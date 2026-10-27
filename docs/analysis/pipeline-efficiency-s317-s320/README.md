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

## Instrument corrections (c6b, Unit E)

- **Window.** `extract.py` selects transcripts by the last in-file timestamp against `WIN_START`, never by mtime
  (the 2026-10-05 mtime cut hid s314 to s316). `WIN_START` is `argv[2]`, else `$EXTRACT_WIN_START`, else
  2026-09-26T00:35Z. `EDGES` now carries s314, s315 and s316, each the close commit of graph's retro (`36f74d63c`,
  `7b74011a9`, `8eb9429a1`) rounded up a few minutes. Re-taken s317 to s320 totals are unchanged (hours, calls, subagent $).
- **Gap.** Each segment records `gap`, the time between consecutive records over 300 s; `gap == op_wait + agent_wait`
  holds on every segment. **Hours everywhere are gap-inclusive** (active plus gap). `roll.py` prints the gap beside them.
- **Pass regex.** `impl_passes.py` reads `G1p<N>`, `pass-<N>`, `pass <N>`, `pass_<N>` and multi-digit `N`; the sprint list is an argument.
- **Dollars.** `roll.py` prints API $ (local calls $0) and token-equivalent $ (each `qwen38flash-mlx` call priced at
  the count-weighted price of that sprint's own HOSTED calls on the same seat), with the model mix beside every sprint.
  The price is derived, not assumed; the lead-seat hosted call counts it derives from are below.

## Token-equivalent dollars, graph s314 to s320 (pipeline bucket; hours gap-inclusive)

| sprint | hours (gap-incl.) | of which gap | API $ | token-equiv $ | lead model mix (calls) |
|---|---|---|---|---|---|
| s314 | 59.3 | 24.2 | 341 | 555 (FALLBACK: s315 hosted lead mix; bracket sonnet 555 to opus 666) | qwen 100% |
| s315 | 32.1 | 19.0 | 505 | 505 | sonnet 100% |
| s316 | 100.1 | 71.0 | 1307 | 1307 | sonnet 100% |
| s317 | 112.8 | 51.4 | 2172 | 2357 | sonnet 56%, qwen 44%, opus 1% |
| s318 | 74.8 | 42.6 | 1720 | 1721 | sonnet 100% |
| s319 | 110.0 | 55.2 | 2234 | 2234 | sonnet 97%, opus 3% |
| s320 (partial) | 75.3 | 58.5 | 1048 | 1048 | sonnet 100% |

Derivation of the local-call price (lead seat hosted calls, `roll.py` output): s314 none (opus 0, sonnet 0);
s315 sonnet 2175; s316 sonnet 4210; s317 sonnet 4528, opus 60; s318 sonnet 4398; s319 sonnet 6151, opus 214;
s320 sonnet 1875; haiku and fable 0 on the lead seat in every sprint. s317 is the only sprint with both local and
hosted lead calls. **s314 has no hosted lead calls**, and graph's configuration at its start commit (`6a4469196`,
`.claude/settings.json`: no top-level `model` key; `aiDlcModels` maps only role names) names no lead model, so s314 is
priced at s315's hosted lead mix and marked a fallback; the sonnet-to-opus bracket is printed beside it.
Arm-log evidence for the bracket: graph's `_bmad-output/arm-log.jsonl` (at `6a4469196`) records the hosted lead
immediately before s314's switch to local as opus (`claude-opus-5-5`, 2026-09-22 to 2026-09-25), then
`qwen38flash-mlx` from 2026-09-25T20:55Z. The bracket's opus end ($666) is therefore the observed predecessor, not a
hypothetical; the sonnet end ($555) is the s315-mix fallback.

Subagent model mix by calls: s314 sonnet 83 / opus 17; s315 sonnet 64 / opus 36; s316 sonnet 67 / opus 32;
s317 sonnet 54 / opus 38 / haiku 8; s318 opus 46 / sonnet 40 / haiku 13; s319 opus 40 / sonnet 35 / haiku 25;
s320 opus 48 / sonnet 42 / haiku 10. Only the lead seat ever ran local, so a cross-sprint dollar comparison that
mixes s314 or s317 with the others compares models as well as work.

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
