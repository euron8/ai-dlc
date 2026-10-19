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
capture group — the captured group is the live consumer value. A site whose
`match` alone cannot pick out ONE line also carries `after_line`, a regex for
the nearest preceding line that IS distinctive; the site is then the first
matching line at or after it. `deploy-command`'s `match` is `^(.+)$` and its
`anchor_context` prose was, until `setup-site-drift.sh` shipped, the ONLY
locator — readable by an agent and by nothing else. A declared span no program
can find is a span no program can check, and the checker that could not find it
silently picked the wrong line rather than saying so. Masking and
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
the core file set changes.

The per-fixture `core/fixtures/<name>/**` entries are NOT here: they live in
the same-shaped `core_manifest:` block of `../fixture-manifest.md`, outside
`reconcile/`, so a new shipping fixture's one-line append changes no
reconcile-engine file. This block plus that one is the whole core file set;
`validate-enforcement-map.sh` I5 binds the union to `core-manifest.md` and
refuses a fixture entry in this block:

```yaml
core_manifest:
  - core/skills/ai-dlc/core-manifest.md
  - core/skills/ai-dlc/enforcement-map.yaml
  - core/skills/ai-dlc/layer-contract.yaml
  - core/git-hooks/pre-push
  - core/skills/ai-dlc/SKILL.md
  - core/skills/ai-dlc/steps/*.md
  - core/skills/ai-dlc/rule-bodies/*.md
  - core/skills/ai-dlc/escalations.md
  - core/skills/ai-dlc/rule-authoring.md
  - core/skills/ai-dlc/artifact-path-grammar.md
  - core/skills/ai-dlc/postcompact-digest.md
  - core/skills/ai-dlc/templates/*.md
  - core/team-roles/*.md
  - core/hooks/ai-dlc-*.sh
  - core/session-driver/*.sh
  - core/schemas/*.json
  - core/rules/*.md
  - core/skills/ai-dlc-setup/**
  - core/skills/ai-dlc-update/**
  - core/scripts/ai-dlc/*

machinery:
  - core/skills/ai-dlc/core-manifest.md
  - core/skills/ai-dlc/enforcement-map.yaml
  - core/skills/ai-dlc/layer-contract.yaml
  - core/git-hooks/pre-push
  - core/skills/ai-dlc/templates/*.md
  - core/skills/ai-dlc/postcompact-digest.md
  - core/hooks/ai-dlc-*.sh
  - core/session-driver/*.sh
  - core/schemas/*.json
  - core/rules/*.md
  - core/skills/ai-dlc-setup/**
  - core/skills/ai-dlc-update/**
  - core/scripts/ai-dlc/*

rulebook:
  - core/skills/ai-dlc/SKILL.md
  - core/skills/ai-dlc/steps/*.md
  - core/skills/ai-dlc/rule-bodies/*.md
  - core/skills/ai-dlc/escalations.md
  - core/skills/ai-dlc/rule-authoring.md
  - core/skills/ai-dlc/artifact-path-grammar.md
  - core/team-roles/*.md

consumer_machinery_home: scripts/ai-dlc-local/
consumer_machinery_subdirs: lib/ hooks/ fixtures/ config/ tests/
consumer_crosswalk_file: .claude/skills/ai-dlc/crosswalk.md
templates_local_home: .claude/skills/ai-dlc/templates-local/
```

`templates_local_home:` carries no `core/` prefix for the same reason
`consumer_machinery_home:` does not: it is a CONSUMER path, identical in both
layouts, and core never writes it. It is the escape hatch for the second shared
directory — `templates/*.md` claims every `.md` a consumer puts beside core's, so
without a declared home a consumer-authored template is `[core]`-owned by a glob
against a file upstream has never held, and the rule-file audit's only sanctioned
disposition for it is a push candidate that cannot be filed.

`consumer_crosswalk_file:` is here for the same reason and under the same rule.
It is the file LC-N6 requires a consumer to write a crosswalk row into, and it
was `extensions/README.md` — a file the distribution ships and this skill's own
`unregistered-drift.sh` compares against base, so the only compliant output of an
ERROR clause was an unregistered edit to upstream's tree. Declaring the path is
what lets the two ends disagree loudly instead of silently: `validate-enforcement-map.sh`
**I67** binds this copy to the one in `skills/ai-dlc/layer-contract.yaml` and
refuses to let the validator or the installer carry the literal. The AUTHORITATIVE
copy is the contract's, beside the clauses that cite it — this one exists because
this skill may not read pipeline files. Core never writes the file beyond
scaffolding it once.

`consumer_machinery_home:` carries NO `core/` prefix, unlike every entry above it.
The entries above name distribution paths that this skill maps into consumer form;
the home is a CONSUMER path already, identical in both layouts, and core never
writes it — so there is nothing to map. It is duplicated here for the same reason
the lists above are: this skill's HARD CONSTRAINT forbids reading pipeline files,
so `warn-shadowed-local-validators.sh` cannot reach `core-manifest.md` at runtime.
`validate-enforcement-map.sh` I43 binds the two copies and every other spelling.

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
    after_line: '^Run the project.s deployment command:$'
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

- **Model and effort in `core/team-roles/*.md`.** Role files state neither.
  `aiDlcRoles.<role>` in the consumer's `.claude/settings.json` states both, and
  `aiDlcModels` maps a model key to a string. Both blocks reconcile through
  `template-sites.md` as a `json-merge`, additive with the consumer winning on
  conflict, so a consumer's values survive a pull by construction with no
  mask/reinject step. There is nothing in a role file to declare as a site.
- **A model-strategy span in `ai-dlc-setup/SKILL.md` STEP 2.** STEP 2 carries
  no consumer-specific choice — the operator's model decision is which string
  each `aiDlcModels` key holds, and that lives in `settings.json`. Do not
  declare a heading-block over STEP 2.

- **Effort.** It lives in `aiDlcRoles.<role>.effort`, alongside the model, and
  reconciles with it as consumer config. No role file states one.
- **The party-persona role files (`tea.md`, `ux.md`, `sm.md`, `cis.md`).** Like
  every role file, these name no model — they are spawned by the external
  `/bmad-party-mode` sub-skill. A persona's model is optional and lives in its
  `aiDlcRoles` entry: set, the renderer writes a definition and the guard binds
  it like any role, including correcting the model on a `/bmad-party-mode`
  spawn; absent, `/bmad-party-mode` controls the model. Either way it is
  consumer config. Nothing to declare.
- **`{running_digest_command}` / `{function_verification_command}`** in
  `steps/deploy-validate.md`. These look identical to `{deploy_command}` /
  `{smoke_test_command}` (same `<!-- {token}: ... -->` comment shape) but
  have zero hits in `ai-dlc-setup/SKILL.md`'s STEP 2/3/4 "Files to replace
  in" lists — they are not wired to any setup step. Ordinary content, not
  exemption sites.
- **The local-model (Ollama) line in `core/team-roles/dev.md`.** It documents a
  launch-time choice — the lead starts that teammate with the local model on the
  command line — so there is no `/model` switch and no value to preserve.
