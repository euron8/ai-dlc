# Step value — stories elicitation, s321 unique-survivor yield (BL-811)

Measured for batch b255 on graph sprint 321's stories elicitation round, read only, at graph HEAD
da6cadadd. It applies the method of `step-value-stories-elicitation-s319-s320.md` to the one s321
round, which is the reading BL-811's shard cost/yield half owes. `elicitation_yield.py` gave the raw
counts (84 per-story CRITICAL/MAJOR findings, 3 cross); this document classifies each of them.

Every graph path below is relative to `_bmad-output/planning-artifacts/s321/` unless it names a
commit.

## Method, as applied

Population: every `### ` heading in a shard of the round that carries the whole word CRITICAL or
MAJOR, the regex `elicitation_yield.py` counts with. MINOR is not classified. Each finding takes the
first class that applies, in this order.

1. **REFOUND** (manual). Another shard of the same round raised the same defect (the same story
   contract and the same failure mode), or a later pass of the sprint raised it (stories adversarial
   p1 to p3). A later pass that finds a flaw in the text the elicitation repair itself wrote is not a
   re-raise of the elicitation finding.
2. **REPAIR-INTRODUCED.** The finding sits in text that an earlier repair, fold or amendment wrote.
   Either the finding body attributes that text to one (read, not regex-matched), or the span arm
   holds: every backtick or double-quoted span of 12 or more characters in the finding body that
   occurs in the text the round read is absent from the authored text, and there is at least one.
3. **UNIQUE-SURVIVED.** Every `grep -c -F` token that the finding's repair blocks run against a story
   file is in that story at the stories gate, and not every one was already in the text the round
   read. Where a repair runs no story-targeted `grep -c -F`, its other `grep -c -F` tokens are
   checked against the whole shipped story set. A repair block is every block of a repair record
   whose `- source:` names the finding, including a block naming several findings.
4. **UNIQUE-unverified.** Otherwise: the repair carries no token, or only some of its tokens
   reached the stories gate. It is not counted as a survivor.

Steps 2 to 4 are computed by the classifier; steps 1 and 2's attribution reading are manual
judgments, listed in the per-finding table.

## Inputs

| Input | Graph source |
|---|---|
| Text the round read | the 25 stories at e6f964de8 (party repair adjudicated and sealed). Every shard's `artifact_sha` equals the sha256 of its story at e6f964de8, 25 of 25; the control, the authored text at 01f3925ec, matches 0 of 25 |
| Authored (base) text | the 25 stories at 01f3925ec ("epics and 25 story files authored"). The readiness correction c3c00660f and the party repair lie between it and the read text |
| Shards | `shards/stories-elicitation/01.md` to `25.md` and `cross.md` |
| Repair records | `shards/stories-elicitation-repair-p1/<n>.md` (25) and `stories-elicitation-serial-repair-p1.md` (6 lanes and the fan-in block that repaired `cross.md`) |
| Shipped text | the stories at 41484a513, "gate story passed", on `ai-dlc/feature/per-chain-rebalancer-instances`: the s321 analogue of s319's story gate log commit ccf7db999 |
| Later passes | `shards/stories-p1/`, `stories-p2/`, `stories-p3/` (26 shards each) |

Order, from the round returns' epochs (`rounds/*.return`), 2026-11-04 UTC: party repair 08:22:44,
elicitation 11:34:34, elicitation repair 13:42:37, its serial lanes 13:53:33, adversarial p1 17:32:47,
p2 19:11:03, p3 19:35:09. So s321's single elicitation round sits where s319 r1 sat: after the party
round, before the adversarial passes.

## Control: s319 r1 re-classified with this method

The study lists its REFOUND and UNIQUE-SURVIVED findings by id but not its REPAIR-INTRODUCED or
UNIQUE-unverified ones, so three bins are comparable: REFOUND, UNIQUE-SURVIVED and other. Inputs were
pinned the same way: s319 r1's 19 per-story shards match the stories at e802b8ccd by `artifact_sha`,
19 of 19; base ce821df7b; repairs at 91d0e2f65; shipped ccf7db999; later passes `stories-p1`,
`stories-p2` and the r2 round.

Sample: r1 shards 05, 12, 15 and 19 (per-story) and cross-2 and cross-4 (cross), 27 findings. They
cover all three bins, and 19 holds the study's hard case, 19#F-1.

| Sample | Findings | Agree |
|---|---|---|
| per-story (05, 12, 15, 19) | 20 | 19 |
| cross (cross-2, cross-4) | 7 | 4 |
| **all** | **27** | **23** |

The four disagreements:

| Finding | Study | This method | Why |
|---|---|---|---|
| r1 12#E-3 | other | UNIQUE-SURVIVED | its token survives at ccf7db999, no attribution, span arm 2 of 4; p1 12#F-1 flaws the repair's own text, so it is not a re-raise |
| r1 cross-2#F-2 | other | UNIQUE-SURVIVED | repaired by one block whose `- source:` names cross-2#F-2 and cross-4#F-2; its story token survives |
| r1 cross-4#F-2 | other | UNIQUE-SURVIVED | the same shared block; its own block carries only a `grep -n -o` line |
| r1 cross-4#F-3 | REFOUND | UNIQUE-SURVIVED | r1 is the TYPE of `pairs[].chain_id` against 4.4; r2 cross-4#F-1 is 3.1 adopting 4.3's key without its unresolved-chain guard, a different failure mode |

A second control over the whole s319 r1 per-story set: of the 44 findings not on the study's
REFOUND list, the mechanical arms (tokens survive, span arm does not hold, no attribution phrase)
predict 15 survivors against the study's 14, and agree on 43 of 44. The one difference is 12#E-3.

Every disagreement makes this method count MORE survivors than the study. s321 has 3 multi-source
`- source:` lines; the only finding they name as a non-first source, 02#F-3, is UNIQUE-unverified
here, so the shared-block reading moves s321 by at most one survivor.

## Yield (MAJOR+, after reading)

| Round | Shard type | C/M | REFOUND | REPAIR-INTRODUCED | UNIQUE-SURVIVED | UNIQUE-unverified |
|---|---|---|---|---|---|---|
| s319 r1 (study) | per-story | 54 | 10 | 22 | 14 | 8 |
| s319 r1 (study) | cross group | 14 | 7 | 2 | 2 | 3 |
| s319 r2 (study) | per-story | 22 | 3 | 3 | 12 | 4 |
| s319 r2 (study) | cross group | 4 | 3 | 1 | 0 | 0 |
| s321 | per-story | 84 | 9 | 28 | **36** | 11 |
| s321 | one cross shard (`cross.md`) | 3 | 2 | 1 | **0** | 0 |

## Summary: cost per unique survivor

Dollars are `elicitation_yield.py`'s, API-list-equivalent at opus rates, from a `spawns.jsonl`
extraction whose four s319 control cells print MATCH against the study (r1 per-story 54 and $40.89,
r1 cross 14 and $32.19, r2 per-story 22 and $34.58, r2 cross 4 and $18.94).

| Round | Shard type | Shards | Spawns | C/M | Unique survived | $ | $ per survivor | Reading |
|---|---|---|---|---|---|---|---|---|
| s319 r1 (study) | per-story | 19 | 19 | 54 | 14 | $40.89 | $2.92 | study |
| s319 r1 (study) | cross group | 6 | 6 | 14 | 2 | $32.19 | $16.09 | study |
| s319 r2 (study) | per-story | 20 | 20 | 22 | 12 | $34.58 | $2.88 | study |
| s319 r2 (study) | cross group | 6 | 6 | 4 | 0 | $18.94 | none survived | study |
| s320 (study, provisional) | per-story | 13 | 13 | 25 | 6 | $22.57 | $3.76 | study |
| s320 (study, provisional) | cross group | 6 | 6 | 11 | 1 | $24.32 | $24.32 | study |
| s321 | per-story | 25 | 36 | 84 | 36 | $111.55 | $3.10 | s321 per-story shards: 36 unique survivors at $3.10 each |
| s321 | one cross shard | 1 | 2 | 3 | 0 | $11.33 | none survived | s321 cross shard: no unique survivor |
| s321 | both | 26 | 38 | 87 | 36 | $122.88 | $3.41 | s321 elicitation shards: $3.41 per unique survivor |

Like for like: this method counts 15 survivors on s319 r1's per-story shards where the study counts
14 (the second control above), which is $40.89 / 15 = $2.73 per survivor against s321's $3.10.

The 36 per-story spawns over 25 shards include the re-dispatches after the handoff stop (graph
179705412, "elicitation round 14 of 26 delivered, 12 stopped at handoff"), so $3.10 carries the cost
of one interrupted round. The figure is not adjusted for it.

The CRITICAL findings: six were raised, all by per-story shards. 17#F-1 (AC1's DOM-node identity
assertion cannot pass) is a unique survivor. 16#F-1 was raised by the cross shard as well (REFOUND),
and 03#F-1, 03#F-2, 22#F-1 and 23#E-1 sit in text the party repair wrote.

Sensitivity. Taking the attribution arm mechanically, as the s319 second control does, instead of by
reading, adds three REPAIR-INTRODUCED findings (02#F-5, 06#F-1 and 13#F-4b, whose bodies name a
repair record or an amendment rule without attributing the defect's text to it) and gives 33
survivors, $3.38 each. Measuring survival at graph HEAD instead of the stories gate gives 35 (06#F-2's
token is gone at HEAD).

## Elicitation's own cost, and the step's

From the same `spawns.jsonl`, every stories-test-strategy spawn whose description carries "licit":
s319 (20 stories) 45 spawns, $95.27, $4.76 per story (adversary 25, $73.08; remediator 20, $22.19).
s321 (25 stories) 70 spawns, $149.07, $5.96 per story (adversary 38, $122.88; remediator 32, $26.19).
Elicitation per story ROSE within the step. s319's second round ran inside gate[stories-test-strategy]
(47 spawns, $66.97): its adversary $53.52 is r2's $34.58 + $18.94, as the step's $73.08 is r1's $40.89
+ $32.19. Counting the gate as well gives s319 92 spawns, $162.23, $8.11 per story, which reproduces
BL-811's filed 92 for $162; s321 has no elicitation spawn in the gate. That mixed population is not
the step's, and `roll.py` reports the gate as its own step, s319 $4.3 and s321 $0.2 per story.

The stories-test-strategy step, `roll.py --seats` per story: s319 0.78 h gap-inclusive, token-equivalent
$25.0 (API $25.0), 42.7M tokens; s321 0.79 h gap-inclusive, token-equivalent $26.9 (API $26.1), 47.5M
tokens. The step rose and its elicitation rose with it. The two are priced by different scripts, so
no share of the rise is assigned to elicitation. BL-812's reading (b) puts the rise in the per-story
and per-part shards and the repairs; elicitation and the adversarial passes p1 to p3 with their
repairs are both inside that, and this reading does not split it between them.

## Verdict

| Element | s321 unique survived | $ per survivor | Verdict |
|---|---|---|---|
| Per-story elicitation shards | 36, including the one surviving CRITICAL | $3.10 (s319 $2.92 and $2.88) | **Keep**: the yield per dollar is the s319 yield the study kept |
| The one cross-story shard | 0: 2 of 3 REFOUND by per-story shards, 1 REPAIR-INTRODUCED | $11.33, none survived | NOTE: no unique survivor on s321 |

## Per-finding classification

Evidence paths are graph paths under `_bmad-output/planning-artifacts/s321/`; "at 41484a513" is the
stories gate, "at e6f964de8" the text the round read.

| Story | Shard | Finding | Heading | Class | Evidence |
|---|---|---|---|---|---|
| 1.1 | `01.md` | F-1 | F-1 — MAJOR — The capture prerequisite names no read path, output path or tick-sequence, and AC2's per-type floor can only be met by dev-composed inputs | REPAIR-INTRODUCED | span arm: 2/2 quoted spans of the read text absent from `stories/story-1-1-feasibility-gate-and-matic-replay-fixture.md` at 01f3925ec |
| 1.1 | `01.md` | F-2 | F-2 — MAJOR — The replay's engine construction and per-tick state seeding are unspecified, and the golden depends on both | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/1.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 1.1 | `01.md` | F-3 | F-3 — MAJOR — "action type and range" is not a defined oracle: `ProposedAction` carries a list of ranges plus layers, trigger, priority and deployed ranges | REPAIR-INTRODUCED | span arm: 2/2 quoted spans of the read text absent from `stories/story-1-1-feasibility-gate-and-matic-replay-fixture.md` at 01f3925ec |
| 1.1 | `01.md` | F-4 | F-4 — MAJOR — The provenance-sha assertion cannot reject a golden regenerated from modified code, yet AC2 and the LR to AC map claim it does | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/1.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 1.1 | `01.md` | F-5 | F-5 — MAJOR — The named gap says AC5 observes the five non-emitting execution types in Story 5.6, but AC5 and Story 5.6 AC2 observe only SWEEP of them | REFOUND | later: `shards/stories-p1/01.md` F-1 and `shards/stories-p1/cross.md` F-1, 1.1's observed-types claim still contradicts 5.6 |
| 1.2 | `02.md` | F-1 | F-1 — MAJOR — AC2 and AC7 pull in opposite directions on `decision.py` `_get_pool_cfg`: AC2 forbids a by-`pool_id` lookup from gaining the predicate, AC7 requires this very lookup to read the selector (introduced by the R-5 repair) | REPAIR-INTRODUCED | finding body: AC7 text is the R-5 party repair |
| 1.2 | `02.md` | F-2 | F-2 — MAJOR — AC1's mandated `importlib.reload` mechanism carries no restoration step, so one test's `INSTANCE_CHAIN` and re-created exception classes leak into every later test in the same xdist worker | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/2.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 1.2 | `02.md` | F-3 | F-3 — MAJOR — AC2's "exactly one recipe match that is not a config-pool loop" is false: `api.py` 1581 is a second one, so the "51 rows" count and the guard test's allowlist are wrong by construction | UNIQUE-unverified | `shards/stories-elicitation-repair-p1/2.md`, `stories-elicitation-serial-repair-p1.md`: 2/3 tokens in `stories/` at 41484a513 |
| 1.2 | `02.md` | F-4 | F-4 — MAJOR — AC6's "unparseable value prints `db=unknown`" has no parse rule; the obvious `urlparse(...).path` implementation prints the raw value and a DSN password | REPAIR-INTRODUCED | span arm: 1/1 quoted spans of the read text absent from `stories/story-1-2-instance-chain-selector-and-predicate.md` at 01f3925ec |
| 1.2 | `02.md` | F-5 | F-5 — MAJOR — AC3 attributes its behaviour to an operator answer with a quote but no locator | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/2.md`, `stories-elicitation-serial-repair-p1.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 1.2 | `02.md` | F-6 | F-6 — MAJOR (underived) — "52 test modules import the config module" is a count asserted with no derivation | REPAIR-INTRODUCED | span arm: 1/1 quoted spans of the read text absent from `stories/story-1-2-instance-chain-selector-and-predicate.md` at 01f3925ec |
| 1.2 | `02.md` | F-12 | F-12 — MAJOR — AC7 requires new test code in `test_s321_matic_replay.py`, a file the story neither owns nor assigns to its new test file (introduced by the R-5 repair) | REPAIR-INTRODUCED | finding body: introduced by the R-5 repair |
| 1.3 | `03.md` | F-1 | F-1 — CRITICAL — AC2 asserts the wallet stub `call_count == 1` on a fixture that carries no wallet, so the AC cannot pass | REPAIR-INTRODUCED | finding body: fan-in/party edit added the wallet stub |
| 1.3 | `03.md` | F-2 | F-2 — CRITICAL — AC3(3) demands `_check_aggregator` `call_count == 0` on Base, contradicting Story 1.2's repaired gate, and AC1/AC2 stub no aggregator check | REPAIR-INTRODUCED | finding body: contradicts Story 1.2's repaired gate (serial repair E-1) |
| 1.3 | `03.md` | F-3 | F-3 — MAJOR — The named boot harness `_make_storage_mock()` cannot run `RebalancerApp.startup()`, and the story forbids a second harness | REPAIR-INTRODUCED | finding body: fan-in edit named the one boot harness |
| 1.3 | `03.md` | F-4 | F-4 — MAJOR — The zero-`sign_transaction` observables (AC1(d), the enable window, AC3(4)) have no live control and the signer seam can be silently overwritten | REFOUND | later: `shards/stories-p1/03.md` F-1, the zero-`sign_transaction` legs still cannot fail |
| 1.3 | `03.md` | F-5 | F-5 — MAJOR — AC4's `insert_execution call_count == 0` control is dead for the direct-call cases, and case (c) names no fixture that reaches the refusal | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/3.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 1.3 | `03.md` | F-6 | F-6 — MAJOR — Story 5.3 AC5 imports "Story 1.3's boot helper", but Story 1.3 names, specifies and exports no such helper | REFOUND | same round: `shards/stories-elicitation/cross.md` F-3 and `shards/stories-elicitation/20.md` F-2 |
| 1.4 | `04.md` | F-1 | F-1 — MAJOR — AC4 flips the FAIL assertions in `test_safeguards.py` but leaves its two PASS assertions vacuous | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/4.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 1.4 | `04.md` | F-2 | F-2 — MAJOR — Story line 108 hands the deployed S9 observation to Story 5.6, which has no S9 content | REFOUND | same round: `shards/stories-elicitation/23.md` E-6 |
| 1.5 | `05.md` | F-1 | F-1 — MAJOR — AC2 and AC5 cannot be run as written: the "Storage never stubbed" rule meets a hardcoded TLS pool and the TLS shim is prescribed only for AC1's children | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/5.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 1.5 | `05.md` | F-2 | F-2 — MAJOR — The "no production file edited" gate omits `rebalancer/state_machine.py`, the file that owns AC3's read, so a red AC3 has no stop rule and no diff guard | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/5.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 1.6 | `06.md` | F-1 | F-1 — MAJOR — An existing green test reds with no owner and no amendment: `test_ac1_d_second_pool_control_runs_in_its_own_chain_context` | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/6.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 1.6 | `06.md` | F-2 | F-2 — MAJOR — AC5 asserts "`config/rebalancer-base.yaml` is not tracked at this commit" with no derivation | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/6.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 2.1 | `07.md` | F-1 | F-1 — MAJOR — AC3 leaves the `bounded` disposition of the burn and collect `_build_tx_payload` sites undefined, and its literal wording yields false "no read exists" results | UNIQUE-unverified | `shards/stories-elicitation-repair-p1/7.md`: no `grep -c -F` token |
| 2.1 | `07.md` | F-2 | F-2 — MAJOR — The seven FR-S321-13 (5) sender rows and the dust-sweep row have no criterion for `bounded=yes` | UNIQUE-unverified | `shards/stories-elicitation-repair-p1/7.md`: no `grep -c -F` token |
| 2.1 | `07.md` | F-6 | F-6 — MAJOR — AC1 anchors FR-S321-13 input (4), the offramp raw `balanceOf` sizing, at a read that is not the Step 1 sizing and is two-hop only | REPAIR-INTRODUCED | span arm: 1/1 quoted spans of the read text absent from `stories/story-2-1-reserve-audit-report-and-pinned-span-findings.md` at 01f3925ec |
| 2.1 | `07.md` | F-3 | F-3 — MAJOR — The AC1 row-count predicate counts every backticked first cell, but AC1 and AC3 invite further tables | REPAIR-INTRODUCED | span arm: 1/1 quoted spans of the read text absent from `stories/story-2-1-reserve-audit-report-and-pinned-span-findings.md` at 01f3925ec |
| 2.2 | `08.md` | F-1 | F-1 — MAJOR — AC6 control spy cannot be built as written, and its refusal assertion can pass for the wrong reason | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/8.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 2.3 | `09.md` | F-1 | F-1 — MAJOR — AC2/AC3 leave the bound site and the test entry point open (same-pool vs top of `_execute_swap`), so the one-time bound can be built twice or the swap rows can be driven at the wrong entry | UNIQUE-unverified | `shards/stories-elicitation-repair-p1/9.md`: 0/2 tokens in `stories/` at 41484a513 |
| 2.3 | `09.md` | F-2 | F-2 — MAJOR — The AC3 completeness check (test row list equals the audit's bounded:no list) names no command and no audit path | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/9.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 2.3 | `09.md` | F-3 | F-3 — MAJOR — AC5 asserts "the only `value` source in `_build_tx_payload` is `_native_value`, a mint-step input" with no derivation | UNIQUE-unverified | `shards/stories-elicitation-repair-p1/9.md`: no `grep -c -F` token |
| 2.4 | `10.md` | F-1 | F-1 — MAJOR — No AC asserts that Step 1 delegates to the helper, so an inlined read that maps an empty balance to 0 passes every AC | UNIQUE-unverified | `shards/stories-elicitation-repair-p1/10.md`: no `grep -c -F` token |
| 2.4 | `10.md` | F-2 | F-2 — MAJOR — AC4's live-mode "sizes exactly X" and "exactly 1" cases name no observable and no chain context that can read one | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/10.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 3.1 | `11.md` | F-2 | F-2 — MAJOR — "a reachable answer that is not `data: null` counts busy" is ambiguous for a 200 body with no `data` key or with `ok: false`; the kept helper `rb_idle_from_json` reads those idle, and `ecs-deploy.sh` today reads a missing `.data` as abort | UNIQUE-unverified | `shards/stories-elicitation-repair-p1/11.md`: no `grep -c -F` token |
| 3.1 | `11.md` | F-3 | F-3 — MAJOR — the default record path "beside the repo root" has no resolution rule, and no AC case runs the default path | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/11.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 3.1 | `11.md` | F-4 | F-4 — MAJOR — AC2(g) "adds no probe timeout" drops the `--max-time 10` bound that `ecs-deploy.sh` has today, and the story neither prices that change nor assigns it to Story 3.3 | REPAIR-INTRODUCED | span arm: 1/1 quoted spans of the read text absent from `stories/story-3-1-absence-record-and-both-idle-helper.md` at 01f3925ec |
| 3.3 | `13.md` | F-1 | F-1 — MAJOR — Items 1-5 and 7-8 all need to enumerate the record (id, ecs_fragment, absent, url_env), but no story owns a reader and 3.1's fixed interface offers none | UNIQUE-unverified | `shards/stories-elicitation-repair-p1/13.md`: no `grep -c -F` token |
| 3.3 | `13.md` | F-2 | F-2 — MAJOR — Check-13 `grep -i "rebalancer" \| head -1` at smoke line 3441 is a fifth substring resolver that AC4's gate-5.6 discharge fence and the Rename Verification do not list | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/13.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 3.3 | `13.md` | F-3 | F-3 — MAJOR — Retention script: the Cloud Map host is to be "parsed from the instance's `url_env`", but `url_env` names an environment variable that is unset on the operator host where this script runs, and the test host assertions have no source | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/13.md`: 2/2 tokens in `stories/` at 41484a513, 1 at e6f964de8 |
| 3.3 | `13.md` | F-4 | F-4 — MAJOR — The `rc 0` controls for `ecs-switch-preset.sh` (AC2 control, item 6 control) cannot be observed offline: the script has no DRY_RUN/seam, the idle gate sits at the top of a 997-line, 53-`aws`-call, multi-`sleep` script that ends in a real smoke run | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/13.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 3.3 | `13.md` | F-4b | F-4b — MAJOR — Where `rb_all_idle` runs in `ecs-deploy.sh` is contradictory: AC1 item 1 puts the `update-service` calls "immediately after `rb_all_idle` passes", while the AC1 and AC3 sentinel cases need the check before the `DRY_RUN` exit at line 181 | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/13.md`, `stories-elicitation-serial-repair-p1.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 3.4 | `14.md` | F-1 | F-1 — MAJOR — AC1 leaves a probe thread that dies on an exception outside its three "unreachable" classes unclassified | REPAIR-INTRODUCED | span arm: 1/1 quoted spans of the read text absent from `stories/story-3-4-execution-state-gate-lambda-probes-both-instances.md` at 01f3925ec |
| 3.4 | `14.md` | F-2 | F-2 — MAJOR — `PROBE_DEADLINE_SECS` has no production value and "joins each thread against" it is not pinned to a shared deadline | REPAIR-INTRODUCED | span arm: 3/3 quoted spans of the read text absent from `stories/story-3-4-execution-state-gate-lambda-probes-both-instances.md` at 01f3925ec |
| 3.4 | `14.md` | F-3 | F-3 — MAJOR — the AC1 barrier stub and the AC2 never-set Event stub hang the pytest process, so the "red" states and the green state are not the stated ones | REPAIR-INTRODUCED | span arm: 1/1 quoted spans of the read text absent from `stories/story-3-4-execution-state-gate-lambda-probes-both-instances.md` at 01f3925ec |
| 3.4 | `14.md` | F-5 | F-5 — MAJOR — the production default record path is never exercised, and an unreadable record is silent by design | REFOUND | later: `shards/stories-p1/14.md` F-1, the unreadable-record arm |
| 3.4 | `14.md` | F-6 | F-6 — MAJOR (underived) — AC4 says "the existing file sets no environment, derived below" and no derivation follows | UNIQUE-unverified | `shards/stories-elicitation-repair-p1/14.md`: no `grep -c -F` token |
| 4.1 | `15.md` | F-1 | F-1 — MAJOR — AC8's verification command is anchored on the shared sprint branch's merge-base, so it fails once any earlier story lands | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/15.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 4.2 | `16.md` | F-1 | F-1 — CRITICAL — The shared-helper import (FI-F10) breaks the Lambda bundle, and the story's "no runtime effect" claim is false for a module-level import | REFOUND | same round: `shards/stories-elicitation/cross.md` F-1 |
| 4.2 | `16.md` | F-2 | F-2 — MAJOR — The story puts the Base dead-man emission in `_handle_rebalancer_down`, a method reached only when Matic is unreachable, so AC3's primary case cannot pass as placed | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/16.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 4.2 | `16.md` | F-3 | F-3 — MAJOR — The Base grace window is unspecified and no fixture discriminates it | UNIQUE-unverified | `shards/stories-elicitation-repair-p1/16.md`: no `grep -c -F` token |
| 4.3 | `17.md` | F-1 | F-1 — CRITICAL — AC1's DOM-node-identity assertion cannot pass: `RebalancerPage` returns null while inactive, so the Backtest tab node is destroyed and re-created on every round trip | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/17.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 4.3 | `17.md` | F-2 | F-2 — MAJOR — Existing tests outside the story's owned paths and outside AC8's lists break on the nav change, so AC8's "the full vitest run passes" is unsatisfiable under the Routing paths | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/17.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 4.3 | `17.md` | F-5 | F-5 — MAJOR — "5 in the other four modules" is contradicted by the story's own fence: the derived output sums to 6 | REPAIR-INTRODUCED | span arm: 5/5 quoted spans of the read text absent from `stories/story-4-3-rebalancer-matic-and-base-pages.md` at 01f3925ec |
| 4.3 | `17.md` | F-9 | F-9 — MAJOR — The Mechanism paragraph leaves the delivery of `apiSegment` to the ~35 non-hook request sites unspecified, though it exists "so the dev does not choose" | REPAIR-INTRODUCED | span arm: 2/2 quoted spans of the read text absent from `stories/story-4-3-rebalancer-matic-and-base-pages.md` at 01f3925ec |
| 5.1 | `18.md` | F-1 | MAJOR — F-1 — AC9 can be built two ways, contradicts AC1's "identical" clause, and its control cannot go RED | REPAIR-INTRODUCED | span arm: 13/13 quoted spans of the read text absent from `stories/story-5-1-base-ecs-service-in-cdk.md` at 01f3925ec |
| 5.1 | `18.md` | F-2 | MAJOR — F-2 — AC4's default record read (the production path) is never exercised, and fails closed to a green result | REPAIR-INTRODUCED | span arm: 5/5 quoted spans of the read text absent from `stories/story-5-1-base-ecs-service-in-cdk.md` at 01f3925ec |
| 5.2 | `19.md` | F-1 | F-1 — MAJOR — AC1's wiring evidence names "the real Base service name" in the `cdk diff`, but that value is a CloudFormation import token and nothing in jest exercises `infra/bin/graph.ts`, so a swapped wiring passes every named check | REFOUND | later: `shards/stories-p1/19.md` F-1, AC1's wiring guard read from a `cdk diff` that cannot show it |
| 5.2 | `19.md` | F-2 | F-2 — MAJOR — AC1 asserts "All 6 rebalancer-log-group `AWS::Logs::MetricFilter` resources" and a log-group count of 6 with the enumeration given but no derivation of the 6 | REPAIR-INTRODUCED | span arm: 6/6 quoted spans of the read text absent from `stories/story-5-2-base-service-alarm-and-monitoring-pins.md` at 01f3925ec |
| 5.3 | `20.md` | F-1 | F-1 — MAJOR — AC4 requires stdout to carry the bytes read back, but the AC3 seam names no stub that can deliver them | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/20.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 5.3 | `20.md` | F-2 | F-2 — MAJOR — AC5 imports a "boot helper" from Story 1.3 that Story 1.3 never names, signs for, or makes parameterizable by config path | REFOUND | same round: `shards/stories-elicitation/03.md` F-6 and `shards/stories-elicitation/cross.md` F-3 |
| 5.4 | `21.md` | F-1 | F-1 — MAJOR — Default `cdk diff` includes dependency stacks, so AC4's "none of the eight in the CicdStack and MonitoringStack captures" cannot hold, and the deploy command and stack list are unspecified | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/21.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 5.4 | `21.md` | F-2 | F-2 — MAJOR — AC5's "listed" and the drop-one fixture are undefined, and the section's required prose can defeat the drop-4.1 case | REPAIR-INTRODUCED | span arm: 2/2 quoted spans of the read text absent from `stories/story-5-4-operator-preconditions-staged-not-run.md` at 01f3925ec |
| 5.4 | `21.md` | F-3 | F-3 — MAJOR — Routing says the checker covers AC1 to AC3, but AC4 also asserts "the checker" and has no Strategy Test IDs row | REPAIR-INTRODUCED | span arm: 5/5 quoted spans of the read text absent from `stories/story-5-4-operator-preconditions-staged-not-run.md` at 01f3925ec |
| 5.4 | `21.md` | F-4 | F-4 — MAJOR — AC3's fixtures need the staged command executed against a stubbed `aws`, and no seam is defined | REPAIR-INTRODUCED | span arm: 3/3 quoted spans of the read text absent from `stories/story-5-4-operator-preconditions-staged-not-run.md` at 01f3925ec |
| 5.4 | `21.md` | F-5 | F-5 — MAJOR — AC6's content clause has no check and collides with R3-RUNNING | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/21.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 5.5 | `22.md` | F-1 | F-1 — CRITICAL — AC4 requires "zero skipped" for a test file that skips 4 tests on every run | REPAIR-INTRODUCED | finding body: git log -S prints only e6f964de8, the party repair commit |
| 5.5 | `22.md` | F-2 | F-2 — MAJOR — AC1 and AC2 key on fixed line numbers (77, 10) while AC7 adds an entry the story lets land two ways | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/22.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 5.5 | `22.md` | F-3 | F-3 — MAJOR — AC6's closed path list excludes the status file the dev contract requires the dev to update | REPAIR-INTRODUCED | span arm: 1/1 quoted spans of the read text absent from `stories/story-5-5-restage-base-entry-router-carry-over.md` at 01f3925ec |
| 5.5 | `22.md` | F-4 | F-4 — MAJOR — The AD-4 / "operator answer D-1" attribution carries neither the operator's words nor a locator | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/22.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 5.5 | `22.md` | F-5 | F-5 — MAJOR — "none contains the old value literal" is asserted for three files and derived for one | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/22.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 5.6 | `23.md` | E-1 | E-1 — CRITICAL — AC2's SWEEP leg can never discharge: no component writes an organic SWEEP row | REPAIR-INTRODUCED | finding body: organic filter rests on party serial repair R-10 |
| 5.6 | `23.md` | E-2 | E-2 — MAJOR — Per-AC state vocabulary has no failure state, so a real RED cannot be recorded | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/23.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 5.6 | `23.md` | E-3 | E-3 — MAJOR — The "deploy timestamp" is used with two meanings, and AC2 mislabels `createdAt` as a completion time | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/23.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 5.6 | `23.md` | E-4 | E-4 — MAJOR — AC2's "digest that `scripts/ecs-deploy.sh rebalancer` pushed" has no recorded source | REPAIR-INTRODUCED | span arm: 2/2 quoted spans of the read text absent from `stories/story-5-6-observe-base-running-matic-succeeding.md` at 01f3925ec |
| 5.6 | `23.md` | E-5 | E-5 — MAJOR — AC3's "matched whole" boot-line check is unimplementable against JSON log events | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/23.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 5.6 | `23.md` | E-6 | E-6 — MAJOR — Story 1.4 hands the deployed S9 observation to this story; no AC here reads it, and the Story 5.2 alarm is a Dependency that nothing observes | REFOUND | same round: `shards/stories-elicitation/04.md` F-2 |
| 5.6 | `23.md` | E-7 | E-7 — MAJOR — Story 1.1 AC5 assigns this story the AC2 observation window and a sha-pinned fence; this story supplies neither | UNIQUE-unverified | `shards/stories-elicitation-repair-p1/23.md`, `stories-elicitation-serial-repair-p1.md`: 1/3 tokens in `stories/` at 41484a513 |
| 6.1 | `24.md` | F-1 | F-1 MAJOR: AC2's "bare `rebalancer` label fails" clause fails the only recorded read it tells the report to cite | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/24.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 6.1 | `24.md` | F-2 | F-2 MAJOR: AC4's command allow-list refuses commands the permitted reads need, and "the session's command log" is undefined | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/24.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 6.1 | `24.md` | F-3 | F-3 MAJOR: AC1's three states overlap, so "exactly one state" is undecidable for the five named capabilities, and "missing" does not fit the router row | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/24.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 6.1 | `24.md` | F-4 | F-4 MAJOR: AC1's universe omits four OPEN Base-specific CO-S317 carry-over items that the backlog lists beside the CO-S316 set | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/24.md`, `stories-elicitation-serial-repair-p1.md`: 1/1 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 6.2 | `25.md` | (no id) AC3's token check has | MAJOR — AC3's token check has three readings; two break and the planted-token control cannot fail | REPAIR-INTRODUCED | span arm: 3/3 quoted spans of the read text absent from `stories/story-6-2-claude-md-covers-both-instances.md` at 01f3925ec |
| 6.2 | `25.md` | (no id) AC1 does not say how t | MAJOR — AC1 does not say how the added lines are split by place, so its negative fixture can pass when it must fail | UNIQUE-SURVIVED | `shards/stories-elicitation-repair-p1/25.md`: 3/3 tokens in `stories/` at 41484a513, 0 at e6f964de8 |
| 4.2 | `cross.md` | F-1 | F-1 — MAJOR — Story 4.2's byte-identical Lambda mirror imports a helper that the Lambda bundle does not contain | REFOUND | same round: `shards/stories-elicitation/16.md` F-1 |
| 5.1, 1.5 | `cross.md` | F-2 | F-2 — MAJOR — Story 5.1 AC9 pins an FR-S321-5 clause but 5.1's trace never carries FR-S321-5 or LR-S321-4, and Story 1.5 still says the clause is routed to the lead | REPAIR-INTRODUCED | finding body: party adjudication added 5.1 AC9 without its trace |
| 5.3, 1.3 | `cross.md` | F-3 | F-3 — MAJOR — Story 5.3 AC5 imports "Story 1.3's boot helper", a symbol Story 1.3 never names or promises | REFOUND | same round: `shards/stories-elicitation/03.md` F-6 and `shards/stories-elicitation/20.md` F-2 |
