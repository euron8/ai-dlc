# BL-912 In-Flight row assessment readers (batch 263, cluster J)

Read-only readers behind the `Reading (batch 263, cluster J)` paragraph of BL-912 in `docs/backlog.md`.
Every script takes its inputs by argv and reads nothing else. Run each as `python3 -I <script> <args>`.

Inputs, all scratch copies:

- `TX`: a copy of the `*.jsonl` at the root of graph's Claude project directory (the root lead transcripts only).
- `G`: a `file://` clone of graph, read with `git log --all` and `git show` only; the figures were taken at `749b77385`.
- `SUB`: graph's Claude project directory itself (its `*/subagents/agent-<id>.jsonl` files are the subagent
  transcripts); read only, never copied.
- `AGENTS`: a text file of agent ids, one per line (the 24 `(b) DISAGREE` agents that `ext.py` prints as `DIS` lines).

| Script | Command | Purpose | Control |
|---|---|---|---|
| `ext.py` | `ext.py TX G SUB` | The committed `docs/analysis/step-value-b257/bl912/bl912_hookgap.py` plus an extension: per-disagreement detail and, with `SUB`, the deliverable each disagreeing agent actually wrote (Write/Edit paths in its own transcript). | `toolu_QZX9impossible` reads 0 (first line of output) |
| `truth.py` | `truth.py EXTOUT SUB` | Reads `ext.py`'s saved output (`EXTOUT`) and, from each disagreeing or agreeing agent's full Write/Edit list, counts whether it wrote the brief's deliverable and the lead's cell. | an impossible agent id has 0 writes (last line) |
| `rows.py` | `rows.py TX SUB` | Lead hand-written rows (`snapshot-update.sh --row-add/--row-replace`) against the agent's own Write/Edit paths, windowed pre-cut and post-cut at 2026-11-12T07:40:00Z. | `aQZX9impossible00` has 0 subagent files |
| `cons.py` | `cons.py TX AGENTS` | Counts the lead's tool calls that name each agent (SendMessage, TaskStop, row ops, waits). | `aQZX9impossible000` has 0 records |
| `detail.py` | `detail.py TX AGENTS` | Prints each lead SendMessage, TaskStop, row-replace, wait and text mention of those agents, with timestamps. | none beyond `cons.py`'s |
| `snaprows2.py` | `snaprows2.py G SUB SINCE UNTIL` | In-Flight rows in graph's committed `_bmad-output/pipeline-snapshot.md` over a commit window, against subagent writes; classifies hand rows and hook rows (`<a+16hex> toolu_...`). Imported by `prov2.py`. | none |
| `prov2.py` | `prov2.py G SUB SINCE UNTIL TX` | Classifies each committed row as lead-written or hook-written, then same-fan permutation, shared-file or other disagreement; counts fan groups. | `aQZX9impossible00` must be absent from the lead set (printed) |

`SINCE` and `UNTIL` are UTC stamps. Pre-cut: `2026-11-09T00:00:00Z 2026-11-12T07:39:59Z`. Post-cut (graph
`e0ebaf019` onward): `2026-11-12T07:40:00Z 2026-12-31T00:00:00Z`.

`ext.py` and `prov2.py` take minutes on 190 transcripts.
