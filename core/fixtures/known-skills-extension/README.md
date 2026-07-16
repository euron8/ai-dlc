# Fixture: known-skills-extension

Self-test for the consumer `known_skills` extension point in `validate-provenance-block.sh`.

## The problem it closes

`known_skills` in `schemas/provenance-block.json` is a **core** list — the skills the distribution
ships. A consumer with its own party-persona or sub-skill (whose real invocation emits a
`SKILL_INVOCATION_PROVENANCE` block citing it) had **no layer-correct way** to register the name:
editing the core schema in place was the only option, and `/ai-dlc-update` now flags that as
`HARD-UNREGISTERED-CORE-DRIFT` (schemas are drift-scanned as of v0.63.2). This proves
`extensions/known-skills.json` is the additive, drift-free alternative.

## What it proves

- without any extension, a block citing a consumer-only skill (`bmad-agent-tea-tea`) **FAILS** (it
  is genuinely not a core skill);
- with `extensions/known-skills.json` — object form `{ "known_skills": ["…"] }` — the block
  **PASSES**;
- the bare-array form `["…"]` also works;
- a present-but-**malformed** extension **fails closed** (never silently degrades to the core-only
  list — a legit registered skill must not wrongly read as forged);
- a nonexistent path is treated as absent (no crash).

Uses the `AI_DLC_KNOWN_SKILLS_EXT` env override to point the real validator at each temp extension.

## Run

    bash run.sh

Exit 0 = every assertion holds. Ships to consumers (it tests a shipped validator); `run.sh`
resolves both the distribution and consumer layouts.
