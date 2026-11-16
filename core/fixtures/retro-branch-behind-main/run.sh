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
# construction; silence cannot pass anywhere in this file. The ship battery
# asserts the eight baseline rows are THERE, not merely that nothing went wrong.
#
# WHY THE TOKEN PARSES RATHER THAN STRING-MATCHES. Pinning full prose in every arm makes a wording
# change read as many regressions. The token carries the six facts that ARE the check — verdict, behind
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
#
# WHY ARM F EXISTS BESIDE ARM E. Arm E is a retro branch AHEAD of origin/main and behind by
# none: it proves the predicate is behind-count and not divergence. Arm F is the only world
# where the LOCAL `main` ref and `origin/main` disagree, and it is the only arm that can tell
# Check 7 from a Check 7 that reads local `main`.
# Without F that substitution is invisible, because in every other world the two refs are equal.
#
# ARM G IS THE ONLY ARM WHOSE PRE-STATE IS A LIE, and it is reset before every battery. Its
# clone starts behind 0 against a stale ref and behind 3 against the real remote; a battery that
# inherited the previous battery's refreshed ref would score the refresh as exercised when it did not run,
# so the token refuses the arm outright if the pre-state is not stale when it runs.
#
# CHECKS 1, 2 AND 4 ARE DRIVEN THROUGH STUBBED SIBLINGS. This fixture's subject is Check 7, and
# the sibling contract those three checks publish is an exit code; stubbing them keeps the run's
# verdict a statement about branch freshness rather than about a delegated validator. The stubs
# are proven live by the ship battery, which reproduces all eight arms from its own toolchain dir.
set -uo pipefail

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
# carry worlds whose verdict it did not change keep asserting.
# ABSENT is keyed only on the subject's own markers counting 0 (see PENDING above part 2); a
# PRESENT subject that is broken is RED. The final line names the PENDING count.
# PENDING is a CONSUMER-layout verdict only: in the distribution an absent subject is RED.
RETRO=""
for _r in "$ROOT/core/skills/ai-dlc/steps/retro.md" "$ROOT/.claude/skills/ai-dlc/steps/retro.md"; do
  [ -f "$_r" ] && { RETRO="$_r"; break; }
done
if [ -z "$RETRO" ]; then
  echo "FIXTURE ERROR: steps/retro.md not found under $ROOT in either layout — an absent subject is not a passing one" >&2
  exit 2
fi
DVSTEP="$(dirname "$RETRO")/deploy-validate.md"
[ -f "$DVSTEP" ] || { echo "FIXTURE ERROR: steps/deploy-validate.md not found beside $RETRO" >&2; exit 2; }

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

# shellcheck source=/dev/null
. "$DIR/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }

echo "retro-branch-behind-main:"
echo "MODE: PUSH"

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

# battery <toolchain-dir> <tag> [worlds] -> space-separated tokens, one per world driven.
#
# TOKEN: <verdict>/<behind-count>/<refresh>/<remedy>/<summary-class>/<rc>
#   verdict  PASS | FAIL | SKIP | NONE (no CHECK 7 line at all) | OTHER[<line>]
#   refresh  R refreshed | N NOT refreshed (fetch failed) | X no remote named origin | ? neither
#   remedy   m if the run printed `git merge origin/main` anywhere, else -
#   summary  all7 | skip7 (the check-7 skip sentence) | nosumm | other[<sentence>]
# Every field is a fact the check emits, so a subject printing nothing scores NONE/-/-/-/…
# and fails every arm rather than passing any.
#
# Each run's output and rc are kept at $WORK/out-<tag>-<world>[.rc] so assertions 2-4 read the SAME runs
# as the battery.

A_ORDER="a b c d e f g h"
battery() {
  local D="$1" tag="$2" worlds="${3:-$A_ORDER}" out rc t="" cur="" w wp
  run()  { out="$( cd "$1" && bash "$D/validate-mandatory-rules.sh" 900 2>&1 )"; rc=$?
           printf '%s\n' "$out" > "$WORK/out-$tag-$cur"; printf '%s' "$rc" > "$WORK/out-$tag-$cur.rc"; }
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


EXPECTED="a:PASS/-/X/-/all7/0 b:FAIL/${BEHIND}/X/m/nosumm/1 c:PASS/-/X/-/all7/0 d:SKIP/-/X/-/skip7/0 e:PASS/-/X/-/all7/0 f:PASS/-/X/-/all7/0 g:FAIL/${BEHIND}/R/m/nosumm/1 h:PASS/-/N/-/all7/0"

# --- 1. the shipping validator answers every arm ------------------------------
toolchain "$WORK/bin" "$VMR"
GOT="$(battery "$WORK/bin" ship)"
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
#             printed), and a gh-sourced count then `=head` (its PR head sha is that PR's row in the
#             world's gh rows) or `!head`; an underivable line carries `@<reason>` from its `; gh fallback:` clause:
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
# over a gutted body, or one surviving fallback line, is RED. The skipped arms are counted, and the
# liveness check requires asserted + skipped == the full count, so a skip cannot hide a lost arm.
#
# PENDING IS A CONSUMER-LAYOUT VERDICT ONLY. In the DISTRIBUTION (the root walk matched
# core/scripts/) retro.md ships in the same tree as this fixture and is always the new one, so an
# absent subject there is a reverted or broken subject: gate_verdict answers RED, pending() counts a
# FAILURE naming the part, and the run exits 1.
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
            "the worlds underivable repointed repointed-nogh repointed-ghfail repointed-empty repointed-badrow wrong-pr reused-branch tree-mismatch head-absent head-fetched and the head-absent arm are not asserted" 1 ;;
  absent) W2ACT=""
          pending "part 2" "the Step 1 carry block (no '# retro Step 1:' comment and no CARRY: token)" \
            "part 2's battery, and its head-absent arm are not asserted" 2
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
  local b="$1" w="$2" d out line cr n ld ev pk br gs gh nl pth hs
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
    "CARRY: "[0-9]*" commit(s) past PR head "*) cr="n$(sed -n 's/^CARRY: \([0-9][0-9]*\) .*/\1/p' <<<"$line")${gs:+@gh#$gs}"
      # A gh-sourced carry names the PR head gh listed for that PR: =head when the line's sha is that
      # world's row for PR #<gs>, !head otherwise (the sha is part of the verdict, not only the PR number).
      if [ -n "$gs" ]; then
        hs="$(sed -n 's/^CARRY: [0-9][0-9]* commit(s) past PR head \([0-9a-f]\{40\}\) .*/\1/p' <<<"$line")"
        if [ -n "$hs" ] && [ "$hs" = "$(awk -v n="$gs" '$1 == n { print $2; exit }' "$P2/$w.rows")" ]; then cr="$cr=head"; else cr="$cr!head"; fi
      fi ;;
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

EXPECTED2="carry:n2/0/y/2/n/y/- empty:none-empty/0/y/0/n/y/- synced:n2/0/y/2/n/y/- conflict:HB-conflict/0/y/0/n/y/- underivable:HB-underivable@one/0/y/0/n/y/1 direct:none-tip/0/y/0/n/y/- unresolved:HB-unresolved/0/y/0/n/y/- repointed:n3@gh#7=head/0/y/2/n/y/1 repointed-nogh:HB-underivable@unavail/0/y/0/n/y/- repointed-ghfail:HB-underivable@rc/0/y/0/n/y/1 repointed-empty:HB-underivable@empty/0/y/0/n/y/1 repointed-badrow:HB-underivable@row/0/y/0/n/y/1 wrong-pr:HB-underivable@one/0/y/0/n/y/1 reused-branch:HB-underivable@newer/0/y/0/n/y/1 tree-mismatch:HB-underivable@tree/0/y/0/n/y/1 head-absent:HB-underivable@local/0/y/0/n/y/1 head-fetched:n3@gh#7=head/0/y/2/n/y/1"
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

fi

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
land_shape_ok() { # <retro.md>: exactly one comment-anchored LAND block printing both outcomes
  local n; n="$(grep -c '^# retro 7a-post step 1: land on the merged trunk$' "$1")" || n=0
  case "$n:$(extract_land "$1")" in 1:*'LAND: main at origin/main'*'LAND: HARD_BLOCK'*) return 0 ;; esac
  return 1
}
# An ABSENT LAND block (subject_state: no comment and no LAND: token) is PENDING. A PRESENT one that
# is not exactly one comment-anchored block printing both outcomes is BROKEN, and FAILs, exit 1.
LBLOCK="$(extract_land "$RETRO")"
if [ "$ST_LAND" = absent ]; then
  pending "part 3" "the 7a-post step 1 LAND block (no '# retro 7a-post step 1:' comment and no LAND: token)" \
    "the worlds land-ok land-wt land-diverged land-tag are not asserted" 1
else
_ln="$(grep -c '^# retro 7a-post step 1: land on the merged trunk$' "$RETRO")" || _ln=0
if ! land_shape_ok "$RETRO"; then
    echo "  FAIL  retro.md carries a LAND marker but ${_ln} '# retro 7a-post step 1: land on the merged trunk' block(s), not exactly one printing both LAND outcomes — a present subject that is broken is a finding, not PENDING" >&2
    echo "retro-branch-behind-main: FAIL (part 3 subject broken)" >&2
    exit 1
fi

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
merge_shape_ok() { # <retro.md>: exactly one comment-anchored 7a block naming <pr-number>, printing both outcomes
  local n; n="$(grep -c '^# retro 7a: merge the retro PR, then read its state from GitHub$' "$1")" || n=0
  case "$n:$(extract_merge "$1")" in 1:*'<pr-number>'*'MERGE: merged'*'MERGE: HARD_BLOCK'*) return 0 ;; esac
  return 1
}
# ABSENT (no comment and no MERGE: token) is PENDING; PRESENT but not exactly one comment-anchored
# block naming <pr-number> and printing both outcomes is BROKEN, and FAILs, exit 1.
MBLOCK="$(extract_merge "$RETRO")"
if [ "$ST_MERGE" = absent ]; then
  pending "part 4" "the 7a MERGE block (no '# retro 7a:' comment and no MERGE: token)" \
    "the worlds merge-ok merge-exit0-open merge-cleanup-failed merge-open merge-view-fails merge-view-lowercase are not asserted" 1
else
_mn="$(grep -c '^# retro 7a: merge the retro PR, then read its state from GitHub$' "$RETRO")" || _mn=0
if ! merge_shape_ok "$RETRO"; then
    echo "  FAIL  retro.md carries a MERGE marker but ${_mn} '# retro 7a: merge the retro PR, then read its state from GitHub' block(s), not exactly one naming <pr-number> and printing both MERGE outcomes — a present subject that is broken is a finding, not PENDING" >&2
    echo "retro-branch-behind-main: FAIL (part 4 subject broken)" >&2
    exit 1
fi
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

# ============================================================================
# BL-993's RECEIPT. Deploy-validate Step 2's record block commits the sprint PR number, its head and
# its squash sha to the sprint branch, and retro Step 1 reads that record before any derivation. It
# builds four re-pointed worlds from the resolved retro.md and deploy-validate.md: the block's
# record, the carry from it with gh never asked, the no-record control that is underivable, and a
# refused record that gh never overrides. Its subject is ABSENT when deploy-validate.md carries
# neither the block's comment nor a `RECORD: ` token, or retro.md never names
# `sprint-pr-merge.txt`, and then PENDING (RED in the distribution), like every subject above.
# ============================================================================
RCPT993="$DIR/receipt-bl993.sh"
[ -f "$RCPT993" ] || { echo "FIXTURE ERROR: missing $RCPT993" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/skills/ai-dlc/steps/deploy-validate.md"
_recw="$(grep -c -e '^# deploy-validate Step 2: record the sprint-PR merge' -e 'RECORD: ' "$DVSTEP")" || _recw=0
_recr="$(grep -c 'sprint-pr-merge\.txt' "$RETRO")" || _recr=0
if [ "$_recw" -eq 0 ] || [ "$_recr" -eq 0 ] || [ "$ST_CARRY" = absent ]; then
  pending "BL-993 receipt" "the sprint-merge record (deploy-validate.md's record block, retro.md's read of it)" "receipt-bl993.sh is not run" 1
else
bash "$RCPT993" "$RETRO" "$DVSTEP" > "$WORK/r993.out" 2>"$WORK/r993.err"; r993_rc=$?
r993_pass="$(grep -cE '^CELL (record|carry|badrecord|statedir) PASS ' "$WORK/r993.out")" || r993_pass=0
if [ "$r993_rc" = 9 ]; then
  bad "FIXTURE BROKEN: receipt-bl993.sh refused to build its worlds: $(head -1 "$WORK/r993.err")"
elif [ "$r993_rc" = 0 ] && [ "$r993_pass" = 4 ]; then
  ok "BL-993 receipt: exit 0, all four cells PASS: $(grep '^CELL ' "$WORK/r993.out" | cut -d' ' -f2-3 | tr '\n' ' ')"
else
  bad "BL-993 receipt: exit $r993_rc with $r993_pass of 4 CELL PASS lines: $(cat "$WORK/r993.out" "$WORK/r993.err" | head -c 600 | tr '\n' ' ')"
fi
fi


echo
# Liveness: a harness that silently stopped running assertions reads exactly like a clean pass.
# A PENDING skip is counted, so asserted + skipped must still be the full count.
# A distribution-layout absence is one FAILED assertion beside its skipped arms, so it is netted out.
if [ "$PENDN" -gt 0 ]; then
  echo "retro-branch-behind-main: $PENDN PENDING row(s) skipping $SKIPPED -- their subjects have not arrived in this retro.md"
fi
report_end retro-branch-behind-main "$((11 - SKIPPED + PENDBAD))"
