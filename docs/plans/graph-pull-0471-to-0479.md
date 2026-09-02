# DISCHARGED — DO NOT EXECUTE — pull the graph consumer from 0.471.0 to 0.479.0

**THIS RUNBOOK IS SPENT. IT RAN, IT MERGED, AND IT IS A RECORD RATHER THAN AN INSTRUCTION.**
Do not follow the numbered actions below; they describe work that is finished. Read
`## Discharge` at the foot for what the run found, and read the rest only as a worked example.

The pull landed on 2026-09-02 as the consumer's PR #1005. **The delivery gap is ZERO and PENDING
is 0** — re-derived on the distribution side after the merge, not taken from the executing
session's report.

## RESUME HERE — HISTORICAL

**This block was the status record while the file was live. It is kept as written.**

**STATE AT THE TIME: WRITTEN AND REHEARSED, NOT STARTED.** The rehearsal ran on `file://` clones
of both trees and every figure in `## Rehearsal` came from it.

**THIS FILE BEING GREEN IS NOT AUTHORIZATION.** `.claude/rules/operator-rulings.md` is
unconditional: a consumer pull is operator-initiated, readiness is not authorization, and a
`PENDING` count is not a decision about WHEN. If you are reading this without the operator having
said "run the pull", stop and ask.

Read `## Start here` FIRST, then `### Numbered actions`. `## Rehearsal` is what to expect;
`## Hazards` is what will bite you.

## Start here

**YOUR SESSION'S PROJECT ROOT MUST BE `/Users/n8/git/graph`.** Skill scope follows the session
root, not a Bash `cd` — a session rooted in the distribution cannot invoke the `ai-dlc-update`
skill at all. If your root is the distribution, stop and restart there.

- **`/Users/n8/git/graph`** — the consumer. WRITE, and only through the skill.
- **`/Users/n8/git/ai-dlc`** — the distribution. READ ONLY from this session.

**THE CONSUMER'S TREE IS DIRTY AND THAT IS EXPECTED.** It carries live `_bmad-output/` pipeline
state, and the set grows while the pipeline runs, so it is deliberately not enumerated here.
**Do not commit, revert, stash or clean it.** Committing makes the branch ahead of its remote and
the preflight then auto-pushes in-flight state on what was meant to be a dry run.

**THE CONSUMER IS ON A CARRY-OVER BRANCH, NOT `main`, AND IT MOVES WHILE YOU WORK.**
Re-derive the branch and the head before you start; do not switch either. Measured during the
session that wrote this file: its head advanced one commit and its dirty count went 8 -> 16 ->
22 within a few hours, from its own pipeline checkpointing at an operator handoff. **A moved
consumer head during your run is the normal case, not an alarm** — check whether the consumer
wrote before concluding anything about it.

**DO NOT WRITE A REF OR A SHA INTO THIS FILE.** The skill pulls latest and resolves the ref
itself. Any sha written down goes stale the moment anything lands, including the commit that
adds this runbook.

**Do NOT re-describe the pull.** The `ai-dlc-update` skill owns resolving the ref, gating its own
self-update, carrying the machinery slice and emitting the worklist. Everything this file adds is
what is SPECIAL about this range.

### Numbered actions

1. **Confirm the operator has authorized THIS pull.** Not a `PENDING` count, not this file being
   green. If that has not happened, stop here and ping.

2. **Record the consumer's pre-run state** — branch, `git status --porcelain | wc -l`, and the
   four fields of `.claude/.ai-dlc-version`. You will assert against these afterwards.

3. **Run the `ai-dlc-update` skill.** Let it resolve the ref. Do not hand-drive `preclassify.sh`
   or `apply.sh`; the skill sequences them and a hand-rolled invocation has produced a wrong
   slice before. The specific trap: the `core/scripts/ai-dlc/*` glob in the manifest is
   CONSUMER-shaped and is rewritten at
   `core/skills/ai-dlc-update/reconcile/preclassify.sh:225`. Passed to `git diff` verbatim it
   matches nothing and drops SILENTLY, which has understated a slice as 2 and 4 files where
   the shipping function gives 3 and 6.

4. **EXPECT `SELF-UPDATE-DEFER`, AND DO NOT CUT THE SELF-UPDATE BRANCH.** This is the one thing
   about this range that will look like a failure and is not. See `## Rehearsal` for the exact
   rows. Fold the machinery slice into the gated apply so everything lands on one branch.

5. **Compare the worklist against `## Rehearsal` before applying.** If the row count, the bucket
   histogram or the `->CLASSIFY` count disagrees with what is recorded there, **STOP and ping the
   operator.** A disagreement is information and is worth more than a clean report.

6. **After the apply, re-run the two validators whose behaviour this pull is meant to change**,
   from the consumer root, and report both exit codes:

   - `scripts/ai-dlc/validate-spawn-ledger.sh` against the live spawn ledger and the current
     sprint. **It exits 1 before this pull and must exit 0 after.** That is the headline benefit
     and the one thing to verify by running rather than by reading.
   - `scripts/ai-dlc/audit-layer-debt.sh` against the layer adjudication register. Its
     `UNDECLARED` count must FALL. It is a reporter and never changes an exit code, so the count
     is the only observable.

7. **Close the candidates, by id, from the CONSUMER ROOT.** Run `ledger-reverify.sh` with the
   consumer root as the process cwd and pass it as an absolute path:

   ```
   cd /Users/n8/git/graph && bash .claude/skills/ai-dlc-update/reconcile/ledger-reverify.sh \
     /Users/n8/git/ai-dlc <base> /Users/n8/git/graph <theirs>
   ```

   **A distribution-root run has turned a live `STILL-LIVE` into a `CLOSE-CANDIDATE`, and a false
   close retires a live entry** — that is the worst output this system has. Report which ids
   closed and which did not. **Expect only ONE to close, and the table above agrees.** Three of the four PENDING candidates
   will NOT close, and `## Rehearsal` records why each one is correct to stay open.

8. **A `CLOSE-CANDIDATE` row is a hypothesis, not a verdict.** For each one, run that entry's
   receipt directly, read the raw exit code, and ask what ELSE satisfies it before rotating
   anything.

9. **Report to the operator**: the worklist as it actually came out, both validator exits from
   action 6, the ids that closed, and any disagreement with `## Rehearsal`.

10. **AFTER THE PULL MERGES, BEFORE YOU STOP: re-derive this file's own `## RESUME HERE` block
    and prove it is still resumable.** The merge is the moment a handoff goes stale — the block
    you just followed becomes a description of finished work, and a session that stops there hands
    the next one an instruction to redo it. Run the commands behind `## Rehearsal` again against
    the real post-pull tree and DIFF every figure against what this file claims; fix the COMMAND
    where they disagree, never only the prose. Then re-derive the delivery gap and the `PENDING`
    set in `docs/plans/graph-ledger-full-drain.md` and report both.

11. **Fill in `## Discharge` and retitle this file `DISCHARGED — DO NOT EXECUTE`.** A spent
    runbook still reading as instructions is this directory's recurring hazard — measured once at
    5 of 6 files in `docs/plans/`.

### Ping the operator

On any question, on any decision, on completion, and on any early stop. From outside, a session
that is thinking and a session that is waiting on a human look identical, and every consumer-side
stall in this program has ended with the operator asking rather than the session reporting.

### Done when

1. The stamp's four fields read `0.479.0` — checked by reading the file, not by assuming.
2. `validate-spawn-ledger.sh` exits **0** on the live sprint where it exited **1** before.
3. `audit-layer-debt.sh`'s `UNDECLARED` count has fallen.
4. `ledger-reverify` has been run from the consumer root and the closing ids reported.
5. `## Discharge` is filled in and the file is retitled.

Criterion 2 is the one that proves the pull was worth running. Its PASS was checked as reachable
by running both copies against the consumer's real ledger before this file was written.

## Hazards

- **`SELF-UPDATE-DEFER` is EXPECTED here and is not a failure.** `gate-validation.md` is a
  rulebook file in this range, and 40+ fixtures assert against a rulebook resolved in the live
  tree. A machinery-only step 2 would judge new machinery against the OLD rulebook and go red on
  a pull that broke nothing. The emitter and its exact reason text are at
  `core/skills/ai-dlc-update/reconcile/self-update-gate.sh:451`.
- **There is no safe stop, so the CURRENT engine classifies this pull.** No intermediate release
  in the range self-updates cleanly. `readopt-override.sh` and the updater `SKILL.md` are both in
  the range, so the consumer's installed, pre-fix copies are what run the delivery. **The specific
  hazard was measured rather than warned about and it comes back ZERO** — see `## Rehearsal`.
- **A false CLOSE is the worst output in this system.** It retires a live defect and is
  indistinguishable from an ordinary absorption. Always run `ledger-reverify` from the consumer
  root.
- **The Bash tool's shell is zsh.** No `PIPESTATUS`, so `cmd | tail` reports `tail`'s status —
  **never read a validator's exit through a pipe.** This bit the measurement that produced this
  runbook: both copies read "exit=0" through a `| tail` while the real codes were 1 and 0.
- **Three of the four PENDING candidates will not close, and that is correct.** Do not read a
  `STILL-LIVE` row on them as the pull having failed.

## Rehearsal

**Run on `file://` clones of both trees, against the consumer's committed HEAD on its carry-over
branch — the head it carried at the time of the rehearsal, which had already advanced once
during the session that wrote this file.** These are EXPECTATIONS, not guarantees. **If the real run disagrees, STOP and ping.**

**One known difference by construction:** the clone carries the consumer's committed state, and
the real run will see its dirty working tree. The pipeline state that makes it dirty is not in
any bucket below.

| what | expected |
|---|---|
| self-update gate | `SELF-UPDATE-DEFER rulebook-coupled-fixtures` naming `gate-validation.md`, a second bare `SELF-UPDATE-DEFER`, and `SELF-UPDATE-SAFE-STOP` reporting no intermediate release self-updates cleanly |
| worklist rows | **13** |
| by git status | 12 `M`, 1 `A` |
| `UPSTREAM-ONLY` | **11** |
| `UPSTREAM-ONLY-ADD` | **1** — `core/scripts/validate-artifact-derivations.sh.fn` |
| `DIST-ONLY-SKIP` | **1** — `core/fixtures/enforcement-map-sites/run.sh` |
| `->CLASSIFY` | **0** — the consumer has diverged on none of these paths, so nothing needs adjudicating |
| templates | 4, all unchanged — **0** template paths moved in this range |
| `ledger-reverify` verdicts | **47 `STILL-LIVE`, 32 `HAND-REVIEW`, 28 `NAMED-UPSTREAM`, 1 `CLOSE-CANDIDATE`** — corrected after the run; see the clone-artifact note below |

**THIS TABLE ORIGINALLY SAID 2 `CLOSE-CANDIDATE` AND THAT WAS A FALSE CLOSE PRODUCED BY THE
REHEARSAL ITSELF.** The executing session caught it. **A `git clone` does not carry `.git/hooks/`**,
so any receipt that reads the consumer's INSTALLED hooks cannot be rehearsed on a clone: it exits
non-zero for the ABSENCE of a hook, and `ledger-reverify` maps non-zero to `CLOSE-CANDIDATE`.
Reproduced both ways — real consumer `.git/hooks/pre-push` present at 314 bytes, receipt rc=0,
`STILL-LIVE`; clone hook ABSENT, same receipt rc=2, `CLOSE-CANDIDATE`.

The entry it fired on, `PC-S312-TRUNK-PUSH-DECLINES-TO-POLICE-THE-TRUNK`, carries **TWO
`verify: sh` lines** — one reading the distribution at `$THEIRS`, one reading the consumer's
`.pre-commit-config.yaml` and `.git/hooks/pre-push`. The distribution-reading one exits 0 in
every tree; the consumer-reading one is the one that flipped. **When a rehearsal and a live run
disagree on a receipt, check first whether the receipt reads state a clone does not carry.**

**AND THE TWO RE-VERIFY TOOLS USE OPPOSITE EXIT CONVENTIONS. DO NOT CARRY ONE INTO THE OTHER.**
`reconcile/ledger-reverify.sh` (the consumer ledger) reads **exit 0 as `STILL-LIVE`** — "still
reproduces at theirs" — and NON-ZERO as `CLOSE-CANDIDATE`, with `126|127` routed to
`NEEDS-REVIEW` so a renamed subject cannot look like a fix. `scripts/backlog-reverify.sh` (this
distribution's own backlog) is the INVERSE: exit 0 means the fix is present and yields
`CLOSE-CANDIDATE`. Both are correct in their own tool. Reading a raw exit code without saying
which tool will consume it is how a close gets recorded backwards.

**THE BOOTSTRAPPING HAZARD IS MEASURED AT ZERO FOR THIS RANGE, re-derived rather than carried
from the previous batch.** The consumer's INSTALLED pre-fix `readopt-override.sh` and this
distribution's fixed copy were both run `--check` over all 8 of the consumer's overrides, with a
`cmp -s` control asserting the two copies differ: **both return rc=0 on all 8.** No override needs
a re-adoption decision in this range, so no `--stamp readopt` decision falls to the old gate.

**WHAT EACH OF THE FOUR PENDING CANDIDATES DOES, AND WHY ONLY ONE CLOSES.** All four get a
`NAMED-UPSTREAM` row, so the ids did reach commit MESSAGES and not only the CHANGELOG.

- `PC-S340-STAMP-READOPT-GATE-IS-BLIND-TO-AN-ADDITIVE-CHANGE-AND-TO-A-REWRITTEN-BODY` —
  **`CLOSE-CANDIDATE`.** The one that closes.
- `PC-S340-UNDECLARED-CUE-CANNOT-TELL-A-REFERENCE-FROM-A-DECLARATION` — **`STILL-LIVE`, and that
  is CORRECT.** The fix closed the DENIAL class; that entry's own receipt tests the CITATION
  class, which is a stated limit of the fix rather than an omission. Verified by running its
  ledger receipt against the fixed script: it still exits 0.
- `PC-S340-VALIDATE-SPAWN-LEDGER-OVERSHOOTS-CHECK-22-DECLARED-ROLE-SCOPE` — **`STILL-LIVE`, and
  that is CORRECT.** Its filed remedy (scope the script to Check 22's five roles) was refuted and
  deliberately not built, so its receipt still reproduces. **The practical FAIL is gone anyway** —
  see the benefit below. Both facts are true and they answer different questions.
- `PC-S340-DERIVATION-CAPTURE-HOOK-ROLLS-BACK-THE-WHOLE-FILE-ON-A-REJECTED-BLOCK` —
  **`HAND-REVIEW`**, `verify: manual` by design. Only its PARSE half shipped; its ROLLBACK half
  was refuted, not deferred.

**THE BENEFIT, measured on the consumer's real tree before this file was written.** Both were run
directly with no pipe, because zsh has no `PIPESTATUS`:

- `validate-spawn-ledger.sh` on the live sprint: **installed exits 1** (`FAIL: 8 Rule 19
  violation(s) across 128 rows`), **fixed exits 0** (`all 124 rows carry a resolvable role file, a
  Rule 19(b) citation, and a matching model pin`). Control: an impossible sprint returns exit 3 on
  both sides, so the differential discriminates rather than merely differing. **This is a gate
  that currently fails on correct data.**
- `audit-layer-debt.sh` on the live register: **installed reports 29 `UNDECLARED`, fixed reports
  19**, `OPEN` unchanged at 16 on both sides, with a `cmp -s` control asserting the copies differ.
- The derivation-capture parse fix has a large surface — **262 files carry a ```derived``` fence
  and 643 carry the `|` alternation shape** the pre-fix hook mis-parsed as a shell pipe, control
  token 0. **Stated limit: that is a count of the SHAPE, not of measured rejections.** Nobody has
  driven the installed hook to confirm each one fails today.

## Discharge

**Merged 2026-09-02 as the consumer's PR #1005**, squash-merged onto its carry-over branch, 18
files, +1909/-321. Executed by a graph session under operator authorization; this section was
written on the distribution side because actions 10 and 11 write to a file that session correctly
treats as READ ONLY.

**EVERY FIGURE BELOW WAS RE-DERIVED HERE RATHER THAN TRANSCRIBED**, because a number from another
session is a hypothesis until re-run. All of the executing session's figures survived that.

### What the rehearsal predicted correctly

| claim | outcome |
|---|---|
| 13 rows, 11 `UPSTREAM-ONLY`, 1 `UPSTREAM-ONLY-ADD`, 1 `DIST-ONLY-SKIP`, 0 `->CLASSIFY` | exact |
| templates 4, all unchanged | exact |
| `SELF-UPDATE-DEFER`, no safe stop, slice folds into the gated apply | exact; `--carried-machinery-slice` |
| bootstrapping hazard zero | held; no `--stamp readopt` decision fell to the old gate |
| `audit-layer-debt.sh` `UNDECLARED` 29 → 19, `OPEN` unchanged at 16 | exact |
| `validate-spawn-ledger.sh` exit 1 → exit 0 | exact |
| only ONE candidate closes | exact |

Re-derived post-merge on the distribution side: stamp `0.479.0` / `7dd68c34` on all four fields
with `installed_at` and `upstream` preserved; `validate-spawn-ledger.sh` sprint 307 **exit 0**;
`audit-layer-debt.sh` **19 UNDECLARED / 16 OPEN** over **322** register rows; both installed
copies now byte-identical to the distribution; **0 `CLOSE-CANDIDATE`** rows remain.

### What the rehearsal got WRONG, and it was corrected mid-run

The table originally said **2 `CLOSE-CANDIDATE`**; the live run correctly reported 1. The second
was a FALSE CLOSE the rehearsal manufactured: a `git clone` does not carry `.git/hooks/`, and the
entry it fired on carries TWO `verify: sh` receipts, the second of which reads
`.git/hooks/pre-push`. The executing session caught it and was right; the table was corrected
before the apply. Filed as `BL-143` — the absent-subject guard that exists to prevent exactly this
is scoped by an allow-list that cannot spell `.git/*`, so it is a check that cannot fire.

### What the rehearsal did NOT predict, and what it cost

**`emit-report --verify` exits 1 immediately BEFORE the apply, and that is correct behaviour.**
Recording the four `LC-E4` verdicts clears the HARD rows and makes the rendered region stale, so
**the union gate fires on your own adjudications**. Regenerating and re-verifying is the prescribed
path and it cleared. Nothing in the step text makes that obvious, and a session that reads the
exit as a blocker will stop with the work already correct. **A future runbook should say this.**

**CRITERION 2 CANNOT BE MEASURED ON AN EMPTY SPRINT, AND THIS FILE DID NOT SAY WHICH SPRINT.** It
said "the live sprint". Measured after the merge: sprint 307 carries 128 rows and returns exit 0;
**sprint 308 has no rows and returns exit 3 — byte-identical to the impossible-sprint control.** A
done-when checked on 308 would have been unfalsifiable while reading as a pass. The executing
session noticed and used 307. **Name the population a criterion is measured over, not just the
command.**

**The benefit is causally confirmed rather than correlated.** All 8 pre-pull FAILs were role
`general-purpose` — exactly the class core's new Check 22 text declares out of scope.

### State after the pull, derived here

Delivery gap **ZERO** (consumer 0.479.0, distribution 0.479.0). **PENDING 0** — all four
candidates resolved to releases at or below what the consumer now runs.

Ledger md5 moved `91deb97f…` → `dbce0d07…`, which is the consumer recording the close and the four
adjudications. **LIVE is still 72 and the archive still 141**: the closed candidate is ANNOTATED
`**ADOPTED UPSTREAM (v0.476.0, verified 2026-09-02)**` but NOT YET ROTATED, and `ledger-rotate.sh`
archives only on an explicit annotation taken as a human act. **The denominator falls when the
consumer rotates, not when the pull lands** — do not read 72 as the pull having failed to move
anything.

`CITED` rose 35 → 36 and `UNFILED` fell 37 → 36 for a reason that has nothing to do with the pull:
filing `BL-143` here cites `PC-S312-TRUNK-PUSH-DECLINES-TO-POLICE-THE-TRUNK`, a live candidate, so
that id now reads as in flight. An incidental effect of a filing, recorded so the next sweep does
not read it as consumer activity.

### Left open on the consumer, flagged and NOT actioned

`_bmad-output/pipeline-snapshot.md` still carries a discharged `HANDOFF POINT` record, so
`ai-dlc-handoff-pending.sh` key 2 keeps returning pending and the Stop guard demands a resume block
every turn. It is consumer-side state; an ai-dlc session never writes there. **Operator's to
clear.**

### What a future runbook should copy

Name the sprint or population every criterion is measured over. Say that the union gate fires on
the executor's own adjudications. And state that a `file://` clone cannot rehearse a receipt
reading anything outside the tracked tree — that class of receipt yields a false CLOSE in
rehearsal specifically, which is the direction that matters.
