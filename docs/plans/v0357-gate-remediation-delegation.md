# v0.357.0 — the gate remediation loop repairs inline, counts nothing, and sweeps by memory

---
## Start here

## ✅ DISCHARGED — SPENT. Do NOT execute this file.

**Everything below is a record, with ONE exception named in `## Open candidate` immediately after
this section.** Apart from that one item, nothing here is an instruction to a later session. The release
shipped, the consumer pull completed, and the consumer is now at **0.360.0** — three releases past
the one this plan delivers. The `⛔ FIRST ACTION` block that stood here told a resuming session to
message a live consumer session mid-apply and to touch nothing until it replied; that session
finished its work and is gone, so following it would have produced a message to nobody and a wait
with no end. It is deleted rather than annotated, because a spent instruction reads exactly like a
live one.

**What discharged it.**

- **0.357.0** merged as PR #534: remediation dispatched rather than applied inline, the K=3 stall
  rung, the derived fan-out worklist, the self-execution waiver window tightened.
- **The consumer pull ran to completion.** `ab898a6ba` carried the pull, `c634c49b3` the s302
  `[story]` gate reset, both merged to the sprint branch. Full account in
  `docs/plans/graph-pull-0356-to-0357.md` `## Discharge`, which is also spent.
- **The gate was reset and deliberately NOT re-run.** The operator separated the pipeline resume
  from this plan. So **Verification item 8 — the end-to-end test of the stall rung — was never
  performed and is not owed by this plan.** It happens whenever the pipeline resumes. Do not read
  this plan's completion as evidence the rung fired correctly in production; it has not yet been
  exercised live.

**Three follow-on releases came out of executing it, each found by the one before:**

- **0.358.0** — the smoke-failure protocol triaged deployment-vs-code and routed both answers to
  the dev seat. New `ops` seat. *Getting the delegation right is not the same as getting the
  delegatee right.*
- **0.359.0** — `retired-layer-contract.sh` exited before opening a file and said nothing, output
  byte-identical to a full scan. Both quiet paths now qualify their zero. Its fixture arm had been
  certifying the silence from a branch it never tested.
- **0.360.0** — the class that zero excluded: a layer file reproducing a core line core has
  deleted. New `reconcile/retired-layer-passage.sh`, false-positive set measured empty across 20
  release pairs.

## Open candidate — available for a future session, owed by nobody

**This is the one live item on this page.** It is a CANDIDATE, not committed work: it may be
picked up, re-scoped, or dropped on measurement. Nothing about this plan's discharge depends on it.

**A `validate-plan-shape.sh` arm requiring every `## Rehearsal` finding to name the step its fix
landed in, or declare itself a record.**

*The evidence it rests on, measured on this plan's own consumer runbook.* Findings that ended
"now written into step X itself" were the ones actually repaired. Findings that did not were,
exactly, the ones still live and blocking when a cold reader found them. **That single difference
predicted the defect set.** A rehearsal that records a finding without landing it produces a
document whose §Rehearsal reads as evidence of repair while the steps still carry the defect.

*What a future session must do FIRST, and the reason it is not already built.* Per `CLAUDE.md`,
measure the false-positive set over `docs/plans/*.md` and ship only if it is empty or enumerated.
An unmeasured lint is one the operator turns off. **That order is not ceremony — it decided the
outcome twice in the session that discharged this plan:** a dormant-role guard was measured, found
to be reading the wrong signal (a name scan scored `ops` at 3 when only 1 was a dispatch), and
NOT shipped; a passage-level detector was measured across 20 release pairs, came back with an
empty false-positive set, and shipped as 0.360.0. Same discipline, opposite answers.

*A second arm, same family, weaker evidence.* `validate-plan-shape.sh`'s P4 checks that a
`path:line` resolves NUMERICALLY, not that the content at that line matches — so it cannot see a
stale citation, and saw none of the staleness defects this program produced. Claims of the form
"`main` carries X", "ref Y exists", "sha Z is reachable" are mechanically checkable against the
actual repo. Treat as a separate candidate with its own measurement; do not fold it in.

*Known false-positive sources to look for before believing an empty set.* A §Rehearsal that is
deliberately a record of a run rather than a defect list; a finding whose fix landed in a
different file than a step; a finding correctly dispositioned as "no change needed". Each needs a
declared form, and per this repo's history a declared exemption is itself a defect worth counting.

Fuller framing, including the arm this supersedes, is in **BOOKED item 3** below — which is
history, where this section is the live pointer.

### The two repos

**Distribution — `/Users/n8/git/ai-dlc`, the tree this plan WRITES.** `main` is clean, pushed and
green; v0.357.0 merged as PR #534.

**Consumer — `/Users/n8/git/graph`. NEVER WRITE IT.** A live consumer, mid-sprint, whose baseline
for this work is `0fd25d10d`. Read it only. Its modified `_bmad-output/` files are expected and are
not yours to tidy. Every bare `architecture.md:` or `pending.md:` citation below is a path in THAT
tree, not this one.

**Ping the operator** on any question, on any decision this file does not settle, and on completion
including an early stop.

### How to work here

Read `CLAUDE.md` — it is the rulebook for this repo and it is not restated here. The discipline it
carries that this release kept paying for: a zero is not a finding, so carry a control in the same
invocation; prove a new check can fire; run the fixture suite the way the hook runs it (`git push`),
never a hand-rolled loop.

**The lead delegates.** That is this release's subject and the prior lead violated it repeatedly
after building the mechanism against it. Where a contract clause with an enforcer decides a
question, follow the clause and name it; where nothing decides it, ping the operator rather than
picking. When a boundary is stated and the next step feels small and obviously correct, that is the
drift, not an exception.

## THE THEME — deny the act, never judge the reason

Every mechanism in this release denies an ACT rather than evaluating a REASON. That is not a
stylistic preference; it is the only design that survives contact with an agent holding good
reasoning. **The session that wrote this release demonstrated it.** The lead built the deny hook,
could recite the rule, agreed to a stop boundary out loud — and crossed it six times in the next
hour, each crossing individually defensible (a false claim in a runbook is a correctness fix; a
validator failing on a citation you just introduced is not new work). Same shape as the
`DECIDED_AUTONOMOUSLY` corpus: 43% outside their own rule's definition, none written by someone who
thought they were cheating.

What follows, and what does NOT survive assuming good reasoning is available:
- **A0 denies the call and never reads the justification.** A detector would have found all six sound.
- **Non-self-dischargeable is the load-bearing property**, not a nicety. A well-formed rationale
  offered as a release condition clears the guard every time.
- **The remedy was one turn away and went unused.** This release ships P3b — an operator-ping
  requirement, mechanised in `validate-plan-shape.sh` — obliging an executor to ping on any decision
  its file does not settle. The lead wrote it, enforced it, and did not apply it to its own decision.

**The rule you are most confident about is the one you are least able to follow unaided.**

## ✅ DISCHARGED — the rehearsal found two regressions THIS RELEASE introduced, and a second rehearsal proved them gone

Both sat in the distribution's own `core/`, not in the merge, so a consumer could not have fixed
them and the pull broke their pre-push suite. Fixed on this branch in `a5b041f` — *"fix: the two
regressions this release introduced, found by rehearsing its own runbook"*. **The findings stay
recorded below, because the differential IS the evidence the fix is real**: a later reader needs
to know what was wrong and how it was proven gone, not merely that something was repaired.

1. **`story-fields-derive` PASS → FAIL**, fixture byte-identical across the pull. The pull had put
   the writing form `scripts/ai-dlc/sprint-status.sh derive-stories` into
   `core/skills/ai-dlc/steps/gate-validation.md` — the exact string that fixture's control arm
   exists to catch — introduced by this release's own Check 5 adjudication.
   **The instruction was REMOVED, not reworded.** What stands in that passage now is the
   read-only form `scripts/ai-dlc/sprint-status.sh derive-stories --check`, at
   `core/skills/ai-dlc/steps/gate-validation.md:485`, and it is the only
   `sprint-status.sh derive-stories` occurrence left in the file.
   **Proven gone:** PASS in BOTH clones, exit 0, with the fixture's own `run.sh` byte-identical
   across the pull, so the arm was not weakened into agreement. Mutation probe: appending the
   bare writing form drove it back to FAIL; restoring returned PASS.
2. **`audit-rule-files.sh --fail-on=deterministic` 0 → 1 tier-1 finding** — an `ORIGIN_TAG` in
   prose in `core/skills/ai-dlc-update/SKILL.md`, shipped by this release.
   **The finding was 2 on the distribution, not 1.** The second was `CLAUDE.md` itself, tagged by
   the tip docs commit, and a consumer-side rehearsal structurally could not see it: a consumer's
   `CLAUDE.md` is template-derived and sits outside that corpus.
   **The two needed OPPOSITE treatments.** `CLAUDE.md`'s tag was the measurement's own
   coordinates, so only the tag form went and the measurement stayed. The update skill's was a
   duration-of-defect provenance clause whose coordinates were already given a sentence earlier,
   so the whole clause went — de-v-ing that second one would have cleared the regex and left the
   violation standing.
   **Proven gone:** exit 0 and `tier-1 findings: 0` in BOTH clones, with the denominators
   MATCHING at `107 files scanned` / `78 skill files searched` — equal denominators are what say
   the two runs looked at the same corpus rather than one of them looking at less.

**The second rehearsal, against a pristine un-pulled control clone.** Full consumer pre-push
suite: pulled **148 ok / 0 FAIL, exit 0**; control **144 ok / 0 FAIL, exit 0**. The delta is
exactly the four fixtures the pull ADDS — `gate-remediation-deny`, `gate-repair-record`,
`gate-series-rung`, `hook-registration-join` — and none removed. Nothing was written to
`/Users/n8/git/graph`: `HEAD` `0fd25d10d` and the same four modified `_bmad-output/` files at
start and at end.

**Branch state:** `feat/v0.357.0-gate-remediation-delegation`, cut from `origin/main`
(`d2378b4`). Committed, **NOT pushed, NOT merged.** Refer to the BRANCH, never to a sha list —
commits are still landing on it and any list written here goes stale immediately. Release triple
validates: subject + `VERSION` 0.357.0 + CHANGELOG heading agree, one release in range, no
unpushed main commits inherited.

**Verified green on the COMMITTED tree** (`git archive HEAD` into a temp dir, not the working
tree): `validate-enforcement-map.sh` exit 0 / 0 FAILs · `validate-gate-manifest.sh` 44/44 ·
`validate-plan-shape.sh` · `validate-claude-rules.sh` · `validate-release-version.sh` ·
`validate-hook-registration.sh` · `sync-taught-schema.sh --check` (proven able to fire) · all
new fixtures: `gate-remediation-deny` 37 arms, `gate-repair-record` 8 arms, `gate-series-rung`.

**Known-failing and PRE-EXISTING, controlled against `origin/main` — do NOT "fix":**
`validate-artifact-paths.sh` exit 1, 2 blocking paths (identical on baseline). `I79:` is a
REPORT line, not a FAIL; it prints identically on baseline.

**Landed beyond the original plan** (all in the commit): I89 + I90 invariants · I57
case-blindness fix · `validate-hook-registration.sh` + a consumer pre-push arm ·
`enforcement-map.yaml` made YAML-parseable (baseline fails, branch parses) ·
`validate-cycle-commits.sh` non-vacuity arm · the self-execution waiver window tightened.

**DONE, all committed on this branch:**
- The runbook `docs/plans/graph-pull-0356-to-0357.md` is written, rehearsed against a
  `git clone --local` copy, corrected, and committed (plan-shape 0/0). Its `## Rehearsal`
  section carries all seven contradictions the rehearsal found.
- **Both blocking regressions fixed and re-rehearsed** — the record is the section above.
- **Done-when criteria 6 and 7 in the runbook corrected.** Criterion 6 had stated a
  DISTRIBUTION fact as a CONSUMER expectation, which no consumer executor could have satisfied.
- **Verification item 7 (E2's window fix, both arms) is covered.**
  `core/fixtures/story-corpus-sprint-slot/run.sh` carries arm A11 (a waiver naming the story
  still lifts) and arm A12 (a neighbouring entry's token does not), plus a mutant proving A12
  can fire: the fixture exits 0 and reports
  `MUTANT A12 (waiver window free to cross an entry boundary again) fails exactly A12`.
- Nothing was ever written to `/Users/n8/git/graph` — same four dirty files, same `HEAD`, at
  start and end of every rehearsal.

**SHIPPED.** Squash-merged to `main` as PR #534, pushed, `pre-push: all gates green` over 144
fixtures / 0 FAIL. The release triple validates on `main`. Everything in Deliverables A–E is in.

**A THIRD regression was caught at push time, after the two above.** `enforcement-map-sites-b`
blocked the push: this release widened I57's posture grammar to be case-tolerant
(`exits?` → `[Ee]xits?` at `scripts/validate-enforcement-map.sh`), and both of that fixture's
mutation probes still `sed`-matched the old lowercase-only literal, so neither mutation applied
and both arms reported `FIXTURE BROKEN` rather than passing. **The fixture refused to certify an
arm it could no longer apply, which is the only reason this surfaced** — the prior session had
verified the VALIDATOR at exit 0, and a passing validator is exactly what a dead probe looks like.
Control: the same shard on `origin/main` exited 0 with both arms `ok`, so it was introduced here.
Repaired by SHRINKING what each probe restates to `[ ]+required/`, which occurs exactly once in
the validator — minimal and unique, so future edits to the case class, quantifiers or digit class
cannot kill it again.

**All three regressions are ONE CLASS: this release moved a subject and left its checker anchored
to the old one.** After finding two, expect the third.

---

## LIVE NOW — the consumer pull, mid-apply. THIS IS THE ACTIVE WORK

**A `graph` consumer session is executing the runbook and has stopped for an adjudication.**
Its state as last reported:

- Branch `ai-dlc-update/0.357.0-reconcile-20260812T050626Z`, `START` = `0fd25d10d`.
  **Nothing committed, nothing pushed.**
- Dry run produced **18 HARD blockers**: 2 `HARD-OVERRIDE-DRIFT-SECTION`, 16
  `HARD-LAYER-ADJUDICATION-MISSING`. Both Class-A are resolved. **16 verdicts remain.**
- The second Class-A was adjudicated and CONFIRMED:
  `.claude/skills/ai-dlc/overrides/steps__retro__domain-sections.md`, anchor
  `#4a. Close-Out Sweep`. The consumer body had replaced core's ERROR/WARN semantics paragraph
  with a stub deferring to core — but the entry `shadows:` that span, so precedence deletes the
  text the stub defers to. Resolution: take core's paragraph plus the new `inline-ok` marker,
  keeping the three consumer-only paragraphs. **Decided by mechanism, not taste** —
  `layer-contract.yaml:524-530` LC-O9 (*"an override's body does not delegate to a construct
  defined inside a section it shadows"*) and its sibling LC-O10 `OVERRIDE-ASSERTS-SHADOW-SURVIVES`
  (*"it tells the reader the text is still there"*); the stub tripped BOTH, and `layer-drift.sh`
  emitted both codes independently on this pull. The entry's own `reason:` history had the same
  class adjudicated wrong twice before.

**OPEN OBLIGATION from that adjudication, not yet confirmed done:** the resolution puts a third
consumer copy of core text into that entry, and it will not track upstream. The consumer session
was asked to record it in the entry's `reason:` beside the existing `## Machine Audits` table and
§3 read-list notes. **An obligation nobody wrote down is one the next re-adoption cannot
discharge** — verify it landed.

**NEXT ACTION IS NOT YET DETERMINED AND MUST NOT BE GUESSED.** A further message from the consumer
session was in flight when this was written and has not been read. It will report the disposition
of the remaining 16 `HARD-LAYER-ADJUDICATION-MISSING` verdicts and whatever it hit doing them.
**Read that message first; it decides what happens next.** Do not resume the pull, do not
adjudicate a verdict, and do not touch the reconcile branch before reading it.

The standard given to that session, which still applies: where a contract clause with an enforcer
decides an adjudication, follow the clause and name it; where nothing decides it, ping the
operator rather than picking.

**The pull is NOT on the sprint branch and will not be until the operator approves the PR.** The
skill cuts a reconcile branch, commits there, pushes, opens a PR into the sprint branch, and
merges only on explicit operator approval — it does not auto-merge. Deliverable D4's gate reset
runs against the sprint branch, so it is gated behind that approval.

---

## THE CONSUMER RUNBOOK — rewritten, and the four defects that shaped it

`docs/plans/graph-pull-0356-to-0357.md` is the executable handoff. It went 679 → 183 → 224 lines.
**Do not re-add what was removed.** Each cut is a defect that had already fired:

1. **It described the pull step by step. Two thirds of it restated what the `ai-dlc-update` skill
   already owns** — resolving the ref, gating its own self-update, carrying the machinery slice,
   running the hook-registration check inside apply, emitting the worklist, printing the settings
   reconcile command. Nearly every blocking defect a cold read found lived in that duplicated
   half. The skill owns the pull; the runbook owns only what no skill does — the s302 gate reset.
2. **It hardcoded the distribution sha.** The apply stamps whatever the ref resolves to, so a
   docs commit to the runbook itself falsified its own acceptance criterion. **Name no ref and no
   sha**; the skill pulls latest and resolves the ref itself.
3. **It enumerated four dirty consumer files.** There were already six at handoff, and the set
   GROWS while the pipeline runs — putting a question to the operator writes one. Name the class
   (`_bmad-output/` is pipeline state), never the members or a count.
4. **Its §Abort claimed nothing commits, so `HEAD` stays at the handoff commit.** The skill
   commits. A bare `git checkout -- <path>` would have restored from the post-apply commit — a
   silent no-op with the shape of a successful recovery. Restores are anchored to `START`, which
   the executor records in step 1, and the file states that paths the apply CREATED cannot be
   restored that way at all.

**The rehearsals could not have caught most of this.** They tested whether the commands work; they
never read the document front to back as an executor would, and both blocking defects sat in steps
1 and 2 — the two steps neither rehearsal ever ran. A cold read by a session with no context found
them. **Cold-read a handoff before shipping it, separately from rehearsing its commands.**

**6 — THE PLAN-PROMOTION GUARD. CLOSED. Disposition: THE WARNING IS THE CEILING.**

   The defect it addresses: `.claude/rules/plan-shape.md` is scoped `paths: docs/plans/**` and
   assumes "work on a plan begins by reading `docs/plans/<slug>.md`, so the trigger fires."
   **False for a NEW plan** — plan mode authors into `~/.claude/plans/` and reads nothing under
   `docs/plans/`, so the rule telling you to promote a plan cannot load while you are writing
   one. `validate-plan-shape.sh` cannot cover it either: its corpus IS `docs/plans/*.md`, so an
   unpromoted plan is invisible and its clean run reads identically either way. Measured — this
   very plan carried four unresolvable citations and no read/write boundary for a whole session,
   and the validator found all five within a second of the file entering its corpus.

   What ships: a `PostToolUse` hook at `~/.claude/hooks/plan-outside-repo-warn.sh` in the
   OPERATOR's home, registered in the USER's `~/.claude/settings.json` — three arms tested
   (fires on `~/.claude/plans/*.md`, silent on a repo path, escalates its banner with the write
   count to defeat habituation) — plus the restatement in `CLAUDE.md` beside the fixture-ship
   trigger, which is the one place that loads unconditionally and survives compaction.

   **Both stronger forms were refuted by measurement, not deferred:**
   - *Ship it to consumers* — refuted. A consumer tree never gets `docs/plans/`, never gets a
     plan-shape validator, and is told nothing about promoting plans.
     `scripts/validate-plan-shape.sh` exists only in `scripts/`, which is distribution-only by
     construction, and `core/fixtures/plan-shape/.dist-only` already declares exactly this.
   - *Version the hook in this repo* — actively fenced out. `.gitignore:41` ignores `.claude/*`,
     and I88's A1 arm at `scripts/validate-claude-rules.sh:95` fails the push on any tracked path
     under `.claude/` that is not `.claude/rules/**/*.md`. It would also be covered by nothing:
     `validate-hook-registration.sh` SKIPs here (no `.claude/settings.json`), its glob is
     `ai-dlc-*.sh` anyway, this repo's pre-push never calls it, and no other gate reads that path.
   - *A blocking form* — there is no act to deny. Plan mode's harness requires the home path to
     exist, so a `PreToolUse` deny breaks plan mode. And no join exists to key a later check on:
     the home plans directory holds 60 files, `docs/plans/` holds 19, and the intersection of
     their filenames is ZERO, so which unpromoted plan was owed promotion is not derivable and a
     check keyed on it fires on all 60. Whether a plan is a handoff is INTENT, and the same write
     produces a handoff and a throwaway draft.

   The disposition is recorded where a prose rule with no enforcer has to live: `CLAUDE.md`, in
   the `.claude/rules/` section, under the heading **"THE WARNING IS THE CEILING"**. That is the
   authority; this entry is the pointer to it. **Do not re-open it here.**

**Hazards these sessions hit, for whoever resumes:**
- **NEVER write to `/Users/n8/git/graph`.** Live consumer, mid-sprint. Read it only. Its modified
  `_bmad-output/` files are expected and are not yours to tidy.
- **Do not `--amend` a release commit while agents still write.** Work landing inside the
  `git add` → `--amend` window vanishes with no error and no diff. Nothing was lost here; that
  was luck, verified after the fact against `HEAD` rather than the working tree.
- **Never put backticks in `git commit -m "..."`.** They RUN and silently delete the quoted text
  from the message — I85's exact defect. Use `-F -` with a quoted heredoc (`<<'MSG'`).
- **Do not `git add -A`** in this tree; it stages agents' scratch. Use explicit paths. A peer
  agent wrote into this tree mid-release; sample a file's mtime twice before committing anything
  you did not author.
- **This shell is zsh: `PIPESTATUS` is empty.** Capture exit codes as `cmd > log 2>&1; echo $?`.
  Piping a command whose exit code IS the answer — `git push | tail` — reported 0 on a FAILED
  push here. Read tracking state, not the pipeline's exit.
- **A control must be a string the target CERTAINLY contains.** Pairing a real pattern that
  returns 0 with a nonsense pattern that also returns 0 proves nothing; that happened here.
- **Agents idle or die without delivering** — three long-report agents did, one to a network
  outage. A silent agent and a passing agent are indistinguishable. Have them write findings to a
  file, and never read a missing report as a clean result.

**BOOKED — two defects found while discharging this release, deliberately NOT fixed here.** Both
are out of scope for this merge and neither blocks it. They are recorded so the next session
starts from the finding rather than re-discovering it:

1. **`core/skills/ai-dlc/rule-authoring.md:87` cites a prohibition the file never states.** It
   describes the tier-1 deterministic detector as mechanizing a *"version reference"* prohibition,
   but the file's own Style list at `:15-18` states only sprint/story references, incident
   narrative, parenthetical origin notes, and embedded dates — no version clause. The word appears
   exactly once in the file, at `:87` itself. **The enforcer is stricter than the rule it cites**,
   and ten live bare-number citations sit compliant-by-rule-text while being only accidentally
   safe from the regex. Fix the rule or narrow the detector; do not leave them disagreeing.
2. **`scripts/validate-claude-rules.sh:109` — a stale citation inside a LIVE error message.** A1's
   error string cites `.gitignore:19-24` as the narrowing it is protecting. Those lines are the
   `_bmad-output/` comment block. The actual `.claude/*` narrowing is `.gitignore:41-45`. An
   operator who follows the pointer the failure hands them lands on the wrong block.
3. **A candidate mechanism for the class this release kept producing — measure before shipping.**
   **SUPERSEDED AS A POINTER: the live home for this is `## Open candidate` near the top of this
   file.** What follows is the original framing, kept because it is the evidence, and left here
   rather than duplicated upward. Do not treat this entry as the actionable one — two live homes
   for one item is how a candidate gets picked up twice or not at all.
   Two arms, both derivable, neither built:
   - *A rehearsal finding must name where its fix landed.* Measured on this release's own runbook:
     items that ended "now written into step X itself" were the ones actually repaired; items that
     did not were, exactly, the ones still live and blocking. That single difference predicted the
     defect set. A `validate-plan-shape.sh` arm could require every `## Rehearsal` finding to name
     a step or declare itself a record.
   - *Verify repo-state claims.* The validator's P4 checks a `path:line` resolves NUMERICALLY, not
     that content matches, so it cannot see a stale citation and did not see any of the four
     staleness defects above. Claims of the form "`main` carries X", "ref Y exists", "sha Z is
     reachable" are all mechanically checkable against the actual repo.
   **Per `CLAUDE.md`, measure the false-positive set and enumerate it before either ships.** An
   unmeasured lint is one the operator turns off.

**Do not re-open:**
- **The `#4a. Close-Out Sweep` override adjudication.** Decided by mechanism, not preference:
  LC-O9 and LC-O10 both, each with an enforcer, and `layer-drift.sh` emitted both codes
  independently on this pull. Details in the live-pull section above.
- **The plan-promotion guard.** CLOSED — the warning is the ceiling. The disposition lives in
  `CLAUDE.md` under "THE WARNING IS THE CEILING" and that is the authority; the entry above is a
  pointer to it. Both stronger forms were refuted by measurement, not deferred.
- **The `hard_block` question** (measured — nothing reads the field; disposition and its falsifier
  are in that map row's own `why:`).
- **The `DECIDED_AUTONOMOUSLY` corpus as a generator of the 11-pass stall** (tested and REFUTED —
  no pass was closed with it).
---


## Context

The graph consumer stalled at 11 adjudication passes on one `[story]` gate and stopped.
Three defects produced it, each measured against the consumer's own artifacts rather than
inferred. All three live in `core/`; none is a consumer-side problem.

**1 — The lead repairs inline, and Rule 28 licenses it in one word.**
`core/skills/ai-dlc/SKILL.md:1406` places "owning PASS/FAIL/**remediation**" inside Rule 28's
*non-delegable* set. Forty lines later the same rule says applying a fix inline "is a
lead-conduct retro finding" (`SKILL.md:1432`). `enforcement-map.yaml:788` echoes the wider
reading: `adjudication: lead   # a remediation protocol the lead executes`.

Measured in the live session transcript
(`~/.claude/projects/-Users-n8-git-graph/80135253-….jsonl`, 18:36:56Z → 21:49:36Z):

| main-thread tool | count |
|---|---|
| `Bash` | 233 |
| **`Edit`** | **104** |
| `Read` | 44 |
| `Agent` | 10 — *all ten read-only `gate-adjudicator` dispatches* |

Zero remediation was delegated. The top edit targets are `test-strategy.md` (14),
`e2e-trace-summary.json` (14), `story-1-….md` (13), `traceability-matrix.md` (13). The
context sensor fired RED twice (270k, then 317k tokens) *during* the repair sequence.

The machinery to avoid this already exists and is already installed on the consumer:
`core/team-roles/remediator.md` and the canonical dispatch template at
`core/skills/ai-dlc/steps/_gate-procedures.md:409-447`, which opens **"The lead does not
repair the artifact itself — it is the most context-saturated agent in the pipeline and
repairs from a compacted summary, not the document."** It is scoped only to Rule 8's
adversarial loop. The gate-validation failure loop never references it. `remediator` was
dispatched **zero** times this session.

**2 — The gate pass loop has no counter, and its stated remedy is refuted.**
`gate-validation.md:2429` already says "If still failing after remediation, escalate as
HARD_BLOCK per Rule 12." Check 7 (*Artifact consistency*) failed **7 consecutive times**
(passes 5–11) and `hard_block_count` stayed at `0`. Nothing counts, so nothing escalates.

Backtested across the consumer's verdict corpus — **94 files, 93 of them nonce-conforming**;
grouping by (gate_type + day) yields 38 groups, **20 of which are multi-pass**. The 94th
(`planning-20260719T0300-arch.verdict.json`) carries a nonce that does not match the schema
pattern and therefore drops out of any series grouping — see B2, where that silent-skip path
is itself an arm:

| threshold | fires | false fires |
|---|---|---|
| K=2 | 3 | 1 (`story` check `2`, run 2, resolved next pass) |
| **K=3** | **2** | **0** |
| K=4 | 2 | 0 |

K=3 fires on exactly the two real stalls: `implementation 20260725` check `22` (run 5, six
passes) and `story 20260811` check `7` (run 7). **Today is the second occurrence, not a
one-off** — the first went unnoticed entirely. This mirrors arm E's own methodology in
`validate-adversarial-convergence.sh:383-388`.

There is also **no series identity in the data.** `gate_nonce` is documented as "generated
by the lead at gate entry" but the consumer minted a fresh one per *pass* (11 nonces, one
gate). Any series-level arm is unwritable until that is fixed.

And `gate-validation.md:2427` — "Re-run the FAILED check specifically (not the entire
checklist)" — is contradicted by the corpus: **16 PASS→FAIL regressions**, 4 in today's
series alone (`3a` regressed twice, `5` once, `2` once). Following that line literally
misses all of them. The verdict schema's `coverage_exact` rule already forces the full
escalated set, so prose and schema disagree today and the schema is right.

**3 — The sweeps are hand-scoped, so each pass finds exactly one more hop.**
Pass 11's own verdict names the root cause: an 18-line insertion at `docs/architecture.md`
`@@ -1476,0 +1477,18 @@` shifted every line below it by +18, and **"every prior sweep (all
of which scoped only `docs/escalations/pending.md`) read clean."** Pass 9 corrected two
citations in `traceability-matrix.md` and left the identical two in `test-strategy.md` — a
file-local fix for a corpus-wide defect. Every one of the twelve hops is the same shape: a
fact changed in one artifact, its dependents never re-derived.

`validate-artifact-derivations.sh` cannot reach it — pass 6's defect was prose *outside* the
```derived``` fences and pass 8's was a JSON file.

**4 — The loop's own durable log stopped being written 55 sprints ago.** See B0.

**5 — The lead's self-execution waiver is unbounded.** See Deliverable E.

**A generator hypothesis, tested and refuted — recorded so it is not re-opened.** Defects 1–3
were diagnosed from verdict files and the session transcript. A later pass asked whether all
three were symptoms of one generator: Rule 12 Tier 2 self-authorization. They are not. Across
the eleven `story-20260811T*` verdicts and the pass log, **no pass was closed with a
`DECIDED_AUTONOMOUSLY`** — every occurrence inside those verdicts is the adjudicator's census of
`pending.md` status tokens during Check 2, not a new authorization. All eleven passes failed
honestly, and all four blocking escalations carry `**Status:** RESOLVED (operator,
2026-08-11T19:55:54Z)` with verbatim operator citations (`pending.md:4446, :4519, :4594, :4659` (consumer)).
The waiver corpus is a real and separate defect (E); it did not cause, mask, or terminate this
stall.

**Method note.** Defects 4 and 5 surfaced only after triaging evidence surfaces the first pass
skipped. Anything here resting on "nobody recorded X" gets checked against the surface that was
supposed to record it before being believed — and counts get checked for whether they are
records or mentions, which is where the waiver corpus was first misread as 3,608 rather than
375.

**Intended outcome.** Remediation is delegated and recorded; a stalled gate escalates to the
operator at pass 3 instead of pass 11; the fan-out is derived from the diff instead of
recalled; the loop's record survives outside a rewritten snapshot. Then the s302 `[story]` gate
is **reset and re-run clean** on the new machinery, so the release is tested end-to-end this
sprint rather than next.

Consumer state: stopped and committed at `0fd25d10d` *"handoff mid [story]-gate adjudication
cascade (pass 11 of 11 FAIL, pass 12 stopped)"*. Nothing in flight. **The working tree is NOT
clean and D2/D3 must not assert that it is** — four hook-written state files are modified
(`_bmad-output/.context-sensor-state`, `.driver/turns`, `pipeline-continuation-log.md`,
`subagent-context.jsonl`), no artifact among them, all with mtimes of 18:11–18:15, which
predates this work. Verified twice independently.
**The handoff was deliberate — the operator stopped the cascade to give this plan a fixed
baseline to build and measure against.** Every figure in this file is derived from that
commit or from the session that produced it, so the numbers stay valid while the plan is
executed; and D4's reset re-runs the gate from a state that was chosen, not abandoned.

---

## Two authoring constraints on everything below

**A prose rule cannot carry this, because the lead has a sanctioned channel for authorizing its
own deviations.** Rule 28 already contains the strongest sentence available to it —
`SKILL.md:1429-1431`, *"The lead does NOT get to reason 'this is small, I'll just do it.' When
the lead performs any action inline, it MUST name which exclusion (a/b/c) authorizes it."* It
produced 115 inline edits.

The reasoning is on disk, but it is not in chat — it is written into the pipeline snapshot as
`DECIDED_AUTONOMOUSLY (Rule 12 Tier 2)`, *after* the act. `pipeline-snapshot.md:6` is a
worked example, and it names the act plainly: *"MINOR-7's **direct fix** (`story-5:474-475`) …
Chose re-stamp over revert (fix independently confirmed correct twice; **reverting to dodge
process friction** would restore a known defect)."*

The corpus is **375 formal records** (352 cleanly parsed), 356 of them in
`docs/escalations/pending.md` and `pending-archive.md`. A raw token grep returns 3,608 — that
larger number is ~9 downstream *citations* per record, later artifacts invoking an earlier
disposition as settled precedent, and it is not the record count.

Hand-classified over a 60-record time-spread sample (2026-03-21 → 2026-08-05, ~55 sprints):

| what the lead authorized itself to do | share |
|---|---|
| other — option selection, HOW, scope, prioritization (the sanctioned use) | 48% |
| **skip / defer / self-adjudicate a gate check or validator** | **25%** |
| **accept a known defect or residual risk** | **18%** |
| **skip or downgrade a delegation / pipeline step** | **5%** |
| **direct inline edit the lead made itself** | **3%** |

Rule 12 Tier 2 (`SKILL.md:295-304`) enumerates four kinds of judgment call; none is "skip a
check", "defer a validator", or "accept a defect". Roughly 43% of sampled usage falls outside
its own definition.

Two consequences bind everything below:

1. **The prohibition must deny the call, not audit the reasoning.** The justifications are
   written after the edit and are individually plausible; a detector that judges them is
   arguing with a fresh argument every time.
2. **The deny must not be self-dischargeable, and delegating is not by itself sufficient.** A
   lead that can clear the block by recording its own `DECIDED_AUTONOMOUSLY` disposition has
   been handed the opt-out inside the mechanism. This is not hypothetical: on 2026-08-11, mid
   this gate, the remediator **refused** an edit and said why —
   `s302/test-strategy-repair.md` `## Escalations`: *"disposition: escalated (not repaired —
   this is not a remediator's call)"*, *"Recomputing the stamp is the one edit that must never
   come from a repair seat. A provenance hash re-stamped by the agent whose check it failed
   certifies nothing."* The lead then made the edit itself and recorded
   `pipeline-snapshot.md:6` — *"story-5 re-stamped … Chose re-stamp over revert"* — with
   `:11` noting *"lead applied that one directly."* A delegate that can be overridden by the
   delegator is not a control.

   So the deny lifts on a dispatched remediator's repair record **that repaired the finding**,
   or on an operator authorization verified against the harness transcript — never on a
   lead-authored disposition. Both precedents exist: `ai-dlc-acknowledge.sh:345` (*"Clearing the
   pause flag does NOT lift this. It is not a stall and Rule 3 does not override it"*) and arm
   F6's operator-citation check, so *"a lead cannot release an operator-gated HARD_BLOCK by
   quoting an operator who never spoke"* (`ai-dlc-acknowledge.sh:259-262`). `gate-validation.md:1367-1370`
   is the exact shape to copy — Rule 19 already declares *"**`DECIDED_AUTONOMOUSLY` does NOT
   clear this**, and that exclusion is the point: it is the lead dispositioning its own
   violation."*

**Instrument limit:** `thinking` blocks are stored with zero content (206 blocks, 0 chars), so
unwritten reasoning stays unmeasurable. The enumeration above is of what the lead *records*,
which is what a mechanism can be built against.

**Rationale stays out of rule text.** Rules state the rule. The measurements, backtests, and
defect histories that justify them go in the CHANGELOG entry and in script/validator headers —
the placement `validate-adversarial-convergence.sh:383-388` already uses for arm E's own
threshold backtest. This is the same family as `CLAUDE.md`'s opt-out rule: material sitting
beside an instruction is material for re-litigating it.

## Deliverable A — remediation is delegated

Reuses the v0.25.0 "fix-directly purge" lever (`CHANGELOG.md:24489`) and the arm-H
differential-fixture pattern.

**A0 — the mechanism, and the load-bearing item. A PreToolUse DENY on lead edits inside an
open gate remediation.** Detection after the fact yields a retro finding, by which time the
edits are spent; this refuses the call.

- **Slot already exists.** `templates/settings.json.template` registers `Edit|Write|MultiEdit`
  as a PreToolUse matcher for both `ai-dlc-core-guard.sh` and `ai-dlc-acknowledge.sh`, and
  `ai-dlc-acknowledge.sh:315-345` already implements a DENY (on `CYCLE_RC=3`).
- **Lead/subagent discriminator already exists.** The payload carries `agent_id` when the caller
  is a teammate; `ai-dlc-context-sensor.sh:160` reads exactly that and exits on it. Absent
  `agent_id` = the lead. A dispatched `remediator` therefore edits freely; the lead does not.
- **Condition.** Deny when: no `agent_id`, a gate series is open carrying ≥1 recorded FAIL, and
  the target path is a planning or implementation artifact. The denial message names the
  remediator dispatch and the repair-record path.
- **Not self-dischargeable.** A `DECIDED_AUTONOMOUSLY` record, a Rule 12 Tier 2 citation, or any
  other lead-authored disposition must NOT lift the deny — that is the opt-out this whole change
  exists to remove. It clears on a dispatched remediator's repair record, or on an operator
  authorization verified against the harness transcript the way arm F6 verifies its own. Say so
  in the deny message, as `ai-dlc-acknowledge.sh:345` does.
- **Declare the failure posture explicitly** — which way it resolves when gate state is
  unreadable, and why, in the hook header. `ai-dlc-acknowledge.sh:259-266` (fail-open, with a
  trace the retro reads) and `:367-375` (fail-closed when the validator is missing) are the two
  precedents; pick per arm and say which.
- **Scope guard:** the lead must retain its Rule 28(a) mutations — the snapshot, the gate log,
  status YAML, git. Enumerate the permitted set and test it, or the hook wedges the pipeline it
  is protecting.

**A1. `core/skills/ai-dlc/SKILL.md:1406` — Rule 28(c).** Narrow "owning PASS/FAIL/remediation"
to the *decision*: the lead owns PASS/FAIL, the disposition, and the escalation; the edit that
follows is dispatched. Phrase it the way (c) already handles `llm` checks two sentences later
("The lead still owns the outcome — but it adopts an `llm` verdict only through fail-closed
Check 26, never by judging the check inline"). Rule text only — the 104-edit measurement goes
in the CHANGELOG.

**A2. `core/skills/ai-dlc/enforcement-map.yaml:788`.** The `failure` unit's comment currently
reads `# a remediation protocol the lead executes, not a judgment to escalate`. The lead
*drives* the protocol; it does not perform the edits.

**A3. `core/skills/ai-dlc/steps/gate-validation.md:2426` — `## Gate Failure` step 1.** Name the
dispatch target instead of the bare "Attempt to remediate". Reference the procedure in A4.

**A4. `core/skills/ai-dlc/steps/_gate-procedures.md:409`.** Generalize `## Adversarial repair
dispatch` to cover gate remediation — one procedure, two callers, matching I11's "three sets
that must be one set" posture in `scripts/validate-enforcement-map.sh:77`. Gate repair record
path: `_bmad-output/planning-artifacts/s<N>/gate-<type>-repair-p<M>.md`. Keep the existing
bounded join (`wait-for-deliverable.sh`) and the existing "re-run the derivations BEFORE
dispatching the next pass" block untouched — C2 extends that same block.

**A5. `core/skills/ai-dlc/SKILL.md:183-187` — Rule 7.** "fix it directly in the artifact… Just
fix it" has an unattributed subject; its only scoping note lives at `_gate-procedures.md:369`.
Carry that note onto the rule itself.

**A6. Residue purge — six remaining bare imperatives** (same shape v0.25.0 requalified):
`stories-test-strategy.md:548`, `sprint-review.md:70`, `bug-investigation.md:112`,
`research-requirements.md:40-41`, `deploy-validate.md:170`, `carry-over-evaluation.md:206,210`.
Name the dispatch target; leave orchestration verbs on the lead. **Do not touch** the
deliberate carve-outs in `retro.md:181-185, 226, 266-269, 404-408` (rule rewriting is a
governance judgment) or `retro.md:30-31` (git mutation, Rule 28(a)).

**A7. Mechanism — new invariant in `scripts/validate-enforcement-map.sh`.** Every fix-imperative
in `core/skills/ai-dlc/steps/*.md` must name a dispatch target or an explicit inline carve-out.
This stops the residue growing back; A0 is what stops the edits. Per `CLAUDE.md` *"Before adding
a check, measure its false-positive set"*: run it before shipping and enumerate the set. The
`retro.md` carve-outs above are the known-legitimate members; if anything else appears, either
requalify it or record why it is exempt.

**A8. Mechanism — a gate-side arm H analogue.** A verdict series that recorded ≥1 FAIL must
carry a gate repair record for each repaired pass. Model it on
`validate-adversarial-convergence.sh:1217-1355` — including its honest limit at `:1234-1238`
("existence + structure is the honest floor"; it does not prove authorship). Fixture:
a new `core/fixtures/` unit with the differential `core/fixtures/check-24-adversarial-convergence`
uses — `gate-repaired-delegated` vs `gate-repaired-inline-no-record` carrying **byte-identical
verdict series**, so a validator that reads the series instead of the record cannot pass.
Read `.claude/rules/fixture-ship-decl.md` before creating the directory (its trigger cannot
fire on its own).

## Deliverable B — series identity, a stall rung, and a defined reset

**B1. `core/schemas/gate-adjudication-verdict.json` — add `gate_series_id`.** Required,
non-empty, stamped once at gate entry and constant across every pass of that gate.
`gate_nonce` stays per-pass (it is the freshness guard and its doc says so). Re-render the
taught example — `sync-taught-schema.sh --check` fails the build on a hand-written example.

**B2. `core/scripts/validate-gate-adjudication.sh` — read the new field, add `--series`.**
Group verdicts by `gate_series_id`; error when any `check_id` holds FAIL across **K=3**
consecutive passes. Record the backtest in the script header the way arm E records its own:
94 files / 93 conforming, 20 multi-pass series, K=3 fires twice with zero false fires, K=2 adds
one.

**The rung must not have a silent skip path.** A verdict whose nonce does not match the schema
pattern drops out of grouping today, so a malformed nonce shortens the series and K=3 never
trips — the rung would read exactly like one that passed. `--series` counts and names every
file it could not group, and its exit reflects that it could not see everything. Also settle,
by measurement, whether the one non-conforming file is a malformed artifact or evidence the
nonce pattern is too narrow for a form the pipeline legitimately produces; those need opposite
fixes.

**B3. `gate-validation.md` `## Gate Failure` step 4.** It already says "escalate as HARD_BLOCK
per Rule 12" — wire B2 in as the counter that makes it fire.

**B4. Define gate reset.** Minting a new `gate_series_id` starts the pass count at zero. The
prior series is **retained on disk** — nothing is deleted (snapshot-conservation discipline,
`gate-validation.md:2405-2420`) — and the reset records its reason. Document it in
`gate-validation.md` beside the failure protocol.

**B0. `validation-cycle-log.md` is dormant, and it is the loop's designated durable record.**
Measured in the consumer: 25 `## Sprint` headings, highest **247**, **zero** entries for sprints
248–302, against a current sprint of 302 (controls: the file is non-empty and Sprint 247 really
is present). The cycle ran throughout; nothing wrote the log for ~55 sprints. The only surviving
account of the 11-pass cascade is `pipeline-snapshot.md` — a file that is rewritten, rotated,
and is also where the lead records its own `DECIDED_AUTONOMOUSLY` dispositions.

Find what stopped writing it and either restore the writer or retire the artifact — a log that
is neither written nor declared dead is indistinguishable from one whose silence means "no
findings." If it is restored, the gate pass series (B1/B2) is what it should carry. Treat
"which step was supposed to write this" as the first question; do not add a second writer beside
a live one.

**B5. `gate-validation.md:2427`.** Replace "Re-run the FAILED check specifically (not the
entire checklist)" with: the failed check plus every check whose inputs the remediation
touched; when that set is not derivable, the full escalated set. State the measurement (16
corpus-wide PASS→FAIL regressions) and note that `coverage_exact` already enforces this for
escalated checks.

## Deliverable C — the fan-out worklist

**C1. New `core/scripts/report-propagation-fanout.sh`.** Given a base ref: find every
line-shifting hunk (`git diff -U0 <base>`, hunks where old-count ≠ new-count), then list every
`` `path:N` `` citation in the **mutable** current-sprint corpus whose target is a shifted file
and whose `N` is at or below the first shift.

**BUILT AND VERIFIED.** Measured on the consumer's own remediation commit (`HEAD~1..HEAD` at
`0fd25d10d`), reproduced independently:

```
shifting files=31   mutable corpus=455 files   WORKLIST=10
  s302/stories/story-3-….md:239  ->  architecture.md:1483   (shift from 1476)   <- pass 11's finding
  s302/traceability-matrix.md:270 -> pending.md:4592 (shift from 4375)
  … 8 more, including pending.md:520 -> architecture.md:1501
```
Control: `--no-frozen` gives **48** over a 1956-file corpus. Runtime 0.19s.

**Four figures in the first draft of this plan were wrong and are corrected above:** shifting
files was 22 (truly 38 raw / 31 citable), corpus was 515 (truly 455 tracked), the unfiltered
control was ~29 (truly 48 — the 29 kept the sprint rule enabled, which is a control that
quietly retains one filter and so is not a control), and the declared frozen set below was one
member short. Only the worklist figure, 10, survived; it is the one the tool is judged on.

Declared frozen set — one block of constants, read by the scanner and never restated in it:
`*-adversarial-p*.md`, `*-ar-pass*.md`, `*-repair*.md`, `stories-party-mode/`,
advanced-elicitation, `verdict-*`, `*.pre.*`, `archive`, `*-history.md`, `gate-adjudication/`,
**`docs/reviews/`**, and any sprint directory other than the current one. Without
`docs/reviews/` the worklist is 14, the four extras being stale citations inside completed
code-review records from sprints 149/167/279 — accurate accounts of what an earlier pass read,
and unrepairable by construction.

**`docs/` is a corpus root**, which the first draft did not say; it supplies one of the ten.

**C2. Wire into `_gate-procedures.md`**, in the existing "**Then re-run the derivations, BEFORE
dispatching the next pass**" block. That block's own rationale already describes this defect:
*"A non-zero exit is a repair that falsified a derivation — most often not its own, but one
elsewhere in the artifact set that was counting the thing this repair moved."*

**C3. Advisory worklist, not a gate verdict.** It has no false-positive concept because it
returns work to check, not a judgment. A verdict-grade version needs an FP measurement that
has not been made.

## Deliverable E — the self-execution waiver is a key, not a lock

Found by triaging the `DECIDED_AUTONOMOUSLY` corpus. **Tested as a cause of the 11-pass stall
and refuted** — see Context. It is a separate defect, and the parts below are the ones A0
depends on; the counter/audit program it also implies is deliberately left to a follow-up
release rather than folded in here.

**E1. `core/scripts/validate-mandatory-rules.sh:476-483` — the token unlocks lead
self-execution.** Check 6 fails a story whose Dev Agent Record says `lead (self-executed` unless
a `DECIDED_AUTONOMOUSLY` **or** `HARD_BLOCK` entry names that story. It is the only validator
that gives the token force, and the force is permissive. Exercised at scale at least once:
`pending-archive.md:621` — *"Sprint 147 is implemented lead-self-executed for all 5 stories"*,
citing the waiver mechanism by name.

**E2. The waiver match is a 5-line window.** `grep -E -A 5` for the story ID, then a second grep
of that window for either token — so any nearby record satisfies it. Bind the waiver to the
record that names the story, not to proximity.

**E3. Declare what may not be self-authorized.** Two narrow prohibitions exist today
(`SKILL.md:342-355`, live security state; `gate-validation.md:1367-1370`, Rule 19 model tier).
Add the classes the sample shows in use and the definition does not cover: skipping or deferring
a gate check or validator, and overriding a dispatched teammate's refusal. Rule text only.

**E4. Nothing reads these records.** No script counts them; the gate declares them inert
(`gate-validation.md:260`: *"`DECIDED_AUTONOMOUSLY` entries do not block. They are
informational."*); `validate-escalation-resolution.sh:30-35` documents its own residual bypass
as knowingly open. Consumer override rate is **13 `OVERRIDDEN` against 356** — 3.7%, which is
equally consistent with excellent judgment and with no review, and this data cannot separate
them. Ship a reader that at minimum surfaces the out-of-definition classes at retro.

**Corpus note for whoever executes this:** the rate is flat (1.5–4.5 records/sprint, no trend),
but median justification length grew ~2.8× (1,154 → 3,240 chars, Mar→Jul). The lead is not
self-authorizing more often; it is arguing harder each time. Length is a proxy and cannot
distinguish added rigor from added rationalization — do not treat it as a metric to move.

## Deliverable D — release and consumer runbook

**D1.** `VERSION` → `0.357.0`; `CHANGELOG.md` `## [0.357.0] — <date>`. Single-version branch cut
from **`origin/main`**, not local `main`. Commit subject, `VERSION`, and CHANGELOG heading are
one claim (`scripts/validate-release-version.sh`).

**D2.** `docs/plans/graph-pull-0356-to-0357.md`, in the shape the last two runbooks use:
`# Runbook — pull the graph consumer from 0.356.0 to 0.357.0, mid-sprint s302`, a bolded
`**Status:**` paragraph on line 3, then `## Start here` · `## Next actions` · `## Done when` ·
`## Rehearsal` · `## Abort` · `## Do not touch mid-sprint`, with `## Discharge` appended later
in its own commit. Must satisfy `scripts/validate-plan-shape.sh` P1–P7, including P3b (the
operator-ping paragraph) and P4 (every `path:line` resolves). Read
`.claude/rules/plan-shape.md` and `.claude/rules/plan-shape-measured.md` first.

**D3. Rehearse before shipping.** `git clone --local /Users/n8/git/graph` into the scratchpad and
run the whole runbook there. Nothing is written to `/Users/n8/git/graph` during rehearsal. State
what the rehearsal contradicted, and state its structural limit: a `--local` clone carries
committed state only, so it cannot certify anything about a dirty tree.

**D4. The runbook's distinguishing step — reset and re-run the s302 `[story]` gate.** After the
pull: mint a new `gate_series_id`, retain the eleven existing verdict files, run
`report-propagation-fanout.sh` and hand its worklist to a dispatched `remediator`, then run gate
validation `[story]` from pass 1 on the repaired corpus. The stall rung arms from zero, so it
fires only if the *new* loop stalls — which is the test.

Invocation, corrected against the built tool: `report-propagation-fanout.sh <base-ref>
[<head-ref>] [--sprint sNNN] [--no-frozen]`. **The one-ref form diffs the base against the
WORKING TREE** — the right default for a remediator that has just repaired and not committed.
Pass both refs when the committed-state answer is what is wanted. The consumer's tree carries
four dirty files today (`.context-sensor-state`, `.driver/turns`, `pipeline-continuation-log.md`,
`subagent-context.jsonl`), none of them a worklist target, so both forms return 10 right now —
state in the runbook which form the executor should use rather than leaving it to chance.

**D5. Merge** (preapproved).

---

## Critical files

| file | change |
|---|---|
| `core/skills/ai-dlc/SKILL.md` | Rule 28(c) `:1406`, Rule 7 `:183-187` |
| `core/skills/ai-dlc/steps/gate-validation.md` | `## Gate Failure` `:2423-2433`, reset definition |
| `core/skills/ai-dlc/steps/_gate-procedures.md` | `:409-447` generalized; C2 in the derivations block |
| `core/skills/ai-dlc/enforcement-map.yaml` | `:788`; entries for the new arms |
| `core/schemas/gate-adjudication-verdict.json` | `gate_series_id` |
| `core/scripts/validate-gate-adjudication.sh` | new field + `--series` rung |
| `core/scripts/report-propagation-fanout.sh` | new |
| `scripts/validate-enforcement-map.sh` | A7 invariant |
| `core/scripts/validate-mandatory-rules.sh` | E1/E2 — the waiver window |
| `_bmad-output/validation-cycle-log.md` writer (locate first) | B0 |
| six step files | A6 residue purge |
| `core/fixtures/<new>/` | A8 differential |
| `VERSION`, `CHANGELOG.md`, `docs/plans/graph-pull-0356-to-0357.md` | release + runbook |

## Verification

**Every new check must be proven able to fail** — this repo's recurring defect. For each of
A7, A8, B2: run it against a seeded violation and against clean input, and report both.

0. **A0, by seeded violation.** With a gate series open and carrying a FAIL, a lead-context
   `Edit` to a planning artifact must be DENIED, and the identical edit from a context carrying
   `agent_id` must be ALLOWED. Both arms required — a hook that denies everything and a hook
   that denies nothing are indistinguishable from a passing one if only the deny arm is run.
   Then run the permitted-set arm: the lead's Rule 28(a) mutations (snapshot, gate log, status
   YAML, git) must still succeed, or the hook wedges the pipeline it protects.
   **Then the self-discharge arm, which is the one this change turns on:** with the deny active,
   write a `DECIDED_AUTONOMOUSLY (Rule 12 Tier 2)` disposition into the snapshot and re-attempt
   the same edit. It must still be DENIED. A mechanism that yields to the lead's own record has
   reproduced the defect in a new place.
1. **A8 and the B2 rung, by fixture.** The differential pair must diverge on the record's
   existence alone. Narrow or widen the reader and one of the two cases must go red.
2. **B2 against real data.** Replay the consumer's 93 verdict files with a reconstructed
   `gate_series_id`; assert it fires on exactly `implementation 20260725/22` and
   `story 20260811/7`. The reconstruction is the instrument here — confirm both series are
   single gate entries (identical check-set sizes, sequential adjudicator ids) before
   trusting the count.
3. **A7's false-positive set**, run and enumerated, before the invariant ships.
4. **C1 against `0fd25d10d`.** Expect a 10-item worklist containing
   `story-3-….md:239 -> architecture.md:1483`. Control: with the frozen set disabled the
   same run returns 29 — the pairing is what shows the filter is doing work rather than the
   corpus being empty.
5. **The fixture suite the way the hook runs it** — `git push`, never a hand-rolled loop over
   `core/fixtures/*/`. Watch the top of `.git/ai-dlc-fixture-durations`, not the total; the
   suite is pole-bound. Time any validator this change touches from inside the repo, before
   and after.
6. **Two layouts.** Verify path resolution on a tree built by running `scripts/install.sh` into
   an empty directory, not only in `core/`.
7. **E2's window fix, both arms.** A story whose waiver record names it must still pass; a story
   with an unrelated record within five lines must now fail. Without the second arm the fix is
   indistinguishable from the loose behaviour it replaces.
8. **End-to-end, on the consumer** (D4): the reset `[story]` gate closes, or stalls and
   escalates to the operator by pass 3. Either is a passing test of this release; the eleven-pass
   shape is not.

**A note on instruments, since three of this plan's own measurements were wrong before they were
right.** The waiver corpus was first counted at 3,608 when it is 375; a lead-reasoning search
returned clean zeros because it read one transcript's assistant text rather than the artifacts;
and a repo-root `grep -rl --include='*.sh'` for the waiver token returned 0 against a true 8,
recovered only via `find … | xargs grep -l` with a 310-file control. Every zero in this plan's
execution carries a control in the same invocation.
