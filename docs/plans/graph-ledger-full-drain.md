# Drain the graph consumer's push-candidate ledger — full sweep

## RESUME HERE

**You were started with one sentence: `READ and FOLLOW docs/plans/graph-ledger-full-drain.md`.
This section is the whole of your entry point, and it is the ONLY CURRENT STATUS RECORD in this
file.** Everything from `## Context` down is HISTORY — measured episodes, refuted hypotheses,
and status records that were current when they were written and that THIS BLOCK REPLACES. Read
it when a rule looks arbitrary or when you need the evidence behind a figure. **Do not take an
instruction from it.**

### START HERE: SWEEP THE CONSUMER FOR NEW PUSH CANDIDATES, THEN PICK FROM THE UNFILED SET.

**YOUR FIRST ACTION IS NUMBERED ACTION 1 BELOW — the sweep for candidates the consumer has filed
since `v0.433.0`.** Standing operator instruction: do it before picking any subject, and report
what it finds. The sweep is cheap and it has now caught a same-day filing four batches running,
including one that arrived WHILE batch 19 was running.

**The baseline, re-derived at `v0.433.0` by running the derive block below: 66 live candidates,
130 archived, of which 33 are UNFILED.** The partition is **10 DISCHARGED / 23 IN-FLIGHT /
33 UNTOUCHED**, summing to 66, with **0** discharged-but-unnamed and **22 TERMINAL** — so 32
candidates delivered in total, 22 of them already closed by the consumer. Re-derive it: the live
count moved by one DURING batch 19, and it has moved between two consecutive commands in this
program more than once.

**SPRINT 306 IS FULLY DISCHARGED AND IS NOT A SOURCE OF WORK. Do not go looking for it.**

### BATCH 20's SUBJECT IS RECOMMENDED AND MEASURED: `BL-119`.

**This is the strongest-evidenced recommendation this plan has carried, because for once the
number comes from the CONSUMER's own state rather than from ours.** Batch 19 fixed the override
half of the adjudication branch and then measured what that does to the reference consumer: it
changes **zero rows today**. The non-keep verdicts are not on the override side. Counted in
`/Users/n8/git/graph/_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl`, with the
`still-additive` count as the control in the same invocation:

```
17 contradicts-core + 3 retire = 20 non-keep records   (265 still-additive)
19 of the 20 are against `extensions/` entries
 1 is against an `overrides/` entry, and the digest that currently resolves for it
   carries `still-additive` -- which is why batch 19's fix moves nothing here yet
```

`BL-119` is the extension half: `apply.sh` correctly suppresses the re-read row on any recorded
verdict, because any verdict discharges a re-read — but `retire` and `contradicts-core` are
recordable against an extension, are honest answers, and **authorize nothing, because no extension
remedy emitter exists anywhere in `core/`**. Nineteen consumer decisions currently reach no actor.
It carries a scored receipt already. **It is NOT PC-backed** — it was found here, so it ranks
below anything the sweep turns up; take it if the sweep is quiet.

Everything from here to the numbered actions is a RECORD of batches 17, 18 and 19. Read it for the
measured episodes; **do not take an instruction from it.**

### BATCH 19 IS DONE AND SHIPPED AS `v0.433.0`, MERGED AT `ecaf3577ce85`.

It took `PC-S307-RECORDED-VERDICT-SUPPRESSES-THE-REMEDY-IT-AUTHORIZES`, filed by the consumer the
same morning the batch opened. `apply.sh` matched the adjudication token's PRESENCE and suppressed
the ATOMIC override-retire sequence for every member of a three-member vocabulary, so recording
the honest `retire` was what made the remedy unreachable. The suppression now branches on a
`ADJ_KEEP_VERDICT` declared once in `layer-drift.sh` and resolved by `apply.sh`, `I86` binds the
second name and joins it to the schema that owns the member set, and `apply-worklist-rows` gained
four directions plus a differential.

**THE FIX INTRODUCED A SECOND FAILURE THAT COULD NOT HAVE EXISTED BEFORE IT, AND ONLY DRIVING THE
LOOP FOUND IT.** The detail field's tokens are an ordered prefix parsed positionally and the
adjudication token sits ahead of them, so a row falling through with it attached matches neither
`replaces_with=` nor `retire_anchor=` and lands in the arm that says *"core supersedes this
entry"* — which an operator obeys by deleting an override file core superseded ONE anchor of.
**Ask what a branch makes REACHABLE, not only what it decides.**

**THE FIRST DRAFT OF THE NEW INVARIANT ARM WAS VACUOUS AND ITS OWN MUTANT SAID SO.** A whole-file
grep for `$ADJ_KEEP_VERDICT` is satisfied by the RESOLUTION block's own `[ -z ... ]` guard twenty
lines above the branch, so a file that resolves the name and then branches on something else
passed. Scoping the read to the loop body fixed it. **Four mutants and two near-misses, and only
the mutant caught it.**

**A NEW FATAL MADE ANOTHER ENTRY'S RECEIPT REPORT FIXED, AND THE HISTOGRAM IS THE ONLY REASON
ANYONE LOOKED.** `BL-037` drives the real `apply.sh` against a stub `layer-drift.sh` declaring only
the row token; the new fail-closed gate aborted before the rows it asserts, and its receipt read
the absence as the fix — exit 1 at `origin/main`, exit 0 on the branch, identical receipt text,
three runs each. Run the receipt histogram BEFORE and AFTER, every batch.

**THE GATE REFUSED ONE PUSH AND THE REFUSAL WAS CORRECT** — a shipping fixture's comment cited
`docs/vocabulary-index.md`, a dev-repo doc `install.sh` does not ship, so the citation is dead in
every consumer tree.

**ONE OF FOUR HANDS DELIVERED, AND IT WAS THE ONE WITH A TREE DELIVERABLE — for the fourth batch
running.** The fixture hand produced the batch's best work unprompted, including the strip arm and
the verdict differential. The scope and receipt hands went idle without reporting and were still
idle after a direct request; the lead did both jobs. **Budget for that. It is not an anomaly any
more, it is the base rate.**

### BATCH 18 — A RECORD, SHIPPED AS `v0.430.0`. IT DISCHARGED THE LAST TWO SPRINT-306 CANDIDATES.

**Merged to `main` at `1febf3b9`, all gates green.** Operator ruled to take both. What landed:

| candidate | what landed |
|---|---|
| `PC-S306-GATE-REVIEW-ARTIFACTS-WRITTEN-OUTSIDE-SPRINT-SLOT` | `code-reviewer.md` and `qa.md` now prescribe `docs/reviews/s<N>/…`; invariant **I99** catches the class at prescription time; `artifact-path-conformance` section 7 guards both |
| `PC-S306-RETRO-AUTOCOMPACT-TRANSCRIPT-FILE-ASSUMPTION-UNVERIFIED` | `retro.md` and `validate-steering-budget.sh` at FOUR sites; the N>1 rule now gates on HANDOFF only |

**THE ADVERSARIAL PASS RAN BEFORE THE MERGE AND IT PAID FOR ITSELF AGAIN.** It found that **I99
acquitted a path that BLOCKS a consumer push** — `s<N>/<story-id>-review.md`, where the slot is
correctly placed and the id still expands sprint-first — and that the arm's own remedy pointed at
that form while its own probe asserted the acquittal every run. The same false claim had already
reached consumer-facing prose. **A mechanism that defends its own defect is the worst shape this
program produces, and only an adversary looking at it before the merge found it.**

**THE GATE REFUSED THREE OF SIX PUSHES AND EVERY REFUSAL WAS CORRECT** — `validator-fork-budget`
twice, `wait-beat-liveness` twice. Budget for it.

### BATCH 17 — A RECORD, SHIPPED AS `v0.429.0`. IT DISCHARGED NINE OF THE SPRINT-306 TWELVE.

**BATCH 17 TOOK THE REMAINING THREE SPRINT-306 CANDIDATES AND SHIPPED THEM AS `v0.429.0`**, on an
explicit operator ruling taken twice: first on the seventh candidate alone, then — when the
consumer filed two more WHILE THE BATCH WAS RUNNING — on all three together. **The sprint-306 set
was nine candidates at the moment batch 17 closed and every one of those nine is
discharged. A TENTH arrived with the retro minutes later and is outstanding — see the block
above.** The three batch 17 took:

| candidate | what landed |
|---|---|
| `PC-S306-UNSOLICITED-CONTEXT-HAS-NO-PROVENANCE-SIGNAL` | `core/hooks/ai-dlc-context-provenance.sh`, a sourced library; all nine `additionalContext` emitters open with a marker line carrying a nonce written to `_bmad-output/.ai-dlc-context-nonce`. `I98` binds the fleet both ways |
| `PC-S306-WAIT-BEAT-CANNOT-DISTINGUISH-SLOW-FROM-NEVER` | the beat reads teammate transcript mtimes and reports `TEAMMATE IDLE, DELIVERABLE ABSENT` / `LIVENESS` / `unavailable`; threshold measured over 1,337 real transcripts |
| `PC-S306-WORKTREE-DELIVERABLE-PATH-AMBIGUOUS-PRIMARY-VS-WORKTREE` | item 7 of the worktree dispatch protocol, sited in the NUMBERED list where the lead authors the prompt |

**THE CONSUMER FILED TWO CANDIDATES MID-BATCH AND THAT IS NOW THE SECOND CONSECUTIVE BATCH IT HAS
HAPPENED IN.** Live candidates went 67 → 69 → 70 while this batch ran. **Re-derive the set at the
START of any batch and again before you close it**, and do not treat a growing set as a reason to
narrow scope — that is the operator's call and they have now made it the same way twice.

**THE PULL REMAINED DEFERRED AND THE GAP WAS FOUR RELEASES AT THAT POINT.** Batch 17 renamed,
re-scoped and RE-REHEARSED the runbook for the `0425 -> 0429` range. **That rehearsal is now
SPENT: batch 18 shipped `0.430.0`, so the file was renamed again to
`docs/plans/graph-pull-0425-to-0430.md` and every figure in it is stale by one release and
marked as such in its own head block. Do not read this paragraph as saying a current rehearsal
exists.**
Consumer installed **0.425.0**, distribution **0.429.0**, **nine** discharged candidates the
consumer cannot see. Keep measuring and reporting it per action 7; do not run it.

### THE REHEARSAL FOUND A DEFECT THAT WOULD HAVE REACHED EVERY CONSUMER, AND THAT IS THE BATCH'S BEST FINDING

The incoming `apply.sh` emitted `WORKLIST settings-merge … hook(s) present and UNREGISTERED:
ai-dlc-context-provenance.sh`. That file is a SOURCED LIBRARY — no event invokes it — so the row's
own remedy, registering it, would have wired every consumer's settings to a command that reads no
stdin and decides nothing. **The pull would have handed every consumer an instruction to do the
wrong thing, in a row whose entire purpose is to be obeyed.**

The exemption had been taught to the distribution's `I13` and to the `hook-registration-join`
fixture, and NOT to `core/scripts/validate-hook-registration.sh` — the copy a CONSUMER runs and
the OWNER of the predicate. **A green run here and a green run there are not the same claim, and
this is the shape that difference takes.** Nothing in this repo could have found it: only driving
the real pull against a real consumer copy did.

**REHEARSE EVERY RUNBOOK AGAINST A SCRATCH COPY BEFORE WRITING ITS NUMBERS.** This is the first
time in the program that the rehearsal caught a consumer-facing defect rather than merely
producing figures.

### WHAT ELSE THIS BATCH MEASURED, EACH OF WHICH COST A GATE RUN

**THE GATE REFUSED FOUR PUSHES AND EVERY REFUSAL WAS CORRECT.** `I77` twice on the same file,
then a fixture bound, then a boundary arm. Budget for it: a batch that adds a hook, a library or
a fixture directory will not pass first time.

**`git update-index --chmod=+x` SETS THE INDEX, AND THE NEXT `git add` UNDOES IT.** `I77` fired
twice on `ai-dlc-context-provenance.sh` because the working-tree file was still 0644 and a later
`git add -A` re-read the mode off disk. `chmod +x` the FILE, then add.

**A NEW SessionStart PAYLOAD CAN BREAK POST-COMPACTION RECOVERY, SILENTLY.** The provenance
contract attached to every SessionStart emission put `ai-dlc-recover.sh`'s block at **10482**
characters against a 9500 bound and a **10000 cliff past which the harness replaces the entire
block with a file-path stub** — the fix for one silent failure causing another, in the one hook
whose job is surviving a compaction. It had 427 characters of headroom. **Site a new payload on a
hook with budget; do not shorten a security explanation to fit.**

**A PER-EMISSION NONCE BREAKS EVERY BYTE-COMPARISON OF HOOK OUTPUT.** Four fixture arms asserted
either the contract's old location or byte-identity across two emissions. All four were
re-anchored, none relaxed. **Ask what a change makes permanently true downstream** — here, that
two emissions of one hook now differ by design.

**AN ADVERSARIAL HAND FOUND FOUR DEFECTS IN THE FIX BEFORE IT LANDED AND ALL FOUR WERE REAL.** The
marker was not a LINE at seven of nine call sites (`$( )` strips trailing newlines, so a
line-anchored check scored **0** on a real emission and **1** on the library's own output); the
header claimed the nonce was unreachable by a tool result, which is false — the property is about
ORDERING, not the channel; the stated replay window was tighter than the enforced one; and a third
limit went unstated, that membership in a MUTABLE LOCAL FILE makes write access forge access.
**Run the adversarial pass BEFORE the merge. This is the first batch that did, and it is the
reason the release is correct.**

**THE ADVERSARY ALSO FILED A FALSE FINDING WORTH KEEPING.** It reported a destructive `git clean`
deleting untracked fixture directories mid-flight, having measured three directories vanishing
together with zero `??` entries. That was the lead's own `FORK_BUDGET` differential — `mv` out,
measure, `mv` back. **The observation was right and the inference was wrong, and the underlying
ask still stands**: an untracked directory moved aside is indistinguishable from one deleted, and
a hand writing into that path during the window would have been clobbered by the restore. Commit
new fixture directories BEFORE taking a differential over them.

**TWO OF THE LEAD'S OWN INSTRUMENTS WERE WRONG AND THE HARNESS SAID SO RATHER THAN SCORING A
KILL.** `grep -c` PRINTS 0 and EXITS 1 on no match, so a `|| printf 0` fallback emitted a SECOND
zero and a comparison read a two-line value. And a receipt carried a LITERAL NEWLINE inside a
quoted payload — `backlog-reverify.sh` extracts one line, so it scored 0 from the file and 1
through the engine. **A multi-line receipt mis-scores silently forever.**

**A RECEIPT ORDERING BUG THAT ONLY SCORING FOUND.** New contract assertions called a function
that ROTATES the nonce, and sat between capturing a nonce and asserting its reuse — so the
receipt failed against the correct fix. **Scoring is not a formality; it has now moved a receipt
in four consecutive batches.**

**FOUR OF FOUR HANDS DELIVERED AGAIN**, every one with a TREE deliverable. The fixture hand's
arms were RIGHT and the lead's library was WRONG on the blank-line path — the fixture failed,
the library was fixed, and that is the mechanism working in the direction it is built for.

### THE GOAL, restated because this program measurably drifted off it

**The subject of this plan is the GRAPH CONSUMER'S push-candidate ledger — the 82 `PC-` ids in
`/Users/n8/git/graph/_bmad-output/ai-dlc-update/push-candidate-ledger.md`. It is NOT
`docs/backlog.md`.** The backlog is the working form the candidates were filed into; it is an
instrument, not the goal. **OPERATOR RULING, and it settles the priority: the original goal
stands. Hardening ai-dlc is secondary — worthwhile, and ranked BELOW the ledger.**

**THE GOAL WAS IN THE FILENAME, THE TITLE AND THE OPENING SENTENCE, AND IT STILL DRIFTED FOR TEN
CONSECUTIVE FILINGS.** The session that drifted typed `graph-ledger-full-drain.md` a dozen times
while doing it. So the failure was not that the goal went unstated — it was that nothing DERIVED
it. Every command in the numbered action list measured `docs/backlog.md`; not one measured the
ledger, so every batch's evidence was about the instrument and none was about the subject. A goal
stated in prose at the top of a file is carried by the reader's ATTENTION, and twelve batches is
longer than attention lasts; `resident-context.md` already says a rule survives only if something
other than memory carries it, and a title is memory. The `PC-` join in the derive block above is
the carrier. The title never was one. **So do not read the drift as the previous session being
careless, because the next session will then assume it would have noticed — assume instead that
whatever this file does not DERIVE, it will lose.**

**THIS PLAN IS NOT A MECHANISM FOR EMPTYING `docs/backlog.md`, AND READING IT AS ONE IS WHAT
WENT WRONG.** Measured at batch 12's close: **the last TEN entries filed — `BL-089` through
`BL-098` — cite ZERO `PC-` ids.** Every one is an ai-dlc-internal discovery. 34 of 69 live
entries trace to a candidate; **35 do not.** Batch 13 had been queued against three entries with
no consumer provenance and no consumer surface, because the selection rule was "readiest to
close", which systematically favours defects the session found itself and already knows how to
fix. Pick by PROVENANCE first, then by consequence.

**A RISING BACKLOG IS NOT THIS PROGRAM FAILING, AND THE OPERATOR HAS RULED ON IT.** Resolving a
PC-backed entry will often FILE new entries, and will sometimes close pre-existing ones that
carry no classification at all. Both are expected. Do not treat the live count as a progress
metric and do not narrow a fix to avoid filing what it uncovers — **the number that measures this
program is candidates discharged, never entries remaining.**

**Two repos, and the boundary is absolute.** `/Users/n8/git/ai-dlc` is WRITE.
`/Users/n8/git/graph` is the reference consumer and is **READ ONLY** — an ai-dlc session never
writes to a consumer. Assert it by ledger CONTENT, not by dirty count and not by `HEAD`:
`md5 -q /Users/n8/git/graph/_bmad-output/ai-dlc-update/push-candidate-ledger.md`. Record the
value before your first action and re-check it after every phase. **When it moves, run
`git -C /Users/n8/git/graph diff` on that path, identify the writer, and PING THE OPERATOR
either way** — the ping is not conditional on the answer, only its content is. Measured during
batch 8: it moved mid-session because a live graph session was appending an S305 retro entry,
with that consumer's `HEAD` advancing and its own s305 artifacts appearing untracked. A
concurrent graph session is the expected cause; your own write is the one that stops the work.
Full boundary in `## Start here` below, and in `.claude/rules/consumer-boundary.md`.

**Never run `git checkout --`, `git restore`, `git clean`, `git stash`, or `git reset --hard`
in either repo, and tell every delegate the same.** Delegates work in `mktemp` copies made with
`git archive HEAD | tar -x`.

### Derive the state; do not trust the numbers below

Every figure here is a HYPOTHESIS about a tree that has moved. The measured base rate of expired
premises in this program is roughly one in two. Each command below carries its own control.

```
git -C /Users/n8/git/ai-dlc log --oneline -1 origin/main
grep -cE '^## BL-[0-9]+' docs/backlog.md          # live entries
grep -cE '^## BL-[0-9]+' docs/backlog.archive.md  # archived
bash scripts/backlog-reverify.sh | grep -oE 'CLOSE-CANDIDATE|STILL-LIVE|HAND-REVIEW|NEEDS-REVIEW' | sort | uniq -c
```

**AND THE JOIN THAT MEASURES THE ACTUAL GOAL, which the block above does not.** Those four
commands describe the INSTRUMENT. This one describes the SUBJECT, and until batch 12 nothing in
this file derived it:

**READ THE ARCHIVE, AND KEY IT ON BOTH RECORD FORMS. A BARE TOKEN GREP IS NOT A CANDIDATE
COUNT, AND NEITHER IS A HEADING GREP.** This block has now been wrong twice, in opposite
directions, and the second time is the instructive one.

The first version grepped every `PC-`-shaped token out of the live ledger and called the result
"candidates". It counted **82** where the headings give **40**: the surplus is bare sprint
prefixes (`PC-S296`, `PC-S333`), truncations (`PC-S3`, `PC-S295-`), and cross-references in prose
to candidates that now live in the ARCHIVE. It also never opened
`push-candidate-ledger.archive.md` — so every mention of an already-closed candidate scored as an
unexamined one.

**BATCH 13 REPLACED IT WITH A `^## PC-` HEADING GREP, AND THAT GRAMMAR CANNOT SPELL A THIRD OF
THE LEDGER. BATCH 14 ADDED A BULLET ARM AND IT STILL MISSED A THIRD FORM.** The consumer records
a candidate in THREE forms. This grammar has now been wrong THREE TIMES, each time in a way that
returned a clean, plausible number:

```
## PC-S314-PRECLASSIFY-BUCKETS-A-MODE-ONLY-CHANGE-...
- **PC-S295-RETRO-CHECK5-SELF-REFERENTIAL — Check 5 compares two hand-maintained records to
  each other and cannot fail (filed 2026-07-21)**
- **PC-S336-STEP-1-AUTOPUSH-IS-THE-UNGUARDED-TWIN-OF-THE-PUSH-STEP-2-HARDENED** — step 1's ...
```

**The third form closes its bold IMMEDIATELY after the id**, where the second continues into
prose. Batch 14's bullet arm required a trailing SPACE after the id (`^- \*\*PC-[A-Z0-9-]+ `),
so it scored every bare-bold entry as a non-instance. Measured at v0.425.0, both directions, with
the partition and an impossible id as controls:

```
              batch 14's grammar    actual    invisible
live                  47              60         13
archive               92             122         30
```

**THE ENTRY THAT PROVES IT IS ITSELF IN THE MISSED SET.** The consumer had already filed
`PC-S305-BARE-BOLD-ENTRY-IS-INVISIBLE-TO-EVERY-REVERIFY`, in bare-bold form, describing this exact
defect — and it was invisible to this grammar BECAUSE of the defect it describes.

**DO NOT READ THAT ENTRY'S TITLE AS OVERSTATED. A REVISION OF THIS BLOCK DID, AND IT WAS WRONG.**
The reasoning was that `ledger-reverify` still emits a `HAND-REVIEW` row for the entry, so
"invisible to EVERY reverify" must be too strong. That **conflates the entry's own FORM with its
SUBJECT**. The entry is written as a dashed bullet, so of course reverify sees it; its subject is
the DASH-LESS `**<id>**` at column 0, and for that form the title is exact. Measured here: one such
line exists in the archive today. **Ask what a finding's subject is before scoring its title against
the artifact that carries it** — the carrier and the claim are different objects.

**A FOURTH SHAPE, AND IT PRODUCES A WRONG ID RATHER THAN A MISSING ONE, WHICH IS WORSE.** An id may
embed a version: `PC-S300-SEVEN-VALIDATORS-SHIPPED-NON-EXECUTABLE-AT-0.242.0`. A `[A-Z0-9-]`
character class stops at the `.`, so the loose arm above MATCHES the line and extracts
`…-NON-EXECUTABLE-AT-0` — a truncated id that is a FALSE MEMBER of the set, joins against no
backlog citation, and never appears as an absence. The class is `[A-Z0-9.-]` below for that reason.
Cardinality is unaffected (122 either way); one id stops being wrong.

Under the widened class the bullet forms partition with NO REMAINDER, which is the control that the
counts are complete rather than merely larger — live **22 = 9 spaced + 13 bare-bold**, archive
**41 = 11 + 30**.

**A cited id that resolves to nothing is a claim about your GRAMMAR before it is a claim about the
ledger.** Point the grammar at its own subject before believing its zero, and note that the two
earlier repairs both PASSED their own controls — a control drawn from the form you already know
about cannot discover the form you do not.

**`sed -E '...;t;d'` IS NOT PORTABLE AND THE FIRST CUT OF THIS BLOCK USED IT.** BSD sed answers
`undefined label ';d'`, both files come back EMPTY, and the partition control — *"must be 0"* —
comes back 0 and AGREES. Only the PRESENCE control, which must come back 1, catches it. That is
why both controls are here and why one of them is positive.

**KEY THE OTHER SIDE ON A BACKLOG ENTRY, NOT ON `docs/`.** A grep over all of `docs/` counts
`docs/reviews/graph-ledger-*`, which is the ADJUDICATION corpus and mentions very nearly every
candidate by construction — so it scores the whole ledger as covered and reports 3 unnamed.
Worse, it is not even stable: writing an id into this plan MOVES it from unnamed to named, and
the first cut of this block did exactly that to all three of its own findings. A candidate is
taken up when a BACKLOG ENTRY cites it. Prose is not a filing.

```
D=/Users/n8/git/graph/_bmad-output/ai-dlc-update
# TWO deliberate widenings, each one a measured defect:
#   1. NO TRAILING SPACE after the id -- that space hid 43 of 63 bullet-form entries.
#   2. THE CLASS INCLUDES `.` -- an id may embed a version, and [A-Z0-9-] truncates it into a
#      FALSE MEMBER that joins against nothing and reports as no absence at all.
# The optional `-? ?` also admits the DASH-LESS `**<id>**` at column 0, which is the subject of
# PC-S305-BARE-BOLD-ENTRY-IS-INVISIBLE-TO-EVERY-REVERIFY.
lids() { { grep -h '^## PC-' "$1" | sed -E 's/^## (PC-[A-Z0-9][A-Z0-9.-]*).*/\1/'
           grep -hE '^-? ?\*\*PC-[A-Z0-9]' "$1" | sed -E 's/^-? ?\*\*(PC-[A-Z0-9][A-Z0-9.-]*).*/\1/'
         } | sort -u; }
lids "$D/push-candidate-ledger.md"         > /tmp/live.txt
lids "$D/push-candidate-ledger.archive.md" > /tmp/arch.txt
grep -rohE 'PC-[A-Z0-9][A-Z0-9-]+' docs/backlog.md docs/backlog.archive.md | sort -u > /tmp/filed.txt
wc -l < /tmp/live.txt                                 # LIVE candidates -- the denominator
wc -l < /tmp/arch.txt                                 # already closed upstream, NOT our workload
comm -12 /tmp/live.txt /tmp/arch.txt | wc -l          # control: must be 0, the two sets partition
comm -12 /tmp/live.txt /tmp/filed.txt | wc -l         # live candidates a backlog entry cites
comm -23 /tmp/live.txt /tmp/filed.txt                 # live candidates NOTHING has filed
grep -cx 'PC-S333-SKILL-RENDERS-THE-THEIRS-REF-UNQUOTED-AND-ZSH-EATS-IT' /tmp/filed.txt  # control: 1
grep -cx 'PC-S295-RETRO-CHECK5-SELF-REFERENTIAL' /tmp/live.txt   # control: 1, a SPACED bullet
grep -cx 'PC-S336-STEP-1-AUTOPUSH-IS-THE-UNGUARDED-TWIN-OF-THE-PUSH-STEP-2-HARDENED' /tmp/live.txt
                                                      # control: 1, a BARE-BOLD bullet -- this is
                                                      # the arm that fails if anyone reinstates the
                                                      # trailing space, and a reinstated grammar
                                                      # reads as a clean, plausible 47
grep -cx 'PC-S300-SEVEN-VALIDATORS-SHIPPED-NON-EXECUTABLE-AT-0.242.0' /tmp/arch.txt
                                                      # control: 1, a DOTTED id. Fails as a TRUNCATION
                                                      # if the class loses its `.`, and a truncated id
                                                      # is a false member, never a reported absence
grep -cx 'PC-S999-NEVER' /tmp/filed.txt                                                  # control: 0
```

Re-derived at v0.433.0: **66 live candidates, 130 archived**, partition control 0, all three
presence controls 1, absence control 0. **The live count rose from 60 to 65 and then to 66
across two consecutive ai-dlc sessions** — graph sessions filed sprint 306's candidates while
this file was being edited, and the ledger's md5 moved four times in all, twice while a batch
was running against it. **It moves when the CONSUMER WRITES, not only when they close**, so a
figure here is a snapshot of a file someone else is holding open. Batch 14's figures — 49
live, 90 archived — were the same ledger read through a grammar missing one record form.

**"CITED" IS STILL NOT THE PROGRESS METRIC, AND THIS IS THE LAST STEP OF THE DERIVATION.** A
candidate cited by a LIVE entry is work in flight; one cited by an entry in the ARCHIVE has been
discharged. Splitting the cited set is what turns this block into a measurement of the goal instead of a
measurement of coverage — and the operator has had to say so twice, because every report of this
program has led with `docs/backlog.md`'s live count, which moves for reasons that have nothing to
do with the ledger. **Report the partition below. Never report live/archive entry counts as
progress.**

```
pc() { grep -rohE 'PC-[A-Z0-9][A-Z0-9-]+' "$1" | sort -u; }
pc docs/backlog.archive.md > /tmp/closed_here
pc docs/backlog.md         > /tmp/open_here
git log --format='%B' origin/main | grep -ohE 'PC-[A-Z0-9][A-Z0-9-]+' | sort -u > /tmp/in_msgs
comm -12 /tmp/live.txt /tmp/closed_here                    # DISCHARGED, still live upstream
comm -12 /tmp/live.txt /tmp/open_here                      # in flight
comm -23 /tmp/live.txt <(sort -u /tmp/closed_here /tmp/open_here)   # untouched
# control: the three MUST sum to the live denominator, or the partition is lying
comm -12 /tmp/live.txt /tmp/closed_here | comm -23 - /tmp/in_msgs   # discharged but INVISIBLE
# TERMINAL -- discharged here AND closed in the consumer's ledger. The line above CANNOT see these.
comm -12 /tmp/arch.txt /tmp/closed_here | wc -l
```

Re-derived at v0.433.0 by running the commands: **10 DISCHARGED, 23 in flight, 33 untouched**,
summing to 66, **0 discharged-but-unnamed**, and **22 TERMINAL**. The overlap the control catches
is still the single `PC-S303-STUB-AUDIT-MARKER-...` id, subtracted from DISCHARGED. That unnamed line is a real
failure mode and not a formality: a fix that ships without its id in the commit MESSAGE discharges
the candidate and produces no row anywhere, so the consumer never learns of it.

**THE PARTITION CONTROL FIRED FOR THE FIRST TIME AT v0.428.0, AND THE CAUSE IS A CITATION THAT
MEANS THE OPPOSITE OF WHAT THE JOIN ASSUMES.** The three buckets summed to **67** against a live
denominator of **66**. `DISCHARGED` and `IN-FLIGHT` are not disjoint: an id cited by an ARCHIVED
entry AND by a LIVE one lands in both. The overlapping id is
`PC-S303-STUB-AUDIT-MARKER-REGEX-MATCHES-LOCAL-VAR-NAMED-STUB`, and `BL-109` cites it **to say
it is a DIFFERENT candidate that its own fix does not close** — the sibling entry that motivated
the distinction. **A `PC-` token in an entry is not a claim of ownership; `pc()` cannot tell
"I close this" from "I am not this".** Subtract the overlap from `DISCHARGED`, never from
`IN-FLIGHT`: a live entry citing an id is work in flight whatever an archived entry said about
it. Corrected, the batch reads 12 / 22 / 32 = 66.

```
comm -12 /tmp/live.txt /tmp/closed_here > /tmp/d.txt
comm -12 /tmp/live.txt /tmp/open_here   > /tmp/f.txt
comm -12 /tmp/d.txt /tmp/f.txt          # the overlap. NOT zero, and not an error
comm -23 /tmp/d.txt <(comm -12 /tmp/d.txt /tmp/f.txt) | wc -l   # DISCHARGED, corrected
```

**Do not "fix" this by narrowing the grammar.** A citation's INTENT is not derivable from the
token, and a grammar that tried would be the fourth wrong spelling this block has shipped. The
overlap is small, enumerable, and worth reading by hand.

**THE `DISCHARGED` LINE FALLS WHEN THIS PROGRAM SUCCEEDS, AND THAT IS WHY `TERMINAL` IS NOW BESIDE
IT.** `DISCHARGED` intersects our archive with the LIVE ledger, so the moment a consumer closes a
candidate it leaves `live.txt` and drops out of the numerator. The count went **7 → 5** across the
pull that closed two candidates — the program's own scoreboard resets on success. This is
`mechanism-design.md`'s "a fix that satisfies a join by deleting the join's subject reads as green
forever", inverted: here the subject's deletion reads as REGRESS.

**REPORT `TERMINAL` AS THE DELIVERED TOTAL AND `DISCHARGED` AS WORK AWAITING THE CONSUMER'S OWN
CLOSE.** They are disjoint, because `live.txt` and `arch.txt` partition. At v0.433.0 that is
**22 delivered and closed, 10 delivered and awaiting close — 32 in total against a headline of 10.**
The 0.430.1 -> 0.432.0 pull is what moved eight of them from the second bucket to the first, and
the headline FELL from 17 to 10 as it did — which is the scoreboard resetting on success, exactly
as the paragraph above says it does.
Both figures are ceilings on coverage rather than adjudications, for the reason the next paragraph
gives: a citation is a filing, not a disposition.

**TWO CANDIDATES REACHED TERMINAL STATE AND NO COUNT THIS PROGRAM EVER MADE INCLUDED THEM** —
`PC-S329-NAMED-UPSTREAM-DETAIL-INSTRUCTS-THE-CLOSE-ITS-OWN-STATUS-FORBIDS` and
`PC-S330-LEDGER-ROTATE-STUCK-SET-CONTRADICTS-THE-SKIP-RULE-IT-CITES`. Both are bare-bold in the
consumer's ARCHIVE, so the old grammar could not see them there, and both are cited by an archived
backlog entry here, so the `DISCHARGED` line could not see them either. Delivered, closed, counted
nowhere. They are the reason both repairs in this block had to land together: fixing the grammar
alone would still have left them in no bucket.

**TWELVE OF SIXTY-SIX, OR TWENTY-SIX OF ONE HUNDRED AND EIGHTY-EIGHT, DEPENDING ON WHICH QUESTION
YOU ASKED.**
State which. Every progress figure quoted before v0.425.0 was against a denominator 28% too small
and a numerator that silently shed its own successes.

**AND "DISCHARGED" IS STILL A CLAIM ABOUT THIS TREE, NOT ABOUT THE CONSUMER.** A consumer runs
its OWN installed engine. Until graph PULLS, none of this reaches it, its ledger does not move,
and this program's goal — draining THAT ledger — cannot be closed on the side that matters.
Derive the gap; it is not optional bookkeeping:

```
awk -F': ' '/^version:/{print $2; exit}' /Users/n8/git/graph/.claude/.ai-dlc-version   # installed
cat VERSION                                                                            # shipped
# per discharged id, the release that FIRST named it -- named_absorbed() takes tail -1
git log --format='%H' -F --grep="<id>" origin/main | tail -1                            # then git show "${sha}:VERSION"
```

**THE GAP CLOSED AND THEN REOPENED AT ONE RELEASE. AT v0.433.0 IT IS ONE RELEASE AND ONE
CANDIDATE.** The deferred pull RAN: the consumer reconciled `0.430.1 -> 0.432.0` on 2026-08-28
and `.claude/.ai-dlc-version` reads **0.432.0** on all four fields. That pull is what moved eight
candidates from DISCHARGED to TERMINAL. Consumer installed **0.432.0**, distribution **0.433.0**,
pending set **`PC-S307`** from `v0.433.0`. Derived per-id against an impossible-id control of 0.

**The range is NOT wide, and the bootstrapping hazard IS live and has been measured rather than
warned about.** One release, three core paths, `self-update-gate.sh` returns `SELF-UPDATE-OK`
because no `core/scripts/` path is in the range, and zero mode-only changes. The specific hazard:
`apply.sh` now resolves a second declaration out of its sibling `layer-drift.sh` and is FATAL when
it cannot, so landing one without the other aborts every later apply — **both are in the range and
both bucket the same way, so the split cannot occur here.** That is a measurement on a `file://`
clone of both trees, not a reading of the code.

The runbook is `docs/plans/graph-pull-0432-to-0433.md`, written and REHEARSED at `v0.433.0`, and
**NOT STARTED**. `docs/plans/graph-pull-0425-to-0430.md` is DISCHARGED — read it as a worked
example, never as a live plan. **Keep measuring the gap and reporting it; do not run the pull, and
do not treat its growth as a reason to reorder the work.**

**EVERY PENDING CANDIDATE IS FROM A SPRINT THE CONSUMER IS STILL RUNNING.** That raises what the
deferral costs; it does not change whose call it is. Report the number and stop.

**AND THE REHEARSAL IS NOT OPTIONAL BOOKKEEPING — IT IS WHERE THIS PROGRAM'S ONLY CONSUMER-FACING
DEFECT WAS CAUGHT.** `v0.429.0`'s rehearsal found a `WORKLIST` row instructing every consumer to
register a sourced library as a hook. Re-rehearse before writing any figure into a runbook.

The gap was ZERO at v0.425.0, which was the first time in the program it had been closed. **A ZERO
GAP IS A STATE, NOT AN ACHIEVEMENT THAT STAYS TRUE**, and it went non-zero on the very next release
that discharged anything. Re-derive it every batch rather than reading any
sentence here. `PC-S333` and `PC-S314` remain CLOSED in the consumer's own ledger (live=0,
archive=1 for each), reached by the `0.415.0 → 0.425.0` pull.

**THE PULL IS NOT YOURS TO RUN.** `.claude/rules/consumer-boundary.md` is unconditional — an
ai-dlc session never writes to a consumer. The pull happens in a GRAPH session the operator
drives. What this plan owes is the GAP, measured, and a recommendation; **report it every batch
so the queue never becomes a surprise.**

**CHECK THE BOOTSTRAPPING HAZARD BEFORE RECOMMENDING A PULL, AND MEASURE IT RATHER THAN WARNING
ABOUT IT.** A fix to a step can never be delivered by that step: the broken version is the one
that runs the delivery. `PC-S314` repaired `preclassify.sh`, which IS the program the pull runs,
so the consumer's unfixed copy classifies the very pull carrying its own repair — and its defect
is a MODE-ONLY change bucketing `UPSTREAM-ONLY` forever, which is a non-terminating step 2.

Measured for this pull rather than asserted, and it comes back CLEAN:

```
git diff --raw <installed-commit>..origin/main -- core/    # mode-only = modes differ, blobs equal
```
**0 mode-only changes** across 38 changed core paths. The three mode changes in the range are all
`000000 -> 100755` file ADDS, which take the `A` branch, not the `M` branch the defect lives in.
So the hazard is real in general and does not bite this pull. **`PC-S314`'s fix takes effect on
the pull AFTER the one that delivers it** — say so in the brief rather than claiming the next
pull is protected by it.

**THE "FIVE UNRESOLVABLE FULL SLUGS" WERE ALL GRAMMAR ARTIFACTS, AND THAT CLAIM IS WITHDRAWN.**
Batch 14 reported eleven ids cited by live entries resolving to NEITHER ledger file, of which six
were citation-grep noise (`PC-S308`, `PC-S334`, `PC-S336`, `PC-S900-`, two `PC-S999-` probe
tokens) and **five were said to be real slugs naming candidates the ledger does not contain**:
`BL-039`, `BL-066`, `BL-016`, `BL-049`, `BL-017`. Re-measured at v0.425.0 under the corrected
grammar, **every one of the five has a resolving citation** — `BL-016`, `BL-017` and `BL-049`
resolve 1 of 1, `BL-039` 1 of 2, `BL-066` 4 of 8. The candidates were in the ledger the whole time,
in a record form the grammar could not spell.

**That is the same defect scoring its own subject as absent, one level over.** A missing candidate
and an unspellable one are the same output. Still establish that a citation resolves before picking
an entry as a batch subject — but run the CORRECTED grammar, and treat a non-resolving citation as
a hypothesis about the grammar first.

**Two of those 20 are new to this block at batch 14**, because they are bullet-form and the
heading grammar could not see them: `PC-S295-RETRO-PARALLEL-OPEN-COUNT-METHOD` and
`PC-S304-STUB-MARKER-REGEX-MATCHES-DOCSTRING-PROSE-AND-BARE-IDENTIFIERS`. Neither has been
examined by any batch.

**Two of the 20 are already dead upstream** — `PC-S300-ORIGIN-TAG-GATE-HAS-NO-WAIVER-FOR-TRACEABILITY-CITATIONS`
is **WITHDRAWN 2026-07-25, the premise was false**, and
`PC-S305-CHECK-17-BYPASS-CONSUMER-CASES-V8-V9-AND-A-PASSING-CONTROL` is **WITHDRAWN 2026-07-27,
REFUTED — its premise was a case-sensitivity artifact**. **Ten more are one sprint's cluster**,
`PC-S312-*`, several of which describe themselves as falsifiability probes for a retirement
rather than as defects. **Read each one's own status line before treating it as work** — that
is what this block has been asking for since batch 1, and the reason it never happened is that
the number it asked about was never a count of candidates.

**THE ID GRAMMAR IS `PC-<SLUG>`, NOT `PC-<NUMBER>`, and getting that wrong returns a clean zero
from BOTH sides.** A first pass keyed on `PC-[0-9]+` reported 0 ids in the ledger AND 0 in the
backlog, which reads as "the join is dead" rather than "the grammar is wrong". The control that
catches it is running the same expression against the ledger itself: if the SOURCE has none
either, the grammar is the defect. This is `verification-discipline.md`'s "point a search grammar
at its own subject before trusting its zero", met in the wild an hour after it was written down.

**"Cited" IS NOT "adjudicated".** A backlog entry naming an id is a FILING, not a disposition —
so the **29** is a ceiling on coverage, not a measurement of it. The **20** is the solid half:
those have not been examined at all. Their status in the consumer's own ledger is **NOT
ESTABLISHED**; some may already be `WITHDRAWN` or `ADOPTED` upstream. **Establish that before
treating 20 as a workload.**

Re-derived at v0.433.0 by running the commands, not by editing the sentence: **73 live / 46
archived**, against an impossible-verdict control of 0 and a `BL-006`-still-live control of 1.
Batch 16 filed six (`BL-104`–`BL-109`) and rotated all six in the same release, so live went
70 → 76 → 70 and the archive went 33 → 39. **Batch 14 recorded 31 archived and the rotation of
`BL-101` moved it to 32 without the sentence being updated** — which is this block's own failure
mode, one release after it was written down.

**THE CEILING BOUND THIS BATCH AND IT WILL BIND THE NEXT ONE.** `validate-backlog-size.sh` caps
the live file at **75** entries. Batch 16 opened at 72, filed six to reach 76 — over — and came
back to 70 only because every entry it filed was also fixed in the same release. **A batch that
files more than three entries it does not close breaches the ceiling**, and the gate reads the
WORKING TREE at push time, so an intermediate commit over the cap is not itself a failure.
Rotation is the lever; the ceiling is not a reason to file fewer findings.

**THE LIVE COUNT WENT UP ACROSS A BATCH THAT CLOSED AN ENTRY, AND THAT IS THE NORMAL CASE RATHER
THAN AN ERROR.** Batch 12 closed and rotated one (`BL-094`) and filed FOUR (`BL-095`, `BL-096`,
`BL-097`, `BL-098`), every one found by asking whether the entry being closed was WIDER than
filed. Do not read a rising live count as a batch that failed; read the ARCHIVE count, which only
ever moves on a real close.

**THE LEDGER NOW REPORTS ZERO `CLOSE-CANDIDATE`, AND THAT IS A RESULT RATHER THAN AN ABSENCE.**
The one it used to carry was `BL-006`, and it was FALSE — the receipt exited 0 on two COMMENT
lines in `scripts/validate-claude-rules.sh`, one of which said the mechanism "was offered and
declined for now". Batch 10 re-anchored it, so a zero here now means what it says. **If a
`CLOSE-CANDIDATE` appears, it is a hypothesis and not a verdict**: run the entry's receipt
directly, read the raw exit code, and ask what ELSE satisfies it before closing anything.

**A `STILL-LIVE` ROW IS NOT EVIDENCE THAT THE ENTRY IS LIVE, AND `BL-089` IS THE ENTRY THAT SAYS
SO.** `backlog-reverify.sh` maps every non-zero `sh` exit to `STILL-LIVE  … "still reproduces
here"`, but this corpus's receipts use **exit 9** to mean *"a precondition moved and I measured
nothing"*. The two are one row. Measured at batch 14's close: **58 exit 1, 1 exit 9, 0 exit 0**
across 59 `sh` receipts — the 9 is `BL-066`, whose receipt is broken shell. Batch 9 rebuilt the other one; `BL-076`'s had been unable to measure
anything for 28 releases and read as `STILL-LIVE` the whole time.
Derive the current pair rather than trusting that one; the count of live `sh` receipts moves
with every batch and the control is the entries declaring `verify: manual`, which the engine
does route to HAND-REVIEW.

**DERIVE THAT CONTROL FROM THE ENGINE, NOT FROM A GREP, AND HERE IS WHY BOTH GREPS ARE WRONG.**
`^verify: manual` returns 6 — it misses the three entries that INDENT the line, which
`backlog-reverify.sh`'s own grammar (`^[ \t]*verify:`) accepts. Fixing the indent gives 9, which
is also wrong: both counts include the `verify: manual` line in the `## Receipts` LEGEND at
`docs/backlog.md:25`, which is prose about the grammar and not an entry. The true number at
v0.419.0 is **8**, and the only reader that gets it right is the engine, because it starts
entries at a `BL-` id and never counts the preamble. An earlier revision of this block quoted 5
from the unindented grep; the revision after it fixed the PROSE and left the COMMAND, so the
file stated 7 beside a command returning 5. Every figure in this block was re-derived at
v0.419.0 by running the commands, not by reading the sentences. Run the engine:

This one is a LOOP, so run it through `bash -c` — your shell is zsh, where an unquoted `$var`
is not word-split and a loop written for bash iterates once over the whole string.

**IT GATES ON A `## BL-` HEADING FOR THE SAME REASON THE CONTROL BELOW USES THE ENGINE.** A bare
`grep "^verify: sh "` returns 56 against a true count of 55, because it also matches the
`verify: sh <one-liner>` line in the `## Receipts` LEGEND at `docs/backlog.md:22` — prose about
the grammar, which then gets EVALUATED as though it were a receipt and lands in the histogram as
a real exit code. It misses indented receipts too. Both halves of this block have now been wrong
in that same way, once each; the ledger's preamble is a receipt-shaped trap and every reader of
this file must skip it:

```
bash -c 'while IFS= read -r l; do ( eval "$l" ) >/dev/null 2>&1; echo "$?"; done \
  < <(awk "/^## BL-[0-9]+/{e=1} e && sub(/^[ \t]*verify: sh /,\"\")" docs/backlog.md) \
  | sort | uniq -c'
bash scripts/backlog-reverify.sh | grep -c '^HAND-REVIEW'   # the control: these DO reach it
```

**Before scoping any entry, run its receipt directly and read the raw exit code.** A 9 means
the row above told you nothing.

### What is DONE — do not redo any of it

**BATCH 16 IS COMPLETE, MERGED AND PUSHED AS `v0.428.0`. IT DISCHARGED ALL SIX SPRINT-306
CANDIDATES**, one commit each on one release branch, every id verbatim in its own release commit
message where `named_absorbed()` can read it — verified 1 hit each against an impossible-id
control of 0. `BL-104`–`BL-109` filed and all six CLOSED and rotated: live **70 → 76 → 70**,
archive **33 → 39**, `--check PASS` before `--apply` with every entry reporting
`CLOSE-CANDIDATE [sha … resolves]`, control `BL-006` still live. The six:

| candidate | what landed |
|---|---|
| `PC-S306-CHECK-2-HAS-NO-SPRINT-SCOPE` | Check 2's blocking clause scoped by the entry header's sprint; a past-sprint `HARD_BLOCK` is SURFACED at implementation/story/retro gates and still BLOCKS at planning and sprint-review; an entry naming no sprint blocks everywhere |
| `PC-S306-SUPPRESSED-STATUS-FIRST-TOKEN-SILENT-NO-OP` | suppression FIELDS under a non-`SUPPRESSED` status are reported, and the verdict line carries `malformed_attempt=` |
| `PC-S306-SERIES-VALIDATOR-NO-LEAD-RESOLUTION-PATH` | `gate-<type>-resolution-p<M>.md` accepted alongside the repair name, `gate-` anchor kept, structure requirement unchanged |
| `PC-S306-FANOUT-UNTRACKED-FILES-INVISIBLE` | corpus is tracked plus `--others --exclude-standard`, de-duplicated, untracked share printed in band |
| `PC-S306-GATE-REMEDIATION-BLOCKS-INDEPENDENT-DEV-DISPATCH` | Section 6 numbered action list conditions routing on the next step's read-set; Section 7's completion condition names the ENTERING gate |
| `PC-S306-STUB-AUDIT-PHASE-N-MATCHES-WORD-BOUNDED-PROSE` | `Phase [0-9]` is a marker only inside a statement of absence; the alternative is narrowed, not deleted |

**BOTH FIXES THE SUPPRESSION CANDIDATE PROPOSED WERE MEASURED AND BOTH ARE UNSHIPPABLE, AND
THAT IS THE BATCH'S BEST FINDING.** Requiring the `**Status:**` line to be exactly one token
rejects most of the corpus. Flagging a second vocabulary token elsewhere on the line scores
**5 of 108** status lines on the reference consumer and **all five are FALSE** — four say *"not
a HARD_BLOCK"* and one says *"already RESOLVED BY FACT below"*. The negation and the intent are
the same shape, so that rule cannot separate the true positive from its own false positives.
**A filed remedy is a hypothesis; build it and measure its false-positive set before writing
it.** The shipped arm keys on the FIELDS instead: 0 of 123 entries, control 16.

**THE GATE REFUSED THE FIRST PUSH ON `FORK_BUDGET` AND THAT IS THE ARM WORKING.** 7067 measured
against 7061. Isolated by differential inside this repo with the two new fixture directories
moved aside and restored: **13 forks for two directories**, which is the per-directory cost the
two previous raises already measured. Raised to **7073**, six over the top of a 7066–7067 spread,
recorded as a one-line reviewable diff beside its own measurement. **Budget the re-push**: a
batch that adds fixture directories will breach, and the breach costs a full second gate run.

**FOUR HANDS, AND FOR THE FIRST TIME IN THIS PROGRAM ALL FOUR DELIVERED.** Every one was given a
deliverable IN THE TREE — a validator edit plus a fixture — rather than a report file, and every
one produced working code with its own measurement recorded beside it. The best work in the
batch again came from the hands whose output was a committed battery. Two of the four never sent
a closing message at all and it did not matter, because the tree was the deliverable. **Give a
hand a tree deliverable or do not spawn it.**

**THE LEAD AUTHORED ALL SIX RECEIPTS AND SCORED EVERY ONE AGAINST FIVE BUILDS** — the shipped
fix, a second spelling by a competent author, and two or three plausible regressions. Three of
the six needed a repair after the first scoring: a span-level receipt was satisfied by one HTML
comment, another by the bold sentence above the numbered item it was meant to read, and a third
could not tell `--exclude-standard` dropped from the fix. **Scoring is not a formality; it moved
half the receipts.**

**TWO OF THE LEAD'S OWN PROBES MEASURED THE WRONG TREE AND A CONTROL CAUGHT BOTH.**
`report-propagation-fanout.sh` and `validate-gate-adjudication.sh` both `cd` to a root resolved
by walking up from the SCRIPT's own directory, so a probe repo built under `mktemp` and entered
with `cd` is silently ignored and the run reports on the distribution. The first cut of the
fanout receipt produced a worklist citing `docs/backlog.archive.md`. **Set
`AI_DLC_PROJECT_ROOT` explicitly, and read the output for paths that could only have come from
the wrong tree.**

**`v0.427.0` FOLLOWED BATCH 15 AND IS ALSO MERGED AND PUSHED (`144fd252`).** It is the
adversarial pass's own findings, landed as a follow-up rather than carried into batch 16. Two
fixes: `--finish` now REFUSES an unresolvable `<theirs>`/`<dist>` instead of writing the literal
argument into `commit:` and declaring the tree consistent; and `core/git-hooks/pre-push`'s
`applying_guard()` no longer tells a wedged operator to re-run the pull, which cannot clear a
range-derived hand-back row. Two entries FILED and not fixed — `BL-102` (`--finish` verifies
nothing it stamps; `mech_fail` is the only variable assigned above the phase guard and mutated
only inside it) and `BL-103` (a hook the template cannot register withholds `--finish` forever;
population measured EMPTY at 19/19). Gate exit 0, 17 of 17 phases, 169 ok / 0 FAIL.

**THE ADVERSARIAL PASS RAN AFTER THE MERGE FOR THE FOURTH TIME, AND ITS BEST ACT WAS A
RETRACTION.** It filed two BLOCKERs, then withdrew them: its `rsync` had excluded
`_bmad-output/`, deleting the consumer's `layer-adjudication-register.jsonl` and its 269 records,
so every adjudicated row re-fired as an outstanding hand-back. With the register present, four
realistic ranges stamp cleanly. **A defective setup and a correct one produced identically
plausible manifests, and only the register's presence separated them.**

**A CONTROL OF MINE PASSED FOR THE WRONG REASON AND I REPORTED IT AS EVIDENCE.** I probed
`--finish` with a bogus `<theirs>` of `refs/heads/nope` and got a correct refusal, so I called
the path sound. The slashes break the `sed`; the `|| true` swallows it; the read-back disagrees.
A slash-FREE bogus ref writes straight through. **Run the control on the input that
DISCRIMINATES** — the rule was already in `verification-discipline.md`.

**BATCH 15 IS COMPLETE, MERGED AND PUSHED AS `v0.426.0`.** `BL-030` CLOSED and rotated,
discharging `PC-S304`, with the id in the RELEASE COMMIT MESSAGE where `named_absorbed()` can read
it (verified: 1 hit, against an impossible-id control of 0). Release `5cc6c4f5`, close-and-rotate
`601f20f4`, fast-forward merge. Live **69 → 68**, archive **32 → 33**; recorded to show the
rotation HAPPENED, **not as progress**. `--check PASS` before `--apply` with the receipt reporting
`CLOSE-CANDIDATE [sha 5cc6c4f5 resolves]`, `BL-030` in the archive and not in the live file,
control `BL-006` still live. Gate exit **0** read from a sentinel CLEARED before the run, **17 of
17** phases PASS, **0 FAIL** lines ANSI-stripped, **169 ok / 0 FAIL** with
`AI_DLC_FIXTURE_NO_SKIP=1` confirmed live in the log, the new fixture read BY NAME against a
present-name control of 1 and an impossible-name control of 0 in the same invocation.

**THE FIX WEDGED ITS OWN ESCAPE HATCH ON THE FIRST END-TO-END RUN, AND ONLY RUNNING IT FOUND
THAT.** `--finish` counted every row it re-derived, including `DECISION hook-registration-unchecked`
— whose stated remedy is to re-run the apply that delivers the missing validator, on the phase
`--finish` skips. Unclearable by construction, and a withheld stamp nobody can advance is a
consumer whose own `pre-push` refuses to run. **Ask what a new gate makes permanently true
downstream; it is not visible in the diff.** The repair is two counters, and only ONE `WORKLIST`
row is reachable under `--finish` at all — derived over the code that mode actually executes, with
a control proving the grammar can see rows, then proved terminating end to end.

**A ZERO GAP LASTED EXACTLY ONE RELEASE, AND THE GAP IS NOW 3 AND HELD OPEN ON PURPOSE.**
`docs/plans/graph-pull-0425-to-0428.md` is written, LIVE and NOT STARTED. **It is not yours to
run.**

**Phases 0–2, 4 and 5 are COMPLETE.** Phase 3 is the batch loop and it is the only remaining
work. Batches 1–16 have all MERGED AND PUSHED; the releases are `v0.374.0`, `v0.375.0`,
`v0.376.0`, `v0.377.0`, `v0.378.0`, `v0.379.0`, `v0.380.0`, `v0.415.0`, `v0.416.0`,
`v0.418.0`, `v0.419.0`, `v0.421.0`, `v0.422.0`, `v0.423.0`, `v0.426.0` and `v0.428.0`, each recorded in `CHANGELOG.md`; `v0.427.0` followed batch 15 as its adversarial-pass follow-up. `v0.381.0` and `v0.382.0` followed batch 7 as machinery releases;
many further machinery releases have shipped between `v0.383.0` and `v0.414.0` that are NOT part
of this program, which is why the batch numbering and the version numbering stopped agreeing.

**THE `0.415.0 → 0.425.0` PULL IS COMPLETE AND THE CONSUMER IS AT `0.425.0` ON ALL FOUR STAMP
FIELDS.** Five PRs in a graph session the operator drove; the runbook is DISCHARGED at
`docs/plans/graph-pull-0415-to-0425.md` and its Discharge section is the record. **`PC-S333` and
`PC-S314` are CLOSED in the consumer's own ledger** — live=0, archive=1 each — which is the
terminal state this program aims at, reached for the first time.

**THAT PULL'S ZERO GAP IS SPENT.** `v0.426.0` discharged `PC-S304` and `v0.428.0` discharged the
sprint-306 six, so the pending set is **7** across **3** releases and
`docs/plans/graph-pull-0425-to-0428.md` is the runbook for it — LIVE, NOT STARTED, and for a graph
session the operator drives. Action 7's detection still applies; derive it rather than reading this.

**BATCH 14 IS COMPLETE, MERGED AND PUSHED AS `v0.423.0`.** Its own report said "CANDIDATES
DISCHARGED 6 → 7 OF 49", and **both halves of that figure were wrong** — the denominator through a
grammar missing two record forms, the numerator through a metric that sheds its own successes. The
partition AS OF THAT BATCH was **5 DISCHARGED, 14 TERMINAL, 60 live**; the current one is in the
derive block above and nowhere else. `BL-033` CLOSED and rotated, discharging
`PC-S314`, with the id in the RELEASE COMMIT MESSAGE where `named_absorbed()` can read it.
Release `5c3711e2`, close-and-rotate `c174b60a`. The entry counters moved **70 → 69** live and
**30 → 31** archived; those are recorded to show the rotation HAPPENED, **not as progress** —
`--check PASS` before `--apply` with the receipt reported
`CLOSE-CANDIDATE [sha 5c3711e2 resolves]`, `BL-033` in the archive and not in the live file,
control `BL-006` still live and the two entries filed this batch still live. Gate exit **0** read
from a sentinel CLEARED before the run and its mtime checked, **17 of 17** phases PASS, **0 FAIL**
lines ANSI-stripped, **168 ok / 0 FAIL** with `AI_DLC_FIXTURE_NO_SKIP=1` confirmed live in the
log, the new fixture read BY NAME against a present-name control of 1 and an impossible-name
control of 0 in the same invocation.

**THE OBVIOUS ONE-LINE FIX WAS A REGRESSION, AND THE ENTRY'S OWN RECEIPT ACCEPTED IT.** `BL-033`
proposed reordering two arms; measured, that answers `ALREADY-AT-THEIRS` for BOTH a consumer that
already carries the exec bit and one that still needs it, because on a mode-only change every
content hash is equal. Its receipt scored `head 1 / reorder 0 / conjunct 0` — it could not tell
the correct fix from the regression, and the entry SAID so in as many words ("takes either fix")
without anyone reading that as a defect. **When an entry tells you its receipt accepts two
different fixes, that is the finding, not a convenience.** Replacement scores
`head 1 / reorder 1 / conjunct 0`.

**THE ENTRY WAS WIDER THAN FILED IN THREE WAYS, AND ASKING THE QUESTION IS WHAT FOUND THEM** —
the `100755 -> 100644` direction, a path whose content is at theirs but whose bit is not (a
DIFFERENT arm, and silent), and the `A` branch's `ALREADY-PRESENT`. That is now four batches
running where "is this entry wider than filed?" paid.

**A CHANGELOG CLAIM OF MINE WAS TRUE AND UNMEASURED, AND THE CASE THAT PROVED IT WAS NOT IN MY
MATRIX.** I asserted a mode-aware hash would refuse a safe `UPSTREAM-DELETED`. My first matrix
showed no such effect — because every `D`-branch case in it had the consumer's mode matching
base's, so the mode-aware hashes still agreed. The claim needed a consumer whose CONTENT matches
base and whose MODE does not, and only then did it reproduce. **A differential over a matrix you
built yourself tests the cases you thought of.**

**A FOLLOW-UP SHIPPED AS `v0.424.0` (`98ad402e`), AND IT IS A HOLE IN BATCH 14'S OWN GUARD.** The
release changed TWO branches of `preclassify.sh`; the fixture built for it guarded one, so the
`A`-branch half could be reverted with the suite green. Filed and closed as `BL-101` in one
cycle. **The finding came from an adversarial pass that ran AFTER the merge — again** — which is
the third time this plan has recorded that, and the standing instruction to run it BEFORE the
merge is still the one being skipped.

**THE ATTACK PRODUCED FOUR CANDIDATE WEAKNESSES AND ONLY ONE WAS A REAL COVERAGE GAP, WHICH IS
ITSELF THE LESSON.** All four satisfy `BL-033`'s replacement receipt; the FIXTURE independently
kills three, because it carries an ordinary-content-change case and both mode directions. **Run a
proposed receipt-weakness against the FIXTURE before reading it as a coverage gap.** They are
different guards, and once an entry is rotated its receipt is archived and inert while the fixture
is what still runs. Measured: `dropbase` killed by `C5`, `halfmode` by `C4`, `modehash` by `C7`,
`arevert` survived.

**A RECEIPT KEYED ON `git archive HEAD` CANNOT SEE THE FIX THAT IS SITTING IN THE WORKING TREE.**
`BL-101`'s read 1 with the repair complete on disk and flipped to 0 on the commit. That is correct
behaviour and it reads exactly like a repair that did not work — check what the receipt EXTRACTS
before believing its verdict about uncommitted work.

**FILED `BL-099` AND `BL-100`.** The exec-bit audit is one-directional — it tests `$1=="100755"`
at both arms, so a file upstream STOPPED shipping executable is never reported, and that
direction has no level-triggered backstop at all. And `--untangle`'s noop arm is mode-blind: a
`.githooks/pre-push` copy at 644 with correct content buckets identically to one at 755.

**BATCH 13 IS COMPLETE, MERGED AND PUSHED AS `v0.422.0` (`bccc8d9c`).** `BL-052` CLOSED and
rotated, discharging `PC-S333`. Live **69 → 68**, archive **29 → 30**, `--check PASS` before
`--apply` with the receipt reported `CLOSE-CANDIDATE [sha bccc8d9c resolves]`, `BL-052` in the
archive and not in the live file, control `BL-006` still live. Gate exit **0** read from a
sentinel CLEARED before the run and its mtime checked, **17 of 17** phases PASS, **0 FAIL**
lines ANSI-stripped, **167 ok / 0 FAIL** with `AI_DLC_FIXTURE_NO_SKIP=1` confirmed live in the
log, the changed fixture read BY NAME (2 hits) against a positive control of 1 and an
impossible-name control of 0 in the same invocation.

**THE ENTRY FILED 5 SITES AND THE POPULATION WAS 13, BECAUSE ITS RECEIPT COULD NOT SPELL ITS
OWN SUBJECT.** `show +<(theirs|base|ours)>:` cannot see `<ancestor>:`, and the one site spelled
that way sat INSIDE the receipt's own scoped directory. Its scope had been narrowed to dodge a
comment quoting the hazardous form; quoting the comment instead makes a wider grammar reach zero
with no exemption list. **Ask what a receipt's grammar structurally cannot match, not only what
its corpus excludes.**

**A MEASUREMENT I PUT IN THE CHANGELOG WAS TAKEN OVER THE WRONG SET AND I WITHDREW IT.** I
claimed a `git`-requiring variant of the new pattern misses 8 wrapped renderings. Over `core/`
both find the same 13 and the difference set is EMPTY; the 37-vs-29 gap is `docs/` prose about
the defect. Reporting two TOTALS hid it — deriving the DIFFERENCE SET is what exposed it. The
pattern choice now rests on the fixture's `x3` mutant instead.

**THREE OF FOUR HANDS DELIVERED NOTHING, AND THE PLAN'S OWN REMEDY IS WHY.** Scope, receipt and
adversary each went idle repeatedly — eight content-free idle notifications between them — after
two direct requests each. Only the FIXTURE hand delivered, as in batch 9, and its work was again
the best in the batch: it found that `grep` handed an EMPTY file list reads STDIN and HANGS,
measured at two wedged processes for two minutes under the pool. **A hand whose deliverable is
the TREE delivers; a hand whose deliverable is a report does not**, because the report file is
the thing a hook denies. Numbered action 3 below has been corrected accordingly.

**BATCH 12 IS COMPLETE, MERGED AND PUSHED AS `v0.421.0`.** `BL-094` CLOSED and rotated;
`BL-095`, `BL-096`, `BL-097` and `BL-098` FILED. The release branch was four commits,
fast-forwarded to `main` as `b8714e0d..f121b1dc`; a follow-up branch then carried `BL-098`, the
sweep bound and the rule carriers, merged as `c37dcb08..5cddec48`. **`BL-098` was filed AFTER the
resume block had already been re-derived once, which made it stale again inside the same session
— re-derive after the LAST write, not after the merge you were thinking of.** Live **65 → 69** (one closed, four filed), archive **28 → 29**, `--check`
PASSing before `--apply`, `BL-094` in the archive and not in the live file, control `BL-006` still
live. Gate exit **0** read from a sentinel CLEARED before the run and its mtime checked, 17 of 17
phases, **0 FAIL lines**, 167 units with `AI_DLC_FIXTURE_NO_SKIP=1`, the changed fixture read BY
NAME (2 hits) against a positive control of 1 and an impossible-name control of 0 in the same
invocation.

**THE ADVERSARIAL PASS RAN BEFORE THE MERGE THIS TIME, AND IT PAID FOR ITSELF ON THE FIRST
FINDING.** A guard firing only on an ADJACENT repeat passed the clean tree, the entry's own
replacement receipt, and all 21 fixture mutants — then rendered a genuine duplicate at exit 0.
**Three independent-looking verification channels shared ONE input shape**: every duplicate seed
in all of them placed the repeat beside the first declaration, and the receipt could only ever do
so, because `awk NR==n{print} {print}` duplicates a line in place. The gap was in the SEED, not
the mechanism, so the repair was one seed per channel and no new guard. **Ask of a verification
suite not whether it has enough arms, but whether its inputs are all the same shape.**

**THE RECEIPT CLOSED ON ONE MEMBER OF A FIVE-MEMBER SET THE ENTRY ITSELF ENUMERATES.** A partition
covering `vocabulary-readers:` alone returned exit 0 while the other four fields stayed silent.
The standing rule is "ask what ELSE satisfies the receipt"; the new form is that **the SET was
under-sampled rather than the mechanism** — the receipt exercised a real behaviour, correctly, on
one member.

**ASKING WHETHER THE ENTRY WAS WIDER THAN FILED PRODUCED THREE OF THE FOUR FILINGS.** It is worth
making that the default question: `BL-095` (a rule file may declare `paths:` twice and the arm
named "declares its scope exactly once" is about something else), `BL-096` (the sibling renderer
refuses a duplicate SOLO declaration and accepts a duplicate GROUP one), `BL-097` (**the renderer
declares TWO populations and this release hardened one** — its schema walker still last-wins a
duplicate JSON key, under a header calling that half "total by construction").

**A WIDENING BEYOND THE ENTRY'S FILED TEXT WAS TAKEN DELIBERATELY AND RECORDED AS ONE.** A field
declared ABOVE its block's `# vocabulary:` line survived the shipped partition — `flush()` clears
the seen-flags at the name line, so the stray and the real declaration are not a repeat. Eight of
eight name lines, silent. Fixed here because it is the same function and the last silent-discard
path in that reader; an orphan is not a repeat, and the CHANGELOG says so.

**TWO MEASUREMENTS OF MINE WERE WRONG AND BOTH WERE CAUGHT BY A CONTROL.** A duplicate-`paths:`
test run under `git archive` had no `.git`, so an unrelated arm failed on BOTH sides and read as a
refusal — the real answer needed a `file://` clone. And a claim that 17 "loose-but-not-strict"
arm-header lines could merge two marker blocks was simply wrong: a line not matching `I[0-9]` was
never a flush point. **There is no "ought to flush" independent of the reader's own regex.**

**A HOOK FORBIDS SUBAGENTS FROM WRITING REPORT FILES, AND A BRIEF THAT DEMANDS ONE WASTES THE
HAND.** Every hand was told its report file was the deliverable; the hook refuses the write with
`Subagents should return findings as text, not write report files`. Two hands worked around it by
returning text, one delivered a file, one delivered only a diff. **Ask for findings AS TEXT in
the final message, and treat the tree as the deliverable for anything that is code.**

**A FOLLOW-UP SHIPPED AS `v0.420.0` (`32ad4896`), AND THE ADVERSARIAL PASS THAT FOUND IT RAN
AFTER THE MERGE.** Arm D's population is a bare `dir/*` glob, and BSD awk ABORTS on a path it
cannot open rather than skipping it — so one broken symlink in either directory ended the walk,
and the only message was arm D's exemption control, which can only say "the exempt file does
not emit". Differential: `5efb3d17^` exits 0 on that tree, `5efb3d17` exits 1, with a bare
`awk: can't open file` on stderr as the whole diagnosis. **The guard was RIGHT and its message
was WRONG** — it refused to certify a zero over a corpus it had not finished reading, then
named the wrong file. The exit code is not reverted; the attribution is fixed, and the
exemption control now stands down for that case so one cause yields one finding.

**RUN THE ADVERSARIAL PASS BEFORE THE MERGE, NOT AFTER.** Batch 11 gated green, merged, and
still shipped a defect that one hour of seeding found. The gate cannot catch this class: the
tree it runs on has no broken symlink, so every arm was correct and silent about a state
nobody constructed. **Seed the states your own population EXCLUDES** — a directory where a file
is expected, a dangling link, an unreadable file — and read what the arm says, not just whether
it exits 0.

**A PARTITION WAS BUILT, MEASURED AND REJECTED, WHICH IS THE PART WORTH REMEMBERING.**
`find -maxdepth 1 -type f` excludes the dangling link BY CONSTRUCTION and is one process for
both populations, which is the shape `mechanism-design.md` prefers over a detector. It measured
**+116**. This file's cost metric charges per DIRECTORY ENTRY EXAMINED, not per `execve`, so a
single `find` over 71 files costs more than the 48-iteration `[ -f ]` loop batch 11 deleted.
**Do not rebuild it** — the rejection is recorded beside the arm. Shipped cost of the fix: −2.

**BATCH 11 IS COMPLETE, MERGED AND PUSHED AS `v0.419.0`.** `BL-090` CLOSED and rotated.
Release `5efb3d17`, close-and-rotate `874d4f41`, fast-forward merge. Live **66 → 65**, archive
**27 → 28**, `--check` PASSing before `--apply`, `BL-090` in the archive and not in the live
file, control `BL-006` still live. Gate exit **0** read from a sentinel file CLEARED before the
run, 17 of 17 phases PASS, 0 FAIL lines, **167 units** with `AI_DLC_FIXTURE_NO_SKIP=1`, all five
changed fixtures read BY NAME against a positive control of 1 and an impossible-name control of
0 in the same invocation.

**A CONTROL THAT AGREES WITH THE VERDICT TOLD ME NOTHING, AND I NEARLY BANKED IT.** The first
by-name read of the gate log returned 0 for all five changed fixtures — and 0 for the
impossible-name control too, because both patterns anchored on a single space where the log
writes a column of them. Two zeros that agree are one broken pattern, not a finding. The
re-read carried a control that MUST come back non-zero, and it did.

**THE POPULATION WAS WRONG IN EXACTLY THE WAY THE ENTRY DESCRIBED, ONE GRAIN OVER.** The first
cut of the reverse join swept `*.sh`. `core/scripts/gen-architecture-index.js` and
`scripts/verify-backlog-bl056.py` exist today, so an extension filter would have shipped a
one-way blind spot inside the arm built to close a one-way blind spot. **Ask of every new
detector what its population EXCLUDES, and check the exclusion is not the defect itself.**

**A GUARD THAT CANNOT FIRE ON THE STATE IT EXISTS FOR.** `esv_glob_matched` answers for ONE
glob. The first arm D concatenated both populations into one array and tested the count — but a
tree where NEITHER glob matched still holds two literal patterns, so the count test reads as a
match. Each population is now tested on its own.

**BUILDING THE ARM IS WHAT EXPOSED WHAT THE OLD ONE WAS PAYING**, and the change came out
fork-NEGATIVE by 47. `for f in dir/*.sh; do [ -f "$f" ] && ...; done` costs one fork PER
CANDIDATE; arm C had been running it over 48 files. Differential on two extracted trees with
the sides asserted to differ before the comparison was read: HEAD **7049**, branch **7002**.
`FORK_BUDGET` was ratcheted DOWN 7076 → 7029 rather than left where it was. No wall-clock
claim: 20.4s before, 20.0s after, three reps each, which cannot resolve 47 forks of 7050.

**FIVE HANDS, ONE DELIVERABLE, AND THE PRESCRIBED REMEDY DID NOT WORK.** Scope, receipt,
fixture-recon and adversary each had a named report file and a brief telling them the file was
the deliverable; none wrote one in over two hours. The FIXTURE hand delivered, and its work was
the best part of the batch — ~230 lines deriving the token and the exempt path from the seed
rather than typing them, anchoring the two `esv_undeclared` mutations on the argument that
SEPARATES them, and asserting the probe's EXACT score so neither mutation can score the
other's kill. **Check the deliverable, not the report: this one existed only as a diff.**
The cost is real and is recorded here rather than smoothed over — the two arms the lead added
share an author with the code they test, which is the one thing `fixture-mutants.md` says not
to do, and the adversarial pass on the close was the lead's own.

**BATCH 10 IS COMPLETE, MERGED AND PUSHED AS `v0.418.0`.** `BL-006` NARROWED and held open,
`BL-093` filed. It was action 1 and it is DONE. Do not re-run it. Live **65 → 66**, archive
**27** (nothing rotated — the entry was narrowed, not closed), and the ledger now reports
**0 CLOSE-CANDIDATE** where it carried one false one. Gate exit **0** read from the hook's own
status file with its mtime checked, 17 of 17 phases PASS, 0 FAIL lines, 167 units with the skip
disabled, all five changed fixtures read BY NAME against an impossible-name control of 0.

**THE ENTRY COULD NOT BE CLOSED, AND FINDING THAT OUT COST ONE ADVERSARIAL HAND.** `BL-006` had
TEN separable claims and the ruled remedy discharged eight. The two survivors are a different
corpus each — `docs/plans/` has no size arm, and the CONSUMER's own ledger is unbounded and
unreachable from here — so the narrowed entry carries a CONJUNCTION receipt that cannot go green
on one of them. **Enumerate an entry's distinct claims BEFORE reading a good measurement as a
close**; that is `v0.417.0`'s lesson and it fired again immediately.

**A CEILING MAKES A RED PUSH, AND THE CHEAPEST WAY TO CLEAR A RED PUSH WAS ONE LINE OF MARKDOWN.**
Before the fix, annotating any entry `**LANDED (v...)**` archived it with `--check PASS`, rc=0 —
reproduced against `BL-006` itself, whose own first line says DO NOT CLOSE. `backlog-rotate.sh`
now refuses to move an entry whose evidence does not hold, and the guard sits before BOTH
branches because `--check` filters `^ALREADY-CLOSED` from both sides of its own comparison.
**The guard as originally specified would have missed its own motivating case**: `BL-006` was the
only live entry whose receipt exits 0, so a receipt-only arm permits it and the SHA arm is what
refuses. Ask of every new detector whether it fires on the case that motivated it.

**A MEASUREMENT I GAVE THE OPERATOR WAS DEFECTIVE AND THEY RULED ON IT.** A byte clause was
ruled, built, and withdrawn: the series behind it started at `158d7528`, which is not on the
first-parent trunk, and its trend was n=1. Archived entries average 7193 bytes against a live
mean of 3758, so rotation is the byte lever and it is denominated in ENTRIES. **Check that a
series' endpoints are on the trunk before drawing a trend from it**, and say so when a figure
you supplied turns out to be wrong.

**THE TRIAGE SWEEP IS ALSO COMPLETE, MERGED AND PUSHED AS `v0.417.0` (`8eb98209`).** All 64 live entries re-derived by 14 independent hands, one
question each, then 4 verifiers briefed to BREAK the proposed closes. **62 REPRODUCES, 2
proposed closes, 1 survived attack.** Coverage joined both ways against the live ledger: nothing
unexamined, nothing examined twice, no duplicates. Live **64 → 65**, archive **26 → 27**. Gate
exit **0** read from `git push`'s own `$?`, 16/16 phases PASS, 166 dispatched / 166 ok / 0 FAIL
against an impossible-name control of 0.

`BL-081` CLOSED (fixed at `5d02dcf4`/`v0.386.0`, thirty releases before anyone joined the row to
it). `BL-066` REJECTED and held open, narrowed to its sibling claim. `BL-091` and `BL-092`
filed. `BL-006`, `BL-066` and `BL-089` amended with what the sweep measured.

**THE VERIFIER PASS CAUGHT A FALSE CLOSE ON SCOPE, NOT ON MEASUREMENT, AND THAT IS THE
TRANSFERABLE LESSON.** Both `BL-066` verifiers agreed on every number and split on what the
entry CLAIMED. Its sibling paragraph names a harm distinct from the one that was fixed — "its
output is the sha an operator is told to go and read" — and `named_ambiguous()` still elects one
commit from its match set. **`v0.387.0`'s CHANGELOG asserts both joins were fixed and that
sentence is false.** An entry with two subjects expires only when both do; ask that question
before reading a good measurement as a close.

**BATCH 9 IS COMPLETE, MERGED AND PUSHED AS `v0.416.0`.** `BL-076` and `BL-078` closed,
`BL-090` filed. Release and merge are one fast-forward commit, `727ddc6c`. Live **66 → 64**,
archive **24 → 26**, `--check` PASSing before `--apply`, no id in both files (control: `BL-076`
present in the archive), and `backlog-reverify` reporting **0 CLOSE-CANDIDATE** afterwards
against an impossible-id control of 0. Gate read directly, not through a pipe: push exit **0**,
**16 of 16** phases PASS, all six changed fixtures read BY NAME against an impossible-name
control of 0.

**THE FIRST PUSH WAS BLOCKED AND THE BLOCK WAS RIGHT.** Widening `I93`'s emitter list from 3 to
14 under its existing per-file loop cost 4 forks per emitter and put the tree **42 over
`FORK_BUDGET`** — `validator-fork-budget` failed the push. `esv_sites` already took a file
LIST for exactly this reason and the first cut ignored it; one `awk` per token over the whole
list took 7092 back to 7054, and the arm's cost is now flat in the declaration's length. **Reach
for the mechanism the file already has before adding a loop** — the same lesson `I97` was built
on in batch 8, one release later, in the same file.

**BATCH 8 IS ALSO COMPLETE** (`v0.415.0`, `BL-079`; merge `8d4d7424`, release `2b474ad2`,
close-and-rotate `20599835`).

**FOUR THINGS THE ENTRY ASSERTED DID NOT HOLD, AND THE RE-DERIVATION IS WHY THEY WERE FOUND.**
Its own `verify:` receipt was EXPIRED — the seed used a capability grammar the validator now
DISARMs, so both arms returned 2 and it exited 9 against every implementation, a correct one
included. Its population was six memlogs, not four. The shared baseline it names as a blocker
does not exist in that consumer. And the false positive dying does NOT turn that gate green: a
join (2a) spine finding survives, byte-identical either way, and a figure taken on `--spec --prd`
alone is a figure about join (1) rather than about Check 30.

**THE INDEPENDENT HANDS PAID AGAIN, 5 OF 5 BATCHES.** Three defects in work already committed on
the branch, each returning a WRONG answer rather than an error: the borrowed grammar joins its
blocks with a FORM FEED and this reader was grepping the join, silently dropping the head
declaration of every block after the first with no DISARM available; a declared population none
of whose ids the memlog mentions took the note branch on every iteration and printed PASS having
joined nothing; and `--locked-requirements ""` reverted to the memlog scan and reproduced the
original false positive. A fourth hand found the CHANGELOG's own s302 claim overstated.

**AND THE FIRST CUT COMMITTED THE DEFECT `I97` NOW BLOCKS.** `validate-locked-anchor.sh` owns
the `LOCKED_REQUIREMENTS` block grammar and exposes `--emit-blocks` so a second reader need not
re-derive it. A hand-rolled marker pair went in anyway and read 2 of the grammar's 6 measured
spellings. **Grep for the mechanism before writing one.**

**The consumer wall-clock investigation is CLOSED and its record is
`docs/v0.380.0-pipeline-cost-investigation.md`.** It refutes ELEVEN hypotheses, each with its
killing measurement, and a twelfth (a plateau exit) is refuted in the history below. **Re-running
any of them is the most expensive mistake available to you.** The operator's standing direction
at the close of that work was: **stop measuring the pipeline, build the fix.**

**The one live proposal out of it has SHIPPED as `v0.382.0`** — `MAJOR` was overloaded, so
`findings_major_underived` now partitions `findings_major` and the convergence exit reads
`findings_critical == 0 && (findings_major - findings_major_underived) == 0`. Absent means ZERO,
so no block written before it changes verdict.

### NEXT ACTIONS — numbered, in order

1. **SWEEP THE CONSUMER FOR NEW PUSH CANDIDATES FIRST. THAT IS THIS BATCH'S OPENING ACTION AND
   IT IS NOT OPTIONAL.** Operator instruction, given at the close of batch 17. Do this BEFORE
   picking any subject, and report what it finds.

   Run the derive block above first — it builds `/tmp/live.txt` and `/tmp/filed.txt`, and the set
   you want is the live candidates NO backlog entry cites. Then DATE each one's filing from the
   consumer's own history, because "unfiled" mixes genuinely new candidates with old ones no
   batch has examined, and only the date separates them:

   ```
   D=_bmad-output/ai-dlc-update
   comm -23 /tmp/live.txt /tmp/filed.txt > /tmp/unfiled.txt
   wc -l < /tmp/unfiled.txt
   while IFS= read -r id; do
     printf '%s  %s\n' \
       "$(git -C /Users/n8/git/graph log --format='%ad' --date=short -S"$id" -- "$D/push-candidate-ledger.md" | tail -1)" \
       "$id"
   done < /tmp/unfiled.txt | sort
   ```

   `-S` reports the commit that INTRODUCED the string, so `tail -1` is the filing. Measured, with
   both controls in the same run: a candidate filed during batch 17 dates `2026-08-27`, a
   long-standing one dates `2026-07-21`, and an impossible id returns ZERO lines. **A zero for a
   real id means the grammar or the path is wrong, not that the candidate is old** — the ledger
   path is the only argument, and the archive is a SEPARATE file.

   **THE BASELINE IS 66 LIVE CANDIDATES AT `v0.433.0`, 33 OF THEM UNFILED, AND SPRINT 306 IS
   FULLY DISCHARGED.** A higher count means the consumer filed while nobody was looking.
   **Re-derive rather than trusting those numbers** — they have moved between two consecutive
   commands in this program, and the live count moved by one DURING batch 19.

   **THE SPRINT-306 RULING IS SPENT. DO NOT LOOK FOR SPRINT-306 WORK.**

   **IF THE SWEEP FINDS A NEW SPRINT'S SET, REPORT AND ASK — DO NOT ASSUME THE RULING EXTENDS.**
   Batch 18 asked and the operator said take both; that answer was about sprint 306's remainder.
   Extending it to a different sprint is theirs to do, not yours.

   **THE TWO FRESHEST FILINGS ARE BOTH DATED 2026-08-28 AND ONE IS ALREADY TAKEN.**
   `PC-S339-WITHDRAWAL-COMMIT-BECOMES-THE-NEW-ATTRIBUTION` is filed here as `BL-117` and is IN
   FLIGHT — do not re-scope it. `PC-S307-AWK-CANT-OPEN-FILE-MISREAD-AS-MISSING-FRONTMATTER`
   arrived WHILE batch 19 was running, is UNFILED, and is the freshest thing in the corpus.
   Read its own status line in the consumer's ledger before treating it as work.

   **IF THE SWEEP FINDS NOTHING NEWER, THE STANDING RECOMMENDATION IS `BL-119`**, for the reason
   measured on the consumer's own register and set out under "BATCH 20's SUBJECT" in the resume
   block above: 19 of the 20 non-keep verdicts that consumer has recorded are against extensions,
   and every one of them authorizes an action no code in `core/` emits. It is not PC-backed — it
   was found here — so it ranks below anything the sweep turns up. `BL-051` remains the coherent
   PC-backed alternative: step 2 computes which machinery paths the consumer edited and then
   discards the answer, discharging
   `PC-S330-STEP-2-HAS-NO-DISPOSITION-FOR-A-CONSUMER-MODIFIED-MACHINERY-PATH`. Verify that id is
   still live upstream, against an impossible-id control, before scoping it.

   **THE UNFILED SET IS THE CORPUS, AND IT IS DOMINATED BY TWO OLD CLUSTERS.** Of the 32, ten are
   `PC-S312-*` — several of which describe themselves as falsifiability probes for a retirement
   rather than as defects — and two are already WITHDRAWN upstream
   (`PC-S300-ORIGIN-TAG-GATE-HAS-NO-WAIVER-FOR-TRACEABILITY-CITATIONS`,
   `PC-S305-CHECK-17-BYPASS-CONSUMER-CASES-V8-V9-AND-A-PASSING-CONTROL`). **Read each
   candidate's own status line in the consumer's ledger before treating it as work** — this
   block has asked for that since batch 1 and it still has not been done for the S312 cluster.
   The most recent filings (`2026-08-26`/`2026-08-27`, the `PC-S337-*` and `PC-S305-*` rows) are
   the freshest and the likeliest to still be real.

   **`BL-051`'s receipt must be replaced FIRST, and that is not optional.** It is one of the four
   the `v0.417.0` sweep found closable by prose — by a comment naming a bucket. Batches 14, 15
   and 17 all had to repair their subject's receipt before landing the fix. Build the correct fix
   AND at least two plausible regressions, score every one, and only then write the `verify:`
   line. **Score a SECOND SPELLING of the correct fix too**: a receipt that rejects a competent
   author's other phrasing is as broken as one that accepts a regression.

   **THE PULL RAN. THE GAP IS ONE RELEASE AND ONE CANDIDATE.** The consumer reconciled
   `0.430.1 -> 0.432.0` on 2026-08-28, which is what moved eight candidates to TERMINAL, and
   `docs/plans/graph-pull-0425-to-0430.md` is DISCHARGED — a worked example, never a live plan.
   `docs/plans/graph-pull-0432-to-0433.md` is its successor: written, REHEARSED at `v0.433.0` on
   `file://` clones of both trees, and NOT STARTED. Its rehearsal measured the bootstrapping
   hazard rather than warning about it — `apply.sh` and `layer-drift.sh` both moved and both
   bucket the same way, so the fail-closed split cannot occur in that range. Do not run the pull,
   do not re-litigate it, and do not treat the gap as a reason to reorder this batch.

   **REHEARSE BEFORE WRITING ANY RUNBOOK FIGURE, AND TREAT THE REHEARSAL AS A DETECTOR.**
   `v0.429.0`'s rehearsal caught a `WORKLIST` row that would have told every consumer to register
   a sourced library as a hook. That is the only consumer-facing defect this program has caught
   before delivery, and nothing inside this repo could have found it.

   **THE RECURRENCE NOTE IS STILL OPEN AND STILL NOT YOURS UNLESS THE OPERATOR SAYS SO.** Sprint
   306 appended a `RECURRED` block to `PC-S305-DISPATCH-GUARD-SED-PATTERN-BOLD-MISMATCH`,
   recording that the defect blocked a live incident fix, that the consumer applied a SCHEMA-side
   workaround the entry's own text says does not close it, and that the entry's `verify:` clause
   is HOOK-side only and therefore **structurally cannot detect a schema-side close**. Read it;
   take it only on a ruling.

   **THE PC-BACKED COUNT IS NOT THE CORPUS.** Live entries citing a `PC-` id outnumber the corpus,
   because some cite candidates already ARCHIVED upstream — closing those discharges something the
   consumer closed itself. Derive the corpus with the join below rather than trusting the list:

   ```
   # /tmp/live.txt comes from the derive block above -- BOTH record forms
   awk '/^## BL-[0-9]+/{if(id!="")out(); id=$2; pcs=""}
        match($0,/PC-[A-Z0-9][A-Z0-9-]+/){p=substr($0,RSTART,RLENGTH); if(index(pcs,p)==0) pcs=pcs (pcs?",":"") p}
        END{if(id!="")out()} function out(){ if(pcs!="") printf "%s\t%s\n", id, pcs }' docs/backlog.md |
   while IFS="$(printf '\t')" read -r id pcs; do
     for p in $(printf '%s' "$pcs" | tr ',' ' '); do
       grep -qx "$p" /tmp/live.txt && { printf '%s\t%s\n' "$id" "$p"; break; }
     done
   done
   ```

   **The list below is the corpus. RE-DERIVE IT — do not read it.**

   Re-derived at v0.426.0 it returns **22 entries**: `BL-029`, `BL-034`, `BL-037`, `BL-039`,
   `BL-040`, `BL-041`, `BL-042`, `BL-043`, `BL-044`, `BL-045`, `BL-047`, `BL-049`, `BL-051`,
   `BL-053`, `BL-054`, `BL-055`, `BL-057`, `BL-062`, `BL-064`, `BL-067`, `BL-069`, `BL-075`.
   `BL-030` left the set by being CLOSED, which is the only way an entry should leave it.

   **BATCH 14 REPORTED 16 AND THE TRUE FIGURE WAS NEVER 16.** Re-run at v0.425.0, the batch-14
   grammar itself returned 22 — `docs/backlog.md` moved under it — and the corrected grammar
   returned 23. Nothing was removed; seven entries were never visible. **Re-derive this list; do
   not read it.** It is a snapshot of two files that both move.

   **The standing recommendation is `BL-051`** — step 2 computes which machinery paths the
   consumer edited and then discards the answer, discharging
   `PC-S330-STEP-2-HAS-NO-DISPOSITION-FOR-A-CONSUMER-MODIFIED-MACHINERY-PATH`. Verify that id is
   still live upstream, against an impossible-id control, before scoping it.

   **Its receipt must be replaced FIRST, and that is not optional.** It is one of the four the
   `v0.417.0` sweep found closable by prose — by a comment naming a bucket. Batches 14 and 15 both
   had to replace their subject's receipt before landing the fix, and batch 15's old receipt
   scored **0 against two regressions that resolved nothing** — a trivial second disjunct on the
   guard line, and one unused assignment. Build the correct fix AND at least two plausible
   regressions, score every one, and only then write the entry's `verify:` line. Score a SECOND
   SPELLING of the correct fix too: a receipt that rejects a competent author's other phrasing is
   as broken as one that accepts a regression, and batch 15 nearly shipped exactly that.

   **The coherent alternative is `BL-049`**, whose candidate
   `PC-S318-SELF-UPDATE-SLICE-CANNOT-CARRY-THE-FIXTURE-FIX-THAT-UNBLOCKS-ITS-OWN-PUSH` is the
   bootstrapping class batch 15 had to reason about from the outside: the broken version is the
   one that runs the delivery. Batch 15 measured that hazard for its own release and it did not
   bite; this entry is about the case where it does.

   **THE SELECTION RULE IS PROVENANCE FIRST, THEN CONSEQUENCE — NOT READINESS.** Operator
   ruling. "Readiest to close" is what pointed batch 13 at three entries with no consumer
   provenance and no consumer surface, and it will do it again, because a session always finds
   its own discoveries easiest to fix. Derive the corpus rather than trusting this list:

   The join that derives it is the one at the top of this action — **run that one, not the
   bare `awk` half of it.** The `awk` alone answers "which entries cite a `PC-` id", which is a
   question about `docs/backlog.md` and not about the consumer; it returned **32** at batch 14's
   close against a true corpus of **16**. Piping it through `/tmp/live.txt` is what makes it a
   measurement of the goal.

   Of the 32, **31 have receipts exiting 1** and one — `BL-066` — exits **9** and has therefore
   measured nothing. Almost all name `core/` paths, so the consumer surface is there; `BL-086`
   is the one that names none.

   **`BL-095` through `BL-098` are DEFERRED, not rejected.** They are real, each carries a
   candidate fix already measured against an empty false-positive set, and they are the
   secondary goal the operator ranked BELOW this one. They are also all distribution-only —
   `scripts/render-invariant-index.sh` and `scripts/render-vocabulary-index.sh` reach no
   consumer. Take them when the PC-backed set is discharged, or when one of them blocks a
   PC-backed fix.

   **The recommendation does not excuse the re-derivation.** Run each candidate's receipt
   directly and read the RAW exit code, then re-derive the entry's population rather than
   believing it. Batch 12's own subject was filed with a receipt that closed on one field of
   the five its entry enumerates, and only running it found that.

   `BL-006` is NARROWED and still live, and it is the coherent alternative — but read its
   receipt first: it is a CONJUNCTION over two corpora in two trees, and the consumer half is
   not reachable from a distribution-side change. Taking it means taking the `docs/plans/`
   half and saying so. `BL-093` is a per-file judgment rather than one fix and is NOT a batch
   subject as it stands. `BL-082` and `BL-083` are still not one subsystem, so taking them
   means saying which single thing you are closing. `BL-066` was REJECTED at v0.417.0 and
   narrowed to its sibling claim, which `named_ambiguous()` still exhibits.

   **Run every candidate's receipt directly and read the RAW exit code before you scope it.**
   The sweep re-established that a `STILL-LIVE` row is not evidence the entry is live, and
   found the population is wider than `BL-089` filed: receipts exiting **1** having measured
   nothing outnumber the exit-9 ones and carry no hint at all. `BL-081`'s did that for 16
   releases while reading as a genuine reproduction.

   **Then re-derive the entry's population rather than believing it.** The sweep measured this
   directly across 64 entries: `BL-019`, `BL-052`, `BL-072` and `BL-086` are all WIDER than
   filed, `BL-081`'s claim 7 was wrong in the direction that strengthened its close, and
   citation drift is routine and mostly not load-bearing. That is the base case, not the
   exception.

   **Ask what ELSE satisfies the receipt.** Three of the four receipt defects the sweep found
   are the `BL-078` shape — `BL-006` closable by a comment, `BL-051` by a comment naming a
   bucket, `BL-074` by a deletion its own entry forbids. The standing rule is in
   `.claude/rules/verification-discipline.md`, "a receipt that reads a RENDERED artifact is
   closable by prose"; it is not restated here.

   **And ask what the fix's own population EXCLUDES.** Batch 11's first cut answered a
   one-way-blindness entry with an arm that was blind by file extension. The exclusion has to
   be stated in the arm and it has to not be the defect itself.
2. **Keep the batch to ONE subsystem.** Take one group or the other, not both.
   Batch 16 was a deliberate exception the operator scoped, and it is over. **When an exception is
   granted again, land it the way batch 16 did**: separate commits on ONE release branch, one per
   candidate, each naming its `PC-` id in its own commit message. Do not squash them.
3. **Put independent hands on SCOPE, FIXTURE and RECEIPT, every time.** In batch 8 they found
   THREE defects in work already committed on the branch; in batch 9 the fixture hand found
   FOUR more live instances of the entry's own defect, and two scope hands independently found
   that the entry's receipt could be closed by prose. Every one returned a WRONG ANSWER rather
   than an error. Across six batches
   this is the only mechanism that has ever told a session it was wrong about its own change.

   **PICK EACH HAND'S MODEL BY WHAT A WRONG ANSWER FROM IT WOULD COST, NEVER BY HOW LARGE THE
   TASK LOOKS.** The `Agent` tool takes `model: "opus" | "sonnet" | "haiku"`, and it is IGNORED
   for `subagent_type: "fork"`, which always inherits yours. Set it explicitly on every spawn —
   an omitted `model` is a default nobody chose. **Do NOT restate the pipeline's own
   role-to-model mapping here**: `core/skills/ai-dlc/SKILL.md` Rule 19 binds that through
   `aiDlcRoles` in `.claude/settings.json` and `core/hooks/ai-dlc-dispatch-guard.sh` enforces
   it — three files carry that basename and only the one named above owns the rule. That is a different
   system — these are ad-hoc hands with no role file — so the choice is yours to make and to
   state.

   - **`opus` when a wrong answer would be SILENT.** Adjudicating scope, partitioning a
     population, attacking a claim, writing a fixture arm or a mutant, deciding whether a
     receipt is satisfiable by something other than the correct fix. Every finding that has
     ever told this program it was wrong came from that shape. Batch 9's two best — a receipt
     closable by one comment line, and a provenance line that names a different corpus on its
     other branch — were judgments no stated grammar would have surfaced.
   - **`sonnet` when a wrong answer would be LOUD.** Resolving citations, counting a corpus
     against a grammar fixed before dispatch, running a fixture and reporting its exit code,
     confirming a path exists. A control in the same invocation catches the error.
   - **Never `sonnet` for the adversarial hand.** Its whole job is to find what the brief did
     not anticipate, and that is precisely what a cheaper model reproduces least.

   Say the model and the one-clause reason in the spawn, so a thin result can be re-run one
   tier up rather than re-argued.

   **DO NOT NAME A REPORT FILE AS ANY HAND'S DELIVERABLE. A HOOK DENIES THAT WRITE** —
   `Subagents should return findings as text, not write report files`. An earlier revision of
   this action prescribed exactly that, and it is the single instruction that has cost this
   program the most delegated work. Ask for findings AS TEXT in the final message.

   **GIVE EVERY HAND A DELIVERABLE IN THE TREE, BECAUSE THAT IS THE ONE THAT ARRIVES.** Measured
   across batches 9 and 13 with the same split both times: the FIXTURE hand — whose output is a
   committed battery — delivered and produced the best work of the batch, while the scope,
   receipt and adversary hands, whose output was a message, went idle without delivering. Batch
   13 sent eight content-free idle notifications and two direct follow-up requests before the
   lead did all three jobs itself. **Budget for that**: dispatch the hands, do the work yourself
   in parallel, and treat anything a hand returns as a check on your own answer rather than as
   the answer. A hand that has gone idle twice is not going to report.

   The hazards themselves are in `.claude/rules/tool-hazards.md` under "Delegation hazards" and
   are not restated here.
   Ask of every receipt: does a correct fix satisfy it, what ELSE satisfies it, and can the
   CORRECT fix be one it REJECTS. Key mutants on LOCATION and observable BEHAVIOUR, never on a
   spelling. **A hand can die mid-task** — one did, to a machine sleep, leaving a fixture
   half-edited and RED; check each one's deliverable rather than its report.
4. **Gate it the way the hook runs it, and read the GATE's own exit.** Simply push and let the
   hook's own run be the single gate — running it manually and then pushing pays for it twice.

   **The fixture tally is NOT the verdict**: a run has exited 1 with the suite reporting PASS.
   Tabulate every `── phase` header against PASS/FAIL, and read each changed fixture BY NAME
   against an impossible-name control in the same invocation. This shell has no `PIPESTATUS`, so
   `cmd | tail` reports `tail`'s status — never read a push's exit through a pipe.
5. **Close the batch properly. A `CLOSE-CANDIDATE` row is the instrument saying the fix is
   present; it is NOT the close.** Annotate each entry with `**LANDED (v<version>, verified
   <sha>).**` at the START of a line — that FORM is what the rotator keys on — then
   `scripts/backlog-rotate.sh --check`, then `--apply`. **Confirm the archive count MOVED.** A
   release has shipped with this step silently skipped and was reported complete; it was caught
   only because the operator asked.

   **THEN LOOK FOR THE ENTRIES YOU CLOSED WITHOUT MEANING TO.** Operator ruling: a PC-backed fix
   will sometimes discharge pre-existing entries that carry no classification, and those closes
   are free — but only if someone looks. The receipt histogram you already run is the
   instrument: **any entry other than your subject reporting exit 0 is an incidental close.**
   Run it before and after, and diff the two.

   ```
   bash -c 'while IFS= read -r l; do ( eval "$l" ) >/dev/null 2>&1; echo "$?"; done \
     < <(awk "/^## BL-[0-9]+/{e=1} e && sub(/^[ \t]*verify: sh /,\"\")" docs/backlog.md) \
     | sort | uniq -c'
   ```

   A 0 in that histogram is a HYPOTHESIS, exactly as `CLOSE-CANDIDATE` is: run that entry's
   receipt alone, read the raw exit, and ask what ELSE satisfies it before annotating anything.
   And record the incidental close in the release commit message — `named_absorbed()` reads
   commit MESSAGES, so an id discharged but not cited produces no row anywhere.

   **THE MIRROR CASE IS ALSO EXPECTED AND IS NOT A FAILURE.** A PC-backed fix will file new
   entries; batch 12 filed four while closing one. File them, tier them, give each a provenance
   line, and do NOT narrow the fix to avoid uncovering them.
6. **AFTER THE MERGE, BEFORE YOU STOP: re-derive this file's own RESUME block and prove it is
   resumable.** This is a numbered action because it is the step that decays silently — the
   merge is the moment the block you were following becomes a description of work already done,
   and a session that stops there hands the next one an instruction to redo it.

   Do these four, and REPORT the result:

   - **Run the derive block above, verbatim, and compare every figure to what it CLAIMS.** Not
     "does it look right" — run it and diff. Fix the file where they disagree.
   - **Read the numbered action 1 as a stranger would.** If it still names work you just
     finished, it is wrong. Replace it with the next action; do not append beside it.
   - **Fix the COMMAND, never only the prose.** Measured at v0.417.0: that release corrected a
     stale figure in the sentence and left the grep beneath it returning a different number, so
     the file asserted 7 above a command printing 5. A resuming session runs the command.
   - **`bash scripts/validate-plan-shape.sh`**, which is the only mechanical half of this. It
     cannot see whether an action is stale, so it passing is not the answer — it is the floor.

   **The three failures this catches are all one shape: the file describing a tree that has
   moved.** A stale action 1 costs a whole session redoing a batch. A stale figure costs the
   trust that makes the other figures usable. A stale command costs whichever the reader
   believes.
7. **DETECT WHETHER A PULL IS OWED, AND IF IT IS, WRITE A RUNBOOK. Do not run the pull.**

   **THE DETECTION, run every batch after the merge.** Three readings from the delivery-gap
   derivation above, and the first one is the trigger:

   - **PENDING count > 0** — at least one discharged candidate the consumer cannot see. **This is
     the trigger on its own.** It is normally 1 per batch, so it goes non-zero almost every time
     and the question is only whether to bank it or send it.
   - **releases behind** — `installed` vs `VERSION`. Past **five**, treat the range as WIDE and
     say so; the consumer's own history is `0.373.0 → 0.378.0` then `0.412.0 → 0.415.0`, and a
     wide range means more paths adjudicated in one session and a bigger blast radius if a
     bootstrapping step is in it.
   - **is a BOOTSTRAPPING step in the range** — did this program change `preclassify.sh`,
     `apply.sh`, `ledger-reverify.sh` or the skill itself? The consumer's INSTALLED copy runs the
     pull that carries its own repair, so the fix cannot protect the pull delivering it.
     **MEASURE the specific hazard rather than warning about it** — for the mode defect that is
     `git diff --raw <installed-commit>..origin/main -- core/`, mode-only being modes-differ and
     blobs-equal. Batch 14 measured 0 of them and the warning would have been false.

   **THE PATTERN IS A RUNBOOK IN `docs/plans/`, and it already exists — do not invent one.**
   `graph-pull-0353-to-0354.md` through `graph-pull-0356-to-0357.md`, `graph-0396-to-0403-pull.md`
   and roughly a dozen others are the corpus; **read the most recent before writing a new one.**
   `docs/plans/graph-pull-0415-to-0425.md` is the most recent and is **DISCHARGED — read it as a
   worked example, not as a live plan.** Its `## Discharge` section is the more useful half: it
   records that the pull SPLIT on a `SELF-UPDATE-SAFE-STOP`, that its rehearsal's row count did not
   decompose across the split, and that its stop list was an ENUMERATION where it should have been
   a class — the run hit two stop-worthy states it had not named. What the shape requires:

   - **Name it `graph-pull-<from>-to-<to>.md`** and open with the `READ and FOLLOW` one-liner
     naming ITSELF. `validate-plan-shape.sh` checks the shape; a live plan also needs at least one
     resolving `path:line` citation or **P4** fails the push.
   - **Write NO ref and NO sha into it.** The skill pulls latest and resolves the ref itself. A
     sha written down goes stale the moment anything lands — including the docs commit adding the
     runbook.
   - **Do NOT re-describe the pull.** The `ai-dlc-update` skill owns resolving the ref, gating its
     self-update, carrying the machinery slice and emitting the worklist. Every step a runbook
     writes about that is a restatement that will drift. Say what the RANGE carries and what is
     special; let the skill's own report be the authority.
   - **`## Start here` must say the session's PROJECT ROOT is `/Users/n8/git/graph`** — skill
     scope follows the session root, not a Bash `cd`, and a session rooted in the distribution
     cannot invoke the skill at all.
   - **Say the consumer's tree is dirty and that this is EXPECTED** (`_bmad-output/` pipeline
     state), do not enumerate the files because the set grows while the pipeline runs, and forbid
     commit/revert/stash/clean — committing makes the branch ahead and the preflight auto-pushes
     in-flight state on a bare dry run.
   - **REHEARSE ON A `file://` CLONE FIRST and put the rehearsal's numbers in the file**, marked
     as an expectation rather than a guarantee, with an instruction to STOP and ping if the real
     run disagrees. Batch 14's rehearsal: 38 rows, 29 `UPSTREAM-ONLY`, 1 add, 8 `DIST-ONLY-SKIP`,
     **0 `->CLASSIFY`**, all four templates `TEMPLATE-UNCHANGED-NOOP`. A disagreement is
     information and is worth more than a clean report.
   - **Make closing the candidates a NUMBERED ACTION, by id.** The pull is not the point; the
     ledger closing is. Tell the session to run `ledger-reverify` **from the consumer root** — a
     distribution-root run has turned a live `STILL-LIVE` into a `CLOSE-CANDIDATE`, and a false
     close retires a live entry — and to report which ids closed and which did not.
   - **Leave a `## Discharge` section empty for the executor**, and require the file be retitled
     `DISCHARGED — DO NOT EXECUTE` when spent. A spent runbook still reading as instructions is
     this directory's recurring hazard: measured once at 5 of 6 files.

   **You cannot run the pull and must not try.** `consumer-boundary.md` is unconditional. Your
   deliverable is the released version, the runbook, and the number.
8. **Cite every closed id verbatim in the RELEASE COMMIT MESSAGE**, not only in `CHANGELOG.md`.
   `named_absorbed()` resolves the signal with `git log -F --grep`, which reads commit MESSAGES;
   a `###` section in the CHANGELOG is in the diff and produces no row at all.

### Ping the operator

**On any question, on any decision, on completion, and on any early stop.** This program runs for
many releases, and from outside a session that is thinking and a session that is waiting on a
human look identical. Merges are preapproved — do not stop to ask for one. Scope is the
operator's: never narrow a goal or drop an item on your own authority; deliver the whole scope
and say clearly what was blocked and why.

### Done when

The six criteria are in `## Done when` at the foot of this file, with 1, 2, 4, 5 and 6 already
satisfied and banked. Criterion 3 is per-release-branch and is re-checked on each batch.

---

*Everything below is HISTORY. It is evidence, not instruction.*

## Context

`/Users/n8/git/graph` is the reference consumer. Its
`_bmad-output/ai-dlc-update/push-candidate-ledger.md` is the queue of consumer innovations
upstream lacks and consumer-filed upstream defects. Every prior cycle drained **four entries**
and stopped; the ledger has grown faster than it has been drained. The operator has asked for
the whole thing: adjudicate every open entry against ground truth, remediate what is real, and
give graph a legitimate way to close what is not.

**The instrument that would normally answer "what is still open" cannot answer it right now,
and it says so itself.** graph's own reconcile report for the 0.370.0 → 0.372.0 pull carries
this line, and the same run reproduces from this session:

> `RECEIPTS-UNDECIDED  (theirs_has receipts)  28 of 28 'theirs_has' receipt(s) reported
> STILL-LIVE on a substring present at BASE as well as at theirs (0.372.0) … Do not treat a
> zero CLOSE-CANDIDATE count from this run as evidence that nothing was absorbed.`

So the zero-close reading is not a floor, and the 59 `STILL-LIVE` rows are not findings. Every
entry has to be taken to the working tree by hand. The measured base rate of expired premises
in this corpus is roughly **one in two** — expect about half the ledger to be dead.

## Start here

**Two repos, and the boundary is absolute.**

- **`/Users/n8/git/ai-dlc`** — WRITE. This is where remediations, CHANGELOG citations,
  `docs/backlog.md` entries and the adjudication register land.
- **`/Users/n8/git/graph`** — **READ ONLY.** `.claude/rules/consumer-boundary.md` is
  unconditional: an ai-dlc session never writes to a consumer. Do not edit, commit, or push
  there. Record `git -C /Users/n8/git/graph status --porcelain | wc -l` before the first action
  and assert it after every phase; a change is a stop-and-ping condition.

**The only two channels that reach graph** are (a) a released version of `core/` that names the
entry's `PC-` id **verbatim**, and (b) a brief the operator carries into a graph session. Nothing
else.

**THIS FILE SAID THE CITATION GOES IN `CHANGELOG.md` AND THAT IS FALSE.** `named_absorbed()`
(`core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:402`) resolves the signal with
`git log -F --grep`, which reads **COMMIT MESSAGES**. A `###` section in `CHANGELOG.md` is in the
commit's DIFF, never its message, so it produces no `NAMED-UPSTREAM` row at all. Measured over the
25 citable closes against `origin/main`, both channels in the same invocation: 4 appear in a commit
message, 8 in the `CHANGELOG` blob, **16 in neither** — and the four that sit in the `CHANGELOG` and
not in a message are the decisive group, because they are cited exactly as this file prescribed and
`named_absorbed()` returns nothing for them. Control in the same invocation: an impossible id
returns 0 from both channels.

So **the id goes in the RELEASE COMMIT MESSAGE, verbatim, for every closed entry**, and in
`CHANGELOG.md` as well — the message is what the closer joins on, the `CHANGELOG` is what a human
and the brief read. Citing only one of the two is the failure this paragraph exists to prevent.

`named_absorbed` takes `tail -1`, the OLDEST matching commit, so re-naming an id already named by an
earlier release does not move the reported version — it still reports the release that first named
it, which is the correct answer.

**Never run `ledger-reverify.sh` with the process cwd at the ai-dlc root.** Measured and
recorded at `core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:927-948`: a distribution-root
run turned a live `STILL-LIVE` into a `CLOSE-CANDIDATE`, and a false CLOSE is the worst output
this tool has — it retires an entry that is still live. Always `cd /Users/n8/git/graph` first and
pass the **absolute** consumer root:

```
cd /Users/n8/git/graph && bash .claude/skills/ai-dlc-update/reconcile/ledger-reverify.sh \
  /Users/n8/git/ai-dlc <base-sha> /Users/n8/git/graph <theirs-sha>
```

**Ping the operator** on any question, on any decision, on completion, and on any early stop.
This program runs for many releases; from outside, a session that is thinking and a session that
is waiting on a human look identical. Merges are preapproved — do not stop to ask for one.

## Status record

**This is the only status record in this file.**

**Phase 0 steps 0–1 are COMPLETE.** The corpus pin, taken on the branch
`ai-dlc/graph-ledger-drain` cut from `origin/main` at `b1ee196`:

| pinned quantity | value |
|---|---|
| graph `HEAD` | `510e4d9f50192e85df54b81df7ebc70d53bdb638` |
| graph `git status --porcelain \| wc -l` **baseline** | **35** |
| ledger `md5` | `2fd444dcf406cdff728fe3c0c4352267` (4356 lines) |
| ledger archive `md5` | `8989cb668a33c6c73be429b827d9797f` (4474 lines) |
| ai-dlc `theirs` | `b1ee196`, VERSION `0.372.0` |
| ai-dlc `base` for reverify | `adec9ae` (0.370.0) |

The pinned copies live in the session scratchpad. **Every step from Phase 0 step 3 onward reads
the pin, not the live file** — a graph session is filing into the live ledger concurrently.

**Phase 0 steps 2–4 are COMPLETE, and they replace the planning-session estimates below.** The
census was built by lifting `ledger-reverify.sh`'s own extraction program (lines 621–738)
verbatim and changing one thing: `flush()`'s `has_verify &&` conjunct was dropped so an entry
carrying no receipt is emitted too. **The control is that the receipt-carrying subset must equal
the tool's own label set** — 79 labels each way, symmetric difference EMPTY, and the comparison
demonstrably fires on a one-line mutant.

| derived, Phase 0 | value |
|---|---|
| **open entry starts** | **131** |
| section banners that are not entries | 16 |
| **adjudicable open entries** | **115** |
| carrying `theirs_has` | 25 |
| carrying `verify: manual` | 24 |
| carrying `verify: sh` | 19 |
| carrying `theirs_lacks` | 11 |
| **carrying no receipt at all — invisible to the closer** | **36** |

**The tool's ENTRY column is not a unique key, and that is a new finding.** Its own header calls
the label *"a join key back into the ledger"*, but the label is whatever precedes the first
` — `, so four `## Open — filed <date>` banners all label as `Open` and the two
`scripts/validate-provenance-block.sh` bullets at pin lines 297 and 302 collide outright. **That
path is the CONSUMER's spelling, quoted from the ledger's own bullet label — do not look for it
here.** In this tree the file is `core/scripts/validate-provenance-block.sh`; `install.sh` lands it
at `scripts/ai-dlc/`.
**Measured: no collision today involves a receipt-carrying entry**, so the defect is real but
currently emits no wrong report row. Tier it accordingly.

**Phase 1 is COMPLETE, and so is the refutation pass that verifies its closes.** The 115 entries
were adjudicated in 29 parallel batches of 4; all 48 proposed closes were then attacked by 12
independent verifiers briefed to break them.

**PHASE 2 IS COMPLETE. `v0.373.0` IS CUT AT `e939a92` ON `ai-dlc/graph-ledger-drain`, NOTHING
PUSHED AND NOTHING MERGED.** `VERSION` is `0.373.0`, the top CHANGELOG heading matches, and
`scripts/validate-release-version.sh` PASSes over 41 commits. The full gate was run the way the
hook runs it — `AI_DLC_FIXTURE_NO_SKIP=1 bash .githooks/pre-push` — and is GREEN: **157 fixtures,
157 ok, 0 FAIL**, with both changed fixtures read by name against an impossible-name control that
came back empty.

**PHASE 4 IS COMPLETE. THE BRANCH WAS MERGED INTO LOCAL `main` AT `3217cde`. It could not be pushed
AT THE TIME; that is no longer true and the paragraph two below says why.**
The full gate was run the way the hook runs it and is GREEN — **157 fixtures, 157 ok, 0 FAIL,
`pre-push: all gates green`** — with all six fixtures changed on the branch read BY NAME in the
full output against an impossible-name control returning 0 and a present-name control returning
non-zero, in the same invocation. `validate-release-version.sh` PASSes over the 58-commit range.
The merge precondition held: local `main` was at `origin/main` with zero commits ahead.

**PUSHING WORKS NOW AND THE 403 PARAGRAPH BELOW IS HISTORY, NOT A CONSTRAINT.** It once returned
403 because the credential helper authenticated as `ats0012_amway`, which has no write access to
`euron8/ai-dlc`. Both v0.374.0 and the two commits after it were pushed successfully. **The remote
is now the SSH alias `git@github-euron8:euron8/ai-dlc.git`**, not the https URL the credential-helper
paragraph in action 0 describes — that paragraph is STALE about the mechanism and is kept only
because the helper is not recorded anywhere else. **Read a push's exit code without a pipe** either
way: `git push … | tail` reports `tail`'s status and prints `exit=0` over a failed push, because
this shell has no `PIPESTATUS`.

**PHASE 3 BATCH 1 IS COMPLETE, MERGED AND PUSHED AS `v0.374.0`.** It adjudicated the three
`CLOSE-CANDIDATE` rows and built the one guard that adjudication turned up. Merge `6828d91`,
release `b8fda98`. The gate was run the way the hook runs it on the branch AND again on the merged
tree — **157 fixtures, 157 ok, 0 FAIL, `pre-push: all gates green`** both times — with the changed
fixture read BY NAME against an impossible-name control returning 0 and two present-name controls
returning non-zero, in the same invocation. `validate-release-version.sh`: one release in the range.

**ALL THREE `CLOSE-CANDIDATE` ROWS WERE REAL ABSORPTIONS AND THE CLOSE STILL SPLIT 2/1. That split
is the finding, and it is a form of the data-losing direction this plan does not otherwise name.**
`BL-009`, `BL-011` and `BL-012` were all fixed by one commit, `941021d`, released in v0.373.0 —
and that commit's own body reads *"GUARDS ARE STILL OWED AND THIS COMMIT DOES NOT PRETEND
OTHERWISE"*, closing *"None of the three entries may be annotated LANDED until that work is done"*.
Two guards landed inside v0.373.0 (`953e39e`, `cb94a43`); `BL-012`'s never did. Closing all three on
the receipts alone would have been correct about every receipt and would still have deleted the only
written record that a guard was owed. **A receipt that rotted is not the only way a close loses
data; a REAL absorption whose close drops the work still attached to it is the other.**

**The absorbing release is NOT `VERSION` at the fix commit.** `941021d` carries `0.372.0` and
released in `0.373.0`. Derive it by an INCLUSIVE forward walk to the first `VERSION` differing from
the fix's parent. That is `BL-066`'s subject and it is still live.

**PHASES 0–2, 4 AND 5 ARE COMPLETE. PHASE 3 IS THE ONLY REMAINING WORK AND ITS HOLD IS RELEASED —
KEEP CUTTING BRANCHES.** The A6 ceiling question is ruled and executed too, so **no decision is
waiting on a human.** See ACTION ZERO, which overrides the numbered sequence.

graph pulled v0.373.0, merged it at **PR #935**, and applied sections A, B and E of the brief.
Measured on the consumer at wind-down, all four stamp fields at `858f4f5`:

| consumer quantity | before | after |
|---|---|---|
| `RECEIPTS-UNDECIDED` | 28 of 28 | **5 of 5** |
| live ledger | 4719 lines | **2953** (archive 6491) |
| `NEEDS-REVIEW` / `INPUT-UNRESOLVED` / `ENTRY-SWALLOWED` | — | **0 / 0 / 0** |
| layer debt OPEN | 16 | **10** |

56 annotations applied (pin 610 was already archived), 42 receipts — 18 replaced and **24 inserted**.
**The 24 inserts are the class that carried NO DIRECTIVE AT ALL**, invisible to every report rather
than merely unclosable; the reverify row count RISING after section E is that set becoming visible,
which is the finding this whole program started from.

**FOUR NEW UPSTREAM DEFECTS CAME OUT OF THE PULL AND ARE FILED** as `BL-066`–`BL-069`, all found by
the consumer, all re-derived here against the shipping code, all with receipts proven in BOTH
directions. See the closing section for what each one is.

**TWO DEFECTS WERE FOUND IN THIS PROGRAM'S OWN BRIEF, BOTH AFTER IT "VERIFIED SOUND", AND BOTH
CAUGHT BEFORE APPLICATION** — the one-version-for-all annotation and an exclusive version walk wrong
by a whole release. Both are fixed and both now carry an arm that can fail. The brief was
subsequently audited row by row from both ends: **57 annotation rows, 0 mismatches**, 39 + 1 + 17 =
57 with the arithmetic itself as the control against an audit that quietly examined a subset.

**Two claims elsewhere in this file are WRONG and both would cost a fresh session real work.**

**`named_absorbed()`'s `tail -1` is not always the correct answer, and the paragraph under "Start
here" says it is.** That paragraph reasons that re-naming an id already named by an earlier release
"still reports the release that first named it, which is the correct answer". For pin 4216,
`PC-S303-POSTCOMPACT-RECOVERY-MANDATE-HAS-NO-STATED-EXCEPTION`, it is the WRONG answer. v0.372.0
named it first, at `1537e4c`, and that close was REFUTED — the gate did not arm on the reference
consumer at all. The actual fix is `9cbb77f`, which `git merge-base --is-ancestor` puts INSIDE
v0.373.0 (0 one way, 1 the other, against a self-comparison control of 0). Both commits now match
the grep, oldest wins, so the mechanical channel will report absorption at the release that did not
fix it and no amount of re-citing can move it. That entry therefore carries `verify: manual` and
needs an operator-chosen version. **A first naming that was a false close makes "the release that
first named it" the one answer you must not report.**

**"Still owed as FIXES, not filings" under Phase 2 is STALE — both landed in v0.373.0.** The
recovery gate not arming on a bare-basename step file, and the gate treating a partial read as a
full one, are both fixed and guarded: `core/hooks/ai-dlc-recover-gate.sh:118` distinguishes a
partial read from a full one, and `core/fixtures/postcompact-rulebook-recovery/run.sh` carries
eight bare-basename references, two mutant arms over exactly that case, and a near-miss arm at
`:527-528` establishing that an `offset:1` Read IS a full read and must be allowed. The fixture
PASSes. A session following that line literally would rebuild two fixes that already exist.

**THE PLAN WAS WRONG ABOUT THE `verify: sh` POLARITY AND SO WAS I, IN THE OPPOSITE DIRECTION —
THIS IS THE MOST IMPORTANT THING ON THIS PAGE.** The two reverify engines read a receipt's exit
code in OPPOSITE senses, and a receipt written for the wrong one proposes closing a live defect:

| engine | subject | `rc=0` | `rc≠0` |
|---|---|---|---|
| `scripts/backlog-reverify.sh` | ai-dlc's OWN `docs/backlog.md` | CLOSE-CANDIDATE, "the fix is present" | STILL-LIVE |
| `core/skills/ai-dlc-update/reconcile/ledger-reverify.sh` | the CONSUMER's ledger | **STILL-LIVE** | **CLOSE-CANDIDATE** |

Read at the emitter, not the header: `ledger-reverify.sh:942`'s dispatch comment states *"`sh`
reads a non-zero exit as 'no longer reproduces' -> CLOSE-CANDIDATE."* `backlog-reverify.sh:184-186`
states the opposite for its own file.

**I briefed four agents with the ai-dlc polarity for receipts destined for the CONSUMER's ledger.**
One caught it unprompted and inverted; the rest were corrected mid-flight. All 14 drafted receipts
now measure `rc=0` (STILL-LIVE) — verified by RUNNING them, not reading them, under the engine's own
exported environment, with controls both ways. **A receipt for a consumer entry must exit 0 while the
defect is live.** The failure mode is a FALSE CLOSE, which this file's own Hazards section calls the
worst output in the system.

**And `126`/`127` are NOT a close.** A renamed subject also exits non-zero, so a relocation reads as
an absorption that never happened — measured on this consumer, one relocation commit moved five
receipt subjects and all five flipped to CLOSE-CANDIDATE in a single run, every one still
reproducing at its new path. Guard every `sh` receipt so an unresolvable subject exits 127
(`[ -n "$s" ] || exit 127`), which `ledger-reverify.sh` reports as NEEDS-REVIEW.

**The pin HOLDS, and graph `HEAD` HAS MOVED PAST `510e4d9f5`. Those are not in tension, and a
session that treats the second as breaking the first will re-derive this from scratch.** The
`HEAD` row in the pin table above is the sha the pin was TAKEN at, not a quantity that stays
true; graph commits on its own schedule and has done so repeatedly since. What is pinned is the
ledger's first 4356 lines, and that reconstruction is verified rather than assumed: `sed -n
'1,4356p'` reproduces `2fd444dcf406cdff728fe3c0c4352267`, with the 4355-line control producing a
different digest.

**The delta is a pure APPEND and that is why the pin survived a moved `HEAD`.** The ledger blob at
`510e4d9f5` is **4312** lines because the pin was taken against graph's WORKING TREE while those
lines were still uncommitted; `8ad601f87` then committed them as a 191-line append at line 4311
with **zero deletions**, and `4312 + 191 = 4503`. Its four entries are all already adjudicated —
pin 4313 as `BL-062`, and 4357 / 4392 / 4435 as `BL-063`–`BL-065`. **No new graph filings**, so the
post-pin adjudication still covers everything.

**Re-derive the delta, do not re-derive the pin.** `git diff --numstat <pinned-HEAD>..HEAD --` the
ledger path answers in one command whether a `HEAD` move touched the pinned region; a non-zero
deletion count or a hunk starting below 4356 is the only state that breaks the reconstruction, and
the md5 says so independently. Consumer dirty count observed at 3 here and at 113 earlier in the
program; that is an observation and never a gate, per done-when 4.

**Pin 1254's disposition is CORRECTED and its sub-claim is refuted**, so the split is now
**25 CLOSE / 14 CLOSE + file the sub-claim / 9 withdrawn / 67 live** — 39 closes, unchanged. The
claim was verified behaviourally rather than taken from this file: mutating
`core/scripts/validate-mandatory-rules.sh:233` to `if false` makes Check 4's PASS branch unreachable
and `mandatory-rules-skip-accounting` reports `FIXTURE ERROR` with arms A, B and D falling to `[]/1`,
against an unmutated control of `PASS (10 assertions)` in the same session. **A grep was the wrong
instrument twice over** — renaming the emitted `CHECK 4: PASS` string kills nothing, because the
fixture asserts the SUMMARY line rather than the per-check line.

**Correcting it exposed that two register sections were hand-written while `--check` passed**
(`c9a4500`). The gated list still said "The fifteen" and still listed 1254; the nine-withdrawn-closes
table held the last hand-typed id column in the file, and it had already decayed — pin 4216 was
written `…MANDATE-NO-STATED-EXCEPTION` against the ledger's `…MANDATE-HAS-NO-STATED-EXCEPTION`. Both
now render, and the gated list's heading COUNT is inside its region deliberately. Measured by joining
every `PC-` token in the register against every one in the pinned ledger: 93 resolve; of the 16 that
do not, 14 are deliberate prose shorthand and 2 sat in that id column.

**THE PULL IS DONE AND ADJUDICATED. graph MERGED v0.373.0 AT PR #935, `0 HARD blockers`.** Sections
A and B of the brief are NOT yet applied and are the only step outstanding on the consumer side.
What the pull produced, all of it adjudicated live:

- **Two upstream defects, both real, both now filed.** graph filed `PC-S334-ABSORBED-AT-READS-THE-`
  `VERSION-BLOB-AT-THE-FIX-COMMIT` — verdict **HOLDS-WIDER**. `absorbed_at()` reads `VERSION` at the
  commit that introduced the substring, but a fix lands while `VERSION` still holds the previous
  number, so it reports one release early: 40 of the 68 commits in `b1ee196..858f4f5` carry the
  pre-bump value. **The filing's scope was wrong in both directions** — `absorbed_at` has TWO
  invocations (`:905`, `:934`), not three, and the cited lines 271/427/455 are not call sites at all
  but the three instances of the `git show "${_c}:VERSION"` IDIOM, in `absorbed_at`,
  `named_absorbed` and `named_ambiguous`. The filing named the true scope while mislabelling it.
- **The widest instance is `named_absorbed()`, filed separately as `BL-066`**, because the fault is
  the JOIN and not the version read, so the forward-walk remedy does not reach it. `_c` is the
  OLDEST commit whose MESSAGE contains the id (`:402`, with a third instance of the idiom in its own
  prefix-fallback arm at `:423`), and `$na_v` from it is interpolated into a paste-ready PERMANENT
  annotation at `:848`. Measured over the 29 ids in `e939a92`'s message against
  `final-disposition.tsv`: **2 agree and 23 disagree over 25 comparable rows**, with 20 resolving to
  `e939a92` itself. Only 4 rows — 2 `FALSIFIED`, 2 `DUPLICATE-OF` — name no absorbing release; the
  25th is `ALREADY-FIXED-93e05d3`, an absorption claim spelled as a SHA, which resolves to 0.102.0
  against the join's 0.373.0. **THREE**
  of the nine older resolutions are this program's own `docs(plan)`/`docs(reviews)` commits that
  merely MENTION the id — the same reads-vs-mentions class as `receipt_absent_subjects` — and a
  fourth, `5b5b95c`, is worse: a ledger-drain release touching 23 `core/` files, attributed to an
  entry adjudicated **FALSIFIED**, so the function would propose an absorption annotation for
  something that was never a defect. **And this plan CAUSED the 20-row case**: the correction
  requiring every closed id in the release commit MESSAGE is what makes the join resolve there.

  **THIS ONE NUMBER WAS WRONG THREE TIMES AND EACH CORRECTION CAME FROM SOMEONE RE-DERIVING IT
  RATHER THAN ACCEPTING IT. That pattern is the finding; the number is just its subject.**

  It read **28 of 29** first — counted BY EYE off a printed table whose adjudicated column also
  matched `FALSIFIED` and `DUPLICATE-OF` rows, so entries with nothing to compare were scored as
  disagreements and a second agreement was missed. It reached the consumer, this file and a commit
  message before a delegate computed the join instead of transcribing it. **A count read off a
  rendering is not a derived count** — the same class as reading a report's own summary sentence as
  a data row, which this program also did one turn earlier.

  It then read **22 of 24 comparable**, which was arithmetically right and mis-partitioned: the
  non-comparable bucket was described as `FALSIFIED`/`DUPLICATE-OF`/`HOLDS`-family when it contains
  no `HOLDS` row at all and does contain an `ALREADY-FIXED-93e05d3`. **The consumer caught that**,
  having derived its own figure before the correction arrived rather than taking one.

  It is **23 of 25** because that sha row is a real absorption claim that a `v`-anchored regex
  cannot parse. **The bucket labelled "nothing to compare" was an artifact of the parser's grammar,
  not a property of the data**, and it hid the single largest disagreement in the set. Every stage
  of this was a clean-looking run.

  **AND THE FIX FOR IT WAS ITSELF WRONG BY A WHOLE RELEASE, WITH A CONTROL THAT COULD NOT HAVE
  CAUGHT IT. This is the sharpest instance in the program of "a check that cannot fire reads exactly
  like one that passed", because it sits INSIDE a guard built to stop a version being wrong.** The
  renderer resolved the sha with an EXCLUSIVE `<sha>..HEAD` walk, on the reasoning that a fix lands
  before its release commit bumps `VERSION`. **Both shapes exist here and the only row this path
  touches is the other one**: `93e05d3` changes `VERSION` itself, `0.101.0` -> `0.102.0`, so it IS
  its own release; the exclusive walk stepped past it to `ebbfae9` and rendered **v0.103.0**. The
  control asserted that a walk from `e939a92~1` lands on `e939a92` — but `e939a92` is a release
  commit one step AHEAD of the start point, so inclusive and exclusive return it alike. **Measured:
  both semantics give the same sha, so the control passed under the broken implementation and under
  the fixed one.** The discriminating input is a release commit walked FROM ITSELF, which is exactly
  the shape the corpus row has and exactly the shape the control avoided. **ARM 5 now uses that
  input and asserts the two semantics DIFFER before reading either**, so it refuses when it cannot
  discriminate rather than passing — proven by reverting the walk, which makes it report both
  answers as `0.103.0` and exit 9. Caught by the consumer, re-deriving.
- **`closes_when` is free prose that nothing parses**, found by graph, filed as `BL-067`. Read at
  `audit-layer-debt.sh:108` and printed at `:215-216`; `migrate-artifact-paths.sh` has zero hits for
  it against a `strip_token` control of 3. It has a schema, a producer and a printer and **no
  consumer**. Measured on the consumer's own register: 24 `owed` objects, **0** ever recorded in any
  `closes_owed`, and 6 carrying the identical `closes_when` naming
  `migrate-artifact-paths.sh --apply` — which graph then ran, so all six came due and nothing
  announced it. Control in the same invocation: 0 open debts match an impossible token.

**Both `BL-` receipts were proven in BOTH directions before filing, which is the half that is
usually skipped.** Against the shipping tree each exits **1** — STILL-LIVE under
`backlog-reverify.sh`'s polarity, which is the OPPOSITE of the consumer engine's — and against a
copy carrying the fix each exits **0**, with the two sides asserted to differ before the comparison
was read. A receipt that cannot go green is a check that cannot fire wearing a live-defect badge.
`backlog-reverify.sh` reports both as `STILL-LIVE` by name, against an impossible-id control of 0.
Neither anchors on a substring: `BL-066` evals the shipping `named_absorbed()` against a synthetic
three-commit history where a `docs` commit MENTIONS the id and a later `fix:` commit absorbs it,
because any fix will quote the `tail -1` reasoning back inside the comment recording it.

**A BLOCKER WAS FOUND IN THIS PROGRAM'S OWN BRIEF, ONE STEP BEFORE IT WAS APPLIED, AND IS FIXED.**
`render-brief.sh` rendered ONE annotation string from the pulled version and instructed it into all
57 entries of sections A and B — while 34 section-A rows are adjudicated `ALREADY-FIXED-v<X>` across
29 distinct versions from v0.21.0 to v0.372.0, and **not one** is adjudicated at 0.373.0. A literal
application stamped v0.373.0 as permanent provenance onto an entry the same brief adjudicates as
fixed in v0.21.0 — precisely the failure `absorbed_at()`'s header was written about, re-introduced
at the human layer. **Arm 1 could not see it**: both enforcers check only the FORM, bold and a digit
after the `v`, so it proved the string well-formed and nothing proved it TRUE. Each row now carries
its own paste-ready string, and **ARM 4** reads the RENDERED artifact — not the map, which would be
a tautology — and refuses when an annotation contradicts its own row's verdict. Proven both
directions: the one-version-for-all mutant refuses at exit 8 naming the pins, the clean render
passes, and 7 version-less rows correctly do not trip it.

**START HERE ON A FRESH SESSION — the numbered next actions.**

### BATCH 7 — COMPLETE, SHIPPED AS `v0.380.0`, WITH `v0.381.0` AFTER IT. A RECORD, NOT AN INSTRUCTION. DO NOT RE-DO IT.

**The line that stood here read `ACTION ZERO: … THE NEXT BATCH IS BATCH 8 AND BL-079 IS ITS
SUBJECT`, and batch 8 shipped as `v0.415.0`.** It is rewritten as a heading because it was the
loudest sentence in the file and the only one shaped like an order, so a resuming session that
skimmed would have taken a spent directive from the history half — the exact failure the
`## RESUME HERE` preamble exists to prevent, sitting in a form that outranks the preamble.

**`v0.380.0`** — merge `5b1fea28`, release `56fbd212`, close+rotate `b2df8e00`. `BL-084` filed and
`BL-073` closed, both annotated `**LANDED (v0.380.0, verified 5b1fea28).**` and rotated: live
**63 → 61**, archive **20 → 22**, 83 ids either side with none in both, `--check` PASSing before
`--apply`, and `backlog-reverify` reporting **0 CLOSE-CANDIDATE** afterwards against an
impossible-id control of 0. Gate run the way the hook runs it: exit **0** read directly, **15 of
15** phases PASS, **161 ok / 0 FAIL**, `subagent-probe` read BY NAME against an impossible-name
control of 0 and a second present-name control of 1, in the same invocation.

**THREE INDEPENDENT HANDS ON SCOPE, FIXTURE AND RECEIPT FOUND DEFECTS IN WORK ALREADY COMMITTED ON
THE BRANCH, AND TWO OF THE THREE WOULD HAVE SHIPPED.** That is now 4 of 4 batches where the
independent-hand mechanism paid.

- **The fixture's one arm for "teammate transcript missing" was reading the PREVIOUS fire's file.**
  `fire()` skipped the copy when a seed was absent but never removed what an earlier fire left
  under the same `agent_id`, so the absent case was never absent. Measured: a hook mutated to fall
  silently BACK to the lead transcript produced output **byte-identical** to the fixed hook's
  across the whole fixture. Repaired, and that mutant now fails two arms by name.
- **Two claims the branch had already committed were FALSE.** The hook header asserted true
  teammate peaks sit well below the threshold and true `compactions` is zero — scanned over all
  1086 teammate transcripts with the hook's own predicates, **32 exceed the 287000 threshold and 16
  actually compacted**, max peak **372633**, above it. And lead-arm agreement was published as
  `99.1%` against a re-derived **95.9%** (1248/1301). Both retracted in place.
- **`131 of 395 adversary spawns ran sonnet despite an opus pin` is refuted outright** — 140
  adversary spawns resolve to a teammate transcript, all opus-pinned, all ran opus, and 395 is not
  constructible from that ledger. The investigation doc is corrected; the correction makes its
  surviving hypothesis stronger, not weaker.

**A GREEN FIXTURE TALLY IS STILL NOT THE GATE VERDICT, AND IT BIT AGAIN HERE.** The first gate run
exited **1** with the fixture suite PASSing: the failing phase was `no dead doc refs`, because the
branch's corrected hook header cited `docs/backlog.md`, which `install.sh` does not ship — a dead
pointer in every consumer tree, aimed at an entry the same release closes. `origin/main`'s copy
carries 0, so the branch introduced it. **Tabulate every `── phase` header against PASS/FAIL and
read the gate's own exit; the tally answers a different question.**

**`validate-release-version.sh` FIRED ON A REAL DEFECT TOO.** An earlier commit's subject carried
`v0.380.0` while `VERSION` at that commit was `0.379.0`. Predicate A caught it. When rewriting
history to fix a subject, assert the rebuilt tree is byte-identical to the original **and** that
the comparison is not vacuous — `git diff --quiet OLD HEAD` alongside a diff against `OLD~1` that
must be non-empty.

**`v0.381.0` — THE FIXTURE SUITE RAN IN FULL ON EVERY PUSH AND TWO SKIP INSTRUMENTS WERE THE
CAUSE.** Merge `ef2ece74`, release `785920f8`. `apply_readset_skip`'s no-change branch printed
*"nothing changed … (the content key owns that case)"* while `fixture_suite_step` printed
*"content key changed — running the suite"*; each deferred to the other and neither ever skipped.
Measured on the close-and-rotate commit above, which touched only two files under `docs/` — a top
the content key's own `EXCLUDE` block already lists — **all 161 fixtures ran**, with both sentences
four lines apart in the log. The read-set manifest now owns the decision, and its universe gains
untracked-but-unignored files, without which the new skip would run over a tree nobody hashed.
`readset-skip` goes 21 → 26 assertions with two mutants keyed on the emitting line. Proof it works:
the very next push selected **29 of 161 fixtures and skipped 132**.

**THE OPERATOR'S STANDING DIRECTION AT THE END OF THIS SESSION: STOP MEASURING THE PIPELINE, BUILD
THE FIX.** The wall-clock investigation is closed at `docs/v0.380.0-pipeline-cost-investigation.md`
with its eleven refutations plus the plateau exit. Do not re-run any of them.

**WHAT BATCH 7 BECAME, AND WHY IT IS NOT `BL-079`.** The operator directed that the consumer's
wall-clock problem be diagnosed before the next batch. That investigation is COMPLETE and its record
is tracked at **`docs/v0.380.0-pipeline-cost-investigation.md`** — read it before touching anything
here; it lists ELEVEN refuted hypotheses so they are not re-run, and each one cost hours. Batch 7
became the one live defect that investigation fell over. `BL-079` moves to batch 8.

**WHAT IS DONE (committed, verified):** `core/hooks/ai-dlc-subagent-probe.sh` read the LEAD's
transcript, so all six derived fields were the lead's. Both reads now point at the teammate's own file
at `<slug>/<session-uuid>/subagents/agent-<agent_id>.jsonl`. `BL-073`'s `|| echo 0` conflation is
gone. Schema stamp `v1 -> v2`. The false premise is corrected in the hook header AND in
`enforcement-map.yaml`'s `subagent-context-probe` block, which stated it verbatim. The fixture could
never fire on this defect — it seeded a teammate-shaped transcript, a layout that does not occur — and
now builds the real two-file shape. Proven both directions on a `git archive` extract: fixed hook
**26/26**, the real pre-fix hook from `origin/main` **fails 15 field assertions**, with the two
asserted to differ before any comparison is read. `validate-enforcement-map.sh` exits 0.

**WHAT REMAINS, in order:**
1. **File `BL-084`** for the probe defect and annotate **`BL-073`** as landed. Note in `BL-073`'s
   annotation that its receipt would REJECT a correct fix — it requires exactly three lines matching
   `^\s*(PEAK|TURNS|COMPACTIONS)=.*jq`, so hoisting those reads into a helper exits 9 forever. The
   shipped fix keeps the three lines, so it closes.
2. **CHANGELOG heading + `VERSION` 0.380.0 + a release commit subject naming it** — one claim, joined
   at pre-push. One version on this branch.
3. **Run the gate the way the hook runs it**: `AI_DLC_FIXTURE_NO_SKIP=1 bash .githooks/pre-push`.
   Read the GATE's exit, never a wrapper's; tabulate every `── phase` header against PASS/FAIL; read
   `subagent-probe` BY NAME against an impossible-name control in the same invocation.
4. Merge, push, **ANNOTATE** with `**LANDED (v0.380.0, verified <sha>).**` at the start of a line,
   then `scripts/backlog-rotate.sh --check` then `--apply`. **Confirm the archive count moved off 20.**

**THE WALL-CLOCK QUESTION IS DIAGNOSED BUT NOT FIXED, AND THE LIVE LEAD IS THE OPERATOR'S.** Planning
cost is uncorrelated with scope (r=0.060) and tracks artifact count (r=0.953); depth tripled at a dated
boundary; the pipeline is lead-bound. Concurrency is refuted (1.17–1.62× charged, negative under one
divergence). The surviving proposal, and it is the operator's own: **`MAJOR` is overloaded.**
`core/team-roles/adversary.md:157-161` makes an underived claim a MAJOR "whether or not you can yet
falsify it" — so *unproven* blocks the exit exactly as hard as *wrong*, and is discharged by ADDING a
derivation, which is an edit, which is what produces the next pass's findings. Supporting figures:
MAJOR 2.10/pass against CRITICAL 0.98; **79% of pass-2+ findings are repair-introduced**; pass-2+
CRITICALs are **3 of 3, 2 of 4, 4 of 4 prior-scope**.

**A DIFFERENT PROPOSAL — A PLATEAU EXIT — WAS BACKTESTED AND IS DEAD. DO NOT RE-RUN IT.** Over 47
fully adjudicable series / 127 passes (s288–s304; 29 series excluded for pre-v0.48.0 schema or missing
pass tokens, named rather than counted as zero): a 2-pass non-increasing-MAJOR exit and every
`MAJOR <= k` variant are **DISQUALIFIED** — each skips a *prior-scope* CRITICAL that was already in the
text when the predicate declared convergence (`s302/stories-p4`, an AC asserting one durable-marker
prefix where the code writes seventeen from nineteen sites; `s299/coe-p3`, an artifact contradicting a
Rule-13 operator-locked decision). The 3-pass strict variant is clean but has **no unique catch**: it
fires once in seventeen sprints, saves two passes — about **three minutes per sprint** — and Arm E
already stops that series one pass later. Decisive: **Arm E fired live exactly twice in 47 series, and
in 2 of 2 the very next pass reached 0C/0M.** In this corpus a plateau is not evidence the cycle has
stopped moving; it is evidence it is one pass from done. Killed on v0.253.0's own standard.

**THE OPERATOR'S MAJOR PROPOSAL IS STILL UNTESTED, and the backtest surfaced its main obstacle.**
There is no `findings_major_prior_scope` in the provenance schema — censused across all 185 pass files,
the only key containing "major" is `findings_major`, while `findings_critical_prior_scope` appears in
127. So the split cannot be computed from what producers emit today: re-tiering the
underived-but-unfalsified class needs the ADVERSARY to emit the distinction (a `team-roles/adversary.md`
change plus a schema field), not just a new validator arm. A check keyed on the absent field would read
empty forever and its silence would be indistinguishable from a clean corpus. Test the proposal, apply
v0.253.0's standard, and kill it if it has no unique catch.

**TWO DECISIONS ARE WAITING ON THE OPERATOR AND NEITHER BLOCKS BATCH 7.** The exit-code question
in `BL-078` (`EXAMINED NOTHING` is one token at three exit codes; unifying them is
consumer-visible, and three options are costed in the entry). And the compaction-durable rule
channel, measured at **43517 of a 43520-byte ceiling** — three bytes — so a new standing rule has
nowhere to go without cutting resident prose, which `resident-context.md` restricts to VESTIGIAL
text whose enforcing mechanism you can name. Two rules earned in batch 6 are parked on that:
a `$?` read after a SIBLING command substitution is the substitution's status, not the command's;
and a mutant keyed on a SPELLING is disarmed by any fix that normalises spellings, so key it on a
LOCATION.

**BATCH 7 SCOPING, RE-DERIVED AT `0f278685` AND STILL A HYPOTHESIS.** The operator ruled during
batch 6 that `BL-079` becomes batch 7 — it is a live false positive on the reference consumer's
s302 gate, and its remedy is a design change (a declared-population flag with SKIP semantics for
a sprint shipping no `locked-requirements.md`, plus a shared baseline that fires
did-not-reproduce 15 times at s302) which the entry says must be settled in one change. Adjacent
and same-family: `BL-076` (five sibling count-without-identity validators) and `BL-078`. The
three filed by batch 6 — `BL-081`, `BL-082`, `BL-083` — are a coherent alternative subsystem of
their own. Keep the batch to ONE subsystem.

**BATCH 4 IS COMPLETE, MERGED AND PUSHED AS `v0.377.0`.** Merge `5ecd136`, release `03be95f`, followed on `main` by `ce97b23` (a
`fixture-mutants.md` correction) and `26ea6ce` (a fixture-comment provenance correction). `main` is
at `26ea6ce` and `origin/main` matches it.
`BL-031`, `BL-035`, `BL-046`, `BL-050` and `BL-068` are annotated `**LANDED (v0.377.0, verified
867597a).**` and rotated. Open `BL-` entries **60 → 59** (five closed, four filed); archive
**9 → 14**. The gate was run the way the hook runs it on the branch AND again on the merged tree —
**160 fixtures, 160 ok, 0 FAIL, all 15 phases PASS, `pre-push: all gates green`** both times — with
the six changed fixtures read BY NAME against an impossible-name control returning nothing and a
present-name control returning 1, in the same invocation. `validate-release-version.sh`: one
release in the range. All five `PC-` ids resolve in the pushed release commit MESSAGE against an
impossible-id control of 0.

**FOUR OF THE FIVE ENTRIES WERE WIDER THAN FILED, AND THAT IS NOW THE BASE CASE RATHER THAN THE
EXCEPTION.** `BL-035` named one drifted close predicate and **four** had drifted across three
programs. `BL-050` named one undisposed status and **four** were undisposed. `BL-068`'s site list
missed **the message the tool PRINTS to the operator**, which is the most consequential of its
sites. Only `BL-031` was exactly as filed, and that was established by re-deriving its population,
not by reading the entry. **Send an independent hand at the SCOPE question every time; it paid on
four of five.**

**THE FIRST GATE EXITED 1 AND THE FIXTURE TALLY WAS 156 ok / 4 FAIL — FOUR RED UNITS, ONE CAUSE,
AND NOT ONE OF THEM WAS ABOUT ITS OWN SUBJECT.** `I77` fired on three shipped shell files tracked
`100644`, so `validate-enforcement-map.sh` exited 1, so every fixture that differentials against a
clean baseline correctly reported its own control dirty rather than reporting on it —
`layer-contract-conformance` and its `-b` sibling ("the UNMUTATED contract already fails — every
mutant below is unattributable"), `validator-arm-selection` ("the baseline this fixture
differentials against is already dirty"), and `validator-fork-budget`. **The mode loss came from
editing files with `> tmp && mv`, which drops the bit at the umask — the exact hazard I77's own
message names.** Fix with `git update-index --chmod=+x`, and check the bit after ANY edit that
rewrites a shipped script through a temp file.

**THE RECEIPT-DEFECT COUNT IS NOW FIVE ACROSS FOUR BATCHES, IN BOTH DIRECTIONS, AND TWO OF THIS
BATCH'S WOULD HAVE CERTIFIED THE WRONG FIX.** `BL-068`'s accepts ONLY the counter change this
repo's own CHANGELOG records as a removed regression — its corpus is `ledger-reverify.sh` and the
string `ledger-rotate` never appears in it, so both remedies the entry's prose calls legitimate
exit 1 forever. It was REPLACED with one driving the shipping rotator, proven four ways: fixed 0,
pre-fix 1, a silent stub 9, guidance deleted 1. `BL-050`'s closes on a sentence about a DIFFERENT
status, because `grep -F NAMED-UPSTREAM` matches inside `NAMED-UPSTREAM-AMBIGUOUS`, and on a
sentence RESTATING the defect. `BL-031`'s binds the escape's SYNTACTIC POSITION, so hoisting the
message into a variable satisfies it while the escape still emits. **Ask of every receipt: does a
correct fix satisfy it, what ELSE does, and can the CORRECT fix be one it rejects.**

**A FIXTURE REFUTED A CHANGE ITS OWN AUTHOR HAD JUST MADE, ON A RECOMMENDATION FROM AN INDEPENDENT
SCOPE HAND, AND THE FIXTURE WAS RIGHT.** Routing `ledger-rotate.sh`'s `susp_closed` through the
lifted anchored predicate turns a REAL entry into `REFUSING to rotate` — rc 0 → 1 — and a refusal
writes nothing. **The stuck rule and the refusal-suppressor FAIL IN OPPOSITE DIRECTIONS**: the
first makes a CLAIM, so looseness states something false and tightening is strictly correct; the
second SUPPRESSES a refusal, so tightness refuses real work. One rule cannot serve both. Reverted,
filed as `BL-071`. **Keep the fixture author a different hand from the arm's — it is the only
mechanism in this program that has ever told a session it was wrong about its own change.**

**A REFUSAL THAT IS NOT FATAL IS A SILENT CLEAN RUN, AND THIS BATCH SHIPPED ONE BEFORE REMOVING
IT.** `ledger_close_awk()` refuses when the close grammar is missing or not single-homed;
interpolated into an awk program that refusal became an EMPTY string, awk died on an undefined
function, and the caller exited **0 with no rows**. Measured rc=0/0 rows against rc=0/1 row when it
resolves. All three callers now compute the lift once behind `|| exit 2`. **When you make a helper
that can refuse, drive its refusal path and read the CALLER's exit, not the helper's.**

**TWO NUMBERS I RELAYED FROM A SCOPE REPORT WERE WRONG AND THE FIXTURE HANDS CAUGHT BOTH** — "five
copy sites" was one, and a claimed live defect had already been closed by my own fix. **A figure
from another session is a hypothesis until re-derived, including one you are merely passing on.**
The same rule bit on shipped prose: the `84 rows / 10 lines` consumer figure in `BL-068` did not
reproduce (12 rows, 2 lines, on a 2953-line ledger against the original's 4356), so the comments
now state the SHAPE and tell the reader to re-derive.

**Two independent hands, on two different batteries, measured the same thing: AN UNMUTATED CONTROL
PASSES AGAINST A SUBJECT REPLACED BY `exit 0`**, because rc=0 with no findings is exactly what a
clean copy looks like. The control is necessary and is NOT what stops silence scoring as a kill —
PRESENCE-shaped assertions are.

**FILED THIS BATCH, each receipt proven three ways before filing**: `BL-071` (the
refusal-suppressor, `verify: manual` because the two inputs a fix must separate are the same shape
on today's signals — an `sh` receipt would be a standard nobody can meet), `BL-072`
(`validate-no-dead-doc-refs.sh` reads 31 of 105 markdown files under `docs/`; the work is the
false-positive MEASUREMENT, not the glob change), `BL-073` (three telemetry reads carrying the
`BL-036` conflation, tiered NOTE), `BL-074` (the entry-line half of the close predicate, still a
hand-copy — deferred deliberately rather than landing a second runtime read into a release whose
fixtures three hands had just stabilised).

**BATCH 5 IS COMPLETE, MERGED AND PUSHED AS `v0.378.0`.** Merge `890b921`, release `6011d94`.
`main` is at `890b921` and `origin/main` matches it. `BL-058`, `BL-059`, `BL-061` and `BL-063`
all reported `CLOSE-CANDIDATE` on the merged tree under receipts that were REPLACED — see below —
and are now annotated `**LANDED (v0.378.0, verified 890b921).**` and ROTATED at `ac36bc1`.

**THE RELEASE SHIPPED WITHOUT THE ANNOTATE-AND-ROTATE STEP, AND WAS REPORTED AS COMPLETE
ANYWAY.** `v0.378.0` was cut, gated, merged and pushed with all four entries still sitting in the
live corpus at `CLOSE-CANDIDATE`, zero `**LANDED (v` annotations, and the archive still at batch
4's 14. The code was right and the bookkeeping the close procedure requires was simply not done;
it was caught only because the operator asked whether the batch was complete. **A `CLOSE-CANDIDATE`
row is the instrument saying the fix is present — it is not the close.** The close is the
annotation form the rotator keys on, and until it exists the entry is still open to every reader
and every count. Live 65 → 61, archive 14 → 18, 79 ids before and after with none in both;
`--check` PASSed before `--apply`, asserting every non-closed verdict byte-identical across the
rotation, and `backlog-reverify` now reports **0 CLOSE-CANDIDATE** against a live-entry control.
Re-derived after the push: **64 `BL-` entries — 56 `STILL-LIVE`, 4 `HAND-REVIEW`, 4
`CLOSE-CANDIDATE`**, against an impossible-id control of 0. The gate was run the way the hook
runs it on the branch AND again on the merged tree — **160 fixtures, 160 ok, 0 FAIL, all 15
phases PASS, `pre-push: all gates green`** both times, gate exit read directly — with the nine
changed fixtures read BY NAME against an impossible-name control of 0 and a present-name control
of 1, in the same invocation. All four `PC-` ids resolve in the pushed release commit MESSAGE
against an impossible-id control of 0.

**ALL FOUR RECEIPTS WERE DEFECTIVE. That is four out of four, and the count across the program is
now nine in five batches.** The polarities repeat rather than diversifying:

- **`BL-063`'s** closed on `[ "$s" -ne 2 ]`, which accepts rc 1 — and BOTH destructive remedies
  reach rc 1, because with the predicate deleted the run falls through to the next join and fails
  there. Deleting the guard scored as FIXED.
- **`BL-061`'s** asserted only that two arms both return 0, with NO arm anything must still DENY,
  so deleting the feature, neutering the citation check and making the branch unreachable all
  scored as FIXED — while REJECTING the PENDING/SKIP remedy `mechanism-design.md` permits.
- **`BL-059`'s** closed on a hardcoded constant, on an echoed argument, and on a fix that renders
  the path and then exits 1, because `O=$(...)` discards `$?`.
- **`BL-058`'s** REQUIRED THE DEFECT TO SURVIVE: it counted files still carrying the divergent
  spellings and demanded `n >= 2`, so a correct unification — measured live as the fix landed,
  3 → 0 — makes it exit 1 forever. **Third occurrence of the `BL-068` polarity.**

**THE REPLACEMENT RECEIPT IS NOT SAFE MERELY FOR BEING NEW.** An independently-authored
replacement for `BL-058` keyed on the vocabulary's NAME; the build named the set "empty-subject
verdict token", containing none of the words it looked for, and it rejected the correct fix — the
same polarity it was written to remove. Caught by driving it. **Key a receipt on facts a fix
cannot rename: emitter PATHS, exit codes, structural relationships.**

**TWO FIXTURES REFUTED THEIR OWN ARM'S AUTHOR, IN ONE BATCH.** `spec-join-integrity` found that
un-disarming Check 30 makes a pre-existing false positive REACHABLE — the LR population is a
whole-file scan, so an absent-id CONTROL TOKEN quoted in a consumer's prose becomes a finding.
`check-25-steering-conduct` found the steering fix INCOMPLETE: rendering only the members read
leaves an empty corpus naming no source, and a `--since` window excluding everything is the
invocation `retro.md` itself prescribes. Both were arms that would have shipped green. **Keep the
fixture author a different hand from the arm's; it is now 3-for-3 across batches 4 and 5.**

**FOUR OF THE FIGURES I PASSED TO DELEGATES WERE STALE OR WRONG, AND EVERY ONE WAS CAUGHT BY THE
DELEGATE.** The `DISARMED` "opposite polarity" claim (all 24 sites exit 2; the apparent `exit 0`
is an inner heredoc's, escalated to 1), the rendering-convention exemplars (both named files carry
0 label-column emitters), the "13 bare capability entries" (a MENTION count — three defensible
counting methods give 5, 8 and 13), and the ordinal qualifier shape (the producer has no ordinal
path; what looked like one is a free-text TYPE). **A figure you are merely relaying is still a
hypothesis.**

**FILED THIS BATCH, each receipt verified by me in both directions before filing:** `BL-075` (the
graph entry that arrived unadjudicated — HOLDS-WIDER; the consumer's own prescribed `\b` fix is a
TOTAL DISARM on bash 3.2, examining 0 markers over 354 files, and its own receipt accepted it),
`BL-076` (five sibling count-without-identity validators; `validate-ci-gates.sh` fails OPEN on a
wrong retro root, worse than the entry just closed), `BL-077` (derive the session's own corpus
rather than retyping an `ls -t | head -1` derivation in prose), `BL-078` (the wider empty-subject
population, 17 sites at 4 exit codes, with the exit-code decision laid out as three options for
the operator), `BL-079` (the LR-population scan; every narrowing that clears the false positive
loses genuine locked requirements, and the best candidate disarms the check).

**AWAITING THE OPERATOR: the exit-code question in `BL-078`.** `EXAMINED NOTHING` is now one token
at three exit codes (0, 4, 78) because unifying the codes is consumer-visible and was deliberately
not taken on this branch. Three options are costed in the entry.

**A COST TO WATCH BEFORE THE NEXT ARM LANDS.** `validator-fork-budget` profiles at **6850–6930
against a 7000 ceiling**, and the profile is not stable run to run. Two invariants landed this
batch (`I92`, `I93`). That fixture fails the push in BOTH directions, so the next arm should be
written for forks or the ceiling revisited.

### BATCH 6 — COMPLETE, SHIPPED AS `v0.379.0`. A RECORD, NOT AN INSTRUCTION. DO NOT RE-DO IT.

Merge `944085a1`, close `c31f52f4`. `BL-056` and `BL-060` annotated
`**LANDED (v0.379.0, verified 944085a1).**` and ROTATED — live 64 → 62, archive 18 → 20, 82 ids
either side with none in both, `--check` PASSing before `--apply`, and `backlog-reverify` back to
**0 CLOSE-CANDIDATE** against a live-entry control. Gate run the way the hook runs it on the
settled tree AND again through the push: **15 phases, 15 PASS, 0 FAIL, 161 fixtures ok, 0 FAIL,
0 SKIP**, exit read inside the hook's own shell both times, four changed fixtures read BY NAME
against an impossible-name control returning nothing. Both `PC-` ids resolve in the pushed commit
MESSAGE against an impossible-id control of 0.

**BOTH ENTRIES WERE ROUGHLY THREE TIMES WIDER THAN FILED, AND THE UNFILED HALF WAS THE WORSE
DIRECTION BOTH TIMES.** `BL-060` filed a false STRAY; underneath it was a **FALSE PASS** — a genuine
stray reached through a home prefix, opened, read, and then excused, because the home match was a
raw-string prefix test. `BL-056` filed one flagless call site; the fifth coupled site was a sprint
extraction reading the BASENAME, so a path-only migration yields a template carrying **ZERO** legacy
path sites that fires, filters, and then skips every step green.

**A MUTANT CAN BE SILENTLY DISARMED BY THE FIX IT GUARDS, AND IT GOES GREEN AT THE MOMENT IT STOPS
WORKING.** A substring mutant was keyed on a home substring that existed only because of where a
checkout SAT; root-relative normalisation is exactly the step that removes it. Post-fix the mutation
flipped no verdict and the arm would have reported a kill it did not earn. Key a mutant on a
LOCATION, never on a spelling. Found only by RUNNING the fix.

**ELEVEN RECEIPT DEFECTS IN SIX BATCHES.** `BL-056`'s arm 1 was an unconditional `exit 0` on a
substring — satisfied by a COMMENT, by a second call site with the defective one untouched, and by
`--require-skill` placed BEFORE the path (which makes the invocation exit 2 on every PR) — while
REJECTING a correct fix with the path hoisted into a variable. `BL-060`'s negative control was
spelled RELATIVELY while the defect is about ABSOLUTE spelling, so both remedies making `--strays`
blind to absolute paths scored as FIXED.

**A GATE RUN WHILE ANOTHER PROCESS WRITES THE TREE IS NOT A MEASUREMENT.** The first gate exited 1
with `crosswalk-home-declaration` FAIL under the pool; it passes standalone and passed on the
settled re-run. That fixture mirrors `core-manifest.md`, which this batch modified. The harness
notification for that run said **"exit code 0"** — the backgrounded wrapper's status — while
`GATE_EXIT=1`. Freeze every hand before the gate.

**FILED THIS BATCH**: `BL-081` (`receipt_absent_subjects` fabricating a consumer-relative path from
a `$DIST` rev-path, which refused a correct close on v0.378.0's own release), `BL-082` (case-variant
spellings, where every remedy opens a FALSE PASS on a case-sensitive consumer), `BL-083` (the
root-marker rule is distribution-shaped — an installed tree carries **0** `VERSION` files at any
depth, and the correct two-layout resolver already exists in the validators).

**AWAITING THE OPERATOR**: the exit-code question in `BL-078`, and the durable rule channel at
**43517/43520**, which has no room for the two rules this batch produced.

### BATCH 6 — THE ORIGINAL SCOPING NOTE, SUPERSEDED BY THE RECORD ABOVE

`BL-056` and `BL-060` were named as the obvious batch 6 at batch 5's scoping and neither has been
re-derived since. **Re-run `bash scripts/backlog-reverify.sh` before believing any count above.**
The batch-5 filings also give a coherent alternative subsystem — `BL-076` and `BL-078` are the
same family as what just shipped, and `BL-079` is a live false positive on the reference consumer
that this batch made reachable.

### BATCH 5 — COMPLETE, SHIPPED AS `v0.378.0`. A RECORD OF HOW IT WAS SCOPED, NOT AN INSTRUCTION. DO NOT RE-DO IT.

**GRAPH FILED TWO NEW ENTRIES DURING BATCH 4, AND ONE OF THEM IS NOT MIRRORED HERE.** The reference
consumer's live ledger moved under this program — md5 `c3b8ed13…` → `1f13c17f…`, 2953 → 3024 lines,
96 entry headings — by graph's own `chore(s303)` sprint-review commits, with a clean working tree
there. **This session never wrote to graph; the change is the consumer's own work**, which is the
state Phase 5 step 22 says to hand over rather than report completion over.

- `PC-S303-FANOUT-SCRIPT-ARG-MAX-VIA-EXPORTED-DIFF-ENV-VAR` — already mirrored here as **`BL-064`**,
  open, `STILL-LIVE`.
- `PC-S303-STUB-AUDIT-MARKER-REGEX-MATCHES-LOCAL-VAR-NAMED-STUB` — **NOT filed here.** It is a
  THIRD defect in `core/scripts/validate-stub-audit.sh`, distinct from `BL-055` (`:217`) and from
  `BL-058` (`:263`) — and `BL-058` is batch 5's anchor, so that file is open on the bench anyway.
  **It is NOT filed because it has not been adjudicated against this working tree**, and filing a
  consumer claim unverified is the thing this program exists to stop. Adjudicate it as part of
  batch 5 and file it, or hand it back with the reason.


**Re-derived at batch 4's close, on `26ea6ce`: 59 open `BL-` entries — 55 `STILL-LIVE`,
4 `HAND-REVIEW`, 0 `CLOSE-CANDIDATE`**, one row per entry, against an impossible-id control of 0.
Archive 14. **Re-run `bash scripts/backlog-reverify.sh` before you believe any of it** — batch 4
opened on a paragraph exactly like this one and `BL-046` had moved.

**There is no `CLOSE-CANDIDATE` to adjudicate, so batch 5 starts at the remediation step.** Run the
instrument anyway: an entry going `STILL-LIVE → CLOSE-CANDIDATE` between sessions has happened
twice in this program, and both times the RECEIPT had rotted rather than the defect being fixed.

**The batch: `BL-058`, `BL-059`, `BL-061`, `BL-063`.** All four confirmed `STILL-LIVE` on `26ea6ce`.
One subsystem, as step 13 requires — a validator whose verdict is about evidence it never opened,
or which refuses over an absence it cannot distinguish from a finding.

- **`BL-058` is the anchor, and it is a VOCABULARY defect.** Three validators spell "examined
  nothing" three ways at three exit codes — `AUDITED NOTHING` at 4, `PASS — NOTHING VERIFIED` at 0,
  `VACUOUS:` at 78 — and none of `docs/vocabulary-index.md`'s twelve vocabularies is this one.
  **The machinery for this landed in batch 4**: `docs/vocabulary-index.md` is DERIVED and
  byte-compared at pre-push, an arm declares its vocabulary with a `# vocabulary:` marker, and
  `I39` now has a fourth reader binding an ACTING region to a derived status set. Read that arm
  before designing this one. Note the hard part is not the register — it is that
  `gate-adjudication-verdict.json`'s `verdict` enum is exactly `PASS` `FAIL`, so a run that
  examined nothing has no verdict it can legally write.
- **`BL-059`** — `validate-steering-budget.sh` prints `transcripts scanned : N` and never WHICH,
  so a wrong-session run is byte-identical to a correct one. The entry records that its own filing
  was narrow in two directions and that `--dir` was added after it. This is a RENDER-the-evidence
  fix, and `mechanism-design.md`'s "render safety-critical output; do not let a model retype it"
  is the rule that governs it.
- **`BL-061`** — an EMPTY `--transcript-dir` is classified as forgery, so passing the flag with no
  transcripts WEDGES the pipeline while passing no flag at all fails open. The entry carries a
  three-arm end-to-end reproduction against the real validator. **This one can wedge live work, so
  `mechanism-design.md`'s "never ship a check that wedges live work or errors on correct data"
  binds the FIX as well as the defect** — PENDING/SKIP over FAIL for an absent corpus.
- **`BL-063`** — one `grep` at `validate-spec-join.sh:164` sits above every other join, so an
  optional `by <author>` qualifier takes down the whole of Check 30 at `exit 2`. **The entry states
  that its own filing's cause is FALSE and its blast radius understated** — read the entry, not the
  filing it quotes.

`BL-056` and `BL-060` are the `validate-provenance-block.sh` pair and are the obvious batch 6.

**Substitute freely if the re-derivation disagrees — but keep the batch to ONE subsystem, read each
receipt before building, and put an independent hand on the SCOPE question.** That hand was right
about the width on FOUR OF FIVE entries in batch 4; the one it was wrong about, it was wrong in the
direction of recommending a change a fixture then refuted.

### BATCH 4 — COMPLETE, SHIPPED AS `v0.377.0`. A RECORD OF HOW IT WAS SCOPED, NOT AN INSTRUCTION. DO NOT RE-DO IT.

**FIRST, ADJUDICATE `BL-046`. IT IS THE ONLY `CLOSE-CANDIDATE` AND IT MUST BE SETTLED BEFORE ANY
REMEDIATION.** Measured at batch 3's wind-down: **60 open `BL-` entries — 56 `STILL-LIVE`,
3 `HAND-REVIEW`, 1 `CLOSE-CANDIDATE`** — one row per entry, against an impossible-id control of 0.
Re-derive with `bash scripts/backlog-reverify.sh`; this paragraph is a hypothesis about a tree that
moves.

`BL-046` is *"neither pre-push hook scrubs git's worktree environment, so a push issued from a
linked worktree redirects 33 fixture sandboxes onto the real repository"*. **It went
`STILL-LIVE` → `CLOSE-CANDIDATE`, and this program has seen that exactly once before — `BL-070`,
where the RECEIPT was wrong rather than the defect being fixed.** Do not close it on the status.
What is established, and what is not:

- **Its receipt is a PRESENCE-ONLY TEXT ANCHOR**: `grep -qE '^[[:space:]]*unset[[:space:]].*`
  `GIT_OBJECT_DIRECTORY'` against both hooks. It asserts a line EXISTS, never that it runs before
  anything it protects.
- **The line really is there in both**, `unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR`
  `GIT_OBJECT_DIRECTORY`, so this is not the `BL-070` shape of a fix the anchor cannot see.
- **What is NOT established is SITING, which is the whole claim.** The scrub is at `.githooks/`
  `pre-push:758` of 788 lines and `core/git-hooks/pre-push:683` of 697, while the fixture-suite
  text appears at 180/187 and 242/253 respectively. **That proves nothing on its own** — a shell
  script defines functions early and invokes them late, so textual order is not execution order,
  and reading it as such is this repo's "text about a program is not the program". **Determine the
  RUNTIME order**, by instrumenting or by tracing the call, not by line numbers.
- **The commit that produced the current text, `7fa26f5`, is a COMMENT fix, and its own body says
  the previous comment asserted a safety property that DOES NOT HOLD** — a reviewer disproved it
  with a live counterexample, and it records "no line-count, siting, or behavior change". So the
  siting question has already been got wrong once in this exact file, in the direction of claiming
  more safety than exists.
- **Batch 1's third state applies**: a real absorption can still fail to close if the fixing commit
  promised work alongside it. Read `7fa26f5` in full, and whatever introduced the `unset` line, before closing.

**THEN CUT BATCH 4: the ledger CLOSE-CHANNEL family — `BL-031`, `BL-035`, `BL-050`, `BL-068`.**
All four confirmed OPEN and `STILL-LIVE` at batch 3's wind-down, one row each, against an
impossible-id control of 0. One subsystem, as step 13 requires: the annotate-then-rotate channel in
`ledger-rotate.sh` / `ledger-reverify.sh` and the step-8 status vocabulary that drives it.

- **`BL-031`** — `ledger-reverify.sh` emits its `ENTRY-SWALLOWED` detail with a literal
  backslash-`u2026` escape. **Batch 3 rewrote that exact arm and left the escape in place
  deliberately**, because changing it was not that batch's subject; the string is at the `emit`
  call at the end of the arm. This one is small and its subject is freshly understood.
- **`BL-035`** — `ledger-rotate.sh` reports an entry as "closed for re-verification" on an
  UNANCHORED phrase. Same file batch 3 added the refusal guard to.
- **`BL-050`** — step 8 forbids the annotation §3f instructs, and `NAMED-UPSTREAM` is a status it
  never reaches. This is the vocabulary half of the same channel.
- **`BL-068`** — `ledger-rotate.sh` states a byte-identical invariant that its own prescribed
  workflow breaks.

**Substitute freely if the re-derivation disagrees — but keep the batch to ONE subsystem, and read
each receipt before building.** Three receipt defects in three batches, in both directions: a
correct fix scored as work remaining (`BL-070`), a destructive fix scored as done (`BL-032`), and a
presence anchor that cannot see siting (`BL-046`, above). **Ask of every receipt both questions:
does a correct fix satisfy it, and what ELSE satisfies it.**

**THE GATE INSTRUMENT IS REPAIRED, WHICH IS WHY BATCH 2 WENT FIRST.** `suite-dispatch-order` no
longer sorts on measured wall-clock, so a red unit in your gate is now a finding about your own
change rather than a coin flip you have to argue with. If it goes red, do not re-run it.

graph pulled v0.373.0, merged it at PR #935, and applied sections A, B and E of the brief. **The
A6 ceiling question is also ruled and executed — see action 6; nothing is owed there.**

**Do these three things, in this order.**

1. **Derive the Phase 3 worklist from `docs/backlog.md`, never from a prose list in this file.**
   `bash scripts/backlog-reverify.sh` is the instrument, and every count in this file is a
   HYPOTHESIS about a tree that has moved. Measured at batch 2's wind-down: **64 `BL-` entries —
   61 `STILL-LIVE`, 3 `HAND-REVIEW`, 0 `CLOSE-CANDIDATE`**, one row per entry, against an
   impossible-id control of 0. (Batch 1's wind-down read 66 / 62 / 4 / 0; `BL-008` and `BL-070`
   are the difference.) **`BL-070` was the one entry this program has seen go
   `STILL-LIVE → CLOSE-CANDIDATE` because its RECEIPT was wrong rather than because its defect
   moved** — re-derive, do not carry a status forward. At ≤4 remediations a branch this is a program of many sessions:
   report after each branch and do not try to batch around the limit.
   **Its `sh` polarity is INVERTED relative to the consumer's engine**: here `rc=0` means the fix is
   PRESENT (`CLOSE-CANDIDATE`) and non-zero means STILL-LIVE. Read
   `scripts/backlog-reverify.sh:183-186` before writing a receipt, not this sentence.
2. **ADJUDICATE EVERY `CLOSE-CANDIDATE` ROW BEFORE REMEDIATING ANYTHING, and there are two ways
   that close loses data, not one.** A `CLOSE-CANDIDATE` means a receipt now reports its fix
   present — either a real absorption, or a receipt that ROTTED, and those are indistinguishable
   from the status alone. **Batch 1 found a third state: all three rows were real absorptions and
   one still could not close, because its fix had shipped with its GUARD OWED and the fixing commit
   said so in its own body.** So confirm two things against the tree, not one: that the fix is
   really there, and that whatever the fixing commit promised alongside it actually arrived. Read
   the fixing commit's message in full before closing on it.
3. **Confirm the read/write boundary.** `/Users/n8/git/graph` is READ ONLY. Record the ledger md5
   before your first action and assert it by CONTENT after every phase, never by the dirty count,
   which measures graph's activity and not your restraint.

**Then cut the next batch** — ≤4 remediations, one version per branch, from `origin/main`. Steps
13–16 carry the method; 14a–14c are the clauses learned the hard way and are not optional.

**BATCH 2 IS COMPLETE, MERGED AND PUSHED AS `v0.375.0`.** It closed `BL-008` and `BL-070` and
carried both carry-over items. The gate was run the way the hook runs it on the branch and again
on the merged tree — **158 fixtures, 158 ok, 0 FAIL** both times — with both changed fixtures read
BY NAME against an impossible-name control returning 0 and a present-name control returning 1, in
the same invocation. `validate-release-version.sh`: one release in the range. Open `BL-` entries
**66 → 64**; archive 3 → 5.

**THE FLAKE'S MECHANISM IS TIGHTER THAN `BL-008` STATES, AND THE CORRECTION MATTERS TO ANYONE
WRITING A COST-ORDERED ASSERTION.** The entry says a `sleep 0` unit OUTRANKS the `sleep 1` unit.
It never did — 0 inversions in 30 loaded repetitions. **It only has to reach a TIE**, because
`sort -k1,1nr`'s `-r` is KEY-SCOPED and tied keys fall through to a FORWARD whole-line
last-resort compare: `aaa 1 / mmm 1 / zzz 3` sorts to `zzz aaa mmm`, which is precisely the order
the entry reports, against an untied control sorting to `zzz mmm aaa`. A margin that makes an
inversion unlikely does not make a tie unconstructible, and only the second is safe.

**THE FIRST ATTEMPT TO REPRODUCE IT FAILED, AND THAT IS THE MORE USEFUL HALF.** A 6-vs-6
differential under 36 spinners on 18 cpus returned zero failures on BOTH sides — reported as no
evidence rather than as a pass, with the two sides asserted to differ first. **Spinners are the
wrong load**: what moves a worker's `$SECONDS` is `bash -c` STARTUP LATENCY, contended on PROCESS
CREATION, not CPU. A 96-way fork storm reproduces it at **1/20 against 0/30 unloaded**. Driving
only the record-writing run instead of the full width-1 replay is ~20× cheaper per repetition,
which is what makes a 1-in-20 event observable at all.

**Two `HOLDS` scope corrections, both found before building, both of the base-case kind this plan
predicts.** `BL-008` names one arm and two were exposed. **`BL-070`'s own receipt scored the
correct guard as ABSENT** — it anchored on `(bash|node)[^|]*gen-architecture-index` over the
fixture text, but **I33** forces a fixture to name both install layouts and resolve one into a
variable, so it invokes `node "$GEN"` and no line places an interpreter and the script's name
together. Re-anchored on behaviour, proven three ways in one invocation: no guard `rc=1`, **a stub
that names the script and exits 0 `rc=1`**, the real guard `rc=0`.

The original batch-2 statement of the problem, kept because the next batch is judged by the same
instrument:

**`BL-008` WAS SEQUENCED FIRST BY OPERATOR RULING BECAUSE IT CORRUPTS THE
INSTRUMENT EVERY OTHER BATCH IS JUDGED BY.** `suite-dispatch-order` sorts three toy fixtures by the
durations the PREVIOUS run recorded; under the pool those units take single-digit milliseconds and
their measured order is the machine's scheduler, not the ordering rule. So the gate reports a red
unit on a tree nothing is wrong with.

**Measured across five pooled gate runs in one session, on four different trees, none of which
carried a change that can reach fixture dispatch ordering: four `ok`, one `FAIL`.** The failing run
was a DOCS-ONLY commit touching a single file under `docs/plans/`. The same unit is green when run
alone, 11 assertions. That is roughly one poisoned gate in five, and every batch of this program
ends in a gate.

**The cost is not the re-run, it is what the re-run does to the evidence.** `BL-008`'s own entry
says it: *"a fixture that fails intermittently in the gate is the shape that gets re-run until
green, and a re-run-until-green unit certifies nothing."* A session that hits this while carrying a
real change has to prove a negative — that its own work could not have reached dispatch ordering —
before it can read its own gate. Batch 1 hit exactly that and had to spend the argument.

**The prescribed fix is in the entry**: stop sorting on real elapsed time in the assertion. Seed the
durations record with FIXED costs and assert the dispatch order those produce, so the arm measures
the ORDERING RULE rather than the machine's scheduler. Everything around it stays — the mutant
battery M1–M4 is sound and its control arm is what proves the hook is green on an unmutated tree.

**`BL-008` is `verify: manual` and its close is a HAND judgement, deliberately.** The entry states
why: a receipt that ran the fixture once would report whichever side of the race that run landed
on, which is the same coin-flip as the arm. Do not go looking for a receipt to turn green. **Once
the arm is seeded rather than timed the race is gone, so a mechanical receipt becomes possible and
writing one is a legitimate part of this remediation** — but it is an option the remediation earns,
not a precondition on it.

**BATCH 3 IS COMPLETE — SHIPPED AS `v0.376.0`. EVERYTHING FROM HERE TO THE END OF THIS SECTION IS
A RECORD OF WHY IT WAS SCOPED THAT WAY, NOT AN INSTRUCTION. DO NOT RE-DO IT.** It was the
ledger-parsing family, `BL-013`, `BL-032`, `BL-065` and `BL-036`; all four are annotated and sit in
`docs/backlog.archive.md`. The paragraphs below are kept because the NEXT batch is judged by the
same instruments and two of the warnings in them fired.

**All four were confirmed OPEN and `STILL-LIVE` at batch 2's wind-down**, one row each, against an
impossible-id control of 0 and a control confirming `BL-008` is absent from the open file and
present in the archive. All four carry `verify: sh`, so all four are exposed to the receipt defect
below. `core/skills/ai-dlc-update/reconcile/lib.sh:276` was re-checked in the same pass and still
resolves to `ledger_entry_shape`, the boundary rule. **These are still hypotheses about a tree that
moves — re-run the instrument, do not read this paragraph as the answer.**

- **`BL-013` and `BL-032` key on the SAME boundary rule**, `lib.sh:276`.
- **`BL-013`'s naive repair is measured WORSE than the defect** — a plain fence toggle drops 47 real
  entries on the reference consumer's ledger. Its entry names the two routes a fix may take.
- **`BL-065`'s entry records that the filing's own prescribed fix does not work**, and that half of
  it is silently inert under BSD `sed`. That is step 14b: run a prescribed fix before adopting it.

**BATCH 2 ADDED A FOURTH THING, AND IT BINDS ALL FOUR OF THESE ENTRIES: A RECEIPT CAN BE WRONG
ABOUT ITS OWN SUBJECT, IN THE DIRECTION THAT LOOKS LIKE WORK REMAINING.** `BL-070`'s receipt scored
a guard that was present, passing, and killing its own mutant as ABSENT — it anchored on
`(bash|node)[^|]*<script-name>` over fixture text, but **I33** requires a fixture to name BOTH
install layouts and resolve one into a VARIABLE, so the shipping guard invokes `node "$GEN"` and no
line in it ever places an interpreter and the script's name together. The anchor was a hypothesis
about what a fix would LOOK like, written before one existed.

**So a `STILL-LIVE` row is not evidence that the defect is live.** It is evidence that the receipt
did not exit 0, and those differ whenever the receipt anchors on TEXT rather than on BEHAVIOUR.
Before building a remediation for any of these four, read its receipt and ask what it would say
against a CORRECT fix — not just what it says today. A receipt that a correct fix cannot satisfy
will have you rebuild something that already works.

**Re-anchor on behaviour and prove it in BOTH directions**, which is what `BL-070`'s replacement
does: run the guard against the shipping subject and require PASS, then rebuild the subject's
neighbourhood in a `mktemp` root around the PRE-FIX blob and require the SAME guard to FAIL, with
`cmp -s` refusing if the two are not different. The decisive case is the third one — **a stub that
names the subject and exits 0 must NOT close the entry** — and it is the case a text anchor cannot
express.

**And a separation that makes a wrong answer UNLIKELY is not one that makes it UNCONSTRUCTIBLE.**
`BL-008`'s arm was ordered by a margin that looked ample and was not, because `sort -k1,1nr`'s `-r`
is KEY-SCOPED: tied keys fall through to a FORWARD whole-line compare, so the two units only had to
reach EQUALITY, never an inversion. Measured: 0 inversions in 30 loaded repetitions, and the arm
failed anyway. Any parsing fix in this family that picks a boundary "far enough" from a collision
is making the weaker claim.

**BOTH CARRY-OVER ITEMS ARE DISCHARGED IN `v0.375.0` AND NOTHING IS OWED. Do not re-do them.**
`e9c5970`'s CodeQL `js/incomplete-sanitization` fix now has its own CHANGELOG section, so it can
reach a consumer — verified uncited before it was written rather than taken from this file: the six
`gen-architecture-index` hits already in `CHANGELOG.md` are all v0.33-era delivery notes, and
`incomplete-sanitization`, `CodeQL` and `escape backslash` returned zero against a control of 34 for
`escape`. `BL-070` is REMEDIATED, not merely filed: `core/fixtures/architecture-index-cell-escaping/`
is a shipping fixture with a mutant arm, registered in `uninstall.sh` and both `core_manifest`
copies. Both entries are annotated and rotated into `docs/backlog.archive.md`.

**THE PIN IS DEAD AND SO IS EVERY LINE NUMBER KEYED ON IT. JOIN BY `PC-` ID.** See "Re-establish the
pin" below, which is now a post-mortem rather than a procedure. This costs you nothing for Phase 3,
because Phase 3 is keyed on `BL-` ids in `docs/backlog.md`, a file this repo owns.

**THE EXPECTED-OUTCOMES LIST IS SPENT. Kept only as the record of what was predicted and what the
prediction was worth**, because two of its six rows are the reason this section exists:

| predicted | what actually happened |
|---|---|
| `RECEIPTS-UNDECIDED 28 of 28` persists until section E is pasted | **EXACT.** It now reads `5 of 5`. |
| ~10 entries report `NEEDS-REVIEW` where a `CLOSE-CANDIDATE` was earned | **WRONG AS STATED, AND THE ERROR WAS MINE.** Measured 0, and 0 is correct. Two preconditions went unstated: the population is section E of the BRIEF, not the ledger, and `receipt_absent_subjects` is unreachable at `rc=0` (`ledger-reverify.sh:1017-1027` — the `0)` arm emits STILL-LIVE and returns). The consumer nearly filed a defect against a correctly-behaving engine on my say-so. **A PREDICTION HANDED TO ANOTHER PARTY WITHOUT ITS PRECONDITIONS IS A FALSE FINDING WAITING TO BE FILED.** |
| 7 `NAMED-UPSTREAM-AMBIGUOUS` rows | Exact at the time; now 5 after the drain. |
| pin 4216 needs a hand-chosen version | Correct. Annotated v0.373.0 by hand. |
| an annotated entry vanishes from the report | Correct, by design. |
| an annotated entry is skipped AND never archives | Did not occur — the strict form held across all 56 annotations. |

0. **THE MERGE AND THE PUSH ARE DONE, AND SO IS STEP 21. Nothing in this action is owed** — it is
   kept because the credential mechanism below is not recorded anywhere else, and a session that has
   to push will need it.
   `main` carries the v0.373.0 release and all of Phase 4. The gate was run the way the hook runs it
   twice, green both times — **157 fixtures, 157 ok, 0 FAIL** — with all six fixtures changed on the
   branch read BY NAME against an impossible-name control returning 0 and a present-name control
   returning non-zero, in the same invocation. `validate-release-version.sh` PASSes over the range.

   **The push identity is project-scoped now, and the mechanism is worth knowing before you touch
   it.** `git push` used to fail **403 as `ats0012_amway`**, which has no write access to this
   remote; `gh api repos/euron8/ai-dlc` reports `push: false` for that account against `push: true`
   for `euron8`, control in the same invocation. `.git/config` now sets
   `credential.helper` to `~/.gh-credential-euron8` — a helper that shells out to
   `gh auth token --user euron8` at each use, so it stores no secret and picks up a rotation
   automatically — plus `credential.https://github.com.username euron8`, and an empty
   `credential.helper` entry ahead of it to reset the inherited global `osxkeychain` helper. That
   config is LOCAL, so other repos keep their own default.

   **Two ways this bites, both measured here.** A `core.askpass` script that calls `gh` hangs git
   indefinitely, and `GIT_TERMINAL_PROMPT=0` does NOT make it fail fast — if git wedges with no
   output, that is the shape; use the credential helper, not askpass. And
   `git push --dry-run | tail` printed `exit=0` over a push that really exited **128**, because this
   shell has no `PIPESTATUS`. **Read a push's status without a pipe.**

1. **Re-establish the pin** (see "Re-establish the pin", below). It held across this entire session:
   graph `HEAD` is still `510e4d9f5`, the live ledger is 4503 lines, and `sed -n '1,4356p'` reproduces
   `2fd444dcf406cdff728fe3c0c4352267` with the 4355-line control differing. Verify anyway; it is one
   command and every line number in the register depends on it.

2. **PHASE 4 IS DONE. Nothing is owed here. Read this only to know what changed under you.**

   **Step 19's real population was 42 receipts, not the 14 this action used to describe.** The step
   covers "each of the 28 undecided `theirs_has` receipts" AND "every open entry the Phase 0
   residual showed carries no directive at all", and only 14 had been drafted. Joining
   `adjudicable-entries.tsv` against `final-disposition.tsv` over the LIVE rows: **18** carry
   `theirs_has`, **22 carry NO DIRECTIVE AT ALL**, and 2 of the 3 post-pin entries carry none
   either. The no-directive class is the quieter half and the worse one — `flush()` gates on
   `has_verify &&`, so those entries emit no row in any reverify report: not open, not closed, not
   needing review, invisible to the closer. A zero CLOSE-CANDIDATE count over a corpus holding 22
   of them means nothing, which is the same shape as the finding that started this program.

   All 42 exist, and coverage is JOINED rather than asserted: the 42 receipt pins against the 42
   owed pins have symmetric difference **EMPTY**, with a control confirming the comparison fires on
   a one-line mutant. 37 measure `rc=0`; 5 are `verify: manual`, each naming the structural fact
   that blocks a predicate rather than the difficulty of writing one; every `sh` receipt carries the
   `exit 127` guard.

   **`extract-receipts.sh` is new and is the ONLY parser of the batch markdown.** Eight arms, each
   probed both directions. Two of its rules were learned from the corpus and matter to anyone
   adding a batch: the `rc` column is MEASURED by running the receipt, never parsed out of the
   prose — `step19-receipts/batch-3.md:123` states "measured rc=1 today" about an ABSENCE arm inside
   a section whose receipt measures 0 — and the `label` column comes from the census, never from the
   batch heading, because `batch-3.md:186` abbreviates its own label by five words. Its probe found
   its own arm-ordering bug: a tab inside a receipt was caught by the verb arm rather than the tab
   arm, so the tab arm now runs first and the file says why.

   **`run-receipts.sh` no longer parses the markdown.** It reads the TSV, re-runs every receipt
   independently, and asserts both that each measures zero and that it AGREES with the recorded rc.
   Its coverage arm is a COUNT of pin headings rather than a parse, so a batch file that gained a
   section the TSV does not carry cannot pass.

   **Three defects were in the promoted Phase 4 machinery, all found by running it:**

   `render-brief.sh` derived the step-12 population from the AUTHORING SESSION'S SCRATCHPAD under
   `/private/tmp/…/<uuid>/scratchpad`. It still existed, so it still worked. When it stops existing
   nothing errors: the script sets `-u` but not `-e`, so a glob matching nothing feeds `awk` no
   files, the population derives to ZERO pins, and sections B, C and D all mis-partition while the
   arithmetic line still prints a sum. It now reads the promoted `filing-population.tsv`, verified
   symmetric-difference EMPTY on field 2 against the scratchpad copy while that still existed, with
   fields 1 and 3 differing by 67 and 118 as the control that the comparison discriminates.

   **Section E's polarity prose was INVERTED for its own subject.** It read "Every one was RUN and
   exits non-zero today … a receipt exiting 0 now is already broken" — `backlog-reverify.sh`'s
   sense, in a section whose receipts are read by `ledger-reverify.sh`. The brief would have told
   graph that all fourteen working receipts were broken and that a false close was the correct
   state. Section C's identical wording is CORRECT and stays, because C is about upstream's own
   `docs/backlog.md`. **The two engines' senses sit four hundred lines apart in one generated file;
   check which engine a paragraph is about before trusting its polarity.**

   **A new arm, ARM 4b, refuses when two batch sections claim the same pin.** Added when three
   authoring agents looked silent and replacements were about to be written to different filenames.
   Two files covering one pin emits two rows for one entry, the brief renders the pin twice with
   different receipts and no statement of which is current, and the coverage count still balances
   because it counts headings.

   **Section F is new** — the three post-pin entries, outside the 115-row partition by construction,
   joined to `BL-063`–`BL-065`. The join FLATTENS the entry body first, because `line 4357, past the
   4356-line pin` wraps in this hard-wrapped file; control in the same invocation, an impossible
   line number joins to nothing.

   The brief renders at **A=39 B=18 C=41 rows/42 entries D=17 E=42 F=3** and the A–D partition
   closes at 115. `render-brief.sh --check` and `extract-receipts.sh --check` both pass.

   The superseded sub-actions, kept only because their evidence is cited above:

   **2a. Build `docs/reviews/graph-ledger-adjudication-data/replacement-receipts.tsv`.** The 14
   replacement receipts are DRAFTED, RUN and PROMOTED, but they are still prose in four per-batch
   files under `graph-ledger-adjudication-data/step19-receipts/batch-{1,2,3,4}.md`. The renderer needs
   them as a TSV with columns `pin / label / old / new / rc / note`. Extract them; do not retype them.
   **Re-run `step19-receipts/run-receipts.sh` after extracting** — it executes every receipt under the
   engine's own exported environment (`DIST`/`BASE`/`THEIRS`/`CONSUMER`) and every one must report
   `rc=0`, which is STILL-LIVE for the consumer engine. Its controls are built in, and it REFUSES
   with exit 2 if any batch file is absent rather than reporting a clean run over nothing.

   **All 14 are verified as of `a47233d`**: `rc=0` each, with `exit 127` guards throughout (6/5/5/5),
   controls firing both ways in the same invocation. **Two of the four batches were promoted in a
   pre-correction state and re-promoted at `92e8bed`** — I snapshotted them while their authors were
   still revising after the polarity correction reached their inboxes. If you touch these files,
   `cmp -s` the promoted copy against whatever you think is current before trusting either; batches 2
   and 4 were byte-identical then, which is what made the comparison believable.

   **2b. Render the brief.** `graph-ledger-adjudication-data/render-brief.sh` writes
   `docs/reviews/graph-ledger-adjudication-brief.md` and has a `--check` mode. It carries three arms,
   all proven able to fire: it tests the annotation string it generates against BOTH enforcers, it
   refuses if the versionless near-miss ALSO passes the strict form, and it refuses outright while
   `replacement-receipts.tsv` is absent rather than emitting a brief that promises a section it lacks.
   Sections A–D partition the 115 exactly — **39 CLOSE + 18 WITHDRAW + 41 LIVE-tracked + 17
   consumer-local**; section E cuts across C and D.

   **2c. Add the three post-pin entries to the brief.** They are NOT in `final-disposition.tsv`, so
   the renderer cannot see them; their verdicts are in `post-pin-verdicts.tsv`. See action 3.

3. **`BL-063`–`BL-065` ARE FILED (`b4e7f17`). This step is DONE.** The three post-pin entries were
   the last unfiled live entries in the program. They were missed for a STRUCTURAL reason: step 12's
   population came from the corpus pin — the ledger's first 4356 lines — and graph filed these after
   the pin was taken, so every derivation downstream inherited that boundary. The coverage check that
   confirmed all 59 population rows were accounted for was CORRECT and said nothing about these.

   Found by asking a different question: do any backlog entries cite a pin above 4356? Zero did,
   against a control confirming 42 cite pins below it. **When a population is derived from a pinned
   snapshot, ask separately what the pin excluded** — a complete-looking coverage proof over the
   population cannot see outside it.

   All three verified from the tree rather than from the authoring agent's account: 64 reverify rows
   for 64 entries, zero `unresolved`/`vacuous`/`INPUT-UNRESOLVED`/`ENTRY-SWALLOWED`, rotator ok, and
   each cites its own post-pin line (4357 / 4392 / 4435) so the join to the consumer resolves. They
   correctly exit NON-ZERO — the ai-dlc polarity, opposite to the fourteen consumer receipts.

3b. **A DEFECT in the shipped engine that costs 10 of the 42 receipts their mechanical close, and a
   RE-DISPOSITION owed on pin 4216. Both were found by the authoring agents, after their batches
   landed, and neither is in the safe-to-ignore category.**

   **`receipt_absent_subjects` CANNOT DISTINGUISH A PATH THE RECEIPT READS FROM ONE IT MERELY
   MENTIONS. That is the general form, and it is wider than the unanchored-regex framing below.**
   The harvest is a `grep -oE` over the receipt's RAW TEXT, so it collects a `mktemp` scratch root, a
   git exclude pathspec, or any incidental literal exactly as it collects a real subject. Measured
   over all 37 `sh` receipts, the class splits three ways and only two are defects:

   - **10 WITHHELD today** — the distribution-path case detailed below.
   - **2 FALSE-COUPLED**, passing only because the harvested path happens to exist. Pin 334 embeds a
     `mktemp` scratch root spelled `.claude/skills/ai-dlc/extensions`; **pin 267 carries
     `':(exclude).claude/worktrees'`, a git PATHSPEC it is asserting should be IGNORED.** Excluding a
     nonexistent directory is a no-op by construction, so that receipt stays perfectly decisive while
     its close is withheld anyway.
   - **4 that LOOK contingent and are the guard working correctly** — pins 226, 252, 255, 259 spell
     `$CONSUMER/.claude/skills/…` where the path IS the entry's subject, and each receipt's own
     `exit 127` agrees with the engine. The function's header records that a `$CONSUMER/`-prefixed
     spelling is normalised precisely so the two forms cannot disagree about one file.

   **Split the class before calling it a defect** — doing so took this from 6 affected to 2, and the
   sharpest instance came from an authoring agent RETRACTING its own earlier all-clear. A delegate's
   correction is where the finding is.

   **The narrow case, which is the 10:** at
   `core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:502-515` the
   extraction is `grep -oE '(\$CONSUMER/)?(docs|_bmad-output|scripts|\.claude)/[A-Za-z0-9_./-]+'` —
   **unanchored** — so a receipt naming `core/scripts/x.sh` yields the match `scripts/x.sh`, which is
   absent under the consumer root, and the caller then withholds the CLOSE-CANDIDATE as
   NEEDS-REVIEW. Measured by lifting that function verbatim and running it over every `sh` receipt
   in `replacement-receipts.tsv`: **10 of 37 affected** — pins 654, 673, 798, 1069, 1093, 1136, 1240,
   1381, 4184, 4313. Controls both directions in the same invocation: a genuinely present consumer
   path (`scripts/ai-dlc/artifact-path-config.sh`) is NOT withheld, and `core/scripts/`
   `validate-locked-anchor.sh` IS.

   **The direction is SAFE and that is why this is a DEFECT rather than a BLOCKER.** The function's
   own header says its caller uses it "to WITHHOLD a CLOSE-CANDIDATE, never to produce one", so the
   cost is that those ten entries need a hand review they should not have needed. No false close.

   **The remedy is one character of indirection, in the receipt and not in the engine**: write
   `S="$DIST/core/scripts"; V="$S/validate-x.sh"` so no literal `core/scripts/…` substring exists for
   the guard to extract. Verified to extract zero paths. Fixing the engine's regex would be the
   better repair but it cannot reach graph until graph pulls, and the brief must be actionable under
   the engine graph has installed TODAY.

   **Pin 4216 wants re-dispositioning to the ADOPTED UPSTREAM channel, cited at 0.373.0.**
   `final-disposition.tsv` still reads `LIVE (close withdrawn) / brief-annotation / no-receipt`,
   written before `9cbb77f` landed. All three surviving sub-claims are now closed and the fixture
   PASSes with by-name arms for each. **The version cannot be 0.372.0**: that is the release whose
   close the refuter overturned, and it is the id's only CHANGELOG cite (`CHANGELOG.md:485`).
   `9cbb77f` wrote NO CHANGELOG entry at all — four files, none of them `CHANGELOG.md` — so the
   0.373.0 section does not name this id and a hand-chosen annotation is the only correct channel.
   Its receipt is already `verify: manual` carrying that reasoning, which is a safe holding state,
   so this is an accuracy improvement to the brief and not a live hazard.

3a. **Two NOTES from the post-pin filing, neither blocking, both worth seeing before writing another
   receipt.**

   **A receipt's own sanity failure is INVISIBLE.** `scripts/backlog-reverify.sh` maps any non-zero
   exit to `STILL-LIVE`, so a receipt that dies at its own `exit 9` guard — subject missing,
   extraction empty, harness broken — reports identically to one that measured a live defect. The
   direction is safe and the silence is not: a receipt can rot into permanent uselessness and every
   run will keep saying "still reproduces here". The consumer's engine distinguishes this (126/127 ->
   NEEDS-REVIEW); ours does not. Filing a distinct status is a candidate for a later pass.

   **`BL-064`'s receipt has a stated dependency**: its diff leg needs `git diff HEAD~1` to be
   non-empty. True today and while `HEAD~1` differs from the tree, but if that ever went empty the
   diff signature would read 0 for a reason unrelated to any fix. Its corpus leg is unaffected, so
   the receipt degrades to half-strength rather than false-closing. Recorded in the entry.

4. **PHASE 5 STEP 21 IS RUN AND DONE-WHEN 5's MECHANICAL HALF IS SATISFIED: 25 of 25.** Run from the
   graph root against the pushed `origin/main` — `bash .claude/skills/ai-dlc-update/reconcile/`
   `ledger-reverify.sh /Users/n8/git/ai-dlc adec9ae /Users/n8/git/graph 5c96500`, exit 0, cwd asserted
   to be the CONSUMER root and never the distribution root. The full output is promoted at
   `docs/reviews/graph-ledger-adjudication-data/step21-reverify-at-0.373.0.log`, byte-identical to the
   run, **because this measurement is PERISHABLE** — an annotated entry emits no row, so once graph
   applies the brief it can never be taken again.

   Every one of the 25 closes whose `final-disposition.tsv` channel is `changelog-cite` — the set
   DERIVED from the channel column, not hand-listed — emits a `NAMED-UPSTREAM` row: **25
   NAMED-UPSTREAM, 0 degraded to NAMED-UPSTREAM-AMBIGUOUS, 0 with no row**, against an impossible-id
   control at 0 and a known id at 2 in the same invocation. **Before the release commit named the ids
   in its MESSAGE, 21 of these 25 produced no row at all.** The run's histogram: 58 STILL-LIVE, 33
   NAMED-UPSTREAM, 25 HAND-REVIEW, 7 NAMED-UPSTREAM-AMBIGUOUS, 1 RECEIPTS-UNDECIDED, 1
   CLOSE-CANDIDATE. The consumer was untouched — ledger md5 identical either side of the run, graph
   `HEAD` still `510e4d9f5`.

   **The other half of done-when 5 — the 14 `brief-annotation` closes — is carried by the renderer's
   own arms, not by this run, and correctly so:** a `NAMED-UPSTREAM` row cannot exist for them
   (`flush()` gates on `has_verify &&` and `named_absorbed()` rejects a non-id-shaped label), so the
   criterion is that the brief renders the exact strict string and the rotator would archive it.
   `render-brief.sh` arm 1 tests the string it generates against BOTH enforcers and refuses if the
   versionless near-miss also passes the strict form.

   **`RECEIPTS-UNDECIDED` still reads 28 of 28**, and that is expected rather than a regression: the
   replacement receipts live in the BRIEF and graph has not applied them. That line is what closes
   when graph pastes section E.

   **Step 22 is DONE.** Step 22 is
   DONE and was re-verified again at wind-down: the pin reproduces, graph `HEAD` is unchanged, and
   the 147 post-pin lines are the three entries above plus one `RETRACTED` banner — **no new consumer
   filings during this run**. Step 21 re-runs `ledger-reverify.sh` from the graph root against the
   new ai-dlc `origin/main`, which now carries the release. Run it BEFORE anything else.

   **Its observation point is BEFORE graph applies any annotation from the brief** — an annotated
   entry is skipped and emits no row, so once graph pastes the section A and B annotations the
   criterion is permanently unreachable and no rerun recovers it. The brief is written and sitting in
   `docs/reviews/graph-ledger-adjudication-brief.md`; the moment it is delivered, this window closes.

   **Do not substitute the local `main` for `origin/main` in that run.** The criterion exists to
   observe what the CONSUMER's engine will see, and the consumer fetches `origin`. A run against a
   local ref no consumer can reach reproduces the shape this plan spent a phase removing.

6. **RULED AND DONE. NOTHING IS OWED HERE — read it only to know what changed under you.**

   **The operator ruled: raise A6 AND land the trade, both.** Executed. The ceiling went
   **40960 → 43520**, the 384 defensible vestigial bytes were cut, and **all seven prose-only rules
   now have a durable carrier**: three delegation hazards in `.claude/rules/tool-hazards.md`, four
   verification rules in `.claude/rules/verification-discipline.md`. A6 reads **43164/43520**.

   **Raising while leaving defensible vestigial prose resident is the decorative outcome the
   ceiling's own header warns about, so the raise and the trade were taken TOGETHER.** The two cuts
   were the `I88` misattribution narrative and the hand-typed-enumeration provenance — each with its
   mechanism named, its instruction authoritatively elsewhere, and its inbound references grepped
   with a control in the same invocation.

   **THE CEILING WAS RULED TWICE AND THE SECOND TIME IS THE LESSON.** 43008 was approved against my
   ESTIMATE that the rules needed 1300–1600 bytes. Written at the terseness where each still carries
   the measurement that justifies it, they needed **2628**, landing 156 over the ceiling just
   approved for them. **The estimate was the error, not the rules** — so the ceiling moved again
   rather than the prose being ground down to fit a number invented before it existed, which is the
   same reasoning behind the FIRST raise. **An estimate of prose you have not yet written is a
   hypothesis; cost it after drafting.** Recorded in the arm's own header.

   The superseded analysis, kept because its measurement is what made the decision:

   **SEVEN prose-only rules now have no durable carrier, not three.** The four below, plus three this
   program added after they were written:

   - **A PREDICTION HANDED TO ANOTHER PARTY WITHOUT ITS PRECONDITIONS IS A FALSE FINDING WAITING TO
     BE FILED.** The `NEEDS-REVIEW` row above, handed to the consumer without stating that its
     population was an unapplied document and that the guard is unreachable at `rc=0`.
   - **A COUNT READ OFF A RENDERING IS NOT A DERIVED COUNT.** Two instances: a report's own summary
     sentence counted as a data row, and a disagreement tally counted by eye off a printed table.
   - **A CONTROL MUST BE RUN AGAINST THE INPUT THAT DISCRIMINATES, AND ASSERTED TO DISCRIMINATE ON
     IT, BEFORE ITS RESULT IS READ.** Measured six times in one pull; see the closing section.

   **THE TRADE, DERIVED AND NOT ESTIMATED.** A6 reads **40920/40960 across 7 files — 40 bytes**. The
   defensible vestigial set, applying `resident-context.md`'s three clauses literally, is **487
   bytes** (C1, the `I88` misattribution narrative at 205B; C3, the hand-typed-enumeration provenance
   at 282B), or **818B** including a qualified candidate that is only worth taking bundled with
   repointing two plan citations. The seven rules need roughly **1300–1600B**. **82% of `CLAUDE.md`
   and 100% of the six rulebooks fail at least one clause**, and the single block large enough to
   close the gap alone (1778B) is the one whose declared enforcer is *the reader*.

   **`scripts/validate-claude-rules.sh:288-305` sets the order of operations and puts the last resort
   with the operator**: mechanize first, scope second, raise the ceiling last. Both prior remedies are
   now exhausted for all seven — none is mechanizable (each fires inside a tool call or is a judgement
   about a population), and `resident-context.md` bars scoping a prose-only rule because scoping
   deletes it from every session that has compacted once. Suggested sizing if the ceiling moves:
   **40960 → 43008**, which leaves ~1000B of real headroom after all seven land with C1+C3 applied.

   **A rule whose only carrier is a plan file dies with the plan.** These are carried by this action
   and by the memory corpus, which is EVIDENCE and not a carrier — a compacted session has not read
   it. The original three, as recorded when they were found:

   **The third is that AN UNTRACKED FILE IS NOT A MISSING FILE.** A check built on a committed
   corpus — `git ls-files`, `git show HEAD:`, anything greping a tree — cannot see an uncommitted
   file, and its clean run reads exactly like a real absence. Measured here: three delegated batch
   files were declared missing while sitting on disk as `??`, one of them recorded in a commit
   message as "never written". Before declaring a delegated deliverable missing: `ls` the path,
   `git status --porcelain` for a `??` row, and ask the agent by name. **`grep -rniE`
   `"uncommitted|untracked|ls-files"` over the durable channel returns 0** — established with
   POSITIVE controls in the same invocation, `PIPESTATUS` at 1 and `compaction` at 12, because a
   zero checked only against another zero establishes nothing. It is the same class as `CLAUDE.md`'s
   measured false-zero list and belongs beside it.

   **The second one is a tool hazard and it has cost real work twice.** `sleep` under the Bash
   tool's `run_in_background` **returns immediately**, so a chain of backgrounded "waits" is rapid
   polling that grants a delegated agent no wall clock at all. Measured here: several apparent
   ten-minute waits spanned about one minute of real time, four authoring agents were described as
   silent when they had barely started, and one agent's work was redone inline as a result. Wait with
   a blocking `until` loop on the condition instead. **`grep -c "sleep"` over the durable channel
   returns 0**, against a control of 1 for `PIPESTATUS` — present — and 0 for an impossible token, so
   the gap is measured rather than assumed. Its evidence is in the memory corpus under
   `ai_dlc_v0372_four_push_candidates` and `ai_dlc_v0373_phase4_42_receipts`, which is EVIDENCE and
   not a carrier: a compacted session has not read it.

   **Its natural home is `.claude/rules/tool-hazards.md`**, whose subject is exactly "behaviours
   that return a WRONG answer rather than an error" and which already carries the `PIPESTATUS` and
   `grep -q`-from-a-pipe cases. It cannot be mechanized — nothing in a tracked file expresses it,
   because it happens in a tool call — so by `resident-context.md` it must NOT be scoped, and the
   unconditional channel is the only option.

   **The first one**, unchanged from when it was recorded: this session
   found that **a coverage proof over a derived population cannot see outside it** — step 12's
   census came from the corpus pin, so the check confirming all 59 rows were accounted for was
   CORRECT and structurally blind to the three entries filed after the pin. That is a sharpening of
   `verification-discipline.md`'s existing "Ask what SET a number was taken over", and it belongs
   beside it.

   **None of the three is there, because the durable channel has 40 bytes of headroom** — arm A6
   reports 40920/40960 across 7 files, re-derived at wind-down. Between them the three rules need
   roughly **1300 bytes**. Adding either requires TRADING OUT existing prose, and `resident-context.md`
   forbids trimming for cost and requires grepping for inbound references before any cut. That is a
   deliberate decision, not a mechanical one.

   Today rule one is carried by action 3 of this file, rule two by action 0's hazard note, and rule
   three by the paragraph above — adequate for this program and for nothing else. **A rule whose only
   carrier is a plan file dies with the plan.** The three options, none of which a session may take on
   its own authority: trade out ~1300 bytes of prose that meets the VESTIGIAL test (mechanism
   nameable, instruction authoritative elsewhere, inbound references grepped); raise A6's 40960
   ceiling, which is a budget decision; or accept that all three stay uncarried and will be relearned.

   **All three were learned the same way in one session, which is itself the argument for spending
   the bytes**: each cost real work, none is mechanizable — two happen inside a tool call and the
   third is a judgement about a population — and `resident-context.md` forbids scoping a prose-only
   rule, so the unconditional channel is the only place any of them can live.

5. **PHASE 3 IS THE ONLY REMAINING WORK AND THE HOLD IS RELEASED. Cut branches.**

   **Ruled by the operator after the pull closed**, with one condition attached: adjudicate the 3
   `CLOSE-CANDIDATE` rows before remediating anything. The hold's original reason — a Phase 3 release
   moves `origin/main` while the consumer is mid-pull — expired at graph's merge.

   **The expiry did NOT lift it; the operator did, and that distinction is the reusable part.** A
   standing ruling outlives the argument that produced it. `operator-rulings.md` puts scope with the
   operator, so a session that finds a hold's stated reason spent must ASK rather than reason its way
   out of the hold.

   **DERIVE the worklist; do not read one.** `bash scripts/backlog-reverify.sh` over
   `docs/backlog.md`. Measured at wind-down: **68 entries — 61 `STILL-LIVE`, 4 `HAND-REVIEW`, 3
   `CLOSE-CANDIDATE`**, impossible-id control 0. The `BL-021`..`BL-069` span covers the original
   `HOLDS` set, the three post-pin entries, and the four defects the pull itself produced. **Any
   count in this file is a hypothesis; the command is the answer.**

   **Adjudicate the 3 `CLOSE-CANDIDATE` rows FIRST.** Each means a receipt now reports its fix
   present — either a real absorption, or a receipt that rotted. This program measured both, and the
   data-losing direction is treating the second as the first.

   **Then, per batch:** ≤4 remediations per release branch, one version per branch, cut from
   `origin/main` and never from a local `main` that may be ahead of it. Steps 13–16 carry the method,
   and 14a–14c are the ones that were learned the hard way: a `HOLDS` gets an independent hand on its
   SCOPE, the filing's prescribed fix is RUN before adoption, and the guarding fixture is read first
   and expected to be blind.

   **Done-when 6 is ALREADY SATISFIED** — "every entry is either remediated and cited, or filed as a
   `BL-` entry". So Phase 3 is sequencing, not a blocker on closing this plan.

**AN UNTRACKED FILE IS NOT A MISSING FILE, AND I DECLARED THREE BATCHES MISSING THAT WERE ON DISK.**
The authoring agents wrote their batch files and left them untracked, as instructed. Two separate
mistakes compounded: a backgrounded `sleep` returns immediately here, so three "waits" spanned about
a minute of real time rather than the long silence they were reported as; and a check that cannot see
an uncommitted file reads exactly like one reporting a real absence. `batch-12.md` was recorded in a
commit message as "never written" — **that claim exceeded its evidence.** A direct `ls` returned
ENOENT when it ran, and the agent reports the file on disk at 08:50; the two cannot be reconciled
from here, so the record should say the file was absent WHEN CHECKED, not that it never existed.
Before declaring a delegated deliverable missing: `ls` the path, `git status --porcelain` for a `??`
row, and ask the agent by name.

**`run-receipts.sh` really did iterate `for i in 1 2 3 4`** — verified at `2db4035:24`, exactly as an
agent reported — so over a partial batch set it would have reported a clean run across four files
while ignoring the rest. The rewrite to a TSV-driven runner removed it, and the current runner
reports `42 receipt(s) from 12 batch file(s)`. Recorded because the finding was RIGHT about a version
that existed, and a reader comparing it against the current file would otherwise conclude the agent
was wrong.

**Three things this session learned that will cost a fresh session real time if forgotten.**

**A count with no join to anything else is a count nobody can falsify.** The step-12 commit reported
"17 withdrawn", derived as 59 rows minus 42 entries — a subtraction assuming one entry per row. Pin
262 drew two entries, and one entry cites a section banner before its own subject. It went unnoticed
until the brief, whose sections must partition 115 exactly, summed to 114. The real figure is 18, and
41 + 18 = 59 closes where the wrong one never did. Corrected in `d6d34c6`.

**Its mirror image, in the same hour: a probe reported that 18 of 42 entries stated no pin line, and
that was FALSE.** `pinned ledger line <N>` WRAPS across lines in a hard-wrapped file, and a
single-line `grep -oE` cannot see it. All 42 state their pin. Flatten the body before matching. Both
failures are one class from opposite sides — an instrument's shape deciding a number that then reads
as a finding about the corpus.

**An idle notification is still not a result, and this session re-confirmed both halves.** Yesterday's
`fix-bl009`/`fix-bl011`/`fix-bl012` fired idle notifications hours late; all three were UNREACHABLE
(`No agent named … is reachable`) because their session was gone, and the tree had been clean at
`95e421a`, so they had left nothing behind. But this session's own agents all delivered when ASKED,
and two of them delivered their most important finding only in the report, never in the file — the
`verify: sh` polarity inversion among them. Ask before concluding, and ask before redoing.

**An agent going quiet in this session did NOT mean it had died, and acting on that assumption cost a
full duplicate pass.** Six adjudicators reported hours late, in one burst, after their work had been
redone inline; two fixture authors never reported at all yet had written complete, passing fixtures to
disk. So: before redoing a delegated task, `git status` for its output and `SendMessage` the agent by
name. An idle notification is not a result, and silence is not death.

**What landed in the session that CUT THE RELEASE, and what each is worth:**

| commit | what | evidence state |
|---|---|---|
| `cb94a43` | BL-011's cross-hook legend arm + 5-mutant battery; the `I77` mode bit | fires on the REAL pre-fix hooks, one FAIL, differential sides asserted to differ |
| `74430c0` | BL-012's receipt could not tell the fix from the defect; DO-NOT-BUILD reasoned | FP set empty over 5 rewordings vs 2 offenders |
| `158d752` | step 12 — 42 backlog entries `BL-021`..`BL-062`, 18 withdrawals promoted | all 41 `sh` receipts RUN, evaluator controlled both ways |
| `953e39e` | BL-009's guard reduced to the half with a bounded FP set | FP set ENUMERATED at one member; unguarded half stated in the fixture |
| `e939a92` | **release v0.373.0**, 29 ids cited in the CHANGELOG *and* the commit message | commit-message join went 9/29 → 29/29, impossible-id control 0 |
| `d6d34c6` | corrected step 12's withdrawal count, 17 → 18 | partition now closes: 39+18+41+17 = 115 |

**A guard was NOT built for BL-009's procedure half, and that is a decision with a measurement
behind it rather than an omission.** Its arm keys on the token `quer` plus a closed list of send
verbs, and 3 of 5 legitimate rewordings fire — "request shape", "transmits", "introduces" all
preserve the instruction and all trip it. That false-positive set is an open class of legitimate
English, which `CLAUDE.md` forbids shipping. A future sweep could delete the query-shape step and
nothing would catch it; the fixture says so in its own header so its green line cannot be read as
covering it.

**The earlier session's table, kept because its findings still stand:**

| commit | what | evidence state |
|---|---|---|
| `40770c3` | 39 register ids repaired; verdict table now RENDERED with a `--check` | proven both directions |
| `b222017` | the naive fence fix would drop 47 entries; one entry carries the odd fence | measured |
| `16d93f4` | the three post-pin entries adjudicated | re-derived |
| `2c5d691` | six late agent reports reconciled; one overturned a verdict of mine | re-derived |
| `d50859d` + `a572e42` | `backlog-rotate.sh` refuses a ledger it would corrupt | FP set empty; 5 mutants, all killed |
| `b0e523b` + `6abef95` | `wait-for-deliverable` chained-sibling false NON-DELIVERY | end-to-end mutant kills; ONE over-broad mutant leaves the branch RED |
| `2951644` | short-id fallback anchored and archive-aware; 4 misattributions withdrawn | measured, fixture 78/78 |

**Two things a resuming session must not mistake for done.**

**Both fixtures now exist — this paragraph previously said they did not, and that was true for about
an hour.** `6abef95` gives `b0e523b` the deterministic end-to-end arm it was owed, from a different
hand, and its decisive mutant reads
`gating the SAMPLE on MAY_SLEEP declares a demonstrably working teammate non-delivered`. `a572e42`
gives `d50859d` a battery of five mutants, all killed, plus an eight-shape near-miss set.

What remains on those two is **only** the entangled mutant at action 0 above. In particular the
original worry — that `b0e523b` rested on a `bash -x` trace because the outcome harness printed the
same line for both builds and could not be made deterministic (pre-seeding the counter collides with
the grant path's rewrite at `wait-for-deliverable.sh:487` and the PENDING loop's re-read at `:586`) —
is **discharged**: the delegated fixture achieved determinism where the inline harness did not.

### Adjudication result — 115 entries

`ALREADY-FIXED` 41 · `HOLDS-MECHANISM-WRONG` 22 · `NOT-UPSTREAM` 16 · `HOLDS` 15 ·
`HOLDS-WIDER` 14 · `FALSIFIED` 4 · `DUPLICATE-OF` 3

### Refutation result — all 48 closes attacked

`CLOSE-CONFIRMED` 24 · `CLOSE-NARROWED` 15 · `REFUTED` 9

**Half the closes did not survive.** Final: **76 live** (67 plus 9 whose closes were withdrawn),
**24 close cleanly**, **15 close only once a named sub-claim is filed first**.

### Where the data lives — READ THESE FIRST ON RESUME

A session scratchpad is session-scoped and unreachable from a fresh session, so the per-entry
evidence was promoted into the repo:

- `docs/reviews/graph-ledger-full-adjudication.md` — the register: method, controls, cross-cutting
  findings, and the 115-row verdict table.
- `docs/reviews/graph-ledger-adjudication-data/phase1-verdicts.tsv` — 115 rows,
  `line / id / verdict / subsystem`.
- `.../refutation-verdicts.tsv` — 48 rows, `line / outcome / why`, one per attacked close.
- `.../final-disposition.tsv` — the merge, 115 rows.
- `.../merge-verdicts.sh` — recomputes it. **An unattacked close renders `CLOSE (UNVERIFIED)`,
  never `CLOSE`** — "nobody checked" and "checked and survived" must not read alike.
- `.../adjudicable-entries.tsv` — the Phase 0 census both passes are keyed on.

### THE PIN IS DEAD. DO NOT RE-ESTABLISH IT — JOIN BY `PC-` ID.

**This section is a POST-MORTEM, not a procedure. Every line number in the register and the brief is
now unresolvable, and running the recipe below will not tell you that — it will hand you a blank
line or the wrong entry.**

Measured at wind-down: the live ledger is **2953 lines** and still moving, down from 4719, because
graph applied the brief — 56 annotations, 42 receipts, and a rotation that archived every closed
entry. **`sed -n '1,4356p'` now returns the WHOLE FILE**, so the old pin md5 check does not fail
loudly; it silently compares the entire file against a digest of a prefix that no longer exists.
Pin 4285, which was a valid mapped offset one revision earlier, is past EOF. 47 `## PC-` entries
remain live against an archive of 6491 lines; control, an impossible id returns 0.

**Join by `PC-` id.** Every live entry carries one, the ids are stable across rotation, and the
archive keeps the closed ones under the same id.

**THIS COSTS PHASE 3 NOTHING**, which is the reason no replacement mapping is offered. Phase 3 is
keyed on `BL-` ids in `docs/backlog.md` — a file this repo owns and rotates itself. The pin only
ever served ADJUDICATION, and adjudication is complete.

**The lesson, which outlives the pin.** The reconstruction survived two `HEAD` moves and then died,
and the sequence is the point:

1. **Append-only held, and was checked.** `sed -n '1,4356p' | md5` reproduced against a 4355-line
   control that differed. Correct every time it was run.
2. **Then a rotation deleted from the MIDDLE** — `@@ -610,28 +609,0 @@` — and the recipe became a
   `-28` shift above line 637, derived from `git diff --numstat` and hunk offsets rather than
   guessed, verified both ways.
3. **Then the full drain invalidated even that**, because the file is now shorter than the pin.

**An append-only assumption is not a property of a file. It is a property of what the consumer
happens to be doing, and it stops being true the moment the consumer acts on your own output.** The
durable instruction was never a line total: it is `--numstat`'s deletion count and the hunk offsets,
and better still an id that does not move at all.

Verified in both directions in one invocation: pin 4313 resolves at 4285 to
`PC-S303-BUDGET-CHECK-EVIDENCE-FIND-PICKS-A-STALE-GATE-LOG` while line 4313 now holds unrelated
prose; pin 4184 resolves at 4156; and pin 297, below the deletion, is unchanged. The archived entry
appears exactly once in the archive against an impossible-id control of 0, carrying the strict
`**ADOPTED UPSTREAM (v0.373.0, verified …)**` form. Its id still returns 2 hits in the LIVE file —
both are MENTIONS, at pin 177's cross-reference and inside graph's new entry, not the entry itself.
**Grep the id and you will conclude the rotation failed.**

**The superseded recipe, and the reason it worked until it did not:** every graph change had been a
pure append, so the pin was the live file's first 4356 lines, checked by
`sed -n '1,4356p' | md5` = `2fd444dcf406cdff728fe3c0c4352267` against a 4355-line control that must
differ. That held for the whole program and reproduced at `2c7935e5d`. **An append-only assumption
is not a property of the file; it is a property of what the consumer happened to be doing.** The
moment the consumer acted on this program's own output, it stopped being true — so the durable
instruction is the `--numstat` deletion count and the hunk offsets, never a line total.

**Everything after line 4356 is new work, and on resume it was ADJUDICATED.** 147 lines: three
entries plus one `## RETRACTED` banner in which graph withdrew its own `--brief` filing as a lead
invocation error — that one owes no upstream work and is not an entry. All three verdicts are
`HOLDS`-family, so all three are LIVE and none needed a refutation pass. Evidence is in the
register's "Three entries filed after the pin" section and
`graph-ledger-adjudication-data/post-pin-verdicts.tsv`:

| live line | entry | verdict |
|---|---|---|
| 4357 | `PC-S303-SPEC-JOIN-MEMLOG-REGEX-STALE-VS-AUTHOR-SUFFIX` | `HOLDS-MECHANISM-WRONG` |
| 4392 | `PC-S303-FANOUT-SCRIPT-ARGV-OVERFLOW-ON-LARGE-DIFF` | `HOLDS-WIDER` |
| 4435 | `PC-S303-SCOPE-CONFIRMATION-FIELD-OF-MISSES-BOLD-MARKDOWN-GRAMMAR` | `HOLDS-WIDER` |

**So the live set is 79, not 76** — 76 from the pin plus these three. Two of the three carry no
receipt, so Phase 4 step 19 owes them one. All three are also `HOLDS-MECHANISM-WRONG`-or-`WIDER`,
which is 3 for 3 on the base rate.

**The subagent channel is UNRELIABLE here, in a way that reads as death.** Six agents across two
batches each ran, went idle, and delivered nothing at the time — so the three entries were adjudicated
inline. All six then delivered **hours late**, in one burst. Two of them overturned the inline verdict
on the third entry, correctly. The lessons a later session needs:

- **An idle notification is not a verdict.** Never let one stand in for a result, and never
  reconstruct what an agent "probably found".
- **Do not assume a silent agent is a dead agent.** Ask it for its report before redoing its work;
  a `SendMessage` to a named agent resumes it from its transcript.
- **A second hand is worth the delay.** The inline pass called
  `PC-S303-SCOPE-CONFIRMATION` a plain `HOLDS` "exactly as filed" and missed a harsher second
  grammar, a prescribed fix that does not work, and a BSD-`sed` no-op. Phase 1's own lesson —
  every close needs an independent hand — extends to `HOLDS` verdicts wherever the SCOPE decides the
  remediation.

### The four decisions are RULED. None is open.

1. **`PC-S297-LOCKED-ANCHOR-VALIDATOR-VACUOUS` (pin 1069) — RETIRED ON RULING.** The exemption is
   correct by design: `core/scripts/validate-locked-anchor.sh:16-18` scopes the byte-match to a
   `full_text_source:` full-text claim, and `:20-26` records that a `requires_context:` load pointer
   **is** resolved for existence. Byte-matching a load pointer would fail honest cite-by-reference.
   No upstream work; the brief carries the reason so graph can retire it.
2. **Full sweep, unchanged — drain all 76.** Scope is not renegotiated by a measurement. Keep cutting
   ≤4-remediation release branches until the `HOLDS` set is empty, reporting after each.
3. **`BL-009`, `BL-011`, `BL-012` jump the queue and are fixed in the close release.** They are live
   defects in already-shipped code, not queued innovations, and two return a WRONG answer rather than
   a missing one. They are gated on no sub-claim, so they add no dependency.
4. **Done-when 5 is narrowed, and the 14 non-citable closes route through the brief.** See the
   amended criterion. The closes all still land; only the evidence differs.

### Two blockers were found on resume and are FIXED

Both were in the promoted register data, not in the adjudications.

- **39 of 115 register ids were abbreviations of the ledger's label, 17 on rows bound for the
  CHANGELOG.** A citation drafted from them would have named ids that exist nowhere and closed
  nothing, silently. Repaired by joining against the Phase 0 census; the verdict table is now
  RENDERED by `docs/reviews/graph-ledger-adjudication-data/render-register-tables.sh`, whose
  `--check` byte-compares and is proven to fail on an in-region edit, a deleted row, a changed TSV
  row and a misspelled marker.
- **`merge-verdicts.sh` exited 2 and recomputed nothing** — it named `refute-all.tsv` and
  `verdicts.tsv`; the committed files are `refutation-verdicts.tsv` and `phase1-verdicts.tsv`.
  Repaired, it reproduces the disposition table byte-identically. It now also derives the **close
  channel** from the census, so the two gates below cannot be forgotten.

**A close has two channels and only 25 of the 39 can use the mechanical one.** A `NAMED-UPSTREAM`
row needs a `verify:` receipt (`ledger-reverify.sh:647` gates on `has_verify &&`) AND an id-shaped
label (`named_absorbed()` rejects any label with a character outside `A-Z0-9-`). 14 closes fail one
or both. They close via the brief's strict `**ADOPTED UPSTREAM (v<digit>` annotation, which
`ledger-rotate.sh` archives with no receipt test anywhere in it.

The two tables that follow are the superseded planning-session estimates, kept because the
false finding in them is instructive. **Do not act on their numbers.**

**Two tiers, and only the first is trustworthy.** The upper block is what the shipping
`ledger-reverify.sh` emitted. The lower block comes from parsers written in the planning
session, and one of those parsers produced a finding that has already been shown false.

| from the shipping tool | value |
|---|---|
| distinct entries it emitted a row for | 89 |
| `STILL-LIVE` rows | 59 |
| `HAND-REVIEW` rows (`verify: manual`) | 25 |
| `NAMED-UPSTREAM` (upstream history already cites the id) | 13 |
| `NAMED-UPSTREAM-AMBIGUOUS` (sprint prefix, 2–17 entries each) | 9 |
| `theirs_has` receipts the tool itself calls undecided | **28 of 28** |
| `NEEDS-REVIEW` | 0 |
| `CLOSE-CANDIDATE` | 0 — **and the tool says not to read that as evidence** |

**Control:** these counts reproduce graph's own run, recorded at
`/Users/n8/git/graph/_bmad-output/ai-dlc-update/reconcile-report.md:218-265`, which is the
evidence that the invocation was right and not merely that it ran.

| from a subagent census — **hypotheses until re-derived** | value |
|---|---|
| raw entry starts matched by the boundary rule | 142 |
| section scaffolding, not entries | 18 |
| already closed on the ledger's own annotation grammar | 19 |
| **OPEN** | **93** |
| open entries citing an ai-dlc path that does not exist at HEAD | ~14 |
| of those, `PC-S312-*` entries targeting the **consumer's own forked `scripts/`**, not core | 9 |

**A planning-session parser produced a false finding, and the failure is the useful part.** A
hand-rolled `awk` reported that two section headings had absorbed a `verify:` receipt belonging
to the entry below them. The shipping parser emits **no row for either heading** — control: a
known id returns 2 rows in the same invocation. The tokens that `awk` matched are
`verify: theirs_has` written inside ordinary prose, which reverify's directive parser correctly
ignores and which this ledger's own header already names as a known hazard. **A hand-written
probe is a second implementation whose bugs nobody finds.** Derive the census from the shipping
code, per Phase 0 step 3.

**The two parsers also disagree about the `push_candidate: true` extension bullets** — the
hand-rolled one counted the 12 `extensions/…-push.md` roster rows as entries, the subagent
classified them as scaffolding. The ledger's own header says that whole section was **"owed, not
done"** as of its last full pass, which argues they are entries. Resolve this at Phase 0 step 4
by reading the section, not by picking a parser.

**A live graph session is filing into this ledger while you work.** At planning time there was an
uncommitted 44-line addition (`PC-S303-BUDGET-CHECK-EVIDENCE-FIND-PICKS-A-STALE-GATE-LOG`) that
is not in graph's `HEAD`. Pin the corpus at Phase 0 and re-derive the delta at Phase 5.

## Verdict vocabulary

Two vocabularies exist and they are not the same. The **machine** statuses
(`STILL-LIVE`, `HAND-REVIEW`, `NEEDS-REVIEW`, `CLOSE-CANDIDATE`, `NAMED-UPSTREAM`,
`NAMED-UPSTREAM-AMBIGUOUS`, `RECEIPTS-UNDECIDED`) are inputs, never verdicts. The **adjudication**
verdict is what this program produces, and it follows the precedent in
`docs/plans/sprint-302-303-push-candidates.md:81-88`:

| verdict | evidence required | disposition |
|---|---|---|
| `HOLDS` | the defect re-derived against the working tree at a named sha, `path:line`, with a control in the same invocation | remediate upstream |
| `HOLDS-WIDER` | as above, plus what the filing understates | remediate at the true scope |
| `HOLDS-MECHANISM-WRONG` | as above, plus the filing's stated cause or consequence shown false | remediate the real defect; record the correction |
| `ALREADY-FIXED (vX.Y.Z)` | the release that fixed it, named, with the fix read in the tree — **not** from the CHANGELOG | close by CHANGELOG citation |
| `FALSIFIED` | the premise shown false in the tree, with a control | close by CHANGELOG refutation |
| `DUPLICATE-OF <id>` | both bodies read; the surviving id named | close by CHANGELOG citation of the dropped id |
| `NOT-UPSTREAM` | no upstream grain fits; consumer-local by nature | brief only, no upstream work |

**Adjudicate the MECHANISM, not the claim.** A defect can be real while the filing's stated cause
and consequence are both false, and the last cycle found three of four filings materially wrong
about why. **Do not trust the filing's prescribed fix** — one of them was itself broken.

## Phases

### Phase 0 — promote this file, then pin the corpus

0. ~~Promote this plan and commit it.~~ **DONE** — this file is the promoted copy.
1. ~~Pin the corpus and record the consumer baseline.~~ **DONE** — see the status record above.
2. Re-run `ledger-reverify.sh` from the graph root as shown in **Start here**, base `adec9ae`,
   theirs = current ai-dlc `origin/main`. **Control:** the row counts must reproduce graph's own
   `_bmad-output/ai-dlc-update/reconcile-report.md:218-265`. They did in planning; a divergence
   means the corpus moved and Phase 0 restarts.
3. Derive the open-entry census **from the shipping code, never from a fresh parser.** Source
   `ledger_entry_awk()` from `core/skills/ai-dlc-update/reconcile/lib.sh:274` for the boundary
   rule, and reuse `ledger-reverify.sh`'s own close predicate `entry_line_closes()`
   (`:629-631`) and its directive parser rather than restating either. The planning session
   restated them and produced a false finding within the hour. Run every `awk` under `LC_ALL=C`;
   the ledger is full of em-dashes and a byte-truncating `substr` aborts the program mid-file.
4. Reconcile the census against the tool's 89 emitted rows and **account for the difference by
   name**. The residual is the set of entries the closer cannot see at all — the ones with no
   directive — and that set is the real reason a zero-close reading means nothing. Section
   headings that are not entries belong in the residual too; classify them explicitly rather
   than letting them inflate the count.

### Phase 1 — adjudicate every open entry (subagent fan-out) — **COMPLETE**

**Steps 5–9 are DONE.** They are retained because the method is what a later pass reuses, not
because work remains in them. What the run added, and what a repeat must keep:

- **Every close needs a second, independent hand.** Half failed. Every place a first-pass agent
  wrote "I hesitated here", a verifier found the defect there — so instruct agents to record their
  hesitation, and aim the verifier at it.
- **`CLOSE-NARROWED` is the verdict a lazy confirmation misses.** Fifteen closes were right about
  their headline and would have buried a live finding no other entry owns. Ask for it by name.
- **Give the verifier the specific weak point**, not a generic "check this".


5. Partition the open entries by the ai-dlc subsystem they target. A planning-session census
   produced this split — **re-derive it, do not trust it**:

   | subsystem | entries |
   |---|---|
   | reconcile machinery (`core/skills/ai-dlc-update/reconcile/*`) | 26 |
   | `core/scripts` validators | 20 (+3 filed under pre-relocation paths) |
   | `core/skills/ai-dlc` rules and steps | 21 |
   | consumer-local `scripts/` — the `PC-S312-*` retirement probes | 9 |
   | `core/git-hooks` and `core/hooks` | 7 |
   | `ai-dlc-update` SKILL.md and steps | 5 |
   | `core/fixtures` | 2 |
   | role files and templates | 2 |

   Batch at **~4 entries per subagent**, one subsystem per batch so a subagent reads one area.

5a. **Take the cheap closes first.** ~14 open entries cite an ai-dlc path that does not exist at
   HEAD, and they split two ways. Nine `PC-S312-*` entries cite the **consumer's own forked**
   `scripts/check-*.sh`, `scripts/lib/pr-class.sh`, `scripts/tests/**` — none of which core has
   ever shipped — so they are `NOT-UPSTREAM` by construction. The rest are **stale path forms,
   not dead entries**: `core/.claude/skills/…/retro.md`, `core/scripts/ai-dlc/…`,
   `tests/fixtures/…` are all pre-relocation spellings of live files, and an entry whose subject
   moved needs a repoint, **not** a close. Do not conflate the two — a close on a repointable
   entry is the data-losing direction.

5b. **Two receipts are green for the wrong reason and must not be read as passes.**
   `PC-S297-GUARDED-MERGE-PROVENANCE-INDIRECT-INVOCATION` and `PC-S297-FFCLUSTER-SHA-STALE` both
   carry `verify: sh ! git cat-file -e <path>`, and both paths are absent from core, so the
   receipt exits 0 on absence rather than on a fix. `PC-S296-H1-FIXTURE-CITATION-GAP` greps for
   the literal `tests/fixtures/check-3b-locked-anchor` in a tree that relocated to
   `core/fixtures/` — it can never match. Verify each against the tree before verdicting.

5c. **One open entry has no heading and no id** (around ledger line 2028): its title was absorbed
   into a fenced block that opens mid-entry, so `ledger-reverify.sh` cannot join it to anything.
   That is a live instance of the `ENTRY-SWALLOWED` class the ledger itself documents. Adjudicate
   its body like any other entry, and record the parser instance in the register.
6. **Spawn one adjudication subagent per batch, in parallel, in a single message.** Each returns
   one verdict row per entry: id, verdict, `path:line` evidence, the control run in the same
   invocation, and what the filing got wrong and in which direction. Give every subagent the
   verdict vocabulary above and the `consumer-boundary` prohibition verbatim.
7. **Every `ALREADY-FIXED`, `FALSIFIED` and `DUPLICATE-OF` verdict gets a second, independent
   verifier subagent whose brief is to REFUTE the close.** Those three are the data-losing
   direction: a false close retires a live defect and reads exactly like an ordinary absorption.
   `HOLDS` verdicts need no second pass — the cost of a false HOLDS is wasted work, not lost work.
8. Write the register to `docs/reviews/graph-ledger-full-adjudication.md`. One row per open
   entry, no exceptions — a missing row is indistinguishable from an entry nobody looked at.
9. The `push_candidate: true` extension blocks have **never been re-derived** since 2026-07-21.
   The ledger's own header says so — *"Owed, not done in this pass"* — and says why
   `layer-drift.sh` cannot answer the absorption question for them: its `EXTENSION-OK` arm
   compares only `base..theirs`, so a block absorbed several releases ago reports OK. Adjudicate
   them per block against core at HEAD like any other entry. **Do not use `layer-drift.sh` as the
   oracle** — that is the same check-cannot-fire trap this pass exists to find.

### Phase 2 — the close release — **PAUSED BY THE OPERATOR, one step in**

**RESUME HERE.** The next action is to finish drafting `BL-009`–`BL-033` and land them, because 15
of the closes are gated on their sub-claim being filed first.

**The backlog list is 22, not 25, and it must be DERIVED rather than recalled.** Three of the
original 25 were ruled fixes rather than filings (decision 3), and two of those three are already
fixed. **Do not work from a prose list** — derive the set from
`docs/reviews/graph-ledger-adjudication-data/final-disposition.tsv` (rows whose disposition contains
`sub-claim` are the 15 gated ones) plus `post-pin-verdicts.tsv` for 3 more. Each gated sub-claim
carries its measured evidence in `refutation-verdicts.tsv`, keyed on the pin line, so the work per
entry is a RECEIPT THAT FIRES rather than a fresh derivation of the defect.

**The 15 gated sub-claims, by pin line:** 273 the producer-surface evidence procedure; 281 two
template files the install glob cannot reach; 387 the divergent flow-log legends; 610 a merged
duplicate whose retirement would delete the only mechanical anchor either entry has; 1254 Check 4's
unreachable PASS; 1449 a bold bullet that splits an entry while `ENTRY-SWALLOWED` fires only on a
colon; 1543 a multi-line plain scalar rendered as one line that reads as a complete reason; 1862
`wait-for-deliverable`'s chained sibling — **FIXED in `b0e523b`**; 3190 three catalog entries outside
the detector with no `NOT-CHECKED` status; 3375 no detector deriving retired paths; 3464 the shipped
schema still naming the blocking row; 3507 the archive-blind short-id fallback — **FIXED in
`2951644`**; 3787 the wrapper discarding `CORE-AT-THEIRS`; 3828 `effort_bound` with no readers; 4153
the budget summary reading three of six channels.

**Plus the three post-pin entries**, all live, all needing a receipt — two carry none at all:
`PC-S303-SPEC-JOIN-MEMLOG-REGEX-STALE-VS-AUTHOR-SUFFIX`,
`PC-S303-FANOUT-SCRIPT-ARGV-OVERFLOW-ON-LARGE-DIFF`,
`PC-S303-SCOPE-CONFIRMATION-FIELD-OF-MISSES-BOLD-MARKDOWN-GRAMMAR`.

**Still owed as FIXES, not filings:** the recovery gate not arming on a bare-basename step file, and
the gate treating a partial read as a full one.

**Each needs a receipt that can fire.** The two failures this program measured, both of which will
recur: an anchor on text **the fix quotes back** (fixes here document what they removed, so the
anchor survives inside the comment recording the change), and an anchor on a **phrasing the filing
invented** rather than one the code uses. Grep the anchor before committing to it, and run the
receipt — one that exits 0 today is already broken.

**Settle while drafting `BL-033`:** the consumer's rotator split an entry mid-fence and left the
archive permanently short five paragraphs. This repo's own `docs/backlog.md` is rotated by the
forked sibling `scripts/backlog-rotate.sh`. If the same boundary blindness is there, the file about
to grow fourfold carries the identical hazard.

**Then the release itself:**

10. One release. `VERSION` bump, matching commit subject, one `## [X.Y.Z]` CHANGELOG heading, and
    **one `###` section per closed id, each naming the `PC-` id verbatim.** Arm C of
    `scripts/validate-release-version.sh` limits a push range to one version *heading*, not one
    section, so every close in the program can ship in this single release.
11. Include the `NAMED-UPSTREAM` set. Read each named commit and decide absorbed vs. rejected vs.
    split vs. passing mention — the tool's own header records that the author of that status got
    all four wrong in the release that shipped it, so this is a reading, not a lookup. Re-cite the
    confirmed ones so graph gets a current, unambiguous row. Resolve the
    `NAMED-UPSTREAM-AMBIGUOUS` prefixes the same way, per entry.
12. Land the accepted-but-not-yet-shipped `HOLDS` entries into `docs/backlog.md` as `BL-` entries
    in the same release, so nothing is carried only in a plan. That file's grammar and receipt
    verbs (`sh` / `has` / `lacks`, never `theirs_*`) are stated in its own header at
    `docs/backlog.md:19-40`.

### Phase 3 — remediation releases

13. Group the `HOLDS` set by subsystem into batches of **≤4 remediations per release branch**.
    One version per branch, cut from `origin/main` — a squash of two takes the first version in
    the subject and breaks the release triple. Expect **many** branches; the operator has asked
    for the full sweep, so keep cutting them until the `HOLDS` set is empty.
14. Per batch: **one subagent drafts each remediation, and a different subagent authors its
    fixture.** `.claude/rules/fixture-mutants.md` requires the fixture's author be a different
    hand from the arm's — an arm and a battery from one hand encode one understanding twice and a
    false pass has an unreachable half nobody sees. The last cycle recorded a self-authored arm
    that passed against its own mutant; do not repeat it.

14a. **A `HOLDS` verdict gets an independent hand on its SCOPE before it is remediated.** Phase 1
    exempted `HOLDS` from second review on the grounds that a false `HOLDS` wastes work rather than
    losing it. That reasoning holds for whether the defect is real and fails for how WIDE it is: a
    `HOLDS` whose scope is wrong ships an incomplete fix, which is lost work wearing a green fixture.
    Measured on the three post-pin entries — all three were `HOLDS`-family, one was filed here as a
    plain `HOLDS` "exactly as filed", and two independent verifiers found a second failing grammar,
    a prescribed fix that does not work when run, and a BSD-`sed` no-op in it. **36 of the 76 live
    entries are already `HOLDS-MECHANISM-WRONG` or `HOLDS-WIDER`**, so scope error is the base case,
    not the exception. Aim the second hand at the scope question specifically — what else fails the
    same way, and does the prescribed fix actually work when executed — not at "is this real".

14b. **Run the filing's prescribed fix before adopting it.** Two of three post-pin filings prescribed
    a fix that provably does not work: one still returned the corrupt value when transcribed
    literally, the other named a channel that does not exist. Transcribe it, execute it against the
    case the filing itself reproduces, and record what it returned.

14c. **Read the guarding fixture before writing the remediation, and expect it to be blind.** All
    three post-pin entries were guarded by a fixture that was absent or seeded from what its reader
    already accepts — `core/fixtures/scope-confirmation/` seeds only the two grammars its parser
    accepts, and `core/fixtures/spec-join-integrity/seed.sh:200` claims "REAL bmad-spec SHAPE,
    captured from an actual headless run" while seeding only the form its regex matches. A fixture
    that cannot express the defect will stay green across the fix, so the remediation is not done
    when the code changes — it is done when an arm exists that fails without it.
15. Gate each branch with `AI_DLC_FIXTURE_NO_SKIP=1 bash .githooks/pre-push` and read every
    changed fixture **by name** in the full output, against an impossible-name control in the same
    invocation. `core/git-hooks/pre-push` is the consumer's hook and prints a green banner having
    run almost nothing; the content-key skip prints one too.
16. Each remediation gets its own `###` CHANGELOG section naming its `PC-` id verbatim.

### Phase 4 — the consumer brief

17. Write `docs/reviews/graph-ledger-adjudication-brief.md`. Per entry: the verdict, the evidence,
    and **either** the exact annotation string to paste —
    `**ADOPTED UPSTREAM (vX.Y.Z, verified <date>)**`, bolded, version immediately after the
    parenthesis — **or** the exact replacement `verify:` receipt.
18. The annotation form is load-bearing in two directions: *any* occurrence of the phrase makes
    `ledger-reverify.sh` skip the entry, but only the strict form lets `ledger-rotate.sh` archive
    it. A sloppy annotation makes an entry invisible **and** unarchivable. Render the exact string
    per entry; do not describe it.
19. For each of the 28 undecided `theirs_has` receipts, derive a replacement anchored on a token
    the fix **must remove** — a flag, a path, a function name — never prose describing the fix.
    Prefer converting to an `sh` predicate scoped to the span the claim is about; a file-wide
    substring cannot express "Check 5 does not consult the gate log". For every open entry the
    Phase 0 residual showed carries no directive at all, supply a receipt, or `verify: manual`
    with the reason it has no mechanical predicate.
20. Deliver the brief to the operator. **Do not apply it.** graph applies it in its own session.

### Phase 5 — close out

21. Re-run `ledger-reverify.sh` from the graph root against the new ai-dlc `origin/main`.
    **Observation point: before graph applies any annotation from the brief** — an annotated entry
    is skipped and emits no row, so this criterion is unreachable afterwards.
22. Re-derive the ledger delta against the Phase 0 pin. Entries graph filed during the run are new
    work; adjudicate them or hand them to the operator explicitly. Do not report completion over
    them silently.
23. Report to the operator: what shipped, what was closed and how, what graph must do, and
    anything left undone with the reason.

## Done when

**STATUS: 1, 2, 4, 5 and 6 are SATISFIED and BANKED. 3 is PER-RELEASE-BRANCH and is re-satisfied
on each batch — it was green on batch 8's branch (`v0.415.0`), which says nothing about batch 9's.**
Each is still stated in full below because a fresh session must be able to re-check them, not take
this line's word for it.

**An earlier revision of this line said criterion 3 was open "with no release branch yet cut", and
eight had been.** It went stale because it recorded a STATE where the criterion records a PER-BRANCH
OBLIGATION. Do not restate 3 as done; it is owed again by the branch you are about to cut.

Two of these were satisfied in ways worth knowing before you re-read them. **Criterion 5 was
NARROWED on measurement** — it split by channel because one criterion over both sets was
structurally unreachable for half of them. **Criterion 4 was measured by CONTENT throughout and
never by the dirty count**, which moved from 35 to 113 to 3 to 4 across the program purely from
graph's own activity.

Each of these is a command, and each was checked to be answerable at the point it is read.

1. `docs/reviews/graph-ledger-full-adjudication.md` carries one verdict row per open entry, and
   the row count equals the Phase 0 open-entry count **derived in the same invocation**.
2. Every id adjudicated `ALREADY-FIXED`, `FALSIFIED`, `DUPLICATE-OF`, or remediated appears
   **verbatim** in `CHANGELOG.md`. Control in the same invocation: an impossible id returns 0
   while a known-cited id returns non-zero.
3. `AI_DLC_FIXTURE_NO_SKIP=1 bash .githooks/pre-push` is green on every release branch, with each
   changed fixture read by name against an impossible-name control.
4. **No write by this program reached graph.** The Phase 0 baseline of **35** is NOT the criterion and
   cannot be: a live graph session is committing and editing there throughout, and it had already
   moved the count to **113** by the time Phase 2 resumed. An absolute count therefore measures
   graph's activity, not this program's restraint, and can never come back equal — it is the
   unreachable-criterion shape this plan is required to avoid. Assert instead that no path this
   program could write is dirty **by content**: the ledger's md5 is unchanged across the phase, and
   `git -C /Users/n8/git/graph diff --stat` names no file this program touched. Record the count as
   an observation, never as a gate.
5. **Split by channel, because one criterion over both sets is unreachable for half of it.** For the
   closes whose `final-disposition.tsv` channel is `changelog-cite` — 25 of 39 — the Phase 5
   `ledger-reverify.sh` run emits a `NAMED-UPSTREAM` row for every id cited, joining on the full
   slug so none degrades to `NAMED-UPSTREAM-AMBIGUOUS`. **That row comes from the RELEASE COMMIT
   MESSAGE, not from `CHANGELOG.md`** — see the correction under "Start here". A run of this
   criterion against a release that cited only in `CHANGELOG.md` returns zero rows and is the
   unreachable-criterion shape, measured: 21 of these 25 produce no row today. For the 14 whose
   channel is
   `brief-annotation`, that row **cannot exist** — `flush()` gates on `has_verify &&` and
   `named_absorbed()` rejects a non-id-shaped label — so the criterion is instead that the brief
   renders the exact strict `**ADOPTED UPSTREAM (vX.Y.Z, verified <date>)**` string for each, and
   that `ledger-rotate.sh --check` would archive it. Derive the two sets in the same invocation from
   the channel column; do not hand-list either.
6. The `HOLDS` set is empty — every entry is either remediated and cited, or filed as a `BL-`
   entry in `docs/backlog.md`.

## Hazards

- **A false CLOSE is the worst output in this system.** It retires a live defect and is
  indistinguishable from an ordinary absorption. That is why every close verdict carries a second
  refuting verifier.
- **The Bash tool's shell is zsh.** No `PIPESTATUS`, unquoted `$var` is not word-split, and `:c`/`:t`
  eat unbraced rev-path references — always `"${sha}:core/…"`. Force `bash -c` for any loop or
  heredoc. Never feed `grep -q` from a pipe: it exits at first match and `pipefail` turns the
  writer's EPIPE into a false NOT-FOUND on large files, which this ledger is.
- **Run `awk` over the ledger under `LC_ALL=C`.** Measured in planning: a multibyte em-dash aborted
  an `awk` mid-file with `towc: multibyte conversion failure`.
- **`bash` is 3.2.** No `mapfile`, `readarray`, `declare -A`, `setsid`; an empty array under `set -u`
  is an error.
- **A zero is not a finding.** Every absence-shaped claim carries a control in the same invocation
  that comes back non-zero, and both are reported.
- **The consumer runs its own installed engine.** Fixing `ledger-reverify.sh` here does not help
  graph until graph pulls. Run the fixed copy locally against graph's ledger for this program's
  own use, but the brief must be actionable under the engine graph has installed today.

## What the pull produced — the four filings, and the one lesson behind all of them

`BL-066`–`BL-069` are in `docs/backlog.md` with full derivations. Summarised only so a fresh session
knows what exists before re-deriving it:

| id | defect | consumer id |
|---|---|---|
| `BL-066` | `named_absorbed()` joins on the OLDEST commit whose MESSAGE mentions an id, and feeds its `VERSION` into a paste-ready PERMANENT annotation. Naming is not absorbing. **This plan CAUSED the worst of it** — the rule requiring every closed id in the release commit message is what makes the join resolve there. | `PC-S334-NAMED-ABSORBED-JOINS-ON-THE-OLDEST-MESSAGE-MENTION` |
| `BL-067` | `closes_when` has a schema, a producer, a printer and **no consumer**. Six layer debts came due the instant graph ran the command they named, and nothing announced it. | `PC-S334-CLOSES-WHEN-NAMES-A-COMMAND-AND-NOTHING-JOINS-THE-TWO` |
| `BL-068` | `ledger-rotate.sh:38-41` states a byte-identical invariant that its own prescribed workflow breaks, and the fixture asserting it **cannot construct** the row that would break it. | `PC-S334-ROTATE-ACCEPTANCE-TEST-FALSE-FAILS-ON-THE-WORKFLOW-IT-DOCUMENTS` |
| `BL-069` | `audit-layer-debt.sh` files its own discharge rows as undeclared debt, so the metric moves the wrong way in response to the action it exists to encourage. | `PC-S334-AUDIT-LAYER-DEBT-FLAGS-ITS-OWN-DISCHARGE-ROWS-AS-UNDECLARED-DEBT` |

### THE FINDING THAT OUTRANKS ALL FOUR, AND THE REASON THIS SECTION EXISTS

**Six independent instances of ONE class in a single pull, split evenly between two parties who were
both actively watching for it.** A path a receipt READS versus one it MENTIONS. A grep hit counted
as a call site. A regex truncating placeholder paths. A report's own summary sentence *"24
HAND-REVIEW"* counted as a data row. A `v`-anchored bucket labelled "nothing to compare" that
contained the largest disagreement in the set. And a receipt guard testing that extracted text
*contained* the string `prefix_entry_count` — which mangled, unparseable text still does — so `eval`
failed, the function was never defined, both counts came back empty, and `[ "" = "" ]` returned 0.

**That last one was in the receipt for the entry documenting the pattern, written in the same hour.**

**Six is not a discipline problem, and treating it as one produces exactly the wrong remedy.** The
instinct after six is to read more carefully — and reading is the faculty that failed all six times.
Every instance was a TEXT-SHAPED QUESTION ASKED ABOUT A PROGRAM: does this file mention X, does this
line contain Y, does this extraction look like a function. Text-shaped questions cannot separate a
subject from a reference to it.

**Nothing about review caught any of them.** Not the brief, which I reviewed before shipping. Not
the figures, which I published three times. Not the version walk, which I reviewed *while writing
its own control*. Reviewing a rendering establishes only that it is internally consistent with
itself, which every one of these was. **All six fell to recomputing from source and comparing two
independently derived values.**

### THE RULE THIS EARNED, and it is the one to carry forward

**A control must be run against the input that DISCRIMINATES, and asserted to discriminate on it,
before its result is read.**

Every bad control in this pull passed on an input ADJACENT to the one that mattered — a summary line
beside the data rows, a release commit one step ahead of the start point, two temp paths differing
only in a header, a fixture corpus that could not construct the row type under test.

`ARM 5` of `render-brief.sh` is the shape that follows from it, and it is portable: draw the probe
FROM THE CORPUS rather than hand-picking one, so it survives the corpus moving; compute both
candidate semantics; and **REFUSE UNLESS THEY DIFFER** before reading either. It does not ask anyone
to read more carefully. It makes the instrument refuse when its two inputs cannot disagree.

**A number was wrong three times and an artifact twice, and every single correction came from a
party re-deriving rather than accepting.** That is the operating lesson of this entire program.
