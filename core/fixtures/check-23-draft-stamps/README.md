# check-23-draft-stamps — adversarial fixture

Proves `scripts/ai-dlc/validate-draft-stamps.sh` (gate-validation Check 23) actually
fails on an unstamped per-sprint planning-artifact write path, and does not fire
on the things that merely look like one.

## Run

```sh
tests/fixtures/check-23-draft-stamps/run.sh
```

Exit 0 iff all five seeded trees get the correct verdict.

## The five cases

| tree | what it is | expected |
|---|---|---|
| `bad-disk` | An unstamped draft sitting in `planning-artifacts/`. Whatever wrote it destroyed the prior sprint's draft. | **FAIL** |
| `bad-layer` | Core is correct — the draft on disk *is* stamped — but a `kind: step-domain` extension restates Section 0 with the unstamped write path. | **FAIL** |
| `bad-test-strategy` | An unstamped `test-strategy.md` at the area root, its own H1 naming one sprint (`# S272 Sprint Test Strategy`) while the path claims the durable root. Added v0.324.0. | **FAIL** |
| `good` | Stamped artifacts on disk, and a layer that restates the *stamped* path. | PASS |
| `decoy` | Everything a naive grep would wrongly flag. | PASS |

## Why `bad-layer` is the case that matters

It is not hypothetical. It is the real graph consumer's
`extensions/steps-domain/carry-over-evaluation-domain.md` verbatim: a
`step-domain` layer hooking `steps/carry-over-evaluation.md` re-states that
step's whole Section 0 — **including the output path** — and the layer is what
renders. So a consumer can silently revert the sprint stamp while core looks
perfectly correct, and the only visible symptom is that next sprint's draft
overwrites this one.

This is the v0.34.0 lesson in fixture form: judge layer correctness against the
*rendered* pipeline, not core alone. It is also why the validator's disk half
exists at all — the disk half fires on the rendered **outcome**, so it catches
this even if the layer half's pattern ever misses the restatement.

## Why `decoy` decides whether the script ships

Three separate false-positive traps, all in one tree:

1. **Step-file name collision.** `route.md`'s pipeline table legitimately names
   the *step* `carry-over-evaluation.md`. Every step file's own name collides
   with its artifact's name. A bare-basename grep flags all of them.
2. **One-shot onboarding artifacts.** `codebase-analysis.md`,
   `brownfield-inventory.md`, `doc-reconciliation.md` are written once, are read
   by path downstream (`discovery.md`, `doc-repair-backfill.md`), and have no
   sprint key. They are unstamped **by design**.
3. **`bug-analysis.md`.** Bug-keyed, not sprint-keyed — two bugs in one sprint
   would collide on the same stamp.
4. **A layer entry hooking `steps/stories-test-strategy.md`.** The step file's own
   name contains `test-strategy`, which entered scope at v0.324.0. This trap sits
   in `extensions/`, which the layer half **does** scan — putting it under
   `steps/` instead would make the arm vacuous, since neither half reads that
   directory and it would pass however the matching were written.

The validator therefore anchors every match on the full
`_bmad-output/planning-artifacts/` path prefix, never on a basename, and scopes
itself to exactly the five per-sprint artifacts. A linter that errors on first
contact gets disabled, and then catches nothing.

## Scope

In: `carry-over-evaluation`, `discovery-context`, `research-notes`,
`architecture-context` — the four drafts that are written per sprint, read by
nothing, and have no archive pair, so an unstamped overwrite is unrecoverable
outside git — and `test-strategy`, which is none of those things and belongs
anyway. It is a TEA deliverable, it IS read downstream, and the failure mode is
identical because it does not depend on the producer: one basename, one area
root, one write per sprint, nothing consolidating and nothing rotating.

Out: the three onboarding artifacts and `bug-analysis` (see above).

## Two mutants, and what each proves

- **Revert `DRAFTS` to the pre-v0.324.0 four.** `bad-test-strategy` flips to
  accepted and **nothing else changes** — the arm fails only its own assertion.
- **Make the layer half basename-anchored** instead of path-anchored. `decoy`
  goes red on `hooks: steps/stories-test-strategy.md`, which is what makes trap 4
  load-bearing. `good` goes red too, on `hooks: steps/carry-over-evaluation.md` —
  that pairing predates v0.324.0 and is two independent witnesses of one
  property, not two entangled assertions.

Both are built as `cmp -s`-guarded copies with an unmutated control from the same
directory, so a `sed` that matched nothing cannot pass as a mutation.
