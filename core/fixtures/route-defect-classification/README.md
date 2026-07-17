# Route Defect-Classification Fixture (Check 27)

Self-test for **Check 27 — routing sanity: a subordinated defect**, the
first-planning-gate check that catches a production defect misrouted into a
non-`bug` pipeline without the Rule 11 mixed-signal clarifying question.

## The bypass it catches (graph S292)

An `/ai-dlc` prompt named two production defects — a *"fee-display failure"* and
a *"wide-mode misreport"* — neither carrying the literal token `bug`, on top of a
carried backlog item. `route.md` Step 2 matched only the carry-over signal, the
defects were folded into a carry-over story as sub-questions, and the mandatory
mixed-signal question (`route.md` Step 4) never fired. The full planning cycle ran
on an unverified hypothesis; the `bug` path (repro-first, Falsification ladder)
was skipped.

Check 27 is `adjudication: llm`: at the first planning gate it is escalated to a
fresh `gate-adjudicator`, which re-reads `user_request_verbatim` from the pipeline
snapshot **on its own substance** and re-derives the signals — it does not trust
the router's recorded `bug_signal_present`. Reading the raw request is what closes
the self-declaration hole: the router that misclassified also wrote the booleans,
so a check that only read them back would pass vacuously on the exact failure.

## Seeded cases and expected adjudicator verdicts

`seed.sh` writes four real snapshots. The verdict is the adjudicator's (llm), so
`run.sh` asserts the seed is well-formed and adversarial, not the verdict itself.

| Snapshot | variant | verbatim | clarification_asked | Expected verdict |
|----------|---------|----------|---------------------|------------------|
| `clean-carryover`     | carry-over | no defect language | n-a | **PASS** (vacuous — no defect signal) |
| `misroute`            | carry-over | two defects, no `bug` token | no | **FAIL** (the S292 bug) |
| `remedied-reroute`    | bug        | same two defects   | n-a | **PASS** (defect triaged on the bug path) |
| `remedied-clarified`  | carry-over | same two defects   | yes | **PASS** (operator was asked) |

This is the three-step proof: (1) vacuous PASS when scope is clean, (2) FAIL on
the real bug, (3) PASS after either remedy. `remedied-reroute` and
`remedied-clarified` are the mutants — each flips exactly one field the invariant
reads (`variant`, then `clarification_asked`), and each must turn the FAIL back
into a PASS.

## Run

    bash seed.sh [OUT_DIR]   # writes the four snapshots, prints the directory
    bash run.sh              # proves the seed is well-formed and distinct

`run.sh` exits 0 when the seed carries one FAIL case, one vacuous-PASS control,
and two single-field-mutant PASS cases; nonzero if the fixture has rotted into a
non-adversarial state.
