# Check 1c Bypass Fixture

Scenario: branch contains a commit whose subject contains the literal
word `research` embedded in unrelated prose (e.g., `Sprint N fix:
research findings about noop`) that would match a naive substring grep
but fail the anchored regex in arm (a). PRD lacks R-marker lines.

Strengthened Check 1c FAILS; naive substring variant PASSES.

Run `seed.sh` to reproduce idempotently.
