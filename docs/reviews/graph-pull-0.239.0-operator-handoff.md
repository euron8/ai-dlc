# graph pull — v0.239.0

**One release. One branch. Six rows, and the smallest pull in this series: `apply.sh` produces
ZERO worklist rows and restamps itself.** Written from a rehearsal — every figure below came off an
end-to-end run against a `git clone --local` of graph at `7d1d7862a`, with the real `apply.sh` from
an engine worktree pinned at `bd740f6` and graph's own `.githooks/pre-push`. **graph itself was
never written to.**

**READ §2.1 BEFORE ANYTHING ELSE. graph's `origin/main` is RED right now and this pull did not do
it.** That finding came out of this rehearsal's control and is the most important thing in this
document.

---

## 1. What this pull carries

**v0.239.0 — `derive-stories` counted entry-VIEW pairs and called them stories, and its `--check`
printed no entry count at all.**

Both canonical views carry the same sprint's `stories:` mapping, and the counts were summed across
them. **Measured on your tree: sprint 299 declares `story-S299-1` once in each view, and
`derive-stories --check` printed `over 2 stories` for a run that saw one story** — against the `1`
your own `entry_count_no_idregex` reads from the same envelope.

**Why that number matters to you specifically.** It is the ENVELOPE side of the comparison your
cross-check B makes. The corpus side is yours and stays yours — core resolves files FROM entries by
construction and must not infer which files on disk are stories, which is the position your
`S6C-49` comment takes and it is right. But the entry side is core's, core already computed it, and
it could not be used: the per-view sum would have made your denominator disagree with your numerator
on every tree carrying both views, and `--check` — the only mode a gate may run — printed no entry
count whatsoever.

Both counts are now per-STORY, distinct across views, with the declared count taken as the **union**
(the two views are not required to agree on their entry set), and the per-view work is printed per
view the way `check-stories` always has. Post-pull, against your own envelope:

```
  implementation: 1 entry, 1 resolved
  planning:       1 entry, 1 resolved

sprint-status: derive-stories --check PASS — 0 drifted key(s) over 1 story, 1 entry declared
```

**It also answers your other upstream ask, by refuting it.** Your side-by-side §5 item 1 asks for a
check-only field form so `title` can be checked but not written. **Re-measured against the shipping
code and your current corpus: 262 titles, 0 unparseable, 0 refused — and 0 refused on all nine
declared fields, across 988 story files.** The control is in the same run: the identical corpus with
v0.237.0's emit-bare behaviour reads **29** unparseable on `title`, so the zero is a detector that
fires. **The write-unsafe class is empty. `title` is writable, and the withholding rests on a defect
that no longer exists.**

---

## 2. Locked decisions — do not re-open these mid-run

**2.1 — THE BIG ONE, AND IT IS NOT THIS RELEASE'S. `origin/main` is RED. `E18` fires on
`scripts/ai-dlc-local/tests/fixtures/s279-4`, declared in `.claude/skills/ai-dlc/machinery.md` and
not on disk.**

Your `§6c-49` retirement (PR #853) deleted `tests/fixtures/s279-4/` with the test that imported it
and left the declaration standing. Measured at the two adjacent commits, on an untouched clone:

| ref | verdict | `E18` | `s279-4` on disk | declared in `machinery.md` |
|---|---|---|---|---|
| `91a3b8910` (before #853) | `errors=0 warnings=1` | 0 | YES | yes |
| `7d1d7862a` (after #853) | **`errors=1 warnings=1`** | **1** | **NO** | yes |

`warnings=1` is unchanged at both refs and is the control: the instrument is reading the same tree
the same way, and only the `E18` cell moved.

**This is not cosmetic. Goal 2 of the charter is scored MET on `E18 = 0` measured in this
consumer** — that is the reading in the program ledger's closing table, and it is currently false.
**The remedy is one line: delete the `s279-4` path from `machinery.md`.** It is a deleted fixture
directory, not a moved one.

**Do it in this pull's branch, as row 5, and say in the commit that it is a #853 follow-up rather
than part of v0.239.0.** Two reasons it rides here instead of waiting for its own PR: your trunk is
red today and every gate a teammate runs is red with it, and this pull's own row 6 cannot tell a
green suite from a red one until it is fixed.

**STOP CONDITION: if `E18` names any path other than `s279-4`, stop and report.** A second stale
entry is a different finding and this brief has not measured it.

**2.2 — `apply.sh` produces ZERO `WORKLIST` rows, and that is expected rather than suspicious.**
This release touches `scripts/sprint-status.sh` and one fixture. **It touches no step file, so no
override is invalidated and no extension is re-read.** The 0.238.0 pull carried seven worklist rows
because it edited Check 5; this one edits nothing any entry hooks. **If a worklist row appears, stop
and report it** — it means something moved that this rehearsal did not see.

**2.3 — The `DECISION drift` row on `extensions/README.md` is NOT this release's.** Your step-27
edit to a core-owned worked example, fourth pull running. **Leave it.**

**2.4 — `apply.sh` restamps by itself this time.** The row reads
`RESOLVED	restamp	44db151 -> bd740f6`. **There is no manual `sed` on `.ai-dlc-version` in this
pull.** Verify the four lines afterwards; do not edit them first.

**2.5 — `contract_version` stays 13.** No clause is added, and the footer's
`entries=50 at_current=50 behind=0 undeclared=0` must be byte-identical before and after.

**2.6 — The fixture COUNT does not move. The instrument that shows delivery is the assertion
count.** `story-fields-derive` goes **33 → 39**; the fixture total stays **112**. Per D-6c41.1 the
line-anchored instrument is blind to this fixture, so row 3 and row 6 give the run-based grep
literally, and a control fixture beside it.

---

## 3. Every command's argument order, because they are NOT the same

```
apply.sh            <dist> <base> <consumer> <theirs>
layer-drift.sh      <dist> <base> <theirs>   <consumer>
hard-blockers.sh    <dist> <base> <theirs>   <consumer>
```

**`apply.sh` with `<theirs>` and `<consumer>` swapped exits 0, writes almost nothing, and prints
`DECISION manifest-unreadable`** — a wrong-argument run that does not look like one.

```
E=/tmp/pull-engine-0239      # the pinned engine worktree, see row 1
B=44db151                    # your current stamp (0.238.0)
T=bd740f6                    # v0.239.0
G=/Users/n8/git/graph
R=$E/core/skills/ai-dlc-update/reconcile
```

- **`apply.sh` rows are TAB-separated.** A `'^RESOLVED '` grep on a space returns a vacuous 0.
- **`.githooks/pre-push` blocks forever on a non-TTY stdin that stays open.** Run it `</dev/null`.
- **`grep -c` on a file with no match PRINTS 0 and EXITS 1.** Under `set -e` or in a `$( )` feeding
  an arithmetic test that is a wedge, not a zero.

---

## 4. Pre-measured expectations — every figure came off the rehearsal

**4.1 — `apply.sh`: rc `0`, `0` bytes of stderr, **6 rows — 5 `RESOLVED`, 1 `DECISION`, 0
`WORKLIST`**.**

```
RESOLVED	pure-apply	scripts/sprint-status.sh
RESOLVED	pure-apply	fixtures/story-fields-derive/run.sh
DECISION	drift	skills/ai-dlc/extensions/README.md
RESOLVED	relabel	ext-check collisions labelled
RESOLVED	restamp	44db151 -> bd740f6
RESOLVED	consistent	the tree matches bd740f6; fixture suite re-enabled
```

**4.2 — the diff: 3 files, +147 / −12**, and `_bmad-output` is untouched (`0` paths).

```
 M .claude/.ai-dlc-version
 M scripts/ai-dlc/sprint-status.sh
 M tests/fixtures/story-fields-derive/run.sh
```

**4.3 — before and after, each with its control.**

| reading | before | after | control |
|---|---|---|---|
| `grep -c seen_resolved scripts/ai-dlc/sprint-status.sh` | **0** | **3** | — |
| `story-fields-derive` assertions | **33** | **39** | — |
| `layer-reference-resolution` assertions | 22 | **22** | must not move |
| fixtures with `run.sh` | 112 | **112** | must not move |
| stamp | `0.238.0` / `44db151` | **`0.239.0` / `bd740f6`** | — |
| `LAYER_CONFORMANCE` footer | `entries=50 at_current=50 behind=0 undeclared=0` | **byte-identical** | — |

**`grep -c derive-stories` is NOT a control on this release — it moves 17 → 20.** It was one in the
0.238.0 brief and it is not one here, because this release edits that script's prose. Use
`layer-reference-resolution` and the fixture count, both of which are genuinely untouched.

**4.4 — the suite: `112 ok`, and `1 FAIL` which is §2.1's, not this pull's.** rc `1`. Three runs on
the rehearsal clone: 43.70s / 42.18s / 41.77s, median **42.18s**.

**The control that attributes it: the identical `1 FAIL` appears on the UNAPPLIED clone at
`7d1d7862a`**, byte-for-byte down to the `LAYER_MEASURED` line's `E18=LC-M1:1/50`. It is graph's
trunk, not the pull. **After row 5 fixes `machinery.md`, expect `112 ok / 0 FAIL`, rc 0.**

---

## 5. Progress ledger — execute in order, tick each row before moving on

| # | Row | Repo | Status |
|---|---|---|---|
| 1 | Pre-flight: clean tree, pin the engine, confirm graph has not moved under this file | graph | **DONE** — `origin/main` still `7d1d7862a`; engine `0.239.0` @ `bd740f6`; stamp `0.238.0` / `44db151` |
| 2 | Classify only. Report the tallies. **Write nothing.** | graph | **DONE** — `0 HARD blockers`; `1 error(s), 1 warning(s)`; `contract_version=13`. **See §9.1 — the error was masked locally at first** |
| 3 | Bank the BEFORE figures, **including the red gate** | graph | **DONE** — red banked: `112 ok / 1 FAIL`, rc 1, ×3 |
| 4 | `apply` on ONE branch, and verify what did and did NOT arrive | graph | **DONE** — 5 R / 1 D / **0 W**; 3 files, +147 / −12. **See §9.2 — the stamp moved 2 of 4 lines, by design** |
| 5 | **Fix `machinery.md`'s stale `s279-4` entry** (§2.1) | graph | **DONE** — `E18` 1 → 0, `W7` still 1 |
| 6 | Assertion delta, full pre-push, commit, push, PR | graph | **DONE** — 39 / 22 / 112; `112 ok / 0 FAIL` rc 0; PR **#854** |
| 7 | Report back the readings §6c-51 needs, and answer §7 | graph | **DONE** — §6 filled, §7 answered: 7.1 **ACCEPTED**, 7.2 **DECLINED with a measurement** |

### Row 1 — pre-flight

```
cd $G && git status --porcelain && git fetch -q origin && git rev-parse origin/main
git -C /Users/n8/git/ai-dlc worktree add --detach /tmp/pull-engine-0239 bd740f6
cat /tmp/pull-engine-0239/VERSION
grep -E '^(version|commit|skill_version|skill_commit):' $G/.claude/.ai-dlc-version
```

**EXPECT:** engine `VERSION` = `0.239.0`; your stamp = `0.238.0` / `44db151`.
**`origin/main` was `7d1d7862a` when this brief was written. If it has moved, DO NOT STOP —
re-derive §4's before-figures**, and say which moved.

### Row 2 — classify only, write nothing

```
E=/tmp/pull-engine-0239; B=44db151; T=bd740f6; R=$E/core/skills/ai-dlc-update/reconcile
bash $R/hard-blockers.sh $E $B $T $G | tail -3
bash $R/layer-drift.sh   $E $B $T $G | grep -vE 'EXTENSION-OK|OVERRIDE-OK' | head -20
cd $G && bash scripts/ai-dlc/validate-layer-entries.sh $G 2>&1 | grep -E 'error\(s\)|LAYER_CONFORMANCE'
```

**EXPECT:** `0 HARD blockers`; validator **`1 error(s), 1 warning(s)`** — the error is §2.1's and
the warning is the known `W7` / `Check 11b` dangling pointer. `contract_version=13`.
**Write nothing in this row.**

### Row 3 — bank the BEFORE figures

```
cd $G
grep -c 'seen_resolved' scripts/ai-dlc/sprint-status.sh                                   # EXPECT 0
ls -d tests/fixtures/*/ | while read -r d; do [ -f "$d/run.sh" ] && echo x; done | wc -l   # EXPECT 112
bash tests/fixtures/story-fields-derive/run.sh 2>&1 | grep -cE '^  (ok|FAIL)'              # EXPECT 33
bash tests/fixtures/layer-reference-resolution/run.sh 2>&1 | grep -cE '^  (ok|FAIL)'       # control, EXPECT 22
for i in 1 2 3; do /usr/bin/time -p bash .githooks/pre-push </dev/null 2>&1 | awk '/real/{print $2}'; done
```

**The two verdict greps are DIFFERENT and D-6c42.1 is why.** Fixture verdicts carry **two** leading
spaces (`'^  (ok|FAIL)'`); the pre-push aggregate's carry **three**
(`'^[[:space:]]+ok[[:space:]]'`). Applying the fixture form to the aggregate returns a vacuous 0,
which on the before-side is indistinguishable from a gate that ran nothing.

**EXPECT `112 ok` and `1 FAIL`, rc 1, three times — and BANK THAT.** It is §2.1's, it is graph's
trunk, and recording it before the pull is what makes row 6's green attributable.

### Row 4 — apply on ONE branch

```
cd $G && git checkout -b chore/pull-0.239.0 origin/main
bash $R/apply.sh $E $B $G $T          # <dist> <base> <consumer> <theirs> — §3
git status --porcelain | sort
git diff --shortstat -- ':(exclude)_bmad-output'
grep -c 'seen_resolved' scripts/ai-dlc/sprint-status.sh                                   # EXPECT 3
git status --porcelain -- _bmad-output | wc -l                                            # EXPECT 0
grep -E '^(version|commit|skill_version|skill_commit):' .claude/.ai-dlc-version            # EXPECT all four 0.239.0 / bd740f6
```

**STOP CONDITIONS:** any `WORKLIST` row (§2.2); `apply` writing anything under `_bmad-output/`; a
second `DECISION`; the stamp not advancing on its own (§2.4).

### Row 5 — fix `machinery.md`'s stale entry

**This is the row with judgement in it and §2.1 is the decision.** Confirm first, then remove:

```
cd $G
grep -n 's279-4' .claude/skills/ai-dlc/machinery.md
ls -d scripts/ai-dlc-local/tests/fixtures/s279-4          # EXPECT: no such file or directory
git log --oneline -1 -- scripts/ai-dlc-local/tests/fixtures/s279-4
```

Delete that inventory line. Then:

```
bash scripts/ai-dlc/validate-layer-entries.sh $G 2>&1 | grep -E 'error\(s\)|LAYER_CONFORMANCE'
```

**EXPECT `0 error(s), 1 warning(s)`, and `entries=50 at_current=50 behind=0 undeclared=0`
unchanged.** The warning must still be there — a run that reports zero of both is a different
answer and means the instrument stopped reading, not that two things got fixed.

### Row 6 — assertion delta, full pre-push, commit, push, PR

```
cd $G
bash tests/fixtures/story-fields-derive/run.sh 2>&1 | grep -cE '^  (ok|FAIL)'              # EXPECT 39
bash tests/fixtures/layer-reference-resolution/run.sh 2>&1 | grep -cE '^  (ok|FAIL)'       # control, EXPECT 22
ls -d tests/fixtures/*/ | while read -r d; do [ -f "$d/run.sh" ] && echo x; done | wc -l   # EXPECT 112
bash scripts/ai-dlc/sprint-status.sh derive-stories --check | tail -4
for i in 1 2 3; do /usr/bin/time -p bash .githooks/pre-push </dev/null 2>&1 | awk '/real/{print $2}'; done
```

**EXPECT:** the derive prints a per-view breakdown and `over 1 story, 1 entry declared`; pre-push
`rc=0`, **112 ok / 0 FAIL** — the FAIL banked in row 3 is gone because row 5 fixed it.
**The control moving, or the subject reading anything but 39, is a hard stop.**

Commit the tracked changes only. **Two commits, not one**: the pull, and the `machinery.md` fix
described as a #853 follow-up. Push; open the PR.

### Row 7 — report back

Fill §6, answer §7, and commit this file with its ticks.

---

## 6. Report-back — the readings §6c-51 needs

Fill each cell with the measurement, not with "as expected".

| reading | expected | measured |
|---|---|---|
| `apply.sh` rc / stderr bytes / row counts | 0 / 0 / 5 R, 1 D, **0 W** | **rc 0, 0 bytes, 6 rows = 5 RESOLVED / 1 DECISION / 0 WORKLIST.** MATCH. Tallied on a literal tab; the `'^RESOLVED '` space form returned the vacuous 0 §3 warns about, printed beside it as the control |
| diff shape | 3 files, +147 / −12, `_bmad-output` 0 | **3 files, +147 / −12.** MATCH. `_bmad-output` carried **5 pre-existing** modified paths before the run (operational pipeline state, not mine to commit); `apply` added **0** and the set was byte-identical after |
| `seen_resolved` before → after | 0 → 3 | **0 → 3.** MATCH |
| `story-fields-derive` assertions before → after | 33 → 39 | **33 → 39.** MATCH, 0 FAIL within the fixture |
| `layer-reference-resolution` (control) | 22 → 22 | **22 → 22.** Did not move |
| fixture count (control) | 112 → 112 | **112 → 112.** Did not move |
| stamp, all four lines | `0.239.0` / `bd740f6` | **DEPARTURE, and the brief is what is wrong — see §9.2.** `version`/`commit` → `0.239.0` / `bd740f6` under `apply.sh`'s own restamp. `skill_version`/`skill_commit` stay `0.238.0` / `44db151`: `apply.sh` has no code path that writes them, and `ai-dlc-update/SKILL.md:1182` specifies the re-stamp as *preserving* them |
| `LAYER_CONFORMANCE` footer before/after | byte-identical | **`entries=50 at_current=50 behind=0 undeclared=0` byte-identical.** The `errors=`/`warnings=` tail moved `errors=1` → `errors=0` at row 5, as intended |
| **`E18` before row 5 / after row 5** | **1 → 0**, `W7` still 1 | **`E18=LC-M1:1/50` → `0/50`; `W7=LC-R2:1/50` at both.** MATCH. The `E18` line named `s279-4` and nothing else, so the §2.1 stop condition did not fire |
| pre-push before / after | `112 ok / 1 FAIL` rc 1 → `112 ok / 0 FAIL` rc 0 | **`112 ok / 1 FAIL` rc 1 → `112 ok / 0 FAIL` rc 0**, three runs each. MATCH. **See §9.3 — the `FAIL` grep needs a different form than the `ok` one** |
| suite median | ~42.2s | **before 46.58s** (46.58 / 48.06 / 45.28); **after 46.24s** (46.43 / 45.63 / 46.24). ~4s slower than the rehearsal at both ends, and equally slower on both sides, so it reads as this machine rather than as the pull |
| `derive-stories --check` on your envelope | breakdown + `over 1 story, 1 entry declared` | **MATCH, verbatim:** `implementation: 1 entry, 1 resolved` / `planning: 1 entry, 1 resolved` / `PASS — 0 drifted key(s) over 1 story, 1 entry declared` |

---

## 7. The two questions this pull hands back

Both are yours to decide and **a measured refusal is a legitimate answer to either.** Neither is
urgent: (a) has zero live subjects, and (b) strengthens a cross-check that already fires.

### 7.1 — Declare `title`, now that the class it was withheld for measures empty

Your side-by-side §5 item 1 withheld `title` from `story-fields.md` because one declaration drives
both the check and the write, and the write was unsafe. **v0.237.1 fixed the write and this brief
measured the result: 262 of 262 of your titles are writable, 0 refused, control 29.** Its drift is
presently checked by nothing.

The remedy is one `field: title` line. **The upstream ask it generated — a check-only field form —
is REFUTED with that measurement**, and building it would be a grain for an empty class.

**If you decline, say why with a measurement**, not with "it was unsafe once".

#### ANSWER — ACCEPTED. The write-unsafe class measures empty on this corpus.

Re-measured here rather than taken from the brief, and **end-to-end through the real script** —
a first attempt using a synthetic harness that called `yaml_scalar`/`rewrite_field_value` directly
produced an incoherent reading (a control of 0 where 29 was expected), so it was discarded rather
than reported. What is below drives `sprint-status.sh derive-stories` in **write mode**.

Method: a synthetic project carrying **all 262** of this repo's story files that have a `title:`
in frontmatter, one envelope entry each, `field: title` declared, derive run in write mode, then
the written envelope parsed with `yaml.safe_load` and every value compared to its source.

| script | envelope after the write | titles round-tripping | `title:` lines that do not parse standalone |
|---|---|---|---|
| shipping (v0.239.0) | **parses** | **262 / 262** | **0 / 262** |
| control (v0.237.0, `git show f15ce5915:`) | **UNPARSEABLE** — `mapping values are not allowed here` | — | **29 / 262** |

The control script carries **0** occurrences of `yaml_scalar`, confirming it is the pre-fix
version, and it fires — so the instrument discriminates rather than passing everything. The 29
reproduces the figure in `yaml_scalar`'s own docstring, independently, on this corpus.

**`title` is writable. The withholding in `story-fields.md` rests on a defect that no longer
exists, and the upstream ask it generated — a check-only field form — is refuted with that
measurement.**

**Not implemented in this PR, deliberately.** Adding `field: title` changes what the gate
compares project-wide and can turn gates red on existing drift; §7 hands it back as the
operator's decision, and it is not one of this brief's six rows. The remedy is one `field: title`
line plus retiring the `title` row's "DERIVED BUT WITHHELD" verdict in
`.claude/skills/ai-dlc/story-fields.md`. Say the word and it is a one-line follow-up.

### 7.2 — Repoint your yaml-side denominator to core's number, or record why not

`entry_count_no_idregex` exists because the retired generator's independent count went away and
both sides of cross-check B ended up inside one script — your residue item 4, caught by the
mutation proof rather than by review. **Core now emits the same number on the mode you already
call**, from a genuinely separate program with a separate parser, so taking it *raises* the
independence rather than lowering it, and it drops a `yq` dependency.

**This is a judgement, not a directive.** Your incumbent already fires on probe D; the gain is
structural, not a missing signal. **A measured decision to keep `entry_count_no_idregex` is a
legitimate ending** — record it with its reason in your side-by-side, per D-4.5.

**What is NOT on offer, and it is settled: core supplying the CORPUS side.** Core resolves files
from entries by construction. A membership rule for which files on disk are stories is yours, the
same way the derivable-field set is, and asking core to infer it is the eight refuted predicates'
territory.

#### ANSWER — DECLINED, and the measurement is a scope difference, not a preference.

On the live envelope the two numbers agree, so today's corpus **cannot tell them apart** —
agreement at n=1 is not evidence either way:

```
current sprint: 299
  entry_count_no_idregex(planning-artifacts)       = 1
  entry_count_no_idregex(implementation-artifacts) = 1
  core:  PASS — 0 drifted key(s) over 1 story, 1 entry declared
```

So the question was put to a corpus that *can* discriminate: a two-view project whose views carry
**different entry sets** — `story-42-1` in both, `story-42-2` in the implementation view only.

```
incumbent (planning view only) : 1
incumbent (impl view only)     : 2
core derive-stories --check    : implementation: 2 entries, 2 resolved
                                 planning:       1 entry,  1 resolved
                                 FAIL — 3 drifted key(s) over 2 stories, 2 entries declared
```

**The incumbent reads 1 where core reads 2.** They are not interchangeable, and the divergence is
structural rather than incidental: `entry_count_no_idregex` reads the **planning view alone**,
while core's new number is the **union of both views** — which is exactly the change v0.239.0
made, and it is correct for core's purpose.

It is the wrong denominator for cross-check B. That check compares the union against Step-1
`checked`, a recursive `find` over story **files**. A story declared in the implementation view,
present on disk, and **missing from the planning envelope** is a membership divergence: the
incumbent reads 1 against `checked` 2 and **fires**; core's union reads 2 against `checked` 2 and
is **silent**. Repointing would buy a separate program and a separate parser at the cost of going
blind to the case the check is fail-closed for.

Recorded per D-4.5 with its reason. The `yq` dependency stays; it is the cheaper of the two costs.
**If core ever emits the per-view counts as separate readable numbers** — it already prints them
in the breakdown — the planning-view figure alone would be a genuine drop-in, and this answer
would flip. That is a smaller upstream ask than the refuted one, and it is the one worth filing.

---

## 8. Known-open, deliberately out of scope

- **`W7` / `Check 11b`** — the dangling check pointer. Pre-existing, one line, nobody's step. It is
  the `1 warning` this brief expects at every reading and it doubles as the control that the
  validator is still emitting.
- **`extensions/README.md` `DECISION drift`** — §2.3, fourth pull running.
- **The `sprint-168` provenance disposition** and **`_bmad-output/.audit-watermark` being
  gitignored while both tools write it** — both recorded by §6c-38, both still nobody's step.
- **`OVERRIDE-DOUBLE-SHADOW` on `steps/retro.md#4a`** and the two
  `OVERRIDE-ASSERTS-SHADOW-SURVIVES` rows — report-only, unchanged by this pull, and named here so
  a reader of row 2's output does not mistake them for new.

All three appeared in row 2's output exactly as described, alongside the pre-existing
`EXTENSION-RESTATES-CORE` on `checks/gate-validation-push.md`. Nothing new.

---

## 9. Departures from this brief, and what each turned out to be

Three readings did not match §4. None was noise, and none stopped the pull.

### 9.1 — `E18` did not fire in the working tree, and the brief was right anyway

Row 2 expected `1 error(s), 1 warning(s)`. The live tree read **`0 error(s), 1 warning(s)`** with
`E18=LC-M1:0/50` — the red gate §2.1 exists to fix was **invisible here**.

Cause: `#853` deleted all 16 tracked files under `tests/fixtures/s279-4/`, but a working tree that
had ever run the deleted `mutation_selfcheck.py` still held
`s279-4/__pycache__/mutation_selfcheck.cpython-314.pyc`, ignored by `.gitignore:59`. `E18` tests
path existence, and the ignored bytecode directory satisfies it. `git status` is silent on it by
construction, so the tree looks clean while the check reads the opposite of trunk.

The brief's §2.1 table was then reproduced on untouched clones rather than assumed, with `W7`
unchanged at both as the control:

| ref | verdict | `E18` | `W7` |
|---|---|---|---|
| `91a3b8910` | `0 error(s), 1 warning(s)` | `0/50` | `1/50` |
| `7d1d7862a` | **`1 error(s), 1 warning(s)`** | **`1/50`** | `1/50` |

Removing the stale `__pycache__` made the live tree reproduce trunk (`E18=1/50`), which is what
made row 3's banked red real and row 6's green attributable. **Anyone re-running §2.1 on a
long-lived checkout will see the same false green** — that note is in the fix commit.

### 9.2 — the stamp advanced 2 of 4 lines, and that is correct

Row 4 expected all four stamp lines at `0.239.0` / `bd740f6`. Measured: `version` and `commit`
advanced; `skill_version` and `skill_commit` stayed at `0.238.0` / `44db151`.

This is `apply.sh` behaving as specified, not a partial write. Its restamp is
`sed -E 's/^(version:).*/'` and `s/^(commit:).*/'` — the `^` anchor cannot match `skill_version:`
or `skill_commit:`, so **the engine has no code path that writes those two lines at all**.
`ai-dlc-update/SKILL.md:1182` specifies the re-stamp as *"preserving `skill_version` /
`skill_commit` / `installed_at` / `upstream`"*, and lines 42-43 define `skill_version` as the
ai-dlc-update tool itself, advanced by the autonomous self-update, not by a content pull. v0.239.0
touches no skill file, so there is nothing to self-update.

The four prior pulls moved all four in lockstep only because of the manual `sed` that §2.4
correctly drops. **§2.4's actual stop condition — "the stamp not advancing on its own" — did not
fire.** Nothing was hand-edited. The brief's row-4 EXPECT is the line to correct for the next pull.

### 9.3 — the `FAIL` verdict needs a different grep from the `ok` verdict

§3 and row 3 give the aggregate `ok` form as `'^[[:space:]]+ok[[:space:]]'`, and it is right — the
aggregate's `ok` lines are followed by a fixture name. **The symmetric `FAIL` form returns a
vacuous 0**: the failing verdict renders as a bare `   FAIL` with nothing after it, so a trailing
`[[:space:]]` matches nothing.

That zero is the dangerous kind. On the before-side, `112 ok / 0 FAIL` at rc 1 is exactly what a
green suite looks like, and the red row 3 exists to bank would have been recorded as absent.
Use `'^[[:space:]]+FAIL[[:space:]]*$'`; the same form finds the 8 `PASS` verdicts, which is the
control that it reads bare verdict lines rather than nothing.
