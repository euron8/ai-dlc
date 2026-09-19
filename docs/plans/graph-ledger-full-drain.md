# Drain the graph consumer's push-candidate ledger — full sweep

**Archived sections live at `docs/plans/archive/graph-ledger-full-drain.md`** — rotated by `scripts/plan-rotate.sh`, original lines 617..1048. It is a RECORD, not an instruction: read it for the evidence behind a figure, never for something to do.

## RESUME HERE

**You were started with one sentence: `READ and FOLLOW docs/plans/graph-ledger-full-drain.md`.
This section is the ONLY CURRENT STATUS RECORD in this file.** It tells you WHERE THINGS STAND.
It does not tell you what to do.

**BEFORE ANY OF THAT: THE LEAD DOES NOT RUN THE SWEEP ITSELF. Spawn hands first — action 0 under
`### NEXT ACTIONS` says how.** `ListAgents`, then one parallel `Agent` block, then read.

**YOUR INSTRUCTIONS ARE FIVE SECTIONS, AND THEY ARE NOT ALL NEXT TO THIS ONE. READ ALL FIVE
BEFORE ACTING:**

1. **`## Start here`** — the two repos and the READ/WRITE boundary. **Read this FIRST, before any
   command.** One of those repos is READ ONLY and a write there is the most expensive mistake
   available in this program.
2. **`### NEXT ACTIONS — numbered, in order`** — what to do, starting at action 1. Jump to the
   heading BY NAME; do not scroll.
3. **`### Ping the operator`** — when to stop and report.
4. **`## Hazards`** and **`### Done when`** — what will bite you, and what finishing looks like.
5. **`### Derive the state; do not trust the numbers below`** — the command block actions 1b and 6
   both tell you to run, and the only place the figures in this file can be checked. It sits ABOVE
   the numbered actions and above `## Context`, so it is LIVE despite its position; jump to it by
   name like the others.

**THE HISTORY BOUNDARY IS BY HEADING, NOT BY POSITION.** `## Start here`, `## Hazards`,
`## Verdict vocabulary` and `### Done when` all sit BELOW `## Context`, so a rule reading
"everything from `## Context` down is HISTORY" would skip this plan's own read/write boundary and
write to the consumer. `scripts/validate-plan-shape.sh:73` cannot catch this: it greps that
`## Start here` EXISTS and never asks whether the reader was told to ignore it.

So: the five sections above are LIVE. Everything else is HISTORY: measured episodes, refuted
hypotheses, and status records that were current when written and that THIS BLOCK REPLACES. Read
those when a rule looks arbitrary or when you need the evidence behind a figure. **Do not take an
instruction from them.**

**MOST OF THAT HISTORY IS NO LONGER IN THIS FILE, AND THAT IS THE CHANGE YOU MOST NEED TO KNOW
ABOUT.** At `v0.580.0` this file was rotated from **1158744 bytes to 138435** — the per-batch
records, the adjudication register, `## Status record`, `## Phases` and `## Verdict vocabulary` all
moved to `docs/plans/archive/graph-ledger-full-drain.md`, named by the pointer at the top. Nothing
was deleted; conservation was asserted three ways. **Go there for the evidence behind any figure,
and expect a rule here to cite a measurement whose story lives in the archive.** `## Context` and
`## What the pull produced` are still in this file.

**A CITATION INTO THE ARCHIVE IS A PLAIN PATH, NEVER `path:line`.** A later rotation re-numbers
that file and a `path:line` into it would then fail `validate-plan-shape.sh`'s citation arm on a
correct rotation.

**THIS FILE IS NOW BOUND AT 150000 BYTES** by arm `P8` of `scripts/validate-plan-shape.sh`, which
covers every plan in `docs/plans/` at depth 1 whether live or spent. When it fires, the remedy is
`bash scripts/plan-rotate.sh docs/plans/graph-ledger-full-drain.md` to see what would move and
`--apply` to move it — **never a discharge banner in the head window**, which would silence P9
through P13 on this file. Rotating is the remedy; there is no exemption list and one must not be
added.

### Derive the state; do not trust the numbers below

Every figure here is a HYPOTHESIS about a tree that has moved. The measured base rate of expired
premises in this program is roughly one in two. Each command below carries its own control.

**SIX of this section's TEN fenced blocks are RUNNABLE and the rest are EXAMPLES, so "run the
derive block" names a set and not a fence.** They group as the FIVE numbered steps below —
**step 3 covers two adjacent fences**, which is why the fence count and the step count differ.
Derive both rather than trusting this sentence: the fence total is
`awk` over ` ``` ` markers between this heading and `### NEXT ACTIONS`, halved. Run them in this
order, and read the prose between them — each one's controls are explained there, not in the
fence:

1. the four-command INSTRUMENT block immediately below (repo head, backlog counts, receipt
   histogram);
2. the `D=…` / `lids()` block, which builds `/tmp/live.txt`, `/tmp/arch.txt` and `/tmp/filed.txt`
   and carries the presence and absence controls — **actions 1b and 6 both depend on this one**;
3. the `pc()` PARTITION block, then the four-line overlap block under it, which corrects
   DISCHARGED;
4. the **PC-BACKED WORKLIST** join, which is the SCOPING input and the only block here that
   answers what work REMAINS;
5. the delivery-gap block (`.ai-dlc-version` vs `VERSION`).

The others are worked examples: the three ledger RECORD FORMS, the grammar table, the
mode-only `git diff --raw` recipe, and the receipt histogram one-liner action 5 owns. Concatenating
every fence in this section gets a syntax error on the record-forms example.

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
COUNT, AND NEITHER IS A HEADING GREP.**

A bare `PC-`-shaped token grep over the live ledger counts **82** where the headings give **40**:
the surplus is bare sprint prefixes (`PC-S296`, `PC-S333`), truncations (`PC-S3`, `PC-S295-`), and
cross-references in prose to candidates that now live in the ARCHIVE. It also misses
`push-candidate-ledger.archive.md` entirely, so every mention of an already-closed candidate
scores as an unexamined one.

**A `^## PC-` HEADING GREP CANNOT SPELL A THIRD OF THE LEDGER, AND A HEADING-PLUS-BULLET ARM
STILL MISSES A THIRD FORM.** The consumer records a candidate in THREE forms:

```
## PC-S314-PRECLASSIFY-BUCKETS-A-MODE-ONLY-CHANGE-...
- **PC-S295-RETRO-CHECK5-SELF-REFERENTIAL — Check 5 compares two hand-maintained records to
  each other and cannot fail (filed 2026-07-21)**
- **PC-S336-STEP-1-AUTOPUSH-IS-THE-UNGUARDED-TWIN-OF-THE-PUSH-STEP-2-HARDENED** — step 1's ...
```

**The third form closes its bold IMMEDIATELY after the id**, where the second continues into
prose. A bullet arm requiring a trailing SPACE after the id (`^- \*\*PC-[A-Z0-9-]+ `) scores every
bare-bold entry as a non-instance. Measured, both directions, with the partition and an impossible
id as controls:

```
              batch 14's grammar    actual    invisible
live                  47              60         13
archive               92             122         30
```

**THE ENTRY THAT PROVES IT IS ITSELF IN THE MISSED SET.** The consumer had already filed
`PC-S305-BARE-BOLD-ENTRY-IS-INVISIBLE-TO-EVERY-REVERIFY`, in bare-bold form, describing this exact
defect — and it was invisible to this grammar BECAUSE of the defect it describes.

**DO NOT READ THAT ENTRY'S TITLE AS OVERSTATED.** `ledger-reverify` still emits a `HAND-REVIEW`
row for the entry, which does not make "invisible to EVERY reverify" too strong — that
**conflates the entry's own FORM with its SUBJECT**. The entry is written as a dashed bullet, so
of course reverify sees it; its subject is
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
ledger.** Point the grammar at its own subject before believing its zero — a control drawn from
the form you already know about cannot discover the form you do not.

**A FIFTH FORM: AN ENTRY IS FREE TO BE `### PC-`.** The consumer files a candidate NESTED under
another entry's heading, at heading level three, and `^## ` cannot match it — the third character
is `#`, not a space. Measured, both ledgers, with every prior control still passing: the live
count goes **71 → 72** and the archive is unchanged at 142. The single recovered id is
`PC-S308-DISPATCH-GUARD-SPRINT-FIELD-INTERMITTENTLY-NULL`, which sat in the ledger while three
consecutive sweeps called it empty of new work — the md5 was genuinely unmoved, so "nothing was
filed" was TRUE, and the GRAMMAR is what failed. **A sweep that reports no new work has made a
claim about its own grammar first.**

The arm is `^#{2,6}` for that reason, which is also the range `ledger_entry_shape()` in
`core/skills/ai-dlc-update/reconcile/lib.sh:278` has always used. **The SHIPPING tooling was never
blind to this form; only this file's hand-rolled copy of its grammar was.** If you touch this
function again, check it against `ledger_entry_shape()` rather than against your own reading of
the ledger.

**`sed -E '...;t;d'` IS NOT PORTABLE.** BSD sed answers `undefined label ';d'`, both files come
back EMPTY, and the partition control — *"must be 0"* — comes back 0 and AGREES. Only the PRESENCE
control, which must come back 1, catches it. That is why both controls are here and why one of
them is positive.

**KEY THE OTHER SIDE ON A BACKLOG ENTRY, NOT ON `docs/`.** A grep over all of `docs/` counts
`docs/reviews/graph-ledger-*`, which is the ADJUDICATION corpus and mentions very nearly every
candidate by construction — so it scores the whole ledger as covered and reports 3 unnamed. It is
not stable either: writing an id into this plan MOVES it from unnamed to named. A candidate is
taken up when a BACKLOG ENTRY cites it. Prose is not a filing.

```
D=/Users/n8/git/graph/_bmad-output/ai-dlc-update
# THREE deliberate widenings, each one a measured defect:
#   1. NO TRAILING SPACE after the id -- that space hid 43 of 63 bullet-form entries.
#   2. THE CLASS INCLUDES `.` -- an id may embed a version, and [A-Z0-9-] truncates it into a
#      FALSE MEMBER that joins against nothing and reports as no absence at all.
#   3. THE HEADING ARM IS `^#{2,6}`, NOT `^##` -- see the FIFTH FORM below. A `### PC-` entry
#      nested under another entry's heading was invisible for three consecutive batches.
# The optional `-? ?` also admits the DASH-LESS `**<id>**` at column 0, which is the subject of
# PC-S305-BARE-BOLD-ENTRY-IS-INVISIBLE-TO-EVERY-REVERIFY.
lids() { { grep -hE '^#{2,6} PC-' "$1" | sed -E 's/^#+ (PC-[A-Z0-9][A-Z0-9.-]*).*/\1/'
           grep -hE '^-? ?\*\*PC-[A-Z0-9]' "$1" | sed -E 's/^-? ?\*\*(PC-[A-Z0-9][A-Z0-9.-]*).*/\1/'
         } | sort -u; }
# READ THE LEDGER AT THE CONSUMER'S SPRINT TIP, NOT FROM ITS WORKING TREE, AND NOT FROM `main`.
# Measured at batch 85, which got this wrong TWICE IN ONE SESSION and in opposite directions.
# That consumer branches per sprint and merges back at the retro, so a candidate filed AFTER the
# sprint's PR merges sits on the sprint branch, committed and pushed, and is absent from `main`
# until the retro merge. The working file answers with whatever is CHECKED OUT at that instant,
# which the consumer changes while a batch is running.
#
# Batch 85 read the entry in full from the working tree at 02:00 (sprint tree checked out), then
# read 0 twice afterwards (main checked out) and recorded the filing first as UNCOMMITTED and then
# as WITHDRAWN. Two instruments agreed on a wrong answer because both were pointed at the wrong
# ref. The consumer session supplied the correction; nothing in this derivation could have.
# `git log -S ... -- <path>` keyed on `main` fails the same way and is the other half of the trap.
#
# So: resolve the sprint branch, and read the ledger THERE with `git show`. Report both counts
# when they differ -- the delta IS the set of filings not yet on main, which is exactly the set a
# sweep is looking for.
# RECENCY IS THE WRONG KEY AND IT SHIPPED A WRONG ANSWER AT BATCH 89. `--sort=-committerdate |
# head -1` picked a branch that was BEHIND main, and the subset control below fired at 7. The
# obvious repair -- "the newest branch AHEAD of main" -- picked a branch carrying NO LEDGER FILE,
# and `git show` on an absent path answers empty: live=0, silently, with every other control still
# passing. Measured over all 22 consumer branches at batch 89: NO ref was a superset of main. Four
# carried a ledger and each was a stale snapshot whose "extra" ids were ALL in main's ARCHIVE --
# they predate closes and are not unmerged filings, which is the same output as a real filing.
#
# So qualify a ref on the PROPERTY that matters -- it carries the ledger AND its live set contains
# main's -- and fall back to main, which is the answer whenever the retro has merged. Report the
# candidates rather than electing one silently.
#
# THE GLOB WAS THE THIRD WRONG KEY, MEASURED AT BATCH 90. `ai-dlc/feature/*` and `*sprint*` are
# two of the consumer's branch prefixes; its sprints also run under `ai-dlc/carry-over/*` (135
# branches), `ai-dlc/bug/*` (19), `ai-dlc/fix-forward/*` and others. Batch 90's filing sat on
# `ai-dlc/carry-over/chunk-max-usd-swap-sizing`, two commits ahead of main and UNPUSHED, and the
# loop never visited it: `ledger ref: main`, every control green, live=55, and the filing invisible.
# The candidate set is EVERY local branch ahead of main; the property test below is what keeps that
# cheap and correct (a branch behind main fails the subset arm and is skipped).
# THE ANCESTOR GATE WAS A CHECK THAT COULD NOT FIRE, AND IT IS GONE. `BL-270`, measured twice.
# It required each candidate branch to CONTAIN `main`, and the consumer branches per sprint while
# `main` advances independently, so a sprint branch DIVERGES rather than fast-forwarding. Measured
# at filing: 0 of 723 non-main branches passed, while 178 CARRIED a ledger. Re-measured at batch
# 130: 1 of 723 passed -- the one branch the consumer happened to have checked out -- so the loop
# elected correctly BY LUCK, and would return to 0 at the next retro merge. Either way 177
# ledger-carrying branches were never read.
#
# THE PROPERTY ARM BELOW IS THE CORRECT TEST AND WAS UNREACHABLE BEHIND THAT GATE. With the gate
# removed it elects 3 refs, each with unexplained=0; a genuinely stale snapshot still fails.
#
# AND ELECTING ONE REF IS UNSOUND, WHICH IS WHY THIS IS A UNION. Measured at batch 130 over the
# three qualifying refs: carry-over adds 4, story-1 adds 4, story-3 adds 4, and the UNION of adds
# is **7** -- they are PAIRWISE INCOMPARABLE and overlap in exactly one id. No qualifying ref
# dominates, so every single-ref rule loses real filings whichever tie-break it picks. `BL-270`'s
# own "strict superset" claim was refuted on this input, both directions non-zero.
#
# THE UNION MUST SUBTRACT THE UNION OF THE ARCHIVES, OR IT RESURRECTS CLOSED CANDIDATES. Measured:
# a bare union of the three live sets is 54, of which **6 ids are live on one qualifying ref and
# ARCHIVED on another** -- candidates the consumer has closed, which a naive union re-opens.
# Union-live MINUS union-archive is 48, and the 3 ids the carry-over branch "loses" to the other
# two are exactly ids IT has archived. `main` is folded into both unions: it contributes nothing
# today (48 either way, both directions 0) and it makes the empty-qualifying-set case correct by
# construction rather than by a fallback.
QUAL=0
: > /tmp/union_live_raw.txt; : > /tmp/union_arch_raw.txt
git -C /Users/n8/git/graph show "main:_bmad-output/ai-dlc-update/push-candidate-ledger.md" > /tmp/mainled.md
lids /tmp/mainled.md >> /tmp/union_live_raw.txt
git -C /Users/n8/git/graph show "main:_bmad-output/ai-dlc-update/push-candidate-ledger.archive.md" > /tmp/mainarch.md
lids /tmp/mainarch.md >> /tmp/union_arch_raw.txt
for b in $(git -C /Users/n8/git/graph for-each-ref --format='%(refname:short)' refs/heads); do
  [ "$b" = main ] && continue
  git -C /Users/n8/git/graph cat-file -e "${b}:_bmad-output/ai-dlc-update/push-candidate-ledger.md" 2>/dev/null || continue
  git -C /Users/n8/git/graph show "${b}:_bmad-output/ai-dlc-update/push-candidate-ledger.md" > /tmp/cand.md
  git -C /Users/n8/git/graph show "main:_bmad-output/ai-dlc-update/push-candidate-ledger.md" > /tmp/mainled.md
  lids /tmp/cand.md > /tmp/cand.txt; lids /tmp/mainled.md > /tmp/mainled.txt
  # A QUALIFYING REF IS MISSING NOTHING MAIN HAS *THAT IT HAS NOT CLOSED*, and the second half of
  # that sentence was absent until batch 113, where it cost the batch its headline. The bare subset
  # arm was written at batch 89 to reject STALE snapshots, and it does — but a branch on which the
  # consumer has been CLOSING candidates is missing exactly the same ids a stale one is, so it
  # fails identically and the loop falls back to `main` with every control green. Measured:
  # `ai-dlc/carry-over/epic-crs-fvs-carryover-priorities`, 27 commits unpushed, live 49 against
  # main's 62 — and ALL 13 of the difference sat in that branch's own ARCHIVE, closed by
  # `55a0b410b … close 14 absorbed entries (#1078)`. The sweep reported `ledger ref: main`,
  # "filings ahead of main: empty", and a worklist of 22 where the true figure was 18.
  #
  # So read the ref's ARCHIVE too, and acquit an id that LEFT live by being CLOSED. A genuinely
  # stale snapshot still fails: its missing ids are in neither of the ref's two files. The
  # discrimination was verified by construction before this arm was written — 13 missing, 13 in
  # the branch archive, so the two readings differ on this input rather than agreeing by luck.
  git -C /Users/n8/git/graph cat-file -e "${b}:_bmad-output/ai-dlc-update/push-candidate-ledger.archive.md" 2>/dev/null \
    && git -C /Users/n8/git/graph show "${b}:_bmad-output/ai-dlc-update/push-candidate-ledger.archive.md" > /tmp/cand_arch.md \
    || : > /tmp/cand_arch.md
  lids /tmp/cand_arch.md > /tmp/cand_arch.txt
  # ids main has that the ref lacks, MINUS the ones the ref has archived == unexplained losses
  comm -23 /tmp/mainled.txt /tmp/cand.txt | comm -23 - /tmp/cand_arch.txt > /tmp/lost.txt
  [ "$(grep -c . /tmp/lost.txt || true)" -eq 0 ] || continue
  # and it must ADD something main lacks, or CARRY closes main has not seen
  qualifies=0
  [ "$(comm -13 /tmp/mainled.txt /tmp/cand.txt | wc -l | tr -d ' ')" -gt 0 ] && qualifies=1
  [ "$(comm -23 /tmp/mainled.txt /tmp/cand.txt | wc -l | tr -d ' ')" -gt 0 ] && qualifies=1
  [ "$qualifies" -eq 1 ] || continue
  QUAL=$((QUAL + 1))
  echo "qualifying ref: $b  live=$(wc -l < /tmp/cand.txt | tr -d ' ')  adds=$(comm -13 /tmp/mainled.txt /tmp/cand.txt | wc -l | tr -d ' ')"
  cat /tmp/cand.txt      >> /tmp/union_live_raw.txt
  cat /tmp/cand_arch.txt >> /tmp/union_arch_raw.txt
done
# REPORT THE COUNT, so an empty qualifying set is ASSERTED rather than inferred. 0 here is a
# legitimate state -- it is the answer whenever every retro has merged -- and it used to be
# byte-indistinguishable from a loop that crashed or skipped every branch, which is exactly how
# the ancestor gate hid for as long as it did.
echo "qualifying refs: $QUAL   (0 is legitimate: main alone, whenever the retro has merged)"
sort -u /tmp/union_live_raw.txt > /tmp/union_live.txt
sort -u /tmp/union_arch_raw.txt > /tmp/arch.txt
# LIVE IS THE UNION MINUS THE UNION OF ARCHIVES. An id archived on ANY qualifying ref has been
# closed by the consumer and must not be resurrected by another ref's staler copy.
comm -23 /tmp/union_live.txt /tmp/arch.txt > /tmp/live.txt
# THE RAW SUBTRACTION IS NOT 0, AND A READER WHO "REPAIRS" IT BACK DELETES THE LOOP'S OWN
# ACQUITTAL. The loop accepts a ref missing nothing main has THAT IT HAS NOT CLOSED -- the batch-113
# repair -- so a ref on which the consumer has been closing candidates is LEGITIMATELY missing those
# ids, and a bare `comm -23` counts every one of them. Measured at batch 114, sweep hand and lead
# independently: raw **15**, all 15 in the elected ref's own ARCHIVE, UNEXPLAINED **0**. The line
# below therefore subtracts the archive exactly as the loop does; the version without that
# subtraction disagreed with its own premise and read as a broken loop on a correct derivation.
# It is an ASSERTION on the loop, never a control -- a non-zero means the loop is broken, not that
# the ledger moved, and a check that cannot fail reads exactly like one that passed. The
# discriminating control is the one below it: the PRESENCE arm, which must be non-zero on main.
lids /tmp/mainled.md > /tmp/live_main.txt
# THE ASSERTION ARM NOW READS THE UNION'S OWN TWO FILES ON BOTH SIDES. It used to compute
# `comm -23 live_main live | comm -23 - arch` against the ref the loop ELECTED -- so whenever the
# loop fell back to `main`, it compared `main` with itself and answered 0 BY CONSTRUCTION. That is
# `BL-270`'s second half, and it is why the gate could not be seen: the presence control read
# non-zero because `main` does carry a ledger, `filings ahead` printed empty, and both controls
# passed beside the wrong answer. `main` is now a MEMBER of the union, so its ids are in
# `live.txt` unless the union archived them, and a non-zero here means a member ledger lost an id
# no member closed -- which is a broken derivation, never a moved ledger.
#
# IT IS AN ASSERTION ON THE DERIVATION, NEVER A CONTROL. A check that cannot fail reads exactly
# like one that passed; the discriminating controls are the two below it.
comm -23 /tmp/live_main.txt /tmp/live.txt | comm -23 - /tmp/arch.txt | wc -l   # assertion: 0, or the derivation is broken
comm -13 /tmp/live_main.txt /tmp/live.txt           # the filings ahead of main. THIS is the new work.
wc -l < /tmp/live_main.txt                          # CONTROL: must be NON-ZERO. A zero here means
                                                    # the ref carried no ledger and `git show`
                                                    # answered empty -- which is what the "newest
                                                    # branch ahead of main" repair did at batch 89,
                                                    # reporting live=0 with every other control
                                                    # still passing.
# CONTROL ON THE ELECTED SET ITSELF, WHICH THE LINE ABOVE CANNOT GIVE -- it reads `main`, not the
# union. A qualifying ref whose archive is a superset of main's live set is acquitted by the
# archive arm while carrying a one-id ledger, and every other control here still passes. The union
# cannot fall below main's live set minus what the union has archived, so assert that floor.
comm -23 /tmp/live_main.txt /tmp/arch.txt | wc -l    # the FLOOR
wc -l < /tmp/live.txt                                # must be >= the floor above
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
grep -cx 'PC-S308-DISPATCH-GUARD-SPRINT-FIELD-INTERMITTENTLY-NULL' /tmp/arch.txt
                                                      # control: 1, a LEVEL-THREE heading nested
                                                      # under another entry. Fails to 0 if anyone
                                                      # narrows the heading arm back to `^## `,
                                                      # which is what hid this entry from three
                                                      # consecutive sweeps. THE OTHER FOUR CONTROLS
                                                      # ALL PASSED THROUGHOUT -- that is the point:
                                                      # a control drawn from a form you already
                                                      # know cannot discover one you do not, so
                                                      # this line exists only because the form was
                                                      # found the expensive way.
                                                      #
                                                      # READS `arch.txt`, AND IT USED TO READ
                                                      # `live.txt`. Batch 82's close ARCHIVED this
                                                      # entry, taking `^### PC-` in the LIVE ledger
                                                      # to 0 against 39 at `^## ` -- so the control
                                                      # went red for the one reason that is not a
                                                      # defect: the program SUCCEEDED. A control a
                                                      # successful close breaks is a control the
                                                      # next session "fixes" by narrowing the
                                                      # grammar it exists to protect. The archive
                                                      # is append-only, so the form stays reachable
                                                      # there; if a live `### PC-` entry is ever
                                                      # filed again, control BOTH files.
grep -cx 'PC-S300-SEVEN-VALIDATORS-SHIPPED-NON-EXECUTABLE-AT-0.242.0' /tmp/arch.txt
                                                      # control: 1, a DOTTED id. Fails as a TRUNCATION
                                                      # if the class loses its `.`, and a truncated id
                                                      # is a false member, never a reported absence
grep -cx 'PC-S999-NEVER' /tmp/filed.txt                                                  # control: 0
```

**The ledger moves when the CONSUMER WRITES, not only when they close**, so a figure here is a
snapshot of a file someone else is holding open.

**"CITED" IS STILL NOT THE PROGRESS METRIC, AND THIS IS THE LAST STEP OF THE DERIVATION.** A
candidate cited by a LIVE entry is work in flight; one cited by an entry in the ARCHIVE has been
discharged. Splitting the cited set is what turns this block into a measurement of the goal
instead of a measurement of coverage. **Report the partition below. Never report live/archive
entry counts as progress.**

```
pc() { grep -rohE 'PC-[A-Z0-9][A-Z0-9-]+' "$1" | sort -u; }
pc docs/backlog.archive.md > /tmp/closed_here
pc docs/backlog.md         > /tmp/open_here
git log --format='%B' origin/main | grep -ohE 'PC-[A-Z0-9][A-Z0-9-]+' | sort -u > /tmp/in_msgs
comm -12 /tmp/live.txt /tmp/closed_here                    # DISCHARGED, still live upstream
comm -12 /tmp/live.txt /tmp/open_here                      # in flight
comm -23 /tmp/live.txt <(sort -u /tmp/closed_here /tmp/open_here)   # untouched
# control: the three sum to the live denominator PLUS the known overlap below -- never to the
# denominator alone. DISCHARGED and IN-FLIGHT are NOT disjoint, so a bare sum reads as a partition
# failure on a correct derivation. Compute the overlap and subtract it before judging:
#   comm -12 /tmp/live.txt /tmp/closed_here | comm -12 - <(comm -12 /tmp/live.txt /tmp/open_here)
comm -12 /tmp/live.txt /tmp/closed_here | comm -23 - /tmp/in_msgs   # discharged but INVISIBLE
# TERMINAL -- discharged here AND closed in the consumer's ledger. The line above CANNOT see these.
comm -12 /tmp/arch.txt /tmp/closed_here | wc -l
```

A sum over the denominator is EXPECTED, not a partition failure. The discharged-but-unnamed line
is a real failure mode and not a formality: a fix that ships without its id in the commit MESSAGE
discharges the candidate and produces no row anywhere, so the consumer never learns of it.

**A CITATION CAN MEAN THE OPPOSITE OF WHAT THE JOIN ASSUMES.** `DISCHARGED` and `IN-FLIGHT` are
not disjoint: an id cited by an ARCHIVED entry AND by a LIVE one lands in both. Measured on
`PC-S303-STUB-AUDIT-MARKER-REGEX-MATCHES-LOCAL-VAR-NAMED-STUB`, which `BL-109` cites **to say
it is a DIFFERENT candidate that its own fix does not close**. **A `PC-` token in an entry is not
a claim of ownership; `pc()` cannot tell "I close this" from "I am not this".** Subtract the
overlap from `DISCHARGED`, never from `IN-FLIGHT`: a live entry citing an id is work in flight
whatever an archived entry said about it.

```
comm -12 /tmp/live.txt /tmp/closed_here > /tmp/d.txt
comm -12 /tmp/live.txt /tmp/open_here   > /tmp/f.txt
comm -12 /tmp/d.txt /tmp/f.txt          # the overlap. NOT zero, and not an error
comm -23 /tmp/d.txt <(comm -12 /tmp/d.txt /tmp/f.txt) | wc -l   # DISCHARGED, corrected
```

**THE PC-BACKED WORKLIST. THIS IS THE SCOPING INPUT, AND EVERY BLOCK ABOVE ANSWERS A DIFFERENT
QUESTION.** The unfiled join (`comm -23 /tmp/live.txt /tmp/filed.txt`) answers *which candidates
has nobody filed an entry for* — a measurement of FILING COVERAGE. This one answers *which live
entries here are still owed to a candidate the consumer still carries* — a measurement of WORK
REMAINING. **A session that reads the first as the second concludes the program is finished while
the ledger is full.** Measured at batch 112: the unfiled join returned 23, every one already
dispositioned, which was reported as "zero available"; this join returned **22 live entries, 20 of
them with an `sh` receipt still exiting 1**, and the consumer's live ledger held 62 candidates at
the same instant. Both numbers were correct. Only one of them was about the work.

Run the JOIN, never the bare `awk` half — the `awk` alone answers a question about
`docs/backlog.md` and says nothing about the consumer.

```
LC_ALL=C awk '/^## BL-[0-9]+/{if(id!=""){out()}; id=$2; pcs=""}
     match($0,/PC-[A-Z0-9][A-Z0-9.-]+/){p=substr($0,RSTART,RLENGTH); if(index(pcs,p)==0) pcs=pcs (pcs?",":"") p}
     END{if(id!=""){out()}}
     function out(){ if(pcs!="") printf "%s\t%s\n", id, pcs }' docs/backlog.md > /tmp/entry_pcs.tsv
wc -l < /tmp/entry_pcs.tsv     # INSTRUMENT: entries citing ANY PC id. NOT the worklist.
[ -s /tmp/entry_pcs.tsv ] || echo "REFUSE: awk half matched nothing -- grammar, not corpus"
: > /tmp/pc_backed.tsv
while IFS="$(printf '\t')" read -r id pcs; do
  for p in $(printf '%s' "$pcs" | tr ',' ' '); do
    grep -qxF "$p" /tmp/live.txt && { printf '%s\t%s\n' "$id" "$p" >> /tmp/pc_backed.tsv; break; }
  done
done < /tmp/entry_pcs.tsv
wc -l < /tmp/pc_backed.tsv     # THE WORKLIST: entries whose candidate is STILL LIVE upstream
cat /tmp/pc_backed.tsv         # read it -- the ids are the batch's candidate set
# controls, same invocation:
wc -l < /tmp/live.txt                                            # must be NON-ZERO
grep -cxF 'PC-S295-RETRO-CHECK5-SELF-REFERENTIAL' /tmp/live.txt  # a known-live id: 1
grep -cxF 'PC-S999-NEVER-A-REAL-ID' /tmp/live.txt                # impossible id: 0
```

**`grep -qxF` reads a FILE here, never a pipe** — fed from a pipe it exits at first match and
`pipefail` turns the writer's EPIPE into a false NOT-FOUND on a large ledger, which is this one.

**THEN SCORE EACH WORKLIST ENTRY'S RECEIPT RAW, AND DO NOT READ AN EXIT 1 AS "LIVE".** This corpus
uses **exit 9** for *"a precondition moved and I measured nothing"*, and `backlog-reverify.sh` maps
every non-zero to `STILL-LIVE`; one receipt read that way for 28 releases. An entry with NO `sh`
receipt scores neither and needs its premise re-derived by hand. **The measured base rate of
expired premises in this program is roughly one in two, so re-derive the premise of whatever you
pick before building anything.**

**AND THE PLAN ALREADY RECORDS SOME OF THIS SET AS NOT-READY — read that before ranking, so a
refuted remedy is not rebuilt.** `grep -F "<id>" docs/plans/graph-ledger-full-drain.md` per
worklist id; entries the file says nothing about are the ones no batch has examined.

**Do not "fix" this by narrowing the grammar.** A citation's INTENT is not derivable from the
token. The overlap is small, enumerable, and worth reading by hand.

**THE `DISCHARGED` LINE FALLS WHEN THIS PROGRAM SUCCEEDS, AND THAT IS WHY `TERMINAL` IS BESIDE
IT.** `DISCHARGED` intersects our archive with the LIVE ledger, so the moment a consumer closes a
candidate it leaves `live.txt` and drops out of the numerator. This is `mechanism-design.md`'s "a
fix that satisfies a join by deleting the join's subject reads as green forever", inverted: here
the subject's deletion reads as REGRESS.

**REPORT `TERMINAL` AS THE DELIVERED TOTAL AND `DISCHARGED` AS WORK AWAITING THE CONSUMER'S OWN
CLOSE.** They are disjoint, because `live.txt` and `arch.txt` partition. Both figures are ceilings
on coverage rather than adjudications: a citation is a filing, not a disposition.

**A CANDIDATE CAN REACH TERMINAL STATE AND APPEAR IN NO COUNT THIS PROGRAM MAKES** — bare-bold in
the consumer's ARCHIVE, so the old grammar could not see it there, and cited by an archived
backlog entry here, so the `DISCHARGED` line could not see it either. Delivered, closed, counted
nowhere. Both repairs in this block had to land together for that reason: fixing the grammar alone
still leaves such a candidate in no bucket.

**STATE WHICH DENOMINATOR A PROGRESS FIGURE IS AGAINST** — the live set or the whole corpus. The
two answers differ by a factor.

**AND "DISCHARGED" IS STILL A CLAIM ABOUT THIS TREE, NOT ABOUT THE CONSUMER.** A consumer runs
its OWN installed engine. Until graph PULLS, none of this reaches it, its ledger does not move,
and this program's goal — draining THAT ledger — cannot be closed on the side that matters.
Derive the gap; it is not optional bookkeeping:

```
awk -F': ' '/^version:/{print $2; exit}' /Users/n8/git/graph/.claude/.ai-dlc-version   # installed
cat VERSION                                                                            # shipped
# per discharged id, the release that FIRST named it -- named_absorbed() takes tail -1.
# Loop over the DISCHARGED set derived above; the id is a variable, never a literal placeholder
# (a `<id>` typed verbatim matches the string "<id>" and returns a real, meaningless commit).
for id in $(comm -12 /tmp/live.txt /tmp/closed_here); do
  sha="$(git log --format='%H' -F --grep="$id" origin/main | tail -1)"
  printf '%s\t%s\n' "$id" "$( [ -n "$sha" ] && git show "${sha}:VERSION" || echo UNNAMED )"
done                                                                                   # control: an impossible id prints UNNAMED
```

**NO RUNBOOK IS LIVE.** Every `docs/plans/graph-pull-*` file is retitled `DO NOT EXECUTE` at its
first line. Read them as worked examples, never as live plans, and check the first line of any you
open. **Keep measuring the gap and reporting it; do not run the pull, and do not treat its growth
as a reason to reorder the work.**

**A PENDING CANDIDATE FROM A SPRINT THE CONSUMER IS STILL RUNNING** raises what the deferral
costs; it does not change whose call it is. Report the number and stop.

**AND THE REHEARSAL IS NOT OPTIONAL BOOKKEEPING — IT IS WHERE THIS PROGRAM'S ONLY CONSUMER-FACING
DEFECT WAS CAUGHT.** `v0.429.0`'s rehearsal found a `WORKLIST` row instructing every consumer to
register a sourced library as a hook. Re-rehearse before writing any figure into a runbook.

**A ZERO GAP IS A STATE, NOT AN ACHIEVEMENT THAT STAYS TRUE** — it goes non-zero on the very next
release that discharges anything. Re-derive it every batch rather than reading any sentence here.

**THE PULL IS NOT YOURS TO RUN.** `.claude/rules/consumer-boundary.md` is unconditional — an
ai-dlc session never writes to a consumer. The pull happens in a GRAPH session the operator
drives. What this plan owes is the GAP, measured, and a recommendation; **report it every batch
so the queue never becomes a surprise.**

**CHECK THE BOOTSTRAPPING HAZARD BEFORE RECOMMENDING A PULL, AND MEASURE IT RATHER THAN WARNING
ABOUT IT.** A fix to a step can never be delivered by that step: the broken version is the one
that runs the delivery. `PC-S314` repaired `preclassify.sh`, which IS the program the pull runs,
so the consumer's unfixed copy classifies the very pull carrying its own repair — and its defect
is a MODE-ONLY change bucketing `UPSTREAM-ONLY` forever, which is a non-terminating step 2.
**`PC-S314`'s fix takes effect on the pull AFTER the one that delivers it** — say so in the brief
rather than claiming the next pull is protected by it.

Measure it rather than asserting it:

```
git diff --raw <installed-commit>..origin/main -- core/    # mode-only = modes differ, blobs equal
```
A `000000 -> 100755` file ADD takes the `A` branch, not the `M` branch the defect lives in, so it
is not a mode-only change.

**A NON-RESOLVING CITATION IS A HYPOTHESIS ABOUT THE GRAMMAR FIRST.** A missing candidate and an
unspellable one are the same output. Establish that a citation resolves before picking an entry
as a batch subject — but run the CORRECTED grammar.

**READ EACH CANDIDATE'S OWN STATUS LINE BEFORE TREATING IT AS WORK.** Some are already WITHDRAWN
or REFUTED upstream, and several of the `PC-S312-*` cluster describe themselves as falsifiability
probes for a retirement rather than as defects.

**THE ID GRAMMAR IS `PC-<SLUG>`, NOT `PC-<NUMBER>`, and getting that wrong returns a clean zero
from BOTH sides.** A pass keyed on `PC-[0-9]+` reports 0 ids in the ledger AND 0 in the backlog,
which reads as "the join is dead" rather than "the grammar is wrong". The control that catches it
is running the same expression against the ledger itself: if the SOURCE has none either, the
grammar is the defect. `verification-discipline.md` owns this rule.

**"Cited" IS NOT "adjudicated".** A backlog entry naming an id is a FILING, not a disposition, so
the cited count is a ceiling on coverage rather than a measurement of it. The unfiled column is
the solid half: those have not been examined at all, and their status in the consumer's own ledger
is NOT ESTABLISHED. **Establish that before treating the column as a workload.**

**THE BACKLOG CEILING IS A LEVER, NOT A REASON TO FILE FEWER FINDINGS.**
`validate-backlog-size.sh` caps the live file; the gate reads the WORKING TREE at push time, so an
intermediate commit over the cap is not itself a failure. Rotation is the lever.

**A RISING LIVE COUNT ACROSS A BATCH THAT CLOSED AN ENTRY IS THE NORMAL CASE, NOT AN ERROR** —
asking whether the entry being closed was WIDER than filed routinely files more. Read the ARCHIVE
count, which only ever moves on a real close.

**A `CLOSE-CANDIDATE` IS A HYPOTHESIS AND NOT A VERDICT**: run the entry's receipt directly, read
the raw exit code, and ask what ELSE satisfies it before closing anything.

**A `STILL-LIVE` ROW IS NOT EVIDENCE THAT THE ENTRY IS LIVE, AND `BL-089` IS THE ENTRY THAT SAYS
SO.** `backlog-reverify.sh` maps every non-zero `sh` exit to `STILL-LIVE  … "still reproduces
here"`, but this corpus's receipts use **exit 9** to mean *"a precondition moved and I measured
nothing"*. The two are one row. One receipt was unable to measure anything for 28 releases and
read as `STILL-LIVE` the whole time. Derive the current pair; the count of live `sh` receipts
moves with every batch and the control is the entries declaring `verify: manual`, which the engine
does route to HAND-REVIEW.

**DERIVE THAT CONTROL FROM THE ENGINE, NOT FROM A GREP, AND BOTH GREPS ARE WRONG.**
`^verify: manual` misses the entries that INDENT the line, which `backlog-reverify.sh`'s own
grammar (`^[ \t]*verify:`) accepts. Fixing the indent is also wrong: both counts include the
`verify: manual` line in the `## Receipts` LEGEND at `docs/backlog.md:25`, which is prose about
the grammar and not an entry. The only reader that gets it right is the engine, because it starts
entries at a `BL-` id and never counts the preamble. Run the engine:

This one is a LOOP, so run it through `bash -c` — your shell is zsh, where an unquoted `$var`
is not word-split and a loop written for bash iterates once over the whole string.

**IT GATES ON A `## BL-` HEADING FOR THE SAME REASON THE CONTROL BELOW USES THE ENGINE.** A bare
`grep "^verify: sh "` also matches the `verify: sh <one-liner>` line in the `## Receipts` LEGEND
at `docs/backlog.md:22` — prose about the grammar, which then gets EVALUATED as though it were a
receipt and lands in the histogram as a real exit code. It misses indented receipts too. The
ledger's preamble is a receipt-shaped trap and every reader of this file must skip it:

```
bash -c 'while IFS= read -r l; do ( eval "$l" ) >/dev/null 2>&1; echo "$?"; done \
  < <(awk "/^## BL-[0-9]+/{e=1} e && sub(/^[ \t]*verify: sh /,\"\")" docs/backlog.md) \
  | sort | uniq -c'
bash scripts/backlog-reverify.sh | grep -c '^HAND-REVIEW'   # the control: these DO reach it
```

**Before scoping any entry, run its receipt directly and read the raw exit code.** A 9 means
the row above told you nothing.

### NEXT ACTIONS — numbered, in order

**0. DISPATCH HANDS BEFORE YOU RUN A SINGLE SWEEP COMMAND YOURSELF.** Operator instruction,
given at batch 90.

   - Your FIRST tool calls are `ListAgents` and then `Agent` spawns, in ONE parallel block:
     a **sweep hand** (`sonnet`, findings as text) that runs the derive block verbatim and
     returns the counts, the unfiled list with filing dates, and every control's value; and a
     **consumer-history hand** (`sonnet`) that reads the READ-ONLY consumer for the state the
     sweep cannot see — unpushed branches ahead of `main`, the porcelain set, the stamp. Run
     nothing they are running. Do the read/write boundary check and read the five live sections
     while they work.
   - The moment a subject is chosen, write the contract in the scratchpad and spawn the
     **adversary** (`opus`, read-only, no worktree) against the CONTRACT, alone, and fold its
     blockers into the contract before any builder starts. Operator instruction at batch 101:
     the adversary and the builder were spawned in one block, five contract blockers landed after
     the build had begun, and finished parts were rebuilt.
   - **AN ADVERSARY BLOCKER IS A FIX LIST, NOT A STOP SIGNAL, UNLESS IT NAMES SOMETHING
     STRUCTURALLY UNCONSTRUCTIBLE.** Operator correction at batch 111: a contract adversary found
     four real defects in a BL-223 design (a receipt blind to the anchor it needed to check; a
     self-probe that fired identically on the broken and fixed reader; a coverage count that
     silently became a row count; a declaration crossing a pull-class boundary with no skip path)
     and the session's first instinct was to write the refutation into the entry AGAIN — a fifth
     time — and defer, matching the pattern of batches 95 and 106 before it. Every one of those
     four findings had a direct, boundable fix (bind the receipt to the anchor column the report
     already had space to print; seed the self-probe on the property that discriminates, not one
     that happens to pass; count distinct names instead of rows; add a per-declaration SKIP verdict
     alongside the existing whole-directory one). **Before filing a fifth refutation, ask
     specifically: does each blocker name a fix, or does it name a proof that no fix exists?** A
     wrong anchor, a bad count, a missing verdict tier — these are bugs in a design, and the
     adversary that found them is the fastest path to the corrected one, not a reason to stop.
     Reserve deferral for a blocker that shows the state is genuinely unconstructible under the
     population's real constraints (no schema validation available, a property provably
     unobservable under the shipped control flow, a join that cannot be made to agree with
     itself) — and say which of those applies, explicitly, rather than defaulting to "refuted, do
     not rebuild" because a prior session's refutation pattern is sitting right there to copy.
   - Then FAN OUT BY DELIVERABLE, never one builder per subject. A subject that ships ALONE is
     one release, not one hand. Spawn one **fix hand** (`opus`, `isolation: "remote"`) for the
     engine change only; on its first commit sha, in ONE spawn block, a **fixture hand** (seed
     change, arms, mutants), a **docs-and-entry hand** (every carrier of the changed contract,
     the backlog entry, the receipt scored against tip/base/stub/mutants) and a **measurement
     hand** (fixture timing base vs tip in a detached worktree, the consumer rehearsal with its
     `cmp -s` control, the reverify diff), each `opus` in its own worktree, each rebasing onto
     that sha. Wall clock is the fix plus the longest arm, never the sum. Batch 101 measured the
     serial shape at over an hour for nine steps a fan-out would have run in the fixture's time.
     The lead does not build; the lead writes the contract, collects by content, cuts the
     release commit, and pings.
   - Every spawn names its model and the one-clause reason. `fork` ignores `model`; do not use
     it for a hand whose wrong answer would be silent.
   - Every spawn prompt carries this sentence verbatim: "Never run `rm -rf` on a variable path;
     build each scratch copy into a fresh `mktemp -d` under the scratchpad and do not delete it;
     anything that must be cleared names a literal absolute path." Operator instruction at
     batch 106, after a hand's `rm -rf "$S/$d"` loop stopped the session on a harness prompt
     that must not be allow-listed.
   - **Never merge while a hand is out**, and never read a hand's idle state as its report.

1. **CHECK `ListAgents` FIRST, RUN THE SWEEP (action 1b below) AGAINST THE REF THAT CARRIES THE
   LIVE LEDGER, RANK THE UNFILED CANDIDATES, THEN SCOPE THE BATCH — AND HOW YOU SCOPE IT DEPENDS ON
   WHO INVOKED YOU.** Operator
   instruction, given at batch 52. **If the one-liner was TYPED BY THE OPERATOR**, report the
   candidates with a marked recommendation and ask, as every batch before has. **If it ARRIVED
   FROM ANOTHER SESSION** — a cross-session message carrying `READ and FOLLOW …`, which is
   action 9's handoff — do NOT stop to ask: take the item(s) your own sweep and ranking
   recommend, state that choice and its reason in your FIRST message to the operator, and
   proceed; the operator can redirect at any ping. **Regardless of who invoked you, batch
   multiple candidates into one release wherever action 2 allows it — and do not merge while a
   hand you dispatched is still out, even on a green gate: batch 63's merged branch was green
   at every phase when its second adversary returned two BLOCKERs, and batch 66's was green
   when its adversary returned a BLOCKER establishing the shipped fix had made things WORSE.**

   **OPERATOR RULING AT BATCH 119, AND IT IS NOT SPENT: `docs/plans/pre-push-wall-clock.md` REMAINS
   THE SUBJECT UNTIL THE SUITE'S WALL CLOCK ACTUALLY FALLS.** Given in as many words — *"420 as a
   pole is not good enough. Neither is 346 on the next. Need to look deeper and refactor more
   aggressively in a future batch."* — after the operator was shown that cutting BOTH co-poles
   would buy roughly 85s of a 500s makespan. This supersedes the batch-118 ruling below, which
   named the same plan for one batch only.

   **The subject is REMOVING WORK, not scheduling it, and that is a change of kind.** The suite is
   no longer pole-bound: at `v0.585.0` the pole was 620s against a work-conservation floor
   (`sum of all unit costs / 12`) of 519.5s, so pole work of any size cannot return more than that
   gap. **Do not open batch 120 by shaving a fixture.** Read that plan's action 1, which names the
   lever the operator identified: every real input file is opened ~8.8 times per full run, and one
   10500-line validator carries 384 `grep`, 158 `awk`, 136 `sed` and 67 `find` sites re-walking
   corpora earlier arms already walked. Sharding and inner pools MOVE work between directories and
   leave that floor untouched — measured, `validator-arm-selection` 370 plus its shard 158 is 528
   pool-seconds for one subject.

   Batch 119 shipped as `v0.585.0` (`389b6bdc`) and is recorded in that plan's discharged section;
   it did not build the inner pool the batch-118 ruling anticipated, and the measurement for why is
   there. **This ruling governs batch 120 and stays live until the operator replaces it.**

   **SUPERSEDED — OPERATOR RULING AT BATCH 118: `docs/plans/pre-push-wall-clock.md` IS BATCH 119's
   SUBJECT.** Kept for its lineage only; the block above replaces it.
   Given in as many words ("I hereby rule it batch 119's subject") after the operator asked whether
   any release from `v0.576.0` to `v0.583.0` had cut the suite's wall clock and was told none had —
   `v0.583.0` added a guard, which is a ceiling and not a cut. This overrode the provenance-first
   ordering for ONE batch, the same shape as the batch-117 ruling for `BL-257`. Its two named
   actions were the `ledger-reverify` pole and the inner-pool sweep, pole first "because the
   makespan is one directory" — **which is the premise batch 119 measured and refuted.**

   **BATCH 118 SHIPPED AS `v0.584.0` (`a1979146`), TWO SUBJECTS, THREE ENTRIES CLOSED, TWO PC IDS
   NAMED VERBATIM IN THE SQUASH MESSAGE.** `BL-259` closed, discharging
   `PC-S312-STEP-2-SPELLS-THE-DERIVED-FIXTURE-SET-IN-A-FORM-ITS-OWN-RUNNER-REFUSES`:
   `self-update-fixtures.sh` normalises `core/fixtures/<name>` and `tests/fixtures/<name>`, with or
   without a trailing slash, to the bare name by character class, sited after `$LOG` exists and
   before the coverage join, rotating the positionals; the refusal row names which shape it saw and
   keeps the original argument as subject; `SKILL.md:477` says what the runner takes. `BL-262`
   closed, discharging `PC-S312-CHECK22-NO-CLEARING-PATH-FOR-19B-CITATION-MISS`: Check 22's
   four-arm disposition is scoped to every route into the validator's failure exit, arm 4 carries a
   remediation per class, arm 1 says an entry clears exactly the spawns it names and may name
   several, the effort route is documented probe-only, every FAIL message names the disposition.
   `BL-256` closed incidentally (its own text said nothing was owed; receipt 0). `BL-260`, `BL-261`
   and `BL-263` FILED, not fixed. Live **71 -> 73** (three rotated, five filed), archive
   **186 -> 189**. Gate `AI_DLC_FIXTURE_NO_SKIP=1`: 22 of 22 phases, 202 ok / 0 FAIL, pole
   `ledger-reverify 500s` against baseline 628s, four fixtures read by name against an
   impossible-name control of 0. First push exit 141 with every gate green and no ref on origin;
   re-push landed. Receipt histogram before and after: the same three zeros (`BL-254`, `BL-238`,
   `BL-236`, each deliberately held open) — no further incidental close.

   **THE SECOND SUBJECT WAS PULLED IN BY THE OPERATOR MID-BATCH AND WAS UNCOMMITTED IN THE
   CONSUMER'S WORKING TREE WHEN READ.** `git show HEAD:` on the sprint branch lacked it; only the
   working file carried it, so it had no `-S` date and the derived id set found it where the commit
   message could not. Its own receipt was a FALSE PASS at base and tip: it greps the disposition
   section for `19(b)|citation`, and arm 3 carries the word "citation" about the
   operator-authorization citation. Its `derived` counts (6 and 0) reproduce on NO copy reachable
   from here, the consumer's installed one included (1 and 1). `BL-262`'s receipt drives the
   validator on a seeded four-row ledger and REFUSES if a class is deleted — the adversary showed a
   naming-only receipt scores a build that deletes the 19(b) arm as FIXED.

   **BOTH CONTRACT ADVERSARIES FOUND BLOCKERS THAT NAMED FIXES, AND NONE WAS STRUCTURAL.** First
   subject: a `case core/fixtures/*)` glob matches a space and a newline, so the contract's own
   sentence acquitted the PC-S310 joined list and ran ONE fixture green over fourteen; `set -- $list`
   word-splits and deletes the joined-list refusal; sited after the coverage join, a complete
   path-form set is convicted incomplete; sited before `$LOG` exists the runner dies at rc=1, the
   red-suite code, with the real fixture green on it. Three of the four contract mutants were
   already green on the shipped suite. Second subject: the fixture's `VIOL=$((VIOL + 1))` grep is a
   text-about-the-program trap (a one-space respelling empties it; a helper function keeps the
   count at 4 with wrong membership), and the effort route is unreachable under the published
   invocation (`BL-263`). Every one went into the contract before a builder started.

   **FOUR FAN-OUT HANDS STALLED AT ONCE ON A HARNESS WATCHDOG (no progress for 600s) AND ALL FOUR
   RESUMED BY NAME WITH THEIR CONTEXT INTACT.** A stall that hits every hand in the same minute is
   the harness, not the hands; `SendMessage` to the name resumes the agent from its transcript.

   **THE LEDGER REF ELECTION FELL BACK TO `main` AGAIN** — the consumer's sprint branch
   `ai-dlc/carry-over/epic-crs-fvs-carryover-priorities` is diverged (6 behind, 63 ahead, 11
   unpushed at the sweep). Main-side worklist 17. Four filings only on the branch, all four now
   filed here (`BL-254`, `BL-259`, `BL-260`, `BL-261`) plus the working-tree one (`BL-262`).
   Consumer stamp `0.581.0`; delivery gap is `v0.582.0`, `v0.583.0`, `v0.584.0`, with 0 mode-only
   changes across 25 raw diff rows and four bootstrapping files in the range (`SKILL.md`,
   `emit-report.sh`, `preclassify.sh`, `self-update-fixtures.sh`). The consumer's installed runner
   still refuses the path form on the pull that delivers `v0.584.0`; the fix takes effect on the
   pull after.

   **ONE READ-SET ROW IS OWED AND NEEDS ROOT.** `check-22-spawn-ledger` now reads
   `core/skills/ai-dlc/steps/gate-validation.md` and its map entry does not carry that path, so a
   docs-only push can skip the fixture whose arm C2 watches that file. The operator runs
   `sudo bash core/scripts/derive-fixture-readsets.sh --list "check-22-spawn-ledger"` and the next
   batch commits the map change, as batch 118 did for `suite-pole-guard`.

   **BATCH 117 SHIPPED AS `v0.583.0` (`3c4c1b14`)**: `BL-257` closed (the pole is watched by
   `scripts/validate-suite-pole.sh` against `docs/suite-pole-baseline.tsv`, row `ledger-reverify
   628`, band 20, ceiling 754, calibrated on three serial full runs with a 12% loaded spread),
   `BL-255` closed, `BL-258` filed. The number to read for the pole is the guard's own PASS line in
   the gate log, never a durations-record row.

   **`core/fixtures/reconcile-emit-report`'s intermittent pool red IS ALREADY FILED AS `BL-230`**
   — batch 118 grepped before filing and found it; do not file it again. `BL-258` is the same shape
   on a second fixture.
   **"RESIDUE ZERO" MEANS NO CANDIDATE AWAITS A FIRST FILING. IT NEVER MEANS THE PC WORK IS
   DONE, AND EVERY BLOCK BELOW SAYING "ZERO KNOWN" IS MAKING ONLY THE NARROW CLAIM.** Two joins,
   two questions, and they are not interchangeable:

   - **`comm -23 /tmp/live.txt /tmp/filed.txt`** — candidates NO backlog entry cites. This is
     FILING COVERAGE. It goes to zero when every candidate has been examined once, which is the
     normal healthy state and says nothing about whether the defects are fixed.
   - **the PC-BACKED WORKLIST join** in `### Derive the state` — live entries whose cited
     candidate is STILL LIVE in the consumer's ledger. **This is WORK REMAINING and it is the
     scoping input.** Run it every batch.

   **Measured at batch 112, which got this wrong:** the first join returned 23, all already
   dispositioned, and the session reported "zero available PC work" and scoped two no-`PC`
   entries. The second join returned 22 entries, 20 with receipts still exiting 1, against a
   consumer ledger holding 62 live candidates. **Scoping a no-`PC` entry over those 22 inverts
   the operator's provenance-first ruling**, which exists precisely because a session finds its
   own discoveries readiest. Report BOTH numbers, say which question each answers, and scope off
   the second.

   **NOTHING IS PRE-SCOPED. THE SWEEP DECIDES, AND IT HAS NOW RETURNED NEW WORK TWO BATCHES
   RUNNING AFTER TWO EARLIER BLOCKS DECLARED THE PC-BACKED SET EXHAUSTED.** That declaration was
   true when written and false one batch later, twice over: the consumer filed
   `PC-S308-GATE-METRICS-CHECK2-STALE-VERDICT-READ-ORDER` on 2026-09-06 (live 66 -> 67), and then
   THREE `PC-S309-*` candidates on 2026-09-07 (live 67 -> 70, unfiled 16 -> 19, md5 moved again).
   **A sentence in this file saying the residue is zero is a snapshot of a file someone else is
   holding open. Run the sweep; never read that sentence for an answer.**

1a. **`docs/backlog.md` IS AT 73 OF 100** — re-derive it, do not read it. The operator raised the ceiling at `v0.446.0`, so filing
   is not blocked. That is not licence to file rather than fix — the standing correction in the
   resume block still governs — but a filing no longer costs a rotation, and rotating still means
   CLOSING, which needs a measurement.

1b. **THE SWEEP, kept here because every later batch runs it as its opening action.** Operator
   instruction, given at the close of batch 17. Do this BEFORE picking any subject when the subject
   is yours to pick, and report what it finds either way.

   **WHAT THIS SWEEP CANNOT SEE, MEASURED AT BATCH 82 OVER TWENTY ENTRIES.** Every join below keys
   on whether an id is CITED — by a backlog entry, or by an `origin/main` release commit message.
   **A citation is not an adjudication.** Batch 82 hand-adjudicated the twenty entries this sweep
   scored as discharged and found **12 RESOLVED, 8 PARTIAL, 0 NOT-RESOLVED** — 8 of 20 carrying
   live upstream residue that a shipped fix left behind, filed as `BL-217`..`BL-225`. Every one had
   been invisible for as long as it had existed, because `named_absorbed()` answers *"was this id
   named in a release commit"* and twelve batches of scoping read that as *"was this entry
   resolved"*.

   The sweep is still the right opening action and its counts are still correct about what they
   measure. **Do not read a DISCHARGED or CITED count as a claim that the entry's subject is
   gone** — that question is answered only by reading the entry's distinct claims against the
   shipping code, which is what the hand review does and what no receipt in this system performs.
   The measured rate at which the two answers differ is **8 in 20**.

   Run **`### Derive the state; do not trust the numbers below`** first — jump to it BY NAME, it
   sits above this action — it builds `/tmp/live.txt` and `/tmp/filed.txt`, and the set
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

   **THE DATE IS A PROPERTY OF THE CONSUMER'S GIT HISTORY, NOT OF THE LEDGER, AND A SQUASH MOVES
   IT.** `tail -1` takes the OLDEST commit introducing the string; the consumer squash-merges onto
   its carry-over branch, and a squash REWRITES that history, so the oldest introducing commit
   becomes the squash and every id it carries jumps forward a day. **Measured 2026-08-31: three
   already-discharged `PC-S307-*` ids dated `2026-08-30` one day and `2026-08-31` the next, while
   the ledger was byte-identical throughout.** Read as new filings they would have cost a session.

   **SO TAKE THE md5 AND THE TWO COUNTS BEFORE YOU READ ANY DATE**, in the same run — the ledger's
   md5, the live count and the unfiled count. Nothing has been FILED unless one of those moved. A
   date that moves alone is the instrument, not the subject.

   **The path is spelled ABSOLUTELY here on purpose.** `$D` in the sweep block above is RELATIVE
   (`_bmad-output/ai-dlc-update`), because it is an argument to `git -C /Users/n8/git/graph`. Reuse
   it with `md5` and it resolves against THIS repo and the command dies `No such file or
   directory` — measured, in the first revision of this very block.

   ```
   L=/Users/n8/git/graph/_bmad-output/ai-dlc-update/push-candidate-ledger.md
   md5 -q "$L"              # moves whenever the CONSUMER writes, which is the normal case and not
                            # an alarm -- check the id set too, and check the consumer's porcelain,
                            # because an uncommitted filing has no -S date
   wc -l < /tmp/live.txt    # the live denominator. It moves ONLY when the consumer files or pulls
                            # -- citing an id here moves CITED and never LIVE
   wc -l < /tmp/unfiled.txt # a CEILING on the available set, never the set itself
   ```

   **AN UNMOVED md5 WITH A MOVED COUNT IS THE GRAMMAR, NOT THE CONSUMER.** Batch 43 read 72 live
   against batch 42's 71 on a byte-identical ledger, because the heading arm was widened to
   `^#{2,6}`. If those two disagree again, ask which of them changed before concluding anything
   about the consumer.

   **THE CONSUMER FILES ONTO ITS SPRINT BRANCH ONCE THAT SPRINT'S PR HAS MERGED**, so a filing is
   committed and pushed and invisible at `main` until the retro merge. **The md5 line above is a
   working-tree reading and inherits that defect**: it answers about whatever is checked out, so a
   moved md5 can mean the consumer switched branches rather than wrote anything. Take the id SET
   from the ref the derive block elects; use the md5 only as a secondary tell and say which ref it
   came from.

   **DERIVE THE ID SET, NEVER THE COMMIT MESSAGE.** A consumer has filed THREE candidates in one
   batch while its own commit subject said TWO.

   **A FILING MAY BE UNCOMMITTED WHEN THE SWEEP RUNS** — its `-S` date comes back EMPTY, exactly
   like the impossible-id control, and only `git show HEAD:` against the worktree separates a new
   filing from a grammar failure.

   **REPORT TERMINAL AS THE DELIVERED TOTAL, NEVER THE BACKLOG'S OWN LIVE COUNT.**

   **AN UNMOVED LEDGER ACROSS A BATCH THAT SHIPPED IS THE NORMAL CASE**, because closing an entry
   here changes what the DISTRIBUTION has done and the consumer's ledger only moves on a pull.
   That is why DISCHARGED rises and the denominator does not.

   **A MOVED md5 DURING YOUR BATCH IS THE NORMAL CASE, NOT AN ALARM** — check whether the consumer
   wrote before concluding anything about a pull. **A moved md5 has three causes — a filing, a
   rotation, and a squash — and one pull can produce two of them at once, which is why the counts
   must be read together and never singly.** A filing RAISES live, a rotation LOWERS it, and a
   pull that does both can leave a net that looks like neither.

   **AN UNMOVED LIVE COUNT IS NOT AN UNMOVED LEDGER**: it has concealed a rotation and a filing
   offsetting each other in the same pull. **A rejection reaching its holder moves this
   denominator; shipping here does not.** A higher LIVE count means the consumer filed while
   nobody was looking.

   **THE SPRINT-306 RULING IS SPENT. DO NOT LOOK FOR SPRINT-306 WORK.**

   **IF THE SWEEP FINDS A NEW SPRINT'S SET, REPORT AND ASK — DO NOT ASSUME THE RULING EXTENDS.**
   Batch 18 asked and the operator said take both; that answer was about sprint 306's remainder.
   Extending it to a different sprint is theirs to do, not yours.

   **THERE IS NO PARKED SUBJECT. THE SWEEP DECIDES.** Do not go looking for a parked branch.

   **IF THE SWEEP FINDS NO NEW FILING, THAT IS NOT AN EMPTY BATCH — TAKE A PC-BACKED ENTRY.**
   "The sweep found nothing" means no candidate awaits a FIRST filing; the PC-BACKED WORKLIST
   join in `### Derive the state` is what says whether work remains, and it has been non-empty
   every time it has been run. Re-derive the set with that join rather than reading a count
   here, and none is pre-chosen. The selection rule is PROVENANCE first, then consequence —
   **never readiness, and a no-`PC` entry ranks below every member of that worklist.** Rank the
   set yourself; re-derive that your pick's id is live upstream, with the archive and
   impossible-id controls both 0, and run its receipt RAW before scoping it.

   **ENUMERATE THE ENTRY'S DISTINCT CLAIMS BEFORE YOU BUILD, BECAUSE HALF OF ONE MAY HAVE
   EXPIRED.** Batch 24's subject was filed against a mechanism a later release had already removed
   and against a damage claim that no longer held, while its real population had grown WIDER than
   the filing. Both dead halves named the REMEDY, so building from the filed text would have added
   a declared channel the defect no longer needs. Score each claim, then say in the entry which
   survived — and keep the entry whole rather than re-filing it, because which half died is the
   part that stops the next reader repeating the mistake.

   **AND COUNT A CLAIM ABOUT A TOOL'S OUTPUT OVER THAT TOOL'S OUTPUT.** The same batch's headline
   was first taken by grepping the consumer's ledger and read 21 / 12 / 5; driving the tool against
   a scratch copy and counting the rows it emits gives 16 / 9 / 3. The ledger holds entries the
   tool SKIPS by design, and they can never be instances of a defect in a row it never emits.

   **Derive the PC-backed set rather than reading that name.** The join below is the only command
   in this action that measures the SUBJECT rather than the instrument; it returned 22 entries
   after the v0.436.0 merge:

   ```
   # /tmp/live.txt comes from `### Derive the state; do not trust the numbers below` -- BOTH record forms
   awk '/^## BL-[0-9]+/{if(id!=""){out()}; id=$2; pcs=""}
        match($0,/PC-[A-Z0-9][A-Z0-9.-]+/){p=substr($0,RSTART,RLENGTH); if(index(pcs,p)==0) pcs=pcs (pcs?",":"") p}
        END{if(id!=""){out()}}
        function out(){ if(pcs!="") printf "%s\t%s\n", id, pcs }' docs/backlog.md \
   | while IFS="$(printf '\t')" read -r id pcs; do
       for p in $(printf '%s' "$pcs" | tr ',' ' '); do
         grep -qx "$p" /tmp/live.txt && { echo "$id"; break; }
       done
     done
   ```

   **Run the JOIN, never the bare `awk` half of it.** The `awk` alone answers "which entries cite a
   `PC-` id", which is a question about `docs/backlog.md` and not about the consumer.

   **REPLACE YOUR SUBJECT'S RECEIPT BEFORE YOU LAND ITS FIX. NOT OPTIONAL, AND NEVER ONCE SKIPPED
   WITHOUT COST.** Batches 14, 15, 17, 21 and 22 all had to; the `v0.417.0` sweep found four
   entries closable by PROSE alone. Build the correct fix AND at least two plausible regressions,
   score every one, and only then write the `verify:` line. **Score a SECOND SPELLING too** — a
   receipt rejecting a competent author's other phrasing is as broken as one accepting a
   regression.

   **BATCH 23 REPLACED ITS RECEIPT THREE TIMES AND EACH ROUND WAS WRONG IN A DIFFERENT
   DIRECTION.** Take these three before you write a line:

   - **SEED THE EXEMPTIONS, OR THE EXEMPTION HALF IS UNTESTED.** Round two drove the real program
     and still accepted five wrong implementations, because its seed held no exempt case and no
     untouched case. Four of the five WEDGED the subject on correct input, which is worse than the
     defect being fixed. For every exemption your fix has, the seed needs an instance of it.
   - **MAKE THE FAILING RUN THE SAME SIZE AS THE CONTROL RUN.** An implementation that reads
     nothing and keys on a COUNT passes any receipt whose bad input is smaller than its good one.
   - **A LITERAL PHRASE ARM IS TOO STRICT AND TOO WEAK AT ONCE.** Round three's `grep -qF` on an
     uppercase sentence rejected the same fix merely lowercased — reporting a shipped fix as
     unshipped — and was satisfied by an HTML comment carrying the phrase over unfixed prose. If
     you must key on prose, make it case-insensitive and reject a match inside a comment, and write
     down in the entry that a rewrite still scores STILL-LIVE.

   **Batch 22 shipped a receipt that did BOTH and needed three more rounds after the merge.** Its
   three holes, in the order they surfaced, each invisible until the previous one closed:

   - **A near-miss in a SEPARATE run is an ADJACENT input.** A second clean tree can only ask
     *does the arm fire at all*, never *does it fire on the RIGHT paths*, because in the run where
     the arm fires there is nothing present it should stay quiet about. Put the negative BESIDE
     the offender, in the same run.
   - **Never key on a token nothing BINDS.** It keyed on a status word carried by no
     `docs/vocabulary-index.md` entry and no `# vocabulary:` arm, so an author who spelled it
     differently — one did, independently — scored as still-live. Key on BEHAVIOUR: the shape of
     the row and a basename, not a word. Check whether your token is bound before keying on it.
   - **The seed must reach the point where a fix could be SITED.** It stopped at the first of four
     early exits, so arm PLACEMENT decided the verdict. Add a control asserting the run got that
     deep.

   Three rounds of scoring is not evidence of a good receipt. It is evidence the inputs were all
   the same SHAPE.

   **THE RESUME BLOCK ABOVE IS THE CURRENT RECORD OF THE GAP.** Do not run the pull, do not
   re-litigate it, and do not treat the gap as a reason to reorder this batch.

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
   # /tmp/live.txt comes from `### Derive the state; do not trust the numbers below` -- BOTH record forms
   awk '/^## BL-[0-9]+/{if(id!="")out(); id=$2; pcs=""}
        match($0,/PC-[A-Z0-9][A-Z0-9-]+/){p=substr($0,RSTART,RLENGTH); if(index(pcs,p)==0) pcs=pcs (pcs?",":"") p}
        END{if(id!="")out()} function out(){ if(pcs!="") printf "%s\t%s\n", id, pcs }' docs/backlog.md |
   while IFS="$(printf '\t')" read -r id pcs; do
     for p in $(printf '%s' "$pcs" | tr ',' ' '); do
       grep -qx "$p" /tmp/live.txt && { printf '%s\t%s\n' "$id" "$p"; break; }
     done
   done
   ```

   **AN ENTRY SHOULD LEAVE THE PC-BACKED SET ONLY BY BEING CLOSED.** Derive the set from the join
   at the top of this action rather than reading any name here; it is a snapshot of two files that
   both move.

   **THE SELECTION RULE IS PROVENANCE FIRST, THEN CONSEQUENCE — NOT READINESS.** Operator
   ruling. "Readiest to close" is what pointed batch 13 at three entries with no consumer
   provenance and no consumer surface, and it will do it again, because a session always finds
   its own discoveries easiest to fix. Derive the corpus rather than trusting this list:

   The join that derives it is the one at the top of this action — **run that one, not the
   bare `awk` half of it.** The `awk` alone answers "which entries cite a `PC-` id", which is a
   question about `docs/backlog.md` and not about the consumer. Piping it through `/tmp/live.txt`
   is what makes it a measurement of the goal.

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
   A `STILL-LIVE` row is not evidence the entry is live: receipts exiting **1** having measured
   nothing outnumber the exit-9 ones and carry no hint at all. One did that for 16 releases while
   reading as a genuine reproduction.

   **Then re-derive the entry's population rather than believing it.** Measured across 64 entries:
   entries WIDER than filed are the base case, not the exception, and citation drift is routine
   and mostly not load-bearing.

   **Ask what ELSE satisfies the receipt.** The standing rule is in
   `.claude/rules/verification-discipline.md`, "a receipt that reads a RENDERED artifact is
   closable by prose"; it is not restated here.

   **And ask what the fix's own population EXCLUDES.** Batch 11's first cut answered a
   one-way-blindness entry with an arm that was blind by file extension. The exclusion has to
   be stated in the arm and it has to not be the defect itself.
1c. **A PULL AUTHORIZATION IS FOR THAT PULL AND IS SPENT ONCE IT RUNS.**
   `.claude/rules/operator-rulings.md` governs the next one: a consumer pull is not preapproved, a
   `PENDING` count is not a decision about WHEN, and it is never handed to a peer session.

   **A PREDICATE IS ITS READ-SET, NOT ITS SCRIPT.** A byte-identical updater engine does not make
   a range inert: `setup-sites.md` is the manifest those executables READ to derive a pull's
   machinery slice, so derive the manifest PER BLOCK — `sites:` is what the mask/reinject
   transform reads. **Derive the slice with the SHIPPING `machinery_paths()`, never by hand:**
   `core/scripts/ai-dlc/*` is a CONSUMER-shaped glob that `preclassify.sh:225` rewrites, and passing
   it to `git diff` verbatim matches nothing and drops silently, understating the slice.

   **A `SELF-UPDATE-SAFE-STOP` SPLIT CAN BE DECLINED FOR A REASON THE ROW DOES NOT CARRY** — where
   the effective classifier input is identical under both plans, a split RELOCATES the `DEFER`
   rather than removing it and manufactures the `commit != skill_commit` state. The gate cannot
   reach that conclusion itself, which is filed as
   `PC-S340-SAFE-STOP-ACQUITTAL-TESTS-ANCESTRY-NOT-CONTENT`.
2. **BATCH MULTIPLE CANDIDATES INTO ONE RELEASE WHEREVER POSSIBLE.** Operator instruction at
   batch 52, replacing the one-subsystem rule that governed batches 17 through 52. "Possible"
   is a set of conditions, each of which keeps the candidates SEPARABLE after they ship:
   - each candidate gets its own fix commit(s) naming NO `PC-` id, its own `BL-` entry with its
     own receipt scored against its own regressions AND against the other candidates' fixes
     (a receipt the other fix closes is a pairing to refuse), its own fixture arms and mutants,
     and its own hands;
   - the ONE release commit names every closed id verbatim, and the CHANGELOG carries one `###`
     per id — action 8 governs: `named_absorbed()` reads `VERSION` at the OLDEST commit naming
     an id, so a per-candidate commit that named its id would report the previous version;
   - a candidate whose fix touches a BOOTSTRAPPING file (`preclassify.sh`, `apply.sh`,
     `ledger-reverify.sh`, the update skill) ships ALONE — action 7's hazard is per release, and
     a wide release multiplies its blast radius;
   - one PR, one gate, one merge; a correction release names only what it corrects.
   Batch 16 landed as one commit per candidate each naming its id; that shape predates the
   batch-43 measurement behind action 8 and is not the pattern any more.
3. **USE SUBAGENTS GENEROUSLY AND KEEP THE LEAD'S CONTEXT ON PLAN EXECUTION.** Operator
   instruction at batch 52. Delegate every reading-heavy or corpus-scale job — the sweep's
   census and the consumer's history, receipt scoring across candidate implementations, the
   consumer-side differential, a fixture battery, and, when batching, each candidate's
   implementation in its own worktree — and keep in the lead only what cannot be delegated:
   the read/write boundary, scoping, collection by content, the release commit, and the
   operator pings. Every hand gets the boundary sentence (`/Users/n8/git/graph` is READ ONLY),
   a deliverable in the tree or findings as text, and a model chosen by what a wrong answer
   would cost. The lead does not read what a hand can summarise, and treats what a hand
   returns as a check on its own answer rather than as the answer.

   **Put independent hands on SCOPE, FIXTURE and RECEIPT, every time.** It is the only mechanism
   that has ever told a session it was wrong about its own change, and what it finds is a WRONG
   ANSWER rather than an error.

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
     ever told this program it was wrong came from that shape, and none of them was reachable
     by a stated grammar.
   - **`sonnet` when a wrong answer would be LOUD.** Resolving citations, counting a corpus
     against a grammar fixed before dispatch, running a fixture and reporting its exit code,
     confirming a path exists. A control in the same invocation catches the error.
   - **Never `sonnet` for the adversarial hand.** Its whole job is to find what the brief did
     not anticipate, and that is precisely what a cheaper model reproduces least.

   Say the model and the one-clause reason in the spawn, so a thin result can be re-run one
   tier up rather than re-argued.

   **DO NOT NAME A REPORT FILE AS ANY HAND'S DELIVERABLE. A HOOK DENIES THAT WRITE** —
   `Subagents should return findings as text, not write report files`. Ask for findings AS TEXT
   in the final message.

   **GIVE EVERY HAND A DELIVERABLE IN THE TREE, BECAUSE THAT IS THE ONE THAT ARRIVES.** A hand
   whose output is a committed artifact delivers; a hand whose output is a message routinely goes
   idle without delivering. **Budget for that**: dispatch the hands, do the work yourself in
   parallel, and treat anything a hand returns as a check on your own answer rather than as the
   answer.

   **BUT AN IDLE HAND IS NOT A HAND WITH NOTHING TO SAY.** Payloads arrive TRUNCATED at ~16000
   characters, so ask for the tail by name. Waiting costs wall clock; merging without them has
   cost a release.

   **EVERY HAND, WRITING OR NOT, SPAWNS WITH `isolation: "remote"`.** Operator instruction,
   given at batch 108's close. Pass it in every `Agent` spawn regardless of the hand's job —
   scope, adversary, census, map, fix, fixture, docs, measurement, all of it. This supersedes
   the read-only-hands-don't-need-one carve-out below: that carve-out was about avoiding
   `isolation: "worktree"`'s cost for a hand that never writes, and it does not extend to
   skipping `"remote"` — the operator wants every spawn on that isolation regardless of whether
   the collision risk below applies to it.

   `--amend` names no commit, so it is only ever correct if you know what `HEAD` is, and
   in a shared checkout with a live peer you do not.

   A READ-ONLY hand — scope, adversary, census, map — does not risk a commit collision the way a
   writing hand does; that distinction still explains WHY a writing hand cannot share the lead's
   checkout, but it is no longer the reason to pick an isolation mode, now that every hand uses
   `"remote"` regardless of job.

   **THE COST IS COLLECTION, AND IT IS YOURS.** A remote or worktree hand's commits land on its own branch,
   not in your tree, so the work does not appear where you last saw it. Ask for the branch name
   and the commit shas in its final message, then collect them yourself and **verify the result
   by CONTENT** — `cmp -s` the files against what the hand said it wrote, and check the ship
   declarations separately. A hand reporting "committed" is a claim about a tree you have not
   read.

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
   entries. File them, tier them, give each a provenance line, and do NOT narrow the fix to
   avoid uncovering them.
6. **AFTER THE MERGE, BEFORE YOU STOP: re-derive this file's own RESUME block and prove it is
   resumable.** This is a numbered action because it is the step that decays silently — the
   merge is the moment the block you were following becomes a description of work already done,
   and a session that stops there hands the next one an instruction to redo it.

   Do these four, and REPORT the result:

   - **Run `### Derive the state; do not trust the numbers below` verbatim, and compare every
     figure to what this block CLAIMS.** Not
     "does it look right" — run it and diff. Fix the file where they disagree.
   - **Read the numbered action 1 as a stranger would.** If it still names work you just
     finished, it is wrong. Replace it with the next action; do not append beside it.
   - **Fix the COMMAND, never only the prose.** A resuming session runs the command.
   - **`bash scripts/validate-plan-shape.sh`**, which is the only mechanical half of this. It
     cannot see whether an action is stale, so it passing is not the answer — it is the floor.

   **The three failures this catches are all one shape: the file describing a tree that has
   moved.** A stale action 1 costs a whole session redoing a batch. A stale figure costs the
   trust that makes the other figures usable. A stale command costs whichever the reader
   believes.
6b. **THE FRESH-RESUME CHECK. ONE RESPONSIBILITY: A SESSION THAT STARTS FROM `origin/main` WITH
   NOTHING BUT THE ONE-LINER RESUMES CORRECTLY. Run it AFTER action 6's docs commit has MERGED,
   and do not stop before it passes.** Action 6 re-derives the block and validates its shape;
   this step proves the re-derived block is the one a stranger will actually read, and that it
   sends them to the right work. Measured at batch 52: action 6 was complete, the validator was
   green, and the re-derived block still sat on an unmerged branch — a fresh session on `main`
   would have read batch 51's block and re-scoped batch 52's subject. Nothing in action 6 could
   see that, because action 6 reads the working tree and a fresh session does not.

   - **Merge the docs commit FIRST.** A resume block that lives only on a branch is invisible
     to a fresh session. `git log -1 --format=%h origin/main -- docs/plans/graph-ledger-full-drain.md`
     must name the commit that carries the new block.
   - **Read it from a FRESH CHECKOUT, as a stranger.** `W="$(mktemp -d)/wt"; git worktree add
     "$W" origin/main`, then in `$W` read ONLY the five live sections `## RESUME HERE` names,
     in the order it names them, with no memory of this session. If any sentence needs this
     session's context to make sense, it is not resumable; fix it and go back to action 6.
   - **Run `### Derive the state; do not trust the numbers below` verbatim from `$W`** and
     compare every figure to the block's claims. A mismatch is a stop, not a note.
   - **Assert action 1 names no shipped work — counting RELEASE commits only.** For every
     `PC-` id action 1 offers as NEXT work:
     `git log -F --grep='<id>' --format=%H origin/main` must be EMPTY. For the id the block says
     SHIPPED it must be non-empty, with `VERSION` at the OLDEST commit naming the id equal to the
     release the block names.

     **DO NOT KEY THIS ON A `^release:` SUBJECT.** A GitHub squash takes the PR TITLE as the
     commit subject, so a correctly-cited release lands with a subject like `0.517.0 — …(#658)`
     and no `release:` prefix, and the arm then reports a mismatch on a release that was fine.
     Key on the MESSAGE MENTION, which is what the closer reads. **A docs commit that names a
     candidate while REPORTING it does not count** — a count over all commits reads 1 for an id
     nothing has shipped, and a literal reader reports a false mismatch. An action 1 naming
     shipped work is the whole failure this step exists for, and it is the one a green validator
     cannot see.
   - **`bash scripts/validate-plan-shape.sh` from `$W`.** PASS is the floor, not the answer.
   - **Remove the worktree** (`git worktree remove --force "$W"`) and report one line:
     `resumable from origin/main at <sha>` with the figures compared, or the mismatch and what
     was done about it.

7. **DETECT WHETHER A PULL IS OWED, AND SEPARATELY WHETHER IT IS REQUIRED. Do not run the pull,
   and do not write a runbook until the second test says yes.**

   **THE PENDING COUNT IS NOT A DECISION, AND TREATING IT AS ONE COSTS A SESSION.** It goes non-zero
   almost every batch by construction — this program discharges candidates, so the number rises
   whenever it succeeds. Measured at `v0.435.0`: PENDING was **12** while the pull was NOT required,
   and a session that read the count alone would have spent itself writing and rehearsing a runbook
   nobody needed. Owed and required are two claims; take both.

   **THE SECOND TEST IS A DIFFERENTIAL AGAINST THE CONSUMER'S REAL TREE, and it is cheap.** Run the
   consumer's INSTALLED `scripts/ai-dlc/validate-layer-entries.sh` and this distribution's copy, both
   against `/Users/n8/git/graph`, and diff the finding sets. **Put a `cmp -s` control in the same
   invocation asserting the two binaries differ** — otherwise two runs of one program produce a
   perfect null and it reads exactly like agreement. If the findings are identical, the pull changes
   nothing observable today and the answer is BANK IT. If they diverge, the consumer is missing a
   finding and that IS the trigger — report it immediately.

   **Then ask what the null does not cover.** A fix that fires on a TRANSIENT is invisible to a
   differential taken while nothing is failing, and a fix for a SILENT failure has no warning shot
   when it becomes live. Both were true at `v0.435.0` and both were stated rather than hidden behind
   the null. Report the null AND its limits, never the null alone.

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

   **AND IN THAT COMMIT ONLY — NOT ALSO IN AN EARLIER ONE.** `named_absorbed()` takes `tail -1`,
   the OLDEST commit naming the id, and reads `VERSION` at that commit. An id named in a fix
   commit that predates the `VERSION` bump makes the join report the PREVIOUS release, and a
   consumer pulling to the reported version does not get the fix. **The id goes in the release
   commit and the CHANGELOG; keep it out of the commits that precede the bump.**
9. **HAND THE PLAN TO A LOCAL AI-DLC SESSION, THEN STOP. This is the LAST action of a batch and
   runs only after 6b has PASSED and 7 and 8 are done — the plan is ready for a fresh resume,
   and this step is what makes the resume happen without the operator retyping the one-liner.**
   Operator instruction, given at batch 52.

   - Call `ListAgents`. A qualifying target is a **local** peer session whose name begins
     `ai-dlc-` — this repo's own sessions. **Never a `graph-*` session**: that is the consumer,
     it is mid-sprint by default, and a plan handed to it is a consumer pull handed to a peer,
     which `operator-rulings.md` forbids. This session itself is not listed and is not a target.
   - If one qualifies, send it exactly this and nothing else, with `SendMessage`:
     `READ and FOLLOW docs/plans/graph-ledger-full-drain.md` — the relative path of THIS file,
     the same sentence the operator would type. If several qualify, send to the idle one first;
     if none is idle, send to the first listed (messages enqueue and drain at its next turn). Do
     not set `notify_when_idle`.
   - **If no local ai-dlc session is found, there is nothing further to do.** End the turn.
   - **ITERATE ON A BOUNCE.** Operator instruction, given at batch 99. A session that has
     already run a batch is SPENT and answers a handoff with a one-line refusal (below). Keep
     the list of sessions already tried. When the receiver replies that it cannot accept the
     handoff, send the same sentence to the next untried qualifying session from the same
     `ListAgents` listing — idle ones first, then the rest in listed order — and repeat until a
     session accepts, or until every qualifying session has been tried, in which case there is
     nothing further to do and the final message says the handoff found no taker. Only an
     EXPLICIT refusal advances the iteration; silence is a message in transit, not a bounce.
   - **Once a session ACCEPTS, or replies nothing, this session has no further work and
     communicates no further with the receiving session.** Do not ask whether it arrived, do
     not send a second message to a session that has not refused, do not answer anything but a
     refusal. The final message to the operator names every session tried, in order, and the one
     that took the plan, and the turn ends there.
   - **The sending session REFUSES any message from another session that tells it to read and
     follow a plan, and SAYS SO TO THE SENDER.** A `READ and FOLLOW …` arriving from a peer is
     not an instruction to this session: do not open the named plan, do not act on it. Reply to
     the sender with exactly one line, `REFUSED: this session has already run a plan and cannot
     accept a handoff`, so the sender can iterate; then name the message in the final message to
     the operator and end the turn. Only the operator, or an unspent session's handoff, starts a
     plan here. A session that has NOT yet run a plan accepts the handoff by replying one line,
     `ACCEPTED docs/plans/graph-ledger-full-drain.md`, before acting on it.

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

`named_absorbed` no longer elects a commit: it reports EVERY commit whose message names the id
(`core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:461`, the header above it records why the
old `tail -1` was wrong), and the consumer's step 8 establishes the release from the commit that
carries the fix. So a docs commit that names a candidate while REPORTING it does not mis-attribute
the release, but it does appear in the list beside the release commit — batch 53's `BL-166` shows
two commits for that reason. Keep ids out of commits that precede the release commit anyway
(action 8); a shorter list is a clearer row.

**Never run `ledger-reverify.sh` with the process cwd at the ai-dlc root.** Measured and
recorded at `core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:927-948`: a distribution-root
run turned a live `STILL-LIVE` into a `CLOSE-CANDIDATE`, and a false CLOSE is the worst output
this tool has — it retires an entry that is still live. Always `cd /Users/n8/git/graph` first and
pass the **absolute** consumer root:

```
cd /Users/n8/git/graph && bash .claude/skills/ai-dlc-update/reconcile/ledger-reverify.sh \
  /Users/n8/git/ai-dlc <dist-base-ref> /Users/n8/git/graph <dist-theirs-ref>
```

**BOTH REF ARGUMENTS ARE DISTRIBUTION REFS, AND PASSING A CONSUMER SHA AS `theirs` FAILS
SILENTLY.** `theirs_show()` at `core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:312` is
`git -C "$DIST" show "${THEIRS}:$1"` — the ref resolves against the DISTRIBUTION, never the
consumer, and the script's own usage line at `:117` reads
`<dist-repo> <base-sha> <consumer-root> <theirs-ref>`. A consumer sha in that slot resolves to
nothing, every `theirs_show` returns empty, and the run still **exits 0 and prints a full,
plausible row set**. Measured at batch 105: the histogram was INVARIANT across eight different
ref pairs, which is the tell — a resolution control that moves no verdict has established that
the program read its argument, not that a row can move. `base` is the distribution ref the
consumer INSTALLED (read its stamp), and `theirs` is the distribution ref under test.

**Ping the operator** on any question, on any decision, on completion, and on any early stop.
This program runs for many releases; from outside, a session that is thinking and a session that
is waiting on a human look identical. Merges are preapproved — do not stop to ask for one.

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
