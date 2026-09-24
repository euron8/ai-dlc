# Post-compact rulebook digest

A compaction re-attaches only the first ~5,000 tokens of `SKILL.md` — under a fifth of it.
Nothing marks where the cut fell, the surviving text ends mid-file without a seam, and the
rules that govern re-reading are themselves past it. This file is what is on the other side.

**Every line in the generated region below is `SKILL.md`'s own text.** It is selected, never
summarised and never rewritten: each heading past the cut with its normative opening, and
where that opening announces a list, the list. `scripts/render-postcompact-digest.sh --check`
fails the push if it drifts from `SKILL.md` by one byte.

**This is the rulebook's INDEX, not the rulebook.** It carries what every rule past the cut
governs and the operative core of each. It does not carry the worked examples, the thresholds
tables, the sub-clauses below the first, or the rationale.

**So: before you act on a rule you find here, `Read .claude/skills/ai-dlc/SKILL.md` for that
rule's full text.** A heading is enough to know a rule binds you and enough to know you do not
hold it; it is not enough to apply it. Reading the entry and proceeding as though you had read
the rule is the one way this file makes things worse than the full read it replaces.

The rules that survive the cut are in your context already and are not repeated here.

## The rulebook past the re-attach cut

<!-- BEGIN GENERATED: postcompact-digest — source: SKILL.md past the re-attach cut -->
DERIVED from `SKILL.md` past the 20121-byte re-attach cut. Do not hand-edit: run
`scripts/render-postcompact-digest.sh --write`. Every line below is SKILL.md's own
text, selected — never summarised, never rewritten.

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

### Rule 3 -- Never stall the pipeline
The pipeline runs as a continuous, uninterrupted flow. Exactly
FOUR pause points exist where you stop and wait for human input:
- (a) **Ambiguity resolution and operator-only decisions** (Rule 11).
- (b) **Production Validation Checkpoint** (Rule 10).
- (c) **Retro commentary prompt**.
- (d) **Sprint-scope confirmation** (`route.md` Step 6) -- the only
  pause point upstream of planning. Confirm or correct the scope you
  already resolved; it is never a question about what to build.

### Rule 4 -- No step may be skipped regardless of perceived simplicity
When a step file is loaded via "READ AND FOLLOW", execute every
numbered section sequentially. Do not skip sections. Do not jump to
the next step file until the current step's execution sequence is
complete and its gate validation has passed.

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

### Rule 8 -- Run the validation cycle per declared intensity
Validation intensity is declared at route time (see route.md Step 6)
and recorded in the pipeline snapshot as `validation_intensity`. The
intensity determines the MINIMUM validation cycle at each planning
phase. The lead MUST NOT run less than the declared minimum. Running
more is always permitted.

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

### Rule 12 -- Escalate asynchronously via file
Write escalations to `docs/escalations/pending.md`. Escalations have
three tiers that determine whether work blocks or continues.

### Rule 13 -- Requirements define WHAT; agents have autonomy over HOW
Concrete details specified by carry-over items, brainstorming sessions or direct user instructions are **locked requirements**: validation cycles may challenge them but MUST NOT silently change them, and any divergence requires human sign-off via `HARD_BLOCK` escalation. READ AND FOLLOW `rule-bodies/rule-13.md` before acting under this rule; that file carries the full, binding text of this rule.

### Rule 14 -- Multi-sprint phasing is autonomous
When the agent determines a feature exceeds single-sprint scope due
to size or risk, the agent may autonomously split it into phased
sprints without human approval. Requirements: document the phasing
rationale, define phase boundaries, ensure each phase delivers
standalone value. Each sprint is deployed and validated at the
production checkpoint before the next sprint begins.

### Rule 15 -- Document what you changed
After each validation cycle, append a brief changelog noting what was improved
and why to `_bmad-output/planning-artifacts/s<N>/changelog-<artifact>.md` -- the
sprint's slot, NEVER the durable artifact. A story's changelog stays inline in the
story, which already carries its sprint in its directory. See `steps/_gate-procedures.md`,
"Where a changelog is written".

### Rule 16 -- Err on the side of doing
When in doubt, apply the improvement. The human reviews the final
production deployment, not intermediate artifacts. "Doing" means the
smallest change that resolves the doubt (Rule 26); this rule is never
license to add mechanism no requirement demands.

### Rule 17 -- Write large files in sections
When creating or updating a file that exceeds ~200 lines, break the
write into multiple sequential operations. Single large writes risk
output token limits and timeouts that leave files incomplete. Applies
to all file types: planning artifacts, story files, code, tests,
reviews.

### Rule 18 -- Rules are hard, directive, and self-contained
A rule in this skill, CLAUDE.md, coding-conventions.md, step files,
or team role files must be writable as a standalone mandate without
supporting narrative. A rule that needs origin context to survive is
not a rule -- it is a suggestion leaning on a story. Rewrite it hard
or move it to a retro doc as a lesson.

### Rule 19 -- Agent spawns MUST bind the full role contract
When the lead invokes the `Agent` tool to spawn a teammate, the spawn MUST bind that teammate to its full role contract -- the role file, its rendered definition, and every mandatory binding -- not the model alone. READ AND FOLLOW `rule-bodies/rule-19.md` before acting under this rule; that file carries the full, binding text of this rule.

### Rule 20 -- Validation evaluations run in independent subagents with provenance
Validation evaluations -- the four `/bmad-*` sub-skills and the native `ai-dlc-adversary-review` convergence review -- MUST be evaluated by real, independent subagents with `mode: subagent` provenance, never roleplayed solo in the lead's own context. READ AND FOLLOW `rule-bodies/rule-20.md` before acting under this rule; that file carries the full, binding text of this rule.

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

### Rule 22 -- Pause-point resume MUST re-read the step file
When a pipeline pause point (Rule 3(a)-(d)) receives human input and
the lead resumes execution, the lead's FIRST action MUST be a `Read`
tool call for the current step file. The lead MUST then enumerate the
remaining numbered sections in output before executing any of them.

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

### Rule 25 -- Artifact-size discipline
Living planning artifacts that grow without bound are the single
largest read cost in the pipeline: a PRD or backlog that accretes every
sprint becomes larger than the context window, so reading it forces
compaction and dominates cache-read. Living artifacts MUST stay
current-state; historical and superseded content MUST move out of the
read path.

## [MOVED <ISO-8601 timestamp> from <source basename> — <trigger>]
```

### Rule 26 -- Minimum mechanism (KISS)
Every produced artifact -- design, code, test, guard, or process
machinery -- MUST use the smallest mechanism that satisfies the
locked requirements and acceptance criteria.

### Rule 27 -- Layered rulebook: core, extensions, overrides
The consumer rulebook is three layers -- core, extensions, overrides -- and a consumer self-improves through the layer contract, never by re-tangling core against upstream. READ AND FOLLOW `rule-bodies/rule-27.md` before acting under this rule; that file carries the full, binding text of this rule.

### Rule 28 -- Delegation is the default; inline execution is the exception
The lead MUST delegate any action a subagent can service; inline execution is permitted only for the non-delegable set. READ AND FOLLOW `rule-bodies/rule-28.md` before acting under this rule; that file carries the full, binding text of this rule.

### Rule 29 -- Steering budget: the operator must always be able to reach you
Claude Code delivers a queued operator message only at a tool-call boundary, so what silences the operator is a long single foreground tool call, and the lead MUST bound foreground call duration within the steering budget. READ AND FOLLOW `rule-bodies/rule-29.md` before acting under this rule; that file carries the full, binding text of this rule.

### Rule 30 -- The spec is BMAD's; the enforcement is ours
Specification artifacts MUST be produced by the BMAD workflows that own them and
MUST NOT be reimplemented in this rulebook: the spec kernel by `bmad-spec`, the
design spine by `bmad-architecture`, epics and the FR coverage map by
`bmad-create-epics-and-stories`, the traceability matrix by
`bmad-testarch-trace`. BMAD is a prerequisite; a second implementation of a
workflow it ships is a parallel path beside a proven one and violates Rule 26(b).

### Rule 31 -- A countable assertion carries the derivation that produced it
Any sentence asserting a count over a corpus -- "N sites", "all N", "N of M",
"every one of the N" -- MUST carry, in the same block, the command or the
citation set that produced the number. A count authored without one is a fact
the reader cannot check and the author did not run, and it is indistinguishable
from a guess.

## INITIALIZATION
Clear the pipeline pause flag before any other action. The
UserPromptSubmit hook creates `_bmad-output/pipeline-paused.flag` on
every user message, including the `/ai-dlc` invocation itself. If the
flag is not deleted here, the Stop hook will treat the next text-only
response as an intentional pause and allow the pipeline to stall.
Execute: `rm -f _bmad-output/pipeline-paused.flag`
<!-- END GENERATED: postcompact-digest -->

