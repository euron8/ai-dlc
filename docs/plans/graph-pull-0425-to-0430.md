# DISCHARGED — DO NOT EXECUTE

# Pull the graph consumer from 0.425.0 to 0.430.1

## RESUME HERE

**Status: DISCHARGED 2026-08-28. DO NOT EXECUTE. Nothing below is an instruction any more.**

The pull ran and landed. `.claude/.ai-dlc-version` on the graph consumer reads **0.430.1 /
`1115a426` on all four fields**, `.claude/.ai-dlc-applying` is absent, and `main` is level with
`origin/main`. The numbered actions below are retained as a record of what was done, not as work
to do. See `## Discharge` at the foot of this file for the real numbers.

**The range this file was written for was wrong by the time it ran, in both directions.** It was
drafted for `0.425.0 -> 0.429.0`, its own banner corrected that to `0.430.0`, and the distribution
was actually at **`0.430.1`** — six releases, 42 commits, **56** changed core paths against the 23
this file predicted. Every figure was re-measured on a `file://` clone before use, exactly as the
banner demanded, and the re-rehearsal is what caught the two things this file got wrong.

**IT RAN AS TWO LEGS, NOT ONE.** `self-update-gate.sh` returned `SELF-UPDATE-DEFER` for the full
range and named `SELF-UPDATE-SAFE-STOP 144fd252` (v0.427.0). Action 2 below says "run
`/ai-dlc-update`" and never anticipates a split. The correct execution was
`/ai-dlc-update 144fd252 apply` then `/ai-dlc-update apply`.

**AND THE WITHHOLDING FIRED, WHICH THIS FILE PREDICTED IT WOULD NOT.** Action 4 below calls itself
conditional and says the rehearsal predicts it will not fire. It fired on leg 2, against 17
outstanding rows, and `--finish --carried-machinery-slice` was a required step rather than a
contingency. The inversion is a consequence of the split: leg 1 installs the new driver, so leg 2
is applied BY it rather than by the old one.

**The one hazard this file warned about hardest did not happen, and the split is why.** It warns
that the corrected `pre-push` guard naming `--finish` "arrives one pull behind itself". Under the
split it arrives in leg 1 and the withhold happens in leg 2, so the corrected message was already
installed when the only thing that triggers it occurred. Verified rather than assumed: the
consumer's `.githooks/pre-push` was byte-identical to the base blob, so it bucketed pure-apply.

### Numbered actions

1. **Confirm your project root is `/Users/n8/git/graph`.** If it is not, stop and ping.

2. **Run `/ai-dlc-update` — AS EXECUTED, TWO LEGS.** The gate deferred and named a safe stop, so
   the actual commands were:

       /ai-dlc-update 144fd252cb0146ef2a7bdd77bcd29023281ae273 apply
       /ai-dlc-update apply

   Leg 1 self-updated autonomously (`SELF-UPDATE-OK` at that ref) and re-invoked itself; leg 2
   deferred with no further safe stop and folded the machinery slice into the gated apply.

3. **Compare the run's manifest against the rehearsal table above.** Report both. If they agree,
   say so; if they do not, stop and ping before applying.

4. **IT FIRED ON LEG 2 — this was not conditional in the event.** 17 rows were disposed, then:

       apply.sh --finish --carried-machinery-slice <dist> 144fd252 <consumer> 1115a426

   Afterwards `.claude/.ai-dlc-version` read **0.430.1** on all four fields and
   `.claude/.ai-dlc-applying` was gone. NOTE: `--finish` prints `RESOLVED consistent` without
   verifying anything (BL-102), so the omitted check was run by hand — every shipped path against
   `git show "1115a426:core/<rel>"`, 44 match / 2 mismatch / 0 absent with a control, the two
   mismatches being the semantic-merge files that must differ.

5. **Close the candidate, by id.** Run `ledger-reverify` **from the consumer root** — a run from
   the distribution root has turned a live `STILL-LIVE` into a `CLOSE-CANDIDATE`, and a false
   close retires a live entry. Then report which of these closed and which did not:

   - `PC-S304-APPLY-SH-RESTAMPS-BEFORE-THE-WORKLIST-IS-DONE`

   The pull is not the point; the ledger closing is.

6. **AFTER THE RUN, BEFORE YOU STOP: re-derive this file's own RESUME block and fill in
   `## Discharge`.** The moment the pull lands is the moment this handoff goes stale — the block
   you just followed becomes a description of finished work, and a session that stops there hands
   the next one an instruction to redo the pull. Change `Status: NOT STARTED` to what actually
   happened, replace the rehearsal table with the run's real numbers, retitle the file
   `DISCHARGED — DO NOT EXECUTE`, and commit it. Fix the COMMANDS, not only the prose.

7. **Report to the operator**, including an early stop.

### Ping the operator

**On any question, on any decision, on completion, and on any early stop.** From outside, a
session that is thinking and a session that is waiting on a human look identical. Merges are
preapproved — do not stop to ask for one.

### Done when

1. `.claude/.ai-dlc-version` reads **`0.430.1`** on `version`, `commit`, `skill_version` and
   `skill_commit`. (This criterion said `0.429.0` when written; that was stale twice over.)
   **MET** — observed after action 4 on leg 2.
2. `.claude/.ai-dlc-applying` is absent. Same observation point. **MET.**
3. `PC-S304-APPLY-SH-RESTAMPS-BEFORE-THE-WORKLIST-IS-DONE` is reported closed or the reason it
   is not is stated. **MET — closed by hand at v0.426.0.** This range discharged more than this
   one id, so the criterion under-reported its own pull: six entries closed in total (see
   `## Discharge`). **This one may legitimately come back NOT closed** — the ledger entry is
   `verify: manual`, so `ledger-reverify` cannot adjudicate it mechanically and will say so.
   That is a PASS for this criterion provided you report which it was; it is a FAIL only if
   nobody looked.

## Discharge

**Discharged 2026-08-28.** Consumer at **0.430.1 / `1115a426`**, all four stamp fields,
`.ai-dlc-applying` absent, `main` level with `origin/main`.

Landed as three PRs on the consumer: **#973** (leg-1 self-update), **#974** (leg-1 reconcile),
**#975** (leg-2 reconcile).

### What the range actually was

Six releases (0.426.0 → 0.430.1), 42 commits, **56** changed core paths (45 M, 11 A) — against
the 23 this file predicted. Both hazards it named were re-measured and held: **0** mode-only
changes across all 56 paths (every mode transition is a `000000 ->` ADD), and the bootstrapping
split confirmed by `--finish` 0→22 / `handback` 0→5 between the installed and incoming
`apply.sh`, with the two blobs asserted to differ as a control.

### The manifests, as run

    leg 1  e7898c7d -> 144fd252   (0.426.0, 0.427.0)
      step 2 SELF-UPDATE-OK -> autonomous self-update, 15/15 fixtures green, PR #973
      step 3: 5 ALREADY-AT-THEIRS, 1 ALREADY-PRESENT  (the whole delta WAS the machinery)
      apply: 1 NOTE override-adjudicated, RESOLVED restamp, RESOLVED consistent
      0 WORKLIST, 0 DECISION.  stamp -> 0.427.0/144fd252

    leg 2  144fd252 -> 1115a426   (0.428.0, 0.429.0, 0.430.0, 0.430.1)
      step 2 SELF-UPDATE-DEFER, SAFE-STOP "-" -> --carried-machinery-slice
      step 3: 39 UPSTREAM-ONLY, 6 DIST-ONLY-SKIP, 5 UPSTREAM-ONLY-ADD, 2 ->CLASSIFY
      apply: 44 RESOLVED pure-apply, 10 NOTE extension-adjudicated,
             3 WORKLIST extension-title-match, 2 WORKLIST semantic-merge,
             1 NOTE override-adjudicated, 1 DECISION restamp-withheld
      after --finish: stamp -> 0.430.1/1115a426, marker cleared

**The `->CLASSIFY` count was 2, not the 0 this file predicted** — `team-roles/qa.md` (a declared
setup site, so mask/reinject rather than a freehand merge) and
`fixtures/artifact-path-conformance/run.sh` (one reworded rationale kept onto theirs, with a
control confirming upstream had not also moved that line).

### The row this file told the executor to STOP on did not appear

`WORKLIST settings-merge` naming `ai-dlc-context-provenance.sh` as an unregistered hook: **absent
from both legs, control 0 each.** Now confirmable at the mechanism rather than by its absence —
the library landed on leg 2, is correctly unregistered, and **four** sibling hooks source it
(`ai-dlc-protect`, `ai-dlc-dispatch-guard`, `ai-dlc-recover-gate`, `ai-dlc-recover`), which is the
"some sibling sources it" exemption v0.429.0 derived to replace the name list.

### Ledger — the point of the exercise

**Six entries closed**, each by hand against its implementing commit's containing release:

| entry | release |
|---|---|
| `PC-S304-APPLY-SH-RESTAMPS-BEFORE-THE-WORKLIST-IS-DONE` | v0.426.0 |
| `PC-S306-CHECK-2-HAS-NO-SPRINT-SCOPE` | v0.428.0 |
| `PC-S306-SUPPRESSED-STATUS-FIRST-TOKEN-SILENT-NO-OP` | v0.428.0 |
| `PC-S306-SERIES-VALIDATOR-NO-LEAD-RESOLUTION-PATH` | v0.428.0 |
| `PC-S306-STUB-AUDIT-PHASE-N-MATCHES-WORD-BOUNDED-PROSE` | v0.428.0 |
| `PC-S306-UNSOLICITED-CONTEXT-HAS-NO-PROVENANCE-SIGNAL` | v0.429.0 |

**This file attributes the sprint-306 set to `0.429.0`. Four of the five landed in `0.428.0`.**
And the version must not be read off the commit that names an id: `593fb466` names the whole
sprint-306 set and is a `docs(backlog)` closure, not an implementation; `git show
81237656:VERSION` reads `0.425.0` for a fix contained in `0.426.0`.

Two entries the file listed as discharged did NOT close and are still open:
`PC-S306-FANOUT-UNTRACKED-FILES-INVISIBLE` and
`PC-S306-GATE-REMEDIATION-BLOCKS-INDEPENDENT-DEV-DISPATCH` — upstream's history does not name
either id, though the behaviours this file describes for both are present at theirs. Their
receipts, not the entries, are the thing to look at next.

### Filed against upstream

`PC-S307-RECORDED-VERDICT-SUPPRESSES-THE-REMEDY-IT-AUTHORIZES` — `apply.sh:575-579` suppresses the
ATOMIC `override-retire` steps on ANY recorded verdict, including `retire` and `contradicts-core`,
whose purpose is to authorize them. The `case` matches the token's presence and never branches on
the value, so the emitted NOTE asserts a property of the verdict on a path that never reads it.
2 of 3 vocabulary members. Receipt scored three ways before filing.

### Left for the operator

**One `retire` verdict is recorded and deliberately not executed**:
`overrides/steps__retro__domain-sections.md` / `steps/retro.md#4a. Close-Out Sweep`, digest
`c86e7face729c84db493143c0653bbe7a06ea751`. §4a is byte-identical across the range (span 374-605,
232 lines, re-derived through the shipping `span_of` with a control), so the pull did not need it;
executing it orphans ~289 non-blank lines including ~101 of consumer close-out machinery. Step 1
of its ATOMIC pair is already satisfied (`AI_DLC_SNAPSHOT_STRIKETHROUGH=forbid`).

**It will not resolve itself.** `adj_digest()` hashes the consumer entry plus core's target at
THEIRS, and the verdict was recorded with THEIRS already at `1115a426`, so the core move that
fired the row is not what spends the digest. It reaches a terminal state only by being executed
deliberately.
