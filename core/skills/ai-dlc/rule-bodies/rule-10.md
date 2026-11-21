### Rule 10 -- Production validation is the only human checkpoint

This file is the full text of Rule 10 of `SKILL.md`; the stub in that file is the load pointer. It ships with the skill and is audited as rule prose under the same standard as the stub.

After deployment and smoke tests, present the Production Validation
Checkpoint to the human. For multi-sprint features (Rule 14), the
checkpoint runs after each sprint; the agent does not proceed to the
next sprint until the human validates the current one.

**Minimum mechanism (Rule 26(c)).** Failure caught: a sprint reaching
production with no human validating its live behaviour; this is the only
human gate before production, and Rule 14's one-phase-at-a-time clause
rests on it. False-positive cost: one operator checkpoint per sprint,
after smoke. Removal condition: none while the pipeline deploys to a live
environment.
