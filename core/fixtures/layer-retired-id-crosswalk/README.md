# layer-retired-id-crosswalk — adversarial fixture

Proves **LC-N6 / E16**: an id that has left the rendered rulebook carries a crosswalk row
resolving it, and the arm refuses rather than guessing when it cannot read the history.

## Why this exists

LC-N5's partition requires a consumer to rename every id it allocated from core's range
into the reserved band. On the reference consumer that is **49 ids across 13 files**. Every
one of those renames leaves behind a bare `Check N` / `Rule N` already written into a gate
log, retro or escalation — and a gate log is the durable audit record, so no rename reaches
back into it. The crosswalk row is the only thing that keeps the citation resolvable.

Core does **not** check the table against the consumer's evidence and does not claim to: it
cannot see which ids a consumer has ever cited, and a clause core cannot evaluate is a rule
with no mechanism behind it (I37). What core *can* see is an id leaving the rulebook, read
from the consumer's own git history. That is exactly what E16 enforces, and it covers every
rename the migration itself creates.

## The distinction the seed exists to pin

The first cut of this arm asked *"did an id leave THIS entry"* and reported **32** subjects
on the reference consumer, **25 of them wrong**. Every wrong one was an entry that had
stopped **restating** a core section — `retro-domain.md` alone carried twenty of core's own
retro step ids. Nothing was retired there: a gate log citing `Step 7a` still resolves, to
core's `7a`, which is where it always pointed.

So the subject is not "left this file" but "left the **rendered rulebook**" — core plus
every entry hooking it. That is a narrowing of the subject set and **not** an exclusion from
the partition: an id core defines is resolvable *because* core is the source of truth for
it. LC-N5's arms are what keep the consumer off it in the first place.

| seeded id | what the migration did to it | must report |
|---|---|---|
| `33` | renamed to `934`; defined nowhere now | **ERROR** — no crosswalk row |
| `34` | moved to a **sibling** entry hooking the same core file | silent — the catalog still defines it |
| `5` | dropped from the entry, but **core** defines `5` | silent — core is the source of truth |
| `933` | never retired | silent — the liveness control |

`933` is load-bearing: without it, an arm that reported *every historical id* would satisfy
the first row and look correct.

## The zero guard

An unreadable id history and a clean one produce the same empty retired-set, which is this
arm's PASS — the repo's named defect class exactly. So the arm refuses, names the entries it
did not judge, and counts them, in three cases: no git work tree, a **shallow** clone (whose
history is truncated at the graft boundary), and a tracked entry whose diff history yields
none of the ids it currently defines.

Part 3 drives a real `--depth 1` clone. Part 4's M3 forces the shallow probe to `ok` and
requires the truncated tree to then report **clean** — which is the state the guard exists
to make impossible.

## Mutants

Four, each scored on the **complete expected vector** rather than per row, because three of
the four cells are occupied by more than one arm and per-row scoring would report
entanglement on every mutant. An unmutated control copy runs first: every assertion is
"this cell moved", and a copy that dies on startup moves every cell at once.

One mutant is recorded here because it was wrong first: M3 originally knocked out the
**per-file** guard and the shallow tree still refused, because two different branches
produce a refusal and only one is reachable on a shallow clone. A mutant that fails to move
its cell is telling you the arm it named is not the arm under test.

## Run

```sh
tests/fixtures/layer-retired-id-crosswalk/run.sh
```

Exit 0 = every assertion holds. Non-zero = the arm, its subject set, or its guard regressed.
