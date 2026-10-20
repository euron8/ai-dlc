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

**Evidence: the read-set fan-out of a runner change.** On a consumer's 0.830.0 to 0.834.0 reconcile push (graph transcript 5d4fbc59), the first push took about 98 minutes and ran 128 of 224 fixtures. 122 of them were woken because the pull changed runner and tooling files: `hermetic-run.sh`, `.githooks/pre-push`, `apply.sh` and `derive-fixture-readsets.sh`. The re-push took about 6 minutes and ran 42 of 224. Load was 77 to 85, so these are loaded figures. No dollar figure was measured. This is BL-583's subject, not BL-694's.

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

**PARTIAL (batch 236, lead ai-dlc-c8's ruling): measured, and no LATE arm ships.** Measured by ai-dlc-77 [ab5b1f], read-only on graph. Every committed revision of graph's `pipeline-snapshot.md` (553; control on an absent path: 0) was judged with `check_backdated_dispatch`'s own join loop against graph's HEAD spawn ledger, truncated to rows whose `ts` is at or before that revision's commit time. That gave 83 judgements over 39 revisions. The ledger committed in the same revision is usually days stale (65 ledger commits against 553), and pairing on it inflated lateness to as much as 923661 s. Controls in the same run: the 4 rows the BACKDATED arm reports on the revision-paired join are present in the input and still BACKDATED; every exact-name row joins by its own name (party-s301-pm, rem-s300-discovery-p1 and the rest, each printed with its B). LATE fires, `t - B > tol`, distinct rows, all statuses / in-flight only: 60 s 26/19, 90 s 25/18, 120 s 24/17, 180 s 20/13, 300 s 17/10, 600 s 12/6.
- Above 600 s, the six in-flight fires are one burst: graph's s315 retro seats (architect, dev, sm, tea, qa, analyst), dispatched 19:33:02-19:34:43Z on 2026-09-30 and stamped 20:10:00Z / 20:25:00Z, 2176-3017 s late. Not verified against a transcript.
- 71-591 s: thirteen exact-name joins. Honest exact-name rows with seconds in the stamp read up to 57 s late in the same corpus (`party-architect-s300-discovery` +57, `party-ux-s300-discovery` +45), so no line separates them.
- The motivating row (`2026-10-16T05:01:00Z`, 57 s late, revision `3dd8a9fd45`) sits inside that honest spread and has status `stopped`, so no in-flight arm would judge it.

Why no arm. Any tolerance is a number chosen after seeing the corpus, and checks here assert binary attributes. A BINARY predicate ("the row's stamp is after its OWN dispatch") needs a per-row join key. The In-Flight row carries the agent id, and the ledger carries `tool_use_id` and never the agent id: 0 of 4 sampled agent ids found in the HEAD ledger, against a control of 1 for a known `tool_use_id`. Role joins are not unique either: `pm` has 182 ledger rows, `architect` 311. The measurement now sits in the arm's header beside the LATE sentence.

Open: the row-side defect (stamp the row from the ledger `ts`). Recommendation, not filed: if the In-Flight row recorded the dispatch's `tool_use_id`, a binary late arm (the stamp differs from its own ledger `ts`) would need no tolerance.

**Built (batch 236): the row-side half is closed; the entry stays PARTIAL.** `core/scripts/wait-for-deliverable.sh --dispatch-ts <agentId|toolu_id>` prints the `ts` of that dispatch's spawn-ledger row verbatim and writes nothing (it takes the `--status` no-write path: no state dir, no lease). It resolves the id through the same `dispatch_epoch_of` the `--dispatch` beat uses, so there is one resolver, and an id with no single ledger row is refused (exit 64) with that function's text. `_gate-procedures.md` step 3 and `route.md`'s In-Flight table text tell the lead to fill `dispatched-at` from it, never from a clock. A row stamped from it equals the ledger `ts`, so `--since <dispatched-at>` passes the `--dispatch` guard's `SINCE > DISPATCH_EPOCH` check on equality. Receipt: a two-row ledger with the subject not first, plus an agentId meta.json. The agentId and toolu_ paths both print 05:00:03Z, which is not the 57 s late 05:01:00Z. The other row prints its own `ts`, and a missing row is refused by name. Run against the shipping script: exit 0. Run against b75ea5439's script: exit 1, through the receipt's own `FAIL: no stamp printed` arm, because that script refuses the flag (`unknown arg`). Not built: no arm judges an existing row. The row still carries no join key, which is the recommendation above.

verify: sh bash core/fixtures/wait-beat-liveness/receipt-bl605.sh

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
## BL-691 — a nested pool makes its pool root outside the OUTER unit's watched TMPDIR, so the outer watcher does not see the nested pool's scratch writes

**NOTE.** A fixture that drives the real hook's pool makes a nested pool: `core/fixtures/prepush-pool-depth/run.sh` calls `run_fixtures` at depth 1 (`:79`, `:120`), and `core/fixtures/readset-skip/run.sh` sources the extracted FIXTURE_POOL block (`:287`, `:361`). `core/fixtures/self-update-fixture-log/run.sh` drives the hook through `h_enter` (`:2090`) and names PREPUSH_POOL_DEPTH (`:2063`); whether it reaches `run_fixtures` was not established. The nested pool chooses its root at the `out=` line (`.githooks/pre-push:2030`, `core/git-hooks/pre-push:1938`), which is `/tmp/fx.XXXXXX` and not under the caller's TMPDIR. The outer pool watches a per-unit TMPDIR (`TMPDIR="$wr" "$@"`, `.githooks/pre-push:2206`; the watched-root limit is commented at `:467-:469`). The nested pool's scratch writes land outside that root, so the outer watcher sees only the nested hook's log output. Whether the outer progress check still holds for those three fixtures is UNRUN.

Owed: when `PREPUSH_POOL_DEPTH` is above 0, the pool root is made under the caller's TMPDIR.

Measured against that owed fix: under hermetic-run the caller's TMPDIR is already nested (`core/scripts/hermetic-run.sh:141` makes `$HR_WORK` under the unit's TMPDIR and `:544` gives the sandbox `TMPDIR="$HR_WORK/tmp"`), so the owed root would make the nested unit TMPDIR `/private/tmp/fx.XXXXXX/.t.XXXXX/hermetic-run.XXXXXX/tmp/fx.XXXXXX/.t.XXXXX`, 90 encoded (74 characters plus 2 per each of 8 `/`) against the 85 that `core/fixtures/procsub-staged-refusal-boot/run.sh:945` allows, and 62 without hermetic-run (`/private/tmp/fx.XXXXXX/.t.XXXXX/fx.XXXXXX/.t.XXXXX`: 50 characters plus 2 per each of 6 `/`) against the 58 bound the hook states at `.githooks/pre-push:2039` and `core/git-hooks/pre-push:1947`; the fix design (shorter names, a changed limit, or the outer watcher following the nested root) is deferred.

verify: sh for f in .githooks/pre-push core/git-hooks/pre-push; do b=$(sed -n '/out="\$(mktemp/,/mkdir -p .*\$out/p' "$f" | grep -v '^[[:space:]]*#'); [ -n "$b" ] && [ "$(printf '%s\n' "$b" | grep -c 'PREPUSH_POOL_DEPTH\|POOL_DEPTH_IN')" -gt 0 ] && [ "$(printf '%s\n' "$b" | grep -c 'TMPDIR')" -gt 0 ] || exit 1; done

## BL-692 — a session that re-renders the reconcile report by hand gets `--verify` exit 0, and apply writes over finding rows the operator never approved, with no ask

**DEFECT.** Filed by ai-dlc-48 in BL-621's release, on lead ai-dlc-c8's ruling. BL-621 made `apply.sh` refuse when a resolved blocker leaves a finding row the approved region never showed, unless a recorded re-approval quotes the region's digest. That gate reads `emit-report.sh --verify`'s exit-3 path. A session that splices a freshly rendered region over `_bmad-output/ai-dlc-update/reconcile-report.md` before applying turns that exit 3 into exit 0, because the report then matches a fresh render. The union gate sees "match" and writes, so the operator is never asked. The fixed filename is overwritten each run, so apply cannot tell a hand re-render from a first apply. BL-621's SKILL.md step 7 no longer tells the session to re-render on the exit-3 path, so the path is now one the prose forbids rather than prescribes, but nothing mechanical closes it.

Measured on BL-621's release tree: `core/fixtures/apply-restamp-worklist/receipt-rerender.sh` builds one mktemp world and drives the shipping `apply.sh` and `emit-report.sh`. The control, without the re-render, refuses with RE-APPROVAL OWED and leaves the tree unwritten. The subject, with the re-render and no record, exits 1: "apply WROTE on a hand re-render with no re-approval".

Owed: a binding between the approval and the region apply writes from that a re-render cannot reproduce, for example a digest of the approved region recorded at the first apply's argument and compared at write time. Receipt: the receipt below exits 0.

verify: sh bash core/fixtures/apply-restamp-worklist/receipt-rerender.sh

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

verify: sh D=scripts/audit-party-wave-barrier.sh; R=core/skills/ai-dlc/rule-bodies/rule-28.md; G=core/skills/ai-dlc/steps/_gate-procedures.md; P=core/skills/ai-dlc/steps/_dispatch-protocol.md; [ -f "$D" ] || exit 9; [ -f "$R" ] && [ -f "$G" ] && [ -f "$P" ] || exit 9; T="$(mktemp -d "${TMPDIR:-/tmp}/bl695.XXXXXX")" || exit 9; bash "$D" --seed a "$T/a.jsonl" --seed b "$T/b.jsonl" --seed c "$T/c.jsonl" --seed e "$T/e.jsonl" || exit 9; bash "$D" "$T/b.jsonl" >/dev/null 2>&1; rb=$?; bash "$D" "$T/c.jsonl" >/dev/null 2>&1; rc=$?; bash "$D" "$T/a.jsonl" >/dev/null 2>&1; ra=$?; bash "$D" "$T/e.jsonl" >/dev/null 2>&1; re=$?; [ "$rb" = 0 ] && [ "$rc" = 0 ] && [ "$ra" = 1 ] && [ "$re" = 1 ] || exit 1; r="$(tr '\n' ' ' < "$R" | tr -s ' ')"; g="$(tr '\n' ' ' < "$G" | tr -s ' ')"; p="$(tr '\n' ' ' < "$P" | tr -s ' ')"; n="$(grep -c 'A rejected spawn is undelivered' <<<"$r")" || n=0; [ "$n" -gt 0 ] || exit 9; n1="$(grep -c 'next wave carries' <<<"$r")" || n1=0; n2="$(grep -c 'the next wave carries' <<<"$g")" || n2=0; n3="$(grep -cE 'join each wave|wave is joined|before the next wave spawns' <<<"$r")" || n3=0; n4="$(grep -cE 'join each wave|wave is joined|before the next wave spawns' <<<"$g")" || n4=0; n5="$(grep -c 'CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS' <<<"$r")" || n5=0; n6="$(grep -ci 'a seat is not a wave' <<<"$r")" || n6=0; n7="$(grep -cE 'Each wave is joined in ONE beat|wave is joined' <<<"$p")" || n7=0; [ "$n1" = 0 ] && [ "$n2" = 0 ] && [ "$n3" = 0 ] && [ "$n4" = 0 ] && [ "$n7" = 0 ] && [ "$n5" -gt 0 ] && [ "$n6" -gt 0 ] || exit 1; exit 0

## BL-699 — reconcile-emit-report's pcache phase costs over ten minutes and is the suite pole on every push that re-keys it

**DEFECT, efficiency.** Filed by the lead (ai-dlc-c8) in batch 236 from ai-dlc-77 [e29316]'s measurement. Owner: ai-dlc-77 [e29316].
- **The cause.** 0.834.0 added phase pcache to `core/fixtures/reconcile-emit-report` (arms PC-V0..V26 and mutants M-region, M-direxcl, M-exit3). Every push whose content key touches that fixture pays it.
- **Measured:** the owner's phase run took over 10 min. In the 0.834.0 dress rehearsal (9ffd957a9), the process tree at 14:42 EDT 2026-10-18 showed `reconcile-emit-report/run.sh` at 9:00 elapsed, the longest in the pool, with four sub-processes at 3:10. That rehearsal failed on another unit and wrote no durations row.
- **Direction (lead-ruled):** make the phase do less. Either share one seeded world across the PC-V cases, or move the pcache mutants into a `.dist-only` battery. Choose by reading the phase, not by timing it.
- **Receipt basis:** the phase's own cost row in `.git/ai-dlc-fixture-durations`, compared like for like (loaded on both sides) with the method stated. The "before" side is the first suite run on main after 0.834.0 that dispatches `reconcile-emit-report`; the record still held the pre-pcache rows 124 / 299 / 134 when this was filed.
- **The fix (b236-bl699):** each pcache mutant runs only the arms holding its declared kill set plus the always-on prefix V0/V1/V14/V2 (`pcv_scope`), and its kill set is read over that scope. Read from the code: 4 suites x 11 seeds became 11 + 0 + 1 + 1, and the three mutant suites dropped from 94 `--verify` renders each to 4, 7 and 8. The four suites run CONCURRENTLY, so this removes box load, not critical path: the ship suite's 94 serial renders are still the phase's floor, and the lever that would move the pole is a split of the ship run along the same `pcv_in` groups (each with its own suite dir), not built here. The receipt below is structural: the scoped mutant launch and the scoped kill-set read each occur once, beside the unscoped ship launch as its control (exit 9 when that control is gone). A revert of either scoping exits 1; a comment carrying both lines does not satisfy it, because each grep is anchored at the line's start. The durations comparison above stays the owner's measurement.
- **Progress (b236-bl699-share).** Counted on scratch copies by instrumenting `pcv_run` (`--verify` renders), `pcv_lat_approve` (plain renders) and `pcv_lat` (seeded worlds), as verify/approve/seed per suite. At ff4eb8329, each of the 4 suites was 149/15/16. At the BL-699 tip, ship was 149/15/16, M-region 4/0/0, M-direxcl 7/1/1 and M-exit3 8/1/1. The 4 suites run CONCURRENTLY (`run.sh` launches ship in the background at `:4212`, each mutant at `:4221`, and joins them in one `wait` at `:4226`), so the ship suite alone still bounds the phase. Both kill-scope guards (`pcv_offscope` at launch, `pcv_noverdict` at scoring) were proven through the real fixture. This change drops three ship renders, read off the code rather than counted: V7's and V40's hit controls, whose identical-engine-copy hits v7c and v40c are the hit evidence on the same tree and record, and V35's control when V32's near miss has just hit the same restored tree. The expected ship count is 146/15/16; the mutant suites are untouched.
- **OWED, next lever.** The nine `pcv_latarm` arms (V17..V25, 36 renders) might share one record per world, IF their holes are shown not to interact. That is a reading still to be done, not a claim.

verify: sh f=core/fixtures/reconcile-emit-report/run.sh; [ -f "$f" ] || exit 9; c="$(grep -cE '^[[:space:]]*\( pcv_suite "\$EMIT" "\$PCV_ROOT/ship" \)' "$f")" || c=0; [ "$c" = 1 ] || exit 9; n="$(grep -cE '^[[:space:]]*\( pcv_suite "\$PCV_ROOT/\$_m/eng/emit-report\.sh" "\$PCV_ROOT/\$_m" "\$\(pcv_scope "\$_m"\)" \)' "$f")" || n=0; s="$(grep -cE '^[[:space:]]*_got="\$\(pcv_failset "\$PCV_ROOT/\$_m/verdicts" "\$\(pcv_scope "\$_m"\)"\)"' "$f")" || s=0; [ "$n" = 1 ] && [ "$s" = 1 ]

## BL-701 — a stale undeclared fixture re-runs on every linked-worktree push, because the in-pool trace that would clear it is skipped there

**DEFECT.** An undeclared fixture (no `inputs.decl`) is keyed on its committed rows in `.ai-dlc-fixture-readsets.tsv`. It skips on them only when its key record is clean, or when the committed `# digest <fx> <sha>` line matches this tree: `readset_committed_digests` (`.githooks/pre-push:827`-`:846`) writes `.cdig` as `match`, `differs` or `nodigest`, and only `match` clears a stale record (`:937`-`:945`). A stale fixture runs, and the hook names it under its reason (`:2001`-`:2009`). It then queues the fixture to be traced after a green run (`:2017`-`:2019`), which is what would clear it. The in-pool trace refuses a linked worktree, though: `readset_pool_trace_prep` sets `why` to "a linked worktree (the trace clones .git, which is a file there)" when `--git-dir` differs from `--git-common-dir` (`:1218`-`:1223`), and the fixtures run without a trace. Nothing then clears a stale fixture in a linked worktree, and every owner pushes from one. So a fixture that goes stale there stays stale and runs on every push until somebody traces it from the main checkout.

**Measured at af9a7b085 (main, 0.876.0), in a fresh clone of the main checkout, and re-derived identical at 328336b22 (0.877.0).** The derivation sources the hook's own `READSET_UNIVERSE` span and calls `readset_manifest` and then `readset_committed_digests`, the way the hook does, with `READSET_LOCAL=/dev/null`. The digest is not reimplemented. The population is `/usr/bin/find core/fixtures -mindepth 1 -maxdepth 1 -type d`: 262 directories, 40 without `inputs.decl` and 222 with one. The undeclared fixtures fall out as follows.

- **match, 0.**
- **differs, 16:** architecture-fast-track, changelog-sprint-slot, check-22-spawn-ledger, context-provenance, context-sensor, derivation-capture, dispatch-model-guard, divergence-hard-block, extension-check-adoption, gate-resume, hook-registration-join, requirements-step, resume-whole-read, review-carry-over-clauses, self-update-join-gate, story-evidence-scaffold.
- **nodigest, 21:** check-17-bypass, check-17-counts, check-1c-bypass, check-23-draft-stamps, check-31-ac-falsifiability, check-3b-locked-anchor, check5-anchor-base, ci-gates-resolution, consolidation-residue, context-mode-protect, core-script-boundary, cycle-commits-enforce, deploy-validate-smoke-classification, document-partition, early-exit-reader, gate-verdict-grep-shape, layer-title-join, prepush-ssh-keepalive, retro-compliance-workflow, route-defect-classification, story-fields-derive.
- **unmapped (no committed rows), 3:** check-h1-recursion, check-manifest-bypass, lib.

16 + 21 + 3 = 40. The 37 that are `differs` or `nodigest` all carry a `run.sh`, and the 3 `unmapped` carry none (see the second claim). Control, from the same invocation: none of the 222 declared fixtures has a `.cdig` row, which is correct, since the deriver drops declared-fixture rows at 0.832.0. The reproduction was checked against a revision where a match is expected. At 6c8ea1d9d (0.781.0) the same derivation rated check-22-spawn-ledger, context-sensor and dispatch-model-guard `match`, so the computation can produce a match, and the zero at HEAD is not a computation that can only say `differs`. Earlier readings: the counts were identical at 0b7a7a432 (0.834.0) and at 0e382fc50 (0.832.0), and 887bcba7a (0.835.0) gave 314/45/269 with 20/22/3. The drop to 40 is five deleted undeclared directories: story-evidence-scaffold-mutants, -b, -c, -d and context-provenance-mutants. 0e382fc50 wrote no digest line. It dropped declared-fixture rows, taking the map from 65 digest lines to 20. b37113afc (0.842.0) removed the four story-evidence-scaffold-mutants lines with their directories, and 7e4af67d6 (0.865.0, the last commit to touch the map) added three for the declared apply-restamp-worklist, -b and -c; it wrote none for an undeclared fixture. Every one of the 16 undeclared survivors is byte-identical at e67a2c0cf (0.826.0). Walking back through the map's history, those 16 lines were written in the commits from 525553598 through e67a2c0cf (none of them is present at c96ad3587, and 12 are at 525553598), and none of them has been rewritten since. So no commit has re-traced an undeclared fixture since 0.826.0, and the tree has moved under all 16 of them.

A `differs` or `nodigest` rating is the population that cannot clear on its committed rows. It is not the set dispatched on a given push. A fixture actually re-runs when its local key record is `stale`, and those records live in the shared git dir. Measured by a peer pushing 0.834.0 from a linked worktree: 8 stale units ran on both dress runs, and every one of them was in that revision's 42 (two, story-evidence-scaffold-mutants and -d, have since been deleted). document-partition was listed under "committed rows carry no # digest line", and context-sensor, dispatch-model-guard, divergence-hard-block, gate-resume, hook-registration-join, story-evidence-scaffold-mutants and story-evidence-scaffold-mutants-d under "committed # digest no longer matches this tree".

**Second claim, which is smaller: three undeclared directories have no committed rows at all.** check-h1-recursion, check-manifest-bypass and lib are `unmapped`. None of them carries a `run.sh`: check-h1-recursion and check-manifest-bypass hold `README.md` and `seed.sh`, and lib holds `README.md` and `preamble.sh`. The hook builds its dispatch list only from directories with a `run.sh` (`:2085`-`:2086`), so these three are never dispatched, never traced and never cost a push. The cost is in the census instead. Any count of "fixture directories" taken as `find -mindepth 1 -maxdepth 1 -type d` counts them as fixtures, and the earlier draft of this entry did exactly that when it called all 45 dispatched. What is owed is a population that the hook and every census share. Either the census keys on `run.sh`, or these directories move out of `core/fixtures/`. The receipt below keys on `run.sh`, as the hook does.

Cost, by the recorded loaded cost in `.git/ai-dlc-fixture-durations` of the main checkout. A cost there is a LOADED cost, measured under the pool, and is not comparable with a solo run. 37 of the 40 carry a recorded row and 3 carry none. The top 5 undeclared fixtures:

| fixture | loaded cost (s) |
|---|---|
| document-partition | 129 |
| self-update-join-gate | 58 |
| dispatch-model-guard | 50 |
| gate-resume | 39 |
| check-22-spawn-ledger | 38 |

No raw total is quoted, because a total goes stale. Derive it from that file joined against the stale set.

Owed: stated, not built. Take one of two directions.

1. **Let the in-pool trace run in a linked worktree.** It cannot run there today because the trace clones `.git`, and in a linked worktree `.git` is a gitlink file naming `<common dir>/worktrees/<name>`, not a repository. The trace would have to clone from `git rev-parse --git-common-dir` and check out this worktree's HEAD and working-tree state.
2. **Refresh the stale digests from the main checkout** by running the command the hook prints (`:2010`-`:2012`): `bash core/scripts/derive-fixture-readsets.sh --reconcile`. Then commit the map. Per `operator-rulings.md`, a read-set trace runs as `bash core/scripts/derive-fixture-readsets.sh --list "<names>" --tracer sandbox`, in the main checkout detached at the commit to trace, and the session that owes it runs it. This clears today's 37, but the next stale fixture in a linked worktree recurs, so on its own it is a stopgap, not the fix.

Related: BL-635 (closed at 0.832.0), whose subject was the read-set rows of declared fixtures.

**Known limit (worktrees/).** The in-pool trace copy of a linked worktree omits the common dir's `worktrees/`. This is deliberate: the `gitdir` files under it name the REAL worktrees, and a `git worktree repair` run in the copy would rewrite one of their gitlinks. So in the copy, `git worktree list` shows 1 line, and a branch checked out in another worktree can be checked out there. Measured: 0 of the 37 traced undeclared fixtures read `worktree list`, `main-worktree/` or "already used by worktree" (`grep -rlE` over each fixture directory), against a repo-wide control of 3 fixture files under `core/fixtures` that do. A traced fixture that starts reading `worktree list` would see 1 line.

**Evidence (batch 236, PULLCOST 0.834.0).** PULLCOST's second dress pole was document-partition at 732 s loaded, against 347 s before. It is one of the 8 stale units that ran on both dress runs from a linked worktree. Its fixture directory is byte-unchanged between c7fc78b88 and 0b7a7a432 (`git diff --name-only` over it: 0 paths, against 12 over the whole range). That is the cost this entry names: an unchanged fixture paid in full, on a push that did not touch it, because nothing on that push could clear its stale record.

verify: sh o="$(mktemp -d)" || exit 9; trap 'rm -rf "$o"' EXIT; s="$o/span.sh"; sed -n '/^# READSET_UNIVERSE_BEGIN$/,/^# READSET_UNIVERSE_END$/p' .githooks/pre-push > "$s"; grep -q '^readset_committed_digests() ' "$s" || exit 9; READSET_MAP=.ai-dlc-fixture-readsets.tsv; READSET_LOCAL=/dev/null; . "$s" || exit 9; readset_manifest "$o"; [ -s "$o/.now" ] || exit 9; readset_committed_digests "$o"; [ -s "$o/.cdig" ] || exit 9; n=0; d=0; for p in core/fixtures/*/; do [ -f "${p}run.sh" ] || continue; f="${p%/}"; f="${f##*/}"; st="$(awk -F'\t' -v f="$f" '$1 == f { print $2 }' "$o/.cdig")"; if [ -f "${p}inputs.decl" ]; then d=$((d+1)); [ -z "$st" ] || exit 9; else [ "$st" = match ] || n=$((n+1)); fi; done; [ "$d" -gt 0 ] || exit 9; FXROOT=core/fixtures/; q="$o/prep.sh"; sed -n '/^readset_pool_trace_prep() /,/^}$/p' .githooks/pre-push > "$q"; grep -q 'PT_LIST=' "$q" || exit 9; . "$q" || exit 9; readset_deriver_path() { printf '%s\n' "$o/dv"; }; [ -x /usr/bin/log ] || exit 9; b="$o/bin"; mkdir "$b" || exit 9; for t in sandbox-exec python3; do printf '#!/bin/sh\nexit 0\n' > "$b/$t" && chmod +x "$b/$t" || exit 9; done; unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_CONFIG_PARAMETERS; g="$o/g"; mkdir "$g" && git -C "$g" init -q && git -C "$g" -c core.hooksPath=/dev/null -c commit.gpgsign=false -c user.name=r -c user.email=r@r commit -q --allow-empty -m r && git -C "$g" -c core.hooksPath=/dev/null worktree add -q "$o/wt" >/dev/null 2>&1 || exit 9; pt() { ( cd "$1" || exit 9; mkdir -p "$o/x$2" && printf 'zzrcpt\n' > "$o/x$2/.trace" || exit 9; PATH="$b:$PATH"; readset_pool_trace_prep "$o/x$2" >/dev/null 2>&1; printf '%s' "$PT_LIST" ); }; [ "$(pt "$g" m)" = zzrcpt ] || exit 9; m=0; [ "$(pt "$o/wt" w)" = zzrcpt ] || m=1; [ "$n" -eq 0 ] && [ "$m" -eq 0 ] || exit 1; exit 0

## BL-706 — no reconcile step runs the derivation differential on every pull, so a consumer whose pulls never hit a derivation never gets an owed-derivations record

**NOTE.** Filed by ai-dlc-77 [ab5b1f] from the BL-668 build (batch 236), lead ai-dlc-c8 ruled it a separate cost question with no owner this batch. BL-668 made `reconcile/derivation-differential.sh --record-owed` create the record on every run, so an absent record now means "no reconcile has ever measured this tree". But `reconcile/apply.sh` (~:1346, ~:1495) emits the differential only as a `WORKLIST artifact-derivations` row, and only when a recorded `derived` command names a core path the range changed; the differential refuses on zero derivations, and nothing runs it unconditionally. So a consumer whose pulls never touch a derivation keeps printing `check-owed-derivations.sh`'s absent line. That line is correct (the tree was genuinely never measured), so this is a cost question, not a defect. A per-pull "no changed path, so nothing owed" record was considered and declined (c8): a derivation can read files its command line never names, so that record would be written from intent, not from a measurement.

Owed: decide whether every pull runs the differential (two validator passes per pull) so the record always exists, measuring that cost on a reference consumer before deciding. No owner this batch.

verify: manual

## BL-697 — I110 reads any backticked lowercase token within six lines after a line containing `In-Flight` as a taught In-Flight status, so prose that teaches no status fails the pregate

**NOTE.** `i110_tokens` (`scripts/validate-enforcement-map.sh`, header of I110 near `:11269`, function near `:11345`) greps every line containing `In-Flight` with `-A6` and collects each backticked lowercase token in that window as a TAUGHT status. The window keys on a mention of the word, not on the status column, so a sentence that merely names the row opens a six-line window in which any backticked token is read as a status. Measured at 0.876.0: `core/skills/ai-dlc/steps/ui-direction.md:28` was reworded to "An absent artifact at the path in the brief (the same value as the In-Flight row and the join) is", a backticked `ux` sat within six lines below it, and I110 reported `ux` as taught-but-unwhitelisted. That failed the pregate and, downstream, validator-fork-budget, whose traced run exited 1. The release worked around it by rewording the sentence; the grammar still fires for the next author who mentions the row near any backticked token.

Owed: stated, not built. Either anchor the teach on the status COLUMN context (the table schema or a `status` mention) rather than on any `In-Flight` mention, or exclude role and agent names derived from the role vocabulary. Before either ships, measure the false-positive set: every token the current grammar collects over `core/skills/ai-dlc` and `core/hooks`, split into real statuses and non-statuses, and show the chosen anchor keeps the first group and drops the second.

verify: sh V="${I110_V:-scripts/validate-enforcement-map.sh}"; f=$(sed -n '/^i110_tokens() {/,/^}/p' "$V"); [ -n "$f" ] || exit 9; T=$(mktemp -d "${TMPDIR:-/tmp}/bl697.XXXXXX") || exit 9; printf 'the same value as the In-Flight row and the join\n\nplain line\n\nplain line\n`ux` is a role name\n' > "$T/a.md"; printf 'In-Flight status\n`stopped` is a taught status\n' > "$T/b.md"; o=$(eval "$f"; i110_tokens "$T") || exit 9; grep -qxF stopped <<<"$o" || exit 9; grep -qxF ux <<<"$o" && exit 1; exit 0

## BL-712 — the supersession reader splits a three-field TAB row with `IFS="$TAB" read`, so a declaration with no `since_core_version` and a `settings_env_key` would land the env key in the since variable

**NOTE, latent.** Id allocated by lead ai-dlc-37; filed by peer session ai-dlc-c0 (batch 236), found while building BL-711.
- **The read site.** `core/skills/ai-dlc-update/reconcile/layer-drift.sh:1986`: `while IFS="$TAB" read -r s_shadows s_since s_env; do`. The producer is `supersessions_of` (`layer-drift.sh:727`-`761`), which prints `shadows<TAB>since<TAB>settings_env_key` at `:733` and `:759`. It initialises `si=""` and `en=""` per declaration (`:734`) and does not default either, so an absent `since_core_version:` line is emitted as an empty middle field.
- **The collapse.** The same IFS-whitespace collapse as BL-711: a tab is IFS whitespace, so `read` merges adjacent tabs. Measured by sourcing the real `supersessions_of` over a literal contract under a mktemp: a declaration with `since_core_version: "0.1.0"` and `settings_env_key: AI_DLC_KEY_A` read as `since=[0.1.0] env=[AI_DLC_KEY_A]` (control); one with `settings_env_key: AI_DLC_KEY_B` and no since read as `since=[AI_DLC_KEY_B] env=[]`. The empty-THIRD case (`S<TAB>V<TAB>`) does not collapse, because a trailing delimiter is stripped without moving a value. The empty-FIRST case (`<TAB>V<TAB>K`) collapses, but the producer only prints a row when `sh != ""` (`:733`, `:759`), so the first field is never empty.
- **Latent or reachable: LATENT in the shipped contract, unguarded by any check.** All 6 `- shadows:` declarations under `override_supersessions:` in `core/skills/ai-dlc/layer-contract.yaml` carry `since_core_version:` (awk count over the block: shadows 6, since 6, env 4), and no script or schema validates the field: `since_core_version` appears in no `.sh` or `.json` outside `layer-drift.sh` and the contract's own comment (`layer-contract.yaml:301`). So a future declaration with an env key and no since is accepted and reaches `:1986` as the broken row above. Its effect would be the wrong branch at `:2084`/`:2091`, which test `s_env`: the row would read as an adoption needing no configuration, with the env key printed as the core version, instead of prescribing the settings change.
- **Owed:** stated, not built. Read each row whole and split by parameter expansion, the split BL-711 used: `IFS= read -r line; a="${line%%"$TAB"*}"; rest="${line#*"$TAB"}"; b="${rest%%"$TAB"*}"; c="${rest#*"$TAB"}"`, applied to the three-field line at `:1986`. Seed a fixture arm with a declaration carrying `settings_env_key` and no `since_core_version`, beside the control carrying both.

verify: manual

## BL-707 — prepush-pool-depth's `obs_d0_max` reads a 0.3s in-flight window by ls-counting a flight dir, so a load burst fails it with no hook defect

**DEFECT.** Filed by peer session ai-dlc-c0 (batch 236 POOLHOOKS), id allocated by lead ai-dlc-c8. `core/fixtures/prepush-pool-depth/run.sh:171` drives six depth-0 stubs that each `sleep 0.3` and records the peak of `ls "$PD_FLIGHT" | wc -l` (`:58-:59`, read by `maxflight` at `:83`) as `obs_d0_max`, wanting 6 (`:211`). Six workers are in flight together only if all six start inside one 0.3s window, so a loaded box fails the cell with no hook defect. Measured on 0.871.0's pre-run with 52 units launched at once: the `.githooks` half read 3 against 6, and because every mutant's moved-set includes that cell, one wrong reading surfaced as 11 FAILs; the `git-hooks` half of the same run passed the arm and all its mutants, and I66 holds the two pool blocks byte-identical. A second solo run on 0.871.0 at load 85 read 5 against 6, again in the `.githooks` half only. Three interleaved pairs at load 39-61, main `82b28696c` (which carries none of 0.871.0's change) launched beside 0.871.0: main went red in 1 of 3 (the `not-exported` mutant's run moved `obs_d0_max`, a `.githooks`-half cell, while its baseline read ok), and 0.871.0 was green in 3 of 3. The `git-hooks` half was clean in all six runs.

Owed: the depth-0 width is asserted by a condition that does not depend on scheduling (each stub blocks until all six have entered, under a bounded wait, or the arm reads the dispatched width instead of an observed overlap), with a mutant showing the arm still catches a pool capped below 6.

verify: manual

## BL-708 — ten fixture arms still report ok with a required tool missing, because the call's stderr is discarded or two empty command substitutions compare equal, so PATH restriction cannot catch them

**DEFECT.** Filed by peer session ai-dlc-c0 (batch 236 BL-676), id allocated by lead ai-dlc-37. BL-676's restricted-PATH sweep (each fixture run under the shipped `hermetic-run.sh` with its PATH cut to its `tools.decl` farm) turns a missing tool into a red unit only where the arm reads that tool's output. Measured under that runner at c2991da155cbc2441e22b55373bb841df5785b05, ten arms ran with the tool absent and still reported ok:

- `apply-legacy-script-path`: `run.sh:307` and `:310` run `cksum` (command not found), so `before` and `after` are both empty and the comparison at `:311` of two empty strings cannot fail.
- `backlog-ledger`: `run.sh:772` has both `tail` substitutions empty, so the last-conserves conjunct passes vacuously.
- `relocation-preclassify`: `run.sh:243` runs `cmp` (command not found), so the FIXTURE STALE guard can no longer fire.
- `route-read-required`: `run.sh:130` runs `cp` (command not found), the routed transcript is never made, and the arm still reports ok.
- `handoff-completion-assertion`: `run.sh:2089` runs `if cmp -s "$HOOKS_DIR/$tgt" "$d/$tgt"`, the FIXTURE STALE "mutation matched nothing" guard; with `cmp` absent the test is false on every mutation, so the guard can never fire. Measured under the BL-676 runner (dcb0aeb8c on b236-bl676): 55 `run.sh: line 2089: cmp: command not found` lines and the run still reports PASS. This release declares `cmp` for that fixture; the arm itself is owed here.
- `plan-rotate`: `scripts/plan-rotate.sh:689-690` pipes into `md5`. With md5 absent, both digests are empty and equal, so the multiset arm cannot fire, and mutant m3 survives (`did not trip the multiset arm alone (exit 0, arm1-pass=yes)`) under the BL-676 runner. This release declares `md5`; the arm fix is owed here.
- `budget-summary-verdict`: `core/scripts/validate-artifact-budget.sh:1265` skips on `command -v jq`, so with jq absent the F9 back-dated-row check silently does not run. This release declares `jq`; the arm fix is owed here.
- `backlog-receipt-binding`: `run.sh:1369` evaluates BL-040's receipt as `bash -c "$RJ_REC"` and reads only its exit; with `wc` absent the receipt's `[ "$(printf '%s\n' "$S" | wc -l)" -lt 200 ] || exit 2` sees `[ "" -lt 200 ]`, returns 2, and the scan at `run.sh:1339-1363` (`rj_scan`) scores every seed OWNED (`SCANNED 10 BLIND 0 OWNED 10`), so the receipt-blind arm cannot fire. This release declares `wc`; the arm fix is owed here.
- `readset-skip` (all four shards): `run.sh:1847` gates the BL-686 psfail, nofallback and readerself-psfail arms on `command -v perl` and `uname -s` reading Darwin. With both undeclared, uname fails silently, the gate reads "not Darwin" and `:1851` prints ok, so the anti-SKIP assertion is vacuous. This release declares `perl` and `uname` in all four shards; the arm fix is owed here.
- `hermetic-runner` B4-B6: they do not assert the stub's `rc=0 ` the way B2 does (`run.sh:336`), so on their own they cannot tell a missing `cat` from the near-miss sentinel they test. Not fixed here.

Candidate mechanism, stated not proposed: a runner-side scan of a fixture's captured output for a `: command not found` line, failing the unit. Its false-positive set under today's PATH, measured read-only over the 223 shipped-runner logs of the BL-676 sweep at c2991da155cbc2441e22b55373bb841df5785b05 (both halves), where no tool is missing: 0 logs carry a `: command not found` line and 0 carry an `env: ... No such file or directory` line. Under that PATH the only line the scan could catch is a deliberate absence test, which prints it whatever the runner, so the zero says the scan would fail no fixture that passes today and nothing more. It is not the scan's false-positive set under the restricted runner BL-676 ships, which these logs cannot measure. The 223 restricted-runner logs of the same sweep carry the line in 66 logs, for scale only. Controls in the same invocation: an impossible token read 0 in both sets, and the positive control is `cksum: command not found` in the restricted `apply-legacy-script-path.log` (its `run.sh:307`). The looser pattern `not found` hits 3 shipped logs (`backlog-ledger`, `enforcement-map-sites-b`, `process-rule-pins`), all of them test-name prose on `ok` lines and none a shell diagnostic, so the scan must key on `: command not found` and not on the bare phrase. Two limits: the scan cannot see the ten instances above on their own run, because their tool is present under today's PATH and only the restricted run exposes it; and a fixture that intentionally probes a missing tool (for example `handoff-resume-guard`, which shadows `jq`) would need to keep its miss out of the captured output, which the shipped logs show none does today.

Owed: the fix for those 10 arms, so that each arm fails when its tool is missing (capture and assert the tool's output is non-empty, or check the tool's exit status, instead of discarding stderr or comparing two possibly empty strings).

verify: manual

## BL-709 — a hermetic-run.sh change re-keys only the declared fixtures whose inputs.decl names the runner, so a runner change gates on those and skips every other declared fixture on its old key

**DEFECT.** Filed by peer session ai-dlc-c0 (batch 236 BL-676), id allocated by lead ai-dlc-37. The verdict-store ident hashes the runner's `HR_SANDBOX_BEGIN`..`END` span (`readset_vs_ident`, `.githooks/pre-push:1483-1487`), so a pass recorded under an older runner is not reused from the store. But the per-fixture key decision (`.githooks/pre-push:1882-1892`) returns `skip` for a declared fixture whose recorded key rows are unchanged, before the store is consulted, and `readset_verdicts` only turns `run` into `skip` (`:1738`), never the reverse. The runner is in a declared fixture's key rows only when that fixture's inputs.decl names `core/scripts/hermetic-run.sh`.

Measured at origin/main c2991da155cbc2441e22b55373bb841df5785b05 and re-derived in the b236-bl676 tree (dcb0aeb8c) with `grep -l 'core/scripts/hermetic-run.sh' core/fixtures/*/inputs.decl`: 7 declared fixtures name the runner (census-hermetic-coverage, hermetic-runner, readset-skip, readset-skip-b, readset-skip-c, readset-skip-d, self-update-fixture-log). Control in the same grep: 9 inputs.decl files name `.githooks/pre-push` on a non-comment line (13 files mention it once comment lines are counted), and an impossible token reads 0. The declared population is 223 `inputs.decl` files.

Consequence: BL-676's runner change (dcb0aeb8c) gates on those 7 plus the fixtures whose tools.decl that release edits; every other declared fixture skips on its pre-change key, so the gate does not exercise the new runner on them. That release covers them by a direct pre-run of every declared fixture through the new runner (its acceptance (a)).

Owed, with the choice left to whoever builds it: (B) put the runner's span into every declared fixture's key (a hook change inside the I66-bound span), or (C) carry a runner digest in each declared fixture's key record so a runner change moves every declared key. Cost measurement for either: the number of declared fixtures re-run per runner change, today 7 and under either remedy every declared fixture (223 `inputs.decl` files in the b236-bl676 tree).

verify: manual

## BL-714 — every EXTENSION-TITLE-MATCHES-CORE (LC-E19) row is re-emitted as a WORKLIST item on every pull with no register lookup, so a consumer's "keep as is" on a pre-existing heading never sticks and the same rows hold the stamp each time

**NOTE.** Relayed by ai-dlc-5d from graph; site re-derived on the distribution by lead ai-dlc-37; id allocated by ai-dlc-37; filed by peer session ai-dlc-c0 (batch 236), with BL-713's release.

`core/skills/ai-dlc-update/reconcile/apply.sh:2014` runs `say WORKLIST extension-title-match "$ext" "$tdetail"` for every LC-E19 row the layer-drift output carries, with no register lookup; the hook-drift arm just above it does consult the register. The design comment at `:2006`-`:2009` defers "promotion to the register" to "a later release's decision once this set has been burned down" — but "keep as is" is a legitimate disposition for a PRE-EXISTING consumer heading, so nothing ever burns the set down, and the same rows hold the stamp on every pull.

Evidence, relayed by ai-dlc-5d and not re-measured by this filing: graph re-disposed the same 8 LC-E19 rows on its 0.881 and 0.883 pulls, twice on 2026-10-19 (graph session transcript 48918adc, lines 2913 and 2917). Graph's 0.881 disposition lives only in its own prose; its register carries 0 TITLE-clause rows against 1029 LC-E lines.

Dedupe, re-derived with `grep -c` at origin/main 2cb29a586 and on b236-bl676: "TITLE-MATCHES-CORE" in docs/backlog.archive.md 10 hits (the lead read them as all about the arm's construction, its WARN level and its title join, none about re-asking); in docs/backlog.md 0; control BL-583 in the archive 6.

Owed, the choice left to the builder: promote LC-E19 to the register with a still-additive verdict, the way the hook-drift arm already reads it; or downgrade PRE-EXISTING rows to NOTE so they no longer hold the stamp. Either way, a fixture arm: a consumer whose register records a disposition for an LC-E19 row is not re-asked on the next pull, with an undisposed row as the control.

verify: manual

## BL-715 — the remediator shard join classifies a part's `siblings:` field only at the join, so a remediator cannot check its own part before returning and a format slip costs a full re-dispatch round

**NOTE.** Relayed by ai-dlc-5d from graph S319; site re-derived on the distribution by lead ai-dlc-37; id allocated by ai-dlc-37; filed by peer session ai-dlc-c0 (batch 236), with BL-713's release.

`core/scripts/join-remediator-shards.sh` classifies a `repaired` entry's `siblings:` field as BADSIB only inside the join: the classifier's row is documented at `:886`, emitted at `:918`, and refused at `:1153`. Its modes are the join itself, `--rerun <part>.md@<ISO>` (`:30`), `--sources` and `--escalations` (`:34`, `:256`); none of them checks one part on its own. The contract is stated in `core/team-roles/remediator.md` (`:42`, `:62`-`:63`), and a remediator has no way to run the join's own classifier against its part before it returns.

Evidence, relayed by ai-dlc-5d and not re-measured by this filing: in graph S319 at 20:20 EDT on 2026-10-19, parts 2, 6, 14 and 15 of 19 were refused (13 REFUSED lines, graph session transcript a367e62c, line 522); record-only re-runs followed and the join succeeded at 20:24 (line 624). That is 4 extra agent runs and about 3.5 minutes, with the contract stated and 21% of parts still missing it.

Dedupe, re-derived with `grep -c` at origin/main 2cb29a586: "BADSIB" 0 in docs/backlog.archive.md and 0 in docs/backlog.md; "join-remediator-shards" 37 in the archive, none about a per-part check; control BL-583 6.

Owed, the mechanism left to the builder: a per-part check mode on `join-remediator-shards.sh`, or the remediator role running the join's own field classifier on its part before it returns. It must be the join's code, not a restatement of the four accepted forms. A fixture arm: a part whose `siblings:` field is a near-miss spelling is refused by the per-part check with the same BADSIB detail the join gives, with a well-formed part as the control.

verify: manual

## BL-716 — after a parallel repair fan-out, every SERIAL-REQUIRED item goes to one serial remediator, so a 19-shard round that finishes in 8 minutes waits an hour on one agent

**DEFECT (efficiency).** Relayed by ai-dlc-5d from graph S319; dedupe re-derived on the distribution by lead ai-dlc-37; id allocated by ai-dlc-37; filed by peer session ai-dlc-c0 (batch 236), with BL-713's release.

`core/scripts/join-remediator-shards.sh:741` defines SERIAL-REQUIRED (parts mode only) as the count of `repaired` entries with a real edit, each owing the cross-file sibling grep and moved-cite check that no shard can run, and the procedure dispatches ONE serial remediator whenever that count or ESCALATED-COUNT is above 0. However many cross-part items there are, one agent works them all, in sequence.

Evidence, relayed by ai-dlc-5d and not re-measured by this filing (load 2–28, so the wall clock is an observation, not a timing): graph S319 stories, 2026-10-19. The 19 parallel shards finished in about 8 minutes (20:10–20:17 EDT); the join reported SERIAL-REQUIRED 148; the one serial agent ran 62 minutes (20:24:49–21:26:53, 172 tool calls, 77 Edit), while the lead re-armed its wait beat 7 times and ran nothing else. That is 148 items in 62 minutes, about 0.42 minutes per item, as an observation; no per-item baseline exists to compare it against.

Prior art, not a duplicate: archived **BL-543** (LANDED v0.815.0, verified a88f88d4) cut the serial remediator's DISCOVERY work — `core/scripts/serial-remediation-worklist.sh` now derives its replaced-text HITs and MOVED-CITEs from the splitters' pre-repair copies instead of the agent finding them by hand — on S319 rounds whose serial remediators took 42, 29 and 31 minutes. Those rounds recorded no SERIAL-REQUIRED counts (BL-543 records one round's 28 appends and 48 edits only), so they are not a baseline for tonight's figure and are not compared with it. BL-543 did not change the COUNT: every cross-part item still goes to the one agent, and that is what this filing owes.

Dedupe, re-derived with `grep -c` at origin/main: "SERIAL-REQUIRED" 3 in docs/backlog.archive.md and 0 in docs/backlog.md; "serial remediator" 35 in the archive, the relevant one BL-543; control BL-583 6.

Owed, the mechanism left to the builder: partition the SERIAL-REQUIRED items by the parts they touch, so disjoint sets run as parallel serial lanes and each lane keeps the serial guarantee within its own set. A fixture arm (or receipt): a seeded join whose two disjoint item sets dispatch to two lanes, while an overlapping pair stays in one lane.

verify: manual
