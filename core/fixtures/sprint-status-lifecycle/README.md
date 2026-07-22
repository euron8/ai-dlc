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
