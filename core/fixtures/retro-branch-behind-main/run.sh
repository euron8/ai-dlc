#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
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
set -uo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

# ROOT BY WALKING UP FOR THE SUBJECT, never by counting `..` hops, and BOTH LAYOUTS NAMED
# (I33/I33c). Upstream this fixture sits at core/fixtures/<name>/ with the toolchain at
# core/scripts/ and the schemas at core/schemas/; a consumer has tests/fixtures/<name>/,
# scripts/ai-dlc/ and .claude/schemas/ — install.sh splits what shares a parent here, so no
# single relative shape reaches both. `VERSION` is deliberately NOT the marker: install.sh
# stamps a consumer with `.claude/.ai-dlc-version` and ships no `VERSION` file, so keying on it
# would make this shipping fixture exit 2 on every consumer it reaches.
ROOT=""; TOOLS=""; SCHEMAS=""
_d="$DIR"
while : ; do
  _p="$(cd "$_d/.." 2>/dev/null && pwd)" || break
  [ -n "$_p" ] && [ "$_p" != "$_d" ] || break
  _d="$_p"
  if   [ -f "$_d/core/scripts/validate-mandatory-rules.sh" ]; then
    ROOT="$_d"; TOOLS="$_d/core/scripts"; SCHEMAS="$_d/core/schemas"; break
  elif [ -f "$_d/scripts/ai-dlc/validate-mandatory-rules.sh" ]; then
    ROOT="$_d"; TOOLS="$_d/scripts/ai-dlc"; SCHEMAS="$_d/.claude/schemas"; break
  fi
  [ "$_d" = "/" ] && break
done
if [ -z "$ROOT" ]; then
  echo "FIXTURE ERROR: validate-mandatory-rules.sh not found in either layout above $DIR" >&2
  exit 2
fi
# retro.md Step 1 is the second subject (Part 2 below). Same two layouts, same root.
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
  printf '#!/bin/sh\nexit 0\n' > "$1/validate-cycle-commits.sh"
  printf '#!/bin/sh\nexit 0\n' > "$1/validate-retro-evidence.sh"
  printf '#!/bin/sh\nexit 0\n' > "$1/validate-retro-prereq.sh"
  chmod +x "$1"/*.sh
}

D_SUMMARY="Sprint 900: $((8 - 1)) of 8 checks verified; 1 SKIPPED (check 7)."

# battery <toolchain-dir> -> eight space-separated tokens, one per world.
#
# TOKEN: <verdict>/<behind-count>/<refresh>/<remedy>/<summary-class>/<rc>
#   verdict  PASS | FAIL | SKIP | NONE (no CHECK 7 line at all) | OTHER[<line>]
#   refresh  R refreshed | N NOT refreshed (fetch failed) | X no remote named origin | ? neither
#   remedy   m if the run printed `git merge origin/main` anywhere, else -
#   summary  all7 | skip7 (the check-7 skip sentence) | nosumm | other[<sentence>]
# Every field is a fact the check emits, so a subject printing nothing scores NONE/-/-/-/…
# and fails every arm rather than passing any.
battery() {
  local D="$1" out rc t=""
  run()  { out="$( cd "$1" && bash "$D/validate-mandatory-rules.sh" 900 2>&1 )"; rc=$?; }
  c7()   { awk '/^  CHECK 7: /{ sub(/^[ ]+/,""); print; exit }' <<<"$out"; }
  summ() { awk '/checks (passed|verified)/{ sub(/^[ ]+/,""); print; exit }' <<<"$out"; }
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

  # A — trunk-cut retro branch, no remote: Check 7 passes without touching the network.
  run "$WA"; t="a:$(tok)"
  # B — THE DEFECT: cut from the ref the squash stranded.
  run "$WB"; t="$t b:$(tok)"
  # C — THE REMEDY the failure message names, applied. It must clear the check.
  run "$WC"; t="$t c:$(tok)"
  # D — no origin/main ref: SKIP loudly, exit 0, COUNTED as check 7 in the summary.
  run "$WD"; t="$t d:$(tok)"
  # E — ahead by two, behind by none. The predicate is behind-count, not divergence.
  run "$WE"; t="$t e:$(tok)"
  # F — local `main` ahead of origin/main, branch cut from origin/main. Still fresh.
  run "$WF"; t="$t f:$(tok)"
  # G — THE STALE CLONE. The pre-state is asserted in the same breath as the run: without a
  #     stale ref going in, this arm is arm B with a remote and proves nothing about the fetch.
  reset_g
  if [ "$(git -C "$WG" rev-list --count HEAD..origin/main)" != "0" ]; then
    t="$t g:PRESTATE-NOT-STALE"
  else
    run "$WG"; t="$t g:$(tok)"
  fi
  # H — the same clone, origin URL pointed nowhere: the fetch fails and the check still decides.
  run "$WH"; t="$t h:$(tok)"

  printf '%s' "$t"
}

EXPECTED="a:PASS/-/X/-/all7/0 b:FAIL/${BEHIND}/X/m/nosumm/1 c:PASS/-/X/-/all7/0 d:SKIP/-/X/-/skip7/0 e:PASS/-/X/-/all7/0 f:PASS/-/X/-/all7/0 g:FAIL/${BEHIND}/R/m/nosumm/1 h:PASS/-/N/-/all7/0"

# --- 1. the shipping validator answers every arm ------------------------------
toolchain "$WORK/bin" "$VMR"
GOT="$(battery "$WORK/bin")"
if [ "$GOT" = "$EXPECTED" ]; then
  ok "all eight arms: a trunk-cut branch PASSes, the feature-cut branch FAILs naming ${BEHIND} commit(s) behind and the remedy, the remedy CLEARS it, a missing origin/main SKIPs and is counted as check 7, neither being ahead of origin/main nor trailing a local main that ran on moves the verdict, a clone whose stale ref hides the defect is REFRESHED and then fails at ${BEHIND}, and a clone that cannot reach its remote still decides and says the ref may be stale"
else
  bad "battery: expected [$EXPECTED], got [$GOT]"
fi

# --- 2. the failure message is actionable, not just non-zero ------------------
# retro.md reads this validator's OUTPUT as well as its exit code. A FAIL that does not name the
# count and the command is a stop with no next step.
OUT="$( cd "$WB" && bash "$WORK/bin/validate-mandatory-rules.sh" 900 2>&1 )"; RC=$?
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
OUT="$( cd "$WD" && bash "$WORK/bin/validate-mandatory-rules.sh" 900 2>&1 )"; RC=$?
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
OUT_A="$( cd "$WA" && bash "$WORK/bin/validate-mandatory-rules.sh" 900 2>&1 )"
reset_g
OUT_G="$( cd "$WG" && bash "$WORK/bin/validate-mandatory-rules.sh" 900 2>&1 )"
OUT_H="$( cd "$WH" && bash "$WORK/bin/validate-mandatory-rules.sh" 900 2>&1 )"
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
CTL="$(battery "$WORK/mut-control")"
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
  local D="$WORK/mut-$tag" M="$WORK/staged-$tag.sh" got n
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
  toolchain "$D" "$M"
  got="$(battery "$D")"
  if [ "$got" = "$want" ]; then
    ok "MUTANT $tag: $claim"
  elif [ "$got" = "$EXPECTED" ]; then
    bad "MUTANT $tag SURVIVED: $claim — every arm unchanged, so nothing here can catch it"
  else
    bad "MUTANT $tag ($claim): expected battery [$want], got [$got]"
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
  '/^echo "\[Check 7\] Retro branch not behind origin\/main\.\.\."$/,/^  esac$/{ /^  esac$/{N;d;}; d; }' \
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
# TOKEN: <carry>/<behind>/<landed>/<evidence>/<picking>/<branch>
#   carry     n<k> carried k | none-tip | none-empty | HB-unresolved | HB-underivable |
#             HB-conflict | NONE (no CARRY: line) | OTHER[<line>]
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
BLOCK="$(extract_block "$RETRO")"
case "$BLOCK" in
  *'<sprint-branch>'*'<N>'*) : ;;
  *)
    echo "  FAIL  retro.md Step 1 carries no carry block naming <sprint-branch> and <N> — the post-squash sprint commits are never carried (an absent block is a finding, not a pass)" >&2
    echo "retro-branch-behind-main: FAIL (part 2 subject absent)" >&2
    exit 1 ;;
esac

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
}
WORLDS2="carry empty synced conflict underivable direct unresolved"
for w in $WORLDS2; do build "$w"; done

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

# run_block <block-file> <world> -> token
run_block() {
  local b="$1" w="$2" d out line cr n ld ev pk br
  d="$P2/run-$(basename "$b" .sh)-$w"
  cp -R "$P2/$w/clone" "$d" || { echo "FIXTURE ERROR: could not copy world $w" >&2; exit 2; }
  out="$( cd "$d" && bash "$b" 2>&1 )"
  line="$(grep -m1 '^CARRY: ' <<<"$out")"
  case "$line" in
    "CARRY: none — the sprint tip is already on origin/main") cr=none-tip ;;
    "CARRY: none — no sprint commit follows PR head "*)      cr=none-empty ;;
    "CARRY: HARD_BLOCK unresolved"*)   cr=HB-unresolved ;;
    "CARRY: HARD_BLOCK underivable"*)  cr=HB-underivable ;;
    "CARRY: HARD_BLOCK conflict"*)     cr=HB-conflict ;;
    "CARRY: "[0-9]*" commit(s) past PR head "*) cr="n$(sed -n 's/^CARRY: \([0-9][0-9]*\) .*/\1/p' <<<"$line")" ;;
    "") cr=NONE ;;
    *)  cr="OTHER[$line]" ;;
  esac
  n="$(git -C "$d" rev-list --count HEAD..origin/main 2>/dev/null)" || n="?"
  if git -C "$d" merge-base --is-ancestor "$(cat "$P2/$w.landed")" HEAD 2>/dev/null; then ld=y; else ld=n; fi
  ev=0
  grep -q 'REVISION 3' <<<"$(git -C "$d" show "HEAD:$GL" 2>/dev/null)" && ev=$((ev+1))
  grep -q 'DV-1' <<<"$(git -C "$d" show "HEAD:$ESC" 2>/dev/null)" && ev=$((ev+1))
  if [ -e "$d/.git/CHERRY_PICK_HEAD" ]; then pk=y; else pk=n; fi
  if [ "$(git -C "$d" symbolic-ref -q --short HEAD)" = ai-dlc/retro/sprint-900 ]; then br=y; else br=n; fi
  printf '%s/%s/%s/%s/%s/%s' "$cr" "$n" "$ld" "$ev" "$pk" "$br"
}
# battery2 <retro.md copy> <tag> -> seven tokens
battery2() {
  local f="$1" tag="$2" b t="" w
  b="$P2/$tag.sh"
  extract_block "$f" | sed -e "s@<sprint-branch>@$SB@g" -e 's@<N>@900@g' > "$b"
  bash -n "$b" 2>/dev/null || { printf 'PARSE-ERROR'; return; }
  for w in $WORLDS2; do t="$t $w:$(run_block "$b" "$w")"; done
  printf '%s' "${t# }"
}

EXPECTED2="carry:n2/0/y/2/n/y empty:none-empty/0/y/0/n/y synced:n2/0/y/2/n/y conflict:HB-conflict/0/y/0/n/y underivable:HB-underivable/0/y/0/n/y direct:none-tip/0/y/0/n/y unresolved:HB-unresolved/0/y/0/n/y"

GOT2="$(battery2 "$RETRO" ship)"
if [ "$GOT2" = "$EXPECTED2" ]; then
  ok "part 2, seven worlds: the retro branch is trunk-cut and 0 behind in every world, carries both post-squash commits (also when the sprint branch merged the trunk after the squash), reports an empty carry as none without error, and stops on a conflict, an underivable PR head and a missing sprint branch with a named HARD_BLOCK and no pick left in progress"
else
  bad "part 2 battery: expected [$EXPECTED2], got [$GOT2]"
fi

cp "$RETRO" "$P2/control.md"
CTL2="$(battery2 "$P2/control.md" control)"
if [ "$CTL2" = "$EXPECTED2" ]; then
  ok "part 2 CONTROL: an unmutated copy reproduces all seven worlds, so a mutant's token below is the mutation"
else
  echo "FIXTURE ERROR: the part 2 control does not reproduce the battery — expected [$EXPECTED2], got [$CTL2]." >&2
  exit 2
fi

# mutate2 <tag> <anchor occurring once in retro.md> <sed-program> <expected> <claim>
mutate2() {
  local tag="$1" anchor="$2" prog="$3" want="$4" claim="$5" m="$P2/m-$1.md" n got
  n="$(grep -cF -- "$anchor" "$RETRO")" || n=0
  if [ "$n" -ne 1 ]; then
    echo "FIXTURE ERROR: part 2 mutant '$tag' anchors on a line occurring ${n} time(s), not once." >&2
    exit 2
  fi
  sed "$prog" "$RETRO" > "$m" || { bad "MUTANT $tag: DID NOT APPLY"; return; }
  if cmp -s "$RETRO" "$m"; then
    echo "FIXTURE ERROR: part 2 mutant '$tag' matched nothing." >&2
    exit 2
  fi
  got="$(battery2 "$m" "m-$tag")"
  if [ "$got" = "$want" ]; then
    ok "MUTANT $tag: $claim"
  elif [ "$got" = "$EXPECTED2" ]; then
    bad "MUTANT $tag SURVIVED: $claim — every world unchanged"
  else
    bad "MUTANT $tag ($claim): expected [$want], got [$got]"
  fi
}

# --- carry-deleted: Step 1 as it stood before the carry. Every world reports no CARRY line, and
# the two worlds with post-squash evidence lose it — the filing's 0-and-0 greps.
mutate2 carry-deleted \
  'if [ -z "$SPRINT_TIP" ]; then' \
  '/^if \[ -z "\$SPRINT_TIP" \]; then$/,/^fi$/d' \
  "carry:NONE/0/y/0/n/y empty:NONE/0/y/0/n/y synced:NONE/0/y/0/n/y conflict:NONE/0/y/0/n/y underivable:NONE/0/y/0/n/y direct:NONE/0/y/0/n/y unresolved:NONE/0/y/0/n/y" \
  "without the carry the trunk-cut retro branch holds neither post-squash marker and nothing says so"

# --- WRONG FIX 1: cut the retro branch from the sprint tip. The markers arrive, and the branch
# no longer has the squash as an ancestor — the defect part 1 exists for.
mutate2 cut-from-tip \
  'git checkout -b ai-dlc/retro/sprint-<N> origin/main' \
  's@^git checkout -b ai-dlc/retro/sprint-<N> origin/main$@git checkout -b ai-dlc/retro/sprint-<N> "$SPRINT_TIP"@' \
  "carry:HB-conflict/2/n/2/n/y empty:none-empty/2/n/0/n/y synced:HB-conflict/0/y/2/n/y conflict:HB-conflict/2/n/1/n/y underivable:HB-underivable/3/n/2/n/y direct:none-tip/1/y/0/n/y unresolved:HB-unresolved/0/y/0/n/n" \
  "WRONG FIX — a tip-cut retro branch trails origin/main and lacks the squash as an ancestor in every world the sprint did not already merge the trunk into"

# --- skip-guard removed: an empty carry list reaches cherry-pick, which refuses it.
mutate2 no-skip-guard \
  'if [ "$CARRY_N" = 0 ]; then' \
  's@^    if \[ "\$CARRY_N" = 0 \]; then$@    if false; then@' \
  "carry:n2/0/y/2/n/y empty:HB-conflict/0/y/0/n/y synced:n2/0/y/2/n/y conflict:HB-conflict/0/y/0/n/y underivable:HB-underivable/0/y/0/n/y direct:none-tip/0/y/0/n/y unresolved:HB-unresolved/0/y/0/n/y" \
  "without the count guard a sprint with nothing to carry is reported as a conflict HARD_BLOCK"

# --- abort removed: the conflict world is left mid-pick.
mutate2 no-abort \
  'git cherry-pick --abort' \
  '/^      git cherry-pick --abort$/d' \
  "carry:n2/0/y/2/n/y empty:none-empty/0/y/0/n/y synced:n2/0/y/2/n/y conflict:HB-conflict/0/y/0/y/y underivable:HB-underivable/0/y/0/n/y direct:none-tip/0/y/0/n/y unresolved:HB-unresolved/0/y/0/n/y" \
  "without the abort a conflicting carry leaves a cherry-pick in progress on the retro branch"

# --- WRONG FIX 2: the `<pr-head>..<tip>` range. Correct until the sprint branch merged the
# trunk after the squash; then the range re-picks trunk commits, and the synced world is the
# only world that can say so.
mutate2 plain-range \
  'elif git cherry-pick --no-merges "$SPRINT_TIP" --not "$PR_HEAD" origin/main; then' \
  's@elif git cherry-pick --no-merges "\$SPRINT_TIP" --not "\$PR_HEAD" origin/main; then@elif git cherry-pick --no-merges "$PR_HEAD..$SPRINT_TIP"; then@' \
  "carry:n2/0/y/2/n/y empty:none-empty/0/y/0/n/y synced:HB-conflict/0/y/0/n/y conflict:HB-conflict/0/y/0/n/y underivable:HB-underivable/0/y/0/n/y direct:none-tip/0/y/0/n/y unresolved:HB-unresolved/0/y/0/n/y" \
  "WRONG FIX — a sprint branch that merged the trunk after the squash makes the plain range re-pick trunk commits and stop"

# --- WRONG FIX 3: the merge-base as the PR head. It is the fork point, so the carry re-picks
# the PR's own work, which the squash already landed, and stops on it.
mutate2 merge-base \
  '  if [ -z "$PR_HEAD" ]; then' \
  's@^  if \[ -z "\$PR_HEAD" \]; then$@  PR_HEAD="$(git merge-base "$SPRINT_TIP" origin/main)"; if [ -z "$PR_HEAD" ]; then@' \
  "carry:HB-conflict/0/y/0/n/y empty:HB-conflict/0/y/0/n/y synced:HB-conflict/0/y/0/n/y conflict:HB-conflict/0/y/0/n/y underivable:HB-conflict/0/y/0/n/y direct:none-tip/0/y/0/n/y unresolved:HB-unresolved/0/y/0/n/y" \
  "WRONG FIX — taking the merge-base as the PR head re-picks the squashed PR work, which is already on the trunk, and stops in every world that has a PR head"

# --- not first-parent: a full-history walk finds the post-squash trunk commit as the fork
# point on a synced branch, so no trunk tree is newer and the PR head reads underivable.
mutate2 all-parents \
  'FORK="$(git rev-list --first-parent "$SPRINT_TIP" \' \
  's@FORK="\$(git rev-list --first-parent "\$SPRINT_TIP" \\@FORK="$(git rev-list "$SPRINT_TIP" \\@' \
  "carry:n2/0/y/2/n/y empty:none-empty/0/y/0/n/y synced:HB-underivable/0/y/0/n/y conflict:HB-conflict/0/y/0/n/y underivable:HB-underivable/0/y/0/n/y direct:none-tip/0/y/0/n/y unresolved:HB-unresolved/0/y/0/n/y" \
  "a walk that follows every parent reads a synced sprint branch as underivable and carries nothing"

echo
# Liveness: a harness that silently stopped running assertions reads exactly like a clean pass.
if [ "$asserted" -ne 20 ]; then
  echo "retro-branch-behind-main: FIXTURE ERROR — ran $asserted assertions, expected 20" >&2
  exit 2
fi
if [ "$fails" -eq 0 ]; then
  echo "retro-branch-behind-main: PASS ($asserted assertions)"
  exit 0
fi
echo "retro-branch-behind-main: FAIL ($fails of $asserted assertion(s))" >&2
exit 1
