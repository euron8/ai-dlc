# Pre-push suite wall clock — long poles and how to cut them

**Archived sections live at `docs/plans/archive/pre-push-wall-clock.md`** — rotated by `scripts/plan-rotate.sh`, original lines 1140..2117. It is a RECORD, not an instruction: read it for the evidence behind a figure, never for something to do.

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

**The live sections of this plan are:**

1. `## Start here`
2. `### Next actions — **THE SUITE IS NO LONGER POLE-BOUND. THE SUBJECT IS TOTAL WORK.**`
3. `### Done when`
4. `## Context`
5. `## Ordered execution`
6. `## Verification`
7. `## Critical files`

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
scheduling headroom left, which is the strongest form of the ruling below.** (Re-derived at
`v0.601.0` from the same block, AFTER that release's own gate run, which is the record a
stranger resuming here will read: pole **429s** (`validator-arm-selection` 347 and
`gate-adjudication-mutants` 264 behind it), total **5899**, floor **491.6s**, concentration
`top10=38.7% top20=57.9%`. **THE POLE IS NOW BELOW THE FLOOR — 429s against 491.6s — SO POLE WORK
HAS NOTHING LEFT TO BUY AT ALL**, and the makespan is the floor. Earlier readings of the same
three, every one LOADED and on a different box load: `v0.598.0` 479/5508/459.0 with gap 20s,
`v0.597.0` 636/6960/580.0 and 513/5745/478.8 on one tree an hour apart, `v0.594.0` 545/6132/511.0,
`v0.593.0` 627/7120/593.3. **THE GAP HAS READ 20s, 56s, ~34s AND NOW NEGATIVE, AND THAT SPREAD IS
THE POINT.** **A gate run REWRITES this record, so the figures a resuming session reads are
whatever the last full dispatch happened to cost, under whatever else was running** — they swing
±27% on load alone. Take the DIRECTION as the answer and never a single reading as one release's
work; batch 129 removed real work and the total still rose 5508 → 5899, because three gate runs
and five measurement agents shared the box.)

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

   **THE RECONCILE MEMO IS FINISHED AS A TARGET — `v0.597.0` CENSUSED THE LAST CANDIDATE AND IT IS
   NOT THIS SHAPE. DO NOT TAKE `reconcile-emit-report` AS ACTION 1's NEXT MEMO.** It is #2 in the
   record at 320 pool-seconds behind the 513s pole, which is exactly why it read as the memo's next
   subject. Censused under a PATH-shadowed wrapper (wrapper control 1, impossible-subcommand control
   0): **ONE invocation is 93 calls / 76 distinct = 1.22x** — `self-update-gate`'s shape, recorded
   two paragraphs down as NOT this lever, and not `ledger-reverify.sh`'s 366/112. The fixture's
   14490 calls resolve to **300** distinct, so the redundancy is ACROSS its ~156 invocations, in
   separate processes. **Every fixture whose whole-run ratio looked memo-shaped has now been
   censused per-invocation and only one of them ever was.**

   **AND THE PER-INVOCATION TABLE'S HIGHEST RATIO WAS ALSO THE WRONG TARGET, WHICH IS THE DURABLE
   HALF.** `hash-object` reads 12 calls to **2 distinct files, 6.00x** — the top row of that
   invocation's table, and 12 forks of a 2s render. Taking it would have repeated `v0.596.0`'s `I75`
   error one release later. **A RATIO RANKS REDUNDANCY, NOT COST**; it is the same instrument
   failure as the by-arm fork table, one level down, and it is spotted the same way — by ABLATION.

   **THE SUBJECT WAS ONE DETECTOR, AND THE FIX WAS A FLAG THAT ALREADY EXISTED.** Every detector
   the renderer drives, timed against one seeded tree, 3 interleaved reps with each run's rc
   asserted: whole render 1456-1556ms, of which **`unregistered-drift.sh` alone is 586-661ms —
   43%** — against `ledger-reverify` 163-165, `preclassify` 132-147, `layer-drift` 84-94 and nine
   others below 100ms. That scan takes `--bucket-rows <file>` so a caller holding preclassify's
   output hands it down instead of making it re-derive them in a second process; `apply.sh:504` has
   passed it since the flag existed and `emit-report.sh` never did, computing those exact rows one
   call above. **NOFLAG 789-949ms against FLAG 610-723ms**, 5 interleaved reps, outputs
   byte-compared every rep, disjoint ranges. **Ask of a slow orchestrator which of its CHILDREN
   costs the time before scoping anything inside it.**

   **AND THE FIGURE QUOTED FOR IT IS THE COUNT, NOT THE SECONDS, EXACTLY AS THIS BLOCK REQUIRES.**
   One full fixture run per side in two FIXED `git worktree` checkouts, interleaved, each under its
   own PATH-shadowed wrapper with that wrapper's control at 1: **14490 → 14047 git calls, −443
   (−3.1%)**, distinct 300 both sides, `rc=0` both sides, assertions 81 against 83 — the sides
   differing by exactly the two arms added. **Both sides reproduced EXACTLY on a second interleaved
   rep — spreads 14490-14490 and 14047-14047, zero either side.** The ms column of that same run is
   void: a concurrent gate put the tip reps at 355892/317245ms against the base's 202105/265350ms,
   overlapping ranges around a −443-call effect. **A DIFFERENTIAL'S BASE MUST BE A TREE THE SESSION CANNOT WRITE** — the first
   attempt used the main checkout while the release branch was being assembled in it, so rep 2's
   base was the tip, caught by grepping that rep's own output for the new arm (83 assertions where
   a real base emits 81) and not by reading the timings.

   **AND A RATIO THAT CORRECTLY SAYS "NOT MEMO-SHAPED" CAN STILL BE HIDING A REPEAT, BECAUSE A
   PER-INVOCATION RATIO CANNOT SEE ONE THAT SPANS TWO FUNCTIONS.** Measured at `v0.598.0` on the
   pole itself: `ledger-reverify.sh` censuses at 141 calls / 118 distinct = **1.20x**, which is
   `self-update-gate`'s shape and is correctly NOT a memo subject. The subject was there anyway.
   `named_ambiguous` opened with `git log -F --grep="$_id" --format=%H "$THEIRS"` and
   `named_absorbed` opens with the identical walk at `--format=%h`, so the two normalise to
   DIFFERENT shapes in a bucketed census and neither function repeats anything when read alone —
   while the single call site reaches the second exactly when the first returned empty. **34 of 41
   distinct slug queries per invocation were the repeat.** Found by ABLATION (stub both to
   `return 0`: base 3.65-3.90s against 2.58-2.70s, 4 interleaved reps in fixed worktrees, rc
   asserted every side), never by the ratio. **Ask what a cheap guard is sitting BEHIND**: the fix
   was ordering four pure predicates so the `sed` and the counter refuse an id before the walk is
   paid for, 141 → 109 calls.

   **AND THAT RELEASE WITHDREW ITS OWN FIXTURE-SOLO FIGURE, WHICH IS THE HAZARD TO CARRY
   FORWARD.** The base fixture run was timed under the PATH-shadowed git wrapper this block tells
   you to build, and the tip run was not. The wrapper is a `sh` that logs and `exec`s — **~8ms per
   git call**, measured at 300 calls over 2 reps, 6.65-6.74s bare against 9.11-9.16s wrapped — and
   `ledger-reverify` makes **9146** of them, so the base carried ~73s of pure instrument. The pair
   read 267.17s → 221.16s and shipped as −17.2%.
   **THE CENSUS WRAPPER AND THE TIMING RUN ARE TWO DIFFERENT MEASUREMENTS AND MUST NEVER SHARE A
   RUN.** Take the count under the wrapper, take the clock without it, and interleave each pair.

   **AND THE REPAIR-BY-SUBTRACTION WAS WRONG TOO, WHICH IS THE HALF WORTH MORE THAN THE FIRST
   ERROR.** ~8ms × 9146 calls gave an estimated base of ~194s, which would have made the tip a
   REGRESSION and nearly reverted a correct change. Re-taken with both sides unwrapped and
   interleaved in fixed worktrees, rc asserted and 274 assertions on all four runs: **base
   240.85-256.75s against tip 220.17-234.45s**, disjoint, **~21.5s (−8.6%)** — real, and half the
   size first claimed. A per-call overhead times a call count is not a measurement of the run,
   because the calls overlap the work. **Re-take a contaminated figure; never repair it by
   arithmetic.**

   **BATCH 129 (`0.599.0`-`0.601.0`) TOOK THE NON-GIT FORKS, AND THAT IS THE LEVER THIS BLOCK'S
   OWN INSTRUMENTS CANNOT SEE.** `ledger-reverify.sh` makes **909 forks against 109 git calls** —
   `sed` 284, `grep` 191, `cat` 170, outnumbering git 6:1 — so the bucketed git census and the
   total/distinct ratio both score a correct 17% CPU cut as ZERO. **Ask what a program forks that
   is NOT git before reading a git census as its cost.** Measured in CPU-seconds because wall
   clock could not resolve it: a 10-rep interleaved wall-clock differential read −492..+1086 ms
   around a mean of 485, spread larger than the effect. Also taken: `machinery_paths()` 26 → 2
   `ls-files` (`0.600.0`), and `retired-tokens.sh`'s per-CLASSIFY-file re-derivation of a
   preclassify both callers already held, 594 → 396 invocations (`0.601.0`).

   **TWO SHIPPED FIXES WERE BLOCKED BY AN ADVERSARY BEFORE THEY LANDED, AND BOTH REMEDIES ARE
   THE DURABLE PART.** A batched `machinery_paths()` that put `--with-tree="$BASE"` on the OPENING
   line of a multi-line command substitution made `armc-mut-base`'s line-delete produce a mutant
   that DOES NOT PARSE — scored as SURVIVED, reading as a regression in the change under test.
   `ac_kill_pre` now runs `bash -n` beside its `cmp -s`. And handing preclassify rows down to
   `retired-tokens.sh` acquitted a live finding on an EMPTY rows file, because that detector's
   refusal goes to stderr and both callers discard it — all four reconcile fixtures stayed green
   over the hole. **Ask of every hand-down what an EMPTY payload makes the reader say.**

   **`gate-adjudication-mutants` (264s) WAS MEASURED AND REFUSED, AND THE REFUSAL IS THE FINDING.**
   Four of the eight sections of the fixture it reruns 21 times are scored by NO mutant's declared
   kill set, and ablating them is a clean **−32%** (base 145.92-158.43s against 99.41-107.09s,
   disjoint, rc=0, 21 scored, 0 FAIL). **It is still a coverage regression.** The battery's guard
   is an EQUALITY compare (`run.sh:198`), so an UNDECLARED failure is a finding TODAY; the
   21-mutant corpus cannot separate the sides because every mutant was authored to damage a
   DECLARED property. One constructed input — deleting the dispatch window's upper bound at
   `validate-gate-adjudication.sh:1398` — reads base `GOT=[BINDING]` rc=1 against ablated `GOT=[]`
   rc=0, silent. **Do not re-take this without splitting the fixture at its own boundary.**

   **`validator-arm-selection` + `-b` (473s combined) IS MEASURED AND OPEN.** 118 declared ids run
   against 103 selectable units, so **15 ids re-run a unit another id already ran** — all 11
   layer-contract ids generate a byte-identical 115068-byte subprogram (controls: `I8` 65412,
   `I82` 93337). Ablating to 103 representatives is −18% on the pair. **DO NOT TAKE THAT SHORTCUT**:
   `run.sh:329` asserts every id runs alone and `:414` that the union of per-id findings equals the
   full run's, and the ablation was measured to stop checking one id's attribution. The real fix is
   lifting the `if [ -f "$lc_file" ]` guard at `validate-enforcement-map.sh:629` so the 9 indented
   arms become column-0 units — a change to a validator the pole invokes, needing its own
   before/after timing, and a release of its own.

   Profiled so far: `ledger-reverify.sh` (done, `0.586.0` memo, `0.598.0` guard order, `0.599.0`
   non-git forks 909 → 639), `preclassify.sh`'s `machinery_paths()` (done, `0.600.0`),
   `retired-tokens.sh` (done, `0.601.0`), I87 in the enforcement-map validator
   (done, `0.587.0`), I60 and I59 in the same validator (done, `0.588.0`), I82 and I84 in the same
   validator (done, `0.592.0` — 4774 → 3827 forks, and the arm table in the block above is the
   post-cut one), `emit-report.sh`
   (PARTIAL, `0.587.0` — the surviving shapes are listed in the discharged record below). Profiled
   and found NOT to have this shape: `gate-adjudication-mutants`, where git is absent by design and
   the awk/grep repetition is spread across 21 independently-necessary sandbox reruns.
   **`self-update-gate` WAS PROFILED AT `v0.590.0`, IS NOT THE MEMO SHAPE, AND WAS TAKEN ANYWAY AT
   `0.600.0` BY A DIFFERENT LEVER — ITS ARM-C FORK FAN-OUT.** The memo reading below stands and is
   still the reason not to build one here. **THREE OF ITS FIGURES WERE REFUTED WHEN RE-DERIVED**,
   which is why none of them should be quoted without re-taking: the fixture drives **257**
   invocations, not ~98 (the 98 came from dividing total git calls by a divisor valid only for FULL
   invocations); the 85 are safe-stop **DRIVERS at 0.027s each**, not sub-walks, and the sub-walks
   are a separate 59; and **the plan's named lever for it — "the range or the walk" — is false**.
   The release range is SEEDED and flat at 4 across 237 releases, so this fixture's cost is not
   history-bound, and ablating the safe-stop walk reads as no measurable change. Compare
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

   **`I65` IS DONE — TAKEN AT `v0.596.0`, AND IT WAS NEVER IN THE FORK TABLE'S TOP FOUR.** Its
   `lc_i65_index` step (c) prefilter was an ERE alternation of the whole 53-code vocabulary
   wrapped in two boundary groups, at **2.23-2.26s** against **0.79-0.83s** for `grep -F -f` —
   ~50% of the layer-contract unit and the single most expensive line in it. The awk below it
   re-applies the exact boundary test, so the prefilter may return a SUPERSET and never a
   subset: verified `comm -23` = **0** lines present-under-ERE and absent-under-`-F`, 275 in the
   safe direction. Whole validator, 4 interleaved reps: base 40.78-42.86s, tip 39.54-39.93s.
   Fork total 3204 against 3203-3204, because one grep replaced one grep — **the fork gate could
   not see this win at all**, which is the same blindness `v0.592.0` recorded in the other
   direction.

   **Inside the validator the remaining arms are `I75` 446, `I84` 273, `I61` 204 and `I64` 181**,
   of a total of 3203 (`FORK_BUDGET` 3209 since `v0.594.0`). `I33b` is GONE from this table —
   645 → 14 at `v0.594.0` — as `I82` went 657 → 61 at `v0.592.0`. Re-derive before choosing — it
   is the only ranking that has predicted anything here:

   **THAT TABLE RANKS FORKS AND NOT COST, AND `v0.596.0` MEASURED THE INVERSION. DO NOT PICK A
   TARGET OFF IT ALONE.** `I75` is top at 446 forks and is **0.86s net** of a ~41s validator.
   The table is still worth re-deriving — it is how a batching opportunity is SPOTTED — but the
   arm that costs the wall clock is found by ABLATION, not by reading the top row. `BL-269`'s
   I75 oracle is therefore not worth building for a 0.86s subject; the entry stays open as a
   coverage fact, not as this plan's next action.

   **AND `--arms <id>` IS NOT A PER-ARM TIMER — `BL-274`.** An INDENTED arm header merges upward
   into the enclosing column-0 unit, so `--arms I61`, `--arms I64` and `--arms I41` all run the
   SAME twelve-arm layer-contract unit. Timing one that way reads the UNIT, exits 0 and prints
   the ordinary OK line, with no tell. The discriminating measurement is one line: **`I41`, an
   arm with FOUR forks, times at 4.29s.** 15 indented headers against 103 column-0 ones, so this
   is not one unit's problem. **Ablate the arm's body, assert `rc=0` on EVERY side, and
   interleave** — two ablations in that release read as huge wins and were a renderer refusal at
   exit 2 and a failing run at exit 1.

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

   **Work concentrates, which is what makes this tractable:** top 10 units are **41.0%** of all
   pool-seconds, top 20 are **57.1%** (re-derived at `v0.598.0` from the post-gate record;
   41.5/58.9 at `v0.597.0`, whose SAME tree read 42.7/60.0 from the pre-gate one — the swing this
   pair of figures has against no code change at all; 41.8/58.9 at `v0.594.0`, 42.3/60.6 at `v0.593.0` and
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

   That 628s row is superseded (`ledger-reverify` was sharded, the pool-12 row re-calibrated).
   Read the tracked file; quote no figure from here.

   `scripts/validate-suite-pole.sh` compares the last full green run's pole against that pool
   width's own recorded pole history (BL-465): the max of every usable row at the width, under the
   file-level `# history-band:` in `docs/suite-pole-baseline.tsv`, fails the push above its ceiling.
   A width with fewer than three history rows CALIBRATES — against the tracked seed row where one
   exists, reported and never enforced. It SKIPs rather than fails on a partial dispatch, and has no
   downward fail. Read the current seed rows and history, and confirm the guard answers on them:

   ```
   grep -v '^#' docs/suite-pole-baseline.tsv        # the tracked seed rows, one per width
   cat "$(git rev-parse --path-format=absolute --git-common-dir)/ai-dlc-suite-pole.history"
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

3b-ii. **REMOVE EVERY AGENT WORKTREE THIS BATCH SPAWNED, BEFORE 3c.** Run after 3b, when no
   hand is still working. `git worktree list | grep .claude/worktrees` derives the set; the
   count at a clean batch close is **0**, and it is the only moment that is true. The `Agent`
   tool auto-removes a worktree only when it is UNCHANGED, so every hand that writes leaves one
   permanently — measured at batch 129: **39 worktrees, 1.0G, three days old, across batches
   114-129**, three of them spawned by briefs that said *"do not delete the worktrees"*.
   **A brief must never say that.** Snapshot any uncommitted files first
   (`git -C <wt> status --porcelain`; 2 of the 39 held some, one a complete unlanded fixture),
   then `git worktree remove`, which deletes the DIRECTORY and never the branch — every commit
   survives, verified by a control resolving a branch after removal. A locked tree needs
   `-f -f`; **read the pid in the lock reason first and confirm it is not a live agent.**
   This is NOT a pre-push gate and must not become one: measured on this batch, hands were
   legitimately live across all four pushes, so a push-time check has a non-empty
   false-positive set on every normal batch.

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

**BATCH 128 SHIPPED `v0.598.0` AND IT TOOK THE POLE ITSELF, ON A SHAPE THREE RELEASES OF
INSTRUMENTS HAD ALL SCORED AS EMPTY.** `ledger-reverify` censuses at **141 git calls / 118
distinct = 1.20x** — `self-update-gate`'s shape, which this plan records as NOT the memo lever.
That reading was CORRECT and the subject was there anyway.

**A PER-INVOCATION RATIO IS BLIND TO A REPEAT THAT SPANS TWO FUNCTIONS.** `named_ambiguous` opened
with `git log -F --grep="$_id" --format=%H "$THEIRS"`; `named_absorbed` opens with the identical
walk at `--format=%h`. The two normalise to DIFFERENT shapes in a bucketed census, so neither
function repeats anything when read alone — while the only call site,
`[ -n "$na" ] || nam="$(named_ambiguous "$label")"`, reaches the second exactly when the first
returned empty. **34 of 41 distinct slug queries per invocation were the repeat.**

**ABLATION FOUND IT, AS IT DID AT `v0.596.0` AND `v0.597.0`. THAT IS THREE RELEASES RUNNING WHERE
THE INSTRUMENT THAT WAS SUPPOSED TO PICK THE TARGET DID NOT.** Stub both functions to `return 0`,
4 interleaved reps in two fixed worktrees with rc asserted every side: base **3.65-3.90s** against
**2.58-2.70s**, disjoint — ~29% of an invocation.

**THE FIX WAS GUARD ORDER, NOT A MEMO, AND NO FORK TABLE OR RATIO NAMES THAT QUANTITY.** All four
of `named_ambiguous`'s guards are pure predicates returning empty, so the order they are asked in
cannot move the answer — only how many history walks are paid for an id that was never going to
produce a row. **141 → 109 git calls (−22.7%)**, distinct 118 → 86, both sides reproducing EXACTLY
across 2 interleaved reps under their own PATH-shadowed wrappers; wall clock base 3.66-3.79s
against tip 3.33-3.49s, disjoint. **A FIXTURE-SOLO PAIR WAS PUBLISHED AND WITHDRAWN BY ITS OWN
CONTROL**: the base run was timed under the census's git wrapper and the tip run was not, at ~8ms
× 9146 calls ≈ 73s of instrument on one side only, so 267.17s → 221.16s was void — **and the
subtraction that "corrected" it to ~194s was void too**, making the tip read as a regression.
Re-taken unwrapped and interleaved, rc asserted, 274 assertions all four runs: **240.85-256.75s
against 220.17-234.45s**, disjoint, **−8.6%**. Stdout and stderr
byte-identical at 104 rows with a control proving `cmp` can report a difference, and the assertion
**LABEL SET** identical at 274 — not merely the count, which is exactly what a reordering can
preserve while moving a verdict.

**THE MUTATION ANCHORS WERE CHECKED BEFORE THE FIXTURE RAN, NOT AFTER.** Two of them key on the
lines that moved. A reordering changes no anchored line's BYTES, so both survived —
`named-anchor-unique` still resolves to exactly 1 line and `mut-bound`'s `--format=%[hH]
"$THEIRS"` still counts 4 sites, the same as at `HEAD`, against a control of 0 for an impossible
format letter. Had one moved, the mutant would have run the unmutated path and read as a pass.

**BATCH 127 SHIPPED `v0.597.0` AND IT REFUTED ACTION 1's NAMED TARGET FOR THE SECOND RELEASE
RUNNING — THIS TIME THE MEMO, NOT THE ARM TABLE.** Action 1 said "FINISHING THE RECONCILE MEMO IS
THE NEXT TARGET" and `reconcile-emit-report` sat at #2 in the record, 320 pool-seconds behind the
513s pole. Its census killed the scope: **one invocation is 93 git calls / 76 distinct = 1.22x**,
`self-update-gate`'s shape, which the plan already recorded as NOT this lever. The whole fixture's
14490 calls against 300 distinct is redundancy ACROSS ~156 invocations in separate processes.

**THE PER-INVOCATION TABLE THEN OFFERED ITS OWN WRONG TARGET.** `hash-object` at 12 calls to 2
distinct files is **6.00x**, the top row — and 12 forks of a 2s render. The same instrument failure
`v0.596.0` recorded for the by-arm fork table, one level down: **a ratio ranks redundancy, not
cost.**

**THE REAL SUBJECT WAS A CHILD PROCESS, FOUND BY ABLATION.** Timing every detector the renderer
drives, 3 interleaved reps with rc asserted: `unregistered-drift.sh` is **586-661ms of a
1456-1556ms render — 43%**, against the next-largest at 163-165ms. The fix was `--bucket-rows`, a
flag that already existed, that `apply.sh:504` had passed since it existed, and that
`emit-report.sh` never passed while computing the exact rows one call above it: **NOFLAG
789-949ms against FLAG 610-723ms**, 5 interleaved reps, byte-compared every rep, disjoint.

**THE EQUIVALENCE WAS OWNED AND THE CALLER WAS NOT, WHICH IS WHY IT WENT UNSEEN.**
`apply-drift-after-write/run.sh:430` asserts the flagged and standalone scans agree row-for-row and
`:442` asserts an empty rows file does not acquit — both about the SCAN. **Nothing bound the
RENDERER to the flag.** `B1` now greps the executing line, because a whole-file grep is satisfied
by prose: probed under `mktemp` in both directions it reports the base renderer, stays quiet on the
flagged one, and still reports a base renderer carrying the flag in a COMMENT, where `grep -cF`
reads 1 and acquits.

**A TIMING DIFFERENTIAL WAS CONTAMINATED BY THE FIX BEING COPIED INTO ITS OWN BASE TREE.** The
main checkout was the "BASE" side of a background run while the branch was being assembled in it,
so rep 2's base was the tip. Caught by grepping that rep's own output for the new arm — 83
assertions where a real base emits 81. **A differential's base must be a tree the session cannot
write**; re-run in two fixed `git worktree` checkouts.

**BATCH 126 SHIPPED `v0.596.0` AND IT REFUTED THIS PLAN'S OWN TARGETING RULE BEFORE IT SHIPPED
ANYTHING.** Action 1 named `I75` next on fork count. Timed, `I75` is **0.86s net** of a ~41s
validator. The by-arm table is a SPOTTING instrument and not a cost ranking, and the warning it
already carried from `v0.592.0` — a fork count is a proxy, not the cost — was firing on the
selection made one paragraph below it.

**THE FIRST CORRECTION WAS ALSO WRONG, AND THAT IS THE DURABLE HALF.** Subtracting a baseline
taken from an arm OUTSIDE the block scored `I61` 4.75s and `I64` 4.67s, which inverted the target
a second time. `--arms` on an INDENTED id runs the whole enclosing unit (`BL-274`); the
discriminating line is `I41`, four forks, **4.29s**. A memo was then built against `I64`,
byte-identical in output and a REGRESSION in forks — 181 → 234, file 3203 → 3257 — and reverted
unshipped. **Two wrong scopings in one session, both from an instrument nobody had questioned.**

**THE REAL SUBJECT WAS `I65`, FOUND ONLY BY ABLATION**, and it never appeared in the fork table's
top four. One line: the step (c) vocabulary prefilter, 2.23-2.26s bounded-ERE against 0.79-0.83s
`grep -F -f`. Whole validator 40.78-42.86s → 39.54-39.93s, 4 interleaved reps, non-overlapping,
stdout and stderr byte-identical with a control proving `cmp` can report a difference.

**TWO ABLATIONS WERE DISCARDED AS BROKEN RATHER THAN READ**, which is why every figure above
carries an asserted `rc=0`. One removed `I61`'s emitters and left the declaration; the renderer's
"declared arm contains no err/warn/fail call" guard refused it at exit 2. A second read 1.02s
against a 4.29s base — a 4x win — and its exit code was **1**. Both would have shipped a wrong
attribution.

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
