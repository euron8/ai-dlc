---
story_id: fixture-requires-context
---

# Fixture story (HONEST CITE-BY-REFERENCE) — requires_context, no full-text claim

<!-- LOCKED_REQUIREMENTS — DO NOT MODIFY DURING VALIDATION -->
<!-- Source: user input -->
requires_context: product-brief.md#LR-1
- LR-1: The reconcile step MUST refuse to run when the local branch is ahead
  of or behind its upstream by any commit (loaded by reference; not byte-matched).
<!-- END LOCKED_REQUIREMENTS -->

This story PASSES: the block makes NO full-text claim (no `full_text_source:`),
only an honest `requires_context:` load pointer, which this script's contract
says is never byte-matched. The uncheckable guard fires on `bullets and no
requires_context`, so honest cite-by-reference is not red — a validator that
failed this too would red every cite-by-reference block in the repo.
