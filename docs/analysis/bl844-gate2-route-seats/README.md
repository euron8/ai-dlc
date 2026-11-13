# BL-844: QA seats per gate-2 re-validation, graph s320 against s321 and s322

`derive.sh` reads graph's committed gate plans, shard dirs and review files and prints, per
gate-2 re-validation (pass M >= 2), the route source and the QA seat count. `out.txt` is its
output at graph `main` c8ab65397. The same run at 1449b5c72 prints the same lines apart from
the ref line. 0 paths under the s320 to s322 artifact and review dirs changed between those
two shas, against 352 paths changed overall.

`derive-g3.sh` joins every story with a gate-3 plan at pass >= 2 to the gate-1 and gate-2
plans that follow each gate-3 rework, ordered by each plan's `sha:` time, ties broken by a review's gate-3 remedy citation, and classes each seat (a) re-run, (b) same-gate re-review or (c) gate-3 remedy (rules in its header).
`out-g3.txt` is its output at c8ab65397, identical at 1449b5c72 apart from the ref line.

Single-seat gate-2 re-validations (route `record-only` or `serial` in the plan) that returned
NEEDS_REWORK. Of the 14 single-seat re-validations in s321 and s322, 2 did. Each row can be
re-derived with `git show main:<review file>` in graph.

| Re-validation | Plan route | Seats | Review file | Catch on record |
|---|---|---|---|---|
| s321 6-1 p2 | record-only | 1 | docs/reviews/s321/6-1-qa-validation-p2.md | Important, Class BOOKKEEPING, first raised at p2: Dev Agent Record judgement calls still list rows 4, 5, 6, 12 as built and tested |
| s321 6-1 p2 | record-only | 1 | docs/reviews/s321/6-1-qa-validation-p2.md | Critical, Class BOOKKEEPING, carried from p1 (its carried line reads open) and re-emitted open by the routed seat, which held the story at NEEDS_REWORK: AC3, citations and negatives that the validator cannot catch |
| s322 4 p3 | serial | 1 | docs/reviews/s322/4-qa-validation-p3.md | Important, Class BOOKKEEPING, first raised at p3 (p2 carried 0 findings): Story evidence sections still state the pre-rework 32-arm harness counts |
