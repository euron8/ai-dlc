# Post-program gap closure — plan

**Successor to `docs/analysis/layer-contract-program-handoff.md`, which is COMPLETE and must not be
deleted.** That file records what was built and — more valuably — what was measured and refuted.
This file does not restate it, supersede it, or re-open any decision it closed.

**Point a fresh Claude Code session at this file in `/Users/n8/git/ai-dlc`.**

Tracked on purpose. The predecessor claimed it was untracked because "committing it would need a
version bump per edit"; false against the tree — `docs:` and `chore:` subjects ship without a bump,
and the predecessor was tracked anyway. Ticking this ledger is a `chore:` commit.

---

## 0. How to use this file, and WHICH REPO YOU ARE IN

1. Read §1–§4 in full. Short, and every line is load-bearing.
2. Read the **Progress Ledger** (§5) for the next unticked row.
3. Read that row's section in §6, execute it, tick the ledger with a sha or a measured count as the
   last act. A fresh session's only way to know where it is.
4. Stop at a **`⏹ SESSION BOUNDARY`**.

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
| **graph freeze** | **RE-IMPOSED, operator-directed 2026-07-30. No sprint runs in graph until this program completes.** |

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
| 4 | **Generate the graph retirement brief** — a multi-session operator handoff, the pull-brief shape — §6.4 | BUILD | no | — |
| 5 | **Execute the retirement in graph, then UNFREEZE** — operator-driven graph sessions — §6.5 | RETIRE | **YES** | — |
| ⏹ | **SESSION BOUNDARY — the freeze ends here. Everything below runs against a live consumer.** | | | |
| 6 | **`LC-N5` WARN → ERROR** — subject set shrinks to 2 after row 5; still owed a `kind: qualifier` measurement — §6.6 | CORE | no | — |
| 7 | **I38 reverse: every normative sentence carries a clause id** — blocked on normalising `overrides/README.md` — §6.7 | CORE | no | — |
| 8 | **Checks `AP` / `VH`: alphabetic ids are invisible to GM1** — blocked on the relabeller's FP set — §6.8 | CORE | no | — |
| 9 | **Generalise the cross-script mode join** — blocked on fixing the extractor's 8 measured misses — §6.9 | CORE | no | — |
| 10 | **The machinery home, inverted: consumer declares, core enforces the declaration** — unmeasured, may be refuted — §6.10 | CORE | no | — |

**Version numbers are not pinned to rows.** Rows that end REFUTED consume no version.

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

### Row 5 — execute in graph, then unfreeze. FREEZE-BEARING.

**Operator-driven graph sessions.** Nothing here is edited from an ai-dlc session. A core defect
found during execution is fixed in ai-dlc and re-delivered — never patched in graph. That rule held
through the entire 0.213.0 pull and is not relaxed.

**Tick this row with the merge sha, the `+added / −removed` tally, and the post-merge counts for
`W5` and `UNLOADABLE`.** Then unfreeze, and say so explicitly in the tick — an unfreeze nobody
records is a freeze that never ends.

**The four §3 criteria are this row's exit condition, not row 10's.**

### Row 6 — `LC-N5` WARN → ERROR.

**Reordered: this now follows retirement.** Row 5 disposes checks 33/34/35, leaving **2** live `W5`
subjects (rules 31/32) instead of 5 **[V]**. An ERROR that fires on live subjects with no remedy
filed wedges the next pull — the failure the predecessor's row 6 shipped into and had to close.

**What is owed is a measurement, not code:** which of graph's entries would actually declare
`kind: qualifier`, derived **per hooked file and per frontmatter flag**. The predecessor's §9 warns
that "the four rules that qualify core numbers" is a subagent-era figure v0.196.0 did not re-derive,
and its row 7's recorded lesson is that the counts were of the **wrong set**, not merely wrong.

**May end REFUTED** — if the grain does not separate a deliberate qualifier from a squatter on real
entries, `W5` stays WARN and the row records why.

### Row 7 — I38's reverse direction.

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

### Row 8 — alphabetic check ids.

**State [R — predecessor §9].** `CHECK_HEAD_RE` is numeric, so `Check AP` and `Check VH` are
invisible to GM1, and both are reported live and unloadable. **Do not read GM1's silence as evidence
they are fine** — they are structurally outside what it can see.

**The constraint.** Widening the grammar is bound to `reconcile/relabel-extension-checks.sh` by
**I34**. A detector that finds a heading the rewriter cannot rewrite reports a defect with no
remedy, so both change in one release, and the relabeller's FP set across every heading it already
rewrites is **unmeasured**. Measure first.

### Row 9 — the cross-script mode join.

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

### Row 10 — the machinery home, inverted. Unmeasured, likely REFUTED.

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
