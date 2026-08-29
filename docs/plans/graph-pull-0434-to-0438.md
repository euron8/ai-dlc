# Pull the graph consumer from 0.434.0 to 0.438.0

## RESUME HERE

**Resume with exactly: `READ and FOLLOW docs/plans/graph-pull-0434-to-0438.md`.** This block is the
current state. Everything under `## Rehearsal` is an EXPECTATION measured before the run, not a
guarantee, and `## Discharge` is empty until the run reports.

**Status: WRITTEN, REHEARSED, NOT STARTED.** Asking for this file is not the act of dispatching the
run — **do not start until the operator says to start.** A previous deferral does not carry forward
as approval, and neither does the existence of this paragraph.

**IT SUPERSEDES `docs/plans/graph-pull-0434-to-0437.md`, WHICH MUST NOT BE EXECUTED.** That file was
written and rehearsed for a machinery-only range, and `v0.438.0` then added a RULEBOOK file to it.
Its Done-when 1 checks the stamp reads `0.437.0`, but the skill resolves `theirs` at run time and
will now deliver `0.438.0` — so following it would fail on a criterion that cannot be met and would
predict a one-leg pull that no longer exists. Superseded rather than patched, because its RANGE
changed, which is the condition its own action 9 names.

**THE RANGE NOW SPLITS INTO TWO LEGS, AND THE GATE PRESCRIBES THE SPLIT RATHER THAN YOU.**
`v0.438.0` changes `steps/route.md`, which is rulebook, and roughly three dozen fixtures are coupled
to rulebook — so `self-update-gate.sh` returns `SELF-UPDATE-DEFER rulebook-coupled-fixtures` and
emits a `SELF-UPDATE-SAFE-STOP` naming the `0.437.0` commit. Leg 1 runs to the stop the gate names;
leg 2 completes. **The gate names the stop itself; no sha is written into this file.**

**The superseded runbook's rehearsal is not wasted — it IS leg 1**, and its figures are reproduced
below as the leg-1 row of the table.

**THE CONSUMER IS PAUSED, AND THAT WAS VERIFIED RATHER THAN ASSUMED.** Its continuation log records
`USER_PAUSE` followed by `ALLOWED_BY_PAUSE`, and `.claude/.ai-dlc-applying` is absent. **Re-verify
both at execution time** — the pause is a state, not a property, and this file was written before
you were dispatched.

### THE HANDOFF THAT PRODUCED THIS PAUSE TOOK THREE ATTEMPTS, AND THIS RANGE CARRIES THE FIX.

Operator-reported: the first handoff did not run all of the handoff steps; a second, invoked as
`/ai-dlc handoff`, **resumed the pipeline instead of handing off**; a third, typed as the bare word
`handoff`, ran every step.

`v0.438.0` closes both halves of that (`BL-125`). But **the fix is in the range you are delivering,
so it is not in the copy you are running.** Until leg 2 lands, the consumer's installed `route.md`
still has the old Step 0.

**So the only skill you invoke in that tree is `/ai-dlc-update`. Do not type `/ai-dlc <anything>`
else, and do not type a bare `handoff` or `resume`** — on the installed router those fall through to
Step 1 fresh-pipeline routing, and Step 6 then archives the paused sprint's snapshot as stale.

### Start here

**This session's PROJECT ROOT is `/Users/n8/git/graph`.** Skill scope follows the session root, not
a Bash `cd` — a session rooted in the distribution cannot invoke the skill at all. If your root is
anywhere else, stop and ping.

**`/Users/n8/git/graph` is the tree this run writes, and the pull itself is what writes it.**
`/Users/n8/git/ai-dlc` is READ ONLY for you: read it freely, write nothing there. **You do not
discharge this file** — a distribution session does that from its own repo. Report your numbers and
stop.

**The consumer's tree is DIRTY and that is EXPECTED** — live `_bmad-output/` pipeline state. **Do
not commit, revert, stash or clean it.** The set of dirty paths grows while the pipeline runs, so it
is deliberately not enumerated here.

**CHECK BRANCH TRACKING BEFORE YOU INVOKE ANYTHING.** `SKILL.md` step 1 treats a branch with **no
upstream configured** as `AUTO-PUSH`, and the preflight runs on EVERY invocation — so
`/ai-dlc-update` in any form, including a bare dry run, publishes the current branch to origin. Run
`git rev-parse --abbrev-ref --symbolic-full-name @{u}`; if it is fatal, stop and ping. At rehearsal
time the working branch tracked its own upstream and was level with it. This is `PC-S336`.

The version stamp is `.claude/.ai-dlc-version`. Read the base from there; **no sha and no ref is
written into this file**, because the skill resolves them and anything written down goes stale.

### Numbered actions

1. **Confirm the project root is `/Users/n8/git/graph`**, then read `.claude/.ai-dlc-version` and
   confirm `0.434.0` on all four fields. A different value means this runbook is for a range you are
   not in — stop and ping.

2. **CONFIRM THE PIPELINE IS STILL PAUSED, AND DO NOT RESUME IT.** Read the tail of
   `_bmad-output/pipeline-continuation-log.md` and confirm the most recent decision is a pause
   rather than a live beat, and that `.claude/.ai-dlc-applying` is absent. **If a sprint is running,
   stop and ping; do not pause it yourself.**

3. **Run `/ai-dlc-update`, and expect TWO LEGS.** The rehearsal predicts
   `SELF-UPDATE-DEFER rulebook-coupled-fixtures` naming `route.md`, plus a `SELF-UPDATE-SAFE-STOP`
   at the `0.437.0` commit. Run leg 1 to the stop the gate names, then leg 2 to complete. **The
   skill owns resolving the ref, gating its self-update, carrying the machinery slice and emitting
   the worklist; none of that is re-described here.** If the gate does NOT defer, that disagrees
   with the rehearsal — stop and ping rather than proceeding on the difference.

4. **Compare each leg's manifest against the `## Rehearsal` table. Report BOTH, agreeing or not.**
   The full range is **15 rows, 13 `UPSTREAM-ONLY` and 2 `UPSTREAM-ONLY-ADD`, ZERO `->CLASSIFY`**;
   leg 1 is a strict subset at 13 rows and leg 2 adds exactly two. **A `->CLASSIFY` row is the
   disagreement most worth stopping on** — it means the consumer edited a machinery path since the
   last pull and the rehearsal could not see it. Do not dispose of such a row; stop and ping.

5. **Assert the derived fixtures were NAMED and ran, after EACH leg.** This range ships the fix that
   makes step 2's fixture term include the fixtures the diff itself touches
   (`core/skills/ai-dlc-update/SKILL.md:233`), enforced by a coverage join in
   `core/skills/ai-dlc-update/reconcile/self-update-fixtures.sh:119`. Leg 1 should name five:

   ```
   consumer-machinery-inventory   layer-conforms-to   layer-entry-unreadable
   self-update-fixture-log        self-update-gate
   ```

   **If the runner refuses with `the slice omits fixtures this diff CHANGES`, that is the new arm
   firing and it is a real finding — report the named directories verbatim and stop.** If it refuses
   with `COVERAGE: UNRESOLVABLE` or `COVERAGE: WRONG-REPO`, stop and ping: those mean the join could
   not run, which is not the same as it finding nothing.

   `layer-entry-unreadable` is NEW and arrives as two `UPSTREAM-ONLY-ADD` rows. A `MISS` verdict for
   it means the slice did not write it, which is a finding about the cycle rather than the fixture.

6. **Dispose of the worklist rows from BOTH legs.** `apply` is not clean while one is outstanding.
   The rehearsal emitted no `->CLASSIFY` row, so any adjudication row is new information — report it
   before disposing of it.

7. **After leg 2, confirm the router fix actually landed**, because it is the reason this range is
   two legs and it is the one file a rulebook deferral could strand:

   ```
   grep -c 'ai-dlc resume' .claude/skills/ai-dlc/steps/route.md     # want >= 1
   grep -c 'STEP_LOADED_TOKEN: route' .claude/skills/ai-dlc/steps/route.md   # control: 1 before AND after
   ```

   **Pre-pull baseline, measured on your tree at `0.434.0`: the first is `0`, the control is `1`.**
   So a post-pull `0` on the first is unambiguous. If the control is not 1 both times, the grep is
   reading the wrong file — stop and ping.

8. **Close the candidates, by id.** Run `ledger-reverify` **from the consumer root** — a
   distribution-root run has turned a live `STILL-LIVE` into a `CLOSE-CANDIDATE`, and a false close
   retires a live entry. The four ids this range discharges, each verified in-range against an
   impossible-id control:

   - `PC-S307-AWK-CANT-OPEN-FILE-MISREAD-AS-MISSING-FRONTMATTER`
   - `PC-S307-MACHINE-AUDITS-IS-A-CHILD-OF-4A-SO-EVERY-4A-SHADOW-SWALLOWS-IT`
   - `PC-S330-STEP-2-HAS-NO-DISPOSITION-FOR-A-CONSUMER-MODIFIED-MACHINERY-PATH`
   - `PC-S318-SELF-UPDATE-SLICE-CANNOT-CARRY-THE-FIXTURE-FIX-THAT-UNBLOCKS-ITS-OWN-PUSH`

   Report which closed and which did not, **by name and whatever the verdict is**. Do not close one
   the tool did not. **`BL-125`'s fix carries no `PC-` id** — it was filed distribution-side from an
   operator report, so expect no ledger row for it and do not go looking for one.

   Ten further ids read as discharged upstream but their discharging commits are NOT in this range —
   they landed at or before the base. If `ledger-reverify` closes any of them too, that is an
   incidental close; report it, do not chase it.

9. **Report to the operator**, including an early stop. Then stop. You do not edit this file.

10. **DISTRIBUTION SESSION ONLY — after the run reports, re-derive this file's own RESUME block and
    prove it is resumable, then write `## Discharge` and retitle the file
    `DISCHARGED — DO NOT EXECUTE`.** The report is the moment the block above stops being an
    instruction and becomes a description of finished work. Re-run the `## Rehearsal` commands and
    DIFF them against what this file claims; **fix the COMMAND and not only the prose, because a
    resuming session runs the command.** Then `bash scripts/validate-plan-shape.sh`, which is the
    floor and not the answer. **A SCHEDULING DECISION STALES THIS FILE AS SURELY AS A RUN DOES** —
    this file exists because that happened to its predecessor within hours of it being written.

### Ping the operator

On any question, on any decision, on completion, and on any early stop. From outside, a session that
is thinking and a session that is waiting on a human look identical.

### Done when

1. `.claude/.ai-dlc-version` reads `0.438.0` on all four fields. Observation point: after leg 2
   completes, before any further work.
2. `.claude/.ai-dlc-applying` is absent, at the same observation point.
3. Action 7's grep returns non-zero with its control at 1, checked after leg 2.
4. The derived-fixture runner's log exists under `_bmad-output/ai-dlc-update/` for each leg and its
   summary line has been reported verbatim — **whatever it says.** Satisfied by REPORTING, not by a
   green run.
5. `ledger-reverify`, run from the consumer root, has been run and its verdict for each of the four
   ids in action 8 reported by name — **whatever that verdict is.** Satisfied by REPORTING, not by a
   close: the tool decides, and a runbook demanding a particular answer would be asking its executor
   to produce one.
6. Every worklist row emitted by either leg is disposed of, so `apply` reports clean.
7. The pipeline is left PAUSED, exactly as you found it. You do not resume it.

## Rehearsal

**Measured on `file://` clones of BOTH trees on 2026-08-29** — consumer cloned at its committed
handoff checkpoint on its working branch, distribution at the `0.438.0` release. Clone paths were
asserted to differ from the live trees before anything was read. **These are EXPECTATIONS. If the
real run disagrees on any row, that disagreement is information and is worth more than a clean
report — stop and ping rather than reconciling it yourself.**

| what | expected |
|---|---|
| self-update gate | `SELF-UPDATE-DEFER rulebook-coupled-fixtures` naming `route.md`, plus `SELF-UPDATE-SAFE-STOP` at the `0.437.0` commit |
| `SELF-UPDATE-CARRY` rows | 0 — the consumer's `.githooks/pre-push` is byte-identical to its base copy |
| full-range manifest rows | 15 |
| `UPSTREAM-ONLY` | 13 |
| `UPSTREAM-ONLY-ADD` | 2 (`layer-entry-unreadable/run.sh`, `.../seed.sh`) |
| `->CLASSIFY` | **0** |
| leg 1 rows | 13 — a strict SUBSET of the full range, asserted, not assumed |
| leg 2 adds | exactly 2: `.claude/skills/ai-dlc/steps/route.md`, `tests/fixtures/resume-whole-read/run.sh` |
| templates | 4, all `TEMPLATE-UNCHANGED-NOOP` |
| leg-1 derived fixtures, full slice written | **5 green, 0 red, 0 missing, of 5 named** |

**THE FIXTURE FIGURE HAS A PRECONDITION AND THE FIRST ATTEMPT AT IT WAS WRONG.** Run against a clone
with only the fixture files copied in, all five came back RED — they were asserting against
machinery still at `ours`. With the full slice written from `theirs`, the same five are green. A red
fixture result on the real run therefore means something different depending on whether the slice
landed; check the slice is complete before reading the verdict.

**WHAT THE REHEARSAL COULD NOT COVER.** It wrote the slice by hand rather than driving step 2, so it
exercised the coverage join and the fixture run but not the skill's own branch/commit/push cycle.
**Leg 2's fixture run was not rehearsed at all** — it depends on a rulebook state that only exists
after leg 1 lands, and constructing it by hand would have been a second implementation of the thing
under test. And a `->CLASSIFY` row cannot appear in a rehearsal taken while the consumer has no
divergence: the zero above says "none today", not "none possible".

**THE BOOTSTRAPPING HAZARD WAS MEASURED, NOT WARNED ABOUT.** The range changes
`.claude/skills/ai-dlc-update/SKILL.md` and `reconcile/self-update-fixtures.sh` — step-2 machinery —
so the consumer's INSTALLED step 2 classifies the release that repairs it. It does not bite:
`self-update-fixtures.sh` is a changed machinery path and `core/fixtures/self-update-fixture-log`
names it, so the unfixed derivation still reaches this release's own fixture. Mode-only changes in
the range: **0**, against a control of 2 rows whose modes differ at all, both adds. `preclassify.sh`,
`apply.sh` and `ledger-reverify.sh` are NOT in the range. The one rulebook path is
`core/skills/ai-dlc/steps/route.md`, declared rulebook by
`core/skills/ai-dlc-update/reconcile/setup-sites.md:225`, and it is the whole reason the gate defers.

## Discharge

*Empty until the run reports. The distribution session that fills this in also retitles the file.*
