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
