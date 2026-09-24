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

Read sprint stories from `_bmad-output/planning-artifacts/s<N>/stories/`.
Read `_bmad-output/implementation-artifacts/sprint-status.yaml`.
Slice-read the architecture document (SKILL.md Rule 25(b)): its current-state
head plus only the section(s) the sprint's stories name in `architecture_refs`
— never the whole file. Use `docs/architecture-index.md` to locate sections when
a story lacks refs.

### 2. Create Agent Team

Create an agent team.

A backgrounded repair on the entering gate does not delay this spawn. The
lead dispatches the story dev now and joins the repair on its own beat;
Section 7 holds the land bar until that gate PASSes.

Spawn the following teammates using role files in `.claude/team-roles/`.
Each spawn MUST bind the FULL role contract, not just the model
(SKILL.md Rule 19):

**(a) Model.** Every Agent tool invocation dispatching a role with a
rendered `.claude/agents/<role>.md` MUST name that role as
`subagent_type`; the definition is the binding for both model and
effort (SKILL.md Rule 19(a)), and the dispatch guard deletes any
`model` param on that path rather than injecting one. For a role with
no matching definition, the `model` parameter MUST still be set
explicitly, to `aiDlcRoles.<role>.model` in `.claude/settings.json`, as
the dispatch-guard-enforced net on that fallback path — do NOT
hardcode a role-to-model table here. Omitted `model` on the fallback
path inherits from the parent conversation and bypasses the role
contract.

**(b) Role contract.** Every dispatch prompt MUST carry the standing
line — byte-identical across dispatches, in the shared block (see
Dispatch-prompt cache discipline below): *"Your operating contract is
`.claude/team-roles/<role>.md`. Read it and follow it as your FIRST
action before any other work."* The subagent reads its own
identity/ownership/constraints/escalation from that file (Rule 19(b));
the lead does not restate them per dispatch.

**(c) No `name`.** A role-bound dispatch MUST NOT pass a `name`
parameter (SKILL.md Rule 19(c)) — doing so drops the definition's
effort binding. Reach the spawned hand afterward by `SendMessage` to its
`ListAgents` agent id.

Violation of (a), (b), or (c) fails gate-validation Check 22 on
detection at retro. Per SKILL.md Rule 19.

**Pre-dispatch routing (Rule 28).** Before dispatching for any story,
the lead MUST inspect the story's frontmatter for a **routing tag** and,
if one is present, bind the routed role (per Rule 19(a)+(b)) instead of
the default `dev`. The flag→role map is canonical in
`stories-test-strategy.md` "Story Routing Tags" — bind from that map, do
NOT hardcode a second copy here. The two routes today:

- `protected_path_editor: true` → dispatch the story to a
  `protected-path-editor` teammate (from
  `.claude/team-roles/protected-path-editor.md`) — NOT execute it inline
  (Rule 28: protected-path editing is delegable, not lead-only) and NOT
  delegate it to a dev teammate. The `protected-path-editor` returns a
  review-ready diff; the lead reviews the diff before merging it (the
  lead-owned safety on a delegated edit). Stories with
  `single_dev_serialized: true` MUST NOT be dispatched to parallel
  teammates that touch the same protected file — protected-path stories
  are dispatched one at a time.
- `escalate_model: true` → dispatch the story to a `dev-escalated`
  teammate (from `.claude/team-roles/dev-escalated.md`) instead of
  `dev`. Same Dev contract, stronger (opus-tier) model. Do NOT instead
  pass a higher `model` param to a `dev` dispatch — the dispatch guard
  binds `dev`'s model to `dev.md`'s pin and rebinds a call-site override
  back to it, so a higher `model` on a `dev` dispatch is silently corrected
  to dev's tier, never honored. Escalation is a ROLE, not a call-site param.

Lead MAY invoke validation sub-skills via the Skill tool per Rule 20.
Catalog and field semantics defined in `stories-test-strategy.md` "Story
Routing Tags" subsection. Violation fails gate-validation Check 22 on
detection at retro.

**Pre-dispatch auth check.** Before any dev dispatch, run:
```
gh auth status
```
MUST succeed. Failure = HARD_BLOCK (environment not authenticated).


**The dispatch protocol — READ AND FOLLOW `_dispatch-protocol.md` before
issuing the first `Agent` call of this step.** That file carries the full,
binding text of: worktree-explicit dev dispatch (the 8-point protocol,
including the no-`git stash` standing line and the worktree-relative
deliverable-path rule); the bounded-join dispatch mandate (Rule 29 — dispatch
`run_in_background: true`, join on the deliverable file with
`wait-for-deliverable.sh`, end the turn, and never yield on an outstanding
join without a live beat armed); bounded-join ≠ serial execution and the
wave-DAG planning output; dispatch-prompt cache discipline; the dev-brief
bug-class checklist; the canonical-story-file pre-flight check; and the
dev-dispatch exploration budget. Load it once per sprint at the first
dispatch and follow it at every later one.

- **dev** from `dev.md`. Assign ownership based on story scope per the
  ownership paths defined in the dev role file.
- **code-reviewer** from `code-reviewer.md`. Read-only, produces reviews
  in docs/reviews/. For a capital-path or high-blast-radius diff, dispatch a
  `code-reviewer-escalated` teammate (from `code-reviewer-escalated.md`)
  instead — same review contract, stronger (opus-tier) model. As with
  `dev-escalated`, escalation is a ROLE, not a call-site `model` param: a
  higher `model` on a plain `code-reviewer` dispatch is silently corrected to
  the standard tier by the dispatch guard.
- **qa** from `qa.md`. Validates acceptance criteria, runs tests.

Spawn additional dev teammates if stories span multiple ownership
boundaries (e.g., dev-frontend + dev-backend).

### 3. Create Task List

Create tasks from sprint stories. For every dev task, create three
follow-up tasks with dependencies:
1. Code review task → assigned to code-reviewer, blocked by dev task
2. QA validation task → assigned to qa, blocked by code review
3. Story validation → blocked by QA. Gate 3 is a lead-run
   `gate-validation.md` declared `[implementation]`; no sub-skill performs it.

### 4. Self-Validate Task List

Verify:
- Every sprint story has a corresponding task
- Dependencies are correct (review blocked by dev, QA blocked by review)
- Teammate assignments match story scope and ownership boundaries
- No story is assigned to a teammate outside their ownership boundary
- Every teammate spawn in Step 2 bound the full role contract per
  SKILL.md Rule 19: (a) the Agent tool `model` parameter was passed and
  matches the role's `/model` directive, and (b) the dispatch carried
  the standing role-contract line binding the subagent to
  `.claude/team-roles/<role>.md`. You do NOT hand-record these:
  `ai-dlc-dispatch-guard.sh` writes one row per dispatch to
  `_bmad-output/spawn-ledger.jsonl` at PreToolUse, and Check 22 reads
  that. READ the ledger here and confirm it matches what you believe you
  dispatched — a row with `role_contract_cited: false` or
  `role_file_readable: false` is a Rule 19 violation you can still fix
  before the gate. `role_contract_cited` is true when the prompt OR the
  definition the dispatch selected delivered the (b) line, and
  `contract_via` says which; it records delivery, not the teammate's read. Do not restate the ledger's contents in the gate log
  as a substitute for it; a table you write about your own dispatches is
  what Check 22 stopped relying on.
- Every story tagged `protected_path_editor: true` was dispatched to a
  `protected-path-editor` teammate (serialized), not executed inline by
  the lead and not delegated to a dev. Record the dispatch in the gate
  log.
- Every story tagged `escalate_model: true` was dispatched to a
  `dev-escalated` teammate, not to a plain `dev`. Record the dispatch in
  the gate log.

Log task list validation in gate log.

### 5. Begin Implementation

Instruct all teammates:
- Read `docs/coding-conventions.md` before writing or reviewing code
- Slice-read the architecture doc — only the section(s) named in the story's
  `architecture_refs` (Rule 25(b)), never whole — and read assigned story files
  before writing code
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
  - If this project declares derivable story fields, run
    `scripts/ai-dlc/sprint-status.sh derive-stories` instead of hand-editing
    the entry: it rewrites each declared field's value from the story file into
    both canonical copies, touching only the value token and leaving field
    order, inline comments and block scalars byte-verbatim. **THE WRITE
    BELONGS HERE AND NOT AT THE GATE** — check #5 runs `--check`, which reports
    and never writes, because a gate that edits the artifact it is validating
    can pass a tree it just changed. An undeclared list is a worklist line and
    exit 0, so a project that has not adopted this is unaffected.
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

**Gate type for validation loading (Rule 21 / Lever 2).** The gates run
at this step are `implementation` gates — when running gate validation
(`gate-validation.md`) at gate1/gate2/gate3, declare it `run gate
validation [implementation]` so the loader loads the implementation
slice (universal core + Checks 5, 6, 8, 9, 10, 11, 11a, 19, 22).

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
run a sub-step snapshot update (see `_gate-procedures.md` \"Sub-step
snapshot update\") after every story transition: ready-for-dev →
in-progress, in-progress → review, review → done. Each transition
appends a Recent Activity line naming the story ID, new status,
and teammate. This keeps the snapshot reflective of mid-sprint
state so a `/compact` or handoff mid-implementation does not lose
visibility into which stories are in-flight.

**And the lead MUST run one AT DISPATCH — in the same turn as the
`Agent` call, before the first wait beat.** A wave dispatched in one
message writes one update covering every teammate in it: a row per
teammate in **In-Flight Teammates**, carrying its deliverable path.

A transition-time write cannot substitute: a teammate is at risk from
dispatch until join, which is exactly the window in which no transition
has happened yet.

**Minimum mechanism (Rule 26(c)) — the dispatch-time In-Flight
Teammates row.** Failure caught: the lead cannot address a dispatched
teammate, reads that as teammate *death*, and re-dispatches work still
running or already delivered. False-positive
cost: one table row per dispatch, written in a snapshot update the lead
already runs; deleted at join, or held as `delivered-reachable` while the
teammate can still be messaged. Removal condition: retire once the harness
gives the lead a handle that both survives compaction and is valid for
the spawn shape it used.

**Auto-handoff evaluation after each story transition (Seam C).**
After each sub-step snapshot update in this step, the lead MUST
invoke auto-handoff evaluation (see `_gate-procedures.md`
\"Auto-handoff evaluation\") at `Seam C` with the label
`implementation story transition <story-id> <from-status>→<to-status>`.
If all preconditions hold — including
`auto_handoff_mode: safe-seam`, red threshold confirmed under Mode
1, and no teammate awaiting orchestration — auto-handoff FIRES and
the session ends. Otherwise evaluation returns CONTINUE and
orchestration resumes.

### 7. All Gates Passed

When ALL sprint stories have passed all three gates AND the entering gate
that routed into this step has reached PASS — including any check whose
repair was dispatched in parallel with that routing:
**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/sprint-review.md`
