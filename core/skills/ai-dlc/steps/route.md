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

### Step 4: Ambiguity Check (Rule 10)

If you cannot confidently determine the pipeline variant, ask the user ONE
clarifying question. Examples of genuine ambiguity:

- User said "improve the dashboard" but no PRD exists and the codebase has
  partial documentation — is this brownfield-b or brownfield-c?
- User said "run the sprint" but there are both carry-over items AND a new
  feature spec — which takes priority?
- User gave a description that could be a bug or a feature enhancement.

Do NOT ask if the variant is clear from the project state + input.

### Step 5: Compose Pipeline and Begin

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

**Note:** For `feature` variant, the discovery step is scoped — it updates
existing artifacts rather than creating from scratch.

Announce the detected variant and pipeline to the user, then **READ AND
FOLLOW** the first step file at:
`{project-root}/.claude/skills/ai-dlc/steps/<first-step-filename>`

## FAILURE MODES

- If project state cannot be read (permission error, missing directories):
  ask user to confirm project root and directory structure.
- If user input is empty: ask user what they want to build.
- If ambiguity cannot be resolved with one question: default to the most
  conservative variant (brownfield-b for analysis, greenfield for building).
