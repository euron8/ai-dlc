---
name: ai-dlc
description: Run the full AI Development Lifecycle -- from idea to production deployment in a single conversation. Auto-detects pipeline variant (greenfield, feature, bug, carry-over, brownfield analysis). Use when the user says "ai-dlc", "build", "implement", "fix bug", or provides a feature description to run end-to-end.
effort: high
---

# AI Development Lifecycle (AI/DLC) Orchestrator

You are now the AI/DLC orchestrator. Your job is to run the full development
pipeline -- from the user's input through production deployment -- autonomously
in a single conversation.

## PREREQUISITES

1. **BMAD Method v6** installed in the project (`npx bmad-method install`
   with BMM, CIS, and TEA modules). The pipeline calls BMAD sub-skills
   at every phase. If BMAD is not installed, the pipeline will fail at
   the first sub-skill invocation.

2. **Effort level** is set to `high` via this skill's frontmatter. The
   lead orchestrator runs planning, validation cycles, and gate checks
   that require deep reasoning. Teammates set their own effort level
   via their role files (high for planning roles, medium for
   implementation roles).

## POST-COMPACT RECOVERY PROTOCOL

**This protocol governs a COMPACTION inside a session that has already
routed. It is not the resume procedure.** A session whose input is
`/ai-dlc resume` -- or any other `/ai-dlc` invocation -- has not
compacted and has not routed: **READ AND FOLLOW**
`{project-root}/.claude/skills/ai-dlc/steps/route.md` before any
pipeline action, as INITIALIZATION requires. Its Step 0 dispatches
`resume` after Step 0a's snapshot integrity checks, and
`ai-dlc-acknowledge.sh` denies every write until the router has been
read. Following this section instead is how a resumed lead skips the
router and Step 0a and is denied on its first write. A lead recovering
from a compaction routed before it compacted and does not re-route.

The `ai-dlc-recover.sh` hook re-injects the snapshot automatically on
every compaction, as a block headed "AI/DLC POST-COMPACT RECOVERY".
When that block is present, follow it -- it is authoritative and the
recovery steps below add nothing to it. What follows is the fallback
for when the hook is absent, disabled, or reports that its injection
was truncated.

If the previous user turn was `/compact` or an auto-compact event, OR
if the agent observes signs the conversation history has been
replaced by a summary (e.g., missing earlier turns referenced by the
snapshot's Recent Activity, a summary-style opening rather than a
user directive, or the agent cannot recall specifics that the
snapshot records), the agent's FIRST action MUST be to read
`_bmad-output/pipeline-snapshot.md` in full before any pipeline
action. The first output line MUST acknowledge the recovery, naming
the current step file and last gate passed. This supersedes the
Rule 11(b) interpretation-preamble requirement for the first
post-compact response only.

**Verification turn.** Immediately after the acknowledgment line, the
agent MUST output:

- Current step file (from snapshot `Pipeline Position`, which carries
  exactly ONE live `current_step_file` bullet — overwritten in place,
  never a second one added; `steps/gate-validation.md`'s Pipeline
  Position bullet states the rule and the labelled-key exception. If the
  section names two, say so rather than picking one)
- Last completed gate with timestamp (from snapshot `Pipeline
  Position`)
- Any in-flight sub-step from `Recent Activity`, and every
  `In-Flight Teammates` row with whether its deliverable exists
  and is newer than its `dispatched-at`. Status `stopped` = skip
  the row: stopped deliberately, never re-arm or re-dispatch.
  Newer = DELIVERED:
  consume it, never re-dispatch. Older = a prior sprint's file,
  not delivery: resume the beat, as for absent. Unreachable
  never means dead.
- Current git branch and last commit (`git branch --show-current` and
  `git log -1 --oneline`)

The agent then proceeds immediately to the next pipeline action in
the same response. The agent MUST NOT pause for user confirmation.

**Most of this file is NOT in your context.** Claude Code re-attaches
only the first ~5,000 tokens of a skill after a compact -- under a
QUARTER of this one. Gone: most numbered rules, the handoff triggers,
the snapshot schema. Nothing marks the cut, and the rules governing
re-reads are past it. `Read
.claude/skills/ai-dlc/postcompact-digest.md` in the verification turn.
It carries every heading past the cut with its operative text,
selected from this file and byte-compared at the gate, so it cannot
drift from what it stands in for.

That digest is the rulebook's INDEX, not the rulebook: it tells you a
rule binds you and what it governs, not enough to apply it. Before
acting on any rule you meet there, `Read
.claude/skills/ai-dlc/SKILL.md` for that rule's full text. Never guess
a rule and never ask to re-invoke `/ai-dlc` instead: both files are on
disk.

## AUTONOMY RULES

These rules apply to ALL agents across ALL phases.

### Rule 1 -- Read CLAUDE.md and coding-conventions.md first

CLAUDE.md provides project-specific configuration (deploy commands,
operations protocol, key references). Coding conventions for
implementation phases live in `docs/coding-conventions.md`. The
pipeline rules live in this skill file and load automatically via
`/ai-dlc`.

### Rule 2 -- Single conversation is the default

Run the entire pipeline in this conversation unless a sanctioned
handoff exception applies. Handoff triggers:

- (a) **Human-requested handoff** -- the user explicitly asks to
  continue in a new session (directly, or in response to a reminder).
- (b) **Yellow-threshold reminder** (first token threshold crossed) --
  the lead outputs a one-line reminder with routing options;
  non-blocking, user decides.
- (c) **Red-threshold reminder** (degradation-zone token threshold
  crossed) -- the lead outputs a more urgent one-line reminder;
  still non-blocking, still the user's call.
- (d) **Imminent-threshold reminder** (auto-compact is a few turns away)
  -- the lead refreshes the pipeline snapshot so the coming compaction
  recovers from a current record, then reminds in one line. **Still
  non-blocking. Still the user's call.**

Only path (a) initiates a handoff. Paths (b), (c) and (d) are reminders
only. The lead does NOT force handoff at any threshold; critical
operations may require continuing past every reminder threshold,
and the user's judgment is authoritative. Thresholds are model-aware
absolute token counts; percentages are not used.

**A threshold is not a request.** The lead may *name* a handoff as an option;
it may never *take* one.

Reminders (b) and (c) are fired by the `ai-dlc-context-sensor.sh` Stop
hook, which measures resident context from the session transcript on
every turn. The lead neither measures nor estimates its own context.
Reminder text is owned by that hook. Full snapshot structure, recurrence
arithmetic, and auto-handoff configuration live in the two **Handoff
Protocol** sections below and in `gate-validation.md` Check 14.

### Rule 3 -- Never stall the pipeline

The pipeline runs as a continuous, uninterrupted flow. Exactly
FOUR pause points exist where you stop and wait for human input:

- (a) **Ambiguity resolution** (Rule 11).
- (b) **Production Validation Checkpoint** (Rule 10).
- (c) **Retro commentary prompt**.
- (d) **Sprint-scope confirmation** (`route.md` Step 6) -- the only
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
Keep working. Do not ask if you should continue.

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

### Rule 4 -- No step may be skipped regardless of perceived simplicity

When a step file is loaded via "READ AND FOLLOW", execute every
numbered section sequentially. Do not skip sections. Do not jump to
the next step file until the current step's execution sequence is
complete and its gate validation has passed.

"This is simple" is never a valid reason to bypass a step or
sub-step. A step that has nothing to do completes quickly — but it
MUST be loaded (Read tool call per Rule 21) and its execution
sequence MUST run. Skipping validation, Skill invocations, or gate
checks to save time or tokens is a pipeline violation. Violation
fails the next gate unconditionally.

### Rule 5 -- Follow the routing, not your judgment

The pipeline sequence is defined by step file routing ("READ AND
FOLLOW" directives and `nextStepFile` in frontmatter). Do not skip
steps, reorder steps, or jump ahead because a step seems unnecessary.
If a step determines it has nothing to do, it completes quickly --
but it must still be loaded and its checks must still run.

### Rule 6 -- Walk through everything

Do not skip sections. Do not summarize. Review every element of every
artifact exhaustively.

### Rule 7 -- Apply all recommended improvements

When party mode, adversarial review, or advanced elicitation surface
a finding INSIDE the validation cycle, it is fixed directly in the
artifact by the dispatched repair seat -- a `remediator` for planning
artifacts (`_gate-procedures.md`, "Adversarial repair dispatch"), dev
teammates for code -- not inline by the lead. Do not present a menu of
options. Do not ask "should I fix this?" Just dispatch it. After the series
stamps `EXIT_CONDITION_MET`, a finding is DEFERRED to the next step's
artifact or it re-opens the series on this record.

Fixing directly governs disposition, not shape. A finding that adds
mechanism MUST state why a simpler change is insufficient (Rule
26(d)); a finding that removes or simplifies mechanism is applied
with the same directness as one that adds it.

### Rule 8 -- Run the validation cycle per declared intensity

Validation intensity is declared at route time (see route.md Step 6)
and recorded in the pipeline snapshot as `validation_intensity`. The
intensity determines the MINIMUM validation cycle at each planning
phase. The lead MUST NOT run less than the declared minimum. Running
more is always permitted.

| Intensity | Trigger | Minimum cycle per planning artifact |
|---|---|---|
| `full` | ≥3 stories touching service code paths | Party Mode → Advanced Elicitation → Adversarial Review |
| `standard` | 1-2 stories touching service code paths | Party Mode → Adversarial Review |
| `carry-over-single` | carry-over variant with ≤2 stories touching service code paths | Party Mode → Adversarial Review |
| `lightweight` | All stories touch only pipeline-infra paths | Adversarial Review at discovery (or requirements) + stories-test-strategy only |

**The Adversarial Review runs until a pass stamps `EXIT_CONDITION_MET`. That
verdict is the only thing that ends it, and it is honoured the moment it is met,
including at pass 1.** The residue that decides it: `team-roles/adversary.md`.
Pass 2+ reviews the REPAIR, not the document again, and verifies the prior
pass's findings landed.

**Divergence is a HARD_BLOCK, not a reason for another pass.** Pass N+1's
`findings_critical_prior_scope` above pass N's `findings_critical` means the repair
is injecting defects. STOP and escalate. A nonzero MAJOR held at zero CRITICAL across
2+ passes is a STALL, and stops the cycle the same way. CRITICALs in scope ADDED
mid-cycle are NOT divergence: no cycle converges on a growing artifact -- freeze
scope, shrink the sprint, restart. Contract: `team-roles/adversary.md`.

**A stop is not the end of the cycle: STOP -> ADJUDICATE -> RESOLVE -> VERIFY.** A repair
edits the artifact on UNCHANGED scope -- that is what diverged. A RESOLUTION changes what
is under review, is written to a record the gate reads, and is followed by ONE verification
pass in the SAME series. Until that record exists the hooks deny every dispatch. FREEZE is
NOT a resolution. Kinds + procedure: `steps/_gate-procedures.md`.

The per-intensity skips are enforced by each planning step's own
intensity gate, not tracked centrally. Follow each step's gate.

`carry-over-single` may only be assigned to carry-over variants. If
actual story count exceeds 2 at `stories-test-strategy`, intensity MUST
be revised upward to `standard`.

The gate log MUST record the declared intensity and confirm the
minimum was met. A gate that passes under `lightweight` with zero
adversarial passes at discovery (or requirements) is a violation.

Intensity does NOT reduce the following (always required regardless):
- Carry-over eval party mode (evaluates slot/close/defer decisions)
- Story validation party mode (real subagents)
- Adversarial review on stories and sprint output (run it; converge it)
- Deploy-validate smoke test (hard gate, see deploy-validate.md)
- Retro party mode (Rule 20 Skill invocation mandate)

### Rule 9 -- Autonomous gates

At each phase transition, run the gate validation protocol
(`gate-validation.md`). Do not wait for human approval.

### Rule 10 -- Production validation is the only human checkpoint

After deployment and smoke tests, present the Production Validation
Checkpoint to the human. For multi-sprint features (Rule 14), the
checkpoint runs after each sprint; the agent does not proceed to the
next sprint until the human validates the current one.

### Rule 11 -- Seek clarity when ambiguous -- HARD_BLOCK severity

Two observable requirements.

**(a) Ambiguity resolution.** Ask for clarification when you detect
genuine ambiguity in the user's request, requirements, or intent. Do
not ask about matters resolvable by reading existing artifacts,
project memory, or applying professional defaults.

**Put the question to the operator with `AskUserQuestion`, the
recommended option first, and set NO pause flag for it.** The option
constraint on every `AskUserQuestion` is stated in Rule 3's pause-point
section and is not restated here. A question typed as prose at the end
of a reply, followed by ending the turn, reads as narration: the
operator sees a paragraph of recap, not a decision that is theirs to
take, and the decision is never taken. The tool holds the turn open, so
the Stop hook never runs and a flag set here is a pause nobody clears --
the same reason Rule 3 gives for (d).

**(b) In-flight interpretation preamble.** The first line of the
agent's response to ANY user message that arrives during or after an
execution phase MUST be a one-sentence interpretation stating whether
the message is being treated as a question or a directive. Example:
*"Reading this as a question about the escalation decision --
answering below, not acting."* A missing first-line interpretation is
a rule violation, not a soft fail.

**Absolute.** The preamble requirement has no exceptions. "The intent
seems clear" is not a valid reason to skip it. A known degradation
mode in long sessions: as the conversation accumulates execution
turns, the lead starts pattern-matching on recent behavior and
misreads user questions as directives. The preamble requirement is
the mitigation -- forcing the lead to state its interpretation out
loud makes the misread visible before it becomes action.
Rationalizing around this rule is itself the failure mode the rule
catches.

### Rule 12 -- Escalate asynchronously via file

Write escalations to `docs/escalations/pending.md`. Escalations have
three tiers that determine whether work blocks or continues.

**Tier 1 -- HARD_BLOCK (work stops):**
- A finding contradicts an explicit human-approved decision.
- The agent cannot implement a requirement as specified (requirement
  divergence) and needs human sign-off on an alternative approach.
- A carry-over item deferral is proposed (`DEFERRAL_REQUEST`).

Action: mark task BLOCKED, message lead, move to next unblocked task.

**Tier 2 -- DECIDED_AUTONOMOUSLY (work continues):**
- A trade-off has no objectively correct answer; agent picks the best
  option, documents rationale, proceeds.
- Requirements are ambiguous but can be reasonably inferred from
  context, project memory, or existing patterns.
- UI/UX direction decisions where no explicit user preference exists.
- Implementation option selection among alternatives presented in a
  carry-over item or story spec.

Action: document decision and rationale, proceed without blocking.

**Tier 3 -- not an escalation:**
Formatting, naming, phrasing, minor refactors, test structure, or any
issue where a professional default exists. Just do it.

The escalation entry format (append, do not overwrite) and the
resolution lifecycle (how HARD_BLOCK / DEFERRAL_REQUEST / DECIDED
statuses are closed at the production checkpoint) live in
`escalations.md` alongside this file. READ AND FOLLOW it when writing or
resolving an escalation.

When resolving a HARD_BLOCK changes how an acceptance criterion is
verified (moving it between verification categories), the resolution MUST
disclose the change for explicit operator acknowledgement — mechanism in
`escalations.md` "AC verification-category-change disclosure".

### Rule 13 -- Requirements define WHAT; agents have autonomy over HOW

Concrete details specified by carry-over items, brainstorming sessions or direct user instructions are **locked requirements**: validation cycles may challenge them but MUST NOT silently change them, and any divergence requires human sign-off via `HARD_BLOCK` escalation. READ AND FOLLOW `rule-bodies/rule-13.md` before acting under this rule; that file carries the full, binding text of this rule.

**Carrier:** `scripts/ai-dlc/validate-locked-anchor.sh`

### Rule 14 -- Multi-sprint phasing is autonomous

When the agent determines a feature exceeds single-sprint scope due
to size or risk, the agent may autonomously split it into phased
sprints without human approval. Requirements: document the phasing
rationale, define phase boundaries, ensure each phase delivers
standalone value. Each sprint is deployed and validated at the
production checkpoint before the next sprint begins.


**Carrier:** `.claude/skills/ai-dlc/steps/route.md`
<!-- I79: every rule below the re-attach cut declares what mechanically carries it,
     or declares `none` and is counted as a gap. A compacted lead does not hold this
     rule; whatever is named here is what survives instead of its memory. -->
### Rule 15 -- Document what you changed

After each validation cycle, append a brief changelog noting what was improved
and why to `_bmad-output/planning-artifacts/s<N>/changelog-<artifact>.md` -- the
sprint's slot, NEVER the durable artifact. A story's changelog stays inline in the
story, which already carries its sprint in its directory. See `steps/_gate-procedures.md`,
"Where a changelog is written".


**Carrier:** none -- WHETHER a changelog is written is still unmechanised: no gate reads one and no artifact schema holds it. Declared a GAP, not a decision that prose suffices. WHERE it is written is carried, by `tests/fixtures/changelog-sprint-slot/`, which fails if any prescribing site names a durable target again -- that is the path, not the rule.
<!-- I79: every rule below the re-attach cut declares what mechanically carries it,
     or declares `none` and is counted as a gap. A compacted lead does not hold this
     rule; whatever is named here is what survives instead of its memory. -->
### Rule 16 -- Err on the side of doing

When in doubt, apply the improvement. The human reviews the final
production deployment, not intermediate artifacts. "Doing" means the
smallest change that resolves the doubt (Rule 26); this rule is never
license to add mechanism no requirement demands.


**Carrier:** none -- a disposition rule with no observable artifact: acting rather than asking leaves no trace a check could read. Declared a GAP.
<!-- I79: every rule below the re-attach cut declares what mechanically carries it,
     or declares `none` and is counted as a gap. A compacted lead does not hold this
     rule; whatever is named here is what survives instead of its memory. -->
### Rule 17 -- Write large files in sections

When creating or updating a file that exceeds ~200 lines, break the
write into multiple sequential operations. Single large writes risk
output token limits and timeouts that leave files incomplete. Applies
to all file types: planning artifacts, story files, code, tests,
reviews.


**Carrier:** none -- write shape is invisible to every gate; a sectioned write and a single write produce the same file. Declared a GAP.
<!-- I79: every rule below the re-attach cut declares what mechanically carries it,
     or declares `none` and is counted as a gap. A compacted lead does not hold this
     rule; whatever is named here is what survives instead of its memory. -->
### Rule 18 -- Rules are hard, directive, and self-contained

A rule in this skill, CLAUDE.md, coding-conventions.md, step files,
or team role files must be writable as a standalone mandate without
supporting narrative. A rule that needs origin context to survive is
not a rule -- it is a suggestion leaning on a story. Rewrite it hard
or move it to a retro doc as a lesson.

The rule-authoring style guide (imperative voice, forbidden hedges,
enforcement-consequence-inline, scope) and the retro rule-file audit's
three violation classes (narrative drift, rule weakness, complexity
accretion) live in `rule-authoring.md` alongside this file. READ AND
FOLLOW it when authoring or auditing a rule file (`retro.md` Step 4).


**Carrier:** `.claude/skills/ai-dlc/steps/retro.md`
<!-- I79: every rule below the re-attach cut declares what mechanically carries it,
     or declares `none` and is counted as a gap. A compacted lead does not hold this
     rule; whatever is named here is what survives instead of its memory. -->
### Rule 19 -- Agent spawns MUST bind the full role contract

When the lead invokes the `Agent` tool to spawn a teammate, the spawn MUST bind that teammate to its full role contract -- the role file, its rendered definition, and every mandatory binding -- not the model alone. READ AND FOLLOW `rule-bodies/rule-19.md` before acting under this rule; that file carries the full, binding text of this rule.

**Carrier:** `scripts/ai-dlc/validate-spawn-ledger.sh`
<!-- I79: every rule below the re-attach cut declares what mechanically carries it,
     or declares `none` and is counted as a gap. A compacted lead does not hold this
     rule; whatever is named here is what survives instead of its memory. -->
### Rule 20 -- Validation evaluations run in independent subagents with provenance

Validation evaluations -- the four `/bmad-*` sub-skills and the native `ai-dlc-adversary-review` convergence review -- MUST be evaluated by real, independent subagents with `mode: subagent` provenance, never roleplayed solo in the lead's own context. READ AND FOLLOW `rule-bodies/rule-20.md` before acting under this rule; that file carries the full, binding text of this rule.

**Carrier:** `.claude/skills/ai-dlc/steps/_gate-procedures.md`
<!-- I79: every rule below the re-attach cut declares what mechanically carries it,
     or declares `none` and is counted as a gap. A compacted lead does not hold this
     rule; whatever is named here is what survives instead of its memory. -->
### Rule 21 -- READ AND FOLLOW is a Read tool call, not recall

A `READ AND FOLLOW` directive MUST produce a `Read` tool call for the
target step file as the FIRST tool call in the response. No other
action (Bash, Edit, Write, Agent, Skill) before the Read. The lead
MUST NOT substitute memory, prior-session knowledge, or accumulated
context for the Read. The Read tool call is the mechanical
verification that the step was loaded into the current conversation
context. **For `gate-validation.md` alone the Read is SLICED, never
whole**: run `scripts/ai-dlc/gate-slice.sh --type <gate type>`, which
emits the `offset`/`limit` spans covering the `GATE_MANIFEST` universal
row plus the declared type's row, and issue one native `Read` per span.
On a resume after a compaction, pass `--done "$(scripts/ai-dlc/gate-checkpoint.sh
--nonce <gate_nonce> done)"` so checks already verdicted at this nonce
are omitted from the plan. The bounded Read is the compliant Read.

**Each step file carries a `STEP_LOADED_TOKEN` HTML comment** (format:
`<!-- STEP_LOADED_TOKEN: <step-name> -->`). It is a marker, and no gate
reads it. This paragraph used to say the gate log entry MUST cite the
token and that the gate FAILS on a missing citation; nothing ever
implemented either half, and the claim is withdrawn rather than built.
A gate log entry is written by the same lead the rule constrains, so a
token cited there is a SELF-REPORT: the lead this rule exists to catch
— the one that pattern-matches on "I know what this step does" and
skips the Read — writes the token from memory exactly as readily as one
that read the file. The evidence that discriminates is the `Read` tool
call in the transcript, which the checked agent does not author;
`.claude/hooks/ai-dlc-acknowledge.sh` Check 2z consumes it that way for
`route.md`, keyed deliberately on a `file_path` and not on this token.
Extending that shape to the other step files is a separate, larger
change and is not claimed here.

**Sliced loading for `gate-validation.md`.** For
`gate-validation.md` alone, "loaded" does NOT mean the whole file. That
file is sliced by gate type: "loaded" means the **universal core** — the
`GATE_MANIFEST` universal row in `gate-validation.md`, which is the single
source for that set and MUST NOT be re-typed here — **and**
every check the file's `GATE_MANIFEST` marks required for the declared
gate type — that exact set present in context, nothing less. The
invoking step MUST declare the gate type when it says "run gate
validation" (format: `run gate validation [<type>]`, where `<type>` is
one of `planning`, `story`, `implementation`, `sprint-review`, `retro`);
the type is the step's already-known phase, not a new computation. The
file-level `STEP_LOADED_TOKEN` no longer proves completeness (the file
is not read whole), so each check carries its own
`<!-- CHECK_LOADED: <id> -->` anchor and H1 reads the manifest and FAILS
the gate if any required check's anchor is absent — completeness is a
checked invariant, not a trust-the-loader assumption. See
`steps/gate-validation.md` "Gate-type manifest". All OTHER step
files remain whole-file `READ AND FOLLOW` as above.

**The slice is EMITTED, never derived by hand.** `scripts/ai-dlc/gate-slice.sh
--type <type>` resolves the rendered manifest — core's table, or the
`overrides/` entry shadowing it, plus every `extensions/checks/` entry
declaring `gate_types:` — and prints one `offset<TAB>limit<TAB>checks`
row per contiguous span. Issue exactly those Reads, natively; never route
the file through a `ctx_*` tool (Rule 23(c)). It exits 2 rather than
shortening the plan when a required check has no anchor. A consumer
extension's checks are reported as a separate load.

**A gate resumes; it does not restart.** Every check that reaches a
verdict is recorded at once —
`scripts/ai-dlc/gate-checkpoint.sh --nonce <gate_nonce> record <id> <PASS|FAIL|SKIP|PENDING>`
— and a resume after a compaction passes the settled set back as
`--done`. Only `PASS` and `SKIP` narrow a resume. The ledger is keyed on
the nonce; a re-dispatch mints a fresh nonce and reads an empty ledger.
The gate is `open`ed at nonce mint and `close`d after Check 15, and
`scripts/ai-dlc/gate-checkpoint.sh current` names the open nonce — a
resume that finds none resumes no gate.

**Failure mode this prevents.** In hot sessions with many completed
gates, the lead pattern-matches on "I know what this step does" and
skips the Read entirely, executing from memory. The Read tool call
is the interrupt that forces re-engagement with the step's actual
instructions. Memory of a step file is not equivalent to loading it.


**Carrier:** `.claude/skills/ai-dlc/steps/implementation.md`
<!-- I79: every rule below the re-attach cut declares what mechanically carries it,
     or declares `none` and is counted as a gap. A compacted lead does not hold this
     rule; whatever is named here is what survives instead of its memory. -->
### Rule 22 -- Pause-point resume MUST re-read the step file

When a pipeline pause point (Rule 3(a)-(d)) receives human input and
the lead resumes execution, the lead's FIRST action MUST be a `Read`
tool call for the current step file. The lead MUST then enumerate the
remaining numbered sections in output before executing any of them.

This rule generalizes Rule 21's principle to mid-step resume. The
step file is the authority for what remains, not the lead's memory.
"Proceed" after human commentary means "continue the step sequence,"
not "skip to completion." Violation: Rule 4 (every section must
complete). Gate FAILS on detection at retro.


**Carrier:** none -- the post-compact directive names the re-read but nothing verifies it happened; measured at 41% against the snapshot's 66% from the same injected block. Declared a GAP.
<!-- I79: every rule below the re-attach cut declares what mechanically carries it,
     or declares `none` and is counted as a gap. A compacted lead does not hold this
     rule; whatever is named here is what survives instead of its memory. -->
### Rule 23 -- Resident-context discipline

Cache-read cost scales with the size of the working context times the
number of turns it stays resident. Every byte re-injected into context
is re-read on every subsequent turn until compaction. Three controls
keep the resident set lean without weakening step fidelity:

**(a) No redundant re-loads.** Re-Read only the *current* step file
(per Rules 21-22). The lead MUST NOT re-Read a completed step file or
a planning artifact to "refresh" — that permanently duplicates it into
the working context. The pipeline snapshot is the authoritative source
for prior-step state (per the Handoff Protocol); query it instead of
re-loading the producing artifact. State files the gate checks must
re-verify (`gate-log.md`, `pipeline-snapshot.md`) are exempt — their
re-read IS the verification. That exemption is conditional on their
staying small, which is not automatic. The snapshot is the most-read
file in the pipeline (every gate, every resume, every compaction
recovery) and carries the tightest Rule 25(d) threshold of any
artifact. Enforce its schema at each gate rather than letting it
accrete.

**(b) Sliced re-read of large step files.** When a Rule 22 resume
targets a large step file whose earlier numbered sections are already
complete, the lead MAY issue the mandatory `Read` with an `offset` to
the remaining sections rather than the whole file. The Read tool call
— the attention interrupt that defeats run-from-memory — remains
mandatory; only its span narrows. Never slice past a section the lead
has not completed. This applies equally to a POST-COMPACTION resume
that lands inside a gate: the mandated re-read of `gate-validation.md`
is the `gate-slice.sh` plan narrowed by `gate-checkpoint.sh done`
(Rule 21), not the whole file.

**(c) Offload high-volume observational Bash (context-mode).** Large
*read-only* command output (test-suite runs, gate-validation script output,
`git log`/`diff`/`status` inspection, log scans) MUST be run via
`ctx_batch_execute` / `ctx_execute` so its bytes stay out of the resident
prefix. Two hard limits: (1) state-mutating commands (`git`
commit/branch/merge/worktree, `gh`, `chmod`, file writes) MUST run via
native Bash — a context-mode subprocess discards filesystem changes, so
routing a mutation through ctx silently no-ops it; when in doubt whether a
command mutates, use native Bash. (2) Verbatim-load files (rule/step/role
files, schemas, snapshot, `gate-log.md`, escalations, `audit-anchors.md`,
`sprint-status.yaml`, story files) MUST NOT be routed through
`ctx_execute_file` / `ctx_batch_execute` / `ctx_index` — consolidation drops
directives and breaks load fidelity. `ai-dlc-protect.sh` hard-blocks it and
is the SET's source of record: `PROTECTED_PATTERNS` there, extended per
project by `extensions/protected-paths.json`. A directory or glob that spans
one of those files is blocked too. Archives and the planning corpus (`prd.md`,
`product-brief.md`, `carry-over-backlog.md`) are deliberately NOT protected —
offload them freely.


**Carrier:** `.claude/rules/ai-dlc-resident-discipline.md` (floor CC 2.0.64; detector: `.claude/hooks/ai-dlc-rules-floor.sh`, a SessionStart hook that resolves the running version and reports LOUDLY when these files are present but the loader is too old to read them -- gating the COPY was tried first and was wrong, because `apply.sh` is a second copy path that knows nothing about versions and a downgrade is a third) -- an UNCONDITIONAL `.claude/rules/` file, which is re-injected on every compaction (`load_reason:"compact"`, measured). It DUPLICATES this rule rather than replacing it, so below the floor the carrier is absent and this rule is exactly as carried as it was before. The floor is named because a bare `rule-file` here would be a claim nothing can falsify, which is worse than the `none` this line used to read -- measured the sharpest collapse in the band, 13x across a compaction boundary. A PATH-SCOPED rule could not have carried it: the per-session memo SURVIVES compaction, so a scoped rule is gone for the rest of the session once the first one lands. The detector cannot be receipt-only either: a subagent's read writes the same `InstructionsLoaded` receipt a parent's read does, while the parent never receives the rule. Do not mistake `context-mode-protection-log.md` for a carrier: that is an artifact-budget file under Rule 25, and matching its NAME is how a scanner wrongly scores this rule as carried.
<!-- I79: every rule below the re-attach cut declares what mechanically carries it,
     or declares `none` and is counted as a gap. A compacted lead does not hold this
     rule; whatever is named here is what survives instead of its memory. -->
### Rule 24 -- Planning and retro exploration is dispatched to analyst subagents

Read-heavy exploration in the planning and retro steps is the lead's largest avoidable cache-read cost and MUST be dispatched to an `analyst` subagent, whose raw reading never enters the lead's context. READ AND FOLLOW `rule-bodies/rule-24.md` before acting under this rule; that file carries the full, binding text of this rule.

**Carrier:** `scripts/ai-dlc/validate-draft-stamps.sh`
<!-- I79: every rule below the re-attach cut declares what mechanically carries it,
     or declares `none` and is counted as a gap. A compacted lead does not hold this
     rule; whatever is named here is what survives instead of its memory. -->
### Rule 25 -- Artifact-size discipline

Living planning artifacts that grow without bound are the single
largest read cost in the pipeline: a PRD or backlog that accretes every
sprint becomes larger than the context window, so reading it forces
compaction and dominates cache-read. Living artifacts MUST stay
current-state; historical and superseded content MUST move out of the
read path.

**Where an artifact LIVES is a separate rule, and it has one home.** The
path grammar — the directory is the only sprint slot, `<area>/s<N>/`, and
no basename may carry a sprint token — lives in
`artifact-path-grammar.md` alongside this file. READ AND FOLLOW it before
writing a pipeline artifact to a path this rulebook does not already
name — **and before handing a session or run name to a `/bmad-*`
sub-skill, because those compose their own output directory from it and
rule 6 governs that name as a path component.** A basename carrying the sprint forces every reader to SEARCH for
the current one, and search means mtime: that is how both pipeline hooks
came to pick the live adversarial series by modification time across 56
sprints in one directory, and how Check 6 verified two closed sprints
against zero story files.

**(a) Current-state live, history archive — move, never delete.** The
live artifact holds what is *currently true*, consolidated. Superseded
requirement versions and prior per-sprint scope narrative are **moved**
(cut-and-paste, verbatim) to the artifact's history/archive file
(`prd.md` -> `prd-history.md`, `product-brief.md` ->
`product-brief-history.md`, `carry-over-backlog.md` ->
`carry-over-backlog-archive.md`, `architecture.md` ->
`architecture-history.md`). The architecture doc is a living artifact under
this rule like any other: per-sprint addenda and superseded ADRs relocate to
`architecture-history.md` rather than accreting inline (the architecture step
rotates on every update). Nothing is ever dropped — the
union of live and history must preserve every prior requirement and
item. Rule 13 locked requirements are by definition current and are never
relocated out of live. History/archive files are write-only — never
read in the hot path — so their growth is free.

**ONE HISTORY FILE ROTATES, AND IT IS NAMED HERE BECAUSE THE SENTENCE
ABOVE IS OTHERWISE FALSE FOR IT.** `pipeline-snapshot-history.md` is fed
by the trim remedy at *every gate* — route.md Steps 0a and 1a,
`_gate-procedures.md`, Check 14 — not by a sprint close, so it accretes
on a cadence no rotation step bounded. Measured on the reference
consumer: 87 KB to 617 KB across four weeks and 29 commits, every one of
them `del=0`. Append-only held perfectly; nothing was watching the
size. "Never whole-read" was prose with no enforcer, and the only
mechanism that touches it points the other way — `*-history.md` sits in
`ai-dlc-protect.sh`'s `EXCLUDED_PATTERNS`, so a whole Read of that file
is EXPLICITLY ALLOWED and costs ~154k tokens. Rotation is what makes an
accidental read survivable. Entries older than the live window move to
`_bmad-output/pipeline-history/pipeline-snapshot-archive.md` — ONE file,
appended forever, itself unbounded and genuinely free — by
`scripts/ai-dlc/rotate-snapshot-archive.sh`, which is the only writer.
**The archive is load-bearing, not filing.** Check 35's corpus is every
tracked `*.md` in the working tree; on the reference consumer 62 of 89
candidate lines live only in this history, so a rotation whose
destination is ignored or unstaged takes destroyed lines from 17 to 79
against a floor of 40. The rotator refuses an ignored destination and
stages the archive itself for that reason. **No other history or archive
file rotates** — the banners in `ai-dlc-pause.sh` and
`ai-dlc-answer-capture.sh` reading "Rotation: none, ever." still hold
verbatim.

**THE MOVED BLOCK IS HEADED, AND THE HEADING IS A `## ` LINE.** Every
block a move lands in a history/archive file opens with

```
## [MOVED <ISO-8601 timestamp> from <source basename> — <trigger>]
```

**The `## ` is load-bearing.** `rotate-snapshot-archive.sh` cuts at the
Nth-from-last `^## ` line and never interprets a heading, so a block
headed any other way is not a cut point, and moves only when the entry
containing it does.

**(b) Slice-read large sectioned artifacts.** Read the section(s)
relevant to the current scope, not the whole file (Rule 23(b)).
Exception: cross-cutting evaluations that must weigh every item against
the whole requirement set (e.g. `carry-over-evaluation`) read the live
file whole and rely on (a) keeping it bounded — slicing there would
risk missing a cross-reference and mis-deciding.

**That exception is conditional.** A whole-read is licensed ONLY while the
artifact is within its (d) budget. Over budget, the exemption is void —
consolidate first (`artifact-consolidation.md`), then read whole.

**(c) Rotate append-only logs.** `gate-log.md`, the hook-written flow log
`pipeline-continuation-log.md`, the hook-written
`context-mode-protection-log.md`, and similar logs rotate
at epoch/sprint boundaries into
`implementation-artifacts/s<N>/<basename>-archive.md` — the destination
`artifact-path-grammar.md` owns, sprint-keyed by DIRECTORY, never dated in the
basename, because the preamble above makes the directory the only sprint slot.
The live log holds only the current epoch. Verifying an appended entry reads the
**tail**, not the whole file.

**ROTATION HAS TWO SITES AND NAMING ONLY THE FIRST IS WHAT DEADLOCKS A CONSUMER.**
The scheduled rotation is `retro.md` §4b (`pipeline-continuation-log.md`,
`context-mode-protection-log.md`) and §7a-post (`gate-log.md`,
`compaction-log.md`). The UNSCHEDULED one is route.md Step 1a's `rotate` remedy,
which fires when a log has grown past budget with no close in reach — the log
re-fills from hook activity after a retro closes, and a session that reads §4b as
the only sanctioned rotation concludes it cannot start the sprint and cannot
close it either. Step 1a's remedy is a rotation site; see it for which `s<N>`
an inter-sprint epoch takes and why the ordinal is mandatory there.

A log bound by no rotation
step is unbounded: every log is named here explicitly, and (d) is what
catches one this list omits. The escalation log `pending.md` is
bounded the same way: terminal (RESOLVED / OVERRIDDEN) entries move to
`pending-archive.md` at retro close so the gate-read stays scoped to open
escalations — mechanism in `escalations.md` "Terminal-entry archival".

**(d) Size budgets — blocking at sprint start, warn-only at retro.** The
canonical per-artifact budgets and their remedies live in ONE place,
`scripts/ai-dlc/validate-artifact-budget.sh`, which every caller runs rather than
restating (a threshold copied into prose is a threshold that drifts from the one
that executes).

Where it runs decides what it does:

- **Sprint start** (`route.md` Step 1a) — **HARD_BLOCK**.
- **Gate Check 14** — **FAILS the gate** for `pipeline-snapshot.md` alone. The
  snapshot is the one artifact that grows *within* a sprint, and it is re-read at
  every gate, every resume, and every compaction.
- **Retro** (`retro.md` Close-Out Sweep) — **warn-only**. Retro reports, it does
  not gate.

**Warn at 100%, block at 100% + grace** (`AI_DLC_BUDGET_GRACE_PCT`, default 10).
An over-budget artifact is always *reported*; only a breach past the band *blocks*.

Consolidation itself stays operator-invoked (`artifact-consolidation.md`): it is a
fidelity-critical rewrite and must be supervised.


**Carrier:** `scripts/ai-dlc/validate-artifact-budget.sh`
<!-- I79: every rule below the re-attach cut declares what mechanically carries it,
     or declares `none` and is counted as a gap. A compacted lead does not hold this
     rule; whatever is named here is what survives instead of its memory. -->
### Rule 26 -- Minimum mechanism (KISS)

Every produced artifact -- design, code, test, guard, or process
machinery -- MUST use the smallest mechanism that satisfies the
locked requirements and acceptance criteria.

**(a) No speculative mechanism.** MUST NOT add abstractions,
configuration options, fallbacks, guards, or generality for
requirements that do not exist. Unrequested capability is scope
creep, not thoroughness. An abstraction, interface, or
parameterization introduced with exactly one call site violates this
clause unless a second concrete consumer lands in the same story or a
(b) rationale record names it.

**(b) Extend proven paths.** When a working path covers the
requirement, extend it. Each of the following requires documented
rationale -- an ADR at design time, a DECIDED_AUTONOMOUSLY entry
(Rule 12) at implementation time:

- a parallel path beside a proven one: why extension is insufficient;
- a new third-party dependency: what it replaces, and why the standard
  library or an already-present dependency will not do;
- caching, pooling, or any optimization: the measurement that showed
  the need.

**(c) Guard machinery carries a contract.** New guard, gate, hook,
or process machinery MUST state at introduction: the concrete failure
it catches, the cost of a false positive, and the condition under
which it is removed. Machinery that cannot state all three is not
added.

**(d) Simplification is first-class.** Review and validation passes
MUST treat removal and simplification findings as equal in standing
to additions. A finding that adds mechanism MUST state why a simpler
change is insufficient.

**(e) Scope fence.** This rule governs the shape of what is produced.
It never authorizes skipping, thinning, or reordering pipeline steps,
gates, or validation cycles -- Rule 4 is unaffected, and "simple" or
"KISS" is never a reason to bypass a step.

Violation is a MAJOR in adversarial review (`adversary.md`) and a
code-review finding (`code-reviewer.md`); machinery lacking the (c)
contract is flagged by the retro rule-file audit (`retro.md` Step 4).


**Carrier:** `.claude/skills/ai-dlc/steps/gate-validation.md`
<!-- I79: every rule below the re-attach cut declares what mechanically carries it,
     or declares `none` and is counted as a gap. A compacted lead does not hold this
     rule; whatever is named here is what survives instead of its memory. -->
### Rule 27 -- Layered rulebook: core, extensions, overrides

The consumer rulebook is three layers -- core, extensions, overrides -- and a consumer self-improves through the layer contract, never by re-tangling core against upstream. READ AND FOLLOW `rule-bodies/rule-27.md` before acting under this rule; that file carries the full, binding text of this rule.

**Carrier:** `scripts/ai-dlc/validate-layer-entries.sh`
<!-- I79: every rule below the re-attach cut declares what mechanically carries it,
     or declares `none` and is counted as a gap. A compacted lead does not hold this
     rule; whatever is named here is what survives instead of its memory. -->
### Rule 28 -- Delegation is the default; inline execution is the exception

The lead MUST delegate any action a subagent can service; inline execution is permitted only for the non-delegable set. READ AND FOLLOW `rule-bodies/rule-28.md` before acting under this rule; that file carries the full, binding text of this rule.

**Carrier:** `.claude/skills/ai-dlc/steps/implementation.md`
<!-- I79: every rule below the re-attach cut declares what mechanically carries it,
     or declares `none` and is counted as a gap. A compacted lead does not hold this
     rule; whatever is named here is what survives instead of its memory. -->
### Rule 29 -- Steering budget: the operator must always be able to reach you

Claude Code delivers a queued operator message only at a tool-call boundary, so what silences the operator is a long single foreground tool call, and the lead MUST bound foreground call duration within the steering budget. READ AND FOLLOW `rule-bodies/rule-29.md` before acting under this rule; that file carries the full, binding text of this rule.

**Carrier:** `scripts/ai-dlc/validate-steering-budget.sh`
<!-- I79: every rule below the re-attach cut declares what mechanically carries it,
     or declares `none` and is counted as a gap. A compacted lead does not hold this
     rule; whatever is named here is what survives instead of its memory. -->
### Rule 30 -- The spec is BMAD's; the enforcement is ours

Specification artifacts MUST be produced by the BMAD workflows that own them and
MUST NOT be reimplemented in this rulebook: the spec kernel by `bmad-spec`, the
design spine by `bmad-architecture`, epics and the FR coverage map by
`bmad-create-epics-and-stories`, the traceability matrix by
`bmad-testarch-trace`. BMAD is a prerequisite; a second implementation of a
workflow it ships is a parallel path beside a proven one and violates Rule 26(b).

**A BMAD finding is not a BMAD verdict.** `lint_spine.py` exits 0
unconditionally and leaves the call to its caller; `bmad-check-implementation-
readiness` reports uncovered requirements without failing anything;
`bmad-testarch-trace` emits a gate decision that blocks nothing;
`bmad-spec`'s Spec Law is graded by the agent that authored the spec. Every one
of those MUST be adopted by a gate check that can FAIL, and the gate check MUST
re-derive its own judgement rather than adopt a self-declared verdict. A
finding nothing acts on is a finding that reads exactly like a clean run.

**A re-rendered artifact is never an anchor.** `bmad-spec` is the sole writer of
`SPEC.md` and re-derives it from `.memlog.md` on every run, so a byte anchor
there holds until the next derive and then either passes against reworded text or
reports a drift that never happened. Byte anchors (Rule 13, Check 3b) keep
targeting the product brief; a derived artifact — `prd.md`, `SPEC.md`, a spine —
is cited with `requires_context:`, never `full_text_source:`. Anything read for
its ID SET rather than its text may be read anywhere.

**Spec derivation is delegated (Rule 28) and escalated (Rule 19).** It is not
orchestration, routing, or a gate decision, so the lead MUST NOT run it inline;
it routes to `pm-escalated`, whose tier is a property of that role file and not
a call-site argument.

Violation is a MAJOR adversary finding and a `code-reviewer` finding. Retire
this rule if BMAD stops shipping the workflows it names, or starts failing on
its own findings.

**Carrier:** `scripts/ai-dlc/validate-spec-join.sh`
<!-- I79: every rule below the re-attach cut declares what mechanically carries it,
     or declares `none` and is counted as a gap. A compacted lead does not hold this
     rule; whatever is named here is what survives instead of its memory. -->
### Rule 31 -- A countable assertion carries the derivation that produced it

Any sentence asserting a count over a corpus -- "N sites", "all N", "N of M",
"every one of the N" -- MUST carry, in the same block, the command or the
citation set that produced the number. A count authored without one is a fact
the reader cannot check and the author did not run, and it is indistinguishable
from a guess.

**This binds prose, not only acceptance criteria.** A count in a disposition,
scope note, out-of-scope declaration, investigation baseline, or dependency
statement is load-bearing: a reviewer reads it as established and reasons from
it. Prose asserting something about a corpus OUTSIDE the criterion's own test is
where an underived count survives longest, because review passes and mechanical
enforcers alike read criterion bodies hardest and that prose least.

**The derivation MUST test the proposition the sentence asserts.** A citation
that resolves proves its target exists; it does not prove the claim made about
that target. Confirming a range begins where it says it begins does not test the
word "full". Derive the predicate, not the pointer.

**A zero carries a control proving the pattern CAN match.** `grep -c` counts
LINES, not entries; a malformed pattern, a wrong path, and a genuine absence all
return the same zero. Report the count and the control together. Check 12 in
`steps/gate-validation.md` requires this of gate evidence rows; this rule
requires it wherever a number is authored.

**A corrected number puts every artifact stating it inside the blast radius.**
When a repair changes a count, an upstream artifact carrying the same count is
in scope for that repair, not outside it.

**A prescriptive count is not an assertion.** A number specifying what an
implementation or a test MUST do is a requirement and derives nothing. This rule
binds descriptive counts: claims about what a corpus already contains.

Violation is a MAJOR adversary finding and a `code-reviewer` finding.

**Carrier:** none -- no mechanical detector survived its own false-positive
measurement. A block-grain detector for "a cardinal applied to a plural noun
with no command or citation in the same block" was built and run: it fires on a
reconstructed real defect and stays silent on that defect's repair, but it flags
6074 blocks across 890 of 998 story files, it cannot trigger at all on a
non-numeric claim, and it is silent whenever the block carries any unrelated
citation -- which the measured cases satisfy. That last property makes it
passable by adding a citation without making the sentence truer, so it was not
shipped. Declared a GAP.
<!-- I79: every rule below the re-attach cut declares what mechanically carries it,
     or declares `none` and is counted as a gap. A compacted lead does not hold this
     rule; whatever is named here is what survives instead of its memory. -->

## INITIALIZATION

Clear the pipeline pause flag before any other action. The
UserPromptSubmit hook creates `_bmad-output/pipeline-paused.flag` on
every user message, including the `/ai-dlc` invocation itself. If the
flag is not deleted here, the Stop hook will treat the next text-only
response as an intentional pause and allow the pipeline to stall.
Execute: `rm -f _bmad-output/pipeline-paused.flag`

**Load consumer layers (Rule 27).** After this core file, check for the
consumer's additive/shadow layers and load them if present:
`{skill}/extensions/` (additive rules, checks, domain steps) and
`{skill}/overrides/` (entries shadowing a specific core rule/check). Skip
silently if the directories are absent or hold only their `README.md`
scaffold (a fresh install) -- the pipeline then runs pure core. Precedence
when applying: overrides > extensions > core.

Load the router step to determine the pipeline variant and begin
execution:

**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/route.md`
