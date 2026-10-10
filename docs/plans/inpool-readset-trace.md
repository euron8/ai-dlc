# In-pool read-set trace — trace the run that gives the push its verdict

## RESUME HERE

**You were started with one sentence: `READ and FOLLOW docs/plans/inpool-readset-trace.md`. This section
is the ONLY CURRENT STATUS RECORD in this file.**

**Why.** Operator goal: every push must be short. A push runs every undeclared fixture that is unmapped or stale,
and after a green suite `readset_live_trace` re-ran those fixtures a SECOND time under `derive-fixture-readsets.sh
--tracer sandbox --local-map`. This plan traces the pool's own run instead, so the read set comes from the run that
produced the verdict and the second run disappears for every fixture traced this way.

**Rulings already made (do not re-litigate).** No fail-open path: a lossy window (drop notice, LOSS CANARY, unread
control, dirty delta, TRIP, driver missing) DISCARDS and never maps a smaller set. Each traced fixture runs in its own
APFS clone of the tracked + untracked-not-ignored list plus `.git`. One serial merge writes the local map under the
existing lock. A TRIP re-runs the fixture untraced and takes that verdict. A linked worktree skips in-pool tracing
with one line naming why. Declared fixtures (`inputs.decl`) are never traced in-pool.

**LANDED as 0.766.0**, main `d2c7538c` (PR #1096), tree equal to the gated `c726c2fe`. The code: the modes are parsed
at `core/scripts/derive-fixture-readsets.sh:184` and `:185`, the clone is `core/scripts/derive-fixture-readsets.sh:568`;
the hook functions are `.githooks/pre-push:1016` (prep) and `.githooks/pre-push:1042` (merge), called around the pool
at `.githooks/pre-push:1863` and `.githooks/pre-push:1891`. Both hooks are identical in the pool block (`I66`).

**The release gate's own figures** (main checkout detached at `c726c2fe`, 12-way, 786s, load 4 at start and 32 at
end): exit 0, `pre-push: all gates green.`, 65 ok / 0 FAIL, the changed fixtures ok by name (readset-skip, -b, -c,
-d, hermetic-runner, prepush-ssh-keepalive).
- `read-set keys: 65 of 277 fixture(s) run (64 changed, 0 unrecorded, 1 stale); skipping 212`
- `read-set map: ... 4 of 277 fixture dir(s) UNMAPPED ...: fixture-git-env-seam ledger-status-vocabulary
  self-update-join-gate validator-fork-budget`
- `read-set in-pool trace: 6 fixture(s) traced in the pool: fixture-git-env-seam ledger-status-vocabulary
  self-update-join-gate validator-fork-budget hermetic-runner prepush-ssh-keepalive`
- `read-set in-pool trace: recorded prepush-ssh-keepalive; discarded: fixture-git-env-seam ledger-status-vocabulary
  self-update-join-gate validator-fork-budget hermetic-runner`

**Fail-closed held.** Each discard is a `log stream` drop (`BL-481`): 720, 524, 237, 710 and 261 drops per window, and
ledger-status-vocabulary also tripped the LOSS CANARY. In the main checkout's `.git/ai-dlc-fixture-readsets.local` each
of the five carries one `#discards` row and zero read-set rows; hermetic-runner kept its 17 committed rows rather than
a smaller set. prepush-ssh-keepalive recorded 7 rows plus `#deriver` against 7 committed.

**Done-when clause 1 is NOT MET on that gate**: the only fixture recorded was a mapped one, and all four UNMAPPED
fixtures were discarded by BL-481 drops at load ~30. Clauses 2 and 3 are read on the next push from the main checkout
(action 1).

**A discarded fixture does not fall back to the detached trace.** `readset_pool_trace_merge` removes every fixture
with an in-pool `rc` from `$out/.trace`, discards included, by design (`.githooks/pre-push:1050`), and the gate printed
no detached-trace line. A discarded fixture stays UNMAPPED and is traced in the pool again on the next push; nothing is
mapped smaller. The 0.766.0 CHANGELOG entry said "falls back to the detached trace" and is corrected in this plan's
docs commit, as are this plan's earlier rulings that said the same.

## Start here

- **Repos.** This distribution repo only. Work in your own clone: `git clone git@github-euron8:euron8/ai-dlc.git
  "$(mktemp -d)/r"`.
- **Read/write boundary.** The main checkout `/Users/n8/git/ai-dlc`: read it, never write it, and never check out in
  or detach it without asking every live `ai-dlc-*` session first and waiting for the answers. No consumer tree is
  touched by this plan. Never edit `readset_keys` or `core/scripts/hermetic-run.sh`. Never message a `graph-*`
  session.
- **Coordination.** Send `GATE START` / `LANDED` to every live `ai-dlc-*` session around any gated push. Never kill a
  process by pattern; only a pid or group you recorded. Point every run that can reach `hermetic-run.sh` at
  `AI_DLC_VERDICT_STORE="$(mktemp -d)"`.
- **Every `Agent` spawn passes `isolation: "remote"`**, works in its own `mktemp -d`, never runs `rm -rf` on a
  variable path, and returns findings as text.
- **Ping the operator** (PushNotification) on any question, any decision, and on completion or an early stop.

## Next actions

1. **Read clauses 2 and 3 on the next push from the main checkout.** Do not start one for this; read the next gated
   push any session makes from the main checkout (a linked worktree skips in-pool tracing and does not count). From
   its output take the `read-set keys:`, `read-set map: ... UNMAPPED` and `read-set in-pool trace:` lines, with load
   beside them. If any of the four UNMAPPED fixtures prints under `recorded`, clause 1 is met on that push and clauses
   2 and 3 are read on the push after it. If they are discarded again on stream drops, report the drop counts and load.
2. **Re-derive this RESUME block after the merge** of whatever lands next: what landed, the push's own `read-set
   in-pool trace:` lines, and its UNMAPPED and stale counts against the 0.766.0 gate's (4 UNMAPPED, 1 stale).
3. **Fresh-resume check**: merge the docs commit, read this plan from a fresh clone of `origin/main` as a stranger,
   re-run action 2's derivation there, assert no next action names work `origin/main` already ships, and run
   `bash scripts/validate-plan-shape.sh` there.
4. **Hand off and stop**: run `ListAgents`, then `SendMessage` the first local `ai-dlc-*` session (never `graph-*`),
   idle ones first, exactly `READ and FOLLOW docs/plans/inpool-readset-trace.md`; on a `REFUSED:` reply try the
   next; once one replies `ACCEPTED`, stop.

## Done when

A gated push from the main checkout prints `read-set in-pool trace: recorded <fixtures>` for at least one undeclared
unmapped fixture, the next push from the same checkout reports that fixture mapped (not UNMAPPED, not stale), and
`readset_live_trace` started no detached trace for it. Observation point: the 0.766.0 gate met none of the three for
an UNMAPPED fixture (see the RESUME block); read them on later pushes from the main checkout.

## Background (not instructions)

- `BL-481` (dropped sandbox reports) is OPEN; residual default-level drops remain under load. In-pool tracing
  inherits them, and the 0.766.0 gate lost five of six in-pool traces to them at load ~30.
- 16 fixtures carry a VERDICT discard in the main checkout's local map and are never mapped by the detached trace:
  apply-machinery-stamp, apply-restamp-theirs, apply-self-overwrite, derivation-differential,
  derivation-differential-mutants, handoff-resume-guard, layer-crosswalk-home, layer-extends-grain,
  layer-readopt-gate, ledger-reverify-b, prepush-worktree-env-scrub, procsub-staged-refusal,
  readset-sandbox-root-clause, readset-stage1-verdict, reconcile-emit-report, remediator-shard-join. In-pool tracing
  has no VERDICT comparison, so the undeclared ones among them become mappable.
- A 2-way `file://` rehearsal before the release selected 119 fixtures and printed the same six in-pool fixtures;
  it was stopped on operator direction at box load 164 before its merge step.
