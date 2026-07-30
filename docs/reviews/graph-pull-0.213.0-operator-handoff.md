# graph pull → ai-dlc v0.213.0 — operator handoff, revision 3

**Point a fresh Claude Code session at this file in `/Users/n8/git/graph`.** It drives the pull to
done across multiple sessions.

**Revision 3, and it is a different KIND of document from revisions 1 and 2.** Those were
single-session copy/paste prompts with four report-back pauses. This one is a multi-session handoff
with a progress ledger, because the pull's judgement load grew from 3 required fixes to **45
discrete decisions** across three separate gates that wedge the push if skipped. A 45-judgement
single-session prompt is how you get the failure this file's own §3 warns about: under context
pressure the fast route through a per-item judgement is to batch-apply the permissive option, which
converts a real finding into a silent exemption and leaves the consumer where it started.

Revisions 1 and 2 live at `docs/reviews/graph-pull-0.183.0-operator-prompt.md`. **Do not reuse
them** — they pull to 0.183.0, which is already banked.

---

## 0. How to use this file, and WHICH REPO YOU ARE IN

1. Read §1–§5 in full. They are short and every line is load-bearing.
2. Read the **Progress Ledger** (§5) to find the next unticked row.
3. Read that row's section in §6, execute it, tick the ledger **with a sha or a count** as the last
   act. A fresh session's only way to know where it is.
4. When you reach a **`⏹ FRESH GRAPH SESSION`**, stop. The operator opens a new session **in
   `graph`**, pointed back at this file, and it picks up the next unticked row. Do not push past one.

## EVERY ROW RUNS IN `graph`. THERE IS ONE SESSION AT A TIME.

This is the thing to be unambiguous about, so it is stated once and plainly:

- **All nine rows in §5 run in a session whose working directory is `/Users/n8/git/graph`.** Every
  command, every edit, the `apply`, the push. There is no row that runs in ai-dlc.
- **This file lives in the ai-dlc repo and is read by absolute path.** That is the only ai-dlc
  involvement in the normal path. Reading a brief from another directory is not "running in" it.
- **`⏹ FRESH GRAPH SESSION` is context hygiene, not a repo switch.** It means *this* graph session is
  full — 28 judgements or 17 adjudications is a context's worth — so start another **graph** session
  and continue. Same repo, same file, next row.

**When an ai-dlc session IS needed — and it is CONDITIONAL, not scheduled.** One trigger only:

> **A tally deviates from its stated expectation, or a stop condition fires.**

Then, and only then, stop and open a session in `/Users/n8/git/ai-dlc` with the deviation. If every
tally matches, **you never open one** and the whole pull is a sequence of graph sessions.

**Why that escalation exists, and why it is a different repo.** The graph session is the
*worst-placed* agent to judge whether a check misfired: it has the consumer's context loaded, it is
mid-push, and the cheap resolution is always "widen the thing that is complaining." §3 names that
failure mode twice, and both wedging gates in this pull have a permissive route that silences them.
An ai-dlc session with the distribution loaded is what refuses it. **A core defect found during this
pull is fixed in ai-dlc and re-delivered — never patched in graph.**

| | **graph session** — the default, all 9 rows | **ai-dlc session** — escalation only |
|---|---|---|
| Opened | for every row, and again after each `⏹` | only when a tally deviates |
| cwd | `/Users/n8/git/graph` | `/Users/n8/git/ai-dlc` |
| Runs | classifiers, `apply.sh`, the 28 declarations, the 17 adjudications, the push | nothing against graph |
| May edit | graph's tree | core only |
| If all tallies match | does the entire pull | **is never opened** |

**Everything in §6 is reference for the row you are on. §5 says what to do next; nothing else in
this file does.** Rejected options and corrected premises are recorded so they are not
re-litigated — they are not competing instructions.

**Fidelity tags.** **[V]** = verified with a control during the 2026-07-29 measurement pass, named
in §4. **[R]** = reported, not independently verified — **treat as a hypothesis.** Two [R] premises
were falsified during the program that produced this pull.

---

## 1. State at handoff

| | |
|---|---|
| **Distribution target** | `3490997`, VERSION **0.213.0**. **PIN THIS SHA.** |
| **Consumer** | `graph` at `170ff9d8c`, stamped **0.183.0 @ 46aa98a** |
| **Span** | `46aa98a → 3490997` — **25 releases**, 0.184.0 through 0.213.0 |
| **Base for every classifier** | `46aa98a` (the stamp), NOT `0.183.0`'s tag and NOT `170ff9d8c` |
| **Judgement load** | **17** adjudications + **28** fixture declarations = 45 per-item decisions, plus 4 mechanical edits |
| **Gates that WEDGE the push if skipped** | three: party-mode home, fixture drivability, the 17 adjudications |
| Program that produced this span | `docs/analysis/layer-contract-program-handoff.md` rows 1–11, all closed |

**graph has been frozen for this program** — no sprint has run in it, which is why `170ff9d8c` is
still the tip and why the tallies below are measurable in advance at all. **The freeze ends when
this pull merges.**

---

## 2. Locked decisions — do not re-litigate

| Decision | Consequence for you |
|---|---|
| **One branch, machinery + rulebook together** | Rev 1's run proved splitting them wedges: the skill's own self-update installs a validator that blocks its own push. Precedent: PR #829. |
| **Consumer checks/rules ≥900; core 1..899** | The 5 `W5` warnings are the consumer's squatters. **Renumbering is NOT part of this pull** — each rewrite touches an integer already in gate logs and wants a crosswalk row first. Verify the tally, leave them. |
| **`overrides/steps__gate-validation__check-25-universal-core.md` is RETIRED, as a required step** | Not optional. v0.197.0 exists to make it possible, and the override's own first line is false — it drops core's gate-type enum. |
| **17 adjudications are RECORDED, not waived** | `level: ADJUDICATED` blocks `apply` while unrecorded. There is no skip flag, deliberately. |
| **The 28 fixture declarations are a PER-DIRECTORY judgement** | Route 2 (`README.md`) over a fixture that HAS a driver is a false statement the script cannot detect and will accept. Do not batch-apply it. |
| **A core defect is fixed in ai-dlc, never in graph** | Stop and escalate to an ai-dlc session. This is the ONLY reason to open one. |

---

## 3. Non-negotiable discipline

**A zero is not a finding.** Every absence-shaped claim carries a control in the same invocation
that returns non-zero. **This rule earned its place five times in one afternoon during this pull's
own measurement pass** — see §4. Every one of those was a wrong invocation that answered "clean."

**Never read `$?` after a pipe.** It is the pipe's last stage. Redirect to a file, then check.

**`printf '%s' "$VAR" | grep -q` inverts under `pipefail`.** Once the value clears the pipe buffer
the pipeline reports the writer's status, so a MATCH answers non-zero. Read the value as a
here-string: `grep -q ... <<<"$VAR"`.

**Unbraced `$ref:path` in zsh.** `:c`/`:t` are history modifiers and eat the next character. Always
`"${r}:core/…"`. graph's operator has already hit this while authoring a receipt.

**A widened exemption is not a fix.** If a gate reports a finding, the remedy is the finding's
subject — never the gate's scope. A home added because it currently reports a finding is an
exemption wearing a performance argument. Both wedging gates in this pull have a permissive route
that silences them, and neither is correct.

**Structurally-impossible zeros are not evidence of work done.** Post-apply, `base` equals `theirs`,
so hook-drift and roughly 8 of 13 statuses **cannot fire at all**. A real run of an earlier revision
mistook that for evidence the re-reads had been disposed. Each row in §6 states which of its zeros
are impossible rather than clean.

**Report tallies verbatim at a boundary.** Not "as expected" — the number, and the stop condition it
was measured against.

---

## 4. Premises already falsified, and the five false probes

**All six tallies in §6 were re-derived on 2026-07-29 against `graph 170ff9d8c` with the shipping
code from a pinned worktree at `3490997` [V].** graph had not moved; the *distribution* had, by 8
releases, so every tally that joins the two trees was stale even though the consumer was not.

**Two of the previous revision's tallies were wrong, and five probes answered falsely before the
right invocation. Expect to hit these — they are properties of the tools, not mistakes you can
avoid by being careful:**

| # | Probe | What went wrong | The right invocation |
|---|---|---|---|
| 1 | `validate-gate-manifest.sh <root>` | Wants a **FILE**, not a repo root. Exited **2**; a grep for `UNLOADABLE` read **0** | `validate-gate-manifest.sh <consumer>/.claude/skills/ai-dlc/steps/gate-validation.md` |
| 2 | `validate-fixture-drivability.sh <root>` | Wants `--dir`. Exited **2**, read as no findings | `validate-fixture-drivability.sh --dir tests/fixtures`, run **from graph's root** |
| 3 | `validate-provenance-block.sh --strays <root>` | Takes **paths**, and derives the project root from **its own script location** — your cwd is ignored. Scanning with the script outside graph reported **397** findings against a true **5** | Run the copy that lives at `scripts/ai-dlc/` **inside graph** |
| 4 | `--strays` against graph's installed copy | graph's 0.183.0 copy contains the string `strays` **zero** times — **the mode arrives WITH the pull.** Nothing can measure it pre-apply except a staged copy | Stage the shipping script into a **copy** of graph, never graph itself |
| 5 | `grep 'W5'` on the linter's output | The token `W5` **never appears in the message text**. 5 warnings existed; the grep said 0 | Match `OUT OF BAND`, or count the `WARN` lines |

**And one tally moved:** the envelope-carrier count after the party-mode fix is **893**, not the
889 recorded. The finding count (**5**) and their subject (`scripts/tests/**`) are unchanged.

**The lesson to carry through every row: when a probe answers "clean," check that it ran.** Four of
the five above are indistinguishable from a passing check if you only read the tally.

---

## 5. Progress Ledger

**The next unticked row is the next thing to do. Do them in order.** Tick as the last act of each
row, with a sha or the count you measured. `—` = not started.

| # | Row | Repo | Status |
|---|---|---|---|
| 1 | Pre-flight: the pre-push shim, `_bmad/`, a clean tree, pin the engine | graph | ✅ shim **314 bytes**, `core.hooksPath` unset; `_bmad/` present; tree cleaned at `b90554891`; engine worktree `/tmp/pull-engine` @ **3490997** (VERSION 0.213.0). **graph tip moved `170ff9d8c` → `b90554891`** — runtime-state only (`.wait-beats/` + `_bmad-output/`), 0 files outside those prefixes vs 19 on the control commit; stamp base `46aa98a` unchanged, so §1's classifier base still holds. |
| 2 | Classify only. Report all six tallies. **Write nothing.** | graph | ✅ All six match; **no stop condition fired**, so no ai-dlc escalation. Measured against engine `/tmp/pull-engine` @ **3490997** (VERSION 0.213.0), consumer `b90554891`, base `46aa98a`. **(1) `layer-drift.sh` — 69 rows**, exit 0: `HARD-LAYER-ADJUDICATION-MISSING` **17**, `EXTENSION-HOOK-DRIFT` **17**, `EXTENSION-OK` **16**, `OVERRIDE-OK` **9**, `HARD-OVERRIDE-DRIFT-SECTION` **4**, `OVERRIDE-DOUBLE-SHADOW` **2**, `OVERRIDE-DELEGATES-INTO-SHADOW` **2**, `OVERRIDE-ASSERTS-SHADOW-SURVIVES` **2** — no status outside the table, no count off by one. **(2) `ledger-reverify.sh` — 56 rows**, exit 0: `STILL-LIVE` 32, `HAND-REVIEW` 13, `CLOSE-CANDIDATE` 5, `NAMED-UPSTREAM` 3, `ENTRY-SWALLOWED` 3 (no expectation stated in §6; recorded as measured — the 3 `NAMED-UPSTREAM` corroborate row 8b's 3). **(3) W5** — `validate-layer-entries: 0 error(s), 5 warning(s)`, exit 0; subjects checks `33.`/`34.`/`35.` (gate-validation-domain.md) + `Rule 31`/`Rule 32` (SKILL-domain.md), all `OUT OF BAND`. **(4) UNLOADABLE** — exit **1** (not 2, so the FILE arg took): `19b 2s 33 35`; `MISSING (manifest id, no anchor): none`; `ORPHAN (anchor, no manifest claim): none`; `manifest source: overrides/steps__gate-validation__check-25-universal-core.md`; `extension gate_types: none`; `manifest ids: 42   anchors: 42`. **(5) Fixtures** — exit **1** (not 2, so `--dir` took): `103 / 73 driven / 2 declared undrivable / 28 undeclared`. The 2 undrivable are core's own `check-h1-recursion` + `check-manifest-bypass` (both carry the marker, both **absent** from the 28) → **no core defect**; the 28 FAIL subjects match §6 row 4's 14+14 list name-for-name. **(6) Check 5** — exit **0**: `sprint-status: check-stories PASS — 2 comparison(s) over 2 entries, 0 finding(s)`, `sprint 299`; **no `story_key_re` KeyError**, so no version skew and this did not need deferring to row 7. **Impossible zeros, stated not counted as clean:** `EXTENSION-ANCHOR-DRIFT` / `EXTENSION-ANCHOR-MISSING` = 0 **because no entry declares `extends:`** — controlled (`extends:` 0 vs `hooks:` 34 / `kind:` 34 in the same trees, same invocation shape; the 2 unanchored `extends` hits are prose); `EXTENSION-RETIRE-CANDIDATE` = 0; `Check AP`/`Check VH` absent from (4) as structurally outside the numeric heading grammar — not evidence they load. **§4 probes reproduced:** `W5` token appears **0** times in the linter output (probe #5); graph's installed `validate-provenance-block.sh` carries `strays` **0** times against the engine copy's **16** (probe #4) — controlled on a 420-line readable file with 16 `provenance` hits, so `--strays` is genuinely unmeasurable pre-apply and its absence is **not** a pass. **Wrote nothing to graph:** HEAD still `b90554891` on `main`, porcelain still the same 3 `_bmad-output/` runtime files, **0** entries outside that prefix. |
| ⏹ | **FRESH GRAPH SESSION.** Report the six tallies. **Escalate to ai-dlc ONLY if one deviates** — otherwise carry straight on in a new graph session | graph | |
| 3 | The two mechanical pre-apply edits: party-mode home, retire `check-25-universal-core` | graph | ✅ Both edits made in graph on `main`, uncommitted (row 6 branches over them). **3a** — `"party_mode_homes": ["scripts/tests/**"]` added to `extensions/known-skills.json`. `--strays: PASS (no out-of-place party-mode blocks; 893 file(s) carried the envelope)`, exit **0** — matches §6's current 893. **Control run in the same shape** with `AI_DLC_KNOWN_SKILLS_EXT=""` (extension disabled): exit **1**, `--strays: FAIL (5 out-of-place party-mode block(s))`, all **5** under `scripts/tests/**` (`validate-mandatory-rules/corpus-snapshot-s288/gate-log-archive-s263.md`, `…s256.md`, `test-scan-stray-legit-homes.sh`, `test-audit-squash-enum.sh`, `test-s239-1-hardening.sh`) — **no 6th, none outside**, so the PASS is a flip and not a vacuous scan. Homes were NOT widened. **3b** — `git rm` of `overrides/steps__gate-validation__check-25-universal-core.md` + `gate_types: implementation` added to `extensions/checks/gate-validation-domain.md` frontmatter. `validate-gate-manifest.sh` on graph's `steps/gate-validation.md`: exit **1**, `manifest source: core` (was the override), `extension gate_types: 34->implementation` (was none), `MISSING … none`, `ORPHAN … none`, `manifest ids: 42   anchors: 42`, `UNLOADABLE … 19b 2s 33 35` — the four row-2 rows ONLY, no stop condition. `validate-layer-entries: 0 error(s), 5 warning(s)`, exit 0 — unchanged by the frontmatter edit. **Method note for row 7's `--strays`:** graph's 0.183.0 `.claude/schemas/provenance-block.json` has **no `stray_scan` block**, so the shipping script against graph's installed schema dies `KeyError: 'stray_scan'` / `GREP_ARGS[@]: unbound variable`, exit 2 — a version skew of the same class as row 2's `story_key_re`, **not** a finding. Measured instead on an APFS copy-on-write clone of graph (`.git`/`node_modules`/`worktrees` omitted — the schema's own `scan_exclude_dirs`) with the shipping schema overlaid at `.claude/schemas/`; nothing was staged into graph itself, and the clone was deleted after. **Instrument trap worth carrying:** this session's `grep` is a shell-**function** wrapper from Claude Code's shell snapshot and it undercounts the real binary — it reported **889** carriers for the same tree and invocation where non-interactive `bash -c` and the validator both report **893** (the 4-file delta is all `_bmad-output/**`). Any count derived through the agent's own shell must be re-derived under `bash -c` before it is reported as a tally. Tree after row 3: exactly the 2 modifications + 1 deletion, plus the 3 pre-existing `_bmad-output/` runtime files, 0 entries elsewhere. |
| 4 | The **28** fixture declarations — one per-directory judgement each | graph | ✅ **20 `run.sh`, 8 `README.md`, 20+8 = 28.** Validator (engine `/tmp/pull-engine` @ **3490997**, from graph's root): exit **0** — `103 directories / 93 driven (run.sh) / 10 declared undrivable / 0 undeclared`, `PASS every fixture directory is driven or declares why it cannot be.` **Full push-suite equivalent run** (`.githooks/pre-push` `run_fixtures()` shape — `for d in tests/fixtures/*/; do [ -f "$d/run.sh" ] \|\| continue; bash "$d/run.sh"`): **93 ran, 0 FAIL.** Every one of the 20 new drivers is individually green and offline; slowest is 1s. **§6's 14/14 [R] split was WRONG in one direction — 6 fixtures are route 1, not route 2**, each confirmed by RUNNING the driver, never by citation: (a) `check-26-deployed-ranges`, `check-27-config-integrity`, `check-30-orphaned-fn`, `check-31-cited-sha`, `check-35-mutation-red-reachability` — **the citation direction is inverted.** Each fixture's own `seed.sh` ends `exec bash "$REPO_ROOT/scripts/tests/test-…"` (targets: `test-s239-2-check26-discrimination.sh`, `test-s241-5-gate3-tamper.sh`, `test-s259-4-check30-orphaned-fn.sh`, `test-s262-check31-cited-sha.sh`, `test-s291-3-check35-mutation-red.sh`, all present), so a path-shaped `git grep -lF "fixtures/<name>"` finds nothing and reads as "no driver" — route 2 here would have been exactly the false statement §6 says the script cannot detect and will accept. (b) `boundary` — its citer `scripts/regen-boundary-fixtures.sh` carries `--check` ("Exit 1 if any fixture or `.regen-hash` would change"); with `--offline` that is a deterministic, network-free assertion over the recorded bytes, i.e. a driver rather than the regenerator §6 read it as. **0 fixtures moved the other way.** Route-1 wiring: 11 delegate to an existing `scripts/**` harness, 5 enter via their own `seed.sh` (target named in one place only), 3 to pytest via `.venv-ci/bin/python3` with a `python3` fallback (ci-local's own resolution), 1 to `regen-boundary --offline --check`. Route 2 = `check-7-arch-content`, `check-18-runtime-constraints`, `check-19-disposition`, `check-20-doc-check`, `check-21-section0`, `check-a52-sprint-pr-merge` (spec-by-example fail/pass gate-artifact pairs whose verdict is an LLM's read; a `run.sh` could only be a newly-authored grep standing in for the model's judgement, which is inventing an enforcer, not delegating), `compute` (**not a fixture** — the empty derived-value TIER ANCHOR of ADR-153-1, only entry is `.gitkeep`; a `run.sh` could only assert an empty dir is empty, the vacuous green the step exists to remove), `retro-audit` (the classifier IS `docs/audit-methodology.md` § Adversarial Pass; its `seed.sh` idempotence is a property of the GENERATOR, so wiring it would tick green beside the fixture while the bypass classification stayed unexercised). Each route-2 README carries the exact `EXEMPT_MARKER` and its own reason, with the negative probe controlled: `git grep -lF "fixtures/<name>"` returns no executable **while the same probe shape returns `check-26-deployed-ranges`' citer** — a real absence, not a mis-run probe. **TWO SUPPORTING EDITS, both required to make a DECLARED driver actually run — the alternative was declaring a driver that cannot execute:** (1) `tests/test_validate_cycle_commits_bypass.py:27` pointed at `scripts/validate-cycle-commits.sh`, which **does not exist** (`ls`: No such file); **line 31 of the same file already names the correct `scripts/ai-dlc/validate-cycle-commits.sh`** — the file contradicted itself. Repaired that one path: **18/19 → 19/19 passed.** It drives BOTH `check-cycle-types-bypass` and `cycle-commits`. (2) `scripts/regen-boundary-fixtures.sh` — adding the required `run.sh` to `tests/fixtures/boundary/` made `--check` report `DRIFT .regen-hash`, because `compute_manifest_hash()` covers every file in that dir except `.regen-hash`, `README.md`, `.gitkeep`. Added `run.sh` to that tuple on the **identical grounds `README.md` already sits there** — harness/declaration, not a recorded boundary byte — so editing the driver never reads as a recording changing. **NOT an exemption-widening: control run in the same shape** — as-is exit **0**; append one byte to `boundary/sprint-152/item-393/block-N.txt` → exit **1** `DRIFT`; restore byte-identical (`cmp` clean) → exit **0**. The recorded bytes stay covered. `shellcheck -S style` (ci-local's own level) on that script: rc **0** both at HEAD and after the edit, so it is **not** one of row 9's four pre-existing shellcheck failures; all 20 new `run.sh` clean at `-S warning` (ci-local's scope is `find scripts -type f -name '*.sh'`, so fixture `run.sh` is outside it anyway). **SURFACED, NOT FIXED — three drivers were DEAD before this row** (`grep` of `scripts/ci-local.sh` runs **none** of them): `scripts/tests/test-s239-1-hardening.sh` fails **5 of 15** assertions `rc=127` on `scripts/validate-provenance-block.sh` + `scripts/validate-mandatory-rules.sh` (both now under `scripts/ai-dlc/` — same stale-path class as (1); `retro-replay` is wired to §6's sanctioned `scripts/retro-replay-harness.sh`, green, so this does not block, and the stale test stays red and run by nothing); `scripts/tests/test_validate_phase_sequencing.sh` fails `Sprint 137 regression baseline — expected exit 0, got 1` (`phase-sequencing` is wired to `tests/test_validate_phase_sequencing.py`, green, and it DOES read `out-of-order-subjects.subjects`). **DEVIATION, operator-facing, recommended PROCEED:** §6 row 4's verify line expects `2 declared undrivable`, which is **arithmetically impossible alongside its own 14/14 split** — every route-2 declaration increments that counter, so 8 of them make it 10. Both load-bearing conditions hold (**exit 0, 0 undeclared**) and the 2 pre-existing exemptions are still exactly core's `check-h1-recursion` + `check-manifest-bypass` (the row-2 stop condition), so **no core defect is implicated** — it reads as a slip in this file's arithmetic, correctable in an ai-dlc session. **Tree after row 4:** row 3's 2 modifications + 1 deletion, the 2 supporting edits above, **28** new untracked files under `tests/fixtures/`, **0** entries outside that prefix, plus the 3 pre-existing `_bmad-output/` runtime files. Still uncommitted on `main` at `b90554891` (row 6 branches over it). |
| ⏹ | **FRESH GRAPH SESSION** — 28 judgements is a context's worth on its own | graph | |
| 5 | The **17** adjudications — record a verdict per row | graph | ✅ **17 still-additive, 0 contradicts-core, 0 retire, sum = 17.** Register written to `_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl`, one `LC-E4` record per row, `recorded_utc` **2026-07-30T11:28:21Z**. Digests **copied** from field 4 of each blocking row by a script that joins on the entry path and asserts set-equality against my verdict table (17/17, `diff` of sorted digests vs the rows = IDENTICAL) — never recomputed, per the schema's own warning. Conformance checked against `core/schemas/layer-adjudication-register.json` read from disk (enum taken from the schema, not restated): **ALL 17 OK**, and a control record with `verdict: still-additive-ish` is rejected by the same checker. **17 of 17 reasons are distinct** (245–1342 chars); no batch-clear. **VERIFY, both halves:** `HARD-LAYER-ADJUDICATION-MISSING` **0** (was 17) and `EXTENSION-HOOK-DRIFT` **17 — UNCHANGED**, so the candidate row still prints and the clause stays falsifiable. `HARD-REGISTER-CONTRADICTION` **0**. **Control that the register is what discharged them:** moved the file aside, re-ran, got `17 HARD-LAYER-ADJUDICATION-MISSING` + `17 EXTENSION-HOOK-DRIFT` back, restored it. **CORE DEFECT FOUND — belongs in ai-dlc, never graph (§2).** Core's NEW §5b paragraph calls the audit-anchor backfill "the ONE commit this pipeline pushes to `main` outside a PR" and says "Fold anything else into the retro PR", but core's OWN §7a-post at the same sha `3490997`, step 7, reads `Commit to `main`: chore(s<N>): rotate gate-log and compaction-log post-retro-merge` — a second out-of-PR commit, so the new sentence is false against core's own step in the same file. Verified **non-wedging**: `validate-audit-anchors.sh --trunk-push` fires only on a commit *claiming* the backfill subject with extra paths, or one rewriting `audit-anchors.md` alone under another subject, and the script's own header states "it bounds the licensed commit; it does not police the trunk — core states no branch policy". Verified it **does render here**: §5b is NOT shadowed (`overrides/steps__retro__domain-sections.md` retired its §5b shadow and records core §5b authoritative again). So `retro-gate-log-rotation.md` was recorded **still-additive** — it states the consumer rationale for the step core itself defines, and graph's §7 override says in its own words that it reproduces core's 7a-post verbatim; charging the entry would misdirect the remedy. `SKILL-push.md` Rule 25(c) carries the same statement and is noted the same way. **DEVIATION vs row 2, benign, recommended PROCEED:** classifier is now **68 rows / `HARD-OVERRIDE-DRIFT-SECTION` 3** (row 2: 69 / 4). Controlled against a clean worktree of `b90554891` (pre-row-3 tree, override still present): **69 / 4** reproduced exactly, and a `comm` diff of the two outputs shows precisely two changes — the retired override's drift-section row is gone, and `gate-validation-domain.md`'s adjudication row changed content because its digest covers the entry, which gained `gate_types:` in row 3b. Both are row 3b's intended consequences. **Therefore row 6's stated "the 4 `HARD-OVERRIDE-DRIFT-SECTION` rows and NOTHING ELSE" is arithmetically stale — expect 3**, the same slip class row 4 recorded for "2 declared undrivable". **Surfaced, not fixed:** two absorbed-duplicate consumer mechanisms (`check-protected-core-paths.sh` → core's `core-paths.sh --audit-diff`; `check-mutation-red-anchor.sh` → core's `validate-mutation-red.sh`, same argument contract), and a now-*realized* silent fork in `dev-push.md` + `qa-domain.md`, whose restatements of core's mutation-red paragraph did not move when core added the replay mandate — exactly what core's Rule 27(c) predicts. Absence claims controlled: the 7-pattern grep proving no entry restates core's rewritten checks 5/16/18/22 returned zero **beside non-zero hits for `core-paths.sh` and `check-mutation-red-anchor` in the same invocation**; `party-mode-inline-relay.md`'s retirement condition probed as its own text demands — **0** inline-relay hits in core `SKILL.md` @ theirs against **19** party-mode hits, same file, same invocation → condition unmet. **Wrote exactly one file to graph:** the register. Tree = rows 3+4's edits + 28 fixture files + the register, 0 entries outside those prefixes; still uncommitted on `main` at `b90554891`. Control worktree `/tmp/graph-ctl` removed. |
| ⏹ | **FRESH GRAPH SESSION** | graph | |
| 6 | `apply` on one branch, machinery + rulebook | graph | ✅ Branch **`chore/ai-dlc-update-0.213.0`** off `b90554891`. **Blockers cleared: 3** `HARD-OVERRIDE-DRIFT-SECTION` (**not 4 — row 5 predicted this and it reproduced exactly**; the 4th was row 3b's retired override). `hard-blockers.sh` now prints `0 HARD blockers.` **Controlled:** moved row 5's register aside, re-ran, and the 17 `HARD-LAYER-ADJUDICATION-MISSING` rows came back through *this* script (row 5 had only controlled them through `layer-drift.sh`), restored it — so the 0 is discharge, not a vacuous scan. `apply.sh` exit **0**: **112 RESOLVED, 19 WORKLIST (17 extension-reread + 2 semantic-merge), 0 DECISION**, `RESOLVED restamp 46aa98a -> 3490997`, in-flight marker cleared. Both required files present: `.claude/schemas/layer-adjudication-register.json`, `.claude/skills/ai-dlc/layer-contract.yaml`. **No flagged block** (`needs_operator_confirmation` 0 in both apply streams). 146 changed paths on the branch. **THE THREE OVERRIDE VERDICTS — 2 readopt, 1 reaffirm, worked one at a time.** (a) `steps__gate-validation__check-5.md` → **readopt**. Its own Removal condition re-tested at theirs and **still unmet, now half met**: core does invoke a validator but its OWN (`scripts/ai-dlc/sprint-status.sh`), not a project-supplied one, and core carries **no** generator-diff arm — probed core's Check 5 body for `generate-sprint-status`/`generator-diff`/`source of truth` for **0** hits against a control of **4** `sprint-status` hits in the same block and invocation shape; the condition is an AND so it still evaluates false. Body now routes the comparison to core's enforcer and carries core's full exit-code table (`0/1/3/4`, with exit 4 never a pass) — without that the fix is INERT, since the lead obeys the override. Consumer deltas 2 and 3 preserved; delta 1 recorded as superseded-in-part rather than dropped. `--check` flipped **1 → 0**, controlled against HEAD's body which reproduced the same 5 stale lines. (b) `steps__retro__domain-sections.md` → **readopt, and it REVERSES the prior 056d160 REAFFIRM as wrong on its load-bearing step.** That note reasoned "restates no table row, so reporting delegates back to core's table" — core's own contract names that as the defect: **`LC-O9` / `OVERRIDE-DELEGATES-INTO-SHADOW`**, "precedence replaces that section at load time, INCLUDING the delegation target, so it reads as a correct single-source delegation and behaves as a dropped one." This entry shadows `#4a`, and core's `## Machine Audits` table lives INSIDE §4a (core `retro.md` 549–572) — so every reaffirm on those grounds left the table, and each upstream fix to it, unrendered. `layer-drift.sh` names the entry and construct outright (`#4a. Close-Out Sweep -> '## machine audits'`), and **graph's own ledger had independently filed it as `PC-S307-MACHINE-AUDITS-IS-A-CHILD-OF-4A-SO-EVERY-4A-SHADOW-SWALLOWS-IT`.** Took the classifier's first-listed remedy: restated the table in the body with the new `UNLOADABLE` cell (body line 307; **control:** HEAD's copy carried `UNLOADABLE` **0** times) and re-pointed all three delegations at it. Recorded the obligation this creates — the table is now a consumer copy and will not track upstream by itself. (c) `steps__retro__pipeline-snapshot-ceiling.md` → **reaffirm** (note recorded). Restates no table row (0 pipe-leading lines), names that validator **0** times. Its `reason:` makes two mirrored core constants the load-bearing check, not the cell — and **the prior note's premise was stale**: `validate-artifact-budget.sh` is NOT absent from this span (2 insertions, 2 deletions), so it was re-derived, not reused. Both hunks are `printf … | grep -q` → here-string (the §3 pipefail fix) at lines 555/872; neither mirrored quantity moved (`pipeline-snapshot.md\|6000\|trim` line 270; `BPT=4`/`GRACE_PCT=10` lines 112–113, the exact lines the body cites), so `6000 × 4 × 1.10 = 26,400` stands. **DEVIATION 1 — row 6 omits a gate core's step 7 makes mandatory, recommended FOLD INTO §6.** Step 7's **mechanical union gate** lets `apply` write only after BOTH `hard-blockers.sh` = 0 **and** `emit-report.sh --verify <report>` exits 0 ("the gap that shipped a data-loss drift past two reports"). graph's `reconcile-report.md` was the 0.183.0 one; `--verify` **failed it, exit 1**, naming the prior refs (`056d160 → 0f9643c`) — a live control that the check is not vacuous. Re-emitted the report for this span with the mechanical region pasted byte-verbatim plus the semantic sections; `--verify` then exit **0**. Report is pinned to PRE-apply state by design; it is not re-verified post-apply. **DEVIATION 2 — row 7's stamp expectation would have FAILED as written, and this is the machinery half.** `apply.sh` deliberately **preserves** `skill_version`/`skill_commit` (SKILL.md §1164), so after apply the stamp read `0.213.0 @ 3490997` on the rulebook pair but still `0.183.0 @ 46aa98a` on the machinery pair. Ran `self-update-gate.sh`: **`SELF-UPDATE-DEFER`** — which is exactly the ordering §2 locked ("carry the machinery slice into the step-7 gated apply… **advance `skill_version`/`skill_commit` with that apply rather than here**"). Advanced them per that instruction, preserving `installed_at`/`upstream`. **Both pairs now read `0.213.0 @ 3490997`**, so row 7's check is satisfiable. **DEVIATION 3, cosmetic:** row 6 says the drift-section blockers "go through `readopt-override.sh --merge`" — there is no `--merge` flag; the script's modes are dossier / `--check` / `--stamp <outcome>`. **REFUTED in ai-dlc, and the real defect is core's:** `--merge` **is** a dispatched case arm in `reconcile/readopt-override.sh`, present both in the engine at `3490997` and at graph's base `46aa98a` (`grep -c -- '--merge)'` = 1 in each), and its body is the three-way `git merge-file` re-adoption. What is missing is its DOCUMENTATION — the script's `# Usage:` header and its exit-2 usage string both list only dossier / `--check` / `--stamp`, so an operator who reads the usage block concludes the mode does not exist, which is exactly what happened here. Row 6's instruction stands as written; the usage block is fixed in core. **HEADS-UP FOR ROW 7, and stated as degenerate rather than clean:** `self-update-gate.sh` ran POST-apply, so consumer-current and incoming were the SAME file and its per-script differential is structurally uninformative (the §3 impossible-zero class) — do not read those three `SELF-UPDATE-UNDECIDED` rows as evidence of anything. The actionable residue is real, though: **3 scripts exit non-zero against graph's tree** — `sync-taught-schema.sh` (1), `validate-audit-anchors.sh` (1), `validate-provenance-block.sh` (**2**). Row 7 expects `--strays: PASS, ~893 carriers` from that third script, so resolve its exit 2 there rather than reading a failure as the pre-existing skew row 3 recorded. **The 2 semantic merges are DONE, and the core-layer guard forced the correct route:** the hook denied an in-place `Edit` of `.claude/team-roles/dev.md` ("upstream-owned CORE file… core stays byte-reconcilable"), so both were merged through the engine route it names (`git show` theirs + re-substitute the consumer's declared ownership region). After merge each file diffs against theirs in **exactly 1 hunk** — the sanctioned `{ownership_paths}` / `{qa_ownership_paths}` fill — and upstream's new `validate-mutation-red.sh` replay text is present in both (`grep` 1 each; **control:** HEAD's copies 0 each). No substitution SITE (`^- {token}`) remains, controlled against theirs which has 1. |
| 7 | Post-apply verification, including the one probe that MUST fail | graph | ✅ **Version line: `version: 0.213.0` / `commit: 3490997` / `skill_version: 0.213.0` / `skill_commit: 3490997` — BOTH pairs, so row 6's deviation-2 fix holds.** Engine `/tmp/pull-engine` still @ **3490997**, `VERSION` 0.213.0. **The flip — all five `IDENTICAL`:** `validate-layer-entries.sh`, `validate-gate-manifest.sh`, `validate-provenance-block.sh`, `validate-fixture-drivability.sh`, `sprint-status.sh`. **Control in the same invocation:** `CLAUDE.md` vs the engine's reports FORKED, so `cmp -s` is not answering yes to everything. **`--strays` — first real run, exit 0:** `--strays: PASS (no out-of-place party-mode blocks; 894 file(s) carried the envelope)`. **894, not the recorded ~893, and the +1 is named:** replicating the validator's own `grep -rlI` corpus under `bash -c` reproduces **894** exactly, of which **889** are tracked at `b90554891` and 5 are not — `.pytest_cache/v/cache/{lastfailed,nodeids}`, `test-results/{gate-story-s288.txt,s290-baseline-triage.md}` (untracked runtime, present at row 3's measurement too) and **`tests/fixtures/stray-party-mode-provenance/seed.sh`**, which is `??` untracked and was written by row 6's apply from the engine's `core/fixtures/stray-party-mode-provenance/seed.sh`. So 893 + 1 new core fixture = 894; the drift is the apply's own delivery, not the gate. **Control that the PASS is a flip:** `AI_DLC_KNOWN_SKILLS_EXT=""` → exit **1**, `FAIL (5 out-of-place party-mode block(s))`, the same 5 subjects row 3 recorded, all under `scripts/tests/**`, **no 6th, none outside**. **`validate-layer-entries`: exit 0, `0 error(s), 5 warning(s)`** — the row-7 outcome that replaces revision 2's expected-exit-1, subjects unchanged (checks `33.`/`34.`/`35.`, `Rule 31`/`Rule 32`, all `OUT OF BAND`); §4 probe #5 reproduced — the token `W5` appears **0** times in that output. **Fixture suite: exit 0** — `103 directories / 93 driven / 10 declared undrivable / 0 undeclared`, `PASS every fixture directory is driven or declares why it cannot be`; **control:** the same installed script against a scratch tree holding one undeclared dir exits **1**. **Check 5's enforcer, post-apply against graph's own installed copies: exit 0** — `sprint-status: check-stories PASS — 2 comparison(s) over 2 entries, 0 finding(s)`, no schema skew. **RENDERED-PIPELINE VERIFICATION, per override, each against a HEAD control (HEAD = `b90554891`, pre-rows-3–6):** (a) `steps__gate-validation__check-5.md` names `sprint-status.sh` **4** times vs **0** at HEAD and carries core's full exit-code table in the body — `0` PASS / `1` gate FAILS / `3` HARD_BLOCK, marked reachable here / `4` "**it compared NOTHING … is never a pass**"; (b) `steps__retro__domain-sections.md` carries `UNLOADABLE` **3** times vs **0** at HEAD — the restated Machine Audits cell is in the text the lead obeys, not only in core; (c) `steps__retro__pipeline-snapshot-ceiling.md` is the reaffirm, and its single `UNLOADABLE` hit is inside the frontmatter note — **body** (157 lines, after the second `---`) carries `UNLOADABLE` **0** times and **0** pipe-leading lines, so the note's own load-bearing claim is true of the body it describes. **`readopt-override.sh --check` on all three: exit 0**, `body carries no superseded core text`. **Control:** the same gate against HEAD's pre-readopt check-5 body exits **1** and prints the stale line — so the three 0s are the gate clearing, not the gate missing. *(First invocation put `--check` before the positionals and died `line 35: 3: parameter null or not set`, exit 1 — a usage error reading as a finding, the §4 class inverted. Contract is `<dist> <theirs> <consumer> <override> --check`.)* **DEVIATION — row 7's `unregistered-drift.sh` probe is STALE, and this is a slip in this file, NOT a core defect. Recommended PROCEED.** As written (`… /Users/n8/git/ai-dlc 46aa98a .`, `EXPECT 0`) it returns **15 `HARD-UNREGISTERED-CORE-DRIFT`** — exactly the 15 tracked core files the apply rewrote. Two things establish the invocation is wrong rather than the tree: (i) `hard-blockers.sh`, which owns the canonical call, passes **four** args (`<dist> <base> <consumer> <theirs>`); with `theirs` supplied the run is **46 CORE-OK / 13 CORE-AT-THEIRS / 1 CORE-TEMPLATE-SUBSTITUTED / 2 HARD-CORE-DRIFT-ABSORBED**, and `CORE-AT-THEIRS`'s own message says "*If you expected drift here, the base is stale: post-apply, re-run with base == theirs*". (ii) The script's comment and **core's `SKILL.md` step 7 both mandate it outright** — "**Pass `theirs` as the base on this re-run, not the pull's base** … the pull's original base reports every line upstream ADDED as a consumer addition upstream absorbed — `HARD-CORE-DRIFT-ABSORBED` on a file `apply` just wrote, whose remedy is a revert to what it already is." **On the mandated invocation (`base = theirs = 3490997`): `60 CORE-OK / 3 CORE-TEMPLATE-SUBSTITUTED`, `HARD-` rows = 0` — row 7's stated expectation, met.** Control that this is not a vacuous scan: the same run still SEES and names all three substituted files (`steps/deploy-validate.md`, `team-roles/dev.md`, `team-roles/qa.md`). **Independent byte proof there is no unregistered core edit at all:** of the 62 classified core files, **59 are byte-identical to `3490997:core/<path>`** and the only 3 that differ are those same declared substitution sites — `dev.md` and `qa.md` diff against theirs in **exactly 1 hunk each**, theirs carrying the literal `- {ownership_paths}` / `- {qa_ownership_paths}` token line and graph the filled value, which is row 6's sanctioned merge and nothing else. Control: the same comparator against `46aa98a:core/steps/retro.md` reports a difference, so it is not answering identical to everything. Under the stale base those two route to `ABSORBED` only because `is_unregistered` also measures against base, so upstream's span additions read as consumer lines; the correct base routes both to `CORE-TEMPLATE-SUBSTITUTED`, the status the tool already applies to `deploy-validate.md`. **Not wedging either way:** `unregistered-drift` appears **0** times in `.githooks/pre-push` and `scripts/ci-local.sh` (control: `validate-layer-entries` appears **6** times in the same grep), so it gates `apply`, not row 9's push. **Step 7's other half, which row 7 also omits — `layer-drift.sh` re-run at base == theirs: 51 rows, `HARD-` = 0**, leaving only the 6 report-only rows already dispositioned in row 2 (2 `OVERRIDE-DOUBLE-SHADOW`, 2 `OVERRIDE-DELEGATES-INTO-SHADOW`, 2 `OVERRIDE-ASSERTS-SHADOW-SURVIVES`). **IMPOSSIBLE ZEROS, stated not counted as clean:** at base == theirs there is no range to diff, so `EXTENSION-HOOK-DRIFT` = 0 and every `OVERRIDE-DRIFT-*` = 0 are **arithmetic, not evidence** — row 5's register is the evidence those 17 were disposed; likewise the 33 `EXTENSION-OK` / 12 `OVERRIDE-OK` are inflated against row 2's 16 / 9 for the same reason. **ROW 6'S THREE NON-ZERO SCRIPTS, resolved as row 7 was asked to:** `validate-provenance-block.sh` **exit 0** (above, was 2 — the schema landed with the apply); `sync-taught-schema.sh` **exit 0** in `--check`, the mode `.githooks/pre-push:96` actually runs — `PASS — 4 taught example(s), all rendered from their schemas; 0 hand-written`; `validate-audit-anchors.sh` bare is **exit 2 = usage**, not a finding (`usage: … --render | --check <file> | --entries <file> | --trunk-push | …`) — its push-suite mode is `.githooks/pre-push:65` `printf '%s' "$PUSH_REFS" \| … --trunk-push`, which **fires for the first time at row 9 and is untested here**. **Wrote nothing to graph:** tree is still rows 3–6's 99 modified / 1 deleted / 46 untracked (39 `tests/fixtures`, 4 `scripts/ai-dlc`, 1 `.claude/skills`, 1 `.claude/schemas`, 1 `_bmad-output/ai-dlc-update`), uncommitted on `chore/ai-dlc-update-0.213.0` at `b90554891`. |
| ⏹ | **FRESH GRAPH SESSION** | graph | |
| 8 | The push-candidate ledger: close `PC-S296`, update the 3 renamed tokens | graph | ✅ **Residual `NAMED-ABSORBED` = 18, NOT 0 — the row's own tick condition is unreachable and this is a slip in this file, recommended PROCEED (detail below).** One file written: `_bmad-output/ai-dlc-update/push-candidate-ledger.md`, +42/-13. **8a — `PC-S296-LEDGER-REVERIFY-LAST-MATCH-WINS` closed `**ADOPTED UPSTREAM (v0.184.0, verified 2026-07-30)**`, against the FIX and explicitly not the citation.** `0c6ab57` ("the ledger closer read only the LAST receipt in an entry, and v0.181.0 recorded that defect as absorbed") replaces the last-match-wins scalar with an accumulator: `dn++; dv[dn]=directive` occurs **1** time at `3490997` and **0** at base `46aa98a` — which is the entry's own stated closing condition, "closes only when the parser accumulates predicates instead of overwriting one". **Deliberately NOT closed on the old token:** `directive=substr(` is still present at theirs (**2**, one code + one upstream comment about this entry), i.e. the token-anchored receipt would have reported STILL-LIVE across a real absorption — the exact false verdict the 2026-07-28 receipt repair predicted, and why `verify: manual` was correct. **Empirical proof, not citation:** running the shipping `ledger-reverify.sh` @ `3490997` against graph's live ledger, `PC-S295-RETRO-STEP5C-DEADLOCK-ON-DEFERRED-RED` — the dual-predicate entry case 2 was *filed about* — now emits **4** rows, `[receipt 1/4]`–`[receipt 4/4]`, covering BOTH the `retro.md` and the `deploy-validate.md` predicate; under the scalar only the physically-last one was ever evaluated. **Control that this is not a blanket rewrite:** exactly 2 entries carry multiple receipts (6 ordinal-tagged rows) and the other 50 rows carry no ordinal — matching upstream's own measurement on this consumer. **Control that the close FIRED and nothing else moved:** classifier **56 → 54** rows, and a `diff` of the two runs shows precisely the 2 `PC-S296` rows removed (`HAND-REVIEW` + `NAMED-UPSTREAM`) and **no other line changed**; `NAMED-UPSTREAM` **3 → 2**, `STILL-LIVE` 32 and `CLOSE-CANDIDATE` 5 unchanged, and `ENTRY-SWALLOWED` **unchanged at 3** — so the added prose split no entry span and PC-S310's own failure mode did not fire on it. The annotation is line-leading and was verified by matching `ledger-reverify.sh:533`'s literal close regex against the file (hit at ledger line 1100); mid-line backticked mentions of `ADOPTED UPSTREAM` elsewhere in the same span do NOT match it, which is why the entry kept reporting until now. **8b — 8 renames, not 3, and the split is per-item.** Renamed where the sentence makes a claim about the tool **as it is now**, or is the annotation a reader must join to a current report row: the 3 live adjudications (`PC-S296` SPLIT, `PC-S297` STILL-LIVE, `PC-S303` CLOSED-AS-REFUTED), `PC-S300`'s close annotation, and 4 present-tense mechanism claims (2 "backstop" sentences, `PC-S300`'s "for want of the signal", `PC-S310`'s "same tier and routing as"). Dated annotations use "the signal now named `NAMED-UPSTREAM`" so the 2026-07-28 record stays true while the join works. **Left, on core's OWN carve-out** — v0.186.0 left the old token in `CHANGELOG.md` and `docs/reviews/`, "historical and deliberately unchanged": 5 in the ledger (`PC-S304`'s as-filed proposal text "`NAMED-ABSORBED` or similar", its adoption receipt pinned to `46aa98a`, its "4 `NAMED-ABSORBED` rows" run tally, `PC-S310`'s quoted "real pair" output, and `PC-S310`'s receipt comment "Set measured at 46aa98a is five") + **11** in `reconcile-log-20260728T143546Z.md`, the dated log of the 0.180.0→0.183.0 pull and the direct analogue of core's CHANGELOG + **2** in `tests/fixtures/ledger-status-vocabulary/run.sh`, which is **core's own fixture** delivered by row 6's apply and whose 2 hits are a deliberate MUTANT (`sed 's/NAMED-UPSTREAM/NAMED-ABSORBED/g'`) proving the detector fires — editing it would break the fixture and is barred by the core-layer guard anyway. Rewriting any of these to reach 0 would falsify a dated measurement or a quoted output. Diff audit: **0** occurrences of the old token on any added line; **8** of the new token. **8c — honoured, and nothing was at risk:** the diff adds, removes, and rewords **zero** `verify:` lines (controlled — `grep -E '^[+-][[:space:]]*verify:'` over the diff returns none), so `PC-S296` keeps `verify: manual`. The 3 of 48 receipts carrying an apostrophe are pre-existing single-quoted `awk` programs, not prose possessives, and are untouched. **SURFACED, NOT FIXED — `PC-S310` now reports `CLOSE-CANDIDATE` and it looks like a REAL close, not the false one it predicted.** Its receipt asserts the emitted-status count is `-le 5`; at theirs the set is **6** — `ENTRY-SWALLOWED` was added. Its own comment names "an unrelated sixth status closes this without fixing it" as the false-close risk, but this sixth status is **not** unrelated: `ENTRY-SWALLOWED` is verbatim the diagnostic `PC-S310` proposed ("emit a new report-only status for every heading with no row"), and it fires on exactly the bold-colon fragments the entry named — the 3 rows are `Who whole-reads them:`, `The window:`, and `The share:`, the last being `PC-S296-WHOLE-READ-POOL`'s own case-3 example. Row 8 names only `PC-S296`, so this was left for the operator: confirm and close it, or carry it to the next pull. **Tree after row 8:** rows 3–7's edits plus this one file; `_bmad-output/ai-dlc-update/` shows `M push-candidate-ledger.md`, `M reconcile-report.md` (row 6's re-emit, untouched here — it is pinned pre-apply by design and is now stale on `PC-S296` for that reason), `?? layer-adjudication-register.jsonl` (row 5). Still uncommitted on `chore/ai-dlc-update-0.213.0` at `b90554891`. |
| 9 | Commit, push, PR, merge. Then unfreeze. | graph | — |

**Rows 4 and 5 are separated on purpose.** Both are per-item judgement at scale and neither
survives sharing a context with the other. Row 5 also cannot be done before row 6's `apply` is
*attempted* — see its section for why that is not a contradiction.

### Out of scope for this pull — surface, do not fix

Each is a **consumer decision** the pull's duty is only to report. Filing one is fine; doing it
inside this pull is not.

- **Renumbering the 5 `W5` squatters** (checks 33/34/35, rules 31/32) — wants a crosswalk row first.
- **Disposing the 4 `UNLOADABLE` checks** (`19b`, `2s`, `33`, `35`) — `33` is a retired tombstone
  whose remedy is deletion; the other three want an anchor plus `gate_types:`.
- **`story-290-1`'s stale `status: review`** — one live Check 5 drift, dormant until that story is
  in a live sprint's mapping.
- **Retiring `scripts/check-mutation-red-anchor.sh`** — fully absorbed by core's
  `validate-mutation-red.sh`, but the swap touches Check 35's prose and a test's path.
- **Retiring `scan-stray-provenance.sh`'s stray arm** — absorbed; its `--fixture-provenance` mode is
  **not** and does not move.
- **graph's override-body finding** (`steps__retro__ci-gates-enforcement-surface.md`) — already
  deferred to a sprint in graph's reconcile log.
- **Core's §5b false-exclusivity sentence** (the core defect row 5 found) — **fixed in ai-dlc
  v0.213.1**, which is LATER than this pull's pinned `3490997`. **Do NOT re-point `theirs` at the
  fix.** The pin stays `3490997`: four blocking rows hook `retro.md` (`retro-domain`, `retro-push`,
  `retro-deferral-expiry`, `retro-gate-log-rotation`), and a new sha changes their THEIRS digests,
  re-opening adjudications row 5 already banked. graph picks the fix up on its NEXT pull.

---

## 6. Rows

### Row 1 — pre-flight. In `graph`.

**Nothing here writes to graph.** Four things, and the first one is the reason this row exists at all.

**1a. The pre-push shim. If it is missing, every gate in this pull is silently disarmed.**

```bash
ls -l .git/hooks/pre-push          # expect: present, 314 bytes
git config core.hooksPath          # expect: NO output (unset)
```

**Measured 2026-07-29: present, 314 bytes, `core.hooksPath` unset [V].** graph is armed by this
untracked shim rather than by `core.hooksPath`, because setting that path would disable the gitleaks
pre-commit. **Nothing in core asserts the shim exists.** Absent, every push in this pull passes
without running a single validator, and that reads exactly like a clean push.

**STOP CONDITION:** shim absent, or `core.hooksPath` set to anything. Do not proceed and do not
"fix" it by setting `core.hooksPath` — that trades this problem for the gitleaks one.

**1b. `_bmad/` must exist** or `install.sh` aborts. Measured: present [V].

**1c. A clean tree.** `git status --porcelain` — commit or stash first. A dirty tree makes the
post-apply `cmp` comparisons in row 7 unreadable, and `_bmad-output/` churn is normal here so read
the list rather than the count.

**1d. Pin the engine, and run the classifiers from a worktree of the DISTRIBUTION at the target
sha — never from graph's installed copies.**

```bash
git -C /Users/n8/git/ai-dlc worktree add --detach /tmp/pull-engine 3490997
git -C /tmp/pull-engine rev-parse --short HEAD     # MUST print 3490997
```

**This is not a preference.** graph's installed engine is 0.183.0 and **cannot emit statuses this
pull adds** — `--strays` appears in its `validate-provenance-block.sh` **zero times** [V]. Revision 1
quoted a tally measured with the new engine while telling the agent to run the old one. Every command
in rows 2 and 7 is prefixed with `/tmp/pull-engine/core/…` for this reason.

**Tick row 1** with the shim's byte count and the worktree sha.

---

### Row 2 — classify only. Report all six tallies. Write nothing. In `graph`.

**The two classifiers take their arguments in DIFFERENT orders.** This has bitten a real run.

```bash
E=/tmp/pull-engine
# layer-drift.sh   <dist> <base> <theirs>   <consumer>
bash $E/core/skills/ai-dlc-update/reconcile/layer-drift.sh \
     /Users/n8/git/ai-dlc 46aa98a 3490997 /Users/n8/git/graph > /tmp/ld.txt
# ledger-reverify.sh <dist> <base> <consumer> <theirs>     <-- 3rd and 4th SWAPPED
bash $E/core/skills/ai-dlc-update/reconcile/ledger-reverify.sh \
     /Users/n8/git/ai-dlc 46aa98a /Users/n8/git/graph 3490997 > /tmp/lr.txt
cut -f1 /tmp/ld.txt | sort | uniq -c | sort -rn
```

**EXPECTED — `layer-drift.sh`, measured 2026-07-29 with the shipping code [V]. 69 rows:**

| Status | Count | Note |
|---|---|---|
| `HARD-LAYER-ADJUDICATION-MISSING` | **17** | **BLOCKS `apply`.** Row 5 is these. |
| `EXTENSION-HOOK-DRIFT` | **17** | one per adjudication row, by construction |
| `EXTENSION-OK` | 16 | |
| `OVERRIDE-OK` | 9 | |
| `HARD-OVERRIDE-DRIFT-SECTION` | **4** | **BLOCKS.** `readopt-override.sh --merge` in row 6 |
| `OVERRIDE-DOUBLE-SHADOW` | 2 | one deliberate collision, self-documented. Report-only |
| `OVERRIDE-DELEGATES-INTO-SHADOW` | 2 | report-only, already deferred to a sprint |
| `OVERRIDE-ASSERTS-SHADOW-SURVIVES` | 2 | report-only |

**STOP CONDITION:** any total other than 69, any status not in this table, or a count off by one.
Report it and escalate to an ai-dlc session — do not adjust the table.

**ZEROS THAT ARE STRUCTURALLY IMPOSSIBLE, not clean.** State these in your report explicitly,
because a real run has already mistaken one for evidence that work was disposed:

- **`EXTENSION-ANCHOR-DRIFT` and `EXTENSION-ANCHOR-MISSING` will be ZERO.** No graph entry declares
  `extends:`, so both are **unable to fire**. A row carrying either means an entry gained an
  `extends:` key — not that the classifier misfired.
- **`Check AP` and `Check VH` will NOT appear** in row 2's `UNLOADABLE` tally. The heading grammar is
  numeric; both are alphabetic and structurally outside what it can see. Both **are** live and
  unloadable. Their absence is not evidence they load.
- **`EXTENSION-RETIRE-CANDIDATE` will be ZERO** — measured, against a table that predicted it would
  rank third in the migration order.

**`EXTENSION-HOOK-DRIFT`'s message text changed in v0.196.0.** A prompt that greps the old wording
counts zero. **Match the STATUS token, never the sentence.**

**Then the four consumer-side tallies. Note each one's invocation trap from §4 — four of the five
false probes are in this block.**

```bash
# (i) W5 squatters — the token 'W5' is NOT in the output. Match the message.
bash $E/core/scripts/validate-layer-entries.sh /Users/n8/git/graph 2>&1 | tail -3
#     EXPECT: 0 error(s), 5 warning(s) -- checks 33/34/35, rules 31/32, all "OUT OF BAND"

# (ii) UNLOADABLE — takes a FILE, not a root
bash $E/core/scripts/validate-gate-manifest.sh \
     /Users/n8/git/graph/.claude/skills/ai-dlc/steps/gate-validation.md 2>&1 | grep -E 'UNLOADABLE|MISSING|ORPHAN|manifest source'
#     EXPECT exit 1: UNLOADABLE = 19b 2s 33 35 ; MISSING none ; ORPHAN none
#     EXPECT manifest source: overrides/steps__gate-validation__check-25-universal-core.md
#            extension gate_types: none          <-- both change in row 3

# (iii) fixture drivability — takes --dir, run from graph's root
cd /Users/n8/git/graph && bash $E/core/scripts/validate-fixture-drivability.sh --dir tests/fixtures 2>&1 | head -5
#     EXPECT exit 1: 103 directories / 73 driven / 2 declared undrivable / 28 undeclared

# (iv) Check 5's new enforcer. Run from graph's root.
#      NOTE: the shipping script needs the shipping SCHEMA. Run against graph's installed
#      copies and it dies with KeyError: 'story_key_re' -- that is a version skew, not a
#      finding. Stage both, or defer this one to row 7 where apply has landed both.
bash $E/core/scripts/sprint-status.sh check-stories 2>&1 | tail -3
#     EXPECT: PASS -- 2 comparison(s) over 2 entries, 0 finding(s)   (sprint 299)
```

**EXPECTED, all measured 2026-07-29 with the shipping code [V]:**

| Tally | Expected | Stop condition |
|---|---|---|
| `W5` warnings | **5**: checks 33, 34, 35; rules 31, 32 | a 6th, or a different subject |
| `UNLOADABLE` | **4**: `19b`, `2s`, `33`, `35`. `MISSING none`, `ORPHAN none` | a 5th, or any MISSING/ORPHAN row |
| Fixture dirs | **103 / 73 driven / 2 undrivable / 28 undeclared** | a 29th, or `declared undrivable` ≠ 2 |
| Check 5 `check-stories` | `PASS — 2 comparison(s) over 2 entries, 0 finding(s)`, sprint 299 | any finding; **exit 4 means it compared nothing and is never a pass** |

**The 2 `declared undrivable` are core's own `check-h1-recursion` and `check-manifest-bypass`.** If
either appears in the 28 findings instead, the exemption marker has diverged and **that is a CORE
defect** — stop and escalate it to an ai-dlc session.

**`--strays` CANNOT BE MEASURED HERE, and that is the finding.** graph's installed copy has the mode
zero times; it arrives with the pull. Do not run it against graph's tree in row 2 and do not read its
absence as a pass. Row 3 stages it in a **copy**. Expected there: **5 findings, all under
`scripts/tests/**`** [V].

**Tick row 2** with all six tallies, verbatim.

⏹ **FRESH GRAPH SESSION.** Report all six tallies to the operator, verbatim.

**If every tally matches its expectation, open a new `graph` session and go to row 3.** No ai-dlc
session is involved — nothing has deviated, so there is nothing to adjudicate.

**If any tally deviates, or any stop condition fired: STOP.** Open a session in
`/Users/n8/git/ai-dlc` with the deviation and let it rule — core defect or consumer decision —
**before** row 3 writes anything. This is the last point at which nothing has been written.

---

### Row 3 — the two mechanical pre-apply edits. In `graph`.

Both are **required**, both are mechanical, and both were verified end to end on a **copy** of graph
on 2026-07-29 [V]. Two edits, then two verifications.

**3a. Register `scripts/tests/**` as a party-mode home. WEDGES THE PUSH if skipped.**

One line into `.claude/skills/ai-dlc/extensions/known-skills.json`, which already exists carrying
`known_skills`:

```json
"party_mode_homes": ["scripts/tests/**"]
```

**Verified on a copy [V]:** before, **5 findings**, every one under `scripts/tests/**` — a consumer
test-harness tree carrying sample blocks inline. After, `--strays: PASS`, **893 file(s) carried the
envelope**.

**STOP CONDITION:** a 6th finding, or one **outside** `scripts/tests/**`. **Do NOT widen the homes to
make it pass.** A home added because it currently reports a finding is an exemption wearing a
performance argument, and the tree it would hide is graph's product source.

*(The recorded figure was 889 carriers; **893** is current. The finding count and subject are
unchanged, so the drift is in files added since, not in the gate.)*

**3b. Retire `overrides/steps__gate-validation__check-25-universal-core.md`. REQUIRED, not optional.**

```bash
git rm .claude/skills/ai-dlc/overrides/steps__gate-validation__check-25-universal-core.md
# then add to the frontmatter of extensions/checks/gate-validation-domain.md:
#   gate_types: implementation
```

**Why it is required and not a suggestion.** That override is **132 lines** carrying an entire
section's `base_sha` drift in order to add one integer to one table cell — and its own first line,
*"Identical to core, with one change"*, is **FALSE**: it drops core's canonical gate-type enum
(`planning · story · implementation · sprint-review · retro`) and the deployment/schema paragraph.
**graph has been running gates against a rendered document with no gate-type enum in it.** Retiring
restores both. v0.197.0's `gate_types:` on check extensions exists precisely to make this possible.

**Verified on a copy with the shipping code [V]. Expected after:**

```
manifest source: core                        (was: the override)
extension gate_types: 34->implementation     (was: none)
MISSING none ; ORPHAN none
exit 1 for the four UNLOADABLE rows ONLY
```

**STOP CONDITION:** any `MISSING` or `ORPHAN` row. That means the tree moved and this instruction is
stale — **do NOT re-author the override to make it pass.**

**Tick row 3** with `--strays: PASS (N carriers)` and the `manifest source:` line.

---

### Row 4 — the 28 fixture declarations. In `graph`. **Its own graph session.**

**WEDGES THE PUSH if skipped**, and this is the row most likely to be done wrong rather than left
undone.

v0.202.0 added a `fixture drivability` step to the consumer pre-push. Each of the 28 undeclared
directories wants **one** of two one-line declarations, and **which one is a per-directory judgement
you must make**:

1. **a `run.sh`** — two lines delegating to the harness that already drives it. This also puts that
   harness into the push suite instead of a hand-maintained `ci-local.sh` trigger, which is a real
   gain, not a formality.
2. **a `README.md`** carrying ``No `run.sh`, deliberately`` and the reason — for a fixture no script
   can drive. It is evidence an LLM reads at a gate.

**THE HAZARD, and it is the whole reason this row has its own session.** Route 2 over a fixture that
**has** a driver is a false statement **the script cannot detect and will accept**. Under push
pressure it is also the faster route for all 28 — which would convert one real finding into 28 silent
exemptions and leave the consumer exactly where it started. **Do not batch-apply route 2.**

**A starting classification — and it is [R], a CITATION, not a proof.** Derived by
`git grep -lF "fixtures/<name>"` over graph restricted to executables. **A script that names a
fixture is not necessarily a script that drives it.** Confirm each one before acting on it.

- **14 cite an executable driver** (route 1 likely): `check-cycle-types-bypass`,
  `check-ff-escalation`, `check-il-oracle-presence`, `check-substrate-audit`, `cycle-commits`,
  `detectors`, `exclusion-importer`, `live-contract-probe`, `live-shape`, `phase-sequencing`,
  `pipe-exit-mask`, `provenance-in-non-retro`, `retro-replay`, `rule-ref-reconcile`.
- **14 cite none** (route 2 likely; most are evidence for LLM-read `check-*` gate checks):
  `boundary`, `check-7-arch-content`, `check-18-runtime-constraints`, `check-19-disposition`,
  `check-20-doc-check`, `check-21-section0`, `check-26-deployed-ranges`, `check-27-config-integrity`,
  `check-30-orphaned-fn`, `check-31-cited-sha`, `check-35-mutation-red-reachability`,
  `check-a52-sprint-pr-merge`, `compute`, `retro-audit`.

**`boundary` is the one most worth re-reading.** It cites `scripts/regen-boundary-fixtures.sh`, which
**REGENERATES** it rather than driving it — which is why it sits on the route-2 side. That distinction
is exactly the one the citation cannot make for you.

**On `retro-replay`:** graph's `scripts/retro-replay-harness.sh` and its `scripts/tests/test-*.sh`
siblings are **NOT absorbed** by core — that arm's "registrable entry point" premise was refuted.
They stay where they are; a `run.sh` delegating to them is now the sanctioned way into the push suite.

**Verify after, from graph's root:**

```bash
bash /tmp/pull-engine/core/scripts/validate-fixture-drivability.sh --dir tests/fixtures
#   EXPECT exit 0 and `0 undeclared`. Those two are the load-bearing halves; the
#   driven/undrivable SPLIT follows the routes and is NOT 2. Every route-2 README
#   increments `declared undrivable`, so it is 2 + (route-2 count) — the 2 pre-existing
#   exemptions plus one per README you write. Measured on the split row 4 actually took
#   (20 run.sh / 8 README.md): 103 directories / 93 driven / 10 declared undrivable /
#   0 undeclared, exit 0.
```

**Tick row 4** with the count that went each route — `N run.sh, M README.md, N+M = 28`.

⏹ **FRESH GRAPH SESSION.** 28 judgements is a full context. Open a new `graph` session for row 5;
do not continue into it here. Still graph — this is context hygiene, not a repo switch.

---

### Row 5 — the 17 adjudications. In `graph`. **Its own graph session.**

**BLOCKS `apply`. There is no skip flag, deliberately.** This is *the layer conformance
adjudication*, shipped in v0.213.0 as `level: ADJUDICATED` — the newest and largest obligation in
this pull, and the one no earlier revision mentions.

**What it is.** `EXTENSION-HOOK-DRIFT` means the core file an extension hooks changed, and an
extension has no section anchor, so nothing can locate what to re-merge. The verdict is **yours**:
the candidate set is mechanized, the judgement is not. Before v0.213.0 this was a `WARN` that
reprinted every pull with no way to say "this one was read" — so the worklist got cleared rather than
read. Now skipping it is a blocked pull instead of a silent one.

**Read the entry against the new core text and record one verdict per row:** `still-additive`,
`contradicts-core`, or `retire`.

**How to record.** One JSON object per line in
`_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl` (shape:
`.claude/schemas/layer-adjudication-register.json`), copying `subject_digest` **verbatim from the
blocking row**:

```json
{"clause":"LC-E4","entry":".claude/skills/ai-dlc/extensions/checks/gate-validation-domain.md","subject_digest":"<copied from the row>","verdict":"still-additive","recorded_utc":"2026-07-30T09:00:00Z","reason":"core's change was to the gate-type enum; this entry adds a check row and does not restate it"}
```

**Four things that will bite:**

1. **Do not re-derive the digest.** It covers the entry **and** the hooked core file at `theirs`.
   Copy it from the row. A digest computed two ways is a digest computed wrong.
2. **A verdict is spent when either side moves.** It is a record of a reading, **not an exemption for
   the path** — which is the entire reason the register is keyed per subject and not per run.
3. **The verdict must be one of the three.** Anything else does not discharge the duty; the schema's
   enum is what the enforcer reads.
4. **Changing your mind is allowed and must be declared.** A second record under one key with a
   different verdict needs `supersedes` **and** `reason`, or it is `HARD-REGISTER-CONTRADICTION`.

**`jq` must be on PATH.** Without it the register cannot be read, and the enforcer treats that as
blocking rather than as an empty register — a register that cannot be read is not a register with
nothing in it.

**Why this row can precede `apply` even though it reports on incoming core.** The classifier reads
`theirs` from the pinned distribution, not from graph's working tree. Every one of the 17 rows is
computable — and recordable — before a single core byte is written. That is the point of doing it
here rather than mid-apply.

**Verify: re-run row 2's `layer-drift.sh` command.**

```
EXPECT: 0 HARD-LAYER-ADJUDICATION-MISSING
        17 EXTENSION-HOOK-DRIFT   <-- UNCHANGED. This row must NOT go quiet.
```

**The second line is the load-bearing half.** The candidate row still prints once adjudicated; only
the blocking row disappears. If `EXTENSION-HOOK-DRIFT` dropped to zero, the clause's declared code is
being emitted by nothing and the clause has become unfalsifiable — **report that as a core defect.**

**Tick row 5** with the verdict split — `N still-additive, M contradicts-core, K retire, sum = 17`.

⏹ **FRESH GRAPH SESSION** for row 6.

---

### Row 6 — `apply` on one branch. In `graph`.

**One branch, machinery and rulebook together.** Locked in §2; the reason is that the update skill's
own self-update cycle installs a validator that blocks its own push, so a split lands a tree that
cannot be pushed. Precedent: PR #829.

```bash
git checkout -b chore/ai-dlc-update-0.213.0
```

**Before `apply`, run the blocking list and read it.** `apply` must not be approved against a report
that dropped a line:

```bash
E=/tmp/pull-engine
bash $E/core/skills/ai-dlc-update/reconcile/hard-blockers.sh \
     /Users/n8/git/ai-dlc 46aa98a /Users/n8/git/graph 3490997
```

**EXPECTED after rows 3–5: the 3 remaining `HARD-OVERRIDE-DRIFT-SECTION` rows and NOTHING ELSE.**
Row 2 measured **4** on the pre-row-3 tree; row 3b's required `git rm` of
`overrides/steps__gate-validation__check-25-universal-core.md` retires one of them, so 3 is the
count that survives rows 3–5 and 4 here would be stale arithmetic, not a missing blocker. The 17
adjudication blockers are discharged by row 5's register; if any still appears, row 5 is incomplete —
go back, do not proceed. `hard-blockers.sh` derives its list from the detectors by design, so a
blocker missing from a hand-written report is a blocker you would approve without seeing.

**The 3 drift-section blockers go through `readopt-override.sh --merge`,** one at a time. Each is an
override whose shadowed core section changed in this span — upstream's new text and the consumer's
override both need to survive, and that is a merge, not a pick.

Then run the pull itself (`/ai-dlc-update`, or `reconcile/apply.sh` per the skill's step 6). **The
new core files must be in the write set** — a new core file silently not written is indistinguishable
from one written correctly. At minimum, confirm afterwards:

```bash
test -f .claude/schemas/layer-adjudication-register.json && echo present || echo MISSING
test -f .claude/skills/ai-dlc/layer-contract.yaml        && echo present || echo MISSING
```

**Flagged-block checkpoint applies.** Any block carrying `needs_operator_confirmation: true` stops
here and asks — being inside an authorized `apply` does not waive a judgement the classifier flagged.

**Tick row 6** with the branch name and the blocker count you cleared.

---

### Row 7 — post-apply verification. In `graph`.

**Read the LABEL, not the exit status,** on every `cmp` below. The two branches assert *opposite*
things before and after apply, and revision 1 shipped a success-branch label that was
self-contradictory.

```bash
E=/tmp/pull-engine
cat .claude/.ai-dlc-version        # BOTH pairs must read 0.213.0 @ 3490997

# the flip: graph's installed validators must now be IDENTICAL to the distribution's
for s in validate-layer-entries.sh validate-gate-manifest.sh validate-provenance-block.sh \
         validate-fixture-drivability.sh sprint-status.sh; do
  if cmp -s "scripts/ai-dlc/$s" "$E/core/scripts/$s"; then
    echo "IDENTICAL  $s   <-- required AFTER apply"
  else
    echo "FORKED     $s   <-- stop and report"
  fi
done

# --strays is now REAL here for the first time (row 3 measured it on a copy)
bash scripts/ai-dlc/validate-provenance-block.sh --strays
#   EXPECT: PASS, ~893 carriers

bash $E/core/skills/ai-dlc-update/reconcile/unregistered-drift.sh \
     /Users/n8/git/ai-dlc 46aa98a . > /tmp/unreg.tsv 2>/dev/null
grep -c '^HARD-' /tmp/unreg.tsv    # EXPECT 0
```

**EXPECTED — and this is where revision 2's numbers do NOT carry forward.** Measured on a copy at
`170ff9d8c` with the shipping code after rows 3–5 [V]:

```
validate-layer-entries: 0 error(s), 5 warning(s)      exit 0
```

**Revision 2 expected `exit 1` with 3 `ERROR` lines and called that "the expected, correct
outcome."** That was true for 0.183.0, whose ERROR tier was brand new and had three live subjects.
**Those three were fixed in that pull.** At 0.213.0 the correct outcome is **exit 0** with the 5 `W5`
warnings and no errors. **A non-zero exit here is a real finding now, not a success.** This is the
single most important difference between the two revisions.

**ZEROS THAT ARE STRUCTURALLY IMPOSSIBLE POST-APPLY — state them, do not count them as clean.**
After `apply`, **`base` equals `theirs`**, so:

- **`EXTENSION-HOOK-DRIFT` and roughly 8 of 13 statuses cannot fire at all.** There is no range left
  to diff. A real run mistook this for evidence the re-reads had been disposed. **It is not.** Row 5's
  register is the evidence they were disposed; this zero is arithmetic.
- The same applies to every `OVERRIDE-DRIFT-*` status.

**Then verify against the RENDERED pipeline, never against core alone.** A core fix is effective only
if it survives `overrides > extensions > core` resolution. For every override re-adopted in row 6,
grep the **override** for the new clause — that is the text the lead actually obeys. Core containing
a fix proves nothing about a section the consumer shadows.

**Run the fixture suite.** It now includes graph's own directories plus whatever row 4 wired in:

```bash
bash scripts/ai-dlc/validate-fixture-drivability.sh --dir tests/fixtures   # EXPECT exit 0
```

**Tick row 7** with the version line, the five `IDENTICAL` labels, and the linter's footer verbatim.

⏹ **FRESH GRAPH SESSION** for row 8.

---

### Row 8 — the push-candidate ledger. In `graph`.

Three edits, all mechanical, all in
`_bmad-output/ai-dlc-update/push-candidate-ledger.md`.

**8a. Close `PC-S296` as `ADOPTED UPSTREAM (v0.184.0)`.** The operator's SPLIT determination drove
that fix and it closes the case that kept the entry open. **Note the recorded trap:** v0.181.0 wrote
`PC-S296` as "absorbed v0.153.0" in core's CHANGELOG *and* in a comment inside `ledger-reverify.sh` —
a **citation read as a fix**. The anchoring closed one arm while the entry's actual subject stayed
live until v0.184.0. Close it against the fix, not against the citation.

**8b. Update the 3 `NAMED-ABSORBED` annotations to `NAMED-UPSTREAM`.** v0.186.0 renamed the status
because the old token contradicts its own header and misled its author. Core no longer carries the old
string outside `CHANGELOG.md` and `docs/reviews/` — both historical and deliberately unchanged — so a
consumer-side grep for it is unambiguous:

```bash
grep -rn 'NAMED-ABSORBED' _bmad-output/     # EXPECT exactly 3, all in the ledger
```

**There is no detector for this**, deliberately: `retired-tokens.sh` matches only `$VAR/path` shapes
in the CLASSIFY bucket, and `retired-layer-contract.sh`'s subject set excludes
`ai-dlc-update/SKILL.md` where the status vocabulary lives. **If you skip 8b, nothing will tell you.**

**8c. When writing any `verify:` receipt — no apostrophes.** `ledger-reverify.sh`'s awk program is a
single-quoted shell string. The file warns about this three lines above where the last change landed,
and that change still wrote `PC-S296's` and failed to parse.

**Tick row 8** with the grep count for the old token — it must be **0** after.

---

### Row 9 — commit, push, PR, merge. Then unfreeze. In `graph`.

**Push in the background.** graph's pre-push runs its whole fixture suite; a foreground push hits the
tool timeout. Redirect to a log, poll for a sentinel, and **verify with
`git ls-remote --heads origin <branch>`** — never by trusting a piped exit code.

```bash
( git push -u origin chore/ai-dlc-update-0.213.0 > /tmp/push.log 2>&1; echo "PUSH_RC=$?" >> /tmp/push.log ) &
# poll for PUSH_RC, then:
git ls-remote --heads origin chore/ai-dlc-update-0.213.0
```

**If the pre-push refuses, read which gate.** All three wedging gates were closed in rows 3–5; a
refusal means one of them regressed, and the remedy is the finding — **never `--no-verify`**.

**One known-flaky class, and the correct response to it.** Two core fixtures
(`layer-readopt-gate`, `apply-drift-refile`) have gone red **once** each under a parallel suite and
green on every rerun. The failure is **cold-start correlated** and the shared factor is the runner, not
either fixture. A re-push is correct **only after showing the release cannot reach the fixture** —
grep every file the pull touched against the fixture, with a control proving the grep matches
something. `--no-verify` is never the answer.

**graph's `ci-local.sh` has two pre-existing failures on main** — shellcheck on four `scripts/*.sh`,
and `server-fixture-manifest` — **unrelated to this pull [R, operator-reported]**. Do not attempt to
fix them here; confirm they predate the branch and say so in the PR.

**The PR body should carry:** the six row-2 tallies, the verdict split from row 5, the route split
from row 4, and the four items from §5's out-of-scope list as explicit follow-ups so they are filed
rather than forgotten.

**After merge: the freeze ends.** Say so to the operator — no sprint has run in graph for the duration
of this program, and rows 1–11 of the distribution-side program are all closed.

**Tick row 9** with the merge sha. **That closes the pull, and with it the layer contract program.**

---

## 7. Known-open, deliberately out of scope

These are recorded so a later session does not re-open them as defects. Each is a real gap with a
stated reason for not closing it here.

- **`contract_version` and `conforms_to` have no reader anywhere in the tree.** The retro-application
  rule the contract states — an entry declaring `conforms_to: N` is held only to clauses with
  `since <= N` — is enforced by nothing, and no consumer entry declares `conforms_to:` today. I41/I42
  keep the declaration coherent; they do not build the reader.
- **`layer-drift.sh`'s status list in `ai-dlc-update/SKILL.md` is prose nothing binds.** It silently
  lagged one status behind from v0.187.0 to v0.192.0. The fix is I39's shape one detector over, and its
  false-positive set is **unmeasured** — the same grammar over the whole file matched 20 tokens when
  I39 tried it, 15 of them other detectors'. Measure before writing it.
- **A retired STATUS token in a consumer layer file has no detector** — this is why row 8b is a manual
  step. Covering it means widening `retired-layer-contract.sh`'s subject set, whose FP set across every
  shape it already extracts is unmeasured.
- **`Check AP` and `Check VH` are outside GM1's subject set.** The heading grammar is numeric. Both are
  live, both carry a real Scope line, and both are unloadable today. Widening is bound to
  `relabel-extension-checks.sh` by I34 — a detector that finds a heading the rewriter cannot rewrite
  reports a defect with no remedy.
- **An override asserting IDENTITY rather than survival has no detector.** v0.187.0's predicate needs a
  scope phrase whose noun is the shadowed grain; `check-25-universal-core`'s *"Identical to core, with
  one change"* has none. Row 3b removes the reason that override exists rather than detecting its
  claim — which is why retiring it is required rather than optional.
- **`--audit-diff`'s citation arm is not bound to the touch it clears.** `pending.md` accumulates, so
  three legacy citations from S298/S299 clear every future in-place core edit. Binding it needs a
  predicate core can derive, and the FP set is unmeasured because the reference consumer has no
  *authorized* in-place core edit to measure against.
- **The crosswalk table's completeness has no clause, deliberately.** Core cannot see which numbers a
  consumer has written into evidence — gate logs, retros, escalations, most of them rotated into
  archives. If it is ever mechanized it will be from the **consumer** side.
- **`enforcement-map.yaml` is copied by `install.sh` but appears nowhere in `core-manifest.md`** — an
  unmanifested core file, so consumer edits to it are not drift-scanned.
