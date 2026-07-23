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

B and C both fail fast, so the wall-clock cost is A alone.

## Run it

    ./run.sh

Verified non-vacuous against the real defect, not only against the mutant: with
`core/scripts/validate-h2-attestation.sh` reverted to its v0.138.0 form, assertion A goes
red with the consumer's verbatim error while D, B and C stay green.

The environment is scrubbed of `AI_DLC_*` and `CLAUDE_PROJECT_DIR` at the top. The script
under test reads `CLAUDE_PROJECT_DIR` directly; left set, the fixture would silently test
the real repo — where `core/scripts/` exists and the bug cannot reproduce.
