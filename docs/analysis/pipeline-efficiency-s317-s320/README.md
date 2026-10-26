# Pipeline efficiency, graph sprints 317–320

This directory extends [`pipeline-efficiency-s317-s318/`](../pipeline-efficiency-s317-s318/) through
graph s319 (closed) and s320 (open, through the stories step). It is the evidence behind BL-808 through
BL-812. It was measured on 2026-10-26 against `~/.claude/projects/-Users-n8-git-graph/`: 112 lead
transcripts and 4098 subagent transcripts. Nothing was written to graph.

## What changed from the s317–s318 scripts

`scripts/extract.py` differs from the s317–s318 copy in two places, and nowhere else:

1. **Sprint edges.** `EDGES` assigns s319 from 2026-10-14T22:00Z and s320 from 2026-10-23T09:53Z.
   Those are graph's retro-close commits `cc9fa15ea` and `ae97d9501`.
2. **Operator wait.** A gap over 5 minutes is charged to operator wait while an `AskUserQuestion` call
   is open. The s317–s318 method charged that time to agent wait, because the answer comes back as a
   `tool_result` that `human_prompt()` rejects. **This is a correction to the committed s317–s318
   tables:** between 7 and 15 hours per sprint move from agent wait to operator wait in s317–s319.

`analyze.py` and `spawns.py` are unchanged; run them from the s317–s318 directory. `render.py` was not
re-run.

## Reproduce

```
OUT=<scratch dir>
python3 docs/analysis/pipeline-efficiency-s317-s320/scripts/extract.py $OUT
python3 docs/analysis/pipeline-efficiency-s317-s318/scripts/spawns.py $OUT
python3 docs/analysis/pipeline-efficiency-s317-s318/scripts/analyze.py $OUT   # control: units==segs token sums equal
python3 docs/analysis/pipeline-efficiency-s317-s320/scripts/roll.py $OUT        # per-sprint, per-step
python3 docs/analysis/pipeline-efficiency-s317-s320/scripts/planning.py $OUT docs/analysis/pipeline-efficiency-s317-s320/scripts/roll.py
python3 docs/analysis/pipeline-efficiency-s317-s320/scripts/decompose.py $OUT   # spawns/story x $/spawn
python3 docs/analysis/pipeline-efficiency-s317-s320/scripts/impl_passes.py $OUT # implementation passes and shards
python3 docs/analysis/pipeline-efficiency-s317-s320/scripts/operator_asks.py
```

Token control: the units==segs sums must be equal; they were at 15.66 B on both sides at measurement. s320 was
still running, so a re-run reads a larger total and slightly different s320 figures. 1 of 4098 subagents is
unjoined.

## Headline (per story; graph `sprint-status.yaml` at each close: s317 21, s318 13, s319 20, s320 13)

| | s317 | s318 | s319 | s320 (planning only) |
|---|---|---|---|---|
| subagent spawns / story | 44.5 | 71.5 | 78.0 | 51.8 |
| $ / spawn | 1.98 | 1.53 | 1.13 | 1.36 |
| subagent $ / story | 88 | 109 | 88 | 70 |
| machine h / story (lead active + agent wait) | 4.8 | 4.7 | 4.7 | — |

The efficiency releases (0.782.0–0.786.0) reached graph on 2026-10-14/15, so s317 and s318 ran before
them and s319 and s320 after. The price per spawn fell about 40%, mostly from cheaper role bindings.
Spawns per story rose by about the same factor, so the cost per story did not move. Dollars are
API-list-equivalent at the prices in `spawns.py`.

**The decision rule for everything filed from this directory is the step-value ruling**, "A step with no
measured value goes" in `.claude/rules/operator-rulings.md`, applied as `docs/analysis/step-value-s317-s319.md`
applies it: a step, round or fan-out width is kept on catches no other step makes that survive to the shipped
artifact, a rare high-consequence catch judged on consequence. The figures here are measurements to report beside
that rule, never pass bars.
