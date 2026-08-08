# Retire graph's consumer layer by absorbing upstream into core

---

# RESUME HERE — state as of 2026-08-06

## Start here

**This file is the plan of record. Everything above `## Context` is current; everything below
it is the original design record, kept for rationale. Where they disagree, the top wins.**

**CITATIONS BELOW `## Context` ARE HISTORICAL AND SOME NO LONGER RESOLVE TO THEIR SUBJECT.**
They were written before the releases that shipped them, and the releases moved the lines.
Checked at handoff: `layer-drift.sh:648` was the env-key guard and is now other code (v0.275.0
changed it), and `SKILL.md:506` described the invitation sentence v0.282.0 deleted. Both sit in
sections marked SHIPPED, so they are records of why a thing was done, not instructions. Every
`path:line` ABOVE `## Context` was re-checked at handoff: **26 citations into THIS repo, 0 past
end-of-file.** Four more point into the CONSUMER — `s301-stories-adversarial-p2.md:327`,
`s301-epics-repair-p5d.md:115`, `s301-stories-adversarial-p6.md:252`,
`s301-stories-repair-p5.md:581` — and **the s301 close-out archived all four**, so they now live
under `_bmad-output/planning-artifacts/archive/s301-<series>/` rather than at the paths quoted.
The content is unchanged (the archive was `git mv` with per-file sha verification); only the
prefix moved. Re-verify any citation
below it against the tree before acting on it.

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

**NOTHING IS IN FLIGHT. No branch is parked.** ai-dlc `main` is at **`0.305.0`**, working tree
clean, and every release this plan produced is merged — the table under §*Where things stand*
lists all eighteen with their PR numbers. The previously-parked F3 branch shipped after two
renumbers (0.288.0 → 0.289.0 → its final slot) once item 11 unblocked it.

**~~graph is at `0.292.0 / c5e7daa` and is QUIESCENT.~~ ~~NO LONGER TRUE — 8b IS IN FLIGHT.~~
~~8b IS DONE. graph is at `0.300.0 / 2bc7aa4`~~ **SUPERSEDED — graph is at `0.314.0 / f9b8aa4`**
on all four stamp fields, on `main`, migrated, gates green. Two hops (#882 self-update, #883
hop-1, #884 hop-2 + the 951-move story migration). VERIFIED FROM THIS SIDE, not taken on the
report: `layer-drift.sh` over `2bc7aa4..f9b8aa4` against graph returns **0 `HARD-*`** with 49
rows across 9 statuses and no `DRIFT-RANGE-DEGENERATE` — so the zero is a real absence, not a
disarmed run.**
s301 is closed; s302 has not started but MAY now start.

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

**The next pull is small and clean, measured: 4 files, ZERO rulebook files (so one hop), and
0 `HARD-*` rows over `f9b8aa4..HEAD`.** It carries v0.315.0, which is where item 20's fix
gets verified by running that fixture from graph's own `tests/fixtures/`.

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

**NEXT ACTION FOR THIS REPO: item 19** — review graph's recent artifact-consolidation attempts.
Operator request, 2026-08-08. Item 12 remains available and gates nothing. **Item 19 is read-only
and historical, so it works either side of the pull; prefer AFTER**, so the review reports against
the engine graph will actually run.

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

## Session handoff — 2026-08-07, written because context depth was becoming the risk

**Nothing is in flight. The tree is clean, `main` is at `0.300.0` + #413, and every branch this
session cut is merged and deleted.** A fresh session starts from `origin/main` with nothing parked.

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
| **15** | **19** — review graph's artifact consolidation | **← THE NEXT ITEM.** Operator request 2026-08-08. Read-only against the consumer; nothing in this repo gates it |
| ~~—~~ | ~~**13**~~ | **DONE** — v0.303.0 (#418). Taken ahead of 6 because 6's gate needs a consumer measurement and graph is mid-pull |
| — | **12** | does not gate anything; take it when convenient. Needs the declared consumer-settable tunables derived first |
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

19. **Review graph's recent attempts at artifact consolidation, and decide whether the process
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

21. **`apply.sh` overwrites itself mid-run.** **REPORTED BY THE CONSUMER 2026-08-08 with receipts,
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

**ai-dlc is at `0.310.0`, `contract_version` 16.** Every release below is merged to `main`. The count in this sentence used to be hand-written and went stale three times; it is now stated as "every row below" so the table is the only thing to keep current:

| release | PR | what it does |
|---|---|---|
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

## Item 11 — the self-update gate compares two usage errors

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

## Item 14 — the dependency map, scoped

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

## Item 10 — the artifact path convention

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

## The one thing that must not be forgotten: pull graph in TWO hops

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

## Still open

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

## Open thread at the end of the session

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
