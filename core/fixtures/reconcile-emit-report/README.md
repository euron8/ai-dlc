# Fixture: reconcile-emit-report

Self-test for `reconcile/emit-report.sh` — the driver that makes the reconcile report's mechanical
sections a **rendered artifact**, and `--verify` that a report carries them intact.

## The problem it closes

The reconcile dry-run report was authored by the update skill's LLM from the detectors' output.
Every mechanical finding was optional-by-omission: a step the narrator forgot was silently skipped,
and a `HARD-*` blocker dropped from the report is one the operator approves `apply` without seeing.
It happened — an in-place core-schema drift was flagged HARD by the detector and left out of two
real reports. Fixing the detector didn't fix this, because an LLM stood between the detector and the
operator and dropped the line.

`emit-report.sh` runs every mechanical detector (`preclassify`, `unregistered-drift`, `layer-drift`,
`hard-blockers`, `relabel`) and renders them into one `BEGIN/END GENERATED: reconcile-mechanical`
region. The skill pastes it verbatim and writes only the semantic sections around it. `--verify`
re-renders and byte-compares the report's region — so a report whose region is **missing**, **stale**,
or **hand-edited to drop a finding** fails. The operator can run `--verify` themselves.

## What it proves

- the driver renders a mechanical region carrying a real HARD blocker;
- `--verify` **PASSES** a report whose region matches the driver;
- `--verify` **FAILS** a report with no region (the narrated-report bug);
- `--verify` **FAILS** a region hand-edited to drop the blocker (an edited render can't hide a finding).

## Run

    bash run.sh

Exit 0 = every assertion holds. Ships to consumers; `run.sh` resolves both distribution and consumer
layouts.
