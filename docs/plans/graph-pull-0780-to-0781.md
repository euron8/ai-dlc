# Pull the graph consumer from 0.780.0 to 0.781.0

READ and FOLLOW docs/plans/graph-pull-0780-to-0781.md

## RESUME HERE

**STATE AT WRITING: WRITTEN AND REHEARSED, NOT STARTED.** The rehearsal ran on a `file://` clone
of the consumer, on the consumer's checked-out carry-over branch, and every figure in
`## Rehearsal` came from it.

**THE REHEARSAL FIGURES ARE EXPECTATIONS TAKEN AGAINST THE UNMERGED 0.781.0 RELEASE COMMIT**, the
single commit on the release branch before its squash-merge to `main`. The skill will resolve
`theirs` to the squash commit on `main`, which carries the same tree and the same message. **A
disagreement between the real run and `## Rehearsal` is a STOP-and-ping, never a judgement call.**

**THIS FILE BEING GREEN IS NOT AUTHORIZATION.** `.claude/rules/operator-rulings.md` is
unconditional: a consumer pull is operator-initiated, readiness is not authorization, and a
`PENDING` count is not a decision about WHEN. If you are reading this without the operator having
said "run the pull", stop and ask.

**A graph session reads this file at its ABSOLUTE path,
`/Users/n8/git/ai-dlc/docs/plans/graph-pull-0780-to-0781.md`.** From a session rooted in the
consumer, the relative path in the one-liner resolves against the consumer and finds nothing.

Read `## Start here` FIRST, then `### Numbered actions`. `## Rehearsal` is what to expect;
`## Hazards` is what will bite you.

## Start here

**YOUR SESSION'S PROJECT ROOT MUST BE `/Users/n8/git/graph`.** Skill scope follows the session
root, not a Bash `cd`, and a session rooted in the distribution cannot invoke the `ai-dlc-update`
skill at all. If your root is the distribution, stop and restart there.

- **`/Users/n8/git/graph`**: the consumer. WRITE, and only through the skill. The hand edits this
  pull needs (the rulebook adjudications in action 5 and the two annotations in action 6) are made
  inside the skill's steps 7 and 8 on its reconcile branch, never in the live carry-over tree.
- **`/Users/n8/git/ai-dlc`**: the distribution. READ ONLY from this session: read it, never write
  it.

**THE CONSUMER'S TREE IS DIRTY AND THAT IS EXPECTED.** It carries live `_bmad-output/` pipeline
state, and the set grows while the pipeline runs, so it is deliberately not enumerated here. **Do
not commit, revert, stash or clean it.** Committing makes the branch ahead of its remote, and the
preflight then auto-pushes in-flight state.

**THE CONSUMER IS ON A CARRY-OVER BRANCH, NOT `main`, AND IT MOVES WHILE YOU WORK.** Re-derive the
branch and the head before you start; do not switch either. A moved consumer head during your run
is the normal case, not an alarm. **The two candidates this pull closes live ONLY on that
carry-over branch's ledger** (and on some sprint story branches cut from it); the consumer's
`main` ledger carries neither. Close them on the reconcile branch cut from the carry-over branch.

**This file carries no ref and no sha.** The skill pulls latest and resolves the ref itself.

**This file does not re-describe the pull.** The `ai-dlc-update` skill owns resolving the ref,
gating its own self-update, carrying the machinery slice and emitting the worklist. Everything here
is what is SPECIAL about this range.

**What the range carries.** One release, 0.781.0. It ships the fixes for both of the consumer's
sprint-318 push candidates (`validate-mutation-red.sh` scores an all-skipped pytest run
`UNEVALUABLE`; dev escalation takes the review route's capital-path criterion), one model-window
policy shared by `validate-artifact-budget.sh` and the context sensor, party seats derived from the
role file in `validate-spawn-ledger.sh`, and the operator's settings-template change.

**Why this pull is required, not optional.** The consumer's installed `validate-spawn-ledger.sh`
cannot see its party personas: on the sprint-317 spawn ledger it reports 0 persona warnings where
0.781.0 reports 57, and 10 arm-S3 serial-exception failures where 0.781.0 reports 11. Its installed
`validate-artifact-budget.sh` cannot read the window declarations in the settings `env` block, so
the analyst's whole-read pool is 66000 tokens where 0.781.0 resolves 330000.

**What is special about this range, in one paragraph.** The self-update gate returns
`SELF-UPDATE-DEFER`, so there is no autonomous self-update cycle and no re-invocation: the slice
folds into the gated apply. That costs nothing for classification, because no reconcile engine file
changes in the range and the installed engine is byte-identical to 0.781.0's. But the dry run
reports **12 `HARD-*` blocking-layer rows**, where the previous pull had none, and those block
`apply` until the operator records adjudications. The rulebook half also has one semantic merge
(`team-roles/dev.md`) and one prose template merge (`QUICKSTART.md`).

### Numbered actions

1. **Confirm the operator has authorized THIS pull.** Not a `PENDING` count, not this file being
   green. If that has not happened, stop here and ping.

2. **Record the consumer's pre-run state**: branch, `git status --porcelain | wc -l`,
   `git rev-list --left-right --count 'HEAD...@{u}'`, the fields of `.claude/.ai-dlc-version`, and
   `md5 -q _bmad-output/ai-dlc-update/push-candidate-ledger.md`. At writing the branch was 248
   commits AHEAD of its remote; step 1 auto-pushes an ahead branch. If that push fails, the
   invocation is UN-SYNCED (`core/skills/ai-dlc-update/SKILL.md:229`) and step 6 refuses `apply`;
   if the branch is BEHIND (`core/skills/ai-dlc-update/SKILL.md:207`), fast-forward with
   `git pull --ff-only` and re-invoke; on DIVERGED, stop and ping.

3. **Run the `ai-dlc-update` skill, first without `apply`.** Let it resolve the ref. Do not
   hand-drive `preclassify.sh`, `apply.sh` or the self-update scripts. A run without `apply` ends at
   its report (`core/skills/ai-dlc-update/SKILL.md:1586`).

4. **EXPECT `SELF-UPDATE-DEFER`, and NO self-update branch, NO push and NO re-invocation.** The
   bootstrapping file set in the range is `reconcile/setup-sites.md` alone (prose about party
   personas); no `SKILL.md`, `preclassify.sh`, `apply.sh` or `ledger-reverify.sh` change, and no
   file changes mode. But the range changes rulebook files, and the gate's
   `rulebook-coupled-fixtures` row names 11 of them and 62 fixtures that assert against rulebook
   (the range's twelfth rulebook file, `rule-bodies/rule-28.md`, is not in that row), so it returns
   `SELF-UPDATE-DEFER` with a `SELF-UPDATE-SAFE-STOP -` row saying no intermediate release exists
   to split on. Follow the DEFER bullet (`core/skills/ai-dlc-update/SKILL.md:428`): carry the slice
   into the gated apply, which runs `apply.sh --carried-machinery-slice`
   (`core/skills/ai-dlc-update/SKILL.md:433`), and commit the gate's own
   `self-update-gate-<ts>.md` record there (`core/skills/ai-dlc-update/SKILL.md:437`).

   **The DEFER costs nothing for the report.** The installed reconcile engine is byte-identical to
   0.781.0's for every file the dry run executes, so the report the installed engine writes is the
   report the new one would write, and both `NAMED-UPSTREAM` rows appear in the dry run itself.

   If the gate returns `SELF-UPDATE-OK` instead, the range or the consumer has moved since this
   file was written. STOP and ping.

5. **Compare the RENDERED report against `## Rehearsal`, then do the rulebook-side work apply
   needs.** Compare the rendered report, not raw engine output: `emit-report.sh` drops
   `STILL-LIVE` rows. If the report disagrees with `## Rehearsal` on any bucket, any `HARD-*` row,
   or any ledger row, STOP and ping. When it agrees, these are the items the operator decides
   before `apply` can run, each named by the report:

   - **10 `HARD-LAYER-ADJUDICATION-MISSING` rows** (LC-A1,
     `core/skills/ai-dlc-update/SKILL.md:1019`): one per extension whose hook target this range
     changed. Each needs a verdict recorded in the consumer's existing
     `_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl` under the `clause` and
     `subject_digest` copied from the row. Step 7 has the record shape.
   - **2 `HARD-OVERRIDE-DRIFT-SECTION` rows** (`core/skills/ai-dlc-update/SKILL.md:919`), on the
     `team-roles__dev__bug-class-sweep` and `team-roles__tea__consumer-drift` overrides. The
     report's `RETIRED-LAYER-PASSAGE` rows name the exact override lines carrying retired core text:
     line 157 of the dev override (the old exit-2 sentence of `validate-mutation-red.sh`) and lines
     37-40 of the tea override (the old "your model is set by `/bmad-party-mode`" persona text,
     which 0.781.0 retired because a persona's model is now optional consumer config).
   - **One semantic merge, `core/team-roles/dev.md` (`BOTH-CHANGED->CLASSIFY`).** The consumer's copy
     substitutes its own ownership-path list for the `{ownership_paths}` placeholder
     (`CORE-TEMPLATE-SUBSTITUTED`); theirs adds the pytest no-test-ran and `skip-check: not applied`
     text. Keep the consumer's ownership list and take theirs' new text.
   - **`TEMPLATE-PROSE-MERGE QUICKSTART.md`** and **`TEMPLATE-JSON-MERGE .claude/settings.json`.**
     The settings merge keeps the consumer's own values. The consumer already carries all four
     `aiDlcModels` keys and every `AI_DLC_MODEL_<F>_WINDOW` declaration, so `--check` reports
     `model_window_needed=no` and there is no settings question for the operator. The template's
     `cis` and `tea` efforts are `high`; the consumer's stay `medium`.

6. **Re-invoke with `apply`, and CLOSE BOTH SPRINT-318 CANDIDATES in step 8, on the reconcile
   branch, from the consumer root.** Every write happens inside the skill's isolated branch; do not
   touch the live carry-over ledger. In step 8:

   - **The governing disposition is the `NAMED-UPSTREAM` bullet**
     (`core/skills/ai-dlc-update/SKILL.md:2588`), which allows a hand annotation on absorption. The
     "close ONLY `CLOSE-CANDIDATE` rows" sentence above it
     (`core/skills/ai-dlc-update/SKILL.md:2575`) does not forbid this. Neither entry carries a
     `verify:` receipt, so `NAMED-UPSTREAM` is the only mechanical signal either will ever get.
   - **The two ids, closed by these exact ids:**
     - `PC-S318-VALIDATE-MUTATION-RED-PRINTS-BASELINE-GREEN-FOR-AN-ALL-SKIPPED-RUN-AND-SCORES-IT-UNPROVEN-NOT-UNEVALUABLE`
     - `PC-S318-DEV-ESCALATION-HAS-NO-CAPITAL-PATH-CRITERION-WHILE-CODE-REVIEWER-ESCALATION-DOES`
   - **Annotate each entry with exactly this line, directly under its `###` heading:**

     ```
     **ADOPTED UPSTREAM (v0.781.0, verified <today's date>)**
     ```

     No backtick may sit between the opening `**` and `ADOPTED UPSTREAM`; a backticked form does
     not close. `ledger-rotate.sh` keys on the bold span.
   - **The version is v0.781.0 for both, and the reason is checkable.** Exactly one distribution
     commit names each id, the 0.781.0 release commit, and that commit both carries the fix and sets
     `VERSION` to `0.781.0`. Read it before annotating: the `NAMED-UPSTREAM` row deliberately
     carries no version.
   - **Take step 8's "before" row set AFTER the annotations.** Taken before them, the two
     `NAMED-UPSTREAM` rows vanish and read as a mismatch.
   - **Run `ledger-rotate.sh` the way step 8 prescribes
     (`core/skills/ai-dlc-update/SKILL.md:2629`, usage at
     `core/skills/ai-dlc-update/reconcile/ledger-rotate.sh:94`), and expect exactly two entries to
     move.** Then step 8's acceptance test (`core/skills/ai-dlc-update/SKILL.md:2640`): the
     re-verifier's `cut -f1,2 | sort` row set is identical before and after `--apply`.
   - **The PR merge needs the operator's explicit approval**
     (`core/skills/ai-dlc-update/SKILL.md:2664`), separate from the `apply` argument.

7. **A `CLOSE-CANDIDATE` row is a hypothesis, not a verdict.** For any other id, run that entry's
   receipt directly, read the raw exit code, and ask what ELSE satisfies it before rotating
   anything. The rehearsal produced none.

8. **Report to the operator**: the gate verdict, the report as it actually came out, the `HARD-*`
   rows and how each was dispositioned, which of the two ids closed, and any disagreement with
   `## Rehearsal`.

9. **AFTER THE PULL MERGES, BEFORE YOU STOP: re-derive this file's own `## RESUME HERE` block
   and prove it is still resumable.** The merge is the moment a handoff goes stale. Re-run the
   commands behind `## Rehearsal` against the real post-pull tree and DIFF every figure against
   what this file claims; fix the COMMAND where they disagree, never only the prose. Then re-derive
   the delivery gap and the `PENDING` set in `docs/plans/graph-ledger-full-drain.md` and report both.
   **This action and every one after it write to the DISTRIBUTION**, so a graph session stops at
   action 8 and the operator hands actions 9-12 to a distribution-side session.

10. **Fill in `## Discharge` and retitle this file as discharged.** A spent runbook still reading
    as instructions is this directory's recurring hazard.

11. **THE FRESH-RESUME CHECK, run by the distribution-side session after action 10's docs commit
    has merged.** Read this file from a fresh checkout of `origin/main`, as a stranger resuming it,
    and confirm it reads as discharged there and that `docs/plans/graph-ledger-full-drain.md`
    reports the delivery gap action 9 derived. Run `bash scripts/validate-plan-shape.sh` there as
    the floor.

12. **HAND THE LEDGER PLAN TO A LOCAL AI-DLC SESSION, THEN STOP.** The distribution-side session
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
   `version: 0.781.0`, checked by reading the file.
2. **Graph session, in the dry-run report, before action 6's annotation**: the report carries
   `NAMED-UPSTREAM` rows for both sprint-318 ids. After the annotation the engine emits no row for
   either, so this is not checkable later.
3. **Graph session, after action 6's rotation**: in one invocation, each id counts 1 in
   `push-candidate-ledger.archive.md` and 0 in `push-candidate-ledger.md`, while
   `grep -c '^## '` over `push-candidate-ledger.md` reads non-zero, which proves the ledger read is
   live. **Key this on the id string, not on a heading count**: both entries are `###` headings, so
   the `^## ` count does not move when they rotate (it read 18 before and after on the rehearsal).
4. **Graph session, after the pull's PR merges**: the installed `validate-spawn-ledger.sh`, run with
   `--ledger _bmad-output/spawn-ledger.jsonl --sprint 317 --settings .claude/settings.json`,
   prints persona warnings (`^WARN: \[(tea|ux|sm|cis)\]`) non-zero, against the `^WARN: \[qa\]`
   count as the control, which reads the same on both engines. The installed
   `validate-artifact-budget.sh --root .` prints `pool 330000`, not `pool 66000`.
5. **Distribution-side session, at action 10**: `## Discharge` is filled in and the file is
   retitled.

Criteria 2, 3 and 4 were checked as reachable on the rehearsal clone before this file was written.

## Hazards

- **A false CLOSE is the worst output in this system.** Always run `ledger-reverify` from the
  consumer root, with absolute paths. Both ref arguments are DISTRIBUTION refs, and a consumer sha
  in either slot exits 0 with a plausible, wrong row set.
- **The naming join walks the ancestors of `theirs` only**
  (`core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:694`). After the squash-merge, `theirs`
  is the squash commit on `main`, and the unmerged release commit is not its ancestor, so one
  commit names each id, as on the rehearsal. **If the squash dropped the ids from the commit
  message, both `NAMED-UPSTREAM` rows are absent: STOP and ping**, do not annotate on this file's
  word.
- **`ledger-rotate.sh` exits 0 on a ledger path that does not exist** and reports "nothing to
  rotate". A zero from it on a mistyped path reads exactly like a clean ledger.
- **The Bash tool's shell is zsh.** No `PIPESTATUS`, so `cmd | tail` reports `tail`'s status.
  Never read an exit code through a pipe.
- **The citations in this file resolve in the DISTRIBUTION.** A line number in the consumer's
  installed copy of the same file may be a different line; read the distribution path given.
- **The rehearsal did not drive `apply`, the gated push or the consumer's pre-push.** The gated
  apply's push runs the consumer's whole pre-push suite with the 62 rulebook-coupled fixtures at
  0.781.0; whether that is green, and its wall clock, are unknown. The rehearsal also did not write
  the 12 adjudications or the `dev.md` merge, so the post-adjudication report is unrehearsed.
- **The `pool 330000` figure was taken through a different branch of the window-library resolver.**
  The rehearsal staged 0.781.0's `validate-artifact-budget.sh` beside a `../hooks/ai-dlc-window.sh`;
  an installed tree resolves the library through `.claude/hooks/`. Same bytes, different lookup, so
  done-when 4's pool figure is a prediction until read on the post-pull tree.

## Rehearsal

Run on a `file://` clone of the consumer at its carry-over head, against the unmerged 0.781.0
release commit. These are expectations, not guarantees. If the real run disagrees, STOP and ping.

| step | outcome | wall |
|---|---|---|
| releases behind | 1 | |
| bootstrapping files in range | `reconcile/setup-sites.md` only; 0 mode-only changes | |
| installed engine vs 0.781.0 | all 32 files under `reconcile/` byte-identical to 0.780.0's; only `setup-sites.md` differs at 0.781.0 | |
| `self-update-gate.sh` | `SELF-UPDATE-DEFER` ×2 (`rulebook-coupled-fixtures`: 11 rulebook files, 62 fixtures; and `-`), `SELF-UPDATE-SAFE-STOP -` (no split exists) | 42s |
| `preclassify.sh` raw | 40 rows: 38 `UPSTREAM-ONLY`, 1 `DIST-ONLY-SKIP`, 1 `BOTH-CHANGED->CLASSIFY` (`team-roles/dev.md`) | 10s |
| rendered per-file buckets | the same 40; semantic worklist `core/team-roles/dev.md`; deletions none | 181s |
| rendered TEMPLATE rows | `TEMPLATE-JSON-MERGE .claude/settings.json`, `TEMPLATE-PROSE-MERGE QUICKSTART.md`, `TEMPLATE-UNCHANGED-NOOP` ×2 (`CLAUDE.md`, `docs/coding-conventions.md`) | |
| rendered blocking-layer | 10 `HARD-LAYER-ADJUDICATION-MISSING`, 2 `HARD-OVERRIDE-DRIFT-SECTION` | |
| rendered other | 3 `CORE-TEMPLATE-SUBSTITUTED`; 5 `RETIRED-LAYER-PASSAGE`; hooks 22 present, 22 registered | |
| reverify raw | 10 rows: 7 `STILL-LIVE`, 1 `RECEIPTS-UNDECIDED`, 2 `NAMED-UPSTREAM` (both sprint-318 ids); rendered: 3 rows | 6s |
| `settings-merge.sh --check` | exit 0; `sensor_wired=true`, five windows declared, `model_window_needed=no` | |
| `settings-merge.sh` write form, on the clone | exit 0; 0 changed keys in `aiDlcRoles`, `aiDlcModels` and `env`, and 0 changed top-level keys | |

Controls in the same runs: an impossible id reads 0 in the reverify output and 0 in the naming
query; each sprint-318 id is named by exactly one commit among the ancestors of `theirs`, and that
commit's `VERSION` reads `0.781.0`.

**Why the pull is required, the differential taken on the clone, installed engine against 0.781.0,
same argv, same tree.** The two sides differ (`cmp -s` 1 for each script and for the window
library).

| script | installed 0.780.0 | 0.781.0 | control |
|---|---|---|---|
| `validate-spawn-ledger.sh`, sprint 317 | persona WARN 0; arm-S3 FAIL 10; exit 1 | persona WARN 57 (56 `tea`, 1 `sm`); arm-S3 FAIL 11 (the new one a `tea` row); exit 1 | `[qa]` WARN 72 on both |
| `validate-artifact-budget.sh --root` | `pool 66000`; 2 `OVER`; exit 1 | `pool 330000`; 1 `OVER`; exit 1 | |

**Closing the two candidates, run on the clone with the installed engine:**

| point | reverify rows naming either id | `ledger-rotate.sh` |
|---|---|---|
| no annotation | 2 (`NAMED-UPSTREAM` ×2) | 0 closed entries, nothing to rotate |
| both annotated `v0.781.0` | 0; `STILL-LIVE` ×7 and `RECEIPTS-UNDECIDED` remain | 2 closed entries would move (42 lines) |
| after `--apply` | 0; row set identical to the annotated run (`cmp` 0) | moved 2 |

After the rotation each id read 0 in the ledger and 1 in the archive, against 18 `^## ` headings in
the ledger and an impossible id reading 0 in the archive.

## Discharge
