# Findings of reader `hand-plan` (recovered verbatim from its transcript agent-ahand-plan-35181e3f36ea3d46.jsonl)

## FINAL-TEXT 2026-11-20T10:45:40.321Z

**Summary**
1. Of planning's 39.6 h, 13.1 h is operator ask pending, 18.5 h has at least one agent running, and 8.0 h is lead-only gap. Exactly one agent was running for 12.0 h (8.4 h of that a single remediator). In another 7.0 h the only thing happening was the local lead model's own turns between rounds.
2. One stall: a stories pass-2 adversary shard sat 49 min on a subagent Bash permission prompt. The lead polled it through four 10-minute beats before noticing. This is the only such case in 377 spawns of 15 min or more across s321-s323.
3. LANE-COUNT 1 rounds are real, but the lone-lane remediator time is about 1.1 h, not 6.2 h. A node is a file, not a section, and the five single-lane rounds I checked show 0 MOVED-CITE edges. Parallelizable work in the lone remediators is about 1.9 h (UB).
4. Pass 2 and pass 3 find almost only text the repair introduced or half-applied. End to end they cost about 4.2 h and $113. Narrowing by part is a no-op because the p1 repair touched every part.
5. Readiness, trace and PRD validate are cheap in s323: readiness about 0.7 min, trace about 1.1 min, PRD validate about 12 min inside the authoring chain. BL-1175 item 3's 0.5-1.2 h and $5-11 is roughly 10x too high for readiness and trace. The step-overlap upper bound is about 5.7 h with real rework risk, because LR-S323-32 to 38 arrived late and the spine cites them.

**Method.** I used `spawns.jsonl` plus the four lead transcripts (`0ef7ba46`, `68cf8de7`, `4b34031d`, `53b4296a`) and the subagent transcripts. The step windows are the real step boundaries (the `segs.jsonl` rows with sprint 323). They sum to 39.6 h, but per-step numbers differ from the extractor's labels. Handoff idle (the 4,973 min between sessions, 15:19 to 16:02 on 11-17, 00:33 to 02:18 on 11-18) is excluded. Cluster counts are spawns grouped with a 120 s tolerance. Control: ask intervals sum to 12.5 h with `AskUserQuestion` call and result paired, which matches your 12.5 h. s321 and s322 were not measured, except the stall scan (377 spawns of 15 min or more across s321-s323).

## 1. Timeline per step

Hours, real step boundaries, s323:

| Step | Wall | Ask pending | Agent running | Lead-only | Rounds |
|---|--:|--:|--:|--:|--:|
| carry-over | 8.4 | 3.1 | 4.0 | 1.4 | 14 |
| requirements | 16.9 | 10.0 | 4.9 | 2.1 | 21 |
| architecture | 5.2 | 0 | 3.1 | 2.1 | 14 |
| stories | 9.1 | 0 | 6.5 | 2.6 | 19 |

Each step runs party seats, party repair, adjudicate and serial repair, elicitation, elicitation repair, adversarial p1, repair, p2 verifier, post-MET repair, then the gate. For example, requirements ran:
- party 07:21-07:53 (46 agents, peak 22);
- party serial passes p1-p6 12:49-14:39;
- elicitation 14:44-14:55 (16 agents);
- p1 17:16-17:55 (15 adversaries + 24 remediators);
- p2 19:23-19:46;
- post-MET 19:52-20:04;
- gate 20:31.

Concurrency by step, in hours: exactly 1 agent 2.5 / 4.1 / 1.8 / 3.6 (carry / req / arch / stories). 10 or more agents: 0.07 / 0.29 / 0.09 / 0.70.

**Ask markers (UTC).** All lanes were finished and waiting behind the asks marked "finished":

| Window | Length | What was finished |
|---|--:|---|
| 11-13 09:33 | 148 min | Day-0 ops dispatched while the ask sat (2 agents overlapping) |
| 11-13 12:32 | 20 min | |
| 11-17 03:43 (OQ1-3) | 200 min | |
| 11-17 07:36 | 300 min | All 14 party-repair lanes finished by 07:53 |
| 11-17 13:03, 13:43, 16:20, 18:41 | 25, 19, 21, 19 min | |

**Lead-only gaps.** The 8.0 h across 64 gaps averages 7.5 min per gap. Of it, 7.0 h (88%) is lead model turns after a result or notification. Advisor consults take 0.39 h, and all validators together 0.09 h. The lead made 4,859 calls in planning. Of the Bash calls, 146 were `snapshot-update.sh`, 129 `wait-for-deliverable.sh`, 52 `join-remediator-shards.sh` and 18 `merge-adversarial-shards.sh`.

Top gaps by lead-active minutes:

| Where | Active | What filled it |
|---|--:|---|
| stories 11:15 | 28 | 104 Bash, 61 Read: gate validators before gate repair |
| requirements 20:04 | 26 | 73 Bash, 53 Read, 3 advisor: gate procedure |
| architecture 00:31 | 24.5 | 64 Bash, 25 Read: p2 join and escalations |
| requirements 15:17 | 21 | 99 Bash, 14 `TaskStop` |
| architecture 02:34 | 18 | gate |
| stories 03:44 | 15 | writing 77 party briefs |
| carry-over 02:57 | 14 | |
| architecture 03:04 | 12 | |
| requirements 19:11 | 12 | |
| architecture 23:13 | 11 | |

## 2. Serial remediator

**Unlabelled spawns.** The 153 spawns without a pass label (requirements 74, stories 79) are the per-part repair shards of the party and elicitation rounds. Descriptions are "Party repair part N/N", "Elicitation repair part N", "Lane N remediator", "Remediator shard N", "Remediate story N-N" and "Repair shard N". They run 12-24 wide, with a median of 1-4 min and tails of 13-25 min.

**The 49 singleton remediator spawns** (no other remediator running) total 6.7 h and $100.6. Beyond those, about 1.7 h more is the tail of parallel rounds, where one remediator is still running (wall-clock hours with exactly one remediator and no other agent: 8.4 h).

| Purpose | Spawns | Minutes | $ |
|---|--:|--:|--:|
| fan-in / cross-section serial | 12 | 147 | 36.5 |
| carry an operator answer into the documents | 8 | 69 | 17.8 |
| single-lane serial | 6 | 68 | 16.9 |
| serial pass (pN / post-MET) | 8 | 68 | 18.0 |
| gate repair | 5 | 27 | 5.1 |
| record mechanics (fences, renders, seals) | 10 | 24 | 5.9 |

Per step: carry-over 12 spawns and 87 min; requirements 19 and 163 min; architecture 7 and 70 min; stories 11 and 82 min.

**Edits.** These 49 made 1,236 Edit/Write calls: 693 (56%) on their own record files and 543 on documents. Document edits fall in many distinct sections: the 30-min "Lane serial repair spine" made 35 edits in 10 sections, and "Fan-in serial remediation" 46 edits in 12 sections across 5 files. I located 75% of edits by heading, so these are lower bounds.

**What binds.** The binding constraint is the join's node definition, not a "document mode" flag as such.
- `core/scripts/join-remediator-shards.sh:978-981`: a node is a file, mapped to the assembled document in document mode.
- `core/scripts/join-remediator-shards.sh:986-988`: a failed worklist joins every file into one lane.
- `.join-plan` shows LANE-COUNT 1 with 0 MOVED-CITE edges for these rounds: architecture-party-repair (41 serial items), ARCHITECTURE-SPINE elicitation and repair, coe-repair-p1 and p2, coe-elicitation, test-strategy-repair-p1.
- Where sections do interact, the worklist found edges: requirements-party-repair 31, requirements-repair-p1 23. requirements-elicitation-repair had no worklist at all (UNASSESSED: no pre-repair copy of SPEC.md), so its edges are unknown.

**Finding (DEFECT).** Section-keyed lanes would work for the single-document artifacts (carry-over-evaluation.md, ARCHITECTURE-SPINE.md, test-strategy.md). Make a node a (file, heading) pair with MOVED-CITE edges as today.
- Gain: the single-lane class is 1.1 h. At the join's own k = min(4, floor(n/2)) that saves at most about 0.8 h wall, with about the same agent-minutes ($0).
- Larger and needing no engine code: the operator-answer fold. It ran as one serial agent, e.g. "Carry cap-all-three answer" with edits across `prd.md` 17, `product-brief.md` 9, `architecture-impact.md` 2 and `locked-requirements.md` 1. One writer per file would take 1.15 h to about 0.3 h (UB 0.85 h).
- Fan-in stays serial by design (the 2.4 h class).
- Total reachable 1.7-1.9 h per sprint (UB); lost catch: the cross-section sibling grep that only a single serial writer owes.

**Record mechanics (NOTE).** Fence re-derivation, renders and seals ran as 23 spawns, 57.9 agent-minutes and $12.7 (10 of them alone, 23.5 min). Serial passes p4-p6 in requirements were the same kind of work ("stale fences", "invalid source token"). A script could re-derive fences.

**Serial passes p2-p6 in requirements.** They were triggered by operator answers landing one at a time (4 min to 14 min each, with 3-28 min of lead gap between them), not by new findings.

## 3. Convergence (s323, findings counted from the merged adversarial records)

| Artifact | p1 | p2 | p3 |
|---|---|---|---|
| carry-over | 13 MAJOR, 5 MINOR | 7 MAJOR, 6 MINOR | 1 MAJOR, 2 MINOR |
| requirements | 1 CRIT, 28 MAJOR, 28 MINOR | 3 MAJOR, 12 MINOR | none (MET) |
| architecture | 9 MAJOR, 9 MINOR | 2 MAJOR, 10 MINOR | none |
| stories | 2 CRIT, 25 MAJOR, 58 MINOR | 2 MAJOR, 20 MINOR | none |
| test-strategy | 3 MAJOR, 1 MINOR | none | none |

I classified "repair-introduced or half-applied" by reading headings, so it is a judgment, not a mechanical count.
- Requirements p2: 15 of 15 are stale-after-repair or propagation misses ("went stale again after LR-37/-38", "the F-4 caption quotes a phrase the body no longer contains").
- Carry-over p2 and p3: about 16 of 16.
- Architecture p2: about 10 of 12 ("still says the two sites, the amendment made three").
- Stories p2: about 16 of 22.
- The two stories p2 MAJORs were both claims the F-1 repair added without a derivation. They survived p1 and were caught only by p2.

**Why pass 2 is full width.** The engine already narrows by part digest (`_gate-procedures.md:798`), but the p1 repair changed every part. Shard counts: requirements 16 and 16, stories 20 and 20, architecture 6 and 6. stories-repair-p1 had LANE-COUNT 18 of 18 stories repaired. Narrowing by part therefore removes nothing; only hunk-level narrowing could. In stories the p2 shard median is 4.5 min against 5.4 for p1, so the per-shard saving is small.

**What the p2/p3 rounds add end to end:**

| Artifact | Wall | Cost |
|---|---|---|
| requirements p2 + repair | 0.7 h | $27 |
| architecture p2 + repair | 0.8 h | $16 |
| stories p2 + repair | 1.6 h (0.8 h without the stall) | $42 |
| carry-over p2 + p3 | 1.1 h | $26 |
| **Total** | about 4.2 h | about $113 |

**Finding (NOTE).** Do not drop pass 2; the repair introduces MAJOR defects it exists to catch. The efficiency lever is on the repair side (self-check of newly added claims, UB unknown), not a narrower p2.

## 4. Step ordering

**What changed late.** Document edit volume (characters written) per phase of requirements was: party repair 151k (35%), elicitation 148k (34%), p1 plus answers 90k (21%), p2 plus post 43k (10%). Architecture was 54% party and 5% in p2 and post. Stories were 2% in p2 and later. Git history has no intermediate planning commits, so these come from remediator Edit calls, not diffs.

**What the next step consumed.** LR-S323-25 to 31 arrived at 14:27, 32-36 at 16:56, LR-37 at 18:30 and LR-38 at 19:05. The spine cites LR-32 (2 times), LR-36 (5), LR-37 (2) and LR-38 (4). The s322 spine has 0 hits on those ids, which is not a true control. Architecture started at 20:48 on the final requirements.

**Overlap upper bounds (hours, not dollars):**
- Architecture from requirements' tail: about 1.6 h (p2, post-MET and gate after 19:05). The rework risk is real: p2 findings at 19:23 included "architecture-impact never carries the LR-36 retry".
- Stories from the architecture tail (p2 16 min, 24 min lead, post-MET 9 min, gate about 50 min): about 1.7 h. The p2 findings changed rule counts the stories cite (AD-15).
- Carry-over tail (p1-p3 and gate, 2.4 h) alongside requirements start: about 2.4 h. The next ask was asked at 03:43 and answered at 07:03; asking earlier would not obviously be answered earlier.
- Total about 5.7 h (UB).

## 5. Fixed rounds

These ran inside authoring chains, so they are not separate spawns.

| Round | Duration | Cost | Outcome |
|---|---|---|---|
| Architecture readiness (`bmad-sprint-planning intent=readiness`) | about 0.7 min in the chain (14.9-15.6 min) | under $1 | 6 findings, 4 repaired (R-1, 3, 4, 6); the routing and wording repairs took 3.1 min and $0.61 |
| PRD validate | about 12 min of a 31-min chain (13.5-25.7) | about $5 (proportional estimate) | its HIGH finding was answered by the spine's per-site table |
| Test-strategy trace (`bmad-testarch-trace`) | about 1.1 min (17.9-19.0) | under $1 | |
| Party rounds | carry-over 89 min, requirements 32, architecture 17, stories 27 | $259 (seat clusters) | party repair entries repaired: carry-over 118, requirements 115, architecture 41, stories 191, plus serial |

BL-1175 item 3's estimate is far above the s323 reading. Party rounds are the highest-yield planning round; do not cut them. I did not re-derive the `step-value-*` readings.

## 6. The stall (DEFECT)

Shard 06 of the stories p2 round (`Adversary shard 06`, opus, 29 calls) ran from 08:40:37 to 09:33:29. Its Bash call at 08:44:22 (a scratch pytest.ini write) never returned until the lead `TaskStop`ped it at 09:33:29 ("The user doesn't want to proceed with this tool use"). The lead meanwhile ran 10-minute `wait-for-deliverable.sh --complete` beats at 08:50, 09:00, 09:10, 09:21 and 09:32.
- The beat length is `_dispatch-protocol.md:255` (`AI_DLC_WAIT_BEAT_SECS=540`).
- A progress check exists at `_gate-procedures.md:213` (`--status`) but was not used.
- Change: have the beat print each undelivered shard's transcript age and name any shard silent for 2 beats.
- Gain: about 0.7 h per occurrence, once in this corpus. Per-sprint value is at most 0.7 h and $0 (UB).
- Separately, the subagent needed a permission for a scratch write; I did not trace why it prompted.

## What I found already efficient
- Remediator parallel rounds: medians of 1-4 min.
- Validators in gaps total 0.09 h.
- Adversary shard times are even except the stall.
- The BMAD readiness and trace calls cost about a minute each.

**Not measured.** s321/s322 round timelines; per-edit interaction between sections for the remediators beyond the 4 largest; lead dollars (local model); whether the OQ asks could have been asked earlier.

Files read were transcripts and artifacts under `~/.claude/projects/-Users-n8-git-graph/` and graph's `_bmad-output/planning-artifacts/s323`, plus `/Users/n8/git/ai-dlc/core/scripts/join-remediator-shards.sh` and the step text under `core/skills/ai-dlc/steps/`. My scratch work is in `/var/folders/yz/_m377xss13g_h6cfz2wt0kdc0000gn/T/c10pl4yhh8aic`.

## SENT 2026-11-20T10:45:58.713Z | Resend part 1: section 1 remainder and section 2

PART 1 of 3 (resend from the top-gaps table onward).

Top gaps by lead-active minutes (all lead-only time between rounds; "act" = lead active minutes in the gap):
1. stories 11:15, 28 min: 104 Bash, 61 Read, 3 advisor. Gate validators before gate repair.
2. requirements 20:04, 26 min: 73 Bash, 53 Read, 24 ctx_execute, 5 Edit, 3 advisor. Gate procedure.
3. architecture 00:31, 24.5 min: 64 Bash, 25 Read. p2 join and escalation processing.
4. requirements 15:17, 21 min: 99 Bash, 14 TaskStop. After the 24-remediator elicitation repair.
5. architecture 02:34, 18 min: 89 Bash, 45 Read, 8 Edit. Gate.
6. stories 03:44, 15 min: 40 Bash, 17 Read, 3 Write, 1 Skill. Building 77 party briefs.
7. carry-over 02:57, 14 min: 42 ctx_execute, 37 Bash.
8. architecture 03:04, 12 min: gate.
9. requirements 19:11, 12 min: 18 Bash, 15 Read.
10. architecture 23:13, 11 min: 67 Bash, 2 advisor.

Lead-only totals: 8.0 h over 64 gaps (mean 7.5 min). 7.0 h (88%) is the lead model's own turns after a tool result or notification; advisor consults 0.39 h; all validators 0.09 h; join/merge/partition scripts 0.06 h. The lead made 4,859 calls in the planning windows (Bash 2,465, Read 936, ctx_execute 568, Agent 417, advisor 64). Bash included 146 snapshot-update.sh, 129 wait-for-deliverable.sh, 52 join-remediator-shards.sh, 18 merge-adversarial-shards.sh.

Method note: step windows are real step boundaries and sum to 39.6 h; they differ from the extractor's per-step labels. Handoff idle excluded. Ask intervals pair AskUserQuestion call with result and sum to 12.5 h in the lead's window (13.1 h in mine), matching your 12.5.

SECTION 2. SERIAL REMEDIATOR
The 153 unlabelled spawns (requirements 74, stories 79) are per-part repair shards of the party and elicitation rounds: "Party repair part N/N", "Elicitation repair part N", "Lane N remediator", "Remediator shard N", "Remediate story N-N", "Repair shard N". Parallel, 12-24 wide, median 1-4 min, tails 13-25 min.

The 49 singleton remediator spawns (no other remediator running at once) total 6.7 h and $100.6. About 1.7 h more is the tail of parallel rounds with one remediator left (wall hours with exactly one agent running and it a remediator: 8.4 h).
- fan-in / cross-section serial: 12 spawns, 147 min, $36.5
- carry an operator answer into the documents: 8, 69 min, $17.8
- single-lane serial: 6, 68 min, $16.9
- serial pass (pN / post-MET): 8, 68 min, $18.0
- gate repair: 5, 27 min, $5.1
- record mechanics (fences, renders, seals): 10, 24 min, $5.9
Per step: carry-over 12 spawns / 87 min; requirements 19 / 163; architecture 7 / 70; stories 11 / 82.

Edits: these 49 made 1,236 Edit/Write calls, 693 (56%) on their own record files and 543 on documents. Document edits are spread: "Lane serial repair spine" 35 edits in 10 sections of ARCHITECTURE-SPINE.md; "Fan-in serial remediation" 46 edits in 12 sections across 5 files. I located 75% of edits by heading, so these are lower bounds.

What sets one lane: the join's node definition, not "document mode" alone.
- core/scripts/join-remediator-shards.sh:978-981: a node is a FILE; in document mode every section maps to the assembled document.
- :986-988: a failed or missing worklist joins every file into one lane.
- .join-plan files: LANE-COUNT 1 with 0 MOVED-CITE edges for architecture-party-repair-p1 (41 serial items), ARCHITECTURE-SPINE-elicitation-repair-p1, ARCHITECTURE-SPINE-repair-p1, coe-repair-p1 (31 lane items), coe-repair-p2, coe-elicitation-repair-p1, test-strategy-repair-p1.
- Where sections do interact the worklist finds edges: requirements-party-repair 31, requirements-repair-p1 23 (LANE-COUNT 4 and 2). requirements-elicitation-repair was UNASSESSED (SPEC.md had no pre-repair copy), so its edges are unknown.
- Step text: skills/ai-dlc/steps/_gate-procedures.md:1157 (one serial remediator per lane), :1169-1171 (fan-in; LANE-COUNT 1 FANIN-COUNT 0 is one lane).

Engine change A (DEFECT): section-keyed lanes for single-document artifacts (carry-over-evaluation.md, ARCHITECTURE-SPINE.md, test-strategy.md): node = (file, heading), MOVED-CITE edges as today, k = min(4, floor(n/2)) as the join already uses for adjudication. Gain: single-lane class is 1.1 h; at most about 0.8 h wall per sprint (UB), about $0 (same agent-minutes). Catch at risk: the sibling grep and moved-cite check only one serial writer owes within a lane.

Engine change B (DEFECT, no join code needed): the operator-answer fold ran as one serial agent although it edits disjoint files. Example "Carry cap-all-three answer into artifacts": prd.md 17 edits, product-brief.md 9, architecture-impact.md 2, locked-requirements.md 1. Brief one writer per file. Class is 1.15 h; UB saving about 0.85 h per sprint, about $0. Catch at risk: cross-file consistency, which the lead's gate already re-checks. Change site: the brief text at _gate-procedures.md:1157-1171.

Fan-in/cross-section class (2.4 h) stays serial by design.

NOTE, record mechanics: fence re-derivation, renders and seals ran as 23 spawns, 57.9 agent-minutes, $12.7 (10 alone, 23.5 min); requirements serial passes p4-p6 (stale fences, invalid source token) are the same kind of work. Serial passes p2-p6 in requirements were triggered by operator answers landing one at a time, not by new findings. A script could re-derive fences; UB about 0.4 h and $6 per sprint.

Total reachable from section 2 (UB): 1.7-1.9 h per sprint.

## SENT 2026-11-20T10:46:09.978Z | Resend part 2: sections 3 and 4

PART 2 of 3.

SECTION 3. CONVERGENCE (s323, counted from merged adversarial records)
Findings by severity:
- carry-over: p1 13 MAJOR 5 MINOR; p2 7 MAJOR 6 MINOR; p3 1 MAJOR 2 MINOR
- requirements: p1 1 CRITICAL 28 MAJOR 28 MINOR; p2 3 MAJOR 12 MINOR; no p3 (MET)
- architecture: p1 9 MAJOR 9 MINOR; p2 2 MAJOR 10 MINOR; no p3
- stories: p1 2 CRITICAL 25 MAJOR 58 MINOR; p2 2 MAJOR 20 MINOR; no p3
- test-strategy: p1 3 MAJOR 1 MINOR; no p2

Repair-introduced vs missed: judged by reading headings (a judgment, not a mechanical count).
- requirements p2: 15 of 15 on text the repair added or left stale (e.g. "answer range went stale again after LR-S323-37/-38", "caption quotes a phrase the body no longer contains").
- carry-over p2 and p3: about 16 of 16.
- architecture p2: about 10 of 12 ("still says two build sites, the amendment made three").
- stories p2: about 16 of 22. Both stories p2 MAJORs are claims the F-1 repair added without a derivation; they survived p1 and only p2 caught them.
Survivors to the final artifact: every p1 and p2 finding marked repaired changed the artifact; p3 residue was 3 findings in carry-over.

Why pass 2 ran full width: the engine already narrows by part digest (_gate-procedures.md:798, full-width reason where a list is missing), but the p1 repair changed every part. Shard counts p1 vs p2: requirements 16/16, stories 20/20, architecture 6/6; stories-repair-p1 had LANE-COUNT 18 of 18 stories repaired. So part-level narrowing removes nothing. Stories p2 shard median 4.5 min vs p1 5.4, so hunk-level narrowing would save little per shard.

Pass 2/3 end to end (its own round + the repair round it triggers + lead gap):
- requirements p2 + post-MET: 0.7 h, $27
- architecture p2 + post-MET: 0.8 h, $16
- stories p2 + repair: 1.6 h (0.8 h without the stall in section 6), $42
- carry-over p2 + p3: 1.1 h, $26
Total about 4.2 h and $113 per sprint (3.4 h without the stall). These are costs, not removable amounts.

Recommendation (NOTE): keep pass 2. It earns its cost by catching repair-introduced MAJORs. A narrower verification would be hunk-level only and saves minutes. The lever is on the repair side (the remediator self-checking claims it adds); I did not measure its upper bound. Catch lost if p2 were dropped: the 14 MAJORs above (carry-over 7+1, requirements 3, architecture 2, stories 2).

SECTION 4. STEP ORDERING
Edit volume (characters written to documents by remediators) per phase:
- requirements: party repair 151k (35%), elicitation 148k (34%), p1 + answers 90k (21%), p2 + post 43k (10%)
- architecture: party 59k, elicitation 25k, p1 18k, p2/post 5k (5%)
- stories: party 199k, elicitation 36k, p1 37k, p2 5.6k, later 1k (2%)
Git history in graph has no intermediate planning commits, so these come from remediator Edit calls, not diffs.

What the next step consumed: LR-S323 ids first written to the requirements documents: 25-31 at 14:27, 32-36 at 16:56, 37 at 18:30, 38 at 19:05 (all 11-17). The final spine cites LR-32 (2x), 36 (5x), 37 (2x), 38 (4x). Control: LR-S323-9999 returns 0 in the same file. Architecture started at 20:48 on the final requirements; architecture-impact.md and the readiness routing also flow back into the PRD (existing back-edge: "Route readiness findings to PRD").

Overlap upper bounds (hours only; overlap saves no dollars and adds rework cost):
- architecture from requirements' tail after LR-38 (19:05): p2 19:23-19:46, post-MET 19:52-20:04, gate to 20:41: about 1.6 h. Risk: p2 findings at 19:23 included "architecture-impact never carries the LR-36 retry".
- stories from architecture's tail (p2 16 min, 24 min lead, post-MET 9 min, gate about 50 min): about 1.7 h. Risk: architecture p2 changed AD-15 site counts that stories cite.
- requirements start alongside carry-over p1-p3 + gate (00:34-02:57): about 2.4 h. The OQ ask at 03:43 was answered at 07:03; asking earlier does not obviously get an earlier answer.
Total about 5.7 h per sprint (UB), medium to high rework risk. Catch at risk: the late LRs (retry rule, cap-all-three) are substantive operator decisions the spine depends on.

## SENT 2026-11-20T10:46:23.509Z | Resend part 3: sections 5, 6 and engine change list

PART 3 of 3.

SECTION 5. FIXED PER-SPRINT ROUNDS (they ran inside authoring chains, not as separate spawns)
- Architecture readiness (Skill bmad-sprint-planning intent=readiness): about 0.7 min inside the 21-min architecture chain (14.9 to 15.6 min), under $1. It returned CONCERNS with 6 findings; 4 were repaired (R-1, R-3, R-4, R-6 in architecture-readiness-repair-p1.md) and the pm routing took 3.1 min and $0.61.
- PRD validate (bmad-prd VALIDATE plus a "PRD rubric walker validation" subagent): about 12 min of the 31-min requirements chain (13.5 to 25.7 min), about $5 by proportion of the chain's $13.7 (an estimate). Its HIGH finding was answered by the spine's per-site table.
- Test-strategy trace (bmad-testarch-trace): about 1.1 min (17.9 to 19.0 min of the 24-min chain), under $1.
- bmad-spec validate: one call at +30.2 min in the requirements chain, under 1 min.
- Party rounds: carry-over first cluster 89 min, $68; requirements 32 min, $51; architecture 17 min, $39; stories 27 min, $102. Entries repaired from party rounds: carry-over 118, requirements 115, architecture 41, stories 191, plus serial records. This is the highest-yield planning round; I do not recommend cutting it.
- BL-1175 item 3 estimated 0.5-1.2 h and $5-11 per sprint for readiness calls. In s323 the readiness and trace calls total about 2 min and under $2. The ceiling of that item is therefore about 0.05 h, not 0.5-1.2 h (s323 only; I did not read s321/s322). The readiness call also caught 4 repaired findings, so removal would lose real catches.
I did not re-derive the step-value-* files.

SECTION 6. THE STALL (DEFECT)
Stories p2 round, "Adversary shard 06" (opus, 29 calls), 08:40:37 to 09:33:29 UTC on 11-18. Its Bash call at 08:44:22 (a scratch pytest.ini write) never returned; it ended when the lead TaskStopped it at 09:33:29 ("The user doesn't want to proceed with this tool use"). Round wall clock 62 min against a shard median 4.5 min. Meanwhile the lead ran 10-minute wait-for-deliverable.sh --complete beats at 08:50, 09:00, 09:10, 09:21 and 09:32 and saw nothing. Population: 377 spawns of 15 min or more across s321-s323 were scanned for a gap over 600 s ending in a rejected tool result; this is the only hit. All 564 s323 planning spawns were scanned for any gap over 300 s: 13 gaps, 2.1 h total, of which this one is 49 min (the rest are model gaps and tool waits of 5-10 min).
- Cause text: skills/ai-dlc/steps/_dispatch-protocol.md:255 sets AI_DLC_WAIT_BEAT_SECS=540; skills/ai-dlc/steps/_gate-procedures.md:213 has a --status progress check that was not used between beats.
- Engine change C: have each beat print every undelivered shard's transcript age and name any shard silent for two beats, so the lead re-dispatches at about 10-20 min. Saving about 0.5-0.7 h per occurrence; one occurrence in the three sprints measured, so per-sprint value is at most 0.7 h (UB), $0. Catch lost: none; a re-run shard replaces the hung one.
- Separate, unexamined: why a subagent needed a permission for a scratch write.

ENGINE CHANGES, RANKED (hours per sprint are upper bounds, wall clock unless noted)
1. Lead-only gaps (8.0 h, 88% lead model turns, 4,859 calls). Change: one script call per round boundary that runs the join, writes the plan file, and prints ready dispatch briefs, instead of the lead reading the plan and retyping lane and fan-in briefs. Cite: join-remediator-shards.sh:975-1031 and :2636-2830 already print the plan; _gate-procedures.md:1123-1177 tells the lead to read it and dispatch by hand. I did not measure turns per gap, so I give no hour figure; I would not claim more than a fraction of the 7.0 h. Catch at risk: the lead's per-round judgment (adjudication of escalations).
2. Operator-answer fold by file in parallel (B above): UB 0.85 h, $0.
3. Section-keyed lanes (A above): UB 0.8 h, $0.
4. Stall detection in the wait beat (C above): UB 0.7 h, $0.
5. Record-mechanics script (fence re-derivation, renders, seals): UB 0.4 h, about $6.
6. Step overlap (section 4): UB 5.7 h, no dollars, high rework risk; not recommended before items 1-5.
Sum of 2-5: about 2.8 h (UB, overlapping classes not double counted only approximately). Planning stays dominated by operator ask wait (13.1 h in my windows) and agent-running rounds (18.5 h), of which 12.0 h had exactly one agent running.

NOT MEASURED: s321/s322 round timelines; per-edit interaction between sections for remediators beyond the four largest; lead dollars (local model); turns per lead gap; whether the OQ asks could have been asked earlier. Scratch dir: /var/folders/yz/_m377xss13g_h6cfz2wt0kdc0000gn/T/c10pl4yhh8aic

