---
name: architecture
description: System design + ADRs + solutioning gate + validation cycle
nextStepFile: ./stories-test-strategy.md
---
<!-- STEP_LOADED_TOKEN: architecture -->

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

### 2a. Variant-Lock Evidence Requirement (when ADR offers multiple variants)

When an ADR offers two or more implementation variants distinguished
by a runtime hypothesis (latency cause, race window, ordering, retry
shape, transport behavior), the ADR MUST require Day-1 implementation
to commit a variant-lock artifact that includes BOTH:

- **(a) Reproduction of the failure mode under controlled conditions.**
  The hypothesis the variants address must be empirically observed,
  not assumed. If the failure cannot be reproduced before Day-1, the
  ADR must default to the variant with smallest blast radius and flag
  the lock as "hypothesis-pending-evidence."
- **(b) Measurement of each variant's behavior against the
  reproduction.** Run each variant against the reproduced failure
  mode and record observable result. The chosen variant is the one
  the measurement supports.

A variant-lock artifact that documents only the chosen path's
rationale without comparison evidence fails this requirement at
gate-validation Check 3 (architecture). Violation: revert variant
lock and re-author with comparison data before continuing.

### 2b. Framework Default Audit for Security-Relevant Properties

When an ADR accepts a framework or cloud-construct default value
(AWS CDK, Terraform module, library config) on any property that
affects authentication, TLS, authorization, network exposure, or
data retention, the ADR MUST record the default value explicitly
and state WHY the default is acceptable for this project's threat
model. "We used the default" is not sufficient — the default's
literal value and its security implications must be in the ADR
body, not left implicit. Gate FAILS at architecture gate if any
security-relevant property is accepted as "default" without the
literal value + acceptability rationale in the ADR.

### 3. Solutioning Gate

Invoke `/bmad-check-implementation-readiness` style check — validate
design coherence against PRD. Fix any misalignment found.

### 4. Validation Cycle (Rule 8)

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
   **Then run auto-handoff evaluation** (see `gate-validation.md`
   "Auto-handoff evaluation") at `Seam D` with the label
   `architecture adversarial pass <N>`. If evaluation returns FIRE,
   the session ends; otherwise continue.
   **When the final pass produces only nitpicks, immediately proceed to step 4:**
4. Append a changelog to the architecture doc.
   **Then immediately proceed to gate validation:**

### 5. Gate Validation and Proceed

Run auto-handoff evaluation at `Seam B` with the label
`architecture end-of-step pre-gate` (see `gate-validation.md`
"Auto-handoff evaluation"). If evaluation returns CONTINUE, run
gate validation (`gate-validation.md`), then:
**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/stories-test-strategy.md`
