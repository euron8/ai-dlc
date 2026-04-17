---
name: gate-validation
description: Autonomous gate validation protocol — referenced by all pipeline steps at phase transitions
---

# Autonomous Gate Validation Protocol

This file is referenced (not loaded as a step) by every pipeline step at
phase transition points. When a step says "run gate validation", execute
this protocol. Every check must PASS. Any failure blocks the gate.

## Validation Checklist

### 1. Validation cycle complete?

- For planning artifacts: Party Mode completed? Advanced Elicitation
  completed? Adversarial Review completed (2+ passes, only nitpicks
  remain)?
- For implementation artifacts: Code Review approved? QA approved?
  Story Validation passed?
- If any required validation was skipped, run it now before proceeding.
- **Evidence:** Gate log must record which validations were run and their
  outcomes. "Completed" without evidence is not completed.

### 2. No unresolved HARD_BLOCKs?

- Read `docs/escalations/pending.md` (if it exists).
- If any entry has status `HARD_BLOCK` and is not RESOLVED, do NOT
  proceed. Report the block and wait for human input.
- `DECIDED_AUTONOMOUSLY` entries do not block. They are informational.
- `DEFERRAL_REQUEST` entries block only the deferred item, not the
  pipeline. Proceed with non-deferred work.

### 3. Requirement anchor integrity?

- For each planning artifact passing through this gate (brief, PRD,
  story files), locate the `LOCKED_REQUIREMENTS` block.
- For each requirement in the block, verify it appears in the artifact
  body with equivalent or greater specificity.
- **Drift detection:** If a locked requirement has been weakened (e.g.,
  "on the user profile settings page" → "in the settings area"), generalized
  (specific scope → vague scope), or removed entirely — the gate FAILS.
- **Remediation:** Restore the drifted requirement to match the locked
  block. If the artifact body contradicts the locked requirement in a
  way that cannot be reconciled by restoring text, escalate as
  `HARD_BLOCK` (requirement divergence).
- If no `LOCKED_REQUIREMENTS` block exists and this is a planning
  artifact derived from user input: the gate FAILS. The block must be
  created by re-reading the original user input / carry-over item /
  escalation spec before proceeding.

### 4. Template placeholder detection?

- Scan all story files in the current sprint for template placeholders:
  `{{...}}`, `[TODO]`, `[TBD]`, `<placeholder>`, empty Dev Agent Record
  fields.
- Run: `grep -rn '{{.*}}' _bmad-output/planning-artifacts/stories/`
- **Gate FAILS** if any placeholder is found. Dev must populate before
  proceeding. This is not a warning — it is a hard gate blocker.
- **Evidence:** Log the grep command and its output (or "0 matches") in
  the gate log entry.

### 5. Story status consistency?

- For every story in the current sprint, verify:
  - Story file `Status:` header value
  - Corresponding entry in `sprint-status.yaml`
  - These MUST match exactly.
- Run: Read both files, compare status values programmatically.
- **Gate FAILS** if any story has mismatched status between the two files.
  Fix the mismatch before proceeding.
- **Evidence:** Log the comparison results in the gate log entry.
  List each story ID and its status in both files.

### 6. Production integrity tests exist? (Implementation gates only)

Skip this check for planning phase gates. Required for Phase 4+ gates.

- For every story in the sprint that modifies the deployed product,
  verify production integrity tests exist:
  - Check the story file for a "Production Integrity Tests" section
    listing test file paths and pass/fail results.
  - Verify the referenced test files exist on disk.
  - Verify the tests pass (or that pass/fail output is logged).
- **Gate FAILS** if any deployable story is missing production integrity
  tests. This is non-deferrable per coding-conventions. The dev must
  add the tests before the gate can pass.
- Stories that are documentation-only, planning-only, or infrastructure
  configuration (no deployed code changes) are exempt.
- **Evidence:** Log which stories were checked, which test files were
  found, and pass/fail status.

### 7. Artifact consistency?


- All planning artifacts referenced by stories exist on disk.
- Architecture doc exists and is current (not stale relative to PRD).
- Sprint-status.yaml exists and contains entries for all sprint stories.

### 8. Deployment evidence? (Implementation gates only)

Skip this check for planning phase gates. Required for Phase 4+ gates.

- Deployment command output must be captured and logged.
- Smoke test output must be captured and logged.
- Deployed asset verification must be documented.
- **Gate FAILS** if the lead claims deployment is complete but cannot
  produce evidence (command output, test results, verification).
- **Evidence:** Include in gate log:
  - Deploy command and output
  - Smoke test command and pass/fail results
  - Asset verification output

### 9. Visual verification? (UI sprint gates only)

Skip if `is_ui_epic == false`. Required when the sprint introduced new
visual surfaces.

- Agent must fetch the deployed production URL and verify rendering.
- Compare each new surface against the documented mockup (from
  ui-direction step or `_bmad-output/planning-artifacts/ui-mockups-*.md`).
- **Gate FAILS** if visual verification was not performed or drift was
  found and not fixed.
- **Evidence:** Include in gate log:
  - Which surfaces were verified
  - Whether drift was found and what was fixed
  - Confirmation that production rendering matches mockups

### 10. Schema/API field verification? (Schema-modifying stories only)

Skip if no stories modify API queries or schema definitions. Required
when any story adds fields to API queries or schema.

<!-- Customize this check for your project's API layer. Examples:
     - GraphQL: run introspection { __type(name: "EntityName") { fields { name } } }
     - REST: verify OpenAPI spec matches live endpoint response shape
     - gRPC: verify proto definitions match deployed service reflection -->

- For every new field added to an API query or schema, verify the field
  exists in the live service before committing the change.
- **Gate FAILS** if any queried field does not exist in the live schema.
  The query change must be reverted or gated behind the service deployment.
- **Evidence:** Log the verification query, its response, and the
  field-by-field verification result.

### 11. Smoke test coverage for user-facing changes? (Implementation gates only)

Skip this check for planning phase gates. Required for Phase 4+ gates.

- For every story in the sprint that introduces, modifies, or removes
  user-facing functionality, verify smoke test updates exist AND are
  adequate:
  - Check the story file for a "Smoke Test Updates" section listing
    which test files were added/modified/removed.
  - Verify the referenced test files exist on disk.
  - Verify the test changes correspond to the story's user-facing
    changes (not just copied boilerplate).
  - **Verify test type matches change type:** UI changes must have
    browser-level tests (e.g., Playwright), not just API health checks.
    API changes must have HTTP endpoint tests. Computation changes must
    have live verification tests. If the story adds a visible UI
    element and the smoke test only checks `GET /endpoint returns 200`,
    the gate FAILS — the test does not verify what the story changed.
- **Gate FAILS** if any user-facing story is missing smoke test updates
  OR if the test type does not match the change type. The dev must add
  or fix the tests before the gate can pass.
- Stories that are purely internal (no user-facing behavior change),
  documentation-only, or infrastructure configuration are exempt.
- **Evidence:** Log which stories were checked, which smoke test files
  were found, what layer each test verifies (browser/API/computation),
  and whether the test type matches the change type.

### 12. Append gate log entry.

Create or append to `_bmad-output/implementation-artifacts/gate-log.md`.
Use the format defined in CLAUDE.md Autonomous Gate Protocol section.

The gate log entry MUST include:
- Gate name and phase
- Timestamp
- Result for EACH numbered check above (PASSED/FAILED/SKIPPED with reason)
- Evidence artifacts collected during checks
- Any remediations performed

A gate log entry without per-check results is incomplete and must be
rewritten before proceeding.

### 13. Announce gate passage.

Output a brief line to the conversation only AFTER Checks 14 and 15
below have also passed. (This check is numbered 13 to preserve
existing cross-references, but execution is deferred until the full
15-check cycle is complete, so the announcement reflects the final
count.)

"Gate [name]: PASSED — 15/15 checks passed — proceeding to [next phase]"

Include the check count so the human can verify completeness at a glance.

### 14. Update pipeline snapshot.

Update `_bmad-output/pipeline-snapshot.md` to reflect the gate passage
and current pipeline state. The snapshot is a living document maintained
throughout the pipeline and is the source of truth for state on handoff,
post-`/compact` recovery, and lead self-orientation.

Refresh these sections:

- **Pipeline Position** — update `current_step_file` (just completed),
  `last_completed_step_file`, `last_gate_passed` (gate name +
  timestamp), and `current_branch` (refresh from
  `git branch --show-current`).
- **Sprint Context** — sync story statuses with `sprint-status.yaml`
  (stories_completed_this_sprint, stories_in_progress,
  stories_not_started). Update sprint_id if it changed. If
  `is_ui_epic` was determined during this gate's step (set in
  `stories-test-strategy.md` Step 7), record it here so
  `deploy-validate.md` can read it from the snapshot after a
  handoff or `/compact` rather than re-detecting.
- **Recent Activity** — append a one-line entry for this gate passage
  (gate name, timestamp, key artifacts touched). Keep the last ~10
  entries; older entries can be pruned.
- **Open Items** — refresh from current state of `docs/escalations/pending.md`
  and any open triage items.
- **Locked Decisions** — append any new locked requirements or
  direction changes confirmed during this gate.
- **Context Reminders** — evaluate context usage and update
  `context_reminders_sent` per the threshold rules below.

**Context reminder threshold check (required at every gate):**

Read the Context Reminders block from the snapshot. If any required
field is absent (e.g., snapshot predates this rule), initialize
missing fields before proceeding: `context_reminders_sent: none`
and each `last_*_fire_tokens`/`last_*_fire_turns` to `null`.

Resolve the active thresholds from the project's `{context_thresholds}`
configuration in CLAUDE.md. Defaults per SKILL.md Rule 10:
- 200K model context → yellow 80K tokens, red 120K tokens
- 1M model context  → yellow 120K tokens, red 200K tokens

The lead cannot self-measure its context window reliably (per the
CLAUDE.md Session Model "introspection" note). Use whichever of these
is available as the estimate, in priority order:
1. The most recent user-shared `/context` output this session
   (authoritative).
2. A conservative estimate from accumulated tool output and turn
   count (erring high, not low).

Evaluation rules (in order):

- **First crossing of yellow:** if `context_reminders_sent` is
  `none` and estimated tokens ≥ yellow_threshold, output the
  Rule 10(b) yellow-threshold reminder substituting the actual
  yellow_threshold value. Set `context_reminders_sent: yellow`,
  `last_yellow_fire_tokens` to the current estimate, and
  `last_yellow_fire_turns` to the current turn count.
- **First crossing of red:** if `context_reminders_sent` is
  `none` or `yellow` and estimated tokens ≥ red_threshold, output
  the Rule 10(c) red-threshold reminder substituting the actual
  red_threshold value. Set `context_reminders_sent: red`,
  `last_red_fire_tokens`, and `last_red_fire_turns`.
- **Recurring yellow (still below red):** if
  `context_reminders_sent` is `yellow`, estimated tokens still
  below red_threshold, and EITHER (estimated_tokens −
  last_yellow_fire_tokens ≥ 50,000) OR (current_turn −
  last_yellow_fire_turns ≥ 20), re-output the yellow reminder and
  refresh `last_yellow_fire_*`.
- **Recurring red:** if `context_reminders_sent` is `red` and
  EITHER (estimated_tokens − last_red_fire_tokens ≥ 50,000) OR
  (current_turn − last_red_fire_turns ≥ 20), re-output the red
  reminder and refresh `last_red_fire_*`.
- **Below yellow threshold:** no reminder, no field change.

The threshold check is an estimate — precision is not required.
Err on the side of outputting the reminder early rather than late.
Reminders are non-blocking one-line outputs; they do not pause the
pipeline. Output, update the snapshot fields, and continue. Any user
reply to a reminder is a Rule 4 directive handled on the next turn.

See SKILL.md Rule 10 for the snapshot's full structure and rationale.

A gate passage without a corresponding snapshot update leaves the
snapshot stale, which undermines its role as the handoff / recovery /
self-orientation source of truth. Do not skip this check.

### 15. Verify snapshot reflects this gate.

After Check 14 writes the snapshot, re-read
`_bmad-output/pipeline-snapshot.md` and confirm:

- The `last_gate_passed` name matches the gate being logged in
  Check 12.
- The `last_gate_passed` timestamp matches (equal to, or within a
  few seconds of) the timestamp in the gate log entry Check 12
  appended.
- `current_step_file` matches the step file that invoked this gate.
- If `context_reminders_sent` was advanced this cycle, the matching
  `last_*_fire_tokens` / `last_*_fire_turns` were also set to
  non-null values.

This check exists because Check 14 is an assertion ("update the
snapshot"); Check 15 is a verification that the assertion took
effect. A gate could otherwise claim Check 14 passed without the
snapshot actually being updated.

**Gate FAILS** if any of the above do not match. Remediation: re-run
Check 14 (re-write the snapshot) and then re-run Check 15. If Check
15 fails twice in a row, escalate as HARD_BLOCK — the snapshot
writer is broken and the gate should not pass with a stale
recovery anchor.

### Sub-step snapshot update (referenced by step files)

Step files invoke this lightweight update after each validation
sub-skill and after each story transition during implementation.
Gate passages still run the full Check 14 above; sub-step updates
are narrower in scope.

When a step file says "run sub-step snapshot update", execute:

1. Append a one-line entry to **Recent Activity** naming the
   sub-skill completed or transition observed, with timestamp and
   artifact touched (e.g., `2026-04-17T15:22Z — /bmad-party-mode
   completed on PRD — _bmad-output/planning-artifacts/prd.md`).
2. Refresh **Open Items** from current state of
   `docs/escalations/pending.md` and any open triage items.
3. Do NOT refresh other sections (Pipeline Position, Sprint Context,
   Locked Decisions remain gate-scope). Do NOT re-evaluate context
   reminder thresholds here — reminder evaluation stays at gate
   boundaries per Check 14 above.

This keeps mid-step compaction survivable: the snapshot's Recent
Activity reflects the in-flight sub-step rather than only the last
gate. The full Check 14 still runs at the next gate.

## Gate Failure

If any check fails:
1. Attempt to remediate (run missing validation, fix inconsistency,
   restore drifted requirement, populate template, sync status).
2. Re-run the FAILED check specifically (not the entire checklist).
3. If the check now passes, continue with remaining checks.
4. If still failing after remediation, escalate as HARD_BLOCK per Rule 4.
5. Do NOT skip a failing check. Do NOT proceed with a known failure.
   "We'll fix it later" is not an acceptable remediation for gate checks.
