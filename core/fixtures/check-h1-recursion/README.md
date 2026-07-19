# Check H1 Recursion Guard Fixture

Scenario: H1 meta-check is invoked with H1_DEPTH=1 already set in
the environment. H1 MUST return PASS immediately without re-enumerating
fixtures to prevent infinite recursion.

Run `seed.sh` to reproduce idempotently.

**No `run.sh`, deliberately.** The condition under test is H1's own control
flow, which no script observes — there is nothing for a driver to assert. The
seed establishes the guard state instead. Do not file this as an undriven
fixture; `check-1c-bypass` and `check-15-bypass` got drivers because their
checks publish mechanical regexes, and this one does not.
