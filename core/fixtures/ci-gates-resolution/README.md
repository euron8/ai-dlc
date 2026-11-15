# ci-gates-resolution Fixture

Discriminating self-test for `core/scripts/validate-ci-gates.sh`'s generalized
enforcement matching. `run.sh` builds throwaway trees under `mktemp` and drives the
validator through the tunables a consumer would set (`AI_DLC_PROJECT_ROOT`,
`AI_DLC_RETRO_DIR`, `AI_DLC_CI_SURFACE`, `AI_DLC_CI_ALIAS_TABLE`).

Assertions:

- **A — EXAMINED NOTHING = exit 78.** No enforcement surface -> exit 78, never 0/1/2.
- **B — comment-aware forward match.** A gate named only in a `#` comment is DORMANT (the
  old `grep -rqF` was fail-open — a name in a banner read as enforced).
- **C — honest enforcement.** Gates present in non-comment code pass.
- **D — alias resolves.** A gate enforced under a different name resolves when BOTH legs
  hold (enforcer wired + anchor present exactly once in non-comment code).
- **E — leg (ii) exactly-once.** An anchor present twice is not exactly once -> DORMANT.
- **F — leg (i) wired.** An enforcer id absent from the surface -> DORMANT despite the
  anchor.

Run `run.sh` to reproduce.
