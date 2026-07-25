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
replace in" directive in `ai-dlc-setup/SKILL.md` STEP 2 (models), STEP 3
(deploy/smoke commands), or STEP 4 (ownership paths). Do NOT add an entry
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
  - core/scripts/ai-dlc/audit-rule-files.sh
  - core/scripts/ai-dlc/core-paths.sh
  - core/scripts/ai-dlc/gen-architecture-index.js
  - core/scripts/ai-dlc/sprint-status.sh
  - core/scripts/ai-dlc/stamp-story-provenance.sh
  - core/scripts/ai-dlc/sync-taught-schema.sh
  - core/scripts/ai-dlc/validate-adversarial-convergence.sh
  - core/scripts/ai-dlc/validate-artifact-budget.sh
  - core/scripts/ai-dlc/validate-audit-anchors.sh
  - core/scripts/ai-dlc/validate-ci-gates.sh
  - core/scripts/ai-dlc/validate-compact-window.sh
  - core/scripts/ai-dlc/validate-cycle-commits.sh
  - core/scripts/ai-dlc/validate-draft-stamps.sh
  - core/scripts/ai-dlc/validate-escalation-resolution.sh
  - core/scripts/ai-dlc/validate-escalation-status-vocabulary.sh
  - core/scripts/ai-dlc/validate-gate-adjudication.sh
  - core/scripts/ai-dlc/validate-gate-manifest.sh
  - core/scripts/ai-dlc/validate-h2-attestation.sh
  - core/scripts/ai-dlc/validate-layer-entries.sh
  - core/scripts/ai-dlc/validate-locked-anchor.sh
  - core/scripts/ai-dlc/validate-mandatory-rules.sh
  - core/scripts/ai-dlc/validate-provenance-block.sh
  - core/scripts/ai-dlc/validate-reattach-budget.sh
  - core/scripts/ai-dlc/validate-retro-evidence.sh
  - core/scripts/ai-dlc/validate-steering-budget.sh
  - core/scripts/ai-dlc/verdict.sh
  - core/scripts/ai-dlc/wait-for-deliverable.sh
```

## Sites

```yaml
sites:
  - id: architect-model-personal
    file: core/team-roles/architect.md
    shape: single-line
    match: '^- Personal: `/model (.+)`$'
  - id: architect-model-bedrock
    file: core/team-roles/architect.md
    shape: single-line
    match: '^- Bedrock: `/model (.+)`$'

  - id: reviewer-model-personal
    file: core/team-roles/code-reviewer.md
    shape: single-line
    match: '^- Personal: `/model (.+)`$'
  - id: reviewer-model-bedrock
    file: core/team-roles/code-reviewer.md
    shape: single-line
    match: '^- Bedrock: `/model (.+)`$'

  - id: reviewer-escalated-model-personal
    file: core/team-roles/code-reviewer-escalated.md
    shape: single-line
    match: '^- Personal: `/model (.+)`$'
  - id: reviewer-escalated-model-bedrock
    file: core/team-roles/code-reviewer-escalated.md
    shape: single-line
    match: '^- Bedrock: `/model (.+)`$'

  - id: pm-model-personal
    file: core/team-roles/pm.md
    shape: single-line
    match: '^- Personal: `/model (.+)`$'
  - id: pm-model-bedrock
    file: core/team-roles/pm.md
    shape: single-line
    match: '^- Bedrock: `/model (.+)`$'

  - id: dev-model-personal
    file: core/team-roles/dev.md
    shape: single-line
    match: '^- Personal: `/model (.+)`$'
  - id: dev-model-bedrock
    file: core/team-roles/dev.md
    shape: single-line
    match: '^- Bedrock: `/model (.+)`$'
  - id: dev-ownership-paths
    file: core/team-roles/dev.md
    shape: heading-block
    heading: '## Ownership'
    next_heading: '## Responsibilities'

  - id: dev-escalated-model-personal
    file: core/team-roles/dev-escalated.md
    shape: single-line
    match: '^- Personal: `/model (.+)`$'
  - id: dev-escalated-model-bedrock
    file: core/team-roles/dev-escalated.md
    shape: single-line
    match: '^- Bedrock: `/model (.+)`$'

  - id: qa-model-personal
    file: core/team-roles/qa.md
    shape: single-line
    match: '^- Personal: `/model (.+)`$'
  - id: qa-model-bedrock
    file: core/team-roles/qa.md
    shape: single-line
    match: '^- Bedrock: `/model (.+)`$'
  - id: qa-ownership-paths
    file: core/team-roles/qa.md
    shape: heading-block
    heading: '## Ownership'
    next_heading: '## Responsibilities'

  - id: analyst-model-personal
    file: core/team-roles/analyst.md
    shape: single-line
    match: '^- Personal: `/model (.+)`$'
  - id: analyst-model-bedrock
    file: core/team-roles/analyst.md
    shape: single-line
    match: '^- Bedrock: `/model (.+)`$'

  - id: adversary-model-personal
    file: core/team-roles/adversary.md
    shape: single-line
    match: '^- Personal: `/model (.+)`$'
  - id: adversary-model-bedrock
    file: core/team-roles/adversary.md
    shape: single-line
    match: '^- Bedrock: `/model (.+)`$'

  - id: gate-adjudicator-model-personal
    file: core/team-roles/gate-adjudicator.md
    shape: single-line
    match: '^- Personal: `/model (.+)`$'
  - id: gate-adjudicator-model-bedrock
    file: core/team-roles/gate-adjudicator.md
    shape: single-line
    match: '^- Bedrock: `/model (.+)`$'

  - id: remediator-model-personal
    file: core/team-roles/remediator.md
    shape: single-line
    match: '^- Personal: `/model (.+)`$'
  - id: remediator-model-bedrock
    file: core/team-roles/remediator.md
    shape: single-line
    match: '^- Bedrock: `/model (.+)`$'

  - id: ppe-model-personal
    file: core/team-roles/protected-path-editor.md
    shape: single-line
    match: '^- Personal: `/model (.+)`$'
  - id: ppe-model-bedrock
    file: core/team-roles/protected-path-editor.md
    shape: single-line
    match: '^- Bedrock: `/model (.+)`$'

  - id: setup-model-strategy
    file: core/skills/ai-dlc-setup/SKILL.md
    shape: heading-block
    heading: '## STEP 2: API Tier and Model Strings'
    next_heading: '**`.claude/team-roles/architect.md`:**'
    anchor_context: >-
      The operator's model-strategy CHOICE only — the strategy mode (Full /
      Balanced / Sonnet-only), the Bedrock follow-up, and the tier-per-role
      example table. This is per-project config the operator customises at
      setup, not rulebook prose: a consumer choosing Balanced over the
      shipped Full is a cost/capability decision, exactly like the model
      strings it drives. Declaring the span exempts that choice from
      in-place core drift at BOTH readers (the pull-time unregistered-drift
      check and the retro-gate immutability check), while leaving the rest
      of the setup wizard guarded. Bounded EXCLUSIVELY at the first
      substitution row, not at the next STEP heading. Bounding it on `##
      STEP 3` also swallowed the ~140 lines of substitution INSTRUCTIONS
      that follow the choice — which files to open and which tokens to fill
      — so upstream could add a role's model-fill block and no layered
      consumer would ever receive it, with no signal at either reader. That
      is not hypothetical: measured on the reference consumer, the
      `dev-escalated` / `analyst` / `remediator` blocks and the
      `{analyst_model}` rows are all present upstream and absent there. The
      terminator is a bold row rather than a heading because STEP 2 carries
      no sub-headings; it is matched as a whole line, and it must exist at
      core@base or `exempt_ranges` cannot bound the span.

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

- **`- \`/effort <level>\`` in every team-role file.** Ships concrete since
  before the first tagged release — there has never been an `{effort}`
  template token. A
  consumer changing this value is real, classifiable rulebook divergence
  (most likely `domain-local`), never a setup-fill restore target.
- **`/model` in the party-persona role files (`tea.md`, `ux.md`, `sm.md`,
  `cis.md`).** By design these carry NO model placeholder — they are spawned
  by the external `/bmad-party-mode` sub-skill, which controls their model, so
  an ai-dlc `{*_model_*}` token there would be inert. They have no `- Personal:
  \`/model …\`` line to mask. Do not add sites for them. (`protected-path-editor.md`
  IS directly Agent-spawned and DOES carry `{ppe_model_*}` sites, above.)
- **`{running_digest_command}` / `{function_verification_command}`** in
  `steps/deploy-validate.md`. These look identical to `{deploy_command}` /
  `{smoke_test_command}` (same `<!-- {token}: ... -->` comment shape) but
  have zero hits in `ai-dlc-setup/SKILL.md`'s STEP 2/3/4 "Files to replace
  in" lists — they are not wired to any setup step. Ordinary content, not
  exemption sites.
- **`{dev_model_local}`** in `core/team-roles/dev.md`. `ai-dlc-setup/SKILL.md`
  STEP 2 references it ("`{dev_model_local}` -> local model string ... or
  remove the line if N/A"), but `dev.md` itself has no live line containing
  this token — it appears only inside the HTML doc comment. There is
  nothing to mask; do not add a site for it.
