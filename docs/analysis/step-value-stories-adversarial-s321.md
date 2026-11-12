# Step value — stories adversarial passes p1 to p3 and their repairs, s321 (BL-812)

Measured for batch b256 on graph sprint 321's stories adversarial passes, read only, from a scratch
clone of graph with every file read at a pinned ref. BL-812 item 1 records that stories-test-strategy's
step-value evidence covers its elicitation shards only (`step-value-stories-elicitation-s321.md`) and
that "the adversarial passes p1 to p3 and their repairs carry no value reading". This document is that
reading. It applies the elicitation method to each pass, and takes its verdict frame for adversarial
passes from `step-value-s317-s319.md` (its BL-569 yield and verdict tables).

`docs/analysis/pipeline-efficiency-s317-s322/scripts/adversarial_yield.py` computes every mechanical
figure below. The REFOUND judgments and the attribution reading are manual and are listed in the
per-finding table.

Every graph path below is relative to `_bmad-output/planning-artifacts/s321/` unless it names a
commit.

## Method, as applied

Population: every `### ` heading in a shard of `shards/stories-p1/`, `stories-p2/` or `stories-p3/`
that carries the whole word CRITICAL or MAJOR. This is the regex `elicitation_yield.py` uses. MINOR
findings are not classified. Each finding takes the first class that applies.

1. **REFOUND** (manual). Another shard of the same pass raised the same defect (the same story contract
   and the same failure mode), or a later pass raised it. A later pass that finds a flaw in text the
   repair wrote is not re-raising the finding.
2. **REPAIR-INTRODUCED.** The finding sits in text that an earlier repair, fold or amendment wrote.
   Either the finding body attributes the text to one (read, not regex-matched), or the span arm holds.
   The span arm holds when the finding body quotes at least one span the pass read (a backtick or
   double-quoted span of 12 or more characters) and every such span is absent from the authored text
   at 01f3925ec. The origin is the repair that wrote the text. The script records, for each span, the
   earliest text state that carries it (authored, readiness fold, party repair, elicitation repair, or
   p1+p2 repair).
3. **UNIQUE-SURVIVED.** Every `grep -c -F` token that the finding's repair blocks run against a story
   file is in that story at the stories gate (41484a513), and the text the pass read did not already
   carry all of them. A repair that runs no story-targeted token has its other tokens checked against
   the whole shipped story set. A repair block is any `### ` section of a repair record whose
   `- source:` line names the finding, including a block that names several findings.
4. **UNIQUE-unverified.** Every other finding. Its repair carries no token, or only part of its token
   set reached the gate. It is not counted as a survivor.

Two attributes do not change a finding's class.

- **MISSED-BY-PRIOR**, as `step-value-s317-s319.md` defines it: the finding sits in text that existed
  when the elicitation round ran. Here that means every span from the read text is already present at
  e6f964de8.
- **EARLIER-RAISED**: an earlier round raised the same defect and its repair did not close it.

The elicitation document classified four of its own findings REFOUND because a p1 shard re-raised
them (01#F-5, 03#F-4, 14#F-5 and 19#F-1), and they name five p1 findings (01#F-5 names two, 01 F-1 and
cross F-1). This reading credits those defects to p1, so neither document drops them.

Steps 2 to 4 are computed by the classifier. The REFOUND calls and the attribution reading in step 2
are manual.

## Inputs

| Input | Graph source |
|---|---|
| Text p1 read | the 25 stories at 6509c26b2 ("stories elicitation round delivered"). Every p1 shard's `artifact_sha` equals the sha256 of its story there, 25 of 25. Control: the authored text at 01f3925ec matches 0 of 25 |
| Text p2 read | the p1-repair output, which no commit carries. Only its hashes are available: all 20 p1-repaired stories chain. For 13, the p2 shard's `artifact_sha` equals the p1 repair part's `artifact_sha_after`; for the other 7 it equals the `artifact_sha_after` of the serial remainder record (`stories-serial-repair-p1.md` and its lane records) whose `artifact_sha_before` is that part's `artifact_sha_after`. The script prints the `hash chain:` line. 14 of 25 p2 shards match 9671dbb93, the post-p2-repair commit, which stands in as the proxy. The bytes are not available, so for p2 the token arm's already-present column is measured against that proxy and is not reliable. Every p2 finding is REPAIR-INTRODUCED by attribution, before that column is reached |
| Text p3 read | the stories at 9671dbb93 ("stories adversarial passes 1-2"), 25 of 25 by `artifact_sha` |
| Earlier text states | 01f3925ec authored, c3c00660f readiness fold, e6f964de8 party repair, 6509c26b2 elicitation repair |
| Shards | `shards/stories-p1/`, `stories-p2/`, `stories-p3/`: 25 per-story shards and `cross.md` each |
| Repair records | `stories-repair-p1.md` (20 parts), `stories-serial-repair-p1.md` and `shards/stories-serial-repair-p1/lane-11.md`, `lane-17.md` (the lanes and the fan-in), `stories-repair-p2.md` (10 parts and the serial remainder), `stories-repair-p3.md` (2 parts and the serial block) |
| Shipped text | the stories at 41484a513, "gate story passed" (the same gate commit the elicitation document uses). After the p3 repair (169208e5b), three commits edit the stories, as `git log 169208e5b..41484a513 -- stories/` lists them: 0b8f86e0b appends story changelogs (25 files, 656 insertions, 0 deletions), a92c1be3d is the planning-artifacts commit (25 files, 192 insertions, 25 deletions), and 04cf4a2f8 is the gate pre-check repair of story 5.6 (1 file, 4 insertions, 4 deletions; `gate-story-repair-p1.md`, Check 902s). The stats are `git show --numstat` on `stories/` for each, and the script prints all three with the list |
| Round epochs | `rounds/stories-p1.return` 2026-11-04T17:32:47Z, `stories-p2.return` 19:11:03Z, `stories-p3.return` 19:35:09Z |
| Dollars and spawns | `spawns.jsonl`, extracted fresh into a `mktemp` directory by BL-812's command (`extract.py`, `spawns.py`, `analyze.py` with `EXTRACT_WIN_END=2026-11-09T00:00:00Z`; token control units==segs 21411048714 on both sides). Its md5 is e3c0aea284d67c57e9eb834ac96e51eb, equal to the copy from an earlier b255 extraction that the first version of this document used, so every figure was re-derived on the fresh file and none moved |

## Controls (same run of `adversarial_yield.py`)

| Control | Value | Expected | Result |
|---|---|---|---|
| step total, s321 stories-test-strategy | 428 spawns, $589.64 = 17.12 and $23.59 per story | BL-812: 17.12 and $23.59 | MATCH |
| elicitation adversary dollars | per-story $111.55, cross $11.33 | the elicitation document's cells | MATCH, MATCH |
| `elicitation_yield.py`'s four s319 cells on the same file | 54/$40.89, 14/$32.19, 22/$34.58, 4/$18.94 | the s319-s320 study | MATCH ×4 |
| C/M per pass against the lead's `rounds/stories-repair-pN.return` | 26 (3 CRITICAL, 23 MAJOR), 4, 2 | 3 + 23, 4, 2 | MATCH ×3 |
| token and span arms re-run on the ELICITATION population, compared with the evidence column of `step-value-stories-elicitation-s321.md` | 59 of 59 rows reproduced | all | MATCH. This control is known to discriminate: before span multiplicity and the no-id join were fixed, it read 54 of 59 and printed DIFFERS |
| join: findings with at least one repair block | 32 of 32 | all (the stories series has no deferral route) | MATCH |
| step total, s319 stories-test-strategy (the like-for-like comparison below) | 311 spawns, $441.19 | the figure read when the comparison was written: 311, $441.19 | MATCH (the script prints it) |
| partition of the step by description | sums to 428 / $589.64; its adversarial part is 116 / $104.17, equal to the per-pass sum | the step total | MATCH ×2 |
| description-based against epoch-based pass assignment | 0 disagreements | 0 | MATCH (the two `Serial lane` rows carry no pass number and are placed by epoch) |
| the elicitation document's `later:` REFOUND rows (01#F-5 to p1 01 F-1 and cross F-1, 03#F-4 to 03 F-1, 14#F-5 to 14 F-1, 19#F-1 to 19 F-1), parsed from that document by the script | 4 findings naming 5 p1 findings; 5 of 5 resolve to a p1 C/M heading | 4, 5, 5 | MATCH |
| impossible token `QZXV-NO-SUCH-TOKEN-7731` in descriptions and in all 78 shards | 0, 0 | 0 | MATCH |

## Cost per pass

Dollars come from `spawns.jsonl` (`usd`). Every adversary and remediator spawn in these passes ran
sonnet (`model_ran`). Wall clock is in session, from round epoch to the next round epoch, and includes
the repair. The script bounds it by the spawns themselves: p1 spawn activity runs 17:32:55 to 19:06:42
(93.8 min) and the longest stretch with no spawn running is 1.7 min, so no resumed-session gap sits
between its spawns; the other 4.5 min of the 98 is lead time around them, after the last spawn ended
(p2: 21.6 min of 24.1, longest idle 0.9 min; p3: 17.0 min of 18.9, longest idle 1.0 min).

| Pass | Adversary spawns | Adversary $ | Repair spawns | Repair $ | Pass + repair | Wall clock |
|---|---|---|---|---|---|---|
| p1 | 27 (25 + cross + 1 re-dispatch) | $51.70 | 23 (20 parts, 2 lanes, fan-in) | $14.78 | 50, $66.47 | 98 min (93.8 min of spawn activity) |
| p2 | 26 | $16.79 | 11 (10 parts, serial remainder) | $6.26 | 37, $23.06 | 24 min |
| p3 | 26 | $12.80 | 3 (2 parts, serial) | $1.84 | 29, $14.64 | ≤19 min (to the test-strategy author spawn, 19:54) |
| **p1-p3** | 79 | $81.29 | 37 | $22.88 | **116, $104.17; 4.64 spawns and $4.17 per story** | |

## Yield (MAJOR+, after reading)

| Pass | C/M | CRITICAL | REFOUND | REPAIR-INTRODUCED | UNIQUE-SURVIVED | UNIQUE-unverified |
|---|---|---|---|---|---|---|
| p1 | 26 | 3 | 2 | 11 | **9** | 4 |
| p2 | 4 | 0 | 0 | 4 | **0** | 0 |
| p3 | 2 | 0 | 0 | 2 | **0** | 0 |
| **all** | 32 | 3 | 2 | 17 | **9** | 4 |

p1's two REFOUND findings are one defect, raised twice in the same pass: 01 F-1 and cross F-1, Story
1.1's SWEEP claim against Story 5.6. The defect is EARLIER-RAISED (elicitation 01#F-5), and its
fixes reached the gate (1/1 and 2/2 tokens). p1's MISSED-BY-PRIOR set, the unique findings whose every
span was already in the text elicitation read, is 5: 02 F-1, 10 F-2, 12 F-1, 20 F-1 and 20 F-2.

## Summary: cost per unique survivor

The elicitation document prices a survivor on adversary dollars only, and this table does the same.
The column with the repair added is shown beside it.

| Pass | Shards | Spawns (adversary) | C/M | Unique survived | Adversary $ | $ per survivor | Pass + repair $ per survivor |
|---|---|---|---|---|---|---|---|
| p1 | 26 | 27 | 26 | 9 | $51.70 | $5.74 | $7.39 |
| p2 | 26 | 26 | 4 | 0 | $16.79 | none survived (by construction: every finding sits in p1-repair text) | none |
| p3 | 26 | 26 | 2 | 0 | $12.80 | none survived (every finding sits in p2-repair text) | none |
| elicitation, s321 (for reference) | 26 | 38 | 87 | 36 | $122.88 | $3.41 | |

p1 also caught 11 defects in the text that the party and elicitation repairs wrote. No later round
raised any of them, and the fixes for 8 reached the gate by token: 01 F-2, 09 F-1, 09 F-2, 10 F-1,
11 F-1, 21 F-1, 21 F-2 and 23 F-1. Two of the 8 are CRITICAL. The elicitation and party readings do not
count these, because the method excludes REPAIR-INTRODUCED findings from the round whose repair wrote
the text. Counting them, with the REFOUND pair as one defect, p1 has 18 distinct catches whose fix
reached the gate: $51.70 / 18 = $2.87 each.

## What the repairs introduced

| Text written by | Cost of that repair | MAJOR+ found in it by p1-p3 | CRITICAL | Fix at the gate |
|---|---|---|---|---|
| party repair (e6f964de8) | (party round, not this reading) | 4 in p1 (10 F-1, 11 F-1, 21 F-1, 21 F-2), plus 19 F-2 whose spans the party and elicitation repairs both wrote | 1 (11 F-1) | 4 by token; 19 F-2 has no token |
| elicitation repair (6509c26b2) | $26.19 (the elicitation document) | 6 in p1 (01 F-2, 09 F-1, 09 F-2, 13 F-2, 23 F-1, 23 F-2), plus the REFOUND pair 01 F-1 / cross F-1 (a half-applied elicitation repair, by its body) | 1 (09 F-1) | 4 by token, the pair by token; 13 F-2 and 23 F-2 have no token |
| p1 repair | $14.78, 23 spawns | **all 4 of p2's** (03 F-1, 09 F-1, 09 F-2, 13 F-1) | 0 | 3: 03 F-1 and 09 F-1 by token, and 13 F-1 by deletion (the struck clause "and by the deploy-validate smoke" reads 0 in story 3.3 at 41484a513, against a control clause from the same sentence that reads 1). 09 F-2's p2 fix was rewritten by the p3 repair after p3 09 F-1 found it could not red (0/1) |
| p2 repair | $6.26, 11 spawns | **both of p3's** (09 F-1, 10 F-1) | 0 | 2: p3 09 F-1 by token, and p3 10 F-1 by deletion (its one token was already in the text p3 read, so the token does not discriminate; the deleted text reads 1/1 gone at the gate) |
| p3 repair | $1.84, 3 spawns | nothing measured; no adversarial pass follows it. The gate pre-check repair (Check 902s) edited story 5.6, which the p3 repair did not touch | | |

Four of the six p2 and p3 MAJORs sit in one chain, stories 2.3 and 2.4, on the native-spend bound
(LR-S321-8): the p1 repair wrote the coverage claim, p2 found it false, the p2 repair added a
parametrization, p3 found that it cannot red, and the p3 repair closed it. The other two are
p2 03 F-1 (story 1.3: the F-3 repair names `importlib.reload`, which 1.2 AC1 rules out) and p2 13 F-1
(the false deploy-validate credit in story 3.3). The script counts the split: 4 of 6 in shards 09 and
10. Each finding sits in text the previous repair wrote.

## Shards that re-read unchanged bytes

| Pass | Shards whose `artifact_sha` equals the same ordinal's in the prior pass | $ | Spawn-hours | C/M from those shards |
|---|---|---|---|---|
| p2 | 5 of 25 | $1.86 | 0.10 | 0 |
| p3 | 14 of 25 | $5.71 | 0.38 | 0 |

So 19 shard reads of story bytes that the previous pass had already read cost $7.57 and 0.48
spawn-hours (the sum of those spawns' own minutes, not wall clock) and raised no MAJOR or CRITICAL. The per-pass cross shards cost p1 $9.10, p2 $2.21 and p3 $0.95, and raised 1 C/M
in total: p1 cross F-1, which is REFOUND. Over one sprint, 19 reads is too few to bound a rare catch.
The zero rules out a frequent catch, not a rare high-consequence one.

## Consequence (the guard clause)

- **CRITICAL.** All three are p1's, and every fix reached the gate. 19 F-1 is a unique survivor: Story
  5.2 AC1's swapped-wiring guard reads property values from a `cdk diff` that cannot show them. It is
  EARLIER-RAISED: elicitation 19#F-1 raised it and the elicitation repair left it open. 09 F-1 is in
  elicitation-repair text: Story 2.3's completeness check cannot pass against a correct build, on the
  native-spend bound. 11 F-1 is in party-repair text: Story 3.1 AC5's allow-list is taken against the
  merge-base.
- **Capital and funds path, by reading the headings.** In p1 these are 01 F-2 (the replay oracle omits
  `deployed_ranges`, the burn source), 09 F-2 (the native-spend bound location), 10 F-1 (an exposure
  test reds on the capital path with no disposition) and 03 F-1 (zero `sign_transaction` legs that
  cannot fail). p2 has 09 F-1 and 09 F-2, and p3 has 09 F-1 and 10 F-1: four of the six p2 and p3
  findings are on the native-spend bound (p2 09 F-1 and 09 F-2, p3 09 F-1 and 10 F-1); p2 03 F-1 and
  p2 13 F-1 are not. The p1 findings in that list other than 03 F-1 sit in
  upstream repair text, and every p2 and p3 one sits in text this series' own repair wrote. This
  grouping comes from reading the headings; no capital-path classifier exists.

## Verdict (a records reading; no step file changes)

The ruling is "A step with no measured value goes" (`.claude/rules/operator-rulings.md`).

| Element | s321 measured value | Verdict |
|---|---|---|
| Adversarial p1, with its repair | 9 unique survivors at $5.74 each, including the one unique CRITICAL (19 F-1). It also has 11 catches in party- and elicitation-repair text that no later round raised; 8 of those fixes reached the gate, 2 of them CRITICAL. That is 18 distinct gate-surviving catches at $2.87 | **Keep.** It is the convergence exit, and it carries unique and high-consequence value |
| Adversarial p2 and p3, with their repairs | 0 unique survivors, by construction. All 6 MAJORs sit in the previous pass's repair text, 4 of them in the native-spend-bound chain, and 5 of the 6 fixes are at the gate. Cost $37.70 for both (pass + repair) | **Keep while repairs write defects**, as `step-value-s317-s319.md` ruled for requirements p2 and p3. They are the only check on a repair's own text, and on s321 that text held capital-path defects in three successive rounds |
| p2/p3 shards on unchanged story bytes | 19 reads, $7.57, 0.48 spawn-hours, 0 C/M | **Narrow candidate, recorded only.** The measured upper bound on the saving is $7.57 and 0.48 spawn-hours on s321 ($0.30 per story). One sprint cannot bound a rare catch, and no narrowing is contracted here |
| The repairs | p1's repair wrote all 4 p2 MAJORs, and p2's repair wrote both p3 MAJORs | The removable cost is the repair defect rate, not a pass (BL-508's finding) |

**The adversarial-pass part of stories-test-strategy did not rise.** From the same `spawns.jsonl` and
the same step, s319's stories adversarial p1 and p2, with their repairs, are 70 spawns and $120.15
($108.40 adversary, $11.75 repair), or $6.01 per story over 20 stories. s321's p1 to p3 are 116
spawns and $104.17, or $4.17 per story over 25. s319's adversary spawns ran opus and its repair spawns sonnet, and every
s321 pass spawn ran sonnet (`model_ran`; the script prints both sets). Spawns per story rose from 3.50 to 4.64, and dollars per story fell by
$1.84. Within the s321 step, the partition is: party round with its repair $187.19 ($7.49 per story),
elicitation $149.07 ($5.96), test-strategy authoring with its passes p1 to p6 $125.88 ($5.04),
stories adversarial $104.17 ($4.17), and authoring, readiness and amendments $22.90 ($0.92). This is
priced by `spawns.jsonl`, not by `roll.py`, so it is not a share of BL-812's $25.0 to $26.9 rise.

## Per-finding classification

The token arm is measured at the stories gate 41484a513, and "in read" counts the tokens already
present in the text the pass read. For p2 that read text is the 9671dbb93 proxy. The span column
counts, for each span from the read text, the earliest state that carries it.

| Pass | Story | Shard | Finding | Heading (short) | Class | Origin / attribute | Evidence |
|---|---|---|---|---|---|---|---|
| p1 | 1.1 | `01.md` | F-1 | AC2 records SWEEP as observed by AC5; AC5 and 5.6 say it never is | REFOUND | same pass: `shards/stories-p1/cross.md` F-1; EARLIER-RAISED (elicitation 01#F-5); body attributes the stale sentence to elicitation repair F-5, half-applied | tokens 1/1 at gate, 0 in read |
| p1 | 1.1 | `01.md` | F-2 | the golden tuple omits `deployed_ranges`, the burn source | REPAIR-INTRODUCED | elicitation repair: its F-3 wrote the five-field tuple (`proposed_ranges` reads 0 in story 1.1 at e6f964de8 and 3 at 6509c26b2); EARLIER-RAISED (elicitation 01#F-3 listed the field) | spans: read text 2, authored 1; tokens 1/1 |
| p1 | 1.2 | `02.md` | F-1 | existing base-chain tests fail under the new predicate and are not owned paths | UNIQUE-unverified | MISSED-BY-PRIOR (all 7 spans authored) | repair carries no `grep -c -F` token |
| p1 | 1.3 | `03.md` | F-1 | AC1's zero-`sign_transaction` legs run dry-run and cannot fail | UNIQUE-SURVIVED | EARLIER-RAISED (elicitation 03#F-4) | 5 repair blocks; tokens 3/3 at gate, 1 in read |
| p1 | 1.3 | `03.md` | F-2 | "`RPC_URL` read only in `_main`" is false, underived | UNIQUE-SURVIVED | | tokens 1/1, 0 in read |
| p1 | 2.3 | `09.md` | F-1 | **CRITICAL**: AC3's completeness check cannot pass against a correct build | REPAIR-INTRODUCED | elicitation repair, by body ("Introduced by the stories-elicitation repair", part 9/25) | tokens 1/1 |
| p1 | 2.3 | `09.md` | F-2 | AC2's second bound location is a branch Story 2.1's rule makes unreachable | REPAIR-INTRODUCED | elicitation repair, by body ("re-opens the F-1 repair of the elicitation record", part 9/25); EARLIER-RAISED (elicitation 09#F-1) | tokens 1/1 |
| p1 | 2.4 | `10.md` | F-1 | the AC1 exposure case has no disposition when it reds | REPAIR-INTRODUCED | party repair: the "Exposure record" sentence reads 0 in story 2.4 at 01f3925ec and c3c00660f and 1 at e6f964de8; the body cites its party adjudication | spans: party repair 9, authored 3; tokens 1/1 |
| p1 | 2.4 | `10.md` | F-2 | positional, universal and negative claims underived | UNIQUE-unverified | MISSED-BY-PRIOR | no token |
| p1 | 3.1 | `11.md` | F-1 | **CRITICAL**: AC5's allow-list is taken against the merge-base with `main` | REPAIR-INTRODUCED | party repair: span arm 5/5 absent from authored, all first at e6f964de8; body names the party repair's FI-RANGE-SC | tokens 1/1 |
| p1 | 3.1 | `11.md` | F-2 | case 7 does not pin the fake's response body | UNIQUE-SURVIVED | | no span; tokens 1/1, 0 in read |
| p1 | 3.2 | `12.md` | F-1 | two caller and live-service claims underived | UNIQUE-unverified | MISSED-BY-PRIOR | no token |
| p1 | 3.3 | `13.md` | F-1 | item 2's resolver and restore have no assertion route | UNIQUE-SURVIVED | | 5 blocks (part, lane-11, fan-in sweep); tokens 1/1, 0 in read |
| p1 | 3.3 | `13.md` | F-2 | the new shared reader's "unreadable record" is not bound to 3.1 | REPAIR-INTRODUCED | elicitation repair: span arm 1/1, first at 6509c26b2 | no token |
| p1 | 3.3 | `13.md` | F-3 | the deployed-ranges loop varies only `REBALANCER_URL` | UNIQUE-unverified | | tokens 1/2 at gate |
| p1 | 3.4 | `14.md` | F-1 | no AC3 case exercises the unreadable-record arm | UNIQUE-SURVIVED | EARLIER-RAISED (elicitation 14#F-5) | tokens 2/2, 0 in read |
| p1 | 4.2 | `16.md` | F-1 | the AC4 import control cannot succeed: `python3 -I` ignores the cwd | UNIQUE-SURVIVED | 3 of 6 spans were first written by the elicitation repair; the body does not attribute, and 1 span is authored, so by this method it is not REPAIR-INTRODUCED | tokens 1/1, 0 in read |
| p1 | 5.2 | `19.md` | F-1 | **CRITICAL**: the swapped-wiring guard reads property values from a `cdk diff` | UNIQUE-SURVIVED | EARLIER-RAISED (elicitation 19#F-1) | 3 blocks; tokens 2/2, 0 in read |
| p1 | 5.2 | `19.md` | F-2 | `MonitoringStack` universal and negative underived | REPAIR-INTRODUCED | party and elicitation repairs: span arm 4/4 absent from authored (party repair 2, elicitation repair 2) | no token |
| p1 | 5.3 | `20.md` | F-1 | AC7's mutation control does not exercise the sentinel-sha assertion | UNIQUE-SURVIVED | MISSED-BY-PRIOR (spans party repair 3, authored 1) | tokens 1/1, 0 in read |
| p1 | 5.3 | `20.md` | F-2 | AC5's `contract_allowlist` mutation need not red the log-line assertion | UNIQUE-SURVIVED | MISSED-BY-PRIOR | tokens 1/1, 0 in read |
| p1 | 5.4 | `21.md` | F-1 | "Every service runs the image tagged `latest`" is false | REPAIR-INTRODUCED | party repair: span arm 2/2 absent from authored, first at e6f964de8. The body's own authorship check (`grep` over three repair RECORDS) reads "original story text". The commits say otherwise, and the commit-based arm is the measurement | tokens 1/1 |
| p1 | 5.4 | `21.md` | F-2 | AC4's revert predicate keys on `[-/+]`, a token `cdk diff` does not emit | REPAIR-INTRODUCED | party round, by body ("entered with the party round's Matic-unchanged fix"); the span arm also holds, 3/3 | tokens 1/1 |
| p1 | 5.6 | `23.md` | F-1 | AC2's digest requirement is absent from the discharge predicate | REPAIR-INTRODUCED | elicitation repair, by body (its E-4 added the digest text); the span arm also holds, 3/3 | tokens 1/1 |
| p1 | 5.6 | `23.md` | F-2 | SWEEP-writer and digest-source universals underived | REPAIR-INTRODUCED | elicitation repair: span arm 2/2, first at 6509c26b2; the body names the elicitation repair records | no token |
| p1 | 1.1, 5.6 | `cross.md` | F-1 | FR-S321-4 "every action type" has three unobserved types; 1.1 contradicts 5.6 on SWEEP | REFOUND | same pass: `shards/stories-p1/01.md` F-1; EARLIER-RAISED (elicitation 01#F-5) | tokens 2/2 |
| p2 | 1.3 | `03.md` | F-1 | the F-3 repair names `importlib.reload`, which 1.2 AC1 rules out | REPAIR-INTRODUCED | p1 repair, by body (part 3/25, entry F-3, a MINOR's repair) | tokens 1/1 at gate |
| p2 | 2.3 | `09.md` | F-1 | "the one bound at the top covers them" is false for the offramp senders | REPAIR-INTRODUCED | p1 repair, by body (part 9, entries F-1 and F-2) | tokens 2/2 |
| p2 | 2.3 | `09.md` | F-2 | AC2 now says every venue and fallback signs at one amount; only two paths are tested | REPAIR-INTRODUCED | p1 repair, by body (part 9 F-2 made the clause unconditional) | tokens 0/1: superseded by the p3 repair |
| p2 | 3.3 | `13.md` | F-1 | item 2 credits the restore path to a deploy-validate smoke that does not reach it | REPAIR-INTRODUCED | p1 repair, by body (lane-11 F-1) | deletion: the struck clause reads 0 at the gate (control 1) |
| p3 | 2.3 | `09.md` | F-1 | the repaired AC3 venue parametrization cannot red the bypass | REPAIR-INTRODUCED | p2 repair, by body (part 9, entry F-2) | tokens 1/1; deletion 4/4 |
| p3 | 2.4 | `10.md` | F-1 | AC4's new value-bound assertion cannot red a gross-sizing build | REPAIR-INTRODUCED | p2 repair, by body (the serial block of `stories-repair-p2.md`) | tokens 1/1, 1 in read, so no discrimination; deletion 1/1 gone |

Sensitivity:

- **10 F-1.** It is REPAIR-INTRODUCED by body attribution alone: the body cites its party
  adjudication, and 3 of its 12 read-text spans are authored text, so the span arm does not hold.
  Were the body attribution not accepted, 10 F-1 would be UNIQUE-SURVIVED (tokens 1/1, 0 in read,
  deletion 1/1 gone), giving p1 10 survivors at $5.17 each and 10 REPAIR-INTRODUCED.
- **Range.** Taken one at a time, 16 F-1 gives 8 survivors, 10 F-1 gives 10 and the 13 F-3 deletion
  arm gives 10, against 9 as classified: p1's survivors read as 8 to 10, $6.46 to $5.17 each, around
  $5.74. The two upward readings together would give 11 ($4.70). The script prints the dollar column.
- **16 F-1.** If its read-text spans written by the elicitation repair were taken as attribution,
  p1's unique survivors would be 8 ($6.46 each) and its REPAIR-INTRODUCED count 12.
- **Deletion arm.** It counts `grep -rn -F` sibling tokens that are present in the read text and gone
  at the gate. Every p1 finding with a deletion token has every deletion token gone at the gate. Of
  the four UNIQUE-unverified findings, only 13 F-3 has deletion tokens, and all 3 are gone at the
  gate. Counting a completed deletion as survival would make 13 F-3 a survivor, giving p1 10
  survivors at $5.17 each.

## Commands

- `python3 docs/analysis/pipeline-efficiency-s317-s322/scripts/adversarial_yield.py <OUT> <graph clone>`,
  with the graph clone made by `git clone -q --no-hardlinks file:///Users/n8/git/graph` and graph's
  `refs/remotes/origin/*` then fetched into it, since da6cadadd is reachable only from a
  remote-tracking branch. It exits 0 and its output prints 11 MATCH and 0 DIFFERS.
- `python3 docs/analysis/pipeline-efficiency-s317-s322/scripts/elicitation_yield.py <OUT> <graph clone>`
  on the same `<OUT>`: four s319 MATCH lines, and s321 $111.55 and $11.33.
- Figures that earlier had no command, each now a line of that script's output: `hash chain:` (the p1
  repair part and serial remainder joined to the p2 shards' `artifact_sha`), `commit 0b8f86e0b|a92c1be3d|04cf4a2f8
  on stories/` and `commits editing stories/ after the p3 repair` (`git show --numstat` and `git log`
  on the graph clone), `s319 adversarial/repair spawns model_ran`, `control s319 step total`, the
  `pN wall clock` lines, `re-read total` and `p1 $ per survivor by survivor count`.
- The text-state checks for 10 F-1 and 01 F-2 used `git show <ref>:<story> | grep -c -F` at 01f3925ec,
  c3c00660f, e6f964de8, 6509c26b2 and 41484a513. The impossible-token control in the same loop read 0
  at every ref, and the must-hit `proposed_ranges` read 3 at 6509c26b2.

## Not measured

| Item | Data available? |
|---|---|
| s319's stories adversarial p1 and p2 by this classification (only their cost is given above) | yes: graph shards at the s319 refs the s319-s320 study pins |
| test-strategy authoring and its passes p1 to p6 with repairs, $125.88 in the same step | yes: `shards/test-strategy-p1/` to `test-strategy-p6/` |
| defects the p3 repair's text caused downstream (implementation review against story text) | yes: graph implementation-stage records; not read |
| the exact bytes p2 read | no: no commit carries the p1-repair output. Its hashes are available and all 20 chain |
| whether a surviving fix is correct (token presence is not correctness), and the MINOR findings | no instrument in this method |
