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
#   RV  merge-review-shards.sh --read-verdict (BL-931): a serial APPROVED and a merged NEEDS_REWORK (shard table,
#       three shard sections with their own reviewed-sha and advisor lines) read VERDICT; two values, no match and
#       PASS under --gate code-review REFUSED; control: --check-serial refuses the merged file on its advisor lines
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

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
MUT_LIB="$(cd "$HERE/../lib" 2>/dev/null && pwd)/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
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
# Gate 2.
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
  local t="$QR/tpl"
  qserial "$1" "$t" "$W/qserial-foo.md"
  [ "$RC" -eq 2 ] && grep -q "^REFUSED: .*'Class: FOO' is not one of BOOKKEEPING CODE EVIDENCE TEST (qa.md's template)" <<<"$OUT" || return 1
  qserial "$1" "$t" "$W/qserial-evidence.md"
  # The run-record LEGACY line (BL-905) is expected here: the seeded qa.md roots drop its sentinel (world.sh rr_qroot).
  [ "$RC" -eq 0 ] && grep -q '^SERIAL-OK: .* verdict=PASS' <<<"$OUT" \
    && [ "$(awk '/^LEGACY/ && !/^LEGACY: canonical-run record not checked:/ { n++ } END { print n + 0 }' <<<"$OUT")" = 0 ] || return 1
  qserial "$1" "$QR/none" "$W/qserial-foo.md"
  [ "$RC" -eq 0 ] && grep -q '^SERIAL-OK: .* verdict=PASS' <<<"$OUT"
}
# RV (BL-931): merge-review-shards.sh --read-verdict, the lifted Check 1 reader and verdict set over ONE review file,
# serial or merged, and no seat rule. A serial APPROVED and a merged NEEDS_REWORK (a shard table, two shard sections,
# each with its own reviewed-sha and advisor line) read; two values, no match, and PASS under --gate code-review
# (outside code-reviewer.md's set) each REFUSED. The control: --check-serial refuses the same merged file on its
# advisor lines, so RV's merged cell is not --check-serial's policy.
rv_files() {
  printf '# Code Review: 1\n\nreviewed-sha: %s\n\n## Verdict\nAPPROVED\n\n## Findings\n\nNone.\n' "$B0" > "$W/rv-serial.md"
  { printf '# Code Review: 1 (merged from 3 shards)\n\n## Summary\n\nThree shards reviewed.\n\n## Verdict\nNEEDS_REWORK\n\n'
    printf '| Shard | Verdict |\n|---|---|\n| 1 | NEEDS_REWORK |\n| 2 | APPROVED |\n| cross | APPROVED |\n'
    for k in 1 2 cross; do printf '\n## Shard: %s\n\nreviewed-sha: %s\nshard-verdict: APPROVED\nadvisor: called\n\n## Findings\n\nNone.\n' "$k" "$B0"; done
  } > "$W/rv-merged.md"
  printf '# Code Review: 1\n\n## Verdict\nAPPROVED\n\nVerdict: NEEDS_REWORK\n' > "$W/rv-two.md"
  printf '# Code Review: 1\n\n## Result\nAPPROVED\n' > "$W/rv-none.md"
  printf '# Code Review: 1\n\n## Verdict\nPASS\n' > "$W/rv-pass.md"
}
rv() { OUT="$(AI_DLC_PROJECT_ROOT="$ROOT" bash "$1/merge-review-shards.sh" --read-verdict "$2" --gate code-review 2>&1)"; RC=$?; }
arm_RV() {
  rv "$1" "$W/rv-serial.md"; [ "$RC" -eq 0 ] && [ "$OUT" = "VERDICT: $W/rv-serial.md verdict=APPROVED" ] || return 1
  rv "$1" "$W/rv-merged.md"; [ "$RC" -eq 0 ] && [ "$OUT" = "VERDICT: $W/rv-merged.md verdict=NEEDS_REWORK" ] || return 1
  rv "$1" "$W/rv-two.md"; [ "$RC" -eq 2 ] && grep -q '^REFUSED: .* reading 2 different values (APPROVED NEEDS_REWORK)' <<<"$OUT" || return 1
  rv "$1" "$W/rv-none.md"; [ "$RC" -eq 2 ] && grep -q "^REFUSED: .* matches Check 1's verdict pattern 0 time(s)" <<<"$OUT" || return 1
  rv "$1" "$W/rv-pass.md"; [ "$RC" -eq 2 ] && grep -q "^REFUSED: Check 1 reads 'PASS' from .*, which is not one of APPROVED NEEDS_REWORK BLOCKED" <<<"$OUT" || return 1
  serial "$1" "$W/rv-merged.md"; [ "$RC" -eq 2 ] && grep -q "^REFUSED: .* carries 3 'advisor:' lines" <<<"$OUT"
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
  # One fx_inproc per conserved call (P2's unit for a guarded subject); the literal subject path is passed.
  ( . "$1/partition-review-diff.sh" \
      && fx_inproc core/scripts/partition-review-diff.sh && conserved "$d/n" "$d/r" "$d/code" \
      && fx_inproc core/scripts/partition-review-diff.sh && ! conserved "$d/n" "$d/e" "$d/code" \
      && fx_inproc core/scripts/partition-review-diff.sh && ! conserved "$d/both" "$d/r" "$d/code" \
      && fx_inproc core/scripts/partition-review-diff.sh && ! conserved "$d/x" "$d/e" "$d/code" )
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
ARMS="C1a C1b C2 C3 CL R1 R2 R3 R4 R5 R6 A1 A2 A3 A4 A5 A6 A7 Q1 Q2 Q3 Q4 Q4n Q5 Q5n QM N1 N2 N3 N4 CV NM NP RV"
rv_files
# S1: the step text routes by both modes, on their invocation lines; the role file states the rule.
if grep -qF '`gate-transition.sh <story> 1 --pass M <flags>` first asks `partition-review-diff.sh --route`' "$STEP" \
   && grep -qF 'partition-review-diff.sh --gate1-rerun` first' "$STEP" \
   && [ "$(grep -c 'TEST is code-class' "$ROLE")" = 1 ]; then
  ok "S1: implementation.md invokes --route and --gate1-rerun; code-reviewer.md states 'TEST is code-class' once"
else bad "S1: implementation.md lost a --route/--gate1-rerun invocation, or code-reviewer.md does not state 'TEST is code-class' exactly once"; fi
# S2: the gate-2 re-validation routes through --route on its own invocation line (exact string). The
# predicate is proved on a copy with the line removed before it reads the shipped step.
S2_LINE='`gate-transition.sh <story> 2 --pass M <flags>` first asks `--route` of the'
p_s2() { grep -qF -- "$S2_LINE" "$1"; }
{ printf 'decoy step\n'; printf '%s\n' "$S2_LINE"; } > "$WORK/s2-has.md"
grep -vF -- "$S2_LINE" "$WORK/s2-has.md" > "$WORK/s2-not.md"
if cmp -s "$WORK/s2-has.md" "$WORK/s2-not.md" || ! p_s2 "$WORK/s2-has.md" || p_s2 "$WORK/s2-not.md"; then
  bad "S2: FIXTURE BROKEN -- the gate-2 route predicate does not tell a step carrying the line from one without it"
elif p_s2 "$STEP"; then ok "S2: implementation.md names the gate-2 route line: $S2_LINE"
else bad "S2: implementation.md does not name the gate-2 route line '$S2_LINE' (a gate-2 re-validation is never routed)"; fi

# S3: the step text narrows a mixed re-review through --narrow and partitions with --narrow-from, on
# their invocation lines (exact strings), proved on a copy with them removed first.
S3_A='On `FULL:` the program asks `--narrow` of the same file.'
S3_B='shard lines are the `--narrow-from` map'
p_s3() { grep -qF -- "$S3_A" "$1" && grep -qF -- "$S3_B" "$1"; }
{ printf 'decoy step\n'; printf '%s\n' "$S3_A" "$S3_B"; } > "$WORK/s3-has.md"
grep -vF -- "$S3_B" "$WORK/s3-has.md" > "$WORK/s3-not.md"
if cmp -s "$WORK/s3-has.md" "$WORK/s3-not.md" || ! p_s3 "$WORK/s3-has.md" || p_s3 "$WORK/s3-not.md"; then
  bad "S3: FIXTURE BROKEN -- the narrowing predicate does not tell a step carrying both lines from one without"
elif p_s3 "$STEP"; then ok "S3: implementation.md names the --narrow invocation and the --narrow-from partition"
else bad "S3: implementation.md does not name '$S3_A' and '$S3_B' (a mixed re-review is never narrowed)"; fi

# The arms run over a copy of the subjects' directory, holding every sibling they resolve beside themselves.
CP="$WORK/cp"; mkdir -p "$CP" || exit 2
for f in partition-review-diff.sh merge-review-shards.sh validate-carried-findings.sh artifact-path-config.sh record-only-diff.sh partition-document.sh content-seal.sh; do
  cp "$SD/$f" "$CP/$f" || { echo "FIXTURE BROKEN: could not copy $SD/$f" >&2; exit 2; }
done
for a in $ARMS; do
  if "arm_$a" "$CP"; then ok "$a"
  else bad "$a: rc=${RC:-?} out=$(head -2 <<<"${OUT:-}" | tr '\n' ' ')"; fi
done

report_end review-reroute
