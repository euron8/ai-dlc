# Findings of reader `step-gate-validation` (recovered verbatim from its transcript agent-astep-gate-validation-c7c473258042c2a2.jsonl)

## SENT 2026-11-20T12:09:05.855Z | gate-validation analysis part 1: summary and per-check table

GATE-VALIDATION step analysis, part 1 of 3 (summary, per-check table). Scripts: /private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/steps/gate-validation/ (README.md names each).

SUMMARY
1. Cost, non-implementation gates (CO, req, arch, stories, SR, retro), s323: lead active 300 min (5.0 h), 1,440 lead calls, 26 of the sprint's 134 compactions, 230M cache-read tokens, plus 4.3 MB of gate-file Reads (gate-validation.md 200 reads/2.97 MB, graph's 73 KB domain extension 53 reads/1.0 MB, _gate-procedures.md 22 reads/0.21 MB). 34 adjudicator shards, 112 agent-min, $26; 6 remediators $5.6; 21 advisor calls, 11.9 min foreground. s322: 183 min, 1,015 calls; s321: 98 min (4 of 6 gates labelled, partial). Clean-gate floor is 19-32 min of lead time (s321/s322/s323 retro/CO); s323 stories 77 and SR 89 are repair-driven.
2. Biggest waste: the lead hand-runs ~14-20 validator arms, hand-writes a 65-line gate-log table, 30-40 GATE_METRIC rows, ledger records and the snapshot row for every gate, re-reading ~100-160 KB of check prose first (and again after each compaction). Only the implementation gate 3 has a program for this (gate-transition.sh). The records are the failure surface: the advisor's G2 call at the s323 retro gate caught an invented value (last_imminent_fire_turns 81) and an unverified merge claim, both slips of hand-writing.
3. What gates catch: 5 adjudicator FAILs in ~190 non-impl llm-check verdicts (2.6%), plus ~14 script-arm/repair events. Of the 5, 2 were validators that silently skipped (Check 2: entry with no Status line; Check 3: validator printed PASS EXAMINED NOTHING on a story whose frontmatter declares an LR with no block), 1 verdict-line grammar (Check 1 'Tip:' prefix), 1 EARS wording (Check 29), 1 real (Check 3, LR-S322-9 never anchored). Nearly every other repair is a record the pipeline wrote in a shape its own validator rejects.
4. 28 of the 40 checks a non-impl gate loads never failed in the 15 gates of s321-s323 (about 75 KB of the file). 12 failed: 1, 2, 2a, 3, 5, 15, 17, 24, 29, 30, 32 (false positive, waived 3 gates), 35.
5. Verdict: the step as a procedure should not exist in this shape. Replace with one program `gate-run.sh --type X` (generalising gate-transition.sh) that prints verdict rows, writes ledger, metrics, gate-log table and snapshot row, plus one adjudicator for the 3 judgments that need a model. Upper bound freed per sprint: about 4 h of lead active, 3.5-4 MB of Reads, roughly 1,100 lead calls (about 180M cache-read tokens). Estimate, not measured: target floor 8-10 min per gate.

DEFECTS (engine)
DEFECT D1 validators that report PASS/skip on an unexamined subject: validate-escalation-status-vocabulary skips entries with no **Status:** line (s322 CO and s323 arch FAILs were found only by the adjudicator); validate-locked-anchor.sh PASS-EXAMINED-NOTHING on story 1-8 (s322 SR Check 3). Fix the validators; the llm check then has nothing left to catch.
DEFECT D2 producers write shapes the gate rejects: Check 30 failed at the story gate in s319, s320, s322, s323 (4 of 5 sprints; 11 CAP-to-AD lines and 11 LR-to-CAP entries in s323); Check 2 vocabulary s322/s323 (3 events); Check 24 chain (s322 arch, s322 stories, s323 stories); Check 17 PRD validate report without provenance block at the requirements gate in s320, s322, s323; Check 5 draft->backlog in s320 and s323 (18 stories, 'per the s315 precedent'). Fix at the authoring step; run the validator at the step's end.
DEFECT D3 gate-validation-domain.md (graph extension, 73 KB) is read 53 times/1.0 MB per sprint at non-impl gates to write rows that read NA/SKIPPED: 11 of its 17 checks (919b, 920, 922-924, 926-928, 930-932) were NA in 14 of 15 non-impl gates and never PASS.
DEFECT D4 Check 32 false positive (route.md:587 filename token) cost an operator-authorized 3-gate suppression in s322.
NOTE N1 shard width varies for the same escalated set: 10 shards (s322 planning), 3 (s323 planning), 8 (story: 0.6-1.3 min each), 4 (SR), 3-9 (retro). Wall clock is the slowest shard (1.5-8.5 min).
NOTE N2 the adjudicator re-runs the validators the lead already ran (gate text says so; verdict evidence cells quote the same validator output).
NOTE N3 H1 (manifest completeness: every required anchor loaded) becomes vacuous once a program runs the checks.

PER-CHECK TABLE (planning/story/SR/retro scope; class from enforcement-map.yaml; 'fires' = non-impl gate events s321-s323 + repair records s319-s323)
id | file:line | bytes | class | verifies | fired | verdict
1 | :222 | 4.7K | llm | review verdict token grammar, party/AE/adversarial present | 1 (SR: 'Tip:' prefix) + J2 drift | SCRIPT (grammar is deterministic)
1c | :291 | 2.0K | llm | research invoked | 0 of 8 | SCRIPT or CUT (0 in 8)
2 | :328 | 8.1K | llm+2 validators | no open HARD_BLOCK, vocabulary | 4 events, all format; 2 missed by script | SCRIPT after D1 fix
2a | :443 | 3.1K | script | operator citation | 1 (prose shape) | KEEP in program
3 | :493 | 1.6K | llm | LR not weakened in body | 1 real | KEEP as judgment; 3b already byte-anchors
3a | :522 | 2.1K | llm | story validation origin | 0 of 3 | MERGE into 3
3b | :565 | 3.1K | script | LR full text | 0 of 3 | KEEP
4 | :619 | 0.5K | llm | placeholder grep | 0 of 15 | SCRIPT
5 | :631 | 7.0K | llm+sprint-status.sh | story status | 2 (draft vs backlog) | SCRIPT, fix producer
7 | :756 | 0.8K | llm | files exist | 0 of 15 | SCRIPT
8,9 retro | :771,:790 | 0.8K, 12.1K | llm | deploy/visual evidence | 0 of 2 | other hand
12 | :953 | 11.1K | lead | write gate-log entry | 1 slip class (advisor G2) | SCRIPT (render)
13 | :1123 | 0.5K | lead | announce | 0 | SCRIPT
14 | :1137 | 16.4K | lead | snapshot update | s323 arch trim lost 65 lines (35 caught) | SCRIPT (snapshot-update.sh exists)
15 | :1389 | 3.1K | lead | verify snapshot | 1 (parser read 183560 tok) | SCRIPT
16 | :1452 | 3.5K | llm+validate-stub-audit | stub audit | 0 of 15 | SCRIPT
17 | :1516 | 13.6K | script | provenance block | 3 (requirements gate) | KEEP script, fix producer
18 | :1718 | 2.8K | project | test-debt anchors | 0 of 2 | KEEP script
20 | :1828 | 3.2K | llm | intensity minimum met | 0 of 10 | SCRIPT (table lookup)
21 | :1882 | 2.5K | llm | strategy ids resolve | 0 of 2; validate-handoff-evidence --strategy exists | SCRIPT
23,25,26,28,31,33,34,36,37 | various | 41K | script | stamps/steering/adoption/spec/scope/trunk/owed | 0 of 8-15 each | KEEP as program arms; 25 should read the baseline itself (lead compares by hand today, :2515)
24 | :2316 | 14.2K | script | adversarial cycle converged | 3 | KEEP script
27 | :2892 | 3.8K | llm | routing sanity | 0 of 8 | KEEP (judgment)
29 | :2977 | 3.7K | llm | spec kernel WHAT/HOW, EARS | 1 (s322 req) | KEEP (judgment)
30 | :3040 | 12.7K | script | LR-CAP-FR-story join | 4 sprints of 5 | KEEP script, fix producer
32 | :3247 | 1.8K | script | BMAD invocations | 1 FP (3 gates) | FIX regex
35 | :3441 | 3.4K | script | snapshot content conserved | 1 real (65 lines, self-inflicted) | KEEP
H1 | :2548 | 4.9K | lead | anchors loaded | 0 | CUT with program
H2 | :2638 | 3.9K | script | forgery fixture attestation | 0 of 15 | KEEP once per sprint, not per gate
core-layer | :2720 | 7.0K | llm | diff classification | 0 of 2 | KEEP (judgment) if consumer edits core
failure/reset | :3618 | 4.4K | lead | repair protocol | 5 of 15 gates | KEEP, shrink
Sizes: 247,205 B, 3,703 lines, 4 code blocks (all prose). Judgment 6 of 40 checks.

## SENT 2026-11-20T12:09:29.634Z | gate-validation analysis part 2: per-gate costs, readers, procedures file

GATE-VALIDATION part 2 of 3: per-gate cost, outputs and readers, _gate-procedures.md.

PER-GATE COST (lead active min / lead calls / compactions / gate-file Read KB / agent spawns, min, $). Source: MONO segs, classes, spawns, gatereads.py. Gate windows are first-to-last lead record labelled gate-validation[X]; adversarial rounds dispatched inside a window cannot be separated (see unmeasured).
s323: CO 19/110/2/570 KB/4, 8 min, $2.0 | req 25/133/3/390/3, 6 min, $1.8 | arch 51/271/5/1,030/7, 20 min, $4.6 | stories 77/343/8/1,370/21, 87 min, $23.9 (9 adversary spawns $15.4 are p2 dispatched inside the window) | SR 89/467/6/960/13, 78 min, $16.5 (window 14:07-20:14 also holds impl gate-3 spawns for 2.2/2.3 under the SR label: 20 and 19 min adjudicator runs and a $5.6 code-reviewer) | retro 38/116/2/300/3, 16 min, $5.1.
s322: CO 20, req 24, arch 57, stories 23, SR 32, retro 27 min; 183 total, 1,015 calls, 14 compactions.
s321: req 27, arch 18, stories 16, SR 25 min (CO and retro unlabelled).
Class split of the s323 300 min (lead calls/min): other 491/112, merge (reading shard outputs, TaskOutput) 346/49, step-reread 170/35, snapshot 167/27, gate-run 146/25, idle-wait -/22, compaction-recovery 83/18, repair 18/7, dispatch 19/6. Re-reading plus recovery = 53 min (18%). Lead tokens in these windows: 214M cache-read (qwen38flash) + 16M (deepseek41), 1.0M out, 1,440 calls, i.e. about 160K cached tokens re-read per call: cost scales with CALL COUNT, not with what any call does.
Clean-gate anatomy, s323 retro (38 min, 116 calls, no FAIL; /private/tmp/.../steps/gate-validation/retro_tl.txt): 7 min Check 14 snapshot trim before the gate (2 hand-written trim scripts, advisor), 3 min working out how the gate runs (greps of enforcement-map.yaml and gate-validation.md), 1 min dispatch, 5 min waiting for 3 shards, merge refused once (shard 1/3 carried all 9 ids), compaction at 03:00 then a 2-minute re-read of 6 slices, 3 min of 20 evidence-collection Bash calls, 7 min writing gate-entry.md, 6 min of row checks plus 2 advisor calls before close.

WHAT FAILED AND WHAT IT COST (non-impl gates, repair records and gate logs)
s323 CO: Check 2 vocabulary, 2 tokens (CLOSED, DISPOSITIONED) in pending.md; remediator hook-denied; lead edited. s323 req: three arms (2a prose shape, vocabulary, 17 PRD report without provenance block; a subagent re-ran the PRD validate), all before the nonce. s323 arch: adjudicator FAIL Check 2 (entry headed 'OPEN' with no Status line), full re-dispatch of 3 shards, then Check 15 parser and Check 35 (65 lines destroyed by the lead's own trim, 68 recovered from git). s323 stories: Check 24 chain, Check 30, Check 5 repaired by three SERIAL remediators (7.6, 6.4, 9.3 min), 11:43 to 12:22 before the adjudicators could be dispatched; then the 8 shards took 1.3 min. s323 SR: Check 1 FAIL ('Tip:' prefix, APPROVED outside qa set, stale open MAJOR on a file the Step-1 one-shot overwrote), remediator 0.8 min, 4-shard re-dispatch 6.7 min wall. s323 retro: merge refused. s322: CO Check 2 (entry without Status); req Check 29 (EARS BEFORE-clause), 17 (stale PRD report), 1/J2 (record labels), 32 FP; arch Check 24 J2 drift (stem moved after MET, a real unreviewed edit); stories Check 30/24 with an operator-authorized reopen; SR Check 3 (real). s321: no non-impl FAIL in the records read.
Real catches in 3 sprints: s322 SR Check 3 (LR-S322-9 unanchored), s322 arch J2 drift, s323 Check 35 (self-inflicted loss), s322 Check 29 wording. Everything else is vocabulary/shape/linkage.

WHO READS WHAT EACH PART WRITES
- gate-log.md entry prose: Check 25 baseline (the lead compares by hand, :2515; no script reads steering_violations: grep of scripts/ and hooks/ returned 0, control gate_nonce 8 files), story_status read by sprint-status.sh, heading-block timestamp read by Check 15, header read by validate-mandatory-rules.sh. The per-check evidence rows (the bulk) are read by the next lead as a format template (retro lead read s322's entry, 03:01:49) and by the advisor; the archive is declared write-only (gate-log-archive.md 396 KB for s323 alone).
- gate-metrics.jsonl: machine-read by validate-suppression-lifetime.sh, validate-snapshot-conservation.sh, validate-escalation-resolution.sh, ai-dlc-gate-remediation-guard.sh. Real readers; a program can write it.
- gate-adjudication part/verdict files: validate-gate-adjudication.sh (Check 26, --series stall rung). Evidence prose in them is copied into gate-log rows.
- .gate-checkpoint ledger: gate-slice --done, resume, series rule. Repair records: Rule 28 guard parses column-0 fields (s322 SR needed a re-format to lift a deny).
- Snapshot row (Check 14): resume digest, next gate.

_gate-procedures.md (148,145 B, 1,822 lines, 5 code blocks); read 22 times/0.21 MB in s323 non-impl gates, 7/49 KB at impl gates
Sub-step snapshot update :16 (8.5K) SHRINK to script help. Bounded-join beat :156 (6.5K) KEEP (hook-backed). Gate-adjudication dispatch :217 (6.2K) KEEP, simplify to one dispatch of judgment checks only. Validation cycle :290 (34.7K), Adversarial review dispatch :697 (16K), Divergence resolution :858 (15.8K), Adversarial repair dispatch :1072 (39.8K): owned by the requirements/arch/stories hands; one structural fact for them: repair introduces the next pass's MAJORs (BL-508 count: s318 p1 17 of 29 MAJORs repair-introduced, p2 11 of 19; s322 stories p2 1 of 3), and s323 spent $319 (1,027 agent-min) on adversary spawns, 149 spawns, of which non-stories p2/p3 passes were 31 spawns $67.6. I did not re-derive the 14 pass-2 MAJORs the brief cites. Auto-handoff evaluation :1487 (13.9K) and Context reminder threshold :1730 (3.9K): not a gate duty; MOVE to the hook that already fires (ai-dlc-context-sensor.sh), the gate row only quotes it.
Advisor touchpoints at gates (SKILL.md:1135-1136, G1 entry, G2 before close; V1 after each repair): 21 calls, 11.9 min foreground in s323 non-impl gates; its catches were slips in hand-written entries (invented value, unverified merge claim, stale numbers). With a rendered entry, G1 has nothing to review before the arms run (the arms run in one call) and G2 reduces to the judgments.

## SENT 2026-11-20T12:09:58.293Z | gate-validation analysis part 3: corrections, redesign, unmeasured

GATE-VALIDATION part 3 of 3: corrections to part 2, redesign, unmeasured.

CORRECTIONS to part 2 (re-derived from gatereads.out and spawns): gate-file Read KB per s323 gate are CO 584, req 386, arch 951 (not 1,030), stories 1,103 (not 1,370), SR 960, retro 296; sum 4,280 KB. Req gate spawns are 3 adjudicator shards, 8 min (not 6). The SR pass-2 re-dispatch was 4 shards of 1.5-2.6 min plus a 0.8-min remediator, about 3 min wall (not 6.7; pass-1 shards ran to 6.0 min). H2 attests once per sprint already; each gate only runs --verify, so the cost there is one script call, not a finding.

G. THE REDESIGN (what I would do, larger than a tweak)
1. One program, `gate-run.sh --type <planning|story|sprint-review|retro> --sprint N`, generalising gate-transition.sh, which already does exactly this for one implementation gate 3 (core/scripts/gate-transition.sh header: runs Checks 2, 2a, 5, 16, 17, 22, 25, H2 in order, mints the nonce, runs `open`). It runs, from the manifest (gate-slice.sh already derives the set), every adjudication: script check and the script arm of every llm check with an enforcer, with the control each row needs, then prints one line per check `[core] N PASS|FAIL|NA <evidence>`; writes the ledger rows, the GATE_METRIC rows (it knows tok_slice from the file spans), the gate-log table body and the Check 14 snapshot call; Check 25 reads its own baseline. Exit non-zero lists every failing check at once, so the lead repairs once, not per arm.
2. The adjudicator is dispatched once, after the arms pass, for the checks no program can decide: 3 (LR drift in the body), 27 (routing sanity), 29 (spec kernel WHAT/HOW), core-layer-immutability at retro (and 9 at retro). Check 1, 4, 7, 16, 20, 21, 1c, 3a, 8 become program arms (grammar, grep, existence, table lookup; D1 fixes land first so no silent-skip hides in them). One shard, about 3 min.
3. The lead's gate text shrinks to: run the program; on FAIL read Gate Failure (:3618, 3.4 KB) and Gate Reset; dispatch the judgment adjudicator (:217 procedure, 6 KB); write only the prose fields a program cannot (Remediations, disclosures); close. Lead read per gate about 20 KB against 100-290 KB today; gate-validation.md would keep the check prose only as the spec the program implements and as the adjudicator's brief, never as a file the lead loads.
4. The consumer extension manifests gate_types per check (the Rule 27 `gate_types:` mechanism already exists), so graph's 73 KB domain file is not loaded at gates where its checks are NA.
5. Move validators to the producing step's last action (spec-join at architecture end, convergence/chain at the step's final repair, status draft->backlog in the story-authoring checklist, provenance block at PRD validate), so the gate sees PASS first time. Evidence: Check 30 failed at the story gate in 4 of 5 sprints, Check 2 vocabulary 3 events, Check 24 3, Check 17 3, Check 5 2.
6. Advisor G1 is dropped (nothing to review before one command); G2 kept before close for the judgments only.
Smallest version that keeps every catch: the s322 SR Check 3 and Check 2 catches become validator fixes; Check 29 stays a judgment; Check 35 and J2 drift stay scripts; the real catches count is unchanged.

Freed per sprint, UPPER BOUNDS, from s323 (target floor per gate 8-10 min is an estimate, not measured):
- lead active 300 min -> about 60 min: up to 4.0 h; s322 base 183 min gives up to 2.1 h. All on the lead's serial path (gates sit between steps), so it is wall clock.
- lead calls 1,440 -> about 300; cache-read tokens about 230M -> about 50M (up to 180M; at sonnet-class list prices roughly $50-70 token-equivalent, price basis not re-run).
- gate-file Reads 4.3 MB -> about 0.4 MB.
- compactions: up to 26 of 134 (those inside non-impl gate windows); the avoided re-read after each is 35 + 18 min of the 300.
- adjudicator spend $26 -> about $8 (one shard per gate), agent-min 112 -> about 25.
- serial remediators in the story gate (23 min agent time, $4.3, 42 min wall before dispatch) go if D2 is fixed at the producers: up to about 0.7 h in s323.
What could be lost: the evidence prose per row (nobody but the next lead and the advisor reads it); a check whose grammar the program gets wrong, hence build order: D1 validator fixes first, each program arm with a seeded-offender and a near-miss probe (verification-discipline.md), program output diffed against the s323 hand-written entries as the control. Engine files to change: core/scripts/gate-transition.sh (extend or sibling), core/scripts/gate-slice.sh, core/skills/ai-dlc/steps/gate-validation.md :161-221 (checklist preamble), :953-1136 (Check 12-13), :1137-1451 (Check 14-15), :2548-2705 (H1/H2), enforcement-map.yaml adjudication column for 1, 1c, 3a, 4, 7, 16, 20, 21, validate-escalation-status-vocabulary.sh, validate-locked-anchor.sh, validate-bmad-invocations.sh (Check 32 regex), core/scripts/validate-steering-budget.sh (read baseline).

H. NOT MEASURED
- Adversarial rounds dispatched inside a gate window (s323 stories: 9 adversary spawns, 41 min, $15.4) and impl gate-3 work under the SR label (BL-1003 leak) inflate the stories and SR rows; I did not split them. SR clean-path time (19:36-19:59 for the failed-then-passed gate itself, about 23 min wall) is read from the gate log, not the extraction.
- s321 CO and retro gates carry no gate-validation label (not measured); s322 pass-1 adjudication files for CO and req are rotated away, so those two FAILs come from the gate-log narrative.
- The H1 row of the s323 SR entry says 71,628 B loaded while gate-slice plans 101,515 B for that type; I do not know which reads the lead skipped.
- Tool latency is small (Bash 1-5 min per gate, Reads under 1 min) so I attribute the minutes to model time; I did not separate generation from queueing on the local model.
- The 14 pass-2 MAJORs, the value of adversarial pass series and the Validation cycle / repair dispatch sections (:290-1486) belong to the step hands; I measured only their spawn cost.
- Check 9/22/11/11a/19 (implementation) are the other hand's. The 135 gate-validation[pre-step] adjudicator transcripts (5.1 h agent-time in s323) are impl gate-3 shards and were not read.
- Whether every program arm exists as a script: Checks 1, 4, 7, 20 have no enforcer in enforcement-map.yaml today; building them is new code.
- No timing runs were taken. The 8-10 min floor and all freed-hours figures are upper bounds from the clean-gate windows (19-32 min) minus the parts a program removes.

## FINAL-TEXT 2026-11-20T12:10:06.150Z

I sent the gate-validation analysis to team-lead in three messages. My scripts and outputs are in `/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/steps/gate-validation/`. The `README.md` there names each script. Nothing was run for timing, and nothing outside that directory was written.

**Verdict:** gate validation should not exist in its current shape. It should become one program, `gate-run.sh --type X`, plus a single adjudicator for the few checks that need a model. The existing `gate-transition.sh` already does this for implementation gate 3.

**Cost of the planning gates (s323):**
- The lead spent 300 min active and made 1,440 calls across the six non-implementation gates.
- 26 of the sprint's 134 compactions fell inside these gates.
- The lead read 4.3 MB of gate files, about 230M cache-read tokens in all.
- 34 adjudicator shards cost $26 and 6 remediators $5.6.
- 21 advisor calls took 11.9 min of foreground time.
- Clean gates take 19–32 min of lead time. The s323 stories gate (77 min) and sprint-review gate (89 min) were driven by repairs and by work I could not separate out.
- The lead is mostly hand-running validators and hand-writing the gate log and snapshot rows.

**What the gates caught:**
- 28 of the 40 checks never failed across the 15 gates of s321–s323; the 12 that did are listed in message 1.
- The adjudicator had 5 FAILs in about 190 verdicts. Two came from validators that silently skip their subject; one was a real unanchored locked requirement (s322 sprint-review Check 3).
- Most repairs were records the pipeline wrote in a shape its own validator rejects. Check 30 failed at the story gate in 4 of 5 sprints (s319–s323).

**Upper bound if redesigned (not measured):** up to about 4 h of lead time per sprint, about 1,100 fewer lead calls, and about 3.9 MB less reading. The 8–10 min per-gate floor behind that figure is my estimate.

Message 3 corrects three per-gate figures from message 2: the Read KB for arch and stories, the req gate's shard minutes, and the sprint-review pass-2 wall time.

**Not separated:**
- Adversarial rounds dispatched inside a gate window, and implementation gate-3 work labelled under sprint-review, inflate the stories and sprint-review rows.
- I did not re-derive the 14 pass-2 MAJORs from the brief.
- The s321 carry-over and retro gates carry no gate label, so they are missing from the s321 totals.
- The s322 pass-1 FAIL records for carry-over and requirements are rotated away. Those two come from the gate-log narrative.

