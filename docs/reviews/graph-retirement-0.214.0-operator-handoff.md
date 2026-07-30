# graph duplicate-enforcement retirement — operator handoff

**Point a fresh Claude Code session at this file in `/Users/n8/git/graph`.** It drives the retirement
to done across multiple sessions.

**This is not a pull.** graph is already stamped `0.214.0 @ 04cea81` on both pairs and there is no
distribution span to reconcile. Nothing here runs `apply.sh`, and no classifier joins two trees. What
this brief disposes is the residue a completed pull left behind: **consumer scripts implementing a
predicate a shipped core validator already implements**, and the extension checks that mandate them.

Produced by row 4 of `docs/analysis/post-program-gap-closure-plan.md`. Its **row 3 RESULT** is this
brief's input and bounds what appears here: the three subjects that came back **REFUTED** are not
retired by this brief, and §7 says what happens to them instead.

---

## 0. How to use this file, and WHICH REPO YOU ARE IN

1. Read §1–§5 in full. They are short and every line is load-bearing.
2. Read the **Progress Ledger** (§5) to find the next unticked row.
3. Read that row's section in §6, execute it, tick the ledger **with a sha or a measured count** as
   the last act. A fresh session's only way to know where it is.
4. When you reach a **`⏹ FRESH GRAPH SESSION`**, stop. The operator opens a new session **in
   `graph`**, pointed back at this file, and it picks up the next unticked row.

## EVERY ROW RUNS IN `graph`. THERE IS ONE SESSION AT A TIME.

- **All seven rows in §5 run in a session whose working directory is `/Users/n8/git/graph`.** Every
  command, every edit, the push.
- **This file lives in the ai-dlc repo and is read by absolute path.** That is the only ai-dlc
  involvement in the normal path. Reading a brief from another directory is not "running in" it.
- **`⏹ FRESH GRAPH SESSION` is context hygiene, not a repo switch.** Same repo, same file, next row.

**When an ai-dlc session IS needed — CONDITIONAL, not scheduled.** One trigger only:

> **A tally deviates from its stated expectation, or a stop condition fires.**

Then, and only then, stop and open a session in `/Users/n8/git/ai-dlc` with the deviation. If every
tally matches, **you never open one.**

**A core defect found during this retirement is fixed in ai-dlc and re-delivered — never patched in
graph.** That rule held through the entire 0.213.0 pull and is not relaxed. It applies with more
force here than in a pull: this brief deletes consumer code on the strength of core's coverage, so a
core validator that turns out not to cover its subject is the one failure that must not be papered
over by keeping the consumer copy quietly alive.

**Everything in §6 is reference for the row you are on. §5 says what to do next; nothing else in this
file does.**

**Fidelity tags.** **[V]** = measured 2026-07-30 with a control, during row 3's derivation or row 4's
authoring pass. **[R]** = reported, not re-verified — **treat as a hypothesis.** Row 3 measured six
absorption claims and **refuted three of them**; row 4 then corrected four of row 3's own figures
(§4). Assume this file contains at least one more.

---

## 1. State at handoff

| | |
|---|---|
| **`graph`** | `18e00ef40`, on `main`, stamped **0.214.0 @ 04cea81** on both the rulebook and machinery pairs **[V]** |
| **Working tree** | 4 pre-existing modifications, all runtime state under `_bmad-output/` **[V]**. Not this brief's; leave them |
| **`ai-dlc`** | `main` at VERSION **0.214.0**. **No distribution sha is pinned and no engine worktree is needed** — see below |
| **Judgement load** | 2 script retirements, 1 partial excision, 1 check-block excision, 3 ledger filings |
| **Gate that WEDGES if done wrong** | one: the `gate_types:` frontmatter line in row 2. Measured, §4 item 2 |
| **graph freeze** | **IN FORCE.** No sprint runs in graph until row 7 merges and says the freeze is over |

**No engine worktree, and this is the one structural difference from the 0.213.0 pull.** That pull
had to run every classifier from a pinned distribution worktree because graph's installed engine was
25 releases stale and **could not emit the statuses the pull added**. Here, graph is stamped at the
distribution's own HEAD and **all three core absorbers are already installed and byte-identical to
core [V]**:

| Core absorber, at `graph:scripts/ai-dlc/` | `shasum` prefix | matches `core/scripts/` |
|---|---|---|
| `core-paths.sh` | `89ff1b7fc261` | yes |
| `validate-mutation-red.sh` | `a1ec071b3ca7` | yes |
| `validate-provenance-block.sh` | `392a592c5a53` | yes |

So every core-side command in this brief runs **graph's own installed copy**, and `--strays` is real
in graph today. Row 1 re-confirms all three before anything is deleted.

---

## 2. Locked decisions — do not re-litigate

| Decision | Consequence for you |
|---|---|
| **One branch, all seven rows** | The check-block excision and the script deletions are one change; splitting them leaves a check naming a deleted script on `main`. |
| **Check 34 is deleted, but its SCHEDULE is preserved in the three role files** | Core's equivalent fires at **retro/close**; graph's Check 34 fires at **gate-1, every story** **[V, §4 item 6]**. Deleting the check without repointing the roles is a coverage loss wearing a retirement label. |
| **Check 35 is deleted outright** | Core's own role files already carry the `validate-mutation-red.sh` mandate **[V, §4 item 7]**. Nothing needs preserving. |
| **`scan-stray-provenance.sh` SURVIVES** | Only its stray arm is excised. `--fixture-provenance` is **not absorbed** by anything and is out of scope per the predecessor's §9. Deleting the whole script deletes an unreplaced capability. |
| **The three REFUTED subjects are FILED, not fixed** | `retro-replay-harness.sh`, `generate-sprint-status.py`, `validate-no-direct-main-push.sh`. Row 6 files them with falsifiable receipts. Retiring one here is out of scope and row 3 measured why. |
| **A core defect is fixed in ai-dlc, never in graph** | The ONLY reason to open an ai-dlc session. |

---

## 3. Non-negotiable discipline

**A zero is not a finding.** Every absence-shaped claim carries a control in the same invocation that
returns non-zero. Report both.

**Never read `$?` after a pipe.** It is the pipe's last stage. Redirect to a file, then check. *(This
was violated once during row 4's own authoring pass — a `git grep | head` control printed `rc=0` for
a token with zero matches. It proved nothing and was re-run.)*

**`printf '%s' "$VAR" | grep -q` inverts under `pipefail`.** Read the value as a here-string:
`grep -q ... <<<"$VAR"`.

**Unbraced `$ref:path` in zsh.** `:c`/`:t` are history modifiers and eat the next character. Always
`"${r}:path"`.

**Build every mutant as a COPY, never an in-place edit, and guard with `cmp -s`** so a `sed` that
matched nothing cannot pass as a mutation.

**A deletion is not a retirement until something re-tests that it stays deleted.** §3 criterion 4 of
the plan. Every row here ends with a probe a later pull re-runs, not a checkbox in a PR body.

**A widened exemption is not a fix.** If a gate reports a finding, the remedy is the finding's
subject — never the gate's scope.

**Report tallies verbatim at a boundary.** Not "as expected" — the number, and the stop condition it
was measured against. **The 0.213.0 handoff's own ledger records three arithmetic slips in that
brief** which the executing session caught and correctly proceeded through. **Row 4 found four more
in its own input (§4). Expect to find one in this file, and report it rather than adjusting to it.**

---

## 4. Premises already falsified, and the traps measured in advance

**Row 3 gave the verdicts. Row 4 re-derived the wiring against `graph 18e00ef40` and corrected four
of row 3's figures.** Each correction below is measured with a control. Where this file and row 3
disagree, **this file is later and was measured against the tree you are about to edit.**

| # | Premise | What is actually true | Control |
|---|---|---|---|
| 1 | Row 3: checks 33/34/35 occupy `gate-validation-domain.md` lines **787–915** | The file is **914** lines, so 915 does not exist. The headings also run **34 (787), 33 (862), 35 (872)** — **not numeric order**. The contiguous block including its `## Check 34` section marker is **784–914 = 131 lines (14.3%)** | `wc -l` = 914; `grep -n '^### '` tail; a bogus `^### 999\.` returns 0 |
| 2 | Excising the three checks is a clean deletion | **It WEDGES.** Leaving `gate_types: implementation` in the frontmatter makes `validate-gate-manifest.sh` exit **2**: *"declares gate_types: implementation and carries no `<!-- CHECK_LOADED: <id> -->` anchor … the declaration claims loading for nothing."* The frontmatter line **must go in the same edit** | Measured on a clone of `18e00ef40`, both variants run; variant B (line removed) exits 1 with the expected residual |
| 3 | Losing `extension gate_types: 34->implementation` regresses the 0.213.0 pull's row 3b | **It does not.** Check 34's `<!-- CHECK_LOADED: 34 -->` (line 788) is the **only anchor in the entire `extensions/checks/` tree**; the mapping existed solely to claim check 34. Row 3b's real gain was `manifest source: core`, which is untouched | `grep -rc CHECK_LOADED extensions/checks/` → the other three files carry **0** |
| 4 | Row 3: the stray arm is **~110 of 155** lines | Over-counted. `--fixture-provenance` is lines **58–89 (32)**; the stray scan body is **90–155 (66)**; lines **1–57** are a header documenting **both**. The stray arm proper is ~66 body lines plus stray-only header prose | Block boundaries read directly; `fi` at 88, `# --- end AC4 mode` at 89 |
| 5 | Row 3: subject 3 has **3 live sites** plus 4 test scripts | Short by one. `scripts/lib/pr-class.sh` carries the script at **:163** (`EXPECTED_VALIDATORS`) **and at :89** (`'^scripts/scan-stray-provenance\.sh$'`, a path allowlist entry) | Scoped `git grep` excluding `_bmad-output`/`docs`; bogus token rc=**1**, 0 lines; universal token **389** files |
| 6 | Check 34 is a pure duplicate of `core-paths.sh --audit-diff` | **The script is. The SCHEDULE is not.** Core's check is `### Core-layer immutability (§7.1 authoring guard — retro/close gate)` (`core/skills/ai-dlc/steps/gate-validation.md:1700`) and its Scope reads *"Fires at the retro / sprint-close gate"*. graph's Check 34 fires *"at gate-1 … for every story"*. **Core's `team-roles/` carry no protected-core-path pre-flight at all** | Universal token matches **11** files in `core/team-roles`; the only `core-paths.sh` hit there is `protected-path-editor.md:42`, a different mode (`--is-core`) in a different role |
| 7 | Check 35 is a pure duplicate | **Confirmed, and core carries the mandate at role level** — `core/team-roles/code-reviewer.md:418`, `dev.md:201`, `qa.md:79` all name `validate-mutation-red.sh`. Nothing needs preserving | same grep, three distinct files |
| 8 | graph needs core's replacement fixtures staged | Already delivered. `tests/fixtures/mutation-red-replay/`, `core-paths-audit-diff/` and `stray-party-mode-provenance/` are all **present with `run.sh` + `seed.sh`**, so all three are already in the push suite's generic fixture loop | 114 fixture dirs total; each named dir listed |
| 9 | The retirement touches the push suite's script list | It does not. **Neither `ci-local.sh` nor `.githooks/pre-push` names any of the three retiring scripts** | `ci-local.sh` names **39** `scripts/tests/test-*`; `.githooks/pre-push` carries **8** `bash scripts/` invocations |

**Two traps row 3 recorded from its own false probes — carry them:**

- **`validate-fixture-drivability.sh` is meaningless without `--dir` or a correct
  `CLAUDE_PROJECT_DIR`, and must never be run under `--quiet` as evidence.** Bare, it reads
  `PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"`; pointed at a tree with no `tests/fixtures` it correctly
  reports "nothing to judge" and **`--quiet` swallows the sentence, leaving exit 0 in silence.**
- **`--audit-diff` has a citation escape hatch that makes a FAIL case answer PASS.**
  `docs/escalations/pending.md` accumulates `Operator authorization:` lines (**8 at `HEAD` [V]**) and
  they clear any later in-place core touch. A PASS from that mode is not evidence the range is clean.

**One more, from Check 17's own prose [V]:** it names **five** ceremony homes and **both**
implementations carry **six**. `docs/architecture-history.md` appears **0** times in the whole
914-line file (control: `architecture.md` appears once in the same span). Row 5 fixes this while it
is in there; it is a live under-declaration, not a cosmetic one.

**The lesson to carry through every row: when a probe answers "clean," check that it ran.**

---

## 5. Progress Ledger

**The next unticked row is the next thing to do. Do them in order.** Tick as the last act of each
row, with a sha or the count you measured. `—` = not started.

| # | Row | Repo | Status |
|---|---|---|---|
| 1 | Pre-flight and baseline. Confirm the three absorbers, record the four baseline tallies. **Write nothing.** | graph | — |
| 2 | Excise checks 34/33/35 **and** the `gate_types:` frontmatter line — §6.2 | graph | — |
| 3 | Subject 1: delete `check-protected-core-paths.sh`, repoint the 3 role lines — §6.3 | graph | — |
| 4 | Subject 2: delete `check-mutation-red-anchor.sh`, its test, and its fixture — §6.4 | graph | — |
| ⏹ | **FRESH GRAPH SESSION.** Report the row-1 baselines against the row-2/3/4 post-state. | graph | |
| 5 | Subject 3: excise the stray arm, repoint Check 17 + `pr-class.sh` + 3 tests — §6.5 | graph | — |
| ⏹ | **FRESH GRAPH SESSION.** Row 5 is per-item judgement and does not share a context with row 6. | graph | |
| 6 | File the 3 REFUTED subjects as ledger entries with falsifiable receipts — §6.6 | graph | — |
| 7 | Verify, commit, push, PR, merge. **Report the net tally. Then UNFREEZE** — §6.7 | graph | — |

### Out of scope — surface, do not fix

Each is a **consumer decision** this brief's duty is only to report.

- **Renumbering the 2 surviving `W5` squatters** (rules 31/32) — wants a crosswalk row first.
- **Disposing the 2 surviving `UNLOADABLE` checks** (`19b`, `2s`) — both want an anchor plus
  `gate_types:`, and `gate_types:` is exactly what row 2 removes from this file for a different
  reason. Do not conflate them.
- **`Check AP` / `Check VH`** — alphabetic ids, structurally outside the numeric heading grammar, so
  they appear in no tally here. **Their absence is not evidence they load.**
- **`--fixture-provenance`'s one live caller is its own test**, which `ci-local.sh` does not reference
  and no fixture `run.sh` drives **[V]**. Whether to keep a 32-line arm nothing runs is a consumer
  decision; row 5 preserves it and files the question.
- **graph has no enforcement of "no direct push to `main`" at all [V]** — row 6 files this. It is a
  finding, not a task for this brief.

---

## 6. Rows

### Row 1 — pre-flight and baseline. In `graph`. Write nothing.

**1a. A clean-enough tree.** `git status --porcelain` — expect **4** entries, all runtime state under
`_bmad-output/`. Read the list, not the count. Anything outside that prefix: stop and ask.

**1b. The pre-push shim. If it is missing, every gate in this brief is silently disarmed.**

```bash
ls -l .git/hooks/pre-push          # expect: present, 314 bytes
git config core.hooksPath          # expect: NO output (unset)
```

**STOP CONDITION:** shim absent, or `core.hooksPath` set. Do not "fix" it by setting
`core.hooksPath` — that trades this problem for the gitleaks one.

**1c. Confirm the three absorbers are installed and match core.** This is what makes the deletions
safe, and it is the one premise the whole brief rests on.

```bash
for s in core-paths.sh validate-mutation-red.sh validate-provenance-block.sh; do
  shasum "scripts/ai-dlc/$s" "/Users/n8/git/ai-dlc/core/scripts/$s"
done
```

**EXPECT** each pair identical: `89ff1b7fc261…`, `a1ec071b3ca7…`, `392a592c5a53…` **[V]**.
**STOP CONDITION:** any pair differs. That means graph's stamp is lying about what is installed, and
nothing may be deleted until it is resolved in an ai-dlc session.

**1d. The four baseline tallies.** Run graph's own installed copies.

```bash
# (i) W5 squatters -- the token 'W5' is NOT in the output. Match 'OUT OF BAND'.
bash scripts/ai-dlc/validate-layer-entries.sh . > /tmp/vle.txt 2>&1; echo "rc=$?"
tail -1 /tmp/vle.txt; grep -c 'OUT OF BAND' /tmp/vle.txt

# (ii) UNLOADABLE -- takes a FILE, not a root
bash scripts/ai-dlc/validate-gate-manifest.sh \
     .claude/skills/ai-dlc/steps/gate-validation.md > /tmp/vgm.txt 2>&1; echo "rc=$?"
grep -E 'UNLOADABLE|MISSING|ORPHAN|manifest source|gate_types' /tmp/vgm.txt

# (iii) fixture drivability -- --dir is MANDATORY, --quiet is FORBIDDEN as evidence
bash scripts/ai-dlc/validate-fixture-drivability.sh --dir tests/fixtures > /tmp/vfd.txt 2>&1
echo "rc=$?"; head -3 /tmp/vfd.txt

# (iv) the stray floor, which must stay PASS across rows 2-5
bash scripts/ai-dlc/validate-provenance-block.sh --strays > /tmp/str.txt 2>&1; echo "rc=$?"
tail -2 /tmp/str.txt
```

**EXPECTED, measured 2026-07-30 against `18e00ef40` [V]:**

| Tally | Expected | Stop condition |
|---|---|---|
| `validate-layer-entries` | exit **0**, `0 error(s), 5 warning(s)`, **5** `OUT OF BAND`: checks 33/34/35 + rules 31/32 | a 6th, or a different subject |
| `validate-gate-manifest` | exit **1**. `UNLOADABLE: 19b 2s 33 35`; `MISSING none`; `ORPHAN none`; `manifest source: core`; `extension gate_types: 34->implementation`; `manifest ids: 42 anchors: 42` | any `MISSING`/`ORPHAN` row, or `manifest source` not `core` |
| `validate-fixture-drivability` | exit **0**, `0 undeclared`. **114 fixture dirs [V]** — this brief deletes one, so expect 113 from row 4 on | any `undeclared`, at any point |
| `--strays` | exit **0**, PASS | any FAIL. **Do NOT widen `party_mode_homes` to make it pass** |

**Record all four verbatim.** Rows 2–5 are measured as deltas against them, and the row-7 exit
condition is stated in these numbers.

**Tick row 1** with the four tallies and the three shasums.

---

### Row 2 — excise checks 34/33/35 and the `gate_types:` line. In `graph`.

**This row contains the one measured wedge in the brief. Read §4 items 1–3 before touching the file.**

Target: `.claude/skills/ai-dlc/extensions/checks/gate-validation-domain.md`, **914 lines**.

**2a. The block is contiguous at the tail, but the headings are NOT in numeric order.** They run
**34 (787), 33 (862), 35 (872)**. Slicing "33 through 35" by number cuts the wrong range and leaves
check 34 in the file. Delete **lines 784–914**, where 784 is the blank line above the `## Check 34`
section marker and 914 is EOF. The file ends after line 783, which is check 32's closing sentence
(*"…retired-in-place (not reused) to preserve cross-reference stability."*).

**Verify the boundary before deleting, not after:**

```bash
sed -n '783p;784p;785p' .claude/skills/ai-dlc/extensions/checks/gate-validation-domain.md
# EXPECT: the check-32 sentence, a blank line, then '## Check 34'
```

**2b. Delete the frontmatter line `gate_types: implementation`. NOT OPTIONAL — skipping it WEDGES.**

Check 34's `<!-- CHECK_LOADED: 34 -->` at line 788 is the **only** anchor in the entire
`extensions/checks/` tree **[V]**. Remove the block and leave the declaration, and
`validate-gate-manifest.sh` exits **2**:

```
validate-gate-manifest: FAIL — a gate_types: declaration cannot load:
    extensions/checks/gate-validation-domain.md: declares gate_types: implementation and
    carries no '<!-- CHECK_LOADED: <id> -->' anchor. There is no check id to put in a row,
    so the declaration claims loading for nothing.
```

**`extension gate_types:` returning to `none` is CORRECT and is not a regression of the 0.213.0
pull's row 3b.** That row's gain was `manifest source: core` — it retired the override that was
shadowing core's manifest — and this edit does not touch it. The `34->implementation` mapping existed
only to claim check 34.

**Verify, both validators:**

```bash
bash scripts/ai-dlc/validate-gate-manifest.sh \
     .claude/skills/ai-dlc/steps/gate-validation.md 2>&1 | \
     grep -E 'UNLOADABLE|MISSING|ORPHAN|manifest source|gate_types'
#   EXPECT exit 1 (NOT 2): UNLOADABLE = 19b 2s ; MISSING none ; ORPHAN none
#                          manifest source: core ; extension gate_types: none
bash scripts/ai-dlc/validate-layer-entries.sh . 2>&1 | tail -1
#   EXPECT exit 0: 0 error(s), 2 warning(s)   -- rules 31/32 only
```

**Both measured on a clone of `18e00ef40` during row 4's authoring pass [V].** Exit **2** here is the
wedge, not a finding: it means 2b was skipped.

**STOP CONDITION:** any `MISSING` or `ORPHAN` row, or `manifest source` no longer `core`. That means
the tree moved and this instruction is stale — **do not re-author the block to make it pass.**

**Tick row 2** with the line count removed, the `UNLOADABLE` line, and the warning count.

---

### Row 3 — subject 1: retire the script, PRESERVE the schedule. In `graph`.

**Row 3 of the plan measured `check-protected-core-paths.sh` (162 lines) against
`core-paths.sh --audit-diff` on a PASS case and a real FAIL case and got identical verdicts naming
the same commit and the same paths, with core strictly better on the arm that differs [V].** The
script is a duplicate. Delete it.

**What is NOT a duplicate is when it fires.** Core's check fires at the **retro/close** gate; graph's
Check 34 fires at **gate-1, for every story**, and core's `team-roles/` carry no protected-core-path
pre-flight at all **[V, §4 item 6]**. Row 2 deleted the check. **The gate-1 schedule now lives or
dies in three role-file lines, and this row is what keeps it alive.**

**3a. Delete the script.**

```bash
git rm scripts/check-protected-core-paths.sh    # 162 lines
```

**3b. Repoint the three role lines. One at a time, and read each line before rewriting it** — they
are 625–914 characters each and each states its own REJECT/STOP criterion in its own voice.

| File | Line | Role's own framing |
|---|---|---|
| `.claude/skills/ai-dlc/extensions/roles/code-reviewer-domain.md` | 41 | mandatory severity; a FAIL is a Critical finding |
| `.claude/skills/ai-dlc/extensions/roles/dev-domain.md` | 15 | before claiming gate-1 done; STOP, do not submit |
| `.claude/skills/ai-dlc/extensions/roles/qa-domain.md` | 17 | REJECT criterion; independently run |

Each carries `scripts/check-protected-core-paths.sh <base-ref>`. Replace with:

```
scripts/ai-dlc/core-paths.sh --audit-diff <base-ref> HEAD
```

**Carry core's exit contract into each line, or the repoint is INERT.** The consumer script was
`0`/`1`. Core's `--audit-diff` is three-valued, and the third value is the one a role that reads
"non-zero means stop" will get wrong:

- **`0`** = no core path touched in range, **or** every touching commit is a recognized
  `chore(ai-dlc-update):` reconcile, **or** an operator-authorization citation is present, **or the
  tree is DORMANT.**
- **`1`** = a core path touched by a non-reconcile commit with no citation.
- **`2`** = the core set could not be resolved, so nothing was classified. **Fail-closed. Not a
  pass.**

**Two things each rewritten line must still say**, because both are live escape hatches core states
in its own header and the roles already gesture at the first:

- **`PASS (with citation)` reports only that a citation exists, never that it covers these touches.**
  `docs/escalations/pending.md` accumulates — **8 `Operator authorization:` lines at `HEAD` [V]** —
  and the existing role text already makes confirming relevance the reviewer's job. Keep that
  sentence; it is now more load-bearing, not less.
- **`DORMANT` is not a pass.** It means the activation rule did not hold at `<base-ref>` — a
  `.claude/.ai-dlc-version` stamp plus the `overrides/` and `extensions/` layer dirs. graph is
  layered, so a `DORMANT` line here means the base ref is wrong, not that the tree is clean.

**3c. Verify the repoint fires, with the control that makes it a flip and not a citation.**

```bash
# the mode resolves and runs, against a real range on this tree
bash scripts/ai-dlc/core-paths.sh --audit-diff <sprint-base> HEAD; echo "rc=$?"
# CONTROL that the deleted script is gone from every live site:
git grep -n 'check-protected-core-paths' -- ':(exclude)_bmad-output' ':(exclude)docs'
#   EXPECT: NO output, rc=1
# CONTROL that the same probe shape still finds something:
git grep -ln 'core-paths.sh' -- ':(exclude)_bmad-output' ':(exclude)docs' | wc -l
#   EXPECT: non-zero, and the three role files among them
```

The second control is the load-bearing one. A bare zero from the first grep measures the scope of
your pathspec, not the absence of a site — **which is exactly how row 3 of the plan shipped a
"wired into nothing" claim that its own execution then falsified** (the subject was wired at
`.pre-commit-config.yaml:30`, a haystack the grep never named).

**Historical mentions under `_bmad-output/` and `docs/` are excluded deliberately and must NOT be
rewritten.** They are dated gate logs, verdict files, retros and reviews recording what was run at
the time. Rewriting one falsifies a measurement. Core applies the same carve-out to its own
`CHANGELOG.md` and `docs/reviews/`.

**Tick row 3** with the grep count for the old token (**0** in live paths) and its control's non-zero.

---

### Row 4 — subject 2: retire the detector, its test, and its fixture. In `graph`.

**Row 3 of the plan measured `check-mutation-red-anchor.sh` (72 lines) against
`validate-mutation-red.sh` across Check 35's own three declared arms plus three more, and core is a
strict superset [V].** The decisive case is a real defect in the consumer copy:

> **A replacement line containing `@` — consumer exit 1, core exit 0.** The consumer's rewrite is
> `sed "<n>s@.*@<repl>@"`, so an `@` in the replacement breaks the expression, **the file is never
> mutated, the test stays GREEN, and the consumer reports "claimed anchor is unproven" against a test
> that was never put under test.** Core mutates correctly and returns PROVEN.

Unlike subject 1, **nothing needs preserving**: core's own role files carry the mandate at
`code-reviewer.md:418`, `dev.md:201`, `qa.md:79` **[V]**, and the 0.213.0 pull already merged that
replay text into graph's `dev.md` and `qa.md`.

**4a. Delete three things.** All are the consumer's duplicate of machinery core now ships:

```bash
git rm scripts/check-mutation-red-anchor.sh                        #  72 lines
git rm scripts/tests/test-s291-3-check35-mutation-red.sh           #  87 lines
git rm -r tests/fixtures/check-35-mutation-red-reachability/       #  62 lines (README+run.sh+seed.sh)
```

**The test and the fixture go with the detector because they test the detector, and core ships its
own replacements which are already installed [V]:** `tests/fixtures/mutation-red-replay/` with
`run.sh` + `seed.sh`, already driven by `.githooks/pre-push`'s generic `for d in tests/fixtures/*/`
loop. Keeping graph's pair would leave a fixture asserting the behaviour of a script that no longer
exists — a red fixture, not a retirement.

**4b. Note the exit-contract widening, and check no caller depends on the narrow one.** Core adds
**exit 2 (UNEVALUABLE — nothing was tested)** and **exit 3 (HARD — the restore did not come back
byte-identical; THE TREE IS LEFT MUTATED)**. A caller written `if script; then PASS else FAIL` is
safe on 2 but **exit 3 needs an operator-visible path, not a FAIL line** — a mutated working tree
that reads as a failing gate is how a mutation gets committed.

Row 2 already deleted Check 35, which was the only place graph mandated the detector. Confirm:

```bash
git grep -n 'check-mutation-red-anchor' -- ':(exclude)_bmad-output' ':(exclude)docs'
#   EXPECT: NO output, rc=1
git grep -ln 'validate-mutation-red' -- ':(exclude)_bmad-output' ':(exclude)docs' | wc -l
#   CONTROL: EXPECT non-zero -- core's role files and its fixture
```

**4c. Re-run the drivability floor, because you just deleted a fixture directory.**

```bash
bash scripts/ai-dlc/validate-fixture-drivability.sh --dir tests/fixtures 2>&1 | head -3
#   EXPECT exit 0, `0 undeclared`, and 113 directories (row 1 baseline was 114)
#   --quiet is FORBIDDEN here: it swallows the "nothing to judge" sentence (§4)
```

**STOP CONDITION:** any `undeclared`. A deletion cannot create one; if it did, the directory count
moved for a reason you have not accounted for.

**Tick row 4** with the fixture-dir count (**113**) and both grep results with their controls.

⏹ **FRESH GRAPH SESSION.** Report rows 2–4 as deltas against row 1's four baselines: expect
`OUT OF BAND` **5 → 2**, `UNLOADABLE` **4 → 2**, fixture dirs **114 → 113**, `--strays` still PASS.
**If any of those four moved differently, stop and open an ai-dlc session before row 5.** This is the
last point at which the change is small enough to read in one sitting.

---

### Row 5 — subject 3: the PARTIAL. In `graph`. **Its own graph session.**

**This is the row most likely to be done wrong rather than left undone, and it is the only row here
that is a per-item judgement.** Row 3 of the plan verified the stray arm is drop-in — the same real
party-mode block planted at **nine home boundaries, 9 of 9 agreeing**, plus a whole-tree scan, two
crafted stray fixtures and two controls **[V]**. Core's resolved home set is printed in its own FAIL
message and is **identical to the consumer's six**.

**But the script SURVIVES.** `--fixture-provenance` is **not absorbed by anything** and is out of
scope per the predecessor's §9. **Deleting the whole script deletes an unreplaced capability** and is
the failure mode this row exists to prevent.

**5a. Excise the stray arm only.** `scripts/scan-stray-provenance.sh` is 155 lines:

| Lines | Contents | Disposition |
|---|---|---|
| 1–57 | header + usage, documenting **both** modes | trim to the surviving mode |
| 58–89 | `--fixture-provenance` (S241-5 AC4) | **KEEP, unchanged** |
| 90–155 | the stray scan body | **EXCISE** |

**Row 3's "~110 of 155" over-counts** — it charged the shared 57-line header entirely to the stray
arm **[V, §4 item 4]**. The stray body is **66 lines**. **Report what you actually removed; do not
carry 110 forward as a target.** A row that hits a line target by trimming a header nobody asked
about has optimised the number, not the duplication.

**5b. Repoint Check 17's stray arm — one arm only.** `gate-validation-domain.md` lines **102** and
**110** name `scan-stray-provenance.sh`. Replace the invocation with:

```
scripts/ai-dlc/validate-provenance-block.sh --strays
```

**Leave the rest of Check 17 alone.** Its retro/PRD/story-readiness provenance arms and the replay
harness are untouched by this brief — `retro-replay-harness.sh` came back **REFUTED** (row 6 files
it), so the sentence naming it stays exactly as it is.

**And fix the home under-declaration while you are in there [V].** Check 17's prose names **five**
homes — `docs/retro/**`, `docs/reviews/**`, `docs/architecture.md`, `_bmad-output/**`,
`scripts/tests/**` — and **both implementations carry six**. `docs/architecture-history.md` appears
**0 times in the whole 914-line file** (control: `architecture.md` appears once in the same span).
Add it. **A party-mode block in `architecture-history.md` is legitimate to both scanners and a stray
by the check that governs them**, which is a live contradiction, not a typo.

**5c. Repoint the two `pr-class.sh` entries.** Row 3 named `:163`; **there is also `:89` [V]**.

- **`:163`** — `EXPECTED_VALIDATORS="scan-stray-provenance.sh"`. This is the AF-2 forged-block floor
  for the `provenance-in-non-retro` PR class. Repoint to the core validator.
- **`:89`** — `'^scripts/scan-stray-provenance\.sh$'` in a path allowlist. **The script still exists**
  (it keeps `--fixture-provenance`), so **decide deliberately whether this entry stays.** Read what
  the allowlist governs before touching it; it is not a duplicate-enforcement site.

**5d. The three tests that drive the stray arm — a per-item judgement each, and this is the hazard.**

| Test | Which arm | Note |
|---|---|---|
| `scripts/tests/test-pr-class-provenance-in-non-retro.sh` | stray (B1/B2, explicit path) | live; asserts FAIL on a forged block and PASS on a legitimate one |
| `scripts/tests/test-scan-stray-legit-homes.sh` | stray (legit homes) | **exists only to test this arm** |
| `scripts/tests/test-s239-1-hardening.sh` | stray (arms 1/3) | **already RED and run by nothing [V]** — 5 of 15 assertions fail `rc=127` on paths that moved under `scripts/ai-dlc/` |
| `scripts/tests/test-s241-5-ac4-provenance-secret.sh` | `--fixture-provenance` | **DO NOT TOUCH.** Sole live caller of the surviving arm |

**The fast route is to delete all three stray tests. Do not.** Two of them assert real behaviour that
must survive the repoint, and the correct move is to repoint them at
`validate-provenance-block.sh --strays` and **run them**. The third
(`test-s239-1-hardening.sh`) is already broken for an unrelated reason and repointing it will not make
it green — **surface it, do not fix it here**; its stale paths are row 6 material.

**Fixture prose also names the script** — `tests/fixtures/provenance-in-non-retro/README.md`,
its two fixture files, and `tests/fixtures/retro-replay/ac3a/arm1`/`arm3`. These are **evidence an
LLM reads at a gate**, so a sentence naming a scanner that no longer performs that scan becomes a
false statement. Update the ones describing the stray check; leave anything describing
`--fixture-provenance`.

**5e. Verify — the floor must not move.**

```bash
bash scripts/ai-dlc/validate-provenance-block.sh --strays > /tmp/str2.txt 2>&1; echo "rc=$?"
tail -2 /tmp/str2.txt
#   EXPECT exit 0, PASS -- identical to row 1's baseline

# CONTROL that the PASS is a flip and not a vacuous scan:
AI_DLC_KNOWN_SKILLS_EXT="" bash scripts/ai-dlc/validate-provenance-block.sh --strays; echo "rc=$?"
#   EXPECT exit 1, FAIL with 5 findings, ALL under scripts/tests/**
#   A 6th, or one outside that prefix: STOP. Do NOT widen party_mode_homes.

# the surviving arm still works:
bash scripts/tests/test-s241-5-ac4-provenance-secret.sh; echo "rc=$?"
```

**STOP CONDITION:** `--strays` no longer PASSes, or the control no longer FAILs with exactly 5. The
first means the excision broke something; **the second means the check has gone vacuous and a PASS
now proves nothing** — which is this repo's named defect class and is worse than a red gate.

**Tick row 5** with the lines removed from the script, the repointed site count, and both halves of
the `--strays` flip.

⏹ **FRESH GRAPH SESSION.** Row 5 is per-item judgement across three tests and five fixture files; it
does not share a context with row 6.

---

### Row 6 — file the three REFUTED subjects. In `graph`.

**§4 of the plan makes recording a refutation the row's deliverable, and its stated reason is that a
refutation not written down gets re-proposed.** These are not tasks deferred; they are measurements
that say **do not build it**. File each in
`_bmad-output/ai-dlc-update/push-candidate-ledger.md` with a `verify:` receipt, because graph's
`ledger-reverify.sh` re-tests every receipt on every pull **[V — 53 rows today]** and a PR-body
checkbox does not.

**6a. `retro-replay-harness.sh` (97 lines) — REFUTED, disjoint predicate.** The harness replays
retro-merge validator fixtures and asserts deny-reason tokens against `defect-manifest.txt`;
`validate-fixture-drivability.sh` asserts every fixture dir has a `run.sh` or a declared exemption.
**Two mutants on the same tree, each failing only its own assertion [V]** — the KISS mutant test for
entanglement. **The 97 lines are not retirable.**

**What IS retirable, and file it as such:** `scripts/ci-local.sh:1336-1342`'s hand-listed
`paths_match` trigger is a duplicate **invocation** (not a duplicate predicate) — `run.sh` already
delegates to the harness and `.githooks/pre-push:160-170`'s generic loop drives it on every push. It
is reachable only from a manual `bash scripts/ci-local.sh`, because **the installed pre-push hook
does not call `ci-local.sh` at all** (control: it invokes 8 other `bash scripts/` targets) **[V]**.

**6b. `generate-sprint-status.py` (1068 lines) — REFUTED, coverage gap.** The consumer compares **5
fields across 10 comparisons**; core's `sprint-status.sh check-stories` compares **`status` alone, 2
comparisons**. Three mutants against the live `sprint-status.yaml`: corrupting `status` → both FAIL;
corrupting `priority` → **consumer 1, core 0**; corrupting `gate_1_model` → **consumer 1, core 0**
**[V]**. Core covers **one of five fields in one of five modes**. **Its wiring surface is 43 files —
larger than the other five subjects combined — and it does not enter this brief.**

**6c. `validate-no-direct-main-push.sh` (46 lines) — REFUTED, and the "free win" was false.** Core's
`--trunk-push` **passes the decisive FAIL case by design**: the real merge `e3522f153` pushed direct
to `refs/heads/main` gives **consumer 1, core 0** **[V]**. Core's own header says why — *"It bounds
that commit; it does not police the trunk."*

**File the finding underneath it, which is the part that matters:** the script is wired at
`.pre-commit-config.yaml:30` (`id: no-direct-main-push`, `stages: [pre-push]`) — **not "wired into
nothing"** — but it is **dormant in every clone**, because `.git/hooks/pre-push` `exec`s
`.githooks/pre-push`, which never reaches the pre-commit framework, and `pre-commit` is installed
`--hook-type=pre-commit` only. graph's own
`overrides/steps__retro__ci-gates-enforcement-surface.md:49` records that this is **deliberate** —
installing the pre-push hook type "would REJECT EVERY PUSH" while `ci-local.sh` exits 1.

> **Net: graph today has no enforcement of "no direct push to `main`" at all.** The consumer's guard
> cannot fire and core's arm declines the question by design. **File this as a finding.** Deleting
> the script is defensible; deleting it *as a free win with zero coupling* is not, and the
> `.pre-commit-config.yaml` entry must go with it if it goes.

**6d. Also file the two dead drivers row 5 surfaced** — `test-s239-1-hardening.sh`'s `rc=127` stale
paths, and the `--fixture-provenance` arm whose only caller is its own test, which nothing drives.

**No apostrophes in any `verify:` receipt.** `ledger-reverify.sh`'s awk program is a single-quoted
shell string; a possessive breaks the parse, and it has broken it before.

**Write receipts against the FIX, never against a citation.** The recorded trap: v0.181.0 wrote an
entry as absorbed in core's CHANGELOG *and* in a comment inside `ledger-reverify.sh` — **a citation
read as a fix** — and the entry's real subject stayed live for three more releases.

**Tick row 6** with the entry ids filed and `ledger-reverify.sh`'s row count before and after.

---

### Row 7 — verify, commit, push, PR, merge. Then UNFREEZE. In `graph`.

**7a. The four baselines, as a reported delta.** Re-run row 1's four commands and report both numbers:

| Tally | Row 1 baseline | Expected now |
|---|---|---|
| `OUT OF BAND` warnings | **5** (checks 33/34/35, rules 31/32) | **2** (rules 31/32) |
| `UNLOADABLE` | **4** (`19b 2s 33 35`) | **2** (`19b 2s`) |
| fixture directories | **114**, `0 undeclared` | **113**, `0 undeclared` |
| `--strays` | exit **0**, PASS | exit **0**, PASS — **plus the `AI_DLC_KNOWN_SKILLS_EXT=""` control still FAILing with exactly 5** |

**A PASS with no control is not evidence here.** Three of the four tallies above go DOWN by design,
and a validator that has stopped running also reports a lower number.

**7b. The net-surface tally — §3 criterion 2 of the plan, and it is REPORTED, not targeted.**

```bash
git diff --stat main...HEAD | tail -1
```

**Report `+added / −removed` verbatim.** The plan's criterion is that consumer surface goes **down**,
and **a row that adds surface states why — "the gate demanded it" is a reason to question the gate.**

Rough expectation from row 4's authoring measurements, **as an order of magnitude and not a target**:
`gate-validation-domain.md` −132, `check-protected-core-paths.sh` −162,
`check-mutation-red-anchor.sh` −72, its test −87, its fixture −62, the stray arm −66 and some header,
against ~10 rewritten lines in the three role files, Check 17 and `pr-class.sh`, plus row 6's ledger
additions. **If your measured removal is far below this, something did not get deleted. If it is far
above, something got deleted that should not have.**

**7c. The falsifiability probe — §3 criterion 4, and this is what makes it a retirement rather than a
deletion.** Each retired subject needs a probe **a later pull re-runs**. Row 6's ledger receipts are
the mechanism: `ledger-reverify.sh` executes them on every pull. File one receipt per retirement
asserting the duplicate **stays** gone — a `git grep` returning 0 in live paths **with its control**,
not a bare zero. A receipt that cannot fail is the same defect as a check that cannot fire.

**7d. Push in the background.** graph's pre-push runs its whole fixture suite; a foreground push hits
the tool timeout.

```bash
( git push -u origin <branch> > /tmp/push.log 2>&1; echo "PUSH_RC=$?" >> /tmp/push.log ) &
# poll for PUSH_RC, then verify by ls-remote -- NEVER by a piped exit code:
git ls-remote --heads origin <branch>
```

**If the pre-push refuses, read which gate. The remedy is the finding — never `--no-verify`.**

**One known-flaky class:** `layer-readopt-gate` and `apply-drift-refile` have each gone red once
under a parallel suite and green on every rerun; the shared factor is the runner. A re-push is
correct **only after showing the change cannot reach the fixture** — grep every file this branch
touched against it, with a control proving the grep matches something.

**Pre-existing `ci-local.sh` red, measured during the 0.213.0 pull [V], do not fix here:**
`server-fixture-manifest` fails identically at the branch point, and **shellcheck is already red on
`main`** — 118 findings across 45 files, 3 error-level. Confirm they predate the branch and say so in
the PR. Note that the 0.213.0 handoff's own "four pre-existing shellcheck failures" figure **did not
reproduce**; do not carry it forward.

**7e. The PR body carries** row 1's four baselines, row 7a's four deltas, the net `+/−` tally, the
per-subject verdicts from row 3 of the plan (**2 RETIRE / 1 PARTIAL / 3 REFUTED**), and the row-6
entry ids as explicit follow-ups.

**7f. Tick row 7 with the merge sha, the `+added / −removed` tally, and the post-merge `W5` and
`UNLOADABLE` counts. Then UNFREEZE, and say so explicitly in the tick — an unfreeze nobody records is
a freeze that never ends.**

**The exit condition is the plan's four §3 criteria, stated as measurements:**

1. **Duplicate enforcement paths = 0** for subjects 1, 2 and subject 3's stray arm — measured by the
   live-path greps with their controls, never by citation.
2. **Net consumer surface goes DOWN** — reported as `+added / −removed`.
3. **`W5` 5 → 2 and `UNLOADABLE` 4 → 2**, with the two survivors of each dispositioned in writing
   (they are: rules 31/32 want a crosswalk row; `19b`/`2s` want an anchor plus `gate_types:`).
4. **Each retirement is falsifiable** — a receipt `ledger-reverify.sh` re-runs on every pull.

---

## 7. Known-open, deliberately out of scope

Recorded so a later session does not re-open them as defects. Each is a real gap with a stated reason
for not closing it here.

- **The three REFUTED subjects stay.** `retro-replay-harness.sh`, `generate-sprint-status.py` and
  `validate-no-direct-main-push.sh` are **1,211 of the 1,600 lines** the plan's §2 tabulated as owed.
  They are not absorbed by anything, and §2's "0 lines retired" framing implied all 1,600 were.
- **graph has no "no direct push to `main`" enforcement at all** (row 6c). Filed, not fixed —
  fixing it means making `ci-local.sh` exit 0 first, which is a sprint, not a retirement.
- **`--fixture-provenance` survives with one caller, its own test, which nothing drives.** Keeping a
  32-line arm nothing runs is a consumer decision this brief deliberately does not make.
- **`Check AP` and `Check VH` remain outside the numeric heading grammar** and appear in no tally
  here. Widening it is bound to `relabel-extension-checks.sh` by **I34**, whose false-positive set is
  unmeasured. Their absence from every count in this file is **not** evidence they load.
- **The `gate_types:` declaration this brief removes is what `19b` and `2s` still want.** Row 2
  removes it because the file has no anchored check left, not because the mechanism is wrong. Do not
  read row 2 as a precedent for dropping `gate_types:` elsewhere.
- **The entry-cost payoff argument does not survive measurement, and this brief does not claim it.**
  `gate-validation-domain.md` is named in 13 of 78 reconcile logs, but **Check 34 in only 2 of the 39
  logs postdating it and Check 35 in 0 of 28** (controls: universal token 78/78, bogus token 0/78)
  **[V]**. The retirement **costs one guaranteed re-adjudication** of the entry at the next pull and
  **saves an expected ≈ 0.05 adjudications per pull.** The payoff is §3 criteria 1 and 3 — two
  implementations of one predicate cannot disagree at a gate if only one exists. **It is not
  adjudication load, and the PR must not say it is.**
- **Every edit here changes the entry's digest and re-opens its adjudication at the next pull.** That
  is priced in and is the correct cost of the change, not a defect to route around.
