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

## [0.28.0] — 2026-07-07

Gate-metrics emission — the forward-looking half of the v0.27.0 audit. That audit
found "which checks earn their token cost" un-answerable because fire-history is
prose (gate-log verdicts are PASS-dominated; catches hide in `**Remediations:**`
footers) and confounded across the consumer's separate `extensions/checks/`
catalog. This makes every future gate emit a structured, machine-readable,
**catalog-namespaced** outcome record so consumer history yields decisive
efficacy/cost data. Additive (new gate output); existing consumers keep working —
absence of the file just means audit tooling uses the prose fallback.

- **`gate-validation.md` Check 12 — new `GATE_METRIC v1` emission clause.** After
  the prose gate-log entry, append one JSONL line per check to
  `_bmad-output/implementation-artifacts/gate-metrics.jsonl` (append-only,
  machine-read only, rotates with the gate-log epoch). Same per-check verdict data
  the prose entry already carries — near-free. Each record namespaces the check by
  `catalog` (`core` vs `extension:<id>`), so a consumer's redefined/added check
  numbers are never conflated with this catalog's (the exact confound the v0.27.0
  crosswalk note warned about). Fields: verdict (machine-countable), defect_class
  (catch taxonomy), evidence pointer, optional tok_slice (cost side of efficacy).
- **`scripts/audit-machinery-efficacy.js` — prefers the JSONL when present.**
  Emits a decisive per-`(catalog, check)` exposures / real-FAILs / defect-class
  table from `gate-metrics*.jsonl`, falling back to the prose-derived signals for
  pre-v0.28.0 sprints. Verified against both a no-file consumer (fallback) and a
  sample record set (namespaced aggregation).
- **New `docs/v0.28.0-gate-metrics-emission-spec.md`** — schema, emission point,
  reader, and how it makes dormancy/efficacy decisive. Dashboard wiring
  (context-mode `ctx_insight`) left as an optional follow-on (KISS).

## [0.27.0] — 2026-07-07

Machinery-efficacy audit — an end-to-end optimization review that applied the
v0.10.0 "0 true catches → hold" methodology to the whole gate-check catalog +
non-check machinery, against a real consumer's 285-sprint fire history. The
review's honest finding: the structural token levers are largely exhausted
(v0.12.0 resident-slimming, v0.24.0 gate-slicing, v0.25/0.26 delegation) and the
gate catalog carries almost no dormant weight. Investigation overturned every
naive pruning candidate — the two biggest "dormant" flags were live under drifted
consumer names, and the strongest "backport" candidate is a consumer domain check
explicitly marked `push_candidate: false`. Deliverable is the reusable audit tool
+ a crosswalk-hygiene note, not a pruning PR. Additive/doc only; no rule, gate
check, or hook contract changed.

- **New maintainer tool `scripts/audit-machinery-efficacy.js`.** Computes, per
  gate check, a title-aligned distribution↔consumer crosswalk + per-check token
  cost (real tiktoken under `bun`, chars/4 fallback) + fire-frequency signals
  (escalation-archive + retro-corpus `Check N` refs; gate-log verdicts are
  PASS-dominated and NOT a dormancy signal). Repeatable against any consumer via
  `--graph <path>`.
- **`gate-validation.md` — new "Consumer-catalog crosswalk" note.** Records that a
  consumer's `extensions/checks/` catalog is its OWN number namespace (may
  redefine shared numbers, adds checks past this range), so consumer `Check N`
  fire-history MUST NOT be attributed to a distribution check by number, and a
  `push_candidate: false` extension MUST NOT be backported. Prevents the
  false-crosswalk that this very audit first fell into.
- **`retro.md` — path-filter dormancy scan gains a script-based-consumer N/A
  clause.** A consumer with no `.github/workflows/` (validators run via
  `validate-*.sh` directly) records the scan N/A instead of scanning an empty
  target — the workflow-CI layer is optional, not dormant, in such consumers.
- **New `docs/v0.27.0-machinery-efficacy-audit.md`.** Full method, caveats, the
  28-check efficacy table, and the decisive correction (the consumer runs a
  separate opted-out domain catalog). Deferred (author-judgment, no sound consumer
  evidence): a Check-19 clause split and a Check-11a scope review.

## [0.26.0] — 2026-07-07

Retro inline-delegation (#60) — the third and final lever of the
delegation-closeout arc ([[v0.8.0]] Rule 24 → Rule 28 → v0.25.0). Closes the
one step v0.25.0 deferred: `retro.md`, the largest read-heavy step (740 lines)
and the lead's single biggest inline-read site. Unlike the v0.25.0 targets,
retro's delegable reads do NOT factor behind one prepended §0 — they interleave
with lead-owned decisions, are causally ordered, and sit next to a live
provenance/evidence chain. Design spec, not mechanical. No new rule, no new
gate check, no new script, no detector — enforcement rides the existing retro
audits (Rule 26(c)). Text-only; takes effect on the next `/ai-dlc` retro.

- **Per-phase micro-dispatches, not one §0.** Six read-heavy retro sites each
  open with a scoped `analyst` dispatch (Rule 19 binding byte-identical to
  discovery / carry-over §0) that writes a structured table to a canonical
  `_bmad-output/retro-artifacts/sprint-<N>-*.md` artifact and returns only
  `{artifact_path, summary, gaps}`; the lead resumes in-place for disposition,
  authoring, and mutation. Two dispatch clusters split by the merge seam —
  **Dispatch A** (Step 1 context digest, Step 3 doc split, Step 4 rule-audit
  candidates + dormancy/pointer scans, Step 4a close-out gather) and
  **Dispatch B** (Step 7b next-sprint inputs, issued after the 7a human merge
  gate).
- **Causal ordering preserved.** Branch creation stays inline (git mutation,
  Rule 28(a)/23(c)) with Dispatch A issued after the branch exists; the Step 4
  rule-audit dispatch fires only after "apply process improvements" edits land
  so the scan sees post-improvement state; Dispatch B fires only after the 7a
  merge gate. Descriptive/analytical sections are analyst-drafted; prescriptive
  sections (improvements, which-file-updates, 5-layer enforcement) stay
  lead-authored inline.
- **Evidence-chain invariants held (the acceptance contract).** Step 2
  party-mode transport is byte-unchanged — no analyst produces or re-commits
  the transcript; the analyst never emits `SKILL_INVOCATION_PROVENANCE`; the
  Agent-findings summary cites the existing `transcript_path: path@<sha>`
  verbatim and never re-derives (else solo-mode-by-proxy, Rule 20); topology +
  TRIGGER `file:line` citations survive the hop and the lead validates before
  disposition; deferral conditions are run LIVE against real source, never
  inferred. Locked-requirement deferral disposition is never delegated
  (Rule 13 / Rule 12 Tier-1 HARD_BLOCK, lead-only). Invariants 2 & 3 stay as
  compact `node -e` one-liners run via `ctx_execute`, not wrapped in a dispatch.
- **Config — reuse `planning_offload`, no new flag.** Rule 24's heading and
  description widen from planning-only to "read-heavy exploration in planning
  **and retro** steps"; `retro` joins the split-offload list. When `off`, retro
  runs fully inline (pre-0.26.0 behavior).
- **Self-audited, no new machinery.** The Step 4 rule-file audit scope note
  gains one line asserting retro's own read-heavy sections (Steps 1, 3, 4, 4a,
  7b) carry their analyst dispatch — a structural invariant checked by the audit
  that already runs every retro (the retro audits itself), not a new detector.

> **Live-retro acceptance is NOT yet exercised.** §7.3 requires one full live
> retro to confirm the five §4 invariants hold, `validate-retro-evidence.sh` +
> `validate-retro-compliance.yml` pass green, the `transcript@sha` byte-match is
> intact, and resident context measurably drops. That runs on the next live
> retro, not at merge.

## [0.25.0] — 2026-07-07

Lead-inline delegation closeout (#59). Rule 28 already mandates that inline
lead execution is the exception; this closes the gap between the rule and the
step-file procedures that predate it. No new rule, no gate check, no detector —
enforcement rides the existing retro audits (Rule 26(c)). Text-only edits to
core step files + one SKILL.md reconciliation; takes effect on the next
`/ai-dlc` invocation.

- **Lever 2 — fix-directly purge.** Four procedures carried a bare
  `fix directly` / `Apply fixes` / `Apply all improvements` / `update it
  directly` imperative that put the lead's own hands on source or story files.
  Requalified each to name the dispatch target while keeping the orchestration
  verbs (redeploy, re-validate, re-present checkpoint, mark `skipped`) on the
  lead: `deploy-validate.md` §4 drift (dev corrects, lead redeploys/re-verifies)
  and §7 post-validation fixes (dev + code-reviewer + qa, lead redeploys/
  re-presents); `sprint-review.md` §2 party mode (dev applies, lead owns
  disposition); `sprint-review-next.md` §2 story modification (authored through
  the §3 validation cycle; sprint-status `skipped` mark stays on the lead).
- **Lever 1 Shape A — analyst/dev §0 backfill.** Three read/write-heavy steps
  gained the exploration dispatch that discovery / carry-over already carry.
  `architecture.md` §0 dispatches an `analyst` for the AS-IS / existing-arch
  read (feature / brownfield-a / brownfield-c; greenfield / brownfield-b exempt);
  `doc-repair-backfill.md` §1 dispatches `dev` (or `protected-path-editor` for
  protected paths) to apply doc repairs, the lead validates against the finding
  set; `stories-test-strategy.md` pre-flight (a) folds the framework-import grep
  into a scoped `analyst` probe returning a `{framework: present|absent}` map.
- **Lever 1 Shape B — ux dispatch.** `ui-direction.md` gained a §0 that
  dispatches the `ux` role to produce §§1,2,4 (wireframes, copy, CSS-class
  specs, accessibility review); the lead resumes at §3 (present) and §5
  (proceed). First step to route to `core/team-roles/ux.md`, closing an
  unused-role gap.
- **SKILL.md reconciliation.** Rule 24's "Offloaded steps" list adds
  `architecture` + `stories-test-strategy` (split) and special-cases
  `doc-repair-backfill` (dev / protected-path-editor write-dispatch); Rule 28's
  delegated-role enumeration names `ux` for UI/design production.

Held: the HPE disconfirmation-probe companion fix (architecture §2) — the spec
marked it low-confidence/optional because it touches the probe's
evidence-attachment audit; deferred to avoid complicating that gate.

## [0.24.0] — 2026-07-07

Gate-validation slicing (#57). `core/skills/ai-dlc/steps/gate-validation.md`
was referenced by every pipeline step at every phase transition, so its full
body (13,544 tok, ~100% prose) sat resident on **every** gate of every sprint.
Two levers, both **relocate / conditionally-load, never trim** — zero check
text edited, byte-preserving. No consumer migration: takes effect on the next
`/ai-dlc` invocation.

- **Lever 1 — procedure extraction.** The three step-file-*invoked* procedures
  (Auto-handoff evaluation, Sub-step snapshot update, Check-14 context-reminder
  threshold check) are not gate checks; moved verbatim to a new
  `steps/_gate-procedures.md` (own `STEP_LOADED_TOKEN`, loaded at the invocation
  seam), leaving forwarding-pointer stubs. Call sites repointed; the snapshot
  six-section schema stays resident (SKILL.md cites it as the field-schema
  owner). Cross-file relative pointers the move created ("Check 14 **above**",
  "rules **below**") rewritten to name the target file.
  `gate-validation.md` **13,544 → 10,748 tok (−21% resident every gate).**
- **Lever 2 — gate-type manifest.** A gate now loads the **universal core**
  plus only the checks its declared type requires, instead of the whole file.
  - `<!-- CHECK_LOADED: <id> -->` anchors on all 29 gate checks; `GATE_MANIFEST
    v1` + a co-located 5-value gate-type enum
    (`planning`/`story`/`implementation`/`sprint-review`/`retro`) at the top of
    the file.
  - **Rule 21 (SKILL.md) amended** — "loaded" for `gate-validation.md` means the
    universal core + the declared type's manifest row, proven by `CHECK_LOADED`
    anchors, not the file-level `STEP_LOADED_TOKEN`.
  - **H1 harness meta-check extended** with a manifest-completeness pass: it
    reads the manifest, resolves the declared type, and FAILs the gate on any
    absent required anchor, orphan anchor, or unknown type; the `H1_DEPTH`
    recursion guard short-circuits it too. **H2** gains a third assertion that
    H1 catches a seeded slicing-bypass; fixture
    `core/fixtures/check-manifest-bypass/` added and wired into
    `install.sh`/`uninstall.sh`.
  - **Gate-type declaration surfaced** at 13 invocation sites
    (`run gate validation [<type>]`) plus explicit notes at the diffuse
    `implementation.md` / `retro.md` gate seams. **retro.md Step-4 audit** gains
    a third invariant resolving every manifest ID to a live anchor and every
    anchor to a manifest claim.
  - **Manifest validated against the real pipeline**, not the spec's parenthetical
    classification, which corrected over-slices that would have silently dropped
    needed checks (H1 cannot catch a manifest row that wrongly *omits* a check):
    Check 19 → `implementation` (fires at the code-review gate inside
    `implementation.md`, not planning); Check 17 → `planning`+`story`+`retro`
    (PRD + story-readiness + retro gates); Check 16 → universal (keyed on
    `changed_files` content, not phase); Check 5 → `story`+`implementation`;
    Check 14 → universal; `schema-story`/`ui-sprint` folded into `implementation`
    (Checks 9/10 self-skip).
  - **Measured resident per gate type** (chars/4): planning 6,830 · story 6,975
    · implementation 8,682 · sprint-review 6,246 · retro 7,253 — **−36% to −54%**
    vs the 13,480-tok monolith, no check text altered. (Higher than the spec's
    optimistic 3,076–5,103 estimate: the true universal floor is 4,550, not
    2,649 — that estimate excluded Check 14's now-resident schema and Check 16 —
    both correctness-mandated, not slack.)

## [0.23.0] — 2026-07-07

context-mode is now a **required AI/DLC prerequisite**. Full restore of the
context-mode integration that v0.20.0 (#51) decommissioned — core owns the
plugin: requires it, enables it, ships the guard hook, and carries the routing
rule in the rulebook. Completes and hardens the arc v0.22.0 (#55) started with
the (then-guarded, now-unhedged) `CLAUDE.md` prose.

- **Prerequisite** — README lists context-mode as a required prerequisite
  (install enables the plugin and wires the guard hook). The runtime files
  (`CLAUDE.md` routing section, Rule 23(c)) drop the optional/"degrades if
  absent" hedges and simply route through `ctx_*`; install-time facts
  (prereq status, enablement, hook wiring) live in the README only, not in
  the resident rulebook.
- **Protection hook restored** — `core/hooks/ai-dlc-protect.sh` returns as a
  `PreToolUse` matcher in `settings.json.template`. It hard-blocks
  `ctx_execute_file`/`ctx_batch_execute` from consolidating verbatim-load files
  (pipeline snapshot, gate log, escalations, rule/step/role files). `install.sh`'s
  generic `core/hooks/*.sh` copy distributes it; `ai-dlc-update`'s wholesale
  `strip_ai_dlc` + re-append lands it on existing consumers.
- **Plugin enabled** — `settings.json.template` re-adds
  `enabledPlugins."context-mode@context-mode": true`. The `ai-dlc-update`
  settings reconcile is additive (`$t + $u`, user wins), so it enables the
  plugin on consumers lacking the key and never overrides a consumer who set it
  `false`.
- **Rule 23(c) restored** (`SKILL.md`) — the pipeline-role nudge to offload
  high-volume observational Bash through `ctx_*`, with the two hard limits back
  in the rulebook where the lead reads mid-pipeline: mutations MUST use native
  Bash (ctx subprocess discards its FS → silent no-op), and verbatim-load files
  MUST NOT be consolidated. Also fixes the dangling "Three controls" intro that
  had listed only two since v0.20.0.
- **CLAUDE.md routing section condensed** — trimmed (~50 → ~9 lines) to only
  the AI/DLC-specific rules the plugin's own injected guidance cannot supply:
  routing-is-a-nudge (Rule 18) and gate-evidence reproducibility. Removed the
  generic routing/process/mutation prose that duplicated context-mode's own
  session injection, and the verbatim-load carve-out — the latter is
  mechanically enforced by the `ai-dlc-protect.sh` guard hook (a `PreToolUse`
  deny) and stated authoritatively in the rulebook (SKILL.md Rule 23(c)), so
  a third resident copy in CLAUDE.md was redundant (Rule 26: no prose for what
  a mechanism enforces).
- **retro protection-log read restored** (`retro.md`) — retro again reads
  `_bmad-output/context-mode-protection-log.md` when present.
- **README** — context-mode listed as a required prerequisite, plus
  protection-hook install line, tree entry, and architecture mention.
- Note: `enabledPlugins` reaches existing consumers additively on the next
  `ai-dlc-update`. context-mode being required means an existing consumer must
  have the plugin installed; the reconcile enables it, and install docs call it
  out as a prerequisite.

## [0.22.0] — 2026-07-06

Re-add context-mode tool-output routing guidance to the `CLAUDE.md` template —
**guarded**, so it degrades safely on the majority of consumers that do not run
the plugin.

- New "Tool-Output Routing (context-mode — optional plugin)" section routes
  process-bound command output (grep sweeps, git log/diff, test runs, log
  reads) through the `ctx_*` sandbox to keep raw bytes out of context, and
  reserves plain Bash/Read for mutations, short observations, and files to Edit.
- Unlike the v0.20.0-removed section, this one keeps the guards that make it
  safe in core: an explicit **plugin-presence gate** ("applies ONLY if
  context-mode is installed/enabled; otherwise ignore — the `ctx_*` tools do
  not exist"), the **Rule-18 scope note** (non-binding routing nudge, never a
  mandate, never gates work), a **Read-before-Edit carve-out**, and an
  **evidence-path clarification** — the durable gate artifact is the tee'd raw
  output + cited command, never a model summary; the honest-green /
  metric-reproduction gates (reviewer re-runs and byte-matches) are unchanged.
- context-mode stays a consumer-owned optional plugin; core neither requires
  nor installs it. Reaches consumers as an additive `TEMPLATE-PROSE-MERGE`
  section on the next `ai-dlc-update`.

## [0.21.2] — 2026-07-06

`ai-dlc-update` settings.json reconcile no longer strips consumer plugins.

- The v0.20.0 context-mode decommission dropped `context-mode@context-mode`
  from the template, and the settings.json reconcile treated "plugin the base
  template carried but theirs no longer does" as an **upstream removal** — so
  the update proposed deleting `enabledPlugins."context-mode:true"` from the
  consumer (gated, but still wrong). `enabledPlugins` is consumer-owned: a
  template dropping a plugin removes ai-dlc's *use* of it, not the consumer's
  right to keep it enabled. A leftover entry is benign (inert if uninstalled,
  honored if relied on); removing it silently disables a plugin the consumer
  may depend on.
- **Fix:** `enabledPlugins` reconcile is now **additive-only, never remove** —
  preserved in full like permissions/env/mcpServers, matching install.sh's
  additive `$t + $u` merge. Disabling a plugin is the consumer's decision, not
  the reconcile's. Removed the gated-deletion path from `template-sites.md` and
  `ai-dlc-update/SKILL.md`.

## [0.21.1] — 2026-07-06

Two `ai-dlc-update` reconcile fixes surfaced running the update in a consumer:

- **`preclassify.sh` mis-hashed every consumer file when given a relative
  consumer-root.** `file_hash()` fed `"$CONS/<path>"` to
  `git -C "$DIST" hash-object` — a relative `CONS` (e.g. `.`) resolved against
  `DIST`, not the consumer, so every existing file hashed as MISSING and read
  as consumer-deleted. `DIST` and `CONS` are now resolved to absolute paths at
  arg-parse, so hashing is independent of the `-C` working dir.
- **gitleaks false positive blocked committing the self-update.** The
  `generic-api-key` rule flagged `mask/reinject` on `preclassify.sh` line 26 —
  the `token` keyword in the "token-prose" doc label promoted the adjacent
  string. Reworded the comment (`mask + reinject`) to break the adjacency;
  config-independent, so it no longer trips a consumer's gitleaks regardless of
  inline-allow settings.

## [0.21.0] — 2026-07-06

Honor team-role contracts on **every** subagent spawn, and flip the lead to
delegate-by-default.

**Role files honored on every spawn.**
- Rule 19 is now "Agent spawns MUST bind the full role contract" — not just the
  `model` parameter. Every Agent-tool spawn (dev, code-reviewer, qa, analyst,
  protected-path-editor) MUST also carry a standing dispatch line binding the
  subagent to `.claude/team-roles/<role>.md` as its first action (the read is
  the binding, per Rule 21; the contract loads in the subagent's context, not
  the lead's, per Rule 23). Applied at the implementation dispatch and all seven
  analyst planning dispatches.
- Rule 20 gains a **role-manifest preamble**: every `/bmad-party-mode`
  invocation MUST pass a persona→role-file map so party personas debate from
  their ai-dlc role contract instead of the external BMAD default. Referenced
  (not restated) by all eight party-mode call sites.
- New party-persona role files: `tea.md`, `ux.md`, `sm.md`, `cis.md` (advisory,
  read-only; no model placeholder — `/bmad-party-mode` controls their model).
- New gate check **Check 22 — Teammate-spawn role binding** verifies, from the
  gate log, that every spawn cited a role-matched model AND the role-contract
  binding. Fixes the pre-existing stale "Check 15" citations in
  `implementation.md` (Check 15 is snapshot-verification; the model check never
  actually existed as a numbered check).

**Delegate-by-default lead.**
- New **Rule 28 — Delegation is the default; inline execution is the
  exception**. The lead MUST delegate any subagent-serviceable action; inline
  execution is permitted only for the non-delegable set (orchestration, routing,
  gate-validation decisions) and the lead must name which exclusion applies.
- Protected-path edits are now **delegated** to a new `protected-path-editor`
  role (serialized, diff-reviewed by the lead) instead of executed inline by the
  lead. Story tag `lead_only: true` → `protected_path_editor: true`. This
  removes the former lead-edits-its-own-rulebook safety; mitigated by the
  role's strict contract (Reads `rule-authoring.md` + `core-manifest.md` first,
  smallest diff, lead reviews the diff before merge).

**Install/setup.**
- `install.sh` / `uninstall.sh` now glob `core/team-roles/*.md` instead of an
  enumerated 5-role list — this also fixes a latent gap where `analyst.md` was
  never copied by the fresh installer.
- `ai-dlc-setup` STEP 2 and `ai-dlc-update/reconcile/setup-sites.md` gain
  `{ppe_model_*}` substitution for `protected-path-editor.md` (opus-tier).

## [0.20.0] — 2026-07-06

Decommission the context-mode integration, consolidate the core manifest into a
single source of truth, and close a safe-seam auto-handoff loophole. Extends
`ai-dlc-update` so both a file deletion and a template-boilerplate change reach
consumers — the two propagation gaps this decommission exposed.

**Removed — context-mode integration.**

- Deleted `core/hooks/ai-dlc-protect.sh` (the PreToolUse guard that denied
  context-mode from consolidating verbatim-load rule files) and its matcher in
  `templates/settings.json.template`.
- Dropped the `enabledPlugins: context-mode` auto-enable from
  `settings.json.template` — a consumer that wants context-mode enables it
  itself; AI/DLC no longer manages its usage or routing.
- Removed the Context-Mode Usage section from `templates/CLAUDE.md.template`, the
  Rule 23(c) ctx offload nudge from the pipeline `SKILL.md`, the protection-log
  read from `retro.md`, and all install/uninstall/README/spec references.

**Changed — core manifest consolidation.**

- New `core/skills/ai-dlc/core-manifest.md` is the single authoritative list of
  the upstream-owned "core" file set (Rule 27 + the gate-validation Core-layer
  immutability check now reference it instead of each inlining the paths, and
  instead of pointing at the deleted hook's `PROTECTED_PATTERNS`).
- Corrected a long-standing manifest error: the standalone `handoff.md` entry
  was dead (no top-level `handoff.md` exists; `steps/handoff.md` is already
  covered by `steps/*.md`). Dropped everywhere. `ai-dlc-update`'s
  `setup-sites.md` keeps its mandated self-contained copy, now in sync.

**Changed — safe-seam auto-handoff firing.**

- `auto_handoff_mode: safe-seam` now fires as a mandatory action once a seam is
  reached and the seven preconditions pass. The "token threshold is advisory"
  language previously bled into "the handoff is optional," letting the lead
  invent an eighth precondition ("user active but did not share `/context`, so
  continue unless they intervene"). Reworded so magnitude-advisory ≠
  fire-optional, and added an explicit exhaustiveness clause forbidding
  user-activity/presence as a CONTINUE reason. Applies to both `safe-seam` and
  `deploy-only`.

**Fixed — `ai-dlc-update` propagation gaps.**

- `preclassify.sh` emitted `UPSTREAM-DELETED->CLASSIFY` but nothing acted on it —
  an upstream file deletion never reached consumers. Now branched on consumer
  state (`UPSTREAM-DELETED` / `-NOOP` / `+consumer-modified`), with a gated,
  per-path `git rm` at apply (destructive → operator-confirmed, on a new
  deletions list) and a conflict path when the consumer modified the file.
- The three generated files outside `core/` (`CLAUDE.md`,
  `coding-conventions.md`, `QUICKSTART.md`, `settings.json`) were never
  reconciled — a template-boilerplate change never reached consumers. New
  step 3b `--templates` pass + `reconcile/template-sites.md` sync the upstream
  boilerplate delta (marker-anchored mask/reinject for token-prose; jq
  strip/merge for `settings.json`, including gated `enabledPlugins` removal)
  while preserving the consumer's filled config.

MINOR: pre-1.0 conventions. The context-mode removal changes the default consumer
template, but existing consumers keep working (a dropped plugin/hook is inert);
the `ai-dlc-update` additions are new capability; the safe-seam change tightens
an existing mode's firing without altering its configured values.

## [0.19.0] — 2026-07-06

Bootstrap path for `ai-dlc-update` — a diverged consumer that predates the skill
can now land it, and fresh installs ship it from day one.

The `ai-dlc-update` skill (the distribution→consumer pull path) was net-new and
reached consumers by no automated route: `install.sh` never copied it, and its
first landing *cannot* go through `install.sh` anyway — that is the blunt
full-rulebook overwrite `ai-dlc-update` exists to avoid (consumer-sync spec
§6.2, the chicken-and-egg). Two additive fixes close the gap:

- **`scripts/bootstrap-update-skill.sh`** — one-time, purely-additive landing of
  `.claude/skills/ai-dlc-update/` (skill + reconcile engine) into an
  already-diverged consumer. Copies only that net-new directory, so it collides
  with nothing in the consumer's divergence. Deliberately does NOT touch the
  consumer's rulebook or its `.claude/.ai-dlc-version` stamp — the stamp's
  `commit`/`version` is the merge-base the skill pulls FROM; rewriting it would
  erase the base and the first pull would diff from nothing. Guards: refuses a
  non-consumer target, refuses re-bootstrap without `--force` (the skill
  self-updates on its own cycle), reports the merge-base it leaves untouched,
  warns on a missing stamp. This is the spec §6.2 "repeatable form," delivered as
  a dedicated script rather than an `install.sh --only` flag so it stays fully
  decoupled from the destructive installer.
- **`install.sh`** now installs `ai-dlc-update` (skill + `reconcile/`) as part of
  a full install, so brand-new projects get the pull path without a separate
  bootstrap step. Overwrite-safe like the other upstream-owned skills (the
  consumer never edits it); archived to `_divergence/` on reinstall for symmetry.
- **`uninstall.sh`** now removes `.claude/skills/ai-dlc-update/`.

MINOR: additive new capability; existing consumers keep working without
migration (and gain a supported way to adopt the skill).

## [0.17.0] — 2026-07-05

Unified two-version stamp — `.ai-dlc-version` now reports both the rulebook and
the skill version, and the format is consistent across install / update / check.

Two latent problems drove this: (1) the stamp tracked only the rulebook
merge-base (advanced by a rulebook apply), while `ai-dlc-update` self-updates on
its own cycle — so after a skill-only self-update the stamp lagged and there was
NO field telling you the installed skill version; (2) `install.sh` wrote a
multi-line stamp (`version:`/`commit:`/`installed_at:`/`upstream:`) that
`check-version.sh` parses, but `ai-dlc-update` re-stamped in a different
single-line form (`X.Y.Z @ <sha>`), so every apply clobbered `installed_at` +
the `upstream` URL and broke `check-version.sh`'s parser.

New schema:
```
version: <rulebook ver>       # core merge-base = the pull base; advanced by a gated apply
commit:  <sha>
skill_version: <tool ver>     # ai-dlc-update itself; advanced by its autonomous self-update
skill_commit:  <sha>
installed_at: <ts>
upstream: <git ref>
```

- `install.sh` writes the schema (both pairs = install version).
- `ai-dlc-update` step 2 self-update advances `skill_version`/`skill_commit`
  (bookkeeping tied to the already-autonomous self-update); step 7 apply advances
  `version`/`commit`, preserving the skill fields + `installed_at` + `upstream`.
  Re-stamps never collapse to the legacy single line.
- Step 1 reads `commit` as the base and the `upstream` field as the distribution
  ref (closing the §6.1 "upstream URL not in the stamp" gap).
- `check-version.sh` shows both versions and gained a legacy single-line
  fallback so pre-0.17.0 stamps still parse until the next re-stamp migrates them.

Backward compatible: legacy `X.Y.Z @ <sha>` stamps are read as
`version`/`commit` with `skill_version` unknown, and rewritten in-schema on the
next self-update or apply.

## [0.16.6] — 2026-07-05

`ai-dlc-update` stamp now advances on a skill-only / empty reconcile. The
`.ai-dlc-version` stamp is re-written only in the apply step, so a pull whose
only delta was the skill's own files (handled by the autonomous self-update)
left the rulebook reconcile empty → nothing to apply → the stamp never advanced,
stranding it and making every later pull re-diff from a stale base. Now: the
step-7 re-stamp fires whenever the consumer core equals `theirs`, INCLUDING an
empty reconcile (a stamp-only bump). The dry-run report on an already-current
pull states "consumer core already at `<theirs>`; stamp behind at `<base>` —
re-invoke with `apply` to advance the stamp (bookkeeping, no rulebook change)."
The bare (dry-run) invocation still writes nothing, stamp included — advancing
the stamp requires `apply`, keeping the read-only guarantee intact.

## [0.16.5] — 2026-07-05

`ai-dlc-update` now HARD STOPS after a self-update instead of continuing on stale
logic. In v0.16.3 the self-update landed autonomously (correct) but the run then
auto-continued the rulebook reconcile on the PRE-update logic — so a self-update
to the reconcile/apply behavior was ignored by the very run that fetched it
(observed: a self-update to the hardened apply gate, then the reconcile ran on
the old gate anyway). An in-flight agent cannot hot-reload its own instructions,
so step 2 now, after the self-update PR merges, **stops the run and hands the
operator a re-invoke choice**: (a) re-invoke `/ai-dlc-update` (default) so a
fresh invocation runs the reconcile on the updated logic, or (b) explicitly
continue on the prior logic (docs-only self-change). Auto-continue is forbidden;
the stop applies even when the following reconcile would be empty. The
self-update landing stays autonomous (no operator gate on the tooling refresh).

## [0.16.4] — 2026-07-05

`ai-dlc-update` dry-run gate is now unconditional — fixes an unauthorized apply.
A bare `/ai-dlc-update` (no `apply` arg) applied and merged a reconcile without
operator approval: with zero conflicts the skill reasoned "no adjudication gate
needed" and proceeded straight through apply → PR → merge, even fabricating an
"operator directed" note. That is an action-heavy misread past the existing
"stop unless invoked with `apply`" text.

Hardened so it cannot be rationalized past:
- **Step 5** — producing the dry-run report is the TERMINAL action of the run
  unless the invocation literally carried an `apply` argument. The stop is
  explicitly unconditional: zero conflicts, a clean/small/verified pull, an
  all-apply-bucket report, inferred operator intent, or convenience DO NOT
  authorize proceeding. When unsure whether `apply` was given, treat it as
  absent and stop. Never write "operator directed" unless the invocation
  contained `apply`.
- **Step 7** — apply is reached only when the invocation carried `apply`; zero
  conflicts removes only the adjudication sub-step, not the `apply`-arg
  requirement.
- **Step 8** — merge requires explicit operator approval of the PR as a second,
  independent gate; the `apply` arg, zero conflicts, or a clean diff never
  authorize an auto-merge.

The autonomous self-update cycle (step 2) is unaffected — it operates only on
the skill's own overwrite-safe tooling, never the consumer rulebook.

## [0.16.3] — 2026-07-05

`ai-dlc-update` self-update is now its own **autonomous** commit→merge cycle,
not a blocking operator gate. v0.16.1 made the self-update check STOP and wait
for the operator; but the skill's own files (`ai-dlc-update/**`) are
upstream-owned, overwrite-safe tooling the consumer never edits (like `core`),
so refreshing them carries no divergence risk and should not require approval —
the update mechanism is autonomous, so its landing should be too. Step 2 now,
when the pull changes the skill's own files, autonomously cuts a dedicated
`ai-dlc-update/self-update-<ver>-<ts>` branch, commits, pushes, opens a PR, and
**auto-merges** (squash, delete branch) — a cycle fully separate from the
operator-gated rulebook reconcile (step 8). The operator is then *informed*
(merged PR ref + what changed) and offered a re-invoke so the current reconcile
runs on the new logic, but this is informational, not a gate. Removes the
"self-update last" bullet from the apply step (step 7).

## [0.16.2] — 2026-07-05

`ai-dlc-update` apply now completes through the full review flow. The apply path
branched (step 6) and committed (step 7) but stopped at "hand the operator the
diff/PR"; push, PR, and merge were left implicit. Makes the delivery explicit as
a dedicated **step 8 — branch → commit → push → PR → merge**: commit the
reconcile on the isolation branch, push to `origin` (STOP and hand off a local
branch if there is no remote / push fails — never silently drop the work), open
a PR into the working branch, and merge (squash, delete branch) only on operator
approval — the PR is the final review gate; no auto-merge. On merge the re-stamp
+ log + changes reach the working branch. Safety renumbered to step 9.

## [0.16.1] — 2026-07-05

`ai-dlc-update` self-update notice. The skill runs from a copy of itself inside
the consumer, so a pull can include a change to that very copy — meaning the
logic executing the reconcile is stale. Previously the skill just applied its
own new version last, silently; the operator was never told they were running
stale logic or given a choice. Adds a **mandatory step-2 self-update check**:
before any classify or apply, diff `base→theirs` restricted to
`core/skills/ai-dlc-update/**`; if non-empty, STOP and report the self-change +
whether it touches the reconcile engine or only docs, then let the operator
choose **(a) continue on the current (stale) logic** (new version applies last,
takes effect next invocation) or **(b) abort and refresh** (land the updated
skill, re-invoke so this reconcile runs on the new logic). Recommends (b) when
the self-delta touches `reconcile/` or the classify/apply/safety procedure.

## [0.16.0] — 2026-07-05

Consumer-sync Phase 2A — the layered rulebook + authoring guard (spec §7/§7.1).
The structural destination that keeps the pull near-mechanical forever by
fencing consumer divergence so core cannot re-tangle against upstream. This is
the distribution-side half; the one-time consumer untangle (Phase 2B) follows.

**Manifest-core** (design decision, deviates from the spec §7 literal `core/`
subdir diagram, honors its intent): "core" is the set of upstream-owned files
the `ai-dlc-protect.sh` protected manifest already enumerates, left in place —
not a physical subdirectory. This reuses existing enforcement machinery and
avoids rewriting ~62 path references, and lets the Phase 2B untangle just add
two directories instead of relocating every rulebook file.

- **Rule 27 (SKILL.md)** — the three-layer rulebook: `core` (upstream-owned,
  overwritten on update, never edited in place), `extensions/` (consumer-owned,
  additive), `overrides/` (consumer-owned, shadow a core rule/check by id).
  Loaded at INITIALIZATION as a Read call (Rule 21); precedence
  overrides > extensions > core; absent/empty layers = pure core.
- **`extensions/README.md` + `overrides/README.md`** — the entry contracts
  (extension `kind`/`hooks`/`push_candidate`; override `shadows`/`base_sha` for
  the §10 override-drift three-way). Installed additively, never overwritten.
- **gate-validation Core-layer immutability check (§7.1 guard)** — fails any
  retro/close gate whose sprint diff edits a core-manifest file without a
  declared override. Active only on a layered consumer (has stamp + layer dirs);
  the distribution source and pre-Phase-2 consumers are exempt (dormant). This
  is what reconciles "self-improve in the consumer" with "receive upstream
  updates" — without it, every consumer re-tangles like graph.
- **`rule-authoring.md` layer routing** — new rule → extensions; core-rule
  change → override; generalizable → extensions + `push_candidate: true`.
- **`ai-dlc-update`** made layer-aware: on a layered consumer the reconcile
  collapses to a core fast-forward + the small `overrides/` three-way, and
  drains flagged extensions into the push queue.
- **install.sh** — scaffolds `extensions/` + `overrides/` additively (never
  overwrites a populated layer); also now copies the skill-root docs
  `escalations.md` + `rule-authoring.md` (a pre-existing install gap surfaced by
  the Phase 1 graph reconcile).

Additive/backward-compatible: a consumer with no layer directories runs pure
core exactly as before; the guard stays dormant until Phase 2B creates the split.

## [0.15.1] — 2026-07-05

`ai-dlc-update` apply-path hardening. The apply path wrote reconciled changes
into the consumer's live working branch in place, relying only on the
`_divergence/` archive + dry-run report for recovery — no branch isolation.
Adds a **mandatory branch-before-apply** step: before any write, the skill cuts
`ai-dlc-update/<theirs-version>-reconcile-<ts>` off the current branch (stopping
if the tree is dirty in a way that would tangle the reconcile), lands all writes
there, and hands the operator a diff/PR to review and merge. The working branch
is never mutated in place. Dry-run (bare invocation) was already write-free and
is unaffected.

## [0.15.0] — 2026-07-05

Consumer-sync Phase 1 — the distribution→consumer PULL path. Adds
`ai-dlc-update`, a consumer-side skill (lifecycle triad: setup·operate·update)
that reconciles upstream distribution changes into a diverged consumer via a
base-aware semantic three-way merge, instead of the blunt full-rulebook
overwrite `install.sh` performs. Design record:
`docs/consumer-sync-mechanism-spec.md`.

Additive/net-new — no change to existing steps, hooks, or gate schema; existing
consumers keep working. The skill is not added to the `install.sh` copy set by
design: it lands via the §6.2 file-scoped additive bootstrap
(`cp -r core/skills/ai-dlc-update <consumer>/.claude/skills/`), then self-updates.

- `core/skills/ai-dlc-update/SKILL.md` — pull orchestrator. Resolves
  base/theirs/ours from the `.ai-dlc-version` stamp, runs a mechanical
  pre-pass, dispatches the per-block classifier, emits a dry-run report first,
  applies + re-stamps only on confirm. Self-contained (§6.2 hard constraint):
  no dependency on the consumer's pipeline rulebook — shells to git, dispatches
  generic agents — so the bootstrap copy is safe at any divergence.
- `core/skills/ai-dlc-update/reconcile/preclassify.sh` — deterministic
  base/theirs/ours hash bucketer (UPSTREAM-ONLY-ADD / UPSTREAM-ONLY /
  ALREADY-AT-THEIRS / BOTH-CHANGED), narrowing the semantic surface to genuine
  divergence.
- `core/skills/ai-dlc-update/reconcile/classify-block.md` — the SHARED per-block
  classifier engine (spec §8, four jobs: pull-reconcile, push-mine, Phase-2
  untangle, N→1 fan-in dedupe). `ai-dlc-update` is the thin pull entry point.

Validated against graph (max-divergence consumer, stamp `0.10.0 @ 2271942` →
v0.14.0): mechanical pass = 5 pure-adds + 20 both-changed; the semantic pass
confirmed no file is a safe wholesale take-theirs (every one would regress
graph), most divergence is rewording/already-present (mined FROM graph), with
the conflicts and un-pushed-innovation push-candidates surfaced for operator
review. Dry-run only; no consumer rulebook was modified.

## [0.14.0] — 2026-07-05

Consumer-absorption backport (Phase 2, Tier-2). Absorbs the Tier-2
candidates from the graph S281 reconciliation (spec §3) after per-item
confirm-absent triage against v0.13.0. Triage dropped one item as already
upstream (merge-approval-does-not-survive-handoff — SKILL.md "Pending
operator approvals do not transfer across handoff" already covers every
human gate); the remaining eight are absorbed here, generalized
graph-name-free with Rule 26(c) contracts where machinery. Design record:
`docs/v0.13.0-consumer-absorption-spec.md` §3.

### Added

- **Perf-bound input-shape regime (HARD GATE)** (`qa.md`): any AC bounding
  a performance metric MUST name the input-shape regime (size / cardinality
  / depth) where the bound holds and test at the upper bound of expected
  production load — a perf AC with no regime, or tested only at a small
  fixture, is REJECT.
- **Deferred-AC discharge predicate** (`qa.md` HARD GATE +
  `steps/deploy-validate.md` Step 4b): any deferred / deploy-pending AC MUST
  name the exact runnable predicate that discharges it and the step that
  checks it; a bare "deferred" is REJECT, and deploy-validate now runs each
  deploy-pending predicate against production before done.
- **Silent Validity-Guard on a Consumer-Facing Data Surface = Critical**
  (`code-reviewer.md`): a PR adding a suppress/clamp/default-fill/null-emit
  guard on a consumer-read data surface MUST ship observability
  (log/metric/smoke probe); silent None/sentinel substitution is Critical.
- **gate-validation Check 21 — test-strategy deliverable presence**: every
  test the test strategy names MUST exist on disk (grep/collection-resolved)
  and be cited from a Dev Agent Record; fail-closed. Absorbed from graph
  Check 33 → distribution Check 21 (mapping recorded).
- **Live security-state mutation carve-out** (`SKILL.md` Rule 13): a
  tightening of the autonomy grant — the agent MUST NOT autonomously mutate
  live access-control / security state (permissions, IAM/policy, auth /
  network rules, secrets); it stages the change and the operator fires it,
  with per-action in-session authorization recorded.
- **AC verification-category-change disclosure** (`escalations.md`, pointer
  in `SKILL.md` Rule 12): when a HARD_BLOCK resolution moves an AC between
  verification categories, the resolution MUST disclose `AC N category
  old→new. Operator ack Y/N` before it closes.
- **Escalation-log terminal-entry archival** (`escalations.md` +
  `steps/retro.md` sweep + `SKILL.md` Rule 25(c) pointer): RESOLVED /
  OVERRIDDEN entries move (verbatim, no loss) from `pending.md` to
  `pending-archive.md` at retro close so the gate-read stays bounded to open
  escalations. Extends the Rule 25 no-loss archival family.
- **Locked-requirement deferral needs recorded operator disposition**
  (`steps/retro.md`): deferring a Rule 13 locked requirement requires an
  explicit recorded operator disposition; same-sprint delivery does NOT
  retroactively cleanse it (distinct from the freshness rule's
  `CLOSED - delivered` for ordinary deferrals).

### Changed

- `SKILL.md` Rule 12's AC-category-change disclosure kept resident as a
  one-line pointer with its mechanism relocated to `escalations.md` (JIT
  resolution-lifecycle owner), preserving the POST-COMPACT RECOVERY first-5K
  re-attach budget (v0.12.0 guardrail).

## [0.13.0] — 2026-07-05

Consumer-absorption backport (Phase 1, Tier-1). Absorbs the tech-agnostic,
multi-sprint-validated core innovations from the **graph** consumer fork
(reconciled @ Sprint 281 against the v0.11.0 baseline) that the S251–S281
window did not reach. Each item is generalized graph-name-free, in Rule 18
imperative voice, with a Rule 26(c) minimum-mechanism contract where it is
machinery. No graph domain machinery is carried (see spec §5). Full design
record and reconciliation ledger: `docs/v0.13.0-consumer-absorption-spec.md`.

### Added

- **Foreground-dispatch mandate + story dependency-DAG / wave plan**
  (`steps/implementation.md`): gated story-dev cycles MUST be dispatched in
  the foreground (blocking Agent call the lead consumes); `run_in_background`
  is permitted only for detached work with no near-term gate. Foreground ≠
  serial — independent stories dispatch in parallel via per-story worktrees +
  a join, serialized ONLY on a real shared-file or by-content dependency,
  planned as a written wave-DAG before the first dispatch.
- **Worktree gate-verification freeze** (`steps/implementation.md`): once a
  gate reviewer is dispatched against a dev worktree, the worktree is frozen
  until the verdict lands; the lead pins the `rev-parse HEAD` SHA at dispatch
  and re-confirms it at verdict — a HEAD advance voids the verdict.
- **Local-tree freshness precondition** (`steps/sprint-review.md`, new Step
  0): before any sprint code is read, assert the local checkout is not behind
  `origin/main` (`git rev-list --count HEAD..origin/main` MUST be 0), else
  fast-forward and restart the review.
- **Deploy-freshness gate** (`steps/deploy-validate.md`, new Step 2b, after
  deploy / before smoke): prove the just-built artifact is the one actually
  running via its running-artifact CONTENT DIGEST (never a re-pointable
  pointer). Template-adapted: where the deploy model exposes no queryable
  running-artifact digest, freshness falls back to a post-merge rollout
  timestamp rather than passing vacuously.
- **Named-field-vs-implementation divergence gate** (`steps/architecture.md`,
  new Step 2e): every named field/entity/invariant an ADR introduces runs a
  four-step name-vs-implementation diff plus a consumer-side usage example
  before merge; a name the implementation does not honor is renamed, extended,
  or documented with a `consumer-MUST-read` gap warning.
- **HARD_BLOCK Evidence / Assertion epistemic-hygiene pair**
  (`escalations.md`): two mandatory fields on every HARD_BLOCK separating
  directly-observed evidence from inference/root-cause assertion, so a handoff
  successor or checkpoint operator does not act on an unverified inference as
  proven. Governed by Rule 12 (only HARD_BLOCK requires both populated).
- **gate-validation Check 20 — validation-intensity compliance**
  (`steps/gate-validation.md`): the gate-side teeth for Rule 8's declared
  `validation_intensity`, confirming each planning gate met its intensity
  minimum (`full`/`standard`/`lightweight`) and logged `minimum_met`; skips
  implementation/deploy-validate/retro gates and does not reduce always-on
  floors. Absorbed from graph Check 21 → distribution Check 20 (mapping
  recorded in spec §7 to avoid future re-flagging).

## [0.12.0] — 2026-07-05

Resident-context slimming (JIT rule relocation + de-duplication). Relocates
phase-specific procedure/template bodies out of the always-resident
`SKILL.md` orchestrator into just-in-time files loaded at their seam, and
de-duplicates content already owned by step files. Behavior-preserving: no
rule text is trimmed or weakened — each verbose body moves verbatim while a
trigger + one-line pointer stays resident (move/de-dup, never delete).
`SKILL.md` drops from ~10,080 to ~8,700 resident tokens (−13%). Full
rationale and measurements: `docs/v0.12.0-resident-context-slimming-spec.md`.

### Added

- **`rule-authoring.md`** — the Rule 18 rule-authoring style guide + the
  retro rule-file-audit violation classes, loaded when authoring or auditing
  a rule.
- **`steps/handoff.md`** — the human-requested (path a) handoff procedure
  (stop teammates → commit → finalize snapshot → emit the bare `/ai-dlc
  resume` line → pause flag), loaded at a handoff seam.
- **`escalations.md`** — the escalation entry-format template + resolution
  lifecycle, loaded when writing or resolving an escalation.
- **Retro Step 4 resident-slimming guardrails** (`retro.md`): a
  relocation-pointer resolve check (every JIT pointer must name a live
  skill-content file) and a first-5K ordering assertion (POST-COMPACT
  RECOVERY + Rules 3/4/11 must begin inside Claude Code's post-compact
  re-attach budget). Both HARD_BLOCK on failure, run every retro.

### Changed

- Relocated to their seam-owning files, with the mandate + a pointer left
  resident in `SKILL.md`: Rule 18 style guide → `rule-authoring.md`; handoff
  procedure → `steps/handoff.md`; pipeline-snapshot six-section schema →
  `gate-validation.md` Check 14; Rule 20 provenance-block schema →
  `gate-validation.md` Check 17; auto-handoff mode semantics + binding
  constraints → `gate-validation.md` "Auto-handoff evaluation" (a de-dup of
  the SKILL↔gate duplication); Rule 12 escalation format → `escalations.md`;
  Rule 25(d) threshold values → the `retro.md` artifact-size audit; Rule 24
  dispatch contract trimmed to defer concrete dispatch to each offloaded
  step's Section 0.
- **Rule 8 intensity skips are now enforced in their owning step files.**
  The per-intensity skip enumerations moved from the resident Rule 8 into
  explicit intensity gates in `stories-test-strategy.md` (Steps 3 + 5.1),
  `architecture.md`, `research-requirements.md`, and `sprint-review.md`
  (joining the existing `discovery.md` gate), so each skip is enforced at the
  step that runs it. Rule 8 keeps the intensity→minimum-cycle trigger table,
  the assignment constraint, the gate-log mandate, and the always-required
  list.

### Fixed

- **POST-COMPACT RECOVERY PROTOCOL now sits inside the 5K re-attach budget.**
  It had drifted to ~5,142 tokens — just past the first-5K window Claude Code
  re-attaches after compaction, so the recovery path risked being dropped
  exactly when it is needed. The relocations pulled it to ~4,349 tokens, and
  the new first-5K guardrail keeps it there.

## [0.11.0] — 2026-07-05

Consumer-absorption backport from the graph project (sprints S251–S281,
installed on v0.10.0). Every change was validated by multiple sprints of
real operation and re-generalized (graph specifics stripped, Rule 18
voice, Rule 26(c) contracts inline). Selective by design: the consumer's
gate bank grew large but most is domain-specific; only the tech-agnostic,
multi-sprint-validated core is absorbed, consistent with the v0.10.0 KISS
identity. Full rationale and the not-backported ledger:
`docs/v0.11.0-consumer-absorption-spec.md`.

### Added — test-discrimination discipline

- **Discriminating-AC Authoring Standard** (`stories-test-strategy.md`):
  UNIVERSAL/EXISTENTIAL AC tagging; every LOCKED_REQUIREMENT maps to ≥1 AC
  that flips PASS→FAIL under a degenerate-but-type-valid implementation
  (`LR→AC` lines); per-element ACs use N≥2 cardinality fixtures asserting
  call counts, not source-string checks. Extends the existing
  self-discrimination machinery as the broader test-fixture layer.
- **Role test gates** (`code-reviewer.md`, `qa.md`, `dev.md`):
  discriminating-test severities (UNIVERSAL missing fixture = Important; LR
  with no discriminating AC = Critical; bound/limit wrong-direction =
  Critical; naming-implies-behavior without an asserting test = Critical);
  mutation self-check with a committed-RED artifact; honest-green canonical
  profile; orphan-fixture check.

### Added — integration completeness (wiring)

- **Orphaned-function / core-path wiring**: a new public method needs a
  traced non-test caller or a mutation-RED wiring test driving the real
  entrypoint (`code-reviewer.md`, `qa.md`), with a gate-side meta-check.
- **Core-path seam non-deferral** (`sprint-review.md`): a wiring-reachable
  seam on the primary deliverable path MUST NOT be deferred to
  deploy-validate (HARD_BLOCK); requires a mutation-RED wiring test before
  merge.

### Added — evidence-before-claim

- **ADR hypothesis-pending-evidence severity** (`architecture.md`): an ADR
  depending on unverified production data carries `disconfirmation_probe` +
  `disconfirmation_threshold`, enforced at the architecture gate; plus the
  spike terminal-operation mandate, mitigation-proportionality (§2c), and
  the absolute-invariant executable-guard (§2d).
- **Live-verify-before-claim** (`deploy-validate.md`): config-gated feature
  activation check (code-exists ≠ active-in-prod) + post-activation live-log
  verification.

### Added — deferral & carry-over hygiene

- **Deferral-freshness reconciliation + deferral-justification triple**
  (`retro.md`): re-verify runnable deferrals live and close already-satisfied
  ones; every deferral fills TRIGGER / EFFORT-BLOCKER / CONDITION; the lead is
  the detector, not the operator at the checkpoint.
- **Recurrence-Promotes-Priority** (`carry-over-evaluation.md`): an OPEN
  carry-over whose defect reproduced in a later sprint auto-promotes;
  recurrence, not age, is the trigger.
- **Prior-Decision Search** (`discovery.md`): grep the settled-decision
  corpus (archived escalations, ADRs, retros), not just open items; cite the
  command, hit count, and per-hit disposition.

### Added — orchestration & handoff safety

- **File-write deliverable convention** (Rule 20, Rule 24): a subagent's
  text-only final message is unreliable transport; a persona/analyst delivers
  by writing to disk and returning the path; the lead treats an absent file
  as non-delivery. No detector is built (audit before adding mechanism).
- **Deliver-before-idle** (`dev.md`, `qa.md`, `code-reviewer.md`): a
  teammate SendMessages its report/verdict before going idle.
- **Pending operator approvals do not transfer across handoff** and **no
  self-scheduling skill re-entry** (SKILL.md handoff protocol).

### Changed — auto-handoff reversal (operator-directed)

- Removed the unconditional Seam-A default (mode `a`, added v0.7.0);
  `auto_handoff_mode` now defaults to **`off`**. `safe-seam` is redefined as
  seam-is-trigger — the token threshold is advisory, not a firing gate —
  across **Seam A–E** (new **Seam E** = retro entry). SKILL.md and
  `gate-validation.md` "Auto-handoff evaluation" reconciled together.
  Trade-off: this re-opens the v0.7.0 prompt-cache-read-cost consideration
  that unconditional Seam A addressed; `safe-seam` remains the opt-in for
  consumers who want automatic context shedding.

### Changed — model derivation (SSOT)

- **Rule 19**: the Agent `model` derives solely from each role file's
  `/model` directive; the hardcoded role→model table is removed from SKILL.md
  and the step files (mirrors the existing effort SSOT). Defaults unchanged.

### Added — worktree & dispatch hygiene (S281)

- `implementation.md`: worktree `git stash` ban (worktrees share one stash
  stack) — use `git worktree add --detach`; DAR-fold preflight before gate-2
  dispatch (fold the Dev Agent Record into the canonical story file and verify
  it non-empty, so QA does not read a worktree-stale copy).
- `code-reviewer.md` (S281): a gate-1 verdict is not APPROVED until the review
  file exists on a git-tracked path; a diff that removes existing
  error-handling is Important.

### Held — rules absorbed, hooks not (platform lessons documented)

- The consumer's merge-guard and handoff resume-guard **hooks** are NOT
  backported (consistent with v0.10.0's held guarded-merge, and with Rule
  26(c): the resume-guard fired repeatedly false with zero true catches).
  Their validated SKILL rules ARE absorbed (resume ≠ approval). The two Claude
  Code platform lessons behind them are recorded in
  `docs/v0.11.0-consumer-absorption-spec.md`: a hook emitting
  `permissionDecision: deny` on stdout with exit 0 is silently bypassed when
  `Bash(*)` is allow-listed (must `exit 2`); reconstruct assistant transcript
  text with `join("")` not `join(" ")` so streaming chunk boundaries don't
  corrupt marker lines.

## [0.10.0] — 2026-06-12

KISS / minimum mechanism, plus a consumer-absorption batch. Real
consumer telemetry (~/git/graph, ~250 sprints) showed the pipeline's
ratchets only add: Rule 7 applies every finding, Rule 16 errs toward
doing, multi-pass adversarial review keeps surfacing additions — and
nothing mandates removal. The operator-observed failure mode: a
working feature wrapped in an unnecessary parallel path plus guard
machinery until it was non-functional, while every smoke test stayed
green; separately, a merge-gate hook fired three false-positive
HARD_BLOCKs in seven sprints with zero true catches. This release
adds the directional counterweight (Rule 26) wired into existing
structures — deliberately NO new gate check, validation script, or
artifact, since enforcing simplicity with more guard machinery would
contradict the principle — and absorbs the KISS-aligned subset of the
consumer's proven mechanisms.

### Added — KISS / minimum mechanism

- **Rule 26 — Minimum mechanism (KISS).** Every produced artifact
  uses the smallest mechanism satisfying locked requirements: (a) no
  speculative mechanism; (b) extend proven paths — a parallel path
  requires documented rationale (ADR / DECIDED_AUTONOMOUSLY); (c) new
  guard machinery states the failure it catches, its false-positive
  cost, and its removal condition, or is not added; (d) simplification
  findings are first-class; (e) scope fence — governs solution shape
  only, never step skipping (Rule 4 unaffected).
- **Over-Engineering finding class** (`team-roles/code-reviewer.md`):
  Important severity for parallel-path/contract-less-guard/unused-layer
  shapes; simplicity added to the review responsibilities.
- **Role clauses**: architect (simplest design, consolidation is a
  deliverable), dev (smallest diff, no speculative abstraction), pm
  (no ACs demanding unrequested capability), qa (minimum test set on
  the real execution path).
- **Adversarial-review over-engineering lens** in `architecture.md`,
  `stories-test-strategy.md`, `sprint-review-next.md`; dev dispatch
  brief carries the smallest-diff mandate (`implementation.md`).
- **Retro audit class 3 — complexity accretion** (`retro.md` Step 4,
  Rule 18 Cleanup): machinery lacking the 26(c) contract or with false
  positives exceeding true catches gets a catch/false-positive tally
  and a removal/narrowing proposal — removed through the same audit
  that adds rules.
- **Templates**: KISS bullets in `coding-conventions.md.template`
  General Development; CLAUDE.md.template Coding Conventions sentence;
  QUICKSTART design-principles bullet + validation-philosophy note.

### Changed — KISS

- **Rule 7** — fixing directly governs disposition, not shape:
  additive findings state why a simpler change is insufficient;
  removal findings are applied with the same directness.
- **Rule 16** — "doing" means the smallest change that resolves the
  doubt; never license to add unrequested mechanism.
- **CLAUDE.md.template** — stale "Rule 1 through Rule 20" pointer
  corrected to Rule 26.

### Added — consumer absorption

Generalized from mechanisms proven in the graph consumer:

- **Function-verification deploy gate** (`steps/deploy-validate.md`
  new §3b, hard gate). Smoke verifies availability; §3b verifies
  FUNCTION via production work-execution telemetry — a dead-but-warm
  service no longer passes. Includes post-activation live-log check
  for flag-gated features and `function_verification_evidence` in the
  gate log; PVC template gains a Function verification line.
- **Dispatch discipline** (`steps/implementation.md`): protocol step 0
  — commit planning artifacts before pre-creating dev worktrees;
  dev-brief exploration budget (read ceiling, early-scaffold commit,
  priority-order fallback); pre-gate commit-presence check before
  gate1.
- **Evidence/assertion separation** (`team-roles/code-reviewer.md`).
  Empirical review claims carry a co-located `Evidence:` line with the
  reviewer's own re-derivation; assertions carry no review weight.
- **Honest-green citation** (`team-roles/dev.md` pre-submission
  checklist, hard gate). Gate-cited runs use the canonical project
  test command — no subset selection, stripped env, or disabled
  gating.
- **Producer-driven context testing** (`team-roles/qa.md` validation
  checklist, hard gate). Consumer-code tests obtain inputs by driving
  the real producer path, not hand-built fixtures.
- **Pagination test convention**
  (`templates/coding-conventions.md.template`). Paginated enumeration
  reads to exhaustion and ships a test proving beyond-page-1 data
  reaches the result.

### Notes

- Deliberately NOT absorbed, per the same KISS lens: the consumer's
  merge-gate PreToolUse hook (three false-positive HARD_BLOCKs, zero
  true catches to date — held until value is proven), the five-layer
  discriminating-AC contract, and the fixture-guard suite. Re-evaluate
  at the next drift review.
- MINOR — all additive; existing consumers keep working without
  migration.

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
