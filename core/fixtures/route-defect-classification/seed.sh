#!/usr/bin/env bash
# Seed the route-defect-classification fixture (gate-validation.md Check 27).
#
# THIS FIXTURE WRITES FILES. Check 27 is adjudication:llm — the gate-adjudicator
# re-reads `user_request_verbatim` from the pipeline snapshot and judges the
# routing decision, so a seed cannot assert the verdict the way a mechanical
# fixture's run.sh can. But it CAN hand the adjudicator a real snapshot to scan
# instead of a paragraph describing one, and run.sh mechanically proves each
# seeded snapshot is well-formed and the four cases are distinct — an adversarial
# seed the adjudicator reads as prose is not adversarial (the H2 vacuity lesson).
#
# Scenario (graph S292): an /ai-dlc prompt named two production defects — a
# "fee-display failure" and a "wide-mode misreport" — neither carrying the token
# "bug", on top of a carried backlog item. The router matched only the carry-over
# signal, folded the defects into a carry-over story as sub-questions, and never
# asked the Rule 11 mixed-signal question. Check 27, at the first planning gate,
# re-reads the verbatim request and must FAIL that misroute.
#
# Four seeded snapshots and their expected adjudicator verdicts:
#   clean-carryover      variant=carry-over, no defect language           → PASS (vacuous — scope-clean)
#   misroute             variant=carry-over, defect+carry-over, no ask    → FAIL (the S292 bug)
#   remedied-reroute     same verbatim, variant=bug                       → PASS (mutant: re-routed)
#   remedied-clarified   variant=carry-over, clarification_asked=yes      → PASS (mutant: asked)
#
# Usage: seed.sh [OUT_DIR]   (prints the seeded directory path on stdout)

set -euo pipefail

OUT="${1:-${OUT:-$(mktemp -d)}}"
mkdir -p "$OUT"

DEFECT_VERBATIM='Run the S292 carry-over sprint. Also, the Rebalancer page shows a fee-display failure and a wide-mode misreport that started after the last deployment — fold them in as needed.'
CLEAN_VERBATIM='Run the S292 carry-over sprint: pick up the next backlog item and plan the stories.'

write_snapshot() { # $1 file  $2 variant  $3 verbatim  $4 bug_sig  $5 co_sig  $6 clarified
  cat > "$OUT/$1" <<EOF
<!-- SEEDED pipeline-snapshot — route-defect-classification fixture, case: $1.
     Check 27 (first planning gate) escalates to the gate-adjudicator, which reads
     user_request_verbatim below on its own substance and re-derives the signals
     rather than trusting the recorded booleans. -->

# Pipeline Snapshot

## Pipeline Position

- variant: $2
- current_step_file: carry-over-evaluation.md
- last_completed_step_file: carry-over-evaluation.md
- last_gate_passed: none
- current_branch: ai-dlc/carry-over/s292-fix
- user_request_verbatim: $3
- bug_signal_present: $4
- carryover_or_sprint_signal_present: $5
- clarification_asked: $6

## Sprint Context

- sprint_id: 292
- validation_intensity: full
EOF
}

# case               variant      verbatim             bug  co   clarified
write_snapshot clean-carryover.snapshot.md    carry-over "$CLEAN_VERBATIM"  no  yes  n-a
write_snapshot misroute.snapshot.md           carry-over "$DEFECT_VERBATIM" no  yes  no
write_snapshot remedied-reroute.snapshot.md   bug        "$DEFECT_VERBATIM" yes yes  n-a
write_snapshot remedied-clarified.snapshot.md carry-over "$DEFECT_VERBATIM" yes yes  yes

echo "$OUT"
