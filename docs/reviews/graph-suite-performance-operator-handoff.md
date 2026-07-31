# The consumer suite's performance — operator handoff

**Repo for every numbered row: `graph`.** Written by an `ai-dlc` session, executed by `graph`
sessions, merged by the operator. Same methodology as
`graph-pull-0.224.0-operator-handoff.md`: every tally below carries the invocation that produced
it and a control returning non-zero in the same run, every row states its stop conditions, and
**no row asks you to re-derive a figure this file states**.

---

## 0. How to use this file, and WHICH REPO YOU ARE IN

**EVERY ROW RUNS IN `graph`. THERE IS ONE SESSION AT A TIME.** Read §1–§5 in full, execute the
first unticked row in the §5 Progress Ledger, and tick it with a sha or a measured count as that
row's last act. Stop at each ⏹ FRESH SESSION marker. Do not open an `ai-dlc` session unless a
tally deviates from its stated expectation or a stop condition fires.

`/Users/n8/git/graph` is the consumer. `/Users/n8/git/ai-dlc` is the distribution and **you never
write to it** — not the tree, not a branch, not a worktree. If a row's finding belongs upstream,
record it in the row and hand back.

**§6 rows 1–3 are blocked on an `ai-dlc` release. Rows 4 and 5 are not, and they go FIRST — run
after the pool lands, they measure a baseline that no longer exists and cannot be recovered.**
Row 6 reports back and is last. **So the order is 4, 5, ⏹, then the release, then 1, 2, 3, 6** —
not "wait for the release".

**Two things to know before you start, so neither arrives as a surprise mid-row:**

1. **This file may be UNTRACKED in `ai-dlc` when you read it.** It was authored while another
   session held that working tree and could not be committed safely. It is real and it is the
   whole of this workstream; if `git -C /Users/n8/git/ai-dlc ls-files --error-unmatch
   docs/reviews/graph-suite-performance-operator-handoff.md` exits non-zero, say so in your row
   and carry on — the plan tracks committing it as obligation **O-1** and it is not your row.
2. **A future `ai-dlc` pull at 0.225.0 or later changes your clean reading from `0 error(s), 0
   warning(s)` to `0 error(s), 2 warning(s)`** — `W6` (a contract-version worklist line, one per
   run, by design) and `W7` (`Check 11b`, a real dangling citation). **Zero errors, so nothing
   wedges.** If you are running these rows after such a pull, that is the expected baseline and
   not a regression to hunt.
Row 0 is the DONE-CHECK that tells you which world you are in; run it before believing any other
sentence here.

---

## 1. Why this file exists, measured

The distribution has spent four releases on suite performance — `v0.205.0`, `v0.206.0`,
`v0.224.0`, and the gate that governs them — and **none of it reaches a consumer.** The strategy
lives in `ai-dlc`'s own repo-local `.githooks/pre-push`, which is not the file consumers receive.

`install.sh:454` copies `core/git-hooks/pre-push` into a consumer's `.githooks/pre-push`, and
that is a **different file** from the one the distribution runs on itself:

| | `ai-dlc`'s own `.githooks/pre-push` | `core/git-hooks/pre-push`, the one you get |
|---|---|---|
| lines | 313 | **208** |
| pool — `xargs -P` | 3 | **0** |
| `AI_DLC_FIXTURE_JOBS` | 2 | **0** |
| content-key skip (`suite-content-key`) | 5 | **0** |
| completeness arm (`n_expected`, "no verdict recorded") | 5 / 1 | **0 / 0** |
| empty-suite guard ("no fixtures found") | 1 | **0** |

Control on the extraction: both files exist and both define `run_fixtures`; a bogus token returns
0 against each in the same invocation.

**And graph runs exactly that file, byte-for-byte** — `cmp -s core/git-hooks/pre-push
/Users/n8/git/graph/.githooks/pre-push` reports identical. So the consumer's whole fixture suite
is this, over **106** drivable fixture directories:

```
run_fixtures() {
  local rc=0 d
  for d in tests/fixtures/*/; do
    [ -f "$d/run.sh" ] || continue
    if bash "$d/run.sh" >/dev/null 2>&1; then
      printf '   ok    %s\n' "$(basename "$d")"
    else
      printf '   FAIL  %s\n' "$(basename "$d")"; rc=1
    fi
  done
  return $rc
}
```

Serial, one at a time, on a box with 18 cores.

Fixture counts, measured in graph: **116 directories, 106 with a `run.sh`**; of the 116, **88 are
shipped by core and 28 are graph's own**, and **20** of those 28 carry a `run.sh` and are timed
below. Controls: 88 + 28 = 116 exactly, so the two sets partition the directories; and the same
comparison the other way returns **5** core directories absent from graph, which is the known
`.dist-only` count. *(Compare DIRECTORIES, not `ls` output: `tests/fixtures/` also holds
`MANIFEST`, `README.md`, `fixture-hashes.lock` and a `.yml`, and counting those made an earlier
pass of this file report 32 graph-owned fixtures against a 116-directory total that could not
contain them.)*

### The two findings that are not about speed at all

**(a) The consumer's suite passes when it runs NOTHING.** The shipped `run_fixtures` returns 0
when the glob matches no directory and when every directory lacks a `run.sh`. The distribution's
own hook fails closed on exactly that — *"no fixtures found -- an empty suite passes every
assertion it never made"* — and **that guard was never shipped** (1 occurrence upstream, 0 in the
consumer's copy). This is the repo's named defect class, sitting in the gate a consumer actually
runs.

**(b) A fixture that never ran is invisible.** The shipped loop prints a verdict inline and keeps
no per-fixture record, so there is no `n_expected` / `n_actual` comparison. The distribution's
hook records each verdict to a file and fails on a missing one, *"because `xargs` collapses any
number of failures into one exit code that cannot say WHICH"*. In the serial consumer loop the
equivalent hole is a fixture whose directory is skipped by the `[ -f ]` test — it reads exactly
like a fixture that passed.

**Both are correctness gaps that the performance work is the occasion to close, not a reason to
defer.** They are cheap and they ship in the same release as the pool.

### Why the consumer cannot fix this itself

`install.sh:445` marks the hook **"always overwrite — upstream-owned"**. A consumer that adds a
pool to its own `.githooks/pre-push` loses the edit at the next pull, silently, and its suite goes
serial again with nothing reporting the regression. **So the mechanism has to ship from core.**
That is row 1's dependency and it is structural rather than a scheduling preference.

---

## 2. Locked decisions — do not re-litigate

1. **The consumer gets the same strategy, not a weaker one.** Pool, derived job list, per-fixture
   verdict files, completeness assertion, empty-suite guard. A carve-out that gives the consumer
   a reduced version is the shape §4b of the governing plan forbids.
2. **The knob stays a knob.** `AI_DLC_FIXTURE_JOBS` is tunable because it was measured on one
   machine; the consumer re-derives it rather than inheriting the distribution's 16.
3. **`§7`'s performance gate binds consumer-owned fixtures too.** Profile the schedule and never
   the durations, `user` vs `system` is the diagnosis, a constant justified by a measurement
   expires when that measurement's subject moves, and a perf refactor ships the three-part proof.
4. **Measurement decides the ORDER of optimisation, never the membership.** A unit measured as
   saving nothing today is scheduled, not dropped.

---

## 3. Non-negotiable discipline

- **A zero is not a finding.** Every command whose answer is an absence carries a control in the
  same invocation that comes back non-zero. Report both.
- **Profile the SCHEDULE, not the durations** — once a pool exists. A serial suite is the
  degenerate case where every unit is a pole, which is why §4's numbers are durations and why
  they stop being the right instrument the moment row 1 lands.
- **A perf refactor ships a three-part proof**, because byte-identical output on a passing tree
  proves nothing about whether a check still FIRES: a differential over the same inputs with the
  baseline run in a `cp -R` copy, a mutation battery per unit, and a knock-out control.
- **Never run the suite in a tree another session is writing.** These measurements were taken on
  a `git clone --local` of graph; graph itself was never written to.
- Traps that have each cost this program a wrong reading: `RC=$?` inside `$( )` never reaches the
  caller — write it to a file; unquoted `$var` does not word-split in zsh; guard every mutant
  with `cmp -s`; and **a profiler must never export a generic variable name** (`OUT`, `TMP`) into
  the environment of the suite it measures — one that exported `OUT` had its own output deleted
  mid-run, twice.

---

## 4. What the MEASUREMENT found — read this before row 4

**Taken on a `git clone --local` of graph at `9b5d408a3` with the 0.224.0 pull applied, running
the consumer suite exactly as the shipped hook runs it: serial, `bash run.sh >/dev/null 2>&1`.
`nice -n 10`, while another session was working, so treat these as an upper bound on a quiet box
and a fair reading of the machine as it is actually used.**

**All 106 fixtures exit 0, so the baseline is attributable** — a red suite would make every timing
under it meaningless. Control: the run recorded 106 verdicts against the 106 drivable directories
§1 counts, so nothing was skipped.

| figure | measured |
|---|---|
| **serial wall clock** | **188.0s** (sum of durations 183.3s) |
| **max single fixture** | **18.0s** — the floor a perfect pool could reach |
| **sum ÷ max** | **10.2x** speed-up available from a pool |
| **total `user` / `system`** | **67.8s user / 102.3s SYSTEM — ratio 1.51** |
| non-zero exit codes | **0 of 106** |

Top eight by duration:

| fixture | duration | user | system |
|---|---|---|---|
| `layer-readopt-gate` | 18.04s | 7.52 | **11.16** |
| `layer-qualifier-grain` | 16.74s | 6.72 | **13.99** |
| `ledger-reverify` | 10.13s | 4.03 | 4.83 |
| `wait-stale-deliverable` | 9.61s | 1.30 | 3.05 |
| `check-24-adversarial-convergence` | 8.76s | 2.58 | **5.98** |
| `layer-catalog-collision` | 6.22s | 2.25 | **4.79** |
| `layer-conforms-to` | 5.96s | 2.31 | **4.56** |
| `ledger-reverify-unfalsifiable` | 5.56s | 2.32 | 2.53 |

### The two findings that decide what is worth doing

**(1) The consumer suite is FORK-BOUND, not work-bound.** System time exceeds user time across
the whole suite — 102.3s against 67.8s — and the gap widens on the heaviest units, where system is
roughly double user. That is §7 gate item 2's signature exactly: *a run with system above user is
process creation, not work.* **A pool makes a fork-bound suite finish sooner while burning the
same CPU; it does not make it cheaper.** Both fixes are worth having and they are different fixes,
and the ratio says which one the distribution should reach for after the pool.

**(2) The graph-owned fixtures are 4.2% of the cost — 7.8s of 183.3s, across the 20 of 28 that
are drivable.** Control, the same join over the core-shipped set: **175.5s = 95.8%**, and
7.8 + 175.5 = 183.3 exactly. The heaviest graph-owned unit is
`check-27-config-integrity` at **1.07s**. Every unit in the top eight is core-shipped, which graph
may not edit. **So there is essentially nothing for the consumer to optimise in its own fixtures,
and row 5's stop condition fires by construction rather than by judgement.** The entire consumer
lever is the shipped hook, and the entire remainder of the cost is the distribution's.

**Caveat, stated rather than smoothed.** These were taken on a `git clone --local`, `nice -n 10`,
while another session was working the same box. They are an upper bound for a quiet machine and a
fair reading of the machine as it is used. The three ratios — 10.2x, 1.51, 4.2% — are far enough
from their decision boundaries that contention does not change any conclusion, and row 4 confirms
them on the real box anyway.

### Row 4's confirmation on the real box — 2026-07-31, graph at `ff444f656`

**Confirmed. All three ratios reproduce; no stop condition fires.** Taken on graph's own machine
(18 cores), in `git clone --local . /tmp/graph-perf-baseline`, serial, `bash "$d/run.sh"` from the
repo root exactly as the shipped hook runs it, no `nice`. Results written outside the copy; the
path was held in `LEDGER_SINK`, never `OUT`/`TMP`/`WORK`/`DIR`. The suite was run **twice** because
run 1 carried one failure (below).

| ratio | §4 pre-measured | run 1 | run 2 | verdict |
|---|---|---|---|---|
| `sum ÷ max` | 10.2x | 9.6x | **10.2x** | confirmed — nowhere near the 1x that would kill row 1 |
| `system ÷ user` | 1.51 | 1.48 | **1.47** | confirmed — system above user, suite is fork-bound |
| graph-owned share | 4.2% | 4.5% | **4.3%** | confirmed — well under row 5's 10% threshold |

Absolute seconds, as expected, differ but barely: wall 187s / 182s against §4's 188.0s; sum 186.0s
/ 181.1s against 183.3s; `max` is `layer-readopt-gate` in both runs (19.38s / 17.68s). Set
partition re-derived over DIRECTORIES: 88 core-shipped + 28 graph-owned = 116, `comm -13` returns
the 5 `.dist-only`, and the per-set cost sums back to the total exactly (7.8 + 173.3 = 181.1).
Run 2's top eight is §4's top eight — same eight units, `ledger-reverify-unfalsifiable` and
`layer-catalog-collision` trading 6th/7th. Heaviest graph-owned unit `check-27-config-integrity`
at 1.09s against §4's 1.07s.

**Finding — one INTERMITTENT fixture, reported not fixed, per this row's stop condition.**
Run 1 recorded `check-il-oracle-presence` (graph-owned; an 11-line ROUTE-1 delegation to
`scripts/tests/test-s168-retro-gates.sh`) at rc=1. It did not reproduce: rc=0 on 5 standalone
repeats and rc=0 in the full run-2 suite, where all 106 exited 0 and no failure log was written.
It is not a persistent red and the timings above are attributable — run 2 is a clean 106/106. The
driver builds temp git repos under `mktemp -d`, and cross-fixture env leakage cannot explain it
(each fixture is a separate child process), so the likely cause is a transient in that driver's
temp-repo setup rather than suite state: the clone's tree was clean and `core.bare` false both
before and after. **This is a flake in a gate that fails the whole push when it fires, so it is
worth an owner — but it is graph-owned, not upstream's.**

**§7's third open question, answered while here: the consumer's pre-push IS enabled.**
`core.hooksPath` is unset as `install.sh` leaves it, but graph carries a 5-line
`.git/hooks/pre-push` shim — *"Installed this way rather than via core.hooksPath, which would
disable .git/hooks/pre-commit"* — whose last line is
`exec "$(git rev-parse --show-toplevel)/.githooks/pre-push" "$@"`. Control: `.githooks/pre-push`
exists and is executable. So the serial suite runs on every push and the 188s is paid for real;
this is not a performance problem nobody has.

---

## 5. Progress Ledger

Tick each row **in this file** as that row's last act, with a sha or a measured count. `—` = not
started. A row ticked with prose is not ticked.

| # | Row | Repo | Status |
|---|---|---|---|
| 0 | Pre-flight: which world am I in — has the pool shipped and been pulled? | graph | **DONE 2026-07-31** — `0` / `0` / **106** drivable / `version: 0.224.0`. Pool NOT shipped; rows 1–3 blocked, start at row 4. Controls in the same run: `run_fixtures` = 2, directories = 116, both non-zero. This file is TRACKED in `ai-dlc` (O-1's untracked case does not apply; control `README.md` also tracked). |
| 4 | CONFIRM §4's pre-measured baseline on the real box (3 ratios, not the seconds) | graph | **DONE 2026-07-31** — CONFIRMED at `ff444f656`: `sum÷max` **10.2x**, `system÷user` **1.47**, graph-owned **4.3%**; 106/106 exit 0 on run 2. One intermittent (`check-il-oracle-presence`, rc=1 in run 1, 0/6 repeats). Deliverable appended to §4. |
| 5 | Confirm the **4.2%** graph-owned share and hand the lever upstream | graph | **DONE 2026-07-31** — **4.3%** (7.8s of 181.1s, 20 drivable of 28). Stop condition fired: nothing optimised. Upstream subjects named — `layer-readopt-gate` 17.68s, `layer-qualifier-grain` 14.61s, `ledger-reverify` 10.37s, all core-shipped. Carried to row 6. |
| ⏹ | **FRESH SESSION** — rows 1–3 need an `ai-dlc` release merged AND pulled | graph | |
| 1 | Verify the pulled hook carries the pool, the completeness arm and the empty-suite guard | graph | — |
| 2 | Re-derive `AI_DLC_FIXTURE_JOBS` for THIS box; do not inherit 16 | graph | — |
| 3 | Re-profile as a SCHEDULE and record the new critical path | graph | — |
| 6 | Report the before/after pair back for the plan's ledger | graph | — |

**Row order is 0, 4, 5, then the ⏹, then 1, 2, 3, 6.** Rows 4 and 5 need nothing from upstream
and are what make rows 1–3 measurable; running them after the pool would destroy the baseline.

---

## 6. Rows

### Row 0 — pre-flight. In `graph`.

```
cd /Users/n8/git/graph
grep -c 'AI_DLC_FIXTURE_JOBS' .githooks/pre-push
grep -c 'no fixtures found' .githooks/pre-push
for d in tests/fixtures/*/; do [ -f "$d/run.sh" ] && printf 'x\n'; done | wc -l
head -1 .claude/.ai-dlc-version
```

Reading: lines 1 and 2 are **0** today — the pool has not shipped. **Control, line 3 — the
drivable fixture count, which MUST be non-zero** (106 on 2026-07-31); a zero there means the
path moved and every reading above it is an absence produced by a wrong directory rather than by
an unshipped mechanism. Line 4 dates the tree.

If lines 1 and 2 are non-zero, the `ai-dlc` release has landed: skip to row 1. If they are 0,
rows 1–3 are blocked and you start at row 4.

### Row 4 — CONFIRM the baseline on the real box. In `graph`.

**§4 is already measured. Do not re-derive it** — reproduce it, on graph's own machine rather than
on the clone-under-contention where it was taken, and confirm the three ratios rather than the
absolute seconds. The seconds will differ; the ratios are what every later row keys on.

**Expect:** all 106 fixtures exit 0; `sum ÷ max` in the neighbourhood of **10x**; `system` above
`user` overall; graph-owned share around **4%**.

**Stop conditions.** Any fixture that FAILS is a finding to report, not to fix here — a red suite
makes every timing under it unattributable, and a fixture that fails in a `git clone --local` but
passes in the working tree is reading something the clone does not carry. If `sum ÷ max` comes
back near **1x**, the suite is dominated by one unit and a pool buys nothing: say so and stop,
because that inverts row 1's expectation. If `user` exceeds `system`, finding (1) is wrong on this
box and the diagnosis in §4 must be re-stated before anyone acts on it.

**Do not run the suite in graph's own tree if any other session is working in it**, and do not
run it in `/Users/n8/git/ai-dlc` at all. Take a throwaway copy:

```
cd /Users/n8/git/graph
git clone --local . /tmp/graph-perf-baseline
```

Then run each fixture serially, exactly as the shipped hook does, recording duration and the
`user`/`system` split per fixture. Write the results to a file **outside** the copy, and **do not
name the environment variable holding that path `OUT`, `TMP`, `WORK` or `DIR`** — 32 of these
fixtures reference such names and one of them deletes the directory an inherited `OUT` points at.

Record duration, exit code and the `user`/`system` split per fixture, write the results **outside**
the copy, and **do not name the environment variable holding that path `OUT`, `TMP`, `WORK` or
`DIR`**. Thirty-two fixtures in the distribution's own suite reference `OUT`, and one of them
deletes the directory an inherited `OUT` points at — it cost two lost profiling runs upstream, and
88 of those fixtures are installed here.

Deliverable: the three ratios, plus a one-line verdict — confirmed, or which one moved and why.
Append it under §4; do not overwrite the pre-measured table, because the pair is the evidence.

### Row 5 — confirm the 4.2% and hand the lever upstream. In `graph`.

**This row's stop condition is already known to fire, and it is stated here so that a session does
not spend a day discovering it.** The 88 core-shipped fixtures are the distribution's to optimise
and **you do not edit them** — they are overwritten at the next pull, the same trap §1 records for
the hook. The 28 graph-owned ones are yours, and §4 measures them at **7.8s of 183.3s = 4.2%**,
with the heaviest at 1.07s.

Derive the set rather than hand-listing it, and confirm the share on your own numbers:

```
comm -23 <(ls tests/fixtures | sort) <(ls /Users/n8/git/ai-dlc/core/fixtures | sort)
```

Control: `comm -12` over the same two inputs returns the shipped set, non-empty (**88**); a bogus
directory name appears in neither column.

**If the share is under 10%** — as measured, it is — **do not optimise anything here.** Write the
number into this row, name the top three core-shipped units from §4 as the upstream subjects, and
carry them to row 6. That is this row's correct ending, not a failure of it: the consumer's cost is
core's fixtures plus the missing pool, and a consumer-side micro-optimisation of a 1.07s fixture
would be work that measurement says is worth nothing.

#### Row 5's outcome — 2026-07-31. The stop condition fired, as predicted. Nothing optimised here.

**Measured share on graph's own box: 7.8s of 181.1s = 4.3%**, over the 20 drivable of 28
graph-owned directories (8 carry no `run.sh`). Under 10%, so per this row's own instruction no
consumer-side optimisation was attempted. The heaviest graph-owned unit is
`check-27-config-integrity` at **1.09s**, then `check-31-cited-sha` 0.88s and `cycle-commits`
0.74s — optimising the whole graph-owned set to zero would return 4.3% of a 188s suite.

Set derived, not hand-listed. Controls, all in the same invocation: `comm -12` returns the
core-shipped set **non-empty at 88**; 88 + 28 = 116, the directory total, so the two sets
partition it; `comm -13` returns the **5** `.dist-only`; and a bogus name (`zzz-not-a-fixture`)
appears in neither column (0 and 0).

**The literal command printed above returns 32, not 28, and that is the §1 trap rather than a
disagreement.** `ls tests/fixtures` lists entries, and four of them are not directories —
`MANIFEST`, `README.md`, `fixture-hashes.lock`, `mock-workflow-with-dormant-gate.yml`. 32 − 4 = 28.
Use the directory form; the literal one is left in place because it is what an earlier pass ran.

**The lever handed upstream.** The top three units by duration are all core-shipped, which graph
may not edit (control: `check-27-config-integrity` is correctly absent from the core-shipped set):

| upstream subject | run 2 | user | system | note |
|---|---|---|---|---|
| `layer-readopt-gate` | 17.68s | 7.39 | **10.54** | the pole; sets the 10.2x ceiling single-handed |
| `layer-qualifier-grain` | 14.61s | 6.20 | **11.70** | system ≈ 1.9× user, the most fork-bound unit measured |
| `ledger-reverify` | 10.37s | 4.13 | 4.87 | |

Carried to row 6. The consumer's entire remaining lever is the unshipped pool in
`core/git-hooks/pre-push`, which is row 1's dependency.

**If the share comes back ABOVE 10% on your box**, §4's finding (2) is wrong there and the row
reverts to its original shape: rank the 28, take the top one, diagnose `user` vs `system` before
changing anything, fix the cause rather than the symptom, and ship the three-part proof. One
fixture, not all of them.

### Row 1 — verify the pulled hook. In `graph`. **Needs the `ai-dlc` release merged and pulled.**

Re-run row 0's five lines. Expect lines 1 and 2 non-zero. Then assert the three properties the
release owes, each with a control:

- **the pool runs**: the suite's wall clock drops against row 4's baseline
- **the completeness arm fires**: a fixture whose verdict is missing FAILS the suite. Prove it —
  temporarily point one fixture's `run.sh` at a non-existent interpreter in the throwaway copy and
  confirm the suite goes red naming that fixture, then restore
- **the empty-suite guard fires**: an empty `tests/fixtures/` FAILS rather than passing

**Stop condition.** If the wall clock drops and the second or third assertion does not fire, the
release shipped speed without the correctness half. Report it and do not tick this row.

### Row 2 — re-derive the pool size for this box. In `graph`.

`AI_DLC_FIXTURE_JOBS` is 16 because that was measured on the distribution's box against a
critical path that has since moved twice. **Do not inherit it.** Sweep the knob across at least
`-P8`, `-P16`, `-P24` on the throwaway copy, record the wall clock at each, and record the flat
region rather than a single winner.

**Read the result honestly: a knob that cannot move the answer tells you nothing about why.** If
the sweep is flat, that is not evidence the suite is compute-bound — the distribution recorded
getting exactly this wrong in both directions, and it took a third measurement (running the heavy
units alone and concurrently) to say which. Take that third measurement before concluding.

### Row 3 — re-profile as a SCHEDULE. In `graph`.

With a pool, durations stop being the instrument. Record **start and end per fixture** and rank by
END time, then report slack per unit. The pole is the unit that ends the suite with ~0 slack;
everything else would save nothing, and the ranking says so rather than implying it.

Deliverable: the schedule table, the named critical path, and the next pole behind it.

### Row 6 — report back. In `graph`.

One comment on the PR, or one message to the operator, carrying: row 4's baseline triple, row 5's
outcome, rows 2 and 3's numbers, and any finding that belongs upstream. The plan's ledger closes
its step on these numbers.

---

## 7. Known-open, deliberately out of scope

- **The 88 core-shipped fixtures' internal cost.** Yours to measure and report, never to edit.
- **`scripts/suite-content-key.sh` is not shipped** (0 hits in `install.sh`, absent from graph),
  so the consumer has no content-keyed skip and re-runs a suite that already passed on an
  unchanged tree. Whether that should ship is an upstream question; it is named here so it is not
  discovered a third time.
- **Whether the consumer's pre-push is even enabled.** `install.sh` installs the file but
  deliberately does not run `git config core.hooksPath .githooks`. A suite nobody runs has no
  performance problem, and that is worth knowing before optimising it — row 0 does not check it,
  and it should be checked once by whoever runs row 4.
