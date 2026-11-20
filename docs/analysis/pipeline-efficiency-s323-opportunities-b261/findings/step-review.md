# Findings of reader `step-review` (recovered verbatim from its transcript agent-astep-review-984e6679adc491c8.jsonl)

## SENT 2026-11-20T12:14:27.383Z | sprint-review step analysis part 1 of 3

SPRINT-REVIEW (+gate[sprint-review]) PART 1/3 — summary and what the step is told to do. Scripts: /private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/steps/sprint-review/ (README.md names each file).

SUMMARY
1. Cost, step spawns only (spawns.jsonl, labels sprint-review + gate[sprint-review]): s321 169 spawns $209.09; s322 65 $82.08; s323 171 $225.54 (phases.py reproduces the seat control rows of the two earlier readings: s321 125/$144.06, s322 40/$47.24). The brief's $236/$101/$280 is a different basis: gaps $27/$19/$55 are NOT the lead (roll_classes lead token-eq for s323 sprint-review+gate = $3.02); unreconciled, see part 3 H.
2. s323 wall by the step's own parts, transcript timestamps, excluding the 195 min operator wait and the 179 min that stories 2.1-2.3 took: 361 min = 6.0 h. Of it, 57 min was the lead blocked inside AskUserQuestion with both Step-3 reviewers already finished; 19 min was a rate-limit failure of the party round; 53 min was a story-branch integration repair that no engine file owns; 85 min was a third adversary pass plus its fix loop.
3. Biggest waste (UPPER BOUNDS, one sprint each): blocking operator ask 48 min; rate-limit fan-out $22.49 + 19 min (0 such spawns in s321/s322, control s323 = 36); adversary passes 2 and 3 against the step's own "ONE-SHOT" rule $12.81 + 33 agent-min; second gate round $2.78 + 16 min.
4. What earns its place: the party round (13 distinct major defects in s323, 10 changed shipped artifacts, survival checked at squash eabdc576e), the fix re-reviews (BOTH s323 fix batches came back NEEDS_REWORK with repair-introduced defects, one Critical: a new live test that could never pass), adversary pass 1 (SA-1 Critical: 5 of 15 done stories never merged).
5. Verdict: the step needs to exist but not in this shape. Keep adversary-once, party round, fix re-review. Script the integration check, the gate's verdict-line grammar and seat dispatch retry. CUT sprint-review-next (0 Reads in 176 lead transcripts, control 87). Take operator asks out of the step.

A. WHAT THE STEP IS TOLD TO DO (core/skills/ai-dlc/steps/sprint-review.md, 186 lines, 10,167 B, 1 code block; graph's installed copy 10,057 B, differs only by the READ AND FOLLOW chunk-size clause at line 186. sprint-review-next.md 76 lines, 3,705 B)
Parts, in order:
- L15-16 "all sub-skills back-to-back without pausing for human input" (the lead paused twice in s323, see D).
- L18-29 Sprint-Overall PR pre-staging rule: prose, no action here; only reader is deploy-validate.md:35 (lead check by prose). Judgment, no enforcer.
- L31-52 Step 0 freshness: git fetch + rev-list count (script-shaped; 1 call in s323, count 0).
- L54-86 Step 1 sprint adversary one-shot: join beat L56-60, review bullets L63-80 (composed diff; operator request re-read L72-76), snapshot update, Seam D eval L82-86.
- L88-122 Step 2 party round: PM/Architect/Dev/TEA/QA, one agent per (seat, story) plus one cross agent per seat, seat-complete lines, waves, count join L100-109; minimum-mechanism text L117-122.
- L124-166 Step 3 fix and re-validate: dev fixes, re-review, QA, repeat; core-path seam non-deferral L132-157; un-exercised branch L159-166.
- L168-186 Step 4: validate-handoff-evidence.sh --strategy HEAD L170-177, Seam B L179-181, gate-validation [sprint-review] L181-184 (Check 20 reads Steps 1-2 as the minimum), READ AND FOLLOW deploy-validate.
- sprint-review-next.md: context load, relevance check, validation cycle on next sprint's stories, commit, gate. Entered from deploy-validate.md:750 and route.md:519.
Script-carryable versus judgment: roughly 70 lines are procedure a program already carries or could (Step 0, joins L56-60 and L103-109, validator L170-177, gate call); roughly 60 lines are judgment (L63-80, L110-115, L132-166); the rest is rule prose. The step also delegates to _gate-procedures.md (1,821 lines, 148 KB, Validation-cycle item 1 at about L440-480, waves L471-477) and gate-validation.md (3,703 lines, 247 KB), which the lead re-read in slices: 50 step/gate-file Reads in the 51-min s323 gate.

NOT IN THE STEP FILE BUT DONE INSIDE IT: integrating story branches into the sprint branch. grep of core/ and graph's installed engine for the commit subject the lead wrote ("Merge story X into s323 sprint branch (all three gates passed...)") returns 0 (control: wait-for-deliverable returns 125 files); implementation.md has no merge-into-sprint-branch procedure; is-ancestor appears only in update machinery.

B+C+E. PER-PART TABLE, s323 (UTC 2026-11-19; lead-active = event gaps <= 300 s; agent-active = same rule on subagent transcripts; spawn minutes include resume gaps and overstate: Step-3 QA span 60.5 min, active 4)
P  | part | wall | lead-act | spawns/$ (agent-active) | critical path? | what it produced and caught
A | Step 0 + adversary pass 1 02:53-03:05 | 12 | 4 | 1 / $4.74 (12) | yes | sprint-adversarial (SA-1 Critical: stories 1.2,1.3,1.4,3.2,5.2 never merged; SA-2 Important, SA-3 APP_ENV, SA-4, SA-5)
B | integration repair 03:05-03:58 | 53 | 53 | 6 / $10.03 | yes | merge resolution x2, suites, fix 1.4 bootstrap; step file does not describe it
C | adversary pass 2 + fix 03:58-04:36 | 38 | 16 | 2 / $11.63 (30) | yes | MAJOR: operator item 2 not delivered by composed diff, 2.1-2.3 "operator-held" without a quote; asked operator
D | operator ask, handoff | 195 wait + 9 | - | - | blocking | answer "Build all three now"; stories 2.1-2.3 built after resume (excluded: 179 min, $23.45)
F | adversary pass 3 + Step 1/3 fix loop 15:57-17:22 | 85 | 83 | 5 / $14.82 | yes | 0C/1M/3m; fix review NEEDS_REWORK (Important: unset ceiling labelled two ways); dev round 2; QA re-dispatched stale
G | party round 17:23-18:04 | 41 | 40 | 2 + 130 seat / $141.56 (about 485) | yes | 95 seat files, 26 major/95 minor, 13 distinct majors
H | disposition + 3 fix seats 18:04-18:22 | 18 | 17 | 4 / $5.54 | yes | lead restored lost gate-log entry; 13 carry-over items; 3 live instruments written
I | Step-3 re-review + QA + operator ask 18:22-19:25 | 63 | 6 | 3 / $8.11 (15) | operator-bound 57 | reviewer pass 1 NEEDS_REWORK (1 Critical, 1 Important); QA PASS 0 defects
J | gate [sprint-review] 19:25-20:16 | 51 | 51 | 9 / $5.62 (24) | yes | Check 1 FAIL (verdict-line grammar, open MAJOR in sibling file), rerun, then Check 14 snapshot trim 12 min
Total A,B,C,F,G,H,I,J: 361 min, about $201.5; with E: $225.5.
s321 and s322 same parts (wall min, lead-active, $): s321 adversary+golden-fix 30/30/$6.19; party+triage 33/33/$163.56; post-party fixes+reviews 84/84/$36.57; gate 30/30/$2.78. s322 adversary+fix 16/9/$3.13; party+triage 31/23/$66.59; post-party 48/28/$7.22; gate 42/42/$5.13. Lead calls (sprint-review + gate labels): s321 396, s322 498, s323 1,290.

## SENT 2026-11-20T12:14:56.682Z | sprint-review step analysis part 2 of 3

SPRINT-REVIEW PART 2/3 — readers, catches, verdicts. CORRECTION to part 1 summary line 3: adversary passes 2 and 3 cost $8.06 + $5.25 = $13.31 and 33 agent-min (not $12.81).

D. WHO READS WHAT EACH PART WROTE
- Seat files (95, party-mode/s323): read by the lead (grep of `## F-` headings and spot reads at 18:03, six minutes), by the repair seats, by the 13 carry-over items (each cites its seat), and by Check 20 only as a COUNT: the gate reads "Step 2 95/95 minimum met" (gate-validation.md:1828-1880 resolves the minimum from sprint-review.md); no gate reads a finding. That reader checks presence, but the seat-complete line carries sha and findings count and all 99 successful seat spawns wrote one (control), so presence is not empty. dev-1 and dev-4 completed and marked their files before their spawns errored; they were correctly not redone.
- sprint-adversarial-p1/p2 files: read by gate Check 1, which FAILED in s323 on the p2 file (open MAJOR in a sibling) and on a QA verdict line outside the set. Read by the lead and the repair seats.
- 13 CO-S323 carry-over items: reader is next sprint's carry-over-evaluation (not read in this study; carry-over analysis owns it).
- Round briefs (95 briefs + dispatcher, commit 893c0c128): written by the lead, read once by the seats; nothing reads them afterwards.
- gate-adjudication shard files: read by the lead's merge and the gate log only.
- Pre-staging rule L18-29: only reader deploy-validate.md:35.
- sprint-review-next.md: no reader in practice, see below.

E. CATCHES, THE PARTY ROUND (s323; method differs from the s321 reading: survival here is a token check at squash eabdc576e, not the share of added lines)
Population: 95 seat files = 5 roles x (18 stories + cross); 130 seat spawns, 34 of them errored (rate limit); 26 major, 0 critical, 95 minor headings (the lead's 165 includes lower tiers); 16 seat files raised nothing, 56 only minors, 23 raised a major.
26 majors = 13 distinct defects:
1 story-4.1 gate-log entry dropped by an implementation merge on 11-18 (pm-10, dev-10, architect-10, tea-10) FIXED (lead restore a60719349), survives at eabdc576e; absent at party-input tip (count 0).
2 story-4.2 AC1/AC2 proofs already green before the entry exists (architect-11, pm-11, tea-11) FIXED (remediator re-key).
3 APP_ENV=prod armed in source (architect-12, architect-cross F-1, dev-12, tea-12 F-2) REFOUND: sprint adversary SA-3 raised it at 02:53; operator answered "Ship armed": no change.
4 deferred ACs whose blocker cleared at integration and no story owns the test (architect-14, qa-14, tea-14 F-1 for 5.1 AC8; architect-16, tea-16 F-1 for 5.3 AC4) FIXED: three live instruments written; survive at squash (3 tokens present, control APP_ENV present, absent token 0).
5 layer byte pin re-baselined beyond the one authorized (dev-1, tea-1): introduced by the sprint-review's own Step-1 fix commits; fix review checked only the hash; operator approved after asking for a plain-language explanation.
6 collect gate removes per-position isolation (architect-cross F-2): a veto candidate for the operator, not fixed.
7 runbook header-less caller list incomplete (tea-12 F-1) FIXED. 8 new tests in no CI lane (tea-13) FIXED (ci-local registration survives). 9 cited e2e capture absent (tea-14 F-2) FIXED (record). 10 test-id drift in deferred predicates (tea-17) FIXED. 11 unstubbed arm never added (tea-4) FIXED (test). 12 refusal row carries no reason (tea-6) FIXED, one code line, survives at squash. 13 live Base router kind untested (tea-7) FIXED (test).
Outcome: 10 changed a shipped artifact (5 code/test/CI, 5 record/runbook), 3 ended as operator decisions. Earlier raise by another part: only #3 found by token search (control: SA-3 token present, impossible token 0); #12, #4's deferral history and #5 are UNIQUE-unverified (I did not read every earlier-hit file). Origin: #1 and duplicate Dev Agent Records (9 of 18 story files, remediator item 1) came from story merges, SA-1 from an omitted merge: three integration-class defects, none produced by any gate. Cost per distinct fixed defect: seats+dispatcher $141.56 / 10 = $14.16 (s321 reading: $13.94 per survivor on whole step cost).
Roles, SOLE raiser at major (data only, no cut recommended): tea 7 (#7-#13), architect 1 (#6), pm 0, dev 0, qa 0. Cost of the successful seats: architect $38.38, tea $38.95, qa $17.36, dev $15.28, pm $10.65. This is BL-1004's third pm reading: 0 (s321), 5 (s322), 0 (s323); its rule "remove if the second reading is also 0" is not met, keep branch holds. A tea-only panel would have covered 12/13 here but your s321 table shows it would have lost D1, D2, D4, D8 there, so s323 alone cannot cut any role; the sole-raiser pass should be run on s321/s322 before the operator is asked.

THE FIX RE-REVIEWS (strongest catch in the step): s323 fix review after Step 1: pass 1 NEEDS_REWORK, 1 Important + 3 Suggestions; after the party: NEEDS_REWORK 1 CRITICAL (the new 5.1 AC8 instrument loads "/" and the route-landing branch can never be true, so the test can never pass) + 1 Important (node instrument exits 0 when every card is INCONCLUSIVE). Both repair-introduced, both fixed, pass 2 APPROVED. QA re-validation across the three s323 runs: 0 defects (about $2.45).

F. VERDICT PER PART (hours/$ are UPPER BOUNDS, per sprint, from one sprint unless stated)
- L31-52 Step 0: KEEP as one line of the integration script; $0, 1 call.
- L18-29 pre-staging: MOVE to deploy-validate.md:35 (its only reader); frees 12 lines of this file; no measured catch.
- Integration (not in file): SCRIPT. One program run at implementation end and again at Step 0: every done story tip is an ancestor of the sprint branch (SA-1), every line a story branch appended to an append-only log is present at tip (#1), exactly one Dev Agent Record per story, every new test file named in ci-local (#8; same class as s321 D6, so it recurred in 2 of 3 sprints; no engine text enforces it: grep found none). Moves B (53 min, $10.03) out of the step and lets pass 1 start on a correct tree; saves adversary pass 2 ($8.06 + 18 agent-min) because "was the repair landed" becomes a script verdict. Changes: new core/scripts file, implementation.md closing step, sprint-review.md L31.
- L54-86 adversary: KEEP once per composed tree (s323 pass 1: Critical; pass 3: Major; s321 D22). Passes 2 and 3 break the "ONE-SHOT, no loop" text at L66-68: $13.31, 33 agent-min. Pass 3 was legitimate (stories 2.1-2.3 added code); pass 2 was repair verification, SCRIPT it.
- L88-122 party: KEEP; SHRINK the procedure not the panel: (1) retry errored seats by script. 34 seat spawns and 2 dispatchers errored; 32 seats' work lost: $22.49 and 19 min (17:23 start, 17:42 re-dispatch); the engine says nothing about rate-limit failures (_gate-procedures.md:471-473 sizes waves only against the concurrent-subagent cap) and the lead re-dispatched by hand (40 of 40 min lead-active). Whether other sessions on the account contributed is not measured, so the finding is "no retry", not "the fan-out caused it". (2) 16 zero-finding seat files cannot be predicted per seat; no cut offered.
- L124-166 Step 3: KEEP re-review. QA: dispatch after the reviewer approves or on the same tip: s323 QA ran on a stale tree and was re-run ($1.28, 8 min).
- L132-166 seam rules: NOTE: no evidence in s323 that the non-deferral rule fired; #4 is exactly its shape and was found by the party.
- L168-177 validator: KEEP; it is a script and it caught stale test-id cells in s323 (commit ab599a998 rebinding ST323-27..35 and 53/54).
- Gate [sprint-review]: SCRIPT the lexical part. In s323 the 4 shards ran twice ($5.62 incl. remediator, 51 min lead): first-round FAIL was verdict-line grammar and a sibling-file open MAJOR, both of the lead's own artifacts; s322 also needed a second round. Run the Check 1 grammar (gate-validation.md:230-286) as a script before dispatch: $2.78 + 16 min per affected sprint (2 of 3), plus the Check 14 snapshot trim after PASS (12 min).
- sprint-review-next.md (76 lines): CUT. 0 Reads of steps/sprint-review-next.md and 0 STEP_LOADED_TOKEN hits in all 176 lead transcripts of graph (control: 87 Reads of sprint-review.md); no spawn or step label in s317-s323. Measured on graph only; no consumer pulled.

## SENT 2026-11-20T12:15:22.170Z | sprint-review step analysis part 3 of 3

SPRINT-REVIEW PART 3/3 — the step as a whole, defects, not measured. Scripts dir: /private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/steps/sprint-review/ (README.md, phases.py, agent_active.json, tl1.tsv, tl2.tsv, majors.txt).

G. THE STEP AS A WHOLE
Smallest version that keeps every catch that earned its place:
1. Integration script (new, no model): ancestors, append-only log lines, one Dev Agent Record, test registration, Check 21 cells. Runs at implementation end; Step 0 re-runs it. Replaces SA-1 detection and finding #1/#8/duplicate-record repairs; fixes land before the step opens.
2. Adversary once on the composed tree, with the operator-request re-read (L72-76; it found the s323 scope MAJOR). A repair is verified by the script, not a second pass.
3. Party round unchanged in panel. Dispatch changes: seats written by a script that retries any seat whose spawn errored, never counting an errored spawn as joined; the lead's join stays the count of seat-complete lines.
4. One fix batch per round: dev fixes, then code re-review, then QA on the reviewer-approved tip (not in parallel with a tree that can still change).
5. Operator decisions raised in the step go to docs/escalations/pending.md and the deploy-validate checkpoint section the lead itself already named ("Decisions for You"); AskUserQuestion is not offered inside the step. Remove the affordance rather than police it. The one exception is scope (the 195 min ask in s323 was a genuine scope decision).
6. Gate: the verdict-line and sibling-file checks run as a script before any adjudicator is dispatched; shards run once.
Estimated effect on s323 (UPPER BOUNDS, each one sprint): wall 48 (ask) + 19 (rate limit) + about 38 (adversary pass 2 and its fix) + 16 (second gate round) = about 120 min of the 361; dollars $22.49 + $8.06 + $2.78 + $1.28 = $34.6 of $225.5. Nothing is lost: every catch listed in E remains. The panel's $141.56 is not reduced; I have no evidence that supports reducing it.
If I could redesign it: split the step by who the findings are for. Integration defects (SA-1, lost entry, duplicate records, unregistered tests, stale cells) are mechanical and belong to implementation's close, not to a sprint-level panel; the panel then reads a tree that has no mechanical defects, so its 13 majors would be the semantic ones (#4, #6, #11, #12, #13 here), which is what 5 role-lenses are for. I would then re-run the sole-raiser table on s321/s322 and, if tea and architect keep producing the sole majors, reduce per-story seats for pm/dev/qa to cross-only; that is a scope decision and not mine.

DEFECTS IN THE CURRENT ENGINE
DEFECT 1: story-to-sprint integration has no owner (no text in core/ or graph's engine; 3 integration defects in s323 and D22 in s321). 53 min, $10.03 inside the step; one of them (SA-1) was a Critical. Fix: new script plus implementation.md close step.
DEFECT 2: a blocking AskUserQuestion inside a step that says "without pausing for human input" (sprint-review.md:15-16). 18:23 ask, answered 19:11 and 19:21; both Step-3 reviewers had returned by 18:24 and 18:32; the fix and pass 2 took 13 min after the answer; gate started 19:36. No HARD_BLOCK entry for the byte-pin or APP_ENV items exists in docs/escalations/pending.md at the branch tip (only S323-2.2-AC5-SET, resolved), so the gate did not need the answers; the lead had written at 18:11 that both were staged for deploy-validate. Upper bound 48 min wall, $0. One sprint of three (s321/s322 op wait in this step 0).
DEFECT 3: no retry for rate-limit-errored seat spawns (see F). $22.49 and 19 min, one sprint of three.
DEFECT 4: step text says ONE-SHOT but three adversary passes ran, and the join is re-dispatched by hand each time. Upper bound $13.31.
NOTE: spawn minutes in spawns.jsonl include resume gaps. Step-3 QA span 60.5 min against 4 active; reviewer 63.8 against about 12; QA fix suite 46.7 against about 10. Any agent-hour figure built on span overstates the Step-3 rows (my table uses active). The earlier "63 min of re-review" reading is therefore operator wait, not review.
NOTE: Check 20 counts seats and never reads findings (validated above that presence is not empty).
NOTE: compactions in the step's own windows: 3 in session 1, 8 in session 2 (my count of continuation markers); compaction-recovery + step-reread classes 20 min in s323 against 1.6 min s321 and 3.4 min s322; gate span has 50 step/gate-file Reads in 51 min because gate-validation.md is 3,703 lines. A cheaper recovery path is a cross-cutting item, not this step's.
NOTE: I found already efficient: Step 0 (one call), validate-handoff-evidence (script, caught 11 stale cells), seat join by seat-complete count (99 of 99 successful seats marked), post-party disposition by the lead took 6 min for 165 findings with 3 fix seats dispatched in parallel.

H. WHAT I DID NOT MEASURE (and whether it was available)
- $ basis: spawns.jsonl `usd` sums to $225.54/$82.08/$209.09 for s323/s322/s321; the brief's $280/$101/$236 differ by $54.5/$19/$27 and the lead's token-eq is $3.02 for s323; unreconciled. Available (extract scripts), not run, since rerun was forbidden.
- Clock: MONO gives 11.12 h for s323 step+gate; first/last transcript timestamps give 12.35 h across the two lead sessions; the 1.2 h difference is not attributed. The 07:54-12:45 handoff gap is not counted anywhere.
- Rate limit: other sessions sharing the account during 17:23-17:38 are not measured. s321/s322 had 0 API-error spawns (control s323: 36, 34 seat + 2 dispatchers).
- Earlier-raise search: token greps at party-input tip 893c0c128 for #3, #5, #8, #12; hits for #12 and #4 were not all read; those two are UNIQUE-unverified. Survival is token presence at eabdc576e, not line share. The disposition of #6 (veto line) was not read; the operator's answer to the seven-veto-line question was truncated in the transcript.
- Sole-raiser table only for s323; s321/s322 were not re-scored (available: the two analysis files hold the seat tables; not done for time).
- s320: 70 sprint-review seat files exist in graph but spawns.jsonl has 6 spawns under the sprint-review label for s320; s320's seats are labelled elsewhere, so the s320 row of any per-sprint table is wrong. Not chased.
- sprint-review-next: measured on graph transcripts only; consumers other than graph not checked.
- Lead per-part minutes for s321/s322 came from event gaps (s321 hosted lead shows no gap above 300 s, so lead-active equals wall there; s322 shows gaps).
- Not measured: the QA fix-suite and reviewer reasons for the suite wall (tool latency sums 2.7 to 5.3 min each; the rest is model time and resume gaps).
- Pre-flight cost of the proposed scripts; no timing run was taken (rule).

