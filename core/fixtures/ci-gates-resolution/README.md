# ci-gates-resolution Fixture

Discriminating self-test for `core/scripts/validate-ci-gates.sh`'s generalized
enforcement matching. `run.sh` builds throwaway trees under `mktemp` and drives the
validator through the tunables a consumer would set (`AI_DLC_PROJECT_ROOT`,
`AI_DLC_RETRO_DIR`, `AI_DLC_CI_SURFACE`, `AI_DLC_CI_ALIAS_TABLE`).

Assertions, each general mechanism paired with a MUTATION control:

- **A — VACUOUS = exit 78.** No enforcement surface -> exit 78, never 0/1/2. Mutation:
  revert to `exit 2` and require the code to flip.
- **B — comment-aware forward match.** A gate named only in a `#` comment is DORMANT (the
  old `grep -rqF` was fail-open — a name in a banner read as enforced). Mutation: neuter
  the comment strip and require the comment-only gate to read enforced again.
- **C — honest enforcement.** Gates present in non-comment code pass.
- **D — alias resolves.** A gate enforced under a different name resolves when BOTH legs
  hold (enforcer wired + anchor present exactly once in non-comment code).
- **E — leg (ii) exactly-once.** An anchor present twice is not exactly once -> DORMANT.
  Mutation: relax `-eq 1` to `-ge 1` and require the twice case to resolve.
- **F — leg (i) wired.** An enforcer id absent from the surface -> DORMANT despite the
  anchor. Mutation: disable leg (i) and require the unwired case to resolve.

A FAIL/PASS is evidence for a mechanism only if removing that mechanism flips it; that is
what the mutation controls assert. Run `run.sh` to reproduce.
