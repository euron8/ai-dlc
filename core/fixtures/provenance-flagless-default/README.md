# provenance-flagless-default

`validate-provenance-block.sh` handed an ordinary artifact carrying no
`SKILL_INVOCATION_PROVENANCE` block, with no flag, printed
`OK: no provenance block required or present` and exited 0. The flagless caller had already
decided the artifact was in scope, so that answer put the burden of remembering a flag on
every gate: a call site that forgot one got a pass over a file nothing had examined, and a
pass over an unexamined file reads exactly like a pass over a clean one.

Absence with no declaration is now a FAIL at exit 1, distinct in MESSAGE from the MALFORMED
verdict and deliberately sharing its exit code. `--allow-missing` is the declaration a call
site makes when it has decided this artifact may legitimately carry none, and it acquits
exactly one rung.

## Arms

Every arm reads the exit code directly off the invocation, never after a pipe.

| Arm | Input | Flag | Expect |
|---|---|---|---|
| f-ctl | `docs/valid.md`, schema-valid block | — | 0 |
| a | `docs/prd.md`, no block | — | 1, stderr names `--allow-missing`, no `MALFORMED`/`CANNOT PARSE` |
| b | `docs/prd.md`, no block | `--allow-missing` | 0 |
| c | `docs/retro/s301/retro.md`, no block | `--allow-missing` | 1 |
| d | `docs/fenced.md`, marker in a ``` fence | `--allow-missing` | 1, as MALFORMED |
| e | `docs/prd.md` | `--allow-missing` + `--require-skill`, both orders | 2 |
| f | `docs/valid.md`, schema-valid block | `--allow-missing` | 0 |
| g | `docs/report.txt`, no block, no `.md` extension | — | 1, stderr names `--allow-missing` |
| h | `docs/solo.md`, block present with `mode: solo` | `--allow-missing` | 1 |

**f-ctl runs FIRST and refuses at exit 2 on failure.** Every arm below it is a statement
about a validator that works; a seed the validator rejects for an unrelated reason would make
the whole file read as agreement.

**Its block is lifted at RUNTIME from `check-17-bypass/seed.sh`'s V2 variant**, not typed
here — this repo's maintained corpus of what the real producer emits, already joined to
`schemas/provenance-block.json` — extended with the `tool_use_id` that variant deliberately
strips and the three `findings_*` counts. A typed copy would be a second author encoding one
understanding twice and would stay green through a change to the schema AND the reader; a
seed derived from the reader's own accept-set proves only that the reader accepts its own
grammar. Lifted, a schema change that breaks V2 breaks this fixture too. The lift and the
extension each refuse at exit 2 if they match nothing.

**Arm (a) reads stderr in BOTH directions and its second half carries a control.** "Does not
carry MALFORMED" is satisfied by a validator that emits nothing at all, so the same grammar is
fired at `docs/fenced.md` in the same run: if it does not match there, the absence in (a) is a
scan that cannot spell its own subject and says nothing.

**(c), (d) and (h) are three arms because the flag has three things it must not acquit.** An
`--allow-missing` that short-circuits the whole reader satisfies any one of them read alone.

## Mutants

Each is a copy of the validator inside its own tree, with `cmp -s` asserting the copy differs.
A mutation that did not apply is FIXTURE BROKEN at exit 2, never a kill. The tree carries the
schema because the validator resolves it by walking up for a marker — a lone copy under
`mktemp` fails closed on "schema not found" and is silent for a reason that has nothing to do
with the mutation.

| Mutant | Edit | Killed by |
|---|---|---|
| M0 | none — the control | (drives the baseline; refuses before any mutant verdict is read) |
| M1 | the flagless-absent rung reverted to `sys.exit(0)` | (a) and (g) |
| M2 | `allow_missing` short-circuits above the retro and MALFORMED rungs | (c), (d) and (h) |
| M3 | deny only when the path ends `.md` | (g) |

**M0's conjunct is positive.** Two inert runs compare equal: a tree where the driven subject
bails at its own startup check makes every mutant "survive" AND the control "pass", because
`rc=1` with nothing printed is what a copy that never ran looks like. M0 requires the deny
message to be THERE.

**M2 and M3 each carry a near-miss conjunct in the same run.** M2 must leave (a) and (g) at 1,
M3 must leave (a) at 1 — a mutant that moved every cell would be M1 again, and the arm it
claims to score would own nothing.

## Layouts

The subject is a SHIPPED validator, so this fixture ships: no `.dist-only`. It resolves the
validator by walking up for its own home — `<root>/core/fixtures/<name>` in the distribution,
`<root>/tests/fixtures/<name>` on a consumer — and names every candidate from that answer
rather than hanging a second derivation off a path some other resolver produced, which is what
I33 fails the build on. With the subject absent in both layouts every arm is named as SKIP; a
silent exit 0 reads exactly like a clean run.
