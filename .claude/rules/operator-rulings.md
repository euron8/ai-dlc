<!-- unconditional: standing rulings about authority and cost bind from the first turn, before any file is read, and must reach subagents. -->

# Operator standing rulings

Decisions the operator has already made. They hold across sessions; a repeated instruction is confirmation.

## Merges are preapproved

No plan and no task stops to ask for merge authorization. Cut the branch, run the gate, merge it. Where a
branch carries more than one release the release-version validator says so; that constrains branch shape.

## Ready releases are bundled and gated once

- The lead collects READY releases onto ONE integration branch and gates it once.
- Pushes stay serialized, one at a time; every other run goes in parallel.
- Call the advisor once immediately before every push: a hook outside the repo denies the push otherwise. The roll-call advisor
  call stays (exempt: PAUSED or CLOSABLE sessions); no pre-merge advisor call.
- A red caused only by one release drops that release from the bundle and the rest re-gate.
- A filing that lands after a bundle starts gating rides the next bundle; it never joins a bundle that is
  gating, and no ready release waits for one. While bundles flow, the batch keeps taking scope and assigns new
  entries to free builders.

## A consumer pull is NOT preapproved

Measure the delivery gap, write the runbook, rehearse it, report the number — then STOP. A written, rehearsed,
green runbook is READY, never AUTHORIZED; neither a `PENDING` count nor an earlier answer about WHETHER a pull
should happen decides WHEN. Never dispatch one, never hand one to a peer session, and never restate this ruling
in a status or ETA report. Before sending any peer work, check what the peer is DOING and put that state in the
question to the operator; `busy` in `ListAgents` is a reason to look further, never a green light.

## Everything is sourced and validated with ground truth

- Every claim in a plan, brief, commit message or report is derived against the working tree, with the
  derivation named. Numbers from an earlier session, a subagent or a document are hypotheses until re-derived;
  where a claim cannot be checked, say so.
- Verify once. The lead verifies a landing by content; the owner sends the sha and does not re-verify.
- Controls stay mandatory for absence claims and close verdicts, not for status messages.

## Scope is the operator's to change, never yours

A measurement may choose the MECHANISM; only the operator chooses whether the GOAL survives. Never narrow a
goal, drop an item or scale work down on your own authority. Deliver the whole scope and say what was blocked
and why. Partial delivery reported as completion is the failure this prevents.

## The output of a flawed process is UNTRUSTED

When the process that produced an artifact is broken, archive the artifact and rerun. Do not disposition it
green because it looks fine.

## Optimize wall clock where something waits, dollars where nothing does

Spawn agents liberally and in parallel; background anything long. Where something waits on the answer, wall
clock rules; where nothing does, cheaper tokens win even if slower. Profile the SCHEDULE per unit first:
measurement decides the ORDER, never the membership. A hand verifies ONLY its own change: `bash -n`, its
discriminating probe, the one unit it edited; the gate runs everything else. Never message a `graph-*` session,
even read-only, without an explicit operator grant.

## The lead orchestrates the box's load

Load from peer ai-dlc sessions on the lead's batch is the lead's to schedule. Pushes take the lead's slot one
at a time; every other run goes in parallel.

## No needless timing runs

Cost evidence for a routine change is the counts the gate records: invocations.decl, exec, fork and render
counts. Where the stated goal IS wall clock or box load, measure that: wall and CPU, old against new,
interleaved. Never ask to reconfirm a stated goal.

## The burden of verifying a change is proportional to the change

Re-run only what a change can move; carry the rest by byte-identity with a control and prove coverage by name.
The push gate is the one full verification: no hand re-runs of carriers or validators, no seeds unless named,
no repeat reading passes, and "two agreeing counted runs" is one counted run plus the gate's. A test that
cannot be trusted to catch what it claims gets a filing against the test, never a manual re-check around it.
A change never invalidates a verdict whose read inputs it did not change; no release forces a whole-suite
re-run. Enforcer: `scripts/invalidation-guard.sh` (pre-push).

## Zero tests depend on load (BL-868)

A test whose verdict or count moves with load is a defect, fixed in the test, never tolerated with a ± row, a
widened bound, a retry or fewer jobs.

## Read-set traces use the sandbox tracer, and the session runs them

Run every read-set trace as `bash core/scripts/derive-fixture-readsets.sh --list "<names>" --tracer sandbox`,
from a normal account with no `sudo`, in the main checkout detached at the commit to trace. A session owing a
trace runs it and commits the map. `fs_usage` and `--tracer both` are for the operator alone.

## A command handed to the operator states its runtime and its odds

Before giving the operator any command, state in the same answer how long it takes and whether it is expected
to succeed, from evidence. If the plan's precondition for it is unmet, say that instead of giving the command.

## A wall clock is a defect until it is justified

A fixture or gate that takes tens of minutes is doing more work than its checks need. Report a cost that grew
under your own change, with before and after; never quote a long wall clock as normal.

## A step with no measured value goes

A pipeline step, round or sub-step is kept only on evidence: a named failure case it prevents, and findings no
other round catches that survive to the shipped artifact. Without that the batch removes or merges it; it is
never put to the operator as a choice. Judge a rare high-consequence catch on consequence, not frequency. Every
efficiency ranking states hours removed AND dollars; a finding with no dollar figure is still a filed row.

## Handoff gaps are out of scope for efficiency analysis

The idle time between a handoff and the next `/ai-dlc resume` is never a finding, overhead row or opportunity.
Measure in-session time only, and state the exclusion once in the method.

## A local-model lead is a goal

A defect exposed under a local lead is a pipeline fix, never a finding against the model or a reason to
recommend a hosted lead.

## Lead compaction and resume are normal operation

Never design a mechanism that refuses, or forces a re-dispatch, because the lead compacted or resumed. A
missing lead-held value degrades to the prior behaviour; it never refuses.

## Reaching the operator

`AskUserQuestion` when a decision is genuinely theirs and the answer changes what happens next; a push
notification only after a long silence. Present an operator stall as CHOICES WITH A MARKED RECOMMENDATION, not
an open question. Report on any question, on any decision, and on completion including an early stop.

## Tier findings on consequence

**BLOCKER**, **DEFECT**, **NOTE**. A NOTE gets no lineage sentence and no justification paragraph. Keep locked
decisions to BLOCKER and DEFECT. Never present a dozen findings in one register.

## A closable session is stated plainly

When a peer session holds no further work (releases merged and verified, branches and worktrees cleaned up, no
slot, filing, relay or close duty owed), the lead says so plainly to the operator AND messages that session
that it is CLOSABLE.

## A tightly scoped defect is fast-tracked

Fold only the contract adversary's BLOCKERs, and a DEFECT only inside the reported subjects; one hand builds
it; one tip-adversary pass, BLOCKERs only; the lead adds no conditions; it takes the next free push slot,
never waiting on another release's readiness.
