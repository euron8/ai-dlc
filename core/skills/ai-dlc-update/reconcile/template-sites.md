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

`settings.json` has no tokens. Reconcile it with the same jq contract
`scripts/install.sh` uses, extended for context-mode decommission:

- **hooks:** strip any block whose inner command matches
  `/\.claude/hooks/ai-dlc-[^/]+\.sh` (the `strip_ai_dlc` predicate), then
  append the template's hook blocks. This removes a stale
  `ai-dlc-protect.sh` PreToolUse matcher and re-adds the current hook set.
- **enabledPlugins:** install.sh's merge is additive (`$t + $u`, user wins),
  so it never REMOVES a plugin the template dropped. For the reconcile, when
  the template no longer carries a plugin key that the base template DID carry
  (e.g. `context-mode@context-mode`), treat that as an upstream removal:
  drop it from the consumer's `enabledPlugins` too — GATED as an operator
  confirmation (a plugin the consumer may rely on), listed in the report's
  deletions list. Keys the consumer added independently are preserved.
- **permissions / env / mcpServers / other user keys:** preserved untouched.

## Ownership

`ai-dlc-update` owns this file (lives under its own `reconcile/`). Keep the
`template_manifest` in sync with `scripts/install.sh` whenever a template is
added, renamed, or removed, and with `ai-dlc-setup`'s token set whenever a new
`{token}` is introduced.
