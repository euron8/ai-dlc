#!/usr/bin/env bash
# Exercise the gate-side repair-record arm against a DIFFERENTIAL pair.
#
# Exit 0 iff the validator's verdict on every seeded case is correct AND the
# differential still holds.
#
# WHAT MAKES THIS A DIFFERENTIAL AND NOT THREE SEPARATE CASES. `gate-repaired-delegated`
# and `gate-repaired-inline-no-record` carry BYTE-IDENTICAL verdict series. Same
# gate_series_id, same nonces, same check_ids, same PASS/FAIL, same evidence strings,
# same bytes. They differ in exactly one thing: whether a repair record exists on disk
# under planning-artifacts/. So any implementation that reaches its verdict by reading
# the SERIES — the FAIL counts, the fall between passes, the pass ordering, the stall
# rung — returns the same answer for both and this fixture goes red. Only an
# implementation that reads the RECORD can separate them.
#
# That property is asserted here, first, before anything else runs. A differential whose
# two arms have quietly acquired a second difference proves nothing about the first one,
# and it would keep reporting green while doing it.
#
# WHAT THE ARM PROVES AND WHAT IT DOES NOT — carried verbatim in posture from arm H's
# own limit (validate-adversarial-convergence.sh, "WHAT THIS PROVES, AND WHAT IT DOES
# NOT"). It proves a STRUCTURED repair record EXISTS for every pass whose FAILs a later
# pass shows were repaired. It does NOT prove a `remediator` subagent rather than the
# lead authored it: a subagent's context leaves no transcript on disk. Existence plus
# structure is the honest floor, and what it separates is "repaired inline, no record"
# from "delegated" — which is exactly the 104-inline-edit defect this release exists
# for. Authorship attribution is a separate, later mechanism, and this fixture must not
# be read as evidence of it.
#
# THE THIRD CASE IS THE OTHER BOUNDARY. `gate-repaired-record-off-label` carries the
# record but renames a field (`edit sites:` for `edit:`). Without it, a maintainer can
# make the inline case pass by widening the field reader until it matches any prose —
# and an arm that matches prose cannot fire, which reads exactly like one that passed.
# The pair "no record" / "renamed field" is what pins the reader between the two ways it
# can go wrong.
set -uo pipefail
# Scrub ambient AI_DLC_* — the validator reads AI_DLC_STATE_DIR, and a consumer that
# tunes it in settings.json would otherwise fail this fixture against correct code.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=/dev/null
. "$DIR/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
# shellcheck source=/dev/null
. "$DIR/../lib/mutant.sh" || { echo "FIXTURE BROKEN: cannot source lib/mutant.sh" >&2; exit 2; }
# shellcheck source=/dev/null
. "$DIR/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }
# shellcheck source=/dev/null
. "$DIR/../lib/inproc.sh" || { echo "FIXTURE BROKEN: cannot source lib/inproc.sh" >&2; exit 2; }

VALIDATOR=""
for cand in \
  "$DIR/../../scripts/validate-gate-adjudication.sh" \
  "$DIR/../../../scripts/ai-dlc/validate-gate-adjudication.sh" \
  "$DIR/../../core/scripts/validate-gate-adjudication.sh"; do
  [ -f "$cand" ] && VALIDATOR="$cand" && break
done
if [ -z "$VALIDATOR" ]; then
  echo "FIXTURE BROKEN: cannot locate validate-gate-adjudication.sh from $DIR"
  exit 1
fi

# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. A present validator with neither the `vga_main() {` line nor the column-0
# source guard predates the in-process wrap, and sourcing it would run its whole body: SKIP and exit 0 (FIXTURE BROKEN
# in the distribution), never an ok. Exactly one half is a respelled subject this fixture cannot drive, which FAILS.
# An unreadable subject is FIXTURE ERROR.
_gd=0; _gg=0
grep -qxF 'vga_main() {' "$VALIDATOR"; _x=$?
[ "$_x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $VALIDATOR (grep exit $_x)" >&2; exit 2; }
[ "$_x" -ne 0 ] || _gd=1
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$VALIDATOR"; _x=$?
[ "$_x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $VALIDATOR (grep exit $_x)" >&2; exit 2; }
[ "$_x" -ne 0 ] || _gg=1
case "$_gd$_gg" in
  11) : ;;
  00) echo "SKIP: gate-repair-record: $VALIDATOR predates the in-process wrap"; fx_skip_exit "$DIR" ;;
  *) bad "$VALIDATOR carries one half of the in-process wrap (vga_main line, column-0 source guard: $_gd$_gg) -- a respelled subject this fixture cannot drive"
     report_end gate-repair-record ;;
esac

echo "HERMETIC-CONSUMED $(cd "$(dirname "$VALIDATOR")" && pwd)/$(basename "$VALIDATOR")"
[ -f "$(dirname "$VALIDATOR")/gate_adjudication.py" ] && echo "HERMETIC-CONSUMED $(cd "$(dirname "$VALIDATOR")" && pwd)/gate_adjudication.py"

ROOT="$(bash "$DIR/seed.sh" | tail -1)"
if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then
  echo "FIXTURE BROKEN: seed.sh produced no root"
  exit 1
fi
EQ="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp" >&2; exit 2; }
trap 'rm -rf "$ROOT" "$EQ"' EXIT

# IN PROCESS (BL-878). Every verdict below is vga_main's, asked through vga, which hands the validator to lib/inproc.sh's
# inproc_run (the operand is a literal tail so arm P2 resolves it); the programs run only in the two cli cells of
# cells.decl, each compared byte for byte with the in-process answer on the same input.
inproc_load "$VALIDATOR" || { echo "FIXTURE ERROR: cannot load $VALIDATOR" >&2; exit 2; }
vga() { inproc_run "${VALIDATOR%/*}/validate-gate-adjudication.sh" vga_main "$@"; }

_f0=0
settle() { [ "$fails" -eq "$_f0" ] && ok "$1"; return 0; }
note_fail() { bad "$*"; }


# --------------------------------------------------------------------------
# 0. THE DIFFERENTIAL ITSELF. Everything below is worthless if this does not hold.
# --------------------------------------------------------------------------
CASES="gate-repaired-delegated gate-repaired-inline-no-record gate-repaired-record-off-label
gate-repaired-adversarial-record-only gate-repaired-record-beside-verdicts
gate-repaired-lead-resolution gate-repaired-adversarial-resolution-only
gate-repaired-resolution-off-label"
A="$ROOT/gate-repaired-delegated/_bmad-output/gate-adjudication"
B="$ROOT/gate-repaired-inline-no-record/_bmad-output/gate-adjudication"

_f0=$fails
n_a="$(find "$A" -name '*.verdict.json' | wc -l | tr -d ' ')"
if [ "$n_a" -lt 3 ]; then
  note_fail "the seeded series has $n_a verdict(s); the differential needs at least three
  passes for two repairs to be provable. The seed is not building what this asserts on."
else
  # EVERY case, not just the first pair. Each new case is another arm of the same
  # differential, and one that quietly carried a different series would pass its own
  # assertion for a reason that has nothing to do with the record on disk.
  for f in "$A"/*.verdict.json; do
    b="$(basename "$f")"
    for case_dir in $CASES; do
      other="$ROOT/$case_dir/_bmad-output/gate-adjudication"
      [ "$other" = "$A" ] && continue
      if ! cmp -s "$f" "$other/$b"; then
        note_fail "the verdict series are NOT byte-identical across cases: $b differs
  between gate-repaired-delegated and $case_dir.
  This fixture's entire claim is that the cases differ ONLY in what repair record exists on
  disk. With a second difference present, a validator could separate them by reading the
  series — which is the implementation this fixture exists to reject — and every assertion
  below would pass for the wrong reason."
      fi
    done
  done
fi
settle "every case carries a byte-identical verdict series to gate-repaired-delegated (three or more passes)"

# And the difference that IS intended must actually be there, or the cases are the same
# case twice and all three would agree no matter what the validator does.
_f0=$fails
recs_a="$(find "$ROOT/gate-repaired-delegated/_bmad-output/planning-artifacts" \
          -name 'gate-*-repair-p*.md' 2>/dev/null | wc -l | tr -d ' ')"
recs_b="$(find "$ROOT/gate-repaired-inline-no-record/_bmad-output/planning-artifacts" \
          -name 'gate-*-repair-p*.md' 2>/dev/null | wc -l | tr -d ' ')"
if [ "$recs_a" -ne 2 ] || [ "$recs_b" -ne 0 ]; then
  note_fail "the seeded repair records are delegated=$recs_a, inline=$recs_b; expected 2
  and 0. The independent variable is not set, so the cases are one case twice."
fi
settle "the independent variable is set: delegated carries 2 repair records, inline carries 0"

# --------------------------------------------------------------------------
# 1. THE ARM. Assert on the MESSAGE, never on the exit code alone.
#
# A validator with NO repair-record arm exits 0 on all three cases; a validator whose
# stall rung fires would exit 1 on all three. Both are wrong, and an exit-code-only
# fixture scores the first as a pass on the delegated case and the second as a pass on
# the other two. This repo's own defect class, reproduced inside the test written to
# catch it. So each case names the message it must carry.
# --------------------------------------------------------------------------
# $1 case-dir  $2 expected exit  $3 message regex ('' = must carry no repair-record
#                                                  finding)  $4 why
expect() { _f0=$fails; _expect "$@"; settle "$1 exits $2 on the finding the case names"; }
_expect() {
  local case_dir="$1" want="$2" want_re="$3" why="$4" got out
  vga --series "$ROOT/$case_dir/_bmad-output/gate-adjudication" >"$EQ/$case_dir.out" 2>"$EQ/$case_dir.err"
  got=$?
  out="$(cat "$EQ/$case_dir.out" "$EQ/$case_dir.err")"
  if [ "$got" -ne "$want" ]; then
    note_fail "$case_dir exited $got, expected $want.
  $why
  validator said: $out"
    return
  fi
  # Match with a HERE-STRING. Never pipe the captured output into a first-match reader:
  # under pipefail a pipeline reports the WRITER's status, so once the validator's output
  # grows past the pipe buffer the test answers "not found" on input that contains the
  # pattern, and every assertion below silently inverts. I54 in
  # scripts/validate-enforcement-map.sh fires on that shape and it fired on the first
  # draft of this file.
  if [ -n "$want_re" ]; then
    if ! grep -qiE "$want_re" <<<"$out"; then
      note_fail "$case_dir exited $want as expected, but for the wrong reason: its output
  carries no finding matching /$want_re/.
  $why
  validator said: $out"
    fi
  else
    if grep -qiE 'repair record|repair-record' <<<"$out"; then
      note_fail "$case_dir raised a repair-record finding against a series that HAS a
  structured record for every repaired pass.
  $why
  validator said: $out"
    fi
  fi
}

expect gate-repaired-delegated 0 '' \
"Two passes had their FAILs repaired (2 FAIL -> 1 -> 0) and a structured repair record
  exists for each. Nothing is owed. If this case is red, the arm is demanding a record
  where one is present — most likely reading the wrong path (the record sits under
  planning-artifacts/s<N>/gate-<type>-repair-p<M>.md, NOT beside the verdicts) or the
  wrong pass number."

expect gate-repaired-inline-no-record 1 'repair record|repair-record' \
"THIS IS THE CASE THE RELEASE EXISTS FOR. Byte-identical series to the delegated case,
  and no repair record for either repaired pass — the lead repaired the artifact with its
  own Edit tool and wrote nothing. If this case exits 0, the arm is reading the SERIES
  (FAIL counts, the fall, the ordering), and the series cannot distinguish an inline
  repair from a delegated one. That is the s302 defect: 11 passes, 104 lead Edit calls,
  zero remediator dispatches, and a verdict corpus that looked exactly like a healthy
  delegated cycle."

expect gate-repaired-adversarial-record-only 1 'repair record|repair-record' \
"A WELL-FORMED record sits in the right sprint directory with the matching pass number, and
  it is the ADVERSARIAL caller's record (\`s<N>-<artifact>-repair-p<M>.md\`), not the gate's
  (\`gate-<type>-repair-p<M>.md\`). The two are siblings in one directory and only the prefix
  separates them. If this case exits 0 the record glob has been loosened to \`*-repair-p<M>\`
  and the arm now adopts an adversarial record as proof of a gate repair — which reopens the
  inline-repair hole inside the check that exists to close it. Measured on the reference
  consumer: 74 adversarial records, 50 with a matching pass number, ZERO gate records; the
  prefixed glob reports 18 missing there and the loose one reports 0."

expect gate-repaired-record-beside-verdicts 1 'repair record|repair-record' \
"The record is correctly named and correctly structured, and it is in the OLD location —
  beside the verdicts under \`gate-adjudication/\` rather than under
  \`planning-artifacts/s<N>/\` where \`_gate-procedures.md\` prescribes it. The first cut of
  this arm derived the record directory as dirname(verdict) and demanded it exactly here,
  which fired on every correctly delegated repair. That derivation is inherited from arm H,
  where it is CORRECT because adversarial passes and their records co-locate; the gate is the
  one caller where it stops being true. If this case exits 0 the arm has drifted back to
  reading the verdict's own directory."

expect gate-repaired-lead-resolution 0 '' \
"Both repaired passes carry a structured record named \`gate-<type>-resolution-p<M>.md\` and
  no \`-repair-p<M>.md\` exists. Not every FAIL closes by a remediator repair: a check whose
  input is a file the remediation guard leaves LEAD-editable
  (ai-dlc-gate-remediation-guard.sh:1110-1111 — \`docs/escalations/**\`, \`*-resolution-p*.md\`)
  closes by a lead-authored resolution, and no dispatch is warranted or possible for it. If
  this case exits 1 the arm accepts only the remediator's filename, which leaves the lead
  choosing between fabricating a dispatch it did not make and taking a MISSING finding for
  work correctly done. This is the ONLY case the second suffix decides."

expect gate-repaired-adversarial-resolution-only 1 'repair record|repair-record' \
"The record is structured, in the right sprint directory, with the matching pass number, and
  it is the ADVERSARIAL cycle's resolution record (\`<artifact>-resolution-p<M>.md\`,
  _gate-procedures.md:324) rather than the gate's (\`gate-<type>-resolution-p<M>.md\`). This
  is case (d) one suffix over and it is what keeps the \`gate-\` anchor load-bearing on the
  new name. If this case exits 0 the second suffix has been widened to \`*-resolution-p<M>\`
  and the arm now adopts an adversarial resolution as proof of a gate repair — the same hole
  the prefixed \`gate-*-repair\` glob was narrowed to close, reopened one suffix over.
  Measured on the reference consumer, depth 2 under planning-artifacts: 17 files match
  \`*-resolution-p<M>.md\`, 16 adversarial and ONE a gate record."

expect gate-repaired-resolution-off-label 1 'UNSTRUCTURED REPAIR RECORD' \
"The resolution record exists for both repaired passes and renames a field ('edit sites:'
  for 'edit:'). The accepted NAME widened; the STANDARD did not. If this case exits 0 the
  structure check has been skipped for the resolution suffix, and the second name becomes a
  way to close any FAIL by filing a differently-named file — which is worse than the gap it
  was added to close, because it looks like a repair record and is not one."

expect gate-repaired-record-off-label 1 'UNSTRUCTURED REPAIR RECORD' \
"The record EXISTS for both repaired passes but renames a field ('edit sites:' for
  'edit:'). The labels are read literally, and this is the boundary at the far end: an
  arm widened until it accepts a renamed field is an arm widened until it accepts prose,
  and one that accepts prose can never fire. If this case exits 0, check whether the
  field reader has been loosened rather than whether the record is really structured.
  The assertion names the UNSTRUCTURED class and not its field labels because the MISSING
  message also spells 'disposition:', 'edit:' and 'derivation:' — it has to, it tells the
  lead what to write — so a field-name regex here is satisfied by the finding that says
  the record is ABSENT, which is the opposite verdict. An arm cannot be keyed on a token
  its sibling finding also carries."

# --------------------------------------------------------------------------
# 1b. A CHECK 22 FAIL CLEARED BY REMEDIATION OWES A RESOLUTION RECORD (contract B2).
#
# The remediable Check 22 classes clear with no escalation entry and no operator line: a
# re-dispatch names each violating row on `remediates:`, and validate-spawn-ledger.sh exits 0.
# The gate series still shows 22 FAIL -> PASS, so the repair-record arm owes a record for pass
# 1, and the lead writes `gate-implementation-resolution-p1.md` naming each R, its target and
# the validator's COUNTS line. The pair carries byte-identical series (asserted first) and
# differs only in that record, so an arm that cleared the series without reading the record
# would pass both, and one that refused a resolution record for Check 22 would fail both.
# --------------------------------------------------------------------------
C22A="$ROOT/gate-c22-remediated-resolution/_bmad-output/gate-adjudication"
C22B="$ROOT/gate-c22-remediated-no-record/_bmad-output/gate-adjudication"
_f0=$fails
n_c22="$(find "$C22A" -name '*.verdict.json' | wc -l | tr -d ' ')"
if [ "$n_c22" -ne 2 ]; then
  note_fail "the Check 22 pair seeded $n_c22 verdict(s); it needs exactly two passes (FAIL then PASS)."
else
  for f in "$C22A"/*.verdict.json; do
    cmp -s "$f" "$C22B/$(basename "$f")" || note_fail "the Check 22 pair's series differ at
  $(basename "$f"); the pair must differ ONLY in the resolution record."
  done
fi
settle "the Check 22 pair carries a byte-identical two-pass series"
_f0=$fails
recs_c22a="$(find "$ROOT/gate-c22-remediated-resolution/_bmad-output/planning-artifacts" -name 'gate-implementation-resolution-p1.md' | wc -l | tr -d ' ')"
recs_c22b="$(find "$ROOT/gate-c22-remediated-no-record/_bmad-output/planning-artifacts" -name 'gate-*-p*.md' | wc -l | tr -d ' ')"
[ "$recs_c22a" -eq 1 ] && [ "$recs_c22b" -eq 0 ] || note_fail "the Check 22 pair's records are
  with=$recs_c22a, without=$recs_c22b; expected 1 and 0."
settle "the Check 22 pair differs only in the resolution record (1 and 0)"

expect gate-c22-remediated-resolution 0 '' \
"Check 22 FAILed at pass 1 on remediable rows only and PASSed at pass 2, and the lead's
  gate-implementation-resolution-p1.md names each remediating re-dispatch, its remediates:
  target and the validator's COUNTS line in the three structured fields. Nothing is owed. If
  this exits 1, the operator-free clear has no record the series arm accepts, and the lead is
  pushed back onto an escalation entry the operator ruled unnecessary."

expect gate-c22-remediated-no-record 1 'MISSING REPAIR RECORD' \
"The same series with NO resolution record. A Check 22 FAIL that cleared by remediation is
  still a repaired pass, and the record is the only place the remediating re-dispatches are
  named against the series. If this exits 0, the arm has been exempted for Check 22 and the
  operator-free clear leaves no trail at the gate."

# --------------------------------------------------------------------------
# 2. THE STALL RUNG MUST NOT BE WHAT MADE THE RED CASES RED.
#
# Check `7` holds FAIL for exactly two consecutive passes, one short of K=3. If the rung
# fired here, cases 2 and 3 would exit 1 for a reason that has nothing to do with the
# repair record, and the fixture would report green while measuring the wrong mechanism.
# --------------------------------------------------------------------------
_f0=$fails
rung_out="$(cat "$EQ/gate-repaired-inline-no-record.out" "$EQ/gate-repaired-inline-no-record.err")"
[ -s "$EQ/gate-repaired-inline-no-record.out" ] || [ -s "$EQ/gate-repaired-inline-no-record.err" ] || bad "the inline case printed nothing; the rung check below would read an empty answer"
if grep -qiE 'consecutive|stall' <<<"$rung_out"; then
  note_fail "the stall rung fired on the inline case. The seeded series holds FAIL on one
  check for two consecutive passes, one short of K=3, precisely so that this fixture's
  red cases are red because of the missing RECORD and nothing else. Either K changed or
  the seed drifted; until that is resolved, cases 2 and 3 above are passing for a reason
  this fixture does not name.
  validator said: $rung_out"
fi

settle "the stall rung did not fire on the inline case (the red cases are red on the record alone)"

# --------------------------------------------------------------------------
# 3. THE PROGRAM, once per distinct CLI outcome (cells.decl cli rows): exit 0 and the exit-1 refusal, each started as
# FXCELL=<id> bash and compared with the in-process answer already captured above: stdout, stderr and exit, byte for byte.
# --------------------------------------------------------------------------
eqv() { # eqv <cell-id> <case-dir> <want-rc>
  local id="$1" c="$2" want="$3"
  FXCELL="$id" bash "$VALIDATOR" --series "$ROOT/$c/_bmad-output/gate-adjudication" >"$EQ/$id.cl.out" 2>"$EQ/$id.cl.err"
  echo "$?" > "$EQ/$id.cl.rc"
  cmp -s "$EQ/$c.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$c.err" "$EQ/$id.cl.err" \
    && [ "$(cat "$EQ/$id.cl.rc")" = "$want" ] && [ -s "$EQ/$id.cl.out" -o -s "$EQ/$id.cl.err" ]
}
if eqv cli-series-pass gate-repaired-delegated 0; then
  ok "cli-series-pass: the program answers the delegated series with exit 0 and the same bytes as the in-process call"
else bad "cli-series-pass: the program and the in-process call differ, or the outcome is not exit 0 with output (rc $(cat "$EQ/cli-series-pass.cl.rc"))"; fi
if eqv cli-series-refuse gate-repaired-inline-no-record 1 && grep -qiE 'repair record|repair-record' "$EQ/cli-series-refuse.cl.out" "$EQ/cli-series-refuse.cl.err"; then
  ok "cli-series-refuse: the program refuses the inline series on the repair-record finding with exit 1 and the same bytes as the in-process call"
else bad "cli-series-refuse: the program and the in-process call differ, or the outcome is not exit 1 on a repair-record finding (rc $(cat "$EQ/cli-series-refuse.cl.rc"))"; fi

report_end gate-repair-record
