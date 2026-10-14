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

## BL-507 — a re-review after rework re-runs the full sharded fan-out instead of reviewing the fix delta

**DEFECT. [efficiency rank 1] $282, 1,258 agent-minutes.** In graph s317 every code-review pass after a
NEEDS_REWORK re-ran the full gate-1 fan-out (10-13 escalated Opus/high shards) at $20-43 a pass:
story 2.6 took five passes (about $149) and 1.2 took four (about $115). In s318, from the third pass on,
the lead reviewed only the fix delta at $1-3 a pass, with the same catch quality. Nothing in core
asks for that: the s318 behaviour was the lead's own choice. Costed in the analysis as the excess of
the 11 full-fan-out re-review passes over the median delta pass ($1.70), from
`pipeline-efficiency-s317-s318/role-efficacy/impl/` (`rework-labels.tsv`).

The receipt is scoped to the `**Gate-1 dispatch` paragraph (57 lines at filing). It reads 1 on this
tree and 0 with one delta-review sentence added there. A selector keyed on a `# … Gate 1` heading
matched nothing in this file and would have read STILL-LIVE forever.

verify: sh F=core/skills/ai-dlc/steps/implementation.md; [ -f "$F" ] || exit 9; S="$(awk '/^\*\*Gate-1 dispatch/{on=1} on&&/^\*\*[A-Z]/&&!/^\*\*Gate-1 dispatch/{exit} on' "$F")"; [ -n "$S" ] || exit 9; printf '%s\n' "$S" | grep -qiE 're-review[^.]{0,120}(delta|since the (last|prior) (pass|review))'

## BL-508 — a repair pass writes the defects the next adversary pass finds

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

verify: manual -- close when the remediator contract (`core/team-roles/remediator.md`, `_gate-procedures.md` adversarial repair dispatch) requires a repair to re-check every sibling site of the fixed text and every cite it moved before reporting, and a fixture pins that requirement.

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

Not built: the B class (status not flipped, a missing Dev Agent Record line, empty or demoted
evidence headings). An empty-heading arm has a 3-story FP set on the same corpus and needs an
operator ruling before it ships. This entry stays open for that class.

Operator ruling (batch 229): ship the evidence half and keep this entry open. The receipt chains the
evidence probe to `probes/bl-510-bookkeeping.sh`, which the batch that builds the B class writes;
until it exists the receipt exits non-zero and the entry cannot rotate as closed.

verify: sh bash docs/analysis/pipeline-efficiency-s317-s318/probes/bl-510-handoff-evidence.sh && bash docs/analysis/pipeline-efficiency-s317-s318/probes/bl-510-bookkeeping.sh

## BL-512 — gate passes are discarded for lead paperwork, most often a Check 22 waiver

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
S298-S318, clause 1 denies nothing and clause 2 denies only S316/S317 rows arm S3 fails.

verify: sh bash docs/analysis/pipeline-efficiency-s317-s318/probes/bl-512-adjudicator-dispatch-waiver.sh

## BL-515 — the lead re-sends spawns the concurrency cap rejected

**DEFECT. [efficiency rank 9] wall clock not measured.** 90 of 179 cap-rejected `Agent` calls were
re-sent with the same description; the worst burst was 32 rejections in one minute (graph s318
sprint-review, 40 of 95 party seats). `RB/rule-28.md` already says to hold the rejected set until a
beat returns a `DELIVERED` line, so this is the lead not following written prose.

The `DELIVERED` key did not survive measurement. Over graph's nine rejecting lead sessions (279
rejections, 233 same-description re-sends), holding until a `DELIVERED` beat would deny 226 re-sends,
142 of which the harness then launched. Per the operator ruling, a slot frees when an agent exits:
`rule-28.md` now releases the held set on an agent task-notification or a non-error
`Agent`/`Task` result (a hook-refused or otherwise failed call frees no slot), and `ai-dlc-dispatch-guard.sh` denies a lead re-send of a rejected
description with neither after the rejection. On the same corpus it denies 3 re-sends, all rejected
again, and 0 that launched. 83 re-sends rejected again are not held because a release record sat
between the attempts.

verify: sh bash docs/analysis/pipeline-efficiency-s317-s318/probes/bl-515-resend-after-cap.sh

## BL-519 — the remediator can set aside a party MAJOR as "outside this shard"

**DEFECT. [efficiency rank 11] cost not measured.** In graph s318 stories, the sm-05 seat raised
"sweep_id never shown in the UI" as a MAJOR. The party remediator dispositioned it "outside this
shard … not required", and the ux mockup did not add it, so it reached sprint-review as cluster C-18.
In the same round a remediator "repaired" sm-12's "two backends" MAJOR by adding a SQLite fixture
rather than questioning why the audit reads SQLite (C-03). A scope disposition by the repair seat is
a decision nobody adjudicates.

verify: manual -- close when the remediator contract forbids dispositioning a party MAJOR as out of shard scope (it escalates instead), and a fixture pins that clause.

