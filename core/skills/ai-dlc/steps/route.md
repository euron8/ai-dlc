---
name: route
description: Detect pipeline variant from project state and user input, compose step sequence
nextStepFile: dynamically determined by routing logic
---
<!-- STEP_LOADED_TOKEN: route -->

# AI/DLC Router

## STATE VARIABLES
- `user_input`: The user's original request text
- `pipeline_variant`: One of [greenfield, feature, bug, carry-over, sprint-execute, brownfield-a, brownfield-b, brownfield-c, analysis-only]
- `has_product_brief`: boolean
- `has_prd`: boolean
- `has_architecture`: boolean
- `has_stories`: boolean
- `has_carry_over_items`: boolean
- `has_ready_sprint`: boolean (stories exist with status ready-for-dev or in-progress)
- `is_ui_epic`: boolean (determined during planning, not routing)

## EXECUTION SEQUENCE

### Step 0: Resume Check

Before running the full routing sequence, check for an existing
pipeline snapshot that indicates a resume from a previous session.

1. Check if `_bmad-output/pipeline-snapshot.md` exists and is non-empty.
2. If YES and the user input contains a resume signal — begins with
   "Resuming an ai-dlc sprint" OR explicitly references "pipeline
   snapshot" — this is a resume. **Before dispatching, run Step 0a
   snapshot integrity validation below.** If integrity validation
   passes:
   - Read the snapshot's **Pipeline Position** section to determine
     `current_step_file`.
   - Acknowledge the resume in the first output line:
     *"Resuming from snapshot at `{current_step_file}`."*
   - Skip the rest of this routing sequence. Steps 1–6 are for fresh
     pipeline starts; on resume they would misclassify the input and
     overwrite the snapshot.
   - **READ AND FOLLOW** the step file named in `current_step_file`:
     `{project-root}/.claude/skills/ai-dlc/steps/{current_step_file}`
   - The snapshot is already current (kept fresh by
     `gate-validation.md` Check 14 on each gate passage throughout the
     previous session); do NOT re-initialize it.
3. If the snapshot exists but user input does NOT indicate a resume
   (e.g., the user is starting a new feature while an old snapshot
   remains on disk from a previous pipeline run), continue to Step 1.
   Step 6 will detect the stale snapshot and archive it before
   creating a new one.
4. If no snapshot exists, continue to Step 1 normally.

### Step 0a: Snapshot Integrity Validation (resume dispatch only)

This sub-step runs only when Step 0 path 2 is taken (a resume). Do
NOT silently dispatch to `current_step_file` if any check below
fails. Surface the specific failure to the user with a proposed
remediation and wait for direction.

**On any failure, create the pause flag before surfacing:**
`touch _bmad-output/pipeline-paused.flag`. Waiting for direction is
an intentional pause, and the Stop hook only recognizes one by that
flag. The `/ai-dlc` invocation deleted it (see SKILL.md, "Clear the
pipeline pause flag before any other action"), so without this the
Stop hook treats the failure message as a Rule 3 stall and returns a
forced-continuation reason that argues for pairing the text with a
tool call -- pressuring the lead toward the very dispatch this
sub-step exists to prevent. The flag also lets
`ai-dlc-driver-signal.sh` emit `.driver/idle`, which parks an
auto-chained session for the operator instead of leaving it blocked.
The lead clears the flag when the user directs the resume.

Run these integrity checks in order:

1. **Required sections present.** Confirm the snapshot contains all
   six load-bearing sections by heading:
   - `Pipeline Position`
   - `Sprint Context`
   - `Recent Activity`
   - `Open Items`
   - `Locked Decisions`
   - `Context Reminders`

   If any section is missing, FAIL with:
   > *"Snapshot at `_bmad-output/pipeline-snapshot.md` is missing
   > section(s): [list]. Resume is unsafe. Reply `archive` to move
   > this snapshot aside and start fresh, `edit` to have me fill in
   > the missing sections from git history, or `abort` to stop."*

   **`In-Flight Teammates` is the seventh section and AUTO-HEALS — it
   does NOT fail this check.** If absent, create it empty, say so in one
   line, and continue. Its absence is unambiguous (a snapshot predating
   the section recorded no teammates, and empty is the correct default),
   so failing on it would strand every snapshot written by a prior
   version. The other six carry state no default can reconstruct, which
   is why they still FAIL.

2. **`current_step_file` exists on disk.** Read the Pipeline Position
   section and resolve `current_step_file` to
   `{project-root}/.claude/skills/ai-dlc/steps/{current_step_file}`.
   If the file does not exist, FAIL with:
   > *"Snapshot references `current_step_file: {value}` but that
   > step file does not exist. Resume cannot dispatch. Reply
   > `archive`, `override <correct-step-file>`, or `abort`."*

3. **Git branch match.** Run `git branch --show-current`. Read the
   branch recorded in the snapshot (in Pipeline Position or Recent
   Activity). If the current branch does not match, do NOT silently
   resume on the wrong branch:
   > *"Snapshot was finalized on branch `{snapshot_branch}` but
   > current branch is `{current_branch}`. Reply `switch` to
   > `git checkout {snapshot_branch}` and resume, `continue-here`
   > to resume on the current branch (I will update the snapshot's
   > branch field), or `abort`."*

4. **`last_gate_passed` recency.** Parse the timestamp from the
   `last_gate_passed` field. If more than 7 days old relative to
   today's date, surface a warning (not a hard fail):
   > *"Warning: snapshot's last gate was {days} days ago. Pipeline
   > state may be stale relative to the code and external systems.
   > Reply `proceed` to resume as-is, `archive` to start fresh, or
   > provide additional context."*

   Wait for the user's reply before dispatching.

If all four checks pass (integrity verified, branch matches or user
confirmed, recency acceptable), continue with the Step 0 path 2
dispatch. Otherwise the user's reply directs the next action.

### Step 1: Read Project State

Check for existing artifacts on disk:

1. Check `_bmad-output/planning-artifacts/product-brief.md` — exists and non-empty?
2. Check `_bmad-output/planning-artifacts/prd.md` — exists and non-empty?
3. Check `docs/architecture.md` or `_bmad-output/planning-artifacts/architecture.md` — exists?
4. Check `_bmad-output/planning-artifacts/stories/` — any story files exist?
5. Check `_bmad-output/planning-artifacts/carry-over-backlog.md` — any OPEN items?
6. Read `_bmad-output/planning-artifacts/sprint-status.yaml` if it exists — current sprint state?
7. Read CLAUDE.md for project rules and conventions.

### Step 1a: Artifact-Size Budget Gate (Rule 25(d)) — HARD_BLOCK

Run `scripts/validate-artifact-budget.sh`.

**Exit 0** — every living artifact is within budget. Continue to Step 2.

**Exit 1** — one or more artifacts are over budget. **HARD_BLOCK. Do not start the
sprint.** Present the script's output to the operator, and apply the remedy the
script names per artifact — they are not interchangeable:

- `consolidate` → the operator runs `artifact-consolidation.md` (a
  fidelity-critical rewrite; it is supervised, never automatic).
- `rotate` → a rotation was **missed**. Move the epoch to a dated archive
  (Rule 25(c)). Never rewrite a log.
- `trim` → trim `pipeline-snapshot.md` to its seven-section schema (Rule 25(a)).

Then re-run the script. It must exit 0 before the sprint proceeds.

### Step 2: Analyze User Input

Classify the user's request:

- **Sprint-execute signal**: Input mentions "implement the sprint",
  "execute the sprint", "run the stories", "pick up implementation",
  "start building", or sprint-status.yaml shows stories in ready-for-dev
  or in-progress status AND user does not describe a new feature/bug.
- **Bug signal**: Input describes the system behaving contrary to intent —
  a failure, a misreport, wrong/stale/incorrect values, a regression,
  "stopped working", "started after a deploy", or any unexpected behavior.
  The literal tokens "fix", "bug", "broken", "wrong", "error", "doesn't work"
  are sufficient but NOT necessary: keyword absence is not signal absence. A
  production-defect description is a bug signal whatever words carry it —
  and that includes a defect described *inside* a carry-over/backlog item.
  Arriving as an operator-dispositioned backlog entry does not neutralize a
  defect; the content is classified on its substance, not its envelope.
- **Feature signal**: Input describes new capability, enhancement, addition,
  or references a feature spec / escalation doc.
- **Carry-over signal**: Input mentions "carry-over", "backlog", "next sprint",
  or no specific feature — just "run the next sprint".
- **Analysis signal**: Input mentions "analyze", "document", "understand",
  "inventory", "what does this codebase do" without mentioning building anything.
- **Greenfield signal**: No trusted artifacts exist AND input describes
  something to build.

### Step 3: Route to Pipeline Variant

Apply the following decision tree:

```
Is there a planned sprint with stories ready for implementation?
  (has_ready_sprint AND user signals "implement", "execute", "run sprint",
   "start building", or does not describe a new feature/bug)
  YES → pipeline_variant = "sprint-execute"
  NO  ↓

Is this a bug fix?
  YES → pipeline_variant = "bug"
  NO  ↓

Is this carry-over / next sprint work?
  YES → pipeline_variant = "carry-over"
  NO  ↓

Is this analysis-only (no implementation requested)?
  YES → pipeline_variant = "analysis-only"
  NO  ↓

Do trusted planning artifacts exist on disk?
  (has_product_brief AND has_prd AND has_architecture)
  YES → pipeline_variant = "feature"
  NO  ↓

Do ANY planning artifacts exist?
  YES → Are they trusted / current?
    NOT SURE → pipeline_variant = "brownfield-c"
    NO, STALE → Is code mid-implementation?
      YES → pipeline_variant = "brownfield-a"
      NO  → pipeline_variant = "brownfield-b"
  NO  → Is there an existing codebase with source files?
    YES → pipeline_variant = "brownfield-b"
    NO  → pipeline_variant = "greenfield"
```

### Step 4: Ambiguity Check (Rule 11)

If you cannot confidently determine the pipeline variant, ask the user ONE
clarifying question. Examples of genuine ambiguity:

- User said "improve the dashboard" but no PRD exists and the codebase has
  partial documentation — is this brownfield-b or brownfield-c?
- User said "run the sprint" but there are both carry-over items AND a new
  feature spec — which takes priority?
- User gave a description that could be a bug or a feature enhancement.
- A defect signal (per Step 2) co-occurs with a carry-over or sprint-execute
  signal — a backlog / "next sprint" request that ALSO describes a production
  defect — which takes priority, the planned work or triaging the defect?

**Mixed defect + carry-over/sprint is a MUST-ASK, not optional.** When a bug
signal (per Step 2) co-occurs with a carry-over or sprint-execute signal and
the operator has NOT already directed the priority, you MUST ask the one
clarifying question before routing. This case fires on signal co-occurrence,
not on operator phrasing — do not resolve it silently by subordinating the
defect into a carry-over/feature story. The "Do NOT ask" allowance below does
NOT cover it: co-occurring defect + carry-over is ambiguous by definition,
because the two route to different pipelines (`bug` → repro-first triage;
`carry-over` → full planning). Record the outcome in the snapshot's
`clarification_asked` field (Step 6): `yes` if you asked, `n-a` if the
operator pre-directed the priority.

Do NOT ask if the variant is clear from the project state + input.

### Step 5: Branch Strategy

Before starting the pipeline, determine the correct branch strategy:

1. **Check the current branch:** Run `git branch --show-current`.

2. **If on `main` or `master`:** Create a new branch for this work.
   Generate a branch name from the pipeline variant and user input:
   - Format: `ai-dlc/<variant>/<short-description>`
   - Examples: `ai-dlc/feature/user-dashboard`, `ai-dlc/bug/stale-cache`,
     `ai-dlc/greenfield/notification-system`
   - Keep the description to 2-4 kebab-case words derived from the
     user's request.
   - Create the branch: `git checkout -b <branch-name>`
   - Announce: "Created branch `<branch-name>` for this work."

3. **If on an existing `ai-dlc/*` branch:** This is likely a resumed
   pipeline. Ask the user: "You're on branch `<name>`. Continue on
   this branch, or create a new one?" If continuing, proceed. If new,
   create as above.

4. **If on any other branch:** The user is on a custom branch. Ask:
   "You're on branch `<name>`. Use this branch for AI/DLC work, or
   create a new branch?" Respect their choice.

5. **If git is not initialized:** Skip branching entirely. Do not
   initialize a git repo — that is the user's decision.

### Step 6: Compose Pipeline and Begin

Based on `pipeline_variant`, load the first step file:

| Variant | Pipeline Sequence | First Step |
|---------|------------------|------------|
| sprint-execute | implementation → sprint-review → deploy-validate → retro | `implementation.md` |
| greenfield | discovery → research-requirements → architecture → stories-test-strategy → [ui-direction] → implementation → sprint-review → deploy-validate → retro | `discovery.md` |
| feature | discovery → research-requirements → architecture → stories-test-strategy → [ui-direction] → implementation → sprint-review → deploy-validate → retro | `discovery.md` |
| bug | bug-investigation → implementation → deploy-validate → retro | `bug-investigation.md` |
| carry-over | carry-over-evaluation → discovery → research-requirements → architecture → stories-test-strategy → [ui-direction] → implementation → sprint-review → deploy-validate → retro | `carry-over-evaluation.md` |
| brownfield-a | codebase-inventory → discovery → research-requirements → architecture → stories-test-strategy → implementation → sprint-review → deploy-validate → retro | `codebase-inventory.md` |
| brownfield-b | deep-codebase-analysis → discovery → research-requirements → architecture → stories-test-strategy → [ui-direction] → implementation → sprint-review → deploy-validate → retro | `deep-codebase-analysis.md` |
| brownfield-c | doc-reconciliation → doc-repair-backfill → discovery → research-requirements → architecture → stories-test-strategy → [ui-direction] → implementation → sprint-review → deploy-validate → retro | `doc-reconciliation.md` |
| analysis-only | deep-codebase-analysis → **STOP** (present analysis to user, do not proceed to implementation) | `deep-codebase-analysis.md` |

**Note:** `[ui-direction]` is conditional — included only when the sprint
introduces new visual surfaces (new UI components, pages, or layout changes).
This is determined during the stories-test-strategy step, not here.

**Note:** For multi-sprint features (Rule 14), each subsequent sprint
loops through: `sprint-review-next` → `implementation` → `sprint-review`
→ `deploy-validate`. The `sprint-review-next` step validates the next
sprint's stories before implementation begins. This loop is handled by
`deploy-validate.md`'s post-validation routing, not by the router.

**Note:** For `feature` variant, the discovery step is scoped — it updates
existing artifacts rather than creating from scratch.

**Determine validation intensity (Rule 8).** Before creating the
snapshot, classify `validation_intensity` based on the stories in
scope (or anticipated scope for carry-over/greenfield):

- `full` — ≥3 stories touching service code paths
- `standard` — 1-2 stories touching service code paths
- `lightweight` — all stories touch only pipeline-infra paths
  (scripts, config, docs, CI workflows)

For carry-over and bug variants where story count is not yet known,
estimate from the user's input. The intensity MAY be revised upward
(never downward) at stories-test-strategy if the actual story scope
differs from the estimate. Record the intensity in the snapshot's
Sprint Context section.

**Resolve `sprint_id` (MANDATORY — this is the pipeline's sprint
identity).** A fresh pipeline start is the only place the sprint number
is derived; every downstream consumer reads it from the snapshot, never
re-derives it. Resolve it here, before creating the snapshot:

    scripts/sprint-status.sh sprint-id

It prints an integer on stdout. Use that value. Do NOT re-derive it by
reading `sprint-status.yaml` yourself — the rules are the script's, and a
second implementation is a second answer.

Exit codes: **0** — use the printed integer. **3** — HARD_BLOCK (Rule 11):
the two `sprint-status.yaml` copies disagree on `sprint:`. Surface both
values and wait; never guess which is authoritative. **1** — fail-closed;
report it and stop.

`sprint_id` MUST be an integer. `none` is a hard stop, never a fallback —
the analyst-draft write paths below are stamped with it (Rule 24), and an
unstamped fallback silently destroys the prior sprint's draft, which is
the exact defect the stamp exists to prevent.

This used to be four prose rules the model applied by hand, and they had
no case for a canonical that exists but carries no `sprint:` key — the
state a rotate-at-close leaves behind. Read as "greenfield", it restamps
a live project from sprint 1. The script derives that case from the
frozen archives instead.

**Rotate the sprint envelope (MANDATORY).** Immediately after resolving
`sprint_id`, run:

    scripts/sprint-status.sh roll --sprint <sprint_id> \
      [--name "<sprint name>"] [--variant <variant>] [--intensity <intensity>]

This is the pipeline's ONLY rotation point, and it is idempotent — on a
re-plan (`sprint_id` unchanged) it is a no-op, so it is always safe to run.
When the prior sprint is closed it freezes that sprint to
`sprint-status/sprint-<N>.yaml` and writes the new envelope in ONE step.
On a greenfield project it creates the file.

Rotation lives HERE, at pipeline start, and not at sprint close, for one
reason: `sprint-id` above must be able to read the closed sprint's
`status: done`. Rotating at close prunes that block, and the successor
does not exist yet — so the number has nowhere to come from and the roll
falls to whoever remembers to do it by hand.

Exit **3** is a HARD_BLOCK: the prior sprint is not closed (`status:` is
not `done`), or a frozen archive already exists and differs from the
canonical it would freeze. Surface it and wait — never freeze live state.

**Initialize the pipeline snapshot.** Before the READ AND FOLLOW, handle
the pipeline snapshot at `_bmad-output/pipeline-snapshot.md`:

- **If the file does NOT exist:** create it with initial state:
  - Pipeline Position (detected variant, first step file, no
    last-completed step yet, no gates passed yet, current git
    branch from `git branch --show-current`; plus the **routing record**,
    which Check 27 re-adjudicates at the first planning gate:
    - `user_request_verbatim` — the operator's request text, verbatim.
      Persist it because a fresh gate-adjudicator has no access to this
      routing conversation and cannot re-classify what was never written
      to disk. `user_input` (Step 2) otherwise lives only in context.
    - `bug_signal_present` — `yes`/`no`, as resolved in Step 2.
    - `carryover_or_sprint_signal_present` — `yes`/`no`, as resolved in Step 2.
    - `clarification_asked` — `yes`/`no`/`n-a`, as resolved in Step 4)
  - Sprint Context (`sprint_id` as resolved above — an integer, never
    `none`; remaining fields from `sprint-status.yaml` if it exists)
  - Recent Activity (empty — will be populated by `gate-validation.md`
    Check 14 on each gate passage)
  - Open Items (empty)
  - Locked Decisions (empty)
  - In-Flight Teammates (empty table, header row only:
    `agent | role | deliverable | dispatched-at`; rows are added at
    dispatch and struck at join)
  - Context Reminders (initialized here; the `ai-dlc-context-sensor.sh`
    hook owns runtime firing and dedupe in its own sidecar, and Check 14
    reconciles these fields from it at each gate):
    - `context_reminders_sent: none`
    - `last_yellow_fire_tokens: null`
    - `last_yellow_fire_turns: null`
    - `last_red_fire_tokens: null`
    - `last_red_fire_turns: null`

- **If the file ALREADY exists** (a stale snapshot from a previous
  pipeline run — Step 0 did not dispatch to a resume, so the user is
  starting fresh with an old snapshot still on disk): do NOT silently
  overwrite. Archive the old file to
  `_bmad-output/pipeline-snapshot.archive.{ISO-timestamp}.md`
  (timestamp format: compact ISO 8601, e.g., `2026-04-15T143000Z`),
  then create a new snapshot with initial state as above. Announce
  the archival in the output so the user knows the previous state
  was preserved.

The full per-section snapshot structure is defined in
`gate-validation.md` Check 14; see the SKILL.md Handoff Protocol and
Pipeline Snapshot section for its role and rationale. The snapshot is
maintained throughout the pipeline and is the source of truth for state
on handoff, post-`/compact` recovery, and lead self-orientation.

Announce the detected variant and pipeline to the user, then **READ AND
FOLLOW** the first step file at:
`{project-root}/.claude/skills/ai-dlc/steps/<first-step-filename>`

## FAILURE MODES

- If project state cannot be read (permission error, missing directories):
  ask user to confirm project root and directory structure.
- If user input is empty: ask user what they want to build.
- If ambiguity cannot be resolved with one question: default to the most
  conservative variant (brownfield-b for analysis, greenfield for building).
