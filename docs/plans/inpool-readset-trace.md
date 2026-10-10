# DISCHARGED — In-pool read-set trace — trace the run that gives the push its verdict

> **THIS PLAN IS SPENT. DO NOT EXECUTE IT.** Every `## Done when` clause is met, on the two gated pushes of 0.767.0
> from the main checkout (`4967fc36`, red; `3680941f`, green, landed as `e6c241a1`). It is kept as the record of what
> was measured. The follow-on work is **BL-481** (dropped sandbox reports) in `docs/backlog.md`.

## RESUME HERE

**You were started with one sentence: `READ and FOLLOW docs/plans/inpool-readset-trace.md`. This section
is the ONLY CURRENT STATUS RECORD in this file, and it records a spent plan.**

**Why.** Operator goal: every push must be short. A push runs every undeclared fixture that is unmapped or stale,
and after a green suite `readset_live_trace` re-ran those fixtures a SECOND time under `derive-fixture-readsets.sh
--tracer sandbox --local-map`. This plan traces the pool's own run instead, so the read set comes from the run that
produced the verdict and the second run disappears for every fixture traced this way.

**Rulings already made (do not re-litigate).** No fail-open path: a lossy window (drop notice, LOSS CANARY, unread
control, dirty delta, TRIP, driver missing) DISCARDS and never maps a smaller set. Each traced fixture runs in its own
APFS clone of the tracked + untracked-not-ignored list plus `.git`. One serial merge writes the local map under the
existing lock. A TRIP re-runs the fixture untraced and takes that verdict. A linked worktree skips in-pool tracing
with one line naming why. Declared fixtures (`inputs.decl`) are never traced in-pool.

**The mechanism LANDED as 0.766.0**, main `d2c7538c` (PR #1096). Code at `875a7b43` (0.768.0): the modes are parsed at
`core/scripts/derive-fixture-readsets.sh:184` and `:185`; the in-pool worker records the verdict the moment the fixture
exits at `core/scripts/derive-fixture-readsets.sh:1544`; the hook functions are `.githooks/pre-push:1091` (prep) and
`.githooks/pre-push:1117` (merge), called around the pool at `.githooks/pre-push:2007` and `.githooks/pre-push:2035`.
Both hooks are identical in the pool block (`I66`). The deriver blob is the same at `d2c7538c`, `4967fc36`,
`3680941f`, `e6c241a1` and `875a7b43`, so the local map's `#deriver` validity key (`.githooks/pre-push:842`) held across all of it.

**Clause 1 MET on the first 0.767.0 gate** (`4967fc36`, main checkout detached, 12-way; load 3.84 at start, 32.52 at
end; exit 1 on four failures, none of them `self-update-join-gate`):
- `read-set map: ... 4 of 277 fixture dir(s) UNMAPPED ...: fixture-git-env-seam ledger-status-vocabulary
  self-update-join-gate validator-fork-budget`
- `read-set in-pool trace: recorded self-update-join-gate prepush-ssh-keepalive; discarded: fixture-git-env-seam
  ledger-status-vocabulary hermetic-runner`

`self-update-join-gate` has no `inputs.decl` (control: 233 fixtures on `origin/main` carry one), was UNMAPPED, ran
`ok`, and the merge wrote it 348 rows plus a `#deriver` row matching the current deriver.

**Clauses 2 and 3 MET on the second 0.767.0 gate** (`3680941f`, the same checkout; load 6.08 at start, 27.81 at end;
exit 0, `pre-push: all gates green.`):
- `read-set map: ... 3 of 277 fixture dir(s) UNMAPPED ...: fixture-git-env-seam ledger-status-vocabulary
  validator-fork-budget` (`self-update-join-gate` is gone from it, mapped through `readset_local_validate`)
- `read-set keys: 47 of 277 fixture(s) run (46 changed, 0 unrecorded, 1 stale); skipping 230`; the one stale is
  `hermetic-runner`
- zero `read-set live trace` lines in the log, against a control of 4 `read-set` lines in the same log, so
  `readset_live_trace` (`.githooks/pre-push:951`) started no detached trace for anything
- `read-set in-pool trace: recorded hermetic-runner self-update-join-gate; discarded: fixture-git-env-seam
  ledger-status-vocabulary validator-fork-budget`

**Why `self-update-join-gate` was traced in the pool again on the push that reported it mapped.** It counts as mapped
at `.githooks/pre-push:842`, yet its key record at `.git/ai-dlc-fixture-keys/self-update-join-gate.key` reads
`#state stale`. Two filters are involved. The `stale, N fixture(s)` report line keys on the decision code `s`. The
post-green trace queue at `.githooks/pre-push:1877` keys on the NEXT state `ns == "stale"`, and `ns` turns stale at
`.githooks/pre-push:1758` when a recorded key changed. The likely cause is that gate 1 wrote the key record while the
fixture was still unmapped, keyed on the whole tree, so the key moved between the two gates. That cannot be verified
now: gate 2 overwrote the record. A same-shape control shows the state settles. `prepush-ssh-keepalive` was recorded
on the 0.766.0 gate, re-traced on gate 1, and is absent from gate 2's in-pool list and verdict lines, so it skipped
on the second push after its recording. `self-update-join-gate` did the same: on the next suite-running push from the
main checkout, ai-dlc-1d's first 0.768.0 gate (`0de54965`, exit 0, later re-gated for an unrelated watchdog race), it
appears on no line of the log, against 51 `ok` verdict lines in the same log, and the UNMAPPED list read
`1 of 277 ...: validator-fork-budget`. The landed 0.768.0 gate (`746fe744`, squashed as `875a7b43`, exit 0, load
25.47 at start and 23.61 at end) read the same: `read-set in-pool trace: recorded hermetic-runner
prepush-ssh-keepalive`, with `self-update-join-gate` absent.

**Two fixtures reached the hold, which is the fail-closed ruling arriving.** After gate 2 the main checkout's local
map holds `fixture-git-env-seam` and `ledger-status-vocabulary` at `#discards 3`, every discard a `log stream` drop
(`BL-481`). `readset_trace_add` (`.githooks/pre-push:883`) routes a fixture at 3 or more on the same `run.sh:deriver`
key to `.trace.held`, which `readset_pool_trace_prep` never reads. 0.768.0 (`875a7b43`, BL-481) declared both of them,
which takes them out of the trace path entirely. `validator-fork-budget` is the one UNMAPPED fixture left.

**NOTE, not filed: a fixture that FAILS in the pool leaves the in-pool line without a mention.** On gate 1
`validator-fork-budget` was among the six traced, failed in the suite, and is in neither `recorded` nor
`discarded`. The worker writes `rc` before it traces (`core/scripts/derive-fixture-readsets.sh:1544`), and a nonzero
exit becomes a discard reason at `core/scripts/derive-fixture-readsets.sh:1667`. The worker's own `discard` write
was not observed for it, and its `#discards` stayed at 1 across that gate. The merge removes every fixture with an
`rc` from the detached queue (`.githooks/pre-push:1126`), so the fixture is neither re-run nor mapped smaller: the
fail-closed direction holds.

**NOTE: the in-pool merge runs on a red suite.** `readset_live_trace` runs only after a green suite
(`.githooks/pre-push:944`), while `readset_pool_trace_merge` at `.githooks/pre-push:2035` is not gated on green. Gate
1 was red, and its merge recorded two fixtures whose own verdicts were `ok`. That is within the rulings above: each
record comes from that fixture's own passing run.

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

1. **Read clauses 2 and 3 on the next push from the main checkout.** DONE: read on ai-dlc-1d's two 0.767.0 gates; the
   figures are in the RESUME block.
2. **Re-derive this RESUME block after the merge.** DONE against `e6c241a1`, with `LOG` set to the second gate's
   saved hook output. The derivation as run:

   ```bash
   L=/Users/n8/git/ai-dlc/.git/ai-dlc-fixture-readsets.local   # READ ONLY
   for f in fixture-git-env-seam ledger-status-vocabulary self-update-join-gate validator-fork-budget hermetic-runner prepush-ssh-keepalive; do
     printf '%s rows=%s markers=%s\n' "$f" "$(awk -F'\t' -v f="$f" '$1==f && $2 !~ /^#/' "$L" | wc -l | tr -d ' ')" \
       "$(awk -F'\t' -v f="$f" '$1==f && $2 ~ /^#/ {printf "%s:%s ", $2, $3}' "$L")"
   done
   # CONTROL: a token no fixture carries must print 0.
   awk -F'\t' '$1=="zq9-not-a-fixture"' "$L" | wc -l
   sed 's/\x1b\[[0-9;]*m//g' "$LOG" | grep -E 'read-set (keys|map|in-pool)|pre-push:'
   ```

   It printed `#discards:3` for fixture-git-env-seam and ledger-status-vocabulary, 428 rows for self-update-join-gate,
   `#discards:2` for validator-fork-budget, 17 rows for hermetic-runner, 7 for prepush-ssh-keepalive, and 0 for the
   control.
3. **Fresh-resume check**: merge the docs commit, read this plan from a fresh clone of `origin/main` as a stranger,
   re-run action 2's derivation there, assert no next action names work `origin/main` already ships, and run
   `bash scripts/validate-plan-shape.sh` there.
4. **Hand off and stop.** Not run. The plan is spent, and P13 binds live plans only, so there is nothing to hand on.

## Done when

A gated push from the main checkout prints `read-set in-pool trace: recorded <fixtures>` for at least one undeclared
unmapped fixture, the next push from the same checkout reports that fixture mapped (not UNMAPPED, not stale), and
`readset_live_trace` started no detached trace for it. **MET** for `self-update-join-gate` on `4967fc36` and
`3680941f` (see the RESUME block).

## Background (not instructions)

- `BL-481` (dropped sandbox reports) is OPEN; residual default-level drops remain under load. In-pool tracing
  inherits them: the 0.766.0 gate lost five of six in-pool traces to them at load ~30, and the two 0.767.0 gates lost
  three of six and three of five at load ~30.
- 16 fixtures carry a VERDICT discard in the main checkout's local map and are never mapped by the detached trace:
  apply-machinery-stamp, apply-restamp-theirs, apply-self-overwrite, derivation-differential,
  derivation-differential-mutants, handoff-resume-guard, layer-crosswalk-home, layer-extends-grain,
  layer-readopt-gate, ledger-reverify-b, prepush-worktree-env-scrub, procsub-staged-refusal,
  readset-sandbox-root-clause, readset-stage1-verdict, reconcile-emit-report, remediator-shard-join. In-pool tracing
  has no VERDICT comparison, so the undeclared ones among them become mappable.
- A 2-way `file://` rehearsal before the release selected 119 fixtures and printed the same six in-pool fixtures;
  it was stopped on operator direction at box load 164 before its merge step.
