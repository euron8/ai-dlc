---
name: implementation
description: Transition to Agent Teams lead, spawn teammates, create tasks, orchestrate build
nextStepFile: ./sprint-review.md
---
<!-- STEP_LOADED_TOKEN: implementation -->

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

Spawn the following teammates using role files in `.claude/team-roles/`.
Spawn using the model defined in the teammate's role file
(`.claude/team-roles/<role>.md`). The role file's `/model` directive is
the authoritative model binding.

**Agent spawn model parameter MUST be passed explicitly.** Every
Agent tool invocation MUST include the `model` parameter, derived from
that role's `/model` directive in its role file
(`.claude/team-roles/<role>.md`) — do NOT hardcode a role-to-model
table here. Omitted `model` inherits from the
parent conversation
and bypasses the role contract. Violation fails gate-validation
Check 15 on detection at retro. Per SKILL.md Rule 19.

**Protected-path lead-only enforcement.** Before dispatching dev for
any story, the lead MUST inspect the story's frontmatter for
`lead_only: true`. If set, lead MUST execute the story itself — no
Agent/Task delegation to dev teammate roles. Lead MAY invoke
validation sub-skills via the Skill tool per Rule 20. Stories with
`single_dev_serialized: true` MUST NOT be dispatched to parallel
teammates that touch the same protected file. Catalog and field
semantics defined in `stories-test-strategy.md` "Protected-Path
Story Tag" subsection. Violation fails gate-validation Check 15 on
detection at retro.

**Pre-dispatch auth check.** Before any dev dispatch, run:
```
gh auth status
```
MUST succeed. Failure = HARD_BLOCK (environment not authenticated).

**Worktree-explicit dev dispatch.** The Agent tool's
`isolation: worktree` parameter is NOT a reliable isolation mechanism
when combined with `subagent_type: general-purpose` — multiple parallel
devs collapse into shared CWD and branch-thrash each other. Lead MUST
follow the worktree-explicit dispatch protocol:

0. Lead MUST commit all planning artifacts the dev needs (story
   files, analysis docs, sprint-status.yaml) to the sprint branch
   BEFORE pre-creating any dev worktree. The worktree base MUST
   contain the canonical story file by construction; a worktree cut
   from a HEAD that predates the artifact commit strands the dev
   without its story spec and forces teardown + recreate. Violation:
   dispatch rework; surface at retro.
1. Lead pre-creates a physical worktree per dispatched story BEFORE
   issuing the Agent call:
   `git worktree add <repo>-s<N>-story-<X> -b dev/sprint-<N>/story-<X> <sprint-branch-HEAD>`
2. Dev branches MUST branch off the current sprint-branch HEAD at
   dispatch time. The lead MUST NOT branch dev worktrees off `main`
   unless the sprint branch has not diverged from main.
3. The Agent call MUST set `mode: "bypassPermissions"` and include
   the worktree absolute path in the prompt. The dev prompt MUST
   instruct the dev to `cd` into the worktree as its first action.
4. On story completion, the lead merges the dev branch into the
   sprint branch and removes the worktree:
   `git merge dev/sprint-<N>/story-<X> && git worktree remove <path>`
5. If merge conflicts arise, the lead resolves them — not the dev.
6. Every dispatch brief into a worktree (dev, code reviewer, or QA)
   MUST include this standing line: "Never run `git stash` or `git
   stash pop` inside this worktree. All worktrees under one repository
   share a single stash stack, so a stash or pop here can surface or
   consume an UNRELATED stash from another worktree. For a before/after
   base compare, use `git worktree add --detach <base>` instead." Keep
   it in the dispatch template, not per-sprint prose the lead must
   remember to re-add. Failure caught: a cross-worktree stash collision
   that silently mutates another dev's working tree. False-positive
   cost: none — an isolated alternative (`--detach`) is provided.
   Removal condition: only if worktrees under one repository stop
   sharing a single stash stack (a git invariant today).

**Foreground-dispatch mandate.** A gated story-dev cycle is
synchronous: the lead's immediate next action reads the dev's result
and routes it into gate-1. The lead MUST dispatch gated story-dev and
fix-forward dev agents in the FOREGROUND — a blocking Agent call whose
result the lead consumes. `run_in_background: true` is PERMITTED ONLY
for detached work with no near-term gate the lead must consume
(monitoring loops, polling a long-running job, observation windows
during which the lead has other non-dependent work). Backgrounding a
gated dev cycle detaches the producer from a consumer blocked on it and
stalls the orchestration turn. Violation is a lead-conduct retro
finding.

**Foreground-dispatch ≠ serial execution.** "Foreground" governs HOW a
dev is dispatched (a blocking Agent call the lead consumes), NOT how
MANY run at once. Independent stories MUST be dispatched in parallel —
in ONE message, each in its own worktree, joined on all results.
Parallelism comes from per-story worktrees plus a join, NEVER from
`run_in_background`. The lead SHALL serialize two stories ONLY on a
real dependency: a shared source file both stories write, or a
by-content gate dependency (story B's gate-1 reads story A's merged
output). Before the first dispatch the lead MUST emit, as a written
planning output, a **story dependency-DAG + wave plan**: for each
story, the files it owns and the stories it genuinely depends on, with
wave grouping derived from it (independent stories → same wave /
parallel; shared-file or by-content chains → serialized land-order). A
default-to-serial dispatch the operator must challenge to parallelize,
or a missing / after-the-fact wave-DAG, is a lead-conduct retro
finding.

**Minimum mechanism (Rule 26(c)) — the wave-DAG planning output.**
Failure caught: silent over-serialization — independent stories queued
behind a chain they share no files with, wasting wall-clock and
parallel capacity; and its inverse, parallel dispatch of two stories
that write the same file, causing merge thrash. False-positive cost:
one written dependency-DAG + wave grouping per sprint before dispatch.
Removal condition: retire once dispatch parallelism is derived
mechanically from a per-story file-ownership manifest rather than lead
judgment.

**Dispatch-prompt cache discipline.** When dispatching multiple
teammates (parallel devs, or a dev plus QA on the same story), order
each dispatch prompt as a **stable shared block first, variable tail
last**. The shared block — sprint conventions, architecture pointer,
role expectations, branch/merge protocol — MUST be byte-identical
across every dispatch in the sprint. Put only the per-story content
(worktree path, story id, acceptance criteria, dev-brief findings)
after it. Prompt-cache entries are content-addressed: an identical
leading block means the first dispatch writes it and every later
dispatch reads it from cache instead of re-writing. Reordering or
re-wording the shared block per dispatch defeats this and forces a
cold write on each spawn.

**Dev-brief bug-class checklist.** When the dev-brief includes a
bug-class finding from the code-reviewer (see `code-reviewer.md`
bug-class audit mandate), the dev MUST grep for same-shape call-sites
listed in the finding and verify each one in the fix commit. The
dev record MUST cite the grep command and match count. Partial
enumeration (fixing the reported instance but not grepping for
siblings) fails gate-validation.

**Canonical-story-file pre-flight check before dev dispatch.** Before
dispatching dev for any story, the lead MUST verify two conditions:
(a) the canonical story file exists at
`_bmad-output/planning-artifacts/stories/story-<id>-*.md`; (b) the
canonical story file is reachable on the dev's branch base (on `main`
or merged into the sprint branch before dev spawn). If (b) fails
because the canonical spec lives on an unmerged PR, the lead MUST
either merge that PR first or pin the dev branch base to a commit
that includes it. Dispatching dev without both conditions satisfied
is a story-scope failure mode. Violation fails gate-validation
Check 15 on detection at retro.

**Dev-dispatch exploration budget.** Every dev brief MUST bound
exploration and force an early write. The brief MUST state: (a) an
explicit read ceiling (default: ≤15 file reads before the first code
write); (b) a mandatory early-scaffold commit — commit function
signatures and file structure before filling bodies, so a mid-work
interruption loses body-fill, not the entire output; (c) if the dev
nears its budget without committed code, it MUST priority-order the
remaining acceptance criteria, implement top-down, and report
DONE-vs-REMAINING per AC. A brief omitting (a)+(b)+(c) is
dispatch-incomplete.

- **dev** from `dev.md`. Assign ownership based on story scope per the
  ownership paths defined in the dev role file.
- **code-reviewer** from `code-reviewer.md`. Read-only, produces reviews
  in docs/reviews/.
- **qa** from `qa.md`. Validates acceptance criteria, runs tests.

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
- Every teammate spawn in Step 2 passed the Agent tool `model`
  parameter per SKILL.md Rule 19. Record the spawned model per
  teammate in the gate log.

Log task list validation in gate log.

### 5. Begin Implementation

Instruct all teammates:
- Read `docs/coding-conventions.md` before writing or reviewing code
- Read architecture doc and assigned story files before writing code
- Use three-tier escalation model (Rule 12)
- Implement the smallest diff that satisfies the ACs (SKILL.md Rule
  26): no speculative abstraction, no parallel path beside a proven
  one, no guard machinery the story does not require
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
- On story transition to `done`, close out any upstream source item the
  story satisfies — do not defer to retro:
  - If the story traces to a carry-over backlog item: update
    `_bmad-output/planning-artifacts/carry-over-backlog.md`, change the
    item's status from `IN SPRINT` to `CLOSED - delivered in sprint <N>
    via <story-id>` in the same commit as the story Status: change.
  - If the story resolves an entry in `docs/escalations/pending.md`:
    append `RESOLVED - <sprint>/<story-id> - <one-line outcome>` to the
    entry in the same commit.
  - If neither applies, skip. Tracing is determined by reading the
    story's LOCKED_REQUIREMENTS block and the `Source:` / provenance
    fields written at story creation.

**Day-1 Variant-Lock Evidence.** For any story whose plan calls for a
runtime-variant lock (per `.claude/skills/ai-dlc/steps/architecture.md`
section 2a), the dev teammate MUST commit a variant-lock artifact on Day 1
of the story containing BOTH (a) reproduction of the failure mode that
motivates the lock AND (b) measurement of each candidate variant's observed
behavior under the same conditions. Declaration-only variant-lock entries
(pick a winner without captured reproduction + measurement) are rejected at
Gate 2.

**Code reviewer — mandatory severity rules (see code-reviewer.md).**
**QA — validate every AC, send failures to dev, re-validate.**

### 6. Orchestrate

Monitor task progress:
- Detect blocked teammates and resolve deadlocks
- Mediate file conflicts between teammates
- When code reviewer sends findings → ensure dev applies ALL fixes
  (simplification/removal findings included, per Rule 7 and Rule 26(d))
- When QA sends failures → ensure dev fixes and QA re-validates
- Track gate approvals (gate1: code review, gate2: QA, gate3: story validation)

**Pre-gate commit-presence check.** Before dispatching code review
(gate1) for any story, run `git -C <worktree> log --oneline
<base>..HEAD` on the story branch and confirm at least one non-merge
commit exists. Zero commits = the dev produced no deliverable; resume
or re-dispatch the dev BEFORE gating. Gating a zero-commit story is a
process violation; surface at retro.

**DAR-fold preflight before gate-2 dispatch.** After gate1 (code
review) approves a story and BEFORE dispatching gate2 (QA), the lead
MUST fold the Dev Agent Record from the dev's completion report into
the canonical sprint-branch story file, then verify that file's Dev
Agent Record section is non-empty — a mechanical section-presence
check, the same class as gate-validation check #4's Dev Agent Record
completeness check. Failure caught: a QA reviewer dispatched against a
worktree-stale story copy reads an empty or old DAR and false-FAILs a
story whose evidence is actually complete. False-positive cost: none —
the check is a cheap section-presence test on a section the dev already
authored. Removal condition: retire this preflight once the dev's DAR
is guaranteed present in the canonical story file by the merge step
itself, making the fold redundant. Dispatching gate2 with an empty DAR
section is a retro finding.

**Worktree gate-verification freeze.** Once the lead dispatches a gate
reviewer (gate-1 code review or gate-2 QA) against a dev worktree, that
worktree is FROZEN: the dev MUST NOT push further commits to it until
the verdict lands. At reviewer dispatch the lead MUST record the exact
`git -C <worktree> rev-parse HEAD` SHA, and before recording any gate
verdict MUST re-confirm `HEAD` still equals that SHA. A HEAD advance
between dispatch and verdict VOIDS the verdict — the lead re-pins the
SHA and re-dispatches / re-verifies. The freeze is the fix (it prevents
the drift); the HEAD-confirm is the tripwire proving the freeze held.
Violation: gate verdict void + retro finding. Failure caught: a
reviewer's SHA-labeled verdict desyncing from the worktree file-state —
a mid-review commit (even a benign dead-code removal) breaks the
label→state binding, so the recorded verdict certifies a tree that no
longer exists. False-positive cost: one `rev-parse HEAD` at dispatch
plus one equality re-check at verdict — two cheap reads, no dev-side
work when the freeze is honored. Removal condition: retire once the
gate pipeline pins reviews to an immutable content ref (a tag or a PR
merge-commit) instead of a live worktree HEAD.

**Sub-step snapshot updates during implementation.** The lead MUST
run a sub-step snapshot update (see `gate-validation.md` "Sub-step
snapshot update") after every story transition: ready-for-dev →
in-progress, in-progress → review, review → done. Each transition
appends a Recent Activity line naming the story ID, new status,
and teammate. This keeps the snapshot reflective of mid-sprint
state so a `/compact` or handoff mid-implementation does not lose
visibility into which stories are in-flight.

**Auto-handoff evaluation after each story transition (Seam C).**
After each sub-step snapshot update in this step, the lead MUST
invoke auto-handoff evaluation (see `gate-validation.md`
"Auto-handoff evaluation") at `Seam C` with the label
`implementation story transition <story-id> <from-status>→<to-status>`.
If all preconditions hold — including
`auto_handoff_mode: safe-seam`, red threshold confirmed under Mode
1, and no teammate awaiting orchestration — auto-handoff FIRES and
the session ends. Otherwise evaluation returns CONTINUE and
orchestration resumes.

### 7. All Gates Passed

When ALL sprint stories have passed all three gates:
**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/sprint-review.md`
