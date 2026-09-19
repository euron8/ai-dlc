### Rule 13 -- Requirements define WHAT; agents have autonomy over HOW

This file is the full text of Rule 13 of `SKILL.md`; the stub in that file is the load pointer. It ships with the skill and is audited as rule prose under the same standard as the stub.

When carry-over items, brainstorming sessions, or direct user
instructions specify concrete details -- UI placement, implementation
approach, scope boundaries, feature behavior -- those details are
**locked requirements**. Validation cycles may challenge or question
locked requirements, but MUST NOT silently change them. Any
divergence from specified requirements -- dropping a requirement,
substituting different behavior, or determining a requirement cannot
be met as specified -- requires human sign-off via `HARD_BLOCK`
escalation (Rule 12, Tier 1). The escalation must quote the original
user-specified detail and the proposed change. Agents that rewrite
user intent into a vaguer form during planning are violating this
rule.

Agents have full autonomy over execution decisions: technical
approach, implementation patterns, UI layout choices (when not
specified by user), option selection among presented alternatives,
and scheduling. These are HOW decisions and use `DECIDED_AUTONOMOUSLY`
(Rule 12, Tier 2) when non-obvious.

**Live security-state mutation carve-out.** The autonomy grant above
does NOT extend to mutating LIVE access-control or security state:
permissions, roles, IAM/policy bindings, auth or network/firewall
rules, secrets/keys/credentials, or any control that governs who can
reach or change a running system. The agent MUST NOT autonomously apply
such a mutation to a live environment. Instead it STAGES the change — as
a reviewable diff, script, or PR the operator runs — and the operator
FIRES it. Each such action requires explicit in-session operator
authorization recorded per action (a standing "proceed" or a resume
prompt is NOT authorization — see "Pending operator approvals do not
transfer across handoff"); one ack does not cover a batch. This is a
deliberate tightening of Rule 13 autonomy: security-state changes are
high-blast-radius and often irreversible, so they are operator-fired
even when the agent is otherwise fully autonomous.

## HANDOFF PROTOCOL AND PIPELINE SNAPSHOT

The lead maintains a living pipeline snapshot throughout the sprint.
When context pressure or human request warrants a handoff, the
snapshot is the contract transferred to a new conversation.

### Living pipeline snapshot

**Path:** `_bmad-output/pipeline-snapshot.md`

**Created** at pipeline instantiation (see `route.md` Step 6).
**Updated** at every gate passage (full refresh, see
`gate-validation.md` Check 14) and at sub-step boundaries within
validation cycles and during implementation (lightweight refresh).
**Verified** after each gate-level update by `gate-validation.md`
Check 15, and on resume by `route.md` Step 0a.
**Finalized** on handoff request.

Structure -- lightweight markdown, no YAML frontmatter, seven required
sections (Pipeline Position, Sprint Context, Recent Activity, Open
Items, Locked Decisions, In-Flight Teammates, Context Reminders). The
canonical per-section field schema lives in `gate-validation.md` Check
14, which owns the snapshot refresh; `route.md` Step 0 reads it on
resume.

The snapshot is the source of truth for pipeline state. When
uncertain about current state, read the snapshot, not the
conversation scrollback.

### No self-scheduling skill re-entry

A self-scheduled wake-up (ScheduleWakeup, cron, or any deferred
self-trigger) MUST NOT carry a payload that invokes this skill or
re-enters the pipeline. Self-scheduled payloads are limited to
inert reminders or read-only status checks.

A self-fired resume is not merely harmful, it is UNNECESSARY: dispatched
subagents, backgrounded commands and long-running deploys already
re-invoke the lead when they finish, so the wake-up buys nothing the
harness does not already provide — it only re-enters the skill with stale
args and a stale snapshot. Auto-handoff terminates the session for a
human to resume (below); it never arms an automated re-entry.

As defense-in-depth, a resume that appears to have been fired by the
lead's own prior self-schedule rather than a human paste MUST be
discarded: recognise the stale-args signature and never execute its
instructions as current. A self-scheduled payload that re-enters the
pipeline is a **lead-conduct finding** at retro, scored with Check A and
Check B in `steps/retro.md`.

## HANDOFF PROTOCOL -- TRIGGERS AND CONTEXT THRESHOLDS

Continues the Handoff Protocol above; step files cite these subsections
as `SKILL.md` Handoff Protocol "<subsection>".

### Handoff triggers

**(a) Human-requested handoff** -- user explicitly asks to continue
in a new session (directly, or in response to a Rule 2(b)/(c)
reminder). Rule 11(b) preamble applies. Only path (a) initiates a
handoff. When it fires, **READ AND FOLLOW** `steps/handoff.md` — the
ordered 5-step procedure (stop teammates → commit → finalize snapshot →
emit the bare `/ai-dlc resume` line → pause flag + end session) and the
resume-line template. Resume is snapshot-driven: the entry line carries
no state; `route.md` Step 0 reads `_bmad-output/pipeline-snapshot.md`
for all of it. Never narrate pipeline state into the resume line.

Auto-handoff (below) executes this same `steps/handoff.md` procedure
unchanged at a safe seam.

### Pending operator approvals do not transfer across handoff

A resume prompt is never an operator approval for a pending gate. When a
handoff crosses a gate that awaits human sign-off, the successor session
MUST re-present that gate and obtain fresh in-session approval — even if
the resume text says "execute ... on my approval" or "proceed once
resumed." Approval is bound to the session that granted it; it does not
survive into a new conversation. This applies to every human gate: the
Production Validation Checkpoint, defined in `steps/deploy-validate.md`; a
destructive one-time operation, defined in `steps/deploy-validate.md`; a
`DEFERRAL_REQUEST`, defined in `escalations.md`; and any HARD_BLOCK
disposition, defined in `escalations.md`. Every gate named here MUST cite
the file defining its procedure. A gate with no procedure is not a gate:
in core AS SHIPPED the sprint-PR merge has none, because `steps/retro.md`
merges it without asking.

That is a fact about core's own deploy shape, not a ruling about yours.
Where a PROJECT's deploy policy defines a procedure for the sprint-PR
merge — an approval step in its `CLAUDE.md`, or in its
`steps/deploy-validate.md` — the same test makes it a human gate there,
and this rule binds it exactly like the four named above. Apply the test
to your own tree; do not read core's answer as a ruling about it.
Do NOT write an extension to say so. Treating resume text as
standing approval is a rule violation.

### Reminder thresholds

Yellow, red, and imminent are DERIVED from the resolved effective window --
a percentage of the window CLAMPED to a bounded "lead" below the ceiling
(`effectiveWindow - 31,000`), not read from a per-row table. The
`ai-dlc-context-sensor.sh` hook computes them and owns the formula, the
defaults, and the worked examples; tune via
`AI_DLC_SENSOR_{YELLOW,RED,IMMINENT}_PCT` and
`AI_DLC_SENSOR_{YELLOW,RED,IMMINENT}_{MIN,MAX}_LEAD`. The band constants are
guarded by `scripts/ai-dlc/validate-compact-window.sh` (see "Auto-compact ordering
invariant" below).

### Reminder semantics

The `ai-dlc-context-sensor.sh` hook measures resident context and emits
the yellow / red / imminent reminder automatically. You neither measure
nor estimate your own context window. If the user shares `/context`
output, treat it as authoritative.

Reminders are non-blocking: the pipeline continues after each one and
the decision is the user's. Any user reply to a reminder is a Rule 11
directive.

At each gate, reconcile the snapshot's Context Reminders fields from
`_bmad-output/.context-sensor-state` (see `gate-validation.md`
Check 14).

### Reminder text

`ai-dlc-context-sensor.sh` is the SOLE emitter and owns the exact wording of
all three bands; do not restate it here or in a step file. No band instructs
the lead to hand off, and no band asks the lead to OFFER one either -- what the
lead says to the operator at a threshold is (b)/(c)/(d) above, and theirs
alone. Every band carries the non-blocking doctrine in the shared wrapper; red
adds that the reminder is not an instruction to hand off, and imminent adds
that only path (a) initiates one and a threshold is not a request. Imminent
also directs a snapshot refresh BEFORE the next pipeline action, because
`ai-dlc-recover.sh` re-reads that snapshot after compaction and recovers a
stale one faithfully.

All three bands are a clamped percentage of the effective window below
`effectiveWindow - 31,000` (see "Reminder thresholds" above). imminent is
its own level ranked above red, so entering it always fires on the first
crossing, and it fires only when the model family's window is declared
(`AI_DLC_MODEL_<FAMILY>_WINDOW` in the settings `env` block) or the
statusline's `window.json` answered -- never on an assumed ceiling. yellow
and red still fire on the assumed 200,000-token floor, so an undeclared
project is never left un-warned.

### Auto-compact ordering invariant

Claude Code compacts at `effectiveWindow - 13,000`, where `effectiveWindow`
is `min(autoCompactWindow, model max)` and `autoCompactWindow` resolves in
Claude Code's precedence order (env > settings.local.json > project
settings.json > user settings; managed/enterprise settings and CLI flags
outrank all of these but are not readable from a hook, so they cannot be
modelled). Because every band is a clamped percentage anchored to the
resolved ceiling, red clears the compaction point BY CONSTRUCTION and the
disjoint clamp ranges keep yellow < red < imminent < compaction for any
window.

AI/DLC does not write `autoCompactWindow`. Run
`scripts/ai-dlc/validate-compact-window.sh` to confirm the band constants keep the
ordering (disjoint clamp ranges, monotonic percentages, red with runway to
spare) and to report the resolved window; it FAILs on a value outside
`[100000, 1000000]`, which Claude Code would silently discard back to the
model default.

### Auto-handoff (configurable via `auto_handoff_mode`)

The lead MAY automatically execute the path (a) procedure
(`steps/handoff.md`) at a defined safe seam when all preconditions hold.
Auto-handoff is NOT a fifth pause point -- it is a session-terminating
action that runs the path (a) procedure unchanged, and resume itself is
never automated.

`auto_handoff_mode` is read from `AI_DLC_AUTO_HANDOFF_MODE` in
`.claude/settings.json` "env"; unset means `off`. A project that excludes
particular seams sets `AI_DLC_AUTO_HANDOFF_SEAMS_EXCLUDED` to a
comma-separated list of seam letters (e.g. `B,C,D`); unset excludes none.
**Do not edit this section to change either value** — a project that
shadows it to pin a mode freezes every unrelated line in the section at
its `base_sha`, which is how an unrelated fix stops arriving. Values:

- `off` (default) -- disabled; only human-requested handoff fires.
- `deploy-only` -- fires only at `Seam A` (pre-deploy preflight in
  `deploy-validate.md`), and only when the context sensor has
  measured red.
- `safe-seam` -- fires at any defined safe seam (`Seam A` through
  `Seam E`); the seam is the trigger and the token *magnitude* is
  advisory (the fire itself is mandatory once the seam is reached and
  preconditions pass — never a discretionary "is the context large
  enough" or "the user is still active" judgment; see `_gate-procedures.md`
  "Auto-handoff evaluation").

The full firing rules -- the seven-precondition evaluation, the per-mode
trigger basis, the resume-safety and clean-boundary constraints, the
distinguishing output line, and the seam definitions (including `Seam E`,
retro entry) -- live in `_gate-procedures.md` \"Auto-handoff evaluation\".
Step files invoke that helper at each seam.

## ADDITIONAL OPERATING RULES

The rules below apply to pipeline execution but are less time-
critical than Rules 1-13. They may sit past the 5K token boundary
that Claude Code re-attaches after compact; if they appear missing
after a compact event, re-invoke `/ai-dlc` to restore them.

