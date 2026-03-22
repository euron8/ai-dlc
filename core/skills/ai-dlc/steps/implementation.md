---
name: implementation
description: Transition to Agent Teams lead, spawn teammates, create tasks, orchestrate build
nextStepFile: ./sprint-review.md
---

# Implementation (Phase 3)

**Purpose:** Transition from planning to Agent Teams lead. Spawn
teammates, create tasks, orchestrate the build/review/QA cycle.

## EXECUTION SEQUENCE

### 1. Context Loading

Read sprint stories from `_bmad-output/planning-artifacts/stories/`.
Read `_bmad-output/implementation-artifacts/sprint-status.yaml`.
Read the architecture document.

### 2. Create Agent Team

Create an agent team.

Spawn the following teammates using role files in `.claude/team-roles/`:
- **dev** from `dev.md` — model: {dev_model}. Assign ownership based on
  story scope per the ownership paths defined in the dev role file.
  <!-- {dev_model}: The model used for dev teammates (e.g., claude-sonnet-4-6) -->
- **code-reviewer** from `code-reviewer.md` — model: {reviewer_model}.
  Read-only, produces reviews in docs/reviews/.
  <!-- {reviewer_model}: The model used for code review (e.g., claude-opus-4-6) -->
- **qa** from `qa.md` — model: {qa_model}. Validates acceptance criteria,
  runs tests.
  <!-- {qa_model}: The model used for QA (e.g., claude-sonnet-4-6) -->

Spawn additional dev teammates if stories span multiple ownership
boundaries (e.g., dev-frontend + dev-backend).

### 3. Create Task List

Create tasks from sprint stories. For every dev task, create three
follow-up tasks with dependencies:
1. Code review task → assigned to code-reviewer, blocked by dev task
2. QA validation task → assigned to qa, blocked by code review
3. Story validation (`/validate-story`) → blocked by QA

### 4. Self-Validate Task List

Verify:
- Every sprint story has a corresponding task
- Dependencies are correct (review blocked by dev, QA blocked by review)
- Teammate assignments match story scope and ownership boundaries
- No story is assigned to a teammate outside their ownership boundary

Log task list validation in gate log.

### 5. Begin Implementation

Instruct all teammates:
- Read `docs/coding-conventions.md` before writing or reviewing code
- Read architecture doc and assigned story files before writing code
- Use three-tier escalation model (Rule 4)
- Update sprint-status.yaml in same commit as story status changes

**Dev teammates — mandatory evidence requirements:**
- Before each commit: run `git diff --staged` and verify every changed
  file is within the story's stated scope. Log the diff summary in the
  story file under "Scope Verification". Out-of-scope changes must be
  stashed or committed separately.
- For rename/refactor stories: run grep for old identifier across ALL
  project files. Log the grep command and output in the story file.
  Zero matches required before submitting for review.
- For stories touching financial calculations: run live smoke tests
  ({smoke_test_command}) and log output in the story file. Unit tests
  alone are not sufficient.
  <!-- {smoke_test_command}: Command to run live smoke tests (e.g., python3 -m pytest tests/test_smoke.py -v) -->
- For stories adding API/schema fields: run schema introspection to
  verify fields exist in the live schema BEFORE committing the query
  change. Log introspection result in the story file. Gate validation
  check #10 will verify this evidence exists.
  <!-- Customize the introspection approach for your project's API layer -->
- Populate Dev Agent Record completely — no empty placeholders. Gate
  validation check #4 will reject templates with `{{...}}`.
- Update sprint-status.yaml in the same commit as story Status: change.
  Gate validation check #5 will reject mismatches.

**Code reviewer — mandatory severity rules (see code-reviewer.md).**
**QA — validate every AC, send failures to dev, re-validate.**

### 6. Orchestrate

Monitor task progress:
- Detect blocked teammates and resolve deadlocks
- Mediate file conflicts between teammates
- When code reviewer sends findings → ensure dev applies ALL fixes
- When QA sends failures → ensure dev fixes and QA re-validates
- Track gate approvals (gate1: code review, gate2: QA, gate3: story validation)

### 7. All Gates Passed

When ALL sprint stories have passed all three gates:
**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/sprint-review.md`
