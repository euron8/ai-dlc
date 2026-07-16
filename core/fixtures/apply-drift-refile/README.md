# Fixture: apply-drift-refile

Self-test for `reconcile/apply.sh` — the resolution driver that makes `ai-dlc-update` **do** the
update, not report it.

## What it proves

The recurring pain was: the report flagged an in-place `known_skills` edit to
`provenance-block.json`, and the operator had to "migrate the drift manually" (write the extension
file, revert the schema). That is mechanical. `apply.sh` does it:

- before: the consumer added `my-persona-skill` to the core schema's `known_skills` in place, no
  extension file;
- after `apply.sh`: the manifest reports `RESOLVED drift-refile`, `extensions/known-skills.json`
  exists carrying the skill, the core schema is reverted (drift gone), and the version stamp is
  advanced — all with no operator step.

`apply.sh` resolves the mechanical set (pure applies, token defaults, drift refile, relabel,
restamp) and hands back only the genuinely semantic merges (`WORKLIST`) and true decisions
(`DECISION`); this fixture isolates the drift-refile path.

## Run

    bash run.sh

Exit 0 = every assertion holds. Ships to consumers; `run.sh` resolves both layouts.
