---
story_id: fixture-uncheckable
---

# Fixture story (UNCHECKABLE) — requirement bullets, no citation of either form

<!-- LOCKED_REQUIREMENTS — DO NOT MODIFY DURING VALIDATION -->
<!-- Source: user input -->
- LR-1: The reconcile step MUST refuse to run when the local branch is ahead
  of or behind its upstream by any commit.
- LR-2: The post-compact re-attach budget MUST be capped at 5,000 tokens.
<!-- END LOCKED_REQUIREMENTS -->

This story is UNCHECKABLE: its LOCKED block asserts requirement bullets but
carries neither a `full_text_source:` (a verbatim-text claim) nor a
`requires_context:` (an honest load pointer). Stock validate-locked-anchor.sh
`continue`d on the absent `full_text_source:` and PASSED it with
claims_checked=0 — PASS by "there was nothing to check", indistinguishable
from PASS by "every claim verified". MUST FAIL.
