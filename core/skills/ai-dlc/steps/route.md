---
name: route
description: Detect pipeline variant from project state and user input, compose step sequence
nextStepFile: dynamically determined by routing logic
---

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
   snapshot" — this is a resume:
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

### Step 1: Read Project State

Check for existing artifacts on disk:

1. Check `_bmad-output/planning-artifacts/product-brief.md` — exists and non-empty?
2. Check `_bmad-output/planning-artifacts/prd.md` — exists and non-empty?
3. Check `docs/architecture.md` or `_bmad-output/planning-artifacts/architecture.md` — exists?
4. Check `_bmad-output/planning-artifacts/stories/` — any story files exist?
5. Check `_bmad-output/planning-artifacts/carry-over-backlog.md` — any OPEN items?
6. Read `_bmad-output/planning-artifacts/sprint-status.yaml` if it exists — current sprint state?
7. Read CLAUDE.md for project rules and conventions.

### Step 2: Analyze User Input

Classify the user's request:

- **Sprint-execute signal**: Input mentions "implement the sprint",
  "execute the sprint", "run the stories", "pick up implementation",
  "start building", or sprint-status.yaml shows stories in ready-for-dev
  or in-progress status AND user does not describe a new feature/bug.
- **Bug signal**: Input mentions "fix", "bug", "broken", "wrong", "error",
  "doesn't work", describes unexpected behavior, or references a defect.
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

### Step 4: Ambiguity Check (Autonomy Rule 10)

If you cannot confidently determine the pipeline variant, ask the user ONE
clarifying question. Examples of genuine ambiguity:

- User said "improve the dashboard" but no PRD exists and the codebase has
  partial documentation — is this brownfield-b or brownfield-c?
- User said "run the sprint" but there are both carry-over items AND a new
  feature spec — which takes priority?
- User gave a description that could be a bug or a feature enhancement.

Do NOT ask if the variant is clear from the project state + input.

### Step 5: Branch Strategy

Before starting the pipeline, determine the correct branch strategy:

1. **Check the current branch:** Run `git branch --show-current`.

2. **If on `main` or `master`:** A new branch should be created for
   this work. Generate a branch name from the pipeline variant and
   user input:
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

**Note:** For multi-sprint features (Rule 9), each subsequent sprint
loops through: `sprint-review-next` → `implementation` → `sprint-review`
→ `deploy-validate`. The `sprint-review-next` step validates the next
sprint's stories before implementation begins. This loop is handled by
`deploy-validate.md`'s post-validation routing, not by the router.

**Note:** For `feature` variant, the discovery step is scoped — it updates
existing artifacts rather than creating from scratch.

**Initialize the pipeline snapshot.** Before the READ AND FOLLOW, handle
the pipeline snapshot at `_bmad-output/pipeline-snapshot.md`:

- **If the file does NOT exist:** create it with initial state:
  - Pipeline Position (detected variant, first step file, no
    last-completed step yet, no gates passed yet)
  - Sprint Context (populate from `sprint-status.yaml` if it exists;
    else `sprint_id: none`)
  - Recent Activity (empty — will be populated by `gate-validation.md`
    Check 14 on each gate passage)
  - Open Items (empty)
  - Locked Decisions (empty)

- **If the file ALREADY exists** (a stale snapshot from a previous
  pipeline run — Step 0 did not dispatch to a resume, so the user is
  starting fresh with an old snapshot still on disk): do NOT silently
  overwrite. Archive the old file to
  `_bmad-output/pipeline-snapshot.archive.{ISO-timestamp}.md`
  (timestamp format: compact ISO 8601, e.g., `2026-04-15T143000Z`),
  then create a new snapshot with initial state as above. Announce
  the archival in the output so the user knows the previous state
  was preserved.

See SKILL.md Rule 10 for the full snapshot structure. The snapshot is
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
