# Pull the graph consumer from 0.432.0 to 0.434.0

## RESUME HERE

**Resume with exactly: `READ and FOLLOW docs/plans/graph-pull-0432-to-0434.md`.** This block is
the current state; everything under `## Rehearsal` is an EXPECTATION measured before the run, not
a guarantee.

**THIS FILE IS NOT ITS OWN AUTHORIZATION. The pull is initiated by the OPERATOR and by nobody
else** — not by a distribution session that notices the gap, not by a consumer session that finds
this file, and not by the fact that the runbook is written and rehearsed. Being ready is not being
told. A previous deferral does not carry forward as standing approval for the next attempt.

**IT SUPERSEDES `docs/plans/graph-pull-0432-to-0433.md`, which must NOT be executed.** That file
was written and rehearsed for a range the operator then chose to bundle. Its `## Rehearsal` table
describes a manifest this run will not produce, and it instructs its executor to STOP and ping on
any disagreement — so run against the bundled range it would fire on nearly every row, and the
strength of that instruction is exactly what would make it costly.

**THE RANGE NOW SPLITS INTO TWO LEGS, AND THE PREVIOUS RUNBOOK PREDICTED ONE.** That is the single
biggest change and it is not a surprise to work around — the gate prescribes it. Bundling
`0.434.0` in changes two RULEBOOK files that roughly three dozen fixtures are coupled to, so
`self-update-gate.sh` returns `SELF-UPDATE-DEFER` and names a safe stop at `0.433.0`. Leg 1 runs
to that stop, leg 2 completes. The gate names the stop itself; no sha is written into this file.

### Start here

**This session's PROJECT ROOT is `/Users/n8/git/graph`.** Skill scope follows the session root,
not a Bash `cd` — a session rooted in the distribution cannot invoke the skill at all. If your
root is anywhere else, stop and ping.

**`/Users/n8/git/graph` is the tree this run writes, and the pull itself is what writes it.**
`/Users/n8/git/ai-dlc` is READ ONLY for you: read it freely, write nothing there. **You do not
discharge this file** — a distribution session does that from its own repo, where this file is
subject to that repo's gate. Report your numbers and stop.

**The consumer's tree is DIRTY and that is EXPECTED** — live `_bmad-output/` pipeline state. **Do
not commit, revert, stash or clean it.**

**THE AUTO-PUSH TRIGGER IS WIDER THAN "you committed something".** It also fires on a branch with
**no upstream configured**, which needs no commit from you. `SKILL.md` step 1 treats that as
`AUTO-PUSH`, and the preflight runs on EVERY invocation — so `/ai-dlc-update` in ANY form,
including a bare dry run, publishes the current branch to origin. **And publishing the branch does
not clear it:** a push without `-u` leaves the ref on origin, byte-identical, with the trigger
still armed, because the condition is keyed on branch tracking configuration rather than on the
ref existing remotely. Check `git rev-parse --abbrev-ref --symbolic-full-name @{u}` before you
invoke anything; if it is fatal, stop and ping. This is `PC-S336`.

The version stamp is `.claude/.ai-dlc-version`. Read the base from there; **no sha and no ref is
written into this file**, because the skill resolves them and anything written down goes stale.

### Numbered actions

1. **Confirm the project root is `/Users/n8/git/graph`**, then read `.claude/.ai-dlc-version` and
   confirm `0.432.0` on all four fields. A different value means this runbook is for a range you
   are not in — stop and ping.

   **AND CONFIRM NO SPRINT IS RUNNING IN THIS TREE.** This range replaces the machinery a sprint
   EXECUTES — `reconcile/apply.sh`, `reconcile/layer-drift.sh`, and the step files under
   `.claude/skills/` — so pulling mid-sprint swaps the pipeline's own steps out from under a run
   that is using them. **If a sprint is in flight, stop and ping; do not pause it yourself.**

2. **Run `/ai-dlc-update`, and expect TWO LEGS.** The rehearsal predicts
   `SELF-UPDATE-DEFER  rulebook-coupled-fixtures` plus a `SELF-UPDATE-SAFE-STOP` naming the
   `0.433.0` commit — because this range changes `steps/handoff.md` and `steps/_gate-procedures.md`,
   which about three dozen fixtures are coupled to. Run leg 1 to the stop the gate names, then leg
   2 to complete. **The skill owns resolving the ref and carrying the machinery slice; none of
   that is re-described here.** If the gate does NOT defer, that disagrees with the rehearsal —
   stop and ping rather than proceeding on the difference.

3. **Assert the two reconcile files landed TOGETHER, after leg 1 and again after leg 2.**
   `core/skills/ai-dlc-update/reconcile/apply.sh:559` resolves `ADJ_KEEP_VERDICT` from its sibling
   `layer-drift.sh` and is FATAL when it cannot, so one arriving without the other aborts every
   later apply. The repaired handoff push it ships alongside is at
   `core/skills/ai-dlc/steps/handoff.md:37`:

   ```
   grep -c ADJ_KEEP_VERDICT .claude/skills/ai-dlc-update/reconcile/layer-drift.sh   # want >= 1
   grep -c ADJ_KEEP_VERDICT .claude/skills/ai-dlc-update/reconcile/apply.sh         # want >= 1
   grep -c ADJ_ROW_TOKEN    .claude/skills/ai-dlc-update/reconcile/apply.sh         # control: >= 1 before AND after
   ```

   **The pre-pull baseline was measured on your tree at `0.432.0`: `ADJ_KEEP_VERDICT` 0 in both
   files, `ADJ_ROW_TOKEN` 3 and 7.** So a post-pull `0` on either of the first two is unambiguous.
   If `apply.sh` has the new name and `layer-drift.sh` does not, STOP and ping.

4. **Compare each leg's manifest against the `## Rehearsal` table.** Report BOTH, agreeing or not.
   A disagreement is information; stop and ping before disposing of any row.

5. **Dispose of the worklist rows.** The rehearsal expects three `WORKLIST extension-title-match`
   rows and **all three are PRE-EXISTING** — not caused by this range. They are still work with an
   owner; `apply` is not clean while one is outstanding.

6. **Close the candidates, by id.** Run `ledger-reverify` **from the consumer root** — a
   distribution-root run has turned a live `STILL-LIVE` into a `CLOSE-CANDIDATE`, and a false
   close retires a live entry. The ids this bundled range discharges:

   - `PC-S307-RECORDED-VERDICT-SUPPRESSES-THE-REMEDY-IT-AUTHORIZES` (0.433.0)
   - `PC-S307-HANDOFF-PUSH-IS-A-BARE-GIT-PUSH-SO-A-FIRST-HANDOFF-CANNOT-SUCCEED` (0.434.0)

   Report which closed and which did not, by name, and do not close one the tool did not.

7. **Measure what the adjudication fix does to YOUR register, and report the number.** The
   expectation is **zero rows changed**, and it was re-derived against this exact range rather
   than carried forward: `core/skills/ai-dlc/steps/retro.md` is byte-identical at base and theirs,
   so the `LC-O15` digest does not move and still resolves to the `still-additive` row
   (`90f946f7…`), not the `retire` row (`c86e7fac…`). **If you see an ATOMIC `override-retire`
   sequence where the last pull emitted a `NOTE override-adjudicated`, that is the fix firing** —
   read the rows and report them.

8. **Report to the operator**, including an early stop. Then stop. You do not edit this file.

9. **DISTRIBUTION SESSION ONLY — after the run reports and the range has merged, re-derive this
   file's own RESUME block and prove it is resumable, then write `## Discharge` and retitle the
   file.** The merge is the moment the block above stops being an instruction and becomes a
   description of finished work. Run the `## Rehearsal` figures again and DIFF them against what
   this file claims; fix the COMMAND and not only the prose, because a resuming session runs the
   command. Then `bash scripts/validate-plan-shape.sh`, which is the floor and not the answer.
   **A SCHEDULING DECISION STALES THIS FILE AS SURELY AS A MERGE DOES** — its predecessor decayed
   the moment the operator chose to bundle, through a door this action does not watch. If the
   range changes again, supersede rather than patch.

### Ping the operator

On any question, on any decision, on completion, and on any early stop. From outside, a session
that is thinking and a session that is waiting on a human look identical.

### Done when

1. `.claude/.ai-dlc-version` reads `0.434.0` on all four fields. Observation point: after leg 2
   completes, before any further work.
2. `.claude/.ai-dlc-applying` is absent, at the same observation point.
3. Action 3's two greps return non-zero with the control also non-zero, checked after BOTH legs.
4. `ledger-reverify`, run from the consumer root, has been run and its verdict for each of the two
   ids in action 6 reported by name — **whatever that verdict is.** This is satisfied by REPORTING,
   not by a close: the tool decides, and a runbook demanding a particular answer would be asking
   its executor to produce one.
5. Every worklist row emitted by either leg is disposed of, so `apply` reports clean.

## Rehearsal

**Measured on `file://` clones of BOTH trees, consumer at its committed baseline, distribution at
`origin/main` carrying `0.434.0`. Nothing was written to either real repo.** Expectations, not
guarantees.

```
core/ paths changed in the range                5     (control: impossible pathspec -> 0)
  reconcile/apply.sh, reconcile/layer-drift.sh,
  steps/handoff.md, steps/_gate-procedures.md,
  fixtures/apply-worklist-rows/run.sh
mode-only changes (modes differ, blobs equal)   0
self-update-gate.sh    SELF-UPDATE-DEFER  rulebook-coupled-fixtures
                       SELF-UPDATE-SAFE-STOP naming the 0.433.0 commit
                       -> TWO LEGS
preclassify                                     5 rows
layer-drift                                    51 rows: 37 EXTENSION-OK, 8 OVERRIDE-OK,
                                               3 EXTENSION-TITLE-MATCHES-CORE,
                                               1 OVERRIDE-SUPERSEDED,
                                               1 OVERRIDE-ASSERTS-SHADOW-SURVIVES,
                                               1 EXTENSION-RESTATES-CORE
apply manifest                                 10 rows: 5 RESOLVED pure-apply,
                                               3 WORKLIST extension-title-match (PRE-EXISTING),
                                               1 NOTE override-adjudicated (still-additive),
                                               1 DECISION restamp-withheld
```

**What changed against the superseded `0432-to-0433` rehearsal, and why each matters:** the range
grew 3 → 5 core paths; the gate went from `SELF-UPDATE-OK` to `SELF-UPDATE-DEFER` with a safe stop,
so a single-leg run is now the wrong expectation; `pure-apply` rows went 3 → 5. **The layer-drift
distribution and the adjudicated row did NOT change**, and that was re-derived rather than carried:
`retro.md` is byte-identical across the whole range, so the digest and action 7's expectation hold.

## Discharge

*Empty. Written and committed by a DISTRIBUTION session in `/Users/n8/git/ai-dlc` after the run
reports, never by the executing consumer session. When it is written, retitle this file
`DISCHARGED — DO NOT EXECUTE` at the top.*
