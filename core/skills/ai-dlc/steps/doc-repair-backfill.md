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

### 1. Repair Existing Docs

Read `_bmad-output/planning-artifacts/doc-reconciliation.md` (the finding
set only — small). For every STALE/WRONG/MISSING-FROM-DOCS finding, dispatch
a `dev` teammate (Agent tool, role-bound per Rule 19) to apply the edits:
update each document to match the codebase, preserve accurate content, add a
correction log, add docs for undocumented code, and flag MISSING-FROM-CODE
with `[NOT IMPLEMENTED]` (never remove). If any target document is a
protected path, dispatch `protected-path-editor` for that file instead
(Rule 28 / `implementation.md`). The lead validates the returned edits
against the finding set; it does not apply them inline.

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
3. `/bmad-review-adversarial-general` — 2+ passes. **Repair the findings** (`_gate-procedures.md`, "Adversarial repair dispatch" — ONE `remediator` per pass; the lead does not repair the artifact itself).
   **Run sub-step snapshot update after each adversarial pass.**
   **Then run auto-handoff evaluation** (see `_gate-procedures.md`
   \"Auto-handoff evaluation\") at `Seam D` with the label
   `doc-repair-backfill adversarial pass <N>`. If evaluation returns
   FIRE, the session ends; otherwise continue.
   **When the final pass produces only nitpicks, immediately proceed to step 4:**
4. Append changelogs to all modified artifacts.
   **Then immediately proceed to gate validation:**

### 4. Gate Validation and Proceed

Run auto-handoff evaluation at `Seam B` with the label
`doc-repair-backfill end-of-step pre-gate` (see `_gate-procedures.md`
\"Auto-handoff evaluation\"). If evaluation returns CONTINUE, run
gate validation [planning] (`gate-validation.md`), then:
**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/discovery.md`
