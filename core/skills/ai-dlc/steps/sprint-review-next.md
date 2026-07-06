---
name: sprint-review-next
description: Validate next sprint's stories before implementation begins — required between multi-sprint transitions
nextStepFile: ./implementation.md
---
<!-- STEP_LOADED_TOKEN: sprint-review-next -->

# Next Sprint Validation

**Purpose:** Before implementing the next sprint, validate its stories
against what was learned during the previous sprint. This step exists
because multi-sprint transitions must not skip the validation cycle —
the previous sprint's implementation may have surfaced issues that
affect upcoming stories.

## EXECUTION SEQUENCE

### 1. Context Loading

Read:
- The next sprint's stories from `_bmad-output/planning-artifacts/stories/`
- The previous sprint's retro (if it exists) or gate log
- Code reviews from the previous sprint in `docs/reviews/`
- Escalations from `docs/escalations/pending.md`
- The architecture document (may have been updated during previous sprint)
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

If any story needs modification, update it directly. If a story is no
longer needed, mark it as `skipped` in sprint-status.yaml with a
rationale.

### 3. Story Validation Cycle (Rule 8)

**Execute all sub-skills back-to-back without pausing for human input
between them:**

1. `/bmad-party-mode` — SM, Dev, Architect, TEA (bound via the **Rule 20 role-manifest preamble** to their `.claude/team-roles/<role>.md`) walk through EVERY
   story in this sprint. Every acceptance criterion, every edge case,
   every dependency. Apply all improvements.
   **Cross-sprint check:** For each story, verify it accounts for
   patterns, APIs, and components introduced in the previous sprint.
   **Run sub-step snapshot update** (see `gate-validation.md` "Sub-step
   snapshot update"). **Then immediately proceed to step 2:**
2. `/bmad-advanced-elicitation` — probe every story's requirements,
   acceptance criteria, and edge cases until zero ambiguity remains.
   Update story files with all findings.
   **Run sub-step snapshot update. Then immediately proceed to step 3:**
3. `/bmad-review-adversarial-general` — 2+ passes on stories. Focus on
   missing acceptance criteria, untestable criteria, scope creep,
   missing NFRs, cross-sprint consistency, and over-engineering
   (Rule 26: ACs demanding mechanism no locked requirement needs —
   propose removals). Apply all fixes.
   **Run sub-step snapshot update after each adversarial pass.**
   **Then run auto-handoff evaluation** (see `gate-validation.md`
   "Auto-handoff evaluation") at `Seam D` with the label
   `sprint-review-next adversarial pass <N>`. If evaluation returns
   FIRE, the session ends; otherwise continue.
   **When the final pass produces only nitpicks, immediately proceed to step 4:**
4. Append a changelog to each modified story file.
   **Then immediately proceed to Commit Updated Stories:**

### 4. Commit Updated Stories

If any stories were modified, commit the changes:
`docs(planning): sprint N stories updated after sprint N-1 validation`

### 5. Gate Validation and Proceed

Run auto-handoff evaluation at `Seam B` with the label
`sprint-review-next end-of-step pre-gate` (see `gate-validation.md`
"Auto-handoff evaluation"). If evaluation returns CONTINUE, run
gate validation (`gate-validation.md`), then:
**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/implementation.md`
