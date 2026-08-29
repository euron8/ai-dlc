# DISCHARGED — DO NOT EXECUTE

# Pull the graph consumer from 0.434.0 to 0.438.0

## RESUME HERE

**Status: DISCHARGED. Both phases ran and landed; nothing below is an instruction any more.**
The consumer stamp reads **0.438.0 / `1b9f53ec`** on all four fields — this distribution's
`origin/main` at the time of the run — and all seven Done-when criteria are met. The numbered
actions are retained as a record of what was done. See `## Discharge` for the measured outcome and
for the two figures this file got wrong.

**Resume with exactly: `READ and FOLLOW docs/plans/graph-pull-0434-to-0438.md`.** This block is the
current state. Everything under `## Rehearsal` is an EXPECTATION measured before the run, not a
guarantee.

**The authorization recorded below is SPENT.** It named one range, one executor and one date, and
that range has landed. A later pull is not authorized by anything in this file.

**Status: AUTHORIZED — PHASE 1 MAY START.** The operator authorized this pull on 2026-08-29 and
named `graph-70`, rooted in `/Users/n8/git/graph`, as the executor. **That decision covers PHASE 1
and nothing else.**

**PHASE 2's apply is a SEPARATE approval and this line does not carry it.** Present it and stop, per
numbered action 4.

**THIS AUTHORIZATION IS SPENT THE MOMENT THIS RUN REPORTS.** It names one range, one executor and
one date. It does not carry to the next range, and a later session reading this paragraph has not
been told to start anything — the standing ruling in `.claude/rules/operator-rulings.md` governs
again from that point.

An earlier revision of this block read `WRITTEN, REHEARSED, NOT STARTED` with `do not start until
the operator says to start`. The executor read it and correctly declined to run, because the
authorization was recorded in `docs/plans/graph-ledger-full-drain.md` and never in this file. **The
authorization belongs in the file that gets followed**, which is why it is here rather than in the
dispatching message.

**IT SUPERSEDES `docs/plans/graph-pull-0434-to-0437.md`, WHICH MUST NOT BE EXECUTED.** That file was
written and rehearsed for a machinery-only range, and `v0.438.0` then added a RULEBOOK file to it.
Its Done-when 1 checks the stamp reads `0.437.0`, but the skill resolves `theirs` at run time and
will now deliver `0.438.0` — so following it would fail on a criterion that cannot be met and would
predict a one-leg pull that no longer exists, and it is silent about the operator gate
the real range ends in. Superseded rather than patched, because its RANGE
changed, which is the condition its own action 9 names.

**THE RANGE SPLITS INTO TWO PHASES, AND THE SECOND ONE IS NOT A SECOND SELF-UPDATE.** This was
measured by rehearsing each phase separately, and the first draft of this file got it wrong.

`v0.438.0` changes `steps/route.md`, which is rulebook, and roughly three dozen fixtures are coupled
to rulebook — so `self-update-gate.sh` returns `SELF-UPDATE-DEFER rulebook-coupled-fixtures` and
emits a `SELF-UPDATE-SAFE-STOP` naming the `0.437.0` commit.

- **PHASE 1 — an autonomous self-update to the stop the gate names.** Rehearsed at that range the
  gate returns `SELF-UPDATE-OK`, so this phase cuts its own branch, runs its derived fixtures and
  auto-merges, exactly as an ordinary machinery pull does.
- **PHASE 2 — NOT another cycle. It is the operator-gated apply.** Rehearsed from the stop to
  upstream HEAD the gate returns `SELF-UPDATE-DEFER` again and its safe-stop row reads *"no
  intermediate release … self-updates cleanly"* — there is no further stop to run to.
  `SKILL.md:366-374` is explicit about what happens instead: **do NOT cut a branch and do NOT
  push.** The machinery slice is carried into the step-7 gated apply so machinery and rulebook land
  on ONE branch, and `skill_version`/`skill_commit` advance **with that apply**, via
  `reconcile/apply.sh --carried-machinery-slice`. **Do not set those two fields by hand.**

**So the stamp reaches `0.438.0` only through an operator-approved apply, not through a second
autonomous leg.** A session waiting for phase 2 to complete on its own will wait forever.

**The gate names the stop itself; no sha is written into this file.**

**The superseded runbook's rehearsal is not wasted — it IS phase 1**, and its figures are
reproduced below as the phase-1 row of the table rather than re-derived by a different method.

**THE CONSUMER IS PAUSED, AND THAT WAS VERIFIED RATHER THAN ASSUMED.** Its continuation log records
`USER_PAUSE` followed by `ALLOWED_BY_PAUSE`, and `.claude/.ai-dlc-applying` is absent. **Re-verify
both at execution time** — the pause is a state, not a property, and this file was written before
you were dispatched.

### THE HANDOFF THAT PRODUCED THIS PAUSE TOOK THREE ATTEMPTS, AND THIS RANGE CARRIES THE FIX.

Operator-reported: the first handoff did not run all of the handoff steps; a second, invoked as
`/ai-dlc handoff`, **resumed the pipeline instead of handing off**; a third, typed as the bare word
`handoff`, ran every step.

`v0.438.0` closes both halves of that (`BL-125`). But **the fix is in the range you are delivering,
so it is not in the copy you are running.** Until the phase-2 apply lands, the consumer's
installed `route.md` still has the old Step 0.

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

3. **Run `/ai-dlc-update` and read the gate's verdict before doing anything else.** The rehearsal
   predicts `SELF-UPDATE-DEFER rulebook-coupled-fixtures` naming `route.md`, plus a
   `SELF-UPDATE-SAFE-STOP` at the `0.437.0` commit. If the gate does NOT defer, that disagrees with
   the rehearsal — stop and ping rather than proceeding on the difference.

   **PHASE 1: re-invoke with the safe-stop ref the gate named**, which is what the skill's own
   description prescribes for this state — prefixing the invocation with a distribution ref stops
   short of upstream HEAD. That range self-updates autonomously.

4. **PHASE 2 IS AN OPERATOR-GATED APPLY, NOT A SECOND CYCLE. Do not wait for one, and do not force
   one.** From the stop to upstream HEAD the gate defers again with no further safe stop. Per
   `SKILL.md:366-374`: report the rows, do NOT cut a branch, do NOT push, and carry the machinery
   slice into the step-7 gated apply so machinery and rulebook land on one branch. The stamp
   advances **through that apply** — `reconcile/apply.sh --carried-machinery-slice` — and **you do
   not set `skill_version`/`skill_commit` by hand.**

   **That apply needs the operator's approval and it is not yours to grant.** Present it, then
   stop and ping.

5. **Compare each phase's manifest against the `## Rehearsal` table. Report BOTH, agreeing or not.**
   The full range is **15 rows, 13 `UPSTREAM-ONLY` and 2 `UPSTREAM-ONLY-ADD`, ZERO `->CLASSIFY`**;
   phase 1 is a strict subset at 13 rows and phase 2 is exactly two. **A `->CLASSIFY` row is the
   disagreement most worth stopping on** — it means the consumer edited a machinery path since the
   last pull and the rehearsal could not see it. Do not dispose of such a row; stop and ping.

6. **Assert the derived fixtures were NAMED and ran — PHASE 1 ONLY.** Phase 2 defers, and a
   deferred cycle cuts no branch and runs no derived fixtures, so there is no second fixture run to
   look for. This range ships the fix that makes step 2's fixture term include the fixtures the diff
   itself touches (`core/skills/ai-dlc-update/SKILL.md:233`), enforced by a coverage join in
   `core/skills/ai-dlc-update/reconcile/self-update-fixtures.sh:119`.

   **THE FIXTURE TERM HAS TWO HALVES AND THE SLICE IS THEIR UNION.** `SKILL.md:226-231` is TERM A —
   every `core/fixtures/<dir>/` whose `*.sh` NAMES a machinery path this diff touched.
   `SKILL.md:233-247` is TERM B — every `core/fixtures/<dir>/` THE DIFF ITSELF TOUCHES. Both
   exclusions are read at `theirs`: a `.dist-only` marker, and no `run.sh` at `theirs`.

   **Phase 1 should name TWENTY-FIVE.** Derived over the six changed machinery paths in this range,
   matching each in BOTH its distribution and its consumer spelling, union term B, minus two
   `.dist-only` dirs (`enforcement-map-sites`, `path-mapping-render`):

   ```
   blocker-adjudication-record   check-15-bypass                consumer-machinery-home
   consumer-machinery-inventory  core-paths-audit-diff          core-script-boundary
   core-write-guard              layer-absorption-retire        layer-anchor-declaration
   layer-artifact-path-prescriptions                            layer-catalog-collision
   layer-conforms-to             layer-contract-conformance     layer-crosswalk-home
   layer-entry-unreadable        layer-extends-grain            layer-qualifier-grain
   layer-reference-resolution    layer-retired-id-crosswalk     layer-title-join
   ledger-status-vocabulary      retired-layer-contract         self-update-fixture-log
   self-update-gate              self-update-join-gate
   ```

   **THE COVERAGE JOIN CANNOT CATCH AN UNDER-DERIVED TERM A, WHICH IS WHY THIS FIGURE IS WRITTEN
   OUT.** `self-update-fixtures.sh:119` joins the set you pass it against TERM B only, so a slice
   naming just term B's five passes the join and is still wrong by twenty dirs. The five are a
   SUBSET, not the answer: `core/scripts/validate-layer-entries.sh` changes `+143/-9` in this range
   and twelve to thirteen fixtures cover it, and stranding those is the state
   `SKILL.md:280-286` describes — the consumer's pre-push runs the WHOLE suite, not the slice, so an
   uncarried covering fixture goes red and blocks the very push this cycle is making.

   **An earlier revision of this action predicted five.** The rehearsal wrote its slice by hand and
   term A never entered it — the gap this file's own `WHAT THE REHEARSAL COULD NOT COVER` paragraph
   predicted, landing on the figure rather than on the cycle. The executor derived 25 from
   `SKILL.md` and stopped rather than proceeding on the difference, which is what action 5 asks for.

   **Derive it again yourself before naming it, and report your figure whatever it is.** Twenty-five
   is a measurement taken in the distribution tree, not a target to reproduce; if yours differs,
   that difference is the finding and it outranks this list.

   **If the runner refuses with `the slice omits fixtures this diff CHANGES`, that is the new arm
   firing and it is a real finding — report the named directories verbatim and stop.** If it refuses
   with `COVERAGE: UNRESOLVABLE` or `COVERAGE: WRONG-REPO`, stop and ping: those mean the join could
   not run, which is not the same as it finding nothing.

   `layer-entry-unreadable` is NEW and arrives as two `UPSTREAM-ONLY-ADD` rows. A `MISS` verdict for
   it means the slice did not write it, which is a finding about the cycle rather than the fixture.

7. **Dispose of the worklist rows from BOTH phases.** `apply` is not clean while one is outstanding.
   The rehearsal emitted no `->CLASSIFY` row, so any adjudication row is new information — report it
   before disposing of it.

8. **After the phase-2 apply, confirm the router fix actually landed.** It is the reason this range
   defers at all, and it is the one file a deferral strands if the apply is not carried through:

   ```
   grep -c 'ai-dlc resume' .claude/skills/ai-dlc/steps/route.md     # want >= 1
   grep -c 'STEP_LOADED_TOKEN: route' .claude/skills/ai-dlc/steps/route.md   # control: 1 before AND after
   ```

   **Pre-pull baseline, measured on your tree at `0.434.0`: the first is `0`, the control is `1`.**
   So a post-pull `0` on the first is unambiguous. If the control is not 1 both times, the grep is
   reading the wrong file — stop and ping.

9. **Close the candidates, by id.** Run `ledger-reverify` **from the consumer root** — a
   distribution-root run has turned a live `STILL-LIVE` into a `CLOSE-CANDIDATE`, and a false close
   retires a live entry.

   **THIS ACTION'S PREMISE WAS WRONG — see `## Discharge`.** It calls the four ids below "discharged
   by this range", derived by reading the range for their commits. The tool, driven from the
   consumer root, returned `NAMED-UPSTREAM` for all four. Naming is not absorption and none were
   closed. The four ids, retained as the record of what was checked:

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

10. **Report to the operator**, including an early stop. Then stop. You do not edit this file.

11. **DISTRIBUTION SESSION ONLY — after the run reports, re-derive this file's own RESUME block and
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

1. `.claude/.ai-dlc-version` reads `0.438.0` on all four fields. Observation point: after the
   phase-2 apply is approved and completes, before any further work. **If the operator does not
   approve that apply, this criterion is correctly UNMET and the run stops there** — report the
   stamp you did reach and say the apply is pending. Do not advance the fields by hand to satisfy
   this line.
2. `.claude/.ai-dlc-applying` is absent, at the same observation point.
3. Action 8's grep returns non-zero with its control at 1, checked after the phase-2 apply. Not
   reachable before it — `route.md` is rulebook and phase 1 does not carry it.
4. The derived-fixture runner's log exists under `_bmad-output/ai-dlc-update/` for each leg and its
   summary line has been reported verbatim — **whatever it says.** Satisfied by REPORTING, not by a
   green run.
5. `ledger-reverify`, run from the consumer root, has been run and its verdict for each of the four
   ids in action 9 reported by name — **whatever that verdict is.** Satisfied by REPORTING, not by a
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
| phase 1 rows | 13 — a strict SUBSET of the full range, asserted, not assumed |
| phase 2 rows | exactly 2: `.claude/skills/ai-dlc/steps/route.md`, `tests/fixtures/resume-whole-read/run.sh` |
| templates | 4, all `TEMPLATE-UNCHANGED-NOOP` |
| phase-1 derived fixtures, hand-written slice — **TERM B ONLY, NOT THE FIGURE TO RUN** | 5 green, 0 red, 0 missing, of 5 named |
| phase-1 derived fixtures, both terms — **the figure to run** | **25 named**; 20 of them term A, unrehearsed, no green/red prediction |
| phase-2 gate, rehearsed from the stop | `SELF-UPDATE-DEFER` again, safe-stop row reads *no intermediate release … self-updates cleanly* |
| phase-2 derived fixtures | **none — a deferred cycle cuts no branch and runs no fixtures** |

**THE FIXTURE FIGURE HAS A PRECONDITION AND THE FIRST ATTEMPT AT IT WAS WRONG.** Run against a clone
with only the fixture files copied in, all five came back RED — they were asserting against
machinery still at `ours`. With the full slice written from `theirs`, the same five are green. A red
fixture result on the real run therefore means something different depending on whether the slice
landed; check the slice is complete before reading the verdict.

**WHAT THE REHEARSAL COULD NOT COVER.** It wrote the slice by hand rather than driving step 2, so it
exercised the coverage join and the fixture run but not the skill's own branch/commit/push cycle.
**Leg 2's fixture run was not rehearsed at all** — it depends on a rulebook state that only exists
after phase 1 lands, and constructing it by hand would have been a second implementation of the
thing under test. **Rehearsing it settled the question rather than deferring it: phase 2 DEFERS, so
it cuts no branch and runs no derived fixtures at all — there is no second fixture run to rehearse.
That is why this file no longer claims one.** And a `->CLASSIFY` row cannot appear in a rehearsal taken while the consumer has no
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

**The run landed both phases and agreed with the rehearsal on every row it predicted. It disagreed
on two figures, and BOTH were this file's error rather than the consumer's.** That is the useful
half of this section.

### Measured on the consumer AFTER the run, from the distribution side, each with a control in the same invocation

```
stamp                 0.438.0 / 1b9f53ec on all four fields   (control: 0 fields at the old 0.437.0/fa92ac44)
.ai-dlc-applying      absent                                  (control: .ai-dlc-version PRESENT in the same test)
action 8 router fix   grep 'ai-dlc resume'        -> 1        (pre-pull baseline 0)
                      control 'STEP_LOADED_TOKEN' -> 1        (1 before AND after)
                      impossible token            -> 0
working branch        ai-dlc/carry-over/dashboard-backlog-s307, 0/0 with its upstream
leftover branches     0 local ai-dlc-update/0.437* or /0.438*
pipeline              still PAUSED, last decision USER_PAUSE
derived fixtures      "# summary: 25 green, 0 red, 0 missing, of 25 named"   read verbatim from the log
reconcile logs        2, one per leg
```

Landed as PRs **#981** (self-update machinery slice), **#982** (reconcile, stamp-only bump) and
**#983** (the phase-2 gated apply).

### The two figures this file got wrong

**The phase-1 derived-fixture count was 5 and the answer is 25.** Corrected mid-run at `1b9f53ec`,
before the branch was cut. The five were TERM B alone — the fixtures the diff itself touches — and
TERM A, every fixture naming a machinery path the diff moved, never entered the prediction because
the rehearsal wrote its slice BY HAND. `core/scripts/validate-layer-entries.sh` changes `+143/-9` in
this range and twelve to thirteen fixtures cover it. **Nothing would have caught the omission**:
the coverage join at `self-update-fixtures.sh:119` joins the passed set against TERM B only, so a
five-directory slice passes it and still strands twenty covering fixtures. All 25 ran green.

**Action 9's premise — that this range DISCHARGES four candidate ids — is not what the tool
reports.** `ledger-reverify`, run from the consumer root, returned **`NAMED-UPSTREAM` for all four**,
with an impossible-id control at 0 rows. Naming is not absorption: a commit can name an id to record
a rejection or a split, step 8 closes `CLOSE-CANDIDATE` only, and each of the four needs its named
commit read and a CONTAINING release established first. **The executor closed none and annotated
nothing, which is correct.** Full-range tally: 49 `STILL-LIVE`, 23 `HAND-REVIEW`, 16
`NAMED-UPSTREAM`, 6 `NAMED-UPSTREAM-AMBIGUOUS`, 1 `RECEIPTS-UNDECIDED`, 1 `CLOSE-CANDIDATE`.

Both defects are the same shape: **a figure derived by a method the real run does not use.** The
rehearsal hand-wrote a slice; this section's action 9 read the range for discharging commits rather
than driving `ledger-reverify`. `verification-discipline.md`'s "run the shipping code against the
real corpus" names both.

### What the rehearsal did not predict, and what it cost

**Phase 2 carried 2 HARD blockers** — `HARD-LAYER-ADJUDICATION-MISSING`, code `EXTENSION-HOOK-DRIFT`,
clause **LC-E4**, on the consumer's `extensions/steps-domain/route-domain.md` and `route-push.md`.
Both hook `steps/route.md`, the one rulebook file in the range, so each needed a recorded verdict
before `apply` could write. Recorded: `route-domain.md` **still-additive**, no `owed`;
`route-push.md` **contradicts-core**, re-declaring the SAME `owed.id`
`OWED-S302-RESET-SNAPSHOT-ROTATOR` under the new digest.

**Re-using that id rather than minting a second is the load-bearing choice.** The debt's handle is
the only thing that survives a digest change, and this pull moved `route.md`, so the old digest
became unaddressable. Verified rather than assumed, from the distribution side: the id appears 3
times as `owed` and **0 times as `closes_owed`** across 290 register rows; its `closes_when` — *"the
reset script no longer writes a dated `pipeline-snapshot.archive.*` path"* — is still UNMET. On the
CONSUMER (no such file exists in this repo, so this is deliberately not written as a resolvable
citation), line 69 of `scripts/ai-dlc-local/ai-dlc-reset-snapshot.sh` still holds
`ARCHIVE="$ROOT/_bmad-output/pipeline-snapshot.archive.${TS}.md"`, and `rotate-snapshot-archive`
matches 0 times there — control: `pipeline-snapshot` matches 2 in that same file, an impossible
token 0, so the zero is a real absence. The debt is left OPEN. Discharging it would have meant
repointing snapshot tooling, far outside a 2-row range.

**`supersedes` was correctly omitted.** LC-A2 binds two records under ONE key stating DIFFERENT
verdicts; this is the same verdict under a NEW key.

### A sequencing hazard this file did not carry, and should have

**The distribution's `main` was three commits UNPUSHED when phase 2 was about to stamp.** Those
commits touch **0** core paths, so the delivered content was identical either way — but the STAMP
records a sha, and `1b9f53ec` existed only on the operator's disk. Stamping it would have written a
base commit no later pull could resolve from the consumer's GitHub upstream. The operator chose to
push first; the ref update was then verified by CONTENT — local `main`, `origin/main` and
`git ls-remote` on the consumer's configured upstream all reading the same sha — rather than by the
push's exit code.

**The hold sent to the executor did not arrive before it cut its branch.** No harm followed: the
stamp had not advanced and the branch was local and unpushed. But the ordering was luck, not design.
**A runbook whose executor resolves `theirs` from the operator's working tree needs a numbered
action asserting that tree is PUBLISHED before anything stamps.** This file had no such action.

### What a future runbook should copy

The executor stopped twice before writing anything — once on a status line that forbade starting,
once on the 5-vs-25 disagreement — and both stops were correct and cheap. Action 5's instruction to
treat a rehearsal disagreement as information rather than reconcile it is what produced the
fixture-count fix. **Keep that instruction verbatim.**
