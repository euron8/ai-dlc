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

- **The machinery home's ERROR clauses stay refuted.** Seven candidate predicates measured, all
  failed **[R, predecessor §7.6]**. Do not re-attempt on a path scan, a name shape, a layer-entry
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
| 2 | **Disarm the predecessor's self-delete; index its refutations** — §6.2 | PRESERVE | no | — |
| 3 | **Derive the retirement set with controls — per subject, is the core absorber actually drop-in?** — §6.3 | MEASURE | no | — |
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

**Free win, confirm it first:** `validate-no-direct-main-push.sh` (46 lines) is wired into nothing
**[V]** — a `grep` across `ci-local.sh`, `.githooks/pre-push` and the extension check files returns
no site, against a control that returns sites for the other five. Dead code, deletable with zero
coupling.

**Also derive the entry cost.** Every edit to `gate-validation-domain.md` changes a layer entry's
digest and re-opens its adjudication at the next pull. Under freeze with no pull pending that is
cheap, and the retirement **reduces** the entry's content — so state the expected effect on the next
pull's adjudication load. That number is this program's payoff argument.

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
