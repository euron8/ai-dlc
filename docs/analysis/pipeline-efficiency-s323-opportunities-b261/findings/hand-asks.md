# Findings of reader `hand-asks` (recovered verbatim from its transcript agent-ahand-asks-cf028c5d69e600f3.jsonl)

## FINAL-TEXT 2026-11-20T10:51:25.656Z

**Summary (s323; my ask/prompt data and per-ask class labels are in `/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/c10-ask/x.tir1/`)**
1. "Keep other lanes moving" is capped at about 30 min of s323's 17.9 h, which is why the prose rules measured null. After each long ask the lead's next work was the answer itself, or the next question. Only #15 had a real independent chain, 26 min and 15 of 17 dispatches.
2. Class stability across sprints is mixed. Update-session asks are almost all standing decisions every sprint (9 of 11, 9 of 11, 8 of 11 are standing or taken-recommended). Pipeline asks are 38%, 30% and 45% genuinely blocking.
3. Presence decides the wait. Asks sent within 10 min of an operator action took a median of 2.3 min in s323, against 68 min when the operator had been silent over 60 min. 17 of 18 waits over 30 min (s321–s323) had no operator prompt anywhere in `~/.claude/projects` during them. The engine sends no notification.
4. Upper bounds, s323, with overlap removed: standing rulings 380 min (214 pipeline, 166 update), ask-and-proceed about 83 min against a naive 422, step-start register at most 11 min. The 300-min ask #15 is worth about 50 min, not 300.
5. DEFECT: ask #24 (195 min) cites the operator's own earlier answers in its question text. Rule 11(a)(i) (decide when a source settles it) shipped in 0.970.0 on 2026-10-30, before s321's first pull. The lead asked anyway.

**Population, one line per gap**
- Population: every lead `AskUserQuestion` `tool_use` paired with its `tool_result` by id (deduplicated across resumed sessions).
- Counts: s321 56 and s322 30, with the `s322`/`s323` edges at 11-13T08:00Z and 11-20T04:20Z. `tools.csv` reads 57/30/38. I did not find the brief's "25" for s322 or the one extra s321 ask.
- s323 has 38 asks: 27 pipeline and 11 pre-step. The brief's 8 pre-step asks would be those 7 over 5 min plus one; I did not pin it.
- My pipeline ask-wait over 300 s is 19.4 h; `op_wait` is 17.9 h.
- Errored or rejected asks (#7, #31, #35) write no "answered" text, so those operator actions are missing from my presence data.

**Versions graph ran.** Rule 11(a)(i) was in force throughout. BL-972's (ii) rule (0.1171.0) and `dispatch, then ask` (0.1092.0) were in graph's reach only as far as pulled: reconciles to 0.1096 on 11-12, 0.1128 on 11-14, 0.1167 on 11-19. (ii) was never in graph's s323 engine.

**s323 asks over 30 min.** Times are ET. No notification was sent for any of them, and no operator prompt appeared in any project during any of them. R = marked Recommended.

| # | Wait | Step | Asked | Chosen | Blocked during wait | First 5 min after | Class |
|---|---|---|---|---|---|---|---|
| 1 | 04:33→07:01, 148 | carry-over | 4 Qs: gas ceiling on standalone collect, gas-read failure path, native-ETH wall split, allowlist-fire timing | R, R, wall 1 rides with pipeline (unbadged), R | 2 lanes done 09:41/09:50Z, idle 131 min | recorded finished lanes, next ask 2 min later | d (b on 3 of 4 Qs) |
| 14 | 22:43→02:03, 200 | carry-over | byte-pin re-baseline; fire order; proxy cert header | authorize; keep order; "forward cert and fire". All unbadged. | 1 lane done 03:44Z, idle 199 | resolved HARD_BLOCK, dispatched "Fold answered OQs" (names the answer), 45 dispatches in 34 min | d |
| 15 | 02:36→07:36, 300 | requirements | header-name premise for FR-19 (3 options); 4 veto lines | both R | 14 repair lanes done 07:37–07:53Z, idle 289 | joined, dispatched 12 adjudicators whose prompts do not name the answer, then 4 lane remediators; next ask (#16, unbadged) 26 min later | b (marked, taken) |
| 23 | 12:58→14:26, 88 | implementation | memory wall: stop mlx-serve / lower allowance / keep waiting | keep waiting, unbadged | 3 lanes running, none finished, 0 idle | SendMessage to lanes, checked 5.5 | b (unmarked status quo) |
| 24 | 23:29→02:44, 195 | sprint-review | build 3 held stories / defer / operator's | build all three; text says "matches your own answers" | 1 lane done 04:36Z, idle 188 | verified fix commit, read `handoff.md`, session ended | c |
| 26 | 04:24→06:33, 129 | update | 3 override drifts (readopt/reaffirm/retire) | READOPT ×3, all R | nothing running (update flow is serial) | ran the merges, asked #27 immediately | c |
| 29 | 13:23→14:11, 48 | sprint-review | byte-pin second re-baseline; APP_ENV arm; 2 veto lines | "explain in plain language"; ship armed; both R | 2 lanes running to 19:22Z, 0 idle | dispatched "Fix step-3 findings", asked #30 | d |

**The other 31 s323 asks (under 30 min):**
- #0 scope confirm is e.
- #2–#5 are a 4-ask burst after #1 (3, 1, 0 and 20 min); #2 and #4 are b, #3 and #5 are d.
- #6, #8, #9, #11, #22, #25, #27 are c: readopt, pristine deletes, merge-keep-both.
- #10, #12, #28 are b.
- #7, #13, #16, #17, #19, #20, #30, #32–#34, #36, #37 are d.
- #21 is c (a within-sprint standing answer: "cap every gas-price signing site", asked piecemeal at #16, #17, #19, #21).
- #18 is b-unmarked.
- #31 and #35 are e.
- Full per-ask rows are in `asks_enriched.json`; part 2 can print them.

**Classes, s323 (38 asks, 1,368 ask-min)**

| Class | Asks | Min | Recommended taken |
|---|---|---|---|
| a, foreseeable | 0 | 0 | – |
| b marked and taken | 6 | 327 | 6 of 6 |
| b unmarked or status quo | 2 | 95 | – |
| c standing | 10 | 381 | 6 of 10 |
| d genuinely blocking | 17 | 562 | 1 of 17 |
| e not a decision | 3 | 2 | 0 |

Precedence is d > a > c > b > e, so an ask takes its hardest question's class. These are my reading of the question text.

Standing-ruling evidence, from `operator-answers-history.md` before 2026-11-13. These are regex counts, so floors.
- Readopt family: 23 earlier asks, 19 answered with a Recommended label.
- Pristine-file deletion: 28 earlier asks, mostly "Yes, delete".
- Still-additive: 48 earlier asks.
- The byte-pin family is mixed, so #14's Q1 is not counted as standing.

**Time of day and presence**
- Waits over 30 min that began outside 08:00–23:00 ET:

| Sprint | Minutes | Share |
|---|---|---|
| s323 | 772 of 1,109 | 70% |
| s323, pipeline only | 643 of 979 | 66% |
| s321 | 794 of 1,326 | 60% |
| s322 | 340 of 473 | 72% |

- The 08–23 band is a poor proxy for presence. The operator answered at 02:03, 02:44 and 03:50 on various nights.
- Operator action before each long ask: #15 34 min, #1 74, #14 129, #24 169, #23 193, #29 283. Five of the six long pipeline asks were sent into absence.
- Control: s321 #47 shows 3 operator prompts in `llm-gateway` during its 264 min, so the scan can fire. It covers Claude Code transcripts only.
- The engine's notification handling is absent. `PushNotification` appears in `core/` only in a deferred-tool roster in `core/fixtures/advisor-gate-deny/lib.sh:388`, a fixture. `templates/settings.json.template` has no `Notification` key (0 hits; `PostCompact` control reads 1). Graph carries `"Notification": []`.

**Cross-sprint share of asks**

| Sprint | a | b marked | b unmarked | c | d | e |
|---|---|---|---|---|---|---|
| s321 (56) | 9% | 20% | 2% | 30% | 38% | 2% |
| s322 (30) | 0 | 23% | 10% | 37% | 30% | 0 |
| s323 (38) | 0 | 16% | 5% | 26% | 45% | 8% |

- Count shares are the stability comparison. Minute shares are each dominated by one ask: 645 min d in s321, 340 min b-unmarked in s322, 300 min b in s323.
- The s321 and s322 labels come from 95–150-character question text, so they are lower confidence than s323's.

**Findings**
- **DEFECT, `op_wait` undercounts ask time.** `extract.py:374-377` counts a gap over 300 s only. Ask #23's 88-min wait had 58 queue records, so it was charged mostly as lead "active". My pipeline ask-wait over 300 s is 19.4 h against 17.9 h; about 2 h of the gap is this. `eta?` at 11-14 15:26Z (21 min) was the lead waiting on a backgrounded push, yet it is charged as operator wait.
- **DEFECT, premise chain.** #14's "forward cert and fire" was answered on an unverified header name. #15 (300 min), #19 (21), #29 (48) and #37 (7) reopened it. The six asks on the APP_ENV/mTLS chain total 577 min. The facts sat in the tree (`infra/lib/ingress-stack.ts:111`, `rebalancer/api.py:635`).
- **NOTE, turn-ended waits.** There are 9 in s323, 128 min, with no question in them. Only 1 of 8 end-of-turn questions across all three sprints sat in plain text, 2 min in s323. 40 min of the 128 fall in pipeline steps.

**Mechanisms** (the wait removed is an UPPER BOUND)

| Mechanism | s323 minutes, naive vs bounded | Carrier | Risk |
|---|---|---|---|
| 1. Standing-rulings PreToolUse refusal on `AskUserQuestion`, keyed on the answers-history family | 380 vs 380 (#21 19, #24 195, update asks 166) | New matcher in `templates/settings.json.template:98-184`. `AskUserQuestion` is only a PostToolUse matcher at `:205`, writing `operator-answers-history.md` via `core/hooks/ai-dlc-answer-capture.sh`. Rule at `SKILL.md:460`. | A look-alike question with a changed premise gets refused (`escalations.md` premise-invalidation). |
| 2. Ask-and-proceed on a marked recommendation, with a veto window | 327 (+95 unmarked) vs about 76 (+7) | `SKILL.md:547` today; the turn is held by `AskUserQuestion` (`SKILL.md:163`, `ai-dlc-continue.sh:67`). `ai-dlc-pause.sh` pauses on any operator prose (`ai-dlc-continue.sh:62`). | Needs an answer route that does not pause. The prose-question defect (`fixtures/pause-question-in-prose`) returns if the question is buried. |
| 3. Step-start decision register | at most 11 (asks formed within 5 min of the prior answer: #2, #3, #4, #20) | route `Step 6`, `route.md:459` | Do not build. Questions arise mid-step from lane output; #1's came about 70 min in. |
| 4. Push notification on an ask pending over N min | 979 pipeline-long minus about 18 for response at median 2.3 min is about 960 | New: `PreToolUse` timer on `AskUserQuestion`, cleared by `ai-dlc-answer-capture.sh` | No counterfactual in the record. It may wake the operator. |
| 5. Presence-aware routing: when the last operator event is over 60 min old, take mechanism 2 or 1 instead of blocking, and batch the rest | adds nothing beyond 1+2; independent chains total about 30 | presence is derivable from `operator-requests-history.md` (`ai-dlc-pause.sh:210`) and the answers history | Presence is inferred from two files, not seen. |

Combined, with overlap removed: mechanisms 1 and 2 are at most 463 min of s323's 22.5 h total `op_wait` including pre-step (about 297 min pipeline-only, 28% of the 17.9 h), if the operator keeps taking the default. Mechanism 4 is not summed in.

**Checked and found efficient**
- #1: only 3 of 4 questions have an owner-reserved answer, and the operator answered the follow-ups in 4 min once present.
- The 11 update-session asks each cost about 10 min when asked while the operator was present.

TRUNCATED, ask for part 2 (the full 38-row s323 table, and the s321 and s322 per-ask class labels).

## SENT 2026-11-20T10:51:52.964Z | Part 2a: rows #24-#29, class minutes, cross-sprint shares

PART 2a of 3. Times ET. R = marked Recommended. Data dir: /private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/c10-ask/x.tir1/ (events.jsonl, asks_enriched.json, tally.json, dump.py).

ROWS FROM #24 ONWARD (s323 asks over 30 min; none was notified; no operator prompt anywhere in ~/.claude/projects during any of them)
#24 | 11-18 23:29 -> 11-19 02:44, 195 min | sprint-review | Asked: 3 pipeline stories held for item 2 (2.1 HODL validator zero address, 2.2 interim native-input refusal, 2.3 offramp leg 1 pays by value): build all three now / defer to next sprint / "these are the operator's". Unbadged, but the question text itself says the first option "matches your own answers" and cites 3 operator answers (operator-answers-history.md:7925, :8123, and LR-S323-19). Chosen: Build all three now. Blocked: 1 lane (dev-escalated "Fix p2 F-2 and F-6") finished 04:36Z, 12 min into the wait, then 188 min idle; nothing else dispatchable. First 5 min after: checked fix commit, captures and escalate flags, read story structure and steps/handoff.md; session then handed off (no further ask in that session). Class: c. The next pipeline ask (#28) came about 5 h later, so a proceeding lead would have kept the full 195 min.
#26 | 11-19 04:24 -> 06:33, 129 min | update session (pre-step) | Asked: 3 override drifts (Rule-8, check-5, dev bug-class-sweep): READOPT / REAFFIRM / RETIRE. All three marked R and taken. Blocked: nothing running (the update flow is serial). First 5 min: ran the three readopt merges, hit a conflict hunk, asked #27 at 0 min gap (Keep both, R, 8 min). Class: c. Prior family evidence below.
#29 | 11-19 13:23 -> 14:11, 48 min | sprint-review | Asked 4 Qs: second byte-pin re-baseline (ratify / revert), APP_ENV arm (hold deploys / neutralize in code / ship armed), 2 veto-line sets. Chosen: free text "I need this explained to me in plain language"; "Ship armed"; "All stand" x2 (R). 2 of 4 marked, both taken. Blocked: QA and code-reviewer re-review lanes running until 19:22/19:25Z; answer arrived 19:11Z so 0 idle. First 5 min: dispatched "Fix step-3 review findings" (its prompt names Byte-pin), asked #30 one minute later. Class: d.
Also over 30 min but not in s323: none. s323 short asks are in part 2b.

PER-CLASS MINUTES, s323 (my reading of question text; precedence d > a > c > b > e, an ask takes its hardest question's class)
Pipeline steps (27 asks, 1171 min): b 6 asks 415 min (4 with all-badged-taken); c 2 asks 214 min (#21 19, #24 195); d 16 asks 540 min (1 recommended-taken); e 3 asks 2 min.
Update sessions (11 asks, 196 min): b 2 asks 8 min (both taken); c 8 asks 167 min (6 taken, #26 is 129 of it); d 1 ask 22 min (#7 pre-push red, operator rejected all options).
All 38 asks, 1368 min: b-marked-and-taken 6 asks 327 min (6/6 taken); b-unmarked or status-quo 2 asks 95 min (#18 7, #23 88); c 10 asks 381 min (6 of 10 taken); d 17 asks 562 min (1 taken; long ones #1 148 + #14 200 + #29 48 = 396, 70% of d); e 3 asks 2 min; a 0.
The 'b' class as first drawn contradicted the brief's definition (operator took the recommended option), so unmarked asks are split out.

STANDING-RULING EVIDENCE (operator-answers-history.md, entries before 2026-11-13T08:00Z; regex family counts so FLOORS)
- override drift readopt/reaffirm/retire: 23 earlier asks (15 before s321, 4 s321, 4 s322); 19 answered with a Recommended label; every s323 member (#6, #22, #26) answered READOPT.
- delete a pristine consumer file upstream removed: 28 earlier (27 before s321 + 1 s321); top answers "Yes, delete" 20, "Delete" 4.
- extension still-additive verdict: 48 earlier (35 + 8 + 5), 42 with Recommended label.
- byte-pin re-baseline: 21 earlier, mixed (authorize x4+, "Require a fresh ADR" x1), so not counted standing except as noted.
- veto-line asks: only 4 before s323, mixed answers; counted b (informational) not c.

CROSS-SPRINT SHARES (all asks, pipeline + update; count share is the stability comparison)
s321 (56 asks, 1552 min): a 5 (9%, 45 min); b-marked 11 (20%, 163); b-unmarked 1 (2%, 6); c 17 (30%, 406); d 21 (38%, 927); e 1 (2%, 4).
s322 (30 asks, 679 min): b-marked 7 (23%, 119); b-unmarked 3 (10%, 351); c 11 (37%, 123); d 9 (30%, 87).
s323 (38 asks, 1368 min): b-marked 6 (16%, 327); b-unmarked 2 (5%, 95); c 10 (26%, 381); d 17 (45%, 562); e 3 (8%, 2).
Minute shares are dominated by one ask each (s321 645 min d, s322 340 min b-unmarked, s323 300 min b-marked). c plus b-marked is 50%, 60%, 42% of asks; d is 38%, 30%, 45%. Update-session asks are 11, 11, 11 per sprint, of which standing or taken-recommended: 11, 9, 10. s321/s322 labels came from 95-150 character question text, lower confidence than s323.

## SENT 2026-11-20T10:52:14.439Z | Part 2b: presence, notification grep, prose asks, bounds derivations

PART 2b of 3.

PRESENCE ANALYSIS
Operator-event series: every AskUserQuestion answer plus every human prompt in graph lead transcripts (human() as extract.py:127 plus exclusion of teammate/task-notification/"Another Claude session sent a message" wrappers), plus human prompts in every other ~/.claude/projects dir, 2026-10-30 to 2026-11-20T04:20Z. Rejected or errored asks (#7, #31, #35) write no "answered" text so those actions are missing.
- Wait by operator recency at send time, all 124 asks (n, median min, sum min): last operator event <=10 min before: 55, 2.5, 700; 10-60 min: 39, 6.7, 1362; >60 min: 30, 16.1, 1537. s323 alone: <=10 min 14 asks median 2.3; 10-60 16 asks median 12.3 (472 min, #15 is 300 of it); >60 min 8 asks median 68.4, 720 of 1368 min (53%).
- Last operator action before each s323 long ask: #15 34 min, #1 74, #14 129, #24 169, #23 193, #29 283, #26 3 (it followed #25's instant answer). Five of six long pipeline asks went into absence.
- Of 18 waits over 30 min in s321-s323, 17 had zero operator prompts in any project during the wait. Positive control: s321 #47 (264 min) shows 3 prompts in the llm-gateway project, so the scan can fire. Scope limit: Claude Code transcripts only, not phone or other apps.
- Time of day, long waits (>30 min) beginning outside 08:00-23:00 ET: s323 772 of 1109 min (70%); s323 pipeline only 643 of 979 (66%, asks #1 04:33, #15 02:36, #24 23:29; #14 started 22:43, just inside); s321 794 of 1326 (60%); s322 340 of 473 (72%); three sprints 1906 of 2908 (66%). The 08-23 band is a weak proxy: the operator answered at 02:03 (#14), 02:44 (#24), 03:50 (#25) and 03:19 (#0), so the operator keeps shifting hours. Operator-silent windows over 3 h in s323 included 03:20-07:01, 20:34-02:03, 02:03-07:37, 20:40-02:44, 08:40-14:21.

NO NOTIFICATION IN THE ENGINE (grep with control)
grep -rlE PushNotification over core templates scripts install.sh returns one file: core/fixtures/advisor-gate-deny/lib.sh (line 388, a deferred-tool roster string in a fixture, not engine behaviour). grep -c Notification templates/settings.json.template = 0; control grep -c PostCompact on the same file = 1. Graph's installed /Users/n8/git/graph/.claude/settings.json has "Notification": [] (line 29). AskUserQuestion appears in 15 files under core/skills (control, non-zero). The only hook on AskUserQuestion is PostToolUse ai-dlc-answer-capture.sh (templates/settings.json.template:205, inside the PostToolUse array that starts at :185); the PreToolUse array (:98-184) has no AskUserQuestion matcher. The PushNotification tool exists in the harness roster but no hook, rule or script calls it. s323 lead tools.csv rows: AskUserQuestion 38, Monitor 7, no push tool.

PLAIN-TEXT END-OF-TURN QUESTIONS (counted separately)
Scan: lead assistant messages with no tool_use whose text ends in "?" followed by a human prompt, s321-s323: 8 events (s321 6, s322 1, s323 1), so the scan can fire. s323's one: 11-14 16:28Z, "Do you want me to go ahead with that?", answered "sure, as long as youre careful" after 2 min. Counting waits over 5 min among them: 0 in s321 and s323, about 7 min in s322. So prose questions are negligible.
Separate from questions: 9 turn-ended pauses in s323 where the human prompt ended a >300 s gap, total 128 min, none carrying a question: 11-14 15:26Z "eta?" 21 min (lead was waiting on a BACKGROUNDED push; extract.py:377 charges it as operator wait: measurement defect); 11-14 16:21Z 5 min ("I'll wait for your go-ahead"); 11-15 23:38Z 26 min ("Did you call the advisor?" after a final report); 11-16 15:02Z 17 min and 11-16 17:39Z 10 min and 11-19 08:19Z 9 min (update skill HARD STOP awaiting "/ai-dlc-update apply", by design); 11-19 01:28Z 5 min implementation ("Say the word to resume" after an operator-triggered pause, then "what caused the transactions in my wallet"); 11-19 20:24Z 21 min deploy-validate (mandated sprint-PR approval seam, "approved, proceed"); 11-20 01:16Z 14 min deploy-validate (operator complaint about "venue wall 2" after the lead's yellow context reminder). Pipeline-step share 40 min; update sessions 88 min. Pre-step op_wait 4.65 h reconciles as 196 min of asks over 300 s... (193) plus 88 min of these prompts.

MEASUREMENT DEFECT (op_wait undercounts ask time)
extract.py:374-377 charges a gap to op_wait only when the gap exceeds 300 s. Ask #23 (88 min) had 58 queue-operation records and 2 queued_command attachments during the wait (from the lanes' task notifications), max gap 2843 s and one gap over 300 s, so most of it was charged as lead active. segs for s323 implementation read op_wait 0.09 h against 88 min of ask time. My pipeline ask-wait over 300 s is 1163 min against segs 1073 min (17.9 h) less 40 min of prompts; the 130 min gap is this plus monotone-clock and step-label drift (carry-over 380 vs 376 min, requirements 399 vs 374, sprint-review 268 vs 250, implementation 88 vs 5). Lead "active" 48.6 h therefore contains about 2 h per sprint of time blocked in an ask.

DERIVATIONS OF THE UPPER BOUNDS
Rule applied: removable = min(wait, work available before the next operator-gated ask); mechanisms not summed where they overlap.
- Standing rulings (c) 380 min: #21 19 + #24 195 + update asks #8 9, #9 10, #11 1, #22 9, #26 129, #27 8 (#6 and #25 are 0 min). #24: next pipeline ask was about 5 h later so full 195 holds. Update asks run serially through one family, so full wait holds. Pipeline portion 214, update portion 166. UPPER BOUND: assumes the operator would give the same answer again (operator took the lead's recommendation or first option in 6 of the 10 c asks and no option was a veto).
- Ask-and-proceed (b-marked) naive 327: #15 300, #28 15, #2 3, #10 2, #12 6, #4 0 (+ unmarked #18 7, #23 88 = 422). Bounded: #15 is worth about 50 min, not 300, because the operator did not return until 12:36Z either way and after the answer the lead worked 26 min (join, 12 adjudicators, 4 lane remediators) and then asked #16, an unbadged operator-gated ask (RULE class). Proceeding would send #16 about 08:15Z into the same absence; at 12:36Z the operator answers #15 and #16 together (#16 had taken 25 min, now about 2). Saving is about 26 + 23 = 49 min. Independence of the chain: of 17 dispatches in the 26 min after the answer, 15 do not mention the answer or header (all 12 adjudicators; I read adjudicator lane1 batch1 and fanin batch1 prompts by hand, others by keyword scan); 2 do (Lane 1 remediator prd, Fan-in serial remediator). #28 bounded 15, #2 3, #10 2, #12 6, #18 7, #23 0 (3 lanes running, memory-blocked, nothing else dispatchable). Sum about 76 + 7 = 83. UPPER BOUND, and it assumes the recommended option is taken again.
- Combined mechanisms 1+2: 380 + 83 = 463 min of s323's 22.5 h total op_wait including pre-step (34% of 22.5 h at most); pipeline-only 214 + about 83 = 297 min, 28% of 17.9 h at most.
- Step-start register 11 min: asks formed 0-2 min after the previous answer in the same step (#2 3 min wait, #3 1, #4 0, #20 7); others arise from lane output (#1's questions needed evaluation lanes about 70 min in; #17 and #20 depend on the answer to #16 and #19). Measured value about 0; recommend not building. Also AskUserQuestion carries at most 4 questions per call.
- Keep-lanes-moving ceiling: after the 4 long d asks with finished lanes (#1 about 3 min until next ask, #14 0 independent (fold depends on answer), #15 26, #24 0) about 30 min of s323 in total. That is why prose rules measured null.

## SENT 2026-11-20T10:52:34.474Z | Part 2c: ask #24 defect cite and mechanisms with cites

PART 2c of 3.

DEFECT: ask #24 (sprint-review, 195 min, 195 of them avoidable) violated a rule already in force
Rule 11(a)(i), "a design choice a source settles is decided, not asked", sources = a prior answer in _bmad-output/operator-answers-history.md, a request in operator-requests-history.md, or an operator quote in a LOCKED_REQUIREMENTS entry. Text: core/skills/ai-dlc/SKILL.md:460-466 (sort section "#### Operator decisions: sort before asking (Rule 11(a))"). First shipped in 0.970.0 on 2026-10-30 (git log -S 'a source settles is decided' on core/skills/ai-dlc/SKILL.md returns aa6675b8f, "0.970.0 batch b246"; control: a token that no commit carries returns 0 lines). Graph pulled 0.970.0 before s321 planning (s321 ask #9 on 10-30 reads "ai-dlc 0.970.0 changed Rule 11(a)"). Ask #24's own text cites three operator answers ("Wall 1 rides with the pipeline" operator-answers-history.md:7925, LR-S323-19 "NEW-2 ... ships", "Wall 3(a) closes it" :8123), says "this is the sprint's own scope gap, not a new value you own", and says the first option "matches your own answers"; the operator took it. So the lead held the settling sources and still asked. Contrast with BL-972 (ii) (decide on recommendation when no source settles), which is 0.1171.0 and was never in graph's s323 engine (graph's reconciles: 0.1096 on 11-12, 0.1128 on 11-14, 0.1164->0.1167 on 11-19). Related: dispatch-then-ask is 0.1092.0 (62a88119c, 2026-11-12), SKILL.md:547-558.

WHY LANES "FINISH AND WAIT" CANNOT BE FIXED BY PROSE
AskUserQuestion holds the turn open: core/hooks/ai-dlc-continue.sh:62-71 and SKILL.md:163-165 ("the turn never ends"). The lead can dispatch before asking (SKILL.md:547) but cannot join or dispatch after, so every lane that ends inside the wait sits until the answer. That is structural, not a rule violation.

FINDINGS (tier on consequence)
- DEFECT: Rule 11(a)(i) not applied (#24, 195 min), see above. Same class for #21 (19 min): the operator had answered "cap it" at three sibling gas-price signing sites (#16, #17, #19) and #21 asked again.
- DEFECT: premise chain. #14 (200 min) asked "forward cert header first / hold the fire / forward and fire" on an unverified premise that the ALB sends the bare X-Amzn-Mtls-Clientcert header; the facts were in the tree (infra/lib/ingress-stack.ts:111 sets VERIFY mode; rebalancer/api.py:635 reads the bare name). Both architect seats raised it CRITICAL later; #15 (300 min) reopened it, then #19 (21), #29 (48), #37 (7). The six asks touching the APP_ENV/mTLS chain (#3, #14, #15, #19, #29, #37) total 577 min. No gate can check a premise; the lever is the question text naming file:line for each factual premise.
- DEFECT (measurement): op_wait undercount and "eta?" mis-attribution, see part 2b.
- NOTE: step-start register measured at about 11 min; do not build.
- NOTE: the update-session family is stable at 11 asks per sprint with 9-11 standing or taken-recommended.

PROPOSED MECHANISMS (UPPER BOUND marks; s323 minutes; carrier path:line is the CURRENT behaviour under /Users/n8/git/ai-dlc)
1. Standing-rulings refusal. A PreToolUse hook with matcher AskUserQuestion that reads operator-answers-history.md (written by core/hooks/ai-dlc-answer-capture.sh), matches the question header and family (override drift, pristine-file delete, still-additive, merge-keep-both, a sibling the operator answered earlier in the same sprint), and refuses with the prior answer cited so the lead records a Tier-2 DECIDED_AUTONOMOUSLY entry. Current behaviour: no PreToolUse matcher for AskUserQuestion (templates/settings.json.template:98-184); the PostToolUse matcher is at :205; update-skill asks are issued per blocker (core/skills/ai-dlc-update/SKILL.md:2603, reconcile/apply.sh:468). Removes 380 min of s323 (214 pipeline, 166 update), UPPER BOUND (assumes the same answer again). Risk: a look-alike question whose premise changed gets refused; mitigate by exempting a question that carries a premise-invalidation marker (escalations.md "Authorization-premise invalidation").
2. Ask-and-proceed on a marked recommendation with a recorded veto window. Needs a non-turn-holding ask: a prose question block plus continued work, and ai-dlc-pause.sh (ai-dlc-continue.sh:62) taught to treat a reply that matches a pending-decision record as an answer, not a pause. Current: SKILL.md:547-558 and :163-165. s323: 327 naive, about 76 critical-path bounded (#15 about 49, not 300), plus about 7 unmarked; total 83 against naive 422, UPPER BOUND. Risk: operator picks otherwise (C4 recorded 41 of 45 recommendations taken, not re-derived here), rework of work done under the default; prose-question burial (fixtures/pause-question-in-prose) unless paired with mechanism 4.
3. Step-start decision register asked as one batch. 11 min of s323, UPPER BOUND. Not recommended: questions arise from lane output mid-step; carrier would be steps/route.md Step 6 (route.md:459) and each step file; the 4-question cap per call also bites.
4. Push notification on an ask pending over N min (60 suggested; at 2.3 min median response when the operator is present, N only needs to beat that). Carrier: a PreToolUse hook on AskUserQuestion that starts a detached timer, cleared by ai-dlc-answer-capture.sh on answer; nothing exists today (grep above). s323: 979 pipeline-long minutes less about 18 = about 960 min, UPPER BOUND with NO counterfactual in the record: 17 of 18 long waits had the operator silent in every project, and the operator returns at 02:00-04:00 sometimes, so some would answer at night and some would not. Risk: waking the operator at night; question text in a push is outbound content (send only the header).
5. Presence-aware routing. Presence signal from operator-requests-history.md (ai-dlc-pause.sh:210) and operator-answers-history.md; when the last operator event is over 60 min old, a marked-and-reversible ask follows mechanism 2, a standing family follows mechanism 1, anything else is filed and batched for the operator's return (the operator answered 4 follow-ups in 4 min at #2-#5). Adds nothing beyond 1+2 in minutes (independent chain total about 30); it is the router, not a saver. Risk: presence is inferred from two files, not observed. Scheduling steps to fixed hours is not supported by the data (66% of long waits started outside 08-23, yet the operator answered at 02:03, 02:44 and 03:50).
6. Premise-read line in the question (process, not a mechanism): each factual premise in an ask carries file:line evidence; unverifiable by a hook. Would have attached to #14 (328 min of follow-on asks #15, #19, #37).
Overall, 1+2 are at most 463 min of s323's 22.5 h (about 297 min of the 17.9 h pipeline op_wait, 28%); the rest is operator-gated d-class waiting (562 min of asks) that only presence, notification or a lower d-count (pre-authorized actions at route) can move, and none of those has a measurable counterfactual in the record.

