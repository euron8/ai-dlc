---
name: sprint-review-next
description: Validate next sprint's stories before implementation begins — required between multi-sprint transitions
nextStepFile: ./implementation.md
---
<!-- STEP_LOADED_TOKEN: sprint-review-next -->

# Next Sprint Validation

**Purpose:** Before implementing the next sprint, validate its stories
against what was learned during the previous sprint. A multi-sprint
transition must not skip the validation cycle — the previous sprint's
implementation may have surfaced issues that affect upcoming stories.

## EXECUTION SEQUENCE

### 1. Context Loading

Read:
- The next sprint's stories from `_bmad-output/planning-artifacts/stories/`
- The previous sprint's retro (if it exists) or gate log
- Code reviews from the previous sprint in `docs/reviews/`
- Escalations from `docs/escalations/pending.md`
- The architecture document — slice-read the current-state head and any
  sections changed in the previous sprint (Rule 25(b)); do NOT whole-read this
  large living artifact. Use `docs/architecture-index.md` to spot changed sections.
- `_bmad-output/implementation-artifacts/sprint-status.yaml`

### 2. Story Relevance Check

For each story in the upcoming sprint, verify:

- **Still relevant:** Does the story still make sense given what was
  built in the previous sprint? Implementation sometimes resolves
  problems that later stories were designed to address.
- **Dependencies met:** Are all dependencies from the previous sprint
  satisfied? Check that prerequisite stories are marked `done`.
- **No new conflicts:** Do any previous sprint decisions, escalations,
  or code review findings affect these stories?
- **ACs still accurate:** Do the acceptance criteria still reflect the
  desired behavior given the current state of the codebase?

If any story needs modification, the modification is authored through the
§3 validation cycle (SM/dev via the story sub-skills), not edited inline by
the lead. Marking a story `skipped` in sprint-status.yaml with a rationale
is orchestration bookkeeping and stays on the lead.

### 3. Story Validation Cycle (Rule 8)

Run the validation cycle (`_gate-procedures.md`, "Validation cycle") on this
sprint's stories — its passes use the **Adversarial review dispatch** and
**Adversarial repair dispatch** sub-routines. Parameters:
- **party-mode seats / subject:** SM, Dev, Architect, TEA — every story in this
  sprint: every acceptance criterion, every edge case, every dependency.
- **cross-sprint check:** for each story, verify it accounts for patterns, APIs,
  and components introduced in the previous sprint.
- **adversarial focus:** missing acceptance criteria, untestable criteria, scope
  creep, missing NFRs, cross-sprint consistency, and over-engineering (Rule 26:
  ACs demanding mechanism no locked requirement needs — propose removals).
- **`Seam D` label:** `sprint-review-next adversarial pass <N>`.
- **on convergence:** append a changelog to each modified story file, then proceed
  to Commit Updated Stories.

### 4. Commit Updated Stories

If any stories were modified, commit the changes:
`docs(planning): sprint N stories updated after sprint N-1 validation`

### 5. Gate Validation and Proceed

Run auto-handoff evaluation at `Seam B` with the label
`sprint-review-next end-of-step pre-gate` (see `_gate-procedures.md`
\"Auto-handoff evaluation\"). If evaluation returns CONTINUE, run
gate validation [story] (`gate-validation.md`), then:
**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/implementation.md`
