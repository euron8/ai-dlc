# spec-join-integrity

Drives `validate-spec-join.sh` (gate-validation Check 30).

The chain `LOCKED_REQUIREMENTS -> CAP-N -> FR-<n> -> story AC -> test` had
hand-typed prose arrows in its middle joins. BMAD supplies the stable IDs
(`bmad-spec` guarantees `CAP-N` is never reused; `bmad-architecture` gives `AD-n`;
`bmad-create-epics-and-stories` emits the `FR Coverage Map`) and none of them
fails a gate — `lint_spine.py` exits 0 by design and leaves the decision to its
caller. Check 30 is that caller.

Payloads are synthetic and minimal. Each red case isolates exactly one join so a
FAIL cannot be produced by a neighbouring one.
