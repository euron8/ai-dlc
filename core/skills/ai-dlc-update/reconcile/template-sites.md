# Template reconcile manifest — SHARED, read-only data

The rulebook reconcile (setup-sites.md + preclassify's default mode) covers
`core/` only. But three generated files live OUTSIDE `core/` — they are
produced from `templates/*.template` at install time and then filled with
consumer-specific config by `ai-dlc-setup`. Upstream edits to the template
boilerplate (a removed section, a reworded rule, a new bullet) never reach a
consumer through the `core/` reconcile, because the consumer's live copy is
not a `core/` file. This manifest is what lets `ai-dlc-update` reconcile them
too — sync the upstream boilerplate delta while preserving the consumer's
filled-in config.

Self-contained like the rest of this skill: read only this file + git + the
consumer tree. Never read the pipeline rulebook.

## Two kinds of generated file

Templates split by how their consumer values are carried:

1. **Token-filled prose** — `CLAUDE.md`, `docs/coding-conventions.md`,
   `QUICKSTART.md`. The template ships `{token}` placeholders (e.g.
   `{deploy_command}`, `{project_operations_protocol}`), each preceded in the
   template by a self-describing HTML marker comment
   (`<!-- {token}: <instructions> -->`). `ai-dlc-setup` replaces each token
   (and usually drops the marker) with real consumer content. Reconciled via
   the **marker-anchored mask/reinject transform** below.

2. **Structured config** — `settings.json`. No tokens; assembled by a jq
   merge at install. Reconciled via the **jq strip/merge** path (not
   mask/reinject) — see "settings.json reconcile" below.

## Template manifest

```yaml
template_manifest:
  # token-filled prose (marker-anchored mask/reinject)
  - template: templates/CLAUDE.md.template
    consumer: CLAUDE.md
    kind: token-prose
  - template: templates/coding-conventions.md.template
    consumer: docs/coding-conventions.md
    kind: token-prose
  - template: templates/QUICKSTART.md.template
    consumer: QUICKSTART.md
    kind: token-prose
  # structured config (jq strip/merge)
  - template: templates/settings.json.template
    consumer: .claude/settings.json
    kind: json-merge
```

## Marker-anchored mask/reinject (token-prose files)

The template is self-documenting: every consumer-fill region is introduced by
a `<!-- {token}: … -->` marker in the template, and the token itself
(`{token}`) marks the exact substitution point. Use the TEMPLATE (base and
theirs) as the map of where consumer content lives; use the consumer file as
the source of the live values.

Per token-prose file, the reconcile is a three-way merge:

- **base-template** = `templates/<file>.template` at the stamp's rulebook
  `commit`.
- **theirs-template** = same path at the target ref.
- **ours** = the consumer's live generated file.

Procedure:

1. **Map the fill regions.** In base-template, each `{token}` (and its
   preceding `<!-- {token}: … -->` marker) delimits a consumer-fill region:
   the region is the token line itself for an inline token
   (`- Deploy command: \`{deploy_command}\``) or the span from the token to
   the next heading for a block token (`{project_operations_protocol}`). The
   fixed prose BETWEEN fill regions is upstream boilerplate.
2. **Extract ours.** For each fill region, capture the consumer's live content
   at the corresponding position in `ours` (the text that replaced the token /
   filled the block). This is the value to preserve.
3. **Compute the boilerplate delta.** Diff base-template → theirs-template
   restricted to the fixed (non-fill) prose. This is the upstream change the
   pull brings in — a removed section (e.g. the decommissioned Context-Mode
   Usage block), a reworded rule, a new boilerplate line.
4. **Rebuild.** Produce the new consumer file = theirs-template's boilerplate
   with each fill region reinjected from the values captured in step 2.
5. **Anchor-drift STOP.** If a token/marker present in base-template cannot be
   located in `ours` (the consumer restructured that region, or setup filled
   it in a shape the marker no longer describes), STOP and flag that file for
   operator adjudication. Never best-effort-place a preserved value — a
   misplaced deploy command or ownership path is worse than a stalled run.
   Same posture as setup-sites.md anchor-drift.

**Boilerplate-only shortcut.** If the base→theirs template delta touches ONLY
fixed prose (no fill region added, removed, or moved), the reconcile is a
clean boilerplate patch — apply the delta to `ours` between its existing fill
regions, no full rebuild needed. The decommission of the Context-Mode Usage
section is exactly this shape: a boilerplate block removed, every token
region untouched.

## settings.json reconcile (json-merge)

`settings.json` has no tokens. **Do not hand-write the jq.** Run the script —
it is the contract, and prose that an agent retypes as jq drifts:

```bash
# step 5 (dry-run report): what would change, and must the operator be asked?
.claude/skills/ai-dlc-update/reconcile/settings-merge.sh \
  --consumer .claude/settings.json \
  --template <theirs>/templates/settings.json.template \
  --check

# step 7 (apply): --model-row carries the operator's answer (1M | 200K | auto)
.claude/skills/ai-dlc-update/reconcile/settings-merge.sh \
  --consumer .claude/settings.json \
  --template <theirs>/templates/settings.json.template \
  --model-row <answer>
```

`--check` prints `model_row_needed=yes|no` plus the exact question to ask, and
writes nothing. Omitting `--model-row` on apply is equivalent to `auto`. The
script refuses to write when the consumer's settings.json is invalid JSON or
when the merge would produce invalid JSON, leaving the file untouched.

What the script guarantees (the same contract `scripts/install.sh` applies, so
a consumer that reconciles and a consumer that reinstalls converge):

- **hooks:** strip any block whose inner command matches
  `/\.claude/hooks/ai-dlc-[^/]+\.sh` (the `strip_ai_dlc` predicate), then
  append the template's hook blocks. Because the strip/re-append is
  wholesale over all `ai-dlc-*` hooks, the current template's hook set —
  including the `ai-dlc-protect.sh` PreToolUse matcher (re-added in
  v0.23.0) and the `PreCompact` / `PostCompact` / `SessionStart` compaction
  hooks (added in v0.35.0) — lands verbatim; a consumer that carried an older
  or absent block converges to the template's. The event-key set is a union of
  the consumer's and the template's, so a new event key needs no migration.
  **`strip_ai_dlc` is per-block, never per-event, and this now matters.**
  `SessionStart` is the first event key ai-dlc shares with tools outside it
  (context-mode and caveman both register `SessionStart` hooks). Stripping the
  whole event would silently delete a consumer's own hooks; stripping the
  matching blocks leaves them in place beside ai-dlc's.
- **enabledPlugins:** additive-only, NEVER remove. install.sh's merge is
  `$t + $u` (user wins); the reconcile follows the same rule — overlay the
  template's plugin keys onto the consumer and never drop a plugin the template
  no longer carries. `enabledPlugins` is consumer-owned state. The template's
  own `context-mode@context-mode: true` (re-added in v0.23.0) is overlaid
  additively — it enables the plugin on consumers that lack the key and is a
  no-op where the consumer already set it; it never overwrites a consumer who
  explicitly set it `false`. A template dropping a plugin removes ai-dlc's
  *use* of it, not the consumer's right to keep it enabled for their own
  reasons. A leftover entry is benign — inert if the
  plugin is uninstalled, honored if the consumer relies on it — whereas
  removing it silently disables a plugin the consumer may depend on. So the
  consumer's `enabledPlugins` is preserved in full, exactly like
  permissions/env/mcpServers. Disabling a plugin is the consumer's decision,
  never the reconcile's; this is NOT a deletions-list case.
- **permissions / env / mcpServers / other user keys:** preserved untouched,
  with exactly one provisioning exception (below).

### `env.AI_DLC_MODEL_ROW` — first-run provisioning only

The `ai-dlc-context-sensor.sh` Stop hook (v0.36.0) reads `AI_DLC_MODEL_ROW`
from the settings `env` block, which Claude Code propagates into hook
subprocesses. It selects which row of the SKILL.md threshold table applies.
The sensor cannot infer it from the transcript: Claude Code records
`claude-opus-4-8` for both the 200K and the 1M variant, and no window size
appears anywhere in the transcript.

**The reconcile NEVER writes this key when it is already present** — it is
consumer-owned, like the rest of `env`. `settings-merge.sh` provisions it only
when the key is **absent** AND the template being applied wires
`ai-dlc-context-sensor.sh` (i.e. the consumer is crossing into v0.36.0+); that
is precisely the `model_row_needed=yes` condition `--check` reports.

When `--check` says yes, put the question in the step-5 dry-run report, ask the
operator, and pass the answer to `--model-row` in step 7. `--check` prints the
question text; do not improvise it. On `auto` the script writes **nothing** —
an absent key is the inference path.

Never default this silently. Pinning `200K` sets `row_known=1` and disables
the sensor's self-correction, so a 1M project would fire early reminders
forever; pinning `1M` on a 200K model puts red (200,000) above that model's
compact threshold (187,000), so red would never fire before compaction — the
exact failure the auto-compact ordering invariant exists to prevent. An unset
key is always the safe state, which is why `auto` is the default answer.

## Ownership

`ai-dlc-update` owns this file (lives under its own `reconcile/`). Keep the
`template_manifest` in sync with `scripts/install.sh` whenever a template is
added, renamed, or removed, and with `ai-dlc-setup`'s token set whenever a new
`{token}` is introduced.
