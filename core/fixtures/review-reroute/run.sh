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
# GATE 2 (BL-844). The route reads a QA validation file the way it reads a code review: its classes
# through --classes, its delta from its column-0 reviewed-sha: (the go-signal sha).
#   Q1  a QA prior, EVIDENCE|BOOKKEEPING, + a records-only delta -> ROUTE
#   Q2  the same QA prior + a delta editing a TEST file -> FULL
#   Q3  a QA prior with a CODE finding + a records-only delta -> FULL
#   Q4  EVIDENCE|BOOKKEEPING + a part shard's hand-over finding (column-0 `handover:`, no Class) -> ROUTE,
#       and --list still carries the hand-over finding; Q4n, its near-miss, the same finding carrying only
#       `handover-run:` -> FULL (the skip covers a hand-over and nothing else)
#   Q5  EVIDENCE|BOOKKEEPING + a classed replay finding `handover-run: 1 AC3 GREEN-SURVIVED` (and
#       NO-BASELINE) -> FULL, a failed hard gate; Q5n, the same with RED -> ROUTE
#   QM  --check-serial --gate qa over a project whose qa.md declares the Class template: `Class: FOO`
#       REFUSED naming qa.md's set, `Class: EVIDENCE` SERIAL-OK; a ROUTED serial file (route:
#       record-only, canonical run, no replay and no handover-run: line) SERIAL-OK; the same root with
#       no template line checks nothing (`Class: FOO` SERIAL-OK)
#   S2  implementation.md names the gate-2 route invocation line, exactly; refused on a copy without it
# BL-809 ITEM 2, THE NARROWED RE-REVIEW (--narrow, --map --narrow-from). The MIXED delta edits engine.py
# and tests/test_engine.py; world.sh's nprior-* priors carry `Files:` as code-reviewer.md asks.
#   N1  CODE `Files: rebalancer/engine.py` + EVIDENCE -> NARROW engine.py, RESIDUE the test (exact)
#   N2  CODE Files: outside the delta, EVIDENCE Files: inside it -> FULL, empty named set
#   N3  CODE Files: outside the delta only -> FULL, empty named set (N2's near-miss with no EVIDENCE path)
#   N4  a second CODE finding with no Files: -> FULL naming it
#   CV  the conservation predicate, asked in process: the exact split holds; a lost, doubled or foreign path fails
#   NM  --map --narrow-from over MIXED_APP: the named part plus one `residue` part (2 parts, as flagless), the
#       maps differ, `narrow-from` in the manifest, the merge succeeds; the manifest with narrow-from dropped
#       is REFUSED by the map cmp and nothing is written
#   NP  the part bound: MIXED at --min-files 2 (flagless SERIAL) and THREE at --max-parts 2 narrow to more
#       parts than flagless and are REFUSED, exit 2, nothing printed or written; MIXED_APP is accepted
#   S3  implementation.md names the --narrow invocation and the --narrow-from partition line
# MUTANTS (each in a copy of the subject's WHOLE script directory; each must kill exactly its arm):
#   m-classonly         the delta guard removed            -> R1 R6 Q2 (each a delta the guard alone sends full)
#   m-failopen-missing  a finding with no Class routes     -> C1b Q4n
#   m-strict            an absent Class is refused         -> C1a
#   m-nodocstring       the docstring filter removed       -> A4
#   m-pyext             a cited .py leaves the code class  -> R6
#   m-noskip            the hand-over skip removed         -> Q4
#   m-nohrun            the failed-replay check removed    -> Q5
#   m-qagate            the merge's Class lift for code review only (B1 reverted) -> QM
#   m-qmd-none          qa.md's template deleted from the seeded tpl root -> QM (the merge's per-gate
#                       activation reads qa.md, not code-reviewer.md)
#   m-noconserve        the conservation assert always holds -> CV (no shipped input reaches the assert,
#                       which is why CV asks the predicate directly)
#   m-noresidue         the residue dropped from --narrow's split -> N1 (also trips N2 N3 NM NP: the
#                       conservation assert turns the dropped path into FULL, which is the guard working)
#   m-union             every class's Files: line narrows -> N2
#   m-emptyok           an empty named set narrows -> N2 N3
#   m-missingempty      a CODE finding with no Files: read as naming nothing -> N4
#   m-nfdrop            the merge re-derives a narrowed manifest without --narrow-from -> NM
#   m-nobound           the narrowed map's part bound removed -> NP
#   m-narrowfirst       --narrow answers in place of --route -> R2 Q1 (also trips the other --route arms)
# Each mutant co-trips no arm outside its decides list, measured at authoring (m-classonly's two deciding
# arms R1 and R6 are both deltas that only the guard sends full). The matrix is re-measured whenever an arm
# or mutant is added or changed, by the REMEASURE command below.
# MUTANT-MATRIX m-classonly decides=R1,R6,Q2 twins=R5
# MUTANT-MATRIX m-failopen-missing decides=C1b,Q4n twins=R2
# MUTANT-MATRIX m-strict decides=C1a twins=C3
# MUTANT-MATRIX m-pyext decides=R6 twins=R1
# MUTANT-MATRIX m-nodocstring decides=A4 twins=A3
# MUTANT-MATRIX m-noconserve decides=CV twins=N1
# MUTANT-MATRIX m-noresidue decides=N1 twins=N4
# MUTANT-MATRIX m-union decides=N2 twins=N3
# MUTANT-MATRIX m-emptyok decides=N2,N3 twins=N1
# MUTANT-MATRIX m-missingempty decides=N4 twins=N1
# MUTANT-MATRIX m-nfdrop decides=NM twins=N1
# MUTANT-MATRIX m-nobound decides=NP twins=NM
# MUTANT-MATRIX m-narrowfirst decides=R2,Q1 twins=A1
# MUTANT-MATRIX m-noskip decides=Q4 twins=Q1
# MUTANT-MATRIX m-nohrun decides=Q5 twins=Q5n
# MUTANT-MATRIX m-qagate decides=QM twins=Q1
# MUTANT-MATRIX m-qmd-none decides=QM twins=Q1
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
for f in merge-review-shards.sh validate-carried-findings.sh artifact-path-config.sh record-only-diff.sh partition-document.sh content-seal.sh; do
  [ -f "$SD/$f" ] || { echo "FIXTURE ERROR: $f is not beside $SD/partition-review-diff.sh" >&2; exit 2; }
done
GRAMMAR=""; STEP=""; ROLE=""; GATEMD=""; QAMD=""
for c in "$ROOT/core/skills/ai-dlc" "$ROOT/.claude/skills/ai-dlc"; do
  [ -z "$GRAMMAR" ] && [ -f "$c/artifact-path-grammar.md" ] && GRAMMAR="$c/artifact-path-grammar.md"
  [ -z "$STEP" ] && [ -f "$c/steps/implementation.md" ] && STEP="$c/steps/implementation.md"
  [ -z "$GATEMD" ] && [ -f "$c/steps/gate-validation.md" ] && GATEMD="$c/steps/gate-validation.md"
done
for c in "$ROOT/core/team-roles" "$ROOT/.claude/team-roles"; do
  [ -z "$ROLE" ] && [ -f "$c/code-reviewer.md" ] && ROLE="$c/code-reviewer.md"
  [ -z "$QAMD" ] && [ -f "$c/qa.md" ] && QAMD="$c/qa.md"
done
[ -n "$GRAMMAR" ] && [ -n "$STEP" ] && [ -n "$ROLE" ] && [ -n "$GATEMD" ] && [ -n "$QAMD" ] || { echo "FIXTURE ERROR: artifact-path-grammar.md, steps/implementation.md, steps/gate-validation.md, code-reviewer.md or qa.md not found under $ROOT" >&2; exit 2; }
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
QR="$WORK/qroot"
rr_qroot "$QR" "$GATEMD" "$ROLE" "$QAMD" || { echo "FIXTURE BROKEN: the seeded qa.md roots did not build (code-reviewer.md carries no Class template line?)" >&2; exit 2; }
grep -q '^Class: ' "$QR/tpl/core/team-roles/qa.md" && ! grep -q '^Class:' "$QR/none/core/team-roles/qa.md" \
  || { echo "FIXTURE BROKEN: the tpl root's qa.md carries no Class template, or the none root's still carries one" >&2; exit 2; }
rr_qserial "$W/qserial-evidence.md" EVIDENCE; rr_qserial "$W/qserial-foo.md" FOO

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
  [ "$a" = "EVIDENCE${TAB}The capture records no head sha${TAB}-
BOOKKEEPING${TAB}The story cites a stale line${TAB}-" ] \
    && [ "$b" = "-${TAB}The capture records no head sha${TAB}-
-${TAB}The story cites a stale line${TAB}-" ] \
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
# Gate 2. QROOT names the seeded root QM reads (a mutant may point it at another).
arm_Q1() { route "$1" "$W/qprior-evidence.md" RECORDS; [ "$RC" -eq 0 ] && grep -q '^ROUTE: 2 Critical/Important finding(s)' <<<"$OUT"; }
arm_Q2() { route "$1" "$W/qprior-evidence.md" TEST_EDIT; [ "$RC" -eq 1 ] && grep -q '^FULL: .*rebalancer/tests/test_engine.py' <<<"$OUT"; }
arm_Q3() { route "$1" "$W/qprior-code.md" RECORDS; [ "$RC" -eq 1 ] && grep -q "^FULL: .*'The Dev Agent Record cites a stale count' is Class CODE" <<<"$OUT"; }
arm_Q4() {
  local l
  route "$1" "$W/qprior-handover.md" RECORDS; [ "$RC" -eq 0 ] && grep -q '^ROUTE: 2 Critical/Important finding(s)' <<<"$OUT" || return 1
  l="$(bash "$1/validate-carried-findings.sh" --list "$W/qprior-handover.md" 2>/dev/null)" || return 1
  [ "$l" = "The full-collection capture names no head
The Dev Agent Record cites a stale count
AC3 replay handed to the cross shard" ]
}
arm_Q4n() { route "$1" "$W/qprior-horun.md" RECORDS; [ "$RC" -eq 1 ] && grep -q "^FULL: the prior finding 'AC3 replay result' carries no Class line" <<<"$OUT"; }
# Q5: a classed replay finding whose result is not RED is a failed hard gate -> FULL (both results);
# Q5n, its near-miss, the same finding with RED -> ROUTE over all three findings.
arm_Q5() {
  route "$1" "$W/qprior-hr-GREEN-SURVIVED.md" RECORDS; [ "$RC" -eq 1 ] && grep -q "^FULL: .*'handover-run: 1 AC3 GREEN-SURVIVED', a hand-over replay whose result is not RED" <<<"$OUT" || return 1
  route "$1" "$W/qprior-hr-NO-BASELINE.md" RECORDS; [ "$RC" -eq 1 ] && grep -q "^FULL: .*'handover-run: 1 AC3 NO-BASELINE'" <<<"$OUT"
}
arm_Q5n() { route "$1" "$W/qprior-hr-RED.md" RECORDS; [ "$RC" -eq 0 ] && grep -q '^ROUTE: 3 Critical/Important finding(s)' <<<"$OUT"; }
qserial() { OUT="$(AI_DLC_PROJECT_ROOT="$2" bash "$1/merge-review-shards.sh" --check-serial "$3" --gate qa 2>&1)"; RC=$?; }
arm_QM() {
  local t="${QROOT:-$QR/tpl}"
  qserial "$1" "$t" "$W/qserial-foo.md"
  [ "$RC" -eq 2 ] && grep -q "^REFUSED: .*'Class: FOO' is not one of BOOKKEEPING CODE EVIDENCE TEST (qa.md's template)" <<<"$OUT" || return 1
  qserial "$1" "$t" "$W/qserial-evidence.md"
  [ "$RC" -eq 0 ] && grep -q '^SERIAL-OK: .* verdict=PASS' <<<"$OUT" && ! grep -q '^LEGACY' <<<"$OUT" || return 1
  qserial "$1" "$QR/none" "$W/qserial-foo.md"
  [ "$RC" -eq 0 ] && grep -q '^SERIAL-OK: .* verdict=PASS' <<<"$OUT"
}
# BL-809 item 2: --narrow over the MIXED delta (engine.py, which nprior-a's CODE finding names, and
# tests/test_engine.py, which nothing names), and the merge of a --narrow-from manifest.
narrow() { OUT="$(bash "$1/partition-review-diff.sh" --narrow "$R" "$2" "$(rr_ref "$W" MIXED)" --exclude-captures "$W/captures" 2>&1)"; RC=$?; }
arm_N1() { narrow "$1" "$W/nprior-a.md"; [ "$RC" -eq 0 ] && [ "$OUT" = "NARROW:${TAB}rebalancer/engine.py
RESIDUE:${TAB}rebalancer/tests/test_engine.py" ]; }
arm_N2() { narrow "$1" "$W/nprior-b.md"; [ "$RC" -eq 1 ] && grep -q '^FULL: no code path of the delta .* is a file the prior' <<<"$OUT"; }
arm_N3() { narrow "$1" "$W/nprior-c.md"; [ "$RC" -eq 1 ] && grep -q '^FULL: no code path of the delta .* is a file the prior' <<<"$OUT"; }
arm_N4() { narrow "$1" "$W/nprior-d.md"; [ "$RC" -eq 1 ] && grep -q "^FULL: the prior CODE finding 'The capture records no head sha' carries no Files: line" <<<"$OUT"; }
# CV: the conservation predicate asked directly (the program sourced; clause 5's seam): a lost path, a
# path on both lists and a list naming a path outside the delta each fail; the exact split holds.
arm_CV() {
  local d="$WORK/cv"; mkdir -p "$d" || return 1
  printf 'M\ta.py\nM\tb.py\n' > "$d/code"; printf 'a.py\n' > "$d/n"; printf 'b.py\n' > "$d/r"; : > "$d/e"
  printf 'a.py\nb.py\n' > "$d/both"; printf 'a.py\nc.py\n' > "$d/x"
  ( . "$1/partition-review-diff.sh" && conserved "$d/n" "$d/r" "$d/code" && ! conserved "$d/n" "$d/e" "$d/code" \
      && ! conserved "$d/both" "$d/r" "$d/code" && ! conserved "$d/x" "$d/e" "$d/code" )
}
# NM: the narrowed map and its merge, over MIXED_APP (MIXED plus a web/app.js edit) and nprior-app
# (`Files: web/app.js`, inside the repository). Flagless that delta is 2 parts (rebalancer/*, web/); narrowed
# it is web/app.js plus one last `residue` part, also 2, so the part bound admits it and the two maps differ.
# The manifest records `narrow-from`, the merge of three APPROVED shards succeeds; the same manifest with
# its narrow-from line dropped is REFUSED by the map cmp, and nothing is written.
arm_NM() {
  local s sd o
  s="$(rr_ref "$W" MIXED_APP)"; sd="$R/docs/reviews/s1/shards/1-code-review-${s:0:12}-p2"; o="$R/docs/reviews/s1/1-code-review-p2.md"
  rm -rf "$R/docs/reviews/s1/shards"; rm -f "$o"
  OUT="$(bash "$1/partition-review-diff.sh" --map "$R" "$B0" "$s" --min-files 2 --narrow-from "$R/docs/reviews/s1/nprior-app.md" --shard-dir "$sd" 2>&1)"; RC=$?
  [ "$RC" -eq 0 ] && [ "$OUT" = "1${TAB}web/*${TAB}web/app.js
2${TAB}residue${TAB}rebalancer/engine.py${TAB}rebalancer/tests/test_engine.py" ] && grep -qx "narrow-from${TAB}docs/reviews/s1/nprior-app.md" "$sd/.manifest" || return 1
  rr_nshard "$sd" 1 "$s"; rr_nshard "$sd" 2 "$s"; rr_nshard "$sd" cross "$s"
  OUT="$(AI_DLC_PROJECT_ROOT="$ROOT" bash "$1/merge-review-shards.sh" "$sd" --gate code-review --out "$o" 2>&1)"; RC=$?
  [ "$RC" -eq 0 ] && grep -q '^MERGED: .* parts=2 ' <<<"$OUT" || return 1
  rm -f "$o"; grep -v "^narrow-from${TAB}" "$sd/.manifest" > "$sd/.m" && mv "$sd/.m" "$sd/.manifest" || return 1
  OUT="$(AI_DLC_PROJECT_ROOT="$ROOT" bash "$1/merge-review-shards.sh" "$sd" --gate code-review --out "$o" 2>&1)"; RC=$?
  # Re-derived flagless, this delta partitions (rc 0) into a different map, so the refusal is the map cmp.
  [ "$RC" -eq 2 ] && grep -qE '^REFUSED: the part map re-derived from .* differs from the map it records' <<<"$OUT" && [ ! -e "$o" ]
}
# NP: the part bound. A narrowed map never has more parts than the un-narrowed map of the same delta and
# options (SERIAL counts as one): MIXED at --min-files 2 (flagless SERIAL, narrowed 2) and THREE at
# --max-parts 2 (flagless 2, narrowed 3) are each REFUSED, exit 2, nothing on stdout and no shard dir
# written; MIXED_APP (2 against 2) is accepted.
np_map() { # <script dir> <seed> <prior> <shard dir> [extra args...]
  local sd="$1" s="$2" p="$3" d="$4"; shift 4
  bash "$sd/partition-review-diff.sh" --map "$R" "$B0" "$(rr_ref "$W" "$s")" --min-files 2 "$@" --narrow-from "$R/docs/reviews/s1/$p" --shard-dir "$d" > "$WORK/np.out" 2> "$WORK/np.err"; RC=$?
  OUT="$(cat "$WORK/np.err" "$WORK/np.out")"
}
np_refused() { [ "$RC" -eq 2 ] && [ ! -s "$WORK/np.out" ] && [ ! -e "$1" ] && grep -q "^partition-review-diff: REFUSED — .*the narrowed map would need more reviewers than the full delta map ($2 parts against $3)" "$WORK/np.err"; }
arm_NP() {
  local d; d="$(mktemp -d "$WORK/np.XXXXXX")" || return 1
  np_map "$1" MIXED 1-code-review.md "$d/a"; np_refused "$d/a" 2 1 || return 1
  np_map "$1" THREE nprior-two.md "$d/b" --max-parts 2; np_refused "$d/b" 3 2 || return 1
  np_map "$1" MIXED_APP nprior-app.md "$d/c"; [ "$RC" -eq 0 ] && [ "$(grep -c . "$WORK/np.out")" = 2 ] && [ -f "$d/c/.manifest" ]
}
ARMS="C1a C1b C2 C3 CL R1 R2 R3 R4 R5 R6 A1 A2 A3 A4 A5 A6 A7 Q1 Q2 Q3 Q4 Q4n Q5 Q5n QM N1 N2 N3 N4 CV NM NP"
# The arms that reach each mutated script. A mutant sweeps only these: every other arm never invokes the
# mutated file, so it cannot move. partition-review-diff.sh is reached by --route, --gate1-rerun, --narrow
# and --map --narrow-from (and --route and --narrow shell validate-carried-findings.sh --classes);
# merge-review-shards.sh by --check-serial and by NM's merge of a narrowed shard directory.
# S1: the step text routes by both modes, on their invocation lines; the role file states the rule.
if grep -qF 'partition-review-diff.sh --route <worktree> <pass M-1 file> <frozen-sha>' "$STEP" \
   && grep -qF 'partition-review-diff.sh --gate1-rerun <worktree> <go-signal-sha> <frozen-sha>' "$STEP" \
   && [ "$(grep -c 'TEST is code-class' "$ROLE")" = 1 ]; then
  ok "S1: implementation.md invokes --route and --gate1-rerun; code-reviewer.md states 'TEST is code-class' once"
else bad "S1: implementation.md lost a --route/--gate1-rerun invocation, or code-reviewer.md does not state 'TEST is code-class' exactly once"; fi
# S2: the gate-2 re-validation routes through --route on its own invocation line (exact string). The
# predicate is proved on a copy with the line removed before it reads the shipped step.
S2_LINE='scripts/ai-dlc/partition-review-diff.sh --route <worktree> <QA pass M-1 file> <go-signal-sha> --exclude-captures <captures file>'
p_s2() { grep -qF -- "$S2_LINE" "$1"; }
{ printf 'decoy step\n'; printf '%s\n' "$S2_LINE"; } > "$WORK/s2-has.md"
grep -vF -- "$S2_LINE" "$WORK/s2-has.md" > "$WORK/s2-not.md"
if cmp -s "$WORK/s2-has.md" "$WORK/s2-not.md" || ! p_s2 "$WORK/s2-has.md" || p_s2 "$WORK/s2-not.md"; then
  bad "S2: FIXTURE BROKEN -- the gate-2 route predicate does not tell a step carrying the line from one without it"
elif p_s2 "$STEP"; then ok "S2: implementation.md names the gate-2 route line: $S2_LINE"
else bad "S2: implementation.md does not name the gate-2 route line '$S2_LINE' (a gate-2 re-validation is never routed)"; fi

# S3: the step text narrows a mixed re-review through --narrow and partitions with --narrow-from, on
# their invocation lines (exact strings), proved on a copy with them removed first.
S3_A='scripts/ai-dlc/partition-review-diff.sh --narrow <worktree> <pass M-1 file> <frozen-sha> --exclude-captures <captures file>'
S3_B='--narrow-from <pass M-1 file> --shard-dir docs/reviews/s<N>/shards/<story-index>-code-review-<sha12>-p<M>'
p_s3() { grep -qF -- "$S3_A" "$1" && grep -qF -- "$S3_B" "$1"; }
{ printf 'decoy step\n'; printf '%s\n' "$S3_A" "$S3_B"; } > "$WORK/s3-has.md"
grep -vF -- "$S3_B" "$WORK/s3-has.md" > "$WORK/s3-not.md"
if cmp -s "$WORK/s3-has.md" "$WORK/s3-not.md" || ! p_s3 "$WORK/s3-has.md" || p_s3 "$WORK/s3-not.md"; then
  bad "S3: FIXTURE BROKEN -- the narrowing predicate does not tell a step carrying both lines from one without"
elif p_s3 "$STEP"; then ok "S3: implementation.md names the --narrow invocation and the --narrow-from partition"
else bad "S3: implementation.md does not name '$S3_A' and '$S3_B' (a mixed re-review is never narrowed)"; fi

# ---- mutants ------------------------------------------------------------------------------------
M="$WORK/mut"; mkdir -p "$M" || exit 2
# The copy holds every sibling the three subjects resolve beside themselves, and nothing else.
mkcopy() {
  local dst="$M/$1" f; mkdir -p "$dst" || return 1
  for f in partition-review-diff.sh merge-review-shards.sh validate-carried-findings.sh artifact-path-config.sh record-only-diff.sh partition-document.sh content-seal.sh; do
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
same=1; for f in partition-review-diff.sh merge-review-shards.sh validate-carried-findings.sh artifact-path-config.sh partition-document.sh; do
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
      Q1) B_Q1=1 ;; Q2) B_Q2=1 ;; Q3) B_Q3=1 ;; Q4) B_Q4=1 ;; Q4n) B_Q4n=1 ;; Q5) B_Q5=1 ;; Q5n) B_Q5n=1 ;; QM) B_QM=1 ;;
      N1) B_N1=1 ;; N2) B_N2=1 ;; N3) B_N3=1 ;; N4) B_N4=1 ;; CV) B_CV=1 ;; NM) B_NM=1 ;; NP) B_NP=1 ;;
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
  local flag="$1" md="$2" decides="$3" twin="$4" name="$5" a dead="" want="" row="" id="${5%%,*}"
  [ -n "$md" ] || { bad "MUTANT $name: the mutation did not apply"; return; }
  if [ "$MATRIX" = 1 ]; then
    for a in $ARMS; do
      MCELLS=$((MCELLS + 1))
      if "arm_$a" "$md"; then row="$row $a=0"; else row="$row $a=1"; dead="$dead $a"; fi
    done
    echo "MATRIX $id:$row | dead:${dead:- none} | decides: $decides | twins: $twin"
    return
  fi
  for a in $decides $twin; do CELLS=$((CELLS + 1)); "arm_$a" "$md" || dead="$dead $a"; done
  for a in $decides; do want="$want $a"; done
  if [ "$dead" = "$want" ]; then
    mutant_killed "$flag" "$id" "MUTANT $name: killed by$want; twin $twin stays green"
  else bad "MUTANT $name SURVIVED or co-tripped: dead among [$decides $twin]:${dead:- none} (want exactly$want)"; fi
}
score "$(( ${B_R1:-0} && ${B_R6:-0} && ${B_Q2:-0} && ${B_R5:-0} ))" "$(mut classonly partition-review-diff.sh '  [ "$ncode" -eq 0 ] || full "the delta' '  : || full "the delta')" "R1 R6 Q2" R5 "m-classonly, the delta guard removed"
score "$(( ${B_C1b:-0} && ${B_Q4n:-0} && ${B_R2:-0} ))" "$(mut failopen partition-review-diff.sh "-) full \"the prior finding '\$rd_' carries no Class line\" ;;" '-) ;;')" "C1b Q4n" "R2" "m-failopen-missing, a finding with no Class routes"
score "$(( ${B_Q4:-0} && ${B_Q1:-0} ))" "$(mut noskip validate-carried-findings.sh '[ "$disp" != "HANDOVER SKIP" ] && printf' 'printf')" "Q4" "Q1" "m-noskip, the hand-over skip removed"
score "$(( ${B_Q5:-0} && ${B_Q5n:-0} ))" "$(mut nohrun partition-review-diff.sh '  [ -z "$hrun" ] || full' '  : || full')" "Q5" "Q5n" "m-nohrun, the failed-replay check removed"
score "$(( ${B_QM:-0} && ${B_Q1:-0} ))" "$(mut qagate merge-review-shards.sh 'CLASS_SET="$(awk "$CLASS_SET_AWK" "$ROLE_MD"' 'CLASS_SET=""; [ "$GATE" != code-review ] || CLASS_SET="$(awk "$CLASS_SET_AWK" "$ROLE_MD"')" "QM" "Q1" "m-qagate, the merge's Class lift for code review only (B1 reverted)"
# m-qmd-none: the unmutated scripts over a tpl root whose qa.md lost its template (code-reviewer.md keeps
# its own), so a merge reading the wrong role file for --gate qa would still refuse FOO.
mkdir -p "$WORK/qroot-strip" && cp -R "$QR/tpl" "$WORK/qroot-strip/tpl" \
  && grep -v '^Class:' "$QR/tpl/core/team-roles/qa.md" > "$WORK/qroot-strip/tpl/core/team-roles/qa.md"
if cmp -s "$QR/tpl/core/team-roles/qa.md" "$WORK/qroot-strip/tpl/core/team-roles/qa.md"; then bad "MUTANT m-qmd-none: the mutation did not apply"
else
  died=""; for a in QM Q1; do CELLS=$((CELLS + 1)); QROOT="$WORK/qroot-strip/tpl" "arm_$a" "$CTL" || died="$died $a"; done
  if [ "$died" = " QM" ]; then mutant_killed "$(( ${B_QM:-0} && ${B_Q1:-0} ))" m-qmd-none "MUTANT m-qmd-none: killed by QM alone, twin Q1 green (the --gate qa activation reads qa.md)"
  else bad "MUTANT m-qmd-none: arms that died:${died:- none} (want exactly QM)"; fi
fi
score "$(( ${B_C1a:-0} && ${B_C3:-0} ))" "$(mut strict merge-review-shards.sh 'ABSENT) continue ;;' 'ABSENT) refuse "$1:$cg_l_ carries no Class line" ;;')" "C1a" "C3" "m-strict, an absent Class is refused"
score "$(( ${B_R6:-0} && ${B_R1:-0} ))" "$(mut pyext partition-review-diff.sh '    if ((p in X) && p ~ /\.(txt|log|out)$/) next' '    if ((p in X) && p ~ /\.(txt|log|out|py)$/) next')" "R6" "R1" "m-pyext, a cited .py leaves the code class"
score "$(( ${B_A4:-0} && ${B_A3:-0} ))" "$(mut nodoc partition-review-diff.sh 'd = substr(u, 1, 3); if (cnt(u, d) < 2) { ds = d; dk = "doc" }; next' 'print NR; next')" "A4" "A3" "m-nodocstring, the docstring filter removed"
# BL-809 item 2.
score "$(( ${B_CV:-0} && ${B_N1:-0} ))" "$(mut noconserve partition-review-diff.sh 'END { exit !(bad == 0 && n == m) }' 'END { exit 0 }')" "CV" "N1" "m-noconserve, the conservation assert always holds"
score "$(( ${B_N1:-0} && ${B_N4:-0} ))" "$(mut noresidue partition-review-diff.sh 'else print $2 > ENVIRON["NR_R"]' 'else next')" "N1" "N4" "m-noresidue, the residue dropped from --narrow's split"
score "$(( ${B_N2:-0} && ${B_N3:-0} ))" "$(mut union partition-review-diff.sh 'if ($1 == "CODE" || $1 == "TEST") { n = split($3' 'if ($1 != "") { n = split($3')" "N2" "N3" "m-union, every class's Files: line narrows"
score "$(( ${B_N2:-0} && ${B_N3:-0} && ${B_N1:-0} ))" "$(mut emptyok partition-review-diff.sh '  [ "$nnam" -ge 1 ] || full' '  : || full')" "N2 N3" "N1" "m-emptyok, an empty named set narrows"
score "$(( ${B_N4:-0} && ${B_N1:-0} ))" "$(mut missingempty partition-review-diff.sh '-|"") full "the prior $rc_ finding' '-|"") : "the prior $rc_ finding')" "N4" "N1" "m-missingempty, a CODE finding with no Files: read as naming nothing"
score "$(( ${B_NM:-0} && ${B_N1:-0} ))" "$(mut nfdrop merge-review-shards.sh '  NF_ARGS=(--narrow-from "$NF_TOP/$M_NF")' '  NF_ARGS=()')" "NM" "N1" "m-nfdrop, the merge re-derives a narrowed manifest without --narrow-from"
score "$(( ${B_NP:-0} && ${B_NM:-0} ))" "$(mut nobound partition-review-diff.sh '[ "$nm_n" -le "$fl_n" ] || refuse' ': || refuse')" "NP" "NM" "m-nobound, the narrowed map's part bound removed"
score "$(( ${B_R2:-0} && ${B_Q1:-0} && ${B_A1:-0} ))" "$(mut narrowfirst partition-review-diff.sh '  --route) shift; route_mode "$@" ;;' '  --route) shift; narrow_mode "$@" ;;')" "R2 Q1" "A1" "m-narrowfirst, --narrow answers in place of --route"

if [ "$MATRIX" = 1 ]; then echo "review-reroute: MATRIX measured, $MCELLS cells (mode FULL)"; [ "$fails" -eq 0 ] && exit 0; exit 1; fi
# A plain run drives only deciding and twin cells: no matrix-only cell ran, and the cell count is exactly the 39 named by the MUTANT-MATRIX header (deciding arms plus twins).
if [ "$MCELLS" -eq 0 ] && [ "$CELLS" -eq 39 ]; then ok "MODE PUSH: no matrix-only cell ran; $CELLS mutant cells driven (deciding arms plus twins)"
else bad "MODE PUSH: a plain run drove $MCELLS matrix-only cell(s) and $CELLS mutant cells (want 0 and 39)"; fi
if [ "$fails" -eq 0 ]; then echo "review-reroute: PASS"; exit 0; fi
echo "review-reroute: $fails FAILED"; exit 1
