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
| 1 | Pre-flight: clean tree, pin the engine, confirm graph has not moved under this file | graph | — |
| 2 | Classify only. Report the tallies. **Write nothing.** | graph | — |
| 3 | Bank the BEFORE figures — timing and per-fixture assertion counts | graph | — |
| 4 | `apply` on ONE branch, and verify what did and did NOT arrive | graph | — |
| 5 | Advance the machinery stamp | graph | — |
| 6 | Full pre-push, commit, push, PR | graph | — |
| 7 | Report back the readings §6c-32 needs | graph | — |

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
