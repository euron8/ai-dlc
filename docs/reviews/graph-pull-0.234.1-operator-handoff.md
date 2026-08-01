# graph pull — v0.233.0, v0.234.0, v0.234.1

**Operator handoff. Written in `ai-dlc`, executed by a `graph` session, merged by the operator.**

Rehearsed end-to-end on a `git clone --local` of graph at `b7ff53013`, driven by the real
`apply.sh` from a pinned engine worktree at `9857448`, with graph's own `.githooks/pre-push`.
**graph itself was never written to.**

---

## 1. What this pull carries, and why it matters more than a usual one

| release | what it is |
|---|---|
| **v0.233.0** | `reconcile/retired-fixtures.sh` — reports a core fixture the consumer still carries after core stopped shipping it |
| **v0.234.0** | **charter goal 2's core half**: the consumer declares its ai-dlc machinery inventory, and core enforces that everything declared lives in the declared home |
| **v0.234.1** | a fixture v0.234.0 shipped could not run in a consumer layout. Without it your first push after this pull is RED |

**v0.234.0 is the one that matters.** Charter goal 2 — *"consumer machinery confined to one
declared home core can police"* — was dropped by v0.232.0 and the operator voided the drop. This
release is that goal's core half. **It does not close the goal.** Goal closure is measured in the
consumer, and that is the follow-on migration, not this pull.

---

## 2. Locked decisions — do not re-open these mid-run

**2.1 — The scaffolded inventory arrives saying `none`, and `none` is a PLACEHOLDER here, not an
answer.** `apply.sh` creates `.claude/skills/ai-dlc/machinery.md` from core's template with the
literal `none` in its block. That makes `W10` silent and the gate green. **It also declares, in
graph's own tree, that this project has no ai-dlc machinery of its own — which is false.** At
least six scripts are ai-dlc machinery by the charter's own naming (§4.4). Filling the inventory in
is the follow-on step's job. **Do not treat the silent `W10` as the goal being met**, and do not
fill the inventory in during this pull — a pull branch that also performs a migration hides both.

**2.2 — The PASS condition is `0 error(s), 4 warning(s)`, unchanged from before the pull.** The
four are `W6`, `W7` and two `W9`. Nothing this pull ships adds or removes a warning. If you see
five, or three, stop and report rather than repairing.

**2.3 — Do not repair the two `W9` subjects or advance the `conforms_to` receipts here.** Both are
real and both are owed, and both are separately scheduled. Fixing them inside this branch makes
this release's own result unreadable, which is the rule every brief in this series has followed.

---

## 3. Every command's argument order, because they are NOT the same

**This is the third time a brief in this series has carried a transposed invocation, and the second
time one was caught only by a run.** The reconcile scripts genuinely differ from each other; read
this table rather than assuming.

```
apply.sh            <dist> <base> <consumer> <theirs>
layer-drift.sh      <dist> <base> <theirs>   <consumer>
ledger-reverify.sh  <dist> <base> <consumer> <theirs>
hard-blockers.sh    <dist> <base> <theirs>   <consumer>
retired-fixtures.sh <dist> <theirs> <consumer>          # three args, not four
```

**`apply.sh` with `<theirs>` and `<consumer>` swapped exits 0, writes almost nothing, and prints
`DECISION manifest-unreadable`** — it does not look like an argument error. That is exactly how the
rehearsal for this brief went wrong on its first run.

Set these once and use them everywhere below:

```
E=/tmp/pull-engine-0234      # the pinned engine worktree, see §5 row 1
B=56202bc                    # your current stamp
T=9857448                    # v0.234.1
G=/Users/n8/git/graph
```

---

## 4. Pre-measured expectations — every figure below came off the rehearsal

**4.1 — `apply.sh`: rc **0**, **0** bytes of stderr, **15 rows, all `RESOLVED`**, including
`RESOLVED machinery-scaffold .claude/skills/ai-dlc/machinery.md`.

**4.2 — Diff surface: 13 files changed, +978 / −6.** Eight modified, five new:

```
 M .claude/.ai-dlc-version
 M .claude/skills/ai-dlc-update/SKILL.md
 M .claude/skills/ai-dlc-update/reconcile/apply.sh
 M .claude/skills/ai-dlc-update/reconcile/setup-sites.md
 M .claude/skills/ai-dlc/core-manifest.md
 M .claude/skills/ai-dlc/extensions/README.md
 M .claude/skills/ai-dlc/layer-contract.yaml
 M scripts/ai-dlc/validate-layer-entries.sh
?? .claude/skills/ai-dlc-update/reconcile/retired-fixtures.sh
?? .claude/skills/ai-dlc/machinery.md
?? .claude/skills/ai-dlc/templates/machinery.md
?? tests/fixtures/consumer-machinery-inventory/
?? tests/fixtures/retired-fixture-orphan/
```

**4.3 — `hard-blockers.sh`: `0 HARD blockers`, before and after.**

**4.4 — Validator, after the pull: `0 error(s), 4 warning(s)`**, footer
`contract_version=13 entries=50 at_current=0 behind=50 undeclared=0`. **`contract_version` moves
12 → 13**, so `W6`'s worklist line will now say *"below contract_version 13"* where it said 12.
**`behind=50` is unchanged and is not damage this release did** — it has been 50 since v0.227.0.

**4.5 — Drivable fixtures: 108 → 110.** Both new fixtures ship. **Neither is `.dist-only`**, so
unlike the last two pulls you should expect them present.

**4.6 — The new fixtures' cost, measured on the rehearsal clone:**
`consumer-machinery-inventory` **6.93s**, `retired-fixture-orphan` **2.94s**. Both are well under
the consumer's known poles, so the gate's wall time should not move materially. **Report your
figures; do not match them against these** — a different box gives different numbers, and this
release changes no scheduling.

**4.7 — `retired-fixtures.sh` reports NOTHING on your tree, and that is the correct result.**
The one orphan it was built for — `tests/fixtures/enforcement-map-sites/` — you deleted in the
previous branch. A zero here is the previous step's result showing up, not a blind instrument; the
fixture that ships alongside it proves the arm fires.

---

## 5. Progress ledger — execute in order, tick each row before moving on

| # | Row | Repo | Status |
|---|---|---|---|
| 1 | Pre-flight: clean tree, pin the engine, confirm graph has not moved under this file | graph | ✅ `origin/main`=`b7ff53013`, `ls-remote` agrees; stamp `0.232.0`/`56202bc` on both pairs; engine worktree `9857448` VERSION `0.234.1`; tracked tree carries only the 4 `_bmad-output/` runtime files |
| 2 | Classify only. Report the tallies. **Write nothing.** | graph | ✅ `0 HARD blockers`; validator `0 error(s), 4 warning(s)` at `contract_version=12 entries=50 at_current=0 behind=50 undeclared=0`; layer-drift 38 EXTENSION-OK / 1 EXTENSION-RESTATES-CORE / 2 OVERRIDE-ASSERTS-SHADOW-SURVIVES / 2 OVERRIDE-DELEGATES-INTO-SHADOW / 2 OVERRIDE-DOUBLE-SHADOW / 12 OVERRIDE-OK; ledger-reverify (verbatim, not a match target) 3 ENTRY-SWALLOWED / 12 HAND-REVIEW / 2 NAMED-UPSTREAM / 3 NEEDS-REVIEW / 46 STILL-LIVE |
| 3 | Bank the BEFORE figures — timing and per-fixture assertion counts | graph | ✅ `/tmp/assert-before-0234.tsv` = **108** rows; three pre-push runs all `rc=0` at `real` 44.25 / 43.30 / 43.49 s, **median 43.49 s** (sanity bound, not a result); control on the same run: **108 `ok`, 0 `FAIL`** |
| 4 | `apply` on ONE branch, and verify what did and did NOT arrive | graph | ✅ branch `chore/ai-dlc-update-0.234.1`; `apply.sh $E $B $G $T` rc **0**, stderr **0 bytes**, **15 rows all `RESOLVED`** incl. `machinery-scaffold` + `restamp 56202bc -> 9857448`. Surface = exactly the 13 §4.2 paths (8 M / 5 new) + the 4 `_bmad-output/` files. ai-dlc-only diffstat **13 files, +976 / −4** — §4.2's +978/−6 is the post-Row-5 figure, and `.claude/.ai-dlc-version` reads `2 2` here vs the `4 4` Row 5 requires, so the 2/2 gap is exactly the pending hand edit. Arrivals: `E18\|W10` **5** hits (controls `E17\|W9`=12, `ZZ99`=0), `contract_version: 13`, `machinery.md` block = `none` (placeholder, left per §2.1), both new fixture dirs present |
| 5 | Advance the machinery stamp | graph | ✅ both pairs now `0.234.1` / `9857448`; `git diff --numstat` on `.claude/.ai-dlc-version` reads exactly **`4 4`**; `installed_at:` and `upstream:` appear as unchanged context lines in the diff |
| 6 | Full pre-push, commit, push, PR | graph | ✅ after-table **110** rows, join pairs **108**, **delta EMPTY**; validator `0 error(s), 4 warning(s)` at `contract_version=13`; pre-push `rc=0`, **110 ok, 0 FAIL**, median **44.44 s** (before 43.49 s); commit `772d45dc9`, PR [#843](https://github.com/euron8/fee_accrual_graph/pull/843), squash-merged as `56927c419`; 4 `_bmad-output/` files left unstaged |
| 7 | Report back the readings §6c-32 needs | graph | ✅ see §7 below |

### Row 1 — pre-flight

```
cd /Users/n8/git/graph
git fetch origin && git status --porcelain
git rev-parse origin/main && git ls-remote origin main
cat .claude/.ai-dlc-version
git -C /Users/n8/git/ai-dlc worktree add --detach /tmp/pull-engine-0234 9857448
cat /tmp/pull-engine-0234/VERSION
```

**EXPECT:** `origin/main` is `b7ff53013` and `ls-remote` agrees. Stamp reads `0.232.0` / `56202bc`
on **both** pairs. Engine `VERSION` reads `0.234.1`. Tracked tree carries only your pre-existing
`_bmad-output/` runtime modifications. **If `origin/main` has moved, stop** — every figure in §4
was taken against `b7ff53013`.

### Row 2 — classify only, write nothing

```
bash $E/core/skills/ai-dlc-update/reconcile/hard-blockers.sh $E $B $T $G
bash $G/scripts/ai-dlc/validate-layer-entries.sh $G | tail -3
bash $E/core/skills/ai-dlc-update/reconcile/layer-drift.sh $E $B $T $G | awk '{print $1}' | sort | uniq -c
bash $E/core/skills/ai-dlc-update/reconcile/ledger-reverify.sh $E $B $G $T | awk '{print $1}' | sort | uniq -c
```

**EXPECT:** `0 HARD blockers`. Validator `0 error(s), 4 warning(s)`, footer at
`contract_version=12`. **`ledger-reverify`'s histogram is REPORT VERBATIM, never a tally to match**
— it reads graph's own residue, which moves independently of this pull.

### Row 3 — bank the BEFORE figures

```
for d in $G/tests/fixtures/*/; do n=$(basename $d); [ -f "$d/run.sh" ] || continue
  printf '%s\t%s\n' "$n" "$(grep -cE '^\s*(ok|bad) ' $d/run.sh)"; done | sort > /tmp/assert-before-0234.tsv
wc -l < /tmp/assert-before-0234.tsv
cd $G && for i in 1 2 3; do /usr/bin/time -p bash .githooks/pre-push 2>&1 | awk '/real/{print $2}'; done
```

**EXPECT:** 108 rows. Three timed runs, all `rc=0`. **Record the median; it is a sanity bound, not
a result.**

### Row 4 — apply on ONE branch

```
cd $G && git checkout -b chore/ai-dlc-update-0.234.1
bash $E/core/skills/ai-dlc-update/reconcile/apply.sh $E $B $G $T
git status --porcelain
git diff --stat | tail -1
```

**MIND THE ARGUMENT ORDER — `$E $B $G $T`, consumer before theirs.** §3 says why.

**EXPECT:** rc 0, 0 stderr, **15 rows all `RESOLVED`** including `machinery-scaffold`. Exactly the
13 paths in §4.2, plus your 4 pre-existing `_bmad-output/` files. Then confirm the arrivals:

```
grep -c 'E18\|W10' $G/scripts/ai-dlc/validate-layer-entries.sh   # the new arms landed
grep -m1 'contract_version:' $G/.claude/skills/ai-dlc/layer-contract.yaml   # 13
sed -n '/```/,/```/p' $G/.claude/skills/ai-dlc/machinery.md | head -3        # the scaffold
ls $G/tests/fixtures/consumer-machinery-inventory $G/tests/fixtures/retired-fixture-orphan
```

### Row 5 — advance the machinery stamp

`apply` writes the `version`/`commit` pair. Set `skill_version`/`skill_commit` by hand to
`0.234.1` / `9857448`. **EXPECT `git diff --numstat` on that file to read exactly `4 4`.** Preserve
`installed_at:` and `upstream:` byte-for-byte.

### Row 6 — assertion delta, full pre-push, commit, push, PR

```
cd $G && for d in tests/fixtures/*/; do n=$(basename $d); [ -f "$d/run.sh" ] || continue
  printf '%s\t%s\n' "$n" "$(grep -cE '^\s*(ok|bad) ' $d/run.sh)"; done | sort > /tmp/assert-after-0234.tsv
join -t"$(printf '\t')" /tmp/assert-before-0234.tsv /tmp/assert-after-0234.tsv | awk -F'\t' '$2!=$3'
bash scripts/ai-dlc/validate-layer-entries.sh . | tail -3
for i in 1 2 3; do /usr/bin/time -p bash .githooks/pre-push 2>&1 | awk '/real/{print $2}'; done
```

**EXPECT:** the join pairs **108** rows and the delta is **EMPTY** — this pull changes no existing
fixture's assertion count; it only adds two new fixtures, which the join cannot pair and therefore
does not report. **Any line at all, or any count moving downward, is a hard stop.**

Validator `0 error(s), 4 warning(s)`, footer `contract_version=13`. Pre-push `rc=0`, **110 ok, 0
FAIL**. Commit, push, open the PR. Leave the 4 `_bmad-output/` runtime files unstaged.

### Row 7 — report back

Each with its control: `origin/main`'s new sha and `ls-remote` agreeing; both stamp pairs;
the validator's final line and both footer lines verbatim; the assertion-delta output verbatim;
both pre-push medians and the `ok`/`FAIL` counts; and the contents of the scaffolded
`machinery.md` block.

---

## 6. Known-open, deliberately out of scope

- **The `conforms_to: 9` receipts** — `behind=50`, three contract versions stale, scheduled
  separately. Not this branch.
- **The two `W9` citations** — `scripts/ssm-tunnel.sh` and `scripts/smoke-test.sh` do not exist.
  Real, owed, scheduled separately. Not this branch.
- **Filling in the machinery inventory** — the whole point of v0.234.0, and the follow-on step.
  This pull only makes the file exist.
- **`W7` / `Check 11b`** — a dangling check pointer, pre-existing.

---

## 7. Row 7 — the readings, each with its control

Executed 2026-08-01 in `/Users/n8/git/graph`. All seven rows green, no deviation from §4 except
one figure that resolved to expectation once the Row-5 hand edit landed (noted in Row 4).

**`origin/main` and its control.** `git rev-parse origin/main` →
`56927c4199ca8685acebdfd49e32c9cfb54ea5b1`; `git ls-remote origin main` →
`56927c4199ca8685acebdfd49e32c9cfb54ea5b1	refs/heads/main`. The two agree. Pre-pull it was
`b7ff5301328b2547cd0f7c4a965f34b0b1b2a781` on both, so §4's figures were taken against the
tree §5 required.

**Both stamp pairs.** `.claude/.ai-dlc-version` on merged `main`:

```
version: 0.234.1
commit: 9857448
skill_version: 0.234.1
skill_commit: 9857448
installed_at: 2026-06-13T13:56:26Z
upstream: https://github.com/euron8/ai-dlc
```

`installed_at:` and `upstream:` are byte-for-byte their pre-pull values — they appear as unchanged
context lines in `git diff`, and the file's `--numstat` read exactly `4 4` as Row 5 requires.

**Validator, final line and both footers, verbatim, on merged `main`:**

```
validate-layer-entries: 0 error(s), 4 warning(s)
LAYER_CONFORMANCE v1 contract_version=13 entries=50 at_current=0 behind=50 undeclared=0 errors=0 warnings=4
LAYER_MEASURED v1 enforcer=validate-layer-entries.sh contract_version=13 codes=27 fired=3 silent_with_subjects=24 unclaimed=none subjects=override:12,extension:38 measured=E1=LC-O1:0/12,E2=LC-O2:0/12,E3=LC-O3:0/12,E8=LC-O10:0/12,E7=LC-O11:0/12,E4=LC-E1:0/38,E5=LC-E2:0/38,E9=LC-E9:0/38,E10=LC-E10:0/38,E11=LC-E11:0/38,E12=LC-E12:0/38,E13=LC-E13:0/38,E14=LC-E16:0/38,W2=LC-E8:0/38,E6=LC-N1:0/38,W1=LC-N2:0/38,W4=LC-N3:0/38,E15=LC-N5:0/38,E16=LC-N6:0/38,W8=LC-N7:0/38,E18=LC-M1:0/50,W10=LC-M2:0/50,W3=LC-R1:0/50,W7=LC-R2:1/50,W9=LC-R3:2/50,E17=LC-C1:0/50,W6=LC-C2:1/50
```

Its control is the same three lines taken in Row 2, before anything was written — identical but for
`contract_version=12`, `codes=25`, `silent_with_subjects=22`, and the absence of `E18`/`W10`. The
warning count is `4` on both sides, so §2.2's PASS condition held rather than being restored. The
four are `W6`×1, `W7`×1, `W9`×2 — `fired=3` across three codes, matching. `behind=50` is identical
on both sides and is not this release's doing.

**Assertion delta, verbatim.** The join printed nothing:

```
after rows: 110
joined rows: 108
--- delta (expect empty) ---
--- end delta ---
```

110 after against 108 before, the join pairing 108 and reporting zero lines. The two unpaired rows
are the arriving fixtures, which the join cannot pair and therefore does not report — exactly §6's
predicted shape. No count moved in either direction.

**Pre-push medians and the `ok`/`FAIL` counts.** Three runs each side, every run `rc=0`:

| | run 1 | run 2 | run 3 | median | `ok` | `FAIL` |
|---|---|---|---|---|---|---|
| before | 44.25 | 43.30 | 43.49 | **43.49 s** | 108 | 0 |
| after | 44.72 | 44.44 | 44.44 | **44.44 s** | 110 | 0 |

Both new fixtures appear by name in the after-run as `ok    consumer-machinery-inventory` and
`ok    retired-fixture-orphan`, so the 110 is two fixtures driven and not two lines counted. The
+0.95 s is within the spread of the before-runs themselves; per §4.6 these are reported, not matched
against the rehearsal's figures. The real push ran the gate again live and printed
`pre-push: all gates green.`

**The scaffolded `machinery.md` block, verbatim:**

```
none
```

Left exactly as `apply.sh` wrote it. Per §2.1 this is a placeholder and not an answer: it declares
in graph's own tree that the project has no ai-dlc machinery of its own, which is false. `W10` is
silent because of it (`W10=LC-M2:0/50`), and that silence is **not** charter goal 2 being met.

**Two things §5 did not ask for, recorded because they are this pull's other arm.**
`hard-blockers.sh` printed `0 HARD blockers` both before and after. `retired-fixtures.sh $E $T $G`
— three args — exited `0` with **zero lines** of output, which §4.7 calls the correct result: the
orphan it was built for was deleted in the previous branch, and the fixture shipping alongside it is
what proves the arm is not blind.

**Method note.** Every fixture tally was re-derived under an explicit `bash -c` rather than the
session's `grep`, which is a shell-snapshot function that undercounts the real binary. The arrival
greps were each run beside a positive and a negative control (`E18\|W10`=5, `E17\|W9`=12,
`ZZ99`=0) so that a zero could be distinguished from a pattern that never matches.
