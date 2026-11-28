# BL-512: what the s323 gate discards found (batch 271, cluster H)

## Question

BL-817's reopened-range rule: a "did not fall" reading closes only with value evidence, a catch no other
step makes that survives to the shipped artifact. BL-512's per-story gate cost on s323 did not fall. This
file asks whether the gate's s323 FAILs supply that evidence.

## Method

- Population: the 10 s323 discarded nonces at `docs/analysis/step-value-b256/bl512/count_discards.b270.out.txt`
  lines 50-59 (graph ref a9b015557). Each nonce's FAIL checks were read from its verdict or parts at that ref.
- The unit is a distinct defect, not a nonce. Three nonces failed two checks each, so the 10 nonces hold 13
  defects.
- Fixed before any result was read: a defect is gate-only (unique to the gate) when no other round RECORDED the same defect before
  the gate. A defect another round recorded and then waived, deferred or accepted is not gate-only.
- Shipped artifact, for the step-value ruling, is the story, the code, or a record a consumer reads. This is the lead's definition for this batch (lead ai-dlc-c3, batch 271). The 'changed product code or tests?' column is a narrower, separate question.
- "Changed product code or tests?" asks whether the fix after the FAIL changed product code or tests on the
  story's branch, or only records (story text, review files, escalation entries, captures).
- Every absence claim (no other round recorded it) was taken with a positive control that must read non-zero
  and the negative token `zq9xx-no-such-token-h271` (rows 4-8 used `zq9xx-no-such-token-h271b`), which must
  read 0. Commands and counts are under "Absence claims" below; the scan code is in `s323-scans/`.
- Every Check 11a row (6, 8, 10, 12, 13) is judged with one grammar, the wider of the two the hands used:
  `git show <sha>:<file> | grep -n -i -E 'live[- ]run|-m live|AGGREGATOR_URL|11a|deploy-pending|live attempt|no live'`
  over the story's code review and QA files. The first reading of rows 6 and 8 used a narrower grammar
  (`11a|live-run (record|attempt)|attempt (is|was) not recorded|no (command|envvar)`) and called both
  gate-only. The owner re-ran the wider one at the same shas: graph a0a7dd4b0 5-1-code-review.md 2 hits,
  5-1-qa-validation.md 8; graph 14cad80ba 5-3-code-review.md 2, 5-3-qa-validation.md 10. The negative token
  `zq9xx-no-such-token-h271` over all of graph a9b015557: 0. Rows 6 and 8 are therefore recorded elsewhere.
- Graph locations are written as `graph <ref> <path>, line N`. Transcripts are graph's session transcripts
  under the operator's Claude projects directory for graph.

## The 13 defects

| # | Nonce | Story | Check | Defect | Class | Other round's record | Fix and successor | Changed product code or tests? |
|---|---|---|---|---|---|---|---|---|
| 1 | planning-20261118T025210Z | none | 2 | Escalation S323-ARCH-P1-LEG2-PREBOUNDARY (graph dec6dd62b^ docs/escalations/pending.md, line 5998) carried the token OPEN, outside the closed vocabulary, and had no Status line. Graph's installed vocabulary validator skips an entry with no Status line (PASSED, n=234). | gate-only, records | None. Near miss: the architecture repair reviewer (agent a0b1c4e2, 00:23Z) saw the OPEN token and did not flag it; the lead's 18 mentions from 02:08Z to 02:48Z treat "OPEN, default in force" as normal. | Commit dec6dd62b relabelled the entry DECIDED_AUTONOMOUSLY (form only). Successor planning-20261118T031522Z PASS Check 2. | no, record form only |
| 2 | sprint-review-20261119T193613Z | none | 1 | graph f745b70b4^ docs/reviews/s323/sprint-review-step3-qa-validation.md, line 29, reads `Verdict: **APPROVED**`, outside the QA set PASS / NEEDS_REWORK (graph a9b015557 .claude/team-roles/qa.md, line 539). | gate-only, records | None. The defect lived about 14 minutes (QA seat 19:22:26Z, lead commit 19:25:53Z "QA re-verify APPROVED", gate 19:36Z); validate-handoff-evidence.sh ran and did not flag it. | Commit f745b70b4 restated the verdict as PASS. Successor sprint-review-20261119T195256Z PASS Check 1. | no, the QA substance was 0 findings |
| 3 | implementation-20261119T015536Z | 3-2 | 22 | Story frontmatter line 19 reads `escalate_model: true` (true at graph 5fe4b5ce7, before the 20:27:51Z dispatch), but the only dev seat was a plain `dev` (agent a8b075e670fcd22ad, sonnet). | gate-only, process | None. The plain seat's ledger row (`toolu_1795033671342_0 | dev |`) appears on 14 lines of the r3c.txt listing from 22:24Z to 02:02Z, one of them the adjudicator's own read, with no flag; the lead's 23:24Z plan line "dev-escalated for 1.1-1.4,2.3,5.2; plain dev for 2.1,2.2" omits 3.2; no dispatch-guard warning; validate-spawn-ledger.sh exit 0 (it checks the role-to-model pin, not story routing). | A dev-escalated (opus) re-verification seat, commit 756583319, "re-ran three commands and changed no code or test". Successor implementation-20261119T021925Z PASS Check 22. | no, the shipped 3-2 code is the plain dev's |
| 4 | implementation-20261118T140535Z | 4-3 | 1 | QA pass-2 file docs/reviews/s323/4-3-qa-validation-p2.md untracked; the story had no Gate-status line. The verdict says "Not a verdict-content defect". | lead-recorded, records | The lead caused it (git reset --mixed d774ffe9) and recorded it: 13:40:38Z "the p2 file is on disk, untracked, content intact"; 14:04:49Z "the p2 file is untracked in the 4.3 worktree at d774ffe9, mark is uncommitted". | Commit 7fb1f0148 (docs/reviews only). Successor 20261118T141133Z PASS. | no |
| 5 | implementation-20261118T143433Z | 5-1 | 11 | A UI change with only vitest/jsdom tests and no browser-level test. | recorded elsewhere, product test | Code review (graph a0a7dd4b0 docs/reviews/s323/5-1-code-review.md, line 49): "server/test_live_smoke.py is untouched and the diff has no smoke or e2e file"; QA 5-1-qa-validation.md line 98 the same; dev strategy row ST323-114 "missing / e2e arm not written". All accepted through the AC5 reason and the AC8 deferral. | Commit da15cf312 added 2 e2e specs and story text. Successor 20261118T144911Z PASS. | yes, two e2e specs added (tests, not product code); the gate was the only round that refused |
| 6 | implementation-20261118T143433Z | 5-1 | 11a | The Dev Agent Record records no command, envvar or outcome for a live run. | recorded elsewhere, records | QA (graph a0a7dd4b0 docs/reviews/s323/5-1-qa-validation.md, lines 70-71): "AC7 / DEPLOY-PENDING ... live read not performed" and "AC8 / DEPLOY-PENDING ... the assertion is unwritten"; line 139 the same. The same QA deploy-pending deferral as rows 10, 12 and 13. | The same commit reworded Smoke Test Updates to "no live path planned". Successor PASS 11a as "Exempt ... No envvar-gated live path exists". | no, cleared by rewording |
| 7 | implementation-20261118T152410Z | 5-3 | 11 | "a visible UI element covered only by an endpoint check FAILS": no Base TEL card DOM assertion. | recorded elsewhere, product test | QA (graph 14cad80ba docs/reviews/s323/5-3-qa-validation.md, line 156): "AC4 Base card DOM smoke assertion is unwritten (ST323-131, missing); lead-accepted deferral"; code review line 46 records the same deferral. | Commit 8f03c8cbf added a 112-line Playwright spec. Successor 20261118T154911Z PASS. | yes, an e2e spec added (test); the gate was the only round that refused |
| 8 | implementation-20261118T152410Z | 5-3 | 11a | The Dev Agent Record says only "AC5 API read DONE (live run deploy-pending)", with no command, envvar or outcome; QA had already run it ("2 passed"). | recorded elsewhere, records | QA (graph 14cad80ba docs/reviews/s323/5-3-qa-validation.md, line 62): "The story and the dev record AC5's live run as deploy-pending, and the reviewer states it was run by no one. QA ran it"; line 91 the same. | Commit 8f03c8cbf copied QA's run into the Dev Agent Record. Successor PASS. | no |
| 9 | implementation-20261118T170930Z | 5-4 | 1 | The story file has no Gate-status line (parts 1-3 only, under _bmad-output/gate-adjudication/, no merged verdict; checks 6 and up never adjudicated). | gate variance, records | None before the FAIL. But the same gate PASSED the same missing Gate-status state at 4-2 (133343Z), the 4-3 rerun and 5-1 (adjudicator note 14:52:47Z); lead 16:11:32Z: "NO Gate-status line in the story — accepted 4.2/4.3 precedent". | 0b634d223..496deae42, 2 story lines. Successor 172256Z PASS Check 1. | no |
| 10 | implementation-20261118T172256Z | 5-4 | 11a | The Dev Agent Record holds no command, envvar or outcome for the live run: "AC5, AC6 landed, deploy-pending". | recorded elsewhere, records | QA (graph a9b015557 docs/reviews/s323/5-4-qa-validation.md, lines 230-231): "AC5 / DEFERRED / ... deploy-pending"; code-review-p2.md line 46: "AC5/AC6 are deploy-pending". | 496deae42..d7a8e25f3, story 6 lines and test-results/s323-5-4-live-attempt.txt ("2 failed, 238 deselected", expected before deploy). Successor 173215Z PASS. | no |
| 11 | implementation-20261118T213543Z | 5-5 | 1 | The 5-5 p3 code review line "carried: none owed" does not end in " — resolved" or " — open". Location: graph a9b015557 _bmad-output/implementation-artifacts/s323/gate-adjudication/implementation-20261118T213543Z.verdict.json, which quotes "carried: none owed. The p2 file carried no open Critical or Important findings". The review file was untracked at the gate and was first committed already fixed, at graph 77ebc31c6. | gate-only, records | None. The p3 reviewer wrote it at 21:07:49Z; the first validate-carried-findings.sh run on the p2 to p3 pair is the adjudicator's (21:41:45Z). | Line rewritten "No carried findings owed: ...". Successor 220335Z PASS. | no |
| 12 | implementation-20261118T213543Z | 5-5 | 11a | The Dev Agent Record has only "AC6 code landed ... live run deploy-pending". | recorded elsewhere, records | QA 5-5-qa-validation.md line 244 and -p2.md line 253: "the attempt is therefore deploy-pending by design". | 0617fced0..5c1d808dc, story 2 lines and a live-attempt capture ("2 failed", before deploy). Successor 220335Z PASS. | no |
| 13 | implementation-20261119T002345Z | 5-2 | 11a | The only AC9 line is "AC9: the smoke node above". | recorded elsewhere, records | QA (graph a9b015557 docs/reviews/s323/5-2-qa-validation-p2.md, line 230): "no live attempt exists at gate 2; it is carried as a deploy-pending deferral ... not scored"; the qa p2 shard cross.md line 26. | cdbe474b0..e154f3a47, story 7 lines and test-results/s323-5-2-live-11a.txt ("1 passed in 5.12s"). Successor 004349Z PASS. | no |

## Counts

- Gate-only: 4 (rows 1, 2, 3, 11). All four are records or process. None changed product code or tests.
- Gate variance: 1 (row 9). The same gate passed the same state on three other stories.
- Recorded elsewhere, the gate the only round that refused: 7 (rows 5, 6, 7, 8, 10, 12, 13).
- Lead-recorded: 1 (row 4).
- Total: 13.

The only two fixes that changed product code or tests are rows 5 and 7, which added e2e test specs. Code review
and QA had already recorded both defects, and the lead had accepted both as deferrals. Row 3's remedy was a
re-verification seat that changed no code, so the shipped 3-2 code is the plain dev's.

Row 9 shows the gate is not self-consistent on Check 1: it failed 5-4 for a missing Gate-status line after
passing the same missing line on 4-2, 4-3 and 5-1.

## Gate-only defects: survival and consequence

The step-value ruling ("A step with no measured value goes", `.claude/rules/operator-rulings.md`) keeps a step
that has a named failure case no other round catches and that survives to the shipped artifact. These FAILs
belong to the gate-adjudicator pass of the planning, sprint-review and implementation gates: the counter keys
a discard's gate type on the nonce prefix, the TYPES regex at
`docs/analysis/step-value-b256/bl512/count_discards.py:80 "TYPES = r"`.

| Row | Nonce | Gate type | Defect | Survives to a shipped artifact had the gate not caught it? | Consequence | Evidence |
|---|---|---|---|---|---|---|
| 1 | planning-20261118T025210Z | planning, Check 2 | Escalation S323-ARCH-P1-LEG2-PREBOUNDARY carried the out-of-set token OPEN and no Status line. | Yes. The entry stays in graph's docs/escalations/pending.md, which the consumer's later gates read at Check 2 through `validate-escalation-status-vocabulary.sh --open` (its header: "gate-validation.md Check 2 reads this instead of Reading pending.md whole"). | Low. Only the entry's form was wrong; the decision and its default did not change (fix dec6dd62b changed the label only). The current release's validator refuses this entry on its own (see "Note on row 1"). | graph dec6dd62b^ docs/escalations/pending.md, line 5998; fix dec6dd62b. |
| 2 | sprint-review-20261119T193613Z | sprint-review, Check 1 | The step-3 QA file read `Verdict: **APPROVED**`, outside the QA set PASS / NEEDS_REWORK. | Yes. The token stays in graph's docs/reviews/s323/sprint-review-step3-qa-validation.md, a committed QA record whose verdict token later checks read. | Low. The QA substance was 0 findings; only the verdict word was wrong. | graph f745b70b4^ docs/reviews/s323/sprint-review-step3-qa-validation.md, line 29; fix f745b70b4. |
| 3 | implementation-20261119T015536Z | implementation, story 3-2, Check 22 | The story carried `escalate_model: true`, but its only dev seat was a plain `dev`. | Yes, as a record. The story ships tagged `escalate_model: true` with no escalated seat in its records. | The code consequence (code built by the non-escalated seat) was not prevented: the remedy only re-verified with an escalated seat, and the shipped 3-2 code is the plain dev's. What the gate's FAIL changed is the record: a verification block in the Dev Agent Record and the spawn-ledger remediation. | graph 5fe4b5ce7 story-3-2 frontmatter, line 19; re-verification commit 756583319. |
| 11 | implementation-20261118T213543Z | implementation, story 5-5, Check 1 | The p3 code review line "carried: none owed" did not end in " — resolved" or " — open". | Yes. The malformed `carried:` line stays in graph's docs/reviews/s323/5-5-code-review-p3.md, which the next review pass's `validate-carried-findings.sh` reads. | Low. The content ("none owed") was accurate. | graph a9b015557 _bmad-output/implementation-artifacts/s323/gate-adjudication/implementation-20261118T213543Z.verdict.json (quotes "carried: none owed. The p2 file carried no open Critical or Important findings"); the review file was untracked at the gate and first committed already fixed, at graph 77ebc31c6; adjudicator's validator run at 21:41:45Z. |

The ruling's result: all four gate-only defects would have survived into committed records a consumer reads.
Each is low-consequence paperwork or process, and none changed shipped code. Each is a named failure case that
no other round caught and that survives to the shipped artifact, so the ruling keeps the gate-adjudicator pass
of these three gates.

## Note on row 1

Measured by the owner: the current distribution's validator refuses this entry. ai-dlc's
`core/scripts/validate-escalation-status-vocabulary.sh:358 "STATUSLESS-ENTRY, fail-closed"` fails a dated
escalation entry with no **Status:** field. Run on a copy of graph dec6dd62b^ docs/escalations/pending.md, it
exits 1 and prints a STATUSLESS line for line 5998,
`## [S323-ARCH-P1-LEG2-PREBOUNDARY] [lead] - OPEN - 2026-11-17T23:55:42Z`, with 16 statusless entries. Run on
graph dec6dd62b docs/escalations/pending.md, the fixed file, it prints no LEG2 line and 15 statusless entries.
Graph ran an older installed copy, which skipped such an entry. Under the current release, row 1 is no longer
the gate's alone. Graph's pending.md still carries 15 other statusless dated entries.

## Absence claims

Each claim reads "no other round recorded this defect before the gate". Counts are: the absence query, the
positive control (must be non-zero), the negative token (must be 0).

- Row 1 (scan code `s323-scans/scan.py`, transcripts before 03:01:01Z). `LEG2-PREBOUNDARY` with context
  `(\*\*Status|OPEN|vocabular|out-of-set|HARD_BLOCK)`: 84 hits. Excluding the 3 adjudicator agents,
  `vocabular|no \*\*Status|Status line|out-of|missing status` finds only lead relay lines from 02:56:35Z on.
  Positive control: adjudicator agent a91445e5, 8 lines of r1.txt (`grep -c 'agent-a91445e5' r1.txt`). Negative,
  row 1's own invocation (`scan.py 2026-11-18T03:01:01Z 'zq9xx-no-such-token-h271'`): TOTAL 0. Repository:
  `git grep -E 'LEG2-PREBOUNDARY.{0,200}(vocabular|no \*\*Status|out-of)' a9b015557`, gate-adjudication/
  excluded: 4 hits, all downstream of the gate; positive control (the verdict.json) 1; negative 0.
- Row 2 (scan.py, transcripts before 19:49:21Z). `step3-qa-validation` with
  `(APPROVED|NEEDS_REWORK|verdict set|not in .{0,30}set|qa\.md)`: 17 hits. Excluding the 4 adjudicators,
  `not in|isn.t in|outside|vocabular`: 2 hits, both lead relays after 19:41:45Z. Positive control: agent
  ae1071e6, 1. Negative 0. Repository grep: only post-gate or unrelated hits; positive control (the
  verdict.json) 1; negative 0.
- Row 3. `git grep -n -i -E 'dev-escalated|escalate_model|plain .?dev|sonnet' a9b015557` over
  docs/reviews/s323/3-2-*, gate-transition/3-2-* and dev-report-3-2.md (43 files): 0. Positive control:
  `handled by a plain` in the 015536Z verdict.json, 1. Negative 0. Transcripts before 02:08:45Z (scan.py):
  21 hits, all lead ledger dumps with no flag, agent ab67f483 (about 5.2) and agent afe90b1d (the gate's own
  adjudicator, the positive control: 4 lines of the r3c.txt listing, `grep -c afe90b1d r3c.txt`). Negative 0.
Rows 6 and 8 below were first read as absences with the narrower grammar; the wider grammar in the method
section finds the QA records quoted in the table, so they are now presence claims. Their first scans are kept
as run:

- Row 6 (`s323-scans/rows-b-11a-scan.py` over the corpus built by `s323-scans/rows-b-corpus.py`). Check 11a
  for 5-1 before 14:34:33Z: 0. Positive control (14:34:33Z to 16:10Z): 226. Negative 0. Review files
  (README, "rows 4-8 review-file grep"): 5-1 code review 0, 5-1 QA 1 (line 56 "Production Integrity", not an
  11a finding); positive control "Dev Agent Record" in the 143433Z verdict.json, 5; negative 0.
- Row 8 (same scan). Check 11a for 5-3 before 15:24:10Z: 10 raw hits, all of them 5-1 gate notes in lead
  transcript 53b4296a (14:44:32Z, 14:53:14Z, 15:03:16Z), where 5.3 appears only as a to-do; real 5-3 hits 0.
  Positive control (15:24:10Z to 16:10Z): 110. Negative 0. Review files: 5-3 code review 0, 5-3 QA 0;
  positive control "Dev Agent Record" in the 152410Z verdict.json, 5; negative 0.
- Row 9 (`s323-scans/scan-transcript-gatestatus-5-4.py`, 8725 transcript files). `Gate-status|gate.status`
  within 200 characters of `5-4|5.4|5x4` before 17:09:30Z: 0. Positive controls: 196 in the adjudicator
  window (17:09:30Z to 17:25Z) and 128 near 5-1 before 17:09:30Z. Negative 0.
- Row 11 (`s323-scans/scan-transcript-carried-5-5.py`, transcripts 20:30Z to 21:46:08Z). `carried: none owed`,
  a `carried:` line, or a validate-carried-findings run on 5-5-code-review-p2, on a 5-5 line: 108 hits (the
  positive control). Read in time order, the earliest validator run on the p2 to p3 pair is the adjudicator's
  at 21:41:45Z, inside the gate; pre-gate runs 0. Negative 0, counted in the same invocation.

Rows 4, 5, 6, 7, 8, 10, 12 and 13 are presence claims: the other round's record is quoted in the table. The
review-file and verdict scans for rows 9-13 are in the README.
