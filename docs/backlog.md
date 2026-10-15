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

verify: sh bash docs/analysis/pipeline-efficiency-s317-s318/probes/bl-507-carried-findings.sh

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

verify: sh bash docs/analysis/pipeline-efficiency-s317-s318/probes/bl-508-siblings.sh

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
S298-S318, clause 1 denies nothing, and clause 2 denies only S316/S317 rows that arm S3 fails under
the 0.783.0 validator, which counts party seats as shardable (`party_seats`). Graph ran S317 under a
validator with no `party_seats`, so a party-seat `invalid-exception` row passed Check 22 there and is
denied here: graph's next pull refuses every S317-shaped adjudicator dispatch carrying such a row
(the tea row `toolu_012cdPrfgjVUGRG1X3sAcT1g`, measured) until that row is waived. The tip
adversary's replay over graph's S317 nonces: 20 denied, 19 of them recorded as Check 22 PASSED
under graph's own validator.

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

The set-aside is `s318/shards/stories-party-repair-p1/5.md:111`. The fix: files mode gains the
section and subject modes' clause (a fix outside your files is `escalated`), a partial repair is a
`repaired` and an `escalated` entry under one `source:`, and the join refuses a `repaired`
MAJOR/CRITICAL whose claim matches `outside (this|my|the) (shard|part|section)|not required` with
no hand-off token. It prints `ESCALATED:` per escalated entry and a count, and the dispatch
procedure sends the serial remediator whenever the count is above 0; before this, nothing consumed
an escalated entry. In `--sources` mode the lead adjudicates those lines rather than re-dispatching.
An escalated entry closes only when a later `repaired` entry carries `- closes: <part> <heading>`
copied from its `ESCALATED:` line, and is then printed as `ESCALATED-CLOSED:`. Closure keyed on the
`source:` token was wrong: a later half repair of another conjunct under the same token, or in
another part, closed the whole escalation. Measured over a scratch copy of graph's s318
`architecture-party-repair-p1.md`, where dev-05#F-3 is escalated in part 5.md and repaired under
the same token in the later part 6.md, the token-keyed join closed 5 of its 8 escalations and the
`closes:`-keyed join closes none. `--sources` needs the sprint's `party-mode/s<N>/` seat
directory and exits 2 without it, so for an adversarial, elicitation or gate repair nothing read the
serial remediator's `closes:` lines. `--escalations <record>` runs the same contract and closure with
no seat files and reports every escalation still open. An escalated entry names the file its fix lies
in as `- edit: <path>:<line(s)> (escalated)`, and the coverage join reads no escalated entry's
`edit:` as a citation. Before this, such an entry made a correct pass refuse as "cited by more than
one shard record", and 15 of graph's 66 escalated s317/s318 entries carry a path there.
Measured over graph's 202 s317/s318 shard parts (478 repaired MAJOR+ entries, counted with the
join's own heading-severity and disposition grammar): 1 hit, that entry, 0 false positives. Not caught: a set-aside reworded past the regex, and C-03's
shape, a substantive mis-repair whose prose and pin agree.

verify: sh bash docs/analysis/pipeline-efficiency-s317-s318/probes/bl-519-set-aside.sh

## BL-521 — QA passes an AC that skips an action a locked requirement requires

**DEFECT.** graph s318 story 1.2 AC5(b) specified that a HODL press with token0 at or below the
0.01 dust floor skips the swap and transfers token1. LR-S318-2's verbatim text is "This function
will swap current wallet balance of offramp_hodl_token0 and swap to offramp_hodl_token1." QA
passed AC5 as specified (`docs/reviews/s318/1-2-qa-validation.md`, AC5 row PASS), the story
shipped, and two live presses skipped the swap. At retro the operator said "I did not approve the
arbitrary minimum that was set that caused the swap to be skipped." `qa.md` had no rule that an AC
omitting a locked requirement's action is a deviation to put to the operator. Its null-impl gate
asks whether some AC goes red against a degenerate implementation, and AC1, AC3 and AC5(c) did.

**The narrow exemption is the point.** The timeline, in UTC: s318 1.2's QA PASS was committed at
`1f1c06c39` 02:40Z, and the sprint-review fix QA at `77961c8c2` 09:01Z.
`S318-HODL-INHERITS-OFFRAMP-DUST-FLOOR-AND-SLIPPAGE` was first committed at `ada77ec60` 08:42Z as a
HARD_BLOCK, blocker type `trade-off`, framed as which config leaf owns the floor, naming no LR. The
operator answered it at 10:49:39Z ("Inherit and say so (Recommended)"), and PR #1220 merged at
16:04Z. The retro correction records that the operator did not read that answer as approving the
skip, so the exemption takes only a Tier 1 `HARD_BLOCK`, blocker type `requirement divergence`,
that cites the LR and names the degraded branch. A looser exemption would have acquitted AC5(b) on
any QA run after 10:49Z; none occurred.

**Scored on graph `main`.** Every s318 epic-1 story carrying an LR (1.2, 1.3, 1.4) fires on 1.2
AC5(b) only: it performs one required action (the transfer), omits the swap on a non-zero token0
balance, and reports `complete`. Each refusal outcome performs none of the actions and reports a
non-success, so exemption (3) acquits it: 1.2 AC6 (`ValueError` before any transaction), 1.2 AC7
(dry-run), 1.2 AC8 (`failed`, `aggregator_unavailable`), 1.3 AC1 (a)/(e) (400), 1.3 AC4 (409/503)
and 1.4 AC2 (a)-(k) (a disabled button). 1.2 AC9 and 1.3 AC7 are out-of-scope declarations that
require no LR action. s317 2.5 AC8 is not acquitted by (3), because LR-S317-7 says
"SHALL be honoured, not refused"; it does not fire because its precondition is an empty layer, a
position set with nothing to rebalance, which is the nothing-to-act-on clause. A non-zero balance
under a floor is not that clause.

Built: a HARD GATE item in `core/team-roles/qa.md` Validation Checklist (trigger, three
exemptions, the HARD_BLOCK route, `Verdict: NEEDS_REWORK` and the lead's `AskUserQuestion` before
rework), the matching sentence in the Escalation Protocol, `escalations.md` and `implementation.md`,
one sentence in `steps/deploy-validate.md` §5 recording an accepted degraded branch as a `descope`
of the omitted action, never `delivered`, and nine `process-rule-pins` rows. The receipt runs the
fixture's `--report` and requires all nine rows `ok`.

Filed by the reference consumer as
`PC-S318-QA-ROLE-HAS-NO-RULE-THAT-A-SKIP-AGAINST-A-LOCKED-REQUIREMENT-IS-A-DEVIATION-TO-PUT-TO-THE-OPERATOR`.

verify: sh R=core/fixtures/process-rule-pins/run.sh; [ -f "$R" ] || exit 9; o="$(bash "$R" --report 2>&1)"; n="$(grep -cE '^  ok    (qa-lrdiv-(lead|never-pass|empty|rework|outcome|exempt|exempt3|other-type)|dv-lrcov-degraded): pinned inside' <<<"$o")" || n=0; [ "$n" -eq 9 ]

## BL-522 — a rebind passed three reviews with nobody pricing the literal it re-keyed

**DEFECT.** Filed by the consumer as `PC-S318-ARCHITECT-ROLE-DOES-NOT-ASK-WHAT-A-LITERAL-IS-WORTH-AFTER-A-REBIND`.

**What happened.** In graph s318, story 1.2's `if hodl:` block set `stable_token = "token1"` (graph main
`rebalancer/execution.py:23351`), which changes which token counts as non-stable. `dust_raw` (main `:23459-23460`) is
`Decimal("0.01")` units of the non-stable token and gates the swap, so the floor moved with no diff touching it; the
retro (`_bmad-output/party-mode-transcripts/s318/retro.md:70`, not re-derived here) puts it at about $0.00002 before and
about $24 after. A live press held 0.0091 WETH under that floor, skipped the swap and ended SUCCESS. The second keyed
literal, the stable-side `Decimal("0.01")` at main `:25078`, was named only by the retro (`:76`, `:120`). The reviewer
that passed the rebind was the adversary, not the architect: `architecture-adversarial-p2.md:83` confirmed the dust gate
precedes the chain refusal and concluded a below-dust press "behaves as on the proven path"; p1 `:669` wrote "above the
dust floor" as a fixture precondition; `docs/reviews/s318/1-2-code-review.md` mutation-tested every rebind line and priced
nothing. `requirements-architect-05.md:8-13,20` came closest: it named the unit flip and wrote "0.01 units of token0"
without a value under either binding.

**The fix (batch 230).** One domain-neutral clause in three roles. A change that makes an existing name, role or unit
resolve to a different value, party or unit while its text stays the same, where a literal or threshold downstream is
computed from or compared against it, prices every literal and threshold the re-bound value flows into under the old and
the new binding, in the unit it is compared against, and records `old -> new`. A literal the diff does not touch is in
scope for that reason. `stories-test-strategy.md` `## Rename Verification` owns finding a rename's references, and this
clause owns pricing a re-target. In `adversary.md` it is a Severity rung, a plain blocking MAJOR that never counts as
underived, CRITICAL when the new price sends a covered case down a different branch. In `code-reviewer.md` it is a
severity classification, Important minimum. In `architect.md` and in the code reviewer's evidence line, the `derived`
fence derives each input the price depends on (the literal's line, and the decimals or units entry under each binding)
with commands naming the source file as an operand; a `BEGIN`-only `awk` computation is not a derivation, and the
arithmetic and `old -> new` go in the sentence beside the fence. `core/fixtures/process-rule-pins` pins eighteen rows
across the three files, including the trigger and the `every literal` scope.

**Scope under the trigger.** In: `dust_raw` (its text is unchanged, it resolves through `dec_ns` of the re-targeted
non-stable token, and the swap gate compares the balance against it); the stable-side `Decimal("0.01")` at `:25078` (its
text is unchanged, it resolves through `dec_s` of the token a `stable_token` binding selects, here the startup check's own local read
from pool config rather than the HODL block's assignment, and the stable balance is compared against it; it is in by
the same shape, not because the s318 block reaches it). Out: the ADR-S317-6 predicate rename and a test-node rename, because each changes its text, which
`## Rename Verification` covers.

verify: sh F=core/fixtures/process-rule-pins/run.sh; [ -f "$F" ] || exit 9; o="$(bash "$F" --report 2>&1)" || exit 1; n="$(grep -cE '^  ok    (adv-rebind-(rung|trigger|every|unit|untouched|oldnew|major)|cr-rebind-(head|trigger|every|unit|untouched|sev)|arch-rebind-(trigger|fence|unit|oldnew|untouched)): pinned inside ' <<<"$o")" || n=0; [ "$n" -eq 18 ]

## BL-524 — the operator-question template badged an operator-owned trade-off "(Recommended)"

**DEFECT.** Filed by the consumer as `PC-S318-OPERATOR-QUESTION-TEMPLATE-LABELS-AN-OPERATOR-OWNED-TRADE-OFF-RECOMMENDED`.

**What happened.** Graph's s317-s318 transcripts carry 38 distinct `AskUserQuestion` questions with a
`(Recommended)` option. The motivating one asked whether the HODL sweep should inherit the offramp 0.01 dust
floor, and badged "Inherit and say so". The label never said that inheriting leaves a token0 balance at or below
0.01 unswapped while the press ends complete. SKILL.md Rule 11(a) told the lead to put the recommended option
first on every question. `_gate-procedures.md` step 2(c) required exactly one badge on the adversarial STOP, and
`validate-adversarial-convergence.sh` F7 failed any record that named none, even when the options touched a
`LOCKED_REQUIREMENTS` entry.

**The fix (batch 230).**
- Rule 11(a): every option states its concrete effect, including the value it leaves in force. A question is
  unbadged when an option sets, relaxes, inherits or leaves in force a config leaf, a money-path threshold or
  literal, a byte-pin, an `LR-`/`LRC-` id, or a `D-<n>` decision.
- Rule 11 grew 729 bytes (17877 to 18606 bytes to its end at base and tip). That pushed Rule 12's two `escalations.md`
  disclosure pointers past the 20121-byte re-attach cut: "AC verification-category-change disclosure" now ends at
  byte 20396 and "Authorization-premise invalidation disclosure" at byte 20589, against 19667 and 19860 at base.
  The five-item unbadged list was folded into one sentence, which saved 10 bytes and did not bring either pointer
  back. **The eviction is accepted.** The post-compact digest does not carry them either, because it renders only
  Rule 12's first paragraph (0 hits for either pointer, against 1 for Rule 12's heading). What survives the cut is
  Rule 12's "READ AND FOLLOW `escalations.md`" sentence, which ends at byte 20116, 5 bytes inside the cut. The two
  disclosures are sections of that file. The digest re-rendered with no byte change.
- The adversarial STOP branches on the record's `locked_requirements_touched:`, read on its first token. Backticks
  and leading blanks are dropped, the value is cut at the first blank, `.`, `,`, `;` or dash, and the result is
  lowercased. A token of `none`, `0`, `n/a`, `-` or `[]`, or no token at all, keeps the old rule, so `none — <prose>`,
  `none changed; ...` and `None.` are unlocked. Any other token names an entry, and then the record must carry
  `recommended_option: none` or no such line, and the new F7b finding fails a named badge.
  `recommended_option:` is read the same way, so `none (Recommended)`, `None.` and `n/a` name no option. The remedy
  text in `ai-dlc-acknowledge.sh` and `ai-dlc-continue.sh` matches, and the validator's says "mark NO option
  (Recommended)". `check-24-adversarial-convergence` adds twelve worlds (five locked-branch shapes, six unlocked
  spellings and one `LR-S1-1 (...)` locked world), eight silence controls and four `--cycle-state` rows.
  `divergence-hard-block` pins "value it leaves in force" in both hooks' ADJUDICATE step, with one mutant per hook
  that flips only its own arm. `process-rule-pins` adds four rows: the Rule 11(a) effects sentence and its unbadged
  clause, and the `_gate-procedures.md` 2(c) effects and no-badge clauses.
- `bug-investigation.md` §2b badges "apply now" only when the relief sets no operator-owned value.
  `remediator.md` gives no recommendation on a locked or operator-owned item. `route.md` no longer claims the
  token appears nowhere in the skill. The continue hook's Rule 11(a) paragraph carries the clause, and
  `pause-question-in-prose` F2 pins it.

**The walk.** Of the 38 badged graph questions, 18 lose the badge under the rule as built: 7 on a config leaf,
2 on a money-path threshold or literal, 5 on a byte-pin, 2 on an `LR-`/`LRC-` id and 2 on a `D-<n>`. The other
20 keep it. The dust-floor question is one of the two money-path questions. It is caught by the effects clause,
because the compliant option has to read "swap skipped for balances <= 0.01 token0". One is borderline: the
`security.wallet_address` checksum question is scored as a config leaf. The rule is prose with no enforcer on
`AskUserQuestion` itself, so the walk shows what the rule reaches, not that a lead will follow it.

Eighteen is what Rule 11(a)'s list reaches, not what this fix reaches. Eleven of the 38 rows (18, 19, 22, 31-38)
were asked by the updater's reconcile flow, which asks from its own template and not from Rule 11(a). Three of
the 18 are among them: rows 33 and 35 (config leaf `aiDlcRoles.dev-escalated.model`) and row 37 (byte-pin,
sha-locked gate evidence). The shipped fix therefore reaches 15 of the 38, and the other 3 stay open until the
updater's template is covered.

**Uncovered.** The updater's reconcile questions in `ai-dlc-update/SKILL.md` (~1905-1907, "a closed question
with your recommendation") are outside this fix. That flow asked 11 of the 38 badged questions. Three of them
(rows 33, 35, 37) would lose the badge under the rule and still carry it, and the other 8 keep it either way.

verify: sh V=core/scripts/validate-adversarial-convergence.sh; S=core/fixtures/check-24-adversarial-convergence/seed.sh; P=core/fixtures/pause-question-in-prose/run.sh; [ -f "$V" ] && [ -f "$S" ] && [ -f "$P" ] || exit 9; R="$(bash "$S" | tail -1)"; D="$R/divergent-resolved"; [ -f "$D/s1-resolution-p2.md" ] || exit 9; T="$R/operator-transcript.jsonl"; run() { bash "$V" --series "$R/$1/s1-adversarial-p" --transcript "$T" --transcript-dir "$R" 2>&1; }; run divergent-resolved >/dev/null || exit 9; for k in lb ln; do mkdir "$R/$k" && cp "$D"/*.md "$R/$k/" || exit 9; done; awk '{print} /^adjudicated_by:/{print "locked_requirements_touched: LR-S1-3"}' "$D/s1-resolution-p2.md" > "$R/lb/s1-resolution-p2.md" || exit 9; awk '/^recommended_option:/{print "recommended_option: none"; next} {print} /^adjudicated_by:/{print "locked_requirements_touched: LR-S1-3"}' "$D/s1-resolution-p2.md" > "$R/ln/s1-resolution-p2.md" || exit 9; grep -q '^recommended_option: [A-Z]' "$R/lb/s1-resolution-p2.md" || exit 9; o="$(run lb)" && exit 1; grep -qF "names a locked requirement" <<<"$o" || exit 1; run ln >/dev/null || exit 1; bash "$P" >/dev/null 2>&1 || exit 1; grep -q '^(i) A Rule 11(a) AMBIGUITY QUESTION: .*then no option is badged' core/hooks/ai-dlc-continue.sh || exit 1; grep -qF 'INCLUDING the value it leaves' core/skills/ai-dlc/SKILL.md || exit 1; exit 0

## BL-525 — the pause gate denies every dispatch while an operator message is outstanding, including a search

**DEFECT.** Filed by the consumer as `PC-S318-PAUSE-GATE-DENIES-READ-ONLY-OPS-DISPATCH-WHILE-AN-OPERATOR-MESSAGE-IS-OUTSTANDING`.
While the pause flag is up, Check 3 of `ai-dlc-acknowledge.sh` denies every `Agent`/`Task` call, so a
search the lead needs to answer the operator runs inline in the lead instead. The operator's ruling is
an Explore-only carve-out: the lead's own dispatch of the built-in `Explore` subagent passes, and
nothing else does. Explore has no Agent, Edit, Write or NotebookEdit, so it adds nothing the lead's
allowed Bash lacks; it is not read-only. The carve-out fails closed on a teammate caller, on any
`subagent_type` other than the exact string `"Explore"`, on a `name` or `team_name` in the call (either
routes it to the in-process teammate runner), on a `team-roles/<role>.md` citation in the prompt (the
dispatch guard rewrites `subagent_type` from one), and on any `.claude/agents/*.md` in the project or
under `$HOME` whose frontmatter `name:` is Explore, case-insensitively. It sits after the Rule 8 STOP
exit, so a STOP still denies it.

**What it does NOT fix, measured.** The motivating dispatch was `ops`, and `ops` stays denied: it writes
its repair record under `_bmad-output/planning-artifacts/` (`core/team-roles/ops.md`, step 4). In graph
s318 there were 5 ACK_DENIED rows, 2 of them Agent and 0 Explore. Over the measured window, 32 Agent
calls were Rule-29-denied and 0 were Explore. So the carve-out would newly allow 0 of graph's real
denied calls.

The receipt drives the hook with two seeded payloads in a paused scratch tree. It exits 0 when an
Explore dispatch is allowed, 1 when it is denied, and 9 when the `ops` control is not denied, because
a hook that allows everything must not close this entry. It reads 0 at this tip and 1 at `11ae360d`.

verify: sh H=core/hooks/ai-dlc-acknowledge.sh; [ -f "$H" ] || exit 9; command -v jq >/dev/null 2>&1 || exit 9; D="$(mktemp -d)" || exit 9; mkdir "$D/_bmad-output" || exit 9; : > "$D/_bmad-output/pipeline-snapshot.md"; : > "$D/_bmad-output/pipeline-paused.flag"; E="$(jq -nc '{session_id:"r",tool_name:"Agent",tool_input:{subagent_type:"Explore",prompt:"list the callers of sprint-status.sh"}}' | HOME="$D" CLAUDE_PROJECT_DIR="$D" bash "$H" 2>/dev/null)"; O="$(jq -nc '{session_id:"r",tool_name:"Agent",tool_input:{subagent_type:"ops",prompt:"list the callers of sprint-status.sh"}}' | HOME="$D" CLAUDE_PROJECT_DIR="$D" bash "$H" 2>/dev/null)"; rm -f "$D/_bmad-output/pipeline-snapshot.md" "$D/_bmad-output/pipeline-paused.flag" "$D/_bmad-output/pipeline-continuation-log.md"; rmdir "$D/_bmad-output" "$D" 2>/dev/null; case "$O" in *'"permissionDecision": "deny"'*) ;; *) exit 9 ;; esac; case "$E" in *'"permissionDecision": "deny"'*) exit 1 ;; esac; exit 0
