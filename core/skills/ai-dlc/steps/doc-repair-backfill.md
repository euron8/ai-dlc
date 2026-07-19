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

Run the validation cycle (`_gate-procedures.md`, "Validation cycle") on all
repaired and backfilled artifacts — its passes use the **Adversarial review
dispatch** and **Adversarial repair dispatch** sub-routines. Parameters:
- **party-mode seats / subject:** PM, Architect, Dev — all artifacts against the
  codebase: do they accurately represent reality?
- **adversarial focus:** none beyond the adversary's default contract.
- **`Seam D` label:** `doc-repair-backfill adversarial pass <N>`.
- **on convergence:** append changelogs to all modified artifacts, then proceed to
  gate validation.

### 4. Gate Validation and Proceed

Run auto-handoff evaluation at `Seam B` with the label
`doc-repair-backfill end-of-step pre-gate` (see `_gate-procedures.md`
\"Auto-handoff evaluation\"). If evaluation returns CONTINUE, run
gate validation [planning] (`gate-validation.md`), then:
**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/discovery.md`
