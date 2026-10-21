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

verify: manual

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

## BL-716 — after a parallel repair fan-out, every SERIAL-REQUIRED item goes to one serial remediator, so a 19-shard round that finishes in 8 minutes waits an hour on one agent

**DEFECT (efficiency).** Relayed by ai-dlc-5d from graph S319; dedupe re-derived on the distribution by lead ai-dlc-37; id allocated by ai-dlc-37; filed by peer session ai-dlc-c0 (batch 236), with BL-713's release.

`core/scripts/join-remediator-shards.sh:741` defines SERIAL-REQUIRED (parts mode only) as the count of `repaired` entries with a real edit, each owing the cross-file sibling grep and moved-cite check that no shard can run, and the procedure dispatches ONE serial remediator whenever that count or ESCALATED-COUNT is above 0. However many cross-part items there are, one agent works them all, in sequence.

Evidence, relayed by ai-dlc-5d and not re-measured by this filing (load 2–28, so the wall clock is an observation, not a timing): graph S319 stories, 2026-10-19. The 19 parallel shards finished in about 8 minutes (20:10–20:17 EDT); the join reported SERIAL-REQUIRED 148; the one serial agent ran 62 minutes (20:24:49–21:26:53, 172 tool calls, 77 Edit), while the lead re-armed its wait beat 7 times and ran nothing else. That is 148 items in 62 minutes, about 0.42 minutes per item, as an observation; no per-item baseline exists to compare it against.

Prior art, not a duplicate: archived **BL-543** (LANDED v0.815.0, verified a88f88d4) cut the serial remediator's DISCOVERY work — `core/scripts/serial-remediation-worklist.sh` now derives its replaced-text HITs and MOVED-CITEs from the splitters' pre-repair copies instead of the agent finding them by hand — on S319 rounds whose serial remediators took 42, 29 and 31 minutes. Those rounds recorded no SERIAL-REQUIRED counts (BL-543 records one round's 28 appends and 48 edits only), so they are not a baseline for tonight's figure and are not compared with it. BL-543 did not change the COUNT: every cross-part item still goes to the one agent, and that is what this filing owes.

Dedupe, re-derived with `grep -c` at origin/main: "SERIAL-REQUIRED" 3 in docs/backlog.archive.md and 0 in docs/backlog.md; "serial remediator" 35 in the archive, the relevant one BL-543; control BL-583 6.

Owed, the mechanism left to the builder: partition the SERIAL-REQUIRED items by the parts they touch, so disjoint sets run as parallel serial lanes and each lane keeps the serial guarantee within its own set. A fixture arm (or receipt): a seeded join whose two disjoint item sets dispatch to two lanes, while an overlapping pair stays in one lane.

Measured input for the partition, graph-watch, batch 238. These figures come from the graph watcher's scratch run of `core/scripts/serial-remediation-worklist.sh` over s319's stories party repair, relayed by the batch-238 lead; this filing did not re-measure them. The run's SUMMARY read `files 19 replaced 115 hits 135 moved-cites 1`, over 19 parts and 148 SERIAL-REQUIRED entries. Taking the parts each item touches as edges, the lane components are: edit only, 19; edit ∪ MOVED-CITE, 18; edit ∪ HIT, 1. One boilerplate line merges every lane: the sprint-title `architecture_refs` line that every story carries (`story-2-1:8-10`, hunk `6.md#F-9`), which HITs line 9 of 18 other stories. On this corpus, a partition on HIT edges therefore yields one lane, the status quo, unless a HIT on a line common to all parts is excluded from the edge set. The builder must decide whether such a common-line HIT can be excluded safely, or must be routed as a single fan-in item.

verify: manual

## BL-725 — the recover gate's per-call `[ -w "$STATE_DIR" ]` stand-down passes on a writable directory whose stage write fails (a full disk), so the snapshot Read is allowed, the stage stays `snapshot`, and every later call is denied FIRST

**DEFECT.** The filing is promised by 0.891.0's CHANGELOG ("Finding: an ENOSPC stage-write failure still holds the gate at `snapshot`", `CHANGELOG.md:42-44`). It came out of the BL-688 work and was relayed by graph-watch, batch 238; the batch-238 filing hand measured and filed it.

`core/hooks/ai-dlc-recover-gate.sh:342` stands the gate down only when `$STATE_DIR` is not writable. The snapshot arm's stage write at `:417` is `{ printf 'step\n' >"${PROGRESS}.$$" && mv -f ...; } 2>/dev/null || rm -f ... || true`, followed by `exit 0`. A write that FAILS in a writable directory (ENOSPC, a quota, EFBIG) is therefore swallowed and the Read is allowed. `:389` then finds no progress file and defaults `STAGE` to `snapshot`, and `:450` denies the next call with the FIRST-call text. That text's remedy is the snapshot Read, which is allowed again and again advances nothing. The bounded escape covers only the advisor stage, so the lead is wedged.

Measured on a seeded tree with the write forced to fail by `ulimit -f 0`, with SIGXFSZ ignored so that the write returns an error the way ENOSPC does: the following Grep is denied "your FIRST tool call". The identical seed without the limit is not denied. No directory-mode test can see a failed write, so BL-688's shape cannot be extended to cover it.

Owed: when the stage write fails, the gate stands down for the call AND for the recovery (unlinking the marker needs no free space). Alternatively, it records that the snapshot Read happened by a means that does not depend on that write succeeding. The fix is the owner's to choose.

verify: sh H=core/hooks/ai-dlc-recover-gate.sh; [ -f "$H" ] || exit 9; command -v jq >/dev/null || exit 9; T="$(mktemp -d)"; mkdir -p "$T/_bmad-output" "$T/steps"; printf "s\n" > "$T/_bmad-output/pipeline-snapshot.md"; printf "x\n" > "$T/steps/x.md"; printf "step_file_resolved=1\nsnapshot_path=_bmad-output/pipeline-snapshot.md\nstep_file=steps/x.md\n" > "$T/_bmad-output/.recover-fired"; RS="{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$T/_bmad-output/pipeline-snapshot.md\"}}"; GL="{\"tool_name\":\"Grep\",\"tool_input\":{\"pattern\":\"a\"}}"; c0="$(CLAUDE_PROJECT_DIR="$T" bash "$H" <<<"$GL" 2>/dev/null)"; grep -q "FIRST tool call" <<<"$c0" || exit 9; CLAUDE_PROJECT_DIR="$T" bash -c "trap \"\" XFSZ; ulimit -f 0; bash \"$H\"" <<<"$RS" >/dev/null 2>&1; [ -f "$T/_bmad-output/.recover-fired" ] || exit 0; c1="$(CLAUDE_PROJECT_DIR="$T" bash "$H" <<<"$GL" 2>/dev/null)"; ! grep -q "FIRST tool call" <<<"$c1"

## BL-726 — `merge-adversarial-shards.sh` copies a mis-stamped shard's `invoked_at` into the merged pass, so Check 24's chronology arm fails on a merge the merge accepted, and the lead hand-edits the provenance record

**DEFECT.** Raised from graph `_bmad-output/planning-artifacts/s319/test-strategy-adversarial-p2.md` and graph commit `ded7e6a18` by graph-watch, batch 238; measured and filed by the batch-238 filing hand.

`core/scripts/merge-adversarial-shards.sh:338` makes the merged `invoked_at` the EARLIEST shard's, and `:1237` takes that minimum by `at_key`. The only check on a shard's own `invoked_at` is its ISO shape (`:465-466`). Two records that could bound it go unused for this purpose. The dispatch's spawn-ledger `ts` is read only to bind `--rerun` starts within `BACKDATE_TOL_S` (`:1124-1155`, BL-598). The shard file's mtime is read only to print `shard_wall` (`:1314-1316`).

Graph s319 test-strategy pass 2 recorded `shard_wall: … 5=2026-10-20T19:40:00Z/2026-10-20T21:23:19Z …` at p2.md:617, a claimed start 1h43m before the shard's own write. The same line records `cross-1=2026-10-20T21:40:00Z/2026-10-20T21:23:50Z`, a claimed start 16 minutes after its mtime. The merge accepted both and wrote `invoked_at: 2026-10-20T19:40:00Z`, which predates pass 1. At 21:52:05Z Check 24 refused: "FAIL (G -- CHRONOLOGY): …test-strategy-adversarial-p2.md claims to follow …-p1.md, but it was written FIRST". This refusal was relayed by the batch-238 lead.

Graph's lead hand-corrected the merged line to `2026-10-20T21:20:30Z` in `ded7e6a18`. `shards/test-strategy-p2/5.md` still carries `19:40:00Z`, so a fresh merge of that shard directory writes the bad value again. An in-place re-merge refuses instead, because an existing output that differs exits 2 (`:345-346`). Either way, the pass file's provenance is a lead edit.

Owed, the owner's to choose: refuse a shard whose `invoked_at` is earlier than its credited dispatch's spawn-ledger `ts` by more than `BACKDATE_TOL_S`, or later than its own write, naming the shard and both times. Or derive the merged `invoked_at` from the dispatch records rather than from the shards' self-reports.

verify: sh L=core/fixtures/adversarial-shard-merge/lib.sh; [ -f "$L" ] || exit 9; NAME=bl-r1; . "$L" >/dev/null || exit 9; export HR_SPAWN_TS=2026-08-24T15:00:00Z; c="$(b3_world)" || exit 9; run_merge "$MERGE" "$c"; [ "$RC" -eq 0 ] && grep -qx 'invoked_at: 2026-08-24T15:01:19Z' "$(out_of "$c")" || exit 9; d="$(b3_world)" || exit 9; shard "$d" 1 2 EXIT_CONDITION_MET 1 "" "2026-08-24T13:00:00Z"; run_merge "$MERGE" "$d"; [ "$RC" -eq 2 ] && exit 0; [ "$RC" -eq 0 ] || exit 9; grep -qx 'invoked_at: 2026-08-24T13:00:00Z' "$(out_of "$d")" && exit 1; exit 0

## BL-727 — `ai-dlc-derivation-capture.sh` refuses a record's re-derivation, because writing the same `$ ` command again re-arms the earlier stale fence and the hook's masked copy sits outside `s<N>/`, where supersession never fires

**DEFECT.** Raised from graph `_bmad-output/pipeline-snapshot.md` at `ded7e6a18` (the PC CANDIDATES bullet) by graph-watch, batch 238; measured and filed by the batch-238 filing hand.

0.803.0 (BL-588) lets a later byte-identical `$ ` command in a review or repair record supersede an earlier one (`core/scripts/validate-artifact-derivations.sh:63-83`). The validator's own header records the write-time gap at `:84-86`: "NOT COVERED: `ai-dlc-derivation-capture.sh` validates a masked copy under a `mktemp -d` parent, never under `s<digits>/`, so supersession never fires there". No entry tracks it.

The gap is wider than an old fence false-alarming. `core/hooks/ai-dlc-derivation-capture.sh:413-416` marks a pair as touched when any payload line equals one of its lines. Re-deriving a stale figure means writing the same command again, so the earlier stale pair is touched too. The masked copy is validated under a `mktemp -d` parent (`:506-507`), where supersession cannot fire, so the hook exits 2 with `FAIL (STALE)` on the earlier line.

Measured in a scratch record `s1/stories-repair-p1.md`: the validator printed `SUPERSEDED: …:4 by …` and exited 0. The hook, on an Edit appending the correct re-derivation, exited 2 with `FAIL (STALE): …:4 … recorded: beta`. Control: the same edit with a non-stale earlier fence exited 0. Graph's s319 lead reported false alarms on record lines that the full validator reports as superseded; that report is relayed and was not re-measured here.

Owed: the hook judges a record's touched pairs with the validator's supersession, for example by placing the masked copy at the record's own `s<N>/<basename>` relative path or by passing the record's identity through. A write that adds a stale block must still be refused, and the receipt exits 3 if it is not.

verify: sh set -uo pipefail; H=core/hooks/ai-dlc-derivation-capture.sh; V=core/scripts/validate-artifact-derivations.sh; [ -f "$H" ] && [ -f "$V" ] && command -v jq >/dev/null || exit 9; w=$(mktemp -d) || exit 9; mkdir -p "$w/p/scripts/ai-dlc" "$w/p/_bmad-output/planning-artifacts/s1" "$w/p/.claude" || exit 9; cp "$V" "$w/p/scripts/ai-dlc/" || exit 9; F="$w/p/_bmad-output/planning-artifacts/s1/stories-repair-p1.md"; printf '# r\n\n```derived\n$ echo alpha\nbeta\n```\n\nlater\n\n```derived\n$ echo alpha\nalpha\n```\n' > "$F"; o=$(cd "$w/p" && AI_DLC_PROJECT_ROOT="$w/p" bash scripts/ai-dlc/validate-artifact-derivations.sh "$F" 2>&1) || exit 9; case "$o" in *SUPERSEDED:*) ;; *) exit 9 ;; esac; P=$(jq -nc --arg f "$F" '{tool_name:"Edit",tool_input:{file_path:$f,old_string:"later\n",new_string:"later\n\n```derived\n$ echo alpha\nalpha\n```\n"}}'); printf '%s' "$P" | CLAUDE_PROJECT_DIR="$w/p" bash "$H" >/dev/null 2>&1; rc=$?; G="$w/p/_bmad-output/planning-artifacts/s1/stories-repair-p2.md"; printf '# r\n\nnew\n\n```derived\n$ echo gamma\ndelta\n```\n' > "$G"; Q=$(jq -nc --arg f "$G" '{tool_name:"Edit",tool_input:{file_path:$f,old_string:"new\n",new_string:"new\n\n```derived\n$ echo gamma\ndelta\n```\n"}}'); printf '%s' "$Q" | CLAUDE_PROJECT_DIR="$w/p" bash "$H" >/dev/null 2>&1; [ $? = 2 ] || exit 3; [ "$rc" = 0 ] && exit 0; [ "$rc" = 2 ] && exit 1; exit 9

## BL-728 — the derivation allowlist refuses a backtick inside single quotes and any `git -C <dir> <read-only-sub>`, so an adversary's correct fenced command is refused at write time and rewritten

**NOTE.** Raised from graph `_bmad-output/pipeline-snapshot.md` at `ded7e6a18` (the PC CANDIDATES bullet) by graph-watch, batch 238; measured and filed by the batch-238 filing hand.

`core/scripts/validate-artifact-derivations.sh:158-162` refuses any command containing a backtick before its quote-aware split runs. So `grep -c -F 'a`b' d.txt`, which bash runs with no substitution, fails `FAIL (ALLOWLIST)`. `:237-238` reads the git subcommand as word 2, so `git -C sub rev-parse …` fails as `'git -C' is not a read-only git subcommand`. The capture hook surfaces both refusals at write time. Measured in a scratch repo: both commands were refused, against `git rev-parse --is-inside-work-tree` passing in the same run.

Direction, for the owner: test the backtick under the existing quote scan, so it is refused only unquoted or inside double quotes, and skip `-C <dir>` before reading the subcommand, deciding whether `<dir>` must stay inside the root. The receipt exits 1 at the backtick arm and 2 at the `git -C` arm. If the owner rules that `git -C` stays refused, drop the receipt's `g.md` arm.

verify: sh set -uo pipefail; V=core/scripts/validate-artifact-derivations.sh; [ -f "$V" ] && command -v git >/dev/null || exit 9; R=$PWD; w=$(mktemp -d) || exit 9; mkdir -p "$w/p/.claude" "$w/p/sub" || exit 9; git -C "$w/p" init -q . || exit 9; printf 'a`b\n' > "$w/p/d.txt"; printf '# x\n\n```derived\n$ git rev-parse --is-inside-work-tree\ntrue\n```\n' > "$w/p/c.md"; printf '# x\n\n```derived\n$ grep -c -F '"'"'a`b'"'"' d.txt\n1\n```\n' > "$w/p/q.md"; printf '# x\n\n```derived\n$ git -C sub rev-parse --is-inside-work-tree\ntrue\n```\n' > "$w/p/g.md"; v() { ( cd "$w/p" && AI_DLC_PROJECT_ROOT="$w/p" bash "$R/$V" "$1" >/dev/null 2>&1 ); }; v c.md || exit 9; v q.md || exit 1; v g.md || exit 2; exit 0

## BL-729 — `stamp-story-provenance.sh --series` refuses the `<stem>-adversarial-p` prefix that Check 24 takes, though its header says it resolves the series "the ONE way Check 24 already does"

**NOTE.** Raised from graph's s319 story-provenance stamping (`_bmad-output/pipeline-snapshot.md` at `ded7e6a18`, and the lead transcript) by graph-watch, batch 238; measured and filed by the batch-238 filing hand. It is tiered NOTE because the refusal is loud and costs one retry. The cost is that the error points the wrong way.

`core/scripts/stamp-story-provenance.sh:77-78` says `--series <prefix>` names the terminal pass "the ONE way Check 24 already does (--series <path-prefix>)". Check 24 is driven with a prefix ending in `-adversarial-p` (`core/fixtures/check-24-adversarial-convergence/run.sh:195`, `core/fixtures/adversarial-shard-merge/lib.sh:548`). The resolver's glob at `:83`, `"${SERIES}"*p[0-9]*.md`, needs a `p` AFTER the prefix, so that prefix matches nothing. The script exits 1 with `matched no <prefix>...p<N>.md pass file`, a message that suggests the `p` form is the right one. Only `<stem>-adversarial-` resolves.

Measured on a three-pass mktemp series: `…/s-adversarial-p` matches none, while the control `…/s-adversarial-` reaches p3. The step files that teach the call (`gate-validation.md:1430-1431`, `stories-test-strategy.md:579-580`) say only "the path-prefix of … the stories-adversarial pass series".

Owed: accept both prefixes (add the glob `"${SERIES}"[0-9]*.md`), or state the exact form in the usage line, the error and both step files.

verify: sh S=core/scripts/stamp-story-provenance.sh; [ -f "$S" ] || exit 9; T="$(mktemp -d)" || exit 9; for n in 1 2 3; do printf 'x\n' > "$T/s-adversarial-p$n.md"; done; printf 's\n' > "$T/st.md"; [ "$(ls "$T" | grep -c '^s-adversarial-p[0-9]*\.md$')" = 3 ] || exit 9; o="$(bash "$S" --series "$T/s-adversarial-p" --check "$T/st.md" 2>&1 </dev/null)"; case "$o" in *s-adversarial-p3.md*) exit 0 ;; *"matched no"*) exit 1 ;; *) exit 9 ;; esac

## BL-730 — the recover gate's touchpoint-R stage enforces on a race-chosen subset of a parallel dispatch: each call of a many-call message waits for its OWN line, the early calls' nets expire uncounted, and only the tail is refused

**DEFECT.** Raised from graph `_bmad-output/pipeline-snapshot.md` at `ded7e6a18` (the stories-p2 history line: "shards 18 and 19 were REFUSED by the touchpoint-R hook") by graph-watch, batch 238; measured on graph transcript `a367e62c` and filed by the batch-238 filing hand.

`core/hooks/ai-dlc-recover-gate.sh:224-236` denies only once the incoming call's own `tool_use` line is on disk. At the 10 s net it stands down without counting, under BL-630's fail-open ruling (`CHANGELOG.md:2462-2467`).

Transcript `a367e62c` shows the race. At line 4515 a `compact_boundary` fires, and at line 4550 the lead Reads the post-compaction digest, with no advisor call afterwards. Lines 4612-4681 then hold one message, `msg_011CgCyKHw8znw1wSZJHk9TR`, with all 19 "Pass 2 adversary shard NN" Agent calls. The hooks ran serially about 7 s apart. Calls 1-17 each hit the net and were dispatched: 17 safety-net stand-down lines, 4615-4679. Calls 18 and 19 were SEEN and refused, at lines 4687 and 4689 ("1 of 3").

Touchpoint R was owed, and it held 2 of 19 calls. This is BL-545's incident shape, many seats dispatched before the R advisor call, now escaping through a parallel batch. The lead also had to notice the partial dispatch and re-dispatch shards 18 and 19.

Direction, for the owner: judge a call as SEEN once any later sibling of the same `message.id` is on disk, since content streams in order, or carry one decision across all of a message's calls. Either way, fail-open on an unreadable transcript stays as ruled.

verify: manual — the discriminating state is a stream race decided by the 10 s wall-clock net. A behavioural receipt would pay that net on every scoring and would fix a mechanism the owner has not chosen.

## BL-731 — the cross-agent brief teaches `partition-document.sh --cross-owner <K> <its cited ordinals>` without the comma-joined form, and the script reads `2, 7` as a non-integer ordinal

**NOTE.** Raised from graph s319 cross-shard agents' calls (`_bmad-output/pipeline-snapshot.md` at `ded7e6a18`, and the lead transcript) by graph-watch, batch 238; measured and filed by the batch-238 filing hand.

`core/scripts/partition-document.sh:19` and `:381` take the cited ordinals as ONE comma-joined argument (`<ordinal,ordinal,...>`), and the usage error states that form. The text a cross agent is briefed from does not: `core/skills/ai-dlc/steps/_gate-procedures.md:384-385` reads `--cross-owner <K>` / `<its cited ordinals>`, and `core/skills/ai-dlc/rule-bodies/rule-28.md:119-120` reads `<K> <ordinals>`.

Measured:
- `--cross-owner 8 2,7` prints `3`.
- `8 2 7` exits 64 with the usage line, which is actionable.
- `8 "2, 7"` exits 64 with `cited ordinal " 7" is not an integer in 1..8`, which names the space and not the format.

Owed: the brief and rule-28 spell out `<ordinal,ordinal,...>`, or the script trims blanks around each comma-separated ordinal. Either fix closes the receipt.

verify: sh P=core/scripts/partition-document.sh; G=core/skills/ai-dlc/steps/_gate-procedures.md; [ -f "$P" ] && [ -f "$G" ] || exit 9; [ "$(bash "$P" --cross-owner 8 2,7 2>/dev/null </dev/null)" = 3 ] || exit 9; [ "$(bash "$P" --cross-owner 8 "2, 7" 2>/dev/null </dev/null)" = 3 ] && exit 0; j="$(tr '\n' ' ' < "$G" | tr -s ' ')"; case "$j" in *"--cross-owner <K> <ordinal,ordinal"*|*"--cross-owner <K> <its cited ordinals, comma-joined"*) exit 0 ;; esac; exit 1

## BL-732 — `audit-party-wave-barrier.sh` keys a round member on the first `party-mode/` path a prompt names, so a party-REPAIR remediator fan-out that cites seat files reads as the party round `s<N>/stories`

**NOTE.** Raised from graph transcript `a367e62c` (s319) by graph-watch, batch 238; measured and filed by the batch-238 filing hand. Related: BL-695, which built the detector.

`scripts/audit-party-wave-barrier.sh:35-40` defines a MEMBER as any Agent/Task call whose `input.prompt` names a path `party-mode/<dir>/<file>.md`, and takes the first such path as its identity. `:224` scans the prompt for that path, and `rkey` at `:254-258` strips the seat and ordinal. The detector reads neither `subagent_type` nor whether the path is the agent's WRITE target.

In graph's `a367e62c`, the 19 Agent calls that name a party-mode path are all `subagent_type: remediator`, described "Party repair shard 01" to "19". Each writes `_bmad-output/planning-artifacts/s319/shards/stories-party-repair-p1/<N>.md` and cites `party-mode/s319/stories-sm-<N>.md` as its INPUT ("Your findings: every finding in ..."). `--trace` over that transcript prints 19 `round=s319/stories DELIVERED` lines and `STAT rounds=1 batches=1`, so the detector judges a repair fan-out as a party round's waves. Control: the same jq over the same transcript counts 19 remediator calls and 0 seat-typed member calls.

The consequence is a false finding, or a false acquittal, attributed to a party round. The detector is a distribution-only audit and gates nothing.

Owed: a member is a call whose party-mode path is the file it writes, or whose role is a party seat, not any call whose prompt cites such a path. The key is the owner's to choose. The receipt's seed, rewritten as a seat, still counts a round, so the receipt does not close merely because the detector stopped seeing rounds.

verify: sh D=scripts/audit-party-wave-barrier.sh; [ -f "$D" ] || exit 9; T="$(mktemp -d)"; J="$T/t.jsonl"; for i in 1 2; do printf "%s\n" "{\"type\":\"assistant\",\"timestamp\":\"2026-01-01T10:00:0${i}.000Z\",\"message\":{\"id\":\"m$i\",\"role\":\"assistant\",\"content\":[{\"type\":\"tool_use\",\"id\":\"tu$i\",\"name\":\"Agent\",\"input\":{\"subagent_type\":\"remediator\",\"description\":\"Party repair shard 0$i\",\"prompt\":\"part path: _bmad-output/planning-artifacts/s900/shards/stories-party-repair-p1/$i.md\\nYour findings: every finding in _bmad-output/party-mode/s900/stories-sm-0$i.md\",\"run_in_background\":true}}]}}" "{\"type\":\"user\",\"timestamp\":\"2026-01-01T10:00:0${i}.500Z\",\"message\":{\"role\":\"user\",\"content\":[{\"tool_use_id\":\"tu$i\",\"type\":\"tool_result\",\"content\":[{\"type\":\"text\",\"text\":\"Async agent launched successfully.\\nagentId: ag$i\"}]}]},\"toolUseResult\":{\"isAsync\":true,\"status\":\"async_launched\",\"agentId\":\"ag$i\"}}" >> "$J"; done; S="$(bash "$D" --trace "$J" 2>&1)"; grep -q "self-probe: ok" <<<"$S" || exit 9; grep -q "STAT rounds=" <<<"$S" || exit 9; ! grep -q "STAT rounds=[1-9]" <<<"$S"

## BL-733 — Check 24 arm L owes a whole re-elicitation when a story is split after a correctly sharded stories elicitation, because the owed set is positional and no path elicits only the new or changed story

**DEFECT.** Raised from graph's s319 gate[story] refusal at 2026-10-20T22:44:38Z and the re-run `_bmad-output/planning-artifacts/s319/shards/stories-elicitation/` (graph `765de28f0` and its worktree) by graph-watch, batch 238; measured and filed by the batch-238 filing hand.

Graph's operator ruled story 2.3 split into 2.3a and 2.3b after s319's stories elicitation had run complete at K=19: 19 ordinal shards plus cross-1 to cross-6, committed at `765de28f0`, with `08.md` carrying `invoked_at: 2026-10-20T02:25:46Z`. Check 24 arm L then refused gate[story]: "FAIL (L -- ELICITATION): s319's stories elicitation over 20 stories is not the sharded shape: (b) ordinals missing: 20.md; shards record K=19, fewer than the 20 stories/ holds. … Re-run the elicitation in that shape before this gate." The lead re-ran the whole K=20 elicitation with 26 adversaries. All 26 files in the live `shards/stories-elicitation/` carry an `invoked_at` after 22:44:38Z, against the 25 committed files. One story changed, and 26 adversaries ran.

The arm is right by its own contract, and that contract is the defect. `core/scripts/validate-adversarial-convergence.sh:3133-3141` derives the owed set at gate time from today's `stories/`: the `merge-adversarial-shards.sh --map` ordinals plus the `partition-document.sh --cross-groups <K>` keys. `l_judge` (`:2882-2948`) compares shard file NAMES against that set.

The recorded-K narrowing (`l_kuse`, `:2844`; header `:2766-2772`) honours only a LARGER recorded K, the shrink direction. A grow is judged against today's K and FAILs by design, because honouring a smaller K would acquit a `shard: 1/1` single voice. The remedy at `:3267-3273` names only a full re-run. No step prose offers anything else: `_gate-procedures.md`'s validation-cycle item 2 (`:454-490`) and its amendment procedure (`:852-868`, arm J2 only) have no path that elicits just the delta.

An elicitation of only the new stories cannot pass today either, because ordinals are positional. Graph's live `stories/`, staged as arm L stages it, maps 08 to `story-2-3a-…` and 09 to `story-2-3b-…`. The committed K=19 shards record 08 as `story-2-3-net-pnl-conditional-fix-…` and 09 as `story-3-1-…`. Every shard after the split point is renumbered, and `--cross-groups 20` differs from `--cross-groups 19` in groups 3, 5 and 6.

Owed, the design for its owner to choose: a delta path for a post-elicitation split or addition. It elicits the stories that no shard covers by name (arm L's own `l_cover` already reads shard subjects by name, `:2854-2877`) plus the cross groups whose membership changed, and it judges coverage by subject NAME rather than by ordinal position. It must keep refusing a single voice over many stories and a shrink-with-replacement (`:2783-2789`). The remedy text then names the delta, not a full re-run.

verify: manual — a discriminating `sh` receipt needs the fix's interface first: where a delta shard lives, what it is named, and how its coverage is recorded. Under today's arm L a seeded tree FAILs every delta shape, so a receipt built on a guessed shape closes only under that guess. A receipt keyed on the remedy text could be closed by prose alone. The real-corpus receipt is the next post-elicitation split on a consumer, or a fixture world written alongside the fix.

## BL-734 — a closing entry appended to an already-joined remediator record has no pre-check, so a `siblings:` slip surfaces only when `--escalations` refuses the whole record

**DEFECT.** Seen by graph-watch (ai-dlc-1b) on graph at 23:38:15Z under installed 0.891.0, relayed by lead ai-dlc-1a; diagnosed on the distribution from the code, without a run, by the 238-s-715 owner (ai-dlc-e3). The residual of BL-715, whose `--check-part` (0.893.0) covers shard parts only. Tiered DEFECT because the same refusal class has cost graph a round on each of two paths: on 2026-10-19, 13 SHARD PARTS refused at the join (BL-715's own evidence, fixed by 0.893.0's `--check-part`); and on 2026-10-20, 2 entries through `--escalations` in record mode (this entry, unfixed). One measured round is this entry's own.

Graph's `--escalations` run refused 2 entries, quoted: "the 08.md F-3 closing (MAJOR) entry is repaired with an edit and its 'siblings:' field is none of its four forms" (the same for 20.md F-2 closing (MINOR)) — the BADSIB class of BL-715's 13 shard-part refusals on 2026-10-19, here from a record-mode writer.

- `core/scripts/join-remediator-shards.sh --escalations <record>` is SRCMODE=2 (`:326`): it judges a whole joined RECORD, and its BADSIB refusal is the shared one at `:1172`.
- The refused entries are `repaired` entries carrying `- closes:`, APPENDED to that record after the join. Two roles write them:
  - the serial remediator after a join (`core/team-roles/remediator.md:203-225`);
  - the PM folding an operator answer (`core/team-roles/pm-escalated.md:98-108`, "APPEND to that joined repair record").
- Neither role is told to check its appended entry before handing back, so the first check is the lead's `--escalations` run. A refusal there exits before the record's escalations are reported and costs a round.
- BL-715 does not reach this: `--check-part` (`:1616-1621`) runs `contract_check 0` in PARTS mode over one shard part, and its role paragraph sits in remediator.md's shard section, before "Close your part with --mark". pm-escalated.md was left unchanged on purpose, because the parts-mode classifier is the wrong judge for a record.

Writer and shape, confirmed by graph-watch on graph `7abfe3b9e` (read-only):
- The refused entries are the SERIAL remediator's. `### 08.md F-3 closing (MAJOR)` sits at line 930 of `s319/stories-elicitation-repair-p1.md`, under `# Serial remediation (cross-file; shard: none, serial-document), pass 1, K=20` (line 898), after `# Repair part 20/20` (line 864). "F-3 closing" counts 0 in the shard parts and 1 in the record. So no part file exists for `--check-part` to read, by construction.
- As committed, that entry carries `- siblings:` followed by a blank line and then a fenced block of grep commands. A plausible reading of "none of its four forms" is that the classifier does not join a value placed after a blank line. Not established: whether the record was edited between the 23:38:15Z refusal and the commit. The builder confirms this shape by running the join's own classifier on that entry in a scratch copy, before choosing the fix. If the classifier itself rejects a legitimate fenced value, that is a second defect, to be fixed in the classifier, not the writer.

Owed (mechanism left to the builder):
- a RECORD-mode pre-check the writer runs on the record it appended to, before it returns — `--escalations <record>` itself, or a record-mode sibling of `--check-part`. It must be the join's code, never a restatement of the four forms;
- one instruction at each writer site: remediator.md's serial-remediator section, and pm-escalated.md's append paragraph;
- a fixture arm in `remediator-shard-join`: a joined record with an appended near-miss closing entry (`- siblings: checked`) is refused by the pre-check with the same BADSIB line `--escalations` prints, and a well-formed closing entry passes;
- a mutant that skips the classifier.

verify: manual

## BL-735 — the recover hook's worst real gate-in-flight emission sits 24 bytes under the 10000 cliff, so any line added to its emitted text silently drops the sidecar note for a compacted lead

**NOTE.** Measured by ai-dlc-e3 (batch 238) while 238-d-721's dress was failing; re-derived by the batch-238 docs hand with one direct fire of the hook in the WC world, not the fixture. Related: BL-457, which moved the cliff onto the emitted string.

`core/hooks/ai-dlc-recover.sh:63` sets `CONTEXT_LIMIT` to 10000, and `:629-632` drop the sidecar note ("Mechanical state captured immediately before this compaction") whenever the wrapped bare directive would reach that limit. `core/fixtures/gate-resume/run.sh`'s BL-457 arm WC (`:637-640`) seeds the worst real gate-in-flight case: a 31-char `implementation-<UTC>` nonce opened through the real `gate-checkpoint.sh`, a sidecar, and an unresolvable step file. It asserts only that the emitted length is under 10000.

Measured, the WC world built as `_mkc457` builds it and fired once:
- at 39fb06be9 (0.894.0) the hook emits 9980 characters, with the sidecar note present: 20 bytes of headroom;
- at 599da0aef (0.895.0), which trimmed the hook by 4 bytes, it emits 9976: 24 bytes of headroom.

The arm's own cliff sweep places the drop between nonce padding n=120 (under) and n=132 (over), per ai-dlc-e3. So a change that adds about two dozen bytes to the hook's emitted text drops the note in the worst real case. `degraded` stays `no`, WC stays green while the emission is under 10000, and nothing announces that a compacted lead has lost its one pointer to the pre-compaction branch and gate-log tail.

Owed (mechanism left to the builder), one of:
- raise the headroom by restructuring what the hook emits, so the worst real case sits well clear of the cliff;
- make a growth past a stated margin fail loudly at author time, for example a WC bound tighter than the cliff, instead of the note dropping silently at run time.

verify: manual — the two owed fixes close on different observables: a restructure moves the emitted length, while an author-time margin leaves it where it is and adds a refusal. An `sh` receipt keyed on either one would refuse the other, and a receipt keyed on the length alone could be closed by a cosmetic trim that leaves the hazard intact.

## BL-736 — a story split carries the test strategy past Check 24 arm J2 as a repair on unchanged scope, so the strategy that maps tests to the new story ids gets no adversarial pass over its current bytes

**DEFECT.** Operator ruling 2026-10-20 on the lead's recommendation, quoted: "I'll go with your recommendation". Evidence from graph s319, raised by graph-watch (ai-dlc-1b) in batch 238 and relayed by lead ai-dlc-1a. Distribution sites re-derived on origin/main 809807a0e by the batch-238 docs hand. Related: BL-733, the elicitation half of the same split.

The operator ruled that a story split counts as a SCOPE CHANGE for the test strategy. The amendment procedure does not treat it as one. `core/skills/ai-dlc/steps/_gate-procedures.md:853-869` gives two ways to amend a notarized artifact after MET:
- item 1 (`:856-860`) is "a residue or gate repair on unchanged scope". It needs only a chain of structured repair records, each with `artifact_sha_before:` and `artifact_sha_after:`, from the notarized sha to the disk sha;
- items 2-4 (`:861-869`) handle a scope change with one `REOPEN_AFTER_MET` record plus ONE verify pass. Item 2 defines a scope change as "a later step rewording a capability".

Check 24 arm J2 enforces that split. `core/scripts/validate-adversarial-convergence.sh:3569-3574` PASSes on a complete chain of repair links. `:3582-3584` reserve the re-open for a scope change, but the arm itself never decides which case it is looking at.

A story split changes the set of story ids the strategy maps tests to. It is not "rewording a capability", so the repair path is open to it, and J2 accepts the chain with no adversarial pass over the strategy's current bytes.

Measured on graph s319 (as relayed by graph-watch; graph not re-read for this filing):
- `test-strategy-repair-p3` (`faa99bbc` -> `15443bd`) carried the 2.3 -> 2.3a/2.3b split;
- `test-strategy-repair-p4` made the strategy 52 lettered cases and 132 rows;
- the test-strategy series PASSed after both, and no adversary reviewed either.

Owed:
- (a) the strategy-subject amendment rule treats a change in the mapped story-id set as a scope change (`REOPEN_AFTER_MET` plus ONE verify pass). That change is detected mechanically from the id set, not by judgement, and J2's acceptance of a repair chain is the arm that changes;
- (b) the verify pass covers only the changed rows where the machinery allows that, and is one full pass where it does not;
- (c) designed TOGETHER with BL-733, so a split costs work in proportion to what it changed;
- a fixture with three worlds:
  - a split strategy with only a repair chain is REFUSED by J2;
  - the same split with `REOPEN_AFTER_MET` and a verify pass is accepted;
  - an in-scope repair (same id set) is still accepted by its chain.

verify: manual — the id-set detector and where the re-open is recorded are the builder's design, so an `sh` receipt built before them would close only under a guessed interface. A discriminating receipt can be written alongside the fix.

