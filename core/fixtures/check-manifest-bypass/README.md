# Check Manifest Slicing-Bypass Fixture

Scenario: a gate declares type `implementation` but loads only the
**planning** slice of `gate-validation.md` — universal core plus the
planning row `1c, 17, 20` — omitting the implementation-required checks
(6, 8, 11, and also 5, 9, 10, 11a, 19, 22). The `CHECK_LOADED` anchors
for the omitted implementation checks are therefore absent from loaded
context.

This is the adversarial self-test for the v0.24.0 Lever 2 fidelity
re-expression: slicing weakened "whole file loaded" to "every applicable
check loaded", and H1's manifest-completeness pass is what proves the
slice did not silently drop a required check.

Expected: H1 reads `GATE_MANIFEST`, resolves the declared type
(`implementation`), and FAILS the gate by naming at least one missing
required `CHECK_LOADED` anchor (e.g. `CHECK_LOADED: 6`). A seed that H1
PASSES means the fidelity guarantee does not hold and a real gate could
skip a required check — the exact class of failure the scar tissue
exists to prevent.

H2 item (3) re-drives this fixture and FAILS if H1 does not catch it.

Run `seed.sh` to reproduce idempotently.
