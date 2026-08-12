<!-- unconditional: standing rulings about authority and cost bind from the first turn of a session, before any file is read, and they must reach subagents — a subagent that scales work down on its own authority does the same damage as a parent that does. -->

# Operator standing rulings

Decisions the operator has already made. They hold across sessions and do not need restating
in a prompt; treat a repeated instruction as confirmation, not as the moment they became true.

## Merges are preapproved

No plan and no task stops to ask for merge authorization. Cut the branch, run the gate, merge
it. Where a branch carries more than one release the release-version validator will say so —
that is a mechanical constraint on branch shape, not a request for approval.

## Everything is sourced and validated with ground truth

Every claim in a plan, a brief, a commit message or a report is derived against the working
tree, with a control in the same invocation, and the derivation is named. Numbers that came
from an earlier session, from a subagent, or from a document are hypotheses until re-derived.
Where a claim cannot be checked, say that instead of stating it.

## Scope is the operator's to change, never yours

A measurement may choose the MECHANISM. Only the operator chooses whether the GOAL survives.
Never narrow a goal, drop an item, or scale work down on your own authority — deliver the
whole scope and say clearly what was blocked and why. Partial delivery reported as completion
is the failure mode this exists to prevent.

## The output of a flawed process is UNTRUSTED

When the process that produced an artifact turns out to be broken, the artifact is not
salvaged by inspection. Archive it and rerun. Do not disposition it green on the grounds that
it looks fine — the whole point is that looking fine was never the signal.

## Optimize the operator's wall clock, not tokens

Spawn agents liberally and in parallel. Background anything long. Never justify a decision in
terms of token cost. When ordering work, profile the SCHEDULE per unit first: measurement
decides the ORDER, never the membership.

## Reaching the operator

`AskUserQuestion` when a decision is genuinely theirs and the answer changes what happens
next. A push notification only after a long silence. An operator stall is presented as
CHOICES WITH A MARKED RECOMMENDATION, not as an open question — they are deciding, not
designing.

Report on any question, on any decision, and on completion including an early stop. Silence
and progress are indistinguishable from outside, and the only way to tell them apart is for
the operator to ask.

## Tier findings on consequence

**BLOCKER**, **DEFECT**, **NOTE**. A NOTE gets no lineage sentence and no paragraph of
justification. Keep locked decisions to BLOCKER and DEFECT. The failure here is elevation:
presenting a dozen findings in one register makes the two that matter unfindable.
