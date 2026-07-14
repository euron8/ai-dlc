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
3. **Adversarial review pass** (`_gate-procedures.md`, "Adversarial review dispatch" — ONE `adversary` per pass, ai-dlc-native, no Skill) — 2+ passes. **Repair the findings** (`_gate-procedures.md`, "Adversarial repair dispatch" — ONE `remediator` per pass; the lead does not repair the artifact itself).
   **Run sub-step snapshot update after each adversarial pass.**
   **Then run auto-handoff evaluation** (see `_gate-procedures.md`
   \"Auto-handoff evaluation\") at `Seam D` with the label
   `doc-repair-backfill adversarial pass <N>`. If evaluation returns
   FIRE, the session ends; otherwise continue.
   Continue until only nitpicks remain — "nitpick" is the MINOR/NIT rung of the
   `team-roles/adversary.md` severity ladder: **zero CRITICAL and zero MAJOR IS the
   exit condition met**, and the terminating pass stamps `verdict: EXIT_CONDITION_MET`.
   **Gate Check 24 reads that field** (v0.58.0: this loop is now gated; before, it ran
   unbounded and no gate ever read its verdict). CRITICALs rising **in the scope the
   prior pass reviewed** are a `DIVERGENT_HARD_BLOCK` — **it STOPS THE CYCLE**; do not
   run another pass. A MAJOR that will not fall for two consecutive passes at zero
   CRITICAL is a STALL, not progress: derive the disputed fact or cut the claim, then
   escalate (Check 24 §E).
   **When the final pass stamps `EXIT_CONDITION_MET`, immediately proceed to step 4:**
4. Append changelogs to all modified artifacts.
   **Then immediately proceed to gate validation:**

### 4. Gate Validation and Proceed

Run auto-handoff evaluation at `Seam B` with the label
`doc-repair-backfill end-of-step pre-gate` (see `_gate-procedures.md`
\"Auto-handoff evaluation\"). If evaluation returns CONTINUE, run
gate validation [planning] (`gate-validation.md`), then:
**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/discovery.md`
