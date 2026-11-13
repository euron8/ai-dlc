#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# retro-branch-behind-main — a retro branch cut from a leftover feature ref is BEHIND the
# merged trunk, and validate-mandatory-rules.sh Check 7 is what says so before the PR does.
#
# THE DEFECT THIS EXISTS TO CATCH. `retro.md` Step 1 cuts the retro branch from `main` after a
# fast-forward to `origin/main`. A squash merge never fast-forwards the sprint's feature branch,
# so that ref survives the merge pointing at a commit the squash is NOT descended from. A retro
# branch cut from it lacks the squash commit as an ancestor, its PR re-includes the entire sprint
# diff against a main that already carries it, GitHub reports CONFLICTING at Step 7a, and the
# recovery is a hand merge of every file both sides touched. Check 7's predicate is
# `git rev-list --count HEAD..origin/main` == 0 — the same test `sprint-review.md` §0 runs.
#
# AND THE PREDICATE IS ONLY AS FRESH AS THE REF IT READS. The squash's branch point is an
# ancestor of the stranded feature ref by construction, so a STALE local `origin/main` scores the
# exact defect world as behind 0 — the check reports PASS on the tree it exists to catch. Check 7
# therefore refreshes the ref itself when a remote named `origin` exists, and every CHECK 7 line
# states which of the three refresh states it ran under. Worlds G and H below are that half:
# G is a clone whose remote main gained the squash AFTER the clone, and H is the same clone with
# its origin URL pointed nowhere. Worlds A through F have no remote at all and must attempt no
# fetch, which assertion 4 pins by exact text.
#
# WHY EVERY ARM IS PRESENCE-SHAPED. Each token demands a VERDICT WORD parsed out of a
# `  CHECK 7: ` line, so a subject that emits nothing scores `NONE` and fails every arm by
# construction; silence cannot pass for a kill anywhere in this file. The unmutated CONTROL is
# necessary and not sufficient for that same reason: it asserts the eight baseline rows are
# THERE, not merely that nothing went wrong.
#
# WHY THE TOKEN PARSES RATHER THAN STRING-MATCHES. Eight arms times seven batteries is fifty-six
# expected lines, and pinning full prose in every one of them makes a wording change read as
# fifty-six regressions. The token carries the six facts that ARE the check — verdict, behind
# count, refresh state, whether the remedy was printed, the summary sentence's class, and the
# exit code — and assertion 4 pins the exact wording ONCE, in the three refresh states, against
# the shipping validator.
#
# WHY THE EIGHT WORLDS ARE EIGHT REPOSITORIES. Check 7 reads refs, so the input IS the commit
# graph. Every world is its own git tree on disk with its own refs; no helper carries a ref out
# of the world that produced it, because refs set globally by one build are what drives world A
# with world B's refs and reads as a withheld verdict rather than as an error.
#
# WHY ARM C IS NOT DECORATION. The failure message NAMES `git merge origin/main` as the remedy.
# An arm that only proves the check fires has not established that the remedy it prints clears
# it, and arm C is also the only arm that separates "is origin/main contained in HEAD NOW" from
# "was it contained when the branch was CUT" — a merge moves the first and never the second.
# Mutant `cutpoint` is that wrong fix built and scored, and arm C is the single arm it moves.
#
# WHY ARM F EXISTS BESIDE ARM E. Arm E is a retro branch AHEAD of origin/main and behind by
# none: it proves the predicate is behind-count and not divergence. Arm F is the only world
# where the LOCAL `main` ref and `origin/main` disagree, and it is the only arm that can tell
# Check 7 from a Check 7 that reads local `main` — the wrong fix mutant `localmain` builds.
# Without F that substitution is invisible, because in every other world the two refs are equal.
#
# ARM G IS THE ONLY ARM WHOSE PRE-STATE IS A LIE, and it is reset before every battery. Its
# clone starts behind 0 against a stale ref and behind 3 against the real remote; a battery that
# inherited the previous battery's refreshed ref would score `nofetch` as a kill it did not earn,
# so the token refuses the arm outright if the pre-state is not stale when it runs.
#
# CHECKS 1, 2 AND 4 ARE DRIVEN THROUGH STUBBED SIBLINGS. This fixture's subject is Check 7, and
# the sibling contract those three checks publish is an exit code; stubbing them keeps the run's
# verdict a statement about branch freshness rather than about a delegated validator. The stubs
# are proven live by the CONTROL battery, which reproduces all eight arms from its own toolchain
# dir — a copy that cannot resolve `../schemas` emits nothing, and "no output" would otherwise
# score as a kill for every mutant at once.
# ============================================================================
# THE MUTANT x ARM MATRIX. Per push each mutant drives only its DECIDING arm and one TWIN: an arm
# that stays GREEN under it, run to prove the kill stays confined to the deciding arm. A tripped
# twin fails the fixture. `--matrix` drives every arm of every mutant and prints one MATRIX-ROW
# per mutant (cell 1 = the arm is dead under the mutant, 0 = green). Re-measure it whenever an arm
# or a mutant is added or changed, with the REMEASURE command below. mutate() and mutate2() READ
# their decides/twins from these very lines, so the header is the behaviour, not a copy of it.
# Arms of part 1 are the worlds a..h; arms of part 2 are the worlds carry..head-absent; arms of
# part 3 are the worlds land-ok..land-tag; arms of part 4 are the worlds merge-ok..merge-view-lowercase.
#
# FOUR MUTANTS HAVE NO GREEN TWIN, measured: `deleted`, `carry-deleted`, `cut-from-tip` and
# `land-pre-fix` fall every arm of their part (the subject emits nothing, or every world is cut from
# the wrong ref), so each carries `twins=-` with its reason and per push drives its deciding arm
# only. The claim "each mutant co-trips no other arm" is NOT made for this fixture: the measured
# dead-sets are recorded under MEASURED MATRIX below, and several are wider than one world because
# the property removed is visible in every world that reaches it (gh-primary calls gh in every
# tree-match world that has a fork point; plain-range and merge-base re-pick in the re-pointed
# worlds too).
#
# MUTANT-MATRIX deleted decides=b twins=- why=with the Check 7 block gone the subject emits no CHECK 7 line in any of the eight worlds, so every arm reads NONE and no arm stays green
# MUTANT-MATRIX reversed decides=e twins=f
# MUTANT-MATRIX silentskip decides=d twins=a
# MUTANT-MATRIX nofetch decides=g twins=b
# MUTANT-MATRIX localmain decides=f twins=b
# MUTANT-MATRIX cutpoint decides=c twins=b
# MUTANT-MATRIX carry-deleted decides=carry twins=- why=with the carry block gone no world prints a CARRY line, so all seventeen worlds read NONE and no world stays green
# MUTANT-MATRIX cut-from-tip decides=carry twins=- why=cutting the retro branch from the sprint tip moves the token of all seventeen worlds (behind count, landed flag or HARD_BLOCK class), so no world stays green
# MUTANT-MATRIX no-skip-guard decides=empty twins=carry
# MUTANT-MATRIX no-abort decides=conflict twins=carry
# MUTANT-MATRIX plain-range decides=synced twins=carry
# MUTANT-MATRIX merge-base decides=carry twins=direct
# MUTANT-MATRIX all-parents decides=synced twins=carry
# MUTANT-MATRIX gh-primary decides=carry twins=direct
# MUTANT-MATRIX no-gh-guard decides=repointed-nogh twins=repointed
# MUTANT-MATRIX ancestry-accepts decides=wrong-pr twins=repointed
# MUTANT-MATRIX no-newest-guard decides=reused-branch twins=repointed
# MUTANT-MATRIX no-tree-check decides=tree-mismatch twins=repointed
# MUTANT-MATRIX rc-ignored decides=repointed-ghfail twins=repointed-empty
# MUTANT-MATRIX no-empty-guard decides=repointed-empty twins=repointed-ghfail
# MUTANT-MATRIX no-row-shape decides=repointed-badrow twins=repointed
# MUTANT-MATRIX no-head-guard decides=head-absent twins=repointed
# MUTANT-MATRIX no-head-fetch decides=head-fetched twins=repointed
# MUTANT-MATRIX land-pre-fix decides=land-wt twins=- why=the bare one-liner prints no LAND line, so every LAND world reads NONE and land-ok cannot stay green on a presence-shaped token
# MUTANT-MATRIX land-no-symref decides=land-tag twins=land-ok
# MUTANT-MATRIX land-no-false decides=land-wt twins=land-ok
# MUTANT-MATRIX land-names-self decides=land-diverged twins=land-wt
# MUTANT-MATRIX merge-exit-only decides=merge-cleanup-failed twins=merge-ok
# MUTANT-MATRIX merge-exit-trusted decides=merge-exit0-open twins=merge-ok
# MUTANT-MATRIX merge-accept-any-state decides=merge-open twins=merge-ok
# MUTANT-MATRIX merge-case-fold decides=merge-view-lowercase twins=merge-open
# MUTANT-MATRIX merge-no-false decides=merge-open twins=merge-ok
# MUTANT-MATRIX pending-in-dist decides=dist-absent twins=consumer-absent
#
# MEASURED MATRIX (the --matrix run that recorded this header, 50 assertions PASS; every row's twin
# GREEN except the four twins=- rows, which are dead in every cell of their part). Dead-sets:
#   deleted {a..h}  reversed {b c e g h}  silentskip {d}  nofetch {g h}  localmain {f g}  cutpoint {c}
#   carry-deleted, cut-from-tip {all 17 part 2 worlds}  no-skip-guard {empty}  no-abort {conflict}
#   plain-range {synced repointed head-fetched}  all-parents {synced}
#   merge-base {carry empty synced underivable repointed-nogh repointed-ghfail repointed-empty
#               repointed-badrow wrong-pr reused-branch tree-mismatch head-absent}
#   gh-primary {carry empty synced conflict}  no-gh-guard {repointed-nogh}  ancestry-accepts {wrong-pr}
#   no-newest-guard {reused-branch}  no-tree-check {tree-mismatch}  rc-ignored {repointed-ghfail}
#   no-empty-guard {repointed-empty}  no-row-shape {repointed-badrow}
#   no-head-guard {head-absent head-fetched}  no-head-fetch {head-fetched}
#   land-pre-fix {land-ok land-wt land-diverged land-tag}  land-no-symref {land-tag}
#   land-no-false {land-wt land-diverged land-tag}  land-names-self {land-diverged}
#   merge-exit-only {merge-cleanup-failed}  merge-exit-trusted {merge-exit0-open}
#   merge-accept-any-state {merge-exit0-open merge-open merge-view-lowercase}
#   merge-case-fold {merge-view-lowercase}
#   merge-no-false {merge-exit0-open merge-open merge-view-fails merge-view-lowercase}
#   pending-in-dist {dist-absent} (arm pending-layout; its subject is this file's own gate_verdict)
# The matrix is measured with every subject PRESENT. With one ABSENT its part prints PENDING and
# drives no mutant of it (the PENDING block above part 2).
# NOT A MUTANT HERE: dropping 7a's `|| PR_STATE=""` is EQUIVALENT under the real producer, whose
# failing `gh pr view` prints 0 bytes to stdout (captured), so PR_STATE is empty either way.
# MUTANT-MATRIX-REMEASURE bash core/fixtures/retro-branch-behind-main/run.sh --matrix
set -uo pipefail

MATRIX=0
[ "${1:-}" = --matrix ] && MATRIX=1
MCELLS=0   # matrix-only cells driven; a plain run must leave this at 0

DIR="$(cd "$(dirname "$0")" && pwd)"

# ROOT BY WALKING UP FOR THE SUBJECT, never by counting `..` hops, and BOTH LAYOUTS NAMED
# (I33/I33c). Upstream this fixture sits at core/fixtures/<name>/ with the toolchain at
# core/scripts/ and the schemas at core/schemas/; a consumer has tests/fixtures/<name>/,
# scripts/ai-dlc/ and .claude/schemas/ — install.sh splits what shares a parent here, so no
# single relative shape reaches both. `VERSION` is deliberately NOT the marker: install.sh
# stamps a consumer with `.claude/.ai-dlc-version` and ships no `VERSION` file, so keying on it
# would make this shipping fixture exit 2 on every consumer it reaches.
ROOT=""; TOOLS=""; SCHEMAS=""; LAYOUT=""
_d="$DIR"
while : ; do
  _p="$(cd "$_d/.." 2>/dev/null && pwd)" || break
  [ -n "$_p" ] && [ "$_p" != "$_d" ] || break
  _d="$_p"
  if   [ -f "$_d/core/scripts/validate-mandatory-rules.sh" ]; then
    ROOT="$_d"; TOOLS="$_d/core/scripts"; SCHEMAS="$_d/core/schemas"; LAYOUT=distribution; break
  elif [ -f "$_d/scripts/ai-dlc/validate-mandatory-rules.sh" ]; then
    ROOT="$_d"; TOOLS="$_d/scripts/ai-dlc"; SCHEMAS="$_d/.claude/schemas"; LAYOUT=consumer; break
  fi
  [ "$_d" = "/" ] && break
done
if [ -z "$ROOT" ]; then
  echo "FIXTURE ERROR: validate-mandatory-rules.sh not found in either layout above $DIR" >&2
  exit 2
fi
# retro.md Step 1 is the second subject (Part 2 below), its 7a-post step 1 the third (Part 3) and
# its 7a the fourth (Part 4). Same two layouts, same root.
#
# A CONSUMER WHOSE INSTALLED retro.md PREDATES THE gh FALLBACK, THE LAND BLOCK AND THE 7a BLOCK.
# This fixture ships (no .dist-only) and retro.md is rulebook, which reaches a consumer only when
# its reconcile PR merges, so the fixture can arrive a pull AHEAD of its subject, and any non-zero
# exit is a red consumer push. So an ABSENT subject is PENDING, never a failure and never a pass:
# each part whose subject is absent prints one `  PENDING  ` row naming it, skips (and counts) the
# arms that need it, and every other arm still asserts — before the fallback arrives, the six
# carry worlds whose verdict it did not change keep asserting, with every non-fallback mutant.
# ABSENT is keyed only on the subject's own markers counting 0 (see PENDING above part 2); a
# PRESENT subject that is broken is RED (arm pending-gate). The final line names the PENDING count.
# PENDING is a CONSUMER-layout verdict only: in the distribution an absent subject is RED.
RETRO=""
for _r in "$ROOT/core/skills/ai-dlc/steps/retro.md" "$ROOT/.claude/skills/ai-dlc/steps/retro.md"; do
  [ -f "$_r" ] && { RETRO="$_r"; break; }
done
if [ -z "$RETRO" ]; then
  echo "FIXTURE ERROR: steps/retro.md not found under $ROOT in either layout — an absent subject is not a passing one" >&2
  exit 2
fi

VMR="$TOOLS/validate-mandatory-rules.sh"
VAA="$TOOLS/validate-audit-anchors.sh"
SS="$TOOLS/sprint-status.sh"
ANCHOR_SCHEMA="$SCHEMAS/audit-anchors.json"
STATUS_SCHEMA="$SCHEMAS/sprint-status.json"
for f in "$VMR" "$VAA" "$SS" "$ANCHOR_SCHEMA" "$STATUS_SCHEMA"; do
  [ -f "$f" ] || { echo "FIXTURE ERROR: required file not found: $f" >&2; exit 2; }
done
echo "HERMETIC-CONSUMED core/scripts/validate-mandatory-rules.sh"
echo "HERMETIC-CONSUMED core/skills/ai-dlc/steps/retro.md"
command -v git >/dev/null 2>&1 || { echo "FIXTURE ERROR: git not on PATH" >&2; exit 2; }
# Hermeticity (I10/I87): a fixture that inherits the operator's AI_DLC_* tunables tests the
# CONFIG, not the code.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

fails=0
asserted=0
ok()  { printf '  ok    %s\n' "$1"; asserted=$((asserted+1)); }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); asserted=$((asserted+1)); }

echo "retro-branch-behind-main:"
if [ "$MATRIX" = 1 ]; then echo "MODE: FULL (--matrix, every mutant x every arm)"; else echo "MODE: PUSH (each mutant drives its deciding arm and one twin)"; fi

# ============================================================================
# THE BASE REPOSITORY. One commit graph, shaped so the squash-merge defect is expressible:
#
#   C1 ── C2 ── S ── T1 ── T2      main, and refs/remotes/origin/main
#          \
#           F1                     ai-dlc/sprint-900, the leftover feature ref
#
# S is `git merge --squash ai-dlc/sprint-900` committed onto main: it carries F1's tree change
# and NOT F1 as a parent, which is the whole reason the feature ref is stranded. T1 and T2 are
# ordinary trunk commits landed after the squash, so the behind-count from F1 is three rather
# than one — a count of one cannot tell "names the number" from "prints a constant".
#
# C2 is also the STALE point worlds G and H clone at: it is an ancestor of F1, so a clone whose
# origin/main sits there scores the defect world as behind 0 until the ref is refreshed.
#
# `schemas/` sits beside every toolchain dir because validate-audit-anchors.sh and Check 6 both
# resolve their schema at $SCRIPT_DIR/../schemas, the relative shape both shipped layouts have.
# ============================================================================
mkdir -p "$WORK/schemas"
cp "$ANCHOR_SCHEMA" "$WORK/schemas/audit-anchors.json"
cp "$STATUS_SCHEMA" "$WORK/schemas/sprint-status.json"

B="$WORK/base"
mkdir -p "$B/_bmad-output/implementation-artifacts"
export AI_DLC_SPRINT_STATUS_SCHEMA="$STATUS_SCHEMA"
bash "$SS" roll  --sprint 900 --intensity full --root "$B" >/dev/null 2>&1
bash "$SS" close --evidence "fixture: PR merged, deploy green, smoke pass" --root "$B" >/dev/null 2>&1
[ -f "$B/_bmad-output/implementation-artifacts/sprint-status.yaml" ] \
  || { echo "FIXTURE ERROR: sprint-status.sh did not write the envelope Check 3 reads" >&2; exit 2; }
unset AI_DLC_SPRINT_STATUS_SCHEMA

git -c init.defaultBranch=main init -q "$B" 2>/dev/null \
  || { echo "FIXTURE ERROR: git init failed" >&2; exit 2; }
g() { git -C "$B" "$@"; }
g config user.email f@example.com
g config user.name Fixture
g config commit.gpgsign false

# C1 — the prior sprint boundary. The story corpus Check 6 reads lands here, so every world
# below carries it whichever ref its HEAD was cut from.
mkdir -p "$B/_bmad-output/planning-artifacts/s900/stories"
printf '# Story 900-1\n\n## Dev Agent Record\n\ndev (delegated) implemented this.\n' \
  > "$B/_bmad-output/planning-artifacts/s900/stories/story-1-fixture.md"
g add -A && g commit -q -m "prior sprint boundary"
PRIOR_SHA="$(g rev-parse HEAD)"

# C2 — trunk work the feature branch is cut from, and the stale clone point.
mkdir -p "$B/trunk"; echo "c2" > "$B/trunk/a.txt"
g add -A && g commit -q -m "trunk work"
C2="$(g rev-parse HEAD)"

# F1 — the sprint's web/** change on its own branch. Check 5 needs it in PRIOR_SHA..HEAD.
g checkout -q -b ai-dlc/sprint-900
mkdir -p "$B/web/src"; echo "console.log('ui')" > "$B/web/src/app.js"
g add -A && g commit -q -m "Sprint 900 web change"
F1="$(g rev-parse HEAD)"

# S — the SQUASH merge onto main. Same tree change, no F1 parent.
g checkout -q main
g merge --squash ai-dlc/sprint-900 >/dev/null 2>&1
g commit -q -m "Sprint 900 (squashed)"
S="$(g rev-parse HEAD)"
# T1, T2 — trunk after the squash.
echo "t1" > "$B/trunk/b.txt"; g add -A && g commit -q -m "trunk after squash 1"
T1="$(g rev-parse HEAD)"
echo "t2" > "$B/trunk/c.txt"; g add -A && g commit -q -m "trunk after squash 2"
T2="$(g rev-parse HEAD)"
g update-ref refs/remotes/origin/main "$T2"

# THE BEHIND COUNT IS DERIVED FROM THE GRAPH, NOT WRITTEN DOWN. It is the number of commits
# origin/main has that the stranded feature ref lacks — S, T1 and T2 — and the arms below build
# their expected token from it. The control refuses a seed that stopped expressing the defect:
# if S ever became an ancestor of F1 (a real merge instead of a squash), or a trunk commit
# stopped landing, the count moves and every arm's expected token would silently follow a graph
# that no longer carries the defect.
BEHIND="$(g rev-list --count "${F1}..${T2}")"
_bset="$(g rev-list "${F1}..${T2}" | sort)"
_want="$(printf '%s\n%s\n%s\n' "$S" "$T1" "$T2" | sort)"
if [ "$BEHIND" != "3" ] || [ "$_bset" != "$_want" ]; then
  echo "FIXTURE ERROR: the seeded graph does not express the defect — ${F1}..${T2} is ${BEHIND} commit(s), expected exactly 3 (S, T1, T2)." >&2
  exit 2
fi
g merge-base --is-ancestor "$F1" "$T2" \
  && { echo "FIXTURE ERROR: the feature ref IS an ancestor of the trunk tip, so the squash was a fast-forward and this seed cannot express the defect." >&2; exit 2; }
g merge-base --is-ancestor "$C2" "$F1" \
  || { echo "FIXTURE ERROR: the stale clone point is not an ancestor of the feature ref, so worlds G and H would not start behind 0 and the fetch would change nothing." >&2; exit 2; }

# ============================================================================
# THE EIGHT WORLDS. A through F are full copies of the base repository and have NO remote, so
# Check 7 must attempt no fetch in any of them. G and H are real clones over `file://`.
# ============================================================================
world() { # world <name> <source-tree> -> path
  local w="$WORK/w-$1"
  cp -R "$2" "$w" || { echo "FIXTURE ERROR: could not build world $1" >&2; exit 2; }
  printf '%s' "$w"
}
artifacts() { # artifacts <world> — the untracked retro evidence checks 2, 4, 5 and 8 read.
  printf '## Gate Log: Sprint 900\n\n| Gate | Result | Notes |\n|------|--------|-------|\n| Deploy Status Report | PASS | USER-CONFIRMED visual verification captured |\n' \
    > "$1/_bmad-output/implementation-artifacts/gate-log.md"
  printf -- '- sprint: 899\n  sha: %s\n- sprint: 900\n  sha: <PENDING-S900-RETRO>\n' "$PRIOR_SHA" \
    > "$1/_bmad-output/audit-anchors.md"
  printf '# Validation Cycle Log\n\n- sprint 900: three cycles\n' \
    > "$1/_bmad-output/validation-cycle-log.md"
  # Check 8 reads the snapshot's pipeline position. Seeded at `retro.md` — the value
  # deploy-validate.md's routing write leaves — so Check 8 runs its live PASS path in every
  # world and this fixture's verdicts stay statements about Check 7. Without it every world
  # would carry a Check 8 SKIP and the summary class would report a floor, which is a different
  # fixture's subject arriving in all eight of this one's tokens.
  printf '# Pipeline Snapshot\n\n## Pipeline Position\n- current_step_file: retro.md\n- last_completed_step_file: deploy-validate.md\n\n## Recent Activity\n- retro in flight\n' \
    > "$1/_bmad-output/pipeline-snapshot.md"
}

# A — the SANITY world: retro branch cut from the merged trunk, exactly as retro.md Step 1 says.
WA="$(world a "$B")";  git -C "$WA" checkout -q -b ai-dlc/retro/sprint-900 main
# B — THE DEFECT: retro branch cut from the leftover feature ref the squash stranded.
WB="$(world b "$B")";  git -C "$WB" checkout -q -b ai-dlc/retro/sprint-900 ai-dlc/sprint-900
# C — THE REMEDY: world B after running the command the failure message names.
WC="$(world c "$WB")"
if ! git -C "$WC" merge --no-edit -m "merge origin/main" origin/main >/dev/null 2>&1; then
  echo "FIXTURE ERROR: the remedy 'git merge origin/main' did not apply cleanly on world B, so arm C would be testing the merge and not the check." >&2
  exit 2
fi
# D — the SKIP world: no origin/main ref resolves, so freshness is unmeasurable.
WD="$(world d "$WA")"; git -C "$WD" update-ref -d refs/remotes/origin/main
# E — the NEAR-MISS: trunk-cut and then AHEAD of origin/main by two. Behind by none.
WE="$(world e "$WA")"
mkdir -p "$WE/retro"
echo "e1" > "$WE/retro/e1.txt"; git -C "$WE" add -A && git -C "$WE" commit -q -m "retro note 1"
echo "e2" > "$WE/retro/e2.txt"; git -C "$WE" add -A && git -C "$WE" commit -q -m "retro note 2"
# F — the SECOND NEAR-MISS, and the only NO-REMOTE world where local `main` and origin/main
#     disagree: origin/main is held at the squash while local main has run on two commits, and
#     the retro branch is cut from origin/main. Behind origin/main by none; behind `main` by two.
WF="$(world f "$B")"
git -C "$WF" update-ref refs/remotes/origin/main "$S"
git -C "$WF" checkout -q -b ai-dlc/retro/sprint-900 "$S"

# G — THE STALE CLONE. A `file://` remote whose main is at C2 when the clone is taken, advanced
#     to the post-squash trunk tip afterwards. The clone's local origin/main is therefore stale,
#     the retro branch is cut from the stranded feature ref, and the pre-fetch behind-count is
#     ZERO: without the refresh Check 7 certifies the exact tree it exists to catch.
REMOTE="$WORK/remote.git"
git clone -q --bare "$B" "$REMOTE" 2>/dev/null \
  || { echo "FIXTURE ERROR: could not build the file:// remote" >&2; exit 2; }
git -C "$REMOTE" update-ref refs/heads/main "$C2"
WG="$WORK/w-g"
git clone -q "file://$REMOTE" "$WG" 2>/dev/null \
  || { echo "FIXTURE ERROR: could not clone the file:// remote" >&2; exit 2; }
git -C "$WG" config user.email f@example.com
git -C "$WG" config user.name Fixture
git -C "$WG" config commit.gpgsign false
git -C "$WG" checkout -q -b ai-dlc/retro/sprint-900 origin/ai-dlc/sprint-900
# H — the SAME clone with its origin URL pointed at a path that does not exist. The fetch fails,
#     the check still has to evaluate, and its line has to say the ref may be stale.
WH="$WORK/w-h"
cp -R "$WG" "$WH" || { echo "FIXTURE ERROR: could not build world h" >&2; exit 2; }
git -C "$WH" remote set-url origin "file://$WORK/no-such-remote.git"
# The squash reaches the REMOTE only now — after both clones were taken.
git -C "$REMOTE" update-ref refs/heads/main "$T2"

for w in "$WA" "$WB" "$WC" "$WD" "$WE" "$WF" "$WG" "$WH"; do artifacts "$w"; done

# G's stale ref is CONSUMED by the run that refreshes it, so it is rewound before every battery.
# A battery inheriting the previous battery's refreshed ref would score `nofetch` green.
reset_g() { git -C "$WG" update-ref refs/remotes/origin/main "$C2"; }

# The worlds must actually hold the relations the arms are written against, or seven of them are
# arm A again and every verdict below is about one input.
_ck() { git -C "$1" rev-list --count HEAD..origin/main 2>/dev/null; }
if [ "$(_ck "$WA")" != "0" ] || [ "$(_ck "$WB")" != "$BEHIND" ] || [ "$(_ck "$WC")" != "0" ] \
   || [ "$(_ck "$WE")" != "0" ] || [ "$(_ck "$WF")" != "0" ] \
   || [ -n "$(_ck "$WD")" ] \
   || [ "$(_ck "$WG")" != "0" ] || [ "$(_ck "$WH")" != "0" ] \
   || [ "$(git -C "$WF" rev-list --count HEAD..main)" != "2" ] \
   || [ "$(git -C "$WE" rev-list --count origin/main..HEAD)" != "2" ] \
   || [ "$(git -C "$REMOTE" rev-list --count "${F1}..refs/heads/main")" != "$BEHIND" ]; then
  echo "FIXTURE ERROR: the worlds do not hold the relations the arms are written against." >&2
  exit 2
fi
# A..F must have NO remote, or their expected refresh state is not the one they are asserted on.
for w in "$WA" "$WB" "$WC" "$WD" "$WE" "$WF"; do
  git -C "$w" remote get-url origin >/dev/null 2>&1 \
    && { echo "FIXTURE ERROR: world $w has a remote named origin, so Check 7 would fetch in a world asserted to attempt none." >&2; exit 2; }
done
git -C "$WG" remote get-url origin >/dev/null 2>&1 \
  || { echo "FIXTURE ERROR: world G has no remote named origin, so its fetch arm could never fire." >&2; exit 2; }

# ============================================================================
# A toolchain dir per script under test: the real resolver under test, plus the three siblings
# whose published contract is an exit code, plus the real audit-anchor resolver Check 5 needs.
# ============================================================================
toolchain() { # <dir> <script-to-install-as-validate-mandatory-rules.sh>
  mkdir -p "$1"
  cp "$2" "$1/validate-mandatory-rules.sh"
  cp "$VAA" "$1/validate-audit-anchors.sh"
  printf '#!/bin/bash\nexit 0\n' > "$1/validate-cycle-commits.sh"
  printf '#!/bin/bash\nexit 0\n' > "$1/validate-retro-evidence.sh"
  printf '#!/bin/bash\nexit 0\n' > "$1/validate-retro-prereq.sh"
  chmod +x "$1"/*.sh
}

D_SUMMARY="Sprint 900: $((8 - 1)) of 8 checks verified; 1 SKIPPED (check 7)."

# battery <toolchain-dir> <tag> <mode> [worlds] -> space-separated tokens, one per world driven.
#
# TOKEN: <verdict>/<behind-count>/<refresh>/<remedy>/<summary-class>/<rc>
#   verdict  PASS | FAIL | SKIP | NONE (no CHECK 7 line at all) | OTHER[<line>] | SERIES-RAN
#   refresh  R refreshed | N NOT refreshed (fetch failed) | X no remote named origin | ? neither
#   remedy   m if the run printed `git merge origin/main` anywhere, else -
#   summary  all7 | skip7 (the check-7 skip sentence) | nosumm | other[<sentence>]
# Every field is a fact the check emits, so a subject printing nothing scores NONE/-/-/-/…
# and fails every arm rather than passing any.
#
# MODE `full` runs the whole 8-check series as a program. MODE `only` SOURCES the toolchain copy
# of the validator and calls its check7() function: the main guard in the subject keeps the series
# from running on a source, and check7() is the same function the series calls, so the code run is
# the code shipped and no flag exists that could skip a check at the gate. Every mutant edits
# Check 7 and nothing else, so `only` is the question each mutant is about. Each run's output and
# rc are kept at $WORK/out-<tag>-<world>[.rc] so assertions 2-4 read the SAME runs as the battery.
cat > "$WORK/c7-driver.sh" <<'DRIVER'
. "$1/validate-mandatory-rules.sh" || exit 2
check7
rc=0
if [ "$FAILURES" -ne 0 ]; then rc=1; echo "Failure details:" >&2; printf '%s' "$FAILURE_MSGS" >&2; fi
echo "C7-DRIVER: failures=$FAILURES skipped=${SKIPPED_CHECKS# }"
exit $rc
DRIVER

A_ORDER="a b c d e f g h"
battery() {
  local D="$1" tag="$2" mode="$3" worlds="${4:-$A_ORDER}" out rc t="" cur="" w wp
  run()  { if [ "$mode" = only ]; then out="$( cd "$1" && bash "$WORK/c7-driver.sh" "$D" 2>&1 )"; rc=$?
           else out="$( cd "$1" && bash "$D/validate-mandatory-rules.sh" 900 2>&1 )"; rc=$?; fi
           printf '%s\n' "$out" > "$WORK/out-$tag-$cur"; printf '%s' "$rc" > "$WORK/out-$tag-$cur.rc"; }
  c7()   { awk '/^  CHECK 7: /{ sub(/^[ ]+/,""); print; exit }' <<<"$out"; }
  summ() {
    if [ "$mode" = only ]; then
      case "$out" in
        *'C7-DRIVER: failures=0 skipped=7'*) printf '%s' "$D_SUMMARY" ;;
        *'C7-DRIVER: failures=0 skipped='*)  printf 'Sprint 900: all 8 checks passed' ;;
      esac
    else awk '/checks (passed|verified)/{ sub(/^[ ]+/,""); print; exit }' <<<"$out"; fi
  }
  tok() {
    local line vd n rf rmd sm
    line="$(c7)"
    case "$line" in
      "CHECK 7: PASS"*) vd=PASS ;;
      "CHECK 7: FAIL"*) vd=FAIL ;;
      "CHECK 7: SKIP"*) vd=SKIP ;;
      "")               vd=NONE ;;
      *)                vd="OTHER[$line]" ;;
    esac
    # A source must define and run nothing else: the series banner means the guard did not hold.
    if [ "$mode" = only ]; then case "$out" in *'[Check 1]'*) vd=SERIES-RAN ;; esac; fi
    n="$(sed -n 's/.*HEAD is \([0-9][0-9]*\) commit(s) behind.*/\1/p' <<<"$line")"
    [ -n "$n" ] || n="-"
    case "$line" in
      *'(origin/main refreshed)'*)  rf=R ;;
      *'NOT refreshed'*)            rf=N ;;
      *'no remote named origin'*)   rf=X ;;
      "")                           rf="-" ;;
      *)                            rf="?" ;;
    esac
    if grep -qF 'git merge origin/main' <<<"$out"; then rmd=m; else rmd="-"; fi
    sm="$(summ)"
    case "$sm" in
      "Sprint 900: all 8 checks passed") sm=all7 ;;
      "$D_SUMMARY")                      sm=skip7 ;;
      "")                                sm=nosumm ;;
      *)                                 sm="other[$sm]" ;;
    esac
    printf '%s/%s/%s/%s/%s/%s' "$vd" "$n" "$rf" "$rmd" "$sm" "$rc"
  }

  for w in $A_ORDER; do
    case " $worlds " in *" $w "*) ;; *) continue ;; esac
    case "$w" in a) wp="$WA" ;; b) wp="$WB" ;; c) wp="$WC" ;; d) wp="$WD" ;; e) wp="$WE" ;; f) wp="$WF" ;; g) wp="$WG" ;; h) wp="$WH" ;; esac
    cur="$w"
    # G — THE STALE CLONE. The pre-state is asserted in the same breath as the run: without a
    #     stale ref going in, this arm is arm B with a remote and proves nothing about the fetch.
    if [ "$w" = g ]; then
      reset_g
      if [ "$(git -C "$WG" rev-list --count HEAD..origin/main)" != "0" ]; then t="$t g:PRESTATE-NOT-STALE"; continue; fi
    fi
    run "$wp"; t="$t $w:$(tok)"
  done
  printf '%s' "${t# }"
}

# tokof <tokens> <key> -> the one token keyed <key>; pick <tokens> <order> <keys> -> those, in order.
tokof() { local x; for x in $1; do case "$x" in "$2:"*) printf '%s' "$x"; return ;; esac; done; }
pick()  { local k o=""; for k in $2; do case " $3 " in *" $k "*) o="$o $(tokof "$1" "$k")" ;; esac; done; printf '%s' "${o# }"; }
# header_spec <mutant> -> "<decides> <twins>" read from this file's own MUTANT-MATRIX lines.
header_spec() {
  local sp dc tw
  sp="$(awk -v t="$1" '$1=="#" && $2=="MUTANT-MATRIX" && $3==t {print $4, $5; exit}' "$0")"
  dc="${sp%% *}"; dc="${dc#decides=}"; tw="${sp##* }"; tw="${tw#twins=}"
  if [ -z "$dc" ] || [ -z "$tw" ] || [ "$dc" = "$sp" ]; then
    echo "FIXTURE ERROR: mutant '$1' has no '# MUTANT-MATRIX $1 decides=<arm> twins=<arm>' header line." >&2
    exit 2
  fi
  HDR_DEC="${dc//,/ }"; HDR_TWN="${tw//,/ }"
  # `twins=-` means the measured row is dead in every cell: no arm to drive, and "-" is never an arm.
  [ "$HDR_TWN" = "-" ] && HDR_TWN=""
}
# matrix_row <mutant> <decides> <twins> <order> <got> <expected>
matrix_row() {
  local k row="" dead="" cell tw_state=GREEN
  for k in $4; do
    if [ "$(tokof "$5" "$k")" = "$(tokof "$6" "$k")" ]; then cell=0; else cell=1; dead="$dead $k"; fi
    row="$row $k=$cell"
  done
  for k in $3; do case " $dead " in *" $k "*) tw_state=DEAD ;; esac; done
  [ -n "$3" ] || tw_state="NONE(twins=-: dead in every cell: $([ "$(wc -w <<<"$dead")" -eq "$(wc -w <<<"$4")" ] && echo yes || echo NO))"
  local twd="${3// /,}"; [ -n "$twd" ] || twd="-"
  echo "MATRIX-ROW $1 decides=${2// /,} twins=$twd twin-state=$tw_state cells:$row dead-set:${dead:- none}"
}

EXPECTED="a:PASS/-/X/-/all7/0 b:FAIL/${BEHIND}/X/m/nosumm/1 c:PASS/-/X/-/all7/0 d:SKIP/-/X/-/skip7/0 e:PASS/-/X/-/all7/0 f:PASS/-/X/-/all7/0 g:FAIL/${BEHIND}/R/m/nosumm/1 h:PASS/-/N/-/all7/0"

# --- 1. the shipping validator answers every arm ------------------------------
toolchain "$WORK/bin" "$VMR"
GOT="$(battery "$WORK/bin" ship full)"
if [ "$GOT" = "$EXPECTED" ]; then
  ok "all eight arms: a trunk-cut branch PASSes, the feature-cut branch FAILs naming ${BEHIND} commit(s) behind and the remedy, the remedy CLEARS it, a missing origin/main SKIPs and is counted as check 7, neither being ahead of origin/main nor trailing a local main that ran on moves the verdict, a clone whose stale ref hides the defect is REFRESHED and then fails at ${BEHIND}, and a clone that cannot reach its remote still decides and says the ref may be stale"
else
  bad "battery: expected [$EXPECTED], got [$GOT]"
fi

# --- 2. the failure message is actionable, not just non-zero ------------------
# retro.md reads this validator's OUTPUT as well as its exit code. A FAIL that does not name the
# count and the command is a stop with no next step.
OUT="$(cat "$WORK/out-ship-b")"; RC="$(cat "$WORK/out-ship-b.rc")"
if [ "$RC" -eq 1 ] \
   && grep -qF 'Check7_BRANCH_BEHIND_MAIN' <<<"$OUT" \
   && grep -qF "HEAD is ${BEHIND} commit(s) behind origin/main" <<<"$OUT" \
   && grep -qF "'git merge origin/main' on this branch" <<<"$OUT" \
   && grep -qF 'VALIDATE-MANDATORY-RULES: FAIL' <<<"$OUT"; then
  ok "the defect world's failure carries its check name, the derived behind count ${BEHIND}, the remedy command, and the FAIL headline"
else
  bad "the defect world's failure was not actionable — rc=$RC, got: $OUT"
fi

# --- 3. the skip is a HEADLINE and a counted check, not a quiet line ----------
OUT="$(cat "$WORK/out-ship-d")"; RC="$(cat "$WORK/out-ship-d.rc")"
if [ "$RC" -eq 0 ] \
   && grep -qx 'VALIDATE-MANDATORY-RULES: PASS WITH SKIPS' <<<"$OUT" \
   && grep -qF '1 SKIPPED (check 7).' <<<"$OUT" \
   && grep -qF 'the verified floor here is 7, not 8' <<<"$OUT"; then
  ok "an unmeasurable checkout gets PASS WITH SKIPS naming check 7 and a floor of 7 — an unmeasurable branch is not certified fresh"
else
  bad "the skip world did not carry the skip headline and floor — rc=$RC, got: $OUT"
fi

# --- 4. the three refresh states, pinned by EXACT text, once ------------------
# The token above parses; this is the one place the wording itself is asserted, and it is also
# where "a sandbox with no remote attempts no fetch" is stated as an observable rather than as a
# claim about the code.
line_of() { awk '/^  CHECK 7: /{ print; exit }' <<<"$1"; }
OUT_A="$(cat "$WORK/out-ship-a")"; OUT_G="$(cat "$WORK/out-ship-g")"; OUT_H="$(cat "$WORK/out-ship-h")"
L_A='  CHECK 7: PASS — HEAD contains origin/main (origin/main not refreshed: no remote named origin)'
L_G="  CHECK 7: FAIL — HEAD is ${BEHIND} commit(s) behind origin/main (origin/main refreshed)"
L_H='  CHECK 7: PASS — HEAD contains origin/main (origin/main NOT refreshed: fetch failed, so the local ref may be stale)'
if [ "$(line_of "$OUT_A")" = "$L_A" ] \
   && [ "$(line_of "$OUT_G")" = "$L_G" ] \
   && [ "$(line_of "$OUT_H")" = "$L_H" ]; then
  ok "all three refresh states are named on the CHECK 7 line itself, byte for byte: no remote means no fetch attempted, a reachable remote means refreshed, and an unreachable one means the reader is told the ref may be stale beside a PASS"
else
  bad "a refresh state was not named as expected — A=[$(line_of "$OUT_A")] G=[$(line_of "$OUT_G")] H=[$(line_of "$OUT_H")]"
fi

# ============================================================================
# MUTANTS. Each is a COPY in its own toolchain directory, `cmp -s`-guarded so a sed that matched
# nothing cannot pass as a mutation, and each anchors on a line that occurs EXACTLY ONCE in the
# subject. Beside them sits an UNMUTATED CONTROL built the same way and asserting the eight
# baseline rows are THERE — without it, a copy that dies resolving ../schemas emits nothing and
# scores as a kill for every mutant at once.
#
# Each mutant declares the EXACT set of arms it moves, and no two share a moved-set:
#   deleted {a..h}   reversed {b,c,e,g,h}   silentskip {d}
#   localmain {f,g}  cutpoint {c}           nofetch {g,h}
# ============================================================================
toolchain "$WORK/mut-control" "$VMR"
CTL="$(battery "$WORK/mut-control" mut-control only)"
if [ "$CTL" = "$EXPECTED" ]; then
  ok "CONTROL: an unmutated copy in its own toolchain dir reproduces every arm — including the three PASS rows, the two FAIL rows and the SKIP row, so a mutant's silence below is the mutation and not the copy"
else
  echo "FIXTURE ERROR: the unmutated control does not reproduce the battery — expected [$EXPECTED], got [$CTL]." >&2
  echo "  Every mutant verdict below would be meaningless." >&2
  exit 2
fi

# The anchor instrument has to be able to report a zero, or "occurs exactly once" is a claim
# about a grep that always answers 1.
_n="$(grep -cF 'CHECK 7: NEVER-EMITTED-ANCHOR' "$VMR")" || _n=0
if [ "$_n" -ne 0 ]; then
  echo "FIXTURE ERROR: the impossible-anchor control matched ${_n} line(s) in the subject." >&2
  exit 2
fi

mutate() { # <tag> <fixed-anchor-that-must-occur-once> <sed-program> <expected-battery> <claim>
  local tag="$1" anchor="$2" prog="$3" want="$4" claim="$5"
  local D="$WORK/mut-$tag" M="$WORK/staged-$tag.sh" got n dec twn ws
  n="$(grep -cF -- "$anchor" "$VMR")" || n=0
  if [ "$n" -ne 1 ]; then
    echo "FIXTURE ERROR: mutant '$tag' anchors on a line occurring ${n} time(s), not once. A LOST SUBJECT is repaired with a new anchor, never with a relaxed assertion." >&2
    exit 2
  fi
  if ! sed "$prog" "$VMR" > "$M"; then
    bad "MUTANT $tag: DID NOT APPLY — sed exited non-zero, so no mutant was ever scored"
    return
  fi
  if cmp -s "$VMR" "$M"; then
    echo "FIXTURE ERROR: mutant '$tag' matched nothing — the line it targets was renamed, so it proves nothing." >&2
    exit 2
  fi
  if ! bash -n "$M" 2>/dev/null; then
    echo "FIXTURE ERROR: mutant '$tag' does not parse. Every arm would fail for a syntax error rather than for the property removed." >&2
    exit 2
  fi
  header_spec "$tag"; dec="$HDR_DEC"; twn="$HDR_TWN"
  toolchain "$D" "$M"
  if [ "$MATRIX" = 1 ]; then
    ws="$A_ORDER"
    got="$(battery "$D" "mut-$tag" only "$ws")"
    matrix_row "$tag" "$dec" "$twn" "$A_ORDER" "$got" "$EXPECTED"
    MCELLS=$((MCELLS + $(wc -w <<<"$A_ORDER") - $(wc -w <<<"$dec $twn")))
    # the full vector is the claim in matrix mode
    if [ "$got" = "$want" ]; then ok "MUTANT $tag [decides arm $dec, twin $twn]: $claim"
    elif [ "$got" = "$EXPECTED" ]; then bad "MUTANT $tag SURVIVED: $claim — every arm unchanged, so nothing here can catch it"
    else bad "MUTANT $tag ($claim): expected battery [$want], got [$got]"; fi
    return
  fi
  ws="$dec $twn"
  got="$(battery "$D" "mut-$tag" only "$ws")"
  if [ "$got" = "$(pick "$want" "$A_ORDER" "$ws")" ]; then
    ok "MUTANT $tag [decides arm $dec, twin $twn]: $claim"
  elif [ "$(pick "$got" "$A_ORDER" "$dec")" = "$(pick "$EXPECTED" "$A_ORDER" "$dec")" ]; then
    bad "MUTANT $tag SURVIVED: $claim — the deciding arm is unchanged, so nothing here can catch it"
  else
    bad "MUTANT $tag ($claim): expected arms [$(pick "$want" "$A_ORDER" "$ws")], got [$got]"
  fi
}

# --- deleted: Check 7 removed outright, refresh block and all. Every arm is presence-shaped on
# its CHECK 7 line, so all eight fall to NONE; arm B is the one that matters, because it is the
# defect going unreported at rc 0. The range runs to `  esac` and takes the closing `fi` with it
# (`N;d`), because the FIRST unindented `fi` in the block now closes the fetch — a range ending
# there would strip the refresh and leave `$C7_REFRESH` unset under `set -u`, which is a mutant
# that dies rather than one that omits the check.
_NONE='NONE/-/-/-/all7/0'
mutate deleted \
  'echo "[Check 7] Retro branch not behind origin/main..."' \
  '/^echo "\[Check 7\] Retro branch not behind origin\/main\.\.\."$/,/^  esac$/{ /^echo /s/.*/:/; /^  esac$/{N;d;}; /^:$/!d; }' \
  "a:$_NONE b:$_NONE c:$_NONE d:$_NONE e:$_NONE f:$_NONE g:$_NONE h:$_NONE" \
  "with the block gone every world reports rc 0 and no CHECK 7 line at all, the defect world included, and the skip world claims all 8 checks passed"

# --- reversed: `origin/main..HEAD` counts what HEAD has that origin/main lacks, which is
# divergence in the wrong direction: it acquits the defect world (reporting 1, not ${BEHIND}) and
# convicts every world that is legitimately ahead, refreshed or not.
mutate reversed \
  'HEAD..origin/main 2>/dev/null' \
  's@^  C7_BEHIND=.*@  C7_BEHIND="$(git rev-list --count origin/main..HEAD 2>/dev/null)" || C7_BEHIND=""@' \
  "a:PASS/-/X/-/all7/0 b:FAIL/1/X/m/nosumm/1 c:FAIL/2/X/m/nosumm/1 d:SKIP/-/X/-/skip7/0 e:FAIL/2/X/m/nosumm/1 f:PASS/-/X/-/all7/0 g:FAIL/1/R/m/nosumm/1 h:FAIL/1/N/m/nosumm/1" \
  "reversing the range mis-counts the defect world as 1 behind, fails the applied remedy, and fails branches that are merely AHEAD — the predicate is behind-count, not divergence"

# --- silentskip: the SKIP branch made a silent PASS. The check is unmeasurable and says PASS,
# and the summary stops naming it — an unmeasurable branch certified fresh, which is this repo's
# recurring class: a check that cannot fire reading exactly like one that passed.
mutate silentskip \
  'SKIPPED_CHECKS="$SKIPPED_CHECKS 7"' \
  's@^  echo "  CHECK 7: SKIP (no origin/main ref resolves.*@  echo "  CHECK 7: PASS"@; /^  SKIPPED_CHECKS="\$SKIPPED_CHECKS 7"$/d' \
  "a:PASS/-/X/-/all7/0 b:FAIL/${BEHIND}/X/m/nosumm/1 c:PASS/-/X/-/all7/0 d:PASS/-/?/-/all7/0 e:PASS/-/X/-/all7/0 f:PASS/-/X/-/all7/0 g:FAIL/${BEHIND}/R/m/nosumm/1 h:PASS/-/N/-/all7/0" \
  "a silent PASS on an unresolvable ref drops check 7 out of SKIPPED and the summary claims all 7 verified on a tree where freshness was never measured"

# --- nofetch: THE REFRESH REMOVED. Every no-remote world is untouched, which is the point: the
# only arms that can see this are the two with a remote, and world G is the one where the stale
# ref hides the defect the check exists for.
mutate nofetch \
  'if git remote get-url origin >/dev/null 2>&1; then' \
  '/^if git remote get-url origin >\/dev\/null 2>&1; then$/,/^fi$/d' \
  "a:PASS/-/X/-/all7/0 b:FAIL/${BEHIND}/X/m/nosumm/1 c:PASS/-/X/-/all7/0 d:SKIP/-/X/-/skip7/0 e:PASS/-/X/-/all7/0 f:PASS/-/X/-/all7/0 g:PASS/-/X/-/all7/0 h:PASS/-/X/-/all7/0" \
  "without the refresh the stale clone reads its own out-of-date ref, certifies the stranded-feature-ref branch as fresh at behind 0, and the unreachable-remote world stops telling its reader the ref may be stale"

# --- WRONG FIX 1: read the LOCAL `main` ref instead of `origin/main`. It is the substitution
# CLAUDE.md's release section already records ("cut release branches from origin/main, not from
# a local main that may be ahead of it"), it passes arms A through E because in every one of
# those worlds the two refs are equal, and only F and G can see it.
mutate localmain \
  'HEAD..origin/main 2>/dev/null' \
  's@^  C7_BEHIND=.*@  C7_BEHIND="$(git rev-list --count HEAD..main 2>/dev/null)" || C7_BEHIND=""@' \
  "a:PASS/-/X/-/all7/0 b:FAIL/${BEHIND}/X/m/nosumm/1 c:PASS/-/X/-/all7/0 d:SKIP/-/X/-/skip7/0 e:PASS/-/X/-/all7/0 f:FAIL/2/X/m/nosumm/1 g:PASS/-/R/-/all7/0 h:PASS/-/N/-/all7/0" \
  "WRONG FIX — measuring against local main fails a branch correctly cut from origin/main when the local trunk ran ahead, and acquits the stale clone because a fetch does not move a LOCAL branch; arms F and G are the only arms that see it"

# --- WRONG FIX 2: measure at the branch's CUT POINT instead of at HEAD — the branch's first
# commit's parent, i.e. "was origin/main contained when this branch was created". It answers
# every other arm identically and can never report the remedy as having worked, because a merge
# moves HEAD and never moves the commit the branch was cut from.
mutate cutpoint \
  'C7_BEHIND="$(git rev-list --count HEAD..origin/main 2>/dev/null)"' \
  's@^  C7_BEHIND=.*@  C7_CUT="$(git rev-list --reverse HEAD --not origin/main 2>/dev/null | head -1)"; if [ -z "$C7_CUT" ]; then C7_BEHIND=0; else C7_BEHIND="$(git rev-list --count "${C7_CUT}^..origin/main" 2>/dev/null)"; fi@' \
  "a:PASS/-/X/-/all7/0 b:FAIL/${BEHIND}/X/m/nosumm/1 c:FAIL/${BEHIND}/X/m/nosumm/1 d:SKIP/-/X/-/skip7/0 e:PASS/-/X/-/all7/0 f:PASS/-/X/-/all7/0 g:FAIL/${BEHIND}/R/m/nosumm/1 h:PASS/-/N/-/all7/0" \
  "WRONG FIX — keying on the branch's first commit still convicts the defect world, but the remedy the failure message names can never clear it; arm C is the only arm that separates the two"

# ============================================================================
# PART 2 — retro.md Step 1's CARRY. Deploy-validate keeps committing to the sprint branch after
# the sprint PR squash-merges, and a retro branch cut from origin/main alone holds none of it:
# the retro reads incomplete files and 7a-post rotates a gate log missing its deploy-validate
# block. Step 1 therefore derives the squash's PR head by TREE equality on the sprint branch's
# first-parent chain and cherry-picks what follows it onto the trunk-cut branch.
#
# THE SUBJECT IS THE SHIPPING BLOCK, EXTRACTED AND RUN. The fenced bash block that opens with
# `# retro Step 1:` is lifted out of retro.md, its two placeholders substituted, and executed in
# a clone of a `file://` remote — the block fetches, so every world has a real origin. Nothing
# here restates the block; a wording change that keeps its behaviour passes and a behaviour
# change moves a token.
#
# SEVEN WORLDS, one per outcome the block can reach, plus the one shape a naive range breaks:
#   carry       squash, one trunk commit after it, two sprint commits after the PR head
#   empty       the same with no sprint commit after the PR head — nothing to carry, no error
#   synced      the sprint branch committed, MERGED the trunk (squash included), and committed
#               again: the only world where `<pr-head>..<tip>` re-picks trunk commits and where
#               a walk that is not first-parent finds no fork point below the trunk
#   conflict    the post-squash sprint commit collides with a trunk commit
#   underivable the trunk moved between the PR's last sync and the squash, so no sprint tree
#               equals a trunk tree and the PR head cannot be derived
#   direct      the sprint tip is already on origin/main (fast-forward landing)
#   unresolved  the sprint branch is gone
#
# TEN RE-POINTED WORLDS, the gh fallback's own (the block asks gh only when the tree match misses
# and a fork point exists). One graph shape, built once per world (build_rp): an older PR #6
# (head H0, squash M0) lands first; the sprint PR #7 (head P) squash-merges as M; the sprint branch
# is then RESET onto M and takes K=3 post-squash commits (the re-pointed shape deploy-validate leaves);
# the trunk moves by one commit T. FORK is therefore M, no sprint tree after M equals a trunk tree,
# and only gh's mergeCommit can name P. K is 3 here and 2 in `carry`, so a printed count that is a
# constant cannot pass both.
#   repointed         truthful row `7 P M`, P local             -> carries 3, source "from gh" #7
#   repointed-nogh    PATH is a farm of symlinks to declared tools only, no gh -> gh unavailable
#   repointed-ghfail  the stub exits 1, prints nothing           -> exited non-zero
#   repointed-empty   the stub exits 0, prints nothing (`[]`)    -> lists no merged PR
#   repointed-badrow  `7 P null` (mergeCommit null)             -> a row that is not the shape
#   wrong-pr          only `6 H0 M0`: M0 is an ancestor of the tip, tree(H0)=tree(M0), M0 != FORK
#                                                                -> not exactly one
#   reused-branch     `8 T T` (newer, listed FIRST) then `7 P M`: T descends from M -> descend from
#   tree-mismatch     `7 TIP M`: TIP is local and its tree is not M's        -> differs
#   head-absent       `7 P M`, P is not in the clone, and origin's URL points nowhere (the block's
#                     first fetch fails non-fatally and the pull-ref fetch fails) -> not local
#   head-fetched      `7 P M`, P is not in the clone and exists ONLY as origin's refs/pull/7/head
#                     (GitHub's PR ref), so the block's pull-ref fetch is what makes it local -> carries 3
# THE gh STUB (write_gh_stub) is a bash script on PATH ahead of everything (`PATH=<stubdir>:$PATH`),
# copied per run with that world's rows/rc beside it. It answers ONLY the blocks' own argv, exactly
# `pr list --head ai-dlc/sprint-900 --state merged --json number,headRefOid,mergeCommit --jq
# <template>` (Step 1) and part 4's `pr merge 42 --squash --delete-branch` and `pr view 42 --json
# state --jq .state` (7a), and each only where the world seeded that shape's .rc file; any other
# argv logs `refused` and exits 97, which the token shows as R<n> so a refusal can never pass for
# the ghfail world. Its row bytes are the real producer's shape,
# captured read-only from `gh pr list ... --jq` on a real repository: one line
# `<number> <40 hex> <40 hex>` and a newline, 87 bytes for a 4-digit number; an empty list is 0
# bytes at exit 0. gh is NOT in tools.decl (the real one would resolve through the invoker's PATH);
# the stub needs only bash, dirname and cat. The seven original worlds get a stub too: `underivable`
# a truthful one (`5 P <squash>`, M != FORK, so "not exactly one" and it no longer depends on gh
# being absent), the other six a WRONG one (`41 <tip> <merge-base>`, which names the sprint tip as
# the PR head), and their token asserts the sentinel ABSENT: gh is never asked on a tree-match hit.
#
# TOKEN: <carry>/<behind>/<landed>/<evidence>/<picking>/<branch>/<gh>
#   carry     n<k> carried k | none-tip | none-empty | HB-unresolved | HB-underivable |
#             HB-conflict | NONE (no CARRY: line) | OTHER[<line>]
#             a count or none-empty line sourced from gh carries `@gh#<n>` (the PR number it
#             printed); an underivable line carries `@<reason>` from its `; gh fallback:` clause:
#             unavail | rc | empty | row | one | newer | local | tree | ? (unrecognised).
#             More than one CARRY: line appends `+L<count>`.
#   gh        - the stub was never called | <n> accepted calls | R<n> any call was refused
#   behind    `git rev-list --count HEAD..origin/main` after the block
#   landed    y if the commit that landed the sprint on the trunk is an ancestor of HEAD
#   evidence  how many of the two post-squash markers HEAD carries: `REVISION 3` in the gate
#             log and `DV-1` in the escalation log — the two greps the filing measured at 0
#   picking   y if a cherry-pick is still in progress (CHERRY_PICK_HEAD present)
#   branch    y if HEAD is the retro branch
# ============================================================================
echo
echo "retro-branch-behind-main: part 2 — retro.md Step 1 carry (subject $RETRO)"

extract_block() { # <retro.md> -> the Step 1 carry block, fences excluded
  awk '/^### 1\. Context Loading/{s=1} s && /^### 2\./{exit}
       s && /^# retro Step 1:/{on=1} on && /^```$/{exit} on{print}' "$1"
}
# ============================================================================
# PENDING: A SUBJECT THAT HAS NOT ARRIVED YET IS NOT A FAILURE, AND A BROKEN ONE IS. This fixture
# ships ahead of its subject (retro.md is rulebook and lands only when a consumer's reconcile PR
# merges), and any non-zero exit is a red consumer push. So each part whose subject is ABSENT
# prints ONE `  PENDING  ` row naming it, skips the arms that need it, and the run exits 0 when
# every other arm is ok. ABSENT is decided ONLY from the subject's own text, never from a world's
# output, and only when EVERY marker of the subject counts 0 (subject_state below):
#   carry block  the `# retro Step 1:` comment AND every `CARRY: ` token in retro.md
#   gh fallback  every line of the extracted Step 1 block naming GH_WHY, GH_ROWS, PR_SRC,
#                `command -v gh` or `gh pr list`
#   LAND block   the `# retro 7a-post step 1:` comment AND every `LAND: ` token in retro.md
#   MERGE block  the `# retro 7a:` comment AND every `MERGE: ` token in retro.md
# Any marker present means PRESENT, and a present subject is held to every arm: a kept comment
# over a gutted body, or one surviving fallback line, is RED. Arm `pending-gate` proves it on three
# seeds with the anchor kept and the block broken. The skipped arms are counted, and the liveness
# check requires asserted + skipped == the full count, so a skip cannot hide a lost arm.
#
# PENDING IS A CONSUMER-LAYOUT VERDICT ONLY. In the DISTRIBUTION (the root walk matched
# core/scripts/) retro.md ships in the same tree as this fixture and is always the new one, so an
# absent subject there is a reverted or broken subject: gate_verdict answers RED, pending() counts a
# FAILURE naming the part, and the run exits 1. Arm pending-layout drives a subject-absent copy
# through subject_state and gate_verdict in BOTH layouts; mutant pending-in-dist removes the layout
# check and is decided by that arm alone.
# ============================================================================
SKIPPED=0; PENDN=0; PENDBAD=0
case "$LAYOUT" in distribution|consumer) : ;; *) echo "FIXTURE ERROR: the root walk set no layout" >&2; exit 2 ;; esac
gate_verdict() { # <layout> <absent|present> -> assert | PENDING | RED
  if [ "$2" = present ]; then printf assert; return; fi
  if [ "$1" = distribution ]; then printf RED; return; fi
  printf PENDING
}
pending() { # <part> <subject> <what is not asserted> <skipped-arm-count>
  SKIPPED=$((SKIPPED + $4))
  if [ "$(gate_verdict "$LAYOUT" absent)" = RED ]; then
    PENDBAD=$((PENDBAD + 1))
    bad "$1: subject absent in the DISTRIBUTION — $2 is absent from $RETRO, which ships in this same tree and must carry it, so $3 (a reverted subject, never PENDING here)"
    return
  fi
  printf '  PENDING  %s: %s is absent from this retro.md, so %s (not a failure; the arms run when it arrives)\n' "$1" "$2" "$3"
  PENDN=$((PENDN + 1))
}
subject_state() { # <subject> <retro.md> -> absent | present
  local n=0 a b
  case "$1" in
    carry) a="$(grep -c '^# retro Step 1:' "$2")" || a=0; b="$(grep -c 'CARRY: ' "$2")" || b=0; n=$((a + b)) ;;
    fallback) n="$(extract_block "$2" | grep -cE 'GH_WHY|GH_ROWS|PR_SRC|command -v gh|gh pr list')" || n=0 ;;
    land) a="$(grep -c '^# retro 7a-post step 1:' "$2")" || a=0; b="$(grep -c 'LAND: ' "$2")" || b=0; n=$((a + b)) ;;
    merge) a="$(grep -c '^# retro 7a:' "$2")" || a=0; b="$(grep -c 'MERGE: ' "$2")" || b=0; n=$((a + b)) ;;
  esac
  if [ "$n" -eq 0 ]; then printf absent; else printf present; fi
}
ST_CARRY="$(subject_state carry "$RETRO")"
ST_FB="$(subject_state fallback "$RETRO")"
ST_LAND="$(subject_state land "$RETRO")"
ST_MERGE="$(subject_state merge "$RETRO")"
[ "$ST_CARRY" = absent ] && ST_FB=absent
# ARM pending-layout: one subject-absent retro.md (the resolved one with every LAND marker deleted)
# and its present twin (the same plus one LAND: line), each read by subject_state, each judged by
# gate_verdict in BOTH layouts. Presence-shaped: every cell must print its verdict word.
PLCELLS="dist-absent consumer-absent dist-present consumer-present"
PL_WANT="dist-absent:RED consumer-absent:PENDING dist-present:assert consumer-present:assert"
_pla="$WORK/pl-absent.md"; _plp="$WORK/pl-present.md"
sed -e '/LAND: /d' -e '/^# retro 7a-post step 1:/d' "$RETRO" > "$_pla"
{ cat "$_pla"; echo 'echo "LAND: main at origin/main"'; } > "$_plp"
if [ "$(subject_state land "$_pla")/$(subject_state land "$_plp")" != absent/present ]; then
  echo "FIXTURE ERROR: the pending-layout seeds are not absent/present ($(subject_state land "$_pla")/$(subject_state land "$_plp"))." >&2
  exit 2
fi
pl_vector() { # [gate-function file] -> the four cells, judged by gate_verdict (or by the file's copy)
  local c ly f st o=""
  for c in $PLCELLS; do
    case "$c" in dist-*) ly=distribution ;; *) ly=consumer ;; esac
    case "$c" in *-absent) f="$_pla" ;; *) f="$_plp" ;; esac
    st="$(subject_state land "$f")"
    if [ -n "${1:-}" ]; then o="$o $c:$( . "$1"; gate_verdict "$ly" "$st" )"
    else o="$o $c:$(gate_verdict "$ly" "$st")"; fi
  done
  printf '%s' "${o# }"
}
PL_GOT="$(pl_vector)"
if [ "$PL_GOT" = "$PL_WANT" ]; then
  ok "pending-layout: a subject-absent retro.md is RED in the distribution and PENDING in a consumer, and its present twin asserts in both [$PL_GOT]"
else
  bad "pending-layout: expected [$PL_WANT], got [$PL_GOT]"
fi
_plt=pending-in-dist
# mutant pending-in-dist: gate_verdict as this file defines it, extracted, with the layout check
# removed. The unmutated extract is the control: it must reproduce the in-script vector.
sed -n '/^gate_verdict() {/,/^}/p' "$0" > "$WORK/gv-control.sh"
sed '/^  if \[ "\$1" = distribution \]; then printf RED; return; fi$/d' "$WORK/gv-control.sh" > "$WORK/gv-pending-in-dist.sh" \
  || { bad "MUTANT $_plt: DID NOT APPLY — sed exited non-zero"; }
_gvn="$(grep -c '^  if \[ "\$1" = distribution \]; then printf RED; return; fi$' "$WORK/gv-control.sh")" || _gvn=0
_gvz="$(grep -c 'NEVER-EMITTED-N9-ANCHOR-zq' "$WORK/gv-control.sh")" || _gvz=0
if [ "$_gvn" != 1 ] || [ "$_gvz" != 0 ] || cmp -s "$WORK/gv-control.sh" "$WORK/gv-pending-in-dist.sh" \
   || [ "$(pl_vector "$WORK/gv-control.sh")" != "$PL_GOT" ]; then
  echo "FIXTURE ERROR: pending-in-dist anchors ${_gvn} time(s) (control ${_gvz}), matched nothing, or the extracted gate_verdict does not reproduce the in-script vector." >&2
  exit 2
fi
header_spec "$_plt"
_plm="$(pl_vector "$WORK/gv-pending-in-dist.sh")"
if [ "$MATRIX" = 1 ]; then
  matrix_row "$_plt" "$HDR_DEC" "$HDR_TWN" "$PLCELLS" "$_plm" "$PL_GOT"
  MCELLS=$((MCELLS + $(wc -w <<<"$PLCELLS") - $(wc -w <<<"$HDR_DEC $HDR_TWN")))
fi
if [ "$(pick "$_plm" "$PLCELLS" "$HDR_DEC $HDR_TWN")" = "dist-absent:PENDING consumer-absent:PENDING" ]; then
  ok "MUTANT $_plt [decides arm $HDR_DEC, twin $HDR_TWN]: without the layout check a subject-absent retro.md in the distribution is PENDING, and the consumer cell is unchanged"
else
  bad "MUTANT $_plt: expected [dist-absent:PENDING consumer-absent:PENDING], got [$(pick "$_plm" "$PLCELLS" "$HDR_DEC $HDR_TWN")]"
fi
# P2MODE: full (fallback present) | prefb (carry block present, fallback absent) | absent
if [ "$ST_CARRY" = absent ]; then P2MODE=absent; elif [ "$ST_FB" = absent ]; then P2MODE=prefb; else P2MODE=full; fi

BLOCK="$(extract_block "$RETRO")"
if [ "$P2MODE" != absent ]; then
  case "$BLOCK" in
    *'<sprint-branch>'*'<N>'*) : ;;
    *)
      echo "  FAIL  retro.md carries a Step 1 carry marker but no carry block naming <sprint-branch> and <N> — a present subject that is broken is a finding, not PENDING" >&2
      echo "retro-branch-behind-main: FAIL (part 2 subject broken)" >&2
      exit 1 ;;
  esac
fi

P2="$WORK/p2"; mkdir -p "$P2"
SB=ai-dlc/sprint-900
GL=_bmad-output/implementation-artifacts/gate-log.md
ESC=docs/escalations/pending.md

# build <world> -> $P2/<world>/{remote.git,clone} and $P2/<world>.landed
build() {
  local w="$1" s="$P2/$1/src" m="" landed=""
  mkdir -p "$s"
  git -c init.defaultBranch=main init -q "$s" || { echo "FIXTURE ERROR: part 2 init failed ($w)" >&2; exit 2; }
  git -C "$s" config user.email f@example.com; git -C "$s" config user.name Fixture
  git -C "$s" config commit.gpgsign false
  c() { git -C "$s" add -A && git -C "$s" commit -q -m "$1"; }
  mkdir -p "$s/$(dirname "$GL")" "$s/$(dirname "$ESC")" "$s/trunk"
  printf 'REVISION 1\n' > "$s/$GL"; printf '# pending\n' > "$s/$ESC"; c C1
  git -C "$s" checkout -q -b "$SB"
  printf 'REVISION 1\nREVISION 2\n' > "$s/$GL"; c "sprint work (the PR head)"
  git -C "$s" checkout -q main
  case "$w" in
    underivable) echo x > "$s/trunk/x.txt"; c "trunk moved before the squash" ;;
  esac
  if [ "$w" = direct ]; then
    git -C "$s" merge -q --ff-only "$SB"
  else
    git -C "$s" merge -q --squash "$SB" >/dev/null 2>&1; c "sprint (squashed)"
  fi
  landed="$(git -C "$s" rev-parse HEAD)"
  echo t1 > "$s/trunk/b.txt"; c "trunk after the squash"
  git -C "$s" checkout -q "$SB"
  case "$w" in
    carry|synced|underivable|unresolved)
      printf '# pending\nDV-1\n' > "$s/$ESC"; c "escalation after the squash"
      # synced: the sprint branch takes the trunk (squash and all) BETWEEN its two post-squash
      # commits. A merge taken before the first one would itself carry a trunk tree, become the
      # derived PR head, and make the plain range agree with the shipped one. The first commit
      # touches only the escalation log, which the trunk never changed, so the merge is clean.
      if [ "$w" = synced ]; then
        git -C "$s" merge -q --no-edit main >/dev/null 2>&1 || { echo "FIXTURE ERROR: synced world merge failed" >&2; exit 2; }
      fi
      printf 'REVISION 1\nREVISION 2\nREVISION 3\n' > "$s/$GL"; c "deploy-validate revision after the squash" ;;
    conflict)
      printf 'REVISION 1\nREVISION 2\nREVISION 3\n' > "$s/$GL"; mkdir -p "$s/trunk"; echo sprint > "$s/trunk/b.txt"
      c "post-squash commit colliding with the trunk" ;;
  esac
  git -C "$s" checkout -q main
  git clone -q --bare "$s" "$P2/$w/remote.git" 2>/dev/null || { echo "FIXTURE ERROR: part 2 bare clone failed ($w)" >&2; exit 2; }
  [ "$w" = unresolved ] && git -C "$P2/$w/remote.git" update-ref -d "refs/heads/$SB"
  git clone -q "file://$P2/$w/remote.git" "$P2/$w/clone" 2>/dev/null || { echo "FIXTURE ERROR: part 2 clone failed ($w)" >&2; exit 2; }
  git -C "$P2/$w/clone" config user.email f@example.com; git -C "$P2/$w/clone" config user.name Fixture
  git -C "$P2/$w/clone" config commit.gpgsign false
  if [ "$w" != unresolved ]; then
    git -C "$P2/$w/clone" checkout -q -b "$SB" "origin/$SB" || { echo "FIXTURE ERROR: part 2 sprint branch checkout failed ($w)" >&2; exit 2; }
  fi
  printf '%s' "$landed" > "$P2/$w.landed"
  # The gh rows this world's stub prints. `underivable` gets the TRUTH (its PR head and its squash,
  # which is not the fork point); every other original world a WRONG row naming the sprint tip as
  # the PR head under the fork point, which no tree-match hit may ever ask for.
  if [ "$w" = underivable ]; then
    printf '5 %s %s\n' "$(git -C "$s" rev-parse "$SB~2")" "$landed" > "$P2/$w.rows"
  else
    printf '41 %s %s\n' "$(git -C "$s" rev-parse "$SB")" "$(git -C "$s" merge-base "$SB" main)" > "$P2/$w.rows"
  fi
  printf '0' > "$P2/$w.ghrc"
}

# build_rp <world> -> the re-pointed graph (see TEN RE-POINTED WORLDS above), its rows and rc.
build_rp() {
  local w="$1" s="$P2/$1/src" cl="$P2/$1/clone" H0 M0 P M T TIP f
  mkdir -p "$s"
  git -c init.defaultBranch=main init -q "$s" || { echo "FIXTURE ERROR: part 2 init failed ($w)" >&2; exit 2; }
  git -C "$s" config user.email f@example.com; git -C "$s" config user.name Fixture
  git -C "$s" config commit.gpgsign false
  c() { git -C "$s" add -A && git -C "$s" commit -q -m "$1"; }
  mkdir -p "$s/$(dirname "$GL")" "$s/$(dirname "$ESC")" "$s/trunk" "$s/docs/dev"
  printf 'REVISION 1\n' > "$s/$GL"; printf '# pending\n' > "$s/$ESC"; c C1
  git -C "$s" checkout -q -b older-pr
  echo older > "$s/trunk/older.txt"; c "older PR head"; H0="$(git -C "$s" rev-parse HEAD)"
  git -C "$s" checkout -q main
  git -C "$s" merge -q --squash older-pr >/dev/null 2>&1; c "older PR (squashed)"; M0="$(git -C "$s" rev-parse HEAD)"
  git -C "$s" checkout -q -b "$SB"
  printf 'REVISION 1\nREVISION 2\n' > "$s/$GL"; c "sprint work (the PR head)"; P="$(git -C "$s" rev-parse HEAD)"
  git -C "$s" checkout -q main
  git -C "$s" merge -q --squash "$SB" >/dev/null 2>&1; c "sprint (squashed)"; M="$(git -C "$s" rev-parse HEAD)"
  # deploy-validate's re-point: the sprint branch reset onto the squash, then committed on.
  git -C "$s" checkout -q "$SB"; git -C "$s" reset -q --hard "$M"
  printf '# pending\nDV-1\n' > "$s/$ESC"; c "escalation after the squash"
  printf 'REVISION 1\nREVISION 2\nREVISION 3\n' > "$s/$GL"; c "deploy-validate revision after the squash"
  echo report > "$s/docs/dev/report.md"; c "dev report after the squash"
  TIP="$(git -C "$s" rev-parse HEAD)"
  git -C "$s" checkout -q main
  echo t1 > "$s/trunk/b.txt"; c "trunk after the squash"; T="$(git -C "$s" rev-parse HEAD)"
  # P and H0 survive only under refs a bare clone does not copy: the remote never holds them.
  git -C "$s" update-ref refs/keep/p "$P"; git -C "$s" update-ref refs/keep/h0 "$H0"
  git -C "$s" branch -q -D older-pr
  # --no-local: a local clone copies the whole object store, unreachable P included.
  git clone -q --bare --no-local "$s" "$P2/$w/remote.git" 2>/dev/null || { echo "FIXTURE ERROR: part 2 bare clone failed ($w)" >&2; exit 2; }
  git clone -q "file://$P2/$w/remote.git" "$cl" 2>/dev/null || { echo "FIXTURE ERROR: part 2 clone failed ($w)" >&2; exit 2; }
  git -C "$cl" config user.email f@example.com; git -C "$cl" config user.name Fixture
  git -C "$cl" config commit.gpgsign false
  git -C "$cl" checkout -q -b "$SB" "origin/$SB" || { echo "FIXTURE ERROR: part 2 sprint branch checkout failed ($w)" >&2; exit 2; }
  # The PR heads are LOCAL objects (no ref) except in head-absent, which also loses its remote, and
  # head-fetched, whose P exists ONLY as origin's refs/pull/7/head (GitHub's PR ref), fetched by the block.
  case "$w" in
    head-absent)
      git -C "$cl" fetch -q "file://$s" refs/keep/h0 2>/dev/null || { echo "FIXTURE ERROR: part 2 object fetch failed ($w)" >&2; exit 2; }
      git -C "$cl" remote set-url origin "file://$P2/$w/no-such-remote.git" ;;
    head-fetched)
      git -C "$cl" fetch -q "file://$s" refs/keep/h0 2>/dev/null || { echo "FIXTURE ERROR: part 2 object fetch failed ($w)" >&2; exit 2; } ;;
    *)
      git -C "$cl" fetch -q "file://$s" refs/keep/p refs/keep/h0 2>/dev/null || { echo "FIXTURE ERROR: part 2 object fetch failed ($w)" >&2; exit 2; } ;;
  esac
  printf '%s' "$M" > "$P2/$w.landed"
  # The relations every re-pointed arm is written against, refused here rather than read as a verdict.
  f="$(git -C "$cl" rev-list --first-parent "$SB" | while read -r x; do git -C "$cl" merge-base --is-ancestor "$x" origin/main && { echo "$x"; break; }; done)"
  if [ "$f" != "$M" ] \
     || [ -n "$(git -C "$cl" log --first-parent --format=%T "$SB" --not "$M" | grep -xF -f <(git -C "$cl" log --format=%T origin/main --not "$M"))" ] \
     || [ "$(git -C "$s" rev-parse "$P^{tree}")" != "$(git -C "$s" rev-parse "$M^{tree}")" ] \
     || [ "$(git -C "$s" rev-parse "$H0^{tree}")" != "$(git -C "$s" rev-parse "$M0^{tree}")" ] \
     || [ "$M0" = "$M" ] || ! git -C "$s" merge-base --is-ancestor "$M0" "$TIP" \
     || ! git -C "$s" merge-base --is-ancestor "$M" "$T" \
     || [ "$(git -C "$s" rev-list --count "$M..$TIP")" != 3 ] \
     || [ "$(git -C "$s" rev-parse "$TIP^{tree}")" = "$(git -C "$s" rev-parse "$M^{tree}")" ] \
     || git -C "$P2/$w/remote.git" cat-file -e "$P^{commit}" 2>/dev/null; then
    echo "FIXTURE ERROR: re-pointed world $w does not hold the relations its arm is written against." >&2
    exit 2
  fi
  if [ "$w" = head-fetched ]; then
    # P reaches origin only now, and only as the PR ref: the remote's heads never held it.
    git -C "$P2/$w/remote.git" fetch -q "$s" refs/keep/p:refs/pull/7/head 2>/dev/null \
      && [ "$(git -C "$P2/$w/remote.git" rev-parse refs/pull/7/head)" = "$P" ] \
      || { echo "FIXTURE ERROR: head-fetched's origin does not carry refs/pull/7/head at the PR head." >&2; exit 2; }
  fi
  if [ "$w" = head-absent ] || [ "$w" = head-fetched ]; then
    git -C "$cl" cat-file -e "$P^{commit}" 2>/dev/null && { echo "FIXTURE ERROR: $w's PR head is an object in its clone before the run." >&2; exit 2; }
  else
    git -C "$cl" cat-file -e "$P^{commit}" 2>/dev/null || { echo "FIXTURE ERROR: $w's PR head is not an object in its clone." >&2; exit 2; }
  fi
  : > "$P2/$w.rows"; printf '0' > "$P2/$w.ghrc"
  case "$w" in
    repointed|head-absent|head-fetched) printf '7 %s %s\n' "$P" "$M" > "$P2/$w.rows" ;;
    repointed-nogh)        : > "$P2/$w.nogh" ;;
    repointed-ghfail)      printf '1' > "$P2/$w.ghrc" ;;
    repointed-empty)       : ;;
    repointed-badrow)      printf '7 %s null\n' "$P" > "$P2/$w.rows" ;;
    wrong-pr)              printf '6 %s %s\n' "$H0" "$M0" > "$P2/$w.rows" ;;
    reused-branch)         printf '8 %s %s\n7 %s %s\n' "$T" "$T" "$P" "$M" > "$P2/$w.rows" ;;
    tree-mismatch)         printf '7 %s %s\n' "$TIP" "$M" > "$P2/$w.rows" ;;
    *) echo "FIXTURE ERROR: build_rp has no rows for world $w" >&2; exit 2 ;;
  esac
}

# The gh stub. It refuses every argv but the block's own, logs each call, and prints its rows.
write_gh_stub() { # <dir>
  cat > "$1/gh" <<'STUB'
#!/bin/bash
h="$(dirname "$0")"
T='.[] | "\(.number) \(.headRefOid) \(.mergeCommit.oid)"'
k=""
if [ "$#" = 10 ] && [ "$1" = pr ] && [ "$2" = list ] && [ "$3" = --head ] && [ "$4" = ai-dlc/sprint-900 ] \
   && [ "$5" = --state ] && [ "$6" = merged ] && [ "$7" = --json ] && [ "$8" = number,headRefOid,mergeCommit ] \
   && [ "$9" = --jq ] && [ "${10}" = "$T" ]; then k=list
elif [ "$#" = 5 ] && [ "$1" = pr ] && [ "$2" = merge ] && [ "$3" = 42 ] && [ "$4" = --squash ] && [ "$5" = --delete-branch ]; then k=merge
elif [ "$#" = 7 ] && [ "$1" = pr ] && [ "$2" = view ] && [ "$3" = 42 ] && [ "$4" = --json ] && [ "$5" = state ] \
   && [ "$6" = --jq ] && [ "$7" = .state ]; then k=view
fi
# A shape this world did not seed is refused as well: each world answers only what it declares.
if [ -n "$k" ] && [ -f "$h/$k.rc" ]; then
  echo "accepted $k" >> "$h/calls.log"
  cat "$h/$k.out"
  [ -f "$h/$k.err" ] && cat "$h/$k.err" >&2
  exit "$(cat "$h/$k.rc")"
fi
echo "refused $*" >> "$h/calls.log"
exit 97
STUB
  chmod +x "$1/gh"
}
[ "$SB" = ai-dlc/sprint-900 ] || { echo "FIXTURE ERROR: the gh stub hard-codes ai-dlc/sprint-900 and SB is $SB" >&2; exit 2; }

# The no-gh PATH: symlinks to the declared tools the block and git need, and nothing else.
FARM="$P2/farm"; mkdir -p "$FARM"
for t in bash git awk grep sed cat dirname basename head tail tr cut sort; do
  _tp="$(command -v "$t")" || { echo "FIXTURE ERROR: declared tool $t is not on PATH" >&2; exit 2; }
  ln -s "$_tp" "$FARM/$t"
done
if PATH="$FARM" command -v gh >/dev/null 2>&1 || ! PATH="$FARM" command -v git >/dev/null 2>&1; then
  echo "FIXTURE ERROR: the no-gh PATH farm resolves gh, or does not resolve git." >&2
  exit 2
fi

# STUB SELF-PROBE, both directions, for each of the three argv shapes the stub answers (Step 1's
# `pr list`, 7a's `pr merge` and `pr view`): the exact argv gets the seeded bytes and the seeded
# exit code; a near miss (one value changed) is refused with 97; a shape the probe dir did not
# seed (no merge.rc) is refused too. The log records accepted/refused in call order.
_sp="$P2/stub-probe"; mkdir -p "$_sp"; write_gh_stub "$_sp"
printf '7 %040d %040d\n' 1 2 > "$_sp/list.out"; printf '3' > "$_sp/list.rc"
printf 'MERGED\n' > "$_sp/view.out"; printf '0' > "$_sp/view.rc"
_spo="$("$_sp/gh" pr list --head ai-dlc/sprint-900 --state merged --json number,headRefOid,mergeCommit \
  --jq '.[] | "\(.number) \(.headRefOid) \(.mergeCommit.oid)"')"; _sprc=$?
"$_sp/gh" pr list --head ai-dlc/sprint-900 --state open --json number,headRefOid,mergeCommit \
  --jq '.[] | "\(.number) \(.headRefOid) \(.mergeCommit.oid)"' >/dev/null; _spnr=$?
_spv="$("$_sp/gh" pr view 42 --json state --jq .state)"; _spvrc=$?
"$_sp/gh" pr view 43 --json state --jq .state >/dev/null; _spvnr=$?
"$_sp/gh" pr merge 42 --squash --delete-branch >/dev/null; _spmnr=$?
if [ "$_sprc" = 3 ] && [ "$_spo" = "$(cat "$_sp/list.out")" ] && [ "$_spnr" = 97 ] \
   && [ "$_spvrc" = 0 ] && [ "$_spv" = MERGED ] && [ "$_spvnr" = 97 ] && [ "$_spmnr" = 97 ] \
   && [ "$(cut -d' ' -f1-2 "$_sp/calls.log")" = "$(printf 'accepted list\nrefused pr\naccepted view\nrefused pr\nrefused pr')" ]; then
  ok "gh stub self-probe: each of the three exact argv shapes gets its seeded bytes and exit code, a one-value near miss of each is refused with 97, an unseeded shape is refused, and every call is logged in order"
else
  bad "gh stub self-probe: list rc=$_sprc out=[$_spo] near-miss rc=$_spnr; view rc=$_spvrc out=[$_spv] near-miss rc=$_spvnr; unseeded merge rc=$_spmnr; log=[$(cat "$_sp/calls.log" 2>/dev/null)]"
fi

WORLDS2="carry empty synced conflict underivable direct unresolved repointed repointed-nogh repointed-ghfail repointed-empty repointed-badrow wrong-pr reused-branch tree-mismatch head-absent head-fetched"
# The worlds a part 2 run ASSERTS. Before the fallback arrives only the six worlds whose verdict the
# fallback did not change are asserted; `underivable` (now `@one`, gh asked) and the ten re-pointed
# worlds are the fallback's own, and are PENDING. With no carry block at all, none is.
W2OLD="carry empty synced conflict direct unresolved"
case "$P2MODE" in
  full)   W2ACT="$WORLDS2" ;;
  prefb)  W2ACT="$W2OLD"
          pending "part 2" "the Step 1 gh fallback (no GH_WHY, GH_ROWS, PR_SRC, command -v gh or gh pr list line in the Step 1 block)" \
            "the worlds underivable repointed repointed-nogh repointed-ghfail repointed-empty repointed-badrow wrong-pr reused-branch tree-mismatch head-absent head-fetched, the head-absent arm and the ten gh-fallback mutants are not asserted" 11 ;;
  absent) W2ACT=""
          pending "part 2" "the Step 1 carry block (no '# retro Step 1:' comment and no CARRY: token)" \
            "part 2's battery, its head-absent arm, its control and all seventeen part 2 mutants are not asserted" 20 ;;
esac
NW2="$(wc -w <<<"$W2ACT")"
if [ "$P2MODE" != absent ]; then
for w in $WORLDS2; do
  case "$w" in
    repointed*|wrong-pr|reused-branch|tree-mismatch|head-absent|head-fetched) build_rp "$w" ;;
    *) build "$w" ;;
  esac
done

# The worlds must hold the relations the arms are written against.
_t() { git -C "$P2/$1/src" rev-parse "$2^{tree}"; }
_sq() { git -C "$P2/$1/src" rev-parse "$(cat "$P2/$1.landed")^{tree}"; }
if [ "$(_t carry "$SB~2")" != "$(_sq carry)" ] \
   || [ "$(_t underivable "$SB~2")" = "$(_sq underivable)" ] \
   || ! git -C "$P2/direct/src" merge-base --is-ancestor "$SB" main \
   || git -C "$P2/carry/src" merge-base --is-ancestor "$SB" main \
   || [ "$(git -C "$P2/synced/src" rev-list --count --merges "main..$SB")" != "1" ] \
   || git -C "$P2/unresolved/clone" rev-parse --verify -q "$SB" >/dev/null; then
  echo "FIXTURE ERROR: the part 2 worlds do not hold the relations the arms are written against." >&2
  exit 2
fi
fi

# run_block <block-file> <world> -> token
run_block() {
  local b="$1" w="$2" d out line cr n ld ev pk br gs gh nl pth
  d="$P2/run-$(basename "$b" .sh)-$w"
  cp -R "$P2/$w/clone" "$d" || { echo "FIXTURE ERROR: could not copy world $w" >&2; exit 2; }
  # Every run has a gh on PATH that is the stub, or a PATH with no gh at all: never the real one.
  if [ -f "$P2/$w.nogh" ]; then
    pth="$FARM"
  else
    mkdir "$d.gh" && write_gh_stub "$d.gh" && cp "$P2/$w.rows" "$d.gh/list.out" && cp "$P2/$w.ghrc" "$d.gh/list.rc" \
      || { echo "FIXTURE ERROR: could not place the gh stub for world $w" >&2; exit 2; }
    pth="$d.gh:$PATH"
  fi
  out="$( cd "$d" && PATH="$pth" "$BASH" "$b" 2>&1 )"
  printf '%s\n' "$out" > "$d.out"
  line="$(grep -m1 '^CARRY: ' <<<"$out")"
  gs="$(sed -n 's/.*(merged PR #\([0-9][0-9]*\), from gh).*/\1/p' <<<"$line")"
  case "$line" in
    "CARRY: none — the sprint tip is already on origin/main") cr=none-tip ;;
    "CARRY: none — no sprint commit follows PR head "*)      cr="none-empty${gs:+@gh#$gs}" ;;
    "CARRY: HARD_BLOCK unresolved"*)   cr=HB-unresolved ;;
    "CARRY: HARD_BLOCK underivable"*)
      case "$line" in
        *"; gh fallback: gh unavailable"*)                          cr=HB-underivable@unavail ;;
        *"; gh fallback: gh pr list exited non-zero"*)              cr=HB-underivable@rc ;;
        *"; gh fallback: gh lists no merged PR"*)                   cr=HB-underivable@empty ;;
        *"; gh fallback: gh printed a row that is not"*)            cr=HB-underivable@row ;;
        *"; gh fallback: not exactly one merged PR"*)               cr=HB-underivable@one ;;
        *"; gh fallback: merged PR(s)"*"descend from"*)             cr=HB-underivable@newer ;;
        *"; gh fallback: PR head "*"not local and not fetchable"*)  cr=HB-underivable@local ;;
        *"; gh fallback: the tree of PR head "*" differs from "*)   cr=HB-underivable@tree ;;
        *"; gh fallback: "*)                                        cr="HB-underivable@?" ;;
        *)                                                          cr=HB-underivable ;;
      esac ;;
    "CARRY: HARD_BLOCK conflict"*)     cr=HB-conflict ;;
    "CARRY: "[0-9]*" commit(s) past PR head "*) cr="n$(sed -n 's/^CARRY: \([0-9][0-9]*\) .*/\1/p' <<<"$line")${gs:+@gh#$gs}" ;;
    "") cr=NONE ;;
    *)  cr="OTHER[$line]" ;;
  esac
  nl="$(grep -c '^CARRY: ' <<<"$out")" || nl=0
  [ "$nl" -gt 1 ] && cr="$cr+L$nl"
  if [ ! -e "$d.gh/calls.log" ]; then gh="-"
  elif grep -q '^refused' "$d.gh/calls.log"; then gh="R$(grep -c . "$d.gh/calls.log")"
  else gh="$(grep -c '^accepted list$' "$d.gh/calls.log")"; fi
  n="$(git -C "$d" rev-list --count HEAD..origin/main 2>/dev/null)" || n="?"
  if git -C "$d" merge-base --is-ancestor "$(cat "$P2/$w.landed")" HEAD 2>/dev/null; then ld=y; else ld=n; fi
  ev=0
  grep -q 'REVISION 3' <<<"$(git -C "$d" show "HEAD:$GL" 2>/dev/null)" && ev=$((ev+1))
  grep -q 'DV-1' <<<"$(git -C "$d" show "HEAD:$ESC" 2>/dev/null)" && ev=$((ev+1))
  if [ -e "$d/.git/CHERRY_PICK_HEAD" ]; then pk=y; else pk=n; fi
  if [ "$(git -C "$d" symbolic-ref -q --short HEAD)" = ai-dlc/retro/sprint-900 ]; then br=y; else br=n; fi
  printf '%s/%s/%s/%s/%s/%s/%s' "$cr" "$n" "$ld" "$ev" "$pk" "$br" "$gh"
}
# battery2 <retro.md copy> <tag> [worlds] -> one token per world driven
battery2() {
  local f="$1" tag="$2" worlds="${3:-$W2ACT}" b t="" w
  b="$P2/$tag.sh"
  extract_block "$f" | sed -e "s@<sprint-branch>@$SB@g" -e 's@<N>@900@g' > "$b"
  bash -n "$b" 2>/dev/null || { printf 'PARSE-ERROR'; return; }
  for w in $WORLDS2; do
    case " $worlds " in *" $w "*) ;; *) continue ;; esac
    t="$t $w:$(run_block "$b" "$w")"
  done
  printf '%s' "${t# }"
}

EXPECTED2="carry:n2/0/y/2/n/y/- empty:none-empty/0/y/0/n/y/- synced:n2/0/y/2/n/y/- conflict:HB-conflict/0/y/0/n/y/- underivable:HB-underivable@one/0/y/0/n/y/1 direct:none-tip/0/y/0/n/y/- unresolved:HB-unresolved/0/y/0/n/y/- repointed:n3@gh#7/0/y/2/n/y/1 repointed-nogh:HB-underivable@unavail/0/y/0/n/y/- repointed-ghfail:HB-underivable@rc/0/y/0/n/y/1 repointed-empty:HB-underivable@empty/0/y/0/n/y/1 repointed-badrow:HB-underivable@row/0/y/0/n/y/1 wrong-pr:HB-underivable@one/0/y/0/n/y/1 reused-branch:HB-underivable@newer/0/y/0/n/y/1 tree-mismatch:HB-underivable@tree/0/y/0/n/y/1 head-absent:HB-underivable@local/0/y/0/n/y/1 head-fetched:n3@gh#7/0/y/2/n/y/1"
# fbmap <tokens> -> those of the ASSERTED worlds only; before the fallback arrives a token also loses
# what only the fallback can print (an @<source|reason> on its carry field, a gh call count).
fbmap() {
  local x k v o=""
  for x in $1; do
    k="${x%%:*}"; case " $W2ACT " in *" $k "*) ;; *) continue ;; esac
    v="${x#*:}"
    [ "$P2MODE" = prefb ] && v="$(sed -E 's#^([^/@]*)@[^/]*/#\1/#; s#/[^/]*$#/-#' <<<"$v")"
    o="$o $k:$v"
  done
  printf '%s' "${o# }"
}
EXPECTED2="$(fbmap "$EXPECTED2")"
GHMUT="gh-primary no-gh-guard ancestry-accepts no-newest-guard no-tree-check rc-ignored no-empty-guard no-row-shape no-head-guard no-head-fetch"

if [ "$P2MODE" != absent ]; then
GOT2="$(battery2 "$RETRO" ship)"
if [ "$GOT2" = "$EXPECTED2" ]; then
  ok "part 2, ${NW2} worlds: the retro branch is trunk-cut and 0 behind in every world, carries both post-squash commits (also when the sprint branch merged the trunk after the squash), reports an empty carry as none without error, and stops on a conflict, an underivable PR head and a missing sprint branch with a named HARD_BLOCK and no pick left in progress; gh is never asked on a tree-match hit; a sprint branch re-pointed onto its squash carries its 3 post-squash commits from the PR head gh names by mergeCommit == fork point, and every gh failure (absent, non-zero, empty, malformed row, no exact row, a newer PR, a non-local head, a tree mismatch) is a named underivable HARD_BLOCK"
else
  bad "part 2 battery: expected [$EXPECTED2], got [$GOT2]"
fi
# head-absent: the not-local stop must be the ONLY stop. A head that is not an object must never
# reach the pick (a HARD_BLOCK conflict would be the carry running on a PR head it never resolved).
if [ "$P2MODE" = full ]; then
_ha="$P2/run-ship-head-absent.out"
_hac="$(grep -c 'HARD_BLOCK conflict' "$_ha")" || _hac=0
_hau="$(grep -c '^CARRY: HARD_BLOCK underivable .*; gh fallback: PR head .* of #7 not local and not fetchable$' "$_ha")" || _hau=0
if [ "$_hac" = 0 ] && [ "$_hau" = 1 ]; then
  ok "head-absent: one underivable line naming PR #7's head as not local and not fetchable, and no HARD_BLOCK conflict line"
else
  bad "head-absent: ${_hac} HARD_BLOCK conflict line(s) (want 0) and ${_hau} not-local underivable line(s) (want 1) in $_ha"
fi
fi

# CONTROL, folded into the ship run: an unmutated copy of retro.md is byte-identical to the
# subject, so it extracts the identical block and a second drive of it would only repeat GOT2.
cp "$RETRO" "$P2/control.md"
if cmp -s "$RETRO" "$P2/control.md" && [ "$(extract_block "$P2/control.md")" = "$BLOCK" ] && [ "$GOT2" = "$EXPECTED2" ]; then
  ok "part 2 CONTROL: an unmutated copy reproduces all ${NW2} worlds, so a mutant's token below is the mutation"
else
  echo "FIXTURE ERROR: the part 2 control does not reproduce the battery — expected [$EXPECTED2], got [$GOT2]." >&2
  exit 2
fi
fi

# mutate2 <tag> <anchor occurring once in retro.md> <sed-program> <expected> <claim>
mutate2() {
  local tag="$1" anchor="$2" prog="$3" want="$4" claim="$5" m="$P2/m-$1.md" n got dec twn ws
  # PENDING skips are counted where the PENDING row is printed; a gh mutant needs the fallback.
  [ "$P2MODE" = absent ] && return
  case " $GHMUT " in *" $tag "*) [ "$P2MODE" = prefb ] && return ;; esac
  want="$(fbmap "$want")"
  n="$(grep -cF -- "$anchor" "$RETRO")" || n=0
  if [ "$n" -ne 1 ]; then
    echo "FIXTURE ERROR: part 2 mutant '$tag' anchors on a line occurring ${n} time(s), not once." >&2
    exit 2
  fi
  # A program starting with @ names a sed -f script (the carry block's lines carry single quotes).
  case "$prog" in
    @*) sed -f "${prog#@}" "$RETRO" > "$m" || { bad "MUTANT $tag: DID NOT APPLY — sed exited non-zero"; return; } ;;
    *)  sed "$prog" "$RETRO" > "$m" || { bad "MUTANT $tag: DID NOT APPLY — sed exited non-zero"; return; } ;;
  esac
  if cmp -s "$RETRO" "$m"; then
    echo "FIXTURE ERROR: part 2 mutant '$tag' matched nothing." >&2
    exit 2
  fi
  header_spec "$tag"; dec="$HDR_DEC"; twn="$HDR_TWN"
  if [ "$MATRIX" = 1 ]; then
    got="$(battery2 "$m" "m-$tag" "$W2ACT")"
    matrix_row "$tag" "$dec" "$twn" "$W2ACT" "$got" "$EXPECTED2"
    MCELLS=$((MCELLS + NW2 - $(wc -w <<<"$dec $twn")))
    if [ "$got" = "$want" ]; then ok "MUTANT $tag [decides arm $dec, twin $twn]: $claim"
    elif [ "$got" = "$EXPECTED2" ]; then bad "MUTANT $tag SURVIVED: $claim — every world unchanged"
    else bad "MUTANT $tag ($claim): expected [$want], got [$got]"; fi
    return
  fi
  ws="$dec $twn"
  got="$(battery2 "$m" "m-$tag" "$ws")"
  if [ "$got" = "$(pick "$want" "$WORLDS2" "$ws")" ]; then
    ok "MUTANT $tag [decides arm $dec, twin $twn]: $claim"
  elif [ "$(pick "$got" "$WORLDS2" "$dec")" = "$(pick "$EXPECTED2" "$WORLDS2" "$dec")" ]; then
    bad "MUTANT $tag SURVIVED: $claim — the deciding world is unchanged"
  else
    bad "MUTANT $tag ($claim): expected [$(pick "$want" "$WORLDS2" "$ws")], got [$got]"
  fi
}

# The ten re-pointed worlds' expected tokens, shared by every mutant that leaves the fallback alone.
_RPW="repointed:n3@gh#7/0/y/2/n/y/1 repointed-nogh:HB-underivable@unavail/0/y/0/n/y/- repointed-ghfail:HB-underivable@rc/0/y/0/n/y/1 repointed-empty:HB-underivable@empty/0/y/0/n/y/1 repointed-badrow:HB-underivable@row/0/y/0/n/y/1 wrong-pr:HB-underivable@one/0/y/0/n/y/1 reused-branch:HB-underivable@newer/0/y/0/n/y/1 tree-mismatch:HB-underivable@tree/0/y/0/n/y/1 head-absent:HB-underivable@local/0/y/0/n/y/1 head-fetched:n3@gh#7/0/y/2/n/y/1"
# The seven original worlds' expected tokens, for the mutants that touch only the fallback.
_ORW="carry:n2/0/y/2/n/y/- empty:none-empty/0/y/0/n/y/- synced:n2/0/y/2/n/y/- conflict:HB-conflict/0/y/0/n/y/- underivable:HB-underivable@one/0/y/0/n/y/1 direct:none-tip/0/y/0/n/y/- unresolved:HB-unresolved/0/y/0/n/y/-"
# rp_with <world:token>... -> _RPW with those worlds' tokens replaced
rp_with() { local o="" x k r; for x in $_RPW; do k="${x%%:*}"; for r in "$@"; do case "$r" in "$k:"*) x="$r" ;; esac; done; o="$o $x"; done; printf '%s' "${o# }"; }

# --- carry-deleted: Step 1 as it stood before the carry. Every world reports no CARRY line, and
# the two worlds with post-squash evidence lose it — the filing's 0-and-0 greps.
_N0='NONE/0/y/0/n/y/-'
mutate2 carry-deleted \
  'if [ -z "$SPRINT_TIP" ]; then' \
  '/^if \[ -z "\$SPRINT_TIP" \]; then$/,/^fi$/d' \
  "carry:$_N0 empty:$_N0 synced:$_N0 conflict:$_N0 underivable:$_N0 direct:$_N0 unresolved:$_N0 repointed:$_N0 repointed-nogh:$_N0 repointed-ghfail:$_N0 repointed-empty:$_N0 repointed-badrow:$_N0 wrong-pr:$_N0 reused-branch:$_N0 tree-mismatch:$_N0 head-absent:$_N0 head-fetched:$_N0" \
  "without the carry the trunk-cut retro branch holds neither post-squash marker and nothing says so"

# --- WRONG FIX 1: cut the retro branch from the sprint tip. The markers arrive, and the branch
# no longer has the squash as an ancestor — the defect part 1 exists for.
mutate2 cut-from-tip \
  'git checkout -b ai-dlc/retro/sprint-<N> origin/main' \
  's@^git checkout -b ai-dlc/retro/sprint-<N> origin/main$@git checkout -b ai-dlc/retro/sprint-<N> "$SPRINT_TIP"@' \
  "carry:HB-conflict/2/n/2/n/y/- empty:none-empty/2/n/0/n/y/- synced:HB-conflict/0/y/2/n/y/- conflict:HB-conflict/2/n/1/n/y/- underivable:HB-underivable@one/3/n/2/n/y/1 direct:none-tip/1/y/0/n/y/- unresolved:HB-unresolved/0/y/0/n/n/- repointed:HB-conflict/1/y/2/n/y/1 repointed-nogh:HB-underivable@unavail/1/y/2/n/y/- repointed-ghfail:HB-underivable@rc/1/y/2/n/y/1 repointed-empty:HB-underivable@empty/1/y/2/n/y/1 repointed-badrow:HB-underivable@row/1/y/2/n/y/1 wrong-pr:HB-underivable@one/1/y/2/n/y/1 reused-branch:HB-underivable@newer/1/y/2/n/y/1 tree-mismatch:HB-underivable@tree/1/y/2/n/y/1 head-absent:HB-underivable@local/1/y/2/n/y/1 head-fetched:HB-conflict/1/y/2/n/y/1" \
  "WRONG FIX — a tip-cut retro branch trails origin/main and lacks the squash as an ancestor in every world the sprint did not already merge the trunk into"

# --- skip-guard removed: an empty carry list reaches cherry-pick, which refuses it.
mutate2 no-skip-guard \
  'if [ "$CARRY_N" = 0 ]; then' \
  's@^    if \[ "\$CARRY_N" = 0 \]; then$@    if false; then@' \
  "carry:n2/0/y/2/n/y/- empty:HB-conflict/0/y/0/n/y/- synced:n2/0/y/2/n/y/- conflict:HB-conflict/0/y/0/n/y/- underivable:HB-underivable@one/0/y/0/n/y/1 direct:none-tip/0/y/0/n/y/- unresolved:HB-unresolved/0/y/0/n/y/- $_RPW" \
  "without the count guard a sprint with nothing to carry is reported as a conflict HARD_BLOCK"

# --- abort removed: the conflict world is left mid-pick.
mutate2 no-abort \
  'git cherry-pick --abort' \
  '/^      git cherry-pick --abort$/d' \
  "carry:n2/0/y/2/n/y/- empty:none-empty/0/y/0/n/y/- synced:n2/0/y/2/n/y/- conflict:HB-conflict/0/y/0/y/y/- underivable:HB-underivable@one/0/y/0/n/y/1 direct:none-tip/0/y/0/n/y/- unresolved:HB-unresolved/0/y/0/n/y/- $_RPW" \
  "without the abort a conflicting carry leaves a cherry-pick in progress on the retro branch"

# --- WRONG FIX 2: the `<pr-head>..<tip>` range. Correct until the sprint branch merged the
# trunk after the squash; then the range re-picks trunk commits. The re-pointed world dies too:
# its PR head is not an ancestor of the tip, so the range reaches back to the squash itself.
mutate2 plain-range \
  'elif git cherry-pick --no-merges "$SPRINT_TIP" --not "$PR_HEAD" origin/main; then' \
  's@elif git cherry-pick --no-merges "\$SPRINT_TIP" --not "\$PR_HEAD" origin/main; then@elif git cherry-pick --no-merges "$PR_HEAD..$SPRINT_TIP"; then@' \
  "carry:n2/0/y/2/n/y/- empty:none-empty/0/y/0/n/y/- synced:HB-conflict/0/y/0/n/y/- conflict:HB-conflict/0/y/0/n/y/- underivable:HB-underivable@one/0/y/0/n/y/1 direct:none-tip/0/y/0/n/y/- unresolved:HB-unresolved/0/y/0/n/y/- repointed:HB-conflict/0/y/0/n/y/1 repointed-nogh:HB-underivable@unavail/0/y/0/n/y/- repointed-ghfail:HB-underivable@rc/0/y/0/n/y/1 repointed-empty:HB-underivable@empty/0/y/0/n/y/1 repointed-badrow:HB-underivable@row/0/y/0/n/y/1 wrong-pr:HB-underivable@one/0/y/0/n/y/1 reused-branch:HB-underivable@newer/0/y/0/n/y/1 tree-mismatch:HB-underivable@tree/0/y/0/n/y/1 head-absent:HB-underivable@local/0/y/0/n/y/1 head-fetched:HB-conflict/0/y/0/n/y/1" \
  "WRONG FIX — a sprint branch that merged the trunk after the squash makes the plain range re-pick trunk commits and stop"

# --- WRONG FIX 3: the merge-base as the PR head. It is the fork point, so the carry re-picks
# the PR's own work, which the squash already landed, and stops on it.
mutate2 merge-base \
  '  if [ -z "$PR_HEAD" ]; then' \
  's@^  if \[ -z "\$PR_HEAD" \]; then$@  PR_HEAD="$(git merge-base "$SPRINT_TIP" origin/main)"; if [ -z "$PR_HEAD" ]; then@' \
  "carry:HB-conflict/0/y/0/n/y/- empty:HB-conflict/0/y/0/n/y/- synced:HB-conflict/0/y/0/n/y/- conflict:HB-conflict/0/y/0/n/y/- underivable:HB-conflict/0/y/0/n/y/1 direct:none-tip/0/y/0/n/y/- unresolved:HB-unresolved/0/y/0/n/y/- repointed:n3@gh#7/0/y/2/n/y/1 repointed-nogh:n3/0/y/2/n/y/- repointed-ghfail:n3/0/y/2/n/y/1 repointed-empty:n3/0/y/2/n/y/1 repointed-badrow:n3/0/y/2/n/y/1 wrong-pr:n3/0/y/2/n/y/1 reused-branch:n3/0/y/2/n/y/1 tree-mismatch:n3/0/y/2/n/y/1 head-absent:n3/0/y/2/n/y/1 head-fetched:n3@gh#7/0/y/2/n/y/1" \
  "WRONG FIX — taking the merge-base as the PR head re-picks the squashed PR work, which is already on the trunk, and stops in every world that has a PR head"

# --- not first-parent: a full-history walk finds the post-squash trunk commit as the fork
# point on a synced branch, so no trunk tree is newer and the PR head reads underivable.
mutate2 all-parents \
  'FORK="$(git rev-list --first-parent "$SPRINT_TIP" \' \
  's@FORK="\$(git rev-list --first-parent "\$SPRINT_TIP" \\@FORK="$(git rev-list "$SPRINT_TIP" \\@' \
  "carry:n2/0/y/2/n/y/- empty:none-empty/0/y/0/n/y/- synced:HB-underivable@tree/0/y/0/n/y/1 conflict:HB-conflict/0/y/0/n/y/- underivable:HB-underivable@one/0/y/0/n/y/1 direct:none-tip/0/y/0/n/y/- unresolved:HB-unresolved/0/y/0/n/y/- repointed:n3@gh#7/0/y/2/n/y/1 repointed-nogh:HB-underivable@unavail/0/y/0/n/y/- repointed-ghfail:HB-underivable@rc/0/y/0/n/y/1 repointed-empty:HB-underivable@empty/0/y/0/n/y/1 repointed-badrow:HB-underivable@row/0/y/0/n/y/1 wrong-pr:HB-underivable@one/0/y/0/n/y/1 reused-branch:HB-underivable@newer/0/y/0/n/y/1 tree-mismatch:HB-underivable@tree/0/y/0/n/y/1 head-absent:HB-underivable@local/0/y/0/n/y/1 head-fetched:n3@gh#7/0/y/2/n/y/1" \
  "a walk that follows every parent reads a synced sprint branch as underivable and carries nothing"

# ---------------------------------------------------------------------------------------------
# THE gh FALLBACK'S MUTANTS. Each sed program is a file (the block's lines carry single quotes),
# each edits lines of the Step 1 block only (every address below occurs once in retro.md, which
# mutate2 re-checks), and each removes one guard.
SEDS="$P2/seds"; mkdir -p "$SEDS"

# --- gh-primary: the fallback runs whether or not the tree match found the PR head. Every
# tree-match world with a fork point now CALLS gh; its stub's wrong row then fails the tree guard,
# so the CARRY line is unchanged and the sentinel field is the only thing that moves.
cat > "$SEDS/gh-primary" <<'SED'
/^  if \[ -z "\$PR_HEAD" \] && \[ -n "\$FORK" \]; then$/c\
  if [ -n "$FORK" ]; then
SED
mutate2 gh-primary 'if [ -z "$PR_HEAD" ] && [ -n "$FORK" ]; then' "@$SEDS/gh-primary" \
  "carry:n2/0/y/2/n/y/1 empty:none-empty/0/y/0/n/y/1 synced:n2/0/y/2/n/y/1 conflict:HB-conflict/0/y/0/n/y/1 underivable:HB-underivable@one/0/y/0/n/y/1 direct:none-tip/0/y/0/n/y/- unresolved:HB-unresolved/0/y/0/n/y/- repointed:n3@gh#7/0/y/2/n/y/1 repointed-nogh:HB-underivable@unavail/0/y/0/n/y/- repointed-ghfail:HB-underivable@rc/0/y/0/n/y/1 repointed-empty:HB-underivable@empty/0/y/0/n/y/1 repointed-badrow:HB-underivable@row/0/y/0/n/y/1 wrong-pr:HB-underivable@one/0/y/0/n/y/1 reused-branch:HB-underivable@newer/0/y/0/n/y/1 tree-mismatch:HB-underivable@tree/0/y/0/n/y/1 head-absent:HB-underivable@local/0/y/0/n/y/1 head-fetched:n3@gh#7/0/y/2/n/y/1" \
  "gh asked on a tree-match hit: the sentinel of a world whose PR head the trees already named is no longer absent"

# --- no-gh-guard: no `command -v gh`; with no gh the call itself fails and reads as exited non-zero.
cat > "$SEDS/no-gh-guard" <<'SED'
/^    if ! command -v gh >\/dev\/null 2>&1; then$/c\
    if false; then
SED
mutate2 no-gh-guard 'if ! command -v gh >/dev/null 2>&1; then' "@$SEDS/no-gh-guard" \
  "$_ORW $(rp_with 'repointed-nogh:HB-underivable@rc/0/y/0/n/y/-')" \
  "without the availability guard a host with no gh is reported as a gh failure, not as gh unavailable"

# --- WRONG FIX: ancestry-accepts. Select the merged PR whose mergeCommit is an ancestor of the
# tip, instead of the one whose mergeCommit IS the fork point. The older PR #6 then passes every
# later guard (its head is local and its tree is its squash's) and its head is carried from.
cat > "$SEDS/ancestry-accepts" <<'SED'
/^    elif \[ "\$(awk -v f="\$FORK" '\$3 == f {n++} END {print n+0}' <<<"\$GH_ROWS")" != 1 \]; then$/c\
    elif [ "$(while read -r n h m; do git merge-base --is-ancestor "$m" "$SPRINT_TIP" && echo "$n"; done <<<"$GH_ROWS" | grep -c .)" != 1 ]; then
/^      read -r GH_N GH_H GH_M <<<"\$(awk -v f="\$FORK" '\$3 == f' <<<"\$GH_ROWS")"$/c\
      read -r GH_N GH_H GH_M <<<"$(while read -r n h m; do git merge-base --is-ancestor "$m" "$SPRINT_TIP" && echo "$n $h $m"; done <<<"$GH_ROWS")"
SED
mutate2 ancestry-accepts "'\$3 == f {n++} END {print n+0}'" "@$SEDS/ancestry-accepts" \
  "$_ORW $(rp_with 'wrong-pr:n3@gh#6/0/y/2/n/y/1')" \
  "WRONG FIX — keying on ancestry instead of mergeCommit == fork point accepts an older merged PR and carries from its head"

# --- no-newest-guard: a newer merged PR from the same branch name no longer stops the selection.
cat > "$SEDS/no-newest-guard" <<'SED'
/^      if \[ -n "\$GH_NEWER" \]; then$/c\
      if false; then
SED
mutate2 no-newest-guard 'if [ -n "$GH_NEWER" ]; then' "@$SEDS/no-newest-guard" \
  "$_ORW $(rp_with 'reused-branch:n3@gh#7/0/y/2/n/y/1')" \
  "without the newest-row guard a reused branch name carries from an older PR while a newer one descends from it"

# --- no-tree-check: the PR head is accepted without its tree equalling the squash's.
cat > "$SEDS/no-tree-check" <<'SED'
/^      elif \[ "\$(git rev-parse "\${GH_H}^{tree}")" != "\$(git rev-parse "\${GH_M}^{tree}")" \]; then$/c\
      elif false; then
SED
mutate2 no-tree-check 'elif [ "$(git rev-parse "${GH_H}^{tree}")" != "$(git rev-parse "${GH_M}^{tree}")" ]; then' "@$SEDS/no-tree-check" \
  "$_ORW $(rp_with 'tree-mismatch:none-empty@gh#7/0/y/0/n/y/1')" \
  "without the tree check a PR head whose tree is not the squash's is accepted and the carry silently reads empty"

# --- rc-ignored: gh's exit code is dropped (the assignment still runs), so a failed call falls
# through to the empty-output guard and is reported as an empty list.
cat > "$SEDS/rc-ignored" <<'SED'
/^    elif ! GH_ROWS="\$(gh pr list /s/elif ! GH_ROWS=/elif GH_ROWS=/
/^        --jq '\.\[\] | "\\(\.number) \\(\.headRefOid) \\(\.mergeCommit\.oid)"')"; then$/s/')"; then$/')" \&\& false; then/
SED
mutate2 rc-ignored 'elif ! GH_ROWS="$(gh pr list' "@$SEDS/rc-ignored" \
  "$_ORW $(rp_with 'repointed-ghfail:HB-underivable@empty/0/y/0/n/y/1')" \
  "without the exit-code test a gh that failed is reported as listing no merged PR"

# --- no-empty-guard: empty output reaches the row-shape test, whose here-string is one empty line.
cat > "$SEDS/no-empty-guard" <<'SED'
/^    elif \[ -z "\$GH_ROWS" \]; then$/c\
    elif false; then
SED
mutate2 no-empty-guard 'elif [ -z "$GH_ROWS" ]; then' "@$SEDS/no-empty-guard" \
  "$_ORW $(rp_with 'repointed-empty:HB-underivable@row/0/y/0/n/y/1')" \
  "without the empty guard an empty merged-PR list is misreported as a malformed row"

# --- no-row-shape: a malformed row reaches the selection and is reported as no exact row.
cat > "$SEDS/no-row-shape" <<'SED'
/^    elif grep -vqE '\^\[0-9\]+ \[0-9a-f\]{40} \[0-9a-f\]{40}\$' <<<"\$GH_ROWS"; then$/c\
    elif false; then
SED
mutate2 no-row-shape "grep -vqE '^[0-9]+ [0-9a-f]{40} [0-9a-f]{40}\$'" "@$SEDS/no-row-shape" \
  "$_ORW $(rp_with 'repointed-badrow:HB-underivable@one/0/y/0/n/y/1')" \
  "without the row-shape test a row with a null mergeCommit is misread as a well-formed list with no exact row"

# --- no-head-guard: the PR head's presence is never checked (nor fetched); a head that is not an
# object reaches the tree comparison and is misreported as a tree mismatch.
cat > "$SEDS/no-head-guard" <<'SED'
/^      elif ! git cat-file -e "\${GH_H}^{commit}" 2>\/dev\/null \\$/s/elif ! git cat-file/elif false \&\& ! git cat-file/
SED
mutate2 no-head-guard 'elif ! git cat-file -e "${GH_H}^{commit}" 2>/dev/null \' "@$SEDS/no-head-guard" \
  "$_ORW $(rp_with 'head-absent:HB-underivable@tree/0/y/0/n/y/1' 'head-fetched:HB-underivable@tree/0/y/0/n/y/1')" \
  "without the presence guard a PR head that is not an object is misreported as a tree mismatch"

# --- no-head-fetch: the PR head is never fetched from origin's PR ref. A head that exists only
# as refs/pull/<n>/head on origin (head-fetched) is reported as not local; a local head is untouched.
cat > "$SEDS/no-head-fetch" <<'SED'
/^          && ! { git fetch -q origin "pull\/\$GH_N\/head" 2>\/dev\/null && git cat-file -e "\${GH_H}^{commit}" 2>\/dev\/null; }; then$/c\
          ; then
SED
mutate2 no-head-fetch '&& ! { git fetch -q origin "pull/$GH_N/head"' "@$SEDS/no-head-fetch" \
  "$_ORW $(rp_with 'head-fetched:HB-underivable@local/0/y/0/n/y/1')" \
  "without the PR-ref fetch a PR head GitHub still holds under refs/pull/<n>/head is reported as not local"

# ============================================================================
# PART 3 — retro.md 7a-post step 1's LAND. After the retro PR merges, 7a-post rotates the
# merge-sensitive records ON THE TRUNK, and 7a never relies on `gh pr merge` having switched the
# checkout. The fenced block that opens with `# retro 7a-post step 1: land on the merged trunk`
# fetches, checks out main and fast-forwards it, and then asserts HEAD is the BRANCH main; it
# prints `LAND: main at origin/main` or a `LAND: HARD_BLOCK` naming the worktree holding main.
# The block is extracted from the resolved retro.md (either layout) and run in a clone of a
# `file://` remote whose main gained the merged retro commit AFTER the clone was taken.
#
# FOUR WORLDS:
#   land-ok        HEAD on the retro branch, local main behind origin/main -> lands, HEAD = main
#   land-wt        main is checked out in a LINKED worktree inside the world -> the checkout
#                  refuses; HARD_BLOCK naming that worktree, HEAD still the retro branch
#   land-diverged  local main carries a commit origin/main lacks -> the fast-forward refuses;
#                  HARD_BLOCK naming no worktree (main is held by the clone itself, filtered out)
#   land-tag       no branch main, a TAG main -> checkout detaches and the fast-forward SUCCEEDS;
#                  only the branch check refuses it, and no worktree holds a branch main
#
# TOKEN: <land>/<head>/<at>/<wt>/<rc>
#   land  ok | HB | NONE (no LAND: line) | OTHER[<line>]; more than one LAND: line appends +L<n>
#   head  main | retro | detached | other      (git symbolic-ref -q --short HEAD after the block)
#   at    y if HEAD is origin/main's commit
#   rc    the block's own exit: 0 | nz (every HARD_BLOCK line must end the block non-zero)
#   wt    the HARD_BLOCK's worktree: holder (the linked worktree) | self (the clone, which the
#         block must NOT name: it filters its own worktree out) | none |
#         other; - when no HARD_BLOCK line names one
# ============================================================================
echo
echo "retro-branch-behind-main: part 3 — retro.md 7a-post step 1 land (subject $RETRO)"

extract_land() { # <retro.md> -> the 7a-post step 1 block, fences excluded
  awk '/^# retro 7a-post step 1: land on the merged trunk$/{on=1} on && /^```$/{exit} on{print}' "$1"
}
# An ABSENT LAND block (subject_state: no comment and no LAND: token) is PENDING. A PRESENT one that
# is not exactly one comment-anchored block printing both outcomes is BROKEN, and FAILs, exit 1.
LBLOCK="$(extract_land "$RETRO")"
if [ "$ST_LAND" = absent ]; then
  pending "part 3" "the 7a-post step 1 LAND block (no '# retro 7a-post step 1:' comment and no LAND: token)" \
    "the worlds land-ok land-wt land-diverged land-tag, the part 3 control and the mutants land-pre-fix land-no-symref land-no-false land-names-self are not asserted" 6
else
_ln="$(grep -c '^# retro 7a-post step 1: land on the merged trunk$' "$RETRO")" || _ln=0
case "$_ln:$LBLOCK" in
  1:*'LAND: main at origin/main'*'LAND: HARD_BLOCK'*) : ;;
  *)
    echo "  FAIL  retro.md carries a LAND marker but ${_ln} '# retro 7a-post step 1: land on the merged trunk' block(s), not exactly one printing both LAND outcomes — a present subject that is broken is a finding, not PENDING" >&2
    echo "retro-branch-behind-main: FAIL (part 3 subject broken)" >&2
    exit 1 ;;
esac

P3="$WORK/p3"; mkdir -p "$P3"
RB=ai-dlc/retro/sprint-900
build_land() { # <world> -> $P3/<world>/{src,remote.git,clone[,holder]}
  local w="$1" s="$P3/$1/src" cl="$P3/$1/clone"
  mkdir -p "$s"
  git -c init.defaultBranch=main init -q "$s" || { echo "FIXTURE ERROR: part 3 init failed ($w)" >&2; exit 2; }
  git -C "$s" config user.email f@example.com; git -C "$s" config user.name Fixture
  git -C "$s" config commit.gpgsign false
  echo c1 > "$s/a.txt"; git -C "$s" add -A && git -C "$s" commit -q -m C1
  git clone -q --bare "$s" "$P3/$w/remote.git" 2>/dev/null || { echo "FIXTURE ERROR: part 3 bare clone failed ($w)" >&2; exit 2; }
  git clone -q "file://$P3/$w/remote.git" "$cl" 2>/dev/null || { echo "FIXTURE ERROR: part 3 clone failed ($w)" >&2; exit 2; }
  git -C "$cl" config user.email f@example.com; git -C "$cl" config user.name Fixture
  git -C "$cl" config commit.gpgsign false
  if [ "$w" = land-diverged ]; then
    echo local > "$cl/local.txt"; git -C "$cl" add -A && git -C "$cl" commit -q -m "local main only"
  fi
  git -C "$cl" checkout -q -b "$RB"
  echo retro > "$cl/retro.txt"; git -C "$cl" add -A && git -C "$cl" commit -q -m "retro work"
  case "$w" in
    land-wt)  git -C "$cl" worktree add -q "$P3/$w/holder" main 2>/dev/null || { echo "FIXTURE ERROR: part 3 worktree add failed" >&2; exit 2; } ;;
    land-tag) git -C "$cl" branch -q -D main && git -C "$cl" tag main "$(git -C "$cl" rev-parse origin/main)" \
                || { echo "FIXTURE ERROR: part 3 could not replace branch main by a tag" >&2; exit 2; } ;;
  esac
  # The retro PR merges on the REMOTE after the clone: the clone's main is behind origin's.
  echo merged > "$s/retro.txt"; git -C "$s" add -A && git -C "$s" commit -q -m "retro (squashed)"
  git -C "$P3/$w/remote.git" fetch -q "$s" +main:main 2>/dev/null || { echo "FIXTURE ERROR: part 3 remote advance failed ($w)" >&2; exit 2; }
}
WORLDS3="land-ok land-wt land-diverged land-tag"
NW3="$(wc -w <<<"$WORLDS3")"
for w in $WORLDS3; do build_land "$w"; done
# _ff <world> -> the exit codes of `merge-base --is-ancestor main origin/main` and of the reverse,
# read in a PROBE COPY that has fetched the advanced remote (the world itself never fetches before
# the block does). Exit 0/1 only: a 128 (an unresolvable sha) is a refusal, never "diverged".
_ff() {
  local p="$P3/ffprobe-$1" a b
  cp -R "$P3/$1/clone" "$p" && git -C "$p" fetch -q origin 2>/dev/null || { printf 'nofetch'; return; }
  git -C "$p" merge-base --is-ancestor main origin/main 2>/dev/null; a=$?
  git -C "$p" merge-base --is-ancestor origin/main main 2>/dev/null; b=$?
  printf '%s/%s' "$a" "$b"
}
# land-ok's main fast-forwards (0/1) and land-diverged's main neither contains nor is contained (1/1).
_ffok="$(_ff land-ok)"; _ffdv="$(_ff land-diverged)"
if [ "$(git -C "$P3/land-ok/clone" symbolic-ref -q --short HEAD)" != "$RB" ] \
   || [ "$(git -C "$P3/land-wt/holder" symbolic-ref -q --short HEAD)" != main ] \
   || git -C "$P3/land-tag/clone" show-ref -q --verify refs/heads/main \
   || ! git -C "$P3/land-tag/clone" show-ref -q --verify refs/tags/main \
   || [ "$_ffok" != 0/1 ] || [ "$_ffdv" != 1/1 ]; then
  echo "FIXTURE ERROR: the part 3 worlds do not hold the relations the arms are written against (fast-forward probe: land-ok $_ffok want 0/1, land-diverged $_ffdv want 1/1)." >&2
  exit 2
fi

# run_land <block-file> <world> -> token
run_land() {
  local b="$1" w="$2" d out line ld hd at wt nl p rc
  d="$P3/run-$(basename "$b" .sh)-$w"
  cp -R "$P3/$w" "$d" || { echo "FIXTURE ERROR: could not copy world $w" >&2; exit 2; }
  # cp -R leaves the linked worktree's admin files naming the ORIGINAL paths; re-link the copy.
  if [ -d "$d/holder" ]; then
    git -C "$d/clone" worktree repair "$d/holder" >/dev/null 2>&1 \
      && [ "$(git -C "$d/holder" rev-parse --git-common-dir 2>/dev/null)" = "$(cd "$d/clone/.git" && pwd -P)" ] \
      || { echo "FIXTURE ERROR: could not re-link the copied worktree of world $w" >&2; exit 2; }
  fi
  out="$( cd "$d/clone" && PATH="$FARM" "$BASH" "$b" 2>&1 )"; rc=$?
  [ "$rc" = 0 ] || rc=nz
  printf '%s\n' "$out" > "$d.out"
  line="$(grep -m1 '^LAND: ' <<<"$out")"
  case "$line" in
    "LAND: main at origin/main") ld=ok ;;
    "LAND: HARD_BLOCK — not on main at origin/main; main is checked out in worktree: "*) ld=HB ;;
    "") ld=NONE ;;
    *)  ld="OTHER[$line]" ;;
  esac
  nl="$(grep -c '^LAND: ' <<<"$out")" || nl=0
  [ "$nl" -gt 1 ] && ld="$ld+L$nl"
  case "$(git -C "$d/clone" symbolic-ref -q --short HEAD)" in
    main) hd=main ;; "$RB") hd=retro ;; "") hd=detached ;; *) hd=other ;;
  esac
  if [ "$(git -C "$d/clone" rev-parse HEAD)" = "$(git -C "$d/clone" rev-parse origin/main)" ]; then at=y; else at=n; fi
  wt="-"
  if [ "$ld" = HB ]; then
    p="${line#*main is checked out in worktree: }"
    if [ "$p" = none ]; then wt=none
    elif [ -d "$d/holder" ] && [ "$p" = "$(cd "$d/holder" && pwd -P)" ]; then wt=holder
    elif [ "$p" = "$(cd "$d/clone" && pwd -P)" ]; then wt=self
    else wt=other; fi
  fi
  printf '%s/%s/%s/%s/%s' "$ld" "$hd" "$at" "$wt" "$rc"
}
# battery3 <retro.md copy> <tag> [worlds] -> one token per world driven
battery3() {
  local f="$1" tag="$2" worlds="${3:-$WORLDS3}" b t="" w
  b="$P3/$tag.sh"
  extract_land "$f" > "$b"
  bash -n "$b" 2>/dev/null || { printf 'PARSE-ERROR'; return; }
  for w in $WORLDS3; do
    case " $worlds " in *" $w "*) ;; *) continue ;; esac
    t="$t $w:$(run_land "$b" "$w")"
  done
  printf '%s' "${t# }"
}

EXPECTED3="land-ok:ok/main/y/-/0 land-wt:HB/retro/n/holder/nz land-diverged:HB/main/n/none/nz land-tag:HB/detached/y/none/nz"
GOT3="$(battery3 "$RETRO" ship)"
if [ "$GOT3" = "$EXPECTED3" ]; then
  ok "part 3, ${NW3} worlds: the LAND block lands a retro-branch checkout on main at origin/main, and refuses with a HARD_BLOCK naming the holder when main is checked out in another worktree, naming the clone when main cannot fast-forward, and naming none when main is a tag (where the fast-forward itself succeeded on a detached HEAD)"
else
  bad "part 3 battery: expected [$EXPECTED3], got [$GOT3]"
fi
# CONTROL: the unmutated copy extracts the identical block, so a mutant's token is the mutation.
cp "$RETRO" "$P3/control.md"
if cmp -s "$RETRO" "$P3/control.md" && [ "$(extract_land "$P3/control.md")" = "$LBLOCK" ] && [ "$GOT3" = "$EXPECTED3" ]; then
  ok "part 3 CONTROL: an unmutated copy reproduces all ${NW3} worlds"
else
  echo "FIXTURE ERROR: the part 3 control does not reproduce the battery — expected [$EXPECTED3], got [$GOT3]." >&2
  exit 2
fi
fi

# mutate_p <part> <tag> <anchor occurring once in retro.md> <@sed-file> <expected> <claim>
# Parts 3 and 4, the same discipline as mutate2: a copy, cmp -s, DID NOT APPLY on a failing sed.
mutate_p() {
  local part="$1" tag="$2" anchor="$3" prog="$4" want="$5" claim="$6" m n got dec twn ws all exp bat nw
  case "$part" in
    3) all="$WORLDS3"; exp="$EXPECTED3"; bat=battery3; nw="$NW3"; m="$P3/m-$tag.md" ;;
    4) all="$WORLDS4"; exp="$EXPECTED4"; bat=battery4; nw="$NW4"; m="$P4/m-$tag.md" ;;
  esac
  n="$(grep -cF -- "$anchor" "$RETRO")" || n=0
  if [ "$n" -ne 1 ]; then
    echo "FIXTURE ERROR: part $part mutant '$tag' anchors on a line occurring ${n} time(s), not once." >&2
    exit 2
  fi
  sed -f "${prog#@}" "$RETRO" > "$m" || { bad "MUTANT $tag: DID NOT APPLY — sed exited non-zero"; return; }
  if cmp -s "$RETRO" "$m"; then
    echo "FIXTURE ERROR: part $part mutant '$tag' matched nothing." >&2
    exit 2
  fi
  header_spec "$tag"; dec="$HDR_DEC"; twn="$HDR_TWN"
  if [ "$MATRIX" = 1 ]; then
    got="$("$bat" "$m" "m-$tag" "$all")"
    matrix_row "$tag" "$dec" "$twn" "$all" "$got" "$exp"
    MCELLS=$((MCELLS + nw - $(wc -w <<<"$dec $twn")))
    if [ "$got" = "$want" ]; then ok "MUTANT $tag [decides arm $dec, twin $twn]: $claim"
    elif [ "$got" = "$exp" ]; then bad "MUTANT $tag SURVIVED: $claim — every world unchanged"
    else bad "MUTANT $tag ($claim): expected [$want], got [$got]"; fi
    return
  fi
  ws="$dec $twn"
  got="$("$bat" "$m" "m-$tag" "$ws")"
  if [ "$got" = "$(pick "$want" "$all" "$ws")" ]; then
    ok "MUTANT $tag [decides arm $dec, twin $twn]: $claim"
  elif [ "$(pick "$got" "$all" "$dec")" = "$(pick "$exp" "$all" "$dec")" ]; then
    bad "MUTANT $tag SURVIVED: $claim — the deciding world is unchanged"
  else
    bad "MUTANT $tag ($claim): expected [$(pick "$want" "$all" "$ws")], got [$got]"
  fi
}

if [ "$ST_LAND" = present ]; then
# --- land-pre-fix: item 1 as it stood, the bare chain with no verdict. The range opens at the
# block's on-disk check (`LAND_HOLD=`, which only this block assigns) and ends at the block's own
# unindented `fi`; only the chain line survives, its `elif ` and trailing backslash stripped. The
# block's leading `git fetch origin main` stays, a second fetch the bare chain repeats.
# A consumer's retro.md one pull behind carries the LAND block without the on-disk check (BL-997's
# subject, PENDING below): there the range opens at the block's own `if git fetch` line, as before.
if grep -q '^LAND_HOLD="\$( cd ' "$RETRO"; then
cat > "$SEDS/land-pre-fix" <<'SED'
/^LAND_HOLD="\$( cd /,/^fi$/{
/^elif git fetch origin main/!d
s/^elif //
s/ \\$//
}
SED
_lpf='elif git fetch origin main && git checkout main && git merge --ff-only origin/main \'
else
cat > "$SEDS/land-pre-fix" <<'SED'
/^if git fetch origin main && git checkout main && git merge --ff-only origin\/main \\$/,/^fi$/{
/^if git fetch origin main/!d
s/^if //
s/ \\$//
}
SED
_lpf='if git fetch origin main && git checkout main && git merge --ff-only origin/main \'
fi
mutate_p 3 land-pre-fix "$_lpf" "@$SEDS/land-pre-fix" \
  "land-ok:NONE/main/y/-/0 land-wt:NONE/retro/n/-/nz land-diverged:NONE/main/n/-/nz land-tag:NONE/detached/y/-/0" \
  "the bare chain prints no verdict: a main held by another worktree leaves HEAD on the retro branch and nothing says so"

# --- land-no-symref: drop the branch check; a tag named main lands a detached HEAD as success.
cat > "$SEDS/land-no-symref" <<'SED'
/^    && \[ "\$(git symbolic-ref -q --short HEAD)" = main \]; then$/c\
    ; then
SED
mutate_p 3 land-no-symref '&& [ "$(git symbolic-ref -q --short HEAD)" = main ]; then' "@$SEDS/land-no-symref" \
  "land-ok:ok/main/y/-/0 land-wt:HB/retro/n/holder/nz land-diverged:HB/main/n/none/nz land-tag:ok/detached/y/-/0" \
  "without the branch check a tag named main fast-forwards a detached HEAD and is reported as landed on main"

# --- land-no-false: the HARD_BLOCK branch no longer ends non-zero; a refused landing reads as a
# successful tool call. The address is the LAND line, and only the `  false` right after it goes.
cat > "$SEDS/land-no-false" <<'SED'
/echo "LAND: HARD_BLOCK — not on main at origin\/main; main is checked out in worktree: /{
n
/^  false$/d
}
SED
mutate_p 3 land-no-false 'echo "LAND: HARD_BLOCK — not on main at origin/main; main is checked out in worktree: ${MAIN_WT:-none}"' "@$SEDS/land-no-false" \
  "land-ok:ok/main/y/-/0 land-wt:HB/retro/n/holder/0 land-diverged:HB/main/n/none/0 land-tag:HB/detached/y/none/0" \
  "without the trailing false a LAND HARD_BLOCK exits 0, so a refused landing is a successful tool result"

# --- land-names-self: the own-worktree filter dropped; a main held by the clone itself is named
# as if another worktree held it.
cat > "$SEDS/land-names-self" <<'SED'
/^  \[ -n "\$MAIN_WT" \] && \[ "\$(cd "\$MAIN_WT" 2>\/dev\/null && pwd -P)" = "\$SELF_WT" \] && MAIN_WT=""$/d
SED
mutate_p 3 land-names-self '[ -n "$MAIN_WT" ] && [ "$(cd "$MAIN_WT" 2>/dev/null && pwd -P)" = "$SELF_WT" ] && MAIN_WT=""' "@$SEDS/land-names-self" \
  "land-ok:ok/main/y/-/0 land-wt:HB/retro/n/holder/nz land-diverged:HB/main/n/self/nz land-tag:HB/detached/y/none/nz" \
  "without the own-worktree filter a main that cannot fast-forward in this very checkout is blamed on a worktree holding it"
fi

# ============================================================================
# PART 4 — retro.md 7a's MERGE. `gh pr merge` exits non-zero after a remote-successful squash
# whenever its LOCAL cleanup fails, so the block decides from the PR's state on GitHub: on a
# non-zero merge exit it asks `gh pr view <n> --json state --jq .state` and only an exact MERGED
# counts. The block is extracted by its comment anchor, `<pr-number>` substituted with 42, and run
# with the same gh stub (the `pr merge` and `pr view` shapes) in an empty directory: the block
# runs no git. The view bytes are the real producer's: `MERGED` and a newline (7 bytes, captured
# read-only); a failing view prints 0 bytes to stdout and its error to stderr, at exit 1.
#
# SIX WORLDS (the state is ALWAYS read, whatever gh pr merge exits):
#   merge-ok              merge exits 0, view prints MERGED     -> merged
#   merge-exit0-open      merge exits 0, view prints OPEN       -> HARD_BLOCK OPEN (a queue took it)
#   merge-cleanup-failed  merge exits 1, view prints MERGED     -> merged (local cleanup failed)
#   merge-open            merge exits 1, view prints OPEN       -> HARD_BLOCK OPEN
#   merge-view-fails      merge exits 1, view exits 1, no bytes -> HARD_BLOCK state unreadable
#   merge-view-lowercase  merge exits 1, view prints merged     -> HARD_BLOCK merged (exact match)
#
# TOKEN: <merge>/<calls>/<rc>
#   merge  merged | merged-cleanup | HB[<reason, spaces as ->] | NONE | OTHER[<line>]; +L<n> if
#          more than one MERGE: line
#   calls  the stub's accepted calls in order (m = pr merge, v = pr view), R<n> if any refused
#   rc     the block's own exit: 0 | nz (a HARD_BLOCK must end the block non-zero)
# ============================================================================
echo
echo "retro-branch-behind-main: part 4 — retro.md 7a merge (subject $RETRO)"
extract_merge() { # <retro.md> -> the 7a block, fences excluded
  awk '/^# retro 7a: merge the retro PR, then read its state from GitHub$/{on=1} on && /^```$/{exit} on{print}' "$1"
}
# ABSENT (no comment and no MERGE: token) is PENDING; PRESENT but not exactly one comment-anchored
# block naming <pr-number> and printing both outcomes is BROKEN, and FAILs, exit 1.
MBLOCK="$(extract_merge "$RETRO")"
if [ "$ST_MERGE" = absent ]; then
  pending "part 4" "the 7a MERGE block (no '# retro 7a:' comment and no MERGE: token)" \
    "the worlds merge-ok merge-exit0-open merge-cleanup-failed merge-open merge-view-fails merge-view-lowercase, the part 4 control and the mutants merge-exit-only merge-exit-trusted merge-accept-any-state merge-case-fold merge-no-false are not asserted" 7
else
_mn="$(grep -c '^# retro 7a: merge the retro PR, then read its state from GitHub$' "$RETRO")" || _mn=0
case "$_mn:$MBLOCK" in
  1:*'<pr-number>'*'MERGE: merged'*'MERGE: HARD_BLOCK'*) : ;;
  *)
    echo "  FAIL  retro.md carries a MERGE marker but ${_mn} '# retro 7a: merge the retro PR, then read its state from GitHub' block(s), not exactly one naming <pr-number> and printing both MERGE outcomes — a present subject that is broken is a finding, not PENDING" >&2
    echo "retro-branch-behind-main: FAIL (part 4 subject broken)" >&2
    exit 1 ;;
esac
P4="$WORK/p4"; mkdir -p "$P4"
WORLDS4="merge-ok merge-exit0-open merge-cleanup-failed merge-open merge-view-fails merge-view-lowercase"
NW4="$(wc -w <<<"$WORLDS4")"
for w in $WORLDS4; do
  mkdir -p "$P4/$w"
  : > "$P4/$w/merge.out"
  case "$w" in
    merge-ok|merge-exit0-open) printf '0' > "$P4/$w/merge.rc" ;;
    *)        printf '1' > "$P4/$w/merge.rc"; printf 'failed to run git: fatal: main is already checked out\n' > "$P4/$w/merge.err" ;;
  esac
  case "$w" in
    merge-ok|merge-cleanup-failed) printf 'MERGED\n' > "$P4/$w/view.out"; printf '0' > "$P4/$w/view.rc" ;;
    merge-exit0-open)     printf 'OPEN\n'   > "$P4/$w/view.out"; printf '0' > "$P4/$w/view.rc" ;;
    merge-open)           printf 'OPEN\n'   > "$P4/$w/view.out"; printf '0' > "$P4/$w/view.rc" ;;
    merge-view-lowercase) printf 'merged\n' > "$P4/$w/view.out"; printf '0' > "$P4/$w/view.rc" ;;
    merge-view-fails)     : > "$P4/$w/view.out"; printf '1' > "$P4/$w/view.rc"
                          printf 'GraphQL: Could not resolve to a PullRequest with the number of 42. (repository.pullRequest)\n' > "$P4/$w/view.err" ;;
  esac
done

run_merge() { # <block-file> <world> -> token
  local b="$1" w="$2" d out line mg nl cl rc
  d="$P4/run-$(basename "$b" .sh)-$w"
  cp -R "$P4/$w" "$d" && write_gh_stub "$d" || { echo "FIXTURE ERROR: could not copy world $w" >&2; exit 2; }
  mkdir "$d/cwd"
  out="$( cd "$d/cwd" && PATH="$d:$PATH" "$BASH" "$b" 2>&1 )"; rc=$?
  [ "$rc" = 0 ] || rc=nz
  printf '%s\n' "$out" > "$d.out"
  line="$(grep -m1 '^MERGE: ' <<<"$out")"
  case "$line" in
    "MERGE: merged") mg=merged ;;
    "MERGE: merged — gh's local cleanup failed; 7a-post lands explicitly") mg=merged-cleanup ;;
    "MERGE: HARD_BLOCK failed — "*) mg="HB[$(tr ' ' '-' <<<"${line#MERGE: HARD_BLOCK failed — }")]" ;;
    "") mg=NONE ;;
    *)  mg="OTHER[$(tr ' ' '-' <<<"$line")]" ;;
  esac
  nl="$(grep -c '^MERGE: ' <<<"$out")" || nl=0
  [ "$nl" -gt 1 ] && mg="$mg+L$nl"
  if [ ! -e "$d/calls.log" ]; then cl="-"
  elif grep -q '^refused' "$d/calls.log"; then cl="R$(grep -c . "$d/calls.log")"
  else cl="$(sed -n 's/^accepted merge$/m/p; s/^accepted view$/v/p' "$d/calls.log" | tr -d '\n')"; fi
  printf '%s/%s/%s' "$mg" "$cl" "$rc"
}
battery4() {
  local f="$1" tag="$2" worlds="${3:-$WORLDS4}" b t="" w
  b="$P4/$tag.sh"
  extract_merge "$f" | sed -e 's@<pr-number>@42@g' > "$b"
  bash -n "$b" 2>/dev/null || { printf 'PARSE-ERROR'; return; }
  for w in $WORLDS4; do
    case " $worlds " in *" $w "*) ;; *) continue ;; esac
    t="$t $w:$(run_merge "$b" "$w")"
  done
  printf '%s' "${t# }"
}

EXPECTED4="merge-ok:merged/mv/0 merge-exit0-open:HB[OPEN]/mv/nz merge-cleanup-failed:merged-cleanup/mv/0 merge-open:HB[OPEN]/mv/nz merge-view-fails:HB[state-unreadable]/mv/nz merge-view-lowercase:HB[merged]/mv/nz"
GOT4="$(battery4 "$RETRO" ship)"
if [ "$GOT4" = "$EXPECTED4" ]; then
  ok "part 4, ${NW4} worlds: a merge that exits 0 is merged without asking for the state; a merge that exits 1 is merged only when gh pr view prints exactly MERGED, and an OPEN, an unreadable and a lower-case state are each a HARD_BLOCK naming what was read"
else
  bad "part 4 battery: expected [$EXPECTED4], got [$GOT4]"
fi
cp "$RETRO" "$P4/control.md"
if cmp -s "$RETRO" "$P4/control.md" && [ "$(extract_merge "$P4/control.md")" = "$MBLOCK" ] && [ "$GOT4" = "$EXPECTED4" ]; then
  ok "part 4 CONTROL: an unmutated copy reproduces all ${NW4} worlds"
else
  echo "FIXTURE ERROR: the part 4 control does not reproduce the battery — expected [$EXPECTED4], got [$GOT4]." >&2
  exit 2
fi

# --- merge-exit-only: the pre-fix decision, a non-zero merge exit is a HARD_BLOCK whatever the
# PR's state. The state is still read, so only the world where it says MERGED after exit 1 moves.
cat > "$SEDS/merge-exit-only" <<'SED'
/^elif \[ "\$PR_STATE" = MERGED \]; then$/c\
elif false; then
SED
mutate_p 4 merge-exit-only 'elif [ "$PR_STATE" = MERGED ]; then' "@$SEDS/merge-exit-only" \
  "merge-ok:merged/mv/0 merge-exit0-open:HB[OPEN]/mv/nz merge-cleanup-failed:HB[MERGED]/mv/nz merge-open:HB[OPEN]/mv/nz merge-view-fails:HB[state-unreadable]/mv/nz merge-view-lowercase:HB[merged]/mv/nz" \
  "deciding on gh pr merge's exit alone STOPs a retro whose PR GitHub already merged"

# --- merge-exit-trusted: a zero merge exit is trusted without the state; a PR a merge queue left
# OPEN is reported merged.
cat > "$SEDS/merge-exit-trusted" <<'SED'
/^if \[ "\$PR_STATE" = MERGED \] && \[ "\$MERGE_RC" = 0 \]; then$/c\
if [ "$MERGE_RC" = 0 ]; then
SED
mutate_p 4 merge-exit-trusted 'if [ "$PR_STATE" = MERGED ] && [ "$MERGE_RC" = 0 ]; then' "@$SEDS/merge-exit-trusted" \
  "merge-ok:merged/mv/0 merge-exit0-open:merged/mv/0 merge-cleanup-failed:merged-cleanup/mv/0 merge-open:HB[OPEN]/mv/nz merge-view-fails:HB[state-unreadable]/mv/nz merge-view-lowercase:HB[merged]/mv/nz" \
  "trusting gh pr merge's exit 0 reports a PR still OPEN behind a merge queue as merged"

# --- merge-accept-any-state: any non-empty state counts as merged after the exact-MERGED arm. OPEN
# decides; the lower-case and the exit-0-open worlds die with it (each is a non-empty state).
cat > "$SEDS/merge-accept-any-state" <<'SED'
/^elif \[ "\$PR_STATE" = MERGED \]; then$/c\
elif [ -n "$PR_STATE" ]; then
SED
mutate_p 4 merge-accept-any-state 'elif [ "$PR_STATE" = MERGED ]; then' "@$SEDS/merge-accept-any-state" \
  "merge-ok:merged/mv/0 merge-exit0-open:merged-cleanup/mv/0 merge-cleanup-failed:merged-cleanup/mv/0 merge-open:merged-cleanup/mv/0 merge-view-fails:HB[state-unreadable]/mv/nz merge-view-lowercase:merged-cleanup/mv/0" \
  "accepting any readable state reports a PR that is still OPEN as merged and proceeds to rotate"

# --- merge-case-fold: the state compared case-insensitively. Only the lower-case world moves.
cat > "$SEDS/merge-case-fold" <<'SED'
/^elif \[ "\$PR_STATE" = MERGED \]; then$/c\
elif [ "$(printf '%s' "$PR_STATE" | tr a-z A-Z)" = MERGED ]; then
SED
mutate_p 4 merge-case-fold 'elif [ "$PR_STATE" = MERGED ]; then' "@$SEDS/merge-case-fold" \
  "merge-ok:merged/mv/0 merge-exit0-open:HB[OPEN]/mv/nz merge-cleanup-failed:merged-cleanup/mv/0 merge-open:HB[OPEN]/mv/nz merge-view-fails:HB[state-unreadable]/mv/nz merge-view-lowercase:merged-cleanup/mv/0" \
  "a case-folded comparison accepts a state that is not exactly MERGED"

# --- merge-no-false: the HARD_BLOCK branch no longer ends non-zero (only the `  false` after the
# MERGE line goes; the LAND block's own `  false` is untouched).
cat > "$SEDS/merge-no-false" <<'SED'
/echo "MERGE: HARD_BLOCK failed — \${PR_STATE:-state unreadable}"/{
n
/^  false$/d
}
SED
mutate_p 4 merge-no-false 'echo "MERGE: HARD_BLOCK failed — ${PR_STATE:-state unreadable}"' "@$SEDS/merge-no-false" \
  "merge-ok:merged/mv/0 merge-exit0-open:HB[OPEN]/mv/0 merge-cleanup-failed:merged-cleanup/mv/0 merge-open:HB[OPEN]/mv/0 merge-view-fails:HB[state-unreadable]/mv/0 merge-view-lowercase:HB[merged]/mv/0" \
  "without the trailing false a MERGE HARD_BLOCK exits 0, so a refused merge is a successful tool result"
fi

# ============================================================================
# ARM pending-gate: PENDING NEVER HIDES A BROKEN SUBJECT. Three seeds keep each subject's anchor and
# break its block: the Step 1 fallback with its guard body deleted (the `PR_SRC=""; GH_WHY=""` line
# kept), the LAND block reduced to the bare chain under its kept comment (land-pre-fix's copy), and
# the 7a block reduced to a bare `gh pr merge` under its kept comment. Each must be classified
# PRESENT by the same subject_state the gate uses, and each must move its deciding world: RED.
# It needs all three subjects present to seed from, so before they arrive it is PENDING with them.
# ============================================================================
if [ "$ST_FB" = present ] && [ "$ST_LAND" = present ] && [ "$ST_MERGE" = present ]; then
  cat > "$SEDS/seed-fallback" <<'SED'
/^  if \[ -z "\$PR_HEAD" \] && \[ -n "\$FORK" \]; then$/,/^  fi$/d
SED
  cat > "$SEDS/seed-merge" <<'SED'
/^PR_STATE="\$(gh pr view <pr-number> --json state --jq \.state)" || PR_STATE=""$/,/^fi$/d
SED
  _sf="$P2/seed-fallback.md"; _sl="$P3/m-land-pre-fix.md"; _sm="$P4/seed-merge.md"
  sed -f "$SEDS/seed-fallback" "$RETRO" > "$_sf"; sed -f "$SEDS/seed-merge" "$RETRO" > "$_sm"
  _sfn="$(grep -cF 'if [ -z "$PR_HEAD" ] && [ -n "$FORK" ]; then' "$RETRO")" || _sfn=0
  _smn="$(grep -cF 'PR_STATE="$(gh pr view <pr-number> --json state --jq .state)" || PR_STATE=""' "$RETRO")" || _smn=0
  if [ "$_sfn" != 1 ] || [ "$_smn" != 1 ] || cmp -s "$RETRO" "$_sf" || cmp -s "$RETRO" "$_sm" || [ ! -f "$_sl" ] || cmp -s "$RETRO" "$_sl"; then
    echo "FIXTURE ERROR: a pending-gate seed did not apply (fallback anchor ${_sfn}, merge anchor ${_smn}, or a seed equals the subject)." >&2
    exit 2
  fi
  _pg="$(subject_state fallback "$_sf")/$(subject_state land "$_sl")/$(subject_state merge "$_sm")"
  _pgf="$(battery2 "$_sf" seed-fb repointed)"
  _pgl="$(battery3 "$_sl" seed-land land-wt)"
  _pgm="$(battery4 "$_sm" seed-merge merge-cleanup-failed)"
  if [ "$_pg" = present/present/present ] \
     && [ "$_pgf" != "$(pick "$EXPECTED2" "$WORLDS2" repointed)" ] \
     && [ "$_pgl" != "$(pick "$EXPECTED3" "$WORLDS3" land-wt)" ] \
     && [ "$_pgm" != "$(pick "$EXPECTED4" "$WORLDS4" merge-cleanup-failed)" ]; then
    ok "pending-gate: an anchor kept over a broken block is PRESENT, never PENDING, and RED — the gutted fallback reads [$_pgf], the bare LAND chain [$_pgl], the bare merge [$_pgm]"
  else
    bad "pending-gate: classified [$_pg] (want present/present/present); seeds read [$_pgf] [$_pgl] [$_pgm], and a seed equal to its expected token was not caught"
  fi
else
  pending "pending-gate" "at least one of the gh fallback, the LAND block and the MERGE block" \
    "the arm proving a kept anchor over a broken block is RED (it seeds from all three) is not asserted" 1
fi

# ============================================================================
# BL-990's RECEIPT, invoked here so it is never an orphan (BL-915's E1). It builds its own three
# worlds from the resolved retro.md (passed, so a consumer layout is the one measured): the
# re-pointed carry derived from gh, the LAND refusal with main held by a linked worktree, and the
# 7a merge whose gh exit is 1 while the PR state is MERGED. BL-990 closes with this subject, so
# the arm requires exit 0 and all three CELL lines PASS; exit 9 is a refusal to build its worlds:
# FIXTURE BROKEN.
# ============================================================================
RCPT990="$DIR/receipt-bl990.sh"
[ -f "$RCPT990" ] || { echo "FIXTURE ERROR: missing $RCPT990" >&2; exit 2; }
# The receipt itself stays strict (exit 1 on a pre-fix retro.md). Its INVOCATION here is gated on
# the same subject_state: with the fallback or the LAND block absent it is PENDING, not run.
if [ "$ST_FB" = absent ] || [ "$ST_LAND" = absent ] || [ "$ST_MERGE" = absent ]; then
  pending "BL-990 receipt" "the gh fallback, the LAND block or the MERGE block it measures" "receipt-bl990.sh is not run" 1
else
bash "$DIR/receipt-bl990.sh" "$RETRO" > "$WORK/r990.out" 2>"$WORK/r990.err"; r990_rc=$?
r990_pass="$(grep -cE '^CELL (carry|land|merge) PASS ' "$WORK/r990.out")" || r990_pass=0
if [ "$r990_rc" = 9 ]; then
  bad "FIXTURE BROKEN: receipt-bl990.sh refused to build its worlds: $(head -1 "$WORK/r990.err")"
elif [ "$r990_rc" = 0 ] && [ "$r990_pass" = 3 ]; then
  ok "BL-990 receipt: exit 0, all three cells PASS: $(grep '^CELL ' "$WORK/r990.out" | cut -d' ' -f2-3 | tr '\n' ' ')"
else
  bad "BL-990 receipt: exit $r990_rc with $r990_pass of 3 CELL PASS lines: $(cat "$WORK/r990.out" "$WORK/r990.err" | head -c 600 | tr '\n' ' ')"
fi
fi

# ============================================================================
# BL-997's RECEIPT. Both landing blocks refuse before the checkout when a file sits on disk at a
# path the trunk would write, so an operator's IGNORED file at a path origin/main force-adds keeps
# its bytes. It builds its own five worlds from the resolved retro.md: the ignored e.log, é.log and
# sub/x.log at Step 1 and at the LAND block, each with a clean twin, and an untracked, non-ignored
# control. Its subject is the on-disk check: ABSENT when retro.md carries no `ON-DISK ` token, and
# then PENDING (RED in the distribution), like every subject above.
# ============================================================================
RCPT997="$DIR/receipt-bl997.sh"
[ -f "$RCPT997" ] || { echo "FIXTURE ERROR: missing $RCPT997" >&2; exit 2; }
_hold="$(grep -c 'ON-DISK ' "$RETRO")" || _hold=0
if [ "$_hold" -eq 0 ] || [ "$ST_CARRY" = absent ] || [ "$ST_LAND" = absent ]; then
  pending "BL-997 receipt" "the on-disk check before Step 1's and the LAND block's checkout" "receipt-bl997.sh is not run" 1
else
bash "$RCPT997" "$RETRO" > "$WORK/r997.out" 2>"$WORK/r997.err"; r997_rc=$?
r997_pass="$(grep -cE '^CELL (step1-ignored|step1-clean|land-ignored|land-clean|land-untracked) PASS ' "$WORK/r997.out")" || r997_pass=0
if [ "$r997_rc" = 9 ]; then
  bad "FIXTURE BROKEN: receipt-bl997.sh refused to build its worlds: $(head -1 "$WORK/r997.err")"
elif [ "$r997_rc" = 0 ] && [ "$r997_pass" = 5 ]; then
  ok "BL-997 receipt: exit 0, all five cells PASS: $(grep '^CELL ' "$WORK/r997.out" | cut -d' ' -f2-3 | tr '\n' ' ')"
else
  bad "BL-997 receipt: exit $r997_rc with $r997_pass of 5 CELL PASS lines: $(cat "$WORK/r997.out" "$WORK/r997.err" | head -c 600 | tr '\n' ' ')"
fi
fi


# A plain (per-push) run must drive no matrix-only cell; a --matrix run must drive them.
if [ "$MATRIX" = 0 ]; then
  if [ "$MCELLS" -eq 0 ]; then ok "a plain run drove no matrix-only cell: every mutant ran its deciding arm and one twin"; else bad "a plain run drove $MCELLS matrix-only cell(s)"; fi
else
  if [ "$MCELLS" -gt 0 ]; then ok "the matrix run drove its matrix-only cells ($MCELLS)"; else bad "the matrix run drove no matrix-only cell"; fi
fi

echo
# Liveness: a harness that silently stopped running assertions reads exactly like a clean pass.
# A PENDING skip is counted, so asserted + skipped must still be the full count.
# A distribution-layout absence is one FAILED assertion beside its skipped arms, so it is netted out.
if [ $((asserted + SKIPPED - PENDBAD)) -ne 51 ]; then
  echo "retro-branch-behind-main: FIXTURE ERROR — ran $asserted assertions ($PENDBAD of them distribution-absence failures) and skipped $SKIPPED as PENDING, expected 51 in all" >&2
  exit 2
fi
if [ "$fails" -eq 0 ]; then
  if [ "$PENDN" -gt 0 ]; then
    echo "retro-branch-behind-main: PASS ($asserted assertions; $PENDN PENDING row(s) skipping $SKIPPED — their subjects have not arrived in this retro.md)"
  else
    echo "retro-branch-behind-main: PASS ($asserted assertions)"
  fi
  exit 0
fi
echo "retro-branch-behind-main: FAIL ($fails of $asserted assertion(s))" >&2
exit 1
