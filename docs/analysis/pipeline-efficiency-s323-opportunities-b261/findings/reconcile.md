# Findings of reader `reconcile` (recovered verbatim from its transcript agent-areconcile-bf0ea3031a9262cd.jsonl)

## SENT 2026-11-20T12:38:18.459Z | RECONCILE part 1 of 3: section A settled figures

RECONCILE part 1/3 (section A). Scripts and README: /private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/steps/reconcile/ . Window for all counts: 2026-11-13T08:00Z..11-20T04:20Z.

A1 REFUSED SUITE LAUNCHES. Units: (a) result block = one tool_result containing "admission: REFUSED" or "GiB: REFUSED" (predicate line); (b) line = one such line inside a block; (c) distinct event = distinct (agent, predicate line text), which removes lines re-shown by tail/cat polling; (d) launch result = a Bash call of pytest-footprint-watchdog.py whose own result is the refusal. Some blocks carry only the predicate line (no "admission:" line): a pattern of "admission: REFUSED" alone misses 8+ files.
 - 177 result blocks (162 in 36 subagents, 15 in the two lead sessions; 156 Bash, 21 Read of a file holding a refusal). 179 "admission: REFUSED" lines, 143 predicate lines.
 - 134 distinct events (FLOOR). 34 of the 177 blocks are direct launch results; the rest are re-reads of logs. A QA agent ran a retry loop (retry.sh, 40 tries, sleep 60) writing attempts.log; the "attempt N rc=2" counters seen in results reach 40/141/146/240, so true distinct launch attempts exceed 134 and are not recoverable from transcripts (only the tail of the log was ever printed).
 - By seat (distinct events): qa 58, dev-escalated 29, code-reviewer-escalated 19, dev 16, code-reviewer 2, adversary 2, tea 2, gate-adjudicator/pm/architect 1 each, lead sessions 3. By UTC hour (distinct events): 11-18 13h 13, 14h 20, 15h 8, 16h 11, 17h 12, 18h 8, 19h 5, 20h 4, 21h 20, 22h 21, 23h 1; 11-19 04h 1, 13h 1, 15h 2, 16h 1, 17h 6. 123 of 134 fall on 11-18 13:00-23:59Z.
 - Why the readers differed: 373 = raw line count of toolUseResult payloads (366 lines in toolUseResult plus message copies; every result is stored twice in a transcript, in message.content and in toolUseResult) over 38 files. 104 = the build reader's subset (lead 53b4296a subagents, window 11-18T12:45..11-19T14:04, both strings required): my same window gives 152 sub blocks (qa 62, dev-escalated 49, code-reviewer-escalated 19, dev 16, cr 3, adjudicator 2, adversary 1). 261 NOT reproduced under any definition I tried (blocks 177/338, lines 179/295/366/514); the quoted "5,372 files" control is a count of the token in any record type. Quote: 134 distinct refused readings (floor), 177 result blocks, 36 subagents + 2 lead sessions affected.

A2 "DEV WAITED 3 x 28 MIN" CONFIRMED, with a correction. Agent agent-a8b075e670fcd22ad (dev, "Story 3.2 dev", 11-18T20:27..11-19T01:16, 288 min). It backgrounded one-process combined suites (pytest server/test_*.py rebalancer/tests, no -n) and waited on task notifications: 20:39:49->21:07:41 (28 min, fullbase run), 21:16:28->21:43:06 (27 min, fullhead run), 22:49:00->23:16:14 (27 min, rw-combined; log "7776 passed in 2058.86s (0:34:18)"). Total 82 min. Two longer idle gaps (51 min, 100 min) are waits for the coordinator's gate-1 and gate-2 NEEDS_REWORK messages, not suites. The build reader's 39 min chain is a different unit (it measures per-call dev waits, not the three notification waits). Whether 3.2 was on the critical path: 3.2 merged last (03:35:21Z, commit "Merge story 3.2", EST 22:35:21), leave the schedule to step-impl-gates.

A3 STORY WITH NO AGENT RUNNING (s323 implementation window, spawns grouped by story id from the description, merged intervals; unnamed dev seats dropped: 2). Gap = no agent of that story running until the next dispatch. By type, n / median / p90 / over 10 min / sum:
 dev -> G1 16 / 1.9 min / 6.3 / 1 / 0.88 h (the build reader's 1-10 min, median 2: reproduced)
 G1 -> G2 14 / 6.6 / 45.5 / 5 / 3.95 h
 G1 -> rework dev 3 / 2.5 / 2.5 / 0
 G2 -> rework dev 6 / 7.1 / 11.8 / 2 / 0.72 h
 G2 -> G3 13 / 15.4 / 117.6 / 7 (5 over 60 min) / 9.81 h
 G3 -> close 15 / 17.1 / 25.7 / 15 / 5.00 h
 dev -> G2 5, dev -> G3 7, G3 -> G3 7, G3 -> dev 4: small.
 All 92 gaps: median 6.6 min, 33 over 10 min, 23.4 h (9.3 h with each gap capped at 10 min). The first report's "median 7.6 min, 36 of 88" mixed all types; the 6-12 s figure is notification -> the lead's first call, a different unit (A7). Not all of a gap is lead lag: it includes the lead working other stories and merges.

A4 SPRINT-REVIEW DOLLARS, to the cent. roll's figure = subagents + lead seat, both token-equivalent: s321 $235.63 = sub 209.09 + lead 26.54 (sonnet lead, real API); s322 $100.76 = 82.08 + 18.68; s323 $279.74 = 225.54 + 54.21. The lead share is the lead's 2.55 M in + 0.99 M out + 196.2 M cache-read tokens (local qwen) priced at the s321 hosted mix (sonnet prices; cache read alone $39.2). The reader's lead $3.02 is NOT reproduced by any pricing I tried (sonnet price on in+out only gives $15.0, out only $9.9). The difference between roll and the spawn sum is entirely the lead seat's token-equivalent.

A5 COMPACTIONS s323: units.jsonl lead rows labelled sprint 323: 134 pipeline-bucket sessions + 16 in 8 ai-dlc-update sessions = 150 (0604f29f 2, 0e678bad 1, 17d27721 2, 4104f33b 1, 70834da1 4, cd192a5a 2, f7ff0ac0 2, f8934707 2). The 149 is one fewer by that reader's session or boundary rule; 150 is the full lead population, 134 the pipeline one.

A6 FIRST-PASS FINDINGS: 47 is right. Independent recount (#### headings under ### Critical/Important in graph docs/reviews/s323, 66 code-review and qa-validation files): pass 1 = 47 (18 TEST, 15 EVIDENCE, 8 BOOKKEEPING, 5 CODE, 1 unclassed), later passes 6, all 53. The 55 came from the first reader's find.py: it counted list lines (80 raw items, h10/findings.json) and hand-classified 55; it is a different unit (bullets, not findings).

A7 LEAD TIME: 8.85 h = sum over 216 "last completion of a round" events of min(notification enqueue -> next dispatch/edit/gate/commit, 600 s) (e2.py; uncapped 26.31 h, median 64 s, p90 565 s). The cap clips each event at 10 min so operator waits and long lead tasks do not enter. It still includes 1.39 h of events where an operator ask was pending (10 events) and 4.17 h where the lead was mid-generation, so it is an upper bound on lead-induced lag, not on critical-path delay: 7.46 h without the ask events. Of the 8.85 h, 3.37 h is notification -> first lead response record (median 14 s, which is the build reader's 6-12 s measured on the first call), 2.72 h of it delivery lag.

## SENT 2026-11-20T12:38:40.125Z | RECONCILE part 2 of 3: section B tables and controls

RECONCILE part 2/3 (section B). Method: copy of extract.py that also dumps every lead record (recs.jsonl, 350,353 records from 10-14T22:00Z); the unmodified-label aggregation reproduces steps.csv for s321-s323 pipeline bucket on all 37 (sprint, step) rows, 0 diffs, and the dump's segs equal MONO segs on 500/500 lead segments; MONO/roll.txt is cmp-identical to docs/analysis/pipeline-efficiency-s323-complete-b261/out/roll.monotone-clock.txt (and differs from roll.default-clock.txt). Tables: steps/reconcile/B_tables.txt.

B1 CONFIRMED on code (extract.py:411-431): the label changes only on a whole Read of a steps/*.md; a Read of an EARLIER step file (a lookup) moves it back. Corrections use the lead's own declarations: `snapshot-update.sh --set current_step_file X.md` (12 events s321-s323), a planning gate close (1), and `gate-checkpoint.sh --nonce implementation-...` spans that run while the old label is sprint-review (3 spans, 13:22-14:03, 14:08-14:23, 14:59-15:44 on 11-19, stories 2.1/2.2/2.3 gate 3). Known cases found: carry-over -> requirements 3.41 h (SET 11-17T03:40:26, includes the 198-min ask) and $7.3 spawn (carry $173.4 -> 166.1, 89 -> 88 spawns); ui-direction -> implementation 0.22 h, 7 spawns, $18.5 (SET implementation.md 11-18T12:56:09; ui-direction left 0.1 h, 1 spawn, $1.3); sprint-review -> implementation 1.03 h, 4 spawns (gate-3 of 2.1-2.3); sprint-review -> deploy-validate 0.19 h (SET 11-19T20:05) and s322 0.23 h; s321 stories -> implementation 2.27 h (SET 11-06T10:41, lead 0ec8b044). s322 16-seat architecture party: it sits under gate-validation[architecture], which is ARCHITECTURE once step and gate are merged; no step change (a gate-vs-step split would move about 21 min of lead time; not split here). "PRD rubric walker" spawns: not found as a separate leak in the 8 steps; 1 research-requirements spawn (s323) is re-resolved by its owner tool_use id into the lead step at the call; residual: 24 of 3,040 s321-s323 spawns have no resolvable owner and keep their old step. Residual risk: leaks with no declaration (no SET, no gate close) are not found.
B2 CONFIRMED: old rule charges a gap to the operator only if gap > 300 s AND the next record is a human prompt or an AskUserQuestion is pending; every inter-record gap <= 300 s inside an open ask is "active". New: whole span tool_use -> tool_result of every AskUserQuestion, plus `touch pipeline-paused.flag` -> next human prompt (excluding compaction-summary records). Moves (h, from active / from long agent wait): s321 2.40 / 2.24, s322 0.77 / 0.91, s323 2.46 / 0.
B3 only ONE fork in s321-s323 (and none in s318-s320 from 10-14): lead df56108b duplicates 357 uuids of 4f12d1d9: s321 deploy-validate 0.95 h, 45 lead calls ($2.86 sonnet-priced), no other sprint.
B4 idle tail (gap over 300 s after a session's LAST tool_use; AskUserQuestion answers excluded): s321 9.91 h (d9d2b30c 7.18 incl. 6.26 h before a final prompt, 0ec8b044 1.48, df56108b 1.25), s322 1.24 h (e444bf13), s323 0.00 (last session ends on a tool call). (The brief's "s321 handoff 8.7 h" = 7.18 + 1.48.)
B5 lead_time.py not recomputed (old clock; "active" holds waits under 300 s: 15.36 h of s323 on my run, equal to the report's 15.4).
B6 subagent $ (units priced at roll.py prices; cache write 2 x input = roll vs 1.25 x input; billing not claimed): s321 1,879.5 vs 1,648.6; s322 992.7 vs 881.2; s323 1,582.3 vs 1,333.3 (cache-write component at roll rate: 615.7, 297.2, 664.1).

Controls: sub $ per sprint from units == spawns.jsonl usd (1879.5/992.7/1582.3); spawns total unchanged by relabel (s323 1138, s322 668, s321 1234); lead calls unchanged by relabel (s322 9,304, s323 11,744; s321 7,127 -> 7,082 only by B3); compactions s323 134, s322 72; elapsed per sprint unchanged by relabel and B2; each new row = lead-own + idle + waiting + operator + long agent (checked).

SPRINT TOTALS, old -> corrected h: s321 111.0 -> 100.1 (-0.95 fork, -9.91 tail; relabel and B2 move only); s322 66.4 -> 65.2 (-1.24 tail); s323 75.4 -> 75.4. Classes new (lead model / tool / idle no agent / waiting on agents <300 s / operator / long agent): s321 13.2 / 3.1 / 5.4 / 27.0 / 29.0 / 22.5 ; s322 16.7 / 3.1 / 2.7 / 13.2 / 12.0 / 17.5 ; s323 22.4 / 5.6 / 2.9 / 15.4 / 20.3 / 8.9. Old operator wait 24.9 / 10.3 / 17.9; old long agent wait 34.8 / 19.7 / 8.9; old active 51.3 / 36.4 / 48.6.

TABLE s323 (step with its gate; elapsed old->new h | lead-own model+tool | idle | waiting <300s on agents | operator old->new | long agent wait old->new | spawns old->new | sub $ old->new (5-min cache in parentheses) | lead calls old->new | compactions old->new):
carry-over 11.8->8.4 | 2.0 | 0.2 | 1.9 | 6.3->3.1 | 1.2->1.2 | 89->88 | 173.4->166.1 (143.2) | 828->811 | 9->8
requirements 13.5->16.9 | 2.9 | 0.3 | 1.6 | 6.2->10.0 | 2.1 | 179->182 | 223.9->233.0 (196.8) | 1178->1182 | 13
architecture 5.2 | 2.2 | 0.3 | 1.2 | 0.0 | 1.4 | 67 | 130.0 (112.1) | 1021->1032 | 12->13
ui-direction 0.3->0.1 | 0.0 | 0.0 | 0.1 | 0 | 0 | 8->1 | 19.8->1.3 (1.1) | 86->25 | 1->0
stories-test-strategy 9.1 | 3.3 | 0.4 | 3.6 | 0 | 1.9 | 264 | 348.3 (291.2) | 1596->1598 | 19
implementation build 5.6->5.8 | 2.7 | 0.1 | 1.5 | 0.1->1.6 | 0.0 | 111->118 | 221.7->240.1 (203.3) | 1130->1183 | 11->12
implementation gates 9.5->10.5 | 6.9 | 0.1 | 2.6 | 0.2->0.3 | 0.3->0.5 | 196->200 | 191.5->202.4 (169.0) | 2600->2875 | 39->42
sprint-review 11.1->9.9 | 2.5 | 0.3 | 1.9 | 4.2 | 1.3->1.0 | 171->167 | 225.5->214.7 (178.5) | 1291->958 | 14->11
deploy-validate 5.3->5.5 | 2.4 | 0.8 | 0.6 | 0.9->1.2 | 0.4 | 14 | 20.4 (16.5) | 1145->1208 | 9
retro 2.7 | 2.0 | 0.2 | 0.3 | 0 | 0.1 | 28 | 23.1 (19.5) | 602->605 | 7
route/handoff/pre-step 1.3 | 0.9 | 0.2 | 0.0 | 0 | 0.2 | 9->8 | 3.1->2.1 (1.4) | 267 | 0
TOTAL 75.4 | 28.0 | 2.9 | 15.4 | 17.9->20.3 | 8.9 | 1138 | 1,582.3 (1,333.3) | 11,744 | 134
(spawns/$ here are by owner tool_use id; "other steps" row has 2->1 spawns, $1.4->0.7.)

## SENT 2026-11-20T12:39:09.546Z | RECONCILE part 3 of 3: s321/s322 tables, section C, report edits

RECONCILE part 3/3. Same columns as part 2.
TABLE s322: carry-over 13.7 | 1.9 | 0.2 | 1.8 | op 5.7 | long 4.2 | 112 | $191.2 (173.9) | 1050 | 8
requirements 9.9 | 2.1 | 0.1 | 3.0 | 1.2->1.3 | 3.4 | 128 | 249.5 (225.9) | 1202->1196 | 11
architecture 5.8->5.7 | 1.4 | 0.1 | 1.4 | 0 | 2.9 | 68 | 110.0 (99.8) | 687->677 | 7->6
stories 7.5 | 2.0 | 0.3 | 1.9 | 0 | 3.3 | 125 | 169.2 (151.4) | 1348->1328 | 11->12
impl build 7.9->8.0 | 3.5 | 0.3 | 2.2 | 1.4->1.5 | 0.6 | 68 | 65.4 (55.4) | 1413->1435 | 8
impl gates 5.1 | 2.2 | 0.2 | 1.1 | 0.6->0.7 | 0.9 | 39 | 71.2 (61.5) | 849->863 | 8
sprint-review 2.3->2.0 | 0.8 | 0.1 | 0.6 | 0 | 0.6 | 65 | 82.1 (68.8) | 497->387 | 4->3
deploy-validate 3.5->3.7 | 1.1 | 0.5 | 0.2 | 0.8->1.9 | 1.0->0.1 | 3 | 5.2 (4.3) | 544->652 | 3->4
retro 5.3->4.1 | 2.5 | 0.5 | 0.4 | 0.4->0.5 | 1.4->0.2 | 31 | 17.7 (14.3) | 896->898 | 8
route/handoff/pre-step 3.9 | 1.8 | 0.4 | 0.2 | 0.2->0.5 | 1.1 | 12 | 3.5 (2.5) | 529 | 2
other (bug-investigation) 1.6 | 0.6 | 0.0 | 0.5 | 0 | 0.3 | 17 | 27.7 (23.3) | 289 | 2
TOTAL 66.4->65.2 | 19.8 | 2.7 | 13.2 | 10.3->12.0 | 19.7->17.5 | 668 | 992.7 (881.2) | 9,304 | 72
Line by line: -1.24 h tail (e444bf13, after the last tool call: queue 0.33 + 0.91 before a compaction); relabel 0.33 h gross (sprint-review -> deploy-validate 0.23, arch -> stories 0.06, stories -> impl 0.04); operator +1.68 (0.77 from active, 0.91 from agent wait: the retro pause for commentary and an ask with notifications).

TABLE s321: requirements 11.1 | 1.5 | 0.6 | 3.7 | 1.9->2.4 | 3.1->3.0 | 168 | 260.6 (232.9) | 812 | 3
architecture 10.0->9.9 | 1.0 | 0.3 | 2.7 | 0 | 5.8 | 122 | 262.6 (237.2) | 558->555 | 5
ui-direction 0.1 | 0.0 | 0.0 | 0.1 | 0 | 0 | 1 | 0.9 (0.7) | 6 | 0
stories 19.7->17.6 | 2.9 | 0.6 | 5.4 | 2.1->1.9 | 8.3->6.9 | 431->430 | 591.9->591.5 (524.2) | 1353->1349 | 11->10
impl build 14.3->16.6 | 3.4 | 0.4 | 6.9 | 1.1->3.9 | 2.0 | 154->155 | 286.5->286.9 (247.6) | 1565->1588 | 12->13
impl gates 8.1->7.9 | 3.1 | 0.5 | 2.6 | 1.2->1.4 | 0.3 | 126 | 160.7 (139.5) | 943->927 | 11
sprint-review 2.9 | 0.8 | 0.3 | 1.7 | 0->0.1 | 0 | 169 | 209.1 (176.8) | 396 | 3
deploy-validate 29.0->28.0 | 2.3 | 1.7 | 3.4 | 18.2->18.1 | 2.6->2.5 | 45 | 100.2 (84.2) | 1021->978 | 7
retro 3.1->1.8 | 0.4 | 0.4 | 0.1 | 0->0.8 | 2.1->0.1 | 14 | 5.5 (4.2) | 170 | 1
route/handoff/pre-step 12.7->4.0 | 0.8 | 0.5 | 0.3 | 0.4 | 10.6->1.9 | 4 | 1.6 (1.3) | 303->301 | 4->3
TOTAL 111.0->100.1 | 16.3 | 5.4 | 27.0 | 24.9->29.0 | 34.8->22.5 | 1234 | 1,879.5 (1,648.6) | 7,127->7,082 | 57->56
Line by line: -0.95 fork copies (deploy-validate; 45 lead calls); -9.91 idle tails (route/handoff 8.7 + retro 1.25); relabel 2.5 h gross (stories -> implementation 2.27); operator +4.64 (2.40 from active, 2.24 from agent wait) less 0.54 inside the fork copies.
(s321 lead $ for the fork copies: $2.86; elapsed rows sum to 100.1.)

SECTION C, admission waits (36 subagents with a refused launch; c_waits.txt lists each: first refusal, agent, role, story, minutes, merge status). Wait = first refused reading -> next admitted reading (or agent end if none): 1,149 agent-minutes (19.2 agent-h); lower bound first -> last refusal 560 agent-min; those agents lived 1,426 min. Not wall clock. By story: 1.1 419 agent-min (dev-escalated rework a0e9ad02 315 of them, 114-refusal figure is that agent's), 3.1 285 (QA pass 2 a2515163: 284.9 min, refusals from 14:45Z, 281.7 min first->last), 5.2 222 (dev a1dae160, 198 min), 1.3 100, 4.1 37, 1.2 26, 1.4 25, unnamed seats 29, 2.1 5. Chain test (dependency chains of wave-dag.copy.md and the gates reader's C1 3.1->3.2, C2 1.1->(1.2,1.3,1.4)->5.2, C3 5.4->5.5; merge times from graph "Merge story" commits, UTC): 1.1 merged 21:06 (not last of C2); 1.2 03:14:50, 1.3 03:34:09, 1.4 03:34:30 (ties within 2 min of the latest), 5.2 03:34:38 (latest of C2; its 222 min wait is the one on C2's tail); 3.1 merged 20:13 and 3.2 03:35:21 is the sprint's last merge, so 3.1's close is NOT the latest of C1 but 3.2 dev started 14 min after it (3.2's own admission waits are small, but its dev lost 82 min to three one-process suite runs, A2). Whether the 277-min QA wait delayed the sprint end depends on the schedule the gates reader is building; 3.1 closed 19 h... correction: 3.1 closed 20:13Z and the QA wait ended before it. I do not decide that here.

FIGURES IN THE LANDED REPORT THAT MUST CHANGE (docs/analysis/pipeline-efficiency-s323-opportunities-b261.md):
1. Totals table: s321 111.0 -> 100.1; s322 66.4 -> 65.2; lead active 51.3 / 36.4 / 48.6 -> 48.6 / 35.7 / 46.2; operator wait 24.9 / 10.3 / 17.9 -> 29.0 / 12.0 / 20.3; waits over 5 minutes 34.8 / 19.7 / 8.9 -> 22.5 / 17.5 / 8.9. Hours per story s321 4.4 -> 4.0, s322 8.3 -> 8.2.
2. Per-step table (lines 83-92), elapsed: carry-over s323 11.8 -> 8.4; requirements s323 13.5 -> 16.9; ui-direction ~0; stories s321 19.7 -> 17.6; implementation s321 22.4 -> 24.5, s322 13.0 -> 13.1, s323 15.1 -> 16.3; sprint-review s323 11.1 -> 9.9, s322 2.3 -> 2.0; deploy-validate s321 29.0 -> 28.0, s323 5.3 -> 5.5, s322 3.5 -> 3.7; retro s321 3.1 -> 1.8, s322 5.3 -> 4.1; the split "= a + b + c" must be recomputed from the new class hours. Lead $ per row is NOT re-priced here (only subagent $ moves, see the tables).
3. Line 96-98 "s323's sprint review is not a pipeline regression ... about 3.4 h of lead-active time": the gate-3 part moves to implementation (1.03 h of the 15 build-and-gate hours of 2.1-2.3 sit in the gate nonce spans); sprint review is 9.9 h, not 11.1; planning (carry+req+arch+stories) stays 39.6 h in s323 (the 3.4 h stays inside planning), 38.6 h in s321.
4. "Where s323's 75.4 hours went": lead's own 33.3 = 25.2 + 5.8 + 2.3 -> 30.8 = 22.4 + 5.6 + 2.9 (the 2.5 h moved to operator); operator answers 17.9 -> 20.3 and "about 2 h more sits inside lead active" is now counted (2.46 h); waiting on agents 15.4 and long waits 8.9 unchanged.
5. Section 2 (line 198): "261 refused launches ... 206 of them between 13:00Z and 24:00Z that day" -> 177 result blocks, 134 distinct refused readings (floor; retry loops hide more), 123 of the 134 on 11-18 13:00-23:59Z.
6. Line 186-188: "a finished agent waited a median 7.6 minutes ...; 36 of 88 ... over 10 minutes" -> per type (A3): dev->gate 1 median 1.9 min; gate 1->gate 2 6.6; gate 2->gate 3 15.4 (7 of 13 over 10 min); gate 3->close 17.1 (15 of 15 over 10); all 92 gaps median 6.6, 33 over 10 min. Line 187 "lead was active 13.6 of 14.4 h" for the implementation step: recompute on the new impl rows.
7. Line 281 "Of 55 classified review findings, 30 are evidence or bookkeeping" -> 47 first-pass findings, 23 evidence or bookkeeping (15 + 8), 18 test, 5 code, 1 unclassed.
8. Lead compactions 134: keep with the label "pipeline sessions; 150 with the 8 ai-dlc-update sessions".
9. Any "8.85 h" lead-lag figure: label as an upper bound that contains 1.39 h of operator-ask events (7.46 h without); and the "3 x 28 minutes" sentence: 28 + 27 + 27 min on one dev, agent a8b075e670fcd22ad (plus two waits for the gate verdicts).
10. s321 deploy-validate "29.0 = 8.2 + 18.2 + 2.6": 28.0 (fork copies removed). Sprint-review dollars: $236 / $101 / $280 stay valid as roll's step+gate figure, and are 209.09 + 26.54 / 82.08 + 18.68 / 225.54 + 54.21 (subagents + token-equivalent lead).
11. Subagent dollars ($1,580 a sprint, section 6): add the five-minute cache-write figure $1,333 (s321 1,649; s322 881) beside it.

COULD NOT SETTLE: the 261 count and the 5,372-file control (not re-derived); the reader's lead $3.02; true attempt count of the retry loops; step leaks with no declared transition (only 16 explicit markers found, 12 SET + 1 gate close + 3 nonce spans; a residual leak is possible); gate-vs-step split of the s322 architecture party; 24 spawns with no owner call; whether cache writes in s323 were five-minute (not claimed); lead dollars after relabel (calls moved, not re-priced); critical-path effect of the admission waits (step-impl-gates).

## FINAL-TEXT 2026-11-20T12:39:26.997Z

I settled sections A and B, and for section C I listed every figure in the landed report that must change. I sent all of it to `team-lead` as three messages plus one correction. The correction replaces a garbled clause in part 3's chain test.

**Section A (settled figures)**
- **Refused launches:** 177 result blocks and 134 distinct refused readings, which is a floor because retry loops hide attempts. 123 of the 134 fall on 11-18 between 13:00Z and 23:59Z. I could not reproduce 261 under any definition. The 373 comes from raw lines, and every result is stored twice in a transcript.
- **Story 3.2 dev:** the three waits are confirmed at 28, 27 and 27 minutes. They sit on one dev, `agent-a8b075e670fcd22ad`, running single-process suites.
- **Gaps with no agent running (A3):** by type, dev to gate 1 has median 1.9 minutes, gate 1 to gate 2 is 6.6, gate 2 to gate 3 is 15.4, and gate 3 to close is 17.1. Across all 92 gaps the median is 6.6 minutes, and 33 run over 10 minutes.
- **Sprint-review dollars:** to the cent, roll's figure is the subagent sum plus the lead's token-equivalent:

  | Sprint | roll total | Subagents | Lead |
  |---|---|---|---|
  | s321 | $235.63 | $209.09 | $26.54 |
  | s322 | $100.76 | $82.08 | $18.68 |
  | s323 | $279.74 | $225.54 | $54.21 |

  The reader's $3.02 lead share does not reproduce.
- **Compactions in s323:** 134 in the pipeline sessions plus 16 in eight ai-dlc-update sessions makes 150.
- **First-pass findings:** 47 is right; an independent recount of the review files gives the same. The 55 was a bullet-line count.
- **Lead-time 8.85 h:** it caps each event at 10 minutes. It includes 1.39 h of operator-ask events, so it is an upper bound on lead lag.

**Section B (instrument defects)**
- **Step attribution (B1):** the leak is real. I found the known cases: 3.41 h of requirements charged to carry-over-evaluation, and ui-direction mostly implementation. Gate 3 of stories 2.1 to 2.3 moves out of sprint-review, 1.03 h. In s321, 2.27 h moves from stories-test-strategy to implementation.
- **Operator wait (B2):** s323 goes from 17.9 to 20.3 h.
- **Forked sessions (B3):** only one fork exists, in s321 deploy-validate, 0.95 h.
- **Idle tails (B4):** 9.91 h in s321 and 1.24 h in s322. s323 has none.
- **Totals, old to corrected:** s321 111.0 to 100.1, s322 66.4 to 65.2, s323 unchanged at 75.4.
- **Cache pricing (B6):** subagent dollars at the one-hour cache-write rate against the five-minute rate. I do not claim which is billed.

  | Sprint | One-hour rate | Five-minute rate |
  |---|---|---|
  | s321 | $1,879.5 | $1,648.6 |
  | s322 | $992.7 | $881.2 |
  | s323 | $1,582.3 | $1,333.3 |

- **Controls:** the uncorrected aggregation matches `steps.csv` on all 37 rows for s321 to s323. `MONO/roll.txt` is `cmp`-identical to `roll.monotone-clock.txt` on main. Subagent dollars match `spawns.jsonl`, and spawns and lead calls do not move under relabeling.

**Section C (admission waits)**
- 36 subagents waited on a refused launch, totalling 1,149 agent-minutes (560 at the lower bound).
- By story, 1.1 has 419 agent-minutes, 3.1 has 285, and 5.2 has 222.
- Story 5.2 is the latest-merged of the 1.1-to-5.2 chain, and 3.1 is not the latest of its chain.
- I did not decide whether admission waits set the step length; that is the gates reader's schedule.

**What I could not settle:**
- The 261 count and the "5,372 files" control, which I did not re-derive.
- The reader's $3.02.
- The true attempt count of the retry loops.
- Step leaks with no declared transition: I found only 16 explicit markers (12 `current_step_file` sets, 1 planning-gate close and 3 gate-nonce spans).
- The gate-versus-step split of the s322 architecture party.
- 24 spawns with no resolvable owner call.
- Lead dollars after relabeling, which are not re-priced.

Everything is in `/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/steps/reconcile/`. Start with `README.md`; the main outputs are `B_tables.txt`, `a3_gaps.txt` and `c_waits.txt`.

