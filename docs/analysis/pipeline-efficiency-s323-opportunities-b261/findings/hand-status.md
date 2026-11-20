# Findings of reader `hand-status` (recovered verbatim from its transcript agent-ahand-status-d015003c224ef5a0.jsonl)

## FINAL-TEXT 2026-11-20T10:37:59.808Z

Everything below is read-only. I did not edit anything or message another session. I quote figures exactly from the C5, C6 and C7 side commits (9fdb809a3, 93409ae7c, d098ef89c), which are not on main yet, and fall back to main otherwise. Those commits give hours on the monotone clock (clock af44929cc or 81c88066b) with the old clock beside them. Where I give no clock, the figure is a count, a dollar amount or a minute figure, which does not depend on the clock.

**Engine per s323 step**, from graph's `.claude/.ai-dlc-version` and its reconcile log, read read-only:
- Carry-over 1 ran on 0.1101.0.
- Carry-over 2, requirements and architecture ran on 0.1160.0.
- The architecture gate, stories and implementation ran on 0.1164.0.
- Graph then reconciled to 0.1167.0 (2026-11-19T03:59-05:00) and 0.1174.0 (07:25-05:00). I read the 0.1174.0 reconcile commit time from graph's log.
- 77 of 84 gate plans read 0.1164.0 and 7 read 0.1174.0 (BL-1030, `engine-at-pass.sh`).
- BL-397 says implementation moved to 0.1167.0 at 08:32Z and 0.1174.0 after 12:01Z. BL-1168 says 0.1174.0 reached the branch at 12:25:19Z. These disagree by about 25 minutes.
- Sprint-review, deploy-validate and retro ran on 0.1174.0. I confirmed this from the version file at graph commits 11-19 13:13 to 15:46 local, and at the retro commits.

The provisional report's line "implementation on 0.1164.0" is therefore only mostly true. Everything shipped in 0.1165.0 to 0.1174.0 touched at most the last stories, sprint-review, deploy-validate and retro.

## A. Table

Abbreviations: CO = carry-over, RQ = requirements, AR = architecture, ST = stories, IM = implementation, SR = sprint-review, DV = deploy-validate, RT = retro. "Mono" means monotone clock. The code cites below are anchors I confirmed against the text on main. The b259 report's cite lines have drifted in places. For example, `SKILL.md:505` and `join-remediator-shards.sh:2709` no longer land on the fix.

| Entry | Fix | Built | Ran in s323 | s323 measured | Verdict | Still owed |
|---|---|---|---|---|---|---|
| BL-514 | Deny subagent bare `sleep` polls | 0.782.0; `ai-dlc-foreground-budget.sh:36-38`. PARTIAL at 0.1146.0 | All steps | Subagent gap 0.83 → 0.64 h/story (clock 81c88066b). Foreground poll class 0.27 → 0.00 h | WORKED | One release, then close. The 2026-11-20 ruling uses s318 as baseline |
| BL-515 | Hold cap-rejected spawns | 0.784.0 LANDED; `dispatch-guard.sh:951` | All | No s323 reading. s322: 0 of 584 | WORKED (s322) | Nothing |
| BL-507, 808, 809 | Delta re-review; captures out of the partition; record-only route | 0.1063.0, 0.1108.0 LANDED. BL-809 PARTIAL; `partition-review-diff.sh:18` | All | Gate-1 re-review passes/story 1.91 (s319) → 0.78 (s323); s317 was 0.62. Gap-inclusive 0.84 h/story. `route: record-only` occurs in 2 review files, ROUTED in 0 | PARTLY: fell against s319, rose against s317, and the route barely ran | A sprint where the route runs. Operator dropped promotion of arm (q) |
| BL-695 | Party-round waves (prose) | 0.1088.0 LANDED; `rule-bodies/rule-28.md` | All | s322: $3.79/story against $4.98 | WORKED (s322) | LANDED line cites a deleted script (see D) |
| BL-811 | Cross groups collapsed in stories elicitation | 0.1071.0 LANDED; `stories-test-strategy.md` | ST | s322: $6.1 vs $6.0 | NO EFFECT | Nothing |
| BL-913 | Scripted gate transition | 0.1108.0 LANDED; `implementation.md:313`, `dispatch-guard.sh:1487` | IM | s322: 8.6 vs 6.0 calls/story | NO EFFECT | Nothing |
| BL-512 | Cut discards of gate passes for lead paperwork | PARTIAL, last touched 0.1135.0 | All gates | Discards/verdict, implementation: 8/26 = 0.308 vs 0.231 before. Every-gate: 10/34 = 0.294 vs 0.263. Lead-caused subset: 1 of 34 vs 6 of 38 | PARTLY | Per-story cost of gate-validation steps, s323 vs s318 |
| BL-541 | Serial remediator join returns on completion | 0.794 to 0.828; `wait-for-deliverable.sh` `live_extend()` | CO2, RQ, AR | 17 wakes over 12 serial passes (1.4 a pass). 10 returned with the pass's delivery. 3 returned at the 9 min 55 s beat cap, armed without `--dispatch` | PARTLY | Not closed |
| BL-543 | Serial remediator worklist discovery | PARTIAL, 0.1133 to 0.1135 | All planning | Longest serial wait 73.0 → 40.2 min. Sweep share fell. Four-step group 2.03 vs 1.83 h/story (mono). $55.5 vs $55.4. 126.8M vs 98.9M tokens | PARTLY | Hours, dollars and sweep count did not fall |
| BL-508 | `siblings:` field and serial lane on repairs | PARTIAL; `join-remediator-shards.sh:882` | RQ, AR, ST, and CO2 | Four-step group 2.03 h (mono) vs 2.36 (s318) and 1.83 (s319); old clock 7.19 vs 2.31. 13 of 15 pass-2/3 MAJORs read as repair-made or half-fixed siblings (strict regex flags 4) | NO EFFECT | Defect class not gone |
| BL-550 | Give seats real repo paths | 0.1135/0.1137 PARTIAL | RQ, AR, CO2 on 0.1160.0 | Missing-path lines/seat: party 0.54 (s319 0.375); elicitation 35/45 = 0.78 (0.67); adversary 52/101 (s319 52/199) | NO EFFECT (rates higher) | Not closed |
| BL-552 | No per-seat status when a join covers | 0.1135.0 PARTIAL | Same | Status/arrival 0.964 → 0.50; signature 0.529 → 0.04, on 24 arrivals (274 before). Step group did not fall | PARTLY | Cause of the 274 → 24 drop undetermined |
| BL-716 | Serial findings dealt to read-only adjudicators; LANES=1 | 0.1058.0 and 0.1133.0 PARTIAL, `join-remediator-shards.sh` (`PLAN-FILE`, route keys). 0.1173.0 and 0.1178.0 PARTIAL | 0.1058/0.1133 clauses in all planning. 0.1173.0 clause did not run | Remediator solo 9.90 h; width-1 8.56 h (s322: 9.24 / 7.36); LANES=1 round 6.20 h vs 5.48 | NO EFFECT / WORSE (old clauses); UNREAD (0.1173.0) | s324 reading |
| BL-810 | One cross agent in CO elicitation | Under 0.1103.0, PARTIAL; `carry-over-evaluation.md:186` | CO2 (0.1160.0) | Cross $9.54 (s319), $7.32 (s320) → $3.00 for 1 spawn. 4 of 6 cross findings found by no part shard. Step $9.52/story vs $4.33 (s319) and $12.20 (s320) | WORKED for cross width; no step saving | Item 2 of BL-812 blocked on this |
| BL-911 | Cap series at p3; narrow the shard map | 0.1008.0 depth; 0.1096.0 narrowing | All | No series past p3. Planning 27.0 h less operator wait, inside the 24.4 to 36.8 h band | PARTLY (depth worked, hours not shown) | Hours below band, or operator ruling |
| BL-972 | Dispatch before asking the operator | 0.1092.0, 0.1145.0, 0.1171.0 PARTIAL; `SKILL.md` "dispatch, then ask" | All, from 0.1101.0 | ADJ-DISPATCH 7.4% (pipeline asks), 5.3% (all asks) vs 9.5% baseline. HELD-AT-ASK 0 of 38 | NO EFFECT | Item 2 (operator's) |
| BL-841 | Hold a lane's question | 0.968, 0.1053, 0.1145 PARTIAL | All | Idle share of ask-wait 96.9% (s320) → 88.4% (s323): 8.5 points against a 5.0-point rule. Asks naming a lane 0 of 38 (s320 5 of 63, s321 0 of 56). Total ask wait 1,368 min vs 3,052 | PARTLY: claim 1 met, claim 2 null again | Claim 2 mechanism |
| BL-838 | Dev seat to sonnet | 0.968.0; `settings.json.template` `dev`, `dev-escalated`. LANDED line in C6 | IM (dev 112 spawns) | Gate-1 passes/story 2.41 → 1.78; gate-2 1.80 → 1.61. 7 of 18 stories clean through both gates vs 13 of 44. Gap-inclusive 1.36 → 0.84 h. $33.0 → $31.9 | WORKED vs s318-s320 pooled haiku. Not lower than s320 (1.77) | Closed in C6. The b259 "no direction supported" is superseded |
| BL-971 / BL-832 | Adversary back to opus/medium (0.1048.0). BL-832 (0.954.0) had set sonnet/high | 0.1048.0; `settings.json.template:9-12` | All except the CO1 session's seat mix, which I did not check | 149 opus/medium spawns: median 5.6 min (s322 11.7), p90 11.6 (61.5), $2.14 (2.89), 17.1 agent-h (45.3), 1 spawn over 45 min (19). Solo-adversary 3.2 h vs 11.5 | WORKED | Nothing |
| BL-974 | Join's format check at `--mark` | 0.1057.0; `wait-for-deliverable.sh:700` (`--check-part`) | RQ, AR (0.1160.0) | 1 join-refusal resume vs 13 (s321). Clause 2 NOT met: a part that passed its own check was refused (06.md "no advisor: line") | PARTLY | Check does not cover `advisor:` fields |
| BL-975 | Report an agent with an open request | 0.1056.0; `wait-for-deliverable.sh:273` (DISPATCH FAILED) | All | Zero deaths in the post-engine window; predicted under 1 | UNREAD (C8 reading in flight) | Outcome line |
| BL-976 | Wrong shard directory denied at dispatch | 0.1055.0; `dispatch-guard.sh:1319` | AR (0.1160.0) | 0 lead corrections vs 7 re-derived on s321 (filed 10 not reproduced) | WORKED. LANDED in C7 | Nothing |
| BL-397 | Evidence sections, full-collection run | 0.674.0, arms 0.1134/0.1136 PARTIAL; `validate-handoff-evidence.sh:2007` | IM | $31.9 (API $23.0), 86.4M tokens vs baseline $29.0 / 71.4M. Hours 0.84 mono (1.17 old) vs pin 2.00 old clock | NO EFFECT on dollars and tokens; hours below pin | Value evidence |
| BL-398 | Bind case letters to tests earlier | 0.1002/0.1021/0.1093/0.1135 PARTIAL | ST (0.1164.0) | $20.90 (API $18.03), 44.8M vs baseline $20.25, 34.8M. Hours 0.43 mono vs s321 0.78, s322 0.89 | PARTLY: below s321 and s322, above baseline on tokens | Tokens below both comparands |
| BL-1141 | Step-value readings for five parts | Reading only; step-text change owed | CO, AR, QA, RT | KEEP: CO p3, gate QA ($25.86), AR adjudicators. No measured value: RT adjudicators ($5.13), PRD validate ($0.70) | Mixed | Step text change |
| BL-1005 | Skip unchanged shards (stories p2/p3) | 0.1091/0.1135 | ST | 0 reads. p1 repair rewrote every story | UNREAD (0 population) | Decision count |
| BL-912 | One-call snapshot rule | 0.1163.0 PARTIAL; `snapshot-update.sh:2` | ST and IM (0.1164.0) | Snapshot-class active h 4.48 (s321) → 2.46; s322 1.71. Planning lead active h 19.5 → 20.4 | PARTLY: class fell, group did not | Outcome line |
| BL-819 | Lead hours and tokens | PARTIAL. Snapshot hook (0.1012.0) | All | Planning lead calls 2,729 / 4,287 / 4,623 (s321/s322/s323); active h 19.5 / 16.3 / 20.4. Compactions per elapsed h 0.51 / 1.08 / 1.78 | WORSE | `lead_time.py:72` clock |
| BL-812 | Per-story outcome row | PARTIAL | All | Machine h/story 3.20 mono (9.39 old clock) vs s319 3.85 (4.64). Subagent $87.9 vs $88.3. Spawns 63.2 vs 78.0 | PARTLY | Items 2, 3 |
| BL-1166 | Dev pre-reviewer before gate 1 | 0.1168.0 PARTIAL; `implementation.md:255`; `pre-reviewer.md` | IM tail only | 3 pre-reviewer spawns, 11-19T12:59Z to 14:41Z | UNREAD (3 spawns, tail of IM) | s324 reading |
| BL-1030 | Zero-seat gate-1/2 skip after gate-3 rework | 0.1137.0, 0.1168.0 PARTIAL; `gate-transition.sh:330`, `:366` | IM on 0.1164.0 | 5 gate-3 reworks, none on 0.1168.0 or later | UNREAD | s324 |
| BL-1168 | Cheaper `validate-spawn-ledger.sh` | 0.1168.0; `validate-spawn-ledger.sh:1398`, `:1620` (`effjoin`) | Last 11 of 69 calls (0.1174.0) | 56.8 s/call (58 calls) → 3.9 s (11 calls). `wait-for-deliverable.sh` 33.0 s vs 6.5 s, from 212 added bare waits | WORKED where it ran | Full sprint |
| BL-1167 | Concurrent consumer pre-push | 0.1170.0 PARTIAL; `core/git-hooks/pre-push` | IM tail on | No reading | UNREAD | s324 |
| BL-1173 | Verify BMAD invocations | 0.1169.0 PARTIAL; `validate-bmad-invocations.sh` | n/a | n/a | UNREAD | Blocking check |
| BL-1175 | One planning entry | PARTIAL 0.1169, 0.1174, 0.1181. Items 3, 4 (0.1169.0), 6 (0.1174.0) | Items 3, 4, 6 did not run in planning | Planning 39.6 h, $59.5/story (s322 $111.1; s321 $51.9). Less operator wait: 27.0 h | UNREAD | Outcome on s324 |
| BL-1169 to 1171 | Folded into BL-1175 | LANDED 0.1169.0, closed as superseded | None | None | n/a | None |
| BL-1174 | Fix the extractor clock | Monotone default in C5; main still defaults to old clock | n/a | s323 187.0 → 75.4 h | Instrument | `lead_time.py:72` |
| BL-842, 806 | Check 22 ledger-binding question; snapshot time | Open | n/a | Reading in flight | Reading in flight | C8 |

## B. Lists

- **Confirmed working:** BL-514, BL-515, BL-695 (s322), BL-838, BL-971, BL-976, BL-1168 (on the 11 calls that ran it), BL-810's cross-width narrowing.
- **Built but not yet readable (first readable sprint s324):** BL-1166, BL-1030, BL-1167, BL-1173, BL-1175 items 3, 4 and 6, BL-716's 0.1173.0 clause, BL-1005 (zero population), BL-975 (zero deaths; reading in flight), and BL-1168's full-sprint figure.
- **Measured null or worse:** BL-811, BL-913, BL-508, BL-550, BL-972, BL-841 claim 2, BL-716's 0.1058/0.1133 clauses, BL-819 (worse), and BL-912's group hours. BL-397, BL-543 and BL-398 did not fall on dollars or tokens.

## C. Shipped after the last engine s323 ran (0.1175.0 to 0.1183.0), efficiency-relevant

The last engine s323 ran was 0.1174.0 (SR, DV, RT).
- 0.1178.0: remediator shard join keeps route-key directories (BL-716, stays PARTIAL).
- 0.1181.0: planning gates trust only pass-file counts the merge itself wrote; agents waiting on their own jobs get one clear instruction (BL-1175, BL-538).
- 0.1171.0 to 0.1173.0 reached graph with 0.1174.0 (0.1171.0: BL-972 design choices decided on the lead's recommendation instead of asked; 0.1173.0: BL-716 serial findings dealt to read-only adjudicators). They did not run in planning.
- Not pipeline wall clock: 0.1175.0, 0.1176.0 and 0.1183.0 are pull and lead-prose fixes. 0.1177.0, 0.1179.0, 0.1180.0 and 0.1182.0 only reduce this repo's push-gate process count, fixtures and conversion checks.
- Unreleased C5, C6 and C7 side commits: no engine change that I found. They carry readings and extractor and report changes.

## D. Record inconsistencies

- **DEFECT:** BL-695's LANDED line credits `scripts/audit-party-wave-barrier.sh`. It is absent from the tree (0 tracked files; control `gate-transition.sh` reads 1) and the archive still mentions it 14 times.
- **DEFECT:** `docs/analysis/.../extract.py:45` on main reads `== "1"`, which is the old clock. The C5 commit makes it `!= "0"`. The BL-1174 note "monotone is the default" holds only after C5 merges.
- **DEFECT:** the b259 report says "no direction supported" for BL-838. C6 says gate-1 passes fell 2.41 → 1.78. They compare different pools, and C6 supersedes the b259 line.
- **NOTE:** BL-397's engine boundaries (0.1167.0 to 12:01Z) disagree with BL-1168's (0.1174.0 at 12:25:19Z).
- **NOTE:** BL-541's "Progress" paragraph and the BL-541 header describe two subjects; only the wake-count half has an s323 reading.
- **NOTE:** BL-514's old-clock baseline reads 0.91 h and its monotone baseline 0.83 h. The entry says which clock each is on.

## Not verified

- I did not re-run any extractor.
- I did not open every `file:line` for BL-541, BL-543, BL-550, BL-552, BL-398, BL-846, BL-847 or BL-843. The fix text comes from their LANDED and PARTIAL lines and their changelog headings.
- I did not check which engine CO1's adversary ran on. The BL-971 comparison uses the whole sprint.
- Sprint-review timing within 11-19 is bounded by commits at 13:13 to 15:46 local, not by an exact step start.

## SENT 2026-11-20T10:38:36.173Z | Part 2: table rows BL-541 onward

PART 2 of 3. Table rows from BL-541 onward. Columns: entry | fix | built | ran in s323 | s323 measured | verdict | still owed. Clocks: mono = monotone (af44929cc or 81c88066b); counts, dollars, minutes are clock-free.

BL-541 | serial remediator join returns on completion | 0.794 to 0.828, wait-for-deliverable.sh live_extend() at :2165; PARTIAL | CO2, RQ, AR (0.1160.0) | 17 wakes over 12 serial passes (1.4 a pass, 3 at most). 10 returned with the pass's own delivery (9 within 10 s before the remediator's completion notice, 1 at 1.8 min). 3 returned on the beat cap at 9 min 55 s to 9 min 56 s, each armed without --dispatch, outside the mode live_extend applies to. 3 returned within 1 s (2 exit-64 usage refusals, 1 bare --since beat). | PARTLY | not closed; only the wake-count half has an s323 reading.

BL-543 | serial remediator worklist discovery | PARTIAL, 0.815.0 to 0.1135.0 | all planning | longest serial wait 73.0 to 40.2 min; sweep share fell. Four-step group 2.03 h/story (mono) vs s319 1.83; $55.5 (API $46.9) vs $55.4; 126.8M vs 98.9M tokens. Old clock 7.19 vs 2.09 h. | PARTLY (hours and dollars did not fall) | sweep count and serial dollars/story did not fall; discovery cost moved into more, smaller spawns.

BL-508 | siblings: field and serial lane on repairs | PARTIAL; join-remediator-shards.sh:882 | RQ, AR, ST, CO2 (engines 0.1101, 0.1160, 0.1164) | four-step group 2.03 h (mono) vs s318 2.36 and s319 1.83; old clock 7.19 vs 2.31. 13 of 15 pass-2/3 MAJORs read as repair-made or half-fixed siblings (strict regex flags 4). Only third planning pass: CO, $8.62 vs filed $41. | NO EFFECT | defect class has not gone away.

BL-550 | give seats real repo paths | 0.1135.0, 0.1137.0 PARTIAL | RQ, AR, ST, CO2 on 0.1160.0+ (CO1 party on 0.1101.0 is outside the population) | missing-path lines per seat: party 68/126 = 0.54 (s319 0.375); elicitation 35/45 = 0.78 (s319 0.67); adversary 52/101 = 0.51 (s319 52/199). Three-step group 1.40 h, $44.4 (API $37.3), 99.4M vs s319 1.69 h, $50.1, 89.1M. | NO EFFECT (rates higher) | not closed.

BL-552 | no per-seat status line when a join covers the round | 0.1135.0 PARTIAL | same | status per arrival 0.964 to 0.50; signature rate 0.529 to 0.04, on 24 arrivals (274 before). Step group did not fall. | PARTLY | cause of the 274 to 24 drop undetermined (only 26 of ~199 seats show a notification); cannot say a live --complete join covered each arrival.

BL-716 | serial findings dealt to read-only adjudicators; LANES=1 tail | 0.1058.0, 0.1133.0 (join plan), 0.1173.0 (.findings-partition), 0.1178.0 (route-key dirs); all PARTIAL; join-remediator-shards.sh (PLAN-FILE) | 0.1058/0.1133 clauses: all planning. 0.1173.0 clause: did not run | remediator solo-role h 9.90, of which width-1 8.56 (s322 9.24 / 7.36; s321 9.62 / 7.37; s320 9.37 / 7.08). LANES=1 round 6.20 h vs 5.48. Writer turns 3.44 h (40%) vs 2.49 (34%). | NO EFFECT / WORSE for old clauses; UNREAD for 0.1173.0 | width-1 tail reading from s324.

BL-810 | one cross agent in CO elicitation | cross narrowing under 0.1103.0, PARTIAL; carry-over-evaluation.md:186 | CO2 (0.1160.0; first session since the change) | cross spawns/$: s319 6 at $9.54, s320 3 at $7.32, s323 1 at $3.00. 6 MAJOR from the cross shard, 4 of 6 found by no part shard (s319 12 of 20, s320 4 of 9). Step $9.52/story (85 spawns, $171.41) vs s319 $4.33, s320 $12.20, s322 $23.02. | WORKED for cross width; no step saving claimed | BL-812 item 2 is blocked on this entry.

BL-911 | cap series at p3; narrow the shard map | 0.1008.0 (cap), 0.1096.0 (narrowing); PARTIAL; _gate-procedures.md:864 | all | no series past p3; narrowing fired on CO p3. Only spawn above bound: stories p2 20th spawn, a re-run of a stalled shard. Planning 27.0 h less operator wait, inside the 24.4 to 36.8 h band (s318 to s321, mono). Old clock 120.6 h is an artefact (98.3 h agent wait). | PARTLY: depth worked, hours not shown | hours below band, or an operator ruling.

BL-972 | dispatch, then ask the operator | 0.1092.0, 0.1145.0, 0.1171.0 PARTIAL; SKILL.md "Operator decisions: dispatch, then ask" | all, from 0.1101.0 (0.1145.0 half from 2026-11-16T18:25Z) | ADJ-DISPATCH 7.4% (pipeline asks), 5.3% (all asks) vs 9.5% (s320 6 of 63). HELD-AT-ASK 0. 25 DECIDED_AUTONOMOUSLY entries; the `source: recommendation` token occurs 0 times (structural: graph SKILL.md first carries it after the last s323 entry). | NO EFFECT | operator's item 2.

BL-841 | hold a lane's question | 0.968.0, 0.1053.0, 0.1145.0 PARTIAL | all | idle share of ask-wait 96.9% (s320, 2956.8 of 3051.8 min) to 88.4% (1208.9 of 1367.5 min, 38 asks): 8.5 points vs the 5.0-point rule; vs s321 93.7%, 5.3 points. Asks naming a lane 0 of 38 (s320 5 of 63, s321 0 of 56). HELD 0 of 38, DISPATCHED-AT-ASK 13 of 38. | PARTLY: claim 1 met, claim 2 null again | claim 2 mechanism; no population for a pre-ask hold.

BL-838 | dev seat to sonnet | 0.968.0; templates/settings.json.template:31 (dev sonnet/medium), dev-escalated opus/medium. LANDED line is in C6 | IM (spawn ledger: dev 112, qa 111, dev-escalated 13) | s323 vs s318-s320 pooled haiku: gate-1 passes/story 2.41 to 1.78 (32 over 18 stories); gate-2 1.80 to 1.61; 7 of 18 stories clean through both gates vs 13 of 44; gap-inclusive 1.36 to 0.84 h; $33.0 to $31.9 (API $33.0 to $23.0). Against single sprints passes rose: gate-1 vs s320 1.77 to 1.78. | WORKED vs the pool | none. b259 "no direction supported" is superseded; the pools differ.

BL-971 / BL-832 | adversary seat back to opus/medium (BL-832 had set sonnet/high at 0.954.0) | 0.1048.0 LANDED; settings.json.template:9-12 | all (I did not check the CO1 session's seat mix) | 149 spawns opus/medium: median 5.6 min (s322 sonnet/high 11.7), p90 11.6 (61.5), $2.14 a spawn (2.89), 17.1 agent-h (45.3), 1 spawn over 45 min (19). Solo-adversary 3.2 h vs 11.5 (s321 15.7). | WORKED | none.

BL-974 | join's format check run at --mark | 0.1057.0, 0.1161.0; wait-for-deliverable.sh:700 (--check-part) | RQ, AR (0.1160.0) | 1 join-refusal resume vs 13 on s321 (4.5 agent-h). Clause 2 NOT met: join refused requirements-elicitation-repair part 06.md "no advisor: line" after it sealed at --mark. | PARTLY | --check-part does not check advisor:, derivations:, disposition fields.

BL-975 | report an agent with an open request | 0.1056.0 to 0.1146.0 PARTIAL; wait-for-deliverable.sh:273 (DISPATCH FAILED) | all | reading is 0 deaths; predicted under 1 | UNREAD (reading in flight, C8) | outcome line.

BL-976 | wrong shard directory denied at dispatch | 0.1055.0, 0.1108.0; ai-dlc-dispatch-guard.sh:1319 | AR p1, p2 (0.1160.0) | 0 shard-directory corrections vs 7 re-derived on s321 (filed 10 not reproduced; control fired on s321) | WORKED (LANDED in C7) | none.

BL-397 | evidence sections, full-collection run | 0.674.0; arms 0.1134.0, 0.1136.0; PARTIAL; validate-handoff-evidence.sh:2007 | IM (population: all stories) | group $31.9 (API $23.0), 86.4M tokens vs baseline $29.0 (API $23.1), 71.4M; hours 0.84 (mono; old clock 1.17, gap 0.18) vs pin 2.00 old clock; s318 to s322 mono 0.78, 1.63, 1.52, 0.90, 1.63 | NO EFFECT on dollars and tokens; hours below pin | value evidence.

BL-398 | bind case letters to tests earlier | 0.1002.0 to 0.1135.0 PARTIAL | ST (0.1164.0; 2026-11-18T03:36Z to 12:40Z) | $20.90 (API $18.03), 44.8M tokens vs baseline $20.25 (API $17.48), 34.8M; s321 $26.88, s322 $26.37. Hours 0.43 (mono) vs s321 0.78, s322 0.89. | PARTLY (below s321 and s322, above baseline on tokens) | tokens below both comparands.

BL-1141 | step-value readings, five parts | reading only; step-text change owed | CO, AR, QA, RT | KEEP: CO p3 ($7.35 vs $13.10 s322), gate QA ($25.86, 18 seats; 4 stories failed by QA that code review p1 approved), AR adjudicators ($4.19). No measured value: RT adjudicators ($5.13, s322 $3.49), PRD validate ($0.70). | mixed | step-text change; RT consequence weighing.

BL-1005 | skip unchanged shards in stories p2/p3 | 0.1091.0, 0.1135.0 | ST (0.1164.0) | 0 of 18 stories-p2 shards unchanged from p1: 0 C/M, $0.00. p1 $40.75, p2 $28.32. | UNREAD (zero does not discriminate) | decision count; baseline s321 19 reads, $7.57, 0.48 spawn-h.

BL-912 | one-call snapshot rule | 0.1012.0, 0.1163.0 PARTIAL; snapshot-update.sh:2 | ST, IM from 0.1164.0 (2026-11-18T02:05Z) | snapshot-class active h across planning plus IM: 4.48 (s321) to 2.46 (s323); s322 1.71. ST 110 of 1,596 calls (7%) 0.29 h; IM 438 of 3,730 (12%) 1.40 h vs s322 0.72 h. Planning lead active 19.5 to 20.4 h. | PARTLY: class fell, group did not | outcome line.

BL-819 | lead hours and tokens | PARTIAL; snapshot-edit-deny.sh:67 (0.1012.0) | all | planning lead calls 2,729 / 4,287 / 4,623 (s321/s322/s323); active 19.5 / 16.3 / 20.4 h; `other` class 1,237 / 2,010 / 1,927 calls, 3.2 / 5.7 / 9.0 h. Compactions per elapsed h 0.51 / 1.08 / 1.78 (134 in 75.4 h). | WORSE | lead_time.py:72 clock.

BL-812 | per-story outcome row | PARTIAL | all | machine h/story 3.20 mono (old clock 9.39) vs s319 3.85 (4.64), s321 3.43, s322 7.01; subagent $87.9 vs $88.3 (s319), $88 (s317); spawns 63.2 vs 78.0 | PARTLY (hours fell vs s319 mono, dollars flat) | item 3 vs projection rows; item 2 blocked on BL-810.

BL-1166 | dev pre-reviewer before gate 1 | 0.1168.0 PARTIAL; implementation.md:255, core/team-roles/pre-reviewer.md | tail of IM only | 3 pre-reviewer spawns in the s323 ledger (12:59Z, 13:03Z, 14:41Z on 11-19) | UNREAD | gate-1 passes per story on a sprint run on 0.1168.0+ (baseline s322 2.38; s321 2.12); read-only property is prose only.

BL-1030 | zero-seat gate-1/2 skip after gate-3 rework | 0.1137.0, 0.1168.0 PARTIAL; gate-transition.sh:330 (g1_after_g3), :366 (g2_after_g3) | IM on 0.1164.0 | 5 gate-3 reworks, none on 0.1168.0+ | UNREAD | s324.

BL-1168 | cheaper validate-spawn-ledger.sh | 0.1168.0; validate-spawn-ledger.sh:1398, :1620 (effjoin) | last 11 of 69 calls (0.1174.0 reached graph 11-19T12:25:19Z) | 69 calls 48.4 s vs 35.0 s (s322). Before fix 58 calls 56.8 s; after 11 calls 3.9 s (ranges do not overlap). wait-for-deliverable.sh 1,069 calls 33.0 s vs 6.5 s, from 212 added bare waits (checking share 2.5% vs 8.3%). test-pytest-admission.sh 0 calls vs 53. | WORKED where it ran | full-sprint figure.

BL-1167 | consumer pre-push runs steps concurrently | 0.1170.0 PARTIAL; core/git-hooks/pre-push | IM tail on | no reading | UNREAD | s324.

BL-1173 | bmad-review reason; BMAD invocation check | 0.1169.0 PARTIAL; validate-bmad-invocations.sh | n/a | n/a | UNREAD | blocking upgrade-time check.

BL-1175 | one planning entry | 0.1169.0, 0.1174.0, 0.1181.0 PARTIAL; items 3 (intent=readiness), 4 (trace run removed), 6 (passes per series) | none in planning (0.1169.0 and 0.1174.0 reached graph with 0.1174.0, after ST) | planning 39.6 h (mono; default clock 133.1) vs s322 36.9, s321 40.8; less operator wait 27.0 h vs 30.0, 36.8; $59.5/story vs $111.1, $51.9; operator wait 12.5 h | UNREAD for the shipped items | outcome on s324.

BL-1169, 1170, 1171 | folded into BL-1175 | LANDED 0.1169.0, closed as superseded | none | none | n/a | none.

BL-1174 | extractor segment clock | PARTIAL; monotone default is in C5 only | n/a | s323 187.0 h to 75.4 h; s318 to s322 reproduce | instrument | lead_time.py:72 same defect (s317 56.2 to 51.3 etc).

BL-842, BL-806, BL-975 | | | | reading in flight (C8) | not measured | |

## SENT 2026-11-20T10:38:48.340Z | Part 3: sections B, C, D

PART 3 of 3. Sections B, C, D.

B. Lists
- Confirmed working: BL-514, BL-515 (s322), BL-695 (s322), BL-838, BL-971, BL-976, BL-1168 (on the 11 calls that ran it), BL-810 cross-width narrowing.
- Built but not yet readable (first readable sprint s324): BL-1166 (3 spawns), BL-1030 (0 reworks on 0.1168.0+), BL-1167, BL-1173, BL-1175 items 3, 4, 6, BL-716's 0.1173.0 clause, BL-1005 (zero population), BL-975 (zero deaths; C8 reading in flight), BL-1168's full-sprint figure.
- Measured null or worse: NO EFFECT: BL-811, BL-913 (both s322), BL-508, BL-550, BL-972, BL-841 claim 2, BL-716's 0.1058/0.1133 clauses (width-1 8.56 h vs 7.36). WORSE: BL-819 (lead calls, compactions per hour 0.51 / 1.08 / 1.78). Group did not fall: BL-912 (class fell, group hours rose), BL-397, BL-543, BL-398 (dollars and tokens), BL-809 (above s317 0.62), BL-512.

Engine each s323 step ran: CO1 0.1101.0; CO2, RQ, AR 0.1160.0; AR gate, ST, IM 0.1164.0 (77 of 84 gate plans 0.1164.0, 7 on 0.1174.0; BL-397 says IM moved to 0.1167.0 at 08:32Z then 0.1174.0 after 12:01Z); SR, DV, RT 0.1174.0 (graph .claude/.ai-dlc-version at 11-19 13:13 to 15:46 local commits and retro commits, read read-only). Graph reconciles: 0.1160.0 11-16T18:02-05:00, 0.1164.0 11-17T21:05-05:00, 0.1167.0 11-19T03:59-05:00, 0.1174.0 11-19T07:25-05:00.

C. Shipped after the last engine s323 ran (0.1175.0 to 0.1183.0), efficiency-relevant. Last engine s323 ran: 0.1174.0.
- 0.1178.0: remediator shard join keeps route-key directories (BL-716, stays PARTIAL).
- 0.1181.0: planning gates trust only pass-file counts the merge wrote; agents waiting on their own jobs get one clear instruction (BL-1175, BL-538, stay PARTIAL).
- 0.1183.0: plain-words duty extended to everything shown to the operator (BL-1181); touches lead prose, not wall clock.
- 0.1175.0, 0.1176.0: self-update and apply fixes for the pull (BL-1180, BL-1179); not pipeline wall clock.
- 0.1177.0, 0.1179.0, 0.1180.0, 0.1182.0: push-gate and fixture work in this repo only; no s324 pipeline effect.
- Reached graph with 0.1174.0 but did not run in planning: 0.1165.0 to 0.1173.0, notably 0.1168.0 (BL-1166, BL-1168, BL-1030), 0.1169.0 (BL-1175 items 3, 4; BL-1173), 0.1170.0 (BL-1167), 0.1171.0 (BL-972), 0.1173.0 (BL-716), 0.1174.0 (BL-1175 item 6).
- Unreleased C5, C6, C7 side commits: no engine change found; readings, extractor and report changes. I did not diff them file by file.

D. Record inconsistencies
- DEFECT: BL-695's LANDED line credits scripts/audit-party-wave-barrier.sh. Absent from the tree (0 tracked files; control scripts/gate-transition.sh reads 1); the archive still mentions it 14 times.
- DEFECT: on main, docs/analysis/pipeline-efficiency-s317-s320/scripts/extract.py:45 reads `== "1"` (old clock by default). The C5 commit changes it to `!= "0"`. BL-1174's "monotone is the default" holds only after C5 merges.
- DEFECT: b259 report says BL-838 "no direction supported"; C6 reads gate-1 passes 2.41 to 1.78 against the pooled s318 to s320 haiku sprints, while against s320 alone it rose 1.77 to 1.78. The pools differ; C6 supersedes.
- NOTE: BL-397's engine boundaries (0.1167.0 to 12:01Z, 0.1174.0 after) vs BL-1168's (0.1174.0 at 12:25:19Z): about 25 minutes apart.
- NOTE: the b259 and provisional reports say IM ran on 0.1164.0; 7 of 84 gate plans read 0.1174.0, so only the last stories ran later engines.
- NOTE: BL-514 baseline reads 0.91 h on the old clock and 0.83 h on clock 81c88066b; the entry labels each.
- NOTE: C5's BL-1174 text says s317 is not reproducible (transcripts before 2026-10-07 gone), so BL-812, BL-397 and BL-508 baselines pooled with s317 are old-clock quotes.

Not verified: I did not re-run any extractor; I did not open file:line cites for BL-543, BL-550, BL-552, BL-398, BL-846, BL-847, BL-843 (fix text taken from LANDED/PARTIAL lines and changelog headings; no s323 reading found for BL-846, BL-847, BL-843); b259 report cite lines have drifted (SKILL.md:505 and join-remediator-shards.sh:2709 no longer land on the fix; I used anchors found by grep); I did not check which engine CO1's adversary ran on; SR start time is bounded by commits at 13:13 to 15:46 local, not an exact step start.

