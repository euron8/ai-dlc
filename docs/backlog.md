# Carry-over backlog

Items this repo owes itself. An entry lives here when it is real, measured, and **not the
subject of any live plan** — the state that previously had no home, so it survived only by
being written into a plan about something else and vanished when that plan was discharged.

**This is the DISTRIBUTION's backlog, and it is not a push-candidate ledger.** A consumer's
`_bmad-output/ai-dlc-update/push-candidate-ledger.md` tracks what that consumer wants pushed
UPSTREAM to ai-dlc, and its receipts resolve against a pull's `theirs` ref with the verbs
`theirs_has` / `theirs_lacks`. This file tracks what ai-dlc owes ITSELF, its receipts resolve
against this working tree, and its verbs are `sh` / `has` / `lacks`. The two grammars are
mutually unreadable by each other's engine on purpose. Entry ids are `BL-`, never `PC-`.

**Read by** `scripts/backlog-reverify.sh`, which executes each entry's `verify:` receipt and
emits a status. **Rotated by** `scripts/backlog-rotate.sh`, which moves closed entries to
`docs/backlog.archive.md` — it moves, it never deletes. Neither ships; both are
distribution-only, as `core/fixtures/plan-shape/.dist-only` already is.

## Receipts

```
verify: sh <one-liner>              exit 0 = the fix is present -> CLOSE-CANDIDATE
                                    exit 9 = the receipt cannot measure its subject -> NEEDS-REVIEW
                                    any other non-zero = still reproduces -> STILL-LIVE
verify: has   <repo-rel-path> "<substr>"    close when the file CONTAINS the substring
verify: lacks <repo-rel-path> "<substr>"    close when the file LACKS it
verify: manual                      no mechanical predicate by design -> HAND-REVIEW
```

**Prefer `sh`.** The tree is right here and executable, which the consumer's ledger cannot
assume of the ref it greps. A receipt runs from the repo root with stdin closed, so it names
any input it reads as a file. A behavioural predicate asserts the defect itself and cannot be
anchored on prose the author invented to describe a wanted fix.

**THIS FILE'S `sh` POLARITY IS THE OPPOSITE OF THE CONSUMER LEDGER'S, AND THE TWO ARE WRITTEN
IN THE SAME SESSIONS.** Here, `scripts/backlog-reverify.sh:334-335` reads **exit 0 as "the fix
is present"** and non-zero as "still reproduces". In a consumer's push-candidate ledger,
`core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:2929` reads it the other way — **exit 0
means the entry STILL REPRODUCES**, and non-zero proposes CLOSE-CANDIDATE. Carrying this file's
rule into a consumer receipt writes a predicate that proposes closing a LIVE defect, which is
the one direction that loses data permanently. Check which file your receipt lands in before
you fix its polarity, and read the emitter rather than either header.

**In a consumer receipt, guard the unresolvable subject too.** A RENAMED subject also exits
non-zero there, so a relocation reads as an absorption that never happened; `[ -n "$s" ] ||
exit 127` makes it NEEDS-REVIEW instead. This file's engine needs no such guard, because its
non-zero direction is the one that keeps the entry open.

**When you must use `has`/`lacks`, anchor on a token the fix CANNOT BE WRITTEN WITHOUT** — a
flag, a path, a function name — never a phrase describing the fix. The consumer's engine
detects that error by reading a third ref; this one has no third ref to read, so the rule is
enforced by the author and by review, not by the tool. `core/fixtures/ledger-reverify-unfalsifiable/README.md`
is the measurement: 13 entries on the reference consumer carried predicates that could never
have gone green, and would have reported "still open" forever.

**A closed entry is annotated in place and left for rotation**, in the form
`**LANDED (v<version>, verified <sha>).**` — the annotation FORM is what the rotator keys on,
never the word anywhere in prose, because an entry that merely discusses landing something is
not a closed entry.


## Pipeline-efficiency ranked set (efficiency ranks 1–14)

Filed from [`docs/analysis/pipeline-efficiency-s317-s318.md`](analysis/pipeline-efficiency-s317-s318.md),
section **"Ranked defects"**. The rank is that section's order and each entry names its row as
`[efficiency rank N]`. Costs are API-list-equivalent over graph sprints 317 and 318, in-session
only (handoff gaps are excluded by operator ruling). Shared cost is counted once, under the higher
rank. Defects first exposed while the local `qwen38flash-mlx` model led are pipeline fixes toward
the operator's local-lead goal, never findings against the model.

**Measuring the change.** A receipt closes an entry on the tree. Whether the fix moved anything is
measured afterwards on consumer transcripts, re-running `pipeline-efficiency-s317-s318/scripts/` over
the sprints after the fix lands. graph is the reference, not the only population:
`magic-bonus-calc-engine` also runs ai-dlc (0.780.0) and has its own transcripts. Measure on every
consumer that has run the fixed release, and name the population beside each figure.



## Sprint 319 lead-transcript review (filed 2026-10-15)

Found by reading graph's s319 lead session `62eadbbe-59c3-436d-bf7c-931ebc09ecba` through
carry-over-evaluation's adversarial pass 1 (to about 21:45Z), with graph on 0.789.0 (`7e8d62d7`).
These are in addition to the four `PC-S319-*` candidates already in graph's uncommitted
push-candidate ledger, and none of them restates one. Every receipt is `manual` at filing: the batch
that builds an entry owes its behavioural `sh` receipt and the probe behind it.

## BL-538 — the lead takes a full turn for every agent notification while an armed join already covers it

**PARTIAL (v0.794.0, verified 8aab009d) — the prose half shipped; the hook and the measurement are OPEN.** rule-28 states the lead's response to a notification a live beat covers (no status line, no re-check) and the two that are not covered. Correction at v0.796.0: 0.794.0 said "arming the beat ships with the wait release"; that release's rule-28 paragraph arms the serial remediator's join with `--complete-repair`, which is BL-541's subject, and carries nothing for this entry. Still owed: the optional hook that injects the response when the notified agent's deliverable is inside a live beat's path set, and the per-wake count re-measured on the next consumer sprint.

**DEFECT (efficiency).** In graph s319 lead session `62eadbbe-59c3-436d-bf7c-931ebc09ecba`, measured at 22:47Z: 109 `<task-notification>` wakes, of which 61 ended with no tool call and only a restatement that the join was still armed ("X delivered … the join beat is still armed, so I'm waiting"). Each such turn re-reads the lead's whole context. That context ran 250–320K tokens (the sensor fired yellow at 252,985 and the snapshot records red readings of 317,305 and 324,185), and by 21:37Z the session had already spent 61 M tokens of lead cache read over 272 API calls. The waits it restates are `wait-for-deliverable.sh --complete` beats over the whole round, which return on their own. Core says what a notification MEANS for the cap-release rule (`rule-28.md:195`) but nowhere what the lead should DO with one that arrives while a beat covers that agent's deliverable. The analysis this backlog is filed from ranks lead waiting among the largest costs (`docs/analysis/pipeline-efficiency-s317-s318.md`, headline and "Relation to the v0.380.0 investigation").

Owed: a stated lead response to a notification for an agent whose deliverable an armed beat covers: no per-agent status line, no re-check, end the turn. Optionally, a hook that injects that instruction when the notified agent's deliverable is inside `.beat-inflight`'s path set. Measure it by re-running the per-wake count on the next consumer sprint.

**Second reading (f7 measured; transcript-only, not re-derived here).** In graph's s319 lead session `c61a91eb`, 20 of 29 task-notification wakes ended with no tool call. Method, f7's heuristic: a wake counts as ending with no tool call when no `tool_use` block appears before the next user line. This is NOT the same series as the filing's 61 of 109, which is a different session (`62eadbbe`), a different count of wakes, and was classed by whether the turn only restated that the join was armed; the two ratios (20/29 and 61/109) are two readings and are not a trend. Both say most wakes under an armed beat end without acting.

**Sharper reading (f7 measured; transcript-only, not re-derived here).** In graph's s319 lead session `c61a91eb`, on 0.828.0, one 25-agent SM seat ran under a single armed join (task `brrt6rqjh`). Between 14:40:41Z and 14:48:20Z (transcript lines 2702-2838) the lead took 14 consecutive wakes whose entire output was "Covered by the armed join; no action." Each was a full turn over a context of about 318k tokens or more, past the RED threshold. By f7's heuristic, the same method as the paragraph above, idle wakes went from 20 of 37 to 37 of 54: 17 in about 8 minutes on one round. The round plans 4 seats of about 25 agents each, so about 70 such turns are expected per round; that figure is f7's projection, not a count. Reading: the 0.794.0 prose half shortened each turn's output but cannot remove the turns; only the hook half can.

verify: manual

## BL-553 — the lead arms a beat on a sentinel nothing will write, to keep the Stop hook quiet

**DEFECT.** Consequence of BL-541. With no completion signal for the serial remediator, the s319 lead armed beats on files it created for the purpose and that no agent writes. At 00:03:48Z it wrote: "A sleeping beat, `bw7kr8cpi`, is now armed on a sentinel file that nothing will write. Its marker holds a future epoch, so it holds for a full quantum." Session 62eadbbe holds 8 such sentinel beats (corrected: the 00:17Z "fold record" beat was a real beat on requirements-d-answers-fold.md that delivered at 00:35:15Z, not a sentinel). Five are serial-remediator waits (00:03:48, 01:19:11, 01:29:06, 01:39:02, 01:48:57Z), closed by `--complete-repair`. The other three are closed too. 00:07:23Z, a serial remediator resumed by SendMessage after a refusal, is closed by reference: BL-593 (LANDED v0.817.0) and BL-541's `--complete-repair --dispatch` cover the resumed block, and nothing was built. 01:15:08Z, a part-04 SPEC render whose part record wrote no marker, is closed in `core/team-roles/remediator.md` (line 78): every part remediator now ends with `wait-for-deliverable.sh --mark <part path> <step> remediator <shard> findings=<n>`, and the part join beat in `core/skills/ai-dlc/steps/_gate-procedures.md` passes `--complete`; `join-remediator-shards.sh` needed no change, because a marked part leaves the serial block intact and unmarked parts still join. 01:52:38Z is closed in the same role file (lines 244-250): a serial remediator whose block appends a `(decision)` re-renders SPEC.md before its `--mark-repair`, so the render sits inside the dispatch that `--complete-repair --dispatch` already joins, and the record_tail refusal at `join-remediator-shards.sh:1477` rejects a serial block with a `(decision)` and a stale SPEC.md. That sentinel beat satisfied `ai-dlc-continue.sh`'s lease test while waiting on nothing, which is the "filler tool call" the hook's own text forbids ("Do NOT emit filler tool calls to get past this block"). The entry stays open only on part (b), below.

**The 01:52:38Z account (graph lead transcript 62eadbbe, read-only).** Two beats are involved, and the earlier wording described them as one. At 01:52:28Z (jsonl lines 9934-9936) a background beat, task bfq5e0eg3, completed and its output read `DELIVERED` for the offramp-config-and-rewards SPEC.md (line 9945), 40 seconds before the render agent returned. At 01:52:38Z (line 9953) the lead armed `wait-for-deliverable.sh --reset --since <now> $S` with `S=.../scratchpad/never-written-sentinel-render`, a path nothing writes, described as "Arm a sleeping beat until the SPEC render agent returns" (task b2id0l4h8), and confirmed its marker was a future epoch at line 9956. The render agent's notification arrived at 01:53:08Z (line 9977), and the lead TaskStopped b2id0l4h8 at 01:53:12Z (line 9980). So the real SPEC.md beat delivered early and the sentinel beat was armed to cover the gap that early delivery left. The control token `never-written-sentinel-render` is present in the transcript (4 lines) and an impossible token returned 0. Whether bfq5e0eg3 delivered on a partial write is not settled by these lines.

**Part (b), the target-containment refusal, is NOT shippable as specified (batch 236, measured by the wfd contract adversary over the reference consumer's lead transcripts, read-only).** 189 transcripts carry 2,869 beat calls over 5,866 targets. The legitimate targets outside the state dir include 803 teammate story-worktree deliverables, 75 background done files, 64 main-tree docs, 57 scratchpad and task outputs and 7 git refs, so "outside `_bmad-output/`" is not a defect signal. The In-Flight table is empty today and no transcript records it at arm time, so "outside every In-Flight row's deliverable" is unobservable. The seat beats that set a custom state dir (`implementation.md:447`, `qa.md:457`, `code-reviewer.md:196`) would fail it outright. At arm time a sentinel and a real done file are the same act; the difference is the lead's intent, which no check can see. Detecting a sentinel by its name is refuted: 2 of the 8 sentinel basenames lack `never-written`. The live claim is that a beat with neither `--dispatch` nor a dispatched agent's deliverable as its target still counts as a lease. Its false-positive set over the 2,869 calls is UNRUN. The only observable candidate is the dispatch join, and `wait-for-deliverable.sh` already WARNs on a `--since`-only beat (line 1345).

verify: manual

## BL-583 — the push suite costs about 8 fixture-hours per full run, over 40% in mutant batteries, and no fixture has been judged on value

**DEFECT (efficiency).** Operator-raised, 2026-10-16 ~04:30 EDT: "gating a release is so expensive, like stupidly expensive to run the push suite". Filed by peer session ai-dlc-68 (listed as ai-dlc-4e [e15800]). Assigned to ai-dlc-a6: phase 1 is a read-only census of where kill sets overlap, phase 2 is confirmation in the lead's slots after H-b. ai-dlc-bb's world-cache release already targets the `review-shard-merge-mutants` pole, so this entry does not count that saving twice.

Measured from `.git/ai-dlc-fixture-durations` in the main checkout, a LOADED-cost record that each push rewrites:
- Filer, at 04:29 EDT (288 rows): sum 28783 s (~8.0 h; ~40 min per full run on a pool of 12); 41 mutant rows at 12398 s, 43%; 12 of the top 15 rows mutant batteries at 583-737 s, the three non-mutant rows `snapshot-archive-rotate` 717 s, `suite-pole-guard` 493 s and `readset-skip-d` 410 s (corrected from 13 after lead ai-dlc-9c re-derived it); 130 rows at 60 s or more, 71 at 120 s or more, 82 under 10 s.
- Intake, re-derived at 06:18 EDT (288 rows, the record rewritten since): sum 27473 s; 41 mutant rows at 11346 s, 41%; 10 of the top 15 are mutant batteries (`derivation-capture-mutants` 737, `review-shard-merge-mutants` and `-b`/`-c` 728-729, `adversarial-shard-merge-mutants` 694, `remediator-shard-join-mutants` and `-b`/`-c`/`-d` 583-589, `updater-session-signals-mutants` 367), and the five non-mutant rows are `suite-pole-guard` 493, `readset-skip-d` 453, `ledger-reverify` 409, `-b` 392 and `-d` 362. Fixture directories: 290 (`/usr/bin/find core/fixtures -mindepth 1 -maxdepth 1 -type d`).
The two readings differ because the record moves with every push. The shape holds across both: the mutant batteries dominate the top of the rank.

Owed, under the step-value ruling in `operator-rulings.md` ("A step with no measured value goes") applied to fixtures — a fixture or mutant shard stays only on evidence, a named defect class it catches that no other unit catches; without that the batch retires or merges it, and it is not put to the operator as a choice:
1. Rank by cost first: the mutant batteries, then the non-mutant poles.
2. For each sharded battery, measure whether its mutants kill anything the base fixture's arms do not; shards of one battery that kill the same set are redundant.
3. State the gate wall clock removed per release and the dollars beside it.

Caveat: the record is a loaded-cost set from recent runs, not a solo timing, and a content-keyed push runs only part of it. The per-gate figure needs the gate log of a real release push (0.794.0 onward). Related: BL-558, BL-592, CLAUDE.md "A wall clock is a defect until it is justified".

Scheduled in batch 235 for a later release (scope ruling: the boundary is the release).


**Partial, v0.810.0.** Item (a), the sandbox re-trace of 13 of the 14 stale fixtures, landed in intake 2 (`52555359`). Items (b) and (c) land here: `fold-architect-ledger-join-mutants` runs C0 and the M6 premise in shard `a` only, bound by a J2 arm, and `derivation-capture-mutants` is four pool units with a derived deal and coverage join (J0, J1, J1b) and no redundant control. Open: the remaining phase-2 items (gate-adjudication M0 in one shard, the readset-skip-digest and advisor-gate-deny controls in one shard each, the ledger-reverify-shard control) and the per-gate wall clock and dollars, which need the gate log of a real release push.

**Gate-log evidence (f7 measured, graph session `f78aa565`; transcript-only, not re-derived here).** The graph push of the reconcile commit took 17.6 minutes in pre-push with 139 of 224 fixtures selected. That is a real release-class push on a consumer tree and a first data point toward the per-gate wall clock this entry owes; it is a consumer's selected subset, not this repo's full-suite figure, and the two must not be compared.

**Item (b), batch 236.** `gate-adjudication-mutants` (M0) and `readset-skip-digest-mutants` (unmutated and impossible-anchor controls) now run their controls in shard `a` only, bound by a J2 once-only arm with a two-direction self-probe, and a D14 arm every shard runs holds each shard's `inputs.decl`/`tools.decl` equal to `a`'s apart from the driver lines (also added to `fold-architect-ledger-join-mutants`). `advisor-gate-deny-mutants` keeps its per-shard control because its shards' declarations differ (`-d` adds `od` and `tee`; `-b`/`-e` declare sibling directories whole), and `ledger-reverify-shard-mutants` keeps its C-a and C-b controls because it is one unit whose kill list is 3 in `a` and 1 in `b`, so `b`'s control is the only one for its mutants. Item (b)'s receipt: `for f in gate-adjudication-mutants readset-skip-digest-mutants; do case $f in gate*) r='/^# M0 /,/^# m1 /' ;; *) r='/^NCTL=0$/,/^# J2: both/' ;; esac; t=$(mktemp) || exit 9; sed -n "${r}p" core/fixtures/$f/run.sh | sed '$d' > $t; [ -s $t ] || exit 9; S=$(grep -m1 '^SHARDS=' core/fixtures/$f/run.sh | cut -d'"' -f2); [ -n "$S" ] || exit 9; first=${S%% *}; for s in $S; do c=$(GROUP=$s C=0; score() { C=$((C+1)); }; dg_all() { C=$((C+1)); }; broken() { :; }; ok() { :; }; bad() { :; }; DG_WORLDS=; POOL=/dev/null; FX=x; HOOK=h; ROOT=r; . $t >/dev/null 2>&1; echo $C); w=0; [ "$s" = "$first" ] && w=1; [ "$c" = "$w" ] || { rm -f $t; exit 1; }; done; rm -f $t; done`. The entry stays open for the per-gate wall clock and dollars.

**Phase 2, v0.842.0.** Every mutation battery is retired: 56 units in 24 batteries, removed because none has a catch on record. A census of every record on `origin/main` that names a battery found only drift reds (re-anchored mutants, re-declared kill sets, scorer timeouts, the battery's own bugs) and one red that was not the battery's: BL-181, a subject locale bug the shipping fixture `gate-remediation-deny` also caught. In the main checkout's loaded-cost record the 56 units were 30380 of 54724 fixture-seconds (56%), and the pole moves from `adversarial-shard-merge-mutants` at 2214 s to `document-partition` at 732 s. The CHANGELOG for 0.842.0 carries the per-battery table. Items (b) and (c) above described those batteries' controls and shards; they no longer exist. Open: the non-mutant poles (`document-partition`, `enforcement-map-sites`, `apply-restamp-worklist-c` and the rest of the top of the record) have not been judged on value, and no per-gate wall clock or dollar figure has been measured.

verify: manual

## BL-584 — two fixtures cannot be traced and have no `inputs.decl`, so they run on every push

**PARTIAL (v0.806.0, verified 581ca289) — owed (1) shipped for `fold-architect-ledger-join` only; owed (1) for `hermetic-runner` shipped in v0.832.0 (verified 67bdbb7a), and owed (3) is OPEN.** `fold-architect-ledger-join` carries `inputs.decl` and `tools.decl` and runs under `hermetic-run.sh` (72 ok, `required_missing=0`); its 46 traced rows are removed. `hermetic-runner` reads its subject files from copies made once at startup. That cut its trace window about 6x (17691 lines to 2902, loaded) but did NOT stop the drops: one 6-fixture `--tracer sandbox` call dropped 3 reports in its window, and three `--local-map` reps dropped 1, 2 and 7, at load 27-43 (0 of 3 clean). The premise that the drops come from re-opening four tree files hundreds of times is REFUTED; the drop cause is undiagnosed. `hermetic-runner`'s 17 rows and digest are removed, so it runs on every push (fail-closed) until the drops are fixed. The earlier count of 27 held fixtures is 5: 27 have `#discards` at n≥3 in `.git/ai-dlc-fixture-readsets.local`, and only 5 are keyed on the current runner and deriver.

**DEFECT (efficiency).** Operator-raised, 2026-10-16 ~04:40 EDT: "what about the fixtures whose readsets cant be mapped? i do not believe you cant figure out a way to refactor those so they dont need to be run every time." Filed by peer session ai-dlc-68 (listed as ai-dlc-4e [e15800]).

Measured by the filer in the main checkout: 65 fixture directories have no row in `.ai-dlc-fixture-readsets.tsv`; 62 carry `inputs.decl`, so the hook counts them MAPPED (`.githooks/pre-push:866-871`) and keys them on the declaration; the other 3 (`lib`, `check-h1-recursion`, `check-manifest-bypass`) have no `run.sh` and are not units. `.git/ai-dlc-fixture-readsets.local` marks fixtures with `#discards` 3 or more when the live trace has thrown their result away three times and stopped retrying (`:954-956`, `:1304`). Intake re-derived: 86 `#discards` rows, 27 of them at 3 or more; `fold-architect-ledger-join` and `hermetic-runner` both have a `run.sh` and no `inputs.decl`. Per the filer those two are the only units that truly run on every push (173 s and 53 s recorded). Discard reasons across all rows, per the filer: 72 "the stream dropped reports", 9 "VERDICT: the sandboxed run's verdict lines differ", 2 "LOSS CANARY", 2 "TRIP".

Owed:
1. `fold-architect-ledger-join` and `hermetic-runner` get an `inputs.decl` and `tools.decl`, so `hermetic-run.sh` runs them hermetically and the hook keys them like the other 62; the sandbox proves the declaration complete.
2. A fixture that cannot be declared because it reads the whole tree by design says so in one README sentence, and is scored under BL-583's value test.
3. Find and fix why the trace stream drops reports (72 rows); while it does, every new undeclared fixture lands in the run-every-push set.

Caveat: in a linked worktree the local map is a different file (the BL-558 symptom); the fixtures unmapped there are re-measured once (1) lands. Related: BL-558, BL-583.

Scheduled in batch 235 for a later release (scope ruling: the boundary is the release).

**The completeness proof covers `inputs.decl` only (batch 236; root cause BL-676).** `tools.decl` KEYS tools but does not RESTRICT them. The sandbox PATH is `$HR_TOOL_DIRS:$HR_BIN` (`core/scripts/hermetic-run.sh:544`: `env -i PATH="$HR_TOOL_DIRS:$HR_BIN"`; header `:54-55`: "PATH pinned to the fixed tool dirs plus a symlink farm / of the declared tools (keyed and unkeyed)"), so every system tool dir is reachable whether declared or not. Removing a tool line therefore makes no fixture fail, and a removed tool line is invisible to any receipt or fixture. Of the 5 `inputs.decl` lines, 4 are mutated by `core/fixtures/hermetic-runner/run.sh` (DC1 `core/scripts/hermetic-run.sh`, DC2 `core/scripts/core-paths.sh`, DC3 `core/fixtures/lib/`, DC4 `.githooks/pre-push`), and two groups cannot be caught. All `tools.decl` lines cannot, because the sandbox never refuses an undeclared tool, so a dropped line changes nothing a fixture can observe. The fifth `inputs.decl` line, `core/git-hooks/pre-push`, cannot on the distribution, because the fixture never opens it there, although it is still part of the key. The result "one tool removed: 0" is therefore not coverage.

verify: sh o="$(bash core/scripts/hermetic-run.sh --root . --key-only hermetic-runner 2>&1)" || exit 1; k="$(printf '%s\n' "$o" | cut -f1)"; nt="$(grep -cv -e '^[[:space:]]*#' -e '^[[:space:]]*$' core/fixtures/hermetic-runner/tools.decl)" || exit 1; nr="$(grep -c '^/' <<<"$k")" || nr=0; [ "$nt" -gt 0 ] && [ "$nr" = "$nt" ] || exit 1; for p in core/scripts/hermetic-run.sh core/scripts/core-paths.sh .githooks/pre-push core/git-hooks/pre-push core/fixtures/lib/ core/fixtures/lib/preamble.sh; do grep -qxF -- "$p" <<<"$k" || exit 1; done # known limit: a removed tool line is invisible (tools.decl keys, does not restrict; BL-676)

## BL-605 — an In-Flight row's `dispatched-at` can be stamped LATER than the real dispatch, and the BACKDATED arm is quiet on a late row by design

**DEFECT.** Filed by peer session ai-dlc-ad, read-only on graph. Graph's `_bmad-output/pipeline-snapshot.md:68` (In-Flight Teammates) reads `remediator (serial, pass 1 cross-part, a7ffc8dcd555207b8) | remediator | s319/requirements-repair-p1.md (appended) | 2026-10-16T05:01:00Z | stopped` (intake confirmed). BL-599's filing puts that remediator's dispatch at 05:00:03Z, so the row is 57 s late. `core/scripts/validate-artifact-budget.sh` `check_backdated_dispatch` states at :1213 (origin/main 3d5f1e70) "A row stamped LATE (after its dispatch) stays quiet; this arm is about back-dating only." Measured by the filer on the extracted function with a one-row ledger at D: a row at D-112 fires BACKDATED (control), and rows at D, D+27 and D+87 are quiet.

Effect: `_gate-procedures.md:149` tells the lead to pass the row's `dispatched-at` as the beat's `--since`, so a late row is a forward-dated `--since`, which (BL-599) misses every write the teammate made between the dispatch and the stamp: the beat reads WAITING on a delivered file. BL-599's release adds `wait-for-deliverable.sh --dispatch <tool_use_id>`, which reads the spawn-ledger `ts` and refuses a `--since` later than it; that guards the beat but not the row, which other readers use.

Owed: the row is stamped from the ledger `ts`, or a write-time arm fires on a row later than its dispatch by more than a stated tolerance. Probe: a row 57 s late fires; a row at the dispatch is quiet.

**Recurring (reported by ai-dlc-f7, read-only on graph; intake ai-dlc-40).** Graph's s319 lead on 0.818.0 (transcript `74de15ba`, line 965, 2026-10-17T14:36:04Z) had the `--dispatch` guard refuse its architect join: `FAIL: --since is 153 s after the earliest dispatch it joins (2026-10-17T14:35:27Z, tool_use_id toolu_01XfPWCXnLJSZTfkDZqv1SxE)`. The lead then corrected its In-Flight row's `dispatched-at`, which is this entry's row defect. The guard did its job and the lead recovered in one turn. The cost was one refused beat and one extra turn. Intake: the line reads as quoted. The transcript carries the `FAIL: --since is` text on 3 lines, and line 1364 is an attachment echoing line 965's text, so there are 2 distinct refusals. The other refusal (line 2816) has a different cause and is filed as BL-656. Control: a token absent from the transcript matched 0.

verify: manual

## BL-608 — the validator fork budget's headroom eroded from +6 to 0 across five releases, and nothing warned

**DEFECT.** Filed by peer session ai-dlc-a6. `scripts/validate-enforcement-map.sh` FORK_BUDGET was set to 3363 in 0.786.0 as "HIGH reading 3357 plus the usual 6" (paragraph ~:825-831 then). Measured by the filer on 2026-10-16 with `fork-profile.sh --section by-arm --stable`, interleaved base/tip/base/tip in one detached worktree at one path, caller environment inherited: origin/main e3073787 (0.796.0) read 3362 and 3363 (STABLE 2, spread 3360-3362), equal to the budget — 0.792.0 through 0.796.0 spent the full +6 and no arm said so. `validator-fork-budget` fails only when the reading EXCEEDS the budget (its arm A3, "measured <= FORK_BUDGET"), so the window between "headroom gone" and "red" is invisible; at zero headroom the instrument's ±1-2 jitter makes any release adding one fork a ~1-in-4 red that reads as a flake. On 0.797.0 (+1 fork, I126 0 -> 1) the re-verify read 3362 with one rep at 3364 against 3363; 0.797.0 raised the budget to 3370 (+1 for its arm, +5 to restore headroom), which intake confirmed as `FORK_BUDGET=3370` at origin/main 3d5f1e70 (`:841`).

Owed: a headroom arm in `validator-fork-budget` that FAILS when the STABLE reading + 2 > FORK_BUDGET, naming the remedy (re-measure and raise by the HIGH reading plus 6, per the file's own rule), so erosion reports while margin remains. It needs its own mutant (the arm with the +2 dropped must miss a seeded reading at budget - 1) and its FP set measured over the budget history in that file's paragraphs. Scope: a small later release.

verify: manual

## BL-610 — the read-set sandbox tracer omits any fixture that probes process liveness

**NOTE.** Filed by peer session ai-dlc-a6 on lead ai-dlc-9c's instruction. `core/scripts/derive-fixture-readsets.sh --tracer sandbox` runs each fixture under `sandbox-exec` with a profile that grants file and process-exec rights but no process-info rights (intake: `process-info` 0 times in the script, against 16 `sandbox-exec`). Inside it `ps -p` sees no other process, not even its own shell, so a fixture whose premise is process liveness fails its own controls and the deriver omits it ("OMITTED (fixture exited 1) -- will always run", 1 occurrence in the script).

Measured by the filer on 2026-10-16 in a trace of 14 fixtures at a0451c70 (rc 0, 173 s, 13 mapped): `derivation-differential` was omitted (its `run.sh` uses `ps -p` 7 times). Its sandboxed log `/private/tmp/ai-dlc-readset-sandbox-501/w/derivation-differential.log:47-48` carries 4 FAIL verdicts, all in A12: the two liveness controls (:47, :48) and the two near-misses they gate (:51 A12l, :52 A12e). No arm outside A12 failed. Of the 13 lines containing `FAIL`, the other 9 are 8 `ok` lines reporting NEWLY-FAILING and the `4 assertion(s) FAILED` summary (intake confirmed the breakdown). The two controls:
  `FAIL  A12 control: ps -p does not separate the seeded dead PID (52683) from the live one (46059) -- A12b and A12l are unreadable`
  `FAIL  A12 control: PID 1 does not separate ps -p from kill -0 here (running as root?) -- A12e is unreadable`
Outside the sandbox the fixture is green: per the filer, `ok derivation-differential` appears in all three 2026-10-16 gate logs (an impossible token reads 0), with 7 loaded runs that day at 15-31 s each.

Cost: it stays unmapped and runs on every push, about 20 s, not the gate pole. It ran on every push before too (its rows were stale), so this is a permanent read-set gap, not a regression. Two candidate fixes, neither chosen: grant process-info in the profile (broadens what a trace records, to be weighed), or skip the liveness arms under the sandbox (weakens the fixture exactly where the trace looks; not recommended). Not to be fixed now.

verify: manual

## BL-587 — a reconcile that records derivations "owed to the sprint's derivation-validator step" has no channel to the sprint lead, so the debt is silently dropped

**DEFECT.** Filed by peer session ai-dlc-68 (listed as ai-dlc-4e [e15800]) from the graph s319 watch; intake re-derived every figure read-only on graph.
- The 0.793.0 reconcile log `_bmad-output/ai-dlc-update/reconcile-log-20261016T0725Z.md:35-43` records the operator's AskUserQuestion disposition "**leave untouched, record as owed**" and lists 8 newly-failing `grep -n` derivations "Owed to the S319 session's derivation-validator step": carry-over-evaluation-architect-5.md:13 and :23, carry-over-evaluation-pm-5.md:13, prd.md:1289, carry-over-evaluation-party-repair-p1.md:632, requirements-party-repair.md:859, shards/carry-over-evaluation-party-repair-p1/5.md:15 and shards/requirements-party-repair/08.md:102 (the BL-581 set). `prd.md:1289` and `s319/requirements-party-repair.md:859` still hold their old `$ grep -n -F -e "  ok  %-44s" … scripts/ai-dlc/validate-artifact-budget.sh` commands in the working tree.
- The 0.798.0 pull's log (`reconcile-log-20261016T105433Z.md`, 51 lines) carries no owed list: its 3 `owed` mentions are a path list, an `audit-layer-debt` count and a ledger re-verify line, and "record as owed" occurs 0 times. That is correct for its own differential — those 8 were already failing at its base, so it cannot report them as NEWLY-FAILING — and it means the only record stays the 0.793.0 log.
- The resumed s319 lead `cf53b84f` (resumed 07:26 EDT) ran `validate-artifact-derivations.sh` (17 mentions) at 07:59 EDT on `requirements-repair-p1.md` only. Its transcript mentions `reconcile-log-20261016T0725Z` 0 times, `prd.md:1289` 0 times and "record as owed" 0 times, against `requirements-repair-p1` 60 times. `_bmad-output/pipeline-snapshot.md` carries `reconcile-log` 0, `prd.md:1289` 0 and an owed-derivation line 0, against `requirements` 12.
So the debt lives only in a file no step of the resumed sprint reads.

Owed:
1. When a reconcile records items owed to a sprint, write them where the sprint reads them — the snapshot's owed/watch section, or a debt row a lead-side check refuses to pass while it is open.
2. The step-0a resume integrity check, or the step's own derivation-validator run, reads that record and re-points each derivation or shows it as open.
3. Prove it on this instance: the 8 rows above. (Per BL-581 each is a line-number re-point, not removed text.)

Related: BL-581 (the false-zero "Verified" in the same 0.793.0 log), BL-579 (the snapshot misreporting the stopped remediator's writes).

**Scope ruling (operator, relayed by lead ai-dlc-9c): CURRENT SPRINT only.** The owed record, its channel, and its check carry derivations owed to the sprint that is current when the reconcile runs. A derivation in a past sprint's artifact is owed to nobody, and must neither block that sprint's lead nor show as open there. The ruling is BL-631's: "I'm stating that I don't care if a fixture or check fails against a historical sprint artifact", and "if someone deleted all of graph consumer's sprint history, it should not matter whatsoever". Item 3's proof is therefore over those of the 8 rows whose artifacts belong to the current sprint. A control row in a past sprint must NOT appear in the record.

**Second instance (graph 0.800.0 → 0.803.0 reconcile, session `89a3adec`, 12:43-12:49 PM EDT).** Filed by ai-dlc-68 (listed as ai-dlc-4e [e15800]); intake re-derived it read-only on graph. `_bmad-output/ai-dlc-update/reconcile-log-20261016T164848Z.md:27-31` (68 lines; committed as `4558f87fe`) records `derivation-differential.sh` exiting 1 with 5 NEWLY-FAILING derivations. Three of them are in the LIVE sprint s319:
- `party-mode/s319/carry-over-evaluation-pm-3.md:38`
- `planning-artifacts/s319/carry-over-evaluation-party-repair-p1.md:337`
- `planning-artifacts/s319/shards/carry-over-evaluation-party-repair-p1/3.md:35`
Each greps `carry-over-evaluation.md` for 'dominant work rather than one item among', and upstream inserted a line above that text: the file grew from 251 lines at `efcd5373` to 266 at `21facb0f`. The other two rows belong to closed sprints, `s303/test-strategy-repair-p1.md:286` and `s308/derivation-staleness-repair-p2.md:61`.

The operator was asked and answered "Record, don't edit (Recommended)"; that phrase occurs 4 times in the session transcript. The disposition went only into the reconcile log. `_bmad-output/pipeline-snapshot.md` carries none of the three s319 rows and does not name the log (0 hits for each; control: `s319` 8). The s319 debt is now 11 re-points: the 8 from 0.793.0 plus these 3.

The question also rested on a false premise. The log's disposition says "these are closed or sha-locked sprint artifacts", and "sha-locked" occurs 6 times in the transcript. s319 is mid-sprint, though, and its repair records are append-only, not closed, so a later block can supersede these derivations: BL-588's mechanism, landed in 0.803.0.

Under the current-sprint scope ruling above, this instance is exactly the discriminating input. The three s319 rows must reach the lead, and the s303 and s308 rows must not. Receipt addition, as suggested by the filer: seed a closed-sprint row (s303) and a live-sprint row (s319) from one reconcile log, and assert that only the live one reaches the lead, whether or not the reconcile chose to edit.

**PARTIAL (v0.808.0).** Delivered: items 1 (debt-row half) and 2. Withdrawn by operator ruling: item 3 (the 8 rows are prose in a reconcile log written before this release, never recorded, so no reader can pick them up; the receipt proves the shape on seeded rows). The 8 rows are live CURRENT/LIVING stale derivations in graph; the operator hands them to graph's own session to re-point, with the 3 s319 rows of the second instance. Open: item 1's snapshot half (D6: no writer can reach the working branch before the reconcile PR merges). Scoped by operator rulings: current sprint and living documents only; refused at the planning gate only.

**What the first instance cost (graph watch ai-dlc-f7, filed as BL-622 and folded here as the same claim; intake re-derived it read-only).** Of the 8 rows from the 0.793.0 log, one is `planning-artifacts/prd.md:1288-1289`, whose fence greps `scripts/ai-dlc/validate-artifact-budget.sh` for `"  ok  %-44s"` and records line 1676 (written in `dbc4c057e`). The line is 1676 at `8f313c3c0` and 1955 from `41d2dbf91` onward. The s319 lead found it about 14 hours after the pull, and only because two pass-2 adversary shards (parts 11 and 6) flagged it: transcript `0e9a936b`, first mention at 21:56:59Z, 17 mentions in all. It now sits in graph's live snapshot (`pipeline-snapshot.md:40`) as "STALE LIVE FENCE (owed to the pass-2 repair, NOT editable before the pass-2 merge because every shard notarized prd sha 15c46858 and the --subject merge refuses a moved sha)". The other 7 owed sites have no sprint-side record. So the missing channel cost an adversary dispatch to recover a grep result.

That snapshot line also names a sub-case the channel has to handle. `core/skills/ai-dlc-update/reconcile/apply.sh:1404`'s WORKLIST remedy says only to re-point each fence, but a live-sprint file whose sha the round's shards have notarized cannot be edited mid-pass. The owed record must therefore survive until the sprint's next repair, not merely reach the lead. Control for "no core reader": 0 files under `core/skills/ai-dlc`, `core/hooks` or `core/scripts` name `ai-dlc-update/reconcile-log` at `581ca289`, against 9 naming `operator-requests-history`. Probe, from the filer: seed a pull that NEWLY-FAILs one fence in a live-sprint artifact, dispose it as owed, and assert the next sprint resume names that file:line. A fence in a closed-sprint artifact stays quiet (near-miss).

**Check 37 passes graph's planning gate with the first instance's fence still failing (graph watch ai-dlc-f7; intake re-read it read-only on graph).** The s319 lead's [planning] gate, transcript `74de15ba` at 0.818.0, shows two things on 2026-10-17. At 14:10:12Z the validator printed "FAIL (STALE): _bmad-output/planning-artifacts/prd.md:1289 … recorded: 1676 … actual: 1955" (1 hit). At 14:15:56Z the lead wrote "Check 37 reads an owed-derivations record that doesn't exist" (1 hit; negative control 0). `_bmad-output/ai-dlc-update/owed-derivations.tsv` is absent in graph, while that directory holds 590 entries. Graph's installed `scripts/ai-dlc/check-owed-derivations.sh` says "absent is silent 0" at `:286-289`, and so does main's at `:291-293`. `steps/gate-validation.md:3300` says "an absent record is exit 0". The only writer is `derivation-differential.sh --record-owed`, which appends NEWLY-FAILING rows only (`:9`). prd.md:1289 broke at the 0.793.0 pull, before the record existed, so every later pull reads it as STALE-BOTH (`:49`), which is never recorded. Of graph's 256 reconcile logs, only `reconcile-log-20261016T0725Z.md` names it. The lead is carrying it by hand, as a MINOR finding into architecture.md.

This is the consequence of the PARTIAL note's withdrawal of item 3: no reader picks up the 8 rows, and Check 37 is not the channel for them. f7 proposes either a one-time back-fill of the record from the reconcile logs' owed lists, or Check 37 also running `validate-artifact-derivations.sh` over the documents it scopes as LIVING. Both would re-open what the operator withdrew, so intake files them as a proposal for the lead to rule on, not as owed. f7's probe, if adopted: a LIVING-document fence broken before the record existed must DENY, and the same fence in a closed sprint stays silent.

verify: manual

## BL-616 — fixture verdicts depend on box load: `validator-fork-budget` reads FIXTURE BROKEN under the gate's pool, and a red costs a full re-push

**DEFECT (efficiency).** Operator directive, relayed by lead ai-dlc-9c: "we need to not be so sensitive to load, it's a self-inflicted issue that fixtures are marked as failed because of it and/or aren't considered successful." The scope is every load-sensitive verdict in the suite, not only the one instance below.

**PARTIAL (v0.820.0, verified 4e6670c1) — item 7 closed as diagnosed; item 8 read once; the entry stays OPEN.** Item 7: 0 live `verify: sh` receipts against 55 `verify: manual`, so no reachable receipt flaps; UNSTABLE is a correct refusal of a racing receipt. Item 8, one reading at pool load: readset-sandbox-root-clause, inside a 30-unit concurrent wave, judged its stream window on attempt 1 of 10 with no drop notices. A single reading; it bounds nothing.

The measured instance is `core/fixtures/validator-fork-budget`. Its arm A2 (determinism, `run.sh:22`, driven at `:262` via `scripts/fork-profile.sh --section total --stable`) requires a repeated total among the `--stable` profiles of an unchanged tree (`fork-profile.sh:33`, `:334`).
- 0.802.0's gate, 10:45-10:54 EDT: `.git/ai-dlc-fixture-failures.20261016T145420Z.9311` reads "1 of 59 units red", then "FIXTURE BROKEN: the profiler could not produce a repeated reading of the real validator. fork-profile: 4 profiles of an unchanged tree produced no repeated total (3400 3399 3401 3397 ). A single dropped xtrace line is expected under load and is subtractive; this is something else." The gate went red and the push was lost.
- ai-dlc-11's slot for 0.801.0: 3388, 3390, 3391 and 3389, the same FIXTURE BROKEN (reported by 9c; intake has no record file for that run).
- Run solo at low load, ai-dlc-11 and ai-dlc-ad each got a clean repeat (reported by 9c; not re-measured at intake, gate window).

A fork COUNT of a fixed tree should not move with load, so the readings drifting both above and below each other means something forks a timing-dependent number of times, or the instrument loses and gains trace lines under load. The record's own text says a dropped line is "subtractive", and readings that rise as well do not fit that alone. The cause is NOT established here: ai-dlc-4e [9b62de] is running the by-line census (`scripts/fork-profile.sh --section by-line` at two loads, differenced) and will add it.

Owed:
1. Find the cause in the measured instance and remove the load dependence at its source (a verdict that holds at any load), rather than retrying until a repeat appears.
2. Census every other verdict in the suite that can change with load (timeouts, wall-clock bounds, poll counts, repeat-until-stable arms), and list each with its mechanism.
3. Receipt per fixed unit: its verdict is identical solo and under the gate's pool at the recorded load. Control: one unit known to be load-free agrees both ways too.

Each instance costs a full re-push of the release, which is the consequence this entry is tiered on.

Owner: ai-dlc-4e [9b62de] (lead ai-dlc-9c).

**Cause and census (ai-dlc-4e [9b62de], 2026-10-16 11:13-11:15 EDT; intake spot-checked the cited lines at origin/main `f4ca6764`).**

*A2's cause is the instrument, not the validator: trace records are spliced, not lost.* Six profiles of `f4ca6764`, taken two at a time at load 2.8, read 3400, 3401, 3401, 3399, 3401 and 3399. Every trace was 39877021 bytes and carried exactly 90452 `+@N@` markers somewhere in its text, but only 90450-90452 of them at line START. Pipeline stages share fd 2, so a sibling stage's trace record can land in the middle of a long host line. The classifier at `scripts/fork-profile.sh:137` (`if ($1 !~ /^\++@[0-9]+@$/) next`) reads field 1 only, so a spliced record is skipped. Diffing the high reading (r2) against the low one (r4) finds two rows only in r2: `scripts/validate-enforcement-map.sh:7766` `sed` (I82) and `:10105` `tr` (I93); the other 981 rows are common. A reading can therefore fall anywhere from n down to n-k, so the arm's premise that only {n, n-1} occur, and that its exit 3 can never be reached, is false. `--stable`'s repeat-until-equal loop does not fix this; it only shrinks the odds.

Proposed fix, built as WIP `06e4d186` on `b235-load-a2`:
- The classifier reads every marker on a line.
- One reading replaces the repeat loop.
- A2 asserts TRACELINES == MARKERS with a second reader over the same trace, and any gap is FIXTURE BROKEN.
- A new splice self-probe checks both directions, with mutants m7 (field-1 reader) and m13 (widened marker).
Offline over the six saved traces, the new classifier reads 3401 on all six with ntrace == MARKERS == 90452. On an unspliced trace the old and new by-line outputs are byte-identical, which is the control.

*Census of load-red candidates, each with 4e's proposed fix:*
1. `validator-fork-budget` A2: the fix above.
2. `core/fixtures/context-sensor/run.sh:614`: the CONTROL window is seeded at `now - 59` against a 60 s freshness bound, and the comment at `:605-607` already records "two of seven gate runs in one day failed exactly that arm". Proposed: seed it at `now - 30`.
3. `core/fixtures/gate-remediation-deny/run.sh:1416-1419`: arm 3b asserts a hung resolver is abandoned in under 15 s of wall clock. Proposed: the stub sleeps 600 s and the bound becomes 300 s.
4. Short HANG watchdogs: `fold-architect-ledger-join/run.sh:456` (150 polls of 0.1 s, so 15 s), `readset-stage1-verdict` `:582`, `:639` and `:660` (10-30 s), and `readset-skip`'s polls. Proposed: size each one to a hang (120 s), not to the expected time.
5. `advisor-gate-deny` `lib.sh:546`, the rr-late cell: a 3 s append against a 10 s default ceiling. Proposed: give that cell an explicit 60 s ceiling.
6. The suite-pole FAIL in `scripts/validate-suite-pole.sh:947-957` and `:997-1008` compares loaded wall clock against loaded history. Proposed: gate on per-unit CPU-seconds and keep wall clock as information.
7. Backlog receipts `--max-unstable 0` (`.githooks/pre-push:269`): a receipt that flaps under contention fails the push. Proposed: diagnose the flap at its source (read still owed).
8. `readset-sandbox-root-clause` `:136-158`: BROKEN when all 10 `log stream` windows drop notices. The rate under pool load must be measured before any fix.

Not load-reds: the pole SKIPs (exit 0), SKIPPED-on-earlier-red, and the trace-TIMED-OUT WARN. Already fixed at source: `agent-definition-render` and `artifact-section-heading-level`.

Coverage limit: the census was curated, not exhaustive (raw hits A 117, B 113, C 123). Items 4 and 7 still owe reads, and `readset-skip` is only partly read. The release order is lead ai-dlc-9c's to set; 4e proposes A2 first, as its own release.

**Progress (0.804.0; entry stays OPEN).** Shipped: census items 1-4.
- Item 1, A2: one reading, every trace marker classified, A2 asserting TRACELINES == MARKERS.
- Item 2: context-sensor's CONTROL moved to `now - 30`.
- Item 3: gate-remediation-deny 3b is binary. The edit is DENIED, and the 600 s sleeper's recorded pid is dead when the hook returns. Elapsed time is printed, not judged.
- Item 4: the `fold-architect-ledger-join` D6 watchdog and `readset-stage1-verdict` `:582`, `:639` and `:660` were raised to 120 s.

Slot, 2026-10-16, 12:04-12:10 PM EDT at load 3.6-4.6:
- validator-fork-budget, solo: 3401 forks, TRACELINES == MARKERS == 90452, 14/14 mutants killed.
- gate-remediation-deny and readset-stage1-verdict through `hermetic-run.sh`: rc 0, `required_missing=0`.
- context-sensor (164 passed) and fold-architect-ledger-join (72 ok), run from the repo root as the hook runs them; neither declares inputs.

Still owed, in the order lead ai-dlc-9c set:
- (6) the suite pole gated on per-unit CPU-seconds;
- (7) the backlog-receipt flap, diagnosed at its source;
- (5) the advisor-gate ceiling, now BL-630;
- (8) the `readset-sandbox-root-clause` all-lossy rate, measured at pool load;
- item 4's unread `readset-skip` polls: `:981`, `:985`, `:1305`, `:1307`, `:1316`, `:1369`, `:1386`, `:1395`, `:1453-1458`, `:1680` and `:4104`;
- every time or numeric threshold in an assertion, each converted to a binary attribute or justified by a named, measured property (operator: "really need to stop forcing arbitrary goals that aren't based on binary attributes"). This release's 120 s watchdogs are harness safety nets for a hang, not verdicts, and are on that list too (BL-632).

Each fixed unit still owes its solo-against-pool receipt, with a load-free control.

**Item 7 diagnosed; closed with no code change (lead ai-dlc-71's ruling).** Read at origin/main `9f8e7691`:
- `scripts/validate-backlog-receipts.sh` runs each receipt in a private detached worktree (`:270-289`, `:311-315`) with no timeout or watchdog wrapper. Its only sleep is the 1 s pause between `worktree add` lock retries (`:273-287`), and running out of retries reports BROKEN (`:312`, `:372`), never UNSTABLE.
- UNSTABLE (`:376-377`) means a re-read of the same commit in a second private worktree gave a different exit. Only the receipt's own text can make the two differ, by racing something it does not own (for example a `grep -q` fed from a pipe behind an `|| exit 9` guard).
- Population: `docs/backlog.md` holds 0 live `verify: sh` receipts (its one `verify: sh` line is the legend at `:22`), against 55 `verify: manual` as the control, so R6 has nothing to score and the arm reports R2 all-manual.
- History: no recorded R6 firing. The one instance is pre-ship, `BL-099` flipping once in 33 runs under three-way contention (`CHANGELOG.md`, 0.562.0 entry), where the checkout-incompleteness hypothesis did not reproduce.
- UNSTABLE is a correct refusal of a racing receipt. Relabelling signal exits as BROKEN was considered and dropped: BROKEN fails the push too (`:1094-1096`), so it would change the label and not the outcome, and nothing in the script raises those signals.

**Item 8 raised (batch 236; the entry stays OPEN, because items 5 and 6 and the unread `readset-skip` polls are still owed).** The lossy-window cap is raised 10 -> 30 in DIAG (`MAXATT`, `core/fixtures/readset-sandbox-root-clause/run.sh:142-162`). It stays a count, and all-lossy still exits BROKEN. At the 0.763.0 gate reading (16 lossy of 23 attempts, p of about 0.70 at load 32-36), the all-lossy odds go from 0.7^10 (about 2.8%) to 0.7^30 (about 2e-5). At 30, an all-lossy run takes about 11 minutes worst case before BROKEN, against about 20 minutes at 60, and 60 bought nothing measurable over 30. Closing observation: read N off the fixture's `stream window judged on attempt N of 30` note in real gate output.

**DEFECT — readset-skip-d reads a false RED under load (batch 236, from graph transcript 5d4fbc59, the push of 8c9563f75, relayed by lead c8; not re-measured here).** At load 77-85, `ck_mut` (`core/fixtures/readset-skip/run.sh:4938-4959`) failed 2 of 56 assertions, rc 1. Mutant `notfail` moved worlds 'f l' rather than l alone, and mutant `nosubtree` moved 'h m' rather than m alone. The same tree passed at load about 8 (18:39-18:45 EDT). Not diagnosed: which part of world f or world h is timing-sensitive. readset-skip-d is now the suite pole, so this is tiered DEFECT under this entry's owed item 2 (the census of load-dependent verdicts).

verify: manual

## BL-632 — shipped checks and fixtures pass or fail on an arbitrary number instead of a binary property of their subject

**DEFECT.** Operator, relayed by lead ai-dlc-9c: "really need to stop forcing arbitrary goals that aren't based on binary attributes." Part of ai-dlc-4e [9b62de]'s load series (BL-616). Subject: assertions whose verdict turns on a number with no stated property behind it, such as wall-clock bounds (`$((SECONDS - t0)) -lt N`, timeouts that fail as HANG or FAIL), percentage windows, and repeat or rep counts. Under load such a bound turns a correct subject red, which is BL-616's consequence, and when tuned to pass it asserts nothing about the subject.

**PARTIAL (v0.820.0, verified 4e6670c1) — the fixture nets and verdicts shipped; the product deadlines are filed as BL-639, BL-640 and BL-641 and stay OPEN.** Every hang net in the load series refuses on no progress (exit 2), never FAILs a verdict on elapsed time: the four mutant batteries' scorer watchdogs, fold-architect-ledger-join D6 (`ulimit -t 10`, 30 s no-progress refusal) and its battery's refusal pass-through ([MS]), readset-stage1-verdict's waits, spec-join-integrity's CPU-budget termination arm, and readset-skip's eleven live-trace waits. Each window carries "a margin over one observed step, not a measurement; a refusal costs a re-run, never a verdict". wait-for-deliverable.sh, ai-dlc-continue.sh and derive-fixture-readsets.sh carry comment-only headers naming the property behind each bound.

Instances known today:
1. `H4` in `adversarial-shard-merge`, on ai-dlc-c9's local branches `b235-ra-g3` and `b235-ra-scratch`: `core/fixtures/adversarial-shard-merge/lib.sh:1139`, `[ "$((SECONDS - t0))" -lt 8 ] && [ "$RC" -eq 2 ] …`, which `run.sh` names "within 8s". It is a timing proxy standing in for "never read stdin". BEING FIXED, NOT OWED: c9's release replaces it with a poison-token file, which is this entry's remedy shape.
2. 0.804.0's 120 s HANG watchdogs (`b235-load-a2`): `fold-architect-ledger-join` D6 raised from 15 s to 120 s, and `readset-stage1-verdict` `:582`, `:639` and `:660` raised to 120 s. That release raises the number; it does not remove it.
3. The advisor-gate 10 s re-read ceiling, BL-630 (`core/hooks/ai-dlc-advisor-gate.sh:579`).
4. The suite-pole wall-clock growth arm, `scripts/validate-suite-pole.sh:947-957` at origin/main `21facb0f`: a run FAILS past `A_MAX + A_MAX * REGIME_BAND / 100`, with `REGIME_BAND=100` at `:248`. Its own header calls that band "uncalibrated" (`:945`).

Owed, per instance: convert it to a binary attribute (did X happen: a poison token read, a sentinel written, a line seen), or name the property the number stands for and justify the number from a measurement of that property. A census of the remaining instances goes with item 1 of BL-616's census.

NOT IN SCOPE, listed for the OPERATOR to decide, not for the owner: budgets the operator set or approved. `FORK_BUDGET=3405` (`scripts/validate-enforcement-map.sh`), the A6 durable-channel ceiling (`DURABLE_MAX`, 69120 on main, 69376 on intake-7, `scripts/validate-claude-rules.sh`), and the backlog size cap (`MAX=104`, `scripts/validate-backlog-size.sh:129`, which `:72` records the operator raised).

Owner: ai-dlc-4e [9b62de] (lead ai-dlc-9c).

**Census (ai-dlc-4e [9b62de], at lead ai-dlc-9c's request; a haiku grep census at origin/main `8f1a9074`, classified by 4e, with the cited lines read in context except the untriaged ones; intake spot-checked every cited line at `8f1a9074`).**

*OWED: fixture assertions judged on elapsed time.*
- `core/fixtures/wait-stale-deliverable/run.sh:362` (`ELAPSED -ge 2`), `:400` (`-le 1`), `:462` (`-le 10`), `:479` (`-ge 6`), and `receipt.sh:113` (`-le 2`). Each asserts whether a beat slept, a property a sentinel could carry instead.
- `core/fixtures/spec-join-integrity/run.sh:495`, `run_bounded`, called with 5 at `:1388` and `:1406`. Its HANG mutant is killed at the 5 s bound, so the bound itself is the discriminator.
- The 0.804.0 120 s nets (item 2) stay for now. Lead's ruling: the hang question is its own release with BL-630, and it starts from what "hung" means as a yes/no property. Measured by 4e: no per-unit ceiling exists in the pre-push pool or in `hermetic-run.sh`, and the hook's 3x/600 s ceiling bounds only the detached read-set trace.
- About 25 untriaged lines: the `sleep 1; t=$((t + 1))` tick loops in five `*-mutants` fixtures (`adversarial-shard-merge`, `apply-self-overwrite`, `remediator-shard-join`, `review-shard-merge` and `self-update-fixture-log`; intake confirmed the five, against 20 files containing `sleep 1`), `core/scripts/derive-fixture-readsets.sh:1088`, `:1510` and `:1568`, and `readset-skip` `:1307`, `:1316`, `:1369`, `:1386`, `:1453`, `:1457`, `:1458` and `:4104`.

*SEPARATE CLASS: product code with a time ceiling, which ships to consumers.*
- `core/scripts/wait-for-deliverable.sh`: `IDLE_SECS` at `:938`, `SETTLE` at `:1003`, `BUDGET` at `:1138` and `DEADLINE` at `:1434`.
- `core/hooks/ai-dlc-recover-gate.sh:201`: a 10 s `SECONDS` re-read loop, the same shape as BL-630.
- `core/hooks/ai-dlc-continue.sh:363`: `RAPID_WINDOW_SECONDS`.

*CLOSES with 4e's pole release now in preparation:* instance 4, `REGIME_BAND`. That release deletes `scripts/validate-suite-pole.sh` and makes the pole information-only. The file is still present at `8f1a9074`.

**Product-code class, batch 236 (wfd release).** BL-639, BL-640 and BL-641 are done in that release, each with its own receipt: SETTLE no longer decides a seat sealed with `--mark` (it stays only as the fail-open net for a legacy marker with no `sha=`), the chained-beat guard decides by the parent shell's start time rather than BUDGET, and the continue hook's unknown-tool path keys the stall run on the session id rather than RAPID_WINDOW_SECONDS alone. This entry stays PARTIAL: BL-630, the 0.804.0 120 s nets, the suite-pole growth arm and `core/hooks/ai-dlc-recover-gate.sh:201` are untouched by it.

verify: manual

## BL-634 — `enforcement-map.yaml` is not valid YAML: `yaml.safe_load` fails on an unquoted `: ` in a prose value

**NOTE.** Reported by lead ai-dlc-9c; intake reproduced it at origin/main `21facb0f`. PyYAML 6.0.3 `yaml.safe_load` on `core/skills/ai-dlc/enforcement-map.yaml` (1425 lines) raises "mapping values are not allowed here" at line 129, column 66. The offending line is `posture: FAILS the gate (exit 0 required; exit 0 with `OK: EXAMINED NOTHING` — printed`, where the unquoted `: ` inside the prose value starts a second mapping. (9c's reading said line 128; PyYAML reports 129, and line 128 is `- site: gate-validation.md Check 2`.) Control in the same run: a small valid file parses.

Nothing breaks today. No tracked file imports PyYAML (0 matches for `import yaml` in any form across the tree, which has 89 `.py` files; control: `import json` in 75 files and `import sys` in 33). The only two `yaml.safe_load` mentions are prose, in `CHANGELOG.md:33885` and `docs/reviews/`. The repo's readers parse the map with awk and grep (fixtures such as `enforcement-map-sites` and `enforcement-map-derivations`). But the file carries a `.yaml` name and ships: `scripts/install.sh` mentions it 4 times and `core-manifest.md` 6. So any standard YAML tool a consumer points at it fails.

The same failure class was fixed once before for a different writer: 0.237.1's `yaml_scalar()` (`CHANGELOG.md:33885` onward) quotes any value carrying `: `, after a regex reader returned PASS over a file `yaml.safe_load` rejected.

Owed: the map parses under a standard YAML loader (quote the offending values, or rename the file to stop claiming YAML), and a check that keeps it so. Measure the check's false-positive set before shipping it, and note that no PyYAML is assumed on a consumer box. Receipt: `yaml.safe_load` succeeds on the shipped map, and a seeded unquoted `: ` in a prose value makes the check fail.

verify: manual

## BL-620 — the LC-A1 layer adjudication accepts a verdict with no evidence the entry was read, so nine re-reads were closed by one keyword grep

**DEFECT** (doubtful, so DEFECT under the operator's standing rule). Filed by ai-dlc-68 (listed as ai-dlc-4e [e15800]); intake re-derived it read-only from graph's session `1b4ba596` and its register record. Graph's 0.803.0 → 0.805.0 pull (2:15-2:22 PM EDT) had 9 `HARD-LAYER-ADJUDICATION-MISSING` rows. Between 18:15Z and 18:21Z the session made **0 `Read` calls in total** (41 Bash calls), and its checks of the nine extensions were keyword greps. The last one, at 18:20:30Z, was `grep -n -i -E 'Rule ?(1|3|4|5|6|9)\b|pause point|phase transiti…'`. One `sed -n '535,550p'` read a single override span. At 18:20:45Z it asked the operator "Can I record 'still-additive' for all nine LC-E4 extension re-reads?", and the operator agreed. `_bmad-output/ai-dlc-update/blocker-adjudication-20261016T181629Z.md:13-25` records the nine rows (entry, core file, sha, verdict) and, under "Verification:", a `grep -n -i -E '\bRule [1569]\b|variant' <nine entries>`.

The contract is `core/skills/ai-dlc-update/SKILL.md:1986`: "Read the entry against the new core text and record a verdict per entry". This pull retired Rule 1 and folded Rules 5, 6 and 9, which are prose rules. A rule-NUMBER grep cannot find an extension that restates a rule's CONTENT without citing its number. For contrast, the 0.800.0 → 0.803.0 session `89a3adec` read each entry against the diff and found that Check 925 contradicted core, which the operator then retired.

The verdicts look right this time. The filer searched for 9 retired-rule phrases across every extension and found none (control token 0). The defect is that nothing would have caught a wrong verdict. A register row is entry, core file, sha and verdict, with no field tying the verdict to a read of the entry, and the open backlog does not cover this (0 matches for `HARD-LAYER-ADJUDICATION-MISSING`). The clearing path is derived, traced by the filer on graph's installed 0.803.0 copies and re-checked at origin/main. `core/skills/ai-dlc-update/reconcile/layer-drift.sh:766-768` reads "every row whose status is such a clause's code must have a verdict recorded in the consumer's register under the subject digest it fired on, or the pull blocks". The key is (clause, `subject_digest`) plus a verdict, and nothing else is consulted. `core/schemas/layer-adjudication-register.json` requires `clause`, `entry`, `subject_digest`, `verdict`, `recorded_utc` and `reason`, and its optional fields are `supersedes`, `owed`, `closes_owed` and `withdraws`. No field carries read evidence. `reason` is free text, and these nine rows satisfy it with the grep sentence. So a schema-valid row whose digest is copied from `--list-adjudications` clears LC-A1, whatever its `reason` says.

Owed: put the evidence in the row, for example a required `read:` field naming the entry's sha or line span compared against the core hunks. Or have the re-read emit a per-entry diff excerpt that the operator question must quote. Receipt: a row with a verdict and no read evidence keeps LC-A1 HARD, and a row with valid read evidence clears it (control).

verify: manual

## BL-621 — the update skill's "re-approve the re-rendered report before apply.sh" has no mechanism, and a session took a pre-authorised merge approval as that re-approval

**DEFECT** (doubtful, so DEFECT under the operator's standing rule). Filed by ai-dlc-68 (listed as ai-dlc-4e [e15800]); intake re-derived it read-only from graph's session `1b4ba596` and at origin/main. In graph's 0.803.0 → 0.805.0 apply, after the nine LC-A1 rows of BL-620 were recorded, the session re-rendered the report region.
- At 18:25:57Z the operator typed "merge is approved when ready" mid-turn. The transcript shows it queued, then removed with `reason: absorbed_mid_turn` at 18:26:02Z.
- At 18:26:13Z the session wrote: "Noted that you've approved the PR merge for when it's ready; I'll apply that at step 8. The re-rendered report's only change is that the nine HARD rows were removed, which is the outcome you already approved, so I'm taking your merge approval as re-approval…"
- At 18:31:51Z it ran `apply.sh --carried-machinery-slice`. No AskUserQuestion fell between the re-render and the apply.

The contract is `core/skills/ai-dlc-update/SKILL.md:1739-1745`: re-render the region, "run `--verify` to exit 0, have the operator re-approve it, and only then run `apply.sh`. … The re-approval is not a formality: a resolution can leave rows the first approval never saw". The operator's words approved the step-8 PR merge, not the re-rendered report.

Consequence this time: likely nil. At 18:25:57Z, before applying, the session found "The only change in the re-rendered region is that the nine HARD rows are gone; nothing new appeared." The defect is that the gate is prose only. `emit-report.sh --verify` checks that the region is current: exit 0, or 3 for the safe-direction "BLOCKERS-RESOLVED" case (`:59-62`, whose own remedy is "a re-render and re-approval"). `apply.sh` reads `--verify` (19 mentions), but its 8 mentions of re-approval are all remedy text in refusal messages (`:217`, `:222`, `:310`, `:323-327`). Nothing records or checks an operator re-approval (0 mentions of an operator-answers record), so any operator message can be read as one.

Owed, one of:
- (a) Mechanise the re-approval. For example, `apply.sh` refuses unless the operator-answers history holds a hook-written answer, timestamped after the region's render, to a question that quotes the region's digest.
- (b) If the batch judges re-approval valueless when a re-render only REMOVES HARD rows (exit-3 territory), remove that case from the prose, under the ruling that a step with no measured value goes. Re-approval stays for a re-render that adds rows.
Either way the prose and the mechanism must agree. Receipt for (a): `apply.sh` refuses after a re-render with no recorded re-approval, and proceeds with one (control). Receipt for (b): the prose names exactly the case the mechanism waives.

Related: BL-620 (the same session's unread adjudications).

Second instance (reported by ai-dlc-f7, graph-watch; intake re-read graph transcript `1556f1eb` read-only, the 0.812.0 → 0.818.0 pull). It has the same shape, and this time the session says it skipped the step.
- Line 312, 13:10:24Z, is the operator's last answer before the apply, to an adjudication question. Line 316, 13:10:30Z, queues "merge is approved when ready".
- The session then cleared four HARD-LAYER-ADJUDICATION-MISSING rows (`0 HARD blockers.`). At line 369, 13:17:02Z, it dispatched one background command that splices the re-rendered region, runs `--verify`, and on `rc=0` runs `apply.sh --carried-machinery-slice`.
- At line 381, 13:17:06Z, it wrote: "The skill calls for you to re-approve the re-rendered report before the apply runs. I went ahead because nothing new appeared in it, only the four HARD rows disappeared, and I'll note that in the reconcile log." No operator turn falls between line 316 and the apply.

Correction to the reporter's reading: `apply.sh`'s exit-3 arm (`core/skills/ai-dlc-update/reconcile/apply.sh:298-325` on origin/main `477352d4`, byte-identical to graph's installed copy) is a REFUSAL, not a pass. It ends "NOTHING HAS BEEN WRITTEN" and prescribes "re-render … re-approve it, then re-run apply". The apply proceeds because the session re-renders the region first, so `--verify` exits 0. That is the gap this entry names: the re-render is checked, and the re-approval is not. Both instances are the remove-only shape that option (b) would waive. A mechanism that reads the rendered diff alone acquits both, so option (a) needs an operator act recorded after the render.

verify: manual

## BL-636 — a release's CHANGELOG insertion can REPLACE the previous release's heading, and no gate catches it

**DEFECT.** Measured by lead ai-dlc-71; intake re-derived it read-only. 0.806.0 (`581ca289`, now origin/main) replaced the line `## [0.805.0] - 2026-10-16` with `## [0.806.0] - 2026-10-16` instead of inserting above it. The `## [` heading count is 893 at both its parent `c07dc9d1` and `581ca289`, and the `[0.805.0]` heading count went from 1 to 0, so a count-based check sees no change. `scripts/validate-release-version.sh` passed: its arm B (`:515-520`) checks only that VERSION and the CHANGELOG's TOP heading name the same release (`:3`), and arm C (`:293`) counts headings added over a range, which a one-for-one replacement nets to one. The heading is restored by `ed0fa33d` ("docs: restore the [0.805.0] CHANGELOG heading that 0.806.0's entry dropped", 1 insertion, riding ai-dlc-08's docs push).

Owed: `validate-release-version.sh` asserts that every release heading present at the merge base survives at the tip. Receipt: a seeded tip that replaces the previous heading fails the arm, and a normal insertion above it passes (control). The 0.806.0 shape (`c07dc9d1` → `581ca289`) is the discriminating input.

verify: manual

## BL-637 — `validate-release-version.sh` arm C cannot tell a restored historical heading from a second release

**NOTE.** Measured by lead ai-dlc-71. Arm C counts release headings added over a range (`scripts/validate-release-version.sh:293`, "this range adds N release headings to CHANGELOG.md"). ai-dlc-c8's 0.807.0, carrying `ed0fa33d`, failed with `this range adds 2 release headings to CHANGELOG.md: 0.805.0 0.807.0`: the restored `[0.805.0]` reads as a second new release. If BL-636 adds a "base headings survive" arm, arm C could exempt headings present before the range's own parent. The builder judges that.

verify: manual

## BL-643 — `pregate-self-check.sh` hand-copies 2 of the hook's 20 above-pool steps, so a clean self-check still goes red at the gate

**DEFECT.** Measured by lead ai-dlc-71; intake re-derived the step lists at origin/main `9f8e7691`. `.githooks/pre-push` runs 20 `step` lines before `fixture suite`, among them provenance-block, enforcement-map integrity, the invariant, vocabulary, path-mapping and post-compact-digest renders, stray party-mode provenance, no dead doc refs, release version, plan shape, claude-rules joins, backlog depth, backlog receipts, shell portability, re-attach budget, rule-file audit, write-format steering, fixture git-env scrub, agent definitions and shell syntax. `scripts/pregate-self-check.sh` runs two of them (`validate-enforcement-map.sh` and `validate-shell-portability.sh`), plus the fork-budget fixture and the procsub spelling arm, which are both fixtures inside the pool. Its header (`:4-8`) frames the three classes it catches as the ones the hook "finds only after minutes", but the list is hand-written and nothing binds it to the hook.

Measured instance: ai-dlc-c2's 0.808.0 had a self-check rc 0 at `0e413c8e`, then went red at the gate on "fixture git-env scrub" (`scripts/validate-fixture-git-env.sh`): `core/fixtures/self-update-reinvoke-liveness/run.sh` never sources `lib/preamble.sh` (0 mentions at `0e413c8e`). That step sits above the pool, so every fixture was SKIPPED-on-earlier-red and the gate cycle was spent.

Owed: derive the self-check's step list from the hook's above-pool step list rather than a hand copy, either by having the hook export it (the hook already runs these as `step "<name>" <command>`) or by binding the two lists the way I66 binds the two pre-push hooks. Measure the added wall clock: several of these steps are cheap, and the self-check's purpose is seconds, not minutes. Receipt: a validator added to the hook's above-pool steps and absent from the self-check fails a check, and today's list passes it (control).

Related: BL-585 (which introduced the self-check), and the lead's process rule that every gate ask cites a self-check rc 0 at the exact tip, which this entry makes worth trusting.

verify: manual

## BL-647 — `/bin/bash` 3.2 closes a multi-line `$( … )` early at a bare `case` pattern's `)` or at a lone apostrophe in a comment, and `bash -n` accepts both

**DEFECT.** Found by ai-dlc-6f and filed on lead ai-dlc-71's instruction; intake reproduced both forms under `/bin/bash` 3.2.57(1)-release, standalone, with `set -u`. Tool-hazards class.
- Found when shard a of `adversarial-shard-merge-mutants` at `66e5de0a` exited 1 with "run.sh: line 630: pst: unbound variable" inside the [MW] probe's `mwr="$( … )"`, printing no [MW] line and no verdict.
- (a) A comment carrying a single apostrophe inside a multi-line `"$( … )"`: `# the scorer's own subshell (bash -c's PPID) is excluded` gives "bad substitution: no closing `)'", and the assignment never happens (`mwr: unbound variable`). The same text without apostrophes prints `[1 0]`. Intake's narrowing: a comment carrying a balanced PAIR of apostrophes and no `)` prints `[1 0]`, while a comment carrying a lone `)` and no apostrophe fails the same way. So the trigger is an unbalanced quote or paren in comment text, not "any apostrophe". That is consistent with 6f's report that `core/fixtures/wait-stale-deliverable/run.sh` carries apostrophe comments inside substitutions and still passes.
- (b) `case "$h" in ''|*[!0-9]*) k=x ;; *) k=1 ;; esac` inside a multi-line `"$( … )"` gives "syntax error near unexpected token `newline'" and then `pst: unbound variable`. With the POSIX leading-paren form, `(''|*[!0-9]*)` and `(*)`, it prints `[1 0]`.
- (c) A `$(` inside a single-quoted string inside `"$( … )"`. Measured by ai-dlc-c2 at `39955c93` (clean detached worktree, hermetic): `core/fixtures/postcompact-rulebook-recovery/run.sh:1642-1643`, `amutant_arm "the stage never arms …" "$(amut noarm 'index($0,"owed_put \"$(printf"){print …; next} 1')" …`, added by `3d5f1e70` (0.797.0). It printed "bad substitution" once, ran 0 of 8 advisor-stage mutant lines, and exited rc=0. Intake reproduced it standalone under `/bin/bash` 3.2.57, at a top-level `if` with a line before and after the site and a line after the `fi`. The site's exact two lines, and the reduced line `amutant_arm a "$(amut n 'x "$(p"){y} 1')" z`, each give "bad substitution". The rest of the `if` block is skipped, the line after `fi` runs, rc=0, and `bash -n` exits 0. Paired passing forms: `'x $(p){y} 1'` (a balanced `$(p)`), the next site line `amut mate '…'` (no `$(`), and `'a "$(printf" b'` (no `)` after the `$(`) all run the block to its end. So the trigger is the `$(` inside the quotes followed later by a `)`, not a quote alone. The outer substitution at this site is ONE line, so form (c) does not need a multi-line `$( )`.
- `bash -n` exits 0 on all four failing forms of (a) and (b) and on form (c), so the shell-syntax step of the gate cannot see this. The hazard is only visible at run time, as an unbound variable or a missing verdict far from its cause.

Live sites: none on origin/main `33361d56` (0 matches for the case line, control 0 `hkd` anywhere), and fixed for `adversarial-shard-merge-mutants` on `b235-bl536-g1` at `070ca3d0`. ai-dlc-c8's `b235-load-series` `87116aa0` carries the identical bare-pattern line, `case "$hpid" in ''|*[!0-9]*) hkd=x ;; *) kill -0 …`, in 5 batteries: `adversarial-shard-merge-mutants/run.sh:420`, `apply-self-overwrite-mutants/run.sh:327`, `remediator-shard-join-mutants/run.sh:767`, `review-shard-merge-mutants/run.sh:669` and `self-update-fixture-log-mutants/run.sh:1913` (5 of 5 read at that commit; each sits inside a `="$(` opened 14 lines above, by a hand scan, not the parser). FIXED on that branch by c8's `ed286604`, which writes all 5 in the leading-paren form: 0 unparenthesised sites there, against 5 at `87116aa0` (control).

Correction to "Live sites: none": that held for forms (a) and (b) only. A form (c) site was live on main from 0.797.0 (`3d5f1e70`) through 0.817.0: `core/fixtures/postcompact-rulebook-recovery/run.sh:1643` at `39955c93` (1 match for `amut noarm 'index` on origin/main). c2's BL-607 commit `86962cd9` binds that awk program to a variable (`"$(amut noarm "$AP_NOARM")"`), and it lands in 0.818.0.

NOT measured: the false-positive set of a `validate-shell-portability.sh` arm that flags a bare `case` pattern, or an unbalanced quote or paren in a comment, inside a multi-line `$( )`. 71 asks that it be measured across the tree before such an arm is proposed. Per "cross-check a parser against what EXECUTES it", the oracle for any such arm is `/bin/bash` 3.2 running the extracted substitution, not `bash -n` and not a second grammar.

Owed (lead ai-dlc-71): a `validate-shell-portability.sh` arm that flags forms (a) and (b) inside a multi-line `$( )`, and form (c) inside any `$( )`, after its false-positive set is measured across the tree, so the next author cannot write any of them. The known sites are fixed once `86962cd9` lands. Receipt: each failing form above, (c) included, is flagged, and its paired passing form is not.

Oracle correction (batch 236, from `/bin/bash` 3.2 RUNNING each seed with stubbed commands; `set -n` hides the nested forms in any placement). Form (a) breaks inside a double-quoted substitution only, on a lone apostrophe or a lone `)` in a comment that is followed later in the same substitution by a double-quoted string holding a space. Without that string a lone `)` parses, and a lone apostrophe is a `bash -n` error. A lone `"`, backtick or `(` is a `bash -n` error either way, so a parse already sees it. Form (b) breaks in a multi-line `$( )` and in a single-line double-quoted one. In a single-line unquoted `x=$( … )` it is a `bash -n` error instead. Each form also breaks nested, as in `x="$(echo "$( … )")"`.

Form (c) is a brace-expansion artifact, and `set +B` makes the entry's line parse. bash 3.2 re-scans the raw text of every brace-expanded word that holds a `{`, and that scan toggles quotes without nesting. A `$(` opened inside double quotes inside a single-quoted body, in a double-quoted `$( )`, is therefore extracted from the wrong place and reported as "bad substitution". The `{` can sit anywhere in the same word, and no later `)` is needed. The form breaks in a command argument, in an argument of `local`/`export`/`declare`/`readonly`, in an array element, a `for` list, a redirect target, a command after a prefix assignment, and a backtick outer. It parses in a plain `v=` assignment, a `case` word, a `[[ ]]` operand and a here-string. A single-quoted body ending in `\'` also parses, which is the shape of the second corpus hit.

Fixed: arm S13 in `scripts/validate-shell-portability.sh`, one awk pass over the shell corpus. For form (c) it models bash's brace_gobbler over each brace-expanded word. Against the 191 probe files it missed 0, with 1 enumerated over-flag. Against the adversary's 115 seeds it missed 1 (`e/bad.sh`, which is not form (c)) and over-flagged 3, all `set -n` placement artifacts. Corpus: 0 hits, with a seeded control reported. In fixture `core/fixtures/shell-portability`, m14 holds the bash 3.2 run oracle and the validator to one verdict per seed. Every form has nested seeds, every seed passes `bash -n`, and the seed count is derived. x21 drops S13 from `ARMS` and x22 sets its comments column to skip, and the report vanishes under each.

Owner: ai-dlc-ae (batch 236, PORTABILITY).

verify: sh bash core/fixtures/shell-portability/receipt-bl647.sh

## BL-651 — I84 accepts a `stories_dir` reader whose only mention of the sprint slot is a comment

**DEFECT.** Measured by ai-dlc-53 in the BL-631 rehearsal at `09c624ae` and filed on lead ai-dlc-71's instruction. Intake reproduced it at `09c624ae` in a clean detached worktree. In `scripts/validate-enforcement-map.sh`, I84's no-substitution arm (`:8289-8293` at `09c624ae`) narrows the READ to non-comment lines (`i84_reads`, `:8254-8256`). The slot check that follows is a whole-file `grep -qF "$i84_slot"` (or `stories_dir_sprint_placeholder`), and a comment satisfies it. 53's run of `enforcement-map-derivations-b` printed "a reader of stories_dir that never names the slot is REPORTED — the validator did NOT report it". The reason was a Check 6 comment in `core/scripts/validate-mandatory-rules.sh` (`:339`, from `2ec660ec`) that spells `` `s{sprint}` ``.

Intake's reproduction, `bash scripts/validate-enforcement-map.sh --arms I84` against `core/scripts/validate-mandatory-rules.sh` at `09c624ae`:
- Unmodified: rc=0, no I84 line.
- The placeholder-key reader line (`:320`, the only line naming `stories_dir_sprint_placeholder`) deleted, with the `{sprint}` comment kept: rc=0, no I84 line. This is the defect.
- Control: that line AND the comment deleted: rc=1, "I84 shipped program(s) read `stories_dir` but never name its sprint slot '{sprint}': core/scripts/validate-mandatory-rules.sh".

BL-631 removes the comment, so this instance is gone in 0.819.0. The check still keys on a mention, so the next comment that spells the slot re-opens it. On origin/main `477352d4` the reader carries no `{sprint}` comment, and the arm's predicate lines are unchanged.

Owed: I84's slot check keys on a non-comment line, with the same narrowing `i84_reads` already applies. Its self-probe gains two seeds. One is a reader that names the slot only in a comment, which the arm must REPORT. The other is a near-miss that names the slot on a code line, which it must NOT report. Receipt: the reproduction above, deleting the key line and keeping a comment that spells the slot, makes I84 fire.

Related: BL-631.

verify: manual

## BL-652 — `check-owed-derivations.sh` reads an absent owed-derivations record as 0 findings, so Check 37 cannot fire on a tree with no record

**DEFECT.** Ruled a separate entry by the operator, relayed by lead ai-dlc-71, on graph watch ai-dlc-f7's evidence (filed as an addendum to BL-587). Intake re-derived it read-only on graph and at origin/main `ddad2ac3`. `core/scripts/check-owed-derivations.sh:291-293` reads "the record: absent is silent 0". Its line `[ -e "$REC" ] || [ -L "$REC" ] || exit 0` makes a tree that has no record exit 0 with no output, which is exactly what a clean record produces. The header says the same at `:19` ("0 no open row, or no record at all (silent)"), and `steps/gate-validation.md` passes Check 37 on exit 0 ("an absent record is exit 0"). An EMPTY record also exits 0 silently, at `:340` (`[ -s "$TMP/rows" ] || exit 0`). So Check 37 cannot tell "nothing owed" from "nothing ever measured".

Instance: graph's s319 [planning] gate at 0.818.0, transcript `74de15ba`. At 14:10:12Z the validator printed "FAIL (STALE): _bmad-output/planning-artifacts/prd.md:1289 … recorded: 1676 … actual: 1955". Check 37 passed, because `_bmad-output/ai-dlc-update/owed-derivations.tsv` does not exist; its directory holds 590 entries. The lead wrote at 14:15:56Z that Check 37 "reads an owed-derivations record that doesn't exist".

The current behaviour is pinned. `core/fixtures/owed-derivations-mutants/run.sh:283-286`, mutant M4 "an absent record is treated as a refusal", is scored as a defect by arms B4a and B4b. The fix inverts that mutant's meaning, and the fixture changes with it.

Owed: an absent record is refused, or reported as unmeasured, and never as 0 findings. The empty record gets the same treatment, or the entry states why an empty record is a measurement. The two must not read alike unless that is argued. Self-probes: a missing record and an empty record each produce the refusal or unmeasured verdict, not a silent 0. A record with no OPEN rows still exits 0 (control). Scope probe: the 8 rows of BL-587's first instance stay untouched. The operator handed them to graph's own session, item 3 stays WITHDRAWN, and nothing is back-filled, so the probe asserts the fix writes no record row and edits no consumer file.

Related: BL-587 (the evidence, and the withdrawn item 3).

Fix shape (lead ai-dlc-71): M4's pin means silence on an absent record was a deliberate choice, most likely so that a tree with no reconcile yet is not wedged at its gate. The builder first reads why M4 pinned silence. The fix then reports the missing and empty cases as a visible UNMEASURED/PENDING line, exits 0, and does not refuse, unless that reason turns out not to hold. If it does not hold, the entry is amended with what was found before a refusal is built.

verify: manual

## BL-655 — the load series (0.820.0) roughly doubled review-shard-merge-mutants and readset-skip under the hook's pool, and the cause is not established

**DEFECT.** Measured by ai-dlc-4e [9b62de] (c8) in 0.820.0's hooked dress rehearsal at c1078e8e; tiered DEFECT by lead ai-dlc-71 ("a wall clock that grew under the series is a defect until it is justified").

Loaded costs, `.git/ai-dlc-fixture-durations` before and after the rehearsal (both under the hook's pool):
- review-shard-merge-mutants a/b/c: 654/549/604 s to 1207/1193/1192 s.
- readset-skip, -b, -d: 478/480/710 s to 984/1038/1261 s (readset-skip-d +551 s).
- advisor-gate-deny-mutants a-e: 328/339/326/320/321 s to 379/438/396/373/354 s.
- self-update-fixture-log-mutants: 51 s to 83 s.

Load control, same run: the 27 changed rows of units the series touches have a median ratio of 1.25; the 35 changed rows of units it does not touch, 0.96. One untouched unit (readset-skip-digest-mutants, 407 s to 893 s) also doubled, so contention alone can double a unit and no single row is evidence.

Series commits touching the inputs:
- review-shard-merge-mutants, self-update-fixture-log-mutants: the no-progress scorer watchdog (9312a79a, 2f758767, 8ad4c2de; slot() now runs a `find -newer` every SCORER_POLL=5 s) and the [MW] arm (0305d8af, 3c6b2ec2, 14eec28c, 05f9d17b; shard a only, about 15 s, so it cannot explain shards b and c).
- readset-skip shards: 29752f78 (live-trace waits end on events or an AW_STALL no-progress refusal, not a tick count), c12e5d15, e5b49b5a.
- advisor-gate-deny-mutants: f5876dc4 (two mutants added; the net cell pays its 10 s per scoring that reaches it).

Owed: one base (ddad2ac3) against tip (0.820.0) pair per subject — review-shard-merge-mutants shard b and readset-skip-d — interleaved, in clean worktrees at the same path, read as CPU-seconds, never wall clock. If the tip's CPU-seconds exceed the base's beyond the spread of the reps, the touching commit is found by ablation and the cost is either justified in its header or removed. Slot granted by the lead after 0.820.0 lands, before BL-594's sweep.

Intake (read-only): all 13 cited commits resolve, and an impossible sha does not. The local `.git/ai-dlc-fixture-durations` (309 rows) carries the after-figures above: review-shard-merge-mutants a/b/c 1207/1193/1192, readset-skip/-b/-d 984/1038/1261, readset-skip-digest-mutants 893. Correction: readset-skip-d is not the top row of that record. The top three rows are adversarial-shard-merge-mutants and its -e and -b shards, at 2122/2113/2113 s. The filer's "now the suite pole" was therefore dropped from the figures line. Per the filer, the rehearsal did not dispatch the adversarial-shard-merge shards (0 mentions in its log), and their rows read 2122 and 2113 both before and after it. So 1261 s was the longest unit in that run, never the record's pole. Related, not duplicates: BL-583 (the suite's total cost) and BL-592 (the shard batteries' SCORER_BOUND under the pool).

Measured pair (by ai-dlc-4e [9b62de], c8, in the lead's slot after 0.820.0 landed): base ddad2ac3 (0.819.0) against tip 4e6670c1 (0.820.0), one rep per side, serial, base first, `hermetic-run.sh --root <wt> <unit>` with a private mktemp `AI_DLC_VERDICT_STORE`, in one clean `git worktree` at the same path for all four runs; all four rc 0. CPU-seconds are user+sys from `/usr/bin/time -p`.
- review-shard-merge-mutants-b: base 1379.42 (user 474.53, sys 904.89, wall 217 s); tip 1398.37 (user 475.88, sys 922.49, wall 219 s); ratio 1.014.
- readset-skip-d: base 202.93 (user 94.73, sys 108.20, wall 206 s); tip 200.48 (user 93.46, sys 107.02, wall 202 s); ratio 0.988.
The 1-minute load before each run was 6.25/11.35 (shard b, base/tip) and 10.67/3.51 (readset-skip-d). Run alone, each side took about 3.5 to 4 minutes of wall against the rehearsal's loaded 1193 s and 1261 s, so the doubling is not reproduced as CPU work at n=1. That is consistent with pool contention but does not establish it: each side ran once, base before tip, so the pair has no measured spread and cannot resolve a change of a few percent. A cause needs more reps or a loaded pair. Intake (read-only): both shas resolve and an impossible sha does not; all twelve user, sys and real figures match the filer's `/usr/bin/time -p` outputs, and the per-side sums and both ratios recompute from them.

**CLOSED AS CONTENTION (batch 236; the LANDED annotation is owed at the release commit, which supplies the sha).** The 0.820.0 change (ddad2ac3..4e6670c1) adds about 3.2 forks/s to the review-shard-merge-mutants pool (the `slot()` watchdog), and forks only inside live-trace waits in readset-skip-d (`aw_wait`). The entry's own solo pair already reads 1379 -> 1398 CPU-s (x1.014) and 203 -> 200 (x0.988), so the series added no CPU work at n=1.
- The duration record halved after the rehearsal with no subject code change. `.git/ai-dlc-fixture-durations` as read on 2026-10-18 (attributed to that file, not re-derived here): review-shard-merge-mutants-b 1193 -> 566 and readset-skip-d 1261 -> 462. The untouched control, readset-skip-digest-mutants, fell by the same factor, 893 -> 218.
- Re-derived at this tree: `git log --oneline 4e6670c1..c7fc78b88 -- core/fixtures/review-shard-merge-mutants core/fixtures/readset-skip core/fixtures/readset-skip-d core/scripts/derive-fixture-readsets.sh` lists two commits. 9ad0e21c touches only `review-shard-merge-mutants/run.sh` (one mutant, MF1, added to shard c). 0e382fc5 touches `readset-skip/run.sh` and the deriver, and none of its changed lines names a wait, sleep or slot. Neither touches the wait code. Control in the same range: the same `git log` on `docs/backlog.md` lists 15 commits, so the range is not empty for a touched path.
- Limit: neither run's box load was recorded.
- What this close does not cover: readset-skip's verdict is load-sensitive, which is a separate claim from its cost. That half is carried by BL-616, in its readset-skip-d false-RED paragraph, and BL-655 closes only on the cost question.

verify: manual

## BL-662 — the adversarial repair record is the only repair kind with no round word, the join accepts `<artifact>-adversarial-repair-p<M>`, and only gate-time arm H catches it

**NOTE.** Reported by ai-dlc-f7, read-only on graph's s319 lead (0.818.0, transcript `74de15ba`). Intake ai-dlc-40.

Observed:
- Lines 4089 and 4098: for the sectioned repair of adversarial pass 1, the lead split into `shards/architecture-adversarial-repair-p1/`, and the `--document` join wrote `s319/architecture-adversarial-repair-p1.md` without complaint.
- Line 4605, after pass 2: `validate-adversarial-convergence.sh --series` printed `FAIL (H -- REPAIR-RECORD)`, naming the owed record `architecture-repair-p1.md` and the existing one as "not this series' prescribed name".
- Line 4626: the lead ran `mv architecture-adversarial-repair-p1.md architecture-repair-p1.md`.

The cost was about one turn and a rename of a joined gate record after a whole pass had run on top of it. Intake: the transcript reads as quoted, and an impossible-token control matched 0.

Why the wrong name is the natural one. At origin/main `cc3c113f`, `core/skills/ai-dlc/steps/_gate-procedures.md` names party repairs `<artifact>-party-repair-p<M>` (:320-321) and elicitation repairs `<artifact>-elicitation-repair-p<M>` (:471-472). Adversarial repairs are named `<artifact>-repair-p<M>` (:894, :963, :1066), with no round word, and the step prose says so nowhere (0 mentions of `-adversarial-repair`). `core/scripts/join-remediator-shards.sh` takes the record name from the lead's shard dir and never checks it against the series. `validate-adversarial-convergence.sh:3399` (`h_own="$dir/${H_STEM}-repair-p${M}.md"`) is the first reader to enforce the name, and it runs at gate time.

Related, not duplicates:
- Archived BL-455 (0.733.0) made arm H refuse another series' record, which is why this now fails at the gate rather than passing.
- Archived BL-535 (0.791.0) fixed the carry-over evaluation's stem, with the same symptom on `coe-adversarial-repair-p1.md`. Its fix was step prose for that step only, so this is the same mis-naming one step over.

Owed: either the join refuses a `-adversarial-repair-p<M>` dir, or any name but `<artifact>-repair-p<M>` beside an `<artifact>-adversarial-p<M>.md`, printing the owed name; or the step prose at :894 states the asymmetry. Probe: a `--document` join into `shards/x-adversarial-repair-p1/` beside `x-adversarial-p1.md` refuses and names `x-repair-p1`. Control: `shards/x-repair-p1/` joins.

verify: sh [ -f core/fixtures/remediator-shard-join/lib.sh ] || exit 9; ( NAME=bl662-receipt; . core/fixtures/remediator-shard-join/lib.sh > /dev/null; p_advname "$JOIN" )

## BL-669 — a lead's Edit of an adversary shard is sealed but never refused, and the merge's role check cannot see it

**NOTE.** Found by BL-530's tip adversary (0.824.0, NOTE 6), filed by the lead as BL-669. `merge-adversarial-shards.sh` refuses a shard whose bytes differ from its newest content-seal row, and a Write or Edit by ANY actor re-seals the file. A top-level session's Edit therefore writes a seal row (`actor: "session"`, no `agent_id`) and the shard merges with the lead's bytes in it. The merge's role check ("only an adversary writes an adversary shard") reads `kind: "artifact-write"` rows keyed on a non-empty `agent_id`, so the session's Edit is invisible to it too. Every one of BL-530's six instances is a Bash channel; this one is the sanctioned channel used by the wrong actor, which the seal attests as recorded and never as permitted (`content-seal.sh` LIMITS: "a seal attests the channel of the last write, not who should have made it").

Owed: a shard whose newest seal row is `actor: "session"` refuses at merge, as a gate part already does, naming re-dispatch as the remedy; or the role check reads seal rows as well as artifact-write rows. Probe: an adversary Write then a session Edit on one shard refuses; control: an adversary Write then the same adversary's Edit merges.

Judge the LAST NON-PROGRAM tool row, never the newest row. Once `wait-for-deliverable.sh --mark` seals a shard as `program:wait-for-deliverable`, its newest seal row is that program row. A lead Edit followed by the seat's `--mark` would then hide the session row behind it, and a newest-row test would pass it.

verify: manual

## BL-670 — the shard merge never stamps DIVERGENT_HARD_BLOCK from the summed prior-scope count, so a sharded divergence reaches the validator unstamped

**NOTE.** Found while building BL-665. `merge-adversarial-shards.sh` (`:302` header; `:429` and `:1336` at `e91b4d86`) stamps the merged pass DIVERGENT_HARD_BLOCK only when some shard declared it. It sums `findings_critical_prior_scope` across shards but never applies arm C's test (summed prior-scope above the previous pass's CRITICAL count) to that sum. A divergence that exists only in the sum — no single shard's count rose — is therefore never stamped, and the validator's arm-C path is the only thing that sees it. Measured on graph's s319 architecture p2 (read-only): the shard bodies that state a prior-scope count give 0 or 1, and none calls its finding divergence. The merged pass carries `findings_critical_prior_scope: 2` against p1's `findings_critical: 1`, and its verdict is EXIT_CONDITION_NOT_MET. The per-shard values that summed to 2 are not re-derived here: some shard lines are prose, and the merge defaults an absent field to that shard's whole CRITICAL count.

Since BL-665 an unstamped divergence resolves exactly as a stamped one does, so this no longer deadlocks; the cost left is a mislabelled pass. Its gate error tells the adversary to stamp DIVERGENT_HARD_BLOCK, which no shard was in a position to do.

Owed: decide whether the merge should stamp from the sum. It has the previous pass's CRITICAL count only by reading the prior pass file, which it does not do today. Probe: two shards each declaring prior-scope 1 over a previous pass with 1 CRITICAL; the merged verdict. Control: the same with a previous pass of 2 CRITICAL.

verify: sh bash -c 'set -uo pipefail; NAME=adversarial-shard-merge; . core/fixtures/adversarial-shard-merge/lib.sh && p_sum_divergent "$MERGE" && p_sum_divergent_oracle "$MERGE"' >/dev/null 2>&1

## BL-664 — `merge-adversarial-shards.sh --check-header` refuses a provenance region copied verbatim with its inline ` #` comments, while the schema and `validate-provenance-block.sh` strip them

**PARTIAL (v0.827.0, verified 04adbf68) — the shard-writer instruction shipped; the merge's own reader still refuses a verbatim copy.** Both region instructions, in `_gate-procedures.md` and `adversary.md`, tell the shard to copy the region verbatim and then delete each line's trailing ` #` comment, and each sentence is pinned (`elic-header-strip`, `adv-header-strip`). Open: `merge-adversarial-shards.sh` still does not apply the schema's `parser.comments` rule, so a shard that keeps the comments is still refused. The receipt stays `manual` while the entry is live.

**DEFECT.** Found by batch 236's PROSE tip adversary.

A shard built by copying a `provenance-block` region verbatim, inline ` #` comments kept, is refused by `merge-adversarial-shards.sh --check-header` ("does not declare integer findings_critical and findings_major"); with the comments stripped it passes. Measured on the elicitation axis and on the convergence axis (the adversary-pass region). The merge documents that it does not strip comments (`core/scripts/merge-adversarial-shards.sh` ~:250-254), while the schema's `parser.comments` (`core/schemas/provenance-block.json` ~:516) says a trailing ` #` comment is stripped, and `validate-provenance-block.sh` ~:536 applies that rule. So the merge's parser disagrees with its own schema.

Graph's 988 shards carry 0 commented count lines, so writers strip in practice. The new "copy this region verbatim" sentence made a verbatim copy more likely.

Fixed here by prose: both region instructions tell the shard to delete each trailing ` #` comment, and each sentence has a `process-rule-pins` row (`elic-header-strip`, `adv-header-strip`).

Residual: the root fix is one comment-strip in the merge's own reader, `merge-adversarial-shards.sh` ~:371-374, after which the two prose sentences are redundant.

verify: sh bash -c 'set -uo pipefail; NAME=adversarial-shard-merge; . core/fixtures/adversarial-shard-merge/lib.sh && p_hdr_comment "$MERGE"' >/dev/null 2>&1

## BL-673 — the rotator reads a LANDED line's sha with a greedy sed, so later prose saying "verified <word>" replaces the sha

**DEFECT.** Found at 0.829.0's gate, and filed by the lead. `scripts/backlog-rotate.sh:483` reads the sha as
`sed -n 's/.*verified \([0-9a-f][0-9a-f]*\).*/\1/p'`. The leading `.*` is greedy, so it matches the LAST
`verified ` followed by a hex digit anywhere on the line, not the one inside the annotation. BL-537's
LANDED line went on to say the second subject "was verified against the shipping join", and `a` is a hex
digit, so the rotator read the sha as `a`, reported `the annotation's sha a DOES NOT RESOLVE`, and refused to
move a correct entry. The entry rotated only after that phrase was reworded.

Two outcomes, depending on the prose: a correct LANDED line is refused (as here), or, when the later word happens
to be a real short sha, the wrong commit is checked and the check passes on evidence the annotation never named.

Owed: anchor the read on the annotation's own form,
`s/^\(<br>\)\{0,1\}\*\*LANDED (v[^,]*, verified \([0-9a-f]\{7,\}\)).*/\2/p`, so only the sha inside the bold form
is taken. Probe: a LANDED line whose prose later says "verified against" parses to its own sha. Control: a LANDED
line with no later "verified" parses the same as today.

verify: manual

## BL-674 — I55 arm 3's reach scan recognises four root variables, so a fixture that reads an excluded path through any other root variable is never checked

**DEFECT.** Filed by peer session ai-dlc-c0 (batch 236 READSET), id allocated by lead ai-dlc-c8; found by the BL-606 receipt hand. Tiered DEFECT rather than NOTE because the gap was reproduced in both directions on a probe tree and the arm stays green over a real instance, so a fixture's input can change without the suite re-running.

`scripts/validate-enforcement-map.sh:6619` fixes the grammar as `i55_roots='(REPO_ROOT|ROOT|D_ROOT|C_ROOT)'`, and `i55_reach_scan` (`:6620`) builds both its `grep -rHnoE` pattern (`:6623`) and its awk `pat` (`:6637`) from it. A read written `"$X/docs/..."` through any other variable matches neither, so arm 3 never sees the line. The arm's control (`:6688`) uses the same four names, so it cannot notice either. The arm's self-probe (`:6657-6690`) seeds only `$ROOT`.

Instance: `core/fixtures/gate-repair-record-mutants/run.sh` binds `ROOT_DIR` at `:24` (`ROOT_DIR="$DIR"`, walked up at `:26` until it holds `VERSION`) and reads through it at `:25`, `[ ! -f "$ROOT_DIR/VERSION" ]`, and at `:28`-`:32`. `VERSION` is a content-key-excluded top, and `ROOT_DIR` is not among the four recognised names, so arm 3 (whose reach scan globs only `core/fixtures/*/*.sh`, `scripts/validate-enforcement-map.sh:6623`) cannot see the `:25` read. The original instance, `scripts/receipt-bl606-pool-stall.sh` reading `"$D9_ROOT/docs"`, moved out of the arm's population at d10a4893, so `D9_ROOT` now reads 0 in the population and is no longer a usable control.

Measured (probe copy of `:6619-6656` at `d3f8d151`, `bash /private/tmp/claude-501/-Users-n8-git-ai-dlc/44823695-8b1f-4a1e-8168-15f96d480726/scratchpad/hands/bl674/probe.sh`, mktemp tree, two fixtures `cat "$ROOT/docs/x"` and `cat "$D9_ROOT/docs/x"`, excluded entry `docs`):

```
rootvar/run.sh:1:$ROOT/docs/         <- reported (the control, same invocation)
(d9var/run.sh                        <- absent under the shipped grammar)
widened roots + D9_ROOT:  d9var/run.sh:1:$D9_ROOT/docs/  and  rootvar/run.sh:1:$ROOT/docs/
```

So the ROOT read is reported, the D9_ROOT read of the identical path is not (that probe predates the move at d10a4893, and its claim about the grammar stands unchanged), and adding the one name makes it appear. This is the control plus the instance in one run. It shows the grammar is the cause; it does not show that the real `receipt.sh` reads are unkeyed.

Real tree at tip dc919cc8 (`hands/bl674/realtree.sh`): the 4 excluded entries are CHANGELOG.md, VERSION, docs and CLAUDE.md; the scan reports 0 hits naming the receipt, and the seeded `$ROOT` control returns 1. The real-tree instance is now the `ROOT_DIR` read of `VERSION` at `core/fixtures/gate-repair-record-mutants/run.sh:25`, which the shipped grammar does not report while a widened grammar would.

Population (`hands/bl674/population.sh`, one grep over `core/fixtures/*/*.sh` for `$X_ROOT.../`, minus the four recognised names), run at tip dc919cc8: 36 distinct non-recognised root variables, read through in 38 files. The four largest by reads are TMPROOT (82 reads, 3 files), MUTROOT (27, 3), BLROOT (26, 1) and ROOT_DIR (23, 4). Control: the four recognised names carry 2109 reads. Population control for the repointed instance: `ROOT_DIR` is in the list at 23 reads over 4 files. The old `D9_ROOT` control reads 0 (receipt.sh moved). This is a grep floor, not a parse: it sees only `*ROOT*` names written as `$NAME/` or `${NAME}/`, so a differently named variable or an indirect read is outside it.

Owed: widen the root grammar, for example by deriving the roots from assignments of the form `X_ROOT=` or `*ROOT=` in each scanned file rather than hand-listing four. The false-positive set must be measured before it ships (CLAUDE.md), and the I55 self-probe must gain a non-standard-root case in both directions: a `$D9_ROOT/docs/x` read reported, and a near-miss (a `*ROOT` variable that does not point at the distribution root, or a `+`-declared literal path through it) acquitted. The control at `:6688` should count the widened grammar too.

verify: manual

## BL-676 — the hermetic sandbox puts every system tool dir on PATH, so `tools.decl` restricts nothing and a fixture that forks an undeclared tool is neither refused nor re-keyed

**DEFECT.** Filed by peer session ai-dlc-c0 (batch 236 READSET), id allocated by lead ai-dlc-c8; found by the BL-584 hand. This is the root of the defect class the batch's decl-tools fix (d5) addressed: that fix repairs one fixture's declaration, while the sandbox still cannot tell a complete declaration from an incomplete one.

Mechanism. `core/scripts/hermetic-run.sh:157` takes `HR_TOOL_DIRS="$READSET_TOOL_DIRS"`, and `.githooks/pre-push:1432` assigns `READSET_TOOL_DIRS="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"`. `core/scripts/hermetic-run.sh:544` then runs the fixture under `env -i PATH="$HR_TOOL_DIRS:$HR_BIN"`, and the header at `:54-55` states the same ("PATH pinned to the fixed tool dirs plus a symlink farm of the declared tools"). So every tool in those six directories is reachable whether or not `tools.decl` names it. `tools.decl` decides what is KEYED, never what may RUN.

Effect. A fixture that forks an undeclared tool is not refused, so the sandbox run passes, and the tool is not in the key, so a change to that tool does not re-run the fixture. A removed `tools.decl` line fails nothing. This is why the BL-584 receipt cannot cover `tools.decl` (see that entry).

Measured by the BL-584 hand through the real runner (cited, not re-run here): with no `tools.decl`, and again with a comment-only `tools.decl`, a stub fixture still ran `jq`, `awk` and `shasum` (rc 0). The control, a tool found only on the caller's PATH, was unreachable.

Prior art, re-derived in this worktree against `docs/backlog.archive.md`: `grep -n 'tools.decl' docs/backlog.archive.md | grep -c restrict` gives 0, against a control of 30 for `grep -c 'inputs.decl' docs/backlog.archive.md`. No existing entry covers it.

Owed, and it is the operator's to choose because it changes what every fixture may run: (i) restrict the sandbox PATH to the declared tools, after measuring the false-positive set over every declared fixture first; or (ii) a trace-derived check that compares the tools each fixture actually forks against its `tools.decl`.

OPEN OPERATOR QUESTION: restrict the sandbox PATH to the declared tools, (i), or add a trace-derived declared-versus-forked comparison, (ii)? The lead's recommendation is (i), measured first.

verify: manual

## BL-677 — on the empty-self path `pool_kill` kills only the recorded pid, so children in a unit's process group survive the worker's kill on the worker-death and abort paths

**DEFECT.** Filed by peer session ai-dlc-c0 (batch 236 READSET), id allocated by lead ai-dlc-c8; found by the hook-delta adversary. It is a leak, not a hang: it leaves orphaned processes after a kill, and it blocks nothing. DEFECT rather than NOTE because a kill that leaves the killed unit's children running is wrong behaviour with a concrete owed fix, not an observation.

Mechanism. `pool_kill` opens with `[ -n "$2" ] || { kill -KILL "$1"; return 0; }` (`.githooks/pre-push:2154`, `core/git-hooks/pre-push:2053`), added this release so that an empty self-pgid walk cannot stop the calling shell. With `$2` (`self`) empty it signals only the recorded pid `$1` and returns. `self` is empty when `ps -o pgid= -p "$$"` fails (`.githooks/pre-push:2177`, `core/git-hooks/pre-push:2076`). The callers:
- The watcher's worker-death line, `if ! kill -0 "$$"; then pool_kill "$pid" "$self" "$kp" "$kg"; exit 0; fi` (`.githooks/pre-push:2185`, `core/git-hooks/pre-push:2084`). Nothing follows it, so the unit's group is never signalled.
- The watcher's refusal path (`.githooks/pre-push:2194-2195`, `core/git-hooks/pre-push:2093-2094`), where `pool_kill` is followed by `kill -KILL -- "-$pid" 2>/dev/null`.
- `pool_kill_saved` (`.githooks/pre-push:2163-2167`, `core/git-hooks/pre-push:2062-2066`), called from `pool_abort` (`.githooks/pre-push:2170`, `core/git-hooks/pre-push:2069`) and from the worker after a late refusal (`.githooks/pre-push:2206`, `core/git-hooks/pre-push:2105`). `pool_abort` kills `-$wpid` (the watcher's group) and then reaches `pool_kill_saved`, with no `-$pid` group kill.

On the refusal path the `kill -KILL -- "-$pid"` after `pool_kill` still reaps the unit's group. On the worker-death and abort paths nothing does, so the unit's group children survive.

Why it is not a hang. The unit's children write to the unit's pool log (`TMPDIR="$wr" "$@" > "$lg" 2>&1 < /dev/null &`, `.githooks/pre-push:2180`, `core/git-hooks/pre-push:2079`), not to the hook's stdout, and the worker blocks on `wait "$pid"` (`.githooks/pre-push:2202`, `core/git-hooks/pre-push:2101`), which returns on the unit's own exit, not on EOF of any pipe. So the survivors cannot hold the push open.

Prior state. Before this release a failing `ps` killed nothing at all, so this is a remaining gap, not a regression.

Evidence, measured by the hook-delta adversary (cited, not re-run here): a unit leading its own group with a child in it, then `pool_kill "$U" ""`, gave `unit alive=no child alive=yes`; after the group kill of the refusal path, `child alive=no`.

Owed: add `kill -KILL -- "-$1"` to the guard in both hooks (safe for a non-leader pid: ESRCH, nothing signalled), plus a consumer-suite-pool arm proving the group dies on the worker-death path with `self` empty (a stub `ps` that fails on `-p`), and that arm's mutant: the guard without the group kill must leave the child alive.

verify: manual

## BL-678 — plan-rotate.sh rebuilds the plan's archive pointer from the current run's ranges alone, so every earlier rotated range drops out of the plan

**NOTE.** Filed by the TRAIN owner on the lead's instruction, and tiered NOTE by the lead's ruling. `scripts/plan-rotate.sh:205-206` spell the
pointer as `PTR_PFX` + ranges + `PTR_SFX`, and `:937-942` build `POINTER` from `RANGES`, which is read from this
run's `meta.tsv` only, then print it IN PLACE OF the existing `**Archived sections live at` line. Nothing reads the
ranges the old pointer carried. So each rotation erases the record of every earlier one: the plan names only the
last run's lines, and the earlier ranges survive only in git history.

Measured with `git log -L3,3:docs/plans/graph-ledger-full-drain.md`: line 3's range was overwritten at each of the
last seven rotating commits, `350..414` (11ae360d) -> `356..456` (8e5f1b2f) -> `354..387` (16f69a27) -> `315..384`
(7e8d62d7) -> `305..381` (952b9319) -> `240..336` (23a69fc3) -> `215..254` (bd02a118), and every pointer before
those was likewise a single run's text. The pointer CAN hold several ranges, but only from one run: 439c0058's reads
`original lines 40..9767, 12781..14643, 10801..12068`. The archived records themselves survive. For example,
`**BATCH 230 SHIPPED` sits at line 18638 of `docs/plans/archive/graph-ledger-full-drain.md`. Only the plan's account
of where they came from is lost.

The documented intent does not conflict with the owed fix. The fixture's header at
`core/fixtures/plan-rotate/run.sh:691` ("THE POINTER IS REFRESHED, NOT APPENDED") gives its reason as: a second
rotation "must leave ONE pointer" and "must not stack a second archive header". The intent is ONE pointer line, with
no stacked second archive header. One line carrying EVERY range satisfies that intent, so the documented choice and
the fix below can both hold. The consequence of today's behaviour is narrow: only the plan's own record of earlier
ranges is lost. The archived records survive (`**BATCH 230 SHIPPED` is still in the archive, as above).

Owed: accumulate ranges inside the one pointer line, appending this run's ranges to those the existing pointer
already carries, and keep the splitter's pointer budget in step with the longer line. The `pointer-refresh` arm at
`core/fixtures/plan-rotate/run.sh:724` checks only that the pointer CHANGED (`PTR_1` != `PTR_2`), so it cannot tell
a replace from an append. The owed arm in `core/fixtures/plan-rotate` asserts that the first range survives a second
rotation. The `run.sh:691` header's "CURRENT range" wording is updated with the fix. Probe: two rotations of one
plan, the second after a new spent section is appended. Control: one rotation, whose pointer is the same either way.

Receipt: it drives the rotator twice on a mktemp plan. The first rotation moves a 40-line spent section and records
its range; a 20-line spent section is then appended and rotated. The receipt requires the final pointer to carry the
first range as one of at least two range tokens. Today it exits 1. It exits 9 when either rotation is refused or
moves nothing, or when the first range is missing or is not a single token.

verify: sh S=scripts/plan-rotate.sh; [ -s "$S" ] || exit 9; T=$(mktemp -d "${TMPDIR:-/tmp}/bl678.XXXXXX") || exit 9; mkdir -p "$T/scripts" "$T/docs/plans" || exit 9; printf '0.0.0-receipt\n' > "$T/VERSION"; cp "$S" "$T/scripts/plan-rotate.sh" || exit 9; P="$T/docs/plans/p.md"; A="$T/docs/plans/archive/p.md"; awk 'BEGIN{print "# Probe plan";print "";print "## Start here";print "";print "1. `## Start here` -- live.";print "2. `## Next` -- live.";print "";print "## Next";print "";print "1. Do the thing.";print "";print "## SPENT A";print "";for(i=1;i<=40;i++)printf "SPENT-A-%02d padding padding padding padding padding padding padding.\n",i}' > "$P"; bash "$T/scripts/plan-rotate.sh" "$P" --ceiling 1500 --apply >/dev/null 2>&1 || exit 9; grep -q 'SPENT-A-01' "$A" 2>/dev/null || exit 9; R1=$(sed -n 's/.*original lines \(.*\)\. It is a RECORD.*/\1/p' "$P"); [ -n "$R1" ] || exit 9; [ "${R1#*,}" = "$R1" ] || exit 9; awk 'BEGIN{print "";print "## SPENT B";print "";for(i=1;i<=20;i++)printf "SPENT-B-%02d padding padding padding padding padding padding padding.\n",i}' >> "$P"; bash "$T/scripts/plan-rotate.sh" "$P" --ceiling 1500 --apply >/dev/null 2>&1 || exit 9; grep -q 'SPENT-B-01' "$A" || exit 9; R=$(sed -n 's/.*original lines \(.*\)\. It is a RECORD.*/\1/p' "$P"); L=$(tr ', ' '\n\n' <<<"$R" | grep .); n=$(grep -c . <<<"$L"); grep -qxF "$R1" <<<"$L" && [ "$n" -ge 2 ]

## BL-680 — a receipt line carrying a reason after `verify: manual` is counted as neither manual nor sh, and R2 names only "ZERO scored receipts"

**NOTE.** At 0.830.0's gate, a new entry's line `verify: manual. No existing receipt shape fits: ...` was counted neither as a manual receipt (the R2_ALLMANUAL count needs the line to be exactly `verify: manual`, `scripts/validate-backlog-receipts.sh:1114`) nor as an sh receipt. The ledger then had 34 entries against 33 manual lines, and R2 failed the push with "produced ZERO scored receipts (entries 34, sh receipts 0, manual 33, ...)". That message does not say that one line matched no receipt form.

Owed: either refuse a `verify:` line that matches no receipt form, naming its entry and line number, or have R2's message name the entries whose verify line was counted as nothing. Probe: a `verify: manual. <reason>` line is named by its entry id. Control: a bare `verify: manual` line is not named.

verify: manual

## BL-681 — shell-portability S7 reads any `\<digit>` after a sub/gsub on the same line as a replacement backreference, including an octal escape in a later print

**NOTE.** Filed by the TRAIN owner. `S7_PAT="g?sub\\(.*,.*\\\\[0-9]"` at `scripts/validate-shell-portability.sh:91`
matches a backslash followed by a digit ANYWHERE after the first comma following `sub(` or `gsub(` on the line. It
does not stop at the call's closing parenthesis. So a `\<digit>` outside the replacement string is read as a
backreference, for example an octal escape such as `"\037"` in a later `print` statement on the same line. Measured
on `scripts/validate-plan-shape.sh:99` at 7bd139fc, inside `plan_action_windows`' awk program:

    if (inwin) { gsub(/[ \t]+/, " ", win); print head "\037" win }

The gsub replacement there is `" "`. The `\037` is the record separator in the `print`. S7 flagged the line, and
the commit filing this entry removed the hit by naming the separator once (`BEGIN { US = "\037" }`, then `print head US win`), with
byte-identical output. The arm itself is unchanged, so the next line shaped like this one is flagged the same way.

Owed: S7 scopes its match to the replacement argument of the sub/gsub call, meaning the second argument up to its
closing delimiter, so a `\<digit>` later on the line is not read as part of it. Probe: the original line 99 above,
inside an awk program in a tracked `.sh` file, is not flagged. Control: `gsub(/x/, "\\1", s)` is still flagged.

Receipt: it drives the real validator in a mktemp git tree holding a copy of it, a `VERSION` marker, one `core/`
text file, one fixture shell file (so no corpus is empty and the scan runs), and two staged seeds:
`scripts/fp.sh`, an awk program carrying the original line 99, and `scripts/bl.sh`, carrying a real backreference.
It reads only the hits listed under the `FAIL: S7:` block. Today it exits 1, because S7 flags `fp.sh`. It exits 0
once S7 stops flagging `fp.sh` while still flagging `bl.sh`. It exits 9 when the validator is missing, the tree
cannot be built, a corpus reads empty or a self-probe fails, or `bl.sh` is not flagged.

verify: sh unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY; V=scripts/validate-shell-portability.sh; [ -s "$V" ] || exit 9; T=$(mktemp -d "${TMPDIR:-/tmp}/bl681.XXXXXX") || exit 9; mkdir -p "$T/scripts" "$T/core/fixtures/x" || exit 9; printf '0.0.0-receipt\n' > "$T/VERSION" || exit 9; cp "$V" "$T/$V" || exit 9; printf '%s\n' 'probe text' > "$T/core/a.md" || exit 9; printf '%s\n' 'true' > "$T/core/fixtures/x/run.sh" || exit 9; printf '%s\n' "awk '" '      if (inwin) { gsub(/[ \t]+/, " ", win); print head "\037" win }' "' f" > "$T/scripts/fp.sh" || exit 9; printf '%s\n' 'awk '"'"'{ gsub(/x/, "\\1", s) }'"'"' f' > "$T/scripts/bl.sh" || exit 9; git -C "$T" init -q && git -C "$T" add -A || exit 9; O=$(bash "$T/$V" 2>&1); grep -qE 'corpus is empty|own probe did not fire|no VERSION marker' <<<"$O" && exit 9; H=$(awk '/^FAIL: /{s=($2=="S7:")} s' <<<"$O"); grep -qF 'scripts/bl.sh:' <<<"$H" || exit 9; grep -qF 'scripts/fp.sh:' <<<"$H" && exit 1; exit 0

## BL-685 — BL-679's recorded `--verify` PASS never forms when the dist shares its ref store with active worktrees

**DEFECT, efficiency.** Found by ai-dlc-77 [e29316] in batch 236 while building BL-679.
- **The cause.** BL-679's key field `distrefs` hashes the dist's `for-each-ref`, HEAD and shallow flag. On a dist
  that is the main ai-dlc checkout, or a worktree of it, agent sessions create, advance and delete branches
  continuously. So the key taken after the render differs from the one taken before, and no record is written.
- **Measured** on a file:// clone of graph, with the dist set to a worktree of the main ai-dlc store: 0 of 5
  rounds recorded and 0 of 5 hit. The heads count moved 990 → 999 → 1011 → 997 → 996 → 998 across the rounds.
  The same consumer, with a self-contained file:// clone as the dist, recorded on the first `--verify` and hit
  on the second.
- **Why it matters.** graph's pulls use `/Users/n8/git/ai-dlc` itself as the dist, through
  `git -C /Users/n8/git/ai-dlc fetch -q origin` (graph sessions f78aa565 and 55506a8e, read by ai-dlc-f7). So
  BL-679 as shipped saves graph nothing.
- **Rejected:** narrowing the key to an enumerated set of ref readers. An adversary found four readers besides
  `retired-fixtures.sh`:
  - the stamp and override base names resolved as dist refs;
  - ledger `sh` receipts, whose read set is open;
  - `refs/replace`;
  - HEAD.
  graph's stamp uses 8-hex shas and its ledger carries 7 `verify: sh` receipts, so a narrowed key would fall back
  on graph every time.
- **Direction (lead-ruled):** keep the key, and remove the churn: the update skill owns a private, main-only, bare distribution clone under the consumer's git-common-dir, built in a later release with BL-693. The recorded PASS ships OFF by default (`EMIT_REPORT_VERIFY_CACHE=1` opts in) until an adversary round on the key finds no BLOCKER. Flipping the default on also adds an apply-restamp-worklist union-gate mutant A2b, run with EMIT_REPORT_VERIFY_CACHE=1, that guards the cache-hit pass branch (`if [ "$_ug_rc" -eq 0 ] && [ "$_ug_hit" = 1 ]; then`), because A2 now guards only the cache-off `elif` branch.
- Owner: ai-dlc-77 [e29316].

verify: manual

## BL-687 — a parallel step Read whose hook runs before the snapshot call's stage write gets the FIRST deny

**DEFECT.** The residual of BL-658, stated by the RECOVER contract adversary (batch 236) and filed by the lead.

A lead that issues the snapshot Read and the step Read in parallel runs two invocations of `core/hooks/ai-dlc-recover-gate.sh` side by side. If the step call's hook reads the stage before the snapshot call's stage write lands, it finds no progress file and defaults to `snapshot`. It passes the marker re-test because the marker is present, and it is denied with "your FIRST tool call must be…", although the snapshot Read is succeeding in the same message. This is the same mechanism as BL-658 case (iii). BL-658's digest allow does not cover it, because a step Read is a mandated Read: allowing it unconditionally would let a step Read alone satisfy the recovery. Cost: one denied call, a re-issued Read, and a false "you skipped the snapshot" message.

Fix shape, which can be built as written. In the `snapshot)` arm, before the fallthrough deny, a FULL Read of the step file that arrives while no stage is written and the marker is present is ALLOWED WITHOUT ADVANCING AND WITHOUT SATISFYING. It writes no stage, keeps the marker, and writes neither `.recover-satisfied` nor `.recover-advisor-owed`. The recovery is then satisfied only by a step Read made once the stage is `step`, so the lead re-issues the step Read after the snapshot Read, or a parallel step Read is satisfied only if its hook runs after the stage write.

What the shape must not open: a step Read alone must never satisfy the recovery without the snapshot Read. The allowed call must leave the marker present, the stage unwritten and `.recover-satisfied` absent, and a bounded step Read must still be denied.

Probe: arm a recovery, then send a full step Read with no stage written. It is allowed, the marker is still present, and neither the stage nor `.recover-satisfied` exists. Then a sequential snapshot Read followed by a step Read satisfies the recovery: the marker is removed and `.recover-satisfied` is written. The receipt exits 1 while the step Read with no stage is denied with FIRST, or while it satisfies anything.

verify: sh command -v jq >/dev/null || exit 9; [ -f core/hooks/ai-dlc-recover.sh ] && [ -f core/hooks/ai-dlc-recover-gate.sh ] || exit 9; p=$(mktemp -d) || exit 9; mkdir -p "$p/_bmad-output" "$p/.claude/skills/ai-dlc"; printf '# S\n\n## Pipeline Position\ncurrent_step_file: `a.md`\n' >"$p/_bmad-output/pipeline-snapshot.md"; echo x >"$p/a.md"; echo d >"$p/.claude/skills/ai-dlc/postcompact-digest.md"; echo x >"$p/z.md"; printf '{"source":"compact","session_id":"S"}' | CLAUDE_PROJECT_DIR="$p" bash core/hooks/ai-dlc-recover.sh >/dev/null 2>&1; grep -q '^step_file_resolved=1' "$p/_bmad-output/.recover-fired" 2>/dev/null || exit 9; g(){ printf '{"tool_name":"Read","session_id":"S","tool_input":{"file_path":"%s"}}' "$1" | CLAUDE_PROJECT_DIR="$p" bash core/hooks/ai-dlc-recover-gate.sh 2>/dev/null; }; g "$p/z.md" | grep -q "FIRST tool call" || exit 9; [ -e "$p/_bmad-output/.recover-gate-progress" ] && exit 9; g "$p/a.md" | grep -q "FIRST tool call" && exit 1; [ -e "$p/_bmad-output/.recover-fired" ] && [ ! -e "$p/_bmad-output/.recover-satisfied" ] && [ ! -e "$p/_bmad-output/.recover-gate-progress" ] || exit 1; g "$p/_bmad-output/pipeline-snapshot.md" | grep -q deny && exit 1; g "$p/a.md" | grep -q deny && exit 1; [ ! -e "$p/_bmad-output/.recover-fired" ] && [ -e "$p/_bmad-output/.recover-satisfied" ] || exit 1; exit 0

## BL-688 — when `_bmad-output` is unwritable, the snapshot Read is allowed but the stage never advances, so every later step Read is denied with FIRST

**DEFECT.** Measured by the RECOVER contract adversary (batch 236) on both origin/main and the BL-666 fix, and filed by the lead.

The gate's stage write (`core/hooks/ai-dlc-recover-gate.sh`, the `snapshot)` arm) is fail-open: when it cannot write the progress file, it still allows the snapshot Read. So with the marker present and `_bmad-output` unwritable, the snapshot Read goes through and the stage is never written. Every later step Read reads no stage, defaults to `snapshot`, and is denied with "your FIRST tool call must be…", and the snapshot Read the deny asks for advances nothing. The recovery cannot be satisfied: a wedge. Its arming precondition checks that the two mandated files are readable, never that the stage can be written.

The stderr half is closed in this release. Before BL-666's fix, the failed write's redirection error could leak to stderr. The A4 wrapper `{ …; } 2>/dev/null` around the temp write and rename now discards it. The wedge itself is open.

Owed: a stage that cannot be written must not leave the gate denying forever. Either the gate stands down (clears what it can and exits 0) when the stage write fails, as the arming precondition does for an unreadable file, or the arming precondition also requires a writable `_bmad-output`. Probe: arm a recovery, `chmod 555 _bmad-output`, make a full snapshot Read, then a step Read; the step Read is not denied with FIRST. Control: the same sequence with `_bmad-output` writable advances to `step`. If the probe runs as a user that ignores permissions, a write test detects it and the receipt exits 9.

verify: sh command -v jq >/dev/null || exit 9; [ -f core/hooks/ai-dlc-recover.sh ] && [ -f core/hooks/ai-dlc-recover-gate.sh ] || exit 9; p=$(mktemp -d) || exit 9; mkdir -p "$p/_bmad-output" "$p/.claude/skills/ai-dlc"; printf '# S\n\n## Pipeline Position\ncurrent_step_file: `a.md`\n' >"$p/_bmad-output/pipeline-snapshot.md"; echo x >"$p/a.md"; echo d >"$p/.claude/skills/ai-dlc/postcompact-digest.md"; echo x >"$p/z.md"; printf '{"source":"compact","session_id":"S"}' | CLAUDE_PROJECT_DIR="$p" bash core/hooks/ai-dlc-recover.sh >/dev/null 2>&1; grep -q '^step_file_resolved=1' "$p/_bmad-output/.recover-fired" 2>/dev/null || exit 9; g(){ printf '{"tool_name":"Read","session_id":"S","tool_input":{"file_path":"%s"}}' "$1" | CLAUDE_PROJECT_DIR="$p" bash core/hooks/ai-dlc-recover-gate.sh 2>/dev/null; }; g "$p/z.md" | grep -q "FIRST tool call" || exit 9; chmod 555 "$p/_bmad-output" || exit 9; if ( : >"$p/_bmad-output/.w" ) 2>/dev/null; then rm -f "$p/_bmad-output/.w"; chmod 755 "$p/_bmad-output"; exit 9; fi; v=0; g "$p/_bmad-output/pipeline-snapshot.md" | grep -q deny && v=9; [ "$v" = 0 ] && g "$p/a.md" | grep -q "FIRST tool call" && v=1; chmod 755 "$p/_bmad-output"; exit "$v"
## BL-690 — the pre-push fixture pool installs no EXIT, INT or TERM trap, so an interrupted hook leaks its pool root `/tmp/fx.*`

**NOTE.** The pool function sets `out="$(mktemp -d /tmp/fx.XXXXXX ...)"` (`.githooks/pre-push:2030`, `core/git-hooks/pre-push:1938`) and removes it only by straight-line `rm -rf "$out"` (`.githooks/pre-push:2044`, `:2080`, `:2088`, `:2446`; `core/git-hooks/pre-push:1952`, `:1984`, `:1992`, `:2320`). The hook says so itself: "There is no trap in this hook" (`.githooks/pre-push:2383`; `core/git-hooks/pre-push:2259` carries the same sentence). An interrupted hook (SIGINT, SIGTERM, SIGHUP, or a `set -u` abort) therefore leaks its pool root. The leak predates this release; the root moved from `/var/folders` to `/tmp` in this release, so it now lands in shared `/tmp`. Filed by peer session ai-dlc-c0 (batch 236 READSET), id allocated by lead ai-dlc-c8, found by the READSET tip adversary on the per-unit TMPDIR change.

Owed: the pool function installs a trap naming EXIT (or INT and TERM) whose body removes `"$out"`, in both hooks, which I66 holds to one program.

verify: sh for f in .githooks/pre-push core/git-hooks/pre-push; do b=$(sed -n '/out="\$(mktemp/,/rm -rf "\$out"/p' "$f" | grep -v '^[[:space:]]*#'); [ -n "$b" ] && [ "$(printf '%s\n' "$b" | grep -c 'trap .*\$out.*\(EXIT\|INT\|TERM\)')" -gt 0 ] || exit 1; done

## BL-691 — a nested pool makes its pool root outside the OUTER unit's watched TMPDIR, so the outer watcher does not see the nested pool's scratch writes

**NOTE.** A fixture that drives the real hook's pool makes a nested pool: `core/fixtures/prepush-pool-depth/run.sh` calls `run_fixtures` at depth 1 (`:79`, `:120`), and `core/fixtures/readset-skip/run.sh` sources the extracted FIXTURE_POOL block (`:287`, `:361`). `core/fixtures/self-update-fixture-log/run.sh` drives the hook through `h_enter` (`:2090`) and names PREPUSH_POOL_DEPTH (`:2063`); whether it reaches `run_fixtures` was not established. The nested pool chooses its root at the `out=` line (`.githooks/pre-push:2030`, `core/git-hooks/pre-push:1938`), which is `/tmp/fx.XXXXXX` and not under the caller's TMPDIR. The outer pool watches a per-unit TMPDIR (`TMPDIR="$wr" "$@"`, `.githooks/pre-push:2206`; the watched-root limit is commented at `:467-:469`). The nested pool's scratch writes land outside that root, so the outer watcher sees only the nested hook's log output. Whether the outer progress check still holds for those three fixtures is UNRUN.

Owed: when `PREPUSH_POOL_DEPTH` is above 0, the pool root is made under the caller's TMPDIR.

verify: sh for f in .githooks/pre-push core/git-hooks/pre-push; do b=$(sed -n '/out="\$(mktemp/,/mkdir -p .*\$out/p' "$f" | grep -v '^[[:space:]]*#'); [ -n "$b" ] && [ "$(printf '%s\n' "$b" | grep -c 'PREPUSH_POOL_DEPTH\|POOL_DEPTH_IN')" -gt 0 ] && [ "$(printf '%s\n' "$b" | grep -c 'TMPDIR')" -gt 0 ] || exit 1; done

## BL-689 — `/bin/bash` 3.2 cannot parse an unbalanced quote or `(` in a heredoc body nested in a `$( … )`, and the gate's `bash -n` never parses the fixture scripts where it would land

**DEFECT.** Found by hand a5fb5b0d of 77 [e29316] while measuring BL-647, and filed on ai-dlc-c8's ruling. This is the bash 3.2 `$( )` family, as BL-647 is. Intake reproduced it standalone under `/bin/bash` 3.2.57(1)-release.
- The form: `v="$(cat <<'X'` / `it's here` / `X` / `)"`. It fails at run time with rc=2 ("unexpected EOF while looking for matching `''") and runs nothing below it. `bash -n` also REJECTS it with rc=2, so unlike BL-647's three forms a parse can see it.
- The trigger is an unbalanced quote or `(` in the heredoc body. One or three apostrophes fail, while two pass. A lone `"` fails, and so does a lone `(`. The outer double quote is not required, because `v=$(cat <<'X' …)` fails too. The delimiter's quoting does not matter: `<<X`, `<<'X'`, `<<"X"` and `<<-'X'` all fail. Paired passing forms: a backtick substitution, a heredoc outside any `$( )`, and a heredoc in a function that the substitution calls (`v="$(f)"`).
- Why no existing gate refused it: `syntax_all` (`.githooks/pre-push:2392-2400`, mirrored in `core/git-hooks/pre-push`) runs `bash -n` over `scripts/`, `core/scripts/`, `core/hooks/`, the reconcile engine and the hooks only. That is 151 of 603 tracked `.sh` files. The other 452, 431 of them under `core/fixtures/`, were parsed by nothing. Seeded probe of the shipping `syntax_all`: it fires on the form in `scripts/` (rc=1) and stays quiet on the balanced pair (rc=0). It also uses `bash` off PATH, which is `/bin/bash` 3.2.57 on this machine. Of the 16 tracked files that carried a heredoc opener on a `$(` line, 15 were fixtures outside that glob, and all 16 parsed. A fixture that carries the form fails as a bare `FAIL <name>` with no cause. A helper that a fixture sources returns 1 to a caller that keeps going, as measured.
- The silent half: a lone `)` in the same heredoc body is accepted by `bash -n` (rc=0) and runs with rc=0, but yields the WRONG value (`a ) here` came back as `a  here`, `X`, `)`). No parse can see it.

Fixed, the parse half: arm S14 in `scripts/validate-shell-portability.sh`, a new `parse` kind. It runs `/bin/bash -n`, pinned to the 3.2 floor because bash 4+ parses `$( )` recursively and would accept the form. It parses only the files a prefilter selects, one awk pass over the `shell` corpus. That pass runs S13's lexer in select mode and keys on two things: a heredoc opener whose lexer state is inside a `$(`, which catches the multi-line spelling, and the census regex for a `$(` followed on the same line by a non-here-string `<<` opener. It used to fork about 600 `bash -n` per validator call; it now forks one per selected file. Of the 16 files the census found, the prefilter selects 14. The other 2, `check-24-adversarial-convergence/run.sh` and `suite-dispatch-order/run.sh`, carry no heredoc opener inside any `$( )`: their census lines are `<<<` here-strings, which the census's own regex took for an opener. Both parse under `/bin/bash -n`. The prefilter self-probes in both directions before the corpus. It must select `$(cat<<X`, `$( cat <<-'X'`, a nested `$(echo "$(cat <<X`, the opener on the line after a multi-line `"$(` and `$(f <<"X"`. It must not select a top-level heredoc, a function-held one, a backtick one or a `<<<`. False-positive set: EMPTY over the tracked shell corpus, with the seeded offender rejected rc=2 in the same run.

Fixed, the silent half: S13 form (d) reads a heredoc body that was opened inside a `$( )`, with its own quote-and-paren counter. It flags a `)` that closes nothing. The rule comes from the `/bin/bash` 3.2 oracle, which compares the captured value against the literal body. A `(` earlier in the body balances the `)`, on the same line or a previous one. Quotes, a backslash, or a `#` comment after a blank hide it. `a#) b`, `(x)# a ) b`, `case x in a) ;; esac` and `$((1+2)) ) x` all break. A backtick, a top-level heredoc or a function-held heredoc is correct. Scored on 71 in-class oracle probes: missed 0, over 0. One run over the tracked shell corpus (601 files at the build), with a seeded offender appended, found 0 corpus hits and reported the offender.

Fixture `core/fixtures/shell-portability`:
- m15 puts the parse form in a fixture script, and only S14 kills it.
- n8 holds the balanced pair, a backtick substitution and a function-held heredoc, and none is reported.
- x23 drops S14 from `ARMS`, and the report vanishes.
- The oracle-agreement arm m14 gains d1 (a lone `)`, BREAK), d2 (a balanced `( )`, ok), d3 (the same nested in `$(echo "$( … )")`, BREAK) and d4 (function-held, ok).
- x24 disconnects form (d)'s body scan, and the report vanishes.

NOT measured: a bash 5 parse of the form, because none is installed here.

Owner: ai-dlc-ae (batch 236, PORTABILITY).

verify: sh d=$(mktemp -d) || exit 9; for s in bad good; do mkdir -p "$d/$s/scripts" "$d/$s/core/fixtures/p" "$d/$s/core/skills" && echo 0.0.0 > "$d/$s/VERSION" && cp scripts/validate-shell-portability.sh "$d/$s/scripts/" && printf 'x\n' > "$d/$s/core/skills/c.md" && printf 'echo ok\n' > "$d/$s/scripts/c.sh" || exit 9; done; printf 'v="$(cat <<\047X\047\nit\047s here\nX\n)"\necho "$v"\n' > "$d/bad/core/fixtures/p/run.sh"; printf 'v="$(cat <<\047X\047\nit\047s x\047s here\nX\n)"\necho "$v"\n' > "$d/good/core/fixtures/p/run.sh"; mkdir -p "$d/bad/core/fixtures/q" "$d/good/core/fixtures/q" || exit 9; printf 'v="$(cat <<\047X\047\na ) here\nX\n)"\necho "$v"\n' > "$d/bad/core/fixtures/q/run.sh"; printf 'v="$(cat <<\047X\047\na ( b ) here\nX\n)"\necho "$v"\n' > "$d/good/core/fixtures/q/run.sh"; [ "$(/bin/bash "$d/bad/core/fixtures/q/run.sh")" = 'a ) here' ] && exit 9; [ "$(/bin/bash "$d/good/core/fixtures/q/run.sh")" = 'a ( b ) here' ] || exit 9; /bin/bash -n "$d/bad/core/fixtures/q/run.sh" || exit 9; /bin/bash -n "$d/bad/core/fixtures/p/run.sh" 2>/dev/null && exit 9; /bin/bash -n "$d/good/core/fixtures/p/run.sh" || exit 9; for s in bad good; do (cd "$d/$s" && git init -q . && git add -A) >/dev/null 2>&1 || exit 9; done; b=$(cd "$d/bad" && bash scripts/validate-shell-portability.sh 2>&1 </dev/null); g=$(cd "$d/good" && bash scripts/validate-shell-portability.sh 2>&1 </dev/null); grep -q '^validate-shell-portability: PASS' <<<"$g" || exit 9; grep -q '^FAIL: S14:' <<<"$b" && grep -q 'core/fixtures/p/run.sh' <<<"$b" && grep -q '^FAIL: S13:' <<<"$b" && grep -q 'core/fixtures/q/run.sh:2:' <<<"$b"

## BL-698 — the handoff guard answers an unpushed or uncommitted handoff with the RESUME text when no resume block was emitted, and a backgrounded push gets a second push

**DEFECT.** Owner ai-dlc-ae (batch 236, GUARDORDER).

`core/hooks/ai-dlc-continue.sh` Check 0 says its arms dispatch "in the procedure's own order", so the lead is told the earliest unsatisfied step. But the COMMIT and PUSH arms also required `RESUME_OK = 1`, and the TEAMMATES, INFLIGHT and RESUME arms did not. So when step 2's commit or step 3's push had not landed AND no well-formed resume block had been emitted, both earlier arms were skipped and the lead got the RESUME text: an instruction to emit a resume prompt that points at an unpushed branch. Three of the 32 arm states answered RESUME wrongly: T=I=1 and R=0 with commit/push in {C0P0, C0P1, C1P0}. The conjunct came in with `6ddd40590` (v0.447.0, PUSH arm) and was copied by `ced16e8b4` (BL-159, COMMIT arm). It is an artifact of the old two-arm dispatch and guards no recorded case.

Evidence, read-only, from the reference consumer's session `a0701ce0` (graph s319, handoff #2). The step-3 push `git push -u origin HEAD` with `timeout: 600000` was issued at transcript line 1825 (17:57:13Z, 1:57 PM EDT). The harness moved it to the background at line 1826 (`backgroundTaskId: bwgggj2q8`, `timedOutAfterMs: 600000`). The guard then answered with the RESUME text ("this turn ends WITHOUT a copy-pasteable resume prompt") at line 1908 (18:08:18Z, 2:08:18 PM EDT), line 1916 (18:08:26Z, 2:08:26 PM EDT) and line 1988 (18:09:07Z, 2:09:07 PM EDT), while the push was still inside its pre-push suite. The push's exit record, a `queue-operation` enqueue naming `bwgggj2q8`, landed at line 2005 (18:09:22Z), and line 2006 shows `a2bc8d3a9..ef057deb1`. Control in the same transcript: line 1856 is the INFLIGHT arm firing correctly. Each refusal was a turn of more than 300k tokens (per session f7's reading). Removing the conjunct alone would have told that lead to push again in the foreground, which starts a second, concurrent pre-push suite.

Fix. (a) The COMMIT and PUSH arms no longer read `RESUME_OK`, so dispatch follows step order: teammates, commit, push, resume line. The four texts that asserted "the resume prompt is well-formed" before the resume arm had run no longer say so. The PUSH and COMMIT texts say to emit no resume prompt until the push has landed. The PUSH text's environmental branch says to finish steps 4 and 5 in the same turn. (b) A new deferral, `HANDOFF_GUARD_DEFERRED_BY_PUSH`, sits beside the live-beat deferral. It replaces the PUSH answer only: it applies only when steps 1 and 2 are satisfied and step 3 is not. A push in flight never hides the TEAMMATES, INFLIGHT or COMMIT text. The signal is a Bash `tool_use` whose program is `git push` and whose tool-result record carries `toolUseResult.backgroundTaskId`, with no later `queue-operation` enqueue naming that id. "Program" means the command is matched only at a command start (start of string, or after `;`, `&`, `|`, `(` or a newline), with optional `env` or `VAR=value` prefixes and an optional `git -C <dir>`. Quoted spans are blanked first, so a watcher such as `until grep -q 'git push' log` is not a push. The enqueue predicate is the one `ai-dlc-dispatch-guard.sh` already keys on. No id means no deferral. The ceiling is 3004 s after the tool-result record. That is the longest push wall clock recorded in the reference consumer's transcripts: 3604 s across 333 paired pushes in 190 sessions, graph session `94702274`, lines 2150 to 2323, on 2026-10-05. The record lands 600 s after a foreground push starts, so the ceiling is 3604 − 600. Past the ceiling, the hook answers with the PUSH text, and that text says the backgrounded push has overrun its ceiling: check its output or notification, and push again only if it exited without landing. It never says to wait, because a lead told to wait burns the BACKOFF window, and BACKOFF then allows the unpushed handoff. A tool_use or tool_result with an empty or absent id joins nothing. The deferral is transcript-only. If the harness changes that record shape, the deferral never fires and the PUSH text returns. Whether a TaskStopped task enqueues is UNMEASURED. `steps/handoff.md` step 3, `_gate-procedures.md` "Auto-handoff evaluation" step 3 and the PUSH text now say: if the push was moved to the background, do not issue another; end the turn and wait for its notification.

verify: sh bash core/fixtures/handoff-completion-assertion/receipt-bl698.sh

## BL-700 — a malformed or absent transcript, or no `jq` on PATH, fails OPEN before the handoff guard runs

**DEFECT.** Owner ai-dlc-ae (batch 236). Found by the GUARDORDER tip adversary (tip698) on 02b16ee93; the id was allocated by lead ai-dlc-c8. Pre-existing on origin/main.

`core/hooks/ai-dlc-continue.sh` allows a requested handoff on an unpublished branch with no `HANDOFF_GUARD_*` row in four cases: the transcript's last line is truncated mid-write, a non-JSON line sits mid-file, the transcript path names no file, or `jq` is not on PATH. The continuation log shows `ADVERSARIAL_STATE_UNADJUDICABLE` and then `ALLOWED_BY_PAUSE`; with the pause flag down, only the first row appears. The same seed with a well-formed transcript gets a HANDOFF GUARD block, which is the control. The four cases give the same silent allow under the branch hook and under the origin/main hook (tip698 `probe4.sh` and `probe4b.sh`, origin/main hooks at `scratchpad/tip698/base/core/hooks`). The receipt below reproduces it: exit 1 with all four named, on both hook trees, against a passing control.

Mechanism, from the code and not traced: Check 0's transcript readers (`LAST_USER`/`LAST_ASST`, `jq -rs` over the whole file) read an empty string when `jq` cannot parse the file or is absent. With no request seen, the guard is armed only by an on-disk key. Check 0b then reports the adversarial state as unadjudicable, and Check 1 allows the Stop.

Owed: a Stop whose transcript cannot be parsed or read, or that runs with no `jq`, must not let a requested handoff end with step 3 unsatisfied and no HANDOFF_GUARD record. The fix is not one line, and it rides a later release. The readers must tolerate a partial last line (`-R` with `fromjson?`, as `push_bg_read` and `ai-dlc-dispatch-guard.sh` already do), and a path with no `jq` needs its own decision.

verify: sh bash core/fixtures/handoff-completion-assertion/receipt-bl700.sh

## BL-703 — wait-beat-liveness and wait-stale-deliverable arms order a fixture event against a step inside wait-for-deliverable.sh with a wall-clock sleep, so under load they fail, and four of their mutants survive

**DEFECT.** The arms fail intermittently under concurrency on trees whose `core/scripts/wait-for-deliverable.sh` and fixture are identical to base. They pass when run alone, and the subject is not at fault. Each arm orders its own event against a step inside wfd using a sleep or a poll cadence, and load stretches the step. In M18, M42, M36 and C41 it is the MUTANT that loses its distinguishing interleaving, so under load the battery acquits.
- S16b `revised-survives`, S16c `revised-rounds`, M36 `revised-round-kept`: the writer `( sleep 1.5; edit )` assumes the beat's first observation (the sweep's `is_delivered` -> `settled()`, wfd :1656 -> :1089) happens before 1.5s. A late beat sees only the edited file, so `.revised` is never written. Forced with `sleep 2` before the sweep (wfd :1617), they fail 2 of 2.
- M18 `settle-is-poll`: the mutant delivers only if its poll period holds one hash for 2s inside each 4s edit gap. Forced with a 4s poll stretch before wfd :1925, it fails 2 of 2.
- M42 `registrations-in-state-dir`: the fixture writes `b.md` the instant A's counter appears, which puts A's post-sweep `beat_alive` steal (wfd :1911) directly on B's exit. Forced, M42 fails 2 of 2 and S21b passes 2 of 2.
- C41 `no-join-memo` (wait-stale-deliverable): both beats read one shared `.settle` record (wfd :1067-1090), so the 1.5s start offset protects nothing. Forced with `sleep 2` before the `.since` rm (wfd :1940), the mutant survives 2 of 2.
- The `WARN: --since without --dispatch` lines in the failure output are not a cause. Every beat prints that warning, and it is the only captured text left when the expected line is missing.
Reports came from peers 48 (BL-553, BL-620), 18 (SHARDS) and 5e (TOOLING), plus a hermetic run during HOOKWAKE. All five wait-beat-liveness arms and C41 were forced on base 0b7a7a432 in scratch copies, each with a cmp-differs control.

Fix: every arm blocks on an event the subject writes, through a fixture-local gated sleep stub. The stub's bound writes `expired` and the arm reports BROKEN, so an expired bound is never a pass. M18 uses a static file with SETTLE=600, POLL=1 and BEAT=5, and now tests that settle age is compared against SETTLE, not against POLL. M35 and M36 refuse unless their world shows `REVISED-AFTER-MARKER 1`. C41 is fixed in TOOLING (0.835.0) at 4162cb9e9: beat 2's process tree is SIGSTOPped until beat 1 has delivered, `.since` is gone and the seal's second has passed.

verify: manual
