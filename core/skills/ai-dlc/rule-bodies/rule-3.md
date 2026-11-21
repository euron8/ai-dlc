### Rule 3 -- Never stall the pipeline

This file is the full text of Rule 3 of `SKILL.md`; the stub in that file is the load pointer. It ships with the skill and is audited as rule prose under the same standard as the stub.

The pipeline runs as a continuous, uninterrupted flow. Exactly
FOUR pause points exist where you stop and wait for human input:

- (a) **Ambiguity resolution and operator-only decisions** (Rule 11).
- (b) **Production Validation Checkpoint** (Rule 10), including the
  stop before it while a locked requirement awaits its recorded
  disposition (`steps/deploy-validate.md` §5).
- (c) **Retro commentary prompt**.
- (d) **Sprint-scope confirmation** (`route-fresh-start.md` Step 6) -- the only
  pause point upstream of planning. Confirm or correct the scope you
  already resolved; it is never a question about what to build.

At a pause point -- and at any terminal STOP or integrity failure that
awaits a human -- `touch _bmad-output/pipeline-paused.flag` before
ending the turn. The Stop hook recognizes an intentional pause by that
flag alone; without it your pause reads as a stall and the hook returns
a forced-continuation reason urging you to pair the text with a tool
call, pushing you past the very checkpoint you stopped at.

(a) and (d) are the exceptions and set NO flag: each is solicited with
`AskUserQuestion`, so the turn never ends and the Stop hook never runs.
A flag set there is a pause nobody clears. (b) and (c) set the flag and
end the turn.

**EVERY `AskUserQuestion` CARRIES 2-4 OPTIONS PER QUESTION. A question with one
option is REJECTED BY THE HARNESS**, not by this rule -- `InputValidationError`,
`"code":"too_small"`, `"minimum":2` -- and the decision it carried is lost unless
you re-ask. Measured on one sprint: three rejections in three sessions, two of
them followed by a compaction inside three minutes, so the escalation went into a
summary and the operator never saw it. If you have only one course of action you
do not have a question; state it and act, or find the real alternative. This is
the single statement of that constraint; `steps/route.md` and
`steps/_gate-procedures.md` cite it rather than restating it.

If you are not at one of these four pause points, you are not done.
Keep working. A phase transition is not a pause point: run its gate
(`gate-validation.md`) and proceed without waiting for approval. Do not ask if you should continue -- that is about
continuing, never about an action only the operator can take.

**Show your work.** Output sub-skill results so the human can
observe the pipeline, then immediately continue to the next action.
Outputting and continuing = correct. Outputting and stopping = stalling.

**Tool call first, recap second.** When transitioning between
pipeline steps, issue the next tool call (Read the next step file)
IN THE SAME response as any status recap. A response that contains
only text and no tool call is a natural turn end — the model will
stop. A response that contains a tool call continues regardless of
surrounding text. Always pair recap text with the next action's
tool call. Never emit a recap without a tool call in the same response.
