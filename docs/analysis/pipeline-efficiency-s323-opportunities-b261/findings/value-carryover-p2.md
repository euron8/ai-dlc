# Findings of reader `value-carryover-p2` (recovered verbatim from its transcript agent-avalue-carryover-p2-9cfdd8ab70df4184.jsonl)

## SENT 2026-11-20T13:04:46.574Z | Carry-over p2 value reading: verdict REPLACE (conditions)

carry-over-evaluation p2 value reading. VERDICT: REPLACE p2 with ONE final adversarial pass over the repair-written text. Not KEEP: no high-consequence p2 catch sat outside such a pass's view. Not CUT: p2 found real defects, all in repair-written text.
Scripts and tables: /private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/steps/carryover-p2-value/ (README.md, heads.txt, bodies.txt)

POPULATION. p2 ran in s320, s322 and s323; s319 ran p1 only. p2 has 25 MAJOR and 0 CRITICAL: 9, 9 and 7 per sprint. The s322 headings are 7 plain plus 2 marked "(underived)". The earlier reading's 9 for s320 reproduces. I read all 25 bodies (bodies.txt). p3 has 3, 2 and 1 MAJOR.

1. PROVENANCE. A "diff-scoped" pass means one that sees every line any repair wrote or changed (party, elicitation, p1 repairs) and may read anywhere else to check those lines.
- Repair-written: 21 of 25. Each body names its source ("Introduced by", "written by", "repair entry ..."): s320 8, s322 7, s323 6.
- Three more sit on a line or clause a repair rewrote, but the defect is in text that stood:
  - s320 cross-1 F-1. The `Dependencies: none` field sat in the Bucket 1 bullet at b20bd5442 line 88, before any repair. The p1 serial repair edited the same bullet at :90 and fixed the sentence beside the field.
  - s322 section 3 F-3. The sentence "Per the operator's disposition there is no re-route" (line 506) was kept inside a paragraph the p1 repair rewrote.
  - s323 section 3 F-3. The :2014 exception clause was rewritten by a repair. The text it contradicts (:1963, :432) stood, and p2 itself says "not repair-injected".
- Unseen: 1 of 25. s322 cross F-1, the AC3 organic-row predicate stated two incompatible ways (lines 261/307 against 1117). These lines stood. It is the residual of pass-1 cross F-5, which no repair record addressed. p2's body says: "No entry in coe-repair-p1.md or coe-serial-repair-p1.md addresses it". p1 raised it first, so p2 only re-found it. A join of p1 finding ids to repair-record entries catches it without a model pass.

2. THE s320 CATCH (wrong-sign IL cause, 2.md F-1). It was repair-written text, so yes, it was in scope. Evidence, from graph blobs (git cat-file, grep -c -F, control token ZZ-NEVER-TOKEN-x9 = 0 in all five):
- "not actually fee-inclusive" is r1 (party repair) 0, r2 (elicitation repair) 0, r2b (p1 section repair) 1, r3 (p1 serial repair) 1, r4 (shipped) 0. The authored and earlier-repaired text had "an oversized fee subtraction", the correct direction.
- Source: the lead-directed correction recorded in coe-repair-p1.md. The p1 repair wrote it.
- The sibling catch, cross-2 F-1 ("same pool and lifetime IL figure"), is also repair-written: r2b 0, r3 2, r4 0. The shipped text names `pool_lifetime_il_usd_lifetime_scope` three times.
- Condition: scope must come from the artifact diff, not from repair records alone. The correction was a lead edit, recorded only in the repair file. cross-2 F-1 also needs the pass to read server/aggregator.py, so scoping must not restrict what it may read.

3. DOWNSTREAM CHANGES (traced by quoted token into later artifacts). 6 traced; I traced no others, so 6 is a floor.
- s320, 2 traced:
  - stories/story-2-1 (and epics/part-2.md) carry the four-cause set with the post-p2 wording "a `current_value_usd` that counts something it should not". The strings "fee-inclusive" and "not actually fee-inclusive" are absent from all s320 stories and epics. Story 2-1 is the investigation that sets the scope of the aggregator IL fix in story 2-2.
  - story 2-2 names the corrected field `pool_lifetime_il_usd_lifetime_scope`.
- s322, 4 traced, all through s322/requirements-context.md:
  - M-2 reads "AC4 compares leaf-wise ... never a sha256" (2.md F-1).
  - M-1 states the AC3 predicate with no status/mode conjunct (cross F-1).
  - M-3 keeps the AC1 deploy-timestamp source OPEN and operator-owned, with CFN stack events as an option (cross F-2).
  - It records that the "execution.py readers return nothing" claim is refuted: two tests read execution.py through `_exec_mod.__file__`, outside the 45-file sweep (s322 p3 F-1, and the p2 section 3 F-1 whole-class readers).
- s323: 0 traced. Of the 14 uncited tag-only rows, only CO-S316-SR-B3 reaches requirements-context, and it comes via a different line (:1242). The stories read carry-over-backlog.md:1120 directly, not the evaluation's false sentence about it. Not derivable whether anything consumed the other s323 repairs.
- Of the 6: diff-scoped final pass sees 5, misses 1 (s322 AC3 predicate, the same item as in section 1).
- Not traced: 19 findings, mostly missing-derivation fences. Their consequence is a wrong record, not changed code.

4. COST OF p2 PLUS ITS REPAIR (subagent API-list $; agent-minutes are summed spawn minutes, not wall).
- s320: 19 spawns, $28.29, 104.6 agent-min (review 13 / $24.74 / 89.4; repair 6 / $3.55 / 15.2). Wall 18:18 to 18:42, 24 min.
- s322: 16 spawns, $48.70. Review 9 spawns $43.21 (cross shard dispatched three times, $22.2 of the total, 287 agent-min); repair 6 / $3.25 / 10.8 min; serial lane 1 / $2.24. Wall 04:07 to 06:21, 134 min. The serial lane's 341.6 min runs to 12:06 and is idle-dominated, so I give no cost for it.
- s323: 13 spawns, $19.5, 64.9 agent-min (matches the step reader's rounds_t). Wall about 39 min (01:43 to 02:22); lead active 29.2 min.
- Total across the three: about 48 spawns, $96.5.
- A final pass would still cost one review round. Saving is therefore p2's repair and re-run, not all of p2. My estimate, not measured: roughly 40 to 55% of the figures above (about 15 min wall in s320 and s323, up to about 100 min in s322 where the cross re-dispatches dominated).

5. VERDICT UNDER THE STANDING RULE. REPLACE, because:
- The rule's KEEP trigger is a high-consequence p2 catch outside the replacement's view. The only one outside it (s322 AC3 predicate) is moderate consequence: an observation AC would misclassify a FAILED organic row. It is also a p1 finding the repair dropped, so p2 re-found it and was not its first catch.
- Every other p2 catch, including the s320 IL pair on the aggregator IL path, sat on repair-written or repair-touched text. 24 of 25 are visible at line or clause level, and 21 strictly.
- Conditions for the replacement:
  - (a) Scope by file diff from the analyst draft, so lead hand-edits are included. Not by repair records.
  - (b) The pass may read the rest of the document, the code and the backlog to check each written line. s320 cross-1 F-1, s320 cross-2 F-1 and s323 F-3 each needed a read outside the diff.
  - (c) A mechanical join of every p1 CRITICAL and MAJOR id to a repair entry, to catch the s322 AC3 type.
  - (d) If p1 is also removed (step-carryover's "one terminal pass"), the pass covers party and elicitation repair text only. p1's own catches on standing text are outside this reading and need their own check.

NOT DERIVED:
- p2 shard-by-shard overlap with p1 findings in s322 and s323, beyond what the bodies state.
- s320 downstream for the 7 documentary p2 findings.
- Whether any p2 text was repair-written at the sub-sentence level in s323, where there is one planning commit. I relied on each body's "Introduced by" and its repair record's before/after quotes.
- The consequence figures for s320 IL are reasoned from story text, not from shipped code. Whether story 2-2's fix actually shipped differently without the p2 fix was not traced.

## FINAL-TEXT 2026-11-20T13:04:56.941Z

The verdict is REPLACE p2 with one final adversarial pass over the repair-written text. I sent the full reading to `team-lead` as one message.

- **What p2 caught:** p2 raised 25 MAJOR findings and no CRITICAL, in s320, s322 and s323. s319 ran no p2. Of the 25, 21 sit on text a repair wrote. Three more sit on a line or clause a repair rewrote, with the defect itself in older text. Only 1 sits outside a repair's reach: s322 cross F-1, the two incompatible statements of AC3's organic-row predicate. p1 had raised it first and no repair record answered it. A join of p1 finding ids to repair entries would catch that without a model pass.
- **The s320 catch:** the wrong-sign impermanent-loss cause was text the p1 repair wrote. I checked this against the graph artifact blobs, with a negative control. "not actually fee-inclusive" is absent after the party and elicitation repairs and present after the p1 repair. A final pass over repair-written lines would have had it in scope. That holds only if the scope comes from the file diff, because the line was a lead-directed correction recorded in a repair file. The reviewer must also be allowed to read `server/aggregator.py`.
- **Downstream:** I traced 6 p2 findings into later artifacts. 5 of those 6 are visible to a diff-scoped pass, and the one it would miss is the AC3 predicate. Two reach s320 stories 2-1 and 2-2. Four reach `s322/requirements-context.md`. None of the s323 findings traced downstream. I did not trace the other 19, mostly missing-derivation fences, so 6 is a floor.
- **Cost of p2 and its repair:**

| Sprint | Spawns | Subagent spend | Wall clock |
|---|---|---|---|
| s320 | 19 | $28.29 | 24 min |
| s322 | 16 | $48.70 | 134 min |
| s323 | 13 | $19.5 | about 39 min |

  s322's cross shard was dispatched three times, which is $22.2 of its total.
- **Why not KEEP:** the one catch outside the replacement's view is moderate consequence and was a repeat of a p1 finding.
- **Conditions on the replacement:**
  - (a) Scope by the diff from the analyst draft, not by repair records.
  - (b) Let the pass read code, the backlog and the rest of the document.
  - (c) Add the p1-finding-to-repair join.
  - (d) If p1 is also removed, its catches on older text need their own check.
- **Not derived:** I traced no overlap between p1 and p2 beyond what each finding's text states. Downstream effects of the 7 documentary s320 findings are untraced. s323's single planning commit limits the before/after provenance. The s320 consequence is reasoned from story text, not shipped code.

Files are in `/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/steps/carryover-p2-value/`:
- README.md
- heads.py
- heads.txt
- bodies.py
- bodies.txt

