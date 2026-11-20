# Pipeline efficiency through graph sprint 323: where the time and money go, step by step, and what to do next

Measured 2026-11-20 (batch 261, cluster C10). To update this analysis, follow
[`../plans/pipeline-efficiency-analysis.md`](../plans/pipeline-efficiency-analysis.md).
That runbook names the readers, the controls and the reconciliation that must run before any figure here is republished.

This extends [`pipeline-efficiency-s317-s322.md`](pipeline-efficiency-s317-s322.md), its batch 259 update
([`pipeline-efficiency-s317-s322-b259.md`](pipeline-efficiency-s317-s322-b259.md)) and the provisional s323 reading
([`pipeline-efficiency-s323-provisional-b259.md`](pipeline-efficiency-s323-provisional-b259.md)) through graph s323, which
closed on 2026-11-19. It reads every step of the pipeline part by part, and cuts across them for the lead's own time, the
operator's waits, the test-suite admission wall and subagent dollars. Nothing was written to graph and no pull was dispatched.
The s323 outcome readings are cited from [`pipeline-efficiency-s323-complete-b261.md`](pipeline-efficiency-s323-complete-b261.md)
and [`s323-outcomes-b261/`](s323-outcomes-b261/), not restated.

## 2. Answer

1. **s323 is the fastest and cheapest sprint per story of s318 to s323 (s317's corpus is truncated): 4.2 h and $87.8 (API) a
   story**, against 4.0 h and $94.7 in s321 and 8.2 h and $123.7 in s322. It took 75.4 in-session hours for 18 stories.
2. **Where s323's 75.4 hours go:** the lead's own work 28.0 h (the local model generating 22.4 h, tool execution 5.6 h), the
   lead idle with no agent running 2.9 h, the lead waiting on running agents 15.4 h, the operator 20.3 h, and long waits on
   agents 8.9 h. Waits on agents over five minutes fell from 22.5 h (s321) to 8.9 h.
3. **The bottleneck is the lead itself.** It made 11,744 calls and compacted 134 times, a median 18 minutes apart. Its speed is
   set by how much it writes, not how much it reads: about 8.7 s per 1,000 output tokens, flat from 80K to 200K tokens of
   context. The 20% of calls that write 1,000 tokens or more hold 54% of its model time; the largest written item is the dispatch
   brief.
4. **The largest levers on wall clock, in order (all UPPER BOUNDS, overlapping):** the test-suite admission wall, 4.3 h of the
   implementation step; the lead's own time (recovery by hook, rendered briefs, snapshot rows written by programs), with at most
   2.7 h, 2.3 h and 0.86 h in three disjoint classes; gates run as programs, up to 4.0 h of lead-active time; the implementation
   gates reshaped, 2.4 h on the binding chain and 7.1 h with the admission wall fixed; the wave plan by real content dependency,
   up to 6 h on the second-longest chain, which appears only after the wall is fixed. Section 8 ranks all seventeen.
5. **A memory wall on graph's test suite held implementation for hours.** 134 distinct refused suite launches (a floor; 177
   result blocks) fell on 2026-11-18, 123 of them between 13:00Z and 23:59Z, and 36 agents spent 1,149 agent-minutes waiting. Fixing
   both waits that sat on the critical path saves 259 minutes; either alone saves 104 or 0. What held the memory is not
   established.
6. **Operator wait is decided by whether the operator is present, and nothing notifies them.** "Keep other lanes moving" is worth
   about 30 minutes of s323. Standing decisions are worth up to 380 minutes and proceeding on a marked recommendation up to 83.
   The operator chose the standing-rulings record and proceeding on a recommendation (2026-11-20); the 16 sprint-PR and fix-PR
   push and merge asks (586 minutes, default taken 16 of 16) have no mandating engine text and fix-forward ones stop being asked.
7. **Planning is a fixed charge of about 39.6 hours, and what it contains earns its place.** The party rounds, adversarial pass 1,
   the separate elicitation round and the story gate each have named catches that survive to shipped artifacts, including
   CRITICALs on capital paths. What goes: carry-over's second adversarial pass (replaced by one diff-scoped final pass), the
   requirements brief and architecture-impact as reviewed subjects, the retro's seven-analyst document drafting, its gate
   adjudicators and next-inputs bundle, sprint-review-next, and the hand-driven bookkeeping that scripts can carry.
8. **What earns its place and stays:** the post-compaction advisor call (116 results read: 49 caught a named error, 18 more
   advised against acting on a stale summary, none ignored); the five-role sprint-review panel; the dev evidence checklist;
   the session-start checks; the scripted spine of deploy-validate with four judgments; the sprint-PR merge approval, which is
   graph's seam; the update flow's safety stops.
9. **Subagent dollars: 28% is context every spawn loads before it works.** s323's $1,582.3 (one-hour cache-write rate; $1,333.3
   at five-minute) has about $300 reachable by opting roles out of the 48.8 KB project block and shipping a tool allowlist.
10. **Earlier published figures were wrong in places** (s321 111.0 h is 100.1 h; operator wait in s323 is 20.3 h, not 17.9 h;
    refused launches are 134 distinct, not 261). The instrument charged steps by the last step file read, undercounted operator
    waits, counted a forked session and idle tails, and priced cache writes at one rate. Section 11 lists every correction.
    None of the proposed changes has run in a sprint: the operator will not run a graph sprint until all items are built
    and pulled, so the next sprint measures them together.

## 3. Population, method and clock

- **Corpus.** `~/.claude/projects/-Users-n8-git-graph/`, read only, pin `EXTRACT_WIN_END=2026-11-20T04:20:00Z`.
  s323's window is 2026-11-13T08:00Z to the pin. Graph's close commit is `16fd227d9`. Sprints s321, s322 and s323
  are read in full; s318 to s320 are quoted from the earlier published reports.
- **Pipeline.** Every step file under `core/skills/ai-dlc/steps/`, the gate procedures they invoke, the update skill
  and the minor steps are read part by part (section 6). Graph's engine during s323: carry-over's first session ran
  0.1101.0; carry-over's second session, requirements and architecture ran 0.1160.0; the architecture gate, stories
  and nearly all of implementation ran 0.1164.0 (77 of 84 gate plans); the last stories, sprint review,
  deploy-validate and retro ran 0.1174.0.
- **Clock.** Hours are on the monotone clock (BL-1174), `extract.py` at the batch 261 C5 blob, then corrected by the
  reconciliation of section 10. A figure on another clock is labelled. A "step" is the pipeline step together with
  its gate, as in the published roll.
- **Extraction control.** The extraction reproduces C5's committed `roll.monotone-clock.txt` byte for byte
  (`cmp`-identical) and differs from its `roll.default-clock.txt`. The uncorrected aggregation of the reconciler's
  record dump reproduces `steps.csv` on all 37 (sprint, step) rows for s321 to s323, with 0 differences; subagent
  dollars from the units equal `spawns.jsonl` (s321 1,879.5; s322 992.7; s323 1,582.3).
- **Scope.** In-session time only. Idle time between a handoff and the next resume is excluded by operator ruling and
  is not a finding anywhere in this report. The eight `/ai-dlc-update` sessions that ran during s323 are outside
  the 75.4 h and are reported separately (section 6.13).
- **Dollars.** API-list-equivalent at `roll.py`'s prices. The lead ran local models and costs $0 on the API; its
  token-equivalent price is the s321 hosted mix (`FALLBACK`). `roll.py` prices a cache write at 2 times input (the
  one-hour rate); every s323 subagent call shows five-minute cache only. Subagent dollars are therefore given both
  ways: s321 $1,879.5 and $1,648.6; s322 $992.7 and $881.2; s323 $1,582.3 and $1,333.3 (one-hour rate, then
  five-minute rate at 1.25 times input). Which rate is billed is not established.
- **No timing run was taken.** Every figure is read from transcripts, records and the tree already on disk.
- **How the readings were taken.** One reader per pipeline step (twelve step readers), cross-cutting readers for
  the lead's time, tokens, operator asks, tool runtime and the planning and implementation timelines, five value
  readers for the verdicts that needed their own evidence (advisor call after compaction, carry-over pass 2,
  elicitation merge, retro party mode, and eight open items), a reconciler that corrected the instrument, and a
  tip adversary over the draft of this report. Each reader returned its findings as text; they are committed
  verbatim under
  [`pipeline-efficiency-s323-opportunities-b261/findings/`](pipeline-efficiency-s323-opportunities-b261/findings/)
  and the readers' scripts under `scripts/` and `steps/`. Section 13 lists them.
- **"Upper bound".** Every saving in this report is an UPPER BOUND on s323 as the basis unless it says measured: the
  hours or dollars that disappear if the change removes the whole measured class and nothing else grows. Savings in
  one table row overlap with its neighbours unless the row says disjoint; no two groups' figures should be added
  without reading the overlap note. A step's elapsed hours are not the wall-clock saving of removing the step:
  where a step runs beside others, the saving is the critical-path part only.
- **A zero is a floor.** A count of zero findings from a part over three sprints is a floor on its catches; it does
  not show the part never mattered, because it cannot be separated from "the work always complied".

## 4. Sprint totals, s318 to s323

| | s318 | s319 | s320 | s321 | s322 | s323 |
|---|--:|--:|--:|--:|--:|--:|
| Stories | 13 | 20 | 13 | 25 | 8 | 18 |
| In-session hours | 59.6 | 94.0 | 99.2 | 100.1 | 65.2 | 75.4 |
| of which lead model generating | n/a | n/a | n/a | 13.2 | 16.7 | 22.4 |
| of which lead tool execution | n/a | n/a | n/a | 3.1 | 3.1 | 5.6 |
| of which lead idle, no agent running | n/a | n/a | n/a | 5.4 | 2.7 | 2.9 |
| of which lead waiting on running agents (gaps under 5 min) | n/a | n/a | n/a | 27.0 | 13.2 | 15.4 |
| of which operator wait | 14.0 | 17.0 | 47.6 | 29.0 | 12.0 | 20.3 |
| of which long waits on agents (gaps over 5 min) | 16.0 | 28.2 | 13.4 | 22.5 | 17.5 | 8.9 |
| Hours per story | 4.6 | 4.7 | 7.6 | 4.0 | 8.2 | **4.2** |
| API $ | 1,720 | 2,234 | 1,623 | 2,367 | 989 | 1,580 |
| Token-equivalent $ | 1,721 | 2,234 | 1,623 | 2,388 | 1,348 | 2,074 |
| API $ per story | 132.3 | 111.7 | 124.9 | 94.7 | 123.7 | **87.8** |
| Subagent $ at the one-hour / five-minute cache-write rate | n/a | n/a | n/a | 1,879.5 / 1,648.6 | 992.7 / 881.2 | 1,582.3 / 1,333.3 |
| Lead calls | 4,412 | 6,374 | 4,926 | 7,082 | 9,304 | 11,744 |
| Lead compactions (pipeline sessions) | 24 | 44 | 36 | 56 | 72 | 134 |

s318 to s320 are quoted from the earlier published reports: their operator-wait and long-agent-wait columns are on
the old definitions, and the reconciliation of section 10 was not re-run on them. In the reconciled sprints the
class columns sum to the in-session hours (s321 13.16 + 3.11 + 5.35 + 26.96 + 29.01 + 22.51 = 100.10; s322
16.68 + 3.08 + 2.69 + 13.22 + 11.97 + 17.54 = 65.18; s323 22.39 + 5.56 + 2.86 + 15.36 + 20.34 + 8.87 = 75.38).
s323 compacted 134 times in the pipeline sessions and 150 times counting the 16 compactions of the eight update
sessions. s317 is not recomputed: graph's transcripts before 2026-10-07 are gone from disk, and its corpus is
truncated.

Source: `steps/reconcile/B_tables.txt` (class hours, spawns, dollars, calls, compactions), C5 `out/roll.monotone-clock.txt`
and `out/s323_complete.txt` (stories, API dollars, s318 to s320).

### Per step, s321 to s323, reconciled

Each row is one pipeline step together with its gate. Elapsed h = lead own + idle + waiting on agents under 5
minutes + operator wait + long agent wait. Step boundaries are corrected from the lead's own declarations
(section 10): the label is moved where the lead set `current_step_file`, closed a planning gate, or ran a
`gate-checkpoint.sh --nonce implementation-...` span under another label. Implementation is split into its build
and its gates because they have different shapes. Lead dollars are not re-priced after the relabel: calls moved,
dollars did not.


**s321**

| Step (with its gate) | Elapsed h | Lead own (model + tool) h | Idle, no agent running h | Lead waiting on agents under 5 min h | Operator wait h | Long agent wait h | Spawns | Subagent $ (1 h / 5 min cache write) | Lead calls | Compactions |
|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| requirements | 11.1 | 1.5 | 0.6 | 3.7 | 2.4 | 3.0 | 168 | 260.6 / 232.9 | 812 | 3 |
| architecture | 9.9 | 1.0 | 0.3 | 2.7 | 0.0 | 5.8 | 122 | 262.6 / 237.2 | 555 | 5 |
| ui-direction | 0.1 | 0.0 | 0.0 | 0.1 | 0.0 | 0.0 | 1 | 0.9 / 0.7 | 6 | 0 |
| stories-test-strategy | 17.6 | 2.9 | 0.6 | 5.4 | 1.9 | 6.9 | 430 | 591.5 / 524.2 | 1349 | 10 |
| implementation build | 16.6 | 3.4 | 0.4 | 6.9 | 3.9 | 2.0 | 155 | 286.9 / 247.6 | 1588 | 13 |
| implementation gates | 7.9 | 3.1 | 0.5 | 2.6 | 1.4 | 0.3 | 126 | 160.7 / 139.5 | 927 | 11 |
| sprint-review | 2.9 | 0.8 | 0.3 | 1.7 | 0.1 | 0.0 | 169 | 209.1 / 176.8 | 396 | 3 |
| deploy-validate | 28.0 | 2.3 | 1.7 | 3.4 | 18.1 | 2.5 | 45 | 100.2 / 84.2 | 978 | 7 |
| retro | 1.8 | 0.4 | 0.4 | 0.1 | 0.8 | 0.1 | 14 | 5.5 / 4.2 | 170 | 1 |
| route/handoff/pre-step | 4.0 | 0.8 | 0.5 | 0.3 | 0.4 | 1.9 | 4 | 1.6 / 1.3 | 301 | 3 |
| TOTAL | 100.1 | 16.3 | 5.4 | 27.0 | 29.0 | 22.5 | 1234 | 1879.5 / 1648.6 | 7082 | 56 |

**s322**

| Step (with its gate) | Elapsed h | Lead own (model + tool) h | Idle, no agent running h | Lead waiting on agents under 5 min h | Operator wait h | Long agent wait h | Spawns | Subagent $ (1 h / 5 min cache write) | Lead calls | Compactions |
|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| carry-over-evaluation | 13.7 | 1.9 | 0.2 | 1.8 | 5.7 | 4.2 | 112 | 191.2 / 173.9 | 1050 | 8 |
| requirements | 9.9 | 2.1 | 0.1 | 3.0 | 1.3 | 3.4 | 128 | 249.5 / 225.9 | 1196 | 11 |
| architecture | 5.7 | 1.4 | 0.1 | 1.4 | 0.0 | 2.9 | 68 | 110.0 / 99.8 | 677 | 6 |
| stories-test-strategy | 7.5 | 2.0 | 0.3 | 1.9 | 0.0 | 3.3 | 125 | 169.2 / 151.4 | 1328 | 12 |
| implementation build | 8.0 | 3.5 | 0.3 | 2.2 | 1.5 | 0.6 | 68 | 65.4 / 55.4 | 1435 | 8 |
| implementation gates | 5.1 | 2.2 | 0.2 | 1.1 | 0.7 | 0.9 | 39 | 71.2 / 61.5 | 863 | 8 |
| sprint-review | 2.0 | 0.8 | 0.1 | 0.6 | 0.0 | 0.6 | 65 | 82.1 / 68.8 | 387 | 3 |
| deploy-validate | 3.7 | 1.1 | 0.5 | 0.2 | 1.9 | 0.1 | 3 | 5.2 / 4.3 | 652 | 4 |
| retro | 4.1 | 2.5 | 0.5 | 0.4 | 0.5 | 0.2 | 31 | 17.7 / 14.3 | 898 | 8 |
| route/handoff/pre-step | 3.9 | 1.8 | 0.4 | 0.2 | 0.5 | 1.1 | 12 | 3.5 / 2.5 | 529 | 2 |
| other steps (bug-investigation etc.) | 1.6 | 0.6 | 0.0 | 0.5 | 0.0 | 0.3 | 17 | 27.7 / 23.3 | 289 | 2 |
| TOTAL | 65.2 | 19.8 | 2.7 | 13.2 | 12.0 | 17.5 | 668 | 992.7 / 881.2 | 9304 | 72 |

**s323**

| Step (with its gate) | Elapsed h | Lead own (model + tool) h | Idle, no agent running h | Lead waiting on agents under 5 min h | Operator wait h | Long agent wait h | Spawns | Subagent $ (1 h / 5 min cache write) | Lead calls | Compactions |
|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| carry-over-evaluation | 8.4 | 2.0 | 0.2 | 1.9 | 3.1 | 1.2 | 88 | 166.1 / 143.2 | 811 | 8 |
| requirements | 16.9 | 2.9 | 0.3 | 1.6 | 10.0 | 2.1 | 182 | 233.0 / 196.8 | 1182 | 13 |
| architecture | 5.2 | 2.2 | 0.3 | 1.2 | 0.0 | 1.4 | 67 | 130.0 / 112.1 | 1032 | 13 |
| ui-direction | 0.1 | 0.0 | 0.0 | 0.1 | 0.0 | 0.0 | 1 | 1.3 / 1.1 | 25 | 0 |
| stories-test-strategy | 9.1 | 3.3 | 0.4 | 3.6 | 0.0 | 1.9 | 264 | 348.3 / 291.2 | 1598 | 19 |
| implementation build | 5.8 | 2.7 | 0.1 | 1.5 | 1.6 | 0.0 | 118 | 240.1 / 203.3 | 1183 | 12 |
| implementation gates | 10.5 | 6.9 | 0.1 | 2.6 | 0.3 | 0.5 | 200 | 202.4 / 169.0 | 2875 | 42 |
| sprint-review | 9.9 | 2.5 | 0.3 | 1.9 | 4.2 | 1.0 | 167 | 214.7 / 178.5 | 958 | 11 |
| deploy-validate | 5.5 | 2.4 | 0.8 | 0.6 | 1.2 | 0.4 | 14 | 20.4 / 16.5 | 1208 | 9 |
| retro | 2.7 | 2.0 | 0.2 | 0.3 | 0.0 | 0.1 | 28 | 23.1 / 19.5 | 605 | 7 |
| route/handoff/pre-step | 1.3 | 0.9 | 0.2 | 0.0 | 0.0 | 0.2 | 8 | 2.1 / 1.4 | 267 | 0 |
| other steps (bug-investigation etc.) | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 1 | 0.7 / 0.6 | 0 | 0 |
| TOTAL | 75.4 | 28.0 | 2.9 | 15.4 | 20.3 | 8.9 | 1138 | 1582.3 / 1333.3 | 11744 | 134 |


Planning (carry-over, requirements, architecture, stories) is 38.6 h in s321 (carry-over did not run), 36.9 h in
s322 and 39.6 h in s323.

**s323's sprint review is not a pipeline regression.** Three stories (2.1, 2.2, 2.3) reached sprint review labelled
"operator-held" with no operator quote behind the label. The operator ruled "build all three now" after a 3.25 h
wait, and they were built and gated inside sprint review. Their gate 3 ran in three `gate-checkpoint.sh --nonce
implementation-...` spans while the step label still read sprint-review; 1.03 h of that is now charged to
implementation gates, and sprint review is 9.9 h, not 11.1 h.

## 5. Did each earlier optimization work?

"Built" is checked against shipping code under `core/` and the entry's `LANDED` or `PARTIAL` line. Figures are
quoted from the entries' batch 261 readings, the s323 outcome readings
([`pipeline-efficiency-s323-complete-b261.md`](pipeline-efficiency-s323-complete-b261.md) and
[`s323-outcomes-b261/`](s323-outcomes-b261/)), and the C6 gate and QA readings under
[`bl844-gate2-route-seats/`](bl844-gate2-route-seats/) and [`step-value-b256/bl512/`](step-value-b256/bl512/).
These are cited, not restated.

### Worked

| Fix | Entry | s323 measured |
|---|---|---|
| Adversary seat back to opus/medium | BL-971 (0.1048.0) | 149 spawns: median 5.6 min against 11.7 (s322, sonnet/high), p90 11.6 against 61.5, $2.14 a spawn against $2.89, 17.1 agent-hours against 45.3, 1 spawn over 45 minutes against 19. Solo-adversary 3.2 h against 11.5 h |
| Dev seat on sonnet | BL-838 (0.968.0), closed | Against the pooled haiku sprints s318 to s320: gate-1 passes per story 2.41 to 1.78, gate-2 1.80 to 1.61, 7 of 18 stories clean through both gates against 13 of 44. Against s320 alone gate-1 is flat (1.77 to 1.78) |
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
| Lead hours and calls | BL-819 | Worse. Lead calls 7,082 / 9,304 / 11,744; compactions per elapsed hour 0.56 / 1.10 / 1.78 (reconciled hours); planning's `other` class 3.2 / 5.7 / 9.0 h |
| Dispatch, then ask | BL-972 (0.1092.0, 0.1145.0) | 0 asks held a lane. The 0.1171.0 half never reached graph's s323 engine |
| Serial remediator | BL-716 (0.1058.0, 0.1133.0), BL-508, BL-543 | Remediator alone 9.9 h against 9.2 h (s322) and 9.6 h (s321). Of 15 pass-2 and pass-3 MAJOR findings in s323, the strict regex flags 4 and a heading reading finds 13 naming a repair-made or half-fixed sibling (2 ambiguous) (BL-508's batch 261 reading) |
| Real repo paths for seats | BL-550 | Missing-path rates rose (party 0.54 against 0.375) |
| Evidence sections; early case binding | BL-397, BL-398 | Dollars and tokens did not fall below baseline ($31.9 against $29.0; $20.90 against $20.25) |
| Scripted gate transition; stories cross collapse | BL-913, BL-811 | No effect on s322; not re-read |

### Built, first complete reading is the next sprint

Reached graph with 0.1174.0 at the tail of s323, or shipped since: the pre-reviewer before gate 1 (BL-1166,
3 spawns in s323), the zero-seat gate skip after a gate-3 rework (BL-1030), the concurrent pre-push (BL-1167),
the BMAD invocation check (BL-1173), the planning entry's readiness, trace and pass-budget items (BL-1175
items 3, 4, 6), the remediator's findings partition and route-key directories (BL-716, 0.1173.0 and 0.1178.0),
the dispatch-then-ask second half (BL-972, 0.1171.0), the spawn-ledger fix on a whole sprint (BL-1168), and the
planning-gate pass-count change (0.1181.0). BL-1005 reads a zero population in s323 and decides nothing. BL-975 is
not a zero population: it read 44 deaths (table "Partly"). No s323 reading exists for BL-515, BL-695, BL-811,
BL-913, BL-846, BL-847 or BL-843.

## 6. The pipeline, step by step

The steps are taken in the order a sprint runs them. Each section gives what the step costs (reconciled hours with their
class split, dollars at both cache-write rates, lead calls), a part table (the part with its file and line, what it is for,
what it cost, what it produces and who reads it, what it caught, and a verdict: keep, shrink, merge, script, move or cut),
the named catches that earn the kept parts, the defects found in the engine (tiered BLOCKER, DEFECT, NOTE), the redesigned
shape, the upper-bound saving with its overlap note, and what was not measured. A step's rows in the section 4 tables are
the step together with its gate; gate validation (6.8) is the procedure the lead runs at each gate and is costed inside the
step that owns the gate.

### 6.1 Route and session start

Files: `core/skills/ai-dlc/steps/route.md` (53,509 B, 870 lines, 2 code fences; graph's installed copy is 51,001 B),
`core/skills/ai-dlc/SKILL.md` INITIALIZATION (:1174-1196). The resume path (route.md lines 1-267: Step 0 :25-116,
Step 0a :118-267) is 17.6 KB (33%). The fresh-start path (Steps 1-6, :269-863) is 35.5 KB and runs once per sprint
(1 of the 5 s323 lead sessions). Procedure a script can carry: pause-flag removal and verification, Step 0a checks 1, 3,
4, 5, 6 and 7, the layers listing and the owed counts. Judgment: what to do when a check fails. Source:
`findings/step-route.md`.

Step files: `route.md`

**What it costs.** The row "route/handoff/pre-step" of the per-step tables is the lead's work before the first step
file is read, plus handoff work (6.12). It is small and entirely on the critical path (the lead is otherwise idle):

| | elapsed h | lead own (model + tool) | idle | waiting on agents <300 s | operator | long agent wait | spawns | subagent $ (1-hour / 5-minute cache write) | lead calls | compactions |
|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| s321 | 4.0 | 0.8 | 0.5 | 0.3 | 0.4 | 1.9 | 4 | 1.6 / 1.3 | 301 | 3 |
| s322 | 3.9 | 1.8 | 0.4 | 0.2 | 0.5 | 1.1 | 12 | 3.5 / 2.5 | 529 | 2 |
| s323 | 1.3 | 0.9 | 0.2 | 0.0 | 0.0 | 0.2 | 8 | 2.1 / 1.4 | 267 | 0 |

Source: `steps/reconcile/B_tables.txt` (hours on the monotone clock; the s321 figure has the 8.7 h of idle tail on
two sessions removed). The ui-direction step is a separate row of 0.1 h in s321 and s323 (1 spawn each, $0.9 and $1.3;
6 and 25 lead calls). The lead ran locally in s322 and s323, so every lead saving in this section is wall clock at $0.

The route segment itself is short: 0.21, 0.81 and 0.40 h (s321, s322, s323; 13, 7 and 5 route segments by the reader's
count). Reading `route.md` takes 3 to 5 slices (19 Reads in the 5 s323 sessions) and 1.7 minutes of the 28.1 minutes
those 5 sessions spent from first record to first step-file read. The rest is Step 0a work done by hand.

**s323 session start, 5 sessions, first record to first step-file read (28.1 min in all):**

| Phase | Minutes |
|---|--:|
| snapshot budget, trim and conservation checks | 5.6 |
| `ctx_execute` mixed (budget gate, owed derivations, conservation) | 6.1 |
| start to first call | 3.2 |
| other Bash | 2.7 |
| owed-derivations | 2.5 |
| snapshot Reads | 2.3 |
| `route.md` Reads | 1.7 |
| ToolSearch (loading the deferred advisor tool) | 1.0 |
| git | 0.9 |
| AskUserQuestion (fresh start only) | 0.9 |
| pause flag | 0.5 |

Per session, first record to first step Read: 4.1, 6.5, 9.9, 3.9 and 3.7 min; first Agent at 4.7, 12.6, 17.0, 6.7 and
5.5 min. The "47 minutes to first dispatch" seen in one session is 28.1 minutes of session start plus 18.4 minutes of
work the resumed step needed (one session spent 6.3 minutes debugging a join-script path); the second part is not route
overhead.

**Part table.**

| Part (file:line) | What it is for | Cost | What it produces; who reads it | What it caught | Verdict |
|---|---|---|---|---|---|
| Step 0 pause-flag removal and verification (`route.md:25-116`; SKILL.md INITIALIZATION :1174-1196) | clear the pipeline pause flag the per-prompt hook creates | 11 calls in 5 sessions, 0.5 min | cleared flag; nothing reads it afterwards | nothing | SCRIPT into the resume pre-flight. Remove the affordance: do not create the flag for the `/ai-dlc` invocation itself (SKILL.md:1176-1183 against the hook) |
| Step 0a checks 1, 3, 4, 5, 6, 7 (`route.md:118-267`) | resume integrity: snapshot present and in budget, step file exists, branch, recency, stranded deploy-validate, owed derivations | the bulk of 28.1 min across 5 sessions | verdicts shown in text; the resume dispatch reads Position and In-Flight; the owed-derivations output is read by the lead only | snapshot over budget at resume in 2 of 5 s323 sessions. Checks 5, 6, 7 and the branch check have no s321-s323 firing measured (not measured whether they fired). Named failures: resume token never recognised (`route.md:64-69`); snapshot archived as stale | SCRIPT (`resume-preflight.sh`, one call; prints Position, In-Flight rows with deliverable state, the target step file, OPEN lines only, INFO as a count). Keep checks 5, 6, 7 in the script (no firing was measured; their cost is one script line each); the HARD_BLOCK checks (2, 5, 6, 7) still wait for the operator |
| Snapshot trim at resume (inside Step 0a) | bring an over-budget snapshot into budget by hand | 5.6 min of the 28.1 (2 of 5 sessions; trim calls 73 in s321, 20 in s322) | trimmed snapshot, rows moved to history | the budget breach itself | MOVE to write time (6.12, snapshot writes) |
| Owed-derivations listing (`route.md:262` demands every INFO line shown) | list derivations a prior session owes | 2.5 min per 5 sessions; one resume printed 84 INFO lines (33 KB) with 0 OPEN | text shown to the user | of 107 runs in s321-s323, a real OPEN line in 9 (s321 7, s322 2, s323 0; control: 39 results carry INFO) | SHRINK: print counts unless OPEN is greater than 0 |
| Fresh start Steps 1-6 (`route.md:269-863`) | intensity, sprint id, roll, scope confirmation, deferral filing, snapshot init, stale-snapshot rotation | 1 fresh start in s323, 0.9 min operator wait | routing record (`user_request_verbatim`, cite, `scope_confirmed` and cite); read by gate Checks 27, 33, 34 and `validate-steering-budget --cite` | the 7-day misread sprint (`route.md:611-619`); graph's records show `scope_confirmed`: 24 confirmed, 2 corrected (control 0) | KEEP the scope confirmation (a wrong-scope sprint is the consequence). Sprint id, roll and snapshot init are already scripts. MOVE Steps 1-6 into their own file, loaded once per sprint (35.5 KB) |
| Step 6 scope-confirm AskUserQuestion (`route.md:604-718`) | put the operator's scope to the operator | one operator ask | scope record | as above | KEEP |
| Step 1a manual continuation-log rotation (`route.md:317-333`) | rotate a hook-written log | not measured | continuation log, appended by `ai-dlc-continue.sh` and `ai-dlc-pause.sh`; one human-facing reader, retro 4b steerability audit (`retro.md:978`) | not measured whether the s321-s323 retros cited it | KEEP (hook-written, costs the lead nothing) |
| Records written by hooks: spawn ledger, continuation log, operator-request and answer history, In-Flight rows, context sensor | state other parts read | 0 lead calls apart from one copy at fresh start (`user_request_verbatim`) | spawn-ledger references in 16 non-fixture files (5 hooks, 11 scripts; referenced, not proven each is a reader); operator history read at route Step 6 and by `validate-steering-budget --cite` | n/a | KEEP, nothing owed by the lead |
| SKILL.md as loaded (72,535 B, 1,196 lines, 2 fences; graph copy 69,824 B) | rules, INITIALIZATION, POST-COMPACT, 32 rule bodies cited by number from step files | 64.6-69.5 KB injected per `/ai-dlc` invocation (14, 8, 5 invocations in s321, s322, s323); first-call context 46-47K tokens; head re-attached (20-27 KB) at each compaction; rule bodies Read on demand 16 times in s323 (72 KB) | the rulebook the lead obeys | n/a | SHRINK to a core of about 8 KB (INITIALIZATION, recovery, rule index) with rule bodies on demand. Value is tokens and headroom only; hours not sized |

**What the step earns.** The scope confirmation is the part with a named catch (the 7-day misread sprint) and a
measured record (2 corrected of 26). The Step 0a integrity checks each have a failure on record (a resume token that was
never recognised; a snapshot archived as stale). Neither is a reason to keep them as hand-run prose: both are
programs that print a verdict.

**Defects.**

- BLOCKER: none.
- DEFECT: resume starts from an over-budget snapshot and the lead hand-trims it (2 of 5 s323 resumes: one wrote
  `trim-snapshot.sh` and `repair-conservation.sh` after `validate-snapshot-conservation.sh` complained; one verified
  removed lines with a 140 s `ctx_execute` that ended "still running"). The budget is a write-time property.
- NOTE: `check-owed-derivations` prints 84 INFO lines (33 KB) on a resume with 0 OPEN.
- NOTE: `route.md` carries rationale and measurement prose inside a step file (for example :48-53, :64-69, :611-619,
  :676-681, :842-847), which resident-context discipline excludes; `audit-rule-files.sh` blocks tags and dates only.
  Bytes not sized.
- NOTE: the `.driver/handoff` file is touched at every handoff and in graph still sits there from Nov 19 02:54 (0 bytes):
  no consumer ran there.

**Redesigned shape.** (1) `resume-preflight.sh`: one call does flag removal and verification, layers listing, snapshot
budget, sections, step-file existence, branch, recency, stranded-deploy check and owed counts, and prints Position,
In-Flight rows with deliverable state, the target step file and sub-step, and OPEN lines only; it exits with the verdict
line the HARD_BLOCK checks need and keeps checks 5, 6 and 7. It replaces about 20 to 35 lead calls per resume (36, 93,
71, 46 and 33 calls before the first dispatch in the 5 s323 sessions; the last three include step work). (2) The
fresh-start path moves to its own file; the resume path is the script plus a 2 KB token-dispatch paragraph. (3) The
snapshot budget is enforced at write (6.12). (4) The advisor tool is loaded at session start instead of by ToolSearch
mid-start (1.0 minute over 5 starts). (5) SKILL.md becomes a core with rule bodies on demand.

**Upper bounds** (s323 basis, `$0`; the lead is local):

| Change | UPPER BOUND | Overlap |
|---|---|---|
| `resume-preflight.sh` and the fresh-start split | 0.35 h per sprint (28.1 min minus about 5 min) | the trim part (5.6 min) overlaps the write-time budget in 6.12 |
| advisor tool loaded at start | 1.0 min over 5 starts | inside the 0.35 h |
| SKILL.md core | not sized (tokens and headroom) | overlaps recovery volume in 6.12 |

**Not measured, and whether it was available.**

- s321 and s322 session-start phase split: available (same script as s323), not run; the 28.1 minute split is s323 only
  (5 sessions).
- Whether checks 5, 6, 7, the branch check and the recency check ever fired in s321-s323: available by grepping lead
  transcripts for their message text; not run.
- Whether retros cite the continuation log: available; not run.
- The share of the 46-47K first-call tokens that is SKILL.md: not available (no no-skill baseline session in the corpus).
- The phase-A attribution, owed-derivations and attachment-size measurements were run inline and are described, not
  saved as scripts (`steps/route-handoff-session/`, `measure.py` runs handoff, stophook, compaction, advisor, snapshot,
  startup).

### 6.2 Carry-over evaluation

File: `core/skills/ai-dlc/steps/carry-over-evaluation.md` (292 lines, 17,779 B, 0 code blocks). 56 lines (4,962 B, 28%)
are Catches, Removed-when and false-positive-cost rationale. The only procedure a script could carry is sub-steps 1a and
1b. Graph's installed copy differs in lines 41 and 291 wording only. The step ran in s322 and s323; it did not run in
s321 (why route skipped it was not read). Sources: `findings/step-carryover.md`, `findings/value-carryover-p2.md`.

Step files: `carry-over-evaluation.md`

**What it costs** (hours on the monotone clock, `steps/reconcile/B_tables.txt`):

| | elapsed h | lead own | idle | waiting on agents <300 s | operator | long agent wait | spawns | subagent $ (1-hour / 5-minute cache write) | lead calls | compactions |
|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| s322 | 13.7 | 1.9 | 0.2 | 1.8 | 5.7 | 4.2 | 112 | 191.2 / 173.9 | 1,050 | 8 |
| s323 | 8.4 | 2.0 | 0.2 | 1.9 | 3.1 | 1.2 | 88 | 166.1 / 143.2 | 811 | 8 |

The s323 figure excludes 3.41 h of requirements work that step attribution had charged here (see DEFECT 1; the 198-minute
SPEC-authority operator ask and a $7.3 "Fold answered OQs" spawn belong to requirements). Inside the step in s323 the
work is strictly serial: analyst, party, repair, operator, adjudication, closure, elicitation, pass 1, pass 2, pass 3,
gate. The step's lead overhead was 718 calls and 239 active minutes (other 91, beat waits 80, dispatch 19, merge 18,
snapshot 12, compaction recovery 5.4 plus step re-read 4.8 over 8 compactions, gate 4.7, repair 4.4) and 16 advisor
calls (10.8 min wall). The evaluation document grew from 342 lines (s319) to 697 (s320), 1,158 (s322) and 2,220
(329 KB, s323).

**Part table.** Per-part cost is s323 agent-minutes and dollars by spawn start window (`rounds_t.py`), with wall in
in-session minutes from the lead's windows. Part windows are the reader's and do not sum to the step row above.

| Part (file:line) | What it is for | Cost (s323) | What it produces; who reads it | What it caught | Verdict |
|---|---|---|---|---|---|
| 0, analyst dispatch and join (`:17-37`) | write the evaluation draft | 1 spawn, 19 min, $6.0; wall 15 | `s323/carry-over-evaluation.md`; read by every later part, the requirements digest, the PRD (34 cites), stories (18 of 18 cite it) | the draft itself | KEEP the analyst. The analyst evaluates the operator-scoped items only. FIX the join (`:28-33`): join on the Agent completion notification (or an appended seat-complete line), not on the first write |
| 1, 1a, 1b context load, audit anchor, trunk audit, backlog health (`:39-78`) | anchor sha, audit-trunk, status counts | lead inline in s323; 80-line output: anchor resolves, audit-trunk 11 of 11 clean with 0 findings, OPEN 251 against threshold 15 | an 80-line section that drew 14 party MAJOR or above (4 seats), 3 elicitation, 1 pass 1, 0 pass 2: all provenance (quote, locator, "286 vs 285 distinct ids") | nothing that changed a build | SCRIPT (anchor lookup, audit-trunk call, status counts, distinct-id count, rendered as the derived fence). Saves about $11 across the rounds that review it; no wall (they run in parallel) |
| Backlog-health rule (`:76-78`, OPEN greater than 15 prioritises triage) | prompt triage when the backlog is large | fires every sprint at 251 and has never changed the scope | nothing | nothing | NOTE: remove the instruction or make it a gate counter; a goal question that the record does not decide |
| 2, item evaluation incl. defect ladder and process-exercise rule (`:80-129`) | per-item verdicts | real work only for the 11 operator items; "no disposition proposed" for 262 others | 262 unscoped ids are 38% of the document's bytes (124 KB of 329 KB, lines 912-2135 of the shipped file); 21 of the 233 ids that appear only there are read downstream (requirements-context digest 13, retro next-inputs 11, one story) against 37 of 59 for the scoped part | nothing a consumer read | KEEP for the operator-scoped items. The 262 unscoped items stay in the backlog and leave the reviewed document |
| 3, party round (`:131-141`) | adversarial seat review of the draft | 29 spawns, 106 min, $35.6; wall 18 (all seats parallel) | 180 findings (4 CRITICAL, 96 MAJOR, 80 minor). By token overlap (a ceiling on re-raise) 23 of 100 MAJOR-plus are unique to one seat, 74 re-raised inside the round; unique/n per seat: tea 7/33, architect 7/28, pm 6/23, dev 3/16 (dev $2.8 in all). Cross seats (4): 23 findings, 3 unique, 18 re-raised by a part seat | smoke tests SKIPPED for a missing playwright package, not networkidle; wall 1 removing a stop on a live-capital signing path; a blocking Day-0 live-read gate recorded as a gap. Changed story shape: story 3-2 is built around the real cause, wall 1 is held with wall 3(a), the Day-0 reads decided Items 7 and 8 | KEEP, run on the finished draft. Dev seat kept (weakest by catches, but $2.8 and no wall) |
| 3 repair, adjudication, closure (party repair 5 section remediators, serial, escalation adjudication, closure writer) | repair the findings; decide escalations | 8 spawns, 99 min, $32.6; wall 08:53-09:41 repair, 12:02-13:03 adjudication and escalation edits, 23:22-23:40 closure | 45 escalated, 69 repaired, 3 not reproduced; 9 operator decisions (D-1 to D-9) and 17 lead decisions (D-10 to D-26, sourced "the document's own analysis") | the closure writer exists because the lead's own backlog and escalation edits made 12 of 153 derivation fences STALE | KEEP. Do the sections 4-6 edits before the first fence is recorded and the closure writer ($2.9, 10 min, plus about 18 min lead checks and a handoff brief) goes. An operator-stood decision is not re-decided by a repair |
| 3 operator asks | owner decisions | 09:34-12:02 (131.6 min, 4 questions), three follow-ups answered in 3 min each, a 20-minute question at 12:32, an 11.7-minute closer question at 01:22; 163 min in this step by the reader's count | decisions D-1 to D-9 | decisions the operator owns | KEEP. The first batch left 17 minutes after the repair join showed the escalations; an earlier ask is not shown to shorten the wait. The 148-minute window overlapped 16 minutes of agent work (serial repair, ops reads) |
| 3b live reads (ops x3, web-fetch) | settle mechanism claims against live evidence | 4 spawns, 31 min, $6.3 | Item 7 root cause (rewards cards never pass the chain); APP_ENV absent on both task definitions | blocking Day-0 gate (PI-S169-1); a party CRITICAL had to remind the lead it was owed | KEEP. Dispatch with the party round, not after the repair (s323 dispatched them at 09:32) |
| 3a elicitation, its repair and serial | read the party-repair text for what the party could not see | 11 spawns, 83 min, $26; wall 54 | 40 findings (0 CRITICAL, 24 MAJOR), about 14 MAJOR substantive: Item 1 AC "no transaction is signed" cannot hold at the offramp legs; wall 3(a) premise drawn from the Matic config; an AC on a model option replaced; close-signal node ids renamed by the Base parametrization; three items declared independent that all edit `server/test_live_smoke.py`; the `_active_execution` remedy blind spot on the edited collect path | unique by construction (reads party-repair text) | KEEP as a separate round |
| 3a pass 1, repair, 4 adjudicators, lane writer | first terminal-style pass | 12 spawns, 90 min, $29.5; wall 48 | 13 MAJOR (11 blocking): 6 provenance, 3 substantive (closer id conflict, two exposure-to-bulk-closure rules, an item-count contradiction), the rest labels and counts | the closer finding caused the avoidable loop in DEFECT 3 | no verdict recorded for pass 1 by itself (see below) |
| 3a pass 2, closer correction, repair, lane, record fixes | second pass | 13 spawns, 65 min, $19.5; wall 60 (21 plus 39); lead active 29.2 min | 7 MAJOR, all in text pass-1 repair wrote; none changes a story (a repair sentence saying a backlog row "still reads as a refusal" after a commit reworded it; "6 rows excluded only by tag" omits 14) | 25 MAJOR across s320, s322, s323 (9, 9, 7); 21 on repair-written text, 3 on a line or clause a repair rewrote, 1 outside a repair's reach | REPLACE with one final adversarial pass, conditions below |
| 3a pass 3, repair, record 4a | terminal stamp | 6 spawns, 31 min, $8.6; wall 18 | 1 MAJOR (a negative without a fence); stamps EXIT_CONDITION_MET that gate Check 24 reads | the terminal stamp | KEEP the terminal stamp as the diff-scoped final pass (already narrows to parts 2-4) |
| 4, deferrals, rare_event, 4a recurrence (`:197-251`) | file deferrals; recurrence cross-check | lead edits of `pending.md` and the backlog; three DEFERRAL_REQUESTs dispositioned, five items marked IN SPRINT | the 4a cross-check was missing from the document and was added by a pass-3-time remediator ($0.8) | n/a | KEEP; SCRIPT the 4a incident-log match if the log is structured |
| 5-6, close and update backlog (`:253-264`) | close the step | lead Edit calls, about 40 min inside the 12:02-13:03 window | backlog | n/a | KEEP |
| 7, Seam B and gate (`:266-291`) | step-closing gate | gate 22 min lead, 4 spawns, 12 min agent, $2.0, plus gate repair of two status tokens | gate record | n/a | KEEP |
| Step file as a re-read (292 lines) | what the lead reloads at each compaction | 8 compactions, 32 step-reread calls, 4.8 min active, 2-3 chunks each | n/a | n/a | SHRINK: move the 56 lines (4,962 B, 28%) of Catches, Removed-when and false-positive text to the notes channel. About 5 minutes and 28% of the re-read tokens per sprint |

**The pass 2 decision.** Pass 2 is REPLACED by one final adversarial pass, scoped by the document's diff from the analyst
draft (not by repair records), free to read anything, plus a mechanical join of every pass-1 CRITICAL and MAJOR id to a
repair entry. Evidence: pass 2 has 25 MAJOR and 0 CRITICAL (9, 9 and 7 in s320, s322, s323; s319 ran pass 1 only; pass 3
has 3, 2 and 1 MAJOR). 21 of the 25 bodies name a repair as the source; 3 more sit on a line or clause a repair rewrote;
1 was unseen by a repair-scoped pass (s322 cross F-1, the AC3 organic-row predicate stated two incompatible ways; pass 1
had raised it and no repair record answered it, so the join catches it without a model pass). The s320 wrong-sign
impermanent-loss cause was repair-written text, checked against five blob versions in graph with a control token that
returns 0 in all five ("not actually fee-inclusive": party repair 0, elicitation repair 0, pass-1 section repair 1, pass-1
serial repair 1, shipped 0); the sibling cross-2 F-1 is also repair-written (0, 2, 0). Traced downstream: 6 pass-2
findings reached later artifacts (s320 stories 2-1 and 2-2; four in `s322/requirements-context.md`; none from s323), a
floor; a diff-scoped final pass sees 5 of the 6 and the join catches the sixth. 19 findings were not traced (mostly
missing-derivation fences; their consequence is a wrong record). Conditions: (a) scope from the artifact diff, since the
s320 correction was a lead edit recorded only in the repair file; (b) the pass may read code, the backlog and the rest of
the document (s320 cross-1 F-1, s320 cross-2 F-1 and s323 section 3 F-3 each needed a read outside the diff; cross-2 F-1
needs `server/aggregator.py`); (c) the join of every pass-1 CRITICAL and MAJOR to a repair entry; (d) if pass 1 is also
removed, the pass covers party and elicitation repair text only, and pass 1's own catches on standing text need their own
check. Cost of pass 2 with its repair: s320 19 spawns, $28.29, 104.6 agent-minutes, wall 24 min; s322 16 spawns, $48.70
(cross shard dispatched three times, $22.2, 287 agent-minutes), wall 134 min; s323 13 spawns, $19.5, 64.9 agent-minutes,
wall about 39 min; about 48 spawns and $96.5 in all. A final pass still costs one review round, so the saving is pass
2's repair and re-run: roughly 40 to 55% of those figures (an estimate, not measured; about 15 min wall in s320 and
s323, up to about 100 min in s322 where the cross re-dispatches dominated).

Pass 1 by itself has no verdict in the decision record. The step reader proposed one diff-scoped terminal pass in place of
passes 1 to 3 (13 pass-1 MAJOR, 3 substantive, 6 provenance-only; 12 of the 45 MAJOR from elicitation to pass 3 are
provenance-only, 6 of them in pass 1, which is why pass 1 stamped NOT_MET with 11 blocking against a ceiling of 3). That
proposal is recorded here and is not decided.

**Defects.**

- DEFECT 1 (extractor and engine): 3.41 h of requirements work was charged to this step. The gate passed at 03:02 and
  the snapshot's `current_step_file` stayed `carry-over-evaluation.md` until 03:40:26; the post-compaction recovery at
  03:39:50 read the stale step file, and the extractor keys the step on the last native Read of a step file, so
  everything to the next native Read of `requirements.md` (07:05:06) was attributed here. The per-step tables carry the
  correction (carry-over 11.8 h to 8.4 h, requirements 13.5 h to 16.9 h). Engine fix: advance `current_step_file` in the
  call that records the gate pass (end of `gate-validation.md`), 37 minutes earlier here; the engine half costs one
  wrong-step reload per such compaction.
- DEFECT 2 (engine, `carry-over-evaluation.md:28-33`): the join on the analyst's artifact fires on its first write (the
  step text says it carries no seat-complete line). In s323 the join fired at 08:33:45 on 657 lines (70 KB); seats were
  dispatched at 08:35; the analyst finished at 08:40:27 at 1,448 lines (135 KB). The seats never saw the S317-S322
  clusters and the lead re-mapped 180 findings to the new section map (147 single, 28 multi, 5 unresolved) at 08:51-08:52.
  The party round ($35.6) reviewed about half the draft. Fix: join on the completion notification.
- DEFECT 3 (engine): the pass-1 repair adjudication amended D-19, which the operator had stood on; the advisor held pass 2
  for an operator question; the operator answered "Wall 3(a) closes it" (the original D-19); a correction remediator
  re-wrote the text. Loop 01:03-01:43, 12 minutes of operator wait, about $2 to $3 avoidable. Fix: the adjudication brief
  states that an operator-stood decision is not re-decided by a repair.
- DEFECT 4 (engine order): the lead's sections 4-6 edits invalidate the document's derived fences (12 of 153 STALE); the
  step then needs a closure writer. Fix: sections 4-6 before the first fence.
- NOTE: in s322 pass 2 the cross shard ran 87 minutes on a 1,125-line document; the lead re-dispatched it at beat 6
  although it was alive, the original finished anyway, and a third was dispatched after the merge guard refused: 3 cross
  runs, 147 agent-minutes, $22, about 107 minutes of lead wait. s323's crosses ran 4 to 17 minutes. The beat contract
  still re-dispatches an alive agent.
- NOTE: s322 had no elicitation (Rule 8 table: standard); s323 `full` ran it. The table already makes the round conditional.

**Redesigned shape.** (1) A script renders 1a and 1b and the counts. (2) The analyst evaluates the operator-scoped items
only and the join waits for completion; the 262 unscoped items stay in the backlog. (3) The Day-0 live reads are
dispatched with the party round. (4) One party round (seats by scoped parts, 4 cross). (5) Party repair by section, then
one operator ask batch built from the seats' operator-owned findings the moment the round returns. (6) Sections 4-6 edits
before fences. (7) Elicitation, kept separate, reading the repair text. (8) One diff-scoped final adversarial pass
stamping MET, plus the mechanical join. (9) The gate. This removes about one review-repair cycle and 38% of the reviewed
text. Without limit: the evaluation becomes a table of the operator's items plus a mechanism section each, generated from
the item entries and the live reads, with the review rounds binding the mechanism sections only, and repairs are
one-clause edits where the repairer replays its own fences before sealing.

**Upper bounds** (s323 basis; every figure an upper bound):

| Change | Wall | Dollars | Overlap |
|---|--:|--:|---|
| cluster text out of the reviewed document | 15-25 min total (the 262-item shard was the longest part shard in pass 1, 16.3 min against 7.4, and in pass 2, 11.3 against 8.8; about 5-9 min per round) | about $27 of shard dollars (party seat 5 $5.1, party repair section 5 $1.6, elicitation part 3 and repair $4.6, pass 1 shard 3 and repair $8.9, pass 2 shard 3 and repair $5.1, pass 3 shard 3 $1.6) plus $6.6 of the four cross shards (38% of $17.3); shard-level sums, so an upper bound | none with the rows below |
| pass 2 replaced by the final pass | 60 min (reader, if pass 1 is also merged: 48 + 60 - 18) | $19.5 (pass 2), against a final pass at $8.6 | with pass 1 if it is merged |
| closure writer removed (sections 4-6 first) | about 20 min lead wall | $2.9 | none |
| 1a and 1b scripted | 0 wall | about $11 across the rounds that read it | none |
| step file rationale moved out | about 5 min | not sized | none |

The reader's sum is wall about 125 to 135 minutes of agent and lead wall on the critical path, of which 60 to 75 minutes
is the realistic figure because pass 1 and pass 2 are repair-bound, and dollars about $80 to $95 of the $166 spawn spend
(50%), not counting lead tokens. Both the wall-clock and the dollar figures assume passes 1 and 2 are merged into one terminal
pass, which was not adopted; with only pass 2 replaced, use the rows above, or the pass-2 reader's estimate of about 15
minutes of wall in a normal sprint and up to about 100 in one like s322 (its estimate, not measured). The operator owns whether pass 2's repair-injected rationale survives: it was decided here
as REPLACE under the conditions above.

**Not measured, and whether it was available.**

- Lead dollars in this step: available (lead tokens are in `classes.jsonl`; not priced).
- Why s321 did not run the step: available (`route.md` Step 6, the s321 snapshot); not read.
- s322 pass-2 bodies (9 MAJOR): available; not read (the s322 reading is from headings and by-token counts).
- s319 and s320 not re-derived; the s320 capital-path catch type does not repeat in s323 (s323 plus s322, not three sprints).
- Unique-finding counts are by shared-backtick-token overlap; re-raise is overstated, so unique counts are floors (27 of
  320 findings carried no token in the s320 reading, 7 of 243 now).
- Survival of each finding in the shipped artifact by fix-token was not run for s323 (story and requirements citations
  were used as the reader trace): available, long.
- Whether a consumer might later depend on the cluster text: no reader found in graph (control above).
- Whether the 148-minute operator wait would have shortened with an earlier ask: not measurable from the record.
- Pass 2 shard-by-shard overlap with pass-1 findings in s322 and s323, s320 downstream for the 7 documentary pass-2
  findings, and sub-sentence provenance in s323 (one planning commit): not derived.
- Consequence for the s320 IL pair is reasoned from story text, not from shipped code.

### 6.3 Requirements

Step file: `core/skills/ai-dlc/steps/requirements.md`, 359 lines, 28,363 B, 16 fence lines (8 code blocks).
Graph's installed copy differs only at line 359 (the 16 KB chunk instruction). By section: s0 2.1 KB, s1 1.9 KB, s2
0.5 KB, s3 locked requirements 10.0 KB (35% of the file; the lead-interpretation ask and the HARD_BLOCK filing
grammar, with an inline awk state program at `:159`), s4 authoring 7.0 KB, s5 the cycle 5.4 KB. The cycle's real
procedure lives in `_gate-procedures.md` (1,821 lines, 148 KB), which the lead re-read in chunks 68 times in s323
(86 in s321, 43 in s322); it re-read `requirements.md` 42 times in s323. About 60% of the file is procedure a script
could carry (s3 grammar, s5 partition, base and series naming, serial-pass bookkeeping). The judgment parts are the
s1 dispositions, s2, locked-bullet extraction, authoring and scope calls. The authoring chain also reads
`discovery.md` three to four times and `research-requirements.md` three times per sprint, because
`requirements.md:202` and `:236` say "carry it unchanged" from `discovery.md` section 4b and
`research-requirements.md` section 2. `discovery.md` and `research-requirements.md` never ran as steps in s317 to
s323; their only rows are two "PRD rubric walker" spawns charged to them by the extractor's label.

Step files: `requirements.md`, `discovery.md`

#### Cost

Hours are on the monotone clock, corrected (reconciler `steps/reconcile/B_tables.txt`). Lead-own is lead model
plus tool; waiting is the lead waiting on running agents under 300 s.

| | Elapsed h | Lead-own h | Idle h | Waiting on agents h | Operator h | Long agent wait h | Spawns | Subagent $ (one-hour / five-minute cache write) | Lead calls | Compactions |
|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| s321 | 11.1 | 1.5 | 0.6 | 3.7 | 2.4 | 3.0 | 168 | 260.6 / 232.9 | 812 | 3 |
| s322 | 9.9 | 2.1 | 0.1 | 3.0 | 1.3 | 3.4 | 128 | 249.5 / 225.9 | 1,196 | 11 |
| s323 | 16.9 | 2.9 | 0.3 | 1.6 | 10.0 | 2.1 | 182 | 233.0 / 196.8 | 1,182 | 13 |

Share of the sprint's API spend (`findings/step-requirements.md`, step plus gate on the pre-correction roll):
13.9%, 25.1% and 14.2%. In s323 the step was 1,010 minutes of wall on the transcript clock with a 43-minute handoff
gap excluded: 599 minutes waiting on eight operator asks (23 questions) and 411 minutes of work. The corrected
operator class for s323 is 10.0 h, which agrees with the 599 transcript minutes. Of the 411 minutes of work, about
226 (55%) are serial repair tails after twelve-minute sharded review rounds, and 45 minutes are the four parallel
review rounds. The lead's s323 requirements work (1,045 calls on the reader's count, 4.77 h active) split as
other 115 min, merge 42, dispatch 26, snapshot 13, repair 10, compaction recovery 8.5, gate run 8.4, step re-read
5.6, idle wait 58.

Round cost by sprint (spawn ledger; `findings/step-requirements.md`):

| Sprint | Authoring | Party | Elicitation | Adversarial |
|---|--:|--:|--:|--:|
| s318 | $4 | $70 (8.2 agent-h) | $71 (6.6) | $146 (12.2) |
| s319 | $8 | $64 (9.6) | $68 (6.0) | $94 (7.1) |
| s320 | $15 | $70 (8.5) | $52 (4.0) | $42 (1.9) |
| s321 | $10 | $54 (3.2) | $96 (12.2) | $98 (11.8); three passes, MET at pass 3 |
| s322 | $7.5 | $84 (8.2) | none | $148 (25.3); four passes, pass 3 capped, pass 2 and 3 majors injected by the repairs |
| s323 | $16 (0.7 h) | $76 (3.9 h) | $48 (2.8 h) | $82 (4.6 h); pass 1 NOT_MET 1 critical 28 major, pass 2 MET 3 major |

s323 phases (spawn start windows): authoring chain 03:02 to 03:44, 3 spawns, $16.8; party 07:21 to 14:39, 68 spawns,
$76.4 (seats 12 min wall, repair 18 min with the SPEC shard at 18.4 min the long pole, lanes and fan-in 25 min,
serial passes p1 to p6 about 97 min including 51 min of asks); elicitation 14:44 to 17:13, 47 spawns, $47.7
(shards 11 min, repair 9, fix and seal records 8, rework and serial lanes 65 min including 28 min of asks);
adversarial pass 1 17:16 to 19:35, 43 spawns, $57.6 (shards 12 min, repair 8, reruns and adjudication 11, serial
lanes and fan-in about 100 min including a 19-minute ask); pass 2 verify and post-MET repair 19:36 to 20:04, 16
spawns, $24.4; gate adjudicators 20:31 to 20:35, 3 spawns, $1.8.

Operator asks: s321 12 asks, 102 min; s322 6 asks, 77 min; s323 8 asks, 23 questions, 599 min (200 for the SPEC
open questions, 300 for the ALB header premise, then 25, 19, 7, 21, 7, 19). The locked block grew from 21 to 38
bullets through those answers.

How much each document changed against the previous sprint (graph sprint-merge commits; s323 is
`e0ebaf019..eabdc576e`): the PRD (1,448 lines, 218 KB) took +234 and -337 lines; the brief (384 lines, 46 KB) +185
and -194 (48% of its lines churned); SPEC.md is a new 189-line file each sprint; architecture-impact is 21 lines
and 15.6 KB. The rounds rewrote, after authoring, about half of the brief and of architecture-impact and a third of
the SPEC (`83e1a2614` to `48c9e9e2b`: PRD +102/-71, brief +116/-44, SPEC +56/-40, architecture-impact 11 of 21
lines, locked +17). History files grow by cut and paste (prd-history +371 lines, 4.98 MB total; brief-history +249,
3.57 MB).

Who reads what (3,102 transcripts of s321 to s323; reads counted from non-error tool uses, a floor):

| Output | Readers in s323 |
|---|---|
| PRD | stories 128 of 243 spawns; architecture 33 of 60; implementation 3 of 111; gate-validation[implementation] 17; sprint-review 9 of 158 |
| locked-requirements | stories 106; gate-validation[implementation] 30; sprint-review 11; validate-locked-anchor, request-coverage, spec-join |
| SPEC.md | stories 41 (architects 19, tea 8); architecture 5; implementation 1; validate-spec-join |
| architecture-impact | stories 19; architecture 6; sprint-review 6 |
| product brief | stories 0; architecture 0 (1 unit in s322, 2 in s321); carry-over-evaluation 3, gate-validation[architecture] 2, retro 1, and validators (request-coverage, locked-anchor legacy anchor, artifact-budget). `steps/stories-test-strategy.md:489` itself calls it "on its way out". Zero s321, s322 and s323 stories cite it (0 files each; locked-slot cites 27, 8 and 21 files as the control) |
| requirements-context.md | 10 units, all inside requirements; architecture 0 in s323 |

#### Part table

| Part (file:line) | What it is for | Cost (s323) | What it produces and who reads it | What it caught | Verdict |
|---|---|---|---|---|---|
| 1. Section 0 analyst digest (`:21-46`) | Rule 24 context, prior-decision search, J3 deferrals | 8.4 min, $2.3, beside the lead writing locked requirements; off the critical path | `requirements-context.md` (54 KB), read by 10 units inside requirements | s323: 30 still-binding, 10 superseded, 3 deferred-unfiled (s321 5/1/1, s322 12/2/5), carried as constraints | KEEP. The J3 `*-deferral-p*.md` listing is a grep: SCRIPT it (saves nothing measurable) |
| 2. Sections 1-2 context, option check (`:48-87`) | Grep corpus; Rule 13 | inside part 1 | dispositions, read by analyst and lead | see part 1 | KEEP; fold section 2 into section 3 (bytes only) |
| 3. Section 3 locked requirements (`:89-183`) | Lead writes slot bullets; every lead-interpretation bullet is asked | one 65-second Write plus part of the asks | `locked-requirements.md`, 44 lines; stories 106, gate adjudicators 30, three validators | s323 pass 1 still found 12 of 29 findings on attribution (quotes labelled operator that were lead text) | KEEP the file. SCRIPT the state and filing grammar (`:151-176` as `lead-interp-state.sh`): frees about 5 KB of resident step text, wall 0 |
| 4. Section 4 authoring dispatch (`:184-287`), one opus pm-escalated chain | Brief, bmad-spec, PRD, PRD validate, architecture-impact | 31 min wall, $13.7 | see 4a to 4f | see below | see below |
| 4a. Brief update (`:190-193`) | Integrate scope, move old narrative to history | 7 min | brief +113/-194 lines; read by nobody downstream (table above) | rounds find cross-document sync defects in it | CUT from the reviewed subject and from the authoring chain; keep a pointer file for `route.md:273` and `carry-over-evaluation.md:47`. Frees 30 shard spawns, $31 and 1.7 agent-h per sprint (s323, shard-attributable only); wall up to 0.5 h (pass 2 exists only to catch late answers missing from brief and architecture-impact). Engine: `requirements.md:190-193`, `:298-300`, `:333`; `partition-subject.sh` subject list; `validate-locked-anchor.sh:177` REMOVE-WHEN note |
| 4b. SPEC kernel (`:195-213`) | bmad-spec headless, EARS | 5 min | SPEC.md, 189 lines; stories 41, validate-spec-join. Its repair shard is the long pole of each sharded repair: party 18.4 min against 1.4 to 5.5 for the other shards, elicitation 9.0, pass 1 3.3 plus reruns 3.3 and 1.1 | not separately counted | SHRINK: apply `(decision)` entries to the memory log through the rounds and render SPEC once after the serial tail. UPPER BOUND wall 0.4 h, $10. Engine: `requirements.md:314-326` and the join's stale-SPEC refusal |
| 4c. PRD update (`:215-262`) | FR-S<N> entries with CAP and LR arrows | in the chain | PRD +234/-337; read by stories 128, architecture 33, gate adjudicators | main catch surface | KEEP. SCRIPT the second pass that adds `(CAP-m)` citations and the LR-block mirror (`Propagate LR bullets into PRD block`, $0.86, 3.7 min; party p5 task 1) |
| 4d. PRD validate (`:255-262`) | Rubric completeness check | about 16 of the chain's 31 min (03:27 to 03:43; 41 PRD edits) plus a $0.74 walker | the chain's own record shows 0 critical, 4 high, 9 medium, every one fixed in place (FR-6 and FR-7 incompatible end states; no throughput guard for the fail-closed ceiling; unscoped `APP_ENV=prod` roll side effects); the report folder is empty at the pin | real done-ness defects at authoring time | KEEP. A gate-entry re-run recorded 1 high, 7 medium, 6 minor, none applied (`changelog-requirements.md`); its cost is not separable (20:04 to 20:31) |
| 4e. Architecture-impact (`:264-270`) | One line per FR; the architect challenges `none` | one write | 21 lines, 15.6 KB; stories 19, architecture 6, sprint-review 6 | 11 of its 21 lines changed after authoring; pass 1 major "moves ALB precondition from the fire to staging" | MERGE into the PRD as a per-FR field. Frees shard 14 in every round (7% of shard spend, $8). Engine: `:264-270`, `:300` |
| 4f. Research runs (`:272-286`) | Deep recon only if open questions bear | 0 runs in s321 to s323 (skip record) | none | Check 1c | KEEP (zero cost); move the premise check into the authoring dispatch (defect 1) |
| 5. Section 5 party round (`:333-336`) | 14 parts, each reviewed by an architect (opus) and a dev (sonnet), plus 2 cross seats | seats $33 ($24 architect, $9 dev), 12 min | 5 critical, 64 major, 82 minor (architect 4C/24M, dev 1C/40M); read by the repair | criticals: batch fee-collect path signs with no gas ceiling (architect-9 and dev-cross; shipped as `test_s323_1_3_fee_collect_ceiling.py`); ALB header premise false (architect-14, cross); fixture mask leaves the real injector (architect-10; shipped as `test_s323_3_2_no_operator_key_leak.py`). `step-value-s317-s319.md:109` agrees: unique capital-path catches in first-authored text | KEEP both seats: the dev found the batch-path critical alone for $9; only the architect found the premise |
| 6. Party repair, lanes, fan-in (section 5, `_gate-procedures.md`) | 14 repair shards, 4 lane remediators, fan-in | 07:35 to 13:02 less the ask | repair record 2,924 lines (183 KB), read by the lead | none | SHRINK through 4b (render once) and by dropping the brief and architecture-impact shards |
| 7. Party serial passes p1 to p6 (12:49 to 14:39) | Cross-part repairs | p1 13 min, p2 13, p3 14, p4 4, p5 5, p6 6 agent-min | p2 and p3 carry operator rulings | p4 re-derived stale PRD fences; p5 mirrored 7 LR bullets into the PRD block, fixed p4's invalid `source:` token, retired a false MOVED-CITE; p6 re-derived 7 stale fences of p4's record, synced the brief to the slot, replayed validators | SCRIPT p4 to p6 (derivation fences re-run by the validator that already replays them; LR mirror by copy). UPPER BOUND wall about 21 min plus lead beats, $4. Same class in s321 ("Repair N stale derivation fences", "Fix BN-ACN wording and brief cites"). Engine: a rewrite mode in `validate-artifact-derivations.sh`; scripts, not a new step |
| 8. Elicitation round, repair, serial (`:333`, cycle item 2) | One elicitation voice over 14 parts plus cross | seats about $26, 11 min; phase $47.7, 2.8 agent-h; non-ask wall about 1.1 h | 1 critical, 19 major, 33 minor | critical LR-S323-31 missing from SPEC (a sync defect). Substantive: the header premise confirms emit but not strip of a client-supplied value (security); the `:17919` ceiling refusal reaches 20 callers with no carrier; the FR-8 sentinel test is vacuous at HEAD in serial runs. `step-value-s317-s319.md:110`: 16 of s318's findings came from text party missed. s322 ran without it | KEEP as a separate round (see "Elicitation: kept as its own round"). Build item: one commit after each review round so s324 can decide on measured splits |
| 9. Adversarial pass 1, repair, serial (`:327-332`) | Convergence exit, 15 shards | $57.6, 3.3 agent-h, about 1.9 h non-ask | 1 critical, 28 major, 28 minor. By title: 12 attribution, quote, locator or derivation; 9 cross-document sync; 8 substantive | the critical: a manual row could discharge Check 928 where the operator said organic only (same class as s322 pass 1's critical); "Cap all three": 3 uncapped signing reads, which became LR-S323-38 and shipped as `test_s323_1_4_permit2_broadcast_subscribe_capped.py` | KEEP as the convergence exit. SCRIPT the 12 mechanical classes (quote locator exists at the cited operator-answers-history line; line locators; derivation present) before pass 1: removes about 40% of pass 1's findings, not the pass. UPPER BOUND 0.5 h, $15. Engine: a validator beside `validate-artifact-derivations.sh` |
| 10. Pass 2 verifier and post-MET repair | Verify pass 1's repair | 16 spawns, $24.4, 56 min with the lead | 3 major (all: late answers LR-36 retry rule and LR-38 caps landed in PRD and SPEC but not in the brief, brief note, architecture-impact) and 12 minor; post-MET repair fixed 14 and deferred 1 | the 3 majors vanish once brief and architecture-impact leave the subject (4a, 4e) | KEEP the pass; CUT the post-MET repair of minors (record, do not repair; s322 recorded-not-applied precedent). UPPER BOUND about 20 min wall, $2.1 |
| 11. Section 6 gate and Seam B (`:354-359`) | Three adjudicators | 0.42 h lead, $1.8 (s321 2.0 h, s322 0.5 h) | mechanical checks 1c, 20, 24, 30; read by the next step | not separately counted | KEEP |
| 12. Operator asks (section 3, section 4b, cycle) | Decisions | 599 min | decisions | see defects 1 to 3 | BATCH and settle checkable premises first |

#### The catches that earn the kept parts

- Party seats: the batch fee-collect path with no gas ceiling (shipped as test 1.3), the false ALB header premise, the
  fixture mask that leaves the real injector (shipped as test 3.2). The dev seat found the first alone for $9.
- Elicitation: requirements s321 critical `08.md` F-1 (the collision list omits `mode_transitions`, so a Base halt row
  blocks a Matic boot; capital path); s323 `10.md` F-1 (the FR-8 sentinel close signal is vacuous at HEAD in a serial
  pytest run; only the elicitation shard mentions it: grep of the token returns party 0 of 30 files, pass 1 0 of 15,
  pass 2 0 of 15); s323 `9.md` F-1 (the `:17919` ceiling refusal reaches 20 signing callers with no carrier). Source:
  `findings/value-elicitation-merge.md`.
- Adversarial pass 1: the organic-only predicate, the three uncapped reads (LR-S323-38).
- Authoring PRD validate: 0/4/9 done-ness defects before the party round.

#### Elicitation: kept as its own round

The merge proposal (run elicitation concurrently with the party seats on one base, one repair tail) was read against
the record. In the four planning steps every round that ran carries named unique shipped catches, including
criticals on capital paths (requirements s321 `08.md` F-1, architecture s321 `3.md` F-1). The proxies behind the
merge proposals failed their own control: the span-overlap flags for "a party seat raised it" and "pass 1 raised it"
do not separate the manual classes of the s321 stories reading (flag: repair-introduced 10 of 23, unique-survived 19
of 38; seat flag 36 of 38 unique survivors). For requirements, unique-shipped candidates on repair-written text
against all candidates were 7 of 27 (s321) and 6 of 9 (s323), so a concurrent round gives up that share and relies on
pass 1 to re-find it. Re-raise counts by passes 1 to 3 cannot show uniqueness, because a repaired defect cannot recur.
The natural experiment (s322 ran no elicitation for requirements) gives requirements pass-1 critical-or-major counts
41, 11, 8 (s322) against 35, 5, 2 (s321) and 29, 3, 0 (s323), different content in each sprint, n of 1 per cell.
Decision: elicitation is kept separate; concurrent party and elicitation is not adopted. The build item is one commit
after each review round (post-authoring, post-party-repair, post-elicitation-repair), which gives the exact split
for s324 and a replay base. Requirements elicitation cost in s323 is $48 and 2.8 agent-h (round 16 spawns and $25;
tail 29 spawns and $21; wall round 12 min, tail 126 min of which 28 min asks).

#### Defects found

- DEFECT 1: a cheaply checkable premise is deferred to a later step. The s323 SPEC records the ALB mTLS header
  premise as "unconfirmed, an architecture-step confirmation". A party seat (architect-14, cross) settled it
  negatively with two web-fetch spawns of 0.3 min each (07:25). Consequence: HARD_BLOCK at 07:36, a 300-minute operator
  stop, LR-S323-31 to 33, an elicitation critical and 6 to 8 pass-1 and pass-2 sync majors. Fix: `requirements.md`
  section 4b states that every SPEC open question or assumption that a fetch or grep can settle is settled in the
  authoring dispatch, before the first ask. UPPER BOUND 300 min of wall (operator-latency dependent: the first ask
  was answered at 07:03, so the second question asked with it could have been answered then) and about 10 propagation
  majors.
- DEFECT 2: answers arrive across five stops and each reopens the four-document sync. The locked block went from 21 to
  38 bullets. Of pass 1's 29 findings 9 are cross-document sync, all 3 of pass 2's are, and elicitation's critical
  is. The same shape is on record (`step-value-s317-s319.md:114-118`: every pass-2-and-later major and half to
  six-sevenths of pass-1 majors sit in text a repair or fold wrote; s322 pass 3: 8 major, all injected by the pass-2
  repair, series capped). Fix: collapse the subject (4a, 4e) so one document carries a decision; batch lead
  decisions per round into one ask.
- DEFECT 3: HARD_BLOCK idles the whole lead. During the 07:36 to 12:37 ask the party repair had finished by 07:53 and
  nothing else ran for 4.7 h. The s321 and s322 asks were short (102 and 77 min in total), so this is operator
  latency made expensive by the pause rule. Option: continue independent shards and serial work that does not touch
  the asked item. UPPER BOUND and risky (the answer then changes text already repaired, which is defect 2); how many
  parts were independent was not measured.
- DEFECT 4: bookkeeping done by agents in the serial tail (part 7): 19 bookkeeping-like remediator spawns in s323
  (0.86 agent-h, $12.3; s321 13 spawns, $10.2; s322 10, $5.7). Small dollars, on the serial chain.
- NOTE: the authoring chain reads `discovery.md` and `research-requirements.md` (24 KB) every sprint for contract
  text (`requirements.md:202`, `:236`). Move the section 4b contract and FR grammar into `requirements.md` or a
  shared include.
- NOTE: rubric-walker spawns land in `discovery` and `research-requirements` rows (s319, s323) because the
  extractor labels by file read. Anyone costing those two steps from the step table reads $0.5 to $0.7 and 0 lead
  time; they never ran.
- NOTE: the lead re-reads `_gate-procedures.md` (148 KB) 43 to 86 times and `requirements.md` 14 to 42 times per
  sprint; compaction recovery plus step re-read is 14 min active in s323. Shrinking what is re-read is worth more
  than trimming rounds.
- NOTE: PRD section "4. Non-Functional Requirements" has no `###` and is one 1,015-line shard (lines 186 to 1200) in
  every round although the sprint's NFRs sit in a separate `###` section; the shard re-reviews carried text. How much
  is carried was not measured.

Found efficient: the analyst digest (parallel, 8 min, $2.3, 30 binding constraints); the authoring chain (31 min for
four documents); the party seats ($33, 12 min wall, 5 critical findings that shipped as tests 1.3 and 3.2); shard
fan-out (each round is 11 to 12 min wall); the gate (0.4 h). The step's cost is in what follows the review rounds and
in the waits.

#### Redesigned shape

1. Analyst digest, locked slot and authoring chain, with the premise and open-question check done in the chain and one
   up-front ask for everything the chain could not settle. The reviewed subject is the PRD (with a per-FR
   architecture-impact field and CAP and LR arrows), SPEC and the locked slot. The brief stays as a short pointer and
   vision file, not reviewed.
2. Party round, then the elicitation round as its own round (kept), each followed by one commit.
3. One sharded repair, then one serial tail whose bookkeeping (fences, LR mirror, citations, SPEC render) is run by
   scripts, not a remediator pass per fix.
4. Scripted pre-checks (quote locator, line locator, derivation present) before pass 1 so the adversary reviews
   substance; pass 1 stays the convergence exit; post-MET minors are recorded, not repaired.
5. Gate unchanged.
6. Split the 1,015-line NFR shard.

A larger redesign, not adopted: make the PRD the single authored document, generate SPEC and the impact table from it
by script, and replace the lead's idle on a HARD_BLOCK with "park the asked item, continue the rest".

#### Upper-bound saving

From the step reader's verdicts, as a sum of upper bounds, overlaps not netted (not a projection): non-ask wall about
6.85 h: SPEC render once 0.4, brief and architecture-impact plus pass 2 0.5, serial bookkeeping 0.4, pass 1
pre-checks 0.5, post-MET 0.3, which sum to 2.1 h. The reader's own total was about 2.7 h (6.85 h to about 4.1 h) and
also counted 1.1 h for the elicitation tail; its listed items sum to 3.2 h, so its 2.7 h is not reproducible from
them. The elicitation tail is not taken here because the round stays separate. Dollars of the reader's about
$90 of $225 per sprint, without the elicitation tail ($21): brief shards $31, architecture-impact $8, pass 2 $24 if
avoidable, SPEC $10, bookkeeping $4, pass 1 $15 less overlap, post-MET $2. Plus up to 300 min of operator-stop wall
from defect 1 (operator-dependent). The three pass-2 majors and about half of pass 1's sync findings vanish with
parts 4a and 4e, which is why those two parts and pass 2 overlap.

What would be lost: independent review of the brief (nobody reads it); the pass-2 verification of repairs unless a
repair touches more than one document. The shipped catches (batch-path ceiling, ALB premise, key-leak fixture, three
uncapped reads, organic-row predicate) were all produced by party seats or pass 1 on PRD and SPEC text.

#### Not measured

- The trace covers s321 to s323 (3,102 transcripts); s317 to s320 were available and not run; their round costs come
  from the spawn ledger only.
- The repair-introduced and first-authored share of s323 findings was classified by title, not text age. Available
  (commits `83e1a2614`, `78ee5f9f6`, `e1fa40a1a`, `34b9f1321`, `48c9e9e2b` exist in graph); not done.
- Whether elicitation's s323 findings were re-found by pass 1: needs text matching; available, not done. s322 ran no
  elicitation and is the only natural control, confounded (four passes, pass 3 capped). Whether elicitation can merge
  is decided by per-round commits next sprint, not from this record. The uniqueness of elicitation catches in s323 is
  bounded by a single planning commit.
- Overlap of the authoring PRD validate with the party round: the report folder is empty at the pin; the chain's own
  record was used.
- Shard-attributable cost covers 111 of 176 s323 requirements spawns on the step reader's own labels (182 after the reconciler's relabel, as in section 4; cross shards, serial lanes and
  answer-carry spawns are not split by file).
- Lead dollars (local model) and the gate-entry fixer re-run (20:04 to 20:31) are not separable.
- Each cited shipped test was matched by file name and LR or AD cite at graph HEAD, not by reading the stories end to
  end. Reads through globs or other-path executions are missed; counts are floors. The gate log in graph is a
  one-line file, so gate findings for requirements come from the changelog and the spawn ledger.
- Operator-latency counterfactuals (defects 1 and 3) are operator-dependent; the 300 min is an upper bound.
- The step reader's monotone operator wait of 375 min against 599 transcript minutes is the pre-correction clock; the
  corrected 10.0 h resolves it.
- Per-finding bodies: 12 bodies of the elicitation reading were read, not all 287 critical-or-major bodies; a full
  read was available.

Controls: the step reader's table reproduces the pre-correction 11.1, 9.9 and 13.5 h; the reconciled s323 figure is 16.9 h (section 4); the ask script returned 26 asks over three sprints; the
brief-cite grep returned 0 beside locked-slot cites 27, 8 and 21; locked-requirements reads in stories were 106
(non-zero); s323 spawn dollars sum to $1,582 against the roll's $1,580. Sources: `findings/step-requirements.md`,
`findings/value-elicitation-merge.md`, `steps/reconcile/B_tables.txt`.

### 6.4 Architecture and ui-direction

The step files read: `core/skills/ai-dlc/steps/architecture.md` (20,749 B, 344 lines, one code block: the fast-track awk
predicate at `:309-311`; graph's installed copy differs in one line, the `:344` READ AND FOLLOW tail) and
`ui-direction.md` (3,546 B, 75 lines, 0 code blocks). About 70% of `architecture.md` is judgment prose addressed to the
architect role (`:128-258`, 12.2 KB: history rotation, Rule 26, HPE, spike mandate, 2d, 2e); about 15% is procedure a
script already carries (join, lint, index, predicate). The cycle the step invokes is not in the file:
`_gate-procedures.md` (148,448 B) and `gate-validation.md` (247,205 B) are re-read by the lead on every compaction.

Step files: `architecture.md`, `ui-direction.md`

#### Cost

Corrected hours on the monotone clock (reconciler `steps/reconcile/B_tables.txt`), step with its gate. Lead-own is
lead model plus tool.

| | Elapsed h | Lead-own h | Idle h | Waiting on agents h | Operator h | Long agent wait h | Spawns | Subagent $ (one-hour / five-minute cache write) | Lead calls | Compactions |
|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| s321 architecture | 9.9 | 1.0 | 0.3 | 2.7 | 0.0 | 5.8 | 122 | 262.6 / 237.2 | 555 | 5 |
| s322 architecture | 5.7 | 1.4 | 0.1 | 1.4 | 0.0 | 2.9 | 68 | 110.0 / 99.8 | 677 | 6 |
| s323 architecture | 5.2 | 2.2 | 0.3 | 1.2 | 0.0 | 1.4 | 67 | 130.0 / 112.1 | 1,032 | 13 |
| s321 ui-direction | 0.1 | 0.0 | 0.0 | 0.1 | 0.0 | 0.0 | 1 | 0.9 / 0.7 | 6 | 0 |
| s323 ui-direction | 0.1 | 0.0 | 0.0 | 0.1 | 0.0 | 0.0 | 1 | 1.3 / 1.1 | 25 | 0 |

s323 split (step reader, step and gate): step 4.30 h, gate 0.86 h; 750 local-lead calls in the step and 271 in the
gate. The gate was 52 minutes; the step 227 plus 27 minutes. About 95% of the step's agent spend is the Rule 8
validation cycle (party, elicitation, adversarial passes one and two and their repairs): $113 of $125 in s323. Authoring
is one 21-minute, $8.4 architect chain; the spine it produced is 3 ADs, 536 lines, 109 KB. The gate found nothing about
the architecture: its three FAILs were lead-authored record-format defects. In s323 ui-direction ran about 5 minutes
and $1.3 (ux seat 6.5 min, `ui-mockups.md` 21 KB, presented 12:40:41 to 12:45:28). The s322 sixteen-seat architecture
party ($25, nested at depth 2) is booked under gate-validation[architecture], which is architecture once step and gate
are merged.

Adversary seat configuration is already efficient here: s323 architecture adversaries 15 spawns, 156 agent-min, $45
(opus/medium) against s322's 15 spawns, 387 min, $50 and s321's 43 spawns, 1,463 min, $169 (sonnet/high); the wall of the
adversarial rounds fell from 4.1 h to about 35 minutes per sprint. Rounds: s321 pass 5, s322 pass 3, s323 pass 2.

#### Who reads what (s323; 1,138 spawns; counted from non-errored Read, Bash, Grep and Edit tool uses)

- `ARCHITECTURE-SPINE.md` (109 KB, 3 ADs): read by story-writing agents (stories: architect 18 of 19, tea 9 of 20, sm 5 of
  19, dev 3 of 19, adversary 8 of 58, remediator 8 of 98). Not read by implementation workers: dev 0 of 18, code-reviewer
  0 of 34, qa 1 of 50, dev-escalated 1 of 4. s321 has the same shape (dev 0 of 9, qa 0 of 45, code-reviewers 1 of 84;
  stories architect 27 of 27); s322 too (dev 0 of 15, code-reviewer 0 of 19). Implementation gets the design through the
  story files: 9 of 18 dev and 4 of 4 dev-escalated briefs carry `architecture_refs` (13 of 22 by a second count); no
  brief names the spine path.
- The decisions that matter reach code through the story text, and they do: AD-15 and AD-16 are cited at 11 sites in
  `rebalancer/execution.py` (`:992, 997, 2774, 17727, 17965, 21952, 21996, 22130, 22516, 25451, 25529`) and in 8 test
  files; commits `841a30a97` and `c8f32ee12` cite AD-15 rows; `LEG2_GAS_PRICE_RETRIES = 3` (`execution.py:993`) is an
  architect pick; Rulings 11 and 13 are elicitation and party outputs.
- `docs/architecture.md` (the fold, `:128-143`): stories architect 16 of 19, remediator 13 of 98; implementation dev 1 of
  18, dev-escalated 2 of 4, qa 3 of 50, code-reviewer 1 of 34; retro analyst 4 of 17.
- `architecture-impact.md` (written by requirements): the step's fast-track key. Fast-track fired in 1 of 63 sprint gate
  archives that record `validation_intensity` (s313; control: `validation_intensity` hits 63). The s323 file had 3 of 19
  FRs `none`, so the full cycle ran.
- `architecture-index.md` (section 4a): opened by 3 of 1,138 s323 spawns (stories 2, sprint-review 1); s321 13; s322 1.
- `changelog-architecture.md`: read by gate adjudicators (5 of 7 s323 gate spawns), nothing else. The chain record is read
  by the join script and by 9 stories-step spawns.
- `ui-mockups.md`: read only by one gate-validation[implementation] shard (part 5 of 8) on every implementation pass, a
  real comparison of source against mockup Surface 1; no dev read it (0 of 18); 0 FAIL or mismatch lines in the s323 gate
  log (5 lines mention the mockup).

#### Part table

Cost column is s323 wall minutes, lead calls, agent minutes, dollars (wall from the lead transcripts; agent minutes and
dollars from the spawn ledger by description). The critical-path column is merged into the cost cell as "CP".

| Part (file:line) | What it is for | Cost (s323; s321 and s322 where the reader gave them) | What it produces and who reads it | What it caught | Verdict |
|---|---|---|---|---|---|
| P0 section 0 explore and J3 deferrals (`:15-44`) | As-is digest for the architect | 3 min, 17 calls, 0 agent, $0 (lead wrote `architecture-context.md` itself; no analyst); s321 analyst 4.8 min, $1.2; s322 none. CP | `architecture-context.md` 8.3 KB; the chain architect; 2 spawns in gate and implementation read it | n/a | KEEP, tiny |
| P1 section 2 authoring chain, one architect (`:52-126`) | Write spine, run `lint_spine`, readiness | 21 min, 12 calls, 21 agent-min, $8.4; s321 63 min, $13 (plus analyst); s322 11 min, $3.8. CP, lead idle at the join (beat re-armed twice) | `ARCHITECTURE-SPINE.md`, chain record 14 KB, lint json; see "who reads what" | AD-17 HPE | KEEP; the beat re-arm is mechanical |
| P2 section 3 readiness and adopt (`:260-280`), fold into `docs/architecture.md` (`:128-143`) | Route 6 findings to pm, fold ADs into the live doc, commit | 6 min, 34 calls, 3.7 agent-min, $1.0; s321 about 2 min; s322 about 8 min. CP | readiness record, PRD wording repairs, fold commit `149c6e77f`; stories architects read the arch doc 16 of 19 | R-1, 3, 4, 6 PRD gaps (4 PRD fixes) | KEEP |
| P3 section 4 party, 20 seats = 4 roles x (4 sections + cross) (`:284-293`) | Design, test and PRD review per seat | 18 min, 77 calls, 137 agent-min, $38.5; s321 28 seats about 16 min, about $38; s322 16 seats ($25 nested, labelled to the gate). CP (slowest seat tea-3 14.7 min; wave 2 starts 2.4 min after wave 1) | 20 seat files, 121 findings: architect 38 (11 major, $15.5), tea 36 (20 major, $15.4), dev 28 (12 major, $4.7), pm 19 (5 major, $3.0); read by the repair parts | 48 major, 0 critical; 5 or more findings raised independently by 2 to 4 seats (the Leg-2 mock census, the Merkl/batch double estimate, the `:24881` budget). `step-value-s317-s319.md:107-112` agrees | KEEP. Option: dispatch all 20 in one wave, 2.4 min |
| P4 party repair: 4 parts, join, worklist, 4 adjudicators, lane serial, fan-in, lead rulings 4 to 10 | Apply 121 findings | 58 min, 106 calls, 61 agent-min, $17.1; s321 about 46 min; s322 about 64 min (lane alone 44.8). CP, the longest pole: parts done in 13 min, then 44 min serial (lane 30.0 with 55 entries for 61 findings, fan-in 7.9) | repair records, 14 rulings in `pending.md`; read by stories and gate Check 24 | 55 repair entries; 1 spine self-contradiction found by the advisor | SHRINK (see redesign; the lane-sizing saving is withdrawn) |
| P5 V1 advisor and ripple fixes | Advisor found Ruling-5 ripple and label gaps | 9 min, 53 calls, 0 agent. CP | correction record; read by the gate | 3 real gaps | KEEP |
| P6 elicitation, 5 shards (`:284` via Rule 8) | Defects the party never saw | 14 min, 13 calls, 42 agent-min, $12.4; s321 6 shards, cross shard 88 min; s322 none. CP | 27 findings (9 to 10 major); read by the repair | Leg1/Leg2 discriminator, in code at `execution.py:25451` ("Rulings 5, 11, 13") | KEEP as a separate round |
| P7 elicitation repair, 4 parts and serial | Apply elicitation findings | 20 min, 26 calls, 24 agent-min, $6.7. CP | spine commit `c5fb8cad` | none separately | KEEP |
| P8 R12 verification, advisor and fixer | Advisor showed Ruling 12 narrowed locked text; amended | 18 min, 103 calls, 5 agent-min, $1.0. CP (lead alone 11 min) | the amendment itself | 4 to 5 of pass 1's 9 major are its ripple | KEEP the catch; the late amendment is the cost |
| P9 adversarial pass 1, 5 shards and merge | Convergence exit | 18 min, 17 calls, 62 agent-min, $18.9; s321 passes 1 to 5; s322 passes 1 to 3. CP | 18 findings, 9 major, 7 blocking, ceiling 3: NOT_MET | 3 design catches (cross F-2 pre-boundary marker, `3.md` F-1 discriminator tests, `3.md` F-2 xfail fixture) | KEEP |
| P10 pass 1 repair, 4 parts and serial cross-section | Apply pass 1 findings | 25 min, 120 calls, 20 agent-min, $5.1; 8 calls refused. CP | repair record | none separately | KEEP |
| P11 adversarial pass 2, 5 shards | Verify the repair | 17 min, 16 calls, 52 agent-min, $13.9; s322 pass 3. CP | 12 findings, 2 major, MET | both majors are partial pass-1 repairs (pass 2 and later are repair-introduced, `step-value-s317-s319.md`) | KEEP as the exit |
| P12 post-MET repair, changelog, index (section 4a), commit, Seam B (`:316-337`) | Close | 27 min (17 including a 7.5-minute resume after the operator typed "handoff"; 10 min lead alone), 135 calls, 9.4 agent-min, $2.5. CP | `changelog-architecture.md` 4 KB, `architecture-index.md`, commit `86738bc61`; read by gate adjudicators 5 and by 3 of 1,138 spawns | 12 wording findings repaired | SHRINK and SCRIPT |
| P13 section 5 gate (`:338-344` into `gate-validation.md`) | Attest the cycle | 52 min, 271 calls, 20.5 agent-min, $4.6; s321 0.31 h; s322 1.27 h. CP | gate-log entry, `verdict.json`; read by later gates | 0 architecture findings; FAILs on Check 2, 15, 35 (all lead-authored record format) | SHRINK and SCRIPT |
| ui-direction (`ui-direction.md:15-75`) | UX mockups and Surface 1 for the operator | about 5 min, $1.3 plus lead | `ui-mockups.md` 21 KB; one implementation gate shard | 0 FAIL in the s323 gate log | KEEP (cheap); fix the step label (defect 4) |

Advisor (Rule 32) in the step: 10 consults in the step and 5 in the gate; the step's 10 cost 6.1 lead-blocked minutes; at
least 3 found a real defect (22:32 a spine self-contradiction from Ruling 5; 23:14 to 23:24 the R12 scope error; 23:53
corrections before rulings).

#### The catches that earn the kept parts

- Party: 121 findings, 48 major; tea 20 major per $15.4, dev 12 per $4.7, architect 11 per $15.5, pm 5 per $3.0.
- Elicitation: the Leg-1 versus Leg-2 discriminator (one offramp-level catch cannot tell a Leg-1 from a Leg-2 refusal), now
  in code. Architecture s321 critical `3.md` F-1 (the staged Base file fails the Base startup self-test, so the "no restart"
  enable path is dead; first-authored, no party seat raised it); s323 spine `3.md` F-4 ("RED (HEAD signs without
  gasPrice)" is false against the installed eth-account, HEAD raises TypeError). Source: `findings/value-elicitation-merge.md`.
- Adversarial pass 1: 18 findings, 9 major, with 3 design and test-feasibility catches. Pass 2: 12 findings, 2 major.
- Named failure case on record: AD-17 (severity HPE) prevented "firing APP_ENV=prod on a premise AWS documentation
  contradicts ... would 401 every gated forwarded request" (spine `:86`). The fire happened 2026-11-19T23:31Z and the
  probes returned 401; the fix is PR #1338 (4 commits). The ADR was right and was held for the operator; the fire still
  produced the 401 episode because no observation point existed to run the probe first (spine `:92`). The value realised
  is a diagnosis ready, not prevention.
- Gate FAILs: Check 2 (a lead-written escalation header `- OPEN -` outside the vocabulary and with no Status line,
  `pending.md:5998`, which `validate-escalation-status-vocabulary.sh` never examines), Check 15 (a tok number in a cell
  poisoned the budget parser), Check 35 (65 snapshot lines destroyed by the lead's trim; 73 at the requirements gate just
  before). The Check 2 failure cost a remediator $0.42, a first adjudication (3 shards, $2.14), a full re-adjudication at
  a fresh nonce (03:15 to 03:24) and the lead's span re-reads: about 19 to 22 min of wall.

#### Elicitation: kept as its own round

The proposal to run elicitation concurrently with the party seats was read against the record
(`findings/value-elicitation-merge.md`): architecture unique-shipped candidates on repair-written text were 8 of 27 (s321)
and 3 of 4 (s323); 19 of 27 (s321) sit on first-authored text. The proxies for the merge failed their own calibration
control, and a repaired defect cannot recur in pass 1, so re-raise counts cannot show uniqueness. Decision: elicitation is
kept separate in all four planning steps; concurrent party and elicitation is not adopted. The step reader's untested
hypothesis (frees about 14 plus 9 minutes) is not taken. Build item: one commit after each review round.

#### Defects found

- DEFECT: refused dispatches. 18 of 85 Agent dispatches in step and gate (s323: 12 and 6) were refused by hooks: post-compact
  "R touchpoint owed" 11 (`hooks/ai-dlc-recover-gate.sh:397`; 8 at 21:33:45 and 21:36:02 because the lead believed the
  advisor was not in its toolset, a stale deferred list, until 21:37:56), no `Deliverable:` line 4, serial-exception grammar
  2 (`hooks/ai-dlc-dispatch-guard.sh:1315`), cross-shard ordinal 1. Wall lost 21:33:45 to 21:39:36 was 5.9 min, the others
  0.1 to 1.4 min: about 10 min in total.
- DEFECT: Check 2 silent skip. `validate-escalation-status-vocabulary.sh` skips entries with no Status line, so a header
  outside the vocabulary passes the script and fails the adjudicator.
- DEFECT: a snapshot trim destroys lines (Check 35, 65 lines, and 73 at the requirements gate just before). Conservation
  is checked only after the fact.
- DEFECT: step-label leak. The snapshot keeps naming `ui-direction.md` until the lead reads `implementation.md`, so s323
  charged 0.35 h and $22 of implementation work to ui-direction (the 69.6-minute, $13.1 dev-escalated 1.1 re-dispatch, the head
  of the eight-story serial `execution.py` chain; five gate-1 reviewers; the ops baseline runner). The corrected table
  gives ui-direction 0.1 h and $1.3. Engine: the snapshot step-file field is updated at the step handoff
  (`ui-direction.md:73-75`, `architecture.md:338-344`).
- NOTE: eight stories (1.1, 1.2, 1.3, 1.4, 2.1, 2.2, 2.3, 5.2) serialized on `execution.py` (strategy lock; a per-site table
  of 11 sites in one 25,000-line file) put a 70-minute opus dev on the implementation critical path.
- NOTE: the operator typed "handoff" at 00:33; the resume cost 7.5 min in-session (the gap is excluded).
- NOTE: `architecture-index.md` was read by 3 of 1,138 spawns; its cost to make is about nothing (a script).
- NOTE: lead alone 78 of 253 min (largest gaps 11 min R12 verification, 10.8 min pass 1 merge read-up, 9.8 min post-MET
  close, 9.7 min V1 consult and fixes).
- NOTE: inside the gate the lead spent step re-read 9.0 plus compaction recovery 5.3 = 14.3 of 51.4 lead-active minutes
  (28%) over 5 compactions re-loading 247 KB of `gate-validation.md`.

Found efficient: the adversary configuration (above); the join beat; party seat yield per dollar.

#### Redesigned shape

Keep: the chain and readiness route, party, elicitation, adversarial to MET, the HPE and 2d and 2e rules (each has a
Catches line and the AD-17 and 2d instances). Change:

1. A script prints every dispatch brief header (Deliverable, shard grammar, role binding) and the dispatch guard stops
   asking the lead to spell grammar. A rendered header cannot omit the `Deliverable:` line.
2. The changelog, index and commit are one script at convergence (`:316-320`, `:322-334`).
3. A pre-nonce script arm covers every record-format check the adjudicators found in s323 (Check 2 header vocabulary over
   all headers, not only those with a Status line; Check 15 cell parse; Check 35 conservation), and
   `snapshot-update.sh` refuses a trim that destroys lines, so the gate's adjudicators attest judgment items only.
4. The step label flips at the handoff, so costs land on the step that spent them.
5. The party round is the option of a single wave of 20 seats (2.4 min).

Withdrawn: sizing the party-repair lane to the join's serial-required set. The step reader proposed that the lane take
only 41 findings instead of 61 (10 minutes freed). The 61 and 41 are different populations (61 findings unconsumed by the
lead, 41 the join's SERIAL-REQUIRED count, never reconciled at 21:49:27), and 40 of the 61 needed edits, so the saving is
not supported.

#### Upper-bound saving

The step reader's corrected sum of upper bounds is about 1.0 h of 5.16 h per sprint and $3 to $8 of spawn dollars, with
the items partly overlapping; its first statement of about 1.4 h was corrected by its second part. With the lane-sizing
item (10 min) withdrawn, the items are: dispatch refusals about 10 min; post-MET changelog script up to 8 min; gate up to
30 min of 52 (with no Check 2 failure the run is Q3 8 min plus one adjudication plus Q6), $2.6; one-wave party 2.4 min.
These sum to about 50 min, UPPER BOUND, and overlap through the lead's own time (the compaction re-reads of the gate file
are the same minutes). No part is a CUT.

#### Not measured

- Repair-introduced against original share per party and elicitation finding: available (shard files and repair records),
  not done; pass 1 and pass 2 were classified by heading only.
- The 20 unexplained lane findings (61 against 41): available in `architecture-party-serial-repair-p1.md`; not read. The
  share of the lane's 61 that were minor: not measured (73 of the 121 party findings are minor).
- The other nine adjudicated checks' history of content FAILs: available (gate-adjudication `verdict.json` for s321 to
  s323); earlier `step-value-b256` gate files not read.
- s321 and s322 refused dispatches and lead calls per part: available (lead transcripts); only s323 was walked end to end;
  s321 and s322 use the spawn ledger and class records only.
- Operator touches: in-step real human messages in s323 were 1 ("handoff"); the step table's `humans` figure of 8 counts
  continuation turns; the 65 user rows were read by eye, not by script.
- Lead dollars (local model) and what a missed finding would have cost: not priced; no counterfactual.
- Reader counts come from tool-use inputs, so a spine delivered inline in a brief is invisible to them; briefs were checked
  for the path (0 implementation briefs name it) and for `architecture_refs`.
- Whether elicitation can merge with the party seats: decided by per-round commits next sprint, not from this record.

Sources: `findings/step-architecture.md`, `findings/value-elicitation-merge.md`, `steps/reconcile/B_tables.txt`.

### 6.5 Stories and test strategy

Step file: `core/skills/ai-dlc/steps/stories-test-strategy.md`, 51,054 B, 801 lines, 1 code block. By section
bytes, the authoring standards (routing 4.3K, discriminating-AC 6.8K, layered AC 4.6K, pre-flight 3.1K, 2a locked
requirements 6.8K, 2b 2.2K) are about 28K (55%); the procedure (readiness, steps 2, 3, 3a, 4, 5, 6, 7) is about 23K.
The procedure a script could carry is briefs, joins, stamping (already scripts) and strategy ids; the judgment is the
content of the review and repair loop. Every sprint runs the same shape: party round, repair, elicitation round,
repair, adversarial pass 1 (p1), repair, adversarial pass 2 (p2), repair, test strategy, story gate.
Source: `findings/step-stories.md`, `findings/value-elicitation-merge.md`.

Step files: `stories-test-strategy.md`

#### Cost (monotone clock; hours; the step with its gate)

| | s321 | s322 | s323 |
|---|--:|--:|--:|
| Elapsed h, corrected | 17.6 (was 19.7 on the old step labels) | 7.5 | 9.1 |
| Lead own (model + tool) | 2.9 | 2.0 | 3.3 |
| Idle, no agent running | 0.6 | 0.3 | 0.4 |
| Lead waiting on agents under 5 min | 5.4 | 1.9 | 3.6 |
| Operator wait | 1.9 | 0.0 | 0.0 |
| Long agent wait (over 5 min) | 6.9 | 3.3 | 1.9 |
| Spawns | 430 | 125 | 264 |
| Subagent $ (one-hour cache-write rate / five-minute) | 591.5 / 524.2 | 169.2 / 151.4 | 348.3 / 291.2 |
| Lead calls | 1,349 | 1,328 | 1,598 |
| Compactions | 10 | 12 | 19 |

Source: `steps/reconcile/B_tables.txt`. Class hours are rounded one at a time and may differ from the elapsed row by
0.1. In s323 the step ran 03:36 to 12:40Z on 2026-11-18: 7.66 h for the step and 1.40 h for its gate, 544 min of step
wall. The lead made 1,110 executed tool calls in the window (651 Bash, 228 Read); the 1,598 above counts API calls,
a different population. Lead active time per part is not separable (see What was not measured).

#### Part table

Round windows are by spawn start time on 2026-11-18, s323. Lead calls are executed calls per window.

| Part (file:line) | What it is for | Cost (s323) | Produces; who reads it | What it caught | Verdict |
|---|---|---|---|---|---|
| P1 Readiness twice and analyst framework map (`stories-test-strategy.md:16-28, 271-286, 547-551`) | Confirm the planning inputs are ready; map frameworks once | 03:36-03:59, 4 min analyst; 1 spawn, $0.7; 113 lead calls in the window | `preflight-framework-map.md`, consumed once by the lead; a PASS leaves no file | No finding on record (a PASS writes nothing; whether the second run changed anything is not separable) | KEEP the analyst (cheap). SHRINK the second readiness (`:547`), which re-invokes the same skill on the same inputs plus epics: at most one skill run per sprint |
| P2 Epics and stories authoring, 2a and 2b (`:340-532`) | Write 18 stories and the epics; build the round briefs | Lead only, about 23 min; 77 party briefs from a lead-written generator (`rounds/gen_ts_briefs.py`, 9,233 B) | 18 stories, epics, briefs; read by every later seat | n/a | SCRIPT the brief build. The engine ships partition, merge, join and wait scripts and no brief generator, so every round's briefs come from a model-written script each sprint; the wrong flag in D1 came from there. Frees the 15 min brief build (upper bound; brief build time per round not separated) and removes a defect class. Add `core/scripts/gen-round-briefs.sh`; engine lines `_gate-procedures.md:551, 607` |
| P3 Party round (`:586-606`) | Multi-seat review of all stories | 03:59-04:26, 27 min wall; 77 spawns, $101.6; 57 lead calls | 76 seat shards, 475 findings (1 CRITICAL, 247 MAJOR, 227 MINOR); read by the repair | 188 C/M repair blocks; 82 raised by one seat only (tea 41, architect 29, sm 7, dev 5); sole-source with the span still in the shipped text: tea 21, architect 18, sm 4, dev 3 | KEEP |
| P4 Party repair, lanes and fan-in | Repair the party findings | 04:31-05:55, 84 min wall; 39 spawns, $50.5; 217 lead calls (150 Bash, 20 Agent) | `stories-party-repair-p1.md`, serial repair; read by the stories and the next round | 187 MAJOR blocks: 95 repaired with the claim span in the shipped text, 62 with no span (unattributable), 26 not repaired, 4 span gone | KEEP the repair. SHRINK the tail: parallel parts end median 33.0 min, p90 34.1; the last spawn ends at 83.4 min (fan-in remediator 40.2 min, 05:12-05:53; re-derive six stale fences 9.8 min). Tail 50 min of wall, UPPER BOUND; why the fan-in runs 40 min serially was not read |
| P5 Elicitation round (`:596-604`; `_gate-procedures.md:598-613`) | Per-story elicitation lens plus one cross-story shard | 05:55-06:16, 21 min; 20 spawns, $43.9; 16 lead calls | 19 shards: 1 CRITICAL (`cross.md`), 16 MAJOR, 29 MINOR | Of 17 C/M, 14 quote spans in party-repair claim text (a span-overlap proxy), 3 do not overlap; 8 repaired with the span in the shipped text (1 CRITICAL, 7 MAJOR). Elicitation round plus repair $60.8 for 8 span-shipped findings = $7.6 each (a floor, not unique survivors). Named unique catches across the four planning steps are in the list below | KEEP as a separate round (operator-rulings decision; see Decisions below). Build item: one commit after each review round so the next sprint can decide |
| P6 Elicitation repair and serial tail | Repair the elicitation findings | 06:21-07:41, 80 min; 21 spawns, $16.9; 87 lead calls | repair records | | KEEP the repair. DEFECT D1: 47.2 min of the 80 is dispatcher lag |
| P7 Adversarial p1 (`:586-606` round list) | Convergence pass over the repaired text | 07:41-07:55, 14 min; 20 spawns, $41.7; 34 lead calls | 19 shards: 2 CRITICAL (stories 2.2 and 5.1), 25 MAJOR, 58 MINOR; read by repair | 24 of 27 C/M quote spans in prior repair text (proxy; a strict reading of s321 gave 10 of 26); 18 MAJOR and CRITICAL repaired with the span in the shipped text | KEEP: the convergence exit is rule-bound (exit needs 0 CRITICAL and at most 3 blocking MAJOR; p1 had 27) |
| P8 p1 repair | Repair p1 findings | 08:00-08:34, 34 min; 21 spawns, $17.0; 63 lead calls | repair records | | KEEP. SHRINK the tail: parallel parts end by 08:08; the cross seat (08:09-08:21) then the fan-in (08:22-08:34) are two serial 12 min steps = 24 min. Running the cross seat beside the parts is a design change and was not measured |
| P9 p2 review | Second convergence pass (p1 did not meet the exit rule) | 08:38-09:42, 64 min; 22 spawns, $32.0; 57 lead calls | 2 MAJOR (2.3, 5.1), 20 MINOR | 1 of 2 MAJOR overlaps repair text. All 18 p2 shards read changed bytes (the artifact sha differs from p1 in 18 of 18), so s321's unchanged-bytes narrowing (19 reads, $7.57) does not apply; 15 of 18 stories had a p1 C/M, so sharding only the touched stories saves about 3 shards ($1.8) | KEEP (rule-bound). DEFECT D2: 41 min |
| P10 p2 repair | Repair p2 findings | 09:50-10:13, 23 min; 17 spawns, $10.1; 60 lead calls | repair records | | KEEP; the cross seat's 12.4 min is the tail |
| P11 Stamp provenance (`:630-647`) | Stamp story provenance | lead script call, 0 spawns | `stamp-story-provenance.sh`; read by Check 17 | n/a | Already a script; KEEP |
| P12 Test strategy author (`:650-689`) | Write the strategy document | 10:20-10:44, 24 min; 1 spawn, $8.1; 46 lead calls | `test-strategy.md`, 110,458 B, ids ST323-1 to ST323-146; read by the strategy review, Checks 21 and 24, `validate-handoff-evidence.sh`, the lead's bind | n/a | See P13 |
| P13 Strategy converge (`:690-739`) | Review and repair the strategy | 10:46-11:12, 27 min; 13 spawns, $18.3, repair 1 spawn $0.5; 181 lead calls (including bind and commit) | `test-strategy-adversarial-p1.md`: 3 MAJOR, 1 MINOR; repair | 5 repair blocks: 3 with the span in the shipped text, 1 not repaired, 1 no span. 20 of 307 implementation and gate seats read the document; 0 of 70 code-reviewer spawns | SCRIPT sections 1 and 6 (its own text says "Lettering rule, applied mechanically" and ids are "one per acceptance criterion, numbered in story order"); SHRINK section 5 to commands only; MOVE its review to Check 21's mechanical arms. UPPER BOUND $28.2 (author, review, repair, dispatcher) and about 55 min of step wall. Lost: the 3 MAJOR strategy-versus-AC catches (3 shipped) unless a script checks AC-to-case counts |
| P14 Bind rows (`:740-760`) | Bind 176 rows | inside P13 | 176 rows; the dev fills Kind and Resolves-to | The row count equals the case letters; the Kind enumeration is unenforced (D3) | KEEP; enforce the vocabulary or delete the word "exactly" |
| P15 Commit planning (`:763-778`) | One `docs(planning)` commit | 11:22Z, 1 commit `45bed5dc6` | the planning record | NOTE: with one commit the bytes before each repair are unrecoverable, so no later reading of the party or elicitation rounds can show what each caught | Add one commit after each review round (5 to 6 commits, seconds); engine line: step 6 (`:763`) |
| P16 UI route, Seam B and story gate (`:780-801`) | Mechanical consistency of the planning set | 11:22-12:40, 78 min wall; 11 gate spawns $7.1 (3 repair $4.3 over 32 min; 8 adjudicators $2.8 over 1.3 min); 179 lead calls (77 Bash, 62 Read, 17 `ctx_search`) | `gate-story-repair-p1` (Check 24 J2 topology, 3 MAJOR), `p2` (Check 30 spec-join: 12 CAPs bound by no AD, 11 LR to CAP; edits the architecture spine and memlog), `p3` (Check 5: 18 stories `status: draft` against yaml `backlog`, 10 `deferred_acs` yaml entries) | 3 failing checks of 41 verdicts, all structural, none in AC content. Check 30 failed the story gate in s319, s320 and s323 (s321 902 s only, s322 none) | KEEP the gate. SCRIPT the checks at the end of authoring (see Redesign item 4). Step 3 (`:536-540`) never names the status value the yaml takes and the story template emits `draft` |

Dispatch and rule text for the party round, repair and elicitation are in `_gate-procedures.md` (engine) and are not
step-file parts.

#### What survives to the built story

- 146 acceptance criteria in 18 stories at planning commit `45bed5dc6` (the AC section is 174,471 B, 51% of 342,365 B
  of story files). At the story gate (`ae63caf38`) 146 of 146 are identical. At the sprint pin (`a9b015557`) 136 are
  identical (93%), 5 are amended with an inline "[Sprint-review amendment ...]" (1.1 AC2 and AC5; 1.3 AC8; 1.4 AC3;
  1.1 AC14 reworded 5 to 7 callers) and 5 changed by a clause (4.2 AC1, AC3; 4.4 AC1, AC8; 5.2 AC10, mostly shifted
  line citations); 0 removed. AC bytes identical: 155,137 of 173,473 (89%). Control: planning against gate reads
  identical for all 146 and the comparer detects a changed AC in 10.
- `test-strategy.md`: 694 of 697 lines identical from planning to the pin; 3 lines edited once (sprint-review
  fix-forward `65ece9ec7`).
- Caveat: byte-identical means "not updated", not "right first time". Story 4.3's gate-2 rework re-timed AC6 to
  deploy time; the AC6 text is unchanged and the deferral lives in frontmatter `deferred_acs` and the Strategy Test
  IDs table. How many ACs went stale this way is not measured.
- Story files grow from 342 KB to 630 KB by the pin (Dev Agent Record, captures); ACs fall from 51% to 28% of the file.

#### Who reads the outputs

Executed Read, Bash and Grep calls in 307 implementation and gate spawn transcripts, paired with results, errors
dropped:

- The story file is touched by 292 of 307 spawns (dev 23 of 25, dev-escalated 6 of 6, qa 64 of 68, code-reviewer 46
  of 50, escalated reviewer 20 of 20, gate-adjudicator 130 of 134); every seat reads the AC section; adjudicators
  make 4.9 story calls per spawn.
- `test-strategy.md` is touched by 20 spawns: dev 9 of 18, dev-escalated 3 of 4, qa 2 of 50 (0 of 18 in the gate),
  gate-adjudicator 5 of 134, ops 1 of 2, code-reviewers 0 of 70. Dispatch prompts that name it: dev 9 of 25, qa 1 of
  68, ops 1 of 2, reviewers and adjudicators 0. The role files `dev.md`, `qa.md`, `code-reviewer.md` do not tell
  their seat to read it. Its content reaches seats through the story's Strategy Test IDs table.
- The story `## Changelog` (28,859 B at planning, 8% of story bytes) has no engine reader (grep of `core/` for the
  heading: 0 hits; control: `Strategy Test IDs` has a reader, `validate-handoff-evidence.sh`).
- `traceability-matrix.md` and `.json` are named only in `hooks/ai-dlc-gate-remediation-guard.sh` and
  `scripts/report-propagation-fanout.sh`; step section 5 says the step takes no trace; the writer was not found.

#### Review depth does not cluster by routing tag

The routing tag (`escalate_model`) marks 7 of 18 stories (1.1, 1.2, 1.3, 1.4, 2.3, 3.2, 5.2). Planning yield is flat
across the tag: party C/M 112 in 7 tagged stories (16.0 per story) against 110 in 11 untagged (10.0); p1 C/M 10
(1.4 per story) against 13 (1.2); elicitation 6 against 9; p2 1 against 1. Downstream cost concentrates: of $440 of
implementation, gate and sprint-review dollars attributable to a story ($59 and 31 spawns unattributable by
description), the 7 tagged stories hold $293 (67%), 25 of 39 rework or NEEDS_REWORK commit subjects (64%) and 70 of
146 ACs (48%). All 3 per-story CRITICALs are in untagged stories (party tea-14 and p1 14 in story 5.1; p1 06 in
story 2.2); p2's 2 MAJORs are in 2.3 and 5.1. No review round mentions `escalate_model` (0 of 76 party shard files and
19 + 19 + 19 later shard files), so the tag predicts downstream cost, not planning yield. The operator closed
BL-1175 item 2 (tier per-story party and elicitation by routing tag) on its own condition on 2026-11-20; s321 and
s322 were not read by tag.

#### Elicitation: the named catches that earn a separate round

Counts: elicitation shard findings headed CRITICAL or MAJOR, "repaired with the claim span in the shipped text", and
"unique-shipped candidates" (repaired, shipped, and no title-token match to a party seat or p1 to p3 finding; an upper
bound on uniqueness), from `findings/value-elicitation-merge.md`:

| Sprint, step | C/M (CRITICAL) | Repaired, span shipped | Unique-shipped candidates (repair-written / first-authored) |
|---|--:|--:|---|
| s321 requirements | 81 (2) | 29 | 27 = 7 / 20 |
| s321 architecture | 38 (1) | 29 | 27 = 8 / 19 |
| s321 stories | 85 listed, 87 in the document (6) | 57 | 42 = 23 / 19 (manual strict reading: 38 unique survivors, 25 repair-introduced) |
| s322 stories | 13 (1) | 7 | 5 = 0 / 5 |
| s323 requirements | 20 (1) | 9 | 9 = 6 / 3 |
| s323 architecture spine | 9 (0) | 8 | 4 = 3 / 1 |
| s323 carry-over evaluation | 24 (0) | 14 | 13 = 2 / 11 |
| s323 stories | 17 (1) | 7 | 4 = 3 / 1 |

s322 had no elicitation for requirements, architecture or carry-over; s321 had none for carry-over.

Named catches no other round raised, all repaired and in the shipped text:

- requirements s321 CRITICAL `08.md` F-1: the collision list omits `mode_transitions`, so a Base halt row blocks a
  Matic boot (capital path).
- requirements s323 `10.md` F-1: the FR-S323-8 sentinel close signal is vacuous at HEAD in a serial pytest run
  (only the elicitation shard mentions it: party 0 of 30, p1 0 of 15, p2 0 of 15 files).
- requirements s323 `9.md` F-1: the `:17919` ceiling refusal reaches 20 signing callers with no carrier.
- architecture s321 CRITICAL `3.md` F-1: the staged Base file fails the Base startup self-test, so the "no restart"
  enable path is dead.
- spine s323 `3.md` F-4: "RED (HEAD signs without gasPrice)" is false against the installed eth-account (HEAD
  raises TypeError).
- stories s321: 38 unique survivors at $2.86 each (87 findings including 6 CRITICAL); s322 CRITICAL `4.md` F-1 (AC7
  unsatisfiable, the test already red, cause outside the changed paths); s323 `cross.md` F-1 CRITICAL (1.2 AC3
  `:15453` no-sign test cannot pass before 1.4 caps `:15456`).
- carry-over evaluation s323: 11 of 13 candidates first-authored; Item 1's per-site AC "no transaction is signed"
  cannot hold at the Leg 2 site; Item 7 says the Playwright mTLS wiring is absorbed while the S319 row says
  deferred; an operator ratification with no verbatim quote.

Cost of the round and its repair tail (spawns, dollars, agent-minutes; wall is usable for s323 only): s321
requirements 34 spawns $93, 716 agent-min; s321 architecture $52, 422; s321 stories 70 spawns $149, 1,184; s322
stories 18 spawns $51, 375; s323 requirements 45 spawns $46, 159 agent-min (round 12 min wall, tail 126 min of which
28 min are operator asks); s323 architecture 10 spawns $19, 67 (33 min); s323 carry-over 9 spawns $18, 61 (19 min);
s323 stories 41 spawns $61, 235 (21 + 85 = 106 min wall, 47 of the 85 being the dispatcher idle of D1).

Two proposals to remove the round were read and not adopted. Running it concurrently with the party round (requirements
and architecture) gives up findings on text the party repair or operator answers wrote after the party round: unique
candidates on repair-written text against all, s321 / s323: requirements 7 of 27 and 6 of 9, architecture 8 of 27 and
3 of 4, carry-over 2 of 13, stories 23 of 42 (proxy) and 3 of 4. Folding into pass 1 loses the elicitation lens
unless the p1 brief carries it. Re-raise by passes 1 to 3 cannot show uniqueness, because a repaired defect cannot
recur. The span-overlap flags failed their own calibration control on the s321 stories reading (flag A: repair-introduced
10 of 23, unique-survived 19 of 38; the seat flag 36 of 38 unique survivors), so the proxies are upper bounds. A
natural experiment (s322 ran no elicitation for requirements, architecture and carry-over) shows an absorbed yield for
carry-over only (p1 C/M to party C/M 0.54 without, 0.13 with) and is one cell per sprint. Uniqueness of the s323
catches is not measurable because the planning record is one commit.

#### Defects

- **DEFECT D1 (47.2 min of wall, $4.0 dispatcher; s323 only, 1 of 10 dispatchers; s321 and s322 had 1 dispatcher
  each with 0.2 and 0.1 min lag).** The elicitation-repair dispatcher (06:21:12-07:13:57) ran 17 remediators that all
  ended by 06:26 (0.7 to 3.1 min each), then waited 6 beats of 540 s on
  `wait-for-deliverable.sh --complete --shard-header elicitation`. The return lists 17 MISSING or UNFINISHED. The
  dispatcher's closing text says the parts passed `--check-part` and were closed, and that the `--shard-header
  elicitation` flag "looks wrong for a repair round whose records have no provenance block". The flag is in the
  lead's dispatcher brief; the 17 per-part briefs carry none. The engine text (`_gate-procedures.md:613`) says the
  elicitation repair is dispatched "as the party repair is"; the lead's generator reused the elicitation line. Cause
  is the dispatcher's reading plus the brief grep; the wait script was not replayed. Fixes: generate briefs by
  script (P2), and make `wait-for-deliverable.sh` refuse at the first beat when a marked shard fails the header
  check permanently, instead of looping its beat budget (`core/scripts/wait-for-deliverable.sh:1115, 1190`).
- **DEFECT D2 (41 min of wall, upper bound; 1 shard, one round observed).** p2 adversary shard 06 (08:40-09:33, 52.9
  min against a median 4.9 and p90 11.6) issued one Bash call at 08:44:22 that did not return for 49.1 min; its
  result reads "The user doesn't want to proceed with this tool use", written when the lead stopped it after an
  advisor call at 09:32. A shell loop of `rm` and `printf` cannot run 49 min, so a permission hold is the likely
  cause (inference, not verified). The lead's beats at 09:21 and 09:32 printed shard status; no rule bounds a
  silent shard. `wait-for-deliverable.sh:205-233` documents why silence is tolerated (a live teammate on one long
  tool call, 57 of 844 episodes past 1200 s), so the fix must key on the transcript: the last event is a tool_use
  with no result older than N min and the command is not a known long runner. An 8.3 min re-run follows. The other
  rounds' longest shard was 13.3 min (p1), so this is a tail event, not a rate.
- **DEFECT D3.** `stories-test-strategy.md:313-317` says `Kind` is "exactly one of test, predicate, deploy-time".
  `validate-handoff-evidence.sh` never refuses on Kind vocabulary (its own header, about lines 299-300 and 577) and
  reads only Kind=test rows (108). 27 of 178 s323 Kind cells are off the vocabulary (unit 15, missing 5, live_ops
  read 4, capture 1, manual_operator 1, deferred 1); 15% of rows are unchecked by Check 21's node-exists arm.
  Either enforce the vocabulary or delete "exactly".
- **NOTE D4 (compaction reload).** The lead read the step file 33 times in s323 (565,882 B of results; 11
  compactions in the step plus 8 in the gate), `gate-validation.md` 39 times (550,247 B), `pipeline-snapshot` 24
  (604,037 B) and `postcompact-digest` 24 (304,025 B). The step file is 4 chunks of 16 KB per reload. Half the file
  (about 28 KB, the authoring standards) is used only in the first 23 min. Moving it to the story-authoring seat's
  role file halves the step's reload (upper bound about 280 KB of Read results a sprint). Guard:
  `validate-ac-falsifiability.sh:212-219` reads `AC_UNBOUNDED_TERMS` from this file, so that list must move with a
  pointer or stay.
- **NOTE D5.** 17 advisor consults in the step; each blocks the lead; not separated per consult.
- **NOTE D6.** The story `## Changelog` (28,859 B at planning) has no engine reader; the "append a changelog to each
  story" clause of step section 4 is a cut candidate.
- **NOTE.** Step 3 (`:536-540`) never names the status value the yaml takes, while the story template emits `draft`
  (18 stories failed Check 5 on it).

#### Redesigned shape

Kept: the party round, p1, p2 (rule-bound ladder), the elicitation round as a separate round, and the story gate.
Adopted changes:

1. A brief generator script (`core/scripts/gen-round-briefs.sh`) and one commit after each review round.
2. The strategy ids, the mapping and the lettered-case rows are written by script from the ACs (ST323 ids are one per
   AC and the lettering is regex-defined); one seat writes the command column per AC only where an AC does not name
   its own command; Check 21 covers the rest. UPPER BOUND $28.2 and about 55 min of step wall.
3. One authoring-time self-check script at the end of steps 2a, 3 and 5 runs `validate-spec-join`,
   `sprint-status.sh check-stories`, the J2 chain check, `validate-ac-falsifiability` and `validate-locked-anchor` on
   all stories and prints one verdict; the gate becomes a re-run. UPPER BOUND about 60 min of wall and $4.3, plus the
   8 compactions the 78 min gate produced.
4. The two stalls fixed: `wait-for-deliverable.sh` refuses at the first beat on a permanent header failure (D1); a
   silent-shard rule keyed on a tool_use with no result (D2). Observed idle removed: 88 min (16% of the step's 544
   min of wall).
5. The Kind vocabulary enforced, or "exactly" deleted (D3).

Proposed by the reader and not adopted: folding the SM and dev seats into the tea and architect briefs ($22.3 of
spawn cost for 7 shipped sole-source blocks, 12 sole-source C/M blocks lost unless their lens is folded in);
removing the elicitation round and its repair (up to $60.8 and about 101 min); a single cross item per party-repair
part with no separate fan-in (tail 50 min to the parallel body's 34); moving the 28 KB of authoring standards to a
role file (D4). Not recommended: tiering review depth by the routing tag (CRITICALs sit in untagged 2.2 and 5.1;
planning yield is flat); cutting p2 (rule-bound; it caught repair-text MAJORs; s321 agrees).

Upper bound for the adopted items: strategy $28.2 and about 55 min; self-check about 60 min and $4.3; stalls 88 min of
observed idle; brief build 15 min. These overlap on the critical path and are not additive: the reader's own bound
for its full list (including items not adopted) is up to about 4 h of the 9.07 h step wall and about $112 of $348,
and is the ceiling of what the record shows, not a target.

#### What was not measured, and whether it was available

- Uniqueness of party and elicitation catches in s323: not available (one planning commit; the pre-repair bytes do
  not exist). Available for s321 (two commits) from the existing reading.
- Lead active minutes per part: the gap-summing method returned 445 min against a segment total of 355 and failed its
  control, so it is not reported; call counts per window are. Per-segment figures were available.
- Why a fan-in remediator takes 40 min: the transcript was available and was not read.
- How many ACs went stale as 4.3's AC6 did: diffs of frontmatter and strategy rows per rework commit were available
  and were not made.
- The writer of `traceability-matrix.*`: not traced.
- The consequence of a missed p1 CRITICAL in 2.2 and 5.1: the counterfactual is not measurable (the stories finished
  with rework counts 0 and 1).
- The value of the gate failures in s321 and s322 beyond the three repair-file counts; s322 had 5 per-story seats
  while the lead brief says 8 stories, not reconciled.
- Whether a permission hold caused D2: inference only.
- Per-finding bodies for elicitation: 12 read (all s322 and s323 CRITICAL and the named deciders), not all 287 C/M
  bodies; a full read was available at a cost of hours.
- Whether pass 1 would have raised the elicitation catches: not testable from this record. A pass-1 shadow run on
  the post-party text is possible only for s321 stories (the commits exist).
- The count of "repaired and shipped" is a floor: spans were searched in planning markdown at the sprint's merge
  commit, excluding SPEC, subject files and json.

### 6.6 Implementation build

Files: `core/skills/ai-dlc/steps/implementation.md`, 52,676 B, 753 lines, 2 code blocks (the build half is about 22 KB:
lines 1-275, 347-390, 683-740; the gates are about 31 KB and are section 6.7); `_dispatch-protocol.md`, 20,357 B,
331 lines, 0 code blocks; `core/team-roles/dev.md`, 31,678 B, 473 lines; `dev-escalated.md`, 4,665 B (delta only).
About 60% of the build half is procedure a script could carry (worktree cut, record-dispatch, snapshot rows, ledger
read, merge and worktree removal, status transitions); the judgment is the routing tag, the wave plan, the brief and
conflict resolution. Source: `findings/step-impl-build.md`; admission-wall figures from `findings/reconcile.md`.

Step files: `implementation.md`, `_dispatch-protocol.md`

#### Cost (monotone clock; hours; the build half only)

| | s321 | s322 | s323 |
|---|--:|--:|--:|
| Elapsed h, corrected | 16.6 | 8.0 | 5.8 |
| Lead own (model + tool) | 3.4 | 3.5 | 2.7 |
| Idle, no agent running | 0.4 | 0.3 | 0.1 |
| Lead waiting on agents under 5 min | 6.9 | 2.2 | 1.5 |
| Operator wait | 3.9 | 1.5 | 1.6 |
| Long agent wait (over 5 min) | 2.0 | 0.6 | 0.0 |
| Spawns | 155 | 68 | 118 |
| Subagent $ (one-hour cache-write rate / five-minute) | 286.9 / 247.6 | 65.4 / 55.4 | 240.1 / 203.3 |
| Lead calls | 1,588 | 1,435 | 1,183 |
| Compactions | 13 | 8 | 12 |

Source: `steps/reconcile/B_tables.txt` (the "implementation build" rows; gates are the next section). The build half in
s321 is 16.6 h on the declared step boundaries; the old label gave 14.3.

The reader's window is the whole implementation step on s323 (lead session `53b4296a`, 2026-11-18T12:45Z to
11-19T03:10Z, 14.4 h, plus the 2.x session `64926214`), 3,899 lead calls paired by id, 32 dev and dev-escalated
spawns, 15 story branches in graph read only. Figures below marked "window" are for that window and include the gates.

- Dev seats: 32 spawns, $162.5 (dev 25 = $58.8; dev-escalated 7 = $103.7; the 5 escalated stories of 18 are 64% of dev
  dollars). Dev wall 1,600 min, of which 522 active and 1,086 (68%) standby. $9.0 a story against s321 $6.4 and s322
  $5.0 (label-based, implementation plus gate-validation[implementation]).
- The lead was busy 843 of 855 min (99%) in the window: 216 calls a story; 373 errored or refused calls cost 146 min.
- Dev build (dispatch to last pre-gate commit) is 11% of story elapsed (498 of 4,503 summed min; 2 to 98 min a story
  against 73 to 495 min from dispatch to merge). Gates (gate 1 to merge) are 75 to 90% of every story's elapsed time.

#### Part table

| Part (file:line) | What it is for | Cost (s323) | Produces; who reads it | What it caught | Verdict |
|---|---|---|---|---|---|
| 1 Context load (`implementation.md:15-22`) | Read stories, status, architecture slice | 12:45:11-12:46:58, about 2 min of lead, 12 calls | Nothing durable; the lead only | None | KEEP |
| 2 Spawn binding, Rule 19(a)(b)(c) (`:24-62`) | Model and role contract on every dispatch | 33 dev dispatches, 4 refused by the guard (no `Deliverable:` line); 80 guard refusals across all briefs | Ledger rows (`ai-dlc-dispatch-guard`) read by Check 22 and the lead (36 ledger reads) | The guard refusals are the catch (80 calls, 4 of them dev) | KEEP. Fold the `Deliverable:` line into a brief template: up to 50 min of lead a sprint across dev and gate briefs (`:315-345`) (UPPER BOUND) |
| 3 Routing tags and escalated role (`:64-101`) | Choose dev, dev-escalated or protected-path-editor | 5 of 18 stories escalated = $103.7 (64% of dev $); dev-escalated $20.7 a story against dev $2.5 (opus, 41 to 208 min lifetimes, 185 to 235 calls); story 1.1 needed two spawns and a 4-finding rework = $34.2 | The tag in the story file, committed before the worktree cut; read by Check 22 | No per-story catch comparison was possible | KEEP; measure escalated against dev catches per story (data not available per story) |
| 4 Auth check (`:108-112`) | `gh auth` | 2 calls, 0 failures | stdout | None in s323 | SCRIPT into the dispatch pre-flight; about 0.05 h |
| 5 Worktree and record-dispatch (`_dispatch-protocol.md:18-109`) | One isolated worktree per story; base sha record | 12:48:34-12:49:17 for 9 worktrees; 2.5 min lost to the index form (`--record-dispatch s323-1.1` failed; the form is `1-1`; `:35` writes `s<N>-<story-index>` with no example) | Worktree; `.git/ai-dlc/stories/s323-<i>` dispatch sha read by `merge-review-shards --check-serial` and the partition (gates 1 and 2) | Cross-worktree stash and branch thrash named in the rule text; none seen | SCRIPT one command `dispatch-story.sh <story> <base>` (worktree add, record, canonical-story pre-flight `:308-320`); about 0.1 h and 12 lead calls a sprint |
| 6 Bounded-join mandate (`:111-185`) | Background dispatch; wait beat on the deliverable | 145 wait-beat calls (26 min of lead) and 19 `tail task output` polls (14 min) | Deliverable file; the Stop hook | Prevents operator lockout (operator wait in the implementation label 0.09 h) | KEEP. The beat quantum is 3.0 min a call, so a 39-min wait is 21 calls |
| 7 Wave-DAG plan (`:186-217`, held lines `:200-201`) | Parallel waves and `held:` lines | One 4.1 KB Write at 12:47:40; the lead broke the chain at 21:13 | `wave-dag.md`, read by the lead only (5 mentions) | Silent over-serialization is the stated catch. Here it caused 5.0 to 8.4 h late starts for 7 stories | SHRINK: wave plan by real content dependency only. Ownership by function region; dispatch everything not content-dependent at once; `held:` only for by-content edges (3.1 then 3.2, 5.4 then 5.5), with a by-content successor dispatched on its predecessor's branch tip. UPPER BOUND up to 6 h of step wall (the second chain) and up to 2 h of lead if calls fall |
| 8 Prompt cache discipline (`:219-232`) | Byte-identical shared block | Dev prompts median 3,563 chars; 20 dev dispatches | Cache hits | None measured | KEEP (cheap) |
| 9 Task list and self-validate (`implementation.md:152-210`) | Tasks per story; 4 checks | 0 TaskCreate calls in 3,899 lead calls (control: 404 Agent calls); 2 spawn-ledger reads inline | Nothing (gate log line: 0 matches, control: 318 gate-log mentions) | None | CUT lines 152-159 and 180-210 (keep the item 4 closing writer at `:160-178` and the ledger read); about 3.5 KB off a file the lead re-reads 24 times |
| 10 Instruct all teammates and mandatory evidence (`:212-271`; evidence list `:225-254`) | The evidence the dev must log | Restated in `dev.md:171-306`, which the dev reads first; the lead never sends it | Story-file sections read by gate-validation checks 4, 5, 6, 10, 21 and by QA | See rows 14 to 17 | MERGE into `dev.md` (single copy); `:214-254` deletes about 2.6 KB |
| 11 Dev seat (`dev.md`) | Implement the story | 25 dev + 7 escalated: 1,600 wall min, 522 active; $162.5 | Code and tests are 57% of typed bytes (tests 45%, code 12%), records 43%; commits | First-pass failures are caught at gate 1 (1.78 passes a story) | KEEP |
| 12 Pre-reviewer (`dev.md:279-287`) | AC and diff review before gate 1 | 3 spawns, $0.82, 0.3 to 0.6 min each (about $0.2 to $0.33 a spawn) | Findings repaired in session; ledger | Story 2.2: 2 real defects (an AC literal not named; a vacuous paired control); all 3 stories first-pass clean | KEEP; 3 of 18 coverage only (BL-1166 owes the outcome line) |
| 13 Handoff validator and commit-presence (`implementation.md:347-390`) | Refuse unfinished handoffs | Gate-transition 139 calls (45 gate-1: 32 ok, 13 refused = 29%); tool time 33 min | Plan file; REFUSED lines to the dev | Refusals: empty-cell 35 results (Strategy Test IDs blanks), no-command 9, dar-heads 7, full-collection 5, dar-missing 2 | KEEP the arms that catch. SCRIPT the fix: `validate-handoff-evidence.sh --fix` for dar-heads (already rendered by `--render-dar`) and empty-cell prefill. Each refusal costs a dev resume (842 standby min over 22 resumes; mean idle 38 min) |
| 14 Dev evidence checklist (`dev.md:171-290`, 19 items; `:309-385`, 5 more) | Self-attestations before handoff | Scope Verification 2.4 KB of 516 KB story text; Cross-CI Parity 0 sections; about 0.3 h of dev time | Read by reviewers; the items with no script reader are Scope Verification, Cross-CI Parity, Naming-implies, Wall-clock ordering and Metric reproduction (grep over `core/scripts`, `core/skills`, `core/hooks`; control: Strategy Test IDs and Smoke Test Updates found). Production Integrity Tests and Rename Verification are read only as "section has no content" (`validate-handoff-evidence.sh:539, 1990`); Smoke Test Updates is checked for real (`:965, 1059`) | Of 171 Critical or Important findings over s321 to s323, about 33 cite one of the 24 items; Scope Verification drew 2; almost none led to a code or test change (`findings/value-open-items.md`, item 4) | KEEP, as the operator decided on the evidence. The ten items with zero findings and no script reader (including four of the five named here) are on record as cut candidates and are not cut |
| 15 Full-collection run, capture and Dev Agent Record heads (`dev.md:315-384`) | Prove the baseline green; evidence | 51% of dev active time is tests and waits (165 min test and lint calls, 103 min wait beats, 268 of 522); 183K lines of captures | The validator reads 25 lines and the counts | Baseline breaks found by the dev (named in the rule text; no s323 instance counted) | SHRINK: keep the run, commit a 60-line summary (command, head, counts, last 40 lines), log outside git |
| 16 Dev Agent Record and four evidence sections | Record for QA | 142 KB of 516 KB story text = 28% (plus Smoke 13 KB, Production Integrity 13 KB, Rename 5 KB) | Read by every gate spawn and checks 4, 6, 10 | dar-missing and dar-heads refusals 9 | SHRINK the Dev Agent Record to a rendered block (heads are already rendered) |
| 17 Lead per-story bookkeeping (`implementation.md:702-740`) | Snapshot rows, Seam C, gate log | 297 `snapshot-update` calls (120 `--activity`); 318 gate-log mentions; lead minutes 65 + 36 + 45 (snapshot read) | `pipeline-snapshot.md`, read after each of 50 compactions (121 reads including denied) | The In-Flight row prevents re-dispatch of running seats | SCRIPT one `story-transition.sh` writing the snapshot row, the gate-log line and the Seam C check; up to 1.5 h of lead a sprint (UPPER BOUND; the gate-driven share is not separated) |
| 18 Merge and worktree removal (`_dispatch-protocol.md:62-65`) | Land the story | 17 merge-class calls, 2.5 min; the merge class is 441 calls, 57 min including the gate side | Merge commit; the lead resolves conflicts | Combined-diff hunks exist in 9 of 18 merges (2.2, 3.1, 3.2, 4.2, 4.3, 4.4, 5.1, 5.4, 5.5) and in none of 1.1, 1.2, 1.3, 1.4, 2.1, 2.3, 4.1, 5.2, 5.3 | SCRIPT (`guarded-merge.sh` and its hook exist) |
| 19 Sub-step advisor calls (Rule 32) | External gate | 66 consults, 46 min of lead | None in the repo | | Out of scope here; the post-compaction call is kept (section 7) |

Parts of the lead's time that could not be separated: snapshot and gate-log time is mixed across the build half and
the gates (one command serves both); the baseline Ops spawn (40 min, $4.9) and a general-purpose "baselines
supervised" spawn (31 min, $0.5) ran off the critical path and were not analysed.

#### What the dev seat spends

32 dev and dev-escalated spawns, 2,729 tool results; active is wall minus gaps over 300 s; 522 active min, 1.208 M
output tokens (control against `spawns.jsonl`: 1,208,231), 352 M cache-read tokens; $162.5 is apportioned by token
weight at a fit of 2.2 to 4.1 $/M units (median 2.5).

| Activity | Calls | Active min | % output tokens | $ | Note |
|---|--:|--:|--:|--:|---|
| Run tests and lint (foreground) | 448 | 165 (32%) | 23% | 23.3 (14%) | foreground cap 3.0 min a call; 29 calls over 2 min |
| Wait on own background job | 76 | 103 (20%) | 3% | 3.9 | 34 chains, longest 39 min over 21 beats (1.1 rework), then 19 and 19 |
| Bash grep, sed, cat reads | 553 | 53 (10%) | 14% | 38.1 (23%) | 52 "over the one-read limit" Read denials push the dev to `sed -n` |
| Other Bash | 179 | 39 (7%) | 4% | 9.7 | |
| Write code and tests | 137 | 26 (5%) | 10% | 7.7 (5%) | |
| Evidence validators and mutation-red replay | 267 | 35 (7%) | 11% | 11.8 (7%) | |
| Write records (story file, captures, reviews) | 129 | 21 (4%) | 8% | 6.4 (4%) | |
| Read story, architecture, conventions | 243 | 18 (3%) | 4% | 12.2 (8%) | |
| Git status, diff, commit | 310 | 21 (4%) | 7% | 9.3 | |
| Final text, messages, ToolSearch, Monitor, context | 250 | 40 (8%) | 8% | about 25 | |

Directly attributable code writing is $7.7; directly attributable paperwork (records, validators, mutation replays) is
$18.2, 2.4 times; reading is $52 (32%); tests $23 (14%) but 51% of dev minutes. Dollars by activity use a fixed
token-price ratio; seats on opus carry the larger fit factors.

What a dev types and commits: through Edit, Write and heredoc, 501 KB typed (tests 45%, code 12%, story file 21%,
other records 22%). Committed by devs on 15 story branches (231 non-merge commits inside dev spawn windows plus 2 min):
209,568 added lines = 96% records (capture `.txt` 87%, `docs/reviews` 6%, other `_bmad-output` and escalations 2%,
story files 1%), tests 3%, code 0.3% (551 lines). Per story, code plus tests range 0 to 1,483 lines against records 69
to 46,644. Story files at the branch tip total 516 KB (Dev Agent Record 28%, Acceptance Criteria 30%, Gate-2 mapping
8%). Rework: 16 rework or fix dev spawns ($53.6): 9 code-bearing ($41.8, 504 min), 6 record-only ($11.4, 86 min), 1
unknown; first dispatches: 13 code-bearing ($104.1), 1 record-only, 2 unknown (2.1 and 2.2 have no derived base).
Errors in dev seats: 165 of 2,729 results (6%): 52 read-limit denials, 12 or more suite-admission refusals (35 in dev
seats, 54 in QA, 15 in reviewers: 104 refused results in subagents under that reader's count), 9 steering-budget polls.

Story timeline (minutes from dispatch): 1.1 first commit 2, last dev commit before gate 1 at 76, dispatch to merge 495;
4.2 73; 4.3 102; 5.1 150; 5.3 216; 4.1 233; 4.4 256; 5.4 302; 5.5 300; 3.2 428; the four stories dispatched at 21:13Z
(1.2, 1.3, 1.4, 5.2) 362 to 382. The full table is `steps/implementation-build/story_timeline.out`. Wave 1 was nine
briefs in one message after 2.4 min of brief writing; the first dispatch was 6.5 min after the step started; the first
commit follows dispatch within 0 to 14 min for all 15 stories (median 2); the lead handoff lag from the last dev
commit to the first reviewer dispatch has median 2 min (1 to 10).

#### The wave plan and the test-suite admission wall

The wave plan in graph chains 1.1 then 1.2, 1.3, 1.4, 2.1, 2.2, 2.3, 5.2 as eight waves "after N merges". Story 1.1
took 495 min from dispatch to merge, so its successors started at 21:13Z and the 2.x stories the next day. The lead
broke the chain at 21:13Z by dispatching 1.2, 1.3, 1.4 and 5.2 together (all on `execution.py`, 8.4 h after wave 1); all
four merged with no combined-diff hunk. Seven stories (1.2, 1.3, 1.4, 5.2, 3.2, 5.5 and the 2.x stories) started 5.0 to
8.4 h late. s323's dispatch spans 8.4 h; s321 spans 30.5 h and s322 29.6 h (dispatch clusters at +0, +3.4, +13.6,
+19.5 and so on to +30.5 h in s321; +0, +5.1, +7.9, +9.5 h in s322). The reader's bound is up to about 6 h of step wall
(the critical path of 1.1's gates at 8.2 h plus the successor cycle of 6.3 h, 14.5 h, falling to about 8.2 h),
realised only if lead calls fall as well, because the lead is saturated. The "0 conflicts" holds for the `execution.py`
chain only: the 9 merges with combined-diff hunks are mostly other files. Against the s323 baseline, writing down what
the lead already did saves 0 h; the saving is the second chain, which the lead did not release early. The operator
decision records this as a real saving of up to 6 h on the second chain, realised after the admission wall and the
lead's call load fall.

The step-level numbers on the admission wall: 177 result blocks and 134 distinct refused readings (a floor; retry
loops hide attempts) in 36 subagents plus 2 lead sessions; 123 of the 134 fall on 2026-11-18 between 13:00 and 23:59Z.
Waits: 36 subagents with a refused launch spent 1,149 agent-minutes between the first refused reading and the next
admitted one (560 at the lower bound; not wall clock): story 1.1 419 agent-min (the dev-escalated rework alone 315 and
114 refusals), 3.1 285 (QA pass 2, 284.9 min), 5.2 222 (dev, 198 min), 1.3 100, 4.1 37, 1.2 26, 1.4 25, unnamed seats
29, 2.1 5. Separately, the dev of story 3.2 lost 82 min to three one-process combined suite runs of 28, 27 and 27 min
(agent `a8b075e670fcd22ad`); story 3.2 merged last (03:35:21Z). The step wall with both waits fixed is 4.3 h (upper
bound; 1.7 h for the QA wait alone). The wall-clock effect, the chain test and the cause (recorded as the local model
server's memory by one lead message, not measured) are in section 7. The build half's dev seats are 35 of the refused
dev-seat results on that reader's count.

#### Defects

- **DEFECT 1 (wave plan holds shared-file stories behind full gate cycles).** `_dispatch-protocol.md:186-217` and
  `implementation.md:64-101`. Up to 6 h of step wall (above).
- **DEFECT 2 (the lead pays 146 min on refused or errored calls).** 80 dispatch-guard refusals (50 min: 35
  gate-adjudicator, 8 code-reviewer, qa and dev briefs lacking a `Deliverable:` line; 4 of 33 dev dispatches); 146
  context-mode "over the one-read limit" denials (49 min: `pipeline-snapshot.md` 56, `implementation.md` 55,
  `postcompact-digest.md` 32, the lead trying a whole-file Read although the step text says chunks); 67 post-compact
  recovery denies (27 min). Root cause: 50 compactions in 14.4 h (one per 17 min), each re-reading `implementation.md`
  (51 KB: 96 chunk reads plus 55 denied), the snapshot (65 plus 56) and the digest (63 plus 32). Engine:
  `implementation.md:115, 753` (chunk wording) and the `ai-dlc-postcompact` hook.
- **DEFECT 3 (committed test logs).** Dev full-collection captures are 15 to 30K lines each
  (`test-results/s323-5-4-full.txt` 30,323 lines; 5-3 and 5-5 15.8K and 15.5K, each with a "-base-full.txt" twin),
  re-committed on rework: 183K lines added and 46K deleted by devs; 13.8 MB in 233 capture files, 18 over 200 KB.
  Required by `dev.md:315-346` and `366-384`. The validator checks the first 25 lines for `$ ` and `head:` (REFUSED
  no-command 9 results) and the counts line; nothing reads the 15K body (QA and reviewers replay, they do not read
  it). Upper bound: history growth only; dev tokens barely move.
- **DEFECT 4 (standby seats pay cache rewrites).** 37 gaps over 300 s (last message text-only, then a lead
  SendMessage 22 gaps / 842 min, or an own-job notification 15 gaps / 231 min); the message after each gap carries
  7.7 M of the seats' 12.4 M cache-write tokens, estimated $29 to $48 of $162.5 (assumes a five-minute cache TTL;
  net of cache-read about 90% of that). `dev.md:421-426` requires the report then idle; a rework as a fresh dispatch
  (16 rework or fix spawns) also pays a cold start. One dev lived 288 min wall: 256 standby, 32 active.
- **DEFECT 5 (escalation cost).** Dev-escalated $20.7 a story against dev $2.5. Not judged wrong: no per-story catch
  comparison was possible.
- **NOTE 1.** Sections 3 and 4 and the section 5 instruct list are dead or duplicated (about 7.4 KB of the 52.7 KB
  file, lines 152-275, with the lead re-reading it 24 times).
- **NOTE 2.** `record-dispatch` needs the `1-1` index form (2.5 min lost).
- **NOTE 3.** `gh auth status` (`:108-112`): 2 calls, 0 failures; fold into a pre-dispatch script.

Efficient, no change: first commit within 0 to 14 min of dispatch for all 15 stories (the early-scaffold rule works);
the lead-to-gate-1 handoff lag; the nine-way first wave dispatched in one message; the pre-reviewer ($0.2 to $0.33 a
spawn, 3 of 18 stories, s323 gate-1 passes 1.78 a story with 9 of 18 clean against s322's 2.50).

#### Redesigned shape

The dev seat, one worktree per story, the record-dispatch sha, the handoff validator and the pre-reviewer earn their
place. What does not: the lead hand-driving each dispatch, bookkeeping row and merge at 216 calls a story and 12 s a
call while 99% busy; a wave plan that waits for full gate cycles; 5 evidence items nothing reads and 3 that check
only "heading non-empty" (kept per the operator's decision, see row 14); 15K-line logs committed as evidence; a
recovery path that re-reads 51 KB after 50 compactions.

1. `dispatch-story.sh <story>`: pre-flight (gh auth, canonical story file reachable, escalate tag committed),
   worktree add, record-dispatch, In-Flight snapshot row, a brief from a template that already carries the
   `Deliverable:` line, role line, no-stash line and exploration budget; the lead supplies only the route and a
   3-line delta. Replaces about 12 lead calls a story and the dev share of the 80 guard refusals.
2. Wave plan derived by script from story `owns:` paths at function-region grain; every story without a by-content
   edge goes in the first wave; a by-content successor is dispatched on its predecessor's branch tip, not after
   merge and gates. Gate capacity then sets the pace.
3. The dev runs `validate-handoff-evidence.sh --dev-check` as its last action, with the same arms and frozen sha as the
   lead's gate-1 handoff (13 of 45 gate-1 transitions refused; each costs a lead round trip, a seat resume at 38 min
   mean idle and about $0.8 to $1.3 of cache rewrite).
4. Capture rule: commit a summary (command, head, counts, last 40 lines) and keep the log outside git; run summaries,
   not logs.
5. One `story-transition.sh` writes the snapshot row, the gate-log line and the Seam C check; post-compact recovery
   reads a rendered 16 KB step digest, not `implementation.md` in 4 chunks plus the snapshot and the digest.
6. Cut the dead step sections (the task list and self-validate, `implementation.md:152-159, 180-210`) and merge the
   evidence list `:214-254` into `dev.md`.

Gains per sprint, all UPPER BOUNDS: item 2 up to 6 h of step wall, realised only with items 1 and 5 since the lead is
saturated; items 1 and 5 up to 2.4 h of lead (error calls) plus 1.5 h of bookkeeping plus about 1 h of recovery reads;
item 3 up to 0.65 h of lead and $22 to $28 (13 refusals times the cache rewrite plus the 6 record-only reworks at
$11.4); standby cache rewrites $26 to $43 shrink with fewer resumes; item 4 no dev dollars, repo growth 13.8 MB; item
6 about 6 KB of text re-read 24 times. These overlap through the lead's call load and are not additive. Engine
lines: `_dispatch-protocol.md:186-217, 18-109, 322-331`; `implementation.md:152-271, 347-390, 702-740`;
`dev.md:171-306, 315-384`.

#### What was not measured, and whether it was available

- s321 and s322 per-story build timelines and record-only rework shares: available (graph git and transcripts), not
  done; only label totals and dispatch clusters were taken.
- Per-item catch rates for the 15 evidence items: available in graph `docs/reviews/s323`; taken for all 24 items over
  s321 to s323 in the separate reading cited in row 14.
- The 7.6 min finished-agent wait of the earlier figure is not a dev wait: the dev handoff lag is 1 to 10 min (median
  2) and notification to the lead's next call has a median 6 to 12 s for dev notifications (n=66). By gap type
  (`findings/reconcile.md` A3) dev to gate 1 has a median 1.9 min.
- Lead snapshot and gate-log time shared between the build half and the gates: not separated.
- Escalation value (dev-escalated against dev catches) per story: not measurable from the record read.
- Branch diffs exclude 2.1 and 2.2 (no dispatch base derived); commits are attributed to the dev by spawn window.
- The 28-min combined suite runs were found by the reconciler on one dev (above); the reader's 104 refused results in
  subagents differ from the reconciled 134 distinct readings by window and definition; the reconciled figure is used.

### 6.7 Implementation gates

Engine versions: `core/skills/ai-dlc/steps/implementation.md` (753 lines, 52,676 B, 2 fence marks; the gate material at
lines 296-700 is about 60% of the file and roughly 80% of it is procedure a script could carry),
`core/skills/ai-dlc/steps/gate-validation.md` (3,703 lines, 247 KB; the implementation slice loads checks 5, 6, 8, 9,
10, 11, 11a, 17, 19, 22 plus the universal row), `core/team-roles/code-reviewer.md` (873 lines, 49 KB),
`code-reviewer-escalated.md` (68 lines, same contract), `qa.md` (745 lines, 50 KB), `gate-adjudicator.md` (234 lines,
16 KB) and `core/scripts/gate-transition.sh` (638 lines). Source: `findings/step-impl-gates.md`; its scripts are under
`steps/implementation-gates/`.

Step files: `implementation.md`

#### Cost

Elapsed hours, implementation gates (step with its gate, corrected clock; `steps/reconcile/B_tables.txt`):

| | s321 | s322 | s323 |
|---|--:|--:|--:|
| Elapsed h, old -> corrected | 8.1 -> 7.9 | 5.1 -> 5.1 | 9.5 -> 10.5 |
| Lead own (model + tool) h | 3.1 | 2.2 | 6.9 |
| Idle, no agent running h | 0.5 | 0.2 | 0.1 |
| Lead waiting under 300 s on agents h | 2.6 | 1.1 | 2.6 |
| Operator wait h, old -> corrected | 1.2 -> 1.4 | 0.6 -> 0.7 | 0.2 -> 0.3 |
| Long agent wait (over 300 s) h, old -> corrected | 0.3 -> 0.3 | 0.9 -> 0.9 | 0.3 -> 0.5 |
| Spawns, old -> corrected | 126 -> 126 | 39 -> 39 | 196 -> 200 |
| Subagent $, one-hour cache-write rate (five-minute rate) | 160.7 (139.5) | 71.2 (61.5) | 202.4 (169.0) |
| Lead calls, old -> corrected | 943 -> 927 | 849 -> 863 | 2,600 -> 2,875 |
| Compactions, old -> corrected | 11 -> 11 | 8 -> 8 | 39 -> 42 |

The s323 gate seats, from `spawns.jsonl` summed by role over the labels `implementation` and
`gate-validation[implementation]`: gate 1 70 seats $100, gate 2 68 seats $91, gate 3 134 seats $66, gate-label dev
rework 9 seats $30. The lead in `gate-validation[implementation]` was active 8.97 h over 2,601 calls: merge 131 min
(781 calls), other 125 min, gate-run 84 min (310 calls), snapshot 63 min, compaction recovery 37 min, dispatch 36 min,
step re-read 30 min. The gate-3 transition call (`gate-transition.sh`) costs the lead 37.3 s a call over 48 ok calls
in s323 (29.8 min; 4 calls errored) and 50.1 s over 22 calls in s322 (18.4 min). The gate-1 and gate-2 transition
calls take 2.8 s on average (44 and 42 ok calls).

Sprint wall of the implementation phase in s323: 841 minutes (14.0 h) from the first dev dispatch at 12:51Z to the
last closing-writer end at 02:52Z. With the 2.1/2.2 late wave (1.4 h) that is 15.4 h against 15.1 h on the pre-correction step clocks (reconciled: build 5.8 h plus gates 10.5 h = 16.3 h, section 4).
The wall was set by three dependency chains: 3.1 -> 3.2 at 841 minutes, 1.1 -> 5.2 at 737 minutes and 5.4 -> 5.5 at
582 minutes. Time with no seat of the chain running was 21% of the first chain, 19% of the second and 48% of the third.
The lead was working gate work for other stories in those gaps, so the gaps are queueing on one lead, not an idle
lead. The dependency-edge latencies themselves total 17, 10 and 5 minutes (32 minutes, 3.8% of chain minutes).

Gaps with no agent of the story running, by type (reconciled count over 92 gaps; `findings/reconcile.md`, A3):

| Gap | n | Median min | Over 10 min | Sum h |
|---|--:|--:|--:|--:|
| dev -> gate 1 | 16 | 1.9 | 1 | 0.88 |
| gate 1 -> gate 2 | 14 | 6.6 | 5 | 3.95 |
| gate 2 -> rework dev | 6 | 7.1 | 2 | 0.72 |
| gate 2 -> gate 3 | 13 | 15.4 | 7 (5 over 60 min) | 9.81 |
| gate 3 -> close | 15 | 17.1 | 15 | 5.00 |

All 92 gaps: median 6.6 min, 33 over 10 min, 23.4 h (9.3 h with each gap capped at 10 min). Not all of a gap is lead
lag: it includes the lead working other stories and merges.

#### Part table

File and line refer to `core/` unless stated; costs are s323 unless stated.

| Part (file:line) | What it is for | Cost | What it produces and who reads it | What it caught | Verdict |
|---|---|---|---|---|---|
| G0 handoff and gate-transition call: `skills/ai-dlc/steps/implementation.md:313-345` (+ 347-390 commit-presence and handoff-evidence validator) | Runs every validator and partition call; writes the plan only on exit 0 | Gate 1/2 call 2.8 s mean (44/42 ok); gate 3 call 37.3 s x 48 = 29.8 min lead tool time | `gate-transition/<story>-g<G>-p<M>.plan`; the dispatch guard denies a reviewer, QA or adjudicator brief without a matching plan (reads sha and story only) | Its WARNs (653 head-tree, 22 capture-unresolved, 15 head-missing, 7 section-empty, 2 placeholder across 59 gate 1/2 plans) none refuses; the same classes return as gate 1/2 EVIDENCE and BOOKKEEPING findings | KEEP the call; SHRINK the WARN set: refuse head-missing, placeholder and section-empty; fix the capture-unresolved tokenizer; head-tree stays a WARN |
| G1 gate 1 code review, first pass: `implementation.md:391-433` (partition fan-out); `team-roles/code-reviewer.md`, `code-reviewer-escalated.md` | Code review of each story's frozen sha | 70 seats, 40 waves, $100; first-pass fan-out of 6 stories = 31 seats $62.6, wall 111 min; 12 serial first passes $16.7 | `docs/reviews/s323/<story>-code-review[-pN].md` and shards; Check 1 reads the verdict line, the carried-findings validator reads Class, dev reads findings; nothing reads Suggestions | 10 production-code catches in s321-s323 (s321 8, s322 1, s323 1), none caught later by gate 2 or 3; examples: s321 2.3 reserve cap clamps a swap silently while callers record the unbounded amount (Critical); s321 3.4 silent default-fill hides an unreadable absence record (Critical); s323 5-2 busy marker omits ranges a live reader needs (Critical) | KEEP |
| G1b gate 1 re-review (record-only route, narrowing, Rule A): `implementation.md:463-510, 524-545` | Re-review of a delta after rework | 22 waves (21 serial), $20.7, wall 90 min | Review pN files | 14 pass-2+ review files, 1 NEEDS_REWORK (TEST) | KEEP; already shrunk |
| G2 gate 2 QA first pass: `implementation.md:556-640, 672-682`; `team-roles/qa.md` (checklist 181-467, shard 581-726); start condition `qa.md:65` | Honest-green canonical suite at the frozen sha, handoff-evidence precondition, smoke | 68 seats, 26 waves, $91; wall union 475 min of which 290 min is one seat (3.1 QA pass 2) waiting 277 min on a suite run refused by host-headroom admission; all QA seats 339 wait min | `<story>-qa-validation[-pN].md` | 3 production-code catches that gate 1 approved at the same sha (s321 1-2 env template; s323 3-1 CI lane wiring; s323 5-2 successful claim toasts REBALANCE FAILED) and 7 test catches; stories with code review ok and QA NEEDS_REWORK on pass 1: 2 / 1 / 4 (s321 / s322 / s323; 7 of 49); in s323 all four were serial stories, so QA is not redundant with a part shard (verified for s323 only) | KEEP; dispatch together with gate 1 (see redesign) |
| G2b gate 2 re-validation, GATE2-SKIP, record-only: `implementation.md:534-570` | Re-run QA after rework when code changed | 9 waves, $26.7; 6 serial waves = 309 min including the 290-min seat | Review pN files | The 290-min seat is a defect (below) | KEEP |
| G3 gate 3 lead run of script arms and nonce open: `implementation.md:158, 313-345`; `scripts/gate-transition.sh` | Runs Checks 2, 2a, 5, 16, 17, 22, 25, H2 in order, mints the nonce, runs `open` | 37.3 s x 48 ok calls = 29.8 min (s322 50.1 s x 22 = 18.4 min) | Plan and nonce; the model seats then re-do what it prints | Nothing it prints fails a gate | KEEP as the whole gate |
| G3b gate 3 adjudication, 8 shards: `team-roles/gate-adjudicator.md`; shards 1 / 2,3 / 4,5 / 6,7 / 8,9 / 10,11 / 11a,16 / 19,22 (`validate-gate-adjudication.sh --expected implementation --shard i/8`; 15 escalated checks) | Model re-adjudication of 15 checks | 134 seats $65.7 (94 with a shard index: mean 1.4 min, $0.40, 16 calls, 0.75M tokens; shard 8 = 4.0 min); 26 passes; nonce-to-verdict median 12.0 min, sum 338 min | `gate-adjudication/<nonce>.verdict.json` plus 8 part files; Check 26 (`gate-validation.md:2832`) reads the verdict fail-closed; the lead acts only on FAILs | Over 68 passes (1,020 check verdicts) 23 non-PASS in 6 checks, 9 of 15 checks never failed; production code changed by a gate-3 FAIL: 0 of 23; Check 22 caught a real routing breach once (3-2 dev not dev-escalated on an escalate_model story, after the seat had run, so only a record changed); Check 11 forced two e2e specs (5-1, 5-3: 52 and 112 lines, TEST) | Gate 3 becomes script arms plus one adjudicator (see redesign) |

Per-check record of gate 3, passes / FAILs over s321-s323 and what each FAIL changed:

| Check | Passes / FAIL | What the FAILs changed |
|---|---|---|
| 1 | 65 / 3 | Untracked review file, carried-line form, p2 supersede not tracked (records) |
| 2, 3, 4, 5, 6, 7, 8, 10, 16 | 68 / 0 each | none |
| 9 | 65 / 3 (s321 only) | The adjudicator failed closed on whether visual verification applied (is_ui_epic true, a UI story needs a rendered deployed URL); no code changed |
| 11 | 66 / 2 | 5-1 and 5-3 had no browser-level test; dev added e2e specs (TEST) |
| 11a | 62 / 6 | Dev Agent Record has no command, envvar or outcome (records, or a live run recorded) |
| 19 | 60 / 8 | Reviewer file lacks a map or visual citation (records); 0 FAIL in s323 after the rule moved into the reviewer's contract (`code-reviewer.md:733`) |
| 22 | 67 / 1 | Dev not dev-escalated on an escalate_model story (record; spawn already happened) |

Rework tiers over 64 NEEDS_REWORK reviews in s321-s323. Tier A is a review with a CODE-class finding where the delta to
the next gate plan's frozen sha contains a code path; tier B is TEST-class with a test or code path changed; tier C is
EVIDENCE, BOOKKEEPING or unclassed findings with 0 code and 0 test paths in the delta. The delta is the whole dev
rework, so tier A proves a finding and a code change followed, not that the change was the fix.

| | A | B | C | other |
|---|--:|--:|--:|--:|
| Gate 1 | 10 | 14 | 10 | 2 |
| Gate 2 | 3 | 7 | 17 | 0 |
| Total | 13 | 21 | 27 | 3 |
| s323 gate 1 / gate 2 | 1 / 2 | 6 / 4 | 1 / 5 | |

Commit-to-commit rework interval: tier A median 63.6 min (n 3), tier B 40.0 (n 10), tier C 34.0 in s323 (n 6, sum
4.6 h); across all sprints tier C median 16.7 min, sum 15.1 h over 27 cycles. A records-only cycle costs a dev rework
seat (about $3.3) plus a serial re-review (gate 1 $0.75, gate 2 $1.75 a wave): about $4 to $5, so s323's 6 cycles are
about $27 and three sprints' 27 cycles about $120 (upper bound; dev seats were not attributed to cycles).

Stories with both pass-1 reviews: code review ok and QA NEEDS_REWORK 2 / 1 / 4 (s321 / s322 / s323); both
NEEDS_REWORK 6 / 2 / 5, so 13 of 49 stories (27%) pay two sequential rework cycles; code review NEEDS_REWORK and QA ok
11 / 1 / 2; both ok 5 / 4 / 6. Passes per reviewed story: s321 code review 1.79, QA 1.35; s322 2.5 / 1.89; s323 1.7 /
1.6.

First-pass finding mix in s323 (gate 1 and gate 2, `####` headings under Critical or Important, 47 findings; the
count is confirmed by an independent recount): CODE 5, TEST 18, EVIDENCE 15, BOOKKEEPING 8, unclassed 1.

#### What earns each gate

- **Gate 1** earns 10 production-code catches, all Critical or Important behaviour defects on capital-path code, none
  caught later.
- **Gate 2** earns 3 production-code catches that gate 1 approved at the same sha, 7 test catches, and the only run of
  the honest-green canonical suite at the frozen sha. A miss reaches the operator: a successful Merkl claim toasting
  REBALANCE FAILED.
- **Gate 3** earns no production-code catch. Check 22 belongs at dispatch, where the guard already refuses other
  Check 22 shapes. Check 11 belongs to QA's own smoke item (`qa.md:439` names the envvar run).

Evidence and bookkeeping findings are the pipeline's own record demands: all 23 s323 pass-1 EVIDENCE and BOOKKEEPING
findings concern a capture's head line, a `$` line, a Dev Agent Record count, a Production Integrity Tests row or a
deferred_acs entry (a capture without a head sha; a capture naming the sprint base but holding the post-change tree; a
`$` line replaying a different command; a count describing the pre-rework tree; AC10 recorded REMAINING with no
deferred_acs; a mutation capture not committed). None is a defect in shipped code. Six of six s323 reviews whose
Critical and Important findings were only those classes were fixed by a records-only delta. The validator sees most of
them first: `gate-transition.sh` printed `WARN head-tree`, `capture-unresolved`, `head-missing`, `section-empty` or
`placeholder` on 54 of 59 s323 gate 1/2 plans (689 lines) and continued.

#### False-positive set of refusing the WARN classes (s323)

Method: graph's installed `validate-handoff-evidence.sh` (cmp-identical to the shipping copy) was run read only over
the 59 s323 gate 1/2 plans. 50 plans reproduce the plan's own gate-log WARN set exactly; the other 9 differ by one
line (a path resolving outside the repository because the run was in the main checkout, not a worktree); a bogus sha
prints 0 WARN. "Matched" is a story-level proxy (a Critical or Important finding of the same story names the capture
and carries an evidence word) and overstates true positives. s322 gives fired counts only.

| Class | Plans fired / lines | Reading | Decision |
|---|---|---|---|
| capture-unresolved | 7 / 7 | 7 of 7 false positives: prose tokens with a slash (`hook/out`, `name/log`) read as paths | Fix the tokenizer (require a capture extension or a `test-results/` prefix: 0 lines remain in s323) before refusing |
| head-missing | 3 / 11 | One story (5-4), four captures; QA raised Critical EVIDENCE on the same story; 0 candidate false positives | Refuse |
| placeholder | 1 / 2 | Story 3-2, `<scratch>` on the `$` line; 0 candidate false positives | Refuse |
| section-empty | 5 / 5 | 5-4 x3 is QA's Critical BOOKKEEPING; 5-5 x2 nobody raised it and the section was filled by the final sha; 0 candidate false positives on the validator's own contract | Refuse |
| head-tree | 54 / 499 | 154 distinct (story, capture) pairs; 32 pairs (21%) have a same-story finding. Of five unmatched code-delta pairs read, 4 are false positives (tracked `__pycache__` `.pyc` files counted as code; a head ending `(+dirty)`; a mutation capture at the base by design; a RED-at-base capture by design) and 1 is a stale capture nobody raised | Stays a WARN. A refusal needs three changes first: skip a head equal to the plan base or ending `(+dirty)`; count only paths the story's own diff touches; exclude `__pycache__` and `.pyc`. Whether that empties the set is not measured |

Evidence is thin: three stories supply all the non-head-tree lines.

#### Defects

- **DEFECT 1.** Gate 3 re-adjudicates what script arms and gates 1 and 2 already hold: 26 passes x 5.2 seats = 134
  seats, $65.7, 338 min of nonce-to-verdict, 0 production-code catches in 68 passes, 2 test additions, 9 of 15 checks
  never failed. Engine: `implementation.md:313-345`, the `implementation` manifest row in `gate-validation.md:65`, the
  `adjudication: llm` entries in `enforcement-map.yaml` for 12 checks, and the sharding in `gate-adjudicator.md`.
- **DEFECT 2.** A gate-2 seat polls an admission refusal for hours with no escalation. The 3.1 QA pass-2 seat (14:44Z to
  19:34Z, 289.9 min) hand-built `retry.sh`, polled `rr.log` and made 98 `wait-for-deliverable` calls against a
  canonical `--record-run` refused for host headroom; the 1.1 dev-escalated rework seat (322.7 min, 161 calls, 114
  attempts, "attempt 111 REFUSED" in its text) did the same. The admission wait belongs in one script call that blocks
  in a queue and returns the recorded run. Both waits had one cause: the local model server (`mlx-serve`) held memory
  against the suite's 26 GiB admission predicate (headroom 21 to 25 GiB) until it released it, and both seats were
  released at about 19:27Z. How much of the 74 GiB headroom the lead model holds when the suite runs is not measured.
- **DEFECT 3.** Gate 2 starts strictly after gate 1 (`qa.md:65`), which doubles rework cycles for 13 of 49 stories and
  idles QA while a fan-out reviews (gate 1 first-pass wall 161 min in s323).
- **DEFECT 4.** Record findings arrive after the dev has left: 27 of 64 reworks are records-only.
- **NOTE 1.** Check 19 had 8 FAILs in s321 and s322 and 0 in s323; the rule moved into the reviewer's contract and the 8
  earlier FAILs were each a reviewer-file rewrite.
- **NOTE 2.** `gate-transition.sh` gate 3 costs the lead 29.8 min in s323 because it runs every script arm before
  `open`.
- **NOTE 3.** `merge-review-shards` and reading shard files is the lead's largest gate class (merge 131 min, 781 calls);
  fewer seats removes calls.

Already efficient: record-only and narrowed re-reviews (21 of 22 s323 gate-1 re-review waves were serial at $0.75
each); GATE1-SKIP after a gate-3 rework (11 in s323, 0 reruns); adjudicator seats are cheap per seat ($0.40, 1.4 min).

#### Redesigned shape

1. **Handoff.** `gate-transition.sh` refuses, before any seat runs, the record classes that became findings:
   head-missing, placeholder and section-empty now; capture-unresolved after the tokenizer fix; the Dev Agent Record
   shape of Check 11a (command, envvar, outcome) and the Check 1 prerequisites (review files tracked, carried-line
   form) after a false-positive measurement. head-tree stays a WARN. Evidence for the replacement is three stories.
2. **Gate 1 and gate 2 dispatch together on one frozen sha.** `qa.md:65` is relaxed; one merged findings list goes to
   the dev; one rework; both gates re-run only if code changed (Rule A already decides this).
3. **Gate 3 = script arms plus one adjudicator.** Script arms for Checks 22, 16 and 5 and the vocabulary half of Check 2
   now; a rule table for Checks 19, 10, 8, 4, 7 and 3 after each arm is proven; one adjudicator seat for Checks 1, 11,
   11a and the hard-block half of Check 2. No 8-way shard. Check 22 moves to dispatch time.
4. **Build conditions for every scripted arm.** Fix the two validators that pass on an unexamined subject
   (`validate-escalation-status-vocabulary.sh` skips entries with no Status line; `validate-locked-anchor.sh` prints PASS
   EXAMINED NOTHING); prove each arm against a seeded failure and a near-miss; diff the program's output against s323's
   hand-written entries.
5. **The admission wait** is one blocking `--record-run` call with a queue, an escalation after a bounded number of
   refusals, and a lead-side capacity check before the gate wave.
6. The closing writer is unchanged.

#### Upper bound on saving

All figures are UPPER BOUNDS on s323 as the basis. Seat and dollar figures are story-serial and overlap; the sprint-wall
effect is the chain simulation below (`steps/implementation-gates/chain_sim.out`; lead capacity is not re-simulated, which
would favour every variant; 3.2, 5.2 and 5.5 values are a reading of `bursts.tsv`, not a replay).

| Change | Chain wall after (C1 / C2 / C3, min) | Wall saved vs 841 min |
|---|---|--:|
| Gate 3 as script plus one seat | 812 / - / - | 29 min (0.5 h) |
| Gate 1 and 2 together, one merged rework | 725 / 652 / 503 | 116 min (1.9 h) |
| Records-only classes refused at handoff | 841 / lowers C3 by 90 and C2 by 15 | 0 min (the binding chain has no tier-C cycle; matters once C1 falls) |
| The three together | 696 / 609 / 379 | 145 min (2.4 h); not additive in a simple way: 145 = 29 + 116 + 0 |
| Check 22 moved to dispatch (3.2, FAIL at 02:08, re-verify and gate-3 pass 2) | | 24 min, in none of the three |
| 3.1 QA wait fixed alone (seat to 8 min) | C1 559, C2 737 binds | 104 min (1.7 h), not 277 |
| 1.1 rework wait fixed alone | C2 454, C1 841 binds | 0 |
| Both admission waits fixed (one cause) | C3 binds at 582 | 259 min (4.3 h), 31% of the step |
| Both waits and all three items | C1 414 | 427 min (7.1 h) |

Seats and dollars, s323: gate 3 seats $65.7 to about $13 (26 passes x one $0.5 seat), saving about $52 and 134 to 26
seats; gate-3 elapsed 338 min to about 104 min, 3.9 h story-serial; gates 1 and 2 together save one rework cycle for
5 stories that failed both (about 40 min each, 3.3 h) and gate 1's wall for 6 stories that passed both (9 min each);
refusing records-only classes at handoff saves 6 cycles x 34 min = 3.4 h and about $27. The sum is about 11 h
story-serial and about $80; the story-serial hours are not sprint wall. Cost of running gate 2 beside gate 1: QA runs
on stories where code review fails and the rework changes code (2 in s323, 14 in three sprints, about $3 each).

Overlap: the 4.3 h wall saving from the admission wait and the 2.4 h from the three redesign items are different
chains and combine to 7.1 h, not the sum of the story-serial figures. Item 3 of this list also reduces the lead's gate
work and with it the queueing gaps, which is not sized here. The refusal of record classes (item 1) and the
production-side items of section 6.6 (the dev runs the handoff check as its last action) cut the same paperwork cycles;
count them once.

#### Not measured

Available and not done:

- The false-positive set of refusing the Check 11a and Check 1 prerequisite shapes (a run over the 59 s323 plans'
  records is read only and possible).
- Whether the head-tree narrowing empties that set.
- Whether the QA-only catches would have been caught by a code reviewer told to read the CI lane (3-1 was a lane-wiring
  miss that code review caught on 3.2).
- Tokens per seat for role-file reads (spawn rows hold total tokens only: gate-3 seat mean 0.75M; a serial code-review
  seat reached 3.7M in s317).
- The lead's cost for gate 3 beyond the script call (the merge and verify class is not split by gate in
  `classes.jsonl`).
- The tail story 3.2's share of sprint wall under each variant beyond the chain model.
- The 80-of-168 adjudicator spawns "ended in a plain pass by a text match" figure was not re-derived (168 adjudicator
  spawns across gate types in s323, 134 in the implementation gate); part-file evidence texts were not classified.

Not available: s321 lead Bash rows for gate-transition calls (s321 call latencies are absent; seat counts and verdict
files for s321 are complete). Caveats: the `spawns.jsonl` step label is the lead's state at spawn, so a gate 1/2 seat can
carry either label and the by-role sum includes some non-gate QA and code-review seats (50 QA seats under
`implementation` in s323; the timeline parse by description gives 70 gate-1 and 68 gate-2 seats on gate waves); 28 of
209 review files could not be joined to a plan sha and are keyed by file-name stem; a plan is written only on exit 0,
so a failed first gate-3 nonce has no plan; tier A can overstate a finding's effect.

### 6.8 Gate validation as a procedure

Scope: the six step-closing gates (carry-over evaluation, requirements, architecture, stories and test strategy, sprint
review, retro). The implementation gate 3 is in section 6.7. Engine files: `core/skills/ai-dlc/steps/gate-validation.md`
(247,205 B, 3,703 lines, 4 code blocks, all prose; 6 of its 40 checks are judgment), `_gate-procedures.md` (148,145 B,
1,822 lines, 5 code blocks), graph's `gate-validation-domain.md` extension (73 KB), `core/scripts/gate-transition.sh`.
Source: `findings/step-gate-validation.md`; its scripts are under `steps/gate-validation/`.

Step files: `gate-validation.md`, `_gate-procedures.md`

#### Cost

Gate time is counted inside the owning step's row in the corrected per-step tables (a step and its gate are one row),
so the gate's own cost is read from the gate windows (first to last lead record labelled `gate-validation[X]`).
Adversarial rounds dispatched inside a window cannot be separated and are included.

s323, non-implementation gates: lead active 300 min (5.0 h), 1,440 lead calls, 26 of the sprint's 134 compactions,
230M cache-read tokens (about 160K cached tokens re-read per call, so cost scales with call count, not with what a call
does), plus 4.3 MB of gate-file reads (`gate-validation.md` 200 reads, 2.97 MB; graph's 73 KB domain extension 53
reads, 1.0 MB; `_gate-procedures.md` 22 reads, 0.21 MB). 34 adjudicator shards, 112 agent-min, $26; 6 remediators
$5.6; 21 advisor calls, 11.9 min foreground. s322: 183 min, 1,015 calls, 14 compactions. s321: 98 min (4 of 6 gates
labelled; carry-over and retro gates carry no label, so s321 is partial).

| Gate, s323 | Lead active min | Lead calls | Compactions | Gate-file read KB | Spawns, agent-min, $ |
|---|--:|--:|--:|--:|---|
| carry-over | 19 | 110 | 2 | 584 | 4, 8 min, $2.0 |
| requirements | 25 | 133 | 3 | 386 | 3, 8 min, $1.8 |
| architecture | 51 | 271 | 5 | 951 | 7, 20 min, $4.6 |
| stories | 77 | 343 | 8 | 1,103 | 21, 87 min, $23.9 (9 adversary spawns, $15.4, are pass-2 dispatched inside the window) |
| sprint review | 89 | 467 | 6 | 960 | 13, 78 min, $16.5 (the window 14:07-20:14 also holds implementation gate-3 spawns for 2.2 and 2.3 under the sprint-review label) |
| retro | 38 | 116 | 2 | 296 | 3, 16 min, $5.1 |

s322 lead active min by gate: carry-over 20, requirements 24, architecture 57, stories 23, sprint review 32, retro 27
(183 total). s321: requirements 27, architecture 18, stories 16, sprint review 25.

Class split of the s323 300 min (lead min / calls): other 112 / 491, merge (reading shard outputs, TaskOutput) 49 /
346, step re-read 35 / 170, snapshot 27 / 167, gate-run 25 / 146, idle wait 22, compaction recovery 18 / 83, repair
7 / 18, dispatch 6 / 19. Re-reading plus recovery is 53 min (18%). The clean-gate floor is 19 to 32 min of lead time
(s321, s322 and s323 retro and carry-over); s323 stories (77) and sprint review (89) are repair-driven. Tool latency is
small (Bash 1 to 5 min a gate, Reads under 1 min), so the minutes are model time; generation and queueing on the local
model were not separated.

Anatomy of a clean gate (s323 retro, 38 min, 116 calls, no FAIL): 7 min of the Check 14 snapshot trim before the gate
(two hand-written trim scripts and an advisor call), 3 min working out how the gate runs (greps of
`enforcement-map.yaml` and `gate-validation.md`), 1 min dispatch, 5 min waiting for 3 shards (the merge refused once:
shard 1/3 carried all 9 ids), a compaction followed by a 2-minute re-read of 6 slices, 3 min of 20 evidence-collection
Bash calls, 7 min writing the gate entry and 6 min of row checks plus 2 advisor calls before close.

#### What failed and what it cost

Non-implementation gate repairs, s321-s323:

- s323 carry-over: Check 2 vocabulary, 2 tokens (CLOSED, DISPOSITIONED) in `pending.md`; the remediator was hook-denied
  and the lead edited.
- s323 requirements: three arms before the nonce (2a prose shape, vocabulary, Check 17 PRD report without a provenance
  block; a subagent re-ran the PRD validate).
- s323 architecture: adjudicator FAIL on Check 2 (an entry headed "OPEN" with no Status line), full re-dispatch of 3
  shards, then Check 15 (parser) and Check 35 (65 lines destroyed by the lead's own trim, 68 recovered from git).
- s323 stories: Checks 24 (chain), 30 and 5 repaired by three serial remediators (7.6, 6.4 and 9.3 min), 11:43 to
  12:22 before the adjudicators could be dispatched; the 8 shards then took 1.3 min.
- s323 sprint review: Check 1 FAIL ("Tip:" prefix, APPROVED outside the QA set, a stale open MAJOR on a file the
  Step-1 one-shot overwrote); remediator 0.8 min; 4-shard re-dispatch of 1.5 to 2.6 min each, about 3 min wall
  (pass-1 shards ran to 6.0 min).
- s323 retro: merge refused once.
- s322: carry-over Check 2 (entry without Status); requirements Check 29 (EARS BEFORE-clause), 17 (stale PRD report),
  1/J2 (record labels), 32 (false positive); architecture Check 24 J2 drift (stem moved after MET, a real unreviewed
  edit); stories Check 30 and 24 with an operator-authorized reopen; sprint review Check 3 (real).
- s321: no non-implementation FAIL in the records read.

Real catches in three sprints: s322 sprint-review Check 3 (LR-S322-9 never anchored), s322 architecture J2 drift, s323
Check 35 (a loss the lead's own trim caused), s322 Check 29 wording. Everything else is vocabulary, shape or linkage.
The advisor's second gate call at the s323 retro gate caught an invented value (`last_imminent_fire_turns` 81) and an
unverified merge claim, both slips of hand-writing the entry.

Adjudicator yield: 5 FAILs in about 190 non-implementation LLM-check verdicts (2.6%), plus about 14 script-arm and
repair events. Of the 5: 2 were validators that silently skipped (Check 2: an entry with no Status line; Check 3: the
validator printed PASS EXAMINED NOTHING on a story whose frontmatter declares an LR with no block), 1 a verdict-line
grammar (Check 1 "Tip:" prefix), 1 EARS wording (Check 29), 1 real (Check 3, LR-S322-9). 28 of the 40 checks a
non-implementation gate loads never failed in the 15 gates of s321-s323 (about 75 KB of the file); 12 failed: 1, 2, 2a,
3, 5, 15, 17, 24, 29, 30, 32 (a false positive waived for 3 gates) and 35.

#### Part table

Scope is the planning, story, sprint-review and retro gates. Class is from `enforcement-map.yaml`. "Fires" counts
non-implementation gate events s321-s323 plus repair records s319-s323. The planning, sprint-review and retro rows carry
the decided verdict: each check is a program arm unless listed as a judgment; the program is one per gate and one
adjudicator takes the judgment checks.

| Check (file:line, bytes) | Class | What it verifies | Fired | Who reads its output | Verdict |
|---|---|---|---|---|---|
| 1 (`gate-validation.md:222`, 4.7K) | llm | Review verdict-token grammar; party, AE and adversarial present | 1 (sprint review "Tip:" prefix) plus J2 drift | The gate row | SCRIPT (grammar is deterministic); script the verdict-line grammar before dispatch |
| 1c (:291, 2.0K) | llm | Research invoked | 0 of 8 | gate row | SCRIPT or CUT |
| 2 (:328, 8.1K) | llm + 2 validators | No open HARD_BLOCK; vocabulary | 4 events, all format; 2 missed by the script | gate row | SCRIPT after the validator fix |
| 2a (:443, 3.1K) | script | Operator citation | 1 (prose shape) | gate row | KEEP in program |
| 3 (:493, 1.6K) | llm | LR not weakened in the body | 1 real | gate row | KEEP as a judgment; 3b already byte-anchors |
| 3a (:522, 2.1K) | llm | Story validation origin | 0 of 3 | gate row | MERGE into 3 |
| 3b (:565, 3.1K) | script | LR full text | 0 of 3 | gate row | KEEP |
| 4 (:619, 0.5K) | llm | Placeholder grep | 0 of 15 | gate row | SCRIPT |
| 5 (:631, 7.0K) | llm + `sprint-status.sh` | Story status | 2 (draft vs backlog) | gate row | SCRIPT; fix the producer |
| 7 (:756, 0.8K) | llm | Files exist | 0 of 15 | gate row | SCRIPT |
| 8, 9 retro (:771, :790; 0.8K, 12.1K) | llm | Deploy and visual evidence | 0 of 2 | gate row | Covered in the deploy-validate and retro sections |
| 12 (:953, 11.1K) | lead | Write the gate-log entry | 1 slip class (advisor second call) | `gate-log.md`: Check 25 baseline, `sprint-status.sh`, Check 15, `validate-mandatory-rules.sh`; evidence rows read by the next lead as a template and by the advisor | SCRIPT (render) |
| 13 (:1123, 0.5K) | lead | Announce | 0 | none | SCRIPT |
| 14 (:1137, 16.4K) | lead | Snapshot update | s323 architecture trim lost 65 lines (35 caught) | resume digest, next gate | SCRIPT (`snapshot-update.sh` exists) |
| 15 (:1389, 3.1K) | lead | Verify snapshot | 1 (parser read 183,560 tokens) | | SCRIPT |
| 16 (:1452, 3.5K) | llm + `validate-stub-audit` | Stub audit | 0 of 15 | | SCRIPT |
| 17 (:1516, 13.6K) | script | Provenance block | 3 (requirements gate) | | KEEP script; fix the producer |
| 18 (:1718, 2.8K) | project | Test-debt anchors | 0 of 2 | | KEEP script |
| 20 (:1828, 3.2K) | llm | Intensity minimum met | 0 of 10 | | SCRIPT (table lookup) |
| 21 (:1882, 2.5K) | llm | Strategy ids resolve | 0 of 2; `validate-handoff-evidence --strategy` exists | | SCRIPT |
| 23, 25, 26, 28, 31, 33, 34, 36, 37 (various, 41K) | script | Stamps, steering, adoption, spec, scope, trunk, owed | 0 of 8-15 each | Check 25's baseline: no script reads `steering_violations` (grep of scripts and hooks returned 0; control `gate_nonce` 8 files) | KEEP as program arms; Check 25 reads its own baseline (compared by hand today, :2515) |
| 24 (:2316, 14.2K) | script | Adversarial cycle converged | 3 | | KEEP script |
| 27 (:2892, 3.8K) | llm | Routing sanity | 0 of 8 | | KEEP (judgment) |
| 29 (:2977, 3.7K) | llm | Spec kernel WHAT/HOW, EARS | 1 (s322 requirements) | | KEEP (judgment) |
| 30 (:3040, 12.7K) | script | LR-CAP-FR-story join | 4 sprints of 5 | | KEEP script; fix the producer |
| 32 (:3247, 1.8K) | script | BMAD invocations | 1 false positive (3 gates) | | FIX regex (`route.md:587` filename token) |
| 35 (:3441, 3.4K) | script | Snapshot content conserved | 1 real (65 lines, self-inflicted) | | KEEP |
| H1 (:2548, 4.9K) | lead | Anchors loaded | 0 | | CUT with the program (vacuous once a program runs the checks) |
| H2 (:2638, 3.9K) | script | Forgery fixture attestation | 0 of 15 | | KEEP once per sprint; each gate runs `--verify` only |
| core-layer (:2720, 7.0K) | llm | Diff classification | 0 of 2 | | KEEP (judgment) if the consumer edits core |
| failure and reset (:3618, 4.4K) | lead | Repair protocol | 5 of 15 gates | | KEEP, shrink |

Judgment checks kept for the one adjudicator: 3, 27, 29 and core-layer.

`_gate-procedures.md` sub-sections (the validation cycle :290 (34.7K), adversarial review dispatch :697 (16K),
divergence resolution :858 (15.8K) and adversarial repair dispatch :1072 (39.8K) belong to the planning steps and are
read in sections 6.2 to 6.5):

| Part (file:line, bytes) | Verdict |
|---|---|
| Sub-step snapshot update :16 (8.5K) | SHRINK to script help |
| Bounded-join beat :156 (6.5K) | KEEP (hook-backed) |
| Gate-adjudication dispatch :217 (6.2K) | KEEP; simplify to one dispatch of judgment checks only |
| Auto-handoff evaluation :1487 (13.9K), context reminder threshold :1730 (3.9K) | MOVE to the hook that already fires (`ai-dlc-context-sensor.sh`); the gate row only quotes it |

Advisor touchpoints at gates (`SKILL.md:1135-1136`; first call at gate entry, second before close; one after each
repair): 21 calls, 11.9 min foreground in s323 non-implementation gates; its catches were slips in hand-written entries
(an invented value, an unverified merge claim, stale numbers). With a rendered entry the first call has nothing to review
before the arms run, and the second reduces to the judgments.

Who reads what the step writes: `gate-log.md` entry prose (Check 25 baseline read by hand, `story_status` read by
`sprint-status.sh`, heading-block timestamp read by Check 15, header read by `validate-mandatory-rules.sh`); the
per-check evidence rows (the bulk) are read as a format template by the next lead and by the advisor, and the archive is
declared write-only (`gate-log-archive.md` is 396 KB for s323 alone). `gate-metrics.jsonl` is machine-read by
`validate-suppression-lifetime.sh`, `validate-snapshot-conservation.sh`, `validate-escalation-resolution.sh` and
`ai-dlc-gate-remediation-guard.sh`; a program can write it. The adjudication part and verdict files are read by
`validate-gate-adjudication.sh` (Check 26, the `--series` stall rung) and their evidence prose is copied into gate-log
rows. The `.gate-checkpoint` ledger is read by `gate-slice --done`, resume and the series rule. Repair records are parsed
by the Rule 28 guard on column-0 fields (the s322 sprint-review repair needed a re-format to lift a deny). The snapshot row
is read by the resume digest and the next gate.

#### Defects

- **DEFECT 1.** Validators report PASS or skip on an unexamined subject: `validate-escalation-status-vocabulary.sh` skips
  entries with no Status line (the s322 carry-over and s323 architecture FAILs were found only by the adjudicator) and
  `validate-locked-anchor.sh` prints PASS EXAMINED NOTHING (story 1-8, s322 sprint-review Check 3). Fix the validators; the
  LLM check then has nothing left to catch.
- **DEFECT 2.** Producers write shapes the gate rejects. Check 30 failed at the story gate in s319, s320, s322 and s323 (4
  of 5 sprints; 11 CAP-to-AD lines and 11 LR-to-CAP entries in s323); Check 2 vocabulary in s322 and s323 (3 events);
  Check 24 chain (s322 architecture, s322 stories, s323 stories); Check 17 PRD validate report without a provenance
  block at the requirements gate in s320, s322 and s323; Check 5 draft to backlog in s320 and s323 (18 stories, "per the
  s315 precedent"). Fix at the authoring step and run the validator as the step's last action.
- **DEFECT 3.** Graph's `gate-validation-domain.md` (73 KB) is read 53 times (1.0 MB) a sprint at non-implementation
  gates to write rows that read NA or SKIPPED: 11 of its 17 checks (919b, 920, 922-924, 926-928, 930-932) were NA in 14
  of 15 non-implementation gates and never PASS.
- **DEFECT 4.** Check 32 false positive (`route.md:587` filename token) cost an operator-authorized 3-gate suppression in
  s322.
- **NOTE 1.** Shard width varies for the same escalated set: 10 shards (s322 planning), 3 (s323 planning), 8 (stories,
  0.6 to 1.3 min each), 4 (sprint review), 3 to 9 (retro). Wall clock is the slowest shard (1.5 to 8.5 min).
- **NOTE 2.** The adjudicator re-runs the validators the lead already ran; its evidence cells quote the same validator
  output.
- **NOTE 3.** H1 (manifest completeness) becomes vacuous once a program runs the checks.

#### Redesigned shape

The gate procedure does not exist in its present shape. Each gate runs as a program.

1. **One program per gate.** `gate-run.sh --type <planning|story|sprint-review|retro> --sprint N`, generalising
   `gate-transition.sh` (which already runs Checks 2, 2a, 5, 16, 17, 22, 25 and H2 in order, mints the nonce and runs
   `open` for implementation gate 3). It runs, from the manifest (`gate-slice.sh` already derives the set), every script
   check and the script arm of every LLM check with an enforcer, with the control each row needs, then prints one line per
   check (`[core] N PASS|FAIL|NA <evidence>`). It writes the ledger rows, the GATE_METRIC rows (it knows `tok_slice` from
   the file spans), the gate-log table body and the Check 14 snapshot call; Check 25 reads its own baseline. A non-zero
   exit lists every failing check at once, so the lead repairs once.
2. **One adjudicator** dispatched once, after the arms pass, for the checks no program decides: 3, 27, 29 and the
   core-layer check. One shard, about 3 min. Checks 1, 4, 7, 16, 20, 21, 1c, 3a and 8 become program arms (grammar,
   grep, existence, table lookup).
3. **The lead's gate text** shrinks to: run the program; on FAIL read Gate Failure (:3618, 3.4 KB) and Gate Reset;
   dispatch the judgment adjudicator (the :217 procedure, 6 KB); write only the prose fields a program cannot
   (Remediations, disclosures); close. The lead reads about 20 KB a gate against 100 to 290 KB today.
   `gate-validation.md` keeps the check prose only as the specification the program implements and as the adjudicator's
   brief, never as a file the lead loads. The earlier plan to split the file into sections is replaced by this.
4. **gate_types on consumer extension checks** (the Rule 27 `gate_types:` mechanism already exists), so graph's 73 KB
   domain file is not loaded at gates where its checks are NA.
5. **Validators move to the producing step's last action**: spec-join at architecture end, convergence and chain at the
   step's final repair, status draft to backlog in the story-authoring checklist, the provenance block at PRD validate.
   The gate then sees PASS the first time (evidence: Check 30 failed at the story gate in 4 of 5 sprints, Check 2
   vocabulary 3 events, Check 24 3, Check 17 3, Check 5 2).
6. **Advisor.** The first gate call is dropped (nothing to review before one command); the second, before close, is kept
   for the judgments only.

Build conditions, binding for every scripted arm (and the same conditions bind the rule-table checks proposed for
implementation gate 3 in section 6.7):

1. Fix the two validators that pass on an unexamined subject (`validate-escalation-status-vocabulary.sh`;
   `validate-locked-anchor.sh`) before any arm that depends on them. Checks 1, 4, 7 and 20 have no enforcer in
   `enforcement-map.yaml` today, so their arms are new code.
2. Prove each scripted arm against a seeded failure and a near-miss.
3. Diff the program's output against s323's hand-written gate entries.

Smallest version that keeps every catch: the s322 sprint-review Check 3 and Check 2 catches become validator fixes;
Check 29 stays a judgment; Check 35 and J2 drift stay scripts. The count of real catches is unchanged.

Engine files that change: `core/scripts/gate-transition.sh` (extend or a sibling), `core/scripts/gate-slice.sh`,
`gate-validation.md` :161-221 (checklist preamble), :953-1136 (Checks 12-13), :1137-1451 (Checks 14-15), :2548-2705
(H1, H2), the `adjudication` column of `enforcement-map.yaml` for Checks 1, 1c, 3a, 4, 7, 16, 20 and 21,
`validate-escalation-status-vocabulary.sh`, `validate-locked-anchor.sh`, `validate-bmad-invocations.sh` (Check 32
regex) and `core/scripts/validate-steering-budget.sh` (read the baseline).

#### Upper bound on saving

All figures are UPPER BOUNDS on s323 as the basis; the 8 to 10 min a gate floor is an estimate, not measured. They come
from the clean-gate windows (19 to 32 min) minus the parts a program removes. Gates sit between steps, so the lead time
is on the serial path and is wall clock.

| Item | Saving (upper bound) |
|---|---|
| Lead active | 300 min to about 60 min: up to 4.0 h (s322 base 183 min gives up to 2.1 h) |
| Lead calls | 1,440 to about 300 |
| Cache-read tokens | about 230M to about 50M, up to 180M; roughly $50 to $70 token-equivalent at sonnet-class list prices (price basis not re-run) |
| Gate-file reads | 4.3 MB to about 0.4 MB |
| Compactions | up to 26 of 134 (those inside non-implementation gate windows); the avoided re-read after each is 35 plus 18 min of the 300 |
| Adjudicator spend | $26 to about $8 (one shard per gate); agent-min 112 to about 25 |
| Serial remediators in the story gate (23 agent-min, $4.3, 42 min wall before dispatch) | up to about 0.7 h in s323 if DEFECT 2 is fixed at the producers |

Overlap: the lead-active, call, token and compaction rows are one saving read in four units, not four savings. The
compaction row overlaps the lead's own-time lever in section 7 and the lever that ships the gate procedure under
the read limit (the file the lead reads in sixteen chunks). The remediator row overlaps the validators-at-the-producing-step move.
What could be lost: the per-row evidence prose (read only by the next lead and the advisor), and a check whose grammar
the program gets wrong, which is why the build conditions above are ordered.

#### Not measured

Available and not done:

- Adversarial rounds dispatched inside a gate window (s323 stories: 9 adversary spawns, 41 min, $15.4) and
  implementation gate-3 work under the sprint-review label inflate the stories and sprint-review rows; they were not
  split.
- s321 carry-over and retro gates carry no gate-validation label.
- The H1 row of the s323 sprint-review entry says 71,628 B loaded while `gate-slice` plans 101,515 B for that type; which
  reads the lead skipped is not known.
- The 14 pass-2 MAJOR findings and the value of adversarial pass series are the planning steps' (sections 6.2 to 6.5);
  only their spawn cost is measured here: s323 spent $319 (1,027 agent-min) on 149 adversary spawns, of which the
  non-stories pass-2 and pass-3 passes were 31 spawns, $67.6; repair introduces the next pass's MAJORs (s318 pass 1 17
  of 29, pass 2 11 of 19; s322 stories pass 2 1 of 3).
- The 135 `gate-validation[pre-step]` adjudicator transcripts (5.1 agent-h in s323) are implementation gate-3 shards and
  were not read here.
- Generation against queueing on the local model.

Not available: s322 pass-1 adjudication files for carry-over and requirements are rotated away, so those two FAILs come
from the gate-log narrative. No timing run was taken.

### 6.9 Sprint review

Files: `core/skills/ai-dlc/steps/sprint-review.md` (186 lines, 10,167 B, 1 code block; graph's installed copy is 10,057 B and differs only by the read-and-follow chunk-size clause at line 186) and `core/skills/ai-dlc/steps/sprint-review-next.md` (76 lines, 3,705 B). The step delegates to `_gate-procedures.md` (1,821 lines, 148 KB) and `gate-validation.md` (3,703 lines, 247 KB). About 70 lines of the step are procedure a program already carries or could carry (Step 0, the joins at L56-60 and L103-109, the validator at L170-177, the gate call); about 60 lines are judgment (L63-80, L110-115, L132-166); the rest is rule prose. Source: `findings/step-review.md`.

Step files: `sprint-review.md`, `sprint-review-next.md`

#### Cost

Step plus its gate (`B_tables.txt`, hours on the monotone clock, in-session time only):

| | s321 | s322 | s323 |
|---|--:|--:|--:|
| Elapsed h (corrected) | 2.9 | 2.0 | 9.9 |
| Lead own (model + tool) | 0.8 | 0.8 | 2.5 |
| Idle, no agent running | 0.3 | 0.1 | 0.3 |
| Lead waiting on running agents (under 300 s) | 1.7 | 0.6 | 1.9 |
| Operator wait | 0.1 | 0.0 | 4.2 |
| Long agent wait | 0.0 | 0.6 | 1.0 |
| Spawns | 169 | 65 | 167 |
| Subagent $ at one-hour cache-write rate (five-minute rate) | 209.1 (176.8) | 82.1 (68.8) | 214.7 (178.5) |
| Lead calls | 396 | 387 | 958 |
| Compactions | 3 | 3 | 11 |

The step-plus-lead-seat figure that `roll.py` prints, $235.63 / $100.76 / $279.74, is subagents ($209.09 / $82.08 / $225.54) plus the lead seat at token-equivalent price ($26.54 / $18.68 / $54.21); a $3.02 lead share read elsewhere does not reproduce under any pricing tried (`findings/reconcile.md`, A4). Gate 3 of stories 2.1 to 2.3 (1.03 h) is counted in implementation, not here. Compactions inside the step's own windows in s323: 3 in the first lead session and 8 in the second; compaction recovery plus step re-read took 20 minutes in s323 against 1.6 (s321) and 3.4 (s322), and the gate span holds 50 step and gate file reads in 51 minutes.

s323's wall by the step's own parts, excluding the 195-minute operator wait and the 179 minutes stories 2.1 to 2.3 took to build: 361 minutes (6.0 h). Of it, 57 minutes was the lead blocked inside an `AskUserQuestion` with both Step-3 reviewers already finished; 19 minutes was a rate-limit failure of the party round; 53 minutes was a story-branch integration repair that no engine file owns; 85 minutes was a third adversary pass and its fix loop. Parts for s321 and s322 (wall min / lead-active min / $): s321 adversary plus golden fix 30 / 30 / $6.19, party plus triage 33 / 33 / $163.56, post-party fixes plus reviews 84 / 84 / $36.57, gate 30 / 30 / $2.78; s322 adversary plus fix 16 / 9 / $3.13, party plus triage 31 / 23 / $66.59, post-party 48 / 28 / $7.22, gate 42 / 42 / $5.13.

#### Part table

s323 timings are UTC 2026-11-19; lead-active uses event gaps of 300 s or less; spawn spans include resume gaps and overstate Step-3 rows (QA span 60.5 min against 4 active).

| Part (file:line) | What it is for | Cost (s323) | Produces; who reads it | Caught | Verdict |
|---|---|---|---|---|---|
| Intro `sprint-review.md:15-16` | Run all sub-skills back to back without pausing for human input | The lead paused twice in s323 (DEFECT 2) | Rule prose | n/a | KEEP; remove the ask affordance inside the step |
| Pre-staging rule `:18-29` | Sprint-Overall PR pre-staging rule | Prose, no action here | Only reader is `deploy-validate.md:35`, by lead prose check | None on record | MOVE to `deploy-validate.md:35`; frees 12 lines here |
| Step 0 freshness `:31-52` | `git fetch` plus `rev-list` count | 1 call, count 0, $0 | The lead | None on record | KEEP as one line of the integration script |
| Integration of story branches into the sprint branch (in no step file) | Make the sprint branch contain every done story | Part B: 53 min wall, 53 lead-active, 6 spawns, $10.03 | Merge resolution twice, suites, a story 1.4 bootstrap fix; no reader | SA-1 (stories 1.2, 1.3, 1.4, 3.2, 5.2 never merged), lost story-4.1 gate-log entry, duplicate Dev Agent Records in 9 of 18 story files, new tests in no CI lane | SCRIPT, at implementation close and at Step 0 |
| Step 1 adversary `:54-86` | One composed-tree adversary pass; operator-request re-read at `:72-76`; Seam D at `:82-86` | Pass 1: 12 min, 1 spawn, $4.74 | `sprint-adversarial` file; gate Check 1, the lead, repair seats | SA-1 Critical; SA-2 Important; SA-3 APP_ENV; SA-4; SA-5. Pass 2: MAJOR that operator item 2 was not delivered by the composed diff and stories 2.1 to 2.3 were "operator-held" with no quote | KEEP once per composed tree. Pass 2 (repair verification, $8.06) is SCRIPT; pass 3 was legitimate (stories 2.1 to 2.3 added code) |
| Operator ask inside the step | Scope decision on stories 2.1 to 2.3 | 195 min wait plus 9 min handoff | Answer "Build all three now" | A real scope decision | KEEP only for scope |
| Step 2 party round `:88-122` | Five roles (PM, Architect, Dev, TEA, QA), one agent per (seat, story) plus one cross agent per seat, seat-complete lines, count join `:100-109` | 41 min wall, 40 lead-active, 2 dispatchers plus 130 seat spawns, $141.56 | 95 seat files; read by the lead (`## F-` headings), repair seats, the 13 carry-over items (each cites its seat); Check 20 reads only the count | 26 major and 95 minor headings = 13 distinct defects; 10 changed a shipped artifact (5 code/test/CI, 5 record/runbook), 3 ended as operator decisions | KEEP the panel; SHRINK the dispatch: retry errored seats by script |
| Round briefs (95 plus dispatcher, commit `893c0c128`) | Brief each seat | Typed by the lead | Read once by the seats | n/a | Rendered by the brief generator (cross-cutting lever) |
| Disposition and fix seats | Triage 165 findings, dispatch three fix seats | 18 min wall, 17 lead-active, 4 spawns, $5.54; the triage itself took 6 min | 13 carry-over items; 3 live instruments | Lead restored the lost gate-log entry | KEEP |
| Step 3 fix and re-validate `:124-166` | Dev fixes, code re-review, QA, repeat | 63 min wall of which 57 operator-bound, 3 spawns, $8.11; QA re-validation over three runs about $2.45 | Re-review files; the gate | Both fix batches came back NEEDS_REWORK with repair-introduced defects, one Critical (a new 5.1 AC8 live test that could never pass); QA 0 defects | KEEP the re-review; dispatch QA after the reviewer approves or on the same tip (QA ran on a stale tree and was re-run, $1.28, 8 min) |
| Seam rules `:132-157`, un-exercised branch `:159-166` | Core-path seam non-deferral | n/a | Rule prose | No evidence the non-deferral rule fired in s323; defect #4 has exactly its shape and the party found it | KEEP; NOTE |
| Step 4 validator `:168-177`, Seam B `:179-181` | `validate-handoff-evidence.sh --strategy HEAD` | A script | The gate | 11 stale test-id cells in s323 (commit `ab599a998` rebinding ST323-27..35 and 53/54) | KEEP (already a script) |
| Gate `[sprint-review]` `:181-184` | `gate-validation.md` checks; Check 20 reads Steps 1 and 2 as the minimum | 51 min wall and lead-active, 9 spawns, $5.62 including remediator; the 4 shards ran twice | Gate log | First-round FAIL was verdict-line grammar and a sibling-file open MAJOR, both the lead's own artifacts; s322 also needed a second round; Check 14 snapshot trim 12 min after PASS | SCRIPT the lexical part (Check 1 grammar at `gate-validation.md:230-286`) before any adjudicator dispatch |
| `sprint-review-next.md` (entered from `deploy-validate.md:750` and `route.md:519`) | Validate the next sprint's stories | 0 Reads of the file and 0 loaded-token hits in all 176 lead transcripts of graph (control: 87 Reads of `sprint-review.md`); no spawn or step label in s317 to s323 | None | None | CUT. Measured on graph only |

#### Catches that earn the kept parts

- Party round, s323: 13 distinct major defects, 10 of which changed a shipped artifact, survival checked at squash `eabdc576e` by token presence, not line share. Examples: the story-4.1 gate-log entry dropped by an implementation merge (fixed by lead restore `a60719349`); deferred ACs whose blocker cleared at integration and that no story tested (three live instruments written; 3 tokens present at the squash, control token present, absent token 0); a layer byte pin re-baselined beyond the one authorised (introduced by the step's own Step-1 fix commits; the fix review checked only the hash); new tests in no CI lane; a refusal row carrying no reason. Only defect 3 (APP_ENV armed) was found earlier by another part (sprint adversary SA-3 at 02:53); defects 12 and 4's deferral history are unverified for earlier hits, since not every hit file was read.
- Sole raiser at major by role, s323: tea 7, architect 1, pm 0, dev 0, qa 0. Over three sprints (s321 / s322 / s323; `findings/value-open-items.md`, item 3): architect 3 / 1 / 0, dev 1 / 0 / 0, pm 0 / 3 / 0, qa 1 / 3 / 0, tea 7 / 7 / 7. A cross-only test loses a sole defect for every role: dev loses D10 (s321, low), pm loses T-12 (s322, medium), qa loses 4, architect loses 3 (D2 and D4 on a capital path and the live config path, both rated high, and T-7), tea loses 6 of 7 in s321 and all 7 in s323. D8 (high: the Base-probe exception that blinded live-Matic monitoring) was raised by dev and qa seats only. No role can go cross-only without loss across the three sprints, so the panel is kept whole. Role cost of the successful s323 seats: architect $38.38, tea $38.95, qa $17.36, dev $15.28, pm $10.65.
- Fix re-reviews: both s323 fix batches carried repair-introduced defects caught by re-review; the strongest catch in the step.
- Adversary pass 1: SA-1, a Critical.
- Cost per distinct fixed defect: seats plus dispatcher $141.56 / 10 = $14.16.

#### Defects found

- DEFECT 1: story-to-sprint integration has no owner. Grep of `core/` and graph's installed engine for the commit subject the lead wrote ("Merge story X into s323 sprint branch (all three gates passed...)") returns 0 (control: `wait-for-deliverable` returns 125 files); `implementation.md` has no merge-into-sprint-branch procedure. Three integration-class defects in s323 and D22 in s321, none produced by a gate. 53 min and $10.03 inside the step; one defect was a Critical. The unregistered-test class recurred in 2 of 3 sprints (s321 D6, s323 #8); no engine text enforces it.
- DEFECT 2: a blocking `AskUserQuestion` inside a step that says "without pausing for human input" (`sprint-review.md:15-16`). The 18:23 ask was answered 19:11 and 19:21; both Step-3 reviewers had returned by 18:24 and 18:32; fix and pass 2 took 13 minutes after the answer. No HARD_BLOCK entry for the byte-pin or APP_ENV items exists in `docs/escalations/pending.md` at the branch tip, and the lead had written at 18:11 that both were staged for deploy-validate. Upper bound 48 min wall, $0, one sprint of three.
- DEFECT 3: no retry for rate-limit-errored seat spawns. 34 seat spawns and 2 dispatchers errored; 32 seats' work was lost: $22.49 and 19 minutes (17:23 start, 17:42 re-dispatch), and the lead re-dispatched by hand. The engine is silent on rate-limit failures (`_gate-procedures.md:471-473` sizes waves only against the concurrent-subagent cap). s321 and s322 had 0 such spawns (control s323: 36). Whether other sessions on the account contributed is not measured, so the finding is "no retry", not "the fan-out caused it". dev-1 and dev-4 completed and marked their files before their spawns errored and were correctly not redone.
- DEFECT 4: the step text says one-shot (`:66-68`) but three adversary passes ran, the join re-dispatched by hand each time. $13.31 and 33 agent-min for passes 2 and 3 ($8.06 + $5.25).
- NOTE: Check 20 counts seats and never reads findings; presence is not empty, since all 99 successful seat spawns wrote a seat-complete line carrying sha and findings count.
- NOTE: spawn spans in `spawns.jsonl` include resume gaps; agent-hour figures built on span overstate the Step-3 rows.
- NOTE: found efficient: Step 0 (one call), `validate-handoff-evidence.sh` (a script that caught 11 stale cells), the seat join by seat-complete count (99 of 99), the lead's post-party disposition.

#### Redesigned shape

1. An integration script, no model call, run at implementation close and re-run at Step 0: every done story tip is an ancestor of the sprint branch (SA-1); every line a story branch appended to an append-only log is present at the tip (the lost entry); exactly one Dev Agent Record per story; every new test file is named in `ci-local`; Check 21 cells. It moves part B (53 min, $10.03) out of the step, lets pass 1 start on a correct tree, and replaces pass 2 because "was the repair landed" becomes a script verdict. Changes: a new `core/scripts` file, a closing step in `implementation.md`, `sprint-review.md:31`.
2. One adversary pass on the composed tree, with the operator-request re-read at `:72-76`; a repair is verified by the script, not by a second pass.
3. The party panel unchanged. Seats are dispatched by a script that retries any seat whose spawn errored and never counts an errored spawn as joined; the lead's join stays the count of seat-complete lines.
4. One fix batch per round: dev fixes, then code re-review, then QA on the reviewer-approved tip.
5. Operator decisions raised in the step go to `docs/escalations/pending.md` and the deploy-validate checkpoint's "Decisions for You" section; `AskUserQuestion` is not offered inside the step. The one exception is scope.
6. The gate's verdict-line and sibling-file checks run as a script before any adjudicator is dispatched, and shards run once.
7. The pre-staging rule moves to `deploy-validate.md:35`; `sprint-review-next.md` is deleted together with its entry points at `deploy-validate.md:750` and `route.md:519`.

A larger shape the reader names: split the step by who the findings are for. Integration defects belong to implementation's close, so the panel reads a tree with no mechanical defects and its majors are the semantic ones, which is what five role lenses are for. Reducing per-story pm, dev and qa seats to cross-only is not supported by the three-sprint sole-raiser table and is a scope decision.

#### Upper-bound saving

UPPER BOUNDS, one sprint each (s323): 48 min (ask) + 19 min (rate limit) + about 38 min (adversary pass 2 and its fix) + 16 min (second gate round) = about 120 min of the 361; dollars $22.49 + $8.06 + $2.78 + $1.28 = $34.6 of $225.5 (the reader's pre-correction step basis). The panel's $141.56 is not reduced; nothing supports reducing it. Overlap: the integration script and the adversary pass-2 saving are one saving; the gate script, the retry and the ask removal are disjoint from each other. Part B's $10.03 and 53 minutes move to implementation close and are not a net saving until the script's cost is counted. The Check 14 snapshot trim after PASS (12 min) belongs to the cross-cutting snapshot item.

#### Not measured

- The 1.2 h difference between the monotone clock (11.12 h for step plus gate before correction) and first-to-last transcript timestamps (12.35 h across the two lead sessions) is not attributed. The 07:54 to 12:45 handoff gap is excluded by scope.
- Whether other sessions on the account shared the rate limit during 17:23 to 17:38. Not measured; the account-level data was not read.
- Earlier-raise search: token greps at the party-input tip for #3, #5, #8, #12 only. The disposition of #6 (a veto candidate left to the operator) and the operator's answer to the seven-veto-line question (truncated in the transcript) were not read.
- The sole-raiser table for s321 and s322 comes from the committed analysis and a re-derivation of s322 only; s321 fix commits were not re-read; s322 T-19 and T-24 fix evidence was not found. Available, not done. Seat-level wall clock was not measured (seats run in waves, so removing a role's seats frees dollars, not clock, unless the wave count falls).
- s320's 70 seat files are labelled outside the sprint-review label in `spawns.jsonl` (6 spawns under the label), so any s320 row of a per-sprint table is wrong; not chased.
- `sprint-review-next.md` was measured on graph transcripts only; other consumers were not checked.
- The pre-flight cost of the proposed scripts. No timing run was taken.

### 6.10 Deploy-validate

File: `core/skills/ai-dlc/steps/deploy-validate.md`, 46,451 B, 770 lines, 5 code blocks (4.9 KB), 8 "Minimum mechanism" rationale paragraphs (4.7 KB), 5 HTML placeholder comments (1.4 KB). Graph runs an older copy of the file (it lacks `git add -f` in the merge record, lacks the "Plain language in the checkpoint" paragraph, and has a shorter read-and-follow cap text) and layers two extensions on the step: `deploy-validate-domain.md` (32,140 B) and `deploy-validate-push.md` (14,750 B), about 93 KB of step text in all. About 18 KB is judgment (smoke triage 3.4 KB, the 3b and 4b predicates 2 KB, 2a, routing); about 28 KB (merge record, 2b, smoke field record, PVC skeleton, coverage, cluster, routing) is procedure a script can carry or render. Sources: `findings/step-deploy.md`, `findings/value-open-items.md` (items 1 and 2).

Step files: `deploy-validate.md`

#### Cost

(`B_tables.txt`, hours on the monotone clock, in-session time only)

| | s321 | s322 | s323 |
|---|--:|--:|--:|
| Elapsed h (corrected) | 28.0 | 3.7 | 5.5 |
| Lead own (model + tool) | 2.3 | 1.1 | 2.4 |
| Idle, no agent running | 1.7 | 0.5 | 0.8 |
| Lead waiting on running agents (under 300 s) | 3.4 | 0.2 | 0.6 |
| Operator wait | 18.1 | 1.9 | 1.2 |
| Long agent wait | 2.5 | 0.1 | 0.4 |
| Spawns | 45 | 3 | 14 |
| Subagent $ at one-hour cache-write rate (five-minute rate) | 100.2 (84.2) | 5.2 (4.3) | 20.4 (16.5) |
| Lead calls | 978 | 652 | 1,208 |
| Compactions | 7 | 4 | 9 |

The class rows are rounded and need not sum to the elapsed row. s321's 29.0 h before correction counted a 57-minute window twice: 183 of 183 records of session 4f12d1d9 between 11-08T15:25 and 16:20 carry the same uuids in the forked session df56108b; the record-level span is 28.05 h. Across s317 to s323 the step takes 4.5 to 10.5 h except s321. s321 is the effect of one event, a new chain (Base) going live under deploy-validate: 17.7 of its hours are 17 operator asks (1,062 minutes of ask waits), of which 5.0 h are seven push or merge go-aheads for a fix PR and the single 10.7 h ask was an overnight wait on a live security-config write that the consumer owns. Reconstruction of s321 by part: lead active 7.7 h, operator gap 17.8 h, agent gap 2.5 h; about 19 h are consumer-only (the Base chain going live, operator-owned values, live PUT security approvals, overnight absence, UI saves) and the engine-shaped part is the re-ask class (5.0 h, partly a consumer rule), 2.5 h of agent waits and 7.7 h of lead activity (902e, 3b and step 4 ran twice in s321, at 15:13 to 15:26 and 23:30 to 00:20).

s323 reads of the step file: 17 chunked Reads (227 K characters), 9 compactions; s322 14, s321 13. The extractor's s323 classes: step re-read 23 calls and 2.4 min, compaction recovery 14 calls and 4.0 min; about 57 K tokens a sprint in context.

#### Part table

| Part (file:line) | What it is for | Cost (s323 unless stated) | Produces; who reads it | Caught | Verdict |
|---|---|---|---|---|---|
| 1. Pre-check `:17-33` | `check-stories --require-done` | rc 0, 18 stories; already a script | Exit code; the lead | None on record | KEEP |
| 1b. Pre-staging audit `:35-44` | Audit that the sprint PR was assembled incrementally | About 2 min; a prose audit of git history ("205 commits", gate-log line 1721) | Gate-log sentence; no later reader | None seen in s323; s321 and s322 not checked | SCRIPT (one git count) |
| 2. Deploy and merge `:46-66` | Operator go-ahead (consumer rule), merge, `ecs-deploy.sh`; pre-roll idle, lock reads and post-roll reads | Part B: 54 min wall; 5 spawns, 29 agent-min, $7.42; lead's "merge" class 301 calls, 33 min | Reads: the lead, then the gate log | None in s323 (all PASS); s321 reads found the 902e and Base empty-ranges | KEEP the reads; SHRINK to scripts |
| 2r. Merge record block `:67-96` | Write `sprint-pr-merge.txt` | Three commit attempts in 70 s (20:46 to 20:47); a recorded deviation: graph's stale copy lacks `-f` and `.gitignore:29` (`*.txt`) blocked the add | `retro.md:49` and `:140` (mechanical) | None | SCRIPT `deploy-record-merge.sh <N> <pr> <head> <squash>`; frees about 1 to 2 min, removes a retyped 26-line block and a defect class |
| 3. 2a destructive one-time op `:98-141` (2.5 KB) | Stage by agent, fire by operator, authorization per action (`:107-109`) | Self-skips; no 2a row seen in s321 to s323 gate logs (not exhaustively checked); about 6 reads a sprint, about 4 K tokens | The operator | None seen | MOVE to an extension read only when staged |
| 4. 2b freshness `:143-185` (2.5 KB) | Image digest equality | PASS on 3 services via ops reads (4.8, 2.8, 4.3 min; $3.36 with the AC reads) | Gate log | None in s321 to s323; never failed (a premature rollout read `DEPLOY_RC=1` was the deploy script's own check); graph's extension 2b/2c duplicates it | SCRIPT (`aws ecs describe-tasks` imageDigest against the pushed digest, one call) |
| 5. 3 smoke `:187-358` (10.2 KB, 22% of the file) | Run, capture, four-field record, one live mutation per run, red-triage loop | 12 min wall (part D); second pair after fix #1338: smoke #1 had 3 first-run failures (gated-pair trio, expected), #2 PASS | Four fields read by gate Check 8 through a retro gate-adjudicator (gate-log line 1871: "all four smoke fields present") | s321: red nav tests (#1304) found only by smoke | KEEP smoke; SCRIPT the record (junit gives first-run, retry and persistent counts; a wrapper writes the four lines); SHRINK `:273-304` (prior-escalation release rule, about 2.1 KB prose for a path with no instance in s321 to s323) into `escalations.md` |
| 6. 3b function verification `:359-413` (3 KB) | Config-gated-flag read and post-activation live-log check | Quiet-window PASS (zero attempts in about a 1 h window; gate-log line 1790) | Gate log | The post-activation read caught the s323 mTLS defect; the zero-activity PASS cannot read RED when cadence is hours-scale | KEEP the post-activation read; SHRINK the zero-activity PASS to require an injected or controlled event (`:379-380`) |
| 7. 4 visual `:415-444` | Human confirmation of UI changes | Part E: one `AskUserQuestion` for four UI changes, 15.1 min wait, answer "All four look right (Recommended)"; the same operator found the dual-allowlist UI mistake later, in the PUT validation, at 21:59 | Gate Check 9 (adjudicator) | None by this part in s321 to s323; smoke (playwright, 20 gate ids PASS in one junit) already covers the surfaces | MERGE into smoke (playwright with trace); frees up to 15 min wall a sprint |
| 8. 4b deferred-AC discharge `:446-503` (3.6 KB) | Run predicates for deferred ACs | Part F: 28 deferred ACs, 19 discharged, 9 re-deferred; 33 min active; 2 ops reads; $2.1 | `sprint-status.sh` close (exit 3 while ids remain, `scripts/sprint-status.sh:138-140`); carry-over evaluation | The story-4.3 predicates forced the APP_ENV=prod fire; the post-fire read showed a header-less 401 and a cert-bearing 401 `mtls_required` on both rebalancers (gate-log 1839-1842): the ALB listener is in VERIFY mode and the gate read the wrong header. Operator Collect Rewards would have returned 401. Fixed in PR #1338 (4 commits, review PASS-with-conditions), re-roll, smoke #2 PASS. High consequence, not caught by gates 1 to 3 or smoke #1 | KEEP; SCRIPT the `git grep` per literal at the deployed sha (`:497-500`) |
| 9. 5 PVC `:504-716` (12.4 KB, 27%) | The operator-facing PR Validation Checkpoint | Part G: 50 min wall (lead active 43); 58 LR lines; an advisor challenge on LR-S323-5 was recorded and rebutted (gate-log 1831) | The operator; `retro` 4a | n/a | SCRIPT the rendering (Locked-Requirement Coverage `:617-683`, 6.9 KB; fix-forward cluster `:588-615`; escalation counts from `locked-requirements.md`, git log and `pending.md`); the model writes only "What Was Built" and "Decisions for You" |
| 10. 6 wait `:717-731` | Mandated stop for the operator | s322 0.75 h, s323 0.86 h operator wait in total (PVC replies, visual, fire precondition) | The operator's decisions were real: option B on the 4b deferral set, authorize agent fire, accept post-fire reads, approve #1338 | n/a | KEEP |
| 11. 7 routing `:732-770` | Two `snapshot-update.sh --set` calls and read retro | About 1 min | Snapshot | n/a | SCRIPT |
| Ops spawns (cross-cutting the step) | Read-only probes (pre-roll idle read, lock read, API read, post-roll reads) | 12 ops spawns, 45 agent-min, $13.59; the lead then re-read 14 ops outputs | The lead | The post-fire proxy and AC3 ground-truth reads need judgment | SCRIPT what the lead already scripts; keep judgment reads |
| Advisor consults (Rule 32 touchpoint I) | Consult before an irreversible action | 36 consults, 875 s (14.6 min foreground), for about 31 irreversible actions (22 push invocations, 2 merges, 5 or more deploys) | The lead | Freshness-window rule, `--require-approval never` justification, the LR-S323-5 challenge | KEEP; touchpoint I is counted in assistant messages (window 10) and the s323 lead makes 3.6 calls a minute, so a consult covers about 3 minutes |

#### Catches that earn the kept parts

- s321: fix-forward PRs #1305, #1306 and #1307 (first save refused; a non-refunding router on a capital path; zero gas). The HARD_BLOCK asks decided: "do-now: refunding router via dev PR" created #1306 (the capital-path catch); "enable in the same PUT"; "I press create myself" led to the live create that exposed #1307. Three of four s321 step-unique catches survive at $33.39 per survivor (`docs/analysis/step-value-sprint-review-deploy-validate-s321.md`).
- s323: the mTLS verify-mode defect found by the post-fire reads (PR #1338), one capital or auth-path catch at $20.43 for the step. The same step's s321 smoke run found red navigation tests only through smoke.
- Parts with no catch on record in s321 to s323: Step 1 pre-staging audit, 2b digest check (PASS three times in s323, never failed), the 3b quiet-window PASS, the 4 visual human confirm.
- Efficient as it stands: the smoke wrapper (6 calls), the 4b predicate runs, the `sprint-status` close gate.

#### Operator touchpoints and who mandates them

Of 17 s321 asks (34 questions), core text mandates only: the PVC and wait (parts 5 and 6), HARD_BLOCK dispositions (Rule 13 through part 3 item 6 and the locked-requirement block at `:658-667`), and the 2a destructive-op firing (`:107-109`). Graph's own text (its `CLAUDE.md` Rule 916, `docs/operator-runbooks/deploy-protocol.md`, extension `deploy-validate-push.md`) mandates the sprint-PR approval, every cdk fire, live config PUTs and the deploy key; all were answered with the recommended or first option. Go-ahead asks over s317 to s323: 16 sprint-PR and fix-PR push or merge asks, 586 minutes, the operator took the default in 16 of 16; none is required by engine text, and no line in the engine, graph's `CLAUDE.md`, runbooks or extensions mandates the fix-forward push asks (the seven s321 asks came from the lead's own reading of Rule (b)/(h); the nearest text, `deploy-protocol.md:115-119` Rule (h), says a fix PR is opened and the checkpoint runs again, not that the push is asked). The sprint-PR merge approval is graph's seam and stays (`findings/value-open-items.md`, item 1).

#### Defects found

- DEFECT 1: fix-forward PRs are gated by a hook that does not test them. Both the graph hook and the engine hook run `cd "$(git rev-parse --show-toplevel)"` on line 41, so they test the worktree the push runs from. The two s321 fix pushes ran with cwd the main checkout, which held the sprint branch (a 2,684-file diff against the 13-file fix branch), and the lead's own asks say the hook "tests the main checkout, not the branch tip". It turned an approval already given at 18:48 (1.6 min) into a second ask of 263.7 min (4.4 h). Seven push or merge asks in s321 are 297 min (5.0 h), all answered with the recommended or first option; s322 and s323 had 1 and 2 such asks (small). No engine or graph text says to push fix-forward branches from a worktree at the tip (0 hits over `core/skills`, `core/rules`, `core/team-roles`, graph's `CLAUDE.md` and the deploy-validate extensions). The hook itself is not at fault. Confidence high on the cost, medium on removability (part is a consumer rule). Upper bound 5.0 h of s321 operator wait. Not derivable: what the hook printed for those two pushes, and whether s321's worktree list differed from today's.
- DEFECT 2: the PVC is hand-composed and unreadable to the operator, twice: s322 ("why not state that in plain english", a 40-minute reply over seven numbered items) and s323 ("what the f is 'venue wall 2'"). The paragraph that answers it (`:579-587`) is in core and absent from graph's installed copy, so s323 ran without it; the fix is in the distribution and not delivered.
- DEFECT 3: ops reads duplicate the lead's own scripts. In s323 the lead wrote `prefire.sh`, `prefire-active.sh`, `lockread.sh`, `apiread.sh` and `postfire-proxy-read.sh` and ran them (68 `aws ecs` Bash calls, 89 live probes) while 12 ops spawns repeated read-only reads. The independence requirement (2a "independent source") covers some of them, not the "pre-roll idle read" or digest equality. Upper bound per sprint: 12 spawns, $13.59, up to about 59 min wall (agent wait 26 plus merge-reading 33) if one committed read script replaced them; not all 12 are replaceable.
- DEFECT 4: touchpoint I is counted in assistant messages (above); a time-based window would cut about half the consults, upper bound about 7 min wall a sprint. One recorded "consult run after the fact" self-finding (gate-log area 1724-1725).
- DEFECT 5: continuity records. s323 had 59 `git commit` and 22 `git push` invocations in 5.3 h, with 33 numbered continuity commits (cont170 to cont202) plus hook-record commits, and 9 compactions. Extractor classes: snapshot 120 calls and 13.2 min; compaction recovery plus step re-read 6.4 min. The reader's own category split (covering 116 of 242 active minutes): git commit and push 7.9 min, snapshot-update 8.7 min. Upper bound about 28 min of lead wall per sprint.
- DEFECT 6: graph's stale copy of the merge-record block lacks `git add -f`; s323 recorded the deviation and needed three commit attempts. The 3b zero-activity PASS cannot fail (part 6).
- NOTE: two of seven s323 asks ("Wait state", "Stale cache") were rejected by the operator; both are of the kind where nothing stopped the lead (2.8 min wait).
- NOTE: a busy-wait `until grep -q ... /dev/null; do :; done` ran its full 120 s in s323 (23:34). Lead-side Bash calls of 90 s or more: s321 12 (all sleep-poll loops waiting for the smoke rc), s322 2, s323 3 (two 100 to 120 s diagnostic runs and the busy-wait). Ops subagents ran two `aws logs filter-log-events` calls in s323 at 236 s and 120 s.
- NOTE: the s323 deploy-validate gate-log section is 176 lines and 57.5 KB (of a 393 KB archive) with no machine reader; Checks 8 and 9 are read by a retro adjudicator that greps for field names. SCRIPT the field-presence check.
- NOTE: the 645-minute overnight ask (live security-config PUT) is consumer-owned and decided something ("enable in the same PUT"); nothing in the engine shortens it.

#### Redesigned shape

The step is kept; the shape changes to a scripted spine plus four judgments.

1. `deploy-validate-run.sh` owns parts 1, 1b, 2r and 2b, the smoke wrapper that writes the four fields from junit, the 4b literal check, the fix-forward cluster and escalation counts, the Locked-Requirement Coverage skeleton and the routing writes; it prints the PVC from records. Cost: one script of about 200 lines over parts that already have a deterministic spec, and one fixture each.
2. The model keeps four judgments: red-smoke triage and fix dispatch; post-activation reads after any live mutation; 4b predicate discharge or re-deferral; "What Was Built" and "Decisions for You".
3. The visual confirm is merged into the browser smoke (playwright with trace); a human confirm is asked only when no automated surface exists.
4. The quiet-window PASS in 3b requires an injected or controlled event.
5. Fix branches are pushed from a clean checkout at their tip, so the unmodified hook tests the tip; an approval already given for a fix is not re-asked.
6. The sprint-PR merge approval is graph's seam and stays; fire, merge and PUT authorizations are declared at planning per named action (the ask-origin reading, lever 3), and fix-forward PRs merge on green from a clean worktree under that authorization; the consumer holds that text.
7. The step file shrinks to the four judgments (about 15 KB) with 2a, 2b and the escalation-release rule moved to read-on-need files.

#### Upper-bound saving

UPPER BOUNDS, per sprint: for an s323-like sprint, lead active about 1 to 1.5 h of 4.0 (scripts and record rendering), the ops spawns (12, $13.59, partial), and 15 min of visual wait; for an s321-like sprint, up to 5.0 h of operator wait (the fix-forward re-ask class), partly on the consumer's side. Overlap: the ops-read saving (about 59 min wall) and the lead's script saving are the same reads moved into one script and are not additive; the continuity-record saving (about 28 min) overlaps the cross-cutting snapshot and compaction items; the advisor-window saving (about 7 min) is separate. Nothing in the redesign removes a catch on record.

#### Not measured

- The s321 and s322 gate-log deploy-validate sections (catches there beyond the existing s321 reading). Available, not done.
- Lead dollars per part (only whole-step token counts exist; $64 as an earlier whole-step figure was not re-derived). Lead dollars per step after relabel are not established.
- Whether the s323 lead read `deploy-validate-domain.md` or `-push.md` (neither is in its Read list; it used 124 `ctx_execute` calls and may have read them there). Available, not done.
- The retro adjudicator's cost of reading the 57 KB gate-log section; the s323 2a rows; per-consult usefulness beyond the three named. Available, not done.
- The phase reconstruction gives 3.7 h of lead active time against the extractor's 4.03 h, and the lead-time category split covers 116 of 242 active minutes: approximations.
- A counterfactual run with a scripted spine is not available.

### 6.11 Retro

Step file: `core/skills/ai-dlc/steps/retro.md`, 1,739 lines, 101,094 B, 8 code fences (170 lines, 10,205 B, 10% of the file), 4 "Minimum mechanism (Rule 26(c))" paragraphs (4,079 B), 16 named scripts. Graph's installed copy differs by 33 lines (1,716 lines) and a 41 KB graph override, `overrides/steps__retro__domain-sections.md`, shadows sections 3, 5 and 7 (it restates Dispatch A, 7a and 7a-post). Which of the two renders the lead obeys was not verified. Sources: `findings/step-retro.md`, `findings/value-retro-party.md`.

Step files: `retro.md`

**Cost** (reconciled, step with its gate; hours on the monotone clock; subagent dollars at the one-hour cache-write rate, five-minute rate in parentheses):

| | Elapsed | Lead own (model+tool) | Idle, no agent | Waiting on agents under 5 min | Operator | Long agent wait | Spawns | Subagent $ | Lead calls | Compactions |
|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| s321 | 1.8 | 0.4 | 0.4 | 0.1 | 0.8 | 0.1 | 14 | 5.5 (4.2) | 170 | 1 |
| s322 | 4.1 | 2.5 | 0.5 | 0.4 | 0.5 | 0.2 | 31 | 17.7 (14.3) | 898 | 8 |
| s323 | 2.7 | 2.0 | 0.2 | 0.3 | 0.0 | 0.1 | 28 | 23.1 (19.5) | 605 | 7 |

s323's retro including its gate is 161.6 minutes of wall, 642 lead calls by the reader's per-call timeline (605 in the reconciled row), 28 spawns. Its phases sum to the segment window 01:36:11Z to 04:17:36Z. Only 52 seconds of it is operator wait. Every part is on the critical path: the lead is serial and the analysts run beside the lead's waiting only. The lead's own dollars were not re-derived.

Two earlier-clock readings of this step were wrong in kind. s319's retro took 8.8 h, of which 6.41 h (23,077 s) is one gap: the lead set the pause flag at 03:15:29Z for the Step 5 operator commentary and the next call came at 09:40:06Z; the old clock bucketed that as agent wait. s322's 5.3 h included 1.25 h idle after the last tool call. On the corrected clock s322 is 4.1 h and s321 1.8 h. Step 5's commentary wait is unbounded in the step text: s318 1.71 h pause plus 0.70 h ask, s319 6.41 h plus 0.64 h, s320 0.98 h of asks, s321 0.73 h, s322 0.44 h, s323 52 s.

Retro document size by sprint: s318 16 KB, s319 25, s320 35, s321 31, s322 139, s323 148. The jump coincides with sharded analyst drafting (16 analyst spawns, $11.3 in s322, against 8 and $2.8 in s321) and the local lead.

**Who reads what the step produces** (executed calls only: tool_use paired with a non-error tool_result; control: the retro session itself shows next-inputs 14 hits, retro-artifacts 1, party transcript 1):

- The closed sprint's `retro.md`: 0 reads in s323's route and carry-over session (249 executed calls); 5 hits across the other 15 s323 lead sessions, all line citations (for example `docs/retro/s322/retro.md:395`, `:698`, `:740` in a remediator brief and a gate evidence line). s322: 4 hits across 15 sessions.
- The 7b next-inputs bundle and `retro-artifacts`: 0 reads in s323; 4 in s322, all because the lead had planted a "NEXT-INPUTS (delivered, consume)" open item. No script or hook reads it (grep finds only `retro.md` and a path template). s323's retro PR deleted s322's committed bundle (7 files, 1,198 lines).
- The party transcript (74 KB): 0 reads by the next sprint. In-retro readers are the classify analyst, the transcript shard and `validate-retro-evidence.sh` (persona and phase marker floor, citation, byte match).
- `carry-over-backlog` (closes and moves from 4a): consumed, 22 calls in the first session and 26 reads of its archive, by grep of CO- ids. Escalations pending-archive 13 calls. Gate-log archive 21 calls in s323 (10 in s322).
- Audit anchors: read by gate-validation Check 18 (`core/skills/ai-dlc/steps/gate-validation.md:1722-1726`) and the coe analyst brief.
- The 7d handoff prompt and carry-over ids: consumed. s323's prompt items 1 to 6 are retro-scheduled `CO-S322-*` ids and `core/skills/ai-dlc/steps/route.md:638-655` finds the `[S<N> close-out proposes]` tag mechanically.
- `push-candidate-ledger`: 92 calls over 9 s323 sessions, also written during the sprint.
- Carry-over-evaluation does not read the retro document at all (it mentions retro only as context, lines 109-128 and 241-249). It re-reads the carry-over backlog itself (22 calls plus a coe-analyst draft) although 4a's sweep and 7b input 2 walked the same file. Content overlap was not measured, only call counts.

**Part table** (`core/skills/ai-dlc/steps/retro.md`; minutes are s323 lead-clock wall; "UB" is upper bound, not additive across rows):

| Part (file:line) | What it is for | Cost | Produces / who reads it | What it caught | Verdict |
|---|---|---|---|---|---|
| Step 1 branch cut and carry (:16-253; 97-line bash :25-121) | Land on trunk, cut the retro branch, carry post-squash commits | s323 2.9 min, 21 calls (lead wrote 2 scratch .sh); s322 8.2 min (hard block, 13 cherry-picks) | The branch; `validate-mandatory-rules` Check 7 | CARRY HARD_BLOCKs in s322 (real) | SCRIPT (`retro-open.sh`, 0 model calls). UB 3 to 8 min. Change: `retro.md:25-121` to `core/scripts` |
| Party mode (:255-371): Skill, 6 persona subagents, transcript commit, provenance block, classify analyst | Cross-role critique of the sprint | s323 7.3 min, 42 calls, $3.8 + $0.37 classifier, 13 agent-min; s322 6.5 min, $2.9; s321 $2.74 | 74 KB transcript; 34 findings in s323 (4 critical, 19 major, 11 minor). Readers: classifier, transcript shard, marker floor; none next sprint | All 4 s323 criticals were fixed or known before the retro (ff1 PR #1338 merged the day before). Strict party-only persisted survivors: s321 0, s322 3, s323 0 (see below) | SHRINK to three seats (test architect, QA, dev); MOVE it to run beside the close-out gather. UB 7 min wall |
| Dispatch A document split (:373-433): 7 analysts draft descriptive sections, join, lead writes the document | The descriptive retro document | s323 12.6 min wall plus 1.5 min write, 42 calls (first dispatch of all 7 hook-denied, re-sent 23 s later), $7.25, 25.7 agent-min (stories shard 8.6 min, $2.42, 52 KB) | 125.7 KB of the 147.8 KB document (85%), a re-transcription of stories, reviews, gate log, escalations, sprint status. Readers: 5 line-cites in 15 sessions; validators need only the transcript citation and provenance block (`validate-retro-evidence.sh:179-357`, `validate-provenance-block.sh:661`) | Nothing it alone could | CUT the 7-analyst drafting; keep the finding-class shard ($0.55, 3.6 min) because the graph override requires finding classes. UB 12 to 14 min wall, about $6.7, 22 agent-min. Change: `retro.md:373-433` (and the graph override 144-226) |
| Step 4 improvements, rule-file audit, resident scan, empirical gate (:435-663) and 4a close-out sweep with Dispatch B (:665-898) | Disposition of deferrals, closing carry-over, bright-line reclass | s323 26.5 min, 178 calls (4) plus 12.3 min, 83 calls (4c: dev reclass wait, second archive move, recovering a lost table); 3 analysts $2.88, 16.1 agent-min; lead wrote 3 archive scripts by hand | 25 closed backlog blocks moved to the archive, escalation archive move, 12 surviving deferrals with triples, 4 fix commits from the bright-line rule (`c061746ad`, `779a4fe5b`, `e269aabe7`, `2cb9bc1c6`) and `ecs-deploy.sh` (`73c537e3f`). The carry-over backlog is what the next sprint greps | The 4 bright-line fixes shipped: the part with a real catch | KEEP gather and disposition; SCRIPT the mutations (cut and paste archive with a no-loss byte check, status close). UB 8 to 12 min. Change: `retro.md:772-809` |
| 4b steerability audit and rotation (:924-1060) | Audit recurring steerability failures; rotate | 1.6 min, 9 calls | Rotation | Efficient | KEEP; script into retro-close. The audit's recurring FAIL is routed to the engine instead of re-narrated each sprint |
| Sprint-ship counters (:1062-1091) | 17 lines in the retro document | not separable | No reader found | Nothing | CUT unless a validator names them |
| Step 5 commentary (:1093-1105) | Operator commentary pause | s323 52 s; s318 to s322 0.44 to 6.4 h of operator wait, unbounded | The operator's remarks | n/a | KEEP the touchpoint; MOVE the pause after the PR push (commit, push and merge hooks run while the operator answers; commentary becomes an amendment) |
| 5b anchor and prune (:1107-1166) | Anchor entry, prune, no-loss | about 1 min, 8 calls | The anchor and pruned file | n/a | SCRIPT (entry, prune and no-loss in one call) |
| 5c validators 1 to 5 and gate[retro] (:1168-1263) | Validate the retro and adjudicate | Prep 9.4 min, 61 calls (Check-14 snapshot trim as 3 scratch scripts). Gate 35.5 min, 98 calls: 3 adjudicators 02:50-02:58Z ($5.1, 16.1 agent-min), lead idle about 5 min on the bounded join, then re-derives checks (03:00-03:11Z) and writes the gate entry (03:11-03:24Z). s322: 9 shards, $3.5, 26.9 min active | The gate entry and 32 GATE_METRIC rows | 0 FAIL in s322 and s323 (BL-1141). The scripts in 1 to 5 run anyway. A miss yields a wrong record in a retro PR, no production effect, fixable next sprint | CUT the adjudicators; SCRIPT the retro slice (`retro-gate.sh`: script arms, 914/915/929 count derivations, entry, GATE_METRIC rows); add `validate-artifact-paths`. UB 30 to 35 min wall, $5.1 (+ $3.5 in s322). Change: `retro.md:1222-1226` |
| 6a commit (:1269-1327) | Commit durable paths | 19.4 min, 26 calls; the lead classified dirty paths against `pipeline-state-paths.json` by 4 python runs (5 min); 12 advisor consults in the retro overall (5 inside 03:33-03:44Z before one push, 306 s direct) | The retro commit | n/a | SCRIPT: `git add` of DURABLE paths from the schema. UB 10 min |
| 6b push, 6d PR, 7a merge (:1329-1452) | Land the retro PR | push 453 s, PR and merge 1.5 min | Merged PR | n/a | KEEP; the hook is graph's |
| 7a-post rotation, terminal snapshot (:1454-1610), 5b backfill | Post-merge rotation | 3 hook runs after merge (132 s, 180 s, final about 230 s), about 770 s foreground for 3 to 4 commits; 7a-post 6.7 min, 15 calls; lead wrote `7a-post-land.sh`, `7d-snapshot.sh`, `7d-snapshot2.sh` | Rotated records | n/a | SCRIPT and batch the commits into one push. UB about 6 min. Whether the pre-push audit-anchor rule allows backfill and rotation in one push was not tested |
| 7b next-inputs (:1612-1653), 6 analysts | Bundle for the next sprint | $2.96, 7.8 agent-min; 13.8 min wall for 7b, 7c and 7d with pushes | No reader in code or transcript | Nothing | CUT 7b; 7c and 7d stay. UB about 9 min, $2.96 |
| 7d handoff block (:1674-1739) | The prompt the operator pastes | not separable | Operator pastes it; `route.md:638-655` reads the tag | `PC-S323-7D-HANDOFF-PROMPT-OMITS-CARRYOVER-IDS` (`fac51188a`) shows the prompt can miss ids | KEEP; the script prints the id list the PC says is missing |

**What the party seats caught, read per sprint.** Strictly, "only source is a party seat and persisted":

- s323: 0. The seats were handed a lead-compiled facts sheet (`s323-retro-facts.md`, 100 lines, 6.7 KB) that already held every item the retro PR then changed (premature rolloutState read, the `git add` block against the blanket `*.txt` ignore, the operator's "stay with me" discovery, the `sys.modules` mock hiding missing cryptography, the lead's own conduct items). Lines 84 to 94 are headed "Lead-owed self-filings (already on the record)". Of the retro PR's changes: the `ecs-deploy.sh` poll was a recorded gate-log deviation four hours before the party; the `.gitignore` negation was a recorded `add -f` deviation; the four small fixes are sweep items cited by `CO-S323-*` ids; `PC-S323-PLAIN-GLOSS` was filed before the party. The coding-conventions rule "A test MUST NOT mock the absence of a production module" is party-assisted (the rule is derivable from review S-3; whether the lead would have written it was not established; persistence at a later sprint's close is not measurable, s324 not started).
- s322: 3 persisted, each raised by 2 or more seats, so only the set is the source: I-3 the event-bound re-open rule for NOT_EVALUATED gates (five seats; consequence DEFECT, a green summary hiding an unmeasured success metric); I-4 "Validator Tests Against the Live Config Shape (Hard Gate)" (four seats; no s323 file cites it and s323 repeated the class, so no demonstrated catch); I-5 the `.env` import-injection carry, built in s323 story 3.1 (consequence DEFECT, 20 xdist failures; the retro's analyst shards read the s322 implementation artifacts, so the sweep side might have found it, not established). About 19 of 41 findings changed nothing.
- s321: none. Six seats, three generalised rules landed upstream in 0.1035.0 (BL-935, BL-936, BL-937), each proposed by 2 to 3 seats and each with an instance already on record; the same class recurred in s323 after the rules landed, so prevention is unshown.
- Per persona: no seat has a unique survivor. TEA (opus in s322 and s323) is the most productive; any two of TEA, QA and Dev cover every s322 and s321 item and the s323 convention, as one sprint-set reading. PM, Architect and SM are never the only source anywhere.

Cost of party seats (spawns ledger, step retro): s321 $2.74, s322 $2.90, s323 $3.82 (two opus seats are 65% of s323 seat cost and set the wall: 4.6 and 4.0 minutes against 0.7 to 2.3 for the sonnet seats). The decision under the standing rule is SHRINK to three seats. s323 seat cost $3.82 would fall to about $1.91; wall does not fall while the test architect stays opus. Moving that seat to sonnet would cut wall to about 2 minutes and is untested. CUT outright would free about 6.8 min and $4.2 and lose the generalised rules above. Dropping the classifier ($0.37, 1.0 min) is a separate decision. What would be lost by the shrink: the generalised rules the lead had no prior record of, and the s322 DOTENV carry decision; no critical finding and no s323 change would be lost. Engine change: `retro.md:255-281` (persona list, Rule 20 preamble 269-272), the `validate-retro-evidence.sh` persona floor (`PERSONA_MARKERS` count), and the retro Step 3 summary section.

**Named catches that earn the kept parts.** (a) Branch and carry correctness (the s322 carry hard block). (b) The close-out bright-line reclass (4 shipped fixes in s323) and the backlog and escalation closes the next sprint greps. (c) Rotation and no-loss (budget gates). (d) Audit anchors and the 5c scripts. (e) The 7d prompt, which the operator pastes and `route.md` parses. (f) Push candidates (4 in s323). The seats' generalised rules (BL-935 to BL-937, the re-open rule, the conventions) earn the three-seat party.

**Defects found.**

- BLOCKER (for time, s322 evidence): 5c does not run `validate-artifact-paths`, so a path-grammar violation surfaced only as a refused push. Push 1 (11:45:36Z, 285 s) was refused by the pre-push artifact-path validator (10 paths under `implementation-artifacts/sprint-322/smoke-evidence` outside the `s<N>/` slot). The retro then spent about 40 minutes (11:50 to 12:25Z): a path migration commit, 3 advisor rounds (7 consults in the retro), and pushes 2 (200 s) and 3 (203 s). It did not fire in s323. Fix in the retro gate script or `retro.md:1168-1226`. UB saved about 40 min wall and 2 hook runs (about 400 s) per recurrence.
- DEFECT: `retro.md:1045-1056` says `rm -rf _bmad-output/retro-artifacts` at 4b because "every one has already been consumed", but 4a's close-out tables are still needed afterwards (s323: the lead found "closeout-tables was deleted" and spent 14 calls, about 70 s, recovering 12 table rows, 352 to 365, from the session JSONL) and 7b writes the next-inputs bundle into the same directory afterwards (committed in `a9b015557`; s322's committed copy, 7 files and 1,198 lines, was deleted by s323's 6a commit). The two instructions contradict.
- DEFECT: the gate-log, pending and backlog archives are read for precedent (gate-log archive 21 calls in s323, 10 in s322) although `retro.md:1530-1532` says no step reads a prior gate entry. The rotation is right; the sentence is wrong.
- DEFECT: the old clock bucketed the Step 5 pause as agent wait (s319: 23,077 s against agent_wait 384.3 min), so earlier operator-wait figures for retro are understated; `steps.csv` retro agent_wait for s318, s319 and s321 contains operator time. The corrected rows above carry it.
- NOTE: the step file is 101 KB against a 16 KB read cap. s323 read `retro.md` 33 times (9 denied), s322 36 times (12 denied), against 3 to 4 in s318 to s321 under hosted leads. 79 errored calls in s322, 58 in s323 (26 Reads), 9% of calls. Each compaction costs roughly 8 to 10 re-read calls (post-compact digest 26.8 KB, snapshot 21.7 KB, the step file); s323 re-read the step 93 times (about 17.9 min, 5 compactions), s322 had 7 compactions.
- NOTE: the lead wrote 11 scratch .sh files (10 distinct) in s323's retro: retro-step1, retro-step1-combined, backlog-archive, verify-archive, escalation-archive, 5c-trim (twice), 5c-trim2, 7a-post-land, 7d-snapshot, 7d-snapshot2. Each is a step the text asks the lead to do by hand that a shipped script should do.
- NOTE: the first dispatch of the 7 draft analysts and two other calls were hook-denied and re-sent (7 errors, 23 s).

Already efficient: the 4b steerability audit and rotation (1.6 min), the 7a merge block (30 s), the Machine Audits single table, push-candidate routing by `core-paths.sh`.

**Redesigned shape: one lead pass, scripts carry the mutations.**

1. `retro-open.sh` (branch, carry, on-disk checks) and `retro-close.sh` (merge verify, rotations with byte no-loss, terminal snapshot, one commit batch, one push). Step prose shrinks to 5 to 10 lines each.
2. The party (three seats: test architect, QA, dev) and the close-out gather start together; the lead dispositions while the seats run.
3. The retro document is a script-generated facts header (counts, ids, paths), the finding-class table (one transcript shard) and the lead-authored improvements, routing and deferral triples: about 20 to 25 KB instead of 148 KB. No Dispatch A shards.
4. Mutations (archive moves, status close, anchor entry and prune, DURABLE-path commit) are scripts; the lead supplies only the decision list.
5. 5c is one `retro-gate.sh`: the five validators, `validate-artifact-paths`, the count derivations (914/915/929) and the gate entry. No adjudicators; a disposition-needed FAIL still escalates.
6. Step 5 commentary after the PR is pushed. Bound it, or have the next sprint's route read the answer.
7. No 7b analysts; the lead writes 7d from the carry-over backlog and its retained findings, and the script prints the id list.
8. Push count: the retro PR push plus one post-merge push (backfill, rotation, finalize, records) instead of 4 hook runs.
9. `retro.md` rewritten to roughly 35 to 40 KB: 8 fences become script calls; the Rule 26(c) paragraphs and the measured narrative leave the resident file. The post-compaction re-read goes from about 7 chunks to about 3.

Not removed on this evidence: the close-out gather (it earned the 4 fixes), the steerability audit, the 7d block.

**Upper-bound saving on s323** (overlapping, not additive): gate[retro] 30 to 35 min; Dispatch A 12 to 14 min and about $6.7; mutation and commit scripting about 25 min; 7b about 9 min and $2.96; compaction re-reads about 10 min. The per-part upper bounds sum to about 95 min. The reader's projection is 161.6 min down to about 60 to 75 min wall, subagent dollars $23.1 down to about $7 to 8, lead calls 642 (the reader's per-call timeline; 605 in the reconciled row) down to about 300 to 350; the call figure is an estimate from removing the listed parts, not measured. Operator waits of 0.44 to 6.4 h in earlier sprints move off the critical path under item 6.

**Not measured.** Lead dollars for the retro (token counts were available; not priced, and the hosted-lead sprints would need the price table). Part-by-part timelines for s318 to s321 (`tl_s31x.tsv` exist, not tabulated; s323 in full, s322 coarsely). `steps.csv` elapsed against segment wall does not reconcile for s318 (3.155 h against a 5.7 h transcript span with a 3,953 s unclassified gap). The 453 s, 132 s and 180 s hook durations are graph's pre-push content, not opened, and whether the audit-anchor trunk-push rule allows batching was not tested. Which render of retro (core or graph override) the lead obeys. Whether a party seat finding would have been found by another part (no counterfactual exists). Content-level overlap between 4a's sweep and carry-over-evaluation's re-read. Whether s324's carry-over session reads the s323 retro document (s324 does not exist). First-run failure rates of the five 5c validators across sprints (s323 had 14 Bash errors in the retro, not individually checked). Whether the lead would have written the s321 and s322 generalised rules without the party; the persistence of s323's convention; s319 and s320 party records (not read); per-seat dollars for s321 and s322 are as recorded in the spawns ledger, not marginal. Scripts: `docs/analysis/pipeline-efficiency-s323-opportunities-b261/steps/retro/` and `steps/retro-party-value/`.

### 6.12 Handoff, recovery and snapshot duties

These are the duties the lead carries around the steps: handoff, snapshot writes, post-compaction recovery, the advisor
touchpoints, the Stop-hook forced continuation, the hook-written records, and the loaded SKILL.md. Sources:
`findings/step-route.md` (duties 3 to 9), `findings/value-advisor-r.md`. Session start and the fresh-start path are in
6.1.

Step files: `handoff.md`

**What it costs.** Handoff work sits in the "route/handoff/pre-step" row of the per-step tables (the table is in 6.1;
s321 4.0 h, s322 3.9 h, s323 1.3 h elapsed; lead calls 301, 529, 267). Recovery, snapshot writes and advisor calls sit
inside the steps in which they happen. Class figures from the extractor (named with the class): snapshot class 6.43,
2.55 and 3.57 h (s321, s322, s323), 1,398, 1,251 and 1,255 calls; compaction-recovery class 0.27, 0.82 and 2.17 h. The
reader's own windows use different definitions and are labelled as windows. The lead ran locally in s322 and s323, so
every lead saving here is wall clock at $0; hosted advisor dollars are not in `spawns.jsonl` and were not measured.

**Part table.** (`R` is the post-compaction advisor touchpoint; `I` the push, merge or deploy touchpoint; Rule 32 is
`SKILL.md:1123-1169`.)

| Part (file:line) | What it is for | Cost | What it produces; who reads it | What it caught | Verdict |
|---|---|---|---|---|---|
| Handoff H1: stop teammates, bounded join beat, TaskStop, row rewrite (`handoff.md:27-66`; `handoff.md` is 9,020 B, 150 lines, 2 fences) | end a session without orphaning agents | 20 handoffs in s321-s323 (s321 12, 196.6 min, 76.6 of it push windows; s322 4, 434.0 min; s323 4, 6.4, 4.5, 8.4, 16.5 = 35.8 min, push windows 15.2 min); median 8.1 min over 20. Real handoff cost by the reader's window: s321 3.3 h, s322 7.2 h (6.0 h in one handoff), s323 0.6 h | the snapshot read by the next session's Step 0a | the failure on record: a lead recovered into the interrupted step and never ran handoff steps 3-4, branch 11 commits ahead with no resume line (`recover.sh` header); the HANDOFF GUARD exists for it and fired 4, 15 and 6 times (s321, s322, s323) | SHRINK: one beat, then TaskStop; a handoff in progress dispatches nothing new |
| H2 commit (`:67-68`), H3 finalize snapshot, advisor I, push (`:69-114`), H5 pause flag and marker removal (`:126-136`) | land the state | 16 of 20 handoffs called the advisor before the push; 8 ran a join beat, 7 a TaskStop; three pushes of 27-31 min in s321 were the consumer pre-push suite | pushed branch read by the successor | I touchpoint catches (below) | SCRIPT (`handoff-run.sh`: commit, snapshot-finalize assertion, push foreground and background past the 600 s ceiling, flags). Calls drop from about 30 to 2-4 |
| H4 resume line and `.driver/handoff` touch (`:115-125`) | give the operator the line to paste | one print and one touch | the operator pastes the line; `.driver/handoff` has no consumer in graph (a 0-byte file from Nov 19 02:54) | n/a | KEEP the resume line as a print |
| Snapshot writes (`snapshot-update.sh`; gate-validation.md Check 14 at :1150-1162) | keep Position, In-Flight, Open Items, Recent Activity current | s323 by kind: activity 477, teammate rows 238, set, line and open-item 388, trim (move to history) 75 calls (363 line-moves), `--help` 98 (71, 99, 98 over the three sprints), other 66; 1.14 MB of command text (850 B per call); 446 calls follow another snapshot call; generation latency of these calls alone 54, 34, 40 min (lower bound) | Position, In-Flight and Context Reminders are read by `recover.sh`, `continue.sh` Check 0, the handoff guard and the sensor; Recent Activity is read by no decision script (only `rotate-snapshot-archive`, `validate-artifact-budget`, `snapshot-update`, the size count in `recover.sh`, context-sensor text); the lead reads the snapshot after a compaction (340 snapshot Reads, 3.7 MB in s323) | a snapshot beat a stale summary at least once (an advisor said "trust the snapshot rows instead"); row adds fell from 356 to 85 once `ai-dlc-inflight-row.sh` went live; row-delete 155 and row-status 88 remain lead-typed | KEEP the state, SHRINK the writing: `snapshot-update.sh` keeps the file inside budget at write time (oldest Recent Activity to history), the join deletes the row, the gate transition writes position and activity. Snapshot-update refuses a trim that destroys lines. Put the op list where the lead holds it after a compaction (98 `--help` calls) |
| Post-compaction recovery (`SKILL.md:25-97`; `hooks/ai-dlc-recover.sh`, `ai-dlc-recover-gate.sh` 779 lines, `postcompact-digest.md` 27,779 B, 405 lines; chunked reads since BL-1184) | make the lead reload state before it acts | window from boundary to first productive call: s321 2.66 h, s322 2.10 h, s323 3.04 h (median 56 s, mean 73 s, median 5 calls) over 59, 82 and 150 compactions (150 is every lead session labelled s323; the pipeline sessions had 134). Context after a compaction median 32K, 23K, 45K tokens. Baseline of about 110 KB (about 28K tokens) before any recovery Read: instructions 50 KB, re-attached SKILL.md head 20-27 KB, skill listing 18 KB, summary 19 KB. Recovery Reads on top, mean per compaction in s323: snapshot 18 KB, step file 18.5 KB, digest 9 KB | the injected block (under the 10,000-character cliff), the `.recover-fired` marker, credit records, `.recover-advisor-owed`; the lead obeys the block, the gate reads the credits and denies every other call until coverage completes | PC-S303 (a lead skipped both mandated Reads twice and stopped at line 773 of 1210 on the third); the handoff recovery that skipped handoff steps 3-4. Both were skipped reads of state, not too-small reads | SHRINK, proposed for the reads it saves: the hook injects Position, In-Flight rows with deliverable state, Open Items and recent activity up to about 9.5 KB plus a sub-step pointer; the gate credits that block as the snapshot read; the step-file mandate narrows to the section the snapshot names; the 27.8 KB digest is not mandated on every recovery. Requires a scratch-copy rehearsal with a seeded compaction comparing the first 10 actions with and without; it must not be claimed to fix stale beliefs (see the advisor R reading) |
| Advisor touchpoint I, push, merge, deploy (Rule 32) | independent check before an irreversible action | s323 224 advisor attempts (222 `mcp` consult, 2 built-in), median 31 s, 2.10 h wall; s321 330 attempts (319 built-in), median 81 s, 6.09 h; s322 50 attempts, median 25 s, 0.42 h. By lead text before the call, s323: R 54, G 54, I 46, other 85 (keyword guess). The lead waits in the foreground, so all of it is wall clock | the advisor-gate hook denies a push without an attempt; no validator checks the advice was used | in graph's own records: the adjudicator verdict checked at the wrong path; the lead editing `docs/architecture.md` in a dev worktree; "Collect Rewards unblocked" claimed with no Base-path read; F-1 misread the brief with ordinal 06 unread; a canary deselect that was a possible CRITICAL; LR-S323-27 narrowed. Sampled: a malformed commit trailer and wrong classification caught before a push | KEEP (hook-enforced outside the repo; catches on record). G1 and G2 belong to the gate step (6.7 to 6.9) |
| Advisor touchpoint R, after a compaction (Rule 32) | catch a lead working from a stale summary | 116 of 134 compactions had a result read; 0.95 h for the 105 R-timed first calls (median 30 s, max 120 s); all 209 advisor calls in the 134 segments 6,973 s = 1.94 h, median 30.6 s. Gate pressure: 56 R-denials of Agent, Write or Edit in 31 segments | advice text only; the lead records disagreement in the artifact it is writing | CAUGHT 49, CAUGHT* 18, ADJUSTED 44, CONFIRMED 3, IGNORED 0, 2 unclassifiable (below) | KEEP unchanged, including the dispatch hold. Withdrawn: fold R into the first G1 or I consult; call the advisor first; claim a hand-off fixes stale beliefs. Keep: load the advisor tool at session start (1.0 min over 5 starts) |
| Stop hook forced continuation (`hooks/ai-dlc-continue.sh`; Rule 3 `SKILL.md:142-194`) | stop a lead that ends a turn with no tool call while the pipeline is active | fired 39, 64, 63 times (s321, s322, s323), 3.4 KB each; HANDOFF GUARD 4, 15, 6; Rule 11(a) once. In s323, 58 of 63 fires were followed by a tool call in the same turn (first call: Bash 44, ToolSearch 3, Agent 2, Write 3, advisor 2, Monitor 2); median 3 s to the next assistant row. 0.2 h | forced turns | 0 s323 fires where the first action was the pause-flag touch (1 in s321): it forced waiting beats, not stalls | SHRINK: allow the stop while a beat lease or a live background agent exists (`continue.sh` Check 0 already does this for handoff beats). The guard treats a live backgrounded push as pending |
| Records written by hooks: spawn ledger, continuation log, operator history, In-Flight rows, context sensor | state other parts read | 0 lead calls | see 6.1 | n/a | KEEP |
| SKILL.md as loaded | rulebook | see 6.1 | | | SHRINK to a core of about 8 KB with rule bodies on demand |

**The post-compaction advisor call (R): kept, with its evidence.** Population: the first advisor result after each of
the 134 compactions in the 5 s323 pipeline sessions (134 = 2 + 11 + 15 + 76 + 30; it equals the roll's 134); 116 had one
and were read; the 18 others are compactions with no advisor call at all. s322 was not read.

| Step | CAUGHT | CAUGHT* | ADJUSTED | CONFIRMED | IGNORED | UNCLASSIFIED | classified of compactions |
|---|--:|--:|--:|--:|--:|--:|--|
| carry-over-evaluation | 0 | 1 | 6 | 1 | 0 | 0 | 8 of 9 |
| requirements | 6 | 1 | 4 | 0 | 0 | 0 | 11 of 13 |
| architecture | 8 | 0 | 1 | 1 | 0 | 0 | 10 of 12 |
| stories-test-strategy | 10 | 3 | 1 | 0 | 0 | 1 | 15 of 19 |
| ui-direction | 2 | 0 | 0 | 0 | 0 | 0 | 2 of 2 |
| implementation | 8 | 12 | 21 | 0 | 0 | 0 | 41 of 47 |
| sprint-review | 9 | 1 | 4 | 0 | 0 | 1 | 15 of 16 |
| deploy-validate | 3 | 0 | 4 | 1 | 0 | 0 | 8 of 9 |
| retro | 3 | 0 | 3 | 0 | 0 | 0 | 6 of 7 |
| TOTAL | 49 | 18 | 44 | 3 | 0 | 2 | 116 of 134 |

Definitions: CAUGHT is a concrete error the advice names that the lead's own text or action shows it held, with later
actions that differ. CAUGHT* is advice that the summary or plan is stale ("pass 2 already dispatched, do not
re-dispatch", snapshot line N says so) where the lead then did not do it but nothing shows it intended to (these may be
undercounted CAUGHT). ADJUSTED is checks or ordering added with no wrong claim shown; it includes 6 false alarms where the
lead checked and its own claim was true (rows 53b4#30, #37, #38, #42, #48 and 6492#15). The two unclassifiable rows are one
whose advice text was indexed away by context-mode and one whose consult ran to the background at 120 s. Where the lead
disagreed with a premise (6 rows) it still ran the check the advice asked for, and the lead was right. About 12 ADJUSTED
rows lean CAUGHT (claims asserted unverified, never shown wrong); the CAUGHT and ADJUSTED boundary is judgment.

What the 49 CAUGHT are: 33 are errors in a draft brief, entry or script or in a memory-held fact (JUDG 19, OTHER 14), 9
are state the snapshot would have shown (SNAP), 4 are the lead's own read coverage (TRUNC), 2 are git state (GIT), 1 is a
wrong snapshot (the snapshot itself claimed edits done that were not). The costliest, from the record: an archive rotate
run against the archive file moved 1,756 entries out and would have gutted the commit; a Check 35 re-run destroyed 65
snapshot lines (recovered from git); a gate-3 freeze broken with evidence not covering the shipped sha; an operator-locked
decision (LR-S323-36 "wide") contradicted; a false repair record that would have broken a join; a push without its commit;
invented timestamps in records and in 7 briefs.

Counterfactual for the state-injection proposal, over the 67 CAUGHT plus CAUGHT*: 27 (40%) were state the snapshot
showed (9 CAUGHT SNAP plus 18 CAUGHT*); 40 were not (JUDG 19, OTHER 14, TRUNC 4, GIT 2 where the branch and last commit
would show one of the two). In all 27 the lead had already Read the snapshot, in chunks, before the consult and held the
stale belief anyway; the advisor found it by comparing the lead's claim with the snapshot lines, and 6 of the 27 mention
a truncated or folded snapshot read (the 16 KB read cap). Handing the state over is therefore not shown to remove the
error. A hook that renders the snapshot also inherits a wrong snapshot (1 CAUGHT and 4 ADJUSTED false alarms). The
highest-yield call follows a refused draft: 29 of the 116 calls came after an R-gate denial of a drafted dispatch or
write (14 CAUGHT JUDG, 5 OTHER, 2 SNAP, 8 ADJUSTED), against the 75 pure-recovery calls (33 ADJUSTED, 18 CAUGHT*, 20
CAUGHT of mixed type (7 SNAP, 1 snapshot-wrong, 3 JUDG, 5 OTHER, 3 TRUNC, 1 GIT), 3 CONFIRMED, 1 unclassified). The 21 of 29 yield figure in the decision record is on that basis.

No-call control (not randomized; the 25 had no digest Read before the first write, so they differ in kind from the 105,
mostly one session): 25 compactions had a dispatch or write before any advisor call. In none of them did a successful
dispatch repeat the previous segment's (type, description): 0 of 96 in the 14 never called again and 0 of 72 in the 11
called later (against 4 of 620 in the 98 advisor-first compactions, all four legitimate re-runs of a failed gate pass's
adjudicator shards). The base rate of the "re-dispatch running work" error without the call is 0 of 25, which cannot rule
out a rate near 1 in 10 at this N. Cost on the other side: 0.95 h for the 105 R-timed calls.

Limits: single reader and no second pass; 92 later advisor calls in the same segments (G1, G2, I, V1, P) are not
classified; thinking text read only for rows 101-115; "cost if acted on" is from the record for the rows named, with no
measured dollar cost; whether any of the 105 calls delayed a dispatch that then changed outcome was not measured.

**Defects.**

- BLOCKER: none.
- DEFECT 1 (handoff step 1 has no bound, `handoff.md:27-46`, `continue.sh` Check 0): in s322 an operator "handoff" at
  06:05 ran to 12:41 (377 min in-session, 11 pushes, 29 operator turns, 12 HANDOFF GUARD fires): the join beat over
  in-flight rows kept the lead working a story 1.8 bug fold through dev, gate 1 (NEEDS_REWORK), gate 2 and adjudication
  inside the handoff, and the operator asked at 08:14 "why are we wasting additional time by continuing story 1.8?".
  `handoff.md` says only that stopping a pass already near delivery discards it (:43-45). This one handoff delayed a
  requested stop by 6.0 h of s322's 7.2 h; the work done was real pipeline work, so the net loss to the sprint is the
  operator's wait, not 6 h of waste (not separated). Confidence high on the timeline, medium on the sprint cost. Fix: one
  beat, then TaskStop; a handoff dispatches nothing new.
- DEFECT 2 (`handoff.md:90-91` against the guard): the file tells the lead "If the push was moved to the background, do
  not issue another; end the turn and wait for its notification"; the guard then fires "step 3's push has NOT landed" on
  that end-turn, 12 times in one session and 17 of that message type over s322 and s323. Fix: treat a live backgrounded
  push (its task id or a lease) as pending. Wall clock about 0, each fire a 1-3 KB forced turn.
- DEFECT 3: resume from an over-budget snapshot with hand trimming (see 6.1).
- NOTE: `snapshot-update.sh --help` called 71, 99 and 98 times; its op list is in nothing the lead holds after a
  compaction.
- NOTE: the context-mode 16 KB read cap denied 155 over-cap Reads in s323; with chunked reads mandated after BL-1184,
  recovery volume for the 101 KB `retro.md` (7 chunks) and the 52 KB `implementation.md` (4 chunks) moves up, not down;
  no run exists since the fix.
- NOTE: during a gate `current_step_file` names the invoking step (`gate-validation.md:1400`), so the `gate-validation.md`
  Reads at recovery (37 recoveries, mean 81 KB, 5.3 Reads, max 178 KB) are the lead's habit, not the recover gate's
  mandate. By step file, s323 recoveries: `implementation.md` 48 (mean 42 KB), `gate-validation.md` 37, stories-test-strategy
  20, sprint-review 17, requirements 14, architecture 13, deploy-validate 10.

**Redesigned shape.** (1) `handoff-run.sh`: one bounded join beat, TaskStop rows, commit, snapshot finalize assertion,
push, resume line, flags and the `.driver` touch; the guard stops firing on a live background push. (2) `snapshot-update.sh`
enforces the Check 14 budget at write; join and transition programs write position, activity and row deletes; the lead
writes judgment only (Open Items, Locked Decisions). (3) Recovery: the state excerpt hand-off for the reads it saves, after
a rehearsal, with the advisor R call and its dispatch hold unchanged. (4) The advisor tool is loaded at session start. (5)
SKILL.md reduced to a core with rule bodies on demand. In s323 terms: handoff about 16 minutes (pushes) instead of 36;
recovery roughly half of 3.04 h. Without limit: make recovery cheap enough that compactions stop mattering, since the
lead's own working reads (391 `gate-validation.md` Reads) are what fill the window.

**Upper bounds** (s323 basis, `$0` for the lead; not additive):

| Change | UPPER BOUND | Overlap |
|---|---|---|
| recovery (state excerpt, narrowed step read) | 3.0 h (whole window; expected 1.5-2 h, since the Reads are 3 of about 5 calls); about 6.8 MB of read results, about 1.7M tokens, cached on a local lead at $0 | the window overlaps the R advisor time partly (the window ends at the first non-read call, so R mostly sits after it, but the overlap was not resolved) |
| snapshot writes | 0.86 h (the consecutive-call class) | the trim part overlaps resume trims in 6.1 |
| handoff script and one-beat rule | 0.3 h in s323 (20.4 of 35.8 min is non-push); up to 6.0 h in the s322 case, 6.7 h counting the unbounded join | none |
| Stop-hook exemption | 0.2 h | none |
| advisor R | kept: 0 h removed. The 1.6 h figure (168 calls x 34 s) is not taken | n/a |

**Not measured, and whether it was available.**

- Advisor dollars, and the share of the 54 R-timed consults that changed the next action: available in principle (compare
  the lead's next three actions with the advice), a hand-labelling pass; not done beyond the 116 above.
- Post-BL-1184 recovery cost: not available (no run since the fix).
- The sufficiency of a 3-4 KB (injected up to about 9.5 KB) state excerpt: needs a rehearsal on a scratch consumer copy;
  not run. Smallest sufficient reload by the reader's reading of the snapshot schema: Position 314 B, Sprint Context 676 B,
  Open Items 746 B, In-Flight 73 B or more, about 10 Recent Activity lines about 1 KB, plus branch and last commit.
- s322 advisor value: available; not read.
- Compaction counts: 134 pipeline sessions and 150 with the 8 `/ai-dlc-update` sessions in the roll; the reader's 149 and
  150 use all s323-labelled lead sessions and are not reconciled with the 134.
- Class hours (snapshot 3.57 h, compaction-recovery 2.17 h) are class-attributed turn time; the reader's windows (3.04 h,
  generation latency 40 min) use different definitions: quote each with its name.

### 6.13 The update flow

The engine-update flow (`/ai-dlc-update`, `core/skills/ai-dlc-update/SKILL.md`) is not a pipeline step. It runs in separate lead sessions between and during sprints, and none of its time is inside the sprint totals of section 4. Sources: `findings/step-update-minor.md`. Population: lead sessions that loaded the skill, from the extraction's `units.jsonl`: s321 13, s322 8, s323 8 sessions (s317 to s320: 55 more sessions, read only for operator answers). Pulls are the `ai-dlc-update/<version>-reconcile` branches in the transcripts: s321 0.970 to 0.1028 (13), s322 0.1036 to 0.1101 (8), s323 0.1128 to 0.1174 (8). Clock: monotone.

Step files: `ai-dlc-update/SKILL.md`

**Cost.**

| | s321 | s322 | s323 |
|---|--:|--:|--:|
| Pulls (distinct releases merged) | 13 | 8 | 8 |
| Lead active, h | 4.72 | 5.92 | 8.12 |
| Elapsed, h (includes waits) | 25.2 | 14.1 | 16.4 |
| Lead calls | 881 | 1,317 | 1,751 |
| Compactions | 2 | 10 | 16 |
| Subagent spawns | 4 | 11 | 8 |
| Subagent $ | 1.64 | 3.26 | 2.05 |
| Lead API $ | 89.73 | 21.38 | 10.93 |
| Lead token-equivalent $ (s321 hosted mix) | | 64.39 | 78.92 |

s321's lead was hosted (real API dollars, control: the reader's s321 $91.37 equals $89.73 lead plus $1.64 subagents); s322 and s323 ran a local lead, so the token-equivalent row is the comparable figure. The s323 lead-call count here is 1,751 against 1,768 in the sprint roll; the 17-call gap is not reconciled (likely continuation legs that do not carry the skill marker). Pulls with no operator question (5 of 13, 3 of 8, 2 of 8; 10 of 29, 34%) cost the lead 0.35, 0.63 and 0.85 h and 64, 147 and 148 calls each, about the same as a pull with questions (0.37, 0.80 and 1.07 h). The orchestration drives the cost, not the asks. Every `/ai-dlc-update` invocation loads a 261,327 B skill (about 65 to 75 thousand tokens at an assumed 3.5 to 4 B per token) and loads happen 32, 21 and 19 times per sprint. After-compaction first-response gaps total 0.24, 0.46 and 2.08 h; in s323 that is 26% of the 8.12 h lead-active figure (UPPER BOUND, each gap also holds real work).

Per-stage cost is approximate: the reader's `stage_time.py` attributes each gap between transcript events to the stage of the last script keyword seen, so hours are approximate and its ask column is unusable (it placed 2.3 h of asks under fetch); ask wait comes from `asks.py`. Lead hours / script-wait hours (background commands the lead waits on):

| Stage | s321 | s322 | s323 |
|---|--:|--:|--:|
| 1 fetch and stamp (dist-clone) | 0.18 / 0.12 | 0.19 / 0.00 | 0.28 / 0.00 |
| 2 self-update gate | 0.18 / 1.13 | 0.27 / 0.77 | 0.46 / 0.67 |
| 3 to 3g, 4 classify and detectors | 0.46 / 0.18 | 0.75 / 0.40 | 1.33 / 0.15 |
| 5 report and adjudication prose | 0.82 / 0.62 | 1.12 / 0.47 | 2.65 / 0.98 |
| 6 to 7 apply.sh | 0.17 / 0.49 | 0.30 / 0.80 | 0.33 / 0.57 |
| PR, merge | 0.65 / 0.00 | 0.59 / 0.12 | 0.69 / 0.02 |
| push (graph pre-push suite) | 0.27 / 2.38 | 0.18 / 1.86 | 1.17 / 1.37 |
| Stage total, lead | 2.81 | 3.60 | 7.12 |

The stage totals are smaller than the lead-active row because the latter also counts model time next to short waits. Ask wait (question to answer): 118, 118 and 196 minutes; of that, asks made only of override, extension or delete questions: 5 (plus 100 in one mixed ask), 73 and 158 minutes. Background script runtime per sprint, minutes: `git push` 163 / 138 / 161 (n = 12 / 9 / 14), self-update-push 52 / 0 / 38 (n = 5 / 0 / 3), apply.sh 47 / 65 / 46, emit-report 21 / 45 / 61 (n = 17 / 19 / 21), self-update-gate 39 / 34 / 16 (n = 24 / 14 / 8), layer-drift 0 / 0 / 13.

**Part table** (`core/skills/ai-dlc-update/SKILL.md`: 3,378 lines, 261,327 B, 0 code blocks, prose with inline code; the procedure at L170 to L2779 is 205 KB). Nearly all of steps 1 to 6 is already a script (`reconcile/*.sh` is 3.7 MB, including apply.sh at 4,129 lines, emit-report.sh and layer-drift.sh at 208 KB); the prose mostly tells the model how to chain and read them.

| Part (file:line) | What it is for | Cost | Produces / who reads it | What it caught | Verdict |
|---|---|---|---|---|---|
| L1-169 preamble, inputs, invocation, taxonomy (10.7 KB) | Orientation, read at every invocation | in every load | The model | n/a | KEEP, at 2 KB |
| L183-324 step 1 resolve inputs (11 KB) | Stamp, branch sync, dist-clone, four ref checks | stage 1: 0.18 / 0.19 / 0.28 h | The dist clone | n/a | SCRIPT (`dist-clone.sh` exists; the four checks are shell). Frees lead 0.2 to 0.3 h |
| L325-864 step 2 self-update (43 KB, 540 lines; the largest part) | Gate, then an autonomous commit-merge cycle for the machinery slice | stage 2: lead 0.18 / 0.27 / 0.46 h; script wait 1.13 / 0.77 / 0.67 h | `self-update-gate-<ts>.md` (198 files in graph; only `self-update-fixtures.sh:269` reads them). Of 46 gate logs in s321 to s323 (logs, including reruns), 34 say SELF-UPDATE-DEFER and 12 SELF-UPDATE-OK | n/a | SCRIPT the DEFER branch; SHRINK the prose to a pointer. Frees lead 0.2 to 0.5 h; the 0.7 to 1.1 h script wait stays unless the DEFER decision precedes the fixture run (not verified) |
| L865-1606 steps 3 to 3g (48 KB) | The lead runs preclassify, layer-drift, unregistered-drift, relabel, ledger-reverify and predicates one by one, reading each output | stage 3: 0.46 / 0.75 / 1.33 h | Detector output. `emit-report.sh:382-993` re-runs every one of them, `--verify` re-renders again, and `apply.sh` runs `--for-apply --verify` again: up to 4 runs per detector per pull | The detectors' own catches (a HARD core-schema drift, override drift) are real | MERGE into the driver. Frees lead 0.46 / 0.75 / 1.33 h (UPPER BOUND) and about 38 min per sprint of emit-report reruns at s323 (21 runs for 8 pulls, mean 2.9 min) |
| L1607-1614 step 4 semantic classify, plus `reconcile/classify-block.md` | One agent per CLASSIFY file | 4 / 11 / 8 agents per sprint, $1.64 / $3.26 / $2.05, 0.1 to 0.7 min each | Verdicts. All 8 s323 verdicts: conflict 0, needs-confirmation 0, FILE_ACTION mostly take-theirs (7) or mixed-layer (1); the same `dev.md`, `qa.md` and `deploy-validate.md` every pull (setup-sited, consumer at base) | n/a | SCRIPT: consumer equal to base outside declared setup spans means take theirs; dispatch only when it differs. Frees about $2 per sprint and the lead's dispatch-and-read time |
| L1615-1775 step 5 report and HARD STOP | emit-report region pasted verbatim, lead prose, `blocker-adjudication-<ts>.md` (120 files in graph) | stage 5: 0.82 / 1.12 / 2.65 h lead; 0.62 / 0.47 / 0.98 h script wait | The adjudication file is read by the model at `SKILL.md:1971` and by no program (grep of `core/`, `scripts/`, graph's installed `scripts/ai-dlc` and skill copy: zero hits; control token `reconcile-log` found in `check-owed-derivations.sh`). Every dry run was followed by an apply in the same pull; the pause between them has a median of about 3 minutes (s322 sum 43 min, s323 sum 42 min; s321's 11 gaps include two outliers of 154 and 71 min, probably overnight, excluded as handoff-like) | The stop is a second gate in front of the PR merge gate | SHRINK: the dry run becomes the PR body |
| L1776-1805 step 6 isolate branch (2 KB) | `git checkout -b` | small | The branch | The consumer-edit safety | SCRIPT; keep the behaviour, drop the prose |
| L1806-2779 step 7 apply (76 KB, 974 lines) | `apply.sh` (305 KB) does the bulk (s323: 290 files RESOLVED pure-apply in one pull); the lead's remainder is the adjudication loop (L1889 on), finish, push, PR, merge | stages 6 to 7: 0.17 / 0.30 / 0.33 h lead; asks 11 / 11 / 11 per sprint. Of 31 reconcile logs in s321 to s323, 16 carried a HARD-* row (override drift 6 logs, layer-adjudication-missing 13 mentions), 28 a WORKLIST row, only 3 neither | The consumer's reconcile PR | The in-place edit stop (see touchpoints) | SCRIPT the clean cases, KEEP the stop for conflicts |
| PR, merge, push | Land the reconcile PR through graph's pre-push suite (about 214 fixtures) | PR and merge 0.65 / 0.59 / 0.69 h; push stage 0.27 / 0.18 / 1.17 h lead and 2.38 / 1.86 / 1.37 h script wait. Mean pre-push 11.5 to 15.3 min, max 86.9 min. `git push` counts 12 / 9 / 14 plus self-update-push 5 / 0 / 3 per sprint (1.3 / 1.1 / 2.1 per pull; includes fix PRs, upstream-candidate filings and retries after a red push, not split by branch name) | The merged pull | Reds seen: s322 upstream MKPW fixture defect (operator took the upstream fix), s323 pytest 9.2.0 against the 9.1.1 pin (4 of 214 fixtures; the operator pushed back and the lead fixed the sandbox pin), s323 gate-adjudication S23-pre control (upstream fixture, waited for the fix) | KEEP the consumer's pre-push suite. One push per pull would be about 156 / 120 / 96 min against 215 / 138 / 199 observed: UPPER BOUND 0.3 to 1.7 h per sprint, not verified |
| L2780-3131 mask/reinject (27.8 KB); L3132-3166 layered consumers (2.2 KB); L3167-3344 untangle (11.9 KB); L3345-3379 not-yet-wired (1.9 KB) | Reference sections loaded with every invocation | Part of every one of the 19 to 32 loads per sprint | Untangle invocations s317 to s323: 0 (control: the token `reconcile-report` returns 103 rows in the same dumps) | n/a | CUT untangle from the always-loaded file (its own file, read only for the argument); move mask/reinject next to `classify-block.md`. Frees about 40 KB (15%) per load |

**Which stages need a model at all.** None of fetch, gate, preclassify, detectors, emit-report, hard-blockers, apply.sh (clean cases), push, PR and merge. A model is needed for: (a) a three-way conflict hunk (`readopt-override.sh --merge` leaves markers; 3 asks in s321 to s323, all answered "keep both" or "yours", the recommended option); (b) an in-place consumer edit of an engine-owned file (register-drift: s322 `dev.md` and `qa.md`); (c) extension adjudication where text evidence must be read (15 questions, all still-additive; one cheap classify-style agent could record the verdict with its CORE_LINE and ENTRY_LINE evidence, reviewed in the PR diff); (d) diagnosing a red pre-push (4 questions).

**Operator touchpoints, s321 to s323** (`asks.py`; 33 asks, 52 questions, labelled by hand from headers). Families, s321 / s322 / s323: override drift 3 / 5 / 5 (13), extension still-additive 7 / 7 / 1 (15), pristine delete 2 / 0 / 4 (6), merge confirm or target pin 2 / 3 / 0, ledger or derivation 2 / 0 / 1, conflict hunk 1 / 1 / 1, push-red or unblock 1 / 1 / 2, in-place edit of an engine file 0 / 2 / 0, re-approve 0 / 1 / 0. Answer kinds: took the recommended option 13 / 14 / 11, first unbadged option 4 / 3 / 2, other option 0 / 3 / 0, declined 0 / 0 / 1 (the s323 pre-push-red ask; the s321 "declined" row is a parser artifact, the file was `git rm`'d 10 minutes later). Of the 52 questions, 34 (override drift 13, extension still-additive 15, pristine delete 6) were default-accepted. Across s317 to s323 there are 102 asks and 167 questions, and 4 questions were answered other than the lead's recommended or first option (s319 one, s322 three); s317 to s320 account for 69 asks and 115 questions with one non-default answer (s319 role-models "Mine; include it").

Touchpoints that decided something: the s322 in-place edit of `dev.md` and `qa.md` (a story's "Suite-launch admission" paragraph in engine-owned role files), where the operator chose "Revert the file" against the recommended refile-as-override (2 questions, ask wait 23 minutes); the s322 MKPW unblock ("upstream fix first"). Typed redirections that changed outcomes (not AskUserQuestion): s322 "the skill was supposed to handle branching" (branch discipline); s322 "why do you think the fix would be available? I haven't told you to pull anything"; s323 "why are those the only options?" and "why arent you looking at how the sandbox gets that version", which led to the root-cause fix of the pytest pin; s323 "Did you call the advisor?", which filed an upstream hook bug. Noise: "merge is approved when ready" typed 8 / 9 / 3 times per sprint, "eta?" and "stalled?" 2 / 4 / 1.

**Defects found.**

- DEFECT: the skill contradicts itself. At `core/skills/ai-dlc-update/SKILL.md:1968-1969` (on the tree this report was written against) it says "ask ONE closed question per blocker", while at `:2001-2002` it says that on a merge conflict "that is the one place a human is genuinely required". The reader cited these as `:1966-1967` and `:1999-2000`; on the current tree the same sentences sit two lines lower. In the record, 13 of 13 clean-merge override-drift questions took the recommended option, 15 of 15 still-additive extension questions did, and 6 of 6 pristine deletions did. Fix: ask only on conflict.
- DEFECT: detectors run up to 4 times per pull (lead steps 3 to 3g at `SKILL.md:865-1606`; `emit-report.sh:382-993`; the `--verify` re-render; `apply.sh --for-apply --verify`).
- DEFECT (local-lead goal): every apply invocation reloads the 261 KB skill and compaction follows (s323: 16 compactions in 8 sessions, 2.08 h of after-compaction first-response gaps); under a local lead this is a pipeline defect, not a finding against the model.
- NOTE: `blocker-adjudication-<ts>.md` has no program reader (120 files; 25 MB directory in graph across 770 files).
- NOTE: the dry-run to apply pause is handoff-like idle when overnight and is not counted as savable.

Already efficient: dist-clone (0.1 to 0.2 min), preclassify (0.3 to 0.6 min), hard-blockers (0.4 min), classify agents ($0.23 to $0.31 each), gate runs (1.6 to 2.4 min mean).

**Redesigned shape: one driver that hands the model only real decisions.** One program `update.sh [pull]`: (1) dist-clone and ref checks; (2) gate, with DEFER decided from the file set; (3) preclassify, detectors and emit-report once (`--verify` folded in); (4) mask-aware three-way: take theirs where consumer equals base outside declared spans; (5) cut the isolated branch and run `apply.sh` for every row that is a pristine delete, a clean readopt merge, or additive by evidence; (6) write `decisions.tsv` with only conflict hunks, in-place edits of engine-owned files with no override, extension rows the script cannot prove additive, and red-push diagnosis; (7) push once, open the PR with the report as its body. The model is started only on `decisions.tsv` rows, with a handbook of roughly 15 KB instead of the 261 KB skill. The operator touches the real decisions (3 in 29 pulls) and the PR merge. Ask only on conflict. Untangle and mask/reinject leave the always-loaded file.

Safety kept: branch isolation (step 6), conflicts stop, deletes only when the consumer copy is byte-equal to base (`apply.sh` already tests "unmodified since base"), the in-place-edit stop (the one catch on which the operator overrode the recommendation), the consumer's pre-push suite, the operator's merge. Removed: the dry-run and apply double gate, per-question confirmation of clean merges, 4x detector runs, 19 to 32 skill reloads.

**Upper-bound saving.** For an s323-like sprint, lead active from 8.12 h to about 2 to 3 h (8 pulls at about 0.15 h mechanical plus the 3 decision pulls at about 0.4 h), ask wait 196 min to about the real decisions, token-equivalent $78.92 to roughly a quarter. These are design targets from the ask-free pull cost, UPPER BOUND, not measurements; the stage savings above overlap with them and are not additive. One-push-per-pull is a further 0.3 to 1.7 h per sprint (UPPER BOUND, not verified). All of it is outside the 75.4 h of s323, so it does not shorten a sprint's in-session clock; it frees the lead sessions that run beside and between sprints. The operator chose on 2026-11-20 to keep the update pace as it is, and the standing-rulings record is the chosen means of cutting the cost per pull (section 9).

**Not measured.** Whether an operator ever read the dry-run report (no read telemetry; only the dry-run to apply gaps, median about 3 minutes). Dollars per update stage (lead token cost exists only per session; stage hours are gap-attributed with a sticky stage rule, approximate; per-call attribution was available and not done). The s317 to s320 update-session stage split (55 sessions dumped, only their asks read). The push count split by branch name (available, not done). Whether the DEFER verdict can be decided before the gate's fixture run (gate cost 16 to 39 min per sprint; not verified). The 17-call gap (1,751 against 1,768) and the exact 2.08 h figure. Read-only throughout: no pull was dispatched or simulated. Scripts: `docs/analysis/pipeline-efficiency-s323-opportunities-b261/steps/update-and-minor-steps/`.

### 6.14 The minor steps

Seven conditional steps sit outside the eight steps of a normal sprint: `bug-investigation`, `artifact-consolidation`, `discovery`, `codebase-inventory`, `deep-codebase-analysis`, `doc-reconciliation` and `doc-repair-backfill`. Source: `findings/step-update-minor.md`, subject 2.

Step files: `artifact-consolidation.md`, `bug-investigation.md`, `codebase-inventory.md`, `deep-codebase-analysis.md`, `doc-reconciliation.md`, `doc-repair-backfill.md`, `research-requirements.md`

**Population limit, binding every row.** Graph is the only consumer measured (175 lead transcripts, s317 to s323). `core/skills/ai-dlc/steps/route.md:381-414` sends a project with trusted planning artifacts to feature, carry-over, sprint-execute or bug; the greenfield, brownfield and analysis-only variants are unreachable for graph. "Never ran" therefore describes graph, not the distribution. The verdict wording for those steps is "unreachable for this consumer, no evidence either way for others". None is cut on this evidence.

**How "ran" was established.** `minor_reads.py` counts assistant `tool_use` Reads (and Bash or ctx commands) naming `steps/<step>.md` in lead transcripts; prose mentions do not count. Controls in the same run: `implementation.md` 679 reads in 53 sessions; a nonexistent step name 0. Hits inside update sessions are `git diff` commands over the engine's own files, not runs (checked for the 4 sessions behind discovery's 8 hits and the 4 behind bug-investigation's non-s322 hits). Graph branch variants across all refs: carry-over 15, feature 2, bug, greenfield, brownfield and analysis 0 (control: 34 `ai-dlc/` refs in total).

**Cost.** These steps have no row of their own in the sprint tables of section 4. Where one ran, its cost is below. The step totals of the reconciled tables carry s322's bug-investigation work in the row "other steps (bug-investigation etc.)": 1.6 h elapsed, 0.6 h lead own, 0.0 h idle, 0.5 h waiting under 5 minutes, 0.0 h operator, 0.3 h long agent wait, 17 spawns, subagent $27.7 ($23.3 at the five-minute rate), 289 lead calls, 2 compactions; s321 has no such row and s323 has 0.0 h with 1 spawn after relabelling (2 before), $0.7 ($0.6 at five minutes). That s322 row includes Gate-1, Gate-2 and dev work on stories 1.4 and 1.8 that carries the bug-investigation label (below), so it overstates the step.

**Part table.**

| Step (file; size) | Parts (file:line) | Ran | Cost | Produced and who reads it | What it caught | Verdict |
|---|---|---|---|---|---|---|
| `bug-investigation.md` (16,416 B, 292 lines, 0 code blocks) | s0 exploration dispatch L15; s1 context L29; s2 investigation L42; s2b operator relief L82; s2c adversarial verification of the root-cause claim L105; s3 fix story L134; s4 validation L149 (6.4 KB, 39% of the file); s5 sprint setup L254; s6 gate L267 | s322 only, mid-sprint, not as a bug variant. On `/ai-dlc` resume the operator pasted a box-crash report (xdist, 31 workers, about 215 GiB); the lead (session 70fd1d6d, 2026-11-10 22:31) could not edit product code and read the step ("checking how this step handles a defect raised mid-sprint") via the defect-signal path `route.md:426-448` (`stories-test-strategy.md:568` and `carry-over-evaluation.md:98` are the other two entry points; which fired is not proven beyond the lead's own words) | Lead 1.13 h active (2 sessions) plus gate-validation[bug-investigation] 0.10 h. Investigation core: 3 analysts (28.9 min, $6.50), the 2c adversary (8.0 min, $1.65), a remediator ($0.80): about $8.95 and 39 agent-min. Labelled spawns total 14 and $25.1 but include fix-story work | `bug-analysis-xdist-runtime-footprint-crash-guard.md`, `bug-analysis.md`, `bug-analysis-adversarial.md`, story 1.8 (xdist crash admission controls), commits `5b035009a` ("premise refuted - collect footprint x xdist, pin never applied") and `4c1ef5afc` ("dispose 2c adversarial findings F-1..F-6"). Readers: story 1.8 and role-file edits; s323 requirements shards and the adversarial pass cite bug-analysis (grep of graph `_bmad-output`, control 0 for a random token) | The 2c adversary returned 6 findings (F-1 wrong producer of pytest 9.2.0, F-2 a live path missing from the ladder, F-3 a required control with no evidence, F-4 the lockstep 26.5 to 27.9 GiB evidence, plus 2 minor) and the remediator repaired them in the analysis before the story hardened. The operator also caught an arithmetic error by typing | KEEP s0 to s2c (a named catch with consequence: a box-crashing defect, premise refuted). s4 (6.4 KB) was not exercised as its own section in s322; no verdict |
| `artifact-consolidation.md` (10,739 B, 186 lines, 1 code block) | working-files rule L35; s1 baseline manifest L66; s2 draft split L79; s3 no-loss verification L104; s4 Rule 20 validation L116; s5 commit the swap L126; s6 retire drafts L141; s7 stop L182 | s318 only (session f849d75f, 2026-10-12 03:10 to 05:55 UTC, operator-invoked; trigger `route.md:290-294`, Step 1a artifact-size budget exit 1, remedy `consolidate`). Not re-run in s319 to s323 (0 reads, control above) | Lead 0.77 h active, 1 session, 0 compactions, 0 operator turns; 15 spawns (11 analysts, 4 adversaries), 52 agent-min, $11.07 | Commit `432a9009c`: whole-read pool 332,286 to 65,766 tokens (budget 66,000): prd 95,317 to 25,694, product-brief 26,384 to 7,958, architecture 115,934 to 20,060, carry-over-backlog 94,651 to 12,054; history and archive files, 4 manifests, 4 coverage reports, 4 validations. Readers: `validate-artifact-budget.sh` (pool arm) and every later step that reads those artifacts whole (`SKILL.md:907`, "consolidate first, then read whole") | The 4 adversary validations found 1 critical (architecture), 8 major and 13 minor (sum of their finding lines), repaired in the drafts before the swap; the no-loss check reported 0 missing lines | KEEP. A recurrence needs the same step; nothing to shrink on this evidence |
| `discovery.md` (15,405 B, 292 lines, 3 code blocks) | s0 L16; s1 L37; s1a prior-decision search L46; s2 option check L85; s3 brainstorm L97; s4 product brief L110; s4a locked requirements L119 (3.5 KB); s4b spec kernel L190 (4.7 KB); s5 validation L269; s6 gate L286 | 0 times in s317 to s323; trigger `route.md:411-413` (no planning artifacts and no source code) | No runtime in graph; update pulls diff it. 65 files in the distribution name it, 21 fixtures, 14 scripts | n/a | Unreachable for this consumer, no evidence either way. s4a and s4b overlap the requirements authoring chain; not compared |
| `codebase-inventory.md` (3,222 B, 67 lines) | s0 L15; scan L27; audit L37; gap L52; gate L58; proceed L62 | 0; trigger `route.md:405-409` (artifacts exist but stale, code mid-implementation, brownfield-a) | 4 files name it, 0 fixtures | n/a | Unreachable for this consumer |
| `deep-codebase-analysis.md` (3,450 B, 79 lines) | s0 L16; structure L27; architecture AS-IS L35; features L44; quality L51; write L61; route L69 | 0; triggers `route.md:396-397` (analysis-only) and `:410-412` (brownfield-b) | 3 files name it, 0 fixtures | n/a | Unreachable for this consumer |
| `doc-reconciliation.md` (2,642 B, 63 lines) and `doc-repair-backfill.md` (2,814 B, 57 lines) | not listed | 0; trigger `route.md:405-407` (artifacts exist, trustworthiness NOT SURE, brownfield-c) | 8 files name each, 2 and 1 fixtures | n/a | Unreachable for this consumer |
| `research-requirements.md` | not listed | 0 as a step in s317 to s323 (section 6.3: it never ran as a step; its only rows are two "PRD rubric walker" spawns charged to it by the extractor's label) | n/a | Read three times per sprint by the requirements authoring chain for contract text (`requirements.md:236`; section 6.3) | n/a | Analysed in section 6.3, not here |

For the five never-run steps the reading is: do not cut or merge on graph's evidence. The four small ones total 12.1 KB, so the saving is nil either way. A distribution-level reading (other consumers, sprints before s317) was not available in this corpus.

**Named catches that earn the kept parts.** Bug-investigation's 2c adversary: a box-crashing defect whose premise (pytest 9.2.0 as the producer, "pin never applied") was refuted, with 6 findings repaired before story 1.8 hardened. Artifact-consolidation: a 332,286-token whole-read pool brought under its 66,000 budget with 0 missing lines and 1 critical, 8 major findings repaired before the swap.

**Defects found.**

- NOTE: `bug-investigation.md` writes its adversarial output to the fixed path `bug-analysis-adversarial.md`, which is overwritten on every run. The 2c adversary reported overwriting a committed, unrelated 32 KB sprint-298 review at that path.
- NOTE (extraction label): the "discovery" sub-segments in the extraction (s318 0.12 h, s319 0.33, s321 0.95, s322 0.19, s323 0.00; 1.59 h of agent time) are not the discovery step. The first prompt of each of the 5 subagents is the requirements step's section 4 authoring chain (pm-escalated), so they probably belong in the requirements row. Likewise several s322 "bug-investigation" spawns are Gate-1, Gate-2 and dev work on stories 1.4 and 1.8. Section 10 carries this as an instrument defect.

**Redesigned shape.** None beyond the file-name fix above. The two steps that ran earn their place; the five that did not run are unreachable for graph and stay.

**Upper-bound saving.** None claimed. Cutting the five unreachable steps would save nothing measurable (the four small ones total 12.1 KB of an engine that graph loads by name), and the evidence does not support it.

**Not measured.** Other consumers' use of any minor step (not available: graph is the only consumer transcript corpus). Whether any minor step ran before s317 (transcripts before 2026-10-07 are gone from disk). The `bug-investigation` s4 validation section (6.4 KB), not exercised in s322 as its own section. Which of the three entry points fired for s322's bug-investigation, beyond the lead's own words. The requirements-versus-discovery overlap at s4a and s4b. Scripts: `docs/analysis/pipeline-efficiency-s323-opportunities-b261/steps/update-and-minor-steps/` (`minor_reads.py`, `minor_reads.out`).

## 7. What cuts across steps

### 7.1 The lead's own time

The lead's own work in s323 is 28.0 h: 22.4 h of the local model generating, 5.6 h of tool execution (with the hooks
and harness around each call). A further 2.9 h is idle with no agent running, and 15.4 h is the lead waiting on
agents that are running, which it cannot shorten. In the implementation step the lead is the critical path: a
finished agent waits for the lead's next dispatch on its story (per-type gaps in section 6.7).

**Model time is decode-bound.** The median call takes 4.0 s; latency is about 8.7 s per 1,000 output tokens and about
0.27 s per 1,000 uncached input tokens. Context size does not move the median: it is flat at 3.4 to 3.7 s from 80K to
200K tokens of context (5.4 s above 200K). The 2,261 calls (20%) that write 1,000 or more output tokens hold 14.2 of
26.2 model hours (54%); their first tools are agent dispatch prompts (329 calls, 2.76 h, 1.03 M output tokens),
grep (284 calls, 1.58 h), `snapshot-update.sh` (131 calls, 0.79 h) and Write (49 calls, 0.48 h). The hosted s321 lead
was 5.3 s per 1,000 output tokens, so the local model is about 1.6 times slower per token. The reader's controls: per-class
calls and hours matched `MONO/classes.jsonl` for s322 and s323; the sum of response minus request over the local
calls is 26.2 h against 25.2 h of model intervals (4%).

**Where the lead's calls go** (s323, all steps; the "other" class is 4,520 calls and 19.9 h active: model 8.9 h, tool
3.0 h, waiting 8.0 h):

| Family | Calls | Active h | Note |
|---|--:|--:|---|
| Text-only turn, no tool | 572 | 5.60 | 4.82 h of it is waiting for a notification; the lead's own cost is 0.78 h |
| Advisor consult | 193 | 2.46 | 211 consults in the pipeline bucket |
| AskUserQuestion | 25 | 2.46 | 2.10 h of it is the ask pending |
| Bash shell reads (grep, sed, cat, ls, awk) | 1,146 | 1.98 | with the 593 `ctx_execute` reads (1.54 h): 1,739 separate model turns, 3.4 h, 3.1 h of it model |
| Bash git and gh | 190 | 0.71 | |
| `ctx_search` and index | 228 | 0.64 | |
| Read of skill and rule files | 230 | 0.46 | |
| Edit of gate records and planning artifacts | 166 | 0.46 | |

Each gate runs its arms one call at a time; `retro.md` is 1,740 lines with 8 code blocks and the lead wrote 9 scratch
scripts in s323's retro.

**Levers on the lead's own time** (s323 basis; UPPER BOUNDS; rows 7.1a, 7.1c and the re-read part of 7.1d overlap;
7.1b is disjoint from the rest):

| # | Found | Change | UPPER BOUND |
|--:|---|---|---|
| 7.1a | After each of 134 compactions the hooks require a 27 KB digest read, a snapshot read, a step-file read and an advisor call before work resumes. Summarizer plus slow first call cost 1.8 h firm; the calls up to the next productive action are 2,056 and 4.29 h (window B, which includes real triage) | The recovery hook injects the snapshot slice and the step's resume section itself. The post-compaction advisor call STAYS (section 7.1 below) | 4.29 h is the whole window and includes the advisor call's 1.55 h (the 125 of 211 consults that land within 40 calls after a compaction); with the call kept the reach is the remainder, at most 2.7 h (4.29 - 1.55, derived here), of which identical re-reads are 0.8 h (611 blocks) |
| 7.1b | The lead types each agent's brief: 329 calls of about 3,100 output tokens, 2.76 h. 131 dispatches were then refused for a missing `Deliverable:` line and typed again (211 of 1,033 dispatches refused in all, 20%, against 10% in s322) | A script renders the brief from the plan, the role and the shard; the dispatch carries a path and the fields that vary. A rendered brief cannot omit the line | 2.3 h and about 0.9 M output tokens, plus 0.66 h of refused dispatches |
| 7.1c | `gate-validation.md` is 247 KB. The lead read it 391 times (5.9 MB); 65 of 134 compactions happened inside gate validation. 155 lead reads were denied as over the one-read limit; 0.1184.0 names the exact chunk to read after a refusal and removes the blind retry, not the sixteen chunks | Each gate is run as a program (section 6.8), so the lead reads a verdict, not the procedure | 0.45 h in denied reads; the larger effect is fewer compactions, not sized separately (section 6.8 gives the lead-active figure) |
| 7.1d | 280 `snapshot-update.sh` calls ran immediately after another one (0.86 h). 131 calls carry snapshot text the lead typed (0.79 h); the class is 1,255 calls and 3.57 h | The programs that know a state change write the snapshot row themselves | 0.86 h and 0.79 h |
| 7.1e | Sprint review, deploy-validate and retro are prose the lead re-derives | Scripted spines (sections 6.9 to 6.11) | per step in section 6 |
| 7.1f | 1,739 separate shell reads (3.4 h) to look up what a finding cites | One call that prints a finding's cited lines | 1.7 h |
| 7.1g | A text-only turn while agents run draws a 3.4 KB forced-continuation message (69 blocking injections; the call after each took 0.20 h in all) | Allow the stop when a background agent is running | 0.2 h |

**Compactions.** s323: 134 in the pipeline sessions (150 with the 16 in the eight update sessions); s321 56 and s322
72 on the reconciled counts. The compaction trigger is about 231K tokens (s321 369K hosted); the post-compaction baseline
grew from 23K to 43K tokens between s322 and s323; the median gap between compactions is 18 minutes and the rate is
1.78 per elapsed hour. 58 of 134 compaction summaries were real summarizer runs (median about 80 s); 76 report under a
second. The first call after a compaction takes a median 18.8 s against a steady 4 s (about 52K uncached prompt
tokens). What fills the window per cycle (s323): step-file Reads 70 KB (5.8 reads, 16%); the re-injected
`instructions` attachment 52 KB (12%); Bash results 36 KB (8%); context-mode recall injected on every prompt 25 KB
(6%); re-injected invoked skills 27 KB (6%). Hooks are not the cost: 0.11 h of hook wall time over 4,542 records,
though they inject 5.5 MB. 343 tool results were denied (155 over the one-read limit, 87 by the post-compact recovery
gate, 44 by the dispatch guard, 14 by the steering budget); the calls' own active time is 0.72 h and the retries 0.52 h,
so about 1.2 h is an upper bound. The always-loaded rulebook of the consumer's `CLAUDE.md` carries two sections the
engine does not need there (7.4e).

**Reaction latency.** From the last agent of a round ending to the lead's next dispatch, edit, gate or commit: 216 events,
8.85 h with each event capped at 10 minutes (uncapped 26.31 h; median 64 s; p90 565 s). That figure is an upper bound on
lead-induced lag: it includes 1.39 h of events with an operator ask pending (7.46 h without them) and 4.17 h in which the
lead was mid-generation. Notifications themselves are not late (agent end to enqueue: median 0.5 s); enqueue to the lead's
first response record has a median 14 s and 3.37 h in all, of which 2.72 h is delivery lag.

**The post-compaction advisor call is kept.** Rule 32's touchpoint R requires an advisor consult before work resumes
after a compaction, and the dispatch hold denies Agent, Write and Edit until it is made. The value reading classified
116 advisor results (the first result after each compaction that had one; the other 18 compactions had no call) in
s323: CAUGHT 49, CAUGHT\* 18 (the advisor asserts the summary is stale and the lead then did not act on it), ADJUSTED 44,
CONFIRMED 3, IGNORED 0, 2 unclassifiable. Of the 49 CAUGHT: JUDG 19 (invented timestamps, wrong brief grammar, a wrong
script argument, a locked decision contradicted), OTHER 14 (memory-held counts and line numbers, draft claims),
SNAP 9, TRUNC 4, GIT 2, and 1 where the snapshot itself was wrong. The clearest costs avoided by the record: an archive
of 1,756 entries gutted in a commit; 65 snapshot lines destroyed; a gate-3 closed on evidence that did not cover the
shipped sha; an operator-locked decision contradicted; a false repair record that would have broken a join; a push
without its commit; invented timestamps in records and in seven briefs. Highest yield is the call that follows a
refused draft (21 of the 29 such calls were CAUGHT: 14 JUDG, 5 OTHER, 2 SNAP). In all 27 cases of snapshot-visible
state the lead had already read the snapshot and held the stale belief anyway, so handing the state is not shown to
remove the error. The no-call control (25 compactions with a dispatch or write before any call) shows no re-dispatch of
running work: 0 of 96 and 0 of 72 dispatches repeated the previous segment's (type, description), which cannot rule
out a rate near 1 in 10 at this N. Latency: the 105 touchpoint-R first calls took 3,411 s (0.95 h, median 30 s); all
209 advisor calls in the 134 segments took 6,973 s (1.94 h, median 30.6 s). Withdrawn: folding R into another
consult, "call the advisor first", and "state hand-off fixes stale beliefs". Kept: load the advisor tool at session
start (1.0 min over 5 starts, section 6.1). s322 was not read for advisor value.

### 7.2 Waiting on the operator

Corrected operator wait is 29.0 h in s321, 12.0 h in s322 and 20.3 h in s323 (section 4). Two instrument corrections
moved it: asks that receive background notifications were charged to the lead as active, and the retro commentary
pause was charged to agent wait (section 10). The class split below is the ask reader's reading of s323's 38 asks
(27 pipeline, 11 in update sessions; 1,368 ask-minutes), made on the earlier clock, so its minutes are
ask-pending minutes and do not sum to 20.3 h.

| Kind | Asks | Minutes |
|---|--:|--:|
| Needed the operator and could not be foreseen | 17 | 562 |
| The same decision, answered the same way before | 10 | 381 |
| The operator took the marked recommendation | 6 | 327 |
| No recommendation marked; the operator chose the status quo | 2 | 95 |
| Not a decision | 3 | 2 |

Pipeline asks are 38%, 30% and 45% genuinely blocking in s321, s322 and s323 (the s321 and s322 labels come from
95 to 150 character question text and are lower confidence). Update-session asks are almost all standing decisions.

- **Presence decides the wait.** Asks sent within 10 minutes of an operator action took a median 2.3 minutes; after an
  hour of silence, 68 minutes. Of 18 waits over 30 minutes in s321 to s323, 17 had no operator prompt in any project
  during them. Waits over 30 minutes that began outside 08:00 to 23:00 ET: 772 of 1,109 minutes in s323 (70%), 794 of
  1,326 in s321, 340 of 473 in s322; the clock band is a poor proxy for presence (the operator answered at 02:03, 02:44
  and 03:50 on various nights). The engine sends no notification: nothing under `core/` or `templates/` calls
  `PushNotification`, and graph's installed `Notification` hook list is empty.
- **Standing decisions** are up to 380 minutes (214 pipeline, 166 update). Three update-session families have long
  histories in graph's answer record: "delete a pristine file upstream removed" asked 28 times before s323 and answered
  yes in most; "extension still additive" 48 times; override drift ("readopt") 23 times, 19 answered with the
  recommended label (regex counts, floors).
- **Proceeding on a marked recommendation** is up to 83 minutes, not the 422 a naive count gives: the lead reaches its
  next operator-gated question within minutes and waits in the same absence.
- **A decision register at step start is worth at most 11 minutes** and is not proposed. Questions come out of lane
  output mid-step.
- **"Keep other lanes moving" is worth about 30 minutes** of s323. After each long ask the lead's next work was the
  answer itself or the next question; only one ask had an independent chain (26 minutes). BL-841's claim 2 and BL-972's
  "held lane" count cannot move.
- **DEFECT.** One 195-minute sprint-review ask quoted the operator's own earlier answers in its question text. Rule 11(a)(i),
  decide when a source settles it, had shipped before s321.
- **DEFECT.** Six s323 asks on one certificate-header premise total 577 minutes; the facts that contradicted the premise
  were in graph's tree (`infra/lib/ingress-stack.ts:111`, `rebalancer/api.py:635`, as reported by the reader).
- **Go-ahead asks s317 to s323: 16 sprint-PR and fix-PR push or merge asks, 586 minutes; the operator took the default in
  16 of 16.** None of the 16 is required by engine text. The sprint-PR merge approval is graph's own rule
  (`docs/operator-runbooks/deploy-protocol.md:28-30`; CLAUDE.md names it a human-approval seam). The fix-forward push asks
  have no mandating text in the engine or in graph's files; the seven s321 asks came from the lead's own reading of the
  nearest rule. The engine mandates only the destructive-operation authorization (`deploy-validate.md:107-109`). Beyond
  those 16, across fire or PUT go-aheads (9 asks, 1,015 minutes, an upper bound because those asks carry other questions),
  push-blocked asks (6 asks, 28.9 minutes) and others, the operator differed from or conditioned the default in 6 of 37.
- **Both hooks test the working tree of the worktree the push runs from.** The two s321 fix pushes ran from the main
  checkout, which held the sprint branch, so the hook tested the sprint tree (2,684-file diff) and not the 13-file fix
  branch. Pushing a fix branch from a clean checkout at its tip makes the unmodified hook test the tip; no engine or graph
  text says to do that (section 6.10).

**What was chosen** (2026-11-20, section 9): a standing-rulings record that the lead and the update skill consult before
asking, with the three update families as its first rows; and proceeding on a marked recommendation with a recorded veto
window where the work under it is cheap to redo. A push notification on a pending ask was offered and not chosen; the
presence finding stands as a measurement. Fix-forward push and merge asks stop being asked (an approval already given for a
fix is not re-asked); the sprint-PR merge approval stays.

### 7.3 The test-suite admission wall

Graph's rule (`docs/coding-conventions.md`, "Suite-Launch Admission and Watchdog") refuses a suite launch unless 8
workers x 1.25 GiB + 16 GiB = 26 GiB fits in measured headroom, and fixes the worker count at 8. On 2026-11-18 from 14:45Z
to 19:27Z headroom sat between 15.6 and 25.9 GiB. The engine has no text about it (0 files under `steps/` or `team-roles/`
mention admission; control: "dispatch" in 42). Each agent polls on its own.

- **Count.** 177 result blocks contain a refusal (162 in 36 subagents, 15 in the two lead sessions; 156 Bash results and
  21 Reads of a file holding a refusal). 134 are distinct (agent, predicate line) refused readings. 134 is a floor: a QA
  agent ran a retry loop (40 tries) whose attempt counters reach 240, and only the tail of the log was ever printed, so the
  true number of launch attempts is not recoverable from transcripts. 123 of the 134 fall on 11-18 between 13:00Z and
  23:59Z. By seat: qa 58, dev-escalated 29, code-reviewer-escalated 19, dev 16, code-reviewer 2, adversary 2, tea 2,
  one each for gate-adjudicator, pm and architect, 3 in the lead sessions.
- **Agent time.** 36 subagents waited on a refused launch for 1,149 agent-minutes (19.2 agent-hours; 560 agent-minutes
  first to last refusal as a lower bound), by story: 1.1 419 (the dev-escalated rework seat 315 of them), 3.1 285 (QA pass
  2, 284.9 minutes), 5.2 222, 1.3 100, 4.1 37, 1.2 26, 1.4 25, unnamed seats 29, 2.1 5. This is agent time, not wall clock.
- **Wall clock.** The step's critical path is three dependency chains: 3.1 to 3.2 at 841 minutes (14.0 h, binding), 1.1 to 5.2
  at 737 and 5.4 to 5.5 at 582. The 3.1 QA seat spent 277 of its 289.9 minutes waiting; fixing that wait alone moves the
  binding chain to 559 and the 737-minute chain binds, so it saves 104 minutes (1.7 h), not 277. The 1.1 dev-escalated rework
  seat (322.7 minutes, 114 attempts) sits on the 737-minute chain; fixing it alone saves 0. Fixing both, which share one
  cause, saves 259 minutes (4.3 h, 31% of the step; the 582-minute chain binds). That is the upper bound with both waits
  fixed and the figure this report carries. Two earlier readings (4.7 h by a critical-path simulation; 1 to 3 h by a
  concurrency join at low confidence) are superseded by it.
- **One dev lost 82 minutes to three single-process suite runs** (28, 27 and 27 minutes, waiting on task notifications; agent
  `a8b075e670fcd22ad`, story 3.2, whose merge was the sprint's last). Two longer idle gaps of that agent (51 and 100 minutes)
  were waits for gate verdicts, not suites.
- **Cause: not established.** The record attributes it, in one lead message, to local model server memory; no
  measurement shows what held the memory. The operator was asked once, 88 minutes in, and answered "keep waiting".
- **Engine items:** check the consumer's suite predicate against measured headroom before the first implementation wave; one
  blocking admission-queue call in place of N agents polling; escalation to the operator after a bounded number of refusals;
  a capacity check at dispatch. **Consumer side (graph's, by coordination, never a write from here):** graph's
  `scripts/pytest_admission.py` measures headroom as free plus inactive memory, so the 16 GiB allowance is margin on top of
  whatever is resident; graph's s322 record shows the local model server resident at 150.3 GiB of 256 GiB (reported by the
  graph session on 2026-11-20, not re-derived here). Graph has since made its admission step down 8 to 6 to 4 workers before
  refusing (PR #1340, `STEP_DOWN = (6, 4)`; 31% of s323's refused readings that carry a headroom figure pass at 6 workers
  and 63% at 4). The engine items are unchanged by it.
- **The wave-plan saving appears only after this wall is fixed**: the second-longest chain's seven late-started stories
  (5.0 to 8.4 h late) wait on the same agents (section 6.6).

### 7.4 Subagent fixed context and dollars

Subagent dollars in s323 are $1,582.3 at the one-hour cache-write rate and $1,333.3 at the five-minute rate (section 3).
At the one-hour rate they are 42% cache writes ($664), 40% cache reads ($633) and 18% output ($285); the cache hit rate is
96.3% (95.6% in s321, 96.3% in s322). Thinking is $81 in all (5% of dollars), and no seat runs above `medium` effort except
the pre-reviewer at `low`, so model and effort bindings are not the lever. Dollars by role: adversary 149 spawns $319;
remediator 258, $298; architect 76, $150; dev-escalated 13, $128 ($9.82 a spawn); tea 66, $119; qa 97, $114; dev 111, $112;
gate-adjudicator 168, $92; code-reviewer-escalated 24, $83; code-reviewer 58, $45.

**Fixed first-request context is $450 of $1,582 (28%)** (s321 $437, 23%; s322 $214, 22%): what each spawn pays to load its
prompt before work, and to re-read it on every later call. The levers (all UPPER BOUNDS):

| # | Found | Change | UPPER BOUND |
|--:|---|---|---|
| 7.4a | A 48.8 KB project-instructions block (graph's `CLAUDE.md`, two rule files, the operator's memory index) loads into 795 spawns in 15 roles; 0 of them read those files again. `omitClaudeMd` is set for 4 of 19 roles (`templates/settings.json.template`) | Set it for every role but the dev seats and the protected-path editor; carry the one path dev needs in its brief | $133 ($159 if the dev seats could also opt out) |
| 7.4b | 1,062 of 1,138 spawns used neither the Skill nor the Agent tool but carry both definitions and a 30 KB skills list | A `tools:` allowlist per role in the rendered agent definition | up to $162; inferred from one allowlisted agent, not tested on a role |
| 7.4c | Six role files are over the limit (`wc -c`: qa 50,457 B, code-reviewer 48,987, adversary 46,895, remediator 39,519, dev 31,678, architect 16,796). The operator's context-mode plugin refuses a single read over 16,384 bytes and the engine tells every agent to read its role file first. In a 40-spawn sample per role, 35 dev, 16 qa, 13 code-reviewer and 13 remediator spawns loaded under half their contract. 0.1184.0 now tells agents to read such files in chunks of at most 16 KB; its first reading is the next sprint | Role files under 16 KB with appendices read on demand make it one call | up to $60 to 70; the compliance half is 0.1184.0's to show |
| 7.4d | Sibling shards cache-write 18 to 37K tokens each because their briefs differ near the top of the prompt | Identical briefs with the shard identity in a first read (depends on rendered briefs, 7.1b) | up to $118, low to medium confidence |
| 7.4e | `templates/CLAUDE.md.template` puts "Project Operations Protocol" (line 37) and "Deployment Commands" (line 55) in the consumer's always-loaded `CLAUDE.md`. On graph those are 11,776 B and 2,681 B of 21,850 B, loaded into every agent that has not opted out and into the lead after every compaction. Nothing in the engine depends on their being there (`deploy-validate.md` and `team-roles/ops.md` contain 0 references to `CLAUDE.md`) | Give the two sections a home the ops seat and deploy-validate read on demand | not sized; the part reaching opted-in roles falls inside 7.4a. Done on graph by the operator's approval on 2026-11-20 (PR #1341): graph's `CLAUDE.md` went from 21,850 B to 10,249 B. The engine item stands so a future install does not put the sections back |

7.4a and 7.4b cut the same first-request tokens; together they are bounded by about $300. Also: 36 agents died on rate
limits ($23.9, 205 agent-minutes); 195 spawns ran under 60 s or made fewer than 5 calls ($66.8, real shard parts; nothing a
script does for free); 80 of 168 gate-adjudicator spawns ended in a plain pass ($40.3; a text match, not checked against the
rules); 63 calls rewrote their cache after a gap over 300 s ($63.3, because no subagent call used the one-hour cache that
graph's settings request). `roll.py` prices every cache write at the one-hour rate (section 10).

### 7.5 Serial tails after parallel rounds

Planning in s323 by real step boundaries: 13.1 h an ask was pending, 18.5 h at least one agent ran (12.0 h of it exactly one;
8.4 h a lone remediator), 8.0 h was the lead alone between rounds (88% the lead model's own turns, 7.1).

| # | Found | Change | UPPER BOUND |
|--:|---|---|---|
| 7.5a | An operator's answer is folded into four documents by one serial agent though it edits disjoint files | One writer per file | 0.85 h |
| 7.5b | A single-document artifact is one lane because the join's node is a file. Seven single-lane rounds showed no cross-section edges | Section-keyed lanes for single-document artifacts | 0.8 h. Of the 6.20 h in `LANES=1` rounds (`serial_tail.py`, committed), the planning reader puts about 1.1 h in single-document single-lane rounds of lone-remediator time; that reader's script is not committed and the sets differ |
| 7.5c | A review shard hung 49 minutes on a permission prompt while four 10-minute waits saw nothing | Each wait prints every undelivered shard's silence; a shard silent two beats is re-dispatched (BL-975's silent-shard rule); the wait script refuses at the first beat on a permanent header failure | 0.7 h per occurrence; 1 in 377 long spawns over three sprints |
| 7.5d | Fence re-derivation, renders and seals run as 23 agent spawns | A script | 0.4 h, $6 |

Kept on evidence: pass 2 in the planning steps, except carry-over evaluation, where it is replaced (section 6.2); party
rounds (465 repaired entries across the four planning steps); the architecture readiness call (4 repaired findings for under
a minute). Not proposed: overlapping the planning steps reaches up to 5.7 h but late operator decisions in requirements were
cited by architecture, so the rework risk is real. Not proposed: running QA alongside code review reaches at most 1.1 h and
wastes QA in the 7 of 17 stories where review fails first. There are no pushes inside implementation (0 against 230 commits);
the pushes that cost time are retro's five (770 s).

**Found efficient, no change:** hook wall time (0.12 h all sprint), notification delivery (0.5 s median), validator re-runs
(none), exact-repeat polls (0.09 h), linters, commits, CI (graph runs none), prompt-cache hit rate, same-spawn repeat reads.

## 8. Ranked levers on wall clock

Ordered by the wall-clock hours of s323 an item can remove (UPPER BOUND), largest first. Rows overlap; the "depends on"
column and the notes below it say where. Hours are s323 in-session hours unless the row says otherwise. "Goal entry" is the
backlog entry that carries the item.

| Rank | Lever | Steps it touches | UPPER BOUND | Depends on | Goal entry |
|--:|---|---|---|---|---|
| 1 | Test-suite admission wall: check the predicate at the first wave, one blocking admission-queue call, escalation after a bounded number of refusals (both waits fixed) | implementation | 4.3 h of the step (259 min; 1.7 h for the QA wait alone, 0 for the dev rework alone); agent time 19.2 agent-h | graph's capacity (its PR #1340 steps workers down); cause not established | BL-1186 |
| 2 | The lead's own time: recovery state injected by hook, rendered briefs, snapshot rows written by the programs that know the change, shell reads folded | all steps; largest in implementation, gates | 7.1a at most 2.7 h; 7.1b 2.3 h; 7.1d 0.86 h; 7.1f 1.7 h; 7.1g 0.2 h (overlapping; the whole of the lead's 28.0 h own time is the ceiling) | the advisor call stays; shared-cache sibling briefs need the rendered briefs | BL-819 |
| 3 | Gates run as programs (one program per gate plus one adjudicator for judgment checks; validators move to the producing step's last action) | gate validation, the six step-closing gates | lead active 300 min to about 60 min, up to 4.0 h; 26 compactions of 134 | three build conditions (below); validators that pass on an unexamined subject fixed first | BL-819 |
| 4 | Implementation gates: gate 1 and gate 2 together on one frozen sha with one merged rework; gate 3 as script arms plus one adjudicator; records-only classes refused at handoff | implementation gates | 145 min (2.4 h) on the binding chain (29 + 116 + 0); with the admission wall fixed 427 min (7.1 h) | gate-3 script arms proven (below) | BL-1186 |
| 5 | Wave plan by real content dependency only; a by-content successor dispatched on its predecessor's tip | implementation build | up to 6 h on the second-longest chain (seven stories started 5.0 to 8.4 h late) | realised only after the admission wall and the lead's call load fall; one dispatch script per story | BL-1186 |
| 6 | Operator wait: standing-rulings record; proceeding on a marked recommendation; fix-forward push and merge asks dropped | requirements, carry-over, sprint review, deploy-validate, update | 380 min standing; 83 min proceeding; 586 min of go-ahead asks over seven sprints, of which the sprint-PR merge approvals stay | proceed-on-recommendation needs the standing-rulings record | BL-972 |
| 7 | Requirements reshaped (brief and architecture-impact out of the reviewed subject; SPEC rendered once; bookkeeping scripted) | requirements | 2.1 h (non-ask wall); up to 300 min operator-stop wall from defect 1 (operator-dependent) | elicitation stays separate | BL-1175 |
| 8 | Retro reshaped (document drafting cut, adjudicators scripted, three-seat party, one push) | retro | 161.6 min to about 60 to 75 min of wall; the per-part bounds sum to about 95 min | none | BL-1189 |
| 9 | Sprint review: integration script at implementation close, retry of errored seats, verdict grammar as a script, no ask for non-scope decisions | sprint review | about 120 min of 361 | the integration script's own cost is counted | BL-1189 |
| 10 | Deploy-validate: scripted spine with four judgments | deploy-validate | 1 to 1.5 h of 4.0 lead-active; 5.0 h of operator wait in an s321-like sprint | consumer side for the fix-forward class | BL-1189 |
| 11 | Stories: strategy ids by script, authoring self-check, the two stall fixes | stories and test strategy | strategy about 55 min and $28.2; self-check about 60 min; stalls 88 min; the reader's whole-list ceiling about 4 h of 9.07 h | not additive | BL-1175 |
| 12 | Carry-over: operator-scoped items only, cluster text out of the reviewed document, pass 2 replaced | carry-over evaluation | Pass 2 replaced only (adopted): about 15 min of wall in a normal sprint, up to about 100 in one like s322 (the `value-carryover-p2` reader's estimate, not measured). 60 to 75 min realistic wall and $80 to $95 assume passes 1 and 2 also merge into one terminal pass, which was not adopted | pass 1 merge not decided | BL-1175 |
| 13 | Route and session start: resume pre-flight script, fresh-start file | route, handoff | 0.35 h per sprint | none | BL-819 |
| 14 | Architecture: record-format arm before the nonce, changelog/index/commit script | architecture | about 50 min | none | BL-1175 |
| 15 | Serial tails: one writer per file, section-keyed lanes, silent-shard rule, fence scripts | planning | 2.8 h (0.85 + 0.8 + 0.7 + 0.4) | none | BL-1175, BL-716, BL-975 |
| 16 | Update flow as one driver | update sessions (outside the 75.4 h) | lead active 8.12 h to about 2 to 3 h; frees lead sessions, not sprint clock | none | BL-1190 |
| 17 | Subagent dollars | all steps (dollars, not wall) | about $300 of $1,582.3 | rendered briefs for shared caches | BL-1187 |

**Build conditions for rows 3 and 4.** Each scripted arm is proven against a seeded failure and a near-miss; the program's
output is diffed against s323's hand-written entries; the two validators that pass on an unexamined subject
(`validate-escalation-status-vocabulary` skips entries with no Status line; `validate-locked-anchor` PASS EXAMINED NOTHING)
are fixed first. The same conditions bind the rule-table checks proposed for implementation gate 3 (19, 10, 8, 4, 7, 3 after
proof).

**Requirements and attribution.**

- Every redesign that replaces a file the lead reads (a gate run as a program, a split step file, a scripted late step)
  still writes the pipeline's own boundary records: the snapshot's `current_step_file` sets and the gate open and close
  records. The extractor is changed to take step and gate boundaries from those records and sprint boundaries from the
  consumer's sprint-close commits, and that change exists before the next sprint's reading is taken. Because every item
  lands before the next graph sprint (section 9a), that sprint measures the items together: the per-step tables attribute an
  effect to a step, not to one change inside it.
- The BL-1186 held-label check (a held, deferred or operator-labelled item carries a resolvable operator source) needs
  BL-972's standing-rulings record and proceed-on-recommendation to exist when it runs.
- Shared-cache sibling briefs (7.4d) need the rendered briefs (7.1b).
- Proceed-on-recommendation needs the standing-rulings record.
- All items land before the next graph sprint (section 9a), so no build order is required.
- The wave-plan saving (row 5) appears only after the admission wall (row 1) is fixed and the lead's call load falls.
- The five engine build briefs are held at the lead until the operator's session relays the outcome of this analysis.

**Withdrawn or not additive.** The batch 259 update's opportunity 2 (declare operator decisions at planning and batch them)
is withdrawn (11 minutes). Its opportunity 3 (serial adversary or remediator): the adversary half is done; the remediator half
is worth about 1.7 h, not 3.7 h. BL-1175 item 3's saving is about a tenth of its estimate (the readiness and trace calls took
about 2 minutes in s323). BL-1167 (the lead's `git push`) has no subject inside implementation.

## 9. Decisions

### 9a. Operator decisions (2026-11-20)

1. **Scope.** The analysis covers the entire pipeline, every step analysed part by part; scope for the build is all engine-side
   groups.
2. **Method is durable.** The method is a runbook under `docs/plans/`, not a memory note, because the analysis is run again;
   readers are committed with one entry point; the report's first lines point at the runbook. A push-time check that a
   pipeline-efficiency report declaring itself under the runbook has a section per step file, the list derived from the step
   directory and not the manifest's wildcard, is filed with its own backlog id and a false-positive measurement over the four
   existing reports as a build condition; it proves coverage, not quality.
3. **The instrument takes step and gate boundaries from what the pipeline declares** (snapshot `current_step_file` sets, gate
   open and close records, sprint-close commits), not from step-file reads or a hand-kept date list. The runbook takes the step
   list from the engine versions the analyzed sprints ran, united with the current one, states versions per step, and names
   the consumer's extensions and overrides as part of each step's text.
4. **Operator waits.** Build the standing-rulings record and proceed-on-recommendation. A push notification on a pending ask
   was offered and not chosen. The engine-update pace is kept as it is. Graph-side items are handled by coordination with a
   graph session.
5. **BL-1166 item 3 (capture-commit check): withdrawn.** The check already exists as a warning (`validate-handoff-evidence.sh:1617`;
   the comment at `:614` says the warning is deliberate); the head-tree comparison fires on 54 of 59 s323 plans (499 lines) and
   4 of 5 unmatched samples were false (tracked `.pyc` counted as code; a `(+dirty)` head; two captures citing the sprint base
   by design). The replacement is a new shape, not the filed item: refuse head-missing, placeholder and section-empty after
   fixing the capture-unresolved tokenizer (7 of 7 flagged tokens were false: prose tokens with a slash); evidence thin (3 stories).
6. **BL-1175 item 2 (tier per-story party and elicitation by routing tag): closed on its own condition.** The entry ships only
   if survivors cluster in tagged stories. s323: tagged 7 stories, 6 survivors, 0 CRITICAL; untagged 11 stories, 11 survivors,
   2 CRITICAL; the three per-story CRITICALs are in untagged 2.2 and 5.1; party critical-plus-major per tagged story 16.0
   against 10.0 untagged; the first pass 1.4 against 1.2. The tag predicts downstream cost (67% of implementation and review
   dollars), not planning yield. s321 and s322 were not read by tag. BL-1175 item 1 is untouched.
7. **BL-819 item 6 (split `gate-validation.md` into sections): replaced** by "run each gate as a program" under the same goal,
   with the three build conditions of section 8.
8. **"I won't run a graph sprint until all of the backlog items from this analysis are built and pulled to graph."** This is the
   operator's statement of 2026-11-20 about when the next sprint runs. It is not a pull authorization and nothing here dispatches
   a pull. It fixes the measurement shape of the next sprint (section 8).
9. **The five engine build briefs are held** at the lead (ai-dlc-1d) until this session relays the outcome.

### 9b. Decided from evidence under the standing rule (reported, not asked)

| Subject | Decision | Evidence in a line |
|---|---|---|
| Post-compaction advisor call (Rule 32 touchpoint R) | Kept unchanged, with the dispatch hold | 116 calls read: CAUGHT 49, CAUGHT\* 18, ADJUSTED 44, CONFIRMED 3, IGNORED 0; of 49: JUDG 19, OTHER 14, SNAP 9, TRUNC 4, GIT 2, snapshot-wrong 1; 0.95 h for the 105 R-timed calls |
| Carry-over adversarial pass 2 | Replaced by one final pass scoped by the document's diff from the analyst draft, free to read anything, plus a mechanical join of every pass-1 CRITICAL or MAJOR to a repair entry | 25 MAJOR read: 21 repair-written, 3 repair-touched, 1 a dropped pass-1 finding; the s320 capital-path catch was repair-written text (five blob versions) |
| Elicitation | Kept as a separate round in all four planning steps; a commit after each review round so the next sprint can decide | Unique shipped catches in every step, including CRITICALs on capital paths (requirements s321 `08.md` F-1; architecture s321 `3.md` F-1); the merge proposals rest on proxies that failed their own control |
| Retro party mode | Shrink to three seats (test architect, QA, dev) | Strict party-only persisted survivors 0 (s321), 3 (s322), 0 (s323); in s323 the lead's facts sheet already held every changed item |
| Retro | Cut the 7-analyst document drafting (keep the finding-class shard), the gate[retro] adjudicators (0 FAIL in two sprints; script the checks and add `validate-artifact-paths`), the 7b next-inputs bundle (no reader); script open and close, mutations, commit and post-merge rotation into one push; move the operator commentary pause after the PR push; route the steerability audit's recurring FAIL to the engine; fix the contradictory `rm -rf` of retro-artifacts; cut sprint-ship counters unless a validator names them | Section 6.11 |
| Deploy-validate | Keep as a scripted spine plus four judgments; visual confirm merged into browser smoke; quiet-window PASS requires a controlled event; fix branches pushed from a clean checkout at their tip; an approval already given for a fix is not re-asked; the sprint-PR merge approval is graph's seam and stays | Sections 6.10 and 7.2 |
| Gate validation | One program per gate plus one adjudicator for judgment checks (3, 27, 29, core-layer); validators move to the producing step's last action; `gate_types` on consumer extension checks | Section 6.8 |
| Implementation gates | Keep gates 1 and 2, dispatched together on one frozen sha with one merged rework; gate 3 as script arms (22, 16, 5, the vocabulary half of 2 now; rule table for 19, 10, 8, 4, 7, 3 after proof) plus one adjudicator for 1, 11, 11a and the hard-block half of 2 | 60 of 225 gate-3 verdict rows (27%) restate script output the lead already held; all 8 FAILs are on judgment checks (1, 11, 11a) |
| Implementation build | Wave plan by real content dependency only; one dispatch script per story; the dev runs the handoff check as its last action; commit run summaries, not logs; per-story bookkeeping script; cut dead step sections | Section 6.6 |
| Test-suite admission wall | A binding item in implementation: engine checks capacity, one blocking admission-queue call, escalation | 4.3 h of step wall with both waits fixed; 134 distinct refusals (floor) |
| Sprint review | Keep the five-role panel, one adversary pass per composed tree, fix re-review; add the integration script at implementation close; retry errored seats; script the gate's verdict-line grammar; operator decisions raised in the step go to the deploy-validate list except scope; cut sprint-review-next | No role can go cross-only without loss in three sprints; sprint-review-next has 0 reads in 176 lead transcripts |
| Stories | Keep party, p1, p2 and the gate; script strategy ids and case rows; authoring self-check script; shipped brief generator; fix the two stalls; enforce or delete the Kind vocabulary | Section 6.5 |
| Requirements | Brief and architecture-impact out of the reviewed subject; render SPEC once after the serial tail; script bookkeeping passes and mechanical pre-checks; settle cheaply checkable premises in the authoring dispatch; record post-convergence MINORs, do not repair them; split the 1,015-line NFR shard | Section 6.3 |
| Architecture | Keep the cycle; pre-nonce script arm for record-format checks; changelog/index/commit script; snapshot-update refuses a trim that destroys lines; fix the step-label leak. The "size the lane to 41" saving is withdrawn | 61 and 41 are different populations; 40 of the 61 needed edits |
| Carry-over evaluation | The analyst evaluates operator-scoped items only and the join waits for completion; the 262 unscoped items stay in the backlog; live reads dispatched with the party round; sections 4-6 edits before fences; an operator-stood decision is not re-decided by a repair | Section 6.2 |
| Route, handoff, session | Resume pre-flight script (keeps checks 5, 6, 7, whose failure text was not printed in s321 to s323); fresh-start path in its own file; snapshot budget enforced at write; handoff is one beat then stop and dispatches nothing new; the guard treats a live backgrounded push as pending; recovery hand-off by state excerpt still proposed, needs a scratch-copy rehearsal, and is not claimed to fix stale beliefs | Sections 6.1 and 6.12 |
| Update flow | One driver that hands the model only real decisions; ask only on conflict; detectors run once; untangle and mask sections out of the always-loaded file | Section 6.13 |
| Sprint-review panel, dev evidence checklist, session-start checks | Kept | A zero over three sprints is a floor; the checklist's 10 zero-finding items stay (sections 6.6, 6.9) |
| Minor steps | bug-investigation and artifact-consolidation kept; five never-run steps are unreachable for graph, not cut; bug-investigation's fixed adversarial output path overwrites prior files (defect) | Section 6.14 |

### 9c. Proposed and not adopted

| Proposal | Why not |
|---|---|
| Merge or fold the elicitation round into the party round, or run them concurrently | Merge proposals rest on proxies that failed their own control; unique catches in every step. The per-round commit is the build item that lets the next sprint decide |
| Remove the elicitation round and its repair (up to $60.8 and about 101 min in stories) | Same |
| Fold the SM and dev seats into the tea and architect briefs in stories | 12 sole-source CRITICAL or MAJOR blocks lost unless their lens is folded in |
| Tier per-story party and elicitation by routing tag (BL-1175 item 2) | Closed on its own condition (9a item 6) |
| A capture-commit check refusing head-tree mismatch (BL-1166 item 3) | Withdrawn (9a item 5) |
| Splitting `gate-validation.md` into sections (BL-819 item 6) | Replaced by gates as programs |
| Folding advisor touchpoint R, calling the advisor first, "state hand-off fixes stale beliefs" | 9b advisor row; in all 27 snapshot-visible cases the lead had already read the snapshot |
| Cutting the dev evidence checklist's zero-finding items | A zero is a floor; 10 candidates remain on the record |
| Cross-only sprint-review seats for any role; a tea-only panel | Loses sole-raised fixed defects (one high-consequence D8 is raised by dev and qa only); a tea-only panel covers 12 of 13 in s323 and fails in s321 |
| Size the architecture serial-repair lane to 41 | Different populations; 40 of 61 needed edits |
| A decision register at step start | At most 11 minutes |
| Presence-aware routing as its own mechanism | Adds nothing beyond standing rulings plus proceed-on-recommendation (independent chains total about 30 minutes) |
| A push notification on a pending ask | Offered; the operator did not choose it |
| Overlapping the planning steps | Up to 5.7 h, but late operator decisions in requirements were cited by architecture |
| Running QA alongside code review | At most 1.1 h and wastes QA in 7 of 17 stories |
| Merging carry-over passes 1 to 3 into one terminal pass | Not decided: only pass 2 is replaced |
| Cutting the five never-run minor steps | Unreachable for graph, saves nothing measurable |

## 10. Instrument

The instrument is `extract.py` and its siblings (`roll.py`, `lead_time.py`, `analyze.py`), at the batch 261 C5 blobs.

| Defect | Tier | Size | Corrected in this report |
|---|---|---|---|
| Step attribution by last step-file read: the label moves only on a whole Read of a `steps/*.md`, and a Read of an earlier step file (a lookup) moves it back (`extract.py`, the step-label assignment in `scan()`) | DEFECT | Known leaks: 3.41 h of requirements charged to carry-over-evaluation (SET `current_step_file` at 11-17T03:40:26, which includes a 198-minute ask); ui-direction to implementation 0.22 h, 7 spawns, $18.5; sprint-review to implementation 1.03 h, 4 spawns (gate 3 of stories 2.1 to 2.3); sprint-review to deploy-validate 0.19 h (s323) and 0.23 h (s322); s321 stories to implementation 2.27 h | Yes, by the lead's own declarations: 12 `snapshot-update.sh --set current_step_file` events, 1 planning gate close, 3 `gate-checkpoint.sh --nonce implementation-...` spans |
| Operator wait charged only where a gap exceeds 300 s, so an ask that receives notifications is charged to the lead as active; the retro commentary pause is charged to agent wait (`extract.py:374-377`) | DEFECT | s321 +4.64 h (2.40 from active, 2.24 from long agent wait, less 0.54 inside the fork copies); s322 +1.68 h (0.77 and 0.91); s323 +2.46 h (all from active) | Yes: whole span `tool_use` to `tool_result` of every `AskUserQuestion`, plus the pause flag to the next human prompt |
| One forked session counted twice | DEFECT | s321 deploy-validate 0.95 h, 45 lead calls ($2.86 sonnet-priced); no other sprint | Yes |
| Idle tail after a session's last tool call counted | DEFECT | s321 9.91 h (one session 7.18 h, including 6.26 h before a final prompt; 1.48 h; 1.25 h); s322 1.24 h; s323 0.00 | Yes |
| `roll.py` prices a cache write at the one-hour rate | DEFECT | Every s323 subagent call wrote five-minute cache; about $249 a sprint on s323 | Dollars given both ways; the billed rate is not established |
| `lead_time.py` still has the old clock (BL-1174) | NOTE | Active holds waits under 300 s (15.36 h of s323) | Not recomputed |
| Sprint edges are a hand-kept date list | NOTE | | Edges used as published |

**What the corrected tables do not fix.** Leaks with no declaration (no `current_step_file` set, no gate close) are not found;
16 explicit markers were found (12 sets, 1 gate close, 3 nonce spans). 24 of 3,040 spawns in s321 to s323 have no resolvable
owner and keep their old step. The gate-versus-step split of the s322 architecture party (about 21 minutes of lead time) is not
made: the party sits under `gate-validation[architecture]`, which is ARCHITECTURE once step and gate are merged. Lead dollars
are not re-priced after the relabel. The retry loops hide attempts (section 7.3). One reader's lead dollar share for sprint
review ($3.02) is not reproduced by any pricing tried; the figure used is `roll.py`'s ($279.74 in s323: subagents $225.54
plus the lead seat's token-equivalent $54.21).

**Residual risk.** The report's per-step hours are exact to the extent that the lead's own declarations mark the step
boundaries. The extractor is to take step and gate boundaries from those declarations (9a item 3); until that change exists the
corrections of this section are applied by hand, per the runbook.

## 11. Corrections to earlier published figures

Readers of main may hold these figures from the previous version of this report or from older reports.

| Figure as published | Corrected | Why |
|---|---|---|
| s321 in-session hours 111.0 | 100.1 | 0.95 h fork copies and 9.91 h idle tail removed |
| s322 in-session hours 66.4 | 65.2 | 1.24 h idle tail removed |
| Operator wait s321 24.9, s322 10.3, s323 17.9 h | 29.0, 12.0, 20.3 h | asks with notifications and the retro pause were not counted |
| Long waits on agents s321 34.8, s322 19.7 h (s323 8.9 unchanged) | 22.5, 17.5 h | the same moves, and the relabel |
| Lead active 51.3 / 36.4 / 48.6 h | 48.6 / 35.7 / 46.2 h on the old definition; the class split of section 4 replaces it | |
| s323 lead's own work 33.3 h (model 25.2, tool 5.8, idle 2.3) | 28.0 h own work (model 22.4, tool 5.6) plus 2.9 h idle with no agent running; 30.8 h on the old definition, which counted that idle as own work | the 2.5 h moved to operator wait |
| Hours per story s321 4.4, s322 8.3 | 4.0, 8.2 | |
| s321 lead calls 7,127; compactions 57 | 7,082; 56 | the forked session |
| s323 per step: carry-over 11.8, requirements 13.5, sprint review 11.1, deploy-validate 5.3, ui-direction 0.3 h | 8.4, 16.9, 9.9, 5.5, 0.1 h | relabel at declared transitions |
| s321 per step: stories 19.7, implementation 22.4, deploy-validate 29.0, retro 3.1 h | 17.6, 24.5 (build 16.6 plus gates 7.9), 28.0, 1.8 h | |
| s322 per step: implementation 13.0, sprint review 2.3, deploy-validate 3.5, retro 5.3 h | 13.1 (8.0 + 5.1), 2.0, 3.7, 4.1 h | |
| Planning 40.8 / 36.9 / 39.6 h | 38.6 / 36.9 / 39.6 h | s321 relabel |
| Refused suite launches: "261", "206 between 13:00Z and 24:00Z", control token in 5,372 files | 177 result blocks, 134 distinct refused readings (floor), 123 of the 134 between 13:00Z and 23:59Z on 11-18 | 261 is not reproduced under any definition tried; 373 was the raw line count of payloads stored twice |
| Memory wall "1 to 3 h / 4.7 h" | 4.3 h with both waits fixed; 1.7 h for the QA wait alone | chain simulation; "12 log calls at 110 s" was wrong |
| "Agents waited a median 7.6 minutes; 36 of 88 over 10 minutes" | By gap type, median minutes: dev to gate 1 1.9; gate 1 to gate 2 6.6; gate 2 to gate 3 15.4 (7 of 13 over 10 minutes); gate 3 to close 17.1 (15 of 15); all 92 gaps median 6.6, 33 over 10 minutes | the earlier figure mixed types |
| First-pass review findings "55" (30 evidence or bookkeeping, 5 code) | 47: 18 TEST, 15 EVIDENCE, 8 BOOKKEEPING, 5 CODE, 1 unclassed (23 evidence or bookkeeping) | 55 counted list lines (80 raw items); 47 counts findings. An independent recount of headings gives 47 pass-1 findings and 6 later |
| Subagent dollars "$1,580 a sprint" | $1,582.3 at the one-hour cache-write rate and $1,333.3 at the five-minute rate; s321 $1,879.5 / $1,648.6; s322 $992.7 / $881.2 | billed rate not established |
| Lead compactions 134 | 134 in pipeline sessions; 150 with the eight update sessions | |
| Compactions per elapsed hour 0.51 / 1.08 / 1.78 (s321, s322, s323) | 0.56 / 1.10 / 1.78 | the denominators are the reconciled in-session hours (100.1, 65.2, 75.4) and s321's 56 compactions |
| Lead-lag 8.85 h | An upper bound that contains 1.39 h of operator-ask events (7.46 h without) | |
| "3 x 28 minutes" dev waits | 28, 27 and 27 minutes on one dev (agent `a8b075e670fcd22ad`), plus two waits for gate verdicts | |
| s323 "compacted once every 18 minutes" | a median 18 minutes apart (1.78 per elapsed hour) | |
| s323 "the fastest and cheapest sprint per story measured" | of s318 to s323 (s317's corpus is truncated) | |
| "BL-1005 and BL-975 read zero populations in s323" | BL-1005 only; BL-975 read 44 deaths, notice median 3717 s to 832 s | |
| Sprint-review dollars $236 / $101 / $280 | unchanged; they are subagents plus the token-equivalent lead seat: 209.09 + 26.54, 82.08 + 18.68, 225.54 + 54.21 | |
| BL-716 "Correction: the single-lane class is 1.1 h, not 6.2 h" | a different class: of the 6.20 h in `LANES=1` rounds, 1.1 h is single-document single-lane rounds, from a reader whose script is not committed | |
| BL-1186 item 4 "Reach: 6.4 h protected" | a real saving of up to 6 h on the second-longest chain, realised after the admission wall and the lead's call load fall | the seven stories started 5.0 to 8.4 h late |
| Architecture "size the lane to 41" saves 10 minutes | withdrawn | different populations |

## 12. Not established and not measured

Each line says whether the measurement was available.

- **What held the memory on 2026-11-18.** Not available from the record: one lead message names the local model server.
- **Whether five-minute or one-hour cache writes are billed.** Available only from the provider's billing record, which is not in the corpus.
- **True count of suite launch attempts.** Not recoverable: retry loops print only their tail.
- **Whether the recovery state excerpt is sufficient.** Available: needs a rehearsal on a scratch consumer copy; not run.
- **Whether elicitation can merge.** Available next sprint: per-round commits will show it.
- **The advisor's value in s322.** Available; not read. 92 later advisor calls in the same segments (other touchpoints) are not classified; the CAUGHT and ADJUSTED boundary is judgment (about 12 ADJUSTED rows lean CAUGHT).
- **Uniqueness of party and elicitation catches in s323.** Not available: s323 has a single planning commit.
- **Lead dollars per step after the relabel.** Available (token counts exist); not done.
- **Residual step-label leaks with no declared transition; the gate-versus-step split of the s322 architecture party; 24 spawns with no owner call.** Not available from the record.
- **Role-contract text left unread by agents.** Byte counts of what loaded were read, not compliance.
- **The `tools:` allowlist saving** is inferred from one allowlisted agent; **the shared-cache saving** assumes byte-identical briefs and a warm cache. Neither was tested.
- **The repair-introduced share of pass-2 findings** is a judgment from finding headings; **the ask classes for s321 and s322** come from truncated question text.
- **The wall-clock of 40 backgrounded pushes and 47 backgrounded suite runs;** which pre-push steps took retro's 453 s push. Graph's hook content was not opened.
- **s318 to s320 under the instrument corrections.** Available; not re-run.
- **Other consumers.** Graph is the only consumer transcript corpus; use of the minor steps elsewhere is not available.
- **No s323 reading exists** for BL-515, BL-695, BL-811, BL-913, BL-846, BL-847 or BL-843.
- **Whether the lead's habit of asking fix-forward push questions came from graph's auto-memory or earlier verbal rulings.** Not derivable: the transcripts show only the asks.

## 13. Reproduce

The method as a runbook: [`../plans/pipeline-efficiency-analysis.md`](../plans/pipeline-efficiency-analysis.md). The readers and
their findings are committed under
[`pipeline-efficiency-s323-opportunities-b261/`](pipeline-efficiency-s323-opportunities-b261/); its
[`README.md`](pipeline-efficiency-s323-opportunities-b261/README.md) lists every script, which reader produced it, how to run
it, and which carry hard-coded scratchpad paths that must be replaced before a re-run. No transcript data is committed;
two first-round readers' scripts (planning and implementation) were never recovered.

```
OUT=<scratch dir>; export EXTRACT_WIN_END=2026-11-20T04:20:00Z
A=docs/analysis/pipeline-efficiency-s317-s318/scripts; B=docs/analysis/pipeline-efficiency-s317-s320/scripts
python3 -I $B/extract.py $OUT && python3 -I $A/spawns.py $OUT && python3 -I $A/analyze.py $OUT
python3 -I $B/roll.py $OUT > $OUT/roll.txt        # must equal pipeline-efficiency-s323-complete-b261/out/roll.monotone-clock.txt
cmp $OUT/roll.txt docs/analysis/pipeline-efficiency-s323-complete-b261/out/roll.monotone-clock.txt
```

Then apply the corrections of section 10 with `steps/reconcile/` (`extract_dump.py`, `report_b.py`, `build_true.py`,
`a3_gaps.py`, `c_admission_waits.py`, `refusals.py`); `steps/reconcile/B_tables.txt` is the committed result.

| Directory under `pipeline-efficiency-s323-opportunities-b261/` | Reader | Findings file |
|---|---|---|
| `scripts/lead-time/`, `out/lead-time/` | the lead's own time | `findings/hand-lead.md` |
| `scripts/tokens/` | tokens and dollars | `findings/hand-tokens.md` |
| `scripts/asks/`, `out/asks/` | operator asks | `findings/hand-asks.md` |
| `scripts/late-steps/`, `scripts/tool-runtime/`, `out/late-steps/` | late steps and tool runtime | `findings/hand-tail.md` |
| (not recovered) | planning timeline | `findings/hand-plan.md` |
| (not recovered) | implementation timeline | `findings/hand-impl.md` |
| `findings/` | record ledger and status of entries | `findings/hand-status.md` |
| `steps/route-handoff-session/` | route, handoff and session | `findings/step-route.md` |
| `steps/carry-over-evaluation/`, `steps/carryover-p2-value/` | carry-over evaluation | `findings/step-carryover.md`, `findings/value-carryover-p2.md` |
| `steps/requirements/` | requirements | `findings/step-requirements.md` |
| `steps/architecture/` | architecture and ui-direction | `findings/step-architecture.md` |
| `steps/stories-test-strategy/`, `steps/elicitation-merge-value/` | stories and test strategy; elicitation | `findings/step-stories.md`, `findings/value-elicitation-merge.md` |
| `steps/implementation-build/` | implementation build | `findings/step-impl-build.md` |
| `steps/implementation-gates/` | implementation gates | `findings/step-impl-gates.md` |
| `steps/gate-validation/` | gate validation | `findings/step-gate-validation.md` |
| `steps/sprint-review/` | sprint review | `findings/step-review.md` |
| `steps/deploy-validate/` | deploy-validate | `findings/step-deploy.md` |
| `steps/retro/`, `steps/retro-party-value/` | retro; party mode value | `findings/step-retro.md`, `findings/value-retro-party.md`, `findings/agent-a26d6adaed0db2.md`, `findings/agent-aaff5e2b7c9bde.md` |
| `steps/update-and-minor-steps/` | update flow and minor steps | `findings/step-update-minor.md` |
| `steps/advisor-r-value/` | advisor after compaction | `findings/value-advisor-r.md` |
| `steps/open-items/` | eight open items | `findings/value-open-items.md` |
| `steps/reconcile/` | reconciliation of the instrument | `findings/reconcile.md` |
| (findings only) | tip adversary over the draft; the previous builder's final text; plugin-docs reading | `findings/tip-adversary.md`, `findings/agent-a486d57c59b4ec.md`, `findings/agent-a8eb666cad2276.md` |
