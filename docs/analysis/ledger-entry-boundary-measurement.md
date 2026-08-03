# The ledger entry-boundary rule — measured, NOT fixed

**Status: MEASURED, NOT FIXED.** Reported as
`PC-S313-LEDGER-ROTATE-SPLITS-AN-ENTRY-AT-A-BOLD-ANNOTATION`. The report is correct and the
consequence is destructive. The fix is withheld because the obvious discriminators do not
survive measurement, and shipping a boundary rule with an unmeasured false-positive set is
how this defect class keeps producing another release.

## The defect

`ledger_entry_shape()` in `reconcile/lib.sh` is THE entry-boundary rule, shared by
`ledger-reverify.sh` and `ledger-rotate.sh`:

```awk
if (l ~ /^- \*\*/)      return "bullet"
if (l ~ /^#{2,6}[ \t]/) return "heading"
```

Any line starting `- **` opens an entry. A **bulleted line whose text begins in bold**,
inside an entry, is therefore read as a new entry. In `ledger-reverify.sh` that mislabels;
in `ledger-rotate.sh` it **physically splits the file** — the head goes to the archive and
the tail, including the `verify:` receipt, is stranded in the live ledger under no heading.

Observed on `PC-S296-WHOLE-READ-POOL`: the archived copy ended mid-sentence and the
derivation, both arguments and the receipt were 170 lines below an unrelated entry in the
live file. A previous run had worked around the symptom by DUPLICATING the
`ADOPTED UPSTREAM` annotation into the orphaned fragment so the receipt would find one —
the tell that the split was already doing damage nobody had traced to the rotator.

## Why the obvious fixes fail, with numbers

Measured against the reference consumer's live ledger (73 `PC-` entries, 3,200+ lines):

| | count |
|---|---|
| lines matching the current boundary | **123** |
| of those, naming a `PC-` id | 73 |
| **matching but naming no `PC-` id** | **49** (33 `- **`, 13 `##`, 3 `###`) |

**Requiring a `PC-` id is not safe.** Some of those 49 are REAL entries in an older,
id-less format, grouped under `## Open — filed <date>` headings — e.g.
`` - **`validate-ci-gates.sh` → repoint the dormant-gate scan…** ``. Tightening the rule to
`^- \*\*PC-` would make the rotator stop seeing every legacy entry, which is a worse
failure than the split: it would silently never archive them.

**Requiring a `verify:` receipt within the entry is not safe either.** Legacy entries
predate the receipt convention and carry none. The probe returns "annotation" for line 78,
which is a genuine entry.

So the two cheap discriminators each have a non-empty false-negative set on the real corpus,
and a false negative here means an entry the rotator cannot see.

## What a real fix has to establish first

1. **Enumerate the legitimate entry shapes** across the live ledger AND the archive — the
   archive is where the older formats live, and a rule that only fits the live file will
   strand them at the next rotation.
2. **Decide whether a bulleted-bold line can be disambiguated at all**, or whether the
   ledger format needs an explicit terminator (`---` already separates most entries — measure
   whether it separates ALL of them, because if it does, the boundary is the separator and
   not the heading shape).
3. **Measure the candidate rule in both directions** on that corpus: entries it stops seeing
   (false negatives, the dangerous side) and annotations it still splits at.
4. **Fix `lib.sh` once.** The rule is already single-homed there and the header records that
   it had drifted before; both readers must move together.

## The consumer-side workaround now in place

The two halves were rejoined and the offending bold dropped. That is per-file and
hand-maintained, which is why the guard belongs in the tool.

## Related, and FIXED in v0.249.0

`PC-S313-LEDGER-REVERIFY-SH-VERB-READS-A-MISSING-FILE-AS-A-FIX` — the `sh` verb read exit
127 (missing subject) as "no longer reproduces" and emitted CLOSE-CANDIDATE. One relocation
commit flipped five entries at once, every one still reproducing at its new path. Now
126/127 emit `NEEDS-REVIEW: unresolved`, symmetric with the `theirs_*` verbs, and every
other non-zero status still closes but carries a warning that a status cannot distinguish
"fixed" from "subject moved" inside an `&&` chain.
