---
story_id: fixture-nothing-verified
---

# Fixture story (ZERO VERIFICATIONS) — a block that claims nothing

<!-- LOCKED_REQUIREMENTS — DO NOT MODIFY DURING VALIDATION -->
<!-- Source: user input -->
<!-- END LOCKED_REQUIREMENTS -->

This story PASSES, and that is correct: a block with no requirement bullets
claims nothing, so there is nothing to substantiate. Failing it would red every
legacy block in a consumer's history for a defect it does not have.

What it must NOT do is print the same line as a verified story. Exit code 0 has
two structurally different roads — "every claim verified" and "there was
nothing to check" — and they shared one report line, so an operator reading a
green gate could not tell which one a story took. Measured on a reference
consumer, 196 of 998 stories took the second road and 0 took the first; the
whole corpus reported PASS and nothing had ever been verified.

The assertion is therefore on the STRING, not the exit code: this file must
report `PASS — NOTHING VERIFIED` and `good-story.md` must not.
