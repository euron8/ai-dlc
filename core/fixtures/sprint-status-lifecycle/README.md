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

Assertion 4 is that case, stated as a property: the answer with frozen archives present equals the
answer with every archive deleted, for six canonical states, and each row also asserts its expected
value so two agreeing wrong answers cannot pass. A canonical that exists with no `sprint:` key
refuses (exit 1, empty stdout, stderr names the file) rather than resolving to `1` or to
`max(frozen archives) + 1`. Assertion 4d is the control: a copy of the tool carrying the pre-change
behaviour must fail the same table.

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
| degenerate (no `sprint:` key) branch returns `max_frozen + 1` / `1` instead of refusing (committed as control arm 4d) | 4 and 4d |
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
4. **the property: the answer with archives equals the answer with every archive deleted**, for six canonical states; a canonical that exists with no `sprint:` key REFUSES (exit 1, nothing on stdout, stderr names the file), never `1` and never `max_frozen + 1` (4d is the control: the pre-change behaviour fails the same table)
5. copies disagree → exit 3 HARD_BLOCK
6. `roll` freezes byte-faithfully, writes the new envelope, and round-trips
7. `roll` is idempotent — a re-run neither re-freezes nor destroys the archive
8. `roll` creates the canonical on greenfield, and mints **no** second copy
9. **MUTANT:** a housekeeping block alone is not parsed as a sprint envelope
10. **MUTANT:** a canonical *with* housekeeping still derives `N+1`
11. `roll` refuses an unclosed sprint (exit 3) — never freezes live state
12. fail-closed on an unreadable schema — never guesses the grammar

### Part 1b (BL-938: a BMAD copy in the freeze slot, and `roll` decides before it writes)

Each world runs one `roll --sprint 322`; a "no write" arm compares a path+mode+md5 listing of the
whole `_bmad-output` before and after. `receipt-bl938.sh` reads what R12, R14, R16 and R23 left.

- R12 / R12i — a BMAD copy (the real producer's bytes, trimmed) in the planning / implementation slot is relocated to `s321/bmad-sprint-status.yaml` and the real freeze lands in the slot
- R12e — the inline-empty `development_status: {}` form (a hand-written / foreign-tool shape) is a BMAD copy too
- R12crlf — a CRLF copy at mode 0640 keeps its bytes and mode
- R12leg — beside an identical legacy freeze the copy is relocated and nothing is written into the slot
- R13 / R13b — a slot file with both keys, and a housekeeping-first file with neither, refuse exit 3 with nothing written
- R14 / R15 — a divergent planning freeze, and planning `in_progress`, refuse exit 3 with nothing written
- R16 — the half-rolled tree is completed by one re-run, and `sprint-id` answers 322
- R17 / R20 — a differing relocation target refuses with nothing written; an identical one is kept
- R18 — a BMAD implementation slot beside an unclosed planning view is not moved before the refusal
- R19 — both slots divergent: one refusal names both paths
- R21 / R22 / R23 — a view ahead of the target, views that disagree, and a preamble-only view beside one still to roll each refuse (3, 3, 1) with nothing written
- R22b — a view at the target beside one two sprints behind is not a half-roll: rule 5 refuses exit 3 naming both, nothing written
- R24 — a BMAD relocation target that is a directory refuses exit 3 in phase 1, nothing written
- R24s — a freeze slot `s321/sprint-status.yaml` that is a directory refuses exit 3 in phase 1, nothing written
- R24p — a slot parent `s321` that is a regular file refuses exit 3 in phase 1, nothing written

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
