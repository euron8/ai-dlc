#!/usr/bin/env bash
# ai-dlc-update — mechanical pre-classification (the cheap, deterministic pass).
#
# Buckets every upstream-changed core/ file by hashing base vs theirs vs ours,
# so the expensive semantic classifier only runs on genuinely BOTH-CHANGED
# files. Self-contained: shells to git only; reads no pipeline rulebook.
#
# Usage: preclassify.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root> [--untangle]
#   dist-repo      path to the distribution git checkout (source of core/)
#   base-sha       the sha in the consumer's .ai-dlc-version stamp
#   theirs-ref     target upstream ref (e.g. HEAD or a tag)
#   consumer-root  the consumer project root (contains .claude/ and scripts/)
#   --untangle     optional. Phase-2 one-time migration mode for a consumer
#                  whose stamp already equals theirs (base == theirs — no
#                  upstream delta exists). A plain base->theirs diff is empty
#                  in that case (git diff <sha> <sha> is always empty), so
#                  this mode enumerates the core-manifest file list from
#                  reconcile/setup-sites.md instead and buckets by ours vs
#                  base (there is no theirs-side status to branch on), with
#                  the exec bit read at theirs (== base by this contract):
#                    UPSTREAM-ONLY-ADD       consumer lacks the file, or holds
#                                            base's bytes without base's mode
#                    ALREADY-AT-THEIRS       base's bytes AND base's mode
#                    BOTH-CHANGED->CLASSIFY  the consumer changed the bytes
#   --templates    optional. Reconcile the generated files OUTSIDE core/
#                  (CLAUDE.md, coding-conventions.md, QUICKSTART.md,
#                  settings.json) from reconcile/template-sites.md. Buckets on
#                  the base->theirs TEMPLATE delta (a token-filled consumer
#                  file never hash-matches the raw template). Buckets:
#                    TEMPLATE-UNCHANGED-NOOP   template boilerplate identical -> noop
#                    TEMPLATE-PROSE-MERGE      token-prose -> mask + reinject (step 7)
#                    TEMPLATE-JSON-MERGE       settings.json -> jq strip/merge (step 7)
#                    CONSUMER-MISSING-NOOP     consumer lacks the generated file -> skip
#
# Output: TSV to stdout — STATUS<TAB>CORE_PATH<TAB>CONSUMER_PATH<TAB>BUCKET
#
# Exit: 0 = classified. 2 = REFUSED: a git call failed (one stderr line names it), or the
#       failure trap could not be armed. Rows printed before a refusal are partial and no
#       caller may read them as buckets.
#
# Deletion buckets (status D — upstream removed the file):
#   UPSTREAM-DELETED                      consumer copy untouched vs base -> delete (gated in step 7)
#   UPSTREAM-DELETED-NOOP                 consumer already lacks it -> noop
#   UPSTREAM-DELETED+consumer-modified->CLASSIFY   consumer changed it -> semantic classify (treat as conflict)
set -u
DIST="${1:?dist-repo}"; BASE="${2:?base-sha}"; THEIRS="${3:?theirs-ref}"; CONS="${4:?consumer-root}"
MODE="${5:-}"

# shellcheck source=lib.sh
# NOT `|| exit 1` the way most siblings guard this, but an unsourceable lib.sh no longer degrades
# silently either: the memo_* calls below then fail with 127, and 127 is not an answer any of
# them accepts, so the run refuses through pc_fail() naming the call rather than classifying
# every path MISSING.
SELF="$(cd "$(dirname "$0")" && pwd)"
. "$SELF/lib.sh" 2>/dev/null || true

# --- A GIT THAT FAILED IS NOT A GIT THAT ANSWERED ---------------------------------------------
#
# This script used to exit 0 over almost every forced git failure. Measured on a scratch copy
# with a PATH shim making one git subcommand exit 128: `diff --name-status` failing gave rc 0 and
# EMPTY output; `hash-object` failing gave rc 0 and a BOTH-ADDED file bucketed UPSTREAM-ONLY-ADD
# (the consumer copy read as MISSING); `rev-parse` failing gave rc 0 and wrong buckets; under
# `ulimit -Su` rc 0 and empty in six runs of six. Three causes: the main loop was the right-hand
# side of `memo_diff_name_status … | while`, so git's status was lost in a pipeline; and
# `file_hash`/`blob_hash` mapped ANY failure to MISSING, which is a legitimate bucket input.
#
# So every git answer below is status-checked, and a failure ends the WHOLE run with exit 2 and
# one stderr line naming the call. THE HELPERS RUN INSIDE `$( )`, where `exit` ends only the
# subshell and the caller would read an empty hash as an answer. pc_fail() therefore signals the
# top-level shell first, whose trap exits 2 as soon as the substitution returns -- one mechanism
# for every call site, rather than a status check at each of them, some of which sit inside an
# `elif` condition where a check cannot be spelled.
#
# THE TRAP IS VERIFIED, NOT ASSUMED. A signal ignored when this shell started cannot be trapped,
# and `trap` then says nothing; a failure would reach no one and the old silent exit 0 would be
# back. So an unarmed trap refuses the run up front. Read back with the plain `trap -p`: lib.sh's
# `trap()` shadow passes every `-p` query straight to the builtin, and I115 refuses the `builtin`
# spelling in any file that sources lib.sh.
trap 'exit 2' USR1
case "$(trap -p USR1 2>/dev/null)" in
  *"exit 2"*) ;;
  *) echo "preclassify: cannot arm the USR1 failure trap (the signal is ignored in this environment), so a git failure could not stop the run — refusing to classify" >&2; exit 2 ;;
esac
PC_TOP=$$
pc_fail() { # <the git call that failed> -> one stderr line, then the WHOLE run exits 2
  echo "preclassify: git failed, refusing to classify: $*" >&2
  kill -USR1 "$PC_TOP" 2>/dev/null
  exit 2
}
# pc_refuse() is pc_fail() for a producer that is not git -- a `find` walk, or a write to the
# staging directory below. Same signal, same exit 2; only the words differ, because "git failed"
# over a failed `find` names the wrong fault.
pc_refuse() { # <what did not run> -> one stderr line, then the WHOLE run exits 2
  echo "preclassify: refusing to classify: $*" >&2
  kill -USR1 "$PC_TOP" 2>/dev/null
  exit 2
}

# Resolve DIST and CONS to absolute paths up front. file_hash() feeds
# "$CONS/<path>" to `git -C "$DIST" hash-object` — a RELATIVE consumer root
# (e.g. `.`) is otherwise resolved relative to DIST, not the consumer, so
# every existing consumer file hashes as MISSING and reads as consumer-deleted.
# Absolute paths make the hash independent of the -C working dir.
DIST="$(cd "$DIST" 2>/dev/null && pwd)" || { echo "preclassify: dist-repo not a directory: ${1}" >&2; exit 2; }
CONS="$(cd "$CONS" 2>/dev/null && pwd)" || { echo "preclassify: consumer-root not a directory: ${4}" >&2; exit 2; }

# --- EVERY LOOP BELOW READS A STAGED FILE, NEVER A `< <( )` ---------------------------------
# A process substitution's exit status is discarded, so a producer that failed fed its loop an
# empty stream and the pass reported nothing to do. Each producer is written to its own file in
# this one directory, its status is read, and a failure refuses the run through pc_fail() or
# pc_refuse(). The file keeps the loop in THIS shell, exactly as `done < <(…)` did; a pipe would
# not. One directory per run, made here in the main shell, removed on EXIT (lib.sh's `trap()`
# composes this handler with its own cleanup rather than replacing it).
PC_STAGE="$(mktemp -d "${TMPDIR:-/tmp}/preclassify-stage.XXXXXX" 2>/dev/null)" || PC_STAGE=""
[ -n "$PC_STAGE" ] && [ -d "$PC_STAGE" ] || { echo "preclassify: refusing to classify: a staging directory could not be created, so no enumeration below could be status-checked" >&2; exit 2; }
trap '[ -n "${PC_STAGE:-}" ] && rm -rf "$PC_STAGE"; :' EXIT

# core/... -> consumer-relative path.
#
# EVERY exception here must match install.sh, because install.sh and this function are
# two writers of the same files and the consumer keeps whichever ran last. They HAD
# diverged: `core/fixtures/` had no case, so the `core/*` catch-all filed fixtures
# under `.claude/fixtures/` while install.sh writes `tests/fixtures/` — the only path
# gate-validation and H1 ever reference. So every pull wrote a shadow copy of every
# fixture into a directory nothing reads, and an upstream fixture fix never reached
# the path its own self-test looks in.
#
# Observed live: v0.48.0 delivered the check-24 fixture to `.claude/fixtures/`, H1
# failed because it was not under `tests/fixtures/`, and the consumer's lead hand-moved
# the directory and committed "H1 fixture remediated" — a consumer manually patching
# around this mapping. An adversarial fixture shipped to a path no check reads is worse
# than no fixture: the catalog claims the check is self-tested, and it is not.
#
# `scripts/validate-enforcement-map.sh` (I8) now evaluates this function and fails if
# it disagrees with install.sh.
map_consumer() { # core/... -> consumer-relative path
  case "$1" in
    core/scripts/*)      echo "scripts/ai-dlc/${1#core/scripts/}" ;;
    core/fixtures/*)     echo "tests/fixtures/${1#core/fixtures/}" ;;
    core/ci-templates/*) echo ".github/workflows/${1#core/ci-templates/}" ;;
    core/git-hooks/*)    echo ".githooks/${1#core/git-hooks/}" ;;
    core/*)              echo ".claude/${1#core/}" ;;
    *)                   echo "$1" ;;
  esac
}
# `core/git-hooks/` is the third subtree the catch-all swallowed. v0.53.0 deleted the CI
# workflow and shipped core/git-hooks/pre-push as the replacement enforcement surface;
# install.sh writes it to `.githooks/pre-push`, but with no case here the pull filed it
# under `.claude/git-hooks/pre-push` — a path no runner, no `core.hooksPath`, and no script
# reads. Observed live on the reference consumer: the only references to `.claude/git-hooks/`
# in its entire tree were `.gitignore` and the file itself, so the repo's ONLY automated gate
# (Actions being disabled there) could not fire, and the documented arming command
# `git config core.hooksPath .githooks` would have found an empty directory.
#
# NOT opted_out(): unlike ci-templates, install.sh writes `.githooks/pre-push`
# unconditionally and leaves only ARMING to the operator (core.hooksPath). Writing the file
# is not the behavioral change; enabling it is. So the pull must write it too.

# CI workflows are OPT-IN, and must stay that way. install.sh has always copied
# ci-templates only `if [ -d "$PROJECT_ROOT/.github/workflows" ]` — a consumer with no
# CI never gets any. Without the same guard here, mapping ci-templates to their real
# destination would make a PULL create `.github/workflows/` on a consumer that never
# opted in, and start running workflows on their repo. Updating a workflow a consumer
# HAS is a fix; conjuring CI on a consumer that has none is a behavioral change nobody
# asked the pull to make.
#
# (Before this release ci-templates fell through the `core/*` catch-all to
# `.claude/ci-templates/`, which nothing reads and install.sh never creates — so
# upstream CI updates reached no one. That is why validate-retro-compliance.yml sat
# dormant on a real consumer.)
opted_out() { # opted_out <consumer-path> -> 0 if this file must be skipped
  case "$1" in
    .github/workflows/*) [ ! -d "$CONS/.github/workflows" ] ;;
    *)                   return 1 ;;
  esac
}
# `-q --verify` is load-bearing, not style. A bare `git rev-parse <rev>:<path>` on a path
# that does not exist in <rev> ECHOES ITS OWN ARGUMENT to stdout and *then* exits 128, so
# `|| echo MISSING` yields the two-line string "<rev>:<path>\nMISSING" — which never
# equals "MISSING", and every `[ "$h" = MISSING ]` test silently reads false. The existing
# buckets escaped this only by accident (the A branch never reads base_h, the D branch
# never reads theirs_h). `-q --verify` prints nothing and exits 1, so MISSING means MISSING.
# Paths that setup-sites.md declares a substitution site for. Read once: these are the
# core files whose `{token}` placeholders `ai-dlc-setup` fills with the consumer's real
# model strings / ownership paths / deploy commands.
#
# A FUNCTION, NOT AN ASSIGNMENT, AND IT IS EXTRACTED BY ITS OWN `^setup_sited_paths() {`…`^}` RANGE.
# `apply.sh` loads this set out of this file twice; as an assignment it was extracted by an awk
# range keyed on the assignment's own closing text, so a respelling ran that range to EOF. The body
# is SELF-CONTAINED for the same reason `machinery_paths()` is: it names no helper and no variable
# of this script, so it means the same thing in every shell that evals it.
#
# RETURNS 4 WHEN THE PRODUCER FAILED, AND THE CALLER REFUSES. The assignment dropped `awk`'s status
# under `2>/dev/null | sort -u`, so an unreadable manifest was an EMPTY set at rc 0 -- every sited
# file read as "not setup-sited", and a token-filled file then bucketed as plain content. A missing
# `setup-sites.md` is the same failure, not a legitimate empty set: the manifest ships in this
# directory in both install layouts, and every caller resolves it beside itself. 4 is the code no
# other status here uses (1-3, 125, 127 and 128 are taken). An EMPTY set from a readable manifest
# is an answer, and returns 0 under `pipefail` too.
setup_sited_paths() { # -> one core-relative setup-sited path per line; 4 = the manifest could not be read
  _ssp_mm="$(dirname "$0")/setup-sites.md"
  [ -f "$_ssp_mm" ] || return 4
  _ssp_out="$(awk '/^[ \t]*file:[ \t]*core\//{sub(/^[ \t]*file:[ \t]*/,""); print}' "$_ssp_mm")" || return 4
  [ -n "$_ssp_out" ] || return 0
  printf '%s\n' "$_ssp_out" | sort -u || return 4
  return 0
}
SETUP_SITED_PATHS="$(setup_sited_paths)" \
  || pc_refuse "the setup-sited path set could not be read from $(dirname "$0")/setup-sites.md (setup_sited_paths returned $?), so no file could be told apart from a setup-filled one"
# --- WHOLE-LINE MEMBERSHIP IS A `case`, NEVER A HERE-STRING OR A HEREDOC -----------------------
# Both membership tests below were `grep -qxF "$1"` fed by `<<<` or `<<EOF`. bash 3.2 stages
# either one to a temp file under the SAME file-size limit as everything else, and when that write
# fails (`ulimit -f`, a full disk) it prints `cannot create temp file for here document`, does not
# run grep, and the test returns 1 -- the "not a member" answer, at rc 0 for the whole run.
# Measured on 1749b545 under `trap '' XFSZ; ulimit -f 1` with each haystack past one block: a new
# setup-sited file bucketed `UPSTREAM-ONLY-ADD` instead of `+SETUP-TOKENS->SUBSTITUTE`, and a
# machinery file at the consumer's own `skill_commit` bucketed `BOTH-CHANGED->CLASSIFY` instead of
# `UPSTREAM-ONLY`. A `case` over the haystack writes no file and forks nothing, so the empty-input
# state is unconstructible rather than detected -- the shape `layer-drift.sh`'s `ld_has_line`
# ships. Each call used to fork one `grep`; it now forks none.
PC_NL='
'
pc_has_line() { # pc_has_line <haystack> <needle> -> 0 when <needle> is a WHOLE line of <haystack>
  case "$PC_NL$1$PC_NL" in *"$PC_NL$2$PC_NL"*) return 0 ;; esac
  return 1
}
setup_sited() { pc_has_line "$SETUP_SITED_PATHS" "$1"; }

# memo_rev_parse (lib.sh) is `rev-parse -q --verify` behind the SHARED cross-process cache
# (populated once per <dist,spec> for the whole render, when emit-report.sh set one up), so a
# resolvable spec still returns its sha and repeats do not fork `git` again.
#
# MISSING IS AN ANSWER, SO ONLY A CONFIRMED ABSENCE MAY PRODUCE IT. `rev-parse -q --verify` exits 1
# for a path absent at a resolvable rev, for an unresolvable rev, and for a path whose SUBTREE or
# ROOT tree is the missing object -- one status for four states. memo_rev_parse separates them with
# lib.sh's discriminator and returns 1 only for a path confirmed absent at a readable tree; the
# other three come back as 125 and refuse the run here. So an UNRESOLVABLE REV REFUSES: before this
# it read as MISSING, and in `--untangle`/`--templates`, which run no `diff` that would have failed
# on it first, every row then bucketed as though the dist held nothing. A path present in the tree
# whose subtree could not be read bucketed MISSING the same way. Any other status is a failure too.
# And a consumer file that EXISTS but will not hash is a failure -- reading it as MISSING turned a
# BOTH-ADDED file into an UPSTREAM-ONLY-ADD that apply overwrites.
blob_hash() {
  local _h _rc
  _h="$(memo_rev_parse "$DIST" "$1:$2" 2>/dev/null)"; _rc=$?
  case "$_rc" in
    0) [ -n "$_h" ] || pc_fail "rev-parse -q --verify $1:$2 exited 0 with no sha"
       printf '%s' "$_h" ;;
    1) echo MISSING ;;
    125) pc_fail "rev-parse -q --verify $1:$2 said absent, and ls-tree could not confirm it: the rev does not resolve, or a tree or blob on the path could not be read" ;;
    *) pc_fail "rev-parse -q --verify $1:$2 exited $_rc" ;;
  esac
}
file_hash() {
  local f="$CONS/$1" _h
  [ -f "$f" ] || { echo MISSING; return 0; }
  _h="$(git -C "$DIST" hash-object "$f" 2>/dev/null)" || pc_fail "hash-object $f exited $?"
  [ -n "$_h" ] || pc_fail "hash-object $f exited 0 with no hash"
  printf '%s\n' "$_h"
}

# --- THE OTHER SHA IN THE STAMP, AND WHY THE `ours_h` COMPARISONS NEED IT ---------------
#
# Every bucket below decides "did the consumer touch this?" by comparing `ours_h` against
# `base_h` and `theirs_h` — and that pair is not exhaustive. The autonomous self-update at
# step 2 rewrites the whole MACHINERY set from an INTERMEDIATE ref, so on a split pull the
# consumer's copy is byte-identical to the distribution at a third sha that is neither
# `commit` nor `theirs`. Against `base_h` and `theirs_h` alone that reads as a consumer edit,
# and the file falls to a `->CLASSIFY` bucket: a semantic-merge obligation manufactured on a
# file with ZERO consumer delta.
#
# REPRODUCED AT GROUND TRUTH from the reference consumer's own committed history, not
# reasoned. Its stamp at `c9919559c` records `commit: f45907a6` (0.443.0) and
# `skill_commit: 94b5f35b` (0.446.0) mid-split; run against that tree with theirs=0.448.0 the
# shipping classifier emits `BOTH-CHANGED->CLASSIFY` for
# `core/skills/ai-dlc-update/reconcile/setup-sites.md` and `core/skills/ai-dlc/core-manifest.md`,
# both of which `cmp -s` byte-identical to the distribution at `94b5f35b` and differ from it at
# BOTH `f45907a6` and the theirs ref. Filed by that consumer as
# `PC-S307-SELF-UPDATE-CARRY-ARM-HAS-NO-CORE-AT-SELF-UPDATE-SUPPRESSION`.
#
# THE COST IS NOT THE ROW, WHICH IS WHY THE FIX IS HERE AND NOT AT THE ROW. That filing names
# `self-update-gate.sh`'s CARRY arm, which reads this bucket string. Both remedies were BUILT
# and scored against the reproduction above: suppressing it in the gate silences the advisory
# row and leaves 2 `WORKLIST semantic-merge` rows, `DECISION restamp-withheld`, and the stamp
# stranded at 0.443.0 — because `apply.sh` never invokes that gate and reads this bucket
# directly (`apply.sh`'s `*CLASSIFY*` arm). Fixing it here drives all three to zero, advances
# the stamp, and the CARRY arm goes quiet with no change of its own. A residual legitimate
# `WORKLIST settings-merge` row is present in both runs and is the control that this does not
# silence work that is real.
#
# READ FROM THE STAMP, NOT PASSED IN, and guarded exactly as `unregistered-drift.sh:121-132`
# guards the same read — that script already reaches the same verdict on the same file in the
# same run, and a second spelling of one fact is a second thing to drift. All three of its
# guards are kept and each has a subject: no stamp at all; `skill_commit` equal to `commit`,
# where the whole question collapses into the `base_h` arm that already exists; and a ref this
# distribution cannot resolve, which would compare against nothing and never match — reading
# exactly like a tree that never split.
SELF_UPDATE_REF=""
_pc_stamp="$CONS/.claude/.ai-dlc-version"
if [ -f "$_pc_stamp" ]; then
  SELF_UPDATE_REF="$(sed -n 's/^skill_commit:[[:space:]]*\([^[:space:]]*\).*/\1/p' "$_pc_stamp" | head -1)"
  [ "$SELF_UPDATE_REF" = "$BASE" ] && SELF_UPDATE_REF=""
  # 0 resolves and 1 does not; anything else is a git that did not answer, and reading it as
  # "does not resolve" would silently drop the skill_commit arms. Checked in its own block so the
  # four-line guard below stays one unit. ONE rev-parse, read by both: a second fork here could
  # fail transiently where the first answered, and the guard would then clear the ref silently.
  _pc_su_rc=0
  if [ -z "$SELF_UPDATE_REF" ]; then :; else
    git -C "$DIST" rev-parse --verify --quiet "${SELF_UPDATE_REF}^{commit}" >/dev/null 2>&1
    _pc_su_rc=$?
    [ "$_pc_su_rc" -le 1 ] || pc_fail "rev-parse --verify --quiet ${SELF_UPDATE_REF}^{commit} exited $_pc_su_rc"
  fi
  if [ -n "$SELF_UPDATE_REF" ] \
     && [ "$_pc_su_rc" -ne 0 ]; then
    SELF_UPDATE_REF=""
  fi
fi

# NEVER `blob_hash "" "$path"`. An empty rev makes the underlying `git rev-parse -q --verify
# ":<path>"` read the INDEX, which resolves for every tracked path in the DISTRIBUTION and
# would match nothing in a way that is impossible to tell from a match. Measured on a
# consumer with NO stamp at all: with the sentinel, 2 CLASSIFY / 0 UPSTREAM-ONLY; with
# `blob_hash ""` instead, 0 / 2 — two paths silently suppressed on a tree that never split.
# The sentinel is a string no sha can equal, so the arms below are unreachable rather than
# accidentally live.
self_update_hash() { # <core-rel-path> -> blob sha at the consumer's own skill_commit
  [ -n "$SELF_UPDATE_REF" ] || { echo NO-SELF-UPDATE-REF; return 0; }
  blob_hash "$SELF_UPDATE_REF" "$1"
}

# --- THE MACHINERY SET, RESOLVED ONCE AND OWNED HERE -------------------------------------
#
# The `skill_commit` arms below are SCOPED to this set, and the scoping is load-bearing
# rather than tidy. Their whole justification is "step 2's autonomous self-update wrote this
# file from an intermediate ref" — and step 2 writes the MACHINERY set and nothing else. A
# non-machinery core file sitting at an intermediate ref got there by some route this arm
# cannot name, so suppressing it is an exemption with no reason attached, and `apply.sh` then
# writes theirs over it with no operator review. Measured on the discriminating input, base
# 0.437.0 / skill 0.442.0 / theirs 0.443.0 with the consumer holding
# `core/fixtures/check-24-adversarial-convergence/run.sh` at the intermediate blob: unscoped
# the arm reclassifies it, scoped it does not, and the path is not in the machinery set.
#
# ONE DERIVATION, OWNED BY THE LOWEST SCRIPT. `self-update-gate.sh` needs the same set for its
# CARRY arm's population and used to resolve it inline; it now `eval`s this function, the way
# `self-update-fixtures.sh` already `eval`s `map_consumer()` out of this file. Two resolutions
# of one manifest is two things to drift, and drift here is silent in both directions: a
# narrower copy leaves the false obligation standing, a wider one suppresses beyond its reason.
#
# READ FROM THE CO-LOCATED MANIFEST, never listed here — the list gaining an entry is exactly
# when this matters most. `core/scripts/ai-dlc/*` is the one CONSUMER-shaped entry: upstream
# the path is `core/scripts/<name>`, and matching a dist path against it directly yields
# nothing at all, silently.
#
# `set -f` IS LOAD-BEARING AND ITS ABSENCE IS SILENT. These entries are git PATHSPECS, and an
# unquoted `$_mg` in a `for` is subject to shell pathname expansion first, so `core/rules/*.md`
# expands against the CWD before git ever sees it. Measured when this derivation was first
# written: the set collapsed from thirteen globs to the ONE entry carrying no glob character,
# and nothing anywhere reported an error. Saved and restored, because this function has a
# caller that does not expect its globbing turned off.
#
# `ls-files --with-tree`, NOT `ls-tree`. These are the manifest's own glob dialect and only the
# index commands speak it: `ls-tree` matches a pathspec by literal prefix, returns EMPTY for
# every globbed entry, reports no error, and rejects `:(glob)` outright. Resolved at BOTH refs,
# because a machinery path DELETED at theirs is absent from one of them and is exactly the case
# where the consumer's copy is the only copy left.
#
# A PRODUCER THAT FAILED RETURNS 4, NEVER A NARROWER SET. Both `ls-files` ran under `2>/dev/null`
# with their status unread, so a listing that failed at ONE ref returned the other ref's paths at
# rc 0: a set narrower than the truth, and non-empty, so no emptiness guard downstream could see
# it. In this script that drops a path added at theirs out of the `skill_commit` scope; in the
# gate it drops a carried path out of arm C's population and the gate says SELF-UPDATE-OK. So the
# manifest read, both listings and the final sort are each status-checked, and any failure is 4 --
# the code no other status here uses. A MISSING `setup-sites.md` is 4 as well: it ships beside
# this file in both layouts and nothing installs one without the other, so its absence is a broken
# install, not a pre-migration state. `set -f` is restored BEFORE the return, so a failure leaves
# the caller's globbing as it found it. An EMPTY set from a readable manifest is an answer and
# returns 0, under `pipefail` too. SELF-CONTAINED: no helper or variable of this script is named,
# because three other scripts and three fixtures `eval` this body where none of them exist.
machinery_paths() { # -> one core-relative machinery path per line, resolved at BASE and THEIRS; 4 = a producer failed
  _mm="$(dirname "$0")/setup-sites.md"
  [ -f "$_mm" ] || return 4
  _mgs="$(awk '/^machinery:/{f=1;next} f&&/^  - /{sub(/^  - /,"");print;next} f{exit}' "$_mm")" || return 4
  _mout=""; _mgnorm=""; _mb=""; _mt=""; _mrc=0
  case "$-" in *f*) _mf=1 ;; *) _mf=0 ;; esac
  set -f
  for _mg in $_mgs; do
    case "$_mg" in core/scripts/ai-dlc/*) _mg="core/scripts/${_mg#core/scripts/ai-dlc/}" ;; esac
    _mgnorm="$_mgnorm $_mg"
  done
  if [ -n "$_mgnorm" ]; then
    # `core.quotePath=false`: the CLASSIFY rows carry raw paths, and arm C and `carried_bucket`
    # join them against this set with `grep -xF` -- a C-quoted set matches no non-ASCII row.
    _mb="$(git -C "$DIST" -c core.quotePath=false ls-files --with-tree="$BASE" -- $_mgnorm 2>/dev/null)" || _mrc=4
    _mt="$(git -C "$DIST" -c core.quotePath=false ls-files --with-tree="$THEIRS" -- $_mgnorm 2>/dev/null)" || _mrc=4
    _mout="$_mb
$_mt"
  fi
  [ "$_mf" = 1 ] || set +f
  [ "$_mrc" -eq 0 ] || return 4
  printf '%s\n' "$_mout" | awk 'length' | sort -u || return 4
  return 0
}

# Resolved ONCE, and only when there is a self-update ref to scope. With no ref the arms are
# already inert, and paying two `ls-files` per manifest glob on every ordinary pull would be a
# cost with no reader. One line, so the assignment and its status read stay together; a failed
# producer refuses the run rather than scoping the arms to a narrower set.
MACHINERY_PATHS=""; _pc_mrc=0
[ -n "$SELF_UPDATE_REF" ] && MACHINERY_PATHS="$(machinery_paths)" || _pc_mrc=$?
[ -z "$SELF_UPDATE_REF" ] || [ "$_pc_mrc" -eq 0 ] \
  || pc_refuse "the machinery path set could not be resolved (machinery_paths returned ${_pc_mrc}: setup-sites.md unreadable, or an ls-files listing at ${BASE} or ${THEIRS} failed), so the skill_commit arms could not be scoped"
is_machinery() { pc_has_line "$MACHINERY_PATHS" "$1"; }

# The whole predicate, in one place so the three call sites cannot disagree about it: this
# consumer's copy is byte-identical to the distribution at the consumer's own `skill_commit`,
# on a path step 2's self-update is the one thing that writes.
at_self_update() { # <core-rel-path> <ours-hash>
  [ -n "$SELF_UPDATE_REF" ] || return 1
  [ "$2" = "$(self_update_hash "$1")" ] || return 1
  is_machinery "$1"
}

# BOTH HASHES ABOVE ARE CONTENT-ONLY, AND THE MODE IS PART OF WHAT A PULL DELIVERS. A blob
# sha and `hash-object` both answer the same question about bytes and neither carries the
# exec bit, so a bucket meaning "nothing left to do" that is decided on them alone is wrong
# for every path whose content already matches theirs and whose MODE does not.
#
# That is not a hypothetical gap in this pipeline: `apply.sh`'s `sync_mode_from_theirs()`
# chmods every file it writes, deriving the bit from `git ls-tree`, and its EXEC-BIT AUDIT
# counts a mechanical failure and WITHHOLDS THE RE-STAMP for any upstream-100755 path the
# consumer cannot execute. So the bit is the driver's responsibility -- and the only thing
# that ever sets it is a bucket that APPLIES. Drop the path as already-satisfied and nothing
# downstream will ever look at it again.
#
# DERIVED FROM THEIRS' OWN TREE, never from a list of which paths are executable. A list
# rots the first time someone adds a hook, which is exactly the case that breaks. Same
# derivation and same source of truth as `sync_mode_from_theirs()`, so the classifier and
# the applier cannot disagree about what theirs' mode IS.
#
# NOT FOLDED INTO blob_hash/file_hash, deliberately, and this was measured rather than
# reasoned. Those two feed the `A` and `D` branches as well: a mode-aware hash there turns
# an `ALREADY-PRESENT` consumer copy into a spurious `BOTH-ADDED->CLASSIFY` hand-back, and
# makes a `D`-branch path whose content matches base read as consumer-modified, refusing a
# delete that is safe. The mode question belongs on the arms that mean "nothing to do", not
# in the definition of content equality.
#
# `[ -x ]` AND NOT A NUMERIC COMPARE. git records exactly two file modes, 100644 and
# 100755; a consumer file may be 600, 664, 775 or anything else the umask produced, and
# none of those is a defect. The only question this can answer is the only one git asks.
#
# UNKNOWN MODE RETURNS SUCCESS, so an unreadable or absent `ls-tree` answer never invents
# work. A symlink (120000) and a gitlink (160000) land here too and neither is a file this
# driver chmods -- same posture as `sync_mode_from_theirs()`, which leaves them alone.
mode_at_theirs() { # <core-rel-path> <consumer-rel-path> -> 0 if the consumer copy's exec bit already matches theirs
  local entry
  # `core.quotePath=false`, as at every other listing here. Only the MODE field is read today, and
  # quoting touches only the path after the tab, so this reader cannot lose a row to it (measured:
  # a mode-only change to a non-ASCII path buckets identically with and without the flag). The flag
  # is here so the line a later reader extends already lists the raw path.
  entry="$(git -C "$DIST" -c core.quotePath=false ls-tree "$THEIRS" -- "$1" 2>/dev/null)" || pc_fail "ls-tree $THEIRS -- $1 exited $?"
  case "${entry%% *}" in
    100755) [ -x "$CONS/$2" ] ;;
    100644) [ ! -x "$CONS/$2" ] ;;
    *) return 0 ;;
  esac
}

if [ "$MODE" = "--templates" ]; then
  # Reconcile the generated files that live OUTSIDE core/ (CLAUDE.md,
  # coding-conventions.md, QUICKSTART.md, settings.json). Bucket on the
  # base->theirs TEMPLATE delta, NOT on ours-vs-base: a token-filled consumer
  # file never hash-matches the raw template, so the meaningful question is
  # "did upstream change the template boilerplate since base?". Reads the
  # template_manifest from template-sites.md (co-located).
  MANIFEST="$(dirname "$0")/template-sites.md"
  # AN UNREADABLE MANIFEST RENDERED AS A CLEAN `none`, AND THAT IS THE REFUSAL THIS ADDS.
  # With `template-sites.md` absent the awk below printed to stderr, the loop read nothing, the
  # block reached its own `exit 0`, and stdout was EMPTY at rc=0 — indistinguishable from "four
  # templates, nothing to sync". A caller rendering this into an operator-facing report then
  # prints `none` for a classifier that classified nothing. Measured: rc=0, 0 bytes.
  #
  # BOTH SHAPES REFUSE, because they are the same absence one level apart: the file missing, and
  # the file present with no `template_manifest:` block for the awk to find (a rename of the key,
  # a truncated copy, a manifest edited to nothing). The second is the one no `-r` test can see,
  # so the parsed output is captured and asserted non-empty rather than piped straight into the
  # loop — a pipeline's emptiness is not observable from inside the loop that reads it.
  [ -r "$MANIFEST" ] || { echo "preclassify: --templates manifest unreadable: $MANIFEST" >&2; exit 2; }
  # Parse the YAML block: each entry has template:/consumer:/kind: lines.
  TEMPLATE_ROWS="$(awk '
    /^template_manifest:/{f=1; next}
    f && /^  - template: /{t=$3; next}
    f && /^    consumer: /{c=$2; next}
    f && /^    kind: /{print t "\t" c "\t" $2; next}
    f && /^[^ ]/{exit}
  ' "$MANIFEST")"
  [ -n "$TEMPLATE_ROWS" ] || { echo "preclassify: --templates manifest parsed to zero entries (no template_manifest: block?): $MANIFEST" >&2; exit 2; }
  printf '%s\n' "$TEMPLATE_ROWS" |
  while IFS=$'\t' read -r tmpl cons kind; do
    [ -z "$tmpl" ] && continue
    base_h="$(blob_hash "$BASE" "$tmpl")"
    theirs_h="$(blob_hash "$THEIRS" "$tmpl")"
    ours_present=MISSING; [ -f "$CONS/$cons" ] && ours_present=PRESENT

    if   [ "$ours_present" = MISSING ];   then bucket="CONSUMER-MISSING-NOOP"      # not a generated consumer -> skip
    elif [ "$base_h" = "$theirs_h" ];     then bucket="TEMPLATE-UNCHANGED-NOOP"    # upstream boilerplate identical -> nothing to sync
    elif [ "$kind" = "json-merge" ];      then bucket="TEMPLATE-JSON-MERGE"        # settings.json -> jq strip/merge (step 7)
    else                                       bucket="TEMPLATE-PROSE-MERGE"; fi   # token-prose -> marker-anchored mask/reinject
    printf '%s\t%s\t%s\t%s\n' "T" "$tmpl" "$cons" "$bucket"
  done
  exit 0
fi

if [ "$MODE" = "--untangle" ]; then
  # Enumerate the core-manifest glob list from setup-sites.md (co-located
  # with this script) rather than diffing base->theirs, which is always
  # empty when base == theirs.
  MANIFEST="$(dirname "$0")/setup-sites.md"
  # `core.quotePath=false`: every path below is mapped by map_consumer() and shown to git again by
  # blob_hash(); a C-quoted non-ASCII name (`"core/rules/caf\303\251.md"`) matches no `core/*` case,
  # maps to itself, and reads MISSING at both ends -- a manifest file reported as one the consumer lacks.
  awk '/^core_manifest:/{f=1; next} f && /^  - /{sub(/^  - /,""); print; next} f{exit}' "$MANIFEST" |
  while IFS= read -r glob; do
    git -C "$DIST" -c core.quotePath=false ls-files "$glob" || pc_fail "ls-files $glob exited $?"
  done | while IFS= read -r path; do
    cons="$(map_consumer "$path")"
    base_h="$(blob_hash "$BASE" "$path")"
    ours_h="$(file_hash "$cons")"

    # "Nothing to untangle" needs the MODE too, not only the bytes: a consumer copy holding base's
    # content without base's exec bit (or with one base does not carry) is not at theirs. It is not
    # a content tangle either, so it is not CLASSIFY: it buckets UPSTREAM-ONLY-ADD, the bucket the
    # default mode's A branch already gives a copy whose content is present and whose bit is not.
    # `mode_at_theirs` reads $THEIRS; this mode's contract is base == theirs (the caller runs it
    # on a stamp that already equals upstream), so theirs' mode IS base's. With two different refs
    # passed, the content is compared at base and the mode at theirs.
    if   [ "$ours_h" = MISSING ];   then bucket="UPSTREAM-ONLY-ADD"       # consumer lacks this manifest file
    elif [ "$ours_h" = "$base_h" ] && mode_at_theirs "$path" "$cons"; then bucket="ALREADY-AT-THEIRS"   # content AND mode -- nothing to untangle
    elif [ "$ours_h" = "$base_h" ]; then bucket="UPSTREAM-ONLY-ADD"       # content at base, exec bit is not -- apply delivers it
    else                                 bucket="BOTH-CHANGED->CLASSIFY"; fi
    printf '%s\t%s\t%s\t%s\n' "U" "$path" "$cons" "$bucket"
  done
  exit 0
fi

# A fixture directory carrying a `.dist-only` marker is NOT a consumer file. THE PULL WAS
# THE WRITER THAT SHIPPED IT. install.sh enumerates the 14 fixtures a consumer gets and
# correctly omits the dist-only ones; map_consumer() maps EVERY core/fixtures/* to
# tests/fixtures/, so the pull shipped them anyway, on every update. Two writers disagreeing
# about MEMBERSHIP, where I8 only ever compared them on DESTINATION. Observed live: the
# reference consumer has tests/fixtures/enforcement-map-sites/ with no subject script beside
# it — a fixture that can never run, in a suite whose green means "these checks are tested."
#
# READ AT THEIRS, NEVER FROM THE DIST WORKING TREE. Every other answer this script gives is keyed
# on a ref; this one read whatever the operator's checkout happened to hold, so a checkout on a
# ref where a fixture was not yet (or no longer) `.dist-only` bucketed it as a pure apply.
# `apply.sh --finish` counts pure-apply rows as unapplied work, so that misreading withheld the
# stamp over a correctly applied tree whose dist-only fixture was, correctly, never written.
# `self-update-fixtures.sh` already reads the marker at theirs for the same reason.
dist_only() { # core/fixtures/<name>/... -> is it marked dist-only at THEIRS?
  case "$1" in
    core/fixtures/*)
      _f="${1#core/fixtures/}"; _f="${_f%%/*}"
      # `cat-file -e` exits 128 for an ABSENT marker and for a git that could not answer alike, and
      # `rev-parse -q --verify` -- the second opinion this used -- answers 1 for a missing SUBTREE
      # exactly as for an absent marker, so a `core/fixtures/<f>/` tree that could not be read read
      # as "not dist-only" and the fixture shipped. memo_has_path (lib.sh) answers 0 present, 128
      # CONFIRMED absent, and 125 when the absence could not be confirmed; a failure read as "not
      # dist-only" ships a dist-only fixture into the consumer, so anything but 0 and 128 refuses.
      _do_rc=0
      memo_has_path "$DIST" "$THEIRS" "core/fixtures/${_f}/.dist-only" || _do_rc=$?
      case "$_do_rc" in
        0)   return 0 ;;
        128) return 1 ;;
        *)   pc_fail "cat-file -e ${THEIRS}:core/fixtures/${_f}/.dist-only exited $_do_rc: the marker could not be confirmed present or absent" ;;
      esac
      ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Scripts-relocation pass — the core validators moved scripts/ -> scripts/ai-dlc/
# in v0.126.0, and a consumer that has not migrated holds every one of them at the
# OLD path. This pass exists because NOTHING ELSE SEES THEM:
#
#   - map_consumer() sends core/scripts/X to scripts/ai-dlc/X, which is empty on a
#     pre-relocation consumer. The changed-files pass below therefore reads the
#     16 upstream-modified validators as "consumer-deleted" and files each a
#     CLASSIFY row -- a semantic merge for a file the consumer never deleted and
#     apply moves mechanically. The 9 UNMODIFIED validators are not in the
#     base..theirs diff at all, so that pass never even mentions them.
#   - unregistered-drift.sh excludes scripts/ by design.
#
# So a locally edited validator at the old path is invisible to the report, and
# the last dry-run asserted OURS==BASE for all 25 against a comparison that never
# ran. This is the detector for it, and it is the report's ground truth.
#
# LEVEL-TRIGGERED, like the orphan pass and like apply.sh's own manifest_dests
# loop: a relocation is a STATE of the consumer tree, not an event in the
# base..theirs history, so the subject set is every validator THEIRS ships, not
# the ones that happen to have changed.
#
# ENUMERATED FROM THE UPSTREAM TREE, never from `find scripts/`. scripts/ is
# SHARED -- the reference consumer owns ~78 of its own scripts beside our 25, and
# no prefix separates them. Driving off `git ls-tree THEIRS core/scripts` is the
# same "derive from the manifest, do not glob the shared dir" discipline the
# core-guard boundary rests on; a find-the-directory pass would indict every
# consumer-authored script as an unknown orphan.
#
# REPORT-ONLY. apply.sh's manifest_dests loop owns the actual move (place THEIRS
# at the new path, empty the old one). These rows carry no action -- apply maps
# RELOCATE-MOVE* to a no-op. The +consumer-edited suffix is a DISCLOSURE, not a
# decision: a validator is machinery with no consumer layer, so the edit is
# overwrite-on-pull like any core file, and the row's only job is to tell the
# operator a local adaptation is about to be discarded so they can confirm it was
# filed as a push candidate first.
#
# STAGED, WITH THE ENUMERATION'S STATUS READ HERE. A failed ls-tree used to feed the loop nothing
# and the pass reported no relocation for a consumer that holds every validator at the old path.
# `core.quotePath=false`: a non-ASCII name is otherwise C-quoted and matches no consumer path.
git -C "$DIST" -c core.quotePath=false ls-tree --name-only "$THEIRS" core/scripts/ > "$PC_STAGE/relocation-ls-tree" 2>/dev/null \
  || pc_fail "ls-tree --name-only $THEIRS core/scripts/ exited $?"
while IFS= read -r core_path; do
  [ -n "$core_path" ] || continue
  base="${core_path#core/scripts/}"
  case "$base" in */*) continue ;; esac   # flat dir only; never descend a subtree
  new_cons="scripts/ai-dlc/$base"
  old_cons="scripts/$base"

  # Already migrated: the file is at its canonical new path and the changed-files
  # pass classifies it there like any other core file. Nothing to relocate.
  [ "$(file_hash "$new_cons")" = MISSING ] || continue

  # Not at the old path either: the consumer simply lacks it. apply's manifest
  # place-arm writes THEIRS; there is no pre-existing copy to move or disclose.
  old_h="$(file_hash "$old_cons")"
  [ "$old_h" = MISSING ] && continue

  theirs_h="$(blob_hash "$THEIRS" "$core_path")"
  base_h="$(blob_hash "$BASE" "$core_path")"
  if [ "$old_h" = "$theirs_h" ] || [ "$old_h" = "$base_h" ]; then
    bucket="RELOCATE-MOVE"
  else
    bucket="RELOCATE-MOVE+consumer-edited"
  fi
  printf '%s\t%s\t%s\t%s\n' "R" "$core_path" "$old_cons" "$bucket -> now at $new_cons"
# NOT memo_ls_tree: that helper caches the RECURSIVE `-r` listing and this call is
# deliberately non-recursive (`ls-tree --name-only`, no `-r`) — it wants only the immediate
# entries of core/scripts/, and filtering the recursive listing to depth 1 after the fact
# is a different, larger rewrite than caching alone. Left as a direct call, staged above the loop.
done < "$PC_STAGE/relocation-ls-tree"

# `--no-renames` IS LOAD-BEARING. Without it git pairs a delete and an add into one
# `R100<TAB>old<TAB>new` row, `read -r status path` hands `path` the tab-joined pair,
# map_consumer() maps only its head, the consumer hash of the joined string is MISSING,
# and the row lands in the M arm's consumer-deleted CLASSIFY bucket with six fields -- a
# semantic-merge task for a file upstream merely moved. (That bucket string is deliberately
# not spelled here: preclassify-mode-bucket anchors its M-arm search on it, and a comment
# carrying it above the loop is text about the program that the search reads as the
# program.) The first rename ever committed
# under core/ (v0.490.0, a fixture transcript) hit this on the reference consumer's very
# next pull. Split, the same change is a D row and an A row, and both arms below already
# classify those correctly: UPSTREAM-DELETED (gated) for the old path, UPSTREAM-ONLY-ADD
# for the new one. The fixture preclassify-rename-row drives a real rename through this
# line and seeds the flag's removal as a mutant.
# memo_diff_name_status (lib.sh): the SHARED cross-process cache for this exact shape --
# `<dist,base,theirs,pathspec>` is the whole key, git's own --no-renames name-status output
# is cached verbatim, so this is byte-identical to the direct call it replaces.
#
# CAPTURED, NOT PIPED. As `memo_diff_name_status … | while` the diff's status was lost in the
# pipeline (this script has no `pipefail`), so a failed diff fed the loop nothing and the run
# exited 0 with EMPTY output -- the same stdout as a range that changes nothing under `core/`.
# The rows are taken first, the status is read off the bare call, and the loop reads them in
# THIS shell from a STAGED FILE whose write is itself status-checked -- NOT a heredoc, which
# bash 3.2 materialises as a TMPDIR file whose write failure (`ulimit -f 0`, a full disk) is
# silent: the heredoc is empty and the loop is skipped with rc 0. Here the same failure refuses.
PC_DIFF="$(memo_diff_name_status "$DIST" "$BASE" "$THEIRS" core/)"
PC_DIFF_RC=$?
[ "$PC_DIFF_RC" -eq 0 ] || pc_fail "diff --no-renames --name-status $BASE $THEIRS -- core/ exited $PC_DIFF_RC"
printf '%s\n' "$PC_DIFF" > "$PC_STAGE/changed-rows" \
  || pc_refuse "the base..theirs rows could not be staged to $PC_STAGE/changed-rows, so the changed-files pass would read nothing"
while IFS=$'\t' read -r status path; do
  [ -n "$path" ] || continue   # printf of an EMPTY diff is one empty line, not zero lines
  cons="$(map_consumer "$path")"

  # core/scripts/* is owned by the scripts-relocation pass above. On a pre-relocation
  # consumer the copy lives at the OLD path, which this base..theirs diff cannot see,
  # so the MISSING-at-new-path result would be a false "consumer-deleted". It is not
  # classified here: the relocation pass has already emitted the real RELOCATE-MOVE row
  # for any validator theirs still ships. A migrated consumer (new path present) falls
  # through and classifies normally.
  #
  # BUT THE PATH IS STILL EMITTED, AS AN INERT ROW, BECAUSE A SILENT `continue` WAS A ZERO.
  # A range whose only core/ change is a core/scripts/* DELETION, pulled by a pre-relocation
  # consumer, used to print NO rows at all (the relocation pass enumerates theirs, where the
  # deleted file is absent) -- and every reader refuses an empty row set over a range that
  # moves core/, so emit-report refused five sections and apply stopped, on a pull with
  # nothing to do, and no re-run could clear it. The row keeps the output non-empty exactly
  # when the range is. `PRE-RELOCATION-NOOP` is inert at every reader of column 4: apply.sh's
  # phase 1 takes `*NOOP` as no action and `--finish` counts only pure-apply buckets; it
  # carries no `CLASSIFY` (worklist, orientation, retired-tokens), is not `UPSTREAM-DELETED`
  # (deletions), and matches neither `^RELOCATE-MOVE` (scripts relocation) nor `consumer-edited`
  # (unregistered-drift and self-update-gate's carried classes). It appears only in the
  # per-file bucket list, which is a listing, not work.
  case "$path" in
    core/scripts/*)
      if [ "$(file_hash "$cons")" = MISSING ] && [ -f "$CONS/scripts/${path#core/scripts/}" ]; then
        printf '%s\t%s\t%s\t%s\n' "$status" "$path" "$cons" "PRE-RELOCATION-NOOP"
        continue
      fi ;;
  esac

  if dist_only "$path"; then
    printf '%s\t%s\t%s\t%s\n' "$status" "$path" "$cons" "DIST-ONLY-SKIP"
    continue
  fi

  if opted_out "$cons"; then
    printf '%s\t%s\t%s\t%s\n' "$status" "$path" "$cons" "CONSUMER-MISSING-NOOP"
    continue
  fi

  base_h="$(blob_hash "$BASE" "$path")"
  theirs_h="$(blob_hash "$THEIRS" "$path")"
  ours_h="$(file_hash "$cons")"

  case "$status" in
    A)
      # A NEW file that carries setup-substitution sites is NOT a pure copy. mask/reinject
      # cannot help it: that transform extracts the CONSUMER's live values before writing
      # theirs, and a file the consumer does not have yet has no live values to extract. So
      # the tokens survive the write, the leftover-token gate fires AFTER every write and
      # before the re-stamp, and its remedy ("add the missing site to setup-sites.md") is
      # wrong -- the site IS declared. The file has simply never been through setup.
      #
      # Every role file predates the consumer's install, so `ai-dlc-setup` filled its tokens
      # once and the pull never had to. team-roles/remediator.md (v0.56.0) is the first NEW
      # template-bearing core file since, and it walked straight into that hole. Surface it
      # in the DRY-RUN, where the operator can answer it, instead of at a gate after writes.
      if   [ "$ours_h" = MISSING ] && setup_sited "$path"; then
                                                bucket="UPSTREAM-ONLY-ADD+SETUP-TOKENS->SUBSTITUTE"
      elif [ "$ours_h" = MISSING ];        then bucket="UPSTREAM-ONLY-ADD"        # pure apply
      elif [ "$ours_h" = "$theirs_h" ] && mode_at_theirs "$path" "$cons"; then bucket="ALREADY-PRESENT"   # content AND mode -> noop
      elif [ "$ours_h" = "$theirs_h" ];    then bucket="UPSTREAM-ONLY-ADD"        # content present, bit is not -> apply delivers it
      # THE SAME DEFECT ARRIVES THROUGH THIS BRANCH TOO, AND ONLY MEASUREMENT SAID SO. A file
      # ADDED between base and theirs, written into the consumer by step 2's self-update at the
      # intermediate ref and then changed again before theirs, is `A` here with `ours` matching
      # neither MISSING nor `theirs_h` -- there is no `base_h` arm to catch it, because the path
      # does not exist at base. Measured over 234 release triples against a consumer holding the
      # distribution's own blob at the intermediate ref for every path -- a tree that authored
      # NOTHING -- the M arm alone leaves 72 residual `BOTH-ADDED->CLASSIFY` rows on 8 distinct
      # paths, every one of them a semantic-merge obligation on a zero-delta file. A second,
      # independent run reached the same conclusion on `predicate-differential.sh`.
      elif at_self_update "$path" "$ours_h"; then bucket="UPSTREAM-ONLY-ADD"
      else                                      bucket="BOTH-ADDED->CLASSIFY"; fi
      ;;
    D)  # upstream removed this file; branch on whether the consumer touched it
      #
      # NO `skill_commit` ARM HERE, AND THAT IS A MEASURED DECISION RATHER THAN AN OVERSIGHT.
      # It is constructible on paper -- a machinery file present at base and at the
      # intermediate ref, deleted by theirs, consumer holding the intermediate blob. It did not
      # occur ONCE across the same 234 triples that produced 361 M-branch and 72 A-branch
      # firings, in either of two independently written sweeps. An arm with no subject is a
      # guard whose removal changes no answer, which this repo treats as indistinguishable from
      # one that passed -- so it is left out, and the absence is written down here rather than
      # rediscovered. That zero is an empty sample, not a proof of unreachability: if a D-branch
      # instance ever appears, this is the arm it is owed, and `at_self_update` is already the
      # predicate to key it on.
      if   [ "$ours_h" = MISSING ];        then bucket="UPSTREAM-DELETED-NOOP"        # already gone -> noop
      elif [ "$ours_h" = "$base_h" ];      then bucket="UPSTREAM-DELETED"             # consumer untouched -> delete (gated)
      else                                      bucket="UPSTREAM-DELETED+consumer-modified->CLASSIFY"; fi
      ;;
    *)  # M (and T). Renames never reach here: --no-renames above splits them into D + A.
      # THE NOOP ARM IS TESTED FIRST, AND ONLY BECAUSE IT CARRIES THE MODE CONJUNCT.
      # Reordering these two arms WITHOUT it is the obvious-looking fix and it is a
      # REGRESSION: on a mode-only upstream change all three content hashes are equal, so a
      # bare `ours_h = theirs_h` cannot tell the consumer that already has the bit from the
      # one that still needs it, and answers "nothing to do" for both. Measured -- see the
      # fixture. Today's order gets the second case RIGHT by accident, which is why the
      # repair adds a discriminator rather than swapping two lines.
      if   [ "$ours_h" = MISSING ];        then bucket="UPSTREAM-MOD+consumer-deleted->CLASSIFY"
      elif [ "$ours_h" = "$theirs_h" ] && mode_at_theirs "$path" "$cons"; then bucket="ALREADY-AT-THEIRS" # content AND mode -> noop
      elif [ "$ours_h" = "$base_h" ];      then bucket="UPSTREAM-ONLY"            # consumer untouched -> apply
      elif [ "$ours_h" = "$theirs_h" ];    then bucket="UPSTREAM-ONLY"            # content at theirs, bit is not -> apply delivers it
      # LAST BEFORE THE CLASSIFY FALLTHROUGH, DELIBERATELY. It must not pre-empt the
      # ALREADY-AT-THEIRS arm, which carries the mode conjunct and is the only arm that can
      # tell a consumer that already has the exec bit from one that still needs it. Reached
      # only once `ours` has been shown to differ from BOTH base and theirs, so the state it
      # names is precisely "upstream content the consumer never authored, at a ref neither
      # endpoint knows about" -- and `UPSTREAM-ONLY` is what that means: apply writes theirs
      # over it, mode included, exactly as it would for any untouched file.
      elif at_self_update "$path" "$ours_h"; then bucket="UPSTREAM-ONLY"
      else                                      bucket="BOTH-CHANGED->CLASSIFY"; fi
      ;;
  esac
  printf '%s\t%s\t%s\t%s\n' "$status" "$path" "$cons" "$bucket"
done < "$PC_STAGE/changed-rows"

# ---------------------------------------------------------------------------
# Orphan pass — files this distribution used to write to a consumer path it no
# longer targets.
#
# When a core subtree's DESTINATION changes (as `core/fixtures/` and
# `core/ci-templates/` did in v0.49.0), the files the pull previously wrote to the
# old path do not move and do not vanish. They sit there, stale, shadowing nothing,
# and every later pull refreshes only the new path — so the orphan silently diverges
# from the file it is a copy of. That is precisely the rot the pull exists to prevent,
# and leaving it to a hand-written migration note in a CHANGELOG is how it never gets
# done.
#
# LEVEL-TRIGGERED, deliberately. This does not key on the base..theirs diff: an orphan
# is a STATE of the consumer tree, not an event in the upstream history. A pull that
# happens to touch no fixture would otherwise skip the check and the orphan would
# survive forever — the same edge-vs-level mistake the absorption detector made.
#
# SAFE BY CONSTRUCTION. It never proposes deleting a file it cannot prove it wrote:
# the orphan's content must hash-match the distribution's own blob (at base or theirs)
# for the core file it came from. A consumer-modified orphan, or a file at the old path
# that upstream never shipped, is surfaced for adjudication and NEVER auto-deleted —
# the same posture as UPSTREAM-DELETED, whose deletions are also gated per-path at
# apply (step 7).
#
# THE WALK IS STAGED ALONE AND ITS STATUS READ BEFORE ANY SORT. This file has no `pipefail`, so
# `find … | sort > f || refuse` would read only sort's status; `find` is written to its own file
# first. A failed walk used to feed the loop nothing, which is the "no orphan here" answer, and
# the stale copies it exists to surface survived the pull unreported. One file per stage, never
# shared with another loop.
#
# THE TABLE IS A WORD LIST, NOT A HEREDOC. It was `done <<'RELOCATIONS'`, which bash 3.2 stages to
# a temp file like any heredoc: a failed staging write ran the loop over NOTHING, at rc 0 -- every
# orphan unreported, the exact answer this pass exists to replace. A literal word list has no
# input to lose. Each word is `<old consumer prefix>|<core subdir>`.
for _pc_reloc in '.claude/fixtures|fixtures' '.claude/ci-templates|ci-templates' '.claude/git-hooks|git-hooks'; do
  old_prefix="${_pc_reloc%%|*}"; core_dir="${_pc_reloc#*|}"
  [ -n "$old_prefix" ] || continue
  [ -d "$CONS/$old_prefix" ] || continue

  find "$CONS/$old_prefix" -type f > "$PC_STAGE/orphan-walk" 2>/dev/null \
    || pc_refuse "the orphan walk of $CONS/$old_prefix did not complete (find exited $?), so an orphan there would read as absent"
  sort "$PC_STAGE/orphan-walk" > "$PC_STAGE/orphan-sorted" \
    || pc_refuse "the orphan walk of $CONS/$old_prefix could not be sorted (sort exited $?)"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    rest="${f#"$CONS/$old_prefix/"}"
    cons_rel="$old_prefix/$rest"
    core_path="core/$core_dir/$rest"
    new_path="$(map_consumer "$core_path")"

    ours_h="$(file_hash "$cons_rel")"
    base_h="$(blob_hash "$BASE" "$core_path")"
    theirs_h="$(blob_hash "$THEIRS" "$core_path")"

    if [ "$base_h" = MISSING ] && [ "$theirs_h" = MISSING ]; then
      # Upstream never shipped this file. Not ours to delete.
      bucket="ORPHANED-UNKNOWN->CLASSIFY"
    elif [ "$ours_h" = "$theirs_h" ] || [ "$ours_h" = "$base_h" ]; then
      # Byte-identical to what we put there -> provably our copy, safe to remove.
      bucket="ORPHANED-RELOCATED"
    else
      # The consumer edited the orphan. Deleting it would destroy their work.
      bucket="ORPHANED-RELOCATED+consumer-modified->CLASSIFY"
    fi
    printf '%s\t%s\t%s\t%s\n' "O" "$core_path" "$cons_rel" "$bucket -> now at $new_path"
  done < "$PC_STAGE/orphan-sorted"
done
