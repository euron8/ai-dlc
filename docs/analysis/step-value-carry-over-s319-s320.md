# Step value — carry-over evaluation rounds (BL-810)

Measured for batch 243 on graph's s319 and s320 carry-over evaluation artifacts and transcripts, read
only, by the method of `step-value-s317-s319.md` and under the same operator ruling (an element stays
only on a named failure case plus catches no other round makes that survive to the shipped artifact;
rare high-consequence catches are judged on consequence). This document records round-level measurement as evidence; the KEEP-or-narrow decision per round and per fan-out width is BL-810's amended scope, carried by cluster c6, a separate release in batch 243.

## Populations and sources

| Figure | Population | Source |
|---|---|---|
| Spawns, dollars, agent-hours | every subagent spawn charged to `carry-over-evaluation` in s319 and s320, gate adjudicators excluded, plus s320's 21 adversarial p1 spawns the extractor charged to `route` (BL-813) | `pipeline-efficiency-s317-s320/scripts/extract.py` output, re-bucketed per round by `step-value-carry-over-s319-s320/scripts/cost2.py <extract-out>`. Control: the uncorrected s320 total reproduces BL-810's 114 / $127, and the script prints the 21 `route` rows |
| Findings | every CRITICAL and MAJOR in every party seat, elicitation shard and adversarial shard, part and cross; MINOR not classified | graph `_bmad-output/party-mode/s31N/` and `planning-artifacts/s31N/` (`carry-over-evaluation-*`, `coe-*`), counted by `scripts/counts.py <graph> <extract-out>`; s320 classified by `scripts/cls.py <graph> <revs-dir> <out.json>` |
| Revisions | s320: analyst draft (r0, reconstructed from the analyst's writes), after the party repair (r1), after the elicitation repair (r2), after the p1 section repair (r2b), after the p1 serial repair (r3), shipped (r4). s319: shipped | graph blobs, not landed here (consumer content): r1 `2a209ae17ea51182f5f092405eaf99f7b6f6ddf0`, r2 `c7318d0f12ef998c2b32aa63b928060016fc9465`, r2b `6824bc3702f040dbd1fcfa93b9fcbf35f2dbc6f6`, r3 `a4010b9891ee2c14e113cb045133e53999adb972`, r4 `1106438812b568edbd549e53f41f00506919f267`, s319 shipped `32492885c5895fc9d4b58f0f88bba5989227d307`; read with `git -C <graph> cat-file -p <blob>`. Token counts by `scripts/fu4.sh` (r3, r4) and `scripts/fu7.sh` (r1 to r4) |
| Shipped artifact | the carry-over evaluation at the commit its gate passed | s320's gate passed (gate-log line 31), so s320 counts in full (`s320-r4-SHIPPED.md`); s319's is `s319-SHIPPED.md` |

## Definitions

The four columns of `step-value-s317-s319.md`:

- **REFOUND:** a later round raised the same defect.
- **MISSED-BY-PRIOR:** the finding sits in text that existed when an earlier round ran.
- **REPAIR-INTRODUCED:** the finding sits in text the previous round's repair, or a fold, wrote or
  half-fixed.
- **UNIQUE-SURVIVED:** not REFOUND and not REPAIR-INTRODUCED, and the fix is present in the shipped
  artifact.

The token classifier over s320 (`scripts/cls.py`) maps onto them as: PRESENT-IN-PRIOR to MISSED-BY-PRIOR,
NEW-SINCE-PRIOR to REPAIR-INTRODUCED, and NOQUOTE-IN-REVIEWED to unresolvable (no quoted span located in
the reviewed revision).

**The repair-introduced caveat.** Under the strict definitions, adversarial p2 scores 0 unique-survived,
because every p2 finding is REPAIR-INTRODUCED. But no round before p2 can see text the p1 repair wrote:
party, elicitation and p1 all ran before it existed. A defect in that text is caught by p2 or by
nothing, so p2's catches are unique to it, and this document scores them that way. Both numbers are
shown below.

## Cost

| Round (with its repair) | s319 spawns / $ / agent-h | s320 spawns / $ / agent-h |
|---|---|---|
| Analyst draft | 1 / $2.05 / 0.2 | 1 / $1.06 / 0.1 |
| Party, part | 24 / $18.81 / 1.4 | 32 / $18.17 / 1.9 |
| Party, cross | 24 / $16.47 / 1.2 | 24 / $18.79 / 2.8 |
| Party repair | 1 / $7.08 / 0.7 | 10 / $13.55 / 1.6 |
| Elicitation, part | 6 / $9.46 / 0.7 | 3 / $10.46 / 1.1 |
| Elicitation, cross | 6 / $9.54 / 0.7 | 3 / $7.32 / 0.7 |
| Elicitation repair | 7 / $5.26 / 0.8 | 4 / $7.26 / 2.2 |
| Decision folds | — | 2 / $2.85 / 0.2 |
| Adversarial p1, part | 6 / $4.71 / 0.2 | 7 / $9.91 / 0.7 |
| Adversarial p1, cross | 6 / $7.61 / 0.5 | 6 / $16.22 / 1.5 |
| Adversarial p1 repair | 7 / $5.68 / 0.5 (no pass number in the descriptions) | 8 / $6.76 / 0.6 |
| Adversarial p2, part / cross / repair | not run | 7 / $12.18 / 0.8; 6 / $12.56 / 0.7; 6 / $3.55 / 0.3 |
| Adversarial p3, part / cross | not run | 7 / $7.62 / 0.4; 6 / $10.28 / 0.5 |
| **Total** | **88 / $86.66** | **132 / $158.55** |

Dollars are API-list-equivalent subagent spend. s320's total is corrected per BL-813 (the extractor had
charged 21 adversarial p1 spawns to `route`); the uncorrected 114 / $127 is the control.

## Yield (MAJOR+, unique surviving, part + cross)

| Round | s319 | s320 |
|---|---|---|
| Party | at least 0/14 + 0/9 | at least 0/8 + 0/6 |
| Elicitation | 0/2 + 0/1 | 0/3 + 0/1 |
| Adversarial p1 | 0 | 0/6 + 0/2 |
| Adversarial p2 | not run | strict 0; by the caveat 9 MAJOR, all fixed in r4 |
| Adversarial p3 | not run | 0 of 2 distinct MAJORs shipped fixed |

Entries read C/M (CRITICAL/MAJOR). Party figures are floors: the first round's catches are unique by
construction, and survival was judged by token presence (see blind spots).

Adversarial p2, s320: the token classifier scores its 9 MAJORs as 7 NEW-SINCE-PRIOR and 2
PRESENT-IN-PRIOR. On reading, `2.md` F-1's quoted claim ("a `current_value_usd` that is not actually
fee-inclusive") first appears in r3, the p1 repair's output, and `cross-1.md` F-1 is the serial repair
leaving Bucket 1's Dependencies field at "none" after rewriting the sentence beside it, a half-fix. All 9
therefore sit in text the p1 repair wrote or half-fixed. No other round raised any of them.

**9 of 9 shipped fixed: each fix token is absent from the text p2 reviewed (r3) and present in the
shipped text (r4).** Derived by `scripts/fu4.sh <r3> <r4>`, which counts each token with `grep -c -F` in
both revisions. Control in the same run: `ZZ-NEVER-TOKEN-b810` reads r3=0, r4=0.

| p2 finding | Fix token | r3 | r4 | r4 line |
|---|---|---|---|---|
| `1.md` F-1 | ``pipeline-snapshot.md` changed`` | 0 | 1 | 3 |
| `2.md` F-1 | `already counts something it should not` | 0 | 1 | 130 |
| `2.md` F-2 | `action_type="FEE_COLLECT"` | 1 | 2 | 117, 280 |
| `4.md` F-1 | `owns pricing a re-target` | 0 | 2 | 318, 319 |
| `6.md` F-1 | `assert il_lt .= 15` | 0 | 2 | 532, 534 |
| `6.md` F-2 | `sed -n '506,511p' …carry-over-backlog.md` | 0 | 1 | 567 |
| `7.md` F-1 | `grep -c 'claimable_raw' docs/escalations/pending.md` | 0 | 1 | 693 |
| `cross-1` F-1 | `Dependencies: the Rebalancer half of the Day-0 read` | 0 | 1 | 90 |
| `cross-2` F-1 | `pool_lifetime_il_usd_lifetime_scope` | 0 | 3 | 113, 525, 659 |

`action_type="FEE_COLLECT"` is the one token already in r3: the fix adds a second occurrence, a new
derivation fence, so its evidence is the count rising from 1 to 2. Where a defect token exists, it goes
the other way: `not actually fee-inclusive` 1 to 0, `Dependencies: none; reads precede` 1 to 0, `same
pool and lifetime IL figure` 2 to 0.

For six of the nine, mostly "a negative with no derivation", the quoted claim is still in r4. That is
consistent with a fix. The finding was that the claim was underived, not that it was false, and the repair
retained the claim and added the derivation fence that grounds it. The fence's arrival is the evidence of
the fix, so the claim's persistence is not evidence against it.

Adversarial p3, s320: three MAJOR headings, two of them (`cross-2`, `cross-6`) the same defect ("which
also covers closed positions" with no derivation), which is still present in r4 at two sites; the third,
`1.md` F-1, quotes text that is also unchanged in r4. 0 of 2 shipped fixed.

## Consequence (the guard clause)

- **Party:** s319, claim signing decided autonomously, struck to an operator choice; s319, a claim
  function not bound to the existing nonce manager (shipped line 282); s320, a `hodl_wallet` destination
  edit with no typed confirmation (r4 line 431).
- **Elicitation:** s319 `2.md` F-1, the only CRITICAL in either sprint's carry-over evaluation: the
  party repair pinned the leaf-absent dust floor to 0.01 against the operator's 0. Fixed at shipped line
  101. It sits in party-repair text, so no earlier round could read it, and without elicitation it ships.
- **Adversarial p1:** s320 `1.md` F-1, the bug-variant re-route recorded as the lead's call after the
  operator had decided it (r4 line 55).
- **Adversarial p2:** s320 `2.md` F-1, a wrong-sign IL candidate cause (r4 line 130); `cross-2` F-1, a
  wrong claim about an IL field (r4 line 113).
- **Adversarial p3:** none.

## Verdicts

| Round | Round-level reading (evidence for c6) | Evidence |
|---|---|---|
| Party (part + cross) | unique surviving catches measured | unique surviving catches in both sprints, including two capital-path defects |
| Elicitation (part + cross) | unique surviving catches measured | unique surviving catches in both sprints; the only CRITICAL in either sprint is its catch (s319 `2.md` F-1) |
| Adversarial p1 | unique surviving catches measured | s320 0/6 + 0/2 unique survivors; s319 p1 had none |
| Adversarial p2 | unique surviving catches measured, on evidence | 9 MAJORs only it could read, all shipped fixed |
| Adversarial p3 | unique surviving catches measured, under Rule 8 | 0 of 2 shipped fixed; it is the loop's terminal pass, whose `EXIT_CONDITION_MET` verdict Check 24 reads |

No round is removed in this release. Each round's `Failure caught:` line is in `carry-over-evaluation.md` §3a,
"Minimum mechanism (Rule 26(c))", pinned by `process-rule-pins` rows `coe-26c-caught` and `coe-26c-loop`.
As in the requirements series, the later passes' yield is the repairs' defect rate: every p2 and p3
finding sits in repair-written text.

## Blind spots

- **s319's elicitation-time text is unrecoverable.** No revision between the party repair and the
  elicitation repair survived, so s319's MISSED-BY-PRIOR for elicitation is a floor.
- **s320's party draft is reconstructed** from the analyst's writes (r0), not read from a committed
  revision, so a party finding against text the analyst rewrote before the seats read it may be misplaced.
- **Survival was judged by token presence**: a finding's quoted span absent from, or its fix's phrase
  present in, the shipped revision. A fix that reworded both reads as survived; a defect re-expressed in
  new words reads as fixed. The NOQUOTE-IN-REVIEWED findings (s320: 5 elicitation, 2 p1) could not be
  placed at all and are counted in no column.
- **Two sprints.** s319 ran no p2 or p3, so the p2 verdict rests on s320 alone.

## Not measured here

The residue-at-MET defect, the residue deferral at the convergence exit (`validate-adversarial-convergence.sh`
and `gate-validation.md`), is BL-814, owned elsewhere.
