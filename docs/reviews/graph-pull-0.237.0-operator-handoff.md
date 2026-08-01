# graph pull — v0.237.0

**One release. One branch. Seven rows.** Written from a rehearsal, not from a plan: every figure
in §4 came off an end-to-end run against a `git clone --local` of graph at `63cff7274`, with the
real `apply.sh` from an engine worktree pinned at `0cc51fc` and graph's own `.githooks/pre-push`.
**graph itself was never written to, and that was verified after the fact** — `origin/main`
unmoved, working tree still its four pre-existing `_bmad-output/` entries, engine worktree removed.

**What this pull is for.** `sprint-status.sh derive-stories` writes each declared story-entry field
back from the story file that entry names. It is the WRITE half of the join `check-stories` already
reads, and every part of it does its work here rather than in the distribution.

---

## 1. What this pull carries

**v0.237.0 — the consumer declares its derivable story fields; core derives from the declaration.**

`consumer_story_fields_file:` is the fourth consumer-owned file the layer contract declares, after
the crosswalk, the machinery inventory and the PR-class taxonomy. Same terms: scaffolded once,
never overwritten, location derived by every reader.

```
field: priority
field: effort
```

**`status` is not declarable and is always derived.** It comes from
`.claude/schemas/sprint-status.json`, because it is the field gate-validation Check 5 depends on.
The declaration ADDS to that floor and cannot subtract from it.

**Why a declaration and not a constant.** Your own tool derives NINE fields; the schema declares
TWO story-entry fields, exactly ONE of which is among the nine. Hand-listing the other eight in
core would be a second home for a schema. Core cannot know that this project's stories carry
`capital_path`.

**Three exit codes, and two of them exist to stop a silent success:** `1` drift found and nothing
written; `3` matched ZERO story files; `4` matched files and some story got zero comparisons.

---

## 2. Locked decisions — do not re-open these mid-run

**2.1 — The pull SCAFFOLDS `.claude/skills/ai-dlc/story-fields.md` and it arrives declaring the
literal `none`.** That is a placeholder, not an answer. `derive-stories` will print a worklist line
and derive only `status`, and **a silent worklist is not this goal being met** — the same trap the
0.234.1 brief locked for `machinery.md`. Adopting the declaration is a separate, deliberate act and
it is NOT this pull's.

**2.2 — The `DECISION drift` row on `extensions/README.md` is NOT this release's.** v0.237.0
touches **0** files under that path; your copy already differs from core's at your current base by
2 lines — your own step-27 edit to a core-owned worked example. Same row the last two pulls
carried, for the same reason. **Leave it. Do not "resolve" it by taking core's copy**, which would
revert your edit.

**2.3 — `contract_version` stays 13 and every footer field is unchanged.** This release adds a
declaration key and no clause. **A footer field that moves is a finding, not a consequence.**

**2.4 — Nothing about your existing output changes.** `derive-stories` is not wired into any gate;
it runs when someone runs it. Both validators' `0 error(s), N warning(s)` lines are unchanged, and
§4.5 states that as a reproduced reading rather than a hope.

**2.5 — Read the assertion delta RUN-BASED.** The line-anchored instrument the earlier briefs used
(`grep -cE '^\s*(ok|bad) '`) scores **38 of your 111 fixtures at zero** — it cannot see an
assertion written in the continuation style, and the fixture this release adds is written that
way. Row 3 and row 6 use a run-based count for it, with an untouched fixture as the control.
*(Note also that `\s` is not a class in BSD `grep -E`; row 3 writes the bracket form.)*

---

## 3. Every command's argument order, because they are NOT the same

**Sixth brief in this series to carry this table, and still not optional.**

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
E=/tmp/pull-engine-0237      # the pinned engine worktree, see §5 row 1
B=7d2dd6a                    # your current stamp (0.236.0)
T=0cc51fc                    # v0.237.0
G=/Users/n8/git/graph
```

**Two instrument notes from your own earlier runs, both false-zero sources:**

- **`apply.sh` rows are TAB-separated.** A tally grepped as `'^RESOLVED '` — with a space —
  returns a vacuous **0** against real rows.
- **`.githooks/pre-push` blocks forever on a non-TTY stdin that stays open.** Run it `</dev/null`.

---

## 4. Pre-measured expectations — every figure came off the rehearsal

**4.1 — `apply.sh`: rc `0`, `0` bytes of stderr, `12` rows — 11 `RESOLVED`, 1 `DECISION` (§2.2),
no `WORKLIST`.**

```
RESOLVED	pure-apply	scripts/sprint-status.sh
RESOLVED	pure-apply	skills/ai-dlc-update/reconcile/apply.sh
RESOLVED	pure-apply	skills/ai-dlc-update/reconcile/setup-sites.md
RESOLVED	pure-apply	skills/ai-dlc/core-manifest.md
RESOLVED	pure-apply	skills/ai-dlc/layer-contract.yaml
RESOLVED	pure-apply	skills/ai-dlc/templates/story-fields.md
RESOLVED	pure-apply	fixtures/story-fields-derive/run.sh
DECISION	drift	skills/ai-dlc/extensions/README.md
RESOLVED	relabel	ext-check collisions labelled
RESOLVED	story-fields-scaffold	.claude/skills/ai-dlc/story-fields.md
RESOLVED	restamp	7d2dd6a -> 0cc51fc
RESOLVED	consistent	the tree matches 0cc51fc; fixture suite re-enabled
```

`story-fields-scaffold` is a row shape no previous pull has produced.

**4.2 — Diff surface: 6 files modified, +345 / −4, plus 3 new paths.**

```
 M .claude/.ai-dlc-version
 M .claude/skills/ai-dlc-update/reconcile/apply.sh
 M .claude/skills/ai-dlc-update/reconcile/setup-sites.md
 M .claude/skills/ai-dlc/core-manifest.md
 M .claude/skills/ai-dlc/layer-contract.yaml
 M scripts/ai-dlc/sprint-status.sh
?? .claude/skills/ai-dlc/story-fields.md
?? .claude/skills/ai-dlc/templates/story-fields.md
?? tests/fixtures/story-fields-derive/
```

**The count is 6 / +345 / −4 under `:(exclude)_bmad-output`.** Your four pre-existing runtime files
sit in the tree and a bare `--shortstat` includes them; and after row 5 the modified count rises
by the stamp's two extra lines. **Quote which of the three you are reporting** — the 0.236.0 run
found all three and none was labelled.

**4.3 — The reading that settles delivery is a JOIN, and it discriminates.**

| reading | before | after |
|---|---|---|
| `derive-stories` in the installed `sprint-status.sh` | **0** | **16** |
| live-sibling control — `check-stories`, same file, same grep | 12 | 17 |
| `.claude/skills/ai-dlc/story-fields.md` | **absent** | **3,760 bytes** |

**4.4 — `hard-blockers.sh`: `0 HARD blockers`, before and after.**

**4.5 — Validator after the pull: `0 error(s), 1 warning(s)`**, footer
`LAYER_CONFORMANCE v1 contract_version=13 entries=50 at_current=50 behind=0 undeclared=0 errors=0 warnings=1`
— **byte-identical to the before-run.** The one warning is the pre-existing dangling `Check 11b`.

**4.6 — Drivable fixtures: 111 → 112. UP BY ONE, NOT TWO.** `story-fields-derive-mutants` is
`.dist-only` and **must be ABSENT**; `story-fields-derive` must be present. **Both halves are a
check**: a missing subject is a delivery failure, a present mutant battery is a packaging defect.

**4.7 — Assertion counts, RUN-BASED per §2.5.**

| instrument | before | after |
|---|---|---|
| run-based, `story-fields-derive` | (absent) | **25** |
| control — run-based, `layer-reference-resolution` (untouched by this release) | **22** | **22** |

The control is what makes the 25 a reading: the same instrument produced a number for a fixture
this release does not touch and it did not move.

**4.8 — The derive's own first run, after the pull, on your real tree.** Measured:

```
sprint-status: derive-stories WORKLIST — .claude/skills/ai-dlc/story-fields.md declares the
  literal `none`, so this project derives nothing beyond the schema's own floor.
sprint-status derive-stories: sprint 299, fields status (--check: nothing will be written)
sprint-status: derive-stories --check PASS — 0 drifted key(s) over 2 stories
```

**rc 0, and `_bmad-output` is untouched by the pull — 0 modified paths under it.** That is the
whole of what this release does to your tree until you declare fields.

**4.9 — Timing, a SANITY BOUND and not a result.** This release changes no scheduling. Same clone,
same box, same session, three runs each side: before **41.92 / 41.93 / 42.11 → median 41.93s**;
after **44.19 / 42.04 / 42.38 → median 42.38s**; **111 `ok` → 112 `ok`, 0 `FAIL` on all six.** The
new fixture was measured against a CONSUMER's schedule before it shipped — 0.52s against an 8.70s
pole. **Report your own figures; do not match them against these.**

---

## 5. Progress ledger — execute in order, tick each row before moving on

| # | Row | Repo | Status |
|---|---|---|---|
| 1 | Pre-flight: clean tree, pin the engine, confirm graph has not moved under this file | graph | — |
| 2 | Classify only. Report the tallies. **Write nothing.** | graph | — |
| 3 | Bank the BEFORE figures — timing, and the run-based assertion control | graph | — |
| 4 | `apply` on ONE branch, and verify what did and did NOT arrive | graph | — |
| 5 | Advance the machinery stamp | graph | — |
| 6 | Assertion delta, full pre-push, commit, push, PR | graph | — |
| 7 | Report back the readings §6c-42 needs | graph | — |

### Row 1 — pre-flight

```
cd $G && git status --porcelain && git fetch -q origin && git rev-parse origin/main
git -C /Users/n8/git/ai-dlc worktree add --detach /tmp/pull-engine-0237 0cc51fc
cat /tmp/pull-engine-0237/VERSION
grep -E '^(version|commit):' $G/.claude/.ai-dlc-version
```

**EXPECT:** engine `VERSION` = `0.237.0`; your stamp = `0.236.0` / `7d2dd6a`; working tree carries
only your four `_bmad-output/` entries.

**`origin/main` was `63cff7274` when this brief was written. If it has moved, DO NOT STOP —
re-derive §4's before-figures instead.** §6c-38's retirement may have landed first, and it is
PARALLEL with this pull by construction: it touches `scripts/ai-dlc-local/` and `pr-classes.md`,
and nothing this pull writes is under either. The figures that could move are §4.7's control and
§4.9's timings; §4.1 through §4.6 are about `.claude/` and should hold verbatim.

### Row 2 — classify only, write nothing

```
E=/tmp/pull-engine-0237; B=7d2dd6a; T=0cc51fc
R=$E/core/skills/ai-dlc-update/reconcile
bash $R/hard-blockers.sh $E $B $T $G | tail -3
bash $R/layer-drift.sh   $E $B $T $G | tail -5
cd $G && bash scripts/ai-dlc/validate-layer-entries.sh $G 2>&1 | grep -E 'error\(s\)|LAYER_CONFORMANCE'
```

**EXPECT:** `0 HARD blockers`. Validator `0 error(s), 1 warning(s)`, `contract_version=13`,
`at_current=50 behind=0`. **Write nothing in this row.**

### Row 3 — bank the BEFORE figures

```
cd $G
grep -c 'derive-stories' scripts/ai-dlc/sprint-status.sh        # EXPECT 0
grep -c 'check-stories'  scripts/ai-dlc/sprint-status.sh        # the control, EXPECT 12
ls -d tests/fixtures/*/ | while read -r d; do [ -f "$d/run.sh" ] && echo x; done | wc -l   # EXPECT 111
bash tests/fixtures/layer-reference-resolution/run.sh 2>&1 | grep -cE '^  (ok|FAIL)'       # EXPECT 22
for i in 1 2 3; do /usr/bin/time -p bash .githooks/pre-push </dev/null 2>&1 | awk '/real/{print $2}'; done
```

**EXPECT:** three timed runs, all `rc=0`, 111 `ok` / 0 `FAIL`. **Record the median; it is a sanity
bound.**

### Row 4 — apply on ONE branch

```
cd $G && git checkout -b chore/pull-0.237.0 origin/main
bash $R/apply.sh $E $B $G $T          # <dist> <base> <consumer> <theirs> — §3
git status --porcelain | sort
git diff --shortstat -- ':(exclude)_bmad-output'
grep -c 'derive-stories' scripts/ai-dlc/sprint-status.sh                 # EXPECT 16
grep -c 'check-stories'  scripts/ai-dlc/sprint-status.sh                 # control, EXPECT 17
wc -c < .claude/skills/ai-dlc/story-fields.md                            # EXPECT 3760
awk '/^```/{f=!f;next} f' .claude/skills/ai-dlc/story-fields.md | grep -vE '^\s*(#|$)'   # EXPECT: none
[ -d tests/fixtures/story-fields-derive-mutants ] && echo "PACKAGING DEFECT" || echo "dist-only held"
git status --porcelain -- _bmad-output | wc -l                           # EXPECT 4, your pre-existing files
```

**STOP CONDITIONS, all four:** `apply` writing `story-fields.md` on a tree that already had one;
`apply` writing anything under `_bmad-output/`; a `WORKLIST` row; a second `DECISION` row. Any of
them and this brief's model of the pull is wrong.

### Row 5 — advance the machinery stamp

`apply` advances `version:`/`commit:` and leaves `skill_version:`/`skill_commit:` at the old
release. Advance both so all four agree:

```
cd $G && sed -i '' 's/^skill_version: 0\.236\.0/skill_version: 0.237.0/; s/^skill_commit: 7d2dd6a/skill_commit: 0cc51fc/' .claude/.ai-dlc-version
grep -E '^(version|commit|skill_version|skill_commit):' .claude/.ai-dlc-version
```

**EXPECT:** all four lines reading `0.237.0` / `0cc51fc`.

### Row 6 — assertion delta, full pre-push, commit, push, PR

```
cd $G
bash tests/fixtures/story-fields-derive/run.sh 2>&1 | grep -cE '^  (ok|FAIL)'              # EXPECT 25
bash tests/fixtures/layer-reference-resolution/run.sh 2>&1 | grep -cE '^  (ok|FAIL)'       # control, EXPECT 22
ls -d tests/fixtures/*/ | while read -r d; do [ -f "$d/run.sh" ] && echo x; done | wc -l   # EXPECT 112
for i in 1 2 3; do /usr/bin/time -p bash .githooks/pre-push </dev/null 2>&1 | awk '/real/{print $2}'; done
```

**EXPECT:** pre-push `rc=0`, **112 ok / 0 FAIL**. **A control moving, or the subject reading
anything but 25, is a hard stop.**

Then commit **the tracked changes only** — leave your four `_bmad-output/` runtime files
uncommitted — push, and open the PR.

### Row 7 — report back

Fill §6 and commit this file with its ticks. **`ai-dlc` owns this file; committing your ticks into
it is a recording act, and the seven briefs before this one were closed the same way.**

---

## 6. Report-back — the readings §6c-42 needs

| reading | value | its control |
|---|---|---|
| `origin/main` before | | `ls-remote` agrees |
| apply rows | | 0 bytes stderr |
| diff surface (say WHICH of the three) | | the §4.2 path set exactly |
| `derive-stories` in the installed script | | `check-stories`, same file, same grep |
| `story-fields.md` scaffolded, block = `none` | | absent before |
| validator after | | same footer fields as before |
| drivable fixtures | | `story-fields-derive-mutants` ABSENT |
| assertion count, run-based | | the untouched control fixture |
| `_bmad-output` paths the pull touched | | expect 0 beyond your pre-existing four |
| gate timing | | verdict count both sides |
| commit / PR / merge sha | | |

---

## 7. Known-open, deliberately out of scope

- **Declaring your derivable fields is NOT this pull.** The scaffold arrives saying `none`, which
  is honest and is not the goal being met. Do it in its own branch once you have decided which of
  your nine fields are genuinely derived from the story file rather than authored in the envelope
  and mirrored into it — **core has no way to tell those two apart by looking.**
- **§6c-38's retirement of `audit-main-since.sh`** is the other open row and is PARALLEL with this
  one. v0.236.0 gave the grammar `capture:`, so the three sprint-keyed obligations that blocked it
  can now be declared.
- **The `sprint-168` provenance finding at `5d2a12156`** still wants an operator disposition.
- **`W7` / `Check 11b`** remains a live dangling check pointer. Pre-existing, one line.
