# Retire graph's consumer layer by absorbing upstream into core

---

# RESUME HERE — state as of 2026-08-08, verified for handoff

## Start here

**EVERY FIGURE IN THIS FILE IS A DATED MEASUREMENT, NOT A FACT. RE-DERIVE BEFORE YOU ACT ON ONE.**
This is not general caution. **Six assertions written into this plan during the 2026-08-08/09
sessions were wrong, and they were wrong in the same way each time: a number was carried forward,
or a proxy was read instead of the subject.** Enumerated, because an unenumerated warning is one
you read past:

| the assertion | what was wrong | what settles it |
|---|---|---|
| graph is at `0.329.0 / 9fc216e` | carried after the 0.330.0 pull had landed | `sed -n '1,4p' /Users/n8/git/graph/.claude/.ai-dlc-version` |
| the owed range is `0.330.0 → 0.337.0` | the pull had already taken it to `0.335.0` | the same command |
| the pull moves 8 `core/` files | derived against the wrong base | `git diff --name-only <stamped sha> HEAD` |
| s302 HAS STARTED | read `sprint: N`, a DECLARED currency, as evidence of activity | `ls _bmad-output/planning-artifacts/s<N>/` |
| `ledger-reverify` skips 15 live entries | modelled the predicate in Python; the shipped one is already anchored | run the shipped reader, before and after |
| item 22 finds 3 non-conforming paths | scanned one scan root; the declared set is four | the resolver, not a hand-picked corpus |

**THE RULE THAT WOULD HAVE CAUGHT ALL SIX: prefer the DERIVATION to the ANSWER, and when this file
gives you both, run the derivation.** Where a paragraph names a command, that command is the
evidence and the number beside it is a dated reading. Where a paragraph gives only a number,
treat it as a pointer and go find the command.

**AND TWO SPECIFIC TRAPS, both of which produced one of the rows above.** A field that DECLARES
something (`sprint: N`, `status: in_progress`, a stamp) tells you what a program was told, never
what happened — find the artifact. And a predicate you have reimplemented in order to measure it
is not the predicate; **run the shipped program**, and run it before your change as well as after,
or you cannot tell a fix from a no-op.

**A STATUS LINE THAT HAS BEEN TRUE FOR A WHILE IS NOT EVIDENCE IT HAS ROTTED.** One of the six was
a CORRECT line overwritten as stale. Measure the subject before rewriting a claim about it.

**FRESH SESSION: your entry point is §*THE NEXT ACTION, AND IT IS THE ONLY LIVE ONE IN THIS FILE*.**
Read this section for the boundaries and the standing operator decisions, then go straight there. It
carries the numbered next-action list; nothing else in this file is an instruction to you.

**This file is the plan of record. Everything below `## Context` is the original design record, kept
for rationale, and where the two disagree the top wins.**

**BUT "ABOVE `## Context`" IS NOT THE SAME AS "CURRENT", AND THIS SENTENCE USED TO SAY IT WAS.**
Above the cut there is one live status block (this section), one live next-action section, and
several sections that are SPENT — §*SPENT — session handoff of 2026-08-07* most of all, whose title
read live for eighteen releases. **The marker is the text, not the position**: a heading or a
paragraph saying SPENT, SUPERSEDED, DONE, or wrapped in `~~strikethrough~~` is a record, and
everything else above the cut is live. Check the marker before acting on anything here.

**CITATIONS BELOW `## Context` ARE HISTORICAL AND SOME NO LONGER RESOLVE TO THEIR SUBJECT.**
They were written before the releases that shipped them, and the releases moved the lines. Two
checked examples: `layer-drift.sh:648` was the env-key guard and is now other code, and a
`SKILL.md` line describing the invitation sentence v0.282.0 deleted. Both sit in sections marked
SHIPPED, so they are records of why a thing was done, not instructions.

**EVERY `path:line` ABOVE `## Context` IS RE-CHECKED AT EACH HANDOFF. Re-run 2026-08-09 after
v0.344.0: 66 distinct citations — 61 resolve in range, 0 past end-of-file, 0 ambiguous, 5 into the
CONSUMER.** Prior readings were 63/58/0/5 after v0.341.0, 62/57/0/5 after the 0.335.0 → 0.337.0 runbook landed, 54/49/0/5 after v0.337.0, the same 50/45/0/5 after v0.331.0 and after v0.330.0, then 51/46/0/5 (before that handoff's own edits changed it), 41/36/0/5, and 40/34/5/3-ambiguous.
**AND THE READING THAT MATTERS IS NOT THE COUNT: v0.344.0 moved all three of item 6's citations off
their subjects while leaving every one of them in range, and v0.341.0 did the same to all four of
item 2's**, so this loop went green over stale citations in the same run that made them stale, twice
in two releases. The current subjects are written into item 6 and item 2. Those are the third and
second recorded instances, after v0.320.0 did it to item 27. **That first figure moving while this paragraph was being written is the drift the sentence below describes.** **Do not carry these
numbers; re-run the loop.** It is one pass: extract
`[A-Za-z0-9_./-]+\.(md|sh|json|yaml):[0-9]+` from everything above `## Context`, resolve each
against `git ls-files`, and compare the line number to `wc -l`. Report the count as its own
control — a loop that extracts nothing prints the same four zeros as a clean file.

**AND THE COUNT IS THE WEAKER HALF OF THE CHECK.** It reports whether a citation RESOLVES, never
whether it still resolves to its subject — v0.320.0 moved two lines item 27 quotes while leaving
both in range, so the audit stayed green over a citation that had gone stale. Read the line, not
just the count. Note also that quoting a bad citation as an EXAMPLE makes the loop flag the
example — write it without the line number, as above.

**THE FIVE CONSUMER CITATIONS, DERIVED RATHER THAN HAND-LISTED — re-derived 2026-08-09 and
unchanged:** `s301-epics-repair-p5d.md:115`, `s301-stories-adversarial-p2.md:327`,
`s301-stories-adversarial-p6.md:252`, `s301-stories-repair-p5.md:581` — **the s301 close-out
archived all four**, so they now live under
`_bmad-output/planning-artifacts/archive/s301-<series>/` rather than at the paths quoted; content
unchanged (`git mv` with per-file sha verification), only the prefix moved. The fifth is
**`tea-consumer.md:18`**, item 22's. **Re-derive this set with the loop above rather than reading
it here** — an earlier revision hand-listed four of the five, in the paragraph that exists to keep
citations honest.

**THE AMBIGUOUS ONE IS THE LESSON: this repo has THREE `SKILL.md` files** (`ai-dlc/`,
`ai-dlc-setup/`, `ai-dlc-update/`), so a bare `SKILL.md` + line number resolves to whichever the reader
reaches first — and `ai-dlc-setup/SKILL.md` has 1065 lines, so the wrong pick reads as past-EOF
rather than as the wrong line. Every `SKILL.md` citation above is now written with its skill
directory. **A citation that a stranger cannot resolve unambiguously is not evidence**, which is the
same standard as one that cannot be located at all.

**FIVE citations point into the CONSUMER, not four.** `s301-stories-adversarial-p2.md:327`,
`s301-epics-repair-p5d.md:115`, `s301-stories-adversarial-p6.md:252`,
`s301-stories-repair-p5.md:581` — **the s301 close-out archived all four**, so they now live
under `_bmad-output/planning-artifacts/archive/s301-<series>/` rather than at the paths quoted; the
content is unchanged (`git mv` with per-file sha verification), only the prefix moved. The fifth is
**`tea-consumer.md:18`**, item 22's, which the old four-item list did not include — a hand-listed
set going stale, in the paragraph that exists to keep citations honest. Re-verify any citation
below it against the tree before acting on it.

**WHICH PLANS IN `docs/plans/` ARE LIVE: THIS ONE, AND ONLY THIS ONE.** Every other file there
is a DISCHARGED runbook and each now says so in its own title. They were all titled
"EXECUTE THIS" and five of them still carried status sections claiming work outstanding —
a fresh session pointed at the directory would have redone a landed pull. Do not execute
any of them; read them only as records.

**AND THAT SENTENCE WAS FALSE ABOUT ONE FILE UNTIL 2026-08-08, which is why it is worth
re-checking rather than trusting.** `s301-close-out-derivation.md` carried no banner while its
sibling `s301-close-out.md` did, and it opens *"Read this whole file before running anything… It
is a close-out procedure"* — executable on its face, for a sprint that is closed. Banner added.
**Verify the claim against `head -1` of every file in the directory before relying on it**; the
six-of-seven state is what a claim about a set looks like when the set is hand-checked.

Working repo: `/Users/n8/git/ai-dlc` (the distribution). Reference consumer:
`/Users/n8/git/graph` — **read it, never write it.** The operator owns every consumer-side
action: running `/ai-dlc-update`, merging its PR, retiring layer entries. House rules for this
repo are in `/Users/n8/git/ai-dlc/CLAUDE.md` and they bind: one version per branch cut from
`origin/main`; commit subject + `VERSION` + CHANGELOG heading are one claim; every absence
carries a same-run control; every mutant is a `cmp -s`-guarded copy with an unmutated control;
measure a new check's false-positive set before shipping it.

**OPERATOR STANDING DECISIONS, 2026-08-06. These override the per-step "ask first" notes
below, and a session following this file must not re-ask them.**

- **Merges are preapproved for the duration of this plan.** Cut the branch from `origin/main`,
  open the PR, and merge it. Do not stop for merge approval on any release in this file.
- **Do not pause between releases.** Run release to release without checking in unless the
  operator is genuinely needed for a decision this file does not already record. Starting a
  fresh session when context fidelity degrades is expected and cheap; pausing is not.
- **s301 is being CLOSED and re-run from scratch as s302**, the way s300 was, and s302 does not
  start until everything in this plan has landed and been pulled. The operator accepts the
  rework because the re-run is itself the control test: it measures whether these changes have
  their intended effect on a sprint that has already failed once without them. A close-out
  prompt for the graph session is owed as part of this work.

**`git branch --no-merged origin/main` LISTS 17 BRANCHES AND NONE OF THEM IS PARKED WORK.**
This repo squash-merges, which rewrites the commit and breaks ancestry, so every branch it has
ever merged reports as unmerged forever. Measured before this was written: four sampled at
random — `v0.283.0`, `v0.288.0`, `v0.225.0`, `v0.57.0` — all have their CHANGELOG heading on
`main` (control: a fabricated `0.999.0` returns 0). **Do not read that list as a backlog, and
do not re-derive this**; two of those branch names are still described as "parked" further down
this file, in sections that predate their release.

**NOTHING IS IN FLIGHT. No branch is parked.** Working tree clean, and every release this plan
produced is merged. **Read the current version from `VERSION`, never from this sentence** — it
carried `0.319.0` for exactly as long as it took the next release to land — the table under §*Where things stand*
lists them with their PR numbers. **Count them there; do not carry a number in this sentence.**
It said "eighteen" for eighteen releases after that stopped being true, which is the same
underived-count defect core Rule 31 exists for, in the file that documents it. The previously-parked F3 branch shipped after two
renumbers (0.288.0 → 0.289.0 → its final slot) once item 11 unblocked it.

**THE 2026-08-09 CONSUMER RUN IS THE MOST RECENT MEASUREMENT AND IT PRODUCED TWO CORE RELEASES.**
Their completion report disagreed with two figures this repo had written into their runbook, and
**both times the consumer was right and the instrument here was wrong** — v0.339.0 (`W11`'s slot
exemption was a hand-list of two spellings, so the clause flagged its own prescribed rewrite on 7 of
7 rows) and v0.340.0 (`ledger-reverify` ran `verify: sh` receipts at the CALLER's cwd, so a run from
this side proposed closing a live entry). **Neither was visible from this side without re-running
the measurement against their tree**, which is the standing lesson: a report that contradicts a
figure here is a measurement, not a mistake to correct.

**GRAPH IS CURRENT AT `0.341.0 / 899411a` ON ALL FOUR FIELDS, re-read 2026-08-09 and unchanged, read 2026-08-09 after their #906.**
**Read the stamp; do not carry that sha** — the derivation is one line below and this paragraph has
named a wrong one twice.

**~~THREE releases have landed here since~~ ~~A pull is owed~~ — THE PULL RAN AND MERGED
2026-08-10. GRAPH IS CURRENT AT `0.345.0 / 959caa8` ON ALL FOUR FIELDS.** Their #907 (machinery
self-update) and #908 (gated reconcile); gate verdict `SELF-UPDATE-OK`. **Verified from this side
rather than accepted:** 11 of 11 shipped files byte-identical to the distribution (control: an
unrelated pair reports DIFF), and both new fixtures driven against their own installed copies
return `PASS`. The runbook [`graph-0341-to-0344-pull.md`](graph-0341-to-0344-pull.md) (#507, #509)
is **SPENT** and its own header now records the one thing it got wrong.

**A FOURTH RELEASE ENTERED THE RANGE MID-RUN, FROM THE CONSUMER, AND IT IS THE SHAPE TO EXPECT.**
v0.345.0 (#508): they reported that `apply-drift-after-write/seed.sh` resolved its schema only in
the distribution layout and exited 2 on every consumer — reproduced here on a tree built by running
`install.sh` into an empty directory, which is the check this repo's rules require and which
v0.343.0 did not get. **All 122 shipped fixtures were then run in the consumer layout: 119 green, 1
red, theirs.** I33 and I33b both returned zero on it, and the reason is not only the `cd`/`pwd`
spelling — **both invariants check WHERE a chain is rooted and neither checked that BOTH LAYOUTS
are named**, while that is the remedy both of them prescribe. I33c closes the second half.

**THE ACTION-0 MEASUREMENT IS WORTH KEEPING AS A RECORD.** Before the pull, graph's pause flag and
snapshot were both present and their installed acknowledge hook was byte-identical to `0.341.0`'s —
so an agent-driven `/ai-dlc-update` was denied at its first dispatch, measured by driving their own
installed copy against the new fixture's scratch tree. v0.344.0 was the fix and could not help the
run that carried it. **That is now discharged and cannot recur on that consumer.**

**GRAPH'S STAMP — READ IT, DO NOT CARRY IT.** Every prior revision of this paragraph named a
version that was wrong within a day; the derivation is the durable part.
`sed -n '1,4p' /Users/n8/git/graph/.claude/.ai-dlc-version` gives all four fields, and all four
must agree unless a slice is mid-flight. **Read 2026-08-09, later the same day: the four fields
DISAGREE — `version: 0.338.0 / commit: 5e49f08` against `skill_version: 0.340.0 /
skill_commit: fb20046`.** That is a pull IN FLIGHT, not drift: their #905 took the self-update
(machinery) hop and the reconcile (rulebook) hop has not landed.

**THE DIVERGENCE POINTS THE OTHER WAY FROM THE ONE THIS PARAGRAPH USED TO DESCRIBE, so do not
match it against the old sentence and conclude it is the known-benign case.** The documented
legitimate split is skill fields BEHIND — a run whose machinery slice was empty, where
`--carried-machinery-slice` is correctly not passed. Here the skill fields are two releases AHEAD.
Read which side is ahead, not merely that they differ.

**~~A PULL IS OWED~~ ~~TAKEN 2026-08-09, all four fields at `0.338.0 / 5e49f08`~~ — A FURTHER PULL
IS IN FLIGHT AND IS HALF-LANDED, measured 2026-08-09.** Their #901/#902 took `0.338.0`, #903 the
`W11` repaths, #904 the byproduct re-home plus a consolidation pass. **Then #905 took the
self-update hop of `0.338.0` → `0.340.0` WITHOUT a runbook from this side, and it carried the
entire shipped payload** — all 9 `core/` files in the range, verified byte-identical against the
distribution with a control that an unrelated pair reports DIFF. **The reconcile hop has not
landed**, which is the whole of the stamp split above.

**IT IS BLOCKED ON AN OPERATOR ANSWER, AND THE GRAPH SESSION HAS ALREADY WRITTEN THE RESOLUTION.**
`_bmad-output/ai-dlc-update/blocker-adjudication-20260809T145920Z.md` (untracked on their tree)
records 1 of 1 blockers — `HARD-LAYER-ADJUDICATION-MISSING` on
`overrides/steps__retro__domain-sections.md`, LC-O15 — recommends `still-additive` re-declaring
`OWED-RETRO-4A-NARROW`, and carries the fully-resolved register line. **Its own readiness line reads
`NOT ready to apply.`** Nothing else gates: zero deletions, zero semantic merges, zero template
merges, zero catalog collisions. **This is the operator's, not this repo's** — read it there rather
than re-deriving it here.

**~~THE OPERATOR HAS RULED THAT HOP WILL NOT BE FINISHED~~ — THE PULL RAN AND IS COMPLETE.** Their
#906 (squash `3a9e216c8`) took `0.338.0` → `0.341.0` in **one hop** from the half-landed start state,
and the split stamp resolved through the tool's own `ALREADY-AT-THEIRS` subtraction — never
hand-edited, which is what the runbook asked for. Verified from this side rather than accepted:
all four stamp fields read `0.341.0 / 899411a`, and the four files that were new to them are
byte-identical to the distribution (control: an unrelated pair reports DIFF).
The runbook [`graph-0338-to-0341-pull.md`](graph-0338-to-0341-pull.md) (#500) is **SPENT**.

**THEIR REPORT'S OWN NUMBERS, re-run against merged main by them and not just the branch:** fixture
`PASS`, `sprint-id` 302, `VERDICT: PASS` on artifact paths, `0 error(s), 2 warning(s)` on layers,
`0 HARD blockers`. Three `HARD-LAYER-ADJUDICATION-MISSING` rows were adjudicated `still-additive` —
the LC-O15 one this repo predicted would survive the wider range, plus **two LC-E4 rows on
`route-domain.md` and `route-push.md` that it did not predict**, and which follow from `route.md`
moving. Predicting one adjudication and getting three is the same class of miss as predicting a hop
count.

**THE RUN RETURNED THREE UPSTREAM DEFECTS, each citing the command that found it and each declaring
what it did NOT verify.** All three reproduced here against the code. Two shipped the same day —
**v0.342.0 (#502)** and **v0.343.0 (#503)**. The third is unresolved and is item 6 of the
next-action list, where it is written up with the derivation it still needs.

The runbook [`graph-0335-to-0337-pull.md`](graph-0335-to-0337-pull.md) is **SPENT**;
its own header records what it got wrong. Do not re-point it at a new range; write a fresh one.
Original text follows.
**Its filename says `0337` and HEAD has since moved to `0.338.0`; the file is not renamed per release
and says why.** `v0.338.0` ships nothing to a consumer — its whole diff is distribution-only
(`scripts/validate-plan-shape.sh`, a `.dist-only` fixture) plus `CLAUDE.md`/`CHANGELOG`/`VERSION` —
so the shipped set is unchanged at five files. It is the
operator's to hand to a graph session; nothing in it is this repo's to run. **Do not predict the hop
count from this side** — the runbook says the same thing and for the same reason. The previous
runbook,
[`graph-0330-to-0335-pull-and-homing.md`](graph-0330-to-0335-pull-and-homing.md), is **SPENT** — it
ran, all five steps completed, and its own header now records the three things it got wrong. Do not
re-point it at a new range; write a fresh one.

**THE BASE IS `b324779`, AND CONFIRM IT BEFORE DERIVING ANYTHING.** This paragraph has now named
the wrong base twice — once carrying `9fc216e` after the 0.330.0 pull had landed, and once telling
the operator the range was `0.330.0 → 0.337.0` after the graph session had already taken it to
`0.335.0`. Both times the stamp was one command away:
`sed -n '1,4p' /Users/n8/git/graph/.claude/.ai-dlc-version`. **Read it; do not carry this number.**

**Scope, derived 2026-08-09 against `b324779` — re-derive rather than reuse:** 5 `core/` files
(`ai-dlc-update/SKILL.md`, `reconcile/apply.sh`, `reconcile/ledger-rotate.sh`, and two fixtures),
plus `VERSION`, `CHANGELOG.md`, `CLAUDE.md` and one `docs/` path. **No rulebook file moves, no
`layer-contract.yaml` change** (`contract_version` stays 18, already applied there), and **no
adjudication digest input moves** — zero paths under `steps/`, `SKILL.md` or `team-roles/`.

**THE REASON TO TAKE IT IS NOT COSMETIC: graph's INSTALLED `ledger-rotate.sh` still archives a live
entry.** Measured 2026-08-09 against their own copy under `.claude/`: **1 closed entry would move**,
and it is `PC-S330` — a live push candidate. The distribution copy on the same ledger reports **0**.
Until this pull lands, `--apply` on that consumer is destructive. See §*What the graph session's
report measured*.

**AND EXPECT A NEW BLOCK OF WARNINGS — 12 OF THEM — WHICH ARE NOT A REGRESSION.** v0.333.0 adds
`LC-R4`/`W11`: an artifact path a layer entry PRESCRIBES is held to the path grammar. Run against
graph's layer from this side: **76 prescriptions read across 4 scan roots, 12 non-conforming in 10
entries, 0 false positives.** Eight are `docs/retro/sprint-<N>.md` citations whose files are gone
and whose slotted forms exist — the tree migrated and the prose did not. **Nothing blocks**: the
clause is WARN and every remedy is an edit to prose the operator owns. `contract_version` also goes
17 → 18, so all 43 entries report `behind` — they already did (`at_current=0`), and the delta is
one clause on the migration worklist.

**WHAT THE OPERATOR SHOULD EXPECT TO SEE FROM IT, and it is the reason to take it:**
`ledger-rotate.sh` will start naming the entries that are closed for re-verification but not
archivable. It counted **8** on graph at `0.329.0` while the same run printed
`0 closed entries — nothing to rotate`. Those 8 are not new damage; they are a state that has been
accumulating invisibly and now has a row.

**TWO HOMING JOBS ARE STILL OWED, both small, neither blocking. VERIFIED STILL OPEN 2026-08-09,
not carried from the paragraph that first recorded them:** `s299/locked-requirements.md` does not
exist and the live brief still carries **6** `LOCKED_REQUIREMENTS` mentions; the brief still
carries its `## Changelog` section and no `s<N>/changelog-product-brief.md` exists. **Nothing
breaks before either is done** — the legacy `product-brief.md` is still an accepted source of
record, and the changelog change governs future passes only.

**~~A THIRD HOMING JOB — the stray `test-strategy.md` at the area root.~~ DONE, verified from this
side 2026-08-09:** the root copy is gone and `s272/test-strategy.md` exists. That was the one with
a deadline (Check 23 at s302's first planning gate), so **s302's planning gate is now clear**.

**~~THE SKILL STAMP AGREEING IS A HAND-FIX, NOT A WORKING MECHANISM.~~ FIXED — v0.320.0 (item 27).**
The operator set `skill_version`/`skill_commit` by hand during the 0.319.0 apply because `apply.sh`
never wrote them. It writes them now, on the one run that may claim them:
`apply.sh --carried-machinery-slice`. **The stamp on this consumer is already correct, so this
release changes nothing there and is owed to the NEXT deferred-slice pull** — do not expect a
visible difference on graph from it. s301 is closed; s302 has not started but MAY now start.

**~~FOUR THINGS CARRIED FORWARD BY THE 0.318.0 PULL~~ — SPENT 2026-08-09, kept as the record.**
The `#4a` narrowing is still tracked by `OWED-RETRO-4A-NARROW` and is now item 26's subject; layer
debt has moved (**10 OPEN / 8 UNDECLARED** at the 0.329.0 pull, the newest UNDECLARED row being a
verdict the operator wrote that names debt in prose without an `owed` object); the `921.`/`20.`
retire-or-refile call is still open; and `PC-S318` has since been joined by `PC-S320`, `PC-S326`,
`PC-S327`, `PC-S328` and `PC-S329`, **five of which this repo has already answered** — see
§*The consumer-reported defect run*. Original text follows.
Reported by
the operator and recorded here so a later session does not read them as this repo's queue:
the `#4a` anchor **stays** (`OWED-RETRO-4A-NARROW` tracks the narrowing); layer debt at **9 OPEN /
8 UNDECLARED**; `gate-validation-push.md`'s `921.`/`20.` duplication awaiting a **retire-or-refile**
call; and **`PC-S318` filed against upstream's slice derivation**. **The last of those is the only
one facing THIS repo** — it is a push candidate, it is not adjudicated here yet, and it belongs to
the next push-candidate triage rather than to any item below.

**THE MIGRATION RAN. The five numbers, as reported and worth not re-deriving:**

```
moves applied / files scanned   2667 of 2667, verified per file, from 5148 tracked scanned
independent triple              2667 R and nothing else; zero content changes; 9929 tracked
                                before and after  <- run because the script's own verdict is
                                                     not evidence
REFUSED                           48   45 AMBIGUOUS, 3 NO-AREA — all left, none dispositioned
DEFERRED                        1001   stories/, untouched, as the plan directs
AREAS INFERRED                     9   NOT the 8 core predicted
SELF-CHECK                         0   destinations carrying a sprint token outside the slot
                                       second dry run exits 3
```

**The 48 refusals are NOT blockers and are NOT done.** Resolving them means renaming basenames and
deciding an area — separate work, still owed, nobody's critical path.

**The pull took THREE hops and four PRs** (graph's #878–#881), not the two the runbook predicted.
That file had already been wrong the other way once. **Stop predicting hop counts from this side.**

**And ai-dlc moved DURING that pull:****And ai-dlc moved DURING that pull:** `0.301.0`, `0.302.0` and `0.303.0` all landed after the
operator started, so a further hop is owed beyond whatever 8b lands on.

**s302 IS NO LONGER A DEADLINE, by operator direction 2026-08-07.** Earlier revisions of this
file treated "s302 is held until item 10 lands" as the thing setting the pace, and item 10's
own section still argues from it. That pressure is withdrawn: *"We don't need to start s302 in
graph right away so I'd prefer to keep plowing through the plan."* Item 10's technical
sequencing constraints are unchanged and still binding — 10b before any migration, readers and
writers together — but "get it done before s302" is not a reason to cut corners on any of them.
Work the order below to completion instead of racing a sprint that is not waiting.

**SEVEN consumer obligations are now open, and NONE GATES ANYTHING** — the 0.314.0 pull recorded
`OWED-RETRO-4A-NARROW` beside the six that existed. All are enumerable in graph's debt audit and
all are re-raised by every pull until discharged. The paragraph below names the two this plan
was tracking and is otherwise unchanged.

**Two consumer obligations are open and NEITHER GATES ANYTHING** — `OWED-DEVPUSH-RESTATES-CORE`
and `OWED-STS-DOMAIN-AB-ABSORBED`, both enumerable in graph's debt audit, both re-raised by every
pull until discharged. The `dev-push.md` split is the real work behind the first. It is
consumer-side, bounded, and deliberately NOT scheduled here: it blocks nothing, and opening a
graph session for it while item 10 is the critical path is churn. Take it when graph is next
open for another reason.

**~~NEXT ACTION: … 10c~~ / ~~10d~~ — BOTH DONE** (v0.299.0 #411, v0.300.0 #412).

**THE CRITICAL PATH IS NOW THE OPERATOR'S, AND IT IS RUNBOOKED.** Everything a graph session needs
is in [`graph-artifact-path-pull-and-migration.md`](graph-artifact-path-pull-and-migration.md),
merged as #413. The operator pastes one line into a graph session; nothing there needs this repo.
**10e cannot ship until that has run once** — a validator landing on ~2700 non-conforming files
wedges first contact.

**~~NEXT ACTION FOR THIS REPO: item 16~~ — DONE.** v0.307.0 (#427) moved the READERS, v0.308.0
(#428) moved the FILES. Both merged, nothing in flight. See §*What item 16 measured*.

**AND THIS PLAN'S OWN FIGURES FOR IT WERE WRONG IN BOTH DIRECTIONS, so do not reuse them.** The
flat corpus is **988** files, not 1001 and not 1024 — 1025 is the count under *any* `stories/`
directory and 25 of those already sat under `s<N>/`. The bare-leading-number share is **781**, not
761. The difficulty this file predicted was also the wrong one: the ambiguity is real in the NAME
and was never in the POSITION, and one line of that realisation replaced the whole deferral.

**~~NEXT ACTION FOR THIS REPO: item 18~~ — DONE.** v0.309.0 (#430). Reproduced at ground truth
with a control, and **half its attribution was wrong the same way item 17's was**: `setup-sites.md`
is not in that script's scan set at all. See §*What item 18 measured*.

**~~NEXT ACTION FOR THIS REPO: item 8~~ — CORE'S HALF IS DONE.** v0.310.0 (#432). The re-verify
surfaced exactly one CLOSE-CANDIDATE and it was FALSE — a migration-moved receipt subject. See
§*What item 8's core half measured*. **What remains of item 8 is the OPERATOR's** and is stated
there: 24 of 24 `theirs_has` receipts are undecided, so the 53 STILL-LIVE set is still not a work
queue.

**~~NEXT ACTION FOR THIS REPO: item 6~~ — DONE.** Four releases: v0.311.0 (#434), v0.312.0 (#435),
v0.313.0 (#436), v0.314.0 (#437). **The gate was takeable and BOTH of its zeros were unreadable,
in different ways** — one FALSE, one a SILENCE — and taking the measurement first is the only
reason the promotion is worth anything. It also surfaced two defects in `apply.sh` that had nothing
to do with item 6 and everything to do with whether ANY of this reaches the operator. See
§*What item 6 measured*.

**~~NEXT ACTION FOR THE OPERATOR: take the 0.300.0 → 0.314.0 pull~~ — DONE 2026-08-08.** 18
adjudications recorded, all with verdicts; one new obligation (`OWED-RETRO-4A-NARROW`) beside
6 pre-existing. One authorised `--no-verify`, naming the unit and its EXIT=2, for the fixture
item 20 records. **The session caught a blocker it had reintroduced itself** — editing an
entry after recording its verdict spends that verdict, because the digest covers the entry;
re-recorded against the moved subject. That is the digest design working, and it is the
reason the done-when list is re-run post-merge rather than remembered.

**~~A PULL IS OWED~~ ~~NO PULL IS OWED. Both were taken 2026-08-08~~ — A PULL IS OWED AGAIN, to
0.323.0.** The two that were taken (0.318.0 via #885/#886, then 0.319.0 via #887) left graph current
at the time, and four releases have landed since. **The scope and the two homing jobs are in the
status block above; do not re-derive them from this paragraph.** What follows is kept only as the
record of what those pulls delivered and of two predictions worth not repeating.

**THE 0.319.0 PULL'S DEFERRED MACHINERY SLICE LANDED WITH THE RULEBOOK ON ONE BRANCH, WHICH IS WHAT
THE DEFER WAS FOR.** The full pre-push fixture suite went green with machinery and rulebook together
— the outcome the split ordering could not have produced. Recorded because this plan twice predicted
hop counts from the distribution side and was twice wrong; the rule stands unchanged: **run the dry
run and read what the gate says.**

**ONE THING THAT PULL CARRIED IS STILL OWED, AND IT IS A HOMING JOB, NOT A DELETE.** The step now writes its four working files to `_bmad-output/planning-artifacts/s<N>/` and
deletes its drafts at Step 6. **That governs FUTURE passes only.** The 33 byproduct files already at
graph's area root must be MOVED into the sprint slot of the pass that produced them, never removed:
older coverage reports cite draft paths as their no-loss evidence, so deleting them breaks a record
that was already written. **~~The full 33-row derivation … with the
destination slot for each — is in §*What item 23b measured*~~ — THAT SENTENCE WAS FALSE, and it was
false in the way a handoff cannot afford.** That section carries the AGGREGATE (33 / 24 direct /
9 inferred / 0 refused) and the list of destination slots; **it never carried the per-file mapping**,
so a session sent there to do the re-home would have found a summary of a table and nothing to act
on. The two instruments that get it wrong ARE written into the step itself — that half was true.

**AND THE PASS ITSELF IS SCHEDULED IN THE RUNBOOK, ON `carry-over-backlog.md`. Two operator
challenges got it there and I was wrong twice on the way.** First I put the pass at s302's kickoff;
the step says *"Run it at a quiescent point (between sprints), not mid-pipeline"* and *"the snapshot
may hold a sprint that has closed, or one that has not started"*, so the moment is NOW. The
entanglement I claimed with the early roll does not exist either: `sprint-id` returns 302 today and
would have returned 302 without the roll, because `status: done` takes rule 3's `sprint + 1`. Then I
made it conditional on the budget — **also wrong: the threshold is what makes the retro RECOMMEND a
pass, not a precondition for running one.** The step's rule is *"the operator runs it on demand,
naming the target artifact."*

**THE TARGET IS MEASURED, NOT "THE BIGGEST".** Sprint-scoped headings, the accretion signature item
19 identified: `carry-over-backlog.md` **58**, `product-brief.md` 3 (the one #900 drained),
`docs/architecture.md` 1, `prd.md` 0, control `sprint-status.yaml` 0. Its `-archive.md` companion
already exists, so the no-loss destination is ready. **The done-whens deliberately do not include a
size drop** — a pass run for fidelity rather than for a breach may reduce very little, and a
criterion requiring the pool to fall would fail a correct pass. What they DO assert is v0.319.0:
zero working files at the area root, both drafts gone after Step 6.

**AND THE PASS SPENDS THIS PLAN'S OWN "s302 HAS NOT STARTED" INSTRUMENT.** It writes into `s302/`,
so that directory will exist afterwards. The sprint still will not have started; **the empty
`stories:` mapping is the surviving evidence** and this plan's §*THE NEXT ACTION* paragraph should be
read that way from now on.

**The one `OVER` row on that consumer is `pipeline-continuation-log.md` at 314%, whose remedy is
ROTATE and which the step excludes by name-class** — it was 309% when the spent runbook called it
unrelated, so it is growing and it is now named as outstanding rather than as noise.

**RE-DERIVED 2026-08-09 and now written into the runbook's §4 as a per-file table**, which is where a
consumer session can use it. It came out **32, not 33** (the plan measured at an older sha), and the
DIRECT/INFERRED split **15/17, not 24/9** — the earlier derivation resolved inferred rows against a
subject-derived sprint timeline by ancestry position, the new one walks first-parent to the nearest
sprint-naming subject. **11 of the 13 destination slots reappear unchanged**, which is the agreement
that matters, since the SLOT is what the move acts on. All 32 destinations are free, checked with a
control that a real collision is detectable. Nothing about this blocks; it is bookkeeping the
operator can take whenever graph is next open, and it is now step 5 of the pull runbook.

**~~The pull carries four things worth naming for the operator~~ — DISCHARGED, kept as the record of
what the 0.318.0 pull delivered:**

- **item 20's fixture fix (v0.315.0)**, verified by running that fixture from graph's own
  `tests/fixtures/`.
- **item 21's self-overwrite fix (v0.316.0)**, which **protects the pull AFTER this one, not this
  one** — the driver that ran during that pull was the copy graph already had. **That protection is
  now live for the v0.319.0 pull.**
- **item 23a's two budget fixes (v0.317.0, v0.318.0).** Predicted: the budget row goes from
  `OVER … 417% of it → consolidate` to `ok … (pool 330,000, 35% of it)`. **CONFIRMED against graph's
  own installed validator after the pull** — `ok  WHOLE-READ POOL (4 planning artifacts)  117379 tok
  (pool 330000, 35% of it)`. That was the CORRECTION, not a threshold being relaxed, and **no
  consolidation was or is owed on the strength of that row.** See §*What item 23a measured*.

**SUPERSEDED, kept for the runbook it points at.** Runbook:
[`graph-0300-to-0314-pull.md`](graph-0300-to-0314-pull.md). **The reason is not the diff size** —
graph migrated 2667 artifacts onto the path grammar and has NO validator enforcing it, because
that shipped in v0.305.0 and graph is at 0.300.0. Measured with a control: core has
`core/scripts/validate-artifact-paths.sh`, graph has neither the script nor a pre-push reference
to it, while a control validator (`validate-draft-stamps.sh`) IS present. Every artifact written
in graph since the migration is unchecked, and s302 would start that way.

**Expect exactly one NEW blocking row and do not read it as a regression:**
`HARD-LAYER-ADJUDICATION-MISSING` on `overrides/steps__retro__domain-sections.md`, because
v0.314.0 promoted LC-O15. Graph's count goes 12 → 13. The runbook states both legitimate verdicts
and why `--stamp retire` is the WRONG remedy there.

**~~NEXT ACTION FOR THIS REPO: item 19~~ — DONE 2026-08-08.** The finding is
[`docs/reviews/graph-artifact-consolidation-review.md`](../reviews/graph-artifact-consolidation-review.md).
**No release**, by the item's own terms. Three different operations are called "consolidation" and
the item's text ran two of them together; the counterfactual is settled (**96.1%** reduction, 12.0 MB
→ 470 KB) and the defects are all in the RESIDUE and all core's. See §*What item 19 measured*.

**~~ITEM 21~~ — DONE.** v0.316.0. `apply.sh` overwrote itself mid-run; **REPRODUCED at ground
truth with a control** and the report's attribution is EXACT — the second in a row, after three
that named the wrong program. See §*What item 21 measured*.

**~~NEXT ACTION FOR THIS REPO: item 23a~~ — DONE 2026-08-08, and THE ANSWER IS YES: graph already
passes.** Two releases: v0.317.0 (#449), v0.318.0 (#450). The finding is
[`docs/reviews/graph-artifact-budget-attainability.md`](../reviews/graph-artifact-budget-attainability.md).
**The 417% breach was an INSTRUMENT READING, not a size**, and both numbers in it were wrong,
independently, in the same direction — the pool understated 5x by a resolver reading a role-file
line format deleted at v0.174.0, the sum overstated 2.35x by a basename sweep counting 26 archived
copies. Corrected on both sides the four live artifacts are **36% of the pool**. See §*What item 23a
measured*. **Do not reuse this plan's "178% / the answer looks like no" framing anywhere below** —
it is refuted, and the paragraph that carried it is struck in item 23's own text.

**~~NEXT ACTION FOR THIS REPO: item 23b~~ — DONE 2026-08-08. v0.319.0 (#452).** The step now homes
all four working files in `s<N>/` and retires the drafts at a new Step 6. **The re-home refusal set
the item demanded is EMPTY — all 33 resolve**, 24 directly from the adding commit's own subject, and
the plan's *"at least two carry no recoverable sprint (they say `S999`)"* is refuted: `S999` is
content in a carry-over ID list, and a byproduct's sprint was never in its content. Two measurement
traps fell out and are recorded in the step itself. See §*What item 23b measured*.

**~~NEXT ACTION FOR THIS REPO: item 23d~~ — DECIDED 2026-08-08: NO. No release, and NOTHING is added
to §*Order of execution*, which is what a "no" is supposed to look like under this item's own
terms.** `artifact-consolidation` stays a step. The item's own strongest argument FOR survived its
control — it is the only step `route.md` HANDS OVER rather than enters — but three of the four gains
a skill was said to bring buy nothing here, measured, and the decider is the subject boundary:
`ai-dlc-setup` and `ai-dlc-update` reference `planning-artifacts` **0** times each, the pipeline
**70**. See §*What item 23d decided*, **which also states the three things that would re-open it**,
so the answer is falsifiable rather than permanent.

**~~NEXT ACTION FOR THIS REPO: item 27~~ — DONE 2026-08-08. v0.320.0 (#458).** The fix is a flag,
`apply.sh --carried-machinery-slice`, with both contradicting prose sites now pointing at it instead
of at each other. **No new invariant was needed and that was PROVEN rather than assumed**: I60
already binds "prose names a mode the script does not dispatch", both sides derived, and mutating the
case arm's name makes it FAIL by name. The fixture gap the item named is measured — **0 fixtures
asserted either skill field after an apply, against a control of 3 assertions on the rulebook pair in
`apply-restamp-theirs` alone.** See §*What item 27 measured*.

**~~NEXT ACTION FOR THIS REPO: item 23c~~ — ITS DERIVATION IS DONE 2026-08-08, no release, and the
item's own stop condition is NOT met, so 23c proceeds.** The finding is
[`docs/reviews/artifact-inlet-locked-block-derivation.md`](../reviews/artifact-inlet-locked-block-derivation.md).
**The sites move cheaply and that was the wrong question on its own.** Of the four validators the
item named, `validate-spec-join.sh` is **not a site at all** (it anchors on the spec's `.memlog.md`),
`validate-request-coverage.sh` and `validate-artifact-budget.sh` move for free, and
`validate-locked-anchor.sh` moves on a one-word default because its SoR pin is a **basename equality
test**. **The step-file count is neither 10 nor derivable as 10** — 8 name the token, 13 name a
durable artifact by path. **THE ONE THING THE ITEM DID NOT NAME IS THE WORK:**
`validate-artifact-budget.sh:859` excludes every `s<N>/` path from the whole-read pool, so moving the
block into a sprint slot drops the pooled sum by three quarters of the brief **with the same bytes
still read whole at gate time** — the change would grade itself. **Do not reuse the item's two-part
framing ("the LOCKED block and changelog"); it is four changes** and the sequencing is in the table.
Item 12, item 22, item 26 and item 28 remain available and gate nothing. (Item 25 shipped as
v0.324.0; item 24 as v0.325.0.)

**~~NEXT ACTION FOR THIS REPO: 23c-1~~ — 23c-2 WAS TAKEN FIRST AND THE ORDER ABOVE WAS CORRECTED,
NOT IGNORED. v0.321.0 (#461).** Two things forced it, both measured after the derivation merged:

- **23c-1 has no subject until 23c-3 writes one.** The right pool change is not "stop exempting the
  live slot" — a live-slot copy of a POOLED basename (`s302/architecture.md`) is a snapshot of the
  durable artifact, and counting it double-counts; graph has 23 such copies historically, latest
  `s288`. The honest change is a second pool arm for a per-sprint whole-read basename in the LIVE
  slot only, and that basename does not exist until 23c-3. Shipping the arm first is a check with no
  subject on any consumer. **23c-1 and 23c-3 therefore ship together.**
- **23c-2 is graded by content leaving the whole-read path, not by the pool arm**, because nothing
  reads a changelog — so it needed nothing from 23c-1 and was clear to go first.

**AND ITS SIZE WAS OVERSTATED IN THE PARAGRAPH ABOVE.** "21% of graph's live brief" is true and
reads much larger than the pooled effect: across all durable artifacts the LIVE changelog total is
**260 lines** (223 brief, 37 `docs/architecture.md`, **0 `prd.md`**). The other ~9,800 changelog
lines are in `-history.md` files `is_archive()` already exempts. **23c-2's case is correctness, not
size** — the size is in 23c-3, which moves the brief's 564-line LOCKED section.

**~~NEXT ACTION FOR THIS REPO: 23c-3 together with 23c-1~~ — DONE 2026-08-08. v0.322.0 (#462).**
§4a writes `s<N>/locked-requirements.md` and the brief keeps a pointer; the SoR is now a PAIR
(`locked-requirements.md` + the legacy `product-brief.md`) because refusing the legacy name would
fail **31 of 62** anchored citations on the reference consumer, all resolvable and none defective;
and the pool gained `SPRINT_WHOLE_READ_SET`, resolved through `sprint-status.sh sprint-id` and
counted from the LIVE slot only. **The legacy name has a removal TEST, not a date** — the PASS line
counts the claims still at it. **Owed to the operator: ONE block** (S299, 169 lines) moved into
`s299/`, and nothing breaks until it is.

**~~NEXT ACTION FOR THIS REPO: 23c-4~~ — DONE 2026-08-08. v0.323.0 (#463). ITEM 23 IS CLOSED.**
The answer was RESOLVE, not refuse: `resolve_artifact` takes the anchor and tries the sibling
`s<n>/` first when it carries `LR-S<n>-`. **v0.322.0 had made the accident into a defect** — with
the block in the sprint slot, a `s302/` story citing `LR-S299-4` would have been told
`anchor not found`, a true statement about the wrong file. Nothing widened: a fabricated bullet
under a cross-sprint anchor still reds, asserted in the fixture.

## THE NEXT ACTION, AND IT IS THE ONLY LIVE ONE IN THIS FILE

**START HERE IF YOU ARE A FRESH SESSION.** Read §*Start here* above for the boundaries, then this
section, then the numbered list below. **Everything else in this file is either a record of
completed work or a scoped item you will be sent to by name.**

**EVERY OTHER PARAGRAPH IN THIS FILE THAT ANNOUNCES A `NEXT ACTION` IS STRUCK THROUGH.** They are
kept because each records what its item measured, and several correct a premise this plan got
wrong. **Do not act on any of them. This section is the live one**, and a `~~strikethrough~~` is
this file's only marker that an action is spent — check for it before acting on anything that looks
like an instruction.

**THE COUNT IS NOT WRITTEN HERE, DELIBERATELY.** It said "seventeen" for two releases after it
stopped being true — the underived-count defect core Rule 31 exists for, in the file that
documents it, in the paragraph warning about it. Derive it instead:
`grep -c 'NEXT ACTION'` minus `grep -c '~~NEXT ACTION'`, and every remaining occurrence must be a
HEADING or a POINTER to this section, not an instruction. Read them; do not count them.

**NOTHING IS IN FLIGHT AND NOTHING GATES.** Working tree clean, `main` == `origin/main`, every
branch this plan produced is merged. **Read the version from `VERSION`, never from this file.**
Item 23 is closed; §*Order of execution* lists what remains and none of it blocks any of the rest.

### The numbered next-action list

**Do these in the order that suits the session; none blocks another. Stop and re-measure before
building — this plan's own record is that a re-derivation changed the work in item 3, item 2b,
item 16, item 17, item 18 and item 23c.**

**ITEMS 1 AND 2 CLOSED 2026-08-09** — 1 without a release, because re-measuring found its subject
already delivered, and 2 as v0.341.0. **THE PULL THEN RAN AND RETURNED THREE NEW DEFECTS, which is
the channel this list has been fed by for the last eight releases.** All three have now shipped
(v0.342.0 #502, v0.343.0 #503, v0.344.0 #505). Item 5 remains OPTIONAL and unscheduled.

**THERE IS NO LIVE ITEM IN THIS FILE. What is outstanding is a PULL — graph is at `0.341.0` and
three releases have landed here since — and no runbook exists for it.** Writing one is the
operator's call; nothing in this file schedules it. **Do not read the empty list as "this plan is
finished"**: every one of the last nine releases entered through the consumer's completion report,
so the next item arrives when that pull runs.

6. **~~`ai-dlc-acknowledge.sh`'s updater carve-out never fires on an agent-driven run~~ — DONE
   2026-08-09. v0.344.0 (#505). THE FILED CAUSE WAS RIGHT AND THIS ITEM'S OWN COUNTER-EVIDENCE WAS
   WRONG.** The item held the fix on *"66 of 66 local sessions carrying a `Skill(ai-dlc-update)`
   tool_use also carry the human `<command-name>` marker, zero without"*. Re-derived over the same
   corpus, matching the tool_use as a STRUCTURED block (a `tool_use` content block whose `name` is
   `Skill`) rather than as two strings anywhere in one file: **66 carry the tool_use and 10 of them
   carry no marker at all**, eight of those carrying only `<command-name>/clear</command-name>`.
   **Two of the ten contain the hook's own grep PATTERN quoted as text**, which is one way a looser
   match manufactures the agreement this item recorded.

   **AND THE LIVE CAPTURE FOUND A THIRD THING NEITHER CANDIDATE MECHANISM PREDICTED**, which is why
   the item was right to demand it. A PreToolUse probe over two headless sessions, one per
   invocation path: a typed `/ai-dlc-update` writes the marker and produces **no `Skill` tool_use at
   all**; an agent-driven dispatch writes the marker **never**, and at that dispatch the transcript
   does not yet carry the tool_use line either (12 lines, both absent), which is flushed by the next
   tool call (17 lines, present). Control: the probe reads the marker on the typed arm, so the
   absences are real.

   So the fix is THREE disjoint arms, not one: `.tool_input.skill` for the dispatch, the serialized
   tool_use ORed into the transcript scan for the fan-out after it, and the `<command-name>` arm
   kept because it is the only signal a typed run produces. See §*What the PC-S331 carve-out
   measured*.

   **AND v0.344.0 MOVED ALL THREE OF THE ORIGINAL ITEM'S CITATIONS OFF THEIR SUBJECTS WHILE LEAVING
   EVERY ONE OF THEM IN RANGE** — the third recorded instance of the failure the citation-count loop
   is structurally unable to see, after v0.320.0 did it to item 27 and v0.341.0 to item 2. **The
   subjects today, found by grepping for them:** the transcript scan is
   `core/hooks/ai-dlc-acknowledge.sh:151` (it was `:111`), and the two consumption sites are `:200`
   and `:396` (they were `:151` and `:347`). The payload arm, which did not exist when the item was
   written, is at `:161`. **Do not re-cite from this paragraph either; it is a dated reading.**

   Original item text follows, unedited, because its instinct — do not write the fix until the
   mechanism is established — is what found both errors.

   **`ai-dlc-acknowledge.sh`'s updater carve-out never fires on an agent-driven run — AND THE
   FILED CAUSE IS NOT ESTABLISHED. Establish the mechanism BEFORE writing the fix.**

   **What is reported.** `PC-S331` (the acknowledge hook's updater carve-out being unreachable via
   the Skill tool). The hook exempts `/ai-dlc-update` sessions from the Rule 29 pause deny, and
   detects them by grepping the TRANSCRIPT for `<command-name>/ai-dlc-update</command-name>` —
   `core/hooks/ai-dlc-acknowledge.sh:111`, consumed at `:151` and `:347`. The consumer reports that
   marker is written when a HUMAN types the slash command and not when the agent invokes the skill
   through the `Skill` tool, so the first dispatch is always denied. **They observed the denial
   twice in one session, live, each time cleared by removing the pause flag and restoring it.**

   **WHAT I ESTABLISHED, and it makes the fix cheaper.** The hook is already a `PreToolUse` hook
   whose matcher includes `Skill` (read from the reference consumer's `settings.json`:
   `Agent|Task|Skill|TaskCreate|Write|Edit|MultiEdit|NotebookEdit`). And the payload field the
   consumer could not confirm **is `skill`** — verified against real captured payloads, not
   inferred: `"name":"Skill","input":{"skill":"ai-dlc-update","args":"apply"}`, with the bare
   `{"skill":"ai-dlc-update"}` form also present. So `.tool_input.skill` is readable at the deny
   site with no new lifecycle, which is the option the hook's own comments already prefer.

   **WHAT I COULD NOT REPRODUCE, AND IT IS THE REASON THIS IS NOT ALREADY FIXED.** Across 66 local
   sessions carrying a `Skill(ai-dlc-update)` tool_use, **every one of them also carries the human
   `<command-name>` marker. Zero sessions have the tool_use without the marker.** If the marker were
   simply absent on agent-driven runs there should be counterexamples, and there are none — so the
   reported cause is not confirmed, and two different mechanisms fit the same observation:

   - the marker is never written for an agent-driven invocation (the filed cause), or
   - the marker IS written, but not yet at the moment the `PreToolUse` hook runs for the FIRST
     dispatch — a read-before-write ordering problem, not a missing-signal one.

   **They have different fixes.** The first is fixed by reading `.tool_input.skill`. The second is
   fixed there too for the dispatch itself, but leaves every SUBSEQUENT `Write`/`Edit` in that
   session denied, because those are not `Skill` calls and the transcript arm is what covers them.
   **Do not write the fix until you know which.** This plan's own record is that a consumer-reported
   cause has been wrong in exactly the detail that decides the fix before.

   **START BY CAPTURING ONE LIVE PAYLOAD AND THE TRANSCRIPT STATE AT DENY TIME**, rather than by
   reasoning from the hook's source. The transcript records the `Skill` tool_use itself, so a
   session-level signal exists for agent-driven runs either way — that is the material for the
   second fix if the second mechanism is the real one.

   **ON THE RECEIPT, which the consumer argued about deliberately and correctly.** A `theirs_has`
   anchored on the transcript grep survives any fix that keeps that line and ORs in a second arm,
   which is the likeliest shape. A `theirs_lacks` on `tool_input.skill` returns 0 at theirs and 0
   across their tracked tree, so it is unfalsifiable and lints `NEEDS-REVIEW` forever. **After a fix
   that reads the payload, `theirs_has "tool_input.skill"` becomes checkable** — so the receipt is
   writable, but only against the fixed shape.

   **Forbidden remedy:** a marker file. The hook already argues against it on lifecycle grounds.

**A NEW ITEM ENTERS THIS LIST THE WAY THE LAST EIGHT RELEASES DID, from the consumer's completion
report rather than from this file.**

**THE NUMBERS BELOW ARE THIS LIST'S OWN AND THE TABLE IN §*Order of execution* CARRIES THE SAME
ITEMS, IN THE SAME ORDER.** They are two views of one sequence, not two sequences: this list says
what to do next, the table says where each item sits in the whole plan's history. **If they ever
disagree, the table is the one to fix** — every completed row in it is a receipt with a PR number,
and this list is derived from what is left.

**ITEMS 25, 24, 28 AND 22 SHIPPED (v0.324.0, v0.325.0, v0.331.0, v0.333.0) and have left this
list.** Their findings are in §*What item 25 measured*, §*What item 24 measured*, §*What item 28
measured* and [`docs/reviews/layer-entry-artifact-path-derivation.md`](../reviews/layer-entry-artifact-path-derivation.md),
and all four refuted their own item's central claim — twice the declaration the item said was missing
already existed and had a hole, and once the item named a candidate population that was one twelfth
of the real one. **That is the pattern to expect from what is left below**, not an accident.

**EVERY ORIGINAL ITEM ON THIS PLAN HAS SHIPPED OR BEEN DECIDED.** Item 22 CLOSED (derivation #474,
hoist v0.332.0 #475, clause `LC-R4`/`W11` v0.333.0 #477), item 26 CLOSED (v0.334.0 #478 — an arm is
NOT addressable, measured, so the row states the surplus instead), item 12 CLOSED (v0.335.0 #479 —
I87; the plan chose the wrong side to derive, and deriving the other one took 19 false positives to
0), item 28 CLOSED (v0.331.0 #473).

**WHAT IS BELOW CAME FROM THE CONSUMER, NOT FROM THIS PLAN.** v0.336.0 and v0.337.0 answered the
graph session's completion report; §*What the graph session's report measured* is the record. Five
of the last nine releases arrived through that channel rather than through this list, which is the
shape to expect.

1. **~~WRITE THE RUNBOOK FOR `0.338.0` → HEAD~~ — THE RANGE AS ITEM 1 FRAMED IT WAS SPENT BEFORE IT
   WAS WRITTEN, and the runbook that DOES exist covers a different one.** Measured 2026-08-09: the
   `0.338.0` → `0.340.0` pull ran without a runbook and its hop 1 carried the whole payload, so
   `graph-0338-to-0340-pull.md` was never written and must not be.

   **WHAT WAS WRITTEN INSTEAD, on operator direction 2026-08-09, is
   [`graph-0338-to-0341-pull.md`](graph-0338-to-0341-pull.md) (#500)** — 0 errors / 0 warnings from
   `validate-plan-shape.sh`. **The operator ruled that the in-flight reconcile hop will NOT be
   finished**, so graph's split stamp is that runbook's START STATE rather than a thing to clean up
   first. Its range is `5e49f08` → `91fde72`: 13 `core/` files, **9 already byte-identical on their
   tree** from their own #905, 4 new. **Do not re-derive that here; the runbook carries its own
   derivation and its own stamp confirmation.**

   **THE MEASUREMENT, because "the runbook is unnecessary" is the kind of claim that needs one.**
   The range `5e49f08` → `fb20046` is 14 files, 9 of them under `core/` (control: 5 non-core).
   Their #905 changed exactly those 9 on their tree, and all 9 are byte-identical to the
   distribution today — `cmp -s` on each mapped pair, 9 SAME / 0 DIFF, with a control that an
   unrelated pair reports DIFF. No fixture in the range is `.dist-only`, so the shipped set is the
   full 9.

   **BOTH DEFECTS THIS ITEM EXISTED TO DELIVER ARE ALREADY DEAD ON THEIR TREE, verified by running
   their own installed programs rather than by reading the diff.** v0.339.0: their validator now
   prints `77 artifact-path prescription(s) read across 4 scan root(s); 0 non-conforming` and
   `W11=LC-R4:0/43`, with total warnings **2** — `W6` and `W7`, exactly what this item predicted
   the post-pull state would be. v0.340.0: their installed `ledger-reverify.sh` is byte-identical
   to core's.

   **THE `W11` REPATH TABLE IN THE SPENT RUNBOOK IS STILL WRONG TO REUSE**, and the reason is now
   history rather than a warning: their 7 remaining rows were the clause's own false positives and
   they are gone without an edit.

   **THE TWO OPEN CONSUMER-SIDE ITEMS ARE STILL OPEN, re-measured rather than carried, and one
   figure moved:** `docs/qa/sprint-<N>/**` is unrepathed — **5** `sprint-<N>` directories, **0**
   slotted (control: a `zzz-*` pattern returns 0). `docs/reviews/` is **not** fully migrated
   either, which the old line implied: 126 slotted against **9** `sprint-*` directories and 2 files
   still at the old spelling. And `pipeline-continuation-log.md` is at **326%** of its budget
   (32697 tok against 10000), up from 322% — the remedy is `rotate`, which the consolidation step
   excludes by name-class. Neither is this repo's.

2. **~~FIX `sprint-status.sh`'s FREEZE PATH~~ — DONE 2026-08-09. v0.341.0 (#498).** Reproduced end
   to end before the fix and re-run after: the pre-fix writer froze to
   `sprint-status/sprint-301.yaml` and the real validator returned `FAIL — 1 blocking`; the fixed
   writer froze to `s301/sprint-status.yaml` and it returned `PASS`. **All three parts the item
   named were real, including the second one it warned a fix would miss** — the reader now takes
   both spellings, and a legacy freeze is honoured where it lies rather than duplicated into the
   slot. See §*What item 2 measured*.

   **EVERY `path:line` IN THE ORIGINAL ITEM TEXT BELOW NOW RESOLVES AND NONE OF THEM POINTS AT ITS
   SUBJECT** — the failure mode §*Start here* names and the one the citation-count loop is
   structurally unable to see. Three had already drifted before this release (the header comment was
   at `:64` not `:63`, `max_frozen` at `:271` not `:276`; only the writer at `:384` was exact), and
   v0.341.0 then moved all four. **The subjects today, found by grepping for them rather than by
   trusting a number, and recorded here so the block below can stay unedited as a record:** the
   writer is `core/scripts/sprint-status.sh:413`, the reader `max_frozen` is at `:304` with the new
   path helpers from `:265`, the header prose is at `:64`, and `route.md`'s roll command is at
   `:394` with the freeze prose just under it. **Do not re-cite from this paragraph either; it is a
   dated reading like every other figure in this file.** Original item text follows, unedited.

   **FIX `sprint-status.sh`'s FREEZE PATH. It is core's, it is measured, and it came out of item 2's
   precondition rather than off this list.** `core/scripts/sprint-status.sh:384` freezes a closed
   sprint to `<area>/sprint-status/sprint-<N>.yaml` — **the pre-migration form**, while core's own
   `migrate-artifact-paths.sh:375` maps exactly that path onto `<area>/s<N>/sprint-status.yaml` and
   `validate-artifact-paths.sh` BLOCKS on it. Probed with a control in one run: the old form is the
   single `BLOCKING` row, the migrated form in the same tree is not reported. The reference
   consumer's own pre-push runs that validator, so **the next genuine roll on a migrated consumer
   writes a path that fails their push.**

   Three parts, and the second is the one a fix will miss:

   - **The writer** at `core/scripts/sprint-status.sh:384`, plus the two prose sites that restate
     the old form (`core/scripts/sprint-status.sh:63` and
     `core/skills/ai-dlc/steps/route.md:400`) and `core/schemas/sprint-status.json`.
   - **The READER, `max_frozen` at `core/scripts/sprint-status.sh:276`,** which globs
     `sprint-status/sprint-*.yaml`. On a migrated consumer that directory holds only
     `_preamble.yaml`, so it already returns nothing — and its caller's fallback then returns
     sprint 1, *"which would silently re-stamp a live project as greenfield"*, in the words of the
     comment directly above it. It must read BOTH spellings: the old one still exists on every
     consumer that has not migrated.
   - **`core/fixtures/sprint-status-lifecycle/run.sh` asserts the old destination in three places**,
     and `core/fixtures/artifact-path-migration` asserts the migration MOVES it — that second one
     stays correct and is the control that the two spellings are a real pair, not a rename.

   **It is dormant on the reference consumer today** (their canonical carries `sprint:`, so the
   fallback never runs) and bites at s302's close. **Not urgent, and deliberately NOT folded into
   the 0.335.0 → 0.337.0 range** — that range is `ai-dlc-update` machinery only, which is what lets
   its runbook promise a self-update-shaped pull; `core/scripts/` in the slice is the case
   `core/skills/ai-dlc-update/SKILL.md:296` warns can strand a push.

3. **~~WRITE THE FRESH RUNBOOK — `0.335.0` → `0.337.0`~~ — DONE 2026-08-09, AND IT RAN.** See the
   SPENT runbook's own header for the three things it got wrong; two of them became v0.339.0 and
   v0.340.0.
   [`graph-0335-to-0337-pull.md`](graph-0335-to-0337-pull.md), 0 errors / 0 warnings from
   `validate-plan-shape.sh`. **THREE THINGS THIS LIST TOLD IT TO SAY WERE WRONG, all three found by
   running the derivation the item demanded:**

   - **"the migration DELETED both archived envelopes"** — it RENAMED them, and the parent claim was
     a diff read without `-M`. Both `s301/sprint-status.yaml` copies exist, 128 lines, `| 0` content
     change. That is what settled whether a reversal had a source at all: it does.
   - **"s302's kickoff roll will SILENTLY no-op"** — it prints `sprint-status: already at sprint 302
     (no-op)` and exits 0. The `if moved:` guard has an `else`, `core/scripts/sprint-status.sh:402`.
     Probed on a scratch tree with a control that rolls for real.
   - **"`PC-S331` will report `STILL-LIVE` against a defect that is fixed"** — the shipped reader
     returns `CLOSE-CANDIDATE`. Predicting a receipt's verdict from its anchor text is what went
     wrong; the reader was one run away.

   **AND THE REVERSAL THE ITEM ASKED FOR IS RECOMMENDED AGAINST, on the strength of item 1 above.**
   Reverting the early roll makes s302's kickoff roll for real, which writes the blocking path, which
   fails their pre-push, which they fix by moving it back to where it already is. The roll was early
   against core's own rule and its OUTCOME is nonetheless the state a correct roll would have left.
   **The call is the operator's and the runbook states it as theirs.**

   Original item text follows, kept because its instinct — establish the precondition before writing
   the reversal — is what surfaced item 1.

   **THE OPERATOR'S INSTRUCTION SAID `0.330.0 → 0.337.0` AND THAT RANGE IS WRONG — they were
   working from a summary of mine that quoted a stamp read BEFORE the graph session ran.** The pull
   landed; graph is at `0.335.0 / b324779`. **Confirm it yourself** rather than trusting this line:
   the same paragraph has now been wrong about the base twice.

   **ITS FIRST TODO IS NOT THE PULL. It is undoing a roll-forward this repo told them to do.**

   **WHY.** `docs/plans/s301-close-out.md` Commit 2 step 1 said *"Run `sprint-status.sh close`
   first, then `roll`"*, and the graph session did exactly that. **That instruction contradicts
   core's own rule**, stated in the script it invokes — `core/scripts/sprint-status.sh:63`:
   *"ROTATION HAPPENS AT PIPELINE START, NOT AT CLOSE… Rotating at start keeps the predecessor's
   terminal state readable exactly until its successor exists."* `core/skills/ai-dlc/steps/route.md:400`
   is where the roll belongs (this line read `steps/route.md:394` until 2026-08-09 — an unresolvable
   spelling of a real citation, which the plan-shape check cannot see because `steps/` is not a
   top-level directory here). **The same runbook refused to cut the s302 BRANCH three sentences later, for the
   identical reason** — so the rule was stated and then broken for the adjacent artifact.

   **THE COST, measured 2026-08-09.** `sprint-id` returns **302** while
   `planning-artifacts/s302/` does not exist (0 files, against 105 for `s301`) and `stories:` is
   empty. ~~And **s302's kickoff roll will silently no-op**: `sprint-status.sh:376` short-circuits on
   `sprint == target`, nothing is appended to `moved`, and the `if moved:` guard means it prints
   NOTHING — indistinguishable from a failure by an operator watching for `rolled forward to
   sprint 302`.~~ **REFUTED 2026-08-09: the guard has an `else`** at
   `core/scripts/sprint-status.sh:402` and the run prints `sprint-status: already at sprint 302
   (no-op)`. The short-circuit at `core/scripts/sprint-status.sh:375` is real; the silence was not.
   **The sprint slot is still the evidence of a started sprint** — that half stands.

   **~~AND A SECOND THING IS UNVERIFIED — DO NOT ACT ON IT, FINISH IT FIRST.~~ ESTABLISHED
   2026-08-09; all three questions answered, and the first sentence of it was wrong.** The roll
   commit `d1f3a1fe4` added `sprint-status/sprint-301.yaml` to BOTH trees (128 lines each). The
   artifact-path migration `dbe755181`, the SAME DAY, **RENAMED both — it did not delete them.**
   `git show -M` reports `{sprint-status/sprint-301.yaml => s301/sprint-status.yaml} | 0` for each
   view; the earlier "128 deletions each" was a diff read without rename detection, which is the
   same class as reading a declaration for a measurement. **Where:** both copies are at
   `_bmad-output/{planning,implementation}-artifacts/s301/sprint-status.yaml` today.
   **Intended:** yes — `core/scripts/migrate-artifact-paths.sh:375` maps that exact form.
   **What it costs at kickoff:** nothing on its own, and the real cost is item 1's — `roll` still
   composes the pre-migration name at `core/scripts/sprint-status.sh:384`, which the consumer's own
   pre-push validator blocks. Original text follows.
   Those
   archive directories now hold only `_preamble.yaml`, and `roll` composes that exact name at
   `sprint-status.sh:384`. **What I did not establish, and stopped rather than guess: where the
   migration moved them, whether that was intended, and what it costs at kickoff.** Establish that
   before writing the reversal, because it decides whether the reversal has a source to restore
   from at all.

   **The reversal itself is the OPERATOR's call, not core's**, and this repo may not write their
   tree. Offer it; do not assume it.

   **~~What the runbook must carry~~ — DISCHARGED; every bullet below is in the written file, and
   the fourth one is REFUTED there.** Kept as the record of what was asked for:

   - **The scope, DERIVED in the file**, with a control that separates `core/` from `docs/`. The
     figures in the status block above are a pointer, not an answer.
   - **The reason to take it, which is destructive-defect urgency, not housekeeping**: graph's
     INSTALLED `ledger-rotate.sh` still archives `PC-S330`, a live entry. Measured against their
     own copy: 1 would move, against 0 for the distribution copy on the same ledger.
   - **The three candidates it closes** — `PC-S329` (reconcile-log) is already a CLOSE-CANDIDATE at
     0.337.0, `PC-S330` and `PC-S331` are NAMED-UPSTREAM at 0.336.0. Their shipped
     `ledger-reverify` says so today; quote the run, do not predict it.
   - **The receipt re-anchoring the pull will make loud.** ~~`PC-S331`'s verify anchors on the prefix
     up to `UPSTREAM`, which the fix KEEPS, so it will report STILL-LIVE against a defect that is
     fixed.~~ **REFUTED — the shipped reader returns `CLOSE-CANDIDATE` for `PC-S331`.** This bullet
     predicted a verdict from the anchor text instead of running the reader that decides it, which
     is the defect the row three items above warns about. `PC-S330`'s anchors on comment text. The
     run already prints `RECEIPTS-UNDECIDED: 26 of
     26`, so this is a class and the runbook should say so rather than list two rows.
   - **NO NEW WARNINGS TO EXPECT.** `contract_version` stays 18 and `W11` is already applied there
     — it fires 12/43 on their tree today, unchanged by this range. Do not re-describe it as new.
   - **DONE-WHENS WHOSE PASS YOU HAVE RUN.** `CLAUDE.md` gained this rule because the SPENT runbook
     broke it twice in one file: *"budget green"* was unattainable when written and *"confirm each
     still resolves"* was unverifiable. Run each command, or state the expected FAIL and what makes
     it unrelated.

4. **~~The 12 `W11` repaths~~ — DONE (their #903), and 7 of the survivors were the CLAUSE's bug,
   not theirs.** See item 1. Original text follows.

   **The 12 `W11` repaths are the OPERATOR's and were IN the runbook as §3** — operator
   direction 2026-08-09, revising the earlier deferral: *"I'll be executing the runbook in a graph
   session, so doesn't it make sense to take them on?"* It does, and **the deferral had been
   misread here as "another session" when the reason on record was "another commit"** — a
   pull-review diff staying a pull-review diff is satisfied by a separate commit in the same
   session. **This line previously said "do not fold them into the runbook as work", which is what
   made the weaker reading look like a decision.**

   One measured constraint came with it, and it is the only ordering in that file: `adj_digest`
   (`core/skills/ai-dlc-update/reconcile/layer-drift.sh:519`) keys a recorded verdict on the entry
   file's blob plus its hooked core file, so editing an entry SPENDS its verdict — and **exactly one
   of the ten `W11` entries is an adjudicated subject**, `overrides/steps__retro__domain-sections.md`,
   derived by intersecting the `W11` list with `--list-adjudications` rather than by inspection.
   §3 therefore runs after the pull merges, and costs one re-adjudication on the following pull.

5. **A derivation, NOT a fix, on the receipt class — OPTIONAL and unscheduled.** **v0.340.0
   answered part of it**: one class of wrong `STILL-LIVE`/`CLOSE-CANDIDATE` was the reader's cwd,
   not the anchor text. The re-anchoring question is still open. Original text follows.
    `26 of 26
   theirs_has` receipts restating the previous run is the third appearance of this. Whether the
   remedy is core's (a receipt form that cannot anchor on text a fix keeps) or authoring discipline
   is unknown. **If you take it, run the SHIPPED reader from the first measurement** — see the
   warning below.

**THE OPERATOR'S SIDE, and none of it is yours to do.** Take the pull — the runbook exists,
[`graph-0335-to-0337-pull.md`](graph-0335-to-0337-pull.md), and it carries its own scope derivation
and its own stamp confirmation, so hand it over rather than re-deriving anything here. **Both
homing jobs are DONE** — the S299 LOCKED block and the brief's `## Changelog` landed in graph #900,
brief 1030 → 648 lines. The stray `test-strategy.md` was done earlier. **Nothing on this plan is
owed to them beyond the pull and the 12 `W11` repaths they deferred by choice.**

**Consumer-side items carried in graph's own ledger, not here, and none is this repo's:**
**`PC-S329-NAMED-UPSTREAM-…`**'s disposition — spell the SLUG, because the `PC-S329` prefix names
TWO live candidates and the other one (`…-APPLY-SH-NEVER-WRITES-THE-RECONCILE-LOG`) is answered by
v0.337.0; `PC-S312`'s receipt, which needs re-anchoring at `docs/retro/s249/retro.md` or it reports
`NEEDS-REVIEW` on every pull; the `921.`/`20.` retire-or-refile call, open across five reports now;
and the 48 refused artifact-path migrations plus the 33 byproduct files at the area root, both
unchanged. **Do not schedule work in this repo behind any of them.**

**s302 HAS NOT STARTED, AND IS NOT A DEADLINE** (operator direction 2026-08-07, confirmed
2026-08-09).

**DO NOT RE-DERIVE THIS FROM `sprint-status.yaml`. A previous revision of this line did, and got it
backwards.** That file reads `sprint: 302` / `status: in_progress`, and neither field means work has
begun: both are the state a ROLL-FORWARD leaves, by the commit that wrote them — *"close the S301
envelope as abandoned, roll forward to S302"*. `sprint: N` is the DECLARED currency
`artifact-path-grammar.md` exists to make total; it answers *which sprint do I write to*, never
*has that sprint begun*.

**The evidence of a started sprint is the SLOT, and it is one listing away:**
`_bmad-output/planning-artifacts/s302/` does not exist, 0 files against 105 for `s301` and 96 for
`s300`, and the `stories:` mapping is empty — a `grep -c story-302` returns 1 and that hit is the
COMMENT naming the key shape, which is the false positive to expect. Nothing on this plan is on its
critical path either way.
It MAY start whenever the operator chooses.

**THE PRIOR HANDOFF WORKED AND ITS LESSON IS WHY THIS SECTION EXISTS.** Item 27 and item 23c were
both handed to a fresh session with everything the work needed written into the item, and both ran
without re-opening anything above them. **What neither had was one place to start**: this file
carried its live next action in a paragraph indistinguishable in shape from sixteen spent ones.

**~~NEXT ACTION FOR THIS REPO: the `ledger-reverify.sh` defects item 8 surfaced.~~ DONE —
v0.301.0 (#415) and v0.302.0 (#416). Item 8c is CLOSED**, and re-verifying it enlarged the
finding: **three of the five `STILL-LIVE` verdicts were false, not one.** See §*What item 8c
measured*. Two things now sit with the OPERATOR, and neither is core's to do.

**~~NEXT ACTION FOR THIS REPO: item 6's UNMEASURED gate~~ — SUPERSEDED, and the paragraph below is
kept only because its instinct was right.** It said a first reading of **0 and 0** taken mid-pull
was UNUSABLE rather than an answer. The re-take, on a quiescent post-migration graph, returned
**0 and 0 again with a working control — and BOTH zeros were still unreadable.** LC-O15's was
FALSE (the join could not see a multi-anchor override, and graph carries one). LC-E6's was a
SILENCE (no fixture anywhere had ever made the code fire). A control proving the RUN worked says
nothing about whether the ARM could have fired. What follows is the original text.
A first reading taken during the pull returned **0 and 0** with a
working control (50 rows across 9 other statuses from the same run), and it is recorded here as
UNUSABLE rather than as an answer. Two things worth carrying into the re-take: LC-E6's code
`EXTENSION-RETIRE-CANDIDATE` has **`fixture: none`** in the contract — a declared I65 gap — so
before promoting it, establish that its code can fire at all, or the promotion promotes a clause
whose zero has never been shown to mean anything. LC-O15's `OVERRIDE-SUPERSEDED` has
`layer-readopt-gate` behind it.

**Item 13 was taken ahead of item 6 for exactly that reason** — it needed a scratch consumer, not
graph — and it shipped as v0.303.0.

## SPENT — session handoff of 2026-08-07, kept only for the two errors it records

**THIS IS NOT THE HANDOFF. The live one is §*THE NEXT ACTION, AND IT IS THE ONLY LIVE ONE IN THIS
FILE*, above.** This section was the handoff at `0.300.0` and every figure in it is superseded;
its title read live for eighteen releases, which is the same defect the discharged runbooks in
`docs/plans/` carried. **The two errors below are why it is kept at all** — both are of the class
this repo audits for, and both still bind.

**~~Nothing is in flight. The tree is clean, `main` is at `0.300.0` + #413, and every branch this
session cut is merged and deleted.~~ SUPERSEDED — read the status block under §*Start here*.**
A fresh session starts from `origin/main` with nothing parked, which is still true and is stated
where the reader is.

**TWO ERRORS THIS SESSION MADE, both of the class this repo audits for, recorded so the next one
does not repeat them:**

1. **"One hop, not two."** Told the operator the 0.292.0 → 0.300.0 pull was a single hop because
   `--safe-stop` exists. Backwards: `--safe-stop` exists to NAME the split, not to remove it. The
   operator's own dry run returned `SELF-UPDATE-DEFER rulebook-coupled-fixtures` and named
   `ef37564` (v0.297.0) as the stop. **Do not reason about a pull's shape from the distribution
   side; run the dry run and read what the gate says.**
2. **"Run `/ai-dlc-update`."** Bare is a DRY RUN. `apply` is the word that makes it act. Both
   errors were corrected in the runbook and the correction is stated in it rather than quietly
   patched.

**What a fresh session should NOT re-derive** — all of it is recorded below in this file:
`sprint-id` never fails and returns 1 for greenfield; `sprint-status.sh` resolves its root from
the process cwd without `--root`; the migration's 2667/48/1001 figures and their PRE-PULL caveat;
and item 8's blind-receipt finding.

### Order of execution

Re-sequenced 2026-08-07 on the operator's question *"should we close out sprint 301 and update
ai-dlc so we have a more current base?"* — the answer is yes, and re-deriving the order changed
more than that one item. **The prior order was wrong** and the reason it was wrong is worth
keeping: it sequenced on *finish what is started* rather than on *which work invalidates which*.

| # | item | why here |
|---|---|---|
| ~~1~~ | ~~**9** — s301 close-out prompt~~ | **DONE** — `s301-close-out.md`, landed on graph's `main` at `1c72823af` |
| ~~2~~ | ~~operator: close s301, land on `main`, TWO-HOP pull~~ | **DONE** — graph at `0.292.0 / c5e7daa`, 25 HARD in / 0 out, layer debt 2 → 0 |
| ~~3~~ | ~~**11** — the self-update gate's bare-invocation probe~~ | **DONE** — v0.288.0 (#388) |
| ~~4~~ | ~~F3, the parked branch~~ | **DONE** — shipped in the v0.289.0–v0.292.0 chain after two renumbers |
| ~~4b~~ | ~~**15** — the consumer notification hook~~ | **DONE** — v0.296.0 (#405). See §*What v0.296.0 shipped* |
| ~~5~~ | ~~**10a + 10b** — declare the path grammar, bind core to it~~ | **DONE** — v0.298.0 (#408), with v0.297.0 (#407) cut first to clear a gate defect the push exposed. See §*What v0.298.0 shipped* |
| ~~6~~ | ~~**7's remainder** — the `validate-layer-entries.sh` sweep~~ | **DONE, and it found NOTHING — measured, with a control.** See §*What item 7's remaining sweep measured*. Item 7 is closed |
| ~~7~~ | ~~**10c**, with **F4** folded in~~ | **DONE** — v0.299.0. Ledger emptied, readers composed, pointer landed, F4 shipped. See §*What v0.299.0 shipped* |
| ~~8~~ | ~~**10d**~~ | **DONE** — v0.300.0. See §*What v0.300.0 measured* |
| ~~8b~~ | ~~operator: pull, then run the migration~~ | **DONE 2026-08-08.** Three hops, four PRs. 2667 moves verified per file, 48 refused, 1001 deferred, self-check 0, second dry run exits 3. See §*Where things stand* |
| ~~8c~~ | ~~**`ledger-reverify.sh`'s own filed defects**~~ | **DONE** — v0.301.0 (#415) fixed the two that were live; v0.302.0 (#416) shipped the mechanism for the class the other three exposed. The plan said "five entries filed against one core file": it is **four plus one** — the fifth is in `layer-drift.sh`. See §*What item 8c measured* |
| ~~9~~ | ~~**10e** — the consumer pre-push validator~~ | **DONE** — v0.305.0 (#423). Blocks on exactly the set the migration would move (0 on graph today), reports the 48 refusals and the 1024 deferred stories rather than wedging them. See §*What v0.305.0 measured* |
| ~~10~~ | ~~**17** — a line retained outside the declared setup-site spans~~ | **DONE** — v0.306.0 (#425). **Reproduced at ground truth**, and the report's attribution was WRONG: `apply.sh` has no mask/reinject at all. See §*What item 17 measured* |
| ~~11~~ | ~~**16** — move `planning-artifacts/stories/` under `s<N>/`~~ | **DONE** — v0.307.0 (#427) readers, v0.308.0 (#428) files. The corpus is **988** flat, not 1024; the restating-reader count was **two**, not three; and the deferral's premise was true about the NAME and never asked about the POSITION. See §*What item 16 measured* |
| ~~12~~ | ~~**18** — `unregistered-drift.sh` reads an intermediate self-update ref as consumer drift~~ | **DONE** — v0.309.0 (#430). Reproduced with a control; **28 files** exposed (control: 72 machinery files outside the scan). Half the report's attribution is REFUTED and left open. See §*What item 18 measured* |
| ~~13~~ | ~~**8** — push-candidate ledger triage~~ | **CORE'S HALF DONE** — v0.310.0 (#432). The run's only CLOSE-CANDIDATE was FALSE; the guard against it existed as a NOTE, not a mechanism. The remaining triage needs the receipts re-anchored, which is the operator's. See §*What item 8's core half measured* | v0.299.0 changed files several `verify:` receipts anchor to. **Re-scoped by 8c**: the receipts are graph's and re-anchoring them is the operator's, so what remains here is adjudicating entries whose subject is core |
| ~~14~~ | ~~**6** — promote LC-E6/LC-O15~~ | **DONE** — v0.311.0 (#434), v0.312.0 (#435), v0.313.0 (#436), v0.314.0 (#437). Both zeros were unreadable: LC-O15's was FALSE, LC-E6's was a SILENCE. Two unrelated `apply.sh` defects fell out of driving it. See §*What item 6 measured* |
| ~~15~~ | ~~**19** — review graph's artifact consolidation~~ | **DONE — no release, by the item's own terms.** `docs/reviews/graph-artifact-consolidation-review.md`. Consolidation is load-bearing and the recurrence is structural; the defects are core's step leaving 33 working files (1.80 MB, 13.7%) in the durable area root and prescribing area-root paths for per-sprint work. See §*What item 19 measured* |
| ~~16~~ | ~~**21** — `apply.sh` overwrites itself mid-run~~ | **DONE — v0.316.0.** **REPRODUCED at ground truth with a control**, and the report's attribution is EXACT — the second in a row. bash resumes at its saved byte offset inside the new file; the fix is the `.incoming.$$` + `mv` idiom the file already used at five sites. One fixture arm was **removed for being vacuous** rather than shipped. See §*What item 21 measured* |
| ~~17~~ | ~~**23a** — are the budget thresholds attainable at all?~~ | **DONE — v0.317.0 (#449) + v0.318.0 (#450). THE ANSWER IS YES and graph already passes at 36%.** The 417% breach was an instrument reading: pool understated 5x, sum overstated 2.35x, both defects core's. The floors were derived anyway, because at a genuine 200K window the threshold IS unattainable (130–151%). See §*What item 23a measured* |
| ~~18~~ | ~~**23b** — artifact-consolidation's residue~~ | **DONE — v0.319.0 (#452).** Four working files homed in `s<N>/`, drafts retired at a new Step 6, and the step prescribed **no path at all** for three of the four — which item 19 did not state. **The refusal set is EMPTY: all 33 resolve, 24 with no inference**, and the `S999` premise is refuted. New fixture `consolidation-residue`; **no existing check could have caught this**, because both the area-root and the slotted path are syntactically conforming. See §*What item 23b measured* |
| ~~19~~ | ~~**23d** — its own skill?~~ | **DECIDED — NO. No release; nothing added to this table, which is what a "no" looks like.** The FOR argument survived its control (it is the only step route HANDS OVER rather than enters) but three of the four claimed gains buy nothing, measured. The decider is the SUBJECT boundary: setup and update reference `planning-artifacts` **0** times, the pipeline **70**. See §*What item 23d decided*, which also states what would re-open it |
| ~~20~~ | ~~**27** — the skill stamp has two contradictory instructions and no writer~~ | **DONE — v0.320.0 (#458).** The branch is a flag, `apply.sh --carried-machinery-slice`, and both prose sites now point at it. **No new invariant: I60 already binds the join**, proven by mutating the case-arm name until it fails by name. New fixture `apply-machinery-stamp`; the gap it fills is measured at **0** skill-field assertions across the whole fixture set against a control of 3 on the rulebook pair. See §*What item 27 measured* |
| ~~21~~ | ~~**23c** — the inlet~~ | **CLOSED — derivation + three releases, v0.321.0 (#461), v0.322.0 (#462), v0.323.0 (#463). ITEM 23 IS CLOSED.** Original row text follows. **DERIVATION DONE 2026-08-08 — the stop condition is NOT met, so 23c proceeds.** Finding: [`docs/reviews/artifact-inlet-locked-block-derivation.md`](../reviews/artifact-inlet-locked-block-derivation.md). **The read side is cheap and it was the wrong question**: of the four validators one is not a site, two move for free, one moves on a one-word default. **The real work is a FOURTH change the item never named — `is_sprint_slotted` exempts every `s<N>/` path from the whole-read pool, so the move grades itself green without a byte less being read.** Now four changes in THREE releases: **23c-2** the changelog — **DONE, v0.321.0 (#461)**, taken first because nothing reads a changelog so it needs no pool arm; **23c-1 + 23c-3** the pool arm with the writer and pin, together because the arm has no subject until the writer creates one; **23c-4** cross-sprint anchoring. See §*What item 23c's derivation measured* |
| ~~22~~ | ~~**25** — five more per-sprint artifacts prescribed at durable paths~~ | **DONE — v0.324.0.** `test-strategy.md` moves to `s<N>/`; Check 23 rescoped from producer to path shape; the criterion written down. **The item's premise that no durable declaration exists is REFUTED** — two independent pairs of carriers already agreed, and four of the five were already decided with reasons. **74 homes, not 73.** `bug-analysis` stays out on a stated disagreement rather than a quiet widening. Two pre-existing fixture defects fell out, one of them a vacuous arm caught before it shipped. See §*What item 25 measured* |
| ~~23~~ | ~~**24** — the fixture ship-list is four hand-lists~~ | **DONE — v0.325.0.** `install.sh` derives from `.dist-only`; the criterion is in `CLAUDE.md`; all 7 empty markers filled and I74(d) requires a body. **The other three lists STAY, with the blast radius measured** — uninstall bounds a destructive loop on a tree where `core/fixtures/` does not exist, and the two glob declarations are read by ~20 programs. **I74's old join could not survive and was replaced rather than kept as a tautology.** A second extractor (I8) was found by RUNNING. See §*What item 24 measured* |
| ~~24~~ | ~~**28** — a `subject_digest` is unreadable once its row stops blocking~~ | **DONE — v0.331.0.** New read-only mode `layer-drift.sh --list-adjudications`, sited on `adj_digest` rather than on `ADJ_CODES`. **The item's own framing would have shipped a listing reporting 1 of 12**: measured on the reference consumer, only ONE keyed subject is an `adj_check` row and eleven are LC-E19 at `level: WARN`, which hides its key harder because a verdict suppresses the whole row. Classify proven byte-identical, 47 rows. Fixture arms in TWO places because the two sites fail differently. See §*What item 28 measured* |
| ~~25~~ | ~~**12** — bind the fixture ambient-env guard~~ | **CLOSED — v0.335.0 (#479).** Ships as **I87**. **The plan derived the wrong side**: it said the subject is "the declared consumer-settable tunables" and no such declaration exists or is needed — a tunable is ambient-dangerous exactly when a SHIPPED PROGRAM DEREFERENCES it, derived from code on both sides. 37 → 24 → 11 → 2 → **0**, with the last two narrowings each taken from ONE measured false positive (a comment; a single-quoted awk program). 21 of the tokens the old grammar flagged have no shipped reader at all. Real answer is zero today, so it carries a self-written probe suite AND was verified by injecting a real exposure |
| ~~26~~ | ~~**22** — a stale path in a layer entry BODY goes undetected~~ | **CLOSED — derivation (#474), hoist v0.332.0 (#475), clause v0.333.0 (#477).** `LC-R4`/`W11` at WARN, `contract_version` 18. **The premise was refuted: the cited path RESOLVES**, naming a migration residue while the live corpus moved — so nothing in the fix tests existence, which would have scored 157 FPs of 309 tokens and missed its own subject. The empty cell was a CONSUMER's own prescriptions. **76 prescriptions read, 12 findings in 10 entries, 0 FPs — nine found only by reading all four scan roots.** The fixture's second mutant found a defect in the arm before it shipped |
| ~~27~~ | ~~**26** — LC-O15 is anchor-grained, the supersession was arm-grained~~ | **CLOSED — v0.334.0 (#478). REPRODUCED first: 119 consumer-only lines, the consumer's exact number, derived independently against the entry's own `base_sha`.** The item's own first question answered NO — **an arm is not addressable**: the declaration keys on `<file>#<anchor>`, core's 231-line span has ONE sub-heading with the superseded machinery on BOTH sides of it, and the second superseded arm is not in the shadowed file at all. So the smaller outcome the item predicted: the row MEASURES the surplus it was already warning about in prose. No new declaration, no new join |
| ~~—~~ | ~~**23d** — its own skill?~~ | **ANSWERED — NO, 2026-08-08. See row 19 and §*What item 23d decided*.** This row is the ORIGINAL scoping and its instruction is spent; a session acting on it would re-open a settled question. What follows is that original text. Operator question 2026-08-08. A DECISION, not a build, and **not answerable before 23a and 23b report**. **A "yes" produces implementation that must be ADDED TO THIS PLAN as its own sequenced item(s) before it starts; a "no" is recorded so it is not re-opened** |
| ~~—~~ | ~~**20** — a shipped fixture no consumer could run~~ | **DONE** — v0.315.0 (#440). Taken out of order: it was blocking the consumer's pull mid-flight |
| ~~—~~ | ~~**21** — `apply.sh` overwrites itself mid-run~~ | **DONE — v0.316.0 (#445). See row 16.** This row is the ORIGINAL report and its instruction — *reproduce it first* — is DISCHARGED; it reproduced, and the attribution was exact. What follows is that original text. REPORTED by the consumer with receipts, **NOT reproduced here**. Reproduce first; three earlier consumer reports in this plan had wrong attributions |
| ~~—~~ | ~~**13**~~ | **DONE** — v0.303.0 (#418). Taken ahead of 6 because 6's gate needs a consumer measurement and graph is mid-pull |
| ~~—~~ | ~~**14** — the dependency map~~ | **DONE** — v0.294.0 (#402) + v0.295.0 (#403). Taken out of order on operator direction, ahead of item 10. See §*What v0.294.0 measured* |


**Two constraints, and neither is a preference.** **10b before 10d**: a migration without the
binding is undone by the next sprint's writes. **The pull before 10d/10e**: 10e wires a
validator into the consumer pre-push, so migrating a consumer whose engine cannot enforce the
new convention means migrating twice.

**And one deadline that is not ours to move: s302 has not started.** The plan already holds it
until this work lands and is pulled. If the convention lands before s302, s302 writes conforming
artifacts from its first file and the migration is paid once. If it lands after, s302 adds
roughly another hundred non-conforming files and the migration is paid again.

**Item 3 is closed as an ITEM and half-open as a DEFECT, and the two must not be confused.**
v0.286.0 shipped the fix for the strip its measurement found defeated on 6 of 135 filenames.
The second defect that measurement named — the live-series pick being an `ls -t` across 56
series in one directory — is **still live, and both hooks say so in their own comments**
(`core/hooks/ai-dlc-continue.sh:283`, `core/hooks/ai-dlc-acknowledge.sh:167`). It is not
fixable at the hook, because the filename grammar has no sprint slot to scope on. **Item 10 is
where it gets fixed**, and until then item 3 should not be quoted as fully discharged.

**Do these in order. Stop and ask if a step's premise no longer holds — several below were
true at 2026-08-06T20:05Z and are worth re-verifying before acting.** That instruction has now
paid for itself twice in one session: item 2b's stated MECHANISM was wrong (the defect is an
underived count, not a miscounted `grep -c`) and item 3's PREMISE was wrong outright (the rung
was already reachable and already firing). Both were caught by re-measuring before building,
and in each case the thing worth shipping was one layer away from what the item named. Re-derive
before you write code.

0. ~~**Parallelize the mutant runs inside the six heavy fixtures.**~~ **COMPLETED — shipped as
   v0.283.0.** Suite makespan **268s → 238s**. See §*What v0.283.0 measured about the suite*
   for the numbers, including the three the plan got wrong. **`feat/v0.283.0-unreached-step-verdicts`
   must be renumbered to `v0.287.0`** — 0.283.0 went to this release, 0.284.0 to the
   validator spawn reduction that followed it, 0.285.0 to item 2b and 0.286.0 to item 3.

1. ~~Confirm with the operator whether the two-hop graph pull has happened yet.~~ **DONE — the
   pull ran and graph is at `0.292.0`. See §*Where things stand*.**
   **ANSWERED 2026-08-06: it has not, and it is now sequenced AFTER this plan's releases**, so
   that s302 starts on a fully-updated consumer. Still the operator's to run; still two hops
   (§*pull graph in TWO hops*). graph's stamp was re-measured at `0.274.0 @ 9036e0d`.
2. ~~**Fix `validate-locked-anchor.sh`.**~~ **COMPLETED — shipped as v0.280.0.** All three OPEN
   `PC-S297-LOCKED-ANCHOR-*` candidates discharged. See §*What v0.280.0 measured*.
2b. ~~**Absorb Rule 930's count-control discipline and give it an enforcer.**~~ **COMPLETED —
   shipped as v0.285.0 (#377)** as core **Rule 31**, with the enforcer measured and
   deliberately NOT shipped. See §*What v0.285.0 measured about the count-assertion class*,
   which corrects this item's stated mechanism. Two things a later session must not re-derive:
   the absorption premise HELD (core's `SKILL.md` had 0 statements of the discipline against
   two same-read controls), but **the defect is not a miscounted `grep -c`** — it is an
   underived count in prose that asserts facts outside the criterion's own test. The carrier
   is a declared I79 gap, taking core's gap count 5 → 6.
3. ~~**Make the adversarial STALL rung reachable mid-cycle.**~~ **CLOSED — the premise was
   refuted and the REAL defect shipped as v0.286.0 (#381).** The rung was already reachable
   and already firing; the live-series derivation underneath it was vacuous on 6 of 135
   filenames. What follows is the record of that measurement, kept because item 7 audits
   against the same class.

   **PREMISE REFUTED BY MEASUREMENT — the original text, for the record.**
   The item read "make the adversarial STALL rung reachable mid-cycle; it fires correctly at p7
   and goes silent once the cycle converges, so today it caught nothing." **Every clause of that
   is false.** The rung is already reachable mid-cycle, it already fired mid-cycle during s301,
   and it fired at p6, not p7. See §*What item 3's measurement found*. Do NOT build the stated
   remedy — a per-pass validator call in the step file — it is a second copy of a mechanism that
   already exists and already ran.
4. ~~**R4 — snapshot ceiling.**~~ **COMPLETED — shipped as v0.281.0 (#369).**
5. ~~**R3 — auto-handoff.**~~ **COMPLETED — shipped as v0.282.0 (#370)**, carrying the
   multi-key `settings_env_keys:` mechanism with it.
6. ~~**R6 — promote LC-E6/LC-O15 to ADJUDICATED.**~~ **DONE — four releases, and the gate was the
   whole item.** v0.311.0 (#434), v0.312.0 (#435), v0.313.0 (#436), v0.314.0 (#437). The count
   came back **0 and 0 with a working control, and BOTH zeros were unreadable** — LC-O15's was
   FALSE and LC-E6's was a SILENCE. **Do not reuse this section's framing of the gate as "count
   the sets": counting was necessary and nowhere near sufficient.** See §*What item 6 measured*.
   What follows is the original text.
   **THIS ITEM'S GATE HAS BEEN WRONG TWICE AND
   IS NOW STATED AS UNMEASURED RATHER THAN GUESSED A THIRD TIME.** It originally read "blocked
   until graph burns down its `EXTENSION-TITLE-MATCHES-CORE` set, or first contact wedges on ~13
   blocking rows." Both halves are false:
   - **Those rows cannot block.** LC-E19 is `level: WARN`, and `hard-blockers.sh:48` selects with
     `awk -F'\t' '$1 ~ /^HARD-/'` — a prefix match the status does not carry. Proven with a
     control in which a `HARD-` row IS selected. `audit-layer-debt.sh` is report-only, exit 0.
   - **They are also the wrong clause.** R6 promotes **LC-E6** and **LC-O15**, both currently
     `WARN`. The title-match rows are **LC-E19**, which R6 does not touch.
   The real exposure is that `level: ADJUDICATED` means "a mechanized candidate set and a HUMAN
   verdict", so promoting LC-E6/LC-O15 makes THEIR rows require a register record to clear.
   **How many rows that is has NOT been counted.** Count the LC-E6 and LC-O15 candidate sets
   against the consumer before scheduling this item; the ~13 figure referred to a different
   clause and must not be reused.
7. **Audit the steps s301 never reached** for the defect classes v0.280.0 found in the steps it
   did reach. s301 stalled at `stories-test-strategy.md` §4, so every downstream step is
   unexercised. The five measured classes are listed in §*What v0.280.0 measured*.
   **F1 and F2 shipped as v0.287.0 (#383). F3 is DONE and PARKED as v0.288.0. F4 is
   RE-HOMED into item 10c. The named lead is still unaudited.** All four findings are in
   §*What the unreached-step audit found*. State of each:
   - **F3 `validate-audit-anchors.sh` — DONE, parked on `feat/v0.288.0-anchors-assertion-count`,
     blocked by item 11.** **Half of F3's premise was REFUTED and must not be rebuilt**: an
     all-`PENDING` anchors file passing `--entries` is correct by design — the schema documents
     `sha` as "a PENDING placeholder until merged" and says the fail-closed belongs to
     `--prior-sprint-sha`; `retro.md` Step 5c claims schema conformance only and points forward
     at Check 18; Check 18 runs `--prior-sprint-sha`, which names a PENDING placeholder as one
     of four fail-closed causes, and `check5-anchor-base`'s `placeholder` mutant already locks
     it. The CONFIRMED half is in §*What v0.288.0 measured*.
   - **F4 `validate-ci-gates.sh` — RE-HOMED, do not ship it standalone.** It is a `docs/retro/**`
     reader-site fix and item 10c moves those paths, so it ships as part of 10c or it is written
     twice.
   - ~~**The unaudited lead: `validate-layer-entries.sh`**~~ **SWEPT 2026-08-07 — NEGATIVE, and
     the lead's premise was wrong.** No release. See §*What item 7's remaining sweep measured*.
     **Item 7 is now CLOSED**: F1/F2 shipped (v0.287.0), F3 shipped (v0.288.0), F4 is re-homed
     into 10c, and the lead is refuted.
8. **Triage graph's push-candidate ledger** — 123 `## PC-` entries, of which roughly 57 are
   upstream-facing and OPEN. Re-run each `verify:` receipt against the current core tree
   before proposing anything; several are documented as having gone blind, meaning the
   substring is absent at base AND at theirs, so the entry can never close.
9. ~~**Write the s301 close-out prompt** for the operator to paste into the graph session,
   mirroring what the s300 close-out did.~~ **DONE — `docs/plans/s301-close-out.md` is the executable procedure the operator runs; `docs/plans/s301-close-out-derivation.md` is how each figure was measured.**
   Every figure in it was re-measured against the consumer on 2026-08-07. It records a
   SEVENTH difference from s300 the plan below did not have (the gate log's headings are
   `## Gate: planning — Sprint 301 (…)`, not the `## Gate Log: Sprint N` s300's sweep assumed,
   so a sweep keyed on the latter empties nothing and exits clean) and a THIRD inventory trap
   (grepping the corpus for `RESTART_CYCLE` returns 1, and it is prose saying RESTART_CYCLE was
   NOT warranted — control: 22 `EXIT_CONDITION_MET` in the same corpus). **Awaiting the
   operator: paste it into graph, then take the two-hop pull.**
10. **Declare ONE artifact path convention, mechanise it, and migrate every existing file to
    it.** **ITEM 10 IS COMPLETE — 10a/10b v0.298.0 (#408), 10c v0.299.0, 10d v0.300.0, 10e
    v0.305.0 (#423). The paragraph below is the record of the item as it was scoped, kept for its
    reasoning; do not read it as work outstanding.** 10c is where
    the readers move, the step files are rewritten and the migration ledger is emptied. Do not
    read the grammar as adopted until then: nothing points an authoring agent at it, deliberately.
    OPERATOR DIRECTIVE, 2026-08-07: one generic folder AND file naming convention;
    **migrating pre-existing files is a MUST**; breaking historical traceability is
    **accepted**, on the stated ground that *a declared convention is itself the guide to
    where to look, and without one nothing has improved*. The full measurement, the proposed
    grammar and the five sub-releases are in §*Item 10 — the artifact path convention*.
    **SEQUENCING CORRECTED 2026-08-07 — this item previously read "do not start it before item 7
    closes", and that was backwards.** 10c rewrites the very reader sites item 7's remaining
    sweep would audit, so ordering 7 first means auditing files 10c then replaces. 10a and 10b
    move no paths and now run EARLY; F4 is folded into 10c. See §*Order of execution*.
    It is also the one item in this plan that **writes to the consumer**, via a migration
    script core ships and the OPERATOR runs — the read-only boundary at the top still binds.
11. **Fix the self-update gate's bare-invocation probe.** It runs each gating script with no
    arguments and no stdin and compares exit codes, but **three of the five gating scripts exit
    2 — a usage error — when invoked that way**, so the differential compares two usage errors,
    lands on `SELF-UPDATE-UNDECIDED` and defers. Any machinery-only pull touching one of those
    three defers permanently. Blocks the parked v0.288.0 branch. See §*Item 11*.
12. **Bind the fixture ambient-env guard, once the join is derivable.** v0.289.0 fixed three
    fixtures that inherited a consumer's `AI_DLC_*` tunables and tested the CONFIG instead of the
    CODE. The guard that would prevent recurrence is not shippable as written: requiring the
    clearing loop wherever a fixture names an `AI_DLC_*` token flags **19** fixtures, most of
    them naming keys they set THEMSELVES as worker-pool plumbing (`AI_DLC_LCC_OUT`,
    `AI_DLC_SFD_SCRIPT`, `AI_DLC_TAC_VALIDATOR`, `AI_DLC_RFO_DETECT`, `AI_DLC_CMI_VALIDATOR`),
    where clearing would break the fixture. Control: **36** fixtures already carry the loop. The
    correct subject set is the declared *consumer-settable* tunables, not any `AI_DLC_*` token —
    derive that side first, then measure the false-positive set again before shipping.
13. ~~**Verify the reference consumer's step-7 finding, then fix it.**~~ **DONE — v0.303.0 (#418).
    IT REPRODUCED**, on the `layer-adjudication-tier` scratch consumer, exactly as this item
    required before any fix: the pull's base gives `EXTENSION-HOOK-DRIFT` +
    `HARD-LAYER-ADJUDICATION-MISSING`, `theirs` as base gives `EXTENSION-OK` and nothing else,
    and the degenerate run still emits a row — the control that makes its zero readable. Step 7's
    one instruction covering both scripts is now split per script, and `layer-drift.sh` emits
    `DRIFT-RANGE-DEGENERATE` when its two refs resolve to the same commit, so the wrong
    invocation announces itself rather than depending on the prose being read correctly.
    False-positive set empty and derived: every programmatic caller already passed the pull's
    base. What follows is the original text.
    REPORTED BY THE CONSUMER,
    NOT YET REPRODUCED HERE — record it as theirs until it is. They report that step 7's
    post-apply re-run instruction disarms its own check: passing `theirs` as the base makes
    `EXTENSION-HOOK-DRIFT` unable to fire, so `hard-blockers.sh` printed `0 HARD blockers.`
    while all 18 adjudications were unrecorded. They caught it by running both bases side by
    side. The emit at `layer-drift.sh:1296` keys on `${BASE}..${THEIRS}`, so a base equal to
    theirs compares a range to itself — the mechanism is plausible on its face. **Reproduce it
    against a scratch consumer before writing the fix**, because a gate that prints zero is the
    exact shape this repo keeps shipping, and a fix aimed at the wrong layer would leave it.

14. ~~**Trace-derive a per-fixture dependency map, so the pre-push runs the fixtures a change can
    actually affect.**~~ **SHIPPED as v0.294.0.** Taken out of order on operator direction
    2026-08-07, ahead of item 10. The first pass's prerequisite measurement is done and its
    answer is in §*What v0.294.0 measured*: **~8000 paths a declaration-based skip would have
    missed**, 78 of 118 fixtures named in no binding at all. Four things a later session must
    not re-derive: `dtruss` is unusable under SIP and **root does not lift that**, while
    `fs_usage` works; APFS is **relatime-like**, so a before/after atime watermark
    under-records by construction; tracing a fixture **as root corrupts its read-set**, not
    merely its verdict; and the wall-clock win is **42%, not the 76% of work removed**, because
    the suite is pole-bound.

15. ~~**Ship the input-needed notification hook to consumers.**~~ **COMPLETED — shipped as
    v0.296.0 (#405).** Everything the scope below predicted held: the I44 objection was already
    refuted, and there was no new machinery to build. See §*What v0.296.0 shipped* for the two
    decisions the scope left open and how each was closed. What follows is the pre-work scope,
    kept for its reasoning.

    **The premise was checked and one objection was WRONG, so do not re-raise it.** The concern
    was that core must not write into a consumer's `settings.json` (I44). Measured: `install.sh`
    already ships hook wiring at scale — **nine hook events** and a dozen-plus commands, through
    a merge engine deliberately shared with `ai-dlc-update`'s reconcile, because *"two copies of
    this jq is how an installed consumer and a reconciled consumer silently diverge"*. A block
    counts as ai-dlc-owned when its command references `.claude/hooks/ai-dlc-*.sh`, so stale
    entries are stripped and replaced on reinstall. There is no new machinery to build.

    **WHY IT BELONGS IN THIS DISTRIBUTION, and it is this repo's own argument.** The plan-shape
    rule already requires every plan to tell its executor to ping, because *"still working" and
    "stopped, waiting on you" look identical from outside, so silence is a stall found only by
    polling* — measured across this repo's runs, EVERY consumer-session stall ended with the
    operator asking rather than the session reporting, including one sitting on a blocking
    question and one that had already FINISHED. That rule is prose. This is its mechanism, and
    `CLAUDE.md` prefers mechanisms to prose.

    **The shape, already proven on the operator's own machine 2026-08-07:**
    - `core/hooks/ai-dlc-notify.sh`. The `ai-dlc-*.sh` prefix is LOAD-BEARING — it is what marks
      the settings block ai-dlc-owned.
    - A `Notification` entry in `templates/settings.json.template`. That event fires on
      permission prompts and idle-waiting. **Do NOT use `Stop`**: it fires at the end of every
      response and trains the operator to ignore it.
    - Pass the message to `osascript` as an ARGUMENT, never interpolated into the script text.
      A payload containing quotes, backslashes or `$(...)` otherwise breaks the AppleScript or
      executes inside it; the reference implementation carries an injection control proving it
      does neither.
    - macOS-only as written. Decide explicitly whether a non-macOS consumer gets a no-op or a
      platform branch, and say which in the release — a hook that silently does nothing on Linux
      is the inert-mechanism class this repo keeps shipping.
    - Reference implementation to copy from: `~/.claude/hooks/notify-input-needed.sh`.

16. ~~**Move `_bmad-output/planning-artifacts/stories/` under `s<N>/`.**~~ **DONE — v0.307.0 (#427)
    and v0.308.0 (#428). Three things below are WRONG and are corrected in §*What item 16
    measured*: the corpus size, the count of restating readers, and — the one that mattered — the
    claim that the syntactic limit is what made this hard.** What follows is the original scope.
    SPLIT OUT OF 10c on
    2026-08-07, deliberately, and it is the one area the artifact path grammar does not yet
    govern. The directory is syntactically conforming — it carries no sprint token — and the
    sprint hides in the FILENAMES (`story-<N>-<M>-slug.md`, `story-S<N>-<M>-slug.md`), which
    is precisely the limit §*What a syntactic check CANNOT catch* documents in
    `artifact-path-grammar.md`. **Check 6's SILENCE was fixed in v0.299.0; its PATH was not.**

    Why it is not a folding-in: `stories_dir` is a **SCHEMA declaration**
    (`core/schemas/sprint-status.json:101`), and **three shipped readers restate the literal
    rather than resolving it** — `validate-mandatory-rules.sh:249`, `validate-locked-anchor.sh`
    and `ai-dlc-protect.sh` (plus `install.sh`). Making it sprint-scoped means making it a
    template the schema owns and every reader resolves, which is an I-invariant's worth of work
    on its own. And `resolve_story_file()` (`sprint-status.sh:608`) resolves a story FILE from
    the entry KEY (`story-S299-1`); under the grammar the file is `story-<M>-<slug>.md` and the
    sprint comes from the directory, so Check 5's whole join has to be re-derived rather than
    re-pointed.

    Do it AFTER 10d/10e or the consumer migrates twice. **Re-measure the story corpus before
    writing anything** — the 786/73/139 split in §*Item 10* is from 2026-08-07.

17. ~~**`apply.sh`'s mask/reinject retains a line OUTSIDE the declared setup-site spans, so upstream
    content silently fails to land.**~~ **DONE — v0.306.0 (#425). REPRODUCED at ground truth, and
    BOTH halves of the attribution were wrong: `apply.sh` implements no mask/reinject, and the
    check that catches it already existed as untangle-only prose. See §*What item 17 measured*.**
    What follows is the original report. REPORTED BY THE CONSUMER 2026-08-08, during the 0.297.0 →
    0.300.0 hop, and **not yet reproduced here** — record it as theirs until it is. Verbatim:
    *"`deploy-validate.md` — `apply.sh`'s mask/reinject retained OURS at line 26, a line OUTSIDE
    both declared setup-site spans, so the one artifact-path line upstream added to this file
    never landed."* They corrected it by hand; the file now differs from theirs only at the two
    declared sites.

    **This is the highest-severity item outstanding, because its failure direction is upstream
    content NOT ARRIVING** — the pull reports success and the consumer is quietly behind. It was
    caught only because `HARD-CORE-BEHIND` flagged it independently, which is the safety net
    working, not the mechanism working. **Reproduce it on a scratch consumer before touching
    `apply.sh`**: a mask that keeps a non-site line is a different bug from a site span that is
    mis-derived, and a fix aimed at the wrong one leaves it.

18. ~~**`unregistered-drift.sh` reads an INTERMEDIATE self-update ref as consumer drift.**~~
    **DONE — v0.309.0 (#430). REPRODUCED at ground truth, and the report named TWO files of which
    only ONE can have come from this script.** See §*What item 18 measured*. What follows is the
    original report. Same
    report. It measures the consumer against the stamp's `commit`, but a self-update hop advances
    `skill_commit` — so on a multi-hop pull, files byte-identical to the distribution at the
    intermediate ref are reported as consumer edits. Verbatim: *"`core-manifest.md` /
    `setup-sites.md` — take theirs. Not consumer drift: both were byte-identical to the
    distribution at `9bd084b`, the intermediate self-update ref this session's own hop wrote."*

    Lower severity than 17 — it produces FALSE work, not lost content — but it costs adjudication
    time on every multi-hop pull, and multi-hop is now the norm rather than the exception (this
    pull was three). The two stamp fields and which one each reader consults is the derivation to
    start from.

19. ~~**Review graph's recent attempts at artifact consolidation.**~~ **DONE 2026-08-08 —
    `docs/reviews/graph-artifact-consolidation-review.md`. No release.** Two things below are
    WRONG: this item treats "consolidation" as one operation when it is THREE with different
    owners, and **its "48 refusals" figure is stale — the owed set is 98** (72 AMBIGUOUS + 3
    NO-AREA + 23 STORY-NO-SPRINT), and was already 72/3/23 at v0.308.0 by this plan's own record.
    See §*What item 19 measured*. What follows is the original scope.
    **Review graph's recent attempts at artifact consolidation, and decide whether the process
    improves or the methodology changes.** **OPERATOR REQUEST, 2026-08-08**, verbatim: *"would
    like to add to the plan a review of graph consumers recent attempts at artifact consolidation
    and determine if there are improvements we can make with that process or even a different
    methodology altogether."*

    **THIS IS A REVIEW, NOT A RELEASE, AND IT MUST NOT OPEN BY PROPOSING A MECHANISM.** The
    deliverable is a written finding: what graph actually did, what it cost, what it achieved,
    and whether the approach is the right one. A core release may follow it; none is authorised
    by this item on its own.

    **Read-only against `/Users/n8/git/graph`** — the boundary at the top of this file binds, and
    nothing in this repo gates the item. Where to start, and each of these is a POINTER to be
    verified rather than a finding: the artifact-path migration this plan's item 10 produced
    (2667 moves, 48 refusals, 1001 deferred — §*Where things stand*), item 16's story-corpus move
    (988 files, §*What item 16 measured*), the s301 close-out and its archive sweep, and whatever
    consolidation graph has attempted on its own since. **The 48 refusals are still owed and
    unresolved**; they are the most likely place a methodology question is hiding, because each
    one needs a basename renamed and an area decided, which is exactly the work a path grammar
    cannot do for you.

    **RE-DERIVE EVERY FIGURE.** Item 16 is this plan's own worked example of why: its predicted
    corpus size was wrong in BOTH directions and the difficulty it named was the wrong one. Any
    number quoted below `## Context` is historical.

    **State the counterfactual.** "Was consolidation worth it" is only answerable against what
    the alternative would have cost, and this plan has the numbers for the migration side but
    not for the do-nothing side. Derive it or say plainly that it is underived.

20. ~~**A shipped fixture could not run on any consumer.**~~ **DONE — v0.315.0 (#440).**
    `story-corpus-sprint-slot/seed.sh` walked `../../..` and required `core/`-prefixed sources, so
    installed it landed on the consumer repo root and exited 2 before any assertion. **REPORTED BY
    THE CONSUMER AND REPRODUCED HERE with a control** (distribution rc=0, install-shaped tree
    `seed: missing core/scripts/sprint-status.sh`) — the first consumer report in this plan whose
    attribution was exact. The class sweep found 8 more suspects by text and **all 8 passed when
    RUN in a consumer-shaped tree**, so the obvious lint has a false-positive set of 8 of 8 and was
    deliberately not shipped. The honest mechanism — running the shipped fixture set inside an
    install-shaped tree — costs a second full suite and is a declared gap.

21. ~~**`apply.sh` overwrites itself mid-run.**~~ **DONE — v0.316.0 (#445). REPRODUCED at ground
    truth with a control, and the report's attribution was EXACT** — the second in a row. bash
    resumes at its saved byte offset inside the replacement and **can exit rc=0 having run the
    wrong code**, so do not remember this as "it fails loudly"; the observed syntax error is the
    lucky end of the band. Fixed with the `.incoming.$$` + `mv` idiom the file already used at five
    sites. **The fix protects the NEXT pull, not the one that delivers it.** See §*What item 21
    measured*. What follows is the original report.
    **REPORTED BY THE CONSUMER 2026-08-08 with receipts,
    NOT YET REPRODUCED HERE — record it as theirs until it is.** This plan has been wrong about a
    consumer report's attribution three times (items 13, 17, 18), and in two of those the named
    program was not the one at fault. **Reproduce it on a scratch consumer before touching
    `apply.sh`.** Start from the fact that phase 1 overwrites every pure-apply core file from
    THEIRS, and `apply.sh` is itself an upstream-owned file under `reconcile/` — so the running
    script can be replaced underneath its own interpreter mid-execution. Whether bash re-reads the
    file is the question to settle FIRST, by experiment, not by recall: the answer decides whether
    this is a live defect or a latent one, and a fix aimed at the wrong half leaves it.

22. **A stale path inside a layer entry goes undetected.** **REPORTED BY THE CONSUMER 2026-08-08,
    NOT YET REPRODUCED HERE.** They cite `tea-consumer.md:18` in their own tree as an entry body
    naming a path that no longer resolves, with nothing reporting it. **The citation is into the
    CONSUMER and must be re-read there before acting.** The layer contract checks `hooks:`,
    `shadows:` and `extends:` targets; a path in an entry's BODY is outside all three. Before
    building anything, derive the false-positive set: entry bodies quote paths for many reasons —
    historical notes, examples, other repos — and a checker that resolves every path-shaped token
    in a body is the unmeasured lint this repo keeps refusing to ship.

23. **Refactor `steps/artifact-consolidation.md` so the process stops leaving its residue in the
    durable area.** **OPERATOR REQUEST, 2026-08-08**, made after reading item 19: *"we need to
    include the artifact-consolidation refactor as a step in this plan."*

    **THE REVIEW IS THE SPEC AND IT MUST BE READ FIRST** —
    [`docs/reviews/graph-artifact-consolidation-review.md`](../reviews/graph-artifact-consolidation-review.md),
    §*What item 19 measured*. Two things in it bind this item's scope. **Do not touch the
    reduction**: 19 passes over 4 artifacts in 66 days is a drain matched to an inlet, the
    counterfactual is a 96.1% reduction (12.0 MB → 470 KB), and nothing measured argues for
    consolidating less often. **And the recurrence is not the defect** — a fix aimed at "make it
    stop happening so often" is aimed at the wrong half.

    **~~23a — ARE THE BUDGET THRESHOLDS EVEN ATTAINABLE BY CONSOLIDATION?~~ DONE 2026-08-08 —
    v0.317.0 (#449) and v0.318.0 (#450). THE ANSWER IS YES; GRAPH ALREADY PASSES AT 36%.**
    Finding: [`docs/reviews/graph-artifact-budget-attainability.md`](../reviews/graph-artifact-budget-attainability.md).
    **Everything below this paragraph is REFUTED as an argument and kept only as the record of what
    the item asked.** Specifically: the "178% after a 96.1% reduction" reading, the sentence "THE
    ANSWER LOOKS LIKE NO", and the inference that the threshold, share or artifact set is wrong.
    Both numbers in that reading were defects in `validate-artifact-budget.sh` — a reader-window
    resolver reading a role-file line format deleted at v0.174.0 (pool understated 5x) and a
    basename sweep counting 26 archived copies (sum overstated 2.35x). **Two things below SURVIVED
    and are worth keeping**: the first bullet's diagnosis of the 30-file sum was CORRECT and is what
    v0.317.0 fixed; and the demand to derive the floors rather than estimate them was right, because
    at a genuine 200K window the threshold IS unattainable (floors 130–151% of pool). **The second
    bullet was WRONG** — see §*What item 23a measured*. What follows is the original text.
    **ARE THE BUDGET THRESHOLDS EVEN ATTAINABLE BY CONSOLIDATION? TAKE THIS FIRST.**
    **OPERATOR REQUEST, 2026-08-08**, and it names a real gap in item 19's review: *"I did not
    see an analysis of the maximum artifact sizes that are required to pass gate check and
    whether or not they are feasible to attain … The maximum size constraints need to be
    attainable via artifact-consolidation."* Correct — the review measured what consolidation
    ACHIEVED and never asked what it must achieve. **A first measurement was taken when the
    request landed; it is a POINTER, and every figure is to be re-derived.**

    ```
    validate-artifact-budget.sh against graph, 2026-08-08, read-only
      whole-read pool                          66000 tok  (33% of the analyst's 200000-tok
                                                           window, from team-roles/analyst.md)
      REPORTED breach                         275812 tok  417% of the pool
      the FOUR LIVE artifacts alone           117379 tok  178% of the pool
        carry-over-backlog.md  42554   prd.md 32619
        architecture.md        21524   product-brief.md 20682
    ```

    **THE ANSWER LOOKS LIKE NO, AND THAT IS THE POINT OF THE ITEM.** After 19 passes and a 96.1%
    reduction the four live artifacts are still **178% of the pool**, and `carry-over-backlog.md`
    alone is **64% of it**. graph reached the same conclusion from the other side at s286, whose
    sprint-status records a *"documented irreducible floor (60k non-binding aim)"*. **If the
    threshold is unreachable, the refactor's shape changes** — a remedy the gate names but no
    amount of correct execution can satisfy is the inert-mechanism class this repo keeps
    shipping, and it is worse than no threshold because it trains the operator to ignore the row.

    **AND THE REPORTED NUMBER IS NOT THE ONE TO REASON FROM.** Two defects were visible in the
    same run and both need confirming before anything is built on them:
    - **The breach sums 30 FILES under a label reading `(4 planning artifacts)`.** The sweep is
      basename-keyed, and the artifact-path migration moved every historical
      `<kind>-s<N>.md` into `s<N>/<kind>.md` — so 25-plus per-sprint `architecture.md` archives
      now carry the same basename as the live one and are counted as live. **A migration-induced
      regression in the budget check**, and the count in the label is exactly the underived
      assertion core Rule 31 exists for, inside the validator that enforces budgets.
    - **The four artifacts consolidation targets are in no `BUDGETS` table row.** That table
      names `gate-log.md`, `compaction-log.md`, `pipeline-continuation-log.md`,
      `context-mode-protection-log.md`, `audit-anchors.md` and `pipeline-snapshot.md` — logs and
      the snapshot. The planning artifacts are governed only by the pooled sum, so **no single
      one of them has a threshold it can be measured against**, which is why "what is the maximum
      size" has no answer to quote today.

    **WHAT 23a MUST PRODUCE.** A stated, derived answer to: what is each artifact's IRREDUCIBLE
    floor — the current-state content that cannot be relocated without losing something a reader
    needs — and does the sum of those floors fit the pool? Derive the floor, do not estimate it:
    Rule 13 locked requirements cannot be retired by consolidation at all, and the remedy text
    already says so. **If the floors do not fit, say so plainly and the finding is that the
    threshold, the pool share, or the artifact set is wrong** — not that graph consolidated
    badly.

    **~~23b — THE RESIDUE.~~ DONE 2026-08-08 — v0.319.0 (#452).** Both edits shipped, plus a third
    the item did not know about: **the step prescribed NO path at all for three of its four working
    files**, so the drafts and the coverage report had no home to be wrong about. **The re-home
    refusal set is EMPTY** and this item's stated premise for it — *"at least two carry no
    recoverable sprint at all (they say `S999`)"* — is **REFUTED**: `S999` appears in two of the 33
    as CONTENT, inside a carry-over ID list, and a byproduct's sprint was never in its content.
    Both controls this item quoted (`s<N>|sprint slot` rc=1, the retire vocabulary rc=1) now flip.
    See §*What item 23b measured*. What follows is the original text.
    **23b — THE RESIDUE. Bounded, core-side, and shippable on its own.** Two edits to the step,
    both with their control already measured in item 19:
    - **Give the step's outputs a sprint slot.** `:41` prescribes
      `_bmad-output/planning-artifacts/consolidation-manifest-<artifact>.md` — an AREA-ROOT path
      for a per-sprint work product. Control on the absence: `s<N>|sprint slot` returns **rc=1**
      over the step and matches five sibling step files. Live consequence today:
      `consolidation-manifest-prd.md` at the root AND `s300/consolidation-manifest-prd.md`, same
      basename, two homes, nothing declaring which is current — **the exact condition item 10 was
      opened to eliminate**, re-created by a step the migration did not touch.
    - **Say whether the drafts are retired at Step 6 or retained as evidence.** `:51` writes two
      drafts to disk; `:93` replaces the live artifact and never mentions the draft again.
      Control: `delete|remove|rm|clean ?up|discard|retire|unlink` returns **rc=1** over the step
      and matches three sibling steps. Either answer is defensible. **The silence is not**, and it
      is how eleven drafts accumulated, one of them a 1383-line near-duplicate of the 1530-line
      live PRD differing on 155 lines.

    **DERIVE THE RE-HOME REFUSAL SET BEFORE WRITING THE EDIT.** The 33 existing root files belong
    to sprints S243 through S301 and **at least two carry no recoverable sprint at all** (they say
    `S999`). A mechanical re-home therefore has refusals, and this repo's rule is that they are
    measured and reported, never assumed empty. **They must NOT be deleted**: `consolidation-
    coverage-*` and `consolidation-validation-*` cite the draft paths as their no-loss evidence,
    so deletion breaks the record the pass produced. This is a HOMING problem, not a garbage one.

    **23c — THE INLET. ITS DERIVATION IS DONE 2026-08-08 (no release) AND THE STOP CONDITION IS NOT
    MET, so 23c proceeds as FOUR sub-releases.** Finding:
    [`docs/reviews/artifact-inlet-locked-block-derivation.md`](../reviews/artifact-inlet-locked-block-derivation.md),
    §*What item 23c's derivation measured*. **Three things below did not survive.** The site count is
    wrong in both halves — one of the four validators (`validate-spec-join.sh`) is **not a site at
    all**, and the step-file figure is **8 by token or 13 by path, never 10**. The `--sor` datum is
    stronger than the item knew: the pin is a **basename equality test** and the resolver **already**
    walks up from the story's own directory, so per-sprint resolution is the existing behaviour. And
    the item's two-part framing — *"the LOCKED block and changelog"* — **omits the work**:
    `validate-artifact-budget.sh:859` exempts every `s<N>/` path from the whole-read pool, so the
    move grades itself green with the same bytes still read whole. What follows is the original text.
    **23c — THE INLET. The real methodology change, and it is NOT SIZED.** The durable artifacts
    refill because every sprint writes its own output into them: **7 of 7 headings added to
    `product-brief.md` in the six days after its 08-02 pass are sprint-scoped**, five carrying an
    explicit `S301` token. Move a sprint's LOCKED block and changelog into `s<N>/` — the slot item
    10 already built — and the inlet closes, at which point consolidation degenerates from a
    19-pass recurring cost into a rare genuine refactor. graph has already proven the containment
    half of this itself, in the s300/s301 archive-and-reset.

    **DO NOT START 23c BY WRITING CODE.** `LOCKED_REQUIREMENTS` is read by **four core validators
    and ten step files**. One datum in its favour: `validate-locked-anchor.sh:129` already
    parameterises the source-of-record (`DEFAULT_SOR_BASENAME`, overridable `--sor`). Whether the
    other thirteen sites move is **UNDERIVED, and deriving it is the whole of 23c's first step.**
    If the derivation says they do not move cheaply, say so and stop — 23b stands alone.

    **~~23d — SHOULD `artifact-consolidation` BE ITS OWN SKILL?~~ ANSWERED 2026-08-08: NO. No
    release; no implementation authorised; nothing added to §*Order of execution*.** The derivation
    this item demanded was run and is in §*What item 23d decided*, together with the three
    conditions that would re-open the question. **Two things in the text below did NOT survive
    measurement and must not be re-argued from it.** The item lists four things a separate skill
    gets: **three of them buy nothing here** — no skill defines its own rules (all 31 are ai-dlc's,
    and `ai-dlc-update` cites seven of them while being a skill anyway), the step already HAS a
    fixture as of v0.319.0, and only `ai-dlc-update` carries a `skill_version`, for the specific
    reason that it performs the version transition. The item also invites the argument that a
    separate skill would have to restate ai-dlc's rulebook; **that argument is refuted by
    `ai-dlc-update` and was dropped.** What the item got RIGHT is that operator-invocation on its own
    cadence is the strongest case FOR, and it survived its control. What follows is the original
    text.
    **23d — SHOULD `artifact-consolidation` BE ITS OWN SKILL (`ai-dlc-artifact-consolidation`)?**
    **OPERATOR REQUEST, 2026-08-08.** A DECISION, not a build, and **it must not be answered
    before 23a and 23b report** — the right packaging follows from what the thing turns out to be,
    and today it is a 103-line step file whose defects are a missing sprint slot and a missing
    cleanup sentence. Derive rather than assert, and the derivation has a shape this repo already
    uses: what does `ai-dlc-update` get from being a separate skill that a step does not? Its own
    resident rulebook, its own fixtures, its own invocation surface, its own version story — and
    against that, a second skill is a second thing to install, reconcile, drift-check and pull.
    The honest inputs are: how many core files reference the step (measured: `SKILL.md`,
    `route.md`, `carry-over-evaluation.md`, `architect.md`, `validate-artifact-budget.sh`), what a
    consolidation pass actually dispatches (an `analyst` under Rule 24), and whether it is
    operator-invoked on its own cadence — which it is, and which is the strongest argument FOR.
    **Do not answer it from the size of the file.**

    **AND A "YES" IS NOT SELF-EXECUTING. 23d DELIVERS A DECISION; THE BUILD THAT FOLLOWS IT IS
    SEPARATE WORK THAT MUST BE WRITTEN INTO THIS PLAN BEFORE IT STARTS.** Standing up
    `ai-dlc-artifact-consolidation` is a new skill directory, its own install and uninstall
    wiring, its own entries in the manifest and in `reconcile/setup-sites.md`, its own fixtures,
    and a migration for every core file that references the step today. **None of that is
    authorised by 23d**, exactly as item 19 authorised no release. The moment the decision lands,
    add the implementation to §*Order of execution* and to the numbered list as its own item or
    items, with their sequencing stated — and if the answer is no, record THAT as the outcome so a
    later session does not re-open a question that was already settled. **A decision item that
    quietly becomes a build item is how scope arrives unsequenced**, and this plan has the room to
    say so in advance.

    **ORDER: 23a → 23b → 23c, with 23d after 23b.** Not preference. 23a can invalidate the others
    — if the thresholds are unattainable, a tidier process still fails the gate and the finding is
    somewhere else entirely. 23b before 23c because 23c changes what a sprint writes, so doing it
    first means re-homing residue 23c would have stopped producing.

24. ~~**The fixture ship-list is hand-written in FOUR places, and the criterion behind it is written
    in NONE.**~~ **DONE — v0.325.0. What follows is the ORIGINAL scoping and its instruction is
    spent.** Three of its figures are corrected by the work: the counts are **132/120/12**, the
    criterion was NOT written nowhere (`.dist-only` existed and 5 of 12 carried a reason), and the
    sites are **five**, not four — I8 parsed `install.sh`'s loop line independently of I74 and was
    found by running. See §*What item 24 measured*. Original text follows.
    Surfaced by v0.316.0: adding one fixture required four edits, and the two I missed
    were found by a failed push rather than by anything at authoring time.

    **BE PRECISE ABOUT WHAT IS AND IS NOT BROKEN, because the obvious framing is wrong.** The set
    IS bound — `scripts/validate-enforcement-map.sh` joins all four and it FIRED, with
    `install.sh and uninstall.sh fixture loops disagree` and `core_manifest copies diverge
    (core-manifest.md vs reconcile/setup-sites.md)`. **This is not the silent-rot class**; the
    ratchet works. What it costs is four edits per fixture and one failed push to learn it.

    **AND IT IS NOT FIXABLE BY GLOBBING THE DIRECTORY.** Measured: **129 fixtures on disk, 117 in
    the ship list, 12 that deliberately do NOT ship** — `enforcement-map-*`, `plan-shape`,
    `suite-dispatch-order`, `suite-content-key`, `crosswalk-home-declaration`,
    `early-exit-reader`, `settings-merge-documented-form`, `story-fields-derive-mutants`,
    `trunk-audit-mutants`. Every one tests the DISTRIBUTION's own machinery, which a consumer does
    not have. The four lists agree exactly at 117 today (control: 0 shipped-but-absent entries, so
    the join is not vacuous).

    **THE REAL DEFECT IS THAT THE 12-ITEM CRITERION IS STATED NOWHERE.** Controlled:
    `distribution-only|does not ship|not shipped|ship list` over `install.sh`, `core-manifest.md`
    and `setup-sites.md` returns **zero matches**, while the same phrasing DOES occur in
    `validate-artifact-budget.sh` and four fixture `run.sh` files — so the grep can fire and the
    zero is real. A fixture author has no way to learn whether their fixture should ship except by
    pattern-matching the list or by pushing and reading the gate. **I decided `apply-self-overwrite`
    ships by inference, not by a rule**, and that is the whole item in one sentence.

    **THE SHAPE TO AIM FOR is this repo's own: one declaration per fixture, colocated with it, and
    all four sites derive from that** — the `CLAUDE.md` rule about deriving both sides of a join
    rather than hand-listing either. Then adding a fixture is one edit, in the fixture's own
    directory, and the criterion is written down where the person making the decision is standing.

    **TWO THINGS TO SETTLE BEFORE WRITING ANY CODE.**
    - **Say plainly that the win is ERGONOMIC, not correctness.** The join already prevents the
      failure that matters. An item that oversells itself as closing a hole will get scoped as
      though it were urgent; it is not, and it gates nothing.
    - **`setup-sites.md` is a RECONCILE declaration, not just a list.** It is read on every pull,
      so changing how its fixture block is produced touches the delivery path — the same path
      items 17, 18 and 21 all landed in. Derive that blast radius first, and if generating it is
      riskier than maintaining it, the honest outcome is to keep the four lists and ship only the
      written criterion. **That is a legitimate result of this item, not a failure of it.**

25. ~~**Five more per-sprint artifacts are prescribed at durable area paths, and one of them is the
    same defect at 73 homes.**~~ **DONE — v0.324.0. What follows is the ORIGINAL scoping and its
    instruction is spent.** Two of its claims are refuted by the work: the durable declaration DOES
    exist (twice over, and it had already decided four of the five with reasons), and the count is
    **74**, not 73. See §*What item 25 measured*. Original text follows.
    Surfaced 2026-08-08 while measuring the false-positive set for a
    general version of 23b's check, **and deliberately left out of v0.319.0** — 23b's scope was two
    edits to one step, and five per-file decisions each needing their own evidence is separate work.
    The measurement is done; do not re-derive it. It is in §*What item 23b measured*.

    **`test-strategy.md` IS THE ITEM.** root=1, `s<N>/` slots=**72**. Identical in kind to
    `consolidation-manifest-prd.md` — same basename, two homes, nothing declaring which is current —
    and invisible to `validate-artifact-paths.sh` for the same reason: both paths conform.
    `bug-analysis.md` (1 and 1) is the same thing small.

    **THREE OF THE FIVE ARE NOT OBVIOUSLY DEFECTS AND MUST BE DECIDED, NOT SWEPT.**
    `brownfield-inventory.md` (root=1, slots=0) is plausibly a genuine one-time durable inventory.
    `codebase-analysis.md` and `doc-reconciliation.md` are prescribed by a step and **written
    nowhere in the reference consumer** (0 and 0), so there is no evidence either way and the honest
    outcome for those two may be "leave it and say why". Control that the measurement is real:
    `prd.md` reads root=1, slots=0, the durable case behaving as expected.

    **DO NOT SHIP A GENERAL LINT FOR THIS.** The general form — every `_bmad-output` path a step
    prescribes must carry `s<N>/` unless the target is declared durable — has a false-positive set of
    **12 of 17** on today's tree, all of them real durable artifacts and logs. What the general form
    actually needs first is a DECLARATION of which artifacts are durable, derived rather than
    hand-listed, and that declaration does not exist. **Producing it is most of this item**, and if
    it turns out to cost more than the five per-file fixes are worth, fixing `test-strategy.md` alone
    and writing down the criterion is a legitimate result.

26. **LC-O15 fires ANCHOR-grained, but a supersession can be ARM-grained — and the remedy it
    prescribes discards the surplus silently.** **REPORTED BY THE CONSUMER 2026-08-08, mid-pull,
    NOT REPRODUCED HERE — record it as theirs until it is.** This plan has been wrong about a
    consumer report's attribution three times (items 13, 17, 18) and exact twice (items 20, 21);
    the run of exactness is not a licence to skip the reproduction.

    **THE REPORT.** `apply.sh`'s worklist step 2/2 tells the operator to narrow
    `overrides/steps__retro__domain-sections.md`'s `shadows:` by removing
    `steps/retro.md#4a. Close-Out Sweep`. Core superseded **one arm** of that section — the
    strikethrough / `--fail-on` machinery, now configured by `AI_DLC_SNAPSHOT_STRIKETHROUGH`, which
    graph already sets to `forbid`. The entry's body under that anchor carries **119 consumer-only
    lines core does not have**, including `S286-CO-CLOSURE-EVIDENCE` (a stale-header closure guard)
    and the `FR-S297-4` ceiling delegation. Narrowing takes core's 4a live and takes all 119 lines
    out of what the lead reads.

    **THE MECHANISM, AS FAR AS IT IS UNDERSTOOD FROM THIS SIDE AND NO FURTHER.**
    `replaces_with=<ENV_KEY>` means *"core now configures what your shadow was written to work
    around."* The narrowing is the right remedy **only when the entry's content under that anchor
    IS the worked-around behaviour.** When it is a superset, the surplus goes with it and nothing
    measures the surplus. The clause asks a question about the ANCHOR and core's change was to an
    ARM inside it.

    **THE PRECEDENT IS THIS PLAN'S OWN, ONE LEVEL DOWN.** v0.312.0 found LC-O15's supersession join
    comparing `norm()` of the WHOLE `shadows:` value while every drift arm below it read through
    `shadow_parts` — so an entry bundling anchors could never match a declaration naming one. That
    fixed the join's grain from ENTRY to ANCHOR. **This report says the same defect survives one
    level up: ANCHOR where the supersession is ARM.** Whether that is the right reading is the
    first thing to establish, not to assume.

    **BEFORE BUILDING ANYTHING, DERIVE THE FALSE-POSITIVE SET — and note that the obvious
    formulation has no subject set yet.** "Warn when the entry's content under a superseded anchor
    exceeds the superseded arm" needs a measurable notion of *the arm*, and today the declaration
    names an anchor and an env key, not a span. **Establishing whether an arm is even addressable
    is the whole of this item's first step.** If it is not, the honest outcome may be that the
    remedy text must stop prescribing a narrowing it cannot scope, and instead hand the operator a
    measured surplus to adjudicate — which is a smaller change than a new join, and possibly the
    right one.

    **IT GATES NOTHING.** `OVERRIDE-SUPERSEDED` is report-only; the blocking row is
    `HARD-LAYER-ADJUDICATION-MISSING`, and a recorded verdict clears it without touching
    `shadows:`. **The consumer's disposition, 2026-08-08: defer the narrowing, record
    `still-additive` against the row's `subject_digest`, and carry the debt in the register's
    `owed` field** — not in `reason:`, because the schema's own text records that 5 of 46 rows on
    this consumer encoded owed work in free prose, one of them reading *"Nothing but this reason
    field is tracking that debt."* `OWED-RETRO-4A-NARROW` continues to track it. **The verdict is
    keyed to subject STATE, so it must be recorded AFTER any edit to the entry, and it self-expires
    the moment anyone touches it** — which is the property that makes deferring safe rather than
    permanent.

27. ~~**`ai-dlc-update/SKILL.md` tells step 7 two incompatible things about the skill stamp, and
    `apply.sh` mechanises one of them.**~~ **DONE — v0.320.0 (#458).** Everything below held: the
    attribution was exact, the fix is the flag this item specified, and the fixture gap it named
    was real and is now measured. Two things it did NOT predict are in §*What item 27 measured* —
    no new invariant was owed, and the write had three silent-success paths rather than one.
    **BOTH CITATIONS BELOW ARE NOW HISTORICAL: the fix moved the lines it quotes.** `:308` still
    lands in step 2's defer bullet but the sentence there now names the flag; `:1414` lands on
    unrelated prose, and the "preserving" sentence it quoted is at `:1421`. They are a record of
    why the fix was made, not an instruction — the same status this file's header gives
    `layer-drift.sh:648`. What follows is the original report. **REPORTED BY THE CONSUMER 2026-08-08 with a control, and REPRODUCED
    HERE — the attribution is EXACT, the third consumer report in a row that is.**

    **THE REPORT.** `apply.sh` said `RESOLVED restamp` while leaving `skill_version`/`skill_commit`
    at `0.318.0` and writing the `0.319.0` machinery files. Their control: `apply.sh` names those
    two fields **0** times against **2** for the rulebook fields it does write. Reproduced here
    exactly — `grep -c` over `reconcile/apply.sh` gives **0** and **0**, and `:958-959` writes only
    `commit:` and `version:`. Widened: **NOTHING in the distribution writes either field.** Only two
    files name them at all — `SKILL.md` (10 mentions, all prose) and `self-update-gate.sh` (1). The
    fields are advanced by the AGENT following prose, which is a duty with no mechanism.

    **AND THE PROSE CONTRADICTS ITSELF, 1100 LINES APART. THIS IS THE ACTUAL DEFECT.**
    - `core/skills/ai-dlc-update/SKILL.md:308` — step 2's defer branch: *"Advance `skill_version`/`skill_commit` with that
      apply rather than here."*
    - `core/skills/ai-dlc-update/SKILL.md:1414` — step 7's re-stamp: *"set `version`/`commit` = theirs, **preserving
      `skill_version`/`skill_commit`**."*

    Step 7 is told to PRESERVE exactly the fields step 2 delegated to it. Whichever the agent reads,
    the other is disobeyed, and `apply.sh` implements `:1414` by never touching them. **The consumer
    hit the seam.** Do not file this as "add a write to `apply.sh`" — that would satisfy `:308` and
    break `:1414`, which is right on its own terms: **a rulebook-only apply must not claim a
    machinery version it did not install.**

    **THE FAILURE DIRECTION IS THE ONE ITEM 18 EXISTS FOR, RE-CREATED.**
    `unregistered-drift.sh` emits `CORE-AT-SELF-UPDATE` — *"Not drift, and no action"* — for a
    machinery file byte-identical to the distribution at `skill_commit`, and it reads `skill_commit`
    from the stamp itself. With a STALE `skill_commit`, the machinery files this apply just wrote
    from THEIRS are no longer byte-identical to that ref, so the suppression does not apply and
    **each one reads as consumer drift and draws a HARD status whose printed remedy is to revert
    upstream's own text.** That is verbatim the failure v0.309.0 fixed, arriving through the stamp
    instead of through the scan. **28 files are in both the machinery set and that scan** (control:
    72 machinery files outside it). The reference consumer set the fields by hand and is not
    exposed; the next consumer who does not notice is.

    **THE FIX IS A BRANCH, AND IT BELONGS IN THE PROGRAM RATHER THAN IN TWO PROSE SITES.** Step 7
    preserves the skill fields normally and advances them ONLY when this apply carried the deferred
    machinery slice. The caller knows which case it is — step 2 emitted `SELF-UPDATE-DEFER` — so the
    shape to aim at is an explicit flag `apply.sh` takes, with both prose sites pointing at it
    instead of at each other. **Derive before building:** whether any existing caller would change
    behaviour, and whether `mech_fail` interacts (a withheld stamp must withhold BOTH pairs, not
    one). **A fixture must drive the deferred-slice path specifically** — the existing stamp
    fixtures drive the rulebook pair only, which is why this shipped.

28. **A `subject_digest` is unreadable once its own row stops blocking.** **REPORTED BY THE CONSUMER
    2026-08-08 and REPRODUCED HERE — attribution exact.**

    **THE REPORT.** To re-read the digest they had recorded a verdict under, the operator had to
    **withhold this consumer's LC-O15 rows to re-fire the block**, read the key, then restore the
    register and verify it byte-identical by sha256. Deliberately breaking your own gate state is
    not a workaround, it is the absence of a reader.

    **REPRODUCED.** The digest reaches the operator only inside the
    `HARD-LAYER-ADJUDICATION-MISSING` message `adj_check` emits when `adj_lookup` returns non-zero
    (`reconcile/layer-drift.sh:483-487`). Once a verdict is recorded `adj_lookup` returns 0 and the
    function returns before printing anything. **There is no read-only mode, no `--list`, and no way
    to recompute the key** — controlled: `subject_digest` appears in the script four times, none of
    them behind a usage flag or a listing mode.

    **WHY IT MATTERS BEYOND ERGONOMICS, and this is the part to lead the fix with.** The verdict is
    keyed to subject STATE — `layer-adjudication-tier` Part 3 proves one byte of entry change
    re-fires the block — and the register's `owed` field is designed to be UPDATED as a debt is
    worked down. **Both operations need the key, and the key is only visible while the row blocks.**
    So the register is writable exactly when it is empty and unreadable exactly when it is in use.

    **THE SHAPE TO AIM FOR is a listing that needs no gate state**: the adjudicable rows and their
    digests, printed on request, independent of whether a verdict exists. **Derive the caller set
    first** — `adj_check` is reached from every clause at ADJUDICATED level, so a listing mode must
    not itself become a second implementation of the candidate join. Gates nothing.

**Do NOT redo R1, R2 or R5** — they are merged as v0.275.0/v0.276.0/v0.277.0, and their
sections in the design record below are labelled SHIPPED.


**NOTIFY AFTER EVERY NUMBERED STEP, AND DO NOT STOP FOR IT.** Operator direction 2026-08-07:
send a notification when each numbered item completes — *"but don't stop processing, these
would just be informational"*. Send it and carry straight on to the next item. These are a
progress feed, not checkpoints, and treating one as a checkpoint is the stall this plan exists
to prevent.

**HOW TO REACH THIS OPERATOR, measured 2026-08-07 — the obvious call is the one that fails.**
`PushNotification` REFUSES to send while the terminal is active: *"this terminal is active, so
your output here already reaches the user."* So the ping fired the instant you get blocked —
seconds after they last spoke — never arrives, and you will wrongly conclude the channel is
broken. Two earlier diagnoses of exactly that (Remote Control unpaired; Apple Terminal
swallowing it) were both wrong, and both were guesses published as findings.

- **Informational, after a numbered step** → `PushNotification`, then keep working. If it comes
  back "not sent", that is fine and expected: the operator is present and has already read it.
- **You need something from them** — a decision, a `sudo` command only they can run → use
  `AskUserQuestion`. It reaches them regardless of terminal state. Do not use it for progress;
  that abuse is what makes the channel worthless.
- Desktop alerting is now automatic on the operator's machine via a `Notification` hook, so it
  does not depend on you remembering. Mobile still does.

**PING THE OPERATOR — on any question, on any decision, and when this plan completes.** The
operator cannot see this session. From outside, "still working" and "stopped, waiting on you"
look identical, so silence is not a neutral state: it is a stall the operator can only find by
polling. Say something when you need a decision, when you hit a premise that does not hold, and
when you are done — including when "done" means you stopped early. **This instruction is carried
forward into every plan in this repo and is enforced by `scripts/validate-plan-shape.sh`; a new
plan that omits it fails the build.**

## What the PC-S331 carve-out measured (the filed cause was right; the refutation written here was the wrong measurement)

**v0.344.0 (#505).** Subject: `core/hooks/ai-dlc-acknowledge.sh`'s `/ai-dlc-update` exemption from
the Rule 29 pause deny.

**THE ITEM HELD THE FIX ON A ZERO, AND THE ZERO WAS AN ARTEFACT OF HOW THE TOOL_USE WAS MATCHED.**
It recorded 66 of 66 sessions carrying both signals and none carrying the tool_use alone, and
concluded the reported cause was unconfirmed. Re-derived by parsing each transcript line and asking
for a `tool_use` content block whose `name` is `Skill` and whose `input.skill` is `ai-dlc-update` —
rather than for the two strings anywhere in one file — the same corpus gives **66 with the tool_use,
10 of them with no `<command-name>/ai-dlc-update</command-name>` anywhere in the session**. Eight of
the ten carry only `<command-name>/clear</command-name>`. **Two carry the hook's own grep pattern as
literal text**, `<command-name>/ai-dlc(-update)?</command-name>`, which a substring match scores as
a marker.

**THE CONTROL IS THE OTHER 56**, found by the same grep in the same pass, so the ten are a real
absence and not a broken pattern.

**THE LIVE CAPTURE THE ITEM DEMANDED FOUND WHAT NEITHER CANDIDATE MECHANISM PREDICTED.** A
PreToolUse probe recording, at hook time, the payload keys and whether the transcript then carried
each signal; two headless sessions, one per invocation path:

```
operator types /ai-dlc-update, at the next tool call
   marker=present   tooluse_line=missing   (a typed slash command calls no tool at all)
agent calls Skill(ai-dlc-update), at that dispatch
   marker=missing   tooluse_line=missing   lines=12   tool_input={"skill":"ai-dlc-update"}
the same session, at the next tool call
   marker=missing   tooluse_line=present   lines=17
```

Row 1 is the control for rows 2 and 3. The filed cause — the marker is never written for an
agent-driven run — is CONFIRMED, and the read-before-write alternative is refuted: the marker never
arrives, not late and not at all. **What neither reading predicted is row 2's second column.** At
the moment of the first dispatch the transcript carries no session-level signal whatsoever, because
the tool_use line for the call being denied has not been flushed yet — so a transcript arm keyed on
the tool_use, which the item named as the material for the second fix, cannot cover the dispatch
either. Only the payload can.

**SO THE THREE SIGNALS ARE DISJOINT AND ALL THREE ARE LOAD-BEARING**, which the sibling mutation
battery asserts one arm at a time: `.tool_input.skill` for the dispatch, the serialized tool_use for
the updater's own per-file `Agent` fan-out (an `Agent` payload carries no skill field), and the
`<command-name>` marker for a typed session. The payload is applied AFTER the transcript scan
because the transcript is one tool call stale by construction and a `Skill(ai-dlc)` resume must
override an updater tool_use earlier in the same session.

**THE NEW TRANSCRIPT PATTERN IS STRUCTURAL AND ITS FALSE-POSITIVE SET WAS MEASURED BEFORE IT
SHIPPED.** `"name":"Skill","input":{"skill":"…"` can only appear as a real tool_use block: a
transcript that QUOTES the string carries it inside a JSON string with every quote
backslash-escaped. Over 498 local transcripts it matched exactly the 69 carrying a real
`Skill(ai-dlc*)` tool_use and **0** others, the control being that the session which did the work
mentions the string four times and matches zero.

**THE CARVE-OUT HAD NO FIXTURE**, in either direction, which is the condition under which an arm
that cannot fire reads exactly like one that passed. `updater-session-signals` now covers all three
paths plus five negative arms.

**AND THE BATTERY BEHIND IT PROVED NOTHING ON ITS FIRST RUN, GREEN.** The subject fixture reads its
mutant seam from an `AI_DLC_USS_HOOK` environment variable and scrubs every `AI_DLC_*` variable for
I10 hermeticity — written in that order, the scrub unset the seam, every mutant exercised the REAL
hook, and all five came back with zero reds, which the harness scores as five survivals. **It was
the unmutated control that made it legible**: the control was green too, and a control that agrees
with every mutant is the signal that the harness, not the code, is what the run measured.

## What item 2 measured (the item was right, and the trap was in how the probe was built)

**SHIPPED as v0.341.0 (#498).** The item's premise reproduced exactly, at ground truth, with a
control: seeded into one tree, `sprint-status/sprint-301.yaml` is the single `BLOCKING` row and the
migrated sibling `s302/sprint-status.yaml` is not reported at all.

**THE END-TO-END PROBE — the real `roll`, then the real validator over its own output:**

```
pre-fix writer   froze to  sprint-status/sprint-301.yaml   VERDICT: FAIL — 1 blocking
fixed writer     froze to  s301/sprint-status.yaml         VERDICT: PASS
```

**AND THE FIRST TWO VERSIONS OF THAT PROBE BOTH RETURNED `PASS` ON BOTH ARMS, which is the part
worth carrying.** `sprint-status.sh` resolves the project root from ITS OWN location, not from
`--root`, and it needs `schemas/sprint-status.json` beside it. A copy placed in a scratch directory
died at `cannot resolve the project root` — and the second attempt died at `cannot find
schemas/sprint-status.json` — both times BEFORE writing anything, so the validator found no
offending path and reported a clean tree. **A `PASS` over a roll that never ran is indistinguishable
from a `PASS` over a roll that ran correctly.** The fix was to make the probe print the roll's own
output line as its control; the two dead arms are visible there as a `FAIL —` from the script rather
than as a freeze.

**ALL THREE PARTS THE ITEM NAMED WERE REAL, and the second is the one it correctly predicted a fix
would miss.** `max_frozen` globbed `sprint-status/sprint-*.yaml`; on a migrated consumer that
directory holds only `_preamble.yaml`, so it already returned nothing, and its caller's fallback
returns sprint 1 — *"which would silently re-stamp a live project as greenfield"*, in the words of
the comment directly above it. Moving the writer alone would have traded a blocked push for a
destroyed sprint. It reads both spellings now, and a freeze already present under the old one is
honoured where it lies rather than duplicated into the slot.

**SIX MUTANTS, EACH KILLING EXACTLY ONE ASSERTION, plus an unmutated control that passes the whole
battery:**

```
reader loses the s<N>/ slot branch      -> migrated archive resolves to 1
reader loses the legacy branch          -> unmigrated archive resolves to 1
slot branch stops requiring the file    -> an empty s<N>/ dir counts as a freeze
writer reverts to the legacy path       -> freeze destination wrong
existing-freeze check ignores legacy    -> a second archive minted beside it
divergence check disabled               -> a divergent freeze does not HARD_BLOCK
```

**GETTING TO "EXACTLY ONE" TOOK TWO RESTRUCTURINGS AND BOTH ARE THE SAME LESSON: an assertion that
reads the destination cannot also be the assertion that tests something else about the freeze.**
The byte-faithfulness and idempotency arms were keyed on the new path, so the path-revert mutant
killed three arms at once; they now resolve the freeze wherever it landed and the destination has
its own single arm. Then the divergence control, seeded under one spelling, failed whenever a mutant
changed which spelling the writer consults — slot-only seeding made the path-revert mutant kill two,
legacy-only seeding made the ignore-legacy mutant kill two. Seeded under **both**, each mutant kills
its own and nothing else.

`core/fixtures/artifact-path-migration` is untouched and is the control that the two spellings are a
real pair rather than a rename: it still asserts the migration MOVES the old form.

**Dormant on the reference consumer today** — their canonical carries `sprint:`, so the fallback
never runs — and it bites at s302's close.

## What item 28 measured (the item named one twelfth of its own subject population)

v0.331.0. **The report reproduced exactly and the item's stated shape of the fix was wrong**, in a
way that would have shipped a reader reporting 1 of 12 and reading like a complete answer.

**THE REPRODUCTION, with a same-run control.** A shadow of the reference consumer's layer
(`.claude/skills/ai-dlc/` plus the register, copied to scratch — graph is never written) classified
at `9fc216e..HEAD`. With the register in place: **0 occurrences of `subject_digest` anywhere in the
output**, and 11 `EXTENSION-TITLE-MATCHES-CORE` rows absent entirely. With the register withheld —
the control, and the thing the consumer's operator actually did — **12 occurrences across 12 rows,
10 distinct subjects**. The two runs differ only in whether a file exists.

**THE ITEM SAID `adj_check` IS REACHED FROM EVERY CLAUSE AT ADJUDICATED LEVEL, WHICH IS TRUE AND IS
NOT THE POPULATION.** Of the 10 distinct keyed subjects, **one** is an `adj_check` row
(`OVERRIDE-SUPERSEDED`). The other nine, and 11 of the 12 occurrences, are **LC-E19
`EXTENSION-TITLE-MATCHES-CORE`** — a clause at `level: WARN` that computes a digest at
`layer-drift.sh`'s title-join site and `continue`s past its own emit when a verdict exists. So the
item's "derive the caller set first" instruction, followed literally against the ADJUDICATED code
set, produces a listing that is silent about 90% of the keys an operator needs.

**AND THAT SITE HIDES ITS KEY HARDER THAN THE ONE THE REPORT WAS FILED ABOUT.** `adj_check` keeps
printing the candidate row and drops only the blocking message; LC-E19 suppresses the whole row, so
the digest leaves with it. The consumer's workaround — withhold the register, re-fire, restore,
sha256 — was the only reader for both.

**THE FIX IS SITED ON `adj_digest`, NOT ON `ADJ_CODES`,** which is what satisfies the item's real
constraint (do not become a second implementation of the candidate join) rather than its stated
one. Every keyed row in the script asks that one function for its key, so recording the call
records the candidate set without restating who is adjudicable, and a digest site added later is
listed with no edit. Mode: `layer-drift.sh --list-adjudications <dist> <base> <theirs> <consumer>`.

**THREE THINGS THE BUILD HAD TO GET RIGHT AND ONE IT NEARLY GOT WRONG:**

- **The classify path is untouched, PROVEN not assumed** — `layer-drift.sh` at `HEAD` against the
  working tree, same shadow, same range: 47 rows, byte-identical stdout, 0 bytes of stderr both
  ways.
- **No `EXIT` trap.** The accumulator is a file because `adj_digest` runs inside command
  substitution and a variable set there dies with the subshell — but the comment above
  `shadow_keys` records that installing a trap in this script made bash report
  `printf: write error: Broken pipe` from every `printf | grep -q` in it, 90 lines of stderr from
  pipelines the change never touched. The file is removed at the end of the list block instead.
- **The count line is on stderr and always printed, including at zero.** This mode's answer is
  frequently an absence, and an empty stdout is what a broken pass, a wrong consumer root and a
  genuinely unkeyed layer all look like.
- **I54b caught three `listing | grep -q` pipelines in the new fixture arm** before it shipped —
  the EPIPE shape where a match reports as not-found once the writer's remaining output clears the
  pipe buffer. Converted to here-strings. That is the sixth time a mechanism in this repo has
  caught a defect in the fix for another one.

**THE FIXTURE ARMS ARE IN TWO PLACES BECAUSE THE TWO SITES FAIL DIFFERENTLY.**
`layer-adjudication-tier` Part 9 asserts **set equality of the digests across the two register
states** — asserting merely that a digest prints is satisfied by the build being rejected — plus a
mutant with `adj_digest`'s recording removed that lists 0 while its classify output is unchanged,
with an unmutated control from the same copied directory. `layer-title-join` Part 7 carries the
WARN half, and its seed gives the sharpest available control: that fixture's contract is a stub
with **no clause at any level**, corroborated against the contract's own text, so an
`ADJ_CODES`-derived listing could name no subject there at all.

## What the graph session's report measured (v0.336.0–v0.337.0, and one finding I fabricated)

The 0.330.0 → 0.335.0 pull and both homing jobs completed: one hop, 0 `HARD-*`, 0 new
adjudications, the 12 `W11` rows exactly as predicted, brief 1030 → 648 lines, graph PRs #898,
#899, #900. **Four things came back with it. Two became releases, one became a `CLAUDE.md` rule,
and one I got wrong.**

**v0.336.0 (#482) — `ledger-rotate.sh --apply` ARCHIVED A LIVE ENTRY, matching it against the
entry's own QUOTATION of the rule.** A push candidate filed ABOUT a rule writes the form the rule
matches, and the test is per-ENTRY across every buffered line. **The report said the quotation was
FENCED. It is INLINE, and that decides the fix** — measured, a fence carrying the ESCAPED awk form
does not match at all, while inline backticks and bare prose both do, **so a fence-skipping fix
would have shipped green and left the defect live.** Fix is one character class, `\(v[0-9]`.
A second defect fell out of measuring the first and nobody had filed it: **`\(v` also matches
`(verified`**, so a versionless close passed a rule whose banner promises a version. False-negative
set measured against the ARCHIVE of genuine closes — the population a tightening endangers —
71 → 70, the single loss being that versionless close.

**v0.337.0 (#484) — the reconcile log, where the OBVIOUS fix was the wrong one.** `apply.sh` never
wrote the log step 7 mandates (0 occurrences against 9 files naming it). But a real log carries
eight sections and `apply.sh` can observe two; a skeleton it could fill ships empty sections that
read as written ones. So the boundary is stated twice — step 7 names the writer, and the tool says
so on every successful run — with a fixture CONTROL that it must not report the log as `RESOLVED`,
because a receipt for an unwritten artifact is worse than silence.

**THE `PC-S329` PREFIX NAMES TWO LIVE CANDIDATES**, and this plan's record had only one. The second
is the reconcile-log one. That is the collision v0.329.0 already documented, arriving again.

**A `CLAUDE.md` RULE CAME OUT OF MY OWN RUNBOOK: TWO DONE-WHENS COULD NEVER HAVE GONE GREEN.**
*"budget green"* was unattainable when written — the only FAIL is an unrelated artifact at 309%,
byte-identical before and after. *"confirm each still resolves"* was unverifiable — no file in that
corpus produces a genuine anchored resolution. The executor substituted a probe and a negative
control, correctly, both times. **Prove a done-when's PASS is reachable, the same way this repo
requires proving a new check can fire.**

**AND ONE FINDING IN THIS SECTION IS A FABRICATION I PUBLISHED AND THEN WITHDREW. READ THIS BEFORE
RE-OPENING `ledger-reverify`.** Asked why I had left its loose close rule alone, I re-measured with
a PYTHON MODEL of the predicate — a bare phrase match over every line — and reported *"15 live
entries skipped, 4 of them biased toward candidates about the ledger tooling."* **The shipped rule
is already anchored**: line-start, optional `<br>`, optional bold-open, and a class excluding
backticks, so blockquotes, inline backticks and shell lines never closed anything. The numbers were
my model's, not the program's. I wrote the fix and a fixture arm before the MUTANT caught it — the
arm passed identically under the pre-fix predicate, which is the definition of vacuous. Reverted;
nothing shipped. **The tell was one command I skipped: run the shipped reader BEFORE the change.**

**The other deferred item was checked and is NOT a defect.** `LR-S300-2` appears in exactly one
file, `pipeline-snapshot-history.md`, an archive; `validate-locked-anchor.sh` takes a story file as
its subject and does not sweep archives. A frozen history citing a requirement that has since moved
is what a history does.

## The consumer-reported defect run (v0.326.0–v0.330.0) — five reports, five fixes, none a plan item

**These are not plan items and never entered §*Order of execution*.** They are defects the
reference consumer filed against this repo during three consecutive pulls, and they are recorded
here because a fresh session reading only the numbered list would not know they happened — or that
five of the seven releases since item 24 came from this channel rather than from the plan.

| filed | subject | answered |
|---|---|---|
| `PC-S320` | a blocking row's remedy ran the operator's own answer as a command | v0.326.0 (#468) |
| `PC-S326` | a fixture asserting the pool arm could not run on any consumer | v0.327.0 (#469) |
| `PC-S327` | `apply.sh` prescribed a destructive retire over a recorded verdict | v0.328.0 (#470) |
| `PC-S328` | the backstop for wrong receipts joined on a name upstream never writes | v0.329.0 (#471) |
| `PC-S329` | `NAMED-UPSTREAM` instructs the close its own status forbids | v0.330.0 (#472) |

**THE ATTRIBUTION RECORD MATTERS MORE THAN THE COUNT.** This plan was wrong about a consumer
report's attribution three times (items 13, 17, 18) and exact five times running (items 20, 21,
then `PC-S320`, `PC-S326`, `PC-S327`, `PC-S328`, `PC-S329`). **The run of exactness is still not a
licence to skip the reproduction** — every one of the five above was reproduced here with a
control before any code was written, and two of the five had a detail the report got wrong
(`PC-S326`'s release attribution was one release off; `PC-S328`'s scope was far larger than filed).

**THE CLASS THEY SHARE, and it is the one to expect next:** four of the five are a mechanism that
was *present and could not fire* — a remediation that deleted its own answer, a fixture green in
the only layout it could not help, a worklist built without reading the register that decides it,
a join asking for a name nobody writes. **A zero, a silence, or a clean line from an instrument
that cannot see its subject.** That is this repo's recurring defect and the reason its invariants
carry self-written probes.

**WHAT THE MECHANISMS CAUGHT IN THE FIXES THEMSELVES** — the strongest evidence in this section,
because it is the system working on its own author: I54b twice (an EPIPE `grep -q` that reports
"not found" on matching input), I39 (a new ledger status undocumented at two of its three bound
sites), I33's own blindness to the two-step form of its subject, a fail-closed guard that aborted
an unrelated fixture's control, a probe that certified an instrument it never exercised, and a
partial-revert mutation that proved the layer it left in place.

## What the close-instruction contradiction measured (a state both rules refuse to own)

v0.330.0. Reported by the consumer as the `NAMED-UPSTREAM` close-instruction contradiction, and
filed by them as `PC-S329`. **The contradiction is real and it is the smaller half.**

`ledger-reverify.sh` skips an entry on `ADOPTED UPSTREAM` ANYWHERE in it; `ledger-rotate.sh`
archives only on the strict `**ADOPTED UPSTREAM (v`. The asymmetry is deliberate and correct.
Its STATED cost was *"an entry wrongly kept costs one more pull to notice"* — **and nothing
noticed**, because rotate reported what it moved and never what it refused.

**Measured on graph at 0.329.0: 8 entries**, in a run whose summary line read
`0 closed entries — nothing to rotate`. One carries
`**ADOPTED UPSTREAM (absorbed before base <sha>, verified <date>)**` — a genuine bolded close the
strict rule refuses only because the parenthetical does not start with a version.

**THE GENERAL FORM: when a safe default's cost is "someone will notice later", check that
something does.** The rule was right; the sentence excusing it was the defect.

The strict rule is untouched. Rotate now names the refused set BEFORE the nothing-to-rotate exit,
which is the case the state hides in, and says plainly that withdrawn / retained / absorbed-before-
base entries belong there legitimately. The `NAMED-UPSTREAM` row names the archivable form; step
3f now reads **not auto-closable** and states what the annotation actually does.

## What PC-S328 measured (the backstop for wrong receipts joined on a name upstream never writes)

v0.329.0. **Filed by the consumer, reproduced and enlarged here.** `NAMED-UPSTREAM` is the THIRD
SIGNAL — the one that fires when a receipt is structurally incapable of closing. It searched for
the entry's FULL SLUG; upstream cites the short `PC-S<n>`.

```
ledger entries                     128       distinct PC-S<n> prefixes      29
  found by the FULL-SLUG join       20         cited in upstream history    20
                                                 naming exactly ONE entry    9   <- attributable
                                                 shared by 2+ entries       11   <- ambiguous
```

**THE COMPOUNDING IS THE FINDING.** `RECEIPTS-UNDECIDED` has read 24-of-24 restatements for three
pulls; NAMED-UPSTREAM exists to catch absorption when receipts are wrong. On the entry whose
receipt WAS wrong, the backstop was silent too — **two independent instruments, both blind, and
their agreement reading as confirmation.** Among the misses: `PC-S320`, `PC-S326`, `PC-S327`,
filed by this consumer and fixed here in this same session.

**THE NAIVE FIX IS WRONG AND THE MEASUREMENT SAYS SO.** 11 of the 20 cited prefixes are shared, so
matching the prefix regardless attributes one commit to every entry a sprint filed. The prefix is
therefore a FALLBACK that attributes only when it resolves to ONE entry; otherwise
`NAMED-UPSTREAM-AMBIGUOUS`, emitted **once per prefix**. Per-entry emission produced **45 rows
from 11 prefixes** — noise added by the fix for a signal that was missing, which is the same trade
the naive match makes one level along.

**GROUND TRUTH against graph's real ledger, before and after:** `NAMED-UPSTREAM` **6 → 10**,
ambiguous **0 → 7 rows**, every other status byte-identical, **nothing lost** (control: the
old-set minus new-set difference is empty). Newly attributed: `PC-S298-WAIT-FOR-DELIVERABLE…`,
`PC-S302-ADJUDICATION-RERUN-BASE…`, `PC-S308-SELF-UPDATE-INSTALLS…`, `PC-S318-SELF-UPDATE-SLICE…`.

**THREE MECHANISMS CAUGHT DEFECTS IN THE FIX, which is the strongest evidence in this entry:**
- **I54b** flagged `git log … | grep -q .` in the new code — EPIPE under `pipefail` reports
  "not named" on a slug that IS named.
- **I39** refused the new status until step 3f documented it AND `emit-report.sh` named it.
- The fixture's bounding mutation rewrote ONE of the now-TWO `git log` calls — a **partial
  revert**, which proves the layer left in place. Both forms are rewritten now.

**THE CONSUMER'S OWN TWO ERRORS ARE WORTH RECORDING** because both were caught by measuring: a
receipt anchored on a GUESS at the fix's shape (`apply.sh` gaining the register — upstream routed
through a row token instead, so it could never close), and a reachability control that was
**unfalsifiable**, its only occurrence being the receipt's own prose. Both re-anchored.

## What PC-S327 measured (two tools disagreeing, and the destructive one had no reader)

v0.328.0. **Filed by the consumer during the 0.327.0 apply, reproduced here with a control.**

```
grep -c layer-adjudication-register   reconcile/apply.sh        0
grep -c layer-adjudication-register   reconcile/layer-drift.sh  2
```

**THE DEFECT IS A DISAGREEMENT, NOT A MISSING CHECK.** `layer-drift.sh` reads the register and
correctly emitted NO blocking row for an entry carrying a recorded `still-additive`.
`apply.sh` builds its override-retire worklist from that same run's `OVERRIDE-SUPERSEDED` rows and
never asks whether a verdict exists — so the gate said *decided, proceed* and the manifest an
operator is told to work TOP-DOWN said *delete it*. The prescribed step would have removed a live
stale-header closure guard and the `FR-S297-4` ceiling delegation, **119 consumer-only lines**,
against a verdict recorded the previous day.

**THE OPERATOR REFUSED IT CORRECTLY AND NOTHING IN THE TOOLING SUPPORTED THE REFUSAL.** That is the
part worth keeping: the next operator would have had to re-derive the same refusal from scratch,
and item 26 is open precisely because LC-O15 is anchor-grained while the decision was arm-grained.

**THE FIX ROUTES THE ANSWER THROUGH THE ROW, not through a second register reader.**
`layer-drift.sh` already computes the verdict; it now declares `ADJ_ROW_TOKEN` and writes
`adjudicated=<verdict>` into the row, and `apply.sh` RESOLVES that declaration. A second reader in
`apply.sh` would be a second thing to keep in step with the schema.

**DIGEST-KEYING IS WHAT MAKES SUPPRESSION SAFE RATHER THAN AN EXEMPTION.** The digest covers the
entry AND the core file it hooks at theirs, so a SPENT verdict suppresses nothing — the token is
absent and the worklist returns. Verified both ways.

**TWO DEFECTS IN THE FIX, BOTH CAUGHT BEFORE SHIPPING, and the first is the instructive one.**
The draft referenced `ADJ_ROW_TOKEN` in `apply.sh` without resolving it. `apply.sh` runs `set -u`,
so that is an unbound variable and **the run aborts mid-apply** — strictly worse than the defect.
It now fails closed with a message. Second: `adj_lookup` and the new `adj_verdict` would have
carried two copies of one `jq` expression; `adj_lookup` is now written in terms of `adj_verdict`.

**I86 binds the token in BOTH directions** — `apply.sh` may not restate the literal, and
`layer-drift.sh` may not declare a token it never writes into a row. That second arm is the
repo's recurring class arriving inside the guard against it: **a token with a home and no emitter
leaves the suppression unable to fire on any pull, forever, while every check stays green.**
Suite assertions `enforcement-map-derivations` A28–A29.

**STILL OPEN, and this does not close it:** item 26 (LC-O15 is anchor-grained, the supersession
was arm-grained). v0.328.0 stops `apply.sh` contradicting a recorded verdict; it does not make an
ARM addressable, which is what item 26 asks. Reproduce item 26 before building it — its first step
is still to establish whether an arm is addressable at all.

## What PC-S326 measured (an invariant blind to its own defect one assignment apart)

v0.327.0. **Filed by the consumer against v0.322.0, reproduced here with a control.** Not a plan
item — it surfaced when the operator ran the 0.320.0 → 0.326.0 apply and the consumer's pre-push
blocked on the fixture.

```
core/fixtures/whole-read-pool/run.sh   consumer layout  rc=2   distribution  rc=0
```

**THE DEFECT.** Its 10d mutation arm resolved `sprint-status.json` as the validator's dirname plus
a parent hop into a `schemas` sibling. `install.sh` SPLITS that parent — `core/scripts/<x>` →
`scripts/ai-dlc/<x>` while `core/schemas/` → `.claude/schemas/` — so the arm was green here and
dead everywhere it shipped. **The consumer's pre-push blocks on its fixture suite, so this was a
permanent stop**; the operator pushed with `--no-verify`, on the record, and was right to flag it
rather than skip the fixture, because a skip reads like a pass.

**WHAT WAS UNREACHABLE IS THE POINT.** That arm proves v0.322.0's `SPRINT_WHOLE_READ_SET` measures
the pool rather than the file merely existing — **the check that stops the locked-requirements move
from grading itself**, which is the whole reason 23c-1 and 23c-3 shipped together. It was green
upstream and could not run anywhere it mattered.

**I33 EXISTS FOR EXACTLY THIS AND WAS BLIND BY CONSTRUCTION.** Its grammar wants the `dirname` call
and the `/..` walk in ONE expression; this shipped them one assignment apart, and **I33's own
pattern returns 0 on the defective file.** I33's header records *"this pattern occurs ZERO times"*
as its false-positive measurement — true of the form it can see, and the same shape as I54 → I54b,
where the pipeline form sat outside I54's grammar by construction.

**A zero over the wrong grammar reads exactly like a clean tree.** That is the general form, and
this repo now has three instances of it.

**I33b** covers the variable-in-between form. Measured before shipping: **1** occurrence across
every `core/fixtures/**/*.sh`, **0** after the fix.

**A DEFECT IN THE GUARD AGAINST THE DEFECT, CAUGHT BEFORE IT SHIPPED.** The first draft inlined the
detection TWICE, so blinding the corpus scan left the probe passing against its own private copy —
**a probe certifying an instrument it never exercised.** Scan and probe now call one function.
Asserted: `enforcement-map-derivations` A26–A27.

**AND THE FIX'S OWN COMMENT TRIPPED THE CHECKER IT WAS EXPLAINING.** Quoting the defective
expression verbatim made I33 — which scans that file — flag the example. Written out in words
instead. Third time this repo has paid for quoting a string a checker is hunting.

**ATTRIBUTION CORRECTION for the ledger:** the consumer's report names 0.326.0's arm; `git log -S`
puts the line in **v0.322.0** (`b2954cc`). Re-anchor the PC-S326 receipt accordingly.

## What PC-S320 measured (a remediation that ran the operator's own answer)

v0.326.0. **Filed by the consumer, reproduced here exactly, and it is core's.** Not a plan item —
it surfaced while reviewing graph's 0.320.0 → 0.325.0 reconcile report, which reported it still
live.

**THE DEFECT.** Backticks inside a double-quoted shell string are command substitution.
`reconcile/layer-drift.sh` lines **960, 963, 967, 970** each wrapped the token `still-additive`,
which is the VERDICT an operator must record to clear an `OVERRIDE-SUPERSEDED` row — and that row
is ADJUDICATED, so it BLOCKS the pull. The shell ran the word, printed
`still-additive: command not found`, and substituted nothing:

```
a consumer that still wants it for its own reasons records  with a reason and the block clears
```

**The blocking row named a verdict as its remedy and deleted which verdict.** The same file already
carried four correctly-escaped backticks, so the idiom was known and four sites were missed.

**VERIFIED BEHAVIOURALLY, not by the absence of backticks** — the four message strings were expanded
before and after: 4 of 4 printed `records <BLANK> with a reason` at `origin/main`, 4 of 4 carry the
word now.

**THE FALSE-POSITIVE SET DECIDED THE SHAPE OF THE ENFORCER.** A crude backtick grep flags **seven**
shipped scripts; **six are inert** — every one Python inside a `<<'PY'` QUOTED heredoc, where the
shell expands nothing and a backtick is literal. Exactly one executed. I85 therefore resolves
heredoc quoting rather than grepping, and its NEGATIVE probe is what keeps that narrowing.

**PROVEN THREE WAYS, because a scanner that has stopped seeing the defect prints the same clean line
as a clean tree:** restoring `origin/main`'s file makes I85 fire with all four rows; blinding the
scanner's match character makes it FAIL CLOSED on its own positive probe; removing the heredoc
narrowing trips its negative probe. Suite assertions `enforcement-map-derivations` A23–A25.

**SEQUENCING, and it is the reason this could ship mid-pull.** The release moves no hooked core file
and ships no rulebook change, and `subject_digest` covers the entry plus the core file it hooks
(`layer-drift.sh:486`). `layer-drift.sh` is neither, so a consumer holding recorded verdicts keeps
them.

## What item 24 measured (the sites were five, and only one of them could derive)

v0.325.0. **Three of the item's figures are corrected, and the correction is the item.**

```
                        item said      measured 2026-08-08
fixtures on disk            129                132
shipped                     117                120
.dist-only                   12                 12
declaring sites               4                  5   <- I8 parses install.sh's loop line
                                                        INDEPENDENTLY of I74, and was found
                                                        by RUNNING, not by reading
`.dist-only` with a reason    0 (implied)        5 of 12   <- 7 were zero bytes
```

**THE COLOCATED DECLARATION THE ITEM ASKS FOR ALREADY EXISTED.** `.dist-only` is a marker file
in the fixture's own directory, I74 already derived the ship set from it, and 5 of the 12
already opened with the same sentence — *"This fixture is DISTRIBUTION-ONLY. It must never be
copied to a consumer."* The item's *"the criterion is stated NOWHERE"* is true of the GENERAL
rule and false of the per-fixture one. **Same shape as item 25 one release earlier: the
declaration exists and has a hole.**

**BOTH PRE-CODE QUESTIONS SETTLED, AND THE BLAST RADIUS IS ASYMMETRIC — that is what decided
the scope.**

- **`install.sh` can derive.** It reads from `$SCRIPT_DIR/../core/fixtures/`, the SOURCE tree,
  which is present whenever it runs. It is also one of the two lists that actually disagreed at
  v0.316.0.
- **`uninstall.sh` CANNOT, and not for a cost reason.** It runs on a consumer where
  `core/fixtures/` does not exist, and its list bounds a **DESTRUCTIVE** loop. Globbing the
  consumer's `tests/fixtures/` would delete fixtures the consumer wrote. **That safety property
  is why the list is there and it was written down nowhere** — which is item 24's own complaint,
  pointing at item 24's own evidence.
- **`core-manifest.md` and `setup-sites.md` are read by ~20 programs** — the core guard hook,
  `core-paths.sh`, `validate-layer-entries.sh`, the drift scan, and a dozen fixtures. Changing
  their glob grammar to a wildcard-with-exclusion touches every reader. **Riskier than
  maintaining them**, which is the outcome the item names as legitimate.

**GROUND TRUTH, on a tree built by running `install.sh` into an empty directory** rather than
in `core/`: **120 fixture directories installed, 0 `.dist-only` leaked** (control: two known
shippers present, four known marked ones absent).

**I74's JOIN COULD NOT SURVIVE THE CHANGE, AND WAS NOT PRETENDED INTO SURVIVING IT.** It read
install.sh's hand-written list. With install.sh deriving, that join compares a derivation to
itself and passes for a reason unrelated to anything being right. **A tautology reads exactly
like a check that holds** — this repo's recurring defect, arriving as a consequence of a fix
rather than as an authoring mistake. So: I74 becomes **(b)** the derivation is still there and
still excludes the marker, plus **(d)** every marker carries a body; and the list-vs-tree joins
moved to **I8**, retargeted onto `uninstall.sh`, which still has a list and needs one.

**THE FIFTH SITE WAS FOUND BY RUNNING.** I8's `fixture_list()` awk-parses
`^for fixture_dir in …` out of install.sh, independently of I74's own `sed` doing the same
thing, and it read the literal `$(` out of the new derivation. Neither the item nor the reading
of the four declared sites showed it; the validator did, on the first run after the edit.

**MUTATION REPLAY — four mutants, each failing EXACTLY ONE assertion, against an unmutated
control from the same tree:**

```
derivation repointed at core/schemas/        -> "does not read core/fixtures/"
`.dist-only` guard deleted from the loop     -> "does not exclude"
plan-shape/.dist-only truncated to 0 bytes   -> "EMPTY body: plan-shape"
one name dropped from uninstall.sh's list    -> "uninstall.sh never names"
```

**All four are now SUITE assertions** (`enforcement-map-derivations` A19–A22). **I74 had no
fixture coverage at all** before this release — an I65-class gap in the invariant that packages
every fixture.

**Adding a fixture now costs THREE edits, not four**, and the removed one is the one that broke.

## What item 25 measured (the declaration existed; it enumerated PRODUCERS and the defect was not one)

v0.324.0. Measured against graph at `54e71012a`, read-only.

**THE ITEM'S PREMISE IS REFUTED.** It said *"what the general form actually needs first is a
DECLARATION of which artifacts are durable … and that declaration does not exist."* It exists, in two
independent pairs of carriers that already agree:

```
durable set     artifact-consolidation.md  "THE AREA ROOT IS FOR DURABLE ARTIFACTS ONLY
                                            -- the four this step targets"
                validate-artifact-budget.sh  WHOLE_READ_SET
                same four: prd - product-brief - architecture - carry-over-backlog

exempt set      core/skills/ai-dlc/SKILL.md  Rule 24 sprint-stamped-drafts paragraph
                validate-draft-stamps.sh     scope note
                same four: codebase-analysis - brownfield-inventory - doc-reconciliation
                           (one-shot onboarding)  +  bug-analysis (bug-keyed)
```

**Four of item 25's five were therefore ALREADY DECIDED, with reasons, before the item was written**
— the three "undecidable" ones and `bug-analysis`. The item read them as open because it measured
the TREE and never asked the rulebook.

**WHAT THE DECLARATION HAS IS A HOLE, AND IT IS THE SHAPE OF THE HOLE THAT GENERALISES.** Both
carriers enumerate **producers**: analyst drafts (Rule 24), onboarding one-shots, a bug-keyed
exception. `test-strategy.md` is a TEA deliverable authored at `stories-test-strategy.md` §5, so it
is in none of the three classes and nothing was wrong. **A classification keyed on who writes a file
cannot see a file whose writer is not in the list.**

**THE PRESCRIPTION SIDE WAS THE SAME DEFECT ITEM 23b FOUND, not the one item 25 named.** The item
said the path was durable-and-wrong. It was **absent**: §5 delegated to `/bmad-testarch-test-design`
and prescribed no path at all. The consumer filled the gap for 72 sprints with
`test-strategy-sprint-<N>.md` — a sprint token in a basename, which rule 2 forbids — and the s<N>/
migration renamed all 72 into slots (`git show`, `R100` rows, s134→s297). Core prescribes the
basename at exactly **two** sites and both are READERS.

**THE ROOT COPY'S OWN FIRST LINE IS THE EVIDENCE.** It reads `# S272 Sprint Test Strategy — AWS
Cost-Lean Optimization`, `**Sprint:** 272`, last written 2026-06-26 while slots run to s301: one
sprint's document standing in as the durable one, and precisely what the two readers were told to
read. Control: `prd.md` is root=1 with no planning slot (its only `s<N>` hit is
`s271/party-mode-transcripts/prd.md`, a transcript directory) — the durable case behaving as
expected.

**RE-MEASURED, AND THE ITEM'S FIGURES DRIFTED: 74 homes, not 73** — 72 direct `s<N>/test-strategy.md`
plus two under consumer archive subdirectories, plus the root copy. Do not carry 73 or 72.

**THE CRITERION, DERIVED RATHER THAN HAND-LISTED, over the 10 basenames core prescribes at
`_bmad-output/planning-artifacts/` root.** An area-root path is legitimate iff the project holds
exactly ONE instance of that basename for its whole life, and there are exactly three ways that is
true, each naming the mechanism that keeps it true:

```
(a) durable / consolidated    4   prd, product-brief, architecture, carry-over-backlog
(b) live + rotated            1   sprint-status.yaml  (route.md Step 1; 56 planning +
                                  47 implementation s<N>/ archives on the consumer)
(c) one-shot onboarding       3   codebase-analysis, brownfield-inventory, doc-reconciliation
(x) none of these             1   test-strategy   <- one write per sprint, nothing
                                  consolidating it and nothing rotating it, so sprint
                                  N+1's write DESTROYS sprint N's
```

**`bug-analysis` IS SHAPE (x) AND STAYS OUT, and the exemption now says so instead of implying
agreement.** A second bug sprint does destroy the first's analysis (root=1, `s292/`=1 on the
consumer). It stays out because no bug KEY exists to compose a path from, and inventing one is Rule
26(a) speculative mechanism. Stated as a disagreement with a reopening condition rather than
absorbed silently.

**TWO PRE-EXISTING FIXTURE DEFECTS FELL OUT OF EDITING `check-23-draft-stamps`.** Its `good` and
`decoy` trees stamped drafts `s288-<base>.md` — the basename form rule 2 forbids and the check's own
error text has always contradicted — and passed anyway, because the disk half only looks for the bare
name at the area root. Both moved to `s288/`. And **the first placement of the new decoy trap was
vacuous**: a step file under `steps/`, a directory neither half scans, so it would have passed
however the matching were written. Moved into `extensions/`, and the second mutant below is what
proves it load-bearing.

**MUTATION REPLAY, both `cmp -s`-guarded copies against an unmutated control from the same
directory.** Reverting `DRAFTS` to the pre-v0.324.0 four flips `bad-test-strategy` to accepted and
changes nothing else — **the arm fails only its own assertion.** A second mutant making the layer
half basename-anchored reds `decoy` on `hooks: steps/stories-test-strategy.md`; it also reds `good`
on `hooks: steps/carry-over-evaluation.md`, which is two independent witnesses of one property and a
pairing that predates this release, not two entangled assertions.

**OWED TO THE OPERATOR, AND IT DOES NOT WEDGE A PULL.** `validate-draft-stamps.sh` is absent from
`core/git-hooks/pre-push` (control: `validate-artifact-paths.sh` is present at :142), so Check 23
fires at PLANNING gates only. graph's stray root copy blocks s302's first planning gate until it is
moved: `git mv _bmad-output/planning-artifacts/test-strategy.md
_bmad-output/planning-artifacts/s272/test-strategy.md` — s272's slot exists and holds no test
strategy. One file.

## What item 23c's derivation measured (the sites move; the instrument does not)

Full finding:
[`docs/reviews/artifact-inlet-locked-block-derivation.md`](../reviews/artifact-inlet-locked-block-derivation.md).
**No release.** Measured against ai-dlc `main` at `0.320.0` and graph at `54e71012a`, read-only.
Every figure was derived in this pass.

**THE STOP CONDITION IS NOT MET.** The item said *"if the derivation says they do not move cheaply,
say so and stop."* They move cheaply. The four validators cost, between them, one default-value
change and one prose edit — and one of the four is not a site at all.

| validator | verdict |
|---|---|
| `validate-locked-anchor.sh` | The SoR pin is a **basename equality test** at `:475` against `DEFAULT_SOR_BASENAME` (`:129`), already overridable by `--sor`. `resolve_artifact` (`:301-346`) tries the story's own directory FIRST and then walks up six levels for the bare basename — so a story in `s<N>/stories/` reaches `s<N>/<sor>` before the area root **without any change at all** |
| `validate-request-coverage.sh` | Takes `--brief <file>` from the caller (`:79`). Its only caller is prose, `gate-validation.md:2248`, and that already writes `--brief <brief>` as a placeholder. **Free** |
| `validate-spec-join.sh` | **NOT A SITE.** It anchors join (1) on the spec folder's `.memlog.md` (`:132`) and reads no artifact the move touches. It names the token in two comments |
| `validate-artifact-budget.sh` | **Free — and that is the defect.** See below |

**THE STEP-FILE COUNT IS NEITHER 10 NOR DERIVABLE AS 10.** **8** step files name
`LOCKED_REQUIREMENTS`; **13** name one of the durable artifacts by path (control: a fabricated
basename returns rc=1 over the same pathspec). Ten is between the two and matches neither, which is
the underived-count class core Rule 31 exists for, in this plan's own text.

**THE WORK THE ITEM DID NOT NAME.** `is_sprint_slotted()` (`validate-artifact-budget.sh:429`, called
at `:859`) excludes **every** `s<N>/` path from the whole-read pool. It shipped in v0.317.0 for a
good reason — after item 10's migration the pool was summing 26 archived copies as live, a 2.35x
overstatement. But it is path-shaped, not sprint-aware, and cannot say *"the CURRENT sprint's slot is
live."* So a 23c that moves the sprint's LOCKED block into `s<N>/` drops the pooled sum by three
quarters of the brief **while the analyst still reads the same bytes whole at gate time.** The row
goes green for a reason unrelated to anything getting smaller. **A 23c release that reports its win
from the budget row is measuring its own exemption**, which is the inert-instrument class arriving
through the change meant to fix what the instrument measures.

**WHAT THE MOVE IS WORTH — and item 19's datum understated it.** Partitioning graph's live brief by
heading, span to the next same-or-shallower heading:

```
product-brief.md   1030 lines
  ## Synthesized Current-State                        182   17%   DURABLE
  ## In-Force LOCKED_REQUIREMENTS Blocks              564   54%   SPRINT
       ### LOCKED block: S299                          180
       ### Discovery Findings & Implementation — S301   377   <- filed under the LOCKED
  ## Changelog (4 entries, all 2026-08-05, all S301)   223   21%   SPRINT      heading, not
                                              -----------------                a LOCKED block
  sprint-scoped                                        787   76%
```

**17% of the durable artifact is durable.** `carry-over-backlog.md` is 1528 of 1647 lines (**92%**)
under sprint-token headings; `prd.md` is 265 of 1530 (**17%**). And the delimited block is only
**169 lines** (`:253-421`) — an edit keyed on the sentinels moves 169 and leaves the 377-line
discovery narrative behind.

**THE CHANGELOG HAS NO READER ANYWHERE IN CORE.** Six sites prescribe appending one —
`core/skills/ai-dlc/SKILL.md:554`, `_gate-procedures.md:205`, and four convergence lines naming a durable target
(`discovery.md:245` the brief, `research-requirements.md:127` the PRD, `architecture.md:289` the
architecture doc, `doc-repair-backfill.md:45` all modified artifacts). Over `core/scripts/` and
`core/hooks/` the only matches are five lines in `validate-mandatory-rules.sh`, all about the
*validation-cycle-log* model, one of which says it outright: *"in per-artifact changelogs (freeform
prose, not countable here)"* (`:139`). Positive control on the same paths: `LOCKED_REQUIREMENTS`
matches in five files.

**A FALSE ZERO FELL OUT OF PRODUCING THAT FIGURE AND THE CONTROL AGREED WITH IT.**
`git grep -in 'change ?log'` without `-E` treats `?` literally in BRE and returned **nothing**; the
fabricated-token control returned rc=1 as well, so the control could not distinguish. The `-E` form
matches in twenty files. **A control has to be a token you know is PRESENT**, and this is the second
shape of unreadable zero this plan has recorded.

**CROSS-SPRINT REFERENCE IS REAL IN PROSE AND ABSENT FROM ANCHORS.** Across graph's 988 story files
`LR-S<n>-` resolves to the story's own slot **3759** times and to a different sprint **260** (141
more in unslotted stories). But the anchored set is **62 citation lines in 46 of 988 files** (26
`full_text_source:`, 36 `requires_context:`) and **0 of them cross a sprint.** Per-sprint walk-up
resolution is correct on today's corpus — **by accident**, since nothing forbids a cross-sprint
`full_text_source:` and Rule 13 makes locked requirements cumulative. 31 of the 62 cite the full
area-root path and would dangle after a move; they are never re-validated, so that is an acceptance
rather than a blocker. **No sprint slot holds a competing copy today** — `s<N>/product-brief.md` 0,
`s<N>/prd.md` 0, `s<N>/carry-over-backlog.md` 0, `s<N>/architecture.md` 23 (the archives
`is_sprint_slotted` exists to exclude).

**AND CORE PRESCRIBES THE ACCUMULATION.** `discovery.md:127-128`: *"A brief accumulates one block
per sprint, and the closer may carry a discriminator so they can be told apart."* The inlet is the
design, not consumer drift.

**23c IS FOUR CHANGES, AND THIS SECTION'S FIRST ORDERING OF THEM WAS WRONG — CORRECTED BELOW, with
the original struck rather than deleted because the reason it was wrong is the useful part.**

- **~~23c-1 — the pool counts the live sprint's slot. First, because every later release is graded
  by the row it fixes.~~** **NOT SHIPPABLE ALONE.** "Stop exempting the live slot" is the wrong
  change: a live-slot copy of a POOLED basename is a snapshot of the durable artifact and counting
  it double-counts — graph holds **23** historical `s<N>/architecture.md` copies (latest `s288`,
  live sprint 302). The right change is a second pool arm for a per-sprint whole-read basename in
  the LIVE slot only, and **that basename does not exist until 23c-3 writes it.** An arm with no
  subject on any consumer is the check-that-cannot-fire class. **23c-1 ships WITH 23c-3.**
- **23c-2 — the changelog. TAKEN FIRST — v0.321.0 (#461).** It needed nothing from 23c-1 because
  nothing reads a changelog, so it is graded by content leaving the whole-read path rather than by
  the pool row. **Its size was overstated as "21% of the brief"**: the LIVE total across durable
  artifacts is **260 lines** (223 brief, 37 `docs/architecture.md`, 0 `prd.md`), the rest sitting in
  `-history.md` files `is_archive()` already exempts. **The case is correctness, not size.** New
  fixture `changelog-sprint-slot`, red on the pre-fix tree naming all **6** sites.
- **23c-3 + 23c-1 — the writer, the pin AND the pool arm, in one release. DONE — v0.322.0 (#462).**
  §4a writes `s<N>/locked-requirements.md`; the brief keeps a pointer. **The SoR became a PAIR
  rather than a replacement** — refusing the legacy `product-brief.md` would fail 31 of 62 anchored
  citations on the reference consumer, all resolvable and none defective, which is the check
  reporting a migration as a fabrication. `prd.md` stays refused and the fixture asserts that in the
  same run as the widening. The prose restatements moved WITH the default, not after it. The pool's
  `SPRINT_WHOLE_READ_SET` resolves `sprint-status.sh sprint-id` and counts the LIVE slot only —
  a `s*/` glob would sum every sprint that ever ran. **The unmutated control earned its keep on the
  first run**: a mutant staged in a scratch dir could not reach `sprint-status.sh` and scored an
  unearned kill, and staging the resolver alone was still short, because it reads
  `../schemas/sprint-status.json` and refuses to guess.
- **23c-4 — cross-sprint anchoring. DONE — v0.323.0 (#463), and the answer was RESOLVE.**
  `resolve_artifact` takes the anchor and tries the sibling `s<n>/` first when it carries
  `LR-S<n>-`. **Refusing would have been wrong**: Rule 13 makes locked requirements cumulative, so
  the citation is honest and the text is genuinely there. **And leaving it would have been worse
  than the accident it started as** — while the block sat in the durable brief a cross-sprint anchor
  resolved by construction; v0.322.0's move made the walk-up reach the story's own slot and report
  `anchor not found`. Nothing widened: a fabricated bullet under a cross-sprint anchor still reds.
  **Item 23 is closed.**

## What item 27 measured (the item was right; two things it did not predict)

**v0.320.0 (#458).** The report's attribution was exact for the third consumer report in a row, and
the fix is the one this item specified: a flag, not a write. Nothing below re-derives the report —
it held.

**THE THREE DERIVATIONS THE ITEM DEMANDED BEFORE BUILDING, with their controls:**

| derivation | answer | control |
|---|---|---|
| would any existing caller change behaviour? | **NO** — 21 invocation sites, every one exactly four positional arguments, none passing a fifth | the same extraction reports four redirection-carrying lines as non-four, so it is not an argument counter stuck on the answer |
| does `mech_fail` interact? | **YES, and it is structural** — the machinery write sits inside the same branch as the rulebook write, so a withheld re-stamp withholds both | the fixture drives the withheld path with the flag ON and asserts all four fields unmoved |
| is `apply.sh` in the self-update gate's bare-invocation probe (item 11's class)? | **NO** — the gating set is what the consumer's pre-push INVOKES, and both pre-push hooks name `apply.sh` **0** times | 3 for `validate-enforcement-map.sh` in the same grep; and bare exit code is unchanged at 1, measured against `origin/main`'s copy |

**THE FIRST THING THE ITEM DID NOT PREDICT: NO NEW INVARIANT WAS OWED, AND THAT IS A MEASUREMENT
RATHER THAN A JUDGEMENT.** The join that failed is *prose names a mode the target script does not
dispatch* — which is **I60**, shipped at v0.216.0, both sides derived rather than hand-listed. It
covers this for free provided the citation is spelt with the flag adjacent to the script name, which
is the shape `emit-report.sh --verify <report> …` already uses. Both `SKILL.md` sites are written
that way. **Proven by breaking it**: renaming the case arm on a `cmp -s`-guarded copy produces
`FAIL: I60 found shipped file(s) naming a mode the target script does not dispatch: apply.sh
--carried-machinery-slice`, and the restored tree passes. A new I85 here would have been a third
hand-listing of a join that already derives itself.

**THE SECOND: THE WRITE HAD THREE SILENT-SUCCESS PATHS, NOT ONE.** A `sed` keyed on
`^skill_version:` over a stamp that has no such line **matches nothing and exits 0**, which is
byte-identical in every observable way to having written. So is a `sed` over a legacy single-line
stamp, and so is a write whose value came from an unreadable `VERSION`. All three now either insert
in schema order or emit a row (`skill-restamp-withheld`, `skill-restamp-failed`), and the result is
**read back** rather than trusted.

**THE FIXTURE GAP THE ITEM NAMED IS REAL AND NOW HAS A NUMBER.** Two fixtures SEED a four-field
stamp (`apply-drift-after-write`, `core-write-guard`); **0 assert `skill_version` or `skill_commit`
after an apply.** Control: 3 assertions on `version:`/`commit:` in `apply-restamp-theirs` alone. New
fixture `apply-machinery-stamp`, 19 arms, with two mutants — the flag defaulting on, and the write
reverted at **both** guards, checked for partiality so a half-revert cannot score — an unmutated
control copy from the same directory, and an arm asserting that the second mutant leaves the first
assertion GREEN, because two arms dying on one mutant means one of them is vacuous.

**IT SHIPS AND IT RUNS INSTALLED**, which is item 20's class: `scripts/install.sh` into an empty tree,
then the fixture from the consumer root — PASS, with the mutant arms firing, so it is not green by
skipping.

**NOTHING VISIBLE CHANGES ON GRAPH.** Its stamp was already correct, set by hand during the 0.319.0
apply. This release is owed to the next deferred-slice pull, on this consumer or any other.

## What item 23d decided (NO — and the FOR argument was right, it just is not enough)

**DECISION: `artifact-consolidation` does NOT become its own skill. No release, and this question is
now CLOSED — do not re-open it without new evidence of the kind listed at the end.** Decided
2026-08-08 on the derivation below, all of it measured against the tree at `aa7100b`.

**THE ITEM'S OWN STRONGEST ARGUMENT SURVIVED ITS CONTROL, WHICH IS WHY THIS IS A JUDGEMENT AND NOT A
DISMISSAL.** The plan said the strongest case FOR is that the step is operator-invoked on its own
cadence. That is true and it is genuinely discriminating. Of the 20 pipeline steps, six are entered
from `route.md` rather than by a predecessor's `nextStepFile`, and **`artifact-consolidation` is the
only one route HANDS OVER rather than enters**:

```
artifact-consolidation   - `consolidate` → the operator runs `artifact-consolidation.md`
bug-investigation        | bug | bug-investigation → implementation → deploy-validate → retro
codebase-inventory       | brownfield-a | codebase-inventory → discovery → …
doc-reconciliation       | brownfield-c | doc-reconciliation → doc-repair-backfill → …
carry-over-evaluation    | carry-over | carry-over-evaluation → discovery → …
handoff                  (a resume mechanism, not a variant)
```

The other four are pipeline VARIANTS that chain onward. **A first attempt at this control was WRONG
and is worth recording**: `retro.md:545` matches "operator-invoked", which read as a second such step
— but the sentence is *about consolidation* (*"Retro NEVER runs the consolidation itself"*), and
retro's own frontmatter says *"agent runs autonomously"*. A grep hit inside a file is not a statement
about that file.

**NOW THE FOUR THINGS THE ITEM SAID A SKILL GETS, TESTED ONE AT A TIME. Three buy nothing here, and
that is measured rather than argued.**

| claimed gain | measured | verdict |
|---|---|---|
| its own resident rulebook | **No skill has one.** All **31** numbered rules live in `ai-dlc/SKILL.md`; `ai-dlc-setup` and `ai-dlc-update` define **0** each and both CITE ai-dlc's — setup Rule 4, update Rules 4, 5, 8, 25(d), 27, 29, 931 | buys nothing |
| its own fixtures | it **already has one** — `consolidation-residue`, shipped v0.319.0, as a step | buys nothing |
| its own version story | only `ai-dlc-update` carries `skill_version`, and its own SKILL.md says why: it is *"the ai-dlc-update tool itself"*, advanced by the autonomous self-update, because update is the thing that PERFORMS the version transition and must move ahead of the rulebook. `ai-dlc-setup` has none | not a skill property — specific to the self-updating tool |
| its own invocation surface | **real, and the only real gain.** Core ships **no `commands/` directory**; skills ARE the invocation surface, so there is no cheaper way to get `/ai-dlc-artifact-consolidation` | real |

**THE RULE-DEPENDENCY ARGUMENT WAS TESTED AND REFUTED — RECORDED SO IT IS NOT RE-RAISED.** "A
separate skill would have to carry or restate ai-dlc's rules" looks decisive until you check whether
the existing skills manage it: `ai-dlc-update` cites seven of ai-dlc's numbered rules and is a
separate skill anyway. **Depending on the rulebook does not make something a step.** The control
killed the argument.

**WHAT DOES SEPARATE A SKILL FROM A STEP TODAY IS THE SUBJECT, AND IT IS ONE CLEAN NUMBER.**

```
references to `_bmad-output/planning-artifacts/`
  ai-dlc-setup       0
  ai-dlc-update      0
  ai-dlc            70
```

**Both existing skills act on the INSTALLATION. The pipeline acts on the PROJECT'S ARTIFACTS.**
`artifact-consolidation` acts entirely on the project's artifacts — the same four
`carry-over-evaluation` whole-reads and `route.md` Step 1a gates on — and since v0.319.0 it resolves
its sprint slot from the pipeline snapshot's `sprint_id`. **setup and update can each run with no
pipeline state at all; consolidation cannot.**

**THAT IS THE DECIDING ARGUMENT, AND IT IS ABOUT COHERENCE RATHER THAN COST.** Promoting
consolidation would create the first skill that reads the pipeline snapshot and writes into
`_bmad-output/planning-artifacts/s<N>/`. The skill/step boundary would then predict nothing, and
that boundary is currently the only thing telling an author where new work belongs. **A distinction
that stops discriminating is worse than the packaging it was meant to improve** — this repo has
shipped that failure under other names and this is the cheap moment to not ship it again.

**AND THE COST IS REAL, though it is the weaker half of the case.** Declaration-site references for
an existing skill, counted across the five sites that would all need entries:

```
                install.sh  uninstall.sh  core-manifest  setup-sites  enforcement-map  TOTAL
ai-dlc-setup             8             2              2            6                7     25
ai-dlc-update           14             2              6            6               45     73
```

Plus its own fixtures, plus migrating the **5** core files that reference the step today
(`core/team-roles/architect.md`, `core/scripts/validate-artifact-budget.sh`,
`core/skills/ai-dlc/SKILL.md`, `steps/carry-over-evaluation.md`, `steps/route.md` — the plan's own
figure, re-derived and unchanged), plus a permanent second surface to install, reconcile,
drift-check and pull. **v0.319.0 is the live measurement of that overhead**: adding ONE fixture cost
four ship-list edits and a failed push to learn which four (item 24). A skill is that shape, larger,
forever.

**SO: one real gain — an invocation surface — against 25–73 declaration sites, a second reconcile
surface, and the loss of the only boundary that currently means anything. NO.**

**WHAT WOULD RE-OPEN THIS, stated so the answer is falsifiable rather than permanent.** Any one of:

- **Consolidation stops depending on pipeline state.** If 23c moves sprint-scoped content out of the
  durable artifacts and consolidation degenerates into a rare genuine refactor with no `sprint_id`
  to resolve, the subject argument weakens and this is worth re-asking.
- **A second operator-invoked, project-artifact-scoped operation appears.** One such operation is a
  step; two with shared machinery is a skill, and the shared machinery would be the thing being
  packaged rather than the file.
- **Core grows a `commands/` surface.** The one real gain would then be available without a skill,
  which settles it in the other direction — the answer stays no and gets cheaper to act on.

**NO IMPLEMENTATION IS AUTHORISED BY THIS AND NONE IS ADDED TO THE ORDER OF EXECUTION**, which is
what a "no" is supposed to look like under this item's own terms.

## What item 23b measured (the refusal set is EMPTY, and two instruments were wrong on the way there)

v0.319.0 (#452). Measured against graph at `5e0f3b2`, read-only. **The reduction was not touched**,
as item 23's own terms require.

**THE ITEM NAMED TWO DEFECTS AND THERE WERE THREE.** The third is the one that explains the other
two: `:41` prescribed the manifest at the area root, and **`:51` and `:62` prescribed no path at
all** for the two drafts and the coverage report. An unprescribed path is not a wrong path — it is
the analyst choosing, every pass, with nothing to be consistent with. Item 19 read the area-root
manifest and did not ask what the other three files were told.

**THE REFUSAL SET IS EMPTY, AND THE PREMISE BEHIND IT WAS A CONTENT TOKEN READ AS PROVENANCE.**

```
33 byproduct files at the area root   (re-derived; unchanged since a8ef9412c)
  DIRECT   24   the adding commit's own subject names the sprint — zero inference
  INFERRED  9   nearest sprint-naming commit in first-parent order
                  7 at walk-back distance 1
                  2 at distance 6 and 7, both BRACKETED s298 back / s299 forward
  REFUSED   0
destination slots: s243 s244 s247 s248 s249 s268 s272 s274 s280 s287 s293 s298 s301
```

The plan's *"at least two carry no recoverable sprint at all (they say `S999`)"* is refuted. `S999`
**does** occur in two of the 33 — in a carry-over ID list, as content — and both of those files
resolve: one DIRECT to `s293`, one INFERRED to `s268`. **The plan read a token in the file as the
file's sprint, and the file's sprint was never in its content.** Same shape as item 16's finding
that the claim was true about the NAME and never asked about the POSITION.

**TWO INSTRUMENTS WERE WRONG, AND BOTH ARE NOW WRITTEN INTO THE STEP so the next re-home does not
repeat them.**

- **Content frequency is a FALSE signal, by construction.** A consolidation byproduct's content IS
  other sprints — that is what it is consolidating — so the modal sprint token is the sprint being
  consolidated, not the one doing it. `consolidation-manifest-carry-over-backlog.md`, first
  committed **2026-06-05**, has S297 (×35) as its modal token. **S297 began 2026-07-22.**
- **`git log --follow` walks a draft into its SOURCE's history.** A consolidation draft is a
  near-copy of the live artifact, so rename detection follows the similarity: three drafts reported
  creation dates of **2026-02-27, 2026-03-05 and 2026-03-08** — months before consolidation existed
  — and `--diff-filter=AR` shows **no rename row at all**. Bare `--diff-filter=A` is correct for
  these files because the migration did not move them; `--follow` is correct for the files it did.
  **Neither instrument is right for both, and the discriminator is whether a rename happened.**
  Worked control: every `s<N>/sprint-status.yaml` reports an add date of **2026-08-07** — the
  migration date — under bare `--diff-filter=A`, which is the same trap pointing the other way.

**AND THE FIRST JOIN WAS WRONG, WHICH IS WHY IT HAD A CONTROL.** Joining on commit DATE against a
subject-derived sprint timeline agreed on 13 of 15 and **disagreed on 2, both by exactly one sprint
in the same direction**. Cause: **graph starts more than one sprint per day** (s243 and s244 both
first appear 2026-06-05; s248 and s249 both 2026-06-09), so "latest sprint on or before D" picks the
higher one. Re-derived on first-parent ANCESTRY POSITION instead of the calendar: **24 of 24 agree.**
The second control was caught being vacuous before it was believed — comparing a join that reads the
add commit against that same commit's subject is a tautology — and was split into DIRECT (no
inference) and INFERRED (with its walk-back distance reported).

**NO EXISTING CHECK COULD HAVE CAUGHT THE DEFECT, and the reason generalises.** I82 binds every
artifact path core prescribes to the grammar, and `validate-artifact-paths.sh` enforces it on the
consumer — but the grammar's rule is *the directory is the only sprint slot*, so what both detect is
a sprint TOKEN outside the slot. **An area-root path carrying no token is syntactically conforming,
and so is the slotted one. Both pass, and neither checker is wrong.** A syntactic grammar cannot
separate a durable artifact from a per-sprint one that omitted its sprint; only the step that writes
the file knows which it is. The new fixture therefore asserts against the STEP, and its assertion 4
is a **join** — Step 6's removal set derived from Step 2's write set, compared both ways — rather
than a second hand-list.

**RED REPLAY against the pre-23b step file:** 4 assertions fail and the mutation guard exits 2.
Verified drivable in the **consumer** layout as well as the distribution — red on graph's installed
0.318.0 step, green on the fixed one, which is the item-20 class covered rather than assumed.

**THE `install.sh`/`uninstall.sh` JOIN FIRED on the one ship-list site I missed** —
`FAIL: install.sh and uninstall.sh fixture loops disagree … consolidation-residue`. That is **item
24's cost demonstrated live**: the ratchet works, and it costs four edits and one failed run to
learn which four.

**FIVE MORE PER-SPRINT ARTIFACTS ARE PRESCRIBED AT DURABLE PATHS. NOT ACTED ON — this is item 25.**
Measured while deriving the false-positive set for a general check, over all 39 `_bmad-output` paths
core's step files prescribe:

```
                          root copies   s<N>/ slots   reading
test-strategy.md                    1            72   the same defect at 73 homes
bug-analysis.md                     1             1   the same defect, small
brownfield-inventory.md             1             0   plausibly durable — a one-time inventory
codebase-analysis.md                0             0   prescribed, never written — undecidable
doc-reconciliation.md               0             0   prescribed, never written — undecidable
prd.md            (control)         1             0   the durable case, behaving as expected
```

**`test-strategy.md` is the strongest instance in the repo and it is not the consolidation step.**
It is the identical condition to `consolidation-manifest-prd.md` at 72x the scale, and it was
invisible for the same reason. **Deliberately not absorbed into 23b**, whose scope was two edits to
one step: five per-file decisions, each needing its own evidence, is a separate item and this repo's
rule is that scope arriving unsequenced is the defect.

## What item 23a measured (the 417% breach was an instrument reading, and both halves were core's)

Full finding: [`docs/reviews/graph-artifact-budget-attainability.md`](../reviews/graph-artifact-budget-attainability.md).
Two releases: **v0.317.0 (#449)** and **v0.318.0 (#450)**. Measured against graph at `a8ef9412c`,
read-only, on the tracked (clean) copies of all four artifacts.

**THE ITEM EXPECTED "NO" AND THE ANSWER IS "YES, ALREADY".** Both numbers in the reading were
wrong, independently, in the same direction:

```
                                    reported     true      error
whole-read pool (denominator)         66,000   330,000    5.00x too small
summed artifacts (numerator)         275,812   117,379    2.35x too large
                                ------------------------------------------
                                          417%       36%
```

**NEITHER DEFECT IS THE CONSUMER'S, and the consumer could not have seen either from the row it was
handed.** It was told `OVER … 417% of it → consolidate` while sitting at 36% of its pool — the
inert-mechanism class, arrived at from the opposite direction to the one this plan usually catches.

- **The numerator.** `:796` finds pool members by basename across two whole trees. Correct until
  item 10's migration renamed every `architecture-s251.md` to `s251/architecture.md` — the LIVE
  basename — at which point the same search summed the archive. 30 rows under a label reading
  `(4 planning artifacts)`: 4 live, 23 per-sprint archives, 3 party-mode transcripts, control sum
  275,812 exactly. **The check was right and the corpus moved under it.** All 26 spurious rows
  carried an `s<N>` component, so one rule excludes all of them, reusing the grammar's own
  `s[0-9]+` component match rather than a second spelling of it. The `s301-close-out/` decoy is the
  load-bearing half: a prefix match would exclude a LIVE artifact from a HARD_BLOCK budget, which
  fails OPEN.
- **The denominator.** `resolve_reader_window()` shipped at v0.124.0 greping `^- Personal:` out of
  `team-roles/analyst.md`; **v0.174.0 (`989939a`) deleted that line from every role file core
  ships**. Fifty releases of an unreachable `1000000` arm and a `200000` fallback that was designed
  as the tightening default for the UNKNOWN case and became the only reachable branch. Controlled:
  `^- Personal:` rc=1 under `core/team-roles/` (control: `^- ` bullets in every role file), `[1m]`
  rc=1 there, and the ONLY occurrence of `Personal:` across `core/`, `templates/`, `scripts/` and
  `install.sh` was the grep itself. graph's analyst resolves `sonnet` → `claude-sonnet-5[1m]`
  through the config block — a 1M window.

**THE COMMENT NAMED THE RIGHT SOURCE AND THE CODE NEVER READ IT.** `:244` already said the window
comes from `aiDlcModels`; the only occurrence of that string in the file was that sentence. The
working two-hop idiom was twenty lines away in `ai-dlc-dispatch-guard.sh:203-205`. **A prose
statement of where a value comes from is not a reader of it** — the same shape as this repo's
`grep -qF` over a whole file being satisfied by a comment.

**AND THE FIXTURE KEPT IT GREEN BY RECONSTRUCTING THE DELETED FORMAT.** `whole-read-pool:63` wrote
its own role file with a `- Personal:` line. Four assertions exercised the resolver against a shape
core had not shipped for fifty releases, and every one passed. **A fixture that builds its own input
can outlive the world its input came from** — a variant of the cannot-fire class in which the check
*does* fire, against a world that no longer exists.

**ORDER MATTERED AND WAS DERIVED, NOT PREFERRED.** Fixing the window alone gives
`ok … 275,812 tok (pool 330,000, 83% of it)` — a PASS reported for the wrong reason that would hide
the numerator defect permanently. Numerator first leaves `OVER … 177%`, still correct against a
still-understated pool. **No intermediate state fails open**, which is why they are two releases in
this order rather than one.

**THE FLOORS WERE DERIVED ANYWAY, AND THE ANSWER FLIPS AT A 200K WINDOW.** Bytes on the tracked
copies, tokens at the validator's own `BPT=4`:

```
                          live tok   floor   relocatable and why
carry-over-backlog.md       42,554  38,949   only 4 of 49 item blocks are CLOSED (14,422 B, 8.5%);
                                             37 OPEN + 7 IN SPRINT + 1 DOWNGRADED are live work
prd.md                      32,619  31,533   changelog + validation pass; S301's full-text LOCKED
                                             section can go to pointer form now the sprint is closed
                                             (measured density 390-422 B/id over S296/S297)
docs/architecture.md        21,524  20,719   AT ITS FLOOR — ADR prose already relocated 2026-08-05;
                                             what remains is a 286-ADR census table with a Basis column
product-brief.md            20,682   8,219   60% relocatable: changelog 17,306 B + a 32,543 B S301
                                             section that DECLARES itself "not a LOCKED block"
                          --------  ------
                           117,379  99,420      vs  66,000 pool -> 151%   vs 330,000 -> 30%
```

**At a genuine 200K window the threshold is unattainable** — 130–151% after every byte consolidation
may move has moved, with `carry-over-backlog.md`'s floor alone at 59% of the pool. **At the 1M window
graph runs, it is attainable and already met.** So the item's premise was right about the shape of
the risk and wrong about whether graph is in it.

**TWO THINGS MEASURED AND DELIBERATELY NOT ACTED ON.**

- **7 carry-over items marked `IN SPRINT` name sprints that have since closed** (S290, S295, S299;
  41,638 B). Consolidation cannot dispose of them; carry-over-evaluation can. **Graph's triage, not
  core's** — reported, not scheduled.
- **The item's second bullet was WRONG.** "The four artifacts are in no `BUDGETS` table row" is
  true and is the DESIGN, stated at `:313-314` with its derivation at `:232-237`: four per-file
  limits bounded nothing real, and the binding quantity is the sum against one window. The
  consequence drawn from it — that no single artifact has a quotable threshold — is correct and is
  not an omission.

**A FIFTH QUESTION IS NOW ON THE TABLE AND IS NOT IN THIS PLAN.** The pool's **33% share** and its
**artifact set** were derived against a hypothetical, because until v0.318.0 no consumer had ever
been measured with a correctly-resolved window. graph is the first data point — 36% of 330,000.
Whether 33% is the right share is now answerable with real numbers and was not before. **Not
scheduled; recorded so it is not mistaken for settled.**

## What item 21 measured (reproduced, attribution exact, and one fixture arm was vacuous)

v0.316.0. **The consumer was right about the program this time** — the second report in a row,
after items 13/17/18 each named the wrong one.

**THE MECHANISM WAS SETTLED BY EXPERIMENT BEFORE ANYTHING WAS TOUCHED**, as this item required,
because the answer decides live-versus-latent. bash reads a script incrementally, keeping a byte
offset:

```
in-place overwrite (cp, same inode)   bash resumed inside the NEW text, ran the
                                      replacement's tail, and exited rc=0
atomic replace (mv, new inode)        unaffected; the original ran to completion
no replacement (control)              unaffected
```

**THEN REPRODUCED AT GROUND TRUTH.** Scratch consumer installed at 0.310.0, pulled to 0.312.0.
Same dist, same range, same tree, same 8 pure-applies; the ONLY variable is where the running copy
lives:

```
running copy = the consumer's own     rc=2, `line 251: syntax error near ';;'`,
                                      stamp withheld, .ai-dlc-applying LEFT, tree partial
running copy = out-of-tree (control)  rc=0, no stderr, re-stamped 0.312.0, marker cleared
```

`overwrite_from_theirs()` wrote with `git show > "$cons"` — open+truncate+write, SAME INODE — and
`apply.sh` is itself in the set it writes, on the copy SKILL.md step 7 tells the session to run.

**THE ABORT IS THE LUCKY END OF THE BAND.** The bash arm shows the same mechanism producing rc=0
with the wrong code executed. **Do not remember this defect as "it fails loudly."**

**THE FIX IS THE IDIOM THE FILE ALREADY USED AT FIVE OTHER SITES** — `.incoming.$$` + `mv`.
Verified by re-running the same reproduction with a consumer carrying the fix: rc=0, no stderr,
theirs landed, stamp advanced, marker cleared, no litter — **identical to the control**, plus the
new `driver-self-update` row.

**THE FIX PROTECTS THE NEXT PULL, NOT THE ONE THAT DELIVERS IT.** The running copy comes from
BASE. The first attempt at the verification arm had this backwards and would have tested nothing.

**AND ONE FIXTURE ARM WAS REMOVED FOR BEING VACUOUS RATHER THAN SHIPPED.** The repair's second
half — the redirect truncated `$cons` BEFORE `git show` ran, so a failed show left an EMPTY core
file — was asserted by driving a THEIRS that lacks the path. **A mutant restoring the redirect
SURVIVED it**, which is what proved the arm could not fire: a THEIRS lacking the path is not
classified as a pure-apply, so the writer is never reached. The remaining ways to fail a `git
show` on a path that IS classified are a corrupted or unreadable object, and a permission-based
arm is exactly the one that passes for the wrong reason when the suite runs as root. It is a
declared gap with its reason, not an assertion.

## What item 19 measured (the reduction is fine; the residue is the defect, and it is core's)

Full finding: [`docs/reviews/graph-artifact-consolidation-review.md`](../reviews/graph-artifact-consolidation-review.md).
**No release**, by the item's own terms — it forbade opening with a mechanism, and nothing here is
authorised. Everything re-derived against graph at `a8ef9412c`, read-only.

**THREE OPERATIONS ARE CALLED "CONSOLIDATION" AND THIS ITEM RAN TWO OF THEM TOGETHER.** (A)
current-state consolidation, core's `steps/artifact-consolidation.md`, 19 passes over 4 artifacts in
66 days. (B) the artifact-path migration, item 10/16. (C) archive-and-reset — s300 and s301 moving a
whole sprint's corpus into `s<N>/archive/`, **graph's own invention and the only one that PREVENTS
accumulation rather than draining it.**

**THE COUNTERFACTUAL IS SETTLED AND DOES NOT NEED RE-ASKING.** The sinks are content that would
otherwise still be live, because the step builds the history draft from lines removed from live:

```
                        live today      sink        never-consolidated
four durable artifacts     469,522  11,568,150          12,037,672 B
                          ~117k tok                        ~3.0M tok   <- 96.1% reduction
```

**AND THE RECURRENCE IS STRUCTURAL, NOT SLOPPY.** `product-brief.md` went 360 → 1030 lines in the
six days after its 08-02 pass, and **7 of 7 headings added in that window are sprint-scoped** (five
carry an explicit `S301` token; the other two are their containers). Sprint output is written into a
sprint-independent file by design. Nothing here argues for consolidating less often.

**THE DEFECTS ARE IN THE RESIDUE AND BOTH ARE CORE'S.**

- **The step writes working files to disk and never says to remove them.** `:51` dispatches two
  drafts, `:41` a manifest, `:62` a coverage report; `:93` replaces the live artifact and the draft
  is never mentioned again. Control on the absence: `delete|remove|rm|clean ?up|discard|retire|unlink`
  returns **rc=1** over the step and matches three sibling step files. Result on graph: **33 of 96
  root-level files in `planning-artifacts/` are byproduct — 1.80 MB, 13.7% of the directory —
  against 383 KB, 2.9%, for the three live artifacts they exist to protect.**
  `consolidation-draft-prd-live.md` is a 1383-line near-duplicate of the 1530-line live PRD,
  differing on 155 lines, with nothing saying which is authoritative.
- **The step prescribes AREA-ROOT paths for per-sprint work products.** Control: `s<N>|sprint slot`
  returns **rc=1** over the step and matches five sibling steps. Live consequence, both tracked
  today: `consolidation-manifest-prd.md` (root, latest token S297) and
  `s300/consolidation-manifest-prd.md` — **same basename, two homes, nothing declaring which is
  current, which is the exact condition item 10 was opened to eliminate.** Eleven basenames now sit
  in both places (control: 85 root basenames in no slot). `validate-artifact-paths.sh` cannot see it
  and is not wrong not to: both paths conform. A syntactic grammar cannot separate a durable artifact
  from a per-sprint one that omitted its sprint.

**THE SINKS ARE NOT A FINDING.** 110,591 lines / 11.6 MB, and nothing reads them — deliberately.
`validate-artifact-budget.sh:367-372` declares `*-history.md`/`*-archive.md` write-only via
`is_archive()` and excludes them, reason at `:62`. Content-level duplication inside them was NOT
measured and is stated as unmeasured.

**ONE PLAN FIGURE WAS STALE AND THIS ITEM REPEATED IT.** "The 48 refusals are still owed" — the owed
set is **98**: 72 AMBIGUOUS + 3 NO-AREA + 23 STORY-NO-SPRINT, from running core's validator against
graph (5054 conforming of 5152, **0 migratable non-conforming**, corpus proved non-empty in the same
run). 72/3/23 was already this plan's recorded v0.308.0 figure; 48 was the FIRST migration's refusal
count over a pre-story subject set. Size the cleanup at 98.

**A MEASUREMENT DEFECT CAUGHT MID-REVIEW, worth carrying: a git pathspec `*` MATCHES `/`.**
`git ls-files '_bmad-output/planning-artifacts/*.md'` returns the whole subtree, not the root level,
so the first duplicate-basename join returned **1395** where the depth-filtered answer is **11**.
Filter depth with `awk -F/ 'NF==3'`, never with a pathspec glob.

**THE METHODOLOGY ANSWER, and it is larger than either fix.** The durable artifacts refill because
sprint-scoped content is written into them. Move a sprint's LOCKED block and changelog into `s<N>/`
and consolidation degenerates from a 19-pass recurring cost into a rare genuine refactor — graph has
already proven the containment half in (C). **NOT SIZED.** `LOCKED_REQUIREMENTS` is read by four core
validators and ten step files; `validate-locked-anchor.sh:129` already parameterises the
source-of-record (`DEFAULT_SOR_BASENAME`, overridable `--sor`), but whether the other thirteen sites
move is UNDERIVED, and deriving it is the prerequisite to proposing anything.

## What item 6 measured (both zeros were unreadable, and the gate was the whole item)

Four releases. The promotion itself is nine lines of YAML; everything else is what the gate turned up.

**THE COUNT, taken on a quiescent post-migration graph over its real pull range, with a working
control (66 rows across ten other statuses from the same run):**

```
LC-O15  OVERRIDE-SUPERSEDED          0     <- FALSE
LC-E6   EXTENSION-RETIRE-CANDIDATE   0     <- a SILENCE
```

**A CONTROL PROVING THE RUN WORKED SAYS NOTHING ABOUT WHETHER THE ARM COULD HAVE FIRED.** That is
the transferable finding, and this plan already had the same shape twice under other names.

**LC-O15's zero was FALSE — v0.312.0 (#435).** The supersession join compared `norm()` of the
WHOLE `shadows:` value against the declaration's, while every drift arm below it reads the value
through `shadow_parts`, lib.sh's one reading of `shadows:`. So an entry bundling anchors could
never match a declaration naming one — and the more anchors an entry bundles the more unrelated
core text it freezes, which is exactly the population the clause exists for. Reproduced one field
apart, same consumer, same range:

```
shadows: steps/retro.md#3. …, #4a. Close-Out Sweep, #5. …, #7. …   0 rows
shadows: steps/retro.md#4a. Close-Out Sweep                        1 row
```

The live miss is `overrides/steps__retro__domain-sections.md`: core declared `#4a. Close-Out
Sweep` superseded at **0.281.0** with `AI_DLC_SNAPSHOT_STRIKETHROUGH`, and the entry's own
`reason:` records two successive re-adoptions of that very section, one of which it calls WRONG.
**And the remedy is not the same remedy** — `--stamp retire` deletes the whole file, so a
multi-anchor hit carries a `retire_anchor=` token and prescribes narrowing `shadows:`.

**LC-E6's zero was a SILENCE — v0.313.0 (#436).** `fixture: none`, honestly declared, and
v0.273.0's note gives the reason the obvious home was refused: `layer-title-join` asserts the
code's ABSENCE and never makes it fire. So no run anywhere had produced the status, and its 0 was
evidence of nothing. New fixture `layer-absorption-retire` fires it on both emit sites. The
control is the sharp part: LC-E6 and LC-E5 come out of the SAME comparison and differ on ONE bit,
whether the core anchor existed at BASE.

**TWO `apply.sh` DEFECTS FELL OUT OF DRIVING IT, and neither has anything to do with item 6 —
v0.311.0 (#434).** They were found because measuring the supersession set meant actually running
the thing that renders it.

- **`say()` printed THREE fields while EIGHTEEN call sites pass FOUR.** Every `WORKLIST` and
  `DECISION` detail was computed and discarded. The operator's row was
  `WORKLIST<TAB>override-retire<TAB><path>` and nothing else, while `SKILL.md` step 7 tells the
  reader to obey a detail beginning `<i>/<n> ATOMIC`.
- **`printf '%s' | while read` dropped its last element,** so a one-key supersession — every keyed
  supersession core has ever declared — emitted ZERO of its key rows. The sequence printed only
  `2/2 … --stamp retire` while its own numbering advertised a `1/2` that never existed: the exact
  reverse of the order the block exists to enforce. `key_total` was right throughout, which is how
  the numbering kept advertising a row nobody printed.

**No fixture drove `apply.sh`'s worklist rendering at all.** The one fixture that greps a
`WORKLIST` row matches field 3, which survived both defects. `apply-worklist-rows` now drives the
shipped script with a stubbed `layer-drift.sh`.

**THE PROMOTION'S COST, MEASURED — v0.314.0 (#437).** `HARD-LAYER-ADJUDICATION-MISSING` on graph
goes **12 → 13**: one row, the LC-O15 true positive. LC-E6 contributes 0. `contract_version`
16 → 17.

**AND THE PROMOTION BROKE A SENTENCE IN THREE FILES.** `layer-drift.sh`'s
`DRIFT-RANGE-DEGENERATE` row, its header comment and `SKILL.md` step 7 each hand-listed the two
ADJUDICATED clauses and asserted a degenerate range disarms every one of them. **LC-O15 is not
range-keyed** — it compares a declaration at THEIRS against the entry on disk — so that stopped
being true the moment the level changed. All three now point at `--adjudicated-codes`, the
derivation I58 already joins at build time. **A hand-list of a derivable set is a defect waiting
for the release that changes the set**, and this one waited exactly one release.

## What item 8's core half measured (the run's one close was false, and its guard was prose)

Re-ran `ledger-reverify.sh` over graph's 56-entry ledger against current core, read-only:

```
STILL-LIVE          53
HAND-REVIEW         15
NAMED-UPSTREAM       5
RECEIPTS-UNDECIDED   1   <- 24 of 24 `theirs_has` receipts, undecided
CLOSE-CANDIDATE      1   <- and it was FALSE
```

**THE ONE CLOSE WAS FALSE, AND THE CONSUMER'S OWN MIGRATION CAUSED IT.**
`PC-S312-STRAYS-DOES-NOT-NORMALIZE-AN-ABSOLUTE-PATH`'s receipt names `docs/retro/sprint-249.md`,
which the artifact-path migration moved to `docs/retro/s249/retro.md`. Its `&&` chain
short-circuits on the missing file and exits 1 — the same status a real fix produces. Verified by
hand at the path that exists now: relative rc=0, absolute rc=1, reproducing exactly as filed.

**The guard for it already existed as a SENTENCE** in the close's own detail, telling the operator
to check the subject paths before draining. That is the same shape item 17 found in §7v criterion
5, two releases earlier.

**WHAT REMAINS IS THE OPERATOR'S, and the numbers say why.** 24 of 24 `theirs_has` receipts are
undecided — this pull moved neither side of them — so the 53 STILL-LIVE set is still a mixture of
live entries and entries whose anchor cannot tell fixed from broken. **Re-anchoring those receipts
is graph's, not core's.** Do not treat the 53 as a work queue until it is done.

**Receipt kinds, measured rather than assumed: 31 `manual`, 26 `theirs_has`, 21 `sh`, 13
`theirs_lacks`.** Five NAMED-UPSTREAM entries are named by upstream history at v0.153.0, v0.172.0,
v0.247.0, v0.248.0 and v0.300.0 and each needs a human confirmation this file cannot give.

**TWO OF THIS SESSION'S OWN MEASUREMENTS HERE WERE WRONG and were caught before being quoted.** A
receipt-kind tally reported *52 of 53 entries carry no receipt* — receipts are spelled
`<br>verify:`, so the field index was off. A path sweep reported *37 of 65 named paths no longer
exist* — it swept distribution paths into a consumer-side question. Precisely scoped, exactly ONE
`verify: sh` receipt names a migration-moved artifact path, with a control showing the same
receipts name paths that do exist. Both errors are the same class this item exists to audit.

## What item 18 measured (reproduced — and half the report was again the wrong program)

**THE MECHANISM IS REAL AND WAS REPRODUCED AT GROUND TRUTH**, on this repo's own history rather
than a synthetic tree. A consumer holding `core/hooks/ai-dlc-acknowledge.sh` exactly as the
distribution had it at an intermediate ref draws `HARD-CORE-DRIFT-ABSORBED`, whose printed remedy
is a **REVERT** — deleting upstream's own content as though the consumer had written it. Control,
same run, the same file at base: `CORE-OK`.

**THE EXPOSURE IS DERIVED: 28 files** sit in both the machinery set (what step 2's autonomous
self-update rewrites) and `unregistered-drift.sh`'s scan set — every hook, six schemas, six
templates, `core-manifest.md`, the `ai-dlc-setup` skill. Control: **72** machinery files sit
outside the scan, so the two sets are genuinely different and the intersection is not an artefact.

**HALF THE REPORT'S ATTRIBUTION IS REFUTED AND THE OTHER HALF IS NOW OPEN.** The consumer named
`core-manifest.md` and `setup-sites.md`. The first is in the scan set and is fixed. **The second
is not in it at all** — it lives under `core/skills/ai-dlc-update/`, which I12 excludes — proven
with a control (the same pathspec yields 76 files and finds `core-manifest.md`). Nothing in
`preclassify.sh` or `apply.sh` classifies that subtree as consumer drift either. **What produced
that row is not established, and a later session should not assume it was this script.** That is
two consecutive consumer reports naming the wrong program, after item 17's.

**A DIFFERENTIAL AGAINST A COPY RUN FROM OUTSIDE `reconcile/` PROVES NOTHING, and the first one
taken here did exactly that.** The script resolves its path mapper from a sibling and emits
nothing without it — so the pre-fix arm came back EMPTY and read like a fix that worked. Re-taken
with the shipped copy placed back inside `reconcile/`, plus a liveness control on it. This is
`CLAUDE.md`'s unmutated-control rule arriving in a differential rather than in a mutant harness.

**And a zsh `:c` history modifier ate a character** in the probe that was supposed to prove the
three blobs were distinct: `"$r:core/..."` printed three distinct ERROR STRINGS and the count
read 3 of 3. Braced, it really is 3. That is the first false-zero source `CLAUDE.md` lists,
landing in the verification of a fixture rather than in the fixture.

## What item 16 measured (the hard part was not the one this plan named)

**THE DEFERRAL'S PREMISE WAS TRUE AND WAS THE WRONG QUESTION, and that is the whole item.** This
plan, the grammar file and the migration script all said the same thing: `story-297-1-slug.md`
reads equally as sprint 297 story 1 and as story INDEX 297, no expression separates them, so the
corpus cannot be judged. Every word of that is correct **about the name**. The grammar places
`stories/` only under `s<N>/`, so a `stories/` directory with no `s<N>/` above it cannot hold a
conforming file whatever the file is called — everything in one predates the grammar, by
construction. **The answer was in the position and three files had written down why it could not
be in the name.** Corroborated before shipping: of the 786 basenames matching `story-<A>-<B>`, all
786 have `A` in the sprint range the tree uses, control being the 73 `story-S<N>-<M>` files where
the sprint is not in doubt.

**THREE FIGURES IN THIS PLAN WERE WRONG:**

- **The corpus is 988 flat files**, not 1001 and not 1024. 1025 is the count under *any* `stories/`
  directory; 25 of those already sat under `s<N>/` (party-mode transcripts and two archives), and
  one is outside the scan roots.
- **781 spell the sprint as a bare leading number**, not 761. There are at least **eleven**
  spellings, not the two the migration's comment named: `S223-1-`, `s289-1-`, `sprint-208-1-`,
  `bug-`, `hotfix-`, `192-ff-A-`, `story-131b-1-`, and five files with no number at all.
- **Two shipped readers restated the corpus literal, not three.** `validate-locked-anchor.sh` is
  not one — the path appears there in a single usage-example COMMENT and is that file's only
  `_bmad-output` reference at all, because it takes the story file as an argument. The real set was
  `validate-mandatory-rules.sh`, `ai-dlc-protect.sh`, `install.sh`, and the schema itself.

**THE FIX'S OWN BLIND SPOT HAD THE SHAPE OF THE DEFECT IT WAS FIXING, and only running it found
that.** Check 6's replacement corpus control, written the obvious way — count stories under the
declared `s*/stories/` — is blind to a tree that has not migrated yet, so an unmigrated consumer
holding 988 story files reported *the corpus is empty* and SKIPped. That is the zero-verification
pass the whole item exists to remove, re-introduced by its own remedy. The control now spans the
whole area, derived by cutting the template at its own placeholder.

**AND I84 FIRED ON ITSELF ON ITS FIRST RUN, twice, which is what the false-positive measurement is
for.** Its reader arm scored `migrate-artifact-paths.sh` as a reader that had forgotten to
substitute — the file MENTIONS `stories_dir` in the comment explaining why it deferred the corpus.
A mention is not a read. And I54 caught the invariant's own `printf | grep -qF` on the same run,
the EPIPE-under-pipefail idiom this repo converted away from in v0.207.0.

**THE TWO PROGRAMS AGREED EXACTLY ON THE REFERENCE CONSUMER**, read-only, 5148 tracked files:
951 moves planned / 951 blocking, 72 ambiguous either way, 3 with no area either way, 23 with no
derivable sprint either way. That is the join the plan asked for, taken on real filenames rather
than on the fixture's seeds.

**Three things a later session should not re-derive:** a `case` glob, never `printf | grep`, for
testing whether a template contains its own placeholder; `IFS`-free `${var//"$pat"/$rep}` works on
bash 3.2 with a quoted pattern (probed); and a fixture that NAMES a path under `core/hooks/ai-dlc-`
enters I10's hook-driving set even when it only mutates the file — `enforcement-map-derivations`
assembles such paths from halves for exactly that reason and the control caught the regression.

## What item 17 measured (the report named the wrong program, and the right check already existed)

**THE DEFECT IS REAL AND WAS REPRODUCED AT GROUND TRUTH**, not synthesised. graph's own pull
commit `188a4b006` shows the hand correction: `deploy-validate.md` line 26 read
`_bmad-output/implementation-artifacts/sprint-<N>-*.md` (OURS, the OLD grammar) where theirs had
`_bmad-output/implementation-artifacts/s<N>/*.md`. The consumer's step file was teaching the
convention item 10 had just replaced.

**TWO THINGS IN THE REPORT WERE WRONG, and a session acting on it literally would have fixed
neither:**

- **`apply.sh` does not implement mask/reinject.** Its two matches for `mask` are both `umask`,
  against fourteen in `SKILL.md`. The transform is PROSE an agent executes. Checked with a
  control, because a zero from a grep is not a finding.
- **The check that catches it already existed and was correct.** §7v criterion 5 states it
  exactly — and §7v is **untangle-only**, so the ordinary pull, which runs the same transform at
  step 7, had no equivalent gate at all. Worse, criterion 5 is prose executed by the agent that
  just performed the transform, and `SKILL.md` itself records it reporting PASS on an instance of
  this defect (`dev.md`, three of theirs' model-option comment lines).

So the fix was neither a code change to `apply.sh` nor a stricter sentence: it was making the
existing rule a program and running it on both paths.

**A DECLARED SPAN NO PROGRAM COULD FIND, and this is the transferable finding.**
`deploy-command`'s `match` is `^(.+)$`; its only locator was `anchor_context` PROSE. The first
implementation resolved it greedily, picked a `{token}` HTML comment ten lines above the real
site, and then reported the correctly-reinjected value line as drift. **A declaration written for
an agent to read is not a declaration a checker can use**, and the checker that cannot find its
subject picks plausibly rather than saying so — the same defect one level in.

**Two silent-field defects, neither of which announces itself:** `IFS=$'\t' read -r a b c`
COLLAPSES RUNS OF TABS (tab is IFS *whitespace*), so a record with empty middle fields shifts
every later field left — here it produced an EMPTY regex, which matches every line; and a
candidate list built with `tr '\n' ' '` carries a TRAILING SPACE, so `"162 "` went into a lookup
that only ever compares `162`.

**ITEM 18 IS STILL OPEN** and is the other half of the same pull's report.

## What v0.305.0 measured (item 10e — and what a gate must NOT block on)

Taken against the reference consumer, read-only, immediately after the migration ran for real.
**The numbers are the release's design, not its decoration:**

```
tracked files under the scan roots            5148
paths the migration would still MOVE             0   <- the blocking set, and it is EMPTY today
REFUSED by the migration                        48   45 ambiguous, 3 with no derivable area
under a stories/ directory                    1024   263 carry a token an expression can see;
                                                     761 spell the sprint as a BARE leading number
```

**Blocking on all 1072 would have wedged first contact**, on a tree whose operator had already
done everything core asked. So the blocking predicate is *the set the migration would move* —
empty on a migrated tree, non-empty the moment a sprint writes `s302-foo.md` at an area root, and
clearable by one command the failure message prints. **No class is exempted by a list**; each is
computed from the path, so nothing can go stale and nothing can be hand-added.

**THE 92 FALSE POSITIVES, and this is the item's transferable finding.** The first working version
resolved the reserved slot against DECLARED areas only. It reported **92 already-conforming paths
as violations** — `_bmad-output/brainstorming/s166/…`, filed exactly right, under an area nobody
had declared — while the migration on the same tree planned ZERO moves. An undeclared area is a
paperwork gap the migration REPORTS; it is not a path defect. **Nothing in reading the code found
this**; the false-positive measurement `CLAUDE.md` requires did, on the first real run.

**Three things a later session should not re-derive:**

- **`migrate-artifact-paths.sh` is far too slow to be a gate.** Minutes on 5148 files (a subshell
  per component); the validator is **0.23s** on the same tree. That is why 10e is a second reader
  and not a wrapper, and why the two are joined by an asserted set equality instead.
- **The story corpus cannot be judged syntactically and the grammar file used to imply it could.**
  761 of 1024 story basenames are `story-297-1-slug.md`, character-for-character the
  `story-<M>-<slug>.md` the grammar prescribes. Item 16 removes the ambiguity by taking the number
  out of the filename; nothing before it can.
- **`SELF_DIR` resolved after a `cd` is a live defect class, not a style note.** The migration
  resolved its own directory after `cd`-ing into the consumer, so `bash core/scripts/migrate-…`
  died at `cd: core/scripts: No such file or directory` while the absolute path the fixture used
  worked. Any core script that gains a sibling dependency inherits this.

## Where things stand

**THIS SECTION IS THE RELEASE TABLE, NOT A STATUS RECORD. The live status is at the top of the
file, under §*Start here*, and it is the only one.** This heading used to open "ai-dlc is at
`0.310.0`, `contract_version` 16" — a second status record that went stale the moment the next
release landed and disagreed with the top of the file by six releases and one contract version.
That is precisely the two-status-records defect `validate-plan-shape.sh` exists for, in the plan
that documents it. **Read the current version from `VERSION`, and the current
`contract_version` from `core/skills/ai-dlc/layer-contract.yaml`; do not carry either here.**
Every release below is merged to `main`:

| release | PR | what it does |
|---|---|---|
| v0.323.0 | #463 | **plan item 23c-4 — item 23 is CLOSED.** `resolve_artifact` takes the anchor and tries the sibling `s<n>/` first when it carries `LR-S<n>-`. Rule 13 makes locked requirements cumulative, so a cross-sprint citation is honest — and **v0.322.0 turned an accident into a defect**: with the block in the sprint slot the walk-up reaches the story's OWN slot and reports `anchor not found`, a true statement about the wrong file. Measured: **260 of 4019** `LR-S<n>-` tokens cross a sprint, **0 of 62** anchored citations did. Nothing widened — a fabricated bullet under a cross-sprint anchor still reds, asserted in the fixture with a mutant and a pairing arm. |
| v0.322.0 | #462 | **plan items 23c-3 + 23c-1, together.** `discovery.md` §4a writes the sprint's `LOCKED_REQUIREMENTS` block to `_bmad-output/planning-artifacts/s<N>/locked-requirements.md` and the brief keeps a pointer; core had PRESCRIBED the accumulation (*"a brief accumulates one block per sprint"*) into an artifact that is 17% durable. The SoR is now a PAIR, because refusing the legacy name would fail **31 of 62** anchored citations, all resolvable — with a removal TEST (the PASS line counts legacy claims) rather than a date, and `prd.md` still refused in the same run. `SPRINT_WHOLE_READ_SET` pools the LIVE slot only, resolved via `sprint-status.sh sprint-id`, so the move cannot grade itself. Owed to the operator: **one** block (S299, 169 lines). |
| v0.321.0 | #461 | **plan item 23c-2.** Rule 15's changelog now goes to `_bmad-output/planning-artifacts/s<N>/changelog-<artifact>.md`, declared ONCE in `_gate-procedures.md` with four convergence lines pointing at it rather than restating the path. Six sites prescribed one; four named a durable target. **Live effect measured at 260 lines** (223 in graph's brief, 37 in `docs/architecture.md`, 0 in `prd.md`) — the "21% of the brief" figure reads larger than the pooled effect and the release says so. **MOVED, never deleted**: nothing in core reads a changelog, which is a reason to home them, not to drop them. New fixture `changelog-sprint-slot`, site set derived not hand-listed, red on the pre-fix tree naming all 6. |
| v0.320.0 | #458 | **plan item 27.** `ai-dlc-update/SKILL.md` told step 7 to PRESERVE `skill_version`/`skill_commit` and step 2 to ADVANCE them with that same apply, 1100 lines apart; `apply.sh` mechanised preserve by never writing the fields — **0 mentions against 2 for the rulebook pair**, and nothing in the whole distribution wrote either. Both instructions are right for different runs, so the branch is a flag the caller passes: `apply.sh --carried-machinery-slice`. **No new invariant — I60 already binds it**, proven by mutating the case arm until it fails by name. Three silent-success paths closed (absent fields inserted in schema order, unreadable VERSION and legacy stamps reported as rows, result read back). New fixture `apply-machinery-stamp` (19 arms, 2 mutants, 1 control), filling a gap measured at **0** skill-field assertions suite-wide. |
| v0.319.0 | #452 | **plan item 23b.** `artifact-consolidation.md` homes all four working files in `_bmad-output/planning-artifacts/s<N>/` and retires its drafts at a new Step 6. The re-home refusal set is **EMPTY — all 33 resolve, 24 with no inference** — and the plan's `S999` premise is refuted. New fixture `consolidation-residue`; no existing check could have caught it, because both the area-root and the slotted path are syntactically conforming. |
| v0.318.0 | #450 | **plan item 23a, second half.** The whole-read sum was overstated 2.35x by a basename sweep counting 26 archived copies. |
| v0.317.0 | #449 | **plan item 23a, first half.** The 417% budget breach was an INSTRUMENT READING: the pool was understated 5x by a resolver reading a role-file line format deleted at v0.174.0. Corrected on both sides, graph's four live artifacts are **36%** of the pool. The floors were derived anyway, because at a genuine 200K window the threshold IS unattainable. |
| v0.316.0 | #445 | **plan item 21.** The resolution driver overwrote ITSELF mid-run: `overwrite_from_theirs()` wrote with `git show > "$cons"` — open+truncate+write, same inode — and `apply.sh` is in the set it writes, on the copy step 7 tells the session to run. **Settled by experiment first**: bash resumes at its saved byte offset inside the new text and **can exit rc=0 having run the replacement's tail**. Reproduced at ground truth, control differing only in where the running copy lived (own copy rc=2 + stamp withheld + tree partial; out-of-tree rc=0 clean). Fixed with the `.incoming.$$` + `mv` idiom already used at five sites; also removes a truncate-before-fetch that left an EMPTY core file on a failed `git show`. New `driver-self-update` row. **One fixture arm was DELETED for being vacuous** after a mutant survived it. |
| v0.315.0 | #440 | A fixture in `install.sh`'s ship list resolved its SOURCES only in the distribution, so it exited 2 on **every** consumer before an assertion ran, on a file byte-identical to upstream. Reported by the consumer and **reproduced here with a control**. Class sweep: 8 further text-suspects, **all 8 pass when RUN in a consumer-shaped tree**, so the obvious lint (FP set 8 of 8) was deliberately NOT shipped. |
| v0.314.0 | #437 | **plan item 6.** LC-E6 and LC-O15 promoted to `ADJUDICATED`; `contract_version` 16 → 17. Cost measured on graph: `HARD-LAYER-ADJUDICATION-MISSING` 12 → 13. Promoting them **broke a hand-list in three files** — LC-O15 is not range-keyed, so "a degenerate range disarms every adjudicated arm" stopped being true; all three now derive via `--adjudicated-codes`. |
| v0.313.0 | #436 | LC-E6's `fixture: none` was honest and left the clause with **no demonstrated firing case anywhere**, so its 0 was a silence. New fixture `layer-absorption-retire` fires it on both emit sites, with the LC-E5 control that separates "core absorbed it" from "you duplicate core" on the one bit that differs. |
| v0.312.0 | #435 | The supersession join compared the WHOLE `shadows:` string, so a multi-anchor override could never match a declaration naming one anchor — the blind spot **was** the population the clause exists for. One live miss on graph. `--stamp retire` deletes the whole file, so a multi-anchor hit now carries `retire_anchor=` and prescribes narrowing. |
| v0.311.0 | #434 | `apply.sh`'s `say()` printed THREE fields while EIGHTEEN call sites passed four, so **every WORKLIST/DECISION detail was discarded**; and `printf '%s' \| while read` dropped its last element, so a one-key ATOMIC sequence emitted only `2/2 --stamp retire` while numbering a `1/2` that never existed. Found by DRIVING it while measuring item 6. New fixture `apply-worklist-rows`. |
| v0.275.0 | #361 | **enablers.** Unnumbered headings now join (`EXTENSION-TITLE-MATCHES-CORE`, LC-E19, WARN) — 27 of graph's 38 entries were previously invisible. Env-keyless `override_supersessions:` can fire, so "core adopted your prose" is declarable. |
| v0.276.0 | #362 | absorbs Check 7 non-vacuity, carry-over item-5 sprint boundary, `dev.md` conditional local-launch → **3 overrides retirable** |
| v0.277.0 | #363 | absorbs qa gate-2 go-signal, code-reviewer context-*shape* severity, pm probabilistic-AC + numeric anchor → **2 extensions retirable** |
| v0.278.0 | #364 | `ai-dlc-update <ref>` / `<ref> apply` target-ref argument, plus `self-update-gate.sh --safe-stop` and a `SELF-UPDATE-SAFE-STOP` row on every DEFER |
| v0.279.0 | #365 | plans that must survive a session live in `docs/plans/`; `scripts/validate-plan-shape.sh` enforces a resumable shape and pre-push runs it. **This file is its first subject.** |
| v0.280.0 | #367 | Check 3b resolves the `requires_context:` load pointer, scopes the byte-match to the cited anchor, and stops spelling a zero-verification PASS like a verified one. Discharges all three OPEN `PC-S297-LOCKED-ANCHOR-*` candidates. |
| v0.281.0 | #369 | `validate-artifact-budget.sh --fail-on <artifact>` plus a supersession-marker arm. Retires `steps__retro__pipeline-snapshot-ceiling` as a CONFIGURED supersession (`AI_DLC_SNAPSHOT_STRIKETHROUGH`). |
| v0.282.0 | #370 | `AI_DLC_AUTO_HANDOFF_MODE` + `AI_DLC_AUTO_HANDOFF_SEAMS_EXCLUDED`, and the `settings_env_keys:` multi-key supersession mechanism. Retires `SKILL__auto_handoff_mode`. |
| v0.283.0 | #373 | **plan item 0.** Inner pools for six internally-serial fixtures; `enforcement-map-sites` sharded into three directories. Suite makespan **268s → 238s**. Output byte-identical, 21 driver mutants green. |
| v0.284.0 | #374 | `validate-enforcement-map.sh` spawn reduction: 1582 → 1156 external commands, **8.36s → 7.02s**. Suite makespan **238s → 214s**. Byte-identical on the failing paths as well as the passing one. |
| v0.285.0 | #377 | **plan item 2b.** Core **Rule 31** — a countable assertion carries the derivation that produced it. Absorbs the consumer's Rule 930 count discipline, which core had nowhere. The enforcer was built, measured and NOT shipped; `**Carrier:** none` is a declared I79 gap (5 → 6). |
| v0.286.0 | #381 | **plan item 3.** The live adversarial series is derived by filtering INSIDE the pick, so a filename that defeats the pass-suffix strip can no longer become a one-pass series the stall guard reports as `CONTINUE`. `I81` binds the expression across both hooks and asserts it is the filtering form. |
| v0.287.0 | #383 | **plan item 7, first two findings.** `validate-mandatory-rules.sh` reports a skipped check as skipped (`PASS WITH SKIPS`, named numbers, verified floor) instead of folding three SKIPs into `all 6 checks passed`; `validate-spawn-ledger.sh` gets an `OK WITH NO PIN COMPARED` verdict so it stops asserting a pin it never fetched. New fixture `mandatory-rules-skip-accounting` (6 arms, 6 mutants); `check-22-spawn-ledger` 13 → 16 assertions. |
| v0.288.0 | #388 | **plan item 11.** The self-update gate probes each gating script BARE; three of five exit 2 (usage error) that way, so the differential compared two usage errors, landed on `UNDECIDED` and deferred every machinery pull touching them. Agreement AT 2 is now its own `OK` arm, scoped so BOTH sides must be 2. |
| v0.289.0 | #392 | Three snapshot fixtures inherited ambient `AI_DLC_*` from a consumer's `settings.json` and tested the CONFIG, not the CODE. 33 siblings already carried the guard. Reported by the consumer while retiring `steps__retro__pipeline-snapshot-ceiling`. |
| v0.290.0 | #393 | `EXTENSION-TITLE-MATCHES-CORE` told the operator to declare `extends:` and promised the row would stop firing, ten lines under the block that deliberately removed that suppression. Remedy text corrected. |
| v0.291.0 | #395 | …and v0.290.0's correction was itself inert: the code is not in `ADJ_CODES`, so no `subject_digest` was published and **no conforming record could be written at all**. The row is now keyed; a recorded verdict silences it until entry or core section moves. Level stays `WARN`. |
| v0.292.0 | #396 | v0.291.0's fixture seed resolved only the distribution layout (I33), so on a consumer it died in its seed and blocked the pull. Fixed via the two-layout `pick` helper the same file already defined. |
| v0.293.0 | #400 | a plan must tell its executor to ping; `validate-plan-shape.sh` enforces it. **This file is its first subject.** |
| v0.294.0 | #402 | **plan item 14.** The suite runs only the fixtures a change can affect, keyed on trace-derived read-sets. 118 fixtures, 40 bound in the enforcement map, **78 named nowhere** — a declaration-based skip would have missed **~8000 paths**. Everything that cannot justify a skip runs everything. Wall clock **42%**, not the 76% of work removed: the suite is pole-bound. |
| v0.310.0 | #432 | **plan item 8, core's half.** The re-verify over graph's 56-entry ledger produced exactly ONE `CLOSE-CANDIDATE` and it was FALSE: the receipt named `docs/retro/sprint-249.md`, which the artifact-path migration moved, so its `&&` chain short-circuited on a missing file and read as a fix. By hand at the path that exists now: relative rc=0, absolute rc=1 — the defect reproduces as filed. The guard for this case existed as a NOTE in the close's own detail text, telling the operator to check the paths themselves. Now a program, and one that can only DOWNGRADE a close, never create one — which answers the false-confidence objection the code had recorded against path-parsing. False positives: exactly one row moved, the one proved false by hand. 67 → 69 assertions. |
| v0.309.0 | #430 | **plan item 18.** The consumer's stamp carries TWO advancing shas and the drift scan only ever read one: step 2's autonomous self-update rewrites the whole MACHINERY set and advances `skill_commit`, so on a multi-hop pull those files sit at an INTERMEDIATE ref while `commit` — what every predicate measures against — stays put. Reproduced on this repo's own history: the same file at the intermediate ref gives `HARD-CORE-DRIFT-ABSORBED`, whose remedy is a REVERT of upstream's own content; at base it gives `CORE-OK`. **28 files** in both the machinery set and the scan (control: 72 outside). New non-blocking `CORE-AT-SELF-UPDATE`, with the ref READ FROM THE STAMP rather than passed in — a fifth argument is a fifth thing a caller can omit. `apply-drift-after-write` 11 → 15 assertions. |
| v0.308.0 | #428 | **plan item 16, second half.** The story corpus migrates. The deferral rested on a TRUE sentence about the NAME and never asked about the POSITION: the grammar places `stories/` only under `s<N>/`, so a `stories/` directory without one predates the grammar and its leading number IS the sprint. A legacy basename is normalised to the explicit `s<N>` spelling and then handled by the SAME transform as every other artifact, rather than by a second one that could drift invisibly. Corroborated first: 786 of 786 leading numbers inside the tree's sprint range, control the 73 explicit-token files. `STORY-NO-SPRINT` replaces `DEFERRED-STORIES` — per FILE, cleared by a rename. **The migration and the pre-push validator agreed EXACTLY on 5148 real files: 951/951 blocking, 72/72, 3/3, 23/23.** |
| v0.307.0 | #427 | **plan item 16, first half.** `stories_dir` becomes a TEMPLATE the schema owns, carrying the sprint slot; **I84** forbids a second copy and requires every reader to substitute it. The literal had FOUR copies and three would have failed SILENTLY — a protected-path pattern that matches nothing ALLOWS, a story glob that matches nothing prints PASS. Check 6's name-keyed glob is replaced by the sprint's own DIRECTORY, so the 298/299 capital-S defect cannot recur. The story-id join is re-derived: the DECLARED sprint is stripped from the entry key to give the index. **The replacement corpus control was itself blind to an unmigrated tree and reported 988 files as an empty corpus — caught by running it, not by reading it.** New fixture (10 assertions, 5 mutants, 1 control). |
| v0.306.0 | #425 | **plan item 17.** `reconcile/setup-site-drift.sh` — §7v criterion 5 as a program, on BOTH the ordinary pull's post-write gate (which had nothing) and untangle's §7v (which had prose the transform's own author checks on themselves, already green on one instance of this defect). Reproduced at ground truth: silent on the corrected consumer, `deploy-validate.md:26` on the reconstructed one. **`apply.sh` was NOT the subject** — its two `mask` matches are both `umask`. `deploy-command`'s span had no machine-readable locator and now carries `after_line`; a site that cannot be pinned to one line FAILS rather than being guessed at. New fixture (15 assertions, 3 mutants, 1 control). |
| v0.305.0 | #423 | **plan item 10e.** `validate-artifact-paths.sh` on the consumer pre-push — real filenames, every push, because a migration is an event and a convention with only one behind it has a half-life. Blocks on exactly the set the migration would move (**0** on graph); reports the **48** refusals and **1024** deferred stories with computed, never listed, reasons. Both sides of that join asserted EQUAL. **92 false positives** caught by measurement before shipping. `artifact-path-config.sh` becomes the ONE reader of the grammar's blocks and **I83** forbids a second, false-positive set measured at zero. Self-probes each run; an empty subject is `NOT-APPLICABLE`, never PASS. New fixture (37 assertions, 4 mutants, 1 control). |
| v0.304.0 | #421 | **from the migration running for real.** The `AREAS INFERRED` remedy named CORE's grammar — a file a pull overwrites, and the wrong home by that file's own rule — and a consumer session followed it literally, proposing core absorb nine consumer-specific areas. Fixing the wording alone would have been WORSE: the consumer's `artifact-paths.md` was byte-identical to the scaffolded template and **nothing read it**, so declaring the areas would have changed no later verdict. The consumer's areas are now READ and joined to core's eight, path resolved from the contract, one `areas_of()` for both files. **Nine, not eight** — the real run also found `_bmad-output/research`, one file, the smallest. 32 → 37 assertions. |
| v0.303.0 | #418 | **plan item 13.** Step 7 told the operator to re-run BOTH drift scripts with `theirs` as the base; that is right for `unregistered-drift.sh` and disarms `layer-drift.sh`, whose two ADJUDICATED clauses are computed over `base..theirs`, so `HARD-LAYER-ADJUDICATION-MISSING` cannot be demanded and `hard-blockers.sh` prints a clean sheet on a tree where every verdict is owed. Reproduced on a scratch consumer with both arms and a control. The instruction is split per script AND `DRIFT-RANGE-DEGENERATE` makes the wrong invocation self-announcing. Resolved commit ids, not argument strings — theirs is a ref and base a sha in every real call. |
| v0.302.0 | #416 | **plan item 8c, second half.** `RECEIPTS-UNDECIDED` — one row per run counting the `theirs_has` receipts whose substring is present at BASE as well as theirs, so this pull moved neither side of them and their STILL-LIVE is a restatement rather than a measurement. **24 of 24** on graph. A COUNT, not a verdict: the stronger predicate was built, fires on **15 of 23** including entries confirmed live, and is REFUTED rather than shipped. Silent at zero. Two defects the fixtures caught and review did not — the loop ran in a subshell so the counter was discarded, and the row's entry column was the ledger path, which made a verdict depend on how the ledger was addressed. 61 → 67 assertions. |
| v0.301.0 | #415 | **plan item 8c, first half.** The consumer root is normalized, because `.` inverts any receipt whose own claim is about absolute paths — measured, 74/74 rows either way with exactly ONE differing, a FALSE CLOSE. And `INPUT-UNRESOLVED`: the unconditional `[ -f "$LEDGER" ] || exit 0` spelled a caller error exactly like a clean corpus (bogus arg 5 and swapped args both gave 0 rows, rc=0, zero bytes of stderr, against 74). Two arms, because an arg-5-only check cannot see the swapped-args case. The fixture had been ASSERTING the defect. 54 → 61 assertions. |
| v0.300.0 | #412 | **plan item 10d.** `migrate-artifact-paths.sh`: dry run by default, `git mv` only, verified per file as source-absent AND dest-readable AND sha256-identical. Rehearsed on a CLONE of the consumer and the rehearsal found four defects reading could not — a component regex run against whole paths (668 detected instead of 2551, `docs/retro` absent entirely), adjacent tokens hiding each other (a two-sprint file planned as unambiguous), the slot nested inside the token it replaces (53 directories), and a half-migrated story corpus. 2667 moves / 48 refused / 1001 deferred / self-check 0 / idempotent. Every refusal and every inferred area is reported. New fixture `artifact-path-migration` (32 assertions, 3 mutants, 1 control). |
| v0.299.0 | #411 | **plan item 10c, with item 7's F4 folded in.** Readers compose the path from the declared sprint instead of searching it; core's 24 excused prescriptions are rewritten and the migration ledger is **EMPTY**, with both I82 arms re-proven by guarded mutant because an empty join reads like a dead one. Both hooks scope the live-series glob to `s<sprint-id>/` — 135 files across 56 sprints down to one sprint's candidate set — and I81 now binds the whole derivation as a marked BLOCK asserting two properties. Check 6's zero-verification PASS is closed with the corpus count as its control. F4: `validate-ci-gates.sh` reports its inventory on a vacuum and adjudicates via the alias table with no CI directory at all. `I82` added to the `OK:` line. |
| v0.298.0 | #408 | **plan item 10a + 10b.** `artifact-path-grammar.md` declares one convention — the directory is the only sprint slot — and `validate-enforcement-map.sh` **I82** binds core's own prescriptions to it. Measured first: **65 prescribed paths, 41 conforming, 24 carrying a sprint token outside the reserved slot**, in 4 positions and 5 spellings. The 24 are a migration ledger bound in BOTH directions, so it can only shrink. `contract_version` does NOT move; the precedent was measured. No path moves. |
| v0.297.0 | #407 | The self-update gate stops reading AGREEMENT as an unattributable failure. Found by the 10a+10b push: a machinery-only pull touching `audit-rule-files.sh` deferred, because bare it defaults to `--fail-on=any` while the hook passes `--fail-on=deterministic` — it fails a threshold the hook never applies, identically on both sides. v0.288.0's fix, one layer up, scoped to `2` alone. Re-measured over **seven** scripts, not five. |
| v0.296.0 | #405 | **plan item 15.** `core/hooks/ai-dlc-notify.sh` on the `Notification` event — the mechanism behind the plan-shape rule's ping requirement. Platforms decided rather than left open: macOS `osascript`, Linux `notify-send`, anything else no channel, and `install.sh` PROBES and REPORTS which, so the no-channel case is not the inert-mechanism class. New fixture `notify-hook-channel` (9 assertions, 4 mutants, 1 control) shims `$PATH` so the Linux and no-channel branches are driven by the shipping code on a macOS suite. |
| v0.295.0 | #403 | `--list` MERGES instead of rewriting the map. v0.294.0's version dropped every untraced fixture — SAFE (unmapped means always-run) and therefore invisible: the suite stayed correct and merely stopped skipping. Verified on the real map, 118 preserved + 1 added. |

**Two absorptions did NOT come up wholesale, and both refusals are worth carrying forward.**
A consumer override is evidence that a consumer needed something; it is not evidence that core
is wrong. In v0.281.0 the override's bare-`~~strikethrough~~` arm turned `inflight-row-shape`
red — a fixture that already held a struck line outside the dispatch ledger is out of scope,
because Recent Activity legitimately strikes superseded entries. Core's position predated the
work and had a fixture behind it, so it won by default and the stricter posture became a key.
That is the better outcome anyway: it turns an adopted retirement into a CONFIGURED one, which
is the shape the whole mechanism was built for. **Run the absorbing change against the full
fixture suite before believing the absorption is clean** — the conflict surfaced as a
red fixture, not as anything visible while reading the override.

**THE PULL IS DONE.** graph is at **`0.292.0 / c5e7daa`**, all four stamp fields, taken as the
two-hop split this plan prescribed (hop 1 `SELF-UPDATE-OK`, hop 2 the rulebook) plus three
single hops as later releases landed. 25 HARD blockers in and 0 out; 5 overrides retired, 1
readopted clean, 18 adjudications recorded. Layer debt OPEN 2 → 0. The `EXTENSION-TITLE-MATCHES-CORE`
queue is at **zero with a control proving the zero is real**. Two obligations are now enumerable
rather than buried in prose — `OWED-DEVPUSH-RESTATES-CORE` and `OWED-STS-DOMAIN-AB-ABSORBED` —
and **neither gates anything**.

## What v0.280.0 measured, and the five defect classes it names

Recorded here because item 7 above audits the unreached steps against exactly these, and
because the numbers are the reason the release was worth cutting.

Against graph's whole story corpus, with the SHIPPING script, before any edit:

```
998 story files
  PASS, 0 claims verified   196     <- including 10 of 10 in the LIVE sprint
  PASS, >=1 claim verified    0     <- never once, in the entire corpus
  FAIL                      802
```

Every s301 block cited only `requires_context:`, which the script recognised as a presence and
never resolved. The sprint's adversary hand-verified citations across eight passes because
nothing mechanical did. **34 of 47 pointers in the corpus named an anchor absent from the
artifact they cite.** The change moves 992 of 998 verdicts not at all; all six that move are
dangling anchors confirmed with a same-file control returning non-zero.

The classes, each measured rather than hypothesised:

1. **Zero-verification PASS** — success has two roads, "everything verified" and "nothing to
   check", sharing one exit code AND one report line.
2. **A check that cannot fire** — an extractor that silently matches nothing.
   `core/scripts/validate-ac-falsifiability.sh:244` extracts `prior_evidence:` citations
   line-initial only, so a mid-sentence one is invisible.
3. **Co-presence mistaken for anchoring** — a match scoped wider than the claim, succeeding on
   text the claim does not name.
4. **A count with no control** — a bare `grep -c` whose zero is indistinguishable from a
   pattern that cannot match, whose false number becomes an AC. This is item 2b.
5. **Entangled or cross-product assertions** — the bullet loop sat inside the citation loop,
   demanding every bullet be present at every anchor.

**One arm of the original plan was REFUTED by measurement and must not be rebuilt.** The plan's
§*Findings* attributes the eight-pass cost to `validate-locked-anchor.sh` on the strength of
p3's `MAJ-p3-2`. That finding actually names class 2 in a *different* script,
`validate-ac-falsifiability.sh`, and the defect it reports **is already repaired in graph's
tree**. Building the obvious fix — disarm on a `prior_evidence:` token that is not line-initial
— was measured against the live sprint first: **8 occurrences, 8 of them false positives**, all
prose quoting the token inside repair-history sections. It was not built. Class 2 is real and
belongs in the item-7 audit; that particular enforcer is not the way to catch it.

## What v0.285.0 measured about the count-assertion class (CORRECTS item 2b's stated mechanism)

Item 2b said the defect was "a bare `grep -c` yields a false number that becomes an AC". The
target case was right and the mechanism was wrong, in a way that would have aimed an enforcer at
nothing. Recorded here so item 7's audit does not inherit the wrong shape.

**The absorption premise HELD.** Core's shipped `SKILL.md` before the edit carried **0**
statements of the discipline, with two controls in the same read: 30 rule headings, and 29
mentions of `grep`/`count`. It discusses counting constantly and never says to control one.

**Core was not silent, and where it spoke is the point.** `steps/gate-validation.md` Check 12
already requires an absence claim to carry its control. That clause is scoped to **gate log
evidence rows**, and `gate-validation.md` is sliced-loaded under Rule 21, so it is in context
only while a gate is being logged. Story work never loads it, and story work is where the
defects are authored. A rule can be present in core and still absent everywhere it is needed.

**The three real findings, and not one is a miscounted grep.** Across three consecutive
adversarial passes in the live sprint:

| finding | what it actually was |
|---|---|
| `MAJ-p4-1` | a scope exclusion asserted about a sibling story the sibling does not contain — not a count at all |
| `MAJ-p5-1` | an AC asserting "five of the thirteen call sites" where the derived count is thirteen |
| `MAJ-p6-1` | a cited range called "full prose" that the citation does not test |

`MAJ-p5-1`'s "five" corresponded to nothing derivable — authored with no command behind it. All
three survived four adversarial passes and two mechanical enforcers, and the consumer's own retro
synthesis names one shared cause: they sit in **prose asserting facts outside the criterion's own
test**, which passes and enforcers alike read least.

**The four sites this plan cited as evidence do not say what it read them as saying.** Re-read,
**three of the four are the discipline WORKING** — a `ZZQQ` control that correctly returned zero,
a label grep deliberately not trusted, a control labelled as such. Only
`s301-stories-adversarial-p2.md:327` (a grep scoped to the wrong file) is an escape. Graph's Rule
930 is effective; the gap was that core lacked it, not that graph's rule was failing.

**The enforcer was built and measured, and is why the carrier is `none`.** A block-grain detector
— a cardinal applied to a plural noun with no command and no `path:line` in the same block:

```
positive control   reconstructed MAJ-p5-1 defect (cmp -s guarded mutant)   1 flag, correct block
negative control   the same file, repaired                                 0 flags
false positives    whole story corpus                    6074 flags / 890 of 998 files
                   live sprint only                        13 flags /   5 of  10 files
```

The live-sprint flags are prescriptive counts ("a test driving two new mints at different
blocks") and in-block enumerations — requirements that derive nothing. **The disqualifying
property is the shape, not the volume:** the detector goes silent whenever the block carries any
unrelated citation, and `MAJ-p6-1`'s block carries three. It is blind to two of the three real
findings, and clears on the third as soon as an author adds a citation without making the
sentence truer. **Do not rebuild it.** If a mechanical enforcer is attempted again, the only
shapes not already refuted are count-versus-enumeration arity and cross-artifact number
agreement — both narrower than the rule, neither catching `MAJ-p5-1`.

## What item 3's measurement found (REFUTES item 3 as written)

Measured 2026-08-07, read-only against the consumer. Every arm carries a control.

**The mechanism already exists and is already wired mid-cycle.** `--cycle-state` is a documented
mode of `validate-adversarial-convergence.sh` that "adjudicates an IN-PROGRESS cycle for the
hooks". Both `core/hooks/ai-dlc-continue.sh` (Stop) and `core/hooks/ai-dlc-acknowledge.sh`
(PreToolUse) call it, and `enforcement-map.yaml:420` states the posture: **runtime DENY of
Agent/Task/Skill/TaskCreate on `--cycle-state` exit 3**. The gate-only arms (D, H) are excluded
from that mode by construction, so it is safe on an in-flight cycle — a synthetic healthy series
returns `CONVERGED` rc=0 where the full gate run returns `H -- REPAIR-RECORD` failures.

**It fires on a partial, unterminated series.** A synthetic three-pass plateau with no terminal
verdict returns `STALLED` rc=3; the control — same length, MAJOR strictly decreasing — returns
`CONVERGED` rc=0.

**Replaying the hook's OWN derivation on s301's real files at p6/p7 returns `STALLED` rc=3.** The
glob, the mtime pick and the `sed -E 's/(pass|p)[0-9]+\.md$//'` prefix strip all resolve
correctly against `s301-stories-adversarial-p*.md`. The consumer's installed validator is
**byte-identical** to core's (`cmp -s`) and returns the same verdict, so this is not a version
skew.

**And it did fire, in the live sprint, mid-cycle.** From the consumer's own
`_bmad-output/pipeline-continuation-log.md`:

```
2026-08-06T12:54:10Z -- ADVERSARIAL_STOP
- DIVERGENT at s301-stories-adversarial-p2.md; pipeline paused (Rule 8)
2026-08-06T17:17:12Z -- ADVERSARIAL_STOP
- STALLED at s301-stories-adversarial-p6.md; pipeline paused (Rule 8)
```

Control that the reader can see other record types on the same day: 202 entries dated
2026-08-06, of which 99 `ALLOWED_BY_LIVE_BEAT`, 47 `PAUSE_SKIPPED`, 26 `ALLOWED_BY_PAUSE`, 20
`USER_PAUSE`, 6 `ACK_DENIED`, 2 `BLOCKED`. Control that the DENY path is not dead: s299's
archived log carries 8 `ADVERSARIAL_STOP_DENIED` records, each naming the Agent tool it refused.

**So the defect is NOT reachability. It is that the pause did not hold.** 54 seconds after each
`ADVERSARIAL_STOP` the same log records `ALLOWED_BY_PAUSE -- Pause flag present; stop allowed`,
and the cycle ran on to p8. The rung spoke, paused the pipeline, and the cycle continued anyway.
Zero `ADVERSARIAL_STOP_DENIED` on 2026-08-06, against 8 in s299 — the Stop hook adjudicated but
the PreToolUse deny never refused a dispatch.

**RESOLVED without the transcript, and the answer clears three suspects and names two real
defects.**

*Cleared.* `ALLOWED_BY_PAUSE` following `ADVERSARIAL_STOP` is not a bypass — it is the SAME
event. `ai-dlc-continue.sh:315` raises the pause flag as the way it stops the pipeline, and the
pause branch at `:379` then allows the session to stop. The PreToolUse deny in
`ai-dlc-acknowledge.sh:200` has **no carve-out** and says so in its own message: *"Clearing the
pause flag does NOT lift this."* And the 7 role spawns recorded after 17:17 (adversary,
remediator, tea, general-purpose, against 37 before it) were **correctly allowed** — `p8` stamped
`EXIT_CONDITION_MET` at 15:02, so `--cycle-state` returned `CONVERGED` rc=0 by then. Nothing in
the deny path is broken.

*The real defects, both in how the hooks answer "which cycle is live".* Both hooks pick the live
series by **mtime across every adversarial series in one never-pruned directory**, then derive
the prefix with `sed -E 's/(pass|p)[0-9]+\.md$//'`.

```
files matching the hook's glob *adversarial*p*.md      135
distinct series they span (s288 -> s301)                56
filenames the prefix strip FAILS to strip                6
control: the strip on a well-formed name               s301-stories-adversarial-p6.md -> s301-stories-adversarial-
```

1. **The strip is defeated by 6 real filenames** — `s289-adversarial-pass1-discovery.md`,
   `prd-adversarial-sprint-150.md` and four siblings. For those the "series" is one whole
   filename matching exactly one file, and a one-pass series can never be STALLED or DIVERGENT.
   The guard then evaluates nothing and allows the dispatch. **A check that cannot fire, in the
   class `CLAUDE.md` names as this repo's recurring one.**
2. **mtime spans 14 sprints.** Any touch on any of the 135 files — an archive sweep, a reformat,
   a repair — moves the live-series pick to an unrelated, long-converged series, and the stall
   guard silently adjudicates the wrong cycle. The blast radius grows with every sprint because
   nothing prunes that directory.

**This is the shippable core release, and it is NOT what item 3 asked for.** The rung does not
need to be made audible; the series resolution underneath it needs to stop being answerable by
mtime and a regex. Suggested shape: derive the live series from the sprint's own declared
identity rather than from the filesystem, fail CLOSED (or say so) when the prefix strip is a
no-op, and carry a same-run control that the reader can still see a multi-pass series. Measure
the false-positive set on all 135 files before shipping.

## What v0.287.0 measured (plan item 7, first two findings)

Two things a later session must not re-derive, and one it must not repeat.

**The parked branch's own fix was broken, and the fixture is what found it.** Its skip counter
was `printf … | sort -u | grep -c . || echo 0`. On the empty (zero-skip) input `grep -c` prints
`0` **and exits 1**, so `||` appended a second `0`; `[ -eq 0 ]` died with `integer expression
expected`, fell through to the skip branch on a tree where nothing had skipped, and
`$((6 - SKIPPED_UNIQUE))` then hit a multi-line operand — which bash treats as a **fatal**
arithmetic syntax error, aborting the shell mid-summary with no verdict line and **rc=1**.
`retro.md` Step 5c reads this script on its exit code alone, so the fix for a summary that could
not tell a skip from a pass would have hard-failed every retro that skipped nothing. **The
branch was pushed and gate-green in that state** — the pre-push suite had nothing that ran this
validator on a tree where all six checks execute, because none existed until this release.
That is the general lesson: *a finished script edit with no fixture is not a finished change,
and "gate-green" measures the fixtures that exist.*

**Two mutants had to be re-aimed, and both re-aimings are the recorded trap.** The first
`zeroskipbug` expectation asserted a wrong summary string; the real behaviour is no summary at
all plus rc=1, so a mutant asserted only on missing wording would have scored the abort as a
kill for the wrong reason. Assert the positive outcome, not the absence of the old one.

**Fixture shape, for the next one.** `mandatory-rules-skip-accounting` drives six arms over one
git-backed project tree — zero skips, each of checks 2/4/5 skipping alone, all three at once,
and a skip alongside a real failure — and each mutant lives in **its own toolchain directory**
(the script resolves siblings from `dirname $0`, so a shared mutant dir cannot express a
per-arm sibling toggle). One summary line serves several arms, so a per-check counter mutant
legitimately moves two of them; each mutant therefore declares its **exact moved-set**, and no
two mutants share one. That is the anti-vacuity property when strict one-arm isolation is not
available.

## What v0.288.0 measured (item 7's F3 — one half refuted, one half confirmed)

**REFUTED, and the refutation is the reusable part.** F3 read "an all-`PENDING` anchors file
returns `entries PASS` rc=0" as a defect. It is the documented design, stated in three places
that all agree: the schema's own prose (`sha` is "a PENDING placeholder until merged", and a
stricter pattern here would be wrong because the fail-closed belongs to `--prior-sprint-sha`),
`retro.md` Step 5c (*"No SHA for the prior sprint = audit-gate fails closed at the next
sprint's per-class test-debt audit (Check 18)"*), and gate-validation Check 18 itself, which
runs `--prior-sprint-sha` and names *"a `sha` still on its PENDING placeholder"* as one of four
fail-closed causes. `check5-anchor-base`'s `placeholder` mutant already locks that arm. **That
is three of six item premises in this plan now refuted by re-measurement** (2b's mechanism, 3's
premise, F3's lower half). The instruction at the top of this file has paid for itself again.

**CONFIRMED — a schema that asserts nothing passes every entry and calls it validated.** The
entry loop is `for name, spec in fields.items()`; the guard was `assert isinstance(fields, dict)`,
which `{}` satisfies. Same file, two schemas:

```
entry: `sprint: forty-two`, no `sha`
  shipped schema   FAIL rc=1
  fields = {}      PASS rc=0   "entries PASS — 1 entry validated"
```

Reachable without editing a core-guarded file — the schema path is `AI_DLC_AUDIT_ANCHORS_SCHEMA`.
Fixed by refusing an empty `fields` by name, and by reporting the unit the claim is made in:
`1 entry validated … (4 field comparisons against 4 declared fields)`. The entry count was
always how much was READ.

**The first measurement of this established nothing, and the fixture now carries the trap.** Its
"bad" entry was `sha: %%NOT-A-SHA%%`, which the shipped schema **accepts** — no whitespace, so
`^\S+$` matches. Both runs passed, the control AGREED with the subject, and agreement proves
nothing. Assertion 7 is that control, rebuilt from an entry the shipped schema genuinely
rejects; without it assertions 8 and 9 are unfalsifiable.

## What v0.296.0 shipped (item 15 — the two decisions the scope left open)

The scope was accurate: no new machinery, and the I44 objection was already refuted before the
work started. Two things it deliberately left for the release to decide, and both are recorded
here so they are not re-litigated.

**1. NON-macOS IS A PLATFORM BRANCH PLUS A PROBE, NOT A NO-OP.** macOS takes `osascript`, Linux
takes `notify-send`, and anything else has no channel and exits 0. The branch alone would still
have been the inert-mechanism class on a platform with no channel — the hook's stderr at
notification time is not somewhere an operator looks. So the resolution is REPORTABLE:
`--probe` prints `channel=` and `platform=`, and `scripts/install.sh` runs it and prints the
answer in the install output. Measured on a fresh install into an empty tree:

```
  hooks installed
  input-needed notifier: desktop channel = osascript (Darwin)
```

The report is a PROBE of the hook that will run later, not a claim about it, so a platform
branch that stops resolving cannot keep reporting that it does. `resolve_channel()` is one
function for the same reason: a probe and a notification path that each resolved separately
could disagree.

**2. THE $PATH SEAM IS WHAT MAKES THE OTHER BRANCHES TESTABLE, and it is the fixture's whole
design.** The suite runs on macOS, so the Linux branch and the no-channel branch would have
shipped unexercised and an operator on Linux would have been the first to run them — a check
that cannot fire, aimed at the branch rather than the assertion. `notify-hook-channel` shims
`uname`, `osascript` and `notify-send` onto `$PATH`, which drives the SHIPPING code rather than
a test-only env var, and the shims RECORD instead of notifying (a fixture that popped a real
desktop notification on every push gets turned off).

**The injection arm needed a second half, and the second is the one that holds.** Asserting
that the hostile body is absent from the AppleScript text is satisfied by an implementation that
escapes only quotes. The arm therefore also asserts the script text is **byte-identical across
two different payloads** — no part of the body is derived from the message at all. The
`interpolate` mutant moves that half alone, because argv still carries the message.

**One mutant moves two arms, declared.** `none-to-osascript` mutates `resolve_channel()`'s
fallback, so it moves both the no-channel arm and the probe arm. That is unavoidable given
decision 1 above, and it is declared rather than hidden: each mutant states its exact moved-set
and no two share one.

**The `install.sh` join is DISTRIBUTION-ONLY and says so.** `scripts/install.sh` does not ship,
so on a consumer that assertion prints `skip` with its reason and the verdict reads
`PASS WITH 1 SKIP(S)` — v0.287.0's lesson applied at the point it would otherwise have passed
quietly. Verified by running the fixture in a tree built by `scripts/install.sh` into an empty
directory, not only in `core/`.

## What v0.298.0 shipped (item 10a + 10b)

**The premise was re-measured before any code, and it HELD** — unlike three earlier items in this
plan. Against core's own shipped rule files, before any edit:

```
artifact paths core prescribes                         65
  conforming                                           41
  sprint token outside the reserved slot                24   <- 4 positions, 5 spellings
```

Two corrections to the scope's own numbers, both from a wider and better-derived corpus (every step
file, every skill-root rule file except the grammar itself, every role file):

- The scope listed 21 step files and five spellings. The five hold. The count of PATHS was never
  stated and is 65, of which 24 violate.
- The scope did not list `_bmad-output/specs/spec-s<N>-<slug>/`, `_bmad-output/party-mode-transcripts/sprint-<N>-retro.md`
  or `_bmad-output/implementation-artifacts/sprint-<N>-*.md`. All three are in the ledger.

**`contract_version` does NOT move, and the scope said it would.** The scope's *"`contract_version`
bumps here"* was checked rather than followed: no LC- clause governs the kind set — it is DATA a
rule reads, exactly as the PR-class taxonomy is — and the precedent was measured, not assumed.
`consumer_story_fields_file:` was introduced in v0.237.0 (#321) and **that commit changed no
`contract_version` line**.

**The key is named `consumer_artifact_paths_file:` as the scope said, but the CORE grammar file is
`artifact-path-grammar.md`, not `artifact-paths.md`.** Two distinct basenames on purpose: one file
is core's and overwritten on pull, the other is the consumer's and never overwritten, and
`CLAUDE.md`'s own opening warning is about exactly that collision.

**I82's ledger is a ratchet and the second direction is what makes it one.** An unlisted violation
fails the build; **a ledger entry core no longer prescribes ALSO fails the build**. And the grammar
file is excluded from its own corpus — load-bearing, not tidy: the ledger lists the offending paths
verbatim, so scanning it would make every entry "still prescribed" by the ledger itself and the
stale arm could never fire.

**Nothing points an authoring agent at the grammar yet, deliberately.** A `SKILL.md` pointer would
tell an agent to obey a grammar the step files it is executing still break in 24 places. **10c is
where the pointer, the step-file rewrite and the reader moves all land together** — and they have
to, because rewriting a prescription while `ai-dlc-continue.sh` still globs the old shape breaks
the hook on the next sprint's first artifact. That sequencing hazard is not in the scope below and
is the main thing 10c must respect.

**A syntactic check over prescriptions cannot see a sprint a PLACEHOLDER conceals.**
`story-<id>-<slug>.md` passes rule 2 — and it is the exact form Check 6's glob broke on. 10e, which
reads real filenames, is where that is caught. Do not read I82 as covering it.

## What item 8's triage measured (the ledger's own verdicts are partly false)

Ran `reconcile/ledger-reverify.sh` over graph's 56-entry push-candidate ledger with the current
distribution as `theirs`, read-only:

```
STILL-LIVE     54
HAND-REVIEW    15
NAMED-UPSTREAM  4
CLOSE-CANDIDATE 0     <- a zero on the only verdict that shows progress
```

**THE ZERO IS NOT EVIDENCE, AND ONE ENTRY PROVES IT.**
`PC-S299-LEDGER-REVERIFY-SIGPIPE-FALSE-ABSENT` reports STILL-LIVE and **is already fixed
upstream**. Its receipt is `theirs_has core/skills/ai-dlc-update/reconcile/ledger-reverify.sh
"grep -qF -- "`, and that substring occurs exactly ONCE in the file —
`core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:290`, which is the REPAIRED line
(`grep -qF -- "$_one" <<<"$_c"`). The defect's own form, `| grep -q`, occurs **zero** times.
**The anchor survives its own fix, so the entry can never close.** That is the check-that-cannot-
fire class, living inside the queue whose job is to track absorption.

**Two more receipt defects, same sweep:**

- **One `verify: sh` receipt of 19 scopes no root**, resolving `core/skills/…` against the process
  cwd. Same class as the two live bugs this session's releases fixed.
- **One cited path is malformed** — `core/.claude/skills/ai-dlc/steps/retro.md`, which is neither
  layout (`CLAUDE.md` §*Two layouts*). Its `theirs_lacks` verdict is vacuous.

**THE FIXES SPLIT, AND THE SPLIT IS THE POINT.** The blind RECEIPTS live in graph's ledger, which
this repo does not write — they go to the operator. What core owns and should fix next:

- `ledger-reverify.sh:147` — `[ -f "$LEDGER" ] || exit 0`. A mistyped argument produces a clean
  rc=0 over zero rows, indistinguishable from a clean corpus. The consumer measured it: swapped
  args → 0 rows, correct args → 69 rows, **both exit 0**. Filed as
  `PC-S316-LEDGER-REVERIFY-EXITS-0-SILENTLY-ON-AN-UNREADABLE-LEDGER-PATH`, and this signature is
  the natural mistake because every sibling in `reconcile/` takes `<dist> <base> <theirs>
  <consumer>` while this one takes consumer THIRD.
- Four sibling entries are also filed against this one file and all report STILL-LIVE:
  `PC-S299-LEDGER-REVERIFY-MISATTRIBUTES-ABSORBING-VERSION`,
  `PC-S316-LEDGER-REVERIFY-DOES-NOT-NORMALIZE-CONSUMER-TO-AN-ABSOLUTE-PATH`,
  `PC-S316-ABSORPTION-DETECTOR-JOINS-ONLY-ON-NUMBERED-ANCHORS`, and the SIGPIPE one above.
  **Re-verify each against the code before building** — the SIGPIPE one is proof that a
  STILL-LIVE verdict here is not evidence the defect is live.

**Do not read the 54 STILL-LIVE as a work queue.** Until the receipts are re-anchored, the set is
a mixture of live entries and entries whose anchor cannot distinguish fixed from broken.

## What item 8c measured (CLOSED — and the blindness is three times what this plan recorded)

All five entries were re-verified against the code before anything was built, as the section above
instructs. **Two were live and are fixed. Three were already fixed and their receipts cannot say
so.** The plan named ONE blind receipt; it is three of five.

| entry | receipt says | measured |
|---|---|---|
| `PC-S299-…-SIGPIPE-FALSE-ABSENT` | STILL-LIVE | **FIXED** — anchored `grep -qF -- `, the REPAIRED line. NAMED-UPSTREAM at v0.300.0 |
| `PC-S299-…-MISATTRIBUTES-ABSORBING-VERSION` | STILL-LIVE | **FIXED** — `absorbed_at()` ships; the receipt anchors prose the corrected emit still prints. History **silent** |
| `PC-S316-ABSORPTION-DETECTOR-…-NUMBERED-ANCHORS` | STILL-LIVE | **FIXED** — `layer-drift.sh` grew an unnumbered arm; the receipt anchors the guard the fix deliberately KEPT. History **silent** |
| `PC-S316-…-EXITS-0-SILENTLY-…` | STILL-LIVE | was LIVE → **v0.301.0** |
| `PC-S316-…-DOES-NOT-NORMALIZE-CONSUMER-…` | STILL-LIVE | was LIVE → **v0.301.0** |

**Only ONE of the three blind ones is visible to `NAMED-UPSTREAM`.** The other two are invisible to
every signal the tool has, which is why v0.302.0 exists.

**A CORRECTION TO THIS PLAN'S OWN TEXT.** §*What item 8's triage measured* says "Four sibling
entries are also filed against this one file". They are not: `PC-S316-ABSORPTION-DETECTOR-…` is
filed against **`layer-drift.sh`**, a different file. It is four plus one.

**THE THIRD ONE WAS SETTLED BY MEASUREMENT, NOT BY READING, and that is the transferable part.**
`layer-drift.sh`'s unnumbered arm names the entry id in its own comment — which is suggestive and
is not evidence. Run against graph:

```
extension entries scanned                                    37
  yielding ZERO numbered anchors (the entry's blind set)     26
CONTROL — core's gate-validation.md yields                   42   <- the harvester works
entries carrying an absorption row                            7
  ...of which are IN the blind set                            6   <- incl. SKILL-push.md,
                                                                     which the entry named
                                                                     BY NAME as unreachable
```

My first attempt at that join returned **0** and I nearly reported it: a `grep -qF` inside a
`while read` that silently matched nothing. It was an absence with no control, in the session
auditing for absences with no controls. The `comm` join above carries its own — 7 total, 6 blind,
1 numbered — and that is what made the zero visibly wrong.

**WHAT CORE SHIPPED, AND THE PREDICATE IT REFUSED TO SHIP.** `SKILL.md` step 3f already carries
the rule — *anchor a `theirs_has` receipt on a token the FIX MUST REMOVE* — and says in the same
breath that it has no guard. v0.302.0 gives it the only mechanism two refs support:
`RECEIPTS-UNDECIDED`, one row per run, counting the `theirs_has` receipts whose substring is
present at **base as well as theirs** — predicates this pull moved neither side of, so their
STILL-LIVE is a restatement, not a measurement. On graph that is **24 of 24**.

**The obvious stronger predicate was built, measured and REFUTED. Do not rebuild it.** Narrowing
that bucket to entries whose cited FILE changed in `base..theirs` fires on **15 of 23** and
includes entries confirmed live (`PC-S302-…-DISARMS-LC-A1`, whose subject sentence is still in
`SKILL.md` — that is plan item 13). There is no third ref for this verb: the question is *would
the fix have had to remove this token*, which two trees cannot answer.

**TWO THINGS ARE NOW THE OPERATOR'S, and neither is core's to do:**

1. **Re-anchor or close the three blind entries in graph's ledger.** They are absorbed. Each wants
   `ADOPTED UPSTREAM (v…, verified <date>)` or a receipt anchored on a token the fix removed. The
   ledger is the consumer's and this repo does not write it.
2. **Read `RECEIPTS-UNDECIDED` on the next pull.** It will say 24 of 24 until the receipts are
   re-anchored, and until then a zero `CLOSE-CANDIDATE` count from that run is not evidence that
   nothing was absorbed.

## What v0.300.0 measured (item 10d — the migration, rehearsed on a clone)

**THE REHEARSAL IS THE FINDING.** Four defects in the migration script, none of which reading it
would have caught, all of them found by running it against a clone of the reference consumer:

1. **A component regex run against whole paths.** The token boundary is `^` or `-`; `/` is neither,
   so `docs/retro/sprint-299.md` matched NOTHING. **668 files detected instead of 2551**, with
   `docs/retro` absent from the plan entirely.
2. **Adjacent tokens hide each other.** `grep -o` and `sed …g` consume the separator the next token
   needs, so `gate-log-archive-s291-s292.md` reported ONE sprint — a two-sprint file planned as
   unambiguous, which would have filed it under the wrong sprint permanently. Fixed by stripping
   one token at a time to a fixed point.
3. **The slot nested inside the token it replaces.** A basename-only transform wrote
   `implementation-artifacts/sprint-287/smoke-evidence/s287/foo.md` on **53** directories.
4. **A half-migrated story corpus.** `story-S298-1-x.md` carries a matchable token and
   `story-297-1-x.md` uses a bare number the transform cannot tell from a story index, so a run
   over `stories/` moves one sibling and leaves the other.

**THE NUMBERS THE OPERATOR NEEDS**, measured on a clone of graph at `655fd3acf`:

```
tracked files scanned                  5145
moves planned / applied / verified     2667      git: 2670 renames, 0 content changes,
                                                 tracked file count identical either side
REFUSED                                  48      45 ambiguous, 3 with no derivable area
DEFERRED (stories/, item 16)           1001
destinations still carrying a token        0
second run                            rc=3       idempotent
```

**THE GRAMMAR DECLARES EIGHT AREAS; THE CONSUMER HOLDS SPRINT-TOKENED FILES IN EIGHT MORE** —
`brainstorming`, `test-artifacts`, `party-mode`, `gate-adjudication`, `party-verdicts-retro`,
`party-review`, `ai-dlc-update`, `sprint-review-transcripts`. They migrate under an inferred area
and the run REPORTS each one. **The grammar file should declare them**; until it does, the
enforcement in 10e will not govern them.

**The generic rule reproduces the grammar's hand-written destination table with no lookup table in
the script.** That is the control on both — they were derived independently and agree.

## What v0.299.0 shipped (item 10c, with F4 folded in)

**The ledger is EMPTY and both of I82's arms were re-proven against it**, because an empty join
reads exactly like a dead one. Guarded mutants: reintroducing one retired spelling fires the
violation arm, one obsolete ledger row fires the stale arm, the unmutated tree is green. Control
that the extractor still sees anything: **74 distinct prescribed paths**.

**THREE THINGS A LATER SESSION MUST NOT RE-DERIVE.**

1. **`sprint-status.sh sprint-id` NEVER FAILS.** With no envelope on disk it returns `1` —
   greenfield, `route.md` Step 6 rule 2, and correct there. So any reader that composes a path from
   it gets a CONFIDENT WRONG sprint rather than an empty one when state is broken, and scoping to
   `s1/` finds nothing, adjudicates nothing and passes in silence. Both hooks therefore carry the
   same control Check 6 uses: a missing sprint directory is only suspicious when OTHER sprint
   directories exist. **Any future reader built on `sprint-id` needs that control too.**
2. **`sprint-status.sh` resolves its root from the PROCESS CWD unless given `--root`.** The hooks
   shipped without it and returned `1` against a tree declaring `7`. Found by a fixture, not by
   reading — `divergence-hard-block`'s new no-envelope arm.
3. **`s*` is now a declared spelling of the reserved slot**, exempt only as a whole component. A
   cross-sprint read is not a currency question. `s*-retro.md` is still rejected.

**F4 is closed, and the fix was an ORDERING, not new logic.** `validate-ci-gates.sh` returned
`78 VACUOUS` before reading a retro, so the "runs it locally" path `retro.md` documents produced no
inventory. The alias-table path that serves a locally-enforced project already existed and touches
no workflow directory — it was simply unreachable behind a check that returned first. The vacuum now
reports every gate it could not check, and vacuous means no surface AND no alias table.

**ONE ITEM WAS SPLIT OUT rather than done badly — item 16, below.**
`planning-artifacts/stories/` did NOT move. It is syntactically conforming (the directory carries no
sprint token) and the sprint hides in the FILENAMES, which is exactly the limit the grammar
documents. Check 6's *silence* was fixed here; its *path* was not.

**v0.298.0's "what each becomes" table claimed 10c had no design work left and was INCOMPLETE.** It
had no row for either log at `_bmad-output/` root — those sit under a scan root but under no area,
so no row could be composed without a decision nobody had made. The table now carries the rule
(every rotation archive lands at `implementation-artifacts/s<N>/<basename>-archive.md`) and 10d
works from it.

## What v0.297.0 measured (a gate defect the 10a+10b push exposed)

**Not attributable to item 10.** Touching `audit-rule-files.sh` — required by I23, which binds every
shipped rule file into the audit corpus — put it in the self-update gate's probe set, and the gate
deferred. Re-measured over every script the consumer's pre-push actually invokes, on a consumer
built by running `install.sh` into an empty tree — **SEVEN, not the five v0.288.0 had**:

```
validate-audit-anchors.sh         bare rc=2   hook passes --trunk-push + stdin
validate-provenance-block.sh      bare rc=2   hook passes --strays
audit-rule-files.sh               bare rc=1   hook passes --fail-on=deterministic
validate-layer-entries.sh         bare rc=0   hook invokes it bare
validate-compact-window.sh        bare rc=0
validate-fixture-drivability.sh   bare rc=0
sync-taught-schema.sh             bare rc=0
```

`validate-layer-entries.sh` is **rc=0** here, not the rc=2 v0.288.0 recorded — that measurement was
taken from a different cwd. **The new case is `audit-rule-files.sh`: bare it defaults to
`--fail-on=any` while the hook passes `--fail-on=deterministic`, so it exits 1 while printing
`tier-1 findings: 0`.** It fails a threshold the hook never applies, identically on both sides, and
v0.288.0's both-non-zero arm called that unattributable and deferred. A probe can ask the wrong
question without earning a usage error, which is why scoping the exemption to `2` was too narrow.

**Expect this class again on any release that edits a script the consumer's pre-push invokes.**

## What item 7's remaining sweep measured (NEGATIVE — the lead's premise was wrong)

The lead read: *"`validate-layer-entries.sh` (1694 lines, five line-initial extractors — the shape
that produced the `validate-ac-falsifiability.sh:244` defect), then `validate-gate-manifest.sh` and
`audit-rule-files.sh`."* **The count was wrong and the shape is not there.** Measured 2026-08-07
with one expression across every core validator, so the population is derived rather than guessed.

```
anchored extractors  (sed/grep/awk with a leading ^)
  validate-layer-entries.sh                     13     <- the lead said five
  validate-gate-manifest.sh                      0
  audit-rule-files.sh                            0
  control, same grep, same run: the sibling     13     <- the zero is not a false zero
```

**All 13 anchor against a grammar that genuinely IS line-initial**, which is the opposite of the
`:244` defect. Markdown headings (`^#{2,4}`, `^\*\*`), YAML keys (`^contract_version:`, `^  - id:`,
`^consumer_*_file:`), whole-value tests on a here-string (`^[0-9]+$`, `^[0-9a-f]{7,40}$`), a diff
prefix (`^+`), a fence marker. **Not one extracts a citation token out of PROSE**, which is the
only place a leading `^` can silently match nothing.

**The one surviving prose-anchored extractor in core is `validate-ac-falsifiability.sh:244` itself,
and it is already dispositioned — do not reopen it.** §*What v0.280.0 measured* records that the
obvious fix was built as a probe and measured against the live sprint: **8 occurrences, 8 false
positives**, all prose quoting the token inside repair-history sections. It was deliberately not
shipped.

**One NOTE, recorded as a note and not elevated.** `validate-gate-manifest.sh`'s final line is
`PASS — both directions resolve.` and does not name how many resolved. That is the class v0.287.0
fixed elsewhere — but this script already dies on `GATE_MANIFEST parsed zero rows`, dies on a
missing `universal` row, and refuses an ambiguous manifest rather than picking one (*"Picking one
would make this scan's PASS unattributable"*). A vacuous PASS is structurally unreachable, so the
missing count is cosmetic.

**No release. A measured absence with a control is the deliverable here**, and item 7 closes on it.

## SPENT — Item 11, shipped as v0.288.0 (#388)

**This is the SCOPE, not work outstanding.** Kept for the derivation; the fix is in the release.

Found 2026-08-07 when v0.288.0's push went red on `self-update-join-gate` (green on `main`, so
attributable). **The blocker is not in v0.288.0.**

`self-update-gate.sh` runs each gating script twice — the consumer's current copy and the
incoming one — and compares exit codes. It invokes them **bare: no arguments, no stdin.**
Measured on `main`, every script the consumer's pre-push invokes:

```
validate-audit-anchors.sh        rc=2   <- usage error
validate-layer-entries.sh        rc=2   <- usage error
validate-provenance-block.sh     rc=2   <- usage error
validate-compact-window.sh       rc=0
validate-fixture-drivability.sh  rc=0
```

**Three of five.** For those, the differential compares two usage errors, both non-zero, so the
gate emits `SELF-UPDATE-UNDECIDED … both versions exit non-zero … treat as defer`. The verdict
is right on its own terms and the probe is worthless: **any machinery-only pull touching one of
those three defers permanently**, folding the machinery slice into the operator-gated apply —
the exact cost §*pull graph in TWO hops* exists to avoid, arriving by accident rather than by a
rulebook change.

`validate-audit-anchors.sh`'s own gate text names the distinction the gate cannot make:
*"Exit 2 is a malformed invocation, NOT a missing anchor."* This is the session's recurring
class again — a verdict that cannot tell two things apart, reading as the safe one.

**Shape, not yet built.** The probe needs an invocation each script can actually answer, or an
explicit exemption for scripts whose bare form is a usage error — and `rc=2` is already the
declared token for that, so the cheapest arm is to treat "both sides exit 2" as *not a
differential signal* rather than as an unattributable failure. **Measure the false-positive set
across all five gating scripts before shipping**, and add a `self-update-join-gate` arm proving
a genuinely-newly-failing incoming script still DEFERS — otherwise the fix removes the gate.

## What v0.294.0 measured (item 14 — SHIPPED; the section below is the pre-work scope)

**The section that follows is the SCOPE as written before the work, kept for its reasoning.
Where the two disagree this one wins.** Three of its statements were refuted by measurement.

**REFUTED: "both need elevated privileges — establish that is workable before anything else,
it is the single point that can kill the approach."** Half right. `dtruss` is dead and root
does NOT lift it — SIP restricts `/bin/bash` itself (`dtrace: failed to execute /bin/bash:
Operation not permitted`), so disabling SIP is the only route and it buys nothing, because
`fs_usage` already reports the same opens and stats. `fs_usage` needs root and works. **Do not
disable SIP for this.**

**REFUTED by measurement, and it disqualifies the obvious privilege-free method:** APFS is
**relatime-like**. A second read of a file does NOT advance its atime, so a before/after
watermark misses every file read twice — the fatal under-record. Forcing atime to 2001 before
each fixture defeats relatime by construction.

**THE PREREQUISITE NUMBER, which the scope below says must exist before any skip is written:**

```
drivable fixtures                                          118   (120 dirs; 2 are seed.sh-only)
  named in an enforcement-map `fixtures:` binding           40
  named NOWHERE                                             78
paths read but not declared, bound fixtures               ~515
paths read by fixtures with no binding at all             7477
TOTAL a declaration-based skip would have missed         ~8000
```

**THE PAYOFF IS 42% OF WALL CLOCK, NOT THE 76% OF WORK REMOVED**, and quoting the larger number
alone is wrong: makespan equals the longest SELECTED unit, so removing 100 cheap fixtures that
ran in parallel anyway moves little. Mean 15.7 of 118 fixtures selected across 40 real commits.

**THE HAZARD ARRIVED THROUGH A ROUTE THE SCOPE DID NOT ANTICIPATE.** It warned that
under-recording one path yields a silently skipped suite. It does — but the largest source was
not a tracer missing an event, it was **the harness changing the program it measured**:
`check-22-spawn-ledger` passes 16/16 as a normal user and fails 9/16 as root, because an arm
asserts a settings-readability REFUSAL and root reads regardless of permissions. An arm root
skips READS FEWER FILES. Trace fixtures unprivileged or the map is corrupt.

**Read-sets are effectively deterministic**: two independent traces of 20 fixtures gave 17
identical and 3 differing by one path — two of those were a branch ref that genuinely moved
between runs, one a negative lookup on a nonexistent file. One variable path in ~4000.

**Maintenance is per-fixture, not a full re-run** — `--list "<fixtures>"` costs a fixture's
runtime plus ~9s. A fixture whose own directory changed has no valid entry and runs by default.

## SPENT — Item 14's pre-work scope, shipped as v0.294.0 (#402) + v0.295.0 (#403)

**This is the SCOPE, not work outstanding.** What it MEASURED, including four things not to re-derive, is in §*What v0.294.0 measured* above — read that first; this section is the plan it was written against.

**The question that produced it.** *"Why does the pre-push gate need to validate unchanged
fixtures?"* The answer is that it largely does not — `scripts/suite-content-key.sh` hashes a
superset of everything the suite can read and skips the whole run on a hit, announcing the skip
and naming the key. What it cannot do is skip PART of the suite, so any change to anything pays
the full makespan.

**"Unchanged fixture" is not "unaffected fixture", and v0.293.0 is the proof.** That release
changed `scripts/validate-plan-shape.sh` and touched zero fixtures; `plan-shape` went red,
correctly, because its SUBJECT moved. A filter keyed on "did this fixture's own files change"
would have skipped exactly the fixture that caught the regression.

**Why the declared bindings cannot be the map. Measured 2026-08-07:**

```
fixtures on disk                                        120
named in an enforcement-map `fixtures:` binding          42
NOT named in any binding                                 78     <- 65% of the suite
```

A per-fixture skip built on declared bindings would skip those 78 blind. And even for the 42, the
binding names what a CLAUSE is proven by, not what the fixture READS — `plan-shape` reads the
validator, every file under `docs/plans/`, and the directory listing itself, while its binding
names one clause.

**The design.** Run each fixture once under a syscall trace, record every path it opens, and key
a per-fixture skip on that measured read-set. On macOS the tracer is `dtruss`/`fs_usage` (both
need elevated privileges — establish that is workable before anything else, it is the single
point that can kill the approach); on Linux, `strace -f -e trace=openat`.

**THE HAZARD, and it is the reason this is scoped rather than just built.** Under-record one path
and the result is not a slow suite — it is a **silently skipped** one. That is this repo's named
defect class aimed at its own gate, and it is invisible by construction: a fixture that never ran
reports nothing, and the summary says green. Any implementation must therefore:

- **Fail CLOSED on an unmapped fixture.** No read-set recorded, no skip — run it. A fixture whose
  trace failed must never be treated as "depends on nothing".
- **Re-derive the map when the fixture itself changes**, or the map describes a program that no
  longer exists.
- **Announce every skip and name the read-set that justified it**, the way the content key
  already does. A silent partial run is the defect.
- **Carry a periodic full run** — a scheduled or flagged `AI_DLC_FIXTURE_NO_SKIP` sweep whose
  verdicts are compared against what the map predicted. A map that has drifted is only findable
  by running what it said to skip.

**The prerequisite measurement, and it is the deliverable of the first pass:** trace all 120,
then **diff the trace-derived read-sets against the 42 declared bindings. That gap is the risk,
quantified** — every path a fixture reads that its binding never mentioned is a path a
declaration-based skip would have missed. Do not write the skip until that number exists.

**What the payoff is, honestly.** The content key already skips 100% of the suite when nothing
moved, so this buys nothing on a no-op push. It buys on every REAL push, where one changed file
currently costs the full 214s makespan. The suite is pole-bound and not CPU-saturated (2876
CPU-seconds over ~240s wall, system time beating user 2:1), so the win here is not more
parallelism — it is not starting the units at all.

**Out of scope: do not touch the content key.** It is the safe outer skip and I55 keeps its
exclusions honest. This is a second, finer skip inside it, and if the finer one is ever in doubt
the correct fallback is the full run.

## SPENT — Item 10, complete across five sub-releases (10a/10b v0.298.0, 10c v0.299.0, 10d v0.300.0, 10e v0.305.0)

**This is the SCOPE, not work outstanding, and it is the longest section above `## Context` that used to read live.** Kept because the measurement and the grammar derivation behind the convention are here and nowhere else. **The convention itself now lives in `core/skills/ai-dlc/artifact-path-grammar.md`, which is the shipped artifact and the thing to read** — this section is why it says what it says.

Raised by the operator 2026-08-07 after v0.287.0, as a question this plan had answered badly:
*"none of that addresses how you know which one is the current, and this is happening in other
folders, not just `_bmad-output/`."* Both halves were right. Everything below is measured.

### The principle the measurement produced

**Currency is DECLARED, never searched.** One home: `_bmad-output/implementation-artifacts/
sprint-status.yaml`, key `sprint: N`, resolved by `sprint-status.sh sprint-id`
(`core/scripts/sprint-status.sh:152`). Every place that instead asks the filesystem is a second
answer that can disagree with the first, and the chain that works has three links:

1. declared identity → `N`
2. a **TOTAL** function from `N` to a path
3. **no search**

**Flatness is not the defect — a filename grammar with no reserved slot for the sprint is.**
`docs/retro/` is the control that proves it: 299 files, flat, **288 matching `sprint-<N>.md`
exactly**, six core programs reading it, and not one of them ever asks which is newest, because
each composes the path from a sprint number it was given. Where link 2 is total, flat is fine.
Where it is partial, the reader must search, and search means mtime.

### What is actually in the tree

Measured on the reference consumer, read-only, 2026-08-07.

```
_bmad-output/planning-artifacts/*.md    805 files, 56 distinct sprints (s7 -> s301)
  sprint token as PREFIX  s<N>-         369   s289-adversarial-pass1-discovery.md
  sprint token as SUFFIX  -s<N>         173   architecture-adversarial-s288-pass2.md
  sprint token as WORD    sprint-<N>    169   prd-adversarial-sprint-150.md
  no sprint token at all                 95   aws-cost-analysis.md   (counts overlap)
```

**`stories/` alone carries at least six spellings of one idea**, and the split is live:

```
998 story files
  story-<N>-<M>-slug.md      786   sprints ... 294 295 296 297
  story-S<N>-<M>-slug.md      73   sprints ... 287 298 299        <- capital S
  neither                    139   S<N>-, s<N>-, sprint-<N>-, bug-, hotfix-, 6 with no prefix
```

**That split has already produced a live zero-verification PASS.** Check 6 of
`validate-mandatory-rules.sh` globs `"${STORIES_DIR}/story-${SPRINT_N}-"*.md`
(`core/scripts/validate-mandatory-rules.sh:346`). For **sprints 298 and 299 the glob matches
zero files**, the loop body never runs, `CHECK6_FAILURES` stays 0 and the check prints PASS.
Control on the same directory in the same read: `story-297-*` matches **11**. Two of the last
four closed sprints had their Dev Agent Record compliance verified against nothing. This is the
same class v0.287.0 just shipped two fixes for, arriving through the naming grammar instead of
through a counter.

*(Recording the miss as well as the finding: the first pass at this counted the capital-S form
as zero, because the grep was lowercase. That is the exact false-zero source `CLAUDE.md` lists
second. The numbers above are the re-measurement.)*

**Outside `_bmad-output/`, 6177 tracked files, the same shape with different exposure:**

| directory | files | naming function | who reads it | status |
|---|---|---|---|---|
| `planning-artifacts/` | 805 | partial, 4 positions | **hooks, by mtime** | **live defect** |
| `stories/` | 998 | partial, 6 spellings | **Check 6, by glob** | **live defect** |
| `docs/reviews/` | 1032 | none — 183 carry `s<N>-`, **849 carry no token** | prose only, LLM-read | latent |
| `docs/retro/` | 299 | **total** (`sprint-<N>.md`) | 6 programs, all composing | safe |

And the convention is **already split in the consumer's own tree**: `scripts/s272-1-datastack-import/`,
`docs/evidence/s271-2/`, `test-results/s287-ff5-evidence/` and
`scripts/tests/fixtures/s278-2-floor-verify/` all use per-sprint directories, while
`docs/reviews/` and `planning-artifacts/` do not. Nothing chooses between them.

### The inconsistency ORIGINATES IN CORE, which is why this is a core release

Core's own step files prescribe **five** sprint-token spellings across 21 files:

```
s<N>- prefix        s<N>-bug-fix-oneshot.md, s<N>-research-notes.md,
                    s<N>-<artifact>-adversarial-p<M>.md, s<N>-coe-adversarial-p<M>.md, +3
sprint-<N>- prefix  sprint-<N>-retro.md, sprint-<N>-retro-draft.md,
                    sprint-<N>-next-inputs.md, sprint-<N>-closeout-tables.md
-sprint-N suffix    ui-mockups-sprint-N.md            <- and it is bare `N`, not `<N>`
-s<N> suffix        gate-log-archive-s<N>.md
no token            prd.md, architecture.md, product-brief.md, test-strategy.md, ...
```

The consumer's four-position mess is **core's grammar faithfully executed**. Fixing the
consumer without fixing the prescription re-creates it next sprint.

### The proposed grammar

**The directory is the ONLY sprint slot. No filename may carry a sprint token.** That collapses
four positions into one and makes conformance a single checkable rule instead of a union of
patterns.

```
<area>/                          area root = DURABLE, sprint-independent, never moves
  <name>.md                        prd.md, architecture.md, product-brief.md, active-epics.md
  s<N>/                          every artifact PRODUCED BY sprint N
    <kind>[-<subject>][-p<M>].md   architecture-adversarial-p2.md, retro.md
    stories/
      story-<M>-<slug>.md          the sprint comes from the directory; <M> is the story index
```

Five rules, each mechanically checkable:

1. **`s<N>` is the only spelling** — lowercase `s`, no zero padding, never `S<N>`, never
   `sprint-<N>`, never a bare number.
2. **No basename may match a sprint token** (`s?[0-9]{2,4}` or `sprint-[0-9]+`). Anywhere.
3. **A file at an area root carries no sprint token and no `s<N>/` parent** — that is what
   makes it durable, and it is the predicate a close-out sweep has never had (the 95).
4. **`kind` comes from a declared closed set**, the way `pr-classes.md` and `story-fields.md`
   already work.
5. **`p<M>` is the only pass marker** — no `pass<M>`, no `-pass-<M>`. Ordering stays
   `order_key()`'s job, never mtime's.

Applies to `docs/retro/` and `docs/reviews/` too, per the operator's "one generic convention":
`docs/retro/s<N>/retro.md`, `docs/reviews/s<N>/<subject>.md`. **`docs/retro/` is the one place
this is a net loss in isolation** — its function is already total — and it is included anyway
because a convention with a carve-out is two conventions. Cost is named here so the sub-release
that changes `validate-retro-evidence.sh:179` and `validate-provenance-block.sh:404` knows it is
paying a known price, not fixing a defect.

**What this buys, concretely.** `ai-dlc-continue.sh:289` and `ai-dlc-acknowledge.sh:173` stop
being `ls -t` over 135 files spanning 56 series and become a composed path under
`s<N>/` — the pick has one candidate set, scoped by construction. Both hooks currently carry the
confession in their own comment (`ai-dlc-continue.sh:283`, `ai-dlc-acknowledge.sh:167`): *"STILL
NOT FIXED, and deliberately: the pick is by mtime across EVERY adversarial series in this one
directory … There is no naming-safe scope to add — series names take the sprint as a SUFFIX as
well as a prefix."* **That sentence is the case for this item, written by the release that
could not fix it.** v0.286.0 closed the strip-defeated half of item 3's measurement; this closes
the other half, and item 3 should not be read as fully discharged until it does.

### Sub-releases, in order

**10a — DECLARE.** `core/skills/ai-dlc/artifact-paths.md`, one home for the grammar, the `kind`
set and the durable/per-sprint predicate, plus `consumer_artifact_paths_file:` in
`layer-contract.yaml` — exactly the shape `consumer_pr_class_file:` (`:220`) and
`consumer_story_fields_file:` (`:241`) already have. No behaviour change. `contract_version`
bumps here.

**10b — BIND CORE TO ITS OWN GRAMMAR.** A new `validate-enforcement-map.sh` invariant deriving
every `_bmad-output/…` write path core prescribes across the 21 step files and asserting each
conforms. Fails the build on a sixth spelling. This is the arm that stops the regrowth, and it
must ship before any migration or the migration is undone by the next sprint's writes.
**Measure the false-positive set on all 21 step files before shipping it** (`CLAUDE.md`).

**10c — READERS COMPOSE, NEVER SEARCH.** Rewrite the search sites onto composed paths: both
hooks' `SERIES` derivation, Check 6's story glob, `validate-spec-adoption.sh:172`,
`validate-retro-evidence.sh:179`, `validate-provenance-block.sh:404`. Each gets a fixture arm
proving it fails when the composed path is absent — a reader that silently finds nothing is the
defect being removed, so it must not be reintroduced as the fix.

**10d — MIGRATE.** A core-shipped `scripts/ai-dlc/migrate-artifact-paths.sh`: `git mv` only,
never delete, per-file verification recorded as *source-absent AND dest-readable AND
sha256-identical* — the s300 close-out's form, which is per-file and not a count. Dry-run
default, `--apply` to write. **The OPERATOR runs it on the consumer**; this session never writes
that tree. Historical traceability breakage is accepted by operator directive, so the script
does **not** attempt link rewriting — the declared convention is the guide.

**10e — ENFORCE ON THE CONSUMER.** A validator wired into the consumer pre-push that fails on a
non-conforming artifact path, with `--report` for the migration's before/after. Ship last, after
10d has run once, or first contact wedges on ~2200 non-conforming files.

**Sequencing constraints.** After item 7 (it rewrites the paths F3/F4 evidence cites) and after
the two-hop pull (a rulebook change of this size must not ride a stale engine). Cheapest order
to interleave with item 8 is 10a→10b, then item 8's ledger triage, then 10c→10e, because 10c
changes files several push-candidate `verify:` receipts anchor to.

## SPENT AND REFUTED — "pull graph in TWO hops"

**DO NOT FOLLOW THE HOP COUNT IN THIS TITLE.** The 0.292.0 → 0.300.0 pull took THREE hops and four PRs, and this plan predicted a hop count from the distribution side twice and was wrong both times. **The rule that replaced it: run the dry run and read what the gate says.** What survives here is the MECHANISM — why a bundled pull defers its machinery slice to step 7 and what a stale engine then misclassifies — which is worth reading before any multi-release pull.

A bundled `0.274.0 → 0.278.0` pull returns `SELF-UPDATE-DEFER`, so the machinery slice lands at
step 7 — *after* step 3's classify. The stale engine then classifies, and the three absorbed
overrides come back as ordinary `HARD-OVERRIDE-DRIFT-SECTION` ("re-adopt the new wording"),
with **zero** `OVERRIDE-SUPERSEDED` and **zero** `EXTENSION-TITLE-MATCHES-CORE` rows. Measured,
not predicted.

```
git -C /Users/n8/git/ai-dlc checkout d4df7c0    # v0.275.0 — machinery only, gate returns SELF-UPDATE-OK
# /ai-dlc-update apply
git -C /Users/n8/git/ai-dlc checkout main
# /ai-dlc-update apply
```

Second hop then yields **3 `OVERRIDE-SUPERSEDED`** + **13 `EXTENSION-TITLE-MATCHES-CORE`**
(verified on a scratch copy). v0.278.0's `--safe-stop` derives `d4df7c0` automatically, but
**cannot help this pull** — step 2 runs graph's own installed gate, which is at 0.274.0 and
emits zero SAFE-STOP rows. This one split is manual; after it, it is permanent.

## Mid-sprint safety (asked and answered with evidence)

Nothing in the tree gates the pull on sprint state (grep + control: zero hits). Steps 6–7
branch before any write and require **explicit operator approval** to merge, separate from the
`apply` arg — so a reconcile cannot mutate the sprint branch. Measured blast radius for the
whole range: **0 of 40 `core/scripts/` validators change**; 6 rulebook files change; exactly
one live-gate behaviour change (Check 7 non-vacuity, +7 lines).

Practical split: **hop 1 is safe mid-sprint** (machinery only, nothing a sprint executes).
**Hop 2 carries all six rulebook files** — take it at a sprint boundary, or `apply` and leave
the reconcile PR unmerged until retro.

## SPENT — "Still open", and NOTHING in it is still open

**EVERY ITEM THIS SECTION LISTS HAS SHIPPED, AND ITS ONE REMAINING BULLET ALSO REPEATS A PREMISE
THIS PLAN LATER REFUTED.** R6 shipped as plan item 6 across four releases — v0.311.0 (#434),
v0.312.0 (#435), v0.313.0 (#436), v0.314.0 (#437). **Do not act on its stated gate**: "only after
graph burns down the 13-row `EXTENSION-TITLE-MATCHES-CORE` set" is false twice over — those rows
are `level: WARN` and cannot block, and they belong to LC-E19, which R6 does not touch. The
measured account is in §*What item 6 measured*, including that **both zeros the gate turned on were
unreadable** — one FALSE, one a SILENCE. What follows is the original text.

**R3 and R4 are NOT open — they shipped.** R3 is v0.282.0 (#370), carrying the multi-key
`settings_env_keys:` mechanism and retiring `SKILL__auto_handoff_mode`; R4 is v0.281.0 (#369),
`--fail-on <artifact>` plus the supersession-marker arm, retiring
`steps__retro__pipeline-snapshot-ceiling` as a CONFIGURED supersession. Their design text
survives below under §*Release sequence* as rationale only.

- **R6 promote LC-E6/LC-O15 to ADJUDICATED** — the one release item still open. Only after graph
  burns down the 13-row `EXTENSION-TITLE-MATCHES-CORE` set, or first contact wedges on ~13
  blocking rows. Ship it last.

## What v0.283.0 measured about the suite (SUPERSEDES the section below in three places)

The section below is kept for its reasoning, which was right about the SHAPE — the suite is
pole-bound, its makespan equals its longest unit, and the lever is that each heavy fixture is
internally serial. Three of its specifics were wrong, and each was wrong in a way that would
have mis-aimed the next session:

1. **The durations it quoted were contention-inflated, not unit costs.** `run_fixtures`
   rewrites `.git/ai-dlc-fixture-durations` on every run with each unit's wall clock *under
   16-way load*. `enforcement-map-derivations` was recorded at 282s and later 508s; its actual
   standalone cost was **137s**. Read that file as a scheduling input, never as a cost model.
2. **Two of the six named fixtures already had inner pools** (`enforcement-map-sites`,
   `layer-contract-conformance`), and two fixtures NOT on the list were bigger than most of it
   (`self-update-join-gate` 105s, `trunk-audit-mutants` 67s). The list was assembled from the
   inflated numbers.
3. **"The biggest goes 282s → ~35s, dropping the makespan toward `sum/16` = 150s" did not
   happen, and could not.** Removing one pole exposes the next one, and there were seven units
   clustered between 130s and 250s. Measured end to end: **268s → 238s**, about 11%.

`enforcement-map-sites` was the pole no inner pool could reach — its unit duration EQUALLED
the makespan at every outer pool size from 4 to 16 — so it is now sharded across three
directories. The outer knob was re-derived on the sharded tree and stays at 16: lower is
monotonically worse (236s at 8, 247s at 6, 260s at 5, 272s at 4).

**Where the remaining time actually goes, so nobody re-runs these.** The suite is 2876
CPU-seconds over ~240s wall, at 1165% of a possible 1800% — **not CPU-saturated**, and
**system time beats user time 2:1** (1914s vs 962s). That is `fork`/`exec` and VFS overhead
from tens of thousands of short-lived processes and ~60 repo-tree copies per run. Two hardware
hypotheses were tested and both are dead ends: `TMPDIR` on a 24 GB RAM disk left system time
unchanged (1914s → 1970s) and the makespan at 245s, because the copies were already served
from the page cache; and there is nothing here a GPU can take, since the bottleneck is the
kernel's per-process and per-file cost rather than arithmetic. **The remaining lever was NOT storage or scheduling but SPAWN COUNT INSIDE the validator**,
and v0.284.0 took it: 1582 external commands per run became 1156 and the run went 8.36s to
7.02s, byte-identical on the failing paths as well as the passing one. Suite makespan across
both releases: **268s → 214s**. What is left there is `i75_norm` (`awk | grep | sed` twice per
subject file, ~60 forks). The older sentence below said the lever was fewer validator
INVOCATIONS; it is fewer PROCESSES per invocation — `validate-enforcement-map.sh` is ~8.5s a call with no
hot spot (a cut-bisect rises monotonically across ~76 invariants) and the suite makes ~140 of
them.

**One intermittent is now on the record.** Four fixtures went red once each across this
release's ~20 measurement runs — `crosswalk-home-declaration`, `apply-drift-refile`,
`enforcement-map-sites`, `suite-dispatch-order` — every one green on standalone re-run.
`.githooks/pre-push` documents the class. More nested pools can only make it likelier. If a
push is blocked by a single red fixture, re-run that fixture alone before believing it.

## The suite critical path — measured, after two invalid measurements

**The pool is not the problem and `FIXTURE_JOBS` cannot help.** From
`.git/ai-dlc-fixture-durations`: 115 units, **2408s serial total**, longest single unit
**282s**. A 16-way ideal makespan is `max(2408/16, 282) = 282s`; observed is **297s**, so the
pool already runs at 95% of its theoretical best. The makespan is bounded below by the single
longest unit.

**`validate-enforcement-map.sh` has no hot spot.** 8.5s per call, and the cumulative curve from
a cut-bisect is flat: 3.66s at 30% of the file, then 5.15 / 5.72 / 6.73 / 8.10 / 8.73. It is
~76 invariants each scanning the tree. There is no cheap single-point fix, and one was
attempted and reverted — a nested shell loop rewritten as a single `awk index()` pass produced
**byte-identical output and 8.40s → 8.60s**, i.e. nothing.

**THE LEVER IS THAT EACH HEAVY FIXTURE IS INTERNALLY SERIAL.** At 8.5s a call:

| fixture | cost | ≈ validator calls |
|---|---|---|
| `enforcement-map-derivations` | 282s | 33 |
| `enforcement-map-sites` | 240s | 28 |
| `ledger-status-vocabulary` | 193s | 22 |
| `consumer-machinery-home` | 186s | 21 |
| `layer-contract-conformance` | 151s | 17 |
| `crosswalk-home-declaration` | 151s | 17 |

138 calls, ~1173s of the 2408s. The pre-push pool parallelizes ACROSS fixtures; each of these
runs its 17–33 independent mutants SEQUENTIALLY inside one pool slot. Give each an inner pool
and the biggest goes 282s → ~35s at 8-way, dropping the makespan toward `sum/16` = 150s.
`.githooks/pre-push:99` already describes doing this for one case, so the shape exists.

**Both failed measurements are recorded because each looked authoritative.**

- `bash -x` charges every command a trace-write, so a 24,000-command trace ranked commands by
  FREQUENCY and presented `IFS=`, `read -r` and `case` as the cost. They were the cheapest
  commands in the file, run the most times. That is what aimed the reverted rewrite at the
  wrong loop.
- A cut-bisect whose copies ran from `/tmp` returned 0.02s at EVERY cut, including one at the
  last line. `REPO_ROOT` is `dirname($0)/..`, so each copy failed root resolution immediately
  and every timing was a script that did nothing. **A uniform result across a bisect is the
  signature of a harness fault, not a flat profile** — the real flat profile, once the root was
  pinned, still rises monotonically.

## What the unreached-step audit found

s301 stalled at `stories-test-strategy.md` §4, so everything downstream is unexercised. The
unreached set, derived from `route.md` and the `GATE_MANIFEST`: `stories-test-strategy.md` §5–7,
`ui-direction.md`, `implementation.md`, `sprint-review.md`, `sprint-review-next.md`,
`deploy-validate.md`, `retro.md`, `artifact-consolidation.md`, `handoff.md`. Control on the
"reachable only through those" claim: **10 of 31** `core/scripts/validate-*.sh` are absent from
`gate-validation.md`, 21 present.

**F1 — `validate-mandatory-rules.sh`, and it is the one that has been passing silently on every
retro the reference consumer has ever closed.** Checks 2, 4 and 5 each have legitimate SKIP
branches; **no SKIP branch touched a counter and no skip counter existed**. The summary printed
`all 6 checks passed` whether six ran or three did, on the same exit code. Verified
independently: `grep -cE 'SKIPS?=|SKIPPED='` → 0, control `grep -cE 'FAILURES='` → 4. On the
consumer, two checks SKIP on **every sprint 296 through 302** because
`validate-retro-prereq.sh` was never provided, and `retro.md` accepts this validator on its
exit code alone. Old and new, side by side on one tree with a stubbed sibling:
`all 6 checks passed` versus `3 of 6 checks verified; 3 SKIPPED (check 2 4 5)`, **both exit 0**.
**SHIPPED as v0.287.0 (#383)**; exit code deliberately unchanged, because a skip is legitimate.

**F2 — `validate-spawn-ledger.sh` asserts a pin it never compared.** Rule 19(a) is compared only
where `EXPECT` is non-empty. Lose the `aiDlcRoles` block and every row falls to `UNPINNED`, the
comparison runs zero times, and the OK sentence still says "a model matching their role's
configured pin". The count already existed and its comment already named the hazard; **nothing
read the count**. Measured with one ledger and two settings files differing only in the key
name: intact gave `FAIL: 2 Rule 19 violation(s)` rc=1, renamed gave the full OK sentence rc=0.
**SHIPPED as v0.287.0 (#383).**

**F3 — `validate-audit-anchors.sh` (Check 18), MEDIUM, NOT yet fixed.** The PASS line counts
ENTRIES, never ASSERTIONS; the guard is `assert isinstance(fields, dict)`, which an empty dict
satisfies while the field loop makes zero comparisons. The lower half needs no schema edit at
all: the sha pattern is `^\S+$` and `PENDING` is rejected only in `--prior-sprint-sha` mode, so
an anchors file whose every sha reads `PENDING` returns "entries PASS — 2 entries validated"
rc=0. `retro.md` Step 5c runs the bare form and requires exit 0, so a wholly unbackfilled
anchor ledger clears that step.

**F4 — `validate-ci-gates.sh`, a deployment gap rather than a code defect, NOT yet fixed.** The
script is correct (distinct VACUOUS wording, distinct rc=78). But on the consumer it has only
ever emitted `VACUOUS: no enforcement surface to scan` rc=78, because there is no
`.github/workflows` (control: `docs/retro` is present). Six unique CI gate names are declared
across 14 of 299 retro files and none has ever been enforcement-checked. `retro.md` says a
script-based consumer with no workflows "runs it locally", and the script cannot serve that
path — without `AI_DLC_CI_SURFACE` it exits 78 before scanning. **Documented remedy and
implemented behaviour disagree, and the consumer is exactly the case that sentence was written
for.**

**Not audited, highest-value remaining lead:** `validate-layer-entries.sh` (1694 lines, five
line-initial `sed`/`grep` extractors — the exact shape that produced the
`validate-ac-falsifiability.sh:244` defect), plus `validate-gate-manifest.sh` and
`audit-rule-files.sh`. Mechanical sweep only, no mutants.

**The shape to rewrite F1 and F2 into is already in the tree:**
`validate-cycle-commits.sh` `audit-trunk` mode has five zero-verification exits, every one with
distinct wording, and a control on the same line at the last.

## Closing s301: what the s300 close-out actually did

**SUPERSEDED — s301 IS CLOSED and this section is history.** The close-out ran, landed on graph's
`main` at `1c72823af`, and the executable procedure it fed is `docs/plans/s301-close-out.md` with
its measurements in `-derivation.md`. Two claims below are now FALSE and are kept only as the
record of what was true beforehand: difference 5 says `main` still lacks `7ecd99dd1` (it has it),
and the whole section presumes s301 is open. Do not act on it.

Reconstructed so the close-out prompt does not have to be invented. **It was TWO commits, not
one**: `7ecd99dd1` (the archive) and `ff490ebd0` (the envelope), ~95 minutes apart, with three
unrelated commits between them.

`7ecd99dd1` — 4 added, 8 modified, **90 renamed R100, ZERO deleted**. Artifacts were `git mv`'d
into six per-series `archive/s300-*` dirs; gate-log emptied; gate-metrics reduced 723→661; the
S300 LOCKED block excised from `product-brief.md` reversibly. Verification recorded per file as
`source-absent AND dest-readable AND sha256-identical`, **not a count**. Two deliberate
NON-actions: no Check 33 `NOT-IN-SCOPE` disposition (it would assert a scope decision that never
happened) and no `RESTART_CYCLE` record (all five series terminated `EXIT_CONDITION_MET`).

`ff490ebd0` — ran `sprint-status.sh close` FIRST then `roll`, because `roll` exits 3 while the
prior sprint is not `done`. Snapshot regenerated by script, not hand-authored. **The new branch
was cut from HEAD, not `main`** — `main` does not carry `7ecd99dd1`, so branching from it would
have resurrected all 90 archived artifacts.

There is **no `abandoned` or `superseded` status value**. The machinery knows only
`in_progress` / `done`; the abandonment lives entirely in the `closure_evidence` prose. And
there is **no documented abandonment procedure in the distribution** — 22 hits for the search
terms, every one either the retro close-out sweep or the adversarial-series `RESTART_CYCLE`
(which abandons a SERIES, not a sprint, and is the pattern the archive dirs imitate). The s300
close-out was improvised against `retro.md:501` + `route.md:394`.

**Six differences an s301 prompt must handle:**

1. **The S301 LOCKED block is an ALIAS of S299, not new content.** S300's was original and was
   excised wholesale; excising S301's must not damage S299's still-live block.
2. `_bmad-output/pipeline-paused.flag` exists and had no S300 counterpart.
   `_bmad-output/.beat-inflight` does NOT exist (control: the pause flag in the same listing
   does).
3. Closing s301 makes s302 the **third** sprint carrying the same unbuilt ask, so S300's
   reasoning about not dispositioning `LR-S299-0..11` has to be restated, not inherited.
4. Volumes differ: 75 gate-metrics rows and a 293-line gate-log, vs 62 and 571 for S300; 97
   planning artifacts vs 90.
5. The branch-cut rule repeats — `main` still lacks `7ecd99dd1`.
6. **`core.hooksPath` is unset**, so consumer git hooks will not fire during the close-out.

Two inventory traps recorded in S300's own commit body, both of which will bite an s301 sweep:
a prefix-only `^s300` glob gives 81 where `-name '*s300*'` gives 86, and `gate-metrics.jsonl`
stores `sprint` as an **integer**, so `grep '"sprint": "301"'` reads 0 and looks clean.

## Known gaps, deliberately not closed

- Both absorption arms join on **markdown headings**. `pm-domain.md` is all bullets (0
  headings), so its retirement can never be reported; retire it by hand. Bold-prose anchors
  were scoped out of v0.275.0.
- `self-update-gate.sh`'s advisory re-entry guard (`AI_DLC_GATE_IN_SAFE_STOP`) is a **cost**
  measure, not a termination one, and is deliberately uncovered by any assertion — no
  observable output distinguishes the two. Documented in the script and the fixture.

## SPENT — open thread at the end of the 2026-08-06 session; s301 is CLOSED and being re-run as s302

**Nothing here is outstanding.** s301 was closed out (`docs/plans/s301-close-out.md`, landed on graph's `main`) and the operator's standing decision is that it is re-run from scratch as s302. Kept as the record of the stall that produced the close-out.

The operator issued a handoff in graph and the sprint has not reached implementation after
hours. Sprint 301 (`eth-rewards-base-v4-pool-indexing`, variant `carry-over`, intensity
`full`), at `stories-test-strategy.md` Section 4 Story Validation Cycle, **mid-cycle**;
`_bmad-output/.beat-inflight` present, 15 dirty paths, `core.hooksPath` unset so the pre-push
hook is not armed.

### Findings (investigated 2026-08-06T20:05Z)

**The stall is the story-validation adversarial cycle, and it is repair-induced.** 44 spawns
on 2026-08-06, of which **15 adversary + 13 remediator = 28 (64%)**. Eight adversarial passes
`p1…p8` (06:51 → 15:02) plus eight repair/resolution artifacts; spawn churn continued to 19:33.
Never left `stories-test-strategy.md`.

Verdict series from `validate-adversarial-convergence.sh --series`:

```
p1 NOT_MET  c=0 m=4      p5 NOT_MET  c=0 m=1
p2 DIVERGENT_HARD_BLOCK  p6 NOT_MET  c=0 m=2
   c=1 m=2               p7 NOT_MET  c=0 m=2
p3 NOT_MET  c=0 m=2      p8 MET      c=0 m=0
p4 NOT_MET  c=0 m=1
```

p3–p7 is a **five-pass plateau at zero CRITICAL / one-to-two MAJOR** — the exact shape the
STALL rung was built for: neither converging nor diverging, so every other rung says "run
another pass". The later passes are almost entirely citation drift, and each repair moves the
line ranges the previous pass verified (p7: *"the two ADR edits shifted two `requires_context`
ranges that p6 had [corrected]"*).

**The detector works and nobody ran it.** Re-running the validator over `p1…p7` only:

```
FAIL (E -- STALL): the cycle held a nonzero MAJOR at ZERO CRITICAL across 4
consecutive passes (from p5 through p7). It is neither converging nor diverging.
```

It fires at **p7 (14:22)**. Once p8 stamped `EXIT_CONDITION_MET` the rung goes silent by
design (no false fire on a converged cycle) — so post-hoc it says nothing. **Operational
lesson: run `validate-adversarial-convergence.sh --series` MID-cycle, not at the end.**

**A second live violation, still open:**

```
FAIL (F -- RESOLUTION): p3 claims to resolve p2, but resolution-p2.md cites
operator_authorization, and no readable transcript was provided (--transcript).
```

**The broken machine check underneath** is `validate-locked-anchor.sh` — p3's MAJ-p3-2 reads
*"both new `prior_evidence:` citations are unresolvable, and clear the validator only by line
position."* graph's own ledger already carries three OPEN candidates for it:
`PC-S297-LOCKED-ANCHOR-BYTE-MATCH-IGNORES-THE-ANCHOR`, `-VALIDATOR-VACUOUS`,
`-EXEMPTED-BY-SILENCE`. Because the mechanical citation check clears on line position, the
adversary had to verify citations **by hand, eight times**.

### Do the four staged releases fix any of this? NO.

Checked one by one, and the honest answer is none of them touch it:

| release | bearing on this stall |
|---|---|
| v0.275.0, v0.278.0 | pull-time layer tooling — zero effect on sprint execution |
| v0.276.0 | Check 7 non-vacuity ADDS a gate assertion; carry-over item 5 is the bug-variant boundary; `dev.md` is a launch bullet |
| v0.277.0 | closest is pm.md's probabilistic-AC rule, but p1's findings were citation accuracy and Rule 26 waiver suppressors — not probabilistic ACs |

### The shell-idiom family IS in this sprint — in the derivations, not the scripts

Operator correction, checked and confirmed. A first probe over graph's **committed shell**
found almost nothing: 183 consumer-owned files, 2 benign bracket-class hits, and **zero files
even enable `pipefail`**, so the I54/I54b precondition never applies. That result is real and
it is also the wrong corpus.

**PARTLY REFUTED by v0.285.0's measurement — read §*What v0.285.0 measured about the
count-assertion class* before acting on this section.** The corpus claim below is right: the
derivation commands sit in markdown prose, not in `*.sh`, and a shell-file linter would catch
none of it. The reading of the four quoted sites is wrong. **Three of the four are the discipline
WORKING**, not going wrong — they are the agent writing a control, or refusing to trust a grep,
and saying so. Only the fourth is an escape. The real class is an underived count in prose
asserting facts outside the criterion's own test, which is a wider target than a shell idiom.

The defects live in the **derivation commands the agents run and cite**, which sit in markdown
prose, not in `*.sh`. In the s301 record: `grep -c` appears 214 times, `sed` 428, `wc -l` 85,
`awk` 45:

- `s301-epics-repair-p5d.md:115` — *"BSD `grep` has no `-P`; the first attempt at this
  enumeration returned a vacuous `0`"*
- `s301-stories-adversarial-p6.md:252` — *"not by the label grep whose zero could not be told
  from a vacuous pattern"*
- `s301-stories-repair-p5.md:581` — *"the grep would have produced a false finding. This is the
  same silent-zero shape…"*
- `s301-stories-adversarial-p2.md:327` — a confirming grep *"scoped to the wrong file"*

**This changes what v0.280.0 should be, and the fresh session must not build the version
described in the session transcript.** A shell-idiom validator over `*.sh` would have caught
**none** of the above, because none of it is in a shell file. Every count and range citation in
a story is produced by one of these commands; a vacuous grep yields a false number, the number
becomes an AC, and the adversary then spends a pass falsifying it. That is the same loop as the
citation drift — one layer earlier.

The consumer already has the right rule and no enforcer: `SKILL-domain.md` Rule 930 says *"Pair
every count with a control that proves the pattern CAN match. `grep -c` counts LINES, not
entries… a bare count is indistinguishable from having examined nothing."* Unabsorbed, and
unenforced on either side.

**The real next work, in priority order:**

1. **Fix `validate-locked-anchor.sh`** (three OPEN candidates above) — anchor-scoped matching
   instead of line-position, non-vacuous claim counting, and no pass-by-silence on a
   zero-bullet block. This is the mechanism whose absence cost eight hand passes.
2. **Make the STALL rung reachable mid-cycle** — a rung that only speaks after the cycle ends
   is a rung nobody hears. Either the story-validation loop runs the validator every pass, or
   the step file mandates it at pass 3+.
3. Discharge the p2→p3 `--transcript` resolution violation.

---

## Context

`/Users/n8/git/graph` is the reference consumer of this distribution. It carries **11
overrides** and **38 extensions** in `.claude/skills/ai-dlc/{overrides,extensions}/`. Every
one of those is a divergence core has to be pulled through by hand on every release, and an
override freezes its *entire shadowed span* at `base_sha` — so unrelated core fixes stop
reaching the consumer. That failure is already documented: v0.268.0's Check 14 fix never
reached graph because an override shadowed the whole check.

The question asked was what to bring upstream so those entries can be retired. Reading the
drift detection produced a harder answer first: **the detector that is supposed to report
retirements is structurally unable to see most of them, and core has no way to say "I
absorbed your prose."** Both were measured, not inferred. Until they are fixed, absorbing
prose upstream retires nothing, because nothing tells the consumer it happened.

So this plan ships the enablers first, then the absorptions that are cheap and unambiguous,
and ends with a verification that the next `/ai-dlc-update` on graph *actually* surfaces the
retirements — run against a scratch copy of the real consumer, not predicted.

### What the drift detection currently reports

`_bmad-output/ai-dlc-update/reconcile-report.md` at 0.273.0 → 0.274.0: 0 HARD blockers,
**1** `EXTENSION-RESTATES-CORE`, 2 `OVERRIDE-DELEGATES-INTO-SHADOW`, 2
`OVERRIDE-DOUBLE-SHADOW`, 1 `OVERRIDE-ASSERTS-SHADOW-SURVIVES`. Layer debt: OPEN 0,
UNDECLARED 6. The register holds 61 rows — 58 `still-additive`, 3 `contradicts-core`,
**0 `retire`**. In the register's whole history the pull has never once said "retire this."

### Blocker 1 — the absorption detector is blind to 27 of 38 extension entries (MEASURED)

`core/skills/ai-dlc-update/reconcile/layer-drift.sh:879` gates the entire absorption pass on
`[ -n "$ext_anchors" ]`, and `anchors_of_file()` (`:470`) harvests only headings matching
`ANCHOR_RE` (`:441`) — which requires a leading integer or a short uppercase id — plus
`bold_anchors_of_file()`, whose awk requires `^\*\*(Check[ \t]+)?[0-9]+`. An entry whose
headings are prose produces zero anchors, and the block is skipped entirely.

I ran the shipping functions verbatim against graph's 38 entries:

```
VISIBLE(has>=1 anchor)=11  BLIND(zero anchors)=27  TOTAL=38
CONTROL: same function on core/skills/ai-dlc/steps/gate-validation.md -> 42 anchors
```

The control is non-zero, so the harvester works; the 27 is a real absence. **Every one of the
8 role entries and every `SKILL-*` entry is blind.** This matches the consumer's own filing,
`PC-S316-ABSORPTION-DETECTOR-JOINS-ONLY-ON-NUMBERED-ANCHORS` ("both duplications found this
pull were found by hand"). At least four already-absorbed entries sit unreported behind it.

### Blocker 2 — core cannot declare "I absorbed your prose" (MEASURED)

`override_supersessions:` (`core/skills/ai-dlc/layer-contract.yaml:281`) is the one mechanism
by which core says an override is no longer NEEDED. It works — the v0.271.0/0.272.0 arc used
it, and graph's Check 14 override is gone as a result. But:

- `layer-drift.sh:648` — `[ -n "$sup_env" ] && emit OVERRIDE-SUPERSEDED ...`. Emission is
  gated on `settings_env_key`. A supersession that needs **no configuration** — core simply
  adopted the clause — can never fire.
- `supersessions_of()` (`:262-278`) already emits a TSV row with an empty env field, and
  `apply.sh:319-325` already has the else-branch that renders the single-row worklist item
  (`env_key=""` → `"core supersedes this entry: $detail"`). **Both ends already work. Only
  the one-line guard blocks it.**
- One `settings_env_key` per row, so a supersession needing two keys (Rule 8's two path
  lists) cannot be expressed.

Consequence: the cheapest, safest retirement class — "core took your paragraph verbatim" —
is currently *undeclarable*. It gates at least three of the eleven overrides.

### Third finding, which drives the release shape

`self-update-gate.sh` runs each incoming script the consumer's `.githooks/pre-push` invokes,
twice, and returns `SELF-UPDATE-DEFER` if the incoming one finds something new. On DEFER the
machinery slice folds into the operator-gated apply at step 7 — which runs *after* step 3's
classify. So on a mixed release, the new detector does not classify that pull.

**Therefore R1 must be machinery-only.** `layer-drift.sh` is not invoked by graph's pre-push,
so a machinery-only R1 returns `SELF-UPDATE-OK`, lands autonomously, and SKILL.md step 2
re-invokes the skill on the fresh engine — the retirements surface in the same invocation.
Mixing a rulebook edit into R1 pushes them a whole pull later.

---

## Status

Superseded — see **RESUME HERE** at the top of this file, which is the single current record.

## Release sequence

House rules apply throughout (`CLAUDE.md`): one version per branch cut from `origin/main`;
subject + `VERSION` + CHANGELOG heading are one claim; every mutant is a copy guarded by
`cmp -s` with an unmutated control; every absence carries a control in the same invocation.

### R1 — the enablers (MACHINERY ONLY) — **SHIPPED as v0.275.0**

Landed larger than planned, in three ways worth carrying forward:

- The title match got its **own status**, `EXTENSION-TITLE-MATCHES-CORE` (LC-E19, WARN), rather
  than reusing `EXTENSION-RESTATES-CORE`. A prose heading is not an identity claim, so the
  stronger status would have told the operator to delete entries that were merely *naming* the
  core section they augment — 6 of the 20 first-contact rows were exactly that.
- **`contract_version` 14 → 15 happens here**, not in R2. R2 and later renumber accordingly.
- `apply.sh` gained an `extension-title-match` worklist arm. Ground truth caught this: the
  classifier emitted 12 rows and `apply` emitted none, so they were an instruction with no
  owner.

Measured false-positive set: 20 rows on first contact → 12 after three derived exclusions, and
all 12 hand-verified true. Six mutants, unmutated control 0/0. The original plan text follows.


`core/skills/ai-dlc-update/reconcile/layer-drift.sh`

1. **Env-keyless supersession.** Change the `:648` guard from `[ -n "$sup_env" ]` to fire
   whenever the row matched at all (`sup_since` is present on every row). When `sup_env` is
   empty, emit a detail string carrying **no** `replaces_with=` token, so `apply.sh`'s
   existing else-branch renders the single "core supersedes this entry" row rather than the
   two ATOMIC rows. Do not touch `apply.sh` — it already handles both shapes.
2. **Title-only absorption pass.** Add a second harvest beside `anchors_of_file()`: the
   normalized TEXT of every `##`/`###`/`####` heading that `ANCHOR_RE` did *not* claim. Run
   it through the existing `same_section()` Jaccard predicate against theirs' heading texts
   and emit only `EXTENSION-RESTATES-CORE` / `EXTENSION-RETIRE-CANDIDATE` — **never**
   `EXTENSION-CHECK-NUMBER-COLLISION`, which has no meaning without a number. Restrict the
   pass to headings; bold-prose anchors (`**Falsification ladder.**`) stay out of scope and
   are named as such in the header comment.
3. **Measure the false-positive set before shipping** (`CLAUDE.md`: "Before adding a check,
   measure its false-positive set"). Run the modified script against graph and enumerate
   every new row. The `:440` comment names the exact hazard — a heading called "Scope"
   diffing against unrelated core prose. If the set is not empty and enumerable, raise
   `same_section`'s floor for the unnumbered arm rather than shipping a noisy detector.

Both stay at their existing WARN levels (`LC-E5`, `LC-E6`, `LC-O15`). No blocking on first
contact; that promotion is R6.

Fixtures: extend `core/fixtures/layer-readopt-gate/run.sh` with an env-keyless supersession
arm, and add an unnumbered-heading absorption arm. Two mutants — revert the `:648` guard,
revert the title pass — each must fail **only** its own assertion.

### R2 — the three free retirements — **SHIPPED as v0.276.0 (#362). Do not redo.**

Each is a delta core should simply carry; none is graph-specific; each retires one override.

| core edit | retires |
|---|---|
| `steps/gate-validation.md` Check 7 — add the fourth bullet: an artifact-consistency pass over an EMPTY referenced set is not a pass. This is the non-vacuity discipline core already applies in Check 5 ("exit 4 … is never a pass") — a core-consistency gap, not a graph fact. | `overrides/steps__gate-validation__check-7.md` |
| `steps/carry-over-evaluation.md` item 5 — add the sprint-boundary clause: reaching PVC on the bug variant closes the interrupted sprint; carry-over evaluation re-enters fresh next sprint, not mid-stream. Zero graph vocabulary; the entry itself records "Removal condition: none anticipated." | `overrides/steps__carry-over-evaluation__item-5-bug-sprint-boundary.md` |
| `team-roles/dev.md` `## Identity` — delete the `Local (Ollama)` launch bullet. It **contradicts the two lines directly above it**, which say `aiDlcRoles.dev` "is the only source; do not infer either value from anywhere else." v0.175.0 moved model/effort into settings and left this orphan. | `team-roles__dev__identity.md` |

Plus three `override_supersessions:` rows with `since_core_version`, `reason`, `verify`, and
**no** `settings_env_key` — the shape R1 unblocked. Bump `contract_version` 14 → 15 (this is
`LC-C2`/`W6`, a WARN, so it will not wedge graph on contact).

### R3 — auto-handoff becomes configuration

`SKILL.md:506` currently reads "projects override the default in this section directly" —
core is *inviting* the shadow, and graph took the invitation for a value (`off`) that equals
core's own default. The entry says so: "operatively null today."

- Declare `AI_DLC_AUTO_HANDOFF_MODE` (`off|deploy-only|safe-seam`) and
  `AI_DLC_AUTO_HANDOFF_SEAMS_EXCLUDED`, read at `steps/_gate-procedures.md:397` (the actual
  reader — "Read `auto_handoff_mode` from SKILL.md Handoff…").
- Delete the invitation sentence at `SKILL.md:506`.
- Supersession row on `SKILL.md#Auto-handoff (configurable via auto_handoff_mode)`. Two keys
  are needed, so this release also carries the **multi-key** extension to
  `override_supersessions` (`settings_env_keys:` list; `supersessions_of` emits one row,
  `apply.sh` renders 1/N…N/N ATOMIC rows).

Retires `overrides/SKILL__auto_handoff_mode.md` — the cleanest v0.271.0-shaped retirement of
the eleven.

### R4 — the snapshot ceiling becomes a core verdict

`overrides/steps__retro__pipeline-snapshot-ceiling.md` restates **zero** core text; it exists
only because core's retro budget run is `--warn-only` and because arm (2) depends on core's
`6000`-token budget constant, which an extension (no `base_sha`) could not track.

- `core/scripts/validate-artifact-budget.sh`: add the supersession-marker arm for
  `pipeline-snapshot.md` scoped outside `## In-Flight Teammates`, and add `--fail-on
  <artifact>` so retro takes a hard verdict on one artifact while staying warn-only overall.
- Env-keyless supersession row.

This is the entry's own stated removal condition; the `base_sha` dependency then evaporates.

### R5 — the three role-file absorptions — **SHIPPED as v0.277.0 (#363). Do not redo.**

| core edit | retires |
|---|---|
| `team-roles/qa.md`, new `## Gate-2 Start Condition (HARD)` — gate-2 validation MUST NOT begin until the lead sends `gate-2 go-signal: <story-id> @ <SHA>`; task-graph completion is not approval. 17 lines, zero domain content. | `extensions/roles/qa-push.md` |
| `team-roles/pm.md` — probabilistic-AC tagging at story-creation ("unverifiable BY CONSTRUCTION, not merely unverified") and prior-artifact numeric anchors linked at authorship. Also discharges the OPEN ledger item `PC-S297-RETRO-UPSTREAM-PM-AC-PRECISION`. | `extensions/roles/pm-domain.md` (currently misfiled as `push_candidate: false`) |
| `team-roles/code-reviewer.md` — return-type / context-shape changes are **Critical**, never downgraded, with a mandatory Consumer Audit (grep every caller, log the command); unverified-API-field is **Important** with the 4-step Field Verification. Genericize the two graph function names. | `extensions/roles/code-reviewer-push.md` |

All three are currently invisible to the detector (roles carry no numbered headings), so R1 is
what makes their retirement reportable at all.

### R6 — promote the retirement signals to ADJUDICATED (gated on R1's measurement)

`LC-E6` (`EXTENSION-RETIRE-CANDIDATE`) and `LC-O15` (`OVERRIDE-SUPERSEDED`) are WARN. A WARN
reaches the report and the worklist but records no verdict, which is why the register holds
0 `retire` rows across 61 adjudications. Raising both to `ADJUDICATED` makes an unrecorded
retirement **block the apply** (`LC-A1`), which is what "surfaced *and* adjudicated" means.

Ship this only after R1's fired set has been measured on graph and is small enough not to
wedge first contact — core's own documented promotion path (`layer-contract.yaml:136-152`;
`LC-N5`'s warn-tier → `E15` at contract_version 8 is the worked example). If the set is
large, R6 splits: promote `LC-O15` first (bounded by the supersession list core controls),
leave `LC-E6` at WARN one release longer.

---

## Verification — ground truth, not a resolver dry-run

Per the standing rule, a read-only probe is not a consumer verification. For **every** release
above, before calling it done:

1. **Commit first.** An uncommitted edit is absent from `git diff BASE THEIRS`, so a delivery
   check on a dirty tree reports a false negative.
2. **Scratch consumer.** Copy graph's `.claude/ scripts/ tests/ .githooks/` into the
   scratchpad. Never write into `/Users/n8/git/graph`.
3. **Baseline with the OLD engine.** Run the scratch tree's *own installed*
   `reconcile/layer-drift.sh` (0.274.0) with `DIST=/Users/n8/git/ai-dlc`, `BASE=9036e0d`,
   `THEIRS=<new release>`. This is the control: it must **not** show the new rows. Without it
   you have shown that the new rows appear, not that the fix produced them.
4. **Run the real apply.** `reconcile/apply.sh <dist> <base> <scratch> <theirs>` from the
   scratch tree, then the consumer's fixture suite the way `.githooks/pre-push` drives it
   (`tests/fixtures/*/run.sh`, no positional args).
5. **Assert the named rows, per release.** R1: the enumerated new
   `EXTENSION-RESTATES-CORE`/`RETIRE-CANDIDATE` set, plus the FP count. R2–R5: exactly one
   `OVERRIDE-SUPERSEDED` per retired override, and an `override-retire` WORKLIST row from
   `apply.sh` for each. R6: `HARD-LAYER-ADJUDICATION-MISSING` on an unrecorded retirement,
   and clean once a `retire` row is written to the register.
6. **Two-repo layout.** Anything touching path resolution is re-verified on a tree built by
   running `scripts/install.sh` into an empty directory, not only in `core/` (invariant I33).
7. **Bootstrap limit, stated not implied.** The consumer runs its own installed engine. R1
   takes effect via the step-2 self-update + automatic re-invoke — but **only because R1 is
   machinery-only** and `self-update-gate.sh` therefore returns `SELF-UPDATE-OK`. If any
   rulebook file lands in R1, the gate defers and the fix classifies one pull later. Verify
   the gate's verdict explicitly; do not assume it.

Build-time, every release: `scripts/validate-enforcement-map.sh` (I36 both directions — a new
code must have a clause and a clause must have an emitter; I42 no clause above
`contract_version`; I63 `absorbed_from:` roles still hold), and
`scripts/validate-release-version.sh`.

---

## Deliberately out of scope, with the reason

Enumerated so the operator can scale the work up, not silently dropped.

**Needs machinery this plan does not build:**
- `overrides/SKILL__Rule-8.md` — the live delta is graph's service/infra path lists
  (`server/ rebalancer/ web/ subgraph/ infra/`). Needs `AI_DLC_SERVICE_PATHS` +
  `AI_DLC_INFRA_PATHS` read at `steps/route.md:351` where intensity is *assigned*. Note the
  entry's stated "three guarantees upstream lacks" are all in core Rule 8 verbatim today, and
  it freezes a paragraph core has since deleted — it is doing net harm, not net good.
- `overrides/steps__gate-validation__check-5.md` — needs a real corpus-glob leg in
  `sprint-status.sh check-stories` (fail closed when the story-file count disagrees with the
  yaml, and on frontmatter `sprint:` mismatch), plus `AI_DLC_CHECK5_EXTRA_VALIDATOR`.

**Genuinely domain-local, do not absorb:**
- `team-roles__tea__consumer-drift.md` — graph's TEA owns test strategy; core's TEA is a
  party-mode advisory lens. Core cannot adopt ownership without breaking every unlayered
  consumer. Worth *narrowing* (drop `#Identity` and `#Escalation` from `shadows:` — both are
  core text verbatim), not retiring.
- `steps__retro__domain-sections.md` — 4 anchors, 608 lines. §3's only delta is the
  finding-class taxonomy citation (an `AI_DLC_FINDING_CLASS_EXTRA` candidate); §5's Stop-hook
  rationale is general; §4a and §7 are genuinely graph-local. It should be **split**, not
  retired.
- `steps__retro__ci-gates-enforcement-surface.md` — core has partly caught up; the residue is
  graph's disabled-GHA operational state and belongs in `extensions/`, not a shadow.

**Large generalizable backlog, already located:** SKILL.md Rules 929/930/931/932 and the
party-mode inline-relay clause; `retro-deferral-expiry` (three fully general rules, misfiled
as domain); the bug-investigation adversarial-verify pass; `attribution-provenance` and
`validator-honesty` as new gate checks. Roughly 57 upstream-facing items are already OPEN in
graph's `push-candidate-ledger.md` — the largest single cluster (5) is defects in
`ledger-reverify.sh` itself, the tool that closes that ledger.

**One consistency gap worth a one-line release:** `known-skills.json` has
`AI_DLC_KNOWN_SKILLS_EXT`; `protected-paths.json` has no equivalent and hardcodes its path at
`core/hooks/ai-dlc-protect.sh:132`. Both JSON extensions are permanent by design and retire
nothing — this just closes the asymmetry.
