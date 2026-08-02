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
| 1 | Pre-flight: clean tree, pin the engine, confirm graph has not moved under this file | graph | ✅ `origin/main` still `0040b020e`; engine `0.238.0`; stamp `0.237.0`/`0cc51fc` |
| 2 | Classify only. Report the tallies. **Write nothing.** | graph | ✅ `0 HARD blockers`; validator `0 error(s), 1 warning(s)` `contract_version=13`; drift: 1 `HARD-OVERRIDE-DRIFT-SECTION` (check-5) + 6 `EXTENSION-HOOK-DRIFT` + 6 paired `HARD-LAYER-ADJUDICATION-MISSING`; rest OK/pre-existing |
| 3 | Bank the BEFORE figures — timing, and both assertion instruments | graph | ✅ `yaml_scalar` 0 / control 16 / invoking 0 / fixtures 112 / derive 25 / control 22; pre-push ×3 rc 0, 112 ok / 0 FAIL, median 45.11s. D-6c42.1 reproduced: fixture-form grep on the aggregate = vacuous 0 |
| 4 | `apply` on ONE branch, and verify what did and did NOT arrive | graph | ✅ branch `chore/pull-0.238.0`; rc 0, 0B stderr, 15 rows (7 R / 1 D / 7 W) identical to §4.1; §4.2 diff 5 files +169/−3; `yaml_scalar` 0→2, control 16→17, step files 0→2; `_bmad-output` untouched (5 pre-existing) |
| 5 | **Re-adopt the Check 5 override with core's new arm** (§2.1), then advance the stamp | graph | ✅ arm carried verbatim, `base_sha` 3490997→44db151, reason block records it came from core; all 7 core bullets still present (controlled); `HARD-OVERRIDE-DRIFT-SECTION` 1→0, `OVERRIDE-OK` 11→12. Six rereads: 0 command-list restatements (controlled 4/1 positive, 10–294 readability). **Beyond the brief:** 6 `LC-E4` `still-additive` records appended, register 24→30, aside/restore control 0/6/0. Stamp all four lines `0.238.0`/`44db151` |
| 6 | Assertion delta, full pre-push, commit, push, PR | graph | ✅ subject 25→**33**, control 22→22, fixtures 112→112; validator footer byte-identical; pre-push ×3 rc 0, 112 ok / 0 FAIL, median 45.07s; commit `91b865c76`, PR #852, merged `91a3b8910`. No service/infra path in the diff, so no ECS deploy |
| 7 | Report back the readings §6c-48 needs, and answer §7's question | graph | ✅ §6 filled with every reading and its control; §7 answered in **§7.1** — `--close-sweep` has **no live subject** and is **contraindicated** on this shape (it would prune the block `sprint-id` reads). No core row returns upstream. §7.2 measures the residual: a **2-field** declaration gap, not a capability gap |

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
| `origin/main` before | `0040b020e` — **unmoved**, §4's before-figures stand as written | `ls-remote` agreed with `rev-parse` |
| apply rows | rc `0`, **15 rows** — 7 `RESOLVED` / 1 `DECISION` / **7 `WORKLIST`**, identical to §4.1's set | **0 bytes** stderr; no 8th `WORKLIST`, no 2nd `DECISION`, no `story-fields.md` row |
| diff surface (say WHICH) | **two quoted, both named.** The **§4.2 pull-only** figure: **5 files, +169 / −3**, no new paths. The **committed** figure: **7 files, +242 / −14** (adds the re-adopted override + the register) | the §4.2 path set matched exactly, all ` M`, no `??` |
| `yaml_scalar` installed | **0 → 2** | live sibling `derive-stories`, same file, same grep: **16 → 17** |
| step files invoking `derive-stories` | **0 → 2** | 0 before |
| Check 5 override re-adopted, `base_sha` advanced | **yes** — arm carried verbatim, `3490997 → 44db151`, reason block records it came from core | arm present (`NEVER WRITES` clause = 1); **all 7 core bullets still present**; `HARD-OVERRIDE-DRIFT-SECTION` 1 → 0, `OVERRIDE-OK` 11 → 12 |
| validator after | `0 error(s), 1 warning(s)` | footer **byte-identical**: `contract_version=13 entries=50 at_current=50 behind=0 undeclared=0 errors=0 warnings=1`. §2.4 held |
| drivable fixtures | **112 → 112** | unchanged, as §2.5/§4.6 predicted |
| assertion count, run-based | `story-fields-derive` **25 → 33** | untouched `layer-reference-resolution`: **22 → 22** |
| `_bmad-output` paths the pull touched | **0.** Status showed the same 5 pre-existing paths after `apply` as before it | the 6th path (`layer-adjudication-register.jsonl`) is **this commit's, not the pull's** — appended after the row-4 reading was banked |
| gate timing | before **45.59 / 44.75 / 45.11 → median 45.11s**; after **44.73 / 45.07 / 45.52 → median 45.07s**. Slower than the rehearsal's ~41.9s in absolute terms, but a **sanity bound** and flat across the pull | **112 `ok` / 0 `FAIL`, rc 0, all six runs**, via the aggregate grep. D-6c42.1 reproduced live: the fixture-form grep on the aggregate returns a vacuous **0** |
| commit / PR / merge sha | commit `91b865c76` · PR **#852** · merge **`91a3b8910`** (squash, branch deleted) | `ls-remote` and local `main` both `91a3b8910`; stamp on `main` reads `0.238.0` on all four lines |

**Two additions beyond the brief, both flagged rather than folded in silently:**

1. **Six `LC-E4` adjudication records.** `layer-drift.sh` raised 6 `HARD-LAYER-ADJUDICATION-MISSING` rows paired with the 6 `EXTENSION-HOOK-DRIFT` rows — a mechanism §2.2 does not mention, though graph's own 0.224.0 pull row 3 set the precedent. All six recorded **`still-additive`**, register **24 → 30**. `LC-E4` was derived from the incoming contract at `44db151` (adjacent `LC-E3` carries a different code, as the control), and digests were extracted programmatically from drift field 4 rather than hand-copied. Control that the register is what cleared the rows: present **0**, moved aside **6**, restored **0**. `hard-blockers.sh` stayed `0` throughout.

2. **Two now-false statements in the override body, corrected.** Carrying core's arm made the generator-diff bullet's *"core has no equivalent"* and the evidence bullet's *"record this for **both** commands"* untrue. Both were fixed — the second to "all three", since an evidence count recorded for two of three arms is exactly the blind spot that bullet exists to close.

**One discrepancy against the brief, minor.** §4.8 describes "its own six-field declaration"; the live run enumerates **seven** field names — `status, priority, model, gate_1_model, effort, capital_path, acceptance_criteria`. That is `s6c-43`'s six declared fields plus `status`, which core derives regardless. The `--check` verdict itself matched §4.8 exactly: `PASS — 0 drifted key(s) over 2 stories`, rc 0.

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

### 7.1 — ANSWER: no live subject, and the operation is CONTRAINDICATED on this shape

**Four readings, each with a control. Not a judgement — the last one is the decisive one and it
came off core's own source, not off an opinion about it.**

**(a) Both canonicals are single-owner, measured by the generator's OWN partition.** Not by eye and
not by regex-reasoning — `partition_monolith` was called directly on both live files:

```
planning        segs=2 owners=['299'] sprint_owners=[299] closing=299 foreign=[] trailing_envelope=False
implementation  segs=2 owners=['299'] sprint_owners=[299] closing=299 foreign=[] trailing_envelope=False
```

`foreign=[]` and `trailing_envelope=False` are exactly the two conditions the `sys.exit(3)`
HARD_BLOCK at `_run_close_sweep` guards. **Positive control** — the same partition over the same
file with one synthetic `sprint_298_leftover:` block appended returns `sprint_owners=[298, 299]`,
`foreign=[298]`, and the guard WOULD fire. So the guard is live machinery with an absent subject,
not dead code, and the zero is a real zero.

**(b) The schema-collision key resolves to the SAME owner, so it never reads as foreign.**
`SPRINT_KEY_RE = ^sprint[_-]([0-9]+)(?:[_-][A-Za-z0-9][A-Za-z0-9_-]*)?:` does match
`sprint_299_housekeeping:` — but it captures owner **299**, which is the closing sprint. The one
apparent monolith key cannot manufacture a multi-sprint canonical.

**(c) Rotation is already working, and the migration is already complete.** `_preamble.yaml` is
present in **both** views, which is `--migrate`'s output and confirms the `active=299 frozen=0
no-loss=OK` one-time split really did complete. Archived per-sprint views: planning **53**,
contiguous `246..298`, no gaps; implementation **44**, contiguous `279..298` (its earlier gaps all
predate 279). **299 is absent from both** — the steady one-behind pattern. Control: a bogus
directory reads **0**.

**(d) THE DECISIVE READING — core rotates at pipeline START, not at close, so the unfrozen 299 is
core's INTENDED state rather than a pending close-sweep subject.** From core's own header in
`scripts/ai-dlc/sprint-status.sh`:

> `ROTATION HAPPENS AT PIPELINE START, NOT AT CLOSE.` `roll` freezes the closed sprint to
> `sprint-status/sprint-<N>.yaml` and writes the new envelope in ONE step. The reference consumer
> rotates at retro-close instead, **which prunes the `status: done` block that sprint-id must
> read** and leaves a preamble-only file no rule covers — a window its lead fills BY HAND.

This was tested, not taken on trust. `sprint-status.sh sprint-id` currently returns **300**, rc 0 —
derived from the `status: done` sprint-299 block still resident in the canonical. **That block is
precisely what `--close-sweep`'s prune leg would delete.**

**So the answer is stronger than "no subject."** The one capability `--close-sweep` uniquely has —
partitioning a multi-sprint canonical — has **no live subject** (a). Its freeze-and-prune is not
merely redundant with core's `roll`; on this shape it is **actively harmful**, because it would
destroy the input `sprint-id` reads to compute the next sprint (d). The absent `sprint-299.yaml`
that looks like pending work is the correct state, and `roll --sprint 300` is what freezes it.

**Therefore §6c-43's FIRST reason dissolves, and this pull dissolves the SECOND.** Both reasons for
not retiring `generate-sprint-status.py` are now gone. **No core row comes back upstream from this
question** — core's whole-text freeze is right for the shape, and there is no rotation grain for
core to gain.

### 7.2 — what retirement still needs, which is one declaration, not a capability

One residual, and it is a measurement rather than a caveat. The consumer's `DERIVABLE` list is
**9** fields; core's live declaration derives **7**:

| | fields |
|---|---|
| consumer `DERIVABLE` (`generate-sprint-status.py:47`) | `status, priority, model, gate_1_model, effort, capital_path, acceptance_criteria, sprint, title` |
| core, live `derive-stories` run | `status, priority, model, gate_1_model, effort, capital_path, acceptance_criteria` |
| **gap** | **`sprint`, `title`** |

The gap is exactly two fields, and §8 already dispositions one of them: `title` was withheld only
until this pull landed, and **it has now landed**, so declaring it is safe and is the operator's
call. Declare `title` and `sprint`, and core's coverage equals the consumer's — at which point the
Check 5 override's delta 2 has no field-coverage argument left either, and retiring the consumer
generator becomes a mechanical removal rather than a capability loss.

**Note the interaction with the override's removal condition (§2.1 work).** Retirement is still not
automatic: conjunct (i) — core invoking a *project-supplied* validator script — remains UNMET, so
the override itself stands regardless of what happens to the generator. Retiring the generator and
retiring the override are two decisions, not one.

## 8. Known-open, deliberately out of scope

- **`title` stays WITHHELD from your declaration until this pull lands.** It is derived and it was
  the field the v0.237.1 defect corrupted; declaring it before the fix is installed is the one way
  to trip it. After the pull it is safe, and declaring it is your call.
- **The `sprint-168` provenance finding at `5d2a12156`** still wants an operator disposition.
- **`W7` / `Check 11b`** remains a live dangling check pointer.
