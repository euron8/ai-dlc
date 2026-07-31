# graph pull → ai-dlc v0.224.0, **and the total naming migration in the same branch** — operator handoff

**Point a fresh Claude Code session at this file in `/Users/n8/git/graph`.** It drives the pull and
the migration to done across multiple sessions.

This is `read-these-five-documents-zesty-clarke.md` **§6c steps 5 AND 6**. They are one branch here,
and that is not a convenience — it is measured. See §2, decision 1.

Precedent: `docs/reviews/graph-pull-0.213.0-operator-handoff.md` (45 judgements) and
`docs/reviews/graph-retirement-0.214.0-operator-handoff.md` (12). **Do not reuse either** — both are
banked, and both pull to shas that are now ten and eleven releases behind.

---

## 0. How to use this file, and WHICH REPO YOU ARE IN

1. Read §1–§5 in full. They are short and every line is load-bearing.
2. Read the **Progress Ledger** (§5) to find the next unticked row.
3. Read that row's section in §6, execute it, tick the ledger **with a sha or a count** as the last
   act. A fresh session's only way to know where it is.
4. When you reach a **`⏹ FRESH GRAPH SESSION`**, stop. The operator opens a new session **in
   `graph`**, pointed back at this file, and it picks up the next unticked row.

## EVERY ROW RUNS IN `graph`. THERE IS ONE SESSION AT A TIME.

- **All ten rows in §5 run in a session whose working directory is `/Users/n8/git/graph`.** Every
  command, every edit, the `apply`, the migration, the push. No row runs in ai-dlc.
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
| **Distribution target** | `1f5e6cc`, VERSION **0.224.0**. **PIN THIS SHA.** |
| **Consumer** | `graph` at `9b5d408a3` (PR #835, merged 2026-07-31), stamped **0.214.0 @ 04cea81** |
| **Span** | `04cea81 → 1f5e6cc` — **10 releases**, 0.215.0 through 0.224.0 |
| **Base for every classifier** | `04cea81` (the stamp), NOT a tag and NOT `9b5d408a3` |
| **Judgement load** | **3** adjudications + **49** renames + **50** `conforms_to` lines + **19** crosswalk rows + **4** reference repairs |
| **Gates that WEDGE the push if skipped** | one, and it is total: `validate-layer-entries.sh` at pre-push, **103 errors** post-apply |
| Plan that produced this span | `~/.claude/plans/read-these-five-documents-zesty-clarke.md` §6c steps 2, 3, 3b, 4a–4e |

The ten releases, derived from `git log` rather than from any sentence in this file (control: a bogus
`feat(v9.` filter returns 0 over the same log): **0.215.0, 0.216.0, 0.217.0, 0.218.0, 0.219.0,
0.220.0, 0.221.0, 0.222.0, 0.223.0, 0.224.0**.

**graph is NOT frozen for this program.** It has taken two PRs (#834, #835) since the plan's step 1.
Re-derive `9b5d408a3` before you start; if graph has moved, every tally below still holds unless the
move touched `.claude/skills/ai-dlc/`, and row 1 tells you how to check that in one command.

---

## 2. Locked decisions — do not re-litigate

| Decision | Consequence for you |
|---|---|
| **1. ONE branch: the pull AND the migration together.** | **Measured, not reasoned.** Post-apply, graph's own newly-installed `validate-layer-entries.sh` exits **1** with **103 errors**, and `.git/hooks/pre-push` (a 314-byte shim that execs `.githooks/pre-push` regardless of `core.hooksPath`) runs it at step 1. **A pull-only branch cannot be pushed.** Splitting them means `--no-verify`, which is the decision to ship a red consumer. |
| **2. The naming partition is TOTAL, and ERROR.** | Plan §4b, operator-directed. Every id form, every namespace: bare integers, suffixed (`19b`→`919b`), alphabetic (`AP`→`XAP`), step ids. There is no exclusion to find and none to add. |
| **3. The renames are a TRANSCRIPTION from the validator's own output.** | Every `E15` line names the id and its conforming form. Do not invent a scheme, do not re-derive the subject list, and do not batch-`sed` — see §4 trap 2, where a literal transcription silently misses two of the 49. |
| **4. The ONE judgement in the migration is qualifier-vs-rename.** | An entry whose whole purpose is to render *inside* a core section (`4a-bis` between core's `4a` and `4b`) migrates to `kind: qualifier` + `extends:`, not to a band id. Decide per entry and record which route each took. |
| **5. A core defect is fixed in ai-dlc, never in graph.** | Stop and escalate. The ONLY reason to open an ai-dlc session. |
| **6. Merge is the operator's.** | `CLAUDE.md` Deployment Rule (b). Push → PR → squash merge; graph's last eight landings are all single-parent squash merges carrying a `(#NNN)`. **A branch that is only committed is not delivered.** |

---

## 3. Non-negotiable discipline

**A zero is not a finding.** Every absence-shaped claim carries a control in the same invocation that
returns non-zero — **and the control must be able to match the CONSTRUCT you are calling absent, not
merely some construct.**

**Guard every mechanical edit with `cmp -s`.** A substitution that matched nothing is
indistinguishable from one that succeeded. This is not theoretical here: **2 of the 49 renames missed
on the first pass** and only the guard caught them (§4 trap 2).

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
`git clone --local` of graph at `9b5d408a3`. graph itself was never written to** — not the tree, not
a branch, not a worktree. The rehearsal ran the real `apply.sh`, the real migration, and graph's own
`.githooks/pre-push`, and it finished **`PREPUSH_RC=0`, all gates green, 106 fixtures ok**.

So the questions this file would otherwise ask you to discover are already answered. **Eight of them
came back differently from what the plan predicted.** Each is a trap in the sense that it looks like
success or like an honest absence.

### 4.1 — The judgement load COLLAPSED, 17 → 3, and step 1 is why

`layer-drift.sh` over `04cea81 → 1f5e6cc` returns **59 rows, exit 0, 0 stderr**:

| status | n |
|---|---|
| `EXTENSION-OK` | 35 |
| `OVERRIDE-OK` | 12 |
| `HARD-LAYER-ADJUDICATION-MISSING` | **3** |
| `EXTENSION-HOOK-DRIFT` | **3** |
| `OVERRIDE-DOUBLE-SHADOW` | 2 |
| `OVERRIDE-DELEGATES-INTO-SHADOW` | 2 |
| `OVERRIDE-ASSERTS-SHADOW-SURVIVES` | 2 |

Controls: a bogus status over the same output returns rc=1; the null span (`1f5e6cc..1f5e6cc`)
returns 38 `EXTENSION-OK` / 0 hook-drift, so the counter can read zero.

The 0.213.0 pull carried **17** adjudications over 25 releases. This one carries **3** over 10.
**The three that remain all hook `SKILL.md`** — `party-mode-inline-relay.md`, `SKILL-domain.md`,
`SKILL-push.md` — and core's `SKILL.md` moved `+22/−9` in the span, entirely inside Rule 27.

### 4.2 — There are NO override blockers, and the absence is explained rather than merely observed

`hard-blockers.sh` returns **3 HARD rows, all adjudications** — no `HARD-OVERRIDE-DRIFT-SECTION`, no
`HARD-UNREGISTERED-CORE-DRIFT`. That would normally be the shape of a blind instrument. It is not:
**24 core files changed in the span and ZERO of them are under `core/skills/ai-dlc/steps/`**, which
is where every override target lives. Control: `core/skills/ai-dlc/SKILL.md` changed in the same
`git diff`, and a bogus path returns 0.

### 4.3 — `EXTENSION-ANCHOR-DRIFT` reads 0 against a NON-EMPTY subject set, for the first time

**10 entries now declare `extends:`** (control: 39 declare `kind:`). When the plan's §1 goal 4 was
written the figure was **0 of 45**, which made every anchor-drift zero vacuous. It is now a
measurement: 0 anchor-drift across 10 anchored entries, in a span where the hooked file moved.
**This is the one acceptance-test number the program has actually moved, and step 7 should say so.**

### 4.4 — TRAP: the crosswalk obligation is **19 rows, not 49**, and §6c-6 is wrong about it

The plan says *"A crosswalk row for every one of the 49 … step 3's arm will block the pre-push until
each row exists."* **Refuted, both directions, on the clone:**

| probe | E15 | E16 | control in the same run |
|---|---|---|---|
| baseline | 49 | 4 | — |
| rename `Rule 13` → `Rule 913` (core **defines** 13) | **48** | **4 — unchanged** | E16 still names `33` |
| rename `Rule 31` → `Rule 931` (core does **not** define 31) | 47 | **5, and it names `Rule 31`** | E16 still names `33` |
| rename `2s.` → `902s.` (pending, section id) | 46 | **6, and it names `2s`** | E16 still names `33` and `Rule 31` |

**Renaming an id core still defines creates no obligation** — core remains the source of truth for it,
so the bare citation stays resolvable. Only an id that leaves the *rendered rulebook* needs a row.
After all 49 renames the count is **20 obligations satisfied by 19 distinct rows** (one id, `5e`, is
claimed by two entries and one row clears both).

*The first `2s.` probe in this rehearsal did not land — the heading is `### 2s.`, my pattern assumed
`## 2s.`, and the commit reported `nothing to commit`. The `0` it produced was a false zero of my own
making and is discarded; the row above is the re-run, guarded.*

### 4.5 — TRAP: two of the 49 remedies are **not literally transcribable**

The validator reports the alphabetic ids as `AP.` and `VH.` and prescribes `XAP.` / `XVH.` — with a
trailing dot. **The headings carry no dot:** `## Check AP — Attribution provenance (every gate)`.
A literal transcription matches nothing and edits nothing.

The correct edit is `## Check XAP —` and `## Check XVH —`, and both clear `E15` once made. **`cmp -s`
is what turned this from a silent miss into a visible one** — without it, 47 of 49 would have read as
49 of 49.

*This is a core defect in ai-dlc's message text, not a graph problem. It is filed in §7 and does NOT
block: the remedy is achievable, it just is not a copy-paste. Do not escalate mid-migration.*

### 4.6 — TRAP: the renames BREAK intra-consumer references, and no plan row mentions it

After the 49 renames the validator reports **4 new `W3` warnings** where it reported 0 before —
entries whose prose says "Step 0b", "Step 5c-table", "Step 5e" against headings that no longer exist:

| referencing file | dangling reference | repair |
|---|---|---|
| `checks/gate-validation-domain.md` | `Step 0b` | `Step 900b` |
| `steps-domain/deploy-validate-domain.md` | `Step 0b` | `Step 900b` |
| `steps-domain/retro-push-validator-preflight.md` | `Step 5c-table` | `Step 905c-table` |
| `steps-domain/SKILL-push.md` | `Step 5e` | `Step 905e` |

Plan §4b's D-4b.1 argues that renumbering *"moves the allocation and leaves the reference exactly
where it was. Nothing is lost."* **That is true of references to CORE's ids and false of references
to the consumer's OWN.** `W3` is a WARN, so it does not wedge the push — which is exactly why it
would have shipped unnoticed. Row 8 repairs all four.

### 4.7 — TRAP: a rename can AWAKEN an obligation on a different entry

`retro-domain.md` acquires an `E16` row for `5e` when `retro-gate-log-rotation.md` renames `5e` away.
`retro-domain.md` was not edited. Its git history shows it once defined `5e`, and that obligation was
dormant only because another entry still defined the id. **Do not assume the E16 set is a function of
the files you touched.** Re-run the validator and take its output.

### 4.8 — Two "pending" ids produce NO crosswalk obligation, and the difference is a different join

The pending set (ids core does not allocate today) is **17**: `0`, `0b`, `19b`, `1b`, `2a`, `2d`,
`2e`, `2s`, `4a-bis`, `4a-quater`, `4a-ter`, `5c-table`, `5e`, `AP`, `Rule 31`, `Rule 32`, `VH`.
The `E16` set after the migration adds only **15 of them** — `0` and `2a` produce no row. `E15`
"pending" joins against core's **catalog**; `E16` joins against the **rendered rulebook**, which
includes core's step sections. Core renders a Step 0 and a Step 2a, so those ids stay resolvable.
**Recorded so that a session which counts 17 and gets 15 does not go looking for a bug.**

### 4.9 — §6c-6's file table is stale by one file (the count is right)

The plan lists **13 files**. It is **14**: step 1 split `retro-push.md` into six entries, and its 2
ids now live in `retro-push-branch-creation.md` (`0.`) and `retro-push-validator-preflight.md`
(`0b.`). **The id total is unchanged at 49** and every other row of that table reproduces exactly.

### 4.10 — `apply` does NOT advance the machinery stamp. The 0.213.0 deviation reproduces verbatim

Post-apply the stamp reads `version: 0.224.0` / `commit: 1f5e6cc` but **`skill_version: 0.214.0` /
`skill_commit: 04cea81`**. `apply.sh` deliberately preserves that pair. Row 5 runs
`self-update-gate.sh` and advances them, preserving `installed_at` and `upstream`. **A row-9 check
that both pairs read 0.224.0 fails without it.**

### 4.11 — The one reading that proves the pull landed the validator, and it is cheap

`unclaimed=` in the `LAYER_MEASURED` footer reads **`E15,E16,E17` before the pull** (findings the
0.224.0 validator emits that graph's installed v7 contract claims from no clause) and **`none`
after**. One command:

```
bash scripts/ai-dlc/validate-layer-entries.sh . | grep LAYER_MEASURED
```

---

## 5. Progress Ledger

**The next unticked row is the next thing to do. Do them in order.** Tick as the last act of each
row, with a sha or the count you measured. `—` = not started.

| # | Row | Repo | Status |
|---|---|---|---|
| 1 | Pre-flight: clean tree, pin the engine, confirm graph has not moved under this file | graph | — |
| 2 | Classify only. Report all five tallies. **Write nothing.** | graph | — |
| 3 | Record the **3** adjudications | graph | — |
| ⏹ | **FRESH GRAPH SESSION** if row 3 took real reading; otherwise carry on | graph | |
| 4 | `apply` on ONE branch | graph | — |
| 5 | Post-apply verification **+ advance the machinery stamp** | graph | — |
| ⏹ | **FRESH GRAPH SESSION** — the migration is its own context | graph | |
| 6 | The migration, part 1: the **49** renames | graph | — |
| 7 | The migration, part 2: `conforms_to: 9` on all **50** entries | graph | — |
| 8 | The migration, part 3: **19** crosswalk rows + the **4** reference repairs | graph | — |
| ⏹ | **FRESH GRAPH SESSION** | graph | |
| 9 | Verify `0 error(s), 0 warning(s)`, run the full pre-push, commit, push, PR, merge | graph | — |
| 10 | Report the acceptance-test inputs back for plan §6c-7 | graph | — |

**Rows 6, 7 and 8 are separated on purpose.** 49 + 50 + 23 mechanical edits do not survive sharing a
context, and row 6 carries the only genuine judgement in the migration (decision 4).

### Out of scope for this pull — surface, do not fix

- **The 6 report-only override rows** (2 `OVERRIDE-DOUBLE-SHADOW`, 2 `OVERRIDE-DELEGATES-INTO-SHADOW`,
  2 `OVERRIDE-ASSERTS-SHADOW-SURVIVES`, across `steps__retro__domain-sections.md`,
  `steps__retro__pipeline-snapshot-ceiling.md`, `steps__gate-validation__snapshot-schema-deploy-baseline.md`,
  `steps__retro__ci-gates-enforcement-surface.md`). Dispositioned in the 0.213.0 pull; unchanged here.
- **The `ledger-reverify.sh` residue** — 66 rows: 46 `STILL-LIVE`, 12 `HAND-REVIEW`, 3 `NEEDS-REVIEW`,
  3 `ENTRY-SWALLOWED`, 2 `NAMED-UPSTREAM`. Report it; do not work it inside this pull.
- **The trailing-dot remedy defect** (§4.5) — ai-dlc's to fix.

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

**EXPECT:** `main`; HEAD `9b5d408a3` **or later**; a working tree whose only entries are under
`_bmad-output/` (4 runtime files at rehearsal time); stamp `version: 0.214.0` / `commit: 04cea81`;
the pre-push shim present at **314 bytes**.

**If HEAD has moved past `9b5d408a3`,** check whether the move touched the layer:

```
git diff --name-only 9b5d408a3 HEAD -- .claude/skills/ai-dlc/ | wc -l
git diff --name-only 9b5d408a3 HEAD | wc -l          # CONTROL: must be non-zero if HEAD moved
```

**Zero on the first line means every tally in this file still holds.** Non-zero: report it and
escalate before row 2 — the 49-id table is derived from the entry files.

**Pin the engine.** An ai-dlc worktree at the target sha, so nothing in this pull depends on that
repo's working state:

```
git -C /Users/n8/git/ai-dlc worktree add --detach /tmp/pull-engine 1f5e6cc
cat /tmp/pull-engine/VERSION      # EXPECT 0.224.0
```

**STOP CONDITION:** `VERSION` is anything but `0.224.0`. Everything below is pinned to `1f5e6cc`.

---

### Row 2 — classify only. Report all five tallies. **Write nothing.** In `graph`.

Argument order differs between these scripts and getting it wrong produces a clean-looking run:

```
# layer-drift.sh     <dist> <base> <theirs>   <consumer>
# ledger-reverify.sh <dist> <base> <consumer> <theirs>     <-- 3rd and 4th SWAPPED
# hard-blockers.sh   <dist> <base> <consumer> <theirs>
```

```
E=/tmp/pull-engine; B=04cea81; T=1f5e6cc; G=/Users/n8/git/graph

# (1) the classifier
bash $E/core/skills/ai-dlc-update/reconcile/layer-drift.sh $E $B $T $G > /tmp/drift.tsv
echo "exit=$?  rows=$(wc -l < /tmp/drift.tsv)"
cut -f1 /tmp/drift.tsv | sort | uniq -c | sort -rn
# CONTROL, same shape: the null span must read zero hook-drift
bash $E/core/skills/ai-dlc-update/reconcile/layer-drift.sh $E $T $T $G | cut -f1 | sort | uniq -c

# (2) the blockers
bash $E/core/skills/ai-dlc-update/reconcile/hard-blockers.sh $E $B $G $T | grep -c '^HARD-'

# (3) the ledger
bash $E/core/skills/ai-dlc-update/reconcile/ledger-reverify.sh $E $B $G $T > /tmp/ledger.tsv
cut -f1 /tmp/ledger.tsv | sort | uniq -c | sort -rn

# (4) the PRE-pull validator reading — this is the "instrument is blind" baseline
bash scripts/ai-dlc/validate-layer-entries.sh . | tail -2

# (5) the engine's validator against graph — what the pull will install
bash $E/core/scripts/validate-layer-entries.sh $G | grep -E '^validate-layer-entries:|^LAYER_CONFORMANCE'
```

**EXPECTED TALLIES [M]:**

| probe | expected |
|---|---|
| (1) `layer-drift.sh` | **59 rows**, exit 0, 0 stderr. `EXTENSION-OK` 35, `OVERRIDE-OK` 12, `HARD-LAYER-ADJUDICATION-MISSING` **3**, `EXTENSION-HOOK-DRIFT` **3**, `OVERRIDE-DOUBLE-SHADOW` 2, `OVERRIDE-DELEGATES-INTO-SHADOW` 2, `OVERRIDE-ASSERTS-SHADOW-SURVIVES` 2 |
| (1) control | null span: **38** `EXTENSION-OK`, **0** hook-drift |
| (2) `hard-blockers.sh` | **3**, all `HARD-LAYER-ADJUDICATION-MISSING` |
| (3) `ledger-reverify.sh` | **66 rows**: `STILL-LIVE` 46, `HAND-REVIEW` 12, `NEEDS-REVIEW` 3, `ENTRY-SWALLOWED` 3, `NAMED-UPSTREAM` 2 |
| (4) graph's INSTALLED validator | exit **0**, `0 error(s), 2 warning(s)` — **this is the blind instrument, not a clean tree.** Its 0.214.0 copy predates E15/E16/E17 |
| (5) the ENGINE's validator | exit **1**, `103 error(s), 0 warning(s)`; footer `contract_version=7 entries=50 at_current=0 behind=0 undeclared=50`; `unclaimed=E15,E16,E17`. Split: **50 `E17`, 49 `E15`, 4 `E16`** |

**STOP CONDITIONS.** Any status in (1) outside that table. A count off by more than one on (1) or
(3). **(5) reading anything other than 103/0** — the migration tables in rows 6–8 are derived from
exactly that run.

**IMPOSSIBLE ZEROS, stated rather than counted as clean:** `EXTENSION-ANCHOR-DRIFT` and
`EXTENSION-ANCHOR-MISSING` are **0**, and unlike every previous pull **that zero has a non-empty
subject set** — 10 entries declare `extends:` (control: 39 declare `kind:`). Report it as a
measurement, because plan §6c-7 needs it.

---

### Row 3 — the 3 adjudications. In `graph`.

All three rows are `EXTENSION-HOOK-DRIFT` against `SKILL.md`, and core's `SKILL.md` moved **+22/−9**
in the span — **entirely inside Rule 27**: the total naming partition, the `X` prefix, the
`conforms_to` receipt, and clause citations added to (b) and (d).

Write one line per row to `_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl`. Required
fields, read from `.claude/schemas/layer-adjudication-register.json` rather than from here:
`clause`, `entry`, `subject_digest`, `verdict`, `recorded_utc`, `reason`. Verdict enum:
`still-additive` | `contradicts-core` | `retire`.

**Copy `subject_digest` from field 4 of each blocking row. Never recompute it** — the schema says so
and the digest covers the entry AND the core file it hooks at `1f5e6cc`.

| entry | digest at `1f5e6cc` | rehearsal analysis — **confirm it, do not inherit it** |
|---|---|---|
| `steps-domain/party-mode-inline-relay.md` | `bc223bfde7507c582836e3bd58df46d4dae5453f` | Adds an inline-relay duty on top of core's party-mode subagent requirement; restates no part of Rule 27 (0 hits for `Rule 27\|900 and above\|out of band\|crosswalk`). Its own stated retirement condition re-probed at theirs: `inline relay` **0** hits in core `SKILL.md` @ `1f5e6cc`, **control 19** `party.mode` hits in the same file and invocation → condition still unmet. → **still-additive** |
| `steps-domain/SKILL-domain.md` | `93efe835a6b77622f14fc400a04cc64f482a0f85` | 6 consumer rules; 0 restatement of Rule 27 (control: 6 `## Rule` headings in the same file). → **still-additive** |
| `steps-domain/SKILL-push.md` | `4a01deb86cefc35875418e66508e0173bb0ba15c` | Same shape, 4 rules. → **still-additive** |

**The trap in this row, and it is the one that would misdirect the whole migration.** All three
entries allocate ids the new Rule 27 forbids. **That is `E15`'s subject and rows 6–8's remedy — it is
not an adjudication outcome.** Recording `contradicts-core` here would charge the entry for a
violation whose fix is a rename, and would leave the rename undone.

**VERIFY, both halves:**

```
bash $E/core/skills/ai-dlc-update/reconcile/hard-blockers.sh $E $B $G $T | grep -c '^HARD-'
# EXPECT 0
mv _bmad-output/ai-dlc-update/layer-adjudication-register.jsonl{,.aside}
bash $E/core/skills/ai-dlc-update/reconcile/hard-blockers.sh $E $B $G $T | grep -c '^HARD-'
# EXPECT 3  -- the CONTROL that the 0 is discharge and not a vacuous scan
mv _bmad-output/ai-dlc-update/layer-adjudication-register.jsonl{.aside,}
```

**Both readings are required.** A `0` without the `3` is a scan that found nothing.

---

### Row 4 — `apply` on ONE branch. In `graph`.

```
git checkout -b chore/ai-dlc-update-0.224.0
bash $E/core/skills/ai-dlc-update/reconcile/apply.sh $E $B $G $T
```

**EXPECT exit 0**, and:

| | |
|---|---|
| `RESOLVED` | **26** |
| `WORKLIST` | **3**, all `extension-reread` — the same three entries row 3 adjudicated |
| `DECISION` | **0** |
| final lines | `RESOLVED relabel ext-check collisions labelled`, `RESOLVED restamp 04cea81 -> 1f5e6cc`, `RESOLVED consistent  the tree matches 1f5e6cc; fixture suite re-enabled` |
| changed paths | **21** (18 modified, 3 untracked) |
| stderr | **0 bytes** |

**STOP CONDITION:** any `DECISION` row, or a non-zero exit. `WORKLIST extension-reread` is normal —
it is the register's three entries asking to be re-read against the new core text, which row 3 did.

---

### Row 5 — post-apply verification, and the stamp half `apply` deliberately does not do. In `graph`.

```
cat .claude/.ai-dlc-version
grep -m1 '^contract_version:' .claude/skills/ai-dlc/layer-contract.yaml
```

**EXPECT** `version: 0.224.0` / `commit: 1f5e6cc`, `contract_version: 9` — **and
`skill_version: 0.214.0` / `skill_commit: 04cea81`, which is CORRECT at this point.** §4.10.

```
bash scripts/ai-dlc/self-update-gate.sh
```

Expect `SELF-UPDATE-DEFER`. Advance `skill_version`/`skill_commit` to `0.224.0` / `1f5e6cc`,
preserving `installed_at` and `upstream`. **Both pairs must read 0.224.0 before row 9.**

**The flip — graph's installed validators must now be byte-identical to the distribution's:**

```
for f in validate-layer-entries.sh validate-gate-manifest.sh validate-fixture-drivability.sh; do
  cmp -s scripts/ai-dlc/$f $E/core/scripts/$f && echo "IDENTICAL $f" || echo "FORKED $f"
done
cmp -s CLAUDE.md $E/CLAUDE.md && echo "control FAILED" || echo "control ok (CLAUDE.md forks)"
```

**EXPECT three `IDENTICAL` and `control ok`.** Without the control, `cmp -s` answering yes to
everything looks the same.

**Now the wedge, and it is expected to be RED:**

```
bash scripts/ai-dlc/validate-layer-entries.sh . | tail -2
```

**EXPECT exit 1, `103 error(s), 0 warning(s)`**, footer `contract_version=9 entries=50 at_current=0
behind=0 undeclared=50`, and **`unclaimed=none`** — §4.11. **If it still reads `0 error(s), 2
warning(s)`, the pull did not land the validator.** Check that before concluding anything.

---

### Row 6 — the migration, part 1: the 49 renames. In `graph`. **Its own session.**

**Do not re-derive the subject list. Run the validator and take its output** — every `E15` line
carries the id and its conforming form:

```
bash scripts/ai-dlc/validate-layer-entries.sh . > /tmp/e15.txt
grep -c '^ERROR  E15' /tmp/e15.txt     # EXPECT 49
```

**14 files, 49 ids [M]:**

| File (under `.claude/skills/ai-dlc/extensions/`) | ids |
|---|---|
| `checks/gate-validation-domain.md` | 16 |
| `steps-domain/SKILL-domain.md` | 6 rules |
| `checks/gate-validation-push.md` | 5 |
| `steps-domain/deploy-validate-domain.md` | 5 |
| `steps-domain/SKILL-push.md` | 4 rules |
| `steps-domain/carry-over-evaluation-domain.md` | 3 |
| `steps-domain/retro-deferral-expiry.md` | 3 (`4a-bis/ter/quater`) |
| `checks/attribution-provenance.md` | 1 (`AP` → `XAP`) |
| `checks/validator-honesty.md` | 1 (`VH` → `XVH`) |
| `steps-domain/bug-investigation-push.md` | 1 |
| `steps-domain/deploy-validate-push.md` | 1 |
| `steps-domain/retro-gate-log-rotation.md` | 1 |
| `steps-domain/retro-push-branch-creation.md` | 1 |
| `steps-domain/retro-push-validator-preflight.md` | 1 |

Split: **32 ALREADY COLLIDED** with a core id today, **17 pending**. Both are ERROR; the split only
tells you which citations are already ambiguous.

**THE JUDGEMENT, per decision 4.** Before renaming, ask of each entry whether its purpose is to
render *inside* a core section. `retro-deferral-expiry.md`'s `4a-bis/ter/quater` is the clear case —
they exist to sit between core's `4a` and `4b`, and renaming them to `904a-bis` moves them out of
that position permanently. The correct migration for those is `kind: qualifier` + `extends:`, which
renders them inside the core section and borrows no id. **Decide per entry and record the route.**
§4b accepts the sort-order cost for everything that is genuinely the consumer's own section.

**MECHANICS — guard every edit:**

```
cp "$f" /tmp/.orig
# ...edit the heading...
cmp -s /tmp/.orig "$f" && echo "MISS: $f" || echo "ok"
```

**TRAP, §4.5 — two of the 49 are not literally transcribable.** The remedy strings read `XAP.` and
`XVH.` with a trailing dot; the headings are `## Check AP — …` and `## Check VH — …` with none. The
correct edits are `## Check XAP —` and `## Check XVH —`. A pattern built from the remedy string
matches nothing on those two, and **without `cmp -s` that reads as 49 of 49 done.**

**VERIFY:**

```
bash scripts/ai-dlc/validate-layer-entries.sh . > /tmp/m1.txt
grep '^ERROR' /tmp/m1.txt | awk '{print $2}' | sort | uniq -c
```

**EXPECT `E15` = 0, `E17` = 50, `E16` = 20, and 4 `W3` warnings** where there were none. The E16 jump
(4 → 20) and the W3 appearance are both correct and are rows 8's work — §4.4, §4.6, §4.7.

**STOP CONDITION:** `E15` non-zero after you believe you are done, or any `MISS` line unexplained.

---

### Row 7 — the migration, part 2: `conforms_to: 9` on all 50 entries. In `graph`.

One frontmatter line per entry. **Read the value from the installed contract, do not transcribe it
from here:**

```
grep -m1 '^contract_version:' .claude/skills/ai-dlc/layer-contract.yaml
```

**The subject list is the validator's own `E17` output** — 50 files, both `extensions/` and
`overrides/`. An entry you have not actually re-read against the current contract should declare the
lower version it was migrated to; `W6` will then name its worklist and nothing is silenced either
way. **Declaring a lower version subtracts no clause** — it is a receipt, not an exemption.

**VERIFY:**

```
bash scripts/ai-dlc/validate-layer-entries.sh . | grep -E '^validate-layer-entries:|^LAYER_CONFORMANCE'
```

**EXPECT** `20 error(s), 4 warning(s)` and the footer
`contract_version=9 entries=50 at_current=50 behind=0 undeclared=0`.

**STOP CONDITION:** `undeclared` anything but 0, or `entries` anything but 50.

---

### Row 8 — the migration, part 3: 19 crosswalk rows + the 4 reference repairs. In `graph`.

**8a — the crosswalk rows.** The table is at
`.claude/skills/ai-dlc/extensions/README.md`, heading *"Catalog crosswalk table (every namespace)"*
— the pull widens that heading from the old check-scoped one. Format:

```
| your id | label | title | resolves a bare citation written before | notes |
```

Derive the obligations from the validator, never by hand:

```
grep '^ERROR  E16' /tmp/m1.txt | grep -oE "used to define '[^']+'" | sort -u
```

**EXPECT 20 rows naming 19 distinct ids** — `5e` is claimed by both `retro-domain.md` and
`retro-gate-log-rotation.md`, and **one row clears both**. The 19: `0b`, `19b`, `1b`, `2d`, `2e`,
`2s`, `33`, `34`, `35`, `4a-bis`, `4a-quater`, `4a-ter`, `5c-table`, `5d`, `5e`, `AP`, `Rule 31`,
`Rule 32`, `VH`.

Four of those (`33`, `34`, `35`, `5d`) pre-date this migration and have **no successor id** — they
were retired outright by the 0.214.0 retirement. Say so in `notes`; do not invent a successor.
Write column 1 namespaced (`Rule 31`, `Check 33`) per the README's own instruction.

**Do NOT try to add a row for all 49.** §4.4: renaming an id core still defines creates no
obligation, and the plan's §6c-6 is wrong about this.

**8b — the 4 dangling references** (§4.6). `W3` names each one:

| file | `Step 0b` → `Step 900b`, `Step 5c-table` → `Step 905c-table`, `Step 5e` → `Step 905e` |
|---|---|
| `checks/gate-validation-domain.md` | `Step 0b` |
| `steps-domain/deploy-validate-domain.md` | `Step 0b` |
| `steps-domain/retro-push-validator-preflight.md` | `Step 5c-table` |
| `steps-domain/SKILL-push.md` | `Step 5e` |

**Use the successor id you actually chose in row 6.** If an entry went the qualifier route instead of
renaming, its references need the qualifier's anchor, not a band id.

**VERIFY — this is the migration's exit condition:**

```
bash scripts/ai-dlc/validate-layer-entries.sh . ; echo "exit=$?"
```

**EXPECT exit 0, `0 error(s), 0 warning(s)`**, footer
`contract_version=9 entries=50 at_current=50 behind=0 undeclared=0 errors=0 warnings=0`.

**CONTROL, and do not skip it — a clean validator is exactly what a broken one looks like:**

```
cp .claude/skills/ai-dlc/extensions/checks/validator-honesty.md /tmp/vh.bak
# revert that one rename: '## Check XVH' -> '## Check VH'
bash scripts/ai-dlc/validate-layer-entries.sh . | tail -1      # EXPECT 1 error(s)
cp /tmp/vh.bak .claude/skills/ai-dlc/extensions/checks/validator-honesty.md
bash scripts/ai-dlc/validate-layer-entries.sh . | tail -1      # EXPECT 0 error(s)
```

**Both readings.** The rehearsal ran exactly this and got `1` then `0`.

---

### Row 9 — verify, commit, push, PR, merge. In `graph`.

```
git add -A && git commit -m "chore(ai-dlc): pull 0.224.0 and migrate every consumer id into the reserved band"
```

**Rehearsal diff against `9b5d408a3`: 75 files changed, +3326 / −408** — 39 under `extensions/`,
13 `tests/fixtures/`, 13 `overrides/` (the `base_sha` restamp), 2 `scripts/ai-dlc/`, plus the stamp,
the contract, `SKILL.md`, `core-manifest.md`, the update skill and the register.

**Run the full pre-push.** Do it in the background and poll — the fixture suite is the long pole:

```
bash .githooks/pre-push origin <remote-url> < /tmp/pushrefs.txt   # or just: git push -u origin HEAD
```

**EXPECT `pre-push: all gates green`, rc 0, 106 fixtures `ok`, 0 FAIL**, and
`fixture directories: 116 / driven 106 / declared undrivable 10 / undeclared 0`. **[M] — the
rehearsal ran graph's own hook on the finished tree and got exactly this.**

**And the green is a FLIP, which the rehearsal proved rather than assumed.** With exactly one of the
49 renames reverted (`## Check XVH` → `## Check VH`) the same hook on the same tree returns
**rc 1**, `FAIL` at *"layer entries (Rule 27: override base_sha, catalog collisions)"*,
`validate-layer-entries: 2 error(s)`. A pre-push that cannot go red is not evidence the migration
landed.

**Verify the push by `git ls-remote --heads`, never by a piped exit code.**

Open a PR. **Squash-merge after operator approval** (`CLAUDE.md` Deployment Rule (b)). Reconcile the
squash **by content, not ancestry** — graph squash-merges, so `--is-ancestor` is false by
construction and answering that question is how a merged branch reads as unmerged
(plan D-6c1.1):

```
git diff <your-commit> origin/main        # EXPECT empty
git diff 9b5d408a3 origin/main | wc -l    # CONTROL: must be large
```

**PR body carries:** row 2's five tallies verbatim, row 3's 3/0/0 verdict split, the rename route
taken per entry (band id vs qualifier), the 19 crosswalk rows, and the ledger residue from row 2 (3)
as follow-ups.

---

### Row 10 — report the acceptance-test inputs. In `graph`, one command each.

Plan §6c-7 re-runs the acceptance test from an ai-dlc session and needs three readings taken **after**
the merge. Report them in the PR or back to the operator:

```
bash scripts/ai-dlc/validate-layer-entries.sh . | grep -E '^LAYER_CONFORMANCE|^LAYER_MEASURED'
grep -rl '^extends:' .claude/skills/ai-dlc/extensions/ | wc -l   # and the kind: control
git rev-parse HEAD
```

**The number that has moved and should be stated plainly:** `EXTENSION-ANCHOR-DRIFT` is **0 across 10
`extends:`-declaring entries** — the first pull in this program where that zero has a subject set.
§4.3.

---

## 7. Known-open, deliberately out of scope

- **The trailing-dot remedy defect (§4.5).** `validate-layer-entries.sh` reports alphabetic section
  ids as `AP.` / `VH.` and prescribes `XAP.` / `XVH.`, but the headings carry no dot, so the remedy
  string is not literally applicable. **ai-dlc's to fix**; it does not block this pull.
- **`W3` has no arm for a reference broken by a rename in the same tree (§4.6).** The 4 warnings are
  correct and were caught, but nothing joins "id renamed" to "references to it" — a consumer that
  renames and does not read the warnings ships dangling prose. A candidate ai-dlc invariant.
- **The 6 report-only override rows.** Unchanged since the 0.213.0 pull.
- **The `ledger-reverify.sh` residue** — 66 rows, 46 `STILL-LIVE`. Worked in its own pass, not here.
- **The 3 `NEEDS-REVIEW` ledger rows** — new status since the last pull; report, do not adjudicate.
