# check-23-draft-stamps — adversarial fixture

Proves `scripts/validate-draft-stamps.sh` (gate-validation Check 23) actually
fails on an unstamped analyst-draft write path, and does not fire on the things
that merely look like one.

## Run

```sh
tests/fixtures/check-23-draft-stamps/run.sh
```

Exit 0 iff all four seeded trees get the correct verdict.

## The four cases

| tree | what it is | expected |
|---|---|---|
| `bad-disk` | An unstamped draft sitting in `planning-artifacts/`. Whatever wrote it destroyed the prior sprint's draft. | **FAIL** |
| `bad-layer` | Core is correct — the draft on disk *is* stamped — but a `kind: step-domain` extension restates Section 0 with the unstamped write path. | **FAIL** |
| `good` | Stamped draft on disk, and a layer that restates the *stamped* path. | PASS |
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

The validator therefore anchors every match on the full
`_bmad-output/planning-artifacts/` path prefix, never on a basename, and scopes
itself to exactly the four per-sprint drafts. A linter that errors on first
contact gets disabled, and then catches nothing.

## Scope

In: `carry-over-evaluation`, `discovery-context`, `research-notes`,
`architecture-context` — the four drafts that are written per sprint, read by
nothing, and have no archive pair, so an unstamped overwrite is unrecoverable
outside git.

Out: the three onboarding artifacts and `bug-analysis` (see above).
