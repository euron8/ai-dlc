---
name: retro
description: Sprint retrospective — agent runs autonomously, human comments before close
nextStepFile: STOP
---

# Retrospective (Phase 5)

**Purpose:** Review the sprint, extract lessons, apply process
improvements. The agent runs the retro autonomously. The human gets
a chance to comment or ask questions before it closes.

## EXECUTION SEQUENCE

### 1. Context Loading

Read all artifacts from this sprint:
- Sprint stories in `_bmad-output/planning-artifacts/stories/`
- Code reviews in `docs/reviews/`
- Gate log at `_bmad-output/implementation-artifacts/gate-log.md`
- Escalation log at `docs/escalations/pending.md`
- Sprint-status.yaml
- Context-mode protection log at `_bmad-output/context-mode-protection-log.md` (if it exists)

### 2. Party Mode Retro

Execute all sub-skills back-to-back without pausing for human input
between them.

**Invoke `/bmad-party-mode` via the Skill tool.** The Skill invocation
IS the satisfier for this step — role-playing PM/Architect/Dev/SM/
TEA/QA perspectives inline in the retro doc without invoking the
Skill is a Rule 3 violation per SKILL.md, regardless of how
well-formed the output appears. This is non-negotiable.

Bring all agent perspectives (PM, Architect, Dev, SM, TEA, QA) into
the discussion:
- Walk through every story's journey from plan to merge
- What worked well in the pipeline
- What caused friction or rework
- Where requirements drifted (check LOCKED_REQUIREMENTS fidelity)
- Where evidence requirements caught issues vs where they were missed
- Process improvements to propose

**Mandatory artifacts from this step (all three):**

1. **Skill invocation evidence.** The `/bmad-party-mode` Skill tool
   call must occur in the lead's own conversation. A `SKILL_INVOCATION_PROVENANCE v1`
   block (schema in SKILL.md Rule 3) is written to the retro doc
   citing the invocation's `tool_use_id`, `invoked_at` timestamp,
   `mode` (solo or subagent), and `transcript_path`.

2. **Transcript file commit.** The party-mode transcript (all agent
   responses in full, not summarized) is committed to
   `_bmad-output/party-mode-transcripts/sprint-<N>-retro.md`. This
   file is the byte-for-byte authoritative record; the retro doc's
   "Agent findings" section in Step 3 summarizes but does not
   replace it.

3. **Provenance block cites transcript@sha.** The provenance block's
   `transcript_path` field uses the `path@<sha>` format where
   `<sha>` is the git blob SHA of the committed transcript file.
   `scripts/validate-retro-evidence.sh` enforces byte-match between
   the cited SHA and the file contents on HEAD.

Local enforcement: `scripts/validate-mandatory-rules.sh <N>` (runs
`validate-retro-evidence.sh`, `validate-cycle-commits.sh`, and
`validate-provenance-block.sh`) MUST pass before Step 6 commits the
retro. CI enforcement:
`.github/workflows/validate-retro-compliance.yml` re-runs the same
scripts on the retro PR.

### 3. Write Retro Document

Write the retro to `docs/retro/sprint-N.md` with:
- Sprint summary (planned vs delivered, rework cycles, autonomous decisions)
- Agent findings (from party mode)
- Specific, actionable improvements
- Which improvements should update CLAUDE.md, team roles, or pipeline steps

### 4. Apply Process Improvements

If the retro identifies changes needed to CLAUDE.md, team role files,
pipeline step files, or coding conventions:

**For new hard requirements (non-deferrable rules, hard gates):**
Adding rule text to one file is not sufficient. Every new hard
requirement must be enforced at ALL applicable layers:
1. **Rule definition** — coding-conventions.md or CLAUDE.md (the rule itself)
2. **Gate validation** — gate-validation.md (structural check that fails
   the gate if the rule is violated)
3. **Dev checklist** — dev.md pre-submission checklist (evidence requirement)
4. **Code review severity** — code-reviewer.md mandatory severity
   classification (missing = Critical)
5. **QA validation** — qa.md validation checklist (reject if missing)

If a retro action item says "hard gate" or "non-deferrable," it MUST
be applied at all 5 layers. Applying it to only 1-2 layers makes it
advisory, not structural.

**For advisory improvements (best practices, conventions):**
- Apply the change to the relevant file(s)

**For all improvements:**
- Document what was changed and why in the retro doc
- List which files were modified and which enforcement layers were added

**Rule text authoring:**
Follow SKILL.md Rule 18. Rules must be imperative or MUST/MUST NOT/SHALL,
state the enforcement consequence inline, and contain no origin narrative.
The WHY of each improvement goes in the commit message below, not in the
rule file.

**Rule file audit (every retro):**

After applying the process improvements above, scan the following files
for violations of SKILL.md Rule 18:

- `CLAUDE.md`
- `docs/coding-conventions.md`
- `.claude/skills/ai-dlc/steps/*.md`
- `.claude/team-roles/*.md`

Two classes of violation to detect:

**1. Narrative drift.** Rule text contains sprint/story references,
incident descriptions, "because we" justification, parenthetical origin
notes, embedded dates, or quoted retro findings.

**2. Rule weakness.** Rule text uses "should", "try to", "consider",
"prefer", "in most cases", or similar soft language where a mandate is
intended. Missing enforcement consequence where one would apply.

Per finding, judge case by case:
- Is the text part of a rule statement (prescriptive/directive), or
  prose explaining how something works (descriptive)? Descriptive prose
  is exempt from both classes.
- For narrative drift: does the bare rule still make sense when the
  narrative is removed?
  - **Yes** → strip the narrative; the WHY goes to the audit commit message.
  - **No** → the rule is leaning on the story. Rewrite it hard (see
    Rule 18 style), or mark for removal and raise during Step 5 human
    commentary.
- For rule weakness: rewrite the rule using imperative or MUST/MUST NOT/SHALL.
  If the soft language was intentional (genuine advisory preference),
  the rule does not belong in rule files — move it to the retro doc
  as a lesson or remove it.

Record audit results in the retro doc under a `## Rule File Audit`
section: files scanned, narrative drifts found (list each), rule
weaknesses found (list each), rules rewritten, rules marked for removal.

**Commit the audit as a separate commit** from the process improvements
above. Commit message:
`docs(rules): rule file audit (retro) — strip narrative, harden weak rules`

If zero violations found, skip the commit and note "Audit: clean" in
the retro doc.

**Path-filter dormancy scan (every retro):**

After the rule-file audit, enumerate CI jobs in `.github/workflows/**`
that use `paths:` or `paths-ignore:` filters. For each such job,
determine the last main-branch SHA on which the job actually ran
(not SKIPPED). If ≥3 sprints have elapsed with zero non-SKIPPED runs
on `main`, the retro MUST either (a) cite an existing `schedule:`
cron trigger on the workflow that exercises the job independent of
path filters, or (b) file a Sprint N+1 task to add a weekly
`schedule:` cron run to that workflow. Reporting-only is not
sufficient — a dormancy finding without a remediation path is
narrative drift. Record results in the retro doc under
`## Rule File Audit` in a `Path-filter dormancy scan` sub-section,
including for each dormant job: evidence
(`gh run list --workflow=<wf> --branch=main --limit 30`), sprint
window, and (a) or (b) remediation.

## Empirical gate validation

Every gate added via retro MUST be exercised on a green run within the next
PR that naturally touches the gate's enforcement domain. Absence of exercise
within that window fails the next retro. Shipping a gate wired to no workflow
trigger, or wired only to a workflow that does not run on any PR in the
exercise window, is the dormant-gate anti-pattern.

Enforcement: `scripts/validate-ci-gates.sh` runs on every pull request via
`.github/workflows/validate-ci-gates.yml`. The script scans `docs/retro/**/*.md`
for declared gate names and grep's `.github/workflows/**` for each; any
declared gate with zero workflow matches is flagged as DORMANT and the
workflow exits non-zero, failing the PR check. Retro authors MUST ship the
gate's workflow wiring in the same PR as the retro's gate declaration, or
cite the wiring PR that did.

Declaration convention: when a retro adds a new CI gate, name it using the
canonical form `` CI gate `<gate-name>` `` (the gate name enclosed in
backticks, preceded by the literal phrase "CI gate"). This is the only form
the shallow detector harvests; gate names mentioned in free-form prose are
intentionally out of scope.

### 4a. Close-Out Sweep

Implementation is supposed to close upstream items inline as stories
transition to `done` (see `implementation.md` step 5). This sweep is
the backstop: it catches items that slipped past inline closure and
ensures no sprint ends with stale OPEN/IN_SPRINT state.

**Sweep targets (run all three):**

1. **`_bmad-output/planning-artifacts/carry-over-backlog.md`.** For
   every item still marked `IN SPRINT` or `OPEN`, check whether any
   story in this sprint satisfies it. Match on story `Source:`,
   LOCKED_REQUIREMENTS references, or epic linkage. If satisfied and
   the story is `done`: mark the item `CLOSED - delivered in sprint
   <N> via <story-id>`. If the story shipped but only partially
   satisfied the item: mark `PARTIAL - sprint <N>` and keep the
   remainder open with a note on what remains. If no story touched
   it: leave as-is (it's legitimate carry-over).

2. **`docs/escalations/pending.md`.** For every entry without a
   RESOLVED or DECIDED_AUTONOMOUSLY terminal marker, check whether
   the sprint addressed it. If yes: append `RESOLVED - sprint <N> -
   <one-line outcome>`. DEFERRAL_REQUEST entries that the human
   accepted at the production validation checkpoint get `DEFERRED -
   sprint <N>` and are moved to the next sprint's carry-over
   backlog (append to `carry-over-backlog.md` as a new OPEN item
   citing the original escalation).

3. **`_bmad-output/implementation-artifacts/sprint-status.yaml`.**
   Final consistency pass: every story with `Status: done` in its
   file MUST have `status: done` in sprint-status.yaml, and vice
   versa. Gate validation check #5 enforced this per-commit; this
   sweep is the last guard against drift. Any mismatch found here is
   a retro finding — record it and fix.

**Record results in the retro doc** under a `## Close-Out Sweep`
section: carry-over items closed/partial, escalations resolved or
deferred, any status-yaml drift caught and corrected. If everything
was already closed inline, note "Sweep: clean (all items closed
inline during implementation)".

### 5. Human Commentary

Present the retro summary and ask:

"Retro complete. Any comments or questions before I close out the sprint?"

Wait for the human's response. If they have commentary:
- Incorporate it into the retro doc
- Apply any additional process changes they request
If they have nothing to add, proceed.

### 6. Commit, Push, and PR

**6a. Commit all remaining artifacts.**

Run `git status` to identify any uncommitted files. Stage and commit
everything produced during the sprint that hasn't been committed yet.
This typically includes:

**Implementation artifacts** (if not already committed per-story):
- `_bmad-output/implementation-artifacts/gate-log.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `docs/reviews/*.md` (code review output)
- `docs/escalations/pending.md` (escalation entries)

**Retro artifacts** (produced in steps 3-5 above):
- `docs/retro/sprint-N.md` (the retro document)
- Any files modified by process improvements (CLAUDE.md, team roles,
  coding-conventions.md, pipeline step files)
- `docs/ai-dlc-feedback.md` (if updated)

**Close-out sweep artifacts** (produced in step 4a above):
- `_bmad-output/planning-artifacts/carry-over-backlog.md` (closures)
- `docs/escalations/pending.md` (resolutions and deferrals)
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
  (any drift corrections)

Use a conventional commit message:
`docs(retro): sprint N retrospective, reviews, and process improvements`

If there are no uncommitted changes, skip this step.

**6b. Push the branch.**

Push the current branch to origin:
```bash
git push -u origin HEAD
```

**6c. Determine if a PR is warranted.**

Check the current branch:
- If on `main` or `master`: No PR needed — work was committed directly.
  Announce: "Sprint [N] complete. Pipeline finished."
- If on any other branch: A PR is warranted. Proceed to 6d.

**6d. Create a pull request.**

Generate a PR using the sprint's artifacts as the source material:

- **Title:** Short description of the work (under 70 characters).
  Derive from the pipeline variant and user's original request.
  Examples: "Add user dashboard with real-time metrics",
  "Fix stale cache in search results"

- **Body:** Use the following structure, populated from sprint artifacts:

  ```
  ## Summary
  [2-5 bullet points describing what was built/fixed, derived from
  the sprint stories and retro summary]

  ## Pipeline
  - **Variant:** [pipeline variant]
  - **Stories:** [count] delivered
  - **Gate log:** see `_bmad-output/implementation-artifacts/gate-log.md`

  ## Autonomous Decisions
  [List any DECIDED_AUTONOMOUSLY entries from docs/escalations/pending.md,
  or "None" if clean]

  ## Test Evidence
  [Brief summary of test coverage — smoke tests, production integrity
  tests, QA validation results]

  ## Retro Highlights
  [1-3 key findings from the retrospective, if notable]
  ```

- Create the PR with `gh pr create` targeting the main branch.
- If `gh` is not available, provide the user with the branch name
  and suggest they create the PR manually.

**6e. Announce completion.**

Present to the user:
- PR URL (if created)
- Sprint summary (stories delivered, gate results)
- Any open escalations that need human review

Announce: "Sprint [N] complete. Pipeline finished."

### 7. Merge and Next-Sprint Handoff

This step closes the loop on the sprint and produces a copy-pasteable
`/ai-dlc` prompt for the next sprint. The prompt is authored here, not
in the next sprint's discovery step, so that retro findings, unfinished
epic scope, and residual risks are still in the lead's working context.

**7a. Merge gate.**

- **If a PR was created in 6d:**
  Ask the user: "Merge PR [#N] now? (y/n)"
  - **y:** Run `gh pr merge <N> --squash --delete-branch` (use the merge
    strategy the repo's PRs normally use; check recent merges with
    `gh pr list --state merged --limit 3 --json number,title,mergedAt`
    if unsure). If merge fails (branch protection, failing checks,
    conflicts), surface the error and stop — do not emit the next-sprint
    prompt until the user resolves and confirms merge.
  - **n:** Do not merge. Emit the next-sprint prompt immediately with a
    one-line preamble noting the PR is still open and the user should
    paste the prompt after it merges.
- **If no PR was created (direct-to-main in 6c):** Skip the merge gate
  and proceed directly to 7b.

**7b. Assemble next-sprint inputs.**

Gather the material the next-sprint prompt will draw from. Read, do not
summarize prematurely:

1. **Current epic state.** Read the active epic file under
   `_bmad-output/planning-artifacts/` (epic files are created by
   `/bmad-create-epics-and-stories` in `stories-test-strategy.md`).
   Determine:
   - Which stories in the epic are `done` vs remaining
   - Whether the epic is complete (all stories done) or in-progress
   - Any epic-level acceptance criteria not yet satisfied
2. **Carry-over candidates.** From `_bmad-output/implementation-artifacts/sprint-status.yaml`,
   list any stories with status `blocked`, `deferred`, or `skipped` that
   have a rationale indicating they should return in a future sprint.
3. **Open escalations.** From `docs/escalations/pending.md`, list any
   entries not resolved during this sprint.
4. **Unexercised gates.** Any CI gate declared in `docs/retro/sprint-N.md`
   (this sprint's retro) that has not yet run green on a PR — these must
   be exercised in the exercise window or the next retro fails (see
   "Empirical gate validation" above).
5. **Retro improvements with sprint-N+1 follow-ups.** Any action items
   in `docs/retro/sprint-N.md` tagged for the next sprint (e.g.,
   "Sprint N+1 task to add weekly schedule cron" from the path-filter
   dormancy scan).
6. **Related-epic scope candidates.** From the broader epics list in
   `_bmad-output/planning-artifacts/`, identify epics that are directly
   related to the current epic (shared components, adjacent user flows,
   or explicit dependency links). These are potential scope for the
   next sprint IF the current epic is complete or nearly so.

**7c. Derive the next-sprint theme.**

Priority order when choosing the theme:

1. **Current epic not complete** → theme = continue/finish the current
   epic. Scope = remaining epic stories + any carry-over or retro
   follow-ups that block epic completion.
2. **Current epic just completed this sprint** → theme = consolidate +
   advance. Scope = retro follow-ups, unexercised gates, open
   escalations, and the most directly-related next epic as stretch
   scope.
3. **Current epic was already complete before this sprint** (sprint was
   pure carry-over or cross-cutting work) → theme = next epic in the
   prioritized list. Scope = that epic's first stories + open
   escalations.

The theme is one sentence, stated as the sprint's objective (not a
summary of inputs).

**7d. Emit the handoff block.**

Present the following verbatim to the user. The `----` lines are the
copy-paste boundaries the user requested; do not add any other content
between them.

```
Sprint [N] closed.

Next sprint theme: [one-sentence theme derived in 7c]

Scope outline (for context, not part of the prompt):
- Current epic: [epic name] — [complete | N of M stories remaining]
- Carry-over: [count] stories  ([list IDs or "none"])
- Open escalations: [count]   ([list IDs or "none"])
- Unexercised gates: [list or "none"]
- Retro follow-ups: [list or "none"]
- Related-epic stretch scope: [list or "none"]

Copy the prompt below to start the next sprint.

----
/ai-dlc

[Draft prompt body — written in the same voice the user would use.
 Lead with the theme. Then name the epic explicitly and say whether
 the goal is to continue it or close it out. Then enumerate the
 in-scope items from 7b in priority order: epic-remaining stories
 first, then carry-over, then retro follow-ups and gate exercises,
 then related-epic stretch scope last (marked "stretch"). Keep it
 under ~15 lines. Do not restate already-done work.]
----
```

Replace the bracketed placeholders with actual content. The prompt body
between the `----` markers must be directly pasteable — no meta
commentary, no "here is your prompt", no surrounding quotes.

**STOP.**
