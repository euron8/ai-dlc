---
name: doc-repair-backfill
description: Brownfield C — repair stale docs and backfill missing BMAD artifacts
nextStepFile: ./discovery.md
---
<!-- STEP_LOADED_TOKEN: doc-repair-backfill -->

# Documentation Repair and Backfill (Brownfield C)

**Purpose:** Repair existing documentation to match reality and backfill
missing BMAD artifacts so planning can proceed from a verified foundation.

## EXECUTION SEQUENCE

### 0. Step Entry Assertion

Output this line verbatim before any other action:
`STEP ENTERED: doc-repair-backfill at {current ISO timestamp}`

### 1. Repair Existing Docs

Read `_bmad-output/planning-artifacts/doc-reconciliation.md`.

For each document with STALE or WRONG findings:
- Update the document to match the codebase
- Preserve accurate content
- Add a correction log at the bottom noting what changed and why

For MISSING FROM DOCS findings:
- Add documentation for undocumented code to the appropriate document

For MISSING FROM CODE findings:
- Flag with [NOT IMPLEMENTED] markers. Do not remove (may be planned work)

### 2. Backfill Missing BMAD Artifacts

For each missing artifact identified in the gap analysis:
- Product brief (if missing): invoke `/bmad-create-product-brief` grounded
  in codebase analysis
- PRD (if missing): invoke `/bmad-create-prd` reverse-engineered from code
- Architecture doc (if missing): invoke `/bmad-create-architecture` from
  AS-IS code

### 3. Validation Cycle

Execute all sub-skills back-to-back without pausing for human input
between them:

Run the full validation cycle (SKILL.md Rule 8) on all repaired and
backfilled artifacts:
1. `/bmad-party-mode` — PM, Architect, Dev walk through all artifacts
   against the codebase. Do they accurately represent reality?
   **Then immediately proceed to step 2:**
2. `/bmad-advanced-elicitation` — probe until zero ambiguity
   **Then immediately proceed to step 3:**
3. `/bmad-review-adversarial-general` — 2+ passes, apply all fixes.
   **Run sub-step snapshot update after each adversarial pass.**
   **Then run auto-handoff evaluation** (see `gate-validation.md`
   "Auto-handoff evaluation") at `Seam D` with the label
   `doc-repair-backfill adversarial pass <N>`. If evaluation returns
   FIRE, the session ends; otherwise continue.
   **When the final pass produces only nitpicks, immediately proceed to step 4:**
4. Append changelogs to all modified artifacts.
   **Then immediately proceed to gate validation:**

### 4. Gate Validation and Proceed

Run auto-handoff evaluation at `Seam B` with the label
`doc-repair-backfill end-of-step pre-gate` (see `gate-validation.md`
"Auto-handoff evaluation"). If evaluation returns CONTINUE, run
gate validation (`gate-validation.md`), then:
**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/discovery.md`
