# check-25-steering-conduct

Self-test for **gate-validation.md Check 25 — Rule 29 bounded-join conduct**.

## What it pins

Check 25 asks a different question from the validator it calls. The validator asks
*"were there any violations?"*; the gate asks *"how many, versus the last gate?"* —
because a starvation window is conduct already committed and cannot be repaired, so
a raw count would make the gate unpassable, and an unpassable gate gets turned off.

That means the **integer** is the mechanism, not the exit status. This fixture
asserts the integer.

| case | seeded shape | expected `--count` |
|---|---|---|
| `starves` | `until [ -s <deliverable> ]; do sleep 15; done`, foreground, 600s | **1** |
| `clean` | one bounded beat through `wait-for-deliverable.sh`, 110s | **0** |
| `backgrounded` | a 30-min call with `run_in_background: true` | **0** |

`backgrounded` is the decoy that decides shippability. A long call is starvation
only if it is **foreground** — a backgrounded one yields a tool boundary
immediately, so the operator stays reachable. An implementation that flagged it
would punish the exact dispatch shape Rule 29 *prescribes*.

The `starves` command is not invented. It is the shape the reference consumer
hand-rolled eight times during S290's planning phase, where
`validate-steering-budget.sh` measured **11 starvation violations, worst 10.0 min**
— while running at no gate at all.

## Run

    bash core/fixtures/check-25-steering-conduct/run.sh

Exit 0 iff all three counts match and the `--count` contract holds (bare integer on
stdout, exit 0 even when violations exist — Check 25 reads it directly, and a
`cmd | grep` would take grep's exit status).
