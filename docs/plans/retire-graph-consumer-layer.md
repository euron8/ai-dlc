# Retire graph's consumer layer by absorbing upstream into core — DISCHARGED 2026-08-10, DO NOT EXECUTE

**Archived sections live at `docs/plans/archive/retire-graph-consumer-layer.md`** — rotated by `scripts/plan-rotate.sh`, original lines 697..5059. It is a RECORD, not an instruction: read it for the evidence behind a figure, never for something to do.

**THIS PLAN IS SPENT AND NOTHING IN IT IS AN INSTRUCTION TO ANYONE.** R1 through R6 all shipped,
the final pull ran and merged, and the consumer is current. Read the whole file as a record.

**THE CLOSING MEASUREMENT, taken 2026-08-10 rather than carried.** Graph reads `0.347.0 / 611bbe2`
on all four stamp fields (`sed -n '1,4p' /Users/n8/git/graph/.claude/.ai-dlc-version`), which is
this repo's `HEAD`, and the range's one shipped file, `core/git-hooks/pre-push`, is byte-identical
to the distribution — `cmp -s`, with a control that an unrelated pair reports DIFF. Working tree
clean, `main` == `origin/main`.

## What is LIVE in this spent record

This plan is discharged and instructs nobody; it is kept as a record. Two sections stay in the
file itself because a reader arriving here needs them before anything else. Everything else is
evidence and lives in the archive named by the pointer at the top of this file.

1. `## What it set out to do, and what it actually delivered` — the outcome
2. `## Start here` — the read/write boundary, which still binds anyone reading the evidence

Anyone acting on anything here should ping the operator first: this is a record of work that
already shipped, so a question about it is a question about a decision someone else made.

## What it set out to do, and what it actually delivered

**BOTH BLOCKERS — the things the plan said had to come first — ARE FIXED AND LIVE IN CORE.** The
absorption detector was blind to 27 of 38 extension entries because the whole pass was gated on
numbered anchors; the title-only harvest R1 specified is `unnumbered_titles_of_file()` in
`core/skills/ai-dlc-update/reconcile/layer-drift.sh`. Core's inability to say "I absorbed your
prose" without a `settings_env_key` is gone: `core/skills/ai-dlc/layer-contract.yaml` carries **7**
`override_supersessions` rows today, against a control of 0 for a fabricated key.

**ALL SIX RELEASES LANDED.** R1 v0.275.0 · R2 v0.276.0 (#362) · R5 v0.277.0 (#363) ·
R4 v0.281.0 (#369) · R3 v0.282.0 (#370) · R6 across v0.311.0–v0.314.0 (#434–#437). R6's promotion
is verifiable in the shipped contract rather than from this sentence: `LC-O15` and `LC-E6` both read
`level: ADJUDICATED`, and the control that the read distinguishes tiers is `LC-E19`, still `WARN`.

**THE PLAN'S OWN HEADLINE METRIC MOVED, ON THE REAL CONSUMER, NOT IN A DRY RUN.** §*Context* below
recorded 61 register rows and *"in the register's whole history the pull has never once said
'retire this.'"* Graph's `_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl` today holds
**146 rows: 138 `still-additive`, 7 `contradicts-core`, 1 `retire`** (control: a fabricated key
returns 0). The `retire` row is `LC-E4` on `extensions/roles/qa-push.md`, recorded
2026-08-07 — *"Fully absorbed… Nothing in the entry survives core."* The entry is gone from their
tree. That is R5's absorption producing the sequence's designed end state through the pull itself.

**THE LAYER SHRANK BY EXACTLY WHAT WAS SCOPED, AND THE BASELINE IS DERIVED FROM GRAPH'S OWN STAMP
HISTORY RATHER THAN FROM THIS FILE'S PROSE.** At the two commits whose stamp reads `0.274.0` — the
version §*Context* measures — graph carried **12 override files and 39 extension `.md` files**.
Today: **7 and 38**. The five overrides gone are R2's three, R3's `SKILL__auto_handoff_mode.md` and
R4's `steps__retro__pipeline-snapshot-ceiling.md`, each verified absent; the one extension gone is
`qa-push.md`. **This file's own `11 overrides / 38 extensions` is an entry count, not a file count,
and the two were never reconciled** — which is why the delta above is stated against a re-derived
baseline.

### Where it fell short of its own text, stated plainly

**R5 PROMISED THREE EXTENSION RETIREMENTS AND PRODUCED ONE.** `extensions/roles/pm-domain.md` and
`extensions/roles/code-reviewer-push.md` are still on their tree, both adjudicated
`still-additive`, with register reasons reading *"Debt discharged. The absorbed section was removed
from the entry and a dated RETIRED/TRIMMED comment left in it."* Core's absorption worked and the
entries were TRIMMED to their un-absorbed residue, which is the correct outcome for prose that is
partly domain-local — but it is not what R5's table claims, and the table was never corrected.

**"RETIRE GRAPH'S CONSUMER LAYER" WAS NEVER THE SCOPE, AND THE TITLE OUTRAN THE PLAN FOR ITS WHOLE
LIFE.** 45 entries remain. Every survivor this file names — `overrides/SKILL__Rule-8.md`,
`overrides/steps__gate-validation__check-5.md`, `team-roles__tea__consumer-drift.md`,
`steps__retro__domain-sections.md` — sits in §*Deliberately out of scope, with the reason* with a
stated reason, and all four are still there, unchanged, by design. Judged against R1–R6 the plan is
complete; judged against its title it retired 6 of 51 entries.

### What the file became, which is the durable lesson

**73 releases carry a CHANGELOG heading in `0.275.0`–`0.347.0`** (control: 0 above `0.347.0`), and
the R1–R6 sequence accounts for **nine** of them — one each for R1, R2, R3, R4 and R5, and four for
R6. By this file's own repeated record, the last nine-odd items entered through the consumer's
completion report rather than off its numbered list, and the final two came from the operator
against this repo's own machinery. **It stopped being a retirement plan long before it stopped being
edited, and ran on as a distribution↔consumer channel inside a five-thousand-line file whose live
content was one status block.** A channel does not need a plan; the next item that arrives gets a
fresh, short file of its own.

**NO PLAN IN `docs/plans/` IS LIVE AS OF THIS DISCHARGE.** Every file there, including this one, is
a record.

---

# SPENT — RESUME HERE, the handoff state as of 2026-08-08

**SUPERSEDED BY THE DISCHARGE BANNER ABOVE. Nothing below is live.** Kept because it records the
boundaries the work ran under and six measurement errors that are worth reading.

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

**~~FRESH SESSION: your entry point is §*THE NEXT ACTION*.~~ THERE IS NO ENTRY POINT ANY MORE —
THE FILE IS DISCHARGED and that section is now §*SPENT — THE NEXT ACTION LIST*.** Read this section
for the boundaries and the standing operator decisions the work ran under; nothing in this file is
an instruction to you.

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

**~~WHICH PLANS IN `docs/plans/` ARE LIVE: THIS ONE, AND ONLY THIS ONE.~~ NONE ARE, AS OF THE
2026-08-10 DISCHARGE — this file was the last one and its banner is at the top.** Every other file
there was already a DISCHARGED runbook and each says so in its own title. They were all titled
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

**~~AND TWO MORE RELEASES HAVE LANDED SINCE, SO A PULL IS OWED AGAIN — ONE FILE.~~ THE OPERATOR
TOOK IT 2026-08-10 AND IT IS THE LAST PULL THIS PLAN OWED.** v0.346.0 (#510) and v0.347.0 (#512),
neither of which came from this list. Derived against `959caa8` at the time: **1** shipped `core/`
path, `core/git-hooks/pre-push`, against a control of 8 non-core changes that ship nothing. It went
without a runbook, which was the operator's call. **Verified from this side rather than accepted:**
all four stamp fields read `0.347.0 / 611bbe2` and that one file is byte-identical to the
distribution, with a control that an unrelated pair reports DIFF.

**IT IS ONE FILE AND IT IS NOT COSMETIC, WHICH IS THE ONLY REASON IT IS WORTH NAMING.** That path
is the consumer's OWN fixture-suite runner, and v0.347.0 changed how it decides which fixtures a
change selects: it now resolves `suite-content-key.sh`'s exclusion set instead of applying none.
**On a consumer that script does not exist, so the set resolves EMPTY and their behaviour is
unchanged by construction** — expect the code to move and the run not to. Do not read an unchanged
run as a failed pull.

**WHAT THOSE TWO RELEASES WERE ABOUT, because both were raised by the operator against this
repo's own machinery rather than by a consumer report.** v0.346.0: `CLAUDE.md` sat inside the
fixture suite's content key while no fixture's verdict depended on it — it is in exactly one
fixture's read-set, and that fixture copies every tracked file. v0.347.0: the suite is POLE-BOUND,
and an invariant added in v0.345.0 put 39% onto a validator the sharded batteries re-run about
thirty times each, taking the pole from 442s to 595s. Both are recorded in `CHANGELOG.md`; the
durable lessons are in `CLAUDE.md`'s fixture-suite section.

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

