# graph pull → ai-dlc v0.226.0 — operator handoff

**Point a fresh Claude Code session at this file in `/Users/n8/git/graph`.** It drives the pull to
done, and it is small: **one judgement, seven rows, no migration.**

This is `~/.claude/plans/read-these-five-documents-zesty-clarke.md` **§6c step 10**. That step exists
because 9b's rows 1–3 need an ai-dlc release *merged AND pulled*, and no row of that ledger did the
pulling. **When this lands, `docs/reviews/graph-suite-performance-operator-handoff.md` rows 1, 2, 3
and 6 become runnable** — that is what this pull is for.

Precedent: `docs/reviews/graph-pull-0.224.0-operator-handoff.md` (10 rows, 49 renames) and
`docs/reviews/graph-pull-0.213.0-operator-handoff.md` (45 judgements). **Do not reuse either** — both
are banked and both pull to shas that are now two and thirteen releases behind.

---

## 0. How to use this file, and WHICH REPO YOU ARE IN

1. Read §1–§5 in full. They are short and every line is load-bearing.
2. Read the **Progress Ledger** (§5) to find the next unticked row.
3. Read that row's section in §6, execute it, tick the ledger **with a sha or a count** as the last
   act. A fresh session's only way to know where it is.
4. When you reach a **`⏹ FRESH GRAPH SESSION`**, stop. The operator opens a new session **in
   `graph`**, pointed back at this file, and it picks up the next unticked row.

## EVERY ROW RUNS IN `graph`. THERE IS ONE SESSION AT A TIME.

- **All seven rows in §5 run in a session whose working directory is `/Users/n8/git/graph`.** Every
  command, every edit, the `apply`, the push. No row runs in ai-dlc.
- **This file lives in the ai-dlc repo and is read by absolute path.** That is the only ai-dlc
  involvement in the normal path.
- **`⏹ FRESH GRAPH SESSION` is context hygiene, not a repo switch.** Same repo, same file, next row.

**When an ai-dlc session IS needed — CONDITIONAL, not scheduled.** One trigger only:

> **A tally deviates from its stated expectation, or a stop condition fires.**

Then, and only then, open a session in `/Users/n8/git/ai-dlc` with the deviation. If every tally
matches, **you never open one**. A core defect found during this pull is fixed in ai-dlc and
re-delivered — **never patched in graph**.

**Fidelity tags.** **[M]** = measured on 2026-07-31 during the full rehearsal described in §4, with a
control in the same invocation. **[R]** = reported, not independently verified — treat as a
hypothesis. Everything numeric in this file is **[M]** unless tagged otherwise.

---

## 1. State at handoff

| | |
|---|---|
| **Distribution target** | `cedfa3b`, VERSION **0.226.0**. **PIN THIS SHA.** |
| **Consumer** | `graph` at `ff444f656` (`main`, and `origin/main` agrees), stamped **0.224.0 @ 1f5e6cc** |
| **Span** | `1f5e6cc → cedfa3b` — **2 releases**, 0.225.0 and 0.226.0 |
| **Base for every classifier** | `1f5e6cc` (the stamp), NOT a tag and NOT `ff444f656` |
| **Judgement load** | **1** — a six-line semantic merge into `extensions/README.md` (row 4). Zero adjudications, zero renames, zero `conforms_to` edits |
| **Gates that WEDGE the push if skipped** | **none.** The layer validator is GREEN before and after this pull; see §4.3 |
| Plan that produced this span | `~/.claude/plans/read-these-five-documents-zesty-clarke.md` §6c steps 8 (v0.225.0) and 9a (v0.226.0) |

The two releases, derived from `git log` rather than from any sentence in this file (control: a bogus
`feat(v9.` filter returns **0** over the same log): **0.225.0, 0.226.0**.

**What they carry, and it is why this pull matters more than its size suggests:**

- **v0.225.0** — `anchor_form` (the remedy string now matches the terminator the heading carries) and
  `LC-R2`/`W7`, the dangling-check-citation clause. `contract_version` 9 → **10**.
- **v0.226.0** — **the consumer's own pre-push gains the fixture pool, the per-fixture verdict files,
  the completeness assertion and a WORKING empty-suite guard.** Until now graph's suite ran serial,
  kept no verdicts, and **returned 0 when it ran nothing**. That last one is not a speed change.

**graph is NOT frozen for this program.** Re-derive `ff444f656` before you start; if graph has moved,
row 1 tells you how to check in one command whether the move touched the layer.

---

## 2. Locked decisions — do not re-litigate

| Decision | Consequence for you |
|---|---|
| **1. The `HARD-UNREGISTERED-CORE-DRIFT` blocker on `extensions/README.md` is EXPECTED, and BOTH remedies its own message names are WRONG here.** | It is the 19 crosswalk rows the 0.224.0 migration wrote, in the file core designates as the crosswalk home. Reverting deletes them and turns `E16` red; refiling them as an `overrides/` entry puts them where the validator does not read. **Do neither.** `apply` protects the file by itself — §4.1. |
| **2. The one judgement is row 4's semantic merge**, and it is six lines. | `apply` emits `WORKLIST semantic-merge` + `DECISION drift` on `extensions/README.md` and writes nothing to it. You hand-insert core's new `LC-R2` bullet and leave the crosswalk rows alone. |
| **3. `0 error(s), 2 warning(s)` after the pull is the PASS condition, not a regression.** | `W6` (all 50 entries declare `conforms_to: 9` against a contract now at 10) and `W7` (`Check 11b`). Both are by design; plan D-6c9.1 predicted both and the rehearsal reproduced both. **Do not clear them in this pull** — see §4.4. |
| **4. A core defect is fixed in ai-dlc, never in graph.** | Stop and escalate. The ONLY reason to open an ai-dlc session. |
| **5. Merge is the operator's.** | `CLAUDE.md` Deployment Rule (b). Push → PR → squash merge; graph's landings are single-parent squash merges carrying a `(#NNN)`. **A branch that is only committed is not delivered.** |

---

## 3. Non-negotiable discipline

**A zero is not a finding.** Every absence-shaped claim carries a control in the same invocation that
returns non-zero — **and the control must be able to match the CONSTRUCT you are calling absent, not
merely some construct.**

**Guard every mechanical edit with `cmp -s`.** A substitution that matched nothing is
indistinguishable from one that succeeded.

**Never read `$?` after a pipe.** It is the pipe's last stage. Redirect to a file, then check.

**`printf '%s' "$VAR" | grep -q` inverts under `pipefail`.** Read the value as a here-string:
`grep -q … <<<"$VAR"`.

**Unbraced `$ref:path` in zsh.** `:c`/`:t` are history modifiers and eat the next character. Always
`"${r}:core/…"`.

**A widened exemption is not a fix.** If a gate reports a finding, the remedy is the finding's
subject — never the gate's scope.

**Report tallies verbatim at a boundary.** Not "as expected" — the number, and the stop condition it
was measured against.

---

## 4. What the REHEARSAL found — read this before row 1

**The entire sequence in §6 was executed end-to-end on 2026-07-31, from an ai-dlc session, on a
`git clone --local` of graph at `ff444f656`. graph itself was never written to** — not the tree, not
a branch, not a worktree. The rehearsal ran the real `apply.sh`, the real semantic merge and graph's
own `.githooks/pre-push`, and it finished **`PREPUSH_RC=0`, all gates green, 108 fixtures ok, 0 FAIL,
43.5s wall**.

**Six things came back differently from what the plan predicted.** Each is a trap in the sense that it
looks like success, or like an honest absence.

### 4.1 — TRAP: there IS a hard blocker, it is NOT in the plan, and its own remedy text is wrong

`hard-blockers.sh` returns **1** row:

```
HARD-UNREGISTERED-CORE-DRIFT     skills/ai-dlc/extensions/README.md
```

`unregistered-drift.sh` gives the detail: *"core file edited IN PLACE (27 lines vs 1f5e6cc) with no
overrides/ entry … this text is deleted on the next pull. Refile the delta as an overrides/ entry
with base_sha 1f5e6cc, or revert the file."*

**The 27 lines are the 19 crosswalk rows the 0.224.0 migration wrote, plus its authoring-constraints
paragraph.** Measured, with controls in the same run: of the **63** rows `unregistered-drift.sh`
emits, **59 are `CORE-OK`** and 3 are `CORE-TEMPLATE-SUBSTITUTED`; this is the only `HARD-` row. The
same diff against `overrides/README.md` returns **0** lines, so the instrument reads a clean core file
as clean.

**And the drift is NEW, created by our own migration following core's own instruction.** graph's
`extensions/README.md` at `9b5d408a3` (pre-migration) is **byte-identical** to core's copy at
`04cea81` — 0 diff lines. At `ff444f656` it differs by **27**. Core ships the table as a
three-pipe-line skeleton at every ref in the span (control: 3 pipe lines at `04cea81`, `1f5e6cc` and
`cedfa3b`, and **0** `Check 24`-style data rows at any of them); graph's is now 22.

**Both named remedies are wrong for this file, and that is a core defect, not your problem to solve:**

- **Revert** deletes the 19 rows. `E16` (`LC-N6`, ERROR) then fires on every retired id and the
  pre-push wedges — the exact condition the 0.224.0 migration cleared.
- **Refile as an `overrides/` entry** puts the rows where nothing reads them.
  `validate-layer-entries.sh` reads the table from exactly one path, hard-wired:
  `CROSSWALK_MD="$EXT_DIR/README.md"` (control: a bogus token over the same file returns 0 hits).

**What actually happens is benign, and it is why this does not block you:** `apply.sh` classifies the
file `WORKLIST semantic-merge` and `DECISION drift` and **writes nothing to it** — md5 byte-identical
before and after, all 19 rows intact [M]. Row 4 then merges core's six new lines in by hand.

**Filed for ai-dlc, out of scope here:** core designates `extensions/README.md` as both an
upstream-owned file that `apply` overwrites and the mandated home for consumer-authored crosswalk
rows an ERROR clause requires. Every future pull will raise this same blocker with the same two wrong
remedies.

### 4.2 — TRAP: the null-span control does NOT discriminate on this span. Use the wide span.

`layer-drift.sh` over `1f5e6cc → cedfa3b` returns **57 rows, exit 0, 0 stderr**, and **the null-span
control returns the identical table** — because this span moves no file any entry hooks. A control
that reproduces the measurement proves nothing.

**The control that works is the WIDE span** `04cea81 → cedfa3b`, which returns **3
`HARD-LAYER-ADJUDICATION-MISSING` + 3 `EXTENSION-HOOK-DRIFT`** in the same invocation shape. That is
what establishes the classifier is live and the zero is a reading rather than a vacuum.

**Zero adjudications and zero hook-drift is CORRECT here**, and the reason is checkable in one
command: of the **19** files core changed in the span, only **three** are under
`core/skills/ai-dlc/` — `core-manifest.md`, `extensions/README.md`, `layer-contract.yaml` — and
**none** is under `core/skills/ai-dlc/steps/`, where every override and every hooked extension target
lives.

### 4.3 — This pull does NOT turn the pre-push red, and that is a first for this program

The 0.224.0 pull installed a validator that went red on 103 errors on first contact. This one does
not: **exit 0 before, exit 0 after.** The layer readings, all [M]:

| | value |
|---|---|
| graph's installed 0.224.0 validator, pre-pull | exit **0**, `0 error(s), 0 warning(s)`, `contract_version=9 entries=50 at_current=50 behind=0 undeclared=0`, `unclaimed=none` |
| the engine's 0.226.0 validator against graph, pre-pull | exit **0**, `0 error(s), 1 warning(s)`, **`unclaimed=W7`** |
| graph's newly-installed validator, post-pull | exit **0**, `0 error(s), 2 warning(s)`, `contract_version=10 entries=50 at_current=0 behind=50 undeclared=0`, **`unclaimed=none`** |

**`unclaimed=` is again the one cheap reading that proves the pull landed the validator**, exactly as
in the 0.224.0 brief §4.11 — it reads **`W7`** before (a finding the incoming validator emits that
graph's installed v9 contract claims from no clause) and **`none`** after. One command:

```
bash scripts/ai-dlc/validate-layer-entries.sh . | grep LAYER_MEASURED
```

### 4.4 — The two post-pull warnings are BY DESIGN. Do not clear them in this pull.

- **`W6`** — *"50 of 50 layer entries declare a conforms_to below contract_version 10 … migration
  worklist: LC-R2"*. One line per run. Clearing it means re-reading each of the 50 entries against
  the v10 contract and advancing its receipt — **a judgement per entry, not a transcription**, and it
  is a separate piece of work from this pull.
- **`W7`** — `Check 11b` in `extensions/steps-domain/deploy-validate-domain.md`, the one genuine
  dangling check citation that survives a complete migration. **That is the v0.225.0 finding
  working**, not a defect introduced here.

Plan D-6c9.1 predicted both. The rehearsal reproduced both, verbatim.

### 4.5 — The drivable fixture count goes 106 → **108**, not the 107 the plan states

Two fixtures arrive, not one: `tests/fixtures/consumer-suite-pool/` (v0.226.0) **and**
`tests/fixtures/layer-reference-resolution/` (v0.225.0). Post-pull the drivability step reads
`fixture directories : 118 / driven (run.sh) : 108 / declared undrivable: 10 / undeclared: 0`. **A
session expecting 106 or 107 should read 108 as delivery, not drift.** Plan §6c-10 item 4 says 107
and is wrong by one.

### 4.6 — v0.226.0 changes what your pre-push PRINTS, and one change is a red where there was green

- The suite step's label now carries its pool width: **`── fixture suite (16-way)`**.
- Verdicts still render in list order; **the work no longer runs in that order**.
- **A `tests/fixtures/` that is empty or has no drivable fixture now FAILS** where it used to pass.
  That is the point of the release.

**The guard is live in the file you are receiving, and it was proven in isolation** because the
obvious whole-tree probe is entangled — see §4.7. The delivered form yields a bare `0` on an empty
list and **fires**; on a two-line list (control) it yields `2` and proceeds. The form it replaces
yielded the two-line string `0\n0` and **did not fire in either case**.

### 4.7 — A probe that LOOKS decisive and is not: do not repeat it

Moving `tests/fixtures/` aside and running the hook to see the empty-suite guard fire returns
`PREPUSH_RC=1` — **but it never reaches the fixture step.** It dies earlier at
`--strays: FAIL (15 out-of-place party-mode block(s))`, because the fixtures carry party-mode
envelopes whose declared home moved with them. Two failures, and the one you were testing did not
run. Recorded because the exit code alone reads exactly like a successful control.

---

## 5. Progress Ledger

**The next unticked row is the next thing to do. Do them in order.** Tick as the last act of each
row, with a sha or the count you measured. `—` = not started.

| # | Row | Repo | Status |
|---|---|---|---|
| 1 | Pre-flight: clean tree, pin the engine, confirm graph has not moved under this file | graph | — |
| 2 | Classify only. Report all six tallies. **Write nothing.** | graph | — |
| 3 | `apply` on ONE branch | graph | — |
| 4 | The semantic merge — six lines into `extensions/README.md`. **The only judgement.** | graph | — |
| 5 | Post-apply verification **+ advance the machinery stamp** | graph | — |
| 6 | Full pre-push, commit, push, PR, merge | graph | — |
| 7 | Report back: the readings plan §6c-10 and the 9b handoff need | graph | — |

### Out of scope for this pull — surface, do not fix

- **`W6`'s 50-entry v10 re-read.** A judgement per entry. Not this pull.
- **`W7` / `Check 11b`.** The v0.225.0 finding working as designed.
- **The 6 report-only override rows** (2 `OVERRIDE-DOUBLE-SHADOW`, 2
  `OVERRIDE-DELEGATES-INTO-SHADOW`, 2 `OVERRIDE-ASSERTS-SHADOW-SURVIVES`) and the 1
  `EXTENSION-RESTATES-CORE`. All present identically in the null span, so none is this span's work.
  Dispositioned in the 0.213.0 pull.
- **The `extensions/README.md` core-ownership defect** (§4.1) — ai-dlc's to fix.
- **`self-update-gate.sh` is not at `scripts/ai-dlc/`** — still true, still ai-dlc's. Row 5 gives the
  path that works.

---

## 6. Rows

### Row 1 — pre-flight. In `graph`. Write nothing.

```
cd /Users/n8/git/graph
git rev-parse --abbrev-ref HEAD; git rev-parse HEAD
git status --porcelain | wc -l
cat .claude/.ai-dlc-version
ls -l .git/hooks/pre-push
```

**EXPECT:** `main`; HEAD `ff444f656` **or later**; a working tree whose only entries are under
`_bmad-output/` (4 runtime files at rehearsal time); stamp `version: 0.224.0` / `commit: 1f5e6cc`;
the pre-push shim present at **314 bytes**.

**If HEAD has moved past `ff444f656`,** check whether the move touched the layer:

```
git diff --name-only ff444f656 HEAD -- .claude/skills/ai-dlc/ | wc -l
git diff --name-only ff444f656 HEAD | wc -l          # CONTROL: must be non-zero if HEAD moved
```

**Zero on the first line means every tally in this file still holds.** Non-zero: report it and
escalate before row 2.

**Pin the engine.** An ai-dlc worktree at the target sha, so nothing in this pull depends on that
repo's working state:

```
git -C /Users/n8/git/ai-dlc worktree add --detach /tmp/pull-engine-0226 cedfa3b
cat /tmp/pull-engine-0226/VERSION      # EXPECT 0.226.0
```

**STOP CONDITION:** `VERSION` is anything but `0.226.0`. Everything below is pinned to `cedfa3b`.

---

### Row 2 — classify only. Report all six tallies. **Write nothing.** In `graph`.

Argument order differs between these scripts and getting it wrong produces a clean-looking run:

```
# layer-drift.sh        <dist> <base> <theirs>   <consumer>
# ledger-reverify.sh    <dist> <base> <consumer> <theirs>     <-- 3rd and 4th SWAPPED
# hard-blockers.sh      <dist> <base> <consumer> <theirs>
# unregistered-drift.sh <dist> <base> <consumer> [theirs]
```

```
E=/tmp/pull-engine-0226; B=1f5e6cc; T=cedfa3b; G=/Users/n8/git/graph
cd $G

# (1) the classifier
bash $E/core/skills/ai-dlc-update/reconcile/layer-drift.sh $E $B $T $G > /tmp/drift.tsv
echo "exit=$?  rows=$(wc -l < /tmp/drift.tsv)"
cut -f1 /tmp/drift.tsv | sort | uniq -c | sort -rn

# (1) CONTROL — the WIDE span, because the null span does NOT discriminate here (§4.2)
bash $E/core/skills/ai-dlc-update/reconcile/layer-drift.sh $E 04cea81 $T $G | cut -f1 | sort | uniq -c | sort -rn

# (2) the blockers
bash $E/core/skills/ai-dlc-update/reconcile/hard-blockers.sh $E $B $G $T | grep '^HARD-'

# (3) the in-place core drift behind that blocker
bash $E/core/skills/ai-dlc-update/reconcile/unregistered-drift.sh $E $B $G $T > /tmp/unreg.tsv
cut -f1 /tmp/unreg.tsv | sort | uniq -c | sort -rn

# (4) the ledger
bash $E/core/skills/ai-dlc-update/reconcile/ledger-reverify.sh $E $B $G $T > /tmp/ledger.tsv
cut -f1 /tmp/ledger.tsv | sort | uniq -c | sort -rn

# (5) graph's INSTALLED validator — the pre-pull baseline
bash scripts/ai-dlc/validate-layer-entries.sh . | tail -2

# (6) the ENGINE's validator against graph — what the pull will install
bash $E/core/scripts/validate-layer-entries.sh $G | grep -E '^validate-layer-entries:|^LAYER_MEASURED' | cut -c1-160
```

**EXPECTED TALLIES [M]:**

| probe | expected |
|---|---|
| (1) `layer-drift.sh` | **57 rows**, exit 0, 0 stderr. `EXTENSION-OK` 38, `OVERRIDE-OK` 12, `OVERRIDE-DOUBLE-SHADOW` 2, `OVERRIDE-DELEGATES-INTO-SHADOW` 2, `OVERRIDE-ASSERTS-SHADOW-SURVIVES` 2, `EXTENSION-RESTATES-CORE` 1. **`EXTENSION-HOOK-DRIFT` 0 and `HARD-LAYER-ADJUDICATION-MISSING` 0** |
| (1) control, wide span | **3** `HARD-LAYER-ADJUDICATION-MISSING`, **3** `EXTENSION-HOOK-DRIFT`, 35 `EXTENSION-OK` — this is what makes the zeros above a reading |
| (2) `hard-blockers.sh` | exactly **1**: `HARD-UNREGISTERED-CORE-DRIFT  skills/ai-dlc/extensions/README.md`. **Expected — §4.1. Do not act on its remedy text.** |
| (3) `unregistered-drift.sh` | **63 rows**: `CORE-OK` 59, `CORE-TEMPLATE-SUBSTITUTED` 3, `HARD-UNREGISTERED-CORE-DRIFT` **1**. Detail on the one: *"core file edited IN PLACE (27 lines vs 1f5e6cc)"* |
| (4) `ledger-reverify.sh` | report the histogram verbatim; it is residue, not this pull's work |
| (5) graph's INSTALLED validator | exit **0**, `0 error(s), 0 warning(s)`, `contract_version=9 … at_current=50`, `unclaimed=none` |
| (6) the ENGINE's validator | exit **0**, `0 error(s), 1 warning(s)`, **`unclaimed=W7`** — the one reading that flips to `none` after the pull |

**STOP CONDITIONS.** Any status in (1) outside that table. **Any `HARD-` row in (2) other than the
single `extensions/README.md` one** — a second blocker is not covered by this brief. (5) reading
anything but `0 error(s), 0 warning(s)`: graph's tree moved since the rehearsal.

**IMPOSSIBLE ZEROS, stated rather than counted as clean:** `EXTENSION-ANCHOR-DRIFT` and
`EXTENSION-ANCHOR-MISSING` are **0**, against a **non-empty** subject set — 10 entries declare
`extends:` (control: 39 declare `kind:`). Report it; plan §6c-7 scores it.

---

### Row 3 — `apply` on ONE branch. In `graph`.

```
git checkout -b chore/ai-dlc-update-0.226.0
bash $E/core/skills/ai-dlc-update/reconcile/apply.sh $E $B $G $T
```

**EXPECT exit 0**, and:

| | |
|---|---|
| `RESOLVED` | **13** |
| `WORKLIST` | **1** — `semantic-merge  skills/ai-dlc/extensions/README.md` |
| `DECISION` | **1** — `drift  skills/ai-dlc/extensions/README.md`, the same file |
| final lines | `RESOLVED relabel ext-check collisions labelled`, `RESOLVED restamp 1f5e6cc -> cedfa3b`, `RESOLVED consistent  the tree matches cedfa3b; fixture suite re-enabled` |
| changed paths | **9** — 7 modified + 2 untracked (`tests/fixtures/consumer-suite-pool/`, `tests/fixtures/layer-reference-resolution/`) |
| stderr | **0 bytes** |

**The `DECISION` row is EXPECTED in this pull and is not a stop condition** — that is a deviation from
the 0.224.0 brief, which listed any `DECISION` as one. It is §4.1's blocker arriving at apply-time,
and `apply` handles it by refusing to touch the file.

**VERIFY it refused, rather than assuming it:**

```
grep -c '^| .Check 19b' .claude/skills/ai-dlc/extensions/README.md    # EXPECT 1
grep -c '^|' .claude/skills/ai-dlc/extensions/README.md               # EXPECT 22 -- CONTROL
```

**STOP CONDITION:** either count lower than that. If the crosswalk rows are gone, `apply` overwrote
the file — stop and escalate to ai-dlc; do not re-add them by hand.

---

### Row 4 — the semantic merge. In `graph`. **The only judgement in this pull.**

`apply` left `extensions/README.md` untouched, so core's own change to that file in this span — **six
lines, one bullet** — has not landed. It is the `LC-R2` clause v0.225.0 added, and it belongs in the
clause list between `LC-R1` and `LC-C1`.

**Take the block from the engine rather than transcribing it:**

```
git -C /Users/n8/git/ai-dlc show cedfa3b:core/skills/ai-dlc/extensions/README.md \
  | sed -n '/^- \*\*\[LC-R2\]\*\*/,/clears this warning as well/p' > /tmp/lcr2.block
wc -l < /tmp/lcr2.block          # EXPECT 6
```

Insert those six lines **immediately before the `- **[LC-C1]** ERROR` bullet**, `cmp -s`-guarded so a
substitution that matched nothing reports itself instead of passing.

**VERIFY — the whole point is that the merge takes core's line and keeps yours:**

```
diff <(git -C /Users/n8/git/ai-dlc show cedfa3b:core/skills/ai-dlc/extensions/README.md) \
     .claude/skills/ai-dlc/extensions/README.md > /tmp/readme.diff
echo "consumer-only lines: $(grep -c '^>' /tmp/readme.diff)"   # EXPECT 27  (your crosswalk rows)
echo "missing from consumer: $(grep -c '^<' /tmp/readme.diff)" # EXPECT 0   (core's text all present)
```

**CONTROL, and it is required** — the same comparison **before** your edit must report **6** missing.
A `0 / 0` reading with no before-value is a diff that ran, not a merge that landed.

**STOP CONDITION:** `missing` non-zero after the edit, or `consumer-only` anything but 27. Either
means core changed more of that file than this brief accounts for.

---

⏹ **FRESH GRAPH SESSION** is *not* needed here — rows 3–5 are one short arc. Carry on.

---

### Row 5 — post-apply verification + the stamp half `apply` deliberately does not do. In `graph`.

```
cat .claude/.ai-dlc-version
grep -m1 '^contract_version:' .claude/skills/ai-dlc/layer-contract.yaml
```

**EXPECT** `version: 0.226.0` / `commit: cedfa3b`, `contract_version: 10` — **and
`skill_version: 0.224.0` / `skill_commit: 1f5e6cc`, which is CORRECT at this point.** `apply`
preserves that pair by design.

```
bash .claude/skills/ai-dlc-update/reconcile/self-update-gate.sh $E $B $T $G
```

**EXPECT `SELF-UPDATE-OK`** — *"the incoming version passes against this consumer's existing tree
(current version rc=0), so installing it cannot block the push."* **This differs from the 0.224.0
pull, which returned `SELF-UPDATE-DEFER`**, and the difference is real: that pull's incoming
validator went red on the existing tree and this one does not.

**Note the path.** `scripts/ai-dlc/self-update-gate.sh` does **not exist** in graph (exit 127). The
script is at `.claude/skills/ai-dlc-update/reconcile/self-update-gate.sh`. Still an ai-dlc handoff
defect, still out of scope.

Now advance `skill_version` / `skill_commit` to **0.226.0** / **cedfa3b**, preserving `installed_at`
and `upstream`. **Both pairs must read 0.226.0 before row 6.**

**The flip — graph's installed validators must now be byte-identical to the distribution's:**

```
for f in validate-layer-entries.sh validate-gate-manifest.sh validate-fixture-drivability.sh; do
  cmp -s scripts/ai-dlc/$f $E/core/scripts/$f && echo "IDENTICAL $f" || echo "FORKED $f"
done
cmp -s CLAUDE.md $E/CLAUDE.md && echo "control FAILED" || echo "control ok (CLAUDE.md forks)"
```

**EXPECT three `IDENTICAL` and `control ok`.** Without the control, `cmp -s` answering yes to
everything looks the same.

**And the 9a delivery, which is what plan step 10 exists to land:**

```
grep -c 'AI_DLC_FIXTURE_JOBS' .githooks/pre-push     # EXPECT 2   (was 0)
grep -c 'no fixtures found'   .githooks/pre-push     # EXPECT 1   (was 0)
wc -l < .githooks/pre-push                           # EXPECT 294 (was 208)
```

**Then the layer reading, and it is GREEN:**

```
bash scripts/ai-dlc/validate-layer-entries.sh . | tail -3
```

**EXPECT exit 0, `0 error(s), 2 warning(s)`** — `W6` and `W7`, both by design (§4.4) — footer
`LAYER_CONFORMANCE v1 contract_version=10 entries=50 at_current=0 behind=50 undeclared=0 errors=0
warnings=2`, and **`unclaimed=none`** in the `LAYER_MEASURED` line, flipped from `W7` at row 2 probe
(6). **If `unclaimed` still reads `W7`, the pull did not land the validator.**

---

### Row 6 — full pre-push, commit, push, PR, merge. In `graph`.

```
bash .githooks/pre-push origin "$(git remote get-url origin)" < /dev/null > /tmp/prepush.out 2>&1
echo "PREPUSH_RC=$?"
```

**EXPECT [M]:**

| | |
|---|---|
| result | **`pre-push: all gates green`, rc 0** |
| fixture suite header | **`── fixture suite (16-way)`** — the pool width, new in this release |
| drivability | `fixture directories : 118 / driven (run.sh) : 108 / declared undrivable: 10 / undeclared: 0` |
| suite | **108 `ok`, 0 FAIL** — including `consumer-suite-pool`, `layer-reference-resolution` and `layer-conforms-to` |
| wall clock | **43.5s** on the rehearsal box (`user 99.95 / sys 213.70`). **Re-derive on yours; do not inherit it** |

**One artefact of running the hook by hand:** with `< /dev/null` the trunk-push arm prints
*"NO REF LINES ON STDIN — nothing was judged"* and PASSes. That is correct — git supplies the ref
protocol on stdin during a real push, and the arm judges it then.

Then commit, push, PR:

```
git add -A && git commit -m "chore(ai-dlc): pull v0.226.0 (fixture pool + empty-suite guard, LC-R2)"
git push -u origin chore/ai-dlc-update-0.226.0
gh pr create --fill
git ls-remote --heads origin chore/ai-dlc-update-0.226.0    # verify the push by reading the remote
```

**EXPECTED DIFF SURFACE [M]: 12 files, +1030 / −15.**

```
.claude/.ai-dlc-version                                +4/-4
.claude/skills/ai-dlc-update/reconcile/setup-sites.md  +2/-0
.claude/skills/ai-dlc/core-manifest.md                 +2/-0
.claude/skills/ai-dlc/extensions/README.md             +6/-0     <- row 4, and ONLY row 4
.claude/skills/ai-dlc/layer-contract.yaml              +24/-1
.githooks/pre-push                                     +93/-7    <- the 9a delivery
scripts/ai-dlc/validate-layer-entries.sh               +86/-2
tests/fixtures/consumer-suite-pool/run.sh              +357/-0
tests/fixtures/layer-conforms-to/run.sh                +8/-1
tests/fixtures/layer-reference-resolution/README.md    +64/-0
tests/fixtures/layer-reference-resolution/run.sh       +225/-0
tests/fixtures/layer-reference-resolution/seed.sh      +159/-0
```

**STOP CONDITION:** `extensions/README.md` showing anything but `+6/-0`. Any deletion there is a
crosswalk row you lost.

**Leave the 4 pre-existing `_bmad-output/` runtime files UNCOMMITTED** — they are operational state,
not this branch's work, and including them makes the count 16.

**Merge is the operator's.** Squash-merge after approval (`CLAUDE.md` Deployment Rule (b)).

**No deploy is owed** [M]: every path above is under `.claude/`, `tests/fixtures/`, `scripts/ai-dlc/`
or `.githooks/`. Confirm it rather than assuming — `server/`, `web/`, `rebalancer/`,
`graph-node-src/`, `subgraph/` and `infra/` must each read 0 against a control of 12 total, or
Deployment Rule (c) fires.

---

### Row 7 — report back. In `graph`, one command each.

```
cat .claude/.ai-dlc-version                                     # both pairs 0.226.0 / cedfa3b
bash scripts/ai-dlc/validate-layer-entries.sh . | tail -2
grep -c 'AI_DLC_FIXTURE_JOBS' .githooks/pre-push                # the 9b-PART-2 unblock reading
c=0; for d in tests/fixtures/*/; do [ -f "$d/run.sh" ] && c=$((c+1)); done; echo "drivable=$c"
git rev-parse origin/main
```

Report those five verbatim. They discharge plan §6c-10's DONE-CHECK (stamp `0.226.0`, contract
present, `AI_DLC_FIXTURE_JOBS` non-zero) and §6c-9's 9b DONE-CHECK in the same breath.

**THEN SAY, IN THE REPLY, THAT 9b-PART-2 IS NOW RUNNABLE**, and name its file:
`/Users/n8/git/ai-dlc/docs/reviews/graph-suite-performance-operator-handoff.md`, rows **1, 2, 3 and
6**. Row 1 verifies the pulled hook; row 2 re-derives the pool size for graph's box rather than
inheriting **16**; row 3 re-profiles as a schedule.

**The before-figures those rows compare against are banked at `eec5655` and cannot be retaken** — the
serial baseline was **188.0s wall, 10.2x available from a pool, 1.47 system/user, 4.3% graph-owned**,
measured before the pool existed. **The rehearsal's post-pool 43.5s is a different box; treat it as a
sanity bound, not as your before/after.**

---

## 7. Known-open, deliberately out of scope

- **`extensions/README.md` is both upstream-owned and the mandated crosswalk home** (§4.1). Filed for
  ai-dlc. Every future pull raises the same blocker with the same two wrong remedies.
- **`self-update-gate.sh` path** — the 0.224.0 brief recorded it; still unfixed.
- **`W6`'s 50-entry re-read against contract v10**, and **`W7` / `Check 11b`**.
- **`suite-content-key.sh` is deliberately not shipped** to consumers (plan D-6c9.2). The skip's
  soundness rests on a superset defined over the distribution's tree, and nothing has measured
  whether it covers a consumer's. Scheduled, not dropped.
