# Findings of reader `hand-tokens` (recovered verbatim from its transcript agent-ahand-tokens-d6c00fc3fc5d0a07.jsonl)

## FINAL-TEXT 2026-11-20T10:46:26.520Z

**s323 token and dollar decomposition: the biggest costs are context every spawn carries, not work the agents do**

1. **Fixed first-request context is $450 of $1,582 (28%).** That is what each spawn pays to load its prompt before doing any work, plus re-reading it on every later call. s321 was $437 (23%) and s322 $214 (22%). It is split between the consumer's resident rulebook block and the skills and tool lists, and both can be shrunk.
2. **The 48.8 KB project-instructions block is loaded into 795 spawns (15 roles) and none of them use it.** It holds graph's `CLAUDE.md`, two rule files and the operator's `MEMORY.md`, and costs $159. The renderer already has an opt-out, `omitClaudeMd`, which only 4 roles use.
3. **Parallel shards re-write their prompt instead of sharing a cache.** Later siblings get only 5–7K tokens of cache read on their first request (the tool definitions plus the 2.4 KB agent definition) and cache-write the other 18–37K. The upper bound on that is $118.
4. **The first role-file Read is denied by a size-limit hook on 795 spawns.** The role contract then loads in part: in a 40-spawn sample per role, 35 of 40 dev spawns and 13 of 40 code-reviewer spawns read under half of it.
5. **Prompt caching is not the problem.** The hit rate is 96.3% and cache-expiry rewrites cost $63. Output is only 18% of dollars. The lead's cost is about 13.5K calls at about 160K context each, and tool payloads are under 1% of its tokens.

**Method.** I extracted s323's 1,138 subagent transcripts, plus s321 (1,234) and s322 (668), into per-spawn records. Prices come from `roll.py`. Control: recomputed $1,582.28 against the record's $1,582.26, with 0 of 1,138 spawns off by more than $0.02. Bytes per token is 2.5, my estimate from the first-request size (about 44K tokens for about 111 KB). Component dollars use it and are approximate. Scripts and per-spawn data are in `/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/c10-tokens/`.

## 1. Dollars and tokens by role and step (s323)

Subagent total is 3.31 B tokens: cache-read 3,165 M, cache-write 120 M, output 20 M, fresh input 0.07 M. By dollars, cache-write is $664 (42%), cache-read $633 (40%), output $285 (18%).

| Role | Spawns | $ | $/spawn | Median calls | Cache-write $ | Cache-read $ | Output $ |
|---|--:|--:|--:|--:|--:|--:|--:|
| adversary | 149 | 319 | 2.14 | 37 | 43% | 34% | 23% |
| remediator | 258 | 298 | 1.15 | 18 | 36% | 47% | 17% |
| architect | 76 | 150 | 1.98 | 30 | 46% | 35% | 20% |
| dev-escalated | 13 | 128 | 9.82 | 135 | 46% | 41% | 13% |
| tea | 66 | 119 | 1.80 | 32 | 42% | 37% | 21% |
| qa | 97 | 114 | 1.18 | 23 | 37% | 50% | 13% |
| dev | 111 | 112 | 1.01 | 13 | 47% | 41% | 12% |
| gate-adjudicator | 168 | 92 | 0.55 | 16 | 44% | 40% | 16% |
| code-reviewer-escalated | 24 | 83 | 3.46 | 56 | 42% | 40% | 18% |
| code-reviewer | 58 | 45 | 0.77 | 17 | 45% | 42% | 13% |

Smaller roles (ops, pm, sm, analyst) are $1.7–27 each. Every role is cache-write heavy, 31–55% of its dollars. The heaviest are pm, sm and ops, because their spawns are short and the first request is most of the work.

Top 15 role×step cells (spawns, $, $/spawn):
1. adversary, stories-test-strategy: 58, $112.0, $1.93
2. remediator, requirements: 96, $97.6, $1.02
3. remediator, stories-test-strategy: 98, $88.2, $0.90
4. adversary, requirements: 46, $75.3, $1.64
5. remediator, carry-over-evaluation: 33, $70.7, $2.14
6. dev-escalated, implementation: 4, $68.2, $17.06
7. qa, implementation: 50, $64.7, $1.29
8. gate-adjudicator, gate[implementation]: 133, $64.6, $0.49
9. architect, sprint-review: 28, $53.8, $1.92
10. code-reviewer-escalated, gate[implementation]: 17, $53.0, $3.12
11. adversary, carry-over-evaluation: 18, $52.8, $2.93
12. dev, implementation: 18, $51.3, $2.85
13. tea, stories-test-strategy: 20, $49.2, $2.46
14. adversary, architecture: 15, $45.2, $3.01
15. tea, sprint-review: 33, $39.0, $1.18

Same-role totals, s321, s322, s323: adversary $609, $362, $319. remediator $260, $178, $298. tea $47, $35, $119. gate-adjudicator $57, $52, $92.

**NOTE (pricing basis).** `roll.py` prices cache-write at 2× input, the 1-hour rate. Every call in s323 shows `ephemeral_5m` only, with 0 one-hour tokens, and the request says `promptCacheRequested: 5m`. At 1.25× input, cache-write is $415 instead of $664, which would take about $249 off the $1,582. I did not check which rate is billed. Graph's `.claude/settings.json` sets `ENABLE_PROMPT_CACHING_1H=1`, but no subagent call used it.

## 2. Fixed context per spawn

Median first request is 43–45K tokens for the 15 roles that load the project block, and 23–25K for adversary, gate-adjudicator, analyst and pre-reviewer, which omit it. Total across s323 is 55 M tokens. The $450 is first-request tokens × (cache-write + (calls−1) × cache-read), by role:

| Role | First request, median tokens | Fixed $ | Share of role $ |
|---|--:|--:|--:|
| remediator | 43.9K | 100 | 34% |
| adversary | 25.1K | 60 | 19% |
| architect | 43.7K | 45 | 30% |
| qa | 44.1K | 42 | 37% |
| dev | 44.0K | 41 | 36% |
| tea | 43.5K | 36 | 31% |
| gate-adjudicator | 23.6K | 30 | 33% |
| code-reviewer, pm, sm | 43–45K | 20, 9, 6 | 45%, 47%, 51% |

What the first request is made of (bytes, from the request shapes and blobs):
- **Tool definitions, 18.2 KB**, 10 tools including Agent (5.4 KB), Skill, ToolSearch and Bash (4.1 KB): $88.
- **Environment, skills list and advisor text, 34.7 KB**: $167. The skills list alone is 30 KB, of which graph's 114 `bmad-*` skills are 15.9 KB and operator-global skills about 13 KB.
- **Project block, 48.8 KB**: $159. It holds graph `CLAUDE.md` 21.9 KB, `upstream-routing.md` 4.0 KB, `ai-dlc-resident-discipline.md` 2.2 KB and the operator's `MEMORY.md` 20.4 KB.
- **System definition 2.4 KB, git status and attribution 3.8 KB**: $11 and $18.
- **A second injection on call 2, 10.2 KB**: the agent-type listing (6.9 KB) and MCP instructions (2.8 KB), $48.
- **The role-file Read**, a fixed cost after the first request: $99.5 for 2,319 reads, 23.2 MB. Sizes in graph: qa 50.4 KB, code-reviewer 48.7 KB, adversary 46.9 KB, remediator 39.5 KB, dev 32 KB.

**DEFECT: the project block is loaded into spawns that never use it. Upper bound $159.**
- **Population.** 795 spawns across 15 roles. 0 of the 795 Read `CLAUDE.md`, the rules or `MEMORY.md`. The only role contract that points at `CLAUDE.md` is dev ("architecture document path defined in your project's CLAUDE.md", `dev.md:135`), plus protected-path-editor.
- **What it costs.** $133 excluding dev and dev-escalated, $159 including them. About $67 of that is `MEMORY.md` alone.
- **Cause.** `/Users/n8/git/ai-dlc/templates/settings.json.template:12,17,42,59` flags only 4 roles with `omitClaudeMd`. The renderer writes it at `core/scripts/render-agent-definitions.sh:182`. Its own comment (lines 30-38) sizes the block at "roughly 25 KB per spawn". It is now 48.8 KB.
- **Change.** Flag every role except dev, dev-escalated and protected-path-editor, and have the dispatch brief carry the architecture-doc path for dev. Confidence high on the mechanism, because adversary spawns show the block absent.
- **Wall clock.** About 19.6K fewer tokens (my estimate) written on each spawn's first call. I did not measure latency.

**DEFECT: roles that never use Skill or Agent still carry their listings. Upper bound about $162.**
- `web-fetch`, whose only tool is WebFetch, has a 1.2 KB tool block and no skills list; its whole first request is 6.2K tokens.
- Skill was used in 61 calls (48 of them adversary spawns) and Agent in 317 (310 by general-purpose).
- 1,062 spawns used neither. The skills list (30 KB) plus the Agent and Skill definitions (7.2 KB) cost $162 across them.
- The agent-type listing on call 2 adds another $32 where Agent is absent.
- Change: render a `tools:` allowlist into the agent definition at `render-agent-definitions.sh` near line 182, excluding Skill and Agent for roles that don't need them. Confidence medium. The skills list vanishing with the Skill tool is inferred from the `web-fetch` agent, which has a tool restriction, not tested on a role definition.

## 3. Calls per spawn and re-reading

Median calls per spawn are in the table above; dev is lowest at 13, pm 11, sm 12, analyst and ops 16–17.

- **Reads are 19% of dollars.** All Read results cost $297 (7,673 reads); all tool results cost $463 (29%).
- **By class:** `_bmad-output` artifacts $128 (27 MB), role files $99.5, code and config $29.
- **No whole-file reads of large files, no meaningful self-repeats.** No Read result over 40 KB, and 19 same-path same-range repeats within a spawn ($0.1).
- **Parallel shards.** 125 sibling groups cover 933 spawns, grouped as same role and step with starts chained within 120 s. A later sibling repeating an earlier sibling's exact Read comes to 838 reads, 11.4 MB, $44.7. Of that, role files are $35.2, so the rest is small. Adversary is $14.9 of it. Only 4.6 MB is read by every member of a group of 3 or more.
- **Do the shards share a cache prefix? No.** The first request of later members, average (cache-read, cache-write) tokens: adversary 5.1K/20.1K, remediator 4.9K/39.5K, qa 7.2K/36.8K, architect 5.7K/34.5K. The 5–7K that hits is the tool definitions plus the system definition, which is cache-controlled. The `CLAUDE.md` block and the rest sit in the message body.

**DEFECT: shard briefs differ, so the later shards' first requests cannot hit a shared cache. Upper bound $118 first-request, $45 repeated reads, mostly overlapping.**
- Per-role first-request bound: remediator $25.8, adversary $18.4, architect $17.2, tea $12.7.
- It assumes byte-identical briefs and a warm cache. The per-shard identity (`shard: i/N` and the like, `_gate-procedures.md:260`) would move into a first Read of a shard packet.
- The first shard has to be dispatched a few seconds before the rest. Siblings dispatched in the same second all cache-write regardless.
- Engine files: `core/skills/ai-dlc/steps/_dispatch-protocol.md:245` and `:292`, `_gate-procedures.md:260`.
- Confidence low-medium. I did not test whether the brief position lets a cache hit extend past the system definition.

**DEFECT: the mandatory first-action role-file Read is denied on large files, so many role contracts load only in part.**
- The `context-mode` hook `PreToolUse:Read` returns "N-byte file, over the one-read limit" and a 235-byte error for any role file over about 16 KB. Samples: architect 16,448 B, adversary 44,208 B, dev 30,218 B. gate-adjudicator at 16,032 B passed.
- 795 spawns hit the denial. The agent then reads the file in chunks, or through `ctx_execute`; one dev spawn used `head -c 9000` on a 32 KB file.
- In a random sample of 40 spawns per role, counting bytes returned by any command naming the role file, the share that loaded under half the file was:

| Role | Under 50% of the contract | Loaded at least 90% |
|---|--:|--:|
| dev | 35 of 40 | 1 |
| qa | 16 of 40 | 19 |
| code-reviewer | 13 of 40 | 14 |
| remediator | 13 of 40 | 12 |
| adversary | 5 of 40 | 26 |

- The wasted denied round trips cost about $9.7. The larger issue is contract compliance.
- Engine change: keep each role file under 16 KB as a core, with the remainder in appendices read on demand. That would also cut the $99.5 role-file read cost, and adversary alone pays $30.6.
- Cause: `render-agent-definitions.sh:187` ("FIRST action") against role files `core/team-roles/{qa,code-reviewer,adversary,remediator,dev}.md` (31–50 KB).
- Confidence medium-high on the denial. The sample counts only role-file bytes visible in command results.

## 4. Output and thinking by seat

All seats run at `effort: medium` except pre-reviewer (low). Model and effort bindings, as graph ran them:
- **opus/medium:** adversary, architect, tea, dev-escalated, code-reviewer-escalated, ops, pm-escalated.
- **sonnet/medium:** remediator, qa, dev, code-reviewer, gate-adjudicator, pm, sm, analyst.

Output is about 450–800 tokens per call. Thinking is 5.3 M tokens, $81, which is 5% of total dollars and 28% of output dollars. Thinking is 37–38% of output for adversary and architect, and 33% for tea. Output for adversary is $72.7 (23% of its spend).

No s323 reading of findings per seat exists on disk (`s323-outcomes-b261` is not in the checkout), so I did not join findings to cost. From the existing s322 reading, the pm seats cost $6.51 for 5 unique survivors.

**Exposure (not a recommendation), same tokens priced at sonnet:** adversary $104, architect $49, tea $37, dev-escalated $37.5, code-reviewer-escalated $25, ops $9.7, pm-escalated $3.5; total $266 of s323's opus spend. This ignores the BL-832 result: adversary on sonnet/high was slower (median 11.7 min against 5.6) and dearer ($2.89 against $2.14 per spawn). The 15 spawns recorded as `synthetic` and the one `local` spawn cost $0 and are excluded. I did not price haiku, because BL-838 found dev on sonnet beats haiku on rework.

The effort binding is not where the money is. The most any effort change could remove is the $81 of thinking across all seats.

## 5. Short-lived and wasted spawns

- **Rate-limit failures, 36 spawns.** All end in `API Error ... litellm.RateLimitError`. They cost $23.9 and 205 spawn-minutes. By role: tea 14, dev 10, architect 9. The work had to be re-dispatched.
- **Short spawns.** 195 spawns ran under 60 s or made fewer than 5 calls, costing $66.8 (179 under 60 s, 30 under 5 calls). Samples are real shard parts: remediator 56 ($21.7), dev 42 ($15.3), gate-adjudicator 33 ($11.7). I found nothing a script could do for free; the saving there is the fixed first-request charge each pays.
- **Gate-adjudicator shards that returned only PASS.** 80 of 168 shards, $40.3 of $91.7, return text containing PASS and no fail words. This is a text match, low confidence, and I did not check which checks the engine could skip by rule. gate-adjudicator spend is $64.6 in implementation, $10.5 in sprint-review.
- **Spawn results the lead never read.** I did not measure it.

## 6. The lead's tokens

Population: all s323 lead units, 13,512 calls and 2.11 B tokens (the pipeline bucket alone is 11,744 calls and 1.84 B).

| Call class | Calls | Tokens | Average context | Cache-read share |
|---|--:|--:|--:|--:|
| other | 6,159 | 0.949 B | 153K | 98.7% |
| merge | 3,620 | 0.599 B | 165K | 99.2% |
| snapshot | 1,255 | 0.204 B | 162K | 99.5% |
| gate-run | 668 | 0.112 B | 168K | 99.4% |
| step-reread | 684 | 0.100 B | 145K | 97.8% |
| dispatch | 394 | 0.070 B | 174K | 99.0% |
| compaction-recovery | 564 | 0.051 B | 90K | 84.5% |

- **Fresh input.** Fresh input is about 2.2K tokens per call and output about 700.
- **Context path.** In the busiest lead (76 compactions) the context runs from 46K at session start, to 73–88K after each compaction (median 83K), to a 228K peak.
- **Payload sizes.** Tool results total 34.5 MB, about 12 M tokens, 0.6% of lead tokens. Read is 22.4 MB (2,534 calls, 407 over 20 KB, mean 8.9 KB). Bash is 5.4 MB over 8,009 calls (mean 678 B). `ctx_execute` is 3.8 MB. Hook-injected context is about 5.8 MB, mostly UserPromptSubmit (3.65 MB over 1,820 calls). No payload returns a one-line verdict worth a change.
- **Where the tokens go.** Lead tokens are calls × resident context. The first request is about 46K tokens, so the project block (about 19.6K) is about 42% of it. Removing it lowers the average context by about 12%, about 225 M tokens per sprint (upper bound). It would also lengthen the compaction cycle about 15%. For the lead this depends on the consumer's `CLAUDE.md` and memory, not an engine flag; the engine can only recommend moving the 11.8 KB deployment protocol out of `CLAUDE.md`.
- **Step re-reads.** 684 `step-reread` calls (0.100 B tokens, 1.7 h) are the lead re-reading step files after compactions. Rule 22 is at `core/skills/ai-dlc/SKILL.md:741`, with the sliced-re-read controls at `:766-787`. The rule itself records the re-read as unverified (41% against 66% in its own measurement).

## 7. Prompt-cache efficiency

- Overall hit rate (cache-read ÷ all input) is 96.3% in s323, 95.6% in s321 and 96.3% in s322. By role it is 94.6–97.5%. The lowest are general-purpose 90.3%, dev 94.6%, gate-adjudicator 94.8% and code-reviewer 94.9%.
- **Cache-expiry rewrites.** After a gap over 300 s, 63 calls re-wrote most of the context, costing $63.3 above a cache hit. Median gap was 14 min, which fits long test or Monitor runs. s321 had 80 such calls ($46.7) and s322 had 39 ($17.1).
- **Where they land.** dev-escalated 18 calls ($33.6) and dev 24 calls ($14.7).
- **Change.** Make `ENABLE_PROMPT_CACHING_1H` reach subagents, since transcripts show 0 one-hour tokens. Upper bound $63 less the one-hour write premium. Where it is set and passed on is not in the engine files I read.
- **Other rewrites.** Another 42 calls rewrote context after short gaps ($7.8). I did not find the cause.

## Looked at and already efficient

- The cache is warm: 96%, with fresh input near zero.
- Same-spawn repeat Reads are essentially absent.
- The small-role seats (pm, sm, analyst) cost under $0.60 per spawn.

## Not measured

- Which skills a role actually needs, and whether a `tools:` allowlist removes the skills list. That is inferred from the `web-fetch` agent only.
- Latency effects of smaller prefixes.
- The 16 KB threshold for the Read denial, which is inferred from three observed file sizes.

Truncation: none.

## SENT 2026-11-20T10:47:00.068Z | Resend part 1: rest of section 1, sections 2-3

PART 1/3 (s323 token and dollar decomposition, resend from top-15 row 12). Method: per-spawn extraction of s323 (1,138), s321 (1,234), s322 (668) subagent transcripts; roll.py prices; control recomputed $1,582.28 vs record $1,582.26, 0 of 1,138 spawns off by >$0.02. Bytes/token 2.5 is my estimate (about 44K tokens for about 111 KB first request), so component dollars are approximate. Scripts and per-spawn data: /private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/c10-tokens/ (extract_spawn.py, lib.py, a2.py, a3.py, a3b.py).

SECTION 1 REST. Top-15 role x step cells, rows 12-15 (spawns, $, $/spawn):
12. dev, implementation: 18, $51.3, $2.85
13. tea, stories-test-strategy: 20, $49.2, $2.46
14. adversary, architecture: 15, $45.2, $3.01
15. tea, sprint-review: 33, $39.0, $1.18
(Rows 1-11 as already sent: adversary/stories 112.0, remediator/requirements 97.6, remediator/stories 88.2, adversary/requirements 75.3, remediator/carry-over 70.7, dev-escalated/implementation 68.2, qa/implementation 64.7, gate-adjudicator/gate[impl] 64.6, architect/sprint-review 53.8, code-reviewer-escalated/gate[impl] 53.0, adversary/carry-over 52.8.)
Same-role totals s321, s322, s323: adversary $609, $362, $319. remediator $260, $178, $298. tea $47, $35, $119. gate-adjudicator $57, $52, $92. Sprint totals: s321 $1,879 (fixed first-request $437), s322 $993 ($214), s323 $1,582 ($450). Token mix s323: cache-write 120 M, cache-read 3,165 M, output 20 M, fresh input 0.07 M. Dollars: cache-write $664 (42%), cache-read $633 (40%), output $285 (18%).
NOTE pricing basis: roll.py prices cache-write at 2x input (1h rate). Every s323 call shows ephemeral_5m only and 0 one-hour tokens; request says promptCacheRequested 5m. At 1.25x input cache-write would be $415, not $664 (about $249 lower). I did not check which rate is billed. Graph .claude/settings.json sets ENABLE_PROMPT_CACHING_1H=1 but no subagent call used 1h.

SECTION 2: fixed context per spawn. Median first request 43-45K tokens for the 15 roles that carry the project block; 23-25K for adversary, gate-adjudicator, analyst, pre-reviewer. Total 55 M tokens across s323. Fixed $ = first-request tokens x (cache-write price + (calls-1) x cache-read price):
remediator 43.9K, $100, 34% of role $; adversary 25.1K, $60, 19%; architect 43.7K, $45, 30%; qa 44.1K, $42, 37%; dev 44.0K, $41, 36%; tea 43.5K, $36, 31%; gate-adjudicator 23.6K, $30, 33%; code-reviewer $20, 45%; pm $9, 47%; sm $6, 51%. Total $450 (28%).
Composition (bytes, from api-request-shape and blob records): tools 18.2 KB $88; env + skills list + advisor text 34.7 KB $167 (skills list 30 KB, of which graph's 114 bmad-* skills 15.9 KB, operator-global skills about 13 KB); project block 48.8 KB $159; system definition 2.4 KB $11; git status + attribution 3.8 KB $18; call-2 injection (agent-type listing 6.9 KB + MCP instructions 2.8 KB) 10.2 KB $48. Role-file Read (after the first request): 2,319 reads, 23.2 MB, $99.5.
Project block contents: graph CLAUDE.md 21.9 KB, .claude/rules/upstream-routing.md 4.0 KB, .claude/rules/ai-dlc-resident-discipline.md 2.2 KB, /Users/n8/.claude/projects/-Users-n8-git-graph/memory/MEMORY.md 20.4 KB (18.8 KB now). 11.8 KB of CLAUDE.md is the Project Operations Protocol (deployment), which only ops needs.

EXACT EVIDENCE, omitClaudeMd. Which file sets it: /Users/n8/git/ai-dlc/templates/settings.json.template lines 12 (adversary), 17 (analyst), 42 (gate-adjudicator), 59 (pre-reviewer). Graph's own /Users/n8/git/graph/.claude/settings.json aiDlcRoles has the same 4 with omitClaudeMd true, and render-agent-definitions.sh (core/scripts/render-agent-definitions.sh:182) writes `omitClaudeMd: true` into /Users/n8/git/graph/.claude/agents/{adversary,analyst,gate-adjudicator,pre-reviewer}.md frontmatter. The other 15 roles render without it. The script's own comment at lines 30-38 sizes the omitted block at "roughly 25 KB per spawn"; it is now 48.8 KB.
Controls: (a) the first-request blob of an adversary spawn has user-message blocks [3217, 580, 260 bytes] against [48820, 3217, 582, 476] for a remediator spawn, so the omit flag demonstrably removes the block; (b) the "0 of 795 spawns read CLAUDE.md, rules or MEMORY.md" count has a positive control: 3 adversary spawns did Read one of them, so the detector can fire; (c) cost recompute control above. Role contracts citing CLAUDE.md: grep over graph .claude/team-roles/*.md finds only dev.md:135 (architecture-doc path "defined in your project's CLAUDE.md") and protected-path-editor.md:7; 0 for every other role.
Population: 795 spawns of 1,138 carry the block (remediator 258, qa 97, dev 111, architect 76, tea 66, code-reviewer 58, code-reviewer-escalated 24, pm 34, sm 20, general-purpose 18, ops 17, dev-escalated 13, others 3). Dollars by role: remediator $44.2, architect $21.9, qa $18.5, dev $18.0, tea $16.0, cr-esc $9.0, code-reviewer $8.8, dev-escalated $7.9. Total $159.3; excluding dev and dev-escalated $133.4; MEMORY.md part alone about $67. UPPER BOUND (assumes every flagged role can run without it). Wall clock: about 19.6K fewer tokens cache-written on each spawn's first call (my estimate, no latency measured).

SECTION 2b: skills list + Agent/Skill tool definitions (30 KB + 5.4 + 1.8 KB). Total $178.6 across spawns; 1,062 spawns used neither Skill nor Agent: $161.5. Skill used 61 calls (adversary 48), Agent 317 (general-purpose 310). Evidence for removal: the web-fetch spawn (tools: WebFetch only) has a 1.2 KB tool block, no skills list, first request 6.2K tokens. Not tested on a role definition (inferred). Plus agent-type listing on call 2: $32.5. Engine change: have render-agent-definitions.sh (near :182, where frontmatter is printed) emit a tools: allowlist.

SECTION 3: calls and re-reading. Read results $297 (7,673 reads, 19% of subagent $); all tool results $463 (29%). By class: _bmad-output $128.4 (2,812 reads, 27 MB), role files $99.5, code/config $29.0, other $12.0, other .claude $10.3, engine steps/skills $9.4 (gate-validation.md read 334 times, 2.2 MB), other md $8.0. No Read result over 40 KB; same path+range repeated within one spawn: 19 reads, $0.1. Sibling groups (same role+step, starts chained within 120 s): 125 groups, 933 spawns. A later sibling repeating an earlier sibling's exact Read: 838 reads, 11.4 MB, $44.7 (role files $35.2, bmad-output $6.2); by role adversary $14.9, architect $5.8, gate-adjudicator $5.5, remediator $5.0. Only 4.6 MB read by every member of groups of 3+.
Shared cache prefix? No. First request of later group members, average cache-read / cache-write tokens: adversary 5.1K / 20.1K, remediator 4.9K / 39.5K, qa 7.2K / 36.8K, architect 5.7K / 34.5K, gate-adjudicator 5.6K / 17.9K. The 5-7K that hits is tools + system definition (the cache-controlled blocks). The brief sits in the message body before the skills block, so differing briefs break the match.
UPPER BOUND $118 (first request; per role remediator $25.8, adversary $18.4, architect $17.2, tea $12.7, dev $10.7, qa $9.5, gate-adjudicator $8.4) assuming byte-identical briefs and a warm cache; plus $45 repeated reads, mostly overlapping. Engine change: per-shard identity (`shard: i/N`, core/skills/ai-dlc/steps/_gate-procedures.md:260; dispatch briefs core/skills/ai-dlc/steps/_dispatch-protocol.md:245, :292) moves into a first Read of a shard packet; dispatch shard 1 a few seconds before the rest. Siblings dispatched in the same second all cache-write regardless. Confidence low-medium. Wall clock: a few seconds stagger per group; cache-read first calls are faster than cache-write.

## SENT 2026-11-20T10:47:14.661Z | Resend part 2: denied role-file read, sections 4-5

PART 2/3.

DENIED FIRST ROLE-FILE READ (exact evidence). Hook: the context-mode plugin's PreToolUse:Read hook (the operator's global plugin, not an ai-dlc hook). Result text in the transcripts, 235-250 bytes: "PreToolUse:Read hook error: context-mode: 16448-byte file, over the one-read limit. Run mcp__plugin_context-mode_context-mode__ctx_execute(language, code, file=...". Observed samples, same text: architect.md 16,448 B, adversary.md 44,208 B, remediator.md 37,576 B, qa.md 50,386 B, code-reviewer.md 48,730 B (read by a code-reviewer-escalated spawn), dev.md 30,218 B. Controls: gate-adjudicator.md (16,032 B), tea.md (11 KB) and every smaller role file were read normally (results 10-17 KB, no error). So the threshold sits between 16,032 and 16,448 B, about 16 KB; I did not read the hook's source, so the exact limit is inferred. Detection of the denial population: Read of a .claude file with a 200-260 byte result: 795 spawns (remediator 258, adversary 149, dev 110, qa 97, architect 76, code-reviewer 58, code-reviewer-escalated 24, dev-escalated 12, a few others); 850 of those results carry is_error true. Caveat: the count is by result size, and 795 happens to equal the project-block population; I verified the text by hand only on the 7 samples above.
Consequence 1: one wasted API round trip per spawn, about $9.7 in total (small) and a few seconds each.
Consequence 2 (the real issue): the contract loads in part. Method: random 40 spawns per role (seed 3); sum of result bytes of every tool call whose input names team-roles/<role>.md (Read chunks, ctx_execute, Bash), denial results excluded. Share that loaded under 50% of the file / 50-90% / at least 90%: dev (32 KB) 35 / 4 / 1 of 40, median 10 KB; qa (50 KB) 16 / 5 / 19; code-reviewer (49 KB) 13 / 13 / 14; remediator (40 KB) 13 / 15 / 12; adversary (47 KB) 5 / 9 / 26; architect (16.8 KB) 4 / 4 / 32. One dev spawn read the contract with `head -c 9000` on a 32 KB file. Caveat: a ctx_execute with an intent filter or a later tool call may have supplied what a byte count misses; confidence medium-high on the denial, medium on the compliance gap.
Engine change: keep each core role file under 16 KB with appendices read on demand (core/team-roles/qa.md 50,457 B, code-reviewer.md 48,987, adversary.md 46,895, remediator.md 39,519, dev.md 31,554). The instruction is at core/scripts/render-agent-definitions.sh:187 ("FIRST action before any other work"). For tokens: adversary pays $30.6 per sprint for role-file reads, role files overall $99.5; a 16 KB core cuts most of that (UPPER BOUND about $60-70, my estimate from the bytes read) but for dev it ADDS tokens if the contract is fully read. This is a compliance fix first.

SECTION 4: output and thinking. Bindings as graph ran them (graph .claude/settings.json aiDlcRoles): opus/medium: adversary, architect, tea, dev-escalated, code-reviewer-escalated, ops, pm-escalated. sonnet/medium: remediator, qa, dev, code-reviewer, gate-adjudicator, pm, sm, analyst, cis, ux, protected-path-editor. sonnet/low: pre-reviewer. No seat runs high. Output per call: adversary 607 tokens (thinking 225, 37% of output), remediator 802 (183, 23%), architect 558 (212, 38%), tea 603 (201, 33%), dev-escalated 553, code-reviewer-escalated 557, gate-adjudicator 447 (70, 16%), qa 495 (119, 24%), dev 538 (157, 29%). Output dollars: adversary $72.7 (23% of its spend), remediator $51.5, architect $29.5, tea $25.2, dev-escalated $16.8, cr-esc $15.3, gate-adjudicator $14.6, qa $14.4, dev $13.4. Thinking totals 5.3 M tokens, $81 (5% of all dollars). So an effort change can remove at most $81 per sprint (UPPER BOUND) in any seat.
Findings join: no s323 per-seat findings reading exists in wt-c5 (s323-outcomes-b261 directory is absent), and I did not derive one. Existing readings: s322 pm seats $6.51 for 5 unique survivors.
Exposure at sonnet price (same tokens, not a recommendation): adversary $104.4, architect $49.0, dev-escalated $37.5, tea $37.3, code-reviewer-escalated $25.0, ops $9.7, pm-escalated $3.5; total $266.4. Not priced as a saving: BL-832 (adversary sonnet/high slower and dearer: s322 $2.89 and 11.7 min median vs s323 $2.14 and 5.6 min). Haiku not priced (BL-838). Rework/passes for these seats not re-derived.

SECTION 5: short and wasted spawns. API-error spawns: 36, $23.9, 205 spawn-minutes; every one is "API Error: Server is temporarily limiting requests ... litellm.RateLimitError" (tea 14, dev 10, architect 9, general-purpose 2, pm 1); they needed re-dispatch. Short spawns (under 60 s or under 5 calls): 195, $66.8 (179 under 60 s, 30 under 5 calls, 14 both); remediator 56 ($21.7), dev 42 ($15.3), gate-adjudicator 33 ($11.7), code-reviewer 13 ($5.6). Samples are real shard parts (gate shard, dev part, qa seat closed with 1 finding), not checks a script could do; their cost is mostly the fixed first request. 15 spawns recorded as `synthetic` and 1 `local` cost $0. Gate-adjudicator: 168 spawns $91.7 (133 in gate[implementation], $64.6); 80 of 168 final texts contain PASS and none of FAIL/MISSING/NOT_EVALUATED/REJECT/violation, $40.3. Regex on final text, low confidence; I did not check whether the engine could skip those shards by rule. Spawns whose result the lead never read: not measured.

## SENT 2026-11-20T10:47:29.130Z | Resend part 3: sections 6-7 and ranked changes

PART 3/3.

SECTION 6: lead tokens. Population: all s323 lead units in classes.jsonl, 13,512 calls and 2.11 B tokens (the pipeline bucket alone is 11,744 calls and 1.84 B). Classes (calls, tokens, average context per call, cache-read share): other 6,159, 0.949 B, 153K, 98.7%; merge 3,620, 0.599 B, 165K, 99.2%; snapshot 1,255, 0.204 B, 162K, 99.5%; gate-run 668, 0.112 B, 168K, 99.4%; step-reread 684, 0.100 B, 145K, 97.8%; dispatch 394, 0.070 B, 174K, 99.0%; compaction-recovery 564, 0.051 B, 90K, 84.5%; repair 168, 0.028 B. Fresh input about 2.2K tokens per call, output about 700.
Busiest lead session (53b4296a, implementation, 76 compactions, 953 M tokens): context starts at 45.8K, drops after each compaction to 72-89K (median 83K), peaks at 221-229K before the next. Median context per call 162K.
Tool payloads entering the lead (tools.jsonl, kind lead, s323, not paired with results): 14,136 results, 34.5 MB, about 12 M tokens at 2.8 B/token, 0.6% of lead tokens. Read 22.4 MB (2,534 calls, mean 8.9 KB, p95 31 KB, 407 over 20 KB); Bash 5.4 MB over 8,009 calls (mean 678 B, none over 20 KB); ctx_execute 3.8 MB (1,198 calls); Agent 1.0 MB; ctx_search 0.8 MB; advisor 0.7 MB. Hook-injected context: UserPromptSubmit 3.65 MB over 1,820 events, SessionStart 1.57 MB over 166, PostToolBatch 0.46 MB over 584 (about 5.8 MB, about 2 M tokens). Nothing here is worth turning into a one-line verdict; lead tokens are calls x resident context (13.5K x about 160K), and the first 46K of context is the same prefix the subagents carry (project block about 19.6K tokens of it).
UPPER BOUND, project block removed from the lead's resident prefix: average context falls about 12%, about 225 M tokens per sprint, and the compaction cycle (83K to 228K) lengthens about 15%. For the lead this is consumer content (graph CLAUDE.md, rules, memory), not an omitClaudeMd flag; the engine can only advise moving long procedures out of CLAUDE.md. Wall clock: smaller per-call prefill; not measured.
step-reread: 684 calls, 0.100 B tokens, 1.7 h; the re-read rule is core/skills/ai-dlc/SKILL.md:741 (Rule 22) with sliced-re-read controls at :766-787; the rule itself records the re-read as unverified (41% against 66%).

SECTION 7: cache efficiency. Hit rate cache-read / (cache-read + cache-write + fresh input): overall 96.3% (s321 95.6%, s322 96.3%). By role 94.6-97.5% for the 12 largest; lowest general-purpose 90.3%, dev 94.6%, gate-adjudicator 94.8%, code-reviewer 94.9%. Expiry rewrites (a call after a gap over 300 s that cache-writes more than half the prior context): 63 calls, $63.3 above a cache-read price; median gap 14 min (long test or Monitor runs). Roles: dev-escalated 18 calls $33.6, dev 24 calls $14.7, adversary 28 calls (all gaps, $5.3). s321: 80 calls $46.7; s322: 39 calls $17.1. Another 42 calls rewrote context after gaps under 60 s ($7.8); I did not find the cause.

RANKED ENGINE CHANGES (per sprint, s323 basis; $ are roll.py list prices, which price cache-write at 2x):
1. Set omitClaudeMd for every role except dev, dev-escalated, protected-path-editor, and carry the architecture-doc path in the dev brief. Files: templates/settings.json.template:12,17,42,59 (the 4 flagged roles today); core/scripts/render-agent-definitions.sh:182. $133 (UPPER BOUND $159); about 0.4 B cache-read plus 10 M cache-write tokens. Confidence high. Wall clock: about 19.6K fewer first-call tokens.
2. Role-file size: core role files under 16 KB core plus on-demand appendices (core/team-roles/{qa,code-reviewer,adversary,remediator,dev}.md) so the first Read is not denied. Fixes a compliance gap (dev 35 of 40 sampled spawns under 50% of contract); token effect up to about $60-70 on role-file reads (UPPER BOUND, my estimate), negative for dev. Confidence medium-high on the denial, medium on the saving.
3. tools: allowlist excluding Skill and Agent for roles that never use them (render-agent-definitions.sh near :182): UPPER BOUND $162 skills list plus Agent/Skill definitions across 1,062 spawns, plus $32 agent-type listing. Confidence medium (inferred from the web-fetch agent). Wall clock: first request 44K to about 28K tokens.
4. Byte-identical shard briefs with a shard-packet first Read, shard 1 dispatched ahead (_dispatch-protocol.md:245, :292; _gate-procedures.md:260): UPPER BOUND $118 plus $45 repeated reads (overlapping). Confidence low-medium.
5. 1h caching reaching subagents (graph settings env says set; 0 one-hour tokens seen): UPPER BOUND $63 less the write premium. Where the setting is lost is not in the engine files I read.
6. Rate-limit failures: 36 spawns, $23.9, 205 spawn-minutes; re-dispatch policy is the lead's, not measured further.
7. Effort/model changes: not recommended on this evidence; thinking is $81 total and the opus-to-sonnet exposure ($266) conflicts with BL-832.
Overlap: items 1 and 3 reduce the same first-request tokens, so do not add them; combined first-request ceiling is the $450 total (28%), which on the 2.5 B/token estimate is about $300 shrinkable, UPPER BOUND.
Not measured: skills a role actually needs, hook source and exact limit, latency effects, per-seat findings for s323, spawns whose results the lead did not read.

