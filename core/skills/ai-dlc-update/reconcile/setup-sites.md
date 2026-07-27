# Setup-substitution site manifest — SHARED, read-only data

Enumerates every core-manifest location `ai-dlc-setup` fills with
consumer-specific config at install/setup time. Both `ai-dlc-update` (the
mask/reinject transform in its core-overwrite step, ordinary pull and
`untangle` alike) and `gate-validation.md`'s Core-layer immutability check
read this file as the single source of truth for "this looks like core
divergence but is actually consumer config, not rulebook prose."

**Ownership.** `ai-dlc-update` owns this file — it lives under its own
`reconcile/` directory, per the skill's HARD CONSTRAINT (self-contained: no
dependency on the consumer's pipeline rulebook). `gate-validation.md`
(pipeline-side) is allowed to READ it — the one documented, one-directional
exception. `ai-dlc-update` never reads pipeline files; the pipeline may read
this file.

**Authoring rule.** Every entry below MUST trace to an explicit "Files to
replace in" directive in `ai-dlc-setup/SKILL.md` STEP 3 (deploy/smoke commands)
or STEP 4 (ownership paths). Model strings are not sites — they live in the
consumer's `aiDlcModels` settings block, which reconciles as a `json-merge`. Do NOT add an entry
just because a `{token}`-shaped HTML comment exists in a core file — several
do without being wired into any setup STEP (see "Explicitly NOT sites"
below). Re-derive this file whenever those STEPs change.

**Matching.** `single-line` sites carry a `match` regex with exactly one
capture group — the captured group is the live consumer value. Masking and
reinjection, and the gate-validation line-level check, operate ONLY on the
captured span, never the whole line, wherever the site shares its line with
fixed core prose. `heading-block` sites span everything between `heading`
and the next occurrence of `next_heading`, exclusive of `next_heading`
itself; the block may or may not still contain the original HTML doc
comment (consumer editing frequently drops it) — do not assume it survives.

**Anchor-drift.** If a site's `match` regex or `heading` cannot be located in
`theirs` (upstream restructured or reworded that section), STOP and flag the
site for operator adjudication. Never silently drop a live consumer value,
and never best-effort-append it somewhere plausible — a wrongly-placed model
string or ownership path is worse than a stalled run.

## Core-manifest file list

Duplicated here (a deliberate copy of the pipeline's
`core/skills/ai-dlc/core-manifest.md`, not read from it) to keep
`ai-dlc-update` self-contained per this skill's HARD CONSTRAINT — it never
reads pipeline files. Keep this list in sync with `core-manifest.md` when
the core file set changes:

```yaml
core_manifest:
  - core/skills/ai-dlc/core-manifest.md
  - core/git-hooks/pre-push
  - core/skills/ai-dlc/SKILL.md
  - core/skills/ai-dlc/steps/*.md
  - core/skills/ai-dlc/escalations.md
  - core/skills/ai-dlc/rule-authoring.md
  - core/skills/ai-dlc/templates/*.md
  - core/team-roles/*.md
  - core/hooks/ai-dlc-*.sh
  - core/session-driver/*.sh
  - core/schemas/*.json
  - core/skills/ai-dlc-setup/**
  - core/skills/ai-dlc-update/**
  - core/scripts/ai-dlc/*
  - core/fixtures/adversarial-citation/**
  - core/fixtures/apply-drift-after-write/**
  - core/fixtures/apply-drift-refile/**
  - core/fixtures/apply-legacy-script-path/**
  - core/fixtures/apply-restamp-theirs/**
  - core/fixtures/askuserquestion-citation/**
  - core/fixtures/audit-anchors-schema/**
  - core/fixtures/blocker-adjudication-record/**
  - core/fixtures/bmad-invocation-resolve/**
  - core/fixtures/check-15-bypass/**
  - core/fixtures/check-17-bypass/**
  - core/fixtures/check-17-counts/**
  - core/fixtures/check-1c-bypass/**
  - core/fixtures/check-23-draft-stamps/**
  - core/fixtures/check-24-adversarial-convergence/**
  - core/fixtures/check-25-steering-conduct/**
  - core/fixtures/check-31-ac-falsifiability/**
  - core/fixtures/check-3b-locked-anchor/**
  - core/fixtures/check-h1-recursion/**
  - core/fixtures/check-manifest-bypass/**
  - core/fixtures/check5-anchor-base/**
  - core/fixtures/ci-gates-resolution/**
  - core/fixtures/context-mode-protect/**
  - core/fixtures/context-sensor/**
  - core/fixtures/core-script-boundary/**
  - core/fixtures/core-write-guard/**
  - core/fixtures/cycle-commits-enforce/**
  - core/fixtures/dispatch-model-guard/**
  - core/fixtures/divergence-hard-block/**
  - core/fixtures/escalation-citation/**
  - core/fixtures/escalation-status-vocabulary/**
  - core/fixtures/gate-adjudication/**
  - core/fixtures/gate-verdict-grep-shape/**
  - core/fixtures/h2-attest-scripts-dir/**
  - core/fixtures/handoff-resume-guard/**
  - core/fixtures/implementation-join-yield/**
  - core/fixtures/inflight-row-shape/**
  - core/fixtures/known-skills-extension/**
  - core/fixtures/layer-catalog-collision/**
  - core/fixtures/layer-readopt-gate/**
  - core/fixtures/ledger-reverify/**
  - core/fixtures/ledger-reverify-unfalsifiable/**
  - core/fixtures/ledger-rotate/**
  - core/fixtures/mandatory-rules-clean-tree/**
  - core/fixtures/pause-hook-origin/**
  - core/fixtures/provenance-not-accessible/**
  - core/fixtures/reconcile-blocking-list/**
  - core/fixtures/reconcile-emit-report/**
  - core/fixtures/relabel-theirs-collision/**
  - core/fixtures/release-version-triple/**
  - core/fixtures/relocation-preclassify/**
  - core/fixtures/resume-whole-read/**
  - core/fixtures/retired-contract-token/**
  - core/fixtures/retired-layer-contract/**
  - core/fixtures/retro-audit-scans/**
  - core/fixtures/route-defect-classification/**
  - core/fixtures/setup-config-drift/**
  - core/fixtures/shadowed-local-validators/**
  - core/fixtures/snapshot-evidence-cell/**
  - core/fixtures/snapshot-section-schema/**
  - core/fixtures/spec-adoption-floor/**
  - core/fixtures/spec-join-integrity/**
  - core/fixtures/sprint-status-lifecycle/**
  - core/fixtures/story-provenance/**
  - core/fixtures/subagent-probe/**
  - core/fixtures/taught-schema/**
  - core/fixtures/validate-mandatory-rules-revive/**
  - core/fixtures/validator-path-resolution/**
  - core/fixtures/verdict-pass-content/**
  - core/fixtures/wait-stale-deliverable/**
  - core/fixtures/whole-read-pool/**

machinery:
  - core/skills/ai-dlc/core-manifest.md
  - core/git-hooks/pre-push
  - core/skills/ai-dlc/templates/*.md
  - core/hooks/ai-dlc-*.sh
  - core/session-driver/*.sh
  - core/schemas/*.json
  - core/skills/ai-dlc-setup/**
  - core/skills/ai-dlc-update/**
  - core/scripts/ai-dlc/*

rulebook:
  - core/skills/ai-dlc/SKILL.md
  - core/skills/ai-dlc/steps/*.md
  - core/skills/ai-dlc/escalations.md
  - core/skills/ai-dlc/rule-authoring.md
  - core/team-roles/*.md
```

## Sites

```yaml
sites:
  - id: dev-ownership-paths
    file: core/team-roles/dev.md
    shape: heading-block
    heading: '## Ownership'
    next_heading: '## Responsibilities'

  - id: qa-ownership-paths
    file: core/team-roles/qa.md
    shape: heading-block
    heading: '## Ownership'
    next_heading: '## Responsibilities'

  - id: deploy-command
    file: core/skills/ai-dlc/steps/deploy-validate.md
    shape: single-line
    anchor_context: >-
      the fenced line directly under "Run the project's deployment
      command:" in "### 2. Deploy" — this fence has no other content,
      whole line is the captured value
    match: '^(.+)$'
  - id: deploy-validate-smoke-command
    file: core/skills/ai-dlc/steps/deploy-validate.md
    shape: single-line
    anchor_context: >-
      the fenced line under "Run live smoke tests and **capture
      output**:" in "### 3. Smoke Tests"
    match: '^(.+?) 2>&1 \| tee test-results/smoke-test-output\.txt$'

  - id: implementation-smoke-command
    file: core/skills/ai-dlc/steps/implementation.md
    shape: single-line
    anchor_context: >-
      "Dev teammates — mandatory evidence requirements" bullet, under
      "### 5. Begin Implementation". The token sits alone on its own
      physical line — the preceding line ("run live smoke tests") and
      following line ("alone are not sufficient.") are SEPARATE physical
      lines in the wrapped prose; the match below is scoped to the
      token's own line only, do not span the paragraph.
    match: '^\s*\((.+?)\) and log output in the story file\.'
```

## Explicitly NOT sites

Documented so a future author doesn't add them:

- **The `- Model:` key line in `core/team-roles/*.md`.** A role file names a
  KEY; the consumer's `aiDlcModels` block in `.claude/settings.json` maps that
  key to a model string. The key is rulebook prose and is core-owned like any
  other line in the file. The string is consumer config in `settings.json`,
  which reconciles through `template-sites.md` as a `json-merge` whose
  `aiDlcModels` merge is additive with the consumer winning on conflict — so a
  consumer's model strings survive a pull by construction, with no
  mask/reinject step. Do not add a site for the `- Model:` line: a consumer
  changing which key a role names is real, classifiable rulebook divergence,
  exactly like `/effort` below.
- **A model-strategy span in `ai-dlc-setup/SKILL.md` STEP 2.** STEP 2 carries
  no consumer-specific choice — the operator's model decision is which string
  each `aiDlcModels` key holds, and that lives in `settings.json`. Do not
  declare a heading-block over STEP 2.

- **`- \`/effort <level>\`` in every team-role file.** Ships concrete since
  before the first tagged release — there has never been an `{effort}`
  template token. A
  consumer changing this value is real, classifiable rulebook divergence
  (most likely `domain-local`), never a setup-fill restore target.
- **The party-persona role files (`tea.md`, `ux.md`, `sm.md`, `cis.md`).** By
  design these name no model at all — they are spawned by the external
  `/bmad-party-mode` sub-skill, which controls their model, so an ai-dlc key
  there would be inert. They have no `- Model:` line, and the dispatch guard
  fails open on them deliberately. Do not add sites for them.
- **`{running_digest_command}` / `{function_verification_command}`** in
  `steps/deploy-validate.md`. These look identical to `{deploy_command}` /
  `{smoke_test_command}` (same `<!-- {token}: ... -->` comment shape) but
  have zero hits in `ai-dlc-setup/SKILL.md`'s STEP 2/3/4 "Files to replace
  in" lists — they are not wired to any setup step. Ordinary content, not
  exemption sites.
- **The local-model (Ollama) line in `core/team-roles/dev.md`.** It documents a
  launch-time choice — the lead starts that teammate with the local model on the
  command line — so there is no `/model` switch and no value to preserve.
