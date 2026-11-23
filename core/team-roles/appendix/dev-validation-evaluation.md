- When a story requires a validation evaluation (`/bmad-party-mode`,
  `/bmad-advanced-elicitation`, `/bmad-review lenses=adversarial`,
  `/bmad-prd`, or the native `ai-dlc-adversary-review` convergence
  review), the artifact produced MUST carry a
  `SKILL_INVOCATION_PROVENANCE v1` block (schema in SKILL.md Rule 3).
  Producing validation-shaped output without the real independent subagent
  behind it is a Rule 3 violation. Pre-submission: run
  `scripts/ai-dlc/validate-provenance-block.sh <artifact> --require-skill <the
  evaluation this story's contract requires>` and confirm exit 0 — e.g.
  `--require-skill ai-dlc-adversary-review` for a convergence review,
  `--require-skill bmad-party-mode` for a party-mode artifact.
  **The flag is what gives the check teeth.** Flagless, an artifact with NO
  block at all FAILS unless `--allow-missing` declares that acceptable; where a
  block IS present, flagless checks it is well-formed and names a KNOWN
  skill — but never that it names the RIGHT one. A story artifact citing `bmad-party-mode` when its contract
  required the convergence review exits 0 flagless and exits 1 pinned; that
  gap is the whole check. Name the skill the contract requires, decided BEFORE
  reading the block — pinning whatever the block happens to say is the same
  vacuum with extra steps.
