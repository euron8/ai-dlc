---
name: stories-test-strategy
description: Readiness check + epics/stories + sprint planning + test strategy + validation
nextStepFile_ui: ./ui-direction.md
nextStepFile_no_ui: ./implementation.md
---

# Stories and Test Strategy (Phase 2d-f)

**Purpose:** Implementation readiness, story creation, sprint planning,
and test strategy with full validation cycle.

## EXECUTION SEQUENCE

### 1. Implementation Readiness

Invoke `/bmad-check-implementation-readiness` — validate PRD + architecture
have everything needed for stories. Fix all gaps directly in the source
artifacts.

### 2. Epics and Stories

Invoke `/bmad-create-epics-and-stories` — break work into prioritized
stories with clear acceptance criteria.

- For **feature**: create stories for the new feature ONLY. Include
  migration/refactoring stories if architecture needs changes.
- For **brownfield-a**: create stories for REMAINING work only. Do not
  create stories for already-completed features unless flagged for rework.
- For **carry-over**: create stories from the carry-over items that
  passed evaluation. The carry-over-evaluation step scoped and validated
  the items; this step creates the actual story files with full ACs.
- Order dependencies explicitly. Reference existing stories by ID.

### 2a. Propagate Locked Requirements to Stories (Rule 8)

For each story created, propagate the relevant locked requirements from
the PRD's `LOCKED_REQUIREMENTS` block into the story file. Each story
gets its own `LOCKED_REQUIREMENTS` block containing only the requirements
that story is responsible for delivering. The story block must also
include:
- Source reference (carry-over item #, user input quote, escalation spec)
- Which PRD requirement(s) this story satisfies

Stories that do not trace back to a locked requirement (e.g., pure
technical stories, migration stories) do not need the block.

### 3. Sprint Planning

Invoke `/bmad-sprint-planning` — select stories for the sprint.

**Multi-sprint phasing check (Rule 9):** If the total story count exceeds
what can be delivered in a single sprint (typically 3-5 stories), or if
risk assessment suggests phasing:
- Split into multiple sprints autonomously
- Document phasing rationale
- Define phase boundaries ensuring each phase delivers standalone value
- The implementation step will execute sprint 1, deploy, signal human,
  then wait for validation before proceeding to sprint 2

### 4. Story Validation Cycle (Rule 3)

1. `/bmad-party-mode` — SM, Dev, Architect, TEA walk through EVERY story.
   Every acceptance criterion, every edge case, every dependency.
   Apply all improvements.
   **Requirement fidelity check:** For each story derived from a carry-over
   item or user instruction, verify: does every AC preserve the specific
   details from the source requirement?
2. `/bmad-review-adversarial-general` — 2+ passes on stories. Focus on
   missing acceptance criteria, untestable criteria, scope creep, missing
   NFRs. Apply all fixes.
   **Source fidelity pass:** Verify stories implement what was requested,
   not a different or lower-effort alternative.
3. Append a changelog to each story file.

### 5. Test Strategy

1. `/bmad-agent-tea-tea` then select test strategy — risk-based test
   strategy for the sprint
2. Tea quality gates — define quality gates and release criteria
3. `/bmad-review-adversarial-general` — review test strategy. Apply fixes.

### 6. UI Detection and Routing

Scan all sprint stories for new visual surfaces (new UI components, pages,
layout changes):

- If **new visual surfaces found**: set `is_ui_epic = true`
  Run gate validation (`gate-validation.md`), then:
  **READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/ui-direction.md`

- If **no new visual surfaces**: set `is_ui_epic = false`
  Run gate validation (`gate-validation.md`), then:
  **READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/implementation.md`
