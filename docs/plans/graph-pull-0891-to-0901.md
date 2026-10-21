# Pull the graph consumer from 0.892.0 to 0.901.0 (leg B of the 0.891.0 to 0.901.0 pull)

`READ and FOLLOW docs/plans/graph-pull-0891-to-0901.md`. **A graph session reads this file at its ABSOLUTE path,
`/Users/n8/git/ai-dlc/docs/plans/graph-pull-0891-to-0901.md`.** From a session rooted in the consumer, the relative
path resolves against the consumer and finds nothing.

## RESUME HERE

**STATE AT WRITING: WRITTEN AND REHEARSED WHILE LEG B WAS ALREADY RUNNING ON GRAPH.** Graph started leg B before this
file landed, and its gate read the rehearsed verdict. An executor already mid-run (its checked-out branch is
`ai-dlc-update/0.901.0-reconcile-<ts>` and `_bmad-output/ai-dlc-update/blocker-adjudication-<ts>.md` exists) enters at
**action 5** — these numbers are this file's actions, not the skill's steps. It runs only the action-2 stamp read on
the carry-over branch, and compares everything from there against `## Rehearsal`. The rehearsal ran on a
`file://` clone of the consumer's carry-over branch, with the consumer's installed engine run from the clone root and
the distribution read from a `file://` clone of this repo's `origin/main`. Every figure in `## Rehearsal` came from
that clone.

**THE PULL SPLITS INTO TWO LEGS.** Graph's dry run to the 0.901.0 range returned `SELF-UPDATE-DEFER`
(`rulebook-coupled-fixtures`, nine rulebook files) with a `SELF-UPDATE-SAFE-STOP` row naming the 0.892.0 release, which
is the remedy `core/skills/ai-dlc-update/SKILL.md:90` prescribes ("Take the ref from that row", line 93).

- **Leg A, 0.891.0 to 0.892.0, is DONE on graph.** Its self-update PR and its leg-1 reconcile PR both merged into the
  carry-over branch, and the leg-1 reconcile wrote `_bmad-output/ai-dlc-update/reconcile-log-20261021T-leg1.md`. It is
  recognised by the stamp `version: 0.892.0` on the carry-over branch. This file does not re-run it.
- **Leg B, 0.892.0 to 0.901.0, is this file's entry point.** Nine releases, 0.893.0 to 0.901.0.

**GRAPH AT WRITING.** Checked out on the carry-over branch `ai-dlc/carry-over/offramp-config-and-rewards`, whose stamp
read `version: 0.892.0` with `skill_version: 0.892.0`, so the entry check in action 2 was already satisfied when leg B
started. A fresh executor runs action 2 in full; one already mid-run re-reads the carry-over stamp once and goes on.

**THE REHEARSAL FIGURES ARE EXPECTATIONS.** A disagreement between the real run and `## Rehearsal` is a STOP-and-ping,
never a judgement call.

**THIS FILE BEING GREEN IS NOT AUTHORIZATION.** `.claude/rules/operator-rulings.md` is unconditional: a consumer pull
is operator-initiated, readiness is not authorization, and a `PENDING` count is not a decision about WHEN. If you are
reading this without the operator having said "run leg B of the pull", stop and ask.

Read `## Start here` FIRST, then `### Next actions`. `## Rehearsal` is what to expect; `## Hazards` is what will bite
you.

## Start here

**YOUR SESSION'S PROJECT ROOT MUST BE `/Users/n8/git/graph`** for actions 1 to 10. Skill scope follows the session
root, not a Bash `cd`, and a session rooted in the distribution cannot invoke the `ai-dlc-update` skill at all. Action
0 and actions 11 onward are for a distribution-side session; a graph session skips them.

- **`/Users/n8/git/graph`**: the consumer. WRITE, and only through the `ai-dlc-update` skill. Every hand edit this pull
  needs (the two CLASSIFY merges, the adjudications, the override readopt) is made inside the skill's steps 7 and 8 on
  its reconcile branch, never as an ad-hoc edit to the live tree.
- **`/Users/n8/git/ai-dlc`**: the distribution. READ ONLY from a graph session: read it, never write it. The one
  exception is `git -C /Users/n8/git/ai-dlc fetch origin` in action 1. It writes the distribution's `.git` (remote-tracking refs and `FETCH_HEAD`), which is harmless.

**THE CONSUMER'S TREE IS DIRTY AND THAT IS EXPECTED.** It carries live `_bmad-output/` pipeline state, which grows
while the pipeline runs. **Do not commit, revert, stash or clean it.** Committing makes the branch ahead of its remote,
and the preflight then auto-pushes in-flight state.

**THE BRANCH THE SKILL WORKS ON IS WHATEVER IS CHECKED OUT, AND IT MOVES WHILE YOU WORK.** The skill's git preflight
(`core/skills/ai-dlc-update/SKILL.md:205`) is relative to the current branch's upstream; a non-`main` branch is not an
error. It cuts its reconcile branch off the current branch (line 209) and opens its PR "into the working branch"
(line 2750). So the checked-out branch decides where leg B lands, and for this pull it must be the carry-over branch.
Re-derive the branch and the head before you start. **Do not switch either yourself**: if action 2 finds the wrong
branch checked out, STOP and ping.

**This file carries no ref and no sha.** The skill resolves the ref itself. Where this file needs the installed
release it names the `commit:` field of `.claude/.ai-dlc-version`, never its value; where it needs a distribution
release it derives the sha from the release's commit subject with a command.

**This file does not re-describe the pull.** The `ai-dlc-update` skill owns resolving the ref, gating its own
self-update, carrying the machinery slice and emitting the worklist. Everything here is what is SPECIAL about leg B.

**What leg B carries**, one line per release, from `CHANGELOG.md` and `git diff --stat` over `core/`:

- **0.893.0**: `join-remediator-shards.sh --check-part`; `core/team-roles/remediator.md` changes.
- **0.894.0**: fixtures only (I55 reach, I110 token window, pre-push pool depth). Nothing consumer-visible.
- **0.895.0**: a resolved `--dispatch` beat at its cap reports LIVE, RECENT or STOPPED: `wait-for-deliverable.sh`,
  `core/hooks/ai-dlc-recover.sh`, `rule-29.md`, `_dispatch-protocol.md`, `_gate-procedures.md`.
- **0.896.0**: `core/git-hooks/pre-push` keys each declared fixture on its runner's whole-file hash. **The consumer's
  first push after leg B re-runs every declared fixture once.**
- **0.897.0**: `artifact_sha` pair emitters write `<stem>@<sha>` only where installed readers accept it. Engine
  scripts, `provenance-block.json`, `_gate-procedures.md`, `gate-validation.md`, `adversary.md`, `remediator.md`.
- **0.898.0**: an In-Flight row's dispatched-at must equal its ledger timestamp, or the gate fails.
  `validate-artifact-budget.sh`, `verdict.sh`, `ai-dlc-derivation-capture.sh`, `gate-validation.md`.
- **0.899.0**: a refused review-shard merge names the correcting seat; `--check-shard` and `--mark` run per-shard
  checks; a lead rewrite plus re-seal is refused (BL-737). `merge-review-shards.sh`, `content-seal.sh`,
  `implementation.md`, `code-reviewer.md`, `qa.md`.
- **0.900.0**: the `validate-mutation-red.sh` capture opens with a replayable command; `core/team-roles/dev.md` changes.
- **0.901.0**: BL-740 VERDICT BACKING in `check_shard()` (`core/scripts/merge-review-shards.sh:91`): a shard's
  NEEDS_REWORK or BLOCKED needs a Critical or Important finding at code-review and any finding at qa, and APPROVED
  carries no Critical.

Derive the range yourself rather than trusting the list (`git -C /Users/n8/git/ai-dlc log --format='%s'` over the
range, and `git diff --stat` over `core/` between the 0.892.0 and 0.901.0 release commits, which read 62 files at
writing).

**What is special about leg B, in one paragraph.** Leg A carried the range's ONE update-skill engine file,
`core/skills/ai-dlc-update/reconcile/layer-drift.sh` (changed in 0.892.0, BL-712: two tab reads keep an empty middle
field), so it is already installed: leg B classifies on the engine that will also apply it, and leg B changes 0 files
under `core/skills/ai-dlc-update/`. Leg B carries **10 `core/scripts/` engine files** (`content-seal.sh`,
`join-remediator-shards.sh`, `merge-adversarial-shards.sh`, `merge-review-shards.sh`, `partition-subject.sh`,
`validate-artifact-budget.sh`, `validate-mutation-red.sh`, `validate-provenance-block.sh`, `verdict.sh`,
`wait-for-deliverable.sh`) and **0 mode changes** across its `core/` diff. The gate is expected to DEFER with no
further split. The report carries **11 `HARD-*` rows, 2 CLASSIFY files, 2 `RETIRED-LAYER-PASSAGE` rows and 1
`UPSTREAM-DELETED` row**; every one is an operator decision, listed in action 5. Graph's leg-1 log names four items
leg B owes; the rehearsal reproduced all four and found a fifth. **No ledger entry closes.**

### Next actions

0. **DESIGNATE THE LEAD BEFORE ANYTHING IS DISPATCHED.** This action binds ONLY a distribution-side session running
   the post-merge actions (11 onward); a graph session running the pull skips it. Operator instruction at batch 236, a
   standard plan shape. The session that receives and ACCEPTS the one-liner is the LEAD; its first call is
   `ListAgents`, and it `SendMessage`s every other `ai-dlc-*` session in the listing (never a `graph-*` session)
   asking for its current state and whether it is free to own a release. A session that has not answered after one
   re-ask and one more timer counts as no session. The lead assigns each available owner one cluster as one release,
   at once and without asking, and reports the roster in its FIRST operator ping. The lead ORCHESTRATES and NEVER
   BUILDS: it scopes, allocates every VERSION and backlog id, lets one push run at a time, verifies each landing by
   content, and runs the docs close. Owners build through hands: an owner makes NO edits, and every edit goes to a
   hand. With no other session available the lead still never builds; the work goes to hands. Every spawn the lead or
   an owner makes carries this sentence verbatim: "Time matters here: do not spend time that can be avoided, and the
   earlier a correct result is obtained, the better." The owner-rules block the lead sends each owner, verbatim, is the
   one in `docs/plans/graph-ledger-full-drain.md` under the action titled "DESIGNATE THE LEAD BEFORE ANYTHING IS
   DISPATCHED" (`docs/plans/graph-ledger-full-drain.md:879`).
   - RELEASES BEFORE MEASUREMENTS. A ready release gates before any measurement.
   - SHORTEST GATE FIRST. Among ready releases, a docs-only release gates first.
   - NO IDLE SESSIONS. Every unassigned item goes to an idle session at once.
   - NO TIMING RUNS. No timing run unless a named fix cannot be chosen without the figure, and the lead approves it.
   - RELEASE TEXT IS PREPARED IN ADVANCE. Each owner's release commit text is written by a hand before its gate opens.

1. **Confirm the operator has authorized leg B, and that the distribution has no `core/` change after the 0.901.0
   release.** Not a `PENDING` count, not this file being green. The distribution's `VERSION` is not the key: later
   releases bump it with docs-only changes. Run `git -C /Users/n8/git/ai-dlc fetch origin`, then, in one invocation:

   ```
   r901=$(git -C /Users/n8/git/ai-dlc log --format=%H -1 --grep='^0\.901\.0 —' origin/main)
   r900=$(git -C /Users/n8/git/ai-dlc log --format=%H -1 --grep='^0\.900\.0 —' origin/main)
   git -C /Users/n8/git/ai-dlc diff --stat "${r901}..origin/main" -- core/ | tail -1    # expect: empty
   git -C /Users/n8/git/ai-dlc diff --stat "${r900}..origin/main" -- core/ | tail -1    # control: non-empty
   ```

   At writing the first read empty and the control read `4 files changed`. If `r901` is empty, or the first line is
   non-empty, or the control is empty, STOP and ping: a `core/` change after 0.901.0 means leg B would pull past the
   rehearsed range.

2. **Record graph's pre-run state, and run the ENTRY CHECK.** Record: `git branch --show-current`,
   `git status --porcelain | wc -l`, `git rev-list --left-right --count '@{u}...HEAD'`, every field of
   `.claude/.ai-dlc-version`, and `md5 -q _bmad-output/ai-dlc-update/push-candidate-ledger.md`. Then read the stamp ON
   THE CARRY-OVER BRANCH:
   `git show ai-dlc/carry-over/offramp-config-and-rewards:.claude/.ai-dlc-version`.

   - **`version: 0.892.0`**: the leg-1 reconcile has merged. Proceed. This is what it read when leg B started.
   - **`version: 0.891.0` with `skill_version: 0.892.0`**: the leg-1 reconcile has NOT merged into the carry-over
     branch. STOP and ping; do not start leg B on top of it. (The rehearsal showed a run from there would be
     full-range on the 0.892.0 engine with the same rows, but the entry check stands.)
   - **Anything else**: STOP and ping.

   Then `git branch --show-current` must read `ai-dlc/carry-over/offramp-config-and-rewards`. If it reads a reconcile
   branch or anything else, STOP and ping; do not switch it. **Exception, mid-run only:** a branch named
   `ai-dlc-update/0.901.0-reconcile-<ts>` is the skill's own leg-B reconcile branch and is EXPECTED. Do not STOP on it.
   Skip the `@{u}` count, which has no upstream there. Once apply has run, the working-tree stamp may read ahead of the
   carry-over's, and that is expected too. Re-read `.claude/.ai-dlc-version` in the working tree: it
   must agree with the carry-over branch's stamp. Step 1 auto-pushes an ahead branch; a failed push makes the
   invocation UN-SYNCED (`core/skills/ai-dlc-update/SKILL.md:230`) and step 2 defers on it
   (`core/skills/ai-dlc-update/SKILL.md:434`). BEHIND (`core/skills/ai-dlc-update/SKILL.md:235`): fast-forward with
   `git pull --ff-only` and re-invoke. DIVERGED (`core/skills/ai-dlc-update/SKILL.md:238`): STOP and ping.

3. **Run the `ai-dlc-update` skill, first without `apply`.** Let it resolve the ref. Do not hand-drive
   `preclassify.sh`, `apply.sh` or the self-update scripts. The gate takes about two minutes and the report render
   about a minute and a half.

4. **EXPECT `SELF-UPDATE-DEFER`, with NO further split.** The gate's `rulebook-coupled-fixtures` row names 9 rulebook
   files (`_dispatch-protocol.md`, `_gate-procedures.md`, `gate-validation.md`, `implementation.md`, `adversary.md`,
   `code-reviewer.md`, `dev.md`, `qa.md`, `remediator.md`), a second `SELF-UPDATE-DEFER -` row follows, and the
   `SELF-UPDATE-SAFE-STOP -` row says no intermediate release self-updates cleanly. Follow the DEFER bullet
   (`core/skills/ai-dlc-update/SKILL.md:456`): no self-update branch, no push, carry the slice into the gated apply.
   The STOP CLASS, which decides every case the expectation does not name:
   - **Any `SELF-UPDATE-SAFE-STOP` row that names a ref** (not `-`): STOP and ping. The range or the consumer has moved.
   - **`SELF-UPDATE-OK`, or any verdict other than the expected one**: STOP and ping.
   - **Any `HARD-*` row, blocker, or bucket not in `## Rehearsal`**: STOP and ping.

5. **Compare the RENDERED report against `## Rehearsal`, then put each decision apply needs to the operator.** Compare
   the rendered report, not raw engine output: each `HARD-*` row and the `UPSTREAM-DELETED` row print twice in it; compare distinct paths, not line counts. If it disagrees on any bucket, any
   `HARD-*` row or any ledger row, STOP and ping. Each item below is the operator's decision, recorded the way the
   skill's adjudication loop prescribes (`core/skills/ai-dlc-update/SKILL.md:1759`, record at
   `core/skills/ai-dlc-update/SKILL.md:1584`; layer verdicts in the register at
   `core/skills/ai-dlc-update/SKILL.md:2017`). The five leg-B items graph has to settle are marked (a) to (e).
   - **2 `BOTH-CHANGED->CLASSIFY` files, `core/team-roles/dev.md` and `core/team-roles/qa.md`**, the semantic
     worklist. Both are `CORE-TEMPLATE-SUBSTITUTED` in graph and both change in leg B. This file's rule, not the
     skill's, and unrehearsed (it fails safe as a STOP): take THEIRS on every changed
     passage and keep graph's template substitution; any other OURS-only line in the printed diff is a STOP.
   - **(b) 10 `HARD-LAYER-ADJUDICATION-MISSING` rows**, graph's "10 extension re-read adjudications", the same 10
     paths as the 10 `EXTENSION-HOOK-DRIFT` rows: under graph's `.claude/skills/ai-dlc/extensions/`,
     `checks/gate-validation-domain.md`, `checks/gate-validation-push-914.md`, `checks/gate-validation-push.md`,
     `checks/validator-honesty.md`, `roles/code-reviewer-domain.md`, `roles/dev-domain.md`, `roles/dev-push.md`,
     `roles/qa-domain.md`, `steps-domain/implementation-domain.md`, `steps-domain/implementation-push.md`. Read each
     extension against the changed core file it hooks before its verdict. The 1 `EXTENSION-TITLE-MATCHES-CORE` row
     (`roles/dev-push.md`) is discharged by that path's adjudication.
   - **(a) 1 `HARD-OVERRIDE-DRIFT-SECTION` row, `overrides/team-roles__dev__bug-class-sweep.md`**: graph's "bug-class-sweep
     override readopt". The other 8 overrides read `OVERRIDE-OK`.
   - **(d) `RETIRED-LAYER-PASSAGE` at `checks/gate-validation-domain.md` line 266**: graph's "retired passage".
   - **(e) `RETIRED-LAYER-PASSAGE` at `overrides/team-roles__dev__bug-class-sweep.md` line 152: NOT NAMED IN GRAPH'S
     LEG-1 LOG.** Carried by item (a): the readopt rewrites this passage. Verify that the post-write retired-passage scan is clean on commit; it is not a separate decision.
   - **(c) 1 `UPSTREAM-DELETED` row, `core/fixtures/wait-beat-liveness/receipt-bl605.sh`**: graph's "deletion
     question". It is paired with an `UPSTREAM-ONLY-ADD` of the same basename under `core/fixtures/budget-summary-verdict/`,
     so the receipt moved fixtures rather than vanishing.
   - **Debt overlap**: the report emits no debt section. Two of the HARD paths, `checks/gate-validation-push.md` and
     `roles/dev-push.md`, also carry `STILL-LIVE` ledger entries; name that to the operator beside their adjudications.
   - **Templates**: all four `TEMPLATE-UNCHANGED-NOOP`. Hooks: 24 present, 24 registered. No settings merge.

6. **Re-invoke with `apply`.** Every write happens inside the skill's isolated reconcile branch, cut off the
   carry-over branch. Run `apply.sh --carried-machinery-slice` the way the DEFER bullet says.

7. **Ledger closes: NONE, per the re-verifier rows.** The rehearsal's re-verifier emitted 8 rows (7 `STILL-LIVE`, 1
   `RECEIPTS-UNDECIDED`) and 0 `CLOSE-CANDIDATE` and 0 `NAMED-UPSTREAM`, identical across both legs; the rendered
   report carries the 1 `RECEIPTS-UNDECIDED` row. The live ledger carries 0 `^### PC-` entries; its only `^### `
   headings are the two retro-filed collections, S295 and S296 (control: 23 `^## ` lines in the same file). The run
   must still confirm two things, from the consumer root, with absolute paths and both ref arguments being
   DISTRIBUTION refs (usage `core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:117`): no new ledger entry appears,
   and the re-verifier's `cut -f1,2 | sort` row set is identical before and after `ledger-rotate.sh --apply`
   (`core/skills/ai-dlc-update/SKILL.md:2727`). Expect the rotate to report "0 closed entries — nothing to rotate".
   Any change is a STOP. A `CLOSE-CANDIDATE` row is a hypothesis, not a verdict: for any such id, run that entry's
   receipt directly, read the raw exit code, and ask what ELSE satisfies it.

8. **Open the PR into the carry-over branch, and merge it only on the operator's explicit approval.** The PR targets
   the working branch (`core/skills/ai-dlc-update/SKILL.md:2750`), which action 2 established is
   `ai-dlc/carry-over/offramp-config-and-rewards`, never `main`. The merge needs separate explicit approval
   (`core/skills/ai-dlc-update/SKILL.md:2752`).

9. **Tell the operator about the BL-740 expected post-pull refusal; do nothing about it inside the pull.** See
   `## Hazards`. It is graph's sprint work, it bites at the next `--gate qa` merge of graph's s319 story 3.1, and
   nothing at pull or push time runs that merge.

10. **Report to the operator**: the gate verdict, the report as it came out, each action-5 decision and how it was
    dispositioned, the ledger row-set comparison, the PR, and any disagreement with `## Rehearsal`. **A graph session
    stops here.** Actions 11 onward write to the DISTRIBUTION; the operator hands them to a distribution-side session.

11. **AFTER THE LEG-B PR MERGES, re-derive this file's own `## RESUME HERE` block and prove it is still resumable.**
    Re-run the commands behind `## Rehearsal` against graph's post-pull carry-over branch, read only, and DIFF every
    figure against what this file claims; fix the COMMAND where they disagree, never only the prose. Then re-derive the
    delivery gap and the `PENDING` set in `docs/plans/graph-ledger-full-drain.md` and report both.

12. **Fill in `## Discharge` and retitle this file as run.** A finished runbook still reading as instructions is this
    directory's recurring hazard.

13. **THE FRESH-RESUME CHECK, after action 12's docs commit has merged.** Read this file from a fresh checkout of the
    distribution's `origin/main`, as a stranger resuming it, and confirm it reads as finished there and that
    `docs/plans/graph-ledger-full-drain.md` reports the delivery gap action 11 derived. Run
    `bash scripts/validate-plan-shape.sh` there as the floor.

14. **HAND THE LEDGER PLAN TO A LOCAL AI-DLC SESSION, THEN STOP.** The distribution-side session calls `ListAgents`;
    if a local `ai-dlc-*` session is found (never a `graph-*` one), it sends, with `SendMessage`, exactly
    `READ and FOLLOW docs/plans/graph-ledger-full-drain.md` and nothing else, then stops. If none is found there is
    nothing further to do.

### Ping the operator

On any question, on any decision, on completion, and on any early stop. From outside, a session that is thinking and
a session that is waiting on a human look identical.

### Done when

Each criterion names its leg, its branch, its observation point and the session that reads it.

1. **Leg A, carry-over branch, before leg B starts, graph session (action 2)**:
   `git show ai-dlc/carry-over/offramp-config-and-rewards:.claude/.ai-dlc-version` reads `version: 0.892.0`. It read
   that when leg B started.
2. **Leg B, carry-over branch, AFTER the leg-B PR merges, graph session**: the same command reads `version: 0.901.0`.
   This holds only because action 1 refuses a range that grew past 0.901.0.
3. **Leg B, reconcile branch, BEFORE the PR, at action 7's acceptance test, graph session**: the re-verifier's
   `cut -f1,2 | sort` row set is identical before and after `ledger-rotate.sh --apply`. Rehearsed reachable: before vs
   after a dry rotate read `cmp` 0, with two controls (theirs rebound to base, and a seeded row) each reading `cmp` 1.
4. **Leg B, reconcile branch, BEFORE the PR, after apply, graph session**: `hard-blockers.sh --post-apply` reads
   `0 HARD blockers.` Not rehearsed for leg B: it needs the operator's decisions on the 11 `HARD-*` rows first. Leg A's
   rehearsal reached the same line on the post-leg-A tree, and graph's own leg-1 run reached it too.
5. **Distribution, `main`, after action 12, distribution-side session**: `## Discharge` is filled in and the file is
   retitled.

## Hazards

- **BL-740 is an EXPECTED POST-PULL REFUSAL, stacked behind an earlier one, and it is graph's sprint work.**
  - **Today**, graph's committed s319 story 3.1 qa pass-2 shard set is refused under the INSTALLED engine, on shard
    `cross-6` (a finding owned by `cross-4`).
  - **After leg B**, once `cross-6` is repaired, the next 3.1 qa pass-2 merge refuses under 0.901.0 on shard `cross-1`,
    which seals NEEDS_REWORK with no finding (`core/scripts/merge-review-shards.sh:91`). Rehearsed: with `cross-6`
    repaired on a scratch copy, the installed engine merged the set and the 0.901.0 engine still refused `cross-1`;
    graph's pass-1 set merged under both engines as the control.
  - **The refusal 0.901.0 prints**, quoted from a captured run, verbatim except that the scratch directory holding the
    shard set is replaced by `<shard-dir>`:

    ```
    REFUSED: <shard-dir>/cross-1.md carries 'shard-verdict: NEEDS_REWORK' but no '#### ' finding in its '## Findings'; a shard's verdict is backed by its own findings. If the finding belongs to another shard, set 'shard-verdict: PASS' here and let that shard's verdict carry it; otherwise file the finding that makes it NEEDS_REWORK here, as a '#### ' heading under '## Findings' (any '### ' container, or none) with a 'parts:' set this shard may own (one the owning group's shard does not already carry) [owner: cross-1]
    ```

  - **Remediation goes through the OWNING seat, per BL-737's prescribed path** (shipped in 0.899.0): the lead
    re-dispatches the `cross-1` seat with the refusal line verbatim and never edits its shard
    (`core/scripts/merge-review-shards.sh:107`).
  - **Nothing at pull or push time runs the merge**: `grep -c merge-review-shards core/git-hooks/pre-push` read 0 at
    writing, against 7 in `core/skills/ai-dlc/steps/implementation.md`. 0.896.0 makes graph's first post-pull push
    re-run every declared fixture once, but fixtures run on seeded trees, not on `docs/reviews/`.
- **An apply `WORKLIST agent-definitions .claude/agents/` row is a disagreement to expect.** The rehearsal's leg-A
  apply emitted it; graph's own leg-1 log records none. If leg B's apply emits it, report it to the operator; it is a
  known rehearsal-vs-graph difference, not a new finding.
- **The checked-out branch decides where leg B lands.** A leg-B invocation from a reconcile branch would cut its
  reconcile branch off that branch and open its PR into it. Action 2 STOPs on that, except the skill's own
  `ai-dlc-update/0.901.0-reconcile-<ts>` branch during a run already past the gate; do not switch the branch yourself.
- **A false CLOSE is the worst output in this system.** Always run `ledger-reverify` from the consumer root, with
  absolute paths. Both ref arguments are DISTRIBUTION refs, and a consumer sha in either slot exits 0 with a
  plausible, wrong row set.
- **`ledger-rotate.sh` exits 0 on a ledger path that does not exist** and reports "nothing to rotate". A zero from it
  on a mistyped path reads exactly like the expected clean ledger, so check the path.
- **The Bash tool's shell is zsh.** No `PIPESTATUS`, so `cmd | tail` reports `tail`'s status. Never read an exit code
  through a pipe.
- **The citations in this file resolve in the DISTRIBUTION.** A line number in the consumer's installed copy of the
  same file may be a different line; read the distribution path given.
- **NOT REHEARSED**: `post-write-gates.sh` (graph's leg-1 run read 4/4); the consumer's pre-push, which on the first
  push after leg B re-runs every declared fixture once (0.896.0), so its result and wall clock are unknown; leg B's
  `apply`, the `dev.md` and `qa.md` merges, and the PR merge, all of which need the operator's decisions on the 11
  `HARD-*` rows first. The post-adjudication report is unrehearsed.

## Rehearsal

Run on a `file://` clone of the consumer at its carry-over branch, stamp asserted `version: 0.891.0` before any
figure was taken, with the consumer's INSTALLED engine run from the clone root and base = the installed `commit:` field.
The distribution was a `file://` clone of this repo with `main` at `origin/main`, passed as the skill's local upstream;
`origin/main` carried 0 `core/` files past the 0.901.0 release (control: 62 across leg B). **Leg B's base tree is
graph's own leg-A self-update commit checked out on the clone**, re-run through steps 3-5 and `apply` on the 0.892.0
engine; it matched graph's live leg-1 reconcile in every file under `.claude/`, `scripts/ai-dlc/` and
`tests/fixtures/`, stamp included (control: the pre-leg-A head differed in 2, 2 and 10 files). **These are
expectations, not guarantees. If the real run disagrees, STOP and ping.**

| step | leg A (0.891.0 engine) | leg B (0.892.0 engine, post-leg-A tree) |
|---|---|---|
| releases behind | 1 | 9 |
| bootstrapping files | `core/skills/ai-dlc-update/`: 1 (`reconcile/layer-drift.sh`); `core/scripts/`: 2; 0 mode changes over 15 `core/` files | `core/skills/ai-dlc-update/`: 0; `core/scripts/`: 10; 0 mode changes over 62 `core/` files (6 adds, 1 delete); a seeded control filter printed 2 mode-changing and 1 mode-only row |
| `layer-drift.sh` effect | installed vs 0.892.0 engine: gate, `--templates`, reverify and `push-drain` byte-identical; preclassify differs only by the 13 slice files moving to `ALREADY-AT-THEIRS`. Full range on both engines: every layer-drift row identical | already installed |
| `self-update-gate.sh` | `SELF-UPDATE-OK` | `SELF-UPDATE-DEFER` `rulebook-coupled-fixtures` (9 rulebook files), `SELF-UPDATE-DEFER -`, `SELF-UPDATE-SAFE-STOP -`; `--safe-stop` exit 1, empty |
| `preclassify.sh` raw | 15: 13 `UPSTREAM-ONLY`, 2 `DIST-ONLY-SKIP` | 62: 47 `UPSTREAM-ONLY`, 6 `UPSTREAM-ONLY-ADD`, 6 `DIST-ONLY-SKIP`, 2 `BOTH-CHANGED->CLASSIFY` (`dev.md`, `qa.md`), 1 `UPSTREAM-DELETED` |
| `preclassify.sh --templates` | 4 `TEMPLATE-UNCHANGED-NOOP` | 4 `TEMPLATE-UNCHANGED-NOOP` |
| rendered `HARD-*` | 0 | 11 distinct paths, each printed twice: 10 `HARD-LAYER-ADJUDICATION-MISSING`, 1 `HARD-OVERRIDE-DRIFT-SECTION` |
| rendered worklist | none | `core/team-roles/dev.md`, `core/team-roles/qa.md` |
| rendered overrides | 9 `OVERRIDE-OK` | 8 `OVERRIDE-OK`, 1 HARD (`team-roles__dev__bug-class-sweep.md`) |
| rendered extensions | none drifting | 10 `EXTENSION-HOOK-DRIFT` (the 10 HARD paths), 1 `EXTENSION-TITLE-MATCHES-CORE` (`roles/dev-push.md`) |
| rendered retired / deletions | none / none | 2 `RETIRED-LAYER-PASSAGE` / 1 `UPSTREAM-DELETED` |
| other rendered | 3 `CORE-TEMPLATE-SUBSTITUTED`, 5 `PREDICATE-STABLE`, hooks 24/24 | hooks 24/24; 0 `RETIRED-CONTRACT-TOKEN`, 0 `RETIRED-LAYER-TOKEN` (anchored; an impossible token read 0) |
| `ledger-reverify` raw / rendered | 8 (7 `STILL-LIVE`, 1 `RECEIPTS-UNDECIDED`) / 1 | the same 8 (`cmp` 0 against leg A) / 1 |
| `push-drain.sh` at theirs vs installed (control) | 4 `PUSH-REFUSED` both (blocks 1-4 of `implementation-push.md`), same digests | same |
| BL-740 pass-2 set | installed engine: exit 2, refused on `cross-6` | 0.901.0 engine: exit 2, refused on `cross-1`; after a scratch repair of `cross-6`, installed exit 0, 0.901.0 still exit 2; pass-1 set exit 0 under both (control) |

**Leg B items graph has to settle, against graph's leg-1 log.**

| item | graph's leg-1 log | rehearsal |
|---|---|---|
| (a) bug-class-sweep override readopt | named, 1 | reproduced, 1 `HARD-OVERRIDE-DRIFT-SECTION` |
| (b) extension re-read adjudications | named, 10 | reproduced, 10 `HARD-LAYER-ADJUDICATION-MISSING` |
| (c) `wait-beat-liveness/receipt-bl605.sh` deletion question | named, 1 | reproduced, 1 `UPSTREAM-DELETED` |
| (d) retired passage at `gate-validation-domain.md` line 266 | named, 1 | reproduced, 1 `RETIRED-LAYER-PASSAGE` |
| (e) retired passage at `team-roles__dev__bug-class-sweep.md` line 152 | NOT NAMED IN GRAPH'S LEG-1 LOG — carried by (a) | 1 `RETIRED-LAYER-PASSAGE` |

**Graph's own full-range dry run agreed.** Its report region (0.891.0 engine, full range) against the rehearsal's
full-range render on the same engine differed in 10 lines, all sha, distribution-path or an uncommitted
`settings.local.json` hook count; every bucket row agreed. Control: the same region against the leg-B render differed
in 24 lines.

**The ledger at rehearsal.** Live ledger: 0 `^### PC-` entries, 2 `^### ` headings (the S295 and S296 retro-filed
collections), 23 `^## ` lines (control). Archive: 16 `^### PC-`. The impossible id `PC-ZZ-IMPOSSIBLE-CONTROL-Q9X`
read 0 in both. `ledger-rotate.sh` dry: "0 closed entries — nothing to rotate (436 lines stay)", exit 0.

## Discharge
