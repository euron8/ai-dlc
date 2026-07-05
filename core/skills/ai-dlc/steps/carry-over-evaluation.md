---
name: carry-over-evaluation
description: Evaluate carry-over backlog, scope items, handle deferrals, then feed into full planning pipeline
nextStepFile: ./discovery.md
---
<!-- STEP_LOADED_TOKEN: carry-over-evaluation -->

# Carry-Over Evaluation

**Purpose:** Evaluate carry-over backlog items, close invalid ones,
handle deferrals, then feed valid items into the full planning pipeline
(discovery → research-requirements → architecture → stories). Carry-over
items get the same planning rigor as new features.

## EXECUTION SEQUENCE

### 0. Exploration dispatch (Rule 24)

If `planning_offload: on` (default), do NOT run sections 1–2 (and 1a)
inline. Spawn an `analyst` subagent (Agent tool, `model` from the analyst role file per Rule 19)
scoped to those reading sections — it loads the backlog/brief/PRD and
audit anchor, evaluates each item, and writes a draft evaluation to
`_bmad-output/planning-artifacts/carry-over-evaluation.md`, returning
only `{artifact_path, summary, gaps}`. Then resume at section 3.
**Sections 3 onward stay inline in the lead** — section 3 is party mode
(Rule 20, never offloaded) and sections 4–6 mutate escalations and the
backlog. If `planning_offload: off`, run all sections inline. Per
SKILL.md Rule 24.

### 1. Context Loading

Read in full (the live current-state files only — this evaluation is
cross-cutting, so per Rule 25(b) it reads whole and relies on those
files staying bounded; do NOT read the `*-history.md` / `*-archive.md`
files):
- `_bmad-output/planning-artifacts/carry-over-backlog.md`
- `docs/architecture.md`
- `_bmad-output/planning-artifacts/product-brief.md`
- `_bmad-output/planning-artifacts/prd.md`
- Project memory files for user preferences and prior decisions

### 1a. Read Audit Anchor

Read `_bmad-output/audit-anchors.md`. Locate the entry for the prior
sprint (current sprint number minus one). Resolve the `sha` field as
`<prior_sprint_sha>` for downstream per-class test-debt audit
(`gate-validation.md` Check 18). If no entry exists for prior sprint,
file HARD_BLOCK at carry-over-evaluation gate — silent skip is
forbidden.

**Backlog health check.** Before per-item evaluation, count OPEN
items and flag any older than 10 sprints. When OPEN count exceeds 15,
prioritize triage as a sprint deliverable.

### 2. Item Evaluation

For each OPEN item in the backlog, evaluate:
1. **Still valid?** Has it been superseded? Has affected code changed?
2. **Effort and complexity?** Single story or multiple?
3. **Dependencies?** On other backlog items?
4. **Option check (Rule 13):** Does this item list multiple implementation
   options or scope levels? If YES:
   - Evaluate options using project context and user preferences
   - Select the best option
   - Document as `DECIDED_AUTONOMOUSLY` with rationale

**Process-exercise scoping.** For any item classified as a
process exercise, the evaluation MUST define a fail-condition trigger:
the specific observable event that constitutes exercise failure. Items
with no distinct fail condition MUST be reclassified as monitoring
notes embedded in the sprint retro rather than carried as standalone
exercise stories.

### 3. Party Mode Evaluation

`/bmad-party-mode` — PM, Architect, Dev, TEA evaluate every item:
- Valid or close? If valid, rough story shape?
- Surface any items that have become higher/lower priority
- Surface any that are clearly no longer worth doing

### 4. Deferral Handling

If the agent determines any item should be DEFERRED (not implemented
this sprint, not closed):
- Write a `DEFERRAL_REQUEST` entry to `docs/escalations/pending.md`
- Include: which item, why deferral is recommended, impact of deferral
- **Proceed with all non-deferred items** — do not block the pipeline
- The human will review deferrals at the production validation checkpoint

### 5. Close Invalid Items

For items the team agrees to close:
- Document closure reason in `carry-over-backlog.md`
  (append status: CLOSED - [reason])

### 6. Update Backlog

Update `carry-over-backlog.md`:
- Mark items proceeding to planning as IN SPRINT
- Mark closed items as CLOSED with reason
- Mark deferred items as DEFERRAL_REQUESTED

### 7. Proceed to Full Planning Pipeline

Valid carry-over items now enter the same planning pipeline as new
features. Do NOT create stories here — that happens in
stories-test-strategy after the full planning cycle.

The discovery step will:
- Update the product brief with carry-over scope
- Extract LOCKED_REQUIREMENTS from carry-over items

The research-requirements step will:
- Update the PRD with carry-over requirements

The architecture step will:
- Assess architecture impact of carry-over items

The stories-test-strategy step will:
- Create stories from the updated planning artifacts
- Run the full validation cycle on stories

Every new item filed MUST include `**Status:** OPEN` at minimum.
Item IDs MUST use `CO-S<sprint>-<descriptor>` format.

Run gate validation (`gate-validation.md`), then:
**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/discovery.md`
