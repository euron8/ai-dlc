# Findings of reader `hand-tail` (recovered verbatim from its transcript agent-ahand-tail-75998b372bdac056.jsonl)

## FINAL-TEXT 2026-11-20T10:50:46.960Z

**Summary**
1. Sprint-review took 4× the lead-active hours because the operator ruled the sprint's own scope gap (stories 2.1–2.3, wrongly labelled "operator-held") was to be built inside it. That work was about 3.4 h of lead-active time. "Per-chain consolidation" is a graph subject name, not pipeline machinery; PR #1337 is just the sprint-wide merge PR.
2. The biggest tool finding is subagent `wait-for-deliverable.sh`: 9.8 h in s323 against 0.91 (s322) and 0.35 (s321). About 6.8 h of that is in 81 units that hit graph's pytest admission refusal (`26 GiB needed > ~15–24 GiB headroom`). One QA agent spent 4.6 h of its 4.8 h life in that retry loop. This is mostly graph-side, with an engine-side queue fix available.
3. Lead dispatch denials: 211 of 1,033 Agent calls (20%) were denied, versus 10% in s322. 131 were the missing `Deliverable:` line in the brief and 40 were post-compaction recovery owed. Upper bound 0.66 h of lead generation time lost.
4. Of the late-step lead time, up to about 3.0 h across sprint-review (second session), deploy-validate and retro is fixed procedure a script could carry (snapshot writes, waits, gate scripts, commit and push). Expect 1.5–2 h reachable. 280 back-to-back `snapshot-update.sh` calls alone cost 0.86 h, and the script already takes many operations per call.
5. Hooks, `git push`, `git commit`, CI and API errors are not meaningful wall-clock costs. The eight `/ai-dlc-update` reconcile sessions are outside the 75.4 h (the pipeline bucket sums to 75.377 h) and add 16.4 h elapsed, 8.1 h lead-active.

Method notes. Paired reader: `scan.py`/`fam.py` in my scratch dir `/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/hand-s323late/`. Control: its s322/s323 Bash counts match `tools.csv` exactly (lead 6,718 and 8,009; sub 25,317 for s323). The published `bash_by_sprint.py` was run unmodified at top-80; s321 comes from it only (unpaired). Backgrounded calls charge about 0 s, so 40 of the 66 lead pushes and 47 full-suite runs are invisible in latency.

## A. Late steps

**A1. Timeline** (lead session 64926214 unless noted; lead-active h from monotone-clock gaps ≤300 s)

| Window (UTC, 11-19/20) | What ran | Lead active |
|---|---|---|
| 53b4296a, 02:53–04:29 | 2 sprint adversaries, 2 merge-resolution devs (1.3, 5.2), re-reviews, full suites on merged HEAD, fixes. Ends with the scope-gap question. | 1.17 h |
| 04:29–07:44 | Operator answer: "Build all three now" (**operator wait 3.25 h, marked**) | 0 |
| A 12:48–14:04 | Stories 2.1/2.2: dev seats, gates 1–3, one operator ask (15 min) | 1.01 h |
| B 14:04–16:40 | Story 2.3 build, review, QA, 3 adjudications, sprint adversary, fix devs | 1.84 h |
| C 16:40–17:23 | Prep for the seat panel | 0.58 h |
| D 17:23–18:23 | About 60 party seats in waves 17:43–17:52, then dev fixes A/B/C, remediator, step-3 review and QA | 1.00 h |
| E 18:23–19:12 | Operator asks about the byte-pin re-baseline (**48 min, marked**) | 0.03 h |
| F 19:12–20:17 | Gate[sprint-review]: 4 adjudicator shards, Check 1 FAIL (an `APPROVED` verdict line outside the QA set, plus an open-MAJOR sibling file), 2 remediators, 4 shards re-run | 0.95 h |
| Deploy-validate 20:17–01:36 | PR #1337 merged 20:46Z; roll and allowlist PUT with 3 operator asks; smoke and visual check (15 min ask); mTLS defect, then fix-forward (dev-escalated, review, PR #1338 merged 00:32Z, re-roll). 7 operator asks totalling 31 min. | 0.47+1.18+0.85+1.36+0.15 = 4.0 h |
| Retro 01:36–04:17 | 6 party seats, 7 analyst draft surfaces, 3 close-out analysts, a dev fix, 3 gate shards, retro PR, 7b with 6 analyst inputs | 0.84+0.97+0.75 = 2.6 h |

My windows A–F sum to 5.4 h. The roll's 5.65 h sprint-review figure is sessions 53b4296a and 64926214 combined (4.17 h + 1.48 h gate), and about 0.95 h of the 64926214 window is labelled `implementation`.

The lead's calls, by turn plus tool minutes (turn = model time before each call):

| Bucket | Sprint-review (64926214) | Deploy-validate | Retro |
|---|---|---|---|
| Hand-reading shell and Read | 117 min | 103 min | 32 min |
| Snapshot bookkeeping | 38 | 21 | 14 |
| Gate and validator scripts | 26 | 0 | 19 |
| Operator asks (tool wait) | 73 | 31 | 0 |
| Advisor | 17 | 17 | 7 |
| Git push | 0.4 | 1.6 | 13.4 |

Of the 1,402 sprint-review calls, 769 are Bash. Tool latency is a small share: Bash tool time is 13 min of 7.5 h in sprint-review and about 13 min of 5.3 h in deploy-validate, and the rest is model turns of about 7–25 s each.

**Why 4× (5.65 h vs 2.94 and 1.66):**
- **DEFECT, sprint-specific scope plus a pipeline hole.** The sprint held 3 stories as "operator-held" with no operator quote. The lead found this only in sprint-review, and building them took windows A–C, about 3.4 h of lead time. The per-story review panel itself (D) was 1.0 h, in line with s321. An implementation-exit check requiring a quote for any "held" label would surface this earlier. Confidence high on the timeline; the check is a suggestion.
- **DEFECT, panel size.** s323 spawned 158 sprint-review agents for 18 stories (8.8 per story, 16.2 agent-h) against s321's 165 for 25 (6.6 per story, 13.8 agent-h).
- **NOTE.** 44 `Server is temporarily limiting requests` errors hit the seat wave at 17:47. Each retried in about 80 s, so roughly 0.02 h wall.

**A2. Fixed-procedure candidates** (lead turn plus tool minutes in 64926214 sprint-review, deploy-validate and retro; upper bound on what one script could remove):
- Sprint-review about 94 min, deploy-validate about 31 min, retro about 56 min, total about 3.0 h. Realistic reach is 1.5–2 h.
- `snapshot-update.sh`: 975 calls, 3.31 h of turns across the 5 pipeline leads. 280 immediately follow another snapshot call (0.86 h). The script already says "one call carries every change" (`core/scripts/snapshot-update.sh:2`), so this is lead habit, not a missing feature.
- Repeated gate triples: 143 runs of three consecutive `snapshot-update` calls, 31 of `gate-checkpoint` (93 calls total).
- Retro: the lead wrote its own scratch scripts (`retro-step1.sh`, `retro-step1-combined.sh`, `s323-backlog-archive.sh`, `s323-5c-trim*.sh`, `7d-snapshot*.sh`), 38 authoring calls. The engine ships only prose: `core/skills/ai-dlc/steps/retro.md` has 1,740 lines but 8 fenced blocks (170 lines).
- `deploy-validate.md` (770 lines) has 5 fenced blocks (93 lines), so deploy-validate is also largely hand-run. Its remaining time is ops and operator-driven, not scriptable.

Retro `git push` is on the critical path: 5 pushes took 770 s, the longest 453 s (`git push -u origin HEAD`, 03:45Z). The result text was compressed in the transcript, so I could not see which pre-push steps ran.

**A3. Session starts:** cheap. First dispatch came 5, 5, 13, 17 and 7 min after session start (36, 33, 93, 71 and 46 calls), 47 min in total, about 1.6% of lead-active.
- Each session reads `route.md` in 3–5 slices, the snapshot 2–3 times and the step file 3–4 times. The context-mode "one-read limit" forces the slicing.
- The recurring cost is post-compaction: `compaction-recovery` 1.88 h (563 calls) plus `step-reread` 1.69 h (684 calls) over 134 compactions, about 96 s each, 3.57 h or 7.3% of lead-active. The same two classes were 1.7 h in s322 and 0.76 h in s321, rising with compactions per hour (0.51, 1.08, 1.78).
- Step files are 52 KB (`implementation.md`), 100 KB (`retro.md`), 148 KB (`_gate-procedures.md`) and 246 KB (`gate-validation.md`). I did not measure tokens per re-read.

**A4. Reconcile sessions.** There were 8 `/ai-dlc-update` sessions, not 3. Engine versions 0.1128, 0.1142, 0.1143, 0.1152, 0.1157, 0.1160, 0.1164 and 0.1174 (0.1167 was handled inside the last one).
- They are not in the 75.4 h. The pipeline bucket sums to 75.377 h; the update bucket adds 16.4 h elapsed (8.1 h lead-active, 4.65 h operator wait, 3.65 h agent-wait, 16 compactions).
- Per session (active h, calls, token-eq $ at sonnet list price): 0.81/148/$11, 1.04/220/$12, 1.11/188/$13, 0.79/178/$12, 0.90/241/$14, 0.60/108/$8, 1.27/246/$15, 1.59/422/$27. Total about $112, and about 1,768 lead calls including two tiny sessions.
- Time went on reading reports and diffs and on `/ai-dlc-update` polling, for example 20 `sleep` loops (21 min) in 17d27721. The lead is a local model, so API dollars are $0.

## B. Tools, scripts, hooks (s323)

**B1. Subagent Bash, flagged ≥0.2 h** (published reader; calls, h, s/call for s321 | s322 | s323):

| Family | s321 | s322 | s323 |
|---|---|---|---|
| `wait-for-deliverable.sh` | 925, 0.35, 1 | 502, 0.91, 7 | **1,069, 9.80, 33** |
| pytest (3 spellings) | 1,109, 2.33 | 742, 0.50 | 847, 3.41 |
| `validate-spawn-ledger.sh` | 76, 0.88, 42 | 35, 0.34, 35 | 69, 0.93, **48** |
| `sleep` | 69, 0.28, 15 | 34, 0.01, 1 | 77, 0.78, **36** |
| `validate-mutation-red.sh` | 1,010, 3.08, 11 | 177, 0.29, 6 | 401, 0.49, 4 |
| `npx vitest` | | | 67, 0.48, 26 |
| `aws` | 216, 0.11, 2 | 27, 0.05, 6 | 67, 0.38, **20** |
| `validate-artifact-derivations.sh` | 1,359, 0.55 | 514, 0.18 | 651, 0.35, 2 |

- Paired totals: sub Bash ok 19.79 h (s322 4.71 h); errored calls separately 707 calls, 1.21 h. Lead ok 4.33 h, errors 277 calls, 0.12 h.
- The one large error is a 2,948 s permission wait (see B4).
- Lead families ≥0.2 h: `sleep` 0.49 h (23 s/call, up from 12), `gate-transition.sh` 0.48 h (141 calls, 12 s), `git push` 0.47 h (28 s, down from 57), `snapshot-update.sh` 0.40 h.
- Pytest launches: 977 commands in total, of which 177 are full-suite (about 10 per story across seats) and about 720 targeted. Targeted runs have a median of 2.8 s. Full-suite foreground time is 1.06 h in the 25 runs ≥60 s. Targeted runs are already the norm.
- Absences with a control (pytest, same filter: 977 calls): docker 7 calls, ruff 3, mypy/pyright 0, eslint/tsc 0, shellcheck 0, `ci-local.sh` 104 calls and 0.03 h. None is a cost.
- `test-pytest-admission.sh` ran 53 times (0.38 h) in s322 and 0 times in s323.

**B2. Findings**
- **BLOCKER (consumer-side, engine can help): pytest admission queueing.**
  - Evidence: 303 distinct predicate readings, 193 REFUSED, all on 11-18 and 11-19. The predicate needs 26.0 GiB (8 workers × 1.25 + 16) against a median headroom of 24.0 GiB (min 15.64).
  - 81 units contain refusal text. In them the wait/sleep time is 7.0 agent-h, of which `wait-for-deliverable` is 6.8 h and pytest 1.35 h.
  - Worst cases: QA 3.1 pass 2 (290 min, 45 refusals, 38 retry attempts) and dev-escalated 1.1 rework (323 min, 21 refusals).
  - Not just concurrency: 37% of refusals (71 of 193) had ≤3 agents running, so the box is short of memory (cause not identified; the local MLX lead is one possible holder, not verified).
  - Serial path: 6.07 of the 9.08 h `wait-for-deliverable` time had ≤3 agents running, so a large share is a straggler tail.
  - Upper bound 7.0 agent-h per sprint. Wall clock is less, probably 1–3 h of straggler tails (uncertain); I did not trace the join.
  - Fix, graph: `docs/coding-conventions.md:868`, `scripts/pytest-admission.conf`, `scripts/pytest-footprint-watchdog.py` (a lower worker count or lower per-worker footprint, so 26 GiB fits). Engine: replace N agents polling with one suite queue.
- **DEFECT (engine): spawn-ledger validator run per shard.** `validate-spawn-ledger.sh` is run by `gate-adjudicator` shards (68 runs, 0.92 agent-h, median 50 s, p90 75 s; s322 was 36 s per call). Only 0.14 h is solo, so it is mostly parallel per gate. The command is in `core/skills/ai-dlc/steps/gate-validation.md:1979`. Making it incremental or lead-run once per gate could remove up to 0.9 agent-h and about 1 min per gate. Confidence medium.
- **DEFECT (engine): dispatch-guard denials.** `core/hooks/ai-dlc-dispatch-guard.sh:1800` denies a brief with no `Deliverable:` line. The denied turns carry briefs a local model regenerates. Rendering that line into the dispatch template, or auto-adding it, would remove the loop. Upper bound 0.66 h of lead generation per sprint across 96 distinct denied turns; 211 of 1,033 Agent calls denied (s322: 62 of 593).
- **NOTE.** `git push`: 66 pushes, 40 backgrounded, 26 foreground at 0.45 h. 9 were ≥30 s and carry all of it. The consumer pre-push is graph's `.githooks/pre-push` (4,100 lines). It did not run a fixture suite on every push in what I could see, but I could not see inside the 453 s retro push. Batching is not a clear win; the retro pushes are the lever.
- **NOTE.** `git commit` 0.3 h combined, `git worktree` 0.22 h in subagents. No action.
- **NOTE.** `Stop` hook blocks: 69 in s323 (79 in s322), 12 min to the next record.

**B3. Hooks** (`hooks.jsonl`, s323)
- Recorded hook time is 0.124 h in total, with ms/call as measured: `ai-dlc-recover.sh` SessionStart 975 ms × 134 = 131 s; context-sensor 203 ms × 584 = 119 s; dispatch-guard 404 ms × 185 = 75 s; `claude-code` PostToolUse 96 ms × 620 = 59 s.
- None exceeds 0.04 h. Three exceed 200 ms per call: `recover.sh`, `dispatch-guard`, context-sensor.
- Limit: only hooks that emit a `durationMs` attachment are recorded. Whole-call floor is 0.18–0.21 s median for trivial Bash calls, so hooks plus harness are at most about 0.2 s per call.
- Denials: 329 blocking errors, 259 of them PostToolUse `derivation-capture` on subagents. Those are feedback, not retried calls. The retry loops are the dispatch denials above.

**B4. Harness waits**
- **DEFECT:** one permission prompt held an adversary shard (stories-test-strategy, Adversary shard 06) for 2,947 s (49 min) on `rm -f $S/$d/conftest.py … printf > pytest.ini` in a scratchpad. Other shards finished by 08:46 and it ran to 09:33, so about 0.8 h of straggler tail (the lead was probably waiting; not verified). Allowing scratchpad `rm` in the settings, or auto-denying after a timeout, fixes it. The engine's `templates/settings.json.template` has no permission rules or `PermissionRequest` hook (grep control: 0 hits in core and templates).
- Other waits: the rate-limit errors above (44 subagent errors, about 0.5 agent-h), 2 `Prompt is too long`, 7 litellm errors on the lead.

**B5. CI:** none on the path. No GitHub Actions; the pre-push hook is the gate. `gh` total 0.058 h (1 `pr checks` call). Skip.

## Looked at and found efficient
Session starts (≤17 min each), hooks, targeted pytest runs, `validate-mutation-red.sh` (down to 4 s/call), `gh`/CI, `git commit`.

Not measured: the true duration of the 40 backgrounded pushes and 47 backgrounded full-suite runs, the 453 s push's hook steps, and who holds the memory behind the admission refusals.

## SENT 2026-11-20T10:51:24.605Z | Part 1: rest of A1 and A2

PART 1 of 4 (rest of A1, then A2). Method: my paired reader is in /private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/hand-s323late/ (scan.py, fam.py, buckets.py). Control: its s322/s323 Bash counts equal tools.csv exactly (lead 6,718 and 8,009; sub 25,317 for s323). Backgrounded calls charge about 0 s, so they are invisible in latency.

A1 (rest). Lead calls in session 64926214, minutes of model turn plus tool time (turn = model time before the call, capped 300 s):

| Bucket | Sprint-review window (12:48-20:17Z, 1,402 calls) | Deploy-validate (1,146 calls) | Retro (639 calls) |
|---|---|---|---|
| read/inspect shell (sed, grep, tail, cat) | 86 min (206 calls) | 75 (280) | 10 (88) |
| Read tool | 32 (243) | 30 (119) | 23 (119) |
| ctx_execute | 31 (87) | 19 (128) | 15 (69) |
| snapshot bookkeeping | 38 (213) | 21 (131) | 14 (68) |
| gate/validator scripts | 26 (111) | 0 | 19 (36) |
| operator asks (tool wait) | 73 (3) | 31 (7) | 0 |
| advisor | 17 (28) | 17 (36) | 7 (12) |
| dispatch (Agent, SendMessage) | 26 (155) | 5 (22) | 7 (40) |
| git other | 28 (78) | 7 (46) | 12 (26) |
| git add/commit | 9 (21) | 3 (24) | 2 (11) |
| git push | 0.4 (4) | 1.6 (18) | 13.4 (5) |
| edit/write | 9 (52) | 13 (78) | 17 (49) |
| aws/curl ops | 0 | 10 (55) | 0 |

Tool latency is a small share. Bash tool time is about 13 min of 7.5 h in sprint-review and about 13 min of 5.3 h in deploy-validate; the rest is model turns of about 7-25 s each (local lead).

Class totals for the lead, s321 / s322 / s323 (active h, step = sprint-review incl. gate): s321 2.94, s322 1.66, s323 5.65. s323 sprint-review classes: other 2.10 h, idle-wait 1.30, merge (reading agent outputs) 0.86, snapshot 0.53, compaction-recovery 0.23, dispatch 0.21, gate-run 0.17, repair 0.14, step-reread 0.10.

Why sprint-review was 4x longer (decomposition of lead-active):
1. DEFECT, sprint-specific scope plus a pipeline hole: the sprint held stories 2.1, 2.2, 2.3 as "operator-held" with no operator quote (the lead's own AskUserQuestion at 04:29Z says "that label has no operator quote anywhere"). The operator answered "Build all three now", so windows A, B, C (12:48-17:23Z) rebuilt and gated them inside sprint-review: about 3.4 h of lead-active (1.01 + 1.84 + 0.58). About 0.95 h of that is labelled `implementation` / `gate-validation[implementation]` in the roll, so the sprint-review-labelled 5.65 h understates it. An implementation-exit check that any "held" story carries an operator quote would surface this before sprint-review. Confidence high on the timeline; the check is my suggestion.
2. Per-story seat panel (window D, about 60 seats at 17:43-17:52Z) plus follow-up fixes: 1.0 h, comparable to s321. s323 spawned 158 sprint-review agents for 18 stories (8.8 per story, 16.2 agent-h) against s321's 165 for 25 (6.6 per story, 13.8 agent-h).
3. Gate[sprint-review] (window F): 0.95 h. 4 adjudicator shards, shard 1 reported Check 1 FAIL (a QA verdict line reading APPROVED outside the QA set, and an open-MAJOR sibling file sprint-adversarial-p2.md), 2 remediators, then 4 shards re-run at 19:55Z.
4. The first session (53b4296a) contributed 1.17 h: 2 sprint adversary passes, 2 merge-resolution devs (1.3 and 5.2), re-reviews, full suites on merged HEAD.
5. NOTE: 44 "Server is temporarily limiting requests" API errors hit the seat wave at 17:47Z; each retried in about 80 s, so about 0.02 h wall.

"Sprint 323: per-chain consolidation" (graph PR #1337, merged 15:46 EDT = 20:46Z) is SPRINT-SPECIFIC naming. It is the sprint-wide squash PR of the whole sprint branch ai-dlc/carry-over/s323-per-chain-consolidation; graph's own retro-artifacts call "per-chain consolidation / Epic 5" a graph initiative with no epic file. The PR step itself is pipeline structure, not extra work. PR #1338 (mTLS fix-forward, merged 19:32 EDT = 00:32Z 11-20) and the retro PR #1339 are separate.

Deploy-validate timeline (lead active 4.0 h of 5.3 h wall; operator asks 31 min, marked):
- 20:17-21:06Z, 0.47 h: PR #1337 merge at 20:46Z, pre-roll ops reads (ops agent 20:49, 21:06).
- 21:06-22:17Z, 1.18 h: roll, post-roll ops reads (4 ops agents), allowlist PUT operator-fired (3 asks 21:40-21:51, about 9 min), a UI cache-reload confusion.
- 22:17-23:19Z, 0.85 h: full smoke run (SMOKE_RC=0), visual-verification ask 905 s, OPS AC3/values reads.
- 23:19-01:06Z, 1.36 h: operator ask about APP_ENV=prod fire (396 s), mTLS gate defect ("ff1": gate reads VERIFY-mode headers the ALB injects), dev-escalated fix 23:58Z, review 00:06Z, PR #1338, re-roll with ops reads 00:32 and 01:06Z. This fix-forward is sprint-specific.
- 01:06-01:36Z, 0.15 h: tail.
Lead ran alone except for ops/dev agents: only 14 spawns, 1.3 agent-h.

Retro timeline (2.0 h + gate[retro] 0.64 h lead-active; 2.7 h wall):
- 01:36-01:46Z: retro.md read, a self-written retro-step1.sh / retro-step1-combined.sh (branch cut), 6 party seats (01:40Z), analyst "classify party findings".
- 01:48-02:00Z: 7 analyst draft surfaces dispatched in two batches (01:48:10 and 01:48:33), then 3 close-out analysts (deferrals, sweep match, audits) at 01:59Z.
- 02:00-02:26Z: lead hand-edits graph files (ecs-deploy.sh rollout poll via dev agent, coding-conventions.md, .gitignore, push-candidate-ledger.md, escalations/pending.md, carry-over-backlog.md entry by entry; 4 mass-reclass edits at 02:12-02:13Z). Dev "bright-line reclass fixes" at 02:26Z.
- 02:50-03:25Z: gate[retro]: 3 adjudicator shards x2.
- 03:25-04:17Z: rotate, audit-anchor backfill, retro PR push 03:45Z (453 s foreground), push to main 03:55Z (132 s) and 04:00Z (180 s), 7b next-inputs: 6 analyst inputs at 04:04-04:09Z (waits of 5-15 min each).
Pushes in retro: 5 foreground, 770 s total on the critical path.

A2. Fixed procedures a script could run end to end (lead turn plus tool minutes in 64926214, SR window + deploy-validate + retro):
- snapshot-update.sh and the follow-on git add/commit of pipeline-snapshot.md: 38+21+14 min = 73 min, plus commits 9+3+2 min.
- wait-for-deliverable / TaskStop / poll / Monitor: 8+1+6 min plus about 14 min of stop/poll turns = about 20 min.
- gate-checkpoint/gate-transition/verdict/validate-* scripts: 26+0+19 = 45 min.
- push: 0.4+1.6+13.4 = 15 min (hook time, not model).
- Sum about 181 min = 3.0 h. UPPER BOUND 3.0 h; realistic reach 1.5-2 h (some of each phase's script calls are judgement-bearing).

Repeated command sequences (from the lead's 1,802 Bash calls across SR+DV+retro; 550 call a scripts/ai-dlc script):
- scripts/ai-dlc/snapshot-update.sh: 324 invocations in 64926214 over these phases (382 s tool time); across the 5 pipeline leads 975 invocations, 3.31 h of lead turns. 280 of them immediately follow another snapshot-update call (0.86 h of turns): that is 143 triples of three consecutive calls in one stretch. Batching these into one call is reachable now: the script already takes many operations per call (core/scripts/snapshot-update.sh:2, "one call carries every change of ..."; its flag loop at lines 269-303 takes --row-status, --set, --line-add, --line-replace, --key-delete, ... repeatedly). So the 0.86 h is lead habit, not a missing feature. UPPER BOUND 0.86 h per sprint; confidence medium-high.
- gate-checkpoint.sh 93 calls (138 s), verdict.sh 52 (218 s), gate-transition.sh 13 here (133 s), validate-* scripts about 100 calls: each gate runs a fixed list of arms one call at a time. A single gate-arms runner would remove the turns between them (the 31 consecutive gate-checkpoint triples).
- wait-for-deliverable.sh 116 calls here (45 s tool time): beat arming, plus ps/pgrep checks for the beat ("ps aux | grep -c wait-for-d", pgrep 'git push').
- Retro: the lead authored 38 script/heredoc calls and 9 scratchpad scripts (retro-step1.sh, retro-step1-combined.sh, s323-backlog-archive.sh, s323-5c-trim.sh, s323-5c-trim2.sh, 7d-snapshot.sh, 7d-snapshot2.sh, s323-escal... , Nd-snaps...). The engine step file has 1,740 lines but only 8 fenced blocks (170 lines; one 96-line block at core/skills/ai-dlc/steps/retro.md:25 and one 27-line block at :1680). deploy-validate.md is 770 lines with 5 blocks (93 lines; one 68-line block at :508). The procedures (4a close-out sweep, 4b rotation, 5b audit-anchor, 5c pre-commit validation gate, 6 commit/push/PR, 7a merge) are prose the model re-derives each sprint.
- Deploy-validate is mostly NOT scriptable: its remaining calls are ops (aws ecs describe-services 9, list-tasks 3, smoke test 4, curl) and operator-driven; I would not count more than the 45-60 min of bookkeeping, waits and gate scripts above.

Continues in PART 2 (A3, A4).

## SENT 2026-11-20T10:51:40.459Z | Part 2: A3 and A4

PART 2 of 4 (A3, A4).

A3. Session start, resume and post-compaction overhead (s323 pipeline leads: 0ef7ba46, 68cf8de7, 4b34031d, 53b4296a, 64926214; idle time between sessions excluded).

Start to first Agent dispatch, first record to first dispatch: 5 min (36 calls before it), 5 min (33), 13 min (93), 17 min (71), 7 min (46) = 47 min over 5 sessions, about 1.6% of the 48.6 h lead-active. Calls before first dispatch are reads and snapshot ops:
- route.md read 3-5 times in slices in every session (the context-mode hook denies a whole-file read over its one-read limit; the file is 51 KB), route-domain.md and route-push.md in 68cf8de7, pipeline-snapshot.md 2-3 times (21.7 KB), then the step file 3-4 times (requirements.md, carry-over-evaluation.md, architecture.md, sprint-review.md, implementation.md), plus gate-validation.md / _gate-procedures.md in 53b4296a.
- The same text is re-read every session and after every compaction. Sizes in graph's installed copy: SKILL.md 70 KB, route.md 51 KB, implementation.md 52 KB, requirements.md 28 KB, stories-test-strategy.md 51 KB, deploy-validate.md 45 KB, retro.md 100 KB, _gate-procedures.md 148 KB, gate-validation.md 246 KB, postcompact-digest.md 27 KB. I did not count tokens per re-read; at a rough 4 bytes per token a gate-state recovery is tens of thousands of tokens.

Post-compaction (the recurring cost): 134 compactions in s323.
- Pipeline leads: compaction-recovery 1.88 h (563 calls) + step-reread 1.69 h (684 calls) = 3.57 h, 7.3% of 48.6 h lead-active, about 96 s per compaction, about 5 re-read calls each. (All lead units, including update sessions: 2.17 + 1.69 h.)
- Same two classes: s322 0.82 + 0.91 = 1.73 h of 42.4 h (4.1%); s321 0.27 + 0.49 = 0.76 h of 56.4 h (1.3%). Compactions per elapsed hour: 0.51, 1.08, 1.78.
- Example text: after a compaction the lead writes "RECOVERY ACK -- post-compact recovery, 4th. Current step file: sprint-review.md ..." and the post-compact hook denies the next dispatches until a postcompact-digest read is done (40 denied Agent calls, see denial table in PART 3).
- UPPER BOUND 3.57 h per sprint (lead wall, serial: the lead is the only seat in these turns). A smaller or digest-only recovery read is the lever; the compaction rate itself is likely the bigger lever (another hand's subject).
- Confidence: high on hours (class totals from classes.jsonl, verified for s323 pipeline units), medium on "5 reads per compaction" (684 / 134).

A4. The /ai-dlc-update reconcile sessions in s323.

They are NOT in the 75.4 h. Control: steps.csv sums for s323 are pipeline 75.377 h elapsed / 48.628 h active; ai-dlc-update 16.419 h elapsed / 8.117 h active; other 0.091 h. The roll's 75.4 h is the pipeline bucket only.

There were 8 sessions (plus 2 tiny ones, 1707a60b and a12082e9), not the 0.1101 -> 0.1160 -> 0.1164 chain in the brief. Branch names in each transcript show these pulls: 0.1128.0, 0.1142.0, 0.1143.0, 0.1152.0, 0.1157.0, 0.1160.0, 0.1164.0, and 0.1174.0 (which also handled 0.1167.0).

| Session | Window (UTC) | Active | Op wait | Agent wait | Calls | Compactions | Token-eq $ (sonnet list, lead) |
|---|---|---|---|---|---|---|---|
| 0e678bad (0.1128) | 11-14 13:51-16:51 | 0.81 h | 0.79 | 1.39 | 148 | 1 | $11 |
| f7ff0ac0 (0.1142) | 11-15 22:14-00:13 | 1.04 | 0.58 | 0.37 | 220 | 2 | $12 |
| 4104f33b (0.1143) | 11-16 13:07-14:32 | 1.11 | 0.00 | 0.31 | 188 | 1 | $13 |
| cd192a5a (0.1152) | 11-16 14:50-16:17 | 0.79 | 0.44 | 0.23 | 178 | 2 | $12 |
| 0604f29f (0.1157) | 11-16 17:24-19:09 | 0.90 | 0.27 | 0.58 | 241 | 2 | $14 |
| f8934707 (0.1160) | 11-16 22:06-23:03 | 0.60 | 0.00 | 0.35 | 108 | 2 | $8 |
| 17d27721 (0.1164) | 11-18 00:41-02:06 | 1.27 | 0.14 | 0.00 | 246 | 2 | $15 |
| 70834da1 (0.1174, 0.1167) | 11-19 07:58-12:25 | 1.59 | 2.44 | 0.42 | 422 | 4 | $27 |

Totals: 8.1 h lead-active, 16.4 h elapsed, 1,768 lead calls (including the 2 tiny sessions), about $112 token-eq at hosted sonnet list price (API $0, local lead), 10 spawns costing about $2. Hosted-price figure is my own estimate, not the roll's fallback mix.

What they spent time on: lead model turns, not tools. Mix per session (tool counts): Bash 75-309, ctx_execute 6-71, Read 9-53, Edit/Write a handful; Bash families are cat, grep, ls, git diff, git push, dist-clone.sh, emit-report.sh, awk. The only tool-time items: 17d27721 had 20 sleep loops (1,263 s, 21 min polling) and 70834da1 had 20 awk calls (124 s) and one 7,758 s AskUserQuestion (operator wait, marked); 0e678bad had a 1,300 s operator ask. So each pull costs about 1 h of lead-active turns for reading the delivery report/diff and writing the reconcile PR, with one pull per 1-2 sprint hours of elapsed time on 11-16. Eight pulls in one sprint is the repeated cost; fewer, batched engine deliveries would remove whole sessions (that is a distribution-cadence decision, not a defect in a session).

Continues in PART 3 (section B).

## SENT 2026-11-20T10:52:05.110Z | Part 3: section B measurements

PART 3 of 4 (section B).

B1. Bash by family. Paired reader (tool_use paired with tool_result by id, errored calls reported separately). Paired totals: s323 sub Bash ok 19.79 h, 24,610 calls (s322: 4.71 h, 15,498 calls); errors 707 calls 1.21 h. s323 lead ok 4.33 h, 7,732 calls (s322 3.14 h); errors 277 calls 0.12 h. The published bash_by_sprint.py (unpaired, run at top-80) gives s323 sub 21.0 h, lead 4.5 h; s322 sub 5.1 h, lead 3.5 h; s321 sub 16.2 h, lead 6.1 h. Paired family key = first non-trivial command, so a compound command is charged to its first program; published reader keys on the first regex match anywhere. Where they disagree I give both.

Subagents (families >= 0.2 h in any of s321/s322/s323, published reader: calls, h, s/call):
- wait-for-deliverable.sh: s321 925, 0.35 h, 1 s | s322 502, 0.91, 7 | s323 1,069, 9.80, 33. Paired s323: 935 ok calls 9.08 h, 35 s/call (s322 386 ok, 0.49 h, 4.6 s). FLAG both on hours and on s/call.
- pytest (three spellings pytest, python3 -m pytest, python -m pytest): s321 1,109 calls 2.33 h | s322 742, 0.50 | s323 847, 3.41. s/call: 4/9/11 -> 2/6/6 -> 14/21/9. FLAG.
- validate-spawn-ledger.sh: 76, 0.88, 42 s | 35, 0.34, 35 | 69, 0.93, 48. FLAG s/call rose.
- sleep: 69, 0.28, 15 | 34, 0.01, 1 | 77, 0.78, 36. FLAG.
- validate-mutation-red.sh: 1,010, 3.08, 11 | 177, 0.29, 6 | 401, 0.49, 4. falling.
- npx vitest: 28, 0.08 | 0 | 67, 0.48, 26. NEW >= 0.2.
- aws: 216, 0.11, 2 | 27, 0.05, 6 | 67, 0.38, 20. FLAG s/call up; 12 calls of aws logs filter-log-events at 110 s each = 0.37 h (s322: 3 calls, 47 s).
- validate-artifact-derivations.sh: 1,359, 0.55 | 514, 0.18 | 651, 0.35, 2 s.
- git (bare), git diff, git worktree, grep, cd, sed: 0.1-1.2 h each in s321, 0.1-0.6 h in s323; per call 0-8 s, no change worth flagging.
- Also under 0.2 h in s323: until 96 calls 0.18 h, git status 0.15, git commit 0.13, validate-handoff-evidence 0.09.

Lead (published reader, s321 | s322 | s323): sleep 71, 0.59 h, 30 s | 64, 0.22, 12 | 77, 0.49, 23 (FLAG s/call up vs s322); gate-transition.sh 149, 0.42, 10 | 69, 0.30, 16 | 141, 0.48, 12; git push 39, 0.40, 37 | 48, 0.76, 57 | 61, 0.47, 28; snapshot-update.sh 756, 0.69 | 1,057, 0.36 | 938, 0.40, 2 s; cd (first-token artifact of "cd X && ...") 0.11 | 0.03 | 0.20; wait-for-deliverable.sh 922, 0.30 | 460, 0.21 | 518, 0.14; gh 0.15 | 0.06 | 0.04.

Serial-path join (spawn intervals, midpoint concurrency, s323 sub Bash ok only): of 19.79 h, 2.14 h ran with <= 1 agent alive and 10.55 h with <= 3 agents alive. For wait-for-deliverable.sh: 9.08 h total, 0.38 h solo, 6.07 h with <= 3 agents; pytest 1.97 h, 0.34 solo, 0.70 narrow; validate-spawn-ledger 0.92 h, 0.14 solo, 0.39 narrow; sleep 1.53 h, 0.13 solo, 1.06 narrow. So the wait time is mostly tails (few agents left), not parallel waste. Wall-clock conversion is not exact: a narrow tail is not necessarily on the lead's critical path.

Who holds the wait-for-deliverable time (paired, s323 sub): qa 5.58 h (213 calls), general-purpose 1.04 h (26; round dispatchers, legitimate beats), dev-escalated 1.04 (40), code-reviewer 0.57 (50), dev 0.54 (55), everything else <= 0.16 h; by step: gate-validation[implementation] 6.2 h, implementation 1.35, stories-test-strategy 0.97. Latencies are bimodal: median 1.2 s, p75 3.4 s, then p90 180.5 s (the 180 s foreground cap): 958 calls, 0 above 600 s. 

Full-suite and test runs by seat: 177 full-suite launches (47 backgrounded, 130 foreground; foreground ok n=109: median 2.3 s, p90 157 s, 25 runs >= 60 s totalling 1.06 h). Role split of full-suite calls: dev-escalated 49 (0.70 h), dev 51 (0.28), qa 45 (0.15), code-reviewer-escalated 26 (0.09). About 160 ok full runs over 16 story ids (e.g. 1.1: 27, 2.3: 19, 3.2: 15, 3.4: 15, 1.4: 10) = about 10 per story across seats; wrapped-by-watchdog 90 calls (17 errored), bare 91. Targeted runs: 724 launches, foreground 672 with median 2.8 s, 1.71 h total. So narrower runs are already the norm; the long ones are the contractual honest-green run (graph docs/coding-conventions.md:868 "Suite-Launch Admission and Watchdog").

Absences with control (same filter, pytest must be > 0): pytest 977 calls 3.77 h; docker/compose 7 calls 0.00 h; ruff 3; mypy/pyright 0; eslint/tsc 0; shellcheck 0; ci-local.sh 104 calls 0.03 h; npm/vitest/jest 160 calls 0.73 h. Linters and type checkers are not a cost.

test-pytest-admission.sh: s322 53 calls 0.38 h (26 s/call); s323 0 calls. In s323 the admission is inside the watchdog (graph scripts/pytest-footprint-watchdog.py; ci-local.sh has check_pytest_admission at scripts/ci-local.sh:1290).

B2 specific scripts. gate-transition.sh lead 92 ok calls 0.39 h (p50 2.2 s, p90 62 s, max 121 s): a few gate transitions are the long ones. snapshot-update.sh lead 629 ok calls 0.24 h tool time (p50 0.6 s) but 975 turns (3.31 h). wait-for-deliverable lead 447 calls 0.09 h (0.7 s). validate-spawn-ledger.sh is run only by gate-adjudicator shards (68 calls). validate-mutation-red.sh by qa 150 (0.17 h), dev-escalated 52, code-reviewer-escalated 59, code-reviewer 42, dev 6. gh: 32 calls total 0.058 h (pr view 19, create 15, merge 15, auth status 7, edit 5, checks 1).

Push and commit. s323 lead pushes 66 (40 backgrounded, 26 foreground, 0.45 h; 9 foreground >= 30 s hold all of it). s322: 57 pushes, 20 bg, 37 fg 0.80 h, 13 >= 30 s. No subagent ran git push (0 of 70 in the scan). Longest: retro PR push 453 s (03:45Z), 11-13 pushes of 251, 166, 160 s, main pushes 180 s and 132 s, 94 and 86 s. Pre-push is graph's .githooks/pre-push (4,100 lines, via .git/hooks/pre-push shim; pre-commit shim .git/hooks/pre-commit 20 lines) and its output on green pushes reads "== extensions == == step references == ... pre-push: all gates green." Backgrounded pushes return in about 1 s, so their real wall (the time before the lead reads PUSH_RC) is not in these figures. I could not see which hook steps took the 453 s push because the stored result is a 206-char compressed note. git commit: sub 99 calls 0.13 h (5 s), lead 227 calls 0.17 h (3 s). Pre-commit is the pre-commit framework (gitleaks); no evidence it is slow.

B3 hooks (hooks.jsonl, s323; only hooks with a durationMs attachment are recorded, so this is a floor):
- Total recorded hook time: 0.124 h (7.4 min) for lead plus sub.
- Per hook (events, ms per call, total): ai-dlc-recover.sh SessionStart 134 lead + 4 sub, 975 ms, 131 s; ai-dlc-context-sensor.sh PostToolBatch 584, 203 ms, 119 s; ai-dlc-dispatch-guard.sh PreToolUse 185, 404 ms, 75 s; claude-code PostToolUse 620 lead + 125 sub, 96 ms, 59 s plus 10 s; ai-dlc-rules-floor.sh SessionStart 166, 160 ms, 27 s; post_tool_hook.py 221, 35 ms; context-sensor Stop 30, 180 ms; title-from-handle.sh 14, 158 ms; others negligible.
- Over 200 ms per call: recover.sh (975), dispatch-guard (404), context-sensor PostToolBatch (203). None above 0.04 h per sprint, so none meets the 0.2 h bar.
- No hook runs on every tool call with a recorded cost above 0.04 h. Whole-call floor: p50 latency of trivial Bash (cat/ls/grep/sed/echo) is 0.24 s lead and 0.18 s sub in s323 (s322 0.21 and 0.18); 21,236 sub calls finish under 1 s totalling 1.5 h. That bounds hook plus harness overhead at about 0.2 s per call, 2.5 h agent-time upper bound over about 50,000 tool calls; not a lever.
- Denials (hook_blocking_error attachments, s323 329): sub PostToolUse 257 (259 of the messages name ai-dlc-derivation-capture.sh; these are post-hoc feedback, not a retried call), lead Stop 69, lead PostToolUse 3. Stop blocks: 69 events (s322: 79), median 3.1 s to the next assistant record, 12 min total, plus the wasted turn: NOTE.

Continues in PART 4 (denied Agent calls, rate limits, CI, ranked changes).

## SENT 2026-11-20T10:52:29.175Z | Part 4: denials, API, CI, ranked changes

PART 4 of 4 (denied Agent calls, harness waits, CI, ranked changes).

Denied or errored lead Agent calls, s323: 211 of 1,033 (20%); s322: 62 of 593 (10%). By reason (all lead sessions in the window, my classifier on tool_result text):
- 131: dispatch guard, brief carries no `Deliverable: <path>` line (gate-adjudicator 39+16, remediator 25+2, analyst 5, code-reviewer 4, qa 1, adversary 1 and others). Source: core/hooks/ai-dlc-dispatch-guard.sh:1800 (the dg_deny text for the missing line).
- 40: post-compact recovery owed ("SKILL.md Rule N touchpoint R is owed. You read postcompact-..."; includes 12 shown as "PreToolUse:Agent hook error").
- 10: "Concurrent subagent limit reached ... Do not retry".
- 10: other dispatch-guard refusals (gate-plan line, --mark grammar at ai-dlc-dispatch-guard.sh:1739, and similar).
- 3: InputValidationError; 1: pipeline paused (operator message outstanding).
Cost: those denials fall on 96 distinct lead turns (parallel calls share a turn). Model-generation time before them, capped at 300 s per turn, totals 0.66 h per sprint. That is an UPPER BOUND on lead wall lost; a denied turn's resend also repeats the brief tokens. Example from 64926214 at 19:37Z: "Guard wants the `Deliverable:` line -- re-sending all four with it". Same pattern at 12:51:33 -> 12:51:44Z (dev seats 2.1, 2.2, reviewer). Confidence high on counts, medium on hours.

Harness-level waits.
- Permission prompt stall (DEFECT): subagent adversary "Adversary shard 06" (stories-test-strategy, 11-18 08:44Z) issued `S=.../scratchpad/exp; for d in base patched; do rm -f $S/$d/conftest.py $S/$d/shared; printf ... > $S/$d/pytest.ini; done; ls $S/base`; the tool result came back 2,947 s later as "The user doesn't want to proceed with this tool use. The tool use was rejected" (toolDenialKind user-rejected, toolDenialBeforeRun true). The other 17-18 adversary shards finished 08:43-08:46Z and shard 06 ended 09:33Z, so the round carried a 49-minute straggler tail (about 0.8 h wall; the join consumer being the lead is probable, not verified). Only one such stall in s323 (5 permission-style rejections in all: this one 2,947 s, a lead ask 1,300 s, 3 short). core templates have no permission rules or PermissionRequest hook: `grep -rln PermissionRequest core templates` returned nothing (control: templates/settings.json.template exists and was searched). Fix: allow scratchpad `rm -f` in the shipped settings and auto-deny any permission prompt in an unattended subagent after a short timeout. UPPER BOUND 0.82 h wall for this sprint; it is a single instance.
- API errors and rate limits: s323 has 51 error records (44 subagent "API Error: Server is temporarily limiting requests (not your usage limit)", all at 17:47Z 11-19 during the 60-seat sprint-review wave; 2 `Prompt is too long ... automatic compaction failed`; 2 litellm BadRequestError; 7 lead-side). The gap from each error to the next record is median 77 s, total 31.5 min over 48 units, of which one lead gap is 1,253 s (11-14 15:26Z, an update session; unrelated to the wave). For the wave: about 80 s per seat, parallel, so about 0.02 h wall, 0.4 agent-h. No retry-with-backoff records exist in the schema; the 80 s is inferred from the gap. Not a lever.
- CI: no waits. No GitHub Actions in the pipeline path ("WHY NOT GITHUB ACTIONS. Operator policy: no CI in GitHub" is in graph's .githooks/pre-push header). One `gh pr checks` call; zero --watch / actions/runs strings in 55,888 scanned Bash commands (s322+s323). gh total 0.058 h (32 calls). The gate is local (pre-push). Total CI wait in s323: about 0.

RANKED CHANGES (hours are per sprint; "wall" = clock, "agent-h" = summed agent time; UPPER BOUND marked)

1. Suite admission queue (graph-side policy plus engine-side queue). Subagents waiting on refused pytest admission: 7.0 agent-h in 81 units (UPPER BOUND; pytest 1.35 h inside), 6.8 h of it `wait-for-deliverable.sh` polling; two units alone 290 and 323 min. Wall effect: the long units were tails with <= 3 agents alive for 6.07 of the 9.08 h wait; 71 of 193 refusals had <= 3 agents alive, so this is box memory (predicate 8 x 1.25 + 16 = 26.0 GiB against median headroom 24.0 GiB, min 15.64, over 303 readings) rather than agent count. Wall clock not traced; I estimate 1-3 h of straggler tail, low confidence. Fix: graph owns docs/coding-conventions.md:868 and scripts/pytest-admission.conf (cap n or footprint so one run fits in typical headroom; find what else holds memory, local model unverified). Engine: a single-flight suite slot (queue with a ticket and one wake-up) instead of N agents each polling; wait-for-deliverable.sh already exists as the wait primitive. Note: all readings are on 11-18 and 11-19, so the predicate arrived in this sprint; s322 had no admission waits (0.91 h total wait-for-deliverable).
2. Dispatch-guard `Deliverable:` denials (engine). core/hooks/ai-dlc-dispatch-guard.sh:1800: render or auto-supply the line (the guard already knows the shard path from the brief) or have the dispatch template emit it. UPPER BOUND 0.66 h lead wall; 131 denials. Also 40 post-compact-recovery denials (guard asks for a digest read first): fold into the recovery read instead of a deny.
3. Post-compaction re-read (engine). 3.57 h lead-active (compaction-recovery 1.88 + step-reread 1.69), 7.3% of lead-active, 96 s per compaction; rises with compaction rate (1.78 per elapsed hour). UPPER BOUND 3.57 h. Lever: smaller recovery read (digest only), and fewer compactions (another hand).
4. Batch snapshot writes (engine instruction, no new script): 280 back-to-back snapshot-update.sh calls = 0.86 h lead turns. UPPER BOUND 0.86 h. Cite core/scripts/snapshot-update.sh:2 (one call carries every change). Whole snapshot class is 3.57 h in s323 (s322 2.55 h, s321 6.43 h).
5. Late-step scripts (engine): a retro-close runner, a gate-arms runner, and a deploy-validate bookkeeping runner. UPPER BOUND 3.0 h of lead time in sprint-review (second session), deploy-validate and retro; realistic 1.5-2 h. Retro and deploy-validate procedures live as prose (core/skills/ai-dlc/steps/retro.md 1,740 lines with 8 fenced blocks; deploy-validate.md 770 lines with 5), and the lead wrote nine scratchpad scripts in s323 retro to cover them. Includes the 5 retro pushes at 770 s (13 min foreground).
6. validate-spawn-ledger.sh incremental or run once per gate by the lead (engine): core/skills/ai-dlc/steps/gate-validation.md:1979. 0.92 agent-h; wall at most about 1 min per gate, UPPER BOUND 0.9 h. The cost grows with the ledger (35 s s322, 48 s s323).
7. Permission-prompt stall (engine template/settings): one instance, UPPER BOUND 0.82 h wall.
8. Held-story label check at implementation exit (engine): "operator-held" with no operator quote cost about 3.4 h of lead time and the late build in sprint-review (sprint-specific occurrence; the check is my suggestion, not measured to catch other cases).

Found efficient or small (no change): hooks 0.124 h recorded and about 0.2 s per call floor; git commit 0.3 h; git push 0.45 h foreground (9 pushes; retro ones are the lever, covered in 5); CI 0; API rate limits 0.02 h wall; session start 47 min over 5 sessions; targeted pytest (median 2.8 s).

Not measured: real wall of the 40 backgrounded pushes and 47 backgrounded full-suite runs (they return in about 1 s); which pre-push steps took the 453 s retro push (stored result truncated); who holds the memory behind the refusals; the wall-clock share of the 7.0 agent-h in item 1.

All sources: transcripts under ~/.claude/projects/-Users-n8-git-graph/ and MONO/ files as listed in the brief; my scripts and outputs are in /private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/hand-s323late/ and its out/ directory.

