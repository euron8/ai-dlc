# Check H1 Recursion Guard Fixture

Scenario: H1 meta-check is invoked with H1_DEPTH=1 already set in
the environment. H1 MUST return PASS immediately without re-enumerating
fixtures to prevent infinite recursion.

Run `seed.sh` to reproduce idempotently.
