---
name: doc-reconciliation
description: Brownfield C — reconcile existing documentation against actual codebase
nextStepFile: ./doc-repair-backfill.md
---
<!-- STEP_LOADED_TOKEN: doc-reconciliation -->

# Documentation Reconciliation (Brownfield C)

**Purpose:** Documentation exists but is not trusted. Compare every claim
in the docs against the actual codebase to determine accuracy.

## EXECUTION SEQUENCE

### 0. Exploration dispatch (Rule 24)

If `planning_offload: on` (default), do NOT run sections 1–5 inline.
Spawn an `analyst` subagent (Agent tool, `model` from the analyst role file per Rule 19) scoped to
sections 1–5 — it inventories docs, scans the codebase, reconciles
claims against reality, and writes the reconciliation report + gap
analysis to `_bmad-output/planning-artifacts/doc-reconciliation.md`,
returning only `{artifact_path, summary, gaps}`. Then resume at section
6 (Gate Validation and Proceed). If `planning_offload: off`, run all
sections inline. Per SKILL.md Rule 24.

### 1. Documentation Inventory

List every existing documentation artifact and its location:
architecture docs, PRDs, stories, wikis, readmes, design docs, ADRs,
API docs, runbooks, onboarding guides.

### 2. Codebase Scan

Walk the full project structure, technology stack, and dependencies.
Map the actual architecture: components, services, data models, APIs,
integrations.

### 3. Reconciliation

For each existing document, compare claims against the codebase:
- **ACCURATE**: document matches the code
- **STALE**: document describes something that has changed
- **WRONG**: document contradicts the code
- **MISSING FROM DOCS**: code exists with no documentation
- **MISSING FROM CODE**: document describes something not implemented

Produce specific line-level citations for every discrepancy.

### 4. Gap Analysis

List BMAD artifacts that are missing entirely (product brief, PRD,
architecture doc, stories, test strategy).

### 5. Write Report

Write the reconciliation report and gap analysis to:
`_bmad-output/planning-artifacts/doc-reconciliation.md`

### 6. Gate Validation and Proceed

Run gate validation (`gate-validation.md`), then:
**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/doc-repair-backfill.md`
