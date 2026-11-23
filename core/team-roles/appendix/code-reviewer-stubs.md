# Code Reviewer appendix: stubs in the execution path

### Stubs in Execution Path = Critical

A stub marker (`stub`, `TODO`, `FIXME`, `wired later`, `Phase N`,
`NotImplementedError`) in a hot-path file (`.py`, `.ts`, `.tsx`, `.js`,
`.sh`, `.sql`, `.github/workflows/**.yml`) is a **Critical** finding
UNLESS the stub's surrounding comment block satisfies ALL FOUR
elements enforced by `gate-validation.md` Check 16:

1. Numbered carry-over item reference — regex `Item [0-9]+`.
2. OPEN or IN-SPRINT status in
   `_bmad-output/planning-artifacts/carry-over-backlog.md` for that
   item (regex `^- Item [0-9]+.*(OPEN|IN SPRINT [0-9]+)`).
3. `file:line` reference — regex `(^|\s)\S+:[0-9]+(\s|$)`.
4. `deferral-reason:` line matching `^deferral-reason:\s+\S.{19,}`
   AND reason body has ≥10 non-whitespace characters.

"Will add in follow-up" with no item reference, deferral-reason `TBD`,
or a CLOSED item reference → **Critical**, not deferrable. Reviewer's
only valid responses: (a) APPROVED if all four elements are present
and verifiable; (b) NEEDS_REWORK naming the missing element(s).
