# Hermetic pole — make the push short

## RESUME HERE

**You were started with one sentence: `READ and FOLLOW docs/plans/hermetic-pole.md`. This section
is the ONLY CURRENT STATUS RECORD in this file.**

**Why this plan exists.** `docs/plans/hermetic-fixtures-poc.md` declared 157 fixtures hermetic across
three releases and the push got no shorter: the pool at `.githooks/pre-push:1701` dispatches every selected
fixture and waits for the longest, so a push costs its single longest selected fixture. The operator's
instruction at batch 209's close: start on the pole, nothing else until it moves. A declared fixture is
excluded from the trace queue at `core/scripts/derive-fixture-readsets.sh:305` and run by the sandbox the
runner builds at `core/scripts/hermetic-run.sh:127`.

**State at 0.757.0 (batch 212).** The rank was re-derived from the 0.755.0 gate's own per-run durations file
(12-way, 103 dispatched, load 84-100): `readset-skip-digest-mutants` 2025s, `readset-skip` 1860s,
`gate-adjudication-mutants` 1665s, `reconcile-emit-report` 1484s, `check-24-adversarial-convergence` 1359s,
`review-shard-merge-mutants` 1171s (`BL-485`, batch 208's), `fold-architect-ledger-join-mutants-b` 1102s
(tenth; the plan's original fourth, deferred as not the pole). The top four are SHARDED into thirteen declared
directories; solo, the longest shard is `readset-skip-d` at 206s against parents of 250-393s solo. The
CHANGELOG entry for 0.757.0 carries the full before/after table with load beside each figure. The 0.757.0
gate's own fixture-suite wall clock is the after figure for done-when 3 and is recorded by action 1 below.

**Second cause, independent of the pole.** Stale key records make every stale fixture run on every push.
The 0.755.0 gate selected 49 stale of 251; its detached live trace (started 22:30 on 2026-10-08) was still
running at this release and may have cleared part of the set. Action 3 measures what remains.

Your instructions are four sections: `## Start here`, `### NEXT ACTIONS`, `### Ping the operator`,
`### Done when`.

## Start here`, `### NEXT ACTIONS`, `### Ping the operator`,
`### Done when`.

## Start here

**Three trees, and only one of them is yours to write.** `<scratch>/ai-dlc-pole`, a full clone under
`mktemp -d` with a `github` remote, pinned at `github/main`: WRITE, every edit and commit of this plan
happens there. `/Users/n8/git/ai-dlc`, the operator's main checkout: read `.git/ai-dlc-fixture-*` with
`cat` only, and use it for the gated push only, detached at the release commit, after asking every
live `ai-dlc-*` session for its window; every linked worktree under its `.claude/worktrees/` is bound
by the same rule. `/Users/n8/git/graph`, the consumer: read it, never write it. Spawned hands: `isolation: "remote"`, a `mktemp -d` under the
scratchpad, no `rm -rf` on a variable path, no load generator, `--no-verify` on every push a hand makes,
no work under `/Users/n8/git/ai-dlc/.claude/worktrees/`. Remove every worktree a hand leaves before
reporting closed.

**The declaration method is the one in `hermetic-fixtures-poc.md` action 3** and the worked examples
under `core/fixtures/*/inputs.decl` (157 of them). Two rules the 0.753.0 gate taught: no
`$(dirname "$X")/../<subtree>` walk in a sentinel; a `run.sh` naming `core/hooks/` or `$HOOK` carries
the `AI_DLC_*` scrub loop. `bash scripts/validate-enforcement-map.sh` must exit 0 on the stacked branch
before any gate. A sentinel prints a `pwd -P`-resolved path or the declared relative path, never one
carrying `..`.

**Measure the push, not the count.** The figure this plan is judged on is the wall clock of a gated
push's fixture suite phase, read from the hook's own output (`── fixture suite` to its tally), before
and after, at the same pool width, with `uptime` load beside each. A declaration that does not move
that figure is not progress here.

### Derive the state; do not trust the numbers above

```bash
git rev-parse --short HEAD; git status --porcelain | wc -l
n=0; for d in core/fixtures/*/; do [ -f "$d/inputs.decl" ] && n=$((n+1)); done; echo "DECLARED $n"   # 169 at 0.757.0
# the pole, from the main checkout, READ ONLY
sort -k2 -nr /Users/n8/git/ai-dlc/.git/ai-dlc-fixture-durations | head -6
# stale records, READ ONLY. CONTROL: the ok count is non-zero.
grep -l '#state stale' /Users/n8/git/ai-dlc/.git/ai-dlc-fixture-keys/*.key | wc -l; grep -l '#state ok' /Users/n8/git/ai-dlc/.git/ai-dlc-fixture-keys/*.key | wc -l
# the thirteen shard directories of 0.757.0 all carry a declaration (expect 13)
for f in readset-skip{,-b,-c,-d} readset-skip-digest-mutants{,-b,-c} gate-adjudication-mutants{,-b,-c} reconcile-emit-report{,-b,-c}; do [ -f core/fixtures/$f/inputs.decl ] && echo "DECL $f"; done | wc -l
uptime
```

### NEXT ACTIONS — numbered, in order

1. **READ THE 0.757.0 GATE'S OWN FIGURES** from the operator checkout, `cat` only:
   `/Users/n8/git/ai-dlc/.git/ai-dlc-fixture-durations.last` (top rows) and its `.jobs`, and the suite
   phase's `read-set keys:` line from the gate output. Write that run's fixture-suite pole, at its width and
   load, beside the 0.755.0 baseline (2025s, 12-way, load 84-100) in this block. If that run selected fewer
   than the four sharded units it is not a comparison; say so and wait for a gate that does.
2. **RE-TAKE THE RANK FROM THAT FILE.** Whatever now tops it is the pole. Likely candidates from the 0.755.0
   rank: `check-24-adversarial-convergence` (1359s, UNMAPPED, ships, no declaration),
   `adversarial-shard-merge-mutants` (1132s), `fold-architect-ledger-join-mutants-{b,c}` (1102/1074s,
   declaration-only), `review-shard-merge-mutants` (`BL-485`, leave to batch 208 unless its lead says done),
   `readset-skip-d` if a re-deal is owed. One fixture per hand, all at once, briefs as batch 212 used
   (`isolation: "remote"`, own clone, `--no-verify` pushes, no timing by hands, exit codes only; the lead
   times every shipped unit solo and sequentially on a quiet box, load under 5 beside each figure).
3. **CLEAR THE STALE RECORDS.** `bash core/scripts/derive-fixture-readsets.sh --reconcile` from the clone
   root names the stale, changed and unmapped set; trace it with `--list "<names>" --tracer sandbox` on the
   main checkout detached at the landed sha (the session runs it, no sudo), commit the map, and confirm on
   the next push's `read-set keys:` line that the stale count fell. Check first whether the detached trace
   from the 0.755.0 gate already committed rows (`git log -3 -- .ai-dlc-fixture-readsets.tsv`).
4. **ONE RELEASE, GATED, THEN MEASURE AGAIN.** Push from the main checkout detached at the squashed commit,
   `AI_DLC_FIXTURE_JOBS` at the width the operator names, read the suite wall clock and the
   `read-set keys:` line, and put before and after in the CHANGELOG with load beside each. Every live
   `ai-dlc-*` session gets GATE START and LANDED; take the next free release number by asking them first.
5. **RE-DERIVE THIS BLOCK**, `bash scripts/validate-plan-shape.sh`, commit, push once from the clone.
6. **FRESH-RESUME CHECK**: merge the docs commit, fresh clone of `origin/main` through the `github`
   remote's URL, read this plan there, re-run the derive block, assert the numbered actions name
   nothing already shipped, run the plan validator there as the floor.
7. **HAND THE PLAN TO A LOCAL AI-DLC SESSION, THEN STOP.** `ListAgents`; if a local `ai-dlc-*`
   session is found (never a `graph-*` one), `SendMessage` it exactly
   `READ and FOLLOW docs/plans/hermetic-pole.md` and nothing else. A `REFUSED:` reply advances to the
   next untried session, idle ones first; silence does not. Once a session accepts, this session has
   no further work and communicates no further with it. If none is found, there is nothing further to
   do.

### Ping the operator

Report on every question, every decision, and on completion including an early stop. Specifically:
when a pole fixture cannot be sandboxed or sharded (with the escape named); when the stale trace needs
the box and another session holds it; and when the release lands, with the before and after wall clock.
Present a stall as choices with a marked recommendation. Never narrow the scope on your own authority.

### Done when

1. Each of the four units at the top of the DERIVED rank (at 0.755.0: `readset-skip-digest-mutants`,
   `readset-skip`, `gate-adjudication-mutants`, `reconcile-emit-report`) is declared, sharded with each shard
   declared, or reported unsandboxable with the exact escape and a shard proposal. MET at 0.757.0. The
   plan's original fourth name, `fold-architect-ledger-join-mutants-b`, ranked tenth and is deferred as
   declaration-only follow-up under action 2; its absence does not reopen this criterion.
2. A committed trace has cleared the stale set, read on a push's `read-set keys:` line as a lower
   stale count than the batch-209 baseline.
3. One gated push after the release shows a shorter fixture-suite wall clock than the baseline at the
   same pool width, both figures with load beside them in the CHANGELOG.
4. This block re-derived, the plan validator green, the fresh-resume check passed, the plan handed on.
