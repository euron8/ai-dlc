# Runbook — pull the graph consumer from 0.356.0 to 0.357.0, mid-sprint s302

**Status: REHEARSED TWICE, BOTH BLOCKING REGRESSIONS DISCHARGED, THE MERGE NO LONGER BLOCKED —
STILL NOT RUN AGAINST THE LIVE CONSUMER, AND DO NOT HAND THIS TO A CONSUMER SESSION UNTIL 0.357.0
IS ON THE DISTRIBUTION'S `main`.** The two regressions the first rehearsal found are fixed at
`a5b041f`, and a second rehearsal re-proved them gone against an un-pulled control clone of the
same consumer commit. What still holds the handoff is not the regressions: until 0.357.0 is on
`main`, every placeholder in this file resolves to the wrong release — see §Rehearsal item 1.
This release exists because of what happened on this consumer: the s302 `[story]` gate ran eleven
adjudication passes and stopped. The pull carries the machinery that would have ended it at pass
three, and step 9 then **resets that gate and re-runs it clean**, so the release is tested
end-to-end this sprint rather than next.

**§Rehearsal IS FILLED. The first rehearsal found two BLOCKING regressions this release introduced;
both are DISCHARGED at `a5b041f` and the second rehearsal proved them gone.** Both sat in the
distribution's own `core/`, not in the merge, so a consumer could not have fixed them and the pull
would have broken their pre-push suite. Each is kept here with the differential that closed it,
because the differential is what makes the fix checkable:

1. **`story-fields-derive` went PASS -> FAIL**, fixture byte-identical across the pull.
   `steps/gate-validation.md:474` carried the writing form
   `` `scripts/ai-dlc/sprint-status.sh derive-stories` `` — the exact string that fixture's control
   arm exists to catch. Introduced by this release's Check 5 adjudication. **DISCHARGED: PASS on
   BOTH arms of the second rehearsal, exit 0**, with `run.sh` byte-identical across the pull
   (`cmp` exit 0; the same `cmp` returns 2 against a different file). The arm still fires —
   appending the bare writing form drove the fixture to exit 1 / FAIL, and restoring returned PASS.
2. **`audit-rule-files.sh --fail-on=deterministic` went 0 -> 1 tier-1 finding**: an `ORIGIN_TAG`
   of `v0.350.0` in prose at `.claude/skills/ai-dlc-update/SKILL.md:1479`, delivered by this
   release itself. **DISCHARGED: exit 0 and `tier-1 findings: 0` on BOTH arms**, denominators
   matching at `107 files scanned` and `78 skill files searched` on each, tier-2 identical at 23
   NARRATIVE_DRIFT + 1 RULE_WEAKNESS and `all findings: 24`. The check still fires — appending an
   origin-tagged sentence gave exit 1 with 1 tier-1, and restore returned 0.

Criteria 6 and 7 in this file were ALSO wrong when it shipped. Both are corrected in place below,
and §Rehearsal items 3 and 4 carry what each was wrong about.

## Start here

Two repos, and the read/write boundary between them is absolute.

- **Distribution — `/Users/n8/git/ai-dlc`. Read it, never write it.** `main` does NOT carry
  `0.357.0`: `main` and `origin/main` are `d2378b4` with `VERSION` `0.356.0`, and `0.357.0` lives
  only on the unmerged branch `feat/v0.357.0-gate-remediation-delegation`. Until it merges, every
  placeholder in this file resolves to the wrong release — §Rehearsal item 1 has the mechanism,
  the three consequences, and what each placeholder resolves to once it is on `main`.
  Every step below reads from this tree and edits none of it.
- **Consumer — `/Users/n8/git/graph`, the tree you WRITE.** Mid-sprint s302, stopped and committed
  at `0fd25d10d` *"handoff mid [story]-gate adjudication cascade (pass 11 of 11 FAIL, pass 12
  stopped)"*. `.claude/.ai-dlc-version` reads `version: 0.356.0` / `commit: 959e778`.

**The working tree is NOT clean and that is expected.** Four hook-written state files are modified
— `_bmad-output/.context-sensor-state`, `.driver/turns`, `pipeline-continuation-log.md`,
`subagent-context.jsonl`. No artifact among them. They predate this work. Do not treat their
presence as a failed precondition and do not revert them.

What this release carries: remediation is dispatched to a `remediator` instead of applied by the
lead, enforced by a PreToolUse hook that denies the edit; a stall rung that escalates when one
check holds FAIL across three consecutive passes of one gate; and a worklist that derives the
fan-out of a repair from the diff instead of from the lead's memory.

**Ping the operator** on any question, on any decision this file does not settle, and on
completion — including an early stop. A session that stops silently is indistinguishable from one
still working, and every stall in this repo's history ended with the operator asking rather than
the session reporting.

## Next actions

Run everything from `/Users/n8/git/graph`. **Use Bash, not Write/Edit**, except where a step says
otherwise.

1. **Commit the pipeline's own in-flight state first**, so the pull is separable for the abort
   path. The four hook-written files above are the subject.

---

2. **Dry-run the pull and read the report. Do not apply yet.**

   ```
   ai-dlc-update
   ```

---

3. **Run the self-update gate explicitly.** Its answer changes the apply form.

   ```
   bash .claude/skills/ai-dlc-update/reconcile/self-update-gate.sh \
        /Users/n8/git/ai-dlc <base-sha> <theirs-sha> "$PWD"
   ```

   Expect `SELF-UPDATE-DEFER` plus a `SELF-UPDATE-SAFE-STOP` row naming the ref to stop at. If the
   slice is deferred, step 4 needs `--carried-machinery-slice` or two of the four stamp lines stay
   at the old version.

---

4. **Apply.**

   ```
   ai-dlc-update apply
   ```

---

5. **Reconcile `settings.json`. This step is not optional and it is not automatic.**

   `apply.sh` deliberately excludes all four template-derived user-owned files — `CLAUDE.md`,
   `coding-conventions.md`, `QUICKSTART.md`, `settings.json` — because each is operator-gated and
   `settings-merge.sh` takes an operator answer (`--model-row`) a non-interactive driver has no
   channel to ask for. It is an operator-visible step by design, not a gap.

   **`--template` needs a FILESYSTEM path and the consumer carries no template**, so materialize
   it from the distribution ref first. Substitute `<theirs>` with the ref you applied in step 4.

   ```
   t=$(mktemp)
   git -C /Users/n8/git/ai-dlc show <theirs>:templates/settings.json.template > "$t"
   bash .claude/skills/ai-dlc-update/reconcile/settings-merge.sh \
        --consumer .claude/settings.json --template "$t"
   ```

   Running it without a materialized `--template` exits 1 with usage. There is no
   `settings.json.template` anywhere under the consumer's `.claude/` and there is not meant to be.

   **This registers TWO hooks on this consumer, not one.** The new
   `ai-dlc-gate-remediation-guard.sh` is this release's. The other,
   `ai-dlc-rules-floor.sh`, has been present-but-unregistered on this consumer since v0.350.0 —
   six releases — and the same merge repairs it. Two is correct here; one would mean the merge
   under-reached.

---

6. **Confirm the pull's hooks are actually wired.**

   ```
   bash scripts/ai-dlc/validate-hook-registration.sh
   ```

   The criterion is **exit 0 with both `UNREGISTERED: none` and `DANGLING: none`** — not any
   particular count. The counts move the moment anyone adds a hook. A nonzero exit names the hook
   and prints a fix command with no placeholders in it.

---

7. **Do the ledger work and the extension rereads** as the dry-run report lists them, recording
   `still-additive` / `contradicts-core` / `retire` per hooked entry into
   `layer-adjudication-register.jsonl`.

---

8. **Run the consumer's own pre-push suite the way its hook runs it**, never a hand-rolled loop
   over the fixture directories.

---

9. **Reset the s302 `[story]` gate and re-run it clean.** This is the step this runbook exists for.

   a. Mint a new `gate_series_id`. **Retain all eleven existing verdict files under the retired
      id** — a reset deletes nothing and overwrites nothing. Record the reset as an escalation
      entry naming the retired id, the new one, and the reason.

   b. Derive the repair fan-out rather than sweeping by memory:

      ```
      bash scripts/ai-dlc/report-propagation-fanout.sh 0fd25d10d~1 0fd25d10d --sprint s302
      ```

      Two refs, deliberately: that gives the committed-state answer. The one-ref form diffs against
      the working tree, which is the right default mid-repair but not what you want here.

   c. Hand the worklist to a **dispatched `remediator`**. The lead does not apply these edits; the
      new PreToolUse guard will deny it, and that denial is the release working.

   d. Run gate validation `[story]` from pass 1 on the repaired corpus. The stall rung counts the
      new series only, so it fires only if the *new* loop stalls.

---

10. **Verify.** See §Done when.

11. **Hand off.** State what is done, what is untouched, and the resume point. Ping the operator.

## Done when

Each criterion states its **observation point** and its **expected** result, because three of them
are not "green" and an executor told to expect green would report failure for work that succeeded.

1. **`.claude/.ai-dlc-version` reads `0.357.0` on ALL FOUR lines.** Observed after step 4, or after
   step 4 plus the carried-machinery slice if step 3 deferred it.

   ```
   grep -cE '0\.357\.0|<new-sha>' .claude/.ai-dlc-version
   ```

   Control: the same file read before step 4 shows `0.356.0` / `959e778`, and that pairing is what
   makes the four meaningful.

2. **`validate-hook-registration.sh` exits 0 with both `none` lines.** Observation point: after
   step 5, not after step 4 — the hook file lands at apply and the registration does not.
   Control: run it BEFORE step 5 and expect a nonzero exit naming
   `ai-dlc-gate-remediation-guard.sh`. A run that passes before the reconcile means it is reading
   the wrong tree.

3. **`ai-dlc-rules-floor.sh` is registered.** It was not, for six releases. Observed after step 5.

4. **The reset `[story]` gate either CLOSES, or STALLS AND ESCALATES BY PASS 3.** Either is a
   passing test of this release. **The eleven-pass shape is the failure.** If the stall rung fires,
   that is the machinery working — run the Rule 12 escalation, do not re-dispatch a fourth pass.

5. **The fan-out worklist is non-empty and its items are checked.** Expect roughly ten items
   against `0fd25d10d~1..0fd25d10d`, including a citation from a story file into
   `docs/architecture.md`. Control: the same command with `--no-frozen` returns a much larger set;
   the pairing shows the frozen-set filter is doing work rather than the corpus being empty.
   **Exit 3 is not a clean result** — it means the scope never resolved, so fix the scope and
   re-run rather than reading the empty worklist as clean.

6. **`validate-artifact-paths.sh` exits 0 with `VERDICT: PASS`.** Observation point: the consumer,
   after step 4. Control: an un-pulled clone of the same consumer commit exits 0 with `VERDICT:
   PASS` identically, so this criterion reports the consumer's standing state at both versions and
   is not evidence the pull did anything.

   Scoped to `/Users/n8/git/ai-dlc` and to no other tree: the same script exits 1 there with
   `FAIL — 2 blocking`. That reading is a fact about the distribution. Do not carry it onto the
   consumer, do not fix it here, and do not report it as a regression from this pull.

7. **The consumer's pre-push suite is green — exit 0, `148 ok / 0 FAIL`.** Observation point: after
   step 8, run through the consumer's own hook as `bash .githooks/pre-push` from the consumer root.

   **The fixture COUNT MOVES across the pull, and 148 is the post-pull number.** Before the pull
   the same suite reports `144 ok / 0 FAIL`, exit 0. The pull ADDS four fixtures and removes none:
   `gate-remediation-deny`, `gate-repair-record`, `gate-series-rung`, `hook-registration-join`.
   Count 144 before step 4 and 148 after; a rise of exactly four, accounted for by those names, is
   the pull landing correctly rather than the suite changing shape.

## Rehearsal — this runbook was executed against a copy TWICE before it shipped

Both passes used the same instrument: `git clone --local /Users/n8/git/graph` at `0fd25d10d`, one
copy pulled and a second pristine clone of the same commit kept un-pulled as the before-arm
control. Nothing was written to `/Users/n8/git/graph` in either pass: `git status --short` read the
same four modified hook-written files at the start and at the end, and `HEAD` stayed `0fd25d10d`.

**First rehearsal**, against branch tip `43729cc`. Executed on the copy: step 3's self-update gate;
step 4 as `reconcile/apply.sh --carried-machinery-slice`; step 5's settings merge, verbatim and
then corrected; step 6 both arms; criteria 1, 2, 3, 5 (both arms), 6; and step 8's whole pre-push
suite, 148 fixtures, **1m24s at 781% CPU** — nowhere near a time-box. It produced the eight
findings below and the two blocking regressions in the header.

**Second rehearsal**, against branch tip `a5b041f`, the commit that fixed both regressions. It
re-ran the two arms that had gone red and the whole suite on both arms:

- fixture `story-fields-derive` and `audit-rule-files.sh --fail-on=deterministic` — both green on
  both arms, each with a mutation probe proving the check still fires. Figures in the header.
- full pre-push suite from the clone root: pulled **148 ok / 0 FAIL, exit 0, 79s**; control
  **144 ok / 0 FAIL, exit 0, 78s**. Both failure sets empty. The 148-vs-144 gap is the pull adding
  four fixtures and removing none, named in criterion 7.
- apply, re-verified end to end: gate `SELF-UPDATE-DEFER` exit 0; `apply.sh
  --carried-machinery-slice <dist> 959e778 <consumer> a5b041f` exit 0; the stamp reached ALL FOUR
  lines. Hook registration exit 1 before the reconcile and exit 0 after, 14 registrations to 16
  present hooks, the added pair exactly `ai-dlc-gate-remediation-guard.sh` and
  `ai-dlc-rules-floor.sh`.
- `validate-artifact-paths.sh`: pulled exit 0 `VERDICT: PASS`; control exit 0 `PASS`, identical;
  `/Users/n8/git/ai-dlc` exit 1 `FAIL — 2 blocking`. This is the reading that rewrote criterion 6.

**Eight things the first rehearsal contradicted**, each of which a prediction would have written the
other way. Items 3 and 4 carry the second rehearsal's result:

1. **`main` does not carry `0.357.0`, so every placeholder in this file resolves to the WRONG
   RELEASE, and §Start here is where it starts.** `main` and `origin/main` are both `d2378b4`,
   `VERSION` `0.356.0`; `0.357.0` exists only on the unmerged branch
   `feat/v0.357.0-gate-remediation-delegation`, and `git merge-base --is-ancestor` says it is **not
   reachable from `main`** (control: `main` IS an ancestor of that branch, so the test is oriented).
   Three consequences, all mechanical:
   - Step 2's `ai-dlc-update` bare resolves `theirs` to **upstream HEAD** (`SKILL.md:52`, `:142`),
     which is `origin/main` — so the dry-run reports the wrong release and step 4 pulls it.
   - `apply.sh:1120` takes the stamp from `git show "${THEIRS}:VERSION"`, so an apply against
     `main` writes `0.356.0` and **criterion 1 can never go green** — an unreachable criterion of
     exactly the kind [[plan-shape-measured]] exists to prevent.
   - Substituting `<theirs>` in step 5 with the only ref this file names has the merge read the
     `0.356.0` template.

   Nor can a sha be written down instead: that branch tip took **five values across these two
   rehearsals** — `1568427` → `3077489` (the `feat` commit amended) → `263ef07` → `43729cc` (a
   `docs(plan):` commit stacked on top, then itself amended) → `a5b041f` (the regression fix). The
   fifth arrived after this item was written, which is the item's own conclusion holding under
   test: a tip that moves both by amendment and by accretion is not an identifier a runbook can
   carry. **The placeholders are not resolvable until `0.357.0` is on `main`.** Once it
   is, all four resolve and none needs a literal: `<base-sha>` is the consumer's own
   `sed -n 's/^commit: //p' .claude/.ai-dlc-version`; `<theirs-sha>` and `<theirs>` are
   `origin/main`; and step 2's report states BOTH on its line 3 — verified by running
   `emit-report.sh` against the copy, which printed ``_base_ `959e778` → _theirs_ `43729cc`.`` So
   the harvest instruction step 2 is missing is one sentence: *record the `_base_ → _theirs_` line;
   steps 3 and 5 both need it.* `<new-sha>` has no such source and is circular — it can only be
   read out of the stamp the apply just wrote — so criterion 1 should name theirs' sha as the
   expected value rather than asking the executor to supply it.
2. **The `--template` path this step was authored with does not exist on a consumer and never did**
   — `.claude/skills/ai-dlc-update/templates/settings.json.template`; step 5 above now carries the
   corrected form, and this is the finding that produced it. Run as authored it prints
   `FAIL: cannot read template: .claude/skills/ai-dlc-update/templates/settings.json.template` and
   exits 1 — no `templates/` directory ships to a consumer at all (control: the sibling
   `reconcile/settings-merge.sh` on the same line resolves). The template lives only in the
   distribution's git objects, so the resolvable form is
   `t=$(mktemp); git -C /Users/n8/git/ai-dlc show <theirs>:templates/settings.json.template > "$t"`
   and then `--template "$t"`. `validate-hook-registration.sh` prints this fix itself, and its
   version clones the upstream over the network rather than reading the distribution already on
   disk.
3. **Criterion 6 was never true of this consumer, at EITHER version — the pull is not what makes it
   false.** On the pulled consumer `validate-artifact-paths.sh` exits **0** — `VERDICT: PASS`,
   5011 conforming of 5109 tracked files — and the pre-push arm that runs it passes. The second
   rehearsal ran the un-pulled control clone too, and it exits **0** with `VERDICT: PASS`
   identically, which is the stronger statement: this is the consumer's standing state before and
   after, not a state the pull produced. The `exit 1, 2 blocking` reading reproduces on
   `/Users/n8/git/ai-dlc` and nowhere else — a fact about the DISTRIBUTION, written into this file
   as a consumer expectation. An executor told to expect a FAIL and handed a PASS reads it as the
   wrong tree. Criterion 6 above now states exit 0 / `VERDICT: PASS` and scopes the FAIL to
   `/Users/n8/git/ai-dlc` by name.
4. **Criterion 7 was false, the pull was what made it false, and it is now DISCHARGED.** In the
   first rehearsal the suite exited 1 on two arms, both proven pull-introduced against the
   un-pulled control clone:
   - `audit-rule-files.sh --fail-on=deterministic` — **0 tier-1 findings before, 1 after**:
     `ORIGIN_TAG` at `.claude/skills/ai-dlc-update/SKILL.md:1479`, an origin tag `v0.350.0` in prose
     **this release itself delivers**.
   - fixture `story-fields-derive` — **PASS before, FAIL after**, the fixture byte-identical across
     the pull (control: `gate-validation.md` moved +58/−6 in the same diff). Its control arm fires:
     `steps/gate-validation.md:474` carried the writing form
     `` `scripts/ai-dlc/sprint-status.sh derive-stories` ``, which that arm exists to catch.
     147 ok / 1 FAIL over 148 fixtures.

   Both defects sat in the distribution's own `core/`, not in the merge, so the consumer could not
   fix them. Fixed at `a5b041f`. The second rehearsal's differential closes both: the suite is
   **148 ok / 0 FAIL, exit 0, 79s** on the pulled arm against **144 ok / 0 FAIL, exit 0, 78s** on
   the control, with both failure sets empty; `audit-rule-files.sh --fail-on=deterministic` is exit
   0 with `tier-1 findings: 0` on both arms over matching denominators; `story-fields-derive` is
   PASS on both. Each of the two carries a mutation probe — re-introduce the defect and the check
   goes red, restore it and the check goes green — so the greens are checks passing, not checks
   that stopped running. Criterion 7 above now states the passing result and the count movement.
5. **Criterion 1's command returns 2, not 4, exactly as printed.** `<new-sha>` is load-bearing:
   `grep -cE '0\.357\.0|<new-sha>'` matches only the two `version`/`skill_version` lines. Substitute
   the sha and it returns 4. The stamp does reach all four lines after a
   `--carried-machinery-slice` apply.
6. **Step 3's `SELF-UPDATE-SAFE-STOP` row names no ref, and cannot.** It reads *"no intermediate
   release in `959e778..1568427` self-updates cleanly"* — a one-hop pull has no intermediate release
   by construction. The DEFER itself is as described. `<base-sha>` is the stamp's own `commit:`
   field; the argument order is `<dist> <base> <theirs> <consumer>`, which is **not** `apply.sh`'s
   `<dist> <base> <consumer> <theirs>`.
7. **`ai-dlc-update` is not a shell command.** Steps 2 and 4 are fenced under a heading that says
   *"Use Bash, not Write/Edit"*; it is not on `PATH` and there is no `.claude/commands/` in either
   scope (control: `git` resolves on the same probe). It is a skill name, which is also why step 4
   has nowhere to put the `--carried-machinery-slice` step 3 says it needs — that flag is internal
   to the skill's own step 7.
8. **Step 9a's "retired id" does not exist.** All eleven retired verdicts carry **no**
   `gate_series_id`, and `validate-gate-adjudication.sh --series` says so per file — *"counted, not
   grouped (no gate_series_id, predates every live series)"*, summarising *"0 series carrying a
   gate_series_id across 11 .json file(s), all 11 of them legacy"*. There is nothing to name in the
   escalation entry.

Confirmed as written, with both arms where the runbook asked for them: **step 5 registers exactly
two hooks** — 14 → 16 distinct, the added pair precisely `ai-dlc-gate-remediation-guard.sh` and
`ai-dlc-rules-floor.sh`, none removed, `env.AI_DLC_MODEL_ROW` and every consumer-owned key intact;
**criterion 2 both ways** — exit 1 before the reconcile naming the unregistered hooks, exit 0 after
with `UNREGISTERED: none` and `DANGLING: none`, and its fix command carries no placeholders;
**criterion 5 exactly** — worklist of 10 including
`…/story-3-percentage-selector-and-create-naming.md:239 -> architecture.md:1483` (both consumer paths), against a
`--no-frozen` control of 48 over a 1956-file corpus versus 455. Two paths in the file are misstated:
three of the four dirty files are `_bmad-output/`-prefixed, and step 7's register is
`_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl`.

**What the rehearsal cannot prove, structurally.** `git clone --local` carries committed state only,
so nothing here certifies the four dirty hook-written files or any ledger receipt. It also drops
local git config and `.git/`-resident state: `core.hooksPath` is unset **on the live consumer too**
(checked read-only, at every scope, against a control that resolves), so `git push` runs none of
this and step 8 must be invoked as `bash .githooks/pre-push` by hand; and with no
`.git/ai-dlc-fixture-durations` and no `.ai-dlc-fixture-readsets.tsv` the copy ran all 148 fixtures
in glob order, so the 1m24s is an upper bound on a differently-ordered live run, not a prediction of
it. Step 2's dry-run report, step 7's ledger work and step 9's reset all need agent dispatches and
were not run — apply.sh's own worklist is 24 rows (14 `extension-reread`, 5 `extension-title-match`,
2 `override-readopt`, 2 `override-retire`, 1 `semantic-merge`) and contains **no** ledger row, so
step 7's ledger half is not derivable from it. Criterion 4 needs a live gate and is untested here.
The distribution commit also moved under the rehearsal — `1568427` → `3077489`, same version, same
subject.

**What the SECOND rehearsal did not run, stated so no one reads its greens as wider than they are.**
Steps 1, 2, 7 and 9 were not run, and neither was criterion 4 — it needs a live gate. Criterion 5's
fan-out worklist was not re-run either: the first rehearsal's worklist of 10, above, stands
unchallenged by this pass and equally unconfirmed by it. No ledger receipt was certified, for the
structural reason above — a `--local` clone carries committed state only.

## Abort

- **Step 4 apply goes wrong** — the step 1 commit is the restore point; the pull is separable from
  the pipeline state by construction.
- **Step 5 merge damages `settings.json`** — it preserves consumer-owned keys
  (`env.AI_DLC_MODEL_ROW`, permissions, mcpServers, statusLine); if any is lost, restore that file
  alone from the step 1 commit and ping the operator before re-running.
- **Step 9 reset loses a verdict file** — stop. The eleven retired verdicts are evidence; a reset
  that deletes is a defect in the reset, not a step to work around.

## Do not touch mid-sprint

- The eleven `_bmad-output/gate-adjudication/story-20260811T*.verdict.json` files. They are the
  retired series and the backtest corpus.
- `docs/escalations/pending.md`'s four s302 RESOLVED entries and their operator citations.
- The frozen review records the fan-out worklist deliberately excludes — `*-adversarial-p*.md`,
  `*-repair*.md`, `stories-party-mode/`, `docs/reviews/`. Their citations are accurate accounts of
  what an earlier pass read; repairing them falsifies the record.
