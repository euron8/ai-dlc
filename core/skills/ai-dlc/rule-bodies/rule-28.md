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
- **(b) Routing** -- pipeline-variant selection, step sequencing, and
  story-to-role routing (an `escalate_model` tag set before a story's first
  dev dispatch, `implementation.md` "Pre-dispatch routing").
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
axis, the lead dispatches one agent per part, plus ONE cross-part agent
(one per seat on a seats axis) where the axis says parts interact, in the waves described below, and
joins them with bounded-join beats (Rule 29). The axes:

- **files** -- an artifact that is two or more files (`stories/`), or a
  story's changed-file set as `partition-review-diff.sh --map` prints it:
  one agent per file or part plus one cross-part agent
  (below), reporting interactions only. Every finding or edit names the parts
  it cites; a per-part agent reports only findings citing its own part
  alone, a cross-part agent only findings citing two or more. A review
  the program answers `SERIAL` is `shard: 1/1 <story-index>`, never
  `shard: none (…)`. Stories elicitation dispatches the same ONE
  cross-story agent briefed with every ordinal, writing `cross.md`
  (`_gate-procedures.md`, validation-cycle item 2).
- **sections** -- a single document that `partition-document.sh --map`
  partitions: one agent per part the map prints plus one cross-part
  agent (below), reporting interactions only, citing parts by
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
  persona agent per (seat, part) plus one cross-part agent per seat. The
  seats record findings and edit nothing; a files-axis repair applies them.
- **seats x sections** -- a party-mode round over a sections-axis subject:
  one persona agent per (seat, part) plus one cross-part agent per seat.
  The seats record findings and edit nothing; a sections-axis repair
  applies them.
- **subject** -- a subject of several files reviewed as one, under one
  base recorded in its manifest (the requirements step's brief, spec,
  PRD and architecture-impact record): one agent per part that
  `partition-subject.sh --map` prints plus one cross-part agent
  (below), reporting interactions only, citing parts by the same rule as the
  files axis. A file unchanged since the base has no part. A review
  joins with `merge-adversarial-shards.sh --subject`; a repair shard
  edits only its section file and `join-remediator-shards.sh --subject`
  joins the parts and reassembles every file. A subject that maps to one
  part is exception 4.
- **seats x subject-parts** -- a party-mode round over a subject-axis
  subject: one persona agent per (seat, part) plus one cross-part agent
  per seat. The seats record findings and edit nothing; a subject-axis
  repair applies them.

**One cross-part agent, never one per group.** On every axis that has a
cross-part agent -- code review and QA validation, an adversarial pass or
repair, elicitation -- the dispatch has ONE, and a party round has one per
seat. It is briefed with every ordinal the map printed, goes out in the
same waves as the parts, reads the WHOLE subject, may cite any part, and
writes `cross.md`. It replaces one cross agent per row of
`partition-document.sh --cross-groups <K>`: measured over the s319 and s320
stories elicitation, the per-story shards made 32 unique surviving catches
at $3.06 each against the cross groups' 3 at $25.15, and every cross group
had already read every story (`BL-811`). Both merges and Check 24 still
accept a COMPLETE `cross-1..G` set written by a dispatch before this rule,
never mixed with `cross.md`; in such a set a cross finding is OWNED by the
group `partition-document.sh --cross-owner <K> <ordinal,ordinal,...>`
prints, and the join refuses one reported outside its owner only when the
owner's shard carries the identical cited set. Every part and cross agent writes its file early
and ends it with one `seat-complete: ... sha=<hex> findings=<n>` line,
appended once as its final act by `wait-for-deliverable.sh --mark`, and its
join beat passes `--complete`
(`_gate-procedures.md`, "Validation cycle" item 1). A SERIAL map has no
cross agent.

**Code review and QA shard their execution too.** On a review over
`partition-review-diff.sh --map`, at gate 1 and gate 2 alike, each part
agent replays the mutation-REDs anchored in its part in its own detached
worktree at the frozen sha, and the cross agent goes out in the same
wave as the parts. The cross agent does its part-independent work
first and joins the part files itself only before the hand-over replays
and the per-AC table (`implementation.md`, the Gate-1 and Gate-2
dispatch paragraphs). What remains on that one agent is the canonical
suite run and the replays a part HANDED OVER, run in the frozen worktree.
**That residue is serial by design, by operator ruling (`BL-474`), taken on
the measurement: every sharded review measured carried zero hand-overs.**
A hand-over is defined as an AC whose replay cannot reach a GREEN
baseline in a fresh detached worktree at the frozen sha, so a per-group
copy made that same way repeats the failure. The frozen worktree's
environment is shared and mutable, and no other copy of it exists.
`merge-review-shards.sh` accounts for every hand-over exactly once.

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
rejection text carries the live value. A rejected spawn launches nothing
and writes nothing. The lead takes the cap in this order: (1) the
readable value, when the lead can read one -- a Bash `printenv
CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`, or the "You can run <N> subagents"
text of a rejection this session already holds; (2) otherwise the
rejection probe: while the cap is unknown, the first wave is the whole
ROUND -- every seat's every part and every seat's cross agent -- so the
wave-size floor is every undispatched member, and the first rejection
that wave draws carries the cap; (3) never an assumed or remembered
number, and never a number written here. Every fan-out in ai-dlc
therefore goes out in waves: a wave's spawns go out together as parallel
`Agent` calls, and a wave is never smaller than the lesser of the members
still undispatched and the cap (`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`,
taken as above) minus the agents already running in this session. A seat
is not a wave: a round split by seat, or by any grouping the cap did not
force, leaves slots idle while each group waits on its slowest member.
Among the waves of ONE fan-out, no wave waits on an earlier wave's join.
The serial cases under "What stays serial" -- a true data dependency, a
review pass and the repair that follows it, an ordered authoring chain --
are not waves of one fan-out: each step there is its own dispatch, joined
before the next is sent. A slot frees when an agent EXITS, not when its
deliverable lands, and each exit while round members remain undispatched
releases the next members, up to the free slots. Each refill arms its
own beat over only the paths that refill launched, with the round's
`--since <epoch>` and `--dispatch` per agent -- one beat per refill, never
one beat per agent; never `--reset` the live beat, which would restart
every other path's clock. A
wave sized from deliveries can over-dispatch slightly; the rejected-spawn
rule below absorbs that. Every per-role site that fans out cites this
paragraph and does not restate it.

**The round's epoch is written down before wave 1.** Before the first
wave spawns, the lead records the round's start as an epoch in the
snapshot's Open Items -- one line, `fan-out round <subject> since
<epoch>` -- and passes `--since <epoch>` on every beat of the round.
Every beat that passes `--since` also passes `--dispatch <agentId>` for
each agent it joins, the `agentId` (or a named teammate's `agent_id`) its
Agent result returned: the beat reads that dispatch's time from the spawn
ledger and refuses a `--since` later than it.
The `<epoch>` is the one recorded before wave 1, never one minted at the
beat. A beat outside a fan-out round, on an agent this session
dispatched, has no round epoch and passes `--dispatch` alone, which sets
the join to the dispatch; an epoch minted after the spawn is the stamp
`wait-for-deliverable.sh` refuses with
`FAIL: --since is <n> s after the earliest dispatch it joins`.
A join resumed after a compaction passes its row's `dispatched-at` with
`--dispatch` (`steps/_gate-procedures.md`, "Bounded-join beat"), and a
teammate a prior session dispatched has no dispatch record this session
can read, so its row is re-armed by its `dispatched-at` alone
(`steps/route.md`, "Step 0: Entry-token and Resume Check").
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
launched agents: one beat over every outstanding path at once, plus one
beat per refill over only the paths that refill launched, never one beat
per agent. A slot frees when an agent exits, and
not before. Hold the rejected set, and re-dispatch exactly that set only
after an agent of this session has exited since the rejection -- never in
the next message. Two records show it: an agent task-notification, which
is an agent exiting, or a non-error `Agent`/`Task` tool_result, which
is the cap admitting a spawn and so a slot having freed, unless it
answers a call from the same message as the rejection. An error result
of any kind, a hook refusal included, launched nothing and frees nothing. A `DELIVERED`
line is not one of them: the agent that wrote the file may not have
exited yet. This is not the retry the harness forbids: its "Do not retry"
forbids re-spawning with no evidence anything has changed, and a
re-dispatch here waits for evidence that a slot has freed. A spawn
rejected twice waits for a further exit after its second rejection before
it is tried again. `ai-dlc-dispatch-guard.sh` refuses a lead re-send whose
`description` was rejected with neither record after it. A rejected spawn's re-dispatch is its first launch, so it never
spends the Rule 20 re-dispatch budget, and its path is armed in the next
beat without `--reset` -- a `--reset` in that call would also restart the
clock on every other path it names.

**A wave that launched nothing still owes a beat.** `wait-for-deliverable.sh`
refuses an empty path list, and Rule 29 forbids ending the turn on an
outstanding join with no live beat. So a wave whose every spawn was
rejected arms one beat over every still-outstanding path from earlier
waves. If none is outstanding, the cap is held by agents this round does
not own: HARD_BLOCK, naming them.

**A notification the live beat already covers is not a turn's work.**
When a task-notification arrives for an agent whose deliverable is a
path you passed to your still-running `wait-for-deliverable.sh` beat,
the beat reports that path: post no status line for the agent, restate
none of its findings or counts, re-check nothing, read nothing, and end
the turn. Inside a `--complete` join the round is reported once, from
the merge, never per seat. Three notifications are not covered. One whose
status is failed: that agent is dead and its deliverable will never
arrive, so it is handled now. The first exit since a spawn was
rejected while that rejected set is held: it releases the set, which is
re-dispatched on it as above. And an exit while round members remain
undispatched: it releases the next undispatched members, up to the free
slots, dispatched on it as the Waves paragraph says.

**The serial remediator's join is armed on the record it appends to.**
Arm it as `_gate-procedures.md` "Adversarial repair dispatch" gives its
`**Join**`, with `--complete-repair` and `--dispatch` alone, never the
plain completion flag: the remediator ends its block with a
`repair-complete: serial <pass> sha=<hex>` line, appended by
`wait-for-deliverable.sh --mark-repair`, which only `--complete-repair`
reads as complete, so a plain beat reads that record unfinished forever.

**The join names what is missing, never what it counted.** It derives the
expected part set from the same program as the dispatch, takes as
delivered every expected path that is non-empty and written since the
round's epoch -- which is what a beat armed with `--since <epoch>`
reports as `DELIVERED`, and a previous sprint's file at the same path is
older than the epoch -- and names expected minus delivered. That missing
set is re-dispatched after the join, under the Rule 20 re-dispatch
budget. The held rejected set is not part of it: it goes out on the first
exit since its rejection, as above, never held for the join. A count
of files in a directory is not a join. When you state a record's time
against a dispatch yourself, take it from
`scripts/ai-dlc/file-mtime.sh <path>`, which prints the epoch and a UTC
stamp, never from a hand-written format: `stat -f %Sm -t %FT%TZ` prints
LOCAL time followed by a literal `Z`.

**What stays serial, and only this:** (1) a true data dependency as
`_dispatch-protocol.md` defines it, and the protected-path
one-at-a-time rule in `stories-test-strategy.md`; (2) a convergence
sequence -- review pass, repair, next pass; sharding shortens a pass and
never overlaps two; (3) an ordered authoring chain whose next step
reads the previous one's output, which includes the serial remediator
dispatched after a join, whose line is `shard: none (authoring-chain)`; (4) a single document that
`partition-document.sh --map` reports SERIAL, or a subject that
`partition-subject.sh --map` maps to one part. A per-role site cites
this clause and names its axis and its join; it does not restate them.

The lead's written dispatch plan names, for every dispatch, its axis
and part count or which of (1)-(4) keeps it whole. Every shard brief
carries one line `shard: <i>/<N> <part-key>` (the cross-part agent:
`shard: cross/<K> g1/1 <ordinals>`, K being the map's part count and
`<ordinals>` every ordinal 1..K, comma-joined, without zero padding --
Check 22 arm S4 refuses a brief that omits one; every axis keeps ONE
cross agent per dispatch, one per seat in a party round, a code or QA
review over `partition-review-diff.sh --map` included)
or `shard: none (<exception 1-4>)`. A
sections-axis part key is the part's heading from the map, as in
`shard: 2/5 ## Functional Requirements`; a document the map reports
SERIAL is `shard: none (serial-document)`. Only the first parenthesised
group is read, so commentary goes after the closing parenthesis, never inside
it. A `none` naming anything other than (1)-(4) on a shardable role is refused
at dispatch; on any other role it is recorded as an invalid exception, which
Check 22 does not judge. Omitting the line is a warning.

**Minimum mechanism (Rule 26(c)) -- split dispatch.** Failure caught:
the lead blocked on one agent reviewing, repairing or adjudicating a
whole multi-part subject while every other lane sits idle, with the
agent's wall clock growing with the parts named in its brief; and a
fan-out wider than the harness's concurrent-subagent cap launching only
its first cap's worth while the lead joins the rest as if they had run,
which proceeds on a partial round. False-positive cost: one fixed
per-agent load cost per extra part, up to six cross-part agents, one join
program run, and one extra beat per refill past the first wave -- paid in spawn
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
own question, a gate verdict on its own work. Three things it may never carry:

- **Retracted or narrowed scope.** A patch message cannot displace the original
  brief; the teammate builds what the brief said. Scope reduction is `TaskStop`
  plus ONE fresh self-contained dispatch stating the out-of-scope list.
- **New or scope-distinct work, however small.** That is a fresh `Agent`
  dispatch, regardless of how many resident teammates already exist. Resident-
  teammate count is a `TaskStop` cleanup concern, never a dispatch-routing
  input.
- **More work for a remediator whose record already carries its `repair-complete:`
  line**, a refusal included. A gate verdict on its work does not reopen a finished
  record; `_gate-procedures.md`, "Adversarial repair dispatch", re-dispatches it fresh.

**A dispatched teammate reaches the lead with `SendMessage` `to: "main"`.** The
word "lead" is a role, not an address: the harness registers no agent by that
name. Measured on the reference consumer's plain-`Agent` dispatches across
Claude Code 2.1.276-2.1.296: `to: "main"` delivered 167 of 167 sends, `to:
"lead"` delivered 0 of 15 (`No agent named 'lead' is reachable`), and `to:
"team-lead"` was accepted 18 times (a 19th was refused for an empty message).
`team-lead` is the agent-teams address: the consumer's 9 ad-hoc teammates spawned
with `team_name` sent 4 messages `to: "team-lead"` and the lead received them,
while `to: "main"` from a teammate spawned with `team_name` is UNMEASURED. A
role-bound dispatch carries no `name` (Rule 19(c)), so it is never such a
teammate, and the role files use `main`. Teammates do not load rule bodies, so
every role-file and skill instruction telling a teammate to message or escalate
to the lead carries the literal `to: "main"` at its own site; the
`process-rule-pins` fixture fails on one that does not.

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
