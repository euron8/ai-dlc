#!/usr/bin/env bash
#
# Prove the route-defect-classification seed is well-formed and adversarial.
#
# Check 27 is adjudication:llm — the verdict is the gate-adjudicator's, not a
# script's, so this run.sh CANNOT assert PASS/FAIL the way a mechanical fixture
# does. What it CAN do, and must, is prove the seed actually wrote four distinct,
# valid snapshots carrying the fields the adjudicator scans — the guard against a
# fixture that silently rots into prose an adjudicator reads and waves through
# (the H2 vacuity failure: seeds that were echo statements describing files never
# written). Every assertion here is on the seeded bytes, not on the routing verdict.
#
# The expected adjudicator verdicts (documented, not asserted here) are the
# three-step proof for Check 27:
#   1. clean-carryover     → PASS   (no defect signal: the check passes vacuously)
#   2. misroute            → FAIL   (defect + carry-over, variant≠bug, not asked: the S292 bug)
#   3a. remedied-reroute   → PASS   (mutant: variant=bug — the defect was triaged)
#   3b. remedied-clarified → PASS   (mutant: clarification_asked=yes — the operator was asked)
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

ROOT="$(bash "$DIR/seed.sh" | tail -1)"
trap 'rm -rf "$ROOT"' EXIT

FAILURES=0

field() { # $1 file  $2 field-name  -> prints value
  sed -n "s/^- $2: //p" "$ROOT/$1" | head -1
}

expect_field() { # $1 file  $2 field  $3 expected  $4 why
  local got; got="$(field "$1" "$2")"
  if [ "$got" != "$3" ]; then
    echo "FAIL [$1]: $2='$got', expected '$3' — $4"
    FAILURES=$((FAILURES + 1))
  else
    echo "ok   [$1]: $2=$3  ($4)"
  fi
}

expect_verbatim_has() { # $1 file  $2 needle  $3 present(1)/absent(0)  $4 why
  if grep -qi "$2" "$ROOT/$1"; then have=1; else have=0; fi
  if [ "$have" != "$3" ]; then
    echo "FAIL [$1]: '$2' present=$have, expected $3 — $4"
    FAILURES=$((FAILURES + 1))
  else
    echo "ok   [$1]: '$2' present=$have  ($4)"
  fi
}

for f in clean-carryover misroute remedied-reroute remedied-clarified; do
  [ -f "$ROOT/$f.snapshot.md" ] || { echo "FAIL: seed did not write $f.snapshot.md"; FAILURES=$((FAILURES + 1)); }
done

# The failing case: a real defect subordinated into carry-over with no question asked.
expect_field       misroute.snapshot.md variant            carry-over "misroute stays on the non-bug path"
expect_field       misroute.snapshot.md clarification_asked no         "the mandatory mixed-signal question was skipped"
expect_verbatim_has misroute.snapshot.md "fee-display failure" 1       "the verbatim carries a defect the router did not tokenize as 'bug'"
expect_verbatim_has misroute.snapshot.md "wide-mode misreport" 1       "the second production defect is present verbatim"
expect_verbatim_has misroute.snapshot.md "\\bbug\\b"          0        "neither defect uses the literal token 'bug' — keyword matching misses both"

# The vacuous-pass control: same route, no defect language.
expect_field       clean-carryover.snapshot.md variant carry-over "control is a genuine carry-over"
expect_verbatim_has clean-carryover.snapshot.md "failure"   0      "no defect signal, so Check 27 passes vacuously"
expect_verbatim_has clean-carryover.snapshot.md "misreport" 0      "no defect signal in the control"

# The two remedies (mutants) — each flips exactly one field the invariant reads.
expect_field remedied-reroute.snapshot.md   variant            bug  "mutant: the defect was re-routed to the bug pipeline"
expect_field remedied-clarified.snapshot.md variant            carry-over "mutant keeps the route..."
expect_field remedied-clarified.snapshot.md clarification_asked yes "...but records that the operator was asked"

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "PASS: seed well-formed — one FAIL case, one vacuous-PASS control, two single-field PASS mutants."
  exit 0
else
  echo "FAIL: $FAILURES seed assertion(s) failed — the fixture is not adversarial as written."
  exit 1
fi
