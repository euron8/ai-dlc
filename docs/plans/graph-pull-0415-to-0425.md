# Runbook — pull the graph consumer from 0.415.0 to 0.425.0

**You were started with one sentence: `READ and FOLLOW docs/plans/graph-pull-0415-to-0425.md`.**
This file is the whole of your entry point.

**No ref and no sha is written down in this file, deliberately.** The `ai-dlc-update` skill pulls
latest by default and resolves the distribution ref itself. Nothing here needs to name one, and a
name written down goes stale the moment anything lands — including a docs commit to this very
file.

**The pull itself is the `ai-dlc-update` skill's job and this file does not re-describe it.** The
skill resolves the ref, gates its own self-update, carries the machinery slice, emits the
worklist, and tells you when a settings reconcile is needed. Follow what it prints. Every step a
runbook writes down about the pull is a restatement of something the skill already owns, and that
is how those steps go stale.

What this file is for is the part no skill does: **saying what this particular range carries, what
it was rehearsed to do, and which two push-candidates it discharges.**

## What this range carries, and why it is being pulled now

Ten releases, `0.416.0` through `0.425.0`, all internal hardening of the distribution's own
validators and backlog machinery. The two that matter to this consumer:

- **`0.422.0`** — every rendering under `core/` that printed a git rev-path unquoted now quotes it.
  Discharges `PC-S333-SKILL-RENDERS-THE-THEIRS-REF-UNQUOTED-AND-ZSH-EATS-IT`.
- **`0.423.0`** — `reconcile/preclassify.sh` now consults the file MODE before bucketing a path as
  already-satisfied. Discharges
  `PC-S314-PRECLASSIFY-BUCKETS-A-MODE-ONLY-CHANGE-AS-UPSTREAM-ONLY-SO-THE-SELF-UPDATE-CANNOT-TERMINATE`.

**Those two candidates are the REASON for this pull.** They are discharged in the distribution and
cannot be closed in this consumer's ledger until the consumer is running the code that fixes them.

**`0.423.0` FIXES THE PROGRAM THAT RUNS THIS PULL, so it cannot protect this pull.** The consumer's
installed `preclassify.sh` is the unfixed one and is what classifies the range carrying its own
repair. Its defect is that a MODE-ONLY upstream change buckets `UPSTREAM-ONLY` forever, which makes
step 2's termination subtraction unable to drop the path.

The mechanism, in the distribution's own tree so it can be read before the pull:
`core/skills/ai-dlc-update/reconcile/preclassify.sh:120` is `blob_hash()`, a blob sha that carries
no mode; `core/skills/ai-dlc-update/reconcile/preclassify.sh:154` is the `mode_at_theirs()` helper
`0.423.0` adds; and `core/skills/ai-dlc-update/reconcile/apply.sh:196` is
`sync_mode_from_theirs()`, the only thing that ever sets the bit — which is why a path dropped as
already-satisfied never gets one.

**Measured on a `file://` clone rather than reasoned about: the range contains ZERO mode-only
changes to `core/`.** Across 38 changed core paths there are three mode changes and all three are
`000000 -> 100755` file ADDS, which take the `A` branch, not the `M` branch the defect lives in.
So the hazard does not bite here. **The fix takes effect on the NEXT pull, not this one** — do not
report this pull as having exercised it.

## Rehearsed on a clone — what to expect

Driven through the distribution's shipping `preclassify.sh` against a `file://` clone of this
consumer at its current stamp. **These are the rehearsal's numbers, not a reading of the code**,
and the live tree was untouched (dirty count 6 before and after):

```
38 rows    29 UPSTREAM-ONLY      pure apply
            8 DIST-ONLY-SKIP     not consumer files
            1 UPSTREAM-ONLY-ADD  net-new
            0 *->CLASSIFY        nothing needs a human decision
templates   4 TEMPLATE-UNCHANGED-NOOP  (CLAUDE.md, coding-conventions.md, QUICKSTART.md, settings.json)
```

**So this is expected to be a mechanical pull with no adjudication and no settings reconcile.**
That is an expectation, not a guarantee: the distribution moves, and the skill's own report is the
authority. **If the report shows ANY `->CLASSIFY` row or asks for a settings reconcile, stop and
ping the operator** — the rehearsal said there would be none, and a disagreement is information.

## Start here

**Execute this from a session whose PROJECT ROOT is `/Users/n8/git/graph`.** Skill scope follows
the session root, not a Bash `cd`, and the skill exists only at
`/Users/n8/git/graph/.claude/skills/ai-dlc-update/`. A session rooted in the distribution cannot
invoke it at all. If yours is, stop and ping the operator for a restart.

Two repos, and the boundary is absolute.

- **Distribution — `/Users/n8/git/ai-dlc`. Read it, never write it.** The skill reads it; you do
  not need to name a ref into it.
- **Consumer — `/Users/n8/git/graph`, the tree you WRITE.** On `main`, in sync with its upstream,
  stamp reads `version: 0.415.0`.

**The working tree is NOT clean and that is expected.** Everything modified is hook-written
`_bmad-output/` pipeline state. **Their number is not fixed and this file does not enumerate them**
— the set grows while the pipeline runs. Judge by the path: anything modified under
`_bmad-output/` is pipeline state. **If something OUTSIDE `_bmad-output/` is dirty, stop and ping
the operator.**

**Do not commit, revert, stash or clean any of them.** Committing makes the branch ahead of its
upstream, and the skill's git preflight then auto-pushes in-flight state on a bare dry run.

**Ping the operator** on any question, on any decision this file does not settle, and on
completion — including an early stop. A session that stops silently is indistinguishable from one
still working, and every stall in this repo's history ended with the operator asking rather than
the session reporting.

## Next actions

1. **Confirm the branch is in sync**, which is the one precondition the skill's preflight depends
   on:

   ```
   git rev-list --left-right --count @{u}...HEAD
   ```

   Expect two zeros, behind and ahead. **Any other reading: STOP**, do not invoke the skill, and
   ping the operator — a branch that is ahead gets auto-pushed, and what is on it is not this
   runbook's to publish.

   **Then record the starting state. Later steps refer to it, and no sha is written down here
   because the consumer is live and its `HEAD` moves.**

   ```
   git rev-parse HEAD
   cat .claude/.ai-dlc-version
   ```

   Call the commit **`START`** and the stamp's `commit:` field **`BASE`**. `BASE` is what step 4
   compares against and it is NOT re-derivable after the apply — keep both where you can paste
   them.

2. **Run the pull.** Invoke the `ai-dlc-update` skill — bare for the dry run, then with `apply`
   after reading the report. These are skill invocations, not shell commands; `ai-dlc-update` is
   not on `PATH`.

   Do what the report and the apply manifest tell you. Ping the operator for anything the report
   does not settle, and specifically for any `->CLASSIFY` row or settings reconcile, which the
   rehearsal says should not appear.

   **The apply does not land on `main`.** The skill cuts a reconcile branch, commits its writes
   there, pushes it and opens a PR, and merges only on explicit operator approval. Ping the
   operator when the PR is open.

3. **Run the consumer's pre-push suite.** `core.hooksPath` is unset here, so `git push` runs none
   of it:

   ```
   bash .githooks/pre-push
   ```

4. **Close the two push-candidates this pull discharges — THIS IS WHY THE PULL EXISTS.** After the
   reconcile PR is merged, run the consumer's own closer. **Never run it with the process cwd at
   the distribution root**: a distribution-root run has turned a live `STILL-LIVE` into a
   `CLOSE-CANDIDATE`, and a false close retires an entry that is still live.

   ```
   cd /Users/n8/git/graph && bash .claude/skills/ai-dlc-update/reconcile/ledger-reverify.sh \
     /Users/n8/git/ai-dlc <BASE> /Users/n8/git/graph <the new stamp commit>
   ```

   **Expect `PC-S333` and `PC-S314` to resolve as `NAMED-UPSTREAM`.** Both ids appear verbatim in
   their release COMMIT MESSAGES, which is what `named_absorbed()` greps — not the CHANGELOG. The
   function is at `core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:447` in the distribution
   if you need to read what it actually joins on; it takes `tail -1`, the OLDEST matching commit,
   so it reports the release that FIRST named an id.

   **A `CLOSE-CANDIDATE` row is a hypothesis, not a verdict.** For each one, read the entry, run
   its own receipt, and ask what ELSE satisfies it before retiring anything.

   **Report which candidates closed and which did not, BY ID.** That number is the only measure of
   this program, and it is the one thing this runbook cannot derive in advance.

5. **Ping the operator with the outcome**, including the ledger result from step 4 and anything the
   rehearsal got wrong. A disagreement between the rehearsal and the real run is worth more than a
   clean report — say so explicitly rather than smoothing it over.

## Abort

`START` is the only restore point. If the apply goes wrong before the PR is merged, the reconcile
branch is separate from `main` and `main` is still at `START` — ping the operator rather than
attempting a repair. **Do not `reset --hard`, `checkout --`, `restore`, `clean` or `stash`
anything in this consumer.**

## Done when

1. The stamp at `.claude/.ai-dlc-version` reads `version: 0.425.0`, where it read `0.415.0`.
2. `bash .githooks/pre-push` is green on the consumer after the apply.
3. The reconcile PR is merged, or the operator has been pinged that it is open and awaiting them.
4. `ledger-reverify` has been run from the consumer root and its verdict for `PC-S333` and
   `PC-S314` reported by id.
5. The operator has been pinged with the outcome.

**Criterion 4 is reachable and 1 is the one to check first** — if the stamp did not move, nothing
else in this list means anything.

## Discharge

*Not yet executed. When it runs, record here what actually happened — the stamp before and after,
the bucket counts the real run produced against the rehearsal's, the ledger verdicts by id, and
anything this file got wrong — then retitle the file `DISCHARGED — DO NOT EXECUTE` and say so in
the first paragraph. A spent runbook that still reads as instructions is this directory's
recurring hazard.*
