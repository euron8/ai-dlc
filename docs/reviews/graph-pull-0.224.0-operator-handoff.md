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
| 1 | Pre-flight: clean tree, pin the engine, confirm graph has not moved under this file | graph | ✅ 2026-07-31 — HEAD `9b5d408a3` (unmoved, so the layer-diff check was not needed), 4 dirty files all under `_bmad-output/`, stamp `0.214.0`/`04cea81`, pre-push shim 314 bytes; engine worktree `/tmp/pull-engine` @ `1f5e6cc`, VERSION `0.224.0` |
| 2 | Classify only. Report all five tallies. **Write nothing.** | graph | ✅ all five match [M]. (1) 59 rows, exit 0, 0 stderr — OK 35/12, ADJ-MISSING 3, HOOK-DRIFT 3, DOUBLE-SHADOW 2, DELEGATES 2, ASSERTS 2; control null span 38 EXT-OK / 0 hook-drift. (2) 3, all `HARD-LAYER-ADJUDICATION-MISSING`. (3) 66 rows: 46/12/3/3/2. (4) exit 0, `0 error(s), 2 warning(s)`. (5) exit 1, `103 error(s), 0 warning(s)`, `contract_version=7 entries=50 undeclared=50`, `unclaimed=E15,E16,E17`, split 49 E15 / 4 E16 / 50 E17. Anchor drift/missing **0 across a 10-entry `extends:` subject set** (control: 39 `kind:`). Note: graph's installed 0.214.0 validator emits **no** `LAYER_MEASURED` line at all (0 hits), so §4.11's pre-pull `unclaimed=` reading comes from the engine's validator at probe (5), not from `scripts/ai-dlc/`; the value itself reproduces |
| 3 | Record the **3** adjudications | graph | ✅ 3 records appended to `layer-adjudication-register.jsonl` (21 → 24 lines), clause **LC-E4** (derived: `EXTENSION-HOOK-DRIFT` is LC-E4's `code:` in the incoming contract; LC-E14 is the anchor twin). All three **still-additive**; digests copied verbatim from drift field 4 and all three reproduce the §6 table. VERIFY **0 / 3 / 0** (present / aside / restored) |
| ⏹ | **FRESH GRAPH SESSION** if row 3 took real reading; otherwise carry on | graph | ⏹ **STOPPED HERE 2026-07-31.** Row 3 took real reading (core `SKILL.md` span diff, all 3 entry files, 5 probes). Next session resumes at **row 4**. Engine worktree `/tmp/pull-engine` @ `1f5e6cc` is still pinned — re-`cat` its `VERSION` before trusting it |
| 4 | `apply` on ONE branch | graph | ✅ branch `chore/ai-dlc-update-0.224.0` off `9b5d408a3`; `apply.sh` **exit 0**, **0 bytes stderr**, **26 RESOLVED / 3 WORKLIST / 0 DECISION**. All 3 WORKLIST are `extension-reread` on exactly the row-3 trio (`party-mode-inline-relay.md`, `SKILL-domain.md`, `SKILL-push.md`). Final lines reproduce verbatim (`relabel` / `restamp 04cea81 -> 1f5e6cc` / `consistent … fixture suite re-enabled`). Changed paths **21 = 18 M + 3 untracked** (the 18th M is row 3's register; the 4 other dirty `_bmad-output/` runtime files pre-date row 1 and are excluded) |
| 5 | Post-apply verification **+ advance the machinery stamp** | graph | ✅ §4.10 reproduced verbatim (`0.224.0`/`1f5e6cc` + `skill_*` still `0.214.0`/`04cea81`), `contract_version: 9`. `skill_version`/`skill_commit` advanced to **0.224.0 / 1f5e6cc**, `installed_at` and `upstream` preserved. Three `IDENTICAL` + `control ok (CLAUDE.md forks)`. Wedge is RED as expected: exit **1**, `103 error(s), 0 warning(s)`, footer `contract_version=9 entries=50 at_current=0 behind=0 undeclared=50`, **`unclaimed=none`** (§4.11 flip confirmed — read `E15,E16,E17` at row 2), split **49 E15 / 4 E16 / 50 E17**. ⚠ **HANDOFF PATH DEFECT, not a tally deviation:** row 5 names `scripts/ai-dlc/self-update-gate.sh` — that file does not exist in graph (exit 127). The script is at `.claude/skills/ai-dlc-update/reconcile/self-update-gate.sh` (byte-`IDENTICAL` to the engine's), usage `<dist> <base> <theirs> <consumer>`. Run correctly it returns **`SELF-UPDATE-DEFER`** as stated, over one `SELF-UPDATE-UNDECIDED` row (post-apply, current and incoming `validate-layer-entries.sh` are the same copy, so both exit 1 and the failure is unattributable by construction). Verdict matched, so no ai-dlc session opened |
| ⏹ | **FRESH GRAPH SESSION** — the migration is its own context | graph | ⏹ **STOPPED HERE 2026-07-31.** Rows 4–5 done on branch `chore/ai-dlc-update-0.224.0` (uncommitted working tree — the branch carries the apply + the stamp advance and is NOT yet committed; row 9 commits). Next session resumes at **row 6**, the 49 renames. Engine worktree `/tmp/pull-engine` @ `1f5e6cc` still pinned — re-`cat` its `VERSION` before trusting it. Row 6 reads `E15` from graph's now-installed validator, which is live and red at 103 |
| 6 | The migration, part 1: the **49** renames | graph | ✅ 2026-07-31 — **49 ids cleared, 0 MISS**. Routes per decision 4: **46 band-id renames** (script-applied, every edit `cmp -s`-guarded, `applied=46 missed=0`) + **3 qualifier** (`retro-deferral-expiry.md`'s `4a-bis`/`4a-ter`/`4a-quater` → `kind: qualifier` + existing `extends: '#4a. Close-Out Sweep'` + `position: append`; the three headings drop their ids for `### [ext:retro-deferral-expiry] …`, which matches neither `CHECK_HEAD_RE` arm, so they allocate nothing). §4.5 trap cleared — `AP`/`VH` edited as `## Check XAP —` / `## Check XVH —` (no trailing dot), 1 line each, `cmp` confirmed non-identical. Verify: **E15 0**, **E16 20**, **E17 50**, **W3 4**, exit 1, 0 stderr, footer `contract_version=9 entries=50 at_current=0 behind=0 undeclared=50 errors=70 warnings=4`. **CONTROL for the E15 zero:** reverting `## Check XVH —`→`## Check VH —` returns **1 E15**, restoring returns **0** — the arm is live, not blind. The qualifier route produced the SAME four tallies the rehearsal measured under the all-rename route; `E10`/`E11`/`E12` all read `0/38`, so the conversion is contract-clean. Row 8's inputs confirmed: 20 E16 rows over exactly the predicted 19 distinct ids (incl. `4a-bis`/`4a-ter`/`4a-quater` — the crosswalk obligation is identical on either route), and the 4 W3 are exactly the predicted pairs |
| ⏹ | **FRESH GRAPH SESSION** — row 6 carried the judgement; row 7 is 50 more edits | graph | ⏹ **STOPPED HERE 2026-07-31.** Rows 6 and **8c** done (8c pulled forward at operator direction — the citation trap was found while reporting row 6 and left unresolved would have shipped). Next session resumes at **row 7**, then row 8. **The branch `chore/ai-dlc-update-0.224.0` is still UNCOMMITTED** — it carries the apply, the stamp advance, the 49 renames and the 20 citation realignments in the working tree; row 9 commits all of it. Engine worktree `/tmp/pull-engine` @ `1f5e6cc` still pinned — re-`cat` its `VERSION` before trusting it. Current validator reading, which row 7 starts from: **exit 1, `70 error(s), 4 warning(s)`**, E16 20 / E17 50 / W3 4 |
| 7 | The migration, part 2: `conforms_to: 9` on all **50** entries | graph | ✅ 2026-07-31 — **applied=50 missed=0 badread=0**. Value `9` read from the installed `layer-contract.yaml`, not transcribed. Subject list taken verbatim from the validator's own 50 `E17` lines. Every insert anchored to the CLOSING `---` of a line-1 frontmatter block, `cmp -s`-guarded, and read back through the validator's own `fm()` semantics. **Guard proven live before the real run:** a control list of three malformed inputs (no frontmatter / unclosed frontmatter / absent file) returned `applied=0 missed=3`. Verify: exit 1, 0 stderr, `20 error(s), 4 warning(s)`, footer `contract_version=9 entries=50 at_current=50 behind=0 undeclared=0` — E17 **50 → 0**, E16 20 and W3 4 both byte-unchanged (row 8's work). **CONTROL for the E17 zero:** deleting the `conforms_to` line from `validator-honesty.md` returns **1 E17**, restoring returns **0** — the arm is live, not blind. Diff surface: exactly **50** `+conforms_to: 9` additions tree-wide, **0** removals, **0** outside `extensions/`+`overrides/`. No `W6` — nothing declared behind |
| 8 | The migration, part 3: **19** crosswalk rows + the **4** reference repairs | graph | ✅ 2026-07-31 — **19 crosswalk rows added, 5 reference repairs applied, 0 MISS.** Obligations derived from the validator (`grep '^ERROR  E16'`), never by hand: **20 rows over 19 distinct ids**, exactly as predicted, `5e` claimed by both `retro-domain.md` and `retro-gate-log-rotation.md` and cleared by one row. Column 1 written namespaced where the matcher accepts it (`Check N` / `Rule N`) and **bare for the 11 step-section ids**, because `grep -Fxq` at L1259–1261 accepts only bare / `Check N` / `Rule N` — there is no `Step N` arm, so `Step 0b` in column 1 would have matched nothing; the namespace is carried in the title instead and the choice is stated in the row's `notes`. **Four ids carry no successor and none was invented:** `Check 33`/`34`/`35` deleted by `39f0248f` 2026-07-30 (34 absorbed by core `core-paths.sh --audit-diff`, 35 by `validate-mutation-red.sh`, per that commit's own body), and `5d` "Pre-Commit Validation Gate" dropped by `7bf089d1` 2026-07-08. Verified absent from the live layer with a live control (same pattern for `915` returns 2 hits). **Three carry no successor by ROUTE, not retirement** — `4a-bis`/`4a-ter`/`4a-quater` went the row-6 qualifier route, so their rows name the anchor (`extends: '#4a. Close-Out Sweep'`, cite by title under Step 4a) rather than a band id, per §6c-8b's "use the successor you actually chose". **8b was 5 edits over the 4 W3 subjects** — `gate-validation-domain.md` carries `Step 0b` twice (the `### 929.` heading text at :653 and the Scope line at :655); W3 reports once per file, so a 4-edit reading would have left one dangling. All line-anchored and `cmp -s`-guarded, `applied=5 missed=0`. **EXIT CONDITION MET: exit 0, `0 error(s), 0 warning(s)`, 0 stderr**, footer `contract_version=9 entries=50 at_current=50 behind=0 undeclared=0 errors=0 warnings=0`, census `fired=0 silent_with_subjects=22` — E16 **20 → 0**, W3 **4 → 0**. **BOTH CONTROLS, and B is the one that proves THIS row:** (A, prescribed) reverting `## Check XVH —`→`## Check VH —` returns **1**, restoring returns **0**; (B) deleting the `Check 34` crosswalk row returns **exit 1, 1 error, 1 `E16`**, restoring returns **0** — so the E16 arm is demonstrably reading the table this row wrote, which control A alone cannot show. Both files restored byte-`IDENTICAL` (`cmp -s`). Diff surface: 5 files, all under `extensions/`; **0** paths under `steps/`, `team-roles/`, `docs/retro/`, `docs/reviews/`, `docs/escalations/` |
| 8c | The migration, part 4: realign the **20** consumer-id citations in LIVE ROUTING DOCS (§6c-8c) | graph | ✅ 2026-07-31 — **20 realigned, 0 MISS**, executed early in the row-6 session at operator direction (independent of rows 7–8; touches no layer entry, so validator tallies are byte-unchanged: `70 error(s), 4 warning(s)`, E16 20 / E17 50 / W3 4 before AND after). `CLAUDE.md` 10, `docs/coding-conventions.md` 6, `docs/operator-runbooks/execution-health-onchain-verify.md` 4. Plus one pre-existing staleness in the same file (`Rule 1 through Rule 26`; core now defines through **Rule 30**) rewritten range-free, and a new **"Reading a numbered citation in this file"** block added to `CLAUDE.md` stating the band so the two namespaces are tellable apart without a path. **Deliberately NOT rewritten:** durable audit records and core-delivered files — see §6c-8c for the three-class rule and the evidence behind each |
| ⏹ | **FRESH GRAPH SESSION** | graph | ⏹ **STOPPED HERE 2026-07-31.** Rows 6, 7, 8 and 8c are all done — **the migration is complete and the layer reads `0 error(s), 0 warning(s)`, exit 0**. Next session resumes at **row 9**: verify, run the full pre-push, commit, push, PR, merge. **The branch `chore/ai-dlc-update-0.224.0` is still UNCOMMITTED** — the working tree carries the apply, the stamp advance, the 49 renames, the 50 `conforms_to` lines, the 19 crosswalk rows, the 5 reference repairs and the 20 citation realignments, and row 9 commits all of it in one commit. Engine worktree `/tmp/pull-engine` @ `1f5e6cc` still pinned — re-`cat` its `VERSION` before trusting it. Row 9 expects **78 files, not 75** (§6c-9: row 8c is additive to the rehearsal) |
| 9 | Verify `0 error(s), 0 warning(s)`, run the full pre-push, commit, push, PR, merge | graph | ✅ 2026-07-31 through PR — **merge is the operator's and is PENDING**. Commit `1ff00a1` on `chore/ai-dlc-update-0.224.0`, pushed, **PR #836** open. Diff **78 files, +3388/−431** — the 78 reproduces §6c-9 exactly (39 `extensions/`, 13 `overrides/`, 13 `tests/fixtures/`, 2 `scripts/ai-dlc/`, 3 `ai-dlc-update/`, stamp, contract, `SKILL.md`, `core-manifest.md`, register, + row 8c's 3 routing docs). **0** paths under `steps/`, `team-roles/`, `docs/retro/`, `docs/reviews/`, `docs/escalations/`. The 4 pre-existing `_bmad-output/` runtime files from row 1 were deliberately left UNCOMMITTED — including them would have made the count 82; they are operational state, not this branch's work. Final pre-push: **`pre-push: all gates green`, rc 0, 106 fixtures ok, 0 FAIL**, `116 / driven 106 / declared undrivable 10 / undeclared 0`. Push verified by `git ls-remote --heads` (local == remote == `1ff00a1`), never by a piped exit code. ⚠ **DEVIATION, resolved in graph — no ai-dlc session opened.** The FIRST push returned **rc 1**: layer gate clean, but `audit-rule-files.sh` FAILed at `--fail-on=deterministic` with **32 tier-1 findings (13 `ORIGIN_TAG` + 19 `EMBEDDED_DATE`), all 32 in the row-8 crosswalk table** at `extensions/README.md:267–285`. Judged graph-side on three measurements: `audit-rule-files.sh` is **not in the diff** (same instrument before and after); at `9b5d408a3` the table held one row whose column 4 read `(label adoption)` and the audit was clean, so the 19 new rows introduced every finding; and the remedy is in-subject. Fixed the subject, not the gate's scope — sprint tags backticked (`used()` blanks quoted spans *by design*: "a phrase inside backticks is being MENTIONED, not used", and a row reproducing a historical title is a mention by construction, which is why `label` was already backticked), and column 4 reduced to the event or sha (the table's own prose already says **"Do NOT try to resolve those by date"**). Audit **32 → 0** tier-1, layer byte-unchanged at 0/0. **BOTH ARMS CONTROLLED:** unwrapping one backtick returns **1 `ORIGIN_TAG`**, re-adding one date returns **1 `EMBEDDED_DATE`**, restore returns **0** each time, both files `cmp -s` IDENTICAL after. This also explains the +24-line README delta vs the rehearsal's `+3326/−408`: the rehearsal's rows were terser and date-free, which is why its `PREPUSH_RC=0` never surfaced this. New §7 candidate filed below |
| 10 | Report the acceptance-test inputs back for plan §6c-7 | graph | ✅ 2026-07-31 — **MERGED and reported. THE PROGRAM IS COMPLETE.** PR #836 squash-merged at operator approval; merge commit **`ff444f6`** on `main`. Squash reconciled **by content, not ancestry**: `git diff 1ff00a1 origin/main` = **0 lines**, control `git diff 9b5d408a3 origin/main` = **5909**, and `--is-ancestor` reads **FALSE** exactly as squash predicts (recording the FALSE so a later reader does not mistake it for an unmerged branch — plan D-6c1.1). **The three §6c-10 readings, taken post-merge on `main`:** (1) exit **0**, 0 stderr, `LAYER_CONFORMANCE v1 contract_version=9 entries=50 at_current=50 behind=0 undeclared=0 errors=0 warnings=0`, and `LAYER_MEASURED … codes=22 fired=0 silent_with_subjects=22 unclaimed=none subjects=override:12,extension:38`. (2) **10** entries declare `extends:`, control **39** declare `kind:`, control bogus key **0**. (3) HEAD `ff444f656ab744192530ed40b58541900220e383`. **THE ACCEPTANCE-TEST NUMBER §4.3 EXISTS FOR:** `EXTENSION-ANCHOR-DRIFT` = `E14=LC-E16:` **0/38**, i.e. **0 anchor drift across a 10-entry `extends:` subject set** — the first pull in this program where that zero has a non-empty subject set, in a span where the hooked file (`SKILL.md`) moved `+22/−9`. Previously 0 of 45 entries were anchored, which made every prior anchor-drift zero vacuous. **No deploy owed:** all 78 paths are `.claude/`, `tests/fixtures/`, `scripts/ai-dlc/`, `docs/` and `CLAUDE.md` — `server/`, `web/`, `rebalancer/`, `graph-node-src/`, `subgraph/` and `infra/` each read **0** against a control of 78 total, so `CLAUDE.md` Deployment Rule (c) does not fire |

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

### Row 8c — the migration, part 4: the citation trap OUTSIDE the layer. In `graph`.

**Why this row exists, and why no rehearsal row caught it.** Rows 6–8 are bounded by what the
validator can see, and the validator's subject set is the **50 layer entries** (`W3 = LC-R1: 4/50`).
`CLAUDE.md`, `docs/coding-conventions.md` and `docs/operator-runbooks/` are not entries, so a
consumer-id citation in them is invisible to every gate in this pull — it survives `0 error(s), 0
warning(s)` and a green pre-push. `CLAUDE.md` in particular is loaded into context on **every
session in this project**, so a stale pointer there misroutes future work rather than merely
recording a dead reference. §4.6's `W3` trap is this same defect at layer scope; this is its
out-of-layer half, and nothing joins the two.

**THE THREE-CLASS RULE. Apply it by CLASS, never file by file.**

| class | paths | action | why |
|---|---|---|---|
| **Durable audit record** | `_bmad-output/`, `docs/retro/`, `docs/reviews/`, `docs/escalations/`, `docs/ai-dlc-layer-adjudications/` | **NEVER rewrite** | Evidence of what was written at the time. Rewriting corrupts the audit record, and LC-N6's crosswalk (row 8) is the mechanism built for exactly these — that is the clause's whole stated rationale |
| **Core-delivered** | `.claude/skills/ai-dlc/steps/`, `SKILL.md`, **`.claude/team-roles/`** | **NEVER edit** (decision 5) | Unregistered core drift the next `apply` overwrites. `team-roles/` is core-delivered — verify with `ls /tmp/pull-engine/core/team-roles/`; it is easy to mistake for consumer-owned because `CLAUDE.md` lists it under Key References |
| **Live routing doc** | `CLAUDE.md`, `QUICKSTART.md`, `docs/coding-conventions.md`, `docs/operator-runbooks/` | **REALIGN** | These route FUTURE work. A stale pointer is an active defect, not a historical fact |

**ALIGN — do not remove the numbers and do not reduce to a subset.** After the band, a `9xx`/`X`
id is self-identifying as consumer-owned *by construction*, which is the property the whole
migration exists to create. Stripping the numbers to make the prose rename-proof would forfeit it,
and the band is a one-time TOTAL partition — consumer ids do not move again, so alignment carries
no recurring cost.

**THE TRAP INSIDE THE TRAP, and it is the reason this row cannot be a `sed`.** Core and the consumer
BOTH define 17, 24, 26, 28, 29, 30, 31 — that is what "ALREADY COLLIDED" meant in row 6. **A citation
must be classified by TITLE/INTENT, never by number.** The validator's own source states the
canonical example: core's 24 is *"The adversarial cycle CONVERGED"*, the consumer's is
*"Financial-display ground-truth live-verify"*. Measured on this tree:

| citation | resolves to | action |
|---|---|---|
| `team-roles/adversary.md` "Check 24 orders the pass series" | **core** (adversarial cycle) | leave |
| `docs/coding-conventions.md:1128` "deploy-validate Check 24 fails closed" | **consumer** (financial-display) | → `924` |
| `team-roles/qa.md:247`, `code-reviewer.md`, `gate-adjudicator.md` "Check 17" | **core** (skill-invocation provenance) | leave |
| `QUICKSTART.md:363` "gate-validation.md Check 14" | **core** (update pipeline snapshot) | leave |
| `QUICKSTART.md:72`, `coding-conventions.md:529` "SKILL.md Rule 13" | **core** (requirements define WHAT) | leave |
| `coding-conventions.md:1170` "orphaned-function gate … Check 30" | **consumer** (exact title match) | → `930` |

`19b` is the easy half — core defines no `19b`, so every citation of it is unambiguously the
consumer's.

**MECHANICS.** Line-anchored and `cmp -s` guarded, so a shifted file MISSes loudly instead of
editing the wrong citation. **20 edits [M]:** `CLAUDE.md` 10, `docs/coding-conventions.md` 6,
`docs/operator-runbooks/execution-health-onchain-verify.md` 4.

Also add a **"Reading a numbered citation in this file"** block to `CLAUDE.md` stating the band —
`Check 928`/`Rule 916` are the consumer's, a bare `Check 28`/`Rule 16` is core's — and pointing at
the row-8 crosswalk. Without it the next reader has no way to tell the namespaces apart, and this
row recurs. While there, `Rule 1 through Rule 26` is stale on its own terms (core defines through
**Rule 30**); rewrite it range-free rather than to a number that goes stale again.

**VERIFY, and the control is the point:**

```
# the realigned ids are present
grep -rncE 'Check 9(19b|22|24|27|28|29|30)|Rule 916|Step 903b' CLAUDE.md docs/coding-conventions.md
# CONTROL: the core-referent citations are still there, untouched — a sweep that
# rewrote them too would look identical on the line above
grep -rnE 'Check 14|Check 17|Check 24|Rule 13' QUICKSTART.md .claude/team-roles/ docs/coding-conventions.md
# and the layer tallies must be BYTE-UNCHANGED: no file here is a validator subject
bash scripts/ai-dlc/validate-layer-entries.sh . | tail -2
```

**EXPECT** the layer reading to be exactly what row 8 left (`0 error(s), 0 warning(s)` once row 8 is
done; `70 error(s), 4 warning(s)` if 8c runs before 7–8, as it did here). **A change in that number
means you edited a layer entry and this row's classification was wrong.**

**STOP CONDITION:** any `MISS`, or any edit under a Durable-audit-record or Core-delivered path.

---

### Row 9 — verify, commit, push, PR, merge. In `graph`.

```
git add -A && git commit -m "chore(ai-dlc): pull 0.224.0 and migrate every consumer id into the reserved band"
```

**Rehearsal diff against `9b5d408a3`: 75 files changed, +3326 / −408** — 39 under `extensions/`,
13 `tests/fixtures/`, 13 `overrides/` (the `base_sha` restamp), 2 `scripts/ai-dlc/`, plus the stamp,
the contract, `SKILL.md`, `core-manifest.md`, the update skill and the register.

**EXPECT 78, NOT 75 — row 8c is additive to the rehearsal and this is not a deviation.** The
rehearsal predates row 8c, so its 75 excludes the three live routing docs that row realigns:
`CLAUDE.md`, `docs/coding-conventions.md`, `docs/operator-runbooks/execution-health-onchain-verify.md`.
Line counts move by roughly +30 for the same reason. **Any OTHER file beyond those three is a real
deviation** — in particular a `.claude/team-roles/` path in the diff means row 8c edited a
core-delivered file and must be reverted before the push.

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
taken per entry (band id vs qualifier), the 19 crosswalk rows, row 8c's 20 citation realignments
**and the three-class rule that decided which citations were left alone**, and the ledger residue
from row 2 (3) as follow-ups.

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
- **`W3`'s subject set stops at the layer, and the citations that matter most are outside it
  (row 8c).** `LC-R1` measures `4/50` — the 50 layer entries. `CLAUDE.md` is not among them, yet it
  is loaded into context on every session in the consumer project, so a consumer id renamed by
  Rule 27 leaves a stale pointer there that passes `0 error(s), 0 warning(s)` AND a green pre-push.
  Found by hand on this pull, after row 6 reported clean. **The strongest candidate invariant in
  this file:** core knows every id an entry defines and every id it retired (it computes both for
  `E15`/`E16`), so it can grep the consumer tree outside the layer for those ids and WARN — the same
  join `W3` already performs, with the subject set widened past the entries. Until that exists, this
  is a hand-discipline step every layered consumer must be told about, which is why it is now row 8c
  rather than a footnote. Note the classification cannot be fully mechanized — core and consumer
  legitimately share numbers, so the id join proposes candidates and a human still resolves each by
  title. A WARN naming candidates is the right level; an ERROR would be wrong.
- **`LC-N6` mandates crosswalk rows that `audit-rule-files.sh` then flags, and nothing joins the
  two instruments (found at row 9, the pull's LAST gate).** A crosswalk row's `title` column
  reproduces the entry's historical title, which routinely carries a sprint tag (`[PI-S253-1]`,
  `(S294 I-14)`) — bare, that is an `ORIGIN_TAG` tier-1 finding. And an author filling column 4
  ("resolves a bare citation written before …") reaches naturally for a date, which is an
  `EMBEDDED_DATE` tier-1 finding. **19 rows produced 32 tier-1 findings and wedged the push**, at
  the one gate that runs after everything else is green. Neither is unsatisfiable — backticks make
  the tag a mention, and column 4 takes an event or a sha — but **nothing tells the author that**,
  and the layer validator says `0 error(s), 0 warning(s)` throughout. The rehearsal missed it
  because its rows happened to be terser and date-free. Cheap candidate fixes, in order of value:
  state both constraints in the README's own crosswalk prose (core delivers that prose, so every
  consumer gets it); and have `validate-layer-entries.sh` WARN when a crosswalk row it is already
  parsing for `E16` contains a bare `S\d{2,4}` or an ISO date. This is the third instance in this
  pull of the same shape — **a mandated edit that a DIFFERENT instrument then penalizes, with no
  join between them** (§4.6 `W3`, row 8c's out-of-layer citations, and now this).
- **The 6 report-only override rows.** Unchanged since the 0.213.0 pull.
- **The `ledger-reverify.sh` residue** — 66 rows, 46 `STILL-LIVE`. Worked in its own pass, not here.
- **The 3 `NEEDS-REVIEW` ledger rows** — new status since the last pull; report, do not adjudicate.
