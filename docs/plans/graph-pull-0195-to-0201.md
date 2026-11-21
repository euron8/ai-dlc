# Pull the graph consumer from 0.1195.0 to 0.1201.0 (two legs: to 0.1198.0, then the rest)

`READ and FOLLOW docs/plans/graph-pull-0195-to-0201.md`. **A graph session reads this file at its ABSOLUTE path,
`/Users/n8/git/ai-dlc/docs/plans/graph-pull-0195-to-0201.md`.** From a session rooted in the consumer, the relative
path resolves against the consumer and finds nothing.

## RESUME HERE

**STATE AT WRITING: WRITTEN AND REHEARSED; READY, NOT AUTHORIZED.** `.claude/rules/operator-rulings.md` is
unconditional: a consumer pull is operator-initiated, readiness is not authorization, and a `PENDING` count is not a
decision about WHEN. If you are reading this without the operator having said "run the pull", stop and ask.

**THE RANGE IS WIDE: six releases, 0.1196.0 to 0.1201.0**, with bootstrapping paths in it (the `ai-dlc-update` skill,
the `ai-dlc` skill, `reconcile/apply.sh`, `reconcile/self-update-gate.sh`) and 0 mode-only changes under `core/`.

**THE PULL SPLITS.** The rehearsed gate on the full range returns `SELF-UPDATE-DEFER` (`rulebook-coupled-fixtures`)
and a `SELF-UPDATE-SAFE-STOP` row that names the 0.1198.0 release, with the remedy "pull to 0.1198.0 FIRST, then pull
again for the rest" (`core/skills/ai-dlc-update/SKILL.md:87`). Leg A is 0.1195.0 to 0.1198.0; leg B is 0.1198.0 to
0.1201.0. The skill resolves both refs itself; this file names releases, never refs.

**THE REHEARSAL FIGURES ARE EXPECTATIONS.** A disagreement between the real run and `## Rehearsal` is a STOP-and-ping,
never a judgement call. Read `## Start here` FIRST, then `### Next actions`; `## Rehearsal` is what to expect;
`## Hazards` is what will bite you.

## Start here

**YOUR SESSION'S PROJECT ROOT MUST BE `/Users/n8/git/graph`** for actions 1 to 12. Skill scope follows the session
root, not a Bash `cd`, and a session rooted in the distribution cannot invoke the `ai-dlc-update` skill at all.
Actions 0 and 13 onward are for a distribution-side session; a graph session skips them.

- **`/Users/n8/git/graph`**: the consumer. WRITE, and only through the `ai-dlc-update` skill. Every hand edit this
  pull needs (the Rule 8 re-point, the adjudications, the retro override) is made inside the skill's reconcile
  branch, never as an ad-hoc edit to the live tree.
- **`/Users/n8/git/ai-dlc`**: the distribution. READ ONLY from a graph session: read it, never write it. The one exception is
  `git -C /Users/n8/git/ai-dlc fetch origin` in action 1.

**THE CONSUMER'S TREE IS DIRTY AND THAT IS EXPECTED.** It carries live `_bmad-output/` pipeline state, which grows
while the pipeline runs; do not enumerate it. **Do not commit, revert, stash or clean it.** Committing makes the
branch ahead of its remote and the preflight then auto-pushes in-flight state.

**THE BRANCH THE SKILL WORKS ON IS WHATEVER IS CHECKED OUT.** The skill cuts its reconcile branch off the current
branch (`core/skills/ai-dlc-update/SKILL.md:205`) and opens its PR into it. At writing graph is on its carry-over
branch `ai-dlc/carry-over/base-capital-path`, stamped `version: 0.1195.0`, and so is `main`. Do not switch the branch
yourself: if action 2 finds another, STOP and ping.

**This file carries no ref and no sha.** **This file does not re-describe the pull**: the `ai-dlc-update` skill owns
resolving the ref, gating its own self-update, carrying the machinery slice and emitting the worklist. Everything
here is what is SPECIAL about this range.

**What the range carries** (`CHANGELOG.md`, sections 0.1196.0 to 0.1201.0; derive it yourself with `git -C
/Users/n8/git/ai-dlc log --format='%s'` over the range):

- **Leg A, 0.1196.0 to 0.1198.0**: the retired-layer-passage scan ignores fenced code; a faithful readopt rebase
  stamps readopt across a cross-section reflow; the update PR commits only the pull's own writes, delivers past a
  staged deletion or rename, bounds its body, replaces a role setting the consumer never changed. Engine files:
  `apply.sh`, `pull.sh`, `readopt-override.sh`, `retired-layer-passage.sh`, `self-update-push.sh`,
  `settings-merge.sh`, `template-sites.md`. No `core/scripts/` path changes, so leg A self-updates cleanly.
- **Leg B, 0.1199.0 to 0.1201.0**: the retro handoff prompt keeps ids (rewrites a section of `steps/retro.md`);
  `_gate-procedures.md` and gate 3 changes; `SKILL.md` Rules 2 to 12 and 21 move to `rule-bodies/` (0.1200.0);
  `core-paths.sh` and `derive-fixture-readsets.sh` become held on the self-update (0.1201.0, no effect on this range).
  **`templates/settings.json.template` changed**, so `.claude/settings.json` takes a JSON template merge.

**What is special, in four lines:**

1. **Graph's Rule 8 override needs the re-point step, never a merge.** `overrides/SKILL__Rule-8.md` shadows
   `SKILL.md#Rule 8`, which moved to `rule-bodies/rule-8.md`. The steps are `CHANGELOG.md:37` onward, rehearsed
   below. `readopt-override.sh --merge` silently cuts graph's 71-line override to 19 lines with 0 conflicts (BL-1201).
   Never run `pull.sh merge`, `--merge`, `--stamp readopt` or `--stamp retire` on it.
2. **A second override drifts that the CHANGELOG does not name**: `overrides/steps__retro__domain-sections.md`
   (shadows `steps/retro.md#7. Merge and Next-Sprint Handoff`, among others). It reads `STALE-CORE-TEXT`, 2 lines.
   It is an operator decision (action 8); never `--merge` it either.
3. **`.claude/settings.json` takes a template JSON merge** (`WORKLIST template-json-merge`). The update PR commits a
   rewritten `settings.json` whole (BL-1202), so an operator-dirty `settings.json` would ride into the PR. At
   writing graph's tree does not carry a dirty `settings.json` (3 dirty paths, all `_bmad-output/`); re-check in
   action 2 and STOP and ping if it is dirty.
4. **graph's committed `_bmad-output/ai-dlc-update/reconcile-report.md` makes apply refuse `UPSTREAM-MOVED`.** Not a
   fault: the skill handles it; report what it says, and do not hand-delete the file.

### Next actions

0. **DESIGNATE THE LEAD BEFORE ANYTHING IS DISPATCHED.** Binds ONLY a distribution-side session running the
   post-merge actions (13 onward); a graph session skips it. The session that ACCEPTS the one-liner is the LEAD; its
   first call is `ListAgents`, and it `SendMessage`s every other `ai-dlc-*` session (never a `graph-*` one) asking for
   its state and whether it is free to own a release. The lead ORCHESTRATES and NEVER BUILDS: it scopes, allocates
   every VERSION and backlog id, lets one push run at a time, verifies landings by content and runs the docs close.
   Owners build through hands and make no edits themselves (every edit goes to a hand). Every spawn carries this sentence verbatim: "Time matters here: do not spend time
   that can be avoided, and the earlier a correct result is obtained, the better." Every hand runs on this machine
   as a background `Agent`; a writing hand passes `isolation: "worktree"`, a read-only hand passes none. Every brief
   forbids `rm -rf` on a variable path. The owner-rules block is in `docs/plans/graph-ledger-full-drain.md` under
   the action titled "DESIGNATE THE LEAD BEFORE ANYTHING IS DISPATCHED" (`docs/plans/graph-ledger-full-drain.md:879`). The
   train rules: RELEASES BEFORE MEASUREMENTS, SHORTEST GATE FIRST, NO IDLE SESSIONS, NO TIMING RUNS, RELEASE TEXT IS
   PREPARED IN ADVANCE, BUNDLE ONLY TO CUT WALL CLOCK.

1. **Confirm the operator has authorized the pull, and that the distribution has no `core/` change after the 0.1201.0
   release.** Run `git -C /Users/n8/git/ai-dlc fetch origin`, then in one invocation:

   ```
   r1201=$(git -C /Users/n8/git/ai-dlc log --format=%H -1 --grep='^0\.1201\.0' origin/main)
   r1200=$(git -C /Users/n8/git/ai-dlc log --format=%H -1 --grep='^0\.1200\.0' origin/main)
   git -C /Users/n8/git/ai-dlc diff --stat "${r1201}..origin/main" -- core/ | tail -1    # expect: empty
   git -C /Users/n8/git/ai-dlc diff --stat "${r1200}..origin/main" -- core/ | tail -1    # control: non-empty
   ```

   If `r1201` is empty, the first line is non-empty or the control is empty, STOP and ping: a `core/` change after
   0.1201.0 means the pull would run past the rehearsed range.

2. **Record graph's pre-run state and run the ENTRY CHECK.** Record `git branch --show-current`,
   `git status --porcelain` (count and whether `.claude/settings.json` is among them), `git rev-list --left-right
   --count '@{u}...HEAD'` and every field of `.claude/.ai-dlc-version`. The stamp must read `version: 0.1195.0`.
   Anything else, a branch other than the carry-over branch, a DIVERGED upstream
   (`core/skills/ai-dlc-update/SKILL.md:238`) or a dirty `settings.json`: STOP and ping. BEHIND
   (`core/skills/ai-dlc-update/SKILL.md:235`): `git pull --ff-only`, then re-invoke.

3. **Run the `ai-dlc-update` skill, first without `apply`.** Let it resolve the ref. Do not hand-drive
   `preclassify.sh`, `apply.sh` or the self-update scripts. **EXPECT the split**: `SELF-UPDATE-DEFER` with
   `rulebook-coupled-fixtures`, a second `SELF-UPDATE-DEFER -` row, and a `SELF-UPDATE-SAFE-STOP` row that names the
   0.1198.0 release. Follow it: run leg A (skill `<0.1198.0 ref> apply`, the ref taken from that row), then leg B
   (`apply` with no ref). **STOP CLASS**: a SAFE-STOP row naming any other release or `-` on the first invocation,
   `SELF-UPDATE-OK` on the full range, or any HARD row or bucket not in `## Rehearsal`: STOP and ping.

4. **Leg A.** Expect `SELF-UPDATE-OK` (`this pull changes no core/scripts/ path`), 17 `UPSTREAM-ONLY` and 3
   `DIST-ONLY-SKIP`, 4 template rows `TEMPLATE-UNCHANGED-NOOP`, 0 HARD rows, 36 `EXTENSION-OK`, 9 `OVERRIDE-OK`. The
   apply manifest should read 17 `RESOLVED pure-apply`, 1 `WORKLIST agent-definitions`, `DECISION restamp-withheld`,
   `DECISION artifact-derivations-differential`. Let the skill's self-update PR and reconcile PR run as it prescribes;
   each merges only on the operator's explicit approval (`core/skills/ai-dlc-update/SKILL.md:1426`).

5. **Leg B, report only, then put each decision to the operator.** Start from the tree after leg A. Compare the
   RENDERED report against `## Rehearsal`; compare distinct paths, not line counts. Any disagreement on a bucket,
   a HARD row or a ledger row: STOP and ping. The operator's decisions, recorded as the skill's adjudication loop
   prescribes (`core/skills/ai-dlc-update/SKILL.md:176`):
   - **14 `HARD-LAYER-ADJUDICATION-MISSING` rows**, one per drifting extension (13 `EXTENSION-HOOK-DRIFT`, 1
     `EXTENSION-ANCHOR-DRIFT`, listed in `## Rehearsal`). Read each extension against the changed core file before
     its verdict. **3 of them are `LC-E4` on `SKILL.md`**: `extensions/steps-domain/party-mode-inline-relay.md`,
     `SKILL-domain.md` and `SKILL-push.md`, each needing one line in
     `_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl` (whole-line `read` quotes, not substrings).
   - **2 `HARD-OVERRIDE-DRIFT-SECTION` rows**: `SKILL__Rule-8.md` (action 6) and `steps__retro__domain-sections.md`
     (action 8).
   - **5 `EXTENSION-TITLE-MATCHES-CORE` rows**: discharged by those paths' adjudications.
   - **2 `BOTH-CHANGED->CLASSIFY` files** resolve as `setup-site-merge` in apply; no hand merge is expected.

6. **The Rule 8 re-point, after leg B's apply has delivered `rule-bodies/rule-8.md`, on the reconcile branch.** Run
   the five steps of `CHANGELOG.md:37` (0.1200.0) exactly as written, with `<dist>` the distribution clone the skill
   used, `<old-base-sha>` the leg-B base, `<theirs>` the leg-B ref. Expected: step 2's diff is the added preamble line
   plus one blank line only; step 3 prints `STAMPED  SKILL__Rule-8.md: base_sha <old> -> <theirs> (reaffirm)` and
   the override goes from 71 to 72 lines; step 4's `pull-decisions.tsv` row; step 5 prints `OVERRIDE-OK ...
   SKILL__Rule-8.md rule-bodies/rule-8.md` with no HARD row for Rule 8. `retired-layer-passage.sh` prints 46
   `RETIRED-LAYER-PASSAGE` rows on `SKILL__Rule-8.md`; they need no edit. A line count other than 72 after step 3, a
   diff beyond the preamble, or any `--merge` having been run: STOP and ping.

7. **Retired passages.** Expect 48 `RETIRED-LAYER-PASSAGE` rows in total: 46 on `SKILL__Rule-8.md` (action 6) and 2
   on `steps__retro__domain-sections.md` (action 8).

8. **The retro override.** `readopt-override.sh <dist> <theirs> <consumer> <override> --check` reports
   `STALE-CORE-TEXT`, 2 lines copied from the old core that the new core no longer contains (the "related-epic
   stretch scope" lines of the handoff prompt, 0.1199.0). The override is 577 lines and the answer is the
   operator's: re-adopt the new core text by hand, or `--stamp reaffirm --note "<why the old clause still stands>"`.
   Never `--merge` (BL-1201). This step is UNREHEARSED beyond `--check`; present both options with a recommendation.

9. **The settings.json merge.** Leg B's apply emits `WORKLIST template-json-merge .claude/settings.json`; the
   restamp-withheld rows read 24 rather than 23. Run the merge as the skill prescribes, then read the diff of
   `.claude/settings.json` on the reconcile branch before the PR: it must contain only the template's additions. Any
   line that is not the template's: STOP and ping (BL-1202).

10. **Close the ledger candidates, by id, from the consumer root.** Run
    `bash /Users/n8/git/ai-dlc/core/skills/ai-dlc-update/reconcile/ledger-reverify.sh <dist-repo> <base-sha>
    /Users/n8/git/graph <theirs-ref>` (usage `core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:117`); both ref
    arguments are DISTRIBUTION refs, never a consumer sha. The rehearsal's leg-B rows name these ids:
    `CLOSE-CANDIDATE` on `PC-S324-PULL-DELIVER-STAGES-ALL-CHANGED-PATHS-SWEEPING-OPERATOR-STATE-INTO-UPDATE-PR`,
    `PC-S324-READOPT-REBASE-REFUSED-ON-CROSS-SECTION-REFLOW-REMAINDER` and
    `PC-S324-RETIRED-LAYER-PASSAGE-FENCE-EXCLUSION-DEFEATED-BY-STAR-STRIP`; `NAMED-UPSTREAM` with no close row on
    `PC-S324-DELIVER-STAGE-REFUSES-ALREADY-DELETED-PATHS-SINCE-PRISTINE-DELETE-STAGES-ONE`,
    `PC-S324-DELIVER-PR-BODY-UNBOUNDED-EXCEEDS-GITHUB-64K-ON-LARGE-REGIONS` and
    `PC-S324-ASK-REISSUES-ON-TRUNCATED-DIGEST-CITE-NO-DIAGNOSTIC-WHEN-ANSWER-RECORD-EXISTS`;
    `NAMED-UPSTREAM` plus `HAND-REVIEW` on `PC-S323-7D-HANDOFF-PROMPT-OMITS-CARRYOVER-IDS-...`;
    `NAMED-UPSTREAM-CITED-ONLY` plus `HAND-REVIEW` on `PC-S323-CONTEXT-MODE-ONE-READ-CAP-DENIES-...`;
    `NAMED-UPSTREAM` plus `STILL-LIVE` on `PC-S324-IMPLEMENTATION-PUSH-STORY-STATUS-CONSISTENCY-CHECK-...`. A
    `CLOSE-CANDIDATE` is a hypothesis, not a verdict: for each, run the entry's receipt directly, read the raw exit
    code and ask what ELSE satisfies it, then apply `ledger-rotate.sh --apply` on the path the skill names. Report
    which ids closed and which did not. A false close retires a live entry. The rehearsal ran `ledger-reverify`
    only; it did not run the receipts or the rotate.

11. **Open the PR into the carry-over branch, merge only on the operator's explicit approval.** Before opening it,
    check the PR's file list against the writes the pull made (BL-1202) and name any path that is not the pull's.

12. **Report to the operator**: each leg's gate verdict, the rendered reports, each action-5 decision and its
    disposition, the Rule 8 step outputs, the ledger rows and which ids closed, the PRs, and every disagreement with
    `## Rehearsal`. **A graph session stops here.** Actions 13 onward write to the DISTRIBUTION.

13. **AFTER THE LEG-B PR MERGES, re-derive this file's own `## RESUME HERE` block and prove it is still resumable.**
    Re-run the commands behind `## Rehearsal` against graph's post-pull carry-over branch, read only, and DIFF every
    figure against what this file claims; fix the COMMAND where they disagree, never only the prose. Then re-derive
    the delivery gap and the `PENDING` set in `docs/plans/graph-ledger-full-drain.md` and report both.

14. **Fill in `## Discharge` and retitle this file as run**, then the docs commit merges.

15. **THE FRESH-RESUME CHECK, after action 14's docs commit has merged.** Read this file from a fresh checkout of
    the distribution's `origin/main` as a stranger, confirm it reads as finished and that
    `docs/plans/graph-ledger-full-drain.md` reports the delivery gap action 13 derived, assert that file's
    next-action list names no id a commit on `origin/main` has shipped, and run `bash scripts/validate-plan-shape.sh`
    there as the floor.

16. **HAND THE LEDGER PLAN TO A LOCAL AI-DLC SESSION, THEN STOP.** The distribution-side session calls `ListAgents`;
    if a local `ai-dlc-*` session is found (never a `graph-*` one), it sends, with `SendMessage`, exactly
    `READ and FOLLOW docs/plans/graph-ledger-full-drain.md` and nothing else. A spent session answers
    `REFUSED: ...`; on that reply try the next untried session; an unspent one replies `ACCEPTED <path>`. If none
    is found there is nothing further to do.

### Ping the operator

On any question, on any decision, on completion, and on any early stop. From outside, a session that is thinking and
a session that is waiting on a human look identical.

### Done when

1. **Carry-over branch, after leg A's reconcile PR merges, graph session**: `git show
   ai-dlc/carry-over/base-capital-path:.claude/.ai-dlc-version` reads `version: 0.1198.0`. NOT rehearsed: the
   rehearsal's leg-A apply withheld the restamp (`DECISION restamp-withheld`), so the stamp read `0.1195.0` after it;
   the stamp advances on the skill's own finish step, which was not run.
2. **Carry-over branch, after the leg-B PR merges, graph session**: the same command reads `version: 0.1201.0`.
3. **Reconcile branch, before the PR, after the Rule 8 step 3**: `wc -l` of the override reads 72 and step 5 prints
   `OVERRIDE-OK` for it. Rehearsed reachable.
4. **Reconcile branch, before the PR, after apply and every adjudication**: `hard-blockers.sh --post-apply` reads `0
   HARD blockers.` NOT rehearsed: it needs the operator's decisions first.
5. **Distribution, `main`, after action 14**: `## Discharge` is filled in and the file is retitled.

## Hazards

- **`--merge` on a layered override is a silent data loss** (BL-1201): 71 to 19 lines on the Rule 8 override, 0
  conflicts reported. The same holds for the retro override.
- **The update PR commits rewritten files whole** (BL-1202): check the PR's file list, `.claude/settings.json`
  first.
- **A false CLOSE is the worst output in this system.** Always run `ledger-reverify` from the consumer root with
  absolute paths; a consumer sha in a ref slot exits 0 with a plausible, wrong row set.
- **`ledger-rotate.sh` exits 0 on a ledger path that does not exist** and reports "nothing to rotate"; check the path.
- **The Bash tool's shell is zsh.** No `PIPESTATUS`; never read an exit code through a pipe.
- **The citations in this file resolve in the DISTRIBUTION**; the consumer's installed copy may differ.
- **0.1129.0's watchdog declaration is already present**: `git -C /Users/n8/git/graph grep -c
  pytest-footprint-watchdog HEAD -- docs/coding-conventions.md` reads 2 on the carry-over branch, with `pytest` as
  the present-token control reading 27 and an impossible token reading no row. No precondition to add.
- **NOT REHEARSED**: the skill's own self-update and reconcile PRs, the stamp advance, `post-write-gates.sh`, the
  consumer's first push after the pull (its pre-push result and wall clock are unknown), the retro override resolution, the LC-E4 register lines, the settings.json merge output,
  graph's dirty `_bmad-output/` (a clone does not carry it), and the receipts of the ledger candidates.

## Rehearsal

Run on a `file://` clone of graph at its checked-out carry-over branch (stamp `0.1195.0`), with this repo's engine at
its 0.1201.0 release commit as the distribution (a clone checked out detached there), base the 0.1195.0 release
commit, using the distribution's `core/skills/ai-dlc-update/reconcile/` scripts directly (`self-update-gate.sh`,
`preclassify.sh`, `layer-drift.sh`, `apply.sh`, `ledger-reverify.sh`, `retired-layer-passage.sh`,
`readopt-override.sh`). Graph's dirty `_bmad-output/` and its committed `reconcile-report.md` handling (removed from
the clone before each run) are the two things a clone does not reproduce. Leg B's base tree is leg A's apply output
committed on the clone. **These are expectations, not guarantees. If the real run disagrees, STOP and ping.**

| item | full range (one invocation) | leg A (0.1195.0 to 0.1198.0) | leg B (0.1198.0 to 0.1201.0, post-leg-A tree) |
|---|---|---|---|
| releases | 6 | 3 | 3 |
| gate | `SELF-UPDATE-DEFER` (`rulebook-coupled-fixtures`), `SELF-UPDATE-DEFER -`, `SELF-UPDATE-SAFE-STOP` naming the 0.1198.0 release | `SELF-UPDATE-OK` | `SELF-UPDATE-DEFER` (same), `SELF-UPDATE-SAFE-STOP -` |
| `core/` files changed / skill-dir files | 88 / 9 | 20 / 8 | 68 / 1 (`self-update-gate.sh`) |
| `preclassify.sh` | 13 add, 2 CLASSIFY, 7 skip, 66 only | 17 `UPSTREAM-ONLY`, 3 `DIST-ONLY-SKIP` | 13 `UPSTREAM-ONLY-ADD`, 2 `BOTH-CHANGED->CLASSIFY`, 4 `DIST-ONLY-SKIP`, 49 `UPSTREAM-ONLY` |
| `--templates` | `settings.json.template` is `TEMPLATE-JSON-MERGE`, 3 NOOP | 4 NOOP | 1 `TEMPLATE-JSON-MERGE`, 3 `TEMPLATE-UNCHANGED-NOOP` |
| `layer-drift.sh` | 14 `HARD-LAYER-ADJUDICATION-MISSING`, 2 `HARD-OVERRIDE-DRIFT-SECTION`, 13 `EXTENSION-HOOK-DRIFT`, 1 `EXTENSION-ANCHOR-DRIFT`, 5 `EXTENSION-TITLE-MATCHES-CORE`, 22 `EXTENSION-OK`, 7 `OVERRIDE-OK` | 36 `EXTENSION-OK`, 9 `OVERRIDE-OK`, 0 HARD | the same as the full range |
| `apply.sh` | not run | 17 `RESOLVED pure-apply`, 1 `WORKLIST agent-definitions`, 1 `DECISION restamp-withheld`, 1 `DECISION artifact-derivations-differential`, rc 0; stamp stayed `0.1195.0` | 62 `RESOLVED pure-apply`, 2 `RESOLVED setup-site-merge`, 13 `WORKLIST extension-reread`, 5 `WORKLIST extension-title-match`, 2 `WORKLIST override-readopt`, 1 `WORKLIST template-json-merge`, 1 `WORKLIST retired-layer-passage`, 1 `WORKLIST artifact-derivations`, 1 `WORKLIST agent-definitions`, `DECISION restamp-withheld`, `DECISION artifact-derivations-differential`, rc 0 (run with `--carried-machinery-slice`) |
| `retired-layer-passage.sh` | | | 48: 46 on `SKILL__Rule-8.md`, 2 on `steps__retro__domain-sections.md` |
| `ledger-reverify.sh` | | | 3 `CLOSE-CANDIDATE`, 8 `NAMED-UPSTREAM`, 1 `NAMED-UPSTREAM-CITED-ONLY`, 2 `HAND-REVIEW`, 8 `STILL-LIVE`, 1 `RECEIPTS-UNDECIDED` |
| Rule 8 steps 1 to 5 | | | override 71 lines before and 72 after; step 2 diff is the preamble plus one blank line; step 3 `STAMPED  SKILL__Rule-8.md: base_sha <old> -> <theirs> (reaffirm)`; step 5 `OVERRIDE-OK ... rule-bodies/rule-8.md`; `validate-layer-entries.sh` 0 errors, 1 warning (W3 on `extensions/steps-domain/route-domain.md`, not traced to this pull), `entries=45 at_current=45 behind=0` |
| retro override | | | `readopt-override.sh --check`: `STALE-CORE-TEXT`, 2 lines |

**The ledger rows above are leg B's row set (base the 0.1198.0 release); they were not re-taken on the full range.**
The `7a` differential of the batch-262 close (old vs new engine on a clone) read `self-update-gate.sh` identical and
`apply.sh` diverged by one row, `WORKLIST template-json-merge .claude/settings.json`; that agrees with leg B above.

## Discharge

