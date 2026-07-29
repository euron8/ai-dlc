# sprint-status-lifecycle

Proves `scripts/ai-dlc/sprint-status.sh` derives `sprint_id` mechanically and rotates the sprint envelope
atomically, and that neither can repeat the two defects this fixture is named after.

## The defect this exists to catch

`sprint_id` — the pipeline's sprint identity — had no mechanical source. `route.md` Step 6 carried
~25 lines of prose the model executed by hand ("mechanically derived" there meant *by rule*, not
*by code*), with four rules:

1. file absent → `1`
2. `status: done` → `N+1`
3. `status:` anything else → `N`
4. the two copies disagree → HARD_BLOCK

**None of them match a canonical that exists but carries no `sprint:` key** — which is exactly the
state a rotate-at-close leaves behind. The likeliest reading of the prose in that state is rule 1,
"greenfield → 1". Rule 24 stamps every analyst-draft write path with `sprint_id`, so resolving 1 on
a live project restamps its drafts from sprint 1 and, in route.md's own words, "silently destroys
the prior sprint's draft, which is the exact defect the stamp exists to prevent."

Assertion 4 is that case. It asserts the resolved value is `max(frozen archives) + 1`, and asserts
separately that it is **not** `1` — the second assertion exists so the failure names the defect
rather than just a wrong number.

## The grammar collision (assertions 8 and 9)

The reference consumer's own rotation tool matches sprint blocks with
`^sprint[_-]([0-9]+)(?:[_-][A-Za-z0-9][A-Za-z0-9_-]*)?:`. Against the real corpus that regex:

- matches **zero** lines of the live canonical (a scalar-header document: `sprint: 291`), so
  `--close-sweep` silently no-ops and **exits 0 reporting success** — verified by running it; and
- **does** match `sprint_291_housekeeping:`, yielding `291`.

So the moment a housekeeping block exists — the block `validate-mandatory-rules.sh` Check 3
*requires* — the tool mistakes it for the sprint envelope, deletes the closure evidence, and leaves
the rows un-pruned. Assertions 8 and 9 are the regression lock on both halves: a housekeeping block
alone must not read as a sprint, and a canonical carrying one must still derive `N+1`.

## Why rotation is at START, not at close

`sprint-id` must be able to read the closed sprint's `status: done`. A rotate-at-close prunes that
block before the successor exists, so the number has nowhere to come from and the roll-forward falls
to whoever remembers to do it by hand. Freezing and rolling in one step at pipeline start keeps the
predecessor's terminal state readable exactly until its successor exists.

## Proving it can fail

A green fixture proves nothing on its own. Both mutants below drive it RED:

| mutation | assertions that fire |
|---|---|
| preamble-only branch returns `1` instead of `max_frozen + 1` | 4 (both legs) |
| `sprint_re` widened to the reference tool's colliding pattern | 8 |

## Part 2 — Check 5, and the count that is part of its contract

`gate-validation.md` Check 5 ("Story status consistency?") says *"Run: Read both files, compare
status values programmatically"*. Core shipped no program: `enforcement-map.yaml` carried
`enforcer: []` for it, so the comparison was performed by hand at every gate while `dev.md`,
`qa.md`, `code-reviewer.md`, `implementation.md` and `retro.md` all restated the duty.

The reference consumer wrote the executable core described — three times — and **each version went
vacuously green at least once**: one globbed `story-<N>-*` at a corpus named `story-S<N>-*` and
printed *"checked 0 story files"* beside its success line; one compared zero derivable fields for a
whole sprint and reported clean; one read a `**Status:**` block its story files no longer carried.

So the battery asserts the **counts and the states**, not only the verdict, and `check-stories`
gives "compared nothing" its own exit code (`4`) rather than folding it into `0`.

Every Part-2 assertion is driven from one function, so the same battery runs against a mutated
**copy** of the tool. A mutant is accepted only when it fails **exactly** its own assertion.

| mutation | assertion that fires |
|---|---|
| "compared nothing" returns `0` | A16 |
| an empty `stories:` block is reported as a finding | A17 |
| the mismatch comparison is disabled | A14 |
| the `**Status:**` body-header reader is removed | A15 |
| a keyless (`- id:`) block is reported as empty | A18 |
| an unresolvable entry is skipped silently | A19 |
| duplicate-key detection is removed | A20 |
| the cross-view comparison is dropped | A21 |
| the id glob is widened to `<id>*` | A22 |

The **unmutated control copy** earned its place on the first run: A21's setup was wrong, so A21
failed on the shipping tool, and eight of the nine mutants reported "entangled" for a reason that
had nothing to do with their mutation — while the A21 mutant itself came back green.

## Assertions

0. `--render` is non-empty and deterministic
1. greenfield (no canonical) → `1`
2. `status: done` → `N+1`
3. in-flight → `N` (a re-plan, not a new sprint)
4. **preamble-only → `max_frozen + 1`, never `1`** — the case the prose has no rule for
5. copies disagree → exit 3 HARD_BLOCK
6. `roll` freezes byte-faithfully, writes the new envelope, and round-trips
7. `roll` is idempotent — a re-run neither re-freezes nor destroys the archive
8. `roll` creates the canonical on greenfield, and mints **no** second copy
9. **MUTANT:** a housekeeping block alone is not parsed as a sprint envelope
10. **MUTANT:** a canonical *with* housekeeping still derives `N+1`
11. `roll` refuses an unclosed sprint (exit 3) — never freezes live state
12. fail-closed on an unreadable schema — never guesses the grammar

### Part 2 (`check-stories`)

13. a consistent tree PASSES **and reports the comparison count**
14. a status mismatch is reported, not absorbed
15. a story file with no frontmatter is read through its `**Status:**` header and **counted**
16. **the vacuity floor** — no `stories:` key compares nothing, and that is exit `4`, never `0`
17. an *empty* `stories:` block is what `roll` writes, so it is not a finding
18. the `- id:` LIST form is a finding — the shape one consumer ran a whole sprint on
19. an entry naming a story file that is not there is a finding, never a skip
20. two entries under one id are reported
21. the two canonical copies disagreeing on a story is reported
22. `story-291-1` never resolves to `story-291-10-…`
