# Runbook — pull the graph consumer from 0.356.0 to 0.357.0, mid-sprint s302

**Status: READY TO RUN.** 0.357.0 is merged to the distribution's `main` (PR #534). Not yet run
against the live consumer.

**No ref and no sha are written down in this file, deliberately.** The skill pulls latest by
default; it resolves the distribution ref itself. Nothing here needs to name one, and a name written
down goes stale the moment anything lands — including a docs commit to this very file, which is how
the previous revision falsified its own acceptance criterion.

**The pull itself is the `ai-dlc-update` skill's job, and this file does not re-describe it.** An
earlier draft walked the pull step by step and every one of those steps was a restatement of
something the skill already owns — which is how they went stale. The skill resolves the ref, gates
its own self-update, carries the machinery slice, emits the worklist, and tells you when the
settings reconcile is needed. Follow what it prints.

What this file is for is the part no skill does: **resetting the s302 `[story]` gate.** The reset
only. Re-running the gate is a pipeline resume, the operator has deliberately kept that out of this
plan, and `_bmad-output/pipeline-paused.flag` is the seam between the two — it is present on this
consumer, it blocks pipeline-step execution, and **this run does not clear it.**

**So this run does NOT test the release end to end, and must not report that it did.** The stall
rung's live behaviour is exercised whenever the operator resumes the pipeline, which is a separate
decision on their own schedule.

## Start here

**Execute this from a session whose PROJECT ROOT is `/Users/n8/git/graph`.** Skill scope follows
the session root, not a Bash `cd`, and the skill exists only at
`/Users/n8/git/graph/.claude/skills/ai-dlc-update/`. A session rooted in the distribution cannot
invoke it at all. If yours is, stop and ping the operator for a restart.

Two repos, and the boundary is absolute.

- **Distribution — `/Users/n8/git/ai-dlc`. Read it, never write it.** It carries 0.357.0. The skill
  reads it; you do not need to name a ref into it.
- **Consumer — `/Users/n8/git/graph`, the tree you WRITE.** Mid-sprint s302, stopped and committed
  at `0fd25d10d` *"handoff mid [story]-gate adjudication cascade (pass 11 of 11 FAIL, pass 12
  stopped)"*. Stamp reads `version: 0.356.0` / `commit: 959e778`.

**The working tree is NOT clean and that is expected.** The modified files are hook-written
`_bmad-output/` state — no artifact among them.

**Their number is not fixed and this file does not enumerate them.** The set GROWS while the
pipeline runs: asking the operator a question writes one, and an earlier draft of this file named
four when there were already six. A count written down here is stale by the time you read it, so
judge by the path — anything modified under `_bmad-output/` is pipeline state — and if something
outside `_bmad-output/` is dirty, stop and ping the operator.

**Do not commit, revert, stash or clean any of them.** Committing makes the branch ahead of its
upstream, and the skill's git preflight then auto-pushes s302's in-flight state to
`origin/ai-dlc/feature/s302-position-usd-create-position` on a bare dry run.

What this release carries: remediation is dispatched to a `remediator` instead of applied by the
lead, enforced by a PreToolUse hook that denies the edit; a stall rung that escalates when one check
holds FAIL across three consecutive passes of one gate; and a worklist that derives the fan-out of a
repair from the diff instead of from the lead's memory.

**Ping the operator** on any question, on any decision this file does not settle, and on completion
— including an early stop. A session that stops silently is indistinguishable from one still
working, and every stall in this repo's history ended with the operator asking rather than the
session reporting.

## Next actions

1. **Confirm the branch is in sync**, which is the one precondition the skill's preflight depends
   on:

   ```
   git rev-list --left-right --count @{u}...HEAD
   ```

   Expect two zeros, behind and ahead. **Any other reading: STOP**, do not invoke the skill, and
   ping the operator — a branch that is ahead gets auto-pushed, and what is on it is not this
   runbook's to publish.

   **Then record the starting commit. Everything later in this file refers to it, and no sha is
   written down here because the consumer is live and its HEAD moves.**

   ```
   git rev-parse HEAD
   ```

   Call that **`START`**. It is the pre-pull state, the fan-out base, and the only restore point
   §Abort has. Keep it where you can paste it — the apply moves `HEAD` off this commit and off this
   branch, so you cannot re-derive it afterwards.

   Record the stamp too, for the same reason — it is what criterion 1 compares against:

   ```
   cat .claude/.ai-dlc-version
   ```

2. **Run the pull.** Invoke the `ai-dlc-update` skill — bare for the dry run, then with `apply`
   after reading the report. These are skill invocations, not shell commands; `ai-dlc-update` is
   not on `PATH`.

   Do what the report and the apply manifest tell you, including the settings reconcile if it asks
   for one. The command it prints is a template with placeholders, not something to paste
   unmodified. Ping the operator for anything the report does not settle.

   **The apply does not land on the sprint branch.** The skill cuts a reconcile branch, commits its
   writes there, pushes it and opens a PR, and it merges only on explicit operator approval — it
   does not auto-merge. So `HEAD` moves off the sprint branch, and the pull is not on the sprint
   branch until that PR is approved. Ping the operator when the PR is open, and say what step 4
   still needs.

3. **Run the consumer's pre-push suite.** `core.hooksPath` is unset here, so `git push` runs none
   of it:

   ```
   bash .githooks/pre-push
   ```

4. **Reset the s302 `[story]` gate — 4a, 4b and 4c, then STOP.** This is the step this runbook
   exists for, and it ends at the reset. Do not re-run the gate; see 4d.

   a. Mint a new `gate_series_id`. **Retain all eleven existing verdict files** —
      `_bmad-output/gate-adjudication/story-20260811T*.verdict.json`, untouched. A reset deletes
      nothing and overwrites nothing.

      **There is no retired id to name.** All eleven predate the field and carry no
      `gate_series_id`. Identify the retired series by its nonce range,
      `story-20260811T183741Z` through `story-20260811T214958Z`, and say in the entry that it
      predates the field. Append the entry to `docs/escalations/pending.md`; appending is not what
      §Do not touch protects. `gate-validation.md`'s reset protocol asks for the retired id and
      cannot be satisfied literally here — record the nonce range and never fabricate an id.

   b. Derive the repair fan-out rather than sweeping by memory:

      ```
      bash scripts/ai-dlc/report-propagation-fanout.sh "$START~1" "$START" --sprint s302
      ```

      Two refs deliberately: that gives the committed-state answer. Exit 3 means the scope never
      resolved — fix the scope and re-run rather than reading an empty worklist as clean.

   c. Hand the worklist to a **dispatched `remediator`**, per `_gate-procedures.md`. The lead does
      not apply these edits; the new PreToolUse guard will deny it, and that denial is the release
      working.

   d. **Rewrite the pipeline snapshot so it describes the reset gate. Without this the reset is
      invisible and the whole step is decorative.** `_bmad-output/pipeline-snapshot.md` is the ONLY
      thing a fresh `ai-dlc` session reads to decide what to do next — `route.md` Step 0 takes
      `current_step_file` from it and follows its resume instruction — and 4a writes the new
      `gate_series_id` into an escalation entry, which resume never reads. Nothing joins the two.

      Three statements in the snapshot still describe the old cascade, and **all three instruct a
      resuming session to continue it.** Each must be restated:

      - the **Pipeline Position** line `Gate validation [story]: IN PROGRESS, 11 completed
        adjudication passes (all FAIL on Check 7), pass 12 stopped mid-flight for handoff` — restate
        as RESET, naming the new `gate_series_id`, with **zero passes recorded against it**;
      - the Recent Activity line stating that `resume must dispatch pass 12 (or 13) with a fresh
        nonce before anything else`;
      - the **`RESUME'S FIRST PIPELINE ACTION`** paragraph, which names pass 12 or 13 explicitly and
        hands the next session pass 12's brief verbatim.

      Replace the resume instruction with: **run gate validation `[story]` from pass 1 of the new
      `gate_series_id`, against the repaired corpus.** Keep the corpus-wide
      `docs/architecture.md:<N>` sweep that paragraph already demands — 4b's worklist is what
      discharges it, and it is the finding that closed pass 11.

      Leave `current_step_file: stories-test-strategy.md` **unchanged.** The schema binds it to the
      step that INVOKED the gate, §1–§7 are all marked COMPLETE in the snapshot, and resume
      therefore re-enters at the gate rather than re-running the step. Pointing it at
      `gate-validation.md` would break that binding.

      **Delete no history.** The eleven passes stay recorded. What changes is the instruction to the
      next session, not the account of what happened. That paragraph already carries one stale
      instruction it warns the reader not to act on (`if pass 7 returns clean…`); do not leave a
      second.

   e. **Land 4a–4d on a branch and open a PR into the sprint branch. Do not leave this work loose
      in the tree.** 4a, 4c and 4d all WRITE — an escalation entry, the remediator's repairs across
      the worklist, and the snapshot rewrite. Left uncommitted they are a pile of modified files
      with no author and no reason attached, and the next lead to resume reads them as stray drift
      rather than a deliberate gate reset. That is the same failure mode the apply avoids by cutting
      a reconcile branch; step 4 gets no branch from the skill, because the skill does not run it.

      Mirror the pull's shape: branch off the **sprint branch as it now stands, with the reconcile
      PR merged**, commit there, push, open a PR into the sprint branch, and **merge only on
      explicit operator approval.** The PR body is where the reset gets its account: the retired
      series named by its nonce range, the new `gate_series_id`, the worklist size and its control,
      and the snapshot statements you rewrote in 4d.

      **Stage explicit paths. Never `git add -A` or `git add .` here.** The hook-written
      `_bmad-output/` state is dirty and must STAY dirty — sweeping it into this commit publishes
      s302's in-flight state, which is the exact outcome §Do not touch exists to prevent. Stage the
      escalation file, the repaired artifacts named in the worklist, and the snapshot; nothing else.
      Diff the staged set before committing and confirm no state file is in it.

   f. **STOP. Do NOT run gate validation `[story]`.** Running the gate is a pipeline resume; the
      operator has separated it from this plan and will schedule it independently. An authorization
      to dispatch the `remediator` in 4c does not cover it, and neither does any instruction in this
      file.

      Leave `_bmad-output/pipeline-paused.flag` where it is — but **do not report it as what holds
      the pipeline, because it is not.** `SKILL.md`'s INITIALIZATION clears it as its first action
      (`rm -f _bmad-output/pipeline-paused.flag`), by design, because the UserPromptSubmit hook
      re-creates it on every user message including the `/ai-dlc` invocation itself. It blocks
      advancement *within* a session; it does not survive the start of a new one. **What holds the
      pipeline is the operator not invoking, and after 4d, a snapshot that says the gate was reset
      rather than telling the next session to dispatch pass 12.**

5. **Verify** against §Done when, then **hand off**: what is done, what is untouched, the resume
   point. Ping the operator.

## Done when

1. **All four stamp lines advanced.** `cat .claude/.ai-dlc-version` and compare against the reading
   you recorded in step 1: both version lines now say `0.357.0`, and both commit lines differ from
   what they said before. Compare against your own recorded reading rather than against a sha named
   here — a stamped sha is whatever the skill pulled, and this file does not know it.

2. **`scripts/ai-dlc/validate-hook-registration.sh` exits 0** with `UNREGISTERED: none` and
   `DANGLING: none`. It runs inside `apply.sh` too. Two hooks get registered by the settings
   reconcile: this release's `ai-dlc-gate-remediation-guard.sh`, and `ai-dlc-rules-floor.sh`, which
   has been present-but-unregistered for six releases. One would mean the merge under-reached.

3. **The gate is RESET and NOT re-run.** A new `gate_series_id` exists; all eleven prior verdict
   files are still on disk; `_bmad-output/pipeline-paused.flag` is still present. Observation
   point: after 4c, with nothing run against the gate afterwards.

   **What this run therefore does NOT establish, and must not be reported as establishing:** the
   stall rung's live behaviour. Whether the reset gate closes or stalls and escalates by pass 3 is
   the end-to-end test of this release, it requires the pipeline resume the operator has kept out
   of this plan, and it happens on their schedule rather than in this run. Report the rung as
   UNTESTED-LIVE.

3a. **The snapshot instructs pass 1, not pass 12.** Grep `_bmad-output/pipeline-snapshot.md` for
   `pass 12` and for `pass 13`: both must be absent from the resume instruction, and the
   `RESUME'S FIRST PIPELINE ACTION` paragraph must name the new `gate_series_id` and pass 1.
   **Carry a control in the same reading** — grep the file for the retired nonce range, which MUST
   still be present, because a snapshot that lost its history is a different failure from one that
   was correctly updated. A resuming session reads only this file; if it still says pass 12, the
   reset did not happen no matter what 4a wrote elsewhere.

3b. **Step 4's writes are on a branch with an open or merged PR, and the working tree carries no
   stray reset edits.** `git status --porcelain` shows the hook-written `_bmad-output/` state files
   and NOTHING ELSE — no escalation file, no repaired artifact, no snapshot. If any of those is
   still modified and uncommitted, 4e did not run and the next lead inherits unattributed drift.
   The state files being dirty is the PASS condition here, not a failure; committing them would be
   the failure.

4. **The fan-out worklist is non-empty and its items are checked.** Roughly ten against
   `START~1..START`, including a citation from a story file into `docs/architecture.md`.
   Control: `--no-frozen` returns a much larger set, which shows the filter is doing work rather
   than the corpus being empty.

5. **The pre-push suite is green.** Expect `148 ok / 0 FAIL`. **The fixture count MOVES across the
   pull** — 144 before, because this release adds four fixtures (`gate-remediation-deny`,
   `gate-repair-record`, `gate-series-rung`, `hook-registration-join`) and removes none. Read the
   fixture line rather than the exit code: the hook drains the ref protocol, and under a non-tty
   stdin its push-judging arm runs on an empty ref list and prints PASS without judging anything.

6. **`scripts/ai-dlc/validate-artifact-paths.sh` exits 0, `VERDICT: PASS`.** It passes on this
   consumer at both versions, so it is not evidence the pull did anything. It fails on the
   distribution and that reading does not transfer here.

## Rehearsal

Executed twice against `git clone --local` copies of the consumer, with a second pristine clone kept
un-pulled as the control arm. Nothing was written to `/Users/n8/git/graph`: same `HEAD` and the same
set of modified `_bmad-output/` files at the start and end of both runs.

**The first rehearsal found two regressions this release had introduced into the distribution's own
`core/`** — a gate carrying the writing form of `derive-stories`, which a fixture's control arm
exists to catch, and an origin tag in audited prose. Both were fixed before the release merged, so
whatever the skill pulls carries the fixes. The second rehearsal proved them gone on both arms, with
the checks proven still able to fire: re-introducing each defect drove its check back to red.

**Structural limits.** A `--local` clone carries committed state only, so nothing here certifies the
dirty hook-written `_bmad-output/` state or any ledger receipt. The gate reset (step 4) needs a live gate and
was never rehearsed. `core.hooksPath` is unset on the live consumer too, which is why step 3 invokes
the hook by hand.

**A cold read, separate from the rehearsals, is what caught the rest.** The rehearsals tested
whether the commands work; they never tested whether the document was coherent read front to back,
and that is where the blocking defects were — including a step that told the executor to commit the
dirty files, which would have published s302 state mid-sprint.

## Abort

**`START` — the commit you recorded in step 1 — is the restore point, and you must name it in the
command.** **Two things here commit.** The skill does, on apply: it cuts a reconcile branch off the
sprint branch, commits its writes there, pushes it, and opens a PR. And **step 4e does**, on its own
branch off the merged sprint branch. So `HEAD` is neither `START` nor the sprint branch for most of
this run — a bare `git checkout -- <path>` restores from whichever of those commits you are standing
on, which is a silent no-op that looks like it worked.

**Which abort you need depends on where you stopped.** Before 4e, step 4's writes are uncommitted
and `git checkout "$START" -- <path>` reaches them. After 4e they are committed on the step-4
branch, `START` no longer describes them, and the abort is to close the PR and leave the branch
unmerged rather than to restore paths — the sprint branch never received them.

- **The apply goes wrong** — restore with `git checkout "$START" -- <path>`, anchored explicitly.
  **Name the paths.** `git checkout "$START" -- .` would revert the `_bmad-output/` state files and
  destroy s302's in-flight work.
- **Paths the apply CREATED are not in `START`** — this release adds fixtures and a hook that do
  not exist on the consumer yet, and `git checkout` cannot restore a file to not existing. It
  errors and leaves them. Reverting the modified files without removing the created ones leaves a
  half-pulled tree. **Do not reach for `git clean`** — it would take the `_bmad-output/` state with
  it. Stop and ping the operator.
- **The settings reconcile damages `settings.json`** — it preserves consumer-owned keys
  (`env.AI_DLC_MODEL_ROW`, permissions, mcpServers, statusLine). If any is lost, restore that file
  alone with `git checkout "$START" -- .claude/settings.json` and ping the operator before
  re-running.
- **The gate reset loses a verdict file** — stop. The eleven retired verdicts are evidence; a reset
  that deletes is a defect in the reset, not a step to work around.

## Do not touch mid-sprint

- The eleven `_bmad-output/gate-adjudication/story-20260811T*.verdict.json` files. They are the
  retired series and the backtest corpus.
- The existing `## [S302` entries in `docs/escalations/pending.md` and their operator citations.
  The entries, not the file — step 4a appends to it.
- The frozen review records the fan-out worklist deliberately excludes — `*-adversarial-p*.md`,
  `*-repair*.md`, `stories-party-mode/`, `docs/reviews/`. Their citations are accurate accounts of
  what an earlier pass read; repairing them falsifies the record.
