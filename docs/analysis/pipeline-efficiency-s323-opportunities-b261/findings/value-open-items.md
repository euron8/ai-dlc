# Findings of reader `value-open-items` (recovered verbatim from its transcript agent-avalue-open-items-a462535fb276b134.jsonl)

## SENT 2026-11-20T13:06:42.271Z | open-items 1 and 2: go-ahead asks, pre-push tree

OPEN-ITEMS part A (items 1 and 2). Scripts: /private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/steps/open-items/ (asks317.py, pm.py, item1.py, show.py, pushcwd.py; asks317.jsonl = data).

ITEM 1. GO-AHEAD ASKS, s317-s323
Population: every lead AskUserQuestion tool_use paired with its tool_result by id in graph's top-level lead transcripts 2026-10-05T13:58Z..2026-11-20T04:20Z (asks317.py, edges from extract.py:64). Control: it returns s321 56 / s322 30 / s323 38 asks, equal to the hand-asks counts; the totals are s317 13, s318 26, s319 71, s320 63. Category membership is curated by (start, header) in item1.py, so it is a judgment; a seeded absent key prints MISSING. A wait is counted once per ask; "default" = the (Recommended) option, else the first-listed.

ANSWER: 16 sprint-PR / fix-PR push-merge asks, 586 min. The operator took the default in 16 of 16 and declined, changed or conditioned none.
- s317: 2 asks, 93.4 min (Sprint PR 92.9, rec; Merge PR 1207 0.5, first).
- s318: 2, 71.2 (Push+PR 56.9; Merge PR 14.3; both first-listed, unmarked).
- s319: 2, 71.7 (Push/PR 1.9; Land fix 69.8; first-listed).
- s320: 1, 25.1 (PR #1277, rec).
- s321: 8, 309.5. Seven are 297.3 (the 11-07 push+PR 0.7, merge 1303 4.2, fix PR 6.7, merge 1304 3.3, push+merge 1.5, merge 1305 263.7, 11-08 push+merge 17.2); the eighth is "Land L2 fix" 12.1. Rec 7, first 1.
- s322: 0. Its deploy-validate step had no asks; its pre-step update merges are bucket U below.
- s323: 1, 15.3 (sprint-review "Merge 2.2+2.3 together", rec).
The 263.7 min re-ask at 11-07T18:54 was answered with the Recommended "Merge on the QA evidence", though the question offered "Get a hook run on the tip first". The approval it re-asked was the 18:48 "Push, open PR, merge when green" (1.5 min, rec).

Related buckets, listed so none is hidden:
- Fire / PUT go-aheads, 9 asks, 1,015 min. These sit in asks that also carry other questions, so that is an UPPER BOUND. s321 5 asks 659 min (the 644.8 min overnight "Router PUT / Enable Base" ask is in it); s323 4 asks 356 min. 7 of 9 took the default. 2 differed:
  (a) s323 11-17T03:43 "Proxy cert" (200 min ask): chose "Forward cert and fire", an unmarked non-first option of Forward cert header first / Hold the fire / Forward cert and fire.
  (b) s323 11-19T21:42 "Allowlist PUT" (1.4 min), free text: "You fire the PUT and verify it landed correctly. I will perform a secondary validation via the Rebalancer UI once you confirm it has landed." The options were "Fired it (Recommended)" / "Hold - firing later". This redirected who fires.
- Push-blocked / --no-verify asks, 6 asks, 28.9 min. 3 were not taken as offered:
  (a) s317 10-09T14:15 "Push blocked" REJECTED: "The user wants to clarify these questions".
  (b) s322 11-11T06:45 "Push block": free text "Pause here." against rec "Fix now, then push".
  (c) s323 11-14T15:59 "Pre-push red" REJECTED, 21.7 min (same clarify response).
  The other 3 took the default.
- Update-session PR merges ("Merge #1218/#1219/#1283/#1323", "Merge pin"), 5 asks, 7.6 min, all default.
- s322 11-09T00:06 "Roll fix" (the sprint-envelope roll, an archive overwrite, 8.3 min): rec "Overwrite archive" taken, and the operator ADDED a condition: "Option 1 plus file an upstream push candidate if warranted."

Across the 16 P asks the operator differed from the default in 0. Across P+F+N+U+R (37 asks) it differed or conditioned in 6: 2 fire, 3 push-blocked, 1 roll.

WHO MANDATES EACH GO-AHEAD. Method: grep the graph files and the engine for approval/merge/push text, then read the lines. Control: the same grep finds Rule 32 in SKILL.md.
Graph's own text:
- Sprint-PR merge approval: docs/operator-runbooks/deploy-protocol.md:28-30 "The agent merges the sprint branch to main during deploy-validate after the human approves the sprint PR". CLAUDE.md:46-48 names "sprint-PR approval, live security mutation, git revert on main" as the human-approval seams. Graph .claude/skills/ai-dlc/extensions/steps-domain/deploy-validate-domain.md:41-47 is the resume-approval guard S253-PR-APPROVAL, and deploy-validate-push.md:13-20 says "Do NOT combine merge approval with production validation into one prompt".
- Fix-forward PR: deploy-protocol.md:115-119 Rule (h): the agent opens a new fix PR "and the PR Validation Checkpoint runs again on the fix PR". This is the nearest text; it does not say to ask before pushing the fix. I found no line in graph's CLAUDE.md, runbooks or extensions that says "ask before pushing a fix-forward PR". The seven s321 asks came from the lead's own reading of Rule (b)/(h). The 18:48 ask text says "second fix-forward PR (the limit is 8)", which is Rule (i) accounting.
- Live security mutation / fire: deploy-protocol.md:244-249 and SKILL-domain.md Rule 916 (lines ~30-39): the operator fires unless an explicit per-action in-session authorization is given. Graph memory (not a file in the repo) adds feedback_do_the_literal_verb_only: "commit it" does not mean push or PR.
Engine text:
- core/skills/ai-dlc/steps/deploy-validate.md:107-109: a destructive one-time operation is staged by the agent and fired by the operator, "explicit in-session operator authorization recorded per action". This covers the destructive-operation class only; it does not cover a PR push or merge.
- The same file's section 6 "Wait for Human" (about lines 717-731) is the PVC stop; it is not a push or merge ask.
- core/skills/ai-dlc/SKILL.md:1144 Rule 32 touchpoint I requires an ADVISOR consult before a push, merge or deploy, not an operator ask.
- The engine has 0 hits for "PR Validation Checkpoint", "sprint PR approv" or "approves the sprint" in skills, rules and team-roles; deploy-validate.md:60 only names {deploy_command}, the consumer's own command.
ANSWER: none of the 16 PR push/merge asks is required by engine text. The PR-merge approvals are graph rules (deploy-protocol Rule (b)/(h)). The fix-forward push asks have no mandating text I could find at all. The engine mandates only the destructive-operation authorization (deploy-validate.md:107-109) and the checkpoint stop.
NOT derivable: whether the lead's habit came from graph's auto-memory or from the operator's earlier verbal rulings; the transcripts show only the asks.

ITEM 2. WHAT TREE THE PRE-PUSH HOOK TESTS
ANSWER: both hooks test the working tree of the worktree the push runs from. The hook code is not the cause, and it is not "the main checkout" either: it is wherever `git push` was invoked.
- Graph's .githooks/pre-push:41 and the engine's core/git-hooks/pre-push:41 are the same line: `cd "$(git rev-parse --show-toplevel)" || exit 1`. The graph shim .git/hooks/pre-push is `exec "$(git rev-parse --show-toplevel)/.githooks/pre-push"`. core.hooksPath is not set in graph, so a push from a linked worktree runs that worktree's tracked hook on that worktree's files. The ai-dlc CLAUDE.md states the same rule: a push is judged on the pushing worktree's tree, never on the pushed sha.
- Graph's hook and the engine's differ by 26 diff lines (874, 1709, 2003+, 2101); the tree-selection line is identical.
- Transcript evidence, pushcwd.py: the s321 fix pushes were `git push -u origin fix/s321-ff-base-first-save` (11-07T18:51:55) and `git push -u origin fix/s321-ff-base-refunding-router` (11-08T03:25:25), both with record cwd /Users/n8/git/graph, the main checkout, which held the sprint branch. The lead's 18:54 question says the hook "ran from the sprint checkout (a 2684-file diff) and not from the 13-file fix branch". The 03:06 text says it tests "the main checkout (ed49ace11)".
- The fix branches exist as plain branches (git branch lists fix/s321-ff-*); `git worktree list` today shows no worktree for them. Caveat: that list is today's state, not s321's, which I cannot recover. The transcript cwd is the evidence.
- So the lead's statement is half right. The hook tested the checkout it ran in (the sprint tree), and the cause is pushing a branch from a checkout that is not on it. A rule or helper that creates the fix branch in a clean worktree and pushes from there makes the same unmodified hook test the tip. No engine or graph text says to push fix-forward branches from a worktree at the tip (grep over core/skills, core/rules, core/team-roles, graph CLAUDE.md and the deploy-validate extensions: 0 hits; the only "clean worktree" lines in core are hook error messages, git-hooks/pre-push:3127,3129).
- The engine hook's remedy: for each such fix push, 18:51 and 03:25 would have run a different suite on the right tree; the advisor-hook cost of the suite is not measured here (no timing runs).
NOT derivable: what the hook actually printed for those two pushes (output files went to the session scratchpad $S/push-ff2.out, ff3.out, which I did not read).

## SENT 2026-11-20T13:08:46.736Z | open-items 7 and 8: session-start checks, continuation log

OPEN-ITEMS part B (items 7 and 8). Scripts: /private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/steps/open-items/ (item7.py, item7b.py).

ITEM 7. STEP 0a CHECKS 5, 6 AND 7 (core/skills/ai-dlc/steps/route.md)
ANSWER: none of the three printed its failure text in s321-s323: 0 of 0 for each. The text of check 5 is at route.md:216 "Snapshot was finalized on branch ...", check 6 at :233 "Warning: snapshot's last gate was ...", check 7 at :244 "Snapshot is at `current_step_file: deploy-validate.md` but sprint-status.yaml records sprint {N} as status: done ...".
Population: ASSISTANT text blocks and AskUserQuestion tool_use inputs in graph's top-level lead transcripts, 2026-10-30T00:10Z to 2026-11-20T04:20Z, split at the s321/s322/s323 edges. tool_result is excluded on purpose: a Read of route.md echoes every failure text, and item7.py counted 13, 8 and 5 such echoes in s321, s322 and s323, which proves the failure-phrase regex can match text.
Failure counts, strict phrases from the step file: check 5 "finalized on branch" 0; check 6 "last gate was N days" 0; check 7 "Snapshot is at `current_step_file" 0. A looser regex hit "stale" and "stranded" 22 times, and I read every hit. All were unrelated uses ("stale snapshot rows", "stranded funds") or pass reports ("not stranded at deploy-validate.md"), so I count them as 0.
Controls (the checks do run, and a pass is printed):
- Assistant-text pass reports ("Step 0a integrity - all seven checks pass" and the like): s321 3, s322 9, s323 7, so 19 resume reports. "branch matches" appears 2, 2 and 3 times, and "not stranded" 0, 2 and 2 times.
- `git branch --show-current` Bash tool_uses (check 5's command): 134, 48 and 83 (an upper bound for check 5, since other steps also use it).
- Assistant text mentioning "Step 0a": 10, 12 and 18.
Checks 6 and 7 print their pass text only when the lead chooses to; the step file prescribes no pass line, so 19 is a floor on resumes that ran the checks.
What remains underivable: a resume where the lead ran a check silently and found nothing (the same as a pass); a failure surfaced in the operator-facing UI but not in an assistant text block or AskUserQuestion input (none seen).

ITEM 8. CONTINUATION LOG AND STEERABILITY AUDIT IN RETROS
Population: graph docs/retro/s321/retro.md, s322/retro.md and s323/retro.md, read in full around every hit (grep "steer|continuation.log|ACK_DENIED|USER_PAUSE|wait-for-deliverable").
Citations of the continuation log:
- s321 (retro.md:106-121 and 183-198): counts ACK_DENIED 1, USER_PAUSE 17, BLOCKED 14, BACKOFF 0 live, and 3, 57, 27, 0 in the archive. Its text says "the log does not say which operator message each one followed, so the cause is not established here". No action.
- s322 (:771-784): ACK_DENIED 9, USER_PAUSE 54, BLOCKED 57, BACKOFF 2, with a root cause attributed to the lead. The only follow-on is a mandated rotation (the log rotated "immediately after this audit"). No other change.
- s323 (:1219-1250): live 2, 15, 36, 0 and archive 1, 4, 7, 0. The 2 ACK_DENIED were "investigated ... corrected at the time", before the audit. The rotation was done.
So 3 of 3 retros cite counts and 0 of 3 name a change they caused, other than the step's mandatory rotation.
Citations of the steerability audit result (Rule 29/25(c) validate-steering-budget.sh):
- s321: Check A FAIL (2 calls, worst 5.1 min), Check B FAIL (3 messages), listed as lead-conduct findings in section 4 items 1-2 (:106-107). The section 5 routing table (:128-141, 8 rows) has no steering row (grep for "steer|continuation" inside the table gives 0, and the control in the same range finds the push-candidate rows).
- s322: Check A FAIL (3 foreground calls, worst 10.0 min), plus 4 hand-rolled until/sleep loops "the Check A shape this very gate counts" (:775-776, :824). Improvements and routing (:692-717) has 0 steering hits; control 6 route/push-candidate hits.
- s323: Check A FAIL, 3 events, worst 4.2 min, same class as the hand-rolled waiter. It is listed in the lead-conduct list in the improvements section (about :1177-1197) and in the audit section. "Replaced by the ops seat's bounded wait" refers to an in-sprint substitution of that one waiter, not a routed improvement. The Improvement Routing section (:1200-1218) has 0 steering hits.
ANSWER: 0 of 3 retros produced a routed change (no push candidate, carry-over, rule edit or conventions row) from the continuation log or the steerability audit. The audit's Check A FAIL recurs in three consecutive sprints (2, 3 and 3 events). If an effect on behavior exists it is not visible in these three records. The audit result is read and recorded each time, and the recording is the only effect I can find.
What remains underivable: whether the audit or the log changed lead behavior in ways the retro does not write down (for example the s323 ops-seat bounded wait); the PostCompact/hook side is out of scope here.

## SENT 2026-11-20T13:10:51.768Z | open-items 5: architecture serial repair 61 vs 41

OPEN-ITEMS part C (item 5). Script: /private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/steps/open-items/item5.py (read-only on graph).

ITEM 5. ARCHITECTURE PARTY SERIAL REPAIR, s323: 61 vs 41
ANSWER: the 61 and the 41 are not nested sets, so "the other 20" is not a leftover of the 41. They count different things.
- SERIAL-REQUIRED 41 (join plan _bmad-output/planning-artifacts/s323/shards/architecture-party-repair-p1/.join-plan line 12; join-remediator-shards.sh:970-974) counts round-one part ENTRIES that are `repaired` with a real edit. I recounted it from architecture-party-repair-p1.md: 50 entries, 41 repaired with an edit, 9 escalated. Each of the 41 owes the serial agent a cross-file sibling grep.
- The 61 is the lead's own derivation at 21:49:20-21:49:27 in session 4b34031d: of the 122 findings in the 20 seat files, 61 are not cited by any of the four part shards ("UNCONSUMED: 61", with TOTAL 122 and CONSUMED 61). The lead noted "61 unconsumed vs the join's SERIAL-REQUIRED: 41" and then briefed the lane without reconciling them. item5.py repeats that derivation verbatim and reproduces 122 / 61 / 61 (control).
What the lane did with the 61 unconsumed findings (matching each to the serial record's entries by source id; the serial record has 67 entries: 16 SP edits, 9 SP-X escalations, 21 WL worklist adjudications, 9 AP already-applied, 12 fan-in FI; the lane's 55 entries are all but the FI ones):
- 40 led to a real edit (SP entries, or an escalation resolved by a fan-in FI edit).
- 1 was escalated.
- 19 were found ALREADY APPLIED by round one (the nine AP entries, "edit: n/a (already applied by round one's part N; no edit in this lane)"). They cite 19 of the 61 findings: six MAJOR and three MINOR entries.
- 1 (pm-cross#F-2) has no entry; the record's note 1 says the prd-wording record already applied it.
So the other 20 = 19 + 1 findings whose repair already existed, and none needed an edit from the serial agent. The 40+1 = 41 that did need the serial agent is a coincidence with the join's 41 (different sets: round-one entries versus unconsumed findings).
Did the 20 need the serial agent? Not for an edit. Someone had to establish "already applied", and the AP entries show how: each is a `grep -c -F` of a claim string in the spine, expecting 1 (AP-1: 3 greps; AP-4: 2; AP-9: a git grep with a positive control). The agent did not need to compose anything: the claim text comes from the part shards' "claim now asserted" lines. A script keyed on those lines would carry this class; I did not build or run it.
What it was worth: the 9 AP entries are 9 of the lane's 55 entries (16%). The step reader's 0.55 min/entry (30 min lane / 55) gives about 5 min of lane time as an UPPER BOUND on what scripting the AP class could free; per-entry time is not recorded, so it is a proportional estimate. The step reader's "10 min freed by sizing the lane to the 41" (30 x 41/61) is not supported: 40 of the 61 needed edits, so shrinking the lane to the join's 41 entries would have dropped real edits (SP, which carry the MAJOR repairs; the lane also resolved the nine part escalations, which are not in the 41).
Underivable: how the lane's 30 min splits across the four entry kinds (the lane transcript was not read); whether the advisor-discovered spine self-contradiction (SP-16) would have been found without the 19 AP greps.

## SENT 2026-11-20T13:12:59.825Z | open-items 6: gate-3 adjudicator evidence, script vs derived

OPEN-ITEMS part D (item 6). Script: /private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/steps/open-items/item6.py. Its table is a regex heuristic; the per-check readings below come from reading rows.

ITEM 6. S323 IMPLEMENTATION GATE-3 ADJUDICATOR VERDICTS: SCRIPT-RESTATING VERSUS DERIVED
Population: graph _bmad-output/implementation-artifacts/s323/gate-adjudication/implementation-*.part-*.jsonl. Control: the script asserts 120 part files and 225 verdict rows, i.e. 15 gate-3 runs x 15 checks (1-11, 11a, 16, 19, 22), 15 rows per check, 217 PASS and 8 FAIL. The unit is a verdict row (one check in one run), not a spawn; the 168-spawn figure is a different population and I did not reproduce it.
What the lead's own run already printed: at a one-story gate 3, `gate-transition.sh` runs the script arms first (core/scripts/gate-transition.sh header, "gate 3" paragraph): Check 2 (escalation-status vocabulary, suppression lifetimes), 2a, 5 (sprint-status.sh check-stories, derive-stories --check), 16, 17's implementation fold, 22, 25 and H2. So of the 15 adjudicated checks, 4 (2, 5, 16, 22) have a script output the lead already holds; the other 11 do not.

ANSWER BY CHECK (PASS rows; "restates" = the adjudicator re-ran the arm's script and reports its output/counts; "derived" = its own reads or greps; "skip" = a self-skip by a scope clause):
- Check 22 (spawn ledger): 15 of 15 PASS rows restate validate-spawn-ledger.sh (it re-ran the script and reports the counts: examined N rows, 0 tier mismatches, PENDING not failures). Own content: at most "no NOTE: lines". Restating 15, derived 0.
- Check 16 (stub audit): 14 restate validate-stub-audit.sh (exit 0 plus the counts line and the list of files it covered); 1 is a self-skip that also prints the script line. One row adds a real judgment (exit 4 means nothing was audited, and the scope was legitimately empty); one reports a first run that failed without --root. Restating 14, skip 1, derived-in-part 2 (they overlap the 14).
- Check 5 (story/sprint-status): all 15 restate check-stories PASS (18 comparisons) and derive-stories --check. The "story frontmatter status: review matches sprint-status.yaml story-323-N" sentence in every row is what check-stories itself compares. Extra own work in only a few rows: a third comparand against the previous gate-log entry (e.g. the 4.4 row) and a duplicate-parent-key scan (about 3 of 15 each). Restating about 12 pure, 3 with an extra.
- Check 2 (escalations): 15 of 15 are MIXED. Every row restates the vocabulary and suppression-lifetime verdict.sh outputs, which the lead had already printed, and adds its own scan of pending.md for HARD_BLOCK status and the DEFERRAL_REQUEST reopen-signal clause (grep, line cites). The script half is redundant in 15 of 15; the derived half is not script-backed. Pure restating 0.
- Checks with no script arm, so every row is the adjudicator's own work. By the heuristic's first-260-character test, 66 of the 217 PASS rows are self-skips: Check 10 15 of 15 ("no story adds fields to an API query or schema"; each row cites a git diff showing only web/ files); Check 8 12 of 15 ("deployment not claimed"); Check 19 12 of 15 (the check's scope is Gate 2 only and it "SKIPS at all other gates"; the other 3 rows read as skips too); Check 9 9 of 15 (no non-test web file changed); Check 11a 8 of 15 (no live-against-production smoke path); Check 11 5 of 15; Check 6 4 of 15. The pure-derived checks are 1 (13 PASS), 3 (14), 4 (15), 7 (13), and part of 6, 9 and 11.
- FAILs, all 8, are on judgment checks: Check 1 (2), Check 11 (2), Check 11a (4). None is on a scripted check (2, 5, 16, 22 have 0 FAIL in 60 rows), so the adjudicator never caught anything those scripts had not already cleared at the transition run.
What this decides (for a script carrying a check with nothing lost):
- Carry now, no loss: 22 (15 rows), 16 (14-15), 5 (about 12-15) and the vocabulary/suppression half of 2 (15): the adjudicator adds nothing the lead's gate-transition run did not print. That is 60 of 225 rows (27%) where the model re-reads a script's own lines.
- Carry with a rule table, no model needed: 19 (a gate-type test: skip unless gate 2), 10 (a git diff over server/schema paths), 8 (is a deployment claimed), 4 (a placeholder regex), 7 (does each referenced path exist), 3 (byte-compare of the LR block against locked-requirements.md; the rows say a Python byte-compare). These are my reading of the evidence text, not a measured replacement; I did not build any of them.
- Keep with the adjudicator: 1, 11, 11a (all 8 FAILs), the HARD_BLOCK/deferral half of 2, and the third-comparand part of 5.
Caveats: the SKIP/derived split is a text heuristic (10 and 19 skip lines are reliable; 6, 9, 11 mix skips with derivations); row classes were read for checks 2, 5, 16, 22 only. Not derivable: the adjudicators' cost per check (a shard holds several checks), so no hours or dollars are attached.

## SENT 2026-11-20T13:14:47.471Z | open-items 3: sprint-review sole-raiser by role, s321-s323

OPEN-ITEMS part E (item 3). Scripts: /private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/steps/open-items/item3_s322.py (s322, re-derived from graph); s321 is read from the committed table in docs/analysis/step-value-sprint-review-deploy-validate-s321.md; s323 is the step-review reader's table (findings/step-review.md E).

ITEM 3. SPRINT-REVIEW PANEL: SOLE RAISER BY ROLE, THREE SPRINTS
Rule: a distinct defect at MAJOR (no critical exists in any of the three sprints) whose major-level sources all come from one role's seats (that role's other seats may repeat it; other roles raised it at most as minor), AND whose fix changed a shipped artifact (code, test, CI, runbook, record). Not counted: ACCEPTED, REJECTED or UNIQUE-unverified entries (no fix evidence).
Populations and controls:
- s321: 130 seat files, 35 C/M findings, 22 distinct defects (the doc's D1-D22), classes taken from that doc. I did not re-derive them.
- s322: re-derived. item5-style control: 45 seat files, 45 major and 112 minor headings (the triage header says the same), 26 major triage entries. Sole role = exactly one role among an entry's MAJOR sources, parsed from the triage `sources:` line against each seat file's heading severity. Fix evidence = a commit in 95d831207..e0ebaf019 that names the T-id (control: the same query finds T-9, T-25 and T-16, which the squash body lists as fixes); for T-12, T-14 and T-24 the evidence is the pipeline-snapshot.md precondition line, as the pm doc reads it.
- s323: the reader's 13 distinct defects from 26 majors in 95 seat files.

DISTINCT SOLE-ROLE, FIXED MAJOR DEFECTS (raised by that role at major, fixed):
| role | s321 | s322 | s323 |
| architect | 3 (D2 Base inherits Polygon offramp_hodl, D4 runbook routing, D6 tests not in ci-local) | 1 (T-7 spine reopen trigger) | 0 (1 raised, not fixed: #6, left to the operator) |
| dev | 1 (D10 blank Strategy Test ID rows, low) | 0 | 0 |
| pm | 0 | 3 (T-2, T-12, T-14) | 0 |
| qa | 1 (D11b "built and tested" rows, low) | 3 (T-15, T-16, T-17) plus T-19 raised, no fix evidence found | 0 |
| tea | 7 (D13-D19) | 7 by commit (T-9, T-10, T-20, T-21, T-22, T-23, T-25), plus T-24 (record line, not confirmed) | 7 (#7-#13) |
Shared defects (not sole, so not in the table): s321 D1, D7, D8 (dev and qa), D11a; s322 T-1, T-3, T-4, T-5, T-6, T-8, T-13, T-18; s323 #1-#5.

CROSS-ONLY TEST. "Per-story seats removed, cross seat kept" loses a sole defect when none of its major sources is the role's cross seat:
- dev: loses D10 (s321, low consequence). 0 in s322 and s323.
- pm: loses T-12 (s322, a pre-merge diff-review precondition, medium). T-2 and T-14 came from pm-cross seats and survive; 0 in s321 and s323.
- qa: loses D11b (s321, low) and T-15, T-16, T-17 (s322): 4 total.
- architect: loses D2 and D4 (s321, both rated high on a capital path and the live config path) and T-7 (s322): 3 total.
- tea: loses 6 of 7 (s321: D13-D19 are per-story seats; only D6 and the s322 T-9, T-25 and T-24 are cross), and all 7 in s323.
ANSWER: no role can be cut to cross-only with zero loss across the three sprints. The two that lose exactly one sole defect in three sprints are dev (D10, low: a blank table row in a deferred story's file) and pm (T-12, medium). Both roles also overlap with others on the high-consequence defects: D8 (high, the Base-probe exception that blinded live-Matic monitoring) was raised by dev-16 and qa-16 and by no other seat, so cutting dev and qa together would lose it. Cutting dev alone, or pm alone, loses nothing high-consequence in these three sprints. The earlier s323 note "a tea-only panel covers 12 of 13" is right for s323 and wrong for s321 (it loses D1, D2, D4, D8, plus D6 and D10 and D11b).
Cost context (whole step): pm seats $17.00 (s321), $6.51 (s322), $10.65 (s323); dev seats $24.13 and $15.28 (s321, s323 successful). The pm figure for s322 is from the committed pm doc; dev for s322 not computed.
Underivable or not done: s321 and s322 survival checks for dev-only/qa-only items beyond what the committed docs state (I did not re-read s321 fix commits); s322 T-19 and T-24 fix evidence; seat-level wall clock (seats run in parallel waves, so removing one role's per-story seats frees dollars, not clock, unless the wave count falls).

## SENT 2026-11-20T13:17:38.099Z | open-items 4: dev evidence items; plus corrections

OPEN-ITEMS part F (item 4, then corrections to earlier parts). README and scripts: /private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/steps/open-items/ (ci_findings.json holds the 171 parsed findings).

ITEM 4. DEV EVIDENCE ITEMS, s321-s323
The dev role file's items: core/team-roles/dev.md lines 171-290 give a 19-item pre-submission checklist (dedicated test file; tests pass with log; honest-green citation; Dev Agent Record; story Status header; sprint-status same commit; conventional commit; scope verification; rename verification; schema/API field verification; production integrity tests; smoke test updates; metric reproduction; cross-CI plugin parity; mutation self-check; naming-implies-behavior; orphan-fixture; edit-already-present; wall-clock ordering), and the "QA Handoff Evidence" section lines 309-385 adds 5 more (full-collection run; dependency setup beside it; four evidence sections filled; Strategy Test IDs rows resolved; capture files carry command / RED capture). I used these 24. Graph's installed dev.md (480 lines) differs from core's (474), so item wording may differ slightly.
Population: graph docs/reviews/s321, s322, s323 code-review and QA files (205 files). I parsed every `### Critical` and `### Important` section into one record per finding, 171 findings (s321 97, s322 21, s323 53; 18 Critical, 153 Important); a "None." section is skipped. Control: the parse finds the known token "Dev Agent Record" in 34 findings and an impossible token in 0. The reviewers tag each finding with Class: BOOKKEEPING 55, TEST 50, EVIDENCE 39, CODE 25, none 2. I used that tag as the code-or-test-change signal: only CODE or TEST means the fix touched code or a test. "Cites the item" = the item is the thing wrong or missing, read from the finding titles after a keyword net (the keyword net is looser than my reading; I read every hit title and dropped false matches). Re-reviews of the same finding (p2, p3) count once. Script reader = a grep of core/scripts/*.sh and *.py for the item's name; controls: "Strategy Test IDs" and "Dev Agent Record" are found, an impossible token is not. A script that reads an item under another spelling would be missed.

FINDINGS PER ITEM (Critical or Important, distinct; s321/s322/s323), code-or-test change, script reader:
1 Dedicated test file: 0/0/0; none; no script. [CUT candidate]
2 All tests pass with log: 0/0/0; none; no script. [CUT candidate]
3 Honest-green citation: 0/1/1 = 2; 0 CODE/TEST (both EVIDENCE, resolved); no script names it.
4 Dev Agent Record populated/accurate: 2/1/1 = 4 (stale counts, stale validator line, wrong commit attribution); 0 (all BOOKKEEPING); validate-handoff-evidence.sh reads presence.
5 Story Status header: 0/0/0; no script by that name (check-stories reads the status). [no findings; script-backed by check-stories]
6 sprint-status same commit: 0/0/0 (1 passing mention in a Critical); several scripts mention it. [no findings; script-backed]
7 Conventional commit message: 0/0/0; no script by that phrase. [CUT candidate, with the caveat that a commit-msg hook might carry it; I did not grep hooks]
8 Scope verification: 2/0/0 (s321: a false "lists only the test file" scope claim; an AC scope text omitting two changed paths); 0 (BOOKKEEPING); no script. NOT a cut candidate: it found two.
9 Rename verification: 0/0/1 (s323 grep-fees capture holds the post-change tree, a rename-style capture); 0 (EVIDENCE); script reads "section has no content" only.
10 Schema/API field verification: 0/0/0; no script. [CUT candidate]
11 Production Integrity Tests: 0/3/1 = 4 (template placeholder left, empty section; one Critical); 0 (BOOKKEEPING); script reads non-empty only.
12 Smoke Test Updates: 1/0/1 = 2 (derivation does not reproduce; AC4 smoke assertion unwritten, flagged by both the code review and QA); 1 TEST (the s323 AC4 assertion; the sprint-review round wrote the live instrument); script reads non-empty only.
13 Metric reproduction command: 0/0/0 strict. One finding is arguable: s321 "AC8 reads '0 failures' and the capture has 49" (a numeric claim contradicted by its capture, raised in both a code review and a QA file). No script reads it. [CUT candidate if that one finding is counted as a Dev Agent Record or full-collection defect, as I did]
14 Cross-CI plugin parity: 0/0/0; no script. [CUT candidate; it is conditional on stories that touch CI]
15 Mutation self-check: 4/0/1 = 5 (one Critical: discriminator ACs with no committed mutation-RED capture; captures carrying the wrong head; a record naming a moved line); 0 CODE/TEST (all EVIDENCE: the captures were redone); validate-mutation-red.sh and validate-handoff-evidence.sh read it.
16 Naming-implies-behavior: 0/0/0; no script. [CUT candidate]
17 Orphan-fixture: 0 strict (1 loose: s321 "T14 retirement left orphaned psql-mock branches", branches, not a fixture file); no script. [CUT candidate]
18 Edit-already-present: 0/0/0; no script. [CUT candidate]
19 Wall-clock ordering evidence: 0/0/0; no script. [CUT candidate]
20 Full-collection run: 1/1/2 = 4 (a collect-only run under the honest-green label; a run not launched through the watchdog; a capture describing the pre-rework tree, Critical; "0 failures" vs 49); 0 CODE/TEST; validate-handoff-evidence.sh and merge-review-shards.sh read it.
21 Dependency setup beside the run: 0/1/0 = 1 (no record of the venv rebuild); 0; script reads it.
22 Four evidence sections filled: overlaps items 9, 11 and 12; 6 findings of stale or placeholder sections (s321 1, s322 4, s323 1, with duplicates across the items); 0 CODE/TEST.
23 Strategy Test IDs rows: 3/0/0 = 3 (divergent copy; rows recorded as "missing" though the cases exist; names that do not collect); 0 (BOOKKEEPING); script reads it.
24 Capture carries its command / RED capture: 1/1/1 = 3 (a "47-red" claim with no committed capture; a pre-change capture not committed; a venv rebuild capture); 0; script reads it.

TOTAL: of 171 Critical/Important findings, about 33 distinct ones cite one of these items as the thing wrong or missing (some count under more than one item, hence overlaps 4, 11, 12, 22). Only 1-2 led to a test (item 12's AC4 smoke assertion); none to a CODE change. The rest were record, capture or bookkeeping fixes.
CUT CANDIDATES (zero Critical/Important findings across s321-s323 AND no script reader): 1 dedicated test file, 2 tests pass with log, 7 conventional commit message (caveat: hook not grepped), 10 schema/API field verification, 13 metric reproduction (zero strict), 14 cross-CI parity, 16 naming-implies-behavior, 17 orphan-fixture (zero strict), 18 edit-already-present, 19 wall-clock ordering. Of the five the earlier reader named (Scope Verification, Cross-CI Parity, Naming-implies, Wall-clock ordering, Metric reproduction), Scope Verification is NOT a cut candidate (2 findings); the other four are, on this record.
CAVEATS (they decide how far "cut" can go): (1) a zero here also reads "the dev always complied, so nothing was caught"; the data cannot separate that from "the item never mattered", and a three-sprint zero is a floor on catches, not proof of no value. (2) The 171 come from the `### Critical` / `### Important` sections; a finding written without those headings is not counted (files with other layouts: none seen in my spot reads, not exhaustively checked). (3) Items 5-7 and 16-19 are checked by the review seats directly (the reviewer is told to read them); I did not measure how often the reviewer checked each.

CORRECTIONS TO EARLIER PARTS
- Part B, item 7: the failure text lines in route.md are 221 (check 5), 233 (check 6) and 249 (check 7), not 216, 233 and 244. The counts are unchanged.
- Part E, item 3: in the cross-only paragraph the tea line should read "tea loses 6 of 7 in s321 (D13-D19 are per-story seats), 4 of 8 in s322, and 7 of 7 in s323". My s322 per-tea cross split is from the `cross` flag in item3_s322.py (T-9, T-24, T-25 cross; T-10, T-20, T-21, T-22, T-23 per-story), so the s322 tea loss is 5, not 4; ignore the numerals in that sentence and use the script output. The architect and pm conclusions stand.
- Part A, item 2: drop the stray phrase about the "advisor-hook cost of the suite"; nothing was measured about suite cost.
STATUS: all eight items are answered in parts A-F. Nothing was written outside the open-items scratch directory; no graph or ai-dlc file was changed.

## FINAL-TEXT 2026-11-20T13:17:51.277Z

All eight items are answered and sent to `team-lead` as parts A–F, using graph's transcripts, records and installed files. I wrote nothing outside the scratch directory `/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/steps/open-items/`. Its README names each script and output.

1. **Go-aheads.** There were 16 push/merge asks for sprint or fix PRs, taking 586 minutes in total. The operator took the default option in all 16 and declined or conditioned none. Graph's own text mandates these asks, in `docs/operator-runbooks/deploy-protocol.md` Rule (b) and (h) and its deploy-validate extensions. I found no text at all that mandates the fix-forward push asks. The engine requires only an operator authorization for destructive one-time operations and the checkpoint stop. Beyond those 16, the operator changed or conditioned 6 other asks, among fire/PUT, push-blocked and roll asks, and those are quoted in part A.
2. **Pre-push hook.** The hook is not at fault. Both graph's and the engine's hook run `cd "$(git rev-parse --show-toplevel)"`, so they test the checkout the push runs from. The two s321 fix pushes ran from `/Users/n8/git/graph`, which held the sprint branch, so the hook tested the sprint tree, not the fix branch. No fix-branch worktree exists today, which I checked after the fact and which s321 may not match.
3. **Sprint-review sole raisers.** No role can be cut to cross-only with zero loss across the three sprints. Dev loses 1 low-consequence defect (D10, s321) and pm loses 1 medium one (T-12, s322). Cutting dev and qa together would lose D8, a high-consequence defect raised only by those two. I wrote a wrong tea figure for s322 in part E and corrected it in part F.
4. **Dev evidence items.** Of 171 Critical/Important findings, about 33 cite one of the 24 items. Zero findings and no script reader leaves 10 cut candidates, including four of the five the earlier reader named (Cross-CI Parity, Naming-implies, Wall-clock ordering, Metric reproduction). Scope Verification is not one: it drew 2 findings. Almost none of the findings led to a code or test change.
5. **Architecture serial repair.** The 61 and the 41 are different populations. The 61 is findings no part cited; 40 of those needed an edit, 1 was escalated, and the other 20 were already applied. Those 20 needed no serial edit, only a check that the fix was already in place.
6. **Gate-3 adjudicators.** Of 225 verdict rows, checks 22, 16, 5 and the script half of 2 restate script output the lead's gate-transition run already printed. That is 60 of 225 rows. All 8 FAILs sit on judgment checks (1, 11, 11a).
7. **Session-start checks.** None of checks 5, 6 or 7 printed its failure text in s321–s323. Pass reports were found 19 times, and the failure-phrase regex does match when a Read of `route.md` echoes the text.
8. **Continuation log and audit.** All three retros cite the continuation log counts and the steerability audit result. None produced a routed change.

The item 6 and item 4 classifications are keyword heuristics over evidence text, so treat their counts as approximate; I read the rows for checks 2, 5, 16 and 22 and the hit titles for item 4. The `.githooks` test for item 2 shows a different cause than the lead's "tests the main checkout" claim, so no fix to the hook is implied.

