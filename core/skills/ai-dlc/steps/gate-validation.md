---
name: gate-validation
description: Autonomous gate validation protocol — referenced by all pipeline steps at phase transitions
---
<!-- STEP_LOADED_TOKEN: gate-validation -->

# Autonomous Gate Validation Protocol

This file is referenced (not loaded as a step) by every pipeline step at
phase transition points. When a step says "run gate validation", execute
this protocol. Every check must PASS. Any failure blocks the gate.

## Gate-type manifest (conditional check loading)

Checks in this file are **sliced by gate type**: a gate loads the
universal core plus only the checks its declared type requires, per the
`GATE_MANIFEST` below. See
`docs/v0.24.0-gate-validation-slicing-spec.md` §5.

**Gate-type enum (canonical, co-located per Rule 26).** The invoking step
declares exactly one type when it says "run gate validation
[`<type>`]" (§5.3). Valid types:

`planning` · `story` · `implementation` · `sprint-review` · `retro`

Deployment / schema / UI applicability is NOT a separate type: the
schema (Check 10), visual (Check 9), and deployment-evidence (Checks 8,9)
checks are folded into the `implementation` and `retro` slices and
self-skip via their own scope clauses (`is_ui_epic == false`, "no stories
modify schema", "deployment not claimed"). This avoids a combined
UI-and-schema sprint being unable to declare two types at once.

**Universal core (always loaded, every gate, every type).** Checks
**1, 2, 3, 4, 7, 12, 13, 14, 15, 16, 26, H1, H2, Gate Failure**. These run
regardless of gate type and are never sliced out (§6). Check 16
(stub-audit) is universal, not implementation-only: it is keyed on
`changed_files` *content* (any gate whose diff touches a hot-path file),
not on gate phase, so slicing it to one type would drop it on a planning
gate that edits `scripts/*.sh`.

```
<!-- GATE_MANIFEST v1 -->
| Gate type      | Required checks (beyond universal core)          |
|----------------|--------------------------------------------------|
| planning       | 1c, 17, 20, 23, 24                               |
| story          | 3a, 3b, 5, 17, 24                                |
| implementation | 5, 6, 8, 9, 10, 11, 11a, 19, 22                  |
| sprint-review  | 18, 21                                           |
| retro          | 8, 9, 17, core-layer-immutability                |
<!-- GATE_MANIFEST_END -->
```

**Loader contract (Rule 21).** The step invoking gate validation reads
this manifest, resolves the declared gate type, and loads (READ AND
FOLLOW) the universal core **plus** every check ID in that type's row.
"Loaded" for `gate-validation.md` means exactly this set present in
context — not the whole file (§5.2). Each check carries a
`<!-- CHECK_LOADED: <id> -->` anchor directly under its heading; H1
reads the manifest and FAILS the gate if any required check's anchor is
absent from loaded context. A check present in this file but absent from
every manifest row (an orphan) is also an H1 FAIL — the manifest and the
check set must stay in sync.

**Correctness rule (do not over-slice).** When a check's firing gate is
uncertain, include its ID in every candidate type's row: over-inclusion
is safe (the check self-skips), under-inclusion silently drops a check a
gate needs.

## Consumer-catalog crosswalk (label the catalog; never join by number)

A consumer's extension check numbers (`extensions/checks/`, Rule 27) are its own
namespace and DO NOT map to this file's numbers. Extensions are **additive**, so at
load time both catalogs render into ONE merged list under the SAME integers: `24` is
this file's adversarial-convergence check *and*, in a consumer, whatever that
consumer numbered 24. **A bare number is not a referent**, and the moment it is
written into a gate log it becomes a permanent one.

**So label the catalog at the point of use** — in the heading the lead reads, and in
the gate-log row the lead writes. The distinction must survive into the durable
record; it cannot rest on the reader recalling this rule at the instant the number is
committed to evidence.

- Core check heading: `### 24. [core] The adversarial cycle CONVERGED (Rule 8).`
- Extension check heading: `### 24. [ext:<id>] Financial-display ground-truth live-verify.`
- Gate-log row id: `[core] 24 — <title>` / `[ext:<id>] 24 — <title>`

`<id>` is the extension file's `id:` frontmatter — the same key `GATE_METRIC v1`
already emits in its `catalog` field (Check 12), so the human render and the machine
record name the catalog identically. **The integer never moves**: `Check 24` ≡
`[ext:x] 24`. The label is added, nothing is renumbered, so existing history maps by
identity and no consumer must renumber on an upstream release.

A check read from `extensions/checks/` belongs to that file's catalog **however its
heading is written** — a consumer that has not yet added the label is still correct,
merely not yet legible. Adding the label is hardening, not a prerequisite.

**Align fire history by title/intent, never by number** — including "catches" counted
from retros and escalations. Resolve a bare `Check N` written before a consumer
adopted the label through that consumer's crosswalk table (`extensions/README.md`),
**not by date**: Check 12 mandates that gate logs are rotated cut-and-paste into
archives, so a git date on a rotated line is the *rotation* date, not the authorship
date. Dating a reference is unsound here; titling it is not.

**Minimum mechanism (Rule 26(c)).** Failure caught: two unrelated checks sharing one
integer in the merged document, so `Check 24: PASSED` in the audit trail has no
referent — and, in the other direction, a consumer check upstream already absorbed
under a *different* number, duplicated forever because the retirement signal joined on
the number. Enforced by `scripts/validate-layer-entries.sh` (E6: a check extension
that redefines a core check number with a different title is an ERROR) and
`ai-dlc-update`'s `reconcile/layer-drift.sh`
(`EXTENSION-CHECK-NUMBER-COLLISION` / `EXTENSION-RESTATES-CORE`, both title-joined and
level-triggered, so a duplicate absorbed releases ago still reports). Remove when core
and consumer catalogs no longer share a rendered namespace.

## Validation Checklist

**Gate-adjudication escalation (before the checklist).** The lead may run on a cheaper model;
the `adjudication: llm` checks (read-and-compare judgment) are escalated, once per gate, to a
fresh Opus `gate-adjudicator`. At gate entry: generate `gate_nonce` (`<gate_type>-<UTC>`),
then READ AND FOLLOW `_gate-procedures.md` "Gate-adjudication dispatch" — dispatch the
adjudicator `run_in_background`, join its verdict. While it runs, evaluate ONLY the `script` /
`project` / `lead` checks below; inline-evaluating an `llm` check is a Rule 20 solo violation.
Adopt the adjudicator's per-check verdicts through the terminal **Check 26** (fail-closed).
H1/H2 stay with the lead — a self-test is never escalated into the mechanism it polices.

### 1. Validation cycle complete?
<!-- CHECK_LOADED: 1 -->

- For planning artifacts: Party Mode completed? Advanced Elicitation
  completed? Adversarial Review completed (2+ passes, only nitpicks
  remain)?
- For implementation artifacts: Code Review approved? QA approved?
  Story Validation passed?
- If any required validation was skipped, run it now before proceeding.
- **Evidence:** Gate log must record which validations were run and their
  outcomes. "Completed" without evidence is not completed.

### 1c. Research-invocation enforcement (research-requirements gate only).
<!-- CHECK_LOADED: 1c -->

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
<!-- CHECK_LOADED: 2 -->

- Read `docs/escalations/pending.md` (if it exists).
- If any entry has status `HARD_BLOCK` and is not RESOLVED, do NOT
  proceed. `touch _bmad-output/pipeline-paused.flag` (Rule 3), then
  report the block and wait for human input.
- `DECIDED_AUTONOMOUSLY` entries do not block. They are informational.
- `DEFERRAL_REQUEST` entries block only the deferred item, not the
  pipeline. Proceed with non-deferred work.
- A HARD_BLOCK marked `RESOLVED`/`OVERRIDDEN` must cite the operator — enforced by
  Check 2a below.
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

### 2a. Escalation resolution operator-citation?
<!-- CHECK_LOADED: 2a -->

A HARD_BLOCK exists because the decision is the operator's. Marking one
`RESOLVED` (or a `DECIDED_AUTONOMOUSLY` entry `OVERRIDDEN`) asserts the
operator adjudicated it — so the entry MUST carry
`**Operator authorization:** <ISO ts> | "<verbatim operator quote, ≥12 chars>"`
(see `escalations.md`).

**Check.** Invoke `scripts/validate-escalation-resolution.sh --escalations
docs/escalations/pending.md --sprint <N> --transcript <this session's
transcript_path>`; exit 0 required. It reads **this sprint's**
RESOLVED/OVERRIDDEN entries (entries carry the sprint in their header;
legacy sprints are out of scope, so the gate does not wedge on old data)
and verifies each citation against the session transcript with the same
genuine-operator predicate Rule 29 uses (`validate-steering-budget.sh
--cite`). A lead-authored "operator disposition" whose quote appears in no
genuine operator message **FAILS** — the S290 failure, where six
`S290-* Lead (…)` escalations were flipped to RESOLVED in a window with
zero operator messages. If you made the call yourself, its status is
`DECIDED_AUTONOMOUSLY` (informational, non-blocking, no citation). Fails
**closed** if `--transcript` is omitted — a forgotten flag cannot silently
disarm the check.

### 3. Requirement anchor integrity?
<!-- CHECK_LOADED: 3 -->

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

- **SUPERSEDED ADR LR disposition.** When an ADR is marked SUPERSEDED
  mid-sprint (per HB-class operator decision authoring a successor
  ADR-bis), every LR in the artifact body that directly instantiates
  the superseded ADR MUST carry an explicit disposition: SUPERSEDED
  (with pointer to successor ADR section) OR AMENDED (with successor
  ADR's effective LR text inline). Silent LR drop (LR text removed
  from artifact body without SUPERSEDED/AMENDED marker) FAILS the
  gate. Remediation: append disposition marker to each affected LR
  before proceeding.

### 3a. Story validation origin check (story gates only).
<!-- CHECK_LOADED: 3a -->

**Scope.** This check fires only when the gate being validated is a
story-level validation gate (invoked from `stories-test-strategy.md`
for story readiness, or from `implementation.md` for story completion).
Skip this check for all non-story gates (planning-artifact gates,
sprint-level gates, deployment gates).

**Check.** For each story being validated, identify its origin:

1. A specific requirement in CLAUDE.md or `docs/coding-conventions.md`.
2. User feedback captured in an escalation or planning artifact.
3. A carry-over item from a previous sprint
   (`_bmad-output/planning-artifacts/carry-over-backlog.md`).
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

### 3b. Locked-requirement full-text anchor integrity (story gates).
<!-- CHECK_LOADED: 3b -->

**Scope.** Story-level gates only. Complements Check 3, which does
INTRA-artifact drift detection (a LOCKED block vs. its own body) and
never compares a story's block against the PARENT source of record.
So a story whose block and body both carry the same lossy summary
passes Check 3 while still being a mis-anchored, summarized
propagation. Check 3b closes that hole with a script.

**Schema (`stories-test-strategy.md` §2a).** A story `LOCKED_REQUIREMENTS`
block distinguishes a full-text CLAIM from a load POINTER:
- `full_text_source: <artifact>:<anchor>` — asserts the verbatim
  requirement lives at this anchor. Byte-enforced.
- `requires_context: <artifact>#<anchor>` — a dev-time load pointer,
  NOT a full-text claim. Never byte-matched (honest cite-by-reference
  stays legal).

**Check.** For each story, invoke
`scripts/validate-locked-anchor.sh <story-file>`; exit 0 required. For
every `full_text_source:` citation it asserts (a) the artifact is the
byte-verbatim source of record — default `product-brief.md`, where
discovery.md §4a extracts the block — and NOT a condensed index
(e.g. prd.md, which is only §2a-propagated); (b) the anchor exists in
that artifact; (c) every requirement bullet in the block is byte-present
there (whitespace-collapsed). A block with only `requires_context:` or
no full-text claim is untouched (Check 3 covers it).

**PASS:** the script exits 0. **FAIL:** a `full_text_source` cites a
non-source-of-record / index artifact, a dangling anchor, or a bullet
not byte-present at the source of record.

**Category-error rider.** Context/tool thresholds (e.g. the ctx
`INTENT_SEARCH_THRESHOLD`) gate what re-enters the conversation on an
intent-bearing tool call; they never gate what is written to a file.
Never shape durable artifact content — including which requirement text
a story inlines — to satisfy a tooling constraint.

### 4. Template placeholder detection?
<!-- CHECK_LOADED: 4 -->

- Scan all story files in the current sprint for template placeholders:
  `{{...}}`, `[TODO]`, `[TBD]`, `<placeholder>`, empty Dev Agent Record
  fields.
- Run: `grep -rn '{{.*}}' _bmad-output/planning-artifacts/stories/`
- **Gate FAILS** if any placeholder is found. Dev must populate before
  proceeding. This is not a warning — it is a hard gate blocker.
- **Evidence:** Log the grep command and its output (or "0 matches") in
  the gate log entry.

### 5. Story status consistency?
<!-- CHECK_LOADED: 5 -->

- For every story in the current sprint, verify:
  - Story file `Status:` header value
  - Corresponding entry in `sprint-status.yaml`
  - These MUST match exactly.
- Run: Read both files, compare status values programmatically.
- **Gate FAILS** if any story has mismatched status between the two files.
  Fix the mismatch before proceeding.
- **Non-vacuous assertion (implementation gates only).** At Phase 4+
  gates, `sprint-status.yaml` MUST contain ≥1 story entry for the
  current sprint. If zero stories are found at an implementation gate,
  Check 5 FAILS — a sprint with no stories cannot pass status
  consistency. Planning-phase gates (where stories are not yet created)
  are exempt from this sub-clause.
- **Duplicate parent-key drift check.** Every parent key in
  `sprint-status.yaml` (e.g., `sprint-<N>-<name>:`) MUST be
  uniquely-rooted. Multiple parent keys with the same name produced
  by parallel worktree commits is a structural drift mode that this
  check catches at the parent level (per-story drift is caught
  above). Gate FAILS if duplicate parent keys are detected; lead
  consolidates under a single parent before gate-pass.
- **Evidence:** Log the comparison results in the gate log entry.
  List each story ID and its status in both files.

### 6. Production integrity tests exist? (Implementation gates only)
<!-- CHECK_LOADED: 6 -->

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
<!-- CHECK_LOADED: 7 -->


- All planning artifacts referenced by stories exist on disk.
- Architecture doc exists and is current (not stale relative to PRD).
- Sprint-status.yaml exists and contains entries for all sprint stories.

### 8. Deployment evidence? (Implementation gates only)
<!-- CHECK_LOADED: 8 -->

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
<!-- CHECK_LOADED: 9 -->

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
<!-- CHECK_LOADED: 10 -->

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
<!-- CHECK_LOADED: 11 -->

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
<!-- CHECK_LOADED: 11a -->

Skip this check for planning phase gates. Required for Phase 4+ gates.

- For every story in the sprint whose smoke tests include a live-against-production path gated by an environment variable (e.g., `SMOKE_TESTS_LIVE=1`):
  - Check the story's Dev Agent Record for explicit documentation that the live run was attempted — the command invoked, the envvar that gated it, and the outcome (PASS, FAIL with details, or pool-scoped skip with justification).
  - A test-suite run with the envvar unset does NOT satisfy this check — the live path was skipped, not exercised.
- **Gate FAILS** if any story with an envvar-gated live-run path lacks attempt evidence in its Dev Agent Record. The story must re-run under the documented envvar before the gate can pass.
- Stories whose smoke tests have no live-against-production path are exempt.
- **Evidence:** Log which stories had envvar-gated live paths, the envvar names, the commands invoked, and the documented outcomes.

### 12. Append gate log entry.
<!-- CHECK_LOADED: 12 -->

Create or append to `_bmad-output/implementation-artifacts/gate-log.md`.
Use the format defined in CLAUDE.md Autonomous Gate Protocol section.

The gate log entry MUST include:
- Gate name and phase
- Timestamp
- Result for EACH numbered check above (PASSED/FAILED/SKIPPED with reason)
- Evidence artifacts collected during checks
- Any remediations performed
- `steering_violations: <N>` — the count Check 25 read (or `SKIP` if no transcript
  resolved). This is the **baseline the next gate compares against**, so it is
  written on every gate, PASS or FAIL. Omitting it silently resets the baseline to
  0 and forgives every violation committed since the last gate.

A gate log entry without per-check results is incomplete and must be
rewritten before proceeding.

**Every per-check row id carries its CATALOG** — `[core] 24 — <title>` for a check
from this file, `[ext:<id>] 24 — <title>` for one from a consumer
`extensions/checks/` file (`<id>` = that file's `id:` frontmatter). A bare `24` is
NOT acceptable: extensions are additive, so both catalogs render into one merged list
under one integer, and the number you write here is the durable audit record. This
row is the exact point at which the ambiguity becomes permanent, which is why the
label belongs here and not only in a rule upstream of it (see "Consumer-catalog
crosswalk" above). Include the title in the row as well — it is the key that resolves
any historical entry written before the label existed.

**Post-write verification.** After appending the gate log entry, read
the **tail** of `_bmad-output/implementation-artifacts/gate-log.md`
(e.g. `tail` the last entry, not the whole file — per Rule 25(c)) and
verify the entry appears at the end. A gate log write that silently
fails (tool error, truncation, wrong path) means the gate passage is
unrecorded. Verification catches this before the pipeline moves on.

**Rotation (Rule 25(c)).** When the live gate-log exceeds its size
threshold (default 25k tokens) or at an epoch boundary, move the
closed-epoch entries to `gate-log-archive-<epoch>.md` (cut-and-paste,
verbatim) so the live log holds only the current epoch. The archive is
write-only and never re-read in the hot path.

**Structured metrics emission (`GATE_METRIC v1`).** After the prose entry
is written and verified above, ALSO append — for every **validation** check
evaluated at this gate — one JSON object per line to
`_bmad-output/implementation-artifacts/gate-metrics.jsonl` (append-only,
machine-read only, never loaded verbatim; rotates with the gate-log epoch
to `gate-metrics-archive-<epoch>.jsonl`). This is the same per-check
verdict data the prose entry already carries, emitted machine-readable so
consumer history yields decisive efficacy/cost data (no prose parsing, no
cross-catalog confound). Per-line schema:

```
{"v":1,"sprint":<N>,"gate":"<type>","phase":"<from→to>","ts":"<ISO8601Z>","sha":"<HEAD>","catalog":"core","check":"<id>","title":"<short>","verdict":"PASS|FAIL|NA|DEFERRED","defect_class":<"token"|null>,"evidence":"<path|run-id>","tok_slice":<int>}
```

- **Emit validation checks only — NOT the procedural gate-mechanics checks
  12–15** (this log-append, 13 announce, 14 snapshot, 15 verify-snapshot).
  Emit every other check the manifest loaded for this gate type (the
  universal-core validators + the gate-type row), including those recorded
  `NA` — an `NA` exposure is signal (the check ran and self-skipped).
- **`catalog`** namespaces the check id: distribution checks emit
  `"core"`; a consumer domain check (Rule 27 `extensions/checks/*.md`)
  emits `"extension:<that file's frontmatter id>"`. This is what makes a
  consumer's `check` numbers un-conflatable with this catalog's (see the
  "Consumer-catalog crosswalk" note above) — never attribute across
  catalogs by number.
- **`verdict`** is machine-countable; **`defect_class`** is a short
  taxonomy token on a real catch/remediation (e.g. `missing-provenance`,
  `orphaned-fn`, `stub-unbacked`, `intensity-under-run`), else `null`.
- **`evidence`** is a pointer (path / run-id), never prose.
- **`tok_slice`** is **REQUIRED** (integer): the token cost of this check's
  loaded slice — the cost side of efficacy, so cost-vs-catch is computable
  without re-measuring. Emit the check's own token size as loaded this gate
  (a stable per-check figure; `scripts/audit-machinery-efficacy.js` prints
  the current per-check counts). Never `null` — a record without a real
  `tok_slice` cannot answer "does this check earn its cost."

The prose gate-log is unchanged and remains the human/audit trail; this
record is additive. Absence of the file on a consumer simply means audit
tooling falls back to the prose path. Consumed by
`scripts/audit-machinery-efficacy.js` and any analytics dashboard.

### 13. Announce gate passage.
<!-- CHECK_LOADED: 13 -->

Output a brief line to the conversation only AFTER Checks 14 and 15
below have also passed.

"Gate [name]: PASSED — all checks passed — proceeding to [next phase]"

Include the check count so the human can verify completeness at a glance.

When any check FAILs due to a HARD_BLOCK resolution, the gate
log entry MUST include `hard_block_fail: true` and cite the
HARD_BLOCK ID from `docs/escalations/pending.md`.

### 14. Update pipeline snapshot.
<!-- CHECK_LOADED: 14 -->

Update `_bmad-output/pipeline-snapshot.md` to reflect the gate passage
and current pipeline state. The snapshot is a living document maintained
throughout the pipeline and is the source of truth for state on handoff,
post-`/compact` recovery, and lead self-orientation.

**Canonical snapshot structure — seven required sections.** Lightweight
markdown, no YAML frontmatter. This is the authoritative definition of
the snapshot's shape (referenced by the SKILL.md Handoff Protocol and by
`route.md` Step 0 on resume). Refresh these sections at every gate:

- **Pipeline Position** — variant; update `current_step_file` (just
  completed), `last_completed_step_file`, `last_gate_passed` (gate name +
  timestamp), and `current_branch` (refresh from
  `git branch --show-current`); plus any handoff-only resume instruction
  not derivable from the other fields (e.g., a bg watcher PID the
  successor must re-arm) so that a bare `/ai-dlc resume` is
  self-sufficient.
- **Sprint Context** — sprint ID (or `none`); stories in scope with
  statuses, synced with `sprint-status.yaml`
  (stories_completed_this_sprint, stories_in_progress,
  stories_not_started); `validation_intensity` (full | standard |
  lightweight). Update sprint_id if it changed. If `is_ui_epic` was
  determined during this gate's step (set in `stories-test-strategy.md`
  Step 7), record it here so `deploy-validate.md` can read it from the
  snapshot after a handoff or `/compact` rather than re-detecting.
- **Recent Activity** — last ~10 entries of gate passages, significant
  commits, key artifacts touched. Append a one-line entry for this gate
  passage (gate name, timestamp, key artifacts touched); older entries
  can be pruned.
- **Open Items** — unresolved triage items, pending human decisions,
  outstanding adversarial review findings; refresh from current state of
  `docs/escalations/pending.md` and any open triage items.
- **Locked Decisions** — locked requirements and human-flagged direction
  changes the lead accepted; append any new ones confirmed during this
  gate.
- **In-Flight Teammates** — one row per dispatched teammate not yet
  joined: `agent name | role | deliverable path | dispatched-at`. A row
  is added at dispatch and **DELETED at join** (see `_gate-procedures.md`
  "Sub-step snapshot update"). An empty table is normal and means nothing
  is in flight.
  **Rows only. No prose, no struck-through history.** A consumed teammate
  is not in flight; Recent Activity and the gate log already record that
  it delivered. The section is bounded by the teammates actually
  outstanding.
- **Context Reminders** — `context_reminders_sent` (none | yellow |
  red), `last_yellow_fire_tokens`, `last_yellow_fire_turns`,
  `last_red_fire_tokens`, `last_red_fire_turns`. Reconcile these from
  the context sensor's sidecar per the procedure in
  `_gate-procedures.md` "Context reminder threshold check". The sensor
  measures and fires; this gate only records what it did.

A lead that cannot address a teammate must not conclude the teammate
died. Being unreachable is not evidence of death — neither a lost
`agent_id` nor a wrong-API error is. Re-join on the deliverable path
recorded here; it needs no handle and survives compaction (Rule 29 —
the file IS the handle).

**Context reminder threshold check (required at every gate).** The
`ai-dlc-context-sensor.sh` Stop hook measures resident context every turn,
fires the Rule 2(b)/(c) reminder, and owns dedupe and recurrence. This gate
check reconciles the snapshot's Context Reminders fields to the hook's
sidecar `_bmad-output/.context-sensor-state`; it does not evaluate a
threshold or produce an estimate. The reconciliation procedure is in
`_gate-procedures.md` "Context reminder threshold check". Run it at every
gate. The fields and thresholds remain authoritative here.

The canonical section structure is defined above in this check; see the
SKILL.md Handoff Protocol and Pipeline Snapshot section for the
snapshot's role and rationale (source of truth on handoff / recovery /
self-orientation).

A gate passage without a corresponding snapshot update leaves the
snapshot stale, which undermines its role as the handoff / recovery /
self-orientation source of truth. Do not skip this check.

**Snapshot budget (Rule 25(d)) — this check FAILS if the snapshot is over it.**
After writing, run:

    scripts/verdict.sh validate-artifact-budget --only pipeline-snapshot.md

`verdict.sh` prints one line and exits with the validator's own status. Never
pipe a validator into `grep` to read its verdict — the pipe hands the exit
status to `grep`, and a validator that prints FAIL and exits 1 then reads as a
pass.

Exit 1 → **Check 14 FAILS.** Trim the snapshot to the seven-section schema defined
above (the `Recent Activity` section holds the last ~10 entries and nothing more;
superseded narrative and handoff appendices move to `pipeline-snapshot-history.md`,
which is write-only), then re-run Check 14 and Check 15.

A `warn` line (over budget, inside the grace band) does **not** fail the gate — trim
at your next natural pause. See Rule 25(d), "Warn at 100%, block at 100% + grace."

The snapshot is the only artifact whose budget is enforced *at gates* rather than
only at sprint start: it is the only one that grows *within* a sprint. The protocol
whole-reads it here (Checks 14/15), on every resume, and after every compaction
(`ai-dlc-recover.sh`).

A snapshot over budget means the schema stopped being enforced at gate passages.
**The gates that let it grow are the finding — not the file.**

### 15. Verify snapshot reflects this gate.
<!-- CHECK_LOADED: 15 -->

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

- **Direct-to-main commit audit.** At retro gate, scan `git log
  main..<sprint-branch>` for merge commits or commits that bypass
  the sprint branch workflow. Any commit pushed directly to main
  during the sprint window that is not a retro PR merge is flagged
  as a process violation. The retro MUST document the commit and
  classify it (emergency hotfix, operator override, or unauthorized
  bypass).

**Gate FAILS** if any of the above do not match. Remediation: re-run
Check 14 (re-write the snapshot) and then re-run Check 15. If Check
15 fails twice in a row, escalate as HARD_BLOCK — the snapshot
writer is broken and the gate should not pass with a stale
recovery anchor.

### 16. Stub audit (hot-path files) — content verification.
<!-- CHECK_LOADED: 16 -->

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
<!-- CHECK_LOADED: 17 -->

**Scope.** Runs at the retro gate unconditionally. Also runs at any
gate where a validation evaluation (bmad-party-mode,
bmad-advanced-elicitation, bmad-review-adversarial-general,
bmad-validate-prd, ai-dlc-adversary-review) was required by the current
phase. Skip on gates that do not produce a provenance-bearing artifact.

**Block schema (`SKILL_INVOCATION_PROVENANCE v1`).** Every validation
evaluation (Rule 20) MUST emit this block into the artifact it
produces; `validate-provenance-block.sh` parses it:

<!-- BEGIN GENERATED: provenance-block/full — source: schemas/provenance-block.json; do not edit by hand -->
```
<!-- SKILL_INVOCATION_PROVENANCE v1
skill: <bmad-party-mode|bmad-advanced-elicitation|bmad-review-adversarial-general|bmad-validate-prd|ai-dlc-adversary-review> # the evaluation that ACTUALLY RAN. Naming one you did not invoke is a forged block.
invoked_at: <ISO 8601 UTC, to the second>   # Check 24 orders the pass series on this. Ambiguity here reorders the cycle.
tool_use_id: <toolu_... — from the Skill tool response, or the Agent dispatch that spawned you> # the only non-forgeable evidence the evaluation ran in a real independent context.
mode: subagent                              # never solo.
lead_role: <the step file that invoked or dispatched the evaluation> # which step owns this pass.
transcript_path: <_bmad-output/party-mode-transcripts/sprint-<N>-retro.md@<sha>> # required for retro party-mode; byte-matched by validate-retro-evidence.sh.
artifact: <path of the artifact you reviewed> # what this pass reviewed.
artifact_sha: <sha256 of that file, as you read it> # `shasum -a 256 <artifact> | cut -d' ' -f1`. Makes the pass a notarization of the bytes it reviewed, which is what lets the gate later prove a claimed revert landed on a state some pass actually saw.
findings_critical: <int>                    # the residue the verdict is adjudicated against.
findings_critical_prior_scope: <int>        # of the CRITICALs above, those in text the PRIOR pass also reviewed. OPTIONAL BY DESIGN: absent means the validator assumes ALL of them (fail-closed). Requiring it would invert that default and reject the safe omission. This is what separates 'not converging' from 'the document is moving'.
findings_major: <int>                       # omit it and the stall rung goes silent for the ENTIRE series.
findings_minor: <int>                       # the nitpick bucket. Does not block the exit condition.
resolves_divergence: <path to the resolution record> # ONLY on the verification pass, and only if the pass before you STOPPED.
verdict: <EXIT_CONDITION_MET|EXIT_CONDITION_NOT_MET|DIVERGENT_HARD_BLOCK> # required on every adversarial-review pass. There is no free-text verdict.
SKILL_INVOCATION_PROVENANCE_END -->
```
<!-- END GENERATED: provenance-block -->

The block above, the parser in `validate-provenance-block.sh`, and the example every role
file shows its agent are all rendered from / loaded from `schemas/provenance-block.json`.
**Do not hand-write a provenance example anywhere** — `scripts/sync-taught-schema.sh --check`
fails the build on one, because a hand-written copy is a copy that can drift, and when this
one drifted the reader parsed nothing and the gate called two unadjudicated passes clean.

**The four adversarial fields.** `findings_*` and `verdict` are REQUIRED
on every `ai-dlc-adversary-review` / `bmad-review-adversarial-general` /
`bmad-validate-prd` pass and are absent elsewhere (party-mode and elicitation
produce no severity residue). The residue decides the verdict; see the mapping
in `team-roles/adversary.md` ("The verdict"). Check 24 enforces it.

**`ai-dlc-adversary-review` — the CONVERGENCE review (v0.58.0).** The Rule 8
cycle invokes NO skill: the lead dispatches the `adversary` role, which runs the
native method in `team-roles/adversary.md`. The bmad skill is kept for the
ONE-SHOT reviews only (`bug-investigation`, `sprint-review`, the test-strategy
sweep), because its contract — *find ≥10, HALT on zero, emit no severity* — has
no fixed point in a loop whose exit condition is zero CRITICAL and zero MAJOR,
and it forbids the very fields this gate reads. `tool_use_id` is the Agent
dispatch's; the block is emitted by the adversary, as before.

**Mode enforcement (Rule 20 — every tracked evaluation).** `mode` MUST be
`subagent` for EVERY validation evaluation, not only party-mode: it runs in a
real independent subagent (party-mode spawns personas internally; single-voice
skills and the convergence review are dispatched to a Rule-19-bound teammate).
`mode: solo` is a violation — the lead roleplayed the validation in its own
context — and FAILS this check. `validate-provenance-block.sh` rejects
`mode: solo` on ANY provenance block, unconditionally: that assertion used to be
gated on the skill enum, which meant a new evaluation name could silently disarm
it. It is no longer gated on anything.

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
  --require-skill ai-dlc-adversary-review` for each story.
  *(v0.58.0: was `bmad-review-adversarial-general`. The stories cycle is a
  CONVERGENCE cycle, so it now stamps the native identifier. A consumer that
  pins the old name in an override — dev/qa/code-reviewer pre-submission
  checks are the usual site — MUST update it in the same pull, or the pinned
  check fails at runtime on the first story of the next sprint.)*

**PASS:** all required provenance scripts exit 0. **FAIL:** any
script reports a missing block, malformed field, unknown skill,
`mode: solo` on any block, missing transcript file (retro
only), or SHA byte-mismatch (retro only).

### 18. Per-class test-debt audit.
<!-- CHECK_LOADED: 18 -->

**Scope.** Runs at sprint-review gate. Reads
`_bmad-output/audit-anchors.md` to determine the prior-sprint retro-PR
merge SHA.

**Check.** First run `scripts/validate-audit-anchors.sh --entries
_bmad-output/audit-anchors.md` — it enforces every entry conforms to the
canonical schema (`.claude/schemas/audit-anchors.json`). A non-zero exit FAILS
this check CLOSED (a malformed entry is a schema regression, not a clean file).
`--entries` deliberately does NOT require the rendered header — a consumer whose
file predates this schema is not wedged here; its next retro (Step 5b) re-seeds
and full-validates the header. Then resolve `<prior_sprint_sha>` from the most
recent prior sprint entry (current sprint number minus one). If absent, gate
FAILS CLOSED with explicit message — silent skip on missing audit-anchor is
forbidden.

For each per-class test category audit applicable to the current
sprint (categories defined by the project), run
`<audit-script> --since <prior_sprint_sha>` over the project's test
directories. Capture PASS/FAIL per category in gate-log entry.

**PASS:** every applicable category audit reports PASS or
ACCEPT-WITH-RATIONALE. **FAIL:** any category reports
REFACTOR-IN-SPRINT (must be addressed before gate close) OR no
`audit-anchors.md` entry exists for prior sprint.

**Producer mandate.** `retro.md` Step 5b at sprint close MUST append
a new entry to `_bmad-output/audit-anchors.md` with the current
sprint's retro-PR merge SHA. The schema is canonical in
`.claude/schemas/audit-anchors.json`; the file header is RENDERED from it by
`scripts/validate-audit-anchors.sh --render` and enforced by that script — it
is NOT defined by the live header or the (reference-only) template.

### 19. Self-reflexive Gate 2 self-discrimination map application.
<!-- CHECK_LOADED: 19 -->

**Scope.** Runs at every Gate 2 (code-review gate) for any PR
carrying acceptance criteria flagged as discrimination-evidence ACs
— specifically (a) PRs that flip a CI gate from advisory to
enforce-fail-on-detect, (b) PRs that introduce or modify a CI
detector regex/awk/script, and (c) PRs whose ACs explicitly require
the reviewer to cite FAIL→PASS run-ID evidence. SKIPS at all other
gates.

**Check.** Reviewer's draft Gate 2 verdict MUST cite by-name
application of the `code-reviewer.md` Self-Discrimination Map
section to each discrimination-evidence AC under review. Citation
format: a verdict line that names which of the three failure
patterns (Pattern 1 reviewer-asserts-without-rerun, Pattern 2
ancestor-check-fabrication, Pattern 3 rubber-stamp-without-REPL)
were checked against the draft, with the disposition for each.

A reviewer-PASS verdict on a discrimination-evidence AC without the
self-discrimination map citation FAILS this check.

**PASS:** every discrimination-evidence AC in the PR has an
accompanying map-citation block in the Gate 2 verdict, and each
named pattern is dispositioned (CLEAR, REVISED, or N/A with one-
line rationale). **FAIL:** any discrimination-evidence AC carries a
PASS verdict without map citation, OR the citation block omits one
of the three named patterns.

**Reference.** Map content + the three failure patterns are defined
in `core/team-roles/code-reviewer.md` "Self-Discrimination Map"
section. This check enforces application; the reviewer role file
owns the pattern definitions. No content duplication.

**Core-path wiring-citation extension.** Also at Gate 2: when the PR's
diff adds or changes a public function on a primary deliverable path (a
non-test source file on the sprint's deployed-product path), the
reviewer's PASS verdict MUST cite, per such function, EITHER (i) a
traced non-test caller — the `grep -rn "<name>" <source-root> | grep -v
/tests/` result showing more than the definition line — OR (ii) a
mutation-RED wiring test that drives the real entrypoint (call site
removed → test RED, captured run) for any function whose spec or ADR
says it runs in / is called from a loop, scheduler, or entrypoint. A
reviewer-PASS on such a function citing NEITHER FAILS this check: an
inert-feature defect (a function implemented and unit-tested but never
invoked in production) slipped through Gate 2. This is the gate-side
meta-check that the orphaned-function / core-path wiring enforcement was
actually applied — the reviewer severity is owned by
`core/team-roles/code-reviewer.md` "Orphaned Function / Core-Path Wiring
= Critical", the QA-inspection counterpart by `core/team-roles/qa.md`
"Orphaned-function / core-path wiring (HARD GATE)", and the seam
non-deferral rule by `sprint-review.md` "Core-path seam non-deferral";
this clause verifies the PASS verdict carries their evidence, exactly as
the self-discrimination clause above verifies the map was applied.
**False-positive cost:** low — the reviewer already runs the caller
trace, so this requires only that the verdict cite evidence it already
holds; a PR adding no public function on a deliverable path is N/A.
**Removal condition:** when a CI orphaned-function detector fails the
build on any un-wired new public function, making the reviewer citation
redundant.

### 20. Validation-intensity compliance (all planning gates).
<!-- CHECK_LOADED: 20 -->

**Scope.** Fires at every planning-phase gate. Skips for implementation,
deploy-validate, and retro gates.

**Check.** Read `validation_intensity` from the pipeline snapshot's
Sprint Context. Confirm the validation cycle run at this gate met at
least the declared intensity's minimum:
- `full`: Party Mode + Advanced Elicitation + Adversarial Review (2+
  passes) — all three MUST have been invoked.
- `standard`: Party Mode + Adversarial Review (1+ pass) — both MUST have
  been invoked.
- `lightweight`: Adversarial Review (1 pass) MUST have been invoked.

An architecture gate that reaches a NO-CHANGES-NEEDED assessment MAY
skip the validation cycle (fast-track). The gate log entry MUST record
`validation_intensity: <level>` and `minimum_met: true|false`. The check
FAILS if the declared minimum was not met. Declared intensity MUST NOT
reduce the always-required floors — carry-over-eval Party Mode, retro
Party Mode, and deploy-validate smoke remain mandatory at every
intensity.

**Minimum mechanism (Rule 26(c)).** Failure caught: a planning gate that
under-ran its declared intensity (a `full` sprint that skipped Advanced
Elicitation or ran a single adversarial pass), silently downgrading
operator-selected rigor. False-positive cost: a sanctioned fast-track
(architecture NO-CHANGES-NEEDED) counted as a miss — resolve by
recording skip provenance in the gate log, not by failing. Removal
condition: retire once validation-cycle invocation is made structurally
unskippable per intensity.

**Graph→distribution number mapping.** This is graph's Check 21
(validation-intensity) absorbed as distribution **Check 20**; recorded
so a future graph reconciliation does not re-flag it as new.

### 21. Test-strategy deliverable presence (sprint-review gate).
<!-- CHECK_LOADED: 21 -->

**Scope.** Runs at the sprint-review gate for any sprint that produced a
test-strategy deliverable (`stories-test-strategy.md` Step 5). Skips
sprints with no test-strategy artifact.

**Check.** For EVERY test the test strategy names as a required
deliverable, confirm BOTH: (a) a matching test exists on disk at the
path/identifier the strategy names — resolved by grep/collection, not by
the presence of the name in prose; AND (b) that test is cited from a Dev
Agent Record (the DAR names the test and its PASS run). A test named in
the strategy but absent on disk, or present on disk but never cited from
a DAR, FAILS this check. Fail-closed: a test-strategy deliverable that
cannot be resolved to a named-and-cited test is a gap, not a pass.

**PASS:** every strategy-named test resolves to an on-disk test cited
from a DAR. **FAIL:** any named test is missing on disk OR present but
uncited, OR the strategy names tests but no DAR citation set exists.

**Minimum mechanism (Rule 26(c)).** Failure caught: a test the strategy
promised that was never written (or was written but never run/cited), so
the sprint closes claiming coverage it does not have. False-positive
cost: one grep-resolve per named test plus a DAR citation scan — cheap,
mechanical. Removal condition: retire once the test strategy is generated
as executable references (each named test is a collectable node) so
presence is structurally guaranteed.

**Graph→distribution number mapping.** Absorbed from graph's Check 33
(cross-story test-strategy §3 deliverable presence) as distribution
**Check 21**; recorded so a future graph reconciliation does not re-flag
it as new.

### 22. Teammate-spawn role binding (implementation gates only).
<!-- CHECK_LOADED: 22 -->

**Scope.** Runs at implementation-phase gates for any gate whose sprint
dispatched teammates via the Agent tool (dev, code-reviewer, qa, or a
`protected-path-editor`). Skips gates with no Agent-tool spawn.

**Check.** Read the gate log's per-teammate spawn records
(`implementation.md` Step 4 self-validate writes them). For EVERY
teammate spawn recorded this sprint, confirm BOTH bindings required by
SKILL.md Rule 19: (a) the `model` parameter was passed explicitly, and
the recorded model matches the spawned role's `/model` directive in
`.claude/team-roles/<role>.md`; AND (b) the dispatch carried the
standing role-contract line binding the subagent to
`.claude/team-roles/<role>.md` as its first action (Rule 19(b)). A spawn
record missing either the model value or the role-contract citation
FAILS this check. Fail-closed: a teammate that ran without a resolvable
role-file binding is a Rule 19 violation, not a pass.

Additionally, for any story tagged `protected_path_editor: true`
(`stories-test-strategy.md` Protected-Path Story Tag), confirm the story
was serviced by a `protected-path-editor` spawn (serialized), NOT
executed inline by the lead and NOT delegated to a dev teammate.

**PASS:** every spawn record cites both a role-matched model and the
role-contract binding, and every protected-path story routed to the
`protected-path-editor`. **FAIL:** any spawn omits a binding, cites a
model that does not match its role file, or any protected-path story was
executed inline or by a dev.

**Minimum mechanism (Rule 26(c)).** Failure caught: a subagent run
without its role contract — a dev without its ownership/constraint
boundary, or the lead absorbing a protected-path edit it should have
delegated (Rule 28). False-positive cost: one gate-log read of records
the lead already writes at Step 4 — no new artifact. Removal condition:
retire once the Agent-tool spawn API structurally attaches the role file
(no lead-authored dispatch line to verify).

### 23. Analyst-draft sprint stamps (all planning gates).
<!-- CHECK_LOADED: 23 -->

**Scope.** Fires at every planning-phase gate. Skips story,
implementation, sprint-review, and retro gates.

**Check.** Invoke `scripts/validate-draft-stamps.sh`; exit 0 required.
It asserts the four per-sprint analyst drafts (Rule 24) are written to
their sprint-stamped paths — `s<N>-carry-over-evaluation.md`,
`s<N>-discovery-context.md`, `s<N>-research-notes.md`,
`s<N>-architecture-context.md`, where `<N>` is `sprint_id` from the
pipeline snapshot's Sprint Context (resolved at `route.md` Step 6).

Two halves, because the drift has two surfaces:
- **Disk.** No unstamped draft may exist in
  `_bmad-output/planning-artifacts/`. This fires on the RENDERED
  outcome, so it catches a core regression and a consumer override
  equally.
- **Layer.** No `extensions/`/`overrides/` entry may declare an
  unstamped draft write path. A `kind: step-domain` extension restates
  its step's whole Section 0 — including the output path — so it can
  revert the stamp in the rendered pipeline while core looks correct
  (Rule 27; the v0.34.0 lesson).

The stamp lives in the **filename**. The draft's H1 is prose and is NOT
parsed — observed H1s include `Sprint 288`, `Sprint S286`,
`Sprint 285 (draft)`. Do not add an H1↔filename agreement check.

**Out of scope by design** (the script will not flag these): the
one-shot onboarding artifacts `codebase-analysis.md`,
`brownfield-inventory.md`, `doc-reconciliation.md` (written once, read
by path downstream, no sprint key), and `bug-analysis.md` (bug-keyed,
not sprint-keyed).

**PASS:** exit 0. **FAIL:** exit 1 — an unstamped draft on disk, or a
layer declaring an unstamped write path.

**Minimum mechanism (Rule 26(c)).** Failure caught: a Section 0 write
path — in core, or in a consumer layer restating it — landing an analyst
draft unstamped. These drafts have no reader, no template, and no
archive pair, so the overwrite silently destroys the prior sprint's
draft, and every citation into the file then resolves against the wrong
sprint's document — a silently-wrong answer, not an error. Observed: a
story's provenance cites `carry-over-evaluation.md §7 F6` and the file
on disk, thirty sprints on, has no §7. False-positive cost: one line per
legitimately-unstamped file, named by the check; an exemption is a
visible line a reviewer sees. Removal condition: retire once the write
path is GENERATED from `sprint_id` rather than prose-specified in each
Section 0, so it cannot drift.

### 24. The adversarial cycle CONVERGED (Rule 8).
<!-- CHECK_LOADED: 24 -->

**Scope.** Fires at every gate whose step ran an adversarial CONVERGENCE cycle —
a loop that must reach zero CRITICAL and zero MAJOR to leave. Those steps are:
`carry-over-evaluation`, `discovery`, `architecture`, `research-requirements`
(**including its `lightweight` single-pass path** — one pass is still a convergence
pass and still stamps a verdict), `stories-test-strategy`, `doc-repair-backfill`, and
`sprint-review-next`.

**This list is DERIVED, and I11 fails the build if it drifts.** It was hand-maintained,
and it rotted twice: v0.58.0 found `doc-repair-backfill` and `sprint-review-next` running
unadjudicated convergence loops and added them — and missed `carry-over-evaluation`, which
was running one too. A step whose file dispatches an adversarial review MUST appear here
and MUST also reference the repair dispatch; I11 asserts all three sets are the same set.

**Self-skips** on any gate whose step ran no convergence cycle — including gates
whose step ran only a ONE-SHOT adversarial review (`bug-investigation`,
`sprint-review`, the test-strategy sweep in `stories-test-strategy` §5). A
one-shot stamps no verdict and this check has nothing to read; do not drag its
artifact into the series.

*(v0.58.0 added `doc-repair-backfill` and `sprint-review-next`. Both have run
`2+ passes … until only nitpicks remain` since they were written, and **no gate
had ever read their verdicts** — an unbounded convergence loop adjudicated by
nobody, which reads exactly like a loop that converged. `doc-repair-backfill`
gates `planning`, so Check 24 already loaded there and only this scope clause
excluded it; `sprint-review-next` gates `story`, which is why 24 joins the story
manifest row.)*

**Check.** Invoke `scripts/validate-adversarial-convergence.sh --series
<path-prefix-of-this-step's-pass-series> --transcript <this session's transcript_path>`;
exit 0 required. Pass `--transcript` (the current session's JSONL) so arm F6 can verify a
resolution record's `operator_authorization` against ground truth; the gate **fails closed**
if a resolution cites an operator message the transcript does not contain — and fails closed
too if `--transcript` is omitted, so a forgotten flag cannot silently disarm the check. It
reads the `findings_critical` / `findings_major` / `artifact_sha` / `verdict` fields of every
pass in the series (schema above, mapping in `team-roles/adversary.md`) and enforces
seven things:

- **A — VOCABULARY.** Every pass declares a `verdict:` from the enumerated set, **and
  the CRITICAL/MAJOR counts that verdict is adjudicated against.** A pass with no
  verdict, or a free-text one, is un-adjudicable. A pass with a verdict and no counts
  turns arm E off for the whole series.
- **B — CONSISTENCY.** The verdict agrees with the residue. `0 CRITICAL + 0
  MAJOR` means the exit condition IS met — the ladder puts MINOR/NIT in the
  nitpick bucket and the exit condition is *"until only nitpicks remain."* A
  clean residue stamped `EXIT_CONDITION_NOT_MET` is a review refusing to
  converge; a dirty residue stamped `EXIT_CONDITION_MET` is one claiming a
  convergence it does not have.
- **C — DIVERGENCE (scope-relative).** A pass whose
  `findings_critical_prior_scope` exceeds the previous pass's `findings_critical`
  must stamp `DIVERGENT_HARD_BLOCK`. Rule 8: divergence is a HARD_BLOCK, not a
  reason for another pass.
  CRITICALs in scope the sprint ADDED mid-cycle are **not** divergence: they count
  in `findings_critical` and not in `findings_critical_prior_scope`. Absent field ⇒
  the validator assumes ALL CRITICALs are prior-scope.
- **D — TERMINAL.** The last pass must be `EXIT_CONDITION_MET`. If the series ends
  unconverged **and** any pass found CRITICALs in newly-added scope, the remedy is
  **freeze the artifact and cut the added scope** — not another pass.
- **E — STALL.** A nonzero MAJOR held at zero CRITICAL across two or more consecutive
  passes is a cycle that is neither converging nor diverging. Another pass is not the
  remedy: verify the disputed fact mechanically, cut the claim, or escalate.
- **F — RESOLUTION.** A pass that runs *after* a `DIVERGENT_HARD_BLOCK` must declare
  `resolves_divergence:` naming a resolution record, and that record must hold up —
  see the resume contract below. The record's `operator_authorization` must **cite** a
  genuine operator message (timestamp + verbatim substring), verified against the
  transcript: a resolution clears an operator-gated hard block, so a lead-authored one
  that quotes an operator who never spoke is rejected. (The S290 fix.)
- **G — CHRONOLOGY.** The series must be monotone in `invoked_at`. A pass that claims
  to follow another but was written before it is the tail of a **dead cycle**, left on
  disk by a restart and chained onto the live series by the glob.

It does NOT enforce the per-intensity pass floor ("2+ passes"). Rule 8 delegates
that to each planning step's own intensity gate; duplicating it here would fail
every legitimate `standard` / `lightweight` single-pass cycle.

**The resume contract — STOP → ADJUDICATE → RESOLVE → VERIFY.** A hard block does not
end the cycle; it stops it until the operator adjudicates. The exit is a **resolution
record**, `planning-artifacts/s<N>-<artifact>-resolution-p<M>.md`, and arm F reads it.
*A repair edits the artifact to close findings on UNCHANGED scope — that is what
diverged. A resolution changes WHAT IS UNDER REVIEW:* `REVERT_REPAIR` |
`CHANGE_APPROACH` | `CUT_SCOPE` | `RESTART_CYCLE`. The verification pass is the next
number **in the same series**. Procedure and record schema:
`steps/_gate-procedures.md` § *Divergence resolution dispatch*.

**FREEZE is not a resolution and is rejected by name.** A hard block means CRITICALs
rose in text a previous pass had already reviewed — text that is *already frozen*.
Freezing it again removes nothing, so the verification pass finds the same CRITICALs
and the gate can never pass. (Freezing IS the remedy for a **moving artifact** — arm
D's scope-grew branch. Different failure, opposite remedy; conflating them is what
parked a live pipeline for a day.)

Fixture: `tests/fixtures/check-24-adversarial-convergence/`. Three cases decide
shippability: `nitpicks-remain` (terminal 0 CRITICAL / 0 MAJOR with five open MINORs
must PASS), `scope-grew-converges` (a CRITICAL rise of 2→3 with only 1 in prior scope
must PASS), and **`divergent-resolved`** (hard block → resolution record →
verification pass → MET must PASS: it is the sanctioned exit, and if it goes red the
cycle has no way out of a hard block).

**PASS:** exit 0. **FAIL:** exit 1 — a pass with no verdict, a verdict
contradicting its residue, an unescalated divergent pass, or a series whose last
pass is not `EXIT_CONDITION_MET`.

**Minimum mechanism (Rule 26(c)).** Failure caught: a planning gate passing over
an adversarial cycle that never converged. Rule 8 requires convergence and calls
divergence a HARD_BLOCK, but with nothing counting a CRITICAL and nothing reading
a verdict, that requirement is unfalsifiable and termination comes from the lead
overriding the adversary's own field. False-positive cost: one line per pass, naming the field to
fix; the residue is already in the report, so stamping it costs the adversary
nothing it has not already computed. Removal condition: retire once the provenance
block is GENERATED from the findings table rather than hand-stamped, so the verdict
cannot disagree with the residue beside it.

### 25. Rule 29 bounded-join conduct — the operator was reachable.
<!-- CHECK_LOADED: 25 -->

**Scope.** Every gate. Rule 29 binds any phase that dispatches.

**Check.** Resolve this session's transcript, then compare the violation count
against the one the previous gate recorded:

    T=$(ls -t ~/.claude/projects/"$(pwd | sed 's|/|-|g')"/*.jsonl 2>/dev/null | head -1)
    scripts/validate-steering-budget.sh --transcript "$T" --count

- **No transcript** (CI, a non-Claude-Code runner) → **SKIP**, recorded as SKIP.
- Read `steering_violations:` from the **previous gate-log entry of this session**
  (Check 12 owns the field). No previous entry → baseline `0`.
- **Count INCREASED → the gate FAILS.** Unchanged → PASS.
- Record the new count as `steering_violations:` in this gate's log entry either way.

**On FAIL.** The validator names the offending calls. Re-issue any still-pending wait
through `scripts/wait-for-deliverable.sh` — one call, every path in the wave — and
record the count.

**Minimum mechanism (Rule 26(c)).** Failure caught: a hand-rolled `until`/`while`/
`sleep` wait on a deliverable blocks a foreground call past the steering budget, and
a queued operator message cannot be delivered for its duration. False-positive cost:
one line, recording a count the validator already computed. Removal condition: retire
once a `PreToolUse` deny makes the unbounded wait unwritable.

### H1. Harness meta-check — each phase-specific check has a self-test fixture.
<!-- CHECK_LOADED: H1 -->

**Recursion guard.** H1 is NOT subject to H1. When H1 runs, it sets
environment variable `H1_DEPTH=1`. If H1 observes `H1_DEPTH` already
set in the environment at entry, it returns PASS immediately without
re-enumeration **or manifest resolution** (the Lever-2 completeness
pass below is also short-circuited) to prevent infinite recursion.
Check H2 (below) verifies the guard fires on a seeded
recursive-invocation fixture.

**Scope.** Meta-check. Runs at every gate. Verifies that each
phase-specific check added to this file (currently: Check 1c, Check 3b
locked-anchor, Check 16's content-verification strengthening, Check 17
provenance, Check 23 draft-stamps, Check 24 adversarial-convergence) ships
with an adversarial self-test fixture under `tests/fixtures/` that the check
catches.

**Check.** For each phase-specific check enumerated below, confirm
both (i) the fixture directory exists with a README.md describing
the bypass scenario and a `seed.sh` reproducing it idempotently, and
(ii) the check's body references the fixture path by name so a
future reader can trace from check → fixture.

Enumerated checks under H1:

- **Check 1c** — fixture at `tests/fixtures/check-1c-bypass/`.
- **Check 3b (locked-requirement full-text anchor)** — fixture at
  `tests/fixtures/check-3b-locked-anchor/`.
- **Check 16 (stub-audit content-verification)** — fixture at
  `tests/fixtures/check-15-bypass/`.
- **Check 17 (skill-invocation provenance)** — fixture at
  `tests/fixtures/check-17-bypass/`.
- **Check 23 (analyst-draft sprint stamps)** — fixture at
  `tests/fixtures/check-23-draft-stamps/`.
- **Check 24 (adversarial cycle convergence)** — fixture at
  `tests/fixtures/check-24-adversarial-convergence/`.

**Manifest completeness (v0.24.0 Lever 2 — slicing fidelity prover).**
After the fixture enumeration, and only when `H1_DEPTH` was not already
set at entry (the recursion guard above short-circuits this resolution
too), H1 proves the slice loaded enough:

1. Read the `GATE_MANIFEST` block at the top of this file and the gate
   type the invoking step declared (§5.3).
2. Resolve the required set = universal core (1, 2, 3, 4, 7, 12, 13, 14,
   15, 16, 26, H1, H2, failure) ∪ the declared type's manifest row.
3. For each required check ID, confirm its `<!-- CHECK_LOADED: <id> -->`
   anchor is present in loaded context. A required ID whose anchor is
   absent = **FAIL** — the slice dropped a required check, identical
   severity to a skipped check.
4. Orphan check: for each `CHECK_LOADED` anchor in this file (a
   standalone-line comment directly under a check heading — not the
   `<!-- CHECK_LOADED: <id> -->` format examples written inline in this
   manifest / H1 prose), confirm the ID appears in the universal core or
   ≥1 manifest row. An anchor matching no manifest entry = **FAIL**
   (manifest drift — a check exists but no gate type requires it).
5. Unknown declared gate type (not one of `planning`, `story`,
   `implementation`, `sprint-review`, `retro`) = **FAIL**.

Seeded self-test: `tests/fixtures/check-manifest-bypass/` seeds a gate
that declares `implementation` but loads only the planning slice
(omitting Check 6/8/11); this manifest-completeness assertion MUST FAIL
it. H2 (below) re-drives that fixture.

**PASS:** every enumerated check's fixture exists with README.md +
seed.sh, the check's body cites the fixture path, AND every
manifest-required check for the declared gate type is loaded with no
orphan anchors and a known gate type. **FAIL:** any enumerated check is
missing its fixture or check-body cross-reference, OR any
manifest-required check's `CHECK_LOADED` anchor is absent, OR an anchor
matches no manifest row, OR the declared gate type is unknown.

### H2. Harness self-test — seeded forgery fixture + H1 recursion guard.
<!-- CHECK_LOADED: H2 -->

**Scope.** Meta-meta-check. Runs in full **once per sprint** — at the sprint's
first gate. Later gates in the same sprint verify the attestation and cite it.

**Start here, at every gate:**

    scripts/validate-h2-attestation.sh --verify --sprint <N>

**Exit 0** — this sprint already drove H2, and the fixture set is byte-identical
to when it did. Cite the `H2_ATTESTED v1` line the script prints. H2 PASSES. Done.

**Exit 1** — either this is the sprint's first gate, or a fixture changed. Drive
all three items below in full, then:

    scripts/validate-h2-attestation.sh --attest --sprint <N>

which re-drives the mechanical fixture itself and, on success, prints the
`H2_ATTESTED v1` line to append to the gate log. If it exits 1, **the gate FAILS**.

The three items:

1. **H1 recursion guard fires.** Re-invoke the H1 check with `H1_DEPTH=1` pre-set
   in the environment; H1 MUST return PASS immediately without re-enumerating
   fixtures. `tests/fixtures/check-h1-recursion/seed.sh` sets the guard and writes
   the state file. (LLM-adjudicated: the seed establishes the condition, you judge
   the response.)

2. **Seeded provenance-block forgery is caught.** `tests/fixtures/check-17-bypass/`
   writes five variants; `run.sh` drives the real validators and asserts the matrix.
   V1–V4 must FAIL `validate-provenance-block.sh`; V5 — a well-formed block citing a
   fabricated transcript SHA — must **PASS** that script and be caught only by
   `validate-retro-evidence.sh`'s byte-match against git. V5 is the forgery floor.
   (Mechanical: `--attest` runs it and fails the gate if it does not hold.)

3. **Seeded slicing-bypass is caught by H1.** `tests/fixtures/check-manifest-bypass/`
   writes a real gate-context file declaring type `implementation` while carrying only
   the planning slice's `CHECK_LOADED` anchors — checks 5, 6, 8, 9, 10, 11, 11a, 19,
   22 are absent. H1's manifest-completeness pass MUST FAIL it, naming at least one
   missing anchor. A seed H1 passes means the v0.24.0 slicing re-expression does not
   hold and a real gate could silently drop a required check. (LLM-adjudicated.)

**PASS:** a valid attestation for this sprint and this fixture digest, OR all of
(1), (2) and (3) hold on a fresh drive.
**FAIL:** the recursion guard does not fire, OR the seeded forgery survives, OR H1
misses the seeded slicing-bypass, OR `--attest` reports the mechanical fixture broke.

**Minimum mechanism (Rule 26(c)).** *Why once per sprint, and why that is not a
weakening.* The three fixtures are static, checked-in files. Nothing about them
changes between gate 1 and gate 5 of one sprint, so H2 was re-proving an identical
fact 4–6 times per planning phase — and this check's own text used to *demand* it
("a fresh fixture seed"). The attestation is pinned to a digest of the fixture set:
change any byte in any of the three and the digest moves, every attestation carrying
the old digest is void, and H2 re-drives in full. The check keeps every tooth. What
was removed is the repetition, not the coverage.

*Removal condition / what this does NOT fix.* Items (1) and (3) are LLM-adjudicated
and their seeds can only establish the condition, not score the answer — only item
(2) is mechanical. If a future release can drive H1 headlessly, (1) and (3) should
join (2) inside `--attest` and H2 becomes fully mechanical.

### Sub-step snapshot update (referenced by step files)

**Moved to `_gate-procedures.md`.** This procedure is
invoked by name from step files, not run in the gate sequence. When a step
says "run sub-step snapshot update", READ AND FOLLOW `_gate-procedures.md`
"Sub-step snapshot update". The full Check 14 above still runs at every gate.

### Auto-handoff evaluation (referenced by step files)

**Moved to `_gate-procedures.md`.** This helper is invoked
by name from step files at defined seams, not run in the Check 1–H2 sequence.
When a step says "run auto-handoff evaluation at Seam <X>", READ AND FOLLOW
`_gate-procedures.md` "Auto-handoff evaluation".

### Core-layer immutability (§7.1 authoring guard — retro/close gate).
<!-- CHECK_LOADED: core-layer-immutability -->

**Scope.** Fires at the retro / sprint-close gate (where rule authoring lands).
The `ai-dlc-core-guard.sh` PreToolUse hook is the PRIMARY enforcement (it denies an
in-place core Edit/Write/MultiEdit at the keystroke); this check is the BACKSTOP for
whatever reached disk anyway — a shell write, a `git push --no-verify`, or a consumer
without the hook wired.
**Active only on a layered consumer** — the project has a `.claude/.ai-dlc-version`
stamp AND the skill's `overrides/` + `extensions/` layer directories exist. The
distribution source repo (no stamp) and a pre-Phase-2 consumer (no layer dirs)
are exempt: the check reports PASS (dormant) there. This is the §10
activation-ordering rule — the guard can only fire once a clean core/layer split
exists.

**Check.** Compute the sprint diff against the branch base:
`git diff --name-only <sprint-base>..HEAD`. Intersect with the core manifest
(read `core-manifest.md` in the skill dir for the authoritative path list:
`.claude/skills/ai-dlc/SKILL.md`, `steps/*.md`, `escalations.md`,
`rule-authoring.md`, `.claude/team-roles/*.md`). For each core file
in that intersection lacking a matching `overrides/` entry (frontmatter
`shadows:` names that file):

- If `.claude/skills/ai-dlc-update/reconcile/setup-sites.md` is present, read
  it (the one documented, one-directional exception to this file never
  otherwise depending on `ai-dlc-update`'s internals — it owns that file,
  this check only reads it) and compute the sprint's changed lines for this
  file: `git diff <sprint-base>..HEAD -- <file>`. **PASS** if every changed
  line falls entirely within a declared site's region (a `single-line` site's
  matched line, or a `heading-block` site's full span) — these are
  `ai-dlc-setup`-filled consumer config (model strings, ownership paths,
  deploy/smoke commands), not rulebook divergence, and need no override.
  **FAIL** if any changed line falls outside every declared site.
- If `setup-sites.md` is absent (an older `ai-dlc-update`, or a consumer that
  hasn't adopted it), fall back to the original file-level check: any edit at
  all to this file with no override → **FAIL**. Never treat the manifest's
  absence as a blanket pass.

**PASS overall:** the core-manifest intersection is empty, every touched file
has a declared override, or every touched file's changed lines resolve per the
above. **FAIL:** any core file has changed lines outside both override
coverage and (when applicable) declared setup-substitution sites.

**Caveat — line-granular, not sub-line.** A sprint diff that touches only the
fixed prose surrounding a masked site's captured value (leaving the value
itself untouched) still PASSES, since the whole line coincides with a
declared site. This is an accepted simplification, not an oversight: the
residual risk — a sprint quietly reording a command's fixed text — is caught
by `ai-dlc-update`'s own step-7v verification gate on the next run
(untangle) or step-7 mask/reinject anchor-drift check (ordinary pull), not at
sprint-close.

**Remediation (not "fix later"):** move the change to the correct layer — a
net-new rule to `extensions/`, a change to an existing core rule to an
`overrides/` entry shadowing it (`rule-authoring.md` routing). Then revert the
in-place core edit so core stays byte-reconcilable with upstream. (Editing a
declared setup-substitution site, e.g. re-running `/ai-dlc-setup` to change a
model string, needs no remediation — it already passes.)

**Minimum mechanism (Rule 26(c)).** Failure caught: in-place core authoring that
makes the next `/ai-dlc-update` clobber or false-conflict — the catch-22 regrown.
False-positive cost: one override declaration for a deliberate core-rule change.
Removal condition: core ships as an immutable package the skill loads, never a
writable tree.

### 26. Gate-check adjudication verdict (escalated llm checks).
<!-- CHECK_LOADED: 26 -->

**Scope.** Every gate (universal). The ONE check through which the lead adopts the
`gate-adjudicator`'s per-check verdicts for the `adjudication: llm` checks it escalated at gate
entry (the escalation preamble at the top of this file; `_gate-procedures.md`
"Gate-adjudication dispatch").

**Check.** Join the verdict at
`${AI_DLC_STATE_DIR:-_bmad-output}/gate-adjudication/<gate_nonce>.verdict.json`, then:

    scripts/verdict.sh validate-gate-adjudication <gate_type> <verdict_path>

Exit 0 required. The validator DERIVES the escalated set from `enforcement-map.yaml`
(`--expected <gate_type>` — the same derivation the adjudicator used) and fails closed: a
missing / malformed / stale verdict (exit 2), an uncovered / unexpected / duplicated escalated
id, an empty evidence, an envelope or `gate_nonce` mismatch, or any per-check `FAIL` (exit 1)
blocks. The lead adopts an `llm` verdict ONLY through this check — evaluating one inline is a
Rule 20 solo violation.

**PASS:** exit 0 — every escalated check covered, well-formed, all PASS. **FAIL:** any nonzero
exit. Fixture: `tests/fixtures/gate-adjudication/`.

**Minimum mechanism (Rule 26(c)).** Failure caught: the lead on a cheaper model silently
mis-judging or skipping a judgment check — a check that cannot fire reads exactly like one that
passed, and an absent verdict reads exactly like a clean one. False-positive cost: one
adjudicator dispatch and one script call per gate. Removal condition: retire if the lead
returns to Opus for all gates, or the escalated checks become script-adjudicated.

## Gate Failure
<!-- CHECK_LOADED: failure -->

If any check fails:
1. Attempt to remediate (run missing validation, fix inconsistency,
   restore drifted requirement, populate template, sync status).
2. Re-run the FAILED check specifically (not the entire checklist).
3. If the check now passes, continue with remaining checks.
4. If still failing after remediation, escalate as HARD_BLOCK per Rule 12.
5. Do NOT skip a failing check. Do NOT proceed with a known failure.
   "We'll fix it later" is not an acceptable remediation for gate checks.
