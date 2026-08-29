# Pull the graph consumer from 0.434.0 to 0.437.0

## RESUME HERE

**Resume with exactly: `READ and FOLLOW docs/plans/graph-pull-0434-to-0437.md`.** This block is the
current state. Everything under `## Rehearsal` is an EXPECTATION measured before the run, not a
guarantee, and everything under `## Discharge` is empty until the run reports.

**Status: WRITTEN, REHEARSED, NOT STARTED.** The operator asked for this file on 2026-08-29 with
the consumer paused mid-sprint following a handoff. Asking for the runbook is not the same act as
dispatching the run — **do not start until the operator says to start.** A previous deferral does
not carry forward as approval, and neither does the existence of this paragraph.

**THE RANGE IS ONE LEG.** The gate returns `SELF-UPDATE-OK` and names no safe stop, so there is no
split to plan around. That is the single most useful thing rehearsal established and it is the
opposite of the previous two runbooks, both of which had to be written for two legs.

**THE CONSUMER IS PAUSED, AND THAT WAS VERIFIED RATHER THAN ASSUMED.** Its continuation log records
`USER_PAUSE` followed by `ALLOWED_BY_PAUSE`, and `.claude/.ai-dlc-applying` is absent. **Re-verify
both at execution time** — the pause is a state, not a property, and this file was written before
you were dispatched.

### THE HANDOFF THAT PRODUCED THIS PAUSE TOOK THREE ATTEMPTS. READ THIS BEFORE YOU TYPE ANYTHING.

Operator-reported, and it is the reason action 2 exists: the first handoff **did not run all of the
handoff steps**; a second attempt invoked as `/ai-dlc handoff` **resumed the pipeline instead of
handing off**; a third, invoked as bare `handoff`, ran every step.

**The consequence for you is narrow and absolute: the only skill you invoke in that tree is
`/ai-dlc-update`.** Do not type `/ai-dlc <anything>`. On the reported evidence that form can
RESUME the sprint, and resuming a sprint underneath a machinery pull is the precise state this
whole runbook exists to avoid.

What the consumer's own log does and does not settle, so you do not over-read it: the pause hook
fired on **every** attempt including the slash form, so the paused state is trustworthy. A
`HANDOFF_GUARD_BLOCK (1/3)` is recorded, which is consistent with the incomplete first handoff.
Whether the slash form dispatches differently is a SKILL question the log cannot answer, and it is
not yours to investigate here — report it and move on.

### Start here

**This session's PROJECT ROOT is `/Users/n8/git/graph`.** Skill scope follows the session root, not
a Bash `cd` — a session rooted in the distribution cannot invoke the skill at all. If your root is
anywhere else, stop and ping.

**`/Users/n8/git/graph` is the tree this run writes, and the pull itself is what writes it.**
`/Users/n8/git/ai-dlc` is READ ONLY for you: read it freely, write nothing there. **You do not
discharge this file** — a distribution session does that from its own repo, where this file is
subject to that repo's gate. Report your numbers and stop.

**The consumer's tree is DIRTY and that is EXPECTED** — live `_bmad-output/` pipeline state. **Do
not commit, revert, stash or clean it.** The set of dirty paths grows while the pipeline runs, so
it is deliberately not enumerated here.

**CHECK BRANCH TRACKING BEFORE YOU INVOKE ANYTHING.** `SKILL.md` step 1 treats a branch with **no
upstream configured** as `AUTO-PUSH`, and the preflight runs on EVERY invocation — so
`/ai-dlc-update` in any form, including a bare dry run, publishes the current branch to origin.
Run `git rev-parse --abbrev-ref --symbolic-full-name @{u}`; if it is fatal, stop and ping. At
rehearsal time the working branch tracked its own upstream and was level with it, so this is
expected to be quiet. This is `PC-S336`.

The version stamp is `.claude/.ai-dlc-version`. Read the base from there; **no sha and no ref is
written into this file**, because the skill resolves them and anything written down goes stale.

### Numbered actions

1. **Confirm the project root is `/Users/n8/git/graph`**, then read `.claude/.ai-dlc-version` and
   confirm `0.434.0` on all four fields. A different value means this runbook is for a range you
   are not in — stop and ping.

2. **CONFIRM THE PIPELINE IS STILL PAUSED, AND DO NOT RESUME IT.** Read the tail of
   `_bmad-output/pipeline-continuation-log.md` and confirm the most recent decision is a pause
   rather than a live beat, and that `.claude/.ai-dlc-applying` is absent. **If a sprint is
   running, stop and ping; do not pause it yourself.** This range replaces step-2 machinery, so
   pulling under a live sprint swaps the pipeline's own tooling out from under a run using it.

3. **Run `/ai-dlc-update`, and expect ONE LEG.** The rehearsal predicts `SELF-UPDATE-OK` with no
   `SELF-UPDATE-DEFER` and no `SELF-UPDATE-SAFE-STOP`. **The skill owns resolving the ref, gating
   its self-update, carrying the machinery slice and emitting the worklist; none of that is
   re-described here.** If the gate DOES defer or name a stop, that disagrees with the rehearsal —
   stop and ping rather than proceeding on the difference.

4. **Compare the manifest against the `## Rehearsal` table. Report it, agreeing or not.** The
   expectation is **13 rows, 11 `UPSTREAM-ONLY` and 2 `UPSTREAM-ONLY-ADD`, and ZERO `->CLASSIFY`**
   — no consumer divergence anywhere in the range. **A `->CLASSIFY` row is the one disagreement
   most worth stopping on**, because it means the consumer edited a machinery path since the last
   pull and the rehearsal could not see it. Do not dispose of such a row; stop and ping.

5. **Assert the five derived fixtures were NAMED and ran.** This range ships the fix that makes
   step 2's fixture term include the fixtures the diff itself touches
   (`core/skills/ai-dlc-update/SKILL.md:233`), enforced by a coverage join in
   `core/skills/ai-dlc-update/reconcile/self-update-fixtures.sh:119`. **This pull is the first real
   exercise of that code.** The five it should name:

   ```
   consumer-machinery-inventory   layer-conforms-to   layer-entry-unreadable
   self-update-fixture-log        self-update-gate
   ```

   The runner writes `_bmad-output/ai-dlc-update/self-update-fixtures-<ts>.md`. **If it refuses
   with `the slice omits fixtures this diff CHANGES`, that is the new arm firing and it is a real
   finding — report the named directories verbatim and stop.** If it refuses with
   `COVERAGE: UNRESOLVABLE` or `COVERAGE: WRONG-REPO`, stop and ping: those mean the join could not
   run, which is not the same as it finding nothing.

   Note that `layer-entry-unreadable` is NEW — it arrives in this pull as two `UPSTREAM-ONLY-ADD`
   rows. A `MISS` verdict for it means the slice did not write it, which is a finding about the
   cycle rather than about the fixture.

6. **Dispose of the worklist rows.** `apply` is not clean while one is outstanding. The rehearsal
   emitted no `->CLASSIFY` row, so any adjudication row you see is new information — report it
   before disposing of it.

7. **Close the candidates, by id.** Run `ledger-reverify` **from the consumer root** — a
   distribution-root run has turned a live `STILL-LIVE` into a `CLOSE-CANDIDATE`, and a false close
   retires a live entry. The four ids this range discharges, each verified in-range against an
   impossible-id control:

   - `PC-S307-AWK-CANT-OPEN-FILE-MISREAD-AS-MISSING-FRONTMATTER`
   - `PC-S307-MACHINE-AUDITS-IS-A-CHILD-OF-4A-SO-EVERY-4A-SHADOW-SWALLOWS-IT`
   - `PC-S330-STEP-2-HAS-NO-DISPOSITION-FOR-A-CONSUMER-MODIFIED-MACHINERY-PATH`
   - `PC-S318-SELF-UPDATE-SLICE-CANNOT-CARRY-THE-FIXTURE-FIX-THAT-UNBLOCKS-ITS-OWN-PUSH`

   Report which closed and which did not, **by name and whatever the verdict is**. Do not close one
   the tool did not.

   **Ten further ids read as discharged upstream but their discharging commits are NOT in this
   range** — they landed at or before the base. If `ledger-reverify` closes any of them too, that
   is an incidental close and it is welcome; report it, do not chase it.

8. **Report to the operator**, including an early stop. Then stop. You do not edit this file.

9. **DISTRIBUTION SESSION ONLY — after the run reports, re-derive this file's own RESUME block and
   prove it is resumable, then write `## Discharge` and retitle the file
   `DISCHARGED — DO NOT EXECUTE`.** The report is the moment the block above stops being an
   instruction and becomes a description of finished work. Re-run the `## Rehearsal` commands and
   DIFF them against what this file claims; **fix the COMMAND and not only the prose, because a
   resuming session runs the command.** Then `bash scripts/validate-plan-shape.sh`, which is the
   floor and not the answer. **A SCHEDULING DECISION STALES THIS FILE AS SURELY AS A RUN DOES** —
   if the operator changes the range, supersede this file rather than patching it.

### Ping the operator

On any question, on any decision, on completion, and on any early stop. From outside, a session
that is thinking and a session that is waiting on a human look identical.

### Done when

1. `.claude/.ai-dlc-version` reads `0.437.0` on all four fields. Observation point: after the
   single leg completes, before any further work.
2. `.claude/.ai-dlc-applying` is absent, at the same observation point.
3. The derived-fixture runner's log exists under `_bmad-output/ai-dlc-update/` and its summary line
   has been reported verbatim — **whatever it says.** Satisfied by REPORTING, not by a green run.
4. `ledger-reverify`, run from the consumer root, has been run and its verdict for each of the four
   ids in action 7 reported by name — **whatever that verdict is.** Satisfied by REPORTING, not by
   a close: the tool decides, and a runbook demanding a particular answer would be asking its
   executor to produce one.
5. Every worklist row emitted by the leg is disposed of, so `apply` reports clean.
6. The pipeline is left PAUSED, exactly as you found it. You do not resume it.

## Rehearsal

**Measured on `file://` clones of BOTH trees on 2026-08-29** — consumer cloned at its committed
handoff checkpoint on its working branch, distribution at `origin/main`. Clone paths were asserted
to differ from the live trees before anything was read. **These are EXPECTATIONS. If the real run
disagrees on any row, that disagreement is information and is worth more than a clean report —
stop and ping rather than reconciling it yourself.**

| what | expected |
|---|---|
| self-update gate | `SELF-UPDATE-OK`, 1 row, no `DEFER`, no `SAFE-STOP` |
| `SELF-UPDATE-CARRY` rows | 0 — the consumer's `.githooks/pre-push` is byte-identical to its base copy |
| manifest rows | 13 |
| `UPSTREAM-ONLY` | 11 |
| `UPSTREAM-ONLY-ADD` | 2 (`layer-entry-unreadable/run.sh`, `.../seed.sh`) |
| `->CLASSIFY` | **0** |
| templates | 4, all `TEMPLATE-UNCHANGED-NOOP` |
| derived fixtures named | 5 |
| derived fixture run, full slice written | **5 green, 0 red, 0 missing, of 5 named** |

The thirteen consumer destinations:

```
tests/fixtures/consumer-machinery-inventory/run.sh        tests/fixtures/layer-conforms-to/run.sh
tests/fixtures/layer-entry-unreadable/run.sh              tests/fixtures/layer-entry-unreadable/seed.sh
tests/fixtures/self-update-fixture-log/run.sh             tests/fixtures/self-update-fixture-log/seed.sh
tests/fixtures/self-update-gate/run.sh                    scripts/ai-dlc/validate-layer-entries.sh
.claude/skills/ai-dlc-update/SKILL.md                     .claude/skills/ai-dlc-update/reconcile/self-update-fixtures.sh
.claude/skills/ai-dlc-update/reconcile/self-update-gate.sh .claude/skills/ai-dlc-update/reconcile/setup-sites.md
.claude/skills/ai-dlc/core-manifest.md
```

**THE FIXTURE FIGURE HAS A PRECONDITION AND THE FIRST ATTEMPT AT IT WAS WRONG.** Run against a
clone with only the fixture files copied in, all five came back RED — because they were asserting
against machinery still at `ours`. With the **full thirteen-row slice** written from `theirs`, the
same five are green. A red fixture result on the real run therefore means something different
depending on whether the slice landed; check that the slice is complete before reading the verdict.

**WHAT THE REHEARSAL COULD NOT COVER.** It wrote the slice by hand rather than driving step 2, so it
exercised the coverage join and the fixture run but not the skill's own branch/commit/push cycle.
And a `->CLASSIFY` row cannot appear in a rehearsal taken while the consumer has no divergence — the
zero above says "none today", not "none possible", which is exactly why action 4 tells you to stop
on one rather than dispose of it.

**THE BOOTSTRAPPING HAZARD WAS MEASURED, NOT WARNED ABOUT.** This range changes
`.claude/skills/ai-dlc-update/SKILL.md` and `reconcile/self-update-fixtures.sh` — step-2 machinery —
so the consumer's INSTALLED step 2 classifies the very release that repairs it. It does not bite:
`self-update-fixtures.sh` is a changed machinery path and `core/fixtures/self-update-fixture-log`
names it, so the unfixed derivation still reaches this release's own fixture. Mode-only changes in
the range: **0**, against a control of 2 rows whose modes differ at all, both of them adds.
`preclassify.sh`, `apply.sh` and `ledger-reverify.sh` are NOT in the range. Everything in it is
machinery by `core/skills/ai-dlc-update/reconcile/setup-sites.md:225`; no rulebook path is included,
which is why the gate does not defer.

## Discharge

*Empty until the run reports. The distribution session that fills this in also retitles the file.*
