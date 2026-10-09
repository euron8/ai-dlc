# Hermetic pole — make the push short

## RESUME HERE

**You were started with one sentence: `READ and FOLLOW docs/plans/hermetic-pole.md`. This section
is the ONLY CURRENT STATUS RECORD in this file.**

**Why this plan exists.** `docs/plans/hermetic-fixtures-poc.md` declared 157 fixtures hermetic across
three releases (0.752.0, 0.753.0, 0.755.0) in smallest-map-rows-first order, and the push got no
shorter: the pool at `.githooks/pre-push:1701` dispatches every selected fixture and waits for the
longest, so a push costs its single longest selected fixture, and the four longest were never touched.
A declared fixture is excluded from the trace queue at `core/scripts/derive-fixture-readsets.sh:305`
and run by the sandbox the runner builds at `core/scripts/hermetic-run.sh:127`.
The operator's instruction at batch 209's close: start on the pole, nothing else until it moves. This
plan is that instruction. It is executed by a session that is not the hermetic-fixtures-poc lead, in
parallel with that plan's close, and it takes the next free release number after asking every live
session which it holds.

**The pole, from `.git/ai-dlc-fixture-durations` in the main checkout at batch 209's close. THAT
RECORD IS POLLUTED AND THE RANK BELOW IS A HYPOTHESIS:** it was rewritten at 20:12 on a day when
orphaned fixture pools and a bare suite run from a shared worktree overlapped three gates, its top
figure (11883s) exceeds any single gate's suite wall clock this week, and `review-shard-merge-mutants`
reads 768s in it where `BL-485` filed it as the pole at 1481s. Action 2 re-derives the rank from a
clean source before action 3 spawns anything.

1. `readset-skip` (4644 lines, 22 map rows, ships)
2. `readset-skip-digest-mutants` (226 lines, ZERO map rows so it runs on every push, `.dist-only`)
3. `fold-architect-ledger-join-mutants-b` (30-line shard driver of a shared battery, `.dist-only`)
4. `gate-adjudication-mutants` (600 lines, `.dist-only`)

`review-shard-merge-mutants` is `BL-485` and batch 208 (`ai-dlc-cd`) is sharding it; do not touch it.

**Second cause, independent of the pole.** 51 to 62 of 251 key records read `#state stale` because
the committed map rows predate digests and no committed trace has cleared them; every stale fixture
runs on every push regardless of the change. One committed trace over the stale set clears it.

Your instructions are four sections: `## Start here`, `### NEXT ACTIONS`, `### Ping the operator`,
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
n=0; for d in core/fixtures/*/; do [ -f "$d/inputs.decl" ] && n=$((n+1)); done; echo "DECLARED $n"   # 103 at 0.754.0; 157 once 0.755.0 (gating at authoring) lands
# the pole, from the main checkout, READ ONLY
sort -k2 -nr /Users/n8/git/ai-dlc/.git/ai-dlc-fixture-durations | head -6
# stale records, READ ONLY. CONTROL: the ok count is non-zero.
grep -l '#state stale' /Users/n8/git/ai-dlc/.git/ai-dlc-fixture-keys/*.key | wc -l; grep -l '#state ok' /Users/n8/git/ai-dlc/.git/ai-dlc-fixture-keys/*.key | wc -l
# which of the four carry a declaration (expect 0 at start)
for f in readset-skip readset-skip-digest-mutants fold-architect-ledger-join-mutants-b gate-adjudication-mutants; do [ -f core/fixtures/$f/inputs.decl ] && echo "DECL $f"; done
uptime
```

### NEXT ACTIONS — numbered, in order

1. **MAKE THE CLONE AND PIN IT**, as above. Ask every live `ai-dlc-*` session (`ListAgents`) what
   release number it holds and whether it holds the main checkout; take the next free number.
2. **MEASURE THE BASELINE AND RE-DERIVE THE RANK FROM A CLEAN SOURCE.** The durations record is
   polluted (resume block). Derive the pole from a gate the record cannot have been written under:
   the per-fixture `.dur` files of a quiet gate, or one run of the four candidates plus
   `review-shard-merge-mutants` each ALONE on a quiet box (`uptime` 1-minute load under 5 beside each
   figure), from the clone root, never under the pool. If the top figures of the record exceed any
   single gate's suite wall clock this week, the record is wrong and the solo run is the rank. Action
   3 spawns nothing until this rank is written down with its source.
3. **ATTACK THE POLE IN RANK ORDER, ONE FIXTURE PER HAND, ALL FOUR HANDS AT ONCE.** For each: read
   `run.sh` and decide whether it SHARDS (a mutant battery the pool can split across sibling
   directories, the `fold-architect-ledger-join-mutants-{,b,c}` shape, each shard declared) or
   DECLARES (a single long run whose inputs can be named). `readset-skip` and
   `readset-skip-digest-mutants` test the trace machinery itself and read the hook's own key records;
   their sandbox needs the hook, the deriver and a seeded repository, which the hermetic runner can hold
   if declared. A hand that finds a fixture cannot be sandboxed says why with the exact escape, and
   proposes the shard instead. Every hand's deliverable: a branch on GitHub, the six measurements of
   action 3, the enforcement-map validator at exit 0, findings as text.
4. **CLEAR THE STALE RECORDS.** `bash core/scripts/derive-fixture-readsets.sh --reconcile` from the
   clone root names the stale, changed and unmapped set; trace it with `--list "<names>" --tracer
   sandbox` on the main checkout detached at the landed sha (the standing ruling: the session runs
   it, no sudo), commit the map, and confirm on the next push's `read-set keys:` line that the stale
   count fell. The trace runs on the box; coordinate the window with every live session first.
5. **ONE RELEASE, GATED, THEN MEASURE AGAIN.** Push from the main checkout detached at the squashed
   commit, `AI_DLC_FIXTURE_JOBS` at the width the operator names, read the suite wall clock and the
   `read-set keys:` line, and put before and after in the CHANGELOG with load beside each.
6. **RE-DERIVE THIS BLOCK**, `bash scripts/validate-plan-shape.sh`, commit, push once from the clone.
7. **FRESH-RESUME CHECK**: merge the docs commit, fresh clone of `origin/main` through the `github`
   remote's URL, read this plan there, re-run the derive block, assert the numbered actions name
   nothing already shipped, run the plan validator there as the floor.
8. **HAND THE PLAN TO A LOCAL AI-DLC SESSION, THEN STOP.** `ListAgents`; if a local `ai-dlc-*`
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

1. Each of the four pole fixtures is declared, sharded with each shard declared, or reported
   unsandboxable with the exact escape and a shard proposal.
2. A committed trace has cleared the stale set, read on a push's `read-set keys:` line as a lower
   stale count than the batch-209 baseline.
3. One gated push after the release shows a shorter fixture-suite wall clock than the baseline at the
   same pool width, both figures with load beside them in the CHANGELOG.
4. This block re-derived, the plan validator green, the fresh-resume check passed, the plan handed on.
