# Where an AI/DLC finding goes

A finding about AI/DLC's own machinery goes UPSTREAM, as a push candidate. A finding about this
project's product, artifacts or content stays here, as a carry-over item. Routing one the wrong
way does not lose the finding — it loses the fix.

## The test

**Is the thing that must change a file AI/DLC installs?** Do not judge this by eye; ask the
tool that owns the answer:

```
scripts/ai-dlc/core-paths.sh --is-core <path>     # exit 0 = AI/DLC's, exit 1 = yours
```

Exit 0 means the next `/ai-dlc-update` overwrites that file, so a local edit to it is erased and
no upstream reader ever sees the defect. Exit 1 means it is yours to change and upstream cannot.

Your `overrides/` and `extensions/` entries are YOURS — `--is-core` returns 1 for them. They are
the supported way to change AI/DLC's behaviour here without editing AI/DLC's files.

## Where each one goes

| Verdict | File | Id |
|---|---|---|
| AI/DLC's own machinery | `_bmad-output/ai-dlc-update/push-candidate-ledger.md` | `PC-S<N>-<SLUG>` |
| This project's own work | `_bmad-output/planning-artifacts/carry-over-backlog.md` | `CO-S<N>-<SLUG>` |

**File the push candidate by default, and file a carry-over item IN ADDITION only when local work
remains** — a workaround you are applying now and must remove once the fix arrives. That second
item's subject is the workaround's removal, not the defect; the defect's record is the push
candidate. Cross-reference the two by id.

**Never file a machinery defect as a carry-over item alone.** The carry-over backlog is work this
project owes itself, and a defect in AI/DLC is work this project cannot do.

## Never edit AI/DLC's files to fix an AI/DLC defect

Editing the distribution's checkout directly, or editing an installed file in place, puts the fix
somewhere no review reaches and no pull preserves. If the defect blocks you now, the unblock is an
`overrides/` or `extensions/` entry plus a carry-over item to remove it — and the push candidate
still gets filed.

## What a push candidate must carry

State the defect against the INSTALLED file, name the path, and give the derivation that shows it
— the command you ran and its output, with a control in the same run that comes back non-zero. An
entry that names a file without a derivation is a hypothesis, and the base rate of expired
premises in that ledger is roughly one in two.

## The detector

`scripts/ai-dlc/audit-upstream-routing.sh` reports carry-over entries that name AI/DLC machinery
and cite no `PC-` id. It is REPORT-ONLY and exits 0 with findings, because routing is a judgement:
an entry may legitimately be your work that merely USES an AI/DLC tool. Read each before refiling.
Its measured false-positive set is enumerated in its own header.
