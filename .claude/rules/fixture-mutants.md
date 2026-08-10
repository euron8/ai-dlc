---
paths:
  - "core/fixtures/**"
---

<!-- no-stub: authoring or changing a mutation battery always begins by reading the
     fixture's own run.sh, which is inside `core/fixtures/**`, so the trigger fires on
     the first action of the work. A CLAUDE.md pointer would restate a trigger that
     already fires. -->

# Mutants

- Build the mutant as a **copy**, never an in-place edit, and guard with `cmp -s`
  so a `sed` that matched nothing cannot pass as a mutation.
- **Revert every layer of a layered fix.** A partial revert produces a mutant
  that proves the layer you left in place, and it comes out green.
- Add an **unmutated control** from the same directory whenever the harness
  itself could be what fails — a lone script copy that dies sourcing `lib.sh`
  emits nothing, and "no output" otherwise scores as a kill.
- Assert a **positive outcome**, not the absence of the old failure message.
- A mutant must fail **only** its own assertion. Two failures mean the
  assertions are entangled and one of them is vacuous.
