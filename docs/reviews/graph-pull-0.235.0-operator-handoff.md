# graph pull — v0.235.0

**Operator handoff. Written in `ai-dlc`, executed by a `graph` session, merged by the operator.**

Rehearsed end-to-end on a `git clone --local` of graph at `c459f207a`, driven by the real
`apply.sh` from a pinned engine worktree at `944c2e2`, with graph's own `.githooks/pre-push`.
**graph itself was never written to** — verified after the fact: `origin/main` unmoved, working tree
still its four pre-existing `_bmad-output/` entries.

---

## 1. What this pull carries

| release | what it is |
|---|---|
| **v0.235.0** | **charter goal 5 (c)'s core half**: `validate-cycle-commits.sh --audit-trunk`, the post-merge trunk audit, with this project's PR-class taxonomy DECLARED rather than inferred |

**Why it matters to this project specifically.** The mechanism core now ships is the one
`scripts/ai-dlc-local/audit-main-since.sh` implements here — 364 lines. **This pull does not retire
that script and must not be used to.** The retirement is its own step, it needs a declared taxonomy
and a side-by-side run first, and two measured expressiveness gaps stand in front of it.

**What arrives, in one line each:**

- a new mode on a validator this project already has — nothing is wired into your gate
- a new consumer-owned file, `.claude/skills/ai-dlc/pr-classes.md`, scaffolded once and never
  overwritten
- one new fixture in your suite, `trunk-audit-classes`
- a new step in `carry-over-evaluation.md` (**1b**) that runs the audit at Day-0

---

## 2. Locked decisions — do not re-open these mid-run

**2.1 — The scaffolded taxonomy arrives saying `none`, and that is a PLACEHOLDER, not an answer.**
`apply.sh` creates `.claude/skills/ai-dlc/pr-classes.md` from core's template with the literal `none`
in its block. The audit then prints one `WORKLIST` line and exits 0. **It is telling the truth: this
project has not declared its trunk classes.** Declaring them is the follow-on step's job. **Do not
declare the taxonomy inside this pull branch** — a pull that also performs a migration hides both,
which is the rule every brief in this series has followed.

**2.2 — The PASS condition is `0 error(s), 1 warning(s)`, unchanged from before the pull.** The one
is `W7` / `Check 11b`, pre-existing and separately known. Nothing this release ships adds or removes
a warning. Two, or zero, is a stop-and-report.

**2.3 — `DECISION drift skills/ai-dlc/extensions/README.md` WILL appear, it is PRE-EXISTING, and it
is not this release's.** Measured: v0.235.0 touches **0** files under that path against a control of
**16** files touched overall, and graph's copy already differs from core at your CURRENT base — line
86, `conforms_to: 9` → `conforms_to: 13`, an edit made in the step-27 branch to a core-owned worked
example. **Do not repair it in this branch and do not let it stop the run**; record it and move on.
It is the unregistered-core-drift class and it wants its own decision, not a pull's.

**2.4 — `WORKLIST extension-reread .claude/skills/ai-dlc/extensions/steps-domain/carry-over-evaluation-domain.md`
is EXPECTED and is normal.** Core's `carry-over-evaluation.md` gained step 1b, so an entry hooking
that file has a moved digest. Re-reading the entry against the new core text and recording a verdict
is the entry owner's job, not the pull's. **A `DECISION` row or a non-zero exit is a stop; a
`WORKLIST extension-reread` is not.**

---

## 3. Every command's argument order, because they are NOT the same

**This is the fourth time a brief in this series has carried this table, and it is still not
optional** — the reconcile scripts genuinely differ from one another.

```
apply.sh            <dist> <base> <consumer> <theirs>
layer-drift.sh      <dist> <base> <theirs>   <consumer>
ledger-reverify.sh  <dist> <base> <consumer> <theirs>
hard-blockers.sh    <dist> <base> <theirs>   <consumer>
retired-fixtures.sh <dist> <theirs> <consumer>          # three args, not four
```

**`apply.sh` with `<theirs>` and `<consumer>` swapped exits 0, writes almost nothing, and prints
`DECISION manifest-unreadable`** — it does not look like an argument error.

Set these once and use them everywhere below:

```
E=/tmp/pull-engine-0235      # the pinned engine worktree, see §5 row 1
B=9857448                    # your current stamp (0.234.1)
T=944c2e2                    # v0.235.0
G=/Users/n8/git/graph
```

---

## 4. Pre-measured expectations — every figure below came off the rehearsal

**4.1 — `apply.sh`: rc **0**, **0** bytes of stderr, **15 rows: 13 `RESOLVED`, 1 `DECISION`
(§2.3), 1 `WORKLIST` (§2.4)**. The `RESOLVED` set includes:

```
RESOLVED  pr-class-scaffold  .claude/skills/ai-dlc/pr-classes.md
RESOLVED  restamp            9857448 -> 944c2e2
RESOLVED  consistent         the tree matches 944c2e2; fixture suite re-enabled
```

**`pr-class-scaffold` is a row shape no previous pull has produced.** It is the third
create-once consumer-owned file core declares, after the crosswalk and the machinery inventory.

**4.2 — Diff surface: 8 files modified, +376 / −11, plus 3 new paths.**

```
 M .claude/.ai-dlc-version
 M .claude/skills/ai-dlc-update/reconcile/apply.sh
 M .claude/skills/ai-dlc-update/reconcile/setup-sites.md
 M .claude/skills/ai-dlc/core-manifest.md
 M .claude/skills/ai-dlc/layer-contract.yaml
 M .claude/skills/ai-dlc/steps/carry-over-evaluation.md
 M scripts/ai-dlc/validate-cycle-commits.sh
 M tests/fixtures/consumer-machinery-inventory/run.sh
?? .claude/skills/ai-dlc/pr-classes.md
?? .claude/skills/ai-dlc/templates/pr-classes.md
?? tests/fixtures/trunk-audit-classes/
```

`consumer-machinery-inventory/run.sh` moves because a mutant in it had never executed; see §6.

**4.3 — `hard-blockers.sh`: `0 HARD blockers`, before and after.**

**4.4 — Validator, after the pull: `0 error(s), 1 warning(s)`**, footer
`LAYER_CONFORMANCE v1 contract_version=13 entries=50 at_current=50 behind=0 undeclared=0 errors=0 warnings=1`.
**Every field is unchanged from before the pull**, `contract_version` included — this release adds no
clause and bumps nothing.

**4.5 — Drivable fixtures: 110 → 111. UP BY ONE, NOT TWO.** The release ships two fixtures and one of
them, `trunk-audit-mutants`, is `.dist-only` and **must be ABSENT here**. Both halves are worth
checking: a missing `trunk-audit-classes` is a delivery failure, and a PRESENT `trunk-audit-mutants`
is a packaging defect.

**4.6 — Per-fixture assertion counts: exactly ONE new row and ZERO moves.** Measured with the
instrument D-6c18.4 introduced, joined over the 110 shared rows: **110 pairs joined, delta empty**,
one added row (`trunk-audit-classes`). **Any moved count, in either direction, is a hard stop.**

**4.7 — Timing, as a SANITY BOUND and not a result.** Same box, same session, three runs each side:
before **43.82 / 41.05 / 41.18 → median 41.18s**; after **43.54 / 41.85 / 41.34 → median 41.85s**;
110 `ok` → 111 `ok`, 0 `FAIL` both sides. **The new fixture was measured against your suite's
schedule before it shipped, not only against the distribution's** — held together with its mutation
battery it cost 21.6s and would have become YOUR POLE (+28.9% on this gate); the battery was split
into the `.dist-only` sibling and the shipping half is ~3s. **Report your own figures; do not match
them against these.**

**4.8 — The audit's own first run, after the pull, prints a WORKLIST and exits 0.** Measured on both
states a consumer can be in — key absent, and scaffolded-but-`none`. That is the whole of what this
release does to your tree until you declare a taxonomy.

---

## 5. Progress ledger — execute in order, tick each row before moving on

| # | Row | Repo | Status |
|---|---|---|---|
| 1 | Pre-flight: clean tree, pin the engine, confirm graph has not moved under this file | graph | — |
| 2 | Classify only. Report the tallies. **Write nothing.** | graph | — |
| 3 | Bank the BEFORE figures — timing and per-fixture assertion counts | graph | — |
| 4 | `apply` on ONE branch, and verify what did and did NOT arrive | graph | — |
| 5 | Advance the machinery stamp | graph | — |
| 6 | Assertion delta, full pre-push, commit, push, PR | graph | — |
| 7 | Report back the readings §6c-37 needs | graph | — |

### Row 1 — pre-flight

```
cd $G && git status --porcelain && git fetch -q origin && git rev-parse origin/main
git ls-remote origin -h refs/heads/main
head -4 .claude/.ai-dlc-version
cd /Users/n8/git/ai-dlc && git worktree add --detach /tmp/pull-engine-0235 944c2e2 && cat /tmp/pull-engine-0235/VERSION
```

**EXPECT:** `origin/main` = `c459f207a…`, and `ls-remote` agreeing with it — **if they disagree your
ref is stale and every figure below is measured against the wrong tree.** Stamp `0.234.1` / `9857448`
on BOTH pairs. Engine `VERSION` = `0.235.0`. Working tree carries only your usual `_bmad-output/`
runtime files.

### Row 2 — classify only, write nothing

```
bash $E/core/skills/ai-dlc-update/reconcile/hard-blockers.sh $E $B $T $G
cd $G && bash scripts/ai-dlc/validate-layer-entries.sh | tail -3
```

**EXPECT:** `0 HARD blockers`. Validator `0 error(s), 1 warning(s)`, footer
`contract_version=13 entries=50 at_current=50 behind=0 undeclared=0`. **Any ERROR here is a stop
before anything is written.**

### Row 3 — bank the BEFORE figures

```
for d in $G/tests/fixtures/*/; do n=$(basename $d); [ -f "$d/run.sh" ] || continue
  printf '%s\t%s\n' "$n" "$(grep -cE '^\s*(ok|bad) ' $d/run.sh)"; done | sort > /tmp/assert-before-0235.tsv
wc -l < /tmp/assert-before-0235.tsv
cd $G && for i in 1 2 3; do /usr/bin/time -p bash .githooks/pre-push 2>&1 | awk '/real/{print $2}'; done
```

**EXPECT:** 110 rows. Three timed runs, all `rc=0`. **Record the median; it is a sanity bound.**

### Row 4 — apply on ONE branch

```
cd $G && git checkout -b chore/ai-dlc-update-0.235.0
bash $E/core/skills/ai-dlc-update/reconcile/apply.sh $E $B $G $T
git status --porcelain
git diff --numstat | awk '{a+=$1;d+=$2;n++} END{print n" files, +"a" / -"d}'
grep -c '^class:' .claude/skills/ai-dlc/pr-classes.md ; grep -c '^none$' .claude/skills/ai-dlc/pr-classes.md
ls tests/fixtures | grep -c trunk-audit ; ls tests/fixtures | grep trunk-audit
```

**EXPECT:** rc 0, 0 bytes stderr, the §4.1 row set, the §4.2 surface. `pr-classes.md` carries **0**
`class:` lines and **1** `none` — the scaffold, per §2.1. **`grep -c trunk-audit` returns exactly 1,
and the one is `trunk-audit-classes`** (§4.5).

### Row 5 — advance the machinery stamp

`apply.sh` advances the `version:`/`commit:` pair; the `skill_version:`/`skill_commit:` pair is the
hand edit this row exists for.

```
cd $G && head -4 .claude/.ai-dlc-version      # after your edit
git diff --numstat -- .claude/.ai-dlc-version
```

**EXPECT:** all four lines reading `0.235.0` / `944c2e2`, and `git diff --numstat` on that file
reading exactly **`4 4`**. A `2 2` means the second pair is still on the old stamp.

### Row 6 — assertion delta, full pre-push, commit, push, PR

```
for d in $G/tests/fixtures/*/; do n=$(basename $d); [ -f "$d/run.sh" ] || continue
  printf '%s\t%s\n' "$n" "$(grep -cE '^\s*(ok|bad) ' $d/run.sh)"; done | sort > /tmp/assert-after-0235.tsv
wc -l < /tmp/assert-after-0235.tsv
join -t$'\t' /tmp/assert-before-0235.tsv /tmp/assert-after-0235.tsv | wc -l
join -t$'\t' /tmp/assert-before-0235.tsv /tmp/assert-after-0235.tsv | awk -F'\t' '$2!=$3{print $1": "$2" -> "$3}'
cd $G && for i in 1 2 3; do /usr/bin/time -p bash .githooks/pre-push 2>&1 | awk '/real/{print $2}'; done
cd $G && bash scripts/ai-dlc/validate-cycle-commits.sh --audit-trunk HEAD ; echo "audit rc=$?"
```

**EXPECT:** 111 after-rows, **110 joined pairs** (the control that the join is not empty), **an EMPTY
delta**. Pre-push `rc=0`, **111 ok / 0 FAIL**. The audit prints one `AUDIT-TRUNK: WORKLIST` line
naming `pr-classes.md` and exits **0** — §4.8.

Then commit the ai-dlc paths only, leave your `_bmad-output/` runtime files unstaged, push, open the
PR. **Do not fill in the taxonomy in this branch** (§2.1).

### Row 7 — report back

Fill §6 below with your own readings. **Every figure with the control that makes it a reading rather
than a hope** — that is what the ledger row this brief serves needs, and a number with no control is
what this whole series exists to stop accepting.

---

## 6. Report-back — the readings §6c-37 needs

*(to be filled by the `graph` session)*

| reading | value | its control |
|---|---|---|
| `origin/main` before | | `ls-remote` agrees |
| apply rows | | 0 bytes stderr |
| diff surface | | the §4.2 path set exactly |
| validator after | | same footer fields as before |
| drivable fixtures | | `trunk-audit-mutants` ABSENT |
| assertion delta | | joined-pair count non-zero |
| gate timing | | verdict count both sides |
| `--audit-trunk` first run | | exit code |
| commit / PR / merge sha | | |

---

## 7. Known-open, deliberately out of scope

- **`W7` / `Check 11b`** — a live dangling check pointer, pre-existing, nobody's step in this pull.
- **`DECISION drift` on `extensions/README.md`** — §2.3. Pre-existing, wants its own decision.
- **`audit-main-since.sh` is NOT retired by this pull.** That is a separate step and it must first
  declare a taxonomy, set the watermark forward, and run both tools side by side over the same range.
  **Two measured expressiveness gaps stand in front of it**: core's grammar resolves a class when ANY
  changed path matches and cannot express `pipeline-infra`'s ALL-paths rule; and a declared validator
  runs once against the tree rather than once per changed file. Answer both with a measurement before
  deleting anything.
