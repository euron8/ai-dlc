# graph pull — v0.231.0 operator handoff

**Repo you will be working in: `/Users/n8/git/graph`.**
**Authoring repo, which you only READ from: `/Users/n8/git/ai-dlc`.**

This delivers **one** release, v0.231.0, and its whole content is a defect class removed
from twenty-one files you already have. There is no new mechanism, no contract change and
no scheduling change. It is the least exciting pull this program has produced, and that is
the point: the sweep found **zero live instances in the distribution**, so all of its value
is in the consumer.

---

## 0. How to use this file, and WHICH REPO YOU ARE IN

Work the **§5 Progress Ledger** top to bottom. Execute the first row whose Status is `—`,
then **tick it in this file with a measured figure or a sha** before moving on. A row
ticked with prose is not ticked.

Every row says which repo it runs in. Rows 1–7 are all in `graph`. **Nothing in this brief
edits `ai-dlc`** except this file's own ledger, which you tick in place.

---

## 1. State at handoff, measured 2026-07-31

| | value |
|---|---|
| `graph` `origin/main` | `16460a676` |
| `graph` stamp | `version: 0.230.0` / `commit: 8e3876f` |
| `ai-dlc` `origin/main` | `65b2f2f`, VERSION **0.231.0** |
| releases behind | **one** |

**If `graph` has moved since**, re-derive the gap from `git log` rather than trusting the
table — that is §6c-5's standing instruction and D-6c5.2 records what it nearly broke:

```
git -C /Users/n8/git/graph log --oneline origin/main -3
git -C /Users/n8/git/graph show origin/main:.claude/.ai-dlc-version | head -2
```

---

## 2. Locked decisions — do not re-litigate

1. **One branch, one PR.** The release is a single sweep; splitting it buys nothing.
2. **The remedy is the here-string form, `<<<"$(cmd)"`.** Dropping `-q` and redirecting to
   `/dev/null` was measured and **rejected**: whether a bare `grep` reads to EOF when its
   output goes to `/dev/null` is an implementation question, and a remedy that depends on
   which `grep` you have installed is not a remedy. Do not "simplify" the swept lines back.
3. **`0 error(s), 2 warning(s)` is the PASS condition**, before and after. It has been the
   clean-consumer reading since v0.225.0 and this release does not move it.
4. **This is not a performance change.** The timings in §4.3 are a sanity bound, not a
   before/after pair, and nothing in this pull should be quoted as a speed result.

---

## 3. Non-negotiable discipline

- **Write nothing before row 4.** Rows 1–3 are measurement.
- **Row 3 cannot be retaken** once row 4 lands. Bank it.
- **Report a zero with its control**, every time. A probe that returns nothing has either
  found nothing or run against the wrong path, and only the control tells you which.
- **Do not fix anything you find in `ai-dlc`.** Report it; it becomes a step in the plan.

---

## 4. What the REHEARSAL found — read this before row 1

Rehearsed end-to-end on a `git clone --local` of `graph` at `16460a676`, using the real
`apply.sh` from a pinned engine worktree at `65b2f2f` and graph's own `.githooks/pre-push`.
**graph itself was never written to** — verified after the fact: `origin/main` unmoved and
the working tree's only four entries still the pre-existing `_bmad-output/` ones.

### 4.1 The pull is clean — no hard blocker, no decision, no conflict

`apply.sh` exits **0** with **0 bytes of stderr** and **18 `RESOLVED` rows and nothing
else** — 15 `pure-apply`, plus `relabel`, `restamp` and `consistent`. `hard-blockers.sh`
returns **NONE** both before and after. That is the second consecutive clean pull, after a
program in which it had never happened once.

### 4.2 What the release actually changes

`I54` bans a shell variable written into a reader that stops at its first match — the
`printf … | grep -q` shape, whose pipeline status under `pipefail` becomes the *writer's*
`EPIPE` once the input outgrows the pipe buffer, so the test answers "not found" on input
that contains the pattern.

Its grammar required three things the defect does not: a builtin writer, the reader as the
immediately next stage, and both on one physical line. **Twenty-two sites in the
distribution sat in that gap, and twenty-one of them ship to you.** Your copies carry every
one.

Two of the swept files also gain an assertion, and this is the part worth understanding
before you read row 6's expectations:

> `layer-qualifier-grain` and `fixture-drivability` build mutants through a helper called
> as `` if m="$(mutate …)" ``. Their "this mutation matched nothing" guard called `bad`
> **inside that command substitution**, so the warning was captured as the helper's return
> value and its failure count died in the subshell. A mutation that stopped landing
> therefore skipped its assertion in **silence** — no red, no diagnostic, exit 0, `PASS`,
> one fewer check than the run before it. Both now record the unlanded mutation to a file
> and assert on it at the end, which is why their assertion counts go **up by one**.

### 4.3 Timings — a sanity bound, NOT a before/after pair

| | readings | median |
|---|---|---|
| before, your 0.230.0 tree | 41.05 *(rc=1, see §4.4)*, 39.13, 39.89 | **39.89s** |
| after, first run — glob order by design | 38.92 | — |
| after, warm | 39.27, 39.46, 39.08 | **39.27s** |

**Do not quote this as a win.** The release changes no scheduling; these numbers exist only
to catch a pull that made the gate dramatically worse. Anything inside a couple of seconds
is noise.

### 4.4 The intermittent, and why it is not this pull's fault

One rehearsal rep went red on **`check-substrate-audit`**, and the standalone pass caught
**`check-il-oracle-presence`** once. Both are `D-6c9.4`'s known race: three graph-owned
fixtures delegate to `scripts/tests/test-s168-retro-gates.sh`, which runs `set -euo
pipefail` with assertions piped into `grep -q` at `:111`, `:465`, `:483`, `:582` — the same
class this release fixes upstream, in a file **only a `graph` session may edit**.

**It fires on both sides of the pull.** Re-run rather than debug. **The same fixture red
twice running is a different fact** — report it and stop.

*This is worth naming plainly: the release you are pulling fixes this exact class in every
file core ships, and cannot touch the four instances in your own driver. Fixing those is a
`graph` decision and is deliberately not in this brief.*

### 4.5 One core-side item you may see and must NOT fix here

Your `layer-qualifier-grain` will still contain **one** line matching the swept construct
after the pull. That is correct and matches core exactly — it is a site the invariant's two
narrowings exclude on measurement, not an oversight. Do not sweep it by hand.

---

## 5. Progress Ledger

**This is the steering. Execute the first row whose Status is `—`, then tick it here.**

| # | Row | Repo | Status |
|---|---|---|---|
| 1 | Pre-flight: clean tree, pin the engine, confirm graph has not moved under this file | graph | **DONE** — `main` @ `16460a676` (unmoved); 4 porcelain entries, all `_bmad-output/`; stamp `0.230.0`/`8e3876f`; hook **20547** bytes; engine pinned `/tmp/pull-engine-0231` @ `65b2f2f`, VERSION **0.231.0** |
| 2 | Classify only. Report all six tallies. **Write nothing.** | graph | **DONE** — (1) 57 rows, exit 0, **0** stderr bytes: `EXTENSION-OK` 38 / `OVERRIDE-OK` 12 / `OVERRIDE-DOUBLE-SHADOW` 2 / `OVERRIDE-DELEGATES-INTO-SHADOW` 2 / `OVERRIDE-ASSERTS-SHADOW-SURVIVES` 2 / `EXTENSION-RESTATES-CORE` 1, `EXTENSION-HOOK-DRIFT` **0**, `HARD-LAYER-ADJUDICATION-MISSING` **0**. (1)-control @`04cea81`: `EXTENSION-HOOK-DRIFT` **3**, `HARD-LAYER-ADJUDICATION-MISSING` **3**, `EXTENSION-OK` 35 — the two zeros are readings. (2) **no `HARD-` row** (grep rc=1); (2)-control **64** rows, reader live. (3) 64 rows: `CORE-OK` 61, `CORE-TEMPLATE-SUBSTITUTED` 3, `HARD-UNREGISTERED-CORE-DRIFT` **0**. (4) verbatim: `STILL-LIVE` **46**, `HAND-REVIEW` 12, `NEEDS-REVIEW` 3, `ENTRY-SWALLOWED` 3, `NAMED-UPSTREAM` 2, `CLOSE-CANDIDATE` **0** — 66 rows, same total as the brief's 45/1 split, residue moved independently. (5) exit 0, `0 error(s), 2 warning(s)`, `contract_version=11 entries=50 … undeclared=0`. (6) exit 0, **identical** to (5). Zero-with-subjects: `EXTENSION-ANCHOR-DRIFT` 0 and `EXTENSION-ANCHOR-MISSING` 0 against **10** files declaring `extends:` (control **39** declare `kind:`) |
| 3 | Bank the BEFORE figures — the timing AND the per-fixture assertion counts | graph | **DONE** — (a) **109** fixtures in `/tmp/assert-before.tsv`, **zero** with `rc!=0` (§4.4's intermittent did not fire); `fixture-drivability` **9**, `layer-qualifier-grain` **27**. (b) three reps all `rc=0 ok=109 FAIL=0`: 43.20 / 42.99 / 43.01 → **median 43.01s**. Runs ~3s above the rehearsal's 39.89s median; different host, and §4.3 makes this a bound not a result. `core.bare=false` and 4 porcelain entries after the reps |
| 4 | `apply` on ONE branch, and verify what did and did NOT arrive | graph | **DONE** — branch `chore/ai-dlc-update-0.231.0`; `apply.sh` exit **0**, **0** stderr bytes, **18** rows all `RESOLVED` (15 `pure-apply` + `relabel` + `restamp 8e3876f -> 65b2f2f` + `consistent`). Porcelain: **16** modified pull paths (`.claude/.ai-dlc-version`, `scripts/ai-dlc/validate-layer-entries.sh`, 14 under `tests/fixtures/`), `.githooks/pre-push` **not** among them, 4 `_bmad-output/` entries untouched. Both `.dist-only` fixtures **absent**; drivable fixtures **109**. Probes, each with its byte control: swept form in validator **1** (`:1112`, control 100415 B), guard `layer-qualifier-grain` **1** (control 15791 B), guard `fixture-drivability` **1** (control 9509 B). §4.5 residual confirmed present and correctly unswept — **1** line, `layer-qualifier-grain/run.sh:203`, and it is a **comment** (control: 14 `grep` lines in that file). NOTE for §6c-19: the three `grep -c` probes first read **0** under this session's `grep` shell-wrapper; re-deriving under `bash -c` gave **1**. A brief that runs these probes without a byte control would have read a manufactured STOP |
| 5 | Advance the machinery stamp | graph | **DONE** — `apply` had already written `version: 0.231.0` / `commit: 65b2f2f`; advanced `skill_version` and `skill_commit` `0.230.0`/`8e3876f` → **0.231.0**/**65b2f2f**. `git diff` on the stamp shows **exactly 4** changed lines — `installed_at: 2026-06-13T13:56:26Z` and `upstream:` preserved byte-for-byte |
| 6 | The assertion-count delta, full pre-push, commit, push, PR | graph | **DONE** — (a) delta is **exactly the two expected lines and nothing else**, both upward: `fixture-drivability: 9 -> 10`, `layer-qualifier-grain: 27 -> 28`; control — the `join` paired **109/109** rows, so the two-line result is a reading and not an empty join; **0** fixtures with `rc!=0` after. (b) warm-up 42.88s then 43.65 / 43.88 / **45.64** → **median 43.88s**, every rep `rc=0 ok=109 FAIL=0`; validator `0 error(s), 2 warning(s)`. (c) staged **16** paths, the 4 `_bmad-output/` entries left unstaged; diff **16 files, +76 / −31** (brief said ~+74/−29; the extra +2/−2 is row 5's skill-stamp pair). Commit **`a76da9dc3`**, pushed, pre-push green on the real push (`pre-push: all gates green`), PR **#840**. `core.bare=false` throughout |
| 7 | Report back the readings plan §6c-19 needs | graph | **DONE** — PR #840 `MERGED` 2026-08-01T03:28:36Z; `origin/main` **`a0f36ec94`**. Both stamp pairs at **`0.231.0` / `65b2f2f`**. Guard probe **1** against its **15791**-byte control. Validator `0 error(s), 2 warning(s)`. Assertion-count delta verbatim: `fixture-drivability: 9 -> 10` and `layer-qualifier-grain: 27 -> 28`, no third line, neither downward. Medians **43.01s** (row 3b) and **43.88s** (row 6b) — a **sanity bound, not a result**; §4.3 says the release changes no scheduling and neither figure may be quoted as a speed outcome. §4.4's intermittent **never fired** — 109 green on all seven full runs. §6c-19 note: the three row-4 `grep -c` probes read a false **0** under this session's `grep` shell-wrapper and **1** under `bash -c`; only the byte controls distinguished the two, and a brief carrying those probes without a paired control would manufacture a STOP |

---

## 6. Rows

### Row 1 — pre-flight. In `graph`. Write nothing.

```
cd /Users/n8/git/graph
git rev-parse --abbrev-ref HEAD; git rev-parse HEAD
git status --porcelain | wc -l
cat .claude/.ai-dlc-version
wc -c < .githooks/pre-push
```

**EXPECT:** `main`; HEAD `16460a676` **or later** (if later, run §1's re-derivation);
a working tree whose only entries are under `_bmad-output/`; stamp `version: 0.230.0` /
`commit: 8e3876f`; the hook at **20547 bytes**, which is the control making the readings
above a reading rather than a bad path.

**Pin the engine** so nothing depends on the other repo's working state:

```
git -C /Users/n8/git/ai-dlc worktree add --detach /tmp/pull-engine-0231 65b2f2f
cat /tmp/pull-engine-0231/VERSION      # EXPECT 0.231.0
```

**STOP CONDITION:** `VERSION` is anything but `0.231.0`.

---

### Row 2 — classify only. Report all six tallies. **Write nothing.** In `graph`.

```
E=/tmp/pull-engine-0231; B=8e3876f; T=65b2f2f; G=/Users/n8/git/graph
cd $G

# (1) the classifier
bash $E/core/skills/ai-dlc-update/reconcile/layer-drift.sh $E $B $T $G > /tmp/drift.tsv
echo "exit=$?  rows=$(wc -l < /tmp/drift.tsv)"
cut -f1 /tmp/drift.tsv | sort | uniq -c | sort -rn

# (1) CONTROL — the WIDE span. The null span does not discriminate here.
bash $E/core/skills/ai-dlc-update/reconcile/layer-drift.sh $E 04cea81 $T $G | cut -f1 | sort | uniq -c | sort -rn

# (2) the blockers
bash $E/core/skills/ai-dlc-update/reconcile/hard-blockers.sh $E $B $G $T | grep '^HARD-'

# (2) CONTROL — the reader is live even when it prints nothing
bash $E/core/skills/ai-dlc-update/reconcile/unregistered-drift.sh $E $B $G $T | wc -l

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
| (1) | **57 rows**, exit 0, **0 bytes of stderr**. `EXTENSION-OK` 38, `OVERRIDE-OK` 12, `OVERRIDE-DOUBLE-SHADOW` 2, `OVERRIDE-DELEGATES-INTO-SHADOW` 2, `OVERRIDE-ASSERTS-SHADOW-SURVIVES` 2, `EXTENSION-RESTATES-CORE` 1. **`EXTENSION-HOOK-DRIFT` 0, `HARD-LAYER-ADJUDICATION-MISSING` 0** |
| (1) control | **3** `EXTENSION-HOOK-DRIFT`, **3** `HARD-LAYER-ADJUDICATION-MISSING`, 35 `EXTENSION-OK` — this is what makes the two zeros above readings |
| (2) | **NOTHING.** No `HARD-` row at all |
| (2) control | **64** rows, so the reader is live and (2)'s silence is a finding |
| (3) | **64 rows**: `CORE-OK` 61, `CORE-TEMPLATE-SUBSTITUTED` 3, `HARD-UNREGISTERED-CORE-DRIFT` **0** |
| (4) | `STILL-LIVE` 45, `HAND-REVIEW` 12, `NEEDS-REVIEW` 3, `ENTRY-SWALLOWED` 3, `NAMED-UPSTREAM` 2, `CLOSE-CANDIDATE` 1. **REPORT VERBATIM — this reads your residue, which moves independently of the pull. It is not a tally to match.** |
| (5) | exit **0**, `0 error(s), 2 warning(s)`, `contract_version=11 entries=50 … undeclared=0` |
| (6) | exit **0**, `0 error(s), 2 warning(s)`, `contract_version=11`. **Identical to (5)** — this release does not touch the contract |

**STOP CONDITIONS.** Any status in (1) outside that table. **Any `HARD-` row in (2)**. (5)
or (6) reporting anything but `0 error(s), 2 warning(s)`.

**IMPOSSIBLE ZEROS, stated rather than counted as clean:** `EXTENSION-ANCHOR-DRIFT` and
`EXTENSION-ANCHOR-MISSING` read 0 against a non-empty subject set — 10 entries declare
`extends:` (control: 39 declare `kind:`). Report it as a zero-with-subjects, not as clean.

---

### Row 3 — bank the BEFORE figures. In `graph`. Still writing nothing.

**Both halves of this row are unrepeatable** once row 4 lands.

**(a) The per-fixture ASSERTION COUNTS.** This is the instrument this brief adds, and the
reason is §4.2: a fixture whose mutation stops landing goes *quieter*, not red, and a green
suite does not report that.

```
cd /Users/n8/git/graph
for d in tests/fixtures/*/; do
  [ -f "$d/run.sh" ] || continue
  o="$(bash "$d/run.sh" 2>&1)"; rc=$?
  printf '%s\t%s\t%s\n' "$(basename "$d")" "$rc" "$(printf '%s' "$o" | grep -cE '^ *(ok|FAIL) ')"
done | sort > /tmp/assert-before.tsv
wc -l < /tmp/assert-before.tsv      # EXPECT 109
grep -E '^(layer-qualifier-grain|fixture-drivability)' /tmp/assert-before.tsv
```

**EXPECT 109 fixtures**, and specifically `fixture-drivability` at **9** and
`layer-qualifier-grain` at **27**. One or two fixtures may report `rc=1` here — §4.4's
intermittent. Note which and continue.

**(b) The timing.**

```
for i in 1 2 3; do
  /usr/bin/time -p bash .githooks/pre-push </dev/null > /tmp/before$i.out 2>/tmp/before$i.time
  echo "rep $i: rc=$? $(grep real /tmp/before$i.time) ok=$(grep -c '^   ok  ' /tmp/before$i.out) FAIL=$(grep -c '^   FAIL' /tmp/before$i.out)"
done
```

**EXPECT** three runs around **40s**, `ok` **109**. A red run from §4.4's fixtures is
expected noise — re-run it and say so. **Record the MEDIAN.**

---

### Row 4 — `apply` on ONE branch. In `graph`.

```
E=/tmp/pull-engine-0231; B=8e3876f; T=65b2f2f; G=/Users/n8/git/graph
cd $G
git checkout -b chore/ai-dlc-update-0.231.0
bash $E/core/skills/ai-dlc-update/reconcile/apply.sh $E $B $G $T
```

**EXPECT exit 0, 0 stderr, and 18 rows, ALL of them `RESOLVED`** — 15 `pure-apply`, plus
`relabel`, `restamp 8e3876f -> 65b2f2f`, and `consistent`. **Any row that is not `RESOLVED`
is a STOP.**

```
git status --porcelain
```

**EXPECT exactly 16 modified paths**: `.claude/.ai-dlc-version`,
`scripts/ai-dlc/validate-layer-entries.sh`, and 14 under `tests/fixtures/`. Note that
`.githooks/pre-push` is **not** among them — this release does not touch the hook.

**Then verify what arrived AND what did not — both are assertions:**

```
ls -d tests/fixtures/suite-dispatch-order 2>/dev/null || echo "absent — correct"
ls -d tests/fixtures/early-exit-reader    2>/dev/null || echo "absent — correct"
for d in tests/fixtures/*/; do [ -f "$d/run.sh" ] && echo x; done | grep -c x
grep -c 'grep -Fxq -- "$kind" <<<' scripts/ai-dlc/validate-layer-entries.sh
grep -c 'mutations-that-did-not-land' tests/fixtures/layer-qualifier-grain/run.sh
grep -c 'mutations-that-did-not-land' tests/fixtures/fixture-drivability/run.sh
wc -c < tests/fixtures/layer-qualifier-grain/run.sh
```

**EXPECT:** both `.dist-only` fixtures **absent**; drivable fixtures **109** (unchanged —
this release adds no fixture you run); the swept form in the validator **1**; the new
mutation guard **1** in each of the two fixtures; and the control, that file present at
about **15.8 kB**, so a zero above would be a bad path rather than a finding.

**STOP CONDITIONS.** Either `.dist-only` fixture PRESENT. Fixture count anything but
**109**. Any of the three `grep -c` probes reading **0** while the control reads non-zero.

---

### Row 5 — advance the machinery stamp. In `graph`.

`apply` advances `version`/`commit`; the skill pair is yours.

```
cd /Users/n8/git/graph
head -4 .claude/.ai-dlc-version
```

**EXPECT** `version: 0.231.0` / `commit: 65b2f2f` already written, and
`skill_version: 0.230.0` / `skill_commit: 8e3876f` still at the old values. Advance those
two to **0.231.0 / 65b2f2f**, preserving `installed_at` and `upstream` byte-for-byte.

---

### Row 6 — the assertion-count delta, full pre-push, commit, push, PR. In `graph`.

**(a) The delta first — this is the row's real assertion.**

```
cd /Users/n8/git/graph
for d in tests/fixtures/*/; do
  [ -f "$d/run.sh" ] || continue
  o="$(bash "$d/run.sh" 2>&1)"; rc=$?
  printf '%s\t%s\t%s\n' "$(basename "$d")" "$rc" "$(printf '%s' "$o" | grep -cE '^ *(ok|FAIL) ')"
done | sort > /tmp/assert-after.tsv
join -t"$(printf '\t')" -j1 -o 0,1.3,2.3 /tmp/assert-before.tsv /tmp/assert-after.tsv \
  | awk -F'\t' '$2!=$3{print $1": "$2" -> "$3}'
```

**EXPECT exactly two lines and nothing else:**

```
fixture-drivability: 9 -> 10
layer-qualifier-grain: 27 -> 28
```

**STOP CONDITION, and it is the most important one in this brief: any third line, or
either count moving DOWNWARD.** A count that falls is a mutation that stopped landing —
a check scoring as proven with nothing behind it. That is a core defect, not a delivery
question. Report it and stop; do not work around it.

**(b) The gate.**

```
/usr/bin/time -p bash .githooks/pre-push </dev/null > /tmp/after0.out 2>/tmp/after0.time
for i in 1 2 3; do
  /usr/bin/time -p bash .githooks/pre-push </dev/null > /tmp/after$i.out 2>/tmp/after$i.time
  echo "rep $i: rc=$? $(grep real /tmp/after$i.time) ok=$(grep -c '^   ok  ' /tmp/after$i.out) FAIL=$(grep -c '^   FAIL' /tmp/after$i.out)"
done
bash scripts/ai-dlc/validate-layer-entries.sh . | grep -E '^validate-layer-entries:'
```

**EXPECT** `ok` **109**, `FAIL` **0**, around **39s**, and the validator at
`0 error(s), 2 warning(s)`. §4.3 says why the timing is not a result.

**(c) Commit, push, PR.** Stage **only the pull's paths** — leave the pre-existing
`_bmad-output/` entries in the working tree so the PR carries the pull and not unrelated
pipeline state.

```
git add .claude/.ai-dlc-version scripts/ai-dlc/validate-layer-entries.sh tests/fixtures
git status --porcelain          # the 4 _bmad-output/ entries should remain UNSTAGED
git commit -m "chore(ai-dlc): pull v0.231.0 (I54 widened to piped early-exit readers)"
git push -u origin chore/ai-dlc-update-0.231.0
gh pr create --fill
```

**Diff surface for sanity: 16 files, about +74 / −29.**

---

### Row 7 — report back. In `graph`, read-only.

**Merge is operator-preapproved for this plan.** After the PR merges:

```
cd /Users/n8/git/graph
git checkout main && git pull
git rev-parse origin/main
head -4 .claude/.ai-dlc-version
grep -c 'mutations-that-did-not-land' tests/fixtures/layer-qualifier-grain/run.sh
wc -c < tests/fixtures/layer-qualifier-grain/run.sh
bash scripts/ai-dlc/validate-layer-entries.sh . | grep -E '^validate-layer-entries:'
```

**Tick row 7 with:** the merged sha; both stamp pairs at `0.231.0` / `65b2f2f`; the guard
probe **1** against its non-zero byte control; the validator at `0 error(s), 2 warning(s)`;
**the assertion-count delta from row 6(a) verbatim**; and the two medians from rows 3(b)
and 6(b) with a note that they are a sanity bound.

---

## 7. Known-open, deliberately out of scope

- **`D-6c9.4` / `D-6c16.1` — the SIGPIPE race in `scripts/tests/test-s168-retro-gates.sh`.**
  Four instances of the class this release fixes upstream, in a file core does not ship.
  **This is the natural follow-up to this pull and it is a `graph` decision**, not a step in
  the distribution's plan. The remedy is the one in §2 item 2.
- **`O-5` — a brief-driven pull writes no `reconcile-log-<ts>.md`.** The charter's first
  acceptance number has had no instrument since this program replaced skill-driven pulls
  with these briefs. It is being decided in `ai-dlc`, not here.
