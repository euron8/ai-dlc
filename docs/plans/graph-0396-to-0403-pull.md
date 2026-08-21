# graph consumer pull, 0.396.0 → 0.403.0 — adjudication handoff

**RESUME WITH: `READ and FOLLOW docs/plans/graph-0396-to-0403-pull.md`.** This block is the
current state and replaces anything below it that reads differently.

**State: the distribution half is DONE and merged. What remains is adjudicating ONE incoming
report** from the graph consumer session that is applying this pull. Six releases shipped,
`v0.398.0` through `v0.403.0`, HEAD `895db006`, `VERSION` 0.403.0. Nothing is owed in this repo.
The next actions are in [`## Next actions`](#next-actions); do those and nothing else.

## Start here

Two trees, and the boundary is absolute.

- **This repo, `/Users/n8/git/ai-dlc`** — the distribution. WRITABLE. All six releases are merged
  and pushed here.
- **`/Users/n8/git/graph`** — the consumer. **Read it, never write to it.** An ai-dlc session
  never writes to a consumer, so do not write or edit any path under that tree — not the ledger,
  not the layer, not a fixture. The consumer's own session runs its pull, its gate and its merge.
  Reading its ledger and its stamp in order to adjudicate is the whole of your access there.

The consumer session was briefed and is running `/ai-dlc-update` itself. It has been told the
operator preapproves merges, so it will not stop to ask.

## Next actions

1. **Wait for the consumer session's report.** Find it with `ListAgents` — it was `graph-ce`, and
   these session names change, so match on the `graph-` prefix rather than the exact name. It was
   told to reply using the `from` attribute of my last message, so its report will arrive addressed
   correctly without further action.
2. **Adjudicate the four entries below.** Each is a receipt that v0.402.0 newly reports as
   `NEEDS-REVIEW`, and all four are TRUE POSITIVES — verified, not assumed. Their dispositions
   differ and the difference matters:
   - `PC-S303-FANOUT-SCRIPT-ARG-MAX-VIA-EXPORTED-DIFF-ENV-VAR` — **re-anchor on `$THEIRS`**, do not
     close. Defect unresolved; only its receipt is unobservable.
   - `PC-S314-PRECLASSIFY-BUCKETS-A-MODE-ONLY-CHANGE-AS-UPSTREAM-ONLY-...` — **re-anchor.** Same.
   - `PC-S334-AUDIT-LAYER-DEBT-FLAGS-ITS-OWN-DISCHARGE-ROWS-AS-UNDECLARED-DEBT` — **re-anchor.** Same.
   - `PC-S337-APPLY-DRIFT-REFILE-NO-MAPPER-ARM-IS-NOT-PARALLEL-SAFE` — **CLOSE it by hand as
     ADOPTED UPSTREAM (v0.398.0)**, with a verified date. This one is different: the underlying
     defect IS FIXED in this range, and its receipt is structurally incapable of observing that.
3. **Confirm the nine bucket-2 entries were NOT treated as defects.** Bucket 2 is a
   consumer-side-only receipt whose subject has no upstream counterpart — mostly
   `scripts/ai-dlc-local/**`, which `map_consumer()` maps from nothing. Verdict stays
   `STILL-LIVE`; the detail now says no pull can settle it. That is not a defect.
4. **Confirm the three `STAYS-RETIRED` watchdogs were left untouched** —
   `PC-S312-PROTECTED-CORE-PATHS-STAYS-RETIRED`, `-MUTATION-RED-ANCHOR-STAYS-RETIRED`,
   `-STRAY-SCAN-ARM-STAYS-RETIRED`. Permanent exit 0 is their CORRECT steady state; they flip only
   on a regression. Reading any of the three as a defect is the error to catch here.
5. **Answer the one open question this session could not.** Does the consumer's layer carry an
   override or extension anchored on the `## Two layouts` heading that `v0.401.0` REMOVED from
   `CLAUDE.md`? If it does, expect a drift row, and the disposition is to re-anchor the layer entry
   on `.claude/rules/consumer-boundary.md`, which is where that rule now lives authoritatively
   along with the `I33` citation. Not derivable from this repo — it needs the consumer's layer.
6. **BLOCKED, and stays blocked unless the operator says otherwise:** the `vacuous predicate`
   guard for the `sh` arm, and the subject-missing guard. `v0.403.0` records the measurement that
   both have ZERO live subjects. Do not build either on your own initiative — the operator
   released both items on that evidence.

**Ping the operator on any question, on any decision, and on completion — including an early
stop.** From outside, a session still working and a session stalled on a blocking question look
identical, and every stall in this repo's history ended with the operator asking rather than the
session reporting. Report even when the answer is "nothing needed adjudicating".

## Completed — do not redo any of this

All merged and pushed to `origin/main`. The CHANGELOG entry for each carries its full evidence and
is the authoritative record; this list is an index, not a substitute.

| Release | What | Status |
|---|---|---|
| `v0.398.0` | fixture fix: unescaped dots in `9.9.9` matched the sha the arm itself wrote | COMPLETED |
| `v0.399.0` | `verification-discipline.md` clause on predicted rates, funded by a duplication cut | COMPLETED |
| `v0.400.0` | `release-version-triple` latent dot site; the refuted token-guard design recorded | COMPLETED |
| `v0.401.0` | removed `CLAUDE.md`'s `## Two layouts` duplication; `I33` relocated | COMPLETED |
| `v0.402.0` | the `sh`-arm falsifiability partition | COMPLETED |
| `v0.403.0` | two authorised guards measured and NOT built, both unable to fire | COMPLETED |

## Why the four entries are true positives

A `verify: sh` receipt runs `cd "$CONSUMER"`, and reverify runs BEFORE an apply, so a receipt that
never references `$THEIRS` or `$DIST` reads only the installed copy — frozen at base — and can never
observe a fix. Measured on the consumer: **13 of 41 live `sh` receipts never consult upstream at
all.** Each of the four names a file upstream ships AND has an installed copy byte-identical to the
base blob, so it is demonstrably reading a frozen tree.

`PC-S337` is the sharpest case and the reason step 2 splits. Its receipt keys on
`mktemp -d -p\|TMPDIR=` — the pinning constructs a HYPOTHESISED hermetic fix would have introduced.
The real cause was different and is fixed: `! grep -q "9.9.9" "$STAMP"` where the line above writes
`commit: $BASE` into that same stamp, so unescaped dots matched `9?9?9` inside the sha, in 0.83% of
runs. **Token choice was never the defect** — a perfectly-anchored version of that receipt would be
equally permanently green.

## Citations, all re-derived at `895db006`

- The partition and its three buckets: `core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:1206`
  is the `sh)` case label; the arm's `unfalsifiable predicate:` emissions are at lines 1182, 1183
  and 1309 of the same file.
- The pre-existing guards the partition was modelled on, for the other verbs:
  `core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:1167` and `:1201` carry
  `vacuous predicate:`.
- The limitation to know about before reading any rendered report:
  `core/skills/ai-dlc-update/reconcile/emit-report.sh:251` filters rows to `STILL-LIVE`, so
  **bucket-2 and undecidable DETAIL never reaches the operator's report.** Read the raw TSV by
  running `ledger-reverify.sh` directly.
- The battery: `core/fixtures/ledger-reverify-unfalsifiable/run.sh:213` onward carries the four
  `PC-SH-*` arms, authored blind to the implementation.

## Done when

1. The consumer session's report has been received and answered, and **each of the four entries in
   step 2 has a recorded disposition** — three re-anchored, `PC-S337` closed as ADOPTED UPSTREAM.
2. Steps 3, 4 and 5 answered explicitly, including a plain "no override found" for step 5 if that
   is the truth.
3. The operator has been pinged with the outcome.

**OBSERVATION POINT, and it matters because this run consumes its own subject.** Verify
`PC-S337`'s disposition BEFORE the consumer rotates its ledger. `ledger-rotate.sh` moves closed
entries to `push-candidate-ledger.archive.md`, and a rotated entry emits NO row, so a live
`ledger-reverify.sh` run correctly reads zero for it afterwards and that zero is not evidence the
close did not happen. After a rotation, check
`_bmad-output/ai-dlc-update/push-candidate-ledger.archive.md` instead, and confirm the archive
count moved — a `CLOSE-CANDIDATE` row is not the close.

Criterion 1 is reachable today: the four entries are live in
`_bmad-output/ai-dlc-update/push-candidate-ledger.md` on the consumer and each currently emits a
row. Criterion 2's step 5 may legitimately resolve to "no such override exists", which is a PASS,
not a failure to check.
