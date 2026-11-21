# Step value on graph s323 (BL-810 close, BL-812 items 1 and 3) — batch 263, cluster J

Graph is read only. s323 has 18 stories (story files under `_bmad-output/planning-artifacts/s323/stories` at
graph 16fd227d9, the s323 close).

## The extraction (one per clock)

The clock is BL-1174's monotone clock as batch 261 used it: the scripts of
`docs/analysis/pipeline-efficiency-s317-s320/scripts/` and `pipeline-efficiency-s317-s318/scripts/` at
af44929cc8ca96ab91e8526516e9ac4efa7d21cd, taken with `git archive af44929cc docs/analysis | tar -x -C <dir>`
and run from there:

    EXTRACT_MONOTONE_SEGS=1 EXTRACT_WIN_END=2026-11-20T04:20:00Z python3 -I <dir>/.../pipeline-efficiency-s317-s320/scripts/extract.py OUT
    python3 -I <dir>/.../pipeline-efficiency-s317-s318/scripts/spawns.py OUT
    python3 -I <dir>/.../pipeline-efficiency-s317-s318/scripts/analyze.py OUT
    python3 -I <dir>/.../pipeline-efficiency-s317-s320/scripts/roll.py OUT > OUT/roll.txt
    python3 -I <dir>/.../pipeline-efficiency-s317-s320/scripts/roll.py OUT --seats > OUT/seats.txt
    python3 -I <dir>/.../pipeline-efficiency-s317-s320/scripts/roll.py OUT --classes > OUT/classes.txt

and the same again with `EXTRACT_MONOTONE_SEGS=0` (old clock) into a second OUT.

Controls on that extraction, both clocks:
- The token control is units==segs 30222324609 on both sides of both runs.
- These outputs are byte-identical (`cmp`) to the committed batch-261 files:
  - `../s323-outcomes-b261/bl508-bl543/group_four_steps.out.txt`;
  - `group_four_steps_hours.out.txt` and `group_four_steps_hours.oldclock.out.txt`, run with `ROLL_DIR=<dir>/.../pipeline-efficiency-s317-s320/scripts`;
  - `../pipeline-efficiency-s323-complete-b261/out/outcome_row.{monotone,default}-clock.txt`, `roll.{monotone,default}-clock.txt` and `roll_classes.monotone-clock.txt`.
- Must-differ control: the two clocks' hour outputs differ.

## Scripts (this directory), each `python3 -I docs/analysis/step-value-s323/scripts/<name>.py ...` from the repo root

| Script | Reads | Output | Controls it prints |
|---|---|---|---|
| `rose_s323.py OUT A B` | spawns.jsonl, seats.txt (via `bl812_rederive`, imported, with STORIES[323]=18) | `out/rose_323_319.txt`, `out/rose_322_319.txt` | C1 the story map is unchanged for 317-322; C2 the per-step subagent $ sums to the sprint total; C3 an impossible step reads 0 |
| `req_yield_s323.py OUT GRAPH` | spawns.jsonl; graph planning artifacts at ship `eabdc576e` (s323 sprint merge #1337) | `out/req_yield_s323.txt` | 48 MATCH lines, 0 DIFFERS (`grep -c`): partitions sum to the label totals with 0 catch-all rows (s323, s322, s319); finding counts taken two ways; impossible tokens 0 beside present ones; one-time mutant (drop `party-adjudicate`) gives 12 catch-all rows, DIFFERS |
| `co_yield_s323.py OUT GRAPH` | spawns.jsonl; graph at `eabdc576e`, verdict files at `16fd227d9`; `../s323-outcomes-b261/bl810-bl1005/out/width-319-320-323.txt` as the C/M control | `out/co_yield_s323.txt` | 55 MATCH lines, 0 DIFFERS (`grep -c`): partitions with 0 catch-all rows; per round x width C/M equals width.py's on all 9 rows; each round's read text equals its `artifact_sha` (8 of 8); one-time mutant (drop the party-cross rule) strands $7.37, DIFFERS |
| `tail_yield_s323.py OUT GRAPH` | spawns.jsonl; graph ship `eabdc576e`, close `16fd227d9`, post-ship control `6fcfd81a7` | `out/tail_yield_s323.txt` | partitions with 0 unmatched and 0 double-matched rows; 95 of 95 seat tokens covered; 165 headings against a second count and the commit message; fix survival 99.4% against the must-differ post-ship commit's 22.0%; one-time mutants (drop the dispatcher rule; change one cluster id) both read DIFFERS |
| `novalue_parts_s323.py OUT` | spawns.jsonl | `out/novalue_parts_s323.txt` | each "no measured value" part's, and carry-over p2 and p3 cross's, spawns and $ equal its yield reader's figure (6 MATCH); an impossible description reads 0 rows |
| `projection_s323.py OUT CLASSES` | spawns.jsonl, seats.txt, `roll.py --classes` | `out/projection.txt` | C1 every s319 baseline the projection table quotes re-derives (MATCH ×4); C2 lead calls by class equal outcome_row's whole bucket within cell rounding; C3 an impossible description token reads 0 beside a present one |

Each `*_yield_s323.py` was written in a scratch directory, then re-run from its committed path over the same OUT.
Its committed `out/` file is `cmp`-identical to the scratch output. Every yield reader is a FLOOR: span presence at
ship is a token proxy, not fix correctness, and the four-way classes the outputs mark as hand readings are hand
readings.

`out/cross_spawns.txt` and `out/cross_spawns.broad.txt` are
`../pipeline-efficiency-s317-s322/scripts/cross_spawns.py OUT [--broad]` over the same OUT. The control is that
s319's 360 (regex) and 498 (broad) and s321's 22 are BL-811's recorded figures.

`rose_322_319.txt` is the control run of `rose_s323.py` against batch 257's s322 reading. It names the same
token-equivalent-only pair, architecture and stories-test-strategy. On subagent $ it names the 13 labels batch 257
named plus `pre-step` ($0.20 to $0.41 per story). Batch 257's run, on its own extractor at an earlier window, did not name
`pre-step`. Why is not established here.
