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

## BL-509 — elicitation fans out per part where one voice measured an order of magnitude cheaper

**DEFECT. [efficiency rank 3] about $60 per elicitation run.** s317 stories ran elicitation as 22 sharded
seats ($69.53); s318 ran it as one voice ($9.37). s318 requirements ran 19 elicitation shards
($56.73, 37 MAJORs). Whether the single voice finds as much has not been measured, so the close
condition is a measurement, not a shard count.

verify: manual -- close when `_gate-procedures.md`'s validation cycle states the elicitation fan-out shape with a recorded measurement of findings per dollar for sharded vs single-voice elicitation on one corpus.

## BL-510 — implementation rework is driven by evidence and bookkeeping, not code

**DEFECT. [efficiency rank 4] $34, 131 agent-minutes after removing BL-507's overlap.** 22 of 33
implementation rework verdicts in s317-s318 were evidence (12: captures with no command or head sha,
uncommitted or gitignored RED files, a truncated capture) or bookkeeping (10: empty headings, status
not flipped, a missing Dev Agent Record line). They held under every dev binding and every reviewer
tier. This is the class BL-397 closed at v0.674.0; it recurs under 0.78x. Understated: in s318 the dev
spawn stayed alive across fix rounds, so its fix work cannot be split out. Per-verdict labels and
costs: `pipeline-efficiency-s317-s318/role-efficacy/impl/rework-labels.tsv`.

verify: manual -- close when a dev's handoff is refused mechanically (before gate 1) on a capture with no command or head sha, or on a RED capture not in the commit, and a fixture seeds both.

## BL-511 — the Step 1a whole-read budget blocks a sprint after the fact, and the same sprint re-breaches it

**DEFECT. [efficiency rank 5] $16 and 3.8 h of lead waiting per occurrence.** route.md Step 1a
HARD_BLOCKed graph's s318 start; the lead dispatched artifact-consolidation and waited 3.8 h. s318's
own authoring then re-breached the pool at 77,078 tokens against 66,000
(`CO-S318-WHOLE-READ-POOL-REBREACHED-BY-S318-AUTHORING`), so s319 will block again. Nothing runs
consolidation before the budget is exceeded.

**Premise correction (measured at batch 229).** The s318 Step 1a block was the pre-0.781 200K-window
resolution: at 0.773.0 the pool resolved to 66,000 (503%, rc 1), while the tip validator on the same tree
resolves 330,000 (100%, within grace, rc 0). Graph reads 31% today. The repair therefore does not run
consolidation (it stays operator-supervised, never automatic). Retro §4a now runs the audit with
`--fail-on whole-read-pool`, whose hard verdict is "pool OVER and no OPEN `carry-over-backlog.md` item
carries `WHOLE-READ-POOL`". Retro §5c check 5 blocks the Step 6 commit on it, and route Step 1 item 5
reads the item before Step 1a runs. Graph's own OPEN `CO-S318-WHOLE-READ-POOL-REBREACHED…` satisfies it.
The receipt drives the §4a and §5c commands as retro.md spells them.

verify: sh bash docs/analysis/pipeline-efficiency-s317-s318/probes/bl-511-retro-pool-verdict.sh

## BL-512 — gate passes are discarded for lead paperwork, most often a Check 22 waiver

**DEFECT. [efficiency rank 6] $16, 132 adjudicator-minutes.** Seven gate nonces were discarded for
lead-caused reasons across both sprints, 3 of them the same Check 22 waiver with no Rule 28
exception, under both the Sonnet and the local qwen lead at about 0.08 per active hour. Check 22
fired correctly each time; the waste is the discarded pass, not an escape. Two further discards
(Check 1 verdict form, Check 5 drift) are inferred, not stated as lead error.

verify: manual -- close when a Check 22 waiver that names no Rule 28 exception is refused at the moment the lead writes it, before any adjudicator is dispatched, and a fixture seeds the waiver form graph wrote.

## BL-513 — Check 21 fails on dev-filled Strategy Test ID cells that nothing re-checks after a rename

**DEFECT. [efficiency rank 7] about $7.** `stories-test-strategy.md` leaves the `Kind` and
`Resolves to` cells "for the dev". Check 21 FAILed the sprint-review gate in both sprints on those
cells: s317 empty cells (Sonnet dev, story 2.7), s318 prose instead of a test node (Haiku dev, 2.2)
and a test that a sprint-review fix renamed (dev-escalated, commit `7d917eb94`), which escalated
review and QA then passed. Not tea's strategy: no failing cell traces to it. This is the class
BL-398 closed at v0.674.0; the rename path is new.

verify: manual -- close when sprint-review step 3 re-binds every Strategy Test ID cell a fix renamed before the gate opens, and a fixture seeds a renamed test whose cell then fails Check 21 before the fix and passes after.

## BL-514 — subagents poll with bare `sleep`, and no guard sees a subagent's wait

**DEFECT. [efficiency rank 8] 5.4-12.4 h of subagent wall clock.** 228 subagent Bash calls whose first
token is `sleep` ran 12.4 h, about 196 s each; the narrow count (commands beginning `sleep`, `until`
or `while`) is 125 calls, 5.4 h, mostly qa and code-reviewer. `ai-dlc-foreground-budget.sh` exempts
any call carrying an `agent_id` by design, and `validate-steering-budget.sh` drops `isSidechain`
records, so neither can see it. Measured: a lead call with `timeout: 900000` is denied, a subagent's
`sleep 200` with the same timeout is not.

verify: manual -- close when a subagent's bare `sleep` poll is bounded by a mechanism that sees subagent calls (a hook arm keyed on `agent_id`, or a role contract pinned by a fixture), and a fixture seeds a qa-shaped `sleep 200` that the arm refuses or the pin catches.

## BL-515 — the lead re-sends spawns the concurrency cap rejected

**DEFECT. [efficiency rank 9] wall clock not measured.** 90 of 179 cap-rejected `Agent` calls were
re-sent with the same description; the worst burst was 32 rejections in one minute (graph s318
sprint-review, 40 of 95 party seats). `RB/rule-28.md` already says to hold the rejected set until a
beat returns a `DELIVERED` line, so this is the lead not following written prose.

verify: manual -- close when a re-sent `Agent` call whose description matches a spawn rejected in the same session with no intervening `DELIVERED` beat is refused by a hook, and a fixture seeds the rejection text.

## BL-516 — no guard stops the lead editing consumer product code

**DEFECT. [efficiency rank 10] cost not measured; high consequence.** The qwen/medium lead edited
`rebalancer/execution.py` itself for s317's ff1 (5 Edits, 10-11T19:52-19:54Z), later reverted and
re-done by a dev seat. Rule 28 forbids it in prose. `core-guard` covers core paths only, and
`gate-remediation-guard` covers the artifact corpus only while a gate FAIL is recorded. Measured by
the receipt's probe: a lead Edit to a core path is denied by `core-guard`, a lead Edit to product code
by no hook. Toward the local-lead goal.

verify: sh bash docs/analysis/pipeline-efficiency-s317-s318/probes/bl-516-lead-product-edit.sh

## BL-517 — the snapshot accepts entries stamped in the future

**DEFECT. [efficiency rank 10] cost not measured.** The s317 retro found fabricated future timestamps
in graph's pipeline snapshot during the qwen/medium lead window; s318 recurred under the Sonnet lead,
with corrections at `pipeline-snapshot-history.md:215, 219, 225` (10-14 02:11-02:58Z). Step 0a's
integrity validation does not compare an entry's stamp with the current time. A pipeline defect, not
a model one; toward the local-lead goal.

**Premise correction (measured at batch 229).** The defect is born at snapshot WRITE time, not at resume.
Over graph's 163 snapshot revisions since 2026-10-09, each replayed with now set to its own commit time,
69 carry a stamp more than 10 min ahead (214 findings: 127 Recent Activity, 87 `dispatched-at`; smallest
lead 10 min; 0 inside the slack). The contract analysis counted 0 of 20 resumes seeing one (not
re-derived here). The cited history lines 215/219/225 resolve at
commit `3e5aeb070`, not HEAD. The arm therefore lives in `validate-artifact-budget.sh`'s snapshot branch,
which gate Check 14 runs at every write and route Step 0a check 1 runs at resume, and its failure names
the remedy (rewrite to `date -u`, keep order, one CLOCK CORRECTION line naming the old stamps as bare
`HH:MMZ`, since a full-form name is itself a future stamp). Every lead-facing call site reads the
validator through `verdict.sh`, which shows 6 matching lines, so the stamp verdict prints first, its
FAIL line carries the remedy, and `verdict.sh` surfaces `FUTURE` rows.

verify: sh bash docs/analysis/pipeline-efficiency-s317-s318/probes/bl-517-future-stamp.sh

## BL-518 — gate-checkpoint opens a nonce of any shape

**DEFECT. [efficiency rank 10] cost not measured.** The qwen/xhigh lead minted
`implementation-2026-10-10T083048Z` from `date -u +%Y-%m-%dT…`, a hyphenated timestamp, and its
checkpoint closed before dispatch. `gate-checkpoint.sh open` accepts it exactly as it accepts the
canonical `implementation-20261010T083048Z`. Toward the local-lead goal.

verify: sh bash docs/analysis/pipeline-efficiency-s317-s318/probes/bl-518-nonce-format.sh

## BL-519 — the remediator can set aside a party MAJOR as "outside this shard"

**DEFECT. [efficiency rank 11] cost not measured.** In graph s318 stories, the sm-05 seat raised
"sweep_id never shown in the UI" as a MAJOR. The party remediator dispositioned it "outside this
shard … not required", and the ux mockup did not add it, so it reached sprint-review as cluster C-18.
In the same round a remediator "repaired" sm-12's "two backends" MAJOR by adding a SQLite fixture
rather than questioning why the audit reads SQLite (C-03). A scope disposition by the repair seat is
a decision nobody adjudicates.

verify: manual -- close when the remediator contract forbids dispositioning a party MAJOR as out of shard scope (it escalates instead), and a fixture pins that clause.

## BL-520 — a teammate is told to "message the lead", a name the harness does not register

**DEFECT. [efficiency rank 12] cost not measured.** 11 `ESCALATION_UNDELIVERED` events across graph
s317-s318 failed with "No agent named 'lead'" (qwen lead 4, Sonnet lead 7). `core/team-roles/dev.md`
tells a dev to "message the lead" at three sites and never names the address a subagent reaches its
parent by. `ai-dlc-escalation-delivery.sh` records the failure after the fact.

verify: manual -- close when every role file that tells a teammate to message the lead names the address a subagent actually reaches its parent by, and a fixture pins that address at each site.
