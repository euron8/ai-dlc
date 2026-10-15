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

## Pipeline-efficiency ranked set (BL-507 .. BL-520)

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

## BL-510 — implementation rework is driven by evidence and bookkeeping, not code

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

verify: sh bash docs/analysis/pipeline-efficiency-s317-s318/probes/bl-510-handoff-evidence.sh && bash docs/analysis/pipeline-efficiency-s317-s318/probes/bl-510-bookkeeping.sh

