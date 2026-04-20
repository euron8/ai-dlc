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

**STOP.**
