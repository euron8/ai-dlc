# Pipeline efficiency, graph sprints 317–322, batch 259 update: s322 complete, what was built, and what is left

Measured 2026-11-18. This updates [`pipeline-efficiency-s317-s322.md`](pipeline-efficiency-s317-s322.md),
which read s322 while it was partial (3 of 8 stories done). Scripts and raw output are in
[`pipeline-efficiency-s317-s322-b259/`](pipeline-efficiency-s317-s322-b259/). Nothing was written to graph.

**Sprints updated with: s322 only, now complete.** s323 is in progress and, by standing operator ruling, no
s323 reading is taken until it completes. There is no newer complete sprint.

## Answer

1. **s322 complete is the slowest sprint per story measured, at 9.6 h a story** against 4.8 h in s321. Its
   $168.6 a story is the highest only because the local-model lead is priced at the hosted mix it replaced; on
   API dollars it is $123.7 a story, below s318 and s320. Most of the hours are sprint size. Planning cost $890
   and 44.0 h for 8 stories; s321's planning cost $1,297 for 25. Planning is close to a fixed charge per
   sprint, so a small sprint pays it over few stories.
2. **The fixes that worked still work.** Subagent sleep polls (0.01 h), cap-rejected spawns (0 of 584), gate-1
   shards per pass (1.44) and implementation dollars per story ($27.9) all held.
3. **Implementation hours per story did not hold: 2.01 h in s322 against 1.13 h in s321.** Dollars stayed flat.
   6 of 8 stories failed gate 1 on the first pass.
4. **Two readings in the earlier report do not stand.** The scripted gate transition (BL-913) read as
   improved at 0.06 h per story on the partial window; at complete it is 0.142 h against s321's 0.125 h. s322's
   carry-over evaluation read as $418 and 26.5 h with requirements at $112 and 4.4 h; the current extractor
   puts them at $231 and 19.5 h, and $298 and 10.7 h. The two steps sum to the same $530 and 30 h either way,
   so the cost moved between them and neither split has been validated.
5. **The lead made more calls in a shorter sprint.** 10,128 lead calls in 77.1 h in s322 against 8,005 in
   120.5 h in s321, which is 1,266 per story against 320 on s322's 8 stories. Compactions were 72 against 57.
   `snapshot-update.sh` ran 1,057 times against 754.
6. **The largest fix from the earlier report cannot be judged yet.** The adversary seat went back to
   opus/medium (BL-971, 0.1048.0), but 124 of s322's 125 adversary spawns ran on sonnet/high. The same is true
   of everything that landed after 0.1061.0, which is where graph's engine stood when s322 closed. s323 is the
   first sprint that can show them.
7. **BMAD.** The pipeline uses the BMAD skills it calls broadly as intended. Seven opportunities came out of
   the comparison; the three with the largest wall clock are batching operator decisions as planning-time
   checkpoints, tiering the stories cycle by risk, and a quick independent review inside the dev seat.

## Population and method

**Corpus.** `~/.claude/projects/-Users-n8-git-graph/`, window end pinned at
`EXTRACT_WIN_END=2026-11-12T14:41:00Z`, the pin batch 256 used. Graph commit `f7e60625b` ("sprint 322 closed",
8 stories done) is at 2026-11-12T12:32:58Z; the last s322 spawn ends 12:47:51Z and the last s322 lead record is
14:40:12Z. Between the pin and `extract.py`'s s322/s323 edge (2026-11-13T08:00Z) there are two session files,
both `/ai-dlc-update` reconcile sessions with no record before the pin; neither names a sprint and neither is
counted.

**Scope.** In-session time only. Idle time between a handoff and the next `/ai-dlc resume` is excluded by
operator ruling and appears in no figure.

**Dollars** are API-list-equivalent at `roll.py`'s prices. s322's lead ran local models (`qwen38flash` 9,206
calls, `deepseek41` 96) and is priced FALLBACK at s321's hosted mix.

**No timing runs.** Every figure is read from transcripts and records already on disk.

**Controls.**

| Control | Expected | Got |
|---|---|---|
| Segment tokens = per-transcript tokens | equal | 24,709,666,393 = 24,709,666,393 |
| Subagents joined to a parent step | all | 6,158 of 6,158 |
| Class tokens = segment tokens | all pairs | 450 of 450 |
| s317–s321 `roll.txt` TOTAL lines against the committed output | identical | 5 of 5 identical |
| Records past the pin entering a figure | 0 | 0 (maximum timestamp in `units`, `segs`, `spawns` is 14:40:12Z) |
| Records past the pin that exist in the corpus | more than 0 | about 161,000 |
| `outcome_row.py` against the committed `outcome_row.s322-complete.txt` | identical | 0 differing lines |

**Instrument defects found and fixed in this release.** Each changes how an earlier figure should be read.

- **`classes_summary.s322-complete.txt` and `classes_totals.s322-complete.txt` carried an older step
  attribution.** They predated three `extract.py` commits (`64d6c9a6d`, `9ee073be0`, `ea8c9fb0c`). Both are
  regenerated in place from the pinned extraction. Sprint TOTALs and every "all steps" line are unchanged, and
  s319–s321 class blocks are byte-identical in the summary; the changed lines are in s317, s318 and s322 (and
  two rounding lines of s321 in the totals file). In s322, gate[carry-over] reads 0.39 h against 3.02 h before,
  and requirements 5.02 h against 2.57 h. Which commit moved them was not bisected.
- **`impl_passes.py` could not spell s322's spawn descriptions.** It keyed a story on `N.N`; s322's reviewers
  are named `story 6`, `g1 pass-2`, or carry no story, so it read 6 stories of 8. The script now maps a bare
  `story N` where no `N.N` key exists, assigns a story-less gate-1 spawn to the nearest keyed spawn by start
  time, and reads a lowercase `g1`. Its s317–s321 output is byte-identical to the committed output, and s322
  reads 8 stories where the unfixed script reads 6. Two limits remain: the bare-story mapping assumes epic 1,
  and s322's two story-less spawns went to story 1.8 from 26.7 and 19.6 minutes away, which feeds the 2.38.

**Instrument limits left in place.**

- `bash_by_sprint.py` and `lead_time.py` do not pair `tool_use` with `tool_result`, so Bash call counts
  include denied and errored calls.
- `gate_run_evidence.s322-complete.txt`, `gate_run_readings.s322-complete.txt` and
  `idle_wait_conservation.s322-complete.txt` were not regenerated. The last needs a second extraction on an
  older extractor; its "446 of 446" pair count, also quoted in BL-819, reads 450 of 450 on the current one.

**Not measured.** The lead's "other" call class is not decomposed here; batch 259's C2 release owns that reader.
The per-call cost of the BMAD readiness, sprint-planning and trace calls is not on record; it was available
from the spawn ledger and not taken. The origin of each operator ask (planning or mid-implementation) was
available and not taken. No s323 reading exists by ruling. Installed BMAD skill text is not tracked in graph's
git and could not be read at a commit.

## Sprint totals

| | s318 | s319 | s320 | s321 | s322 complete |
|---|--:|--:|--:|--:|--:|
| Stories | 13 | 20 | 13 | 25 | 8 |
| In-session hours | 74.8 | 110.0 | 117.8 | 120.5 | 77.1 |
| of which long waits on agents | 28.3 | 38.2 | 27.0 | 38.6 | 28.0 |
| of which operator wait | 14.3 | 17.0 | 47.9 | 24.9 | 10.3 |
| Token-equivalent $ | 1,721 | 2,234 | 1,623 | 2,388 | 1,348 |
| Hours per story | 5.8 | 5.5 | 9.1 | 4.8 | 9.6 |
| $ per story | 132.4 | 111.7 | 124.9 | 95.5 | 168.6 |
| Subagent spawns per story | 71.5 | 78.0 | 84.8 | 49.4 | 82.4 |
| $ per spawn | 1.53 | 1.13 | 1.14 | 1.52 | 1.50 |
| Lead compactions | 24 | 44 | 36 | 57 | 72 |
| API $ per story | 132.3 | 111.7 | 124.9 | 94.7 | 123.7 |

Source: `out/roll.txt`, `out/decompose.txt`. Token-equivalent dollars price s322's local lead FALLBACK at $359;
the API row does not.

### Per step (elapsed hours / token-equivalent $)

| Step (with its gate) | s318 | s319 | s320 | s321 | s322 complete |
|---|--:|--:|--:|--:|--:|
| carry-over-evaluation | 2.8 / 132 | 3.2 / 110 | 24.8 / 191 | did not run | 19.5 / 231 |
| requirements | 6.3 / 335 | 9.1 / 286 | 7.3 / 210 | 12.5 / 314 | 10.7 / 298 |
| architecture | 4.9 / 191 | 14.9 / 221 | 28.7 / 132 | 10.4 / 305 | 6.0 / 140 |
| stories-test-strategy | 25.6 / 415 | 16.9 / 586 | 15.1 / 627 | 20.2 / 678 | 7.8 / 221 |
| implementation | 11.8 / 423 | 41.8 / 825 | 25.2 / 270 | 28.2 / 638 | 16.1 / 223 |
| sprint-review | 5.6 / 143 | 2.7 / 117 | 2.1 / 20 | 3.5 / 236 | 2.4 / 101 |
| deploy-validate | 5.5 / 25 | 4.9 / 33 | 7.3 / 128 | 29.9 / 177 | 3.6 / 27 |
| retro | 3.8 / 19 | 8.9 / 25 | 3.4 / 29 | 3.1 / 18 | 5.5 / 51 |
| bug-investigation | | | | | 1.6 / 39 |

Source: `out/tables_s322_complete.txt`. The s318 sprint-review cell reads 5.6 / 143 here against 6.7 / 148 in
the earlier report, from the attribution change above.

Planning (the first four rows) in s322 is 44.0 h and $890, which is 5.5 h and $111 per story. s321's was $52
per story.

## Where s322's 77.1 hours went

| Share | Hours | What | s321 |
|---|--:|---|--:|
| Waiting on subagents | 38.6 | 28.0 h in gaps over 5 minutes, plus 10.6 h of idle waits under 5 minutes | about 60 |
| Lead turn time | 28.0 | 10,128 lead API calls at 9.96 s each | about 35, at 16 s a call |
| Operator answers | 10.3 | 25 asks, median 8 minutes, 2 over an hour | 24.9 over 57 asks |
| Lead tool execution | 3.8 | 0.28 h of it is `AskUserQuestion` under 5 minutes | 4.9 |

Source: `out/lead_time.txt`, `out/ask_split.txt`. `lead_time.py` reads every lead transcript, so the rows sum
to more than 77.1.

| Solo-role hours | s318 | s319 | s320 | s321 | s322 complete |
|---|--:|--:|--:|--:|--:|
| adversary | 6.3 | 6.5 | 6.7 | 15.7 | 11.5 |
| remediator | 7.8 | 11.9 | 9.4 | 9.6 | 9.2 |
| analyst | 0.6 | 0.5 | 0.7 | 0.3 | 2.8 |
| gate-adjudicator | 1.0 | 2.3 | 1.8 | 1.8 | 1.7 |
| dev or dev-escalated, the larger | 3.8 | 4.4 | 2.6 | 4.0 | 1.3 |
| Wall clock with exactly one agent running | 20.5 | 26.5 | 20.1 | 28.8 | 19.1 |
| Wall clock with any agent running | 36.6 | 50.3 | 35.5 | 55.9 | 33.4 |

Source: `out/poles_allroles.txt`. The adversary and the remediator together hold 20.7 of the 33.4 hours in
which any agent ran.

## Which optimizations are implemented, and what graph ran

"Implemented" is checked against the shipping code under `core/` and the entry's `LANDED` or `PARTIAL` line.
Graph's engine version is from its reconcile merges: 0.1028.0 when s322 opened, 0.1061.0 when it closed. A
change that landed after 0.1061.0 is in the distribution and has not run in a complete sprint.

### Live in s322 and measured

| Fix | Entry | Shipping code | s322 complete against s321 | Verdict |
|---|---|---|---|---|
| Subagent `sleep` polls denied | BL-514 (0.782.0) | `core/hooks/ai-dlc-foreground-budget.sh:279` | subagent `sleep` 0.01 h against 0.28 h; lead `sleep` 0.22 h against 0.59 h | worked |
| Cap-rejected spawns held | BL-515 (0.784.0) | `core/hooks/ai-dlc-dispatch-guard.sh:951` | 0 rejections of 584 `Agent` calls | worked |
| Delta re-review, captures out of the partition, record-only route | BL-507, BL-808, BL-809 | `core/scripts/partition-review-diff.sh:309`, `steps/implementation.md:459` | gate-1 shards per pass 1.44 against 1.39; implementation subagent $ per story $17.1 against $17.9; step total per story 2.01 h and $27.9 against 1.13 h and $25.5 | dollars held, hours did not |
| Party-round waves | BL-695 (0.857.0) | prose only, `rule-bodies/rule-28.md:187` | 24 seats dispatched within 2.1 minutes, 25.4 minutes of wall clock; $3.79 per story against $4.98 | worked |
| Scripted gate transition | BL-913 (0.1006.0) | `steps/implementation.md:313`, `core/hooks/ai-dlc-dispatch-guard.sh:1487` | lead gate-run time 0.142 h per story against 0.125 h; 8.6 `gate-transition.sh` calls per story against 6.0 | no effect; the earlier "worked" reading is withdrawn |
| Hold a lane's question (prose) | BL-841 (0.968.0) | `SKILL.md:505` | 0 of 25 asks named a held lane; lane-idle share 95.7% against 93.7% | no effect |
| Cross groups collapsed in stories elicitation | BL-811 | `steps/stories-test-strategy.md:591` | adversary plus remediator elicitation $6.1 per story against $6.0; step alone 0.93 h and $26.4 per story against 0.80 h and $26.9 | no effect |
| Snapshot writes through one program | BL-819 L3, BL-912 (0.1012.0) | `core/hooks/ai-dlc-snapshot-edit-deny.sh:67` | `snapshot-update.sh` 1,057 lead calls, 132 per story against 30; lead snapshot time 0.317 h per story against 0.257 h | worse |
| Repairs carry `siblings:` and a serial lane | BL-508, BL-716 lanes | `core/scripts/join-remediator-shards.sh:881`, `:2709` | solo remediator 9.2 h against 9.6 h; 7.36 h at width 1, of which 5.48 h in single-lane rounds | no effect |
| Convergence capped at pass 3 | BL-911 (0.1008.0) | `steps/_gate-procedures.md:855` | architecture, carry-over and stories stopped at pass 3 (s321 ran to 5 and 6); requirements ran pass 4. Width did not narrow: 10, 10, 10, 10 in requirements | depth worked; one step exceeded the cap |
| Carry-over cross groups collapsed | BL-810 | `steps/carry-over-evaluation.md:186` | first carry-over round since the fix: 19.5 h and $231 against 24.8 h and $191 in s320, on a step split that moved between extractor versions | no fall supported |
| Dev seat to sonnet | BL-838 (0.968.0) | `templates/settings.json.template:31` | gate-1 passes per story 2.38 (s322), 2.12 (s321) on sonnet; 1.77 (s320), 3.16 (s319) on haiku | no direction supported |
| Story evidence sections | BL-397 (0.674.0) | `core/scripts/validate-handoff-evidence.sh:2007` | implementation per story 2.01 h and $27.9, inside the pre-fix range | no effect |

### Reached graph during s322, too late to measure

| Fix | Entry | Reached graph | What s322 shows |
|---|---|---|---|
| Adversary seat back to opus/medium | BL-971 (0.1048.0) | after the last sonnet/high adversary spawn at 11-11T07:55Z | 1 opus/medium spawn of 125 (8.3 minutes, $2.84). The seat's s322 figures are the sonnet/high ones: median 11.7 minutes, p90 61.5, $2.89 a spawn, 19 spawns over 45 minutes |
| Join's format check run inside the agent | BL-974 (0.1057.0) | 11-11T22:16Z | 16 join-refusal resumes, 11.2 agent-hours idle, all before it arrived |
| An agent with an open request is reported | BL-975 (0.1056.0) | 11-11T19:45Z | 4 API-error resumes, 4.2 agent-hours idle, all before it arrived |
| Wrong shard directory denied at dispatch | BL-976 (0.1055.0) | 11-11T19:45Z | no such resume in s322 |
| Read-only adjudicators split from the writer | BL-716 (0.1058.0) | 11-11T22:16Z | no planning round ran after it |

### Landed, first run is s323

BL-911's document and subject narrowing (0.1096.0), the dispatch-then-ask rule (BL-972, 0.1092.0 and 0.1145.0),
the one-call snapshot rule (BL-912, 0.1163.0), BL-397's added arms (0.1134.0, 0.1136.0) and BL-1141. Each
entry already owns its outcome line.

### Not built

| Earlier row | State |
|---|---|
| 2. Operator questions: a mechanism | prose only (`SKILL.md:497`); no hook enforces it, and the prose form measured null twice |
| 8. First-pass gate-1 failures | no entry until this report |
| 9. `validate-mutation-red.sh` per-call cost | no entry; in s322 it is 6 s a call over 177 calls, down from 11 s over 1,010 |
| 10. `validate-spawn-ledger.sh` per-call cost | no entry until this report |
| 11. graph `git push` in the lead | no entry until this report |
| 12. deploy-validate, not decomposed | no entry; s322's ran 3.6 h and $27, so s321's 29.9 h did not recur |
| 13. Local-model lead compaction | no dedicated entry; measured under BL-819 |

### Records that disagree with the code

- **NOTE.** BL-695's `LANDED` line credits `scripts/audit-party-wave-barrier.sh`, which 0.1146.0 deleted.
- **NOTE.** The step-value decision for architecture round 2c was recorded as MERGE and shipped as a removal
  (0.805.0).

## Opportunities

Ordered by the wall clock a named fix can reach on s322 complete, with s321 beside it where the two differ. Hours are in-session wall
clock unless marked agent-hours. Dollar figures marked "est." rest on the stated assumption.

### DEFECT

| # | Opportunity | Hours per sprint | $ per sprint | Entry | Evidence |
|--:|---|---|---|---|---|
| 1 | **The lead's call volume rose.** 10,128 calls in 77.1 h against 8,005 in 120.5 h; 1,266 per story against 320 on 8 stories, so the per-story figures carry the sprint-size confound. The "other" class is 1.78 h per story against 0.40, merge 0.66 h against 0.34, snapshot 0.317 h against 0.257. | up to 14.1 h (the excess over s321's per-story rate in those three classes, at 8 stories) | up to $170 (the same classes' token-equivalent excess, FALLBACK-priced) | BL-819, BL-912 (owned; first reading of the one-call rule is s323) | `out/roll_classes.txt`, `out/lead_time.txt` |
| 2 | **Operator decisions are found mid-step and asked one at a time.** Declare each operator-owned decision as a checkpoint at planning and ask them as one batch at the step boundary while independent lanes run. The prose rule measured null in s321 and s322. | up to 10.3 h (s322), 24.9 h (s321) | $0 | BL-972 (line added) | 25 asks, 0 with a held lane, 95.7% of ask minutes with no lane active |
| 3 | **A serial adversary or remediator holds the round.** 20.7 solo hours. The adversary rebind is unread; the remediator's single-lane rounds are 5.48 h. | about 5 h expected from the rebind (11.5 h against the 6.5 h opus/medium level); up to 3.7 h from adjudicator splitting (BL-716's k=4 bound) | about $135 from the rebind (124 spawns × $1.09, which is $2.89 less the s319–s320 opus/medium $1.81) | BL-971, BL-716 (owned; first reading s323) | `out/poles_allroles.txt`, `out/serial_tail.txt`, `out/seats_adversary.txt` |
| 4 | **Six of eight stories failed gate 1 first time.** The dev's pre-submission step is a self-check list. Add one quick independent reviewer inside the dev seat before gate 1. | 3.4 agent-hours idle across 10 rework resumes (s322); 13.1 across 37 (s321) | $17 on passes 2–4 (s322); $80 on passes 2–7 (s321) | BL-1166 | `out/impl_passes.txt`, `out/resumes.txt`; `core/team-roles/dev.md:171` |
| 5 | **The stories cycle runs at full depth for every story.** Tier per-story party and elicitation by the routing tag the step already has. The survivors-by-tag classification is owed first, from the existing step-value record. | not measured; the rounds are parallel (25.4 minutes for 24 seats) | $134 est., if 40% of 25 stories are low-risk at $7.49 + $5.96 a story | BL-1171 | `step-value-stories-adversarial-s321.md`; `steps/stories-test-strategy.md:30` |
| 6 | **A small sprint pays the whole planning charge.** Planning was $890 and 44.0 h for 8 stories. Requirements ran four passes at width 10 and carry-over evaluation took 19.5 h. | an exposure, not a reachable saving: 5.5 h per story against 1.7 h, about 30 h at 8 stories | $111 per story against $52, about $470 at 8 stories | BL-1171 (same tiering question); BL-911 for width | per-step table above |
| 7 | **Readiness runs three times a sprint and one BMAD output has no reader.** The architecture-time call states that epics do not exist yet; the sprint-planning intent runs readiness again; its `sprint-status.yaml` is moved aside, and no program under `core/` uses the moved file's sprint data (`core/scripts/sprint-status.sh:589` compares its bytes only to decide the move). Whether anything consumes the intent's story selection is unread. | 0.3–0.7 h est., two calls dropped at 10–20 minutes each | $3 est., at the $1.50 spawn average | BL-1169 | `steps/architecture.md:262`, `steps/stories-test-strategy.md:18`, `:542`, `steps/route.md:587` |
| 8 | **The planning-time trace gate cannot fail.** The step's own text calls it disarmed by construction: no test exists and every criterion is planned. Move the trace to sprint review and keep a deterministic check that every criterion maps to a case. | not measured | not measured | BL-1170 | `steps/stories-test-strategy.md:697` |

### NOTE

| # | Opportunity | Hours per sprint | $ per sprint | Entry | Evidence |
|--:|---|---|---|---|---|
| 9 | graph's `git push` in the lead is the largest lead Bash family. The two readers disagree on s322: 44 calls at 62 s (`bash_by_sprint.py`) and 42 intervals at 36.7 s (`lead_time.py`). s321 was 39 calls at 37 s. | 0.43–0.76 h | $0 | BL-1167 | `out/bash_by_sprint_top80.txt`, `out/lead_time.txt` |
| 10 | Subagent `wait-for-deliverable.sh` went from 1 s to 7 s a call (502 calls). `validate-spawn-ledger.sh` is 35 s a call on a 9,582-row ledger that only grows. `test-pytest-admission.sh` is 26 s a call (53 calls). | 0.91 + 0.34 + 0.38 agent-hours | not measured | BL-1168 | same |
| 11 | The pipeline's stated reason for not looping `bmad-review` (it pads to ten findings) contradicts the current BMAD docs. The BMAD skills the pipeline invokes for readiness, sprint planning, epics and stories, and test architecture are absent from the current docs. Every invoked name is resolved at each planning gate (Check 32), but nothing runs that probe when BMAD is upgraded, so a dropped name fails mid-sprint. | 0 | 0 | BL-1173 | `steps/_gate-procedures.md:694`; `core/scripts/validate-bmad-invocations.sh:246` |
| 12 | The s323-close re-take: first reading for rows 1 and 3 and for every "first run is s323" fix. | 0 | 0 | BL-812 (line added) | "Reproduce" |

Rows 2 and 5 overlap with row 6: fewer and earlier decisions shorten planning. Rows 1 and 13 of the earlier
report overlap here as row 1: fewer lead calls means fewer compactions.

## BMAD: is the pipeline using the skills as intended

**What was read.** https://docs.bmad-method.org on 2026-11-18: the index and about 60 pages, the ones on how
BMAD works, building and reviewing a change, autonomous development loops, planning, existing codebases,
project context and multi-agent discussions in full. `llms.txt` returned 404. The pages carry no version.
Graph's installed BMAD at the last main commit before s322 is core and bmm 6.12.4 with tea 1.19.1.

**The docs describe a newer generation than the pipeline calls.** They centre on a product-owner agent, a
ticket tree, `bmad-build`, `bmad-build-auto` and `bmad-code-review`. They have no page for `bmad-spec`,
`bmad-sprint-planning`, `bmad-create-epics-and-stories` or the `bmad-testarch` workflows (keyword scan 0 hits
each; control `bmad-agent-po` hit). So the docs give no intent for readiness placement or sprint planning.

**Where the pipeline already matches the intent.**

- Small changes skip planning (`route.md:504` and `:507`, the `sprint-execute` and `bug` variants).
- Research, brainstorming and the product brief are conditional.
- The convergence bound at pass 3 matches the docs' line that findings on a third pass mean something is wrong
  upstream.
- The lead owns dispatch and never lets a worker pick its next unit, which is the `bmad-build-auto` contract.
- Party mode runs in its documented subagent, non-interactive form.

**Where the docs point at an opportunity.** These are opportunity rows 2, 4, 5, 6, 7, 8 and 11 above.

| Docs guidance | What the pipeline does | Row |
|---|---|--:|
| Human checkpoints are fields on each ticket, fixed at planning, so other tickets continue while a person decides | decisions surface mid-step, one ask at a time | 2 |
| The build runs one quick independent reviewer inside the dev run; thorough review is kept for the pull request | a self-check list, then gate 1 | 4 |
| For established code, too much planning costs documents nobody reads; stories are planned thin and acceptance detail is written when the build starts | every non-bug sprint re-authors brief, spec, PRD, architecture and full acceptance criteria for every story, each with party, elicitation and adversarial rounds | 5, 6 |
| A document is added only when it answers a question the work has | readiness three times; a sprint-planning file whose sprint data nothing uses | 7 |
| Test design and trace are not the default test-generation path; generation works from code that exists | trace runs at planning, where coverage is zero | 8 |
| `bmad-review` never pads; zero findings is a valid outcome | the pipeline's text says it must find ten issues | 11 |

**Catches at risk.** Every round named above has a KEEP or a named catch in the `step-value-*` files:
per-story party and elicitation hold the capital-path catches (39 unique survivors in s321, including its one
CRITICAL), and stories readiness has an s317 catch. None is proposed for removal outright; row 5 would drop per-story party and elicitation for untagged stories,
and is safe only if
survivors cluster in tagged stories, which is unmeasured; row 7 keeps the stories readiness call and drops the
two with no reading.

**Two NOTE-tier differences with no change proposed.** The docs say a fresh chat per workflow; the pipeline's
lead is one long session by design. The docs run the retrospective per epic; the pipeline runs it per sprint at
$18–51.

## What this changes in the earlier report

- Its s322 column was partial, and its carry-over and requirements cells split the same cost differently. Read this
  file's tables instead.
- BL-913 is "no effect", not "worked".
- Its opportunity 1 is built and unread; opportunities 5, 6 and 7 are built and unread or unexercised;
  opportunity 12 did not recur.

## Reproduce

```
OUT=<scratch dir>; export EXTRACT_WIN_END=2026-11-12T14:41:00Z
A=docs/analysis/pipeline-efficiency-s317-s318/scripts
B=docs/analysis/pipeline-efficiency-s317-s320/scripts
C=docs/analysis/pipeline-efficiency-s317-s322/scripts
D=docs/analysis/pipeline-efficiency-s317-s322-b259/scripts
python3 -I $B/extract.py $OUT && python3 -I $A/spawns.py $OUT && python3 -I $A/analyze.py $OUT
python3 -I $B/roll.py $OUT; python3 -I $B/roll.py $OUT --classes; python3 -I $B/decompose.py $OUT
python3 -I $D/tables_s322_complete.py $OUT    # per-step table with each gate folded in
python3 -I $B/impl_passes.py $OUT 317,318,319,320,321,322
python3 -I $D/poles_allroles.py $OUT; python3 -I $C/seats.py $OUT adversary
python3 -I $C/lead_time.py; python3 -I $C/bash_by_sprint.py 80; python3 -I $B/cap_rejections.py
python3 -I $C/resumes.py $OUT; python3 -I $C/ask_split.py $OUT; python3 -I $C/serial_tail.py $OUT
python3 -I $D/operator_asks_pinned.py; python3 -I $D/advisor_server_tool_use.py
python3 -I $C/outcome_row.py $OUT 322 321 319
```

For s323, once it has closed: add its edge to `EDGES` in `extract.py` and its story count to `STORIES` in
`roll.py`, move the pin past its last lead record, and run the block. `roll.py`, `decompose.py`, `seats.py` and
`impl_passes.py` read only `$OUT`; the scripts under `$D` and the listed `$C` readers drop records past the
pin themselves.
