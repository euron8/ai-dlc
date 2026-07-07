---
name: bug-investigation
description: Bug path — investigate root cause, create fix story, route to implementation
nextStepFile: conditional (see Step 6)
---
<!-- STEP_LOADED_TOKEN: bug-investigation -->

# Bug Investigation (Phase 1D-bug)

**Purpose:** Investigate a bug, determine root cause, create a targeted
fix story, then route to implementation.

## EXECUTION SEQUENCE

### 0. Exploration dispatch (Rule 24)

If `planning_offload: on` (default), do NOT run sections 1–2 inline.
Spawn an `analyst` subagent (Agent tool, bound to the analyst role file `.claude/team-roles/analyst.md` per SKILL.md Rule 19 — both bindings: `model` and the standing role-contract Read line) scoped to
sections 1–2 — it loads context, investigates, reproduces, and traces
root cause, then writes its findings (root cause, repro, affected
files/call-sites) to `_bmad-output/planning-artifacts/bug-analysis.md`,
returning only `{artifact_path, summary, gaps}`. Then resume at section
3 (Create Fix Story) using the analysis. The lead authors the fix
story, validates, and owns it. If `planning_offload: off`, run all
sections inline. Per SKILL.md Rule 24.

### 1. Context Loading

Read planning artifacts:
- `_bmad-output/planning-artifacts/prd.md`
- `docs/architecture.md` or `_bmad-output/planning-artifacts/architecture.md`
- `_bmad-output/planning-artifacts/test-strategy.md` (if exists)

### 2. Investigation

Read the relevant source code, tests, and configuration. Trace the bug
to its root cause. Document:
- **Root cause:** what is wrong and where
- **Impact scope:** what else is affected
- **Classification:** design flaw vs. implementation error

If the bug reveals a **DESIGN FLAW** that requires architecture changes:
- Document the finding
- The pipeline will automatically run through the full planning cycle
  (discovery → architecture → stories) to plan the fix properly
- Route to `discovery.md` instead of creating a fix story here

If the bug is an **IMPLEMENTATION ERROR**: proceed with fix planning.

**Falsification ladder.** For each architectural layer that the bug
could plausibly originate from, the investigation MUST document why
that layer IS or IS NOT the root cause, with evidence (query result,
code trace, or test output). "Likely cause at layer X" without
evidence ruling out other layers is insufficient. Violation: gate
fails on incomplete falsification.

### 3. Create Fix Story

Create a bug-fix story in `_bmad-output/planning-artifacts/stories/`:
- Source Requirements section quoting the bug report verbatim
- Root cause description
- Fix approach
- Acceptance criteria (what "fixed" looks like)
- Regression scope (existing tests, new tests needed)

**If the user specified a particular fix approach or scope, preserve it
(Rule 13). Do not substitute a different approach.**

### 4. Validation

`/bmad-review-adversarial-general` — review the fix approach:
- Is it the right fix or just a patch?
- Will it introduce regressions?
- Is test coverage sufficient?
- **Source fidelity pass:** Does the story address the specific issue
  described? Does the fix approach match what was requested?
Apply all improvements. Append changelog to the story.

### 5. Sprint Setup

Run `/bmad-sprint-planning` to set up a single-story sprint.

### 6. Gate Validation and Proceed

Run gate validation [implementation] (`gate-validation.md`), then:

If design flaw detected:
**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/discovery.md`

If implementation error:
**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/implementation.md`
