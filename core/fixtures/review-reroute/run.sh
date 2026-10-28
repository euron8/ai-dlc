#!/usr/bin/env bash
# review-reroute/run.sh -- the record-only route of a gate-1 re-review and Rule A, the gate-1 re-run
# after a QA rework: partition-review-diff.sh --route and --gate1-rerun, the Class line's grammar in
# merge-review-shards.sh, and validate-carried-findings.sh --classes.
#
# Usage: run.sh        Exit: 0 every assertion holds, 1 a regression, 2 fixture broken.
#
# WHAT IS AT STAKE. A route that sends a re-review to one serial reviewer when the rework edited code
# skips the review that would have caught it; that misroute is ship-blocking. So the route is a
# CONJUNCTION (every prior Critical/Important finding EVIDENCE|BOOKKEEPING, AND a delta with no code
# path) and fails closed. Rule A's error in the costly direction is a skipped gate-1 run over a real
# code change, so it re-runs on anything it cannot read as blank, comment or docstring.
#
# ARMS (world.sh holds the seeds; each range is one commit on the base B0):
#   C1a a prior with NO Class lines is ACCEPTED by --check-serial (old-engine carried findings)
#   C1b the same prior routes FULL over a records-only delta
#   C2  `Class: FOO` is REFUSED by --check-serial, naming the value
#   C3  `Class: EVIDENCE` / `Class: BOOKKEEPING` are accepted (the control for C2)
#   CL  --classes prints `<class>\t<carry string>` per finding, `-` when unclassed; --list is unchanged
#   R1  EVIDENCE|BOOKKEEPING prior + a delta editing a TEST file -> FULL (graph s317 2-6 p3's shape)
#   R2  EVIDENCE|BOOKKEEPING prior + a delta of review records, story records and captures -> ROUTE
#   R3  a prior with zero Critical/Important findings -> FULL
#   R4  a prior whose reviewed-sha names no commit -> FULL, exit 1
#   R5  a TEST-class prior finding + a records-only delta -> FULL
#   R6  a .py under test-results/ -> FULL, uncited AND with a captures list naming it (graph s318 2-3)
#   A1  an 18-line live smoke test added to an existing test file -> GATE1-RERUN (graph s319 1-1-b)
#   A2  a records- and captures-only rework -> GATE1-SKIP (graph s319 2-3a-a, 3-1-c)
#   A3  a comment-only test edit -> GATE1-SKIP
#   A4  a docstring-only edit -> GATE1-SKIP
#   A5  an added test file whose body is a docstring and a comment -> GATE1-RERUN (an ADDED test)
#   A6  a line inside a triple-quoted string ASSIGNED to a name -> GATE1-RERUN (it is code, not a
#       docstring: A4's near-miss, so a filter dropping every triple-quoted line dies here)
#   A7  a JS block-comment-only edit -> GATE1-SKIP
#   S1  implementation.md names both modes on their invocation lines; code-reviewer.md states the
#       class rule once
# MUTANTS (each in a copy of the subject's WHOLE script directory; each must kill exactly its arm):
#   m-classonly         the delta guard removed            -> R1 R6 (both are deltas the guard alone sends full)
#   m-failopen-missing  a finding with no Class routes     -> C1b
#   m-strict            an absent Class is refused         -> C1a
#   m-nodocstring       the docstring filter removed       -> A4
#   m-pyext             a cited .py leaves the code class  -> R6
# Each mutant co-trips no arm outside its decides list, measured at authoring (m-classonly's two deciding
# arms R1 and R6 are both deltas that only the guard sends full). The matrix is re-measured whenever an arm
# or mutant is added or changed, by the REMEASURE command below.
# MUTANT-MATRIX m-classonly decides=R1,R6 twins=R5
# MUTANT-MATRIX m-failopen-missing decides=C1b twins=R2
# MUTANT-MATRIX m-strict decides=C1a twins=C3
# MUTANT-MATRIX m-pyext decides=R6 twins=R1
# MUTANT-MATRIX m-nodocstring decides=A4 twins=A3
# MUTANT-MATRIX-DYNAMIC score why=the name is the fifth argument of each literal score call and reaches mutant_killed as "$name", so each m- name above is one literal call site
# MUTANT-MATRIX-REMEASURE bash core/fixtures/review-reroute/run.sh --matrix
# The unmutated copy must pass every arm first (CTL), so a copy that cannot run is FIXTURE BROKEN.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
SD=""; ROOT=""
d="$HERE"
while [ -n "$d" ] && [ "$d" != "/" ]; do
  for c in "$d/core/scripts" "$d/scripts/ai-dlc"; do
    [ -z "$SD" ] && [ -f "$c/partition-review-diff.sh" ] && SD="$c" && ROOT="$d"
  done
  [ -n "$SD" ] && break
  d="$(dirname "$d")"
done
[ -n "$SD" ] || { echo "FIXTURE ERROR: partition-review-diff.sh not found above $HERE in either layout; nothing was asserted" >&2; exit 2; }
for f in merge-review-shards.sh validate-carried-findings.sh artifact-path-config.sh; do
  [ -f "$SD/$f" ] || { echo "FIXTURE ERROR: $f is not beside $SD/partition-review-diff.sh" >&2; exit 2; }
done
GRAMMAR=""; STEP=""; ROLE=""
for c in "$ROOT/core/skills/ai-dlc" "$ROOT/.claude/skills/ai-dlc"; do
  [ -z "$GRAMMAR" ] && [ -f "$c/artifact-path-grammar.md" ] && GRAMMAR="$c/artifact-path-grammar.md"
  [ -z "$STEP" ] && [ -f "$c/steps/implementation.md" ] && STEP="$c/steps/implementation.md"
done
for c in "$ROOT/core/team-roles/code-reviewer.md" "$ROOT/.claude/team-roles/code-reviewer.md"; do
  [ -z "$ROLE" ] && [ -f "$c" ] && ROLE="$c"
done
[ -n "$GRAMMAR" ] && [ -n "$STEP" ] && [ -n "$ROLE" ] || { echo "FIXTURE ERROR: artifact-path-grammar.md, steps/implementation.md or code-reviewer.md not found under $ROOT" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/scripts/partition-review-diff.sh"
echo "HERMETIC-CONSUMED core/scripts/merge-review-shards.sh"
echo "HERMETIC-CONSUMED core/scripts/validate-carried-findings.sh"
echo "review-reroute: subject dir = $SD"
if [ "${1:-}" = "--matrix" ]; then echo "review-reroute: mode FULL (--matrix)"; else echo "review-reroute: mode PUSH"; fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/review-reroute.XXXXXX")" || exit 2
WORK="$(cd "$WORK" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT
. "$HERE/world.sh" || { echo "FIXTURE ERROR: cannot source world.sh" >&2; exit 2; }
W="$WORK/w"; mkdir -p "$W" || exit 2
rr_world "$W" "$GRAMMAR" || { echo "FIXTURE BROKEN: the seeded repository did not build" >&2; exit 2; }
R="$W/repo"; B0="$(rr_ref "$W" B0)"
for n in TEST_EDIT RECORDS SMOKE RECORDS_QA COMMENT DOCSTRING ASSIGNED NEWTEST JSCOMMENT; do
  [ -n "$(rr_ref "$W" "$n")" ] || { echo "FIXTURE BROKEN: seed $n has no ref" >&2; exit 2; }
done

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
MUT_LIB="$(cd "$HERE/../lib" 2>/dev/null && pwd)/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
MATRIX=0; [ "${1:-}" = "--matrix" ] && MATRIX=1
TAB="$(printf '\t')"
# Each arm takes the script directory under test and returns 0 when its assertion holds.
route() { OUT="$(bash "$1/partition-review-diff.sh" --route "$R" "$2" "$(rr_ref "$W" "$3")" --exclude-captures "$W/captures" 2>&1)"; RC=$?; }
rerun() { OUT="$(bash "$1/partition-review-diff.sh" --gate1-rerun "$R" "$B0" "$(rr_ref "$W" "$2")" --exclude-captures "$W/captures" 2>&1)"; RC=$?; }
serial() { OUT="$(AI_DLC_PROJECT_ROOT="$ROOT" bash "$1/merge-review-shards.sh" --check-serial "$2" --gate code-review 2>&1)"; RC=$?; }
arm_C1a() { serial "$1" "$W/prior-noclass.md"; [ "$RC" -eq 0 ] && grep -q '^SERIAL-OK: ' <<<"$OUT"; }
arm_C1b() { route "$1" "$W/prior-noclass.md" RECORDS; [ "$RC" -eq 1 ] && grep -q '^FULL: .*carries no Class line' <<<"$OUT"; }
arm_C2()  { serial "$1" "$W/prior-foo.md"; [ "$RC" -eq 2 ] && grep -q "^REFUSED: .*'Class: FOO' is not one of" <<<"$OUT"; }
arm_C3()  { serial "$1" "$W/prior-evidence.md"; [ "$RC" -eq 0 ] && grep -q '^SERIAL-OK: ' <<<"$OUT"; }
arm_CL()  {
  local a b c
  a="$(bash "$1/validate-carried-findings.sh" --classes "$W/prior-evidence.md" 2>/dev/null)" || return 1
  b="$(bash "$1/validate-carried-findings.sh" --classes "$W/prior-noclass.md" 2>/dev/null)" || return 1
  c="$(bash "$1/validate-carried-findings.sh" --list "$W/prior-evidence.md" 2>/dev/null)" || return 1
  [ "$a" = "EVIDENCE${TAB}The capture records no head sha
BOOKKEEPING${TAB}The story cites a stale line" ] \
    && [ "$b" = "-${TAB}The capture records no head sha
-${TAB}The story cites a stale line" ] \
    && [ "$c" = "The capture records no head sha
The story cites a stale line" ]
}
arm_R1() { route "$1" "$W/prior-evidence.md" TEST_EDIT; [ "$RC" -eq 1 ] && grep -q '^FULL: .*rebalancer/tests/test_engine.py' <<<"$OUT"; }
arm_R2() { route "$1" "$W/prior-evidence.md" RECORDS; [ "$RC" -eq 0 ] && grep -q '^ROUTE: 2 Critical/Important finding(s)' <<<"$OUT"; }
arm_R3() { route "$1" "$W/prior-zero.md" RECORDS; [ "$RC" -eq 1 ] && grep -q '^FULL: .*carries no Critical or Important finding' <<<"$OUT"; }
arm_R4() { route "$1" "$W/prior-badsha.md" RECORDS; [ "$RC" -eq 1 ] && grep -q '^FULL: the prior reviewed-sha .* names no commit' <<<"$OUT"; }
arm_R5() { route "$1" "$W/prior-code.md" RECORDS; [ "$RC" -eq 1 ] && grep -q '^FULL: .*is Class TEST' <<<"$OUT"; }
# R6: a .py under test-results/ is CODE whether or not the story cites it. The captures list a story
# yields never names one (--list-captures prints .txt/.log/.out only), so the cited spelling here is
# the harder one: a list that DOES name it still must not move it out of the code class.
arm_R6() {
  route "$1" "$W/prior-evidence.md" PYCAP; [ "$RC" -eq 1 ] && grep -q '^FULL: .*test-results/red_copy.py' <<<"$OUT" || return 1
  OUT="$(bash "$1/partition-review-diff.sh" --route "$R" "$W/prior-evidence.md" "$(rr_ref "$W" PYCAP)" --exclude-captures "$W/captures-cited-py" 2>&1)"; RC=$?
  [ "$RC" -eq 1 ] && grep -q '^FULL: .*test-results/red_copy.py' <<<"$OUT"
}
arm_A1() { rerun "$1" SMOKE;     [ "$RC" -eq 0 ] && grep -q '^GATE1-RERUN: .*server/test_live_smoke.py' <<<"$OUT"; }
arm_A2() { rerun "$1" RECORDS_QA; [ "$RC" -eq 0 ] && grep -q '^GATE1-SKIP: ' <<<"$OUT"; }
arm_A3() { rerun "$1" COMMENT;    [ "$RC" -eq 0 ] && grep -q '^GATE1-SKIP: .*(1 code path' <<<"$OUT"; }
arm_A4() { rerun "$1" DOCSTRING;  [ "$RC" -eq 0 ] && grep -q '^GATE1-SKIP: .*(1 code path' <<<"$OUT"; }
arm_A5() { rerun "$1" NEWTEST;    [ "$RC" -eq 0 ] && grep -q '^GATE1-RERUN: .*adds the test file rebalancer/tests/test_new.py' <<<"$OUT"; }
arm_A6() { rerun "$1" ASSIGNED;   [ "$RC" -eq 0 ] && grep -q '^GATE1-RERUN: .*rebalancer/engine.py' <<<"$OUT"; }
arm_A7() { rerun "$1" JSCOMMENT;  [ "$RC" -eq 0 ] && grep -q '^GATE1-SKIP: .*(1 code path' <<<"$OUT"; }
ARMS="C1a C1b C2 C3 CL R1 R2 R3 R4 R5 R6 A1 A2 A3 A4 A5 A6 A7"
# The arms that reach each mutated script. A mutant sweeps only these: every other arm never invokes the
# mutated file, so it cannot move. partition-review-diff.sh is reached by --route and --gate1-rerun (and
# --route shells validate-carried-findings.sh --classes); merge-review-shards.sh only by --check-serial.
# S1: the step text routes by both modes, on their invocation lines; the role file states the rule.
if grep -qF 'partition-review-diff.sh --route <worktree> <pass M-1 file> <frozen-sha>' "$STEP" \
   && grep -qF 'partition-review-diff.sh --gate1-rerun <worktree> <go-signal-sha> <frozen-sha>' "$STEP" \
   && [ "$(grep -c 'TEST is code-class' "$ROLE")" = 1 ]; then
  ok "S1: implementation.md invokes --route and --gate1-rerun; code-reviewer.md states 'TEST is code-class' once"
else bad "S1: implementation.md lost a --route/--gate1-rerun invocation, or code-reviewer.md does not state 'TEST is code-class' exactly once"; fi

# ---- mutants ------------------------------------------------------------------------------------
M="$WORK/mut"; mkdir -p "$M" || exit 2
# The copy holds every sibling the three subjects resolve beside themselves, and nothing else.
mkcopy() {
  local dst="$M/$1" f; mkdir -p "$dst" || return 1
  for f in partition-review-diff.sh merge-review-shards.sh validate-carried-findings.sh artifact-path-config.sh; do
    cp "$SD/$f" "$dst/$f" || return 1
  done
  echo "$dst"
}
# mut <name> <file> <old exact substring> <new> -> the mutated directory, or empty when nothing changed
mut() {
  local dst; dst="$(mkcopy "$1")" || { echo ""; return; }
  RR_O="$3" RR_N="$4" awk '!done && (i = index($0, ENVIRON["RR_O"])) { $0 = substr($0, 1, i - 1) ENVIRON["RR_N"] substr($0, i + length(ENVIRON["RR_O"])); done = 1 } { print }' \
    "$SD/$2" > "$dst/$2.m" && mv "$dst/$2.m" "$dst/$2" || { echo ""; return; }
  if cmp -s "$SD/$2" "$dst/$2"; then echo ""; else echo "$dst"; fi
}
CTL="$(mkcopy ctl)"
# The copy is byte-identical to the subject, so one sweep of it is the live sweep: it is the control a
# mutant is judged against AND the verdict on the subject itself.
same=1; for f in partition-review-diff.sh merge-review-shards.sh validate-carried-findings.sh artifact-path-config.sh; do
  [ -n "$CTL" ] && cmp -s "$SD/$f" "$CTL/$f" || same=0
done
[ "$same" -eq 1 ] || { echo "FIXTURE BROKEN: the control copy differs from $SD or did not build" >&2; exit 2; }
died=""
for a in $ARMS; do
  if "arm_$a" "$CTL"; then
    ok "$a"
    case "$a" in
      C1a) B_C1a=1 ;; C1b) B_C1b=1 ;; C2) B_C2=1 ;; C3) B_C3=1 ;; CL) B_CL=1 ;;
      R1) B_R1=1 ;; R2) B_R2=1 ;; R3) B_R3=1 ;; R4) B_R4=1 ;; R5) B_R5=1 ;; R6) B_R6=1 ;;
      A1) B_A1=1 ;; A2) B_A2=1 ;; A3) B_A3=1 ;; A4) B_A4=1 ;; A5) B_A5=1 ;; A6) B_A6=1 ;; A7) B_A7=1 ;;
    esac
  else died="$died $a"; bad "$a: rc=${RC:-?} out=$(head -2 <<<"${OUT:-}" | tr '\n' ' ')"; fi
done
if [ -z "$died" ]; then ok "CTL: the unmutated copy of $SD passes every arm"
else bad "CTL: FIXTURE BROKEN -- the unmutated copy failed:$died; no mutant verdict below is evidence"; fi
# score <base-pass flag> <mutant dir> "<deciding arms>" "<twin arms>" <mutant name>
# Per push a mutant DRIVES only its deciding arm(s) and its twin(s). A twin is an arm that stays GREEN under
# the mutant, so a tripped twin, or a deciding arm that stays green, fails the fixture. `run.sh --matrix`
# drives EVERY arm on EVERY mutant and prints one row per mutant: each arm with its cell (1 = the arm died,
# 0 = it stayed green) and the dead set by arm name.
CELLS=0; MCELLS=0
score() {
  local flag="$1" md="$2" decides="$3" twin="$4" name="$5" a dead="" want="" row=""
  [ -n "$md" ] || { bad "MUTANT $name: the mutation did not apply"; return; }
  if [ "$MATRIX" = 1 ]; then
    for a in $ARMS; do
      MCELLS=$((MCELLS + 1))
      if "arm_$a" "$md"; then row="$row $a=0"; else row="$row $a=1"; dead="$dead $a"; fi
    done
    echo "MATRIX $name:$row | dead:${dead:- none} | decides: $decides | twins: $twin"
    return
  fi
  for a in $decides $twin; do CELLS=$((CELLS + 1)); "arm_$a" "$md" || dead="$dead $a"; done
  for a in $decides; do want="$want $a"; done
  if [ "$dead" = "$want" ]; then
    mutant_killed "$flag" "$name" "MUTANT $name: killed by$want; twin $twin stays green"
  else bad "MUTANT $name SURVIVED or co-tripped: dead among [$decides $twin]:${dead:- none} (want exactly$want)"; fi
}
score "$(( ${B_R1:-0} && ${B_R6:-0} && ${B_R5:-0} ))" "$(mut classonly partition-review-diff.sh '  [ "$ncode" -eq 0 ] || full "the delta' '  : || full "the delta')" "R1 R6" R5 "m-classonly, the delta guard removed"
score "$(( ${B_C1b:-0} && ${B_R2:-0} ))" "$(mut failopen partition-review-diff.sh "-) full \"the prior finding '\$rd_' carries no Class line\" ;;" '-) ;;')" "C1b" "R2" "m-failopen-missing, a finding with no Class routes"
score "$(( ${B_C1a:-0} && ${B_C3:-0} ))" "$(mut strict merge-review-shards.sh 'ABSENT) continue ;;' 'ABSENT) refuse "$1:$cg_l_ carries no Class line" ;;')" "C1a" "C3" "m-strict, an absent Class is refused"
score "$(( ${B_R6:-0} && ${B_R1:-0} ))" "$(mut pyext partition-review-diff.sh '    if ((p in X) && p ~ /\.(txt|log|out)$/) next' '    if ((p in X) && p ~ /\.(txt|log|out|py)$/) next')" "R6" "R1" "m-pyext, a cited .py leaves the code class"
score "$(( ${B_A4:-0} && ${B_A3:-0} ))" "$(mut nodoc partition-review-diff.sh 'd = substr(u, 1, 3); if (cnt(u, d) < 2) { ds = d; dk = "doc" }; next' 'print NR; next')" "A4" "A3" "m-nodocstring, the docstring filter removed"

if [ "$MATRIX" = 1 ]; then echo "review-reroute: MATRIX measured, $MCELLS cells (mode FULL)"; [ "$fails" -eq 0 ] && exit 0; exit 1; fi
# A plain run drives only deciding and twin cells: no matrix-only cell ran, and the cell count is exactly the 11 named by the MUTANT-MATRIX header (deciding arms plus twins).
if [ "$MCELLS" -eq 0 ] && [ "$CELLS" -eq 11 ]; then ok "MODE PUSH: no matrix-only cell ran; $CELLS mutant cells driven (deciding arms plus twins)"
else bad "MODE PUSH: a plain run drove $MCELLS matrix-only cell(s) and $CELLS mutant cells (want 0 and 11)"; fi
if [ "$fails" -eq 0 ]; then echo "review-reroute: PASS"; exit 0; fi
echo "review-reroute: $fails FAILED"; exit 1
