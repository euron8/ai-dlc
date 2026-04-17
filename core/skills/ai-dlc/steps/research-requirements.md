---
name: research-requirements
description: Research + PRD creation + validation cycle
nextStepFile: ./architecture.md
---

# Research and Requirements (Phase 2a-b)

**Purpose:** Domain, market, and technical research feeding into PRD
creation with full validation cycle.

## EXECUTION SEQUENCE

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

- For **greenfield/brownfield-b**: invoke `/bmad-create-prd` — full PRD
  with personas, metrics, risks
- For **feature/brownfield-a/c**: UPDATE the existing PRD — add
  requirements for the new scope. Do not rewrite existing requirements.
  Reference existing components by name where the new work touches them.
  **For requirements from carry-over items or user instructions: quote
  the source requirement verbatim. Preserve specific details. Do not
  generalize.**

### 2a. Propagate Locked Requirements (Rule 8)

Copy the `LOCKED_REQUIREMENTS` block from the product brief into the PRD.
If the PRD adds new requirements derived from research, add those to the
block only if they originated from the user's input (not from research
findings or agent analysis). Research may inform HOW requirements are met
but does not create new locked WHAT requirements.

### 3. PRD Validation

Invoke `/bmad-validate-prd` — structured completeness check. Fix all
gaps found.

### 4. Validation Cycle (Rule 3)

**Execute all sub-skills back-to-back without pausing for human input
between them:**

1. `/bmad-party-mode` — PM, Architect, UX, Dev, TEA debate every section
   of the PRD (personas, stories, NFRs, metrics, risks, constraints).
   Walk through exhaustively. Apply all improvements.
   **Requirement fidelity check:** Verify each new requirement preserves
   specific details from its source.
   **Run sub-step snapshot update** (see `gate-validation.md` "Sub-step
   snapshot update"). **Then immediately proceed to step 2:**
2. `/bmad-advanced-elicitation` — probe every section until zero ambiguity.
   Update the PRD with every clarification.
   **Run sub-step snapshot update. Then immediately proceed to step 3:**
3. `/bmad-review-adversarial-general` — 2+ passes. Apply all fixes
   between passes. Continue until only nitpicks remain.
   **Source fidelity pass:** Verify requirements implement what was
   requested, not a generalized or lower-effort alternative.
   **Run sub-step snapshot update after each adversarial pass.**
   **When the final pass produces only nitpicks, immediately proceed to step 4:**
4. Append a changelog to the PRD.
   **Then immediately proceed to gate validation:**

### 5. Gate Validation and Proceed

Run gate validation (`gate-validation.md`), then:
**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/architecture.md`
