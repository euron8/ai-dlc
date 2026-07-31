# layer-reference-resolution — adversarial fixture

Covers **LC-R2 / `W7`** (a `Check <n>` citation that resolves nowhere) and the **form
`E15` states its remedy in**.

Both defects were found by *running* the band migration against the reference consumer,
not by reading the code. Neither is reachable from core's own tree: core has no consumer
whose ids it can renumber.

## What it asserts

`LC-N5` renumbers an allocation. It does not touch the prose that cites the old id, and
until `W7` nothing joined the two — the reference consumer's migration orphaned three
`Check 19b` citations across three files, one of them a group heading `## Check 19b`
sitting directly above the `### 919b.` that replaced it. The step-reference clause
(**LC-R1**) caught none of them: its grammar is `Step`, and a check id is not a step id.

*(That clause's code is deliberately not spelled out here. This fixture asserts nothing
about it, and **I65** reads a code named anywhere in a fixture directory that is not a
shell comment as proof the clause is exercised — a `.md` has no comment syntax, so an
explanatory mention would file LC-R1's gap as closed when nothing tests it.)*

The four silent cases are the fixture. An arm that reports the three real subjects and
also reports any of these has not passed:

| citation | why it must stay silent |
|---|---|
| `Check 34` | a crosswalk row in **bare** form resolves it |
| `Check 12` | a crosswalk row in **namespaced** form resolves it |
| `Check 7` | core still defines it — core is the source of truth for its own range |
| `Check A`, `Check N` | placeholders in a worked example; no id, so no remedy |

The remedy-form half asserts **applicability**, not that the message changed: the string
`E15` emits for a subject is present in the file it is emitted about. `defined_anchors`
strips the terminator so ids compare as ids, and the remedy re-attached a `.` to every
one — but two of the reference consumer's 39 section-id subjects carry `—` instead
(`## Check AP — …`), so for those the remedy named a string that occurs nowhere. A
pattern built from it matches nothing, the id stays out of band, and the edit count still
reads right.

## Structure

- `seed.sh` — a consumer **mid-migration**: some ids renamed into the band, some not,
  with a crosswalk carrying its two rows in both accepted forms. It is a git repo,
  because a consumer is one and a seed that is not makes `E16` refuse.
- `run.sh` — 14 assertions: 3 premises read without the code under test, the pristine
  vector, 2 applicability arms, the crosswalk row proven load-bearing by removing it, the
  migration **exit condition**, 5 mutants and 1 unmutated control.

Mutants are copies guarded by `cmp -s`, scored as a complete vector so that a mutant
moving two cells reports entanglement rather than a kill.

**The first cut of this fixture seeded only the bare crosswalk row**, so the mutant
deleting the namespaced branch changed a line, passed `cmp -s`, and proved nothing. Two
rows, two mutants, one cell each.

## Run

```
core/fixtures/layer-reference-resolution/run.sh
tests/fixtures/layer-reference-resolution/run.sh    # installed layout
```

Exit 0 = every assertion holds; 1 = a regression; 2 = the fixture itself is broken.
