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
13. **No row depends on the rotation archive** — the same rotated live ledger is classified
    with its archive present and with it deleted, and the output must be byte-identical and
    carry the unattributed `NAMED-UPSTREAM-AMBIGUOUS` row. A mutant whose prefix row is gated
    on an open-union-archive count loses that row when the archive is deleted.

## Why the acceptance test is the row set and not the bytes

The row set — status and subject — is what the classifier SAYS about which work, and a swept
entry cannot hide behind a duplicate in it the way it can behind a row count. The detail column
carries a count of OPEN live entries, which a correct ANNOTATE moves; the bytes across the
rotation alone are asserted separately, and there nothing may move.

`ledger-reverify.sh` reads the open entries of the live ledger and nothing else. It never opens
the rotation archive, a closed entry emits no row and is counted nowhere, and a bare-prefix
citation gets one `NAMED-UPSTREAM-AMBIGUOUS` row attributed to no entry, whatever the count. A
rotation moves only closed entries, so it can move neither a row nor a byte. That is the
operator's rule: a reader's rows must be the same with all sprint history deleted.

It used to read history. The prefix was counted over the open entries unioned with the archived
labels, and a count of one handed the row to a prefix fallback as a single attribution. An entry
annotated in the same pass was on neither side while it sat in the live file and on the archive
side once moved, so the count **dipped** at the annotate and **returned** at the rotate. On a
two-member prefix with one member annotated that crossed one-vs-many and the surviving sibling's
row flipped between `NAMED-UPSTREAM <slug>` and `NAMED-UPSTREAM-AMBIGUOUS <prefix>` across a
rotation that swept nothing. The reference consumer reported that shape from its own ledger with
89 rows either side. Assertion 4c seeds the two-member `PC-S910` pair and asserts the row set
holds across all three states; its mutant gates the prefix row on the open-union-archive count
again and shows the flip.

The seed carries a `PC-S900` trio — two open entries and one closed in the same pass — so the
AMBIGUOUS row has a subject and its count (2, the open members) has a value to assert on both
sides of the move. Before that trio existed the ledger held no id of that shape at all, so the
row this assertion is about could not be produced no matter what the code under test did, and
the assertion was decorative rather than merely unseeded.

## Notes for future edits

The entry-boundary rules are lifted from `ledger-reverify.sh`'s parser unchanged: an entry is
a top-level `- **…**` bullet or a `##`–`######` heading, and either one ends the entry above
it. If that parser changes, this must change with it — they are one definition in two places
and only the fixture joins them.

`awk`'s `>` truncates per target on first write, so the split appends (`>>`) into
pre-created files. Getting that wrong drops every entry but the last, and the line-accounting
guard is what turns that into a refusal instead of silent data loss.
