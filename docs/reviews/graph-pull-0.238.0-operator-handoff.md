# graph pull — v0.237.1 + v0.238.0

**Two releases. One branch. Seven rows.** Written from a rehearsal: every figure in §4 came off an
end-to-end run against a `git clone --local` of graph at `0040b020e`, with the real `apply.sh` from
an engine worktree pinned at `44db151` and graph's own `.githooks/pre-push`. **graph itself was
never written to, and that was verified after the fact.**

**Both releases exist because of your `§6c-43` session.** It named two reasons it could not retire
`generate-sprint-status.py`, and it found a defect in the release it was measuring against. This
pull carries the answers to all three.

---

## 1. What this pull carries

**v0.237.1 — the derive wrote unparseable YAML and its own reader reported it clean.**

`derive-stories` takes the derived value off the story file with `strip_value`, which removes the
quotes, and re-emitted it **bare**. A title carrying `: ` wrote `title: Fix: the direction-flip
guard`, which is not YAML. **Your corpus: 29 of 262 titles unparseable, 1 more silently mangled,
control ZERO for all eight other declared fields.**

**And the envelope's own reader is a regex, more permissive than YAML** — so `--check` reported
PASS over the file the same tool had just corrupted. Two arms ship, because the first alone leaves
the silence: correct quoting, and a **round-trip guard** that reads the composed line back through
the envelope's own grammar and refuses the write on mismatch.

**v0.238.0 — `derive-stories` had no invocation site, which was your second reason.**

Check 5 now runs `derive-stories --check` (reports, never writes) and `implementation.md` runs the
write. **A gate that edits the artifact it is validating can pass a tree it just changed**, so the
two are deliberately different modes at different sites.

**Your first reason — the `--close-sweep` rotation grain — was measured upstream and REFUTED.** See
§7; it is a question for you, not a core gap.

---

## 2. Locked decisions — do not re-open these mid-run

**2.1 — THE BIG ONE. This pull produces an `override-readopt` WORKLIST row on your Check 5
shadow, and that is expected.** `overrides/steps__gate-validation__check-5.md` shadows
`steps/gate-validation.md#5` at `base_sha: 3490997`, and v0.238.0 edits core's Check 5. Its own
reason block says the shadow reproduces core's text *"verbatim below, so the shadow loses nothing
of core."*

**The decision, locked: the shadow MUST carry core's new `derive-stories --check` arm.** It is a
new core obligation, and a shadow that silently drops it is the exact defect the override's own
header says it was refiled to stop — *"it REPLACED core's manual read-and-compare procedure … and
silently NARROWED core's non-vacuous sub-clause."* **Re-adopt with the arm, advance `base_sha`, and
say in the reason block that the arm came from core.** Do not resolve the row by re-stamping alone.

**2.2 — Six further `extension-reread` WORKLIST rows are expected and are NOT findings.** Core's
`gate-validation.md` and `implementation.md` both moved, so every extension hooked to them is
re-read. Four checks and two steps-domain entries. Read them; none needs an edit unless it restates
Check 5's or implementation's command list.

**2.3 — The `DECISION drift` row on `extensions/README.md` is NOT this release's.** Your step-27
edit to a core-owned worked example, third pull running. **Leave it.**

**2.4 — `contract_version` stays 13 and every footer field is unchanged.** No clause is added.

**2.5 — The drivable fixture count does NOT move.** Neither release adds a fixture; both grow one.
**The instrument that shows delivery is the RUN-BASED assertion count** — per D-6c41.1 the
line-anchored one is blind to this fixture. Rows 3 and 6 give both greps literally, **including the
pre-push aggregate's, which differs from the fixture's by one leading space** and which the last
brief left implicit (D-6c42.1).

---

## 3. Every command's argument order, because they are NOT the same

```
apply.sh            <dist> <base> <consumer> <theirs>
layer-drift.sh      <dist> <base> <theirs>   <consumer>
ledger-reverify.sh  <dist> <base> <consumer> <theirs>
hard-blockers.sh    <dist> <base> <theirs>   <consumer>
retired-fixtures.sh <dist> <theirs> <consumer>          # three args, not four
```

**`apply.sh` with `<theirs>` and `<consumer>` swapped exits 0, writes almost nothing, and prints
`DECISION manifest-unreadable`** — a wrong-argument run that does not look like one.

```
E=/tmp/pull-engine-0238      # the pinned engine worktree, see §5 row 1
B=0cc51fc                    # your current stamp (0.237.0)
T=44db151                    # v0.238.0 (carries v0.237.1)
G=/Users/n8/git/graph
```

- **`apply.sh` rows are TAB-separated.** A `'^RESOLVED '` grep on a space returns a vacuous 0.
- **`.githooks/pre-push` blocks forever on a non-TTY stdin that stays open.** Run it `</dev/null`.

---

## 4. Pre-measured expectations — every figure came off the rehearsal

**4.1 — `apply.sh`: rc `0`, `0` bytes of stderr, `15` rows — 7 `RESOLVED`, 1 `DECISION`, **7
`WORKLIST`**.** The worklist rows are §2.1 and §2.2 and are the most this series has carried.

```
RESOLVED	pure-apply	scripts/sprint-status.sh
RESOLVED	pure-apply	skills/ai-dlc/steps/gate-validation.md
RESOLVED	pure-apply	skills/ai-dlc/steps/implementation.md
RESOLVED	pure-apply	fixtures/story-fields-derive/run.sh
DECISION	drift	skills/ai-dlc/extensions/README.md
WORKLIST	override-readopt	.claude/skills/ai-dlc/overrides/steps__gate-validation__check-5.md
WORKLIST	extension-reread	…/checks/attribution-provenance.md
WORKLIST	extension-reread	…/checks/gate-validation-domain.md
WORKLIST	extension-reread	…/checks/gate-validation-push.md
WORKLIST	extension-reread	…/checks/validator-honesty.md
WORKLIST	extension-reread	…/steps-domain/implementation-domain.md
WORKLIST	extension-reread	…/steps-domain/implementation-push.md
RESOLVED	relabel	ext-check collisions labelled
RESOLVED	restamp	0cc51fc -> 44db151
RESOLVED	consistent	the tree matches 44db151; fixture suite re-enabled
```

**4.2 — Diff surface: 5 files, +169 / −3, no new paths**, under `:(exclude)_bmad-output`. Per
D-6c41.3, **say which of the three you are quoting** — this figure, the bare one, or the committed
one after row 5's stamp lines.

```
 M .claude/.ai-dlc-version
 M .claude/skills/ai-dlc/steps/gate-validation.md
 M .claude/skills/ai-dlc/steps/implementation.md
 M scripts/ai-dlc/sprint-status.sh
 M tests/fixtures/story-fields-derive/run.sh
```

**4.3 — The delivery join, and it discriminates.**

| reading | before | after |
|---|---|---|
| `yaml_scalar` in the installed `sprint-status.sh` (v0.237.1) | **0** | **2** |
| live-sibling control — `derive-stories`, same file, same grep | 16 | 17 |
| step files invoking `sprint-status.sh derive-stories` (v0.238.0) | **0** | **2** |

**The third row is the one your §6c-43 asked for**: the mode had no invocation site, and now it has
two — `gate-validation.md` for `--check` and `implementation.md` for the write.

**4.4 — `hard-blockers.sh`: `0 HARD blockers`, before and after.**

**4.5 — Validator after the pull: `0 error(s), 1 warning(s)`**, footer
`LAYER_CONFORMANCE v1 contract_version=13 entries=50 at_current=50 behind=0 undeclared=0 errors=0 warnings=1`
— **byte-identical to the before-run.**

**4.6 — Drivable fixtures: 112 → 112, UNCHANGED.** Neither release adds one.

**4.7 — Assertion counts, RUN-BASED (§2.5).**

| instrument | before | after |
|---|---|---|
| run-based, `story-fields-derive` | **25** | **33** |
| control — run-based, `layer-reference-resolution` (untouched) | **22** | **22** |

**4.8 — The derive against your real tree, its own six-field declaration, after the pull:**
`--check PASS — 0 drifted key(s) over 2 stories`, rc 0. **And `_bmad-output` is untouched by the
pull — 0 modified paths under it.** The artifact six actors hand-edit is not written by a pull.

**4.9 — Timing, a SANITY BOUND.** Three runs each side: before **41.91 / 41.78 / 42.25 → median
41.91s**; after **44.29 / 41.79 / 41.76 → median 41.79s**; **112 `ok` / 0 `FAIL` on all six.**

---

## 5. Progress ledger — execute in order, tick each row before moving on

| # | Row | Repo | Status |
|---|---|---|---|
| 1 | Pre-flight: clean tree, pin the engine, confirm graph has not moved under this file | graph | — |
| 2 | Classify only. Report the tallies. **Write nothing.** | graph | — |
| 3 | Bank the BEFORE figures — timing, and both assertion instruments | graph | — |
| 4 | `apply` on ONE branch, and verify what did and did NOT arrive | graph | — |
| 5 | **Re-adopt the Check 5 override with core's new arm** (§2.1), then advance the stamp | graph | — |
| 6 | Assertion delta, full pre-push, commit, push, PR | graph | — |
| 7 | Report back the readings §6c-48 needs, and answer §7's question | graph | — |

### Row 1 — pre-flight

```
cd $G && git status --porcelain && git fetch -q origin && git rev-parse origin/main
git -C /Users/n8/git/ai-dlc worktree add --detach /tmp/pull-engine-0238 44db151
cat /tmp/pull-engine-0238/VERSION
grep -E '^(version|commit):' $G/.claude/.ai-dlc-version
```

**EXPECT:** engine `VERSION` = `0.238.0`; your stamp = `0.237.0` / `0cc51fc`.
**`origin/main` was `0040b020e` when this brief was written. If it has moved, DO NOT STOP —
re-derive §4's before-figures**, and say which moved.

### Row 2 — classify only, write nothing

```
E=/tmp/pull-engine-0238; B=0cc51fc; T=44db151
R=$E/core/skills/ai-dlc-update/reconcile
bash $R/hard-blockers.sh $E $B $T $G | tail -3
bash $R/layer-drift.sh   $E $B $T $G | tail -8
cd $G && bash scripts/ai-dlc/validate-layer-entries.sh $G 2>&1 | grep -E 'error\(s\)|LAYER_CONFORMANCE'
```

**EXPECT:** `0 HARD blockers`; validator `0 error(s), 1 warning(s)`, `contract_version=13`.
**Write nothing in this row.**

### Row 3 — bank the BEFORE figures

```
cd $G
grep -c 'yaml_scalar' scripts/ai-dlc/sprint-status.sh                                  # EXPECT 0
grep -c 'derive-stories' scripts/ai-dlc/sprint-status.sh                               # control, EXPECT 16
grep -rl -- 'sprint-status.sh derive-stories' .claude/skills/ai-dlc/steps/ | wc -l      # EXPECT 0
ls -d tests/fixtures/*/ | while read -r d; do [ -f "$d/run.sh" ] && echo x; done | wc -l  # EXPECT 112
bash tests/fixtures/story-fields-derive/run.sh 2>&1 | grep -cE '^  (ok|FAIL)'            # EXPECT 25
bash tests/fixtures/layer-reference-resolution/run.sh 2>&1 | grep -cE '^  (ok|FAIL)'     # control, EXPECT 22
for i in 1 2 3; do /usr/bin/time -p bash .githooks/pre-push </dev/null 2>&1 | awk '/real/{print $2}'; done
```

**The two verdict greps are DIFFERENT and D-6c42.1 is why.** Fixture verdicts carry **two** leading
spaces (`'^  (ok|FAIL)'`); the pre-push aggregate's carry **three** (`'^[[:space:]]+ok[[:space:]]'`).
Applying the fixture form to the aggregate returns a vacuous **0**, which on the before-side is
indistinguishable from a gate that ran nothing. **EXPECT 112 `ok` / 0 `FAIL`, rc 0, three times.**

### Row 4 — apply on ONE branch

```
cd $G && git checkout -b chore/pull-0.238.0 origin/main
bash $R/apply.sh $E $B $G $T          # <dist> <base> <consumer> <theirs> — §3
git status --porcelain | sort
git diff --shortstat -- ':(exclude)_bmad-output'
grep -c 'yaml_scalar' scripts/ai-dlc/sprint-status.sh                                  # EXPECT 2
grep -c 'derive-stories' scripts/ai-dlc/sprint-status.sh                               # control, EXPECT 17
grep -rl -- 'sprint-status.sh derive-stories' .claude/skills/ai-dlc/steps/ | wc -l      # EXPECT 2
git status --porcelain -- _bmad-output | wc -l                                          # EXPECT your pre-existing count
```

**STOP CONDITIONS:** `apply` writing anything under `_bmad-output/`; a `RESOLVED` row for
`story-fields.md` (it is yours and already exists); an **eighth** `WORKLIST` row or a second
`DECISION`.

### Row 5 — re-adopt the Check 5 override, then the stamp

**This is the row with judgement in it and §2.1 is the decision.** Core's Check 5 gained a
`derive-stories --check` arm. Your shadow reproduces core's text and its own header says it must
lose nothing of core.

```
cd $G
git -C $E show $T:core/skills/ai-dlc/steps/gate-validation.md | sed -n '/CHECK_LOADED: 5/,/^<!-- CHECK/p'
```

Carry the new arm into the shadow, advance its `base_sha` to `44db151`, and record in the reason
block that the arm came from core. Then:

```
sed -i '' 's/^skill_version: 0\.237\.0/skill_version: 0.238.0/; s/^skill_commit: 0cc51fc/skill_commit: 44db151/' .claude/.ai-dlc-version
grep -E '^(version|commit|skill_version|skill_commit):' .claude/.ai-dlc-version
```

**EXPECT:** all four lines `0.238.0` / `44db151`.

### Row 6 — assertion delta, full pre-push, commit, push, PR

```
cd $G
bash tests/fixtures/story-fields-derive/run.sh 2>&1 | grep -cE '^  (ok|FAIL)'            # EXPECT 33
bash tests/fixtures/layer-reference-resolution/run.sh 2>&1 | grep -cE '^  (ok|FAIL)'     # control, EXPECT 22
ls -d tests/fixtures/*/ | while read -r d; do [ -f "$d/run.sh" ] && echo x; done | wc -l  # EXPECT 112
for i in 1 2 3; do /usr/bin/time -p bash .githooks/pre-push </dev/null 2>&1 | awk '/real/{print $2}'; done
```

**EXPECT:** pre-push `rc=0`, **112 ok / 0 FAIL**. **The control moving, or the subject reading
anything but 33, is a hard stop.** Commit the tracked changes only; push; open the PR.

### Row 7 — report back

Fill §6, answer §7's question, and commit this file with its ticks.

---

## 6. Report-back — the readings §6c-48 needs

| reading | value | its control |
|---|---|---|
| `origin/main` before | | `ls-remote` agrees |
| apply rows | | 0 bytes stderr; 7 WORKLIST expected |
| diff surface (say WHICH) | | the §4.2 path set exactly |
| `yaml_scalar` installed | | `derive-stories`, same file, same grep |
| step files invoking `derive-stories` | | 0 before |
| Check 5 override re-adopted, `base_sha` advanced | | the new arm present in the shadow |
| validator after | | same footer fields as before |
| drivable fixtures | | unchanged at 112 |
| assertion count, run-based | | the untouched control fixture |
| `_bmad-output` paths the pull touched | | expect 0 beyond your pre-existing |
| gate timing | | verdict count both sides, aggregate grep |
| commit / PR / merge sha | | |

---

## 7. The question this pull hands back — `--close-sweep`'s live subject set

**Your `§6c-43` gave two reasons for not retiring `generate-sprint-status.py`. This pull answers the
second. The first was measured upstream and REFUTED, and what survives is a question only you can
settle.**

Measured against your `origin/main`: **both live canonicals are SINGLE-SPRINT** — 1 top-level
`sprint:` key, 27 lines each. The one apparent monolith block key is `sprint_299_housekeeping:`,
which core's own schema comment warns collides with that regex. **And rotation already works: 45 and
54 archived per-sprint views exist under `sprint-status/`** — exactly what core's `roll` produces.
Control: a bogus directory reads 0.

**So core's whole-text freeze is the correct operation for the shape your tree actually has, and
there is no rotation grain for core to gain.** The question:

> **Does `--close-sweep` have any live subject?** Its HARD_BLOCK guards a multi-sprint canonical;
> your canonical is single-sprint; and your own `--migrate` re-run reported
> `active=299 frozen=0 no-loss=OK`, a completed one-time split.

**If it has none, then your FIRST reason for not retiring dissolves**, and with this pull installed
your second does too. **Answer it in §6 with a reading, not a judgement** — and if it does have a
live subject, that measurement is the core row, and it comes back upstream.

## 8. Known-open, deliberately out of scope

- **`title` stays WITHHELD from your declaration until this pull lands.** It is derived and it was
  the field the v0.237.1 defect corrupted; declaring it before the fix is installed is the one way
  to trip it. After the pull it is safe, and declaring it is your call.
- **The `sprint-168` provenance finding at `5d2a12156`** still wants an operator disposition.
- **`W7` / `Check 11b`** remains a live dangling check pointer.
