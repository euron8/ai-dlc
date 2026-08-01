# graph pull 0.230.0 — operator handoff

**Two releases: v0.229.0 (the fixture pool dispatches longest-first) and v0.230.0 (which
fixes what v0.229.0 cost you). Take them together — v0.229.0 alone makes your pre-push
21.7% slower, measured.**

Target `8e3876f`, VERSION **0.230.0**. Base — the commit graph is stamped at today —
**`5879f70`**, VERSION 0.228.0.

---

## 0. How to use this file, and WHICH REPO YOU ARE IN

Every row below runs in **`/Users/n8/git/graph`**. This file lives in `/Users/n8/git/ai-dlc`
and you are writing your ledger ticks into it there; that is deliberate and it is the
only thing you write outside graph.

**Work the §5 Progress Ledger top to bottom. Execute the first row whose status is `—`,
tick it with a measured value, and stop at any row that says STOP.** A row ticked with
prose is not ticked.

**ONE SESSION AT A TIME.** While you are executing this file, no `ai-dlc` session may
branch, check out, or reset in that repo — it would yank this file out from under you
mid-read. That is D-6c8.1 and it has already happened once.

---

## 1. State at handoff, measured 2026-07-31

| | value |
|---|---|
| graph `origin/main` | `d2b69420f` |
| graph stamp | `version: 0.228.0` / `commit: 5879f70` |
| graph drivable fixtures | **109** |
| `ai-dlc` `origin/main` | **`8e3876f`**, VERSION **0.230.0**, in sync (`0 0`) |
| releases in this pull | **two** — v0.229.0 and v0.230.0 |

**If graph's HEAD has moved past `d2b69420f`,** check whether the move touched the layer
before trusting any tally here:

```
cd /Users/n8/git/graph
git diff --name-only d2b69420f HEAD -- .claude/skills/ai-dlc/ | wc -l
git diff --name-only d2b69420f HEAD | wc -l          # CONTROL: non-zero if HEAD moved at all
```

**Zero on the first line means every tally in this file still holds.** Non-zero: report
it and escalate before row 2.

---

## 2. Locked decisions — do not re-litigate

1. **Both releases ride in ONE branch.** v0.229.0 on its own is a measured regression for
   you; splitting them means deliberately landing that. There is no separable value in
   the split.
2. **The expected post-pull gate reading is `0 error(s), 2 warning(s)`, exit 0** — the
   same as your pre-pull reading. Neither release touches the layer contract;
   `contract_version` stays **11**.
3. **`suite-dispatch-order` must NOT appear in your tree.** It is `.dist-only`. Its
   absence is a PASS condition, not an omission — that is the whole content of v0.230.0.
4. **`check-substrate-audit`, `check-ff-escalation` and `check-il-oracle-presence` may
   fail intermittently. This is yours, it predates this pull, and the remedy is to
   re-run.** §4.4 has the evidence and the rule.

---

## 3. Non-negotiable discipline

- **Argument order differs between the reconcile scripts and getting it wrong produces a
  clean-looking run:**
  ```
  # layer-drift.sh        <dist> <base> <theirs>   <consumer>
  # ledger-reverify.sh    <dist> <base> <consumer> <theirs>     <-- 3rd and 4th SWAPPED
  # hard-blockers.sh      <dist> <base> <consumer> <theirs>
  # unregistered-drift.sh <dist> <base> <consumer> [theirs]
  ```
- **Report a zero only with the control that ran in the same invocation.** Every expected
  zero below carries one.
- **A core defect you find is fixed in `ai-dlc` and re-delivered — never patched here.**
  Stop and hand back.
- **The merge is the operator's.** No agent self-authorizes one.

---

## 4. What the REHEARSAL found — read this before row 1

Rehearsed end-to-end on a `git clone --local` of graph at `d2b69420f`: the real
`apply.sh` from a pinned engine, the real merge, graph's own `.githooks/pre-push`. **graph
itself was never written to.**

### 4.1 This pull has NO hard blocker — a first for this program

`hard-blockers.sh` returns **nothing**. The `HARD-UNREGISTERED-CORE-DRIFT` on
`extensions/README.md` that made plan step 11 exist was closed by your 0.228.0 migration.
Control that the reader is live: `unregistered-drift.sh` returns 64 rows in the same pass.

### 4.2 What the two releases actually change

v0.229.0 makes both pre-push hooks dispatch the fixture pool **longest-first**, using a
durations record the previous run writes to `.git/ai-dlc-fixture-durations`. It is
invisible to `git status`, it is never committed, and if it is missing or malformed the
suite runs in plain glob order — slower, never shorter.

v0.230.0 moves that mechanism's *proof* out of the fixture you run. v0.229.0 added ~30s
of assertions to `consumer-suite-pool`, which is shipped to you; in the distribution that
was a passenger against a 151s pole, and **on your suite it became the pole** at 40s
against a next-heaviest 29s.

### 4.3 The before/after, both halves on one box in one session

| | readings | median |
|---|---|---|
| before, your current 0.228.0 hook | 40.68, 40.85, 42.01 | **40.85s** |
| after, **first run** — glob order, NOT the after-figure | 41.09 | — |
| after, warm | 38.99, 38.97, 39.00 | **38.99s** |

**4.6% off your whole pre-push.** The distribution measured 7.2% off the *fixture step*
alone; the two reconcile — 2.4s off ~30s of fixtures is 7.9%, and off a 41s gate that
also runs ~11s of other gates it is 4.6%. **When you quote a number, say which one it
is.**

**Your first post-pull run has no durations record yet, so it is glob order by design.
Do not measure the release on it.** The second run is the one.

### 4.4 The intermittent, and why it is not this pull's fault

Four post-pull runs produced two with failures — `check-substrate-audit` and
`check-ff-escalation`. **The control is what makes this reportable rather than alarming:
four runs on the restored PRE-pull tree produced one with a failure, so it fires on both
sides.** Solo, each is 0 of 6.

All three affected fixtures — those two plus `check-il-oracle-presence` — delegate to
**your** `scripts/tests/test-s168-retro-gates.sh`, which runs `set -euo pipefail` with
assertions piped into `grep -q` (`:111`, `:465`, `:483`, `:582`). `grep -q` exits on the
first match and SIGPIPEs a still-writing upstream, so the pipeline status is 141 and the
assertion takes its false branch. It needs a loaded scheduler, which is why it appears
under a 16-way pool and never solo.

**RULE FOR ROW 6: if one of those three is red, re-run the gate. If the SAME fixture is
red on two consecutive runs, that is a different fact — stop and report it.** The file is
yours and only a `graph` session may edit it; fixing it is not part of this pull.

### 4.5 One core-side item you may see and must NOT fix here

`tests/fixtures/apply-drift-refile/run.sh:28` has the same construct and failed once in
four post-pull runs (0 of 8 solo). **That file is core's.** It is recorded upstream as a
gap in invariant I54's subject set and is scheduled there. Report it if you see it; do
not edit it.

---

## 5. Progress Ledger

| # | Row | Repo | Status |
|---|---|---|---|
| 1 | Pre-flight: clean tree, pin the engine, confirm graph has not moved under this file | graph | **DONE 2026-07-31** — `main` @ `d2b69420f83f35a400c830e8b9ffe8d18d5a57cc` (unmoved, §1 check not needed); porcelain 4 entries, all `_bmad-output/`; stamp `version: 0.228.0` / `commit: 5879f70`; `DURATIONS_RECORD` **0** against hook **16657 bytes** (control non-zero); engine pinned `/tmp/pull-engine-0230` @ `8e3876f`, VERSION **0.230.0** |
| 2 | Classify only. Report all six tallies. **Write nothing.** | graph | **DONE 2026-07-31** — (1) **57 rows**, exit 0, **0 stderr bytes**; `EXTENSION-OK` 38, `OVERRIDE-OK` 12, `OVERRIDE-DOUBLE-SHADOW` 2, `OVERRIDE-DELEGATES-INTO-SHADOW` 2, `OVERRIDE-ASSERTS-SHADOW-SURVIVES` 2, `EXTENSION-RESTATES-CORE` 1, `EXTENSION-HOOK-DRIFT` **0**, `HARD-LAYER-ADJUDICATION-MISSING` **0** — exact match. (1) control @ `04cea81`: `EXTENSION-HOOK-DRIFT` **3**, `HARD-LAYER-ADJUDICATION-MISSING` **3**, `EXTENSION-OK` 35 — reader live, zeros are readings. (2) **0 `HARD-` rows** (3 non-HARD rows emitted, 0 stderr) — §4.1 holds. (3) **64 rows**: `CORE-OK` 61, `CORE-TEMPLATE-SUBSTITUTED` 3, `HARD-UNREGISTERED-CORE-DRIFT` **0**. (4) verbatim, 66 rows: `STILL-LIVE` **46**, `HAND-REVIEW` 12, `NEEDS-REVIEW` 3, `ENTRY-SWALLOWED` 3, `NAMED-UPSTREAM` 2, `CLOSE-CANDIDATE` **0** — residue moved by one since the brief was written (the sample's lone `CLOSE-CANDIDATE` now reads `STILL-LIVE`; total unchanged at 66). (5) exit **0**, `0 error(s), 2 warning(s)`, `contract_version=11 entries=50 … unclaimed=none`. (6) exit **0**, `0 error(s), 2 warning(s)`, `contract_version=11 entries=50 at_current=0 behind=50 undeclared=0` — identical to (5). **IMPOSSIBLE ZEROS stated:** `EXTENSION-ANCHOR-DRIFT` and `EXTENSION-ANCHOR-MISSING` are **0 rows against a non-empty subject set** — 10 entries declare `extends:`, control 39 declare `kind:`. No STOP condition met |
| 3 | Bank the BEFORE figure — it cannot be retaken after row 4 | graph | **DONE 2026-07-31** — 3 reps on the 0.228.0 hook, all `rc=0`, all `ok=109`, `FAIL=0`: **44.92, 44.73, 44.87** → **MEDIAN 44.87s**. **0 red runs**; none of §4.4's three fixtures fired. This box is slower than the rehearsal box (44.87 vs 40.85), so row 6 must be compared against **this** number, not against §4.3's |
| 4 | `apply` on ONE branch, and verify what did and did NOT arrive | graph | **DONE 2026-07-31** — branch `chore/ai-dlc-update-0.230.0`; `apply.sh` exit **0**, **0 stderr bytes**, **`RESOLVED` × 5** (`pure-apply` git-hooks/pre-push, `pure-apply` fixtures/consumer-suite-pool/run.sh, `relabel` ext-check collisions, `restamp` 5879f70→8e3876f, `consistent` tree matches 8e3876f). Changed by apply: exactly the three expected paths (`.claude/.ai-dlc-version`, `.githooks/pre-push`, `tests/fixtures/consumer-suite-pool/run.sh`); the 4 `_bmad-output/` entries are row-1 pre-existing operational state, untouched. Assertions: `DURATIONS_RECORD` **4**; hook **IDENTICAL** to `$E/core/git-hooks/pre-push`; `EXPECTED_ASSERTIONS=14` **1**; `suite-dispatch-order` **absent — correct**; fixtures **109**. No STOP condition met |
| 5 | Advance the machinery stamp | graph | **DONE 2026-07-31** — `apply` had already written `version: 0.230.0` / `commit: 8e3876f`, with the skill pair still at `0.228.0` / `5879f70` as expected. Both advanced to **`skill_version: 0.230.0` / `skill_commit: 8e3876f`**; `installed_at: 2026-06-13T13:56:26Z` and `upstream: https://github.com/euron8/ai-dlc` preserved byte-for-byte |
| 6 | Full pre-push, the AFTER figure, commit, push, PR | graph | **DONE 2026-07-31** — 4 reps: rep 1 (glob order, discarded) **44.44s**; warm reps **43.68, 43.17, 43.06** → **MEDIAN 43.17s**. Durations record **109 lines** from rep 1 onward, untracked (`git status` sees 0). Pole is **`layer-readopt-gate` 30** (then `layer-qualifier-grain` 28, `layer-crosswalk-home` 27); **`consumer-suite-pool` records 9s** — a passenger, so v0.230.0 landed, not v0.229.0 alone. **1 red run: rep 2, `check-substrate-audit`** (`ok=108 FAIL=2`) — §4.4's known intermittent, green on reps 3 and 4, so **noise, not a fact**. Delta vs row 3: **44.87 → 43.17 = 1.70s, 3.8% off the whole pre-push** (the whole-gate figure, not the fixture-step figure). Commit **`a651d9e73`**, pushed; `git ls-remote` returns the same sha (control). PR **#839** — https://github.com/euron8/fee_accrual_graph/pull/839. **DEVIATION from the brief's `git add -A`:** staged only the three pull paths; the 4 pre-existing `_bmad-output/` entries were left in the working tree so the PR carries the pull and not unrelated pipeline state |
| 7 | Report back the readings plan §6c-16 needs | graph | **DONE 2026-07-31** — merge was **operator-preapproved in-session**; PR #839 squash-merged, branch deleted, `main` fast-forwarded. `git rev-parse origin/main` → **`16460a676831898a7fc2f5f7e76cfa6d4bf79fc8`**. `head -4 .claude/.ai-dlc-version` → `version: 0.230.0` / `commit: 8e3876f` / `skill_version: 0.230.0` / `skill_commit: 8e3876f` — **both pairs advanced**. `grep -c DURATIONS_RECORD .githooks/pre-push` → **4**, against hook **20547 bytes** (control non-zero; was 16657 pre-pull). `grep -c 'EXPECTED_ASSERTIONS=14'` → **1**. `validate-layer-entries.sh .` → exit **0**, **`0 error(s), 2 warning(s)`**, `contract_version=11 entries=50 at_current=0 behind=50 undeclared=0`. **The two figures only this session can produce: BEFORE median 44.87s (3 runs, 0 red) → warm AFTER median 43.17s (3 warm runs, 1 red — `check-substrate-audit` on the first warm rep, green on both following, so §4.4 noise). 1.70s, 3.8% off the whole pre-push gate on this box.** No `apply-drift-refile` failure was observed in any of the 7 runs (§4.5 not reproduced here) |

---

## 6. Rows

### Row 1 — pre-flight. In `graph`. Write nothing.

```
cd /Users/n8/git/graph
git rev-parse --abbrev-ref HEAD; git rev-parse HEAD
git status --porcelain | wc -l
cat .claude/.ai-dlc-version
grep -c DURATIONS_RECORD .githooks/pre-push
wc -c < .githooks/pre-push
```

**EXPECT:** `main`; HEAD `d2b69420f` **or later** (if later, run §1's two-line check);
a working tree whose only entries are under `_bmad-output/`; stamp `version: 0.228.0` /
`commit: 5879f70`; `DURATIONS_RECORD` **0** — you do not have the mechanism yet; the hook
at **16657 bytes**, which is the control making that zero a reading rather than a bad
path.

**Pin the engine** so nothing depends on the other repo's working state:

```
git -C /Users/n8/git/ai-dlc worktree add --detach /tmp/pull-engine-0230 8e3876f
cat /tmp/pull-engine-0230/VERSION      # EXPECT 0.230.0
```

**STOP CONDITION:** `VERSION` is anything but `0.230.0`.

---

### Row 2 — classify only. Report all six tallies. **Write nothing.** In `graph`.

```
E=/tmp/pull-engine-0230; B=5879f70; T=8e3876f; G=/Users/n8/git/graph
cd $G

# (1) the classifier
bash $E/core/skills/ai-dlc-update/reconcile/layer-drift.sh $E $B $T $G > /tmp/drift.tsv
echo "exit=$?  rows=$(wc -l < /tmp/drift.tsv)"
cut -f1 /tmp/drift.tsv | sort | uniq -c | sort -rn

# (1) CONTROL — the WIDE span. The null span does not discriminate here.
bash $E/core/skills/ai-dlc-update/reconcile/layer-drift.sh $E 04cea81 $T $G | cut -f1 | sort | uniq -c | sort -rn

# (2) the blockers
bash $E/core/skills/ai-dlc-update/reconcile/hard-blockers.sh $E $B $G $T | grep '^HARD-'

# (3) in-place core drift
bash $E/core/skills/ai-dlc-update/reconcile/unregistered-drift.sh $E $B $G $T | cut -f1 | sort | uniq -c | sort -rn

# (4) the ledger
bash $E/core/skills/ai-dlc-update/reconcile/ledger-reverify.sh $E $B $G $T | cut -f1 | sort | uniq -c | sort -rn

# (5) YOUR installed validator — the pre-pull baseline
bash scripts/ai-dlc/validate-layer-entries.sh . | tail -2

# (6) the ENGINE's validator against graph — what the pull will install
bash $E/core/scripts/validate-layer-entries.sh $G | grep -E '^validate-layer-entries:|^LAYER_CONFORMANCE'
```

**EXPECTED TALLIES:**

| probe | expected |
|---|---|
| (1) | **57 rows**, exit 0, 0 stderr. `EXTENSION-OK` 38, `OVERRIDE-OK` 12, `OVERRIDE-DOUBLE-SHADOW` 2, `OVERRIDE-DELEGATES-INTO-SHADOW` 2, `OVERRIDE-ASSERTS-SHADOW-SURVIVES` 2, `EXTENSION-RESTATES-CORE` 1. **`EXTENSION-HOOK-DRIFT` 0, `HARD-LAYER-ADJUDICATION-MISSING` 0** |
| (1) control | **3** `EXTENSION-HOOK-DRIFT`, **3** `HARD-LAYER-ADJUDICATION-MISSING`, 35 `EXTENSION-OK` — this is what makes the zeros above a reading |
| (2) | **NOTHING.** No `HARD-` row at all — §4.1 |
| (3) | **64 rows**: `CORE-OK` 61, `CORE-TEMPLATE-SUBSTITUTED` 3, `HARD-UNREGISTERED-CORE-DRIFT` **0** |
| (4) | `STILL-LIVE` 45, `HAND-REVIEW` 12, `NEEDS-REVIEW` 3, `ENTRY-SWALLOWED` 3, `NAMED-UPSTREAM` 2, `CLOSE-CANDIDATE` 1. **REPORT VERBATIM — this reads your residue, which moves independently of the pull. It is not a tally to match.** |
| (5) | exit **0**, `0 error(s), 2 warning(s)`, `contract_version=11 … unclaimed=none` |
| (6) | exit **0**, `0 error(s), 2 warning(s)`, `contract_version=11`. **Same as (5)** — neither release touches the contract |

**STOP CONDITIONS.** Any status in (1) outside that table. **Any `HARD-` row in (2)** —
this brief expects none, and one means the tree moved. (5) or (6) reporting anything but
`0 error(s), 2 warning(s)`.

**IMPOSSIBLE ZEROS, stated rather than counted as clean:** `EXTENSION-ANCHOR-DRIFT` and
`EXTENSION-ANCHOR-MISSING` are 0 against a non-empty subject set — 10 entries declare
`extends:` (control: 39 declare `kind:`). Report it.

---

### Row 3 — bank the BEFORE figure. In `graph`. Still writing nothing.

**This is the half that cannot be retaken.** Once row 4 lands, your 0.228.0 hook is gone.

```
cd /Users/n8/git/graph
for i in 1 2 3; do
  /usr/bin/time -p bash .githooks/pre-push </dev/null > /tmp/before$i.out 2>/tmp/before$i.time
  echo "rep $i: rc=$? $(grep real /tmp/before$i.time) ok=$(grep -c '^   ok  ' /tmp/before$i.out) FAIL=$(grep -c '^   FAIL' /tmp/before$i.out)"
done
```

**EXPECT** three runs around **41s**, `ok` **109**. A red run from one of §4.4's three
fixtures is expected noise — re-run it and say so.

**Record the MEDIAN, not the mean**, and record it in this file's row 3 tick. Row 6 needs
it and no later session can reproduce it.

---

### Row 4 — `apply` on ONE branch. In `graph`.

```
E=/tmp/pull-engine-0230; B=5879f70; T=8e3876f; G=/Users/n8/git/graph
cd $G
git checkout -b chore/ai-dlc-update-0.230.0
bash $E/core/skills/ai-dlc-update/reconcile/apply.sh $E $B $G $T
```

**EXPECT exit 0, 0 stderr, `RESOLVED` × 5**, and exactly three changed paths:

```
git status --porcelain
```
```
 M .claude/.ai-dlc-version
 M .githooks/pre-push
 M tests/fixtures/consumer-suite-pool/run.sh
```

**Then verify what arrived AND what did not — both are assertions:**

```
grep -c DURATIONS_RECORD .githooks/pre-push          # EXPECT 4
cmp -s .githooks/pre-push $E/core/git-hooks/pre-push && echo IDENTICAL
grep -c 'EXPECTED_ASSERTIONS=14' tests/fixtures/consumer-suite-pool/run.sh   # EXPECT 1
ls -d tests/fixtures/suite-dispatch-order 2>/dev/null || echo "absent — correct"
for d in tests/fixtures/*/; do [ -f "$d/run.sh" ] && echo x; done | grep -c x   # EXPECT 109
```

**STOP CONDITIONS.** `suite-dispatch-order` PRESENT — `.dist-only` failed and v0.230.0's
whole content did not land. `EXPECTED_ASSERTIONS` reading anything but **14** — you have
v0.229.0's shipped fixture and not v0.230.0's, which is the 9-second regression. Fixture
count anything but **109**.

---

### Row 5 — advance the machinery stamp. In `graph`.

`apply` advances `version`/`commit`; the skill pair is yours to advance.

```
cd /Users/n8/git/graph
head -4 .claude/.ai-dlc-version
```

**EXPECT** `version: 0.230.0` / `commit: 8e3876f` already written, and
`skill_version: 0.228.0` / `skill_commit: 5879f70` still at the old values. Advance those
two to **0.230.0 / 8e3876f**, preserving `installed_at` and `upstream` exactly.

---

### Row 6 — full pre-push, the AFTER figure, commit, push, PR. In `graph`.

**Run the gate FOUR times. The first is glob order and is discarded — §4.3.**

```
cd /Users/n8/git/graph
for i in 1 2 3 4; do
  /usr/bin/time -p bash .githooks/pre-push </dev/null > /tmp/after$i.out 2>/tmp/after$i.time
  echo "rep $i: rc=$? $(grep real /tmp/after$i.time) ok=$(grep -c '^   ok  ' /tmp/after$i.out) FAIL=$(grep -c '^   FAIL' /tmp/after$i.out) record=$(grep -c . .git/ai-dlc-fixture-durations 2>/dev/null || echo 0)"
done
sort -k2,2nr .git/ai-dlc-fixture-durations | head -3
```

**EXPECT:** rep 1 around **41s**; reps 2–4 around **39s**, `ok` **109**; the record
**109 lines** from rep 1 onward; and the top of the record to be **`layer-readopt-gate`**
at ~28 with `consumer-suite-pool` nowhere near it. **If `consumer-suite-pool` is your
pole, row 4's stop condition was missed** — you have v0.229.0 without v0.230.0.

**Re-run rule for §4.4's three fixtures: red once is noise, red twice on the same fixture
is a fact. Report which happened.**

Then commit, push, open the PR. **Do not merge — that is the operator's.**

```
git add -A
git commit -m "chore(ai-dlc): pull v0.229.0 + v0.230.0 (fixture pool dispatches longest-first)"
git push -u origin chore/ai-dlc-update-0.230.0
gh pr create --fill
git rev-parse HEAD; git ls-remote origin refs/heads/chore/ai-dlc-update-0.230.0
```

The last two lines are the control that the push actually landed the sha you think it
did.

---

### Row 7 — report back. In `graph`, read-only.

Plan §6c-16 needs exactly these, and it will re-derive them rather than take your word —
so report the command output, not a summary:

```
cd /Users/n8/git/graph
git rev-parse origin/main                                   # after the operator merges
head -4 .claude/.ai-dlc-version                             # EXPECT both pairs 0.230.0 / 8e3876f
grep -c DURATIONS_RECORD .githooks/pre-push                 # EXPECT 4
wc -c < .githooks/pre-push                                  # CONTROL, must be non-zero
grep -c 'EXPECTED_ASSERTIONS=14' tests/fixtures/consumer-suite-pool/run.sh
bash scripts/ai-dlc/validate-layer-entries.sh . | tail -2   # EXPECT exit 0, 0 error(s), 2 warning(s)
```

**Plus the two figures only you can produce: the row 3 BEFORE median and the row 6 warm
AFTER median, with the number of red runs on each side.**

---

## 7. Known-open, deliberately out of scope

- **`test-s168-retro-gates.sh`'s SIGPIPE race** (§4.4). Yours, predates this pull, needs
  its own branch. Recorded upstream as D-6c9.4.
- **`apply-drift-refile`'s same construct** (§4.5). Core's. Recorded upstream as a gap in
  I54's subject set.
- **`LAYER_CONFORMANCE … behind=50`.** Every entry declares a `conforms_to` below the
  current `contract_version`. That is `W6`'s migration worklist and is not this pull's
  work.
