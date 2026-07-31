# graph pull → ai-dlc v0.227.0 + v0.228.0 — operator handoff

**Point a fresh Claude Code session at this file in `/Users/n8/git/graph`.** It drives the pull
to done: **seven rows, one judgement, and a migration that is measured rather than open.**

This is `~/.claude/plans/read-these-five-documents-zesty-clarke.md` **§6c steps 13 and 14, in one
branch** — the pull that carries the crosswalk table's new home, and the migration that moves
graph's rows into it. §4.8 records why they are one branch and not two; that is a decision, not
a preference, and it was measured on the rehearsal.

Precedent: `docs/reviews/graph-pull-0.226.0-operator-handoff.md` (7 rows) and
`graph-pull-0.224.0-operator-handoff.md` (10 rows, 49 renames). **Do not reuse either** — both
pull to shas that are now behind.

---

## 0. How to use this file, and WHICH REPO YOU ARE IN

1. Read §1–§5 in full. They are short and every line is load-bearing.
2. Read the **Progress Ledger** (§5) to find the next unticked row.
3. Read that row's section in §6, execute it, tick the ledger **with a sha or a count** as the
   last act. A fresh session's only way to know where it is.
4. When you reach a **`⏹ FRESH GRAPH SESSION`**, stop. The operator opens a new session **in
   `graph`**, pointed back at this file, and it picks up the next unticked row.

## EVERY ROW RUNS IN `graph`. THERE IS ONE SESSION AT A TIME.

- **All seven rows run in a session whose working directory is `/Users/n8/git/graph`.** Every
  command, every edit, the `apply`, the push. No row runs in ai-dlc.
- **This file lives in the ai-dlc repo and is read by absolute path.** That is the only ai-dlc
  involvement in the normal path.
- **`⏹ FRESH GRAPH SESSION` is context hygiene, not a repo switch.** Same repo, same file, next
  row.

**When an ai-dlc session IS needed — CONDITIONAL, not scheduled.** One trigger only:

> **A tally deviates from its stated expectation, or a stop condition fires.**

Then, and only then, open a session in `/Users/n8/git/ai-dlc` with the deviation. If every tally
matches, **you never open one**. A core defect found during this pull is fixed in ai-dlc and
re-delivered — **never patched in graph**.

**Fidelity tags.** **[M]** = measured on 2026-07-31 during the full rehearsal described in §4,
with a control in the same invocation. **[R]** = reported, not independently verified. Everything
numeric here is **[M]** unless tagged otherwise.

---

## 1. State at handoff

| | |
|---|---|
| **Distribution target** | `5879f70`, VERSION **0.228.0**. **PIN THIS SHA.** |
| **Consumer** | `graph` at `5f425e664` (`main`, and `origin/main` agrees), stamped **0.226.0 @ cedfa3b** |
| **Span** | `cedfa3b → 5879f70` — **2 releases**, 0.227.0 and 0.228.0 |
| **Base for every classifier** | `cedfa3b` (the stamp), NOT a tag and NOT `5f425e664` |
| **Judgement load** | **1** — row 4: move 20 crosswalk rows to the file this pull creates, and take core's `extensions/README.md` verbatim. Zero adjudications, zero renames, zero `conforms_to` edits |
| **Gates that WEDGE the push if skipped** | **none.** The layer validator is GREEN before and after; see §4.3 |
| Plan that produced this span | `~/.claude/plans/read-these-five-documents-zesty-clarke.md` §6c steps 11 (v0.227.0) and the v0.228.0 row above 13 |

The two releases, derived from `git log` rather than from any sentence in this file (control: a
bogus `feat(v9.` filter returns **0** over the same log): **0.227.0, 0.228.0**.

**What they carry, and the second one exists because the first one was incomplete:**

- **v0.227.0** — the catalog crosswalk table moves out of `extensions/README.md`, which is core's
  file, to the path `layer-contract.yaml` declares as `consumer_crosswalk_file:`. `LC-N6` was an
  ERROR whose only compliant output was an unregistered edit to upstream's tree, and graph's
  0.224.0 migration wrote nineteen rows there and earned a permanent
  `HARD-UNREGISTERED-CORE-DRIFT` for obeying it. `LC-N7`/`W8` reports rows still in the old
  location. `contract_version` 10 → **11**.
- **v0.228.0** — **the pull now creates that file.** v0.227.0 shipped the scaffold in
  `install.sh`, which no consumer ever runs again, so the declared path arrived empty for every
  existing tree: contract declaring it, template shipped, `W8` telling you to move rows into a
  file that did not exist, and nothing reporting the absence. `apply.sh` scaffolds it when absent
  and never touches it when present. `I69` closes the second half — four shipped sites, `W8`'s
  own remedy string among them, named the wrong file as the declaration's home.

**graph is NOT frozen for this program.** Re-derive `5f425e664` before you start; row 1 tells you
how to check in one command whether a move touched the layer.

---

## 2. Locked decisions — do not re-litigate

| Decision | Consequence for you |
|---|---|
| **1. The pull and the migration are ONE branch.** | §4.8 has the measurement. Moving the rows out is what makes the semantic merge a verbatim copy of core's file; done separately you hand-insert core's 20 new lines around 27 consumer lines and then delete those lines again in the next branch. |
| **2. The `HARD-UNREGISTERED-CORE-DRIFT` blocker on `extensions/README.md` is EXPECTED at row 2, and this branch is what ends it.** | It is the 19 crosswalk rows the 0.224.0 migration wrote plus their authoring-constraints paragraph. `apply` writes nothing to that file (§4.1). After row 4 the next pull's blocker count is **0** [M], with a control that reads non-zero on the pre-migration tree. |
| **3. Probe (6) of row 2 exits 1 with ONE ERROR, and that is expected.** | `E16` — the engine's v0.228.0 validator reading graph's still-installed **v10** contract, which predates `consumer_crosswalk_file:`. It clears the instant `apply` installs the v11 contract. **A pre-pull run of the incoming validator is not a verdict on your tree.** §4.2 |
| **4. `0 error(s), 2 warning(s)` after row 4 is the PASS condition.** | `W6` (all 50 entries declare `conforms_to` below 11) and `W7` (`Check 11b`). Both by design. **`W8` must be GONE** — a surviving `W8` means rows were copied rather than moved. §4.4 |
| **5. All 20 rows move, including `24`.** | Measured: `24` is not mechanically required and it is still graph's. §4.5 has both halves and the disposition. |
| **6. A core defect is fixed in ai-dlc, never in graph.** | Stop and escalate. The ONLY reason to open an ai-dlc session. |
| **7. Merge is the operator's.** | `CLAUDE.md` Deployment Rule (b). Push → PR → squash merge; graph's landings are single-parent squash merges carrying a `(#NNN)`. **A branch that is only committed is not delivered.** |

---

## 3. Non-negotiable discipline

**A zero is not a finding.** Every absence-shaped claim carries a control in the same invocation
that returns non-zero — **and the control must be able to match the CONSTRUCT you are calling
absent, not merely some construct.**

**Guard every mechanical edit with `cmp -s`.** A substitution that matched nothing is
indistinguishable from one that succeeded.

**Unbraced `$ref:path` in zsh eats the next character.** `:c` and `:t` are history modifiers, so
`$T:core/...` becomes `5879f70ore/...` and git reports the path absent. **Always `"${T}:core/…"`.**
This was hit live during the rehearsal, in a repo whose `CLAUDE.md` opens with it.

**Never read `$?` after a pipe.** It is the pipe's last stage. Redirect to a file, then check.

**`printf '%s' "$VAR" | grep -q` inverts under `pipefail`.** Read the value as a here-string.

**A widened exemption is not a fix.** If a gate reports a finding, the remedy is the finding's
subject — never the gate's scope.

**Report tallies verbatim at a boundary.** Not "as expected" — the number, and the stop condition
it was measured against.

---

## 4. What the REHEARSAL found — read this before row 1

**The entire sequence in §6 was executed end-to-end on 2026-07-31, from an ai-dlc session, on a
`git clone --local` of graph at `5f425e664`. graph itself was never written to** — not the tree,
not a branch, not a worktree. It ran the real `apply.sh`, the real migration and graph's own
`.githooks/pre-push`, finishing **`PREPUSH_RC=0`, all gates green, 109 fixtures ok, 0 FAIL, 41s
wall**.

### 4.1 — The blocker is still there at row 2, and this branch is what clears it

`hard-blockers.sh` returns exactly **1** row —
`HARD-UNREGISTERED-CORE-DRIFT  skills/ai-dlc/extensions/README.md` — with the detail *"core file
edited IN PLACE (27 lines vs cedfa3b)"*. Controls in the same run: of the **63** rows
`unregistered-drift.sh` emits, **59 are `CORE-OK`** and 3 are `CORE-TEMPLATE-SUBSTITUTED`.

`apply` writes nothing to that file — md5 byte-identical before and after, all 22 pipe rows
intact [M]. **After row 4 the next pull's `hard-blockers.sh` returns 0** [M], and
`unregistered-drift.sh` reads **61 `CORE-OK` + 3 template-substituted, zero `HARD-`**.

### 4.2 — TRAP: the incoming validator goes RED against your tree BEFORE the pull, and it is right to

Probe (6) of row 2 exits **1** with `1 error(s), 3 warning(s)`. The error is:

```
ERROR  E16  could not read 'consumer_crosswalk_file:' from .claude/skills/ai-dlc/layer-contract.yaml
```

That is the v0.228.0 validator reading graph's **v10** contract, which predates the declaration.
It is a true statement about a state that exists for the duration of the pull and no longer. The
same probe after `apply` reads **0 errors** [M]. **Do not treat it as a stop condition, and do
not edit the contract to satisfy it.**

### 4.3 — TRAP: the null-span control does NOT discriminate on this span. Use the wide span.

`layer-drift.sh` over `cedfa3b → 5879f70` returns **57 rows, exit 0, 0 stderr**, and the
**null-span control returns the identical table** — this span moves no file any entry hooks. A
control that reproduces the measurement proves nothing.

**The control that works is the WIDE span** `04cea81 → 5879f70`: **3
`HARD-LAYER-ADJUDICATION-MISSING` + 3 `EXTENSION-HOOK-DRIFT` + 35 `EXTENSION-OK`** in the same
invocation shape. Zero hook-drift is correct here and checkable in one command: of the files core
changed in the span, **none is under `core/skills/ai-dlc/steps/`**, where every override and every
hooked extension target lives.

### 4.4 — The two post-pull warnings are BY DESIGN; the third must disappear

- **`W6`** — *"50 of 50 layer entries declare a conforms_to below contract_version 11"*. One line
  per run. Clearing it is a judgement per entry and is not this pull.
- **`W7`** — `Check 11b` in `extensions/steps-domain/deploy-validate-domain.md`, the one genuine
  dangling citation that survives a complete migration. That is the v0.225.0 finding working.
- **`W8`** — present before row 4 naming **20** rows, **absent after** [M]. It is the whole
  point of the migration half.

### 4.5 — `24` IS graph's row, and it moves. Both halves were measured.

The plan asks whether graph's `24` row is real or core's inherited illustration. **Both, and the
disposition is unambiguous once the two readings are separated:**

- Its text is **byte-identical** to core's shipped example at `cedfa3b`, because core drew that
  example from graph's own situation. That is why §1 goal 3 of the plan read graph's table as
  having "exactly one data row".
- It is nonetheless **graph's**: `gate-validation-domain.md` defines `### 924. [ext:gate-validation-domain]
  Financial-display ground-truth live-verify` today, the same title the row carries, and graph's
  own history shows the id under its pre-migration number (control: the same probe for `19b`, an
  id graph plainly owns, returns 8).
- It is **not mechanically required**: dropping only that row from the old table and re-running
  the shipping validator produces **no `E16`** — because core defines a different `Check 24`, so a
  bare `24` still resolves to something. Control: the same run with the row present is also 0.

**Which is exactly why a human needs the row.** A gate log citing `24` while graph's entry owned
that number now resolves to core's adversarial-convergence check — the wrong one, silently. Move
it with the other nineteen and keep its note.

### 4.6 — The drivable fixture count goes 108 → **109**, not 110

One fixture arrives, not two: `tests/fixtures/layer-crosswalk-home/`. v0.228.0's other new
fixture, `crosswalk-home-declaration`, is **`.dist-only`** and correctly never installs. Post-pull
the drivability step reads `fixture directories : 119 / driven (run.sh) : 109 / declared
undrivable: 10 / undeclared: 0`. **A session expecting 108 should read 109 as delivery, not
drift.**

### 4.7 — `apply` gains a row you have not seen before, and it is the delivery

```
RESOLVED	crosswalk-scaffold	.claude/skills/ai-dlc/crosswalk.md
```

The file arrives **byte-identical to the template THEIRS ships** (1626 bytes) [M]. If that row is
absent and the file is not there, **stop** — that is v0.227.0's defect recurring and it is
ai-dlc's, not something to work around by creating the file by hand.

### 4.8 — Why ONE branch, measured rather than argued

The plan says steps 13 and 14 are separable, and they are: `W8` is a WARN, so a pull-only branch
is pushable. It is still the wrong split, and the rehearsal shows why in one number. **Core's
change to `extensions/README.md` in this span is 20 lines of new prose plus a fenced example, and
graph's copy carries 27 consumer-only lines in the same region.** Merged separately you insert
core's 20 around your 27, then delete all 27 in the next branch and re-verify. Merged together
the whole file becomes `git show "${THEIRS}:core/skills/ai-dlc/extensions/README.md"` verbatim —
a copy with a `cmp -s` control, no hand-editing, and one digest re-open instead of two.

---

## 5. Progress Ledger

**The next unticked row is the next thing to do. Do them in order.** Tick as the last act of each
row, with a sha or the count you measured. `—` = not started.

| # | Row | Repo | Status |
|---|---|---|---|
| 1 | Pre-flight: clean tree, pin the engine, confirm graph has not moved under this file | graph | — |
| 2 | Classify only. Report all six tallies. **Write nothing.** | graph | — |
| 3 | `apply` on ONE branch, and verify the scaffold arrived | graph | — |
| 4 | The migration + the semantic merge. **The only judgement.** | graph | — |
| 5 | Post-apply verification **+ advance the machinery stamp** | graph | — |
| 6 | Full pre-push, commit, push, PR, merge | graph | — |
| 7 | Report back: the readings plan §6c-13 and §6c-14 need | graph | — |

### Out of scope for this pull — surface, do not fix

- **`W6`'s 50-entry re-read against contract v11.** A judgement per entry. Not this pull.
- **`W7` / `Check 11b`.** The v0.225.0 finding working as designed.
- **The 6 report-only override rows** (2 `OVERRIDE-DOUBLE-SHADOW`, 2
  `OVERRIDE-DELEGATES-INTO-SHADOW`, 2 `OVERRIDE-ASSERTS-SHADOW-SURVIVES`) and the 1
  `EXTENSION-RESTATES-CORE`. All present identically in the null span, so none is this span's
  work. Dispositioned in the 0.213.0 pull.
- **`self-update-gate.sh` is not at `scripts/ai-dlc/`** — still true, still ai-dlc's. Row 5 gives
  the path that works.
- **The SIGPIPE driver bug in `scripts/tests/test-s168-retro-gates.sh`** (plan D-6c9.4). graph's
  file, graph's to fix, not this pull.

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

**EXPECT:** `main`; HEAD `5f425e664` **or later**; a working tree whose only entries are under
`_bmad-output/` (4 runtime files at rehearsal time); stamp `version: 0.226.0` / `commit: cedfa3b`;
the pre-push shim present at **314 bytes**.

**If HEAD has moved past `5f425e664`,** check whether the move touched the layer:

```
git diff --name-only 5f425e664 HEAD -- .claude/skills/ai-dlc/ | wc -l
git diff --name-only 5f425e664 HEAD | wc -l          # CONTROL: must be non-zero if HEAD moved
```

**Zero on the first line means every tally in this file still holds.** Non-zero: report it and
escalate before row 2.

**Pin the engine.** An ai-dlc worktree at the target sha, so nothing depends on that repo's
working state:

```
git -C /Users/n8/git/ai-dlc worktree add --detach /tmp/pull-engine-0228 5879f70
cat /tmp/pull-engine-0228/VERSION      # EXPECT 0.228.0
```

**STOP CONDITION:** `VERSION` is anything but `0.228.0`. Everything below is pinned to `5879f70`.

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
E=/tmp/pull-engine-0228; B=cedfa3b; T=5879f70; G=/Users/n8/git/graph
cd $G

# (1) the classifier
bash $E/core/skills/ai-dlc-update/reconcile/layer-drift.sh $E $B $T $G > /tmp/drift.tsv
echo "exit=$?  rows=$(wc -l < /tmp/drift.tsv)"
cut -f1 /tmp/drift.tsv | sort | uniq -c | sort -rn

# (1) CONTROL — the WIDE span, because the null span does NOT discriminate here (§4.3)
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
| (2) `hard-blockers.sh` | exactly **1**: `HARD-UNREGISTERED-CORE-DRIFT  skills/ai-dlc/extensions/README.md`. **Expected — §4.1. Row 4 is what ends it.** |
| (3) `unregistered-drift.sh` | **63 rows**: `CORE-OK` 59, `CORE-TEMPLATE-SUBSTITUTED` 3, `HARD-UNREGISTERED-CORE-DRIFT` **1** |
| (4) `ledger-reverify.sh` | `STILL-LIVE` 45, `HAND-REVIEW` 12, `NEEDS-REVIEW` 3, `ENTRY-SWALLOWED` 3, `NAMED-UPSTREAM` 2, `CLOSE-CANDIDATE` 1. Residue, not this pull's work — report it verbatim |
| (5) graph's INSTALLED validator | exit **0**, `0 error(s), 2 warning(s)`, `contract_version=10 … behind=50`, `unclaimed=none` |
| (6) the ENGINE's validator | exit **1**, `1 error(s), 3 warning(s)`, **`unclaimed=W8`**. The one error is `E16` and it is EXPECTED — §4.2. `W8` names **20** rows |

**STOP CONDITIONS.** Any status in (1) outside that table. **Any `HARD-` row in (2) other than
the single `extensions/README.md` one** — a second blocker is not covered by this brief. (5)
reading anything but `0 error(s), 2 warning(s)`: graph's tree moved since the rehearsal. **(6)
reporting more than one error, or an error that is not `E16`.**

**IMPOSSIBLE ZEROS, stated rather than counted as clean:** `EXTENSION-ANCHOR-DRIFT` and
`EXTENSION-ANCHOR-MISSING` are **0** against a non-empty subject set — 10 entries declare
`extends:` (control: 39 declare `kind:`). Report it; plan §6c-7 scores it.

---

### Row 3 — `apply` on ONE branch. In `graph`.

```
git checkout -b chore/ai-dlc-update-0.228.0
bash $E/core/skills/ai-dlc-update/reconcile/apply.sh $E $B $G $T
```

**EXPECT exit 0**, 0 stderr, and:

| | |
|---|---|
| `RESOLVED` | **12**, including **`RESOLVED  crosswalk-scaffold  .claude/skills/ai-dlc/crosswalk.md`** |
| `WORKLIST` | **1** — `semantic-merge  skills/ai-dlc/extensions/README.md` |
| `DECISION` | **1** — `drift  skills/ai-dlc/extensions/README.md`, the same file |
| final trio | `relabel`, `restamp cedfa3b -> 5879f70`, `consistent  the tree matches 5879f70; fixture suite re-enabled` |
| changed paths | **9** — 6 modified + 3 untracked (`crosswalk.md`, `templates/crosswalk.md`, `tests/fixtures/layer-crosswalk-home/`) |

**The `DECISION` row is EXPECTED and is not a stop condition.** It is §4.1's blocker arriving at
apply-time, and `apply` handles it by refusing to touch the file.

**VERIFY the two things this release exists for, rather than assuming them:**

```
ls -l .claude/skills/ai-dlc/crosswalk.md                              # EXPECT present, 1626 bytes
cmp -s .claude/skills/ai-dlc/crosswalk.md \
       $E/core/skills/ai-dlc/templates/crosswalk.md && echo SCAFFOLD-OK
grep -c '^|' .claude/skills/ai-dlc/extensions/README.md               # EXPECT 22 -- apply refused
```

**STOP CONDITION:** no `crosswalk.md` (that is v0.227.0's defect recurring — escalate, do not
create it by hand), or the README's pipe count below 22 (a crosswalk row you lost).

---

### Row 4 — the migration + the semantic merge. In `graph`. **The only judgement in this pull.**

Your 20 rows move to the file row 3 created, the authoring-constraints paragraph moves with them,
and `extensions/README.md` goes back to being core's file byte-for-byte.

```
CW=.claude/skills/ai-dlc/crosswalk.md
RM=.claude/skills/ai-dlc/extensions/README.md

# 1. harvest — data rows only; the header and separator stay in the template's table
grep '^| ' $RM | grep -vE '^\| your id|^\|---' > /tmp/rows.txt
wc -l < /tmp/rows.txt                        # EXPECT 20
grep -c '^|' $RM                             # CONTROL: 22 -- the reader is discriminating

# 2. the consumer-authored paragraph about your own table moves with the table
sed -n '/^\*\*Two authoring constraints on this table/,/rotation date rather than the authorship date\./p' $RM > /tmp/para.txt
wc -l < /tmp/para.txt                        # EXPECT 7

# 3. append both, cmp -s guarded
cp $CW /tmp/cw.before
{ cat /tmp/rows.txt; printf '\n'; cat /tmp/para.txt; } >> $CW
cmp -s /tmp/cw.before $CW && echo "MIGRATION DID NOT APPLY -- stop" || echo "written"

# 4. the semantic merge IS taking core's file. Brace the ref: $T:core/... is eaten by zsh.
git -C /Users/n8/git/ai-dlc show "${T}:core/skills/ai-dlc/extensions/README.md" > $RM
cmp -s <(git -C /Users/n8/git/ai-dlc show "${T}:core/skills/ai-dlc/extensions/README.md") $RM \
  && echo "README byte-identical to core@THEIRS"
```

**VERIFY [M]:**

```
grep -c '^| ' $CW                            # EXPECT 21  (1 header + your 20 rows)
grep -c '^|'  $RM                            # EXPECT 3   -- core's fenced example, nothing else
bash scripts/ai-dlc/validate-layer-entries.sh . | tail -2
```

**EXPECT exit 0, `0 error(s), 2 warning(s)`** — `W6` and `W7`, and **`W8` gone**. Footer
`contract_version=11 entries=50 at_current=0 behind=50 undeclared=0 errors=0 warnings=2`,
`unclaimed=none`.

**STOP CONDITIONS.** A surviving `W8` means rows were copied rather than moved. **Any `E16` means
a row was dropped rather than relocated — report it, do not re-add it to the old file to make it
pass.** `grep -c '^|' $RM` anything but 3: re-derive core's own count from
`git -C /Users/n8/git/ai-dlc show "${T}:core/skills/ai-dlc/extensions/README.md" | grep -c '^|'`
rather than trusting this line — it is a property of core's file and core's file can change.

**And the outcome the migration half exists for, which must be SHOWN and not inferred from the
row count:**

```
bash $E/core/skills/ai-dlc-update/reconcile/hard-blockers.sh $E $T $G $T | grep -c '^HARD-'
```

**EXPECT 0** [M]. That is the next pull's blocker reading, taken now.

---

⏹ **FRESH GRAPH SESSION** is *not* needed here — rows 3–5 are one short arc. Carry on.

---

### Row 5 — post-apply verification + the stamp half `apply` deliberately does not do. In `graph`.

```
cat .claude/.ai-dlc-version
grep -m1 '^contract_version:' .claude/skills/ai-dlc/layer-contract.yaml
grep -c '^consumer_crosswalk_file:' .claude/skills/ai-dlc/layer-contract.yaml
```

**EXPECT** `version: 0.228.0` / `commit: 5879f70`, `contract_version: 11`, the declaration count
**1** — **and `skill_version: 0.226.0` / `skill_commit: cedfa3b`, which is CORRECT at this point.**
`apply` preserves that pair by design.

```
bash .claude/skills/ai-dlc-update/reconcile/self-update-gate.sh $E $B $T $G
```

**EXPECT `SELF-UPDATE-OK`**. **Note the path:** `scripts/ai-dlc/self-update-gate.sh` does not
exist in graph (exit 127). Still an ai-dlc handoff defect, still out of scope.

Now advance `skill_version` / `skill_commit` to **0.228.0** / **5879f70**, preserving
`installed_at` and `upstream`. **Both pairs must read 0.228.0 before row 6.**

**The flip — graph's installed validators must now be byte-identical to the distribution's:**

```
for f in validate-layer-entries.sh validate-gate-manifest.sh validate-fixture-drivability.sh; do
  cmp -s scripts/ai-dlc/$f $E/core/scripts/$f && echo "IDENTICAL $f" || echo "FORKED $f"
done
cmp -s CLAUDE.md $E/CLAUDE.md && echo "control FAILED" || echo "control ok (CLAUDE.md forks)"
```

**EXPECT three `IDENTICAL` and `control ok`.** Without the control, `cmp -s` answering yes to
everything looks the same.

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
| drivability | `fixture directories : 119 / driven (run.sh) : 109 / declared undrivable: 10 / undeclared: 0` |
| suite | **109 `ok`, 0 FAIL** — including `layer-crosswalk-home` |
| wall clock | **41s** on the rehearsal box. **Re-derive on yours; do not inherit it** |

**One artefact of running the hook by hand:** with `< /dev/null` the trunk-push arm prints *"NO
REF LINES ON STDIN — nothing was judged"* and PASSes. That is correct — git supplies the ref
protocol on stdin during a real push.

Then commit, push, PR:

```
# Stage the pull's paths EXPLICITLY. `git add -A` would sweep in the pre-existing
# _bmad-output/ runtime files, which the diff-surface expectation below excludes.
git add .claude .githooks scripts/ai-dlc tests/fixtures
git commit -m "chore(ai-dlc): pull v0.228.0 (crosswalk table moves to its consumer-owned home)"
git push -u origin chore/ai-dlc-update-0.228.0
gh pr create --fill
git ls-remote --heads origin chore/ai-dlc-update-0.228.0    # verify the push by reading the remote
```

**EXPECTED DIFF SURFACE [M]: 11 files, +913 / −44.**

```
.claude/.ai-dlc-version                                +4/-4
.claude/skills/ai-dlc-update/reconcile/apply.sh        +59/-0
.claude/skills/ai-dlc-update/reconcile/setup-sites.md  +14/-0
.claude/skills/ai-dlc/core-manifest.md                 +1/-0
.claude/skills/ai-dlc/crosswalk.md                     +58/-0    <- row 4: your rows, their new home
.claude/skills/ai-dlc/extensions/README.md             +21/-28   <- row 4: core's file, verbatim
.claude/skills/ai-dlc/layer-contract.yaml              +53/-4
.claude/skills/ai-dlc/templates/crosswalk.md           +30/-0
scripts/ai-dlc/validate-layer-entries.sh               +72/-8
tests/fixtures/layer-crosswalk-home/run.sh             +462/-0
tests/fixtures/layer-crosswalk-home/seed.sh            +139/-0
```

**STOP CONDITION:** `extensions/README.md` showing deletions other than the 28 (your 27 rows plus
the blank line that separated them) — anything more is core text you dropped.

**Leave the pre-existing `_bmad-output/` runtime files UNCOMMITTED** — they are operational state,
not this branch's work.

**Merge is the operator's.** Squash-merge after approval (`CLAUDE.md` Deployment Rule (b)).

**No deploy is owed** [M]: every path above is under `.claude/`, `tests/fixtures/` or
`scripts/ai-dlc/`. Confirm it rather than assuming — `server/`, `web/`, `rebalancer/`,
`graph-node-src/`, `subgraph/` and `infra/` must each read 0 against a control of 11 total, or
Deployment Rule (c) fires.

---

### Row 7 — report back. In `graph`, one command each.

```
cat .claude/.ai-dlc-version                                     # both pairs 0.228.0 / 5879f70
ls -l .claude/skills/ai-dlc/crosswalk.md                        # the file step 14 needed
grep -c '^consumer_crosswalk_file:' .claude/skills/ai-dlc/layer-contract.yaml
git show origin/main:.claude/skills/ai-dlc/crosswalk.md | grep -cE '^[[:space:]]*\|'
git show origin/main:.claude/skills/ai-dlc/extensions/README.md | grep -cE '^[[:space:]]*\|'
bash scripts/ai-dlc/validate-layer-entries.sh . | tail -2
git rev-parse origin/main
```

Report those seven verbatim. They discharge plan **§6c-13's DONE-CHECK** (stamp `0.228.0`,
contract present, declaration non-zero, `crosswalk.md` resolves) and **§6c-14's** (rows arrived,
README back to core's 3 pipe lines) in the same breath.

---

## 7. Known-open, deliberately out of scope

- **`W6`'s 50-entry re-read against contract v11**, and **`W7` / `Check 11b`**.
- **`self-update-gate.sh` path** — the 0.224.0 brief recorded it; still unfixed.
- **The SIGPIPE driver bug** in `scripts/tests/test-s168-retro-gates.sh` (plan D-6c9.4) — graph's
  file, and `I54` is an invariant over the distribution's tree so it cannot see a consumer's.
- **`suite-content-key.sh` is deliberately not shipped** to consumers (plan D-6c9.2).
- **A brief-driven pull writes no `reconcile-log-*.md`** (plan O-5), so the charter's first
  acceptance number still has no instrument. Unscheduled, and not this pull's to fix.
