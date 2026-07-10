---
story_id: fixture-good
requires_context:
  - product-brief.md  # LR-1, LR-2 — honest load pointer, never byte-matched
---

# Fixture story (GOOD) — verbatim full-text claim anchored at the SoR

<!-- LOCKED_REQUIREMENTS — DO NOT MODIFY DURING VALIDATION -->
<!-- Source: user input -->
full_text_source: product-brief.md:LR-1
- LR-1: The reconcile step MUST refuse to run when the local branch is
  ahead of or behind its upstream by any commit, printing the exact
  divergence count and the remediation command, and MUST NOT fall back to
  a three-way merge under any circumstance including a clean working tree.
<!-- END LOCKED_REQUIREMENTS -->

This story PASSES: the `full_text_source:` resolves to the source of record
`product-brief.md`, the anchor `LR-1` exists there, and the requirement
bullet is byte-present verbatim (whitespace-collapsed). The frontmatter
`requires_context:` pointer is a load reference and is never byte-matched.
