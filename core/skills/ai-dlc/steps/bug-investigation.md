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
- **Root-cause input, not just location:** trace whether the inputs FEEDING
  the root cause were themselves computed correctly. "A distinct root cause"
  names WHERE the defect is, not whether the values it acts on are right — a
  fix that corrects the site while leaving a wrong input upstream still ships
  the defect (e.g. a safeguard that fires correctly on a mis-computed input).
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

**Revert-control completeness.** "Root cause identified" is a
classification, not a proof the fix is complete. The null hypothesis the
fix must rule out is: what degenerate or incomplete fix would still earn
the root-cause label while leaving part of the original defect live?
Prove it with a control — revert the fix, confirm the ORIGINAL symptom
returns UNCHANGED IN SHAPE, then re-apply. The revert result is required
evidence in the fix story (`reverted at <sha>, original symptom <X>
reproduced in shape, re-applied`); its absence fails the gate exactly as
an incomplete falsification ladder does. Ties to the falsification ladder
above: that proves the cause is correctly LOCATED, this proves the fix is
COMPLETE.

### 3. Create Fix Story

Create a bug-fix story in `_bmad-output/planning-artifacts/s<N>/stories/`:
- Source Requirements section quoting the bug report verbatim
- Root cause description
- Fix approach
- Acceptance criteria (what "fixed" looks like)
- Regression scope (existing tests, new tests needed)

**If the user specified a particular fix approach or scope, preserve it
(Rule 13). Do not substitute a different approach.**

### 4. Validation

Dispatch ONE `adversary` (Agent tool, bound to `.claude/team-roles/adversary.md`
per SKILL.md Rule 19) to run `/bmad-review-adversarial-general` on the fix story.
**ONE-SHOT — the bmad skill is correct here and stays** (no loop, no verdict, no
counted exit condition; the skill's ≥10 floor buys a cynical sweep and costs
nothing). The native `adversary` review is for CONVERGENCE cycles only.
- Is it the right fix or just a patch?
- Will it introduce regressions?
- Is test coverage sufficient?
- **Source fidelity pass:** Does the story address the specific issue
  described? Does the fix approach match what was requested?

It writes findings to `_bmad-output/planning-artifacts/s<N>/bug-fix-oneshot.md`
carrying a `SKILL_INVOCATION_PROVENANCE v1` block with
`skill: bmad-review-adversarial-general`, `mode: subagent`, and the three
`findings_*` counts — and **no `verdict`**, which a one-shot never stamps. The
path must not carry an `-adversarial-p<M>` suffix: Check 24 globs that prefix and
a verdict-less pass swept into a series fails rung A.

Apply all improvements. Append changelog to the story.

**Then stamp the story — MECHANICALLY, never by hand.** Check 17's bug-fix
story-readiness gate requires a `SKILL_INVOCATION_PROVENANCE` block on the story
itself, and nothing else writes one. Run:

`scripts/ai-dlc/stamp-story-provenance.sh --terminal
_bmad-output/planning-artifacts/s<N>/bug-fix-oneshot.md --profile
bug-story-provenance <story-file>`

`--profile bug-story-provenance` is load-bearing: the default profile pins the
convergence skill and demands `verdict: EXIT_CONDITION_MET`, so it refuses every
bug story by construction. You author nothing; the gate's `--check` re-derives
the same block and fails on any drift.

### 5. Sprint Setup

Run `/bmad-sprint-planning` to set up a single-story sprint.

### 6. Gate Validation and Proceed

Run gate validation [implementation] (`gate-validation.md`), then:

If design flaw detected:
**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/discovery.md`

If implementation error:
**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/implementation.md`
