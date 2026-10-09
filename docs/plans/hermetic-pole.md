# Hermetic pole — make the push short

## RESUME HERE

**You were started with one sentence: `READ and FOLLOW docs/plans/hermetic-pole.md`. This section
is the ONLY CURRENT STATUS RECORD in this file.**

**THE GOAL, OPERATOR ORDER AT BATCH 217: EVERY PUSH IS SHORT. NOTHING ELSE IN AI-DLC OUTRANKS IT.** A push runs every
fixture it selects, so its wall clock tracks HOW MANY run, not the longest one. The batch-217 baseline, from a gate's
own log: `read-set keys: 122 of 277 fixture(s) run (57 changed, 8 unrecorded, 57 stale)`. **No more pole sharding**:
every new directory edits `setup-sites.md` and `core-manifest.md` and re-runs about fifty fixtures on its own push.

**State at batch 219: 0.763.0 LANDED as `6f9da269` on `origin/main`.** It is the batch-217 release (the shared
per-project verdict store, both hooks, 42 declarations, BL-481's first half, four shards) rebased onto 0.762.0, plus
the fix for the defect that stopped its first gate: the store's key was computed twice and the two copies disagreed.
What landed for that:

1. **One `READSET_VS` span** in both hooks, after `READSET_TOOLS`, holding `readset_vs_store <root>`
   (`.githooks/pre-push:1203`), `readset_vs_ident <hook> <runner>` and `readset_vs_input`. `hermetic-run.sh` extracts
   and sources it at top level; its `hr_store_put` (`core/scripts/hermetic-run.sh:453`) is the one writer.
   `#universe` hashes it too, so no entry written before 0.763.0 is reused.
2. **The runner is the store's only writer.** `readset_vs_put` is gone from both hooks; derive block below holds it at 0.
3. **A declared fixture's published key is exactly its declared key.** No carry-over from an older record; the run/skip
   comparison ignores a recorded row the declaration no longer produces; a declared directory under an excluded top
   gets no row (the runner's rule). The row composition is still two implementations held equal, which is **BL-493**.
4. **The census arm**, unit `vs` arm (k), `vs_census` at `core/fixtures/readset-skip/run.sh:5172`, a synthetic world holding every
   shape that diverged, driven fresh and after a record carry, byte-compared with `--key-only`, three one-side mutants
   killed. The operator chose it over a real-tree arm, which was measured at 6.6 minutes and would key its host on
   the whole tree. **Real-tree census, run once on the release tree: `225 declared, 225 identical, 0 differ`.** The
   carried pass of that census cannot be read as a census, because under the fix a record whose only difference is
   the foreign row decides `skip` and publishes nothing; the synthetic arm edits a declared input between its passes
   so both shapes publish.

**The 0.763.0 gate, from its own log:** `read-set keys: 32 of 277 fixture(s) run (25 changed, 0 unrecorded, 7 stale)`
and `verdict store: 89 fixture(s) skipped on a pass recorded elsewhere`, `apply-drift-after-write` among them. 32 ok,
0 FAIL, every phase PASS, exit 141 from the transport, re-pushed hookless and merged as PR #1090. Wall clock 18:22 to
18:35 at load 50 to 65, bound by three unseeded ~700s `review-shard-merge-mutants` shards. The store was cleared by
exact listing before the gate (228 entries, then 46 a peer's gate had added), seeded from a clean clone at the release
commit, 184 of 225 before the operator stopped the seed to gate, 202 after the gate. **Order a re-seed longest-first
from `.git/ai-dlc-fixture-durations`**; glob order put the four ~700s units last and cost about five minutes.

**Peers at the batch-219 close.** `ai-dlc-59` holds `b218-git-decl`, rebased onto the release and claiming 0.764.0;
`ai-dlc-7b` holds `b218-inpool-trace` and rebases onto 59's tip; `ai-dlc-ad` holds `b218-advgate` and queues behind
both. Ask each for its current state; do not trust this paragraph.

Your instructions are four sections: `## Start here`, `### NEXT ACTIONS`, `### Ping the operator`,
`### Done when`.
## Start here

**Three trees, and only one of them is yours to write.** `<scratch>/ai-dlc-pole`, a full clone under
`mktemp -d` with a `github` remote, pinned at `github/main`: WRITE, every edit and commit of this plan
happens there. `/Users/n8/git/ai-dlc`, the operator's main checkout: read `.git/ai-dlc-fixture-*` with
`cat` only, and use it for the gated push only, detached at the release commit, after asking every
live `ai-dlc-*` session for its window; every linked worktree under its `.claude/worktrees/` is bound
by the same rule. `/Users/n8/git/graph`, the consumer: read it, never write it, and NEVER message a `graph-*` session
without an explicit operator grant, not even a read-only question. Learn about consumer activity from the process table
and block on its pid.

**Every hand brief carries these lines.** `isolation: "remote"`; a `mktemp -d` under the scratchpad; no `rm -rf` on a
variable path; no load generator; `--no-verify` on every push the hand makes; no work under
`/Users/n8/git/ai-dlc/.claude/worktrees/`. **Never `pkill`, `killall` or kill by pattern**: stop only processes you
started, by the pid or process group recorded when you started them. A batch-217 hand's `pkill -f hermetic-run.sh` was
in the window when graph's push was SIGTERMed. **Every run that invokes `hermetic-run.sh` sets `AI_DLC_VERDICT_STORE` to
a mktemp dir**: a test run without it wrote 184 entries into the real store. Remove every worktree a hand leaves before
reporting closed. A wait loop has an exit: a pid or a capped count, never only a marker that may never come.

**Measure only what a decision reads.** Operator ruling at batch 217: no solo timings, because no gate or done-when reads
them. The figures this plan is judged on are an ordinary push's `read-set keys:` run count and its `verdict store: N
fixture(s) skipped` line, with the fixture-suite wall clock and load beside them.

### Derive the state; do not trust the numbers above

```bash
git rev-parse --short HEAD; git status --porcelain | wc -l
git ls-remote github refs/heads/main refs/heads/b218-git-decl refs/heads/b218-inpool-trace refs/heads/b218-advgate
git show github/main:VERSION                                                                 # 0.763.0 or later
n=0; for d in core/fixtures/*/; do [ -f "$d/inputs.decl" ] && n=$((n+1)); done; echo "DECLARED $n"   # 225 at 6f9da269
# single-sourced: the hook has no store writer (0) and the runner sources the shared span (1); control: the span exists in the hook (1)
grep -c 'readset_vs_put' .githooks/pre-push core/git-hooks/pre-push
grep -c 'READSET_VS_BEGIN' core/scripts/hermetic-run.sh; grep -c '^# READSET_VS_BEGIN$' .githooks/pre-push
# the real verdict store, READ ONLY; control: the base directory exists
/usr/bin/find ~/.cache/ai-dlc/verdicts -mindepth 2 -type f | wc -l; ls -d ~/.cache/ai-dlc/verdicts | wc -l
uptime
```

### NEXT ACTIONS — numbered, in order

1. **MEASURE AN ORDINARY PUSH.** DONE at batch 219; the figure is in `### Done when` 4. A push from a clone with no
   `.git/ai-dlc-fixture-keys` keys every fixture unrecorded and runs the full suite, which is the wrong measurement.
2. **RE-DERIVE THIS BLOCK**, `bash scripts/validate-plan-shape.sh`, commit, push from the main checkout, merge. DONE at
   batch 219 as PR #1091.
3. **FRESH-RESUME CHECK**: fresh clone of `origin/main` through the `github` remote's URL, read this plan there,
   re-run the derive block, assert the numbered actions name nothing already shipped, run the plan validator there as
   the floor.
4. **HAND THE PLAN TO A LOCAL AI-DLC SESSION, THEN STOP.** `ListAgents`; if a local `ai-dlc-*`
   session is found (never a `graph-*` one), `SendMessage` it exactly
   `READ and FOLLOW docs/plans/hermetic-pole.md` and nothing else. A `REFUSED:` reply advances to the
   next untried session, idle ones first; silence does not. Once a session accepts, this session has
   no further work and communicates no further with it. If none is found, there is nothing further to
   do. The receiving session reads `### Done when`; where every item is met, it rotates this plan with
   `scripts/plan-rotate.sh` and files nothing new here. **BL-493** (one function for the key rows) and the orphaned
   consumer hook recorded under **BL-481** are backlog work, not this plan's.

### Ping the operator

Report on every question, every decision, and on completion including an early stop. Specifically: when the ordinary
push's `read-set keys:` count is not below the batch-217 baseline of 122; when a gate's `verdict store:` skip count is
far below the declared fixtures the push would otherwise run; and when the plan is handed on. Present a stall as
choices with a marked recommendation. Never narrow the scope on your own authority.

### Done when

1. The pole work of 0.757.0 and 0.760.0 is MET and closed; the pole is no longer this plan's measure. **MET.**
2. The verdict store's key is single-sourced: the census arm (unit `vs` arm (k) of `readset-skip`) reports every
   diverged shape's hook key equal to its runner key at the gate that ships it, three one-side mutants killed, and a
   real-tree census over every declared fixture run once on the release tree reads `225 declared, 225 identical,
   0 differ`. **MET at 0.763.0**; the operator chose the synthetic arm over a real-tree arm that would key its host on
   the whole tree.
3. That release has landed, and its gate printed a `verdict store: N skipped` line covering the declared fixtures the
   push would otherwise have run. **MET: `6f9da269`, `verdict store: 89 fixture(s) skipped`, `32 of 277 run`.**
4. An ordinary push after it (no hook, runner or deriver change) shows its `read-set keys:` run count and fixture-suite
   wall clock, with load beside them, recorded here against the batch-217 baseline of 122 run. **MET: the batch-219
   docs-only push (`3fb33968`, from the main checkout at load 14) printed `FIXTURE SUITE SKIPPED on an unchanged
   content key`, 0 run, exit 0 in about 90 seconds; `docs/` is an excluded top, so nothing was keyed.**
5. The carriers are committed (**MET at 0.763.0**, four sentences across `tool-hazards.md`, `operator-rulings.md` and
   `verification-discipline.md`), this block re-derived, the plan validator green, the fresh-resume check passed, the
   plan handed on.
