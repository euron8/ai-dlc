# DISCHARGED — DO NOT EXECUTE — pull the graph consumer from 0.779.0 to 0.780.0

**THIS RUNBOOK IS SPENT. IT RAN, IT MERGED, AND IT IS A RECORD RATHER THAN AN INSTRUCTION.**
Do not follow the numbered actions below; they describe work that is finished. Read `## Discharge`
for what happened.

## RESUME HERE

**STATE AT WRITING (history): WRITTEN AND REHEARSED, NOT STARTED.** The rehearsal ran on `file://` clones of the
consumer, and every figure in `## Rehearsal` came from it. A contract adversary then simulated
the self-update, the re-invocation and the step-8 annotate-and-rotate on a further clone; its
findings are folded in.

**THIS FILE BEING GREEN IS NOT AUTHORIZATION.** `.claude/rules/operator-rulings.md` is
unconditional: a consumer pull is operator-initiated, readiness is not authorization, and a
`PENDING` count is not a decision about WHEN. If you are reading this without the operator having
said "run the pull", stop and ask.

**A graph session reads this file at its ABSOLUTE path,
`/Users/n8/git/ai-dlc/docs/plans/graph-pull-0779-to-0780.md`.** From a session rooted in the
consumer, the relative path in the one-liner resolves against the consumer and finds nothing.

Read `## Start here` FIRST, then `### Numbered actions`. `## Rehearsal` is what to expect;
`## Hazards` is what will bite you.

## Start here

**YOUR SESSION'S PROJECT ROOT MUST BE `/Users/n8/git/graph`.** Skill scope follows the session
root, not a Bash `cd`, and a session rooted in the distribution cannot invoke the `ai-dlc-update`
skill at all. If your root is the distribution, stop and restart there.

- **`/Users/n8/git/graph`**: the consumer. WRITE, and only through the skill. The one hand edit
  this pull needs, action 6's annotation, is made inside the skill's step 8 on its reconcile
  branch, never in the live carry-over tree.
- **`/Users/n8/git/ai-dlc`**: the distribution. READ ONLY from this session: read it, never write
  it.

**THE CONSUMER'S TREE IS DIRTY AND THAT IS EXPECTED.** It carries live `_bmad-output/` pipeline
state (and, at rehearsal, `docs/escalations/pending.md`), and the set grows while the pipeline
runs, so it is deliberately not enumerated here. **Do not commit, revert, stash or clean it.**
Committing makes the branch ahead of its remote, and the preflight then auto-pushes in-flight
state.

**THE CONSUMER IS ON A CARRY-OVER BRANCH, NOT `main`, AND IT MOVES WHILE YOU WORK.** Re-derive the
branch and the head before you start; do not switch either. A moved consumer head during your run
is the normal case, not an alarm.

**This file carries no ref and no sha.** The skill pulls latest and resolves the ref itself.

**This file does not re-describe the pull.** The `ai-dlc-update` skill owns resolving the ref,
gating its own self-update, carrying the machinery slice and emitting the worklist. Everything here
is what is SPECIAL about this range.

**What the range is for.** One release. It ships a fix to the updater's own `ledger-reverify.sh`: a
candidate id containing `.` or `_` now reaches the join that reports which release named it. The
one live candidate this unblocks is `PC-S317-3.2-DERIVATION-HOOK-CWD`, whose fix shipped in
**v0.773.0** and which the installed engine has never reported, because its id contains a `.`.

### Numbered actions

1. **Confirm the operator has authorized THIS pull.** Not a `PENDING` count, not this file being
   green. If that has not happened, stop here and ping.

2. **Record the consumer's pre-run state**: branch, `git status --porcelain | wc -l`, the fields of
   `.claude/.ai-dlc-version`, and `md5 -q _bmad-output/ai-dlc-update/push-candidate-ledger.md`.

3. **Run the `ai-dlc-update` skill, first without `apply`.** Let it resolve the ref. Do not
   hand-drive `preclassify.sh`, `apply.sh` or the self-update scripts. A run without `apply` ends at
   its report (`core/skills/ai-dlc-update/SKILL.md:1586`) and writes nothing to the tree.

4. **EXPECT `SELF-UPDATE-OK`, then a self-update, then an automatic re-invocation.** The range
   changes the updater's `SKILL.md` and `reconcile/ledger-reverify.sh` and no `core/scripts/` path,
   so the gate permits the self-update. After it lands, the skill stops that invocation and
   re-invokes itself (`core/skills/ai-dlc-update/SKILL.md:720`), and the fresh invocation
   "loads the updated logic and runs the reconcile on it" (`core/skills/ai-dlc-update/SKILL.md:730`).
   **The report you compare in action 5 is the RE-INVOKED run's**, written by the new engine over a
   tree the self-update already wrote.

   If the gate instead returns `SELF-UPDATE-DEFER` (for example on a red self-update fixture run),
   the slice folds into the gated apply and the OLD engine writes the report, so the
   `NAMED-UPSTREAM` row is absent from it. It then appears inside this same pull at step 8, whose
   mandatory re-run of the re-verifier (`core/skills/ai-dlc-update/SKILL.md:2551`) runs the engine
   step 7 just wrote. Either outcome is correct; report which one ran.

   **If the re-invoked run stops with the branch BEHIND or DIVERGED from its upstream**
   (`core/skills/ai-dlc-update/SKILL.md:207`), the consumer's own pipeline pushed between the
   self-update merge and the re-invocation. Fast-forward with `git pull --ff-only` and re-invoke;
   on DIVERGED, stop and ping.

5. **Compare the report against `## Rehearsal` before applying.** Compare the RENDERED report, not
   raw engine output: `emit-report.sh` drops `STILL-LIVE` rows. On the `SELF-UPDATE-OK` path
   expect the per-file buckets `ALREADY-AT-THEIRS` ×4 and `DIST-ONLY-SKIP` ×1, no semantic
   worklist, a stamp-only "consumer core already at …; stamp behind" line, and exactly two
   ledger rows: `NAMED-UPSTREAM PC-S317-3.2-DERIVATION-HOOK-CWD` and `RECEIPTS-UNDECIDED`. On the
   DEFER path expect the pre-write buckets in `## Rehearsal` and the `RECEIPTS-UNDECIDED` row
   alone. **If the report matches neither, STOP and ping the operator.**

6. **Re-invoke with `apply`, and close `PC-S317-3.2-DERIVATION-HOOK-CWD` in step 8, on the
   reconcile branch.** Every write happens inside the skill's isolated branch; do not touch the
   live carry-over ledger. In step 8:

   - **The governing disposition is the `NAMED-UPSTREAM` bullet**
     (`core/skills/ai-dlc-update/SKILL.md:2588`), which allows a hand annotation on absorption. The
     "close ONLY `CLOSE-CANDIDATE` rows" sentence above it (`core/skills/ai-dlc-update/SKILL.md:2575`)
     does not forbid this; the named commit absorbed the entry.
   - **Annotate the entry with exactly this line, under its heading:**

     ```
     **ADOPTED UPSTREAM (v0.773.0, verified <today's date>)**
     ```

     The parser keys on that bold span (`core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:2419`),
     and `ledger-rotate.sh` names the same form (`core/skills/ai-dlc-update/reconcile/ledger-rotate.sh:544`).
     No backtick may sit between the opening `**` and `ADOPTED UPSTREAM`; a backticked form does not
     close.
   - **The version is v0.773.0, NOT v0.780.0, whatever a row's detail offers.** Exactly one
     distribution commit names the id, the 0.773.0 release commit, and it both carries the fix and
     bumps `VERSION`; 0.780.0 only made the engine able to see that. The OLD engine's
     `CLOSE-CANDIDATE` detail offers `v0.780.0` if the receipt is repointed, and that is wrong.
   - **The annotation is what closes it; repointing the receipt is optional.** The entry's
     `verify:` line reads the distribution at a pinned sha through a literal path, so it reads
     `STILL-LIVE` at every ref. Repointing it at `"$DIST"` and `"${THEIRS}"` makes it honest
     (`CLOSE-CANDIDATE`) but archives nothing without the annotation. It is the only live receipt
     in the ledger with that pinned shape.
   - **Run `ledger-rotate.sh` the way step 8 prescribes, and expect exactly one entry to move.**
   - **Step 8 compares the re-verifier before and after the rotation `--apply`. Take "before"
     AFTER the annotation.** Taken from the pre-annotation report, two rows for this id
     (`NAMED-UPSTREAM`, `STILL-LIVE`) vanish and read as a mismatch; taken after it, the diff is
     empty.
   - **The PR merge needs the operator's explicit approval**
     (`core/skills/ai-dlc-update/SKILL.md:2664`), separate from the `apply` argument.

7. **A `CLOSE-CANDIDATE` row is a hypothesis, not a verdict.** For any other id, run that entry's
   receipt directly, read the raw exit code, and ask what ELSE satisfies it before rotating
   anything. The rehearsal produced none.

8. **Report to the operator**: the gate verdict and which engine wrote the report (action 4), the
   report as it actually came out, whether the `NAMED-UPSTREAM` row appeared and at which step, the
   ids that closed, and any disagreement with `## Rehearsal`.

9. **AFTER THE PULL MERGES, BEFORE YOU STOP: re-derive this file's own `## RESUME HERE` block
   and prove it is still resumable.** The merge is the moment a handoff goes stale. Re-run the
   commands behind `## Rehearsal` against the real post-pull tree and DIFF every figure against
   what this file claims; fix the COMMAND where they disagree, never only the prose. Then re-derive
   the delivery gap and the `PENDING` set in `docs/plans/graph-ledger-full-drain.md` and report both.
   **This action and every one after it write to the DISTRIBUTION**, so a graph session stops at
   action 8 and the operator hands actions 9-12 to a distribution-side session.

10. **Fill in `## Discharge` and retitle this file `DISCHARGED — DO NOT EXECUTE`.** A spent
    runbook still reading as instructions is this directory's recurring hazard.

11. **THE FRESH-RESUME CHECK, run by the distribution-side session after action 10's docs commit
    has merged.** Read this file from a fresh checkout of `origin/main`, as a stranger resuming it,
    and confirm it reads `DISCHARGED — DO NOT EXECUTE` there and that `docs/plans/graph-ledger-full-drain.md`
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
   `version: 0.780.0`, checked by reading the file.
2. **Graph session, before action 6's annotation**: the re-invoked run's report carries
   `NAMED-UPSTREAM PC-S317-3.2-DERIVATION-HOOK-CWD`, or action 4 recorded `SELF-UPDATE-DEFER` and
   step 8's re-verifier carries it. After the annotation, both engines emit no row for that id, so
   this is not checkable later.
3. **Graph session, after action 6's rotation**: in one invocation, the id counts 1 in
   `push-candidate-ledger.archive.md` and 0 in `push-candidate-ledger.md`, while `grep -c '^## '`
   over `push-candidate-ledger.md` reads non-zero, which proves the ledger read is live. Do not count
   `^## PC-` for that: this candidate is the ledger's only `## PC-` heading, so a correct close
   reads 0 there.
4. **Distribution-side session, at action 10**: `## Discharge` is filled in and the file is
   retitled.

Criteria 2 and 3 were checked as reachable on a rehearsal clone before this file was written.

## Hazards

- **A false CLOSE is the worst output in this system.** Always run `ledger-reverify` from the
  consumer root, with absolute paths. Both ref arguments are DISTRIBUTION refs, and a consumer sha
  in either slot exits 0 with a plausible, wrong row set.
- **`ledger-rotate.sh` exits 0 on a ledger path that does not exist** and reports "nothing to
  rotate". A zero from it on a mistyped path reads exactly like a clean ledger.
- **The Bash tool's shell is zsh.** No `PIPESTATUS`, so `cmd | tail` reports `tail`'s status.
  Never read an exit code through a pipe.
- **The citations in this file resolve in the DISTRIBUTION.** Line 2419 of the consumer's
  installed `ledger-reverify.sh` is a different line; read the distribution path given.
- **The rehearsal did not drive the self-update fixture run or the self-update push.** The first
  runs fixtures; the second writes to the consumer's origin. The gate verdict came from the
  installed gate script, and the re-invoked run was simulated by writing the slice and stamp on a
  clone and re-running the installed `preclassify.sh` and `emit-report.sh`. The fixture run's wall
  clock is unknown.

## Rehearsal

Run on `file://` clones of the consumer at its carry-over head, against the distribution's
current `main`. These are expectations, not guarantees. If the real run disagrees, STOP and ping.

| step | outcome | wall |
|---|---|---|
| releases behind | 1 | |
| bootstrapping files in range | `SKILL.md`, `reconcile/ledger-reverify.sh`; `preclassify.sh` and `apply.sh` unchanged; 0 `core/scripts/` files | |
| mode-only changes in `core/` | 0 of 5 changed files | |
| `self-update-gate.sh` | `SELF-UPDATE-OK` (no `core/scripts/` path in the slice) | 3s |
| `preclassify.sh`, before the self-update writes (the DEFER path's report) | 5 rows: 4 `UPSTREAM-ONLY`, 1 `DIST-ONLY-SKIP`, 0 `->CLASSIFY` | 1s |
| `preclassify.sh` and `emit-report.sh`, after the self-update writes (the OK path's report) | 4 `ALREADY-AT-THEIRS`, 1 `DIST-ONLY-SKIP`; no semantic worklist | |
| reverify raw, installed engine | 9 rows: 8 `STILL-LIVE`, 1 `RECEIPTS-UNDECIDED`; rendered: 1 row | 2s |
| reverify raw, 0.780.0 engine | the same 9, plus `NAMED-UPSTREAM PC-S317-3.2-DERIVATION-HOOK-CWD`; rendered: 2 rows | 3s |

Controls in the same runs: the two engine files differ (`cmp -s` 1), each is byte-identical to its
distribution release, `lib.sh` is identical on both sides, and an impossible id reads 0 on both.
The consumer's own 0.779.0 pull report carries the same `ALREADY-AT-THEIRS` and stamp-behind shape.

**Closing the candidate, four cells, 0.780.0 engine:**

| receipt | annotation | reverify rows for the id | `ledger-rotate.sh` |
|---|---|---|---|
| as is | none | `NAMED-UPSTREAM`, `STILL-LIVE` | nothing to rotate |
| repointed | none | `CLOSE-CANDIDATE`, `NAMED-UPSTREAM` | nothing to rotate |
| as is | v0.773.0 | none | 1 entry would move |
| repointed | v0.773.0 | none | 1 entry would move |

The repointed receipt exits 1 at the distribution's `main` and at the installed release, and 0 at
the pre-fix pinned sha, so it does discriminate. After the rotation, the id read 0 in the ledger and
1 in the archive, against 18 `^## ` headings in the ledger (and 0 `^## PC-` headings).

## Discharge

**Merged 2026-10-13 as the consumer's PRs #1217 (self-update, `776433bee`) and #1218 (reconcile,
`cf886c04b`)**, squash-merged onto its carry-over branch `ai-dlc/carry-over/s318-artifact-consolidation`.
Executed by a graph session under operator authorization; this section was written on the
distribution side, which only read graph.

**The run agreed with `## Rehearsal` on every predicted row, and there were no disagreements.** Taken
from the consumer's reconcile log `reconcile-log-20261013T132309Z.md` and re-derived here:

- Gate `SELF-UPDATE-OK`, self-update fixtures 1 green, and the re-invoked 0.780.0 engine wrote the
  report (the OK path of action 4).
- Report: `ALREADY-AT-THEIRS` ×4 and `DIST-ONLY-SKIP` ×1, no semantic worklist, 0 HARD blockers.
  Ledger rows `NAMED-UPSTREAM PC-S317-3.2-DERIVATION-HOOK-CWD` and `RECEIPTS-UNDECIDED` came out of the
  dry run, so done-when 2 was met before the annotation.
- `PC-S317-3.2-DERIVATION-HOOK-CWD` was annotated `**ADOPTED UPSTREAM (v0.773.0, verified 2026-10-13)**`
  and rotated as one entry. The reverify row set was identical before and after `--apply`.

**Re-derived from the distribution side after the merge, controls in the same invocation:**

- `.claude/.ai-dlc-version` reads `version: 0.780.0` in the working tree and at the consumer's HEAD
  (done-when 1). The installed `ledger-reverify.sh` is byte-identical to 0.780.0's (`cmp` 0) and
  differs from 0.779.0's (`cmp` 1).
- The id counts 1 in `push-candidate-ledger.archive.md` and 0 in `push-candidate-ledger.md`, with 18
  `^## ` headings in the ledger, both in the working tree and at HEAD. An impossible id reads 0 in
  the archive (done-when 3).
- The drain plan's derive block, run in a fresh worktree at `origin/main` `4e9e8329`, reads graph's
  live candidate set as **0** across 9 qualifying refs. `arch` is 357, and main's live set of 3 lies
  wholly inside it (floor 0). The DISCHARGED set is 0, and the impossible-id gap control prints
  `UNNAMED`.

One thing the executing session flagged: its own `>`+`mv` write of the self-update slice dropped
exec bits, which it fixed with `chmod +x` before the fixture run. That was its write method, not
the distribution's tooling, and nothing was filed.
