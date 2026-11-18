# Pipeline efficiency: s323 so far (PROVISIONAL), and a clock defect in every earlier hours figure

Batch 259, cluster C4b, 2026-11-18. Requested by the operator after the s322-complete report
(`pipeline-efficiency-s317-s322-b259.md`) left s323 unread.

**Every s323 figure here is PROVISIONAL.** s323 is open. Its four planning steps have passed their gates;
implementation has closed 7 of 18 stories. Nothing here is an `Outcome measured:` line. The re-take at the
s323 close replaces it.

## Answer

1. **DEFECT (instrument, BL-1174). Each published hours figure for s317 to s322 falls by 8% to 20%.** The
   extractor's segment clock counted an out-of-order record's interval twice. On a monotone clock s322 is
   66.4 h, not 77.1 h, and s321 is 111.0 h, not 120.5 h. Dollars, tokens and call counts do not move. The
   sprint ordering does not change. s323 could not be read at all on the old clock (141.2 h against 45.8 h of
   session span), which is how the defect surfaced.
2. **Moved the right way: the adversary rebind (BL-971).** s323's 146 adversary spawns ran on opus/medium:
   median 5.6 minutes, 1 spawn over 45 minutes, $2.06 a spawn. s322's 124 ran on sonnet/high: median 11.7
   minutes, 19 over 45 minutes, $2.89 a spawn. Adversary agent-hours fell from 45.3 to 16.4 with more spawns.
3. **Moved the right way: snapshot calls (BL-912), on calls only.** In the stories step, the first to run the
   one-call rule, snapshot calls are 110 against s322's 198. Lead time in the class is flat (0.29 h against
   0.28 h).
4. **Planning wall clock: flat in total, down once operator wait is taken out.** Planning took 39.6 h and
   $1,071, against 36.9 h and $889 in s322 and 40.8 h and $1,298 in s321. Less operator answer time it is
   27.0 h, against 30.0 h and 36.8 h. Hours with a subagent running fell to 17.7, from 22.1 and 30.4.
5. **Not improved: the lead's call volume in planning.** 4,623 lead calls against 4,287 (s322) and 2,729
   (s321). Step re-reads, compaction-recovery calls and merge calls all rose. Compactions are 75 in 45.8 h,
   against 72 in 66.4 h.
6. **Not moved: operator questions (BL-972).** 0 of 15 pipeline asks held a lane, as in s322. Three asks
   account for 10.8 of the 13.1 hours of answer wait, and in each one the running lanes finished and then
   waited.
7. **Moved the wrong way: the single-lane remediator.** 9.88 solo hours already, against 9.24 for all of s322.
8. **Too early to call: implementation.** 4.9 h and $200 with 7 of 18 stories closed. The closed stories are
   the early closers.

## Population and method

- Graph `/Users/n8/git/graph` and its transcripts, read only. Graph ref `e70a344c0` (the story 5.4 gate-3
  close, 2026-11-18T17:53:50Z).
- Pin `EXTRACT_WIN_END=2026-11-18T17:54:00Z`. The lead transcript was still being written; records after the
  pin are dropped.
- Sprint boundary: the last s322 lead record is 2026-11-12T14:40:12Z (e444bf13) and the first s323 lead record
  is 2026-11-13T08:16:50Z (0ef7ba46). `extract.py`'s existing edge, 2026-11-13T08:00Z, sits between them. No
  edge was edited.
- In-session time only. Idle time between a handoff and the next resume is excluded, as in the earlier
  reports.
- Step completion is read from graph's own gate commits: carry-over evaluation 2026-11-17T03:02Z, requirements
  2026-11-17T20:45Z, architecture 2026-11-18T03:36Z, stories 2026-11-18T12:46Z.
- Story count: 18 story files under `_bmad-output/planning-artifacts/s323/stories` at `e70a344c0`. Per-story
  figures are given for planning only, where that count is fixed.
- s323's lead ran only local models, so its token-equivalent dollars use s321's hosted lead mix, as s322's do
  (`roll.py` `FALLBACK`). API dollars are beside them.
- Hours are stated on the monotone clock (`EXTRACT_MONOTONE_SEGS=1`), with the default clock beside them where
  they differ.
- No timing run was taken.

### Which engine each step ran

Reconcile commit times are graph's, in UTC.

| Step | Lead session | Engine |
|---|---|---|
| carry-over evaluation, first session (2026-11-13) | 0ef7ba46 | 0.1101.0 (reconciled 2026-11-13T06:57Z) |
| carry-over evaluation, second session; requirements | 68cf8de7, 4b34031d | 0.1160.0 (2026-11-16T23:02Z) |
| architecture | 4b34031d, then 53b4296a for the gate | 0.1160.0, then 0.1164.0 for the gate |
| stories-test-strategy; implementation | 53b4296a | 0.1164.0 (2026-11-18T02:05Z) |

A fix shipped after 0.1160.0 is read on the stories step and implementation only.

### The clock defect

`extract.py` measured each segment interval from the previous record, whatever its timestamp. A record
stamped earlier than its predecessor charged nothing, but the next record then charged the whole interval
again. s323's transcripts replay a burst of `attachment` records, stamped before an operator pause, after
the record that ends the pause. In lead 68cf8de7 one 4.73-hour pause was charged about fifteen times, and
requirements read 89.6 h.

`Classer.interval()` in the same file already used a monotone clock, which is why `roll.py --classes` has
always printed an "out-of-order overcount" line. The segment clock was never changed to match.

This release adds `EXTRACT_MONOTONE_SEGS=1`. It is off by default, so every committed output still
reproduces. Controls:

- Default clock, edited scripts, old pin (`2026-11-12T14:41:00Z`): `roll.txt` and `roll_classes.txt` are
  `cmp`-identical to the committed b259 outputs.
- Default clock at the new pin: the s317 to s322 `TOTAL` lines are identical to the old pin's, line by line.
  The new pin therefore moves no earlier sprint, and the monotone figures below hold at either pin.
- Monotone clock, s323: the total is 45.8 h, and the four lead sessions' first-to-last spans sum to 45.8 h.
  The default clock's 141.2 h exceeds the span, which no correct clock can.
- Dollars, tokens and lead calls: equal between the two clocks for every sprint (`out/s323_provisional.txt`,
  the `EQUAL` column).
- `spawns.jsonl`, `classes.jsonl`, `units.jsonl`, `owner.json` and `tools.jsonl` are `cmp`-identical between
  the default-clock and monotone-clock runs, and `segs.jsonl` differs. So every reader that does not read
  segment hours gives the same answer on either run.

| Sprint | Published (default clock) | Monotone clock | Change |
|---|--:|--:|--:|
| s317 | 80.8 h | 72.8 h | −10% |
| s318 | 74.8 h | 59.6 h | −20% |
| s319 | 110.0 h | 94.0 h | −15% |
| s320 | 117.8 h | 99.2 h | −16% |
| s321 | 120.5 h | 111.0 h | −8% |
| s322 | 77.1 h | 66.4 h | −14% |
| s323 to the pin | 141.2 h | 45.8 h | −68% |

Operator wait is almost unchanged (s322 10.3 h on both clocks). The overcount sits in agent wait (s322 28.0 h
to 19.7 h) and in active time (38.8 h to 36.4 h). Regenerating every committed output on the monotone clock is
BL-1174, owed at the s323-close re-take.

Not measured: `pipeline-efficiency-s317-s318.md` uses its own copy of the extractor, which has the same clock
(`pipeline-efficiency-s317-s318/scripts/extract.py:81`). Its figures were not re-run; the run was available.

## Planning: the four completed steps

Monotone clock. Each step includes its own gate. Elapsed = lead active + operator wait + agent wait. Source:
`out/s323_provisional.txt`.

"Active" is lead time with no gap over 300 seconds between records. It includes short waits on subagents, so
it is not a measure of lead work, and "agent wait" counts only waits longer than 300 seconds. s323's
implementation reads 4.9 h active and 0.0 h agent wait with 151 spawns running. The split is shown for
completeness; the comparisons below use elapsed hours, hours with a subagent running, and call counts.

| Step | Sprint | Elapsed h | active + operator + agent | Token-eq $ (API $) | Lead calls | Spawns | Default clock h |
|---|---|--:|---|--:|--:|--:|--:|
| carry-over evaluation | s322 | 13.7 | 3.9 + 5.7 + 4.2 | 231 (191) | 1,050 | 112 | 19.5 |
| | s323 | 11.8 | 4.3 + 6.3 + 1.2 | 207 (173) | 828 | 89 | 25.7 |
| requirements | s321 | 11.1 | 6.2 + 1.9 + 3.1 | 314 (314) | 813 | 168 | 12.5 |
| | s322 | 9.9 | 5.3 + 1.2 + 3.4 | 297 (250) | 1,202 | 128 | 10.7 |
| | s323 | 13.5 | 5.2 + 6.2 + 2.1 | 274 (224) | 1,178 | 179 | 90.0 |
| architecture | s321 | 10.0 | 4.1 + 0.0 + 5.8 | 306 (306) | 560 | 122 | 10.4 |
| | s322 | 5.8 | 2.9 + 0.0 + 2.9 | 140 (110) | 687 | 68 | 6.0 |
| | s323 | 5.2 | 3.8 + 0.0 + 1.4 | 173 (130) | 1,021 | 67 | 6.0 |
| stories-test-strategy | s321 | 19.7 | 9.2 + 2.1 + 8.3 | 678 (660) | 1,356 | 431 | 20.1 |
| | s322 | 7.5 | 4.3 + 0.0 + 3.3 | 221 (169) | 1,348 | 125 | 7.8 |
| | s323 | 9.1 | 7.2 + 0.0 + 1.9 | 416 (348) | 1,596 | 264 | 11.5 |

Planning as a whole:

| | s321 (25 stories) | s322 (8) | s323 (18) |
|---|--:|--:|--:|
| Elapsed h | 40.8 | 36.9 | 39.6 |
| Elapsed h less operator wait | 36.8 | 30.0 | 27.0 |
| Hours with at least one subagent running | 30.4 | 22.1 | 17.7 |
| Subagent hours, summed | 116.5 | 65.9 | 47.4 |
| Adversary alone (no other subagent running) h | 15.6 | 10.8 | at most 2.6 |
| Remediator alone h | 9.6 | 7.8 | 9.5 |
| Token-eq $ (API $) | 1,298 (1,279) | 889 (720) | 1,071 (876) |
| Lead calls | 2,729 | 4,287 | 4,623 |
| Spawns | 721 | 433 | 599 |
| Per story: h, less operator wait | 1.47 | 3.75 | 1.50 |
| Per story: token-eq $ | 51.9 | 111.1 | 59.5 |
| Per story: lead calls | 109 | 536 | 257 |

The subagent rows are the four planning steps without their gates, from `out/poles_allroles.txt` (`busy`,
`serial` and `solo-role`). s321 had no carry-over step. s323's stories step does not list the adversary among
its top three solo roles, so its share there is at most 0.4 h and the total is given as an upper bound.

What the table says:

- **Time with a subagent running fell.** 17.7 h, against 22.1 h in s322 and 30.4 h in s321, with more spawns
  than s322. The adversary's time alone fell from 10.8 h to at most 2.6 h. This is the rebind and is the clearest
  gain in the sprint.
- **The remediator did not follow.** Its time alone rose from 7.8 h to 9.5 h and it is now the largest serial
  role in every planning step.
- **The rest is the lead on its own.** Planning less operator wait is 27.0 h and a subagent was running for
  17.7 h of it, so at least 9.3 h had only the lead working, against at least 7.9 h in s322 and 6.4 h in s321.
- **Operator wait rose.** 12.6 h of planning was the operator's answer time, against 6.9 h in s322.
- **Per story, s323 matches s321 and is not better.** The 1.50 h and $59.5 a story are the s321 level. s322's
  figures were the cost of a small sprint, as the earlier report said.
- **Stories-step dollars follow story count.** $416 for 18 stories is $23.1 a story, against $27.6 (s322) and
  $27.1 (s321).

## Fix by fix

Tiered on consequence. "Read on" names the steps that ran the fix.

### DEFECT

| Fix | Read on | s322 | s323 so far | Direction |
|---|---|---|---|---|
| **Adversary on opus/medium** (BL-971, 0.1048.0) | all planning steps | 124 spawns on sonnet/high: median 11.7 min, p90 61.5 min, 19 over 45 min, 45.3 agent-h, $359, $2.89 a spawn | 146 spawns on opus/medium: median 5.6 min, p90 11.3 min, 1 over 45 min, 16.4 agent-h, $301, $2.06 a spawn | **right**: about 29 agent-hours and $58 removed with 22 more spawns |
| **Join-refusal resumes** (same rebind; the slow adversary missed its join) | all planning steps | 16 resumes, 11.2 agent-h idle | 4 resumes, 0.4 agent-h idle | **right** |
| **Dispatch then ask** (BL-972; 0.1092.0 live throughout, 0.1145.0 from 2026-11-16T18:25Z) | pipeline asks only | 19 asks, 9.4 h; 0 held a lane; 8 of 19 dispatched at the ask | 15 asks, 13.1 h; 0 held a lane; 6 of 15 dispatched at the ask (2 of 6 before 0.1145.0, 4 of 9 after) | **none that this count can resolve**: no lane is held, and the three long waits remain |
| **Lead call volume** (BL-819; no fix landed that targets it) | planning | 4,287 calls; `other` 2,010; merge 1,031; step re-reads 220; compaction recovery 179 | 4,623 calls; `other` 1,932; merge 1,438; step re-reads 292; compaction recovery 198 | **not improved**: 257 calls a story against s321's 109 |
| **Compactions** (BL-819) | whole sprint | 72 in 66.4 h, 1.1 an hour | 75 in 45.8 h, 1.6 an hour | **wrong** |
| **Single-lane remediator** (BL-716, not built) | planning | 9.24 solo h for the whole sprint; 5.48 h in one-lane rounds | 9.88 solo h already; 6.20 h in one-lane rounds | **wrong**: now the largest serial pole, since the adversary no longer is |
| **Shard narrowing after pass 1** (BL-911, 0.1096.0) | all planning steps | not comparable (sonnet/high era) | adversary spawns by pass label: requirements 15 then 15; architecture 5 then 5; carry-over 4, 5, 4. No adversary pass past p3 | **unread**: pass 2 is as wide as pass 1, which is correct if every part changed. The changed-part count was not joined |

The three long asks: 148 minutes (carry-over, 2 lanes running), 200 minutes (carry-over, 1 lane) and 300
minutes (requirements, 14 lanes). In each, the lanes finished inside the wait and their results sat until the
answer came. That is 10.8 h, and it is exactly BL-972's subject. Asks with a lane finishing inside account for
676 of s323's 783 pipeline ask minutes (86%), against 44 of 562 (8%) in s322.

The ask reader (`out/ask_split.txt`) also counts asks in update sessions, which it labels `pre-step`: 8 of its
23 s323 asks and 11 of its 30 s322 asks. They are excluded above, on both sides. Its lanes-idle share (94.4% for s323) is over
all 23 and was not recomputed for the 15.

Remediator spawns carrying no pass label number 74 in requirements and 79 in stories (`out/seats_adversary.txt`).
What they are was not read; the transcripts were available.

### NOTE

- **One-call snapshot rule** (BL-912, 0.1163.0), read on the stories step only: 110 snapshot calls of 1,596
  (7%), against 198 of 1,348 (15%) in s322. Lead time in the class is 0.29 h against 0.28 h. Sprint to date the
  lead ran `snapshot-update.sh` 500 times, against 1,057 in all of s322; that count includes denied calls.
- **Gate-1 first pass** (BL-1166, not built): of 6 reviewed stories, 3 passed first time and 3 took two passes.
  s322 was 2 of 8 first time. 20 of 39 gate spawns did not parse, and these are the early closers.
- **Implementation to the pin**: 4.9 h, $200 (API $135), 1,491 lead calls, 151 spawns, 7 of 18 stories
  closed in the 5.1 hours after the stories gate. s322's whole implementation was 13.0 h and $223 for 8. Eleven
  open stories have already charged cost here, so no per-story figure is given.
- **Sprint to the pin**: 45.8 h, $1,304 token-equivalent, $1,033 API.

## Planning does not follow the work (BL-1175)

**DEFECT.** The intensity recorded in graph's pipeline snapshot was `full` for s321, `carry-over-single` for
s322 and `full` for s323. Planning was 40.8 h, 36.9 h and 39.6 h. The reduced tier bought nothing, and 8, 18
and 25 stories paid the same charge. In s322 planning was 36.9 of the sprint's 66.4 hours and $889 of its
$1,348, against 13.0 h and $223 to implement all eight stories.

The tier is set by story count (`core/skills/ai-dlc/steps/route.md:531`: three or more stories touching
service code is `full`). Nothing reads whether a story carries a new requirement or a new architecture
decision. A bug fix takes the same four document steps as a new subsystem.

BL-1175 is the single backlog entry for planning cost, by operator ruling; BL-1169, BL-1170 and BL-1171 are
folded into it as work items. Its first code item keys the tier on that, per story and not per sprint, so that in a mixed sprint only the
stories that need requirements or architecture work go through those steps. Its ceiling on s323 is the requirements and architecture steps,
18.7 h and $447, if no story needed either. The share that did need them is unread and is the entry's first
step.

## What this says about where to work next

The structural item is BL-1175, above. Inside the current structure, in order of wall clock on s323's
planning:

1. **The lead working with no subagent running** (at least 9.3 h, and rising across three sprints), with
   4,623 lead calls behind it. BL-819 owns it and has no landed fix that targets it.
2. **Operator answer wait with finished lanes behind it** (10.8 h in three asks, $0). BL-972's prose rule has
   now read null three times. The mechanism proposed in the earlier report (declare operator decisions at
   planning, ask them as one batch) is not built.
3. **The single-lane remediator** (6.2 h in one-lane rounds). BL-716.
4. **Pass 2 as wide as pass 1** (BL-911). 15 adversary spawns at requirements p2 cost $22 and 1.1
   agent-hours. Whether the narrowing should have removed any of them depends on how many parts the pass-1
   repair changed, which is the join still owed.

## Not read

Each was available and not taken: advisor calls for s323 (`advisor_server_tool_use.py` and
`operator_asks_pinned.py` stop at s322); the stories party round; cap rejections; `decompose.py`; the
readiness and trace calls that BL-1175's work items 3 and 4 name; which hook steps the lead's `git push` spends its time in.
The lead Bash families (`out/bash_by_sprint_top80.txt`) do not separate pipeline sessions from update
sessions, so only `snapshot-update.sh` is quoted from them.

## Reproduce

```
B=docs/analysis/pipeline-efficiency-s317-s320/scripts; A=docs/analysis/pipeline-efficiency-s317-s318/scripts
C=docs/analysis/pipeline-efficiency-s317-s322/scripts; D=docs/analysis/pipeline-efficiency-s317-s322-b259/scripts
E=docs/analysis/pipeline-efficiency-s323-provisional-b259/scripts
export EXTRACT_WIN_END=2026-11-18T17:54:00Z
for o in DEF MONO; do
  [ $o = MONO ] && export EXTRACT_MONOTONE_SEGS=1
  python3 -I $B/extract.py $o && python3 -I $A/spawns.py $o && python3 -I $A/analyze.py $o && python3 -I $B/roll.py $o
done; unset EXTRACT_MONOTONE_SEGS
python3 -I $E/s323_provisional.py DEF MONO
python3 -I $C/seats.py MONO adversary; python3 -I $B/impl_passes.py MONO 321,322,323
python3 -I $C/resumes.py MONO; python3 -I $C/ask_split.py MONO; python3 -I $C/serial_tail.py MONO
python3 -I $D/poles_allroles.py MONO; python3 -I $C/bash_by_sprint.py 80; python3 -I $C/lead_time.py
```

The committed reader outputs other than the two `roll` files were taken on the default-clock run; they read
spawns, classes and transcripts, none of which the segment clock touches.
