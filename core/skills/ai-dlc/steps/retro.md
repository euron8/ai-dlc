---
name: retro
description: Sprint retrospective — agent runs autonomously, human comments before close
nextStepFile: STOP
---
<!-- STEP_LOADED_TOKEN: retro -->

# Retrospective (Phase 5)

**Purpose:** Review the sprint, extract lessons, apply process
improvements. The agent runs the retro autonomously. The human gets
a chance to comment or ask questions before it closes.

## EXECUTION SEQUENCE

### 1. Context Loading

Create the retro branch using the canonical name that
`scripts/validate-mandatory-rules.sh` expects:

```bash
git checkout -b ai-dlc/retro/sprint-<N>
```

The branch name MUST contain `sprint-<N>` (literal word "sprint"
followed by the sprint number). Abbreviated forms (`s<N>`,
`retro-<N>`) cause validation failures because the script's
branch-detection regex requires the `sprint-<N>` substring.

Read all artifacts from this sprint:
- Sprint stories in `_bmad-output/planning-artifacts/stories/`
- Code reviews in `docs/reviews/`
- Gate log at `_bmad-output/implementation-artifacts/gate-log.md`
- Escalation log at `docs/escalations/pending.md`
- Sprint-status.yaml
- Context-mode protection log at `_bmad-output/context-mode-protection-log.md` (if it exists)

Run auto-handoff evaluation at `Seam E` with the label
`retro Step 1 pre-flight` (see `gate-validation.md` "Auto-handoff
evaluation"). If evaluation returns FIRE, the session ends;
otherwise continue to Step 2.

### 2. Party Mode Retro

Execute all sub-skills back-to-back without pausing for human input
between them.

**Invoke `/bmad-party-mode` via the Skill tool.** The Skill invocation
IS the satisfier for this step — role-playing PM/Architect/Dev/SM/
TEA/QA perspectives inline in the retro doc without invoking the
Skill is a Rule 3 violation per SKILL.md, regardless of how
well-formed the output appears. This is non-negotiable.
Each agent MUST be spawned as a real subagent for independent perspective. Solo mode (roleplaying agents inline) is forbidden.

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

Local enforcement runs in Step 5c (pre-commit validation gate).
CI enforcement: `.github/workflows/validate-retro-compliance.yml`
re-runs the same scripts on the retro PR.

### 3. Write Retro Document

Write the retro to `docs/retro/sprint-N.md` with:
- Sprint summary (planned vs delivered, rework cycles, autonomous decisions)
- `hard_block_count` (integer): total HARD_BLOCKs encountered this sprint
- `hard_block_class[]`: list of HARD_BLOCK classifications (e.g., requirement-divergence, scope-conflict, infra-outage)
- Agent findings (from party mode)
  with finding-class per pass (see templates/pipeline/retro-finding-class-tracking.md)
- Specific, actionable improvements
- Which improvements should update CLAUDE.md, team roles, or pipeline steps

Retro findings asserting infrastructure topology MUST cite the
IaC source file and line (Terraform, CDK, CloudFormation, Docker
Compose, or equivalent). Agent consensus is not evidence of
topology shape.

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

Three classes of violation to detect:

**1. Narrative drift.** Rule text contains sprint/story references,
incident descriptions, "because we" justification, parenthetical origin
notes, embedded dates, or quoted retro findings.

**2. Rule weakness.** Rule text uses "should", "try to", "consider",
"prefer", "in most cases", or similar soft language where a mandate is
intended. Missing enforcement consequence where one would apply.

**3. Complexity accretion.** A gate, check, hook, guard, or rule
added in a prior sprint that lacks the Rule 26(c) contract (concrete
failure caught, false-positive cost, removal condition), or whose
false positives since introduction exceed its true catches. For each
such finding, record the catch/false-positive tally and propose
removal or narrowing as a process improvement in this retro —
machinery is removed through the same Step 4 mechanism that added it.

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
weaknesses found (list each), complexity accretions found (list each
with catch/false-positive tally), rules rewritten, rules marked for
removal.

If the audit produced file changes, do NOT commit them yet — Step 5c
handles the audit commit as a separate commit before the main retro
commit in Step 6.

If zero violations found, note "Audit: clean" in the retro doc.

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

**Deferral-freshness reconciliation (run BEFORE the three sweeps,
MANDATORY).** For every carry-over deferral, re-affirmed deferral, or
passive monitor whose blocking or monitored condition is a runnable
test, anchor, query, or observable event, the lead MUST re-verify that
condition LIVE at close-out — run the cited test, query the cited
source, or read the monitored signal. If the condition is now satisfied
(test green where it was held red, event observed, value in-band), the
item is reclassified `CLOSED - delivered in sprint <N>` /
`CLOSED - satisfied` with the verification evidence cited — NOT carried,
NOT re-deferred. A deferral whose target is already delivered is a
vacuous deferral, and the lead is its detector: surfacing it as "defer"
at the production validation checkpoint (PVC), where the operator rather
than the lead discovers it, is a close-out failure. Record each
re-verification (item, condition, result) in the retro `## Close-Out
Sweep` section. Rule 26(c): this catches a vacuous deferral reaching the
operator at the PVC; its false-positive cost is one redundant re-run of
an already-runnable check (a still-unmet condition simply confirms the
carry); it is removed when successive retros record zero
reclassifications. Violation: a stale or already-satisfied deferral
surfaced at the PVC → retro finding.

**Deferral-justification triple (MANDATORY — extends the freshness
reconciliation above to the trigger and effort axes).** The freshness
rule checks only the CONDITION axis (is the blocking condition still
unmet?). That is necessary but insufficient: a deferral can be vacuous
because its premise is false OR because it conceals trivially-doable
work. So every carry-over deferral, re-affirmed deferral, and every
sprint-cut deferral surfaced at close-out MUST fill all three slots, and
any unfillable slot reclassifies the item BEFORE the PVC — close it, or
do it now (the lead is the detector, not the operator):
- **TRIGGER** — the specific in-sprint diff or path that creates the
  need, cited `file:line`. No citable trigger → the item is INVALID;
  delete it, do not carry it.
- **EFFORT-BLOCKER** — what concretely prevents in-sprint delivery, with
  an estimate. If the work is below an OBJECTIVE bright-line — a ≤~10-line
  config edit, or the deletion of a single artifact — it is IN-SCOPE NOW,
  not a deferral. The bright-line MUST be objective, never "lead
  judgment".
- **CONDITION** — the runnable test, query, or observable and its
  current LIVE result (the freshness reconciliation above).
  Already-satisfied → `CLOSED - delivered`.
A deferral surviving all three slots is presented at the PVC with its
triple as evidence — a stress-tested deferral the operator reviews, not
one the operator must detect. Rule 26(c): this catches an untriggered or
trivially-doable deferral before it reaches the operator; its
false-positive cost is filling three short slots per surviving deferral;
it is removed when successive retros record zero unfillable slots.
Violation: any deferral or carry-over surfaced at the PVC without its
triple, or the operator (not the lead) catching a vacuous deferral →
retro finding.

**Sweep targets (run all three):**

1. **`_bmad-output/planning-artifacts/carry-over-backlog.md`.** For
   every item still marked `IN SPRINT` or `OPEN`, check whether any
   story in this sprint satisfies it. Match on story `Source:`,
   LOCKED_REQUIREMENTS references, or epic linkage. If satisfied and
   the story is `done`: mark the item `CLOSED - delivered in sprint
   <N> via <story-id>` with `closed_at: <ISO date>`, then **move** the
   closed item out of the live backlog into
   `carry-over-backlog-archive.md` (cut-and-paste, verbatim — Rule
   25(a)). The live backlog holds only OPEN / IN-SPRINT / PARTIAL /
   DEFERRED items. If the story shipped but only partially satisfied
   the item: mark `PARTIAL - sprint <N>` and keep the remainder open in
   the live backlog with a note on what remains. If no story touched
   it: leave as-is (it's legitimate carry-over).

   When a carry-over item is partially satisfied, record status as
   `PARTIAL - sprint <N>` with explicit description of what was
   completed and what remains. Keep the remainder open as a new
   carry-over item.

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

**Artifact-size audit (Rule 25(d), warn-only).** Measure the live
planning artifacts and compare to their thresholds:
`prd.md` 60k tokens, `product-brief.md` 60k,
`carry-over-backlog.md` 40k, live `gate-log.md` 25k (≈ bytes/4). For
any artifact over threshold, record a `## Artifact-Size Audit` warning
in the retro doc naming the artifact, its size, and the threshold, and
recommend the operator run the one-shot consolidation step
(`artifact-consolidation.md`). This NEVER blocks the pipeline and the
retro NEVER runs the consolidation itself — consolidation is a
fidelity-critical rewrite and is operator-invoked. If all artifacts are
under threshold, note "Artifact sizes: within thresholds".

## Sprint-Ship Verification

Sprint-ship counters track smoke-quality across deploy-validate runs.

- **`consecutive-deploy-clean`** — increments on each deploy-validate run
  with zero smoke FAILs. Resets to 0 on ANY smoke FAIL, regardless of
  whether the FAIL is new or pre-existing. Strictest counter; reflects
  ship-quality without grandfathering.
- **`consecutive-no-regression`** — increments on each deploy-validate run
  with zero NEW smoke FAILs (pre-existing FAILs may persist without
  resetting this counter). Resets to 0 ONLY on a NEW smoke FAIL not
  present in the prior deploy-validate run. Looser counter; reflects
  whether THIS sprint introduced regressions versus carrying pre-existing
  debt.

Both counters MUST be reported in every retro under the standard template
line:

```
dual-counter: consecutive-deploy-clean: <N>/5; consecutive-no-regression: <M>/5 (run-id: <CI-run-id>).
```

The 5/5 ship-quality target applies to BOTH counters independently. A
sprint is ship-quality when EITHER counter reaches 5/5.

### 5. Human Commentary

Present the retro summary and ask:

"Retro complete. Any comments or questions before I close out the sprint?"

Wait for the human's response. If they have commentary:
- Incorporate it into the retro doc
- Apply any additional process changes they request
If they have nothing to add, proceed.

### 5b. Append Audit-Anchor SHA

After human commentary returns and before commit, append a new entry
to `_bmad-output/audit-anchors.md` with the current sprint's
retro-PR-merge SHA placeholder. The merge SHA is unknown until the
retro PR merges; lead writes the entry with sprint + closed_at fields
and updates the SHA in a follow-on commit on `main` after merge.
Schema and producer mandate live in `audit-anchors.md` header. No
SHA = audit-gate fails closed at next sprint's per-class test-debt
audit (`gate-validation.md` Check 18).

### 5c. Pre-Commit Validation Gate

Before committing retro artifacts, run all three checks in order.
Failure on any check blocks the Step 6 commit.

1. **Rule file audit commit.** If the rule file audit (Step 4)
   produced file changes, commit them NOW as a separate commit:
   `docs(rules): rule file audit (retro) — strip narrative, harden weak rules`.
   If the audit was clean, skip.

2. **Provenance block verification.** Open the retro doc and verify
   the `SKILL_INVOCATION_PROVENANCE v1` block cites a valid
   `tool_use_id`. If the tool_use_id is NOT_ACCESSIBLE (common after
   compact), that is acceptable — note it in the provenance block.
   If the provenance block is missing entirely, add it now before
   proceeding.

3. **Mandatory rules validation.** Run:
   `scripts/validate-mandatory-rules.sh <N>` (where N is the sprint
   number). This executes `validate-retro-evidence.sh`,
   `validate-cycle-commits.sh`, and `validate-provenance-block.sh`.
   MUST exit 0. If it fails, fix the issues before proceeding to
   Step 6.

### 6. Commit, Push, and PR

**6a. Commit all remaining artifacts.**

**Pre-commit completeness check.** Before staging, verify these
artifacts exist for this sprint. Missing items indicate a skipped
step — go back and complete it before committing:

- [ ] Gate-log entry exists in `_bmad-output/implementation-artifacts/gate-log.md` for this sprint
- [ ] `_bmad-output/audit-anchors.md` updated (Step 5b)
- [ ] Next-sprint prompt emitted (Step 7) OR "no next sprint" stated explicitly
- [ ] Retro doc has provenance block citing party-mode transcript

If any item is missing, complete the skipped step NOW before
proceeding. Do not commit an incomplete retro.

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
