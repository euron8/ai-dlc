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

The row set — status and subject — is what the classifier SAYS about which work, and a swept
entry cannot hide behind a duplicate in it the way it can behind a row count. The bytes are
stricter than the invariant needs, and until the counter was corrected they false-failed on
the workflow the skill prescribes — annotate, then rotate, in one pass.

`prefix_entry_count()` in `ledger-reverify.sh` now counts a sprint prefix over the **corpus** —
every entry line in both files, open or closed — so annotating moves nothing between the files
and rotating moves one entry from one to the other, and the count is the same on both sides of
either step. It used to count the OPEN entries unioned with the archived labels, and the open
extractor skips any entry carrying `ADOPTED UPSTREAM`: an entry annotated in the same pass was
on neither side while it sat in the live file and on the archive side once moved, so the count
**dipped** at the annotate and **returned** at the rotate. On the `PC-S900` trio that was a
count of 2 before the move and 3 after, printed inside the `NAMED-UPSTREAM-AMBIGUOUS` detail —
a changed line on an identical row. On a two-member prefix with one member annotated, it was
a count of **1** before the move and 2 after, which crosses the threshold between
`named_absorbed()`'s single attribution and `named_ambiguous()` — the surviving sibling's row
flips `NAMED-UPSTREAM <slug>` to `NAMED-UPSTREAM-AMBIGUOUS <prefix>` across a rotation that
swept nothing, and that IS a changed row set. The reference consumer reported that shape from
its own ledger with 89 rows either side. Assertion 4c seeds the two-member `PC-S910` pair and
asserts the row set holds across all three states; its mutant reverts the counter to the
open-union-archive body and shows the flip.

The archive arm of the counter is not the defect: without it the count is anti-monotonic and
converts a correct ambiguity into a confidently wrong attribution. The corpus count is that
fix carried one step further — strictly fewer attributions, never more.

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
