# Fixture: reconcile-blocking-list

Self-test for `reconcile/hard-blockers.sh` — the generator + verifier that makes the reconcile
report's blocking list a **rendered artifact**, not LLM prose.

## The bypass scenario

The dry-run report is authored by the update skill's LLM from the detectors' output. Nothing forced
every `HARD-*` line to appear in it — and on a real pull one didn't: `unregistered-drift.sh` flagged
an in-place edit to a core schema (`provenance-block.json`) `HARD`, **twice**, and both reports said
"no unregistered core drift." A blocker dropped from the report is one the operator approves `apply`
without ever seeing, and `apply` then overwrites the consumer's edit silently. The detector was
fixed (v0.63.2); the *report* un-reported it.

`hard-blockers.sh` wraps both `HARD-*` detectors (`unregistered-drift.sh` + `layer-drift.sh`):
- **print mode** renders the canonical blocking list (paste verbatim into the report);
- **`--check <report>`** fails if the report is missing any `HARD-*` item the detectors emit.

## What it proves

- print mode renders a real in-place-drift blocker;
- `--check` **FAILS** a report that omits the blocker (reproduces the bug);
- `--check` **PASSES** a report that names it;
- with the drift reverted, print says `0 HARD blockers` and `--check` passes any report.

## Run

    bash run.sh

Exit 0 = every assertion holds. Ships to consumers (it tests a shipped reconcile script); `run.sh`
resolves both the distribution and consumer layouts.
