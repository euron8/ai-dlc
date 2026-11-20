# Findings of reader `tip-adversary` (recovered verbatim from its transcript agent-atip-adversary-bccf597824f59d63.jsonl)

## SENT 2026-11-20T11:36:34.059Z | C10 tip adversary: 1 BLOCKER, 6 DEFECTs

C10 tip adversary (88a5a4da9), verdict: 1 BLOCKER, 6 DEFECT, 4 NOTE.
The BLOCKER is the report's claim that BL-975 had a zero population in s323. BL-975's own batch-261 PARTIAL shows 44 deaths.
Backlog mechanics, the engine facts, the operator decisions, links and secrets all check clean.

BLOCKER
B1. report.md:150, "BL-1005 and BL-975 read zero populations in s323 and decide nothing." This contradicts backlog.md:2988 (BL-975 PARTIAL v0.1185.0). That entry says s323 is "the first window in which scan.sh finds a death". It found 44 deaths on 2026-11-19, and the notice latency median went from 3717 s (s322) to 832 s (s323). There is no source for "zero": grep BL-975 over pipeline-efficiency-s323-complete-b261.md and s323-outcomes-b261/ returns 0 lines. Control: BL-975 is found at backlog.md:2934.
Fix: drop BL-975 from that sentence, or say "BL-975: 44 deaths in s323, notice median 3717 s to 832 s; Outcome line still owed (the grammar cannot express it)". Put BL-975 in the "Partly" table.

DEFECT
D1. backlog.md:2329 (BL-716 block), "Correction: the single-lane class is 1.1 h ... not the 6.2 h this entry carries as the LANES=1 round figure (6.20 in s323)". The 6.20 h figure comes from the committed `serial_tail.py` run (backlog.md:2310: "LANES=1 round ... 6.20"). The 1.1 h figure comes from the planning reader, whose script is not committed (README:40-42). It also measures a different set: single-document single-lane rounds of lone-remediator time, not every LANES=1 round. Calling it a "Correction" tells a later builder that the scripted figure is wrong. report.md:259 says the same thing ("not the 6.2 h BL-716 carries").
Fix: "a different class: of the 6.20 h LANES=1 rounds, 1.1 h is single-document rounds (uncommitted reader)". If you treat "mislead a builder" strictly, promote this to BLOCKER.
D2. report.md:22, "compacted 134 times, once every 18 minutes". The source, out/lead-time/c1.txt line 18, says "minutes between: median 17.8 mean 31.0". The same report at :136 gives 1.78 compactions per elapsed hour, which is one every 34 minutes. Fix: "a median 18 minutes apart".
D3. backlog.md BL-1187 item 3 gives the dev role file as "dev 31,554". `wc -c core/team-roles/dev.md` at 88a5a4da9 gives 31678 (qa 50457, code-reviewer 48987, adversary 46895 and remediator 39519 all match). Also, architect.md is 16,796 B, which is over the 16,384 limit, and is missing from the item (and from report.md:295, "Five role files"). Fix: 31,678, and add architect at 16,796 B, or state why it is excluded.
D4. BL-1186 item 4, "Reach: 6.4 h protected", and its "Expected movement" ("the hours a declared serialization holds stories the lead already ran together"). In s323 the lead had already run those stories together, so the item cannot move the s323 baseline it is to be read against. Fix: label item 4 as 0 h against the s323 baseline (it protects existing practice) and take it out of the Expected movement.
D5. BL-1187 item 1, "Reach: $133; upper bound $159". report.md:293 gives $133 alone, and report.md:60 says every saving is an UPPER BOUND. The same item carries two different hedges. Fix: one figure with one hedge in both places.
D6. report.md:16, "s323 is the fastest and cheapest sprint per story measured". The cited source, roll.monotone-clock.txt (s317 TOTAL line), gives s317 at 3.5 h and $66.7 a story. s317 is truncated (backlog.md:482: 13 of 19 steps). Fix: "of s318 to s323".

NOTE
N1. README:29 lists a `d1b` script under scripts/lead-time/. There is no d1b.py in the commit (only out/lead-time/d1b.txt and d1b_323.txt). README:5 says "every .json ... was left out", but out/asks/tally.json is committed (counts only, no text).
N2. report.md:138, the BL-716 row "13 of 15 pass-2 and pass-3 major findings". grep '13 of 15' over backlog.md, backlog.archive.md and s323-outcomes-b261 finds 0 (control '9.62' is present). This conflicts with :107, "Figures are quoted from the entries' batch 261 readings". Cite the reader instead.
N3. report.md:307 does not record the operator's 2026-11-20 decision on update pace ("keep as is"). Nothing in it is wrong. Also, :173 and :193 use "BLOCKER" as a ranking word inside an analysis document.
N4. report.md:18, "The fix that did it is the adversary seat's return": a causal claim made from one comparison.

Checked and clean:
- Sprint totals and the per-step table match roll.monotone-clock.txt and s323_complete.txt in every cell I summed, within rounding. Lead calls (by model mix) and compactions per hour (0.51 / 1.08 / 1.78) match.
- Engine facts: omitClaudeMd is set on 4 roles (adversary, analyst, gate-adjudicator, pre-reviewer). gate-validation.md is 247,205 B. roll.py P: cw = 2 x input for all four models. "admission" appears in 0 files under steps/ and team-roles/ (control: "dispatch" in 42). PushNotification appears only in a fixture's roster string. retro.md has 1,739 lines and 8 code fences. The dev.md:127 and protected-path-editor.md:7 citations are correct, and so are the template line numbers 37 and 55. The pre-dispatch auth check exists (implementation.md:108).
- Backlog: `git diff --numstat` gives 144 added and 0 deleted lines (control: the previous commit deleted 167). Each block sits inside its own entry, before that entry's Step/verify lines. Numbering continues: BL-819 4-10, BL-716 4-5, BL-972 6-8, BL-1166 3, BL-1175 22; BL-975 and BL-1174 start at 1 and had no list before. `verify:` lines go from 172 to 174, one per new entry. BL-1186 and BL-1187 each have one done condition, a baseline, no target number and `verify: manual`.
- Operator decisions: scope, the standing-rulings record, proceed-on-recommendation, the push notification "NOT chosen", and graph handled by coordination and never written are all recorded correctly. "pull" appears 0 times in the report.
- New directory: every README entry exists except d1b.py (N1). 0 email addresses, 0 credentials. 33 of 60 scripts carry absolute scratchpad or home paths, and README:17-20 says so. ag.txt holds short agent descriptions, which the README declares.
- Every link in the report and in the two pointer sentences resolves at 88a5a4da9.

## FINAL-TEXT 2026-11-20T11:36:44.436Z

I found one BLOCKER in commit 88a5a4da9, plus 6 DEFECTs and 4 NOTEs, and sent the full findings to team-lead. I edited, committed and pushed nothing.

**BLOCKER:** the report says BL-975 read a zero population in s323 (`docs/analysis/pipeline-efficiency-s323-opportunities-b261.md:150`). BL-975's own batch-261 PARTIAL (`docs/backlog.md:2988`) says the opposite: it found 44 deaths in s323, and the median notice delay fell from 3717 s to 832 s. Nothing in the s323 outcome records supports "zero".

**DEFECTs:**
1. **BL-716 "Correction"** (`docs/backlog.md:2329`): it calls the committed, script-derived 6.20 h figure wrong. The 1.1 h that replaces it comes from a reader whose script is not committed, and it counts a different set of rounds. This could mislead a later builder, so the lead may want to treat it as a BLOCKER.
2. **"Compacted once every 18 minutes"** (report line 22): 18 minutes is the median gap. The report's own figure of 1.78 an hour means about one every 34 minutes.
3. **BL-1187 item 3, role-file sizes:** it gives dev as 31,554 B, but the file in the tree is 31,678 B. It also leaves out `architect.md`, which at 16,796 B is over the 16,384-byte read limit.
4. **BL-1186 item 4:** it claims "6.4 h protected" and counts it in Expected movement. The lead already ran those stories together in s323, so this item cannot move the s323 baseline it will be read against.
5. **BL-1187 item 1:** it says "$133; upper bound $159", while the report gives $133 and calls every saving an upper bound. The same saving carries two different hedges.
6. **"Fastest and cheapest sprint per story measured"** (report line 16): the source table it cites shows s317 at 3.5 h and $66.7 a story. s317's data is incomplete, so the claim should say "of s318 to s323".

**NOTEs:**
- The README lists a `d1b` script that is not in the commit. It also says every `.json` file was left out, but `out/asks/tally.json` is committed (counts only).
- The BL-716 row figure "13 of 15" does not appear in any entry, though the report says those figures are quoted from the entries.
- The report leaves out the operator's "keep as is" decision on engine-update pace, and uses the word "BLOCKER" to rank opportunities.
- "The fix that did it" is a causal claim resting on one comparison.

**Checked and clean:**
- The sprint totals and per-step tables match their sources within rounding.
- The engine facts the report asserts hold. The `omitClaudeMd` count, the `gate-validation.md` size and the `roll.py` cache-write price are all correct. No step or role file mentions "admission", checked against a control.
- `docs/backlog.md` has 144 lines added and 0 deleted. Every block sits inside its own entry and continues its numbering, and the two new entries are well formed.
- The operator's 2026-11-20 decisions are recorded correctly, and nothing reads as authorizing a consumer pull.
- Every link resolves, and the new directory holds no email addresses or credentials.

