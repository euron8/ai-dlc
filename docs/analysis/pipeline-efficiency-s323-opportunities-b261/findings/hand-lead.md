# Findings of reader `hand-lead` (recovered verbatim from its transcript agent-ahand-lead-fc9ed6e2d7de318e.jsonl)

## FINAL-TEXT 2026-11-20T10:50:41.211Z

The lead's own time in s323 is mostly model generation, and 78% of that is decoding output tokens. Of the 48.6 h "active", 15.4 h is waiting on running subagents, so about 33 h is the lead's own.

Everything below is the pipeline bucket (48.6 h, 134 compactions, 11,744 calls), the same population as your brief.

## Summary
1. **Lead-own time:** 25.2 h model, 5.8 h tool and 2.3 h idle with no agent running. A further 15.4 h is waiting on running subagents (shorter than 300 s), which the lead cannot shorten.
2. **Model time is decode-bound:** the median call takes 4.0 s. Latency is about 8.7 s per 1,000 output tokens. Context size does not move the median: it is flat at 3.4–3.7 s from 80k to 200k context. The 20% of calls with 1,000 or more output tokens carry 54% of model time (14.2 of 26.2 h).
3. **"Other" is 4,520 calls and 19.9 h active:**
   - model 8.9 h
   - tool 3.0 h
   - waiting 8.0 h (6.3 h of it ends on a notification enqueue)
   - of the waiting, text-only turns hold 4.8 h and operator asks 2.1 h
4. **Compactions** cost about 1.8 h firm (summarizer plus first-call prefill) and up to 6.1 h with re-orientation. The local window compacts at about 230k, against about 388k for the hosted s321 lead. Post-compaction baseline context grew from 23k to 43k tokens, s322 to s323.
5. **Hooks are not the cost:** 0.11 h of hook wall time, but 5.5 MB injected. Denials cost about 1.2 h (upper bound). Repeat work is small except re-reads after compaction (611 blocks, 0.80 h).

## Method and controls
- I ran a patched copy of `extract.py` (`Classer` and step logic untouched) that also writes one row per lead record. It reads transcripts only and writes nothing outside my scratch directory. I did not touch MONO or re-run its extraction.
- **Controls:**
  - Before the bucket filter, per-class calls and hours matched `MONO/classes.jsonl` exactly for s322 and s323.
  - With the bucket filter (pipeline = session reached a step beyond pre-step, per `analyze.py:25-28`), I reproduced 48.6 h, 134 compactions, 11,744 local-model calls and 57 compactions for s321.
  - Σ(response − request) over local-lead calls is 26.2 h against 25.2 h of "model" intervals, which is a 4% disagreement.
- **Not in the pipeline bucket:** the `ai-dlc-update` sessions are excluded (8.1 h, 16 compactions, 1,751 calls).
- **Active** means intervals of 300 s or less, so it includes waits.
- **What to trust in the split:**
  - Model is the interval ending in an assistant record or after an api-request marker. Against output tokens, R² is 0.66–0.97, so it is real.
  - "Tool" is the interval ending in a tool_result. It includes hooks and harness overhead around the call.
  - "Harness" is mostly waiting for a notification: queue-operation enqueue is 7.31 h of its 10.6 h. I split wait as "subagent running" or "no subagent running" using `spawns.jsonl`.
  - Thinking text is blank in the transcripts, so thinking tokens cannot be separated from text and tool arguments.
- **Hours** are lead wall-clock hours.
- **Tokens** are fresh (input plus cache-creation) plus output, in millions, with cache-read given separately.
- Scratch directory: `/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/leadtime.VUEMZE/`. `out/` holds the tables, `lib.py` the reader, and `build.py` the patched extract.

## 1. "Other" decomposed (s323)
The existing `lead_other_split.py` re-runs extract with an injected subclass. I used a direct reader instead, so its sub-class rules were not applied.

| Sprint | Calls | Active h | Model h | Tool h | Wait h |
|---|--:|--:|--:|--:|--:|
| s321 | 2,462 | 9.8 | 3.6 | 1.0 | 5.2 |
| s322 | 4,336 | 14.2 | 8.3 | 1.9 | 3.9 |
| s323 | 4,520 | 19.9 | 8.9 | 3.0 | 8.0 |

s323 by step group (calls / active h):
- planning 1,657 / 8.0
- implementation+gate 1,433 / 6.5
- sprint-review 342 / 1.5
- rest 1,088 / 3.9

Gate seats opened inside a planning step count under implementation+gate, which is why planning differs from b261's 1,927 calls.

Top families, s323 all steps (calls, active h, fresh+out M):

| Family | Calls | Active h | Wait h | fresh+out M |
|---|--:|--:|--:|--:|
| Text-only turn, no tool | 572 | 5.60 | 4.82 | 0.58 |
| Advisor consult | 193 | 2.46 | 0.21 | 0.99 |
| AskUserQuestion | 25 | 2.46 | 2.10 | 0.06 |
| Bash shell reads (grep/sed/cat/ls/awk) | 1,146 | 1.98 | | 1.65 |
| ctx_execute shell reads | 593 | 1.54 | | 1.05 |
| Bash git/gh | 190 | 0.71 | | |
| ctx_search/index | 228 | 0.64 | | |
| Read of skill/rules files | 230 | 0.46 | | |
| Bash other programs | 167 | 0.40 | | |
| Write of other paths | 57 | 0.35 | | |
| Bash scripts | 95 | 0.32 | | |
| ToolSearch | 65 | 0.29 | | |
| Bash/ctx python inline | 209 | 0.71 | | |
| Edit of gate records and planning artifacts | 166 | 0.46 | | |

- **Text-only turns:** 4.82 h of their 5.60 h is waiting for a notification, which belongs to the agents. The lead's own cost is 0.78 h.
- **Shell reads:** these are 1,739 separate model turns (3.4 h, 3.1 h of it model). The largest share, 928 calls and 2.1 h, targets repo and other paths.
- **Per-group tables:** `out/a4_323_planning.txt`, `a4_323_impl+gate.txt`, `a4_323_sprint-review.txt`, `a4_323_rest.txt` and `a4_all.txt`.
- **Bookkeeping, denied calls and hook-retry calls:** nothing shows in "other" apart from the denied calls counted in section 6. TodoWrite-style tools are about zero.

## 2. Seconds per call and why
Lead call latency (request to last assistant record), by sprint and model:

| Sprint, model | Median | p90 | Median ctx |
|---|--:|--:|--:|
| s321, hosted sonnet | 5.3 s | 16.5 s | 255k |
| s322, qwen38flash | 3.5 s | 15.3 s | 148k |
| s323, qwen38flash (10,683 calls) | 4.0 s | 18.3 s | 159k |
| s323, deepseek41 (1,061 calls) | 4.8 s | 19.5 s | 142k |

- **qwen, s323, by context bucket** (median, p90): 80–120k is 3.4 s, 17 s. 120–160k is 3.7 s, 15.8 s. 160–200k is 3.7 s, 15.2 s. Above 200k it is 5.4 s, 24 s.
- **By output tokens** (qwen): under 200 tokens is 1.6 s. 200–1,000 is 4.1 s. 1,000–5,000 is 15 s. Above 5,000 is 57 s.
- **OLS fit:** about 8.7 s per 1,000 output tokens, about 0.27 s per 1,000 uncached input tokens, and a small cache-read term.
- **Where model time goes:** by output size, 2,261 calls of 1,000 or more output tokens hold 14.2 h of 26.2 h. The first tools of those calls:
  - Agent dispatch prompts: 329 calls, 2.76 h, 1.03M output tokens
  - grep: 284 calls, 1.58 h
  - snapshot-update.sh: 131 calls, 0.79 h
  - Write: 49 calls, 0.48 h
- **Active, s323:** model 51%, harness/wait 21%, idle-wait 14%, tool 11%. Within tool, Bash is 2.69 h and advisor 1.76 h.
- **Hosted s321** is 5.3 s per 1,000 output tokens, so the local model is about 1.6 times slower per token. s321's lead active time was mostly waiting: model was 28% of active.

## 3. Compactions (s323: 134; s321 57; s322 72)

| | s321 | s322 | s323 |
|---|--:|--:|--:|
| Compaction trigger (preTokens, mean) | 369k | 230k | 231k |
| Post-compaction baseline (postTokens, mean) | 34k | 23k | 43k |
| Calls between compactions (median) | 106 | 122 | 79 |
| Minutes between (median) | 65 | 40 | 18 |

- **Local window:** about 230k. Compactions are now 1.8 per hour of sprint.
- **Summarizer:** 134 events (all auto), sum 1.24 h. 58 are real summarizer runs (median about 80 s). 76 report under 1 s, so they appear to be a no-model compaction. The call before the boundary ends median 3 s earlier for those 76 and median 80 s earlier for the 58 slow ones.
- **First call after compaction:** median 18.8 s, against a steady median of about 4 s. It carries about 52k uncached prompt tokens, about 0.55 h extra in total.
- **Re-orientation, window A:** leading reads of snapshot, step files, skills, task-output and ToolSearch. That is 618 calls, 0.25 h, 8.35M fresh+out tokens.
- **Re-orientation, window B:** until the first dispatch, edit, gate or commit call. That is 2,056 calls (mean 15), 4.29 h, 13.5M fresh+out tokens. This is an UPPER BOUND because it includes real triage.
- **Advisor touchpoint R:** 125 of 211 consults land within 40 calls after a compaction (1.55 h), mandated by `core/skills/ai-dlc/SKILL.md:1132`.
- **Step-reread class:** 684 calls, 1.69 h. 311 of them are within 25 calls after a compaction.
- **Total attributable:** about 1.8 h firm (summarizer 1.24 plus prefill 0.55) and up to about 6.1 h with window B. s321 was about 2.6 h and s322 about 3.4 h on the same definition.
- **Where they happen:** 65 of the 134 compactions occur in gate-validation, whose step file is 247 KB (`core/skills/ai-dlc/steps/gate-validation.md`). The lead read it 391 times (5.9 MB) in s323.

What fills the context. I excluded the `prompt_snapshot` attachments, which look like a system-prompt log. The rest is 435 KB plus 63k output tokens per cycle against 188k growth, implying about 3.5 bytes per token. Top consumers per cycle (s323 share):

| # | Consumer | KB/cycle (count) | Share |
|---|---|---|--:|
| 1 | Step-file Reads | 70 KB (5.8 reads) | 16% |
| 2 | `instructions` attachment (CLAUDE.md and rules, re-injected) | 52 KB | 12% |
| 3 | Bash results | 36 KB (52 results) | 8% |
| 4 | UserPromptSubmit injections, almost all the context-mode recall | 25 KB (12.7 injections) | 6% |
| 5 | `invoked_skills` re-injected | 27 KB | 6% |

Also in the top set are skill/rules Reads (26 KB), ctx_execute results (22 KB) and the compaction summary (20 KB). The re-injected set (instructions, skill listing, invoked skills, SessionStart, summary, file attachments) is about 160 KB, which is the 43k baseline. Subagent payloads are small: Agent results 7.7 KB and task-notification text 5.5 KB per cycle. Lead output tokens are about a third of growth.

## 4. Repeated work (s323)
- **Exact repeats** (same unit, step, tool and command text) number 1,028 blocks, 3.6 h. Advisor consults make up 186 blocks and 2.2 h of that, but they take no arguments, so they are not true repeats.
- **Real exact repeats** are about 840 blocks, 1.4 h, 7.3M tokens. The main part is Read of the same file after a compaction (611 blocks, 0.80 h, 260 with identical result size).
- **Polls:** `wait-for-deliverable.sh` was called 438 times (0.70 h active; the beats themselves fall in the over-300 s gap). 58 repeated the same command with an identical result size. Sleep-containing Bash is 89 blocks, 0.60 h.
- **Validators:** I found no meaningful exact re-runs of validators.
- **Near repeats** (same program plus path) are too coarse to count as repeated work.

## 5. Reaction latency (s323, last subagent of a round, n=216)
- Subagent end to notification enqueue is a median 0.5 s, so notifications are not late.
- Enqueue to next dispatch, edit, gate or commit: median 64 s, p90 565 s, 8.85 h with each event capped at 600 s. This includes real work such as reading the deliverable.
- Enqueue to the lead's first response record: median 14 s, 3.37 h capped. That splits into:
  - lead mid-call or between calls: 130 events, median 18 s, 1.18 h
  - lead idle after a turn end: 65 events, median 5 s, 0.79 h
  - operator ask pending: 10 events, 1.36 h
  - in a tool: 10 events, 0.05 h
  - compaction inside the window: 22 events
- Pure wake overhead is about 2.0 h and the operator-ask part is 1.4 h. The lead busy-mid-turn case is 3.9 s median delivery lag (2.7 h capped, overlapping the figures above).
- Overlapping notifications make a sum over all notifications meaningless, so I report only the last of each round.

## 6. Hooks on the lead (s323)
- **Wall time:** 4,542 hook records, Σ durationMs 0.11 h.
- **Injected:** 5.5 MB.
  - UserPromptSubmit 3.42 MB: 1,706 injections, of which `context_mode_recall` is 1,675 (3.39 MB, about 2 KB each). `ai-dlc-pause` is 31.
  - SessionStart 1.52 MB (139)
  - PostToolBatch 0.42 MB (524)
- **Denials:** 343 denied tool results.
  - Read over context-mode's one-read limit: 155. Retried: 101.
  - Post-compact recovery gate: 87 (46 Bash, 16 ctx_execute, 13 Read, 12 Agent).
  - Dispatch guard: 44, with 34 retried.
  - Steering budget: 14.
  - The calls' own active time is 0.72 h and the retries 0.52 h, so about 1.2 h is an upper bound.
- **Stop hook (`ai-dlc-continue.sh`):** 69 blocking feedback injections (63 "Pipeline is active", 6 handoff guard), 0.22 MB. The call after each took 0.20 h.

## Changes, hours removable, and the engine cause
| # | Tier | Change | Removes on s323 | Engine cause |
|---|---|---|---|---|
| 1 | DEFECT | Render dispatch prompts from role file plus brief by script, so the Agent call carries a path | UPPER BOUND 2.3 h and ~0.9M output tokens (329 calls) | `core/skills/ai-dlc/steps/_dispatch-protocol.md` (no prompt-assembly script exists; the lead authors 3.1k-token prompts) |
| 2 | DEFECT | Make `snapshot-update.sh` derive its payload from state, so the lead sends no long text | UPPER BOUND 0.79 h (131 long calls); the class is 1,255 calls and 3.57 h | `core/skills/ai-dlc/steps/gate-validation.md:1149` and other steps |
| 3 | DEFECT | Exempt "a background agent is running" from the Stop block, or end waits with a blocking `wait-for-deliverable.sh` beat | UPPER BOUND 0.20 h, 69 calls, 0.22 MB | `core/hooks/ai-dlc-continue.sh` (decision order, lines 7–11); `SKILL.md:142` (Rule 3) |
| 4 | DEFECT | Split step files so each read fits the context-mode one-read limit (denied at 25 KB and above; step sizes up to 247 KB); or ship per-section files | UPPER BOUND 0.45 h and 155 denied calls; the slice reads (70 KB/cycle) also shrink | `core/skills/ai-dlc/steps/` (implementation.md 52 KB, route.md 53 KB, retro.md 101 KB, _gate-procedures.md 148 KB, gate-validation.md 247 KB) |
| 5 | DEFECT | Cut the post-compaction route: have the recover hook inject snapshot plus digest in one step instead of a mandated Read, then Read, then advisor | UPPER BOUND 4.3 h (window B), 2,056 calls, 13.5M tokens | `core/skills/ai-dlc/SKILL.md:80-92` (digest Read); `core/hooks/ai-dlc-recover.sh:569`; `core/hooks/ai-dlc-recover-gate.sh:1-25` |
| 6 | NOTE | Drop advisor touchpoint R (post-compaction), or run it once per round | UPPER BOUND 1.55 h, 125 calls | `core/skills/ai-dlc/SKILL.md:1132`; Rule 32 gives about 100 s per consult at `:1166` |
| 7 | DEFECT | Raise the effective window or cut the baseline: the 52 KB `instructions` attachment, the 27 KB skill carry-over, the 25 KB UserPromptSubmit recall (switch off context-mode recall for lead sessions) | Fewer compactions; UPPER BOUND on window B and the 1.8 h firm cost | `CLAUDE.md` plus the unconditional rule files; hook outside the repo |
| 8 | NOTE | Fold the 1,739 shell reads (grep/sed/cat/ls) into scripts that answer one question per call | UPPER BOUND about half of 3.4 h | None named; follows from the call pattern |
| 9 | NOTE | Add hook feedback or a reminder to reuse a prior read after compaction | UPPER BOUND 0.80 h (611 repeat Reads) | `core/skills/ai-dlc/steps/*.md` |
| 10 | NOTE | Advisor (211 calls, 2.7 h, 1.8 h of it tool): value not assessed here | n/a | `SKILL.md:1123` |

I found nothing wrong with these:
- Hook wall time is negligible.
- Notification delivery lag is small.
- `wait-for-deliverable.sh` beats are already blocking and bounded (600 s).
- Exact repeats are rare apart from the post-compaction re-reads.

I did not measure the operator wait or the agent wait, which are out of scope. I did not check whether hosted-lead s321 had the same step-read pattern.

## SENT 2026-11-20T10:51:08.138Z | Resend part 1: section 1 rest, section 2

PART 1 of 3 (resend from section 1 onward). Population: s323 pipeline bucket (48.6 h active, 134 compactions, 11,744 local calls; controls matched MONO).

SECTION 1 (rest). Planning differs from b261's 1,927 calls because gate seats opened inside a planning step count under impl+gate in my grouping.
"Other" s323 = 4,520 calls, 19.9 h active: model 8.9, tool 3.0, wait 8.0 (6.3 h of the wait ends on a queue-operation enqueue = waiting for a notification). s321: 2,462 calls / 9.8 h. s322: 4,336 / 14.2 h.
Groups (calls / h): planning 1,657 / 8.0 (wait 3.9); impl+gate 1,433 / 6.5; sprint-review 342 / 1.5; rest 1,088 / 3.9.
Top families, s323 all steps (calls, active h, of which wait h, fresh+out Mtok):
- text-only turn (no tool): 572, 5.60, wait 4.82, 0.58M. Lead's own cost is the 0.78 h model part; the rest is waiting on agents.
- advisor consult: 193, 2.46 (tool 1.60), 0.99M
- AskUserQuestion: 25, 2.46, wait 2.10 (operator), 0.06M
- Bash shell reads (grep/sed/cat/ls/awk/tail/wc): 1,146, 1.98, 1.65M
- ctx_execute shell reads: 593, 1.54, 1.05M
- Bash git/gh: 190, 0.71 (tool 0.38)
- ctx_search/index: 228, 0.64, 0.57M
- Read of skill/rules files: 230, 0.46, 0.67M
- Bash other programs: 167, 0.40; Write other-path: 57, 0.35; Bash scripts: 95, 0.32; ToolSearch: 65, 0.29, 0.33M
- python inline (Bash + ctx_execute): ~209, 0.71
- Edit gate-records/planning-artifacts/docs: ~213, 0.57; TaskStop 59, 0.10 (0.60M fresh, ListAgents-style state)
Shell reads = 1,739 separate model turns, 3.4 h (3.1 h model). 928 of them (2.06 h) target repo/other paths (code, tests, task outputs), 146 task-output, 128 skill/rules, ~170 _bmad-output.
Per-group top-12 tables: scratch dir out/a4_323_<planning|impl+gate|sprint-review|rest>.txt, out/a4_all.txt (dir = /private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/leadtime.VUEMZE/). Bookkeeping tools (TodoWrite etc.) ~0 calls. Denied/retried calls are counted in section 6, not here.

SECTION 2. Seconds per call and why.
Latency = api-request to last assistant record of the message. Median / p90, s323: qwen38flash (10,683 calls) 4.0 / 18.3 s, median ctx 159k; deepseek41 (1,061) 4.8 / 19.5 s. s322 qwen 3.5 / 15.3 s. s321 hosted sonnet (6,631) 5.3 / 16.5 s, ctx 255k.
Context size does NOT drive it. qwen s323 by ctx bucket (median, p90): 80-120k 3.4 / 17.0; 120-160k 3.7 / 15.8; 160-200k 3.7 / 15.2; >200k 5.4 / 24.2.
Output tokens drive it. qwen s323 by output size: <50 tok 0.7 s; 50-200 1.6 s (n 2,874); 200-1,000 4.1 s (n 6,179); 1,000-5,000 15.2 s (n 2,155); >5,000 56.7 s (n 107, p90 112 s). OLS (R2 0.66 qwen, 0.75 deepseek): lat = -2.6 + 0.27 s/1k uncached input + 0.024 s/1k cache-read + 8.7 s/1k output tokens. Hosted sonnet: 5.3 s per 1k output (so local ~1.6x slower per token). qwen38flash-mlx in s321 fits at R2 0.97.
Decode share: mean output 713 tok/call (median 369) x 8.7 s/1k = ~6.2 s of 7.9 s mean model time per call. OLS-attributed decode ~20.4 h of the 26.2 h summed model latency (uncached prefill ~2.0 h). The cache-read term is small per call but collinear with the intercept, so I do not state a number for it; the flat median by ctx bucket is the better evidence.
Output-size distribution (s323, local calls): <200 tok: 3,112 calls, 2.0 h (7%); 200-1,000: 6,371 calls, 10.1 h (38%); 1,000-3,000: 1,849 calls, 9.0 h (34%); >=3,000: 412 calls, 5.2 h (20%). So 2,261 calls (19%) hold 14.2 h (54%) of model time and 5.0M of the ~8.4M output tokens.
What the >=1,000-output-token calls are (first tool of the call): Agent/Task dispatch 329 calls, 2.76 h, 1.03M tok (~3.1k tokens each = dispatch briefs/prompts authored token by token); grep 284 calls, 1.58 h, 0.56M; ctx_execute 151, 0.86 h; snapshot-update.sh 131, 0.79 h, 0.25M (snapshot text typed into the call); python inline 101, 0.65 h; cat 74, 0.58 h; Write 49, 0.48 h, 0.15M; Read step-file 68, 0.40 h (reasoning before a read); sed 73, 0.38 h; ls 62, 0.36 h. For the grep/cat/ls/read calls the output is almost certainly thinking, not written text: transcripts store thinking blank (thinking_display=updates), so thinking vs text vs tool arguments cannot be separated. I can say dispatch, snapshot-update and Write calls are written content (call arguments); I cannot say what fraction of the remaining ~1,500 calls is narration vs reasoning.
Engine text behind them: dispatch briefs: core/skills/ai-dlc/steps/_dispatch-protocol.md (no script assembles the prompt; the lead authors it per Agent call). Snapshot text: core/skills/ai-dlc/steps/gate-validation.md:1149 (writes go through scripts/ai-dlc/snapshot-update.sh, text supplied by the lead) and per-step calls (stories-test-strategy.md:786,795; deploy-validate.md:761; retro.md:1601-1607). Narration before waits: SKILL.md:142 Rule 3 plus hooks/ai-dlc-continue.sh (the Stop hook demands continuation, so a text-only turn is answered with 3.4 KB of feedback).
Active split s323 (my interval rules): model 25.2 h (51%), harness/wait 10.6 (21%), idle-wait 7.0 (14%), tool 5.8 (11%), wake 0.1. Of 48.6 h: waiting while a subagent runs 15.4 h; lead-own = model 25.2 + tool 5.8 + idle with no agent running 2.3 = 33.3 h. Tool: Bash 2.69, advisor 1.76, Agent 0.49, ctx_execute 0.29, Read 0.19, AskUserQuestion 0.19. s321: model was 28% of active (hosted lead mostly waited: 27.5 h waiting on agents); s322 model 49%.
Trust: model interval = closing record is assistant or previous is api-request (checked: sum of response latencies 26.2 h vs 25.2 h model intervals, 4% apart, R2 above). Tool includes hooks/harness around the call. Harness is mostly waiting for a notification (enqueue 7.31 h of 10.6 h).

## SENT 2026-11-20T10:51:22.973Z | Resend part 2: sections 3 and 4

PART 2 of 3. Population as before (s323 pipeline bucket).

SECTION 3. Compactions. s321 57, s322 72, s323 134 (all auto).
Window: preTokens mean s321 369k (median 388k), s322 230k, s323 231k (median 230k, max 249k). The local lead compacts at ~230k; the hosted s321 lead at ~388k. Per cycle context growth (pre minus post) is ~188k tokens in s323 vs ~335k in s321, which is why s323 compacts every 79 calls / 18 min (median) vs s321 every 106 calls / 65 min.
Cost of one compaction (s323):
- Summarizer: sum durationMs 1.24 h. 58 are real runs (median ~80 s before the boundary stamp); 76 report <1 s (a no-model compaction; the call before the boundary ends median 3 s earlier). s321 1.10 h (all real), s322 1.56 h.
- First call after: median 18.8 s own latency (steady median ~4 s), ~52k uncached prompt tokens because the prefix cache is gone. Excess ~15 s x 134 = ~0.55 h and ~7M uncached tokens.
- Firm total = 1.24 + 0.55 = ~1.8 h.
- Re-orientation window A (leading Reads of snapshot, step files, skill/rules, task-output, ToolSearch/Skill): 618 calls (4.6 per compaction), 0.25 h, 8.35M fresh+out tokens (mostly the first call's uncached prompt), 48M cache-read.
- Window B (until first dispatch/edit/gate/commit call): 2,056 calls (mean 15), 4.29 h (mean 115 s), 13.5M fresh+out, 203M cache-read. UPPER BOUND: it includes real triage. It also contains the advisor touchpoint R: 125 of 211 consults land within 40 calls after a compaction = 1.55 h.
- Step-reread class: 684 calls, 1.69 h; 311 within 25 calls after a compaction.
- Up to ~6.1 h = 1.8 firm + 4.29 window B (B overlaps the advisor 1.55 h; step-reread partly overlaps B). Same definition: s321 ~2.6 h, s322 ~3.4 h.
- Where: 65 of 134 compactions occur inside gate-validation (core/skills/ai-dlc/steps/gate-validation.md is 247 KB; lead did 391 reads, 5.9 MB, in s323), 11 each in stories-test-strategy and implementation, 10 requirements.
Why baseline grew 23k -> 43k (s322 -> s323 mean postTokens): the post-compaction context is almost entirely re-injected fixed text. Per-cycle KB (s322 -> s323): `instructions` attachment (CLAUDE.md + unconditional rules + user CLAUDE.md) 37.8 -> 52.3 (+14.5); invoked_skills (skill carry-over) 22.2 -> 27.2 (+5); compaction summary 15.4 -> 19.6 (+4); file attachments 12.3 -> 16.2 (+4); skill_listing 19.7 -> 18.8; SessionStart hook context 11.5 -> 11.3. These plus deferred-tools/agent listings sum to ~160 KB = ~43k tokens at the 3.5 bytes/token implied by the per-cycle budget (435 KB + 63k output tokens vs 188k growth). The instructions growth is the resident-rules channel (CLAUDE.md and .claude/rules unconditional files), the main contributor to the +20k.
What fills the window between compactions (s323, KB per cycle, share of non-snapshot bytes; prompt_snapshot attachments excluded as a system-prompt log): 
1. Step-file Reads 70 KB (5.8 reads; 16%). gate-validation.md 391 reads/5.9 MB, _gate-procedures.md 114/1.0 MB, implementation.md 60/0.9 MB
2. instructions attachment 52 KB (12%)
3. Bash results 36 KB (52 results; 8%)
4. UserPromptSubmit injections 25 KB (12.7/cycle; 6%): 1,675 of 1,706 are the context-mode recall block (~2 KB each), only 31 are ai-dlc-pause
5. invoked_skills 27 KB (6%)
Also: skill/rules Reads 26 KB, ctx_execute results 22 KB, queued_command 20 KB, compaction summary 20 KB, skill_listing 19 KB, file attachments 16 KB. Subagent payloads are small: Agent results 7.7 KB, task-notification text 5.5 KB per cycle (s321 had 18.8 and 24.5 KB). Lead's own output tokens ~63k/cycle = a third of growth. ai-dlc SKILL.md text loads via the Skill tool: 9 in s323 (~195 KB each when loaded; ~50k tokens each).

SECTION 4. Repeated work (s323, exact repeat = same unit+step+tool+command/path text):
- 1,028 blocks, 3.6 h, 7.3M fresh+out tokens, of which 186 blocks / 2.2 h are advisor consults that take no arguments (not true repeats). Real: ~840 blocks, ~1.4 h.
- Main part: Read of the same file+slice after a compaction: 611 blocks, 0.80 h, 260 with identical result size. Same-cycle Reads 67 blocks 0.09 h. git push repeats 8 (0.22 h, mostly retries after a failure/deny).
- Polls: wait-for-deliverable.sh 438 calls, 0.70 h active (the beats themselves fall in the over-300 s gap since a beat can sleep up to 600 s, wait-for-deliverable.sh:493); 58 exact repeats with identical result size (0.09 h). sleep-containing Bash 89 blocks, 0.60 h.
- Validators: validate-gate-adjudication.sh 65 calls (0 exact repeats), validate-artifact-derivations 29, validate-snapshot-conservation 21, gate-checkpoint.sh 115, gate-transition.sh 94 (0.54 h, 2 repeats): no meaningful same-result re-runs.
- snapshot-update.sh 636 calls 1.73 h (3 exact repeats), so those are different updates, not repeats.
- "Near repeats" (same program + first path) are 6,420 blocks by my key but that key is too coarse (different greps on one directory); I do not count them as repeated work.

## SENT 2026-11-20T10:51:42.119Z | Resend part 3: sections 5, 6, ranked changes

PART 3 of 3.

SECTION 5. Reaction latency (s323, LAST subagent of a round = no other spawn of that lead running at its end; n=216; matched by task-id to spawns.jsonl). Overlapping notifications make an all-notifications sum meaningless, so only round-last events are summed.
- Subagent end -> notification enqueued: median 0.5 s (p90 1.8 s). Notifications are not late.
- Enqueue -> next dispatch/edit/gate/commit call: median 64 s, p90 565 s, 8.85 h with each event capped at 600 s (26.3 h uncapped, dominated by operator-pending outliers). This includes real work (reading the deliverable, deciding).
- Enqueue -> first lead response record: median 14 s, 3.37 h capped. Split by lead state at enqueue: mid-generation or between calls 130 events, median 18 s, 1.18 h; idle after turn end 65, median 5 s, 0.79 h; operator ask pending 10, 1.36 h; inside another tool 10, 0.05 h. Compaction occurred inside the window in 22 events. So pure wake/delivery overhead is ~2.0 h; operator ask pending is the remaining 1.4 h. Delivery lag when the lead is busy: median 3.9 s.
- Comparison (first-response, capped): s321 4.20 h / 256 events, s322 5.76 h / 234 events.
- Lead was idle waiting on a late notification: not observed (lag 0.5 s median).

SECTION 6. Hooks on lead turns (s323, 4,542 hook records).
- Wall time: sum of durationMs 0.11 h (sequential upper bound). Top: ai-dlc-recover.sh SessionStart 134 x 975 ms = 0.04 h; ai-dlc-context-sensor.sh PostToolBatch 524 x 203 ms = 0.03 h; ai-dlc-dispatch-guard.sh PreToolUse 179 x 405 ms = 0.02 h. Hook time is not a cost.
- Injected bytes 5.5 MB: UserPromptSubmit 3.42 MB (1,706; 1,675 are context_mode_recall ~2 KB each; 31 ai-dlc-pause), SessionStart 1.52 MB (139), PostToolBatch 0.42 MB (524).
- Denials: 343 denied tool results. By hook: context-mode one-read limit on Read 155 (101 retried next call; smallest denied file seen 25,332 B; the denial tells the lead to use ctx_execute with file=); post-compact recovery gate 87 (46 Bash, 16 ctx_execute, 13 Read, 12 Agent; few retried because the lead then does the mandated Reads); dispatch guard on Agent 44 (34 retried); steering budget on foreground Bash 14 (13 retried). Cost: denied calls' own active 0.72 h + retry calls 0.52 h = ~1.2 h UPPER BOUND, 343 calls + 169 retries.
- Stop hook (hooks/ai-dlc-continue.sh): 69 blocking feedback messages (63 "Pipeline is active...", 3.4 KB each; 6 handoff guard) = 0.22 MB; the call after each costs 0.20 h in total (33 other, 28 merge-class).

RANKED ENGINE CHANGES (s323; all hours/calls are UPPER BOUND unless stated; paths under /Users/n8/git/ai-dlc/core/)
1. Compaction route, up to 4.3 h / 2,056 calls / 13.5M fresh+out tokens (window B) on top of 1.8 h firm. Cut the baseline and the re-orientation: skills/ai-dlc/SKILL.md:80-92 (mandated digest Read of a 27 KB file), hooks/ai-dlc-recover.sh:569 + hooks/ai-dlc-recover-gate.sh:1-25 (FIRST Read snapshot, SECOND Read step file, then Rule 32 touchpoint R at SKILL.md:1132). Change: have the recover hook inject the snapshot slice and the step's resume section directly instead of mandating Reads; baseline files (CLAUDE.md + unconditional .claude/rules, 52 KB `instructions`) shrink via the resident-context discipline; switch the context-mode recall injection off for lead sessions (25 KB/cycle, outside the repo).
2. Dispatch briefs, up to 2.3 h and ~0.9M output tokens (329 calls of 1,000+ tokens, 2.76 h, 1.03M tokens): skills/ai-dlc/steps/_dispatch-protocol.md. Change: a script renders the prompt from role file + brief path; the Agent call carries only the path and the few variable fields.
3. Advisor touchpoint R, up to 1.55 h / 125 calls (211 consults total 2.72 h): skills/ai-dlc/SKILL.md:1132 (Rule 32 at :1123-:1169). Change: drop R or fold it into the once-per-gate G1; value of the other touchpoints not assessed here.
4. snapshot-update.sh text, up to 0.79 h / 131 calls (class total 1,255 calls, 3.57 h): steps/gate-validation.md:1149, stories-test-strategy.md:786,795, deploy-validate.md:761, retro.md:1601-1607. Change: derive the update from records in the script (--from-state) so the lead sends a short call.
5. Step files over the one-read limit, up to ~0.45 h / 155 denied reads + the 70 KB/cycle of step-file slices: steps/gate-validation.md (247 KB), _gate-procedures.md (148 KB), retro.md (101 KB), route.md (53 KB), implementation.md (52 KB). Change: ship these as per-section files under the limit, with the section list rendered by script, so each read is whole and not retried; gate-validation alone is 391 reads / 5.9 MB.
6. Stop-hook forced continuation, up to 0.20 h / 69 calls: hooks/ai-dlc-continue.sh (decision order at top of file), SKILL.md:142 Rule 3. Change: allow stop when a background agent is running, or end waits with the blocking wait-for-deliverable.sh beat in the same call.
7. Shell-read triage, up to ~1.7 h of 3.4 h / 1,739 calls (half): no engine text names it. Change: a gate-findings script that prints the cited lines for a finding in one call.
8. Re-read after compaction, up to 0.80 h / 611 Reads (260 identical result size): partly folded into change 1.
9. Dispatch-guard and steering-budget denials, up to ~0.45 h / 58 calls (44 dispatch guard + 14 steering): hooks/ai-dlc-dispatch-guard.sh, hooks/ai-dlc-foreground-budget.sh. Change: make the guard's check part of the dispatch script (change 2) so a refusal cannot happen.
Not removable by lead changes: 15.4 h waiting on running subagents (7.7 planning, 4.9 impl+gate, 1.8 sprint-review, 1.1 rest); 2.1 h operator AskUserQuestion wait inside "other".
Found efficient: hook wall time (0.11 h), notification lag (0.5 s), validator re-runs (none), exact-repeat polls (58 calls, 0.09 h).
Overlap warning: items 1, 3 and 8 overlap (window B contains the R consults and the re-reads); do not add them. Items 2 and 4 are disjoint from the rest.
Scratch: /private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/leadtime.VUEMZE/ (lib.py reader, out/ tables).

