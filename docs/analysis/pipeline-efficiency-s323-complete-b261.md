# Pipeline efficiency: s323 complete readings (BL-812, BL-819, BL-971, BL-1175, BL-912)

Batch 261, cluster C5 (hand: readings A, B, C). Sections for these entries only; the other hand's sections (`m2_` outputs) are separate.

## Method

- Graph `/Users/n8/git/graph` and its transcripts, read only. s323 closed: `finalize snapshot . sprint 323 closed` commit count 1 (control `sprint 322 closed` 1). Final graph ref `16fd227d9` (2026-11-19T23:00:40-05:00).
- Pin `EXTRACT_WIN_END=2026-11-20T04:20:00Z` for every regeneration. Clock: monotone segs clock (`EXTRACT_MONOTONE_SEGS=1`, the default since BL-1174), default-clock (`=0`) beside it where hours appear.
- Pipeline: `extract.py`, `spawns.py`, `analyze.py`, `roll.py`, `roll.py --seats`, `outcome_row.py`, `poles_allroles.py`, `seats.py`, `serial_tail.py`, then `scripts/s323_complete.py` and `scripts/story_totals.py` (this directory). Story counts: `roll.py` STORIES[323]=18; `s323_complete.py` passes its own story counts (`PLANNED`), so `bl812_rederive.py` was NOT edited (it lacks 323 and no reading here calls it).
- Controls: old clock at the original pin `2026-11-12T14:41:00Z` reproduces the committed `roll.txt` (`cmp` identical) and `roll_classes.txt` differs only by the `STORIES` header text and the added s323 block (the lines STORIES[323] explains). Dollars, token-equivalent dollars and lead calls are EQUAL between the two clocks for every sprint (`s323_complete.txt` `$/calls EQUAL`). The monotone s323 total (75.4 h) equals the sum of the five lead sessions' first-to-last spans (75.4 h); the default clock's 187.0 h exceeds it.
- s317 is NOT recomputed. Graph's transcripts for s314-s316 and early s317 are gone from disk (oldest mtime 2026-10-07), so today's corpus holds part of s317. s317 figures below are the published ones (BL-812: $88, 4.8 h, 44.5 spawns), old clock, full corpus, non-reproducible. Comparison runs from s318.
- In-session time only; no timing run. Token-equivalent dollars price the local lead at s321's hosted mix (`roll.py` FALLBACK), API dollars beside.
- Planning step lead-class rows moved by at most 5 calls against the provisional report (`other` 1,932 to 1,927, 9.1 to 9.0 h); the planning total is unchanged at 4,623 calls and 39.6 h. One subagent segment of the stories step (0.04 h, 2026-11-19T02:30Z) lies after the provisional pin.

## A. BL-812 / BL-819 / BL-971 re-take

Source: `out/story_totals` rows are `out/bl812_story_totals.txt`, produced by `scripts/story_totals.py` over `out/outcome_row.monotone-clock.txt` and `out/outcome_row.default-clock.txt` (`outcome_row.py` C1 to C4 controls read MATCH for all four sprints).

| Sprint | Machine h per story, monotone (default clock) | Subagent $ per story | Spawns per story | Lead tokens M per story | Lead calls per story |
|---|--:|--:|--:|--:|--:|
| s317 (published, old clock, full corpus, not reproducible) | 4.8 | 88 | 44.5 | | |
| s319 | 3.85 (4.64) | 88.3 | 78.0 | 80.7 | 318 |
| s321 | 3.43 (3.80) | 75.2 | 49.4 | 71.5 | 285 |
| s322 | 7.01 (8.36) | 124.1 | 83.5 | 169.4 | 1,163 |
| s323 | 3.20 (9.39) | 87.9 | 63.2 | 102.3 | 652 |

Sprint wall clock, pipeline bucket, both clocks (`out/s323_complete.txt`, first block): s318 74.8 h to 59.6 h; s319 110.0 to 94.0; s320 117.8 to 99.2; s321 120.5 to 111.0; s322 77.1 to 66.4; s323 187.0 to 75.4. Token-equivalent dollars: s322 $1,348, s323 $2,074 (API $989, $1,580). Per-step machine h, tokens, subagent $ and spawns for every step are in `out/outcome_row.monotone-clock.txt` (lead seat) and `out/s323_complete.txt` (per-step elapsed split, dollars, calls, spawns).

**BL-971 extra** (`out/bl971_seats_adversary.txt`, `seats.py`; solo from `out/poles_allroles.txt` TOTAL lines): s323 adversary 149 spawns on opus/medium, median 5.6 min, p90 11.6 min, $2.14 a spawn, 17.1 agent-hours, 1 spawn over 45 min. s322: 124 on sonnet/high, median 11.7, p90 61.5, $2.89, 45.3 agent-hours, 19 over 45 min. Solo-adversary hours (whole sprint, all steps): s323 3.2 h against s322's 11.5 h and s321's 15.7 h. Remediator solo: s323 9.9 h, s322 9.2 h, s321 9.6 h.

**BL-819** (`out/s323_complete.txt`, lead classes in the four planning steps, calls / active h; s321 | s322 | s323):

```
   other               s321  1237 /  3.2 h | s322  2010 /  5.7 h | s323  1927 /  9.0 h
   step-reread         s321    55 /  0.2 h | s322   220 /  0.4 h | s323   292 /  0.8 h
   compaction-recovery s321    19 /  0.1 h | s322   179 /  0.4 h | s323   198 /  0.7 h
   total               s321  2729 / 19.5 h | s322  4287 / 16.3 h | s323  4623 / 20.4 h
   compactions per elapsed h over the whole pipeline bucket, monotone clock: s321 57 in 111.0 h = 0.51 | s322 72 in 66.4 h = 1.08 | s323 134 in 75.4 h = 1.78
```

Lead active hours include waits on subagents shorter than 300 s, so calls are the like-for-like figure. Compactions across the sprint rose from 75 (provisional, 45.8 h) to 134 with implementation, sprint review and retro included. Planning less operator wait, with a subagent running (`busy`, four steps without gates), and the lead-only lower bound:

```
s321 less op-wait 36.8 h; subagent running 30.4 h; lead-only lower bound 6.4 h
s322 less op-wait 30.0 h; subagent running 22.1 h; lead-only lower bound 7.9 h
s323 less op-wait 27.0 h; subagent running 17.7 h; lead-only lower bound 9.3 h
```

## B. BL-1175 planning

Row shape of `backlog.md:3877` (monotone h, default clock in parentheses; elapsed includes each step's gate), `out/s323_complete.txt`:

| Sprint | Stories | Planning h monotone (default) | Less operator wait | Operator wait | Token-eq $ (API $) | Lead calls |
|---|--:|--:|--:|--:|--:|--:|
| s321 | 25 | 40.8 (43.0) | 36.8 | 4.0 | 1,298 (1,279) | 2,729 |
| s322 | 8 | 36.9 (44.0) | 30.0 | 6.9 | 889 (720) | 4,287 |
| s323 complete | 18 | 39.6 (133.1) | 27.0 | 12.5 | 1,071 (876) | 4,623 |

Per story (monotone): s321 1.63 h, $51.9; s322 4.61 h, $111.1; s323 2.20 h, $59.5. These planning figures equal the provisional ones: the four planning steps closed before the provisional pin, so completion added no planning records beyond the one subagent segment above.

**Item-0 class table (`backlog.md:4013`) re-read on complete s323.** Not re-classified. s323's story set at the final ref `16fd227d9` is the same 18 files as at the provisional ref `e70a344c0` (`git ls-tree` count 18 at both), and the planning steps' lead records and gate commits are unchanged, so the survivors-by-tag figures, which come from planning-step records, have no new input. The story files were edited during implementation (118 changed files under `planning-artifacts/s323` between the two refs, from commits dated after the planning gates); a re-read of those edits as new survivors was not taken, and was available.

**What each of the three still holds of s323's planning (39.6 h)** (`out/s323_complete.txt`, `still held` lines; s321 | s322 | s323):

```
BL-716 remediator solo, steps+gates:   9.8 h (24%) | 8.8 h (24%) | 9.9 h (25%)
BL-972 operator wait:                  4.0 h (10%) | 6.9 h (19%) | 12.5 h (32%)
BL-819 lead active, lead calls:        19.5 h (48%), 2729 | 16.3 h (44%), 4287 | 20.4 h (52%), 4623
```

The three overlap (wait and solo time sit inside lead active time), so the shares do not sum.

## C. BL-912 snapshot-class lead calls

`out/s323_complete.txt`, BL-912 block (`classes.jsonl`, clock-invariant; step with its gate folded in). Snapshot calls of all lead calls in the step, and snapshot active h:

```
stories-test-strategy   s321 173 of 1356 (13%) 0.57 h | s322 198 of 1348 (15%) 0.28 h | s323 110 of 1596 (7%) 0.29 h
implementation          s321 578 of 2508 (23%) 2.64 h | s322 322 of 2261 (14%) 0.72 h | s323 438 of 3730 (12%) 1.40 h
implementation label only s321 349 of 1562 (22%) 1.30 h | s322 213 of 1413 (15%) 0.42 h | s323 139 of 1129 (12%) 0.35 h
carry-over-evaluation   s322 145 of 1050 (14%) 0.30 h | s323 84 of 828 (10%) 0.25 h
requirements            s321 116 of 813 (14%) 0.63 h | s322 143 of 1202 (12%) 0.24 h | s323 85 of 1178 (7%) 0.25 h
architecture            s321 85 of 560 (15%) 0.64 h | s322 90 of 687 (13%) 0.17 h | s323 116 of 1021 (11%) 0.27 h
```

The one-call rule reached graph at 2026-11-18T02:05Z (0.1164.0), so it is read on the stories step and implementation. Calls fell in both; lead hours in the class on the stories step are flat (0.28 to 0.29 h); implementation active h in the class rose from s322's 0.72 h to 1.40 h on 3,730 calls against 2,261.
