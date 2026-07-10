---
story_id: fixture-bad
requires_context:
  - prd.md  # LR-1
---

# Fixture story (BAD) — mis-anchored, summarized full-text claim

<!-- LOCKED_REQUIREMENTS — DO NOT MODIFY DURING VALIDATION -->
<!-- Source: user input -->
full_text_source: prd.md:LR-1
- LR-1: Reconcile refuses on an un-synced branch (see prd.md for full text).
<!-- END LOCKED_REQUIREMENTS -->

This story FAILS validate-locked-anchor.sh on two counts: the
`full_text_source:` cites `prd.md` (a condensed index) rather than the
source of record `product-brief.md`, and the bullet is a ≤250-char summary
that is not byte-present in the record.
