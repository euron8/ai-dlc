# b244 snapshot of graph s317–s320

This snapshot is pinned so that the figures cited by the backlog's `Outcome measured:` lines still hold after
graph's transcripts move on or are cleaned up. Nothing was written to graph.

- **WIN_END:** `2026-10-27T13:08:00Z` (`EXTRACT_WIN_END`). Records later than this are dropped. WIN_START is the
  default `2026-09-26T00:35:00Z`.
- **Run date:** 2026-10-27T13:29Z. The extractor read a copy-on-write clone (`cp -cR`) of
  `~/.claude/projects/-Users-n8-git-graph/` taken at 13:29:41Z, through `EXTRACT_ROOT`.
- **Corpus:** 158 lead transcripts and 5236 subagent transcripts were selected. 158 lead units and 5231 subagent
  units have records before WIN_END, and 0 subagents are unjoined.
- **Token control** (analyze.py, units==segs): 21441027755 = 21441027755.
- **STORIES**, part of the snapshot (`roll.py` `STORIES`, from graph `sprint-status.yaml` at each close):
  s317 21, s318 13, s319 20, s320 13. s320 was still open at WIN_END, and its 13 is the count at that time.

Files:

- `steps.csv` is the output of analyze.py from the s317–s318 directory, run on this extract.
- `seats.txt` is `roll.py <OUT> --seats`. For the cited step groups (s317+s318 pooled, then each sprint) and for
  every step per sprint, it prints per story: hours gap-inclusive with the gap beside them, token-equivalent $
  with API $, tokens, and the lead and subagent figures separately (`lead active X h, lead $Y, subagent active
  X h, subagent $Y`). Subagent active hours are summed over subagents, so they can exceed elapsed hours.
- `cap_rejections.txt` is the output of `scripts/cap_rejections.py`, run with the same pin on the same frozen
  clone (2026-10-27T13:59Z). Per sprint, it counts unique lead Agent/Task tool_use ids, and those whose result
  says "Concurrent subagent limit reached".

Reproduce from this directory's parent:

```
EXTRACT_WIN_END=2026-10-27T13:08:00Z python3 scripts/extract.py $OUT
python3 ../pipeline-efficiency-s317-s318/scripts/analyze.py $OUT    # steps.csv
python3 scripts/roll.py $OUT --seats                                 # seats.txt
EXTRACT_WIN_END=2026-10-27T13:08:00Z python3 scripts/cap_rejections.py   # cap_rejections.txt
```

Two pinned runs on the frozen clone are byte-identical. A pinned run on the live corpus at 13:26Z gives the same
`steps.csv` as the clone. So the pin holds while the corpus grows, as long as no record before WIN_END is
rewritten or deleted.
