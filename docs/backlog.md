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

**Evidence (HANDOFF, 0.876.0).** The precondition for the hook half is in: the architect, analyst and ux deliverables now carry every item their return carried (`## Architect handoff`, `## Gaps`, `## Design decisions`), and SubagentStop keeps each final message in `_bmad-output/.subagent-final/<agent_id>.txt`. No hook is installed and this entry stays open.

**Evidence (HOOKWAKE).** The hook half ships as a UserPromptSubmit hook, `core/hooks/ai-dlc-hookwake.sh`, that BLOCKS a subagent hand-back while that agent's wait beat is outstanding. It joins on the `.wait-beats/.beat-argv-<pid>` record `core/scripts/wait-for-deliverable.sh` writes at arm time, with the start time read through the shared `core/scripts/wfd-start-of.sh`, and `core/fixtures/hookwake` drives it in both layouts. That is a different shape from the "hook that injects that instruction" this entry names: it refuses the wake rather than telling the lead how to answer it. The measurement half, a re-taken wake count on a consumer lead session, is still OPEN, so the entry stays PARTIAL.

**Progress (batch 240).** The flip half needs a redesign before it returns to the operator: `wait-for-deliverable.sh` records dispatch-to-path pairs at arm time, J4 becomes per-agent, C5 gets a guaranteed carrier, and the design is checked against a captured real UserPromptSubmit payload.

**Progress (batch 241; the entry stays OPEN, `verify: manual` unchanged, no LANDED line).** The hook half is retired by operator ruling 2026-10-23, and `core/hooks/ai-dlc-hookwake.sh` and its fixture are removed in this release. Retiring the hook does not touch this entry's subject, the full lead turn per notification that an armed beat already covers, so that defect and its per-wake re-measure on a consumer lead session are still owed. The "Evidence (HOOKWAKE)" and batch-240 paragraphs above describe a mechanism that no longer ships.

**Third reading (batch 243, c5; transcript-only; the entry stays PARTIAL).** The s320 lead work spans four transcripts under `~/.claude/projects/-Users-n8-git-graph/`: `719a49a0` (the opening session, 133 dispatches), `d71fcbce` (a short resume, 4), `d22c7889` (the main s320 lead, 539) and `04c0da6d` (the latest resume, 35). They were identified as the non-sidechain sessions whose first human turn is `/ai-dlc`. `888e1365` (the s319 lead) and `913d04cc` were rejected for carrying almost no s320 mentions, and `fa7ce946` for being an `/ai-dlc-update` session. Under f7's heuristic (a wake ends with no tool call when no `tool_use` block appears before the next user line), the wakes and the no-tool-call wakes per transcript are 125/91, 7/1, 482/355 and 34/25, which sum to 472 of 648 (73%). The same counter reproduces the s319 `c61a91eb` window of 37 of 54 exactly (up to transcript line 2838) but does NOT reproduce the window of 20 of 29 (its nearest reading is 23 of 40 at line 2702). The 73% figure is therefore a FLOOR OF UNKNOWN ACCURACY, not an exact count. The wake definition (a non-sidechain user line carrying the task-notification tag that is not a `tool_result`) is this counter's own, and a raw tag count disagrees with it: 2482 occurrences against 482 parsed wakes in `d22c7889`, because the tag also appears in queued and quoted lines. About 112 of the 472 idle wakes explicitly restate that an armed join or beat covers them; that number is a TEXT-REGEX APPROXIMATION, not a classification of each turn. One example is `d22c7889` line 716: "Covered by the armed join; nothing to do until it reports." The mechanism that would remove these turns has no design since the hook was retired, so the entry stays PARTIAL and its verify line is unchanged.

Decision rule: the step-value ruling, "A step with no measured value goes" (`.claude/rules/operator-rulings.md`), cited per BL-817.

verify: manual

## BL-583 — the push suite's non-mutant poles have not been judged on value, and no per-gate wall clock or dollar figure has been measured

**NOTE (efficiency).** Re-tiered from DEFECT: Phase 2 (v0.842.0) retired every mutation battery, so the remaining owed work (judging the non-mutant poles, a per-gate wall clock and dollars) is measurement, not a defect. Operator-raised, 2026-10-16 ~04:30 EDT: "gating a release is so expensive, like stupidly expensive to run the push suite". Filed by peer session ai-dlc-68 (listed as ai-dlc-4e [e15800]). Assigned to ai-dlc-a6: phase 1 is a read-only census of where kill sets overlap, phase 2 is confirmation in the lead's slots after H-b. ai-dlc-bb's world-cache release already targets the `review-shard-merge-mutants` pole, so this entry does not count that saving twice.

Measured from `.git/ai-dlc-fixture-durations` in the main checkout, a LOADED-cost record that each push rewrites:
- Filer, at 04:29 EDT (288 rows): sum 28783 s (~8.0 h; ~40 min per full run on a pool of 12); 41 mutant rows at 12398 s, 43%; 12 of the top 15 rows mutant batteries at 583-737 s, the three non-mutant rows `snapshot-archive-rotate` 717 s, `suite-pole-guard` 493 s and `readset-skip-d` 410 s (corrected from 13 after lead ai-dlc-9c re-derived it); 130 rows at 60 s or more, 71 at 120 s or more, 82 under 10 s.
- Intake, re-derived at 06:18 EDT (288 rows, the record rewritten since): sum 27473 s; 41 mutant rows at 11346 s, 41%; 10 of the top 15 are mutant batteries (`derivation-capture-mutants` 737, `review-shard-merge-mutants` and `-b`/`-c` 728-729, `adversarial-shard-merge-mutants` 694, `remediator-shard-join-mutants` and `-b`/`-c`/`-d` 583-589, `updater-session-signals-mutants` 367), and the five non-mutant rows are `suite-pole-guard` 493, `readset-skip-d` 453, `ledger-reverify` 409, `-b` 392 and `-d` 362. Fixture directories: 290 (`/usr/bin/find core/fixtures -mindepth 1 -maxdepth 1 -type d`).
The two readings differ because the record moves with every push. The shape holds across both: the mutant batteries dominate the top of the rank.

Owed, under the step-value ruling in `.claude/rules/operator-rulings.md` ("A step with no measured value goes") applied to fixtures — a fixture or mutant shard stays only on evidence, a named defect class it catches that no other unit catches; without that the batch retires or merges it, and it is not put to the operator as a choice:
1. Rank by cost first: the mutant batteries, then the non-mutant poles.
2. For each sharded battery, measure whether its mutants kill anything the base fixture's arms do not; shards of one battery that kill the same set are redundant.
3. State the gate wall clock removed per release and the dollars beside it.

Caveat: the record is a loaded-cost set from recent runs, not a solo timing, and a content-keyed push runs only part of it. The per-gate figure needs the gate log of a real release push (0.794.0 onward). Related: BL-558, BL-592, CLAUDE.md "A wall clock is a defect until it is justified".

Scheduled in batch 235 for a later release (scope ruling: the boundary is the release).

**Partial, v0.810.0.** Item (a), the sandbox re-trace of 13 of the 14 stale fixtures, landed in intake 2 (`52555359`). Items (b) and (c) land here: `fold-architect-ledger-join-mutants` runs C0 and the M6 premise in shard `a` only, bound by a J2 arm, and `derivation-capture-mutants` is four pool units with a derived deal and coverage join (J0, J1, J1b) and no redundant control. Open: the remaining phase-2 items (gate-adjudication M0 in one shard, the readset-skip-digest and advisor-gate-deny controls in one shard each, the ledger-reverify-shard control) and the per-gate wall clock and dollars, which need the gate log of a real release push.

**Gate-log evidence (f7 measured, graph session `f78aa565`; transcript-only, not re-derived here).** The graph push of the reconcile commit took 17.6 minutes in pre-push with 139 of 224 fixtures selected. That is a real release-class push on a consumer tree and a first data point toward the per-gate wall clock this entry owes; it is a consumer's selected subset, not this repo's full-suite figure, and the two must not be compared.

**Item (b), batch 236.** `gate-adjudication-mutants` (M0) and `readset-skip-digest-mutants` (unmutated and impossible-anchor controls) now run their controls in shard `a` only, bound by a J2 once-only arm with a two-direction self-probe, and a D14 arm every shard runs holds each shard's `inputs.decl`/`tools.decl` equal to `a`'s apart from the driver lines (also added to `fold-architect-ledger-join-mutants`). `advisor-gate-deny-mutants` keeps its per-shard control because its shards' declarations differ (`-d` adds `od` and `tee`; `-b`/`-e` declare sibling directories whole), and `ledger-reverify-shard-mutants` keeps its C-a and C-b controls because it is one unit whose kill list is 3 in `a` and 1 in `b`, so `b`'s control is the only one for its mutants. Item (b)'s receipt (inert: its subject batteries `gate-adjudication-mutants` and `readset-skip-digest-mutants` were retired in v0.842.0, and run in a scratch copy it exits 9; it is kept as history and is not a live `verify:` line): `for f in gate-adjudication-mutants readset-skip-digest-mutants; do case $f in gate*) r='/^# M0 /,/^# m1 /' ;; *) r='/^NCTL=0$/,/^# J2: both/' ;; esac; t=$(mktemp) || exit 9; sed -n "${r}p" core/fixtures/$f/run.sh | sed '$d' > $t; [ -s $t ] || exit 9; S=$(grep -m1 '^SHARDS=' core/fixtures/$f/run.sh | cut -d'"' -f2); [ -n "$S" ] || exit 9; first=${S%% *}; for s in $S; do c=$(GROUP=$s C=0; score() { C=$((C+1)); }; dg_all() { C=$((C+1)); }; broken() { :; }; ok() { :; }; bad() { :; }; DG_WORLDS=; POOL=/dev/null; FX=x; HOOK=h; ROOT=r; . $t >/dev/null 2>&1; echo $C); w=0; [ "$s" = "$first" ] && w=1; [ "$c" = "$w" ] || { rm -f $t; exit 1; }; done; rm -f $t; done`. The entry stays open for the per-gate wall clock and dollars.

**Phase 2, v0.842.0.** Every mutation battery is retired: 56 units in 24 batteries, removed because none has a catch on record. A census of every record on `origin/main` that names a battery found only drift reds (re-anchored mutants, re-declared kill sets, scorer timeouts, the battery's own bugs) and one red that was not the battery's: BL-181, a subject locale bug the shipping fixture `gate-remediation-deny` also caught. In the main checkout's loaded-cost record the 56 units were 30380 of 54724 fixture-seconds (56%), and the pole moves from `adversarial-shard-merge-mutants` at 2214 s to `document-partition` at 732 s. The CHANGELOG for 0.842.0 carries the per-battery table. Items (b) and (c) above described those batteries' controls and shards; they no longer exist. Open: the non-mutant poles (`document-partition`, `enforcement-map-sites`, `apply-restamp-worklist-c` and the rest of the top of the record) have not been judged on value, and no per-gate wall clock or dollar figure has been measured.

**Evidence: the read-set fan-out of a runner change.** On a consumer's 0.830.0 to 0.834.0 reconcile push (graph transcript 5d4fbc59), the first push took about 98 minutes and ran 128 of 224 fixtures. 122 of them were woken because the pull changed runner and tooling files: `hermetic-run.sh`, `.githooks/pre-push`, `apply.sh` and `derive-fixture-readsets.sh`. The re-push took about 6 minutes and ran 42 of 224. Load was 77 to 85, so these are loaded figures. No dollar figure was measured. This is BL-583's subject, not BL-694's.

**Progress (batch 240).** Re-scoped to the poles not covered by BL-699 or BL-755 (BL-755 is archived, in `docs/backlog.archive.md`).

verify: manual — the owed work is a judgment of the non-mutant poles and a per-gate wall clock and dollar figure from a real release push, so no predicate over the tree can test it; a live 0-mutants receipt would read CLOSE-CANDIDATE while that work is open.

## BL-584 — two fixtures cannot be traced and have no `inputs.decl`, so they run on every push

**PARTIAL (v0.806.0, verified 581ca289) — owed (1) shipped for `fold-architect-ledger-join` only; owed (1) for `hermetic-runner` shipped in v0.832.0 (verified 67bdbb7a), and owed (3) is OPEN.** `fold-architect-ledger-join` carries `inputs.decl` and `tools.decl` and runs under `hermetic-run.sh` (72 ok, `required_missing=0`); its 46 traced rows are removed. `hermetic-runner` reads its subject files from copies made once at startup. That cut its trace window about 6x (17691 lines to 2902, loaded) but did NOT stop the drops: one 6-fixture `--tracer sandbox` call dropped 3 reports in its window, and three `--local-map` reps dropped 1, 2 and 7, at load 27-43 (0 of 3 clean). The premise that the drops come from re-opening four tree files hundreds of times is REFUTED; the drop cause is undiagnosed. `hermetic-runner`'s 17 rows and digest are removed, so it runs on every push (fail-closed) until the drops are fixed. The earlier count of 27 held fixtures is 5: 27 have `#discards` at n≥3 in `.git/ai-dlc-fixture-readsets.local`, and only 5 are keyed on the current runner and deriver.

**PARTIAL (batch 240) — owed (2) is met; owed (3) stays OPEN, so this entry carries no `**LANDED` line.** Of the 37 `core/fixtures/*/run.sh` directories that had no `inputs.decl`, 34 now carry `inputs.decl` and `tools.decl`, each proven by `core/scripts/hermetic-run.sh`. The other 3 carry a dedicated `.undeclarable` marker, whose first line states why no one declaration holds in both layouts: `hook-registration-join`, `retro-compliance-workflow` and `self-update-join-gate`. The last of those is also `.dist-only`. The marker replaces the README sentence that (2) named, because 10 of the 37 already had a README for other purposes. Invariant I74(e) in `scripts/validate-enforcement-map.sh` binds it: every `run.sh` directory carries exactly one of `inputs.decl` or a `.undeclarable` with a non-empty first line. The arm's self-probe runs under mktemp before the corpus and fires in both directions.

Census, scored under `bash -c 'set -uo pipefail; …'`: 260 `run.sh` directories, 257 declared, 3 undeclarable, 0 offenders, exit 0. A second spelling (a `find -name run.sh` walk with `head -1`) also exits 0. Three seeded regressions each exit 1: a directory with neither file, an empty `.undeclarable`, and a directory with both. The receipt is `verify: manual`, because a census over the marker would read CLOSE-CANDIDATE while (3), the trace-stream drop cause, is still owed.

**PARTIAL (batch 241) — owed (3) is diagnosed and its cross-deriver cause is fixed; a solo drop at high load is unexplained, so (3) stays open and this entry carries no `**LANDED` line.** The cause is box-wide Sandbox report volume. Every `--local-map` and `--in-pool` deriver (`core/scripts/derive-fixture-readsets.sh`) adds to one shared pool of kernel Sandbox reports. A heavy fixture's window therefore drives "dropped during" notices into every window that overlaps it, and each of those windows discards its fixture on the drop-notice guard or the loss canary. The forced reproduction traced subject `small`, which issues exactly 40 tagged reads, beside a neighbour deriver tracing `big`, which runs 25 passes of `xargs -P 8 cat` over 3000 files. Without a slot, the subject's windows read notices/delivered/canary of 56/37/3, 62/35/5 and 51/33/7. With a per-uid window slot in both derivers they read 0/40/0 three times, while `big` still issued 59-61k reports per window. The fix is that slot. It is a per-uid mkdir lock at `/private/tmp/ai-dlc-readset-window-<uid>`, taken just before a window's sentinel writes and released just after its stream is stopped, under `--local-map` and `--in-pool` only. It is the BL-375 shape: it changes the schedule and not the work. Its pid file is written by the hook's own `readset_lock_write` and judged by its `readset_lock_stale`. The deriver sources both from a new `READSET_LOCK` span in both pre-push hooks. A waiter breaks a stale slot, writes a heartbeat line to its pool log every 100 polls (about 20s) so `POOL_STALL` does not refuse it, and runs the stale test inside its wait loop. The slot is re-entrant by holder pid. A nested deriver skips the wait only when the `READSET_SLOT_HOLDER` marker it inherited names this slot and the pid that the slot's pid file records as live. A stale marker or a foreign one waits. `core/fixtures/readset-skip`'s `slot` unit drives all of this through `core/fixtures/readset-skip/slot-world.sh` in a stub-stream world, and six mutants each fail exactly their own scenarios.

What (3) still owes is one observation: `small` traced alone at load 88, with no other `log stream` attached, gave 4 notices and lost 1 path of 40, and the slot does not explain that.

The cost of serialising windows is UNMEASURED. The bound below is derived from the code and was not timed. On one push, the windows that the pool and the detached trace open together number at most the `.trace` list (a fixture the pool traced leaves that list at `.githooks/pre-push:1251-1252`). That list holds only fixtures with no `inputs.decl` (`:1224`, and the `.mapped.all` join at `:960`), so the window count is derived by `for d in core/fixtures/*/; do [ -f "$d/run.sh" ] && [ ! -f "$d/inputs.decl" ] && echo "$d"; done | wc -l`. Each window holds the slot for, at most, the whole-tree `reset_atimes` (one `find | xargs touch` over the trace tree, which runs after the acquire), plus the settle loop (100 x 0.2s), plus the fixture's own run, plus the flush loop (100 x 0.2s). So a deriver waits at most the sum, over the windows queued ahead of it, of (40s plus that window's `reset_atimes` plus its fixture run). Windows from other sessions on the same uid add to the queue, because the slot is box-wide by design. In the detached trace this waiting is absorbed by `readset_trace_ceiling`: a wait long enough to reach the ceiling is killed, and the fixture stays unmapped, which is fail-closed. Under `--in-pool` the waiter heartbeats into its pool log, so `POOL_STALL` (`.githooks/pre-push:498`, 600 still polls) does not refuse the waiter. A HUNG `--in-pool` holder is itself refused by `POOL_STALL`: its group is killed, so its EXIT trap does not run and its slot is left behind, and the waiter then breaks that stale slot and takes it. Only when the holder is not under the pool (a detached `--local-map` trace) does the waiter wait until that holder's `readset_trace_ceiling`.

A slot that cannot be taken no longer wedges the wait loop. A path that is not a directory, a missing or unwritable parent, a stale directory whose `rmdir` fails, and a fifth stale break in one acquire each print one `slot: UNSLOTTED` line naming the slot and the reason, and that window runs unslotted. This fails open on overlap only: the drop-notice guard and the loss canary still discard an overlapped window.

The evidence that drives the slot is `bash core/fixtures/readset-skip/slot-world.sh core/scripts/derive-fixture-readsets.sh .githooks/pre-push`. It exits 0 when every scenario passes, 1 when one fails, and 9 when the world cannot be built. Its scenarios cover the window order (each window's stream stops before the next holder's starts), nesting, stale and foreign markers, the stale break, the heartbeat, the unslotted plain mode, the four fail-open cases and an old-empty-slot control. `core/fixtures/readset-skip`'s `slot` unit runs it against the shipped deriver and against one mutant per property. It is not this entry's receipt: the receipt is `verify: manual`, because a live receipt would read CLOSE-CANDIDATE while (3)'s solo high-load drop remainder is open.

**Absence-tolerant `!` lines, held by sentinel.** For each of the following, dropping the line from the declaration leaves `hermetic-run.sh` at rc 0, because the fixture tolerates the file's absence once it leaves the sandbox. The `!` sentinel is what binds each one while it is declared, and that is the shape the `!` grammar exists for, so none of them is a dead line: `context-mode-protect` `core/hooks/ai-dlc-context-provenance.sh`; `context-provenance` `core/hooks/ai-dlc-window.sh`; `context-sensor` `core/hooks/ai-dlc-context-provenance.sh`; `core-script-boundary` `core/hooks/ai-dlc-context-provenance.sh`; `cycle-commits-enforce` `core/fixtures/lib/preamble.sh` and `core/scripts/validate-mandatory-rules.sh`; and `derivation-capture` `core/scripts/partition-document.sh`, `core/scripts/validate-adversarial-convergence.sh`, `core/scripts/validate-artifact-budget.sh`, `core/scripts/wait-for-deliverable.sh` and `core/scripts/wfd-start-of.sh`.

**DEFECT (efficiency).** Operator-raised, 2026-10-16 ~04:40 EDT: "what about the fixtures whose readsets cant be mapped? i do not believe you cant figure out a way to refactor those so they dont need to be run every time." Filed by peer session ai-dlc-68 (listed as ai-dlc-4e [e15800]).

Measured by the filer in the main checkout: 65 fixture directories have no row in `.ai-dlc-fixture-readsets.tsv`; 62 carry `inputs.decl`, so the hook counts them MAPPED (`.githooks/pre-push:866-871`) and keys them on the declaration; the other 3 (`lib`, `check-h1-recursion`, `check-manifest-bypass`) have no `run.sh` and are not units. `.git/ai-dlc-fixture-readsets.local` marks fixtures with `#discards` 3 or more when the live trace has thrown their result away three times and stopped retrying (`:954-956`, `:1304`). Intake re-derived: 86 `#discards` rows, 27 of them at 3 or more; `fold-architect-ledger-join` and `hermetic-runner` both have a `run.sh` and no `inputs.decl`. Per the filer those two are the only units that truly run on every push (173 s and 53 s recorded). Discard reasons across all rows, per the filer: 72 "the stream dropped reports", 9 "VERDICT: the sandboxed run's verdict lines differ", 2 "LOSS CANARY", 2 "TRIP".

Owed:
1. `fold-architect-ledger-join` and `hermetic-runner` get an `inputs.decl` and `tools.decl`, so `hermetic-run.sh` runs them hermetically and the hook keys them like the other 62; the sandbox proves the declaration complete.
2. A fixture that cannot be declared because it reads the whole tree by design says so in one README sentence, and is scored under BL-583's value test.
3. Find and fix why the trace stream drops reports (72 rows); while it does, every new undeclared fixture lands in the run-every-push set.

Caveat: in a linked worktree the local map is a different file (the BL-558 symptom); the fixtures unmapped there are re-measured once (1) lands. Related: BL-558, BL-583.

Scheduled in batch 235 for a later release (scope ruling: the boundary is the release).

**The completeness proof covers `inputs.decl` only (batch 236; root cause BL-676).** `tools.decl` KEYS tools but does not RESTRICT them. The sandbox PATH is `$HR_TOOL_DIRS:$HR_BIN` (`core/scripts/hermetic-run.sh:544`: `env -i PATH="$HR_TOOL_DIRS:$HR_BIN"`; header `:54-55`: "PATH pinned to the fixed tool dirs plus a symlink farm / of the declared tools (keyed and unkeyed)"), so every system tool dir is reachable whether declared or not. Removing a tool line therefore makes no fixture fail, and a removed tool line is invisible to any receipt or fixture. Of the 5 `inputs.decl` lines, 4 are mutated by `core/fixtures/hermetic-runner/run.sh` (DC1 `core/scripts/hermetic-run.sh`, DC2 `core/scripts/core-paths.sh`, DC3 `core/fixtures/lib/`, DC4 `.githooks/pre-push`), and two groups cannot be caught. All `tools.decl` lines cannot, because the sandbox never refuses an undeclared tool, so a dropped line changes nothing a fixture can observe. The fifth `inputs.decl` line, `core/git-hooks/pre-push`, cannot on the distribution, because the fixture never opens it there, although it is still part of the key. The result "one tool removed: 0" is therefore not coverage.

Decision rule: the step-value ruling, "A step with no measured value goes" (`.claude/rules/operator-rulings.md`), cited per BL-817.

verify: manual — (3)'s solo high-load drop remainder is open, so a live receipt would read CLOSE-CANDIDATE

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

**Progress (batch 240; the entry stays OPEN, `verify: manual` unchanged, no LANDED line).** The `readset-skip-d` false RED above was reproduced from a forced DROPPED VERDICT, and its lead candidate was ruled out. Hand H2's measurements, on scratch copies; not re-measured at intake.
- **Ruled out: the watcher's first poll.** `pool_run`'s watcher first polls after `sleep 1` (`.githooks/pre-push:2257`). A forced 2 s stall in the seeded run.sh (`[ -f "$CK_CTL/slow.$f" ] && sleep 2`), on alpha, beta, delta and all three, in worlds f and h, under the unmutated block, `notfail` and `nosubtree`, moved 0 of 24 cells. Elapsed rose 2 s per stall, so the over-1 s path ran.
- **Reproduced.** A seeded unit sends `kill -TERM $PPID` once, and `pool_abort` exits 130 with no verdict. With beta dropped, the shipped `ck_mut` reads `moved worlds 'f l'`, graph's exact set; the control without the control file is unchanged. World (f) cannot tell FAIL from no-verdict, and `notfail` publishes beta's key, so f moves under `notfail` only. World (h) moves under the UNMUTATED block and `nosubtree` alike, so graph's unmutated (h) read ok only because the drop hit `nosubtree`'s drive.
- **Not established: what drops a verdict under load.** Three candidates, each a CANDIDATE and none a finding. (a) The live-trace watchdog's group `kill -TERM -- "-$dp"` / `"-$sp"` (`.githooks/pre-push:1155-1167`, `core/git-hooks/pre-push:1055-1067`) under pgid reuse; `ck_push` turns the inner live trace off, so this needs the outer group id reused. (b) A fork or process-limit failure in the inner worker. (c) The inner watcher's process walk under pid churn. The experiment to run first is (a): in a scratch copy, force the watchdog's pgid to equal the inner pool worker's group and send the TERM. If that drops a verdict the way the forced `kill -TERM $PPID` did, it reproduces the shape. (b) and (c) need a resource or timing condition that a scratch copy cannot force as directly.
- **Shipped.** On a FAIL, `ck_mut` prints, for every moved world, the want and got vectors and that world's `no verdict recorded` / `produced a verdict` / `REFUSED` pool lines (`core/fixtures/readset-skip/run.sh:5078`), so the next field red names a drop. There is no stall arm and no timing mutant: no elapsed-time dependence exists, and the derived added floor is 0.
- **Considered, not built.** A world-f field counting dropped verdicts (want 0). It names the drop, but it would turn every load drop in an unmutated drive into a new red.
- **One more field red, UNCLASSIFIED (dropped verdict or otherwise).** On R5's U56 build in batch 240, the `wait-beat-liveness` mutant `revised-postpoll-silent` read red once under load and green on rerun; the change under test did not touch `say_revised`. Figures: 1 red, 1 green rerun, base green once. Not re-measured at intake.
- **Still owed.** The trigger of the dropped verdict; census item 8 (`readset-sandbox-root-clause` all-lossy rate at pool load); Owed item 3 (solo-against-pool receipt per fixed unit, with a load-free control); census items 5 and 6; and the remaining unread `readset-skip` polls listed above.
- **Receipt for this progress (quoted, not installed as `verify:`).** `grep -c 'no verdict recorded' core/fixtures/readset-skip/run.sh` scores 0 at 5b5388924 and 1 at this release's tip. It shows that the diagnostic print exists, not that the drop is fixed.

**Progress (batch 241; the entry stays OPEN, `verify: manual` unchanged, no LANDED line).** Read at origin/main `65d51577b`; not re-measured under load.
- **Owed item (5) is discharged by BL-630.** `docs/backlog.archive.md` `## BL-630` carries `**LANDED (v0.820.0, verified 4e6670c1).**`.
- **Owed item (6) was discharged by REMOVAL, not built.** 0.807.0 (`9f8e76914`) deleted the suite-pole guard: `scripts/validate-suite-pole.sh` is absent, and `.githooks/pre-push` now has `step "suite pole (this run's longest fixture; information, not a verdict)"` (`pre-push:2723` (`information, not a verdict`)). No CPU-second gate exists, so item 6 as worded will not be built.
- **The unread `readset-skip` poll list in the batch-236 and batch-240 paragraphs is superseded.** `:981`, `:985`, `:1305`, `:1307`, `:1316`, `:1369`, `:1386`, `:1395`, `:1453-1458`, `:1680` and `:4104` no longer resolve to polls in `core/fixtures/readset-skip/run.sh` (they are `fi`, `esac`, comments and similar). The batch-236 `ck_mut` cite `4938-4959` is stale as well: the function is now at `run.sh:5047` (`ck_mut()`). The batch-240 cite still holds at `run.sh:5078` (`no verdict recorded`). Earlier paragraphs are left as written.
- **Census of `readset-skip` by `grep -nE 'sleep [0-9.]+|while .*-lt|timeout|deadline' core/fixtures/readset-skip/run.sh`, widened by `grep -nE 'while :|AW_STALL|kill -0'`.** The cited sites fall into six dispositions. Result: no cited site judges a verdict on elapsed time.
  - Poll-counted window, not judged on time: `run.sh:182` (`AW_STALL:-100`) with its tick `run.sh:183` (`${AW_SLEEP:-sleep} 0.1`), and the stub's own counted wait `run.sh:1076` (`AW_STALL:-100`) with `run.sh:1077` (`sleep 0.1`). The comment block above `aw_wait` states that nothing is judged on elapsed time.
  - Floors that decide no verdict: `run.sh:1410` (`sleep 1.1`) and `run.sh:1892` (`-lt 2`), each commented as a floor and each backed by a same-drive control.
  - Hang watchdog or safety net: `run.sh:1687` (`ct_drive "$POOL" t1 3 hang`) hands the subject a 3 s ceiling against a stub that never ends, and the wait on it is poll-counted (`aw_wait` at `run.sh:1535` (`ct_sig`)), so a slow box delays the verdict and does not change it. `run.sh:4535` (`-lt 300`) is a bounded wait of 30 s inside a seeded run.sh.
  - Retry counts, not time: `run.sh:3434`, `run.sh:3539`, `run.sh:3550` and `run.sh:3575` (each `-lt 3`) retry a real-stream loss arm up to three times. Load changes whether the arm is exercised (SKIP) and never turns it FAIL on elapsed time.
  - Stub text inside a seeded string: `run.sh:1481` (`while :; do sleep 1`) and `run.sh:1482` (`sleep 0.1`), both inside `LT_HANG`; `run.sh:3799` (`sleep 0.2`) in the log-stream stub; `run.sh:4278` (`exec sleep 30`).
  - Not load-shaped (seeded stand-in processes, file-count seeds, repetition counts and probe text): `run.sh:137` (`sleep 600`), `run.sh:1475` (`sleep 600`), `run.sh:2172` (`sleep 600`), `run.sh:1590` (`sleep 30`), `run.sh:217` (`--timeout 1s`), `run.sh:746` (`-lt 210`), `run.sh:1594` (`-lt "$reps"`), `run.sh:5032` (`-lt "$CK_N"`), `run.sh:2300` (`sleep 1; rm -f`), `run.sh:2293` (`sleep 600 & s=$!`).
  - The census disposes only the cited sites and is a floor: the first grep returns 37 hits (`grep -cE`, control `sleep 600` returns 4, an impossible token returns 0), 15 of them uncited, and the widened grep returns 36 hits of which 35 are uncited. Read by line, the 15 uncited first-grep hits are comment text (`run.sh:1468` (`exit timeout`), `run.sh:1518` (`sleep 1`)), a status-text match (`run.sh:1565` (`exit timeout`)), sed and grep over the `sleep 30` stub (`run.sh:1668` (`sleep 30`), `run.sh:1670` (`sleep 30`)), expected-signature strings (`run.sh:1686` (`timeou`), `run.sh:1688` (`3s ceiling`)), file-count seed loops (`run.sh:3417` (`-lt 1500`), `run.sh:3521` (`-lt 1500`), `run.sh:3522` (`-lt 100`)) and probe text (`run.sh:5389` (`python3 timeout`)); none judges a verdict on elapsed time. The widened grep's uncited hits (for example `aw_wait`'s `while :` and `kill -0`) were not read line by line, so the conclusion is stated for the cited sites and the 15 read ones only.
  - The census covers `sleep`, `-lt` loops, `timeout` and `deadline` spellings. It cannot see a bound spelled through a variable such as `$cl` or `$ceil`.
- **Still owed.** The trigger of the dropped verdict; census item 8 (`readset-sandbox-root-clause` all-lossy rate at pool load); Owed item 3 (solo-against-pool receipt per fixed unit, with a load-free control); the remaining census of time and numeric thresholds in assertions (BL-632).

**Progress (batch 243; the entry stays OPEN, `verify: manual` unchanged, no LANDED line).** Read at origin/main `bd0be5e51`.

- **Current lines for drifted cites, re-derived at `bd0be5e51` with grep and sed.** `--max-unstable 0` is at `.githooks/pre-push:279` (`--max-unstable 0 --min-entries 1`). The suite-pole step is at `.githooks/pre-push:2764` (`step "suite pole (this run's longest fixture; information, not a verdict)" pole_info_step`). The live-trace watchdog group kills are at `.githooks/pre-push:1171-1183` and `core/git-hooks/pre-push:1071-1083` (`kill -TERM -- "-$dp"` through `kill -TERM -- "-$sp"`). The earlier paragraphs' cites were correct at their anchored shas and are left as written: `git show f4ca6764:.githooks/pre-push | sed -n 269p` returns `--max-unstable 0 --min-sh-receipts 0 --min-entries 1`, and `git show 65d51577b:.githooks/pre-push | sed -n 2723p` returns the `step "suite pole ..." pole_info_step` line.
- **Discharged: BL-632 is LANDED**, at `docs/backlog.archive.md:35919` (`**LANDED (v0.849.0, verified ee52d23d).**`, under the heading at `:35917`). The batch-241 paragraph's `**Still owed.**` clause "the remaining census of time and numeric thresholds in assertions (BL-632)" is therefore discharged; the old text is left as written.
- **Candidate (a) NOT REPRODUCED (hand H3's scratch harness; not re-measured at intake).** The harness sourced the hook's `FIXTURE_POOL_BEGIN..END` span and `readset-skip`'s `CK_HELPERS` (real `ck_push`, live trace off, `AI_DLC_FIXTURE_JOBS=1`) and ran the watchdog subshell verbatim with `cl=1` and an injected `dp`, for both `.githooks/pre-push` and `core/git-hooks/pre-push`, with identical results. Arms: base ok x3, rc 0. Positive control (`beta` runs `kill -TERM $PPID`): `FAIL beta (no verdict recorded)` and `2 of 3 fixtures produced a verdict`, rc 1, which is H2's shape. Negative (`dp` = an unrelated `set -m` group): watchdog exit 3, ok x3. Alias (`dp` = the inner worker's pgid, which equals the outer unit's group): watchdog exit 3, outer unit exit 143, no verdict lines. `dp` = `beta`'s own group gives `FAIL beta` with a verdict recorded. `dp` = the inner watcher's group gives ok x3. Reason: the inner pool worker never leads its own group, so a group TERM reaching it also ends xargs and the fixture; a single dropped verdict with siblings ok needs a TERM to the worker's pid alone, and the watchdog signals only groups. Pre-reap aliasing cannot occur, because `$dp` is an unreaped child.
- **NOTE (no fix built).** A window remains after the reap: the watchdog's `kill -0 -- "-$dp"` poll and unconditional `kill -KILL -- "-$dp"` (`.githooks/pre-push:1172-1173`) can still fire on a reusable id if its sleep ended just before `kill "$wp"` (`:1181`). Reuse would need pid wrap within that window, and the table above shows the result would not be a single drop anyway.
- **Still owed after this paragraph.** The trigger of the dropped verdict (candidates (b) and (c)); census item 8; owed item 3. Items 8 and owed-3 are not run under the batch's NO TIMING RUNS ruling.

Decision rule: the step-value ruling, "A step with no measured value goes" (`.claude/rules/operator-rulings.md`), cited per BL-817.

verify: manual

## BL-685 — BL-679's recorded `--verify` PASS never forms when the dist shares its ref store with active worktrees

**LANDED (v0.962.0, verified 8fd3bb945).** RETIRED with BL-679's cache, not fixed: the recorded `--verify` PASS is deleted from `emit-report.sh`, because it never formed on graph's shared dist (this entry's own finding), it shipped off by default, graph never set `EMIT_REPORT_VERIFY_CACHE`, and under the operator's step-value ruling a step with no measured value goes. `dist-clone.sh` stays as the ref-stable, main-only dist every reconcile reader takes; only its cache reason is retired.

Outcome measured: no graph pipeline step; the cost lives in core/skills/ai-dlc-update/reconcile/emit-report.sh, whose cache never formed on a shared dist, so it removed nothing to measure.

**DEFECT, efficiency.** Found by ai-dlc-77 [e29316] in batch 236 while building BL-679.
Decision rule: the step-value ruling, "A step with no measured value goes" (`.claude/rules/operator-rulings.md`), cited per BL-817.
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
- **Round 5 F1 (BLOCKER):** a tracked symlink to an IGNORED in-tree file passed er_link_inside while no field hashed the target, so an edit through the link hit a stale PASS; probe p1-symlink-ignored-target.sh; fixed by er_link_target hashing the resolved file's raw bytes (and refusing a directory target) in consindex's 120000 arm and er_hash_list; arm PC-V32.
- **Round 5 F2 (BLOCKER):** under `* text=auto` a staged CRLF save is the same LF blob, so index and status read clean while the detectors cmp raw CRLF bytes; probe p2b-crlf-restaged.sh; fixed by consindex keying every tracked file's raw bytes whenever er_normalises finds a text/eol/filter/ident attribute, core.autocrlf or core.eol; arm PC-V33.
- **Round 5 F3 (DEFECT):** under core.checkStat=minimal plus core.trustctime=false, a same-size, mtime-kept rewrite of a tracked core file left status clean, so the 0.859.0 engine accepted a stale PASS (rc 0) where a fresh render exited 1 (trustctime=false alone, p3, was refuted); probe k3.sh; fixed by er_cgit forcing `-c core.trustctime=true -c core.checkStat=default`; arm PC-V37.
- **Round 5 F4 (DEFECT):** consignored's hand-written roots omitted `.githooks`, a map_consumer destination, so an ignored hook edit hit; probe p4-githooks-ignored.sh; fixed by er_mapped_roots deriving the mapped roots from preclassify.sh's map_consumer; arm PC-V34.
- **Round 5 F5 (DEFECT):** an empty directory is invisible to git while detectors test `[ -d ]`, so removing an empty bound fixture dir hit; probe p6-empty-dir.sh; fixed by consignored listing every empty directory under the read roots; arm PC-V35.
- **Round 5 F6 (BLOCKER):** a non-repository directory named `.git` below the root is skipped by every git listing while layer-drift's find reads beneath it, hiding HARD-OVERRIDE-BASE-UNRESOLVABLE; probe p5-dotgit-component.sh; fixed by er_key refusing any `.git` component below the root (top-level `.git` and `.claude/worktrees` pruned); arm PC-V36.
- **Round 6 B1 (BLOCKER):** a read root reached through a symlinked parent (consumer `scripts` a link to an outside or ignored dir) hid every file under it from consignored's `ls-files -o -i -- scripts/ai-dlc`, which does not cross a symlinked directory; probe symroot-out / symroot-in; fixed by er_key refusing (R2) a symlink at or above any read root (er_read_roots, walked component by component) and any symlink under one; arm PC-V39.
- **Round 6 B2 (BLOCKER):** preclassify.sh's file_hash and layer-drift.sh's adj_digest ran `git -C "$DIST" hash-object` on consumer files without `--no-filters`, so a non-bare dist's unkeyed work-tree `.gitattributes` rewrote consumer bytes; probe distattr; fixed by `--no-filters` at both sites and by er_key refusing (R1) a dist that is not bare; arms PC-V42 (the detectors run directly, against a pre-fix control copy) and PC-V38.
- **Round 6 B3 (BLOCKER):** a tracked symlink's TARGET exec bit was unkeyed (er_link_target keyed bytes only) while preclassify's mode_at_theirs tests `-x` through the link; probe linkexec; fixed by er_key refusing (R2) every tracked symlink, which made the 120000 arm of consindex unreachable, so it is removed; arms PC-V39, PC-V32 (rewritten: the link refuses, the regular file hits).
- **Round 6 B4 (BLOCKER):** an `sh` receipt naming a consumer `.git/` path is tested for existence by ledger-reverify.sh while the key prunes `.git`; probe dotgit-receipt; fixed by er_key refusing (R4) when any live sh receipt names a `.git/` path, read through ledger-reverify.sh's own token split in a new `--receipt-tokens` mode; arm PC-V41.
- **Round 6 B5 (BLOCKER):** an engine file that is a symlink was skipped by er_kf_engine's `find . -type f`, so an edit to its outside target hit; probe englink; fixed by er_key refusing (R3) any symlink inside the engine directory; arm PC-V40.
- **Round 6 D1 (DEFECT, LIMIT, NOT FIXED):** a file changed and restored during the render (ABA between the key taken before it and the key taken after) records a PASS for bytes the detectors read in the middle state; stated in emit-report.sh's THE LIMITS (6).
- **Round 6 D2 (DEFECT, LIMIT, NOT FIXED):** a report file placed at a detector input (the push-candidate ledger) is excluded from the work-tree fields as the report, so an edit to it outside the region hits; stated in emit-report.sh's THE LIMITS (7).
- **Round 7 B1 (BLOCKER):** a receipt token `docs/../.git/x` passed ledger-reverify.sh's prefix whitelist, missed R4's `.git/` prefix test, and its `[ -e ]` resolved into the git-dir; probe p1 dotdot; fixed by REPLACING R4 with a receipts key field: every `--receipt-tokens` subject as its lexical form (`.`/`..` resolved as text, a climbing token keeping `../`) plus `present`/`absent` by `[ -e ]` of the token as ledger-reverify.sh spells it, so the bit is the OS's answer to the engine's own read; arms PC-V43 (the normaliser, extracted and run alone), PC-V41 (rewritten: a `.git/` subject keys, not refuses).
- **Round 7 B2 (BLOCKER):** the same engine `[ -e ]` was unkeyed for a subject outside every read root: an untracked empty directory, an ignored file, a path under `.claude/worktrees/`; probes p1 emptydir, p3, p1 wt; fixed by the same receipts field; arm PC-V44.
- **Round 7 B3 (BLOCKER):** retired-fixtures.sh's `git log --all` walks every linked-worktree HEAD of the dist while distrefs keyed for-each-ref and the main HEAD only; probe p2; fixed by distrefs keying `git worktree list --porcelain`; arm PC-V45.
- **Round 7 B4 (BLOCKER):** layer-drift.sh prefixed `tests/fixtures/` to an extension's `fixtures:` value and tested `[ -d ]` unsanitised, so `../../docs/x` escaped the read roots; probes p4a/p5a; fixed at the one reader: a value with a `..` component or a leading `/` renders EXTENSION-FIXTURE-UNBOUND naming the escape and is never tested on disk, so no key change is needed; arm PC-V46.
- **Round 7 D3 (DEFECT):** a non-ignored `.claude/worktrees/agent-x/` holding a `.git` lists in conswork's `ls-files -o` with a trailing `/`, and er_hash_list returned 1 without er_refuse, a silent miss on every --verify; probes p4b/p5b; fixed by a named refusal (`a listed path is a directory (a nested work tree or an unignored worktree): <p>`); arm PC-V47.
- OWED: `.claude/worktrees/` among install's transient ignores (touches install.sh; held out of the round-7 fix).
- OWED to round 8: R2 against a hardlink, firmlink or bind mount (UNRUN in round 7).
- **Round 8 B1 (BLOCKER):** relabel-extension-checks.sh read `$SKILL_DIR/$hooks` with no guard, so a `hooks:` value escaping to `.git/`, an ignored `.claude/worktrees/` file or an ignored file outside every root was unkeyed; fixed by consumer-read.sh refusing `..` and a leading `/` (PC-V49).
- **Round 8 B2 (BLOCKER):** layer-drift.sh's unquoted `for fx in $(fm … fixtures)` globbed the value against the engine's working directory before the round-7 escape guard; fixed by `set -f` in every closure script's preamble (PC-V50).
- **Round 8 B3 (BLOCKER):** the receipts field's lexical label gave `docs/a/../d` and `docs/b/../d` one row while the OS resolves them through different prefixes; fixed by deleting the label and keying the resolved path in a read log (PC-V51).
- **Round 8 B4 (BLOCKER):** a `.claude/WORKTREES` receipt passed the case-sensitive inside test, so its bytes were never hashed on case-insensitive APFS; fixed by logging the path the OS reads and pruning a case variant only when it is the same directory (PC-V52).
- **Round 8 B5 (BLOCKER):** preclassify.sh tested `$CONS/scripts/<name>` under a bare `scripts/` no read root listed; fixed by routing it through the read log (PC-V53).
- **Round 8 B6 (BLOCKER, the class):** every detector resolved consumer paths on its own; closed by one helper (`consumer-read.sh`) that every closure read goes through, a key that re-takes the read log, and `scripts/validate-consumer-reads.sh` forbidding a raw consumer read in the derived closure. N1 (a symlink at `.claude/worktrees`) now refuses by name (PC-V54).
- **Round 8 residual (OPEN, round 9 targets it first):** a program run through `cr_run` reads files the log cannot see; the hand-listed roots and the ignored-file field stay in the key as a belt, so a `cr_run` program reading a file outside every belt root, or a tracked file outside the index fields, is unkeyed.
- Round 8 Q3: a hardlink and an unprivileged `hdiutil` mount each miss correctly; a firmlink and a bind mount are UNRUN (no unprivileged way to create them on macOS).
- Owner: ai-dlc-69 [9599d6] (formerly ai-dlc-77 [e29316]).
- **Part (a), BUILT (v0.919.0, batch 240, R5 U9; PARTIAL, the entry stays open):** `.claude/worktrees/` is in the consumer's transient-ignore block. It comes from a declared `out_of_root` field in `core/schemas/pipeline-state-paths.json`, which `sync-transient-ignore.sh` renders inside the same markers. `install.sh` renders it at install time. A pull does not write it: `.gitignore` is user-owned, so `apply.sh`'s `--check` reports the block as drifted and emits a `transient-ignore` WORKLIST row naming `bash scripts/ai-dlc/sync-transient-ignore.sh`, and the rule lands only when that command is run. A consumer therefore gets the `.claude/worktrees/` ignore line only when it runs that row's command, and the drift row is EXPECTED on graph's first pull after this release; it is not a regression. I95(f) refuses a transient `paths[].ignore` that escapes root and an `out_of_root` pattern that sits under root, and it probes both directions. `apply.sh`'s `transient_ignore_row` includes the field in its tracked-path scan, and `transient-ignore-block` carries arm 10 and mutant M6. **Side effect:** `emit-report.sh`'s `consignored` listing does NOT change, because it already prunes `.claude/worktrees/`. On the first `--verify` after a consumer re-renders its block, `conswork` changes (the unignored worktree entries it listed drop to 0) and `consindex` changes (the tracked `.gitignore` bytes). A consumer that had an unignored worktree could not form a BL-679 record before, so for it the rule makes a recorded PASS possible rather than invalidating one; any consumer that already holds a recorded PASS has it invalidated once by the `consindex` change. Scored part-(a) receipt, held here because `backlog-reverify.sh` reads only the entry's first `verify:` line and part (b) is still owed (fix 0, `OOR_PATTERNS=""` field-not-rendered non-zero, pattern-in-`paths[].ignore` non-zero, hard-coded renderer line with no `out_of_root` field non-zero, single-jq renderer emitting both halves 0):
  `d=$(mktemp -d) && bash core/scripts/sync-transient-ignore.sh --root "$d" >/dev/null 2>&1 && awk "/^# BEGIN AI\/DLC transient/{b=1} b{print} /^# END AI\/DLC transient/{b=0}" "$d/.gitignore" > "$d/blk" && grep -qxF .claude/worktrees/ "$d/blk" && grep -qxF _bmad-output/.wait-beats/ "$d/blk" && jq -e "[.out_of_root[]?|.pattern]|index(\".claude/worktrees/\")" core/schemas/pipeline-state-paths.json >/dev/null && jq -e "[.paths[] | .ignore // empty | select(startswith(\".claude/\"))] | length == 0" core/schemas/pipeline-state-paths.json >/dev/null`
- **Part (b), OWED, and it is a REVIEW rather than a build:** the round-9 adversary on the `cr_run` residual above must run before the recorded-PASS default is flipped on.

- **Round 9 engine release (batch 241, lead ai-dlc-58, r9; BL-685 stays OPEN on `verify: manual`, the default stays OFF):** fixes the round-9 BLOCKERs B1-B6 and D1 in the engine. Engine code: `emit-report.sh`, `consumer-read.sh`. Validators: `core/scripts/validate-hook-registration.sh`, `scripts/validate-consumer-reads.sh`. Fixture: `core/fixtures/reconcile-emit-report/` (`run.sh`, `inputs.decl`, `tools.decl`, `receipt-round9.sh`). Rulebook: none. Packaging: none.
  - **B1:** theirs' `validate-hook-registration.sh` ran unlogged. It now runs through `cr_run_reads` and records its own reads in-process (`HOOKREG_READS_OUT`, a sentinel, `python3 -I`). On a python3 without `sys.addaudithook`, the recorder writes no list, so the engine refuses rather than accepting a partial list.
  - **B2:** a consumer-copy validator writes `!` and refuses by name.
  - **B3:** the consumer's HEAD (unborn, detached or a symbolic ref) and the `shallow` file are keyed.
  - **B4:** a derived env-name set is keyed (ten names today, no `CLAUDE_CODE_*`). LIMIT: a text grep cannot see `${!name}` or `env | grep` readers.
  - **B5:** gitlinks are keyed by their staged index line, pruned from the dotgit find, skipped in `er_hash_list`, and refused by name for a glob-character name, a gitlink at, under or containing a read root, and `submodule.recurse=true`. A gitlink at, under or containing a read root refuses by name, and arm V76 with mutant M-b5-root holds that refusal.
  - **B6:** an ignored nested repository outside every read root is accepted; a non-ignored one, one inside a root or one containing a root refuses by name.
  - **D1:** `validate-consumer-reads.sh` flags a non-`$SELF`, non-`cr_` program handed a rooted argument.
  - An armed record-time cause line is written: `emit-report: recorded PASS not recorded: <cause>`.
- **Round 9 arms and mutants:** V55 (B2 refusal), V59 (B1 and mixed engines c), V60 (B3), V61 (B4), V62 (the secret arm: a `CLAUDE_CODE_MESSAGING_TOKEN` marker appears in no cache file, with a positive control), V63 (M-direxcl's new subject, so M-direxcl is kept, not retired), V64-V75 (B5/B6). V18/V19 moved onto a file whose exec bit `mode_at_theirs` tests. G-miss (V66) is killed by no single-site mutant, because three fields move at once, and its header says so. Mutant scores: 24 mutants, scored by an independent rescore after the tip-adversary fold, by a hand that built none of the work (one shard-a run through `hermetic-run.sh` with a fresh verdict store), which gave PASS 154/154 in shard a, exit 0, at tip 997fc4ee5 (restacked onto 0.937.0). All 24 PC-V mutants fail exactly their declared kill set: M-region [V3], M-direxcl [V63], M-exit3 [V9 V10], M-cksum [V56], M-base [V56 V57 V58], M-sha [V57 V58], M-unarmed [V56], M-hex [V58], M-b1 [V59], M-b2 [V55], M-b3 [V60], M-b4 [V61], M-secret [V62], M-gitlink-refuse [V64 V65], M-gitlink-prune [V64], M-b5-root [V76], M-hashlist-skip [V67], M-recurse [V68], M-glob [V69], M-b6-ignored [V73 V74 V75], M-b6-under [V71], M-b6-contains [V72], M-b6-dotgit-path [V73 V74], M-b6-batch-rc [V75]. None killed an arm outside its set, and none was NOT BUILT, UNSCORED or SURVIVED. M-b6-ignored's three arms each assert the one refusal it deletes; M-b6-dotgit-path kills V73 because under it the refusal names `x/.git` rather than the directory `x`.
- After the rescore, the 0.938.0 dress found one non-comment here-string the B5/B6 change had added to emit-report.sh (`done <<< "$_er_dotgit"`), which BL-360 forbids; it now reads a file staged through er_stage with a named refusal on a failed write, procsub-staged-refusal-boot-b passes (52 assertions), and the B5/B6 probe's worlds are byte-identical, so the rescore above stands for the mutants (their anchors all occur once on the fixed engine).
- **Round 9 receipt:** `core/fixtures/reconcile-emit-report/receipt-round9.sh` (100755, not installed as `verify:`) scores fix 0; base 2; B1, B2, B3 and B4 each reverted alone 1, red only in its own world; B6 reverted alone 2, red only in B6; B5 reverted 2, red in B5 and B6, because that revert is the pre-B5/B6 engine and also removes B6 (B5 was not reverted alone); second spelling 0. LIMIT: no receipt world has an unignored nested directory holding a real repository (V73-V75 seed `x/.git` directories that are NOT repositories, which takes the same refusal code path, and no fixture or receipt world holds an unignored nested real repository).
- **Round 9 rehearsal** on a `file://` clone and APFS copies of the real consumer, graph: mixed engines (a), the old engine (graph's installed 0.928.0) with the new validator, was byte-identical except two lines caused by the swapped THEIRS tree. (c), the new engine with an old validator, fails closed with `! reads-list` (variant clone). (b) on graph's real layout: every armed run refuses by R2 (an ignored symlink, `.claude/skills/swap-integration`, under the `.claude` read root), and the B5 and B6 causes no longer fire; this is NOT a hit rate. A variant clone without the gitlink: 3/3 hits. With that link removed (a control, not graph): records and hits, and R2 is the last refusal on graph's layout. The derived env names were all unset in every run, so variation inside a real pull was held, not tested.
- **Round 9 D (DEFECT, NOT FIXED) BL-800:** the read log's L refusal (`emit-report.sh`, `er_log_entries`' awk) never fires, because awk's END exit overrides the rule's exit. It is unreachable at main and in this release because R2 refuses first. That rests on the contract adversary's census and was not measured in every world; no claim is made that no consumer was ever exposed. It is fixed in the following release.
- **Round 9 still PARTIAL (named, not fixed):** the `:371`/`:379` hardlink, firmlink and bind mount; untracked-not-ignored keyed by conswork per the code, not probed; limit (6); the receipt's clock and network; the rest of the key's fields, not re-reviewed in round 9; and two refusals that have no probe, the B6 check-ignore rc>=2 refusal and the gitlink-newline refusal. The change to the pole's cost is unmeasured until the dress; the new arms land in phase pcache, shard a.
- **Round 9 B7 release (batch 241, lead ai-dlc-58, r9 (B7); BL-685 stays OPEN on `verify: manual`, the default stays OFF):** an untracked symlink under a read root no longer refuses outright (R2's per-root walk is removed). Engine code: `core/skills/ai-dlc-update/reconcile/emit-report.sh` only. Fixture: `core/fixtures/reconcile-emit-report/` (`run.sh`, `receipt-round9.sh`). Rulebook: none. Packaging: none. It files and closes BL-800 in the same release.
  - **B7:** a DIRECTORY link is keyed by its IDENTITY (its path, each readlink string in the chain, its resolved root-relative path, and kind `d`), never by the content behind it. A FILE link keeps its byte hash. A link is accepted only if it is untracked, its chain resolves inside the consumer root with every hop inside, it is not dangling, its target neither equals nor contains the link or any read root, and it does not lie under a root a consumer program walks unlogged (every `corpus-root:`, `_bmad-output`, `.claude/hooks`). Each failure refuses by name. B7 also refuses a dir link whose resolved target holds content git does not key. B7 accepts a directory link only when the files on disk under its resolved target (`find ! -type d`, so a link inside the target is an entry and never followed) EQUAL the files git tracks there. Any file on disk git does not list refuses by name: ignored, untracked, under a `.git` component, a case or Unicode-normalisation variant, a nested repository or submodule, a special file. So does a tracked file missing from disk, and so does a target with no tracked file. The equality replaced an earlier ignored-only listing (an absence check that read zero whenever a spelling missed), and that listing is deleted. Cost: one `git ls-files` per key take when a directory link is accepted, plus four forks per accepted link.
  - **The guarantee**, stated in the engine beside the key: content is not keyed because every logged walk refuses an L crossing (`er_log_entries`), and that refusal is what keeps a read-through out of the key. LIMIT: a ledger `sh` receipt can read through anything, as it already could. KNOWN LIMITS: B7 closes link spellings, not the receipt limit. A `verify: sh` receipt can still read ignored content without any link. Other known limits: an empty directory under an accepted target is keyed by nothing; a clean or eol filter can hide an edit to a tracked file, link or not; there is a window between the target walk and the receipt's read. The bounding delta review: no probe got the equality test to accept a target whose content is not all keyed. NOTE: a tracked filename containing a newline is refused by the existing `ls-files -v` flag check, which fails closed.
  - **BL-800 (fixed and closed here):** BL-800 was a live exposure at main from 0.889.0 to 0.940.0 whenever the cache was armed with `EMIT_REPORT_VERIFY_CACHE=1` (it is off by default), through any LOGGED consumer read whose path crosses an ignored symlink outside every read root, for example a ledger `verify: sh` receipt's subject (the measured shape B), or a resolved hooks: or fixtures: value checked with cr_test. `er_log_entries`' awk was `$3 ~ /^L / { exit 0 } END { exit 1 }`, which always exits 1 because awk runs END after a rule's `exit` and END's exit wins; it is now `{ f = 1; exit } END { exit !f }`. Measured world (shape B): an ignored link `docs/retro` pointing at an outside dir, and a ledger receipt `verify: sh grep -q x "$CONSUMER/docs/retro/f.md"`. At base 2e322a41b the record formed carrying `read t docs/retro/f.md L docs/retro`; after f.md changed, the armed run accepted the recorded PASS while a fresh render added a `CLOSE-CANDIDATE PC-R9REACH` row. At the fix, it refuses with `R2 a symlink lies on a consumer path a detector read (docs/retro/f.md)`. R2's per-root walk never visits docs/, which is why R2 did not pre-empt it. The narrower true claim: R2 DID pre-empt the read-root shapes (a link at `.claude/skills/ai-dlc` and a link above a read root were both refused at base), and a logged walk rooted outside the read roots cannot be built, because every logged walk is rooted under a read root. Consumer exposure not measured: the read of graph's settings and transcripts was not run. Exposure needs two conditions: the cache armed via `EMIT_REPORT_VERIFY_CACHE=1`, and a `sh` receipt crossing an ignored link outside the read roots.
  - **CORRECTION of a false claim:** 0.939.0's text, and the "Round 9 D" bullet above, said BL-800 was "unreachable at main and in this release because R2 refuses first". That was false. It rested on a census, and a read-only experiment then built a counterexample (shape B above).
  - **Measured by the contract adversary:** no closure detector reads through a graph-shaped link: 33 logged reads, 0 naming the link or target (control 12), and the render and sorted read log were identical after the content behind the link changed.
  - **Round 9 B7 arms and mutants:** thirteen new arms in phase pcache, shard a: V77 B7-pos, an ignored dir link with an IGNORED target, records, HITs, and still HITs after the content behind it changes; V78 retarget, which MISSes, plus a respelling of the same target, which MISSes again (a plain repoint misses even without the readlink string, because the resolved path is keyed); V79 file link, which MISSes on a content change; V80 outside; V81 dangling; V82 contains the link (`..`); V83 contains a read root; V84 under _bmad-output; V85 under .claude/hooks; V86 under a corpus-root (docs/escalations); V87 tracked link (the existing R2 cause); V88 BL-800 X2 shape (`.claude/skills/ai-dlc` itself a link); V89 BL-800 shape B (the ignored `docs/retro` link read by a ledger receipt). V80-V89 each refuse by name with the record untouched. PC-V39 shape (c) is rewritten from an R2 refusal to accept-and-key, as a deliberate behaviour change; fold arms: V90 (an ignored target refuses: no tracked file), V91 (a fully tracked target records and HITs, then MISSes on change), V92 (a case-variant spelling refuses), V93 (a target under `.git` refuses) and V94 (a non-repository `.git` directory under a tracked target refuses). Mutants: eleven new mutants, M-b7-key [V78], M-b7-inside [V80], M-b7-contains-link [V82], M-b7-contains-root [V83], M-b7-corpus [V84], M-b7-hooks [V85], M-b7-croot [V86], M-b7-filehash [V79], M-b7-logL [V88 V89], and M-b7-unkeyed and M-b7-presence (described below), which makes 35 in the reconcile-emit-report mutant set. M-b7-logL makes both worlds record and then hit stale after the content behind the link changes. The dangling-link guard was deleted as vacuous (its removal changed no outcome); V81 asserts the refusal that fires. Fold mutants: M-b7-unkeyed [V90 V92 V93 V94] drops the equality test; M-b7-presence [V94] accepts on tracked-presence alone. On a case-sensitive volume V92's link dangles and refuses earlier, so M-b7-unkeyed does not kill V92 there. Receipt: receipt-round9.sh gains a B7 world and a BL-800 world (shape B, plus the X2 sub-world), and a world selector. `receipt-round9.sh BL-800`: fix scores 0; base 0.940.0 scores 1, by a stale accept; the dead awk restored scores 1; the check deleted outright scores 1. The whole receipt: fix scores 0; base scores 2 (the B7 world cannot record on the old engine). Rescore: an independent rescore by a hand that built none of it: shard a PASS 183/183, exit 0, at tip 4aa215cc0 (restacked onto 0.940.0); all 35 mutants fail exactly their declared sets.
  - **Round 9 B7 rehearsal** on an APFS copy of the real consumer graph, WITH its ignored link `.claude/skills/swap-integration` present and its gitlink: 3 of 3 armed pairs recorded and hit on the shipping tip 4aa215cc0, re-taken on the same APFS copy with the link present (its target holds 2 files on disk, 2 tracked), the 12-field key identical within each pair, no refusal in any run. This is the real-graph-layout hit-rate figure. The derived env names were all unset, so variation inside a real pull was held, not tested. The copy's 17 submodule pointers were asserted inside the copy, and the real graph was unchanged before and after.
  - **Cost:** the R2 per-root `find` walk is removed (one fewer `find` per read root on every key take). Per link: 2 forks, or 3 for a directory link.
  - The BL-360 here-string fix from 0.939.0 is preserved, with 0 non-comment `<<<`.
  - **Still PARTIAL (named, not fixed):** the hardlink, firmlink and bind mount; limit (6); the receipt's clock and network; the rest of the key's fields, not re-reviewed in round 9.
- **Round 9 D-r9b-1 (DEFECT, BUILT in the release that carries this line, a precondition for the flip):** a predicate run through `cr_run` reads the index stat cache, which the key does not hash. Round 5 F3 forces `core.trustctime=true` and `core.checkStat=default` only on the KEY's own status (`er_cgit`), while the predicates `predicate-differential.sh` runs through `cr_run` run plain git under the consumer's config. The example is `validate-snapshot-conservation.sh:263`, `git -C "$ROOT" diff "$BASE" -- "$SNAPSHOT"`. Under a relaxed stat config, a same-size, mtime-kept rewrite makes that diff read the stale index blob. The key hashes the same bytes at record and hit time, so a later `touch` changes what the predicate reads while no key field or logged read moves, and the armed run accepts a stale PASS where a fresh render exits 1.
  - **Probe** `p2-snapstat.sh`: under `checkStat=minimal` plus `trustctime=false`, `checkStat=minimal` alone and `trustctime=false` alone, the armed run was rc 0 (accepted) and the fresh run rc 1 (STABLE -> RECLASSIFIES). The default-config control was correctly accepted. Each single setting exposes it, which is wider than F3's measured conjunction.
  - **Exposure** needs the cache armed, either relaxed setting, a pull whose predicate read-set differs between BASE and THEIRS, a same-size mtime-kept rewrite of a corpus file, and an mtime change between verifies. The reference consumer is not exposed (all three settings unset): `git -C /Users/n8/git/graph config --get core.checkStat`, `core.trustctime` and `core.ignoreStat` each printed nothing (rc 1), and the control `git -C /Users/n8/git/graph config --get core.repositoryformatversion` printed 0.
  - **Built:** `er_key` in `core/skills/ai-dlc-update/reconcile/emit-report.sh` refuses `core.checkStat` other than `default` (compared case-insensitively) and `core.trustctime` set to a false boolean. Each is read with the exit code captured: unset allows, an unreadable value refuses. The `core.ignoreStat` read moved onto the same helper. The forced `trustctime` and `checkStat` options in `er_cgit` were deleted as vacuous, since every admitted config is now default. Arm PC-V37 was rebuilt in the p2 world (the snapshot validator through `cr_run`, cause checkStat), with the pre-fix two-layer revert as mutant M-v37 (it stale-hits PC-V37). The single-refusal arms are PC-V97 and PC-V99 (`checkStat=minimal` and `MINIMAL` refuse), PC-V98 and PC-V100 (`default` and `Default` allow), PC-V101 and PC-V103 (`trustctime=false` and `no` refuse), PC-V102 (`trustctime=true` allows) and PC-V108 (a checkStat refusal at hit time). Mutants: M-v37a deletes the checkStat refusal and fails PC-V97, PC-V99 and PC-V108; M-v37b deletes the trustctime refusal and fails PC-V101 and PC-V103. The p2 world cannot kill a single-refusal mutant, because with er_cgit's forced `-c` gone the key and the predicate run the same config and agree; the single-key mutants are killed in a raw-bytes world (a ledger `verify: sh grep` receipt over a tracked file rewritten same-size, mtime kept).
  - **Progress:** D-r9b-1, the flip's precondition, is built. The cache default is NOT flipped. Flipping it is a later lead ruling and still needs mutant A2b.
  - **fsmonitor, also built:** `er_key` also refuses `core.fsmonitor` when it is set to anything other than a false boolean (unset allows). Arms: PC-V104 (a lying hook path refuses), PC-V105 (`false` allows), PC-V106 (`true` refuses) and PC-V107 (fsmonitor injected through GIT_CONFIG_COUNT/KEY/VALUE refuses). It also refuses a non-empty `GIT_TEST_FSMONITOR`, which turns fsmonitor on with `core.fsmonitor` unset (arm PC-V109; PC-V110 is its ALLOW twin, where `GIT_TEST_FSMONITOR` is set empty and the run records and hits; mutant M-v37g deletes that refusal and fails exactly PC-V109, by a stale hit, with PC-V104 in scope as its control). Mutant M-v37f deletes the refusal and fails PC-V104, PC-V106 and PC-V107. There is no M-v37c: an invalid `core.ignoreStat` makes git itself exit 128 on ls-files and status before the read is reached. It is a refusal and not a forced `-c core.fsmonitor=false` because forcing would reach only the key's own git calls, while `cr_run` predicates run plain git under the consumer's config.
  - **Scored receipt (held as text, not installed as `verify:`; the entry stays `verify: manual`).** The snippet runs under `set -uo pipefail` with the engine path as `$1`. It cuts `er_cfg_read` and the refusal lines out of the engine (never retyped), runs them against fresh `git init` consumers, and exits 0 only if `checkStat=minimal` and `MINIMAL` refuse, unset and `Default` allow, `trustctime=no` refuses, `fsmonitor=true` refuses, `fsmonitor=false` allows, a non-empty `GIT_TEST_FSMONITOR` in the environment of the extracted block refuses and an empty one allows. The receipt unsets `GIT_TEST_FSMONITOR` at its top, so it does not depend on the caller's environment.

  ```sh
  set -uo pipefail
  unset GIT_TEST_FSMONITOR
  E="${1:?engine path}"
  T="$(mktemp -d)"; _er_tmp="$T"
  cr_git() { local r="$1"; shift; git -C "$r" "$@"; }
  er_refuse() { printf '%s\n' "$1" > "$_er_tmp/key.refused"; return 1; }
  awk '/^er_cfg_read\(\) \{/{p=1} p{print} p&&/^}/{exit}' "$E" > "$T/read.sh"
  awk '/^  er_cfg_read core\.ignoreStat --bool/{p=1} /AN INHERITED MEMO/{p=0} p{print}' "$E" > "$T/block.sh"
  [ -s "$T/read.sh" ] && [ -s "$T/block.sh" ] || { echo "extract empty"; exit 2; }
  { cat "$T/read.sh"; echo 'chk() {'; cat "$T/block.sh"; echo '  return 0; }'; } > "$T/fn.sh"
  bash -n "$T/fn.sh" || exit 2
  . "$T/fn.sh"
  fail=0
  try() {
    CONSUMER="$(mktemp -d "$T/c.XXXXXX")"; git init -q "$CONSUMER"
    [ -z "$2" ] || git -C "$CONSUMER" config "$1" "$2"
    if chk 2>/dev/null; then got=allow; else got=refuse; fi
    [ "$got" = "$3" ] || { echo "WRONG $1=$2 want $3 got $got"; fail=1; }
  }
  tryenv() {
    CONSUMER="$(mktemp -d "$T/c.XXXXXX")"; git init -q "$CONSUMER"
    if GIT_TEST_FSMONITOR="$1" chk 2>/dev/null; then got=allow; else got=refuse; fi
    [ "$got" = "$2" ] || { echo "WRONG GIT_TEST_FSMONITOR=$1 want $2 got $got"; fail=1; }
  }
  try core.checkStat minimal refuse
  try core.checkStat MINIMAL refuse
  try core.checkStat "" allow
  try core.checkStat Default allow
  try core.trustctime no refuse
  try core.fsmonitor true refuse
  try core.fsmonitor false allow
  tryenv /nonexistent refuse
  tryenv "" allow
  [ "$fail" -eq 0 ] && echo OK
  exit "$fail"
  ```

    Scores, each copy proven different from the tip by `cmp -s`: the fix (tip engine) scores 0. Regression r1 (the trustctime refusal line deleted) scores 1, failing on `trustctime=no`. Regression r2 (the lowercasing removed from `er_cfg_read`, so the compare is case-sensitive) scores 1, failing on `Default`, which it wrongly refuses. Regression r3 (the `GIT_TEST_FSMONITOR` refusal line deleted) scores 1, failing on `GIT_TEST_FSMONITOR=/nonexistent`, which it wrongly allows. A second correct spelling (`er_cfg_read` reading `config --get-regexp` and taking the last line per lowercased key) scores 0. N2 control: the tip scored with `GIT_TEST_FSMONITOR=/nonexistent` exported in the caller's environment still scores 0. Measured exits: tip 0, r1 1, r2 1, r3 1, second spelling 0, tip with the variable exported 0.
  - **Original owed fix (now built, kept for the record):** `er_key` in `core/skills/ai-dlc-update/reconcile/emit-report.sh` refuses by name, beside the existing `core.ignoreStat=true` refusal, when the effective `core.checkStat` is anything other than `default` or `core.trustctime=false`. Do not force the settings into `cr_run`, which would change the render.
  - **Owed arm:** the p2 world under each single setting is refused with no record formed. Its ALLOW twin: the default config records and hits. Its mutant: deleting the refusal makes the run accept stale.
- **Round 9 checked, no finding** (recorded so round 10 does not repeat them):
  - `layer-drift.sh:1341` `diff --quiet` in `adj_spent_note`: same mechanism, but only the detail column is fed, and no region prints it.
  - `ls-files --with-tree` on a bare dist works.
  - Env names read only by an entry's sourced siblings are already the B4 LIMIT.
  - `k2_resolve_file` walk-up is already LIMIT (2).
  - `generated_at` is on the write path, not the `--series` invoke.
  - Reflog reads: 0 hits.
  - gettext/locale: unrun, and it cannot fire on this host. NOTE at most.
- **Round 9 verdict (key review, under the lead's ruling):** one DEFECT (D-r9b-1), no BLOCKER, so the flip is not held by the review, and D-r9b-1 is a precondition for the flip, built by a later batch.

verify: sh e=core/skills/ai-dlc-update/reconcile/emit-report.sh; a=core/skills/ai-dlc-update/reconcile/apply.sh; [ -f "$e" ] && [ -f "$a" ] || exit 9; ! grep -qF "EMIT_REPORT_VERIFY_CACHE" "$e" "$a"

## BL-706 — no reconcile step runs the derivation differential on every pull, so a consumer whose pulls never hit a derivation never gets an owed-derivations record

**NOTE.** Filed by ai-dlc-77 [ab5b1f] from the BL-668 build (batch 236), lead ai-dlc-c8 ruled it a separate cost question with no owner this batch. BL-668 made `reconcile/derivation-differential.sh --record-owed` create the record on every run, so an absent record now means "no reconcile has ever measured this tree". But `reconcile/apply.sh` (~:1346, ~:1495) emits the differential only as a `WORKLIST artifact-derivations` row, and only when a recorded `derived` command names a core path the range changed; the differential refuses on zero derivations, and nothing runs it unconditionally. So a consumer whose pulls never touch a derivation keeps printing `check-owed-derivations.sh`'s absent line. That line is correct (the tree was genuinely never measured), so this is a cost question, not a defect. A per-pull "no changed path, so nothing owed" record was considered and declined (c8): a derivation can read files its command line never names, so that record would be written from intent, not from a measurement.

Owed: decide whether every pull runs the differential (two validator passes per pull) so the record always exists, measuring that cost on a reference consumer before deciding. No owner this batch.

**Progress (batch 240).** The cost differential is reachable (two validator passes over 919 derivations on a `file://` clone). It is banked under the NO TIMING RUNS ruling and runs only when a named fix needs the figure.

verify: manual

## BL-806 — a lead can write an estimated, future-dated time into `pipeline-snapshot.md`, and a resuming session reads it as fact

**DEFECT.** Filed at the batch-242 close from the graph watch (ai-dlc-fa, poll 30, 03:42 EDT 2026-10-26). At 07:39:12Z graph's s320 lead ran a `sed` that wrote `| 18/19 delivered at 07:50Z (still out: cross-1 only …` into `_bmad-output/pipeline-snapshot.md`. That stamp is 11 minutes after the moment it was written. The row's previous value read `16/19 delivered at 07:35Z`, so the time was estimated, not taken from `date`. `core/skills/ai-dlc/SKILL.md:52` makes a resuming session read that file in full before any pipeline action, so a wrong time there becomes a resuming lead's premise. No outcome was affected this time.

Owed: a check, not an instruction, because the instruction to take times from `date` exists in this repo's own rules and was not followed. Either the snapshot writer stamps times itself, or a hook or validator refuses a snapshot time later than the write's own clock. Measure the false-positive set first: a deliberately future time (a stated deadline) must be spelled differently from a delivery stamp.

**Progress (batch 243; the entry stays PARTIAL, `verify: manual` unchanged, no LANDED line).** Part (a) shipped; part (b) is owed.

**(a) shipped.** Deny B in `core/hooks/ai-dlc-foreground-budget.sh` (`elif ... then "DENY B"` at `:248`, header `# DENY B, A SHELL WRITE OF THE SNAPSHOT` at `:81-122`) refuses a Bash call that names `pipeline-snapshot.md` (as a path ending there; `pipeline-snapshot-history.md` appends stay allowed) and carries a write shape: `sed`/`perl` with `-i`/`--in-place`, a `>`/`>>` redirect onto it, `tee [-a]`, `cp|mv|install|ln` with it as the last operand, `git checkout|restore` of it, or an interpreter write (`open(…,'w'|'a'|'x'|'+')`, `.write_text(`, `.write_bytes(`, `writeFileSync`) on the literal path or on a variable bound to it earlier in the command. Reads stay allowed (`cat`, `grep`, `sed -n`, `<`, `python3 open(p)`, `cp` from it, `git add/commit/show/diff`). It is an early branch decided before every scope gate and fail-open, so no timeout, `agent_id` or missing detector exempts it. The remedy is the Edit or Write tool, so `ai-dlc-derivation-capture.sh` judges the written stamps; that hook's own header (`core/hooks/ai-dlc-derivation-capture.sh:134`, "reaches no PostToolUse hook") says a Bash `sed -i` on the snapshot reaches no PostToolUse hook, which is how the motivating `07:50Z` row went unjudged.

Measurement 0a, driving the shipped hook over graph's transcripts: 4,617 Bash calls name the snapshot and 1,912 are denied (1,905 by Deny B and 7 by Deny A, which fires on the waiter shape in the same corpus; 1,873 distinct). Of the 1,905 Deny B records (1,866 distinct), an independent second reading tags 1,740 by write shape: interpreter open-w 1,630, `sed -i` 121, cp/mv 10, tee 7, `git restore` 3 and redirect 2. These are tag counts, and a record can carry more than one, so they sum to 1,773. The other 165 records (164 distinct) carry no tag from that reading. A quote-aware scan of each `sed -i` invocation's file operand resolves all 164 distinct records to the snapshot, so they are `sed -i` writes that the reading's regex did not tokenise. The false-positive set is empty by an independent second reading. The fail-closed alternative (deny any command naming the snapshot unless it starts with a whitelisted read verb) was measured on the same corpus and rejected: it denied 1,465 commands that are not writes. Over `core/` and `templates/` (`core/fixtures` excluded) there are 517 payloads and exactly 1 deny, the validator's own self-probe body at `core/scripts/validate-artifact-budget.sh:1951` (`} > "$LPROBE_D/state/pipeline-snapshot.md"`), which is script body and not a command an agent issues. No core script takes the snapshot path as an argument and writes it.

(a)'s receipt, QUOTED and not installed (the entry's receipt line stays manual): drive the shipped hook with `{"tool_name":"Bash","tool_input":{"command":"sed -i '' 's/a/b/' _bmad-output/pipeline-snapshot.md"}}` and require a deny naming Edit; require `sed -n 1p _bmad-output/pipeline-snapshot.md` and a `>>` onto `pipeline-snapshot-history.md` to be allowed; the `sed -i.bak` spelling must also deny. It has not been scored here; the fixture arms of the hook change carry the scored form.

**(b) owed: a bare `HH:MMZ` in a stamp position is not yet separable from a quoted time.** Two measurements, both with controls, and neither yields a grammar with an empty or enumerated false-positive set.
- Measurement 1, committed history of graph (file:// clone, read-only): 568 revisions of `_bmad-output/pipeline-snapshot.md`, now = the commit's `%ct`. 999 bare tokens, 292 fire (more than 600 s ahead) in 73 revisions. A 12 h previous-day rule removes 137 of them. The remainder is 184 `~` approximations, 35 range ends, 1 stray `T` and 72 other in 22 distinct texts, all false positives (times on another date, quoted past times); 0 true positives. The motivating `18/19 delivered` row was never committed: `git log -S` returns 0 for it against 1 for the `in_flight_sub_step` control. Controls: the HEAD path exists (`cat-file` 0, a missing path 128); `99:99Z` gets 0 hits; the shipping dated-stamp arm on the same population finds 71 revisions and 342 FUTURE findings.
- Measurement 2, hook input (graph transcripts): 5,236 jsonl files, 351,365 tool_uses, 5,695 touching the snapshot (3,552 Edit, 9 Write, 2,134 Bash). The motivating write is a Bash `sed` at 2026-10-26T07:39:12Z in `d22c7889…jsonl`, with `07:50Z` 648 s ahead; it is invisible to the write-time hook, and Deny B now refuses it. Edit payloads: 163 token fires without a rollover rule, 133 with. After narrowing (`~`, range ends, CLOCK CORRECTION/NOTE lines, 12 h rollover, backticked) about 55 fire, about 51 true positives and about 4 false positives, BY HAND CLASSIFICATION, not a derived count. An FP class that cannot be enumerated remains: a quoted earlier time under 12 h old (`08:57:12Z` quoted at 00:38). Controls: `99:99Z` 0; the motivating row matches. Eight CLOCK CORRECTION rewrites by graph leads show the true-positive class is real.
- Design when it ships: warn-only, exit-2 text on Edit/Write payloads at write time (like `check_malformed_stamps`, never the gate population), whose remedy never says to overwrite.
- What unblocks it: a grammar that separates a QUOTED time from a STAMPED one, for example anchoring on the stamp's field position (the leading stamp of a Recent Activity line, the status cell's own stamp slot) rather than any `HH:MMZ` token in the text. It ships only with a derived false-positive set that is empty or enumerated.

verify: manual

## Efficiency regression after the ranked set (filed 2026-10-26)

Filed from [`docs/analysis/pipeline-efficiency-s317-s320/`](analysis/pipeline-efficiency-s317-s320/), which
re-runs the s317–s318 extractor over graph s317–s320. The efficiency releases (0.782.0–0.786.0) reached graph
on 2026-10-14/15. **Measured per story, with operator wait excluded, they removed nothing.** Subagent dollars per
story read $88 for s317, $109 for s318 and $88 for s319. Machine hours per story read 4.8, 4.7 and 4.7. The price
per spawn fell about 40%, from $1.98 to $1.13, and spawns per story rose from 44.5 to 78.0. The first four
entries below are the measured sources of the added spawns, and BL-812 carries the outcome target. Every receipt
is `manual` at filing; the batch that builds an entry owes its behavioural `sh` receipt and the probe behind it.

**Amended 2026-10-26: no entry here closes on a tree receipt.** As filed, each of BL-808 through BL-811 could
close when its mechanism shipped. That is the shape under which all 19 entries of the ranked defects table in
`docs/analysis/pipeline-efficiency-s317-s318.md` closed (BL-397, BL-398, BL-504, BL-507 to BL-520, BL-568,
BL-569: each archived with `**LANDED (v`) and per-story cost did not move.

The goal is a pipeline in which every step earns its wall clock and its tokens. It is not a number. The rule that
decides a step is the step-value rule (`docs/analysis/step-value-s317-s319.md`, "A step with no measured value
goes" in `.claude/rules/operator-rulings.md`): a step, round or fan-out width is kept on a named failure case and
on catches no other step makes that survive to the shipped artifact, and a rare high-consequence catch is judged
on consequence, not frequency. So each entry here closes on a measured graph sprint, read by
`docs/analysis/pipeline-efficiency-s317-s320/scripts/`, that states what its own step's machine hours and tokens
per story did against s317 and s319. A cost that fell closes the entry. A cost that did not fall closes it only
with that rule's evidence for what the cost buys; without it, the cost is waste the entry still owes. The s317 and
s319 figures beside each entry are reference points, not pass bars: a fixed bar can be met by cutting a step that
catches real defects, which the rule forbids. An entry whose mechanism has shipped and whose sprint has not been
measured is PARTIAL, whatever its `verify:` line says. BL-817 makes this a mechanism.

## BL-808 — the gate-1 partition counts committed test-evidence captures as reviewable files, so an evidence-heavy diff fans out to ten reviewers

**DEFECT (efficiency).** `partition-review-diff.sh` excludes only the scan roots (`_bmad-output`, `docs/retro`,
`docs/reviews`, `docs/escalations` on graph), so every `test-results/*.txt` capture counts toward the 8-file
threshold (`REVIEW_SHARD_DEFAULT_MIN_FILES`). Since BL-510's capture header and committed-RED rules, a fix that
touches one code file and re-records fifteen captures crosses the threshold. It then dispatches 4 part reviewers
and 6 cross reviewers, because `partition-document.sh --cross-groups 4` prints six groups.

Measured on graph s319. Each pass's range is taken from its merged review's `<base>..<sha>` Summary line or the
prior pass's `reviewed-sha:`, and the program was re-run on it:
- Re-reviews: 21 of 44 passes shard today, and 2 would shard if captures were not counted. Story 3.1 p6's part
  map is two `test-results/` files in parts 1–2, a third part mixing code with mutation captures, and a fourth part of
  captures only.
- Pass 1: 10 stories sharded, and 4 would still shard without captures. Those 10 ranges held 81 captures, against
  20 in s318's 4 sharded ranges.
- Cost: a sharded code-review pass averaged 12.9 spawns, $19.70 and 103 agent-minutes. A serial pass averaged
  $0.90 and 5 agent-minutes.

Owed: the reviewable count excludes the captures the story CITES as evidence. Key the exclusion on what
`validate-handoff-evidence.sh` already resolves at the same pre-gate-1 call, not on a path prefix, which would
diverge per consumer. The captures stay in the range the reviewers read. Measure the partitioner before and after,
because the pole runs fixtures that invoke it.

Outcome, jointly with BL-809: implementation plus gate-validation[implementation] read 14.1 spawns and $24.3
per story in s317, and 31.5 spawns and $30.7 in s319. The measured sprint reports that step's figures beside
these, and any reviewer width it keeps names the catches that width alone made.

**Fix (this release).** `validate-handoff-evidence.sh --list-captures [-C <repo>] <story-file> <frozen>` prints
every capture the story cites under the handoff arms' own grammar, only when tracked at `<frozen>`, in toplevel
spelling; a bare capture basename resolves to the tracked files of that name inside the story's capture
directories. `partition-review-diff.sh --map ... --exclude-captures <file>` drops the intersection of that list
with the reviewable files from the threshold COUNT only, and a counted file count of at most one answers SERIAL.
The flag never touches the file set, because `merge-review-shards.sh` re-derives the map with a flagless re-run
and compares it byte for byte; the file-set mutant is its guard. `implementation.md` runs the pair at gate 1, at
the re-review and at gate 2. Delivered effect, measured by the contract adversary: 19 of 30 s319 sharded passes
flip to SERIAL, against 24 of 30 with every capture-extension file excluded and 13 of 30 with cited-only paths.
That is below the entry's original estimate. The before/after partitioner timing the entry asked for was not
run: NO TIMING RUNS (lead ruling, batch 243).
Under the amendment above this entry does not close on the shipped mechanism; it stays open until the measured
sprint reports the joint outcome with BL-809, read by the step-value ruling, with the s317 and s319 figures as
reference points. Receipt for the shipped mechanism (scored text, not the close
predicate): `bash core/fixtures/review-shard-merge/receipt-bl808.sh core/scripts/partition-review-diff.sh` — fix 0,
the flag parsed but not applied 1, the list length subtracted 1 and the captures dropped from the file set 1,
second spelling (the intersection with `comm`) 0.

Decision rule: the step-value ruling, "A step with no measured value goes" (`.claude/rules/operator-rulings.md`), cited per BL-817.

Basis (operator ruling, BL-817): dollars are token-equivalent (a local-model call priced at that sprint's hosted lead mix; s317 is the only sprint with local lead calls, 44% of its lead calls) with API dollars beside them, and every hour figure in this entry is gap-inclusive (operator and agent waits over 300 s included; the gap is measured separately by the extractor). Per story, implementation plus gate-validation[implementation], from `docs/analysis/pipeline-efficiency-s317-s320/scripts/` as committed at fc71a7b10 on main: s317 2.01 h gap-inclusive, token-equivalent $36.8 (API $31.4); s318 0.91 h gap-inclusive, token-equivalent $32.5 (API $32.5); s319 2.09 h gap-inclusive, token-equivalent $41.3 (API $41.3).

verify: manual

## BL-809 — a re-review pass is spent on evidence and bookkeeping findings that a validator could settle, so a story is reviewed up to nine times

**DEFECT (efficiency).** Graph s319 ran 44 gate-1 re-review passes over 23 reviewed stories. s317 ran 13 over 21
and s318 ran 16 over 14. Story 3.1 ran 9 passes: p5, p8 and p9 carried 0 findings, and p4, p6 and p7's findings
are capture labels, `$` lines, stale citations and story-record wording.
- Finding mix: about 2 in 3 of the 250 `#### ` findings in s319's `-p<M>` files are evidence or bookkeeping
  (167 matched an evidence or bookkeeping keyword set). That is a heading-keyword classification and a floor of
  unknown precision. The derived form is a finding under a part whose map row is entirely captures.
- Code-shaped findings: the remainder include real code findings (a PUT of `inf` returning 500, a live smoke that
  passes silently on null), so the round itself is not the defect.
- BL-510 is PARTIAL: it reaches about 7 of 12 evidence verdicts and 0 of 10 bookkeeping verdicts by its own
  measurement, and the rest still return as review findings.

Owed:
1. A NEEDS_REWORK whose every Critical and Important finding is evidence or bookkeeping re-checks through
   `validate-handoff-evidence.sh` and the one serial reviewer it names, not through a fresh fan-out.
2. A re-review whose delta, captures excluded (BL-808), touches no more than one code file dispatches one serial
   reviewer.
3. Extend the validator to the evidence classes s319's findings show it does not refuse: a capture labelling the
   wrong commit, a `$` line that cannot replay, and a stale per-AC citation.

Item 1 is the wall-clock lever and is not optional. A re-review pass is a serial wait (rework, freeze, review)
whatever its width, so a narrower pass removes dollars and a removed pass removes hours. BL-808 makes passes
narrower and removes none. Reference points: gate-1 re-review passes per reviewed story read 0.62 in s317 (13
over 21) and 1.91 in s319 (44 over 23); implementation plus gate-validation[implementation] machine hours per
story (`steps.csv` active plus agent wait, operator wait excluded) read 1.87 and 1.80. The measured sprint reports
both. A re-review pass is earned by a code finding the pass caught; a pass spent only on evidence or bookkeeping a
validator could settle is the waste this entry removes. The implementation spawn and dollar figure is reported
jointly with BL-808.

**Status (this release).** PARTIAL. Item 1 and item 3 shipped; item 2 is owed with its FP set below; `verify: manual` until the measured sprint.

Item 1, the record-only route. Each Critical/Important finding carries one `Class: CODE|TEST|EVIDENCE|BOOKKEEPING` line (owner `code-reviewer.md`; TEST is code-class; a finding admitting any code fix is CODE). `merge-review-shards.sh` refuses a value outside the set and accepts a missing one. `partition-review-diff.sh --route` routes a re-review to `validate-handoff-evidence.sh` plus one serial reviewer only when every prior Critical/Important finding is EVIDENCE or BOOKKEEPING and the delta from the prior `reviewed-sha:` to the frozen sha carries no code path. It sends the pass full on zero findings, a missing or unknown Class, any unrouted finding, an unresolvable or non-ancestor sha, and an empty or unreadable delta. The delta's code class (`partition-review-diff.sh`, THE CODE CLASS) drops a path under a scan root, a `.md`, a `.txt/.log/.out` outside any test directory, or a `.txt/.log/.out` that `--list-captures` names; any code-extension file is code wherever it sits and whether or not the story cites it. Measured on graph with the shipped predicate: 0/3/6 routed passes (s317/s318/s319). M7's 4 for s318 used a `test-results/` path-prefix partition. The shipped class counts `test-results/red_splat_copy.py`, which the s318 2-3 story cites, as code, so s318 2-3-p3 goes full (fail closed). Labels: blind re-label disagreement was s317 13/86 (5 cross E|B) and s318 5/75 (1 crosses). Without the delta guard, s317 routes 3 passes on M7's labels and 1 on the blind labels, and the s317 2-6 miss appears under one labeller only. The guard removes it under both, so the delta guard is the safety property and Class is the saving.

Guard cost, PRICE / VALUE. VALUE is a pass the guard sent full whose re-review raised at least one CODE or TEST finding; PRICE is every other such pass (clean, or evidence and bookkeeping findings only). The guard sent 11 passes full that the class oracle would have routed: PRICE 10, VALUE 1. VALUE is a full re-review pass that caught a CODE or TEST finding the record-only route would have missed; a pass whose only findings are EVIDENCE or BOOKKEEPING is PRICE, because the route would have settled those.
- s317, PRICE 2, VALUE 1. 1-2-p3 and 1-2-p4 are PRICE. 2-6-p4 is VALUE: it caught 2 code findings that the s317 2-6 rework had introduced by deleting an assertion.
- s318, PRICE 3, VALUE 0. 1-1-p3 is PRICE: its one Important finding (the mutation captures are gitignored and not in the commit) is EVIDENCE. 2-3-p2 is PRICE: its two Important findings (`ac4-hunks.txt` and `ac1-ac3-green.txt` record no command or head sha; the close signal claims a RED for a binding that has no capture) are both EVIDENCE. 2-3-p3 is PRICE: APPROVED with no Critical or Important finding (its one Suggestion is the red-splat driver's exit code).
- s319, PRICE 5, VALUE 0. 2-3b-p4, 3-1-p8, 3-2-p5 and 4-3-p5 are PRICE: each raised no Critical or Important finding. 4-4-p3 is PRICE: its one Important finding is EVIDENCE (`ac1-unavailable` is labelled "AC1 d and AC2 b" but its recapture runs only `-t ST319-4.4-01`), and the verdict stayed APPROVED.
- Derived by reading each pass's review file in graph's clone (read-only), with the labels as the s318 blind re-label and the s319 reading of M4b's findings; the class of each finding is the label, and a pass with no Critical/Important finding has none to label.

Item 3, Rule A. Gate 1 re-runs after a QA rework iff the range adds a test file, or changes a code or test file on a line that is not blank, a comment or a docstring; captures and records never trigger it (`partition-review-diff.sh --gate1-rerun`). Saving in s319: 2 of 44 passes (2-3a-p2 and 3-1-p9, both after QA-only reworks). 2-3a-p3 still re-runs, because 2-3a-b added 26 executable lines. The justified post-APPROVED re-runs 1-1-p3 (18 lines) and 4-4-p4 (1 added spec) still re-run. 3-1-p6 was waste.

Item 2, narrowing a mixed re-review to the files its CODE findings name, is not shipped. Its FP set over s317–s319 is 1 of 19 mixed-prior passes: s319 3-1-p3 raised a CODE finding (a dead nested function) in `rebalancer/tests/test_s319_3_1_merkl_rewards.py`, a file outside the prior CODE findings' set. CODE was read as C and H on s317/s318 and N on s319; control: an empty narrowing set flags 7 of 7.

Receipts (evidence for the shipped mechanism; `verify:` stays manual):
- `bash core/fixtures/review-reroute/receipt-bl809-route.sh core/scripts/partition-review-diff.sh` (fix 0; guard removed 1; missing Class routing 1; second spelling 0)
- `bash core/fixtures/review-reroute/receipt-bl809-rulea.sh core/scripts/partition-review-diff.sh` (fix 0; docstring filter removed 1; added test file ignored 1; second spelling 0)

Earlier releases, under the Owed numbering above (kept as written):
- Item 2, closed by BL-808: `partition-review-diff.sh --exclude-captures` answers SERIAL for a counted
  (non-capture) delta of at most one file, whatever the threshold. The re-review step text in
  `implementation.md` cites that SERIAL answer as one reviewer, `shard: 1/1 <story-index>`.
- Item 3, shipped in `validate-handoff-evidence.sh` (handoff mode, the in-range captures arm (a) reads):
  - Arm (m) K-UNQUOTED is a refusal, `k-unquoted`: a `$ ` line that passes `-k` an unquoted multi-word
    expression. Measured read-only over graph s317-s319 at 100 gate-1 passes (519 in-range captures,
    402 `$ ` lines), it had 4 hits, all true positives (s319 3-1 p4/p6, raised at
    `3-1-code-review-p6.md:741`). The FP set is empty. The shipped arm reads only cited captures, as
    arm (a) does, so it refuses 2 of the 4. The two `ac9` captures at p6 are in range but uncited.
  - Arm (n) PLACEHOLDER is a WARN (lead ruling) for a `<name>` on a `$ ` line. `<redacted>` and
    `<base-worktree>` are exempt; the latter is the one FP, s319 `lint-base.txt:1`, which its reviewer
    accepted. FP 0 after the exemptions.
- Item 3, still owed:
  - The per-AC untracked-citation arm has 1 TP (s317 2-3) against 22 FP in two shape classes: rows
    deferred to deploy-validate, and a `git rm` disposition line. The exclusion wording is unmeasured.
  - The wrong-commit capture is unchanged; it stays the head WARN (lead ruling).

Decision rule: the step-value ruling, "A step with no measured value goes" (`.claude/rules/operator-rulings.md`), cited per BL-817.

Basis (operator ruling, BL-817): dollars are token-equivalent (a local-model call priced at that sprint's hosted lead mix; s317 is the only sprint with local lead calls, 44% of its lead calls) with API dollars beside them, and every hour figure in this entry is gap-inclusive (operator and agent waits over 300 s included; the gap is measured separately by the extractor). Per story, implementation plus gate-validation[implementation], from `docs/analysis/pipeline-efficiency-s317-s320/scripts/` as committed at fc71a7b10 on main: s317 2.01 h gap-inclusive, token-equivalent $36.8 (API $31.4); s318 0.91 h gap-inclusive, token-equivalent $32.5 (API $32.5); s319 2.09 h gap-inclusive, token-equivalent $41.3 (API $41.3).

verify: manual

## BL-810 — carry-over evaluation runs party, elicitation, cross and adversarial rounds whose yield has never been measured

**DEFECT (efficiency).** Carry-over-evaluation spawns in graph:

| | s317 | s318 | s319 | s320 |
|---|---|---|---|---|
| Spawns | 49 | 79 | 88 | 114 |
| Dollars | $96 | $110 | $87 | $127 |

s320's step ran 5.8 machine hours, against 2.9 in s318 and 2.8 in s319. Cross shards appeared in s319 (24) and
held in s320 (24); elicitation and adversarial shards grew alongside them.

`docs/analysis/step-value-s317-s319.md` measured requirements, architecture, stories and sprint-review rounds and
never carry-over's. No `Failure caught:` line exists for these rounds. Under the step-value ruling
(`.claude/rules/operator-rulings.md`, "A step with no measured value goes"), an element with no measured value is
removed or merged by the batch.

Owed: measure s319 and s320 carry-over rounds by the step-value method: REFOUND, MISSED-BY-PRIOR,
REPAIR-INTRODUCED and UNIQUE-SURVIVED, with a high-consequence guard. Remove each round with no unique surviving
catch, and give each kept round its `Failure caught:` line.

**Amended: the measurement goes down to the fan-out width.** A round can earn its place while most of its width
does not, and the round-level measurement cannot see that. For each round, separate the catches the per-part
shards made from those only its cross groups made, with the consequence of each and the dollars and agent-minutes
each width cost. A cross group whose unique surviving catches are none, or are low-consequence catches another
round also makes, is narrowed or merged. One that carries a high-consequence catch no other round makes is kept on
consequence, and states that catch and its cost beside its `Failure caught:` line. Reference points:
carry-over-evaluation read 49 spawns and $96 in s317 (the table above, `origin/main`'s extractor); s320 read 114
and $127 on that extractor, and 132 and $159 on BL-813's corrected one.

**Status (this release).** PARTIAL. The `Failure caught:` lines shipped: each round's line is in
`carry-over-evaluation.md` §3a, pinned by `process-rule-pins` rows `coe-26c-caught` and `coe-26c-loop`. The
round-level measurement in `docs/analysis/step-value-carry-over-s319-s320.md` is recorded as evidence for the
per-round, per-width measurement: party, elicitation and adversarial p1 carry unique surviving catches, and p2's
9 MAJORs sit in text only it could read and all 9 shipped fixed. That evidence does not discharge this entry; the
KEEP or narrow decision per round and per width is c6's, under the step-value ruling.
The amended scope (the measurement per round down to the fan-out width) is not in this release; it rides
cluster c6, a separate release in batch 243. It is not dropped. Receipt for the shipped mechanism (scored text,
not the close predicate): `s=$(LC_ALL=C awk '/^### 3a\. /{g=1;next} g&&/^### /{exit} g' core/skills/ai-dlc/steps/carry-over-evaluation.md); [ -n "$s" ] && grep -qF 'Failure caught:' <<<"$s" && grep -qE '^- Adversarial pass(es)? 2[^:]*: Failure caught:' <<<"$s"`
— it holds the §3a `Failure caught:` lines in place, including adversarial pass 2's. Scored by this rebase: fix 0,
the pre-release `carry-over-evaluation.md` (bd0be5e51) 1. Scores recorded by the hands that built the receipt, under
`set -uo pipefail`: the §3a paragraph deleted 1; the adversarial-loop line missing with the other three
`Failure caught:` lines present 1; the second spelling ("Adversarial pass 2 onward (the convergence loop): Failure
caught:") 0.

**Status (c6b).** PARTIAL, still open. The per-round, per-width measurement is in `docs/analysis/step-value-carry-over-s319-s320.md`, "Per-width", by `scripts/width.py` over s319 and s320 (320 CRITICAL/MAJOR findings, joined by token).
- Result: every high-consequence catch for party, elicitation and p1 was made by a per-part shard. Cross groups alone made only p2's half-fixed `Dependencies` field and its wrong IL claim.
- Decision: per-part shards stay in every round; party cross narrows to one per seat; elicitation, p1, p2 and p3 cross merge to one agent briefed with every section; p2's two cross catches are kept on consequence (one cross agent reading every section sees them), their cost beside the `Failure caught:` lines in §3a.
- Coverage guard: Check 22 arm S4 (`validate-spawn-ledger.sh`) refuses a one-cross dispatch (`cross/<K> g1/1 <ordinals>`) whose brief omits any section; it binds the BRIEF, not reads; FP 0 over graph's 7242-row spawn ledger (no real g1/1 row yet, so its accept path is covered by seeded arms only). Arm S4X binds the emitter templates to that spelling.
- Cross spend removed per sprint (sum minus costliest): s319 $13.54 party, $7.49 elicitation, $6.03 p1; s320 $16.33 party, $4.50 elicitation, $12.85 p1, $10.06 p2, $8.27 p3. Party keeps one per seat, so its saving is below its figure.
- Still owed: a measured sprint (spawns, dollars and agent-hours per width) beside s319 and s320. The cross-only counts are ceilings (token join; 27 findings carry none). s320's p2 and p3 rest on one sprint. Not closed.

Receipt (prose, `verify:` stays manual): `s=$(LC_ALL=C awk '/^### 3a\. /{g=1;next} g&&/^### /{exit} g' core/skills/ai-dlc/steps/carry-over-evaluation.md | tr -s ' \n\t' '   '); [ -n "$s" ] && grep -qiE 'party dispatches one cross agent per seat' <<<"$s" && grep -qiE 'elicitation and each adversarial pass dispatch one cross agent' <<<"$s" && ! grep -qF 'one agent per (seat, part) and per cross group' <<<"$s"` (fix 0; pre-change 1; old line restored 1; width paragraph deleted 1; party clause reworded away 1; rewrapped 0).

Basis (operator ruling, BL-817): dollars are token-equivalent (a local-model call priced at that sprint's hosted lead mix; s317 is the only sprint with local lead calls, 44% of its lead calls) with API dollars beside them, and every hour figure in this entry is gap-inclusive (operator and agent waits over 300 s included; the gap is measured separately by the extractor). Per story, the four planning steps (carry-over-evaluation is not separable in this table), from `docs/analysis/pipeline-efficiency-s317-s320/scripts/` as committed at fc71a7b10 on main: s317 1.91 h gap-inclusive, token-equivalent $54.2 (API $54.1); s318 2.95 h gap-inclusive, token-equivalent $80.0 (API $80.0); s319 2.12 h gap-inclusive, token-equivalent $56.4 (API $56.4); s320 5.54 h gap-inclusive, token-equivalent $78.9 (API $78.9).

verify: manual

## BL-811 — sharded stories elicitation costs thirteen times the single voice it replaced

**DEFECT (efficiency).** Stories elicitation spawns read 23 for $72 in s317, 5 for $12 in s318, 92 for $162 in
s319, and 44 for $65 in s320. 0.782.0 (BL-509) made stories elicitation sharded. The keep-sharded verdict in
`docs/analysis/step-value-s317-s319.md` rests on s317's unique yield, so this entry does not reopen that verdict.
It owes the cost per shard instead: the shard count, the seat's model binding, and whether the shards share
one context write. Measure s319 and s320 yield per shard, so that the count is set by the yield and not by the
part count.

**Amended: widened to every split dispatch's cross groups.** Stories elicitation is one instance. Every split
dispatch pays one cross agent per cross group from `partition-document.sh --cross-groups`, which is 6 cross
agents beside 4 parts. Cross-shard spawns, counted on one population: the rows of the s317–s320 spawn extraction
(4098 rows) whose description matches `cross g\d|cross-\d|cross shard|cross-part|cross-story|cross/|cross remediator`
and not `cross-section|cross seat`. As a control, 671 s319–s320 descriptions contain "cross" at all, and 2 of those are
excluded. s317: 134 cross spawns, 6.4 per story ($449.5, $21.4 per story, 24% of subagent dollars). s319: 360 cross
spawns, 18.0 per story ($512.1, $25.6 per story, 29%), of which implementation and its gate hold 171 (159 + 12). The
count is a floor: a spawn whose description names no cross token is not counted. 24.9 per story, 273, $36.8 and 42%
were filed without a reproducible derivation and are withdrawn. API price = token-equivalent here: the subagent seats
ran no local model in s317 or s319 (s317 sonnet 566 / opus 316 / haiku 52 / fable 1; s319 sonnet 668 / opus 557 /
haiku 336). In stories elicitation the cross groups made 3 unique surviving catches at $25.15 each against the
per-story shards' 32 at $3.06, and every cross group read every story. Owed: one cross agent per split dispatch (code
review, QA validation, elicitation, adversarial passes and repairs, on every axis; party: one per seat), unless that
dispatch's measured cross catches justify more under the step-value rule, a high-consequence catch counting on
consequence. The measured sprint reports cross spawns per story on this same script and population beside s317's 6.4
and s319's 18.0.

**Fix (this release).** Measured in `docs/analysis/step-value-stories-elicitation-s319-s320.md`
over s319 r1, s319 r2 and s320, which is provisional because its stories gate has not passed.
Per-story shards: 52 shards, 32 unique survivors (26 on s319), $3.06 per survivor, and both unique
CRITICALs. Cross-group shards: 18 shards, 3 unique survivors (2 on s319), $25.15 per survivor, 52%
re-raised. Story size does not predict per-story yield (Spearman −0.025, n = 52). The validation-cycle
item 2 in `_gate-procedures.md` now dispatches stories elicitation as one `adversary` per ordinal plus
ONE cross-story `adversary` briefed with every ordinal, writing `cross.md`. Its delta clause owes one
`cross.md`. Rule 28, `stories-test-strategy.md` §4 and Check 24 arm L's text follow. The party round,
the convergence passes and the sections and subject axes keep their cross groups. "At most 2 MAJORs
at risk, no CRITICAL" is a counterfactual UPPER BOUND on s319: it assumes the single voice loses all of
the cross catches (s319 r1 cross-1#F-2 and cross-4#F-1, plus s320 cross-4#F-3, provisional). Every
cross-group shard already read every story, so the one all-ordinal voice reads each of those pairs.
Counterfactual saving: $58.98 over three rounds ($39.85 on s319). It is computed as Σ cross minus the
costliest cross shard per round.
Status (c6b). The engine now accepts a lone `cross.md` at any K, and the prose collapses cross to one agent per dispatch;
this supersedes BL-464's "cross.md alone is refused". Receipt for the shipped mechanism (scored text, not the close
predicate): `bash core/fixtures/review-shard-merge/receipt-bl811.sh core/scripts/merge-review-shards.sh` (scores 0/1/1/0 under
`set -uo pipefail`). The earlier inline receipt block is removed: it keyed on the
sentence `one cross-story agent per (seat, cross group)`, which this release deleted, so it scores 1 now. The entry
stays PARTIAL: the measured sprint is owed.

Decision rule: the step-value ruling, "A step with no measured value goes" (`.claude/rules/operator-rulings.md`), cited per BL-817.

Basis (operator ruling, BL-817): dollars are token-equivalent (a local-model call priced at that sprint's hosted lead mix; s317 is the only sprint with local lead calls, 44% of its lead calls) with API dollars beside them, and every hour figure in this entry is gap-inclusive (operator and agent waits over 300 s included; the gap is measured separately by the extractor). Per story, stories-test-strategy, from `docs/analysis/pipeline-efficiency-s317-s320/scripts/` as committed at fc71a7b10 on main: s317 0.69 h gap-inclusive, token-equivalent $29.4 (API $29.4); s318 1.91 h gap-inclusive, token-equivalent $31.1 (API $31.1); s319 0.80 h gap-inclusive, token-equivalent $26.0 (API $26.0); s320 0.93 h gap-inclusive, token-equivalent $39.1 (API $39.1).

verify: manual

## BL-812 — the efficiency program shipped fixes with no per-story outcome target, and the outcome went unmeasured until two sprints later

**DEFECT (efficiency).** The ranked set summed to about $500 of removable cost against roughly $1,700–2,300 per
sprint. Every closed entry closed on a tree receipt, and the "Measuring the change" paragraph under the ranked-set heading
was never run. Per story, subagent dollars were flat ($88, $109, $88) across s317–s319, and machine hours were flat
(4.8, 4.7, 4.7). In the same window, BL-808 through BL-811 added spawns, and BL-510's capture rules fed BL-507's
fan-out instead of reducing it.

Owed:
1. **The outcome is measured on consumer transcripts by `docs/analysis/pipeline-efficiency-s317-s320/scripts/`
   over the first graph sprint that runs the fixes:** machine hours (lead active plus agent wait, operator wait
   excluded), tokens, subagent dollars and spawns, per story and per step, beside s317 ($88, 4.8 h, 44.5 spawns)
   and s319 ($88, 4.7 h, 78.0). Each step whose cost did not fall carries the step-value evidence for what that
   cost buys. The goal is efficiency, not a number: a fixed bar can be met by cutting a step that catches real
   defects, and the step-value rule decides every cut.
2. **The release that ships the last of BL-808 through BL-811 states that measurement as owed, and this entry
   closes only on the measured sprint,** never on a tree receipt.
3. **The release also states its projected per-story figures for each step it changed,** so that the measured
   sprint is read against a prediction. A step that moved less than projected is explained from the sprint, and
   an entry whose step did not move and carries no value evidence reopens.

**Status (b244 c3).** PARTIAL, `verify: manual`. Items 1 and 2 are owed: they need the measured graph sprint. For
item 3, projections are stated below for the steps 0.948.0 and 0.952.0 changed. The release that ships BL-809 item 2
(still owed) owes its own projection for the step it changes, so item 3 stays OPEN. Every figure below is a
PROJECTION, a counterfactual on a past sprint, and never a target or a pass bar: the step-value rule decides the
measured sprint, and a projected figure never does. The subject set was derived from `git show --stat ce275f7e9
abd42574d` and the step, rule-body and role diffs. 0.949.0's step changes (BL-804, BL-807, BL-814, BL-816) are
excluded, because they are not BL-808 through BL-811 and BL-804 is a reopened efficiency entry that owes its own
outcome. Three changes carry no cost of their own and get no row: `gate-validation.md`'s newest-first Recent Activity
wording, its Check 24 arm L text, and the `carry-over-evaluation.md` `Failure caught:` lines. Every s319 per-story
division uses 20 stories and every s320 one uses 13 (`roll.py` STORIES; `docs/analysis/pipeline-efficiency-s317-s320/README.md:81`).
s320's planning figures are provisional, because its stories gate has not passed. API dollars equal token-equivalent
dollars for every s319 and s320 figure, because only s317 ran a local lead (README:65-67). Two instruments are
mixed here. The savings come from each entry's own extraction: BL-808's pass means, its 31.5 spawns and its $30.7
are from the bd0be5e51-era extractor, BL-810's figures are from the BL-813-corrected extractor (0.948.0), and
BL-811's are from its hand's extraction in `docs/analysis/step-value-stories-elicitation-s319-s320.md`. The Basis
dollars and hours are from the scripts as committed at fc71a7b10 on main. So a projected figure, which is baseline minus saving, crosses
the two instruments. The savings on implementation passes overlap: BL-808's flips, BL-809's route, Rule A and
BL-811's cross collapse all act on the same gate passes, and the $19.70 sharded mean includes the pass's 6 cross
reviewers. The combined implementation figure is therefore a MEAN-BASED ESTIMATE, the sum of the standalone
mean-based estimates. BL-808's row, BL-809's high end and Rule A's high end are each N passes times the sharded mean
($19.70, 12.9 spawns, 103 agent-minutes). Such an estimate bounds the saving only if the passes that flip cost at or
below the sharded mean, and the tree does not record per-pass cost for the flipped set. An overlap can only lower a
marginal saving, so the sum does not double count. The one genuine ceiling is BL-811's 171 spawns, a count ceiling
and not a mean. BL-808's "19 of 30" sharded s319 passes does not match the 10 + 21 = 31 its own body counts, and the
tree cannot resolve which is right.

| Step | Mechanism (release) | Baseline per story | Projected saving per story, arithmetic | Projected per story |
|---|---|---|---|---|
| implementation + gate-validation[implementation] | BL-808 cited captures leave the shard count (0.948.0) | s319 token-eq $41.3 (API $41.3), 2.09 h gap-inclusive (Basis); 31.5 spawns, $30.7 (BL-808 outcome paragraph, older extractor) | $: 19 × ($19.70 − $0.90) = $357.20 / 20 (s319) = $17.86 (API same). Agent-minutes: 19 × (103 − 5) = 1862 / 20 = 93.1. Spawns: 19 × (12.9 − 1) = 226.1 / 20 = 11.31, where the 1 is the step text's one-reviewer SERIAL dispatch and not a recorded mean. Lead calls, tokens: not derivable from recorded data. Hours: no projection (F5) | $41.3 − 17.86 = $23.4 token-eq (API same); 31.5 − 11.31 = 20.2 spawns; agent-minutes, lead calls, tokens: not derivable |
| implementation + gate-validation[implementation] | BL-809 item 1, record-only re-review route (0.952.0) | as above | $: 6 routed s319 passes, cost per pass not recorded. Range $0 to 6 × ($19.70 − $0.90) = $112.80 / 20 = $5.64 (API same). The low end applies because a route fires only on a delta with no code path, which `--exclude-captures` already answers SERIAL, so the marginal saving over BL-808 is near zero. Spawns: 0 to 6 × 11.9 = 71.4 / 20 = 3.57. Agent-minutes: 0 to 6 × 98 = 588 / 20 = 29.4. Lead calls, tokens, hours: not derivable from recorded data | inside the combined mean-based estimate below |
| implementation + gate-validation[implementation] | Rule A, gate 1 skipped after a QA-only rework (0.952.0; the entry body's "Item 3") | as above | $: 2 of 44 s319 passes removed (2-3a-p2, 3-1-p9), cost per pass not recorded. Range 2 × $0.90 = $1.80 to 2 × $19.70 = $39.40, / 20 = $0.09 to $1.97 (API same). Spawns: 2 × 1 = 2 to 2 × 12.9 = 25.8, / 20 = 0.10 to 1.29. Agent-minutes: 2 × 5 = 10 to 2 × 103 = 206, / 20 = 0.5 to 10.3. Hours: a removed pass removes a serial wait, but no hour figure is recorded, so this is not derivable. Lead calls, tokens: not derivable | inside the combined mean-based estimate below |
| implementation + gate-validation[implementation] | BL-809 arms (m) `k-unquoted` and (n) `placeholder` (0.948.0, which that CHANGELOG calls item 3) | as above | no projection: not derivable from recorded data in any unit. 2 refusals in s319 are a count of refusals, not a cost | not derivable |
| implementation + gate-validation[implementation] | BL-811 one cross reviewer or cross QA per dispatch (0.952.0) | s319: 171 cross spawns in the step (159 + 12, BL-811) | Spawns: ceiling 171 / 20 (s319) = 8.55, a genuine count ceiling because it is every recorded cross spawn and not a mean. One cross agent survives per dispatch that is still sharded, and that dispatch count is not recorded. $: not derivable, because cross dollars are not separable from the all-step $512.1. Agent-minutes, lead calls, tokens: not derivable | inside the combined mean-based estimate below |
| implementation + gate-validation[implementation], combined | the five rows above | s319 token-eq $41.3 (API $41.3); 31.5 spawns | MEAN-BASED ESTIMATE, the sum of the standalone mean-based estimates (the sharded mean may understate the passes that flip, so it is not a bound). $: 17.86 + 5.64 + 1.97 = $25.47 (API same), with BL-811's dollar share not derivable. Spawns: 11.31 + 3.57 + 1.29 + 8.55 = 24.72. Agent-minutes: 93.1 + 29.4 + 10.3 = 132.8, BL-811 not derivable | mean-based estimate of at least $41.3 − 25.47 = $15.8 token-eq (API same), before BL-811's dollars; at least 31.5 − 24.72 = 6.8 spawns, where BL-811's 8.55 is a count ceiling |
| carry-over-evaluation (inside the four planning steps) | BL-810, party cross one per seat; elicitation and adversarial passes one cross agent (0.952.0) | carry-over alone: s319 88 spawns / $86.66, so 88 / 20 = 4.40 spawns and $86.66 / 20 = $4.33; s320 132 / $158.55, so 132 / 13 = 10.15 and $158.55 / 13 = $12.20 (BL-813-corrected extractor). Four planning steps (Basis): s319 token-eq $56.4 (API $56.4), s320 $78.9 (API $78.9) | $, an upper bound because party keeps four cross agents: s319 13.54 + 7.49 + 6.03 = $27.06 / 20 = $1.35; s320 16.33 + 4.50 + 12.85 + 10.06 + 8.27 = $52.01 / 13 = $4.00 (API same). Spawns (cross shard counts in the per-width table): s319 (24 − 4) + (6 − 1) + (6 − 1) = 30 / 20 = 1.50; s320 (24 − 4) + (3 − 1) + 3 × (6 − 1) = 37 / 13 = 2.85. Agent-minutes: ceiling only, all cross agent-hours, s319 (1.2 + 0.7 + 0.5) h = 144 min / 20 = 7.2, s320 (2.8 + 0.7 + 1.5 + 0.7 + 0.5) h = 372 min / 13 = 28.6. Lead calls, tokens: not derivable from recorded data | carry-over: s319 $4.33 − 1.35 = $2.98 and 4.40 − 1.50 = 2.90 spawns; s320 $12.20 − 4.00 = $8.20 and 10.15 − 2.85 = 7.30 spawns. Four planning steps: s319 $56.4 − 1.35 = $55.05, s320 $78.9 − 4.00 = $74.9 (API same) |
| stories-test-strategy | BL-811 one cross-story adversary per elicitation dispatch (0.948.0) | Basis: s319 token-eq $26.0 (API $26.0), 0.80 h gap-inclusive; s320 $39.1 (API $39.1). Elicitation alone: s319 92 spawns / $162 | $: s319 r1 $32.19 − $7.34 = $24.85, plus r2 $18.94 − $3.94 = $15.00, gives $39.85 / 20 = $1.99; s320 $24.32 − $5.19 = $19.13 / 13 = $1.47, provisional (API same). Spawns: s319 2 rounds × (6 − 1) = 10 / 20 = 0.50; s320 (6 − 1) = 5 / 13 = 0.38. Tokens: ceiling only, all s319 cross tokens, cache write 1,112,193 + 952,631 = 2,064,824 / 20 = 103,241 and cache read 31,189,138 + 18,707,988 = 49,897,126 / 20 = 2,494,856; per-shard tokens are not recorded. Agent-minutes, lead calls: not derivable from recorded data | s319 $26.0 − 1.99 = $24.0, s320 $39.1 − 1.47 = $37.6 (API same). Elicitation alone, s319: 92 / 20 = 4.60 spawns and $162 / 20 = $8.10, so 4.60 − 0.50 = 4.10 spawns and $8.10 − 1.99 = $6.11. s320 spawns: not derivable, because the Basis records no per-story spawn figure for the step |
| stories-test-strategy, party round and convergence passes and repairs | one cross agent per dispatch, party one per seat (0.952.0) | as above | no projection: not derivable from recorded data. The 189 non-implementation cross spawns of s319 (360 − 171) are not separable by step | not derivable |
| sprint-review | party cross one per seat (`sprint-review.md`, 0.952.0) | not recorded per story | no projection: not derivable from recorded data | not derivable |
| Rule 8 convergence passes, every step | one cross-file shard per pass (`rule-20.md`, 0.952.0) | not recorded per story | no projection: not derivable from recorded data | not derivable |
| requirements and architecture (four planning steps) | requirements-subject and sections-axis elicitation and adversarial passes, one cross-part adversary (`_gate-procedures.md`, 0.952.0) | not recorded per story | no projection: not derivable from recorded data | not derivable |
| lead calls across steps | BL-819 L3, `snapshot-update.sh` (0.952.0) | s319 lead-seat calls 6,151 + 214 = 6,365 / 20 = 318.3; s320 1,875 / 13 = 144.2 (README:66, `roll.py` hosted lead calls; the instrument differs from BL-819's whole-sprint count, which for s317 reads 8,133 against README's 4,588 + 3,539 = 8,127) | Lead calls: s319 (445 − 298) = 147 / 20 = 7.35; s320 (219 − 123) = 96 / 13 = 7.38. $, spawns, agent-minutes, tokens: not derivable, and no dollar figure is claimed (BL-819) | s319 318.3 − 7.35 = 310.9; s320 144.2 − 7.38 = 136.85 lead calls |
| lead calls across steps | BL-819 L1, `wait-for-deliverable.sh --complete --status` progress check (0.952.0) | not recorded per story | no projection: not derivable from recorded data. BL-819 records L1 as already mechanised, with a residual from a 30-hit sample and no saving figure | not derivable |

Decision rule: the step-value ruling, "A step with no measured value goes" (`.claude/rules/operator-rulings.md`), cited per BL-817.

Basis (operator ruling, BL-817): dollars are token-equivalent (a local-model call priced at that sprint's hosted lead mix; s317 is the only sprint with local lead calls, 44% of its lead calls) with API dollars beside them, and every hour figure in this entry is gap-inclusive (operator and agent waits over 300 s included; the gap is measured separately by the extractor). Per story, the whole pipeline bucket, from `docs/analysis/pipeline-efficiency-s317-s320/scripts/` as committed at fc71a7b10 on main: s317 5.37 h gap-inclusive, token-equivalent $112.2 (API $103.4); s318 5.75 h gap-inclusive, token-equivalent $132.4 (API $132.3); s319 5.50 h gap-inclusive, token-equivalent $111.7 (API $111.7); s320 5.79 h gap-inclusive, token-equivalent $80.6 (API $80.6).

verify: manual

## BL-817 — an efficiency entry closes on a tree receipt, so the ranked set closed and per-story cost never moved

**DEFECT (efficiency).** The 19 entries of the ranked defects table in
`docs/analysis/pipeline-efficiency-s317-s318.md` (BL-397, BL-398, BL-504, BL-507 to BL-520, BL-568, BL-569) are
all archived with `**LANDED (v`, and none of them carries the `DEFECT (efficiency)` tag. A further 13 archived
entries do carry it (BL-541, BL-543, BL-550, BL-552, BL-558, BL-585, BL-609, BL-615, BL-672, BL-679, BL-694,
BL-716, BL-801). Each one closed when a receipt over the tree passed. None closed on a consumer sprint showing its own step had got cheaper or faster, and measured per story
over graph s317–s319 the set removed nothing: $88, $109, $88 and 4.8, 4.7, 4.7 h. BL-808 through BL-812 were
filed the same way and are amended above. A receipt proves the mechanism shipped. It does not prove the outcome
moved, and for an efficiency entry the outcome is the claim.

Owed:
1. **A close predicate keyed on the outcome.** Because the ranked set was never tagged, the predicate cannot key
   on the tag alone: an entry is an efficiency entry if it carries the tag OR cites an efficiency analysis under
   `docs/analysis/` as its source. `scripts/backlog-rotate.sh` will not archive one carrying `**LANDED (v` unless it
   also carries an `Outcome measured:` line naming the consumer sprint, the script that measured it, and the before
   and after per-story machine hours and tokens of its own step, lead and subagent separately (BL-819). Where
   that figure did not fall, the line must
   also cite the step-value evidence that the cost buys a catch no other step makes, as a `path:line` that
   resolves to a step-value analysis table row or a `Failure caught:` line; a sentence alone does not satisfy it. `validate-backlog-receipts.sh`
   fails the push on such an entry with no outcome line, with a line naming no sprint, or with a figure that did
   not fall and no value citation. The arm requires a figure's PRESENCE beside each seat label and never judges its VALUE; that reading rests on the batch-243 amendment below, which is a lead filing and not an operator ruling. Before the arm ships, its
   self-probe fires on a seeded `LANDED` with no outcome line and on one whose figure did not fall with no
   citation, and stays quiet on one whose figure fell and on one whose figure did not fall with a citation.
2. **The filing shape.** An efficiency entry states, at filing, its baseline sprint, the step it owns, and the
   movement it expects in that step's machine hours and tokens, and it CITES the step-value ruling
   ("A step with no measured value goes", `.claude/rules/operator-rulings.md`) as its decision rule rather
   than restating it or substituting a number for it. BL-808 through BL-812 were filed from an analysis that
   carried that rule, and their first amendment replaced it with fixed per-story bars: the goal was defined and
   the filing did not carry it. The arm above refuses an entry that does not cite the ruling.
3. **Re-audit the 32 archived closes named above.** For each, measure its own step's per-story machine hours,
   tokens, dollars and spawns across s317–s320 with `docs/analysis/pipeline-efficiency-s317-s320/scripts/`. An
   entry whose step did not move and carries no value evidence is reopened into this ledger with its figure. An
   entry whose step moved, or whose cost is shown to buy unique catches, keeps its close and gains its
   `Outcome measured:` line in the archive.

Outcome owed: the arm behaves as its self-probe states, and every one of the 32 archived closes carries an
`Outcome measured:` line or is reopened.

**Amendment (batch-243 close).** Item 1's arm shipped in 0.952.0 narrower than item 1. `eff_shape_ok` at `scripts/validate-backlog-receipts.sh:864` requires only `token-equivalent`, `API` and `gap-inclusive`. It does not require a lead figure and a subagent figure, so an outcome line that reports neither still satisfies it. Measured line by line by ai-dlc-b4: 0 of the 19 re-audit lines in the reopened set, and 0 of the 21 archived `Outcome measured:` lines, carry a lead hour or lead dollar figure. Those that mention the lead give a local-model share, a count of the lead's Agent calls, or prose saying no step applies. Control: `lead dollars` occurs 5 times in the ledger, all in BL-819. Owed: the arm requires per-step lead and subagent figures, as item 1 and BL-819 item 3 already say, with its false-positive set measured over the reopened set and the archive. No close was false: BL-817 was not closed in 0.952.0.

**Progress (batch 244, c2).** Item 1's arm now requires a lead figure and a subagent figure on a sprint-branch `Outcome measured:` line, one per seat, in hours or dollars. The five archived sprint-branch lines (`docs/backlog.archive.md`, the stories-test-strategy, route-plus-pre-step, whole-pipeline, architecture and requirements groups) gained ground-truth seat figures from the committed snapshot `docs/analysis/pipeline-efficiency-s317-s320/b244-snapshot/` (extract.py with EXTRACT_WIN_END=2026-10-27T13:08:00Z, roll.py --seats), and three of them (stories-test-strategy, route-plus-pre-step, whole-pipeline) had their s320 figures re-taken; no direction verdict flipped. False-positive set of the tightened arm: EMPTY. Measured by the owner, the shipping validator run at the collected tip of this release against base (fc71a7b10), over copies of both corpora passed by path. The old predicate over the base archive, the tip archive, the base live ledger and the tip live ledger gives 0 rows each. The new predicate over the base archive gives exactly 5 SHAPE rows, BL-509, BL-511, BL-515, BL-568 and BL-569, the five sprint-branch outcome lines that carried no lead or subagent figure; they are the arm's own subject, not false positives. Over the base archive (fc71a7b10) with this release's five amended lines applied it gives 0 rows, with 21 in the close population and 16 on the no-step branch. Over the live ledger, base and tip, it gives 0 rows each, with 0 in the close population, because BL-513 and BL-694 are not yet stamped `**LANDED`; the fix hand ran a stamped copy separately and got 2 in the close population, both valid. The 5 true positives were dispositioned by amendment from the committed snapshot, and the exception set is empty. Receipt scoring, under `set -uo pipefail`: the receipt seeds one sprint-branch line with all three labels and only `Lead-seat share 2%, subagent seats 3`, runs `--archive` on it, and requires rc 1 with `BL-990	SHAPE`. The fix (this release) scores 0. Regression 1, the old three-label predicate (fc71a7b10), scores 1. Regression 2, a word-only `eff_seat_ok` (`grep -qi lead && grep -qi subagent`), scores 1. A second correct spelling (a sed split at every seat word, then a per-segment first-number check; it passes E0 over 26 seeds and the real archive) scores 0. A further candidate spelling, a single `grep -E` per seat, failed E0 on BL-972, the shared figure, and was rejected as not correct; the seed is what discriminated it. BL-817 stays `verify: manual` because it is PARTIAL. Still open: item 2, because the ruling citation (F-RULING) shipped in 0.952.0 but the rest of the filing shape (baseline sprint, owned step and expected movement) is not mechanised; and the remainder of item 1, because the arm checks the sprint, the labels, the direction, the citation and now the seat figures, but not that the line names the script that measured it or that it gives both before and after figures. Item 3's re-audit has been carried out, and the "Outcome owed" coverage clause holds. State after this release, in which BL-513 and BL-694 close and rotate, derived per id, by heading and `Outcome measured:` in each entry's body: of the 32 closes this entry names, 18 are archived with an `Outcome measured:` line and 14 are reopened in the live ledger, with 0 in neither; the base (fc71a7b10) was 16 and 16. The "Reopened by BL-817's re-audit" section holds 16 entries after this release: those 14, plus BL-695 and BL-804, which were reopened from outside the named set (BL-594, also reopened from outside it, has since closed and is archived). This count was corrected in batch 245 from a stated 17. It is derived by heading: an awk over `docs/backlog.md` that opens the section at its `## Reopened by BL-817's re-audit (batch 243)` heading, closes it at the next `##` heading carrying no BL- label, and counts the `## BL-` headings in between. Controls in the same run: 43 `## BL-` headings in the whole ledger, and 0 for a section token that occurs nowhere in the file.

**Progress (batch 245, c5).** Item 1's remainder and item 2 are mechanised in `scripts/validate-backlog-receipts.sh`. A sprint-branch `Outcome measured:` line must now name the script that measured it (NO-SCRIPT). That is either a full `.py`/`.sh` path that resolves in the tree, or a resolving directory token plus a bare basename that resolves under it. A `path:line` value citation is not counted, so a `.sh` value citation cannot satisfy the clause by its path shape. The line must also give a before and an after figure (NO-FIGURES): both of the words `before` and `after`, or a `<num> to <num>` pair. A sprint pair such as `s319 to s320` is not a figure pair. No-step lines are exempt from both. On the live ledger only, and never under `--archive`, a tagged efficiency entry ADDED since the merge-base of HEAD with `origin/main` must carry a `Baseline: s3NN` line (F-BASELINE), a `Step: <token>` line (F-STEP) and a non-empty `Expected movement:` line (F-MOVEMENT), unless it says there is no graph pipeline step. The step vocabulary is read at run time from `docs/analysis/pipeline-efficiency-s317-s320/scripts/extract.py`: every step file whose path matches its `STEP_RE`, less its `SUBPROC` set, plus `pre-step` and `gate-validation[<step>]`. Bare `gate-validation` is not a step, because the extractor never emits it. When the extractor is missing the validator refuses with exit 2. When `origin/main` is absent the filing-shape arm is skipped and the OK line says so. The population is the tag only, which is what F-RULING reads; an untagged `docs/analysis/` citer stays F-UNTAGGED's.

Census, derived with the arm's own entry awk (lifted from the validator) and its `eff_names_sprint`, not with a hand grep. Over the archive at base c0d4f97cc, 29 lines carry the phrase `Outcome measured:`, 26 entries carry an anchored outcome line, 8 of those take the sprint branch (BL-509, BL-511, BL-513, BL-515, BL-568, BL-569, BL-594, BL-694) and 18 take the no-step branch. The live ledger has 8 lines carrying the phrase and 0 anchored outcome lines, so item 1's new predicates have no live subject today. That is a vacuous zero and not a finding.

False-positive set: EMPTY, and no exceptions. Over the base archive the new predicates give 0 rows, with 26 in the close population and 18 on the no-step branch. The tip archive is unchanged, because no amendment was needed, and also gives 0. Over the live ledger, base and tip, they give 0 rows. The grammar reached 0 by fitting it to the corpus, not by narrowing it after a failure. None of the 8 sprint-branch lines names a full script path except BL-515 (`.../scripts/cap_rejections.py`). The other 7 name the directory `docs/analysis/pipeline-efficiency-s317-s320/scripts/` plus bare `extract.py` / `roll.py`, so a full-path-only grammar would refuse those 7, and the fold's directory-plus-basename branch is what accepts them. Seven of the 8 lines carry both `before` and `after`. The eighth is BL-594, at archive line 38660, which uses `2.23 to 1.24` with no before/after word. The adversary predicted it would fail, and it fails only under the contract's first grammar. The fold's `<num> to <num>` branch accepts it, so it is accepted and not dispositioned. Dispositions: none were owed, and there are no archive amendments.

Item 2's scoped false-positive set is 0 by construction on this branch, because the merge-base is HEAD and nothing is added. Unscoped, with every live entry treated as added (a scratch repository whose `origin/main` ledger is empty), F-BASELINE, F-STEP and F-MOVEMENT each fire on 34 entries: BL-397, 398, 507, 508, 510, 512, 514, 538, 541, 543, 550, 552, 583, 584, 615, 616, 679, 685, 695, 716, 804, 808 to 812, 817, 819, 838, 841 and 843 to 846. All 34 were filed before the labelled fields existed. Scoping to added headings is the decision that they are not re-filed, and BL-838 to BL-847, the freshest filings, are at base.

Self-probe E0 has 14 new seeds, BL-983 to BL-996, each with an offender and a near-miss per branch. The quiet sprint-branch seeds gained a resolving script path and a before/after pair. The expected set went from 20 to 30 rows. The counts went from 32 entries / 26 in the close population / 2 on the no-step branch to 46 / 31 / 2, plus 7 judged by the filing-shape arms. The assertion that `--archive` emits no F- row is kept. Each new predicate (script, figures, step, baseline, movement and the added-set scope) was replaced by an always-true version and run once, and each made E0 exit 2; an unmutated control copy exited 0. `core/fixtures/backlog-receipt-binding` gains the worlds ef-noscript, ef-dirbase, ef-nofigs, ef-topair, ef-filing and ef-filing-noref. ef-filing seeds `origin/main` with a pre-existing tagged entry carrying no fields, which must stay quiet, plus an added entry with no fields and an added entry with all three. It also gains the mutants m-noscript, m-nofigs, m-nostep, m-nobaseline, m-nomovement and m-noscope, each required to be killed by E0's refusal. Both fixtures that invoke the validator now seed `extract.py` and declare it in `inputs.decl`.

Still open: item 3's outcome lines from the next graph sprint. They are the first live subjects item 1's new predicates will see, and the first filings item 2 judges are the ones made after this lands. BL-817 stays PARTIAL.

verify: manual

## BL-819 — the lead session's own hours and tokens are outside every efficiency entry, and they are most of the wall clock

**DEFECT (efficiency).** BL-808 through BL-811 count subagent spawns and subagent dollars, and BL-812 counts
machine hours without saying how much of them is the lead's. No entry attributes hours or dollars to the lead
session, which is the larger share of the machine hours, and whose cost rose. Per story, from this ledger's s317–s320 extraction
(`steps.csv`, pipeline bucket, operator wait excluded, prices as `roll.py`):

| | s317 | s318 | s319 | s320 (through stories) |
|---|---|---|---|---|
| Lead active h / story | 2.93 | 2.48 | 2.74 | 1.29 |
| Agent wait h / story | 1.85 | 2.18 | 1.91 | 1.27 |
| Lead active share of machine hours | 61% | 53% | 59% | 50% |
| Lead $ / story | 15.2 | 23.3 | 23.6 | 10.6 |

The implementation step holds the largest part: lead active 18.7 h in s317 and 17.9 h in s319 (first given here as 18.7 h in both; the Correction block below has the corrected figure), and lead dollars $41.25
in s317 against $136.54 in s319 (API price; see the Correction block). Gate-validation is second (10.5 h and 9.8 h). Narrowing a parallel fan-out
(BL-808, BL-811) removes subagent tokens and little wall clock, because a fan-out takes as long as its slowest
shard; lead active time is the part of the wall clock that is serial. The lead hours come from the same gap
summation as every machine-hour figure here, which over-counts when timestamps arrive out of order (about +5 h on
s320's total); that changes no direction, and the attribution below should correct it before it builds on it.

Expected movement, a projection to read the measured sprint against and not a bar: implementation lead dollars
per story back toward s317's level at flat or lower lead hours, and lead active hours per story falling in every
step whose lead work is mechanised under item 2.

Owed:
1. **Attribute the lead's active time and tokens inside each step** of s319 and s320, with the extractor
   extended for it: dispatch and brief writing, reading and merging shard output, repair loops, validator and
   gate runs, re-reads of step files, and compaction recovery. Each class gets hours, tokens and dollars per
   story. The implementation step's lead dollars rising from $41.25 to $136.54 is explained from it.
2. **Decide each class by the step-value ruling** ("A step with no measured value goes",
   `.claude/rules/operator-rulings.md`, as applied in `docs/analysis/step-value-s317-s319.md`). Lead work that
   carries no catch or decision another element does not already make is removed or mechanised: a merge or a
   check the lead reads and re-derives by hand that a program already answers goes to the program.
3. **Lead hours and lead tokens join every efficiency outcome.** BL-812's measured sprint and BL-817's
   `Outcome measured:` line report lead active hours and lead dollars beside the subagent figures, per step.

Reference points, not pass bars: the table above. This entry closes on a measured graph sprint that reports the
lead's per-step hours and tokens against s317 and s319, with value evidence for any class whose cost did not
fall.

**Status (c6b).** PARTIAL, `verify: manual`.

**Correction (batch 243).** The implementation step's lead dollars rose from $41.25 (s317) to $136.54 (s319) at API price, corrected from $145, which does not reproduce on the fixed extractor. That is a true dollar rise caused by the model move: the s317 lead seat ran local qwen38flash-mlx for 68.1% of the implementation step's lead calls (1,530 of 2,248), 66.0% across implementation and its gate, and 43.5% across the whole sprint (3,539 of 8,133). s318–s320 lead seats are about 100% Sonnet. Priced token-equivalent, with s317's local calls at s317's own hosted lead mix (opus 60 / sonnet 4,528 calls), the implementation lead figure is $120.11 against $136.54: **+13.7% real**. Lead calls fell from 2,248 to 2,010 (**−10.6%**, not flat). Active hours went from 18.7 to 17.9; elapsed hours, gap-inclusive, from 26.0 to 27.0.

**Instrument defects, with figures.** Gap time is 91% of "other" hours; every hour figure here is labelled gap-inclusive with the gap beside it. The extractor's 10-05 mtime cut hid s314–s316; the extractor now selects by in-file timestamp, and those sprints are visible (fixed).

**Token-equivalent table** (hours gap-inclusive; local calls priced at that sprint's hosted lead mix; bracket = all local calls at Sonnet .. at Opus):

| sprint | API $ | token-eq $ (lead / sub) | bracket | elapsed h (gap h) | per story API / token-eq |
|---|---|---|---|---|---|
| s314 | 341 | 555 (214 / 341), FALLBACK: s315 hosted lead mix | 555 .. 666 (opus end = observed predecessor) | 59.3 (24.2) | — |
| s315 | 505 | 505 | — | 32.1 (19.0) | — |
| s316 | 1,307 | 1,307 | — | 100.1 (71.0) | — |
| s317 | 2,172 | 2,357 (505 / 1,852) | 2,356 .. 2,440 | 112.8 (51.4) | 103.4 / 112.2 (21 stories) |
| s318 | 1,720 | 1,721 | — | 74.8 (42.6) | 132.3 / 132.4 (13) |
| s319 | 2,234 | 2,234 | — | 110.0 (55.2) | 111.7 / 111.7 (20) |
| s320 | 1,048 | 1,048 | — | 75.3 (58.5) | 80.6 / 80.6 (13) |

**Mechanisations (batch 243):**
- **L1, beat polls.** `_gate-procedures.md` "Bounded-join beat" gave no progress-check form; it now prescribes `wait-for-deliverable.sh --complete --status <the wave's paths>`, never a grep, listing or count of the shard directory. s319/s320 had 163+164 and 22+38 hand probes. In a 30-hit sample, 12–14 asked the progress question that per-path `--status` already answers; the rest are partition checks (4), required reads of delivered content (5), orientation (5) and pre-dispatch checks (2). Recorded as already mechanised, with that residual. Pinned by `process-rule-pins` row `gp-beat-status`.
- **L2, gate re-reads.** Already prescribed: `gate-validation.md` and `SKILL.md` direct `gate-checkpoint.sh`. No step text changed. Residual: 4 re-runs in s319 and 0 in s320 — identical validator calls already run before a compaction in the same gate, across the 7 compactions whose recovery block carried the gate-resume section, excluding the prescribed snapshot budget call. All 4 fell in the 2 windows where the lead did not call `gate-checkpoint.sh done`. Recorded as already mechanised.
- **L3, snapshot updates.** Items 1–3 of "Sub-step snapshot update" were one Edit per row; they are now one `bash scripts/ai-dlc/snapshot-update.sh` call. The program runs `validate-artifact-budget.sh --stamps-only` on the lines it adds and writes nothing on a finding. s319: 445 snapshot Edits in 298 consecutive runs; s320: 219 in 123. One call per run is −7.35 and −7.38 calls per story; no dollar figure is claimed. Pinned by `gp-snap-program` and by the program's own fixture `snapshot-update-stamps`. 0.947.0's Deny B had already refused the 451 python and 49 `sed -i` snapshot writes of s319.

verify: manual

## BL-828 — mutant arms that score a kill without asserting their unmutated arm passed in the same run

**DEFECT.** Filed at the batch-243 close. In c6b, a fold found that 41 of `check-22-spawn-ledger`'s 43 mutant arms scored a kill without first asserting that the arm passed on the unmutated tree in the same run. A mutant that breaks the arm's setup, rather than the subject, therefore read as killed. 0.952.0 fixed check-22: `need_base` now occurs 52 times in `core/fixtures/check-22-spawn-ledger/run.sh`. No census has been taken across the other fixtures.

Owed: the census over `core/fixtures/*/run.sh`, with its false-positive set measured and enumerated before any arm ships. Then either a shared base-pass helper, or an arm that refuses a kill with no same-run base pass. Mechanism as `.claude/rules/fixture-mutants.md` states it.

**PARTIAL: the mechanism is in, and three fixtures are migrated.** "No same-run base pass" is data flow, so it cannot be grepped. The emission site can be. `core/fixtures/lib/mutant.sh` now carries `need_base` and `mutant_killed <flag> <name> <message>`, which is the one sanctioned way to emit a kill. It refuses (FIXTURE BROKEN, return 2, no `ok`) unless the flag says the unmutated arm passed in the same run. `scripts/validate-mutant-kills.sh` is a standalone `.githooks/pre-push` step, not an arm of `validate-enforcement-map.sh`. Its arms:

- M1 refuses a `KILLED`/`killed` on a non-comment line of a `run.sh` that is not routed through `mutant_killed`, in a fixture missing from `scripts/mutant-kills-allowlist.txt`.
- M2 refuses a stale row: a listed fixture with no unrouted kill left, or with no `run.sh`.
- M3 refuses a duplicate row.
- M4 refuses a row whose fixture is not on the allowlist at `origin/main`, so an added row or a count-keeping swap fails. It SKIPs with its reason when `origin/main` does not resolve or carries no allowlist yet.

So the allowlist only shrinks. A mktemp self-probe runs first and checks both directions.

The census, at 7c8a88fd7, covered 262 `run.sh`:

- Case-insensitive `killed` on non-comment lines: 882 lines in 127 fixtures.
- Case-sensitive `KILLED|killed`: 875 lines in the same 127. The 7 dropped lines are `SIGKILLed`.
- 234 comment lines are excluded.
- 360 of the 875 lines carry no `mut` word. They are kept, because the arm is keyed per fixture.

The allowlist is the output of `--derive`, never typed. That was 127 fixtures, and it is **124** rows now because three fixtures are migrated, `check-22-spawn-ledger`, `story-evidence-scaffold` and `handoff-resume-guard`:

- Every kill goes through `mutant_killed`.
- NB BINDING covers both kinds of call site.
- A second NB mutant, `mutant_killed` skipping `need_base`, is refused.

Owed: migrate the remaining allowlisted fixtures, removing each row in the change that migrates it.

**Progress (0.961.0, batch b245).** 33 more fixtures route their kills through `mutant_killed` behind a same-run base-pass flag, and each change deletes its own row, so `scripts/mutant-kills-allowlist.txt` falls from 124 rows to 91. The remaining 91 stay owed, and the entry stays open.

verify: manual

## BL-836 — nothing at pre-push asserts that an OPEN entry's `verify: sh` receipt still runs, so a rename inside a release breaks it silently

**DEFECT.** Filed at the batch-244 close. Found in the c4 tip adversary's F4 check. At pre-push, the only program that executes live receipts is `scripts/validate-backlog-receipts.sh`, and it `eval`s each one at `:316` and `:376`. A receipt exiting outside 0 and 1 counts as OUT-OF-POPULATION, capped at 1, and nothing asserts rc 0. `scripts/backlog-rotate.sh` executes receipts only for the entries it moves (`:510`). So an OPEN entry whose receipt stops measuring its subject keeps passing every gate. Measured twice in batch 244, both caught by hand before the release commit: c4's phase-B renames broke the BL-830 receipt (`bg1_killed` became `bg1_convicts`), and the BL-834 receipt lacked `core/fixtures/lib/mutant.sh` after it moved there.

Owed: a pre-push arm that executes every OPEN `verify: sh` receipt whose entry's own release is on the branch, or whose subject path the branch touches, and fails on any exit other than the receipt's recorded expectation. It needs a measured false-positive set over the live ledger before it ships, and both directions probed.

**Progress (batch 245, c5).** The arm extends the existing bare receipt step at pre-push (`.githooks/pre-push`, `scripts/validate-backlog-receipts.sh`) rather than adding a mode, as two arms. R7 judges OPEN entries. It FAILs on exit 9, on 126, on any exit of 128 or more, and on the own-shell route: exit 1, 2 or 127 where the receipt's own shell reports a missing command, a missing sourced file or a syntax error. Its ceiling is 0. It does not FAIL on bare 127 or on 2 through 8, because 2 through 8 are real STILL-LIVE codes: BL-830's own receipt exits 2 while the entry is open. The could-not-measure rule lives in the new helper `scripts/backlog-receipt-lib.sh` (mode 100755), and `scripts/backlog-reverify.sh` sources it too. Its `cant_measure` was extracted byte-for-byte from `scripts/backlog-reverify.sh`, and the reverify output is identical over the live ledger's 43 rows. R8 judges entries stamped `**LANDED` since the merge-base plus headings added in the `docs/backlog.archive.md` diff, and each must exit exactly 0. Its base comes from `--base`, default `origin/main`. R8's population is relative to the LOCAL `origin/main`, so a stale one widens it, and the gate is run after a fetch. A rotation counts only when an entry's heading is added in the archive diff and its id is absent from the archive at the merge-base, so an archived entry retitled on the branch is not run (self-probe seed BL-988, mutant c5-m9). The condition is deliberately not "removed from the live ledger": an entry filed and rotated in the same release, as BL-848 is, sits in the live ledger at neither end, and that spelling drops it from R8 (seed BL-989, mutant c5-m10). Seeds BL-977 (exit 126) and BL-978 (exit 130) hold R7's 126 arm and its 128-and-above branch (mutants c5-m7 and c5-m8).

The open population is empty today. Control: the ledger carries 47 `^verify:` lines, the one `^verify: sh` is the legend, and 0 of 43 entries hold an open `sh` receipt. R7's ceiling of 0 therefore rests on a vacuous population. Each arm prints its empty state rather than a bare clean, even under `--quiet`: `OPEN-POPULATION: EMPTY`, and `CLOSED-POPULATION: EMPTY`, `NOT DERIVED` or `<n> run`. Both lines are probed before the corpus. R8's false-positive set was measured on two scratch branches. BL-604 exits 0 and passes. BL-056 exits 16 and FAILs by name, because its receipt rotted after its close, so it is a true positive. No archive sweep was run. Three mutants are each killed: c5-m1 drops the closed population, c5-m2 puts the ceiling back to 1, and c5-m3 removes exit 9 from the FAIL set. The `.githooks/pre-push` argv is unchanged, so the step needs no hook edit and the owner pushes.

Neither executor can recurse. A receipt that invokes `.githooks/pre-push` re-enters the validator from inside the run executing it, and 40 archive `sh` receipts mention pre-push. A rotated one re-enters through R8, and an OPEN one through the open scorer that R2 through R7 read. Both `score_ledger` and `score_closed` export `BR_RECEIPTS_RUNNING` to every receipt they run. Its value is the ledger's identity: the subject repository's git common dir, physically resolved, plus the ledger's path relative to the subject root. The common dir is shared by every checkout, so a pre-push re-entered from inside a receipt's `git worktree add` checkout resolves the same key. Only a nested run whose own key equals the inherited value skips. A run that does skip still runs its self-probes and the efficiency arms, but executes no corpus receipt. A presence-only key had made every receipt that drives this validator on a ledger of its own seeding skip R2 through R8. Measured on BL-227's archived receipt at the presence-only tree: exit 0 unset, exit 1 with the variable set. With the ledger key it exits 0 with the variable set to a different ledger. It prints `OPEN-POPULATION: SKIPPED` and `CLOSED-POPULATION: SKIPPED`, and exits on the efficiency verdict alone. The name has no `AI_DLC_` prefix because fixtures strip that prefix from their environment (`core/fixtures/readset-stage1-verdict/run.sh:46` is one). Paths checked: a direct `bash .githooks/pre-push` keeps the variable, and so does `git push`, since git passes its environment to the hook. Inside `core/scripts/hermetic-run.sh` the `env -i` drops it. That path cannot reach the validator, because none of the 25 fixtures that declare the hook in `inputs.decl` also declares `scripts/validate-backlog-receipts.sh`, and the consumer hook does not invoke the validator. The self-probe adds BL-976 (an open receipt) and BL-987 (a closed receipt), each asserting the variable is set, plus both SKIPPED lines. `backlog-receipt-binding` arm c5r drives two receipts through a probe `.githooks/pre-push` that carries the receipts step's invocation. BL-864 is stamped LANDED: the gate terminates, R8 runs it once, and the inner run prints `CLOSED-POPULATION: SKIPPED`. BL-865 is open: the gate terminates, its base exit is 0, and the inner run prints `OPEN-POPULATION: SKIPPED`. Mutant c5-m4 ignores the sentinel on entry and is killed on both paths. Each seed bounds itself by depth, exiting 7 at depth 2, so BL-864 fails under R8 at 3 runs. BL-865 stops being ALREADY-PASSING and runs 14 times against its control's 2. On the open path the gate still exits 0, because a base exit of 1 is in-population for the open scorer, so the depth cap is what terminates it. Mutants c5-m5 and c5-m6 drop the export to the open and the closed workers, and the self-probe kills each. Self-probe seed BL-979 records the value an open receipt inherits. It asserts that the same ledger reads as a re-entry and that the same ledger resolved from a second checkout gives the same key. It also asserts that a ledger in a separate seeded repository, and a different ledger in the same repository, do not read as a re-entry. BL-979 also holds the repository half of the key: two repositories that carry a ledger at the same relative path must get different keys, or a receipt that seeds its own `docs/backlog.md` (BL-387's shape) would read as a re-entry. Mutant c5-m11 restores the presence-only key and c5-m12 drops the common dir from the key, and BL-979 kills both. Both export sites resolve the key before dispatch and refuse with exit 2 if it does not resolve, so an empty key cannot fail open. A mutant scored by a self-probe refusal is killed only when its target seed's refusal, the text `seed <id>:`, is the one that fired. A 600-second watchdog bounds the arm.

Cost: R8 re-runs receipts that `scripts/backlog-rotate.sh` already ran at the release commit, so a fixture-keyed receipt runs twice in a release. R8 still earns that run because the pre-push tree is the MERGED tree, not the tree the rotate step saw.

Seeded evidence, per shape:

| Shape | exit | OPEN R7 | LANDED R8 |
|---|---|---|---|
| exit 9 | 9 | fires | fires |
| 126 | 126 | fires | fires |
| 130 | 130 | fires | fires |
| own-shell command not found | 127 | fires | fires |
| exit 2 | 2 | does not fire | — |
| BL-830 rename under `grep -q old_name` | 1 | CANNOT fire | fires |
| BL-830 calling the renamed function | 127 | fires | fires |
| BL-830 as it broke (`. f; old_name x \|\| exit 1`) | 1 | fires (own-shell) | fires |
| BL-834 as it was, `\|\| exit 9` guard | 9 | fires | fires |
| BL-834 guardless, source then call | 127 | fires | fires |
| BL-834 guardless, source only | 1 | fires | fires |
| BL-834 via a child script sourcing the missing file | 127 | does not fire | fires |
| bare 127 from a child's missing helper | 127 | does not fire | fires |

Three open-entry shapes cannot fire: the rename under `grep -q`, a child's bare 127, and a child sourcing the missing helper. This entry's title names an OPEN entry's receipt as its subject (lead ruling), so it stays PARTIAL. Reported, not built: a convention that asserts the anchor before testing the defect (`grep -q anchor f || exit 9; …`) would turn a rename into exit 9, which R7 sees. That is a design question for the next batch. The scored receipt draft is evidence only. Scored under `set -uo pipefail`, it exits 0 on the fix in this release, 1 on the base c0d4f97cc, 1 with the population not widened, 1 with exits 2 through 8 in the FAIL set, and 0 on a second spelling (the LANDED set from the ledger diff's added-line ranges, the rotated set from `git log -p`).

verify: manual

## BL-837 — the remediation guard skips dispatch binding when a verdict carries any plain FAIL, so a forged unbound verdict acquits through an in-force SUPPRESSED entry

**DEFECT.** Filed at the batch-244 close, from the c6 second delta adversary (owner ai-dlc-c5). The defect is already on `main` and independent of `FAIL_WAIVED`. In `core/hooks/ai-dlc-gate-remediation-guard.sh`, arm 7a's dispatch binding runs only when `LIVE_CLEAN=1` (`:1070-1080`, `:1209`). A verdict carrying any plain FAIL leaves `LIVE_CLEAN=0`, so binding never runs.

Forged input: a newer UNBOUND verdict whose only plain FAIL is a check that an in-force, genuinely cited SUPPRESSED entry covers. Arm 7b covers that check, so the real bound pass's uncovered FAIL is never read. The guard returns ALLOW, both at the pre-c6 guard (0.957.0, `619d7acd9`) and at 0.958.0, with no `GATE_VERDICT_UNBOUND` logged. Expected: DENY with `GATE_VERDICT_UNBOUND`, because an unbound verdict may convict but never acquit. Controls in the same probe: a forged all-PASS verdict and a forged `FAIL_WAIVED`-only verdict both DENY. Check 26 is outside this path.

Owed: run the binding whenever arm 7b could empty the fail set, not only when the fail set is already empty. That changes arm 7a for every gate, so the fix needs its own contract and adversary. It also owes a guard fixture arm with this forged input and a mutant restoring the `LIVE_CLEAN`-only condition.

verify: manual

## Graph s320 implementation review (filed 2026-10-27)

Found by reading graph's s320 lead transcripts (`0de9fe4e`, `ca14f3b7`), its spawn ledger, its commit log and the `docs/reviews/s320/` gate records, read only, at graph `b975b7746`. Times are EDT. At filing, 10 of 13 stories were done after about 16 hours of implementation; 1.3 was in review and 2.1 and 2.2 had never been dispatched. Derivations are named in each entry.

## BL-838 — the shipped dev seat is haiku, and implementation reworks rose once dev and QA moved to haiku

**DEFECT (efficiency). Operator ruling 2026-10-27: `dev` → sonnet/medium, `dev-escalated` → sonnet/high.** `templates/settings.json.template` `aiDlcRoles` pins `dev` to haiku/medium and `dev-escalated` to sonnet/medium; 0.781.0 (`6c8ea1d9d`) set both, moving dev from sonnet and dev-escalated from opus/high.

Measured in graph (spawn ledger `model_bound`/`effort_bound`, and story review files by the highest `-p<N>` per story under `docs/reviews/s31N/`):

| Sprint | dev | qa | stories through both gates at pass 1 | gate-1 / gate-2 passes per story |
|---|---|---|---|---|
| s317 | sonnet/medium (82), then haiku/high (40), then haiku/medium (13) | sonnet | 9/17 | 1.71 / 1.18 |
| s318 | haiku/medium | sonnet | 4/13 | 2.23 / 1.38 |
| s319 | haiku/medium | haiku | 4/18 | 3.00 / 1.78 |
| s320 | haiku/medium | haiku | 4/10 | 1.80 / 2.30 |

This is confounded: specs got denser and gates were added over the same sprints, and s317's dev rows carry no story id, so its sonnet and haiku stories cannot be split. The s320 4.2 trace is the direct evidence. Its gate-1 p1 and gate-2 p1 failed on the AC2 literal grep `not.toContain(COMPLETE_HODL.hodl_wallet)`, the AC7 enumeration and the AC7 two-cause state, and gate-1 p4 failed on a control test that never reached the modal. The story file as dispatched (`27481ace9`, 18469 B) states the first three verbatim: the grep 3 times, "two-cause" 2 times. Each miss costs a serial gate pass of about 12 minutes and five seats, so a cheaper dev spawn is not a cheaper story.

QA, consumer side: the template pins `qa` to sonnet/medium, and graph's `.claude/settings.json` overrode it to haiku in the 0.789.0 reconcile (`b3f2fe199`, graph-local). The operator ruled QA back to sonnet/medium. That is graph's setting and is owed in graph, not here. The same reconcile also moved graph's `code-reviewer` from opus to sonnet against the template's opus.

Owed: the template change, `render-agent-definitions.sh` output in the fixtures that pin these tiers re-checked (`core/fixtures/dispatch-model-guard/seed.sh:57-58` seeds its own values), and an `Outcome measured:` line on the next graph sprint, using the table's two columns.

Tree check for the template half (exit 0 when fixed; measured 1 on `origin/main` `cb1486eac` and 0 on a copy with both roles changed): `python3 -c 'import json,sys;r=json.load(open("templates/settings.json.template"))["aiDlcRoles"];sys.exit(0 if (r["dev"]["model"],r["dev"]["effort"],r["dev-escalated"]["model"],r["dev-escalated"]["effort"])==("sonnet","medium","sonnet","high") else 1)'`. It is not the `verify:` line because `validate-backlog-receipts.sh`'s seed grammar cannot spell a python predicate (R2 reads it UNSCORABLE), and the entry closes on the outcome line anyway.

Decision rule: the step-value ruling, "A step with no measured value goes" (`.claude/rules/operator-rulings.md`).

verify: manual

## BL-839 — a story held on a lead precondition falls out of the lead's worklist, and nothing re-surfaces it

**DEFECT. BLOCKER-grade in s320.** The s320 wave plan (`_bmad-output/planning-artifacts/s320/wave-plan.md`, written 06:25Z) holds 2.1 and then 2.2 "for the amendment": the lead commits 2.1's `## Tolerance (pre-stated)` through a PM re-dispatch before the ops dispatch (story 2.1 AC2, line 115). Sixteen hours later the amendment had not happened: 0 spawn-ledger rows since 02:00 name 2.1 or 2.2 (control: 1.3 has 5), 0 `pm` spawns since 02:00 (control: 42 earlier in the sprint), the story file's last commit is 01:50, and `pipeline-snapshot.md` carries neither story in its worklist. The lead session compacted 38 times over that span. 2.2 waits on 2.1's `## Outcome`, so the chain still has to run in series after every other story is done.

The wave plan is a document the lead wrote once. Nothing reads it back, and no snapshot field carries a held story's unblock action, so after a compaction the hold is invisible.

Owed: every held story and its unblock action carried as a snapshot field that the post-compact digest renders, and a check at the implementation step's exit (and at each wave join) that every `ready-for-dev` story is dispatched or names its hold. Probe it with a seeded story held on an amendment that never lands.

verify: manual

## BL-840 — a story can set a dated read window that becomes the sprint's earliest close, with no deferral path stated

**DEFECT.** s320 story 1.3 AC4 scores the s319 monitor "operator press by T+7", ceiling 2026-10-29T21:36:22Z. Its dependencies line requires that AC4 "runs in the final 12 hours before its ceiling" (from epoch 1793266582, 05:36 EDT on 10-29). So the sprint cannot close before then, two days after every other story could have, and nothing in readiness, stories adversarial or the wave plan surfaced that. The closing writer's `deferred_acs` path (`implementation.md:167`) already exists, and s320 used it for 1.2 AC4, 3.3 AC4/AC5 and 3.4 AC7/AC8, but the story does not name it for AC4.

Owed: the stories step (or readiness) refuses an AC whose earliest permitted run time falls after the sprint's planned close unless the AC states its deferral (`deferred_acs` and the carry-over item). The wave plan states the sprint's earliest close derived from those windows.

verify: manual

## BL-841 — while an AskUserQuestion is pending, the lead advances no lane

**DEFECT (efficiency).** Today's nine AskUserQuestion waits add up to 242 minutes (`tool_use` to `tool_result`, lead transcripts). The lead is single-threaded on the question, so every lane whose next step is ready waits behind it. Clearest case: the question at 02:57 waited 95 minutes; story 1.1's gate-2 PASS committed at 03:11, and the next spawn-ledger row is at 04:35 (0 rows between 03:11 and 04:34). The spawn ledger's long gaps on 10-27 (101, 56, 44 and 69 minutes) line up with the 02:57, 05:22, 06:22 and 07:06 questions. Of the nine, two were mechanical Check 22 questions (BL-842), and one (4.1 AC13, unmeetable as written) genuinely gated its story.

Owed: before a blocking question, the lead dispatches every ready action on lanes the question does not touch and arms their joins; the question names the lanes it holds. Measure it as lane idle minutes during operator waits on the next graph sprint. Handoff gaps stay excluded by ruling; an operator wait inside a session is not a handoff gap.

Decision rule: the step-value ruling, "A step with no measured value goes" (`.claude/rules/operator-rulings.md`).

verify: manual

## BL-842 — Check 22 routes a spawn-ledger binding question to the operator

**DEFECT.** Twice on 10-27 (02:57, waiting 95 minutes, and 09:38) Check 22 failed on one old spawn-ledger row: the test-strategy pass-3 cross reviewer, then the pass-2 QA cross reviewer. Each question asked whether that row carried its role binding and brief. That is a mechanical fact about the ledger with a closed set of remediations (BL-512's Check 22 arm 4 shapes), not an operator decision. BL-512 removed discarded passes for this check; it did not remove the operator from the loop.

Owed: a Check 22 failure on a ledger row resolves through its named remediation (a sharded re-dispatch or a cited Rule 28 exception) without an AskUserQuestion; `steps/` text routing a Check 22 failure to the operator is removed. A guard or fixture arm that counts operator questions citing Check 22 in a seeded run.

verify: manual

## BL-843 — capture heads and counts are retyped into the Dev Agent Record, so every re-capture re-stales the record

**DEFECT (efficiency).** s320 4.2 gate-2 p2 failed because Dev Agent Record lines 171 and 185 named capture heads (`bb38de110`, `8dc444e17`) that the captures' own headers contradict (`59a3d3c5e (+dirty)`, `2cb736e8`/`760cb0d4`). Rework 3 re-captured, which moved the head to `9bba0b54`, and p3 failed on line 171 again plus line 189. Reworks 3 and 4 state "No code or test file changed". 4.1's QA p1-p3 failed on the same class ("record-only", commit titles 09:19, 09:37, 10:00). Four 4.2 passes plus three 4.1 passes, each about 12 minutes and five QA seats, were spent on metadata the capture files already carry.

BL-510 made a divergent `head:` a WARN in `validate-handoff-evidence.sh`, and BL-809 item 3 left "the wrong-commit capture" as a WARN. The finding still costs a full pass because a model retypes the value. That is the "render safety-critical output; do not let a model retype it" rule from `mechanism-design.md`.

Owed: the Dev Agent Record cites captures by path only, and the heads and counts are rendered from the capture headers into a generated block with a `--check` at the pre-gate handoff. QA's checklist stops comparing prose to headers.

Decision rule: the step-value ruling, "A step with no measured value goes" (`.claude/rules/operator-rulings.md`).

verify: manual

## BL-844 — a record-only gate-2 rework re-runs the full QA fan-out, and a gate-3 rework re-runs gates 1 and 2

**DEFECT (efficiency).** BL-809 item 1 routes a record-only gate-1 re-review to the validator and one serial reviewer. Gate 2 has no such route. In s320 4.2, QA p2, p3, p5 and p6 each failed only on record or capture-metadata findings, and each re-dispatch was five QA seats (four parts and a cross; lead transcript 12:06, 13:31, 14:50, 15:05), followed by a gate-3 pass. 4.2 ran 14 gate passes and about 50 seats.

Owed: a gate-2 NEEDS_REWORK whose every Critical and Important finding is `Class: EVIDENCE|BOOKKEEPING` re-checks through `validate-handoff-evidence.sh` and one serial QA seat over the open findings, the way BL-809 item 1 does at gate 1. Measure it as gate-2 passes per story, the BL-838 column.

Decision rule: the step-value ruling, "A step with no measured value goes" (`.claude/rules/operator-rulings.md`).

verify: manual

## BL-845 — Check 11's smoke coverage, a mechanical arm, runs first at gate 3, after gate 2 has passed

**DEFECT (efficiency).** s320 4.2 passed gate 2 at p4 (13:58), then gate 3 failed Check 11 (14:04): the `hodl_wallet` typed-confirm step had no browser smoke test. Four gate-2 passes had not raised it. The fix (rework 5) then sent 4.2 back through gate-1 p4 and p5 and gate-2 p5 to p7, about 1h45m of serial wall clock (14:04 to 15:51). Check 11 reads the story file and the diff, both fixed at the gate-2 go-signal.

Owed: the gate-3 script arms that read only the frozen diff and story file (Check 11 at least) run at the gate-2 go-signal and refuse there. Probe with a story whose Check 11 fails at a gate-2 PASS sha.

Decision rule: the step-value ruling, "A step with no measured value goes" (`.claude/rules/operator-rulings.md`).

verify: manual

## BL-846 — QA reports one instance of a defect class per pass, so a class with two instances costs two passes

**DEFECT (efficiency).** s320 4.2 QA p5 failed because one Playwright replay could not be reproduced from its capture (no `webServer`, no start command). p6 then failed on the same class in a second capture (`playwright-sweep-hodl-story-4-2-green.txt` line 1 names port 5173 with no start command). The same happened with 4.2's head stamps across p2 and p3. QA ran on haiku in s320 (BL-838).

Owed: QA's checklist requires that a finding sweep its class across the story's whole evidence set and list every instance, and the rework brief carries that list. A fixture arm seeding two instances of one class and asserting both are reported.

Decision rule: the step-value ruling, "A step with no measured value goes" (`.claude/rules/operator-rulings.md`).

verify: manual

## BL-847 — the stories step never reads the QA checklist that gate 2 applies, so a spec can contradict its own gate

**DEFECT.** s320 4.2 as dispatched had a `## Smoke Test Updates` section reading "None", derived by grepping `scripts/test-aws-smoke.sh` for HODL (0 hits). Gate-2 p1 failed C2 ("Smoke-test-update HARD GATE unmet: the browser HODL spec is not updated") and gate 3 failed Check 11 on the same surface. It also failed C1, "Visual consistency: any CSS/layout change verified via computed style". That rule lives in graph's `extensions/roles/qa-domain.md:167` and `overrides/team-roles__qa__bug-class-sweep.md:249`, and the dispatched story mentioned computed style 0 times. `stories-test-strategy.md:261` names `## Smoke Test Updates` as read by Check 11's smoke clause but does not define which surface counts as smoke, and the stories step loads no QA domain extension.

Owed: the stories step reads the QA checklist that gate 2 will apply, consumer extensions included, and every HARD GATE item that the story's diff class triggers appears in the story's ACs or test strategy. The smoke surface is one definition shared by `stories-test-strategy.md`, QA and Check 11.

verify: manual

## BL-850 — fixture optimization

**DEFECT.** An umbrella entry for fixture optimisation: a fixture whose wall clock exceeds what its checks need. Typical causes are a subject run once per assertion, mutant or world instead of once per distinct question, and a full mutant × arm matrix re-scored on every push. Each fixture gets its section in the release that changes it.

**PARTIAL (0.961.0, batch b245 part one).** 54 fixtures are narrowed. Each measures its mutant × arm matrix once by `bash core/fixtures/<fx>/run.sh --matrix`, records it in the header, and on each push runs each mutant's deciding arm plus one green twin. Counts below are before → after per push, from the owners' instrumented runs; "not recorded" means no count was taken. Loaded costs come from the dress.

- check-24-adversarial-convergence: validator executions 1357 → 747; receipt world builds 474 → 43. NOT FINAL: its validator seam follows.
- readset-skip: hook drives 740 → 221; direct apply calls 228 → 148; deriver runs 339 → 170; git inits 449 → 63; world builds 943 → 348.
- ledger-reverify: shards b/c/d collapsed into one directory; engine invocations 216 → 212; seeds 4 → 1; baselines 4 → 1; full-ledger sites 34 → 6. Row helpers now match a label as a fixed string up to a boundary.
- apply-drift-refile: shards b/c collapsed; apply.sh runs 174 → 139; fresh worlds 97 → 75; mutant arm-scorings 65 → 50.
- foreground-budget-deny: hook invocations 4176 → 489.
- document-partition: predicate runs 1015 → 89.
- carried-findings: validator runs about 1100 → 62.
- census-hermetic-coverage: censuses 24 → 22.
- snapshot-archive-rotate: the mutant control's re-run of the kill-point sweep (about 655 rotator runs) → one counted run checked against the live trace.
- enforcement-map-sites: validator runs 185 → 139; whole-template re-seeds 42 → 0.
- ledger-status-vocabulary: full validator runs 11 → 1.
- validator-arm-selection: m2 drives 3 representatives instead of every one.
- serial-remediation-worklist: worklist runs 210 → 30; worlds 210 → 5; mutant cells 168 → 27.
- remediator-shard-join: 13 repeated unmutated drives → 3 per-family copy controls.
- prepush-pool-depth: git-init worlds 93 → 14; pool drives about 195 → 23; the hook-2 watcher battery is deleted, because I66 binds that block to hook 1's, and an arm drives `validate-enforcement-map.sh --arms I66` over a one-byte seeded fork.
- layer-adjudication-tier: layer-drift calls 274 → 114; Part 11 mutant drives 110 → 20.
- layer-readopt-gate: E2 drives 161 → 57; git inits 161 → 12.
- gate-resume: hook fires about 288 → 70; the shipped hook's dense sweep is unchanged.
- party-wave-barrier: self-probe replays about 60 → 3.
- advisor-gate-deny: hook runs about 679 → 240.
- askuserquestion-citation: node runs 25 → 9.
- artifact-path-migration: seed.sh runs 10 → 1 plus clones.
- artifact-path-conformance: seed.sh runs 9 → 3.
- audit-anchors-schema: renders 7 → 2.
- upstream-routing: core-paths.sh about 1s → 0.03s per call, about 70 calls.
- suite-dispatch-order: real sleeps about 12s → 1s.
- snapshot-evidence-cell: 260 selector drives → deciding worlds plus one twin.
- vocabulary-index: the 24 mutant worlds skip the renderer's self-probes through `--skip-selfprobe`; controls keep them.
- backlog-real-ledger: classifier full-ledger runs 2 → 1.
- transient-ignore-block: renders about 168 → 90; seeds 80 → 7 plus clones.
- agent-definition-render: seeds about 196 → 14; hook-world builds 20 → 1.
- Narrowed to deciding arm plus twin, count not recorded: adversarial-citation, apply-legacy-script-path, apply-setup-sited-merge, apply-worklist-rows, backlog-ledger, backlog-size-ceiling, check-15-bypass, check-25-steering-conduct, check-31-ac-falsifiability, consumer-machinery-home, content-seal, crosswalk-home-declaration, derived-fence-binding, fixture-git-env-seam, fold-architect-ledger-join, owed-derivations, release-version-triple, retired-layer-contract, retro-audit-scans, retro-branch-behind-main, review-reroute, schema-install-fallback, subject-partition.

Owed: the remaining fixtures in the b245-fx2 part, among them check-24-adversarial-convergence's seam, layer-reference-resolution, and the prevention mechanism that refuses regrowth.

### reconcile-emit-report (q5)

The fixture renders the full mechanical region about 200 times across its shards, and each render runs every reconcile detector. Owed: render once per distinct render input (normally once in total) and compare every report variant against that render through `emit-report.sh --verify --region-from <file>`. The variants include missing, stale, edited, alias path, blockers resolved, re-rendered since approval, and the hand-edit/UNDECIDED cases. That seam skips the render and calls `er_compare`, the same single function plain `--verify` runs after its own render. It prints `emit-report: --region-from: region supplied by caller; nothing was rendered` on every run and never writes the approved-region record. Keep ONE end-to-end plain `--verify` so render-plus-compare stays wired. A setup whose repository state changes the render stays a separate render, with a comment saying why. The cache-only phases go with the retirement of BL-679's recorded `--verify` PASS (BL-679 and BL-685, RETIRED in the same release). apply.sh and the update skill never pass the flag.

Renders per push (counter spliced into `render()`, one shard per run): before (011853d19) shard a 694, b 171, c 280, d 25, total 1170; after shard a 15, b 22, c 29, total 66 (shard d is deleted). Per tag, read off each render's program and consumer in the after logs: base-world a 2, b 3, c 2 (7); conflicting-state a 8, b 17, c 12 (37); mutant-deciding a 5, b 2, c 15 (22). Per-shard floor (base-world renders each shard pays): a 2 (the seed render and the one plain `--verify`), b 3 (the seed render, V-R's real approval and the ctl-V control), c 2 (the seed render and the ctl-SB control). Narrowing: each mutant runs its deciding arm and its named twins, and the matrix is re-measured by `bash core/fixtures/reconcile-emit-report/run.sh --matrix`.

**Progress (0.962.0, batch b245).** reconcile-emit-report renders once per distinct render input: 1170 renders per push become 66 (base-world 7, conflicting-state 37, mutant-deciding 22), with 0 coverage losses (161 assertions retired with the BL-679 cache, 40 folded into their mutant kill lines). Solo hermetic runs at 66623ceb4: shard a 97s, b 71s, c 56s. The entry stays PARTIAL.

verify: manual

## Reopened by BL-817's re-audit (batch 243)

Each entry below closed on a tree receipt and is reopened because its own step's per-story cost did not fall over the graph sprints after its fix, measured with the s317-s320 extractor (token-equivalent dollars with API dollars beside, gap-inclusive hours). Each owes an `Outcome measured:` line on a later graph sprint, or a value citation, before it closes again.

## BL-397 — a story reaches gate-1 without the evidence sections, and reaches QA without a full-collection run with counts

**DEFECT (efficiency).** Closed in 0.674.0 on a tree receipt, reopened by BL-817. Its decision rule is the step-value ruling, "A step with no measured value goes" (`.claude/rules/operator-rulings.md`).

**DEFECT.** Filed by the consumer as PC-S315-DEV-AND-QA-ROLE-CHECKLISTS-LET-A-STORY-REACH-GATE-1-WITHOUT-THE-EVIDENCE-SECTIONS-AND-THE-FULL-SUITE.

**Claims, enumerated.** (1) No story file carried `Production Integrity Tests`, `Smoke Test Updates`
and, for renames, `Rename Verification` at its first submission: the filing says 0 of 5. (2) Story
1.5 reached QA without the dev having run the full suite and failed gate-2 on a baseline-fixture
test. (3) Check 21 failed pass 1 with 0 of 31 strategy test ids cited in any Dev Agent Record.
(4) Code review has no baseline-fixture sweep when a diff changes a handler's result shape.

**Premise, re-derived at `origin/main` 144c41b8.** The story template is BMAD's, and no ai-dlc
step tells the lead to add the evidence headings: `Strategy Test IDs` occurs in 0 files under `core/`
(control: `Production Integrity Tests` occurs in 4). `dev.md` already requires a canonical
full-collection run, but only inside `## Workflow Per Task` item 15. The dev side requires no counts: `deselect`
occurs 0 times in `dev.md` outside that section and once inside it. The phrase is the `--deselect`
flag, not a count. `code-reviewer.md` contains `baseline-fixture` 0 times (control: `fixture` 9).
At the consumer's final S315 tip, 5 of 5 stories carry the Production Integrity Tests and Smoke
Test Updates headings and 2 of 5 carry Rename Verification, because rework added them. The
first-submission state the filing counts was not walked. That walk was available but not taken,
because this session's harness refuses git commands aimed at the consumer tree. Claim (1) is an
unmeasured claim, not an unmeasurable one. Claim (2) is the seats' reading and was not
re-derived.

**Consumer overrides, read-only, `graph/.claude/skills/ai-dlc/overrides/`.** 10 override files
(control: 10 of 10 carry `shadows:`). The consumer shadows `team-roles/dev.md#Workflow Per Task` and
`team-roles/qa.md#Validation Checklist` wholesale (`team-roles__dev__bug-class-sweep.md`,
`team-roles__qa__bug-class-sweep.md`). Nothing shadows `code-reviewer.md`, `stories-test-strategy.md`
or Check 21. Any upstream text inside those two sections never reaches this consumer's dev or QA
until the consumer re-adopts the overrides against the new base. That is why the new requirements
sit in sibling sections.

**The fix.** `stories-test-strategy.md` Pre-Flight Checklist item (c) requires four headings in
every story file. They are `## Production Integrity Tests`, `## Smoke Test Updates`,
`## Rename Verification` and `## Strategy Test IDs`, the last a table with a closed `Kind`
vocabulary. `dev.md` gains `## QA Handoff Evidence`: the full-collection invocation, its working
directory and collected/passed/failed/deselected/skipped/xfailed counts before the handoff
message, the four sections filled, and every table row resolved. `qa.md` gains
`## Handoff Evidence Precondition`, a REJECT before any checklist item when that evidence is
absent. `code-reviewer.md` Field Verification item 5 adds the baseline-fixture sweep, with a
control, as an Important finding. Check 21 names the table as its citation set (BL-398).

**Fixture.** `story-evidence-scaffold` (ships) has section-keyed arms. The dev and qa arms first
stub the two shadowed sections, as the loader does, so text moved into them is a finding. It has
twelve copy mutants, each killed by its own arm only, plus a control and a cwd probe. Bound to
Check 21 in `enforcement-map.yaml`. Its read-set is not yet traced; the operator runs
`sudo bash core/scripts/derive-fixture-readsets.sh --list "story-evidence-scaffold"`.

**Receipt, scored.** Tip 1 (no fixture). Fix 0. Wrong fix A exits 1: it folds the dev text into
the shadowed `## Workflow Per Task`, which a whole-file grep accepts. Wrong fix B exits 1: it puts
the qa precondition inside the shadowed `## Validation Checklist`. Exit 9 means a subject role
file is gone or the fixture reports FIXTURE BROKEN.

Closed in 0.674.0 (verified f7eec6f5) on a tree receipt, reopened by BL-817.

Held note (batch 177): shipped the Pre-Flight scaffold (c), the dev `## QA Handoff Evidence` and
qa `## Handoff Evidence Precondition` sections outside the consumer's shadowed sections, the
code-reviewer baseline-fixture sweep, and fixture `story-evidence-scaffold`.

Former receipt (the mechanism, not the outcome): sh F=core/fixtures/story-evidence-scaffold/run.sh; [ -f core/team-roles/dev.md ] && [ -f core/team-roles/qa.md ] || exit 9; [ -f "$F" ] || exit 1; o="$(bash "$F" 2>&1)"; [ $? -eq 2 ] && exit 9; for m in dev-into-workflow dev-no-counts qa-into-checklist cr-no-sweep drop-strategy-heading move-strategy-heading; do grep -qF "MUTATION '$m' killed by its own arm only" <<<"$o" || exit 1; done; grep -qx 'story-evidence-scaffold: PASS' <<<"$o"

Re-audit (BL-817): graph s314+s315 against s317, s318, s319, `docs/analysis/pipeline-efficiency-s317-s320/scripts/` (extract.py, roll.py as committed at fc71a7b10 on main; the step rows of steps.csv per story); per story, implementation plus gate-validation[implementation]: before (s314+s315 pooled, 9 stories) 2.00 h gap-inclusive, token-equivalent $29.0 (API $23.1), 71.4M tokens (s314 token-equivalent is the FALLBACK: s315's hosted lead mix); after s317 (21 stories) 2.01 h gap-inclusive (gap 0.71 h), token-equivalent $36.8 (API $31.4), 71.3M tokens; s318 (13 stories) 0.91 h gap-inclusive (gap 0.17 h), token-equivalent $32.5 (API $32.5), 71.7M tokens; s319 (20 stories) 2.09 h gap-inclusive (gap 0.77 h), token-equivalent $41.3 (API $41.3), 119.2M tokens. Lead-seat local-model share of calls in this step group: s314 100%, s315 0%, s317 66%, s318 0%, s319 0%; subagent seats ran hosted models only (opus, sonnet, haiku). The step did not fall. Measured against s314+s315 with a WEAK BASELINE: 9 stories, s314's lead seat 100% local. Bracket: token-equivalent before reads $29.0 at the sonnet FALLBACK and $32.2 at the opus observed predecessor; every after-sprint figure is above both ends, so the pricing choice cannot decide this entry.

verify: manual

## BL-398 — a strategy case letter is not bound to a test until sprint-review, and a re-point story lists its consumers from memory

**DEFECT (efficiency).** Closed in 0.674.0 on a tree receipt, reopened by BL-817. Its decision rule is the step-value ruling, "A step with no measured value goes" (`.claude/rules/operator-rulings.md`).

**DEFECT.** Filed by the consumer as PC-S315-STORIES-TEST-STRATEGY-CASE-LETTERS-AND-RE-POINT-CONSUMERS-ARE-NOT-BOUND-TO-A-TEST-AT-AUTHORING.

**Claims, enumerated.** (1) Nothing at authoring or story close resolves a strategy case letter
to a test name: planned case `(g)` of `1.4-UNIT-002` had no test until sprint-review. (2) Nothing
requires a re-point story to enumerate every consumer of the constant by `git grep`, with a
control. The filing's instance is one constant left un-normalized for a sprint.

**Premise, re-derived at `origin/main` 144c41b8.** `stories-test-strategy.md` names no strategy case
letters. Its one `lowercase letter` hit, line 156, is the AC-ordinal grammar (control:
`Test Strategy` occurs 4 times). Check 21 resolved "every test the strategy names" against "a Dev Agent
Record" citation with no prescribed shape. A DAR prose mention therefore counted, and a lettered
case inside one strategy row was never its own unit. **Measured on the consumer, read-only:**
S315's strategy row for `1.4-UNIT-002` lists cases (a) to (g). The story's Check 21 repair section
maps 6 of the 7 to nodes in `server/tests/test_s315_4_base_binding.py` and states (g) has none. A
per-letter check over that population returns 6 resolved and 1 unresolved: the true (g), with 0
false positives. **N=1 strategy row**, so the zero is a floor, not a rate. That figure was taken
over the repair section's PROSE mapping, and it scores the per-letter resolution logic only. The
shipped Check 21 wording does not accept that prose as a citation. On S315 as it stands, with no
story carrying the table, the check FAILS on shape and never reaches the letters. The same story carries
rows no collectable node can satisfy: `1.4-OPS-001`/`-004` are deploy-time and `1.4-UNIT-005` is a
shell predicate. The table's `Kind` column exists so those rows do not fail a node check.

**Consumer overrides.** No override shadows `stories-test-strategy.md` or Check 21. The consumer
overrides `steps/gate-validation.md#Check 20` and `#Check 5` only, so this reaches the consumer on
its next pull with no re-adoption.

**The fix.** Pre-Flight item (c)'s `## Strategy Test IDs` table has one row per strategy id and
per lettered case, with `Kind` ∈ {`test`, `predicate`, `deploy-time`}. Step 5 item 3 writes the
rows and requires the strategy's letter count to equal the row count. Check 21 names that table
as its citation set and says a DAR prose mention is not a citation. It fails a letter with no row,
a `test` row whose node is not on disk, and an empty `Resolves to`, and reports a strategy with
no id table as a stated SKIP, never a PASS. **Re-point consumers:** `## Rename Verification` now
requires `git grep` of the old and new names, every hit dispositioned, with a control. This half
is prose plus fixture only, and there is no mechanical check. A re-point story's consumer set has
no machine-readable declaration to join against, so its false-positive set cannot be measured.

**Fixture.** `story-evidence-scaffold` (shared with BL-397): the per-letter binding, the closed
vocabulary, the citation set, the unrowed-letter arm, the SKIP-not-PASS arm and an unisolatable
Check 21. Each has a mutant killed by its own arm only.

**Receipt, scored.** Tip 1. Fix 0. Wrong fix A exits 1: Check 21 keeps accepting a DAR naming a
test as a citation. Wrong fix B exits 1: a table-less strategy reads PASS and Step 5 writes "rows
as needed".

Closed in 0.674.0 (verified f7eec6f5) on a tree receipt, reopened by BL-817.

Held note (batch 177): shipped the `## Strategy Test IDs` table with per-letter rows and a closed
Kind vocabulary, Step 5's binding, Check 21 reading that table with a stated SKIP, the
`## Rename Verification` git-grep enumeration, and fixture `story-evidence-scaffold`.

Former receipt (the mechanism, not the outcome): sh F=core/fixtures/story-evidence-scaffold/run.sh; [ -f core/skills/ai-dlc/steps/gate-validation.md ] && [ -f core/skills/ai-dlc/steps/stories-test-strategy.md ] || exit 9; [ -f "$F" ] || exit 1; o="$(bash "$F" 2>&1)"; [ $? -eq 2 ] && exit 9; for m in no-letter-binding open-kind dar-prose-citation letter-unchecked skip-as-pass no-check-21; do grep -qF "MUTATION '$m' killed by its own arm only" <<<"$o" || exit 1; done; grep -qx 'story-evidence-scaffold: PASS' <<<"$o"

Re-audit (BL-817): graph s314+s315 against s317, s318, s319, `docs/analysis/pipeline-efficiency-s317-s320/scripts/` (extract.py, roll.py as committed at fc71a7b10 on main; the step rows of steps.csv per story); per story, stories-test-strategy: before (s314+s315 pooled, 9 stories) 1.28 h gap-inclusive, token-equivalent $20.3 (API $17.5), 34.8M tokens (s314 token-equivalent is the FALLBACK: s315's hosted lead mix); after s317 (21 stories) 0.69 h gap-inclusive (gap 0.35 h), token-equivalent $29.4 (API $29.4), 42.6M tokens; s318 (13 stories) 1.91 h gap-inclusive (gap 1.42 h), token-equivalent $31.1 (API $31.1), 58.1M tokens; s319 (20 stories) 0.80 h gap-inclusive (gap 0.45 h), token-equivalent $26.0 (API $26.0), 44.8M tokens. Lead-seat local-model share of calls in this step group: s314 100%, s315 0%, s317 2%, s318 0%, s319 0%; subagent seats ran hosted models only (opus, sonnet, haiku). The step did not fall. Measured against s314+s315 with a WEAK BASELINE: 9 stories, s314's lead seat 100% local. Bracket: token-equivalent before reads $20.3 at the sonnet FALLBACK and $21.7 at the opus observed predecessor; every after-sprint figure is above both ends, so the pricing choice cannot decide this entry.

verify: manual

## BL-507 — a re-review after rework re-runs the full sharded fan-out instead of reviewing the fix delta

**DEFECT (efficiency).** Closed in 0.785.0 on a tree receipt, reopened by BL-817. Its decision rule is the step-value ruling, "A step with no measured value goes" (`.claude/rules/operator-rulings.md`).

**DEFECT. [efficiency rank 1] $282, 1,258 agent-minutes.** In graph s317 every code-review pass after a
NEEDS_REWORK re-ran the full gate-1 fan-out (10-13 escalated Opus/high shards) at $20-43 a pass:
story 2.6 took five passes (about $149) and 1.2 took four (about $115). In s318, from the third pass on,
the lead reviewed only the fix delta at $1-3 a pass, with the same catch quality. Nothing in core
asks for that: the s318 behaviour was the lead's own choice. Costed in the analysis as the excess of
the 11 full-fan-out re-review passes over the median delta pass ($1.70), from
`pipeline-efficiency-s317-s318/role-efficacy/impl/` (`rework-labels.tsv`).

**The fix is a delta review that is still sharded, by operator ruling.** No partition change was
needed: `partition-review-diff.sh`'s `<base>` argument already partitions the delta when it is given
the prior pass's `reviewed-sha:`. That was measured by this batch's contract on 26 real graph pass
pairs, and the probe below re-checks the mechanism on a seeded repository. Because the
partition drops the scan roots, a delta review can miss defects in the story record. For example,
s318 2.4 p2 found an Important on a DAR self-contradiction that no delta hunk touched. So the first
cross shard is briefed with the whole story record and the full prior..frozen diff. Every prior
Critical/Important is carried, and Check 1 checks the carry with `validate-carried-findings.sh`.

**Stated residual.** A delta pass does not re-find a pre-existing defect that lies outside the
delta (s317 2.6 p3, the AC9 Strategy row). Check 21(b) and BL-513's refusal catch it downstream.
**Predicted cost.** At the default threshold, s318 1-1 p3, 2-3 p3, 2-4 p2 and 2-4 p3 would still
shard, to about 10 seats each, because test-results captures count as reviewable files. The $282
filed above will therefore not fully reproduce under the sharding ruling. The saving comes from the
narrower range and the carried-finding brief, not from a single delta reviewer.

**Pre-migration.** The validator reads the review's own repository and HEAD, never where its
running copy sits, because a story is reviewed in its own worktree and checked by the main
checkout's copy. A branch whose history never added the program reads PENDING, and so does a
review committed before the earliest add. A program that sits in the checkout but was never
committed there (gitignored or untracked) binds, with a NOTE. A shallow repository is refused.
A prior is held to the `#### ` form only when it carries the template's column-0 `reviewed-sha:`
line and was not committed before the add. graph's leads persist reviews late (one snapshot
commit persisted s318 2.4 p1 and p2 together), so the commit alone cannot say a prior was written
under the rule. Any other prior has its findings carried by heading or by an id-led bold label,
and any other line in it prints a NOTE. In a held prior, lead-in prose before the first `#### `
is a NOTE, and only a bullet or a bold finding-id line there fails. A label prior is also
answered by its finding id alone, and trailing punctuation never decides a match.
`validate-carried-findings.sh --list <prior>` prints the exact carry strings, and the Gate-1
re-review brief carries them. The serial template in `code-reviewer.md` now writes `#### `
findings and a column-0 `reviewed-sha:` line.

The earlier prose receipt was closable by one sentence and is replaced by a probe. The probe runs
the validator on seeded pass pairs, including an `open` carry under NEEDS_REWORK that must pass.
It also runs a seeded worktree topology: a pre-pull story branch reads PENDING, a revert and
re-add of the program still binds, and a story spanning the pull passes. After the pull, a marked
bullet prior fails, a marked heading prior with lead-in prose passes, and a lazily persisted
unmarked prior carried by id alone passes. `--list` must print the exact carry string. It runs `--map` on a
seeded repository with the prior sha as the base (rc 0) and with the pair reversed (rc 2), and
requires the step and Check 1 text.

Closed in 0.785.0 (verified 0f7e0e0c) on a tree receipt, reopened by BL-817.

Former receipt (the mechanism, not the outcome): sh bash docs/analysis/pipeline-efficiency-s317-s318/probes/bl-507-carried-findings.sh

Re-audit (BL-817): graph s317+s318 against s319, `docs/analysis/pipeline-efficiency-s317-s320/scripts/` (extract.py, roll.py as committed at fc71a7b10 on main; the step rows of steps.csv per story); per story, implementation plus gate-validation[implementation]: before (s317+s318 pooled, 34 stories) 1.59 h gap-inclusive, token-equivalent $35.2 (API $31.8), 71.5M tokens; after s319 (20 stories) 2.09 h gap-inclusive (gap 0.77 h), token-equivalent $41.3 (API $41.3), 119.2M tokens. Lead-seat local-model share of calls in this step group: s317 66%, s318 0%, s319 0%; subagent seats ran hosted models only (opus, sonnet, haiku). The step did not fall.

verify: manual

## BL-508 — a repair pass writes the defects the next adversary pass finds

**DEFECT (efficiency).** Closed in 0.786.0 on a tree receipt, reopened by BL-817. Its decision rule is the step-value ruling, "A step with no measured value goes" (`.claude/rules/operator-rulings.md`).

**DEFECT. [efficiency rank 2] about $105 across both sprints.** In every planning series read
(carry-over, requirements, architecture) in both sprints, each MAJOR on pass 2 or 3 sat in text the
previous repair wrote or half-fixed: 19 traced, 16 read in full, one true re-find. In stories the
adversary labelled repair-introduced majors s317 p1 0/11, p2 2/9, p3 2/4 and s318 p1 16/30, p2 8/19,
p3 1/2. Typical forms: one copy fixed and its sibling left, line cites shifted, a false count written
by the repair. Costed as planning third passes that ran only because every pass-2 MAJOR was repair-made
($39 s318 + $2 s317), plus the stories repair-introduced share of later-pass adversary and
remediator spend (4/13 × $97 ≈ $30 s317, 9/21 × $80 ≈ $34 s318). The remediator's drop from
high to medium effort at the s317/s318 boundary coincides with the rise; that is confounded and is
graph's setting, not core's. Subsumes the earlier "adversary series length" finding.

Efficacy, re-read for the fix: about 10 of about 33 sampled repair-introduced MAJORs are a sibling
left unfixed or a moved cite; the rest are underived claims the existing evidence contract already
forbids. The fix reaches that third, so the $105 is not what it recovers. The fix: every `repaired`
entry with a real edit carries `- siblings:`. A files-mode shard writes a fence grepping the
replaced text over ONLY its own files (a concurrent shard fixing a copy elsewhere would turn a
wider fence stale) plus a control count of the new text, and names an out-of-shard sibling on an
unfenced `escalated` entry. A section or subject shard writes `n/a (section shard; re-checked by
the serial remediator after assembly)`, because assembly deletes the section file its control
names. An insertion-only edit writes `n/a (insertion)`, a deletion-only edit `n/a (deletion)`. The serial
remediator runs the cross-file grep over the assembled files (`s<N>/stories s<N>/epics` after a
files-mode join, never the slot, `shards/` or a record) and re-checks moved cites, after the join.
Every repaired edit owes that grep, so the join prints `SERIAL-REQUIRED: <n>` (repaired entries
with a real edit) beside `ESCALATED-COUNT`, and the procedure dispatches the serial remediator in
every mode when either is above 0. Before this it ran only for an escalation or a multi-file
finding, and in graph s318 `stories-repair-p3` and `stories-elicitation-repair-p1` no serial
remediator ran. `join-remediator-shards.sh`
refuses a missing field in every parts mode, total omission included: the era is the install,
since parts are written fresh by agents reading the installed role file. Only `--sources`, which
checks a record that may span a pull, keeps a PENDING line, binding from the record's first
carrier onward. 0 of graph's 202 s317/s318 shard parts carry the field. The arm's own awk, run
over scratch copies of them, flags 936 entries in 193 parts, with the same run's set-aside count of
1 as its control. Those parts are never re-joined, though: 20 of their 23 dirs already hold a joined record, which a join
refuses to overwrite; the other 3 belong to closed sprints; and no shipped program calls the join.
The field is read in its four forms and no other: a presence reader passed `- siblings: checked`,
and a reader keyed on the word passed any entry whose prose mentions a sibling. The fence is a
`text`-labelled one, a point-in-time record that `validate-artifact-derivations.sh` and the capture
hook never replay: as a `derived` fence its control went STALE the first time a later pass rewrote the
text it counts, and the slot-wide re-run exits 1, "send back to the remediator" (graph's s318 slot
already reads 3316 stale of 4475). The join counts the control once, in parts mode, and refuses a
fence whose text is not in the file it names.

Cost, measured by re-running the join over graph's eight files-mode s317/s318 stories repair
rounds, with a compliant `siblings:` line added to every non-escalated entry: SERIAL-REQUIRED reads
71, 185, 23, 11, 4, 31 and 24 on the seven that join (s317 elicitation, party, adversarial p1, p2;
s318 elicitation, stories p1, p2). That is 349 repaired edits whose cross-file sibling grep the
serial remediator now owes, against the earlier dispatch rule, under which s318 stories-repair-p3
and stories-elicitation-repair-p1 ran no serial remediator. The eighth round, s318 party, refuses on
the known sm-05 set-aside (BL-519), its one true positive; there are 0 false refusals.

Residue (operator ruling: BL-508 closes on the after-join cite re-check, with this recorded): the
`grep -rn -F` line's output is recorded at the edit, never checked at write time (the capture hook
replays only `derived` fences) and never re-run; whether the grepped text is
really the replaced text (the write ledger carries no old_string); a files-mode shard writing the
section-shard form skips the fence, because the four forms are not gated by mode; a `--sources`
record omitting the field everywhere reads PENDING; and a substantive mis-repair whose prose and
pin agree.

Closed in 0.786.0 (verified 4aa734c4) on a tree receipt, reopened by BL-817.

Former receipt (the mechanism, not the outcome): sh bash docs/analysis/pipeline-efficiency-s317-s318/probes/bl-508-siblings.sh

Re-audit (BL-817): graph s317+s318 against s319, s320, `docs/analysis/pipeline-efficiency-s317-s320/scripts/` (extract.py, roll.py as committed at fc71a7b10 on main; the step rows of steps.csv per story); per story, the four planning steps (carry-over-evaluation, requirements, architecture, stories-test-strategy): before (s317+s318 pooled, 34 stories) 2.31 h gap-inclusive, token-equivalent $64.1 (API $64.0), 107.1M tokens; after s319 (20 stories) 2.12 h gap-inclusive (gap 1.20 h), token-equivalent $56.4 (API $56.4), 100.9M tokens; s320 (13 stories) 5.54 h gap-inclusive (gap 4.34 h), token-equivalent $78.9 (API $78.9), 137.6M tokens. Lead-seat local-model share of calls in this step group: s317 1%, s318 0%, s319 0%, s320 0%; subagent seats ran hosted models only (opus, sonnet, haiku). The step did not fall.

verify: manual

## BL-510 — implementation rework is driven by evidence and bookkeeping, not code

**DEFECT (efficiency).** Closed in 0.787.0 on a tree receipt, reopened by BL-817. Its decision rule is the step-value ruling, "A step with no measured value goes" (`.claude/rules/operator-rulings.md`).

**DEFECT. [efficiency rank 4] $34, 131 agent-minutes after removing BL-507's overlap.** 22 of 33
implementation rework verdicts in s317-s318 were evidence (12: captures with no command or head sha,
uncommitted or gitignored RED files, a truncated capture) or bookkeeping (10: empty headings, status
not flipped, a missing Dev Agent Record line). They held under every dev binding and every reviewer
tier. This is the class BL-397 closed at v0.674.0; it recurs under 0.78x. Understated: in s318 the dev
spawn stayed alive across fix rounds, so its fix work cannot be split out. Per-verdict labels:
`docs/analysis/pipeline-efficiency-s317-s318/role-efficacy/impl/exp.py:7-26` (the `CLS` table;
the `rework-labels.tsv` this entry first cited exists nowhere).

Premise correction: the capture grammar the close condition names did not exist. dev.md prescribed
no capture header and no "head sha", and graph's captures are committed `test-results/*.txt` files
cited by path, not story fences. **PARTIAL.** Built: `core/scripts/validate-handoff-evidence.sh`,
run by implementation.md's pre-gate commit-presence check before gate 1, refuses a cited capture
in the story's range with no command line, a cited mutation-RED capture not tracked at the frozen
sha, and a glob or brace cited as a capture of which some alternative matches no tracked file; a
missing or divergent `head:` is a WARN, never a refusal. Exit 1 blocks gate-1 dispatch; exit 2 is
recorded and does not. dev.md `## QA Handoff Evidence` now prescribes the header (`$ <command>`,
`head: <sha>`, `(+dirty)` for an uncommitted tree) and committed RED captures, and
`validate-mutation-red.sh` prints `head:` and `cwd:`. Reach: about 7 of the 12 evidence (E)
verdicts and 0 of the 10 bookkeeping (B) verdicts. Measured over all 32 s317/s318 story merges:
10 refusals in 5 stories, each a capture the reviewer could not read as evidence — (a) s317 1.2
`p2-full`, `p3-full`, s317 2.2 `p2-db-passed`, s318 2.3 `ac4-pin-tests`, s318 2.5
`head-canonical-run` and the two `mutation-drop-*-full` (no command line); (b) s317 2.1
`mutation-pop`, `mutation-recorder` (gitignored REDs); (c) s317 2.2 `s317-2-2-mutation-*.txt` (a
glob over gitignored REDs, matching nothing tracked). The three other globs (s318 2.3 twice, s318
2.4 `seed{1,2,3}`) match committed files and are acquitted. Each refusal is enumerated in the
script header. The 30 head-tree WARNs were artifacts of a BSD `awk -v` abort on multi-line input
until it moved to ENVIRON; they are now computed, and stderr is empty on all 32.

Operator ruling (batch 229): ship the evidence half and keep this entry open. The receipt chains the
evidence probe to `probes/bl-510-bookkeeping.sh`, which the batch that builds the B class writes;
until it exists the receipt exits non-zero and the entry cannot rotate as closed.

Bookkeeping half (batch 230). Built: the same script, at the same pre-gate-1 call, reads the story
at the frozen sha through git and refuses `status-not-review` (the story's status is not `review`),
`status-yaml-mismatch` (it disagrees with the story's row in the IMPLEMENTATION view of
sprint-status.yaml) and `heading-demoted` (one of the four evidence headings appears only below
`## ` or only at `# `, code fences stripped). The status grammar and the row join are
`sprint-status.sh`'s, through a new `story-status --ref <sha> <story-file>` mode, so there is one
parser. A committed story with no status refuses `status-missing`, and a story file not tracked at
the frozen sha refuses `story-untracked`, because the reviewer reads the commit (both 0 over the 63
gate-1 snapshots below). An absence the row arm cannot decide (no yaml, no row) prints a
`SKIP STATUS (<reason>)` line and does not refuse; the reason is the sibling's stderr, and the
story line is parsed even when the row half fails. Lines are read with a trailing CR stripped and
under `LC_ALL=C`, and the story and yaml are decoded with replacement, so a CRLF story or one
non-UTF-8 byte cannot turn an arm into a silent pass. The heading grammar is one awk function shared
with strategy mode; `## Rename Verification (dev)` is that heading at level 2 in both.

Covered shapes, at gate 1: s317 4.3a CR p1 (status `in-progress`) and s318 1.5 CR p1 (three
headings at `###`), 2 of the 10 B labels. s317 4.2a also: its status read `ready-for-dev` in the
story and both yaml views at an APPROVED gate-1 sha, and its QA validation
(`docs/reviews/s317/4-2a-qa-validation.md:57` in graph) records the lead flipping the sprint-branch
copy instead. The arm refuses that pass. 6 of the 10 B labels are at QA, not gate 1.

Uncovered shapes. The Dev Agent Record: `dev.md:166` requires it before submission, while
`implementation.md`'s DAR-fold preflight (gate-2 dispatch) folds it into the story AFTER gate 1
approves. s317 2.7 and 4.2a were APPROVED without one. The two contradict each other; reconciling
them is a flow change and not in this release. Empty evidence headings: no arm (operator ruling,
batch 230). Three B labels match no shape here: s317 2.6 QA p1 (the dev edited another story's
artifacts), s318 1.5 QA p1 (stale derived fences) and s318 2.6 CR p3 (a recipe anchor line).

False-positive set, by population. Graph, a read-only clone at 2b6f952e7. Gate 1: every s317/s318
code-review pass with a `reviewed-sha:` (56; the contract counted 49) plus, for the 7 that record
none (s317 1-4, 1-6, 2-2 twice, 3-2, 4-2b, 4-3b), the first story-branch commit reading `review`:
63 snapshots over 34 story files. 3 bookkeeping refusals, 0 false positives, as named above. The
evidence arms refuse 6 more there, all in the 0.783.0 class (a RED capture the reviewer could not
read): s317 2.1 p1 and 2.3 p2 (APPROVED), the s317 2.2 proxy twice (APPROVED), s317 2.3 p1 and s318
1.1 p1 (NEEDS_REWORK); 2.3 and 1.1 p1 are new to this population because their REDs were committed
only after gate 1. 0 level-1 evidence
headings (control: 63 `# Story` headings). Arm 2 refuses 0. The same run with the PLANNING view
refuses 8 passes (s317 1.2 four times, 2.2 twice, s318 2.1 and 2.6), 2 of them APPROVED gates. The
story-merge tips (35 merge second-parents over 34 stories, re-derived; the 0.783.0 header says 32):
base and tip scripts print identical evidence and strategy refusals; the only
new lines are 19 `status-not-review` on tips that read `done`, which is post-gate state.

Gate 2, not added. At each QA go-signal sha (44 of 45 validation files; s317 4-2b records none) the
bookkeeping arms refuse 3: s317 4.2a QA p1 (`ready-for-dev`, a true positive) and 4.2a QA p2 and
p3 (`status-yaml-mismatch`, story `review`, story-branch row `ready-for-dev`). p3 PASSED, and p2
records the status finding closed: by then the lead keeps the canonical row on the sprint branch,
so the story branch's copy lags. Those two are false positives. The contract's condition was a
false-positive set of 0, so there is no second invocation at gate 2.

Narrowing. Merge tips were the first population and are wrong for it: 19 of 35 read `done`. The
planning view was the first row source and lags at three APPROVED gate-1 shas. A missing Dev Agent
Record was an arm and was dropped because core's own flow puts it after gate 1. The trailing-text
heading counts as level 2; read as absent it would hide `(dev)` headings.

Closed in 0.787.0 (verified 2dc7b58d) on a tree receipt, reopened by BL-817.

Former receipt (the mechanism, not the outcome): sh bash docs/analysis/pipeline-efficiency-s317-s318/probes/bl-510-handoff-evidence.sh && bash docs/analysis/pipeline-efficiency-s317-s318/probes/bl-510-bookkeeping.sh

Re-audit (BL-817): graph s317+s318 against s319, `docs/analysis/pipeline-efficiency-s317-s320/scripts/` (extract.py, roll.py as committed at fc71a7b10 on main; the step rows of steps.csv per story); per story, implementation plus gate-validation[implementation]: before (s317+s318 pooled, 34 stories) 1.59 h gap-inclusive, token-equivalent $35.2 (API $31.8), 71.5M tokens; after s319 (20 stories) 2.09 h gap-inclusive (gap 0.77 h), token-equivalent $41.3 (API $41.3), 119.2M tokens. Lead-seat local-model share of calls in this step group: s317 66%, s318 0%, s319 0%; subagent seats ran hosted models only (opus, sonnet, haiku). The step did not fall.

verify: manual

## BL-512 — gate passes are discarded for lead paperwork, most often a Check 22 waiver

**DEFECT (efficiency).** Closed in 0.784.0 on a tree receipt, reopened by BL-817. Its decision rule is the step-value ruling, "A step with no measured value goes" (`.claude/rules/operator-rulings.md`).

**DEFECT. [efficiency rank 6] $16, 132 adjudicator-minutes.** Seven gate nonces were discarded for
lead-caused reasons across both sprints, 3 of them the same Check 22 waiver with no Rule 28
exception, under both the Sonnet and the local qwen lead at about 0.08 per active hour. Check 22
fired correctly each time; the waste is the discarded pass, not an escape. Two further discards
(Check 1 verdict form, Check 5 drift) are inferred, not stated as lead error.

The count did not reproduce as stated. Re-derived from graph's lead transcripts, the measured Check 22
discards are three nonces: s317 `implementation-20261010T230257Z` (a tier-pin waiver naming "82 dev
and 42 code-reviewer rows" and no spawn), and s317 `124524Z` and s318 `011534Z` (waivers naming
every `invalid-exception` spawn and citing no Rule 28 exception, or only "the four"). All four lead
`OVERRIDDEN` writes in s317-s318 were Bash `cat >> … <<EOF` appends, so no Edit/Write matcher sees
them. The check runs at dispatch: `ai-dlc-dispatch-guard.sh` refuses an implementation-gate
`gate-adjudicator` dispatch (Check 22 is in that manifest row only) when a current-sprint `OVERRIDDEN`
entry that dispositions Check 22 names no spawn of the sprint (catches 230257Z), or when a shardable
`invalid-exception` ledger row is not named by an `OVERRIDDEN` entry that remediates it as Check 22
clearing arm 4 accepts, by a sharded re-dispatch or a cited exception (1)-(4) (catches 124524Z and
011534Z). The Remediation field is assembled across graph's wrapped continuation lines before it is
read, and a negation counts only in the clause before the `re-dispatch` claim (or before a cited
exception), so "re-dispatched sharded, not serially" covers and "exception (3) does not apply" does
not. A refused dispatch writes no spawn-ledger row. Over graph's pending-archive.md + pending.md,
S298-S318, clause 1 denies nothing, and clause 2 denies only S316/S317 rows that arm S3 fails under
the 0.783.0 validator, which counts party seats as shardable (`party_seats`). Graph ran S317 under a
validator with no `party_seats`, so a party-seat `invalid-exception` row passed Check 22 there and is
denied here (the tea row `toolu_012cdPrfgjVUGRG1X3sAcT1g`, measured). Corrected at the batch-230 close:
the guard judges only the snapshot's current `sprint_id`, so a prior sprint's rows never refuse a later
sprint's adjudicator. What refuses one after the pull is the current sprint's own shardable
`invalid-exception` rows with no remediation (graph: 3, 11 and 3 in S316, S317 and S318); the waiver
shape is action 7 of `docs/plans/graph-pull-0781-to-0787.md`. The tip
adversary's replay over graph's S317 nonces: 20 denied, 19 of them recorded as Check 22 PASSED
under graph's own validator.

Closed in 0.784.0 (verified d4880724) on a tree receipt, reopened by BL-817.

Former receipt (the mechanism, not the outcome): sh bash docs/analysis/pipeline-efficiency-s317-s318/probes/bl-512-adjudicator-dispatch-waiver.sh

Re-audit (BL-817): graph s317+s318 against s319, s320, `docs/analysis/pipeline-efficiency-s317-s320/scripts/` (extract.py, roll.py as committed at fc71a7b10 on main; the step rows of steps.csv per story); per story, every gate-validation step: before (s317+s318 pooled, 34 stories) 0.86 h gap-inclusive, token-equivalent $12.2 (API $11.0), 27.5M tokens; after s319 (20 stories) 0.87 h gap-inclusive (gap 0.34 h), token-equivalent $17.9 (API $17.9), 47.0M tokens; s320 (13 stories) 0.05 h gap-inclusive (gap 0.00 h), token-equivalent $1.2 (API $1.2), 3.4M tokens. Lead-seat local-model share of calls in this step group: s317 57%, s318 0%, s319 0%, s320 0%; subagent seats ran hosted models only (opus, sonnet, haiku). The step did not fall. s320 is partial (through stories), so its gate figure covers the planning gates only.

verify: manual

## BL-514 — subagents poll with bare `sleep`, and no guard sees a subagent's wait

**DEFECT (efficiency).** Closed in 0.782.0 on a tree receipt, reopened by BL-817. Its decision rule is the step-value ruling, "A step with no measured value goes" (`.claude/rules/operator-rulings.md`).

**DEFECT. [efficiency rank 8] 5.4-12.4 h of subagent wall clock.** 228 subagent Bash calls whose first
token is `sleep` ran 12.4 h, about 196 s each; the narrow count (commands beginning `sleep`, `until`
or `while`) is 125 calls, 5.4 h, mostly qa and code-reviewer. `ai-dlc-foreground-budget.sh` exempts
any call carrying an `agent_id` by design, and `validate-steering-budget.sh` drops `isSidechain`
records, so neither can see it. Measured: a lead call with `timeout: 900000` is denied, a subagent's
`sleep 200` with the same timeout is not.

Premise corrected on re-measurement: the 228 first-token `sleep` calls / 12.4 h do not reproduce.
There are 80 first-word subagent sleeps (57 refused by the harness, 23 ran, 0.03 h). The cost is
foreground sleeping LOOPS, usually behind a prefix such as `S=/x;` or `cd x &&`, so the arm matches
a sleeping loop or a `sleep` of 30 s or more at any command position. Replaying graph's subagent
Bash calls through the fixed hook (budget 120 s) denies 198: 152 loops and 46 long sleeps, 17.0 h of
tool_use-to-tool_result wall clock.

Closed in 0.782.0 (verified 6fe903b6) on a tree receipt, reopened by BL-817.

Former receipt (the mechanism, not the outcome): sh bash docs/analysis/pipeline-efficiency-s317-s318/probes/bl-514-subagent-poll.sh

Re-audit (BL-817): graph s317+s318 against s319, s320, `docs/analysis/pipeline-efficiency-s317-s320/scripts/` (extract.py, roll.py as committed at fc71a7b10 on main; the step rows of steps.csv per story); per story, the whole pipeline bucket: before (s317+s318 pooled, 34 stories) 5.52 h gap-inclusive, token-equivalent $119.9 (API $114.5), 228.3M tokens; after s319 (20 stories) 5.50 h gap-inclusive (gap 2.76 h), token-equivalent $111.7 (API $111.7), 255.3M tokens; s320 (13 stories) 5.79 h gap-inclusive (gap 4.50 h), token-equivalent $80.6 (API $80.6), 142.6M tokens. Lead-seat local-model share of calls in this step group: s317 44%, s318 0%, s319 0%, s320 0%; subagent seats ran hosted models only (opus, sonnet, haiku). The step did not fall. The subject (bare `sleep` polls) has no step of its own; the whole-pipeline figure is stated as the population it would move.

verify: manual

## BL-541 — the serial remediator's join is a beat on a record that already exists and is appended to, so it returns on every append and never on completion

Closed in 0.828.0 on a tree receipt, reopened by BL-817. Its decision rule is the step-value ruling, "A step with no measured value goes" (`.claude/rules/operator-rulings.md`).

Closed in 0.828.0 (verified a777c5b4) on a tree receipt, reopened by BL-817. The lease-race half: the beat takes `.beat-inflight` and its EXIT trap directly after the state-dir mkdir, before `--dispatch` resolution, so a beat blocked on the spawn ledger is seen by the stop hook (section 20; receipt below).

**PARTIAL (v0.796.0, verified e3073787; v0.815.0, verified a88f88d4) — the completion signal and its join step shipped; the stop-hook lease-race trace is OPEN.** `_gate-procedures.md` joins the serial and unsharded remediator with `wait-for-deliverable.sh --complete-repair --dispatch <agentId>`, and the auto-handoff and `handoff.md` step 1 split a mixed in-flight set into plain, `--complete` and `--complete-repair` calls. The second subject, whether `ai-dlc-continue.sh`'s `beat_lease_live` misreads a lease a just-returned beat rewrote, is untraced.

**PARTIAL (v0.794.0, verified 8aab009d) — the prose half shipped.** remediator.md: the serial remediator, and the one unsharded remediator, end the record with `repair-complete: serial <pass>` at column 0; a part or shard remediator writes no such line.

**DEFECT (efficiency).** `_gate-procedures.md:975` joins a repair with `scripts/ai-dlc/wait-for-deliverable.sh <repair_record_path>`. For the serial cross-section or cross-part remediator, that path is the JOINED record, which exists before the dispatch, and the remediator APPENDS its entries to it (`:940-942`). The plain predicate, "non-empty and written since the join armed", is therefore met by the first append and by every one after it. `--complete` cannot help: it keys on a last line beginning `seat-complete:`, and a repair record carries none (`wait-for-deliverable.sh:254-312`). So nothing distinguishes a serial remediator that has finished from one that has written one entry.

Measured in graph s319 lead session `62eadbbe-59c3-436d-bf7c-931ebc09ecba`, 23:54Z to 00:04Z: 21 `wait-for-deliverable.sh` invocations on `s319/requirements-party-repair.md` and two lead-made sentinel files. 9 were plain `--since <ts>`, 6 used `--reset --since`, and two waited on sentinels the remediator would never write, so they could only time out. Each return woke a ~300K-token lead turn (BL-538). The lead diagnosed it itself ("each beat returns as soon as the remediator writes again") but had no correct form to arm.

The stop hook also fired "NO LIVE WAIT-BEAT IS ARMED" at 00:00:49Z, seconds after the lead armed beat `bcd634p7x`. That repeats 23:13:02Z, when the lead read `.beat-inflight` five seconds later as holding a future epoch. Both are consistent with `ai-dlc-continue.sh`'s lease test (`beat_lease_live`, around `:290`) misreading a lease a just-returned beat rewrote. Neither is proven, because the marker may have cleared between the hook and the read.

Owed: a completion signal the serial remediator writes last (a terminal line in its appended block that the beat can key on, as `seat-complete:` does for seats), and a step that tells the lead to arm `--complete`-style on it; or a join on the agent's own completion notification instead of a file. Separately, trace whether the stop hook's lease read can race a beat's own marker rewrite.

Former receipt (the mechanism, not the outcome): sh S=core/scripts/wait-for-deliverable.sh; [ -f "$S" ] || S=scripts/ai-dlc/wait-for-deliverable.sh; [ -f "$S" ] || exit 9; S="$(pwd -P)/$S"; command -v mkfifo >/dev/null || exit 9; d="$(mktemp -d)" || exit 9; mkdir -p "$d/_bmad-output" || exit 9; mkfifo "$d/_bmad-output/spawn-ledger.jsonl" || exit 9; row="$(printf '{"v":1,"ts":"%s","name":"r","tool_use_id":"toolu_R541"}' "$(date -u -r $(( $(date +%s) - 30 )) +%Y-%m-%dT%H:%M:%SZ)")"; ( exec 3> "$d/_bmad-output/spawn-ledger.jsonl"; : > "$d/reached"; while [ ! -e "$d/release" ]; do sleep 0.1; done; printf '%s\n' "$row" >&3 ) & h=$!; ( cd "$d" && exec env -u CLAUDE_CODE_SESSION_ID AI_DLC_STATE_DIR= AI_DLC_TEAMMATE_DIR=/nonexistent AI_DLC_PROJECT_ROOT="$d" AI_DLC_WAIT_BEAT_SECS=2 AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_MARGIN_SECS=1 bash "$S" --dispatch toolu_R541 x.md ) > "$d/o" 2>&1 & b=$!; n=0; while [ ! -e "$d/reached" ] && [ "$n" -lt 300 ]; do sleep 0.1; n=$((n+1)); done; [ -e "$d/reached" ] || { kill "$b" "$h" 2>/dev/null; exit 9; }; m="$(cat "$d/_bmad-output/.beat-inflight" 2>/dev/null)"; : > "$d/release"; wait "$h"; wait "$b"; grep -q '^WAITING   x.md' "$d/o" || exit 9; [ "${m#* }" = "$b" ]

Re-audit (BL-817): graph s319 against s320, `docs/analysis/pipeline-efficiency-s317-s320/scripts/` (extract.py, roll.py as committed at fc71a7b10 on main; the step rows of steps.csv per story); per story, the four planning steps (carry-over-evaluation, requirements, architecture, stories-test-strategy): before (s319 pooled, 20 stories) 2.12 h gap-inclusive, token-equivalent $56.4 (API $56.4), 100.9M tokens; after s320 (13 stories) 5.54 h gap-inclusive (gap 4.34 h), token-equivalent $78.9 (API $78.9), 137.6M tokens. Lead-seat local-model share of calls in this step group: s319 0%, s320 0%; subagent seats ran hosted models only (opus, sonnet, haiku). The step did not fall.

verify: manual

## BL-543 — the serial remediator discovers its sibling and moved-cite worklist by hand, making it the longest single wait in the planning steps

Closed in 0.815.0 on a tree receipt, reopened by BL-817. Its decision rule is the step-value ruling, "A step with no measured value goes" (`.claude/rules/operator-rulings.md`).

Closed in 0.815.0 (verified a88f88d4) on a tree receipt, reopened by BL-817. `core/scripts/serial-remediation-worklist.sh` derives the serial remediator's replaced-text HITs and MOVED-CITEs from the pre-repair copies the splitters now keep (`sections/.before`, `.before/<stem>`), and removes each copy it resolved unless `--keep` is passed. A file with no copy is UNASSESSABLE, exit 3. The sections and subject repair dispatch runs it once after the join and before the serial dispatch, and the remediator adjudicates its hits instead of deriving them. Fixture `serial-remediation-worklist`.

**DEFECT (efficiency).** In s319 carry-over-evaluation (2.8 h), the two serial cross-section remediators took 42 min (party repair, 19:54–20:36Z) and 29 min (elicitation repair, 20:53–21:22Z), about 42% of the step. Every parallel fan-out in the same step finished in 5–15 min. In requirements, the serial cross-part remediator ran 52 min (23:11Z–00:04Z). Most of that work is mechanical. For every `repaired` entry it runs `grep -rn -F '<replaced text>'` over the assembled files, and it re-reads every cite into an edited file (`_gate-procedures.md:991-1002`). BL-508 (v0.786.0) made the serial remediator run whenever `SERIAL-REQUIRED` is above 0, so this cost now lands on every sharded repair. Owed: the join emits that worklist itself, meaning each repaired entry's replaced text with its grep hits over the assembled files, and each cite into an edited file whose line moved. The serial remediator is then briefed to adjudicate the hits rather than find them. Measure by re-timing the serial remediator on the next consumer sprint.

**Fourth timing (graph s319 requirements elicitation repair).** The serial cross-part remediator ran 31 min, 01:19:04Z to 01:50:12Z. It spent 14 min reading before its first write at 01:33:02Z, then made 28 record appends and 48 subject edits (prd.md 28, architecture-impact.md 8, product-brief.md 8, .memlog.md 4) for 20 repaired, 5 escalated and 1 skipped. That makes four serial passes in one sprint, at 42, 29, 52 and 31 min, every one longer than the parallel fan-out it follows.

Former receipt (the mechanism, not the outcome): manual

Re-audit (BL-817): graph s319 against s320, `docs/analysis/pipeline-efficiency-s317-s320/scripts/` (extract.py, roll.py as committed at fc71a7b10 on main; the step rows of steps.csv per story); per story, the four planning steps (carry-over-evaluation, requirements, architecture, stories-test-strategy): before (s319 pooled, 20 stories) 2.12 h gap-inclusive, token-equivalent $56.4 (API $56.4), 100.9M tokens; after s320 (13 stories) 5.54 h gap-inclusive (gap 4.34 h), token-equivalent $78.9 (API $78.9), 137.6M tokens. Lead-seat local-model share of calls in this step group: s319 0%, s320 0%; subagent seats ran hosted models only (opus, sonnet, haiku). The step did not fall.

verify: manual

## BL-550 — party seats grep for files that do not exist, because nothing gives them the repository's real paths

Closed in 0.794.0 on a tree receipt, reopened by BL-817. Its decision rule is the step-value ruling, "A step with no measured value goes" (`.claude/rules/operator-rulings.md`).

Closed in 0.794.0 (verified 8aab009d) on a tree receipt, reopened by BL-817. The party-seat section of architect, dev, pm and tea (byte-identical across the four, I124) tells a seat to list a code path with `git ls-files <dir-or-glob>` before reading it, and that a grep which errored searched nothing.

**DEFECT (efficiency).** Across 134 s319 party and elicitation seat transcripts there are 105 "No such file or directory" lines. Seats guessed paths such as `rebalancer/db.py`, `rebalancer/state_store.py`, `server/main.py`, `rebalancer/config_schema.py`, `infra/lib/ecs-stack.ts` and `rebalancer/execution_log.py`, none of which exist and none of which the subject files cite (`grep -l -F` over the PRD, SPEC, brief and `architecture-impact.md` returns 0 for each, against 3 for the control `rebalancer/execution.py`). Each miss is a tool round trip and a guess that can be filled in with an invented answer. Owed: the seat brief carries the subject's cited code paths (derivable from the subject files) and an instruction to resolve any other path with `git ls-files` before reading it.

**Second instance, the adversarial round (graph s319 resumed lead `f65eae3b`, requirements-adversarial-p1, 2026-10-16).** Filed by peer session ai-dlc-68. Seven parts (1, 2, 6, 8, 13, cross-3 and cross-6) made 13 greps for nonexistent paths: `dashboard/`, `extensions/`, `shared/`, `shared/tokens.py`, `aggregator/`, `rebalancer/config_schema.py`, `rebalancer/config.example.json`, `rebalancer/tests/test_s318_subscribe_pin.py`, `test_s245_subscribe_pin.py`, `web/src/pages/Dashboard.jsx|tsx` and `web/src/hooks`. Three more greps died on `ugrep` limits: "exceeds complexity limits" on `.{0,80}` and `[^.]{0,140}` (parts 12 and cross-6), and "empty (sub)expression" on `\b` inside an alternation (cross-5). The brief owed above should also state a pattern form that `ugrep` accepts.

Former receipt (the mechanism, not the outcome): sh for r in architect dev pm tea; do s=$(LC_ALL=C awk "/^## As a party seat/{g=1} g&&/^## /&&!/party seat/{exit} g" "core/team-roles/$r.md"); case "$s" in *"list it first with \`git ls-files <dir-or-glob>\`"*) ;; *) exit 1;; esac; done

Re-audit (BL-817): graph s319 against s320, `docs/analysis/pipeline-efficiency-s317-s320/scripts/` (extract.py, roll.py as committed at fc71a7b10 on main; the step rows of steps.csv per story); per story, the four planning steps (carry-over-evaluation, requirements, architecture, stories-test-strategy): before (s319 pooled, 20 stories) 2.12 h gap-inclusive, token-equivalent $56.4 (API $56.4), 100.9M tokens; after s320 (13 stories) 5.54 h gap-inclusive (gap 4.34 h), token-equivalent $78.9 (API $78.9), 137.6M tokens. Lead-seat local-model share of calls in this step group: s319 0%, s320 0%; subagent seats ran hosted models only (opus, sonnet, haiku). The step did not fall.

verify: manual

## BL-552 — the lead posts a status line for every finished seat even with a join covering the round

Closed in 0.794.0 on a tree receipt, reopened by BL-817. Its decision rule is the step-value ruling, "A step with no measured value goes" (`.claude/rules/operator-rulings.md`).

Closed in 0.794.0 (verified 8aab009d) on a tree receipt, reopened by BL-817. rule-28: a notification for an agent whose deliverable a live beat covers gets no status line and no re-check; a `--complete` round is reported once, from the merge. A failed agent and a held rejected set are carved out.

**DEFECT (efficiency).** Distinct from BL-538 (the wake itself): even when the lead does take a turn, the step files give it nothing to do with "seat N delivered" except narrate it. In the s319 party round (36 seats) and elicitation round (19 shards), almost every arrival produced a lead message of the form "<seat> delivered (n findings). The join beat is still armed …". The text carries per-seat finding counts that the merge recomputes anyway. Owed: the step files say a notification for an agent inside an armed `--complete` join gets no per-agent summary; the lead ends the turn, and reports the round once from the merge.

Former receipt (the mechanism, not the outcome): sh f=core/skills/ai-dlc/rule-bodies/rule-28.md; t=$(tr "\n" " " < "$f"); case "$t" in *"Two notifications are not covered. One whose status is failed"*) ;; *) exit 1;; esac; case "$t" in *"post no status line for the agent"*) ;; *) exit 1;; esac

Re-audit (BL-817): graph s319 against s320, `docs/analysis/pipeline-efficiency-s317-s320/scripts/` (extract.py, roll.py as committed at fc71a7b10 on main; the step rows of steps.csv per story); per story, the four planning steps (carry-over-evaluation, requirements, architecture, stories-test-strategy): before (s319 pooled, 20 stories) 2.12 h gap-inclusive, token-equivalent $56.4 (API $56.4), 100.9M tokens; after s320 (13 stories) 5.54 h gap-inclusive (gap 4.34 h), token-equivalent $78.9 (API $78.9), 137.6M tokens. Lead-seat local-model share of calls in this step group: s319 0%, s320 0%; subagent seats ran hosted models only (opus, sonnet, haiku). The step did not fall.

verify: manual

## BL-615 — adversary seats and shards are never told to resolve a code path with `git ls-files`, so BL-550's second instance is uncovered

Closed in 0.827.0 on a tree receipt, reopened by BL-817. Its decision rule is the step-value ruling, "A step with no measured value goes" (`.claude/rules/operator-rulings.md`).

Closed in 0.827.0 (verified 04adbf68) on a tree receipt, reopened by BL-817. `team-roles/adversary.md` gains a contract item: before reading or grepping a code path its brief does not cite, the adversary lists it with `git ls-files <dir-or-glob>` and reads only what that returns. The wording is adversary-specific, outside the I123-bound adjacency, and opens no "As a party seat" heading (I124 still passes on architect, dev, pm and tea). Pinned by the `process-rule-pins` R row `adv-ls-files`.

**DEFECT (efficiency).** Filed by peer session ai-dlc-c9 at lead ai-dlc-9c's direction, out of c9's release (a), where it was item A6 and was taken out because BL-550 is closed and A6 would have closed nothing. Intake re-derived it read-only at origin/main `86d3a695`.

BL-550 is archived LANDED (v0.794.0, verified `2f6d5199`) on its role-file half: the party-seat section of `architect`, `dev`, `pm` and `tea`, byte-identical across the four under I124, tells a seat to list a code path with `git ls-files <dir-or-glob>` before reading it. Its receipt loops over `architect dev pm tea` only. The archived entry also records a **second instance, in the adversarial round** (graph s319 resumed lead `f65eae3b`, requirements-adversarial-p1): seven parts (1, 2, 6, 8, 13, cross-3 and cross-6) made 13 greps for paths that do not exist, such as `dashboard/`, `shared/tokens.py` and `rebalancer/config_schema.py`.

Those shards run the `adversary` role. `_gate-procedures.md:413`, `:422`, `:444`, `:585` and `:609` dispatch "one `adversary` per story ordinal", "one `adversary` per part plus one cross-part `adversary`", and so on. The adversary side has no instruction:
- `git ls-files` counts over `core/team-roles/*.md`: `adversary.md` 0, against `dev` 2 and `architect`, `pm` and `tea` 1 each (the control).
- `_gate-procedures.md` has 0 mentions of `ls-files` (control: 28 mentions of `adversary`).
- `adversary.md` (552 lines, 9 `##` headings) never says "code path" and has no `## As a party seat` section.

So the LANDED close never reached the role that produced the second instance. The open backlog does not cover it either (0 `ls-files` mentions).

Constraint on the fix: I124 (`scripts/validate-enforcement-map.sh:13573`, `i124_names='architect dev pm tea'`) binds the party-seat section to exactly those four roles. Its half B fails the push on any other role file carrying a heading opening "As a party seat". The instruction therefore cannot reach `adversary.md` by copying that section. It needs its own text in `adversary.md`, or in the shard brief `_gate-procedures.md` dispatches, or I124's list must widen deliberately. The I123 chunking paragraph is the other binding a role-file edit has to respect.

Rejected at contract time: release (a)'s A6 candidate derived a `code paths:` block for the brief with a hand-written regex in prose (`git ls-files | grep -F -x -f <(grep -ohE '[A-Za-z0-9_./-]+\.[a-z]{1,4}' …)`). The contract adversary flagged it as verification-discipline's hand-regex class (a second implementation of a path grammar). Whether the fix is prose or a mechanism is this entry's decision.

Owed:
1. Decide prose (an `adversary.md` or shard-brief instruction) or a mechanism (a path list derived by shipping code, not a prose regex), and record why.
2. Receipt: run the shipping code, not a grep of the role file. For example, a shard brief rendered for a subject naming a non-existent path shows the resolved/absent split; or, for prose, a receipt over the dispatched brief and not over BL-550's four files. Control: the four party-seat roles still pass I124.

Related: BL-550 (archived; both instances), I124, I123.

Former receipt (the mechanism, not the outcome): sh t="$(awk '/^## Constraints/{p=1;next} p&&/^## /{exit} p' core/team-roles/adversary.md | tr '\n' ' ' | tr -s ' ')"; [ -n "$t" ] || exit 9; grep -qE 'path[^.]*(does not|do not|never|neither)[^.]*cite' <<<"$t" && grep -qE 'git ls-files <[^>]+>`[^.]*read only what' <<<"$t" && ! grep -qE '^#+ As a party seat' core/team-roles/adversary.md && bash scripts/validate-enforcement-map.sh --arms I123,I124 >/dev/null 2>&1

Re-audit (BL-817): graph s319 against s320, `docs/analysis/pipeline-efficiency-s317-s320/scripts/` (extract.py, roll.py as committed at fc71a7b10 on main; the step rows of steps.csv per story); per story, the four planning steps (carry-over-evaluation, requirements, architecture, stories-test-strategy): before (s319 pooled, 20 stories) 2.12 h gap-inclusive, token-equivalent $56.4 (API $56.4), 100.9M tokens; after s320 (13 stories) 5.54 h gap-inclusive (gap 4.34 h), token-equivalent $78.9 (API $78.9), 137.6M tokens. Lead-seat local-model share of calls in this step group: s319 0%, s320 0%; subagent seats ran hosted models only (opus, sonnet, haiku). The step did not fall.

verify: manual

## BL-679 — one consumer pull re-runs `emit-report.sh --verify` three or four times, each a full detector re-render, and no caller accepts an earlier PASS

**LANDED (v0.962.0, verified 8fd3bb945).** RETIRED, not fixed: the recorded `--verify` PASS cache (its key, read log, `ai-dlc-verify-pass` record, refusals and opt-in) is deleted and `--verify` always re-renders, because the cache never formed on graph's shared dist (BL-685), it shipped off by default, graph never set it, and under the operator's step-value ruling a step with no measured value goes. The re-render cost itself moves to the fixture side under BL-850. Closed in 0.834.0 on a tree receipt, reopened by BL-817. Its decision rule is the step-value ruling, "A step with no measured value goes" (`.claude/rules/operator-rulings.md`).

Closed in 0.834.0 (verified d4281b59) on a tree receipt, reopened by BL-817. `emit-report.sh --verify` records an exit-0 PASS in the consumer's git-dir, and accepts a matching one only with `EMIT_REPORT_VERIFY_CACHE=1`. It ships off by default, and with that unset every `--verify` is byte-identical to the previous release. Exit 1 and exit 3 are never recorded. The default turns on only after a key review finds no BLOCKER (BL-685). Tests: reconcile-emit-report PC-V0..V26 and mutants M-region, M-direxcl and M-exit3; receipt below.

**DEFECT (efficiency).** In the graph pull session `f78aa565` (0.823.0 to 0.828.0), f7 measured `emit-report.sh --verify` run 3-4 times in one pull, each a full re-render of every detector at 3-14 minutes, about 35 of the pull's 116 in-session minutes. Source: f7's transcript read, not re-derived here; a transcript-only figure. Handoff gaps are excluded from the 116.

Sites, re-derived against this tree at 9ad0e21c (f7's consumer line numbers matched the distribution's exactly):
- `core/skills/ai-dlc-update/SKILL.md:1514` (the first step-7 `emit-report.sh --verify <report> <dist> <base> <consumer> <theirs>` instruction, "it MUST exit 0") and `:1720` (the second statement of the same gate, "(1) ... exits 0"). `:1748` says to run `--verify` again after pasting a freshly rendered region.
- `core/skills/ai-dlc-update/reconcile/apply.sh:259`, the union gate's own call: `bash "$SELF/emit-report.sh" --verify "$UNION_REPORT" "$DIST" "$BASE" "$CONSUMER" "$THEIRS"`.
- Inside each `--verify`, `core/skills/ai-dlc-update/reconcile/emit-report.sh:832` runs `predicate-differential.sh "$DIST" "$BASE" "$THEIRS" "$CONSUMER"`. `--verify` begins at `:67` and re-renders the whole region through `render()` (`:165`), so every caller pays every detector, this one included.

Owed: key a recorded PASS on (dist, base, theirs, consumer tree hash, region hash). A later caller in the same pull whose key matches accepts the recorded PASS instead of re-running the detectors. An edit outside the mechanical region leaves the key unchanged and so triggers no re-run; an edit inside the region, or any change to the four tree identities, changes the key and re-runs. The write is made only by a `--verify` that exited 0, and the PASS is read, not trusted from the report text. f7 estimates about 20 minutes removable per pull, which makes this the first of the pull-path costs; that estimate is f7's and is not re-measured here. Probe: a second `--verify` on an unchanged key skips the render (assert by detector invocation count, not by output), and a one-byte edit inside the region re-renders and fails. Control: an edit outside the region on the same key still accepts.

Note that `emit-report.sh` and `apply.sh` are the consumer's INSTALLED engine, so the pull that delivers this fix still runs the old re-runs.

No existing receipt shape fits: the subject is a count of detector invocations across a multi-caller pull, which needs a seeded world and a driver of the real `--verify`, and no such receipt has been written or run here (UNRUN).

Former receipt (the mechanism, not the outcome): sh f="$(mktemp)" || exit 9; bash core/fixtures/reconcile-emit-report/run.sh >"$f" 2>&1 </dev/null; [ -s "$f" ] || exit 9; grep -Eq '^ +ok +PC-V1( |$)' "$f" && grep -Eq '^ +ok +PC-V3( |$)' "$f" && grep -Eq '^ +ok +PC-V10( |$)' "$f" && grep -Eq '^ +ok +PC-V4( |$)' "$f" && grep -Eq '^ +ok +PC-V26( |$)' "$f" && ! grep -Eq '^ +FAIL +PC-V' "$f"; r=$?; rm -f "$f"; exit $r

Re-audit (BL-817): graph s319 against s320, `docs/analysis/pipeline-efficiency-s317-s320/scripts/` (extract.py, roll.py as committed at fc71a7b10 on main; the step rows of steps.csv per story); per story, the ai-dlc-update bucket (consumer pulls): before (s319 pooled, 20 stories) 1.59 h gap-inclusive, token-equivalent $8.6 (API $8.6), 22.1M tokens; after s320 (13 stories) 0.56 h gap-inclusive (gap 0.43 h), token-equivalent $2.1 (API $2.1), 4.9M tokens. Lead-seat local-model share of calls in this step group: s319 1%, s320 0%; subagent seats ran hosted models only (opus, sonnet, haiku). The step did not fall. The bucket's figure fell in s320, a partial sprint with one pull; the entry's own subject (`emit-report.sh --verify` re-runs per pull) was not counted by this re-audit, so the fall is not attributed to it.

Outcome measured: no graph pipeline step; the cost lives in core/skills/ai-dlc-update/reconcile/emit-report.sh, whose opt-in cache graph never set, so retiring it moves no pull's cost.

verify: sh f=core/skills/ai-dlc-update/reconcile/emit-report.sh; [ -f "$f" ] || exit 9; ! grep -qF "ai-dlc-verify-pass" "$f"

## BL-716 — after a parallel repair fan-out, every SERIAL-REQUIRED item goes to one serial remediator, so a 19-shard round that finishes in 8 minutes waits an hour on one agent

Closed in 0.913.0 on a tree receipt, reopened by BL-817. Its decision rule is the step-value ruling, "A step with no measured value goes" (`.claude/rules/operator-rulings.md`).

Closed in 0.913.0 (verified 5b5388924) on a tree receipt, reopened by BL-817. **DEFECT (efficiency).** Relayed by ai-dlc-5d from graph S319; dedupe re-derived on the distribution by lead ai-dlc-37; id allocated by ai-dlc-37; filed by peer session ai-dlc-c0 (batch 236), with BL-713's release.

`core/scripts/join-remediator-shards.sh:741` defines SERIAL-REQUIRED (parts mode only) as the count of `repaired` entries with a real edit, each owing the cross-file sibling grep and moved-cite check that no shard can run, and the procedure dispatches ONE serial remediator whenever that count or ESCALATED-COUNT is above 0. However many cross-part items there are, one agent works them all, in sequence.

Evidence, relayed by ai-dlc-5d and not re-measured by this filing (load 2–28, so the wall clock is an observation, not a timing): graph S319 stories, 2026-10-19. The 19 parallel shards finished in about 8 minutes (20:10–20:17 EDT); the join reported SERIAL-REQUIRED 148; the one serial agent ran 62 minutes (20:24:49–21:26:53, 172 tool calls, 77 Edit), while the lead re-armed its wait beat 7 times and ran nothing else. That is 148 items in 62 minutes, about 0.42 minutes per item, as an observation; no per-item baseline exists to compare it against.

Prior art, not a duplicate: archived **BL-543** (LANDED v0.815.0, verified a88f88d4) cut the serial remediator's DISCOVERY work — `core/scripts/serial-remediation-worklist.sh` now derives its replaced-text HITs and MOVED-CITEs from the splitters' pre-repair copies instead of the agent finding them by hand — on S319 rounds whose serial remediators took 42, 29 and 31 minutes. Those rounds recorded no SERIAL-REQUIRED counts (BL-543 records one round's 28 appends and 48 edits only), so they are not a baseline for tonight's figure and are not compared with it. BL-543 did not change the COUNT: every cross-part item still goes to the one agent, and that is what this filing owes.

Dedupe, re-derived with `grep -c` at origin/main: "SERIAL-REQUIRED" 3 in docs/backlog.archive.md and 0 in docs/backlog.md; "serial remediator" 35 in the archive, the relevant one BL-543; control BL-583 6.

Owed, the mechanism left to the builder: partition the SERIAL-REQUIRED items by the parts they touch, so disjoint sets run as parallel serial lanes and each lane keeps the serial guarantee within its own set. A fixture arm (or receipt): a seeded join whose two disjoint item sets dispatch to two lanes, while an overlapping pair stays in one lane.

Measured input for the partition, graph-watch, batch 238. These figures come from the graph watcher's scratch run of `core/scripts/serial-remediation-worklist.sh` over s319's stories party repair, relayed by the batch-238 lead; this filing did not re-measure them. The run's SUMMARY read `files 19 replaced 115 hits 135 moved-cites 1`, over 19 parts and 148 SERIAL-REQUIRED entries. Taking the parts each item touches as edges, the lane components are: edit only, 19; edit ∪ MOVED-CITE, 18; edit ∪ HIT, 1. One boilerplate line merges every lane: the sprint-title `architecture_refs` line that every story carries (`story-2-1:8-10`, hunk `6.md#F-9`), which HITs line 9 of 18 other stories. On this corpus, a partition on HIT edges therefore yields one lane, the status quo, unless a HIT on a line common to all parts is excluded from the edge set. The builder must decide whether such a common-line HIT can be excluded safely, or must be routed as a single fan-in item.

Built (batch 240, R2): lanes are keyed on FILES from each part's `edit:` set, joined only by MOVED-CITE edges from the worklist the join now runs after a sections or subject assembly (`--keep`); a HIT or escalation reaching two or more lanes is one FANIN item, so the common-line HIT is routed to the fan-in and never excluded. Lanes run as a second parts-mode round through the same join (`--artifact <name>-serial`), and `--escalations`/`--sources` read that round's record after round one's.

Former receipt (the mechanism, not the outcome): sh bash core/fixtures/remediator-shard-join/receipt-bl716.sh

Re-audit (BL-817): graph s319 against s320, `docs/analysis/pipeline-efficiency-s317-s320/scripts/` (extract.py, roll.py as committed at fc71a7b10 on main; the step rows of steps.csv per story); per story, stories-test-strategy: before (s319 pooled, 20 stories) 0.80 h gap-inclusive, token-equivalent $26.0 (API $26.0), 44.8M tokens; after s320 (13 stories) 0.93 h gap-inclusive (gap 0.40 h), token-equivalent $39.1 (API $39.1), 65.0M tokens. Lead-seat local-model share of calls in this step group: s319 0%, s320 0%; subagent seats ran hosted models only (opus, sonnet, haiku). The step did not fall.

verify: manual

## BL-804 — a remediator writes `derivations: not replayed` although replay is its default, and the join's refusal costs a whole re-dispatch

Closed in 0.949.0 on a tree receipt, reopened by BL-817. Its decision rule is the step-value ruling, "A step with no measured value goes" (`.claude/rules/operator-rulings.md`).

Closed in 0.949.0 (verified 94c8dcdc7) on a tree receipt, reopened by BL-817.

**DEFECT (efficiency).** Filed at the batch-242 close from the graph watch (ai-dlc-fa, poll 16, 01:07 EDT 2026-10-26). In graph s320, the `stories-party --pass 1` repair join refused at 05:05:46Z with `REFUSED: 11.md: derivations: not replayed; …` (the checks-field refusal in `core/scripts/join-remediator-shards.sh`). Part 11 is story 3.5, in `s320/shards/stories-party-repair-p1/11.md`. `core/team-roles/remediator.md:134-139` makes replay the default ("Replay is the default: run `scripts/ai-dlc/validate-artifact-derivations.sh <your record>` after your last edit"), but the remediator wrote `not replayed` anyway. Graph's lead recovered by contract: a record-only re-run (agent a0481edc5f18691e2) replayed 5 derivations and re-marked, and the re-join returned rc=0. The cost was one dispatch and about 2 minutes. One instance, measured from the transcript.

Owed: a mechanism that makes the default the act, not the instruction. For example, the `--mark` path of `wait-for-deliverable.sh` could run the replay itself when a repair record says `not replayed` and its fences name no deferred document, then write the count. That moves a refusal the join already makes to the point where the remediator can still fix it. Measure the false-positive set first: a record whose fences are legitimately deferred must not be forced.

Former receipt (the mechanism, not the outcome): sh bash core/fixtures/remediator-shard-join/receipt-bl804.sh

Re-audit (BL-817): graph s320, `docs/analysis/pipeline-efficiency-s317-s320/scripts/` (extract.py, roll.py as committed at fc71a7b10 on main; the step rows of steps.csv per story); per story, stories-test-strategy: 0.93 h gap-inclusive, token-equivalent $39.1 (API $39.1), 65.0M tokens, the baseline. No graph sprint has run 0.949.0 yet. Owed: first graph sprint on >=0.949.0. The shipped mechanism (0.949.0, `wait-for-deliverable.sh --mark` replays the derivations) stands; the reopen owes the outcome, not a rebuild.

Owed (batch b244, c4), the premise of the mechanism above corrected. The ordering was not the defect: `core/team-roles/remediator.md` orders `join-remediator-shards.sh --escalations` before `wait-for-deliverable.sh --mark-repair` on purpose, `core/skills/ai-dlc/steps/_gate-procedures.md` agrees, and graph's repair subagent (agent-a2ba43cd07934d6e7, 2026-10-27T09:01Z) followed it. Its join refused `derivations: not replayed`; it replayed, edited the line to `replayed 1`, re-joined at rc 0, and then marked. That cost about 16s inside the dispatch and no re-dispatch, so the join before the mark is the designed loop. The real defect was one sentence in `remediator.md` that said `--mark` and `--mark-repair` replay the record themselves, which offered the serial or unsharded remediator `not replayed` as an option its own earlier join refuses. Resolved: the sentence now scopes the replay to `--mark` and says the serial remediator replays before its join and writes `replayed <n>` itself, pinned in `process-rule-pins` by the `rem-serial-replay` row, a named mutant that restores the old clause, and the `rem-serial-optout` arm. The entry stays OPEN: it is decided by its receipt plus a measured outcome under BL-817, the first graph sprint on a release carrying this sentence showing no `not replayed` refusal at the join.

verify: manual

## BL-695 — a sharded stories party round waits on its slowest seat at every wave, because the lead split the round by seat and joined each seat before dispatching the next

Closed in 0.950.0 on a mechanism measurement; step cost did not fall; reopened by BL-817. Its decision rule is the step-value ruling, "A step with no measured value goes" (`.claude/rules/operator-rulings.md`).

**DEFECT (efficiency).** f7 measured, graph s319 lead sessions c61a91eb and a0701ce0, 0.830.0; transcript-only, not re-derived here: (1) in the stories-test-strategy party round, per-story seats ran a median of 5.5-6.5 min and cross seats a median of 15.5-18.3 min, with one cross seat at 43.2 min; (2) f7 estimated the pole at 40-80 min per round — an estimate, not a measurement; (3) the TEA seat ran per-story n=19, median 2.0 min, max 6.6, and cross n=6, median 17.5 min, max 35.3, about 20-29 min of pole per wave. The batch 236 WAVES adversary read the same two transcripts, read only: "Concurrent subagent limit reached" appears 0 times in either (control: 9 other graph transcripts carry it); the round went out as four waves of 25 agents, one seat each (19 per-story + 6 cross), against a probable cap of 42, so about 17 slots sat idle in every wave. From each wave's last seat to the next dispatch: Dev to Architect 35.6 min after the last per-story seat and 15.6 min after the last cross seat (beat cadence plus a 429 episode); Architect to TEA 11.8 min and 14 s; TEA ended the round on a 29.1 min pole. The cross pole in each in-session transition is the gap between its last per-story seat and its last cross seat: (35.6 - 15.6) + (11.8 - 0.2) = 20.0 + 11.6 = 31.6 min across the two. The 15.6 min of beat cadence and 429 overhead after the Dev round's last cross seat is separate from that pole. SM to Dev is excluded: it was a session handoff.

Cause: a per-seat barrier the LEAD imposed, with the cap never probed — not one the cap forced. The lead wrote "the other three seats follow once the harness cap is known from any rejections", against `rule-28.md`'s "until a rejection has shown the cap, the first wave is the whole set". Two prose sites licensed the barrier: Rule 28's Waves paragraph joined each wave "before the next wave spawns", and both Rule 28's missing-set sentence and `_gate-procedures.md`'s party-round join folded the rejected set into "the next wave". Nothing in a later wave reads a seat file, so the barrier buys nothing. This is the open measurement of BL-464 claim 7, which is the parent: the per-group cross fan-out shipped, and the pole that remains is the barrier.

Owed: the prose half lands in this release. `rule-28.md` takes the cap from `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` when the lead can read it, else from the rejection probe, never from a remembered number; sizes a wave at no less than min(remaining, cap - running); says a seat is not a wave; refills a slot on each exit; arms one beat per refill over only that refill's paths, never `--reset`; adds the undispatched-members exit as a third uncovered notification; and re-dispatches MISSING after the join and the rejected set on the first exit. `_gate-procedures.md` splits MISSING from rejected and dispatches cross members first, worded as a tendency (the earlier calls were admitted first in 52 of 63 graph messages with rejections, and not in 11). The detector is the read-only transcript-replay script `scripts/audit-party-wave-barrier.sh`, which judges a delivered exit of a round member whose response turn carries no Agent/Task dispatch for the round while RUNNING < CAP; no beat is read, and the earlier beat predicate and its narrowings are gone. Its false-positive set is measured on the graph transcripts plus c61a91eb and a0701ce0. Its remaining blind spots: (1) a ceiling below the harness cap that someone legitimately set, because the replay reads no conversation; (2) operator pause or question windows, which read as unanswered exits: two of the 13 corpus findings over 187 graph transcripts, 22e0f5c2 b30 and ea675b67 b32, sit wholly inside a Rule 29 pause and are FALSE (the other 11 are TRUE); (3) an enqueue with no delivery is never judged; (4) RUNNING undercounts when Agent records are out of the harness's order, measured up to 16 mid-wave, so an idle count of 1-3 is within that error; (5) a round re-run under the same name reads as a later batch; (6) a round's last stretch, with no later new member, is never judged; (7) with no readable cap and no `--cap`, the transcript is unjudged (UNKNOWN-CAP). A live PreToolUse WARN is not buildable, because the dispatch-guard matcher is `Agent|Task` only, so it cannot see the Bash beat, and it cannot know whether round members remain undispatched. The real close is the consumer's next stories round showing seats refilling during the cross pole.

Lead ruling: s319 (a0701ce0) was a real barrier, but the detector reads it UNKNOWN-CAP because the transcript records no cap. With `--cap 42` it fires twice (batches 2 and 3, running=24, idle=18, gaps 3348 s and 1364 s). The Rule 28 cap order, the environment variable when readable and otherwise the rejection probe, is what puts the cap into future transcripts.

Receipt: the detector run as a transcript replay, plus the prose conjuncts. It exits 9 if `scripts/audit-party-wave-barrier.sh`, `rule-28.md`, `_gate-procedures.md` or `_dispatch-protocol.md` is missing, then writes seeds (a), (b), (c) and (e) into a `mktemp` dir it leaves in place, and requires the detector to exit 0 on (b), refill on exit, and on (c), a cap-forced wave, and to exit 1 on (a), a wave held for the previous join with slots free, and on (e), the measured s319 shape: four 25-member seat waves, each fully joined, cap 42 from a `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS=42` tool_result line, three FINDINGs at idle 18. Seed (c) is what kills the free-slot test removed: without it that mutant only widens findings and the three other seeds cannot see it. The prose is read with newlines folded to spaces, since both files wrap. "A rejected spawn is undelivered" must be in `rule-28.md` (a positive control, else exit 9); "next wave carries" must be absent from `rule-28.md` and "the next wave carries" from `_gate-procedures.md`; `join each wave|wave is joined|before the next wave spawns` must be absent from both, and "Each wave is joined in ONE beat" or "wave is joined" from `_dispatch-protocol.md`; `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` and, in any case, "a seat is not a wave" must be present in `rule-28.md`. Anything else is exit 1.

**Progress (0.857.0; entry stays OPEN).** Shipped: the prose half and the detector.
- Prose: `rule-28.md`, `_gate-procedures.md` and `_dispatch-protocol.md` size a wave from the harness cap, refill it on each exit, and no longer treat a seat as a wave.
- Detector: `scripts/audit-party-wave-barrier.sh`, a read-only transcript replay, with the `party-wave-barrier` fixture.
- Corpus census, from the detector header's FINAL STATE: 13 findings over 187 graph transcripts, 11 TRUE and 2 FALSE. The two FALSE are 22e0f5c2 b30 and ea675b67 b32, both inside a Rule 29 pause window, which the replay cannot see (residual 2).
- The entry stays open until the consumer's next stories round is measured.

**The shipped-half receipt (batch 240; quoted, not installed as `verify:`).** It exits 0 on origin/main at 0.924.0, because the prose half and the detector shipped, so as the closing line it read the entry as a CLOSE-CANDIDATE while the consumer half is still owed: `D=scripts/audit-party-wave-barrier.sh; R=core/skills/ai-dlc/rule-bodies/rule-28.md; G=core/skills/ai-dlc/steps/_gate-procedures.md; P=core/skills/ai-dlc/steps/_dispatch-protocol.md; [ -f "$D" ] || exit 9; [ -f "$R" ] && [ -f "$G" ] && [ -f "$P" ] || exit 9; T="$(mktemp -d "${TMPDIR:-/tmp}/bl695.XXXXXX")" || exit 9; bash "$D" --seed a "$T/a.jsonl" --seed b "$T/b.jsonl" --seed c "$T/c.jsonl" --seed e "$T/e.jsonl" || exit 9; bash "$D" "$T/b.jsonl" >/dev/null 2>&1; rb=$?; bash "$D" "$T/c.jsonl" >/dev/null 2>&1; rc=$?; bash "$D" "$T/a.jsonl" >/dev/null 2>&1; ra=$?; bash "$D" "$T/e.jsonl" >/dev/null 2>&1; re=$?; [ "$rb" = 0 ] && [ "$rc" = 0 ] && [ "$ra" = 1 ] && [ "$re" = 1 ] || exit 1; r="$(tr '\n' ' ' < "$R" | tr -s ' ')"; g="$(tr '\n' ' ' < "$G" | tr -s ' ')"; p="$(tr '\n' ' ' < "$P" | tr -s ' ')"; n="$(grep -c 'A rejected spawn is undelivered' <<<"$r")" || n=0; [ "$n" -gt 0 ] || exit 9; n1="$(grep -c 'next wave carries' <<<"$r")" || n1=0; n2="$(grep -c 'the next wave carries' <<<"$g")" || n2=0; n3="$(grep -cE 'join each wave|wave is joined|before the next wave spawns' <<<"$r")" || n3=0; n4="$(grep -cE 'join each wave|wave is joined|before the next wave spawns' <<<"$g")" || n4=0; n5="$(grep -c 'CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS' <<<"$r")" || n5=0; n6="$(grep -ci 'a seat is not a wave' <<<"$r")" || n6=0; n7="$(grep -cE 'Each wave is joined in ONE beat|wave is joined' <<<"$p")" || n7=0; [ "$n1" = 0 ] && [ "$n2" = 0 ] && [ "$n3" = 0 ] && [ "$n4" = 0 ] && [ "$n7" = 0 ] && [ "$n5" -gt 0 ] && [ "$n6" -gt 0 ] || exit 1; exit 0`

**Mechanism evidence (c5's measured close, kept verbatim).** **Measured close (batch 243, c5).** The transcript is graph's s320 stories-round lead, `d22c7889-6a0a-4353-9626-d39017478bc3.jsonl`, identified as the one transcript carrying the s320 stories party round's Agent spawns (76 delivered exits for round s320/stories); its own note sizes the waves "waves capped at 42 (CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS)". `bash scripts/audit-party-wave-barrier.sh --trace <transcript>` exits 0 with 0 findings, rounds=3, batches=24, and a cap of 42 read from the transcript with capsrc=env (no `--cap` given); with `--cap 42` the result is the same. No "Concurrent subagent limit reached" rejection occurs, so the cap came from the environment variable, which is the Rule 28 cap order working. Shape: in the stories round 33 exits REFILLED at running=39 of 42 and 1 was SLOTS-FULL, through 03:41Z; the final 42 exits are the round's tail after its last member was dispatched (76 = 42 + 34), which the detector does not judge by design. Control from the same evidence: s319 `a0701ce0` with `--cap 42` exits 1 and fires on batches 2 and 3 (running=24, idle=18, gaps 3348 s and 1364 s), as the lead ruling above records, and the detector's self-probe passed. This is ONE round's measurement after the prose fix. A barrier that did not recur on one round is the close condition this entry named, so the entry closes on that; it is not proof the barrier cannot return, and the detector stays available to re-run.

Re-audit (BL-817): graph s319 against s320, `docs/analysis/pipeline-efficiency-s317-s320/scripts/` (extract.py, roll.py as committed at fc71a7b10 on main; the step rows of steps.csv per story); per story, stories-test-strategy: s319 (20 stories) 0.80 h gap-inclusive (gap 0.45 h), token-equivalent $26.0 (API $26.0), 44.8M tokens; s320 (13 stories) 0.93 h gap-inclusive (gap 0.40 h), token-equivalent $39.1 (API $39.1), 65.0M tokens. Lead seat 0% local in both sprints; subagent seats ran hosted models only. The step did not fall: the wave barrier did not recur, and the step cost more per story.

Owed: the step's per-story cost on a measured graph sprint, or the step-value evidence for what that cost buys; and, per BL-812 item 3, an explanation of s320's rise drawn from the sprint itself. Not a rebuild: the shipped wave sizing (0.950.0) stands.

verify: manual


## BL-866 — timing runs are retired; cost evidence is the counts the gate records

**NOTE.** Operator ruling, 2026-10-28 17:16 EDT: "Timing runs are pointless and unwarranted. I don't want them, they add unnecessary ceremony to collect data that will never be used and become irrelevant quickly." A ruling at 17:15 stands beside it: no work needs a quiet box. Cost evidence is the counts the gate records (invocations.decl, exec, fork and render counts), and reading a duration off a pre-push log stays allowed.

**Changed (batch b245).** The durable rules carry it: `.claude/rules/operator-rulings.md` gains the section "No timing runs" and drops the "Measure `uptime` before a gate" clause; `CLAUDE.md` restates the validator rule as counting execs and invocations before and after; `.claude/rules/verification-discipline.md` recasts "Time both sides the same way" as "Count both sides the same way" and keeps the trees-versus-revisions hazard; `.claude/rules/tool-hazards.md` ends the PS4 paragraph at counting invocations. The live timing instructions in `docs/plans` are recast as counts or deleted: `graph-ledger-full-drain.md` (archive), `pre-push-wall-clock.md` (archive), `hermetic-fixtures-poc.md`, `graph-s305-triage.md` and `graph-pull-0891-to-0901.md`. Historical quotes and recorded wall clocks are untouched.

**Second claim: the pole-baseline calibration depended on timing runs.** Its header required three serial forced full runs and the MAX. The mechanism is already gone and nothing needs a counts-based replacement: `docs/suite-pole-baseline.tsv`, `scripts/validate-suite-pole.sh` and the `suite-pole-guard` fixture were deleted at 0.807.0 (CHANGELOG.md:5311), and the pre-push hook now prints the pole as information and never fails on it. `git ls-files` lists no baseline file, and no script, hook, fixture or validator reads one. The remaining readers are prose only: `docs/plans/pre-push-wall-clock.md:127`, `:547`, `:562`, `:579` and `:585` (the section marked SUPERSEDED at :547, whose `grep -v '^#' docs/suite-pole-baseline.tsv` command at :585 describes the removed guard), `docs/plans/archive/graph-ledger-full-drain.md:13382` and `:16571`, `docs/poc/hermetic-census/02-census.tsv:227`, and history in CHANGELOG.md and docs/backlog.archive.md. The quiet-box calibration instruction at `docs/plans/pre-push-wall-clock.md:564` is recast to say the row is no longer re-calibrated by timing runs.

A third durable change: `CLAUDE.md`, in the section on running the fixture suite, now states that the shared verdict store is seeded before a release push and that a re-run in a mktemp store caches nothing, citing `docs/plans/hermetic-pole.md`; the sentence also names the `verdict store: N fixture(s) skipped` line as the evidence the seed worked, and the owner rules in `docs/plans/graph-ledger-full-drain.md` carry the per-unit throwaway-ref verification push and the validators-only integrator rule.

verify: manual
