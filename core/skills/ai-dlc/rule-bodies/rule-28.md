### Rule 28 -- Delegation is the default; inline execution is the exception

This file is the full text of Rule 28 of `SKILL.md`; the stub in that file is the load pointer. It ships with the skill and is audited as rule prose under the same standard as the stub.

The lead MUST delegate any action a subagent can service. Doing the
work inline in the lead's own conversation is permitted ONLY when the
action falls in the **non-delegable set**:

- **(a) Orchestration** -- spawning/joining teammates, task creation and
  dependency wiring, wave/DAG planning, branch and worktree management,
  merge and land-order integration (including merge-conflict resolution,
  `implementation.md` -- integration is orchestration), and discharge-
  predicate execution at deploy gates.
- **(b) Routing** -- pipeline-variant selection and step sequencing.
- **(c) Gate-validation decisions** -- resolving the manifest, running the
  `script` / `project` / `lead` checks, owning the PASS/FAIL, the remediation
  disposition and the escalation, and adopting the `gate-adjudicator`'s per-check
  verdicts via Check 26. Applying the remediation EDIT is NOT in this set: the
  repair is dispatched to a `remediator`
  (`_gate-procedures.md`, "Adversarial repair dispatch") and the lead verifies it
  against the repair record. The lead still owns the disposition -- but it clears
  a FAIL only through a dispatched repair, never by editing the artifact inline.
  Evaluating an individual `adjudication: llm` check is NOT in this set: like a
  Rule 20 validation evaluation it is escalated to a fresh `gate-adjudicator` and
  never rendered solo in the lead's context. The lead still owns the outcome --
  but it adopts an `llm` verdict only through fail-closed Check 26, never by
  judging the check inline.

Triggering a validation sub-skill (Rule 20) is orchestration -- the lead
triggers it but does not roleplay it, and Rule 20 requires the evaluation
itself to run in real, independent subagents (`mode: subagent`), never solo
in the lead's context. A validation sub-skill executed solo is both a Rule 20
violation and the Rule 28 failure this rule names (the lead absorbing
delegable evaluation work into its own context).

**Everything else is delegated.** Implementation and fixes -> dev
teammates. Read-heavy planning exploration -> analyst (Rule 24).
Protected-path edits -> `protected-path-editor` (Rule 26 / this rule /
`implementation.md`), which the lead formerly executed itself. Code
review -> code-reviewer. Test validation -> qa. UI/design production
(mockups, copy, CSS-class specs, accessibility review) -> ux
(`ui-direction.md` §0).

**Burden of justification is inverted.** The lead does NOT get to reason
"this is small, I'll just do it." When the lead performs any action
inline, it MUST name which exclusion (a/b/c) authorizes it. An inline
action outside the non-delegable set -- editing source, reading a
codebase to understand it, drafting an artifact, applying a fix -- is a
lead-conduct retro finding, even when the lead could have done it
faster alone. The point is not speed; it is keeping production work in
subagent context and the lead in orchestration (Rule 23).

**Split dispatch: one agent per independent part.** Rule 28 decides
WHETHER work is delegated; this clause decides the SHAPE of a
delegation. When a dispatch's scope partitions along an independent
axis, the lead dispatches one agent per part, plus one cross-part agent
where the axis says parts interact, in the waves described below, and
joins each wave in one bounded-join beat (Rule 29). The axes:

- **files** -- an artifact that is two or more files (`stories/`), or a
  story's changed-file set as `partition-review-diff.sh --map` prints it:
  one agent per file or part plus one cross-part agent scoped to
  interactions between them only. Every finding or edit names the parts
  it cites; a per-part agent reports only findings citing its own part
  alone, the cross-part agent only findings citing two or more. A review
  the program answers `SERIAL` is `shard: 1/1 <story-index>`, never
  `shard: none (…)`.
- **sections** -- a single document that `partition-document.sh --map`
  partitions: one agent per part the map prints plus one cross-part
  agent scoped to interactions between sections only, citing parts by
  the same rule as the files axis. A review joins with
  `merge-adversarial-shards.sh --document`; a repair shard edits only
  its section file from `partition-document.sh --split`, and
  `join-remediator-shards.sh --document` joins the parts and runs
  `partition-document.sh --assemble`, which refuses unless the document
  is still the bytes it was split from.
- **worklist items** -- a list a program derives
  (`validate-gate-adjudication.sh --expected`): slices of the derived
  order, no cross-part agent.
- **surfaces** -- the surfaces a Rule 24 Section 0 declares: one analyst
  per surface, no cross-part agent.
- **seats x parts** -- a party-mode round over a files-axis subject: one
  persona agent per (seat, part) plus one cross-part round.
- **seats x sections** -- a party-mode round over a sections-axis subject:
  one persona agent per (seat, part) plus one cross-part round per seat.

**The partition is derived, never listed.** The part set comes from a
program or from the tree -- the artifact directory's listing, the
`--map` of a document, the `--expected` worklist, the Section 0 surface
list -- and never from a
list the lead types into a brief. **The join is a program.** It
re-derives the same set, refuses unless every part delivered exactly
once and every finding respects the partition, and only then writes
the single file the gate already reads. Readers of that file do not
change; a lead that assembles the file by hand has not joined.

**Waves: the harness caps concurrent subagents.** The harness runs at
most `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` subagents at once in a
session and rejects every spawn past that with `Concurrent subagent
limit reached. You can run <N> subagents at once. Do not retry.`; that
rejection text carries the live value, so read the cap from it and
never from a number written here. A rejected spawn launches nothing and
writes nothing. Every fan-out in ai-dlc therefore goes out in waves: a
wave is at most the cap minus the agents already running in this
session, its spawns go out together as parallel `Agent` calls, and each
wave is joined with
one bounded-join beat (Rule 29) before the next wave spawns. Until a
rejection has shown the cap, the first wave is the whole set; its
rejections are the probe. A slot frees when an agent EXITS, not when its
deliverable lands, so a wave sized from deliveries can over-dispatch
slightly; the rejected-spawn rule below absorbs that. Every per-role
site that fans out cites this paragraph and does not restate it.

**The round's epoch is written down before wave 1.** Before the first
wave spawns, the lead records the round's start as an epoch in the
snapshot's Open Items -- one line, `fan-out round <subject> since
<epoch>` -- and passes `--since <epoch>` on every beat of the round.
That line stays through every Open Items refresh until the round's join
has completed, and is deleted then. The In-Flight Teammates row cannot
carry it: a row is deleted when its deliverable is consumed, so it is
gone for exactly the parts already delivered, and Recent Activity
rotates. `wait-for-deliverable.sh` drops a path's own epoch when it
reports it `DELIVERED`, so a path re-armed after a compaction without
`--since` reads its finished file as pre-existing and waits to
NON-DELIVERY, spending the Rule 20 budget on an agent that is done.

**A rejected spawn is undelivered, and holding it is not a retry.** Read
the rejected set synchronously from the `Agent` tool results of the
message that dispatched the wave. Never pass a rejected spawn's
deliverable path to `wait-for-deliverable.sh`: nothing is writing it, so
the join would exhaust its whole beat sequence and then spend the Rule 20
one-re-dispatch budget on an agent that never ran. Arm only the paths of
launched agents, and arm one beat over every outstanding path from all
waves, never one beat per wave. Hold the rejected set, and re-dispatch
exactly that set only after a bounded-join beat has returned with at
least one `DELIVERED` line -- never in the next message. This is not the
retry the harness forbids: its "Do not retry" forbids re-spawning with
no evidence anything has changed, and a re-dispatch here waits for
evidence of progress, a `DELIVERED` line, which is the sign that an agent
of this round has finished its work and will exit. A spawn rejected twice
waits for a further beat with a fresh `DELIVERED` before it is tried
again. A rejected spawn's re-dispatch is its first launch, so it never
spends the Rule 20 re-dispatch budget, and its path is armed in the next
beat without `--reset` -- a `--reset` in that call would also restart the
clock on every other path it names.

**A wave that launched nothing still owes a beat.** `wait-for-deliverable.sh`
refuses an empty path list, and Rule 29 forbids ending the turn on an
outstanding join with no live beat. So a wave whose every spawn was
rejected arms one beat over every still-outstanding path from earlier
waves. If none is outstanding, the cap is held by agents this round does
not own: HARD_BLOCK, naming them.

**The join names what is missing, never what it counted.** It derives the
expected part set from the same program as the dispatch, takes as
delivered every expected path that is non-empty and written since the
round's epoch -- which is what a beat armed with `--since <epoch>`
reports as `DELIVERED`, and a previous sprint's file at the same path is
older than the epoch -- and names expected minus delivered. That missing
set, with the held rejected set, is what the next wave carries. A count
of files in a directory is not a join.

**What stays serial, and only this:** (1) a true data dependency as
`_dispatch-protocol.md` defines it, and the protected-path
one-at-a-time rule in `stories-test-strategy.md`; (2) a convergence
sequence -- review pass, repair, next pass; sharding shortens a pass and
never overlaps two; (3) an ordered authoring chain whose next step
reads the previous one's output; (4) a single document that
`partition-document.sh --map` reports SERIAL. A per-role site cites
this clause and names its axis and its join; it does not restate them.

The lead's written dispatch plan names, for every dispatch, its axis
and part count or which of (1)-(4) keeps it whole. Every shard brief
carries one line `shard: <i>/<N> <part-key>` (the cross-part agent:
`shard: cross/<N> cross`) or `shard: none (<exception 1-4>)`. A
sections-axis part key is the part's heading from the map, as in
`shard: 2/5 ## Functional Requirements`; a document the map reports
SERIAL is `shard: none (serial-document)`. Only the first parenthesised
group is read, so text may follow it on the line. A `none` naming anything
other than (1)-(4) is recorded as an invalid exception and FAILS Check 22;
omitting the line is a warning.

**Minimum mechanism (Rule 26(c)) -- split dispatch.** Failure caught:
the lead blocked on one agent reviewing, repairing or adjudicating a
whole multi-part subject while every other lane sits idle, with the
agent's wall clock growing with the parts named in its brief; and a
fan-out wider than the harness's concurrent-subagent cap launching only
its first cap's worth while the lead joins the rest as if they had run,
which proceeds on a partial round. False-positive cost: one fixed
per-agent load cost per extra part, one cross-part agent, one join
program run, and one extra beat per wave past the first -- paid in spawn
overhead, recovered in wall clock. Removal condition: retire the split
once the harness parallelises a single agent's independent sub-scopes
itself, or once the join programs report that parts routinely arrive no
faster than one whole-subject agent; retire the waves once the harness
queues a spawn past its cap instead of rejecting it.

**`SendMessage` reaches a resident teammate; it does not create a context.**
A teammate you can still message is NOT a blank slate: its original dispatch
brief and every prior exchange remain in its context and OUTRANK anything sent
later. So `SendMessage` carries only content that is ADDITIVE AND CONSISTENT
with the brief that teammate was dispatched under -- a fold-in arriving before
the deliverable lands, a crash-recovery resolution, an answer to the teammate's
own question, a gate verdict on its own work. Two things it may never carry:

- **Retracted or narrowed scope.** A patch message cannot displace the original
  brief; the teammate builds what the brief said. Scope reduction is `TaskStop`
  plus ONE fresh self-contained dispatch stating the out-of-scope list.
- **New or scope-distinct work, however small.** That is a fresh `Agent`
  dispatch, regardless of how many resident teammates already exist. Resident-
  teammate count is a `TaskStop` cleanup concern, never a dispatch-routing
  input.

**Minimum mechanism (Rule 26(c)).** Failure caught: the lead absorbing
delegable work inline, saturating its context and collapsing the
production/orchestration boundary -- and its mirror, the lead RECYCLING a
resident teammate for work that never belonged to it, which reintroduces an
unrelated brief and exchange history into a deliverable that was supposed to
start clean, and reports back with no signal that it did. False-positive cost:
an occasional dispatch of work the lead could have done in one turn, or one
extra spawn where a message would have been reused -- paid in one orchestration
round, recovered in context headroom. Removal condition:
retire once the harness structurally prevents the lead from taking
non-orchestration actions.
