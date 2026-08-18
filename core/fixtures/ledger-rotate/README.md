# ledger-rotate

Proves `reconcile/ledger-rotate.sh` moves CLOSED push-candidate entries to an archive
without touching open ones, without losing a line, and without changing what the classifier
says about the work that is still open.

## The problem it addresses

The push-candidate ledger is append-only by design: step 8 appends, `ledger-reverify.sh`
never edits, and a close is an **annotation**, never a deletion — the entry is the provenance
of an upstreamed change. Nothing ever moved a closed entry out.

Measured on the reference consumer at v0.147.1: **2830 lines / 220 KB / 50 entries**, grown
1038 → 1820 → 2325 → 2830 across 40 commits, monotonic, never once smaller. Only 39 entries
still classified. The rest are parsed on every pull, rendered into every report, and re-read
by every agent that edits the file, for zero classifier value — and a batch of receipt edits
against a 220 KB file is the slowest step in the whole update.

## Why rotation is stricter than the skip rule

`ledger-reverify.sh` treats an entry as closed on `/ADOPTED UPSTREAM/` anywhere in it. That
is correct for **skipping** — the cost of skipping one extra entry is one unverified row.
It is wrong for **moving**, where the cost is live work filed into an archive nobody re-reads.

The phrase occurs in open entries two ways: as instruction ("annotate `ADOPTED UPSTREAM (vX,
verified <date>)` once the grep is non-zero") and as narrative ("the sentinel ADOPTED
UPSTREAM in v0.135.0, but…"). On the reference consumer there are 47 occurrences, 32 of them
in the annotation form, so **15 are not annotations**. On the loose rule, rotation reported 39
entries to move; on the annotation
form (`**ADOPTED UPSTREAM (v`) it reports 31. Those 8 are live entries the loose rule would
have archived.

The asymmetry is deliberate and is stated in the script header.

## What `run.sh` asserts

1. **Sanity** — the seed really holds closed entries, open entries, and a decoy.
2. **Dry run writes nothing** — the default reports only.
3. **Open entries stay**, in both supported shapes (`## heading` and `- **bullet**`).
4. **The decoy stays** — an open entry that merely quotes or narrates the phrase is not
   closed. This assertion caught a real bug in the first draft of the script.
5. **Closed entries leave the live ledger**, in both shapes.
6. **Closed entries are in the archive** — moved, never deleted.
7. **The preamble stays** — text belonging to no entry is not swept.
8. **No line lost** — live + archive ≥ the original.
9. **The acceptance test** — `ledger-reverify.sh` emits the **same row set, by status and
   subject**, across the rotation. Rotation moves exactly the entries it already skips, so a
   row that appears or disappears means the split took a live entry. This is the assertion
   that matters; the others localise the failure.
10. **Idempotent** — a second `--apply` is a no-op.
11. **The accounting guard is load-bearing** — a mutant with the balance check disabled is
    built, so the guard cannot pass vacuously.
12. **A genuine sweep still fails the row-set test** — a mutated rotator with the version
    digit removed from its close predicate archives a live entry that quotes the annotation
    form, its row disappears, and the comparison in 9 fails. Without this the reshape in 9
    would be a looser assertion with nothing saying so.
13. **The prefix counter survives a rotation** — a mutant with the archive arm of
    `prefix_entry_count()` removed turns a correct `NAMED-UPSTREAM-AMBIGUOUS` row into a
    confident single attribution of the surviving sibling.

## Why the acceptance test is the row set and not the bytes

A byte comparison is wrong for the workflow the skill prescribes — annotate, then rotate, in
one pass. `prefix_entry_count()` in `ledger-reverify.sh` counts a sprint prefix over the OPEN
entries **unioned with the archived labels**, and the open extractor skips any entry carrying
`ADOPTED UPSTREAM`. An entry annotated in the same pass is therefore on neither side while it
sits in the live file, and on the archive side once moved — so the count **rises** across a
move that can only shrink the live set. That number is printed inside
`NAMED-UPSTREAM-AMBIGUOUS` details, so correct work surfaces as changed lines on an identical
row set.

**What holds is the shape, not a pair of totals: the row set does not move, the differing lines
all carry a prefix count, and the count rises.** Re-derive it rather than quoting a number —
run `ledger-reverify.sh` either side of the rotation on the ledger in front of you. Illustrated
by one run, named with its population: annotating every open entry on a copy of the reference
consumer's live ledger, 79 entries, gave 12 rows with an identical set, 2 differing lines, both
of them prefix counts, one of which rose from 3 entries to 5. An earlier run of the same
experiment on a larger ledger reported 84 rows and 10 differing lines. Both are true of their
own corpus and neither is the invariant.

Nothing was swept in either. The byte form hands the operator a false alarm exactly when a
large batch of closes has landed, and the remedy it invites is unwinding correct work. The
counter is not the defect: without its archive arm the count is anti-monotonic and converts a
correct ambiguity into a confidently wrong attribution. The claim was wrong; the code was right.

The seed carries a `PC-S900` trio — two open entries and one closed in the same pass — because
`named_ambiguous()` gates on a `PC-S<n>` prefix shared by two or more entries. Before that
trio existed the ledger held no id of that shape at all, so the row this assertion is about
could not be produced no matter what the code under test did, and the assertion was decorative
rather than merely unseeded.

## Notes for future edits

The entry-boundary rules are lifted from `ledger-reverify.sh`'s parser unchanged: an entry is
a top-level `- **…**` bullet or a `##`–`######` heading, and either one ends the entry above
it. If that parser changes, this must change with it — they are one definition in two places
and only the fixture joins them.

`awk`'s `>` truncates per target on first write, so the split appends (`>>`) into
pre-created files. Getting that wrong drops every entry but the last, and the line-accounting
guard is what turns that into a refusal instead of silent data loss.
