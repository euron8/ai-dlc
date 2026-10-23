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

verify: manual

## BL-553 — the lead arms a beat on a sentinel nothing will write, to keep the Stop hook quiet

**DEFECT.** Consequence of BL-541. With no completion signal for the serial remediator, the s319 lead armed beats on files it created for the purpose and that no agent writes. At 00:03:48Z it wrote: "A sleeping beat, `bw7kr8cpi`, is now armed on a sentinel file that nothing will write. Its marker holds a future epoch, so it holds for a full quantum." Session 62eadbbe holds 8 such sentinel beats (corrected: the 00:17Z "fold record" beat was a real beat on requirements-d-answers-fold.md that delivered at 00:35:15Z, not a sentinel). Five are serial-remediator waits (00:03:48, 01:19:11, 01:29:06, 01:39:02, 01:48:57Z), closed by `--complete-repair`. The other three are closed too. 00:07:23Z, a serial remediator resumed by SendMessage after a refusal, is closed by reference: BL-593 (LANDED v0.817.0) and BL-541's `--complete-repair --dispatch` cover the resumed block, and nothing was built. 01:15:08Z, a part-04 SPEC render whose part record wrote no marker, is closed in `core/team-roles/remediator.md` (line 78): every part remediator now ends with `wait-for-deliverable.sh --mark <part path> <step> remediator <shard> findings=<n>`, and the part join beat in `core/skills/ai-dlc/steps/_gate-procedures.md` passes `--complete`; `join-remediator-shards.sh` needed no change, because a marked part leaves the serial block intact and unmarked parts still join. 01:52:38Z is closed in the same role file (lines 244-250): a serial remediator whose block appends a `(decision)` re-renders SPEC.md before its `--mark-repair`, so the render sits inside the dispatch that `--complete-repair --dispatch` already joins, and the record_tail refusal at `join-remediator-shards.sh:1477` rejects a serial block with a `(decision)` and a stale SPEC.md. That sentinel beat satisfied `ai-dlc-continue.sh`'s lease test while waiting on nothing, which is the "filler tool call" the hook's own text forbids ("Do NOT emit filler tool calls to get past this block"). The entry stays open only on part (b), below.

**The 01:52:38Z account (graph lead transcript 62eadbbe, read-only).** Two beats are involved, and the earlier wording described them as one. At 01:52:28Z (jsonl lines 9934-9936) a background beat, task bfq5e0eg3, completed and its output read `DELIVERED` for the offramp-config-and-rewards SPEC.md (line 9945), 40 seconds before the render agent returned. At 01:52:38Z (line 9953) the lead armed `wait-for-deliverable.sh --reset --since <now> $S` with `S=.../scratchpad/never-written-sentinel-render`, a path nothing writes, described as "Arm a sleeping beat until the SPEC render agent returns" (task b2id0l4h8), and confirmed its marker was a future epoch at line 9956. The render agent's notification arrived at 01:53:08Z (line 9977), and the lead TaskStopped b2id0l4h8 at 01:53:12Z (line 9980). So the real SPEC.md beat delivered early and the sentinel beat was armed to cover the gap that early delivery left. The control token `never-written-sentinel-render` is present in the transcript (4 lines) and an impossible token returned 0. Whether bfq5e0eg3 delivered on a partial write is not settled by these lines.

**Part (b), the target-containment refusal, is NOT shippable as specified (batch 236, measured by the wfd contract adversary over the reference consumer's lead transcripts, read-only).** 189 transcripts carry 2,869 beat calls over 5,866 targets. The legitimate targets outside the state dir include 803 teammate story-worktree deliverables, 75 background done files, 64 main-tree docs, 57 scratchpad and task outputs and 7 git refs, so "outside `_bmad-output/`" is not a defect signal. The In-Flight table is empty today and no transcript records it at arm time, so "outside every In-Flight row's deliverable" is unobservable. The seat beats that set a custom state dir (`implementation.md:447`, `qa.md:457`, `code-reviewer.md:196`) would fail it outright. At arm time a sentinel and a real done file are the same act; the difference is the lead's intent, which no check can see. Detecting a sentinel by its name is refuted: 2 of the 8 sentinel basenames lack `never-written`. The live claim is that a beat with neither `--dispatch` nor a dispatched agent's deliverable as its target still counts as a lease. Its false-positive set over the 2,869 calls is UNRUN. The only observable candidate is the dispatch join, and `wait-for-deliverable.sh` already WARNs on a `--since`-only beat (line 1345).

**Progress (batch 240).** Part (b) is not buildable as specified: the spawn ledger has 14 of 6,317 rows with a deliverable field, and even a generous reconstruction still refuses about 190 legitimate `--since`-only beats, which is a floor.

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

**Evidence: the read-set fan-out of a runner change.** On a consumer's 0.830.0 to 0.834.0 reconcile push (graph transcript 5d4fbc59), the first push took about 98 minutes and ran 128 of 224 fixtures. 122 of them were woken because the pull changed runner and tooling files: `hermetic-run.sh`, `.githooks/pre-push`, `apply.sh` and `derive-fixture-readsets.sh`. The re-push took about 6 minutes and ran 42 of 224. Load was 77 to 85, so these are loaded figures. No dollar figure was measured. This is BL-583's subject, not BL-694's.

**Progress (batch 240).** Re-scoped to the poles not covered by BL-699 or BL-755.

verify: manual

## BL-584 — two fixtures cannot be traced and have no `inputs.decl`, so they run on every push

**PARTIAL (v0.806.0, verified 581ca289) — owed (1) shipped for `fold-architect-ledger-join` only; owed (1) for `hermetic-runner` shipped in v0.832.0 (verified 67bdbb7a), and owed (3) is OPEN.** `fold-architect-ledger-join` carries `inputs.decl` and `tools.decl` and runs under `hermetic-run.sh` (72 ok, `required_missing=0`); its 46 traced rows are removed. `hermetic-runner` reads its subject files from copies made once at startup. That cut its trace window about 6x (17691 lines to 2902, loaded) but did NOT stop the drops: one 6-fixture `--tracer sandbox` call dropped 3 reports in its window, and three `--local-map` reps dropped 1, 2 and 7, at load 27-43 (0 of 3 clean). The premise that the drops come from re-opening four tree files hundreds of times is REFUTED; the drop cause is undiagnosed. `hermetic-runner`'s 17 rows and digest are removed, so it runs on every push (fail-closed) until the drops are fixed. The earlier count of 27 held fixtures is 5: 27 have `#discards` at n≥3 in `.git/ai-dlc-fixture-readsets.local`, and only 5 are keyed on the current runner and deriver.

**PARTIAL (batch 240) — owed (2) is met; owed (3) stays OPEN, so this entry carries no `**LANDED` line.** Of the 37 `core/fixtures/*/run.sh` directories that had no `inputs.decl`, 34 now carry `inputs.decl` and `tools.decl`, each proven by `core/scripts/hermetic-run.sh`. The other 3 carry a dedicated `.undeclarable` marker, whose first line states why no one declaration holds in both layouts: `hook-registration-join`, `retro-compliance-workflow` and `self-update-join-gate`. The last of those is also `.dist-only`. The marker replaces the README sentence that (2) named, because 10 of the 37 already had a README for other purposes. Invariant I74(e) in `scripts/validate-enforcement-map.sh` binds it: every `run.sh` directory carries exactly one of `inputs.decl` or a `.undeclarable` with a non-empty first line. The arm's self-probe runs under mktemp before the corpus and fires in both directions.

Census, scored under `bash -c 'set -uo pipefail; …'`: 260 `run.sh` directories, 257 declared, 3 undeclarable, 0 offenders, exit 0. A second spelling (a `find -name run.sh` walk with `head -1`) also exits 0. Three seeded regressions each exit 1: a directory with neither file, an empty `.undeclarable`, and a directory with both. The receipt is `verify: manual`, because a census over the marker would read CLOSE-CANDIDATE while (3), the trace-stream drop cause, is still owed.

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

**PARTIAL (v0.808.0).** Delivered: items 1 (debt-row half) and 2. Withdrawn by operator ruling: item 3 (the 8 rows are prose in a reconcile log written before this release, never recorded, so no reader can pick them up; the receipt proves the shape on seeded rows). The 8 rows are live CURRENT/LIVING stale derivations in graph; the operator hands them to graph's own session to re-point, with the 3 s319 rows of the second instance. Open: item 1's snapshot half (D6: no writer can reach the working branch before the reconcile PR merges). **WITHDRAWN (batch 239, lead ai-dlc-13):** the snapshot half is superseded by `core/skills/ai-dlc/steps/route.md`'s owed-derivations check, which every resume runs (`scripts/ai-dlc/check-owed-derivations.sh`); the residue that a pull never runs the derivation differential is BL-706's. Scoped by operator rulings: current sprint and living documents only; refused at the planning gate only.

**What the first instance cost (graph watch ai-dlc-f7, filed as BL-622 and folded here as the same claim; intake re-derived it read-only).** Of the 8 rows from the 0.793.0 log, one is `planning-artifacts/prd.md:1288-1289`, whose fence greps `scripts/ai-dlc/validate-artifact-budget.sh` for `"  ok  %-44s"` and records line 1676 (written in `dbc4c057e`). The line is 1676 at `8f313c3c0` and 1955 from `41d2dbf91` onward. The s319 lead found it about 14 hours after the pull, and only because two pass-2 adversary shards (parts 11 and 6) flagged it: transcript `0e9a936b`, first mention at 21:56:59Z, 17 mentions in all. It now sits in graph's live snapshot (`pipeline-snapshot.md:40`) as "STALE LIVE FENCE (owed to the pass-2 repair, NOT editable before the pass-2 merge because every shard notarized prd sha 15c46858 and the --subject merge refuses a moved sha)". The other 7 owed sites have no sprint-side record. So the missing channel cost an adversary dispatch to recover a grep result.

That snapshot line also names a sub-case the channel has to handle. `core/skills/ai-dlc-update/reconcile/apply.sh:1404`'s WORKLIST remedy says only to re-point each fence, but a live-sprint file whose sha the round's shards have notarized cannot be edited mid-pass. The owed record must therefore survive until the sprint's next repair, not merely reach the lead. Control for "no core reader": 0 files under `core/skills/ai-dlc`, `core/hooks` or `core/scripts` name `ai-dlc-update/reconcile-log` at `581ca289`, against 9 naming `operator-requests-history`. Probe, from the filer: seed a pull that NEWLY-FAILs one fence in a live-sprint artifact, dispose it as owed, and assert the next sprint resume names that file:line. A fence in a closed-sprint artifact stays quiet (near-miss).

**Check 37 passes graph's planning gate with the first instance's fence still failing (graph watch ai-dlc-f7; intake re-read it read-only on graph).** The s319 lead's [planning] gate, transcript `74de15ba` at 0.818.0, shows two things on 2026-10-17. At 14:10:12Z the validator printed "FAIL (STALE): _bmad-output/planning-artifacts/prd.md:1289 … recorded: 1676 … actual: 1955" (1 hit). At 14:15:56Z the lead wrote "Check 37 reads an owed-derivations record that doesn't exist" (1 hit; negative control 0). `_bmad-output/ai-dlc-update/owed-derivations.tsv` is absent in graph, while that directory holds 590 entries. Graph's installed `scripts/ai-dlc/check-owed-derivations.sh` says "absent is silent 0" at `:286-289`, and so does main's at `:291-293`. `steps/gate-validation.md:3300` says "an absent record is exit 0". The only writer is `derivation-differential.sh --record-owed`, which appends NEWLY-FAILING rows only (`:9`). prd.md:1289 broke at the 0.793.0 pull, before the record existed, so every later pull reads it as STALE-BOTH (`:49`), which is never recorded. Of graph's 256 reconcile logs, only `reconcile-log-20261016T0725Z.md` names it. The lead is carrying it by hand, as a MINOR finding into architecture.md.

This is the consequence of the PARTIAL note's withdrawal of item 3: no reader picks up the 8 rows, and Check 37 is not the channel for them. f7 proposes either a one-time back-fill of the record from the reconcile logs' owed lists, or Check 37 also running `validate-artifact-derivations.sh` over the documents it scopes as LIVING. Both would re-open what the operator withdrew, so intake files them as a proposal for the lead to rule on, not as owed. f7's probe, if adopted: a LIVING-document fence broken before the record existed must DENY, and the same fence in a closed sprint stays silent.

**Progress (batch 240).** The f7 survivor reopens the operator-withdrawn item 3, so it goes to the operator in plain words with a recommendation before any build.

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

**Progress (batch 240; the entry stays OPEN, `verify: manual` unchanged, no LANDED line).** The `readset-skip-d` false RED above was reproduced from a forced DROPPED VERDICT, and its lead candidate was ruled out. Hand H2's measurements, on scratch copies; not re-measured at intake.
- **Ruled out: the watcher's first poll.** `pool_run`'s watcher first polls after `sleep 1` (`.githooks/pre-push:2257`). A forced 2 s stall in the seeded run.sh (`[ -f "$CK_CTL/slow.$f" ] && sleep 2`), on alpha, beta, delta and all three, in worlds f and h, under the unmutated block, `notfail` and `nosubtree`, moved 0 of 24 cells. Elapsed rose 2 s per stall, so the over-1 s path ran.
- **Reproduced.** A seeded unit sends `kill -TERM $PPID` once, and `pool_abort` exits 130 with no verdict. With beta dropped, the shipped `ck_mut` reads `moved worlds 'f l'`, graph's exact set; the control without the control file is unchanged. World (f) cannot tell FAIL from no-verdict, and `notfail` publishes beta's key, so f moves under `notfail` only. World (h) moves under the UNMUTATED block and `nosubtree` alike, so graph's unmutated (h) read ok only because the drop hit `nosubtree`'s drive.
- **Not established: what drops a verdict under load.** Three candidates, each a CANDIDATE and none a finding. (a) The live-trace watchdog's group `kill -TERM -- "-$dp"` / `"-$sp"` (`.githooks/pre-push:1155-1167`, `core/git-hooks/pre-push:1055-1067`) under pgid reuse; `ck_push` turns the inner live trace off, so this needs the outer group id reused. (b) A fork or process-limit failure in the inner worker. (c) The inner watcher's process walk under pid churn. The experiment to run first is (a): in a scratch copy, force the watchdog's pgid to equal the inner pool worker's group and send the TERM. If that drops a verdict the way the forced `kill -TERM $PPID` did, it reproduces the shape. (b) and (c) need a resource or timing condition that a scratch copy cannot force as directly.
- **Shipped.** On a FAIL, `ck_mut` prints, for every moved world, the want and got vectors and that world's `no verdict recorded` / `produced a verdict` / `REFUSED` pool lines (`core/fixtures/readset-skip/run.sh:5078`), so the next field red names a drop. There is no stall arm and no timing mutant: no elapsed-time dependence exists, and the derived added floor is 0.
- **Considered, not built.** A world-f field counting dropped verdicts (want 0). It names the drop, but it would turn every load drop in an unmutated drive into a new red.
- **One more field red, UNCLASSIFIED (dropped verdict or otherwise).** On R5's U56 build in batch 240, the `wait-beat-liveness` mutant `revised-postpoll-silent` read red once under load and green on rerun; the change under test did not touch `say_revised`. Figures: 1 red, 1 green rerun, base green once. Not re-measured at intake.
- **Still owed.** The trigger of the dropped verdict; census item 8 (`readset-sandbox-root-clause` all-lossy rate at pool load); Owed item 3 (solo-against-pool receipt per fixed unit, with a load-free control); census items 5 and 6; and the remaining unread `readset-skip` polls listed above.
- **Receipt for this progress (quoted, not installed as `verify:`).** `grep -c 'no verdict recorded' core/fixtures/readset-skip/run.sh` scores 0 at 5b5388924 and 1 at this release's tip. It shows that the diagnostic print exists, not that the drop is fixed.

verify: manual

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

verify: manual

## BL-691 — a nested pool makes its pool root outside the OUTER unit's watched TMPDIR, so the outer watcher does not see the nested pool's scratch writes

**NOTE.** A fixture that drives the real hook's pool makes a nested pool: `core/fixtures/prepush-pool-depth/run.sh` calls `run_fixtures` at depth 1 (`:79`, `:120`), and `core/fixtures/readset-skip/run.sh` sources the extracted FIXTURE_POOL block (`:287`, `:361`). `core/fixtures/self-update-fixture-log/run.sh` drives the hook through `h_enter` (`:2090`) and names PREPUSH_POOL_DEPTH (`:2063`); whether it reaches `run_fixtures` was not established. The nested pool chooses its root at the `out=` line (`.githooks/pre-push:2030`, `core/git-hooks/pre-push:1938`), which is `/tmp/fx.XXXXXX` and not under the caller's TMPDIR. The outer pool watches a per-unit TMPDIR (`TMPDIR="$wr" "$@"`, `.githooks/pre-push:2206`; the watched-root limit is commented at `:467-:469`). The nested pool's scratch writes land outside that root, so the outer watcher sees only the nested hook's log output. Whether the outer progress check still holds for those three fixtures is UNRUN.

Owed: when `PREPUSH_POOL_DEPTH` is above 0, the pool root is made under the caller's TMPDIR.

Measured against that owed fix: under hermetic-run the caller's TMPDIR is already nested (`core/scripts/hermetic-run.sh:141` makes `$HR_WORK` under the unit's TMPDIR and `:544` gives the sandbox `TMPDIR="$HR_WORK/tmp"`), so the owed root would make the nested unit TMPDIR `/private/tmp/fx.XXXXXX/.t.XXXXX/hermetic-run.XXXXXX/tmp/fx.XXXXXX/.t.XXXXX`, 90 encoded (74 characters plus 2 per each of 8 `/`) against the 85 that `core/fixtures/procsub-staged-refusal-boot/run.sh:945` allows, and 62 without hermetic-run (`/private/tmp/fx.XXXXXX/.t.XXXXX/fx.XXXXXX/.t.XXXXX`: 50 characters plus 2 per each of 6 `/`) against the 58 bound the hook states at `.githooks/pre-push:2039` and `core/git-hooks/pre-push:1947`; the fix design (shorter names, a changed limit, or the outer watcher following the nested root) is deferred.

**Progress (batch 240).** The NOTE stands: 0 stalls across 21 failure records and 2,680 transcripts, with the positive control present, and units run 13-175 s against a 600 s stall window. Any fix's receipt must force a nested unit past that window.

verify: sh for f in .githooks/pre-push core/git-hooks/pre-push; do b=$(sed -n '/out="\$(mktemp/,/mkdir -p .*\$out/p' "$f" | grep -v '^[[:space:]]*#'); [ -n "$b" ] && [ "$(printf '%s\n' "$b" | grep -c 'PREPUSH_POOL_DEPTH\|POOL_DEPTH_IN')" -gt 0 ] && [ "$(printf '%s\n' "$b" | grep -c 'TMPDIR')" -gt 0 ] || exit 1; done

## BL-695 — a sharded stories party round waits on its slowest seat at every wave, because the lead split the round by seat and joined each seat before dispatching the next

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

verify: manual — the owed half is a measurement of graph's next stories round showing seats refilling during the cross pole, which no tree state can answer.

## BL-699 — reconcile-emit-report's pcache phase costs over ten minutes and is the suite pole on every push that re-keys it

**DEFECT, efficiency.** Filed by the lead (ai-dlc-c8) in batch 236 from ai-dlc-77 [e29316]'s measurement. Owner: ai-dlc-77 [e29316].
- **The cause.** 0.834.0 added phase pcache to `core/fixtures/reconcile-emit-report` (arms PC-V0..V26 and mutants M-region, M-direxcl, M-exit3). Every push whose content key touches that fixture pays it.
- **Measured:** the owner's phase run took over 10 min. In the 0.834.0 dress rehearsal (9ffd957a9), the process tree at 14:42 EDT 2026-10-18 showed `reconcile-emit-report/run.sh` at 9:00 elapsed, the longest in the pool, with four sub-processes at 3:10. That rehearsal failed on another unit and wrote no durations row.
- **Direction (lead-ruled):** make the phase do less. Either share one seeded world across the PC-V cases, or move the pcache mutants into a `.dist-only` battery. Choose by reading the phase, not by timing it.
- **Receipt basis:** the phase's own cost row in `.git/ai-dlc-fixture-durations`, compared like for like (loaded on both sides) with the method stated. The "before" side is the first suite run on main after 0.834.0 that dispatches `reconcile-emit-report`; the record still held the pre-pcache rows 124 / 299 / 134 when this was filed.
- **The fix (b236-bl699):** each pcache mutant runs only the arms holding its declared kill set plus the always-on prefix V0/V1/V14/V2 (`pcv_scope`), and its kill set is read over that scope. Read from the code: 4 suites x 11 seeds became 11 + 0 + 1 + 1, and the three mutant suites dropped from 94 `--verify` renders each to 4, 7 and 8. The four suites run CONCURRENTLY, so this removes box load, not critical path: the ship suite's 94 serial renders are still the phase's floor, and the lever that would move the pole is a split of the ship run along the same `pcv_in` groups (each with its own suite dir), not built here. The receipt below is structural: the scoped mutant launch and the scoped kill-set read each occur once, beside the unscoped ship launch as its control (exit 9 when that control is gone). A revert of either scoping exits 1; a comment carrying both lines does not satisfy it, because each grep is anchored at the line's start. The durations comparison above stays the owner's measurement.
- **Progress (b236-bl699-share).** Counted on scratch copies by instrumenting `pcv_run` (`--verify` renders), `pcv_lat_approve` (plain renders) and `pcv_lat` (seeded worlds), as verify/approve/seed per suite. At ff4eb8329, each of the 4 suites was 149/15/16. At the BL-699 tip, ship was 149/15/16, M-region 4/0/0, M-direxcl 7/1/1 and M-exit3 8/1/1. The 4 suites run CONCURRENTLY (`run.sh` launches ship in the background at `:4212`, each mutant at `:4221`, and joins them in one `wait` at `:4226`), so the ship suite alone still bounds the phase. Both kill-scope guards (`pcv_offscope` at launch, `pcv_noverdict` at scoring) were proven through the real fixture. This change drops three ship renders, read off the code rather than counted: V7's and V40's hit controls, whose identical-engine-copy hits v7c and v40c are the hit evidence on the same tree and record, and V35's control when V32's near miss has just hit the same restored tree. The expected ship count is 146/15/16; the mutant suites are untouched.
- **OWED, next lever.** The nine `pcv_latarm` arms (V17..V25, 36 renders) might share one record per world, IF their holes are shown not to interact. That is a reading still to be done, not a claim.

- **Progress (batch 240; the entry stays OPEN, with no LANDED line).** The nine `pcv_latarm` arms (V17..V25) moved out of shard a's `pcache` phase into a new phase `pcvlat`, dealt to a new shipping shard `reconcile-emit-report-d` (`SHARDS="a b c d"`, `PHASES_d="pcvlat"`). The cache-arm helpers are hoisted to one definition above both phases (`pcv_setup`, `pcv_cache_engine`, `pcv_shim`, `pcv_read_ids`), so nothing is duplicated. A new stray-verdict check (`pcv_unexpected`) makes an arm that writes a verdict in a phase whose id list does not read it FAIL; before, a `pcv_latarm` left behind in `pcache` wrote an `ok` nothing read. It has a self-probe, a near-miss probe and a mutant. The `-d` dir declares shard a's tool list (shard c's lacks `shasum`, which the engine's record hash needs in the sandbox) and `layer-adjudication-tier/seed.sh`; shards a, b and c declare the `-d` driver. Packaging is in `uninstall.sh`, `core-manifest.md` and `fixture-manifest.md`. The headers of `core/fixtures/reconcile-emit-report-b/run.sh:11` and `-c/run.sh:11` said those shards are named in `setup-sites.md`, which is false because `.claude/rules/fixture-ship-decl.md:44` says a shipping fixture is never named there; this release corrects both to name `core-manifest.md` and ai-dlc-update's `fixture-manifest.md`, the same wording as the new `-d` header.
- **Verified, through `hermetic-run.sh`.** Shard a rc=0 with 112 assertions; shard d rc=0 with 23 assertions, all nine ok. By text, the base `PCV_IDS` (38) equals the tip's (29) plus the nine. Not run: a base-versus-tip comparison of the remaining ids' verdicts; shard a's full PASS at the tip is the evidence. No wall-clock figure is quoted.
- **The old receipt, and why the line is now `verify: manual`.** The previous closing line was `verify: sh f=core/fixtures/reconcile-emit-report/run.sh; [ -f "$f" ] || exit 9; c="$(grep -cE '^[[:space:]]*\( pcv_suite "\$EMIT" "\$PCV_ROOT/ship" \)' "$f")" || c=0; [ "$c" = 1 ] || exit 9; n="$(grep -cE '^[[:space:]]*\( pcv_suite "\$PCV_ROOT/\$_m/eng/emit-report\.sh" "\$PCV_ROOT/\$_m" "\$\(pcv_scope "\$_m"\)" \)' "$f")" || n=0; s="$(grep -cE '^[[:space:]]*_got="\$\(pcv_failset "\$PCV_ROOT/\$_m/verdicts" "\$\(pcv_scope "\$_m"\)"\)"' "$f")" || s=0; [ "$n" = 1 ] && [ "$s" = 1 ]`. It exited 0 at 782fd93f9 (control: file absent, exit 9). It checks that the kill-scope plumbing exists, so it read as a CLOSE-CANDIDATE on an entry that is still open.
- **The new receipt for the `-d` split (quoted, not installed as `verify:`).** `f=core/fixtures/reconcile-emit-report/run.sh; [ -f "$f" ] || exit 9; [ -f core/fixtures/reconcile-emit-report-d/run.sh ] || exit 1; grep -qE '^SHARDS="([a-z]+ )*d( [a-z]+)*"$' "$f" || exit 1; s="$(sed -n 's/^PHASES_d="\([a-z0-9_]*\)"$/\1/p' "$f")"; [ -n "$s" ] || exit 1; awk -v s="$s" 'BEGIN { n = split("17 18 19 20 21 22 23 24 25", v, " ") } /^[[:blank:]]*#/ { next } $0 == "if rer_phase " s "; then" { i = 1; o++; next } $0 == "fi # end rer_phase " s { i = 0; next } { for (k = 1; k <= n; k++) { re = "PC-V" v[k] "([^0-9]|$)"; if (i && $0 ~ re) h[k] = 1; if (!i && $0 ~ /PCV_IDS=/ && $0 ~ re) bad = 1 } } /^[[:blank:]]*pcv_latarm[[:blank:]]/ { if (i) c++; else bad = 1 } END { if (bad || o != 1 || c < 1) exit 1; for (k = 1; k <= n; k++) if (!h[k]) exit 1 }' "$f"`. Scores: fix 0; call left in `pcache` 1; V17 back in `PCV_IDS=` 1; V25 appended by `PCV_IDS="$PCV_IDS ..."` 1; `PHASES_d` absent 1; `PHASES_d` names `sb` 1; second spelling (slug `latnine`, the nine as a loop with one literal call line) 0; file absent 9.
- **Owed, named exactly.** (b236-bl699-share), the reading of whether the nine arms can share one record per world; and (d), the before/after durations, a timing measurement that is not in this release.

verify: manual

## BL-706 — no reconcile step runs the derivation differential on every pull, so a consumer whose pulls never hit a derivation never gets an owed-derivations record

**NOTE.** Filed by ai-dlc-77 [ab5b1f] from the BL-668 build (batch 236), lead ai-dlc-c8 ruled it a separate cost question with no owner this batch. BL-668 made `reconcile/derivation-differential.sh --record-owed` create the record on every run, so an absent record now means "no reconcile has ever measured this tree". But `reconcile/apply.sh` (~:1346, ~:1495) emits the differential only as a `WORKLIST artifact-derivations` row, and only when a recorded `derived` command names a core path the range changed; the differential refuses on zero derivations, and nothing runs it unconditionally. So a consumer whose pulls never touch a derivation keeps printing `check-owed-derivations.sh`'s absent line. That line is correct (the tree was genuinely never measured), so this is a cost question, not a defect. A per-pull "no changed path, so nothing owed" record was considered and declined (c8): a derivation can read files its command line never names, so that record would be written from intent, not from a measurement.

Owed: decide whether every pull runs the differential (two validator passes per pull) so the record always exists, measuring that cost on a reference consumer before deciding. No owner this batch.

**Progress (batch 240).** The cost differential is reachable (two validator passes over 919 derivations on a `file://` clone). It is banked under the NO TIMING RUNS ruling and runs only when a named fix needs the figure.

verify: manual

## BL-753 — the hookwake hook's blocking predicate (J1-J4) has never had an adversary pass, and it must have one before the hook can default on

**DEFECT.** Source: operator ruling, batch 239, on BL-538 ("I'll take your recommendation"). Filed by lead ai-dlc-13.

BL-538's batch-239 measurement found the shipped hook removes nothing on the reference consumer, because it is opt-in and default OFF (`core/hooks/ai-dlc-hookwake.sh` header, "OPT-IN, DEFAULT OFF"). graph's s319 leads `218aa1b8` (138 of 203 wakes idle) and `a367e62c` (97 of 150 idle) carry 0 hookwake rows, against a control of 35 in install session `48918adc`. The operator ruled that the default stays OFF and that the blocking predicate gets an adversary review first.

The predicate a review must break, from the hook's header:
- J1: exactly one outstanding beat in the lead transcript's bounded tail;
- J2: exactly one live `.beat-argv-<pid>` record whose start time matches;
- J1=J2: the task-id join;
- J3: the agent id is in the record's `--dispatch` set, read from argv;
- J4: `wait-for-deliverable.sh --status` exits 0 with every path DELIVERED.

A false BLOCK suppresses a completion the lead needed, which costs far more than an idle wake. The review asks, per clause, what state satisfies it while the lead still needs the wake: a stale beat, a recycled pid, a dispatch set wider than the join, or a DELIVERED path the agent has not finished writing.

Owed: one adversary pass (opus, read-only) over J1-J4 and C5. Fold its BLOCKERs and DEFECTs as fixes, each with an arm in `core/fixtures/hookwake`. Only then put flipping the default to the operator, with BL-538's idle-wake figures as the value.

**Progress (batch 240; the entry stays OPEN).** The adversary pass is done: 1 BLOCKER (J4 can block at most one wake per fan-out, a ceiling of about 27 of 1,562 idle wakes corpus-wide and about 0 in session 888e1365), five DEFECTs and a NOTE. The recommendation is to keep the hook OFF.

verify: manual — the subject is a review, not a code state; it closes when the review's findings are folded or ruled.

## BL-766 — gate-adjudicator.md never says a FAIL is complete only when the check's comparison surface is exhausted

**NOTE.** Source: BL-765's diagnosis, batch 240. Filed by lead ai-dlc-3f. Not built.

One sentence for `core/team-roles/gate-adjudicator.md:116-118` (the rule that every verdict is PASS or FAIL with evidence): a FAIL is complete only when the check's comparison surface is exhausted, not when one deviation settles it. It would cover every `adjudication: llm` check, where BL-765 covers Check 9 alone.

verify: manual — the sentence is prose with no mechanical predicate.


## BL-777 — emit-report.sh's recorded-PASS cache keys with `cksum`, so on a box without `cksum` it silently never records and nothing says why

**NOTE.** Found while building BL-692's fixture (batch 240): the sandbox's `tools.decl` lacked `cksum`, and the cache never recorded. Not built, and a candidate for a later release, not BL-692's.

`emit-report.sh`'s recorded-PASS cache builds its key with `cksum`. On a box with no `cksum` the key is empty and the cache silently never records, so it fails safe: every lookup is a miss and every `--verify` re-renders. That is a check that cannot fire, with no signal. Under BL-692's apply-mode rule a cached PASS is the only path that accepts without a re-render, so such a consumer pays a re-render every time and nothing says why.

Owed: one stderr line, printed under the cache opt-in only so that plain `--verify` stays byte-identical, reading `cannot key: cksum is absent` (the recorded-PASS cache cannot key because `cksum` is absent).

verify: has core/skills/ai-dlc-update/reconcile/emit-report.sh "cannot key: cksum is absent"


## BL-784 — Check B of `validate-steering-budget.sh` does not model the hook's lead-Explore allowance while paused, so it would score such a dispatch as a steamroll

**NOTE.** Source: BL-783's contract adversary, batch 240, filed by lead ai-dlc-3f. Filed OPEN, not built; the same class as BL-783.

`core/hooks/ai-dlc-acknowledge.sh:740-755` lets a LEAD (no agent id) Explore dispatch through while paused when four conditions hold: the call carries neither `name` nor `team_name`, its prompt is readable, its prompt cites no `team-roles/<role>.md`, and no agent definition named Explore shadows the built-in. `core/scripts/validate-steering-budget.sh` models none of it: `grep -c Explore core/scripts/validate-steering-budget.sh` returns 0 (control: `grep -c "Check B"` on the same file returns 11). Check B would therefore count such a dispatch after an operator message as a steamroll.

Measured on graph, read-only, over main-session transcripts since 2026-10-15T18:49:36Z: 168 sessions, 1600 Agent/Task tool_use blocks parsed (control), 0 lead Explore dispatches, so 0 after an operator message (`grep -l '"subagent_type":"Explore"' ~/.claude/projects/-Users-n8-git-graph/*.jsonl | wc -l` returns 1 file, which the window parse did not count, so it predates the window or sits in a non-main record). The defect is latent in the corpus, reachable by any lead that dispatches Explore.

Owed: the four conditions need their own contract before a fix, and a validator change must bind to the hook's logic the way BL-783 binds to the hook's updater-session predicate, never restate it.

verify: manual — the fix needs its own contract; the allowance is not yet modelled by any predicate to test.

## BL-788 — a deferred AC's discharge predicate lived only in the QA review file, so deploy-validate §4b ran a predicate no step checked against the deployed sha

**DEFECT.** Source: batch 241, lead ai-dlc-58, owner ai-dlc-12; a consumer filing from graph sprint 319 (the deferred-AC predicate that lives only in the QA review file).

At `done` the closing writer copied only the deferred AC ids into `deferred_acs`; the predicate itself stayed in the QA verdict. Graph s319: predicate `PI-1.2-a` appears twice in `docs/reviews/s319/1-2-qa-validation-p2.md` and zero times in its story file, and at deploy-validate §4b it named a label the deployed bundle did not carry, with nothing telling the lead to check that literal against what was deployed.

Built: `code-reviewer.md` Ownership (and the Responsibilities bullet and "As the Closing Writer" list, so the role's "exactly these writes" enumeration names it) has the closing writer write a `## Deferred ACs` section into the story file at `done` — each entry opening `- **<id>**` with the id written to `deferred_acs`, the predicate text copied from the highest `-p<N>` QA verdict and that verdict's path, `None.` for a story with none, placed before `## Dev Agent Record`. `qa.md`'s discharge-predicate item says the same. `deploy-validate.md` §4b reads the predicate from that section, falls back to the QA verdict for a pre-migration story with no section (recorded under `deferred_ac_discharge`), reports a missing entry or a `None.` beside a non-empty `deferred_acs` as a closing-writer defect, and checks each literal against the deployed sha, recording a correction as `old -> new` or re-deferring. Pinned by `process-rule-pins` rows `def-copy-*`, with a named ids-only mutant.

verify: sh bash core/fixtures/process-rule-pins/receipt-bl788.sh

## BL-786 — I10 reads only run.sh, so a fixture whose hook invoker lives in lib.sh is outside its population

**NOTE.** Source: batch 240, lead ai-dlc-3f. Filed by the r13 owner; not built.

`adversarial-shard-merge` runs a hook at `lib.sh:183` and scrubs at `lib.sh:10`, but I10 never reads `lib.sh`. Widening the unit to `run.sh` + `lib.sh` + `seed.sh` with I10's patterns verbatim was measured: population 55 to 58, offenders 0 to 2, `adversarial-shard-merge` acquitted. Both offenders are false positives: `check-15-bypass/seed.sh:558` is a comment naming the `hooks/ai-dlc-*.sh` glob, and `core-paths-audit-diff/seed.sh:54,95` are `- hooks/ai-dlc-*.sh` yaml seed data. Neither executes a hook, so the widening was not shipped.

Owed: a widened unit whose pattern excludes comments and the `hooks/ai-dlc-*` glob and data form, measured to an empty false-positive set with `adversarial-shard-merge` acquitted and a seeded `lib.sh`-only unscrubbed invoker reported.

verify: sh s="$(awk '/^# --- I10: fixture hermeticity/{f=1} f&&/^# --- I13:/{exit} f' scripts/validate-enforcement-map.sh | grep -Ev '^[[:space:]]*#|^[[:space:]]*err ')"; grep -qE 'grep[^|]*lib\.sh|/\*/lib\.sh|"/lib\.sh"' <<<"$s"

## BL-785 — the pause gate allows Bash, so a Bash-driven deploy is not treated as pipeline-advancing while paused

**NOTE.** Source: batch 240, lead ai-dlc-3f (finding raised by the r12 owner). Not built.

`core/hooks/ai-dlc-acknowledge.sh:871` tells the paused session "Read-only tools (Read, Grep, Glob, Bash) are still ALLOWED", and the gate admits Bash on that footing, so a deploy driven through Bash is not scored as pipeline-advancing while the pause flag is present. Graph s319: the 21:34 EDT 2026-10-22 deploy ran with the flag present. The flag was stale and the operator had authorised the deploy, so no harm followed.

Owed: the Bash allowance gets its own contract, and a false-positive set measured over real Bash calls before any Bash-pattern deny is built.

verify: manual — the fix needs its own contract and a measured false-positive set first, so no predicate over the tree exists to test yet.
