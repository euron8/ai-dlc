#!/usr/bin/env bash
# fanout-untracked-corpus — report-propagation-fanout.sh's corpus is tracked PLUS
# untracked-not-ignored, and each of those three words is load-bearing.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# The corpus was sourced from `git ls-files`, which lists TRACKED files only. The
# reference consumer never `git add`s planning/implementation artifacts mid-sprint —
# they are committed at PR time — so every artifact a remediator writes DURING a sprint
# is untracked at the moment this script runs. Reproduced by that consumer at sprint 306,
# with two real files on disk under `_bmad-output/planning-artifacts/s306/`:
#
#     mutable corpus: 1 files
#       of those, from the current sprint: 0
#     SCOPING FAILURE: sprint 306 was declared, but not one corpus file came from its
#       artifact directory. The tree this root resolved to does not hold that sprint.
#     rc=3
#
# That is exit 3 — the WRONG-TREE exit — fired on the right tree, over files sitting at
# exactly the path the script was looking for. And the script's only caller is the gate
# remediation loop, which runs mid-sprint by construction: the broken state was not an
# edge case, it was the tool's sole operating condition.
#
# WHY THE FIX HAS A SECOND HALF THAT ALSO NEEDS GUARDING. `--exclude-standard` is what
# keeps the union from admitting build output and caches. Measured on that same consumer:
# `git ls-files --others` alone lists 84309 files, 12641 of them under `docs/` or
# `_bmad-output/`, against a legitimate corpus of a few hundred. Dropping the flag is a
# one-word edit that turns an advisory worklist into noise, and no arm here existed to
# see it. So the arms below are a THREE-WAY partition — the untracked half is admitted,
# the ignored files are not, and the tracked half is still there — because a fix that
# lands any one of the three and drops another reads exactly like a fix that worked.
#
# AND THE WRONG-TREE EXIT MUST SURVIVE THE FIX. A change that satisfies a check by
# deleting the check's subject reads as green forever. `SCOPING FAILURE` is the only
# thing standing between this tool and an empty worklist off an unrelated repository, so
# assertion 4 drives a genuinely wrong tree and requires exit 3 to still come back.
#
set -uo pipefail

# HERMETIC — scrub the operator's tuning before invoking anything (I10). AI_DLC_PROJECT_ROOT
# is set explicitly per invocation below, and a leaked one would pin every run to the same
# tree and make every comparison here vacuous.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset CLAUDE_PROJECT_DIR

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

# Both install layouts, derived from install.sh's mapping: core/scripts/<x> lands at
# scripts/ai-dlc/<x> on a consumer. A fixture that only knew the distribution path would
# ship inert to the one tree it is written to defend.
SUBJ=""
for cand in "$ROOT/core/scripts/report-propagation-fanout.sh" \
            "$ROOT/scripts/ai-dlc/report-propagation-fanout.sh"; do
  [ -f "$cand" ] && { SUBJ="$cand"; break; }
done
[ -n "$SUBJ" ] || {
  echo "FIXTURE ERROR: report-propagation-fanout.sh not found in either layout" >&2
  echo "  looked in: $ROOT/core/scripts (distribution), $ROOT/scripts/ai-dlc (consumer)" >&2
  exit 2
}
echo "  subject resolved: $SUBJ"

command -v python3 >/dev/null 2>&1 || {
  echo "FIXTURE ERROR: python3 not on PATH; the subject's scanner is a python3 heredoc" >&2
  exit 2
}
REAL_GIT="$(command -v git)" || { echo "FIXTURE ERROR: git not on PATH" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/fanout-untracked.XXXXXX")" \
  || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
. "$HERE/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }

# IN PROCESS (BL-878). The subject is loaded ONCE with lib/inproc.sh's inproc_load (its source guard returns after
# defining rpf_main) and every arm asks rpf_main through inproc_run, in a subshell made to look like a fresh
# `bash report-propagation-fanout.sh`. The program runs only in the cli cells (cells.decl).
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. A consumer can receive this file one pull before the wrapped subject, and
# sourcing a pre-wrap subject would run its whole body. So the shape is checked first, on its two halves: neither the
# `rpf_main() {` line nor the column-0 source guard is a subject that predates the wrap, which prints SKIP and exits 0
# (FIXTURE BROKEN in the distribution) -- never an ok. Exactly one half is a respelled subject this fixture cannot
# drive, which FAILS. An unreadable subject is FIXTURE ERROR.
rpf_def=0; rpf_guard=0
grep -qxF 'rpf_main() {' "$SUBJ"; _gx=$?
[ "$_gx" -le 1 ] || { echo "FIXTURE ERROR: cannot read $SUBJ (grep exit $_gx) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
[ "$_gx" -ne 0 ] || rpf_def=1
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$SUBJ"; _gx=$?
[ "$_gx" -le 1 ] || { echo "FIXTURE ERROR: cannot read $SUBJ (grep exit $_gx) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
[ "$_gx" -ne 0 ] || rpf_guard=1
if [ "$rpf_def$rpf_guard" = 00 ]; then echo "SKIP: $SUBJ predates the in-process wrap"; fx_skip_exit "$HERE"; fi
if [ "$rpf_def$rpf_guard" != 11 ]; then
  bad "$SUBJ carries one half of the in-process wrap (rpf_main line: $rpf_def, column-0 source guard: $rpf_guard) -- a respelled subject this fixture cannot drive"
  report_end fanout-untracked-corpus
fi
. "$HERE/../lib/inproc.sh" || { echo "FIXTURE BROKEN: cannot source lib/inproc.sh" >&2; exit 2; }
inproc_load "$SUBJ" || { echo "FIXTURE BROKEN: sourcing $SUBJ defined nothing" >&2; exit 2; }
declare -F rpf_main >/dev/null || { echo "FIXTURE BROKEN: sourcing $SUBJ defined no rpf_main" >&2; exit 2; }

# ============================================================================
# THE TREES
# ============================================================================
# A consumer mid-sprint. `docs/architecture.md` is the SHIFT TARGET: tracked, then given a
# two-line insertion in the working tree, which is the uncommitted state a remediator is
# actually in. Three citing files, one per corpus-membership class, each citing a DIFFERENT
# line so a worklist row names its own class unambiguously:
#
#   docs/tracked-cite.md                             tracked            MUST be scanned
#   _bmad-output/planning-artifacts/s306/…​           untracked, listed  MUST be scanned
#   docs/junk/ignored-cite.md                        untracked, IGNORED must NOT be
#
# `docs/junk/` is gitignored, so it is the only thing separating `--others` from
# `--others --exclude-standard`, and without it that flag would be unobservable here.
mktree() { # mktree <dir> <with-sprint-artifacts: yes|no>
  local d="$1" want="$2" i=1
  mkdir -p "$d/docs/junk" "$d/_bmad-output/planning-artifacts/s306" || return 2
  ( cd "$d" && "$REAL_GIT" init -q . ) || return 2
  printf 'docs/junk/\n' > "$d/.gitignore" || return 2
  printf 'sprint: 306\n' > "$d/_bmad-output/planning-artifacts/sprint-status.yaml" || return 2
  while [ "$i" -le 20 ]; do printf 'line %d\n' "$i" >> "$d/docs/architecture.md"; i=$((i+1)); done
  # Backticks are written via printf \140: a citation is backtick-delimited by the
  # subject's own grammar, and a literal backtick inside a double-quoted string here
  # would be command substitution against a hole.
  printf 'cites \140docs/architecture.md:15\140 from a tracked file\n' > "$d/docs/tracked-cite.md" || return 2
  ( cd "$d" && "$REAL_GIT" -c user.email=f@f -c user.name=fixture add -A \
      && "$REAL_GIT" -c user.email=f@f -c user.name=fixture commit -q -m base ) || return 2
  # The working-tree insertion. Two lines added at the top, so the first shifted OLD line
  # is 1 and every citation in the file is at or below it.
  { printf 'INSERTED\nINSERTED\n'; cat "$d/docs/architecture.md"; } > "$d/.tmp" || return 2
  mv -f "$d/.tmp" "$d/docs/architecture.md" || return 2
  printf 'cites \140docs/architecture.md:17\140 from an IGNORED file\n' > "$d/docs/junk/ignored-cite.md" || return 2
  if [ "$want" = yes ]; then
    printf 'cites \140docs/architecture.md:16\140 from an UNTRACKED sprint artifact\n' \
      > "$d/_bmad-output/planning-artifacts/s306/story-1.md" || return 2
  else
    # The WRONG-TREE shape: the sprint is declared but its directory holds nothing, in
    # neither tracked nor untracked form. `docs/` still supplies a plausible corpus, which
    # is what makes this the case that reads most like a clean result.
    rmdir "$d/_bmad-output/planning-artifacts/s306" || return 2
  fi
  return 0
}

TREE="$WORK/consumer"
mktree "$TREE" yes || { echo "FIXTURE ERROR: could not build the mid-sprint tree" >&2; exit 2; }
BASE="$( cd "$TREE" && "$REAL_GIT" rev-parse HEAD )" || { echo "FIXTURE ERROR: no base rev" >&2; exit 2; }

WRONG="$WORK/wrongtree"
mktree "$WRONG" no || { echo "FIXTURE ERROR: could not build the wrong tree" >&2; exit 2; }
WBASE="$( cd "$WRONG" && "$REAL_GIT" rev-parse HEAD )" || { echo "FIXTURE ERROR: no base rev" >&2; exit 2; }

# Sanity: the three citing files must be in the membership classes the arms assume, or
# every assertion below is about a tree that cannot express the defect.
tracked_ok=$( cd "$TREE" && "$REAL_GIT" ls-files | grep -c '^docs/tracked-cite\.md$' )
untr_ok=$(    cd "$TREE" && "$REAL_GIT" ls-files --others --exclude-standard \
                | grep -c '^_bmad-output/planning-artifacts/s306/story-1\.md$' )
ign_ok=$(     cd "$TREE" && "$REAL_GIT" ls-files --others --exclude-standard \
                | grep -c '^docs/junk/ignored-cite\.md$' )
if [ "$tracked_ok" != 1 ] || [ "$untr_ok" != 1 ] || [ "$ign_ok" != 0 ]; then
  echo "FIXTURE ERROR: the seed tree is not in the three membership classes the arms assume" >&2
  echo "  tracked=$tracked_ok (want 1)  untracked-listed=$untr_ok (want 1)  ignored-listed=$ign_ok (want 0)" >&2
  exit 2
fi

# ============================================================================
# THE HARNESS
# ============================================================================
# `run <subject> <tree> <base>` -> prints the subject's output with a trailing
# `rc=<n>` line. The rc is appended INSIDE the substitution because zsh has no PIPESTATUS
# and a caller reading $? after a pipe would read the wrong program's status.
run() {
  local subj="$1" tree="$2" base="$3" out rc
  out="$( AI_DLC_PROJECT_ROOT="$tree" inproc_run "$subj" rpf_main "$base" 2>&1 )"; rc=$?
  printf '%s\nrc=%d\n' "$out" "$rc"
}
# Every predicate below reads a captured string with a here-string, never a pipe: `grep -q`
# leaves at its first match, and under pipefail a pipeline then answers with the writer's
# EPIPE and reports NOT-FOUND on input that contains the pattern.
has()  { grep -qF -- "$2" <<<"$1"; }
rows() { grep -cE '^  [^ ].*  ->  ' <<<"$1"; }

# The REQUIRED input of inputs.decl: every assertion drives this file, and this is the first
# point it is run. SUBJ is built from a pwd-resolved ROOT, so it carries no `..` segment.
echo "HERMETIC-CONSUMED $SUBJ"
OUT="$(run "$SUBJ" "$TREE" "$BASE")"

# ============================================================================
# 1. THE FILED DEFECT — an untracked sprint artifact is IN the corpus.
# ============================================================================
# Presence-shaped on purpose: it demands the worklist row and the sprint count, so a
# subject that emitted nothing at all would fail it rather than pass on an absence.
if has "$OUT" "rc=0" \
   && ! has "$OUT" "SCOPING FAILURE" \
   && has "$OUT" "_bmad-output/planning-artifacts/s306/story-1.md:1  ->  docs/architecture.md:16"; then
  ok "an UNTRACKED file under the current sprint's artifact root is scanned, and its stale citation reaches the worklist"
else
  bad "an untracked sprint artifact is invisible to the corpus — the filed sprint-306 defect: $(grep -c 'SCOPING FAILURE' <<<"$OUT") scoping failure(s), $(grep -o 'rc=[0-9]*' <<<"$OUT")"
fi
# The in-band control the header owes its reader. `>= 1`, not `== 1`, deliberately: the
# exact count is arm 2's subject, and an arm that also pinned it would go red on arm 2's
# regression and leave two failures where one defect exists.
n_untracked="$(sed -n 's/.*untracked (not yet git-added): \([0-9][0-9]*\).*/\1/p' <<<"$OUT" | head -1)"
if [ -n "$n_untracked" ] && [ "$n_untracked" -ge 1 ]; then
  ok "the header states the untracked contribution ($n_untracked), so a consumer can see what its .gitignore admitted"
else
  bad "the header does not report an untracked corpus contribution ('${n_untracked:-<absent>}') — the cost of the union is invisible on the run that pays it"
fi

# ============================================================================
# 2. `--exclude-standard` HOLDS — a gitignored file is NOT in the corpus.
# ============================================================================
# The other side of the union, and the one a one-word edit removes. Its own positive
# conjunct — the worklist must be non-empty — is what stops this arm scoring a kill
# against a subject that produced no worklist at all.
if [ "$(rows "$OUT")" -ge 1 ] && ! has "$OUT" "docs/junk/ignored-cite.md"; then
  ok "a gitignored file under a corpus root stays OUT of the corpus — the union is --exclude-standard, not bare --others"
else
  bad "a gitignored file reached the worklist (or the worklist was empty and this arm proved nothing): rows=$(rows "$OUT")"
fi

# ============================================================================
# 3. THE TRACKED HALF IS STILL THERE.
# ============================================================================
# A union written as a replacement rather than an addition passes assertions 1 and 2 and
# silently stops scanning every artifact the consumer HAS committed — which on the
# reference consumer is 10666 files against a handful of uncommitted ones.
if has "$OUT" "docs/tracked-cite.md:1  ->  docs/architecture.md:15"; then
  ok "TRACKED files are still scanned — the untracked set was added to the corpus, not substituted for it"
else
  bad "a tracked citing file no longer reaches the worklist: the untracked half replaced the tracked half instead of joining it"
fi

# ============================================================================
# 4. THE WRONG-TREE EXIT SURVIVED THE FIX.
# ============================================================================
# What does this change make always-true downstream? If admitting untracked files could
# make `SCOPING FAILURE` unreachable, the fix would have satisfied the check by deleting
# its subject, and every later run over an unrelated repository would read as clean.
WOUT="$(run "$SUBJ" "$WRONG" "$WBASE")"
if has "$WOUT" "rc=3" && has "$WOUT" "SCOPING FAILURE"; then
  ok "a tree whose declared sprint has no artifact directory in EITHER tracked or untracked form still exits 3 — the wrong-tree exit is still reachable"
else
  bad "SCOPING FAILURE can no longer fire: the corpus fix made the wrong-tree exit unreachable, so an empty worklist off an unrelated repository now reads as a clean result. $(grep -o 'rc=[0-9]*' <<<"$WOUT")"
fi

# ============================================================================
# 5. THE CLI CELLS (cells.decl): the subject run as a PROGRAM once per distinct CLI outcome
# ============================================================================
# Each `FXCELL=<id> bash` start is compared with the in-process call on the same input: stdout, stderr and exit
# separately, byte for byte. Outcomes: exit 0 with a worklist (cli-worklist), exit 3 SCOPING FAILURE (cli-scoping), and
# exit 2 naming the root the subject RESOLVED (cli-root). Each cell also asserts its own outcome, so two runs that both
# printed nothing cannot read as equivalent.
#
# cli-root IS THE ROOT-RESOLUTION CELL. The subject walks UP from `${BASH_SOURCE[0]}`'s directory for its root when
# AI_DLC_PROJECT_ROOT is unset; in process, BASH_SOURCE[0] must still be the subject's own file, or the walk starts
# from this fixture's directory and answers about another tree. A copy sits at <probe>/core/scripts/ under a probe
# root marked by `.claude/` and holding no repository (GIT_CEILING_DIRECTORIES stops git's own walk at the work
# directory), and both runs start from an unrelated directory: each must refuse naming <probe> as the root.
EQ="$WORK/eq"; mkdir -p "$EQ" || { echo "FIXTURE ERROR: mkdir eq" >&2; exit 2; }
eqv() { # <cell-id> <subject path> <tree or -> <base> -> $EQ/<id>.{ip,cl}.{out,err,rc}; tree `-` leaves the root unset
  local id="$1" s="$2" t="$3" b="$4"
  if [ "$t" = - ]; then
    ( cd "$EQ" && GIT_CEILING_DIRECTORIES="$WORK_P" inproc_run "$s" rpf_main "$b" ) > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
    ( cd "$EQ" && GIT_CEILING_DIRECTORIES="$WORK_P" FXCELL="$id" bash "$s" "$b" ) > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  else
    AI_DLC_PROJECT_ROOT="$t" inproc_run "$s" rpf_main "$b" > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
    AI_DLC_PROJECT_ROOT="$t" FXCELL="$id" bash "$s" "$b" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  fi
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
}
eq_twin() { printf 'in-process rc=%s err=[%s] / program rc=%s err=[%s]' "$(cat "$EQ/$1.ip.rc")" "$(head -1 "$EQ/$1.ip.err")" \
  "$(cat "$EQ/$1.cl.rc")" "$(head -1 "$EQ/$1.cl.err")"; }
if eqv cli-worklist "$SUBJ" "$TREE" "$BASE" && [ "$(cat "$EQ/cli-worklist.cl.rc")" = 0 ] \
   && grep -qF '_bmad-output/planning-artifacts/s306/story-1.md:1  ->  docs/architecture.md:16' "$EQ/cli-worklist.cl.out"; then
  ok "cli-worklist: the program emits the mid-sprint worklist exactly as the in-process call does (stdout, stderr, exit 0)"
else bad "cli-worklist: the program and the in-process call differ, or the outcome is not exit 0 with the untracked row ($(eq_twin cli-worklist))"; fi
if eqv cli-scoping "$SUBJ" "$WRONG" "$WBASE" && [ "$(cat "$EQ/cli-scoping.cl.rc")" = 3 ] \
   && grep -qF 'SCOPING FAILURE' "$EQ/cli-scoping.cl.out"; then
  ok "cli-scoping: the program exits 3 with SCOPING FAILURE on the wrong tree exactly as the in-process call does"
else bad "cli-scoping: the program and the in-process call differ, or the outcome is not exit 3 with SCOPING FAILURE ($(eq_twin cli-scoping))"; fi
WORK_P="$(cd "$WORK" && pwd -P)" || { echo "FIXTURE ERROR: cannot resolve WORK" >&2; exit 2; }
PROBE="$WORK_P/probe"
mkdir -p "$PROBE/.claude" "$PROBE/core/scripts" && cp "$SUBJ" "$PROBE/core/scripts/report-propagation-fanout.sh" \
  || { echo "FIXTURE ERROR: could not build the root probe" >&2; exit 2; }
if eqv cli-root "$PROBE/core/scripts/report-propagation-fanout.sh" - HEAD && [ "$(cat "$EQ/cli-root.cl.rc")" = 2 ] \
   && grep -qxF "ERROR: $PROBE is not a git repository; this script derives its scope" "$EQ/cli-root.ip.err"; then
  ok "cli-root: in process, the subject resolves its root from its own file (<probe>), exactly as the program does"
else bad "cli-root: the in-process root is not the program's, or neither names <probe> as the root ($(eq_twin cli-root))"; fi

echo
report_end fanout-untracked-corpus
