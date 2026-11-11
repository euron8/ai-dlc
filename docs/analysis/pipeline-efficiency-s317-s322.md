# Pipeline efficiency, graph sprints 317–322: did the optimizations work, and what is left

Measured 2026-11-11. This extends [`pipeline-efficiency-s317-s318.md`](pipeline-efficiency-s317-s318.md)
and [`pipeline-efficiency-s317-s320/`](pipeline-efficiency-s317-s320/README.md) through graph s321
(closed 2026-11-08) and s322 (open: planning complete, 3 of 8 stories done at the snapshot). Scripts
and their raw output are in [`pipeline-efficiency-s317-s322/`](pipeline-efficiency-s317-s322/).
Nothing was written to graph.

## Answer

1. **The implementation-step fixes worked.** Implementation plus its gate fell from 2.09 h and $41.3
   per story (s319) to 1.13 h and $25.5 (s321). Gate-1 review shards per pass fell from 5.5 to 1.4.
   Subagent sleep-polling and cap-rejected spawns are gone.
2. **Per story, s321 is the cheapest and fastest sprint since s318: 4.8 h and $95.5**, against 5.5 h
   and $111.7 in s319. Two confounds carry part of that: s321 had 25 stories to spread planning over,
   and it ran no carry-over evaluation.
3. **In absolute terms nothing got shorter.** s321 took 120.5 in-session hours and $2,388, the
   longest and most expensive sprint measured. Planning did not fall.
4. **One shipped change made sprints slower and dearer.** Moving the adversary seat from opus/medium
   to sonnet/high (BL-832, 0.954.0) raised its time per spawn from 7–8 minutes to 18–22 and its cost
   per spawn from $1.70–1.91 to $2.24–2.90. The adversary is now the seat the lead waits on most.
5. **Half of a sprint's wall clock is the lead waiting on subagents**, about 60 of s321's 120.5 h.
   Operator answers are another 24.9 h. The lead's own turns are about 35 h. The earlier analyses
   counted 35–41% of the lead's "active" time as lead work when it was idle waiting.

## Population and method

**Corpus.** `~/.claude/projects/-Users-n8-git-graph/`: 151 lead transcripts and 6,018 subagent
transcripts, window end pinned at `EXTRACT_WIN_END=2026-11-11T10:30:00Z`. The transcripts before
2026-11-09 were restored from another machine on 2026-11-11 (19,278 files, byte-compared after the
copy, none overwritten). **The restored corpus starts at 2026-10-07T08:00Z, so it is missing s317's
first two days.** s317 figures below are the ones committed in the s317–s320 README; every other
sprint is re-extracted here.

**Sprint edges.** `extract.py` gains one edge: s321 ends at 2026-11-09T00:00:00Z. The last s321 lead
record is 2026-11-08T21:47:02Z and the s322 lead opens at 2026-11-09T00:00:37Z; the spawn ledger
agrees (last s321 row 20:30:46Z, first s322 row 00:20:57Z).

**Scope.** In-session time only. Idle time between a handoff and the next `/ai-dlc resume` is
excluded by operator ruling and appears in no figure.

**Dollars** are API-list-equivalent at the prices in `roll.py`. A local-model lead call is priced at
the hosted lead mix it replaced (token-equivalent). s322's lead ran only local models
(`qwen38flash`, `deepseek41`), so its lead dollars use s321's hosted mix and are marked FALLBACK.
`roll.py` now recognises those two model names; before the change s322's lead priced at $0.

**Stories.** graph `sprint-status.yaml` at each close: s318 13, s319 20, s320 13, s321 25
(24 done). s322 has 8 planned.

**Controls.**

| Control | Expected | Got |
|---|---|---|
| Segment tokens = per-transcript tokens | equal | 23,818,644,955 = 23,818,644,955 |
| Subagents joined to a parent step | all | 6,018 of 6,018 |
| Adding the s321/s322 edge leaves s317–s320 unchanged | identical per-sprint sums | identical on every numeric field of `segs.jsonl`; only s321 split |
| Recognising the local model names moves only s322 | one line differs | s322 token-equivalent $817 → $1,063; no other sprint moved |
| Class tokens = segment tokens | all pairs | 432 of 432 (lead unit, step) pairs |

**Three instrument corrections made here.** Each changes how earlier figures should be read.

- **"Lead active" contains idle waiting.** `extract.py` calls every inter-record gap of 300 s or less
  active. `lead_time.py` splits it: an interval that follows the harness's end-of-turn record is the
  lead sitting idle until a subagent notification wakes it. That is 25–41% of "active" in every
  sprint (21.7 h of 62.2 h in s321). BL-819's premise, that the lead's own hours are most of the
  wall clock, is overstated by that share.
- **A spawn's duration contains resume idle.** `spawns.jsonl` records first-to-last timestamp. A
  finished agent the lead later resumes sits idle in between: one 8-minute serial-lane remediator read
  as 5.7 h. `poles.py` cuts each subagent's timeline at a resume message and drops the idle span
  (22.3 h in s321, 20.2 h in s322). `decompose.py`'s agent-minutes per spawn still include it.
- **Model time hides behind harness records.** The first record written when a response arrives is
  often an attachment, not the assistant record. `lead_time.py` reports "model" and "harness"
  separately; the two together are the lead's turn time, and the split between them is not reliable.

**Not measured.** Resident role-file bytes and hook injection were not re-taken. The deploy-validate
step's 29.9 h in s321 is not decomposed. s322 is partial: implementation is in progress and
sprint-review, deploy-validate and retro have not run.

## Sprint totals (pipeline bucket)

| | s317 | s318 | s319 | s320 | s321 | s322 (partial) |
|---|--:|--:|--:|--:|--:|--:|
| Stories | 21 | 13 | 20 | 13 | 25 | 8 planned |
| In-session hours | 112.8 | 74.8 | 110.0 | 117.8 | 120.5 | 56.6 |
| of which long waits on agents | — | 28.3 | 38.2 | 27.0 | 38.6 | 21.6 |
| of which operator wait | — | 14.3 | 17.0 | 47.9 | 24.9 | 8.8 |
| Token-equivalent $ | 2,357 | 1,721 | 2,234 | 1,623 | 2,388 | 1,063 |
| Hours per story | 5.4 | 5.8 | 5.5 | 9.1 | **4.8** | — |
| $ per story | 112 | 132.4 | 111.7 | 124.9 | **95.5** | — |
| Subagent spawns per story | 44.5 | 71.5 | 78.0 | 84.8 | 49.4 | — |
| $ per spawn | 1.98 | 1.53 | 1.13 | 1.14 | 1.52 | 1.57 |
| Lead compactions | — | 24 | 44 | 36 | 57 | 50 |

Source: `out/roll.txt`, `out/decompose.txt`. s317 is from the s317–s320 README.

Spawns per story fell 37% from s319 to s321. The price per spawn rose 35% over the same span,
because dev and QA moved from haiku to sonnet (BL-838) and the adversary moved to sonnet/high.

### Per step, per sprint (elapsed hours / token-equivalent $)

| Step (with its gate) | s318 | s319 | s320 | s321 | s322 |
|---|--:|--:|--:|--:|--:|
| carry-over-evaluation | 2.8 / 132 | 3.2 / 110 | 24.8 / 191 | did not run | 26.5 / 418 |
| requirements | 6.3 / 335 | 9.1 / 286 | 7.3 / 210 | 12.5 / 314 | 4.4 / 112 |
| architecture | 4.9 / 191 | 14.9 / 221 | 28.7 / 132 | 10.4 / 305 | 6.0 / 140 |
| stories-test-strategy | 25.6 / 415 | 16.9 / 586 | 15.1 / 627 | 20.2 / 678 | 7.8 / 221 |
| implementation | 11.8 / 423 | 41.8 / 825 | 25.2 / 270 | 28.2 / 638 | 8.8 / 123 (in progress) |
| sprint-review | 6.7 / 148 | 2.7 / 117 | 2.1 / 20 | 3.5 / 236 | not reached |
| deploy-validate | 5.5 / 25 | 4.9 / 33 | 7.3 / 128 | 29.9 / 177 | not reached |
| retro | 3.8 / 19 | 8.9 / 25 | 3.4 / 29 | 3.1 / 18 | not reached |

Source: `out/roll.txt`. s322 dollars include the FALLBACK-priced local lead.

Planning (the first four rows) cost $1,073 in s318, $1,203 in s319, $1,160 in s320 and $1,297 in
s321. It has not fallen in any sprint. s322's carry-over evaluation, at $418 and 26.5 h, is the
most expensive single step it has run and the most expensive carry-over evaluation measured.

## Where s321's 120.5 hours went

| Share | Hours | What |
|---|--:|---|
| Waiting on subagents | about 60 | 38.6 h in gaps over 5 minutes, plus 21.7 h of idle waits under 5 minutes that were counted as lead-active |
| Lead turn time | about 35 | 8,005 lead API calls at about 16 s each (model plus harness) |
| Operator answers | 24.9 | 57 `AskUserQuestion` calls; 6 waited over an hour |
| Lead tool execution | 4.9 | 1.1 h of it is `AskUserQuestion` under 5 minutes |

Source: `out/roll.txt`, `out/lead_time.txt`. `lead_time.py` reads every lead transcript (62.2 h
"active"); the pipeline bucket's active is 57.0 h, so the rows sum to slightly more than 120.5.

**Which seat the lead was waiting on.** `poles.py` measures the wall clock during which every
running subagent had the same role, so that role alone was holding the step open.

| Solo-role hours | s318 | s319 | s320 | s321 | s322 (partial) |
|---|--:|--:|--:|--:|--:|
| adversary | 6.3 | 6.5 | 6.7 | **15.7** | **11.4** |
| remediator | 7.8 | 11.9 | 9.4 | 9.6 | 9.1 |
| code-reviewer-escalated | — | 3.3 | — | 4.5 | — |
| dev or dev-escalated, the larger | 3.8 | 4.4 | 2.6 | 4.0 | 1.1 |
| ops | — | — | 2.4 | 3.8 | — |
| Wall clock with exactly one agent running | 20.5 | 26.5 | 20.1 | 28.8 | 16.4 |
| Wall clock with any agent running | 36.6 | 50.3 | 35.5 | 55.9 | 29.0 |

Source: `out/poles.txt`. Half of the time any subagent is running, exactly one is.

## Did each optimization have its intended effect?

Landing versions and first-sprint attribution are from the backlog entries, `CHANGELOG.md` and
graph's reconcile merges. The efficiency releases 0.782.0–0.787.0 reached graph on 10-14/15, so
s317 and s318 ran before them. s321 forked from a base carrying everything through 0.969.0.

### Worked

| Fix | Entry | Intended | Measured |
|---|---|---|---|
| Subagent `sleep` polls denied | BL-514 (0.782.0) | remove 5.4–12.4 h of subagent wall clock | Subagent `sleep`: 3.0 h (s317), 3.9 h (s318), then 0.28 h (s321) and none in s322's top families. `out/bash_by_sprint.txt`. |
| Cap-rejected spawns held, not re-sent | BL-515 (0.784.0) | stop re-sending rejected spawns | Rejections: 53 (s318), 7 (s319), 0 (s320), 0 (s321), 0 (s322). `out/cap_rejections.txt`. |
| Delta re-review, capture files out of the gate-1 partition, record-only route | BL-507, BL-808, BL-809 (0.785.0, 0.948.0, 0.952.0, 0.989.0) | BL-808's projection: about 20.2 implementation spawns and $23.4 per story | Gate-1 shards per pass: 3.3 (s318), 5.5 (s319), 1.9 (s320), 1.4 (s321). Implementation subagent spawns per story: 31.5 (s319) → 11.2 (s321). Subagent $ per story: $30.7 → $17.9. Step total per story: 2.09 h and $41.3 (s319) → 1.13 h and $25.5 (s321). Against the s317+s318 baseline of 1.59 h and $35.2 that is −29% hours and −28% dollars. `out/impl_passes.txt`, `out/decompose.txt`. |
| Party-round waves sized from the cap and refilled on exit | BL-695 (0.857.0) | remove the per-seat barrier pole from the stories party round | Round wall clock, first seat spawned to last seat ended: 196.3 min over two lead sessions (s319, 100 seats, 4 roles one after another) → 27.7 min in one session (s321, 104 seats, all 4 roles dispatched within 20 s). s321 had 4 cross seats against 24, so the cut is not wave sizing alone. Round subagent $ per story: $5.24 → $4.78. stories-test-strategy step alone per story: s319 0.78 h and $25.0, s321 0.79 h and $26.9, so the step cost did not fall. `out/roll.txt`; the round cut is a scratch reader over `spawns.jsonl`. |
| Scripted gate transition | BL-913 (0.1006.0) | fewer lead hand calls per gate | Lead gate-run time per story: 0.13 h (s321) → 0.06 h (s322). `gate-transition.sh` ran 149 times in s321 and 41 in s322. Partial sprint. |

Re-review **passes** did not fall. Gate-1 passes per reviewed story were 1.67 (s317), 3.16 (s319)
and 2.13 (s321); only 8 of 24 s321 stories passed gate 1 first time. The fixes made each pass cheap,
not rare.

### No measurable effect

| Fix | Entry | Measured |
|---|---|---|
| Hold a lane's question while other lanes advance (prose) | BL-841 (0.968.0) | The entry's own s321 reading stands: 0 of 24 asks named a held lane. Operator wait was 24.9 h over 57 asks in s321 and 8.9 h over 17 in s322. |
| Cross groups collapsed to one agent in stories elicitation | BL-811 (0.948.0, 0.952.0) | Stories elicitation, adversary plus remediator: $162 for 20 stories in s319 ($8.1 each), $65 for 13 in s320 ($5.0), $149 for 25 in s321 ($6.0), $49 for 8 in s322 ($6.1). The adversary rebinding moved in the same window, so the collapse is not separable. |
| Snapshot writes through one program | BL-819 L3, BL-912 (0.952.0, 0.1012.0) | Lead snapshot time per story: 0.25–0.26 h in s317–s319, 0.35 h (s320), 0.26 h (s321), 0.21 h (s322). The program ran 756 times in s321 and 802 times in s322, which is 100 calls per planned story. The hand edits stopped; the call count did not fall. |
| Repairs carry a `siblings:` field and a serial lane | BL-508, BL-716 | Solo-remediator wall clock is 9.4–11.9 h in every sprint from s319 on. |
| Idle share of ask-wait minutes (no lane active during an operator ask) | BL-841 (0.968.0) | Ask-wait minutes with no lane active, of ask-wait minutes: 96.9% (s320, 2956.8 of 3051.8) → 93.7% (s321, 1453.6 of 1552.0); the other sprints read 97.2% (s317), 96.4% (s318), 94.3% (s319), 96.3% (s322 partial). The share did not fall by the 5.0-point rule; the drop in raw idle minutes is the asks' own wait shrinking. |
| Story evidence sections, the dev's full-collection handoff and the QA precondition | BL-397 (0.674.0) | Implementation plus its gate, per story, gap-inclusive h / token-equivalent $: BL-397 step group did not fall across the post-fix sprints. Before (s314+s315, 9 stories, `pipeline-efficiency-s317-s320/b244-snapshot/steps.csv`) 2.00 / $29.0; s317 2.02 / $37.0, s318 0.91 / $32.5, s319 2.09 / $41.3, s320 1.94 / $20.7, s321 1.13 / $25.5 (re-extract whose roll.txt is `out/roll.txt`). The before sits inside the post-fix range. s314 alone is 3.87 / $48.7, s315 alone 0.50 / $13.3. |

The ask-wait row is `ask_split.py`'s per-sprint `LANE-IDLE` line in `out/ask_split.txt` (BL-841 claim 1): each `AskUserQuestion`
wait, `tool_use` to `tool_result`, less the time any subagent of the same lead session was active (its records
merged at extract.py's 300 s gap, no tail), totals summed in seconds. One s321 ask present in two lead files is
counted once, so s321 is 56 asks where `operator_asks.py` gives 57.

### Not yet measurable

| Fix | Entry | State |
|---|---|---|
| Narrow a convergence pass after the first; cap at pass 3 | BL-911 (0.1008.0) | First binds in s322. **Depth fell:** s321 stories ran to pass 6 and architecture to pass 5; s322 architecture and stories stopped at pass 3 and carry-over at pass 3. s322 requirements has spawns labelled pass 4. **Width did not narrow:** s322 requirements ran 10, 10 and 10 adversaries on passes 2–4, and architecture 5, 5 and 5. Closes on the s322 outcome line. |
| Carry-over cross groups collapsed | BL-810 | s321 ran no carry-over evaluation. s322's ran at $418 and 26.5 h, the highest measured, under the sonnet/high adversary. |
| Dev seat to sonnet | BL-838 (0.968.0) | Gate-1 passes per story 1.80 (s320, haiku) against 2.13 (s321, sonnet). Different stories; no direction supported. |

### Made it worse

**The adversary seat's move to sonnet/high (BL-832, 0.954.0).** graph's settings took the same
binding on 2026-10-27 (`7759588aa`), so s321 and s322 ran on it throughout.

| Adversary seat | s319 | s320 | s321 | s322 (partial) |
|---|--:|--:|--:|--:|
| Binding | opus/medium | opus/medium | sonnet/high | sonnet/high |
| Spawns | 294 | 294 | 272 | 124 |
| Median minutes | 6.2 | 5.0 | 8.9 | 11.7 |
| p90 minutes | 16.8 | 14.5 | 51.3 | 61.5 |
| Minutes per API call | 0.37 | 0.37 | 0.67 | 0.48 |
| Summed hours | 40.3 | 33.9 | 83.7 | 45.3 |
| $ | 561 | 501 | 609 | 359 |
| $ per spawn | 1.91 | 1.70 | 2.24 | 2.90 |
| Spawns over 45 minutes | 2 | 1 | 33 | 19 |

Source: `out/seats_adversary.txt` (`seats.py`), adversary rows by `model_ran` and `effort_bound`. Summed hours include
resume idle, which is about 3 h of s321's 83.7.

Inside the 33 long s321 runs, 14.2 of 35.2 hours are single API requests averaging 66 s each, with
11,000–12,500 output tokens of thinking per call. The time is the model at high effort, not tools.
A parallel round ends when its slowest shard does, so a p90 of 51 minutes sets the round's length.

Confidence is MEDIUM: the sprints reviewed different subjects, and s321 ran more elicitation. The
per-call figures are properties of the binding and do not depend on the subject.

## Opportunities

Ranked by wall clock, on s321 as the basis. Hours are in-session wall clock unless marked
agent-hours. Each row is sent to the batch lead for a backlog id.

### DEFECT

| # | Opportunity | Hours | $ per sprint | Confidence | Evidence |
|--:|---|---|---|---|---|
| 1 | **Rebind the adversary seat.** Return it to opus/medium, or measure sonnet/medium against it on one planning step. | about 9 h of wall clock; about 50 agent-hours | about $120 | MEDIUM | Solo-adversary wall clock 15.7 h against 6.5–6.7 h; 272 spawns × ($2.24 − $1.80) |
| 2 | **Operator questions hold the sprint.** The prose fix measured null. A mechanism is owed: the lead keeps every lane not named in the question moving, and questions raised in one round go out together. | up to 24.9 h | $0 | MEDIUM | 57 asks, 6 over an hour; s320 was 47.9 h |
| 3 | **Lead bookkeeping calls.** `wait-for-deliverable.sh` (922), `snapshot-update.sh` (756) and `gate-transition.sh` (149) are 1,827 of the lead's 8,005 calls. Each lead call costs about 16 s and $0.064. Fold the snapshot write into the programs that already know the state change, and block on a round instead of polling it. | up to 8 h | up to $117 | MEDIUM | `out/lead_time.txt`, `out/bash_by_sprint.txt`. Upper bound: assumes one tool call per lead turn |
| 4 | **Serial repair tails.** One remediator, or one fan-in writer, holds a round open after the parallel work ends. | up to 9.6 h | about $0 | MEDIUM | Solo-remediator 9.6 h (s321), 9.1 h (s322 partial); a 73-minute "Fan-in writer" in s322 |
| 5 | **A record-format refusal is found at the join, not by the writer.** The agent finishes, the lead joins, the join refuses a provenance or `edit:` line, and the lead resumes the agent to fix one line. Run the join's own check inside the agent before it seals its part. | 29 loops; 15.7 agent-hours idle before the resume (4.5 h in s321, 11.2 h in s322) | about $30 | MEDIUM | `out/resumes.txt` |
| 6 | **A subagent killed by an API error is noticed an hour later.** Five remediators dispatched together at 11-09T17:54Z died on a connection error and were resumed at 19:00–19:08Z. Nothing reports an agent whose last record is an open request. | 1.2 h per event | $0 | HIGH for the event; frequency is one in two sprints | `out/resumes.txt`: four resume messages reading "terminated on an API connection error", mean 63 minutes idle |
| 7 | **A wrong shard directory in the dispatch brief.** In s321 architecture the lead sent "the merge requires shard dir …" corrections to ten adversaries that had finished and were waiting, up to 58 minutes. | about 1 h per event | $0 | HIGH for the event | Ten resume gaps, 3.0 agent-hours |

### NOTE

| # | Opportunity | Hours | $ per sprint | Evidence |
|--:|---|---|---|---|
| 8 | First-pass gate-1 failures: 16 of 24 s321 stories needed a second pass. Each is a dev resume, a re-review and a lead round trip. | 13.1 agent-hours idle across 37 rework resumes | $80 on passes 2–7 | `out/impl_passes.txt` |
| 9 | `validate-mutation-red.sh` slowed from 4–7 s to 11 s a call in s321 (1,010 calls). | 3.1 agent-hours | not measured | `out/bash_by_sprint.txt` |
| 10 | `validate-spawn-ledger.sh` takes 42 s a call in subagents and reads a 9,447-row ledger that only grows. | 1.0 agent-hours | not measured | same |
| 11 | graph's `git push` takes 37–91 s in the lead (39 calls in s321). | 0.4 h | $0 | same; consumer-side gate |
| 12 | deploy-validate ran 29.9 h elapsed in s321 with 8.7 h active and 3.8 h of solo `ops`. Not decomposed. | not measured | $177 | `out/roll.txt` |
| 13 | The local-model lead compacts about once an hour: 50 compactions in 56.6 h of s322 against 57 in 120.5 h of s321. Recovery is 0.06 h per story. It also made 831 lead calls per planned story against 320 in s321, at 9.4 s a call against 15.9 s. | 0.5 h | $0 | `out/roll.txt`, `out/classes_summary.txt` |

Rows 1 and 4 overlap: a faster adversary shortens the rounds the remediator then repairs. Rows 3
and 13 overlap: fewer lead calls means fewer compactions.

## What this changes in the earlier analyses

- **BL-819** states the lead's own hours are most of the wall clock. Under the split above the lead's
  turns are about 29% of s321 and waiting on subagents is about 50%.
- **BL-812's** per-story baseline of 4.7–4.8 machine hours was flat through s319. s321 reads 4.8 h
  per story on gap-inclusive hours against 5.5 h for s319 on the same basis.
- **`decompose.py`'s** agent-minutes per spawn include resume idle and should not be read as run time.

## Reproduce

```
OUT=<scratch dir>; export EXTRACT_WIN_END=2026-11-11T10:30:00Z
A=docs/analysis/pipeline-efficiency-s317-s318/scripts
B=docs/analysis/pipeline-efficiency-s317-s320/scripts
C=docs/analysis/pipeline-efficiency-s317-s322/scripts
python3 -I $B/extract.py $OUT && python3 -I $A/spawns.py $OUT && python3 -I $A/analyze.py $OUT
python3 -I $B/roll.py $OUT; python3 -I $B/roll.py $OUT --classes
python3 -I $B/decompose.py $OUT; python3 -I $B/impl_passes.py $OUT 317,318,319,320,321,322
python3 -I $B/cap_rejections.py; python3 -I $B/operator_asks.py
python3 -I $C/poles.py $OUT          # which role holds the lead's wall clock
python3 -I $C/lead_time.py           # lead active time: model, tool, idle wait
python3 -I $C/bash_by_sprint.py      # Bash wall clock by command family, per sprint
python3 -I $C/seats.py $OUT adversary # one seat by the binding it ran on, and passes per step
python3 -I $C/resumes.py $OUT        # why finished subagents were resumed, and the idle before it
python3 -I $C/ask_split.py $OUT      # BL-841/BL-972: each AskUserQuestion wait by what the lanes did during it, and its lane-idle minutes
python3 -I $C/serial_tail.py $OUT    # BL-716: which serial step the solo-remediator hours sit in (out/serial_tail.txt)
```

**The solo-remediator hours, decomposed (BL-716).** `serial_tail.py` reproduces `poles.py`'s remediator
solo-role total per sprint (its self-check line) and splits it. Of 9.37/9.62/9.15 h in s320/s321/s322,
7.08/7.37/7.27 h had ONE remediator alive. Joined to the round-one join that the same lead session printed
before each spawn, that width-1 time sits in rounds whose join printed `LANE-COUNT: 1` (4.03/3.74/5.48 h:
document mode maps every section to one assembled document, so a file-keyed lane can never split it) and in
the fan-in after a multi-lane round (2.19/2.46/1.51 h). A straggler lane is 0.51/0.15/0.12 h. Of those
agents' time, writer turns (an Edit/Write, the mark, the join) are 35/29/33% and the rest is read-only
adjudication. That puts the predicted width-1 tail with adjudication split from writing at
4.78/4.74/4.84 h (k=2) and 3.63/3.43/3.63 h (k=4). This is an UPPER BOUND: it assumes even item splits and
counts the time that decides an edit as writer time.

Every script reads `~/.claude/projects/-Users-n8-git-graph`, except `seats.py`, which reads only its OUT
argument. `extract.py`, `cap_rejections.py` and the other six scripts in the s317–s322 directory honour
`EXTRACT_ROOT`; `spawns.py`, `decompose.py`,
`operator_asks.py`, `bash_cost.py` and `resident.py` have the path hard-coded.

To measure a rebinding on a later sprint: add the sprint's edge to `EDGES` in `extract.py` and its story
count to `STORIES` in `roll.py`, re-run the block above, and read `seats.py` for the rebound role beside
`poles.py`'s solo-role hours.
