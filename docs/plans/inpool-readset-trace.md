# In-pool read-set trace — trace the run that gives the push its verdict

## RESUME HERE

**You were started with one sentence: `READ and FOLLOW docs/plans/inpool-readset-trace.md`. This section
is the ONLY CURRENT STATUS RECORD in this file.** It lives on branch `b218-inpool-trace`, not on `main`;
read it from a clone of that branch.

**Why.** Operator goal (relayed by ai-dlc-77, the hermetic-pole lead): every push must be short. A push runs
every undeclared fixture that is unmapped or stale, and after a green suite `readset_live_trace` re-runs
those fixtures a SECOND time under `derive-fixture-readsets.sh --tracer sandbox --local-map`. This plan
traces the pool's own run instead, so the read set comes from the run that produced the verdict and the
second run disappears for every fixture traced this way.

**Rulings already made by ai-dlc-77 (do not re-litigate).** One release, canary intact. No fail-open path:
a lossy window (drop notice, LOSS CANARY, unread control, dirty delta, TRIP, driver missing) DISCARDS and
never maps a smaller set. Each traced fixture runs in its own APFS clone of the tracked +
untracked-not-ignored list plus `.git` (never the whole directory). The worker removes its clone AFTER
recording, off the critical path. One serial merge writes the local map under the existing lock. A TRIP
re-runs the fixture untraced and takes that verdict. A linked worktree skips in-pool tracing with one line
naming why and behaves as today. Declared fixtures (`inputs.decl`) are never traced in-pool.

**Where the code is, at `ca9c83b7`:** the modes are parsed at `core/scripts/derive-fixture-readsets.sh:199`
and `:207`, the merge exits at `core/scripts/derive-fixture-readsets.sh:922`, the clone is
`core/scripts/derive-fixture-readsets.sh:568`, and the in-pool copy choice is at
`core/scripts/derive-fixture-readsets.sh:1099`. The hook functions are `.githooks/pre-push:1016` (prep) and
`.githooks/pre-push:1042` (merge), called after the pool at `.githooks/pre-push:1888`.

**Squashed as 0.766.0, not yet gated.** One commit on main `ec9d11c0` (0.764.0), durable copy on GitHub as
`release-0.766.0-durable`; its `core/` and `.githooks/` are byte-identical to the verified `de6b865c`, and
`validate-release-version.sh` is rc 0. Queue: ai-dlc-ee's docs-only push, then ai-dlc-ad's 0.765.0 (`db7852fb`), then
this. When ad sends LANDED, rebase the squash onto ad's merge sha, move the CHANGELOG entry above 0.765.0's, re-run
`validate-release-version.sh`, and gate (action 4).

**Base, before the squash.** The branch sat on ai-dlc-59's git.decl tip `770195f1` (`b218-git-decl`: four commits on
ai-dlc-c6's 0.763.0 store commit `ffe350f4`, whose tree is identical to main `6f9da269`), rebased without conflicts.
Re-taken on this base at `7b730929`: `validate-enforcement-map.sh` rc 0 (I66), `validate-shell-portability.sh` rc 0 (S8 clear),
and readset-skip 92, -b 110, -c 108, -d 62 ok, all 0 FAIL. -d moved 55 to 62 with the base's own 115-line
readset-skip edit. ai-dlc-59's 0.764.0 squash `5f160a72` (one commit on `6f9da269`) differs from `770195f1` only in
`VERSION` and `CHANGELOG.md`, so the next rebase, onto 59's LANDED merge sha, needs no re-run:
`git rebase --onto <59's merge sha> 770195f1 b218-inpool-trace`. The shas below are pre-rebase.

**Rehearsal r1** (2-way, `file://`, on `cc8d5248` at base `febd4027`, the main checkout's key records copied in):
`read-set keys: 119 of 277 fixture(s) run (118 changed, 0 unrecorded, 1 stale)` and
`read-set in-pool trace: 6 fixture(s) traced in the pool: fixture-git-env-seam ledger-status-vocabulary
self-update-join-gate validator-fork-budget hermetic-runner prepush-ssh-keepalive`. It was stopped about 35 minutes
in, on operator direction (box load 164), before the merge, so no `recorded` line exists. Its S8 shell-portability FAIL
was the base's: the brace fix sits in 59's later commits.

**Built and pushed (hookless), branch `b218-inpool-trace`, originally on e2's git.decl tip `018c819c`:**
- `33583ae5` — `core/scripts/derive-fixture-readsets.sh`: `--in-pool <dir>` (one fixture; writes
  `log`, `rc`, `trip`, `rows` or `discard`; no local-map write; no VERDICT comparison because there is no
  second run) and `--merge-pool <dir> --local-map <file>` (the one serial writer, through
  `readset_local_write`); `readset_clone_tree` (clonefile per listed file in ONE python process, tar copy as
  fallback); liveness keyed on this run's own sentinel path; `--in-pool` does not add a pool level.
  `.githooks/pre-push`: `readset_pool_trace_prep`, a worker `elif`, `readset_pool_trace_merge`.
- `d522cb15` — the same hook change mirrored into `core/git-hooks/pre-push`; I66 diff 0 lines (control 73).
- `ca9c83b7` — `core/fixtures/readset-skip/run.sh` unit `tracer`: in-pool and merge arms (clean, drop,
  canary, trip, empty dirs, nothing-to-merge) plus mutant `nocanary` killed by the canary arm alone;
  `notrap` mutant re-anchored. readset-skip a, c (108 ok, also through hermetic-run) and d (52 ok) green.

**Measured (this batch, figures with load beside them):** a real `--in-pool` trace of `process-rule-pins`
recorded 70 rows and merged with a `#deriver` row (load 61). `validator-fork-budget` at `d522cb15`: PASS,
3321 of 3324 (load 15); base and tip fork totals 3319/3321 vs 3323/3322, inside run-to-run noise.
List-clone of the real checkout, 12 concurrent: 1.66-1.70s per clone at load ~10 against 6.7-7.2s for the
deriver's tar copy; 4.3-5.0s at load 35-38. Whole-directory `cp -c`: 7.9s (file-count bound).
No packaging edit is needed: install.sh copies `core/scripts/*` by glob, uninstall removes the directory,
the manifest claims `scripts/ai-dlc/*` (checked against `hermetic-run.sh` as control).

**Action 2 is DONE, on the branch at `8da6cb01`.** `df9d7464`: `pm_copy` in `core/fixtures/readset-skip/run.sh`
takes an optional `PM_FN` that confines a mutant's anchor to one function body; the BL-452 knob and linked
mutants run with `PM_FN=readset_live_trace`; arm (f) passes when no gamma row lands and nothing is stashed,
with the red-push world's passing gamma (`|stashed|1|`) as its positive control. `8da6cb01`: arms `pt1`
(knob 1 lists gamma, the near-miss), `pt0` (knob 0 prints nothing, PT_LIST empty), `ptw` (linked worktree
prints `skipped (` … `a linked worktree`, main checkout lists gamma); mutants `ptknob` and
`ptlinked` under `PM_FN=readset_pool_trace_prep`, killed by `pt0` alone and `ptw` alone. Re-run by the lead
at `8da6cb01` (load 10-11): readset-skip rc 0, 92 ok; readset-skip-b rc 0, 110 ok. The hand read -c 108 ok,
-d 52 ok, and `validate-enforcement-map.sh` rc 0. readset-skip's baseline is 92, not the 108 written earlier.

## Start here

- **Repos.** This distribution repo only. Work in your own clone:
  `git clone --branch b218-inpool-trace git@github-euron8:euron8/ai-dlc.git "$(mktemp -d)/r"`.
- **Read/write boundary.** The main checkout `/Users/n8/git/ai-dlc`: read it, never write it, and do not
  check out in or detach it without asking ai-dlc-77 first and waiting for the answer. No consumer tree is
  touched by this plan. Push only branch
  `b218-inpool-trace`, always `--no-verify` until the gated release push. Never edit `readset_keys` or
  `core/scripts/hermetic-run.sh` (other hands own them). Never message a `graph-*` session.
- **Coordination.** ai-dlc-77 holds the box queue and release numbers; ai-dlc-cc and ai-dlc-e2 hold others.
  State your release number to all three before building it, and send `GATE START` / `LANDED` around any gated
  push. Never kill a process by pattern; only a pid you recorded. Point every run that can reach
  `hermetic-run.sh` at `AI_DLC_VERDICT_STORE="$(mktemp -d)"`.
- **Every `Agent` spawn passes `isolation: "remote"`**, works in its own `mktemp -d`, never runs
  `rm -rf` on a variable path, and returns findings as text.
- **Ping the operator** (PushNotification) on any question, any decision, and on completion or an early stop.

## Next actions

1. **Rebase.** Done onto `770195f1`; see the Base paragraph. Release order: ad's 0.764.0 advisor-gate fix may
   gate first by operator ruling, then c6's 0.763.0 store, then 59's git.decl, then this release. When 59 sends its
   squashed release commit, confirm it with `git ls-remote` and rebase `b218-inpool-trace` onto it. Conflicts are expected only in
   `.githooks/pre-push` / `core/git-hooks/pre-push`; keep I66 at 0 diff lines.
2. **DONE at `8da6cb01`** (see the RESUME block). **Fix readset-skip-b** (spawn one hand). Then add the arms ai-dlc-77 required for
   `readset_pool_trace_prep`'s copied lines: `AI_DLC_READSET_LIVE_TRACE=0` sets PT_LIST empty and prints
   nothing (near-miss: knob 1 prints `read-set in-pool trace: 1 fixture(s) traced in the pool: gamma`); a
   linked worktree prints `read-set in-pool trace: skipped (` … `a linked worktree` (near-miss: main checkout
   lists gamma); two `PM_FN=readset_pool_trace_prep` mutants, each killed by its own arm only.
3. **Own-change checks, no full rehearsal.** The operator asked whether a second rehearsal was warranted, and the
   ruling in `.claude/rules/operator-rulings.md` is that a hand verifies only its own change and the gate runs the
   rest. Rehearsal r1 (RESUME block) already showed the prep picking the in-pool set inside a real gate. After every
   rebase: `bash scripts/validate-enforcement-map.sh` (I66) and `bash scripts/validate-shell-portability.sh` (S8)
   from the clone root, then readset-skip, -b, -c and -d, each with its own `AI_DLC_VERDICT_STORE`. When 59's
   squashed commit arrives, run `git diff --stat 770195f1 <squash>` first; if it names only `VERSION` and
   `CHANGELOG.md`, rebase without re-running.
4. **Release.** Take the next free VERSION from `origin/main` at push time (0.764.0 is git.decl's, 0.765.0 is
   ai-dlc-ad's), announce it to ai-dlc-c6, ai-dlc-59 and ai-dlc-ad, write the CHANGELOG entry from the draft below,
   squash to one commit, send GATE START, gate from the main checkout detached at the squash creating
   `release/<version>`, confirm the remote ref moved with `git ls-remote`, merge, send LANDED. From the gate's own
   output read its exit, each changed fixture by name, and the `read-set in-pool trace:` lines (traced, recorded,
   discarded and why, with load beside them). Then, read only, count the rows each traced fixture landed in the
   main checkout's `.git/ai-dlc-fixture-readsets.local`, and compare `hermetic-runner`'s against its 17 committed
   rows in `.ai-dlc-fixture-readsets.tsv`. A large shortfall there is a lossy window the guards did not catch,
   recorded as a too-small read set: the fail-open outcome. Report it as a DEFECT; it is not a pass. If the gate
   discards all six at high load for BL-481 reasons, report that and do not re-gate.
5. **Re-derive this RESUME block after the merge**: what landed, the gate's own `read-set in-pool trace:`
   lines, and the next push's UNMAPPED and stale counts against the pre-release push.
6. **Fresh-resume check**: merge the docs commit, read this plan from a fresh clone of `origin/main` as a
   stranger, re-run action 5's derivation there, assert no next action names work `origin/main` already
   ships, run `bash scripts/validate-plan-shape.sh` there.
7. **Hand off and stop**: run `ListAgents`, then `SendMessage` the first local `ai-dlc-*` session (never
   `graph-*`), idle ones first, exactly `READ and FOLLOW docs/plans/inpool-readset-trace.md`; on a `REFUSED:`
   reply try the next; once one replies `ACCEPTED`, stop.

## Done when

A gated push of the release prints `read-set in-pool trace: recorded <fixtures>` for at least one undeclared
unmapped fixture, the next push from the same checkout reports that fixture mapped (not UNMAPPED, not stale),
and `readset_live_trace` started no detached trace for it.

## Background (not instructions)

- `BL-481` (dropped sandbox reports) is OPEN. `log stream --level debug` was removed and the
  `--local-map` liveness window widened to 10s (both in 0.762.0's content); residual default-level drops
  remain under heavy load. In-pool tracing inherits them: a lossy window discards and the fixture falls back
  to the detached trace.
- 16 fixtures carry a VERDICT discard in the main checkout's local map and are never mapped by the detached
  trace: apply-machinery-stamp, apply-restamp-theirs, apply-self-overwrite, derivation-differential,
  derivation-differential-mutants, handoff-resume-guard, layer-crosswalk-home, layer-extends-grain,
  layer-readopt-gate, ledger-reverify-b, prepush-worktree-env-scrub, procsub-staged-refusal,
  readset-sandbox-root-clause, readset-stage1-verdict, reconcile-emit-report, remediator-shard-join.
  In-pool tracing has no VERDICT comparison, so the undeclared ones among them become mappable.

## CHANGELOG draft (put in at push time, with the version and date; add the rehearsal and gate figures)

Batch 218 (in-pool read-set trace). After a green suite, `readset_live_trace` re-ran every undeclared unmapped or
stale fixture a second time under `derive-fixture-readsets.sh --tracer sandbox --local-map`. This release traces the
pool's own run instead, so the read set comes from the run that gave the push its verdict, and the second run
disappears for every fixture traced that way.

- **Deriver.** `--in-pool <dir>` traces one fixture inside the pool worker and writes `log`, `rc`, `trip`, and
  `rows` or `discard` into `<dir>`; it never writes the local map and makes no VERDICT comparison, because there is
  no second run to compare. `--merge-pool <dir> --local-map <file>` is the one serial writer, through
  `readset_local_write`. `readset_clone_tree` clones the tracked plus untracked-not-ignored list and `.git` per
  file (clonefile in one python process, tar as the fallback), never the whole directory.
- **Hook.** `readset_pool_trace_prep` picks the in-pool set before the pool, the worker runs a picked fixture
  through `--in-pool` and takes its rc, and `readset_pool_trace_merge` merges after the pool under the live trace's
  lock. Both pre-push hooks change identically (`I66`).
- **No fail-open path.** A lossy window (drop notice, LOSS CANARY, unread control, dirty delta, TRIP, driver
  missing) DISCARDS and never maps a smaller set; a discarded fixture falls back to the detached trace. A TRIP
  re-runs the fixture untraced and takes that verdict. A linked worktree skips in-pool tracing with one line
  naming why. A declared fixture (`inputs.decl`) is never traced in the pool. `AI_DLC_READSET_LIVE_TRACE=0` turns
  it off with no output.
- **Fixture.** `readset-skip` gains in-pool and merge arms (clean, drop, canary, trip, empty dirs, nothing to
  merge), the `pt0`/`pt1`/`ptw` arms on the prep, and mutants `nocanary`, `ptknob` and `ptlinked`, each killed by
  its own arm alone. `pm_copy` takes an optional `PM_FN` that confines a mutant's anchor to one function body.
- **This hook edit re-runs every fixture that reads either pre-push hook** on this release's own push.
