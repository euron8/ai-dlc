---
name: sprint-review
description: Sprint-level adversarial review + party mode on complete sprint output
nextStepFile: ./deploy-validate.md
---
<!-- STEP_LOADED_TOKEN: sprint-review -->

# Sprint Review (Phase 4)

**Purpose:** Final sprint-level review across all stories before
deployment. Adversarial review + party mode on the complete sprint.

## EXECUTION SEQUENCE

### 0. Step Entry Assertion

Output this line verbatim before any other action:
`STEP ENTERED: sprint-review at {current ISO timestamp}`

Execute all sub-skills back-to-back without pausing for human input
between them:

### Sprint-Overall PR Incremental Pre-Staging

Sprint-overall PR MUST be assembled incrementally throughout the sprint:
carry-over candidates and partial-close accounting are drafted in
`_bmad-output/implementation-artifacts/sprint-<N>-*.md` as anchors close,
not post-hoc at sprint-close. Final sprint-overall PR assembly = merge +
diff check only, not composition.

This rule applies UNIVERSALLY to all sprint-overall PRs, not gated on
anchor count or story count. Universality is the value — gating on
story count would reintroduce the "surprise sprint-overall content"
mode this rule prevents.

### 1. Sprint-Level Adversarial Review

`/bmad-review-adversarial-general` — final adversarial pass on the
complete sprint output:
- Walk through every change across all stories
- Check for cross-cutting issues (inconsistent patterns, missing
  integration points, duplicated logic across stories)
- Apply all fixes autonomously. Dev teammates apply code fixes.

**Run sub-step snapshot update after each adversarial pass.**
**Then run auto-handoff evaluation** (see `gate-validation.md`
"Auto-handoff evaluation") at `Seam D` with the label
`sprint-review adversarial pass <N>`. If evaluation returns FIRE,
the session ends; otherwise continue.

### 2. Sprint-Level Party Mode

`/bmad-party-mode` — PM, Architect, Dev, TEA, QA walk through the
entire sprint implementation:
- Does the implementation match the requirements?
- Are there cross-cutting concerns?
- Is the test coverage adequate across the sprint as a whole?
- Apply all improvements.

### 3. Fix and Re-Validate

If the sprint review surfaced findings that required code changes:
- Dev teammates apply fixes
- Code reviewer re-reviews affected files
- QA re-validates affected stories
- Repeat until clean

### 4. Gate Validation and Proceed

Run auto-handoff evaluation at `Seam B` with the label
`sprint-review end-of-step pre-gate` (see `gate-validation.md`
"Auto-handoff evaluation"). If evaluation returns CONTINUE, run
gate validation (`gate-validation.md`), then:
**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/deploy-validate.md`
