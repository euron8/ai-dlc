# DISCHARGED — Retire the "2+ passes" floor: converge on the exit condition, not a pass count

> **THIS PLAN IS SPENT. DO NOT EXECUTE IT.** Shipped as **v0.413.0** (`81bcc00d`) on
> `origin/main`, with the follow-on mechanisms in **v0.414.0**. Every numbered action below
> is done. Kept as the RECORD of what was measured and why, never as a set of instructions.
>
> A spent runbook still written in the imperative is this repo's recorded handoff hazard:
> a session told to FOLLOW it redoes merged work.


**Resume with: `READ and FOLLOW docs/plans/adversarial-pass-floor-retirement.md`.**
That is the whole instruction the operator gives. This block is the entry point;
everything below it is the reasoning and the measured evidence behind the change.

Target release: **v0.413.0** (`VERSION` read `0.412.0` when this was written).

## Start here

**Repos and the read/write boundary.**

- **Write here:** `/Users/n8/git/ai-dlc` — this repo, on branch
  `release/0.413.0`, cut from `origin/main` at `43981c44`.
- **READ-ONLY:** `/Users/n8/git/graph` — the reference consumer. It is the
  corpus every number in this plan was measured over. **Read it, never write
  it.** Where a run has to exercise it, copy it to scratch first.
- **Scratch:** `/private/tmp/claude-501/-Users-n8-git-ai-dlc/33774944-3e63-435d-afba-5e9f958b0132/scratchpad`
  for probe trees. Disposable; every measurement it produces is restated here so
  this plan does not depend on it surviving.

**Ping the operator on any question, on any decision, and on completion —
including an early stop.** A session executing this file is invisible from
outside: "still working" and "stopped, waiting on you" look identical, so
silence is a stall that is only ever found by the operator asking.

## Current status

**IN PROGRESS.** Branch `release/0.413.0` cut from `origin/main`; this plan
promoted and committed. No item below has landed yet.

## Next actions

1. **SKILL.md Rule 8** — strip counts from all four rows of the intensity
   table; rewrite `:233` and `:263`. Change item 1.
2. **The unbound copies** — `_gate-procedures.md:210`,
   `gate-validation.md:177`, `gate-validation.md:1574`,
   `validate-adversarial-convergence.sh:64-66`,
   `templates/QUICKSTART.md.template:441,645,707`. Change item 2.
3. **`research-requirements.md:127-130`** — the lightweight ceiling wording.
   Change item 3.
4. **Check 20's failure example** — `gate-validation.md:1260-1267`. Change
   item 4.
5. **Arm J** — key the re-open on `artifact_sha`; reseed the fixture and add the
   two new cases. Change item 5.
6. **Invariant I96** — new arm in `scripts/validate-enforcement-map.sh`, then
   `scripts/render-invariant-index.sh`. Change item 6.
7. **Release triple + CHANGELOG**, then push (the gate runs on push) and merge.
   Merges are preapproved; do not stop to ask. Change item 7.

## Done when

Each of these has been checked to be reachable from the current tree:

- `AI_DLC_FIXTURE_NO_SKIP=1 bash .githooks/pre-push` exits **0**, read from the
  gate itself and not from a wrapper.
- `check-24-adversarial-convergence` reports ok **by name** in that run.
- The I96 arm reports **zero** over the post-change tree, and its `mktemp` probe
  shows it firing on a seeded offender and silent on the seeded near-miss.
- Arm J's three fixture cases do **not** all agree: `reopen-same-bytes` exit 0,
  `reopen-moved-clean` fires, `reopen-sha-absent` exit 0.
- Re-running the changed validator over `/Users/n8/git/graph` yields exactly
  **one** new fire versus the current predicate: `s290/discovery`.
- `docs/invariant-index.md` byte-compares clean after
  `scripts/render-invariant-index.sh`, with an `I96` row present.

## Context

`core/skills/ai-dlc/SKILL.md` Rule 8 declares a per-intensity MINIMUM validation
cycle. The `full` row (`SKILL.md:228`) requires `Adversarial Review (2+ passes)`
and `SKILL.md:233` states `"2+ passes" is a FLOOR; the cycle must CONVERGE to
leave it.`

The loop's real exit condition is a RESIDUE, not a count: a pass stamps
`EXIT_CONDITION_MET` when `findings_critical == 0` and
`findings_major - findings_major_underived == 0` (`core/team-roles/adversary.md:260-268`),
and the cycle runs "until the terminal pass stamps `EXIT_CONDITION_MET`"
(`core/skills/ai-dlc/steps/_gate-procedures.md:210-217`). The floor is a second,
independent stopping rule sitting beside that one.

Outcome: **one stopping rule.** The pass count falls out of convergence instead
of being asserted next to it. The exit condition is honoured the moment it is
met.

## Evidence

### The number was never derived

`git log -S 'Adversarial Review (2+ passes)' --reverse`: the string arrives fully
formed in the initial framework commit `5212c786` (2026-03-22), in three files at
once, with no rationale. It moved verbatim into Rule 8 at `09c170f0`. The
four-tier table that produced the `full` = 2+ / `standard` = 1+ split was
absorbed from the consumer at CHANGELOG `[0.4.2]`, again with no derivation.
A search for text deriving or admitting the number returns zero; a bare
`arbitrary` search over the same corpus returns hits, so the search was live.

### What a floor pass has actually found: nothing, once

Derived against the reference consumer `/Users/n8/git/graph` (`_bmad-output/**`,
324 adversarial files → **71 pass series, 161 consecutive pass pairs**):

| Population | Count |
|---|---|
| Pass pairs whose EARLIER pass stamped `EXIT_CONDITION_MET` | 6 |
| ...same `artifact_sha` — a **true floor pass**, same bytes re-reviewed | **1** |
| ...different `artifact_sha` — the artifact MOVED after MET (a re-open) | 5 |
| Blocking findings produced by that one true floor pass | **0** |

The one true floor pass is `s292/stories` p1→p2: identical `artifact_sha`
`307b013da152`, both MET, 0 CRITICAL / 0 MAJOR.

Intensity cross over 41 sprints carrying a declared `validation_intensity`: 39
`full` series, of which only **3** had p1 stamp MET at all. Where the floor
binds it is honoured — exactly one `full` series ran a single pass, and its p1
carries no parseable verdict.

One pass costs a measured **median 23.5 min** of pass-to-pass wall clock
(n=148 intervals with two parseable `invoked_at` stamps; mean 97.8, p25 15.9).
**The saving is not the argument** — one pass across 71 series is noise. The
argument is that two stopping rules where one suffices is the thing being fixed.

### The repo's own prior measurements agree

- `core/fixtures/check-17-counts/run.sh:22`, `CHANGELOG.md:23092`, and
  `core/schemas/provenance-block.json:468`: **12 of 13 second passes find no
  CRITICAL and no MAJOR**, and both later-pass hits across 15 changed-artifact
  pass-pairs were repair-induced rather than discovered. Population: 55
  `ai-dlc-adversary-review` provenance blocks over 30+ sprints.
- `core/scripts/validate-artifact-derivations.sh:9-21`: of 79 MAJORs raised at
  pass 2+, **78% were introduced by a prior repair**.
- `docs/plans/graph-ledger-full-drain.md:577`: **79% of pass-2+ findings are
  repair-introduced**, over 47 series / 127 passes.
- `core/team-roles/adversary.md:95-102` already tells the reviewer the opposite
  of a floor: *"ZERO FINDINGS IS THE GOAL, NOT A FAILURE. NEVER MANUFACTURE A
  FINDING TO SATISFY A QUOTA — no floor, no minimum."* Rule 8 imposes on the
  lead exactly what the role file forbids the reviewer.

### The one argument on the other side, and why it does not reach this change

`docs/plans/graph-ledger-full-drain.md:580-590` backtested an early-exit
predicate and **killed it**: a 2-pass non-increasing-MAJOR exit and every
`MAJOR <= k` variant are DISQUALIFIED, each skipping a prior-scope CRITICAL
already sitting in the text.

That is a **plateau** predicate (findings stopped rising), not a **clean
residue**. This change adds no exit predicate at all — it removes a count beside
the existing 0C/0M one. In both disqualifying series the exiting pass was
reporting non-zero blocking findings, which `EXIT_CONDITION_MET` already
refuses. **Do not re-run that backtest; it answers a different question.**

The verification-of-repair rationale (`SKILL.md:233`, `adversary.md:65`,
`_gate-procedures.md:265-269` — "pass 2+ reviews the REPAIR") is untouched and
unreachable here: when pass 1 stamps MET there is no repair, so the rationale is
vacuous in exactly the case the floor forces a pass.

### The floor has no mechanism today

- `core/skills/ai-dlc/steps/gate-validation.md:1238-1258` **Check 20** is the
  only enforcement, and it is `adjudication: llm`, `enforcer: []` in
  `core/skills/ai-dlc/enforcement-map.yaml:371-376`.
- `minimum_met` has **0** occurrences in `core/scripts/` and `core/hooks/`
  (control: `validation_intensity` = 1, at `core/scripts/sprint-status.sh:446`).
- `core/scripts/validate-adversarial-convergence.sh:64` says outright that it
  does not enforce the floor.
- The only code touching it is arm J's exemption at `:1215`, which *excuses* a
  floor pass rather than requiring one.

So the floor is prose, adjudicated by a model reading a checklist. Removing it
removes no enforcement.

### A defect found while measuring

`validate-adversarial-convergence.sh:1197-1203` names its two false fires as
`s290-discovery` p1 MET → p2 MET and `s292-stories` p1 MET → p2 MET, "both the
same shape". They are not. `s292-stories` shares `artifact_sha` across p1/p2.
`s290-discovery` does not — p1 `0db9fd8392bf`, p2 `cd1450150cd7`, same
`artifact: product-brief.md`. The brief MOVED after sign-off, which is arm J's
own definition of a re-open; that pass escaped only because it happened to find
nothing.

## Change

### 1. `core/skills/ai-dlc/SKILL.md` Rule 8 — the single source

Replace the `Minimum cycle per planning artifact` column so it names
EVALUATIONS only, with no counts:

| Intensity | Minimum cycle becomes |
|---|---|
| `full` | Party Mode → Advanced Elicitation → Adversarial Review |
| `standard` | Party Mode → Adversarial Review |
| `carry-over-single` | Party Mode → Adversarial Review |
| `lightweight` | Adversarial Review at discovery + stories-test-strategy only |

Keep the table header and the `` | `name` | `` row form byte-compatible with
I80's extractor (`scripts/validate-enforcement-map.sh:5577-5639`), which parses
`\| Intensity \| Trigger.*` then `^\| \`([a-z-]+)\``. It reads the SET and the
shape, never the minimums column, so a column edit is safe — but a header edit
DISARMS it, so do not touch the header.

Replace `:233` with a statement of the single rule: the Adversarial Review runs
until a pass stamps `EXIT_CONDITION_MET`; the pass count is whatever convergence
takes. Keep the second half of that sentence ("Pass 2+ reviews the REPAIR, not
the document again") — it is a contract about what a later pass does, not a
floor.

Leave `:239` (`nonzero MAJOR held at zero CRITICAL across 2+ passes is a STALL`)
alone. That 2 is arm E's `STALL_THRESHOLD`, a different number:
`validate-adversarial-convergence.sh:389`, and its accumulator needs at least
three passes to reach the threshold, so it is unaffected in both directions.

Fix `:263` — `Adversarial review (1+ pass on stories and sprint output)` becomes
a count-free statement that the review is always required regardless of
intensity.

### 2. The three unbound copies and the two template copies

Each restates the count outside the table and none is bound to it:

- `core/skills/ai-dlc/steps/_gate-procedures.md:210` — `2+ passes (a floor, not
  a target)` becomes a pointer to the convergence condition already stated 7
  lines later in the same item.
- `core/skills/ai-dlc/steps/gate-validation.md:177` — Check 1's
  `Adversarial Review completed (2+ passes, only nitpicks remain)?` becomes
  `Adversarial Review converged (terminal pass stamps EXIT_CONDITION_MET)?`.
- `core/skills/ai-dlc/steps/gate-validation.md:1574` and
  `core/scripts/validate-adversarial-convergence.sh:64-66` — both carry the
  "does NOT enforce the per-intensity pass FLOOR" sentence. There is no floor to
  not-enforce; restate as the reason the validator is count-blind by design
  (a legitimate cycle converges in one pass).
- `templates/QUICKSTART.md.template:441`, `:645`, `:707` — the consumer-facing
  copies. `install.sh:349` copies this verbatim and **no invariant binds it to
  SKILL.md**, which is why it drifted.

### 3. `core/skills/ai-dlc/steps/research-requirements.md:127-130`

`on validation_intensity == lightweight, run one adversarial pass only` reads as
a CEILING and contradicts arm D, which requires the last pass to be MET. Restate
as what it means: skip party-mode and advanced-elicitation; the convergence
cycle still runs to MET. `_gate-procedures.md:187` and `gate-validation.md:1536`
already say a lightweight single pass is still a convergence pass — cite, do not
restate.

### 4. `core/skills/ai-dlc/steps/gate-validation.md:1260-1267` — Check 20

The Rule 26(c) failure example names `a full sprint that ... ran a single
adversarial pass` as the defect. That becomes false. Reduce the example to the
skipped-evaluation half, which is what Check 20 still catches. Leave the check's
resolve-from-the-table mechanic alone — it now resolves a count-free row and
keeps working.

### 5. Arm J — key the re-open on `artifact_sha`

`core/scripts/validate-adversarial-convergence.sh:1211-1215`. Replace the
`blocking > 0` narrowing with the direct evidence of a re-open: the artifact
moved after it was signed off.

```sh
[ "${P_VERDICT[$i]}" = "EXIT_CONDITION_MET" ] || continue
j=$((i + 1))
# absent sha on EITHER side exempts -- see below
[ -n "${P_SHA[$i]}" ] && [ -n "${P_SHA[$j]}" ] || continue
[ "${P_SHA[$i]}" != "${P_SHA[$j]}" ] || continue   # same bytes re-reviewed: costs nothing
```

`P_SHA` is already parsed at `:431`; no new parsing.

**Absent sha on either side must exempt.** Legacy passes predate the field and
`mechanism-design.md` forbids shipping a check that errors on pre-migration
data. In the live corpus the field is present on 161 of 161 pairs, so this
tolerance costs nothing there — but the current `reopen-floor-pass` fixture
seeds NO sha (the `pass` helper at `seed.sh:30-54` emits `artifact_sha` only
when arg 8 is non-empty, and `:591-592` pass six args). **Left as-is that
fixture would exercise the absent-sha branch and prove nothing about the
same-sha exemption** — a decoy testing the wrong arm.

Fixture work in `core/fixtures/check-24-adversarial-convergence/`:

- `reopen-floor-pass` — reseed both passes with an IDENTICAL sha. Rename the
  case (`reopen-same-bytes`) and re-ground its comment: a post-MET pass on
  unchanged bytes yields the same residue and costs nothing, and SKILL.md's
  "running more is always permitted" keeps it legal. Still expects exit 0 /
  `CONVERGED`.
- **New case** `reopen-moved-clean` — p1 MET sha A → p2 MET with 0 findings,
  sha B. Expect the arm to FIRE. This is the s290-discovery shape and the catch
  the current predicate misses.
- **New case** `reopen-sha-absent` — the current seeding, no shas, expect exit
  0. Pins the legacy tolerance so it cannot be silently removed.
- `reopen-unrecorded` (`seed.sh:574-577`) is arm J's existing true positive and
  is independent of this change; confirm it still fires.

Correct the mislabelled example at `:1197-1203` and the operator-facing error
text at `:1225-1226`, and the prose contract at `_gate-procedures.md:372-376`.

**This arm gets STRICTER while the rest of the release relaxes.** Blast radius,
measured: 1 additional fire across 71 series. The escape hatch already exists —
`REOPEN_AFTER_MET` is in `VALID_RESOLUTIONS` at `:310`. A fire returns rc 3 from
`--cycle-state`, which both hooks turn into a dispatch DENY
(`core/hooks/ai-dlc-acknowledge.sh:302-316`, `core/hooks/ai-dlc-continue.sh:486-505`),
so the consumer writes a resolution record and continues.

### 6. New invariant **I96** — a pass count may not be restated

`scripts/validate-enforcement-map.sh`, beside I19 at `:2202-2221`. I19 cannot
cover this: its regex needs a backticked intensity name AND an evaluation name
on one line, so it sees neither `_gate-procedures.md:210` nor
`gate-validation.md:177` — both drifted under it.

Grammar: a pass count on a line that also names the adversarial cycle,
case-insensitive, over `core/skills/ai-dlc/**`, `core/team-roles/**` and
`templates/**`:

```
[0-9]+\+? pass(es)?\b   AND   (Adversarial Review|adversarial convergence|convergence cycle|Rule 8|adversarial pass)
```

**False-positive set, measured today: 9 hits, and all 9 are lines this change
edits or deletes** — `SKILL.md:228,229,230,231`, `_gate-procedures.md:210`,
`gate-validation.md:177,1574`, `QUICKSTART.md.template:441,707`. Post-change the
set is empty by construction; assert that in the same run.

Controls the grammar already passes, verified: it does NOT match `SKILL.md:239`
(arm E's STALL threshold), `remediator.md:158` (`Measured: 13 passes`),
`artifact-consolidation.md:124` (`Only Steps 3–4 pass:`),
`_gate-procedures.md:537` (`preconditions 3–7 pass`), or
`gate-validation.md:1829` (`seed H1 passes`).

**Stated limit:** the two-token form catches the restatement shape that actually
drifted and does NOT catch a bare count in running prose (`SKILL.md:233`'s
`"2+ passes" is a FLOOR` carries no adversarial token on its line). Widening to
a single token pulls in the five word-sense false positives above. Record this
in the arm header per `verification-discipline.md` — "how a false-positive set
reached zero is part of the arm".

I96 is unclaimed: 0 hits for `\bI96\b|i96_` across `scripts/ docs/ core/`
(control: I95 = 49). Do not hand-edit `docs/invariant-index.md` — write the arm
header opening with `I96:` and run `scripts/render-invariant-index.sh`.

### 7. Release triple

Commit subject, `VERSION`, and the CHANGELOG heading must all say `0.413.0`.
Cut the branch from `origin/main`, not from local `main`.

## What deliberately does not change

- **The exit condition itself.** No predicate is added, loosened, or tuned.
- **Arm D (TERMINAL).** It keys on `$LAST_VERDICT` with no `N` term, so a
  one-pass series ending MET already passes today — that is the legitimate
  `standard`/`lightweight` shape.
- **Arms C, G, H, I.** All are between-pass predicates and go vacuous at N=1.
  That is correct, not a loss: N=1 implies p1 stamped MET implies zero blocking
  findings implies **no repair happened**, so there is nothing for a
  divergence, chronology, repair-record or ceiling rung to police.
- **Arm E (STALL).** `STALL_THRESHOLD=2` with an accumulator that starts at pass
  2 needs ≥3 passes to fire. The floor never armed it and its removal cannot
  disarm it.
- **`CHANGELOG.md` history.** Append-only; the historical `2+ passes` quotes at
  `:10852`, `:23096`, `:25651` and elsewhere stay.
- **`docs/v0.13.0-consumer-absorption-spec.md:278`,
  `docs/analysis/compliance-review-20260323.md:183`.** Frozen historical
  records.

## Verification — CLOSED, and items 6 and 7 were closed LATE

**The DISCHARGED label above was applied while items 6 and 7 of this section were still
unrun.** Items 1-5 were complete; 6 was partial (an installed tree was checked, but the
suite was never run in the consumer layout) and 7 had been substituted with a synthetic
`mktemp` series instead of the consumer-side close it asks for. Both are now done, and the
substitution is the point worth keeping: a synthetic N=1 check exercises the VALIDATOR, and
item 7 asks about the HOOK. They are different programs.

- **6, closed.** `scripts/install.sh` into an empty tree; `check-24` run from
  `tests/fixtures/` in the consumer layout: 103/103. Then the CONSUMER's copy of
  `validate-adversarial-convergence.sh` was mutated (arm J's sha compare disabled) and the
  fixture went red on `reopen-moved-clean` and `reopen-unrecorded` -- which is what
  establishes that the consumer copy is the one that ran, rather than the fixture reaching
  back into the distribution tree.
- **7, closed.** A scratch consumer tree, never `/Users/n8/git/graph` itself. The real
  `ai-dlc-acknowledge.sh` on a `PreToolUse` Agent payload: a series converged at pass 1
  reports `CONVERGED`, the hook exits 0 and emits NO deny. **Control, in the same run:** add
  a successor pass at a changed `artifact_sha` and the same hook emits the deny. Without
  that control a hook that never armed would have produced an identical "no deny".
- **The boundary was checked by a JOIN, not by intent.** `graph` showed four dirty files
  during the run. The hook writes `- Session: <session_id>` into
  `_bmad-output/pipeline-continuation-log.md`, and the payload used `s7`: that token appears
  **once in the scratch tree and zero times in graph**, whose entries carry a concurrent
  session's UUID. Proximity in time proved nothing; the session-id join did.

## Verification (as planned)

1. **Prove I96 can fail before trusting its zero.** Under `mktemp`, seed a tree
   carrying `Adversarial Review (2+ passes)` and a near-miss carrying
   `across 2+ passes is a STALL`. The arm must report the first and stay silent
   on the second. Both directions, per `verification-discipline.md`.
2. **Prove arm J's new predicate discriminates.** Run the three fixture cases and
   assert they do not all agree: `reopen-same-bytes` exit 0,
   `reopen-moved-clean` fires, `reopen-sha-absent` exit 0. A run where all three
   pass identically has not established that the sha comparison does anything.
3. **Re-run the arm J change against the real corpus, not the fixture.** From
   `/Users/n8/git/graph`, drive the shipping validator over every series and
   diff the verdict set against the current predicate. Expected delta: exactly
   one new fire (`s290/discovery`). Any other delta is unmeasured behaviour and
   blocks the release.
4. **Run the gate the way the gate runs it:**
   `AI_DLC_FIXTURE_NO_SKIP=1 bash .githooks/pre-push`. Read the gate's own exit
   code, never a backgrounded wrapper's, and read
   `check-24-adversarial-convergence` by NAME — a green banner can mean the
   content-key skip fired.
5. **Byte-compare the derived indexes.** `scripts/render-invariant-index.sh` and
   `scripts/render-vocabulary-index.sh` both compare at pre-push. I80's
   vocabulary row must still render the same four intensity names after the
   column edit; if it does not, the extractor was reading the minimums column
   and this plan's premise about it is wrong.
6. **Verify on an installed tree, not this one.** Run `scripts/install.sh` into
   an empty directory and confirm the edited `QUICKSTART.md.template` and the
   Rule 8 table land with no count, in both layouts. A green push here proves
   nothing about a consumer.
7. **Close on the consumer side.** On a scratch copy of `/Users/n8/git/graph`
   (never in place), confirm a `full`-intensity series whose p1 stamps MET is
   adjudicated `CONVERGED` at N=1 by `--cycle-state`, and that no hook denies
   the following dispatch.

## Risks

- **Arm J tightens in a release that otherwise relaxes.** Measured blast radius
  is 1 fire in 71 series with an existing escape hatch. Flagged because it is
  the one item here that can stop a consumer's pipeline.
- **The `lightweight` row loses `(1 pass)`.** That number was already a floor,
  not a ceiling — arm D has always required the last pass to be MET. Item 3
  makes the step file agree with the machinery rather than changing behaviour.
- **I96 does not catch every phrasing.** Stated above with its measured reason;
  it catches the form that drifted three times.
