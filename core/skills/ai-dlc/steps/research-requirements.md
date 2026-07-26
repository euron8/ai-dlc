---
name: research-requirements
description: Research + PRD creation + validation cycle
nextStepFile: ./architecture.md
---
<!-- STEP_LOADED_TOKEN: research-requirements -->

# Research and Requirements (Phase 2a-b)

**Purpose:** Domain, market, and technical research feeding into PRD
creation with full validation cycle.

## EXECUTION SEQUENCE

### 0. Exploration dispatch (Rule 24)

If `planning_offload: on` (default), do NOT run section 1 inline. Spawn
an `analyst` subagent (Agent tool, bound to the analyst role file `.claude/team-roles/analyst.md` per SKILL.md Rule 19 — both bindings: `model` and the standing role-contract Read line) scoped to section 1
— it performs the domain/market/technical research and writes the
research notes to
`_bmad-output/planning-artifacts/s<N>-research-notes.md` (Rule 24 sprint
stamp: `<N>` is `sprint_id` from the pipeline snapshot's Sprint Context,
resolved at `route.md` Step 6), returning only
`{artifact_path, summary, gaps}`. Then resume at section 2 (PRD
Creation) using the notes. **Sections 2 onward stay inline in the
lead** — PRD authoring and the Rule 8 / PRD validation cycles are never
offloaded. If `planning_offload: off`, run all sections inline. Per
SKILL.md Rule 24.

### 1. Research

Run all applicable research back-to-back (skip none unless clearly
irrelevant). **Do not pause between research sub-skills:**

1. `/bmad-domain-research` — problem domain deep dive
2. `/bmad-market-research` — competitive landscape (skip for internal
   tools or infrastructure work where no market exists)
3. `/bmad-technical-research` — technology options, constraints, risks

Synthesize research findings into the product brief. Update it directly
if research surfaces new constraints or opportunities.

### 2. PRD Creation

- For **greenfield/brownfield-b**: invoke `/bmad-prd` — full PRD
  with personas, metrics, risks
- For **feature/brownfield-a/c**: UPDATE the existing PRD per Rule 25(a)
  — integrate the new scope's requirements into the current-state
  sections, and **move** superseded requirement versions and prior
  per-sprint scope narrative to `prd-history.md` (cut-and-paste,
  verbatim). Never drop a requirement: the union of `prd.md` and
  `prd-history.md` must preserve every prior requirement. Rule 13
  locked requirements stay in the live PRD. Reference existing
  components by name where the new work touches them.
  **For requirements from carry-over items or user instructions: quote
  the source requirement verbatim. Preserve specific details. Do not
  generalize.**

### 2a. Propagate Locked Requirements (Rule 13)

Copy the `LOCKED_REQUIREMENTS` block from the product brief into the PRD.
If the PRD adds new requirements derived from research, add those to the
block only if they originated from the user's input (not from research
findings or agent analysis). Research may inform HOW requirements are met
but does not create new locked WHAT requirements.

### 3. PRD Validation

Invoke `/bmad-prd` — structured completeness check. Fix all
gaps found.

### 4. Validation Cycle (Rule 8)

Run the validation cycle (`_gate-procedures.md`, "Validation cycle") on the PRD —
its passes use the **Adversarial review dispatch** and **Adversarial repair
dispatch** sub-routines. Parameters:
- **party-mode seats / subject:** PM, Architect, UX, Dev, TEA — every section of
  the PRD (personas, stories, NFRs, metrics, risks, constraints).
- **source-fidelity check:** verify each requirement implements what was
  requested, not a generalized or lower-effort alternative, preserving specific
  details from its source.
- **adversarial focus:** none beyond the adversary's default contract.
- **intensity:** on `validation_intensity == lightweight`, run one adversarial
  pass only — skip party-mode and advanced-elicitation. It is still a convergence
  pass (Check 24's scope includes `research-requirements`), so it stamps a
  `verdict:`; a single pass is not a one-shot review.
- **`Seam D` label:** `research-requirements adversarial pass <N>`.
- **on convergence:** append a changelog to the PRD, then proceed to gate
  validation.

### 5. Gate Validation and Proceed

Run auto-handoff evaluation at `Seam B` with the label
`research-requirements end-of-step pre-gate` (see
`_gate-procedures.md` \"Auto-handoff evaluation\"). If evaluation
returns CONTINUE, run gate validation [planning] (`gate-validation.md`),
then:
**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/architecture.md`
