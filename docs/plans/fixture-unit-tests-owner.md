# Fixtures to in-process unit tests: owner brief

## RESUME HERE

You were started with `READ and FOLLOW docs/plans/fixture-unit-tests-owner.md` on branch
`exp/fixture-unit-tests`. You are the release OWNER for the three open units below. The lead is
session `ai-dlc-b3`. It holds the merge order, actions 3-8 of
`docs/plans/fixture-unit-tests-handoff.md` and the release push. Report each unit's result to
`ai-dlc-b3` by `SendMessage`, never only as session output.

Time matters here: do not spend time that can be avoided, and the earlier a correct result is obtained, the better.

## Rules

- The operator rulings in `docs/plans/fixture-unit-tests-handoff.md` `## Operator rulings that
  bind this work` bind you: no de-scoping, no timing runs, no process counts, no verdicts, and no
  load-dependent test (BL-868).
- You build through hands only (Agent tool, `isolation: "remote"`, one hand per unit, all spawned
  in one block). You make no edits yourself. Each hand clones under `mktemp -d`, works only on its
  named branch, and pushes nothing. Every brief opens with the time sentence above.
- A hand verifies only its own change: `bash -n`, its fixture once from the repo root, its
  `--matrix` once, and `validate-fixture-hygiene.sh`.
- Each hand commits on its branch with no `WIP:` prefix and reports the tip sha as text.

## Units

1. **`exp/fut-artifact-derivations` (tip 774736d56).** Finish the seven steps listed under
   "`exp/fut-artifact-derivations` at 774736d56" in the handoff's
   `## Final report status of the last four hands`. The branch was cut before rsj-reader-a/-b
   moved the rsj cells into `unit-reader-a.sh`/`unit-reader-b.sh`. Its step 5 (the rsj `lib.sh`
   `wfd_run`) and step 6 (EC41m-EC43m) are therefore made against `exp/fixture-unit-tests`'s rsj
   files: the hand first merges `exp/fixture-unit-tests` into its branch.
2. **`exp/fut-readset` (tip 12e6c9931).** Clear every "Owed" item under "`exp/fut-readset` at
   12e6c9931" in that same section. The `--matrix` partial output in `rs.pE1wKb/` came from a
   killed run and is void. Re-run it.
3. **`exp/fut-wait-beat-liveness` `--matrix`.** The branch is already merged into
   `exp/fixture-unit-tests`. Run `bash core/fixtures/wait-beat-liveness/run.sh --matrix` once on
   `exp/fixture-unit-tests`'s tip and compare its rows against the fixture's header matrix. The
   earlier `wbl/mx.out` came from a killed run and is void. If a row differs, the hand fixes it on
   a new branch `exp/fut-wbl-matrix`.

## Done

Each unit's report to `ai-dlc-b3` names its branch, tip sha, the fixture and `--matrix`
outcomes, and anything it left open with the reason. Then stop.
