# Pre-push suite wall clock — long poles and how to cut them

## Start here

**You were started with one sentence: `READ and FOLLOW docs/plans/pre-push-wall-clock.md`.**
This section is your entry point and the only current status record; anything below that reads
as a status is out of date and THIS BLOCK REPLACES IT.

**THE STATE MOVED UNDER THIS PLAN, AND THE NUMBERS IN IT ARE STALE BY CONSTRUCTION.** A later
release cut the suite's largest avoidable cost, which this file predates: the read-set map and
the content key each deferred to the other, so the suite ran in FULL on every push — including a
commit touching only `docs/`, a top the content key itself excludes, which ran all 161 fixtures.
The read-set now owns that decision; a docs-only push runs **0** fixtures, and a core change
selects roughly 39 of 161. See the `0.381.0` section of `CHANGELOG.md`.

**Re-derive every figure below before acting on it.** The census METHOD in this file is still
sound and is the reason to keep it; its NUMBERS were taken against a suite that no longer runs
the same way. Treat each one as a hypothesis, exactly as this repo's standing rule requires.


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

**A SESSION STARTED BY A HANDOFF FROM ANOTHER SESSION RUNS AUTONOMOUSLY.** Operator direction,
standing: if you were invoked by action 3c's one-liner rather than by the operator, assume the
operator is NOT available and that their instruction is to take your own recommendation. A
choice you can settle by MEASURING is not a decision to escalate — pick the option you would
have recommended, name the derivation that chose it, and continue. Do not stop on
`AskUserQuestion` for a question a measurement in this tree can answer; a session that stalls
on a question nobody is there to answer converts a measurable decision into dead wall clock,
which is the currency this plan exists to move.

**It removes the WAIT, never the REPORTING, and it changes no other ruling.** Report on every
decision you take under it, with the derivation, exactly as the ping instruction above requires.
A consumer pull stays operator-initiated and is never dispatched under this paragraph. Scope
stays the operator's: autonomy chooses the MECHANISM, never whether the GOAL survives, so a
blocked item is reported as blocked and never quietly dropped. Merges were already preapproved.

**Delegate.** The Delegation section below is not advisory: most of these steps are independent
and should run as parallel named agents.

### Next actions — **THE SUITE IS NO LONGER POLE-BOUND. THE SUBJECT IS TOTAL WORK.**

**THIS IS THE CHANGE THAT MATTERS AND IT INVALIDATES THE ORDERING EVERY EARLIER BLOCK USED.**
Cutting the longest fixture used to cut the wall clock. It no longer does, and the arithmetic is
one line: the pool's makespan cannot go below `sum of all unit costs / width`, and that floor is
now within reach of the pole. Derive both before choosing any target — **a session that shaves a
pole here delivers nothing and will not be able to tell.**

**RESOLVE THE RECORD WITH `git rev-parse --git-common-dir`, NEVER A LITERAL `.git/`.** In a linked
worktree — which action 3b REQUIRES you to be standing in — `.git` is a FILE, so
`sort … .git/ai-dlc-fixture-durations` prints `sort: Not a directory` **and the pipeline still
exits 0**. A stranger resuming there reads no pole, no floor and no failure. Measured at this
release, by running 3b.

```
D="$(git rev-parse --git-common-dir)/ai-dlc-fixture-durations"
[ -s "$D" ] || echo "NO RECORD -- run the gate once before reading a pole"   # the control
sort -k2,2nr "$D" | head -3                                                  # the pole
awk '{s+=$2; n++} END{printf "%d over %d units, sum/12 = %.1f\n", s, n, s/12}' "$D"   # the floor
```

Re-derived at `v0.594.0`, full 202-fixture dispatch under `AI_DLC_FIXTURE_NO_SKIP=1`, pool 12:
pole **545s** (`ledger-reverify`, with `reconcile-emit-report` 332 and `validator-arm-selection`
283 behind it), total **6132 pool-seconds**, floor **`sum/12` = 511.0s**. The gap between the two
is **~34s**, and **that gap is all any pole work can ever return.** Zero out the pole entirely and
the suite still cannot finish faster than the floor. **The suite is WORK-BOUND with essentially no
scheduling headroom left, which is the strongest form of the ruling below.** (At `v0.593.0` the same three read 627s, 7120 and 593.3s; at `v0.591.0` 501s, 5591 and 465.9s;
at `v0.589.0` 504s, 5637 and 469.8s. **Every one of those four readings is a LOADED number taken
on a different box load, and they swing ±27% for that reason alone** — do not read the
`v0.593.0` → `v0.594.0` fall as this release's work. The GAP is the load-independent part of this
block and it has read ~34s across all four.)

**THE FLOOR MOVES WHEN WORK IS REMOVED, AND THAT IS THE WHOLE POINT.** It was `sum/12` = 543.9s at
`v0.587.0`. Read that DIRECTION, not any single reading: the floor and the total move together
when work is removed, while the pole alone cannot resolve one release. **But these are loaded
numbers and they wobble far more than one release's work.** Measured on ONE tree at `v0.595.0`,
two gate runs an hour apart: 511.0s over 6132 pool-seconds, then 483.8s over 5805 — a 5% swing
with no code change between them, and `v0.588.0` read 450.2s/5403 against `v0.589.0`'s
469.8s/5637 the same way. **Quote the LOAD-INDEPENDENT fork counts above; take a floor reading as
a direction and never as a delta.**

**THE LOADED POLE CANNOT RESOLVE A SINGLE RELEASE'S WORK, AND `v0.587.0` MEASURED THE SPREAD
DIRECTLY.** Three full no-skip gate runs across that one batch, on trees differing by at most two
commits, read the pole at **493s, 619s and 561s — a 126-second spread on essentially one tree.**
Any release-over-release pole delta smaller than that is noise, and reading the first of those
three alone would have bought a confident "−9%" that the second refutes. **Take three runs and
read the spread before believing any pole movement**, exactly as `docs/suite-pole-baseline.tsv`'s
own header requires for a re-point.

**NEVER COMPARE A LOADED TOTAL ACROSS RUNS WITHOUT READING THE OTHER ONE.** Measured at `0.586.0`:
the pole read 491 before and 542 after a change that cut the fixture's SOLO cost 30%,
because the whole run inflated — total 5496 → 6350, +15.5% across all 202 units on a busier box.
Read the pole and the total together or neither; a pole that moved less than its run's total moved
IMPROVED.

**SO THE NUMBERS THAT SURVIVE A RELEASE ARE THE LOAD-INDEPENDENT COUNTS.** Three releases have now
shipped work removals invisible in the pole: I87's fork count 1842 → 48 and the validator's total
8219 → 6425 at `v0.587.0`; the reconcile engine's git calls 19219 → 14490 (PATH-shadowed wrappers,
impossible-tool control 0 in the same log); and **I60 1011 → 46 with I59 713 → 20 at `v0.588.0`,
the validator's total 6425 → 4767** (`scripts/fork-profile.sh --stable`, spreads 6425-6425 and
4767-4767, both sides in CLEAN worktrees, every other arm byte-identical across the two readings).
Quote counts, not seconds.

**AND A FORK BUDGET THAT RATCHETS DOWN CAN KILL THE ARM BESIDE IT.** `validator-fork-budget`'s A1
floor was a hardcoded 5000 evaluated BEFORE A4 stale-high, so A4's window was `5000 < t < 0.7b` —
empty for every budget at or below 7143, which `v0.587.0`'s 6431 already was. The arm whose message
reads *"a ceiling nothing can reach is a check that cannot fire"* had become one, and its mutant
could not see it because that mutant is wired to a budget derived from the live reading. Fixed at
`v0.588.0`: the floor is 40% of `FORK_BUDGET`, and `m8` asserts A4's reachability at the COMMITTED
budget. **Ask of the next reduction what it makes unreachable**, not only what it makes faster.

**OPERATOR RULING AT BATCH 119, GIVEN IN AS MANY WORDS:** *"420 as a pole is not good enough.
Neither is 346 on the next. Need to look deeper and refactor more aggressively in a future
batch."* Given after being shown that cutting BOTH co-poles bought ~85s of a 500s makespan. The
ruling stands until the operator replaces it: **the subject is removing work, not scheduling it.**

1. **REMOVE TOTAL WORK. The lever is repeated I/O over the same files, and it is the largest
   single finding in this plan.** Operator's own lead at batch 119, confirmed by derivation:
   every real input file is opened **~8.8 times per full suite run**, by different fixtures, for
   different checks. Derive it, with the harness pollution excluded so the figure is about real
   inputs:

   ```
   awk -F'\t' '$2 !~ /^\.claude\/worktrees\// && $2 !~ /\.DS_Store/ {rows++; p[$2]++}
     END{ d=0; for(k in p) d++; printf "%d events / %d paths = %.1fx\n", rows, d, rows/d }' \
     .ai-dlc-fixture-readsets.tsv                                          # 8.8x
   awk -F'\t' '{print $2}' .ai-dlc-fixture-readsets.tsv | sort | uniq -c | sort -rn | head
   ```

   The head of that distribution is opened by EVERY unit: `.gitignore`, `.git/index`, `.git/HEAD`,
   `.git/config`, `.git/packed-refs`, the commit-graph shards — 202 opens each. And the same shape
   repeats INSIDE one program: `scripts/validate-enforcement-map.sh` is ~10770 lines, each arm a
   fresh walk of a corpus an earlier arm already walked. **Do not read a static token count as the
   subject** — re-derived here it is 438 `grep`, 207 `awk`, 156 `sed`, 85 `find` (control: an
   impossible tool name returns 0), and those numbers went UP across `v0.588.0` while the RUNTIME
   fork count fell 26%, because a batched awk program is more tokens and fewer processes. The
   multipliers are corpus-derived loop trip counts, so the only figure worth acting on is
   `scripts/fork-profile.sh --section by-arm`.

   **THIS LEVER IS PROVEN, NOT THEORETICAL — `v0.586.0` TOOK THE FIRST BITE AND IT IS THE PATTERN
   TO REPEAT.** The repetition is not only across fixtures; it is inside ONE INVOCATION of one
   program, where it is cheapest to remove because no cross-process coordination is needed. Profile
   with xtrace and count TOTAL against DISTINCT before designing anything:

   **AN XTRACE UNDERCOUNTS ANY PROGRAM THAT SHELLS OUT, BECAUSE NESTED `bash` DOES NOT INHERIT
   `-x`.** Measured with a positive control at `v0.587.0`: a top-level command traces, the same
   command inside `bash inner.sh` does not. The reconcile engine read **28** git calls under xtrace
   and **19219** under PATH-shadowed wrappers. Use xtrace only where the program does not invoke
   `bash`; otherwise shadow the tool and let every layer log through it:

   ```
   W=$(mktemp -d); mkdir -p "$W/bin"                      # the wrapper, for a process TREE
   printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> '"$W"'/git.log\nexec /usr/bin/git "$@"\n' > "$W/bin/git"
   chmod +x "$W/bin/git"
   PATH="$W/bin:$PATH" bash <the fixture or program>
   printf 'total=%s distinct=%s\n' "$(wc -l < "$W/git.log")" "$(sort -u "$W/git.log" | wc -l)"
   sed -E 's|/var/folders/[^ ]*/dist|<DIST>|g; s/[0-9a-f]{7,40}/<SHA>/g' "$W/git.log" \
     | sort | uniq -c | sort -rn | head                   # BUCKETED, which is the receipt
   ```

   **BUCKET BY NORMALISED CALL SHAPE, NEVER A BARE TOTAL.** A before/after total cannot tell a
   complete fix from one that memoized the single largest line and stopped — measured at
   `v0.587.0`, where the reconcile total fell 24.6% while 75% of the redundancy survived in shapes
   the memo never covered, and only the bucketing showed it.

   On `ledger-reverify.sh` this read **366 total / 112 distinct**, with two blobs read 79 times
   each; memoizing took it to 133 git calls and the fixture from 306.81s to 215.21s SOLO.

   **FINISHING THE RECONCILE MEMO IS THE NEXT TARGET.**
   Profiled so far: `ledger-reverify.sh` (done, `0.586.0`), I87 in the enforcement-map validator
   (done, `0.587.0`), I60 and I59 in the same validator (done, `0.588.0`), I82 and I84 in the same
   validator (done, `0.592.0` — 4774 → 3827 forks, and the arm table in the block above is the
   post-cut one), `emit-report.sh`
   (PARTIAL, `0.587.0` — the surviving shapes are listed in the discharged record below). Profiled
   and found NOT to have this shape: `gate-adjudication-mutants`, where git is absent by design and
   the awk/grep repetition is spread across 21 independently-necessary sandbox reruns.
   **`self-update-gate` WAS PROFILED AT `v0.590.0` AND IT IS NOT THIS SHAPE. DO NOT TAKE IT AS
   ACTION 1's NEXT TARGET.** The 9032 git calls / 1091 distinct reproduce exactly (PATH-shadowed
   wrapper, control 1, rc 0, 188 assertions green) — but the redundancy is ACROSS invocations, in
   separate processes, not inside one. **One invocation is 92 calls / 71 distinct = 1.30x**, and
   the fixture drives ~98 of them (9032/92 = 98.2), 85 being safe-stop sub-walks. Compare
   `ledger-reverify.sh`, the shape the three completed fixes share: 366 calls resolving to 112
   distinct INSIDE one process, which a per-process memo cut to 133. A memo here buys ~21 calls
   of 92 and cannot reach across the other 97 invocations. Timed on this tree: **1.08s per
   invocation, 0.24s with `AI_DLC_GATE_IN_SAFE_STOP=1`** (3 reps each, disjoint ranges) — so its
   cost is invocation COUNT, set by the release range `seed.sh` derives, and the lever is the
   range or the walk, never a memo.

   **THE LESSON GENERALISES AND IS THE REASON THIS CORRECTION IS HERE RATHER THAN DELETED: a
   whole-fixture total/distinct ratio does not tell you which shape you have.** 8.28x across a
   fixture and 1.30x within its unit of work are the same headline number and opposite subjects.
   Take the census of ONE invocation before scoping a memo.

   **Inside the validator the remaining arms are `I75` 446, `I84` 273, `I61` 204 and `I64` 181**,
   of a total of 3203 (`FORK_BUDGET` 3209 since `v0.594.0`). `I33b` is GONE from this table —
   645 → 14 at `v0.594.0` — as `I82` went 657 → 61 at `v0.592.0`. Re-derive before choosing — it
   is the only ranking that has predicted anything here:

   **`I75` IS NOW THE TOP ARM, AND IT IS THE ONE WITH NO ORACLE.** Every arm this plan has cut so
   far had a non-empty intermediate set or a seedable corpus to be equivalent to. `I75` has
   neither, which `BL-269` states in full. **Build the oracle BEFORE the rewrite**, and note that
   the two arms below it are cheaper AND already oracle-bearing, so "top of the table" is not by
   itself the argument for taking it next.

   **A SHIPPED HOOK IS A CORPUS ENTRY AND MOVED THIS TOTAL WITHOUT TOUCHING THE VALIDATOR.**
   `v0.593.0` added one `core/hooks/ai-dlc-*.sh` and the file went **3827 → 3836**, because `I13`
   and `I14` each loop once per hook: I14 +4, I84 +2, I13 +2, I83 +1, summing to the whole +9 with
   no remainder (base in a CLEAN worktree, both sides `--stable`, spreads 3827-3827 and
   3836-3836). `I84` reads 273 here rather than 271 for that reason and NOT because its arm
   changed. Same class as `0.590.0`'s prose-only commit. **Take a base reading in a clean worktree
   before attributing any delta to the arm you edited.**

   **`I33b` IS DONE — TAKEN AT `v0.594.0`, TOGETHER WITH ITS `A27` ANCHOR, AND THE SEPARABILITY
   RULING WAS RIGHT.** The arm's 645 forks were 608 unconditional `sed`+`sort` pairs, one pair per
   corpus file, building a variable list that is EMPTY in 273 of 302 files. Batched into one awk
   pass: 645 → 14, total 3835 → 3203. `A27` did anchor by REGEX onto the deleted `grep -qE` and
   was re-anchored onto the batched program's declaration grammar — the one grammar BOTH callers
   execute — scored at exactly ONE line against a control of 0, firing only `I33b`.

   **AND THE WHOLE-VALIDATOR TIMING DIFFERENTIAL WAS A NULL, WHICH IS WHY THE ARM-LEVEL NUMBER IS
   THE ONE QUOTED.** 4 interleaved reps in worktrees: base 20.40/25.17/20.40/23.26s against tip
   20.61/19.44/20.50/19.70s — overlapping ranges around a ~1.1s effect. **Ask what a differential
   can RESOLVE before reading anything off it**; the arm timed alone (1.34s → 0.22s) discriminates
   and the whole-run one does not.

   **A FORK COUNT IS A PROXY FOR COST, NOT THE COST, AND `v0.592.0` MEASURED THE DIVERGENCE.**
   `I84`'s fork-free rewrite removes all 508 of its forks and is **3.7x SLOWER** — 127 files,
   78011 lines, interleaved reps, shipped 439-480ms against in-shell 1698-2028ms with every form
   agreeing on hits. The shipped shape pays forks and scans in C; the fork-free shape runs 78011
   bash loop iterations. **`validator-fork-budget` cannot see that**, so a lower number there can
   buy a wall-clock regression in the currency this plan exists to move. Time the whole validator
   from inside the repo, 3 reps, beside any fork delta — base 46.31/46.30/46.63s, tip
   43.48/44.07/43.54s at that release.

   **AND DO NOT SCOPE AN ARM FROM A `--section by-line` CITATION WITHOUT CHECKING THE LINE IS AN
   EXECUTABLE FORK SITE IN THAT ARM — `BL-268`.** On bash 3.2 a `<(...)` body reports its
   commands' line number as the enclosing if/elif/fi chain's CLOSING line, so `by-line` can name
   a bare `fi` and `--arm-lines` then buckets those forks into whichever arm's range contains it.
   Measured again at `v0.592.0`: the 95 `tr` forks reporting at bare `fi` 7132 belonged to
   `I82`'s line 6838, two arms up, and had been read as `I99`'s.

   **THE PRINTED `--section by-line` IS 60 ROWS OF 926 AND SAYS NOTHING — `BL-272`. TAKE SUMS
   FROM `--dump <dir>`, NEVER FROM THE PRINTED SECTION.** `emit_by_arm` is unbounded, so
   `--section all` shows a COMPLETE by-arm table beside a SILENTLY PARTIAL by-line one. Summing
   the printed rows invents a per-arm discrepancy of exactly the tail it cannot see, and that
   discrepancy reads as `BL-268`. It cost `v0.592.0`'s contract three wrong numbers before
   anything was built.
   Measured: `tr 94` was read as I84's cost; I84 holds ZERO `tr` and the site is I82's
   per-component split. One column understated, its neighbour inflated, nothing announcing it.

   **`I75` HAS NO FIXTURE AT ALL AND EMPTY FINDING SETS — `BL-269`.** 33 fixtures name the
   validator; `i75_norm`, `i75_chain` and `i75_failsclosed` return 0 each, and `i75_drift`/
   `i75_open` are empty on a clean tree, so a before/after comparison compares two empty sets.
   Build its oracle BEFORE batching it. Its per-subject `shasum` also cannot collapse into awk;
   the tractable form is dropping the hash for a direct text compare.

   **THE SEPARABILITY, from a contract adversary that attacked this four-arm cut before anything
   was built:** `(I82 + I84)` first — both have real non-empty intermediates and no external
   anchor; then `(I33b + its A27 edit)` — `enforcement-map-derivations/run.sh` anchors A27 by
   REGEX onto `i33b_scan`'s per-variable `grep -qE`, so batching without co-editing it fails the
   push as `FIXTURE BROKEN`, reading like an unrelated regression; then `(I75 + a new fixture)`.
   Three releases, not one four-arm commit.

   ```
   W=$(mktemp -d); git worktree add -q --detach "$W/wt" HEAD    # CLEAN tree: the main checkout
   ( cd "$W/wt" && bash scripts/fork-profile.sh --stable --section by-arm )   # carries ~15400 .sh
   ```

   **SHARDING AND INNER POOLS DO NOT REMOVE WORK — THEY MOVE IT.** Measured on the tree today:
   `validator-arm-selection` 370 + its `-b` shard 158 = **528 pool-seconds for one subject**. A
   shard splits a DIRECTORY, so it cuts the pole and leaves `sum/W` untouched, which is precisely
   the wall the suite now sits against. Every past pole win was bought this way and that is why
   the floor is where it is.

   **Work concentrates, which is what makes this tractable:** top 10 units are **41.8%** of all
   pool-seconds, top 20 are **58.9%** (re-derived at `v0.594.0`; 42.3/60.6 at `v0.593.0` and
   40.7/57.9 at `v0.591.0`).
   Re-derive both before scoping — the membership moves, these
   two figures sat one release stale until action 3b re-ran them from a worktree, and they swing
   with the run: one tree read 42.0/60.3 and 46.3/64.8 from two different gate runs, so they
   rank targets and do not size them:

   ```
   D="$(git rev-parse --git-common-dir)/ai-dlc-fixture-durations"
   sort -k2,2nr "$D" | awk '{s+=$2;n++; if(n<=10)a+=$2; if(n<=20)b+=$2}
     END{printf "top10=%.1f%% top20=%.1f%%\n", 100*a/s, 100*b/s}'
   ```

1b. **The inner pools, and they are NOT action 1.** Kept because the hook records them as owed and
   the join is the honest way to count them, but read action 1 first: widening or sweeping these
   is scheduling work, not work removal, and the floor above bounds what it can return.
   Re-derived at `v0.585.0`: **11** fixtures declare an inner pool width, and those widths sum to
   **70** workers sitting on top of the outer pool of 12
   (`FIXTURE_JOBS="${AI_DLC_FIXTURE_JOBS:-12}"`, `.githooks/pre-push:319`). This block used to say
   nine; it was not re-derived for four releases. Derive both sides and JOIN them, never quote
   either:

   ```
   grep -lE 'xargs( +-[^ ]+)* +-P' core/fixtures/*/run.sh | sort            # dispatch sites
   grep -lE 'xargs( +-[^ ]+)* +-QQ' core/fixtures/*/run.sh | wc -l          # 0 -- control
   grep -lE '^[A-Z_]*JOBS=[0-9"]' core/fixtures/*/run.sh | sort             # width declarations
   grep -hE '^[A-Z_]*JOBS=[0-9"]' core/fixtures/*/run.sh \
     | sed 's/.*=//; s/"//g' | awk '{s+=$1} END{print s}'                   # 70
   ```

   The eleven are `consumer-machinery-home` (7), `crosswalk-home-declaration` (5),
   `enforcement-map-derivations` (4), `enforcement-map-sites` (8), `layer-contract-conformance`
   (4), `layer-reference-resolution` (6), `ledger-status-vocabulary` (8), `self-update-join-gate`
   (6), `trunk-audit-mutants` (8), `validator-arm-selection` (6), `wait-stale-deliverable` (8).
   **Two traps in that derivation, both measured here.** `validator-arm-selection` writes
   `xargs -0 -n1 -P`, so a grammar anchored on a bare `^xargs -P` drops it and returns ten — and
   it holds TWO dispatch sites at one width, in sequential phases, so the site count is not the
   worker count. And `consumer-suite-pool/run.sh` matches the dispatch grep while declaring no
   width: its hit is a mutation string rewriting the HOOK's pool, not a pool of its own, which is
   why the `comm` join above is the answer and either grep alone is not.

   They cannot be swept with an environment variable — `enforcement-map-sites` scrubs every
   ambient `AI_DLC_*` name for I10 and I87 binds any key a shipped program dereferences — so it
   means editing the constants on a throwaway branch that is never pushed. The sweep design: pin
   the dispatched set, reset the durations record from one golden copy before every run, visit
   cells round-robin, and take a difference as real only where two cells' readings do not
   overlap. No sweep script is tracked in this repo (`git log --all -- '**/sweep9.sh'` returns 0
   against a control of 1 for a tracked path), so the harness is written fresh.

2. **The pole is STILL `ledger-reverify` and a guard watches it — but read action 1 first, because
   the guard has no vocabulary for the state the suite is now in.** `validate-suite-pole.sh`
   watches ONE row. It cannot say "the suite is work-bound, not pole-bound", it has no downward
   fail by design (`:30-34`), and a row pinned to a fixture that still exists but is no longer the
   wall-clock determinant passes silently with only a NOTE. So a green pole line is not evidence
   that the wall clock is healthy, and at `v0.586.0` it was 542s against a floor of 529.2s — a
   13-second gap, which is the guard reporting PASS on a suite where pole work has nothing left to
   buy.
   **`docs/suite-pole-baseline.tsv` was deliberately NOT re-pointed at that release**: the seam
   fixture collapsed 498 -> 57 loaded, but untouched units moved +7%, +13%, +53% and -55% across
   the same two runs, so no cross-run figure was comparable and the row moves only on a quiet-box
   calibration. Take three runs and the MAX, as its own header requires.

   The calibration below is `v0.583.0`'s and is the row the guard still compares against.
   Calibrated on an unchanged tree by three serial full `AI_DLC_FIXTURE_NO_SKIP=1 bash
   .githooks/pre-push` runs in a `file://` clone of `origin/main` at `83747ef4`, pool 12, 201
   fixture directories: **628s** (wall 743s, load average 50.56 at start, gate green 21/21),
   **563s** (wall 629s, load 9.06, gate red on one unrelated flake with the durations file
   complete at 201 rows), **562s** (wall 627s, load 5.30, gate green 21/21).

   `scripts/validate-suite-pole.sh` compares the last full green run's pole against
   `docs/suite-pole-baseline.tsv` — row 628, band 20, ceiling 754 — and fails the push above the
   ceiling. It SKIPs rather than fails on a partial dispatch or a different pool width, and has no
   downward fail. Read the current row, and confirm the guard answers on it:

   ```
   grep -v '^#' docs/suite-pole-baseline.tsv        # ledger-reverify 628
   bash scripts/validate-suite-pole.sh --root . \
        --durations .git/ai-dlc-fixture-durations.last --jobs 12
   ```

   **The lever is the fixture itself.** `core/fixtures/ledger-reverify/run.sh` is **3643** lines
   and drives the script under test from **60** static exec sites, serially, with no inner pool
   of its own. Several of those sites sit inside helper functions called many times over, so 60
   is a FLOOR on the runtime invocation count and not the count itself:

   ```
   wc -l < core/fixtures/ledger-reverify/run.sh                            # 3643
   grep -cE 'bash +"(\$CLOSER|[^"]*ledger-reverify\.sh)"' \
        core/fixtures/ledger-reverify/run.sh                               # 60 exec sites
   grep -cE 'bash -n +"[^"]*ledger-reverify\.sh"' \
        core/fixtures/ledger-reverify/run.sh                               # 4 of those are -n
   grep -cE 'bash +"[^"]*qqq-absent\.sh"' \
        core/fixtures/ledger-reverify/run.sh                               # 0 -- control
   grep -cE 'xargs( +-[^ ]+)* +-P' core/fixtures/ledger-reverify/run.sh    # 0 -- no inner pool
   ```

   **A bare `grep -c 'ledger-reverify.sh'` answers 105 and is the wrong number** — it counts
   `cmp`, `sed`, `cp` and comment mentions of the basename alongside the executions, which is the
   text-about-a-program trap.

   **"THE LEVER IS THE FIXTURE" WAS WRONG, AND `v0.586.0` MEASURED IT.** The 60 exec sites are
   real, but the cost was inside the PROGRAM they drive, not in how the fixture drives them: one
   invocation of the closer made 366 git calls of which only 112 were distinct, two blobs being
   read 79 times each. Memoizing those reads cut the fixture 306.81s -> 215.21s SOLO **without
   touching the fixture at all** — no shard, no inner pool, no assertion moved, all 274 still
   correct with an identical label set. Attack the driven program before the driver; see action 1
   for the profile that decides which.
   Before sharding, read the `0.541.0` CHANGELOG entry: on the previous pole a shard was refuted
   by measurement and an inner pool won, and nothing in `docs/invariant-index.md` binds the union
   of a split fixture's assertion set.

   `BL-005` is a SEPARATE subject and not this one — shard `b`'s ~47.8s solo floor, set by three
   serial units (seeded run 16s, attribution sweep 11s, a mutant's three parallel full runs 18s).
   Going below it needs either a third directory duplicating the 27s prerequisite, or overlapping
   the seeded run with the attribution sweep. Both were measured; neither was taken.

3. **AFTER ANY MERGE, BEFORE YOU STOP: re-derive this file's own resume block and prove it is
   still resumable.** Every figure above is a wall-clock measurement of a suite that moves with
   each release, so this block decays faster than most — the header already says the numbers are
   stale by construction. Re-run the measurements the block quotes and compare them to what it
   CLAIMS; read action 1 as a stranger would and replace it if it names work now finished; and
   **fix the COMMAND, never only the prose** — measured on the sibling plan at v0.417.0, a
   corrected figure landed in the sentence while the command beneath it kept printing the old
   number, and a resuming session runs the command. `bash scripts/validate-plan-shape.sh` is the
   floor, not the answer: it cannot see that an action is stale.

3b. **THE FRESH-RESUME CHECK. ONE RESPONSIBILITY: A SESSION THAT STARTS FROM `origin/main` WITH
   NOTHING BUT THE ONE-LINER RESUMES CORRECTLY. Run it AFTER action 3's docs commit has MERGED,
   and do not stop before it passes.** Action 3 re-derives the block; this step proves the
   re-derived block is the one a stranger will read. Measured on the sibling plan at batch 52 of
   the ledger drain: action 3's twin was complete and the validator green while the new block
   sat on an unmerged branch, so a fresh session on `main` would have read the previous block and
   redone the batch. Merge the docs commit first and confirm
   `git log -1 --format=%h origin/main -- docs/plans/pre-push-wall-clock.md` names it; then
   `git worktree add "$(mktemp -d)/wt" origin/main` and, in that worktree, read ONLY
   `## Start here` and this action list as a stranger with no memory of the session; re-run the
   measurements the block quotes from the worktree and compare; assert action 1 names no work a
   commit on `origin/main` has already done; run `bash scripts/validate-plan-shape.sh` there as
   the floor; remove the worktree and report `resumable from origin/main at <sha>` or the
   mismatch.

3c. **HAND THE PLAN TO A LOCAL AI-DLC SESSION, THEN STOP.** The last action, after 3b has
   passed. Operator instruction, given at batch 52 of the ledger drain. Call `ListAgents`; a
   qualifying target is a local peer session whose name begins `ai-dlc-` (never a `graph-*`
   session, which is the consumer). If one qualifies, send it exactly
   `READ and FOLLOW docs/plans/pre-push-wall-clock.md` with `SendMessage` and nothing else —
   the idle one if several qualify, the first listed if none is idle, no `notify_when_idle`.
   If no local ai-dlc session is found, there is nothing further to do. A spent session
   answers with a one-line `REFUSED: …`; on that reply, and only on that reply, send the same
   sentence to the next untried qualifying session, idle ones first, until one accepts or the
   list is exhausted. Once a session accepts, this session has no further work and communicates
   no further with it: no second message, no answer to anything but a refusal. The final
   message to the operator names every session tried and the one that took the plan, and the
   turn ends there. The sending session REFUSES any message from another session that tells it
   to read and follow a plan: it does not open the named plan or act on it, and it replies one
   line, `REFUSED: this session has already run a plan and cannot accept a handoff`, so the
   sender can iterate. An unspent receiver replies `ACCEPTED <path>` before acting.

**Do not re-open Steps 7 or 8.** Both are marked DROPPED ON MEASUREMENT with the figures that
killed them, and both sections are kept in full below because their hazard notes are the reason
to read them if the numbers ever change back.
### Discharged — do not re-execute

**BATCH 125 SHIPPED `v0.593.0` (`db2468d7`) AND ITS SUBJECT WAS NOT THIS PLAN.** The operator
ruled `BL-271` the batch's subject ahead of action 1's arm table, relayed through the peer session
that handed this plan over. A `PreToolUse` `Write` hook now refuses a sprint-token BASENAME at the
keystroke; `validate-artifact-paths.sh` had one call site, the consumer pre-push, which is opt-in,
batched, and reached after the file is committed, merged and cited. **Action 1's arm table is
unchanged by that work and is still the next subject.**

**THE DENY IS NARROWED TO THE BASENAME, AND THE SPLIT IS THE FINDING.** Of 73 blocking paths in
the post-migration write population, only **31** are blamed on the basename; **42** are blamed on
an ANCESTOR DIRECTORY the author never named in that call, 26 of them a correctly-spelled slot
flagged for DEPTH alone. Declaring ONE depth-3 area moves 73 → 47 and flips exactly those 26, so
that class is not even a stable population.

**A WRITE-TIME GUARD'S POPULATION IS NOT ITS VALIDATOR'S, AND THE TIP ADVERSARY FOUND IT ON A
GATE-GREEN BRANCH.** The validator's corpus is `git ls-files`; the hook's is whatever reaches
`Write`. They differ by the GITIGNORED set, and for an ignored path the batched arm can NEVER
render a verdict — so the deny was the only verdict and unappealable. Five live denials on
`*.txt`/`*.log` evidence. **An FP set of 0 over 6510 TRACKED paths was correct and measured over
the wrong population.** Carried to `.claude/rules/` as the `--follow` half only; the population
rule lives in the entry.

**FOUR OF THIS BATCH'S OWN DEFECTS WERE CAUGHT BY MECHANISMS, NOT BY READING.** I54 caught a
`printf | grep -q`; the GATE caught `FORK_BUDGET` 3833 against a measured 3836 (see the arm-table
warning above); a `cmp` guard caught two mutant scores produced by `sed` expressions that SILENTLY
NEVER APPLIED; and a corpus sweep caught 3 denials on a passing tree from an ambiguity count read
over the basename instead of the whole path. **A `git log --follow` rename query scored 1 of 73
where a derived 1192-pair rename map scored 62**, and the 1 had already been quoted into a value
argument that the correction inverted.

**A FALSE `BL-272` SIBLING WAS FILED AND WITHDRAWN.** `validate-artifact-paths.sh:410` is
`head -60`, but `:411` prints `… first 30 of 73 shown.` — a DECLARED preview, not a silent
truncation, and it was in the captured output of the run that was misread. Not filed. The error was
reading a RENDERED artifact instead of driving the program.

**BATCH 124 SHIPPED `v0.592.0` AND IT IS ACTION 1 AGAIN — THE LAST TWO ARMS AT THE TOP OF THE
BY-ARM TABLE, PLUS A REWRITE THIS RELEASE REFUSED.** Validator total **4774 → 3827 forks**,
`FORK_BUDGET` 4777 → 3833, stdout and stderr byte-identical to base.

**I82 657 → 61**, by the `[[ =~ ]]` transform `I82b` one arm down already used, plus parameter
expansion for the per-path split. The nine in-body probes are the oracle: this form 0 failures,
the quoted-RHS form 7, the anchors stripped 4, the exemption dropped 1, with never-flags 7 and
always-flags 2 as controls.

**THE FIVE "INTERMEDIATE SETS" ARE NOT AN ORACLE AND WERE NEARLY USED AS ONE.** Areas, roots,
paths, components and dirs are all computed BEFORE the predicate is first called and are not
functions of it, so they agree between any two implementations — including the quoted-RHS port
this release warns about. The live corpus is fully conforming and holds no discriminating input.

**I84 527 → 271, AND THE FORK-FREE FORM WAS REFUTED BY MEASUREMENT.** The in-shell `read` loop
removes all 508 forks and is **3.7x SLOWER** — 127 files, 78011 lines, interleaved reps: shipped
439-480ms against in-shell 1698-2028ms, every form agreeing on hits. **`validator-fork-budget`
cannot see that.** Whole-validator wall clock, 3 reps each from inside the repo: base
46.31/46.30/46.63s, tip 43.48/44.07/43.54s. A fork count is a proxy for cost and not the cost.

**THE CONTRACT CARRIED THREE WRONG NUMBERS INTO THE ADVERSARY PASS, AND ALL THREE CAME FROM ONE
TRUNCATION.** `fork-profile.sh --section by-line` prints 60 rows of 926 under a header identical
to an untruncated one, while `emit_by_arm` is unbounded. Summing the printed rows invented a
per-arm discrepancy of exactly the tail it could not see, and that discrepancy reads as `BL-268`
— real, filed, live. Filed as `BL-272`. **Take by-line sums from `--dump <dir>`.**

**`BL-268` IS ALSO LIVE AND THIS RELEASE FOUND ITS HIDDEN SITE**: 95 `tr` forks reporting at bare
`fi` 7132 belonged to `I82`'s line 6838 two arms up, and had been read as `I99`'s.

**FILED, NOT FIXED: `BL-270`, `BL-271`, `BL-272`.** The drain plan's ledger-ref election gates on
`merge-base --is-ancestor main "$b"` and **0 of 723 non-main consumer branches pass it** while 178
carry a ledger, so it elects `main` every time and its assertion arm — computed against the ref it
elected — answers 0 by construction. `BL-271` is the one candidate visible through no other ref.

**BATCH 123 SHIPPED TWO RELEASES — `v0.590.0` (`e42340fd`) AND `v0.591.0` (`ec959797`) — AND ITS
SUBJECT WAS NOT THIS PLAN.** The operator ruled the scope: the six candidates that exist ONLY on
the consumer's SPRINT branch, re-derived at `8990d8cad`. That ref carries **53** live candidates
against `main`'s **62**; the worklist stays 17 but its MEMBERSHIP moves, and three entries a
main-keyed sweep cannot surface (`BL-260`, `BL-261`, `BL-263`) say so in their own text. The
plan's own `lids()` block already mandates the sprint tip and records that batch 85 got this
wrong twice in one session; a hand elected `main` anyway and the lead took it. **Read the block,
not the hand.**

**THREE OF THE SIX NEEDED NO WORK, AND THAT IS A DELIVERY FACT, NOT A DEFECT.** `BL-259` and
`BL-262` landed at `0.584.0`, `BL-254`'s code half at `0.578.0` — all inside the consumer's
unpulled `0.582.0`→`0.589.0` gap, so they read as live upstream because the consumer is eight
releases behind. `BL-254` stays OPEN and headed `DEFECT` deliberately: it was filed AT that
release for the residual half no predicate resolving against this tree can observe. A first
draft of the release note called all three "landed"; the tip adversary caught it.

**`v0.590.0` — Check 22's effort arm could not fire at the gate its own step file publishes.**
`probe_effort()` returns empty without a readable `--probe`, so every row landed in
`EFFORT_PENDING` and none reached `VIOL`. The published invocation passed three flags and no
probe. Measured end to end, one seeded row (`effort_bound: high` against a probe recording
`low`): **rc=1 with the probe, rc=0 without**, same ledger and settings, reproduced in a real
`install.sh` consumer tree. `--probe` sits BEFORE `--settings` because `BL-263`'s receipt stops
collecting at that flag — placed after it the fix is real and the receipt still reads 1.

**THE FIXTURE COULD NOT HAVE SEEN IT, WHICH IS THE PART TO CARRY FORWARD.** Every arm built its
own command line with `--probe` already on it, so **zero arms joined the published invocation to
the validator** (control: 3 name the validator at all) while all 55 assertions were green. `C2b`
now EXECUTES the fenced block — a grep for the token is satisfied by the prose around it, which
carries `--probe` four times.

**AND THAT ARM'S EXTRACTOR WAS WRONG TWICE, BOTH TIMES IN THE DIRECTION THAT READS AS WORKING.**
First it appended the closing ``` before testing for it, so both sides died of a syntax error at
rc=1 and the arm reported "not discriminating" — a broken extractor indistinguishable from the
defect it hunts. Then, caught by the tip adversary: stripping every trailing `\` and joining
made it MORE FORGIVING THAN A SHELL, so a block whose continuation was deleted mid-command still
reassembled into a valid command line and scored green, while a consumer copy-pasting it loses
every flag after the break. **An arm that executes a documented command is only as good as its
transcription of that command.**

**`v0.591.0` — a session with zero captured requests is now NAMED.** `BL-261`'s buildable half:
`validate-request-coverage.sh --session <id>` refuses with exit 2 when the capture holds no entry
for it. PENDING-shaped and opt-in, so Check 33's published invocation is byte-unaffected — a
fail-closed default would wedge live work. The ALLOW TWIN is the arm that matters: a session the
capture DOES hold exits 0 on the same command line, because a deny arm alone cannot tell a
correctly-keyed guard from one refusing everything. The root cause is NOT established and the
entry says so.

**A PROSE-ONLY COMMIT MOVED THE FORK COUNT, AND THE GATE CAUGHT IT.** `0.590.0` touched no code
in `validate-enforcement-map.sh` and still breached `FORK_BUDGET` by one. The documented path
`_bmad-output/subagent-context.jsonl` sits under a declared scan root, so I82's extractor pulled
it into `i82_seen` and charged two `grep -qE` per component: **I82 653 → 657, total 4769 → 4774**.
Budget 4773 → 4777, with base measured at 4769 in a clean worktree to prove the delta was the
branch's. **A DOCUMENTED PATH IS A CORPUS ENTRY HERE.**

**`agent-definition-render`'s "rare flake" IS A ~90% CONCURRENCY DEFECT, AND IT BELONGS TO
`main`.** It went red on a gate run and was nearly dispositioned as the `BL-230` class on nine
green solo runs. **The solo runs are the outlier.** An 8-run sweep predicts 0.27 events at the
rate `BL-258` claims — below one, so that clean sweep could not discriminate and was discarded
rather than read as an acquittal. At a discriminating N: solo 0/9, width-12 5/12, **29/32 at tip
and 29/32 at base**. Identical at the same N is what establishes ownership. Lead: `mut()`'s
`cp "$SUBJ_DIR"/*` copies the LIVE `core/scripts/` per mutant while 105 fixtures naming that path
share the pool — the destination is a private `mktemp -d`, the source is not. `BL-258` widened;
the mutant and its entanglement check stay as they are.

**TWO CONTRACT FINDINGS ABOUT THIS PLAN'S OWN ACTION 1 WERE FILED AS `BL-268` AND `BL-269`**, from
an adversary that attacked the four-arm cut before anything was built. They are summarised in
action 1 above and are the reason its arm table now carries a warning.

**BATCH 122 ALSO SHIPPED `v0.589.0` (`bc1d75b7`, PR #789) — A CORRECTION, AND THE TIP ADVERSARY
FOUND BOTH HALVES OF IT ON A GATE-GREEN BRANCH.**

**`[ \t]` IS NOT `[[:space:]]`, AND `v0.588.0` CLAIMED THE PREDICATE WAS "PRESERVED VERBATIM".**
Three regex literals in the two new awk programs used a two-member class where the shell grammars
they replaced used the six-member POSIX class. Measured end to end on a seeded tree: a file whose
`# Usage:` line is FORM-FEED indented and correctly documents its mode was reported as
UNDOCUMENTED by the tip at exit 1 and silently by the parent — **a false finding invented by the
port**. The TAB direction the adversary also flagged is REFUTED: awk compiles `\t` inside a
LITERAL regex, so both grammars match a tab-indented arm. `awk -v` is where the escape is
stripped, which is why `i60_nc_form` already used the class.

**`getline < file` RETURNS -1 ON AN UNREADABLE FILE AND AWK RAISES NOTHING.** I59's floor counts
the `find` LIST while the scan reads the FILES, so a corpus listed and never opened reported the
same clean line as a scanned one — the shell form could not hide it because `grep` wrote to
stderr. Measured: 3 listed, 2 scanned, awk exit 0, stderr EMPTY; and on a seeded tree with one
corpus file at mode 000 the parent exits **0** while the fix reports `listed 100 ... SCANNED only
99` and exits 1. **Ask of every `getline` what it does when the file will not open.**

**AN AWK LITERAL CANNOT CONTAIN AN APOSTROPHE, INCLUDING IN ITS COMMENTS.** It is a single-quoted
shell literal. The first draft of the scan-count block closed it on a possessive form of
"validator"; the second draft did it again WHILE WARNING ABOUT IT, by quoting the offending word.
Both caught by `bash -n` and by `--arms I59` exiting 2 — the selector's own refusal path working
exactly as its header says it must.

**TWO ADVERSARY FINDINGS WERE REFUTED BY MEASUREMENT.** The derived mutant tally counts **9** over
a real green run, not 5 — `kill_j`'s own messages match the counter's grammar, verified by driving
the SHIPPED `note()` over the exact lines a green run emits. And `BL-265`'s receipt is not
prose-satisfiable; both anchors resolve to executing lines. **A delegate's finding is a hypothesis
until re-derived**, in both directions.

**BATCH 122 SHIPPED AS `v0.588.0` (`6b5b9a63`, PR #788). ACTION 1 AGAIN, AND THE SECOND SUBJECT WAS
FOUND BY THE FIRST ONE FAILING.**

**I60 and I59 became one awk pass each**, the two arms left at the top of the by-arm table after
`0.587.0`. `i59_undocumented_in` forked one `awk` per MODE (216 modes across 100 files) and
`i59_modes_of` four externals per FILE; `i60_ghosts_in` forked a `find` and a `head` per CITATION
(97 each) and `i60_dispatches` eight externals per resolved citation (84) over only 42 distinct
target files. **I60 1011 → 46, I59 713 → 20, the file 6425 → 4767 (−25.8%)**, `--stable` 2/2 each
side in CLEAN worktrees, spreads 6425-6425 and 4767-4767, every OTHER arm byte-identical across
the two readings. `FORK_BUDGET` 6431 → 4773.

**THE EQUIVALENCE ORACLE HAD TO BE BUILT AGAINST A CORPUS THAT CAN DISAGREE.** Both arms report
zero findings on this tree, so comparing FINDINGS compares two empty sets — the vacuous shape
`0.587.0` measured at 0 of 205. The shipped implementations were extracted BYTE-IDENTICALLY (with
a control proving the comparator can report a difference) and scored over the non-empty
INTERMEDIATE sets — 216 modes, 164 dispatch rows — plus a seeded `mktemp` corpus that fires,
asserted non-zero on the shipped side first, with a fully-documented file as the silent control.
A deliberately wrong port was then built and shown to DISAGREE on the same input.

**AN ORACLE THAT SETS `pipefail` IS NOT MEASURING A SUBJECT THAT DOES NOT.** The extraction first
reported 53 ghosts against the validator's 0: `i60_ghosts_in` ends `… | sort -u | grep -qx`, and
`grep -q` leaves at its first match while `sort` is still writing, so under `pipefail` every
dispatched mode read as undispatched. The subject is `set -u`. The probe was wrong, as this repo's
rule says to assume.

**TWO MUTATION ANCHORS DIED AND WERE RE-ANCHORED; SIX WERE VERIFIED BY RUNNING THEM.** Measured
before re-anchoring, with the dead function deliberately left in place: the old I59 arm-2 mutation
applied cleanly, `cmp -s` passed it, and `--arms I59` exited 0 printing the OK line — the
silent-unmutated-run defect `0.587.0` shipped. `i59_modes_of` was DELETED rather than kept beside
the awk, and `i60_nc_form()` exists as a function so the battery has one executable site to key on;
the same regex in the prose above it is text a `sed` cannot tell from the program.

**THE FORK GATE'S OWN FLOOR HAD KILLED THE ARM BESIDE IT, AND THE CORRECT CHANGE IS WHAT EXPOSED
IT.** `judge`'s A1 floor was a hardcoded 5000 evaluated before A4 stale-high, so A4's window was
`5000 < t < 0.7b` — EMPTY for every budget at or below 7143, which `0.587.0`'s 6431 already was.
Landing the true reading at 4767 made the fixture report the improvement as
`BROKEN ... a broken tracer`, with m2, m3, m5 and m6 all firing on A1 instead of their own arms.
Floor is now 40% of `FORK_BUDGET` so both bounds move together; the three real broken-tracer inputs
measure 0, 0 and 1 against a live control of 4767. New mutant `m8` constructs the midpoint of A4's
window at the COMMITTED budget — the one mutant that must key on `$BUDGET`, because `m3` at
`T1 * 2` has a window under any floor and could never see the closure. Filed as `BL-265`.

**BOTH NEW RECEIPTS WERE WRITTEN PROSE-SATISFIABLE AND CAUGHT BY SCORING THEM.** `BL-265`'s first
form returned 0 against a three-line file of pure comments with no executable floor; `BL-266`'s was
satisfied by two unrelated comments about a hand-copied path. Both re-keyed on emission sites and
scored 0 / 1 / 1 across the real file, a prose-only file and the parent commit. `BL-266` also
records that the I59 corpus mutation is over-broad — four arms' corpora, up from three, and `vrun`
reads only one verdict — which is pre-existing and which this release widened by one site.

**BATCH 121 SHIPPED AS `v0.587.0` (`14f5ecfb`). TWO SUBJECTS ON ACTION 1, AND THE SECOND ONE IS
DELIBERATELY UNFINISHED.**

**I87's two per-item loops became one awk pass each.** `i87_readable` forked one `grep` per file
across 430 files; `i87_exposed_in` ran ~9 externals per fixture directory across 205 of them.
**I87 1842 → 48 forks, the whole file 8219 → 6425**, `FORK_BUDGET` 8225 → 6431 taken from the
fixture's own reading rather than by arithmetic. I87 no longer appears in the by-arm table.
(I60 was named here as the next target; `v0.588.0` took it, and I59 with it.)

**THE RECONCILE HALF IS A PARTIAL FIX AND SAYS SO.** A filesystem-backed blob/tree memo in
`lib.sh`, shared across one `emit-report.sh` render through `AI_DLC_RECONCILE_MEMO` because the
sub-detectors are separate processes and an in-process memo cannot reach them. Git calls
**19219 → 14490 (−24.6%)**, distinct 302 → 300, so **75% of the original redundancy remains** in
shapes the memo does not cover: `show <sha>:…/classes.md` 542, `ls-tree --name-only` 443,
`cat-file -e` 375, `rev-parse -q --verify` 369 and 369, `ls-files --with-tree` 359, `hash-object`
273. A single before/after TOTAL cannot tell a complete fix from one that memoized the biggest
line and stopped; the census must be bucketed by normalised call shape, and only that bucketing
revealed the partial-ness.

**A MEMO THAT MOVES A CALL SITE MOVES EVERY MUTATION ANCHORED ON IT.** Relocating two git calls
into `lib.sh` left `preclassify-rename-row`'s and `retired-layer-token`'s `sed` anchors on a
fallback branch that never executes while `lib.sh` is present, so **both mutants silently ran the
UNMUTATED path.** Verified by content: the anchor is present once in `preclassify.sh` at the parent
commit, absent there now, present twice in `lib.sh`. Every other fixture that `sed`-mutates a
reconcile detector was checked against the four relocated shapes; no third was orphaned.

**THE TIP ADVERSARY FOUND A SHIPPING BLOCKER ON A FULLY GREEN BRANCH, WHICH IS WHY THAT PASS
EXISTS.** `memo_show` and `memo_rev_parse` filled byte-correctly and served through
`printf '%s\n' "$(<f)"`, which strips EVERY trailing newline and adds one back — a blob with none
came back one byte LONGER, an empty blob as a bare newline. `unregistered-drift.sh` pipes that
straight into `cmp -s -`, so a byte-identical consumer file read as DRIFTED. The
single-trailing-newline case is every normal file, which is why the battery, the full gate and a
consumer install rehearsal were all green over it. **The idiom came from this repo's own `0.586.0`
release note**, which recommended `$(<file)` for cache reads — right for a VALUE, wrong for a BLOB.

**TWO PROFILING HAZARDS, BOTH CARRIED INTO `.claude/rules/`.** A `$(date)` inside `PS4` charges one
fork per traced line, so a per-line timing profile ranks loops by ITERATION COUNT — it attributed
37s of a 47s run to two fork-free loops that an ablation differential then refuted, every range
overlapping. And **nested `bash` does not inherit `-x`**, so an xtrace of a program that shells out
undercounts everything below it: the reconcile census read 28 git calls under xtrace against 19219
under PATH-shadowed wrappers.

**BATCH 120 SHIPPED AS `v0.586.0` (`78ebe40a`, PR #784). IT IS THE FIRST DELIVERY OF ACTION 1, AND
IT REFUTED ACTION 2's OWN FRAMING.** The action-1 lever — repeated I/O over the same files — holds
INSIDE one invocation of one program, which is where it is cheapest to remove.

**`ledger-reverify.sh` read the same blob up to 79 times per invocation.** `theirs_show`,
`base_show` and `theirs_has_path` are called from the per-entry loop, so their cost scales with the
LEDGER's length while their distinct inputs scale with the number of SUBJECT PATHS it names. Xtrace
over one invocation: **366 git calls, 112 distinct** — 170 `show` resolving to 9 blobs, 49
`cat-file -e` to 6 paths, and `consumer_scannable` probing one unchanging directory 35 times.
Memoized: **366 -> 133 calls; fixture 306.81s -> 215.21s SOLO**, one invocation 4.71–4.90s ->
3.33–3.49s over 4 interleaved reps with disjoint ranges.

**NO FIXTURE CHANGE, WHICH IS THE PART TO CARRY FORWARD.** No shard, no inner pool, no assertion
touched — 274 assertions still correct with an IDENTICAL LABEL SET, not merely an identical count,
and all eight fixtures driving that file green. Action 2 said "the lever is the fixture itself";
the measurement says the lever was the program the fixture drives.

**A MUTANT SCORING IDENTICAL MEANT THE CORPUS LACKED THE INPUT, NOT THAT THE GUARD WAS VACUOUS.**
The memo separates a cache MISS from an EMPTY BLOB. The mutant conflating them returned
byte-identical output AND the same call count, because the seeded ledger holds no empty blob —
reading that as an acquittal would have deleted a correct guard. Scored on a constructed repo
carrying one: 5 lookups cost 1 git call under the guard and 5 under the mutant, with a non-empty
blob as the same-invocation control at 1 either way. Carried into
`.claude/rules/verification-discipline.md`.

**The loaded record is NOT the evidence here and nearly read backwards**: pole 491 -> 542 while the
run's TOTAL went 5496 -> 6350 (+15.5%) on a busier box. See the caveat in the Next-actions header.

**BATCH 119 SHIPPED AS `v0.585.0` (`389b6bdc`, PR #781). ITS SUBJECT WAS NOT THE POLE, AND THE
REASON IS ACTION 1.** The batch opened under the batch-118 ruling naming this plan, found the
co-pole tie, and then found that the co-pole's cost was not its own design at all.

**`fixture-git-env-seam` 498s -> 57s loaded**, full 202-fixture dispatch. `mktree` copied the whole
working tree eight times per run excluding only `./.git` and `./node_modules`, so it copied
`.claude/worktrees/` — the **Claude Code harness's own agent checkouts**, gitignored, and present
in whatever number of concurrent sessions were running. On the measured tree that was 34 checkouts,
871M of a 1.0G copy, 15x the file count. It was also RACING other sessions: `tar` walks those
directories while another session deletes one, and the fixture exited 9 as `FIXTURE BROKEN`, which
reads exactly like a regression in whatever change is under test.

**AND ITS GUARD COULD NOT SEE THE SILENT HALF, WHICH IS THE PART TO CARRY FORWARD.**
`tar cf - | tar xf - || return 1` reads only the READER's status — there is no `pipefail` in that
fixture or in `core/fixtures/lib/preamble.sh`. Constructed: a writer failing on a missing member
exits **1 alone and 0 through the pipe**, landing 50 of 51 files, and the two `[ -f ]` probes below
it pass because they name two files out of thousands. The copy now asserts COMPLETENESS by counting
entries on both sides. **The exclusion alone would have removed the trigger and left the broken
detector permanently unexercised** — fixing a symptom and hiding the defect.

**`core/scripts/derive-fixture-readsets.sh` was recording gitignored paths into a TRACKED map.**
12435 of 36046 rows pointed into `.claude/worktrees/`; ~35% of all data rows named gitignored
paths. Two derivations of one fixture minutes apart returned 4815 rows and then 26854 — a 5.6x move
caused only by how many agents were live. Filed as `BL-264`. **The stale rows are still in the map**
and clear only on a root-privileged re-derivation taken with no agent worktrees on disk; they are
deliberately not hand-edited, per `BL-127`.

**Two defects found while profiling the pole**: `ledger-reverify/run.sh:184` ran a command
substitution inside a diagnostic string (raw backticks in a double-quoted argument, invisible to
`bash -n`, wrong only in the message), and `.githooks/pre-push` described the inner pools as
"NINE ... 66 workers" against a derived 11/70.

**WHAT BATCH 119 DID NOT DO, DELIBERATELY:** it did not build the `ledger-reverify` inner pool the
batch-118 ruling anticipated. Measured, that pool buys 4.08x on ONE directory and converts to almost
nothing at suite level for the reason action 1 now states, and it carried the largest build risk in
the contract (an assertion counter with no `EXPECTED_ASSERTIONS` floor, a host-`TMPDIR` glob, and a
write-read-clear chain on a fixed path). The design work is in the contract and is not lost; the
measurement is what deprioritised it.

**The consumer rehearsal and the merge. DONE.** A tree built by running `scripts/install.sh`
into an empty directory received both `layer-contract-conformance` and
`layer-contract-conformance-b`, and both printed the sibling's SKIP at exit 0. The four
`.dist-only` shards (`enforcement-map-derivations-b`, `validator-arm-selection`,
`validator-arm-selection-b`, `validator-fork-budget`) were absent, with the shipped pair as the
same-invocation positive control. `uninstall.sh --force` exited 0, removed `tests/fixtures/`
including the `-b` shard, and left `_bmad/`. `AI_DLC_FIXTURE_NO_SKIP=1 bash .githooks/pre-push`
was green — **153 ok, 0 FAIL**, full dispatch — and all ten fixtures this program changed read
`ok` **by name**, against a control name that returns 0 in the same grammar.

**The read-set map. DONE, by the operator, under `sudo`.** Landed as `0376cb5` and merged in
`d4fd318`: **140 of 153 → 153 of 153**. Re-derived against the tracked map, the dispatched set
and the map's key set are equal in **both** directions, with a seeded absent name reported by
the same join as the control that it can fire. `check-h1-recursion` and `check-manifest-bypass`
are correctly outside both sets — neither carries a `run.sh`, so the suite's
`core/fixtures/*/run.sh` glob never dispatches them.

**Two findings from the rehearsal, both PREEXISTING and neither in this program's scope.**
`uninstall.sh` has no removal path for `.claude/hooks/ai-dlc-*.sh` (17 files), `.claude/schemas/`
(6), `.claude/session-driver/`, `.claude/settings.json` or `.claude/.ai-dlc-version`, so 25 files
survive an uninstall; this program's only edit to that file was adding
`layer-contract-conformance-b` to the fixture loop. And on a CONSUMER — not here —
`layer-contract-conformance-b` `exec`s its sibling, which takes its SKIP path and prints a
hardcoded literal naming ITSELF, so both directories emit one label. In this repo the shard
banners and closes under its own name, so there is no collision. The runner keys verdicts on
the directory, so nothing is broken; what it costs is that a consumer's log cannot be read by
fixture name for that pair.

**Both are tracked in `docs/backlog.md` as BL-002 and BL-003**, with executable receipts, so
they survive this plan's discharge.

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

## Where it landed — measured on the merged tree, gate green

`AI_DLC_FIXTURE_NO_SKIP=1 bash .githooks/pre-push` from the main checkout, box idle,
`pre-push: all gates green.`

```
whole pre-push wall           245.21s   (816.79 user + 1588.07 sys = 2404.9 CPU-s)
pool sum                      5553 -> 2785 pool-seconds   (-50%)
pole                          506  ->  220s
```

The old pole set is gone from the top eight entirely — `self-update-join-gate`,
`enforcement-map-sites` and both its shards no longer appear. What replaced it:

| unit | s |
|---|---|
| **validator-arm-selection** | **220** |
| validator-fork-budget | 159 |
| layer-contract-conformance | 134 |
| layer-contract-conformance-b | 133 |
| layer-readopt-gate | 119 |
| check-24-adversarial-convergence | 104 |
| enforcement-map-derivations | 102 |
| enforcement-map-derivations-b | 102 |

**THE POLE IS NOW THE FIXTURE THIS PROGRAM ADDED IN STEP 6** — 220s of a 245s wall, and
`validator-fork-budget` from Step 5 is second at 159s. That is this repo's recurring shape:
the new check becomes the pole. Both are `.dist-only`, both are cheap to shard or trim
(`validator-arm-selection` runs all 94 ids alone at ~0.4s each plus a seeded-tree pass), and
**neither existed when this plan was written**, so neither is in any step below.

CPU floor on 18 cores is now **2405 / 18 ≈ 134s** against a 245s wall, so roughly 45% of
packing headroom remains — the same ratio as before the program started, at half the work.

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

> **DONE. 199.33s → 10.58s, and re-derived here at 11.49s wall / 39.65 CPU-seconds on the
> merged tree at load 4.71.** 3 interleaved pairs with disjoint ranges (before
> 194.24–202.45, after 10.51–11.09), all six runs 16/16, **all ten captured stdouts
> byte-identical** including the pre-change baseline, with a decoy control proving `cmp` can
> fire. The range is bounded to 5 commits / 4 safe-stop candidates / anchors 43 at BASE and 44
> at THEIRS, and the derivation is kept rather than replaced by a hardcoded ref.
>
> **MONOTONICITY, measured for the record and not acted on: REJECT ×111, zero transitions.**
> Every candidate rejects, so the whole walk establishes only that no safe stop exists — and a
> negative over an unproven predicate still has to check every candidate. **This weakens the
> deferred binary-search option rather than supporting it**: a search strategy helps only where
> a transition exists, and on this range there is none. The agent's first probe of this was
> DEAD and it said so — `xargs -I{}` collapses a tab, so the gate received a literal
> `"1 438ee6b…"` as a ref, an unresolvable ref emits no DEFER, and the classifier scored
> **111 ACCEPT: a clean-looking run that had measured nothing.** Caught by `od -c`, not by the
> run.
>
> **SHARDING COSTS CPU, and the census now shows how much.** Each shard re-runs the control, so
> `layer-contract-conformance` went 764.5 → 441 + 415 = **856 CPU-s (+12%)** and
> `enforcement-map-derivations` 830.6 → ~917 (+10%). That is the trade this program is making
> deliberately — on a pole-bound suite, packing beats total work — but it is a real cost and it
> caps how far sharding can be pushed before it starts moving the CPU floor the wrong way.
>
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

> **DONE, and it corrected this plan twice. Read both corrections before trusting anything
> else written here about arm selection.**
>
> **Result: the seven battery shards go 3033.7 → 285.7 CPU-seconds**, less 258 for the new
> differential fixture — about **−2490 CPU-seconds net**. A full validator run is 15.6-17.3s;
> a selected one is **0.40s**. Solo costs, alternated against a `git archive HEAD~1` tree at
> load 5.7-9.4, and never comparable with the loaded figures in the durations record.
>
> | | solo CPU-s before → after |
> |---|---|
> | enforcement-map-sites | 644.8 → 36.4 |
> | enforcement-map-sites-b | 548.2 → 37.0 |
> | enforcement-map-sites-c | 523.4 → 35.9 |
> | enforcement-map-derivations | 338.9 → 33.4 |
> | enforcement-map-derivations-b | 338.7 → 31.0 |
> | layer-contract-conformance | 335.4 → 58.2 |
> | layer-contract-conformance-b | 304.3 → 53.8 |
>
> **CORRECTION 1 — this plan's safety argument was wrong.** It held that a coupled arm reading
> an unset name under `set -u` "exits with `unbound variable` — loud, not green". Measured:
> true in the main shell, **FALSE inside `$( )`**, which kills only the subshell. Three of the
> thirteen coupled units — **I5, I26, I54b** — exited **0** with the message on stderr and
> **no finding**: an arm silently scanning an empty subject, which is precisely the silent
> false pass this repo exists to prevent. **The hoist is a prerequisite, not a tidy-up.**
>
> **CORRECTION 2 — this plan's arm→mutant rule had a 32% false-positive set.** It prescribed
> matching each assertion's `want` string as a literal substring of an arm's `err()` text, with
> 0 or ≥2 matches being `FIXTURE BROKEN`. Measured over all **121** `want` strings in the three
> batteries: 82 resolve to one unit, 8 to several, 15 to none because the message is
> interpolated at runtime, 16 to none because the want is a grep pattern. **That rule would
> declare 39 of 121 assertions broken on a correct tree.** `CLAUDE.md` requires an FP set
> measured before a check ships; this one was measured and the rule was replaced — the id is
> derived from each assertion's own existing name (`A24_i85_…` → `I85`), with a per-battery
> control that fails the shard if the assertions that should select stop selecting.
>
> **Coupling, re-derived empirically by executing each unit rather than parsing it:** 91 arm
> regions confirmed, but **10 headers are indented**, so the selectable unit is the column-0
> arm and there are **81 units**. **68 self-contained, 13 coupled** (not 64/27), through
> **11 names** (not ~15) and exactly **one** cross-arm function, `norm_core_manifest` —
> confirmed. A first automated pass reported three functions and 26 names; `check` and `emit`
> were prose inside `err "…"` strings. **The static pass is a second implementation with its
> own bugs**, and the shipped numbers are the empirical ones.
>
> Three units whose input is another arm's derived output carry a machine-readable
> `# requires-arms:` marker and selection takes the transitive closure. Proven load-bearing:
> deleting all three makes `--arms I43/I44/I54b` emit `unbound variable`; unmutated, silent.
>
> **The all-ids equality holds:** `--arms` with every declared id selected produces
> byte-identical stdout, byte-identical stderr and the same exit code as a plain run, at
> 19.84 vs 19.45 CPU-s (**+2%**). The selection machinery has no material overhead of its own.
>
> **A floor `--arms` cannot lower:** all nine of `layer-contract-conformance`'s arms are
> indented inside one `if [ -f "$lc_file" ]` block, so they share **one** selectable unit.
> Its 5.8× is the ceiling for that fixture unless that block is split.
>
> **NOTE, and it binds Step 9: the pre-push hook's `.git/` paths are literal, so the suite is
> DEGRADED in every worktree.** `.githooks/pre-push:174,625,633` write
> `.git/ai-dlc-fixture-durations`, `.git/ai-dlc-suite-key` and its log; in a worktree `.git` is
> a **file**, so all three fail with `Not a directory`. The content-key skip never fires and no
> durations are recorded. Pre-existing and untouched by this program — but **Step 9 must be run
> from the main checkout, never a worktree**, or it sweeps against a record nothing is writing.

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

### Step 7 — the fork-reduction campaign — **DROPPED ON MEASUREMENT, by operator ruling**

> Not skipped. **Dropped because the measurement that justified it no longer holds.**
>
> This step was sized at ~1200 pool-seconds on the premise that the suite runs
> `validate-enforcement-map.sh` **137 times per push at 15.7s**. After Step 6 it runs fully
> about **ten** times — the pre-push's own serial step plus each battery's absence-shaped
> sanity control, which keep the full run deliberately, because a selected run says nothing
> about the arms it did not run. Everything else is `--arms` at **0.40s**.
>
> So the campaign's value fell from ~1200 pool-seconds to roughly **100**, against 60-90
> minutes of work across 40-60 individual sites each needing its own two-directions probe.
> The `FORK_BUDGET` gate from Step 5 stays and holds the ground: the number cannot decay again
> without a reviewable one-line diff.
>
> **The patterns remain documented below and remain correct** — P1's `in_lines` helper still
> exists unused at 380 sites, P2's per-file grep loops are still there. They are simply no
> longer worth the hours. Re-open this if the validator's full-run cost starts mattering again.

### Step 7 (as written, for the record) — the fork-reduction campaign

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

### Step 8 — copy and clone eliminations — **DROPPED ON MEASUREMENT, by operator ruling**

> The `self-update-join-gate` half **shipped** with Step 4 — the `local`-scope fix, the
> hardlink clones, the parallel installs and the `cp -Rc` fast path are all in. What is dropped
> is the `enforcement-map` half: the `$PRISTINE` hoist and the seed clone-eliminations.
>
> Sized when `enforcement-map-derivations` was 452s and its ~70 tree copies were 20-40s of it.
> After Steps 2 and 6 that fixture is **102s loaded / 33.4 CPU-s solo**, and its shard is the
> same. The copies are now a fraction of a unit that is a fraction of the pole. Roughly 20
> minutes of work for single-digit seconds off a non-pole.
>
> **The hazard notes below stand and are the reason to read this section if it is re-opened**:
> the worker's `trap 'rm -rf "$PRISTINE"' EXIT` must drop `$PRISTINE` before the hoist, or the
> first worker to finish deletes the tree the others are reading; and `cp -Rc` needs its
> `rm -rf`-then-fallback shape, because `core/fixtures/` ships and GNU `cp` has no `-c`.

### Step 8 (as written, for the record) — copy and clone eliminations

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
