# Pipeline efficiency through graph sprint 323: what worked, where the time goes now, and what to do next

Measured 2026-11-20 (batch 261, cluster C10). This extends
[`pipeline-efficiency-s317-s322.md`](pipeline-efficiency-s317-s322.md), its batch 259 update
([`pipeline-efficiency-s317-s322-b259.md`](pipeline-efficiency-s317-s322-b259.md)) and the provisional s323
reading ([`pipeline-efficiency-s323-provisional-b259.md`](pipeline-efficiency-s323-provisional-b259.md)) through
graph s323, which closed on 2026-11-19. The s323 outcome readings themselves are on main as of 0.1185.0: batch 261's
[`pipeline-efficiency-s323-complete-b261.md`](pipeline-efficiency-s323-complete-b261.md) (C5), the gate and QA
readings (C6) under [`bl844-gate2-route-seats/`](bl844-gate2-route-seats/) and
[`step-value-b256/bl512/`](step-value-b256/bl512/), and [`s323-outcomes-b261/`](s323-outcomes-b261/) (C7). This
report reads them, adds new decompositions of s323 from seven readers, and ranks what is left. Nothing was
written to graph.

## Answer

1. **s323 is the fastest and cheapest sprint per story of s318 to s323 (s317's corpus is truncated): 4.2 h and $87.8 (API) a story**, against 4.4 h
   and $94.7 in s321 and 8.3 h and $123.7 in s322. It took 75.4 in-session hours for 18 stories.
2. **The largest measured change is the adversary seat's return to opus/medium.** The adversary held a round alone for
   3.2 h, against 11.5 h in s322 and 15.7 h in s321. Long waits on agents fell from 34.8 h (s321) to 8.9 h.
3. **The bottleneck is now the lead itself.** Of 75.4 h, 33.3 h is the lead's own work (25.2 h of it the local
   model generating), 15.4 h is the lead waiting on running agents, 17.9 h is waiting on the operator and 8.9 h
   is long waits on agents. The lead made 11,744 calls and compacted 134 times, a median 18 minutes apart (134 in 75.4 h).
4. **The local lead's speed is set by how much it writes, not how much it reads.** A call costs about 8.7 s per
   1,000 output tokens and does not slow with context size between 80K and 200K tokens. The fifth of calls that
   write 1,000 tokens or more hold 54% of its model time. The largest written item is the dispatch brief, which
   the lead types out for every agent.
5. **A memory wall on graph's test suite held implementation for hours.** Across eleven hours on 2026-11-18
   agents were refused when starting the suite because the host had less free memory than graph's admission
   rule needs.
   Agents spent 9.8 h in `wait-for-deliverable.sh` in s323, against 0.9 h in s322; about 6.8 to 7.0 h of it is
   agents retrying against that rule, and one QA agent alone is 4.6 h. What held the memory is not established.
6. **Operator wait is decided by whether the operator is present, and nothing notifies them.** "Keep other
   lanes moving" is worth about 30 minutes of s323's 17.9 h, which is why that rule measured null three times.
7. **Planning is still a fixed charge of about 40 hours.** Its remaining serial tails are worth about 2.8 h.
8. **Subagent dollars: 28% is context every spawn loads before it works.** About $300 a sprint of that is
   reachable.
9. **Nine fixes are built and have not yet run in a complete sprint.** s324 is their first reading.

## Population and method

- **Corpus.** `~/.claude/projects/-Users-n8-git-graph/`, read only, pin `EXTRACT_WIN_END=2026-11-20T04:20:00Z`.
  s323's window is 2026-11-13T08:00Z to the pin. Graph's close commit is `16fd227d9`.
- **Clock.** Hours are on the monotone clock (BL-1174), `extract.py` at the batch 261 C5 blob. A figure taken
  on the old clock is labelled.
- **Extraction control.** This report's extraction reproduces C5's committed `roll.monotone-clock.txt` byte for
  byte, and differs from its `roll.default-clock.txt`.
- **Scope.** In-session time only. Idle time between a handoff and the next resume is excluded by operator
  ruling. The eight `/ai-dlc-update` sessions that ran during s323 are outside the 75.4 h and are reported
  separately.
- **Dollars** are API-list-equivalent at `roll.py`'s prices. The lead ran local models and costs $0 on the API;
  its token-equivalent price is the s321 hosted mix (`FALLBACK`).
- **No timing run was taken.** Every figure is read from transcripts and records already on disk.
- **How the new readings were taken.** Seven read-only readers, one per subject, each with its own controls.
  [`pipeline-efficiency-s323-opportunities-b261/`](pipeline-efficiency-s323-opportunities-b261/) holds the
  scripts of five of them (lead time, tokens, operator asks, late steps, tool runtime) under `scripts/`, their
  small text result tables under `out/`, and a `README.md` that names each file, how to run it and what could
  not be recovered. The planning and implementation readers' scripts are not committed. No transcript data is
  committed. Claims this report rests on were re-checked against the tree; "Not verified" below lists what was
  not.
- **Every saving below is an UPPER BOUND unless it says otherwise**, on s323 as the basis.

## Sprint totals

| | s318 | s319 | s320 | s321 | s322 | s323 |
|---|--:|--:|--:|--:|--:|--:|
| Stories | 13 | 20 | 13 | 25 | 8 | 18 |
| In-session hours | 59.6 | 94.0 | 99.2 | 111.0 | 66.4 | 75.4 |
| of which lead active | 29.5 | 48.8 | 38.2 | 51.3 | 36.4 | 48.6 |
| of which operator wait | 14.0 | 17.0 | 47.6 | 24.9 | 10.3 | 17.9 |
| of which waits on agents over 5 minutes | 16.0 | 28.2 | 13.4 | 34.8 | 19.7 | 8.9 |
| Hours per story | 4.6 | 4.7 | 7.6 | 4.4 | 8.3 | **4.2** |
| API $ | 1,720 | 2,234 | 1,623 | 2,367 | 989 | 1,580 |
| Token-equivalent $ | 1,721 | 2,234 | 1,623 | 2,388 | 1,348 | 2,074 |
| API $ per story | 132.3 | 111.7 | 124.9 | 94.7 | 123.7 | **87.8** |
| Lead calls | 4,412 | 6,374 | 4,926 | 7,127 | 9,304 | 11,744 |
| Lead compactions | 24 | 44 | 36 | 57 | 72 | 134 |

Source: C5 `out/roll.monotone-clock.txt` and `out/s323_complete.txt`. s317 is not recomputed: graph's transcripts
before 2026-10-07 are gone from disk.

### Per step, s321 to s323 (elapsed h = lead active + operator wait + agent wait | token-equivalent $)

| Step (with its gate) | s321 | s322 | s323 |
|---|--:|--:|--:|
| carry-over-evaluation | did not run | 13.7 = 3.9 + 5.7 + 4.2, $231 | 11.8 = 4.3 + 6.3 + 1.2, $207 |
| requirements | 11.1 = 6.2 + 1.9 + 3.1, $314 | 9.9 = 5.3 + 1.2 + 3.4, $297 | 13.5 = 5.2 + 6.2 + 2.1, $274 |
| architecture | 10.0 = 4.1 + 0.0 + 5.8, $306 | 5.8 = 2.9 + 0.0 + 2.9, $140 | 5.2 = 3.8 + 0.0 + 1.4, $173 |
| stories-test-strategy | 19.7 = 9.2 + 2.1 + 8.3, $678 | 7.5 = 4.3 + 0.0 + 3.3, $221 | 9.1 = 7.2 + 0.0 + 1.9, $416 |
| implementation | 22.4 = 17.9 + 2.3 + 2.2, $638 | 13.0 = 9.5 + 2.0 + 1.5, $223 | 15.1 = 14.5 + 0.3 + 0.3, $575 |
| sprint-review | 2.9 = 2.9 + 0.0 + 0.0, $236 | 2.3 = 1.7 + 0.0 + 0.6, $101 | 11.1 = 5.6 + 4.2 + 1.3, $280 |
| deploy-validate | 29.0 = 8.2 + 18.2 + 2.6, $177 | 3.5 = 1.8 + 0.8 + 1.0, $27 | 5.3 = 4.0 + 0.9 + 0.4, $64 |
| retro | 3.1 = 1.0 + 0.0 + 2.1, $18 | 5.3 = 3.4 + 0.4 + 1.4, $51 | 2.7 = 2.6 + 0.0 + 0.1, $49 |

Source: C5 `out/s323_complete.txt`. Planning (the first four rows) is 40.8 h, 36.9 h and 39.6 h.

**s323's sprint review is not a pipeline regression.** Three stories (2.1, 2.2, 2.3) reached sprint review
labelled "operator-held" with no operator quote behind the label. The operator ruled "build all three now"
after a 3.25 h wait, and they were built and gated inside sprint review: about 3.4 h of lead-active time.

## Did each optimization have its intended effect?

"Built" is checked against shipping code under `core/` and the entry's `LANDED` or `PARTIAL` line. Graph's
engine during s323: carry-over's first session ran 0.1101.0; carry-over's second session, requirements and
architecture ran 0.1160.0; the architecture gate, stories and nearly all of implementation ran 0.1164.0 (77 of
84 gate plans); the last stories, sprint review, deploy-validate and retro ran 0.1174.0. The earlier reports'
"implementation ran 0.1164.0" is therefore true of all but its tail. Figures are quoted from the entries'
batch 261 readings.

### Worked

| Fix | Entry | s323 measured |
|---|---|---|
| Adversary seat back to opus/medium | BL-971 (0.1048.0) | 149 spawns: median 5.6 min against 11.7 (s322, sonnet/high), p90 11.6 against 61.5, $2.14 a spawn against $2.89, 17.1 agent-hours against 45.3, 1 spawn over 45 minutes against 19. Solo-adversary 3.2 h against 11.5 h |
| Dev seat on sonnet | BL-838 (0.968.0), closed | Against the pooled haiku sprints s318 to s320: gate-1 passes per story 2.41 to 1.78, gate-2 1.80 to 1.61, 7 of 18 stories clean through both gates against 13 of 44. Against s320 alone gate-1 is flat (1.77 to 1.78). This supersedes the batch 259 "no direction supported" |
| Subagent `sleep` polls denied | BL-514 (0.782.0) | Foreground polling 0.00 h since s319; subagent waiting per story 0.83 h to 0.64 h |
| Wrong shard directory denied at dispatch | BL-976 (0.1055.0), closed | 0 corrections against 7 re-derived on s321 |
| Join-refusal resumes | BL-974 (0.1057.0) | 1 against 13 on s321. One part that passed its own check was still refused by the join, so the check is incomplete |
| Cheaper `validate-spawn-ledger.sh` | BL-1168 (0.1168.0) | 3.9 s a call on the 11 calls that ran the fix, against 56.8 s on the 58 before it |
| One cross agent in carry-over elicitation | BL-810 | 1 cross spawn at $3.00 against 3 at $7.32 (s320); it still found 4 major findings no part shard found |
| Cap-rejected spawns held; party-round waves | BL-515, BL-695 | Last read on s322 (0 of 584 rejections; $3.79 a story against $4.98). No s323 reading was taken |

### Partly

| Fix | Entry | s323 measured |
|---|---|---|
| One-call snapshot rule | BL-912 (0.1163.0) | Snapshot calls fell (stories 110 of 1,596 against 198 of 1,348). Lead time in the class did not: implementation 1.40 h against 0.72 h. 280 snapshot calls still ran back to back |
| Convergence capped at pass 3; narrowing | BL-911 | No series ran past pass 3. Narrowing fired once (carry-over pass 3). Every other pass 2 ran full width because the pass-1 repair had touched every part |
| Delta re-review, record-only route | BL-507, BL-808, BL-809 | Re-review passes per story 0.78 against 1.91 (s319) and 0.62 (s317). The record-only route ran in 2 review files |
| Hold a lane's question | BL-841 | Idle share of ask-wait minutes 96.9% (s320) to 88.4%. 0 of 38 asks named a lane |
| Dead agents noticed | BL-975 (0.1056.0, 0.1133.0, 0.1146.0) | s322 4 deaths, first lead action 3701 to 3729 s after the death, median 3717 s; s323 44 deaths, 41 with a first action, 57 to 934 s, median 832 s (the 36 notice-only deaths alone: median 840 s over 33). All 44 were one rate-limit burst on 2026-11-19. Its Outcome line is still owed: the efficiency Outcome grammar cannot express a notice-latency outcome |
| Gate-pass discards | BL-512 | Lead-caused discards 1 of 34 against 6 of 38; the discard rate itself rose (0.294 against 0.263) |

### No effect, or worse

| Fix | Entry | s323 measured |
|---|---|---|
| Lead hours and calls | BL-819 | Worse. Lead calls 7,127 / 9,304 / 11,744; compactions per elapsed hour 0.51 / 1.08 / 1.78; planning's `other` class 3.2 / 5.7 / 9.0 h |
| Dispatch, then ask | BL-972 (0.1092.0, 0.1145.0) | 0 asks held a lane. The 0.1171.0 half never reached graph's s323 engine |
| Serial remediator | BL-716 (0.1058.0, 0.1133.0), BL-508, BL-543 | Remediator alone 9.9 h against 9.2 h (s322) and 9.6 h (s321). of 15 pass-2 and pass-3 MAJOR findings in s323, the strict regex flags 4 and a heading reading finds 13 naming a repair-made or half-fixed sibling (2 ambiguous) (BL-508's batch 261 reading) |
| Real repo paths for seats | BL-550 | Missing-path rates rose (party 0.54 against 0.375) |
| Evidence sections; early case binding | BL-397, BL-398 | Dollars and tokens did not fall below baseline ($31.9 against $29.0; $20.90 against $20.25) |
| Scripted gate transition; stories cross collapse | BL-913, BL-811 | No effect on s322; not re-read |

### Built, first complete reading is s324

Reached graph with 0.1174.0 at the tail of s323, or shipped since: the pre-reviewer before gate 1 (BL-1166,
3 spawns in s323), the zero-seat gate skip after a gate-3 rework (BL-1030), the concurrent pre-push (BL-1167),
the BMAD invocation check (BL-1173), the planning entry's readiness, trace and pass-budget items (BL-1175
items 3, 4, 6), the remediator's findings partition and route-key directories (BL-716, 0.1173.0 and 0.1178.0),
the dispatch-then-ask second half (BL-972, 0.1171.0), the spawn-ledger fix on a whole sprint (BL-1168), and the
planning-gate pass-count change (0.1181.0). BL-1005 reads a zero population in s323 and decides nothing.

## Where s323's 75.4 hours went

| Share | Hours | What |
|---|--:|---|
| The lead's own work | 33.3 | model generating 25.2, tool execution 5.8, idle with no agent running 2.3 |
| The lead waiting on running agents | 15.4 | waits shorter than 5 minutes: 7.7 planning, 4.9 implementation, 1.8 sprint review |
| Operator answers | 17.9 | 27 pipeline asks; about 2 h more sits inside "lead active" (see instruments) |
| Long waits on agents | 8.9 | gaps over 5 minutes |

Outside the 75.4 h: eight `/ai-dlc-update` sessions, 8.1 h lead-active and 16.4 h elapsed.

**Which role the sprint waited on alone** (hours in which every running agent had that role): remediator 9.9,
qa 4.7, adversary 3.2, dev-escalated 2.7, gate-adjudicator 2.1, dev 1.8. Exactly one agent was running for
25.5 of the 39.7 hours in which any agent ran.

## Opportunities

Ordered by wall clock. Each names what the measurement found, the change, and where it lands. Rows inside one
group overlap unless the group says otherwise, and no two groups' figures should be added without reading the
overlap notes.

### 1. The lead writes and re-reads too much (largest share of wall clock; 33.3 h is the lead's own)

| # | Found | Change | Reach |
|--:|---|---|---|
| 1a | After each of 134 compactions the hooks require a 27 KB digest read, a snapshot read, a step-file read and an advisor call before work resumes. Summarizer plus slow first call cost 1.8 h; the calls up to the next productive action are 2,056 and 4.3 h. 125 of the sprint's 211 advisor calls are this one | The recovery hook injects the snapshot slice and the step's resume section itself. The post-compaction advisor call folds into the once-per-gate call or goes | up to 4.3 h, of which the advisor call is 1.55 h and identical re-reads 0.8 h |
| 1b | The lead types each agent's brief: 329 calls of about 3,100 output tokens, 2.76 h. 131 dispatches were then refused for a missing `Deliverable:` line and typed again (211 of 1,033 dispatches refused in all, 20%, against 10% in s322) | A script renders the brief from the plan, the role and the shard; the dispatch carries a path and the fields that vary. The join already prints the lane plan (`join-remediator-shards.sh`). A rendered brief cannot omit the line | up to 2.3 h, plus 0.66 h of refused dispatches |
| 1c | `gate-validation.md` is 247 KB. The lead read it 391 times (5.9 MB); 65 of 134 compactions happened inside gate validation; step-file slices are the largest thing filling the window between compactions. 155 lead reads were denied as over the one-read limit. 0.1184.0 names the exact chunk to read after a refusal, which removes the blind retry and not the sixteen chunks | Ship the gate procedure as per-check sections under the read limit, with the section list rendered by script | 0.45 h in denied reads; the larger effect is fewer compactions, which is not sized |
| 1d | 280 `snapshot-update.sh` calls ran immediately after another one (0.86 h). The script already takes many operations per call. 131 calls carry snapshot text the lead typed (0.79 h) | The gate and step programs that know the state change write the snapshot row themselves | up to 0.86 h and 0.79 h; the class is 3.57 h |
| 1e | Sprint review, deploy-validate and retro are prose the lead re-derives: `retro.md` is 1,740 lines with 8 code blocks, and the lead wrote 9 scratch scripts in s323's retro. Each gate runs its arms one call at a time | A retro-close runner and a gate-arms runner | up to 3.0 h; 1.5 to 2 h expected |
| 1f | 1,739 separate shell reads (3.4 h) to look up what a finding cites | One call that prints a finding's cited lines | up to 1.7 h |
| 1g | A text-only turn while agents run draws a 3.4 KB forced-continuation message (69 times) | Allow the stop when a background agent is running | 0.2 h |

1a, 1c and the re-read part of 1d overlap. 1b is disjoint from the rest. In the implementation step alone, the
lead was active 13.6 of 14.4 h and a finished agent waited a median 7.6 minutes for the lead's next dispatch on
its story; 36 of 88 such waits ran over 10 minutes while the lead worked other stories. So every hour removed
from the lead in that step is wall clock.

**Found efficient, no change:** hook wall time (0.12 h all sprint), notification delivery (0.5 s median),
validator re-runs (none), exact-repeat polls (0.09 h), linters, commits, CI (graph runs none).

### 2. The test-suite memory wall (holds the critical path when it occurs)

Graph's rule (`docs/coding-conventions.md`, "Suite-Launch Admission and Watchdog") refuses a suite launch
unless 8 workers × 1.25 GiB + 16 GiB = 26 GiB fits in measured headroom, and fixes the worker count at 8. On
2026-11-18 from 14:45Z to 19:27Z headroom sat between 15.6 and 25.9 GiB. 261 refused launches are in s323's
transcripts (a control token returns in 5,372 files), 206 of them between 13:00Z and 24:00Z that day. One QA agent lived
290 minutes of which 277 were polling for a 138-second run; a dev rework ran 323 minutes with 114 refusals. Both
were on the critical path. The lead told one agent that the local model server had released memory; what held
the memory was not established. The operator was asked once, 88 minutes in, and answered "keep waiting".

The engine has no text about it (0 files under `core/` mention admission in step or role text). Each agent
polls on its own.

- **Engine:** check the consumer's suite predicate against measured headroom before the first implementation
  wave; one single-flight queue for suite runs in place of N agents polling; raise it to the operator after a
  bounded number of refusals.
- **Consumer side (a brief, never a write):** the predicate and the worker count are graph's; so is whatever
  shares the box with the local model. Graph's `scripts/pytest_admission.py` measures headroom as free plus
  inactive memory, so the 16 GiB allowance is margin on top of whatever is resident, and graph's s322 record
  shows the local model server resident at 150.3 GiB of 256 GiB (reported by the graph session on 2026-11-20;
  not re-derived here). The operator coordinates the consumer side with graph under the grant of 2026-11-20. Done by graph under the operator's approval on 2026-11-20: PR #1340 (e3c7794c5) makes its suite admission step down 8 -> 6 -> 4 workers before refusing (`STEP_DOWN = (6, 4)` in `scripts/pytest_admission.py`); of s323's refused readings carrying a headroom figure, 31% pass at 6 workers and 63% at 4. The engine items are unchanged by it.
- **Reach:** two readers disagree. A critical-path simulation gives up to 4.7 h of implementation's 14.0 h; a
  concurrency join gives 1 to 3 h at low confidence. Agent time is firmer: 7.0 agent-hours in 81 agents.

### 3. Operator wait (17.9 h, $0)

Classified by reading each of s323's 38 asks (27 pipeline, 11 in update sessions; 1,368 minutes):

| Kind | Asks | Minutes |
|---|--:|--:|
| Needed the operator and could not be foreseen | 17 | 562 |
| The same decision, answered the same way before | 10 | 381 |
| The operator took the marked recommendation | 6 | 327 |
| No recommendation marked; the operator chose the status quo | 2 | 95 |
| Not a decision | 3 | 2 |

- **Presence decides the wait.** Asks sent within 10 minutes of an operator action took a median 2.3 minutes;
  after an hour of silence, 68 minutes. Of 18 waits over 30 minutes in s321 to s323, 17 had no operator prompt
  in any project during them. The engine sends no notification: nothing under `core/` or `templates/` calls
  `PushNotification`, and graph's installed `Notification` hook list is empty.
- **Standing decisions** are up to 380 minutes (214 pipeline, 166 update). Three update-session families have
  long histories in graph's answer record: "delete a pristine file upstream removed" asked 28 times before s323
  and answered yes in 24; "extension still additive" 48 times, 42 as recommended; override drift 23 times.
- **Proceeding on a marked recommendation** is up to 83 minutes, not the 422 a naive count gives: the lead
  reaches its next operator-gated question within minutes and waits in the same absence.
- **A decision register at step start is worth about 11 minutes** and is not proposed. Questions come out of
  lane output mid-step. This withdraws opportunity 2 of the batch 259 update.
- **"Keep other lanes moving" is worth about 30 minutes.** After each long ask the lead's next work was the
  answer itself or the next question. BL-841's claim 2 and BL-972's "held lane" count cannot move.
- **DEFECT:** one 195-minute sprint-review ask quoted the operator's own earlier answers in its question text.
  Rule 11(a)(i), decide when a source settles it, had shipped before s321.

Six s323 asks on one certificate-header premise (asks 3, 14, 15, 19, 29 and 37 in the operator-asks reader's numbering) total 577 minutes; the facts that contradicted the premise were in graph's tree (`infra/lib/ingress-stack.ts:111`, `rebalancer/api.py:635`, as reported by the reader, not re-derived here).

Changes the operator chose (2026-11-20): a standing-rulings record the lead and the update skill consult before
asking, with the three update families as its first rows; and proceeding on a marked recommendation with a
recorded veto window where the work under it is cheap to redo. A push notification on a pending ask was offered
and not chosen; the presence finding stands as a measurement.

### 4. Planning's serial tails (39.6 h; 2.8 h reachable inside the current structure)

Planning in s323 by real step boundaries: 13.1 h an ask was pending, 18.5 h at least one agent ran (12.0 h of
it exactly one; 8.4 h a lone remediator), 8.0 h was the lead alone between rounds (88% of that the lead model's
own turns, which group 1 addresses).

| # | Found | Change | Reach |
|--:|---|---|---|
| 4a | An operator's answer is folded into four documents by one serial agent though it edits disjoint files | One writer per file | 0.85 h |
| 4b | A single-document artifact is one lane because the join's node is a file. Seven single-lane rounds showed no cross-section edges | Section-keyed lanes for single-document artifacts | 0.8 h. Of the 6.20 h in `LANES=1` rounds (`serial_tail.py`, committed), the planning reader puts about 1.1 h in single-document single-lane rounds of lone-remediator time; that reader's script is not committed |
| 4c | A review shard hung 49 minutes on a permission prompt while four 10-minute waits saw nothing | Each wait prints every undelivered shard's silence; a shard silent two beats is re-dispatched | 0.7 h per occurrence; 1 in 377 long spawns over three sprints |
| 4d | Fence re-derivation, renders and seals run as 23 agent spawns | A script | 0.4 h, $6 |

**Kept on evidence:** pass 2 (it caught 14 major findings in s323, nearly all on text the repair added or left
stale; the count is a reading of finding headings); party rounds (465 repaired entries across the four steps);
the architecture readiness call (4 repaired findings for under a minute). **Corrected:** BL-1175 item 3 sizes
the readiness and trace calls at 0.5 to 1.2 h; in s323 they took about 2 minutes. **Not proposed now:**
overlapping the planning steps reaches up to 5.7 h but late operator decisions in requirements were cited by
architecture, so the rework risk is real.

### 5. Implementation and its gates (15.1 h)

- **Width is not the limit.** The spawn cap is 42 and was not hit in implementation. A simulation on the
  measured per-story durations gives 11.3 h at width 4, 6 or 8, against 14.0 h measured; the 2.7 h difference is
  lead latency (group 1).
- **Write down what the lead already did.** `_dispatch-protocol.md` serializes stories that write one source
  file, which declared an eight-story chain. The lead ran four of them together and merged at close; the
  declared chain would have cost about 6.4 h more. Against the s323 baseline this item saves 0 h, because the lead already ran those stories together; it protects existing practice from the declared chain. Risk: merge conflicts, of which s323 has two review records.
- **First-pass rework is mostly paperwork.** Of 55 classified review findings, 30 are evidence or bookkeeping
  form and 5 are code. A recurring one is evidence captured on a commit other than the frozen one;
  `validate-handoff-evidence.sh` runs before gate 1 and does not compare them. Reach: up to 6 agent-hours and
  $43 of rework, by allocation.
- **Check that a held, deferred or operator-labelled item carries a resolvable operator source: at intake (when a sprint takes such an item into scope, whatever sprint wrote the label) and at implementation exit (a label written during the sprint), resolving each cited operator locator to a line whose text matches the quote.** A label with no source, or whose locator does not resolve, does not block and is not silently accepted: the lead surfaces it as one operator decision recommending "keep it as labelled", proceeds on that, and records the answer as the item's source. One occurrence in s323, 3.4 h; silent acceptance of a wrong label cost a 195-minute ask and about 3.4 h found only at sprint review, while a blocking ask costs an operator wait at planning (s323's carry-over asks waited 148 and 200 minutes). It depends on the proceed-on-recommendation and standing-rulings items of group 3. As reported by the graph session on 2026-11-20 (not re-derived here), graph's audit found 58 labelled items (23 backed, 10 stale, 25 unbacked) and three cited quotes that resolve in neither operator history file; the operator declined a retroactive batch (0 confirmed, 0 corrected, 0 dropped), and graph's policy is no retroactive audit, each legacy item handled when a sprint takes it on. This item touches an item only then, which is that policy.
- **Not proposed:** running QA alongside code review reaches at most 1.1 h and wastes QA in the 7 of 17 stories
  where review fails first. There are no pushes inside implementation (0 against 230 commits).

### 6. Subagent dollars ($1,580 a sprint; about $300 reachable)

Subagent dollars are 42% cache writes, 40% cache reads and 18% output; the cache hit rate is 96.3%. Thinking is
$81 in all, and no seat runs at high effort, so model and effort bindings are not the lever.

| # | Found | Change | Reach |
|--:|---|---|---|
| 6a | A 48.8 KB project-instructions block (graph's `CLAUDE.md`, two rule files, the operator's memory index) loads into 795 spawns in 15 roles; 0 of them read those files again. `omitClaudeMd` is set for 4 of 19 roles (`templates/settings.json.template`) | Set it for every role but the dev seats and the protected-path editor; carry the one path dev needs in its brief | $133 (upper bound; $159 if the dev seats could also opt out) |
| 6b | 1,062 of 1,138 spawns used neither the Skill nor the Agent tool but carry both definitions and a 30 KB skills list | A `tools:` allowlist per role in the rendered agent definition | up to $162; inferred from one allowlisted agent, not tested on a role |
| 6c | Six role files are over the limit (`wc -c`: qa 50,457 B, code-reviewer 48,987, adversary 46,895, remediator 39,519, dev 31,678, architect 16,796). The operator's context-mode plugin refuses a single read over 16,384 bytes, and the engine tells every agent to read its role file first. In a 40-spawn sample 35 dev, 16 qa, 13 code-reviewer and 13 remediator spawns loaded under half their contract. 0.1184.0 (BL-1184), shipped after s323, now tells agents and the lead to read such files in chunks of at most 16 KB; its first reading is s324 | Still open after 0.1184.0: a chunked read is one call per 16 KB. Role files under 16 KB with appendices read on demand make it one call | up to $60 to 70; the compliance half is 0.1184.0's to show |
| 6d | Sibling shards cache-write 18 to 37K tokens each because their briefs differ near the top of the prompt | Identical briefs with the shard identity in a first read (falls out of 1b) | up to $118, low to medium confidence |
| 6e | `templates/CLAUDE.md.template` puts "## Project Operations Protocol" (line 37) and "## Deployment Commands" (line 55) in the consumer's always-loaded `CLAUDE.md`. On graph those two sections are 11,776 B and 2,681 B of a 21,850 B file, loaded into every agent that has not opted out and into the lead after every compaction (134 in s323). Nothing in the engine depends on their being there: `core/skills/ai-dlc/steps/deploy-validate.md` and `core/team-roles/ops.md` each contain 0 references to `CLAUDE.md` (control: `deploy-validate.md` mentions "ops" 5 times, case-insensitive). The role files that name `CLAUDE.md` are `core/team-roles/dev.md:127` (a path "defined in your project's CLAUDE.md") and `core/team-roles/protected-path-editor.md:7` (as a protected governance file) | Give the two sections a home the ops seat and deploy-validate read on demand | not sized; the part reaching opted-in roles falls inside 6a. Done on graph by the operator's approval on 2026-11-20 (PR #1341, 885f53e83): graph's `CLAUDE.md` went from 21,850 B to 10,249 B (`git cat-file -s`; control: the parent commit reads 21,850). The engine item stands so a future install does not put the sections back |

6a and 6b cut the same first-request tokens; together they are bounded by about $300. Also: 36 agents died on
rate limits ($24, 205 agent-minutes), and 80 of 168 gate-adjudicator spawns ended in a plain pass ($40; a text
match, not checked against the rules).

### 7. Engine updates during a sprint (outside the 75.4 h)

Eight update sessions ran during s323: 8.1 h lead-active, 16.4 h elapsed, 1,768 lead calls. Each costs about an
hour to read the delivery and write the reconcile. Their 11 asks a sprint are almost all standing decisions
(group 3). How often this repo delivers to graph mid-sprint is the operator's decision; on 2026-11-20 the operator chose to keep the update pace as it is and cut the cost per pull through the standing-rulings record.

### 8. Instruments

- **DEFECT.** `extract.py` charges an ask to operator wait only where a gap exceeds 300 s. An ask that receives
  background notifications is charged to lead active: one 88-minute ask reads 5 minutes. About 2 h of s323's
  lead-active time is an ask pending.
- **DEFECT.** `roll.py` prices cache writes at the one-hour rate. Every s323 subagent call wrote five-minute
  cache. At the five-minute rate subagent dollars are about $249 lower a sprint. Which rate is billed was not
  established.
- **NOTE.** Graph's settings ask for one-hour caching and no subagent call used it; 63 calls rewrote their cache
  after a gap ($63).
- **NOTE.** `lead_time.py` still has the old clock (BL-1174).

## What this changes in the earlier reports

- The batch 259 update's opportunity 2 (declare operator decisions at planning and batch them) is withdrawn.
- Its opportunity 3 (serial adversary or remediator): the adversary half is done; the remediator half is worth
  about 1.7 h, not 3.7 h.
- BL-1175 item 3's saving is about a tenth of its estimate.
- The provisional report's "implementation ran 0.1164.0" holds for all but the last stories.
- BL-838 reads "worked" against the pooled baseline.
- BL-1167 (the lead's `git push`) has no subject inside implementation; the pushes that cost time are retro's
  five, 770 s.

## Not verified

- The memory wall's wall-clock share (two readers, 4.7 h and 1 to 3 h) and what held the memory.
- The repair-introduced share of pass-2 findings is a judgment from finding headings.
- The ask classes for s321 and s322 come from truncated question text.
- How much role-contract text went unread: byte counts of what loaded, not a test of compliance.
- The `tools:` allowlist saving is inferred, and the shared-cache saving assumes byte-identical briefs.
- Which pre-push steps took retro's 453 s push; the wall clock of 40 backgrounded pushes and 47 backgrounded
  suite runs.
- No s323 reading exists for BL-515, BL-695, BL-811, BL-913, BL-846, BL-847 or BL-843.

## Reproduce

```
OUT=<scratch dir>; export EXTRACT_WIN_END=2026-11-20T04:20:00Z
A=docs/analysis/pipeline-efficiency-s317-s318/scripts; B=docs/analysis/pipeline-efficiency-s317-s320/scripts
python3 -I $B/extract.py $OUT && python3 -I $A/spawns.py $OUT && python3 -I $A/analyze.py $OUT
python3 -I $B/roll.py $OUT > $OUT/roll.txt        # must equal pipeline-efficiency-s323-complete-b261/out/roll.monotone-clock.txt
```

The readers run on that extraction. Their scripts (`scripts/lead-time/`, `scripts/tokens/`, `scripts/asks/`,
`scripts/late-steps/`, `scripts/tool-runtime/`) and small result tables (`out/lead-time/`, `out/asks/`,
`out/late-steps/`) are in
[`pipeline-efficiency-s323-opportunities-b261/`](pipeline-efficiency-s323-opportunities-b261/); its
[`README.md`](pipeline-efficiency-s323-opportunities-b261/README.md) lists each file, how to run it
(`python3 -I`, the extraction directory as the argument or the hard-coded constant to replace) and the two
readers whose scripts are not committed (planning, implementation).
