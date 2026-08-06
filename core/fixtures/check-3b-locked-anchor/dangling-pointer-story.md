---
story_id: fixture-dangling-pointer
---

# Fixture story (DANGLING LOAD POINTER) — requires_context names an absent anchor

<!-- LOCKED_REQUIREMENTS — DO NOT MODIFY DURING VALIDATION -->
<!-- Source: user input -->
requires_context: product-brief.md#LR-99-NEVER-WRITTEN
- LR-99: The reconcile step MUST do something the brief has never recorded
  (loaded by reference; not byte-matched).
<!-- END LOCKED_REQUIREMENTS -->

This story FAILS. The citation form is honest — a `requires_context:` load
pointer, whose bullets are correctly never byte-matched — but the anchor it
names is absent from the artifact, so a dev told to load it at implementation
time gets nothing.

The discriminating pair for this file is `requires-context-story.md`, which is
the same shape with an anchor that RESOLVES and must stay green. Without that
pair, a validator that failed every `requires_context:` block would satisfy
this assertion, and a validator that always fails is indistinguishable from one
that works.
