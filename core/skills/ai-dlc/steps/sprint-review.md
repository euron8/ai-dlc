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

**Intensity gate for lightweight.** When `validation_intensity ==
lightweight`, skip this sprint-level party mode — the single Step 1
adversarial pass satisfies the lightweight minimum. Proceed to Step 3
(Fix and Re-Validate) with any Step 1 findings.

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

**Core-path seam non-deferral.** When any reviewer flags an untested
integration seam (a wiring point where one component's output must reach
another for the feature to function), the disposition MUST classify the
seam as either **wiring-reachable pre-merge** — whether the real
entrypoint actually invokes the seam is a pure-software fact knowable
in-process before merge — or **environmental** — the seam is reachable
only in the deployed environment. A wiring-reachable seam on the
sprint's PRIMARY deliverable path (the path that realizes the sprint's
headline deliverable) MUST NOT be deferred to deploy-validate;
deferring it is a HARD_BLOCK (Rule 12 Tier 1). Such a seam requires an
in-pipeline mutation-RED wiring test before merge — a test that drives
the real entrypoint and FAILS if the seam is unwired (external legs MAY
be mocked; the wiring itself MUST be exercised). Only a genuinely
environmental seam MAY defer. Any override MUST name the risk verbatim:
"this could merge with every gate green and ship functionally inert."
Catches: a feature that passes code review, QA, and smoke yet ships
functionally inert because its core wiring seam was never exercised and
was deferred to a live-only check. False-positive cost: one in-pipeline
wiring test per core-path seam, external legs mocked. Remove when: the
sprint's primary deliverable path contains no cross-component wiring
seam reachable in-process before merge.

### 4. Gate Validation and Proceed

Run auto-handoff evaluation at `Seam B` with the label
`sprint-review end-of-step pre-gate` (see `gate-validation.md`
"Auto-handoff evaluation"). If evaluation returns CONTINUE, run
gate validation (`gate-validation.md`), then:
**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/deploy-validate.md`
