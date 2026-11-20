# s323 opportunities readers (batch 261, C10)

Scripts and small result tables behind
[`../pipeline-efficiency-s323-opportunities-b261.md`](../pipeline-efficiency-s323-opportunities-b261.md).
Source only: no extracted transcript data is committed (every `.jsonl`, `.json` and `.pkl` dump was left out, with the one exception of `out/asks/tally.json`, which holds counts only, and
so was any output that quotes transcript text, such as raw command lines or hook messages). Re-extract from
`~/.claude/projects/-Users-n8-git-graph` (read only) as the report's "Reproduce" section says.

## Run

- Export `EXTRACT_WIN_END=2026-11-20T04:20:00Z` and run with `python3 -I <script> [args]`.
- The scripts read an extraction directory: the output of `extract.py` and its siblings
  (`docs/analysis/pipeline-efficiency-s317-s320/scripts/`), which the readers called `MONO/` (`segs`, `spawns`, `tools`,
  `hooks`, `units` and `classes` files and `owner.json`). Where a script takes the directory as an argument
  it is the first argument. Where it does not, the directory is a hard-coded constant (`M`, `D`, `MONO`,
  `SRC`, `R`).
- **Every hard-coded absolute scratchpad path (`/private/tmp/claude-501/...`) is left as the script ran.
  Replace it with your own extraction directory before running.** Scripts also read
  `/Users/n8/git/graph/docs/reviews/s323/` (`tool-runtime/find.py`, `tool-runtime/sumr.py`) and
  `~/.claude/projects/-Users-n8-git-graph/`, read only.
- Order inside a reader is the file order of the reader's own scratch directory, which is not recorded: read a
  script's docstring or header before running it. A script that imports `lib` needs its own reader's `lib.py`
  beside it.

## Files

| Reader | Subject | `scripts/` | `out/` |
|---|---|---|---|
| lead time | the lead's own work: model, tool and idle time per call, compaction recovery, snapshot and read classes, notification latency, hook cost, denied tool calls | `scripts/lead-time/` (`lib.py`, `fam.py`, `build.py`, `a1` to `a4`, `b1`, `b2`, `c0` to `c4`, `ctl`, `d1`, `d3`, `e1`, `e2`, `f1`, `f2`, `g1`, `h1`) | `out/lead-time/*.txt` |
| tokens | subagent dollars: the fixed first-request context, cache write and read shares, per-role breakdown | `scripts/tokens/` (`lib.py`, `extract_spawn.py <sprint> <out.jsonl>`, `a2`, `a3`, `a3b`) | none small enough to keep; rerun |
| operator asks | every `AskUserQuestion` and every wait over 300 s after a lead turn, s321 to s323 | `scripts/asks/` (`dump.py OUTFILE`, `ans.py`, `show*.py`, `win.py`) | `out/asks/tally.json` (counts per sprint and class, no text) |
| late steps | sprint review, deploy-validate and retro: Bash call families, API errors, hook errors, phase boundaries | `scripts/late-steps/` (`lib.py`, `scan.py OUT`, `fam.py`, `buckets.py`, `phase.py`, `ag.py`) | `out/late-steps/ag.txt` (agent list: time, role, description, duration) |
| tool runtime | tool-call latency, suite-launch admission refusals, git and push calls, long gaps, review-finding tallies | `scripts/tool-runtime/` (`adm.py`, `adm2.py`, `agent_calls.py`, `agerr.py`, `biggaps.py`, `dup.py`, `fam.py`, `find.py`, `full.py`, `gaps.py`, `gaps2.py`, `gitcalls.py`, `gt.py`, `lead.py` to `lead3.py`, `long.py`, `long2.py`, `push.py`, `sumr.py`) | none small enough to keep; rerun |

The `tool-runtime` reader is recorded from its scratch directory name (`h10`); the subject column is read from the
scripts, not from a brief.

## Readers whose scripts could not be recovered

- **Planning serial tails** (report group 4): its scratch directory held only pickled extractions
  (`cl.pkl`, `ev.json`, `lone.pkl`) and no script. The figures in group 4 are from that reader's report and can be
  re-derived from the lead-time `lib.py` classes and the `out/lead-time` tables, not from a committed script.
- **Implementation and its gates** (report group 5): the reader's scratch directory could not be found. Its
  critical-path simulation (11.3 h at width 4, 6 or 8 against 14.0 h) has no committed script.

## What was left out, and why

- Data dumps: `*.jsonl`, `*.json` and `*.pkl` extractions (tens of MB, and they quote transcript text).
- `lead-time/d2.txt`, `late-steps/out/bash_by_sprint_top80.txt` and the `bash.jsonl`, `hookerr.jsonl`, `apierr.jsonl`
  and `othertools.jsonl` dumps: raw command lines and hook messages from transcripts.
- Bytecode (`__pycache__`).
