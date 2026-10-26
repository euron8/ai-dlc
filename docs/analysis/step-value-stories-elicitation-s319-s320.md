# Step value — stories elicitation, per-story shards against cross-group shards (BL-811)

Measured for batch 243 on graph's s319 and s320 stories elicitation rounds, read only. It applies the
same ruling as `step-value-s317-s319.md`: an element is kept on a named failure case plus catches no
other round makes that survive to the shipped artifact, rare high-consequence catches are judged on
consequence, and every figure states dollars.

**s320 is PROVISIONAL throughout.** Its stories gate has not passed, so nothing in it has shipped and
its survival column is measured against the working tree. Every s320 figure below carries
"(provisional)". The verdict rests on s319.

## Round structure

| Round | Text it read | Shards | Record |
|---|---|---|---|
| s319 r1 | the authored stories, before adversarial p1 | 19 ordinals + 6 cross groups (`cross/19 g<g>/6`) | archived at graph `91d0e2f65` (elicitation round and repair), 2026-10-20 |
| s319 r2 | the stories after p1 and p2 converged (`b652377a8`, EXIT_CONDITION_MET), the post-MET amendments, and amendment p5 (`765de28f0`); story 2.3 split into 2.3a/2.3b | 20 ordinals + 6 cross groups (`cross/20 g<g>/6`) | graph `7abfe3b9e` (round K=20 and repair); shipped at the story gate log `ccf7db999` |
| s320 (provisional) | the authored stories | 13 ordinals + 6 cross groups | working tree `s320/shards/stories-elicitation/` |

Every cross-group shard in all three rounds notarized every story of its round in `artifact_sha`
(19, 20 and 13 `<stem>=<sha>` entries): a cross group's pairs were its FOCUS, never its read set.

## Populations and sources

| Figure | Population | Source |
|---|---|---|
| Dollars, tokens, model | every `adversary` spawn of the round's elicitation window: s319 r1 2026-10-20T02 UTC, s319 r2 2026-10-20T22:4x UTC with `licit` in the description, s320 2026-10-26T06:05 UTC | BL-811 hand's extraction `bl811/out.Uphh/spawns.jsonl` and `units.jsonl` (graph transcripts under `~/.claude/projects/-Users-n8-git-graph/`), read by `bl811/yield.py`, `comp.py`, `sp.py`, `ctx.py` |
| Findings | every CRITICAL and MAJOR `### ` heading in every elicitation shard; MINOR not classified | `bl811/pin.volH/r1`, `pin.volH/r2` (pinned copies of the s319 shard dirs), graph `s320/shards/stories-elicitation/` |
| Repair and survival | the repair shards and joined repair record of each round; a fix survives when every `grep -c -F` token its repair record names is in the shipped stories and not all were already in the text the round read | `pin.volH/r1repair`, `r2repair`, `r1-joined-repair.md`, `r2-joined-repair.md`; shipped `pin.volH/stories-ccf7db999`; s320 (provisional) against the working tree `s320/stories/` |
| Story size | bytes of the story file the round read | `pin.volH/stories-pre-r1`, `stories-pre-r2`, `s320-authored` |

Controls, each in the same run:

- `final.py` classified 130 findings, and `yield.py`'s per-shard sum is 130.
- All 35 manual REFOUND keys matched a finding (`REF keys used 35 of 35`).
- Re-run for this document into a fresh directory, `final.py` reproduced the hand's
  `bl811-rows.json` byte for byte (`cmp` exit 0).

Definitions, as `step-value-s317-s319.md` uses them:

- **REFOUND:** another shard of the same round raised the same defect, or a later pass raised it.
  These are manual judgments, listed below.
- **REPAIR-INTRODUCED:** the finding sits in text a previous repair, fold or amendment wrote. It is
  detected by an attribution phrase in the finding, or, in s319, by every quoted span being absent
  from the base text and present in the text the round read.
- **UNIQUE-SURVIVED:** the finding is not REFOUND or REPAIR-INTRODUCED, and every token its repair
  names is in the shipped stories.
- **UNIQUE-unverified:** the finding is unique, but its repair carries no token or only a partial
  one. It is not counted as a survivor.

## Cost

| Round | Shard type | n | $ | $ cache write | $ cache read | $ output | $ per unique survivor |
|---|---|---|---|---|---|---|---|
| s319 r1 | per-story | 19 | $40.89 | $14.84 | $8.98 | $16.96 | $2.92 |
| s319 r1 | cross group | 6 | $32.19 | $9.25 | $6.55 | $16.36 | $16.09 |
| s319 r2 | per-story | 20 | $34.58 | $14.67 | $7.26 | $12.57 | $2.88 |
| s319 r2 | cross group | 6 | $18.94 | $7.80 | $3.98 | $7.14 | none survived |
| s320 (provisional) | per-story | 13 | $22.57 | $9.55 | $4.18 | $8.77 | $3.76 |
| s320 (provisional) | cross group | 6 | $24.32 | $7.50 | $4.49 | $12.30 | $24.32 |
| **all** | per-story | 52 | $98.05 | | | | **$3.06** |
| **all** | cross group | 18 | $75.45 | | | | **$25.15** |

Dollars are API-list-equivalent at opus rates (input 4, cache write 8, cache read 0.20, output 20
per M); the component sum reproduces each group's spawn total within one cent. Input tokens are under $0.12 per
group and are omitted.

### Model binding

| Sprint | Role | Bound | Ran | n |
|---|---|---|---|---|
| s319 | `adversary` (elicitation shard) | opus / medium | opus | 51 |
| s319 | `remediator` (elicitation repair) | sonnet / medium | sonnet | 41 |
| s320 (provisional) | `adversary` | opus / medium | opus | 19 |
| s320 (provisional) | `remediator` | sonnet / medium | sonnet | 25 |

Every spawn ran the model it was bound to.

### Context writes

The shards do not share one context write. Each spawn writes its own cache.

| Round | Type | n | Cache-write tokens | Cache-read tokens | Mean first-call context |
|---|---|---|---|---|---|
| s319 r1 | cross | 6 | 1,112,193 | 31,189,138 | 23,317 |
| s319 r1 | per-story | 19 | 1,789,134 | 42,652,699 | 23,047 |
| s319 r1 | repair | 20 | 1,725,566 | 35,135,527 | 45,729 |
| s319 r2 | cross | 6 | 952,631 | 18,707,988 | 24,173 |
| s319 r2 | per-story | 20 | 1,805,977 | 34,618,154 | 23,891 |
| s319 r2 | repair | 21 | 1,616,157 | 22,312,963 | 45,301 |
| s320 (provisional) | cross | 6 | 937,766 | 22,437,441 | 23,413 |
| s320 (provisional) | per-story | 13 | 1,193,828 | 20,892,058 | 23,473 |
| s320 (provisional) | repair | 25 | 2,073,038 | 31,158,253 | 45,223 |

The first call's shared prefix is about 23k tokens, so a shard's fixed write is about $0.14
(`comp.py`). A shard's cost is its own reading and writing, not a duplicated prefix.

## Yield (MAJOR+, after reading)

| Round | Shard type | C/M | REFOUND | REPAIR-INTRODUCED | UNIQUE-SURVIVED | UNIQUE-unverified |
|---|---|---|---|---|---|---|
| s319 r1 | per-story | 54 | 10 | 22 | **14** | 8 |
| s319 r1 | cross group | 14 | 7 | 2 | **2** | 3 |
| s319 r2 | per-story | 22 | 3 | 3 | **12** | 4 |
| s319 r2 | cross group | 4 | 3 | 1 | **0** | 0 |
| s320 (provisional) | per-story | 25 | 6 | 12 | **6** | 1 |
| s320 (provisional) | cross group | 11 | 5 | 3 | **1** | 2 |
| **all** | per-story | 101 | 19 (19%) | 37 | **32** | 13 |
| **all** | cross group | 29 | 15 (52%) | 6 | **3** | 5 |

On s319 alone, per-story shards carry 26 unique survivors and cross groups carry 2.

`final.py` prints `r1:19#F-1` as REFOUND. `yield.py` corrects it after reading: that finding is
the 5.4 instance, and adv p1 18#F-1 raised the 5.3 sibling, not this defect. With the correction the
per-story count is 32 and REFOUND is 34. Without it, the per-story count is 31.

### Unique survivors and their fix locations

The fix location is the story file and line the round's repair record edits (`story-<e>-<s>:<line>`).

| Finding | Sev | Fix | Defect |
|---|---|---|---|
| s319 r1 01#F-1 | M | 1-1:57 | AC3's HOT_RELOAD_EXCLUDED clause names a bare key, so it cannot go red for the `offramp` leaf |
| s319 r1 01#F-2 | M | 1-1:69 | AC7 lists two exclusions `git diff --name-only` cannot evaluate |
| s319 r1 02#F-1 | M | 1-2:75 | AC7's mirror escape clause passes against a page that never renders the label |
| s319 r1 04#E-1 | M | 1-4:60 | AC3's `latest_success` mutant survives a fixture where the skip row is not strictly newer |
| s319 r1 08#E-2 | M | 2-3:119-120 | AC9's HPE probe passes trivially if it runs before the deploy |
| s319 r1 09#E-1 | M | 3-1:85 | the spine's open-risk check of the pair set has no AC in its assigned story |
| s319 r1 12#E-8 | M | 4-1:73 | one staged command per chain, where one PUT carries all appends |
| s319 r1 14#F-2 | M | 4-3:106-108 | no AC covers the background claim raising; a failed claim polls as pending forever |
| s319 r1 15#E-2 | M | 4-4:88, 4-4:127 | no AC says whether the claim shares the Collect Fees state |
| s319 r1 15#E-3 | M | 4-4:117 | AC8's discharge predicate reads neither a receipt nor a destination |
| s319 r1 16#E-4 | M | 5-1:65 | AC1's fixture gloss is false: broadcast swap then failed transfer persists `PARTIAL` |
| s319 r1 18#F-2 | M | 5-3:61 | AC1 and AC2 do not partition the read outcomes on a `failed` unsub row |
| s319 r1 19#F-1 | M | 5-4:76 | AC3's zero-POST count reds every read the AC allows |
| s319 r1 19#F-4 | M | 5-4:67 | the operator quote at AC2 has no locator |
| s319 r1 cross-1#F-2 | M | 3-2:81, 3-3:65 | the USD total string's scale is not fixed between producer 3.1 and consumers 3.2, 3.3 |
| s319 r1 cross-4#F-1 | M | 3-1:85, 4-2:120 | 3.1 never says whether `claimable_raw` is the proof-bound amount 4.2 claims |
| s319 r2 05#F-1 | M | 1-5:46 | the `since=` audit bound compares local-offset time against `Z` UTC |
| s319 r2 06#F-1 | **C** | 2-1:80-81 | AC5 has no passing conclusion when both price keys miss |
| s319 r2 07#F-1 | M | 2-2:56 | the manual sum has no rule for mixed available and unavailable pools |
| s319 r2 08#F-2 | M | 2-3:31 | the `pool_state`/`subgraph_input`/`other` input fix ships under no AC |
| s319 r2 11#F-1 | M | 3-2:83, 3-3:65 | AC2's `empty` fixture does not pin `claimable_usd: null` |
| s319 r2 12#F-1 | M | 3-3:67-68 | AC2 has no `status: ok` zero-pending fixture |
| s319 r2 13#F-1 | M | 4-1:51-52 | AC2 never pins the constant's key type; `.get(<int>)` returns `None` |
| s319 r2 14#F-1 | M | 4-2:158-161 | no AC defines a broadcast claim whose receipt times out |
| s319 r2 17#F-1 | M | 5-1:71 | a dry-run SUCCESS skip row classifies PASS-skipped while AC1 refuses it |
| s319 r2 17#F-2 | M | 5-1:71 | the "row absent after the press" FAIL shape has no wait condition |
| s319 r2 18#F-1 | M | 5-2:91 | AC5's monitor closes when the button ships, before the claim is observed |
| s319 r2 20#F-1 | M | 5-4:72-73 | AC2 never fails on zero or one read |
| s320 01#F-2 (provisional) | M | 1-1:80, 108-109, 114 | the `"hodl":` token the fences key on is produced by no source line |
| s320 02#F-2 (provisional) | M | 1-2:112 | AC3's floor comparison is on a `->>` text operand with no numeric cast |
| s320 03#F-2 (provisional) | M | 1-3:108-109 | AC5's NON-FIRING-HEALTHY control accepts zero |
| s320 03#F-3 (provisional) | M | 1-3:53 | AC6 maps one case to SCORED-RED in Then and to an AC failure in the fixture |
| s320 08#F-1 (provisional) | M | 3-2:90 | AC2 and AC4 contradict on whether the control node fails |
| s320 13#F-1 (provisional) | **C** | 4-2:107 | AC8: a `""` `hodl_wallet` opens the typed modal with confirm enabled |
| s320 cross-4#F-3 (provisional) | M | 3-3:81 | 3.3 AC5 allows two pool-pnl ids red, 2.2 AC6 allows a third |

### REFOUND judgments

Manual, from reading the headings and bodies (`final.py` `REF`, with the `r1:19#F-1` correction).

| Finding | Sev | Kind | Raised also by |
|---|---|---|---|
| s319 r1 03#F-1 | M | later | s319 adv p1 03#F-1 |
| s319 r1 03#F-2 | M | later | r2 03#F-1 |
| s319 r1 04#E-2 | M | later | s319 adv p1 04#F-1, r2 04#F-1 |
| s319 r1 05#F-1 | C | later | s319 adv p1 05#F-1 |
| s319 r1 09#E-2 | M | later | r2 10#F-1 |
| s319 r1 12#E-1 | C | same round | r1 cross-2#F-4 (4.1 half) |
| s319 r1 13#E-1 | M | same round | r1 cross-2#F-1, 15#E-1 |
| s319 r1 13#E-2 | M | later | s319 adv p1 13#F-1 |
| s319 r1 15#E-1 | M | same round | r1 cross-2#F-1, 13#E-1 |
| s319 r1 17#F-1 | M | same round | r1 cross-3#F-3 |
| s319 r1 cross-2#F-1 | M | same round | r1 13#E-1, 15#E-1 |
| s319 r1 cross-2#F-3 | M | same round | r1 cross-3#F-1 (one repair block) |
| s319 r1 cross-2#F-4 | M | same round | r1 12#E-1 (4.1 half) |
| s319 r1 cross-3#F-1 | M | same round | r1 cross-2#F-3 |
| s319 r1 cross-3#F-3 | M | same round | r1 17#F-1 |
| s319 r1 cross-4#F-3 | M | later | r2 cross-4#F-1 |
| s319 r1 cross-6#F-1 | M | later | s319 adv p1 13#F-4, p2 13#F-1, r2 cross-6#F-1 |
| s319 r2 08#F-1 | C | same round | r2 09#F-1, cross-1#F-1 |
| s319 r2 08#F-3 | M | same round | r2 cross-1#F-2 |
| s319 r2 09#F-1 | M | same round | r2 08#F-1, cross-1#F-1 |
| s319 r2 cross-1#F-1 | C | same round | r2 08#F-1, 09#F-1 |
| s319 r2 cross-1#F-2 | M | same round | r2 08#F-3 |
| s319 r2 cross-6#F-1 | M | later | the r1 cross-6#F-1 / adv p1 13#F-4 lineage (4.2 AC12 / 5.2 monitor seam) |
| s320 03#F-1 (provisional) | M | later | s320 adv p1 cross-1#F-1 |
| s320 04#F-1 (provisional) | C | later | s320 adv p1 04#F-1 |
| s320 05#F-2 (provisional) | M | later | s320 adv p1 05#F-2, p2 05#F-1, p5 05#F-1 |
| s320 09#F-1 (provisional) | M | later | s320 adv p1 09#F-1 |
| s320 10#F-1 (provisional) | M | same round | s320 cross-2#F-2, cross-4#F-2 |
| s320 12#E-2 (provisional) | M | same round | s320 cross-6#F-1 |
| s320 cross-2#F-2 (provisional) | M | same round | s320 10#F-1, cross-4#F-2 |
| s320 cross-3#F-1 (provisional) | M | same round | s320 cross-5#F-1, cross-4#F-1 |
| s320 cross-4#F-1 (provisional) | M | same round | s320 cross-3#F-1, cross-5#F-1 |
| s320 cross-4#F-2 (provisional) | M | same round | s320 10#F-1, cross-2#F-2 |
| s320 cross-5#F-1 (provisional) | M | same round | s320 cross-3#F-1, cross-4#F-1 |

Of the 29 cross-group findings, 15 were re-raised. Most of those were raised by a sibling cross
group in the same round, because every group read the whole subject.

## Consequence (the guard clause)

- **CRITICAL unique survivors:** both came from per-story shards. They are s319 r2 06#F-1, where AC5
  has no passing conclusion when both price keys miss, and s320 13#F-1 (provisional), where an empty
  `hodl_wallet` opens the confirm modal already enabled.
- **CRITICALs raised by a cross group:** one, s319 r2 cross-1#F-1, the 2.3a/2.3b grading defect.
  Per-story shards 08#F-1 and 09#F-1 raised it too, in the same round.
- **Cross-group unique survivors:** three, all MAJOR. They are listed under the upper bound below.
- **Claim-path and funds-path catches among the unique survivors:** s319 r1 14#F-2 (a failed claim
  polls as pending forever), r1 15#E-3 (discharge reads no receipt or destination), r1 cross-4#F-1
  (claim amount against proof), r2 14#F-1 (a broadcast claim whose receipt times out) and r2 18#F-1
  (the claim monitor closes before any claim is observed). Four of the five came from per-story
  shards. This grouping comes from reading the headings for this document. The BL-811 hand did not
  classify capital path, so no "capital-path" count is stated.

## Size against yield

The rows are per-story shards, all rounds (s320 provisional), split into terciles by the size of the
story the shard read.

| Story bytes | Shards | Unique survivors | Mean per shard | Shards with none |
|---|---|---|---|---|
| 6,714 – 11,590 | 17 | 10 | 0.59 | 9 |
| 11,701 – 15,547 | 17 | 11 | 0.65 | 7 |
| 15,593 – 31,854 | 18 | 11 | 0.61 | 9 |

Spearman rank correlation of size against unique survivors, n = 52: −0.025. Story size does not
predict per-story yield, so a size threshold cannot replace the per-ordinal count.

## Verdict

| Element | Unique survived (s319) | $ per survivor, all rounds | Verdict |
|---|---|---|---|
| Per-story elicitation shards | 26 (32 with s320 provisional), including the only CRITICALs | $3.06 | **Keep** |
| Cross-group elicitation shards, one per group | 2 (3 with s320 provisional), all MAJOR | $25.15; 52% re-raised | **Collapse to ONE cross-story shard briefed with every ordinal (`cross.md`)** |

The rule changes only stories elicitation on the files axis. The party round, the adversarial
convergence passes, their repairs, the sections axis and the subject axis keep their cross groups.

### Condition 1: the risk is an upper bound

The claim is that at most 2 MAJORs are at risk on s319, and no CRITICAL. It is a counterfactual
UPPER BOUND, and it is derived as follows.

1. The cross groups' unique surviving catches are exactly three:
   - **s319 r1 cross-1#F-2**: the USD total string's scale between producer 3.1 (ordinal 09) and
     consumers 3.2 and 3.3 (ordinals 10, 11).
   - **s319 r1 cross-4#F-1**: whether 3.1's `claimable_raw` (ordinal 09) is the proof-bound amount
     that 4.2 (ordinal 13) claims.
   - **s320 cross-4#F-3** (provisional): 3.3 AC5 (ordinal 09) against 2.2 AC6 (ordinal 05).
2. The upper bound assumes the single cross voice loses all three. That gives 2 MAJORs on s319, or
   3 if provisional s320 is counted. None is CRITICAL. The only CRITICAL a cross group raised,
   r2 cross-1#F-1, per-story shards raised as well.
3. The single cross voice need not lose them, because it reads each of those pairs. Each pair sits
   inside the read set the single voice is given. Every cross-group shard already read every story:
   its `artifact_sha` notarizes all 19, 20 or 13 stories, and `_gate-procedures.md` "The cross
   groups" states that a cross agent reads the whole subject and treats its group's pairs as focus.
   The one `cross.md` voice is briefed with every ordinal, so its read set is the same. What it loses
   is the per-group focus, not access to any pair. The real loss is therefore between zero and the
   bound.

### Counterfactual saving: $58.98

Saving = Σ cross-group cost − Σ (the costliest cross-group shard of each round). The costliest group
shard stands in for the one all-ordinal voice, which reads the same stories.

| Round | Σ cross | Costliest shard | Saving |
|---|---|---|---|
| s319 r1 | $32.19 | $7.34 | $24.85 |
| s319 r2 | $18.94 | $3.94 | $15.00 |
| s320 (provisional) | $24.32 | $5.19 | $19.13 |
| **three rounds** | $75.45 | $16.47 | **$58.98** |

On s319 alone the saving is $39.85. The proxy has not been run: no round has used one all-ordinal
elicitation voice.

### Condition 2: s320

s320 is provisional, because its stories gate has not passed. It contributes one cross survivor,
six per-story survivors, $19.13 of the saving and 13 of the 52 size rows. The verdict holds on s319
without it: 26 per-story survivors against 2 cross survivors, with both cross catches MAJOR.

## Data note: round 2 found defects in converged text

s319 r2's per-story shards found 12 unique survivors, 1 of them CRITICAL (06#F-1). They sit in text
that adversarial p1 and p2 had converged on (graph `b652377a8`, EXIT_CONDITION_MET). The finding
classes exclude text that the amendments and p5 wrote. This is recorded as a measurement. It is not
a rule.

## Blind spots

- The REFOUND judgments are manual, from reading. A wrong "same round" call moves a finding between
  REFOUND and UNIQUE.
- REPAIR-INTRODUCED is detected by an attribution regex and by quoted-span absence. A finding that
  quotes nothing and names no origin stays in the unique classes.
- 18 unique findings (13 per-story, 5 cross) carry no repair token, or a partial one. They are
  UNIQUE-unverified and are not counted as survivors in either column, so both survivor counts are
  floors.
- Survival is token presence in the shipped stories. It does not establish that the fix is correct.
- s320 is measured against the working tree, before its gate.
- The single cross voice is a counterfactual and its cost is a proxy. No round has run it.
- MINOR findings are not classified.
