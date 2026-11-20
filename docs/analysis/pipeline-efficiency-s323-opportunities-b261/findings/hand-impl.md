# Findings of reader `hand-impl` (recovered verbatim from its transcript agent-ahand-impl-331b35425c85bada.jsonl)

## FINAL-TEXT 2026-11-20T10:46:29.664Z

**What sets s323 implementation wall clock (the implementation step and its gates)**

1. **BLOCKER: a host-memory admission wall (up to 4.7 h of 14.0 h).** It held back both critical paths between 14:45Z and 19:30Z on 11-18. Seats could not launch the pytest suite because the machine had too little free memory. The local lead model, `mlx-serve`, held that memory.
2. **BLOCKER: the lead is the serial resource.** It was active 13.6 of 14.4 h. At least one story sat with no agent running 64% of the time.
3. **DEFECT: width and the concurrency cap are not the limit.** The cap is 42 and was never hit in implementation. With the dependency order actually used, story width 4, 6 and 8 all give 11.3 h (UPPER BOUND, zero lead latency). The measured window is 14.0 h.
4. **DEFECT: 371 of 3,885 lead tool calls were refused or errored (9.5%).** That includes 100 of 404 Agent dispatches.
5. **NOTE: first-pass rework is mostly record form, not logic.** Of 55 classified findings, 30 (55%) are EVIDENCE or BOOKKEEPING and only 5 (9%) are CODE. I could not allocate rework cost per class.

**Method and scope**
- The window is the lead session `53b4296a…` from 11-18T12:45:29Z to 11-19T03:09:29Z. A second session on 11-19 (stories 2.1 and 2.2) adds 1.2 h; the gap between the two is excluded.
- Spawns come from `MONO/spawns.jsonl`. Per-call figures come from re-parsing the subagent and lead transcripts. Calls are paired by `tool_use` id; for the lead I did not drop errored calls except in the refusal count.
- I did not run `impl_passes.py` because it writes `implrows.json` into `MONO`; pass counts below are parsed from spawn descriptions.
- Story 2.3 was built in the sprint-review step (60 min dev), so implementation has 17 stories.
- Controls:
  - The cap grep returns 0 in `53b4296a…`. The other session returns 20.
  - Git commits are 149 for agents and 81 for the lead, against 0 pushes.
  - `core/` has 0 hits for "admission". The same command hits 30+ files for `wait-for-deliverable`.

---

### BLOCKER 1: the admission wall

**Evidence**
- The graph convention `docs/coding-conventions.md:868-892` requires a suite launch to satisfy `n×1.25 + 16 GiB <= headroom`. For `-n 8` that is 26 GiB.
- Headroom sat at 15.6–25.9 GiB from 14:45 to 19:27Z. The QA seat for 3.1 was admitted at 19:30 with 74.2 GiB.
- The lead told the 1.1 seat: "mlx-serve released its memory at ~14:27 UTC [local time]".
- The operator was asked once and answered "Keep waiting" (303 s).
- There were 373 refusals across 23 agents in s323, against 24 in s322 and 0 in s321. Of the 311 refusal lines that carry a headroom figure, 195 (63%) would have passed at `-n 4` and 281 (90%) at `-n 2`.

**What it held up**
- QA 3.1 pass 2 ran 290 min, of which 277 min were `wait-for-deliverable` polls. Its canonical run was 138 s. That one agent is 4.62 h of the 7.63 h of `wait-for-deliverable` in implementation, which is 61%.
- The 1.1 dev-escalated rework ran 323 min with 114 refusals and 3 queued suite runs, 4.3 h of them waiting on the queue.
- Both are critical-path stories. 3.1 closed at 20:10, so 3.2 started at 20:27. 1.1 closed at 21:03, so 5.2 started at 21:13. No step in the engine text checks the wall.
- QA's "3.5 h solo" is this one agent. Without 3.1, QA `wait-for-deliverable` is 0.96 h.

**Removable**
- Up to about 4.7 h of the 14.0 h window (UPPER BOUND, from the DAG simulation below). That is about 6% of the 75.4 h sprint.
- Up to about $85 (UPPER BOUND): lead at about $11/h ($575 − $413 subagent = $162 over 14.4 h), plus idle seat cost.

**Engine changes**
- Add a host-capacity step beside the "Pre-dispatch auth check" (`implementation.md:108`). It should compute the suite predicate against measured headroom, including the local model's resident memory.
- Put one FIFO suite queue (a core script) in front of seats instead of N seats polling every 60 s.
- Escalate to the operator within minutes, not hours.
- Let the consumer set the worker count. `-n 4` alone clears 63% of the refusals.

**Risk:** the predicate protects against host OOM. Lowering it can kill the local lead model.

### BLOCKER 2: the lead is saturated

**Evidence**
- The lead made 3,885 tool calls in the window. 13.6 of 14.4 h were active, with 0.09 h of operator wait.
- 8,620 `qwen38flash` records: 4,735 text-only records with 5.17 M thinking characters against 181 K visible. They cover 5.03 h of generation gaps. Tool-use records add 1.50 h, tool waits 2.18 h, and agent-notification and prompt records the remaining time.
- Stories waiting on the lead (no agent running):
  - At least one story waited 9.0 h of the 14.0 h.
  - The average queue is 1.66 stories.
  - Stories in flight average 4.4.
- During the 8 longest per-story gaps (66–144 min) the lead made 262–793 calls on other stories.

**What the lead's calls were spent on**

| Family | Calls | Lead time |
|---|---|---|
| gate-transition | 339 | 0.68 h |
| Agent dispatch | 404 | 0.62 h |
| advisor | 66 | 0.52 h |
| validate-* | 249 | 0.37 h |
| snapshot-update | 281 | 0.36 h |

- Gate 3's 37 transitions took 49.8 s each in the foreground, 30.7 min in total.
- The class table (`classes.jsonl`) gives compaction-recovery plus step-reread at 502 calls and 1.35 h, against 0.34 h in s321 and 0.32 h in s322. There were 50 compactions in the window, against 23 in s321 and 16 in s322.

**Change:** one script call per gate event that records the verdict, runs the transition, updates the snapshot and runs the validators.
- Those four families are 1,273 calls and 2.03 h. Folding them removes at most about 1.2 h. I assumed 60%; I did not measure the fold itself.
- That is about $13, and it maps to wall clock only because the lead is saturated.
- Risk: the individual checks stay, but the lead sees fewer intermediate results.

### DEFECT 3: critical path, concurrency and width

**What limits concurrency**
- The cap is `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`, giving 42 subagents. Implementation never hit it; the 10 hits are in the other session at 11-19T17:51, in sprint review.
- Agent width across the window was 0 for 12% of the time, 1 for 9% and 2–3 for 49%. Peak was 12; the average was 3.36 with 48.4 agent-hours.
- Nine devs were dispatched at once at 12:51. The remaining stories were held by the wave-DAG (`implementation/wave-dag.md`).
- The engine text causing the long chain is `_dispatch-protocol.md:193`. It serializes two stories on "a shared source file both stories write", which gave the locked chain 1.1→1.2→1.3→1.4→2.1→2.2→2.3→5.2 on `rebalancer/execution.py`.
- The lead did not follow that chain. 1.2, 1.3, 1.4 and 5.2 all started at 21:13 after 1.1 closed, and 2.1 and 2.2 ran in parallel the next day.
- No hook enforces the chain. One working tree is not a limit, because each story has its own worktree.
- The test suite is a serialized resource only through BLOCKER 1.

**Makespan in hours**
- Assumptions:
  - Each story is one slot.
  - Its duration is the measured union of its agent-busy time. This includes the admission waits, and it assumes zero lead latency.
  - 2.3 is 1.3 h.
  - The schedule is critical-path-first list scheduling.
- This is an UPPER BOUND on improvement.

| Edges | W=2 | W=3 | W=4, 6, 8 |
|---|---|---|---|
| Declared chain | 19.4 | 17.7 | 17.7 |
| As executed | 19.3 | 13.1 | 11.3 |
| As executed, 3.1 without its 4.62 h wait | 17.0 | 11.5 | 9.9 |

- Actual was 14.0 h. Width beyond 4 buys nothing. Lead latency accounts for about 2.7 h of the difference.
- The critical paths are 1.1 (6.29 h busy) then 5.2 (3.61 h), and 3.1 (5.66 h) then 3.2 (5.62 h).
- In 3.2, the dev waited 28, 27 and 27 min on the one-process combined run (`server/test_*.py rebalancer/tests`, "about 28 minutes at base"). That is 82 min on the critical path.

**Change:** keep the lead's relaxation of the shared-file edge, with merge at close, as `_dispatch-protocol.md:193` text.
- The declared chain would have cost about 6.4 h more.
- Risk: merge conflicts. The record has `1-3-merge-resolution-review.md` and `post-merge-fixes-review.md`.

### Q1: per-story buckets

Summed over the 17 stories, in story-hours:
- **(a) Agent working:** 37.2 h (union of each story's agent intervals).
- **(b) Waiting on the lead or between dispatches:** 24.9 h. 21.6 h of it is in 36 gaps over 10 min. The other 3.4 h is in 52 short gaps.
- **(c) Held behind the DAG:** 46.0 h. That is 8.4 h each for 1.2, 1.3, 1.4 and 5.2, plus 7.4 h for 3.2 and 5.1 h for 5.5.
- **(d) Operator:** 0.33 h of lead-level wait in the window (one `AskUserQuestion`, 303 s).

| Story | Held h | Busy h | Gap h | Gate-1 passes | Gate-2 passes | Span h |
|---|---|---|---|---|---|---|
| 1.1 | 0 | 6.29 | 1.90 | 2 | 1 | 8.20 |
| 1.2 | 8.36 | 1.78 | 1.18 | 2 | 1 | 2.96 |
| 1.3 | 8.36 | 1.91 | 0.59 | 3 | 2 | 2.50 |
| 1.4 | 8.36 | 1.86 | 1.14 | 1 | 1 | 3.00 |
| 3.1 | 0 | 5.66 | 1.66 | 2 | 2 | 7.32 |
| 3.2 | 7.42 | 5.62 | 0.97 | 4 | 2 | 6.59 |
| 5.2 | 8.36 | 3.61 | 0.31 | 3 | 3 | 3.92 |
| 5.5 | 5.10 | 3.95 | 0.66 | 3 | 3 | 4.60 |

- The other nine stories are in the full list below.
- Gap hours (b) include the lead's own gate-script time.
- The gate-pass columns are my description parse and may be off by one where shard labels vary.

Remaining stories (held / busy / gap / G1 / G2 / span):
- 2.1: 0 / 0.49 / 0.03 / 1 / 1 / 0.52
- 2.2: 0 / 0.44 / 0.07 / 1 / 1 / 0.52
- 4.1: 0 / 1.46 / 2.39 / 1 / 2 / 3.85
- 4.2: 0 / 0.40 / 0.78 / 0 / 1 / 1.19
- 4.3: 0 / 0.95 / 0.73 / 0 / 2 / 1.68
- 4.4: 0 / 0.50 / 3.75 / 1 / 2 / 4.25
- 5.1: 0 / 0.51 / 1.96 / 0 / 1 / 2.47
- 5.3: 0 / 0.65 / 2.92 / 0 / 1 / 3.57
- 5.4: 0 / 1.12 / 3.90 / 2 / 2 / 5.02

### Q3: gate pipeline and QA

- Gates are strictly sequential per story. 0 of 68 QA spawns overlap a reviewer spawn of the same story.
- First-pass results by verdict:
  - Gate 1: 7 of 17 stories failed.
  - Gate 2: 9 of 17 failed.
  - Both failed: 5 stories (1.3, 3.2, 5.2, 5.4, 5.5).
- A review run after a QA failure happened 6 times. Those QA runs are redone either way.
- Running QA concurrently with gate 1 would waste one QA pass in the 7 stories where gate 1 fails.
- Gate 1 wall on the four critical-path stories is 0.04 to 1.11 h, so concurrency saves at most about 1 h (UPPER BOUND).
- Identical test commands across seats: 1 of 1,155 distinct suite commands, because paths differ per seat.
- Full-suite proof runs by seat in implementation: dev 40, code reviewer 18, QA 25, and 17 `record-run`. Each is about 2.3 min once admitted.
- I did not measure how many QA canonical runs repeat a dev run at the same sha.

### Q4: first-pass failures

- 55 findings carry a `Class:` tag in `docs/reviews/s323` (all review files): TEST 20, EVIDENCE 19, BOOKKEEPING 11, CODE 5.
- Each Critical or Important finding in the reviews carries one of these tags.
- Examples of EVIDENCE and BOOKKEEPING that a script could catch:
  - A capture whose head stamp is not the frozen sha, or that predates the rework.
  - A suite run not wrapped in the watchdog.
  - An empty `## Production Integrity Tests` section.
  - A `deferred_acs` row that does not match the story.
  - A damaged story-file splice.
- Dev already runs `validate-handoff-evidence.sh` before gate 1 (`dev.md:383`). The missing check is capture head against sha.
- Rework-labelled spawns are 55 of 307, $79 and 15.9 agent-hours. 4.8 h of that is the 3.1 QA wait, leaving about 11 agent-hours. This is agent time, not wall clock.
- Estimate: at most the share of EVIDENCE and BOOKKEEPING, about $43 and 6 agent-hours, UPPER BOUND and an allocation by finding count.
- Risk: a head-stamp check could mask a real stale capture if it only compares text.

### Q5: lead calls

- Lead calls (3,730): other 938, merge 1,222, gate-run 403, snapshot 438, dispatch 184, compaction-recovery 257, step-reread 245, repair 43. The counts and hours are from `classes.jsonl`.
- 1,150 of 2,369 Bash calls already chain 3 or more commands.
- There were no pushes, so there is no push or pre-push timing to report.
- 371 refused or errored calls:
  - 55 dispatches had no `Deliverable: <path>` line (`ai-dlc-dispatch-guard.sh:1800`).
  - 20 were refused because the post-compact advisor call was owed (`ai-dlc-recover-gate.sh:343`).
  - 146 Reads were denied by context-mode as oversize, and 21 by post-compact recovery.
- Cost is about 0.5 h (UPPER BOUND, at 5–10 s per refusal).
- **Change:** have the guard derive the `Deliverable` line from the gate plan path instead of refusing.

### Q6: Bash time inside agents

| Family | s323 | s322 | s321 |
|---|---|---|---|
| `wait-for-deliverable` | 368 calls, 7.63 h | about 0 h | about 0 h |
| Bash total | 13.78 h | 2.24 h | 10.02 h |
| pytest | 815 calls at 9 s, 2.11 h | 456 calls at 8 s, 0.97 h | 1,177 calls at 10 s, 3.29 h |
| `git other` (per call) | 1 s | 1 s | 2 s |

- Dev pytest per call is slower: 15 s on 341 calls in s323, against 6 s in s322 and 8 s in s321.

**Looked at and found efficient**
- Git operations: 5,154 calls in agents, 1 s each.
- Hooks: 0.05 h total.
- Gate-3 adjudicator fan-out: 168 spawns, median 1.7 min each.
- Parallel wave-1 dispatch: 9 devs launched at once.

**TRUNCATED, ask for part 2:** the per-class rework dollars (needs a pass-by-pass join of reviews to spawns), the s321 and s322 timelines, and the suite-reuse count.

## SENT 2026-11-20T10:46:57.522Z | Part 1: BLOCKER 1 rest, BLOCKER 2

PART 1 of 3. Window: lead session 53b4296a, 11-18T12:45:29Z to 11-19T03:09:29Z = 14.40 h (impl + gate labels). Lead active 13.6 h, op-wait 0.09 h. Second session 11-19 12:49-14:03 (2.1, 2.2) adds 1.2 h, excluded gap between. 17 stories in implementation; 2.3 was built in sprint-review (60 min dev). I did not run impl_passes.py (it writes implrows.json into MONO); pass counts are parsed from spawn descriptions and may be off by one where shard labels vary.

BLOCKER 1 (rest): ENGINE CHANGES for the admission wall
- Wall: graph docs/coding-conventions.md:868-892 requires n*1.25+16 GiB <= headroom (26 GiB at -n 8). Headroom 15.6-25.9 GiB from 14:45Z to 19:27Z; the QA seat for 3.1 admitted 19:30 at 74.2 GiB. Lead message to the 1.1 seat: "mlx-serve released its memory at ~14:27 UTC [local]". mlx-serve is the local lead model server (signature "mlx-serve-local" on every lead record). Operator asked once via AskUserQuestion (303 s): "Keep waiting".
- 373 refusals in s323 across 23 agents (s322: 24, s321: 0). Of 311 refusal lines carrying headroom, 195 (63%) pass at -n 4 (21 GiB), 281 (90%) at -n 2, 96 (31%) at -n 6.
- Held: QA 3.1 pass 2 = 290 min, 277 min in wait-for-deliverable polls (98 calls x 180 s; 88 refusals), canonical run itself 138 s. 1.1 dev-escalated rework 323 min, 114 refusals, 3 queued suite runs, about 4.3 h on the queue. 1.2 rework 47 refusals; 1.1 cross reviewer 22. wait-for-deliverable total 7.63 h in s323, QA 3.1 = 4.62 h = 61%. QA without 3.1: 0.96 h wfd.
- Both critical paths: 3.1 closed 20:10 so 3.2 started 20:27; 1.1 closed 21:03 so 1.2/1.3/1.4/5.2 started 21:13.
- Engine text is silent: core/*.md has 0 hits for "admission" (control in same grep: 30+ files for wait-for-deliverable). The wall is consumer-defined, the engine only supplies the polling script (core/scripts/wait-for-deliverable.sh, AI_DLC_WAIT_BEAT_SECS).
- Change 1: a host-capacity step next to "Pre-dispatch auth check" (core/skills/ai-dlc/steps/implementation.md:108): compute the consumer predicate against measured headroom WITH the local model resident, before wave 1.
- Change 2: one FIFO suite queue (core script) in front of seats, instead of N seats polling every 60 s.
- Change 3: escalate to the operator after a bounded refusal count (minutes), not after 4.7 h.
- Change 4: let the consumer set the worker count (-n 4 clears 63%).
- Removable: up to about 4.7 h of the 14.0 h window (UPPER BOUND, from the DAG simulation in part 2), about 6% of the 75.4 h sprint. Up to about $85 (UPPER BOUND): lead about $11/h (575 - 413 subagent = 162 over 14.4 h) x 4.7 = $52, plus idle seat cost (QA 3.1 $6.3, 1.1 rework $21 part idle, 1.2 rework $2.5).
- Catch at risk: the predicate protects the host from OOM; lowering it can kill the local lead model.

BLOCKER 2: the lead is the serial resource
- 3,885 lead tool calls in the window. Active 13.6 of 14.4 h (94%).
- Lead model: all 8,620 assistant records are qwen38flash. 4,735 are text-only records (5.17 M thinking chars vs 181 K visible), gap time 5.03 h. Tool-use records add 1.50 h, tool waits 2.18 h. So model generation is about 6.5 h of 13.6 h active; the rest is waits under 300 s.
- Queue: with a story in "gap" state (no agent running, its next dispatch owed) at least one story waited 9.0 of 14.0 h; average queue 1.66 stories; stories in flight average 4.4 (peak 9). Gap-state histogram: 0 waiting 4.96 h, 1 waiting 3.76 h, 2 1.45 h, 3 1.25 h, 4 1.09 h, 5 0.53 h, 6+ 0.97 h.
- Lead reaction latency (agent finished to next dispatch for that story, 88 gaps): median 457 s, p90 2,736 s; 36 gaps over 600 s sum 21.6 h of story time; 52 gaps under 600 s sum 3.4 h.
- Longest gaps: during each of the 8 longest (66-144 min: 5.4, 5.3, 4.4 twice, 1.1, 5.1, 4.1, 1.4) the lead made 262-793 calls on other stories (e.g. 5.4: 793 calls in 144 min). So the wait is queueing behind the lead's own turns, not an operator or slot wait.
- Per-story bucket sums over the 17 stories (story-hours): (a) agent working 37.2 (union of each story's agent intervals); (b) waiting on lead/between dispatches 24.9 (includes the lead's own gate-script time); (c) held behind the DAG 46.0 (1.2, 1.3, 1.4, 5.2 at 8.4 each = 33.4, 3.2 7.4, 5.5 5.1); (d) operator 0.33 h of lead-level wait in the window.
- Change: one script call per gate event (verdict record + gate-transition + snapshot-update + validators). Those four families (gate-transition 339, Agent 404, validate-* 249, snapshot-update 281) are 1,273 calls = 2.03 h of lead time. Folding removes at most about 1.2 h (UPPER BOUND; the 60% fold rate is my assumption, not measured), about $13. It maps to wall clock only because the lead is saturated. Catch at risk: the lead sees fewer intermediate results; the individual checks stay.

## SENT 2026-11-20T10:47:13.255Z | Part 2: DAG sim, refused calls, gates, findings

PART 2 of 3.

DEFECT 3: DAG simulation
- Declared edges (graph _bmad-output/implementation-artifacts/s323/wave-dag.md): chain 1.1>1.2>1.3>1.4>2.1>2.2>2.3>5.2 on rebalancer/execution.py; 5.4>5.5; 3.1>3.2. Cause in engine text: core/skills/ai-dlc/steps/_dispatch-protocol.md:193 serializes on "a shared source file both stories write".
- Executed: after 1.1 closed, 1.2, 1.3, 1.4, 5.2 all started at 21:13; 2.1 and 2.2 ran in parallel the next day. Edges used for the "as executed" row: 1.1>{1.2,1.3,1.4,5.2}, 5.4>5.5, 3.1>3.2.
- Assumptions: each story is one slot; duration = measured union of its agent-busy intervals (includes admission waits, zero lead latency); 2.3 = 1.3 h (sprint-review spawns 14:24-15:40); critical-path-first list scheduling. UPPER BOUND on improvement. Busy durations (h): 1.1 6.29, 1.2 1.78, 1.3 1.91, 1.4 1.86, 2.1 .49, 2.2 .44, 3.1 5.66, 3.2 5.62, 4.1 1.46, 4.2 .40, 4.3 .95, 4.4 .50, 5.1 .51, 5.2 3.61, 5.3 .65, 5.4 1.12, 5.5 3.95. Sum 38.5 h.
- Makespan (h), width in stories W=2 / 3 / 4,6,8: declared chain 19.4 / 17.7 / 17.7; as executed 19.3 / 13.1 / 11.3; semantic edges only (1.1>1.2>{1.3,1.4,5.2}, 2.2>2.3, 5.4>5.5, 3.1>3.2) 19.4 / 13.0 / 11.7; as executed with 3.1 minus its 4.62 h wait 17.0 / 11.5 / 9.9.
- Width 6 and 8 equal width 4. Measured window 14.0 h; critical path 11.3 h; so lead latency is about 2.7 h of the gap.
- Critical paths: 1.1 (6.29) then 5.2 (3.61); 3.1 (5.66) then 3.2 (5.62). In 3.2 the dev waited 28, 27, 27 min on the one-process combined run (server/test_*.py rebalancer/tests, "about 28 minutes at base") = 82 min on the critical path.
- Change: keep the lead's relaxation of the shared-file edge, merging at close, as the stated rule in _dispatch-protocol.md:193. Declared chain would have cost about 6.4 h more. Catch at risk: merge conflicts (record: 1-3-merge-resolution-review.md, post-merge-fixes-review.md).
- Cap: CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS gives 42. Not hit in implementation (0 hits in 53b4296a; control: 10 hits in session 64926214 at 11-19T17:51, sprint-review). Peak agent width 12, mean 3.36 over 48.4 agent-hours; 0 agents 12% of the time, 1 agent 9%, 2-3 agents 49%.

DEFECT 4: 371 of 3,885 lead calls errored or were refused (9.5%) in the window
- By tool: Read 171, Agent 100, Bash git other 38, Bash gate-transition 18, snapshot-update 7, rest 37.
- Agent, 100 of 404 dispatches (25%): 55 refused for no "Deliverable: <path>" line (35 + 12 gate-adjudicator, 8 code-reviewer; hook core/hooks/ai-dlc-dispatch-guard.sh:1800), 20 for post-compact touchpoint R (advisor call owed; core/hooks/ai-dlc-recover-gate.sh:343, "message 1 of 3"), about 4 shard-map mismatch (plan 4-part map), remainder other guard denials. Some counts appear twice as a plain and a "PreToolUse:Agent hook error:" variant of the same refusal.
- Read, 167 of 171 classified: 146 context-mode "N-byte file, over the on..." oversize denial, 15+6 post-compact recovery Read denials.
- Cost: each refused Agent call also regenerates the brief on the local model. At 5-10 s per refusal about 0.5 h (UPPER BOUND, I did not time the resends).
- Change: derive the Deliverable line from the gate plan path in the hook instead of refusing (remove the affordance); let the lead's first post-compact advisor call be part of the recovery hook. Catch at risk: the Deliverable check catches a brief that names no path; deriving it from the plan keeps that.

First-pass findings classification (s323, docs/reviews/s323, all review files; each Critical/Important finding carries one Class line per core/team-roles/code-reviewer.md:131,167)
- 55 tagged: TEST 20 (36%), EVIDENCE 19 (35%), BOOKKEEPING 11 (20%), CODE 5 (9%). Merged files may repeat a finding quoted in a later pass, so counts are a ceiling.
- Gate 1 first pass NEEDS_REWORK: 1.1, 1.2, 1.3, 3.2, 5.2, 5.4, 5.5 = 7 of 17. Gate 2 first pass NEEDS_REWORK: 1.3, 3.1, 3.2, 4.1, 4.3, 4.4, 5.2, 5.4, 5.5 = 9 of 17. Both: 5.
- Deterministic-check candidates (EVIDENCE+BOOKKEEPING = 30, 55%): capture head stamp not the frozen sha or predates the rework ("capture predates the production-code rework at the frozen sha", "captures name the wrong head", "grep-fees capture holds post-change tree"); honest-green run not launched through the pytest watchdog (4.1, 33 min rework); empty "## Production Integrity Tests" (5.4); sprint-status deferred_acs row missing an AC; damaged story-file splice. validate-handoff-evidence.sh already runs before gate 1 (dev.md:383); the missing check is capture-head against sha.
- TEST class (20) is mostly "fixture cannot detect the mutation it claims" (e.g. 4.4 PEM fixture, 5.2 mutation RED through a TypeError); not fully scriptable.
- Cost: rework-labelled spawns 55 of 307, $79 of $413, 15.9 agent-hours (QA 6.4, dev-escalated 5.4, reviewers 1.6, dev 2.5). 4.8 h of that is the 3.1 QA admission wait, leaving about 11 agent-hours. s322: 28 spawns, $27, 4.1 h; s321: 66, $98, 11.2 h. Agent time, not wall.
- Not measured: cost per class (would need a pass-by-pass join of findings to spawns). Allocating by finding count, EVIDENCE+BOOKKEEPING is at most about $43 and 6 agent-hours of the labelled rework (UPPER BOUND; an allocation, not a join). Catch at risk: a text-only head compare could pass a stale capture.

## SENT 2026-11-20T10:47:32.180Z | Part 3: gates, lead calls, Bash families, ranked changes

PART 3 of 3.

Gate-pipeline concurrency
- Gates are strictly sequential per story: 0 of 68 QA spawns overlap a reviewer spawn of the same story. Per-story spawn order, e.g. 3.1: D R Q D R Q A8 C; 4.2: D Q A8 C.
- A reviewer pass followed a QA failure 6 times (3.1, 3.2, 4.4, 5.2, 5.5 twice): QA findings forced code changes, so a pass-1 QA run in parallel with gate 1 would be redone in those, and wasted in the 7 stories where gate 1 fails first (QA pass 1 costs about $1-5).
- Wall saved if gate 2 started with gate 1: at most gate-1 wall on the critical-path stories: 3.1 0.04 h, 1.1 0.51 h, 5.2 0.42 h, 3.2 1.11 h, so under about 1.1 h on the longest path (UPPER BOUND, zero lead latency). Engine text making it serial: implementation.md gate-2 go-signal at the frozen sha after gate 1 (lines 632, 683-687, freeze).
- Gate 3: 168 adjudicator spawns, $92, 6.9 agent-hours, median 1.7 min, 8 shards in parallel per pass; the lead's gate-3 transition is 37 calls x 49.8 s = 30.7 min foreground.
- Duplicated suite runs across seats: of 1,155 distinct suite commands per story only 1 is textually identical across seats (paths and scratch dirs differ), so identical-command counting is a floor. Full-suite proof runs in implementation: dev 40, code reviewer 18, QA 25 plus 17 merge-review-shards --record-run; each about 138 s once admitted (about 100 runs x 2.3 min = 3.9 CPU-hours, mostly background). Not measured: how many QA canonical runs repeat a dev run at the same sha. Rule requiring the repeat: graph qa.md "QA MUST verify the proof run was wrapped" and core qa.md:347-392 canonical run at the frozen sha.
- QA solo hours: 3.1 pass 2's 4.62 h of wfd polling (BLOCKER 1). QA Bash total 6.61 h: wfd 5.58 h, pytest 0.40 h (256 calls, 6 s), git 0.25 h, web tests 0.18 h.

Lead calls in implementation by purpose (classes.jsonl, impl + gate label, s323 | s322 | s321 calls / active h)
- other 938/4.64 h | 993/3.54 | 612/3.32
- merge 1,222/3.12 | 554/1.51 | 707/2.86
- gate-run 403/1.70 | 142/0.65 | 359/2.31
- snapshot 438/1.40 | 322/0.72 | 578/2.64
- dispatch 184/1.10 | 123/0.61 | 168/1.33
- compaction-recovery 257/0.78 | 57/0.18 | 22/0.08
- step-reread 245/0.57 | 55/0.14 | 56/0.26
- repair 43/0.33 | 15/0.08 | 6/0.03
- idle-wait 0.87 h | 2.12 | 5.02
- Total 3,730 | 2,261 | 2,508. Compactions in the window: 50 vs 16 vs 23.
- Re-parsed lead families (window, calls, lead time): gate-transition 339, 0.68 h; Agent 404, 0.62 h; git other 1,198, 0.62 h; advisor 66, 0.52 h (28 s per call); validate-* 249, 0.37 h; snapshot-update 281, 0.36 h; Read 788, 0.20 h.
- Gate-transition by arg: gate 1 46 calls 2.6 s, gate 2 44 calls 3.2 s, gate 3 37 calls 49.8 s, 193 calls are grep/read of the script text.
- Pushes: 0 by lead and 0 by agents (control: 81 lead and 149 agent commits), so there is no push or pre-push hook time in implementation. Hook time total 0.05 h.
- Per-story fixed overhead: 3,730 / 17 = about 219 calls per story. Batch candidates: the four families above (1,273 calls, 2.03 h).

Test/validator runtime by family (agents, implementation, Bash wall time; calls x seconds per call)
- s323: wait-for-deliverable 368 x 75 s = 7.63 h; pytest 815 x 9 s = 2.11 h; git other 5,154 x 1 s = 1.33 h; web tests 309 x 11 s = 0.98 h; validators/lint 346 x 9 s = 0.84 h; sleep 63 = 0.24 h. Bash total 13.78 h (8,191 calls).
- s322: pytest 456 x 8 s = 0.97 h; git 1,703 x 1 s = 0.69 h; validators 101 = 0.29 h; total 2.24 h.
- s321: git 9,149 x 2 s = 4.87 h; pytest 1,177 x 10 s = 3.29 h; web tests 260 x 10 s = 0.72 h; total 10.02 h.
- Slower than s321/s322: wait-for-deliverable (new, 7.63 h vs about 0.03 h) and dev pytest (341 calls x 15 s = 1.43 h vs 6 s in s322 and 8 s in s321). Not slower: QA pytest (6 s vs 10-14 s), git (1 s), web tests (11 s vs 10 s).
- Long agents are mostly idle waiting, not running: dev 3.2 (288 min) had 11 min of tool time and 257 min of gaps ending in a task notification or coordinator message; 1.1 rework 264 min; 5.2 162 min; 5.5 dev 100 min. Dev seats stay alive as standby through their gates (e.g. 3.2 dev 51 min between "at review" and the lead's 18-finding message), so agent-hours overstate work.

RANKED ENGINE CHANGES (hours = wall clock in the 14.0 h implementation window unless stated; all UPPER BOUND)
1. Host-capacity check plus one suite queue plus bounded-refusal escalation. Cites: implementation.md:108 (add beside the auth check), core/scripts/wait-for-deliverable.sh. Removes up to about 4.7 h, up to about $85. Catch at risk: host OOM and loss of the local lead model.
2. Fold per-gate-event lead calls into one script (gate-transition, snapshot-update, validators, dispatch brief generation). Cite: implementation.md:317 (gate-transition.sh call form). Up to about 1.2 h, about $13 (the 60% fold rate is assumed). Catch at risk: fewer intermediate results seen by the lead.
3. Derive the Deliverable line and fold the post-compact advisor call into recovery so refusals stop. Cites: core/hooks/ai-dlc-dispatch-guard.sh:1800, core/hooks/ai-dlc-recover-gate.sh:343. Up to about 0.5 h. Catch at risk: briefs naming no deliverable path.
4. State the shared-file relaxation as the rule (merge at close) instead of serializing. Cite: _dispatch-protocol.md:193. Up to about 6.4 h versus the declared chain; 0 h versus what the lead already did. Catch at risk: merge-conflict rework.
5. Check capture head against the frozen sha at dev handoff. Cites: dev.md:380-383, core/scripts/validate-handoff-evidence.sh. Up to about 6 agent-hours and about $43 of rework (allocation by finding count); wall effect unmeasured. Catch at risk: stale captures passing a text compare.
6. Start gate 2 with gate 1 for stories on the critical path only. Cite: implementation.md:632,683. Up to about 1.1 h on the longest path. Catch at risk: wasted QA in the 7 of 17 stories where gate 1 fails first.
7. Do not run the 28-minute one-process combined suite three times on a critical-path dev seat; run it once at the frozen sha. Up to about 55 min of 3.2's critical path. Not engine text I located: the run comes from the lead's step-0 baseline in graph.

Left open: per-class rework dollars (needs a pass-by-pass join), s321/s322 per-story timelines, and the count of repeated canonical runs at the same sha.

