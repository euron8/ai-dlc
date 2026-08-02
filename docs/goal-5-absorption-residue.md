# Goal 5 — absorption of the eight duplicate consumer scripts: one arithmetic, and what is left

**Status: PARTIAL. The residue is OPEN with a per-subject disposition (§5b) — two core seams named, one operator question, and 180 lines that were never subjects.**

The charter's fifth goal was *"absorption of the eight consumer scripts that merely duplicate a core
script with one extra arm."* This document exists because that outcome has been stated in three
places with three different arithmetics, none of which reconciles with the others, and a reader
quoting any one of them quotes a different number. **Every figure below is re-derived on a single
instrument against graph at `daf1d4a46` (2026-08-01), and every percentage states its denominator.**
**§2 carries one correction taken later the same day at `c459f207a`**, after graph's goal-2
segregation established that one of the charter's eight was never a subject.

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

*(That figure was correct for the subject set as the charter defined it. It is superseded by §2's
correction, which removes one row the charter should never have listed: the residue is **1,717**.
Both are stated because the first is what the re-derivation found and the second is what the tree
supports — and conflating those is how this goal acquired three arithmetics in the first place.)*

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
| ~~`validate-no-direct-main-push.sh`~~ | ~~46~~ | ~~46~~ | — | **NOT A SUBJECT — see below** |
| `retro-replay-harness.sh` | 97 | 97 | **0** | REFUTED |
| **Total** | **2,007** | **1,717** | **−290** | |

Controls, same invocation: `ci-local.sh` resolves at both refs at 1,659 lines; a bogus path under
`scripts/` returns `fatal: path … does not exist` at both. So `GONE` is a reading and not a failed
lookup.

**Retirement was 290 lines. Against each of the three denominators that have been used:**

- **290 of 2,007** — the subject set as it actually stood when the program started = **14.4%**
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
3. **2,007** — the measured subject set. The only one of the three that a command reproduces.

**CORRECTED 2026-08-01: `validate-no-direct-main-push.sh` is not a subject at all.** The charter's
Part F names it as consumer ai-dlc machinery. When graph performed the goal-2 segregation, its
session applied the test — *would this script still have a job with ai-dlc removed?* — and judged
it **domain code**: its inputs are git refs and commit subjects, and with ai-dlc gone it still
blocks direct pushes to `main`. It was excluded from the machinery inventory with that reasoning
stated, and reported rather than moved, which is exactly what that step's stop condition required.
**So the charter's Part F list was wrong by one row**, and its 46 lines leave both the subject set
and the residue: 2,053 → **2,007** and 1,763 → **1,717**. **Retirement does not move** — this
script was refuted, never retired — **so the correction changes a denominator, not an
achievement.**

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

**1,717 lines are live in the consumer today**, across five files, and they are an **OPEN** item. As of 2026-08-01 all five sit inside the declared machinery home — goal 2's segregation — so the residue is now *segregated* rather than mixed with domain code, which is a different thing from being retired.

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

## 5b. Per-subject disposition — the analysis the refutations never did

**Added 2026-08-01, and this section is why §5's "OPEN item" was not an ending.** The refutations
measured whether CORE has the arm. That answers a different question from the charter's premise,
which is that each subject *"merely duplicates a core script with one extra arm."* `validate-no-
direct-main-push.sh` proved that premise can simply be FALSE for a subject — and the test had never
been applied to the rest.

**Each subject resolves to exactly one of three dispositions:**

- **(i) NOT A DUPLICATE** — the remainder is consumer-specific. It leaves the subject set, and the
  charter was wrong for that row.
- **(ii) CORE LACKS A SEAM** — the consumer re-implemented because core offered nowhere to hook.
  **Actionable core work.**
- **(iii) CORE LACKS A DUTY** — core does not claim the responsibility. **An operator decision about
  core's scope, not a measurement.**

**Residue re-derived at graph `c459f207a`: 1,722 lines across 5 files**, not the 1,717 in §2.
`generate-sprint-status.py` went 1,068 → **1,073** when the segregation rewrote its own path
references. *A figure moving while a document about moving figures is being written is the finding,
not a typo.*

| subject | lines | disposition | evidence |
|---|---|---|---|
| `scan-stray-provenance.sh` | 83 | **(i) NOT A DUPLICATE** | The duplicated half is gone. All 8 of its `stray`/`party-mode` mentions are deprecation text; lines 78–79 are an error message redirecting the caller to core's `validate-provenance-block.sh --strays`. What remains is an S241-5 fixture-provenance lint core has no concept of. **Part of it is a pure deprecation stub and is retirable in the consumer.** |
| `retro-replay-harness.sh` | 97 | **(i) NOT A DUPLICATE** | It replays graph's OWN historical failures — `S154`, `S155`, `S238`, `S239`. Core cannot hold a fixture for another project's sprint history. Control: exactly one core fixture matches those tokens, `check-15-bypass/README.md` naming `LR-S155-3` in an unrelated wording note. |
| `audit-rule-exercise.sh` | 105 | **(i) NOT A DUPLICATE** — corrected 2026-08-01 | **Corrected on a structural test.** Its `lib/gate-log-corpus.sh` exists to bind two core scripts that once enumerated one corpus two ways. **That divergence is gone from core**: glob-corpus **0**, `nullglob` **0**, and **0** core files use `nullglob` at all; graph's installed copies of both scripts are byte-identical to core today. The helper's only live caller is this audit, whose other half is graph-specific. Absorbing it imports a fix for a defect core no longer has. *(Its header's stated blocker is separately false — it claims core is "a python3 implementation" and core's is `#!/usr/bin/env bash`.)* |
| `generate-sprint-status.py` | 1073 | **(ii) CORE LACKS A SEAM** | Same artifact, two writers. Core's `sprint-status.sh` owns the sprint-status envelope and **does** read story files (28 references; control: 8 for its schema), but its modes are `--check --closed-at --evidence --intensity --name --render --retro-doc --root --sprint --variant` — **no derive-from-frontmatter mode**. The consumer's tool writes frontmatter-derived values into core's artifact because there is nowhere to hook. |
| `audit-main-since.sh` | 364 | **(iii) CORE LACKS A DUTY — OPERATOR QUESTION** | Re-derived: `trunk audit` **0** files in `core/`+`templates/`, `post-merge` 2, `audit-main` 1 (control: `cycle-commits` **12**). It is the detection mechanism behind graph's own Rule 20 and catches merges that bypass both hooks, including `--admin` and web-UI merges. **Whether core should claim a post-merge trunk-audit duty is a scope decision, not a measurement.** |

### What this changes

**180 lines leave the subject set** — the two `(i)` rows are not duplicates and never were. The
subject set becomes **1,827** and the live residue **1,542**, with retirement unchanged at **290 =
15.9% of 1,827**. **Retirement does not move on any of these corrections; only denominators do.**

**1,178 lines are (ii) — actionable core work**, and that is the disposition the refutations never
distinguished from (iii). Two seams are named: an `--exercise` mode on `audit-rule-files.sh`, and a
derive-from-frontmatter mode on `sprint-status.sh`. **Neither is scheduled here** — naming a seam is
not shipping one, and each needs its own measurement, false-positive set and fixture.

**364 lines are (iii) and are the operator's question**, stated as a question: *should core claim a
post-merge trunk-audit duty?* If yes, the arm is core's and the consumer's script retires. If no,
`audit-main-since.sh` is legitimate consumer machinery, it leaves the subject set like the `(i)`
rows, and goal 5's residue is **1,178** — entirely (ii).

### Goal 5's remaining distance, stated so it is not an open-ended "OPEN"

Goal 5 closes when: both `(ii)` seams are shipped or explicitly declined with a measurement, and the
`(iii)` question has an operator answer. **That is two core changes and one decision — not an
unbounded backlog**, and it is the first time this goal has had a finite statement of what remains.

## 6. Summary — SUPERSEDED 2026-08-01 by §7. The table below is left as the record of what §2–§5b measured.

| | |
|---|---|
| Promised (locked decision 4) | ~3,000 lines |
| Charter's own tabled subject set | 2,610 lines — overstates the tree by 557 |
| Measured subject set | **2,007 lines** |
| Retired, net | **290 lines** |
| Retirement rate | **14.4% of 2,007** / 11.1% of 2,610 / 9.7% of ~3,000 |
| Live residue | **1,717 lines** across 5 files — **OPEN**, and all five now sit inside the declared machinery home |
| Subjects retired | 2 of 8 |
| Subjects partially absorbed | 1 of 8 |
| Subjects refuted | 5 of 8, all with receipts, 2 re-derived at v0.232.0 |
| Subjects that grew | **1** — `audit-main-since.sh`, +16 lines |

**The capability half of this goal is real**: six core arms shipped, each measured, and two of them
fixed genuine defects in the scripts they were replacing. **The retirement half — which is what the
charter's word "absorption" means — delivered 14.1% of the only denominator that a command
reproduces.**

---

## 7. The number moved — re-derived 2026-08-01 at graph `f15ce591552e9db18bf6df07f4ba3d4b09ab072d`

**This is the first time in the program that goal 5's retirement figure has changed.** Every prior
correction in this document moved a DENOMINATOR; this one moves the achievement, because
`audit-main-since.sh` is gone from the consumer's tree.

**Re-derived, not subtracted.** Every cell below is `git show <ref>:<path> | wc -l` at the same two
refs §2 used — `18e00ef40` before, `origin/main` after — with the segregation's path move
(`scripts/` → `scripts/ai-dlc-local/`) resolved per file:

| Subject | before | now | change |
|---|---|---|---|
| `check-protected-core-paths.sh` | 162 | **GONE** | **−162** |
| `check-mutation-red-anchor.sh` | 72 | **GONE** | **−72** |
| `scan-stray-provenance.sh` | 155 | 83 | **−72** |
| `audit-rule-exercise.sh` | 105 | 105 | 0 |
| `generate-sprint-status.py` | 1068 | **1073** | **+5** |
| `audit-main-since.sh` | 348 | **GONE** | **−348** |
| `retro-replay-harness.sh` | 97 | 97 | 0 |
| **Total** | **2,007** | **1,358** | **−649** |

Controls in the same invocation: `ci-local.sh` resolves at both refs (1,659 → 1,661), and a bogus
path under `scripts/ai-dlc-local/` returns nothing at either. So each `GONE` is a reading.

**Retirement is 649 lines = 32.3% of 2,007** — 24.9% of the charter's 2,610, 21.6% of decision 4's
~3,000. Against the **14.4%** this document recorded a day earlier, that is the movement.

**Excluding the three `(i)` rows** — the 285 lines §5b established are not duplicates and never
were — the reading is **649 of 1,722 = 37.7%**. Both are stated because they answer different
questions, and neither is quotable without its denominator.

**A SECOND SUBJECT HAS NOW GROWN DURING THE PROGRAM.** `generate-sprint-status.py` is **+5**
(1068 → 1073), joining `audit-main-since.sh`'s +16. The summary row above said "1"; it is 2, and
the pattern is worth naming: **a subject nobody is absorbing does not sit still.**

### The 510 lines that are NOT in this arithmetic, stated so they are not quietly added

The retirement branch also deleted `tests/test-audit-squash-enum.sh` (337 lines, wired into no
runner) and Section C of `tests/test-pr-class-provenance-in-non-retro.sh` (173 lines, which drove
the deleted script; 16 → 8 assertions, 0 failed either side). **They are real deletions and they
are not charter subjects.** Adding them would produce a fourth denominator over a fifth population,
which is the exact error §2's "three denominators" section exists to record. The honest statement
is: **649 lines of the charter's subject set, plus 510 lines of collateral the retirement enabled.**

### What the residue is now

**1,358 lines across 4 files, and its composition changed as well as its size.**

- **285 lines are `(i)`** — `scan-stray-provenance.sh` 83, `retro-replay-harness.sh` 97,
  `audit-rule-exercise.sh` 105. Not duplicates, never were.
- **1,073 lines are `(ii)`** — `generate-sprint-status.py`, and **v0.237.0 built the seam it named**:
  core's `sprint-status.sh derive-stories` is the derive-from-frontmatter mode §5b measured as
  absent. **The seam exists; the consumer has not adopted it.** Its `story-fields.md` arrived
  declaring the literal `none` in the 0.237.0 pull, which is honest and is not adoption.

  **AND THAT IS A SCHEDULED ROW, NOT A CLOSING STATEMENT.** This document's first draft of §7 said
  adoption was *"a judgement only the consumer can make"* and therefore not work anyone owed. The
  premise is true and the conclusion does not follow: **core cannot decide which fields are
  derivable, and the consumer already has.** `generate-sprint-status.py:47` carries a `DERIVABLE`
  list of nine names (`status priority model gate_1_model effort capital_path acceptance_criteria
  sprint title`); control, a bogus token returns 0. Declaring them is a transcription of a list
  already in force — the same act that retired `audit-main-since.sh` a day earlier.

  Three further measurements make it schedulable rather than aspirational. Core now dispatches
  `--check / --render / check-stories / close / derive-stories / roll / sprint-id` against the
  consumer tool's `--check / --close-sweep / --dry-run / --migrate / --migrate-artifact-dir /
  --root / --sprint / --validate / --write`. The consumer's own `EXIT_CHECK_ZERO_FILES = 3` and
  `EXIT_CHECK_ZERO_COMPARISONS = 4` are **the two exit codes v0.237.0 shipped**, transcribed from
  this tool — **the semantics already agree.** And the caller set is enumerable: two overrides, one
  role file, and the machinery inventory.

  **The one genuine judgement is per field: DERIVED from the story file, or AUTHORED in the
  envelope and mirrored into it.** Only core cannot tell those apart. A field that is authored must
  not be declared, and if most of the eight turn out authored, that is a real answer that shrinks
  what the seam can absorb — a measured residue rather than a retirement. It is `§6c-43`.
- **`(iii)` is EMPTY.** The operator's question — *should core claim a post-merge trunk-audit
  duty?* — was answered YES by v0.235.0/v0.236.0 and the answer was executed.
- **The `(i)` rows are not uniformly closed either.** §5b's own note on `scan-stray-provenance.sh`
  says *"part of it is a pure deprecation stub and is retirable in the consumer"*, and no row
  carried it. Measured at `origin/main`: the repo-wide arm was retired in 0.214.0 and what sits at
  that path is an `echo … >&2; exit 2` block whose own comment says the script *"now implements
  `--fixture-provenance <path>...` only"*. **A finding stated in a document and carried by no row is
  how a loose end survives** — `D-6c9.4` was recorded three times before anyone fixed it. It is
  `§6c-44`.

**CORRECTION to §5b, and it is an internal inconsistency rather than a new measurement.** §5b says
*"180 lines leave the subject set — the two `(i)` rows"* while its own table marks **three** rows
`(i)`; `audit-rule-exercise.sh` was reclassified in that same table and the summary sentence was
not updated with it. The figure is **285**, not 180. Nothing downstream depended on it — §7 above
re-derives from the tree rather than from that subtraction — but a document about arithmetic
carrying two arithmetics is the defect it exists to name.
