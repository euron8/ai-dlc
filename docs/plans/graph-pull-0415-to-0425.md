# DISCHARGED — DO NOT EXECUTE — pull the graph consumer from 0.415.0 to 0.425.0

**This runbook is SPENT.** It was executed on 2026-08-27 and the pull it describes has landed: the
consumer is at `0.425.0` and both push-candidates it targeted are closed in that consumer's own
ledger. **Nothing below this line is an instruction.** It is the record of a completed run, kept
because the `## Discharge` section at the foot names four things this file got wrong, and those are
worth more than the file was.

**No ref and no sha was written down in this file, deliberately.** The `ai-dlc-update` skill pulls
latest by default and resolves the distribution ref itself. Nothing here needed to name one, and a
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

**EXECUTED 2026-08-27. The pull landed and both push-candidates are CLOSED in the consumer's own
ledger**, which is the terminal state this runbook existed to reach.

Attribution, because the two halves were measured by different sessions: consumer-side figures
(PR numbers, bucket splits, gate results, register counts) are the executing session's. Everything
attributed to the distribution below was re-derived independently in `/Users/n8/git/ai-dlc`, each
with a control in the same invocation.

### Final state

```
version:       0.415.0 -> 0.425.0
commit:        f86e085c -> e7898c7d
skill_version: 0.415.0 -> 0.425.0
skill_commit:  f86e085c -> e7898c7d
```

Consumer `main` at `c55f66edc`, in sync with upstream, nothing dirty outside `_bmad-output/`.
Three PRs, each merged on explicit operator approval: **#965** self-update 0.415.0→0.421.0,
**#966** reconcile 0.415.0→0.421.0, **#967** reconcile 0.421.0→0.425.0.

Ledger, re-derived here: **`PC-S333` and `PC-S314` both live=0, archive=1**. Both annotated
`**ADOPTED UPSTREAM (v0.425.0, verified 2026-08-27)**`, the form `ledger-rotate.sh:212` keys on.

### THE PULL WAS SPLIT, AND THIS FILE DID NOT ANTICIPATE IT

The single largest thing the runbook got wrong. Step 2 returned `SELF-UPDATE-DEFER` with a
`SELF-UPDATE-SAFE-STOP` naming `045ef6d9` (0.421.0), so the pull ran as two hops rather than one:
`ai-dlc-update 045ef6d9 apply`, then `ai-dlc-update apply`.

**The DEFER prose and the SAFE-STOP row are not in conflict, and reading them as conflicting is the
trap.** `SKILL.md:317`'s "do NOT cut the branch" governs the pull whose gate deferred; the SAFE-STOP
row decides *which range to pull*. Under a split, hop 1 has its own step 2 — measured
`SELF-UPDATE-OK` — so it cuts its branch legitimately and hop 2 re-invokes on the landed engine.
"Fold the slice into the gated apply" is the branch taken when **no** safe stop exists,
`self-update-gate.sh:178`. A third branch at `:173` says "SPLIT BUYS NOTHING HERE" when the
consumer's own `skill_commit` is already at or past the named ref; that is what makes the row a
measurement rather than a suggestion, and it did not fire here.

Hop 2 then returned `SELF-UPDATE-SAFE-STOP -` — no intermediate release self-updates cleanly — so
its slice was folded in with `apply.sh --carried-machinery-slice`, which advanced all four stamp
fields.

### Four more things this file got wrong

1. **The rehearsal's 38 rows do not decompose across a split.** Re-derived: hop 1 **26** core rows,
   hop 2 **14**, full range **38**. 26 + 14 = 40 because two paths change in both segments and are
   classified twice. The real run reproduced 26 then 14 exactly. A per-hop mismatch against 38 is
   not the disagreement this file said to stop on.
2. **`NAMED-UPSTREAM` was predicted; both candidates returned `CLOSE-CANDIDATE`** — a stronger
   result, because the receipts re-verified rather than an id merely being named. Step 4 should tell
   the next operator to expect either.
3. **Step 4's description of `named_absorbed()` was false for the shipped code.** It does not take
   `tail -1` and does not elect one commit; it reports the whole match set
   (`<newest-sha> <oldest-sha> <n> <how>`), changed upstream as
   `PC-S334-NAMED-ABSORBED-JOINS-ON-THE-OLDEST-MESSAGE-MENTION`. Verified against the consumer's
   installed copy, byte-identical to the distribution's. **A multi-commit row is correct output.**
   Corollary: the join reads the full ancestry of `THEIRS`, not `BASE..THEIRS`, so a split cannot
   break it.
4. **The stop list was incomplete.** It named only `->CLASSIFY` rows and a settings reconcile. The
   run hit a `SELF-UPDATE-DEFER` and six `HARD-LAYER-ADJUDICATION-MISSING` blockers, neither of
   which it named, so both had to be escalated as "a decision this file does not settle". A future
   runbook states the stop condition as a class, not as an enumeration.

### Verified as predicted

Zero mode-only `core/` changes, so the `0.423.0` bootstrapping hazard could not bite — re-derived
per hop as well as over the full range, all three zero, every mode change being a
`000000 -> 1007xx` ADD taking the `A` branch. Both hops mechanical at the bucket level with
**0 `->CLASSIFY`** in each. No settings reconcile in either hop. All four templates
`TEMPLATE-UNCHANGED-NOOP`.

**`PC-S314`'s fix was NOT exercised by this pull** and its annotation says so: `preclassify`
classified the range on the pre-fix engine by construction. It takes effect on the next pull.

### Six blockers from a three-line delta

The entire rulebook delta in hop 2 is **2 files, 3 insertions, 3 deletions** — re-derived here,
control being `preclassify.sh` at 52 insertions in the same range — and all three lines are the
same quoting fix, `PC-S333` itself. Semantics unchanged.

That is what licensed a text search as sufficient evidence for all six adjudications: with
semantics unchanged, an extension can only go stale by *textually restating* the broken form, so
there is no behavioural channel to miss. **That reasoning does not generalise to anchor drift** and
should be restated, not assumed, next time.

Five were dispositioned `still-additive`; one, `overrides/steps__retro__domain-sections.md`
(`OVERRIDE-SUPERSEDED`, LC-O15), took `still-additive` **plus a declared debt**. Executing its
narrowing would strand ~114 consumer-only lines as an override body with no anchor claiming it —
a direction `E7`, `readopt-override.sh:247`, `LC-O9` and `LC-O14` all leave uncovered, so the
orphan would be reported by nothing. Debts declared: `OWED-S338-RETRO-4A-ANCHOR-NARROW`,
`OWED-S338-EXTENDS-PROCESS-IMPROVEMENTS`, `OWED-S338-EXTENDS-SPRINT-SHIP`. Layer debt OPEN 11 → 14;
register 261 → 269.

### Operational notes for the next runbook

- **The consumer's `bash .githooks/pre-push` now exceeds a 10-minute foreground budget.** Background
  it. Result here: rc 0, 11 PASS, 0 FAIL.
- **`apply.sh` updates itself mid-run** and prints `RESOLVED driver-self-update`. Re-running on the
  new driver was idempotent; a third run emitted 0 WORKLIST / 0 DECISION.
- **`gh` was mis-authenticated for the consumer** — the active account could not see a private repo,
  so every `gh` call 404'd and the PR could not be opened. A `GH_CONFIG_DIR` override fixes an
  agent's own calls but **not** `.claude/hooks/guarded-merge.sh`, which shells out to `gh pr view`
  in its own subprocess. Resolved by the operator, and it is an operator decision: it mutates
  global `gh` state and races their other sessions.
- **`zsh` ate a quoted git rev-path** — `"$THEIRS:core/…"` expanded via the `:c` history modifier
  and left 20 empty files before failing, because the redirect had already opened. `"${THEIRS}:…"`
  is correct. This is `PC-S333` reproducing live in the session that closed it.
- **Four `retired-*` detectors given unsplit arguments** exited `parameter null or not set` while
  printing zero rows — byte-identical to a clean corpus.

### Left open, then handled as separate work

Nine ledger entries were CLOSED at re-verification but not archivable: `ledger-reverify` skips them
and `ledger-rotate` refuses them, so they appeared in exactly one block of output and had never been
filed. **Deliberately not folded into this pull**, and resolved afterwards as its own change.

The nine were two populations, which is why "fix all nine" was the wrong frame. **Five** were list
items inside one human record section, counted only because the entry-boundary rule opens an entry
on any line-leading `- **…**`; they were never push-candidates. **Four** are real entries that fall
inside the carve-out `ledger-rotate.sh:405-406` names in as many words — *"If the close is genuine
but has no version (absorbed before base, withdrawn, a retained copy), that is a legitimate state
and the row is the record of it."*

Resolution: the five de-listed, the four untouched. That is the remedy the tool itself prescribes
at `ledger-rotate.sh:244` — *"If the reported line is an ANNOTATION, re-indent it so it does not
start a line, or drop its bold."* **Two of the four are WITHDRAWN, so annotating them
`ADOPTED UPSTREAM` would not be imprecise but false.** Three version-bearing record markers were
deliberately NOT normalised into archivable form: they are not push-candidates, and rotating them
into the candidate archive would inflate the only durable progress signal this program has by three.

Result **9 → 4 unarchivable**, with `ledger-reverify`'s row set identical at 92 = 92 before and
after, and `0 closed entries — nothing to rotate` afterwards, which is the correct outcome rather
than a null one.

Artifacts: `reconcile-log-20260827T152847Z.md` (hop 1), `reconcile-log-20260827T155404Z.md`
(hop 2), `self-update-fixtures-20260827T150503Z.md` (37 green / 0 red / 0 missing of 37 named).
