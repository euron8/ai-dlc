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
`_bmad-output/planning-artifacts/s<N>/research-notes.md` (Rule 24 sprint
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

Synthesize research findings into the product brief. When research surfaces
new constraints or opportunities, dispatch the `pm` (Agent tool, bound to
`.claude/team-roles/pm.md` per SKILL.md Rule 19 — both bindings: `model` and the
standing role-contract Read line) to update it directly. The lead owns the
routing, not the edit.

### 2. PRD Creation

Read `_bmad-output/specs/s<N>/<slug>/SPEC.md` first — it is the
machine contract `bmad-prd` consumes, produced at `discovery.md` §4b.

**Every functional requirement MUST cite the capability it realises**, in its own
entry, alongside the existing locked-requirement arrow:

```
- **FR-S<N>-1 (CAP-1) (← LR-S<N>-1) — <title>.** <body>
```

`CAP-<m>` is `bmad-spec`-owned and never reused or renumbered, so this is a join a
script can close — unlike the `←` arrow, which is a character.

**`bmad-prd` cannot add this citation, so the PM adds it in a second pass.** The
strings `CAP-`, `LR-` and `SPEC.md` have ZERO occurrences anywhere in that skill, its
template numbers requirements globally as `#### FR-1: {short capability name}`, and it
explicitly instructs "skip traceability matrices". So a PRD it authors will never carry
the citation. After `bmad-prd` returns, walk each FR entry and add the `(CAP-<m>)`
token, resolving it from the spec kernel. Treat that as part of authoring the PRD, not
an optional enrichment: gate-validation Check 30 FAILS on a capability no FR cites, and
the pass that adds the tokens is the only thing that can make it pass.

The citation belongs on the FR entry and **NOT** in the `FR Coverage Map`. That map
is `/bmad-create-epics-and-stories`' artifact and its template emits
`FR1: Epic 1 - <description>` — an FR-to-epic mapping that carries no capability
token. Requiring one there would fail a correct map. FR-to-epic coverage is
`/bmad-check-implementation-readiness` step 03's job; do not restate it.

Gate-validation Check 30 FAILS on a capability no FR cites: a capability with no
functional requirement behind it is specified and unplanned, so it reaches no epic,
no story and no test.

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

Copy the `LOCKED_REQUIREMENTS` block from
`_bmad-output/planning-artifacts/s<N>/locked-requirements.md` into the PRD.
If the PRD adds new requirements derived from research, add those to the
block only if they originated from the user's input (not from research
findings or agent analysis). Research may inform HOW requirements are met
but does not create new locked WHAT requirements.

### 3. PRD Validation

Invoke `/bmad-prd` with the **validate** intent — structured completeness check
against its own rubric. Dispatch the `pm` (role-bound per Rule 19) to fix the
gaps it reports. The lead owns the routing, not the edit.

It detects create / update / validate from the conversation, so say which you
want rather than relying on inference: this call must not re-author the PRD. Under
the headless contract the validate intent always writes both
`validation-report.html` and `validation-report.md` into the run folder regardless
of finding count, and returns `"offer_to_update": true` — read the report, do not
treat the returned offer as an instruction to hand it the update.

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
- **intensity:** on `validation_intensity == lightweight`, skip party-mode and
  advanced-elicitation. **That skip is the whole of `lightweight`; it is NOT a
  cap on passes.** The cycle still converges (Check 24's scope includes
  `research-requirements`), so each pass stamps a `verdict:` and the series ends
  when one stamps `EXIT_CONDITION_MET`. A single pass is not a one-shot review.
- **`Seam D` label:** `research-requirements adversarial pass <N>`.
- **on convergence:** append a changelog to
  `_bmad-output/planning-artifacts/s<N>/changelog-prd.md` (`_gate-procedures.md` —
  "Where a changelog is written"; NOT the PRD itself), then proceed to gate
  validation.

### 5. Gate Validation and Proceed

Run auto-handoff evaluation at `Seam B` with the label
`research-requirements end-of-step pre-gate` (see
`_gate-procedures.md` \"Auto-handoff evaluation\"). If evaluation
returns CONTINUE, run gate validation [planning] (`gate-validation.md`),
then:
**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/architecture.md`
