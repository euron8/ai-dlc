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
  emits nothing, and "no output" otherwise scores as a kill. **The control is
  NECESSARY AND NOT SUFFICIENT, and believing otherwise is how a battery certifies
  silence.** Measured independently by two hands on two batteries: a control
  asserting rc=0-and-no-findings PASSES against a subject replaced by `exit 0`,
  because rc=0 with nothing reported is exactly what a clean copy looks like. What
  stops silence scoring as a kill is that every arm is PRESENCE-shaped — each one
  requiring a specific row or message to APPEAR — so a subject that emits nothing
  fails them by construction. Give the control a positive conjunct too: it must
  assert a baseline row is THERE, not merely that nothing went wrong.
- Assert a **positive outcome**, not the absence of the old failure message. A
  mutation that WIDENS a guard to match everything often produces the same
  output as the unmutated original, so it scores a kill it did not earn —
  measured on a `case` pattern widened to `*)`. Make the guard match NOTHING.
- **An ABSENCE-shaped arm is the one that REQUIRES a mutant, and a seeded
  near-miss is not a substitute.** Both-directions controls establish that the
  arm discriminates between two inputs; only a mutant establishes that it
  discriminates at all. Measured: a release shipped four fixtures whose new arms
  all had an offender and a near-miss, and with the subject replaced by
  `exit 0` two of them still printed `ok` — an absence passing for a program
  that never ran, one arm after the mutant written to prevent exactly that. Ask
  of every new arm whether it would pass against a subject that emits nothing;
  if yes, it needs a committed mutant, not a hand-run one.
- A mutant must fail **only** its own assertion. Two failures mean the
  assertions are entangled and one of them is vacuous. When both findings are
  genuinely true, the arms overlap rather than the mutant being wrong: decide
  which arm OWNS the case and make the other stand down for it.
- **Keep the fixture's author different from the arm's, deliberately.** An arm
  and a battery written by the same hand cannot disagree — they encode one
  understanding twice, and a false pass has an unreachable half nobody sees.
- **Never seed from what the reader accepts.** Seed from what the real producer
  emits. A seed derived from the reader's accept-set proves the reader accepts
  its own grammar and nothing else, and it stays green through a change to both.
- **A fixture whose tree cannot EXPRESS the defect proves nothing.** Check the
  seed can actually reach the branch under test, exercise a layout-conditional
  resolver against every root shape it claims to handle, and give the unit a
  positive control so a harness that died reports as broken rather than as clean.
  Two shapes measured while building one seed: the detector already had a guard
  covering the case (so the obvious seed was classified before it reached the
  branch), and `diff` COALESCED the exempt line and the offending line into one
  hunk, so an exemption keyed on the first swallowed the second.
- **When a guard flips no verdict, arm it on COST — and the signal is the first
  observable that guard actually gates.** Some guards are fast paths: deleting
  them changes no decision, so a verdict-flip arm can never fire on one, and
  `mechanism-design.md` would have you delete a line that is load-bearing for
  time rather than for behaviour. Give it a subject instead. Measured, on a
  `PreToolUse` gate whose marker check returns before any parsing: the obvious
  signal was `jq`, and it was WRONG — `command -v jq` executes nothing and the
  first real `jq` sat BELOW the guard, so the arm passed against its own mutant.
  `sed` was the first thing past the line that forks. Pick the signal, then let
  the mutant tell you whether you picked it right; an arm that survives deleting
  its own subject is watching the wrong thing.
- **Mutate the file the fixture RESOLVES, which is not always the one you are
  changing.** A fixture that names candidates in both install layouts takes the
  first that exists, and in this repo `core/git-hooks/pre-push` is found before
  `.githooks/pre-push`. Mutating the other copy leaves every arm green, and a
  mutant that killed nothing reads exactly like an arm that cannot fire —
  measured, three in a row, on a change that was in fact correct. `cmp -s` does
  not catch it: the mutation applied cleanly, to a file the run never loaded.
  Print the resolved path, or assert the kill count is non-zero.
