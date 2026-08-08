# Review — graph's artifact consolidation

**Plan item 19** of [`docs/plans/retire-graph-consumer-layer.md`](../plans/retire-graph-consumer-layer.md).
Operator request 2026-08-08: *"a review of graph consumers recent attempts at artifact
consolidation and determine if there are improvements we can make with that process or even a
different methodology altogether."*

**This is a review, not a release.** No core change is authorised by it. Every figure below was
re-derived on 2026-08-08 against `/Users/n8/git/graph` at `a8ef9412c` and
`/Users/n8/git/ai-dlc` at `aea1d00` (`VERSION` 0.315.0). The consumer was read and never
written. Numbers quoted from the plan are marked where they turned out to be stale.

---

## Summary

Consolidation is doing its job and is not optional: without it graph's four durable planning
artifacts would today be **12.0 MB / ~3.0M tokens** instead of **470 KB / ~117k tokens**. The
recurrence people notice — nineteen passes over four files in sixty-six days — is not a failure
of the process, it is the process working against a tank that refills every sprint.

The defects are in the *residue*, not the *reduction*, and both belong to core rather than to
graph:

1. The step writes its working files into the durable area and **never says to remove them**.
   33 of the 96 files in `_bmad-output/planning-artifacts/` — **1.80 MB, 13.7% of that
   directory** — are consolidation byproduct. The four live artifacts the process exists to
   protect are 383 KB, **2.9%**.
2. Core's step prescribes **area-root paths** for files that are per-sprint work products, at a
   point in time when the path grammar item 10 shipped already provides an `s<N>/` slot for
   exactly this. The step names no slot.

And the methodology question has an answer that graph already found on its own: the durable
artifacts refill because **every sprint writes its own output into them**. Contain that and
consolidation stops being periodic.

---

## Three different things are called "consolidation"

They have different owners, different costs and different verdicts, and the plan's item 19 text
runs two of them together.

| | what it is | owner | cadence | verdict |
|---|---|---|---|---|
| **A** | *current-state consolidation* — drain a durable artifact into a write-only `-history.md` sink | **core**, `steps/artifact-consolidation.md` | 19 passes / 66 days | works; leaves residue |
| **B** | *the artifact-path migration* — every artifact onto the `s<N>/` grammar | **core**, plan item 10/16 | one-time, 3 hops | achieved its claim |
| **C** | *archive-and-reset* — a sprint's whole planning corpus into `s<N>/archive/` | **graph's own** | s300, s301 | the one worth generalising |

---

## A — current-state consolidation

### What graph actually did

17 commits between 2026-05-31 and 2026-08-05. Subject-matched per artifact (`git log
--full-history`, so squash-pruned history cannot hide a pass):

```
prd.md                   7 passes
product-brief.md         5
carry-over-backlog.md    4
docs/architecture.md     3
```

Each pass moves superseded content from the live file into a companion sink. Line counts at each
pass, `BEFORE` = the blob at `<commit>^`:

```
FILE                   DATE        BEFORE   AFTER     CUT
prd.md                 2026-05-31   12311    3747    8564
prd.md                 2026-06-05    3884    3432     452
prd.md                 2026-06-24    2673    1778     895
prd.md                 2026-06-26    2222    1943     279
prd.md                 2026-07-18    2466    1787     679
prd.md                 2026-07-28    3422    2944     478
prd.md                 2026-08-02    2781    2165     616
prd.md                 2026-08-05    1797    1383     414
prd.md                 HEAD                  1530

product-brief.md       2026-05-31   10213     859    9354
product-brief.md       2026-06-24    1437     564     873
product-brief.md       2026-07-18    2407    2058     349
product-brief.md       2026-07-27    2828    2083     745
product-brief.md       2026-07-28    2083    1954     129
product-brief.md       2026-08-02    1886     360    1526
product-brief.md       HEAD                  1030

carry-over-backlog.md  2026-05-31    9985    5112    4873
carry-over-backlog.md  2026-06-05    5192    3329    1863
carry-over-backlog.md  2026-08-02    1212    1215      -3
carry-over-backlog.md  HEAD                  1647

architecture.md        2026-07-09   21018     443   20575
architecture.md        2026-08-02    1522    1142     380
architecture.md        2026-08-05    1972     717    1255
architecture.md        HEAD                   759
```

Read the gaps between an `AFTER` and the next `BEFORE`: `product-brief.md` was cut to 564 on
06-24 and stood at 2407 by 07-18. `prd.md` was cut to 1787 on 07-18 and stood at 3422 by 07-28.
`architecture.md` was cut to 443 on 07-09 and stood at 1522 by 08-02.

### Finding A1 — consolidation is load-bearing. The counterfactual, stated.

The plan asked for the do-nothing side and it is derivable: the sink files *are* the content that
would otherwise still be live, because the step's history draft is built from lines removed from
live (`core/skills/ai-dlc/steps/artifact-consolidation.md:56`).

```
                        live today      sink        never-consolidated
prd.md                     130,477   3,838,553           3,969,030 B
product-brief.md            82,728   3,276,264           3,358,992 B
carry-over-backlog.md      170,219   2,266,491           2,436,710 B
docs/architecture.md        86,098   2,186,842           2,272,940 B
                        ----------  ----------          ------------
                           469,522  11,568,150          12,037,672 B
```

At core's own `bytes/4` divisor that is **~117k tokens live against ~3.0M never-consolidated** —
a 96.1% reduction. A single one of those files would exceed any context window. **The question
"was consolidation worth it" is settled and does not need re-asking.**

*Caveat, stated rather than buried:* this is an upper bound on the counterfactual. It assumes
every byte now in a sink would have been authored identically into a live file. Some of it —
particularly the per-sprint changelog prose — would plausibly not have been written at all in a
world where the artifact was visibly unmanageable. The direction is not in doubt; the exact
multiple is.

### Finding A2 — the recurrence is structural, not sloppy

`product-brief.md` went 360 → 1030 lines in the six days after its 08-02 pass. Every heading
added in that window is sprint-scoped:

```
## In-Force LOCKED_REQUIREMENTS Blocks (… 1 in-force LOCKED block: `S299` … `S301` alias …)
### Discovery Findings & Implementation Sequence — S301
## Changelog
### 2026-08-05 — S301 discovery-brief party-mode round 1, remediation pass (Rule 15)
### 2026-08-05 — S301 discovery Section 5, step 2: advanced elicitation
### 2026-08-05 — adversarial pass-1 remediation (`s301-product-brief-adversarial-p1.md`)
### 2026-08-05 — S301 discovery Section 5, step 3: adversarial convergence (lead summary)
```

Five of the seven carry an explicit `S301`/`s301` token; the other two are the container headings
those five live under. **7 of 7 are sprint-scoped content written into a sprint-independent
file.** That is where the refill comes from, and it is prescribed — `discovery.md` and the
adversarial passes write there by design.

So the treadmill is not a quality problem in the consolidation passes. It is the arithmetic of a
tank with a continuous inlet and a periodic drain.

### Finding A3 — the process leaves its working files in the durable area, and core never says to remove them

This is the actionable one.

`artifact-consolidation.md:51` dispatches an analyst to produce **two drafts written to disk**,
plus a manifest (`:41`) and a coverage report (`:62`). Step 6 (`:93`) says *"Replace the live
artifact with the consolidated live draft."* The draft file itself is never mentioned again.

**Control on that absence.** `grep -niE '\b(delete|remove|rm |clean ?up|discard|retire|unlink)\b'`
over the step returns **rc=1, zero matches**. The same regex over sibling step files matches
`_gate-procedures.md`, `deploy-validate.md` and `gate-validation.md`, so it fires on prose that
does prescribe deletion. The zero is a real absence.

What that produces in graph today, in `_bmad-output/planning-artifacts/` (root level only —
depth-filtered with `awk -F/ 'NF==3'`, because a git pathspec `*` matches `/` and the first pass
at this join wrongly returned 1395):

```
33 of 96 root-level files are consolidation byproduct     1,799,699 B   13.7% of the directory
  11 consolidation-draft-*
   7 consolidation-validation-*
   6 consolidation-manifest-*
   4 consolidation-coverage-*
   5 assorted validation-/review- variants
the three live artifacts they exist to protect              383,424 B    2.9%
```

`consolidation-draft-prd-live.md` is 1383 lines against live `prd.md`'s 1530, differing on 155
lines — a stale near-duplicate of the current PRD, sitting in the same directory, with nothing
saying which is authoritative. Eleven such drafts are tracked, the oldest last touched
2026-07-19. Two still carry an `S999` placeholder token.

**They cannot simply be deleted.** `consolidation-coverage-*` and `consolidation-validation-*`
cite the draft paths as their evidence, so deletion breaks the no-loss record the pass produced.
The residue is a *homing* problem, not a garbage problem.

### Finding A4 — the step prescribes area-root paths for per-sprint work products

`artifact-consolidation.md:41` names
`_bmad-output/planning-artifacts/consolidation-manifest-<artifact>.md`. Under the grammar item 10
shipped, the area root is *durable, sprint-independent, never moves* and `s<N>/` holds *every
artifact produced by sprint N*. A manifest for sprint 300's consolidation pass is the second
thing, filed as the first.

**Control on that absence.** `grep -niE 's<N>|sprint slot'` over the step returns **rc=1**. The
same pattern matches `bug-investigation.md`, `architecture.md`, `carry-over-evaluation.md`,
`deploy-validate.md` and `_gate-procedures.md` — five step files that do name the slot.

The consequence is already visible. Both of these are tracked right now:

```
_bmad-output/planning-artifacts/consolidation-manifest-prd.md        304 lines, latest token S297
_bmad-output/planning-artifacts/s300/consolidation-manifest-prd.md   193 lines
```

Same basename, two homes, nothing declaring which is current — **the exact condition item 10 was
opened to eliminate, re-created by a step the migration did not touch.** Eleven basenames now
exist both at the area root and under an `s<N>/` slot; six of the eleven are consolidation
artifacts. (Control: 85 root basenames appear in no slot, so the join is discriminating.)

`validate-artifact-paths.sh` cannot see this and is not wrong not to: both paths conform. A
syntactic grammar cannot tell a durable artifact from a per-sprint one that merely omitted its
sprint. This is the limit the grammar file documents under *What a syntactic check CANNOT catch*,
met in the wild.

### On the sinks — not a finding, and worth saying so

110,591 lines / 11.6 MB now sit in `prd-history.md`, `product-brief-history.md`,
`carry-over-backlog-archive.md` and `architecture-history.md`, and nothing reads them. **That is
deliberate and correct.** `validate-artifact-budget.sh:367-372` declares history and archive files
write-only via `is_archive()` and excludes them from measurement, with the reason stated at `:62`.
Their growth is free because no session loads them. I looked for a duplication problem inside them
and did not establish one: `product-brief-history.md` has 1687 headings and 824 distinct, but
repeated heading *text* across sprints with different bodies is expected, and I did not derive a
content-level duplicate measure. **Unmeasured, stated as unmeasured.**

---

## B — the artifact-path migration

Re-derived by running core's own validator read-only against the consumer:

```
tracked 9943, under the scan roots 5152
  conforming        5054
  AMBIGUOUS           72   path names more than one sprint
  NO-AREA              3   sprint dir under a scan root that is not an area
  STORY-NO-SPRINT     23   of 1024 story files, no derivable sprint
VERDICT: PASS — no MIGRATABLE non-conforming path
```

**It achieved what it claimed.** Zero migratable non-conforming paths remain, on a corpus the
validator proves non-empty in the same run.

**One plan figure is stale and item 19's own text repeats it.** The plan says *"The 48 refusals
are still owed and unresolved"*. The owed set today is **98 files — 72 + 3 + 23** — and it was
already 72/3/23 at v0.308.0, where the plan itself records the migration and the validator
agreeing exactly on those three numbers. The 48 (45 AMBIGUOUS + 3 NO-AREA) was the *first*
migration's refusal count over a pre-story-corpus subject set. Anyone scheduling the refusal
cleanup should size it at 98, not 48.

The cost side is on the record and I did not re-derive it: three hops, four consumer PRs, seven
core releases (v0.298.0–v0.308.0), 2667 + 951 moves verified per file.

---

## C — archive-and-reset, which graph invented

s300 closed *"by archive-and-reset, not by disposition"* (`7ecd99dd1`) and s301 *"by abandonment,
not completion"* (`bfb58e0d9`). Both moved the sprint's entire planning corpus into per-cycle
directories under the sprint's own slot:

```
_bmad-output/planning-artifacts/s300/archive/{cycle-1,discovery-adversarial-cycle-1,
                                              prd-adversarial-cycle-1, …}
_bmad-output/planning-artifacts/s301/archive/{cycle-1,carry-over-evaluation,epics, …}
195 files across 15 such directories
```

This is the only one of the three that **prevents** accumulation rather than draining it, and it
is the only one graph built itself. It works because the sprint slot is the natural container for
sprint-scoped output — which is precisely the resource core's consolidation step does not use.

It is also incomplete as practised: s301 was archived wholesale and `product-brief.md` still grew
670 lines during it, because the discovery step writes LOCKED blocks and changelog entries into
the durable artifact directly.

---

## Recommendation

Stated last, deliberately, and none of it is authorised by item 19.

**Do not change the reduction.** Findings A1 and A2 say the passes are doing necessary work at a
cadence set by sprint throughput. Nothing here argues for consolidating less often.

**The two residue defects are small, core-side, and independently shippable.**

1. Give `artifact-consolidation.md` a sprint slot for its outputs — manifest, coverage,
   validation, both drafts under `_bmad-output/planning-artifacts/s<N>/`. This removes the
   stale-near-duplicate class and the two-homes-one-basename class in one edit, and it needs no
   deletion, so the no-loss citations keep resolving. Before shipping, derive what the existing
   33 root files should become: they belong to sprints S243 through S301 and several carry no
   recoverable sprint at all (two say `S999`), so a mechanical re-home has a refusal set that
   must be measured, not assumed.
2. Decide explicitly whether the drafts are retired at Step 6 or retained as evidence. Today the
   step does neither, which is how eleven of them accumulated. Either answer is defensible; the
   silence is not.

**The methodology question has one real answer, and it is larger than either fix.** The durable
artifacts refill because sprint-scoped content is written into them (A2). If a sprint's LOCKED
block and changelog lived in `s<N>/` with the durable artifact carrying current state and a
pointer, the inlet closes and consolidation degenerates from a nineteen-pass recurring cost into
a rare genuine refactor. Graph has already proven the containment half of this in C.

**That change is not small and I have not sized it.** `LOCKED_REQUIREMENTS` is read by four core
validators and ten step files. One encouraging datum: `validate-locked-anchor.sh:129` already
carries `DEFAULT_SOR_BASENAME = "product-brief.md"` behind an overridable `--sor`, so the
source-of-record is parameterised at that layer rather than hard-wired. Whether the other
thirteen sites are equally movable is **underived**, and deriving it is the prerequisite to
proposing anything.

---

## What this review did NOT establish

- **Content-level duplication inside the history sinks.** Heading repetition was measured;
  duplicated prose was not.
- **The wall-clock or token cost of a single consolidation pass.** Commits, byproduct file counts
  and byproduct bytes are proxies. The sprint records show consolidation consuming story slots
  (s286 carried it as a LOCKED P2 story) and stalling a pipeline at Step 6 (s299), but I did not
  reconstruct session cost.
- **Whether the 98 owed path refusals matter.** They are named and non-blocking. Nobody has
  argued they should be resolved rather than left.
- **The true counterfactual for content that would never have been written.** See A1's caveat.
