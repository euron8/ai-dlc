---
name: architecture
description: System design + ADRs + solutioning gate + validation cycle
nextStepFile: ./stories-test-strategy.md
---

# Architecture (Phase 2c)

**Purpose:** System design decisions, ADRs, and solutioning gate with
full validation cycle.

## EXECUTION SEQUENCE

### 1. Context Loading

Read the PRD and product brief from `_bmad-output/planning-artifacts/`.

### 2. Architecture Creation or Update

- For **greenfield/brownfield-b**: invoke `/bmad-create-architecture` —
  full system design, tech decisions, ADRs
- For **feature**: Assess whether existing architecture supports this
  feature as-is. If yes, document the integration approach as an addendum.
  If no, update the architecture doc with changes needed. Use ADRs for
  every modification. Explicitly document: what stays the same, what
  changes, what is new.
- For **brownfield-a**: Document the AS-IS architecture from code, then
  target architecture for remaining work.
- For **brownfield-c**: Update architecture doc (or create if missing).
  Document TARGET state: what stays, what changes, what is new.

### 3. Solutioning Gate

Invoke `/bmad-check-implementation-readiness` style check — validate
design coherence against PRD. Fix any misalignment found.

### 4. Validation Cycle (Rule 3)

**Execute all sub-skills back-to-back without pausing for human input
between them:**

1. `/bmad-party-mode` — Architect, Dev, TEA, PM debate every design
   decision, every component boundary, every data flow. Walk through
   exhaustively. Apply all improvements.
   **Run sub-step snapshot update** (see `gate-validation.md` "Sub-step
   snapshot update"). **Then immediately proceed to step 2:**
2. `/bmad-advanced-elicitation` — probe every design assumption until
   zero ambiguity remains. Update the architecture doc with all findings.
   **Run sub-step snapshot update. Then immediately proceed to step 3:**
3. `/bmad-review-adversarial-general` — 2+ passes. Focus on security,
   scalability, coupling, single points of failure, backward
   compatibility, migration risk, integration seams. Apply all fixes
   between passes. Continue until only nitpicks remain.
   **Run sub-step snapshot update after each adversarial pass.**
   **When the final pass produces only nitpicks, immediately proceed to step 4:**
4. Append a changelog to the architecture doc.
   **Then immediately proceed to gate validation:**

### 5. Gate Validation and Proceed

Run gate validation (`gate-validation.md`), then:
**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/stories-test-strategy.md`
