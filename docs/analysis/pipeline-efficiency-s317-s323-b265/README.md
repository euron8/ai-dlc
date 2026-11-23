# Pipeline efficiency s317 to s323, narrowed pause detector (batch 265, BL-1174)

`out/roll.txt` and `out/roll_cachewrite.txt` are the default-switch outputs of the efficiency chain with the
narrowed pause detector (`TOUCH_FLAG_RE` in `prescan()`, commit 54f069ddf). No earlier committed output is
replaced.

## Command

Tree: ai-dlc `704a4eacd`. Graph transcript root: `~/.claude/projects/-Users-n8-git-graph` (read only); derived
sprint edges from `/Users/n8/git/graph` (`git log`, read only). Pin `EXTRACT_WIN_END=2026-11-20T04:20:00Z`, every
other switch at its default (monotone clock, derived edges, relabel, operator wait, fork dedupe, idle tail, split
segments, tiered cache-write pricing).

```
export EXTRACT_WIN_END=2026-11-20T04:20:00Z
python3 docs/analysis/pipeline-efficiency-s317-s320/scripts/extract.py $OUT
python3 docs/analysis/pipeline-efficiency-s317-s318/scripts/spawns.py $OUT
python3 docs/analysis/pipeline-efficiency-s317-s318/scripts/analyze.py $OUT
python3 docs/analysis/pipeline-efficiency-s317-s320/scripts/roll.py $OUT > $OUT/roll.txt
```

## Old-detector comparison and controls

The same chain ran in the same invocation against a copy of the same tree whose `extract.py` differs only at line
739 (`re.search(r"\btouch\b", cmd)` in place of `TOUCH_FLAG_RE.search(cmd)`); `cmp` of the two `extract.py` copies:
differ at char 46940, line 739. `spawns.py`, `analyze.py` and `roll.py` are byte-identical.

- Reproduction: the old-detector `roll.txt` TOTAL lines read operator wait s318 16.2, s321 29.3, s323 20.3 h and
  totals 59.3, 100.1, 75.4 h, the BL-1174 batch 261 E8 defaults row.
- Negative: s317, s319, s320 and s322 TOTAL lines are identical in both runs; their `segs.jsonl` deltas are 0.
- Lead-seat deltas, narrowed minus old, from `segs.jsonl` (total / operator wait / agent wait / active, h): s318
  0 / -0.0955 / 0 / +0.0955 (session `328c2b58`, retro; `roll.txt` operator wait 16.2 -> 16.1); s321
  0 / -0.0049 / 0 / +0.0049 (session `0ec8b044`, implementation; `roll.txt` still 29.3); every other sprint 0.
- The narrowed detector removes 3 of 134 pause matches in the window and adds none: `0ec8b044`
  2026-11-06T10:59:18Z and `328c2b58` 2026-10-14T17:41:45Z (prose that mentions a touch of the flag), `68cf8de7`
  2026-11-17T15:35:54Z (`touch` of another file beside an `rm -f` of the flag; no hours move).
- Committed outputs: pause spans count only with `EXTRACT_OPWAIT` on (`extract.py:554`). The all-off chain
  (`EXTRACT_EDGES=hand EXTRACT_RELABEL=0 EXTRACT_OPWAIT=0 EXTRACT_FORK_DEDUPE=0 EXTRACT_IDLE_TAIL=0
  EXTRACT_SPLIT_SEGS=0 ROLL_CACHE_TIER=0`, same pin) gives a `roll.txt` `cmp`-identical to
  `pipeline-efficiency-s323-complete-b261/out/roll.monotone-clock.txt` under both detectors, with identical
  `segs.jsonl` (the default-switch `segs.jsonl` pair differs, the control). No committed output moves.
