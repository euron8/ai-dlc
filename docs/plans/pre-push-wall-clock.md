# Pre-push suite wall clock — long poles and how to cut them

## Start here

**Read the Context, then §8b, then the Ordered execution table.** Context frames the two levers
and their sizes; §8b is the whole-suite CPU census that decides which lever is worth what;
Ordered execution is what to do and in what order. Findings §1-§10 are the derivations behind
those numbers — read one when you doubt a figure, not before starting.

**Repos.** One tree is written: `/Users/n8/git/ai-dlc`. **No consumer repo is touched at any
point.** Anything needing a consumer is rehearsed on a tree built by running
`scripts/install.sh` into an empty directory, never in place.
`/Users/n8/.claude/projects/-Users-n8-git-ai-dlc/memory/` — **read it, never write it.**

**Merges are preapproved.** No step in this plan stops for merge authorization. Cut the branch,
run the gate, merge it.

**Everything is sourced.** Every figure below was derived against the working tree with a
same-invocation control, and the derivation is named beside it. A number carried from an
earlier session or from a subagent is a hypothesis until re-derived.

**Ping the operator** on any question, on any decision, and on completion — including an early
stop. Silence and progress are indistinguishable from outside, and the only way to tell them
apart is for the operator to ask.

**Delegate.** The Delegation section below is not advisory: most of these steps are independent
and should run as parallel named agents.

### Next actions

1. **Land the durations merge** (Step 1) in both hooks, with the `suite-dispatch-order` arm and
   its `m4` mutant. Everything measured after this depends on the record being complete.
2. **In parallel, as named agents in worktrees:** shard `enforcement-map-derivations` (Step 2),
   shard `layer-contract-conformance` (Step 3), and take `self-update-join-gate`'s seed apart
   (Step 4 + the Step 8 items for that fixture).
3. **Build `scripts/fork-profile.sh` and the `FORK_BUDGET` gate fixture** (Step 5). Independent
   of 1 and 2; it is the instrument the next two steps are measured with.
4. **Hoist the ~15 cross-arm names and `norm_core_manifest`** above the first arm header, then
   ship `--arms` (Step 6). Do the hoist in the parent, once; delegate one agent per dependency
   family after it.
5. **Run the fork campaign** P1/P2/P4/P5 as one agent per pattern, then the harness tail in
   batches (Step 7).
6. **Hoist `$PRISTINE` and add the `cp -Rc` fast path** (Step 8) once the shards have landed.
7. **Re-derive the pool widths** (Step 9), backgrounded, and rewrite the expired justification
   at `.githooks/pre-push:133-158` and its consumer twin whatever the answer.
8. **Regenerate the read-set map — needs the OPERATOR, and an idle box.**
   `scripts/derive-fixture-readsets.sh` runs `fs_usage`, which **needs root** (`:5`, `:53`), and
   `fs_usage` is system-wide, so tracing while anything else runs folds that activity into the
   map (`:60`). Measured after Steps 1-5: **13 of 153 fixture directories have no map entry** —
   the three added by this program (`enforcement-map-derivations-b`,
   `layer-contract-conformance-b`, `validator-fork-budget`) and ten that predate it
   (`check-h1-recursion`, `check-manifest-bypass`, `gate-remediation-deny`, `gate-repair-record`,
   `gate-series-rung`, `hook-registration-join`, `invariant-index`, `retired-layer-passage`,
   `shell-portability`, `vocabulary-index`).
   **This is fail-closed and not a correctness problem** — `apply_readset_skip:357-359` adds any
   fixture with no map entry to the selection unconditionally, so an unmapped fixture always
   runs. It erodes the skip rather than breaking it. Do it on a quiet box, under `sudo`, after
   the sharding has settled, so the map is derived once against the final directory set.

### Done when

Each of these is a command with a checked-reachable PASS, not a target.

- `bash scripts/validate-plan-shape.sh` → **0 errors, 0 warnings**. Reachable: it reads that
  way on this file today, and removing `## Start here` was shown to produce exactly one finding
  naming it — the control that the arm can fire.
- `bash core/fixtures/suite-dispatch-order/run.sh` green with its assertion floor raised, **and**
  its new `m4` mutant shown to turn that arm red. A merge arm that passes without the mutant is
  indistinguishable from today's replace.
- `bash scripts/validate-enforcement-map.sh` silent on I5, I8, I20, I33, I66, I74 — **and** the
  I66 fork error demonstrated by editing one hook and not the other, then cleared.
- Each sharded family: union of the shards' assertion labels equals the pre-shard set captured
  on the parent commit, and each of the four shard controls in Step 3 shown to exit 2.
- `--arms` with every declared id selected produces byte-identical stdout, stderr and exit code
  to a plain run. This is the equality assertion that makes every per-arm number trustworthy;
  if it does not also cost the same wall time, the selection machinery has its own overhead.
- The fork gate goes **red** when a deleted loop is re-added, and says `FIXTURE BROKEN` — not
  pass — when `bash -x` is neutered by overriding `PS4`.
- `AI_DLC_FIXTURE_NO_SKIP=1 bash .githooks/pre-push` green, with the changed fixtures read **by
  name** in the output. A green banner from the content-key skip is not evidence.
- The makespan and the CPU census re-derived, not assumed: `sort -k2,2nr
  .git/ai-dlc-fixture-durations | head -8` for the pole, and a fresh solo census for the CPU
  floor. **Observation point matters** — take both after Step 7 lands, since Steps 5-7 change
  which arms are worth batching and therefore what Step 9 should sweep.

## Context

`git push` in this repo is gated by `.githooks/pre-push`, whose dominant step is a
150-fixture suite dispatched through `xargs -P 16`. The suite is **pole-bound**: its wall
clock equals the single longest fixture directory, not the total work divided by the pool.
`CLAUDE.md` already says so and points at `.git/ai-dlc-fixture-durations`, but the figures
it cites have gone stale twice and no current number is written down anywhere.

This plan re-derives the pole from ground truth and establishes what the reachable floor
actually is. The short version, and it is not the answer the framing suggests: the pole is
six fixtures, five of them mutation batteries for one 6232-line validator, those six are
**80% of everything the suite computes**, and **that validator alone is ~49% of it** while
having silently regressed **4.1× against a fork budget written in its own header**.

Measured end to end: total suite CPU work is **4983 CPU-seconds**, so on 18 cores the
scheduling ceiling is **277s** against today's **506s** — the pool is 55% efficient, and
perfect packing is worth 45% and not one second more. Getting below 277s means removing work,
and half of the work is in one place.

```
today                                          506s   (8.4 min)
perfect packing, work unchanged                277s   scheduling ceiling
arm selection removes ~2300 CPU-s, then packing ~150s
```

---

## Findings — all measured this session

### 1. The pole is six fixtures, and there is a 261-second cliff behind them

From `.git/ai-dlc-fixture-durations` (loaded costs, whole seconds, written by
`.githooks/pre-push:472`):

| fixture | recorded s |
|---|---|
| self-update-join-gate | 506 |
| enforcement-map-sites-b | 490 |
| enforcement-map-sites | 470 |
| enforcement-map-sites-c | 468 |
| enforcement-map-derivations | 452 |
| layer-contract-conformance | 434 |
| *check-24-adversarial-convergence* | *173* |

150 fixture directories (`find core/fixtures -mindepth 1 -maxdepth 1 -type d | wc -l`),
148 with recorded costs — `check-h1-recursion` and `check-manifest-bypass` are new and
unrecorded. Sum of recorded costs **5553s**; the six above are **2820s, 50.8% of it**.

### 2. Pool width is not the lever

LPT makespan simulation over the real durations file:

```
P=16  makespan=506s   sum/P=347s   util=68.6%
P=18  makespan=506s   sum/P=308s   util=61.0%
P=24  makespan=506s   sum/P=231s   util=45.7%
```

Widening the pool moves nothing, because `makespan >= longest single unit`. Splitting each
>400s unit into **two** shards reaches the packing floor immediately:

```
top6 split 2 ways:  P=16 -> 348s (5.8m)   P=18 -> 309s (5.2m)
top6 split 3 ways:  P=16 -> 348s          P=18 -> 309s
top6 split 4 ways:  P=16 -> 347s          P=18 -> 309s
```

**A 2-way split is sufficient; 3- and 4-way buy nothing.**

**Read this as an upper bound, not a forecast.** The simulation credits a split with halving
the unit's duration, which is false for units that are already internally parallel — see §8
and §8b, where the real ceiling turns out to be **277s**, set by CPU work rather than by
directory length.

### 3. `validate-enforcement-map.sh` is ~49% of the suite's CPU work, and it has regressed 2.4x

Measured from inside the repo, twice: **16.0s wall, 8.1s user + 9.9s sys, 113% CPU.**

The suite runs it **137 times per full run** — enforcement-map-sites a/b/c 26+23+22,
enforcement-map-derivations 35, layer-contract-conformance 31 (already deduped by `reg_run`
at `core/fixtures/layer-contract-conformance/run.sh:91-94`). 137 × 15.7s ≈ **2150s of the
suite's 5553 pool-seconds.**

Every cost comment in the tree is stale, and all of them stale LOW:

| cited | where |
|---|---|
| ~2.5s | `core/fixtures/enforcement-map-sites/run.sh:54` |
| 6.45s | `core/fixtures/layer-contract-conformance/run.sh:28` |
| ~8.5s | `core/fixtures/enforcement-map-derivations/run.sh:30` |
| 13.2s | `CLAUDE.md` |

**Nothing gates it.** `CLAUDE.md` tells the author to time it before and after; that is a
reader-enforced rule and the decay happened anyway.

### 4. The validator's cost is fork overhead, and there is no hotspot to fix

**CORRECTED IN EXECUTION.** This section first said "~12,850 external-command invocations,
~10,400 real forks, a 6.6× decay". **That was mine and it was an over-count.** I histogrammed
command-name tokens anywhere in the 262k-line trace, which counts `grep` and `awk` wherever
they appear inside `err()` message text and inside the embedded awk programs. The direct
measurement, by a classifier that scores token 1 of each trace line against bash builtins and
the script's own functions, is:

```
6553 traced external invocations   -> a 4.1x decay against the file's recorded 1582
prologue                              5 forks
top 10 arms                        80.6% of all 6553
I87 1463   I60 799   I82 641   I59 603   I33b 484
I84  431   I75 382   I61 196   I64 174   I83 110
```

Both numbers can be defended for different quantities — 6553 is what the trace *shows* being
invoked, and every `$( )` additionally forks an invisible subshell, so total process creations
are higher by a constant shape. The gate counts the traced quantity and says so. The
per-fork constants stand: **1.81 ms per fork+exec** (`/usr/bin/true` ×5000 = 9.04s) and
**2.17 ms per grep** (2000 greps = 4.33s); 6553 × ~1.5 ms is the 9.9s of system time.

A timestamped xtrace spans 18.3s of which only **3.9s sits in gaps larger than 30 ms**; the
slowest single operation is one 0.885s `grep -rnE`. The other 14.4s is a quarter-million
tiny shell operations. **Any fix is a broad batching campaign, not a targeted one** — and
the script already records the lesson at `:181-184` (`grep -qxF` vs `case`, ~530×) while
still forking `grep -qxF` 380 times per run.

### 5. The read-set skip cuts fixture COUNT by 86% and wall clock by 15%

Replayed the selection rule (`.githooks/pre-push:342-367`) against the last 40 commits:

```
commits=40   full-suite-forced=8   nothing-changed=20   selective=12
selective avg: 21.5 of 150 fixtures, makespan 429s, sum 2631s
makespan over the 20 commits that ran anything: max 506  median 490  min 123
```

Of the 12 selective commits, **10 select five of the six poles**; only 2 select none.
The 8 forced-full commits are forced by an orphan path — a new file, or `.claude/rules/*.md`,
which is in no fixture read-set.

**The skip optimises sum, not makespan.** It is correct and worth keeping; it is not a
wall-clock mechanism and must not be credited as one.

### 6. The durations record is clobbered by every selective run

`.githooks/pre-push:517-518` replaces the whole record with only the dispatched units'
costs. After a selective run (measured average: 21.5 of 150), the ~129 skipped units lose
their cost and re-enter the next run's ordering at the `999999` unknown slot (`:450`),
which sorts **first** — so the real poles are dispatched **last**.

Simulated makespan under the three record states:

```
healthy record (LPT)            506s
after one selective run         573s   (+13%)
no record at all (fresh clone)  671s   (+33%)
```

### 7. Nine fixtures open nested pools inside the 16-way outer pool

`consumer-machinery-home` 7, `crosswalk-home-declaration` 5, `enforcement-map-derivations` 8,
`enforcement-map-sites` 8, `layer-contract-conformance` 8, `ledger-status-vocabulary` 8,
`self-update-join-gate` 6, `trunk-audit-mutants` 8, `wait-stale-deliverable` 8 — **66 inner
workers on top of 16 outer slots, on an 18-core box.**

`self-update-join-gate` measured solo: **163.9s wall, 718 CPU-seconds, 4.38 average cores.**
Loaded it records 506s — **3.1× inflation.**

The justification for `FIXTURE_JOBS=16` at `.githooks/pre-push:133-158` was measured on an
**83-fixture, 72-second** suite and asserts "the suite is latency-bound, not compute-bound".
**That premise has expired.** The units that now set the wall clock are fork-bound CPU work
at 113% CPU with 62% system time.

### 8. The six poles solo — and the correction this forces

Each pole run **alone** from the repo root, `/usr/bin/time -p`:

| fixture | solo wall | CPU-s | avg cores | loaded | inflation |
|---|---|---|---|---|---|
| self-update-join-gate | 163.9s | 718.0 | 4.38 | 506 | 3.09× |
| enforcement-map-sites | 113.5s | 607.9 | 5.35 | 470 | 4.14× |
| enforcement-map-sites-b | 124.8s | 529.2 | 4.24 | 490 | 3.93× |
| enforcement-map-sites-c | 110.3s | 521.6 | 4.73 | 468 | 4.24× |
| enforcement-map-derivations | 107.8s | 822.9 | 7.64 | 452 | 4.19× |
| layer-contract-conformance | 100.1s | 752.0 | 7.51 | 434 | 4.34× |
| **total** | **720.3s** | **3951.6** | **33.85** | 2820 | |

(`enforcement-map-sites` at 113.5s solo against 470s loaded reproduces `CLAUDE.md`'s recorded
112s/442s to within 2%, which is the control on the whole census.)

**This overturns the sharding-only reading, including my own simulation above.** Those six
fixtures already run their own inner pools; solo they demand **33.85 cores on an 18-core
box**. Splitting a directory that already saturates 7.6 cores into two directories does not
halve its duration — it changes scheduling granularity while the CPU work stays put.

The binding constraint is therefore **not** the longest directory. It is

```
makespan >= total CPU-seconds / ncpu
```

and for the six poles alone that is **3951.6 / 18 = 220s**, already above the longest single
solo fixture (163.9s). The LPT numbers in §2 are an upper-bound model that credits a split
with halving; treat them as the ceiling of what scheduling can buy, not the forecast.

**Consequence for the plan: sharding is necessary but not sufficient, and cutting the
validator's CPU work moves the floor itself.**

### 8b. The whole-suite CPU census — the real floor

Every fixture with a `run.sh` run **alone**, sequentially, from the repo root:

```
fixtures measured:      148
total CPU-seconds:     4983
total solo wall:       1292s   (average 3.9 cores per fixture)
floor at 18 cores:      277s
```

Top of the census by CPU work, which is a different ranking from the loaded one:

| fixture | CPU-s | solo wall | cores |
|---|---|---|---|
| enforcement-map-derivations | 830.6 | 109.4 | 7.59 |
| layer-contract-conformance | 764.5 | 103.0 | 7.43 |
| self-update-join-gate | 751.1 | 171.5 | 4.38 |
| enforcement-map-sites | 599.8 | 111.0 | 5.41 |
| enforcement-map-sites-b | 542.3 | 129.2 | 4.20 |
| enforcement-map-sites-c | 510.0 | 107.6 | 4.74 |
| *ledger-status-vocabulary* | *190.7* | *26.4* | *7.23* |

**Three numbers that reframe the whole problem:**

- **The six poles are 3998 of 4983 CPU-seconds — 80% of all the work the suite does.** The
  loaded-cost view put them at 50.8%; that understated them, because contention inflates the
  light fixtures too.
- **The scheduling ceiling is 277s, not 348s.** Today's 506s is **55% efficient** — the pool
  keeps 9.85 of 18 cores busy on average. Perfect packing is worth 45%, and that is *all* it
  is worth.
- **`validate-enforcement-map.sh` is 137 × 18.0 CPU-s ≈ 2466 CPU-seconds — 49% of the entire
  suite's CPU work.** Not 39%: that earlier figure was against loaded pool-seconds. Half of
  everything this suite burns is one 6232-line script being run 137 times.

So the two levers, sized against ground truth:

```
today                                          506s
perfect packing, work unchanged                277s   (scheduling ceiling)
arm selection removes ~2300 CPU-s, then packing ~150s
```

Nothing else in the suite is worth more than a few seconds of either number.

### 9. Corroboration from outside the repo

- **Span law**, CLRS 3rd ed. §27.1 p.780 eq. (27.3): `T_P >= T_∞`. Read from the scan at
  `cs.wustl.edu/~roger/569M.s09/MultithreadedAlgorithmsChapter.pdf`. This — not Amdahl,
  whose subject is a sequential *fraction* — is the law that says removing other fixtures
  cannot cross the pole.
- **Graham 1969**, *Bounds on Multiprocessing Timing Anomalies*, SIAM J. Appl. Math. 17(2)
  pp. 416-429: Theorem 2 eq. (7) gives LPT's `4/3 - 1/(3n)` worst case, and eqs. (9)/(16)
  give both lower-bound terms — total-work/P and longest-task. The runner's longest-first
  dispatch (`.githooks/pre-push:446-455`) is this algorithm.
- **`xargs -P` cannot participate in any shared job budget.** Verified three ways with a
  control in each invocation: POSIX omits `-P` entirely and mandates sequential execution;
  GNU findutils has zero `jobserver`/`MAKEFLAGS`/token hits in NEWS, manual, git log, or
  `xargs/xargs.c` (control `proc_max` -> 18 hits in the same file); the local BSD man page
  has 0 hits for jobserver/token against 4 for `-P`. **N concurrent `xargs -P k` run up to
  N·k processes and none can see the others** — which is exactly this suite's shape.
- **The remedy has a canonical form**: GNU Make's jobserver — *"If the '-j' option were
  passed down to sub-makes you would get many more jobs running in parallel than you asked
  for"* — and Ninja's pools. oneTBB Appendix B names this exact composition: *"this
  composition of parallel runtimes may result in a quadratic number of simultaneously
  running threads… Such oversubscription can degrade the performance."*
- Industry test splitters that balance on **recorded historical runtime** — CircleCI
  `--split-by=timings`, Buildkite `bktec` — are doing what this runner already does.
  Bazel's own sharding spec is naive round-robin by index. **The dispatch mechanism here is
  ahead of the field; the problem is core demand, not dispatch order.**

### 10. The validator's cost is 100% inside its arms, and its prologue is 0.7% of a run

`PS4='+${LINENO}|'` xtrace, per-source-line cost attributed to the arm region it falls in
(arm regions delimited by the `# --- I<n>: ... ---` headers the invariant-index renderer
already parses; 81 headers covering the 94 declared invariants):

```
before the first arm header (prologue, helper defs):   0.1s
from the first arm onward:                            13.7s
```

```
I87   2.09s   I33b  0.77s   I91  0.38s      top  5 arms: 6.2s  (45%)
I82   1.22s   I85   0.67s   I61  0.38s      top 10 arms: 8.8s  (64%)
I60   1.15s   I84   0.60s   I33c 0.38s      top 20 arms: 11.3s (82%)
I65   0.99s   I75   0.58s   I59  0.36s      top 48 arms: 13.2s (96%)
```

**A correction to this measurement, which is itself the finding.** My first pass keyed arm
boundaries on `^# --- I<n>:` at column 0 and found 81 headers. A blanks-tolerant pattern finds
**96** — thirteen arm headers are indented, including I36 forward/reverse, I37, I38, I41, I42,
I58, I61, I62, I63, I64 and I65 — and the column-0 pass silently merged all of them into their
preceding arm's bucket. **This exact bug is already recorded** at
`scripts/render-invariant-index.sh:22`: *"after fixing the header regex, which was anchored to
column 0 and could not see an INDENTED arm header. That one hid I31, I41, I42 and I58."*

The figures above are the corrected pass. **The operative consequence for Step 6: anything that
re-derives arm boundaries must call the shipped extractor, never a fresh grep.** A misplaced
boundary under `--arms` means a selected arm's body is attributed to its neighbour and does not
run — a silent false pass, which is this repo's whole subject. `EXTRACT_AWK` in
`scripts/render-invariant-index.sh:76-148` is the only correct grammar, and that file already
states the doctrine: one awk program, used by the self-probe and by the render.

**The prologue is 0.1s.** That single number is what makes arm-addressability worth
building: a mutant that needs only its own arm pays essentially no fixed setup tax. A
`--only I45` run would cost roughly `0.1s + that arm's cost` — under a second for the median
arm — against 15.7s today. Across the suite's **137 invocations that is ~2150s becoming
~150s**, which is ~36% of the suite's total work removed, and it is the largest single lever
available anywhere in this analysis.

---

## What is NOT the answer

Recorded so the next reader does not re-derive them.

- **Widening the pool.** `makespan >= longest unit` — P=16, 18 and 24 all simulate to 506s.
- **The read-set skip.** It already cuts 150 fixtures to ~21 and the wall clock barely moves,
  because 10 of 12 selective commits select five of the six poles. Keep it; do not credit it.
- **Sharding alone.** The six poles solo demand 33.85 cores; the machine has 18. Splitting a
  directory that already saturates 7.6 cores does not halve its duration.
- **Optimising a hot arm.** There is no hot arm: the slowest single source line is 0.83s of
  ~14s, and the top 40 of 81 arms are 96% of the cost.

---

## Delegation — run this program with subagents, not one thread

The operator's currency is wall clock, not tokens. Spawn agents liberally and in parallel;
background anything long. This program is unusually well shaped for it: most of the steps are
independent, and the expensive parts are measurement runs where the agent waits rather than
thinks.

**Where a subagent is the right unit:**

| work | delegation |
|---|---|
| Steps 2, 3, 4, 8 | **one agent per fixture family**, in parallel, each in `isolation: "worktree"` — they touch disjoint files and would otherwise serialise behind each other's measurement runs |
| Step 7's fork campaign | **one agent per pattern (P1…P5)**, in parallel; each pattern is a mechanical transform over enumerable sites with its own named control. Give each agent the site list from `forks-by-line` and require it to return the before/after fork count and its control's output |
| Step 7's long tail | one agent per batch of ~10 sites off the harness worklist, fanned out; the batches do not interact |
| Step 6's arm conversion | one agent per dependency family from the coupling table (the `lc_*` family, the `cm`/`CMH` family, …). The hoist is the shared prerequisite and is **not** delegable — do it once, in the parent, first |
| Step 9's sweep | **background it**; 15 cells × ≥4 interleaved reps is hours of machine time and zero thinking. One agent drives it and reports the cell table |
| any long measurement | `run_in_background` and keep working. Never sit in the foreground waiting on a suite run |

**Where a subagent is the WRONG unit, and why:**

- **The I66-joined pool region.** Both hooks must change identically and byte-for-byte. Two
  agents editing the two halves is how they diverge. One agent, both files, one diff.
- **The `--arms` go/no-go and the hoist.** One shared refactor everything else depends on.
- **Anything whose output is a verdict on the whole program.** A subagent's number is a
  hypothesis until re-derived — `.claude/rules/operator-rulings.md`. Delegate the *work*;
  re-derive the *headline* in the parent, with a control, before it goes in a commit message.

**What every delegated agent must be handed**, or it will re-derive it wrongly: the fixture is
run **from the repo root** (five fixtures resolve their root from the process cwd and report
`FIXTURE BROKEN` when `cd`-ed into); a recorded cost is a **loaded** cost and must never be
compared with a solo one; and the control for its own change from the table in Verification.

---

## Implementation

Ordered so that each step's measurement is trustworthy when it is taken. Step 1 lands first
because every later makespan reading comes off the record it repairs. Steps 2/3/4 and 8 are
independent of each other and should run as parallel agents; 5 gates 6 and 7.

### Step 1 — the durations record must MERGE, not replace

`.githooks/pre-push:517-518` (and its I66 twin in `core/git-hooks/pre-push`) replaces the
whole record with only the dispatched units' costs. Replace with a last-wins merge:

```sh
  cat "$out"/.dur/* > "$out/.durations" 2>/dev/null
  if [ -s "$out/.durations" ]; then
    { [ -s "$DURATIONS_RECORD" ] && cat "$DURATIONS_RECORD"; cat "$out/.durations"; } 2>/dev/null \
      | awk 'NF == 2 { c[$1] = $2 } END { for (k in c) print k, c[k] }' \
      | sort > "$out/.merged"
    [ -s "$out/.merged" ] && cp "$out/.merged" "$DURATIONS_RECORD" 2>/dev/null
  fi
```

Concatenation order is the merge rule — old record first, this run second, `c[$1]=$2` is
last-wins. `NF == 2` is the same predicate the reader already uses at `:448`. `NR==FNR` was
rejected: it dies when the record does not exist, which is the fresh-clone case the current
code handles correctly. The empty-run behaviour at `:513-516` is preserved unchanged.

**I66 requires the identical text in both hooks**, indented identically; prose above may and
should differ. `fx_pool_block()` in `scripts/validate-enforcement-map.sh` strips comments
before comparing.

Residual cases, each already benign: a stale cost only mis-**orders** (the count guard at
`:454-456` rejects a short reorder, and both `n_expected` and the report read `$out/list`,
never `$out/.order`); a ghost key for a deleted fixture is already proven harmless by
`core/fixtures/suite-dispatch-order/run.sh:161-171`, which feeds a literal `ghost 42` line;
a renamed fixture falls to the `999999` fail-safe by design. Pruning against the on-disk set
is deliberately **not** in this step — doing it right needs a pre-skip copy of the list,
which is another executable line in the I66-joined region for a defect nobody has measured.

**Proof, with the control.** Extend `core/fixtures/suite-dispatch-order/run.sh` (it already
seeds a real git tree, drives the hook, and carries a `mut()` battery with a `cmp -s` guard
and an `EXPECTED_ASSERTIONS` floor). New arm: after a narrowed run, the record still carries
the undispatched units' costs and the next run's dispatch trace is still longest-first. New
mutant `m4` reverts the merge to a plain `cp`; under it the arm must read 1 line instead of
3 and the trace must collapse to glob order. **Without that mutant the arm passes equally on
a hook that never merged anything**, because on a full run merge and replace are
indistinguishable. Bump `EXPECTED_ASSERTIONS` accordingly.

### Step 2 — shard `enforcement-map-derivations` (452s) two ways

Structural twin of `enforcement-map-sites`: same derived `NAMES` (`:563` vs `:1717`), same
`--run-one` entry, same control-first, same `JOBS=8` + `xargs`. Transplant from
`core/fixtures/enforcement-map-sites/run.sh`:

- `SHARDS="a b"` (`:1755`) — two, because the simulation shows 3- and 4-way buy nothing.
- `--group` arg parse + membership guard (`:1763-1771`), placed **after** the `--run-one`
  branch which already owns `$1`. Rewrite the copied comment's *reason*: derivations does not
  scrub `AI_DLC_*` (it says so at `:590-597`), so the sites rationale would be a false reason.
- Coverage join (`:1779-1790`) — a declared shard with no driver directory must exit 2.
- `NAME` derivation (`:1792-1793`), then replace **every** literal
  `enforcement-map-derivations:` in the report with `$NAME`.
- Round-robin partition awk (`:1822-1826`) — round-robin, not contiguous halves, because
  assertion costs differ by an order of magnitude (`:1746-1750`).
- `N_MINE` empty-shard guard (`:1827-1831`).

New `core/fixtures/enforcement-map-derivations-b/` with a 30-line `exec` wrapper copied from
`enforcement-map-sites-b/run.sh`, `chmod +x`, and a **non-empty `.dist-only`** carrying
`enforcement-map-sites-b/.dist-only`'s second paragraph verbatim ("A SHARD INHERITS ITS
SIBLING'S MARKER BY CARRYING ITS OWN, NOT BY POINTING AT IT"). Because it is `.dist-only`,
**do not** touch `uninstall.sh`, `core-manifest.md`, or `setup-sites.md` — I8 fails on either.
Verified against a control: `enforcement-map-derivations` appears in 0 of those three files
while `layer-contract-conformance` appears in all three.

`JOBS=8` drops to **4**, with the arithmetic written in place: two directories × 4 keeps this
fixture's contribution to the machine's core demand where it was. This is the one number in
the step that is a judgement, and it goes on Step 5's measurement list.

### Step 3 — shard `layer-contract-conformance` (434s) two ways

**Not a transplant.** This fixture is a three-phase registry (`run.sh:80-97`): `RUNS` is the
deduped set of distinct validator invocations, `ARMS` the assertion list, and the mapping is
**many-to-one** — three arms read the `control` run and one reads another arm's run.
Partitioning `ARMS` would split arms away from the run they read.

Partition **`$RUNS` minus `control`** round-robin. A shard's arms are those whose `run` field
is in its partition, plus — in shard `a` only — arms whose run is `-`. Arms reading `control`
evaluate in every shard, matching the sites precedent.

Three things that will silently break if missed:

- **`ASSERTIONS` must become shard-local.** It is incremented in `reg_arm` for every arm in
  Phase 1, so an unmodified shard prints "all 31 assertions correct" after evaluating ~15.
- **A new coverage arm** asserting every arm's `run` field resolves to `-`, `control`, or a
  member of `$RUNS`. An arm that resolves nowhere today simply is not printed.
- **An `N_MINE` zero guard on the pool feed.** The existing `N_RUNS -lt 25` floor is global
  and still passes on a shard dealt nothing.

`LCC_JOBS=8` → 4, same arithmetic as Step 2.

**Packaging differs: this fixture SHIPS.** Ship the shard too and add it to all three
hand-lists — `scripts/uninstall.sh:140`, `core/skills/ai-dlc/core-manifest.md:215` (and its
second copy, bound by I5), `core/skills/ai-dlc-update/reconcile/setup-sites.md:156`. I8 joins
all three in both directions, so a partial edit fails the very next push. On a consumer both
directories resolve `$VAL` to nothing and take the existing SKIP at `:63`.

**Coverage proof for Steps 2 and 3, and the controls.** The union of the shards' assertion
labels, minus the control both run, must equal the pre-shard set captured on the parent
commit. Then a permanent arm inside shard `a`: `N_LISTED - 1 == Σ over $SHARDS of the count
dealt to that shard`. Four controls, each of which must be shown to come out the other way:
move the `-b` directory aside (must exit 2); declare a `c` shard with no directory (must exit
2); shrink `SHARDS` to `a` while `-b` still passes `--group b` (shard b must exit 2, not fall
back to `a` — the failure the sites comment says an env-var design would produce); and for
LCC, register a throwaway arm naming a label absent from `$RUNS`.

### Step 4 — `self-update-join-gate` (506s): measure the seed before sharding it

> **THE POLE IS ONE MECHANISM, AND IT GROWS ON ITS OWN.** Measured by ablation
> (`AI_DLC_GATE_IN_SAFE_STOP=1` makes `:161` return early, so this is a non-destructive
> ablation rather than an edit), 3 interleaved reps, one gate invocation at a time:
>
> | invocation | median real |
> |---|---|
> | full, DEFER consumer | **155.07s** |
> | same, safe-stop short-circuited | **1.40s** |
> | full, non-DEFER consumer | 3.30s |
> | the `:291` walk over 150 fixture directories, in isolation | 0.83s |
>
> **`advise_safe_stop` is 153.7s of 155.07s — 99.1%**, and the 150-directory walk that looked
> like the obvious suspect is 0.5% of one invocation. The mechanism, re-derived here with a
> control: `BASE..THEIRS` spans **227 commits of which 111 touch VERSION** (control: the same
> `rev-list` against a nonexistent path returns 0), and `self-update-gate.sh:120-122` spawns
> **one full nested gate invocation per candidate**. 110 × ~1.4s reproduces the delta. It is
> linear rather than quadratic by design — `:118` exports `AI_DLC_GATE_IN_SAFE_STOP=1` before
> the loop so children do not recurse, and the comment says so.
>
> **`seed.sh` derives `BASE` as the parent of the newest `CHECK_LOADED`-adding commit and
> `THEIRS` as HEAD, so every release that lands without adding an anchor adds one more nested
> gate invocation.** Nobody has to touch this fixture for it to get slower. That is how it
> reached #1 pole, and 111 is the current value, not a constant.
>
> **OPERATOR RULING:** bound the FIXTURE's range at the minimum that keeps every assertion
> non-vacuous, and leave `self-update-gate.sh` alone. Separately, measure what a consumer pays
> on a wide pull and report it as a finding — a consumer crossing N releases pays N nested gate
> invocations and nothing on that side measures it. The monotonicity question (if the defer
> predicate flips exactly once across the candidate range, the linear scan is a binary search
> wearing a loop and 110 invocations becomes ~7) is to be **measured and reported, not acted
> on** in this program.
>
> **A second ruling, on the shared temp namespace:** `seed.sh:24` mktemps into
> `${TMPDIR:-/tmp}/su-join-gate.*`, and two concurrent consumers of that namespace can delete
> each other's work trees — which happened during this execution, from a cleanup glob of mine.
> The fixture's completeness arm reports that case **byte-identically** to "the pool dropped
> work"; an isolated repro fired three ways (healthy 6/6 markers, `export -f` removed 0/6,
> source tree deleted mid-flight 0/6) confirms the verdict cannot discriminate. Fix: give each
> run a private TMPDIR. **Do not** add an arm to tell the two apart — the namespace fix makes
> that state unconstructible, and a check for an unconstructible state cannot fire.
>
> **PREMISE CONTRADICTED IN EXECUTION — read this before acting on the rest of Step 4.**
>
> The step below assumes the seed dominates. Instrumented during execution it does not:
> **seed ~4s, gate pool ~222s, rc-pair table ~1s** — the seed is about 2% of the fixture.
> The cost is a single invocation of
> `core/skills/ai-dlc-update/reconcile/self-update-gate.sh`, which walks all 150 fixture
> directories (`:291`), executes both the current and incoming version of every changed
> `core/scripts/` file inside the consumer tree (`:367-368`), and re-invokes the entire gate
> once per VERSION-bumping commit in `BASE..THEIRS` under `--safe-stop` (`:120-122`).
>
> **So sharding this fixture cannot help**, and for a reason stronger than the seed cost: its
> six gate invocations already run concurrently at width 6 = the run count, so splitting them
> across two directories changes nothing about when the last one finishes. The seed work below
> is still worth doing — it is cheap and it uncovered a shipped defect — but the fixture's
> wall clock moves only when that gate program gets cheaper.
>
> The seed/pool/rc split above came from a subagent and **has not been re-derived on a quiet
> machine**. My own attempt returned seed 33-41s and the pickaxe 2.2-2.5s against the agent's
> 4.2s and 0.16s — taken at load average 62 with three agents running, i.e. inflated about an
> order of magnitude. Directionally they agree; neither set is comparable with the other, and
> that is the loaded-versus-solo hazard this plan warns about, walked into while writing it.
> **Re-derive on an idle box before any number here is quoted.**
>
> **A shipped defect found by attempting the parallelisation**, confirmed independently with
> controls in both directions on bash 3.2.57: in `seed.sh:57`,
> `local ref="$1" dest="$2" src="$WORK/src-${ref:0:8}"` expands `${ref:0:8}` against the
> **enclosing** scope, not the `ref` assigned earlier on the same line. With no outer `ref` it
> yields `src="$WORK/src-"` for **both** installs, and `set -u` does not catch it because
> `local` has already declared the name by the time `src` is evaluated. The two installs have
> always shared one scratch directory; it survives only because `rm -rf "$src"` wipes the
> previous clone, and parallelising them without splitting the assignment fails outright with
> `could not create work tree dir '.../src-': File exists`.

Its six gate invocations are already parallel at width 6 = the run count. The only thing a
shard could parallelise is already parallel, and a shard would re-pay `seed.sh` in full:
three `git clone --no-hardlinks` against a 20 MB `.git`, two full `scripts/install.sh` runs,
and a history-wide pickaxe. **Do not shard it until the serial prefix is measured.**

```
/usr/bin/time -l bash core/fixtures/self-update-join-gate/seed.sh    # solo, idle, 5 reps
```

Let `S` = median seed wall, `T` = 163.9s (measured). If `S/T > ~0.4` a 2-way shard costs
`S + (T-S)/2` per shard and roughly doubles this fixture's aggregate CPU — not worth it. If
`S/T < ~0.15` it pays.

**The change I expect to be right regardless** is attacking the prefix in place:

- **Parallelise the two `install_at` calls** (`seed.sh:67-68`). They are independent — distinct
  `ref`, distinct `dest`, and `install_at` derives `src="$WORK/src-${ref:0:8}"` so the scratch
  clones cannot collide. Capture each PID and `wait "$pid"` individually so
  `install at BASE failed` and `install at THEIRS failed` stay distinguishable; collapsing
  them into one message is a regression in evidence. Expected saving: about half the seed.
- **Measure the pickaxe** at `seed.sh:36-37` before touching it. If it is under a couple of
  seconds, leave it. The derivation must not become a hardcoded ref — `:32-34` says why, and
  `:45-54` proves the derived range is non-vacuous.

Control for the parallel seed: point one ref at a bogus SHA and confirm the run exits 2
naming **that** ref. Then the full fixture must stay green with the same six assertions.

### Step 5 — build the fork profiler and the gate FIRST

Both later steps depend on it, and the file already tells you the number it should produce.

**`scripts/validate-enforcement-map.sh:173-177` carries its own fork budget, verbatim:**

> THIS SCRIPT'S COST IS PROCESS SPAWN, MEASURED RATHER THAN ASSUMED. One run of it forks
> **1582** external commands — 643 of them `grep` — and at 1.48ms per fork+exec on the
> reference box that is 2.34s of its 4.70s of SYSTEM time. The suite runs it **~140 times**…

Measured today: **6553 traced external invocations, 9.9s of system
time.** That is a **4.1× decay in a number the file states about itself**, and it is the whole
argument for the gate. (It also corroborates the 137-invocation count independently.)

**The harness must be dynamic — static analysis of this file does not work.** It embeds awk
programs and python3 heredocs carrying their own `for`/`while` keywords, so a shell-shaped
parser reports call sites at nesting depth 39; and static `grep` tokens under-report runtime
invocations by 13× (308 vs 4073) because the multipliers are corpus-derived loop trip counts.

`scripts/fork-profile.sh`: `PS4='+@${LINENO}@ '`, `bash -x … 2>&1 >/dev/null`, one awk
classifier. The `@N@` marker is what separates trace from the validator's own stderr —
**`BASH_XTRACEFD` does not exist in bash 3.2**, which is all this box has, so fd separation is
unavailable. Classify token 1 against bash builtins, the script's own functions (derived:
`grep -oE '^[a-z_][a-z0-9_-]*\(\) \{'`), and everything else = one fork. Join line → arm by
**reusing `EXTRACT_AWK` from `scripts/render-invariant-index.sh:76-148` verbatim** — that file
already states the doctrine ("One awk program, used by the self-probe and by the render, so
the thing proven to work is the thing that runs"). Outputs: `forks-by-line` (the worklist),
`forks-by-arm` (a reviewable artifact — a new invariant that adds 800 forks shows up in a
diff), and `TOTAL`.

Known undercount, stated so nobody re-derives it: each `$(...)` costs a subshell fork plus the
traced inner command, and only the inner one is visible. It is a constant-shape bias; it does
not affect ranking or a like-for-like gate. Do not chase it.

**The gate.** `FORK_BUDGET=<N>` lives beside the `:173-177` comment — the comment that
decayed, made executable — and a new fixture fails when `measured > FORK_BUDGET`. **A wall-clock
budget is the wrong shape**: it cannot run inside a 16-wide pool without measuring contention,
and a threshold with enough headroom to survive a loaded box cannot catch the 39% regression
`CLAUDE.md` already records. Fork count is deterministic and load-independent.

Four guards, all required, or the gate passes vacuously:

1. `measured == 0` is `FIXTURE BROKEN`, not a pass — it means the tracer produced nothing.
2. Classifier probes run **before** the corpus: a script invoking `/usr/bin/true` exactly 50
   times must report exactly 50; a fork-free script must report exactly 0.
3. Count twice, require equality; inequality is `FIXTURE BROKEN` with the delta, never a red.
4. Assert the traced run's exit code **and** that the trace reached the last arm's header line
   — a validator that dies at line 400 forks very little and would sail under budget.

Plus a stale-high arm: fail when `measured < FORK_BUDGET × 0.7` with "lower it", or the budget
ratchets to a number nothing can cross. Re-baselining on corpus growth is a deliberate,
reviewable one-line diff — a forks-per-fixture ratio was considered and rejected because it
hides a regression behind corpus growth.

Controls that prove the gate can fire: re-add one deleted loop and it must go red; neuter
`bash -x` by overriding `PS4` and it must say `FIXTURE BROKEN`, not pass.

### Step 6 — arm-addressable validator (the largest lever)

Give `scripts/validate-enforcement-map.sh` an `--arms <ID>[,<ID>…]` mode so a mutation battery
runs only the arm its mutant targets. On today's numbers that takes the suite's 137
invocations from ~2150s to ~150s — about 36% of total suite work, the largest single lever in
this plan.

**The go/no-go was measured and is decisively passed.** The condition is "shared setup is a
small fraction of a run"; measured, cost attributed to every line before the first arm header
— which includes the execution of every helper defined there — is **0.1s of 13.8s, 0.7%**.

**The silent-false-pass hazard is smaller than it looks, for one specific reason.** The
validator runs `set -u` (`:155`) and **not** `set -e`. So the coupled-arm failure — arm X
selected while arm W that computed X's input is skipped — reads an unset variable and the
shell **exits with `unbound variable`**. That is a loud crash, not a green run, which is the
opposite of this repo's named failure class.

**The coupling is enumerable, not speculative.** Over the 91 arm regions, counting a
dependency only where an arm reads a variable it did not first assign: **64 arms are
self-contained; 27 read a value first set in an earlier arm**, through roughly 15 named values
(`lc_file`, `lc_ids`, `lc_pins`, `TEMPLATE`, `em_marker`, `cm`, `CMH`, `CORE_SCRIPTS_HOME`,
`scan_policy`, `SETTINGS_TMPL`, `PP_CONS`, `PP_DIST`, `CCF`, `LC_YAML`, `i54_files`, `GV`) and
exactly **one** function defined inside an arm and called from four others,
`norm_core_manifest`. Most are not arm state at all — `lc_file` is assigned from
`${AI_DLC_LAYER_CONTRACT:-…}` and merely happens to sit inside the I36/I37/I38 region.

So the prerequisite is a **hoist of ~15 names and one function above the first arm header**.
It is mechanical, provable by a byte-identical output differential on the real corpus, and
worth doing regardless — it is what makes `forks-by-arm` attributable at all.

**The safety net already exists, and it is the mutants.** The three batteries assert these
invariant ids: sites 28 arms (I8 I10 I12 I15 I16 I17 I20 I21 I25 I26 I29 I31 I32 I33 I40 I45
I47 I49 I50 I51 I52 I53 I54 I55 I56 I57 I59 I60), derivations 13 (I3 I8 I9 I10 I22 I23 I33
I33b I74 I79 I84 I85 I86), layer-contract 11 (I10 I36 I37 I38 I41 I42 I61 I62 I63 I64 I65) —
union **≈48 distinct arms, which is exactly the set `--arms` would ever be pointed at**, since
those three fixtures are its only callers. The conversion is therefore self-proving per arm:
if selection broke an arm's reachability, its mutant stops firing and the fixture goes red.
Arms outside the 48 are never selected and their selected-mode behaviour is irrelevant.

Two design constraints that must hold or the mechanism rots:

- **The arm→mutant mapping must be DERIVED, never hand-listed.** Each fixture's `want` string
  is a literal substring of some arm's `err(...)` text, so resolve it by matching `want`
  against each arm's line range. **0 or ≥2 matches is `FIXTURE BROKEN`**, raised at build time
  before a pool slot is spent — the same posture as the existing `cmp -s` guard in
  `mutant_fires`.
- **`--arms` must be generated from the same extractor** — filter the source to preamble plus
  the selected arm regions using `EXTRACT_AWK`'s own line ranges. A hand-written second
  region-finder is a second set of bugs.

Residual hazards `set -u` does not cover, both enumerable: an accumulator a skipped arm would
have appended to (exactly **one** `X="$X …"` shape in the whole file), and a variable that is
legitimately empty so the arm evaluates an empty subject and prints nothing. The differential
that catches both: on a clean tree, `--arms I<n>` for every ID in turn must produce no
finding, and the **union over all IDs must equal the full run's output exactly**.

Rank the conversion by measured arm cost, not by ID: I87 2.09s, I82 1.22s, I60 1.15s, I65
0.99s, I33b 0.77s, I85 0.67s, I84 0.60s, I75 0.58s. Note that I87 and I82 — the two most
expensive arms — are selected by **no** fixture, so they only ever cost the one full run in
the pre-push prologue; the arms worth converting first are the expensive members of the
48-arm selected set, not the expensive arms outright.

**One more vacuity guard `--arms` must carry:** `--arms I999`, naming an id no arm declares,
must exit 2 with `no arm declares I999`, never exit 0 having run nothing. Likewise an id whose
region contains no emitter — `render-invariant-index.sh` already counts `silent` arms, so
reuse that count. A fixture asking for an arm that cannot emit is a fixture that passes forever.

**And the equality assertion that makes the whole mechanism self-checking:** `--arms` with
*every* declared id selected must produce byte-identical stdout, stderr and exit code to a
plain run. It is one line, it exercises every region boundary at once, and if it does not also
cost the same ~15.7s then the selection machinery has overhead of its own and every per-arm
number taken through it is contaminated.

### Step 7 — the fork-reduction campaign

Broad by necessity — the flat profile leaves nothing to target. Four patterns, ranked by
(forks removed / risk); the harness names the rest.

**P1 — membership test against a string already in memory.** 380 `grep -qxF` invocations
remain, and **the replacement helper already exists**: `in_lines()` at `:192-202`, written for
exactly this, with the measurement beside it (`grep -qxF -- b <<<"$L"` 3.717s vs `case` 0.007s,
~530×). Static sites: `:906`, `:1631`, `:1635`, `:1645`, `:4880`, `:4881`, `:4951`, `:5245`,
`:5259`. Expected −380 forks. **Hazard the file itself documents at `:186-190`**: an empty
needle becomes `"\n\n"` and matches any list holding a blank line — a silent PASS. Control per
site: an empty needle against a list containing a blank line must return false.

**P2 — one external per file inside a file loop → one external over all files.** The canonical
site is `i87_readable()` at `:5620-5626`, the 511-invocation `AI_DLC_*` family; `find … -exec
grep … {} +` takes it to ~4. Same shape at `:3036`, `:4055-4056`, `:742`. Expected −600 to
−900 forks, and the user-time win is larger than the fork constant predicts because for 15 KB
files `grep` is nearly all startup. Control: byte-identical output on the real corpus, plus
I87's existing three-way probe at `:5638-5665`.

**P3 — N recursive tree scans → one.** `:1166-1172` inside I65 runs one `grep -rls` **per
enforcer basename**, ~40 full recursive walks. The comment there says "one grep per enforcer,
not per pair" — that was the last round of this same campaign; the next step is one grep for
all of them via `grep -rnoFf`. Invisible to gap analysis because it is 40 separate 20-50 ms
scans rather than one long one. Control: I65's existing four-way positional probe at
`:1232-1250` must produce the identical `1/100/1000/10000` score.

**P4/P5 — `$(cat f)` → `$(<f)`** (measured in-file at `:207-216`: 0.83 ms vs 2.04 ms; 682 `cat`
invocations remain) and **`basename`/`dirname` → parameter expansion** (the idiom is already
used at `:1161`). Zero risk, ~900 forks between them.

**Target: 15.7s → ~7s.** Confidence high (≥85%) that P1+P2+P4+P5 alone reach ≤11s — they are
mechanical and the helpers exist. Moderate (~65%) for ≤7.5s, which needs the harness-generated
tail of 40-60 individual sites each with its own probe. The prior round of this campaign
reached 1582 forks, so the tail is demonstrably reachable; that it rotted back to 6553 is
the evidence that it will not stay there without Step 5's gate.

**Time it from inside the repo, and A/B with `git stash` or a `git worktree` — not a renamed
sibling.** `:1666`, `:1697` and `:4955` reference `validate-enforcement-map.sh` **by name**, so
a copy at `scripts/vem-before.sh` reads the canonical file for I35/I52 and is not excluded from
I91's scan, producing spurious findings. A copy run from `/tmp` resolves its root elsewhere and
exits in 5 ms, which reads as an enormous speed-up and is a broken measurement.

### Step 8 — copy and clone eliminations

**Hoist `$PRISTINE` in `enforcement-map-derivations`.** `seed_tree()` (`:63-66`) is called from
`--run-one` only, so every one of ~35 workers builds its own 7.5 MB / 493-file pristine tree,
and `fresh()` (`:73-77`) then copies it again per assertion — ~70 tree copies per run.
`$PRISTINE` is **read-only in every worker**. Build it once in the parent above the `xargs` at
`:601`. **The one real bug this can introduce**: the worker's `trap 'rm -rf "$PRISTINE" …' EXIT`
at `:550-551` must drop `$PRISTINE`, or the first worker to finish deletes the tree the other
34 are reading. Control that makes read-only a fact rather than a claim: `touch` a stamp before
the pool and require `find "$PRISTINE" -newer stamp -print -quit` to be empty after — then
invert it once, having a throwaway worker touch a file there, and confirm the check goes red.

**APFS clone the tree copies.** Verified on this box: `/bin/cp` supports `-c` (`clonefile(2)`)
and `$TMPDIR` and the repo are on the same APFS volume, so a copy-on-write clone is legal and
effectively free for 493 files. `cp -Rc "$SRC" "$DST" || { rm -rf "$DST"; cp -R "$SRC" "$DST"; }`
— **the fallback is mandatory and so is the `rm -rf` before it**: `core/fixtures/` is installed
into consumer trees, GNU `cp` has no `-c`, macOS `cp -c` fails rather than degrading across
volumes, and a partial clone is a fixture that mutates something that was never there. Control:
force the fallback and require byte-identical fixture stdout. **Measure
`time bash core/fixtures/enforcement-map-derivations/seed.sh` first** — one number decides
whether this is worth doing at all.

**`self-update-join-gate`'s seed.** Three changes, in order of certainty:

- **Parallelise the two `install_at` calls** (`:67-68`). Independent by construction: distinct
  `src="$WORK/src-${ref:0:8}"`, distinct `dest`, shared read-only `$DIST`. Capture each PID and
  `wait` on it individually — a naked `wait` loses the codes and turns a broken install into a
  green seed. Control: point BASE at a bogus ref and confirm the fixture still reports
  `FIXTURE ERROR: install at BASE failed` and exits 2.
- **Drop `--no-hardlinks`** (`:29`, `:58`). The comment at `:26-28` justifies "a clone, never
  the live repo" on **isolation** grounds and says nothing about hardlinks; `--no-hardlinks`
  forces a byte copy of an 11.54 MiB pack three times. Hardlinking is safe because git objects
  are immutable and content-addressed — `gc`/`repack` write new files and unlink old ones, and
  unlinking one hardlink does not disturb the other. **`--shared`/`--reference` is the unsafe
  option** (it uses `objects/info/alternates`, and a prune in the source breaks the clone) —
  say so in the diff so the next reader does not "improve" it. Control: `git fsck` clean and
  byte-identical fixture output.
- **Replace the two clone+checkout pairs with `git worktree add --detach`** — no objects copied
  at all. **`git archive | tar -x` is NOT a substitute**: `install.sh:19-21` runs
  `git rev-parse --short HEAD` and `git diff-index --quiet HEAD` to stamp `AI_DLC_COMMIT`, and
  an archive has no `.git`, so the installed consumer would silently differ from the one the
  gate reads. Control: `AI_DLC_COMMIT` non-empty and correct in both installed consumers.
- **The pickaxe** at `:36-37`: add `-n 1` so git stops itself rather than relying on SIGPIPE,
  and drop `--pickaxe-regex` — the needle contains no metacharacters, so plain `-S` does a
  cheaper literal diff-count. Measure first; under a second, leave it. The derivation must not
  become a hardcoded ref — `:32-34` says why and `:45-54` proves the range is non-vacuous.

### Step 9 — re-derive `AI_DLC_FIXTURE_JOBS` and the nine inner widths, together, LAST

Two comments in the tree already ask for this, and one names this exact trigger:
`enforcement-map-sites/run.sh:1814-1817` ("a knob here multiplies against a knob there and the
product is what lands on the machine") and `layer-contract-conformance/run.sh:519-526`
("Re-derive both numbers together if the critical path moves off `enforcement-map-sites`" — it
has). Sequence it last: sweeping widths against today's pole set answers a question Steps 2-5
delete.

**Design.** Response variable: suite makespan, one number per run, plus **red-rate as a second
response variable** — `.githooks/pre-push:145-150` records an intermittent-red class that
correlates with concurrency, and a cell that wins 8% while turning one assertion intermittent
is a loss. Vary two factors, not nine: `AI_DLC_FIXTURE_JOBS ∈ {8,12,16,20,24}` and a single
**scale** applied to all nine inner widths at once ∈ {0.5×, 1×, 1.5×}. Nine independent widths
is 3⁹ and is not an experiment.

Hold constant: `AI_DLC_FIXTURE_NO_SKIP=1` on every cell (without it the dispatched set varies
run to run and the makespans are not comparable); same commit, clean tree; **reset
`.git/ai-dlc-fixture-durations` from one golden copy before every run**, or cell *N* is a
function of cell *N-1*; idle box; fixed cooldown against thermal drift.

≥4 repetitions per cell, **interleaved against the incumbent** (16 / 1×), never blocked. Call a
difference real only when the two cells' reading ranges do not overlap — the standard already
applied at `.githooks/pre-push:439-441`.

Controls that make it a measurement rather than a ritual: `JOBS=1` must give a makespan equal
to the sum of the durations record, or the harness is not measuring the pool; `JOBS=64` must
get worse or stop improving, because flat from 8 to 64 means the response variable is dominated
by something outside the pool and every other cell is uninterpretable; and the incumbent must
be able to win, which is what makes "leave the constant alone" a reachable answer.

**Varying the inner widths has a trap.** You cannot add an `AI_DLC_*` knob — `enforcement-map-sites`
scrubs every ambient `AI_DLC_*` name for I10, so it would be unset before it was read, and I87
binds any key a shipped program dereferences. Either `sed` the constants on a throwaway branch
that is never pushed, or use a non-`AI_DLC_`-prefixed name that survives the scrub — and in
either case it must not ship, because a tunable with no measured default is exactly what this
repo's gate expires.

**Deliverable regardless of the answer:** rewrite `.githooks/pre-push:133-158` and its
consumer-facing twin. Its load-bearing sentence — "the suite is latency-bound, not
compute-bound" — was measured on 83 fixtures at 72s and is contradicted by every reading in
this plan. Leaving it beside a re-derived constant is how the next reader inherits a premise
nobody holds.

---

---

## Ordered execution

| # | change | parallelism | est. effect | risk |
|---|---|---|---|---|
| 1 | durations record merges instead of replacing | one agent, both hooks | protects 13-33% of makespan already being lost after selective runs | low |
| 2 | shard `enforcement-map-derivations` 2 ways | agent A, worktree | finer granularity on 452s | low |
| 3 | shard `layer-contract-conformance` 2 ways | agent B, worktree | finer granularity on 434s; 3 hand-lists to update | **medium** |
| 4 | `self-update-join-gate`: measure the seed, parallelise `install_at`, drop `--no-hardlinks`, worktrees | agent C, worktree | 506s → ~380-400s | low-med |
| 5 | `scripts/fork-profile.sh` + `FORK_BUDGET` gate fixture | one agent | 0s; enabling and protective — land it **before** the campaign so its gains are locked | none |
| 6 | hoist the ~15 cross-arm names + `norm_core_manifest`, then `--arms` | parent does the hoist; one agent per dependency family | **~2150s → ~150s of suite work** | high, mitigated by `set -u` and the 48 existing mutants |
| 7 | fork campaign P1-P5 then the harness tail | one agent per pattern, then batches of ~10 sites | 15.7s → ~7s ⇒ ~1200 pool-seconds | low each |
| 8 | `$PRISTINE` hoist, `cp -Rc`, seed clones | folded into agents A and C | 20-40s on each of four heavy units | low |
| 9 | re-derive outer + inner pool widths | one agent, backgrounded | replaces an expired 83-fixture measurement | none |

Steps 1-4 and 5 can all be in flight at once. 6 and 7 both edit
`scripts/validate-enforcement-map.sh` — sequence them, or give one agent the file.

**What "done" looks like.** Today: makespan **506s**, total CPU work **4983 CPU-seconds**,
scheduling ceiling **277s**, validator 15.7s × 137 ≈ 2466 CPU-s ≈ 49% of the whole.

Steps 1-4 and 8-9 attack the 45% gap between 506s and 277s. Steps 5-7 attack the 4983 itself:
removing ~2300 CPU-seconds takes the ceiling to roughly **150s**. Those are the only two
things that move, and they are independent.

**Do not carry any of those figures forward as a claim.** Re-derive after each step: the
makespan from `.git/ai-dlc-fixture-durations` watching the **top**, not the sum; the CPU work
by re-running the solo census. A recorded cost is a LOADED cost and never comparable with a
solo one.

## Verification

Every step above carries its own control; these are the whole-program ones.

**Baseline, taken before anything changes and again after each step:**

```
cp .git/ai-dlc-fixture-durations /tmp/durations.golden      # the reset source for Step 9
AI_DLC_FIXTURE_NO_SKIP=1 bash .githooks/pre-push            # the gate, run the way it runs
```

**Step 0, before any of it: promote this file.** It is a handoff, it currently lives at
`~/.claude/plans/`, and nothing there is version-controlled or validated. Copy it to
`docs/plans/<slug>.md`, run `bash scripts/validate-plan-shape.sh`, and commit — the validator's
corpus is `docs/plans/*.md` only, so its clean run today says nothing about this file.

Read the changed fixtures **by name** in the full output. `core/git-hooks/pre-push` is the
CONSUMER's hook — run here it prints a green banner having executed almost nothing — and the
content-key skip prints a green banner too. Neither is evidence that anything was exercised.

**Standing checks that must stay green throughout:**

```
bash scripts/validate-enforcement-map.sh          # I5, I8, I20, I33, I66, I74 all live here
bash scripts/render-invariant-index.sh --check
bash scripts/validate-claude-rules.sh
bash core/fixtures/suite-dispatch-order/run.sh
bash core/fixtures/fixture-drivability/run.sh
```

**The I66 negative control, which must be run rather than assumed:** apply a pool-region change
to `.githooks/pre-push` only, run the validator, confirm it prints the I66 fork error naming
the mapped diff, then apply the same text to `core/git-hooks/pre-push` and confirm it goes
silent. A join asserted and never demonstrated reads exactly like one that cannot fire.

**Consumer side.** Steps 3, 8 and 9 touch shipped artifacts — a shipped shard directory, a
`cp -c` that Linux `cp` does not have, and the consumer hook's own prose. Build a tree with
`scripts/install.sh` into an empty directory and run the suite there in both layouts; a path
that resolves in this tree can resolve nowhere in an installed one.

## Critical files

- `.githooks/pre-push` — `:172-566` fenced pool region; merge at `:517-518`; expired width
  justification at `:133-158`
- `core/git-hooks/pre-push` — the I66 twin; every pool-region edit lands here identically
- `core/fixtures/enforcement-map-sites/run.sh:1717-1838` — the shard pattern to copy
- `core/fixtures/enforcement-map-sites-b/` — the wrapper + `.dist-only` shape to copy
- `core/fixtures/enforcement-map-derivations/run.sh` — Step 2
- `core/fixtures/layer-contract-conformance/run.sh:80-97, 504-539, 589-596` — Step 3, the hard one
- `core/fixtures/self-update-join-gate/seed.sh:29-68` — Step 4
- `scripts/validate-enforcement-map.sh` — Steps 5-7. `set -u` at `:155`, `REPO_ROOT` at `:157`,
  the stale 1582-fork budget at `:173-177`, `in_lines`/`in_body` at `:192-215`, `lc_file` at
  `:599`, I65's per-enforcer tree walk at `:1166-1177`, `i87_readable` at `:5620-5626`
- `scripts/render-invariant-index.sh:76-148` — `EXTRACT_AWK`, **the only correct arm grammar**
  (96 header-shaped lines against a column-0 grep's 83), and the self-probe posture to copy
- `core/fixtures/suite-dispatch-order/run.sh` — where Step 1 is proven and its mutant lives
