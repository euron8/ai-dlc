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
- with the drift reverted, print says `0 HARD blockers` and `--check` passes any report;
- a **stale base** is read out rather than swallowed. `unregistered-drift.sh` emits
  `CORE-AT-THEIRS` for a consumer file already byte-identical to `theirs`, and SKILL.md step 7
  calls that the tell the base is stale — every status that detector emits means "consumer edits
  vs base", so against a base that already IS theirs the list is *silent* about in-place core
  edits rather than clean on them. The row carries no `HARD-` prefix, so this wrapper's only
  reader discarded it and the run rendered as the affirmative empty line. It is now rendered
  **beside** `0 HARD blockers.`, not instead of it (a suppressing read-out would break the
  positive control at `run.sh:192`), and `--check` **warns without failing** on the same world —
  the set is smaller than it should be but honestly computed, so reddening it would wedge an
  accurate report.

The stale-base arms carry three mutants, each keyed on a render **site** rather than on the
status spelling: deleting the print site, deleting the check-mode warn site (which changes no
exit code, so the warning is its only observable), and widening the rows-supplied gate that keeps
the row out of `emit-report.sh`'s region — where a duplicate would double the count `--verify`'s
`unseen_rows()` reads.

## Run

    bash run.sh

Exit 0 = every assertion holds. Ships to consumers (it tests a shipped reconcile script); `run.sh`
resolves both the distribution and consumer layouts.
