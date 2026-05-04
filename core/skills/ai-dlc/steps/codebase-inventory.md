---
name: codebase-inventory
description: Brownfield A — inventory existing codebase to identify what exists and what planning artifacts are missing
nextStepFile: ./discovery.md
---
<!-- STEP_LOADED_TOKEN: codebase-inventory -->

# Codebase Inventory (Brownfield A)

**Purpose:** You inherited a project mid-flight. Some code exists. Some
planning artifacts are missing. Inventory what exists before backfilling.

## EXECUTION SEQUENCE

### 0. Step Entry Assertion

Output this line verbatim before any other action:
`STEP ENTERED: codebase-inventory at {current ISO timestamp}`

### 1. Codebase Scan

Walk through every directory and file in the project:
- Document the technology stack, frameworks, dependencies, project structure
- Identify all implemented features and their state (complete, partial,
  broken, stubbed)
- Map the existing architecture: components, services, data models, API
  contracts, integrations, configuration
- Identify all existing tests and their coverage scope

### 2. Artifact Audit

Check for existing planning artifacts:
- Product brief: `_bmad-output/planning-artifacts/product-brief.md`
- PRD: `_bmad-output/planning-artifacts/prd.md`
- Architecture: `docs/architecture.md` or `_bmad-output/planning-artifacts/architecture.md`
- Stories: `_bmad-output/planning-artifacts/stories/`
- Test strategy: `_bmad-output/planning-artifacts/test-strategy.md`

For each existing artifact, note whether it appears current or stale
relative to the codebase.

### 3. Gap Analysis

Produce a gap report listing every BMAD artifact that is missing or
incomplete. Write the full inventory and gap report to:
`_bmad-output/planning-artifacts/brownfield-inventory.md`

### 4. Gate Validation

Run gate validation (`gate-validation.md`). Check 1 (validation cycle complete) is waived for this analysis step — there is no planning artifact to validate. All other applicable checks run normally, including Check 14 (snapshot update) and Check 15 (snapshot verification).

### 5. Proceed

**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/discovery.md`

The discovery step will use the inventory to ground brainstorming and
brief creation in what actually exists.
