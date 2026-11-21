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

### Rule 1 -- Retired
No instruction. CLAUDE.md loads on its own for the lead and for every
role whose agent definition does not set `omitClaudeMd`; a role that
sets it Reads `CLAUDE.md` when its brief or step says to. Coding
conventions are `docs/coding-conventions.md`.

### Rule 2 -- Single conversation is the default
Run the entire pipeline in this conversation unless a sanctioned handoff exception applies. Only a human-requested handoff (the user explicitly asks to continue in a new session) initiates one; the yellow, red and imminent token-threshold reminders are non-blocking and the user's call. **A threshold is not a request.** The lead may *name* a handoff as an option; it may never *take* one. READ AND FOLLOW `rule-bodies/rule-2.md` (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`) before acting under this rule; that file carries the full, binding text of this rule.

### Rule 3 -- Never stall the pipeline
The pipeline runs as a continuous, uninterrupted flow. Exactly FOUR pause points exist where you stop and wait for human input: (a) ambiguity resolution and operator-only decisions (Rule 11), (b) the Production Validation Checkpoint (Rule 10), (c) the retro commentary prompt, (d) sprint-scope confirmation. At (b), (c) and any terminal STOP that awaits a human, `touch _bmad-output/pipeline-paused.flag` before ending the turn; (a) and (d) set NO flag. Every `AskUserQuestion` carries 2-4 options per question.

### Rule 4 -- No step may be skipped regardless of perceived simplicity
When a step file is loaded via "READ AND FOLLOW", execute every numbered section sequentially. Do not skip sections, and do not jump to the next step file until the current step's execution sequence is complete and its gate validation has passed. "This is simple" is never a valid reason to bypass a step or sub-step. A step that has nothing to do completes quickly — but it MUST be loaded (Read tool call per Rule 21) and its execution sequence MUST run. Skipping validation, Skill invocations, or gate checks to save time or tokens is a pipeline violation. The sequence is the step-file routing, not your judgment: do not reorder steps or jump ahead. READ AND FOLLOW `rule-bodies/rule-4.md` (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`) before acting under this rule; that file carries the full, binding text of this rule.

### Rule 5 -- Follow the routing
Rule 4. READ AND FOLLOW `rule-bodies/rule-5.md` (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`) before acting under this rule; that file carries the full, binding text of this rule.

### Rule 6 -- Walk through everything
Rule 4. READ AND FOLLOW `rule-bodies/rule-6.md` (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`) before acting under this rule; that file carries the full, binding text of this rule.

### Rule 7 -- Apply all recommended improvements
A finding that party mode, adversarial review or advanced elicitation surfaces INSIDE the validation cycle is fixed directly in the artifact by the dispatched repair seat -- a `remediator` for planning artifacts, dev teammates for code -- not inline by the lead. Do not present a menu of options and do not ask "should I fix this?": dispatch it. After the series stamps `EXIT_CONDITION_MET`, a finding is DEFERRED to the next step's artifact or it re-opens the series on this record. A finding that adds mechanism MUST state why a simpler change is insufficient (Rule 26(d)). READ AND FOLLOW `rule-bodies/rule-7.md` (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`) before acting under this rule; that file carries the full, binding text of this rule.

### Rule 8 -- Run the validation cycle per declared intensity
Validation intensity is declared at route time and recorded in the pipeline snapshot as `validation_intensity`; it determines the MINIMUM validation cycle at each planning artifact, and the lead MUST NOT run less than the declared minimum (`test-strategy.md` alone runs the convergence review only). Running more is always permitted.

### Rule 9 -- Autonomous gates
Rule 3. READ AND FOLLOW `rule-bodies/rule-9.md` (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`) before acting under this rule; that file carries the full, binding text of this rule.

### Rule 10 -- Production validation is the only human checkpoint
After deployment and smoke tests, present the Production Validation Checkpoint to the human. For multi-sprint features (Rule 14), the checkpoint runs after each sprint; the agent does not proceed to the next sprint until the human validates the current one. READ AND FOLLOW `rule-bodies/rule-10.md` (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`) before acting under this rule; that file carries the full, binding text of this rule.

### Rule 11 -- Seek clarity when ambiguous -- HARD_BLOCK severity
Two observable requirements. **(a) Ambiguity resolution.** Ask for clarification on genuine ambiguity in the user's request, requirements or intent, never about matters resolvable by reading artifacts, project memory or professional defaults. Put the question to the operator with `AskUserQuestion`, the recommended option first unless the question is unbadged, and set NO pause flag for it. Before any question reaches the operator: search the recorded prior answers, derive what the tree or config can give, gloss every project-internal id in plain language, and dispatch ready work, then ask.

### Rule 12 -- Escalate asynchronously via file
Write escalations to `docs/escalations/pending.md`. **Tier 1 -- HARD_BLOCK (work stops):** a finding contradicts an explicit human-approved decision, a requirement cannot be implemented as specified, or a carry-over deferral is proposed; mark the task BLOCKED, message the lead (a teammate: `SendMessage` `to: "main"`), move to the next unblocked task. **Tier 2 -- DECIDED_AUTONOMOUSLY (work continues):** document the decision and rationale and proceed; the Tier 2 bullets yield to Rule 11(a)'s sort before asking. **Tier 3 -- not an escalation:** just do it. READ AND FOLLOW `rule-bodies/rule-12.md` (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`) before acting under this rule; that file carries the full, binding text of this rule.

### Rule 13 -- Requirements define WHAT; agents have autonomy over HOW
Concrete details specified by carry-over items, brainstorming sessions or direct user instructions are **locked requirements**: validation cycles may challenge them but MUST NOT silently change them, and any divergence requires human sign-off via `HARD_BLOCK` escalation. READ AND FOLLOW `rule-bodies/rule-13.md` (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`) before acting under this rule; that file carries the full, binding text of this rule.

### Rule 14 -- Multi-sprint phasing is autonomous
When the agent determines a feature exceeds single-sprint scope due
to size or risk, the agent may autonomously split it into phased
sprints without human approval. Requirements: document the phasing
rationale, define phase boundaries, ensure each phase delivers
standalone value. Each sprint is deployed and validated at the
production checkpoint before the next sprint begins.
READ AND FOLLOW `rule-bodies/rule-14.md` (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`) before acting under this rule; that file carries the full, binding text of this rule.

### Rule 15 -- Document what you changed
After each validation cycle, append a brief changelog noting what was improved
and why to `_bmad-output/planning-artifacts/s<N>/changelog-<artifact>.md` -- the
sprint's slot, NEVER the durable artifact. A story's changelog stays inline in the
story, which already carries its sprint in its directory. See `steps/_gate-procedures.md`,
"Where a changelog is written".
READ AND FOLLOW `rule-bodies/rule-15.md` (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`) before acting under this rule; that file carries the full, binding text of this rule.

### Rule 16 -- Err on the side of doing
When in doubt, apply the improvement. The human reviews the final
production deployment, not intermediate artifacts. "Doing" means the
smallest change that resolves the doubt (Rule 26); this rule is never
license to add mechanism no requirement demands.
READ AND FOLLOW `rule-bodies/rule-16.md` (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`) before acting under this rule; that file carries the full, binding text of this rule.

### Rule 17 -- Write large files in sections
When creating or updating a file that exceeds ~200 lines, break the
write into multiple sequential operations. Single large writes risk
output token limits and timeouts that leave files incomplete. Applies
to all file types: planning artifacts, story files, code, tests,
reviews.
READ AND FOLLOW `rule-bodies/rule-17.md` (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`) before acting under this rule; that file carries the full, binding text of this rule.

### Rule 18 -- Rules are hard, directive, and self-contained
A rule in this skill, CLAUDE.md, coding-conventions.md, step files,
or team role files must be writable as a standalone mandate without
supporting narrative. A rule that needs origin context to survive is
not a rule -- it is a suggestion leaning on a story. Rewrite it hard
or move it to a retro doc as a lesson.
READ AND FOLLOW `rule-bodies/rule-18.md` (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`) before acting under this rule; that file carries the full, binding text of this rule.

### Rule 19 -- Agent spawns MUST bind the full role contract
When the lead invokes the `Agent` tool to spawn a teammate, the spawn MUST bind that teammate to its full role contract -- the role file, its rendered definition, and every mandatory binding -- not the model alone. READ AND FOLLOW `rule-bodies/rule-19.md` (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`) before acting under this rule; that file carries the full, binding text of this rule.

### Rule 20 -- Validation evaluations run in independent subagents with provenance
Validation evaluations -- the four `/bmad-*` sub-skills and the native `ai-dlc-adversary-review` convergence review -- MUST be evaluated by real, independent subagents with `mode: subagent` provenance, never roleplayed solo in the lead's own context. READ AND FOLLOW `rule-bodies/rule-20.md` (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`) before acting under this rule; that file carries the full, binding text of this rule.

### Rule 21 -- READ AND FOLLOW is a Read tool call, not recall
A `READ AND FOLLOW` directive MUST produce a `Read` tool call (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`) for the target step file as the FIRST tool call in the response; no other action before the Read, and memory is never a substitute. For `gate-validation.md` alone the Read is SLICED: run `scripts/ai-dlc/gate-slice.sh --type <gate type>` and issue one native `Read` per emitted span. A gate resumes, it does not restart: record each verdict with `scripts/ai-dlc/gate-checkpoint.sh --nonce <gate_nonce> record <id> <PASS|FAIL|SKIP|PENDING>`. READ AND FOLLOW `rule-bodies/rule-21.md` (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`) before acting under this rule; that file carries the full, binding text of this rule.

### Rule 22 -- Pause-point resume MUST re-read the step file
When a pipeline pause point (Rule 3(a)-(d)) receives human input and
the lead resumes execution, the lead's FIRST action MUST be a `Read`
tool call for the current step file. The lead MUST then enumerate the
remaining numbered sections in output before executing any of them.
READ AND FOLLOW `rule-bodies/rule-22.md` (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`) before acting under this rule; that file carries the full, binding text of this rule.

### Rule 23 -- Resident-context discipline
Cache-read cost scales with the size of the working context times the
number of turns it stays resident. Every byte re-injected into context
is re-read on every subsequent turn until compaction. Three controls
keep the resident set lean without weakening step fidelity.
READ AND FOLLOW `rule-bodies/rule-23.md` (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`) before acting under this rule; that file carries the full, binding text of this rule.

### Rule 24 -- Planning and retro exploration is dispatched to analyst subagents
Read-heavy exploration in the planning and retro steps is the lead's largest avoidable cache-read cost and MUST be dispatched to an `analyst` subagent, whose raw reading never enters the lead's context. READ AND FOLLOW `rule-bodies/rule-24.md` (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`) before acting under this rule; that file carries the full, binding text of this rule.

### Rule 25 -- Artifact-size discipline
Living planning artifacts that grow without bound are the single
largest read cost in the pipeline: a PRD or backlog that accretes every
sprint becomes larger than the context window, so reading it forces
compaction and dominates cache-read. Living artifacts MUST stay
current-state; historical and superseded content MUST move out of the
read path.
READ AND FOLLOW `rule-bodies/rule-25.md` (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`) before acting under this rule; that file carries the full, binding text of this rule.

### Rule 26 -- Minimum mechanism (KISS)
Every produced artifact -- design, code, test, guard, or process
machinery -- MUST use the smallest mechanism that satisfies the
locked requirements and acceptance criteria.
READ AND FOLLOW `rule-bodies/rule-26.md` (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`) before acting under this rule; that file carries the full, binding text of this rule.

### Rule 27 -- Layered rulebook: core, extensions, overrides
The consumer rulebook is three layers -- core, extensions, overrides -- and a consumer self-improves through the layer contract, never by re-tangling core against upstream. READ AND FOLLOW `rule-bodies/rule-27.md` (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`) before acting under this rule; that file carries the full, binding text of this rule.

### Rule 28 -- Delegation is the default; inline execution is the exception
The lead MUST delegate any action a subagent can service; inline execution is permitted only for the non-delegable set. READ AND FOLLOW `rule-bodies/rule-28.md` (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`) before acting under this rule; that file carries the full, binding text of this rule.

### Rule 29 -- Steering budget: the operator must always be able to reach you
Claude Code delivers a queued operator message only at a tool-call boundary, so what silences the operator is a long single foreground tool call, and the lead MUST bound foreground call duration within the steering budget. READ AND FOLLOW `rule-bodies/rule-29.md` (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`) before acting under this rule; that file carries the full, binding text of this rule.

### Rule 30 -- The spec is BMAD's; the enforcement is ours
Specification artifacts MUST be produced by the BMAD workflows that own them and
MUST NOT be reimplemented in this rulebook: the spec kernel by `bmad-spec`, the
design spine by `bmad-architecture`, and epics and the FR coverage map by
`bmad-create-epics-and-stories`. BMAD is a prerequisite; a second implementation of a
workflow it ships is a parallel path beside a proven one and violates Rule 26(b).
READ AND FOLLOW `rule-bodies/rule-30.md` (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`) before acting under this rule; that file carries the full, binding text of this rule.

### Rule 31 -- A countable assertion carries the derivation that produced it
Any sentence asserting a count over a corpus -- "N sites", "all N", "N of M",
"every one of the N" -- MUST carry, in the same block, the command or the
citation set that produced the number. A count authored without one is a fact
the reader cannot check and the author did not run, and it is indistinguishable
from a guess.
READ AND FOLLOW `rule-bodies/rule-31.md` (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`) before acting under this rule; that file carries the full, binding text of this rule.

### Rule 32 -- Consult the advisor tool at named touchpoints when it is available
When the harness gives you an `advisor` tool, you MUST call it at each touchpoint below; it
takes no parameters and forwards your whole transcript to a separate reviewer. When it does not
but you hold `mcp__advisor__consult`, call that tool at the same touchpoints instead; while you
hold the built-in tool, a consult does not count. If you hold neither, or a call returns an
error, continue without it -- a missing or failed advisor never blocks, delays or fails a step.
The touchpoints:
- **R -- post-compact recovery.** After the `postcompact-digest.md` Read, and after arming any
  fresh beat the In-Flight Teammates rows require (`run_in_background: true`), then call the
  advisor in the same turn, before your first dispatch or write.
- **G1 -- every gate, at entry.** Before the script arms run (`steps/gate-validation.md`).
- **G2 -- every gate, before it closes.** Before `gate-checkpoint.sh --nonce <gate_nonce> close`.
- **V1 -- validation cycle, after a repair.** After a repair record is joined and before the
  next pass is dispatched (`steps/_gate-procedures.md`, Validation cycle).
- **V2 -- a verdict and a validator disagree.** When a pass verdict and a validator's result
  disagree, before acting on either.
- **P -- a validation-cycle teammate is slow.** On the beat whose `WAITING` line reports
  `beat 2/` for a validation-cycle deliverable, re-arm the next beat (`run_in_background:
  true`) FIRST, then call the advisor in the same turn. Once per pass, never once per beat.
- **I -- before an irreversible step.** Before a push, a merge or a deploy, call the advisor
  in a message of its own and read its answer, unless an advisor attempt already falls inside
  the window of `ai-dlc-advisor-gate.sh` (`ADVISOR_GATE_WINDOW`, default 10, counted in
  assistant messages with the current one as the first). One consult covers every push, merge
  and deploy inside that window, the deploy included though the hook does not gate it, unless
  its answer objected or left an objection open, or what ships changed since (a commit merged
  that the consult did not see, a red smoke). With none inside the window a consult is owed, which is stricter than
  the hook's per-kind test. Then issue the push, merge or deploy.

## INITIALIZATION
Clear the pipeline pause flag before any other action. The
UserPromptSubmit hook creates `_bmad-output/pipeline-paused.flag` on
every user message, including the `/ai-dlc` invocation itself. If the
flag is not deleted here, the Stop hook will treat the next text-only
response as an intentional pause and allow the pipeline to stall.
Run `rm -f _bmad-output/pipeline-paused.flag` as its own Bash call, with nothing chained before or after it,
then run `[ ! -e _bmad-output/pipeline-paused.flag ]` as a separate call that must exit 0 before anything advances;
on a non-zero exit, repeat the rm alone. A denied call runs none of its parts.
<!-- END GENERATED: postcompact-digest -->

