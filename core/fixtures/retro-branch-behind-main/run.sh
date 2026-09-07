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
artifacts() { # artifacts <world> — the untracked retro evidence checks 2, 4 and 5 read.
  printf '## Gate Log: Sprint 900\n\n| Gate | Result | Notes |\n|------|--------|-------|\n| Deploy Status Report | PASS | USER-CONFIRMED visual verification captured |\n' \
    > "$1/_bmad-output/implementation-artifacts/gate-log.md"
  printf -- '- sprint: 899\n  sha: %s\n- sprint: 900\n  sha: <PENDING-S900-RETRO>\n' "$PRIOR_SHA" \
    > "$1/_bmad-output/audit-anchors.md"
  printf '# Validation Cycle Log\n\n- sprint 900: three cycles\n' \
    > "$1/_bmad-output/validation-cycle-log.md"
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

D_SUMMARY="Sprint 900: $((7 - 1)) of 7 checks verified; 1 SKIPPED (check 7)."

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
      "Sprint 900: all 7 checks passed") sm=all7 ;;
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
   && grep -qF 'the verified floor here is 6, not 7' <<<"$OUT"; then
  ok "an unmeasurable checkout gets PASS WITH SKIPS naming check 7 and a floor of 6 — an unmeasurable branch is not certified fresh"
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
  "with the block gone every world reports rc 0 and no CHECK 7 line at all, the defect world included, and the skip world claims all 7 checks passed"

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

echo
# Liveness: a harness that silently stopped running assertions reads exactly like a clean pass.
if [ "$asserted" -ne 11 ]; then
  echo "retro-branch-behind-main: FIXTURE ERROR — ran $asserted assertions, expected 11" >&2
  exit 2
fi
if [ "$fails" -eq 0 ]; then
  echo "retro-branch-behind-main: PASS ($asserted assertions)"
  exit 0
fi
echo "retro-branch-behind-main: FAIL ($fails of $asserted assertion(s))" >&2
exit 1
