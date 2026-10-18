#!/usr/bin/env bash
# reconcile-region: exempt — operator-run differential; executes consumer commands, never on the pull path
# derivation-differential.sh — did THIS PULL break a recorded derivation, as opposed to the
# consumer's artifact corpus carrying stale ones already?
#
# Usage: derivation-differential.sh <dist> <base> <consumer> <theirs> [--base-root <dir>]
#                                   [--record-owed <file> [--log-name <name>]]
#
# `--record-owed <file>` APPENDS every NEWLY-FAILING row this run prints to <file>, so a derivation the
# operator chooses to LEAVE (disposing of the artifact-derivations WORKLIST row without re-pointing it)
# stays owed instead of living only in the model's recollection. Each record row is rendered by the
# classifier from the SAME variables as the printed row, never retyped, one tab-separated line:
#   OWED <key = file:line, relative to the consumer> <recorded command> <recorded output>
#        <actual output> <base>..<theirs> <reconcile log name>
# There is NO status cell: the record is append-only and a row closes only when
# `scripts/ai-dlc/check-owed-derivations.sh` re-runs the validator on that key and finds it reproducing.
# Without the flag nothing is written. `--log-name` names the reconcile log the row belongs to; its
# default is `reconcile-log-unnamed`, because the log is written after this runs.
#
# THE ROW THIS CHECKS. apply.sh emits `WORKLIST artifact-derivations` when a fenced ```derived
# command in `_bmad-output/**/*.md` names a core path the range CHANGED. Its clear used to be the
# whole-corpus validator exiting 0, and on the reference consumer that clear is unreachable:
# the validator reads thousands of stale derivations before the apply and the same thousands
# after it, nearly all line citations into living docs that drifted long before this pull. Every
# pull then disposed the row by a hand-built differential. This is that differential, built once.
#
# WHAT IS HELD FIXED AND WHAT VARIES. The artifact TEXT is the consumer's copy on both sides -- the
# same files, the same fence lines, passed as the same absolute paths -- and only the PROJECT ROOT
# the commands run against changes: the pre-apply tree, then the consumer's own tree. Varying the
# artifacts as well (base artifacts against theirs artifacts) was measured on the reference
# consumer at 22 newly-failing / 18 newly-passing of pure noise, all from the apply editing
# artifacts; holding them fixed gives 0 / 0 on the same pull. One validator binary runs both
# sides -- the consumer's installed `scripts/ai-dlc/validate-artifact-derivations.sh` -- so the
# only thing that can move a verdict is the tree.
#
# THE KEY IS FILE + FENCE LINE AND THE VERDICT IS THE STATUS, NEVER THE OUTPUT TEXT. Text is
# identical on both sides by construction, so file:line names one derivation on both. A
# derivation's recorded-vs-actual output is not compared across sides: an already-stale one
# whose actual output this range moved again is still stale-before and stale-after, and keying
# on output would hand the operator a clear no edit for this pull can close.
#
#   NEWLY-FAILING  reproduced at base, fails at the consumer -- THIS PULL'S WORK. Named, with the
#                  output the fence recorded and the output it produces now (`recorded: … actual: …`
#                  in the row's detail). The base side reproduced, so the recorded output IS the base
#                  output; the cause is read off the row, never re-derived by hand. Each is the
#                  validator's `/`-joined text cut at 160 characters, so two outputs that differ only
#                  past that column print identically.
#   NEWLY-PASSING  failed at base, reproduces now. Listed.
#   STALE-BOTH     stale on both sides -- pre-existing debt, out of this row's scope. Listed.
#   UNASSESSABLE   the validator REFUSED it (ALLOWLIST, READS-STDIN, GRAMMAR) on either side, so
#                  no status exists to compare. Listed, never counted as cleared.
#
# Exit: 0 zero NEWLY-FAILING (the row's clear) | 1 one or more NEWLY-FAILING | 2 refused -- no
#       verdict, never a clear.
#
# THE BASE ROOT IS FOUND FROM THE STAMP, NOT FROM HEAD. The newest commit on the consumer's
# first-parent chain whose `.claude/.ai-dlc-version` `commit:` resolves in <dist> to the same
# object as <base>. At hand-back the apply is uncommitted and the stamp withheld, so that is HEAD;
# after the step-8 commit re-stamps to theirs it is HEAD^. Either way it is the tree the apply
# started from. A stamp-EQUALITY gate between the two roots was rejected: at hand-back both stamps
# read <base> by design, so it would refuse the one moment this runs.
#
# A SELF-UPDATE COMMIT IS SKIPPED, because `commit:` alone does not say the tree is pre-pull. Step 2
# commits theirs' MACHINERY slice (`scripts/ai-dlc/*`, `.claude/skills/ai-dlc-update/**`) and
# advances `skill_commit:` to theirs while leaving `commit:` at <base>. Taken as the base root, that
# commit already carries this range's machinery, so a derivation over a machinery path the range
# broke fails on BOTH sides, reads STALE-BOTH, and the run exits 0 -- a false clear, measured on a
# seeded world and on the reference consumer's 0.624.0 -> 0.627.0 pull, where the self-update commit
# sits directly under the reconcile commit.
#
# BUT `skill_commit:` IS LEGITIMATELY BEHIND `commit:`, SO EQUALITY IS THE WRONG TEST. Step 2 advances
# `skill_commit:` only when the machinery slice is non-empty, so after a pull with no self-update the
# pre-pull commit carries a `skill_commit:` that is a strict ANCESTOR of <base>. An equality test
# rejects that true pre-pull commit and refuses -- measured on the reference consumer's history at 32
# of 123 walk points, 20 of them pulls. So a commit is the base root when its `commit:` resolves to
# <base> AND its `skill_commit:` line is ABSENT, or names <base>, or names a strict ancestor of <base>
# in <dist> (`merge-base --is-ancestor`): a tree whose machinery is no newer than <base>. It is
# SKIPPED when `skill_commit:` names a descendant of <base> (a self-update carrying this range's
# machinery), an unrelated commit, an EMPTY value, or one that does not resolve in <dist>. An empty
# value is a skip, never "absent": the line is there and says nothing, so the tree cannot be shown to
# be pre-pull. A skipped commit costs at worst a refusal, never a clear. The walk takes the NEWEST
# such commit: a consumer commit above the pull that edits an operand is part of the pre-apply tree,
# and an older commit would score a derivation written against that edit as already stale.
#
# `--base-root` IS HELD TO THE SAME TEST. It checked only `commit:`, so a worktree of HEAD at hand-back
# -- the self-update commit, in exactly the shape above -- passed it and cleared a real break.
#
# A LEAKED BASE WORKTREE IS NAMED, NEVER REMOVED, AND ONLY WHEN ITS RUN IS DEAD. A run killed by SIGKILL
# never reaches its EXIT trap, so its `derivation-differential-root-*` worktree stays registered in
# the consumer. Each run writes its PID into `<that dir>/pid` before adding the worktree; a registered
# worktree is reported in a NOTE row only when that PID is recorded and pid_live() says the process
# is GONE. A concurrent LIVE run's worktree looks identical on disk, and naming it with a removal
# remedy would hand the operator a command that pulls the tree out from under a run in progress. A
# worktree whose directory records no PID is not named either: it cannot be shown to be abandoned.
#
# LIVENESS IS `kill -0` READ BY ITS ERROR, NEVER `ps -p`. `/bin/ps` is setuid root on macOS, and
# wherever setuid execs are refused -- a `sandbox-exec` profile, the read-set tracer's among them --
# `ps -p` exits 126 "Operation not permitted" for EVERY pid, its own included, so every recorded PID
# read as dead and a LIVE run's worktree was named for removal. `kill -0` is a shell builtin and
# execs nothing. Bare `kill -0` is not enough either: it fails with EPERM on a live process another
# uid owns, so a concurrent run by a different user read as dead. So the failure is read by its
# message: "No such process" (ESRCH) is the only answer that names a worktree; "Operation not
# permitted" (EPERM) is a live process we may not signal; and ANY OTHER outcome -- an unparsed or
# empty message -- reads as live. An unreadable answer fails toward silence, never toward a removal
# remedy. Bash's builtin prefixes the message with the script path and line, so it is matched by
# suffix. macOS `strerror` is not localized; `LC_ALL=C` holds the text fixed where it would be.
# ACCEPTED RESIDUAL: a dead run whose PID the kernel has handed to an unrelated process reads as
# live -- under another uid via EPERM, under ours via rc 0 -- and its leaked worktree goes unnamed.
# That is the safe direction: the row is suppressed, nothing is removed, and a later run whose PID
# is free again names it.
#
# A WORKTREE, NOT `git archive`, because derivations run `git` -- `git log`, `git ls-files`,
# `git show` against refs -- and an exported tree has no repository under it: every such
# derivation would fail at base and read as NEWLY-PASSING noise, or worse, mask a real change.
# The worktree is detached at the base commit, created under mktemp, and removed on EXIT with
# `git worktree remove --force` on the path this script created, then `git worktree prune`.
# Hooks are disabled for the checkout so a consumer post-checkout hook cannot run as a side effect.
#
# THE TWO SIDES MUST DIFFER, AND WHAT MUST DIFFER IS CONTENT. At least one path in the range's
# mapped changed set must differ byte-wise between the base root and the consumer (present on
# one side only counts); otherwise both runs read the same tree and a perfect null would read as
# agreement. And a base root on which ZERO derivations reproduce while the consumer reproduces
# at least one is refused: the validator exits 1 all-STALE over a missing or empty root rather
# than refusing, which is the signature of a broken root, not of a pull that fixed everything.
#
# THE ROW'S FILE SET IS NOT RE-STATED HERE. `vd_join()` is lifted out of apply.sh, and
# `map_consumer()` out of preclassify.sh, by the same awk-range + eval this directory already uses
# for map_consumer. If either lift fails the run refuses; a private copy of the join would let the
# operator clear a set the row never named. The join is SCOPED: it keeps only the files the scope
# classifier calls CURRENT or LIVING, so the NEWLY-FAILING set and the exit are the same with every
# past sprint's artifacts deleted, and a classifier that cannot run refuses here (`scope`).
#
# OUT OF SCOPE, stated so a clear is not over-read: a derivation whose operand exists only as an
# untracked or ignored file in the consumer fails at base and shows as NEWLY-PASSING (counted in a
# NOTE); a checkout-dependent derivation (branch name, mtimes, `.git/*`) can differ as noise; a
# relative `_bmad-output/...` operand reads each root's own copy of that artifact; ref-dependent
# `git` derivations read the shared refs from both roots. Runtime is roughly the validator's cost
# twice, run in parallel -- tens of seconds per side on the reference consumer -- which is why
# this is operator-run and never invoked from the driver.
set -uo pipefail

PROG=derivation-differential
say_row() { printf '%s\t%s\t%s\n' "$1" "$2" "$3"; }
refuse()  { say_row REFUSED "$1" "$2"; exit 2; }

BASE_ROOT_ARG=""; BASE_ROOT_SET=0
OWED_FILE=""; OWED_SET=0; LOG_NAME="reconcile-log-unnamed"
_n=0; DIST=""; BASE=""; CONSUMER=""; THEIRS=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --base-root)
      [ "$#" -ge 2 ] || refuse usage "--base-root needs a directory argument."
      BASE_ROOT_ARG="$2"; BASE_ROOT_SET=1; shift 2 ;;
    --base-root=*) BASE_ROOT_ARG="${1#--base-root=}"; BASE_ROOT_SET=1; shift ;;
    --record-owed)
      [ "$#" -ge 2 ] || refuse usage "--record-owed needs a file argument."
      OWED_FILE="$2"; OWED_SET=1; shift 2 ;;
    --log-name)
      [ "$#" -ge 2 ] || refuse usage "--log-name needs a name argument."
      LOG_NAME="$2"; shift 2 ;;
    -*) refuse usage "unknown option $1. Usage: $PROG.sh <dist> <base> <consumer> <theirs> [--base-root <dir>] [--record-owed <file> [--log-name <name>]]" ;;
    *)
      _n=$((_n + 1))
      case "$_n" in
        1) DIST="$1" ;; 2) BASE="$1" ;; 3) CONSUMER="$1" ;; 4) THEIRS="$1" ;;
        *) refuse usage "too many arguments. Usage: $PROG.sh <dist> <base> <consumer> <theirs> [--base-root <dir>]" ;;
      esac
      shift ;;
  esac
done
if [ "$OWED_SET" -eq 1 ]; then
  [ -n "$OWED_FILE" ] || refuse usage "--record-owed is EMPTY. An empty path records nowhere, which would read as a record that was written."
  case "$LOG_NAME" in ''|*[!A-Za-z0-9._-]*) refuse usage "--log-name must be a plain file name ([A-Za-z0-9._-]+), not '$LOG_NAME'." ;; esac
fi
[ "$_n" -eq 4 ] || refuse usage "expected four arguments. Usage: $PROG.sh <dist> <base> <consumer> <theirs> [--base-root <dir>]"

SELF="$(cd "$(dirname "$0")" && pwd)"

# ---- lift the ONE join and the ONE mapper ------------------------------------------------
eval "$(awk '/^map_consumer\(\) \{/,/^\}/' "$SELF/preclassify.sh" 2>/dev/null)"
command -v map_consumer >/dev/null 2>&1 \
  || refuse lift "could not load map_consumer() from $SELF/preclassify.sh. Without the one mapper the row's changed set cannot be derived, and a private table is the defect I17 exists to prevent."
eval "$(awk '/^vd_join\(\) \{/,/^\}/' "$SELF/apply.sh" 2>/dev/null)"
command -v vd_join >/dev/null 2>&1 \
  || refuse lift "could not load vd_join() from $SELF/apply.sh. The row's file set is defined by that join and nowhere else; re-stating it here would let this clear a set the row never named."

# ---- inputs ------------------------------------------------------------------------------
[ -d "$DIST" ] || refuse dist "no such directory: $DIST"
[ -d "$CONSUMER" ] || refuse consumer "no such directory: $CONSUMER"
CONSUMER="$(cd "$CONSUMER" && pwd)"
git -C "$CONSUMER" rev-parse --verify -q HEAD >/dev/null 2>&1 \
  || refuse consumer "$CONSUMER is not a git work tree with a HEAD, so no base commit can be found in its history."
BASE_OBJ="$(git -C "$DIST" rev-parse --verify -q "${BASE}^{commit}" 2>/dev/null)" \
  || refuse base "$BASE does not resolve to a commit in $DIST."
git -C "$DIST" rev-parse --verify -q "${THEIRS}^{commit}" >/dev/null 2>&1 \
  || refuse theirs "$THEIRS does not resolve to a commit in $DIST."
VALIDATOR="$CONSUMER/scripts/ai-dlc/validate-artifact-derivations.sh"
[ -f "$VALIDATOR" ] || refuse validator "$VALIDATOR is not on this consumer, so nothing can re-run the derivations. install.sh delivers it from core/scripts/."
ART="$CONSUMER/_bmad-output"
[ -d "$ART" ] || refuse corpus "$ART does not exist, so there is no artifact corpus and no row to clear."

TMP="$(mktemp -d "${TMPDIR:-/tmp}/$PROG-XXXXXX")" || refuse tmp "could not create a scratch directory."
WT_PARENT=""; WT=""
cleanup() {
  if [ -n "$WT" ]; then
    git -C "$CONSUMER" worktree remove --force "$WT" >/dev/null 2>&1
    git -C "$CONSUMER" worktree prune >/dev/null 2>&1
  fi
  [ -n "$WT_PARENT" ] && { rm -f "$WT_PARENT/pid" 2>/dev/null; rmdir "$WT_PARENT" 2>/dev/null; }
  rm -f "$TMP/files" "$TMP/chain" "$TMP/blobs" "$TMP/pairs" "$TMP/list.out" "$TMP/list.err" \
        "$TMP/b.out" "$TMP/b.err" "$TMP/t.out" "$TMP/t.err" "$TMP/rows" "$TMP/counts" \
        "$TMP/operands" "$TMP/moved" "$TMP/owed" "$TMP/owed.keep" "$TMP/scope.err" "$TMP/dropped" 2>/dev/null
  rmdir "$TMP" 2>/dev/null
}
trap cleanup EXIT

# ---- the row's file set, by the row's own join --------------------------------------------
vd_join "$DIST" "$BASE" "$THEIRS" "$ART"
# The join keeps only the current sprint's artifacts and the living documents, so a past sprint's
# derivation can neither make this exit 1 nor be recorded. A classifier that could not run leaves
# the set unknown, and a clear over an unknown set is the guess the scope ruling forbids.
[ -z "${VD_SCOPE_ERR:-}" ] \
  || refuse scope "which artifacts belong to the current sprint is unknown: ${VD_SCOPE_ERR}. Restore the current sprint's canonical sprint-status.yaml (its \`sprint: <N>\` and \`status:\` lines) so \`sprint-status.sh sprint-id\` answers, then re-run."
[ -n "${VD_MOVED:-}" ] \
  || refuse join "the range ${BASE}..${THEIRS} changes no core path (or the diff could not be read), so the artifact-derivations row cannot have been emitted for it. Check the refs against the row."
[ "$VD_LISTED" -gt 0 ] || refuse join "$ART lists no markdown file."
[ "$VD_SCANNED" -ge "$VD_LISTED" ] \
  || refuse join "the join opened ${VD_SCANNED} of ${VD_LISTED} artifact file(s), so the row's file set is not known."
[ -n "$VD_FILES" ] \
  || refuse join "no fenced derivation names a path this range changed (${VD_HITS} hit(s)), so there is no artifact-derivations row for this range to clear."
printf '%s\n' "$VD_FILES" > "$TMP/files"
printf '%s\n' "$VD_MOVED" | tr '|' '\n' | grep -v '^$' > "$TMP/moved"

stamp_commit() { sed -n 's/^commit:[[:space:]]*//p' | head -1 | tr -d '[:space:]'; }
stamp_skill_commit() { sed -n 's/^skill_commit:[[:space:]]*//p' | head -1 | tr -d '[:space:]'; }
resolves_to_base() { # <stamp-commit> -> 0 when it names the same object as <base> in <dist>
  local o
  [ -n "$1" ] || return 1
  o="$(git -C "$DIST" rev-parse --verify -q "${1}^{commit}" 2>/dev/null)" || return 1
  [ "$o" = "$BASE_OBJ" ]
}
# NO HERE-STRING IN THIS FILE. bash 3.2 stages every `<<<` to a temp file, and when that write
# fails -- `ulimit -f`, a full TMPDIR -- the command reads EMPTY stdin. The presence test below
# was `awk … <<<"$1" || return 0`, so a failed staging read as "the stamp carries no
# skill_commit:" and ACQUITTED the stamp: exactly the self-update root the header says must be
# refused. The presence test is now a `case` prefix match (no file, no fork), and every stamp
# parse is fed by a pipe from `printf`, which nothing stages. `printf '%s\n'` feeds the bytes
# `<<<` did, and each parser reads to EOF before its own `head -1`, so no early-exiting reader
# sits on the pipe.
NL='
'
skill_commit_ok() { # <stamp text> -> 0 when its machinery is no newer than <base> (see the header)
  local v o
  case "$NL$1" in *"${NL}skill_commit:"*) ;; *) return 0 ;; esac
  v="$(printf '%s\n' "$1" | stamp_skill_commit)"
  [ -n "$v" ] || return 1
  o="$(git -C "$DIST" rev-parse --verify -q "${v}^{commit}" 2>/dev/null)" || return 1
  [ "$o" = "$BASE_OBJ" ] && return 0
  git -C "$DIST" merge-base --is-ancestor "$o" "$BASE_OBJ" 2>/dev/null
}

# ---- the base root ------------------------------------------------------------------------
if [ "$BASE_ROOT_SET" -eq 1 ]; then
  [ -n "$BASE_ROOT_ARG" ] || refuse base-root "--base-root is EMPTY. An empty root is not the pre-apply tree; the validator would run every derivation against nothing and report them all stale."
  [ -d "$BASE_ROOT_ARG" ] || refuse base-root "--base-root $BASE_ROOT_ARG is not a directory."
  BR="$(cd "$BASE_ROOT_ARG" && pwd)"
  git -C "$BR" rev-parse --verify -q HEAD >/dev/null 2>&1 \
    || refuse base-root "--base-root $BR is not a git work tree with a HEAD. Derivations run git; a root without a repository fails them all for a reason neither side owns."
  _bst="$(cat "$BR/.claude/.ai-dlc-version" 2>/dev/null)"
  _bs="$(printf '%s\n' "$_bst" | stamp_commit)"
  resolves_to_base "$_bs" \
    || refuse base-root "--base-root $BR carries stamp commit '${_bs:-<none>}', which does not resolve in $DIST to <base> ${BASE}. That root is not the tree this pull started from."
  skill_commit_ok "$_bst" \
    || refuse base-root "--base-root $BR carries skill_commit '$(printf '%s\n' "$_bst" | stamp_skill_commit)', which is empty, unresolvable in $DIST, or not <base> ${BASE} or an ancestor of it. That root already carries machinery past <base> (a step-2 self-update commit, which HEAD is at hand-back after one), so a derivation this range broke would read stale on both sides. Pass a checkout of the commit BELOW the self-update commit."
  BASE_DESC="--base-root $BR"
else
  # The first-parent chain, each commit's stamp BLOB in one cat-file pass; a blob is resolved
  # against <dist> once, and the first commit whose blob resolves to <base> is the base commit.
  # A blob whose skill_commit: is past <base>, empty or unresolvable is skipped (see the header).
  git -C "$CONSUMER" rev-list --first-parent HEAD > "$TMP/chain" 2>/dev/null \
    || refuse base-root "could not walk the consumer's first-parent history."
  sed 's|$|:.claude/.ai-dlc-version|' "$TMP/chain" \
    | git -C "$CONSUMER" cat-file --batch-check='%(objectname)' > "$TMP/blobs" 2>/dev/null
  [ "$(wc -l < "$TMP/chain" | tr -d ' ')" = "$(wc -l < "$TMP/blobs" | tr -d ' ')" ] \
    || refuse base-root "the stamp lookup over the first-parent chain returned a different number of rows than the chain has commits."
  paste "$TMP/chain" "$TMP/blobs" > "$TMP/pairs"
  BASE_COMMIT=""; _bad=" "
  while IFS="$(printf '\t')" read -r _c _b; do
    case "$_b" in *missing*|'') continue ;; esac
    case "$_bad"  in *" $_b "*) continue ;; esac
    _st="$(git -C "$CONSUMER" cat-file -p "$_b" 2>/dev/null)"
    _sc="$(printf '%s\n' "$_st" | stamp_commit)"
    if resolves_to_base "$_sc" && skill_commit_ok "$_st"; then BASE_COMMIT="$_c"; break; fi
    _bad="$_bad$_b "
  done < "$TMP/pairs"
  [ -n "$BASE_COMMIT" ] \
    || refuse base-root "no commit on the consumer's first-parent chain carries a .claude/.ai-dlc-version whose commit: resolves to <base> ${BASE} in $DIST with a skill_commit: that is absent, <base>, or an ancestor of <base> (a self-update commit, or one whose skill_commit: is empty or unresolvable, is not shown to be the pre-pull tree), so the tree this pull started from cannot be found. Pass --base-root <dir> naming a checkout of the commit the pull started from -- the one BELOW any self-update commit; --base-root holds its stamp to the same test and refuses a root whose skill_commit: is past <base>."
  WT_PARENT="$(mktemp -d "${TMPDIR:-/tmp}/$PROG-root-XXXXXX")" || refuse base-root "could not create a scratch directory for the base worktree."
  printf '%s\n' "$$" > "$WT_PARENT/pid" || refuse base-root "could not record this run's PID in $WT_PARENT, so a later run could not tell this worktree from an abandoned one."
  git -C "$CONSUMER" -c core.hooksPath=/dev/null worktree add --detach "$WT_PARENT/base" "$BASE_COMMIT" >/dev/null 2>&1 \
    || refuse base-root "could not add a detached worktree of $BASE_COMMIT at $WT_PARENT/base."
  WT="$WT_PARENT/base"
  BR="$WT"
  git -C "$BR" rev-parse --verify -q HEAD >/dev/null 2>&1 || refuse base-root "the base worktree at $BR has no HEAD."
  BASE_DESC="worktree of $BASE_COMMIT"
fi

say_row INFO stamps "base root ($BASE_DESC) stamp commit: $(stamp_commit < "$BR/.claude/.ai-dlc-version" 2>/dev/null); consumer stamp commit: $(stamp_commit < "$CONSUMER/.claude/.ai-dlc-version" 2>/dev/null). Information only -- at hand-back both read <base>."

# ---- the discriminating control: the two roots must differ in CONTENT on the changed set ----
_ndiff=0; _nmoved=0
while IFS= read -r _p; do
  [ -n "$_p" ] || continue
  _nmoved=$((_nmoved + 1))
  if [ -e "$BR/$_p" ] && [ -e "$CONSUMER/$_p" ]; then
    cmp -s "$BR/$_p" "$CONSUMER/$_p" || _ndiff=$((_ndiff + 1))
  elif [ -e "$BR/$_p" ] || [ -e "$CONSUMER/$_p" ]; then
    _ndiff=$((_ndiff + 1))
  fi
done < "$TMP/moved"
[ "$_ndiff" -gt 0 ] \
  || refuse control "none of the ${_nmoved} path(s) this range changed differs between the base root and the consumer, so both runs would read the same tree and a null would read as agreement. Either the apply has not been run, or the base root is not the pre-apply tree."
say_row INFO control "${_ndiff} of ${_nmoved} changed path(s) differ between the base root and the consumer."

# ---- the universe: every derivation in the row's files, root-independent -----------------
# shellcheck disable=SC2046 -- the file list is newline-split on purpose; IFS is set to newline.
_oifs="$IFS"; IFS='
'
set -f
set -- $(cat "$TMP/files")
set +f
IFS="$_oifs"
AI_DLC_PROJECT_ROOT="$CONSUMER" bash "$VALIDATOR" --list "$@" > "$TMP/list.out" 2> "$TMP/list.err"
_lrc=$?
[ "$_lrc" -eq 0 ] || refuse validator "--list exited ${_lrc} over the row's $# file(s); the universe of derivations is unknown."

# ---- both sides, one binary, in parallel ---------------------------------------------------
( cd "$BR" && AI_DLC_PROJECT_ROOT="$BR" bash "$VALIDATOR" "$@" > "$TMP/b.out" 2> "$TMP/b.err" ) &
_bp=$!
( cd "$CONSUMER" && AI_DLC_PROJECT_ROOT="$CONSUMER" bash "$VALIDATOR" "$@" > "$TMP/t.out" 2> "$TMP/t.err" ) &
_tp=$!
wait "$_bp"; BRC=$?
wait "$_tp"; TRC=$?
case "$BRC" in 0|1) ;; *) refuse validator "the base-side run exited ${BRC} (only 0 and 1 are verdicts). $(head -3 "$TMP/b.err" | tr '\n' ' ')" ;; esac
case "$TRC" in 0|1) ;; *) refuse validator "the consumer-side run exited ${TRC} (only 0 and 1 are verdicts). $(head -3 "$TMP/t.err" | tr '\n' ' ')" ;; esac

# ---- classify ------------------------------------------------------------------------------
# Only stderr HEAD lines `FAIL (<verdict>): <abspath>:<line> ` are read, never continuation lines.
# The file is matched against the row's own set, so a path containing a colon cannot mis-split.
# THE STREAM IS NAMED BY FILENAME, NOT COUNTED BY `FNR == 1`: an exit-0 side leaves an EMPTY
# stderr file, which has no first record, so a counter would shift the consumer side's lines into
# the base side's slot and score every consumer failure as a base failure.
awk -v C="$CONSUMER/" -v brc="$BRC" -v trc="$TRC" -v cf="$TMP/counts" -v of="$TMP/operands" \
    -v ow="$OWED_SET" -v of2="$TMP/owed" -v rng="${BASE}..${THEIRS}" -v lg="$LOG_NAME" \
    -v fF="$TMP/files" -v fL="$TMP/list.out" -v fB="$TMP/b.err" -v fT="$TMP/t.err" '
  { src = (FILENAME == fF) ? 1 : (FILENAME == fL) ? 2 : (FILENAME == fB) ? 3 : (FILENAME == fT) ? 4 : 0 }
  src == 1 { F[$0] = 1; next }
  function keyof(s,    f, r) {
    for (f in F) if (index(s, f ":") == 1) {
      r = substr(s, length(f) + 2)
      if (match(r, /^[0-9]+/)) { KL = substr(r, RLENGTH + 1); return f ":" substr(r, 1, RLENGTH) }
    }
    return ""
  }
  src == 2 {
    if (substr($0, 1, 2) != "  ") next
    k = keyof(substr($0, 3))
    if (k == "" || KL !~ /^  /) next
    if (!(k in U)) { U[k] = 1; ord[++nu] = k; CMD[k] = substr(KL, 3) }
    next
  }
  # Any other head line ends the block a recorded/actual pair belongs to.
  (src == 3 || src == 4) && /^[A-Z][A-Z-]*( \([A-Z-]*\))?: / { ck = "" }
  # A SUPERSEDED derivation -- a record command re-derived byte-identically later in the same file
  # -- is neither run nor counted by the validator, so it has no FAIL on either side and would read
  # as a PASS on both. Counted as a base-side pass, it keeps the broken-root refusal below from ever
  # firing on a row holding a record with a repeat. Supersession depends only on the file`s bytes
  # and path, so both sides name the same set; it is read from both and skipped from every count.
  (src == 3 || src == 4) && /^SUPERSEDED: / {
    k = keyof(substr($0, 13))
    if (k != "" && KL ~ /^ by /) SUP[k] = 1
    next
  }
  (src == 3 || src == 4) && /^FAIL \((STALE|ALLOWLIST|READS-STDIN|GRAMMAR)\): / {
    v = $0; sub(/^FAIL \(/, "", v); sub(/\).*/, "", v)
    s = $0; sub(/^FAIL \([A-Z-]*\): /, "", s)
    k = keyof(s)
    if (k == "" || KL !~ /^ /) next
    if (src == 3) { heads_b++; if (brc == 1) B[k] = v } else { heads_t++; if (trc == 1) T[k] = v }
    if (src == 4 && v == "STALE") ck = k
    if (!(k in U) && !(k in X)) { X[k] = 1; xord[++nx] = k }
    next
  }
  # A STALE block on the consumer side carries what the command printed then and now, each `/`-joined
  # and cut at 160 by the validator. Tabs become spaces so a --numstat output adds no row field.
  src == 4 && ck != "" && substr($0, 1, 16) == "      recorded: " { r = substr($0, 17); gsub(/\t/, " ", r); REC[ck] = r; next }
  src == 4 && ck != "" && substr($0, 1, 16) == "      actual:   " { r = substr($0, 17); gsub(/\t/, " ", r); ACT[ck] = r; next }
  function st(v) { return v == "" ? "PASS" : v }
  function refusal(v) { return v == "ALLOWLIST" || v == "READS-STDIN" || v == "GRAMMAR" }
  function rel(k) { return index(k, C) == 1 ? substr(k, length(C) + 1) : k }
  function row(status, k) {
    printf "%s\t%s\tbase=%s consumer=%s", status, rel(k), st(B[k]), st(T[k])
    if (k in CMD) printf "  $ %s", CMD[k]
    if (status == "NEWLY-FAILING" && (k in REC)) printf "  recorded: %s  actual: %s", REC[k], ACT[k]
    printf "\n"
    # THE OWED RECORD IS RENDERED HERE, FROM THE VARIABLES THE PRINTED ROW READ: the same rel(k), the
    # same CMD[k], the same REC[k] and ACT[k]. A tab inside any of them was already made a space for
    # REC and ACT; the command is cleaned the same way for the record only.
    if (ow == 1 && status == "NEWLY-FAILING") {
      c = (k in CMD) ? CMD[k] : ""; gsub(/\t/, " ", c)
      rr = (k in REC) ? REC[k] : ""; aa = (k in ACT) ? ACT[k] : ""
      printf "OWED\t%s\t%s\t%s\t%s\t%s\t%s\n", rel(k), c, rr, aa, rng, lg >> of2
    }
  }
  END {
    nf = np = sb = un = pb = bp = tp = nsup = 0
    for (i = 1; i <= nu; i++) {
      k = ord[i]
      if (k in SUP) { nsup++; continue }
      if (B[k] == "") bp++
      if (T[k] == "") tp++
      if (refusal(B[k]) || refusal(T[k]))       { un++; row("UNASSESSABLE", k) }
      else if (B[k] == "" && T[k] == "STALE")   { nf++; row("NEWLY-FAILING", k) }
      else if (B[k] == "STALE" && T[k] == "")   { np++; row("NEWLY-PASSING", k) }
      else if (B[k] == "STALE" && T[k] == "STALE") { sb++; row("STALE-BOTH", k) }
      else pb++
      if (B[k] != "" && (k in CMD)) print k "\t" CMD[k] > of
    }
    for (i = 1; i <= nx; i++) { k = xord[i]; un++; row("UNASSESSABLE", k) }
    printf "%d %d %d %d %d %d %d %d %d %d %d\n", nu, nf, np, sb, un, pb, bp, tp, heads_b + 0, heads_t + 0, nsup > cf
  }
' "$TMP/files" "$TMP/list.out" "$TMP/b.err" "$TMP/t.err" > "$TMP/rows"
: >> "$TMP/operands"
read -r N_U N_NF N_NP N_SB N_UN N_PB N_BP N_TP H_B H_T N_SUP < "$TMP/counts" 2>/dev/null \
  || refuse classify "the classifier produced no counts."
[ -n "${N_SUP:-}" ] || refuse classify "the classifier produced no superseded count."

[ "$N_U" -gt 0 ] || refuse validator "--list named ZERO derivations in the row's $# file(s), which the join says carry at least one. A universe the validator cannot spell compares nothing."
# A side that exited 1 must have NAMED a failure; one that did not is a grammar this reader
# cannot spell, and scoring it as all-pass would manufacture NEWLY-PASSING or hide NEWLY-FAILING.
[ "$BRC" -eq 0 ] || [ "$H_B" -gt 0 ] || refuse validator "the base-side run exited 1 and named no FAIL line this reader parses."
[ "$TRC" -eq 0 ] || [ "$H_T" -gt 0 ] || refuse validator "the consumer-side run exited 1 and named no FAIL line this reader parses."
[ "$N_BP" -gt 0 ] || [ "$N_TP" -eq 0 ] \
  || refuse base-root "ZERO derivations reproduce at the base root while ${N_TP} reproduce at the consumer. The validator exits 1 all-STALE over a missing or broken root rather than refusing, so this is the signature of a root that is not the pre-apply tree, not of a pull that repaired everything."
say_row INFO superseded "${N_SUP} of ${N_U} derivation(s) are superseded by a later byte-identical copy in the same record; the validator runs only the later copy, so they are in no count or row below."

# The record is appended only after every refusal above has passed, so a refused run records nothing.
# SCOPE IS CURRENT SPRINT ONLY (operator ruling), AND THE CLASSIFIER IS THE READER'S, NOT A COPY. The
# join above already kept only CURRENT and LIVING files, so every NEWLY-FAILING row here is in scope by
# construction, and a past sprint's or a history file's break never reaches this loop (it is named by the
# `INFO out-of-scope` rows below instead). Each row is still re-classified by the consumer's installed
# `check-owed-derivations.sh --scope <path>` before it is appended, and anything but CURRENT or LIVING
# refuses: the sprint can roll between the join and this write, and recording or dropping a row on a
# scope that moved is the guess the ruling forbids. A classifier that is absent or refuses (exit 2: the
# current sprint could not be resolved) refuses the run for the same reason.
if [ "$OWED_SET" -eq 1 ] && [ -s "$TMP/owed" ]; then
  _scope_tool="$CONSUMER/scripts/ai-dlc/check-owed-derivations.sh"
  [ -f "$_scope_tool" ] \
    || refuse record "$_scope_tool is not on this consumer, so a row's sprint scope cannot be classified and nothing was recorded. It is delivered by install.sh's copy loop over core/scripts/."
  : > "$TMP/owed.keep"
  while IFS= read -r _orow; do
    _okey="$(printf '%s\n' "$_orow" | cut -f2)"
    _sc="$(AI_DLC_PROJECT_ROOT="$CONSUMER" bash "$_scope_tool" --scope "${_okey%:*}" 2>"$TMP/scope.err")" \
      || refuse record "the scope classifier exited non-zero for ${_okey%:*}: $(head -2 "$TMP/scope.err" | tr '\n' ' ')Nothing was recorded."
    case "$_sc" in
      CURRENT|LIVING) printf '%s\n' "$_orow" >> "$TMP/owed.keep" ;;
      *) refuse record "the scope classifier printed '${_sc}' for ${_okey%:*}, which the join had kept as the current sprint's or a living document's. The scope moved between the two reads (did the sprint roll?), so nothing was recorded; re-run." ;;
    esac
  done < "$TMP/owed"
  if [ -s "$TMP/owed.keep" ]; then
    cat "$TMP/owed.keep" >> "$OWED_FILE" 2>/dev/null \
      || refuse record "could not append the NEWLY-FAILING rows to $OWED_FILE, so the debt this run found would be recorded nowhere. Nothing was cleared."
  fi
fi

cat "$TMP/rows"
# A file the scope dropped is named, never silently absent: one row per hit-bearing PAST or HISTORY file.
# It is not run, not recorded, not refused and not closed.
printf '%s\n' "$VD_DROPPED" > "$TMP/dropped" \
  || refuse tmp "could not stage the out-of-scope file list, so a dropped file would go unnamed."
while IFS="$(printf '\t')" read -r _dt _dp; do
  [ -n "$_dp" ] || continue
  case "$_dt" in
    PAST) _dw="a sprint that has since finished" ;;
    *)    _dw="a history file (an archive, or an ai-dlc rotation output)" ;;
  esac
  say_row INFO out-of-scope "${_dt}	${_dp} carries a recorded derivation naming a path this range changed, and is ${_dw}: it is not this pull's to repair, so it is NOT run, NOT recorded, NOT refused at the gate and NOT carried forward, and it is not closed."
done < "$TMP/dropped"

# ---- NOTEs: what the differential cannot attribute -----------------------------------------
# Operands are read as whitespace-split words of the recorded command with globbing OFF, so a
# `*` in a derivation is a word and never an expansion against this shell's cwd. A word counts
# as an operand path when it carries a `/`; one derivation is counted at most once.
_n_only=0
set -f
while IFS="$(printf '\t')" read -r _k _cmd; do
  [ -n "$_k" ] || continue
  for _tok in $_cmd; do
    _tok="${_tok#[\"\']}"; _tok="${_tok%[\"\']}"
    case "$_tok" in -*|/*|*'$'*|*'*'*|*'|'*) continue ;; */*) ;; *) continue ;; esac
    if [ -e "$CONSUMER/$_tok" ] && [ ! -e "$BR/$_tok" ]; then
      _n_only=$((_n_only + 1)); break
    fi
  done
done < "$TMP/operands"
set +f
[ "$_n_only" -eq 0 ] || say_row NOTE operands "${_n_only} base-side failure(s) name an operand that exists only in the consumer's tree (untracked or ignored, so absent from the base root). They read as NEWLY-PASSING or STALE-BOTH, never as NEWLY-FAILING, and are not this pull's doing."
git -C "$CONSUMER" status --porcelain 2>/dev/null \
  | awk -v mf="$TMP/moved" '
      BEGIN { while ((getline l < mf) > 0) M[l] = 1 }
      { p = substr($0, 4); i = index(p, " -> "); if (i) p = substr(p, i + 4); gsub(/^"|"$/, "", p); if (!(p in M)) print p }
    ' \
  | while IFS= read -r _p; do
      say_row NOTE "$_p" "uncommitted in the consumer and outside this range's changed set, so a derivation reading it can move for a reason this pull does not own."
    done
# A leaked base worktree from an earlier run: matched on the directory name this script mints, this
# run's own (if any) excluded by its unique mktemp segment, and named only when the PID its run
# recorded beside it is DEAD. A live PID is a concurrent run; no recorded PID proves nothing.
_own="${WT_PARENT##*/}"
# pid_live <pid> -> 0 unless the process is shown GONE (ESRCH). See the header: EPERM is live, and
# an unreadable answer is live.
pid_live() {
  local _e
  _e="$(LC_ALL=C kill -0 "$1" 2>&1)" && return 0
  case "$_e" in
    *"No such process") return 1 ;;
    *"Operation not permitted") return 0 ;;
  esac
  return 0
}
git -C "$CONSUMER" worktree list --porcelain 2>/dev/null \
  | sed -n 's/^worktree //p' \
  | awk -v own="$_own" 'index($0, "/derivation-differential-root-") && (own == "" || !index($0, "/" own "/"))' \
  | while IFS= read -r _p; do
      _pid="$(head -1 "${_p%/*}/pid" 2>/dev/null | tr -d '[:space:]')"
      case "$_pid" in ''|*[!0-9]*) continue ;; esac
      pid_live "$_pid" && continue
      say_row NOTE worktree "$_p is a registered worktree left by an earlier run of this helper (PID $_pid, no longer running) that never reached its cleanup. It is not removed here; \`git worktree remove --force\` on that path clears it."
    done

say_row SUMMARY "_bmad-output/" "${N_U} derivation(s) in $# file(s): ${N_NF} NEWLY-FAILING, ${N_NP} NEWLY-PASSING, ${N_SB} STALE-BOTH, ${N_UN} UNASSESSABLE, ${N_PB} reproduce on both sides. Base validator exit ${BRC}, consumer exit ${TRC}."
if [ "$N_NF" -gt 0 ]; then
  say_row VERDICT "_bmad-output/" "${N_NF} derivation(s) reproduced before this apply and fail after it. Re-point each NEWLY-FAILING one at the path core carries at ${THEIRS}, then re-run this check."
  exit 1
fi
say_row VERDICT "_bmad-output/" "zero NEWLY-FAILING: this pull broke no recorded derivation. STALE-BOTH rows are pre-existing debt outside this row's scope; UNASSESSABLE rows are not cleared by this verdict and need a hand adjudication."
exit 0
