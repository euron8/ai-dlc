# Hermetic pole — make the push short

## RESUME HERE

**You were started with one sentence: `READ and FOLLOW docs/plans/hermetic-pole.md`. This section
is the ONLY CURRENT STATUS RECORD in this file.**

**THE GOAL, OPERATOR ORDER AT BATCH 217: EVERY PUSH IS SHORT. NOTHING ELSE IN AI-DLC OUTRANKS IT.** The pole
premise below was WRONG and four releases were spent on it. Measured on the 0.761.0 gate's own log: `read-set
keys: 122 of 277 fixture(s) run (57 changed, 8 unrecorded, 57 stale)`. Most of those run on a push regardless of
what it changed. The wall clock is bound by HOW MANY fixtures run, not by the longest one. The derived
forced-run set is 61 directories (stale plus UNMAPPED, from the gate log's `stale, N fixture(s):` and `read-set
map:` lines). 15 of them carry `inputs.decl` and still run: `.githooks/pre-push:1443` forces a fixture whose
local key record reads `#state stale` unless it has a valid LOCAL row, it never exempts a declared fixture, and
`:1455` writes `stale` back, so a declared fixture can never leave stale. The other 46 are undeclared. The
figure this plan is judged on is the `read-set keys:` run count of an ordinary push, and the wall clock beside
it. **No more pole sharding.** Sharding adds directories, and every new directory edits `setup-sites.md` (read by
48 mapped fixtures) and `core-manifest.md` (12), which re-runs them all on that push.

**Why this plan existed before batch 217.** `docs/plans/hermetic-fixtures-poc.md` declared 157 fixtures hermetic across
three releases and the push got no shorter: the pool at `.githooks/pre-push:1701` dispatches every selected
fixture and waits for the longest, so a push costs its single longest selected fixture. The operator's
instruction at batch 209's close: start on the pole, nothing else until it moves. A declared fixture is
excluded from the trace queue at `core/scripts/derive-fixture-readsets.sh:305` and run by the sandbox the
runner builds at `core/scripts/hermetic-run.sh:127`.

**State after 0.760.0 landed (batch 214, `31617801`).** The rank was re-derived from the 0.757.0 gate's own
per-run durations file (12-way, 68 dispatched, load 3 rising to 83): `check-24-adversarial-convergence` 743s,
`readset-skip-d` 732s, `procsub-staged-refusal` 656s, `procsub-staged-refusal-boot` 619s,
`apply-restamp-worklist` 599s, then `review-shard-merge-mutants{,-b,-c}` 595s (`BL-485`, batch 208's). All five
are SHARDED at 0.760.0: fifteen directories, the 0.760.0 CHANGELOG entry carries the per-shard solo table with
load beside each figure and the shipping-directory fork cost. `readset-skip` was re-dealt in place (no new
directory). `procsub-staged-refusal` and `procsub-staged-refusal-boot` are reported UNSANDBOXABLE: both read this
repository's own history by `git show <sha>:<path>`, and committing the pinned blobs under `core/` was built,
passed the runner and failed enforcement-map arms I104, I113 and I65 as a second corpus. They stay undeclared,
`.dist-only`, sharded; the shard proposal on file is a seeded repository inside the sandbox.

**The 0.760.0 gate's own figures (done-when 3).** 12-way, start load 2.7, 117 of 269 fixtures run (56 changed, 9 unrecorded,
52 stale), suite phase 05:05 to 05:26 = about 1290s wall at end load 16, every one of the seventeen shard directories ok
by name, `validator-fork-budget` 3318 of 3324. Its per-run durations file tops at `self-update-gate` 606s then
`fold-architect-ledger-join-mutants-b` 452s, `readset-skip-digest-mutants` 439s, `review-shard-merge-mutants` 437s; the
largest shard shipped here reads under 300s loaded. Against the 0.757.0 gate (68 dispatched, 1123s, start load 3.3) this
run dispatched 117 and took longer in wall clock while its pole fell from 743s to 606s; it is not a same-selection
comparison and done-when 3 is read on the pole, not the wall clock, because the wall clock is pole-bound only when the
selection is held equal. The gate's own suite-pole phase printed SKIP (coverage 68% of the record under 90%).

**Second cause, independent of the pole.** Stale key records make every stale fixture run on every push.
The 0.760.0 gate selected 52 stale of 269; its own detached post-green trace recorded 34 of 42 into the
local map and the operator checkout's key records read 57 stale against 209 ok after it. Action 3 then ran `--reconcile`
from the main checkout detached at 31617801: 50 named (43 stale, 5 unmapped, 2 changed), 24 recorded, 26 OMITTED by
`log stream` drops at load 3-8, and the map committed with this docs commit (222 fixtures mapped, 12607 entries, down
from 241 and 30065: the deriver drops a traced-and-omitted fixture's old rows so it runs always, the fail-closed
direction). The OMITTED set is the `BL-481` class and is wider than that entry lists; the next push's `read-set keys:` line
is where the stale count is read, and it must be read TOGETHER with that line's UNMAPPED count: nineteen
previously mapped fixtures lost every row to this trace (`validator-arm-selection`, `layer-contract-conformance`,
`self-update-join-gate` among them), so they leave `stale` and enter UNMAPPED with nothing cleared. Only the 24
recorded fixtures can have moved to `ok`, and 24 is the most that line can credit.

**What is next.** The suite pole is now whatever the 0.760.0 gate's per-run file says it is; derive it from
`.git/ai-dlc-fixture-durations.last` in the main checkout before touching anything. `review-shard-merge-mutants`
at 595s loaded is `BL-485` and belongs to batch 208 unless that batch's lead says done.

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
n=0; for d in core/fixtures/*/; do [ -f "$d/inputs.decl" ] && n=$((n+1)); done; echo "DECLARED $n"   # 180 at 0.760.0 plus the batch-214 docs commit
# the pole, from the main checkout, READ ONLY
sort -k2 -nr /Users/n8/git/ai-dlc/.git/ai-dlc-fixture-durations.last | head -6   # the last GREEN gate, never the merged record
# stale records, READ ONLY. CONTROL: the ok count is non-zero.
grep -l '#state stale' /Users/n8/git/ai-dlc/.git/ai-dlc-fixture-keys/*.key | wc -l; grep -l '#state ok' /Users/n8/git/ai-dlc/.git/ai-dlc-fixture-keys/*.key | wc -l
# the eleven declared shard directories of 0.760.0 (expect 11); the six procsub shards are undeclared by ruling
for f in check-24-adversarial-convergence{,-b,-c,-d} readset-skip{,-b,-c,-d} apply-restamp-worklist{,-b,-c}; do [ -f core/fixtures/$f/inputs.decl ] && echo "DECL $f"; done | wc -l
uptime
```

### NEXT ACTIONS — numbered, in order

1. **MAKE THE CLONE AND PIN IT** at `github/main`; ask every live `ai-dlc-*` session (`ListAgents`) what
   release number and batch number it holds and whether it holds the main checkout; WAIT for every answer;
   state the number you take to every one of them before building.
2. **CUT THE FORCED-RUN SET, ALL AT ONCE.** Derive it from the last gate log: every name on its `stale, N
   fixture(s):` lines and its `read-set map: ... UNMAPPED` line. (a) The hook fix: a declared fixture with a
   stale record is decided on its declared keys, and a match writes `ok` (`.githooks/pre-push:1443`, `:1455`,
   and the same lines in `core/git-hooks/pre-push` under I66). It ships from the main checkout detached at the
   commit. (b) Declare every undeclared member, about eight per hand, all hands at once. The procsub
   directories are undeclared by ruling and stay so. A declaration adds no directory, so it edits no ship list.
   (c) Trace what cannot be declared. Never message a `graph-*` session; read the process table and block on a
   pid. No solo timings: no gate or decision reads them. **The superseded pole instruction follows, kept only as
   history; do not act on it.** Derive the rank from
   `.git/ai-dlc-fixture-durations.last` in the main checkout (the per-run file of the last GREEN gate; the merged
   record is polluted). At 0.760.0 it reads `self-update-gate` 606s (ships, DECLARED at 0.759.0, so it is keyed on its
   declaration and is a shard job), `fold-architect-ledger-join-mutants-b` 452s, `readset-skip-digest-mutants{,-c}` 439/422s,
   `review-shard-merge-mutants{,-c}` 437/432s (`BL-485`, batch 208's; leave it unless its lead says done). A
   fixture whose subject is the live repository's history (`procsub-staged-refusal`, `-boot`) is sharded and
   left undeclared: do not build a pin corpus under `core/`. New SHIPPING shard directories move `FORK_BUDGET`
   through arm I8 (+4 at 0.757.0, +4 to +6 at 0.760.0): profile base/tip with `fork-profile.sh --section by-arm
   --stable` before the gate. Hands: `isolation: "remote"`, own literal-path clone, `--no-verify` pushes, no
   timing, exit codes only, and a HOLD / WINDOW OPEN token so they build during a peer's gate and run only in an
   agreed window; the lead times every shipped unit solo and sequentially, load under 5 beside each figure,
   re-taking any row that started above 5. After assembling several hands, grep every new shard name in
   `scripts/uninstall.sh`, `core-manifest.md` and `setup-sites.md`: a `-X theirs` cherry-pick drops the earlier
   hand's words silently. Stage the release commit by path, never `git add -A` with a plan edit in the tree.
3. **CLEAR THE STALE RECORDS.** `bash core/scripts/derive-fixture-readsets.sh --reconcile` from the clone
   root names the stale, changed and unmapped set; trace it with `--list "<names>" --tracer sandbox` on the
   main checkout detached at the landed sha (the session runs it, no sudo), commit the map, and confirm on
   the next push's `read-set keys:` line that the stale count fell. Check first whether a detached post-green
   trace is still running there (`ps` for `derive-fixture-readsets`, then block on its pid) and whether it
   committed rows (`git log -3 -- .ai-dlc-fixture-readsets.tsv`). `readset_trace_add` holds a fixture after
   three discards; the gate prints that list as `NOT re-tracing`, and those leave only by declaration.
4. **ONE RELEASE, GATED, THEN MEASURE AGAIN.** Push only a durable copy of the release commit hookless; the
   gated push from the main checkout detached at the squashed commit must CREATE `release/<version>`, or the
   hook does not run. `AI_DLC_FIXTURE_JOBS=12` unless the operator names a width. Read the gate's exit, every
   changed fixture by name, the `read-set keys:` and `read-set map:` lines, and the new `.last` pole; put before
   and after in the CHANGELOG with load beside each. Every live `ai-dlc-*` session gets GATE START and LANDED.
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
   declared, or reported unsandboxable with the exact escape and a shard proposal. MET at 0.757.0. The five at the
   top of the 0.757.0 gate's rank (`check-24-adversarial-convergence`, `readset-skip-d`, `procsub-staged-refusal`,
   `procsub-staged-refusal-boot`, `apply-restamp-worklist`) likewise: MET at 0.760.0, the two procsub units
   reported unsandboxable with their escapes and a seeded-repository proposal.
2. A committed trace has cleared the stale set, read on a push's `read-set keys:` line as a lower
   stale count than the batch-209 baseline (59-60 stale). PARTIAL at 0.760.0: the gate's trace plus action 3's trace moved the
   operator checkout from 60 to 57 stale; the committed map is in the batch-214 docs commit and the next push reads it. Read `stale` and
   UNMAPPED together: nineteen fixtures were reclassified stale -> UNMAPPED by that trace, and only the 24 recorded
   can count as cleared.
3. One gated push after the release shows a shorter fixture-suite wall clock than the baseline at the
   same pool width, both figures with load beside them in the CHANGELOG. OPEN: no two gates since 0.755.0
   have dispatched a comparable selection (103, 68, 117); the per-run POLE has fallen 2025s -> 743s -> 606s
   across them and is the figure this plan now tracks until a same-selection pair exists.
4. This block re-derived, the plan validator green, the fresh-resume check passed, the plan handed on.
