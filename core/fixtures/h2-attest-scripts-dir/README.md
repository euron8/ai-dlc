# h2-attest-scripts-dir

`validate-h2-attestation.sh --attest` must drive its fixture from an **installed
consumer layout** — core validators at `scripts/ai-dlc/`, bare `scripts/` holding only
consumer-authored tooling, fixtures at `tests/fixtures/`.

## The defect

Every release through v0.138.0 derived the validator directory before shelling out:

```bash
SCRIPTS_DIR="$PROJECT_DIR/scripts"
[ -f "$SCRIPTS_DIR/validate-provenance-block.sh" ] || SCRIPTS_DIR="$PROJECT_DIR/core/scripts"
...
bash "$RUN" --scripts "$SCRIPTS_DIR"
```

Two faults, and the second is what made it fatal.

The candidate pair predates the v0.126.0 relocation, so it never names `scripts/ai-dlc/`.
And the fallback is assigned with **no existence test** — "not found" is
indistinguishable from "found at `core/scripts`". That unchecked guess was then
*asserted* to the fixture runner as an explicit `--scripts` override, overriding
`check-17-bypass/run.sh`'s own candidate list, which has included `scripts/ai-dlc/` since
v0.126.0 and was right all along.

In a consumer, `--attest` died on

```
FAIL: cannot locate validate-provenance-block.sh (pass --scripts DIR)
```

while the same fixture, run by hand with no `--scripts`, self-located and passed the full
matrix. H2 could not attest, so the sprint's gate log carried no `H2_ATTESTED` line and
the harness self-test had no mechanical result at all.

Upstream it worked: the distribution has a `scripts/` that holds no validators, so the
fallback fired and landed on `core/scripts` — correct. **The check worked everywhere it
was authored and nowhere it shipped.**

The fix deletes the derivation. `check-17-bypass/run.sh` self-locates, it was the only
consumer of `SCRIPTS_DIR`, and one candidate list cannot go out of sync with itself.
`--scripts DIR` survives as an operator override, forwarded only when supplied.

## Why this is its own fixture

`validator-path-resolution` already enumerates every `core/scripts/*.sh`, including this
one, and is the obvious home. **It cannot host this proof.** To compare layouts it
installs all ~26 validators into *both* `scripts/` and `scripts/ai-dlc/` — and in that
tree the broken derivation finds `$WORK/scripts/validate-provenance-block.sh` and
succeeds. The assertion would be green against the exact bug it was written for.

The proof needs a tree where bare `scripts/` is what a real consumer's is: present,
populated, and holding no core validator. That is this fixture's entire design, and it is
why the decoy consumer script is not decoration. `run.sh` asserts the property directly
and exits 2 if bare `scripts/` ever gains a core validator.

(`validator-path-resolution` never reaches this code by another route either: its default
bare invocation exits at the usage line — the blind spot its own comments name.)

## Assertions

| | |
|---|---|
| **D** | `--digest` resolves `tests/fixtures/` in a consumer and prints 16 hex chars. |
| **A** | `--attest --sprint 999` exits 0 and prints a well-formed `H2_ATTESTED v1` line. The run that failed in every consumer. One full `check-17-bypass` drive — this fixture's only real cost. |
| **B** | *Non-vacuity control.* The same command with `--scripts <nonexistent>` — the exact path the shipped code computed — must FAIL. Without it, A passing would say nothing about whether the drive depends on locating the validators. |
| **C** | *Mutation control.* The pre-v0.139.0 derivation is `sed` back in and must fail with `cannot locate validate-provenance-block.sh`. Guarded by `cmp -s`: a sed that matched nothing is reported as a FAIL, never as a pass. This is the assertion that goes red the day someone re-adds a guessed `SCRIPTS_DIR`. |
| **E** | A table-cell attestation `--verify`s. The motivating case: a consumer pasted the line into the H2 row's Evidence cell and was told the sprint had never attested. |
| **F** | The canonical column-1 attestation still `--verify`s. A widening that breaks it is a regression E cannot see. |
| **G** | A table-cell attestation at a MOVED digest reports **`the fixture set CHANGED`**, not first-gate. Asserts the MESSAGE, because both branches exit 1 and only the message distinguishes them. |
| **H** | Only another sprint's line present reports first-gate — so G's message assertion discriminates rather than matching whatever is printed. |
| **I/J** | `XH2_ATTESTED` and `NOT_H2_ATTESTED` in a cell do NOT verify. The match is token-bounded; without these, a line that *denies* an attestation grants one. |
| **L/M** | A same-sprint, digest-matching span inside a sentence reporting that **the gate FAILED** does NOT verify — from a table cell and from column 1. Both must be LOCATED at `<log>:1` with no PASS and no CHANGED: routing prose to the CHANGED arm still tells an operator the sprint attested and the fixtures moved. |
| **N** | A legitimate cell followed by a **further table column** (`…`. \| 1033 \|`) still verifies. The acquittal L/M buy must not reach the arm's own subject; without N the tail could be anchored on end of line and every other arm would read identically. |
| **O** | `--verify`'s citation is the token **span**, byte-identical from column 1 and from a cell. Asserted as a value, not a length — the matching *line* in a cell is the whole markdown row. |
| **P** | *Placement and verdict.* The reader is one `awk` pass that tracks each table's header. MUST VERIFY: column 1, a `- \`SPAN\`` bullet, a row under a `Result`/`Verdict` header whose verdict cell begins `PASS` (plain, with a trailing numeric column, `**PASS (attested, cite — do not re-drive)**`, and a `[core] H2_ATTESTED` row label). MUST REFUSE, each LOCATED at its exact `<log>:<line>` with the refusal reason, never first-gate and never CHANGED: the defect report's five lines (headerless and under a header), prose before the span in a PASS row's cell, `❌`, `~~…~~`, `<!-- -->`, `> `, a `VOIDED`, `—` or `FAIL` verdict, a headerless row, a header with no verdict column, and a FAIL row at a MOVED digest. Controls: a PASS row at a moved digest reads CHANGED, a log with no span reads first-gate, and a log with an accepted span followed by a refused one at a different `at=` cites the ACCEPTED span. A seventh FAIL line (`` `SPAN` — … FAILED, do not cite ``) is the only adversarial seed the closed lead admits, so it is the one that can see the tail. |
| **K** | *Mutation battery.* Every mutant is a copy with named lines of the subject replaced; each anchor must match EXACTLY ONE line (a self-probe proves zero and many are refused), the copy must differ by `cmp -s` and parse by `bash -n`, or the mutant reports DID NOT APPLY — never KILLED. An unmutated copy in the same place must pass every scored predicate first. A mutant is KILLED only when its owning predicate fails AND its sanity predicates still pass. (a) lead and locating boundary opened — I/J. (b) CHANGED arm held to column 1 — G. (c) tail opened — L/M. (d) a failure vocabulary instead of the header-keyed PASS column — the do-not-re-drive row. (e) column-1-only reader — the header+PASS row. (f) negated-class lead — `❌`. (g) verdict judged on the accepting arm only — the FAIL row at a moved digest. (h) citation cut from the last span in the log — the citation arm. (m1) locator keyed on the live digest — moved bullet. (m2) locator deleted — live bullet. (m3) tail backtick-then-anything — the seventh FAIL line. (m4) locator hoisted above the accepting verdict — order arm. (m5) unconditional locator — empty log. (m6) first quoted line named — two bullets. (m7) remedy line deleted — remedy arm. |

B, C, E–P and K all fail fast, so the wall-clock cost is A alone.

## Why the reader arms live here

A and C assert the **emitter**, whose output is undecorated by construction, and are
structurally blind to the **reader**. The `H2_ATTESTED` line is transcribed by hand into a
markdown gate log, so what `--verify` receives is not what `--attest` printed. E–O drive
`--verify` through the consumer tree this fixture has already built, at the digest D already
resolved, which is why they add assertions without adding a drive.

L, M and N are the half that makes a widened reader safe rather than merely wider. A gate
log's own narrative QUOTES the line it complains about, at the same sprint and the same
digest, so a reader bounded only at the front grants an attestation to a report that the gate
failed — a false PASS on a check nobody drove, which is worse than the false RE-DRIVE being
fixed. N keeps that acquittal off the fixture's own subject.

## Run it

    ./run.sh

Verified non-vacuous against the real defect, not only against the mutant: with
`core/scripts/validate-h2-attestation.sh` reverted to its v0.138.0 form, assertion A goes
red with the consumer's verbatim error while D, B and C stay green.

The environment is scrubbed of `AI_DLC_*` and `CLAUDE_PROJECT_DIR` at the top. The script
under test reads `CLAUDE_PROJECT_DIR` directly; left set, the fixture would silently test
the real repo — where `core/scripts/` exists and the bug cannot reproduce.
