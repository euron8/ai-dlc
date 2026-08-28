# Pull the graph consumer from 0.432.0 to 0.433.0

## RESUME HERE

**Resume with exactly: `READ and FOLLOW docs/plans/graph-pull-0432-to-0433.md`.** This block is
the current state; everything under `## Rehearsal` is an EXPECTATION measured before the run, not
a guarantee.

**One release, three core paths, no self-update split predicted.** The range carries one fix —
the adjudication suppression now branches on the recorded verdict instead of on the token's
presence (`PC-S307`). Read `## Rehearsal` before you start and STOP if the real run disagrees
with it; a disagreement is information and is worth more than a clean report.

**THE ONE THING THAT MUST LAND TOGETHER, AND THE REHEARSAL SAYS IT WILL.**
`core/skills/ai-dlc-update/reconcile/apply.sh:559` now resolves a second declaration,
`ADJ_KEEP_VERDICT`, out of its sibling `layer-drift.sh`, and it is FATAL (exit 2) when it cannot
— by design, because guessing either way is a filed defect. **If this pull landed the new
`apply.sh` beside an old `layer-drift.sh`, the consumer's next apply would abort with exit 2 on
every adjudicated row.** Both files are in the range and both bucket the same way, so the split
cannot occur here. Verify it anyway at action 3: it is one grep, and it is the failure that would
be discovered at the WORST moment, on the next pull.

### Start here

**This session's PROJECT ROOT is `/Users/n8/git/graph`.** Skill scope follows the session root,
not a Bash `cd` — a session rooted in the distribution cannot invoke the skill at all. If your
root is anywhere else, stop and ping.

**`/Users/n8/git/graph` is the tree this run writes, and the pull itself is what writes it.**
`/Users/n8/git/ai-dlc` is READ ONLY for you: read it freely, write nothing there. **You do not
discharge this file** — a distribution session does that from its own repo, where this file is
subject to that repo's gate. Report your numbers and stop. (The previous runbook ordered its
executor to commit into the distribution while its own boundary forbade it; the executor had to
resolve that mid-run, and this is the rule that came out of it.)

**The consumer's tree is DIRTY and that is EXPECTED** — live `_bmad-output/` pipeline state, and
the file set grows while the pipeline runs, so it is not enumerated here. **Do not commit, revert,
stash or clean it.** Committing makes the branch ahead and the preflight auto-pushes in-flight
state on what you intended as a dry run.

The version stamp is `.claude/.ai-dlc-version`. Read the base from there; **no sha is written into
this file**, because the skill resolves the ref itself and anything written down goes stale the
moment the next thing lands — including the commit that adds this runbook.

### Numbered actions

1. **Confirm the project root is `/Users/n8/git/graph`.** If it is not, stop and ping. Then read
   `.claude/.ai-dlc-version` and confirm it says `0.432.0` on all four fields. A different value
   means this runbook was written for a range you are not in — stop and ping.

2. **Run `/ai-dlc-update`.** The skill owns resolving the ref, gating its own self-update,
   carrying the machinery slice and emitting the worklist; none of that is re-described here.
   The rehearsal predicts ONE leg — `self-update-gate.sh` returned `SELF-UPDATE-OK` because the
   range changes no `core/scripts/` path. **If it returns `SELF-UPDATE-DEFER` and names a safe
   stop, that is a split and this file did not predict it: run the two legs, and say so in your
   report.**

3. **Assert the two reconcile files landed TOGETHER, before you do anything else with the tree.**
   This is the hazard named at the top:

   ```
   grep -c ADJ_KEEP_VERDICT .claude/skills/ai-dlc-update/reconcile/layer-drift.sh   # want >= 1
   grep -c ADJ_KEEP_VERDICT .claude/skills/ai-dlc-update/reconcile/apply.sh         # want >= 1
   grep -c ADJ_ROW_TOKEN    .claude/skills/ai-dlc-update/reconcile/apply.sh         # control: >= 1 before AND after this pull
   ```

   The control is there because the first two returning 1 tells you the strings arrived; only a
   token that was already present tells you the grep and the path are right. **If `apply.sh` has
   the new name and `layer-drift.sh` does not, STOP and ping** — do not run another apply.

4. **Compare the run's manifest against the `## Rehearsal` table.** Report BOTH, whether or not
   they agree. If they disagree, stop and ping before disposing of any row.

5. **Dispose of the worklist rows the run emits.** The rehearsal expects three
   `WORKLIST extension-title-match` rows, and **all three are PRE-EXISTING** — they describe
   entries whose headings name a core section, and they are not caused by this range. They are
   still work with an owner; `apply` is not clean while one is outstanding. Disposing of them is
   the same judgment it was last pull, and nothing in this range changes it.

6. **Close the candidate, by id.** Run `ledger-reverify` **from the consumer root** — a
   distribution-root run has turned a live `STILL-LIVE` into a `CLOSE-CANDIDATE`, and a false
   close retires a live entry. The id this range discharges:

   - `PC-S307-RECORDED-VERDICT-SUPPRESSES-THE-REMEDY-IT-AUTHORIZES`

   Report which ids closed and which did not, by name, and do not close one the tool did not.

7. **Measure what this fix does to YOUR register, and report the number.** It is the one figure
   the distribution cannot take for you, and the rehearsal says it is **zero rows changed today**:
   of the non-keep verdicts recorded in
   `_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl`, exactly one is against an
   `overrides/` entry and the digest that currently resolves for it carries `still-additive`, so
   the manifest is byte-identical before and after. That is the honest expectation and not a
   defect. **If your run emits an ATOMIC `override-retire` sequence where the previous pull
   emitted a `NOTE override-adjudicated`, that is the fix firing** — read the rows, check they
   name the action you expect, and report them.

8. **Report to the operator**, including an early stop. Then stop. You do not edit this file.

9. **DISTRIBUTION SESSION ONLY — after the run reports and the range has merged, re-derive this
   file's own RESUME block and prove it is resumable, then write `## Discharge` and retitle the
   file.** This is a numbered action because it is the step that decays silently: the merge is
   the moment the block above stops being an instruction and becomes a description of finished
   work, and a session that stops there hands the next one an order to redo the pull. Run the
   `## Rehearsal` figures again against the tree as it now stands and DIFF them against what this
   file claims — not "does it look right"; fix the file wherever they disagree, and fix the
   COMMAND and not only the prose, because a resuming session runs the command. Then
   `bash scripts/validate-plan-shape.sh`, which is the floor and not the answer: it cannot see
   whether an action is stale. **It is addressed to a distribution session and to nobody else** —
   the executing consumer session reports its numbers and stops, because this file lives in a
   repo that session is forbidden to write.

### Ping the operator

On any question, on any decision, on completion, and on any early stop. From outside, a session
that is thinking and a session that is waiting on a human look identical.

### Done when

1. `.claude/.ai-dlc-version` reads `0.433.0` on `version`, `commit`, `skill_version` and
   `skill_commit`. Observation point: after the apply completes, before any further work.
2. `.claude/.ai-dlc-applying` is absent, at the same observation point.
3. Action 3's two greps both return non-zero with the control also non-zero.
4. `ledger-reverify`, run from the consumer root, has been run and its verdict for
   `PC-S307-RECORDED-VERDICT-SUPPRESSES-THE-REMEDY-IT-AUTHORIZES` reported by name — whatever
   that verdict is. **This criterion is satisfied by REPORTING the verdict, not by it being a
   close**: the tool decides, and a runbook that demanded a particular answer would be asking its
   executor to produce one.
5. Every worklist row the run emitted is disposed of, so `apply` reports clean.

## Rehearsal

**Measured on `file://` clones of BOTH trees, against the consumer's committed baseline, with the
distribution at the merge commit for 0.433.0. Nothing was written to either real repo.** These are
expectations. A disagreement is a reason to stop and ping, not a reason to adjust the run.

```
core/ paths changed in the range                3     (control: an impossible pathspec -> 0)
  reconcile/apply.sh, reconcile/layer-drift.sh, fixtures/apply-worklist-rows/run.sh
mode-only changes (modes differ, blobs equal)   0
self-update-gate.sh                             SELF-UPDATE-OK -- no core/scripts/ path in range
preclassify                                     3 rows, all M
layer-drift                                     51 rows: 37 EXTENSION-OK, 8 OVERRIDE-OK,
                                                3 EXTENSION-TITLE-MATCHES-CORE,
                                                1 OVERRIDE-SUPERSEDED,
                                                1 OVERRIDE-ASSERTS-SHADOW-SURVIVES,
                                                1 EXTENSION-RESTATES-CORE
apply manifest                                  3 RESOLVED pure-apply
                                                3 WORKLIST extension-title-match (PRE-EXISTING)
                                                1 NOTE    override-adjudicated
                                                1 DECISION restamp-withheld
```

**The differential that matters, taken with both sides asserted to differ by md5 before it was
read**: the old `apply.sh` and the new one produce the SAME adjudicated row against this
consumer's current register — `NOTE override-adjudicated`, verdict `still-additive`. The fix is
correct and moves nothing here today, because the only override-level record whose digest
currently resolves is a keep. Where the non-keep verdicts actually sit is the extension side:
**20 non-keep records, 19 of them against `extensions/` entries**, and those are a separate
unfixed gap (`BL-119` in the distribution's backlog), not something this pull changes.

## Discharge

*Empty. Written and committed by a DISTRIBUTION session in `/Users/n8/git/ai-dlc` after the run
reports, never by the executing consumer session. When it is written, retitle this file
`DISCHARGED — DO NOT EXECUTE` at the top: a spent runbook still reading as instructions is this
directory's recurring hazard, measured once at 5 of 6 files.*
