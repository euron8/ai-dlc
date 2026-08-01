# graph pull — v0.236.0

**One release. One branch. Seven rows.** Written from a rehearsal, not from a plan: every figure
in §4 came off an end-to-end run against a `git clone --local` of graph at `b7b7e1b6a`, with the
real `apply.sh` from an engine worktree pinned at `7d2dd6a` and graph's own `.githooks/pre-push`.
**graph itself was never written to, and that was verified after the fact** — `origin/main`
unmoved, working tree still its four pre-existing `_bmad-output/` entries.

**Why this pull matters more than most.** It is the one thing standing between you and deleting
`scripts/ai-dlc-local/audit-main-since.sh`. Your own side-by-side (`docs/reviews/trunk-audit-side-by-side.md`
§4.4) named per-commit interpolation as the retirement blocker; this release is that, and nothing
else in it is load-bearing for you.

---

## 1. What this pull carries

**v0.236.0 — `capture:`, so a declared validator can take a value the audited commit determines.**

Your measurement: three of the incumbent's four retro-class obligations take the commit's sprint
number as an argument, and every argument in a `validator:` line was a literal, so none of them
could be declared. On the 6 retro-class commits in your audited range the incumbent re-ran 4
validators and `pr-classes.md` re-ran 2.

After this pull, `pr-classes.md` can say:

```
class: retro
paths: ^docs/retro/sprint-[0-9]+(-retro)?\.md$
capture: sprint ^docs/retro/sprint-([0-9]+)\.md$
validator: scripts/ai-dlc/validate-mandatory-rules.sh {sprint}
```

The regex matches the commit's **changed paths** and must be anchored `^...$`; group 1 is the
value; `{sprint}` in any `validator:` line of the same class is replaced by it.

**Exactly one value, and every other outcome is a FINDING** — zero matching paths, two paths
yielding different values, or a value containing anything outside `[A-Za-z0-9._-]` (the declared
command is `eval`ed, so a capture is an injection surface fed by your own repository's paths).

**This pull does NOT write your taxonomy.** Adopting the grammar is a separate, deliberate act and
it is §6c-38's row, not this one's.

---

## 2. Locked decisions — do not re-open these mid-run

**2.1 — The `DECISION drift` row on `extensions/README.md` is NOT this release's, and the proof is
a measurement rather than an assertion.** v0.236.0 touches **0** files under that path, against a
control of **13** files touched overall; and your copy already differs from core's **at your
current base** by 2 lines — your own step-27 edit to a core-owned worked example (`conforms_to: 9`
→ `13`). It is the same row §6c-37's pull carried for the same reason. **Leave it. Do not
"resolve" it by taking core's copy**, which would revert your edit.

**2.2 — `pr-classes.md` is yours and this pull must not touch it.** Measured: byte-identical
across the whole rehearsal (`md5` `1ed82e923f50862267960a2a8e048449` before and after, 5 classes
both ends). **If `apply` writes that file at all, STOP and report** — the scaffold-once rule is
what makes it safe to declare in, and v0.228.0 is why that rule exists.

**2.3 — `contract_version` stays 13 and every footer field is unchanged.** This release adds no
clause. **A footer field that moves is a finding, not a consequence of the pull.**

**2.4 — The drivable fixture count does NOT move.** Both fixtures already exist in their correct
places; this release only grows them. The instrument that shows delivery is the assertion count,
not the fixture count — see §2.5, which is a trap.

**2.5 — THE SERIES' ASSERTION-COUNT INSTRUMENT READS ZERO ON THE ONE FIXTURE THIS RELEASE MOVES,
and that is a defect in the instrument rather than in the delivery.** The instrument every brief
since v0.231.0 has used is

```
grep -cE '^\s*(ok|bad) ' "$d/run.sh"
```

which is **line-anchored**. `trunk-audit-classes` writes its assertions in the continuation style
(`… \` then `&& ok "…" \` then `|| bad "…"`), so not one of them starts a line and the instrument
scores it **0** — before and after. Measured on your tree: **38 of 111 fixtures score 0 under it**,
and at least 3 of those 38 demonstrably carry assertions. **A delivery check that reads 0 at both
ends of the release it is checking is a check that cannot fire.**

**So this brief uses a RUN-BASED count for the subject fixture** — the verdict lines the fixture
actually prints — and keeps the line-anchored one only for the other 110 rows, where it has
worked. Row 3 and row 6 carry both.

---

## 3. Every command's argument order, because they are NOT the same

**Fifth brief in this series to carry this table, and still not optional.**

```
apply.sh            <dist> <base> <consumer> <theirs>
layer-drift.sh      <dist> <base> <theirs>   <consumer>
ledger-reverify.sh  <dist> <base> <consumer> <theirs>
hard-blockers.sh    <dist> <base> <theirs>   <consumer>
retired-fixtures.sh <dist> <theirs> <consumer>          # three args, not four
```

**`apply.sh` with `<theirs>` and `<consumer>` swapped exits 0, writes almost nothing, and prints
`DECISION manifest-unreadable`** — a wrong-argument run that does not look like one.

Set these once and use them everywhere below:

```
E=/tmp/pull-engine-0236      # the pinned engine worktree, see §5 row 1
B=944c2e2                    # your current stamp (0.235.0)
T=7d2dd6a                    # v0.236.0
G=/Users/n8/git/graph
```

**Two instrument notes your own 0.235.0 run reported back, both false-zero sources:**

- **`apply.sh` rows are TAB-separated.** A tally grepped as `'^RESOLVED '` — with a space —
  returns a vacuous **0** against real rows. §4.1 renders them as columns, which reads as spaces.
- **`.githooks/pre-push` blocks forever on a non-TTY stdin that stays open** (`[ -t 0 ] ||
  PUSH_REFS="$(cat)"`), producing 0 bytes rather than failing. Run it `</dev/null`.

---

## 4. Pre-measured expectations — every figure came off the rehearsal

**4.1 — `apply.sh`: rc `0`, `0` bytes of stderr, `11` rows — 10 `RESOLVED`, 1 `DECISION` (§2.1).**

```
RESOLVED	pure-apply	scripts/validate-cycle-commits.sh
RESOLVED	pure-apply	scripts/validate-layer-entries.sh
RESOLVED	pure-apply	skills/ai-dlc-update/reconcile/apply.sh
RESOLVED	pure-apply	skills/ai-dlc/templates/pr-classes.md
RESOLVED	pure-apply	fixtures/layer-crosswalk-home/run.sh
RESOLVED	pure-apply	fixtures/layer-crosswalk-home/seed.sh
RESOLVED	pure-apply	fixtures/trunk-audit-classes/run.sh
DECISION	drift	skills/ai-dlc/extensions/README.md
RESOLVED	relabel	ext-check collisions labelled
RESOLVED	restamp	944c2e2 -> 7d2dd6a
RESOLVED	consistent	the tree matches 7d2dd6a; fixture suite re-enabled
```

**No `WORKLIST` row and no new path.** Both `layer-crosswalk-home` files move because they carried
the whitespace-strip defect §4.8 describes; they are not otherwise part of this release's subject.

**4.2 — Diff surface: 8 files modified, +408 / −18. No untracked additions.**

```
 M .claude/.ai-dlc-version
 M .claude/skills/ai-dlc-update/reconcile/apply.sh
 M .claude/skills/ai-dlc/templates/pr-classes.md
 M scripts/ai-dlc/validate-cycle-commits.sh
 M scripts/ai-dlc/validate-layer-entries.sh
 M tests/fixtures/layer-crosswalk-home/run.sh
 M tests/fixtures/layer-crosswalk-home/seed.sh
 M tests/fixtures/trunk-audit-classes/run.sh
```

**4.3 — The reading that settles delivery is a JOIN on the grammar, and it discriminates.**

| reading | before | after |
|---|---|---|
| `capture:` in the installed `validate-cycle-commits.sh` | **0** | **7** |
| control — `audit-trunk` in the same file, same grep | 6 | 6 |
| `capture:` in `templates/pr-classes.md` | absent | **5** |

The control is the point: one grep reads 0→7 on the subject and 6→6 on a sibling token in the
same file, so a zero before the pull is a reading rather than a broken instrument.

**4.4 — `hard-blockers.sh`: `0 HARD blockers`, before and after.**

**4.5 — Validator after the pull: `0 error(s), 1 warning(s)`**, footer
`LAYER_CONFORMANCE v1 contract_version=13 entries=50 at_current=50 behind=0 undeclared=0 errors=0 warnings=1`
— **byte-identical to the before-run.** The one warning is `W7=LC-R2:1/50` on both sides, the
pre-existing dangling `Check 11b`.

**4.6 — Drivable fixtures: 111 → 111, UNCHANGED**, and `trunk-audit-mutants` must stay **ABSENT**
(it is `.dist-only` and it grew by 9 mutants this release; a present one is a packaging defect).

**4.7 — Assertion counts. ONE fixture moves, and the run-based instrument is the reading.**

| instrument | before | after |
|---|---|---|
| **run-based, `trunk-audit-classes`** — verdict lines the fixture prints | **22** | **37** |
| control — run-based, `layer-reference-resolution` (untouched by this release) | 22 | 22 |
| line-anchored, joined over all 111 rows | 111 pairs, delta on `trunk-audit-classes` only | — |

**The control is what makes the 22→37 a reading**: the same instrument moved for the subject and
stayed put for a fixture this release does not touch. **A third moving line, or any count moving
DOWNWARD, is a hard stop.**

*(The line-anchored instrument scores `trunk-audit-classes` at 0 before and 2 after — an artefact
of the helper this release added, not a delivery figure. §2.5.)*

**4.8 — What the second half of this release fixes in YOUR tree, and it is worth knowing about.**
A POSIX bracket expression has no escapes. Every declaration reader in this distribution stripped
surrounding whitespace with a class holding a backslash and the letter `t` — so the class was
SPACE, BACKSLASH and that letter, and **any declaration line ending in one of those three lost its
last character, with no error and no non-zero exit.** `validator: x --strict` would have arrived
as `--stric`.

**Measured on your tree, and it is LATENT rather than firing: 0 of 35 `pr-classes.md` block lines
and 0 of 75 `machinery.md` declared paths end in one of those characters.** Nothing you have
written today was being truncated. It is fixed before it bites, which is why there is no
before/after to show you here — and why you should not go looking for a behaviour change.

**4.9 — Timing, a SANITY BOUND and not a result.** This release changes no scheduling. Same clone,
same box, same session, three runs each side: before **41.18 / 41.49 / 41.43 → median 41.43s**;
after **41.53 / 41.74 / 41.30 → median 41.53s**. **111 `ok` / 0 `FAIL` on all six runs.** The
fixture that grew was measured against a CONSUMER's schedule before it shipped: 1.7s → 4.28s,
not the pole, 4.42s of slack. **Report your own figures; do not match them against these.**

---

## 5. Progress ledger — execute in order, tick each row before moving on

| # | Row | Repo | Status |
|---|---|---|---|
| 1 | Pre-flight: clean tree, pin the engine, confirm graph has not moved under this file | graph | ✅ |
| 2 | Classify only. Report the tallies. **Write nothing.** | graph | ✅ |
| 3 | Bank the BEFORE figures — timing, and BOTH assertion instruments | graph | ✅ |
| 4 | `apply` on ONE branch, and verify what did and did NOT arrive | graph | ✅ |
| 5 | Advance the machinery stamp | graph | ✅ |
| 6 | Assertion delta, full pre-push, commit, push, PR | graph | ✅ |
| 7 | Report back the readings §6c-41 needs | graph | ✅ |

### Row 1 — pre-flight

```
cd $G && git status --porcelain && git fetch -q origin && git rev-parse origin/main
git -C /Users/n8/git/ai-dlc worktree add --detach /tmp/pull-engine-0236 7d2dd6a
cat /tmp/pull-engine-0236/VERSION
grep -E '^(version|commit):' $G/.claude/.ai-dlc-version
```

**EXPECT:** `origin/main` = `b7b7e1b6a…` — **and if it is not, STOP**: this brief's figures were
taken against that ref. Engine `VERSION` = `0.236.0`. Your stamp = `0.235.0` / `944c2e2`.
Working tree carries only your four `_bmad-output/` entries.

### Row 2 — classify only, write nothing

```
E=/tmp/pull-engine-0236; B=944c2e2; T=7d2dd6a
R=$E/core/skills/ai-dlc-update/reconcile
bash $R/hard-blockers.sh $E $B $T $G | tail -3
bash $R/layer-drift.sh   $E $B $T $G | tail -5
cd $G && bash scripts/ai-dlc/validate-layer-entries.sh $G 2>&1 | grep -E 'error\(s\)|LAYER_CONFORMANCE'
```

**EXPECT:** `0 HARD blockers`. Validator `0 error(s), 1 warning(s)`, `contract_version=13`,
`at_current=50 behind=0`. **Write nothing in this row.**

### Row 3 — bank the BEFORE figures

```
# instrument A — the series' line-anchored one, for the 110 rows where it works
for d in $G/tests/fixtures/*/; do n=$(basename $d); [ -f "$d/run.sh" ] || continue
  printf '%s\t%s\n' "$n" "$(grep -cE '^[[:space:]]*(ok|bad) ' $d/run.sh)"; done | sort > /tmp/assert-A-before.tsv
wc -l < /tmp/assert-A-before.tsv

# instrument B — RUN-BASED, and the only one that can see this release (§2.5)
cd $G
bash tests/fixtures/trunk-audit-classes/run.sh 2>&1 | grep -cE '^  (ok|FAIL)'
bash tests/fixtures/layer-reference-resolution/run.sh 2>&1 | grep -cE '^  (ok|FAIL)'   # the control

for i in 1 2 3; do /usr/bin/time -p bash .githooks/pre-push </dev/null 2>&1 | awk '/real/{print $2}'; done
```

**EXPECT:** 111 rows from A. From B: **22** for the subject and **22** for the control. Three
timed runs, all `rc=0`, 111 `ok` / 0 `FAIL`. **Record the median; it is a sanity bound.**

### Row 4 — apply on ONE branch

```
cd $G && git checkout -b chore/pull-0.236.0 origin/main
bash $R/apply.sh $E $B $G $T          # <dist> <base> <consumer> <theirs> — §3
git status --porcelain | sort
git diff --shortstat
md5 -q .claude/skills/ai-dlc/pr-classes.md ; grep -c '^class:' .claude/skills/ai-dlc/pr-classes.md
grep -c 'capture:' scripts/ai-dlc/validate-cycle-commits.sh
grep -c 'audit-trunk' scripts/ai-dlc/validate-cycle-commits.sh     # the control, must read 6
grep -c 'capture:' .claude/skills/ai-dlc/templates/pr-classes.md
[ -d tests/fixtures/trunk-audit-mutants ] && echo "PACKAGING DEFECT" || echo "dist-only held"
```

**EXPECT:** §4.1's 11 rows, §4.2's 8 files at +408/−18, `pr-classes.md` md5
`1ed82e923f50862267960a2a8e048449` with 5 classes, `capture:` **7** against a control of **6**,
template **5**, `dist-only held`.

**STOP CONDITIONS, all three:** `apply` writing `pr-classes.md`; a `WORKLIST` row; a second
`DECISION` row. Any of them and this brief's model of the pull is wrong.

### Row 5 — advance the machinery stamp

`apply` advances `version:`/`commit:` and leaves `skill_version:`/`skill_commit:` at the old
release. Advance both so all four agree:

```
cd $G && sed -i '' 's/^skill_version: 0\.235\.0/skill_version: 0.236.0/; s/^skill_commit: 944c2e2/skill_commit: 7d2dd6a/' .claude/.ai-dlc-version
grep -E '^(version|commit|skill_version|skill_commit):' .claude/.ai-dlc-version
```

**EXPECT:** all four lines reading `0.236.0` / `7d2dd6a`.

### Row 6 — assertion delta, full pre-push, commit, push, PR

```
cd $G
for d in $G/tests/fixtures/*/; do n=$(basename $d); [ -f "$d/run.sh" ] || continue
  printf '%s\t%s\n' "$n" "$(grep -cE '^[[:space:]]*(ok|bad) ' $d/run.sh)"; done | sort > /tmp/assert-A-after.tsv
join -t $'\t' /tmp/assert-A-before.tsv /tmp/assert-A-after.tsv | wc -l          # the control: 111
join -t $'\t' /tmp/assert-A-before.tsv /tmp/assert-A-after.tsv | awk -F'\t' '$2!=$3'

bash tests/fixtures/trunk-audit-classes/run.sh 2>&1 | grep -cE '^  (ok|FAIL)'          # expect 37
bash tests/fixtures/layer-reference-resolution/run.sh 2>&1 | grep -cE '^  (ok|FAIL)'   # expect 22

for i in 1 2 3; do /usr/bin/time -p bash .githooks/pre-push </dev/null 2>&1 | awk '/real/{print $2}'; done
```

**EXPECT:** join count **111** (non-zero, which is what makes the delta a reading). Instrument A
shows `trunk-audit-classes 0 → 2` **and nothing else** — the artefact of §2.5, not a delivery
figure. Instrument B: **22 → 37** on the subject, **22 → 22** on the control. Pre-push `rc=0`,
**111 ok / 0 FAIL**.

**A count moving DOWNWARD anywhere, or a third moved line under instrument A, is a hard stop.**

Then commit **the tracked changes only** — leave your four `_bmad-output/` runtime files
uncommitted — push, and open the PR.

### Row 7 — report back

Fill §6 and commit this file with its ticks. **`ai-dlc` owns this file; committing your ticks into
it is a recording act, and the six briefs before this one were closed the same way.**

---

## 6. Report-back — the readings §6c-41 needs

| reading | value | its control |
|---|---|---|
| `origin/main` before | `b7b7e1b6a9aa871166204970d3228dd0b0e95cc7` — the expected ref, no STOP | `git ls-remote origin main` agrees, same sha |
| apply rows | rc `0`, **11** rows — 10 `RESOLVED`, 1 `DECISION`, **0** `WORKLIST`; §4.1's row set exactly, in order | **0** bytes stderr; tallies grepped TAB-anchored per §3, not space-anchored |
| diff surface | at row 4, **8** files **+408 / −18**, **0** untracked; as committed, the same 8 files at **+410 / −20** | the §4.2 path set exactly — and the count is 8/+408/−18 only under `:(exclude)_bmad-output`; a bare `git diff --shortstat` reads 12/+464/−22 because the four pre-existing runtime files (4 files, +56/−4) are in the tree. The committed +410/−20 is §4.2's figure **plus row 5's two stamp lines**: `apply` moves `version:`/`commit:` (2/2 at row 4) and row 5 moves `skill_version:`/`skill_commit:` as well (4/4 at commit). Expected, not a discrepancy — but **a future brief should say which of the two it is quoting**, since a reader who checks §4.2 against the merged squash commit will find +410/−20 |
| `pr-classes.md` md5 | `1ed82e923f50862267960a2a8e048449` — **unwritten**, matching §2.2's before-value | **5** classes; `apply` printed no row for the installed copy, only for `templates/pr-classes.md` |
| `capture:` in the installed validator | **0 → 7** | `audit-trunk` in the same file, same grep: **6 → 6**; `templates/pr-classes.md` **absent → 5** |
| validator after | `0 error(s), 1 warning(s)` | footer **byte-identical** to before: `LAYER_CONFORMANCE v1 contract_version=13 entries=50 at_current=50 behind=0 undeclared=0 errors=0 warnings=1`; the warning is `W7=LC-R2:1/50` on both sides, the pre-existing dangling `Check 11b` |
| drivable fixtures | **111 → 111**, unchanged | `tests/fixtures/trunk-audit-mutants` **ABSENT** — `dist-only held` |
| assertion delta, run-based | `trunk-audit-classes` **22 → 37** | `layer-reference-resolution`, untouched by this release: **22 → 22**. Instrument A joined 111/111 rows and moved **one** line, `trunk-audit-classes 0 → 2` (the §2.5 artefact), nothing else, nothing downward |
| gate timing | before `44.66 / 44.71 / 44.95` → median **44.71s**; after `44.55 / 45.72 / 45.46` → median **45.46s** | `rc=0` and **111 ok / 0 FAIL** on all six runs |
| commit / PR / merge sha | commit `d7ea5eb1b` · PR [#848](https://github.com/euron8/fee_accrual_graph/pull/848) · squash-merged to `main` as **`63cff7274a153be065335c663c6b1ad2d67065c6`**, operator-approved | the four `_bmad-output/` runtime files left uncommitted. Verified on `main` **by content, not by ancestry** (a squash merge makes `--is-ancestor` false): all four stamp lines `0.236.0`/`7d2dd6a`, `capture:` reads 7 against the `audit-trunk` control at 6, installed `pr-classes.md` md5 unchanged |

**No deploy follows this merge.** The diff is `.claude/`, `scripts/ai-dlc/` and `tests/fixtures/`
only — no `server/`, `web/`, `rebalancer/`, `graph-node-src/` or `infra/` path — so there is no
`ecs-deploy.sh` service to run and no `cdk deploy`. Machinery-only, as the six pulls before it.


**Two instrument notes back, both about §2.5's grep rather than about the tree.**

- **§2.5's figure of "38 of 111" does not reproduce here; the reading is 39, and the cause is the
  grep and not the fixtures.** §2.5 writes the instrument as `'^\s*(ok|bad) '` while row 3 writes it
  as `'^[[:space:]]*(ok|bad) '`. macOS `grep -E` (BSD) does not honour `\s`, so those two are
  different instruments on this box. Row 3's bracket-expression form is the one banked, and it was
  banked identically at both ends, so the join and its 111-row control are unaffected. **A future
  brief quoting a `\s` figure at a consumer on macOS should expect it to be off by a few.**
- **§2.5's conclusion holds regardless, and this run is the demonstration**: the line-anchored
  instrument scored the one fixture this release moves at **0 before**, and the run-based one
  scored it **22 → 37**.

**Everything else in §4 reproduced exactly.** No STOP condition fired: `apply` did not write
`pr-classes.md`, there was no `WORKLIST` row, and there was no second `DECISION` row. Timing came in
about 3.3s above §4.9's rehearsal on both sides — a different box, and the before/after delta is
+0.75s, so it is read as a sanity bound and not as a result, per §4.9.

---

## 7. Known-open, deliberately out of scope

- **Adopting `capture:` in your taxonomy is NOT this pull.** It is §6c-38's row, and it is the one
  that retires `audit-main-since.sh`. Do it in its own branch, against your own side-by-side.
- **The `sprint-168` provenance finding at `5d2a12156`** still wants an operator disposition. This
  release does not touch it.
- **`_bmad-output/.audit-watermark` is gitignored and both tools write it**, so an audit's RANGE is
  not reproducible across machines while its verdict is. Recorded upstream, nobody's step yet.
- **`W7` / `Check 11b`** remains a live dangling check pointer. Pre-existing, one line.
