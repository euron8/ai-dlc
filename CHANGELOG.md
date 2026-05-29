# Changelog

All notable changes to AI/DLC are recorded here.

This project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
and [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## Bump rules

- **MAJOR** — breaking change to skill contract, hook protocol, gate-validation
  schema, install layout, or any consumer-visible interface that requires
  manual migration. Pre-1.0, breaking changes may land in MINOR.
- **MINOR** — additive: new steps, new patterns, new validation checks, new
  hook capabilities, new templates. Existing consumers keep working without
  migration.
- **PATCH** — wording, doc fixes, internal cleanup, non-behavioral edits.

## [Unreleased]

## [0.5.0] — 2026-05-29

Balanced model strategy becomes the new default. Opus is reserved for
the two highest-leverage roles (Lead orchestration, Architect design);
PM and Code Reviewer move to sonnet at `high` effort; Dev and QA stay
sonnet at `medium`. Effort — not model tier — now separates the
planning-grade roles from the implementation-grade roles on the sonnet
side. Also fixes a long-standing contradiction where the spawn-map
bound PM to sonnet while the role file, QUICKSTART, and setup tables
bound it to opus.

Existing consumers keep working without migration: already-filled
role files and QUICKSTART tables are untouched by an upgrade. The
change affects new installs (Step 0 setup defaults) and the
gate-enforced spawn map only.

### Changed

- **Balanced default model strategy.** `ai-dlc-setup` Step 0 now
  provisions Lead + Architect on the opus-tier string and PM, Code
  Reviewer, Dev, QA on the sonnet-tier string. The setup variable
  mapping is reframed around two tiers (opus-tier / sonnet-tier)
  instead of planning/implementation, since PM and Code Reviewer are
  planning-grade roles now running on sonnet at high effort.
- **Rule 19 spawn map (SKILL.md + implementation.md).** Now
  `dev, qa, pm, code-reviewer -> sonnet`; `architect, tea -> opus`.
  Previously `code-reviewer` mapped to opus while `pm` was already
  sonnet in the spawn map but opus everywhere else — both are now
  internally consistent.
- **Role files.** `pm.md` and `code-reviewer.md` model-string
  examples updated to sonnet. `code-reviewer.md` rationale reworded:
  the capability edge over dev now comes from `high` effort, not a
  more capable model tier.
- **QUICKSTART template.** Model Strings and Model Assignments tables
  updated to the balanced default; PM and Code Reviewer annotated as
  sonnet at high effort.

### Fixed

- **PM model contradiction.** Resolved toward sonnet across the spawn
  map, role file, setup table, and QUICKSTART. Eliminates a potential
  gate-validation Check 15 ambiguity where a spawned PM teammate's
  `/model` directive disagreed with the required spawn parameter.

## [0.4.2] — 2026-05-13

Consumer absorption from graph project (Sprint 224–231 innovations).
Validation intensity system, fidelity hardening, step-entry assertion
removal, and 15+ generic mechanism absorptions. All additive; no
consumer migration required.

### Added

- **Validation intensity system (Rule 8).** Four-tier intensity
  (full/standard/carry-over-single/lightweight) replaces fixed "full
  validation cycle" mandate. Declared at route time, recorded in
  snapshot. Reduces overhead for small carry-over sprints without
  weakening critical gates. (Source: graph S175+)
- **Rule 22 — Pause-point resume must re-read step file.** Generalizes
  Rule 21 to mid-step resume. Prevents "proceed = skip to completion"
  failure mode after human commentary at pause points.
- **Solo mode ban.** Party mode MUST spawn real subagents. Inline
  role-playing (solo mode) produces convergent opinions from a single
  LLM and is now explicitly forbidden.
- **Fidelity check in continue hook.** Anti-pattern warning against
  pattern-matching on prior sprints; forces re-read of current step
  file sections.
- **Resume re-read in pause hook.** Resume instruction changed from
  "proceed" to "RE-READ step file per Rule 22."
- **Canonical retro branch naming.** `ai-dlc/retro/sprint-<N>` format
  required by validation script regex.
- **HARD_BLOCK tracking in retro.** `hard_block_count` and
  `hard_block_class[]` fields in retro document template.
- **Finding-class per pass tracking.** Retro party-mode findings now
  reference `retro-finding-class-tracking.md` template.
- **Topology verification mandate.** Retro findings asserting infra
  topology must cite IaC source file and line.
- **Falsification ladder (bug-investigation).** Each architectural
  layer must be ruled in or out with evidence.
- **Worktree-explicit dev dispatch (implementation).** Pre-created
  physical worktrees replace unreliable `isolation: worktree` Agent
  parameter.
- **Dev-brief bug-class checklist (implementation).** Dev must grep
  for same-shape call-sites from code-reviewer findings.
- **Pre-dispatch auth check (implementation).** `gh auth status` must
  succeed before dev dispatch.
- **Backlog health check (carry-over-evaluation).** Flag items >10
  sprints old; triage when >15 open.
- **Process-exercise scoping (carry-over-evaluation).** Items without
  fail-condition triggers reclassified as monitoring notes.
- **Carry-over item ID format.** `CO-S<sprint>-<descriptor>` with
  mandatory `**Status:** OPEN`.
- **Out-of-scope declaration rule (stories-test-strategy).** Stories
  must name uncovered targets when Day-0 survey exceeds lane scope.
- **AC precision for smoke checks.** "Check N MUST produce PASS"
  replaces "zero SKIPs on Check N."
- **Story-authoring pre-flight checklist.** Framework-import
  inspection and role-file/step-file existence verification.
- **Intensity gate for carry-over-single (discovery, stories).** Skip
  brainstorming and epics sub-skills for ≤2-story carry-overs.
- **SUPERSEDED ADR LR disposition (gate-validation Check 3).**
  Silent LR drop without SUPERSEDED/AMENDED marker fails gate.
- **Check 12 post-write verification.** Re-read gate log after write
  to catch silent failures.
- **HARD_BLOCK gate-fail tracking (gate-validation Check 13).**
  `hard_block_fail: true` with escalation ID in gate log.
- **Direct-to-main commit audit (gate-validation Check 15).** Retro
  gate scans for commits bypassing sprint branch workflow.
- **PVC template tables.** PVC-Deferred Items and Operator Decisions
  Required sections now use structured tables instead of HTML comments.
- **CLAUDE.md.template scope note.** Clarifies Context-Mode Usage
  section is routing guidance, not a Rule-18 mandate.

### Changed

- **Rule 8 title.** "Run the full validation cycle" → "Run the
  validation cycle per declared intensity."
- **Provenance block `mode` field.** `<solo|subagent>` → `subagent`
  (follows from solo mode ban).
- **Sprint Context snapshot.** Added `validation_intensity` field.
- **Carry-over satisfaction matching.** Partial satisfaction now
  records `PARTIAL - sprint <N>` with explicit remainder.

### Removed

- **Step Entry Assertions.** Removed from all 18 step files (added in
  v0.4.1). Hook-level enforcement via continue/pause hooks is
  sufficient; per-step assertions added token overhead without
  additional enforcement value.

## [0.4.1] — 2026-05-04

Consumer absorption bundle from graph and ai-group-review projects.
Strengthens step-skip prevention, hardens smoke gate, and adds
reusable templates. All additive; no consumer migration required.

### Added

- **Step 0 Entry Assertions.** All 16 pipeline step files (plus route)
  now output `STEP ENTERED: <name> at {timestamp}` verbatim as their
  first action. Makes step-skip visible in transcript audit.
  (Source: ai-group-review)
- **Hard Smoke Gate.** deploy-validate.md §3 upgraded from "Evidence
  Required" to "Hard Gate — Non-Skippable". Missing
  `smoke_run_evidence` = unconditional gate FAIL. Infra outage →
  HARD_BLOCK (no PVC without evidence). (Source: graph)
- **Retro Step 6a Pre-commit Checklist.** 4-item artifact-existence
  check before retro commit: gate-log, audit-anchors, next-sprint
  prompt, provenance block. (Source: ai-group-review)
- **Retro Step 5c Pre-Commit Validation Gate.** Full section
  consolidating rule-file audit commit, provenance block verification,
  and mandatory-rules validation into a single enforcement point
  before Step 6. (Source: graph)
- **Pipeline templates.** `templates/pipeline/pvc-presentation-template.md`
  and `templates/pipeline/retro-finding-class-tracking.md` — standardized
  formats for PVC presentation and retro finding classification.
  (Source: graph)

### Changed

- **Rule 4 rewritten.** Renamed to "No step may be skipped regardless
  of perceived simplicity". Added anti-rationalization clause: "'This
  is simple' is never a valid reason to bypass a step." Violation now
  explicitly fails the next gate unconditionally.
  (Source: ai-group-review)
- **Stop hook softened.** `ai-dlc-continue.sh` REASON message now
  distinguishes false positives (mid-phase text before next action)
  from real stalls. Warns against skipping steps to avoid hook firing.
  Cites Rule 4 alongside Rule 3. (Source: graph)
- **Retro Step 4 audit-commit contradiction resolved.** Removed stale
  "Commit the audit as a separate commit" instruction that conflicted
  with Step 5c delegation.

## [0.4.0] — 2026-05-04

Pipeline integrity and observability improvements. All additive; no
consumer-visible interface breakage.

### Added

- **Rule 21 — STEP_LOADED_TOKEN verification.** New SKILL.md Rule 21
  mandates that `READ AND FOLLOW` directives produce a Read tool call
  as the first action (no substitution from memory). Each step file
  now contains a `<!-- STEP_LOADED_TOKEN: <name> -->` comment; gate
  log entries MUST cite the token. Prevents step-skip via recall in
  hot sessions.
- **STEP_LOADED_TOKEN comments.** Added to all 18 step files.
- **Initialization pause-flag clear.** SKILL.md INITIALIZATION section
  now clears `_bmad-output/pipeline-paused.flag` before loading the
  router, preventing a race where the UserPromptSubmit hook's flag
  creation on the `/ai-dlc` invocation itself stalls the pipeline.
- **Dual-counter sprint-ship verification.** `retro.md` new section
  defines `consecutive-deploy-clean` and `consecutive-no-regression`
  counters with 5/5 target. Replaces ad-hoc smoke-quality tracking
  with a structured dual-counter pattern.
- **Non-vacuous assertion sub-clause.** `gate-validation.md` Check 5
  now FAILS at Phase 4+ gates when `sprint-status.yaml` contains zero
  story entries — empty-gate pass prevention.
- **SUPERSEDED ADR LR disposition.** `gate-validation.md` Check 3 new
  sub-clause requires explicit SUPERSEDED/AMENDED markers on LRs when
  their parent ADR is superseded mid-sprint. Silent LR drop FAILS.

### Changed

- **Continue hook softened.** `ai-dlc-continue.sh` REASON wording now
  distinguishes "may be legitimate" from hard stall, reducing
  step-skipping pressure in mid-phase result presentation.
- **Retro Step 4 audit commit separation.** Audit file changes are no
  longer committed inline; Step 5c handles the audit commit separately
  from the main retro commit.
- **Resume prompt simplified.** Removed `----` delimiters and preamble
  text from the resume-prompt template; body is now directly pasteable
  without wrapper parsing.

## [0.3.0] — 2026-04-27

Absorbs seven generalized mechanisms from the `graph` consumer
(sprint S169–S170 retro PIs). All additive; no consumer-visible
interface breakage.

### Added

- **Audit-anchor SHA chain.** `core/skills/ai-dlc/steps/retro.md`
  new Step 5b (producer) + `carry-over-evaluation.md` new Step 1a
  (reader) + `gate-validation.md` new Check 18 (per-class test-debt
  audit gated on prior-sprint retro-PR merge SHA). Silent skip
  forbidden — missing anchor FAILS the gate CLOSED. New
  `templates/audit-anchors.md.template` ships the file schema and
  bootstrap entry.
- **Self-reflexive Gate 2 self-discrimination map.** New
  `gate-validation.md` Check 19 + full "Self-Discrimination Map"
  section in `core/team-roles/code-reviewer.md` defining the three
  failure patterns (reviewer-asserts-without-rerun,
  ancestor-check-fabrication, rubber-stamp-without-REPL) that the
  reviewer MUST cite by-name when approving discrimination-evidence
  ACs. Applies to enforce-flip PRs, CI-detector PRs, and ACs
  requiring FAIL→PASS run-ID evidence.
- **Duplicate parent-key drift check.** `gate-validation.md` Check 5
  (story status consistency) now also FAILS when multiple parent
  keys in `sprint-status.yaml` share a name — a structural drift
  mode from parallel-worktree commits that the per-story comparison
  would miss.
- **Sprint-overall PR incremental pre-staging.** New section in
  `sprint-review.md` + verification step in `deploy-validate.md`
  Step 1. Sprint-overall PR MUST be assembled incrementally via
  `_bmad-output/implementation-artifacts/sprint-<N>-*.md` files as
  anchors close; final assembly is merge + diff check only, not
  composition. Applies universally, not gated on story count.
- **Protected-path story tag.** `stories-test-strategy.md` new
  subsection defines three story-frontmatter fields
  (`protected_paths`, `lead_only`, `single_dev_serialized`) and
  ships a default catalog (SKILL.md, step files, team-roles,
  CLAUDE.md, coding-conventions). `implementation.md` enforces
  `lead_only: true` at dev-dispatch time — lead executes the story
  itself, no Agent delegation. Consumers extend the catalog locally.
- **Layered AC verification accounting.** `stories-test-strategy.md`
  new subsection defines the five-layer enum
  (unit/integration/e2e/live_ops/manual_operator) and the
  `layered_ac_count` frontmatter field. Sum MUST equal total AC
  count. Feeds `gate-validation.md` Check 11 evidence.
- **Bug-class audit mandate.** New section in
  `core/team-roles/code-reviewer.md`. Stories declaring a
  class-of-bug fix (semantic error, double-counting, off-by-one,
  type confusion, scope mismatch) MUST include a grep-derived
  enumeration of every call-site with the same code shape. Absence
  is a **Critical** finding; non-deferrable.

[0.3.0]: https://github.com/euron8/ai-dlc/releases/tag/v0.3.0

## [0.2.0] — 2026-04-26

### Changed

- Rule 2(a) human-requested handoff and the auto-handoff helper
  (`gate-validation.md` "Auto-handoff evaluation") are now 5-step
  procedures. New Step 1 stops all in-flight teammates (TaskStop on
  every `in_progress` task plus halt of any Agent-spawned teammate
  not bound to a task) BEFORE committing in-flight work, finalizing
  the snapshot, or emitting the resume prompt. Closes a race where
  teammates kept running after the lead output the resume prompt
  and committed work the successor session could not see.
- Resume prompt template in `core/skills/ai-dlc/SKILL.md` Handoff
  Protocol is now wrapped in `----` delimiter lines (one before,
  one after) so the user knows exactly which lines to copy/paste
  into the new session. Auto-handoff procedure references the same
  delimiter requirement.

[0.2.0]: https://github.com/euron8/ai-dlc/releases/tag/v0.2.0

## [0.1.0] — 2026-04-25

Initial versioned release. Establishes the public surface for change tracking.

### Added

- `VERSION` file at repo root as semver source of truth.
- `CHANGELOG.md` for release history.
- `scripts/install.sh` writes `.claude/.ai-dlc-version` stamp into the
  consumer project at install time, capturing the installed version,
  upstream commit sha, and install timestamp. Consumers can read this
  file to know what they have.
- `scripts/check-version.sh` — consumer-runnable script that compares
  the local stamp against the upstream `VERSION` file and reports drift.
- README "Versioning" section documenting bump rules and the consumer
  upgrade flow.

### Baseline

The 0.1.0 line freezes the current shape of:

- `core/skills/ai-dlc/` (SKILL.md + 18 step files)
- `core/skills/ai-dlc-setup/SKILL.md`
- `core/team-roles/{architect,code-reviewer,dev,pm,qa}.md`
- `core/hooks/ai-dlc-{protect,pause,continue}.sh`
- `core/scripts/validate-{ci-gates,provenance-block,mandatory-rules,retro-evidence}.sh`
- `core/ci-templates/validate-{ci-gates,retro-compliance}.yml`
- `core/fixtures/check-{15-bypass,17-bypass,h1-recursion,1c-bypass}/`
- `patterns/` (high-cost-action-gating, bundle-verification,
  api-field-verification, financial-plausibility, ...)
- `templates/{CLAUDE.md,QUICKSTART.md,settings.json,coding-conventions.md}.template`

[Unreleased]: https://github.com/euron8/ai-dlc/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/euron8/ai-dlc/releases/tag/v0.4.0
[0.1.0]: https://github.com/euron8/ai-dlc/releases/tag/v0.1.0
