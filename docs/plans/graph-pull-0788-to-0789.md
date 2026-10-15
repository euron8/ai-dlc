# DISCHARGED — DO NOT EXECUTE — pull the graph consumer to 0.789.0

**Discharged by graph's own run: `b3f2fe199`, "reconcile distribution 0.788.0 → 0.789.0" (#1226), stamp `version:
0.789.0` on graph `main`, with PC-S319 archived.** The PC-S319 "local work remaining" is
`docs/plans/graph-implementation-push-s2-narrow.md`.

## RESUME HERE

**SPENT: graph ran this pull as #1226; see `## Discharge`. What follows is the state at writing.**
**STATE AT WRITING: WRITTEN AND REHEARSED, NOT STARTED.** The rehearsal ran on a `file://` clone of
the consumer at its `main` head, with the consumer's INSTALLED engine run from the clone root,
against the 0.789.0 release content before that release was squash-merged. Every figure in
`## Rehearsal` came from that clone.

**THE CONSUMER IS AT 0.788.0.** Graph pulled 0.788.0 before this file was written, and its
`.claude/.ai-dlc-version` read `version: 0.788.0` at rehearsal. The range this file covers is
therefore **one release, 0.789.0**. Re-read the version file in action 2; if it reads anything
other than 0.788.0, STOP and ping.

**THE REHEARSAL FIGURES ARE EXPECTATIONS.** A disagreement between the real run and `## Rehearsal`
is a STOP-and-ping, never a judgement call.

**THIS FILE BEING GREEN IS NOT AUTHORIZATION.** `.claude/rules/operator-rulings.md` is
unconditional: a consumer pull is operator-initiated, readiness is not authorization, and a
`PENDING` count is not a decision about WHEN. If you are reading this without the operator having
said "run the pull", stop and ask.

**A graph session reads this file at its ABSOLUTE path,
`/Users/n8/git/ai-dlc/docs/plans/graph-pull-0788-to-0789.md`.** From a session rooted in the
consumer, the relative path in the one-liner resolves against the consumer and finds nothing.

Read `## Start here` FIRST, then `### Numbered actions`. `## Rehearsal` is what to expect;
`## Hazards` is what will bite you.

## Start here

**YOUR SESSION'S PROJECT ROOT MUST BE `/Users/n8/git/graph`.** Skill scope follows the session
root, not a Bash `cd`, and a session rooted in the distribution cannot invoke the `ai-dlc-update`
skill at all. If your root is the distribution, stop and restart there.

- **`/Users/n8/git/graph`**: the consumer. WRITE, and only through the skill. The hand edits this
  pull needs (the `dev.md` merge and the two layer adjudications in action 5, the one ledger
  annotation in action 6) are made inside the skill's steps 7 and 8 on its reconcile branch, never
  as ad-hoc edits to the live tree.
- **`/Users/n8/git/ai-dlc`**: the distribution. READ ONLY from this session: read it, never write
  it.

**THE CONSUMER'S TREE IS DIRTY AND THAT IS EXPECTED.** It carries live `_bmad-output/` pipeline
state, and the set grows while the pipeline runs, so it is deliberately not enumerated here. **Do
not commit, revert, stash or clean it.** Committing makes the branch ahead of its remote, and the
preflight then auto-pushes in-flight state.

**THE CONSUMER WAS ON `main` AT WRITING, AND IT MOVES WHILE YOU WORK.** Re-derive the branch and
the head before you start; do not switch either. A moved head during your run is the normal case,
not an alarm.

**This file carries no ref and no sha.** The skill pulls latest and resolves the ref itself. Where
this file needs the installed release, it names the `commit:` field of `.claude/.ai-dlc-version`,
never its value.

**This file does not re-describe the pull.** The `ai-dlc-update` skill owns resolving the ref,
gating its own self-update, carrying the machinery slice and emitting the worklist. Everything here
is what is SPECIAL about this range.

**What the range carries.** 0.789.0 changes four `core/` files.
`core/skills/ai-dlc/steps/_dispatch-protocol.md` point 3 now requires two standing lines in every
worktree dev brief: every git command is `git -C <worktree>` (or a `cd` on every Bash call), and
one story per dispatch, the dev going idle when finished. `core/team-roles/dev.md` says the same
from the dev's side in three places (Responsibilities, the commit-before-idle bullet, and the
HARD_BLOCK tier, which now goes idle instead of moving to the next task).
`core/skills/ai-dlc-update/reconcile/push-refusals.tsv` gains one row refusing, as absorbed,
graph's `implementation-push.md` §2 "Worktree-explicit dev dispatch" block.
`core/fixtures/process-rule-pins/run.sh` pins the new text.

**What is special about this range, in one paragraph.** The self-update gate returns
`SELF-UPDATE-DEFER` with no safe stop, so the slice folds into the gated apply. The only file under
`core/skills/ai-dlc-update/` in the range is `push-refusals.tsv`, which is DATA that `push-drain.sh`
reads at `theirs`, not engine code: `preclassify.sh`, `apply.sh`, `ledger-reverify.sh`,
`ledger-rotate.sh`, `push-drain.sh` and `SKILL.md` are byte-identical across the range, so
classification on the installed engine is exact. The report carries **one `BOTH-CHANGED->CLASSIFY`
row, on `core/team-roles/dev.md`** (graph's in-place `{ownership_paths}` substitution), and **2
`HARD-*` rows**, both layer adjudications on the `dev.md` extensions. **One ledger entry closes in
this pull, `PC-S319-IMPLEMENTATION-PUSH-WORKTREE-EXPLICIT-DISPATCH-BLOCK-RESTATES-CORE-DISPATCH-PROTOCOL`,
through the refusal channel** (action 6).

### Numbered actions

1. **Confirm the operator has authorized THIS pull, and that 0.789.0 has landed.** Not a `PENDING`
   count, not this file being green. Then confirm the distribution's `VERSION` reads exactly
   `0.789.0`. If either is not true, stop here and ping: a later `VERSION` means the range has
   grown past this rehearsal.

2. **Record the consumer's pre-run state**: branch, `git status --porcelain | wc -l`,
   `git rev-list --left-right --count 'HEAD...@{u}'`, the fields of `.claude/.ai-dlc-version`, and
   `md5 -q _bmad-output/ai-dlc-update/push-candidate-ledger.md`. The version file must read
   `version: 0.788.0`; anything else is a STOP. Step 1 auto-pushes an ahead branch. If that push
   fails, the invocation is UN-SYNCED (`core/skills/ai-dlc-update/SKILL.md:229`) and step 6 refuses
   `apply`; if the branch is BEHIND (`core/skills/ai-dlc-update/SKILL.md:207`), fast-forward with
   `git pull --ff-only` and re-invoke; on DIVERGED, stop and ping.

   **Also record that the PC-S319 block has not moved.** In the same invocation, from the consumer
   root, run `bash .claude/skills/ai-dlc-update/reconcile/push-drain.sh /Users/n8/git/ai-dlc
   <commit: field of .claude/.ai-dlc-version> .` and confirm block 1 of
   `extensions/steps-domain/implementation-push.md` reads `PUSH-CANDIDATE` with the digest the
   ledger entry names, and blocks 2-5 read `PUSH-REFUSED`. If block 1's digest differs from the one
   the entry names, graph has edited §2 since the entry was filed and the refusal row will not
   match it: STOP and ping.

3. **Run the `ai-dlc-update` skill, first without `apply`.** Let it resolve the ref. Do not
   hand-drive `preclassify.sh`, `apply.sh` or the self-update scripts. A run without `apply` ends at
   its report (`core/skills/ai-dlc-update/SKILL.md:1586`). Expect the report render to take about a
   minute and a half.

4. **EXPECT `SELF-UPDATE-DEFER`, and NO self-update branch, NO push and NO re-invocation.** The
   gate's `rulebook-coupled-fixtures` row names 2 rulebook files (`_dispatch-protocol.md`, `dev.md`)
   and 63 fixtures, and its `SELF-UPDATE-SAFE-STOP -` row says no intermediate release self-updates
   cleanly. Follow the DEFER bullet (`core/skills/ai-dlc-update/SKILL.md:428`): carry the slice into
   the gated apply (`core/skills/ai-dlc-update/SKILL.md:433`), and commit the gate's own
   `self-update-gate-<ts>.md` record there (`core/skills/ai-dlc-update/SKILL.md:437`).

   If the gate returns `SELF-UPDATE-OK` instead, the range or the consumer has moved since this
   file was written. STOP and ping.

5. **Compare the RENDERED report against `## Rehearsal`, then do the work apply needs.** Compare the
   rendered report, not raw engine output: `emit-report.sh` drops `STILL-LIVE` rows. If the report
   disagrees with `## Rehearsal` on any bucket, any `HARD-*` row, or any ledger row, STOP and ping.
   When it agrees, these are the items the operator decides before `apply` can run, each named by
   the report:

   - **1 `BOTH-CHANGED->CLASSIFY` row, `core/team-roles/dev.md`, on the semantic worklist.** The
     orientation block's ONLY-IN-THEIRS set is the three 0.789.0 hunks plus `{ownership_paths}`; its
     ONLY-IN-OURS set is graph's nine ownership-path lines plus the three old sentences the hunks
     replace. **Expected resolution: take THEIRS on all three changed passages (Responsibilities,
     commit-before-idle, HARD_BLOCK go-idle) and keep OURS's nine ownership-path lines in place of
     `{ownership_paths}`.** Graph's substitution sits in the ownership list only and overlaps none of
     the three hunks, so nothing of graph's is lost. If the full diff the report prints shows any
     other OURS-only line, STOP and ping.
   - **2 `HARD-LAYER-ADJUDICATION-MISSING` rows**, on `extensions/roles/dev-domain.md` and
     `extensions/roles/dev-push.md`, both `hooks: team-roles/dev.md`. Each needs a verdict recorded
     in `_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl` under the `clause` and
     `subject_digest` copied from the row; step 7 has the record shape
     (`core/skills/ai-dlc-update/SKILL.md:1981`). Read each extension against the changed `dev.md`
     before recording its verdict. At rehearsal neither carried "next unblocked", "shared task
     list", "subsequent story", "go idle" or "git -C" (control in the same count: "gate-1" read 8 in
     `dev-domain.md`), and `dev-push.md` is a retirement notice pointing at
     `overrides/team-roles__dev__bug-class-sweep.md`, so neither contradicts the new text on its
     face. The verdict is the operator's; put it to them.
   - **The 2 `EXTENSION-HOOK-DRIFT` rows and the 1 `EXTENSION-TITLE-MATCHES-CORE` row** are the same
     two extensions and are discharged by the adjudications above.
   - **The 3 `CORE-TEMPLATE-SUBSTITUTED` rows** (`deploy-validate.md`, `dev.md`, `qa.md`) are
     graph's template substitutions from earlier pulls. `dev.md`'s is the one the merge above keeps;
     the other two files are not in the range. Nothing further.
   - **All 9 overrides are `OVERRIDE-OK` and all four templates are `TEMPLATE-UNCHANGED-NOOP`.** No
     override readoption and no settings merge.

6. **Re-invoke with `apply`, and CLOSE
   `PC-S319-IMPLEMENTATION-PUSH-WORKTREE-EXPLICIT-DISPATCH-BLOCK-RESTATES-CORE-DISPATCH-PROTOCOL`
   in step 8, on the reconcile branch, from the consumer root.** Every write happens inside the
   skill's isolated branch. The entry's own text says how it closes: "Upstream's answer should land
   in `reconcile/push-refusals.tsv` (refuse) or close this entry (absorbed)." 0.789.0 landed the
   answer in `push-refusals.tsv`, so the close is the refusal channel. In step 8:

   - **Run `push-drain.sh` the way step 8 prescribes** (`core/skills/ai-dlc-update/SKILL.md:2517`,
     usage at `core/skills/ai-dlc-update/reconcile/push-drain.sh:34`), from the consumer root, with
     absolute paths. **Expect all 5 blocks of `implementation-push.md` to read `PUSH-REFUSED`**,
     block 1 now included. If block 1 still reads `PUSH-CANDIDATE`, STOP and ping: do not drain it
     and do not close the entry.
   - **The governing disposition is the all-refused bullet**
     (`core/skills/ai-dlc-update/SKILL.md:2578`): an entry whose every live block reads
     `PUSH-REFUSED` is annotated by hand, with an `Edit`, directly under its `###` heading, with
     exactly `**CLOSED AS REJECTED — BY DESIGN, adjudicated <today's date>**`. That is the one form
     this file prescribes; do not write `ADOPTED UPSTREAM` for this entry.
   - **The dry run will also carry a `NAMED-UPSTREAM` row and a `HAND-REVIEW` row for this id. They
     are NOT this close's mechanism.** The `NAMED-UPSTREAM` row keys on the release commit's message,
     which a squash-merge may or may not carry; the refusal row is CONTENT at `theirs` and survives
     any squash. If the `NAMED-UPSTREAM` row is absent, that is not a STOP; if the `PUSH-REFUSED`
     row is absent, it is.
   - **Take step 8's "before" row set AFTER the annotation.** Taken before it, both of this id's rows
     vanish and read as a mismatch.
   - **Run `ledger-rotate.sh` the way step 8 prescribes
     (`core/skills/ai-dlc-update/SKILL.md:2629`, usage at
     `core/skills/ai-dlc-update/reconcile/ledger-rotate.sh:94`), and expect exactly one entry to
     move.** Then step 8's acceptance test (`core/skills/ai-dlc-update/SKILL.md:2640`): the
     re-verifier's `cut -f1,2 | sort` row set is identical before and after `--apply`. Run
     `ledger-reverify.sh` **from the consumer root**, with absolute paths, both ref arguments being
     distribution refs.
   - **CONFIRM the earlier close is still archived.** In one invocation,
     `grep -c '^### PC-S318-ROTATE-GATE-ADJUDICATION-SPRINT-FLAG-NEVER-MATCHES-NONCE-STYLE-SERIES-IDS'`
     reads 1 over `push-candidate-ledger.archive.md` and 0 over `push-candidate-ledger.md`, while
     `grep -c '^## '` over `push-candidate-ledger.md` reads non-zero. Key it on the `^### ` heading:
     the unanchored id counts 2 in the archive because its annotation line quotes the id. If it is
     back in the live ledger, STOP and ping.
   - **The PR merge needs the operator's explicit approval**
     (`core/skills/ai-dlc-update/SKILL.md:2664`), separate from the `apply` argument.

7. **The entry's "local work remaining" is NOT part of this pull.** It says to narrow
   `implementation-push.md` §2 to the consumer-specific points once upstream confirms absorption.
   Do not do it inside this pull: editing §2 changes its digest, and the block then reads
   `PUSH-CANDIDATE` again on the next pull, correctly, as a new proposal. Name it to the operator as
   follow-up work for a sprint, and stop there.

8. **The new dispatch lines bind graph's next implementation step.** From the first dev dispatch
   after the pull, the lead's worktree brief carries the two point-3 standing lines from
   `core/skills/ai-dlc/steps/_dispatch-protocol.md`, and a dev reporting HARD_BLOCK goes idle
   rather than taking another story. Nothing to do in the pull session; tell the operator.

9. **A `CLOSE-CANDIDATE` row is a hypothesis, not a verdict.** For any id other than PC-S319, run
   that entry's receipt directly, read the raw exit code, and ask what ELSE satisfies it before
   rotating anything. The rehearsal produced no `CLOSE-CANDIDATE` row.

10. **Report to the operator**: the gate verdict, the report as it actually came out, the `dev.md`
    merge and the two `HARD-*` rows and how each was dispositioned, the step-8 `push-drain.sh` rows,
    whether PC-S319 closed and rotated, the PC-S318 confirmation, and any disagreement with
    `## Rehearsal`.

11. **AFTER THE PULL MERGES, BEFORE YOU STOP: re-derive this file's own `## RESUME HERE` block
    and prove it is still resumable.** Re-run the commands behind `## Rehearsal` against the real
    post-pull tree and DIFF every figure against what this file claims; fix the COMMAND where they
    disagree, never only the prose. Then re-derive the delivery gap and the `PENDING` set in
    `docs/plans/graph-ledger-full-drain.md` and report both. **This action and every one after it
    write to the DISTRIBUTION**, so a graph session stops at action 10 and the operator hands
    actions 11-14 to a distribution-side session.

12. **Fill in `## Discharge` and retitle this file as spent.** A spent runbook still reading as
    instructions is this directory's recurring hazard.

13. **THE FRESH-RESUME CHECK, run by the distribution-side session after action 12's docs commit
    has merged.** Read this file from a fresh checkout of the distribution's `main`, as a stranger
    resuming it, and confirm it reads as spent there and that `docs/plans/graph-ledger-full-drain.md`
    reports the delivery gap action 11 derived. Run `bash scripts/validate-plan-shape.sh` there as
    the floor.

14. **HAND THE LEDGER PLAN TO A LOCAL AI-DLC SESSION, THEN STOP.** The distribution-side session
    calls `ListAgents`; if a local `ai-dlc-*` session is found (never a `graph-*` one), it sends,
    with `SendMessage`, exactly `READ and FOLLOW docs/plans/graph-ledger-full-drain.md` and nothing
    else, then stops. If none is found there is nothing further to do.

### Ping the operator

On any question, on any decision, on completion, and on any early stop. From outside, a session
that is thinking and a session that is waiting on a human look identical.

### Done when

Each is observed at the point named, by the session named.

1. **Graph session, after the pull's PR merges**: `.claude/.ai-dlc-version` reads
   `version: 0.789.0`, checked by reading the file.
2. **Graph session, in step 8, before action 6's annotation**: `push-drain.sh` at `theirs` reads
   `PUSH-REFUSED` for all 5 blocks of `implementation-push.md`. The rows do not depend on the
   ledger, so this stays checkable after the annotation too.
3. **Graph session, after action 6's rotation**: in one invocation,
   `grep -c '^### PC-S319-IMPLEMENTATION-PUSH-WORKTREE-EXPLICIT-DISPATCH-BLOCK-RESTATES-CORE-DISPATCH-PROTOCOL'`
   reads 1 over `push-candidate-ledger.archive.md` and 0 over `push-candidate-ledger.md`, while
   `grep -c '^## '` over `push-candidate-ledger.md` reads non-zero.
4. **Graph session, at action 6's acceptance test**: the re-verifier's `cut -f1,2 | sort` row set is
   identical before and after `ledger-rotate.sh --apply`.
5. **Distribution-side session, at action 12**: `## Discharge` is filled in and the file is
   retitled.

Criteria 2, 3 and 4 were checked as reachable on fresh clones of the consumer (see `## Rehearsal`).

## Hazards

- **A false CLOSE is the worst output in this system.** Always run `ledger-reverify` from the
  consumer root, with absolute paths. Both ref arguments are DISTRIBUTION refs, and a consumer sha
  in either slot exits 0 with a plausible, wrong row set.
- **The close keys on the §2 block's digest.** `push-drain.sh` matches a block by its digest
  against `push-refusals.tsv` at `theirs`. If anyone edits `implementation-push.md` §2 before the
  pull, block 1 digests differently, reads `PUSH-CANDIDATE` at `theirs`, and the entry must NOT be
  closed. Action 2 measures this before the run; step 8 measures it again.
- **The refusal channel survives a squash; the naming join may not.** The `NAMED-UPSTREAM` row
  walks the ancestors of `theirs` only
  (`core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:694`) and reads commit messages. The
  rehearsal's row came from the release commit BEFORE its squash-merge. That is why action 6 closes
  on the `PUSH-REFUSED` rows and not on the naming row.
- **`ledger-rotate.sh` exits 0 on a ledger path that does not exist** and reports "nothing to
  rotate". A zero from it on a mistyped path reads exactly like a clean ledger.
- **The Bash tool's shell is zsh.** No `PIPESTATUS`, so `cmd | tail` reports `tail`'s status.
  Never read an exit code through a pipe.
- **The citations in this file resolve in the DISTRIBUTION.** A line number in the consumer's
  installed copy of the same file may be a different line; read the distribution path given.
- **The rehearsal did not drive `apply`, the gated push or the consumer's pre-push.** The gated
  apply's push runs the consumer's whole pre-push suite with the 63 rulebook-coupled fixtures at
  the new version; whether that is green, and its wall clock, are unknown. The rehearsal also did
  not write the `dev.md` merge or the 2 adjudications, so the post-adjudication report is
  unrehearsed.

## Rehearsal

Run on a `file://` clone of the consumer at its `main` head, installed 0.788.0, with the consumer's
INSTALLED engine run from the clone root, base = the installed `commit:` field, against the 0.789.0
release commit before its squash-merge, with the distribution read from a `file://` clone. **These
are expectations, not guarantees. If the real run disagrees, STOP and ping.**

| step | outcome | wall |
|---|---|---|
| releases behind | 1 (0.789.0) | |
| bootstrapping files in range | none: `preclassify.sh`, `apply.sh`, `ledger-reverify.sh`, `ledger-rotate.sh`, `push-drain.sh` and `SKILL.md` are byte-identical across the range (`git diff --quiet` exit 0; the same test on `core/team-roles/dev.md`, the control, exit 1); the one update-skill file in range is `reconcile/push-refusals.tsv`, data; 0 mode changes over 4 changed `core/` files (a seeded mode-change row through the same filter printed, as the control) | |
| `self-update-gate.sh` | `SELF-UPDATE-DEFER` ×2 (`rulebook-coupled-fixtures`: 2 rulebook files, 63 fixtures; and `-`), `SELF-UPDATE-SAFE-STOP -` (no split exists) | 9s |
| `preclassify.sh` raw | 4 rows: 3 `UPSTREAM-ONLY` (`process-rule-pins/run.sh`, `push-refusals.tsv`, `_dispatch-protocol.md`), 1 `BOTH-CHANGED->CLASSIFY` (`team-roles/dev.md`) | 2s |
| `preclassify.sh --templates` | 4 `TEMPLATE-UNCHANGED-NOOP` (`CLAUDE.md`, `docs/coding-conventions.md`, `QUICKSTART.md`, `.claude/settings.json`) | <1s |
| rendered blocking-layer | 2 `HARD-LAYER-ADJUDICATION-MISSING` (`roles/dev-domain.md`, `roles/dev-push.md`; each row printed twice in the report) | 78s for the whole render |
| rendered other | semantic worklist: `core/team-roles/dev.md` only; 3 `CORE-TEMPLATE-SUBSTITUTED`; 2 `EXTENSION-HOOK-DRIFT`, 1 `EXTENSION-TITLE-MATCHES-CORE`, 9 `OVERRIDE-OK`, 5 `PREDICATE-STABLE`; 0 `RETIRED-*`, 0 deletions, 0 relabels; hooks 22 present, 22 registered | |
| reverify raw | 10 rows: 7 `STILL-LIVE`, 1 `NAMED-UPSTREAM` (PC-S319), 1 `HAND-REVIEW` (PC-S319, `verify: manual`), 1 `RECEIPTS-UNDECIDED`; rendered: 3 rows | 2s |
| `push-drain.sh` at `theirs` = the 0.789.0 release commit | 5 rows, all `PUSH-REFUSED` (blocks 1-5 of `implementation-push.md`) | <1s |
| `push-drain.sh` at `theirs` = the installed 0.788.0 commit (control) | block 1 (§2 "Worktree-explicit dev dispatch") `PUSH-CANDIDATE`, blocks 2-5 `PUSH-REFUSED`; same digests both runs | <1s |

**The ledger at rehearsal.** The live ledger carried three `### ` headings: two retro-filed
collections (S295, S296) and PC-S319, the only `PC-` entry, `verify: manual`. PC-S319 counted 1 in
the live ledger and 0 in the archive; the PC-S318 rotate id counted 0 live and 2 in the archive
(1 keyed on `^### `, the other hit being its own annotation line quoting the id); the impossible id
`PC-ZZ-IMPOSSIBLE-CONTROL-Q9X` counted 0 in both.

**Action 6, rehearsed on two fresh clones with the installed engine.** Before annotation,
`ledger-rotate.sh` dry: "0 closed entries — nothing to rotate", exit 0. After writing
`**CLOSED AS REJECTED — BY DESIGN, adjudicated <date>**` under the PC-S319 heading: dry "1 closed
entries would move (7 of 427 lines, leaving 420)", exit 0; `--apply` moved 1 entry, exit 0; then
PC-S319 counted 0 on `^### ` in the live ledger and 1 in the archive, with 19 `^## ` lines still in
the live ledger. Re-verifier row sets: 10 rows before the annotation, 8 after it (the PC-S319
`NAMED-UPSTREAM` and `HAND-REVIEW` rows vanish, which is why the "before" set is taken after the
annotation), 8 after `--apply`; before-vs-after `cut -f1,2 | sort` identical (`cmp` 0), and
pre-annotation-vs-before different (`cmp` 1) as the control that the comparison can tell sets apart.
`push-drain.sh` at `theirs` after the rotation still read 5 `PUSH-REFUSED`.

**What the rehearsal does not cover.** It did not apply the `dev.md` merge, record the two
adjudications, or run the consumer's pre-push; see `## Hazards`.

## Discharge

Ran in a graph session on 2026-10-15 and merged as graph #1226 (`b3f2fe199`). The stamp on graph `main` reads
`version: 0.789.0`, `commit: 7e8d62d7`. Recorded from graph's committed history, read only, by a distribution-side
session. The run's own account is graph's `_bmad-output/ai-dlc-update/reconcile-log-20261015T172805Z.md`.

- **Matched `## Rehearsal`**, per that log: `SELF-UPDATE-DEFER` with the slice carried; every bucket, `HARD-*` row and
  ledger row agreed. The `dev.md` merge took theirs on all three passages and kept graph's nine ownership-path lines.
  Both `LC-E4` adjudications were recorded `still-additive` on `roles/dev-domain.md` and `roles/dev-push.md`.
- **Done-when 1-3 re-derived here against graph `main`; 4 taken from graph's log:**
  - `push-drain.sh` at `7e8d62d7` reads 5 `PUSH-REFUSED` and 0 `PUSH-CANDIDATE`.
  - PC-S319 counts 1 on `^### ` in the archive and 0 in the live ledger, with 19 `^## ` lines still live.
  - PC-S318's rotate id counts 1 archived and 0 live.
  - The impossible id `PC-ZZ-IMPOSSIBLE-CONTROL-Q9X` counts 0 in both files.
  - The rotation's row-set comparison read `cmp` 0, against a control pair that differed. That figure comes from
    graph's log; it was not re-run here.
- **Graph's pre-push suite**, which this file did not rehearse, is not recorded in that log. The PR merged; its
  gate result and wall clock were not derived here.
- **Post-apply** (per the log): `hard-blockers.sh --post-apply` `0 HARD blockers.`, `setup-site-drift.sh` and
  `validate-hook-registration.sh` exit 0.
- **Left as follow-up:** narrowing `implementation-push.md` §2. On the operator's ruling it runs between sprints, as
  `docs/plans/graph-implementation-push-s2-narrow.md`.
