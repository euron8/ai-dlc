READ and FOLLOW docs/plans/graph-pull-0786-to-0788.md

# Pull the graph consumer to 0.788.0

## RESUME HERE

**STATE AT WRITING: WRITTEN AND REHEARSED, NOT STARTED.** The rehearsal ran on a `file://` clone of
the consumer at its `main` head, with the consumer's INSTALLED engine, against the 0.788.0 release
content before that release was squash-merged. Every figure in `## Rehearsal` came from that clone.

**THE CONSUMER IS AT 0.786.0.** Graph pulled 0.785.0 and then 0.786.0 before this file was
written, and its `.claude/.ai-dlc-version` read `version: 0.786.0` at rehearsal. The range this file
covers is therefore **two releases, 0.787.0 and 0.788.0**, which is NOT wide. Re-read the
version file in action 2; if it reads anything other than 0.786.0, STOP and ping.

**THE REHEARSAL FIGURES ARE EXPECTATIONS.** A disagreement between the real run and `## Rehearsal`
is a STOP-and-ping, never a judgement call.

**THIS FILE BEING GREEN IS NOT AUTHORIZATION.** `.claude/rules/operator-rulings.md` is
unconditional: a consumer pull is operator-initiated, readiness is not authorization, and a
`PENDING` count is not a decision about WHEN. If you are reading this without the operator having
said "run the pull", stop and ask.

**A graph session reads this file at its ABSOLUTE path,
`/Users/n8/git/ai-dlc/docs/plans/graph-pull-0786-to-0788.md`.** From a session rooted in the
consumer, the relative path in the one-liner resolves against the consumer and finds nothing.

Read `## Start here` FIRST, then `### Numbered actions`. `## Rehearsal` is what to expect;
`## Hazards` is what will bite you.

## Start here

**YOUR SESSION'S PROJECT ROOT MUST BE `/Users/n8/git/graph`.** Skill scope follows the session
root, not a Bash `cd`, and a session rooted in the distribution cannot invoke the `ai-dlc-update`
skill at all. If your root is the distribution, stop and restart there.

- **`/Users/n8/git/graph`**: the consumer. WRITE, and only through the skill. The hand edits this
  pull needs (the layer adjudications and the override readoption in action 5, the one annotation
  in action 6) are made inside the skill's steps 7 and 8 on its reconcile branch, never as ad-hoc
  edits to the live tree. The rotator moves in action 8 are made by graph's own next retro, at the
  moment that action names.
- **`/Users/n8/git/ai-dlc`**: the distribution. READ ONLY from this session: read it, never write
  it.

**THE CONSUMER'S TREE IS DIRTY AND THAT IS EXPECTED.** It carries live `_bmad-output/` pipeline
state, and the set grows while the pipeline runs, so it is deliberately not enumerated here. **Do
not commit, revert, stash or clean it.** Committing makes the branch ahead of its remote, and the
preflight then auto-pushes in-flight state.

**THE CONSUMER WAS ON `main` AT WRITING, AND IT MOVES WHILE YOU WORK.** Sprint 318 is closed and
its snapshot still reads `sprint_id: 318`. Re-derive the branch and the head before you start; do
not switch either. A moved head during your run is the normal case, not an alarm.

**This file carries no ref and no sha.** The skill pulls latest and resolves the ref itself.

**This file does not re-describe the pull.** The `ai-dlc-update` skill owns resolving the ref,
gating its own self-update, carrying the machinery slice and emitting the worklist. Everything here
is what is SPECIAL about this range.

**What the range carries.** 0.787.0: gate 1's handoff validator refuses a story whose committed
status is not `review`, or whose implementation-view row disagrees with it, and refuses a demoted
evidence heading. 0.788.0: every gate verdict carries a lead-prescribed `gate_series_id` of the form
`<gate_type>-s<N>-<TS>` (story-scoped gates put a `story<slug>` field before `-s<N>-`), checked by
`validate-gate-adjudication.sh` for every verdict whose nonce is on or after 2026-10-15; and the
gate-adjudication rotator refuses a sprint close it cannot select, with a `--series` escape and a
rewritten retro step 5b.

**What is special about this range, in one paragraph.** The self-update gate returns
`SELF-UPDATE-DEFER` with no safe stop, so the slice folds into the gated apply. No bootstrapping
file is in the range (`preclassify.sh`, `apply.sh`, `ledger-reverify.sh` and the update skill are
all unchanged), so classification on the installed engine is exact. The report carries **8 `HARD-*`
rows** (7 layer adjudications, 1 drifted override) and **no** semantic merge. The override that
drifted is the one that matters: graph's `overrides/steps__retro__domain-sections.md` restates retro
step 5b, so **unless that section is readopted, graph's retro keeps the OLD step 5b and never sees
the `--series` remedy** the rotator will demand of it (action 5). Only ONE ledger entry closes in
this pull; the other four sprint-318 entries were closed by graph's 0.786.0 pull (action 6).

### Numbered actions

1. **Confirm the operator has authorized THIS pull, and that 0.788.0 has landed.** Not a `PENDING`
   count, not this file being green. Then confirm the distribution's `VERSION` reads exactly
   `0.788.0`. If either is not true, stop here and ping: a later `VERSION` means the range has
   grown past this rehearsal.

2. **Record the consumer's pre-run state**: branch, `git status --porcelain | wc -l`,
   `git rev-list --left-right --count 'HEAD...@{u}'`, the fields of `.claude/.ai-dlc-version`, and
   `md5 -q _bmad-output/ai-dlc-update/push-candidate-ledger.md`. The version file must read
   `version: 0.786.0`; anything else is a STOP. Step 1 auto-pushes an ahead branch. If that push
   fails, the invocation is UN-SYNCED (`core/skills/ai-dlc-update/SKILL.md:229`) and step 6 refuses
   `apply`; if the branch is BEHIND (`core/skills/ai-dlc-update/SKILL.md:207`), fast-forward with
   `git pull --ff-only` and re-invoke; on DIVERGED, stop and ping.

3. **Run the `ai-dlc-update` skill, first without `apply`.** Let it resolve the ref. Do not
   hand-drive `preclassify.sh`, `apply.sh` or the self-update scripts. A run without `apply` ends at
   its report (`core/skills/ai-dlc-update/SKILL.md:1586`). Expect the report render to take about
   three and a half minutes.

4. **EXPECT `SELF-UPDATE-DEFER`, and NO self-update branch, NO push and NO re-invocation.** The
   gate's `rulebook-coupled-fixtures` row names 5 rulebook files (`_gate-procedures.md`,
   `gate-validation.md`, `implementation.md`, `retro.md`, `gate-adjudicator.md`) and 73 fixtures,
   and its `SELF-UPDATE-SAFE-STOP -` row says no intermediate release self-updates cleanly. Follow
   the DEFER bullet (`core/skills/ai-dlc-update/SKILL.md:428`): carry the slice into the gated
   apply (`core/skills/ai-dlc-update/SKILL.md:433`), and commit the gate's own
   `self-update-gate-<ts>.md` record there (`core/skills/ai-dlc-update/SKILL.md:437`).

   If the gate returns `SELF-UPDATE-OK` instead, the range or the consumer has moved since this
   file was written. STOP and ping.

5. **Compare the RENDERED report against `## Rehearsal`, then do the rulebook-side work apply
   needs.** Compare the rendered report, not raw engine output: `emit-report.sh` drops `STILL-LIVE`
   rows. If the report disagrees with `## Rehearsal` on any bucket, any `HARD-*` row, or any ledger
   row, STOP and ping. When it agrees, these are the items the operator decides before `apply` can
   run, each named by the report:

   - **7 `HARD-LAYER-ADJUDICATION-MISSING` rows**, one per extension whose hook target the range
     changed: `checks/gate-validation-domain.md`, `checks/gate-validation-push-914.md`,
     `checks/gate-validation-push.md`, `checks/validator-honesty.md`,
     `steps-domain/implementation-domain.md`, `steps-domain/implementation-push.md`,
     `steps-domain/retro-push-next-sprint-prompt.md`. Each needs a verdict recorded in
     `_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl` under the `clause` and
     `subject_digest` copied from the row; step 7 has the record shape. Read each extension against
     the changed hook target before recording its verdict. The last one also carries an
     `EXTENSION-ANCHOR-DRIFT` row: its anchor in `retro.md` moved, so check the anchor still names
     the passage it hooks.
   - **1 `HARD-OVERRIDE-DRIFT-SECTION` row, on `overrides/steps__retro__domain-sections.md`**, with
     the one `RETIRED-LAYER-PASSAGE` row pointing at line 331 of the same file. That override
     carries a copy of retro step 5b ending "refusal, and investigate before re-running.", which is
     the sentence 0.788.0 extends with the `--series` remedy, the `--legacy-through` step, the
     re-run rule and the sprint-confirmation rule. **Disposition: READOPT the section so the
     override carries 0.788.0's step 5b text.** Keeping the old text means graph's next retro reads
     a step 5b that says only "investigate", while the rotator refuses that retro (action 8). This
     is the operator's decision; put it to them with that consequence stated.
   - **The 3 `CORE-TEMPLATE-SUBSTITUTED` rows** (`deploy-validate.md`, `dev.md`, `qa.md`) are
     informational: none of the three files is in the range, and each carries graph's own template
     substitution from earlier pulls. Nothing to merge.
   - **All four templates are `TEMPLATE-UNCHANGED-NOOP`.** There is no settings merge.

6. **Re-invoke with `apply`, and CLOSE THE ONE LIVE SPRINT-318 CANDIDATE in step 8, on the
   reconcile branch, from the consumer root.** Every write happens inside the skill's isolated
   branch. In step 8:

   - **The governing disposition is the `NAMED-UPSTREAM` bullet**
     (`core/skills/ai-dlc-update/SKILL.md:2588`), which allows a hand annotation on absorption. The
     "close ONLY `CLOSE-CANDIDATE` rows" sentence above it
     (`core/skills/ai-dlc-update/SKILL.md:2575`) does not forbid this. The entry carries no
     `verify:` receipt, so `NAMED-UPSTREAM` is the only mechanical signal it will ever get.
   - **The five sprint-318 ids, by id:**

     | id | action |
     |---|---|
     | `PC-S318-ARCHITECT-ROLE-DOES-NOT-ASK-WHAT-A-LITERAL-IS-WORTH-AFTER-A-REBIND` | already closed `**ADOPTED UPSTREAM (v0.786.0, verified 2026-10-15)**` and rotated by graph's 0.786.0 pull; CONFIRM only |
     | `PC-S318-OPERATOR-QUESTION-TEMPLATE-LABELS-AN-OPERATOR-OWNED-TRADE-OFF-RECOMMENDED` | already closed `**ADOPTED UPSTREAM (v0.786.0, verified 2026-10-15)**` and rotated; CONFIRM only |
     | `PC-S318-PAUSE-GATE-DENIES-READ-ONLY-OPS-DISPATCH-WHILE-AN-OPERATOR-MESSAGE-IS-OUTSTANDING` | already closed `**ADOPTED UPSTREAM (v0.786.0, verified 2026-10-15)**` and rotated; CONFIRM only |
     | `PC-S318-QA-ROLE-HAS-NO-RULE-THAT-A-SKIP-AGAINST-A-LOCKED-REQUIREMENT-IS-A-DEVIATION-TO-PUT-TO-THE-OPERATOR` | already closed `**ADOPTED UPSTREAM (v0.786.0, verified 2026-10-15)**` and rotated; CONFIRM only |
     | `PC-S318-ROTATE-GATE-ADJUDICATION-SPRINT-FLAG-NEVER-MATCHES-NONCE-STYLE-SERIES-IDS` | annotate with exactly `**ADOPTED UPSTREAM (v0.788.0, verified <today's date>)**` directly under its `###` heading |

     **CONFIRM** means: in one invocation, each of the four counts 1 in
     `push-candidate-ledger.archive.md` and 0 in `push-candidate-ledger.md`, while `grep -c '^## '`
     over `push-candidate-ledger.md` reads non-zero. Do NOT re-annotate any of the four. If any of
     them is back in the live ledger, STOP and ping.
   - **The dry run must carry a plain `NAMED-UPSTREAM` row for the rotate id.** If it does not,
     STOP and ping; do not annotate on this file's word.
   - **Establish the version from the commit before annotating.** Read the commit the row names and
     confirm it is the release commit that carries the rotator change and sets `VERSION` to
     0.788.0. No backtick may sit between the opening `**` and `ADOPTED UPSTREAM`; a backticked form
     does not close. `ledger-rotate.sh` keys on the bold span.
   - **Take step 8's "before" row set AFTER the annotation.** Taken before it, the
     `NAMED-UPSTREAM` row vanishes and reads as a mismatch.
   - **Run `ledger-rotate.sh` the way step 8 prescribes
     (`core/skills/ai-dlc-update/SKILL.md:2629`, usage at
     `core/skills/ai-dlc-update/reconcile/ledger-rotate.sh:94`), and expect exactly one entry to
     move.** Then step 8's acceptance test (`core/skills/ai-dlc-update/SKILL.md:2640`): the
     re-verifier's `cut -f1,2 | sort` row set is identical before and after `--apply`.
   - **The `HAND-REVIEW` row for the sprint-319 implementation-push entry is not this pull's
     close.** Leave it; it is `verify: manual` and is adjudicated on its own.
   - **The PR merge needs the operator's explicit approval**
     (`core/skills/ai-dlc-update/SKILL.md:2664`), separate from the `apply` argument.

7. **THE CHECK 22 WAIVER IS ALREADY LIVE IN GRAPH, NOT A CONSEQUENCE OF THIS PULL.** The dispatch
   guard that reads Check 22 waivers shipped at 0.784.0 and graph installed it with its 0.785.0
   pull; this range does not change the guard. Carry it forward unchanged: IF the next
   implementation-gate adjudicator dispatch is REFUSED by the dispatch guard, write the Check 22
   waiver it names; otherwise do nothing. The guard judges only the snapshot's current `sprint_id`
   (`core/hooks/ai-dlc-dispatch-guard.sh:695`). On a refusal:

   - Read the deny. It lists each uncovered `toolu_` id (the text at
     `core/hooks/ai-dlc-dispatch-guard.sh:1065`).
   - The lead appends ONE `## ` entry to `docs/escalations/pending.md` (the guard reads that file
     only, never `pending-archive.md`) whose header carries `Check 22` and the sprint as `S<N>`,
     with `**Status:** OVERRIDDEN`, a field naming every uncovered `toolu_` id verbatim, and a
     `**Remediation:**` field that does ONE of the two things Check 22 clearing arm 4 accepts
     (`core/hooks/ai-dlc-dispatch-guard.sh:836`): names the exception that actually applied
     (`exception (3)`, or its short name such as `authoring-chain`, not negated), or states
     `the work was re-dispatched sharded as <names>`. A sentence saying none of the four applies
     remediates nothing.
   - Which exception applied, or whether to re-dispatch, is the operator's decision. Put it to the
     operator as an `AskUserQuestion` naming each id and its recorded shard line; never pick it.
   - **The same gate's brief now carries a prescribed `gate_series_id`** (0.788.0's
     `gate-validation.md` "At gate entry"). Copy it from the brief; a verdict whose nonce is on or
     after 2026-10-15 and whose id is not `<gate_type>-[story<slug>-]s<N>-<TS>` is BLOCKED by
     `validate-gate-adjudication.sh`.

8. **AT GRAPH'S NEXT RETRO, STEP 5b'S ROTATOR WILL REFUSE, AND THE REMEDY IS FOUR `--series`
   MOVES.** This is 0.788.0's rotator, not 0.787.0's. The retro's step 5b text owns the procedure
   (only if action 5 readopted the override; otherwise the retro is reading the old text, so follow
   the distribution's `core/skills/ai-dlc/steps/retro.md` step 5b); this action is what is special
   about graph. In the retro session:

   - Run the step 5b command. Expect exit 1, "REFUSED -- no verdict names series 's<N>', and 4
     verdict(s) carry a gate_series_id no --sprint selector can match", and four printed `--series`
     commands under "THE REMEDY IS ONE --series MOVE PER ID", spelled with `scripts/ai-dlc/`, in
     this order: `s311-stories-test-strategy-7` hinted `s311`; `s311-sprint-review` hinted `s311`;
     `sprint-review-20260919T193432Z` printed `--sprint s<N>` with `NO HINT (s312..s313)`;
     `implementation-20261005T022120Z` hinted `s316`. A separate WARN block names 48 PASS-only
     verdicts with 44 commands, 8 of them `NO HINT`; step 5b says to apply those printed lines
     before the commit too, and each `NO HINT` one among them is its own operator question.
   - **Confirm each hinted sprint against graph's sprint-close commits** before adding `--apply`,
     with `TZ=UTC git log --date=format-local:%Y%m%dT%H%M%SZ --format='%ad %s'`; a sprint's close
     is its `chore(s<N>): rotate ... post-retro-merge` commit, or its retro PR's merge commit where
     it has none. **Sprint 311 has no rotate commit**, so its close is the `Sprint 311 retro` PR merge,
     2026-09-14T15:21Z. The two `s311` series' verdict nonces, `20260913T044428Z` and
     `20260914T072634Z`, fall after s310's close (2026-09-11T12:32Z) and before it, so `s311` is
     confirmed; the ids also carry the `s311` token themselves. `implementation-20261005T022120Z`
     falls after s315's close (2026-09-30T20:14Z) and before s316's (2026-10-05T13:58Z), so `s316`
     is confirmed.
   - **`sprint-review-20260919T193432Z` is `NO HINT`.** Raise an `AskUserQuestion` naming the id,
     its nonce `20260919T193432Z`, the rotator's window `s312..s313`, and the close commits: s312's
     rotate commit is 2026-09-21T04:33Z, so the nonce predates s312's close. Never pick the sprint
     yourself.
   - **`--series` refuses an id a `--sprint` selector can already name** (exit 2, "carries a -s<N>-
     token, so --sprint already selects it"). Never hand it such an id.
   - Run each command as printed (a dry run), then with `--apply`, in the printed order. A `--series`
     run that exits 1 and prints a `--legacy-through` remedy is applied the same way, dry then
     `--apply`, before re-running that `--series` line. Then re-run `--sprint s<N> --apply`; the
     close is done only when it exits 0.

9. **The convergence validator is not in this range.** `validate-adversarial-convergence.sh` is
   byte-identical across it, so no closed series can change verdict. Nothing to re-run.

10. **A `CLOSE-CANDIDATE` row is a hypothesis, not a verdict.** For any id other than the rotate id,
    run that entry's receipt directly, read the raw exit code, and ask what ELSE satisfies it
    before rotating anything. The rehearsal produced no `CLOSE-CANDIDATE` row.

11. **Report to the operator**: the gate verdict, the report as it actually came out, the `HARD-*`
    rows and how each was dispositioned, whether the rotate id closed, the four confirmations, and
    any disagreement with `## Rehearsal`.

12. **AFTER THE PULL MERGES, BEFORE YOU STOP: re-derive this file's own `## RESUME HERE` block
    and prove it is still resumable.** Re-run the commands behind `## Rehearsal` against the real
    post-pull tree and DIFF every figure against what this file claims; fix the COMMAND where they
    disagree, never only the prose. Then re-derive the delivery gap and the `PENDING` set in
    `docs/plans/graph-ledger-full-drain.md` and report both. **This action and every one after it
    write to the DISTRIBUTION**, so a graph session stops at action 11 and the operator hands
    actions 12-15 to a distribution-side session.

13. **Fill in `## Discharge` and retitle this file as spent.** A spent runbook still reading as
    instructions is this directory's recurring hazard.

14. **THE FRESH-RESUME CHECK, run by the distribution-side session after action 13's docs commit
    has merged.** Read this file from a fresh checkout of the distribution's `main`, as a stranger
    resuming it, and confirm it reads as spent there and that `docs/plans/graph-ledger-full-drain.md`
    reports the delivery gap action 12 derived. Run `bash scripts/validate-plan-shape.sh` there as
    the floor.

15. **HAND THE LEDGER PLAN TO A LOCAL AI-DLC SESSION, THEN STOP.** The distribution-side session
    calls `ListAgents`; if a local `ai-dlc-*` session is found (never a `graph-*` one), it sends,
    with `SendMessage`, exactly `READ and FOLLOW docs/plans/graph-ledger-full-drain.md` and nothing
    else, then stops. If none is found there is nothing further to do.

### Ping the operator

On any question, on any decision, on completion, and on any early stop. From outside, a session
that is thinking and a session that is waiting on a human look identical.

### Done when

Each is observed at the point named, by the session named.

1. **Graph session, after the pull's PR merges**: `.claude/.ai-dlc-version` reads
   `version: 0.788.0`, checked by reading the file.
2. **Graph session, in the dry-run report, before action 6's annotation**: the report carries a
   plain `NAMED-UPSTREAM` row for the rotate id. After the annotation the engine emits no row for
   it, so this is not checkable later.
3. **Graph session, after action 6's rotation**: in one invocation, each of the five ids counts 1
   in `push-candidate-ledger.archive.md` and 0 in `push-candidate-ledger.md`, while
   `grep -c '^## '` over `push-candidate-ledger.md` reads non-zero. Key this on the id string, not
   on a heading count: the entries are `###` headings, so the `^## ` count does not move.
4. **Graph session, at the next retro's step 5b**: `rotate-gate-adjudication.sh --sprint s<N>
   --apply` exits 0 after action 8's moves.
5. **Distribution-side session, at action 13**: `## Discharge` is filled in and the file is
   retitled.

Criteria 2 and 3 were checked as reachable on the rehearsal clone for the rotate id (its
`NAMED-UPSTREAM` row is shown). Criterion 4 was checked as reachable on a fresh clone: the four
moves made `--sprint s318 --apply` exit 0.

## Hazards

- **A false CLOSE is the worst output in this system.** Always run `ledger-reverify` from the
  consumer root, with absolute paths. Both ref arguments are DISTRIBUTION refs, and a consumer sha
  in either slot exits 0 with a plausible, wrong row set.
- **The naming join walks the ancestors of `theirs` only**
  (`core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:694`). The rehearsal's
  `NAMED-UPSTREAM` row came from the release commit BEFORE its squash-merge. After the merge,
  `theirs` is the squash commit, whose message is whatever the merge passed. **If the squash
  dropped the rotate id from its message, the row is absent: STOP and ping**, do not annotate on
  this file's word.
- **`ledger-rotate.sh` exits 0 on a ledger path that does not exist** and reports "nothing to
  rotate". A zero from it on a mistyped path reads exactly like a clean ledger.
- **Gate 1 handoffs get stricter at 0.787.0.** The incoming `validate-handoff-evidence.sh` refuses
  a story whose evidence headings (`## Production Integrity Tests`, `## Smoke Test Updates`,
  `## Rename Verification`) sit only below level 2. Replayed on sprint 318's story 1.5 at its
  frozen gate-1 commit, it refuses where the installed copy passed. A story authored with `###`
  evidence headings will be refused at its next handoff; promote the headings.
- **The Bash tool's shell is zsh.** No `PIPESTATUS`, so `cmd | tail` reports `tail`'s status.
  Never read an exit code through a pipe.
- **The citations in this file resolve in the DISTRIBUTION.** A line number in the consumer's
  installed copy of the same file may be a different line; read the distribution path given.
- **The rehearsal did not drive `apply`, the gated push or the consumer's pre-push.** The gated
  apply's push runs the consumer's whole pre-push suite with the 73 rulebook-coupled fixtures at
  the new version; whether that is green, and its wall clock, are unknown. The rehearsal also did
  not write the 7 adjudications or readopt the override, so the post-adjudication report is
  unrehearsed.

## Rehearsal

Run on a `file://` clone of the consumer at its `main` head, installed 0.786.0, with the consumer's
INSTALLED engine run from the clone root, against the 0.788.0 release commit before its
squash-merge. **These are expectations, not guarantees. If the real run disagrees, STOP and ping.**

| step | outcome | wall |
|---|---|---|
| releases behind | 2 (0.787.0, 0.788.0); not wide | |
| bootstrapping files in range | none: `preclassify.sh`, `apply.sh`, `ledger-reverify.sh` and the whole update skill are byte-identical across the range (the same diff on the rotator, a control, is non-empty); 0 mode changes and 0 mode-only over 17 changed `core/` files | |
| `self-update-gate.sh` | `SELF-UPDATE-DEFER` ×2 (`rulebook-coupled-fixtures`: 5 rulebook files, 73 fixtures; and `-`), `SELF-UPDATE-SAFE-STOP -` (no split exists) | 56s + 27s |
| `preclassify.sh` raw | 17 rows: 16 `UPSTREAM-ONLY`, 1 `DIST-ONLY-SKIP` (`gate-adjudication-mutants`), 0 `->CLASSIFY` | 5s |
| `preclassify.sh --templates` | 4 `TEMPLATE-UNCHANGED-NOOP` (`CLAUDE.md`, `docs/coding-conventions.md`, `QUICKSTART.md`, `.claude/settings.json`) | 1s |
| rendered blocking-layer | 7 `HARD-LAYER-ADJUDICATION-MISSING`, 1 `HARD-OVERRIDE-DRIFT-SECTION` (each row printed twice in the report) | 197s for the whole render |
| rendered other | 3 `CORE-TEMPLATE-SUBSTITUTED`; 1 `RETIRED-LAYER-PASSAGE` (retro override line 331); 6 `EXTENSION-HOOK-DRIFT`, 1 `EXTENSION-ANCHOR-DRIFT`, 2 `EXTENSION-TITLE-MATCHES-CORE`, 8 `OVERRIDE-OK`, 5 `PREDICATE-STABLE`; hooks 22 present, 22 registered | |
| reverify raw | 10 rows: 7 `STILL-LIVE`, 1 `NAMED-UPSTREAM` (the rotate id), 1 `HAND-REVIEW` (the sprint-319 implementation-push entry), 1 `RECEIPTS-UNDECIDED`; rendered: 3 rows | 8s |

**The ledger at rehearsal.** The live ledger carried 1 sprint-318 id, the rotate id; the archive
carried the four 0.786.0 ids, each annotated `ADOPTED UPSTREAM (v0.786.0, verified 2026-10-15)`. The
rotate id is named by 1 commit in the range, the 0.788.0 release commit. Control in the same
measurement: an impossible id is named by 0 commits across every ref of the distribution.

**The engines the range changes, installed copy against incoming, on full-tree clones.** Each pair
differs (`cmp` 1 for `rotate-gate-adjudication.sh`, `sprint-status.sh`,
`validate-gate-adjudication.sh`, `validate-handoff-evidence.sh`); an engine the range does not
change, `core-paths.sh`, is identical (`cmp` 0), as the control that the copies are the ones meant.

| engine and argv | installed | incoming |
|---|---|---|
| rotator `--sprint s318` (dry) | exit 0, "nothing to move" | exit 1, the four-series refusal in action 8 |
| rotator `--sprint s319` (dry) | exit 0 | exit 1, the same four series |
| `validate-gate-adjudication.sh <type> <verdict>` over all 239 live verdicts | 77 exit 0, 162 exit 1 | identical: 0 exit codes changed, 0 output texts changed |
| `validate-gate-adjudication.sh --series <live dir>`, `--expected` ×4 | 1; 0 ×4 | identical |
| `sprint-status.sh sprint-id`, `check-stories`, `derive-stories --check` | 0, 0, 0 | identical |
| `validate-handoff-evidence.sh` at 8 sprint-318 gate-1 frozen commits | 7 exit 0, 1 exit 1 (story 2.4) | story 1.5 goes 0 to 1 (three `heading-demoted` refusals); story 2.4 stays 1 (trailer wording only); 6 identical |
| `validate-handoff-evidence.sh --strategy HEAD` over sprint 318's 13 stories | 0 | identical |

**What the null does not cover.** The new series-form arm of `validate-gate-adjudication.sh`
applies only to verdicts whose nonce is on or after 2026-10-15, and graph had 0 such verdicts at
rehearsal, so the 239-verdict null cannot show it firing. It binds from graph's first gate after
the pull. 0.787.0's status-mismatch refusals did not fire on any replayed sprint-318 handoff.

**Action 8, rehearsed on a fresh clone with the incoming rotator.** Live verdicts before: 239. The
four printed moves, with `sprint-review-20260919T193432Z` filed as s312 for the scratch test only
(not a ruling), each exited 0 dry and 0 with `--apply`; then `--sprint s318` exited 0 dry and 0 with
`--apply`, with the 48-verdict WARN still printed. Live verdicts after: 235. `--series` on the
selectable id `planning-s303-20260814T152401Z` exited 2 with the refusal quoted in action 8. No move
printed a `--legacy-through` remedy.

## Discharge
