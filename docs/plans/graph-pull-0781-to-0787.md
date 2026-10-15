READ and FOLLOW docs/plans/graph-pull-0781-to-0787.md

# Pull the graph consumer from 0.781.0 to 0.787.0

## RESUME HERE

**STATE AT WRITING: WRITTEN AND PARTLY REHEARSED, NOT STARTED.** The rehearsal ran on a `file://`
clone of the consumer at its `main` head. Every figure in `## Rehearsal` came from that clone. They
were taken against the 0.786.0 integration content, before 0.786.0 was squash-merged and before
0.787.0 existed.

**THE 0.787.0 ROWS ARE PENDING A RE-REHEARSAL.** 0.787.0 will carry the gate-adjudication rotator
refusal (BL-523), BL-510 and the rotator's writer half. The distribution lead re-rehearses this file
after 0.787.0 lands and rewrites `## Rehearsal`. **Until that rewrite has landed, this file is not
ready to run, and a graph session that reads it first stops at action 1 and pings.** Action 1 says
how to tell.

**THE REHEARSAL FIGURES ARE EXPECTATIONS.** A disagreement between the real run and
`## Rehearsal` is a STOP-and-ping, never a judgement call.

**THIS FILE BEING GREEN IS NOT AUTHORIZATION.** `.claude/rules/operator-rulings.md` is
unconditional: a consumer pull is operator-initiated, readiness is not authorization, and a
`PENDING` count is not a decision about WHEN. If you are reading this without the operator having
said "run the pull", stop and ask.

**A graph session reads this file at its ABSOLUTE path,
`/Users/n8/git/ai-dlc/docs/plans/graph-pull-0781-to-0787.md`.** From a session rooted in the
consumer, the relative path in the one-liner resolves against the consumer and finds nothing.

Read `## Start here` FIRST, then `### Numbered actions`. `## Rehearsal` is what to expect;
`## Hazards` is what will bite you.

## Start here

**YOUR SESSION'S PROJECT ROOT MUST BE `/Users/n8/git/graph`.** Skill scope follows the session
root, not a Bash `cd`, and a session rooted in the distribution cannot invoke the `ai-dlc-update`
skill at all. If your root is the distribution, stop and restart there.

- **`/Users/n8/git/graph`**: the consumer. WRITE, and only through the skill. The hand edits this
  pull needs (the rulebook adjudications in action 5, the five annotations in action 6, the
  rotator moves in action 8 and any waiver in action 7) are made either inside the skill's steps 7
  and 8 on its reconcile branch, or by the pipeline at the moment named, never as ad-hoc edits to
  the live tree.
- **`/Users/n8/git/ai-dlc`**: the distribution. READ ONLY from this session: read it, never write
  it.

**THE CONSUMER'S TREE IS DIRTY AND THAT IS EXPECTED.** It carries live `_bmad-output/` pipeline
state, and the set grows while the pipeline runs, so it is deliberately not enumerated here. **Do
not commit, revert, stash or clean it.** Committing makes the branch ahead of its remote, and the
preflight then auto-pushes in-flight state.

**THE CONSUMER IS ON `main` AT WRITING, NOT A CARRY-OVER BRANCH, AND IT MOVES WHILE YOU WORK.**
Sprint 318 is closed and its retro merged. Re-derive the branch and the head before you start; do
not switch either. A moved head during your run is the normal case, not an alarm. **The five
candidates this pull closes are on `main`'s ledger** (`_bmad-output/ai-dlc-update/push-candidate-ledger.md`,
19 `^## ` headings at writing). If the session finds itself on another branch, re-check that each
id is in that branch's ledger before closing anything.

**This file carries no ref and no sha.** The skill pulls latest and resolves the ref itself.

**This file does not re-describe the pull.** The `ai-dlc-update` skill owns resolving the ref,
gating its own self-update, carrying the machinery slice and emitting the worklist. Everything here
is what is SPECIAL about this range.

**What the range carries.** Six releases, 0.782.0 through 0.787.0, which the drain plan calls WIDE.
Among them: a lead edit to product code is denied (0.783.0); the dispatch guard holds a cap-rejected
spawn and refuses an implementation-gate adjudicator over a waiver Check 22 rejects (0.784.0); a
gate-1 re-review is a sharded delta review checked by the new `validate-carried-findings.sh`
(0.785.0); the five sprint-318 candidates' fixes (0.786.0 and 0.787.0); the paused-lead Explore
carve-out (BL-525) and the locked-value F7b reading (BL-524) (0.786.0).

**What is special about this range, in one paragraph.** The self-update gate returns
`SELF-UPDATE-DEFER` with no safe stop, so the slice folds into the gated apply and classification
runs on the installed engine. That costs nothing for classification: the only bootstrapping file in
the range is `reconcile/setup-sites.md`, and the installed preclassify buckets it correctly. But
the rendered report carries **27 `HARD-*` blocking-layer rows** (25 layer adjudications, 2 drifted
overrides), and three semantic merges. Two consequences land AFTER the pull, in the consumer's own
next sprint: the 0.784.0 guard reads Check 22 waivers at every implementation-gate adjudicator
dispatch (action 7), and the 0.787.0 rotator refuses graph's next retro until eight series are
filed by hand (action 8).

### Numbered actions

1. **Confirm the operator has authorized THIS pull, and that the file is ready.** Not a `PENDING`
   count, not this file being green. Then confirm `## Rehearsal` is the post-0.787.0 re-rehearsal:
   the distribution's `VERSION` reads `0.787.0` or later, and `## Rehearsal` says it was taken
   against 0.787.0. If either is not true, stop here and ping.

2. **Record the consumer's pre-run state**: branch, `git status --porcelain | wc -l`,
   `git rev-list --left-right --count 'HEAD...@{u}'`, the fields of `.claude/.ai-dlc-version`, and
   `md5 -q _bmad-output/ai-dlc-update/push-candidate-ledger.md`. Step 1 auto-pushes an ahead branch.
   If that push fails, the invocation is UN-SYNCED (`core/skills/ai-dlc-update/SKILL.md:229`) and
   step 6 refuses `apply`; if the branch is BEHIND (`core/skills/ai-dlc-update/SKILL.md:207`),
   fast-forward with `git pull --ff-only` and re-invoke; on DIVERGED, stop and ping.

3. **Run the `ai-dlc-update` skill, first without `apply`.** Let it resolve the ref. Do not
   hand-drive `preclassify.sh`, `apply.sh` or the self-update scripts. A run without `apply` ends at
   its report (`core/skills/ai-dlc-update/SKILL.md:1586`). Expect the report render to take about
   twelve minutes; it is not hung.

4. **EXPECT `SELF-UPDATE-DEFER`, and NO self-update branch, NO push and NO re-invocation.** The
   bootstrapping file set in the range is `reconcile/setup-sites.md` alone; no `SKILL.md`,
   `preclassify.sh`, `apply.sh` or `ledger-reverify.sh` change, and no file changes mode. The gate's
   `rulebook-coupled-fixtures` row names 20 rulebook files and 63 fixtures that assert against
   rulebook, and its `SELF-UPDATE-SAFE-STOP -` row says no intermediate release self-updates
   cleanly. Follow the DEFER bullet (`core/skills/ai-dlc-update/SKILL.md:428`): carry the slice into
   the gated apply (`core/skills/ai-dlc-update/SKILL.md:433`), and commit the gate's own
   `self-update-gate-<ts>.md` record there (`core/skills/ai-dlc-update/SKILL.md:437`).

   If the gate returns `SELF-UPDATE-OK` instead, the range or the consumer has moved since this
   file was written. STOP and ping.

5. **Compare the RENDERED report against `## Rehearsal`, then do the rulebook-side work apply
   needs.** Compare the rendered report, not raw engine output: `emit-report.sh` drops
   `STILL-LIVE` rows. If the report disagrees with `## Rehearsal` on any bucket, any `HARD-*` row,
   or any ledger row, STOP and ping. When it agrees, these are the items the operator decides
   before `apply` can run, each named by the report:

   - **25 `HARD-LAYER-ADJUDICATION-MISSING` rows**, one per extension whose hook target the range
     changed. Each needs a verdict recorded in
     `_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl` under the `clause` and
     `subject_digest` copied from the row. Step 7 has the record shape. The report lists all 25 by
     path; read each extension against the changed hook target before recording its verdict.
   - **2 `HARD-OVERRIDE-DRIFT-SECTION` rows**, on `team-roles__dev__bug-class-sweep` and
     `team-roles__qa__bug-class-sweep`. The three `RETIRED-LAYER-PASSAGE` rows do not line up with
     them one-to-one: one names line 40 of the dev bug-class-sweep override, which is a HARD row;
     two name lines 83-84 of the tea consumer-drift override, which is NOT a HARD row; and the qa
     bug-class-sweep override, which IS a HARD row, has no passage row. Disposition each HARD row
     from its own section diff, and each passage row on its own.
   - **Three semantic merges (`BOTH-CHANGED->CLASSIFY`)**: `core/team-roles/dev.md`,
     `core/team-roles/qa.md` and `core/skills/ai-dlc/steps/deploy-validate.md`. Each is also
     `CORE-TEMPLATE-SUBSTITUTED`: the consumer's copy substitutes its own value for a template
     placeholder. Keep the consumer's substitution and take theirs' new text.
   - **All four templates are `TEMPLATE-UNCHANGED-NOOP`.** There is no settings merge and no
     settings question for the operator.

6. **Re-invoke with `apply`, and CLOSE THE FIVE SPRINT-318 CANDIDATES in step 8, on the reconcile
   branch, from the consumer root.** Every write happens inside the skill's isolated branch. In
   step 8:

   - **The governing disposition is the `NAMED-UPSTREAM` bullet**
     (`core/skills/ai-dlc-update/SKILL.md:2588`), which allows a hand annotation on absorption. The
     "close ONLY `CLOSE-CANDIDATE` rows" sentence above it
     (`core/skills/ai-dlc-update/SKILL.md:2575`) does not forbid this. None of the five entries
     carries a `verify:` receipt, so `NAMED-UPSTREAM` is the only mechanical signal any of them will
     ever get.
   - **The rehearsal could NOT show the five `NAMED-UPSTREAM` rows.** At rehearsal no distribution
     commit named any of the five ids; they will be named by the 0.786.0 and 0.787.0 release commit
     messages. **If the real dry run does not carry a plain `NAMED-UPSTREAM` row for each id, STOP
     and ping**; do not annotate on this file's word. The `NAMED-UPSTREAM-AMBIGUOUS PC-S318` row
     the rehearsal shows is a different row, explained in `## Rehearsal`; it never authorizes a
     close.
   - **The five ids, closed by these exact ids, each with exactly this line directly under its
     `###` heading:**

     | id | annotation |
     |---|---|
     | `PC-S318-ARCHITECT-ROLE-DOES-NOT-ASK-WHAT-A-LITERAL-IS-WORTH-AFTER-A-REBIND` | `**ADOPTED UPSTREAM (v0.786.0, verified <today's date>)**` |
     | `PC-S318-OPERATOR-QUESTION-TEMPLATE-LABELS-AN-OPERATOR-OWNED-TRADE-OFF-RECOMMENDED` | `**ADOPTED UPSTREAM (v0.786.0, verified <today's date>)**` |
     | `PC-S318-PAUSE-GATE-DENIES-READ-ONLY-OPS-DISPATCH-WHILE-AN-OPERATOR-MESSAGE-IS-OUTSTANDING` | `**ADOPTED UPSTREAM (v0.786.0, verified <today's date>)**` |
     | `PC-S318-QA-ROLE-HAS-NO-RULE-THAT-A-SKIP-AGAINST-A-LOCKED-REQUIREMENT-IS-A-DEVIATION-TO-PUT-TO-THE-OPERATOR` | `**ADOPTED UPSTREAM (v0.786.0, verified <today's date>)**` |
     | `PC-S318-ROTATE-GATE-ADJUDICATION-SPRINT-FLAG-NEVER-MATCHES-NONCE-STYLE-SERIES-IDS` | `**ADOPTED UPSTREAM (v<0.787.0>, verified <today's date>)**` |

     The fifth version is a placeholder until the re-rehearsal confirms the release that carries
     the rotator; the re-rehearsal replaces `<0.787.0>` with that version. No backtick may sit
     between the opening `**` and `ADOPTED UPSTREAM`; a backticked form does not close.
     `ledger-rotate.sh` keys on the bold span.
   - **Establish each version from the commit before annotating.** The `NAMED-UPSTREAM` row
     deliberately carries no version. Read the naming commit for each id and confirm it is the
     release commit that both carries the fix and sets `VERSION` to the version in the table. If a
     version differs, use the release that CONTAINS the fix and say so in the report.
   - **Take step 8's "before" row set AFTER the annotations.** Taken before them, the five
     `NAMED-UPSTREAM` rows vanish and read as a mismatch.
   - **Run `ledger-rotate.sh` the way step 8 prescribes
     (`core/skills/ai-dlc-update/SKILL.md:2629`, usage at
     `core/skills/ai-dlc-update/reconcile/ledger-rotate.sh:94`), and expect exactly five entries to
     move.** Then step 8's acceptance test (`core/skills/ai-dlc-update/SKILL.md:2640`): the
     re-verifier's `cut -f1,2 | sort` row set is identical before and after `--apply`.
   - **The PR merge needs the operator's explicit approval**
     (`core/skills/ai-dlc-update/SKILL.md:2664`), separate from the `apply` argument.

7. **IF the next implementation-gate adjudicator dispatch is REFUSED by the dispatch guard, write
   the Check 22 waiver it names; otherwise do nothing.** This is a consequence of 0.784.0, which
   counts party seats (`tea`, `sm`, `ux`, `cis`) as shardable. The guard judges only the
   snapshot's current `sprint_id` (`core/hooks/ai-dlc-dispatch-guard.sh:695`), so the sprint-317
   party-seat `tea` row (`toolu_012cdPrfgjVUGRG1X3sAcT1g`, shard line
   `none (ordered authoring chain)`) is not what will trigger it: that row is judged only while the
   snapshot reads sprint 317. **The trigger is whatever the CURRENT sprint itself records before its
   first implementation gate**: a shardable `invalid-exception` spawn-ledger row that no OVERRIDDEN
   entry both names and remediates. Expect it to be likely, not rare. Sprints 316, 317 and 318
   recorded 3, 11 and 3 such rows, and the installed guard never refused over any of them. On a
   refusal:

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
   - Re-dispatch the adjudicator. The rehearsal measured this shape on a sprint-317 snapshot: an
     entry naming only the `tea` row removed that one row from a deny of 11, and an entry naming
     all 11 ids with `exception (3) authoring-chain` turned the deny into an allow.

8. **CONTINGENT ON 0.787.0 BEING IN THE PULLED RANGE: at graph's next retro, step 5b's rotator
   will refuse, and the remedy is eight `--series` moves.** The rehearsal ran the 0.787.0
   candidate rotator against the clone: `--sprint s318` and `--sprint s319` both exit 1, naming 12
   verdict files in 8 FAIL-carrying series. The retro's step 5b text (shipped in the same release)
   owns the procedure; this action is what is special about graph. In the retro session:

   - Run the step 5b command. Expect exit 1 and eight printed `--series` commands under "THE
     REMEDY IS ONE --series MOVE PER ID", spelled with `scripts/ai-dlc/`. A separate WARN block
     lists 40 PASS-only series; step 5b says to apply those printed lines before the commit too.
   - **Confirm each hinted sprint against graph's sprint-close commits** before adding `--apply`:
     `git log --format='%ad %s'` filtered to `chore(s<N>): finalize snapshot` and
     `chore(s<N>): rotate gate-log`. The series id's oldest verdict nonce must fall after the
     previous sprint's close and before the hinted sprint's close. Expected hints: `s311` for
     `s311-stories-test-strategy-7`, `s311-sprint-review` and `sprint-review-s311`; `s316` for
     `planning-20261001T034846Z` and `implementation-20261005T022120Z`; `s318` for
     `implementation-20261014T011534Z` and `sprint-review-20261014T105054Z`.
   - **One line is `NO HINT`: `sprint-review-20260919T193432Z`, printed `--sprint s<N>` with the
     window `s312..s313`.** Raise an `AskUserQuestion` naming the id, its one verdict nonce
     `20260919T193432Z`, the two candidates `s312` and `s313`, and the two close commits: s312's
     snapshot was finalized on 2026-09-21 and s313's on 2026-09-25, so the nonce predates s312's
     close. Never pick the sprint yourself. Raise one question for any other `NO HINT` line, and
     for any hint the close commits do not confirm.
   - Run each command as printed (a dry run), then with `--apply`, in the printed order, then
     re-run `--sprint s<N> --apply`. Expect exit 0.

9. **Confirm the BL-524 and BL-525 changes re-red no closed graph series.** The rehearsal ran the
   installed and the incoming `validate-adversarial-convergence.sh` over 129 graph series and found
   0 exit codes changed and 0 F7b findings (`## Rehearsal`). After the pull merges, re-run the same
   enumeration with the installed copy and confirm the exit-code histogram is unchanged. BL-525 is
   a hook change at dispatch time and changes no series verdict.

10. **A `CLOSE-CANDIDATE` row is a hypothesis, not a verdict.** For any id other than the five, run
    that entry's receipt directly, read the raw exit code, and ask what ELSE satisfies it before
    rotating anything. The rehearsal produced one `CLOSE-CANDIDATE` mention in the rendered report
    heading and no `CLOSE-CANDIDATE` row.

11. **Report to the operator**: the gate verdict, the report as it actually came out, the `HARD-*`
    rows and how each was dispositioned, which of the five ids closed, and any disagreement with
    `## Rehearsal`.

12. **AFTER THE PULL MERGES, BEFORE YOU STOP: re-derive this file's own `## RESUME HERE` block
    and prove it is still resumable.** The merge is the moment a handoff goes stale. Re-run the
    commands behind `## Rehearsal` against the real post-pull tree and DIFF every figure against
    what this file claims; fix the COMMAND where they disagree, never only the prose. Then re-derive
    the delivery gap and the `PENDING` set in `docs/plans/graph-ledger-full-drain.md` and report both.
    **This action and every one after it write to the DISTRIBUTION**, so a graph session stops at
    action 11 and the operator hands actions 12-15 to a distribution-side session.

13. **Fill in `## Discharge` and retitle this file as spent.** A spent runbook still reading as
    instructions is this directory's recurring hazard.

14. **THE FRESH-RESUME CHECK, run by the distribution-side session after action 13's docs commit
    has merged.** Read this file from a fresh checkout of `origin/main`, as a stranger resuming it,
    and confirm it reads as spent there and that `docs/plans/graph-ledger-full-drain.md` reports the
    delivery gap action 12 derived. Run `bash scripts/validate-plan-shape.sh` there as the floor.

15. **HAND THE LEDGER PLAN TO A LOCAL AI-DLC SESSION, THEN STOP.** The distribution-side session
    calls `ListAgents`; if a local `ai-dlc-*` session is found (never a `graph-*` one), it sends,
    with `SendMessage`, exactly `READ and FOLLOW docs/plans/graph-ledger-full-drain.md` and nothing
    else, then stops. If none is found there is nothing further to do. This runbook is spent by
    then, so it is the ledger plan, not this file, that the receiver follows.

### Ping the operator

On any question, on any decision, on completion, and on any early stop. From outside, a session
that is thinking and a session that is waiting on a human look identical.

### Done when

Each is observed at the point named, by the session named.

1. **Graph session, after the pull's PR merges**: `.claude/.ai-dlc-version` reads
   `version: 0.787.0` (or the later version the re-rehearsal names), checked by reading the file.
2. **Graph session, in the dry-run report, before action 6's annotation**: the report carries a
   plain `NAMED-UPSTREAM` row for each of the five ids. After the annotation the engine emits no
   row for any of them, so this is not checkable later.
3. **Graph session, after action 6's rotation**: in one invocation, each id counts 1 in
   `push-candidate-ledger.archive.md` and 0 in `push-candidate-ledger.md`, while
   `grep -c '^## '` over `push-candidate-ledger.md` reads non-zero, which proves the ledger read is
   live. Key this on the id string, not on a heading count: the five entries are `###` headings,
   so the `^## ` count does not move when they rotate.
4. **Graph session, at the first implementation-gate adjudicator dispatch after the merge**: the
   dispatch is allowed, or it was refused and action 7's waiver made the re-dispatch allowed.
5. **Graph session, at the next retro's step 5b (only if 0.787.0 was pulled)**:
   `rotate-gate-adjudication.sh --sprint s<N> --apply` exits 0 after action 8's moves.
6. **Distribution-side session, at action 13**: `## Discharge` is filled in and the file is
   retitled.

Criteria 2 and 3 cannot be checked on the rehearsal clone until the release commits name the ids;
the re-rehearsal checks them. Criteria 4 and 5 were checked as reachable on full-tree copies of the
rehearsal clone: a waiver naming every uncovered id turned a deny into an allow, and the eight moves
made `--sprint s318 --apply` exit 0 with the candidate rotator.

## Hazards

- **A false CLOSE is the worst output in this system.** Always run `ledger-reverify` from the
  consumer root, with absolute paths. Both ref arguments are DISTRIBUTION refs, and a consumer sha
  in either slot exits 0 with a plausible, wrong row set.
- **The naming join walks the ancestors of `theirs` only**
  (`core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:694`). After the squash-merge, `theirs`
  is the squash commit on `main`. **If a squash dropped an id from its commit message, that id's
  `NAMED-UPSTREAM` row is absent: STOP and ping**, do not annotate on this file's word.
- **`ledger-rotate.sh` exits 0 on a ledger path that does not exist** and reports "nothing to
  rotate". A zero from it on a mistyped path reads exactly like a clean ledger.
- **The Bash tool's shell is zsh.** No `PIPESTATUS`, so `cmd | tail` reports `tail`'s status.
  Never read an exit code through a pipe.
- **The citations in this file resolve in the DISTRIBUTION.** A line number in the consumer's
  installed copy of the same file may be a different line; read the distribution path given.
- **The dispatch guard reads `docs/escalations/pending.md` only.** A waiver already rotated into
  `pending-archive.md` does not cover a row. On the rehearsal, a sprint-318 snapshot denied the
  next implementation adjudicator over three sprint-318 `remediator` rows whose waivers sit in
  `pending-archive.md`. Sprint 318 is closed, so no gate can be dispatched under it; if the snapshot
  ever reads 318 again, that deny is the cause.
- **The rehearsal did not drive `apply`, the gated push or the consumer's pre-push.** The gated
  apply's push runs the consumer's whole pre-push suite with the 63 rulebook-coupled fixtures at
  the new version; whether that is green, and its wall clock, are unknown. The rehearsal also did
  not write the 27 adjudications or the three merges, so the post-adjudication report is
  unrehearsed.

## Rehearsal

Run on a `file://` clone of the consumer at its `main` head, with the consumer's INSTALLED 0.781.0
engine, against the 0.786.0 integration content (0.785.0 plus the five merged 0.786.0 deliverables).
0.787.0 did not exist; its rotator was measured from its own candidate branch. **These are
expectations, not guarantees. If the real run disagrees, STOP and ping. The 0.787.0 rows are
pending the re-rehearsal named in `## RESUME HERE`.**

| step | outcome | wall |
|---|---|---|
| releases behind | 6 at the planned target (0.782.0-0.787.0); WIDE | |
| bootstrapping files in range | `reconcile/setup-sites.md` only, in both the 0.786.0 content and the rotator branch; 0 mode changes, 0 mode-only, over 72 changed `core/` files | |
| `self-update-gate.sh` | `SELF-UPDATE-DEFER` ×2 (`rulebook-coupled-fixtures`: 20 rulebook files, 63 fixtures; and `-`), `SELF-UPDATE-SAFE-STOP -` (no split exists) | 122s |
| `preclassify.sh` raw | 72 rows: 56 `UPSTREAM-ONLY`, 9 `UPSTREAM-ONLY-ADD`, 4 `DIST-ONLY-SKIP`, 3 `BOTH-CHANGED->CLASSIFY` (`team-roles/dev.md`, `team-roles/qa.md`, `steps/deploy-validate.md`) | 22s |
| `preclassify.sh --templates` | 4 `TEMPLATE-UNCHANGED-NOOP` (`CLAUDE.md`, `docs/coding-conventions.md`, `QUICKSTART.md`, `.claude/settings.json`) | 1s |
| rendered blocking-layer | 25 `HARD-LAYER-ADJUDICATION-MISSING`, 2 `HARD-OVERRIDE-DRIFT-SECTION` (each row printed twice in the report, 54 lines) | 739s for the whole render |
| rendered other | 3 `CORE-TEMPLATE-SUBSTITUTED`; 3 `RETIRED-LAYER-PASSAGE`; hooks 22 present, 22 registered | |
| reverify raw | 9 rows: 7 `STILL-LIVE`, 1 `RECEIPTS-UNDECIDED`, 1 `NAMED-UPSTREAM-AMBIGUOUS PC-S318`; rendered: 2 rows | 10s |

**The `NAMED-UPSTREAM-AMBIGUOUS PC-S318` row is not the five closes.** It cites one docs-only
distribution commit that mentions the sprint prefix and changes nothing under `core/` or
`templates/`, and 8 ledger entries carry the prefix. It is deliberately not attributed. The five
plain `NAMED-UPSTREAM` rows appear only once the 0.786.0 and 0.787.0 release commit messages name
the ids. Control in the same run: each of the five ids, and the impossible id
`PC-ZZ-IMPOSSIBLE-CONTROL-Q7`, is named by 0 commits on both the integration content and the
rotator branch; each of the five counts 1 in graph's ledger and 0 in its archive, and the
impossible id counts 0 in both.

**Action 7, the dispatch guard (0.784.0), driven on full-tree copies of the clone with an
implementation-gate adjudicator brief.** The incoming and installed guards differ (`cmp` 1).

| snapshot `sprint_id` | installed guard | incoming guard |
|---|---|---|
| 318 (as cloned) | allow | deny: 3 sprint-318 `remediator` rows, waivers in `pending-archive.md` only |
| 317 (rewritten) | allow | deny: 11 sprint-317 rows, including the `tea` row |
| 317 plus a `pending.md` waiver naming the `tea` row with `exception (3) authoring-chain` | | deny: the same list minus the `tea` row (10) |
| 317 plus a `pending.md` waiver naming all 11 ids with `exception (3) authoring-chain` | | allow |
| 319 (rewritten) | allow | allow, VACUOUSLY: the clone has 0 sprint-319 ledger rows, and a sprint with no keys fails open |

The sprint-319 row says nothing about sprint 319's real first gate; action 7 is conditional for that
reason. A story-gate nonce was allowed by both guards in the as-cloned state, which is the control
that the deny is the implementation-gate arm and nothing else.

**Action 8, the 0.787.0 candidate rotator, dry run on the clone.** It differs from the installed
copy (`cmp` 1). `--sprint s318`: installed exit 0, candidate exit 1. `--sprint s319`: candidate
exit 1, same refusal. The refusal names 12 verdict files in 8 FAIL-carrying series, prints 8
commands, 7 hinted and 1 `NO HINT (s312..s313)`, and a WARN block of 40 PASS-only series, 9 of them
`NO HINT`. On a fresh copy of the clone, the eight printed moves each exited 0 dry and 0 with
`--apply` (the `NO HINT` id filed as s312 for the scratch test only, which is not a ruling on it),
after which `--sprint s318` exited 0 dry and 0 with `--apply`, with the 40-series WARN still printed.
Re-taken by the re-rehearsal against the released rotator.

**Action 9, the convergence validator (BL-524 F7b).** Installed against incoming, same argv, from
the consumer root, over 129 series enumerated as every file named `*adversarial*pass<N>*`,
`*adversarial-p<N>*` or `*adversarial-review-pass-<N>*` under `_bmad-output/` and `docs/`, cut at
the pass number. The two copies differ (`cmp` 1). Exit pairs: 89 `0 -> 0`, 40 `1 -> 1`, 0 changed.
Output text differed on 7 series, every changed line a partitioner-fallback message or a shifted
line number in a bash error, because the incoming copy ran from a distribution layout; no changed
line carries a verdict. 0 F7b findings. Of graph's 65 records carrying
`locked_requirements_touched:`, 1 names a lock and a badge on the first-token reading (an s307
architecture record). Its series fails `J -- REOPEN` on both copies, so it cannot discriminate.
Only 6 series reach any resolution record at all (each has a `DIVERGENT_HARD_BLOCK` pass), and all 6
fail on both copies for other arms. **The F7b arm was proven able to fire** on the distribution's
own check-24 seed worlds: `adjudication-locked-badged` prints the locked finding on the incoming
copy (exit 1) and not on the installed one (exit 0), while `adjudication-unlocked-badged` passes on
both. The C2 fix round's figure of 137 series was taken over an enumeration this rehearsal could not
recover; 129 is this file's population and the predicate above is its method.

## Discharge
