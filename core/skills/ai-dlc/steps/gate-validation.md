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

### 1c. Research-invocation enforcement (research-requirements gate only).

**Scope.** This check fires only at the research-requirements gate, and
only when the pipeline variant (read from
`_bmad-output/pipeline-snapshot.md` `pipeline_variant` field as-of
start-of-gate-check) is one of `{greenfield, feature, brownfield-a,
brownfield-b, brownfield-c, carry-over}`. SKIPS `{bug,
sprint-execute, analysis-only}`.

On missing/corrupt snapshot, reports PENDING (not FAILED) and escalates
via HARD_BLOCK to force snapshot reconstruction.

**Check.** Research-requirements phase has invoked technical research.
Two arms, either satisfies (dual-arm OR):

- **Arm (a) — commit-subject marker.** Grep branch commits (since `main`
  divergence) for a subject line matching regex
  `^Sprint [0-9]+ (research-requirements|technical.*research|research.*technical|bmad-technical-research)`.
  A single match on any commit in the branch satisfies arm (a).

- **Arm (b) — PRD content proxy.** The PRD artifact contains a "Research
  Findings" section AND ≥1 numbered marker matching regex
  `^(- |### )?\*{0,2}R[0-9]+\s+[—–-]\s`. The `\*{0,2}` optionally
  accepts bold-marker prefix `**R1 — ...**` which is the dominant
  style in real PRDs authored via `/bmad-technical-research`. Single
  match satisfies arm (b).

**PASS:** arm (a) OR arm (b) matches. **FAIL:** neither matches.

### 2. No unresolved HARD_BLOCKs?

- Read `docs/escalations/pending.md` (if it exists).
- If any entry has status `HARD_BLOCK` and is not RESOLVED, do NOT
  proceed. Report the block and wait for human input.
- `DECIDED_AUTONOMOUSLY` entries do not block. They are informational.
- `DEFERRAL_REQUEST` entries block only the deferred item, not the
  pipeline. Proceed with non-deferred work.
- **AC deferral requires a named observable reopen signal.** When an
  AC is deferred with classification "platform limitation", "external
  dependency", "awaiting third-party fix", or any similar phrasing,
  the escalation entry MUST name a specific, observable signal that
  would reopen the deferral. Invalid signals (examples): "first Linux
  CI run" when no such run is scheduled, "once upstream fixes it"
  with no version/date, "when the platform changes" when the platform
  is not under project control. Valid signals (examples): "first
  invocation of workflow `<name>` after `<date>`", "release of
  `<package>` version `>=X.Y`", "fix-forward PR lands". Deferrals
  missing a valid signal MUST be escalated as `HARD_BLOCK` for
  root-cause investigation rather than accepted. Gate FAILS if a
  deferral entry in scope for this gate lacks a valid reopen signal.

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

### 3a. Story validation origin check (story gates only).

**Scope.** This check fires only when the gate being validated is a
story-level validation gate (invoked from `stories-test-strategy.md`
for story readiness, or from `implementation.md` for story completion).
Skip this check for all non-story gates (planning-artifact gates,
sprint-level gates, deployment gates).

**Check.** For each story being validated, identify its origin:

1. A specific requirement in CLAUDE.md or `docs/coding-conventions.md`.
2. User feedback captured in an escalation or planning artifact.
3. A carry-over item from a previous sprint
   (`_bmad-output/planning-artifacts/carry-over-items.md`).
4. The locked requirements block from product brief or PRD.

If the story has no identifiable origin in any of the above, the
story is not origin-anchored; note it and move on (Check 3's general
requirement anchoring covers this case).

If the story IS origin-anchored, verify that the story's acceptance
criteria FULLY satisfy the original requirement text. Compare:

- Quote the original requirement verbatim from its source.
- Quote the story's acceptance criteria.
- For each substantive element of the original requirement
  (placement, behavior, scope, specific values), identify which
  acceptance criterion covers it.

**Gate FAILS** if any substantive element of the original requirement
is not covered by a story acceptance criterion, REGARDLESS of
whether the story's own ACs pass their validation. A story whose ACs
are internally consistent but which does not address the original
requirement has failed its purpose and cannot pass the gate.

**Remediation.** Expand the story's acceptance criteria to cover the
uncovered elements, re-validate the story, and re-run Check 3a. If
the story cannot reasonably be expanded to cover the requirement
(because the requirement is larger than one story's scope), escalate
as Rule 12 HARD_BLOCK with `requirement divergence` as the blocker
type and the original requirement quoted verbatim.

**Why this is a gate-level check.** The story's own validation cycle
may pass (the story is internally coherent and its ACs are testable)
while the story still fails to address the thing it was created to
address. This failure mode cannot be caught by validating the story
in isolation; it requires comparing the story to its source. Check
3a enforces that comparison at the gate.

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

### 11a. Live-run attempted under envvar gate? (Implementation gates only)

Skip this check for planning phase gates. Required for Phase 4+ gates.

- For every story in the sprint whose smoke tests include a live-against-production path gated by an environment variable (e.g., `SMOKE_TESTS_LIVE=1`):
  - Check the story's Dev Agent Record for explicit documentation that the live run was attempted — the command invoked, the envvar that gated it, and the outcome (PASS, FAIL with details, or pool-scoped skip with justification).
  - A test-suite run with the envvar unset does NOT satisfy this check — the live path was skipped, not exercised.
- **Gate FAILS** if any story with an envvar-gated live-run path lacks attempt evidence in its Dev Agent Record. The story must re-run under the documented envvar before the gate can pass.
- Stories whose smoke tests have no live-against-production path are exempt.
- **Evidence:** Log which stories had envvar-gated live paths, the envvar names, the commands invoked, and the documented outcomes.

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

"Gate [name]: PASSED — all checks passed — proceeding to [next phase]"

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

Resolve the active thresholds from the SKILL.md Handoff Protocol
"Threshold defaults" section. Defaults:
- 200K model context → yellow 80K tokens, red 120K tokens
- 1M model context  → yellow 120K tokens, red 200K tokens

The lead cannot self-measure its context window reliably. Two modes
apply (per SKILL.md Handoff Protocol "Reminder semantics"):

**Mode 1 — user-shared `/context` (authoritative).** The most
recent user-shared `/context` output this session drives both the
threshold-crossing check AND the recurrence arithmetic. Under
Mode 1, the evaluation rules below apply, and on any firing the
lead emits the full Rule 2(b) / 2(c) reminder text and advances
`last_yellow_fire_tokens` / `last_yellow_fire_turns` (or the red
counterparts).

**Mode 2 — fallback estimate (advisory only).** When no user-
shared `/context` is available, compute:

```
estimate = 15,000  (baseline for CLAUDE.md + skill + system prompt)
         + (turns_this_session * 2,000)  (approx per-exchange cost)
         + sum(tool_output_sizes_in_bytes) * 0.25  (bytes-to-tokens conservative high)
```

If the estimate crosses a threshold, emit the lighter check-line
(not the full Rule 2 reminder):

> *"Context estimate suggests crossing the {yellow|red} threshold
> (~{estimate}K tokens, fallback heuristic). Please share
> `/context` output to confirm. I will continue with this estimate
> as a working assumption until confirmed."*

Under Mode 2, DO NOT advance the `last_*_fire_tokens` /
`last_*_fire_turns` snapshot fields and DO NOT update
`context_reminders_sent`. Mode 2 is a prompt for confirmation, not
a reminder; advancing fire state on unverified estimates would
cause noisy re-firing on long sessions. When the user responds
with `/context` output, treat the shared value as Mode 1 input:
evaluate the threshold, emit the full Rule 2 reminder if the
shared value confirms the crossing, and advance fire state.

Evaluation rules (Mode 1 only — in order):

- **First crossing of yellow:** if `context_reminders_sent` is
  `none` and shared tokens ≥ yellow_threshold, output the
  Rule 2(b) yellow-threshold reminder substituting the actual
  yellow_threshold value. Set `context_reminders_sent: yellow`,
  `last_yellow_fire_tokens` to the shared value, and
  `last_yellow_fire_turns` to the current turn count.
- **First crossing of red:** if `context_reminders_sent` is
  `none` or `yellow` and shared tokens ≥ red_threshold, output
  the Rule 2(c) red-threshold reminder substituting the actual
  red_threshold value. Set `context_reminders_sent: red`,
  `last_red_fire_tokens`, and `last_red_fire_turns`.
- **Recurring yellow (still below red):** if
  `context_reminders_sent` is `yellow`, shared tokens still below
  red_threshold, and EITHER (shared_tokens −
  last_yellow_fire_tokens ≥ 50,000) OR (current_turn −
  last_yellow_fire_turns ≥ 20), re-output the yellow reminder and
  refresh `last_yellow_fire_*`.
- **Recurring red:** if `context_reminders_sent` is `red` and
  EITHER (shared_tokens − last_red_fire_tokens ≥ 50,000) OR
  (current_turn − last_red_fire_turns ≥ 20), re-output the red
  reminder and refresh `last_red_fire_*`.
- **Below yellow threshold:** no reminder, no field change.

Reminders are non-blocking one-line outputs; they do not pause the
pipeline. Output, update the snapshot fields under Mode 1, and
continue. Any user reply to a reminder is a Rule 11 directive
handled on the next turn.

See SKILL.md Handoff Protocol and Pipeline Snapshot section for the
snapshot's full structure and rationale.

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

### 16. Stub audit (hot-path files) — content verification.

**Scope.** Runs at every gate whose `changed_files` set includes any
hot-path file. Hot-path extensions: `.py`, `.ts`, `.tsx`, `.js`,
`.sh`, `.sql`. Hot-path paths: `.github/workflows/**.yml` (directly
invoked by GitHub Actions).

**Check.** Grep changed hot-path files for stub markers (regex
`(stub|TODO|FIXME|wired later|Phase [0-9]|NotImplementedError)`).
For each match, verify FOUR elements in the match's surrounding
comment block (preceding 5 lines + the matched line):

1. **Numbered carry-over item reference.** Regex `Item [0-9]+`
   matches somewhere in the comment block.
2. **OPEN or IN-SPRINT status.** Lookup the referenced item number
   in `_bmad-output/planning-artifacts/carry-over-backlog.md`;
   matching line must match regex
   `^- Item [0-9]+.*(OPEN|IN SPRINT [0-9]+)`. CLOSED or absent
   items fail this element.
3. **`file:line` reference.** Regex `(^|\s)\S+:[0-9]+(\s|$)` —
   path token + colon + 1+ digits. Digit-only; rejects `file:FIXME`.
4. **Deferral-reason line with min-content + density.** Primary
   regex: `^deferral-reason:\s+\S.{19,}` (at least one non-
   whitespace char after `deferral-reason:\s+`, then 19+ more chars
   of any kind). Secondary density check: the reason body
   (everything after `deferral-reason:\s+`) must contain ≥10
   non-whitespace characters, computed via
   `<reason> | tr -d '[:space:]' | wc -c`. Defeats `X` + padding
   bypass.

**PASS:** every stub match satisfies all four elements. **FAIL:**
any stub match missing any element. FAIL output names the
offending `file:line` and the specific missing element(s).

### 17. Skill-invocation provenance (retro gate + sub-skill-gated gates).

**Scope.** Runs at the retro gate unconditionally. Also runs at any
gate where a validation sub-skill (bmad-party-mode,
bmad-advanced-elicitation, bmad-review-adversarial-general,
bmad-validate-prd) was required by the current phase. Skip on gates
that do not produce a provenance-bearing artifact.

**Check.** Invoke `scripts/validate-provenance-block.sh` against the
gate's primary artifact.

- **Retro gate:** run `scripts/validate-provenance-block.sh
  docs/retro/sprint-<N>.md` AND `scripts/validate-retro-evidence.sh
  <N>`. Both must exit 0. validate-retro-evidence.sh additionally
  enforces transcript file presence, byte-match against the cited
  SHA, and non-triviality floors (MIN_CHARS, MIN_PERSONAS,
  MIN_PHASES).
- **PRD gate (research-requirements phase):** run
  `scripts/validate-provenance-block.sh
  _bmad-output/planning-artifacts/prd.md --require-skill
  bmad-validate-prd`.
- **Story readiness gate (stories-test-strategy):** run
  `scripts/validate-provenance-block.sh <story-file>
  --require-skill bmad-review-adversarial-general` for each story.

**PASS:** all required provenance scripts exit 0. **FAIL:** any
script reports a missing block, malformed field, unknown skill,
missing transcript file (retro only), or SHA byte-mismatch (retro
only).

### H1. Harness meta-check — each phase-specific check has a self-test fixture.

**Recursion guard.** H1 is NOT subject to H1. When H1 runs, it sets
environment variable `H1_DEPTH=1`. If H1 observes `H1_DEPTH` already
set in the environment at entry, it returns PASS immediately without
re-enumeration to prevent infinite recursion. Check H2 (below)
verifies the guard fires on a seeded recursive-invocation fixture.

**Scope.** Meta-check. Runs at every gate. Verifies that each
phase-specific check added to this file (currently: Check 1c, Check
16's content-verification strengthening, Check 17 provenance) ships
with an adversarial self-test fixture under `tests/fixtures/` that
the check catches.

**Check.** For each phase-specific check enumerated below, confirm
both (i) the fixture directory exists with a README.md describing
the bypass scenario and a `seed.sh` reproducing it idempotently, and
(ii) the check's body references the fixture path by name so a
future reader can trace from check → fixture.

Enumerated checks under H1:

- **Check 1c** — fixture at `tests/fixtures/check-1c-bypass/`.
- **Check 16 (stub-audit content-verification)** — fixture at
  `tests/fixtures/check-15-bypass/`.
- **Check 17 (skill-invocation provenance)** — fixture at
  `tests/fixtures/check-17-bypass/`.

**PASS:** every enumerated check's fixture exists with README.md +
seed.sh, and the check's body cites the fixture path. **FAIL:** any
enumerated check is missing its fixture or check-body cross-reference.

### H2. Harness self-test — seeded forgery fixture + H1 recursion guard.

**Scope.** Meta-meta-check. Runs at every gate. H2 verifies two
things:

1. **H1 recursion guard fires.** Re-invoke the H1 check with
   `H1_DEPTH=1` pre-set in the environment; H1 MUST return PASS
   immediately without re-enumerating fixtures. Fixture at
   `tests/fixtures/check-h1-recursion/` seeds the recursive-
   invocation scenario.

2. **Seeded provenance-block forgery is caught.** The fixture at
   `tests/fixtures/check-17-bypass/` contains an adversarial
   retro-shaped file with a well-formed-LOOKING provenance block
   where the `tool_use_id` was copied from a prior real invocation
   but the transcript_path SHA was hand-edited to a fabricated
   value. `validate-retro-evidence.sh` MUST flag this variant.

**PASS:** both (1) and (2) hold on a fresh fixture seed. **FAIL:**
either the recursion guard does not fire OR the seeded forgery
passes validation.

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

### Auto-handoff evaluation (referenced by step files)

Step files invoke this helper at each safe seam defined in SKILL.md
Handoff Protocol "Auto-handoff (configurable via `auto_handoff_mode`)".
When a step file says "run auto-handoff
evaluation at Seam <X>", execute this procedure. The outcome is
either CONTINUE (no-op — the step resumes normally) or FIRE (the
lead executes the Rule 2(a) handoff and the session ENDS). This
helper MUST NOT be invoked from inside the Check 1–15 sequence
above; it is only called from step files at the defined seams.

**Inputs:** the seam name (`Seam A`, `Seam B`, `Seam C`, or
`Seam D`) and a short human-readable label for the distinguishing
output line (e.g., `deploy-validate Step 0 pre-flight`,
`implementation story transition`,
`architecture adversarial pass 2`).

**Evaluate preconditions in this order. The first failing
precondition returns CONTINUE immediately — no fire, no side
effects, the step resumes.**

1. **Mode gate.** Read `auto_handoff_mode` from SKILL.md Handoff
   Protocol "Auto-handoff" section. If `off`, return CONTINUE. If
   `deploy-only` and the seam
   is not `Seam A`, return CONTINUE. If `safe-seam`, all four
   seams are permitted — proceed to precondition 2.

2. **Red threshold confirmed under Mode 1.** Read
   `context_reminders_sent` from the snapshot Context Reminders
   block. If it is not `red`, return CONTINUE. Check 14 advances
   this field to `red` ONLY when a user-shared `/context` confirmed
   the crossing under Mode 1 — Mode 2 fallback estimates MUST NOT
   advance the field. This precondition is therefore equivalent to
   "red threshold confirmed via user-shared `/context`".

3. **Snapshot is current.** Read the most recent Recent Activity
   entry. If it does not reflect either (a) the gate passage that
   most recently ran Check 15, or (b) the sub-step snapshot update
   preceding this seam, run the sub-step snapshot update now and
   re-read. If the update fails or Recent Activity still does not
   reflect the preceding sub-step, return CONTINUE — firing
   auto-handoff on a stale snapshot would produce a broken resume
   contract.

4. **No gate validation currently executing.** This precondition is
   satisfied by-construction: step files MUST NOT invoke this
   helper from inside the Check 1–15 sequence. If the caller is
   inside Check 1–15, return CONTINUE — treat as a caller bug.

5. **No deployment currently executing.** This precondition is
   satisfied by-construction: Seam A runs at `deploy-validate.md`
   Step 0, before Step 1. No other seam runs during
   `deploy-validate.md` Steps 1–5. If the caller is between Step 1
   and Step 5, return CONTINUE.

6. **No teammate awaiting lead orchestration response.** Check the
   task list for in-progress tasks that are blocked on a lead
   mediation or response. Inspect recent teammate messages
   awaiting the lead. If any teammate is awaiting a response,
   return CONTINUE — firing handoff while a teammate is blocked
   would strand the teammate.

7. **Not at any Rule 3 pause point.** Verify the lead is not
   currently in ambiguity resolution, the Production Validation
   Checkpoint, the retro commentary prompt, or the post-compact
   verification turn. If any pause point is active, return
   CONTINUE.

If all seven preconditions pass, FIRE auto-handoff. Execute the
Rule 2(a) handoff 5-step procedure (defined in SKILL.md Handoff
Protocol "Handoff triggers") with one addition — the distinguishing
output line in step 4 identifies this handoff as automated:

1. **Stop all in-flight teammates first.** Call `TaskStop` on
   every `in_progress` task. Halt any Agent-spawned teammate not
   bound to a task. Wait until every teammate has returned before
   proceeding. Record stopped teammates and in-flight artifacts in
   the snapshot's Open Items in Step 3.
2. `git add` and `git commit` any in-flight work, including work
   teammates left in the working tree.
3. Finalize the pipeline snapshot — one last update capturing
   in-flight state, current sub-step, and the stopped-teammate
   record from Step 1.
4. Output the distinguishing auto-handoff line (substitute mode,
   seam label, confirmed token count from the most recent user-
   shared `/context`), then output the resume prompt (SKILL.md
   Handoff Protocol template) wrapped in `----` delimiter lines:

   > *"Auto-handoff triggered by auto_handoff_mode=<mode> at
   > <seam_name>. Context at <tokens> tokens, red threshold
   > confirmed via user-shared /context."*

5. End the session. Do not continue the pipeline in this
   conversation. Reply to any further messages with a pointer to
   the snapshot and the resume prompt.

A FIRE outcome does not return control to the calling step. A
CONTINUE outcome returns silently — the step proceeds with its
next directive (typically the `gate-validation.md` call, the next
adversarial pass, or the next story transition orchestration).

## Gate Failure

If any check fails:
1. Attempt to remediate (run missing validation, fix inconsistency,
   restore drifted requirement, populate template, sync status).
2. Re-run the FAILED check specifically (not the entire checklist).
3. If the check now passes, continue with remaining checks.
4. If still failing after remediation, escalate as HARD_BLOCK per Rule 12.
5. Do NOT skip a failing check. Do NOT proceed with a known failure.
   "We'll fix it later" is not an acceptable remediation for gate checks.
