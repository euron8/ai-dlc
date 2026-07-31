# Post-program gap closure — plan

**Successor to `docs/analysis/layer-contract-program-handoff.md`, which is COMPLETE and must not be
deleted.** That file records what was built and — more valuably — what was measured and refuted.
This file does not restate it, supersede it, or re-open any decision it closed.

**Point a fresh Claude Code session at this file in `/Users/n8/git/ai-dlc`.**

Tracked on purpose. The predecessor claimed it was untracked because "committing it would need a
version bump per edit"; false against the tree — `docs:` and `chore:` subjects ship without a bump,
and the predecessor was tracked anyway. Ticking this ledger is a `chore:` commit.

---

## ▶ NEXT STEP — where the program is right now

**Updated as the last act of every row. If this block is stale, the row that moved the program did
not finish.**

> **Next: row 7** (§6.7) — I38's reverse direction, every normative sentence carries a clause id.
> Fourth in §5's ranking, now that row 9 is SHIPPED as **v0.216.0**. Rows 1–6, 8 and 9 are ticked;
> **row 7 is the last one before row 10, which is an operator decision rather than a session.**
>
> **Who: an agent, in a fresh `ai-dlc` session.** No operator decision is pending. Working directory
> `/Users/n8/git/ai-dlc`. Paste:
>
> ```
> Read docs/analysis/post-program-gap-closure-plan.md in full, then execute row 7.
> Rows 1-6, 8 and 9 are ticked. Normalise overrides/README.md's clauses into the
> bold-led bullet form FIRST — the predicate cannot fire on half its subject
> otherwise, and a check that cannot fire reads exactly like one that passed.
> Measure the 41 -> 40 clause delta as part of this row; it is the number that
> says whether the arm is worth its release.
> Row 7's recorded blocker is that overrides/README.md has zero bold-led bullets.
> Three rows running, the recorded blocker was a claim that died on being opened.
> Check that one before you build around it.
> ```
>
> **The carry-forward from rows 6, 8 and 9, and it has now paid three times:** each row's recorded
> blocker was a claim, and opening the file it named refuted it. Row 8's named the wrong invariant;
> row 6's named a grain with **zero adoption in the consumer and no legal way to adopt it**; row 9's
> named 8 false positives that were **all the extractor's own grammar, five of them produced by the
> validator file itself**. Before treating any recorded "blocked on X" in this file as a constraint,
> check that X is what the record says it is. **Row 7 carries the last unverified one.**
>
> **Row 9's carry-forward, which is about fixtures rather than about this program:** a guard sitting
> downstream of a liveness probe can only be tested on an input the probe still passes. An arm that
> breaks the shared extractor trips the probe first and reports a defect in a mechanism that is
> working. It is stated in `enforcement-map-sites/run.sh`'s own arm 4 now, not only here.
>
> **Row 6's carry-forward for anyone who later re-opens `LC-N5`:** the clause's exclusion has a
> measured hole. It is stated in `validate-layer-entries.sh`'s own header now, not only here.

---

## 0. How to use this file, and WHICH REPO YOU ARE IN

1. Read §1–§4 in full. Short, and every line is load-bearing.
2. Read the **Progress Ledger** (§5) for the next unticked row.
3. Read that row's section in §6, execute it, tick the ledger with a sha or a measured count as the
   last act. A fresh session's only way to know where it is.
4. **Update the `▶ NEXT STEP` block at the top of this file in the same commit as the tick.** The
   tick says where the program has been; that block says what to do next, and only one of the two
   survives a fresh session's first read.
5. Stop at a **`⏹ SESSION BOUNDARY`**.

### `▶ NEXT STEP` blocks — the operator never reconstructs a handoff from conversation

**Every point at which this program needs a human carries a `▶ NEXT STEP` block naming the working
directory and the literal prompt to paste.** This was missing through rows 4 and 5: both handoffs
were assembled in chat, the operator had to ask for the prompt twice, and nothing in the file would
have told a fresh reader what to do. **A reply that reports a row complete without pointing at one of
these blocks is the same defect** — the file, not the conversation, is where the next action lives.

Two kinds, and they are the only two:

- **`▶ NEXT STEP — OPERATOR`** — a human must act: open a session in a *different* repo, approve a
  merge or a push, or make a call the agent is barred from making. Carries the cwd and a fenced,
  paste-able prompt.
- **`▶ NEXT STEP — AGENT`** — the current session carries straight on, or a fresh session in the same
  repo does. No human decision is pending, and the operator's only job is to start it.

**A row whose section carries neither is unfinished.** Rows 6–10 each carry one.

**What is an OPERATOR step and what is not.** Opening a fresh session is not by itself an operator
decision — say `AGENT` and give the prompt. Reserve `OPERATOR` for: a repo switch, a merge or push
(CLAUDE.md's Deployment Rule (b) puts merge after operator approval and no agent may self-authorize
one), lifting or imposing the freeze, and any point where a stop condition fired and the remedy is a
judgement call between core defect and consumer decision.

### Every row runs in `ai-dlc` except row 5.

Stated once and plainly, because the predecessor's brief used one marker for two unrelated things
and its operator read it as a repo switch (`ae72f06` is the fix):

- **Rows 1, 2, 3, 4 and 6–10 run in a session whose working directory is `/Users/n8/git/ai-dlc`.**
- **Rows 1 and 3 READ graph.** They run from an ai-dlc session and write nothing to that tree.
  Reading another directory is not "running in" it. If a row would write to graph, it is the wrong
  row.
- **Row 5 is the only graph row.** Working directory `/Users/n8/git/graph`, operator-driven, against
  the brief row 4 produces. Row 4 *writes* that brief; it does not execute it.
- **`⏹ SESSION BOUNDARY` is context hygiene, not a repo switch.** It means the current session is
  full. Start another session **in the same repo the next row names** and carry on.

**A core defect found while executing row 5 is fixed in ai-dlc and re-delivered — never patched in
graph.** That is the only reason row 5 hands control back, and it is a new ai-dlc session, not an
edit from the graph one.

**Discipline is NOT restated here.** Repo `CLAUDE.md` binds, and the predecessor's §3 carries the
traps this program measured. Read both. Restating a mechanism is this repo's named defect — a
restatement drifts tighter, invisibly — so this file points rather than copies.

**Fidelity tags.** **[V]** measured 2026-07-30 with a control, in the assessment that produced this
file. **[R]** carried from the predecessor or a graph session's report, **not** re-verified. Two [R]
premises were falsified during the last program and five of one row's six design choices died on
contact with a measurement. Verify before building.

---

## 1. State at handoff

| | |
|---|---|
| `ai-dlc` main | `04cea81`, VERSION **0.214.0**. Both validators exit 0; **87/87 fixtures pass** **[V]** |
| `graph` consumer | `18e00ef40`, stamped **0.214.0 @ 04cea81** on both pairs **[V]** |
| Predecessor program | 12 rows closed; 27 merge shas all ancestors of `main` (control: `main` is not an ancestor of `main~1`) **[V]** |
| Layer contract | **40 clauses**, all carrying `enforcer:` + `code:`. 21 ERROR / 17 WARN / 4 ADJUDICATED, `contract_version` 7 **[V]** |
| **graph freeze** | ~~RE-IMPOSED, operator-directed 2026-07-30.~~ **LIFTED at row 5, 2026-07-30, merge `39f0248ff` (PR #833). Sprint work in graph may resume. Rows 6–10 do not touch graph and run against a live consumer.** graph is now at `39f0248ff`, still stamped 0.214.0 @ 04cea81 |

**The freeze is the scarce resource in this plan, and only §6 rows 4–5 need it.** Row 1 reads graph
read-only. Rows 2 and 6–10 do not touch it at all. Sequence accordingly: get the graph batch done,
unfreeze, then finish core unfrozen. Do not hold the freeze open for a core measurement.

---

## 2. The finding that reorders everything: the pull retired nothing

Locked decision 4 of the predecessor read *"Absorb the 8 duplicate consumer scripts alongside the
contract — ~3,000 lines retired as core grows one arm each."* Six arms shipped, two were refuted.

**Measured in graph today [V]:**

| Consumer subject | Lines | Absorbed by | Still wired into |
|---|---|---|---|
| `scripts/check-protected-core-paths.sh` | 162 | `core-paths.sh --audit-diff` (v0.199.0) | **Check 34**, `gate-validation-domain.md` |
| `scripts/check-mutation-red-anchor.sh` | 72 | `validate-mutation-red.sh` (v0.200.0) | **Check 35**, same file |
| `scripts/scan-stray-provenance.sh` | 155 | `validate-provenance-block.sh --strays` (v0.198.0) — **stray arm only**; `--fixture-provenance` is deliberately NOT absorbed | same file |
| `scripts/retro-replay-harness.sh` | 97 | the fixture-drivability convention (v0.202.0) | `ci-local.sh` + same file |
| `scripts/generate-sprint-status.py` | 1068 | `sprint-status.sh check-stories` (v0.203.0) | `ci-local.sh` |
| `scripts/validate-no-direct-main-push.sh` | 46 | `--trunk-push` + pre-push arm 0 (v0.201.0) | **nothing** — dead code |
| **Total** | **1600** | | **0 lines retired** |

**And the pull's net effect on graph [V]:** `+11,326 / −1,553` across 188 files = **net +9,773**.
Decomposed: core-delivered fixtures `+5,339`, core-delivered `scripts/ai-dlc` `+2,504`, rulebook
`+2,145`, **consumer-authored fixture declarations only `+438` across the 28**.

**Read that decomposition honestly.** The bulk of the growth is core machinery arriving, which is
what a pull is for, and the consumer-authored addition is small. **The failure is narrower and worse
than line count: graph now runs two implementations of the same four checks, and four of the six
superseded scripts are still wired into live gates.** Two implementations of one predicate can
disagree at a gate, and the consumer has no way to know which one is authoritative. A capability
shipped without its retirement is not a completed absorption — it is a fork with a release note.

**The consolidation that makes this tractable [V].** Three separate items collapse onto one file:

- **Check 33** — `### 33. … — RETIRED.` A tombstone. A `W5` squatter and `UNLOADABLE`.
- **Check 34** — *Protected-core-path pre-flight*, i.e. `check-protected-core-paths.sh`. A `W5` squatter.
- **Check 35** — *Gate-1 mutation-red anchor reachability*, i.e. `check-mutation-red-anchor.sh`. A `W5` squatter **and** `UNLOADABLE`.

So the retirement batch also disposes **3 of the 5 `W5` squatters and 2 of the 4 `UNLOADABLE`
checks**, in `extensions/checks/gate-validation-domain.md`. It shrinks `LC-N5`'s live subject set
from 5 to 2 — which is why retirement now precedes the `LC-N5` tightening rather than following it.

---

## 3. Outcome criterion — what "done" means for this program

The predecessor was judged on capability shipped and scored 12 of 12. Judged on the consumer, it
retired nothing. This program is judged the other way round:

1. **Duplicate enforcement paths = 0.** No consumer script implements a predicate a shipped core
   validator already implements. Measured per subject, with the core absorber run against the
   consumer's real inputs — never by citation.
2. **Net consumer surface goes DOWN.** Report `+added / −removed` on graph for this program's own
   changes. A row that adds consumer surface states why, and "the gate demanded it" is a reason to
   question the gate.
3. **`W5` and `UNLOADABLE` counts go down, or their remaining members are dispositioned in writing.**
4. **Each retirement is falsifiable.** The check that the duplicate is gone is a probe a later pull
   re-runs, not a checkbox in a merged PR body.

**A row that cannot move one of these four does not justify the freeze.**

---

## 4. How a row ends — three outcomes, all first-class

The predecessor invented its verdicts mid-flight ("PARTIAL, and the remainder is closed, not owed",
three times). Declared up front here:

- **SHIPPED** — a release or a graph merge, with a mutant proving each new check fires and a
  measured false-positive set, empty or enumerated.
- **REFUTED** — the measurement says do not build it. **Recording is the row's deliverable**: the
  predicate tried, the subject set measured, the control used, the reason. A refutation not written
  down gets re-proposed.
- **RETIRED** — a mechanism is deleted and something re-tests that it stays deleted.

**Refuted rows are recorded here and in the CHANGELOG, and indexed by row 2.** No new register: the
predecessor's row 11 register is per-*entry* adjudication and is the wrong home **[V]**, and I37
forbids a clause with no mechanism so `layer-contract.yaml` cannot hold one either.

---

## 4a. Premises this plan deliberately does NOT carry forward

**The full list lives in the predecessor's `## 0a. Refutation Index`** — every refutation the last
program measured, one line each, with the release and the failed predicate. Row 2 built it. Read it
before re-proposing anything below; this section is the short form.

- **The machinery home's ERROR clauses stay refuted.** **Eight** candidate predicates measured, all
  failed **[V — recounted from the predecessor's own §7.6 table by row 2; the "seven" this section
  carried was an undercount]**. Do not re-attempt on a path scan, a name shape, a layer-entry
  citation, a gate-check invocation, a fixture-dir complement, a `fixtures:` declaration, a basename
  collision, or a `settings.json` hook command. One untried direction is row 10; it is unmeasured.
- **`RENUMBER-BAND --apply` and `layer-relocate.sh --apply` stay closed** — tools for refuted clauses.
- **"6,118 lines of consumer ai-dlc machinery" is [R]** and presupposes the predicate that does not
  exist. What is measurable **[V]**: 75 `scripts/*.sh`, 295 files under `scripts/lib` +
  `scripts/tests`, 13 `.claude/hooks`, and `scripts/ai-dlc-local/` does not exist.
- ~~**`EXTENSION-HOOK-DRIFT` at "31 of 76 pulls" is still [R].**~~ **CLOSED by row 1 [V]:
  34 of 78 pulls** (13/32 pre-v0.60, 21/46 post). Control: all 44 logs lacking the code still match
  the universal token `ai-dlc`, and a bogus code matches 0. The [R] figure was accurate.

---

## 5. Progress Ledger

**The next unticked row is the next thing to do.** `—` = not started. Freeze-bearing rows are marked.

| # | Row | Kind | Freeze | Status |
|---|---|---|---|---|
| 1 | **Re-derive the four metrics that justified the whole program** — §6.1 | MEASURE | no | **DONE 2026-07-30** — corpus 78+10, baseline's 76/32/44 reproduced. clean-pull **30/32 → 22/44** (baseline 30/32 → 17/44; post grain unrecoverable); prose **4.3 → 5.7 kB** whole-log, **0.3 → 0.7 kB** sections (baseline 3.8 → 8.3 kB; grain unrecoverable); `NEEDS-REVIEW`+`HAND-REVIEW` **0 → peak 22 → 15 today** (baseline 38, unreproducible at any commit); re-litigation **4 of 9** (baseline 6 of 9, overstated); `EXTENSION-HOOK-DRIFT` **34/78** ([R] 31/76 → **[V]**). Metrics 1 and 3 measure detector arrival (v0.60.0, v0.122.0), not pull health. Archiving confound **REFUTED** — 15 both sides of the rotation. graph read-only, `18e00ef40` untouched |
| 2 | **Disarm the predecessor's self-delete; index its refutations** — §6.2 | PRESERVE | no | **DONE 2026-07-30** — delete-licence and false-untracked claim removed (both greps 0 against controls returning 3 / 16 / 1); §0 rewritten as a completed-program record; **`## 0a. Refutation Index` added — 8 machinery-home predicates, the band ERROR + `RENUMBER-BAND --apply`, `layer-relocate.sh --apply`, `--is-consumer-machinery`, absorption arms 1 and 4, arm 8's refuted NAME, §7.9's value claim + subject-set-of-1, row 11's 5 design choices, `silent once recorded`, and §4's 3 pre-program falsifications**. §4a repointed; its "seven" machinery predicates recounted to **8** from the predecessor's own table. Weakness stated in the index: nothing enforces that a reader consults it. `docs:` commit, no version bump |
| 3 | **Derive the retirement set with controls — per subject, is the core absorber actually drop-in?** — §6.3 | MEASURE | no | **DONE 2026-07-30** — 6 subjects, each verdict backed by a run of the core absorber against the consumer's real inputs on a case that should PASS **and** one that should FAIL. **RETIRE 2 / PARTIAL 1 / REFUTED 3.** RETIRE: `check-protected-core-paths.sh` (162), `check-mutation-red-anchor.sh` (72). PARTIAL: `scan-stray-provenance.sh` (stray arm only, ~110 of 155). REFUTED: `retro-replay-harness.sh`, `generate-sprint-status.py`, `validate-no-direct-main-push.sh` — **1,211 of the 1,600 lines §2 tabulated are not absorbed by anything**. §6.3's "wired into nothing **[V]**" free win is **FALSIFIED** — `.pre-commit-config.yaml:30`. Entry cost: 129 of 915 lines leave `gate-validation-domain.md` (14.1%), expected next-pull adjudication saving **≈ 0** (Check 34 named in 2 of 39 logs since arrival, Check 35 in 0 of 28; control 78/78 universal token). graph read-only, `18e00ef40` untouched |
| ⏹ | **SESSION BOUNDARY.** Report row 1's four numbers and row 3's per-subject verdicts before opening the graph batch. | | | |
| 4 | **Generate the graph retirement brief** — a multi-session operator handoff, the pull-brief shape — §6.4 | BUILD | no | **DONE 2026-07-30** — `docs/reviews/graph-retirement-0.214.0-operator-handoff.md`, 7 rows, 2 `⏹` boundaries, §3's net-surface criterion carried as a reported `+added / −removed` tally and §3's four criteria as row 7's exit condition. Scope held to row 3's bound: subjects 1+2, subject 3's stray arm, checks 33/34/35; the 3 REFUTED filed as row-6 ledger entries with receipts. **Re-deriving the wiring against `18e00ef40` corrected FOUR of row 3's own figures and found one measured wedge** — see the Row 4 RESULT below. **No engine worktree needed**, unlike the 0.213.0 pull: all 3 core absorbers are already installed in graph and byte-identical to core. graph read-only, `18e00ef40` untouched, 4 pre-existing runtime modifications unchanged; scratchpad clone removed. `docs:` commit, no version bump |
| 5 | **Execute the retirement in graph, then UNFREEZE** — operator-driven graph sessions — §6.5 | RETIRE | **YES** | **DONE 2026-07-30 — MERGE `39f0248ff`, PR #833, squash to `main`, operator-approved. THE GRAPH FREEZE IS LIFTED.** Brief's 7 rows all ticked. **Net `23 files changed, +599 / −679` = −80 overall, −469 excluding the +389 ledger filing.** Post-merge, **independently re-measured from ai-dlc against `39f0248ff`**: `W5`/`OUT OF BAND` **5 → 2** (rules 31/32 only, no check id); `UNLOADABLE` **4 → 2** (`19b 2s`), rc=1 not the wedge's 2, `manifest source: core`, `extension gate_types: none`, `manifest ids: 41 anchors: 41`; fixture dirs **114 → 113**, `0 undeclared`; `--strays` PASS at 893 carriers with the `AI_DLC_KNOWN_SKILLS_EXT=""` control still exit 1 at **exactly 5**, all under `scripts/tests/**`. Duplicate-path greps **0 hits, rc=1** for both retired subjects against controls returning **17** and **6** files. `scan-stray-provenance.sh` **155 → 83** lines (stray arm out, `--fixture-provenance` intact). **13 ledger entries filed with 13 `verify:` receipts**, `ledger-reverify.sh` **53 → 66 rows**, every new row `STILL-LIVE`, the other four statuses unmoved. **The retirement found a latent defect neither row 3 nor row 4 anticipated** — see the Row 5 RESULT below. **Six deviations reported rather than adjusted to**, one of them a slip in row 4's own brief |
| ⏹ | ~~SESSION BOUNDARY — the freeze ends here.~~ **PASSED 2026-07-30 at merge `39f0248ff`. The freeze is lifted and everything below runs against a live consumer.** Rows 6–10 are `ai-dlc` sessions and touch graph not at all | | | |
| 6 | **`LC-N5` WARN → ERROR** — subject set shrinks to 2 after row 5; still owed a `kind: qualifier` measurement — §6.6 | CORE | no | **REFUTED 2026-07-30 — `LC-N5` STAYS WARN, no release consumed.** The grain cannot carry the tightening and the measurement is what says so. Against the live consumer `39f0248ff` with the shipping 0.215.0 validator: **0 errors, 2 warnings**, both `RULE OUT OF BAND` (rules 31/32, one file), identical under graph's installed 0.214.0 copy — so row 8's widening did not move `W5`. **Of 33 extension entries, 0 declare `kind: qualifier`, 0 `extends:`, 0 `position:`** (control: 33 carry `^kind:`; the 7 raw grep hits are all in `extensions/README.md`, which `layer_files()` excludes) — 19 releases after v0.196.0 shipped the grain and documented it in the consumer's own entry contract. **All 4 entries carrying a core-defined number are structurally BARRED from declaring it** by E11's exactly-one-anchor rule; they span **14 / 3 / 4 / 4** core sections. `kind:` is per-FILE and `W5`'s subject is per-HEADING: rules 31/32 share `SKILL-domain.md` with rules 13/16/20/30. Counterfactuals: exclusion **replaced** by the flag → **2 → 27** subjects; **added** as an extra exemption → exempts nothing. **The row found a live hole in the clause it was sent to tighten** — see the Row 6 RESULT. `docs:` commit plus a comment correction in `validate-layer-entries.sh`, no version bump |
| 7 | **I38 reverse: every normative sentence carries a clause id** — blocked on normalising `overrides/README.md` — §6.7 | CORE | no | — |
| 8 | **Checks `AP` / `VH`: alphabetic ids are invisible to GM1** — blocked on the relabeller's FP set — §6.8 | CORE | no | **SHIPPED 2026-07-30 — v0.215.0.** The recorded blocker was **REFUTED on both halves**: I34 binds `RULE_RE`, not any check grammar, and the relabeller's `ANCHOR_RE` had **already** carried `[A-Z]{1,3}[0-9]*` and the `—` terminator since the `### H1.` widening — no rewriter change was ever owed. **The relabeller's FP set was measured anyway and is EMPTY**: 39 labels stripped from a copy of the consumer tree, **32 proposals, 0 outside the hand-applied set** (control: intersection 32; the 2 non-proposals are `2s`/`2a`, ids core does not define, control returning 1 for `15` on the same invocation). `CHECK_HEAD_RE` widened in both detectors; measured delta across core + consumer is exactly `H1 H2 AP VH` + the consumer's `H1`, **0 spurious ids**, numeric branch unchanged at 171, `—` admitting no numeric heading. Against the live consumer `39f0248ff`: `UNLOADABLE` **2 → 4** (`19b 2s AP VH`) — the count row 8 was ranked 1st to make honest — and `validate-layer-entries` **unmoved at 0 errors / 2 warnings**. The bold pseudo-heading form is **deliberately not widened**, on a measured FP (`**QA —` in `steps/implementation.md`, both trees). **I47 extended to a three-way join** (detectors ↔ rewriter); reversion mutant fires it **alone**, and removing the arm turns only that fixture line red. **87/87 fixtures, 87 verdicts recorded**; verified again on a tree built by `install.sh`. `LC-E17` unchanged, `contract_version` stays 7 |
| 9 | **Generalise the cross-script mode join** — blocked on fixing the extractor's 8 measured misses — §6.9 | CORE | no | **SHIPPED 2026-07-30 — v0.216.0, `I60`.** The cheap precondition came back **NO**: I59 (0.214.0) generalised the **other half** of the join — every *dispatched* mode is documented — and left row 9's half (every *cited* mode is dispatched) untouched. It does not even subsume I49/I53's documentation arms, measured not read: drop `--list` from `core-paths.sh`'s `usage()` and **I49 fires while I59 stays silent**, because I59 accepts a mode named in any comment. **The subject set was re-derived and it is a different set, not a different size: 44 (script, mode) pairs across 25 targets, against the recorded 31 across 15** — the predecessor's row 7 lesson for the third row running. **The recorded 8 misses were all the extractor's, in two enumerated classes: FIVE produced by `validate-enforcement-map.sh` itself** (error prose, its own grep flags, I59's probe heredoc — and I49/I53 already carry that exact self-exclusion), **THREE from dispatch forms the `case`-arm grammar cannot see** (six scripts parse with `[ "$1" = "--x" ]`; `audit-rule-files.sh` dispatches `--fail-on=any\|deterministic` as valued arms). Both sides normalised at `=`, both dispatch forms read. **FP set EMPTY, 0 citations resolving to nothing.** Liveness probe carries both dispatch forms; 4 fixture arms in `enforcement-map-sites`; reversion mutant kills **only** the I60 assertions and leaves the seven prior ones green. Distribution-only — no consumer surface change (control: `tests/fixtures/` ships 82 fixtures, this one is not among them). **87/87 fixtures.** graph untouched |
| 10 | **The machinery home, inverted: consumer declares, core enforces the declaration** — unmeasured, may be refuted — §6.10 | CORE | no | — |

**Version numbers are not pinned to rows.** Rows that end REFUTED consume no version.

### Ranking for rows 6–10 — the ledger order is NOT the run order

**Row 1's stop condition ruled that rows 6–10 are ranked on §3's four criteria, not on the baseline's
four numbers**, two of which measured detector arrival rather than pull health. Ranked 2026-07-30,
after row 5 moved the counts those criteria are stated in:

| Order | Row | Why here |
|---|---|---|
| **1st** | **8** | Row 5 moved `UNLOADABLE` 4 → 2, and **that 2 is an understatement**: `Check AP` and `Check VH` are live, unloadable, and structurally invisible to the numeric heading grammar. The number this program just improved has the repo's named defect class inside it. Serves §3 criterion 3 directly |
| **2nd** | **6** | Its subject set is now the 2 survivors row 5 left (rules 31/32) — the condition it was reordered to wait for. Also §3 criterion 3, but safer once row 8 has made the count honest |
| **3rd** | **9** | Core-internal join hygiene. Cheap precondition first: **I59 shipped in 0.214.0, after §9 recorded the hand-listing, and may already have absorbed part of the subject set** |
| **4th** | **7** | The 41→40 clause delta is worth measuring, but it moves no §3 criterion and is blocked on normalising `overrides/README.md` |
| **5th** | **10** | Unchanged. Largest, least measured, and the row whose predecessor produced seven consecutive refutations |

**Do not fall back to ledger order.** If a row is executed out of this ranking, say which criterion
justified it.

### Explicitly out of scope

- Re-attempting anything in §4a.
- Deleting the predecessor handoff, at any point, for any reason.
- Editing graph from an ai-dlc session. Rows 4–5 produce a brief an operator executes in graph.
- Holding the freeze open past row 5.

---

## 6. Rows

### Row 1 — re-derive the four metrics. Read-only against graph.

**Why first.** The predecessor was justified on four numbers in
`~/.claude/plans/i-m-done-with-consumer-indexed-fox.md` § Context: clean-pull rate **94% → 39%**,
adjudication prose **3.8 kB → 8.3 kB**, `NEEDS-REVIEW`/`HAND-REVIEW` **0 → 38**, **6 of 9** blocker
adjudications re-litigating a file another already covered. **No release re-derives any of them**
**[V]**. Thirty releases were spent against a symptom nobody rechecked.

**The corpus exists:** **78 `reconcile-log-*` and 10 `blocker-adjudication-*`** files in graph's
`_bmad-output/ai-dlc-update/` **[V]** — the same corpus the baseline's "76 pulls" came from.

**Do.** Derive all four, banded as the baseline banded them. Derive "clean" from the logs' own
vocabulary; do not invent a definition, and state the one you found. Partial results already in
hand: adjudication prose for the one post-program pull is **6.4 kB**, mid-range of the nine
pre-program files (3.6–19.6 kB), n=1 **[V]**; `NEEDS-REVIEW` + `HAND-REVIEW` is **3 + 12 = 15**
against the baseline's 38 — **but the 0.214.0 pull moved 418 lines into
`push-candidate-ledger.archive.md`, so part of that drop is archiving, not resolution** **[V]**.
Separate the two or the number is a lie.

**Fold in:** re-derive `EXTENSION-HOOK-DRIFT`'s "31 of 76 pulls" from the same corpus, closing a [R]
the predecessor quoted in two rows.

**A zero is not a finding.** Each of the four carries a control in the same invocation.

**Stop condition.** If the metrics show the pull fight is materially better, rows 6–10 are
optimisations and should be re-ranked rather than executed in order. **Row 5 is not gated on this** —
duplicate enforcement paths are a defect regardless of how the pull metrics read.

#### Row 1 RESULT — measured 2026-07-30, read-only against graph at `18e00ef40`

Corpus **78** `reconcile-log-*.md` + **10** `blocker-adjudication-*.md`. The baseline's corpus is
recoverable exactly: 78 minus the two logs postdating the baseline file's mtime
(`reconcile-log-20260728T143546Z.md`, `reconcile-log-20260730T145354Z.md`) = **76**, splitting
**32** pre / **44** post at v0.60 — the baseline's own denominators, both reproduced. Version
extracted from each log header; **0 extraction misses**; monotonicity control found 7 inversions,
1 a filename-sort artefact of the three ISO-dashed names and 6 genuine out-of-order re-pulls.

| # | Metric | Baseline | Re-derived | Verdict |
|---|---|---|---|---|
| 1 | clean-pull rate | 30/32 (94%) → 17/44 (39%) | 30/32 (94%) → **22/44 (50%)** | grain UNRECOVERABLE on the post side |
| 2 | adjudication prose / pull | 3.8 kB → 8.3 kB | whole log **4.3 → 5.7 kB**; adjudication sections only **0.3 → 0.7 kB** | grain UNRECOVERABLE; direction reproduced |
| 3 | `NEEDS-REVIEW`/`HAND-REVIEW` | 0 → 38 | 0 → peak **22** (2026-07-26), **15 today** (3 + 12 of 53 rows) | 38 UNREPRODUCIBLE at any point in history |
| 4 | blocker adjudications re-litigating | 6 of 9 | **4 of 9** (4 of 10 today) | OVERSTATED |
| + | `EXTENSION-HOOK-DRIFT` | 31 of 76 pulls | **34 of 78** (13/32 pre, 21/46 post) | [R] → **[V]**, confirmed |

**The definition of "clean" does not exist.** The logs never use the phrase "clean pull" and the
baseline never defines it. Searched: no subset of the logs' own not-clean vocabulary (conflict /
blocker / adjudication / operator-decision section headings, `CONFLICT <id>` markers, `HARD-` codes,
`needs-confirmation`) reproduces both baseline cells. Best fit — **a log is not clean iff it carries
a `HARD-` code or a blocker section** — reproduces the pre cell exactly (30/32) and misses the post
cell by 5 (22/44 vs 17/44). Control: the predicate fires on 55 logs and does not fire on 23, so it
is neither vacuous nor universal; 93 negated mentions across 52 logs are excluded and counted.

**Metrics 1 and 3 measure detector availability, not pull health.** First appearance in the corpus:
`HARD-` codes and `layer-drift.sh` at **v0.34.0**; the blocker section at **v0.60.0**;
`hard-blockers.sh` at v0.67.0; `ledger-reverify.sh` at v0.106.0; `NEEDS-REVIEW`/`HAND-REVIEW` at
**v0.122.0 (2026-07-22)**. The baseline's era boundary **is** the version the blocker section first
appears, and its "post-2026-07-22 phenomenon" date **is** the day the two statuses first exist.
Cutting at the detector's own arrival, the split reads 31/34 (91%) → 22/44 (50%). This is the
repo's named defect class — a check that cannot fire reads exactly like one that passed — applied
to the justification for thirty releases.

**The archiving confound is REFUTED, not merely separated.** `ledger-reverify.sh` run with
base/theirs held fixed at `3490997`→`04cea81` against both the pre-rotation ledger (`e3522f153`)
and the post-rotation one: **54 rows → 53 rows, and `NEEDS-REVIEW` + `HAND-REVIEW` = 15 on both
sides.** The 418-line rotation moved only closed entries — the archive carries 54 line-leading
`ADOPTED UPSTREAM`/`WITHDRAWN` annotations and reverifies to **0 rows** against the live ledger's
53 on the identical invocation. No part of the drop from the baseline is archiving.

**`NEEDS-REVIEW`/`HAND-REVIEW` are runtime-only.** All 27 occurrences of those tokens in the two
ledger files are prose mentions; neither is a status field. No static grep can reproduce "38", and
no recorded tally of 38 exists anywhere in the corpus (largest recorded: 36 `STILL-LIVE`,
12 `HAND-REVIEW`). The time series over 32 ledger commits peaks at **22**. The "0 before" half is
confirmed with its control — 0 rows *and* 0 receipts at every commit from 2026-07-20 back, because
the `verify:` receipt grammar did not exist yet.

**Safe to re-run under freeze.** `ledger-reverify.sh` executes receipt shell commands at line 671;
the 5 live `verify: sh` receipts are all read-only (`git show`, `git cat-file -e`, `awk`, `grep`,
`test`). A first probe returned 0 `sh` receipts on the wrong grammar (`verify: sh:` — there is no
second colon); the control that caught it was 81/60 bare `verify:` hits.

**Stop condition, answered.** The pull fight is **not** materially better: the two metrics that
justified the program cannot be reproduced, and their apparent collapse is detector arrival. Rows
6–10 are not vindicated by this measurement and are not refuted by it either — the measurement is
silent on them. **Rank rows 6–10 on §3's four criteria, not on the baseline's four numbers.**
Row 5 stands unchanged, as §6.1 already provides.

### Row 2 — disarm the self-delete, index the refutations. Cheap and urgent.

**Why urgent.** The predecessor's §0 says *"Do not delete it until the Progress Ledger is fully
ticked."* **The ledger is now fully ticked [V]**, so the file's own instruction licenses deleting
the only findable index of seven measured machinery-home refutations, the refuted band ERROR, two
refuted tools, two refuted absorption arms, and row 11's five refuted design choices. Those
refutations survive in CHANGELOG prose across 297 version headings — durable, and unfindable **[V]**.

**Do.** Rewrite the predecessor's §0 as a completed program record, deleting the delete-licence and
the false untracked claim. Add a **Refutation Index** near the top: one line each, with the release
that recorded it and the predicate that failed. Point this file's §4a at that index.

**No new mechanism**, and state its weakness in it rather than papering over it with a check that
cannot fire: nothing enforces that a reader consults an index.

**Not a release.** A `docs:` commit.

### Row 3 — derive the retirement set. Read-only against graph. THE ROW THAT MAKES ROW 5 SAFE.

**§2's table is the candidate set, not the answer.** For each of the six subjects, the question is
whether the core absorber is genuinely drop-in for the consumer's use — and the predecessor's own
record says the arm rationale was wrong as often as it was right (arm 2's stated premise false,
arm 5's rationale false, arm 7's absorber the wrong file, arm 8's arm name refuted, and two arms
refuted outright).

**Per subject, produce a verdict backed by a run, never a citation:**

1. Run the **core absorber** against the consumer's real inputs and compare its verdict to the
   consumer script's on the same inputs. Equal verdicts on a case that should PASS **and** one that
   should FAIL — a matching PASS alone proves nothing.
2. Name every wiring site that must change. Four of six route through
   `extensions/checks/gate-validation-domain.md` **[V]**; `generate-sprint-status.py` and
   `retro-replay-harness.sh` also route through `ci-local.sh` **[V]**.
3. State what is **not** absorbed. `scan-stray-provenance.sh --fixture-provenance` is deliberately
   out of scope per the predecessor's §9, so that subject is a **partial** retirement — the stray
   arm goes, the script stays, and the gate check repoints for one arm only.
4. Verdict: **RETIRE**, **PARTIAL**, or **REFUTED — the absorber does not cover it**.

**Expect refutations.** If two of six come back REFUTED that is a good row, and it is the same rate
the absorption arms themselves ran at.

~~**Free win, confirm it first:** `validate-no-direct-main-push.sh` (46 lines) is wired into nothing
**[V]** — a `grep` across `ci-local.sh`, `.githooks/pre-push` and the extension check files returns
no site, against a control that returns sites for the other five. Dead code, deletable with zero
coupling.~~ **FALSIFIED by the row itself.** The subject is wired at `.pre-commit-config.yaml:30`.
The `[V]` grep's three named haystacks did not include the pre-commit config, so its zero measured
the scope of the search and not the absence of a site — the exact class `CLAUDE.md` opens with. See
the Row 3 RESULT below.

**Also derive the entry cost.** Every edit to `gate-validation-domain.md` changes a layer entry's
digest and re-opens its adjudication at the next pull. Under freeze with no pull pending that is
cheap, and the retirement **reduces** the entry's content — so state the expected effect on the next
pull's adjudication load. That number is this program's payoff argument.

#### Row 3 RESULT — measured 2026-07-30, read-only against graph at `18e00ef40`

Method: a `git clone --local --no-checkout` of graph into a scratchpad, checked out at `18e00ef40`.
Every run below is against that clone. graph itself was never written to; its `HEAD` is unchanged
and its working tree carries the same four pre-existing runtime-state modifications it started with.
Both scripts in every pair are the SHIPPING copies (`scripts/ai-dlc/core-paths.sh` in the sandbox is
byte-identical to graph's, `shasum` `89ff1b7fc261`).

| # | Consumer subject | Lines | Verdict | Decided by |
|---|---|---|---|---|
| 1 | `check-protected-core-paths.sh` | 162 | **RETIRE** | PASS and FAIL both agree, same offenders named |
| 2 | `check-mutation-red-anchor.sh` | 72 | **RETIRE** | core is a strict superset and fixes a real defect |
| 3 | `scan-stray-provenance.sh` | 155 | **PARTIAL** | stray arm drop-in on 9 boundary probes; `--fixture-provenance` not absorbed |
| 4 | `retro-replay-harness.sh` | 97 | **REFUTED** | disjoint predicate — each mutant fails only its own assertion |
| 5 | `generate-sprint-status.py` | 1068 | **REFUTED** | core compares 1 of the 5 fields, in 1 of the 5 modes |
| 6 | `validate-no-direct-main-push.sh` | 46 | **REFUTED** | core passes the decisive FAIL case, by design |

**Tally, verbatim, against §6.3's stated stop condition ("if two of six come back REFUTED that is a
good row"): three of six REFUTED, one PARTIAL, two RETIRE.** Of the 1,600 lines §2 tabulated,
**234 retire outright** and **~110 more** if the stray arm is excised from subject 3 — so
**1,256 of 1,600 lines are not absorbed by anything**, against §2's "0 lines retired" framing which
implied all 1,600 were owed.

**1 — `check-protected-core-paths.sh` → `core-paths.sh --audit-diff`: RETIRE.** Identical CLI
(`<base-ref> [<head-ref>]`). Three real ranges: the `/ai-dlc-update` reconcile commit `e3522f153`
(PASS, both 0), `2f04341da` with no core path touched (control, both 0), and — because the first
FAIL attempt returned a matching PASS on both sides via the citation escape hatch, which proves
nothing — a second FAIL case run against the real graph tree at `85ac897a6` (2026-07-16), the last
era in which `docs/escalations/pending.md` carried **0** `Operator authorization:` lines (control: 8
at `HEAD`, 12 at `f718b1eea`, 0 at `85ac897a6` and earlier). There, `95ffa2297` touching
`steps/carry-over-evaluation.md` and `steps/gate-validation.md` under a non-reconcile subject:
**both exit 1, both name the same commit and the same paths.** Core is strictly better on the arm
that differs — the consumer greps `pending.md` for `Operator authorization:`, core delegates to
`validate-escalation-resolution.sh` (the v0.204.0 fix for a grep a sentence saying no citation
exists could satisfy). **Wiring: 4 files.** `extensions/checks/gate-validation-domain.md`
(Check 34, lines 787–861), `extensions/roles/code-reviewer-domain.md:41`,
`extensions/roles/dev-domain.md:15`, `extensions/roles/qa-domain.md:17`.

**2 — `check-mutation-red-anchor.sh` → `validate-mutation-red.sh`: RETIRE.** Identical CLI. Check
35's own three declared arms, run against both detectors: unreachable anchor (both 1), reachable +
value-asserting (both 0), coverage-only degenerate (both 1). Three further arms the consumer
collapses into its single FAIL: a line number past EOF and a byte-identical replacement both go
consumer 1 / core 2 — same pass/fail, and core's 2 correctly says *nothing was tested* rather than
accusing the test. The decisive one: **a replacement containing `@` — consumer 1, core 0.** The
consumer's rewrite is `sed "<n>s@.*@<repl>@"`, so the `@` breaks the expression, the file is never
mutated, the test stays GREEN, and the consumer reports "claimed anchor is unproven" against a test
that was never put under test. Core mutates correctly and returns PROVEN. **Wiring: 3 files.**
`gate-validation-domain.md` (Check 35, lines 872–915),
`scripts/tests/test-s291-3-check35-mutation-red.sh:21` (a single `DETECTOR=` line),
`tests/fixtures/check-35-mutation-red-reachability/README.md:21`. **Repoint hazard:** core adds
exit 2 (UNEVALUABLE) and exit 3 (HARD — **tree left mutated**). A caller written as
`if script; then PASS else FAIL` is safe, but the fixture's arms assert only non-zero and would stay
green against either; and exit 3 needs an operator-visible path, not a FAIL line.

**3 — `scan-stray-provenance.sh` → `validate-provenance-block.sh --strays`: PARTIAL.** Identical
`--strays [<path>...]` shape. Core's resolved home set is printed in its own FAIL message and is
**identical to the consumer's six**: `_bmad-output/**`, `docs/retro/**`, `docs/reviews/**`,
`docs/architecture.md`, `docs/architecture-history.md`, `scripts/tests/**`. The same real
party-mode block was planted at nine home boundaries — 4 homes (all PASS on both) and 5 non-homes
(all FAIL on both), **9 of 9 agree** — plus the whole-tree default scan (both 0; core reports 890
files carrying the envelope), the two crafted stray fixtures (both 1), and two controls (a known
stray: both 1; a file with no block: both 0). The sandbox was left with 0 modified paths.
**`--fixture-provenance` is NOT absorbed** and is out of scope per the predecessor's §9, so the
script stays — but that arm has **exactly one live caller, its own test**
(`scripts/tests/test-s241-5-ac4-provenance-secret.sh`), which `ci-local.sh` does not reference
(control: `ci-local.sh` names 39 other `scripts/tests/test-*.sh`) and no fixture `run.sh` drives.
Whether to keep a 45-line arm nothing runs is a row-4 question, not a row-3 one. **Wiring: 3 live
sites** — `gate-validation-domain.md:102,110` (Check 17, one arm), `scripts/lib/pr-class.sh:163`
(`EXPECTED_VALIDATORS="scan-stray-provenance.sh"`), plus 4 test scripts.
**Found in passing:** Check 17's prose names **five** homes and both implementations carry **six** —
`docs/architecture-history.md` appears **0 times in the whole 914-line file** (control:
`architecture.md` appears once in the same span). The prose under-declares its own mechanism by one
home, so a party-mode block in `architecture-history.md` is legitimate to both scanners and a stray
by the check that governs them.

**4 — `retro-replay-harness.sh` → the fixture-drivability convention: REFUTED.** These answer
disjoint questions and the run says so. The harness replays retro-merge validator fixtures and
asserts each deny-reason token against `defect-manifest.txt`; `validate-fixture-drivability.sh`
asserts every fixture directory has a `run.sh` or a declared exemption. Two mutants, on the same
tree: making the declared-noncompliant `s155-noncompliant.md` compliant → **harness 1** ("(b)
s155-noncompliant.md was ACCEPTED but declares defect"), **drivability 0**; removing
`tests/fixtures/retro-replay/run.sh` → **drivability 1** (`undeclared: 1`), **harness 0**. Each
mutant fails only its own assertion, and both restored byte-identical. What v0.202.0 absorbed is the
**driving convention, not the harness**: `run.sh` delegates to it (`exec bash
"$ROOT/scripts/retro-replay-harness.sh"`), and `.githooks/pre-push:160-170`'s generic
`for d in tests/fixtures/*/` loop drives it on every push. **That does make `ci-local.sh:1336-1342`'s
hand-listed `paths_match` trigger redundant** — a duplicate *invocation*, not a duplicate
*predicate*, and reachable only from a manual `bash scripts/ci-local.sh` because the installed
pre-push hook does not call `ci-local.sh` at all (control: it invokes 8 other `bash scripts/`
targets). **The 97 lines are not retirable. The trigger block is.**
**Measurement trap recorded:** the first drivability run answered `exit 0` in silence. Bare, it
reads `PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"` — my own session had that set to `/Users/n8/git/ai-dlc`,
which has no `tests/fixtures`, so it correctly reported "no fixture tree — nothing to judge" and
`--quiet` swallowed the sentence. A false zero of the measurer's making. Row 4's brief must state
that this validator is only meaningful with `--dir` or a correct `CLAUDE_PROJECT_DIR`, and must not
be run under `--quiet` as evidence.

**5 — `generate-sprint-status.py` → `sprint-status.sh check-stories`: REFUTED.** Both PASS on the
live tree, and the pass is where the coverage gap shows: the consumer reports **1 story, 10
comparisons across 5 fields** (`acceptance_criteria`, `capital_path`, `gate_1_model`, `priority`,
`status`); core reports **2 entries, 2 comparisons**, on `status` alone. Three mutants against the
live `_bmad-output/planning-artifacts/sprint-status.yaml`: corrupting `status` → **both 1**;
corrupting `priority` → **consumer 1, core 0**; corrupting `gate_1_model` → **consumer 1, core 0**.
All restored, 0 modified paths. Core covers **one of five compared fields in one of five modes** —
the consumer also carries `--write`, `--migrate`, `--close-sweep` and `--validate`, and core's `roll`
is deliberately a different mechanism (rotation at pipeline start, not at retro-close, stated in its
own header). **1,068 lines are not retirable; neither is the `--check` mode.** The genuine duplicate
is the `status` comparison alone, and unpicking one field from a five-field diff costs more than the
duplicate does. **Wiring: 43 files** — `ci-local.sh` ×4, `overrides/steps__gate-validation__check-5.md`
×4, `overrides/steps__retro__domain-sections.md` ×4, `qa-domain.md:136`,
`.claude/schemas/sprint-status.json:30`, `validate-story-frontmatter.sh`,
`validate-story-status-consistency.sh`, and 30+ test/fixture files. **This subject alone is a larger
wiring surface than the other five combined; it should not enter the row-5 brief.**

**6 — `validate-no-direct-main-push.sh` → `--trunk-push` + pre-push arm 0: REFUTED, and it is not a
free win.** Real pre-push protocol lines built from real graph commits. Case A, the licensed Step 5b
backfill `2f04341da` (`chore(s298): backfill audit-anchor SHA after retro PR #812 merge`, touching
`_bmad-output/audit-anchors.md` alone): **both 0** — and that agreement proves nothing, which is why
Case B matters. Case B, the real merge `e3522f153` pushed direct to `refs/heads/main`:
**consumer 1 ("BLOCKED: direct push to main contains a non-exception commit"), core 0
("--trunk-push: PASS — 1 commit(s) judged").** Case C control, the same commit pushed to a
non-trunk ref: both 0. Core's header states the reason plainly — *"It bounds that commit; it does
not police the trunk."* The consumer's predicate (**every** commit on a push to `main` must match
the backfill regex) is strictly wider than core's (only a commit that claims the subject without the
paths, or takes the paths without the subject). Corpus control: 106 commits on `main` match the
backfill pattern, 2,767 commits total, a bogus pattern matches 0.
**And the "wired into nothing" premise is false.** It is `id: no-direct-main-push` in
`.pre-commit-config.yaml:30`, `stages: [pre-push]`, and `CLAUDE.md:281` documents
`pre-commit install --hook-type pre-push` as the repo's one-time setup. It is nonetheless **dormant
in every clone**, for a reason graph states itself: `overrides/steps__retro__ci-gates-enforcement-surface.md:49`
records that the pre-push hook type is deliberately NOT installed because `ci-local.sh` exits 1
today and installing it "would **REJECT EVERY PUSH**". Measured on this clone: `.git/hooks/pre-push`
is a shim that `exec`s `.githooks/pre-push`, which never reaches the pre-commit framework (control:
the token appears 6 times in `.git/hooks/pre-commit`, 0 times in `.githooks/pre-push`), and
`pre-commit` 4.5.1 is installed with `--hook-type=pre-commit` only. **Net effect: graph today has no
enforcement of "no direct push to `main`" at all** — the consumer's guard cannot fire, and core's arm
declines the question by design. Deleting the script is defensible; deleting it *as a free win with
zero coupling* is not, and the `.pre-commit-config.yaml` entry must go with it.

**Entry cost — the payoff argument, and it does not survive the measurement.**
`gate-validation-domain.md` is **914 lines**. Checks 33, 34 and 35 occupy lines **787–915**,
contiguous at the file's tail: **129 lines, 14.1%**, excised without touching the interior. Against
the reconcile corpus: the file is named in **13 of 78** pulls (controls: universal token `ai-dlc`
78/78, a bogus token 0/78) — the second-most-adjudicated of the four extension check files, behind
`gate-validation-push` at 21/78. But the three checks being removed are **not** what drives that
traffic. Denominator-corrected to each check's own arrival in the file (33 on 2026-07-06, 34 and 35
both on 2026-07-16): **Check 34 is named in 2 of the 39 logs postdating it, Check 35 in 0 of 28.**
So the retirement **costs one guaranteed re-adjudication** of the entry at the next pull — a changed
file is adjudicated with certainty, against a 13/78 base rate — and **saves an expected ≈ 0.05
adjudications per pull**. The payoff for row 5 is §3 criterion 1 (two implementations of one
predicate cannot disagree at a gate if only one exists) and criterion 3 (3 of 5 `W5` squatters, 2 of
4 `UNLOADABLE`). **It is not adjudication load, and the brief must not claim it is.**

**What row 4's brief covers, per §6.3's bound:** subjects 1 and 2 (RETIRE), subject 3's stray arm
(PARTIAL), and checks 33/34/35. Subjects 4, 5 and 6 are REFUTED and are recorded here and in the
CHANGELOG per §4 — subject 4's redundant `ci-local.sh` trigger block and subject 6's dormant
pre-commit entry are filed as ledger entries with falsifiable receipts, not fixed in the brief.

### ⏹ SESSION BOUNDARY — report row 1's four numbers and row 3's six verdicts.

### Row 4 — generate the graph retirement brief.

**Reuse the shape that worked.** `docs/reviews/graph-pull-0.213.0-operator-handoff.md` drove 45
per-item judgements across nine rows and multiple sessions without a batch-apply. Same structure:
a ledger, per-row sections, `⏹ FRESH GRAPH SESSION` markers, explicit stop conditions, and tallies
reported verbatim rather than as "as expected".

**Carry its hard-won corrections in.** Its §4 records five probes that answered falsely before the
right invocation — a validator wanting a FILE not a root, one wanting `--dir`, one deriving the
project root from its own script location, a mode that arrives *with* the pull and cannot be
measured before it, and a grep for a token that never appears in the message text. **Its own §5
ledger also records three arithmetic slips in the brief itself** that the executing session caught
and proceeded through. Expect the same class here and say so in the brief.

**The brief must state the net-surface criterion from §3 as a reported tally**, so the executing
session reports `+added / −removed` at the merge rather than "retired the duplicates".

**Bound the scope.** The brief covers row 3's RETIRE and PARTIAL verdicts, checks 33/34/35, and
nothing else. The other consumer-owed items — `19b`/`2s` `UNLOADABLE`, rules 31/32, the three dead
drivers **[R]**, `PC-S310`'s apparent real close **[R]** — are **surfaced in the brief as filed
ledger entries with falsifiable receipts, not fixed in it**. graph's `ledger-reverify.sh` re-tests
every receipt on every pull **[V — 53 rows today: 33 STILL-LIVE, 12 HAND-REVIEW, 3 NEEDS-REVIEW,
3 ENTRY-SWALLOWED, 2 NAMED-UPSTREAM]**, which is the mechanism a merged PR body's 11 checkboxes are
not.

#### Row 4 RESULT — brief written 2026-07-30, wiring re-derived read-only against graph at `18e00ef40`

Deliverable: **`docs/reviews/graph-retirement-0.214.0-operator-handoff.md`**. Shape reused from the
0.213.0 handoff — §0 repo statement, §1 state, §2 locked decisions, §3 discipline, §4 falsified
premises, §5 ledger, §6 rows, §7 known-open — with `⏹ FRESH GRAPH SESSION` after row 4 and after
row 5, the two per-item-judgement boundaries.

**One structural difference from the pull, and it removes the 0.213.0 brief's biggest trap.** That
pull needed a pinned engine worktree because graph's installed engine could not emit the statuses the
pull added (`--strays` appeared in it **0** times). Here graph is stamped at the distribution's own
HEAD and **all three absorbers are installed and byte-identical to `core/scripts/`** — `core-paths.sh`
`89ff1b7fc261`, `validate-mutation-red.sh` `a1ec071b3ca7`, `validate-provenance-block.sh`
`392a592c5a53`. Every command in the brief runs graph's own copy; nothing is staged.

**Four of Row 3's figures were wrong, each corrected with a control:**

1. **The excision span.** Row 3 said checks 33/34/35 occupy lines **787–915** of a **914**-line file —
   915 does not exist. The headings also run **34 (787), 33 (862), 35 (872)**, *not* numeric order, so
   slicing "33 through 35" by number cuts the wrong range and leaves check 34 in the file. The
   contiguous block including its `## Check 34` marker is **784–914 = 131 lines (14.3%)**, not 129.
2. **Row 3's "~110 of 155" for the stray arm over-counts.** `--fixture-provenance` is lines 58–89
   (32); the stray body is 90–155 (**66**); lines 1–57 are a header documenting **both**. Row 3
   charged the shared header entirely to the stray arm. The brief tells the executing session to
   report what it removed rather than carry 110 as a target.
3. **Subject 3's wiring is short by one live site.** `scripts/lib/pr-class.sh` carries the script at
   **:89** (`'^scripts/scan-stray-provenance\.sh$'`, a path allowlist) as well as at `:163`. Control:
   bogus token rc **1** / 0 lines, universal token **389** files, same invocation.
4. **Check 34 is not a pure duplicate — the SCRIPT is, the SCHEDULE is not.** Core's equivalent is
   `Core-layer immutability (§7.1 authoring guard — retro/close gate)` at
   `core/skills/ai-dlc/steps/gate-validation.md:1700`, whose Scope reads *"Fires at the retro /
   sprint-close gate"*; graph's Check 34 fires *"at gate-1 … for every story"*, and **core's
   `team-roles/` carry no protected-core-path pre-flight at all** (control: universal token matches 11
   files there; the sole `core-paths.sh` hit is `protected-path-editor.md:42`, a different mode in a
   different role). So the brief **deletes check 34 but repoints the three role lines** to
   `core-paths.sh --audit-diff`, preserving the gate-1 firing point. Check 35 has no such problem —
   core mandates `validate-mutation-red.sh` at `code-reviewer.md:418`, `dev.md:201`, `qa.md:79`.

**A measured wedge the naive route walks into.** Excising the three checks while leaving the
frontmatter `gate_types: implementation` makes `validate-gate-manifest.sh` exit **2**: *"declares
gate_types: implementation and carries no `<!-- CHECK_LOADED: <id> -->` anchor … the declaration
claims loading for nothing."* Check 34's anchor at line 788 is **the only one in the entire
`extensions/checks/` tree** (control: the other three check files carry **0**). Measured on a
`git clone --local` of `18e00ef40` in the scratchpad, both variants built as copies: variant A
(line kept) exit **2**; variant B (line removed) exit **1** with the expected residual
`UNLOADABLE: 19b 2s`, `manifest source: core`, `extension gate_types: none`. Both variants give
`0 error(s), 2 warning(s)`. The reverted `gate_types: none` is **not** a regression of the pull's row
3b, whose real gain was `manifest source: core` — the `34->implementation` mapping existed only to
claim check 34.

**Baselines recorded in the brief for the executing session to measure against**, all against
`18e00ef40` with graph's own installed copies: `validate-layer-entries` exit 0, **5** `OUT OF BAND`;
`validate-gate-manifest` exit 1, `UNLOADABLE 19b 2s 33 35`, MISSING/ORPHAN none, `manifest ids: 42
anchors: 42`; **114** fixture directories, 0 undeclared; `--strays` PASS. Post-retirement expectation
**5 → 2**, **4 → 2**, **114 → 113**, PASS held with its `AI_DLC_KNOWN_SKILLS_EXT=""` flip control.

**Also folded in:** core ships replacement fixtures for both absorbers and **they are already in
graph** (`mutation-red-replay/`, `core-paths-audit-diff/`, `stray-party-mode-provenance/`, each with
`run.sh` + `seed.sh`, so already in the push suite's generic loop) — which is why the brief retires
graph's `check-35-mutation-red-reachability/` fixture and its test alongside the detector. And
**neither `ci-local.sh` nor `.githooks/pre-push` names any of the three retiring scripts** (controls:
39 `scripts/tests/test-*` names, 8 `bash scripts/` invocations), so the retirement does not touch the
push suite's script list.

**The brief does not claim the adjudication-load payoff**, per row 3's measurement, and says so in
its §7 — the cost is one guaranteed re-adjudication against an expected saving of ≈ 0.05 per pull,
and the payoff is §3 criteria 1 and 3.

**Honest weakness, stated rather than papered over.** Row 4 corrected four of row 3's figures by
re-deriving them; nothing guarantees this brief is the fixed point. Its §4 says so and instructs the
executing session to report a deviation rather than adjust to it — the same disposition the 0.213.0
handoff's ledger records three times, each time correctly.

### Row 5 — execute in graph, then unfreeze. FREEZE-BEARING.

**Operator-driven graph sessions.** Nothing here is edited from an ai-dlc session. A core defect
found during execution is fixed in ai-dlc and re-delivered — never patched in graph. That rule held
through the entire 0.213.0 pull and is not relaxed.

**Tick this row with the merge sha, the `+added / −removed` tally, and the post-merge counts for
`W5` and `UNLOADABLE`.** Then unfreeze, and say so explicitly in the tick — an unfreeze nobody
records is a freeze that never ends.

**The four §3 criteria are this row's exit condition, not row 10's.**

#### Row 5 RESULT — merged `39f0248ff` 2026-07-30. Verified from ai-dlc against the merged tree.

**All four §3 criteria met, each as a measurement rather than a claim.** (1) Duplicate enforcement
paths **0** for subjects 1, 2 and subject 3's stray arm, by live-path grep with a control that
returns non-zero in the same invocation. (2) Net surface **DOWN**: `+599 / −679`. (3) `W5` **5 → 2**,
`UNLOADABLE` **4 → 2**, both survivor sets dispositioned in writing. (4) Each retirement carries a
`ledger-reverify.sh` receipt that a later pull re-runs — the three `…-STAYS-RETIRED` entries — and all
three were mutation-tested in both directions.

**The finding worth keeping: retiring a duplicate can silently RE-ARM a dead gate, and this one
nearly did.** Two gates discriminated by **validator name** rather than by PR class:
`.claude/hooks/guarded-merge.sh` and `scripts/audit-main-since.sh` both tested
`EXPECTED_VALIDATORS` for `validate-provenance-block.sh`. Since S249 the `provenance-in-non-retro`
class carried `scan-stray-provenance.sh` instead, so **those arms had been unreachable for the entire
time they appeared to be enforcing something**. Retiring the consumer scanner would have put the core
validator's name on both classes and switched the dead arms back on — re-arming exactly the per-block
retro validation the S249 Check-17 carve-out exists to prevent, whose stated consequence is that
accumulated historical blocks "would permanently deny every future non-retro merge." The fix moved
both gates to a **class** test and selects `--strays` from `PR_CLASS`, because `EXPECTED_VALIDATORS`
is word-split and a flag cannot live in it. **+42 lines added, with the reason stated in the code** —
§3 criterion 2's "a row that adds consumer surface states why", answered in the file rather than the
PR body. Both unreachable arms are **filed, not revived**; reviving one is a consumer decision.

**Generalise it: a join keyed on a NAME breaks when the name is the thing you are retiring.** The
retirement was scoped by predicate (does core compute the same answer) and by schedule (does core
fire at the same point, row 4's correction). This is a third axis — **does anything downstream key on
the retired thing's NAME?** — and it is invisible to both of the first two. `CLAUDE.md`'s "derive
both sides of a join rather than hand-list either" is the standing form of this; here the hand-listed
side was a validator basename in a shell string.

**Row 4's brief was itself wrong once, and the executing session reported it rather than adjusting.**
Its §7d carried the 0.213.0 handoff's "118 findings / 45 files / 3 error-level" shellcheck figure as
pre-existing red. Re-measured under ci-local's exact invocation: `main` is **122 / 49 / 3**, branch
HEAD **120 / 47 / 3** — the branch **removes** two findings and adds none. Same non-reproducing class
as the figure the 0.213.0 handoff itself failed to reproduce, so it is not carried forward again.
**Two briefs in a row have now shipped that number wrong. Do not quote it a third time; measure it.**

**Confirmed dispositions carried out of the row:** the three REFUTED subjects stay
(`retro-replay-harness.sh`, `generate-sprint-status.py`, `validate-no-direct-main-push.sh` —
**1,211 of the 1,600 lines §2 tabulated are absorbed by nothing**); graph still has **no enforcement
of "no direct push to `main`" at all**; `--fixture-provenance` survives with one caller, its own
test, which nothing drives; Check 17's five-vs-six home under-declaration is **fixed** —
`docs/architecture-history.md` now named in the prose that governs both scanners.

### Row 6 — `LC-N5` WARN → ERROR. **RANKED 2nd.**

> **▶ DONE — REFUTED, 2026-07-30. `LC-N5` stays WARN and no version was consumed.** Ticked in §5,
> RESULT below, indexed in the predecessor's `## 0a. Refutation Index`, and the `▶ NEXT STEP` block
> at the top now points at row 9. Nothing here is owed. The recorded blocker — "the `kind: qualifier`
> grain is what unblocks this" — was a claim, and the RESULT records what it was actually worth.

**Reordered: this now follows retirement.** Row 5 disposes checks 33/34/35, leaving **2** live `W5`
subjects (rules 31/32) instead of 5 **[V]**. An ERROR that fires on live subjects with no remedy
filed wedges the next pull — the failure the predecessor's row 6 shipped into and had to close.

**What is owed is a measurement, not code:** which of graph's entries would actually declare
`kind: qualifier`, derived **per hooked file and per frontmatter flag**. The predecessor's §9 warns
that "the four rules that qualify core numbers" is a subagent-era figure v0.196.0 did not re-derive,
and its row 7's recorded lesson is that the counts were of the **wrong set**, not merely wrong.

**May end REFUTED** — if the grain does not separate a deliberate qualifier from a squatter on real
entries, `W5` stays WARN and the row records why. ~~May~~ **Did.** See below.

#### Row 6 RESULT — REFUTED 2026-07-30. Consumer read-only at `39f0248ff`; `LC-N5` stays WARN.

**The grain does not separate a deliberate qualifier from a squatter on real entries, and it cannot
be made to — the reason is structural, not a matter of adoption.**

Method: a `git clone --local --no-checkout` of graph into the scratchpad at `39f0248ff`. Every
figure below is derived by **lifting the shipping extractors out of
`core/scripts/validate-layer-entries.sh`** — `RULE_RE`, `CHECK_HEAD_RE`, `BAND_FLOOR`,
`defined_rules`, `defined_anchors`, `below_band`, `fm`, `resolve_target`, `layer_files` — with I45's
own `band_fn` technique, never by copying a grammar. Lift control in the same invocation: core
`SKILL.md` **30** rules, `steps/gate-validation.md` **39** anchors, `BAND_FLOOR` **900**; a zero on
any of the three aborts, because a lifted function whose pattern variable is unset greps the empty
string and harvests nothing, which reads exactly like a conforming tree. graph itself was never
written to; `HEAD` unchanged, the same four pre-existing runtime-state modifications.

**Ground truth first, with the code that will ship.** `core/scripts/validate-layer-entries.sh` at
0.215.0 against the clone: **`0 error(s), 2 warning(s)`**, both `RULE OUT OF BAND` — `Rule 31` and
`Rule 32`, both in `extensions/steps-domain/SKILL-domain.md`. **Byte-for-byte the same two lines
from graph's own installed 0.214.0 copy on the same tree**, so row 8's grammar widening did not move
`W5`, as row 8 said. Zero `RULE NUMBER COLLISION` lines — remember that.

**The measurement §6.6 owed, per hooked file and per frontmatter flag:**

| | |
|---|---|
| extension entries | **33** |
| declaring `kind: qualifier` | **0** |
| declaring `extends:` | **0** |
| declaring `position:` | **0** |
| entries carrying ≥1 core-defined number | **4** |
| …of those, able to declare `kind: qualifier` at all | **0** |

Control on the zeros: **33** entry files carry `^kind:`, and the histogram is `step-domain` 21,
`role` 8, `check` 4 — no fourth value. The raw tree-wide grep returns **7** hits for the three keys
and **every one is in `extensions/README.md`**, which `layer_files()` excludes by name: the grain is
fully documented in the consumer's own entry contract and adopted by nothing, **19 releases after
v0.196.0 shipped it**.

**Three reasons it cannot be the discriminator, in increasing order of finality:**

1. **Zero adoption**, above — which alone only says nobody has done it yet.
2. **`kind:` is per FILE; `W5`'s subject is per HEADING.** Both live subjects and four excluded
   core-defined rules are in **one file**. `SKILL-domain.md` would have to be `qualifier` for rules
   13/16/20/30 and not-qualifier for 31/32 simultaneously. No per-file flag can express that.
3. **E11 bars the flag on every entry that would need it.** `kind: qualifier` requires `extends:`,
   and `extends:` admits **exactly one anchor** — *"two anchors mean two spans, and a drift row could
   no longer say which one moved."* The four entries carrying core-defined numbers render into
   **14, 3, 4 and 4** core sections respectively. None of them can legally declare it. The grain is
   built for an entry that qualifies **one** core section; the consumer has none.

**Counterfactuals, computed rather than argued:**

| Variant | `W5` subject set |
|---|---|
| today — exclusion is *"core defines this number"* | **2 rules / 0 checks** |
| **A** — exclusion **replaced** by `kind: qualifier` | **10 rules / 17 checks = 27** |
| **B** — `kind: qualifier` **added** as a further exemption | **2 / 0** — exempts nothing, changes nothing |

A wedges every consumer immediately; B is a no-op. There is no third reading in which the grain
moves this clause, so the tightening is **REFUTED on its stated prerequisite** and `LC-N5` stays
WARN at `contract_version` 7.

**`LC-N5` also stays WARN on grounds independent of the grain**, and this is the part §6.6 warned
about: rules 31 and 32 are **live in graph today** and core cannot renumber them. An ERROR blocks
graph's next pull until graph renames its own catalog — the failure the predecessor's row 6 shipped
into, and the reason `W5`'s own header chose WARN when the set was five.

**The finding worth keeping: the exclusion swallows its own detonated subjects, and one has already
detonated.**

`docs/retro/sprint-294.md`, written **2026-07-20** and untouched since, files three improvements
from one retro as three consecutive rules — `I-1 → Rule 30`, `I-3 → Rule 32`, `I-14 → Rule 31`,
each a bare integer in the durable audit record. All three landed in one commit (`67cb76d3d`). On
that day all three were `W5` subjects. **Core allocated its own `### Rule 30 -- The spec is BMAD's;
the enforcement is ours` on 2026-07-26 (`6dd9cff`), reaching graph on 2026-07-27** — an unrelated
rule on the same integer, six days later.

So `W5`'s stated detonation is not hypothetical. It happened, to a sibling of the two live subjects,
inside the reference consumer, during this program. **And `W5` went quiet about that number on the
exact day its warning came true**, because the exclusion asks whether core defines it *today*. Rule
30 did not become clean; it became the defect. `W4` does not report it either — the consumer's
remedy was the catalog label `[ext:skill-domain]`, applied 2026-07-28 (`54bb56cff`), and `W4` reads
a labelled heading as the resolved state. **Neither arm fires on the one number in the tree that has
actually gone off**, which is what the run's `2 RULE OUT OF BAND / 0 RULE NUMBER COLLISION` above
records. This is the repo's named defect class sitting inside the clause row 6 was sent to tighten.

Nor is the audit record repaired. The crosswalk table in graph's `extensions/README.md` — the remedy
`W5`'s own message prescribes — carries **exactly one data row** (`Check 24`) and **no row for Rule
30, 31 or 32**. The frozen retro's bare `Rule 30` still has two referents and nothing resolves it.

**A candidate predicate, measured and deliberately NOT shipped.** A deliberate qualifier cannot
reference a core rule that does not exist yet, so **authorship order separates the two classes**.
Derived from graph's own history across all eight core-defined rule numbers: **7 qualifier-consistent
(core first, by 3 days to 3 months), 1 consumer-first — Rule 30 — and 0 undecidable.** FP set empty
on the reference consumer; controls: a number neither side defines is empty on both sides, core's
`Rule 1` resolves to 2026-04-18, and the pickaxe survives the relabeller because `Rule 30 ` is a
substring of both the labelled and unlabelled headings (Rule 30 returns its 2026-07-20 authoring
date, not its 2026-07-28 relabel date). **It is not wired, and the reason is this repo's own rule:**
a shallow or squashed consumer clone answers empty on *both* sides, and an arm that cannot fire
reads exactly like one that passed. It needs a zero guard, a fixture, a mutant and a remedy decision
before it needs a predicate — that is a release, and this row's deliverable is a measurement.
Recorded here so it is not re-derived from scratch.

**One figure corrected in shipping code.** `validate-layer-entries.sh`'s header called the
core-defined-number exclusion *"the exclusion that keeps the check honest"* and said *"the reference
consumer carries four such rules, each declaring itself a tightening of the core rule it names."*
Re-derived: **eight** such rules across **two** entry files, not four — and one of the four in
`SKILL-domain.md` is not a tightening of anything, since consumer Rule 30 ("Lead states no fact it
did not observe this session") and core Rule 30 ("The spec is BMAD's; the enforcement is ours") share
nothing but the integer. **The count was right for one file and the membership was wrong**, which is
the predecessor's row 7 lesson verbatim. The header now states the hole, the eight, and the unwired
predicate. Comment-only: `validate-enforcement-map.sh` exits 0, `shellcheck -S error` clean, the
graph run is unmoved at `0 error(s), 2 warning(s)`, and all five fixtures that read this file —
`enforcement-map-sites`, `layer-anchor-declaration`, `layer-catalog-collision`,
`layer-contract-conformance`, `layer-qualifier-grain` — pass.

**Two measurement traps, both mine, both recorded because the next row will meet them.**

1. **`validate-layer-entries.sh` takes its root as `$1`, not `--dir`.** Invoked as
   `... --dir <root>`, `PROJECT_ROOT` becomes the literal string `--dir`, the run prints **nothing**
   and **exits 0**. My first ground-truth run did exactly that and read as a clean tree. The control
   that caught it: the same script against `/tmp` says *"Not an ai-dlc consumer"* — a real absence is
   loud, and silence was the tell. Row 4's brief already records this class for a different
   validator; it is now four instances.
2. **I45's `band_fn` extractor cannot lift a one-liner function.** Its awk stops at the first line
   beginning with `}`, so `layer_files() { …; }` — whole body on the opening line — extracts to EOF
   and `eval` re-executes the rest of the validator. It failed loudly (`OVR_DIR: unbound variable`)
   rather than silently, which is the only reason it cost minutes. **I45 itself lifts only
   multi-line functions today, so it is not affected** — but anything reusing the technique must
   handle the one-liner case.

### Row 7 — I38's reverse direction. **RANKED 4th.**

> **▶ NEXT STEP — AGENT. This is the current row** — row 9 shipped as v0.216.0 and row 7 is next.
> Fresh session, cwd `/Users/n8/git/ai-dlc`.
>
> ```
> Read docs/analysis/post-program-gap-closure-plan.md in full, then execute row 7.
> Rows 1-6, 8 and 9 are ticked. Normalise overrides/README.md's clauses into the
> bold-led bullet form FIRST — the predicate cannot fire on half its subject
> otherwise, and a check that cannot fire reads exactly like one that passed.
> Measure the 41 -> 40 clause delta as part of this row; it is the number that
> says whether the arm is worth its release.
> Row 7's recorded blocker is that overrides/README.md has zero bold-led bullets.
> Three rows running, the recorded blocker was a claim that died on being opened.
> Check that one before you build around it.
> ```
>
> **On ending: tick §5, update the `▶ NEXT STEP` block at the top, and hand to row 10 — which needs
> an operator decision before it starts.**

**State [V].** I38 forward ships. The reverse — every normative sentence carries a clause id — is
refused **in code** at `scripts/validate-enforcement-map.sh:650` with the reason recorded: a keyword
predicate matches 26 lines against 10 real clauses, and the structural predicate is worse because
the two READMEs do not share a clause shape — all 10 bold-led bullets are in `extensions/README.md`
and `overrides/README.md` has zero.

**Why it matters.** "40 clauses, all enforced" means *every clause that reached the machine-readable
contract is enforced*. The baseline counted **41 normative prose clauses**. **Nothing measures the
delta [V]** — a normative prose clause that never became an entry is invisible, which is this repo's
named defect class applied to the contract itself.

**Do.** Normalise `overrides/README.md`'s clauses into the bold-led bullet form first — the
predicate cannot fire on half its subject otherwise — then ship the reverse arm with its measured FP
set. **Measure the 41→40 delta as part of this row**; it is the number that says whether the arm is
worth its release.

### Row 8 — alphabetic check ids. **RANKED 1st of the remaining five.**

> **▶ DONE — SHIPPED as v0.215.0, 2026-07-30.** Ticked in §5, RESULT below, and the `▶ NEXT STEP`
> block at the top now points at row 6. Nothing here is owed. The prompt this row ran from named
> **I34** as the binding constraint; that was wrong, and the RESULT records what the constraint
> actually was.

**State [R — predecessor §9].** `CHECK_HEAD_RE` is numeric, so `Check AP` and `Check VH` are
invisible to GM1, and both are reported live and unloadable. **Do not read GM1's silence as evidence
they are fine** — they are structurally outside what it can see.

~~**The constraint.** Widening the grammar is bound to `reconcile/relabel-extension-checks.sh` by
**I34**. A detector that finds a heading the rewriter cannot rewrite reports a defect with no
remedy, so both change in one release, and the relabeller's FP set across every heading it already
rewrites is **unmeasured**. Measure first.~~ **REFUTED by the row itself — the [R] state above was
accurate and the constraint under it was not.** See the Row 8 RESULT below.

#### Row 8 RESULT — SHIPPED v0.215.0, 2026-07-30. Consumer read-only at `39f0248ff`.

**The recorded blocker was false on both halves, and neither half needed a new measurement to
falsify — only a reading of the files it named.**

1. **I34 binds `RULE_RE`.** Its own header says the rule namespace is deliberately kept apart from
   the check namespace, because folding the word `Rule` into the check grammar would merge `Rule 29`
   and check `29` into one id. It has never governed a check heading. The invariant that binds the
   two detectors is **I47**; the one that binds the two rewriter-side copies is **I15**.
2. **The rewriter could already rewrite `## Check AP — …`.** `relabel-extension-checks.sh` defines
   `ANCHOR_RE` as `…([0-9]+[a-z-]*|[A-Z]{1,3}[0-9]*)[[:space:]]*[.—]` and has since the widening for
   `### H1.`; its own inline comment names that exact heading form as one it resolves. **No rewriter
   change was owed in this release or any other**, so "both change in one release or neither does"
   had nothing behind it.
3. **Unloadability's remedy was never the relabeller.** The relabeller adds an `[ext:<id>]` label to
   resolve a NUMBER COLLISION. What clears an `UNLOADABLE` is an anchor plus `gate_types:`, or
   deletion — which GM1's own FAIL message already prints, and which an alphabetic id satisfies
   exactly as a numeric one does.

**The FP measurement was run anyway, because §6.8 asked for it, and it is empty.** The 39
hand-applied `[ext:…]` labels were stripped from a scratchpad copy of the consumer's skill tree and
the relabeller re-run: **32 proposals, 0 outside the hand-applied set.** Control: the intersection is
32 and both compared files are non-empty, so the `comm` is not answering on an empty side. The 2 hand
labels it does not propose are not misses — `2s` and `2a` are ids core does not define in the file
each entry hooks, verified with a control returning **1** for `15` on the identical invocation. The
other 5 labels are in `extensions/README.md`, which the `kind:` filter skips. Dry-run only; the
consumer's `HEAD` and its four pre-existing runtime modifications are unchanged.

**What the widening admits, measured before it was written.** Across core's `skills/ai-dlc/` and the
consumer's installed tree the alphabetic branch harvests exactly `H1`, `H2`, `AP`, `VH` and the
consumer's `H1` — every one a real id, **0 spurious**. The `—` terminator admits **no numeric heading
at all**. Nothing that matched before stops matching (numeric branch unchanged at **171** core
matches; control: a bogus grammar matches 0).

**Consumer effect, measured against `39f0248ff` and again from a tree built by `install.sh`:**
`UNLOADABLE` **`19b 2s` → `19b 2s AP VH`**, and `validate-layer-entries` **unmoved at 0 errors /
2 warnings**. No new `CHECK OUT OF BAND` — `below_band` already excluded alphabetic ids — and no new
collision, because the consumer's `H1` extension heading is correctly labelled and `heading_labelled`
clears it. **Note the direction: this row RAISES the `UNLOADABLE` count**, which is §3 criterion 3
read the way §5's ranking note stated it — the 2 was an understatement and 4 is the honest number.
The two new members are dispositioned in writing here and in the CHANGELOG.

**One form deliberately NOT widened, on a measured FP.** `bold_anchors_of_file` harvests the
`**24. …**` pseudo-heading. The alphabetic branch applied there harvests
`**QA — validate every AC …**` (`steps/implementation.md`, present in core and in the consumer's
installed copy) as a check id `QA` — a false positive with no remedy, since there is no check `QA` to
anchor. The bold form stays numeric and the file says why.

**Two lookups widened with the harvester, for the non-obvious reason.** `heading_title` and
`heading_labelled` harvest nothing; they resolve an id already harvested. Left narrow, a widened
harvester feeds them an id whose title comes back empty, an empty title routes the collision arm into
its RESTATES branch, and `heading_labelled` can never clear it — the "remedy that does not remedy"
defect that function's own header records, reached from the other side. Their terminator is an
alternation, not the bracket class `[.—]` the shell grammar uses: a byte-oriented `awk` treats a
multibyte `—` inside brackets as three bytes, and `sub()` would strip one and leave the rest in the
title.

**The mechanism, and it is the finding worth keeping.** `ANCHOR_RE` and `CHECK_HEAD_RE` are the same
grammar in four files. I15 held the rewriter pair identical to *each other*; I47 held the detector
pair identical to *each other*. **Both were green for four releases while the pairs diverged from one
another** — two internally consistent halves of one grammar, which no pair-check can see and which is
strictly harder to spot than a single forked copy. I47 is now a three-way join, with I15 carrying the
fourth definition transitively. The mutant is a **reversion**: narrow both detectors, in step, back to
the grammar this release replaced. The old arm is satisfied by construction — the fixture asserts the
two mutated copies are byte-identical and fails itself if they are not — so **only** the new arm can
fire, and it does; removing the arm turns that one fixture line red and leaves the other two green.
No fixture arm exists for the new "cannot find `ANCHOR_RE`" branch on purpose: I15 reads the same
assignment, so deleting it fails both invariants and neither mutant would be attributable.

**Also fixed, same class as the blocker:** both detectors said their `CHECK_HEAD_RE` copies were
bound by **I46**. I46 binds the extension `kind:` vocabulary. A citation a reader cannot follow is a
join that reads as verified and is not — two more instances, in the same two files as the I34
misattribution.

**No contract change.** `LC-E17`'s normative text — *"A check an extension DEFINES as a heading is
loadable"* — was already grammar-agnostic and already covered `AP` and `VH`; only its enforcer was
narrow. `contract_version` stays **7**.

**Generalise it.** A recorded blocker is a claim. This one had three verifiable parts, all wrong, all
checkable by opening the file it named — and the predecessor's §9 wrote it, two handoffs restated it,
and the code comment carrying it read as a design note rather than as the defect. **Before treating a
"blocked on X" in this file as a constraint, check that X is what the record says it is.** Rows 6, 7
and 9 each carry one.

### Row 9 — the cross-script mode join. **RANKED 3rd.**

> **▶ DONE — SHIPPED as v0.216.0, 2026-07-30.** Ticked in §5, RESULT below, and the
> `▶ NEXT STEP` block at the top now points at row 7. Nothing here is owed. The cheap
> precondition this row was told to run first answered **NO** — I59 absorbed none of the subject
> set — and the recorded blocker under it was, for the third row running, a claim rather than a
> constraint.

**State [R — predecessor §9, now four instances].** I49 binds `core-paths.sh`'s modes, I53
`validate-escalation-resolution.sh`'s, I59 (v0.214.0) every mode a shipped script dispatches to its
own prose. `CLAUDE.md` says derive both sides of a join rather than hand-list either; this is
hand-listed three ways.

**The generalisation was measured and rejected:** 31 (script, mode) pairs across 15 targets, **FP
set not empty — 8 misses, most of them the derivation's own grammar** (`--exclude` harvested from a
git pathspec and from a grep flag, `--mode` from prose, dispatch forms that are not `case` arms).

**Do.** Fix the extractor first; write the invariant only when the FP set is empty or enumerated.
**Check I59 first** — it shipped after §9 recorded this and may already have absorbed part of the
subject set.

#### Row 9 RESULT — SHIPPED v0.216.0, 2026-07-30. `I60`. Distribution-only; graph untouched.

**The precondition answered NO, and the answer is a distinction the ranking note did not have.**
The join has two halves. **I59 (v0.214.0) generalised the half row 9 was not about** — every mode a
shipped script *dispatches* is named in its own prose. Row 9's half is the reverse: every mode a
shipped file *cites* on another script is one that script dispatches. I59 never touched it, and its
own header records the reverse direction as measured-and-declined for a *within-file* citation
grammar, which is a different join from this cross-script one.

**I59 does not even subsume I49's and I53's documentation arms**, and that is a measurement rather
than a reading. On a copy of `core-paths.sh` with `--list` removed from its `usage()` echo and the
dispatch untouched: **I49 reports `--list`, I59 stays silent** — I59 accepts a mode named in *any*
comment line, I49 requires it in the usage line. Control, same invocation: the unmutated copy
returns empty on both. So the two per-target invariants keep both arms and nothing was retired.

**The subject set is a different set, not a different size.** Re-derived at 0.215.0:
**44 (script, mode) pairs across 25 targets**, against §9's recorded **31 across 15**. That is the
predecessor's row 7 lesson — the counts were of the wrong set — for the third row of this program.
§9's third instance (`validate-mandatory-rules.sh` → `validate-audit-anchors.sh --prior-sprint-sha`)
is inside the derived set, along with 22 targets nobody had hand-listed.

**All 8 recorded misses were the extractor's, in two enumerated classes.** Neither is a property of
the tree:

| Class | Count | What it was |
|---|---|---|
| **The validator file itself** | **5** | `validate-enforcement-map.sh` quotes `<script>.sh --mode` in error prose, in its **own grep flags** (`--exclude=core-paths.sh --exclude=…` reads as a citation of `--exclude`), and inside I59's probe heredoc. **I49 and I53 already exclude that file by name** — the exclusion is inherited, not invented |
| **Dispatch forms the `case` grammar cannot see** | **3** | Six shipped scripts parse with `[ "$1" = "--x" ]` or `[[ "$1" == "--x" ]]`; `audit-rule-files.sh` dispatches `--fail-on=any\|deterministic` as **valued** arms while callers cite `--fail-on` |

With the self-exclusion restored and both dispatch forms read (both sides normalised at `=`):
**44 pairs, 0 ghosts, 0 unresolved targets — the false-positive set is EMPTY.** Measured both ways in
one invocation: with the validator left in corpus the run reports 3 ghosts and 2 unresolved, all
five bogus; with it excluded, zero.

**Unresolved target names are skipped, not reported**, and that is a scope call rather than an
oversight: "does core ship a script by this name" is I50's join over a different citation grammar,
and reporting it here would fire on every consumer-owned script a template legitimately names.
Measured: 0 citations in the shipped corpus resolve to nothing, so the skip discards no live subject
today.

**The invariant can fire, proven three ways rather than asserted.** I60 writes its own liveness probe
each run, and **the probe target dispatches one mode as a `case` arm and one as a `[ "$1" = … ]`
test** — the second form is the fix this release shipped, and an extraction that lost it again would
go quiet rather than red. Targeted mutants, each with its own message and an unmutated control that
stays silent: break the non-case dispatch form → *"has lost the non-case form"*; break the citation
grammar → *"did not fire on its own probe"*; collapse the corpus → *"I60 derived only …"*.
Four fixture arms in `enforcement-map-sites` (the family home — I49, I53 and I59 all live there).
**The reversion mutant — excise I60 entirely — kills only the two I60 assertion lines and leaves all
seven prior assertions green.**

**The finding worth keeping: a guard downstream of a liveness probe can only be tested on an input
the probe still passes.** The corpus-floor arm was written first as "break the shared citation
function and require the floor message". It failed — against a floor that was working. The probe
reads the same function, so it fired first and the floor was never reached. The arm now repoints the
**corpus scan's** root and leaves the probe's own alone. Generalised: a probe that shields the rest
of an invariant also shields it from its own fixture, and an arm written without noticing that
reports a defect in a mechanism that is fine. This is adjacent to the repo's named class rather than
an instance of it — the check could fire, but the *assertion* could not.

**Three false zeros of the measurer's own making, all caught by controls, all recorded because they
are cheap to repeat.**

1. **`$S` not exported into a `bash -c` script**, so the derivation wrote to nowhere and reported
   `distinct targets: 0`. The universal-token control in the same invocation returned **254 files**,
   which is the only reason it read as a broken run rather than an empty tree.
2. **zsh does not word-split unquoted `$var`**, so `set -- $pair` inside a `for` loop passed
   `"audit-rule-files.sh --fail-on"` as a single argument and every `find` returned nothing. Already
   recorded in this repo's memory; it cost minutes again. Force `bash -c` for any loop that splits.
3. **A basename join answered SHIPPED for a file that is not shipped.** Checking which changed files
   reach a consumer tree with `find -name "$(basename …)"` matched `run.sh` — one of **82** installed
   fixtures. The corrected join is on the path suffix, and it reports the truth: this release is
   distribution-only, and `enforcement-map-sites` is not among the 82 (control: `tests/fixtures/`
   is non-empty and lists `adversarial-citation` and others). **A join key that is not unique is a
   join that cannot answer**, which is `CLAUDE.md`'s per-file-grep-against-a-glob trap one step over.

**Verification.** `validate-enforcement-map.sh` exit 0, `validate-no-dead-doc-refs.sh` PASS,
`shellcheck -S error` clean on both changed files, **87/87 fixtures**. Re-verified on a tree built by
running `scripts/install.sh` into an empty directory: the validator is correctly **not** shipped and
the control (`scripts/ai-dlc/core-paths.sh`) is. No contract change — I60 is an invariant of the
distribution's own validator, not a layer-contract clause, so `contract_version` stays **7**.

### Row 10 — the machinery home, inverted. Unmeasured, likely REFUTED. **RANKED 5th.**

> **▶ NEXT STEP — OPERATOR.** This one is a decision before it is a session.
>
> **The call to make: is this row worth a session at all?** It is the largest and least measured row
> in the program, its predecessor produced **eight consecutive refutations** on the same subject
> (§4a), and §9 of the predecessor already argues that the home staying a declaration with an empty
> home is **correct behaviour, not a defect**. Closing it unstarted as REFUTED-BY-PRIOR-MEASUREMENT
> is a legitimate ending and costs nothing.
>
> If you want it run, open a fresh session, cwd `/Users/n8/git/ai-dlc`, and paste:
>
> ```
> Read docs/analysis/post-program-gap-closure-plan.md in full, then execute row 10.
> Measure the VALUE before building anything: if an undeclared script is exactly
> as invisible as it is today, this row ends REFUTED and the home stays as it is.
> Do not re-attempt any of the 8 refuted predicates in §4a's Refutation Index.
> ```
>
> **On ending: tick §5, and update the `▶ NEXT STEP` block at the top to say the program is closed —
> with the count of rows SHIPPED, REFUTED and RETIRED.** That block is the last thing anyone reads.

**Do not re-attempt the refuted predicates in §4a.** All seven asked core to *infer* which consumer
executables are ai-dlc. That question has no answer core can compute, and the measurement is
conclusive.

**The direction never tried.** Every other durable mechanism in this program is *declare + join*:
someone states something and an invariant binds the statement to its readers. The home is the one
place attempted as inference. Candidate: **the consumer declares its machinery, and core enforces
only the declaration** — nothing outside it is claimed, and the release says so rather than implying
whole-tree coverage.

**Everything about this is a hypothesis.** Open questions, each of which can kill it: what a
consumer gains by declaring; whether a declaration nobody is obliged to write is enforcement or
theatre; and whether §9's note that the home "gains inhabitants when a consumer files something
there, which is now a consumer decision with nothing blocking it" is already the whole answer.

**Measure the value before building.** If an undeclared script is exactly as invisible as it is
today, this row ends **REFUTED** and the home stays a declaration with an empty home — which §9
already argues is correct behaviour, not a defect.

**Ranked last on purpose.** Largest, least measured, and the one whose predecessor produced seven
consecutive refutations.
