# Findings of reader `value-advisor-r` (recovered verbatim from its transcript agent-avalue-advisor-r-c47fe6bbc7e67ecf.jsonl)

## SENT 2026-11-20T13:05:38.144Z | advisor-r-value part 1 of 3: counts

ADVISOR R VALUE, s323, part 1/3 (counts). Scripts, full table and README: /private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/steps/advisor-r-value/ (table.tsv = the 134-row table; cls.json = my class per call). s322 NOT done.

HEADLINE: 116 advisor results read (the first result after each of 134 compactions that had one). CAUGHT 49, CAUGHT* 18 (advisor-asserted, defined below), ADJUSTED 44, CONFIRMED 3, IGNORED 0, EMPTY 0, unclassifiable 2. The catches are mostly NOT stale recovery state: 33 of 49 CAUGHT are errors in a draft brief/entry/script or a memory-held fact (JUDG 19, OTHER 14); only 9 are state the snapshot would have shown. The one natural control (25 compactions with no call before the first dispatch/write) shows no re-dispatch of running work.

(1) POPULATION. Boundaries: 134 = 2+11+15+76+30 over sessions 0ef7ba46, 68cf8de7, 4b34031d, 53b4296a, 64926214 (control: equals the roll's 134). "First dispatch/write" = first Agent/Task/Write/Edit tool_use whose result is not is_error (the gate's own set).
- Advisor before the first dispatch/write: 98. No dispatch/write before the next compaction, advisor called: 7. YES total 105.
- Dispatch/write first, no call before it: 25 (14 never called again in that segment; 11 called later, 2-18 actions after). In ALL 25, no successful Read of postcompact-digest.md preceded the first dispatch/write, so the gate's R stage (which arms only after that Read) had not armed. Advisor-unavailable results: 0 (the only error result is 1 attempt the recover gate itself denied, 0 s).
- No dispatch/write and no call before the next compaction: 4.
- Gate pressure: 56 R-denials of Agent/Write/Edit in 31 segments; in 29 of the 116 classified segments the lead called the advisor only after such a denial (a brief or entry already drafted).
- Latency, request to result: all 209 advisor calls in the 134 segments: 6,973 s = 1.94 h, median 30.6 s. The 105 R-timed first calls: 3,411 s = 0.95 h, median 30 s, max 120 s (one call, 6492#8 ln8688, ran past 120 s and went to background). The 116 classified first calls: 3,878 s = 1.08 h. The other 92 calls in those segments (G1/G2/I/V1/P touchpoints) are NOT classified; 13 of the 116 rows are themselves another touchpoint that fell first in the segment (tagged in table.tsv).
- Rows with lead thinking visible: all five sessions are local-model leads; I read the lead's visible text and tool calls for every row, and its thinking text only for rows 101-115 (added late). The advisor may see more than I did; that matters for CAUGHT* below.

(2) CLASSES, per step (CAUGHT, CAUGHT*, ADJUSTED, CONFIRMED, IGNORED, EMPTY, UNCLASSIFIED; n classified of compactions in that step):
carry-over-evaluation 0,1,6,1,0,0,0 (8 of 9)
requirements 6,1,4,0,0,0,0 (11 of 13)
architecture 8,0,1,1,0,0,0 (10 of 12)
stories-test-strategy 10,3,1,0,0,0,1 (15 of 19)
ui-direction 2,0,0,0,0,0,0 (2 of 2)
implementation 8,12,21,0,0,0,0 (41 of 47)
sprint-review 9,1,4,0,0,0,1 (15 of 16)
deploy-validate 3,0,4,1,0,0,0 (8 of 9)
retro 3,0,3,0,0,0,0 (6 of 7)
TOTAL 49,18,44,3,0,0,2 (116 of 134; the 18 unclassified are compactions with no advisor call at all)
Step comes from MONO/segs.jsonl (gate-validation[X] counted under X).
Definitions I used. CAUGHT: the advice names a concrete error that the lead's own text or action shows it held, and later actions differ. CAUGHT*: the advice says the summary or plan is stale ("pass 2 already dispatched, do not re-dispatch", snapshot line N says so) and the lead then did not do it, but nothing in the transcript shows the lead intended it; if the advisor sees reasoning I cannot see, these belong in CAUGHT. ADJUSTED: checks or ordering added, no wrong claim shown (includes 7 FALSE ALARMS where the lead checked and its own claim was true: rows 49, 56, 57, 60, 66, 103 and 31's reverse). IGNORED 0: where the lead disagreed with a premise (rows 56, 57, 60, 66, 83, 103) it still ran the check the advice asked for, and the lead was right.

Uncheckable by me: row 31 (advice text indexed away by context-mode, lead later said "generator defect is real") and row 96 (consult went to background at 120 s; advice not found in the transcript). Both UNCLASSIFIED.

## SENT 2026-11-20T13:05:59.898Z | advisor-r-value part 2 of 3: all 49 CAUGHT rows

ADVISOR R VALUE part 2/3: ALL 49 CAUGHT rows. Format: session#compaction step errtype Lline (advice result line in the session transcript): error named; what the lead then did. Steps: REQ requirements, ARCH architecture, STS stories-test-strategy, UI ui-direction, IMPL implementation, SR sprint-review, DV deploy-validate, RET retro. errtype: SNAP = state the snapshot would have shown; JUDG = brief/script/rule judgment error; OTHER = memory-held fact, draft claim, disk or git fact outside the snapshot; TRUNC = lead's own read coverage; GIT = branch/commit state. IGNORED rows: none.
68cf#8 REQ JUDG L9054: pending.md/snapshot timestamps invented (13:25Z vs real ~13:43Z); lead wrote CORRECTION entry with date -u
68cf#9 REQ JUDG L9744: seven briefs invoked_at invented (14:58Z vs date -u 14:46Z); lead sent correction to shard agents
4b34#2 REQ OTHER L2859: memlog line numbers quoted from pre-compaction memory, brief hardcoded findings=8; Agent R-denied; lead sed-verified memlog then dispatched
4b34#4 REQ JUDG L4391: lead decision (retry rule not extended) conflicts with operator locked answer LR-S323-36 "wide"; lead wrote PIN-SPAN-CORRECTION, dispatched fixer
4b34#5 REQ JUDG L5296: repair brief seals pass 1 not 2, SPEC wrongly exempted from sha chain; lead rewrote brief, retried after R denial
4b34#7 REQ JUDG L6675: deleting a Status line shifted pending.md cites; lead Edit-restored the line, ran validators
4b34#11 ARCH OTHER L10334: "V1 6-item gap list" only in pre-compaction memory, snapshot NEXT stale; 4 Edits R-denied; lead re-derived from disk
4b34#12 ARCH JUDG L11529: Ruling 12 amendment wrong attribution, placeholder timestamp, wrong :24758 retry claim; lead ran 3 code checks, rewrote
4b34#13 ARCH OTHER L12297: finding count 18 not 11 (held from memory); lead re-derived with grep -c, read unread findings and step file
53b4#0 ARCH JUDG L993: changelog draft wrong "Per-site table (row 5)", stale lint/fold-sha/J3; Write R-denied; lead verified before retry (rewrite itself not shown)
53b4#1 ARCH SNAP L1855: "Core slice fully loaded" false, spans 1-5 read pre-compaction; snapshot said resume load; lead re-read all core spans
53b4#2 ARCH SNAP L2446: recovery claims (34 ledger rows, 3/3 shards) unbacked; snapshot 02:54:28Z line says shards running; lead had read snapshot, had not reconciled; re-established from disk
53b4#3 ARCH JUDG L3254: 3 adjudicator briefs' Context paragraphs not neutralized; Agent R-denied; lead re-issued all 3 inside the 900 s bind window
53b4#4 ARCH OTHER L3953 (G2 consult): Check 35 stale, 66 In-Flight rows deleted since last PASS; lead re-ran it: 65 lines destroyed, recovered from git
53b4#7 STS OTHER L6432: 18 briefs' GATED FACTS ids/anchors written from memory; Agent R-denied; lead verified every citation, regenerated briefs
53b4#11 STS JUDG L10287: generator invented return-line grammar, epoch guess, provenance block; Write R-denied; lead re-derived from adversary.md/join script
53b4#12 STS JUDG L11372: Edit on cross.md F-8 would record a repair that never happened and break the join; lead SendMessage'd the seat to re-disposition not-reproduced
53b4#13 STS SNAP L12327: old seat a57e65 still live per snapshot row, hung on pytest; lead TaskStop'd it, checked conftest, then re-dispatched
53b4#15 STS TRUNC L13666: lead claim "step file fully re-read" false (read 1-646, sec 5-7 unread); lead read 647+
53b4#18 STS SNAP L15880: verification turn overstated loaded state; snapshot says push.md re-read pending; lead re-read gate spans and extensions
53b4#19 STS JUDG L16470: repair-seat brief invents remedy shape unchecked against validator/precedent; Agent R-denied; lead checked FAIL lines, --arms, append safety
53b4#21 STS JUDG L17939: p3 brief 3 defects (ready-for-dev ruling unestablished, false notarized claim, guessed stamp invocation); lead investigated before retry
53b4#23 STS SNAP L19100: "merge completed, COVERAGE-OK" unsupported; snapshot newest line says 7/8 delivered, shard 7 pending; lead verified on disk before Check 26
53b4#24 STS SNAP L19545: lead note "gate-log entry appended, 38 metric rows staged" contradicts snapshot line 43 REMAINING; lead patched entry, appended 38 rows
53b4#25 UI SNAP L20304: acknowledgment wrong (stale fire state, story 1.1 dev role, 4.1/4.2 delivery); wave 1 not re-dispatched; lead fixed snapshot current_step_file, TaskStop
53b4#26 UI SNAP L21390: 4.2 QA brief carried 4-4's sha 4955b7b8f, snapshot has 4-2's dac9e023f; Agent R-denied; lead verified shas, dispatched four QAs
53b4#41 IMPL JUDG L32992: rotate-snapshot-archive.sh run with the archive file instead of the history dir, moved 1,756 entries out; lead restored the archive from git HEAD
53b4#43 IMPL JUDG L34869: Gate-status Edit on 5.4 story file while worktree frozen at 0b634d223 under an open nonce; Edit R-denied; lead joined parts first
53b4#45 IMPL OTHER L36278: gate-log entry draft quotes stale/unverified evidence (series, HEAD d7a8e25f); Edit R-denied; lead corrected pass-count wording and series line
53b4#52 IMPL OTHER L41466 (G2): entry has unverified Gate-1 plan lines, evidence cells not re-sourced; lead pulled plan blocks verbatim by script
53b4#63 IMPL TRUNC L50035: gate-slice spans must be re-read, compaction cleared them; lead had said "now read"; lead re-read all spans and extensions
53b4#64 IMPL TRUNC L50577: recovery "discharged" but implementation.md never re-read; lead read it 1-555, 556-745, verified 1.4 closes
53b4#65 IMPL OTHER L52160: 5.2 entry draft has pre-written cells, unverified claims; lead found canonical DAR stale, re-folded 11a block, committed
53b4#73 IMPL SNAP L57258: In-Flight row not struck (its --line-delete was refused), adversarial-p1.md never committed; lead re-ran delete, fixed four housekeeping items
6492#0 SR JUDG L1371: F-6 brief defects (R-denied dispatch); lead dispatched the seat with a corrected brief (one other point of the advice was wrong)
6492#1 SR SNAP-FALSE L1827: snapshot cont127 claimed escalation rename + authorization rewrite DONE, they were NOT; lead made both Edits. The snapshot itself was wrong
6492#3 SR JUDG L3224: pause flag cleared with rm && test in one call, adjudicator verdict path wrong; lead re-ran in two calls, re-checked path
6492#4 SR OTHER L4656: gate-3 freeze broken, 2.3 branch tip moved to 8874f91f7 (frozen e1d59d064), evidence does not cover shipped code; lead agreed, verified fix shape
6492#5 SR OTHER L5654 (G2): snapshot conservation broken, unsourced "214486" number, 45/46 mismatch; lead fixed all before close
6492#6 SR JUDG L6382 (pre-push): capture HEAD labels name the wrong tree, F-5 must not be self-discharged; lead sed-corrected before pushing
6492#7 SR OTHER L7705: QA capture was pre-round-2 (6316) and a real Step-4 issue; lead confirmed both
6492#11 SR GIT L11097: lead on a detached HEAD; lead re-attached the branch at f71765ce6, committed bookkeeping
6492#12 SR JUDG L11780: remediator brief must also cover the -p2 sibling or Check 1 fails again; Agent R-denied; lead merged the failed pass (widening not shown in 10 actions)
6492#14 DV GIT L13209 (push consult): commit never ran (compound command blocked), push would miss 3 pipeline files; lead committed first
6492#18 DV TRUNC L17692: deploy-validate.md (45 KB) never loaded, lossy snapshot read; lead read sections 504-760, re-read snapshot
6492#22 DV OTHER L22467 (push consult): stale S321/carry-over statuses, DECIDED count 22 vs 25 vs 20, Base cert audit missing; lead dispatched OPS read, closed stale items
6492#24 RET OTHER L24154: drafted paragraph claimed a .gitignore edit that never happened; lead ran verification (dropping the claim not shown)
6492#25 RET OTHER L24947: lead's status self-contradictory on whether the apply path exists in the archive script; lead read the script and found the summary wrong
6492#27 RET JUDG L26307: trim script guessed not derived; Write R-denied; lead enumerated real bullets, ran it, found 6 continuation lines lost, repaired

COST IF ACTED ON (record only, the clearest): 53b4#41 archive of 1,756 entries gutted in the commit; 53b4#4 65 snapshot lines destroyed; 6492#4 gate-3 closed on evidence that did not cover the shipped sha; 4b34#4 operator-locked decision contradicted; 53b4#12 false repair record breaking a join; 6492#14 push without its commit; 68cf#8/#9 invented timestamps in records and 7 briefs. Dispatch count at risk in the stale-state rows: none observed (see control).

## SENT 2026-11-20T13:06:24.340Z | advisor-r-value part 3 of 3: CAUGHT*, split, control, limits

ADVISOR R VALUE part 3/3. (Correction to part 1: the false-alarm rows are 53b4#30, #37, #38, #42, #48 and 6492#15, six rows, in ADJUSTED; "31's reverse" in part 1 should be ignored.)

(2b) CAUGHT* (18, advisor-asserted "summary stale, do not re-dispatch / re-mint / re-write, snapshot line N says so"; lead then did not): 68cf#2 COE, 4b34#0 REQ, 53b4#6, #14, #16 STS, 53b4#27, #28, #33, #34, #35, #47, #53, #54, #58, #60, #61, #72 IMPL, 6492#13 SR. Each names a snapshot line or row recording the work as done or in flight. IGNORED: none (0 of 116).

(3) THE COUNTERFACTUAL: would the proposed hook state (position, In-Flight rows, open items, last 10 activity lines, branch and last commit) have shown the error? Over the 67 CAUGHT+CAUGHT*:
- STATE THE SNAPSHOT SHOWED: 27 = 9 CAUGHT (SNAP) + 18 CAUGHT*. Examples with the snapshot content cited by the advice: 53b4#26 "02:54:28Z line says shards running" while the lead claimed 3/3 delivered; 53b4#24 "snapshot line 43 REMAINING: append gate-log entry + 38 metric rows" while the lead said appended; 53b4#26 (ui) 4-2 sha dac9e023f recorded while the brief carried 4-4's; 53b4#23 "newest Recent Activity line says 7/8 delivered, shard 7 pending". CAUTION that cuts against the proposal: in all 27 the lead had already Read the snapshot (in chunks) before the consult, and held the stale belief anyway; the advisor found it by comparing the lead's claim with the snapshot lines. 6 of the 27 mention a truncated or folded snapshot read (context-mode 16 KB cap). So handing the state is not shown to remove the error; it may only move the same comparison to the hook.
- THE SNAPSHOT WAS WRONG OR STALE: 1 CAUGHT (6492#1: cont127 claimed edits done that were not) plus 4 ADJUSTED false alarms where the snapshot/summary lagged the lead's true state (53b4#42 ln33899 and 53b4#48). A hook that renders the snapshot inherits this.
- NOT in the snapshot: JUDG 19 (invented timestamps, wrong brief grammar, wrong script argument, frozen-worktree rule, locked-decision misread) and OTHER 14 (memory-held counts and line numbers, draft claims, git tip of a story worktree, conservation breaks). Neither could be shown by the proposed state. TRUNC 4 (own read coverage of the step file or gate spans): not in the snapshot; the recover-gate chunk accounting is the nearer mechanism. GIT 2 (detached HEAD; uncommitted files): "branch and last commit" would show the first, not the second.
Counts: could-have-shown 27 of 67 (40%); could not 40 of 67 (JUDG 19, OTHER 14, TRUNC 4, GIT 2 split 1/1 included here as could-not for the second).
Where the catches sit: 29 of the 116 calls came after an R-gate denial of a drafted dispatch/write; there the advisor was reviewing a concrete brief or entry: 14 CAUGHT JUDG, 5 OTHER, 2 SNAP, 8 ADJUSTED. The 75 calls with no prior dispatch/write attempt (pure recovery): 33 ADJUSTED, 18 CAUGHT*, 7 SNAP + 1 SNAP-FALSE + 3 JUDG + 5 OTHER + 3 TRUNC + 1 GIT CAUGHT, 3 CONFIRMED, 1 unclassified. So the highest-yield call is the one that reviews a drafted artifact, not the recovery check.

(4) NO-CALL CONTROL (not randomized; the 25 had no digest Read before the first write, so they differ in kind from the 105; most are in one session, 53b4296a). 25 compactions had a dispatch/write before any advisor call (14 never called again, 11 called later). Checked the 20 actions from the first dispatch/write (control.py): in the 14 never-called, denials by OTHER hooks (dispatch guard "no Deliverable line" 53b4#5, #8 (3 refusals), #56; snapshot written outside snapshot-update.sh 6492#20), each retried by the lead; correction cues in 68cf#10 (a remediator "correcting that field shape and re-sealing") and 53b4#74 (removing a duplicate deferred section). No denied R-style duplicate dispatch. Re-dispatch probe (dupdispatch.py): successful Agent dispatches with the same (type, description) as the previous segment: 0 of 96 dispatches in the 14, 0 of 72 in the 11; in the 98 advisor-first compactions 4 of 620 (all four are 64926214#12 re-running a failed gate pass's 4 adjudicator shards, legitimate). So: no sign, in 25 unadvised compactions, of the "re-dispatch running work" error that the 18 CAUGHT* rows warn about; the base rate of that error without the call was 0 of 25 compactions, which cannot rule out a rate near 1 in 10 at this N. 4 more compactions had no dispatch/write and no call (4b34#9 after 3 R-denials, 53b4#17, #57, #69); nothing to compare.

(5) LIMITS. Not classified: s322 (not started); 92 later advisor calls in the same segments (other touchpoints); 18 compactions with no call at all (4+14); rows 31 and 96 (advice text not recoverable). Single reader, no second pass; the CAUGHT / ADJUSTED boundary for "advice added checks, claim later not shown wrong" is judgment (about 12 ADJUSTED rows lean CAUGHT: e.g. 68cf#7, 53b4#34 claims asserted unverified, never shown wrong). CAUGHT* may be undercounted CAUGHT. "Cost if acted on" is from the record only for the rows named; no row has a measured dollar cost. Thinking text read only for rows 101-115. Segment boundaries are compact_boundary rows; first dispatch/write ignores Bash writes (the gate's set). The advisor's latency is the call's wall clock, not lead idle time. Not measured: whether any of the 105 calls delayed a dispatch that then changed outcome; the cost of the 1.94 h is 6,973 s of lead wait, none of it overlapped with other work that I checked.

