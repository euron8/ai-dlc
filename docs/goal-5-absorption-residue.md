# Goal 5 — absorption of the eight duplicate consumer scripts: one arithmetic, and what is left

**Status: PARTIAL. The residue is OPEN, not closed.**

The charter's fifth goal was *"absorption of the eight consumer scripts that merely duplicate a core
script with one extra arm."* This document exists because that outcome has been stated in three
places with three different arithmetics, none of which reconciles with the others, and a reader
quoting any one of them quotes a different number. **Every figure below is re-derived on a single
instrument against graph at `daf1d4a46` (2026-08-01), and every percentage states its denominator.**

The instrument is `git show <ref>:<path> | wc -l`. All subject files end in `0a`, so `wc -l` is the
true line count and not an undercount of a final unterminated line.

---

## 1. The finding comes first, because re-derivation moved the figures

The prior scoring of this goal was taken against graph at `39f0248ff` and compared the **charter's
stated line counts** against **counts measured in the tree**. Those are two instruments, and they
disagree by exactly one line on every subject:

| Subject | charter's column | measured at `18e00ef40` |
|---|---|---|
| `check-protected-core-paths.sh` | 163 | **162** |
| `check-mutation-red-anchor.sh` | 73 | **72** |
| `scan-stray-provenance.sh` | 156 | **155** |
| `audit-rule-exercise.sh` | 106 | **105** |
| `generate-sprint-status.py` | 1069 | **1068** |
| `audit-main-since.sh` | 349 | **348** |
| `validate-no-direct-main-push.sh` | 47 | **46** |
| `retro-replay-harness.sh` | 647 | **97** |

Seven for seven, off by one in the same direction. That is an instrument difference in the charter's
column, not a change in the tree — and reading it as a change produced four wrong conclusions:

**Four subjects were credited with a retirement and their bytes never moved.** `audit-rule-exercise.sh`,
`generate-sprint-status.py`, `validate-no-direct-main-push.sh` and `retro-replay-harness.sh` have
**byte-identical blobs** at `18e00ef40` and at `daf1d4a46`. Three of them were scored as "−1 line"
and the fourth as "−550". The correct figure for all four is **zero**. Control from the same probe:
`scan-stray-provenance.sh` and `audit-main-since.sh` come back `CHANGED`, and `ci-local.sh` — a file
nobody claims this program touched — comes back `IDENTICAL`, so the test distinguishes.

**Two subjects moved by one more line than recorded.** `scan-stray-provenance.sh` shrank by **72**,
not 73. `audit-main-since.sh` **grew by 16**, not 15 — it is still the only subject in the set that
got larger while a program to shrink it was running.

**And the prior arithmetic did not subtract to its own stated total.** It recorded a corrected
subject-set size of ~2,060 and a residue of 1,763, then reported **307** lines retired.
`2,060 − 1,763 = 297`. The 307 was carried because the two percentages quoted beside it (11.8% and
14.9%) were computed from it rather than from the subtraction.

**The residue is the one figure that did not move.** 1,763 lines, reproduced exactly.

---

## 2. The one arithmetic

Measured at `18e00ef40` — graph immediately before `39f0248ff`, the retirement commit — and at
`daf1d4a46`.

| Subject | before | today | change | disposition |
|---|---|---|---|---|
| `check-protected-core-paths.sh` | 162 | **GONE** | **−162** | RETIRED |
| `check-mutation-red-anchor.sh` | 72 | **GONE** | **−72** | RETIRED |
| `scan-stray-provenance.sh` | 155 | 83 | **−72** | PARTIAL — the stray arm absorbed, the rest live |
| `audit-rule-exercise.sh` | 105 | 105 | **0** | REFUTED (arm 1) |
| `generate-sprint-status.py` | 1068 | 1068 | **0** | REFUTED |
| `audit-main-since.sh` | 348 | 364 | **+16** | REFUTED (arm 4) — and it grew |
| `validate-no-direct-main-push.sh` | 46 | 46 | **0** | REFUTED |
| `retro-replay-harness.sh` | 97 | 97 | **0** | REFUTED |
| **Total** | **2,053** | **1,763** | **−290** | |

Controls, same invocation: `ci-local.sh` resolves at both refs at 1,659 lines; a bogus path under
`scripts/` returns `fatal: path … does not exist` at both. So `GONE` is a reading and not a failed
lookup.

**Retirement was 290 lines. Against each of the three denominators that have been used:**

- **290 of 2,053** — the subject set as it actually stood when the program started = **14.1%**
- **290 of 2,610** — the charter's own tabled total for the same eight files = **11.1%**
- **290 of ~3,000** — locked decision 4's promise = **9.7%**

The gross retirement is **306 lines** (162 + 72 + 72); the net is 290 because `audit-main-since.sh`
grew by 16 in the same window. Both are true and they answer different questions. **Quote the net,
and say it is net.**

### The three denominators, and why they differ

They are nested, and each is inflated relative to the one inside it.

1. **~3,000** — locked decision 4's promise. It overstates the charter's own table by **390 lines**,
   or 15%, and nothing in the charter derives it.
2. **2,610** — the charter's Part F table. It overstates the tree by **557 lines**: 7 from the
   one-line instrument skew above, and **550 from a single row**.
3. **2,053** — the measured subject set. The only one of the three that a command reproduces.

**The 550-line row has no support in graph's history at all.** The charter records
`retro-replay-harness.sh` at 647 lines. Measured across **every commit that has ever touched it** —
6 commits, all refs — its maximum size is **97**. It has never been larger. It was 81 at first
appearance and 97 since, and it drives `tests/fixtures/retro-replay/`, whose 14 files plus the
harness total 395 — which is still not 647 by any grouping.

---

## 3. The refuted subjects, with their receipts

Five of the eight were refuted. A refutation here means the *absorption arm* was measured and found
not to exist: the core script the consumer script was to be absorbed into does not do, and does not
claim to do, the job the consumer script does. **§7 of the governing plan requires a refutation to be
re-checked when the tree moves.** Arms 1 and 4 are re-derived below against core at **v0.232.0**;
they were last checked at v0.216.0.

**Arm 1 — `audit-rule-exercise.sh` → `audit-rule-files.sh --exercise`.** Core has no gate-log corpus
enumerator, so there is nothing for an `--exercise` arm to read. Measured over `core/` + `templates/`:
`gate_log_corpus` **0 files**, `gate-log-corpus` **0 files**. Control, same corpus: `Rule 26` matches
**36 files**. **HOLDS.**

**Arm 4 — `audit-main-since.sh` → `validate-cycle-commits.sh`.** Core states no post-merge trunk-audit
duty. Measured over the same corpus: `pr-class` **0**, `PR class` **0**, `validator-runs` **0**,
`watermark` **0**, `audit-results` **0** files. Controls, same corpus: `provenance` **74 files**,
`audit` **73 files**. **HOLDS.** *(The two controls read 73 and 70 at v0.216.0 and read 74 and 73
today — the corpus grew, the zeros did not.)*

**The other three — `retro-replay-harness.sh`, `generate-sprint-status.py`,
`validate-no-direct-main-push.sh` — were refuted by run-based mutant differentials**, which is a
stronger record than either of the two above: each was refuted by running the proposed core
replacement against the consumer's real inputs and showing it produced a different verdict. Those
measurements stand and are not re-litigated here. What this document withdraws is not the
measurements but the **disposition** that followed them — see §5.

**One subject is PARTIAL, not refuted.** `scan-stray-provenance.sh` lost its stray-provenance arm to
core and kept the rest: 155 → 83.

---

## 4. What "net −80" was, and why it is not a retirement figure

The retirement commit `39f0248ff` reports `23 files changed, 599 insertions(+), 679 deletions(-)` —
a whole-commit diffstat of **net −80**, and it has been quoted as this goal's result. It is not one.
Decomposed:

| | files | + | − | net |
|---|---|---|---|---|
| the whole commit | 23 | 599 | 679 | **−80** |
| the 3 subject scripts it touched | 3 | 29 | 335 | **−306** |
| everything else in the same commit | 20 | 570 | 344 | **+226** |

Control: the three subject paths resolve in that stat (3 of 3); a bogus path returns 0 from the same
extraction.

**So −80 is the retirement plus 226 lines of unrelated churn that happened to share a commit.** It
measures a commit, not a subject set. It is a third instrument over a third population, and it is the
reason this document exists.

---

## 5. The residue, and its disposition

**1,763 lines are live in the consumer today**, across six files, and they are an **OPEN** item.

They were previously dispositioned as *"formally dropped"*, on the reasoning that the refutations
closed them. **That disposition is withdrawn.** The governing decision of 2026-07-31 states that a
measurement may choose the mechanism but may not choose whether a goal survives, and *"the remainder
is closed, not owed"* is the phrase that closed two other charter goals without anyone being asked.

**What the refutations actually established** is that these six files cannot be absorbed *by the core
scripts proposed for them*. That is a true and well-evidenced statement about eight specific arms. It
is not a statement that the duplication does not exist, and it is not a decision that the 1,763 lines
should stay.

**What is owed, stated as the smallest honest thing:** any future proposal to absorb one of these six
names the core mechanism it would absorb into and measures it before a release is cut. There is no
scheduled work here and none is implied. The residue is recorded as open so that it is visible, which
is the whole distinction this document is making.

---

## 6. Summary

| | |
|---|---|
| Promised (locked decision 4) | ~3,000 lines |
| Charter's own tabled subject set | 2,610 lines — overstates the tree by 557 |
| Measured subject set | **2,053 lines** |
| Retired, net | **290 lines** |
| Retirement rate | **14.1% of 2,053** / 11.1% of 2,610 / 9.7% of ~3,000 |
| Live residue | **1,763 lines** across 6 files — **OPEN** |
| Subjects retired | 2 of 8 |
| Subjects partially absorbed | 1 of 8 |
| Subjects refuted | 5 of 8, all with receipts, 2 re-derived at v0.232.0 |
| Subjects that grew | **1** — `audit-main-since.sh`, +16 lines |

**The capability half of this goal is real**: six core arms shipped, each measured, and two of them
fixed genuine defects in the scripts they were replacing. **The retirement half — which is what the
charter's word "absorption" means — delivered 14.1% of the only denominator that a command
reproduces.**
