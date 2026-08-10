---
paths:
  - "docs/plans/**"
---

<!-- no-stub: loads under the same `paths:` as plan-shape.md, which carries the
     instruction this file supplies evidence for. Two pointers to one trigger would be
     the drifting second copy the stub rule forbids. -->

# Plan shape — the measurements behind the done-when clause

Companion to [[plan-shape]], under the same `paths:`, so the rule and the evidence for it
load together. Split by role, not by length: the instruction is there, the measurement is
here.

## The done-when rule's two measured failures

This repo's rule for a new check — prove it can fire — applies to acceptance criteria, and
the plan that closed this program broke it twice in one file. *"`validate-artifact-budget.sh`
green"* was unattainable when written: the only FAIL is an unrelated artifact at 309%,
byte-identical before and after the work. *"confirm each still resolves"* was unverifiable:
no file in that corpus produces a genuine anchored resolution, so the executor could not
satisfy it literally at all. **Both read like ordinary criteria and neither could ever have
gone green.** An executor then either invents a substitute — which is what happened,
correctly, both times — or reports failure for work that succeeded. Run the command, or
state the expected FAIL and what makes it unrelated.

## Reachable AT THE MOMENT IT IS CHECKED, which is not the same thing

Measured on the 0.341.0 → 0.345.0 runbook, whose done-when 5 asked that `ledger-reverify`
report a receipt as `CLOSE-CANDIDATE`. Reachability was checked before the file shipped and
the derivation was right — but the run's own later step CLOSES and ROTATES that entry, and a
rotated entry emits no row, so the live ledger correctly reads **0** by the time the criterion
is read. The executor materialized the pre-close ledger from its own commit and answered
there, which is correct and is work the file should not have cost them. **When a run consumes
its own subject, state the observation point** — before which step, against which ref. This is
the third criterion in this repo's runbooks that an executor had to reinterpret rather than
satisfy literally.

The opt-out rule's own measurement stays in `CLAUDE.md` beside the rule, for the reason
given in [[plan-shape]].
