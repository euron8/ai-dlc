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

## [0.9.0] — 2026-05-30

Artifact-size discipline — the dominant read+turn lever. Real consumer
telemetry (~/git/graph, ~224 sprints) showed living planning artifacts
grown without bound — `prd.md` 393k tokens, `product-brief.md` 329k,
`carry-over-backlog.md` 224k — and the skill *mandated* it ("do not
rewrite existing requirements" → append forever). One step,
`carry-over-evaluation`, instructed reading ~946k tokens "in full" — ~5x
the lead's window, forcing compaction churn. This release bounds the
living artifacts to current-state, moving history out of the read path,
with a no-loss guarantee that preserves the fidelity the old "do not
rewrite" rule protected. Design record:
`docs/v0.9.0-artifact-size-discipline-spec.md`.

### Added

- **Rule 25 — Artifact-size discipline.** Living artifacts stay
  current-state; superseded/historical content **moves** (cut-and-paste,
  verbatim — never deleted) to `*-history.md` / `*-archive.md`. Read the
  relevant section of a sectioned artifact, not the whole file (except
  cross-cutting evaluations, which read whole and rely on bounding).
  Rotate append-only logs at epoch boundaries; verify appends by tail,
  not full re-read. Warn thresholds (prd/brief 60k, backlog 40k,
  gate-log 25k tokens). Rule 13 locked requirements never relocated.
- **`artifact-consolidation.md`** — operator-invoked one-shot migration
  for already-bloated artifacts. An `analyst` (v0.8.0) emits a baseline
  manifest and drafts the consolidated-live/history split; the lead runs
  a no-loss verification (every manifest entry present in live ∪
  history; locked reqs stay live) plus Rule 20 validation, then commits
  the git-reversible swap.

### Changed

- **Supersede-to-history replaces append-forever.** `research-requirements`
  and `discovery` now integrate new scope into current-state sections and
  move superseded versions + per-sprint narrative to the history file,
  verbatim, with no requirement loss.
- **Retro close-out moves CLOSED carry-over items to the archive**
  (live backlog = OPEN / IN-SPRINT / PARTIAL / DEFERRED only), and adds a
  warn-only artifact-size audit that points the operator to consolidation.
- **gate-log post-write verification reads the tail**, not the whole
  file, and rotates per epoch.
- **pm.md** reads scope-relevant PRD/brief sections, not the whole files.
  `carry-over-evaluation` reads the live current-state files whole
  (cross-cutting) — never the history/archive companions.

### Notes

- Decisions: single consolidated PRD + slicing (defer sharding until a
  bounded PRD proves too large); operator-invoked migration (no auto
  rewrite); carry-over reads whole-but-bounded (not sliced); warn-only
  thresholds.
- Existing installs: Phase-1 behavior (slice-reads, tail-verify) applies
  next session; already-bloated artifacts need the one-shot
  `artifact-consolidation` migration to actually shrink. No-loss is
  preserved throughout — history/archive files hold every prior byte;
  total disk is unchanged, the win is keeping them out of the read path.

## [0.8.0] — 2026-05-30

Planning-phase subagent offload — continues the cache-read arc (v0.7.0).
The lead's largest avoidable read cost is read-heavy planning/analysis
work it does inline: every file read accumulates in its context and is
re-read every turn. This release moves the *exploration* portion of
designated steps to an ephemeral read-only `analyst` subagent whose raw
reading never enters the lead's context — the lead receives only a
pointer + summary + gaps and reads the artifact from disk on demand
(Rule 23(a)). Design record: `docs/v0.8.0-planning-subagent-offload-spec.md`.

### Added

- **`analyst` team role** (`core/team-roles/analyst.md`). Read-only
  exploration subagent, model `sonnet`, effort `medium`. Explores in
  its own context, writes a self-contained artifact to disk, returns
  only `{artifact_path, summary, gaps}` — never raw content. No state
  mutation, no re-spawn, no validation sub-skills.
- **Rule 24 — Planning exploration is dispatched to analyst subagents.**
  Centralizes the dispatch contract, the production-vs-validation
  boundary (analyst drafts; lead validates, decides, owns; Rule 20
  sub-skills stay inline), and the `planning_offload` config (default
  `on`; set `off` for pre-0.8.0 fully-inline behavior).
- **Per-step dispatch sections** in seven steps. Full offload —
  `deep-codebase-analysis`, `codebase-inventory`, `doc-reconciliation`.
  Partial offload (reading sections only; authoring / party-mode /
  validation / mutations stay inline) — `bug-investigation`,
  `carry-over-evaluation` (§3 party mode is Rule 20), `discovery`,
  `research-requirements`.

### Changed

- **Rule 19 spawn map** adds `analyst -> sonnet`:
  `dev, qa, pm, code-reviewer, analyst -> sonnet`; `architect, tea ->
  opus` (SKILL.md + implementation.md).
- **Setup + QUICKSTART** provision the analyst role: balanced and
  sonnet-only model tables, variable mapping (`{analyst_model_*}` ->
  sonnet-tier), and QUICKSTART model tables / role tree.

### Notes

- Expected to cut lead read tokens in planning phases proportional to
  each step's read volume (codebase analysis is the largest). Magnitude
  unproven without per-phase telemetry; most cache-read volume is
  caching working as intended (~10x cheaper than uncached), so this
  shaves the avoidable slice, not the inherent cost.
- Existing installs are unaffected until they adopt the new default on a
  fresh install or set `planning_offload: on`. MINOR — additive.

## [0.7.0] — 2026-05-30

Prompt-cache **read**-cost reduction. Real consumer telemetry (3–4
sessions: 86.2M cache-read vs 3.3M cache-write tokens) showed cache
read is the dominant cost bucket — ~57% cost-weighted vs ~27% for
write — driven by a large working context read on every turn of long
sprints. v0.6.0 addressed the write side; this release targets the
reducible read waste without weakening the v0.4.x step-fidelity
mechanisms. (Note: most cache-read volume is prompt caching working as
intended — the alternative is ~10x the tokens uncached — so the goal
is trimming redundant residence, not eliminating reads.)

### Added

- **Rule 23 — Resident-context discipline.** Three integrity-safe
  controls on the working set:
  - **(a) No redundant re-loads.** Re-Read only the current step file;
    never re-Read a completed step file or planning artifact to
    refresh — query the pipeline snapshot (already the authoritative
    source). Each redundant re-read permanently duplicates content
    into context and is re-read every subsequent turn. `gate-log.md`
    and `pipeline-snapshot.md` re-reads are exempt (small; the
    re-read is the verification).
  - **(b) Sliced re-read.** Rule 22 resume MAY `Read` with an `offset`
    to the remaining sections of a large step file. The mandatory Read
    tool call (the run-from-memory interrupt) is preserved; only its
    span narrows.
  - **(c) Observational-Bash offload.** High-volume read-only command
    output SHOULD route through context-mode `ctx_batch_execute` to
    stay out of the resident prefix; state-mutating commands MUST stay
    on native Bash (ctx subprocesses discard FS changes).

### Changed

- **`auto_handoff_mode` default `off` → `a`.** New mode `a` fires
  auto-handoff at `Seam A` (pre-deploy preflight) **unconditionally** —
  no user-shared `/context` required. Seam A is once per sprint, where
  context is maximal and the user is already at the Production
  Validation Checkpoint, so it sheds the whole build's accumulated
  context right before the long monitoring window — the biggest
  single read-cost cap, at zero added handoff fatigue. Existing modes
  `deploy-only` and `safe-seam` are unchanged and still require Mode 1
  red confirmation. All resume-safety preconditions (snapshot current,
  not mid-gate, no teammate blocked, no pause point active) apply in
  every mode.

### Notes

- A between-stories auto-handoff (Seam C) was prototyped but dropped:
  throttling it without `/context` required a story-count proxy whose
  machinery (config knob, mode branch, `sprint-status.yaml` read) was
  more complexity than the marginal read saving justified. Seam A
  unconditional captures the dominant peak simply. Lowering the red
  threshold (~200k on the 1M-model lead) remains an operator lever,
  unchanged by default, as it trades against handoff fatigue.

## [0.6.0] — 2026-05-29

Prompt-cache write-cost reduction. The lead session is long-lived with
a large resident prefix; on API-key / Bedrock / Vertex auth the cache
defaults to a 5-minute TTL, so idle gaps during deploy/monitoring
windows expire the cache and force a full prefix re-write at the 1.25x
write rate — the dominant cache-write cost across a sprint. This
release addresses the two causes that are skill-side and integrity-safe
(extended TTL and cold subagent spawns) and deliberately does NOT touch
the v0.4.x step-load / re-read integrity mechanisms, whose cache payoff
is modest and whose weakening carries fidelity risk.

### Added

- **1-hour prompt cache TTL in the generated `settings.json`.**
  `templates/settings.json.template` now sets
  `ENABLE_PROMPT_CACHING_1H=1` under `env`. Collapses idle-gap cache
  expiry (the main write driver) into a single cache entry. No-op on
  Claude subscription auth (already 1h); corrective on Bedrock. Step 6
  of `ai-dlc-setup` documents the rationale, the `FORCE_PROMPT_CACHING_5M`
  override, and the tool-set-churn caveat (adding/removing an MCP
  server mid-sprint invalidates the conversation cache).
- **Dispatch-prompt cache discipline (`implementation.md`).** Teammate
  dispatch prompts MUST lead with a byte-identical shared block and
  place per-story content in the tail, so content-addressed cache
  entries are reused across parallel spawns instead of cold-written
  per dispatch.

### Notes

- Re-read gating (Rule 22 / handoff) and resident-footprint trimming
  were evaluated and deferred: they collide with step-fidelity and
  rule-availability hardening for modest gains, and read tokens are
  ~10x cheaper than writes. Revisit only if cache telemetry shows
  reads dominating after the TTL change.

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
