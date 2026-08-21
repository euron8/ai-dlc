# graph consumer pull, 0.396.0 → 0.403.0 — adjudication handoff

# DISCHARGED — NOTHING HERE IS WORK TO DO

**This plan is SPENT. Do not execute it.** The consumer applied the pull and merged as PR #954 into
`ai-dlc/feature/rebalance-pct-selector`; its stamp reads 0.403.0 @ `895db006` on both pairs. All six
numbered actions below were carried out and their outcomes are in [`## Outcome`](#outcome). It is
retained as the evidence record for that pull, nothing more.

**THE COMPOSITE GATE EXITED rc=1. DO NOT RECORD THIS PULL AS A CLEAN RUN.** An earlier revision of
this block said the gate went green; that was wrong, and it is the failure this repo already knows —
a fixture tally read as a gate verdict. 155 checks ok, one FAIL: `VERDICT: FAIL — 6 blocking, 3
ambiguous`, six sprint-304 review docs carrying the sprint token in the basename rather than the
reserved `s304/` slot. **Pre-existing and unrelated to this pull**, present before the consumer
touched anything, and still open on their side. Both of their pushes used `--no-verify`, on the
record. Every gate belonging to this pull exited 0 individually — `emit-report.sh --verify`,
`setup-site-drift.sh`, `validate-hook-registration.sh` (18/18), `hard-blockers.sh` at
`0 HARD blockers.` before and after — and all three changed fixtures pass, including the
intermittently-red `apply-drift-refile`. The composite is red on something older than the pull.

**This file is NOT reachable from `895db006`.** It was committed at `7b41c16d`, a docs-only
descendant. `git show 895db006:docs/plans/graph-0396-to-0403-pull.md` fails. Read it at `7b41c16d`
or later. The `path:line` citations in `## Citations` were derived at `895db006` and still hold —
that commit changed no cited file.

Two things it got WRONG are corrected in `## Outcome` — read those before trusting any confirmation
step in the body below.

The distribution half shipped as `v0.398.0` through `v0.403.0`, HEAD `895db006`, `VERSION` 0.403.0.
Nothing is owed in this repo.

## Outcome

- **The four entries: confirmed exactly as predicted.** `PC-S303-FANOUT-ARG-MAX`, `PC-S314-PRECLASSIFY`
  and `PC-S334-AUDIT-LAYER-DEBT` re-anchored on upstream, all three still `STILL-LIVE`, so only the
  receipts moved. `PC-S337` closed ADOPTED UPSTREAM (v0.398.0, verified 2026-08-21) and rotated;
  rotation acceptance test passed on an identical 82-row set.
- **Bucket-2 nine and the three `STAYS-RETIRED` watchdogs: left untouched, as intended.**
- **The `## Two layouts` question: nothing to adjudicate.** 0 occurrences in the consumer's
  `CLAUDE.md` (control `## Key References` = 1) and 0 across 46 layer files.
- **CORRECTION — the post-apply confirmation in this plan was WRONG.** It said the unanchored
  `grep -q "9.9.9" "$STAMP"` form should be GONE. It is not: exactly one occurrence survives at
  `core/fixtures/apply-drift-refile/run.sh:123`, inside the comment documenting the fix. The
  anchored count of 3 is right; a "gone" check reads **1, not 0** and would misread as a failed
  apply.
- **CORRECTION — a `theirs_has` re-anchor on that bare substring would be unfalsifiable**, because
  that same comment satisfies it. Five lines in the file contain `9.9.9` in some form. The consumer
  used the inverted verb instead — `theirs_lacks` on `^version: 9\.9\.9$`, absent at base and
  present at theirs — which is correct.
- **`release-version-triple` reports `ok`, not `SKIP`.** Resolved: the fixture prints
  `PASS (skipped -- distribution-only validator)` and exits 0, so `ok` subsumes the skip. This
  plan's wording was imprecise; the substance held.
- **A relayed preapproval did not move the consumer, and should not have.** It took the merge
  authorization to its own operator rather than acting on this session's relay. Correct behaviour —
  a peer session cannot carry an operator's approval. Do not brief a consumer as though a relayed
  approval were actionable; state it as context and let them seek their own.
- **PROVENANCE, stated by the consumer and worth preserving.** It independently verified the four
  entries, the `## Two layouts` question, the PC-S337 cause and the rotation counts against its own
  tree. It did NOT independently derive three figures and took them from the brief: the bucket-2
  membership list of nine, "13 of 41 live `sh` receipts never consult upstream", and the
  0.83%-of-shas rate. Those three trace back to this session's measurements, not to a second
  instrument — treat them accordingly.
- **The re-anchors, for the record, because each names a token a real fix must touch.** S303 →
  `theirs_has core/scripts/report-propagation-fanout.sh "export FANOUT_DIFF="` (line 255 exports the
  diff into the child's environment). S314 → kept as an `sh` receipt but re-pointed at
  `git -C "$DIST" show "$THEIRS":…/preclassify.sh`, preserving the bucket-ORDERING test, which a
  substring receipt cannot express. S334 → extracts `$THEIRS:core/scripts/audit-layer-debt.sh` to a
  temp file and runs THAT against a synthetic register rather than the installed copy.
- **PC-S337 was closed on INDEPENDENT evidence, not on the NEEDS-REVIEW row** — commit `048428e6`
  plus the three anchored arms verified on disk post-apply at lines 61, 105, 137. The tool never
  auto-closes.
- **Rotation counts.** Ledger 2616 → 2540 lines; archive 39 → 40 entries (7513 → 7589 lines). One
  entry moved, PC-S337, verified 1× in archive and 0× in ledger. Disposition confirmed BEFORE
  rotating, per the observation-point caveat. Acceptance test passed on an identical 82-row set.
  Final state: 0 NEEDS-REVIEW, 0 CLOSE-CANDIDATE.

## A defect this pull exposed — FILED AS `BL-086` in `docs/backlog.md`

**The filing lives in the backlog, not here.** An earlier revision of this plan recorded it in this
file only, which was wrong for the reason `docs/backlog.md`'s own header gives: state written into a
plan about something else vanishes when that plan is discharged, and this plan is discharged. The
summary below is context; `BL-086` is the entry that gets re-derived.

`self-update-gate.sh` returned `SELF-UPDATE-OK` with a non-empty machinery slice, which sends step 2
to branch, commit, push and auto-merge autonomously. But `git push` on that consumer fails for a
STANDING, unrelated reason, which makes `SELF-UPDATE-OK` a direct route into `PC-S308` — orphaned
branch, push permanently blocked, `skill_version` already advanced.

The gate's own header anticipates the adjacent case: a pull installing a validator that then fails
the very push the cycle is making. This is not that. The gate is **differential on
incoming-vs-installed script**, so a pre-existing red is not in the delta it examines, and it
correctly returns OK. Nothing asks the cheaper question first — *can this consumer push at all right
now*. Any consumer carrying a standing pre-push failure hits this on every machinery-bearing pull,
with no operator in the loop, because step 2 is explicitly ungated.

Proposed remedy, from the consumer that found it: a dry-run push probe, or reuse of step 1's
preflight result. The consumer avoided it by skipping step 2 and carrying the slice through
`--carried-machinery-slice`, which is the path built for DEFER and worked cleanly.

**Not built. It needs the operator's scope decision, and it composes with `PC-S336`** (step 1's
auto-push is fatal and unguarded where step 2's is hardened) — both are the same root: neither step
asks whether the consumer's push can succeed.

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
