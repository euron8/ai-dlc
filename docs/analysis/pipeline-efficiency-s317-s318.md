# Pipeline efficiency: ai-dlc core × graph sprints 317–318

Measured 2026-10-14 against the graph consumer's own Claude Code transcripts. Purpose: identify
where the AI/DLC pipeline spends wall clock and tokens, step by step, with each step's stated
reason for existing, so optimisation targets can be chosen from data.

Data and the scripts that produced every figure are in
[`pipeline-efficiency-s317-s318/`](pipeline-efficiency-s317-s318/). Every table below is
rendered by `scripts/render.py` from those CSVs. The one exception is the "Role efficacy" section,
whose figures come from four per-phase analyses. Their scripts and joined data are in
[`pipeline-efficiency-s317-s318/role-efficacy/`](pipeline-efficiency-s317-s318/role-efficacy/)
(`planning`, `stories`, `impl`, `lead`). They read from the session scratchpad paths written inside
them, so they are evidence of the derivation, not a re-runnable pipeline.

## Population and method

**Corpus.** `~/.claude/projects/-Users-n8-git-graph/` — the 65 lead-session transcripts and 1849
subagent transcripts with activity at or after 2026-10-05T14:00Z (the s316 close commit
`e2977c4f6`). Distribution source: `/Users/n8/git/ai-dlc` at `42e320f6`. Consumer: graph's main
checkout at `7a8c6c98a`, which runs ai-dlc 0.781.0. Nothing was written to graph.

**Sprint edges.** Sprint 317 runs from 10-05T14:00Z to 10-12T02:30Z, which is the end of its retro
segment. Sprint 318 runs from 10-12T02:30Z to 10-14T14:30Z and is **open**: sprint-review is at gate
pass 2, and deploy-validate and retro have not run.

**One segment relabel.** In session `f849d75f` the lead Read `retro.md` at 10-12T10:04Z while it was
mid-requirements. All 37 subagents spawned in the following 95 minutes are described as
"Elicitation part N" or "Elicitation repair N", which is the requirements validation cycle. That
segment is charged to `requirements` (`RELABEL` in `scripts/analyze.py`). No other segment was
relabelled.

**Tokens.** The source is `message.usage` on assistant lines, de-duplicated by `message.id`
keeping the **last** line, because one API message spans several transcript lines and only the last
carries the final `output_tokens`. Four classes are reported: fresh input, cache write (`cw`), cache
read (`cr`) and output. "API-equiv $" prices them at list rates from the `claude-api` skill
(cached 2026-10-06): Opus 5.5 $4/$20, Sonnet 5.5 $2/$10, Haiku 5.5 $0.10/$0.50, Fable 5.1
$10/$50 per M input/output. Cache reads are priced at $0.20 (Opus/Sonnet) and $0.25 (Fable).
**Two prices are assumptions, not quoted figures:** a 1-hour cache write at 2× input, and a Haiku
cache read at 0.1× input. Sprint 317's lead partly ran on a local `qwen38flash-mlx` model (3,546
API calls by unique `message.id`, of which 3,539 carry a `usage` block and enter the token tables).
It is priced at $0 and is excluded from the dollar figures, but not from token counts. The
dollar column is a relative weight for ranking, not an invoice.

**Step attribution.** A lead session is segmented at each `Read` of
`core/skills/ai-dlc/steps/<step>.md`, because Rule 21 makes that Read the step-entry act. A Read
of `gate-validation.md` opens a `gate-validation[<owning step>]` sub-segment. Reads of
`_gate-procedures.md` and `_dispatch-protocol.md` do not move the segment. A subagent is attributed
to the segment that contains its parent `Agent` tool call: the subagent's `meta.json` `toolUseId`
is joined to the lead's `tool_use.id`. This joined **1848 of 1849** subagents. "pre-step" is session
time before the first step Read, which is cold start and resume orientation.

**Wall clock, three columns.** *Elapsed* is first-to-last timestamp in the segment.
*Lead active* sums inter-line gaps of ≤5 min. *Waiting on agents* sums gaps over 5 min that are not
ended by a human prompt; most are `queue-operation` lines, where the lead is blocked on background
subagents. *Operator wait* sums gaps over 5 min that end in a human prompt. Time *between* sessions
(a handoff waiting for `/ai-dlc resume`) is out of scope by operator ruling. Handoff gaps are not
treated as an optimisation target and appear in no column or finding.

**Bucketing.** A lead session with at least one step Read is `pipeline`. One with none, whose
assistant lines are attributed to the `ai-dlc-update` skill, is `ai-dlc-update (reconcile)`.
Anything else is `operator ad-hoc`.

**Controls (all reproduced by `scripts/analyze.py`).**

| Control | Expected | Got |
|---|---|---|
| Sum of segment tokens = sum of per-transcript tokens | equal | 8,091,778,584 = 8,091,778,584 |
| Subagents joined to a parent step | all | 1848 / 1849 (1 `unjoined`) |
| One subagent re-derived with `jq` (`agent-a02f8cbd67a80796b`) | equal to `units.jsonl` | cr 1,832,885 / cw 434,783 / out 14,891 / in 854 / 26 calls — match |
| Every assistant line carries `usage` | 100% | 32/32 lead, 61/61 subagent sampled |
| A step known to have run (`gate-validation[implementation]`) has non-zero segments | >0 | 317: 16.3 h, 318: 5.2 h |
| Ledger cross-check (spawn-ledger rows vs transcripts) | same order | ledger 1018 (317) + 953 (318); transcripts 1849, which includes Explore and advisor spawns the ledger does not record |

**Population edges.** `find` returns 1852 subagent files with a modification time in the window.
Three of them have no line timestamped at or after 10-05T14:00Z, so `units` holds 1849. The
`mcp__advisor__consult` tool (100 calls) is billed server-side and is in **no** token or dollar
figure. Line-cited rationale is from ai-dlc `main` at `42e320f6`; across the window graph ran
0.779.0–0.781.0.

**Sub-steps are inferred, not timed.** Transcripts mark step entry (a step-file Read), not sub-step
entry. Sub-step cost is therefore shown two ways: the `gate-validation[…]` sub-segment, and the
role and description mix of the spawns inside each step (the step × role table). Neither is a
direct sub-step clock.

**Not measured.** Hook *latency* is reported from the transcript's `durationMs`, not timed
independently. Per-story hop attribution in the ledger is name-heuristic and is used only
qualitatively. Byte sizes of variable hook injections were not measured.

## Headline

- **8.09 B tokens across two sprints, 95% cache reads.** By API-equivalent dollars the split is
  even across three classes: cache write about 37%, cache read about 33%, output about 30%. Fresh
  input is under 1%. Cache writes rank first **only under the assumed 2× one-hour write price**; at
  1.25× they fall to 27% and rank last of the three (cache read 38%, output 34%). They scale with spawn count: a
  subagent's first call writes a **mean** of 34,475 tokens of fresh context (over 1849 first calls).
- **Subagents carry 59% (s317) and 69% (s318) of tokens** (2,767 M of 4,714 M; 2,323 M of 3,378 M).
- **API-equivalent spend: $2,314 for s317 and $1,713 for s318 to date.**
- **The lead is mostly waiting.** In pipeline sessions, the waiting-on-agents column is 46 h of s317's
  113 h elapsed and 36 h of s318's 65 h. Subagents themselves ran 72.1 h of `Bash`, 12.4 h of that
  in `sleep`.
- **Planning dominates; implementation and stories are the two largest single steps.** With each
  step's gate folded in, implementation is $659 (s317) and $422 (s318), and stories-test-strategy is
  $622 and $414. The two are within 6% and 2% of each other. The planning chain (carry-over-evaluation
  through stories-test-strategy, with gates) is 53% of s317 pipeline-bucket spend ($1,156 of $2,172)
  and 64% of s318 ($1,073 of $1,675). Implementation plus its gate is 30% and 25%.

## Per-step table

<!-- rendered by scripts/render.py, table 1 -->

| Sprint | Step | Elapsed h | Lead active h | Waiting on agents h | Operator wait h | Compactions | Lead tok M | Subagent tok M | cache-read % | Output M | API-equiv $ |
|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| 317 | pre-step | 2.5 | 0.4 | 1.3 | 0.7 | 1 | 6 | 0 | 73% | 0.0 | 8 |
| 317 | route | 0.3 | 0.3 | 0.0 | 0.0 | 0 | 7 | 0 | 85% | 0.1 | 4 |
| 317 | carry-over-evaluation | 5.8 | 1.7 | 3.9 | 0.1 | 1 | 73 | 113 | 94% | 4.1 | 114 |
| 317 | gate-validation[carry-over-evaluation] | 0.2 | 0.2 | 0.0 | 0.0 | 1 | 12 | 1 | 97% | 0.1 | 5 |
| 317 | requirements | 8.9 | 2.3 | 6.3 | 0.2 | 1 | 83 | 129 | 96% | 3.6 | 119 |
| 317 | gate-validation[requirements] | 0.2 | 0.2 | 0.0 | 0.0 | 1 | 8 | 3 | 95% | 0.1 | 5 |
| 317 | architecture | 10.9 | 5.3 | 5.2 | 0.4 | 3 | 154 | 306 | 95% | 9.5 | 286 |
| 317 | gate-validation[architecture] | 0.3 | 0.3 | 0.0 | 0.0 | 0 | 11 | 3 | 97% | 0.1 | 5 |
| 317 | stories-test-strategy | 14.6 | 7.3 | 6.4 | 0.9 | 4 | 236 | 658 | 94% | 17.1 | 617 |
| 317 | gate-validation[stories-test-strategy] | 0.3 | 0.3 | 0.0 | 0.0 | 0 | 10 | 2 | 97% | 0.1 | 5 |
| 317 | implementation | 26.0 | 18.7 | 7.1 | 0.1 | 8 | 340 | 639 | 94% | 10.5 | 446 |
| 317 | gate-validation[implementation] | 16.3 | 8.7 | 7.6 | 0.0 | 13 | 225 | 295 | 95% | 4.4 | 213 |
| 317 | sprint-review | 5.6 | 5.1 | 0.5 | 0.0 | 4 | 86 | 561 | 93% | 12.4 | 265 |
| 317 | gate-validation[sprint-review] | 1.5 | 0.9 | 0.6 | 0.0 | 1 | 25 | 12 | 95% | 0.3 | 6 |
| 317 | deploy-validate | 10.9 | 4.8 | 4.1 | 2.0 | 3 | 148 | 30 | 96% | 1.0 | 23 |
| 317 | retro | 0.9 | 0.7 | 0.3 | 0.0 | 1 | 27 | 14 | 96% | 0.3 | 17 |
| 317 | handoff | 7.8 | 4.4 | 2.9 | 0.5 | 2 | 136 | 0 | 98% | 0.5 | 33 |
| 317 | ai-dlc-update (reconcile) | 38.2 | 11.5 | 7.0 | 19.7 | 0 | 356 | 0 | 98% | 0.9 | 140 |
| 317 | operator ad-hoc | 0.8 | 0.2 | 0.0 | 0.7 | 0 | 4 | 0 | 97% | 0.0 | 2 |
| 318 | pre-step | 0.2 | 0.0 | 0.0 | 0.2 | 0 | 0 | 0 | 13% | 0.0 | 1 |
| 318 | route | 3.9 | 0.1 | 3.8 | 0.0 | 0 | 4 | 0 | 81% | 0.0 | 4 |
| 318 | artifact-consolidation | 1.0 | 0.8 | 0.2 | 0.0 | 0 | 16 | 13 | 95% | 0.3 | 16 |
| 318 | carry-over-evaluation | 2.9 | 2.0 | 0.9 | 0.0 | 1 | 83 | 115 | 95% | 2.0 | 132 |
| 318 | gate-validation[carry-over-evaluation] | 0.0 | 0.0 | 0.0 | 0.0 | 1 | 0 | 0 | 99% | 0.0 | 0 |
| 318 | requirements | 6.1 | 4.3 | 1.8 | 0.0 | 2 | 146 | 426 | 95% | 7.5 | 330 |
| 318 | gate-validation[requirements] | 0.2 | 0.2 | 0.0 | 0.0 | 0 | 11 | 4 | 97% | 0.1 | 5 |
| 318 | architecture | 4.5 | 2.4 | 2.2 | 0.0 | 2 | 88 | 277 | 95% | 5.6 | 174 |
| 318 | gate-validation[architecture] | 0.3 | 0.3 | 0.0 | 0.0 | 1 | 16 | 14 | 95% | 0.2 | 17 |
| 318 | stories-test-strategy | 24.9 | 6.4 | 18.3 | 0.1 | 3 | 186 | 570 | 94% | 15.9 | 404 |
| 318 | gate-validation[stories-test-strategy] | 0.7 | 0.5 | 0.3 | 0.0 | 1 | 24 | 7 | 97% | 0.1 | 10 |
| 318 | ui-direction | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 1 | 1 | 94% | 0.0 | 1 |
| 318 | implementation | 6.6 | 5.7 | 0.9 | 0.0 | 4 | 163 | 548 | 94% | 6.6 | 336 |
| 318 | gate-validation[implementation] | 5.2 | 3.9 | 1.3 | 0.0 | 4 | 136 | 85 | 96% | 1.1 | 86 |
| 318 | sprint-review | 1.4 | 1.2 | 0.2 | 0.0 | 1 | 35 | 250 | 95% | 3.2 | 130 |
| 318 | gate-validation[sprint-review] | 4.0 | 0.6 | 3.4 | 0.0 | 0 | 13 | 13 | 94% | 0.2 | 12 |
| 318 | handoff | 3.3 | 1.0 | 2.3 | 0.0 | 1 | 47 | 0 | 96% | 0.1 | 16 |
| 318 | ai-dlc-update (reconcile) | 5.0 | 2.8 | 1.0 | 1.2 | 0 | 84 | 0 | 97% | 0.2 | 38 |
| **317** | **total** | 151.8 | 73.1 | 53.2 | 25.4 | 44 | 1947 | 2767 | 95% | 64.9 | **2314** |
| **318** | **total** | 70.3 | 32.3 | 36.6 | 1.4 | 21 | 1055 | 2323 | 95% | 43.1 | **1713** |

Notes on reading it:

- **Implementation is under-attributed.** In both sprints it overlaps its own gate segment, because
  the lead re-reads `gate-validation.md` per story during implementation. Read
  `implementation` and `gate-validation[implementation]` together: s317 42.3 h and $659, s318 11.8 h
  and $422 so far.
- **Steps that did not run, by variant.** discovery, research-requirements, codebase-inventory,
  deep-codebase-analysis, doc-reconciliation, doc-repair-backfill, bug-investigation and
  sprint-review-next are not reached by graph's `carry-over` variant (route.md:481-497).
  ui-direction did not run in s317 and took 6 minutes in s318.
- **Not yet reached in s318:** deploy-validate and the s318 retro.

## Per-role table

<!-- rendered by scripts/render.py, table 2. Bindings: graph .claude/settings.json aiDlcRoles, identical to templates/settings.json.template. -->

| Sprint | Role | Spawns | Summed agent h | Tok M | Output M | API-equiv $ | $/spawn | Models observed |
|---|---|--:|--:|--:|--:|--:|--:|---|
| 317 | adversary | 143 | 34.5 | 356 | 6.8 | 347 | 2.43 | opus |
| 317 | code-reviewer-escalated | 91 | 23.7 | 415 | 4.5 | 320 | 3.52 | opus |
| 317 | architect | 66 | 22.7 | 306 | 5.8 | 290 | 4.39 | fable,opus |
| 317 | tea | 88 | 37.9 | 356 | 12.7 | 250 | 2.85 | sonnet |
| 317 | remediator | 118 | 25.4 | 332 | 8.0 | 207 | 1.75 | sonnet |
| 317 | dev | 113 | 39.5 | 437 | 10.9 | 112 | 1.00 | haiku,sonnet |
| 317 | code-reviewer | 59 | 8.8 | 150 | 1.5 | 91 | 1.55 | opus,sonnet |
| 317 | qa | 93 | 10.3 | 163 | 1.3 | 91 | 0.98 | sonnet |
| 317 | gate-adjudicator | 78 | 4.4 | 72 | 0.8 | 43 | 0.55 | sonnet |
| 317 | pm | 43 | 3.6 | 45 | 0.7 | 30 | 0.69 | sonnet |
| 317 | sm | 27 | 2.7 | 42 | 0.6 | 23 | 0.86 | sonnet |
| 317 | dev-escalated | 2 | 3.0 | 50 | 0.4 | 22 | 11.18 | sonnet |
| 317 | analyst | 10 | 1.2 | 21 | 0.4 | 14 | 1.41 | sonnet |
| 317 | pm-escalated | 1 | 0.8 | 18 | 0.3 | 8 | 8.07 | sonnet |
| 317 | protected-path-editor | 3 | 0.5 | 5 | 0.0 | 3 | 1.06 | sonnet |
| 318 | adversary | 194 | 32.1 | 492 | 7.7 | 423 | 2.18 | opus |
| 318 | architect | 79 | 15.9 | 295 | 3.9 | 242 | 3.06 | fable,opus |
| 318 | code-reviewer-escalated | 67 | 13.4 | 253 | 3.0 | 188 | 2.81 | opus |
| 318 | remediator | 149 | 13.2 | 236 | 2.8 | 130 | 0.87 | sonnet |
| 318 | tea | 62 | 14.2 | 190 | 5.1 | 114 | 1.83 | sonnet |
| 318 | qa | 83 | 7.9 | 131 | 1.0 | 69 | 0.83 | sonnet |
| 318 | code-reviewer | 44 | 4.5 | 74 | 0.7 | 65 | 1.49 | opus |
| 318 | pm | 44 | 4.4 | 100 | 1.7 | 53 | 1.19 | sonnet |
| 318 | sm | 19 | 5.1 | 67 | 2.0 | 41 | 2.17 | sonnet |
| 318 | gate-adjudicator | 59 | 3.4 | 50 | 0.5 | 27 | 0.46 | sonnet |
| 318 | dev-escalated | 5 | 4.8 | 37 | 0.2 | 20 | 4.06 | sonnet |
| 318 | dev | 91 | 30.0 | 381 | 10.9 | 13 | 0.14 | haiku |
| 318 | analyst | 15 | 0.8 | 13 | 0.3 | 9 | 0.62 | sonnet |
| 318 | pm-escalated | 1 | 0.1 | 1 | 0.0 | 1 | 1.38 | opus |
| 318 | general-purpose | 1 | 0.1 | 2 | 0.0 | 1 | 1.34 | sonnet |
| 318 | ux | 1 | 0.0 | 1 | 0.0 | 1 | 0.57 | sonnet |

**The review side costs far more than the build side.** In s318, adversary, architect,
code-reviewer-escalated, remediator, tea, qa, code-reviewer and gate-adjudicator together cost
$1,258. dev and dev-escalated cost $33. Haiku dev runs 91 spawns and 381 M tokens for $13, while the
Opus reviewers of that work cost about 30× more.

**Per-spawn subagent shape** (median over the window): adversary 6.6 min and 1.76 M tok; tea 13.1
min (p90 60.8) and 2.56 M; code-reviewer-escalated 11.4 min and 3.67 M; architect 12.8 min and
3.41 M; dev 12.1 min and 2.7 M; gate-adjudicator 3.1 min and 0.8 M. dev-escalated had a median of
54.5 min across 7 spawns.

## Where the money goes inside each step (top 25 step × role cells)

<!-- rendered by scripts/render.py, table 3 -->

| Sprint | Step (spawning segment) | Role | Spawns | API-equiv $ |
|---|---|---|--:|--:|
| 317 | implementation | code-reviewer-escalated | 73 | 259 |
| 317 | stories-test-strategy | adversary | 99 | 216 |
| 318 | requirements | adversary | 76 | 188 |
| 318 | implementation | code-reviewer-escalated | 64 | 178 |
| 318 | stories-test-strategy | adversary | 59 | 129 |
| 317 | sprint-review | architect | 27 | 124 |
| 317 | stories-test-strategy | tea | 44 | 120 |
| 317 | stories-test-strategy | architect | 23 | 89 |
| 317 | stories-test-strategy | remediator | 73 | 82 |
| 317 | sprint-review | tea | 27 | 74 |
| 318 | stories-test-strategy | tea | 21 | 72 |
| 317 | implementation | qa | 62 | 62 |
| 317 | gate-validation[implementation] | code-reviewer-escalated | 18 | 61 |
| 317 | architecture | adversary | 19 | 60 |
| 318 | requirements | architect | 18 | 56 |
| 318 | architecture | adversary | 22 | 52 |
| 318 | sprint-review | architect | 19 | 51 |
| 318 | implementation | code-reviewer | 30 | 51 |
| 317 | architecture | architect | 9 | 50 |
| 318 | stories-test-strategy | architect | 19 | 49 |
| 318 | stories-test-strategy | remediator | 54 | 47 |
| 318 | carry-over-evaluation | architect | 10 | 47 |
| 317 | implementation | code-reviewer | 30 | 47 |
| 317 | carry-over-evaluation | remediator | 14 | 46 |
| 317 | architecture | tea | 10 | 45 |

## Step-by-step: what it does, why it exists, what it cost

Rationale is cited to the distribution source. "FC" is a step file's `Failure caught:` contract
(Rule 26(c)). Where no source states a reason, the entry says so.

### route (s317 $4 / 0.3 h; s318 $4 / 3.9 h elapsed, 0.1 h active)
- **Sub-steps:** 0 entry token and resume check; 0a snapshot integrity; 1 read state;
  **1a artifact-size budget HARD_BLOCK**; 2–3 pick the variant; 4 ambiguity check; 5 branch strategy;
  6 compose the pipeline and declare `validation_intensity`.
- **Why:** 0a is CHN R7 (snapshot integrity on resume); 1a is Rule 25 (unbounded artifacts are
  "the single largest read cost … forces compaction"); 4 is Rule 11; 6 is Rule 8.
- **Measured:** cheap. The s318 3.8 h agent-wait is the 1a HARD_BLOCK firing on the whole-read pool:
  the lead dispatched `artifact-consolidation` and waited. The same pool is already re-breached
  (`CO-S318-WHOLE-READ-POOL-REBREACHED-BY-S318-AUTHORING`, 77,078 tok against a 66,000 budget), so
  s319 will hit it again.

### artifact-consolidation (s318 $16 / 1.0 h)
- **Sub-steps:** baseline manifest; analyst drafts the split; no-loss and Rule 20 verification inline;
  swap; retire.
- **Why:** an artifact past its Rule 25(d) threshold; CHANGELOG [0.9.0]; artifact-consolidation.md:145.
- **Measured:** cheap per run. The cost is that it is **reactive**: it runs after the budget gate blocks
  a sprint, and the sprint's own authoring then re-breaches the budget.

### carry-over-evaluation (s317 $119 incl. gate / 6.0 h; s318 $132 / 2.9 h)
- **Sub-steps:** analyst exploration; audit-anchor and post-merge trunk audit; evaluate items;
  **party mode** (PM, Architect, Dev, TEA × sections); validation cycle; deferral handling;
  recurrence promotes priority; close invalid items; update the backlog.
- **Why:** carry-over-evaluation.md:12-13, "Carry-over items get the same planning rigor as new
  features". 4a's FC is items "carried indefinitely because each sprint judged it in isolation".
- **Measured:** s318 cost about the same as s317 in half the elapsed time. The architect (Opus) is
  the largest cell, at $47 for 10 spawns.

### requirements (s317 $124 / 9.1 h; s318 $335 / 6.3 h)
- **Sub-steps:** analyst exploration; prior-decision search; option check; locked requirements, written
  inline; **one serial `pm-escalated` chain** (brief, then `bmad-spec`, then PRD); validation cycle
  (party seats Architect and Dev × parts, then adversary and remediator); gate.
- **Why:** requirements.md:10-18. It replaces discovery and research-requirements for feature and
  carry-over because the two-step form was "three passes over one decision". CHANGELOG [0.531.0]
  measured 10.5 h to reach architecture, with about half the findings being restatement errors.
- **Measured:** s318 cost 2.7× s317. **The adversary series is most of the difference:** 76
  adversary spawns at $188 against 12 in s317. In session `f849d75f`, 37 of those spawns were the
  requirements **elicitation** pass ("Elicitation part N" / "Elicitation repair N"). That stage of
  the validation cycle runs only at `full` intensity (Rule 8). The s318 snapshot records a 3-pass stories series and
  a 3-pass architecture series. This step's own series is in `roles.csv`.

### architecture (s317 $291 / 11.2 h; s318 $191 / 4.8 h)
- **Sub-steps:** analyst exploration; create or update; 2a–2e (variant-lock evidence, framework-default
  audit, mitigation proportionality, executable invariant guard, named-field divergence gate);
  solutioning gate; validation cycle (Architect, Dev, TEA, PM party); regenerate the architecture index;
  gate.
- **Why:** 2e has FC :252 ("a named field whose name over-claims"). 4a has :325 ("re-incur the
  whole-read cost this index exists to avoid"). The rule against per-sprint addenda comes from
  CHN:1213-1216 (an architecture.md "past 500K tokens"). **2a–2d: no stated rationale found.**
- **Measured:** the second most expensive planning step in s317. Its convergence is recorded as
  14, then 4, then 0 majors over three adversary passes (graph pipeline-snapshot-history:130).

### stories-test-strategy (s317 $622 / 14.9 h; s318 $414 / 25.6 h). **The largest planning step in both sprints.**
- **Sub-steps:** 1 implementation readiness, with its reference subsections (routing tags,
  discriminating-AC standard, layered AC accounting, pre-flight, out-of-scope, smoke AC precision);
  2 epics and stories; 2a/2b propagate locked requirements and `architecture_refs`; 3 sprint
  planning; 3a defect fold; **4 story validation cycle** (SM, Dev, Architect, TEA party,
  **sharded per story ordinal plus one cross-story agent per cross group**, stories-test-strategy.md:536,
  then adversary and remediator); 5 test strategy; 6 commit; 7 UI routing.
- **Why:** 2b comes from CHN:1207-1212 (`architecture_refs` are the slice dev and qa read instead of
  the whole document). 2a is Rule 13. 4 is Rule 8. **The file carries no FC lines, and the other
  sub-steps have no stated rationale.**
- **Measured:**
  - s317: 99 adversary spawns ($216), 44 tea ($120), 23 architect ($89) and 73 remediator ($82).
    One segment is relabelled to implementation (`RELABEL` in `scripts/analyze.py`). In session
    `1feefd46` the lead re-read `stories-test-strategy.md` mid-implementation, 10-10T08:53–10:53Z, and
    all 11 spawns in that window are "gate-N cross-N" reviews of story 2.5 (code-reviewer-escalated,
    $72).
  - s318: an 18.3 h agent-wait. The longest single wait is **4.1 h** (10-13T06:42Z, session
    `ed2d9d82`), which matches the flow log's 251-min idle gap and a 3-pass adversarial series
    (p1 29 majors, then NOT_MET, then MET at p3; graph HIST:110).
  - Cost scales as **seats × stories × adversary passes**.

### ui-direction (s318 $1 / 6 min)
- **Sub-steps:** ux dispatch; mockups; a11y; present (non-blocking); document; proceed.
- **Why:** ui-direction.md:10-11. It is non-blocking per Rule 10.
- **Measured:** negligible. Did not run in s317.

### implementation + gate-validation[implementation] (s317 $659 / 42.3 h; s318 $422 / 11.8 h to date)
- **Sub-steps:**
  - 1 context.
  - 2 agent team (Rule 19 bindings, `_dispatch-protocol`).
  - 3 task list, per story: dev, then **gate 1 code review sharded by changed-file group plus cross
    reviewers** (implementation.md:309-330), then **gate 2 QA in waves**, then gate 3 story
    validation, then the closing writer (code-reviewer, 1/1).
  - 4–5 self-validate and begin.
  - 6 orchestrate.
  - 7 all gates passed.
- **Why:** FCs at :372 (QA against a stale worktree false-FAILs), :463 (a SHA-labelled verdict
  desyncs) and :492 (an unaddressable teammate is read as dead). Delegation is Rules 19 and 28. The
  dispatch protocol's wave-DAG has an FC at `_dispatch-protocol.md:167` ("silent over-serialization …
  wasting wall-clock").
- **Measured:**
  - **code-reviewer-escalated (Opus, effort high) is the largest cell in both sprints:** $259 for 73
    spawns in s317 and $178 for 64 in s318. That is more than all dev work combined.
  - **Review loops:** stories with more than one code-review pass were 8 of 21 (s317) and 8 of 13
    (s318). Extra review passes totalled 19 and 21 (`docs/reviews/s31{7,8}/` `-pN` suffixes).
  - **Gate-3 re-passes:** s317 had 3 entries needing a second nonce (15, 23 and 35 min). s318 entry 1
    needed three nonces (30 min).
  - **13 compactions** in s317's implementation-gate segment alone.

### sprint-review + gate (s317 $271 / 7.1 h; s318 $142 / 5.4 h, pass 2 pending)
- **Sub-steps:** pre-stage the PR; 0 local-tree freshness; 1 one-shot sprint adversarial; **2 sprint
  party mode, one agent per (seat, story) plus one per (seat, cross group)** (sprint-review.md:101-105);
  3 fix and re-validate; 4 gate (Checks 18, 20, 21 plus universal).
- **Why:** 0 has FC :47 ("stale-tree drift-clobber"). The lightweight skip is Rule 8. Fixes go to dev
  per Rule 28. **There is no stated reason for the party fan-out shape.**
- **Measured:**
  - s317: 135 seat files (5 seats × 27 groups), with architect $124 and tea $74.
  - s318: 95 seats, **40 rejected at the harness's concurrent-subagent cap** and re-dispatched in 4
    waves. The cap is `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`; ai-dlc hard-codes none (RB/rule-28.md:155-165).
  - s318 produced **230 findings in 95 seats** (sprint-review-party-digest.md:3).
  - **Gate pass 1 FAILed in both sprints:**
    - s317 on Checks 1, 2 and 21 (60 min to PASS).
    - s318 on Checks 21 and 915. Pass 2 ran in the next session.

### deploy-validate (s317 $23 / 10.9 h)
- **Sub-steps:** pre-deploy; deploy; 2a destructive-op gate; 2b deploy-freshness; 3 smoke (hard);
  3b function verification; 4 visual; 4b deferred-AC discharge; 5 Production Validation Checkpoint;
  6 human wait; 7 route. It runs no gate-validation gate.
- **Why:** FCs at :103, :147, :222, :269, :396, :481 and :529. The checkpoint is Rule 10, the only
  human pause.
- **Measured:** **cheap in tokens and expensive in wall clock.** The 10.9 h includes three
  fix-forwards (ff1–ff3), whose full-suite runs alone took 558 s, **2296 s** and 990 s. It also
  includes 2.0 h of operator wait at the checkpoint. These are consumer test and deploy costs, not
  pipeline overhead.

### retro (s317 $17 / 0.9 h; s318 not reached)
- **Sub-steps:** context; **party retro (6 seats)**; write the retro; 4 apply process improvements;
  4a close-out sweep and machine audits; 4b steerability audit and flow-log rotation; ship
  verification; human commentary; anchor SHA; pre-commit gate; commit and PR; merge and next-sprint
  prompt. It is the largest step file at 80,495 B, after gate-validation and _gate-procedures.
- **Why:** FCs at :612, :634 and :1097. Step 7 is authored in-step so retro findings "are still in the
  lead's working context" (:1239-1242).
- **Measured:** 8 persona spawns, $17. It is cheap for the largest-but-two step file, because the
  lead reads it in slices: 4 Reads at 46.5 KB each.

### handoff (s317 $33 / 7.8 h; s318 $16 / 3.3 h)
- **Sub-steps:** stop teammates; commit; finalise the snapshot and push; emit `/ai-dlc resume`; set
  the pause flag.
- **Why:** Rule 2 path (a); CHN R20 (auto-handoff at safe seams).
- **Measured:** each handoff costs a commit and push. A push runs graph's pre-push gate, which is
  expensive: `git push` averaged 37 s per call over 132 lead calls, and the 10-14 handoff push was
  blocked by pre-push.

## Resident core-file cost (what the pipeline makes agents read)

Bytes returned by `Read` calls on ai-dlc core files: step files, SKILL.md, rule bodies and role
files. Measured by `scripts/resident.py` over the same corpus. These are bytes *delivered into
context*. Each one is then re-billed as cache read on every later turn of that agent.

| Sprint | Lead MB | Subagent MB |
|---|--:|--:|
| 317 | 7.4 | 23.5 |
| 318 | 3.5 | 24.8 |

Largest single sources:

| Sprint | Reader | File | Reads | KB/read | KB total |
|---|---|---|--:|--:|--:|
| 318 | subagent | team-roles/adversary.md | 192 | 37.1 | 7,122 |
| 317 | subagent | team-roles/code-reviewer.md | 149 | 41.0 | 6,106 |
| 317 | subagent | team-roles/adversary.md | 143 | 35.6 | 5,087 |
| 318 | subagent | team-roles/code-reviewer.md | 103 | 42.2 | 4,350 |
| 317 | subagent | team-roles/qa.md | 93 | 32.3 | 3,005 |
| 317 | lead | steps/gate-validation.md (sliced) | 166 | 15.7 | 2,604 |
| 317 | lead | steps/route.md | 23 | 46.6 | 1,071 |
| 317 | lead | steps/implementation.md | 34 | 28.3 | 964 |

- **The role files are the largest resident line item, and every spawn pays for its own.**
  adversary.md is 35,989 B and code-reviewer.md is 40,801 B (inventory). Read once per spawn, they
  then ride in cache for that agent's 15–30 calls. The figure includes the role file returned in
  pieces; KB/read is what the harness actually returned.
- **gate-validation.md is sliced** (`gate-slice.sh`, 199 KB whole file, 14–16 KB per Read), so the
  lead's gate cost is read volume, not file size: 166 Reads in s317 against 85 in s318.
- **SKILL.md and the rule channel** (59,182 B + 6,166 B) are re-injected on each compaction:
  44 compactions in s317 and 21 in s318.

## Cross-cutting overheads

| Overhead | Measured | Source |
|---|---|---|
| **Subagent cold start** | median first-call cache write about 34K tok × 1849 spawns ≈ 64 M tok of cache writes before any work | `scripts/bash_cost.py` (first-call cw mean 34,475) |
| **Sleep-polling in subagents** | 228 Bash calls whose first matched token is `sleep`, **12.4 h**, about 196 s each (`bash_cost.py`). Narrower count, commands that *begin* with `sleep`/`until`/`while`: 125 calls, 5.4 h; by role qa 2.8 h, code-reviewer 1.2 h, dev-escalated 0.8 h, dev 0.4 h. The two populations differ; 5.4 h is the floor. | `bash_cost.py`; ad-hoc role split (not shipped) |
| **Sleep-polling in the lead** | 330 calls, 1.4 h | `bash_cost.py` |
| **Validator runs inside agents** | `validate-mutation-red.sh` 1177 calls / 1.9 h; `validate-artifact-derivations.sh` 1930 sub + 258 lead calls / 1.5 h; `validate-spawn-ledger.sh` 120 calls / 0.8 h | `bash_cost.py` |
| **Compactions** | s317 44 lead compactions (45 in compaction-log), s318 21 (24 in log) | units.jsonl; graph compaction logs |
| **ai-dlc-update reconcile sessions** | s317 20 sessions, 38.2 h, $140 (19.7 h operator wait); s318 6 sessions, 5.0 h, $38 | table above |
| **Hook injections** | 17,523 hook firings, 4.2 MB injected context. `PreToolUse:Read` additionalContext 4,507 firings / 1.86 MB (the context-mode guidance tip); SessionStart 135 / 1.42 MB. Hook process time 1157 s total. | `hooks.csv` |
| **Flow-log noise** | PAUSE_SKIPPED 2065 (s317) + 1531 (s318); ALLOWED_BY_LIVE_BEAT 1040 + 919 | graph pipeline-continuation logs |
| **Undelivered escalations** | 11 `ESCALATION_UNDELIVERED`; 9 of them "No agent named 'lead'" | same |

Two of these are not ai-dlc's. The `PreToolUse:Read` 1.86 MB and part of SessionStart are the
operator's context-mode and caveman plugins (`pretooluse.mjs`, `caveman-smart.js`). ai-dlc's own
fixed injections are the recover heredoc (about 8.3 KB per compact resume), pause/continue/answer-capture,
and the rules floor.

## Ranked defects

The DEFECT list below is grouped by severity, not ranked. This table ranks it. Every cost is
API-list-equivalent over s317 and s318, in-session only, and **counts only what fixing that defect
would remove**. Where two findings share cost, it is counted once, under the higher rank. Each row
is filed as a `docs/backlog.md` entry that cites this rank as `[efficiency rank N]`, so the drain
plan's whole-backlog adjudication carries the order. Rows exposed under the local qwen lead are
pipeline fixes toward the operator's local-lead goal and are ranked on the same basis as the rest.

| Rank | Defect | Cost removed | Confidence | Entry | Derivation |
|---|---|---|---|---|---|
| 1 | Full sharded re-review after rework, where a delta review served | **$282**, 1,258 agent-min | MEDIUM | BL-507 | the 11 full-fan-out re-review passes, less the median delta pass ($1.70), from `role-efficacy/impl/rework-labels.tsv` |
| 2 | Repairs write the defects the next adversary pass finds (subsumes DEFECTs 3 and 9) | **≈$105** | LOW–MEDIUM | BL-508 | planning third passes run only because every pass-2 MAJOR was repair-made: $39 (s318) + $2 (s317), from `role-efficacy/planning/`; plus stories repair-introduced share of p2+p3 adversary and remediator spend: 4/13 × $97 ≈ $30 (s317) + 9/21 × $80 ≈ $34 (s318), from `role-efficacy/stories/` |
| 3 | Elicitation sharded per part where one voice was measured cheaper | **≈$60** per run | LOW | BL-509 | s317 stories, 22 seats $69.53 against s318's single voice $9.37; equal finding yield not measured |
| 4 | Implementation rework from evidence and bookkeeping, after rank 1's overlap (DEFECT 8) | **$34**, 131 agent-min | MEDIUM | BL-510 | the 22 E/B verdicts in `rework-labels.tsv`, each full pass capped at the median delta pass; understated where the dev was kept alive |
| 5 | Step 1a budget blocks a sprint after the fact, and the sprint re-breaches it (DEFECT 6) | **$16 + 3.8 h** lead wait per occurrence | MEDIUM | BL-511 | the s318 route and artifact-consolidation segments |
| 6 | Gate passes discarded for lead paperwork, mostly Check 22 (DEFECTs 7 and 10) | **$16**, 132 adjudicator-min | HIGH | BL-512 | `role-efficacy/lead/`: 7 lead-caused discards $13.18 + 2 inferred $2.89 |
| 7 | Check 21 fails on dev-filled Strategy Test ID cells nothing re-checks after a rename | **≈$7** | HIGH | BL-513 | two sprint-review nonces and their repairs |
| 8 | Subagents poll with bare `sleep`, and no guard sees it (DEFECT 5) | ≈$0; 5.4–12.4 h subagent wall clock | MEDIUM | BL-514 | `scripts/bash_cost.py`; the probe denies a lead call and allows a subagent's |
| 9 | The lead re-sends cap-rejected spawns (DEFECT 4) | ≈$0; wall clock not measured | HIGH | BL-515 | 90 of 179 rejected calls re-sent, `role-efficacy/lead/` |
| 10 | Mechanism gaps the local lead exposed: product-code edit, future snapshot stamps, malformed nonce | ≈$0 measured; the code edit is high-consequence | HIGH | BL-516, BL-517, BL-518 | `probes/bl-516-*.sh`, `probes/bl-518-*.sh`; snapshot history lines |
| 11 | The remediator sets aside a party MAJOR as "outside this shard" | not measured; one reached sprint-review | MEDIUM | BL-519 | `role-efficacy/stories/` escape table |
| 12 | Teammates told to message "lead", which no agent is named | not measured | HIGH | BL-520 | 11 `ESCALATION_UNDELIVERED` events |

Old DEFECT 11 (no capital-path routing criterion for dev escalation) is not ranked: it shipped as
BL-504 in v0.781.0, which graph has pulled. Ranks 4 and 7 recur after BL-397 and BL-398 closed the
same classes at v0.674.0. Their entries say so, so a batch does not re-ship the earlier fix.

The table ranks only the DEFECT list's rows. The rationale gaps in the findings summary (the
"Rationale gaps" bullet under "Efficient vs inefficient — findings") carry no cost figure and are
not rows. They are carried by BL-568 and BL-569.

**Measuring a fix.** A receipt closes an entry on the tree. Whether the fix moved anything is
measured on consumer transcripts after it lands, by re-running this directory's scripts over the
sprints since. graph is the reference consumer, not the only one: `magic-bonus-calc-engine` also
runs ai-dlc (0.780.0) and has its own transcripts. Measure on every consumer that ran the fixed
release, and name the population beside each figure.

## Efficient vs inefficient — findings

Tiered on consequence. Each item names its measurement and the core file it would change.
**These are findings only; nothing has been built.**

### BLOCKER

None. No measured cost blocks the pipeline from completing.

### DEFECT

1. **The review side outspends the build side by 30–40×, and full fan-out re-review is the driver.**
   In s318, review roles cost $1,258 against dev $33. code-reviewer-escalated (Opus/high, never
   rebound) cost $433 across 146 implementation-window spawns. Its catches were real: s318 1.1's
   address-validation bypass, 1.2's untested transfer amount, and s317 2.6's dead code. The cost came
   from **process, not model**. In s317 every re-review was a full fan-out at $20–40 a pass (2.6: five
   passes, about $149; 1.2: four, about $115). In s318, passes from the third onward were delta
   reviews at $1–3. That switch saved more than any binding change measured (see "Role efficacy").
   → `core/skills/ai-dlc/steps/implementation.md:309-330` (gate-1 sharding).
2. **stories-test-strategy's validation cycle is the most expensive sub-step in the pipeline, and it
   carries no stated rationale for its fan-out shape.** Seats × story ordinals × adversary passes:
   s317 99 adversary, 44 tea and 73 remediator spawns; s318 an 18.3 h agent-wait including a 4.1 h
   single block. The file has no FC lines (the inventory found none).
   → `core/skills/ai-dlc/steps/stories-test-strategy.md` step 4 and `_gate-procedures.md:227`
   (validation cycle).
3. **Adversary series length is the main driver of planning-step variance.** requirements doubled
   2.7× from s317 to s318 ($124 → $335), driven by 12 → 76 adversary spawns, 37 of them a
   full-intensity elicitation pass. Rule 8 says
   "divergence is a HARD_BLOCK, not a reason for another pass", yet three-pass series appear in
   requirements, architecture and stories.
   → `_gate-procedures.md:475-753` (adversarial dispatch and repair).
4. **Sprint-review party fan-out exceeds the harness concurrency cap.** In s318, 95 seats were
   attempted and 40 were rejected at the 42-agent cap, then re-dispatched in 4 waves.
   `_gate-procedures.md:330-337` bounds a round at seats × (PART_CAP + 6) = seats × 14, which at 5
   seats is 70, above the cap. The waves rule exists (RB/rule-28.md:155) but is applied after the
   rejection rather than planned up front.
   → `_gate-procedures.md:330-374`.
5. **Sleep-polling inside subagents: 5.4–12.4 h** (narrow and broad command populations). QA and
   code-reviewer agents `sleep` while waiting (about 196 s per call). Check 25 (bounded-join
   conduct, FC gate-validation.md:2228) does exist, but its validator `validate-steering-budget.sh`
   drops `isSidechain` records before collecting tool calls (its header, lines 73-74 and 259-260),
   so it **cannot see a subagent's waits**. Rule 29 and the bounded-join beat govern the lead. No measured mechanism
   governs subagent waits, and `foreground-budget` only refuses over-budget timeouts.
   → `core/team-roles/qa.md`, `code-reviewer.md`; `core/hooks/ai-dlc-foreground-budget.sh`.
6. **The whole-read-pool budget gate is reactive.** route 1a HARD_BLOCKs a sprint, consolidation runs,
   and the same sprint re-breaches the pool (77,078 against 66,000 tok), so the next sprint blocks
   again.
   → `route.md` step 1a, `artifact-consolidation.md`, Rule 25.
7. **First-pass gate FAILs recur on bookkeeping checks.** These include Check 22 (waiver without
   `tool_use_id`, twice in s317), Check 21 (Strategy Test ID cells, sprint-review in both sprints),
   Check 5 (derived-story drift) and Check 6 (stale story copies). Each costs a fresh nonce and
   15–60 min. These are checks an author-side script could satisfy before the gate opens. Check 21
   traces to **dev-filled** `Resolves to` cells, not to tea's strategy: `stories-test-strategy.md:645-649`
   leaves them "for the dev", and no review gate re-checks the table after a later rename.
   → `gate-validation.md` Checks 5, 6, 21, 22; `stories-test-strategy.md:645-649`.
8. **Rework loops come mostly from evidence and bookkeeping, not code.** 22 of 33 implementation
   rework verdicts (67%) were evidence-format or bookkeeping: captures with no command or sha,
   uncommitted or gitignored RED files, empty headings, a status not flipped. This held under every
   dev binding and every reviewer tier.
   → `core/team-roles/dev.md` handoff contract.
9. **Repairs create the defects later adversary passes find.** In every *planning* series read
   (carry-over, requirements, architecture), in both sprints, each MAJOR on pass 2 or 3 sat in text
   the previous repair wrote or half-fixed: 19 traced, 16 read in full, and one true re-find. Those
   passes cost about $39 extra in s318 planning. In *stories* the repair-introduced share is a subset,
   by the adversary's own label: s317 p1 0/11, p2 2/9, p3 2/4; s318 p1 16/30, p2 8/19, p3 1/2. The
   pass-1 rise (0/11 → 16/30) follows the stories party repair. The remediator can also set aside a party major as "outside this shard",
   which is how C-18 (sweep_id never shown) reached sprint-review.
   → `core/team-roles/remediator.md`; `_gate-procedures.md:753` (adversarial repair dispatch).
10. **Lead-caused gate waste recurs under every lead model.** There were 7 discarded nonces costing
    $13.18 and 117 adjudicator-minutes, at about 0.08 per active hour on both Sonnet and the local
    qwen lead; 3 of the 7 were the same Check 22 waiver paperwork. The lead also re-sent 90 of 179
    spawns rejected at the concurrency cap, against rejection text that says "Do not retry".
    Other conduct: an inline product edit for ff1 (qwen/medium lead, later reverted), two wrong-base
    reconcile PRs reverted (#1181, #1184, Opus pre-step), and three s318 merges without the Rule 32
    advisor call.
    → `gate-validation.md` Check 22; `RB/rule-28.md:155` (waves).
11. **Dev escalation has no capital-path criterion.** s318 story 1.3 went to plain Haiku dev. The
    operator questioned it, the lead conceded the routing had no risk basis, and the story was
    re-dispatched to dev-escalated. The lead filed this in graph's ledger as a push candidate
    (`PC-S318-DEV-ESCALATION-HAS-NO-CAPITAL-PATH-CRITERION…`).
    → `stories-test-strategy.md:38-70` (routing tags).

### NOTE

- **Efficient:** gate-adjudicator (median 3.1 min, $0.46–0.55 per spawn, no verdict overturned on
  adjudicator error); every `gate-validation[…]` planning gate (about $5 and ≤20 min each); route;
  ui-direction; handoff; and the lead's cache-read ratio (97–98%). Haiku dev is *cheap* per spawn, but
  whether it is *efficient* is answered in "Role efficacy" below, not by its spawn cost.
- **Cache writes (37% of spend) scale with spawn count, not with work.** Any reduction in spawn count
  pays about 34K cw tokens per spawn avoided.
- **ai-dlc-update reconcile** cost 38.2 h and $140 in s317 (20 sessions), against 5.0 h and $38 in
  s318.
- **Hook injection is dominated by non-ai-dlc plugins.** context-mode's Read tip is 1.86 MB across
  4,507 firings.
- **9 `ESCALATION_UNDELIVERED` events with "No agent named 'lead'"**: the escalation path addresses a
  name the harness does not register.
  → `core/hooks/ai-dlc-escalation-delivery.sh`.
- **Rationale gaps** (no stated reason found): stories-test-strategy sub-steps, architecture 2a–2d,
  sprint-review party fan-out shape, Rules 1, 5, 6, 9, 10 and 14.

## Role efficacy: did each model and effort binding produce work that survived?

The operator retuned subagent model and effort during these sprints to find a more efficient
setting. Each change is a dated **change point** in the spawn ledger (`model_bound`, `effort_bound`,
ordered by spawn start; `out/binding-changepoints.txt`). Each change is read below as an experiment.
The outcome is the cost of work that passed, **including the rework it caused downstream**, not the
cost per spawn.

Four read-only analyses produced this section, one per phase group: planning; stories, ui-direction
and sprint-review; implementation and deploy; and the lead with cross-cutting roles. Their scripts
and joined data are in `pipeline-efficiency-s317-s318/role-efficacy/`.

**The main confound.** Every change point except the dev and code-reviewer switches falls between
the sprints. For those roles "before vs after" is also "s317 vs s318", which changes the subject
matter, the review sharding (requirements pass 1 was one reviewer in s317 and 19 shards in s318),
duplicate merging, the story author (sm to pm), and advisor availability (39 of 174 s318 adversary
runs reported the advisor rate-limited). Baseline roles that never changed (adversary, qa, pm, sm,
gate-adjudicator) moved as much as the changed roles in several measures. Read every verdict below
at its stated confidence.

### Subagent binding changes

| Role | Change (UTC) | n before → after | What moved | Verdict | Confidence |
|---|---|---|---|---|---|
| dev | sonnet/medium → haiku/high (10-10T20:04) → haiku/medium (10-11T11:56) | stories 14 → 4 → 10 | First-pass clean 8/14 → 3/4 → 5/10. Substantive-defect rework 3/14 → 0/4 → 1/10. Dev $ per story $3.89 → $0.40 → $0.79. | No measured rise in code defects on Haiku. All four haiku/high stories were small and non-capital, and capital-path s318 stories went to dev-escalated. Haiku/medium's measured weakness is **incomplete delivery**: 2.4 had no commit, 2.3's rework was incomplete, and 1.5 had a false model trailer. | LOW |
| dev (as a party seat) | sonnet → haiku | planning seats 15 → 40 | Cost per repaired finding 10–25× lower. 11 of 40 Haiku finals self-report a contract breach or an unverified claim, against 0 of 15 for Sonnet. Only seat with not-reproduced findings (3 of 46). | Cheap, but its findings need verification. | MEDIUM |
| code-reviewer | sonnet/high → opus/medium (10-10T21:08) | spawns 28 → 39; stories first-reviewed 10 → 14 | First-pass NEEDS_REWORK 4/10 → 3/14. Same $ per spawn ($1.86 → $1.84), 44% faster (14.4 → 8.0 min). Substantive escapes to QA 0 → 0. | Faster at equal cost, no quality loss seen. Opus samples ran with the advisor rate-limited more often. | LOW–MEDIUM |
| architect | opus/high → fable/medium (10-12T01:35) → opus/medium (10-12T19:07) | 65 → 11 → 51 (+18 with no effort recorded) | Fable cost about 6× opus/high per repaired finding in carry-over, with no better result. Opus medium vs high: cost per seat down 34% (stories) and 41% (sprint-review). 25 of 25 s318 majors acted on, and it was one of two roles finding majors no other seat found. | Opus/medium holds quality at lower cost; Fable/medium was the costliest. | LOW–MEDIUM |
| tea | sonnet/high → sonnet/medium (10-12T01:35) | 87 → 63 | Findings and majors per seat flat. Median time 26.5 → 3.1 min (planning). Abandoned runs 2 → 0. No later defect traced to tea's strategy, at either effort. | No measurable quality loss. | MEDIUM |
| remediator | sonnet/high → sonnet/medium (between 10-09T05:48 and 10-11T12:58) | 115 → 150 | Median time 10.8 → 1.8 min. Repairs that held: about 90% at both settings. **Repair-introduced majors rose:** 0.12 → 0.25 per repaired major (planning) and 0/11 → 16/30 of stories pass-1 majors. About $39 of extra third passes in s318 planning, against about $13 saved. | Cheaper per call, but more collateral damage; possibly net negative. Confounded by author, brief and sharding. | LOW–MEDIUM |
| dev-escalated | sonnet/high → sonnet/medium | 1 → 4 | 2 of 3 after-stories needed substantive rework. | Not comparable at n=1 before. | LOW |
| pm-escalated | sonnet/high → opus/medium | 1 → 1 | The two spawns did different tasks. | Not an experiment. | — |

Baseline roles that never changed: adversary (opus/medium), qa, pm, sm, analyst and gate-adjudicator
(all sonnet/medium), and code-reviewer-escalated (opus/high).

### Lead model

**Running the lead on the local `qwen38flash-mlx` model is an operator goal.** Defects the pipeline
exposes under a local lead are opportunities to fix in the pipeline, not reasons to move the lead
back to a hosted model. A lead-model comparison here is therefore not a choice between models. It
is a list of what has to change for the local lead to run cleanly.

The lead ran **Sonnet 5.5** for most pipeline work in both sprints. A **local `qwen38flash-mlx`**
model led 3,546 API calls (unique `message.id`, the same basis as the Method section; 9,423
transcript lines) of s317 pipeline work: route
through stories on 10-08, then implementation, gate 3, sprint-review and deploy-validate from 10-10 to
10-11. It is priced at $0, so the dollar tables understate s317's lead cost. Opus led only a handful
of pipeline calls (68 transcript lines). The per-regime guard rates below are per active hour, which
is unaffected by the line-versus-call distinction. The one lead *effort*
change was qwen xhigh → medium at 10-11T12:42, which coincides with entering deploy-validate.

Cost-bearing guard events (handoff guard, ACK denials, cap rejections) ran 3.25/h on plain Sonnet,
about 1.4–1.7/h on Sonnet 1M and 0.56/h on qwen/xhigh. Each regime ran different phases, so these
rates measure phase mix as much as model. Lead-caused nonce discards ran at about 0.08 per active hour
on both Sonnet and qwen. **No lead-model effect is separable** (LOW).

**Defects exposed under the local lead (opportunities toward the goal):**

- **Inline product edit, Rule 28.** The qwen/medium lead edited `rebalancer/execution.py` itself for
  ff1 (5 Edits, 10-11T19:52–19:54Z, session `af48eb49`). The edit was later reverted and a dev seat
  re-dispatched. The rule is prose. `core-guard` and `gate-remediation-guard` did not stop a lead edit
  to consumer product code outside a recorded gate FAIL.
  → `core/hooks/ai-dlc-gate-remediation-guard.sh`; `RB/rule-28.md`.
- **Fabricated future timestamps** in the pipeline snapshot, in the same qwen/medium window. They
  were found by the s317 retro, not by a mechanism. **The same defect recurs under the Sonnet lead
  in s318:** the snapshot clock ran ahead, with corrections at pipeline-snapshot-history.md:215, 219
  and 225 (10-14 02:11–02:58Z). It is the pipeline's defect, not the model's.
  → `core/skills/ai-dlc/steps/route.md` step 0a (snapshot integrity).
- **Malformed gate nonce.** Nonce `083048Z` (qwen/xhigh) was minted with a stray hyphen from
  `date -u +%Y-%m-%dT…`, and its checkpoint closed before dispatch. A hand-composed nonce format is a
  free-text step that a scripted minter would remove.
  → `core/scripts/gate-checkpoint.sh`.
- **Lead-authored gate paperwork.** Nonce `230257Z` (qwen/xhigh) was discarded because "The FAIL
  was the lead's own paperwork" (an OVERRIDDEN waiver). This is the same Check 22 class Sonnet also
  failed (DEFECT 10).
- **Skipped post-compaction recovery MUSTs** in s317 (retro), across qwen and Sonnet stints.
  `recover-gate` exists, but the MUSTs were still skipped.
  → `core/hooks/ai-dlc-recover-gate.sh`.

They fall into three kinds, which need different fixes:

- **No mechanism.** The inline product edit: Rule 28 is prose only.
- **A mechanism with a gap.**
  - Snapshot integrity (route 0a) does not catch future stamps.
  - `gate-checkpoint.sh` accepts a nonce the lead composed by hand without validating its format.
  - `recover-gate` exists, but the recovery MUSTs were still skipped.
- **A mechanism that fired and cost a re-pass.** Check 22 caught the bad waiver; the waste was the
  discarded nonce, not an escape.

A local lead exercises these gaps first. Closing them helps every lead model.

### What the bindings did *not* explain

The largest measured rework sources recur under every binding:

- **Evidence and bookkeeping.** 22 of 33 implementation rework verdicts (DEFECT 8).
- **Repair-created defects** driving extra adversary passes (DEFECT 9).
- **Full fan-out re-review** at $20–40 a pass in s317, against $1–3 delta re-review in s318 (DEFECT 1).
- **Lead gate paperwork** (DEFECT 10).
- **Dev-filled Strategy Test ID cells** that nothing re-checks (DEFECT 7).

One case does tie a loop to a dev: s317 story 2.6 (sonnet/medium). Two of its four rework rounds were
caused by the previous fix deleting other tests (MEDIUM).

**Deploy fix-forwards ff1–ff3 trace to no reviewer or QA escape.** ff1 exposed a path that predated
the sprint, ff2 is an enhancement ("Incident L does not reproduce"), and ff3 is a changed operator
requirement (LOW–MEDIUM).

## Relation to the v0.380.0 investigation

[`docs/v0.380.0-pipeline-cost-investigation.md`](../v0.380.0-pipeline-cost-investigation.md)
found that planning wall clock tracks **process volume** (r = 0.953 with planning artifact count),
not scope (r = 0.060 with stories delivered). It also found that convergence depth tripled at a
dated boundary, and that the pipeline is **lead-bound**. This measurement agrees on the first
point: the planning chain is 57–59% of spend, and its variance is adversary-series length. It
**differs on the third:** in s317–s318 the lead spent about as long *waiting on agents* (53 h and
37 h) as it spent active (73 h and 32 h). The critical path has moved toward the subagents.

## Reproduce

```
python3 -I scripts/extract.py <outdir>      # streams the transcripts, about 6 s
python3 -I scripts/analyze.py <outdir>      # steps/roles/hooks/tools CSVs + controls
python3 -I scripts/render.py  <outdir>      # the tables above
python3 -I scripts/bash_cost.py             # Bash wall clock by command family
python3 -I scripts/resident.py              # bytes Read from core files
```
