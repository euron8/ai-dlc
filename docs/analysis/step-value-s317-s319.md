# Step value — requirements rounds (BL-569) and the rationale-gap elements (BL-568)

Measured for batch 235 on graph's s317, s318 and s319 artifacts and transcripts, read only. It
applies the operator ruling of 2026-10-16:

- An element with no measured value is removed or merged by the batch, not put to the operator.
- An element is kept only on a named failure case it prevents, plus findings it catches that no other
  round catches and that survive to the shipped artifact.
- Rare high-consequence catches are judged on consequence, not frequency.
- Rankings state hours and dollars.

## Populations and sources

| Figure | Population | Source |
|---|---|---|
| Dollars, agent-hours | every subagent spawn charged to `requirements` (or the named step); s317 and s318 complete, s319 up to 2026-10-16T03:06Z | `pipeline-efficiency-s317-s318/scripts/{extract,analyze,spawns}.py` re-run with an s319 cut at 2026-10-15T18:48Z; 2065 spawns. Control: s317 and s318 requirements adversary rows reproduce the committed snapshot exactly (12 / $44.04, 76 / $187.55) |
| Round wall clock | first dispatch to the joined or merged record, in session only; handoff gaps excluded | graph `pipeline-snapshot-history.md` (s317, s318); for s319 the spawn ledger, `.artifact-writes.jsonl` and file mtimes, because the lead's typed s319 stamps run about an hour ahead of the mtimes |
| Findings | every CRITICAL and MAJOR in every round, read; MINOR not classified | the seat, shard, merged and repair records under graph `_bmad-output/party-mode/s31N/` and `planning-artifacts/s31N/` |
| Shipped artifact | the requirements subject at the commit where the requirements gate passed | s317 graph `bdbfd63e5`, s318 graph `15e9ebad6`, each pinned by hashing the four subject blobs against the hashes the gate log names (control: the next commit that changes the PRD hashes differently). s319 has not shipped |

Definitions used for every round:

- **REFOUND:** a later round raised the same defect.
- **MISSED-BY-PRIOR:** a later round's finding sits in text that existed when an earlier round ran.
- **REPAIR-INTRODUCED:** the finding sits in text that the previous round's repair, or a fold, wrote or
  half-fixed.
- **UNIQUE-SURVIVED:** the finding is not REFOUND and not REPAIR-INTRODUCED, and its fix is present in
  the shipped artifact.

**The first round's catches are unique by construction.** Nothing reviewed the text before it. The
column that tests the party round is therefore the later rounds' MISSED-BY-PRIOR. Whether elicitation
alone would have caught what party caught is **not measurable from this corpus**, because no sprint ran
elicitation without party first.

## BL-569 — requirements: party, elicitation, adversarial

### Cost

| Round (with its repair) | s317 h / $ | s318 h / $ | s319 h / $ (partial) |
|---|---|---|---|
| Party | 1.9 / $25.08 | 1.4 / $70.23 | 1.6 / $57.99 |
| Elicitation | 1.7 / $15.65 | 2.0 / $68.03 | 1.2 / $62.88 |
| Adversarial p1 | 2.2 / $33.06 | ≥1.9 / $88.90 | 0.6 / $42.28 (repair still running) |
| Adversarial p2 | 0.6 / $14.42 + 5 unlabelled shards $9.46 | ≤0.75 / $34.85 | not run |
| Adversarial p3 | — | ≤0.4 / $21.96 | not run |

Hours are lead wall clock. Dollars are API-list-equivalent subagent spend. Authoring and folds
(analyst, pm) are excluded: s317 $9.34, s318 $5.65, s319 $19.14.

### Yield (MAJOR+, distinct after reading)

| Sprint | Round | Shape | C/M | REFOUND | MISSED-BY-PRIOR | REPAIR-INTRODUCED | UNIQUE-SURVIVED C/M |
|---|---|---|---|---|---|---|---|
| s317 | Party | 2 seats | 2/11 | — | — | 0 | **2/10** |
| s317 | Elicitation | 1 voice | 0/6 | 0 | 2 | 3 | **0/3** |
| s317 | Adv p1 | 1 reviewer | 0/3 (first write 0/4, rewritten by the lead) | 0 | 1 | 2 | **0/1** |
| s317 | Adv p2 | 5 shards, run twice | 0/2 | 1 partial | 0 | 2 | **0/0** |
| s318 | Party | 36 seats | 1/27 | 3 | — | 0 | **1/23** |
| s318 | Elicitation | 19 shards | 1/28 | 3 | **16** from party | 10 | **0/16** |
| s318 | Adv p1 | 19 shards | 0/21 | — | 3 | 18 | **0/3** |
| s318 | Adv p2 | 19 shards | 0/5 | — | 0 | 5 | **0/0** |
| s318 | Adv p3 | 19 shards | 0/1 | — | 0 | 1 (deferred; unrepaired at ship, `prd.md:1282`) | **0/0** |
| s319 | Party | 36 seats | 0/81 raw | — | — | — | not yet shipped |
| s319 | Elicitation | 19 shards | 14/72 raw (14 C = 5 defects) | ≈6 | ≥3 (floor: party-time text did not survive) | 48 (44 written by the D-answers fold, 4 by the party repair) | not yet shipped |
| s319 | Adv p1 | 19 shards | 0/27 | 2 | 7 | 17 | not yet shipped |

### Consequence (the guard clause)

High-consequence catches made by exactly one round:

- **Party:**
  - s317: a 25% request rebalancing 100% of a position when chunking is off (CRITICAL).
  - s317: the post-rebalance sweep re-minting the withheld remainder (CRITICAL).
  - s317: the missing-Quoter `ConfigError` either swallowed or raised after the burn.
  - s318: CAP-1 refusing its own main path on a zero token1 balance (CRITICAL).
  - s318: a HODL press taking the two-hop path or the offramp destination.
  - s318: an all-lowercase `hodl_wallet` crash-looping the live rebalancer at load.
  - s318: an unchecked address settable through the PUT path.
  - s318: destination hot reload against ADR-S188-4.
  - s318: three capital-path byte-pin boundaries.
- **Elicitation:**
  - s317: an enabled Base pool quoting its swap against the hard-coded Polygon Quoter after the burn.
    Party raised only the address-input half, at MINOR.
  - s318: a mixed-case address with a bad checksum passing `is_address`.
  - s318: the locked addresses missing from the contract.
  - s318: initial values never reaching the production config.
  - s318: the second `_unsub_session_id` caller orphaning gated markers.
  - s318 (REPAIR-INTRODUCED, so outside the unique count): `contract_allowlist` called "no runtime
    effect" while it has four runtime sites, including the startup self-test that exits the process.
  - s319: off-lock claim signing colliding with an in-flight rebalance's nonce.
  - s319: an empty allowlist failing open.
  - s319: an S3 null halting every rebalance.
  - s319: a $5 Leg-1 floor about 250,000 times the old threshold.
- **Adversarial p1:**
  - None that was not repair-introduced, in any sprint. Its unique catches are citation and
    observability defects.
  - REPAIR-INTRODUCED, high consequence: s317 subscribe broadcast from the burn hash; s318 destination
    rebind placed before the assignment that overwrites it.
- **Adversarial p2 and p3:**
  - None unique. Every finding sits in text the previous repair wrote.
  - REPAIR-INTRODUCED: s317 p2 F1 (`security.wallet_address` and `position_manager_address` must be
    replaced with `pool_id`, or `load_config` raises) is high consequence.

### Verdict

| Round | Failure case stated today | Unique-survived, high consequence | Verdict |
|---|---|---|---|
| Party | none (`requirements.md`, `_gate-procedures.md` "Validation cycle": `Failure caught` 0; control `architecture.md` 1) | yes, both shipped sprints | **Keep.** Write the failure case: capital-path and address defects in first-authored text; s317 C-1/arch C-1, s318 05 F-1 and the HODL-routing set. |
| Elicitation | none | yes, all three sprints | **Keep.** Write the failure case: defects in text party never saw (folds, party repair), and pre-party text party missed (16 in s318). |
| Adversarial p1 | Rule 8: it is the convergence exit Check 24 reads | no unique high-consequence catch | **Keep as the convergence exit.** 18 of 21 (s318) and 17 of 27 (s319) of its MAJORs are repair-introduced, so its cost is the repairs', and BL-508 owns that. |
| Adversarial p2, p3 | Rule 8 | none unique; one high-consequence repair-introduced catch (s317 p2 F1) | **Keep while repairs write defects; BL-508 owns the cost.** Removing them drops the only check on a repair's own text, which is where s317 p2 F1 and s318 p1 cross-5 F-1 were found. |

**Measured, no round is removable on the ruling's terms.** The waste is real and is located
elsewhere. Across all five series read (requirements s317, s318, s319; stories s317, s318), every
pass-2+ MAJOR and between half and six-sevenths of pass-1 MAJORs sit in text a repair or fold wrote.
The removable cost is the repair defect rate, not a round. That is BL-508 (efficiency rank 2), and this
table is its evidence across three sprints, not two.

Merging elicitation into adversarial p1 is not a small release. Elicitation shards carry no `verdict:`
line, and `merge-adversarial-shards.sh --elicitation` writes the merged record with none, so a merged
round would have to change what Check 24 arm K3 reads. It is not contracted here.

## BL-568 — the rationale-gap elements (`pipeline-efficiency-s317-s318.md:577`)

**The analysis list is partly wrong.** 2c and 2d each carry a `Catches:` line, at `architecture.md:191`
and `:219`; the `Catches:` count in `architecture.md` is 4. Those lines predate the analysis. The list
below corrects it.

| Element | Failure case today | Measured catches | Cost | Verdict |
|---|---|---|---|---|
| architecture 2a variant-lock evidence | none; its "fails at gate-validation Check 3" names a check that does not test it (`gate-validation.md` variant-lock tokens 0; control `Check 29` 1) | s317 0, s318 only "N/A" dispositions | 1139 B, plus the `implementation.md:265-272` restatement | **Remove**, with the restatement |
| architecture 2b framework default audit | none | s318: one use, recording an operator ruling the requirements step had already settled; its only follow-up finding was a MINOR | 701 B | **Remove** |
| architecture 2c mitigation proportionality | `Catches:` `:191` | s317 0; s318 one false §2c sentence, which became a MAJOR (p2 F-1) | 1616 B | **Merge** into the adversary's over-engineering focus |
| architecture 2d executable invariant guard | `Catches:` `:219` | s317 a unique MAJOR (p1 S1-F1); s318 guards on 5 ADRs, advisory shipped at `docs/architecture.md:800, 814` | 1702 B | **Keep** |
| stories-test-strategy step 4 party, per story | none | s317 3 C / 94 M and s318 53 M, unique to party and token-verified in shipped text | s317+s318 $262 / 35.8 agent-h | **Keep; write the failure case** |
| stories step 4 party, cross-story | none | s318 HODL funds destination (`sm-cross-1#F-1`), now asserted at `test_s318_1_2_offramp_hodl_sweep.py:223`; no other round raised it | $138 / 22.7 agent-h | **Keep; write the failure case** |
| stories step 4 elicitation, sharded | none | s317 22 shards: about 15 unique, including E-4 (uncapped mint through a raised wallet read); s318 one voice: at most 1 | $84 / 7.2 agent-h | **Keep sharded.** This contradicts BL-509 (rank 3), which measured cost and not yield. |
| stories step 4 adversarial p2, p3 | Rule 8 | s317 10 of 11 and s318 15 of 21 MAJORs repair-introduced | in $317 / 23.7 agent-h | Keep as the convergence exit; BL-508 owns the cost |
| stories 1 readiness reference subsections | `:293` only | readiness s317 1 C / 2 M, repaired | $10.9 | Keep (not separated) |
| stories 5.1a trace | `:633` says its gate leg is disarmed by construction | none | lead-inline | **Merge into 5.1** |
| sprint-review party fan-out (seat × story + seat × cross) | none (`sprint-review.md:87-113`; controls `:47`, `:143`) | s317 D12 (missing post-burn halt, capital path), A11, DC2; s318 C-26 (funds destination), C-06, C-03, C-12; all on graph main by content; 10 of 26 s318 major clusters story-only | $353 / 36.3 agent-h | **Keep; write the failure case.** The over-cap dispatch (s318: 40 rejected) is DEFECT 4 in the analysis, not this verdict |
| Rule 1 (read CLAUDE.md first) | none | 0 citations in graph logs (control Rule 3: 2433) | 333 B, plus the digest copy | **Remove** (reduce to a heading pointer) |
| Rule 5 (follow the routing) | none | every citation is "Rule 5 fast-track", which licenses a skip; its text duplicates Rule 4 | 382 B | **Merge into Rule 4** |
| Rule 6 (walk through everything) | none | 0 citations | 133 B | **Merge into Rule 4** |
| Rule 9 (autonomous gates) | none | 11 citations, all narration; Rule 3 already lists the only pause points | 148 B | **Merge into Rule 3** |
| Rule 10 (production validation checkpoint) | none stated | 21 citations, each a real pause; the only human gate before production | 326 B | **Keep on consequence; write the failure case** |
| Rule 14 (autonomous phasing) | none stated | 20 citations, routine; Rule 10's per-sprint clause depends on it | 484 B | **Keep; write the failure case** |

A merged or removed rule keeps its number as a one-line pointer to the rule that absorbed it. Rules are
cited by number across core and consumer logs, so renumbering would break those citations.

## Contracted releases

Each release has at most six entries and runs as one gate. Each removal or merge lists every inbound
reference found by `git grep` at `origin/main` 952b9319.

**R1 — architecture 2a/2b removed, 2c merged** (≈ 30 min gate)
1. `steps/architecture.md` §2a and §2b deleted. §2c's `Catches:` clause moves into
   `team-roles/adversary.md`'s Rule 26 focus as one sentence, and §2c is deleted. 2d and 2e keep their
   letters.
2. `steps/implementation.md:265-272` "Day-1 Variant-Lock Evidence" deleted. Its "rejected at Gate 2"
   has no arm: the `variant` hits in `team-roles/code-reviewer.md` (`:561`, `:586`) are "invariant",
   and `qa.md` has 0.
3. `scripts/validate-layer-entries.sh:831` and `:2161`: comment examples naming `### 2a.` and `### 2b.`
   are rewritten to 2d and 2e. This is comment-only, but the pole invokes this validator, so time it
   before and after.
4. Fixtures: none pins architecture's 2a or 2b. The two `### 2[ab].` hits in `core/fixtures` are
   `escalation-status-vocabulary/run.sh:662`, a synthetic heading, and `process-rule-pins/run.sh:236,
   247, 545`, which pin `bug-investigation.md`.

**R2 — Rules 1, 5, 6, 9 folded** (≈ 30 min gate)
1. `SKILL.md`: Rule 1 becomes a one-line pointer. Rules 5 and 6 fold into Rule 4, and Rule 9 into
   Rule 3. Each keeps a one-line `### Rule N` pointer.
2. `postcompact-digest.md:33, 74, 81, 102`: the same edits, byte-identical to the SKILL.md copy where an
   invariant binds them.
3. `hooks/ai-dlc-acknowledge.sh:319` "Rule 5:" becomes "Rule 4:".
4. `scripts/sprint-status.sh:358, 871` "Rule 5" comments are checked and re-pointed where they mean the
   routing rule.
5. "Rule 5 fast-track" at `steps/architecture.md:289` and `fixtures/architecture-fast-track/` is renamed
   to "Rule 4 fast-track" in the step and in the fixture's expected text. `reconcile/layer-drift.sh:1539`
   and `fixtures/layer-readopt-gate/seed.sh:473` quote a consumer string and stay as is.
6. `fixtures/layer-anchor-declaration`, `layer-readopt-gate` and `retro-audit-scans` seed their own
   rulebooks with "Rule 1" and "Rule 9" headings, so they are unaffected. Confirm that with their run
   in the gate.

**R3 — failure-case lines for kept elements** (≈ 20 min gate; docs-shaped, no mechanism)
1. `_gate-procedures.md` "Validation cycle" item 1 (party), item 2 (elicitation) and item 3
   (adversarial): one `Failure caught:` line each, citing this document's catches. This is the BL-569
   receipt. Confirm with the BL-536 owner that lines 235–484 are not frozen.
2. `sprint-review.md:87-113`: the party round's failure case (s317 D12, s318 C-26).
3. `stories-test-strategy.md` step 4: party per story, cross-story and sharded elicitation, each with
   its catch.
4. `SKILL.md` Rules 10 and 14: one failure-case line each.
5. `stories-test-strategy.md` 5.1a merged into 5.1.
6. `pipeline-efficiency-s317-s318.md:577` corrected: 2c and 2d removed from the gap list, and the
   list points here.

**Backlog notes (the docs release, not a code release)**
- BL-508 cites this document as its three-sprint evidence.
- BL-509 is contradicted for stories: sharded elicitation's unique yield exceeds the single voice's.
  Re-scope it or close it on this evidence.
- BL-568 and BL-569 close on R1 to R3.

## Blind spots

- **Party-time text in s319 did not survive anywhere searched**, so elicitation's MISSED-BY-PRIOR there
  is a floor.
- **Survival is checked by token or phrase presence** in the shipped blobs, not by re-reading the
  semantics.
- **No MINOR finding was classified.**
- **Stories elicitation and adversarial survival was not token-tested.** Those uniqueness counts come
  from reading.
- **s317's requirements adversarial p1 file on disk was rewritten by the lead** after the adversary
  returned NOT_MET, so its counts are of the rewrite.
- **Rule firing counts come from graph's tracked logs**, filtered by each file's last commit date, and
  are not isolated to s317 and s318.
