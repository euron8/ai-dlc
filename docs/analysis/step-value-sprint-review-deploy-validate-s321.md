# Step value — sprint-review and deploy-validate, s321 (BL-812 item 1)

Measured for batch b256 on graph sprint 321, read only. BL-812 item 1 owes step-value evidence
for each step whose cost did not fall, and records two such steps on s321: sprint-review (subagent
$1.93 to $8.25 per story on the label `sprint-review` alone, as recorded; counting
`gate-validation[sprint-review]` in as well, as this document's step population does, s319 is $4.95
and s321 $8.36, see Cost) and deploy-validate ($0.56 to $4.01, label `deploy-validate`, which has no
gate label in either sprint). This document applies the method of
`step-value-s317-s319.md` (REFOUND, MISSED-BY-PRIOR, REPAIR-INTRODUCED, UNIQUE-SURVIVED, and the
high-consequence guard) to both steps, as `step-value-stories-elicitation-s321.md` did for
stories elicitation. `pipeline-efficiency-s317-s322/scripts/sr_dv_yield.py` produces every count
and dollar figure below. The per-finding classes are manual readings and are listed in full.

Graph paths are relative to the graph repo. Refs: `da6cadadd` (the graph HEAD b255 pinned),
`dfca19e76` (sprint-review Step 0, the merge of #1285 into the sprint branch: the tree the review
read), `ed49ace11` (the sprint branch at merge time), `fb6f198e7` (the Sprint 321 squash on `main`,
#1303: the shipped artifact for sprint-review), and the four deploy-validate fix-forward squashes
`01dde7133` (#1304), `2625acc45` (#1305), `c5ddf2d4d` (#1306) and `4840808e7` (#1307).

## Method, as applied

Population: every `## F-n (major)` or `(critical)` heading in a sprint-review seat file
(`_bmad-output/party-mode/s321/sprint-review-<role>-<NN|cross>.md`, 130 files), plus the one
finding of the adversary one-shot (`_bmad-output/implementation-artifacts/s321/sprint-review-adversarial.md`,
graded MAJOR by its author). There are 0 CRITICAL headings. MINOR is not classified (186 rows; the
lead's triage file dispositions them). For deploy-validate the population is every defect a
fix-forward PR repaired. Each finding takes the first class that applies.

1. **REFOUND.** Another seat of the same round raised the same defect (same code path, same failure
   mode), or an earlier step raised it. An earlier raise whose closure did not reach the code is
   marked **REFOUND (open)**. Neither kind is counted as a unique survivor.
2. **REPAIR-INTRODUCED.** The finding sits in text that a repair, fold or merge wrote. Here that
   means the sprint-review Step 0 merge of #1285.
3. **UNIQUE-SURVIVED.** The finding's fix commit is identified from the batch dev report that cites
   it, and that commit's added lines are present in the shipped tree. The script measures this per
   commit: the share of added lines of 12 or more characters present at `fb6f198e7` and at
   `da6cadadd`. Every fix scores 90.9% to 100% at ship.
4. **ACCEPTED.** The lead filed the finding to a carry-over as accepted or as an operator decision,
   with no code fix. It is not a survivor.
5. **UNIQUE-unverified.** The finding is not REFOUND, but its disposition is a carry-over note
   (story 5.6 is deferred and its text is LOCKED) or no disposition record names it. It is not a
   survivor.

The first round's catches are unique by construction (`step-value-s317-s319.md`), and sprint-review
is not a first round. Every one of its findings sits in code or documents that the story gates
had already passed, so each is MISSED-BY-PRIOR against those gates. The column that tests
sprint-review is therefore whether an earlier step had already raised the defect.

**Two levels are reported**, because the method's REFOUND rule marks every member of a group that
several seats raised:

- **Per finding (the method).** A defect that several seats raised scores REFOUND for each of them.
- **Per step (distinct defect).** Duplicates inside the step collapse to one defect. A defect is
  step-unique when no earlier step raised it, it was fixed, and the fix survived.

The step-value question ("findings no other round catches that survive to the shipped artifact") is
the per-step level. The per-finding level is printed beside it so that it can be compared with the
elicitation study.

## Inputs

| Input | Graph source |
|---|---|
| Spawns and dollars | `spawns.jsonl` from `extract.py`, `spawns.py` and `analyze.py` with `EXTRACT_WIN_END=2026-11-09T00:00:00Z`, the b255 invocation (see Commands) |
| Seat findings | `_bmad-output/party-mode/s321/sprint-review-*.md` at `da6cadadd` (130 seat files; `.bak` excluded) |
| Adversary | `_bmad-output/implementation-artifacts/s321/sprint-review-adversarial.md` |
| Dispositions | batch dev reports `sr-{pool,probe,docs,web,tests,claude,leftovers,envleak,minors}-dev-report.md` and `sprint-review-minors-triage.md` (implementation-artifacts/s321, at `ed49ace11`); carry-overs added by `3e57cbb77`, `163433fa6` and `5cd2facfe`; the sprint-review gate verdict `gate-adjudication/sprint-review-20261107T141957Z.*` |
| Earlier raises | `docs/reviews/s321/` and the planning shards at `dfca19e76` (sprint-review) and `fb6f198e7` (deploy-validate) |
| Shipped | `fb6f198e7` for sprint-review fixes; `da6cadadd` for the fix-forwards, which land after the sprint squash |

Order, 2026-11-07 UTC, from spawn start times: the adversary one-shot ran at 11:45, the 130 party
seats at 12:13–12:19, the fix batches at 12:46–14:01, the gate adjudicators at 14:20, and the sprint
squash merged at 14:58. Deploy-validate ran from 15:13 on 11-07 to 18:25 on 11-08.

## Cost

### The s319 baseline is mis-split between two step labels

Labels: **`sprint-review`** is the recorded step label; **`gate-validation[sprint-review]`** is the
gate span label the extractor gives the sprint-review gate's reads. Every figure below says which of
the two it counts: "sprint-review only" is the first label alone, "sprint-review + gate" is both.
Recorded $1.93 per story is the first label alone; with both labels s319 is $4.95 (the recorded
figure stays beside it, uncorrected, in the table).

BL-812's s319 sprint-review figure ($1.93 per story, 73 spawns) does not cover the whole s319
sprint-review. The s319 extraction charged 75 spawns ($60.49) to `gate-validation[sprint-review]`:
the per-story seats for stories 01 to 08, all 30 cross seats, the adversary one-shot and the 4
gate adjudicators. In s321 that label holds only the 4 adjudicators. Like for like, step plus its
gate, the two sprints compare as follows.

| Sprint | Spawns | $ | Per story | Source |
|---|---|---|---|---|
| s319 sprint-review only (label `sprint-review`) | 73 | $38.50 | 3.65, $1.93 | BL-812 figure, re-derived: MATCH |
| s319 sprint-review + gate (`sprint-review` + `gate-validation[sprint-review]` 75 / $60.49) | 148 | $98.99 | 7.40, $4.95 | baseline correction: $1.93 recorded, $4.95 with both labels |
| s321 sprint-review only (label `sprint-review`) | 165 | $206.31 | 6.60, $8.25 | BL-812 figure, re-derived: MATCH |
| s321 sprint-review + gate (`sprint-review` + `gate-validation[sprint-review]` 4 / $2.78) | 169 | $209.09 | 6.76, $8.36 | |

So the like-for-like rise is $3.41 per story ($110.10 in total), not $6.32.

### Where the $110.10 went (labels `sprint-review` + `gate-validation[sprint-review]`)

| Phase | s319 spawns / $ | s321 spawns / $ | Δ $ |
|---|---|---|---|
| party seats, per-story | 100 / $51.57 | 125 / $144.06 | +$92.49 |
| party seats, cross | 30 / $35.08 | 5 / $10.84 | −$24.24 |
| consolidation, triage, round dispatcher | 1 / $0.71 | 2 / $6.95 | +$6.24 |
| adversary one-shot | 1 / $4.67 | 1 / $1.98 | −$2.69 |
| fixes, with their review and QA | 12 / $5.14 | 32 / $42.48 | +$37.34 |
| gate adjudicators | 4 / $1.83 | 4 / $2.78 | +$0.95 |
| **total** | **148 / $98.99** | **169 / $209.09** | **+$110.10** |

Both sprints ran 130 seats. s319 had 100 per-story and 30 cross seats; s321 had 125 per-story
and 5 cross, so the one-cross-seat-per-role change of 0.952.0 landed. Seat dollars by (role, model
ran), per-story and cross together, over both labels:

| Role | s319 | s321 | Δ |
|---|---|---|---|
| architect | opus, 26, $56.39 | opus, 26, $71.35 | +$14.96 |
| dev | **haiku**, 26, $1.63 | **sonnet**, 26, $24.13 | +$22.50 |
| qa | **haiku**, 26, $1.88 | **sonnet**, 26, $19.66 | +$17.78 |
| pm | sonnet, 26, $11.02 | sonnet, 26, $17.00 | +$5.98 |
| tea | sonnet, 26, $15.73 | sonnet, 26, $22.76 | +$7.03 |

The dev and qa seats were bound to sonnet in s321 (`model_bound` sonnet, 33 and 37 spawns in the
step) and to haiku in s319 (29 and 30). That binding alone adds $40.28, and fix volume adds $37.34.
Together they are 71% of the rise.

### deploy-validate

| Phase (s321) | Spawns | $ | Agent-min |
|---|---|---|---|
| ops verification (smoke, 3b, Step 4, reads) | 14 | $36.25 | 146.6 |
| ops rollout action (Base DB and secret, EFS config, config PUT, restart, PoolSwapTest deploy, router-enable PUT) | 7 | $12.55 | 49.0 |
| ops diagnosis and watch | 8 | $22.74 | 100.5 |
| fix-forward dev, code review and QA | 16 | $28.63 | 174.0 |
| **total** | **45** | **$100.18** | per story 1.80, $4.01: BL-812 figure, MATCH |

One of the 45 is a double count. `agent-a422ac9aa8d949aab` ("Read-only watch of Base create",
$2.56) appears in two lead transcripts (sessions `4f12d1d9` and `df56108b`). Deduplicated, the
step is 44 spawns and $97.62. s319's step ran 9 spawns and $11.11.

## Yield: sprint-review (35 C/M findings)

Fix batch key: `pool` = 4b1fd2a65 + 6df2ae912, `probe` = 323c7b18e, `docs` = a723c175a + 1c6433d94,
`web` = 4a58923c0, `tests` = 0d83871e3, `1.1-ff` = 36bf72950. The defect ids D1–D22 are this
document's own. The Class column is the per-finding level: a defect that two or more seats raised
is REFOUND on every row. The per-step level is in the summary.

| Finding | Defect | Class | Disposition / survival | Consequence |
|---|---|---|---|---|
| architect-02#F-1 | D1 requested `pool_id` not instance-scoped; manual rebalance reaches `engine.execute` on the other chain's pool | REFOUND (open): 1.2 code review raised it (`1.2-code-review.md:215`, disposition L, to Story 1.6), and 1.6 closed one handler | pool, 100% | **high**: LR-S321-1 isolation on a capital path |
| architect-06#F-1 | D1 | REFOUND | pool | |
| architect-cross#F-1 | D1 | REFOUND | pool | |
| dev-03#F-1 | D1 | REFOUND | pool | |
| dev-cross#F-1 | D1 | REFOUND | pool | |
| pm-02#F-1 | D1 | REFOUND | pool | |
| architect-10#F-1 | D2 Base inherits Polygon `offramp_hodl` defaults (`enabled: True`, Polygon token addresses): an armed HODL sweep on Base | UNIQUE-SURVIVED | pool, 100% | **high**: capital path once Base is enabled |
| architect-13#F-1 | D3 `REBALANCER_URL` means a probe URL in two scripts and a Cloud Map host in a third | ACCEPTED (carry-over item 2) | none | medium |
| architect-20#F-1 | D4 the operator runbook `s317-base-enable.md` targets the Matic instance, appends a duplicate pool and overwrites the 0.1 gwei ceiling | REFOUND (by architect-22; step-unique as D4) | docs, 92.3% | **high**: operator procedure on the live config path |
| architect-22#F-1 | D4 (the runbook contradicts the AD-4 routing rule) | REFOUND | docs | |
| architect-23#F-1 | D5a 5.6 hold close signal omits AC5, and its clock starts at the wrong event | UNIQUE-unverified: a carry-over entry (docs Item 3); story 5.6 is deferred and LOCKED | not in shipped story text | low |
| architect-23#F-2 | D5b AC1 precondition names per-story merge shas, which squash never puts on `main` | UNIQUE-unverified (same carry-over) | not in shipped story text | medium |
| architect-23#F-3 | D5c AC3 accepts `relation "execution_log" does not exist` as a pass | UNIQUE-unverified (same carry-over) | not in shipped story text | medium |
| architect-cross#F-2 | D6 seven S321 deploy-safety and routing test files are not registered in `ci-local.sh` | UNIQUE-SURVIVED | tests Item 1, 99.5% | medium |
| qa-05#F-1 | D7 the `db_required` independence proof (LR-S321-1/4) is skipped on every pre-push | REFOUND | tests Item 2 | |
| tea-05#F-1 | D7 | REFOUND | tests Item 2 | |
| tea-cross#F-1 | D7 | REFOUND | tests Item 2, 99.5% | medium |
| dev-16#F-1 | D8 `_probe_base_instance` misses `http.client.HTTPException`: a truncated Base reply aborts every cycle, including all 30 Matic rules and the Matic dead-man | REFOUND | probe, 100% | **high**: blinds live-Matic monitoring |
| qa-16#F-1 | D8 | REFOUND | probe | |
| dev-07#F-1 | D9 five signed `value` senders are not compared with the reserve cap | ACCEPTED (operator decision, carry-over item 3; unreachable while Base is disabled) | none | high if reached; not fixed |
| dev-23#F-1 | D10 story 5.6 Strategy Test ID rows are blank (Check 21) | UNIQUE-SURVIVED | docs Item 2 | low |
| dev-24#F-1 | D11a `base-state-report.md` rows 1 and 2 rest on substring counts, not a Base assertion | REFOUND | docs Item 4 | |
| tea-24#F-1 | D11a | REFOUND | docs Item 4 | low |
| qa-24#F-1 | D11b rows 18 and 20 are "built and tested" on one subscribe-signing test | UNIQUE-SURVIVED | docs Item 4 | low |
| tea-01#F-1 | D12 the Matic replay is circular for 11 of 12 ticks | ACCEPTED (carry-over item 1) | none | medium |
| tea-02#F-1 | D13 the AC4 zero-sign assertion is non-discriminating (the control's counter is 0 too) | UNIQUE-SURVIVED | tests Item 4 | medium |
| tea-04#F-1 | D14 a shallow-copy safeguard mutant survives both AC5 tests | UNIQUE-SURVIVED | tests Item 6 | medium |
| tea-07#F-1 | D15 the native-reserve audit is frozen pre-sprint and says `no` where 2.3 and 2.4 bounded the rows | UNIQUE-SURVIVED | docs Item 5 | medium (operator decision input) |
| tea-13#F-1 | D16 D2 and the reader arm encode the live `absent: true` state and go red on the planned 5.6 flip | UNIQUE-SURVIVED | tests Item 3 | low |
| tea-17#F-1 | D17 page-to-module `apiSegment` hand-off is untested through `RebalancerPage` | UNIQUE-SURVIVED | web F-1, 100% | medium |
| tea-17#F-2 | D18 1 of 21 mutating request sites is prefix-tested; no source-level guard | UNIQUE-SURVIVED | web F-2 | medium (guards a future Base-to-Matic misroute) |
| tea-21#F-1 | D19 three deploy-staging guards can be deleted with 44/44 green | UNIQUE-SURVIVED | tests Item 5 | medium |
| tea-23#F-2 | D20 5.6 AC2 predicate admits `trigger="integrity_correction"` rows | UNIQUE-unverified: no disposition record names it; graph s322 `prd.md` D-2 takes up the same question | none in s321 | medium |
| tea-cross#F-2 | D21 LR-S321-10 is proven for the decision layer only, with no Matic execution-layer byte control | UNIQUE-unverified: no disposition record names it | none | medium |
| adversary F-1 | D22 the Matic replay is red on the composed tree (15 of 22) because the golden pins the shape #1285 removed | REPAIR-INTRODUCED: written by sprint-review's own Step 0 merge | 1.1-ff, 100% | medium: production correct, gating suite red |

"No disposition record names it" (D20, D21) is a search of the dev reports, the minors triage,
the carry-over backlog at `ed49ace11`, and `git grep -F 'tea-23#F-2'` / `'tea-cross#F-2'` over
graph `_bmad-output` and `docs` at `ed49ace11` and `da6cadadd`. All return 0. The same invocation
finds the cited form `tea-13#F-1` in `sr-tests-dev-report.md`. The lead's `findings.tsv`, which the
triage file names as its source, is not committed, so a disposition recorded only there cannot be
seen.

### Summary, sprint-review

| Level | C/M | REFOUND | REPAIR-INTRODUCED | ACCEPTED | UNIQUE-unverified | UNIQUE-SURVIVED | $ (`sprint-review` + `gate-validation[sprint-review]`) | $ per survivor |
|---|---|---|---|---|---|---|---|---|
| per finding | 35 | 15 | 1 | 3 | 5 | **11** | $209.09 | **$19.01** |
| per step, distinct defects | 22 | 1 (D1, open) | 1 (D22) | 3 | 5 | **15** | $209.09 | **$13.94** |
| per step, D1 residue counted | 22 | 0 | 1 | 3 | 5 | **16** | $209.09 | $13.07 |

High-consequence, step-unique and survived: **D2, D4 and D8**, at $209.09 / 3 = **$69.70 each**.
D1 is a fourth, counted as REFOUND (open). Story 1.2's gate raised it and handed it to 1.6, 1.6's
gates passed a one-handler closure, and only sprint-review found the residue. Without the step the
residue would have shipped.

By phase, per step (every dollar figure in this paragraph is over both labels, as the phase split
is): the per-story seats ($144.06) made 14 of the 15 step-unique survivors ($10.29
each) and all three high-consequence ones. The cross seats ($10.84) made one alone (D6) and shared
D7. The adversary ($1.98) made no step-unique survivor; its one finding, D22, is REPAIR-INTRODUCED,
and fixing it is what made the gating suite green. The pm seats ($17.00) made no step-unique
survivor: pm-02#F-1 is D1. The sonnet dev and qa seats ($43.79) made three step-unique survivors no
other role raised (D8, D10, D11b), including high-consequence D8, which was raised by dev-16 and
qa-16 and by no other seat.

Missed by sprint-review: three of deploy-validate's four defects (below) are visible in the code
(#1305's invariant, #1306's router encoding, #1307's estimate payload), and none of the 130 seats,
the adversary or the minors triage names them. All eight defect tokens read 0 there, against a
positive control of 32 (`_resolve_request_pool`) in the same corpus and an impossible token of 0.

## Yield: deploy-validate (4 fix-forward defects)

| Defect | Found by | Class | Survival (added lines at `fb6f198e7` / `da6cadadd`) | Consequence |
|---|---|---|---|---|
| #1304 live smoke iOS portrait nav tests expect 3 `shell-nav-btn`, but Story 4.3 made 4 | live smoke | UNIQUE-SURVIVED | 0.0% / 100% | low (test only) |
| #1305 the first Base config save is refused: invariant (iii), "at least one pool enabled", rejects every PUT to the staged all-disabled Base instance | ops triage of "Base config save reverting" | **REFOUND (open)**: architecture elicitation raised it as MAJOR (`planning-artifacts/s321/shards/architecture-elicitation/1.md` F-1, with the 400 reproduced) and its repair was marked `repaired` in the architecture text (`architecture-elicitation-repair-p1.md`), while the validator code was unchanged until #1305 | 2.4% / 100% | blocks delivery: the Base instance could not be configured. Fails closed |
| #1306 Base same-pool swaps need the refunding `PoolSwapTest` encoding (`swap_router_kind`): the absent key keeps `SwapRouterNoChecks`, and the fix states that PoolSwapTest "refunds leftover native ETH to msg.sender" | ops derivation of the Base swap router | UNIQUE-SURVIVED | 6.4% / 100% | **high**: native value on a capital path. The consequence is read from the fix's commit text and the ops pre-enable simulation (a 1e12 wei refund in the trace), not from a trace of the old router |
| #1307 off-Matic `eth_estimateGas` payloads carry `gas: 0`, so every Base create, rebalance and compound estimate fails ("gas allowance 0") | the live Base create press | UNIQUE-SURVIVED | 0.3% / 100% | blocks delivery: no Base position could be created. Fails closed |

The survival column is also the discriminating control for the survival measure. Each fix is
absent from the sprint squash and present after it. The sprint-review fixes score 90.9% to 100% at
the squash itself.

A prior raise of #1306 or #1307 was searched with a token sweep of `docs/reviews/s321`,
`party-mode/s321` and `planning-artifacts/s321` at `fb6f198e7`. These tokens read 0: `gas
allowance`, `gas field`, `"gas": 0`, `zero gas` (except one unrelated reserve sentence), `excess
native` and `not refund`. Broader tokens have hits that were NOT read for a raise: `estimateGas`
(18) and `refund` (39). So for these two, step-unique holds against sprint-review (measured) and
against the earlier steps only as far as that token sweep reaches.

### Summary, deploy-validate

| Reading | Defects | Step-unique survived | High consequence | $ | $ per survivor |
|---|---|---|---|---|---|
| whole step, recorded | 4 | **3** (#1304, #1306, #1307) | 1 (#1306), plus 2 delivery blockers (#1305, #1307) | $100.18 | **$33.39** |
| whole step, duplicate removed | 4 | 3 | as above | $97.62 | $32.54 |
| diagnosis + fix-forward phases only | 4 | 3 | as above | $51.37 | $17.12 |

The other $48.80 (verification $36.25 and rollout $12.55) is the step doing its deployment job, not
reviewing. In s321 that job included the Base instance going live: database, EFS config, stacks, the
PoolSwapTest deploy, the router-enable PUT, and the two operator-pressed creates verified SUCCESS on
chain (`52fc9e600`: "Operator-pressed Base L1 and L2 creates verified (execution_log SUCCESS,
on-chain txs 0x1, both positions subscribed) ... LR-S321-1 HARD_BLOCK resolved"). s319's
deploy-validate deployed no new chain.

## What the rise bought

- **sprint-review (+$110.10 like for like over both labels, +$3.41 per story).**
  - $37.34 is fix work: 17 distinct defects fixed and shipped (15 step-unique) and 54 trivial minors
    applied, against 12 fix spawns in s319.
  - $40.28 is the dev and qa seats moving from haiku to sonnet. Those seats produced three
    step-unique survivors that no other role raised, among them high-consequence D8.
  - −$24.24 is the cross collapse (30 seats to 5). The 5 remaining cross seats still produced D6
    alone.
  - Whether haiku dev and qa seats would have made D8 cannot be measured from this corpus: no sprint
    ran both bindings on the same tree. s319's haiku dev and qa seats raised 38 of that sprint's 51
    C/M (qa 29, dev 9), unclassified.
- **deploy-validate (+$89.07).** A new chain went live, and 4 defects that every earlier step
  passed were caught and fixed live: one capital-path defect and two that would have left Base
  unable to configure or to create a position. 16 spawns ($28.63) were fix-forward work, against 6
  ($1.63) in s319.

## Reading under "A step with no measured value goes" (for the records; no step file is changed)

| Step | Named failure case it prevented in s321 | Step-unique survivors, high consequence | $ per survivor | Reading |
|---|---|---|---|---|
| sprint-review (both labels, $209.09) | cross-story seams no story gate owns: a hand-off closed at one call site (D1), Polygon defaults inherited by the new instance (D2), a new Base call path whose exception silences every Matic rule (D8), an operator runbook no story owns (D4) | 15; D2, D4, D8 (D1 as REFOUND open) | $13.94 ($19.01 per finding) | **KEEP.** Narrowing candidates, recorded and not ruled: the pm seats ($17.00) made 0 of 15, and this is one sprint, so the zero is not decisive; the adversary one-shot ($1.98) made 0 step-unique, but its one REPAIR-INTRODUCED catch kept a red gating suite from shipping, at the lowest cost in the step. Removing either is not supported by one sprint |
| deploy-validate | defects reachable only live, or raised earlier and closed in prose only: a refused first save (#1305), a non-refunding router encoding (#1306), a zero gas allowance (#1307) | 3; #1306 (plus 2 delivery blockers) | $33.39 whole step; $17.12 on its catch-and-repair phases | **KEEP.** No narrowing candidate was measured. The $2.56 double count is an extractor artifact, not a step cost |

Both steps carry step-value evidence on s321. Neither is a remove candidate: each made
high-consequence catches that no other step made and whose fixes shipped.

## Commands

Graph is READ ONLY. Every graph read below is `git show`, `git ls-tree`, `git diff` or `git grep` of
committed objects. The scratch clone and the live repo give byte-identical script output (`cmp -s`).

```
G=$(mktemp -d)/graph; git clone -q --no-hardlinks file:///Users/n8/git/graph $G
git -C $G fetch -q file:///Users/n8/git/graph '+refs/remotes/origin/*:refs/remotes/src/*'   # da6cadadd is on a remote-tracking ref only
OUT=$(mktemp -d); export EXTRACT_WIN_END=2026-11-09T00:00:00Z
A=docs/analysis/pipeline-efficiency-s317-s318/scripts; B=docs/analysis/pipeline-efficiency-s317-s320/scripts
python3 -I $B/extract.py $OUT && python3 -I $A/spawns.py $OUT && python3 -I $A/analyze.py $OUT
python3 -I docs/analysis/pipeline-efficiency-s317-s322/scripts/sr_dv_yield.py $OUT $G
```

Controls, same invocations:

- `analyze.py` token control: units==segs 21411048714 on both sides, the b255 figure at this
  window.
- Spawn ledger: graph `_bmad-output/spawn-ledger.jsonl` at `da6cadadd` has md5
  249bf9b2ccc233549e60c6c1fa123e8d (b255's). The working-tree copy now differs because a live s322
  session appends to it, but its s317–s321 rows are byte-equal (5992 rows, same md5 prefix
  `5e3f62315f0a`). Its s322 rows differ (529 against 648), which is the positive control.
- The script's block 1 prints the label set behind every figure (`step labels containing
  sprint-review or deploy-validate`: s319 `sprint-review` 73 / $38.50, `gate-validation[sprint-review]`
  75 / $60.49, `deploy-validate` 9 / $11.11; s321 165 / $206.31, 4 / $2.78, 45 / $100.18), prints the
  s319 recorded-label-alone against both-label figures ($1.93 against $4.95), and counts the
  `gate-validation[deploy-validate]`-style labels as 0.
- The script's block 1 re-derives all four BL-812 per-step figures (s319 and s321 sprint-review
  and deploy-validate): MATCH ×4. The impossible step `NEVER-STEP-ZZQ` reads 0 spawns.
- Block 3: s321 seat files 130, C/M 34, minor 186, against the gate verdict's "130" and the triage
  file's "34 major" and "186 minor": MATCH.
- Block 4: the deploy-validate fixes read 0.0–6.4% at the sprint squash and 100% after it, which is
  the discriminating side. An impossible line reads 0.
- Block 5: the deploy-validate defect tokens read 0 in the sprint-review corpus, with the positive
  control `_resolve_request_pool` at 32 and the impossible token at 0.
- The first trace of the 34 MAJOR ids against the fix reports read NONE for 25 of them. That was
  an empty-corpus path bug: a glob over a directory that did not exist, with a carry-over hit
  making the run look live. It was caught because the cited form `tea-13#F-1` then read 0 where the
  report carries it. The re-run reads the real corpus.

## Not measured

- **s319's sprint-review yield, per finding.** The data is available (130 seat files, 51 C/M,
  consolidation and dispositions committed) but was not classified, so no s319 cost per survivor
  exists to set beside s321's.
- **Whether the haiku-to-sonnet seat binding bought yield.** Not measurable from this corpus: no
  sprint ran both bindings on the same tree.
- **The lead's `findings.tsv`.** Not committed, so a disposition recorded only there cannot be seen.
  It bears on D20 and D21.
- **Prior raises of #1306 and #1307 beyond the token sweep.** 18 `estimateGas` and 39 `refund` hits
  are available and were not read.
- **Per-story normalisation of deploy-validate.** It is not meaningful: the step's cost follows
  deploy events (a new chain), not story count. The figure is reported only because BL-812 records
  it that way.
- **MINOR findings (186).** Not classified, by the method. The triage file classes them: 54
  TRIVIAL-FIX (applied), 46 DUPLICATE, 7 NOISE, 71 REAL-BUT-NOT-SPRINT-SCOPE, 8 NEEDS-DECISION.

## Re-derivation on the fixed extractor (batch 257, BL-1003 item 3)

This document's population counts `gate-validation[sprint-review]` into the step, so BL-1003 lists it
as a suspect reading. It is re-taken at its own window, `EXTRACT_WIN_END=2026-11-09T00:00:00Z`, by
`sr_dv_yield.py` over two extracts that differ only in `extract.py` (e3cb7710f, the parent of
0.1100.0, against the fixed one), driven by
`docs/analysis/pipeline-efficiency-s317-s322/scripts/bl1003_rederive.py`, with output in
`docs/analysis/pipeline-efficiency-s317-s322/out/bl1003_rederive.txt`. Control, same invocation: the
old extract carries the step's 169 spawns and $209.09. The fixed extract's output is byte-identical,
all 79 lines, because 0 of 5498 spawns change owner at this window. The fixed extractor reads
left=1 for s321, and that one LEFT event (2026-11-04T04:48:18Z, from the architecture gate to
`stories-test-strategy`) moves lead-side rows only, none of them in sprint-review or deploy-validate.
Every count, cost and per-survivor figure above stands, and so does BL-1004's pm-seat reading taken
from it. `elicitation_yield.py` is re-taken the same way and is byte-identical, all 7 lines.
