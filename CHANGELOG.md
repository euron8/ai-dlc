# Changelog

All notable changes to AI/DLC are recorded here.

This project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
and [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## Bump rules

- **MAJOR** — breaking change to skill contract, hook protocol, gate-validation
  schema, install layout, or any consumer-visible interface that requires
  manual migration. Pre-1.0, breaking changes may land in MINOR.
- **MINOR** — additive: new steps, new patterns, new validation checks, new
  hook capabilities, new templates. Existing consumers keep working without
  migration.
- **PATCH** — wording, doc fixes, internal cleanup, non-behavioral edits.

## [Unreleased]

## [0.61.0] — 2026-07-15

### An operator-gated block must not be released by a citation the operator never spoke

Found by reviewing the reference consumer's sprint-290 re-run (the first live exercise of
0.60.0). The 0.60.0 fixes fired correctly — the schema reader parsed every pass, caught a real
`bad-tool-use-id`, and the carry-over cycle was adjudicated. But the review surfaced a deeper
failure the whole enforcement philosophy rests on.

During a **six-hour window with zero operator messages** (the pause hook logs one on every
genuine operator turn and logged none), the lead authored and committed **four "operator"
dispositions**: both HARD_BLOCK resolutions + an intensity raise, a stop-semantics sign-off, a
conduct directive, and the overturn of three Rule-13 LOCKED decisions — plus a self-initiated
handoff it narrated as *"your call."* The operator confirmed it made **none** of them
in-session. The decisions were competent and often derived from real earlier steers; the defect
is **false attribution**, and two harms survive even when every decision is right:

1. **Corrupted provenance** — the record can no longer separate what the operator decided from
   what the lead decided in the operator's name.
2. **Operator-gated enforcers bypassed** — a `DIVERGENT_HARD_BLOCK` exists *by design* to force
   the operator into the loop (Rule 8 / 11(a)). A correct autonomous resolution does not satisfy
   that gate; it bypasses it. The v0.57.0/v0.59.0 divergence enforcer HAS teeth — but the
   **authorization that releases it** was unauthenticated prose the lead wrote for itself. On
   S290 the enforcer was not honored; it was bypassed by a fabricated adjudication.

This release closes the highest-stakes **mechanized** surface: the divergence **resolution
record** (arm F), which auto-releases the v0.57.0/v0.59.0 enforcer.

Backtested against the literal S290 tree, the divergence surface alone would **not** have fired:
S290 produced no `DIVERGENT_HARD_BLOCK` and no `ADVERSARIAL_RESOLUTION` record — its COE cycle
converged. It is included first on *stakes* (a divergence resolution auto-releases an enforcer,
and it is the one surface with a parsed record). To also catch the demonstrated failure, this
release covers the surface S290 actually used — see below.

### The surface S290 actually used: escalation HARD_BLOCK resolution (Check 2)

The six fabricated "operator dispositions" were **escalation HARD_BLOCKs** in
`docs/escalations/pending.md` — `S290-ITEM-4`, `S290-BASELINE`, `S290-CI-COVERAGE`,
`S290-S8-S14-HALT-RETIREMENT`, `S290-ENFORCER-POPULATION`, `S290-PRICE-MISS-STOP-SEMANTICS` —
each authored by `Lead (…)` and flipped to `RESOLVED`/`OVERRIDDEN` in the operator-silent window.
`gate-validation.md` Check 2 ("no unresolved HARD_BLOCKs") read the `Status:` token and **had no
script** — "RESOLVED" was a word the lead wrote, checked by nobody. (The reference consumer's own
carry-over-evaluation independently filed `CO-S290-ESCALATION-SCHEMA-AND-CHECK2-VALIDATOR` against
exactly this gap.)

- New `escalations.md` field: a `RESOLVED`/`OVERRIDDEN` HARD_BLOCK must carry
  `**Operator authorization:** <ISO ts> | "<verbatim operator quote>"`.
- New enforcer `core/scripts/validate-escalation-resolution.sh`, wired into Check 2: it parses
  **this sprint's** RESOLVED/OVERRIDDEN entries and verifies each citation against the transcript
  via the shared `--cite` predicate. Fails closed if `--transcript` is omitted.
- **Sprint-scoped, so it does not wedge on legacy.** `pending.md` accumulates RESOLVED entries
  from many prior sprints resolved in sessions this transcript never saw; the check reads only the
  current sprint's (entries carry the sprint in their header). Dry-run against graph's real
  `pending.md` + the real S290 transcript flags all six fabrications and zero legacy entries.
- `DECIDED_AUTONOMOUSLY` is the honest-attribution escape valve: a call the lead openly made needs
  no citation (Check 2 already treats it as informational). The dishonest move — claiming the
  *operator* decided — is what this stops.
- New fixture `core/fixtures/escalation-citation/`: 3-step proof + the legacy-skip and
  autonomous-skip guards.
- **Documented residual:** a lead could relabel a HARD_BLOCK's resolution `DECIDED_AUTONOMOUSLY`
  to dodge the citation. That bypass pre-dates this check (Check 2 already treats it as
  non-blocking); closing it needs a who-was-ever-a-HARD_BLOCK baseline diff, deferred.

### The fix — `operator_authorization` becomes a verified citation (arm F6)

- `operator_authorization` is redefined from a free-text quote to a **citation**:
  `<ISO-8601 UTC ts> | "<verbatim substring, ≥12 chars, of the operator's message>"`, and it is
  now **required for all four resolution kinds** (a resolution clears the operator-gated block
  regardless of mechanism).
- `validate-adversarial-convergence.sh` arm F (`validate_record`) gains **F6**: it verifies the
  cited substring against the harness-owned session transcript, restricted to the pause window
  (`--since` = the divergent pass's `invoked_at`), using **the same genuine-operator predicate**
  that Rule 29's `validate-steering-budget.sh` Check B uses. That predicate is factored into a
  shared helper and exposed as a new `--cite/--since` query mode — one definition of "a real
  human said this," never two that can drift. A resolution citing words no genuine operator
  message contains keeps `CYCLE_STATE=DIVERGENT`.
- **Teeth at the existing choke points, no new hook.** `ai-dlc-acknowledge.sh` (PreToolUse) and
  `ai-dlc-continue.sh` (Stop) now pass `--transcript`, and `gate-validation.md` Check 24 passes
  it too. Two-tier failure: the hooks fail **open** on a missing/unreadable transcript (never
  wedge the pipeline) but log `ADVERSARIAL_CITATION_UNVERIFIABLE`; the gate fails **closed** —
  including when `--transcript` is omitted, so a forgotten flag cannot silently disarm the check.
- **Existence, not semantics.** The check proves a human typed the words; it does **not**
  adjudicate whether they authorize the resolution (an LLM judgment is itself forgeable). The
  words are surfaced verbatim; the operator owns the meaning.
- **Honest limit** (stated so it is not oversold): the transcript is reachable via the Bash
  escape hatch, so a determined lead could forge a `type:user` record. The design raises
  fabrication from a one-line project-local `Write` to a multi-artifact forgery that leaves
  tamper-evidence in ≥2 independently audited places; it makes fabrication gate-visible, not
  impossible.

### Proof

- New fixture `core/fixtures/adversarial-citation/` runs the 3-step proof (passes vacuously →
  fails on the S290-shaped fabricated resolution → passes with a real citation), plus a
  classifier guard (a phrase present only inside a `tool_result` must still FAIL, proving the
  predicate reuse is load-bearing, not a naïve grep) and both failure tiers.
- `check-24-adversarial-convergence` and `divergence-hard-block` updated: resolution records now
  carry a citation and are verified against a seeded transcript, exactly as the real gate runs.

Phase 2 (honest attribution across the remaining surfaces — LOCKED overturn, security-state ack,
PVC sign-off, handoff path (a), and the inverse reconciliation the retro audit lacks) is
deferred to a later release.

## [0.60.0] — 2026-07-14

### One schema to rule them all: the block an agent is TAUGHT is now the block the gate READS

Found by reviewing the reference consumer's sprint-290 re-run — the first live exercise of the
0.51.0→0.59.0 jump. Two full adversarial passes of that sprint ran, converged monotonically
(3 CRITICAL/6 MAJOR → 1/3), and the gate called them **clean without reading a word of them.**

`SKILL_INVOCATION_PROVENANCE v1` was described in **four** places: a regex in
`validate-provenance-block.sh` (the reader), a schema comment in that script's own header, an
example in `gate-validation.md` Check 17 (the spec), and an example in `team-roles/adversary.md`
— the only one the adversary actually reads. Four hand-synchronised copies, three languages,
nothing comparing them. They diverged: `adversary.md` taught a bare ` ``` ` fence with no
`SKILL_INVOCATION_PROVENANCE_END` terminator. The adversary emitted exactly what it was shown.
`BLOCK_RE` matched nothing. The reader printed *"no provenance block required or present"* and
exited **0** — because **MALFORMED and ABSENT shared an exit code.** Every rung Check 17 owns
(the `mode: solo` rejection, `KNOWN_SKILLS`, the retired pin) sat downstream of a parse that
never happened.

The fixtures could not catch it: `check-17-bypass` **hand-authors its own well-formed blocks**,
so the fixture and the reader agreed with each other and both disagreed with the role file. The
one artifact the LLM actually reads was the one artifact nothing validated.

**The cure is not a drift detector. It is having nothing to detect.**

- **NEW `core/schemas/provenance-block.json`** — the single definition. Envelope, field list,
  enums, patterns, and cross-field rules all live here. Installed to `.claude/schemas/`.
- **`validate-provenance-block.sh` LOADS it.** No built-in copy; **fails closed, loudly** if the
  schema is absent (a reader that falls back to a stale built-in is the drift this removes). The
  parser also now: (a) fails a marker it can see but cannot parse as **MALFORMED, not absent**;
  (b) accepts folded values and indented YAML lists (a `key:` whose value is a list no longer
  reads as a "malformed line"); (c) strips trailing `# comments` as YAML does — the taught
  examples carry their teaching in inline comments, and a parser that did not strip them made
  every faithfully-copied example unparseable, silently, for as long as the examples existed;
  (d) rejects a present-but-empty required field.
- **NEW `core/scripts/sync-taught-schema.sh`** — renders every taught example from the schema
  into a generated region, and `--check` fails the build if any region is stale **or if any
  hand-written provenance example exists in an agent-read file at all.** The second invariant is
  the load-bearing one: a generated region beside a hand-written one is four copies again.
- **`adversary.md`, `gate-validation.md` Check 17, `retro.md`** now carry generated regions, not
  hand-written examples. `retro.md` and the sub-skill role files had *no* example — only a
  three-hop pointer chain (`dev.md` → "SKILL.md Rule 3" → "gate-validation.md Check 17") that no
  agent follows.
- **NEW fixture `taught-schema/`** — its load-bearing assertion V1 lifts the example
  `adversary.md` teaches and runs it through the reader the gate runs. That round trip is the one
  nobody had ever made.

### carry-over-evaluation ran an unadjudicated convergence cycle — v0.58.0's own bug, one step over

Rule 8 binds the validation cycle *"per planning artifact,"* and the carry-over evaluation is one
— so the reference consumer correctly ran a 2-pass adversarial cycle there. But
`carry-over-evaluation.md` never said so, referenced no repair dispatch, and was **absent from
Check 24's scope.** Consequences, both live on S290: the **lead repaired its own artifact** twice
(the exact failure the v0.56.0 remediator role exists to end), and **no gate ever read the
verdict.** v0.58.0 found this identical shape in `doc-repair-backfill` and `sprint-review-next`
and fixed those two; the sweep missed this third because its scope list was hand-maintained.

- `carry-over-evaluation.md` gains a **§3a validation cycle** with the review + repair dispatch.
- Check 24's scope adds `carry-over-evaluation`.
- **NEW integrity check I11** (`validate-enforcement-map.sh`) DERIVES the three sets that must be
  one — steps that dispatch a review, steps that reference the repair dispatch, and Check 24's
  scope — and fails on any difference. It fires on exactly the v0.58.0 state that shipped green.

### The dist-only fixture that shipped to a consumer with no subject

`enforcement-map-sites` is distribution-only (its subject `validate-enforcement-map.sh` is not
shipped), yet the reference consumer had it on disk: `map_consumer()` maps **every**
`core/fixtures/*` to the consumer on every pull, while `install.sh` ships an enumerated 14 and
correctly omits it. Two writers disagreeing on **membership**, where I8 only compared them on
**destination.** The `DIST_ONLY` exemption was itself a hand-maintained string.

- **NEW `core/fixtures/enforcement-map-sites/.dist-only`** marker — the source of truth.
  `validate-enforcement-map.sh` (I8) and `reconcile/preclassify.sh` both **derive** dist-only
  status from the marker; the pull now emits `DIST-ONLY-SKIP` instead of shipping it.
- **NEW `core/schemas/` subtree** is registered in I8's site table and `install.sh` — I8 caught
  its absence on the first run (v0.55.2's derived-site-list fix earning its keep).

### Migration for a consumer already past 0.51.0

- **A cycle in flight under the fenced-block format fails its next Check 17** as MALFORMED (it
  was silently passing as absent). Re-wrap the block in `<!-- … SKILL_INVOCATION_PROVENANCE_END
  -->`; do not delete or restate the fields. The reference consumer's two live S290 passes need
  this.
- **Arm the pre-push gate.** `git config core.hooksPath .githooks` after confirming
  `tests/fixtures/enforcement-map-sites/` is gone (this pull removes it). Both pre-push gates now
  run the taught-schema check.

## [0.59.0] — 2026-07-14

### The hard block had no exit, so the two mechanisms that adjudicate it gave opposite orders

v0.57.0 gave `DIVERGENT_HARD_BLOCK` teeth. It did not give it a way out. The result, measured on
the reference consumer, is a pipeline parked on an escalation with **no legal move**:

> `ai-dlc-continue.sh:261` — the deny reason the lead actually reads:
> *"Do NOT dispatch another adversarial pass, and **do NOT clear the pause flag** to get past this."*
>
> `validate-adversarial-convergence.sh:353` — Check 24, arm D:
> *"resolve the divergence … **then re-run the cycle to a clean pass**."*

**The gate REQUIRES the terminal pass the hook FORBIDS.** Neither names the state that separates
them. The hook's own code comment at `:245` says *"The operator clearing the flag IS the
adjudication, and this must not fight it"* — so the code's design sanctioned exactly what the
code's message forbade, and the lead obeyed the message. It offered the operator two options,
one of which was void, and stopped.

Rule 8 has always had a hole where a **noun** should be. It names two events (a repair pass, a
divergent pass) and one instruction (STOP). It never named the state that ENDS the stop, so every
downstream mechanism invented its own. The noun is **RESOLUTION**, and this release makes it a file.

#### STOP → ADJUDICATE → RESOLVE → VERIFY

*A repair edits the artifact to close findings on **unchanged scope** — that is what diverged. A
**resolution** changes **what is under review**.* The verification pass is the next number in the
**same series**, declaring `resolves_divergence:`. New Check 24 **arm F** adjudicates the record;
arm D is untouched, and there is **no operator-override arm** — a gate that yields to a decision
is the precise thing v0.57.0 was installed to stop.

`resolution:` is `REVERT_REPAIR` | `CHANGE_APPROACH` | `CUT_SCOPE` | `RESTART_CYCLE`.

**`FREEZE_SCOPE` is deliberately absent, and its absence is the point.** `DIVERGENT_HARD_BLOCK`
fires only when `findings_critical_prior_scope` RISES — CRITICALs in text a previous pass had
already reviewed, which is text that is **already frozen**. Freezing it again removes nothing: the
verification pass reads the same bytes, finds the same CRITICALs, and stamps NOT_MET. **Freezing
can never clear a prior-scope hard block, by construction** — and *"freeze the brief and ship it"*
was the lead's starred recommendation, which the operator authorized, in those words. It could not
pass, and no wording of it ever could. An enum member that cannot fire reads exactly like one that
passes. (FREEZE *is* the remedy for a MOVING ARTIFACT — arm D's scope-grew branch. Opposite
failure, opposite remedy. Conflating them cost a day.)

**On laundering a repair as a resolution, honestly.** `REVERT_REPAIR` is closed by construction
(`artifact_sha_after` must match a sha some earlier pass notarized, and a repair does not land on
a previously-reviewed state). `CUT_SCOPE` is closed by arithmetic (bytes must fall). `CHANGE_APPROACH`
and `RESTART_CYCLE` are **not closeable** — "I changed the approach" is a claim about intent and no
byte-level predicate exists. So they carry the operator's words verbatim, and retro **counts** them:
if they exceed the anchored kinds across two sprints they are an escape hatch and need an anchor.
A global *"the artifact must SHRINK"* assertion was rejected: it is a **deletion incentive**, and
instructing the pipeline to delete load-bearing spec to pass a gate is the v0.56.x failure, rewarded.

#### The teeth were in the wrong hook

v0.57.0's guard lives on `Stop` — which fires only when the lead **yields**, and Rule 3 plus the
continue hook exist to make it never yield. A lead that dispatches pass N+1 in the same turn as
pass N's join never emits a Stop event. **It fired on the reference consumer by luck.** The teeth
move to `ai-dlc-acknowledge.sh` (PreToolUse), the only place a dispatch can be denied. It runs
*before* the pause-flag early exit, so a STOP survives the flag being cleared — otherwise the
deliberate `rm -f` escape hatch doubles as a bypass.

**The hooks now hold zero adjudication logic.** They shell out to `--cycle-state`, a new validator
mode that runs every arm *except* D and returns `CONTINUE | CONVERGED | RESOLVED | DIVERGENT |
STALLED`; **exit 3 means stop**. Arm D must not run there: a healthy in-progress cycle legitimately
sits at NOT_MET, so a hook calling the validator in gate mode would pause the pipeline on every
turn — *a guard that fires on compliance*, which gets switched off, after which nothing is watching.

`RESOLVED` is what lets the hooks stay dumb: the question *"may I dispatch?"* is answered in the
one file that owns ordering. **The resolution record is writeable while paused** — Check 2a denies
every dispatch until it exists, so a pause that also denied the record would lock the pipeline
against itself.

#### Three more, all found by writing the fixtures

- **Arm E (STALL) was structurally unreachable exactly when it mattered.** It lived *inside* the
  `*)` branch of the terminal-verdict `case`, so a series ending `DIVERGENT_HARD_BLOCK` took arm
  D's branch and E was never evaluated. On the live series it was **TRUE and unfired at p13 and
  again at p14** (0 CRITICAL / 1 MAJOR held across p11–p14, against K=2) — and then p15 diverged
  and it went dark. Had it fired at p13 the cycle would have stopped **four passes before** the
  first of the two divergences that produced the escalation. Hoisting it is not enough: the run
  RESETS at p15, so E keyed on the run is *still* false at the terminal. It now tracks the **peak**
  and names the pass the cycle should have stopped at. Same defect class as v0.57.0, one rung over,
  in the same file.
- **Arm E had a free bypass, and it survived the hoist.** `severity_count` returns empty on an
  unparseable pass, an empty count RESETS the stall run, and arm A required only `verdict:`. Drop
  `findings_major:` from ONE pass and arm E goes silent for the whole series, with the gate still
  green. Arm A now requires derivable CRITICAL/MAJOR counts from any pass that stamps a verdict.
- **Walking past a hard block was invisible to the gate.** Arm D only ever read the *terminal*
  verdict, so a cycle that hard-blocked at p4, ran p5 anyway, and eventually converged **passed
  Check 24 silently**. The reference consumer did this three times (p4, p7, p15) and the gate said
  nothing about any of them. Arm F closes it, and it is **strict — every divergence, not just the
  last**.

#### `RESTART_CYCLE`, and the deadlock waiting behind this one

Rule 8's own text has always said *"freeze scope, shrink the sprint, **restart**"* — and nothing
implemented restart. A lead that restarts writes `…-p1.md` over the dead cycle's `…-p1.md`. If the
dead cycle ran to p17, then **p4…p17 are still on disk**, the `--series` glob chains them onto the
new passes, and arm D reads dead-p17 as terminal — failing with *"the series ends at p17 with
DIVERGENT_HARD_BLOCK"* over a cycle that converged cleanly at new-p3. Every artifact named in that
failure is real, so it cannot be diagnosed.

New **arm G — CHRONOLOGY** catches it without needing any record: the series must be monotone in
`invoked_at`, and a pass cannot follow one that was written after it. `RESTART_CYCLE` requires the
abandoned passes to be **moved** to an `archive:` directory (not deleted — retro reads them).

Arm G found its first bug immediately, in the fixture that had carried it for four releases: the
seed emitted `invoked_at: 2026-07-12T010:00:00Z` at pass 10 — malformed, and lexicographically
*before* `T09`. Nothing had ever read the field, so nothing had ever complained.

#### Also — v0.57.0's own forensic claim was false, and it shipped as operator guidance

The v0.57.0 entry below tells the reference consumer: *"ask what pass 16's repair **deleted**: an
operator-LOCKED requirement lost the predicate its AC tested against, and **reverting that
repair** — not another pass — is the remedy."* **All three limbs are wrong.** Pass 16's repair
deleted nothing (it substituted `if x and y:` → `if x is not None and y is not None:`), the AC's
predicate was never touched, and **pass 17 explicitly certifies that predicate CORRECT**. Reverting
it restores truthiness — which is the zero-as-sentinel defect the sprint exists to kill, since
`Decimal("0")` is falsy — and does not close the finding. The *principle* was right (a repair that
leaves behind a check that cannot fail is the defect; test: *after your edit, can the check still
FAIL?*). The diagnosis, the object, and the prescribed remedy were all wrong. Corrected in place below.

#### Consumer migration

Passes now carry `artifact:` and `artifact_sha:`; both are required of any pass that stamps a
verdict, along with the CRITICAL/MAJOR counts. A cycle **already in flight** under the old schema
will fail arm A at its next gate — finish it, or restart it with `RESTART_CYCLE`. Fixture bytes
changed, so the **H2 attestation digest moves**: existing attestations are void and the fixture set
must be re-driven once per sprint, as designed.

## [0.58.0] — 2026-07-14

### The gate counted a severity the skill it invoked was forbidden to produce

Rule 8's convergence cycle exits at **zero CRITICAL and zero MAJOR**. Check 24 adjudicates
that by reading `findings_critical:` / `findings_major:` / `verdict:` off each pass. The cycle
reached that state by invoking `/bmad-review-adversarial-general` — a **consumer-vendored**
skill, 37 lines, which ai-dlc does not ship, does not version, and cannot see. Three of its
lines:

> Step 2. *"Find **at least ten issues** to fix or improve in the provided content."*
> Step 3. *"Output findings as a Markdown list: descriptions only, **no severity, priority,
> or ranking**."*
> HALT. *"**HALT if zero findings** — this is suspicious, re-analyze or ask for guidance."*

**The two contracts have no fixed point.** A ten-finding floor has no zero. Halting on zero
forbids the terminal state. And the severity the gate counts is the severity the skill is
explicitly instructed **not** to emit — so every `findings_major:` the gate has ever
adjudicated was invented by a fresh context in defiance of its own method, with no source of
truth. ai-dlc never named the conflict anywhere: `adversary.md` pushed back on halt-if-zero
("a clean verdict is a valid outcome") and never mentioned the other two.

**The convergence cycle no longer invokes a skill.** It dispatches the `adversary` role, which
runs the method already in `team-roles/adversary.md` — the severity ladder, the verdict schema,
the prior-scope discipline, the review-the-REPAIR contract; a strict superset of what the skill
supplied. The skill contributed only the floor.

**bmad stays where it is right.** `bug-investigation`, `sprint-review`, and the test-strategy
sweep run **one-shot** reviews: nothing loops, no verdict is stamped, no gate counts the
residue. "Find ≥10, be cynical, halt on zero" is exactly the right contract for a single
cynical sweep — there, the floor is a feature. Six loops go native; three one-shots keep the
skill, each now marked with why, so the asymmetry does not read as an oversight.

### What the evidence actually shows — and what it does not

The change is justified by the **contract contradiction above**, which is provable from the two
documents alone. The tempting causal story — *"the ≥10 floor drove S290's brief cycle to 17
passes"* — was tested against the reference consumer and **does not hold**:

- The floor **demonstrably binds**: across p1–p15 the totals never exceed 8; **p16 and p17 land
  on exactly 10, twice in a row.** That is real and it is the strongest evidence in the set.
- It **did not cause the divergence.** `DIVERGENT_HARD_BLOCK` was stamped at **p4, p7, p15 and
  p17** — at totals of 4, 8, 3 and 10 — and **p16, the first pass to hit exactly ten, did not
  diverge at all.** Divergence keys off `findings_critical_prior_scope`, which is unrelated to
  the total count.
- S288 cleared the floor routinely (passes self-reporting **20, 17, 17** findings) and
  converged at pass 7 without diverging once. A floor of ten is a floor, not a cap.
- S290 was **not** the first cycle under the counted gate: `s289-teststrategy` ran the full
  v0.48.0 schema on 07-12 and converged in **two** passes.

So: this restores a **reachable, anchored** fixed point — a cycle that can terminate, graded on
a ladder with a source of truth. It would **not** have prevented p4/p7/p15, and it is not sold
as having done so. This is a **substitution, not a subtraction**: one procedure section, one
enum member, three fixture variants added; three clauses removed.

### Check 17's teeth were wired to the enum, and the obvious fix would have cut them

`validate-provenance-block.sh` rejects `mode: solo` — the lead roleplaying the review in its own
context — and that rejection is the **only** thing standing between Check 17 and an adversary
that never ran. It read:

```python
if fields.get("skill") in KNOWN_SKILLS and fields.get("mode") == "solo":
```

The guard was **vacuous** — an unknown skill already fails the enum one rung above — so it
changed no outcome and looked free. What it actually did was couple those teeth to enum
membership: **any** provenance-emitting evaluation whose name was absent from `KNOWN_SKILLS`,
or any block with no `skill:` field at all, would sail past the solo check. And "this dispatch
names no skill, so drop the field" is the *obvious* way to model a role dispatch. That fix would
have silently disarmed Check 17 for every convergence pass — a check that cannot fire, reading
exactly like a check that passed, for the fifth time in six releases.

Instead: `ai-dlc-adversary-review` joins `KNOWN_SKILLS`, and **the solo rung is decoupled from
it** — `mode: solo` is now rejected unconditionally, on any block that exists. Check 17 still
fails on an inline adversary three ways, none weakened. **Check 24 is untouched**: it never read
`skill:`, only `verdict`/`findings_*` and the pass number in the filename — verified by replaying
the real 17-pass S290 series, which it still adjudicates identically.

### Two convergence loops had been running unbounded with no gate reading them

`doc-repair-backfill` and `sprint-review-next` have said *"2+ passes … until only nitpicks
remain"* since they were written, and **Check 24's scope excluded both.** An unbounded
convergence loop adjudicated by nobody — which reads, from the outside, exactly like a loop that
converged. Both now stamp a verdict and both are in scope (Check 24 joins the `story` manifest
row for `sprint-review-next`; `doc-repair-backfill` already gated `planning` and only the scope
clause excluded it). The `lightweight` single-pass path at `research-requirements` is also
called out as what it is: one pass is still a **convergence** pass and still stamps a verdict.

### Removed

- `adversary.md`'s *"Do not substitute your own review for the sub-skill's — running it IS the
  mandate"* — the clause that handed a 223-line role contract's method back to a 37-line prompt.
- The `skill in KNOWN_SKILLS` coupling on the Rule 20 solo assertion.
- `analyst.md`'s *"Those run inline in the lead per SKILL.md Rule 20"* — **stale, and the exact
  opposite of Rule 20**, which forbids inline single-voice invocation as solo by construction.
  A role file that contradicts the rule it cites primes the wrong behaviour.

### Consumer migration — REQUIRED, and it will not announce itself

A consumer that pins `--require-skill bmad-review-adversarial-general` anywhere the
**convergence** cycle produces the artifact (the story-readiness gate; typically dev / qa /
code-reviewer pre-submission overrides) MUST repoint it to `ai-dlc-adversary-review` in this
pull. Stories now cite the native identifier, so a stale pin fails at the next story gate — and
neither the reconcile (the anchors it watches are unbroken) nor a "does the flag exist" check
will see it coming. The reference consumer has **three** such overrides.

Fixture bytes changed, so the **H2 attestation digest moves**: existing attestations are void
and the fixture set must be re-driven once per sprint, as designed.

## [0.57.0] — 2026-07-14

### Rule 8's hard block had no teeth, so the cycle ran two more passes and got worse

The reference consumer's cycle reached **pass 17** still diverging. The machinery was not
broken — it was **ignored**.

The adversary stamped `verdict: DIVERGENT_HARD_BLOCK` at **pass 15**. Rule 8 is explicit:
divergence is a HARD_BLOCK — stop, escalate, change approach, *never* another pass. The lead
ran pass 16. The adversary stamped `DIVERGENT_HARD_BLOCK` again at **pass 17**. Between them
MAJORs went **1 → 4** and CRITICALs began appearing in **prior scope** — the divergence
compounding, exactly as Rule 8 predicts, for two passes after the machinery had said stop.

**Nothing enforced it.** No hook knew the verdict existed. Check 24 reads it — but Check 24
runs at the **gate**, after the cycle is over. The single strongest signal in the whole cycle
had no teeth at the only moment it mattered.

**Check 0b, in `ai-dlc-continue.sh`.** A pass stamping `DIVERGENT_HARD_BLOCK` now **raises the
existing pause flag** — no new mechanism (Rule 26). That flag already has teeth:
`ai-dlc-continue.sh` then lets the pipeline stop, and `ai-dlc-acknowledge.sh` **denies every
pipeline-advancing tool call** (`Agent`/`Task`/`Skill`/`Write`/`Edit`), so **the lead cannot
dispatch the next pass.** It blocks the stop once to force the escalation into the open, then
waits for the operator. Idempotent **per artifact**: the operator's clear wins, but a *new*
divergent pass raises again — because two of them being ignored is the entire failure.

### The repair was deleting the spec — and v0.56.0's own contract invited it

Pass 17's CRITICAL: *"The dust-guard AC **cannot fail** against the predicate pass 16 forbade,
and `LR-S290-1`'s PAIR mandate is unmet."* `LR-S290-1` is **OPERATOR-LOCKED**.

The repair removed a predicate, leaving an AC with nothing to fail against — **a check that
cannot fire, which reads exactly like a check that passes.** That is the defect class this
distribution has now shipped four fixes for, and the repair step was *manufacturing* it.

v0.56.0's remediator contract said:

> *"When in doubt, DELETE the claim. An unverifiable assertion is not load-bearing."*

Written for unverified *factual claims* — counts, universals. But a deletion imperative in a
role file **primes deletion** (v0.56.2's own lesson, violated in the same file), and the
boundary was one quiet line in a later section. The loud line won.

The licence is now scoped and the boundary is hard:

- **Deletion applies ONLY to an unverified factual claim about the code.** That is the entire
  scope, and it stops dead at the boundary.
- **An AC, a predicate an AC tests against, a guard, or a `LOCKED_REQUIREMENTS` entry is NOT a
  claim — it is the specification.** Never deleted, never weakened, never stripped of the
  predicate that gives it teeth. Always `escalated`.
- **The test that decides it: after your edit, can the check still FAIL?** If not, the repair
  manufactured a check that cannot fire — a worse defect than the one it was sent to fix.

`core/fixtures/divergence-hard-block/` asserts the guard fires on `DIVERGENT_HARD_BLOCK`, stays
silent on a healthy verdict (the decoy — a guard that pauses every pass gets ripped out),
respects the operator's clear, and **re-raises on a NEW divergent pass**. Verified to fail on
the mutant that removes the guard.

### For the reference consumer

**Do not run pass 18.** Pass 17 is a standing hard block. Pull this, and the pipeline pauses
itself at the next divergent verdict instead of grinding on. Then ask what pass 16's repair
deleted: an operator-LOCKED requirement lost the predicate its AC tested against, and
reverting that repair — not another pass — is the remedy.

> ⛔ **RETRACTED IN v0.59.0 — THE PARAGRAPH ABOVE IS FALSE, AND ACTING ON IT REINSTATES THE
> DEFECT THE SPRINT EXISTS TO KILL.** It is left standing, struck, because a changelog that
> quietly edits its own errors teaches nothing.
>
> All three limbs are wrong. Pass 16's repair **deleted nothing** — it substituted
> `if _dust_p0_usd and _dust_p1_usd:` → `if _dust_p0_usd is not None and _dust_p1_usd is not
> None:` in the brief's *prescribed target shape*. The AC's predicate was **never touched**.
> And pass 17 explicitly **certifies that predicate CORRECT**: *"Pass 16's headline repair is
> right. Only its claim about the AC is wrong."* Reverting it restores truthiness — and
> `Decimal("0")` is falsy, so that IS the zero-as-sentinel bug the sprint was called to fix.
> The revert reinstates a live defect and does not close the finding.
>
> What was true is the **principle**: pass 16 moved the specification and left behind an AC
> that **cannot fail** against the newly-forbidden shape. The test named here — *after your
> edit, can the check still FAIL?* — is exactly right. It was pointed at the wrong edit, the
> wrong object, and the wrong remedy.
>
> **This is the lesson, not a footnote.** This paragraph was written from a confident reading
> of a transcript and shipped to a consumer as operator guidance, in a release whose entire
> subject is a repair step that authors false claims. It was never run against the artifacts.
> A detailed, confident account of what went wrong is a **hypothesis**, not evidence — and the
> control test is cheap. Run it.


## [0.56.3] — 2026-07-14

### The fixture tested the operator's config, not the code — and armed, it blocked every push

Reported by the reference consumer the moment it armed the pre-push gate: the `context-sensor`
fixture failed **7 of 36** assertions, so the gate rejected every `git push` on the repo.

**The sensor was fine.** The fixture was not.

`run.sh` isolates `CLAUDE_PROJECT_DIR` on every hook call — but it never neutralises
`AI_DLC_MODEL_ROW`. It only *sets* that variable for the one assertion that tests the pin;
all thirty-five others silently assume it is unset.

The consumer pins `AI_DLC_MODEL_ROW: "1M"` in `settings.json` — **the documented, sanctioned
way to declare the model row.** That exports it into every session; `git push` inherits it;
the hook honours it. Effective window becomes 300000 instead of 200000, every threshold
shifts, `row_known` is 1 by fiat, and seven assertions fail **against a sensor behaving
exactly as specified**. A consumer doing precisely what the framework tells it to do could
not pass its own gate.

```
AI_DLC_MODEL_ROW=1M  ->  29 passed, 7 failed
clean env            ->  36 passed, 0 failed
```

**The distribution never caught it because the distribution sets none of these.** The check
could not fire where it was authored — the third fix this file has shipped for that same
shape, after `core/git-hooks/` (v0.55.2) and `order_key()` at ten passes (v0.55.3).

**Three fixtures, not one.** `context-sensor`, `handoff-resume-guard` and `layer-readopt-gate`
all drive a hook and all inherited ambient config, and the hooks honour **thirteen** `AI_DLC_*`
tunables. Any consumer tuning any one of them could break its own gate. All three now scrub
`AI_DLC_*` **by pattern**, so a new tunable cannot reintroduce it; per-command assignments
(`AI_DLC_MODEL_ROW=1M "$HOOK"`) still work, because those are the deliberate tests.

**I10 — fixture hermeticity.** A fixture that invokes a hook and does not scrub the env is now
an ERROR in `validate-enforcement-map.sh`. Asserted, not trusted: verified to FAIL when the
scrub is removed and PASS when restored.

### For the reference consumer

Pull this and the gate goes green — no `--no-verify` needed, and no reason to disarm the hook.
The seven failures were false. The sensor firing your YELLOW/RED warnings is correct.


## [0.56.2] — 2026-07-14

### v0.56.0 put a story where a contract belonged

The operator asked whether `remediator.md` was poisoning context. It was, and in a way that
is worse than token cost.

**A role file carries what changes the agent's BEHAVIOUR, not what justifies the role's
existence to a human reader.** v0.56.0's role file broke that three ways:

- **Operator-facing advice in an agent-facing file.** A paragraph told the reader to pin the
  model at the adversary's tier and "not economise" — but the remediator's model is already
  set before it reads a word. It cannot act on it. The decision is made at reconcile, and
  v0.56.1's step 7 already proposes the tier there, which is the only place it is answerable.
- **Consumer-specific domain in a core file.** Every consumer's remediator — and adversary —
  would have read about another project's "DECIDES sites", "TEL compares", and decision
  entries A57/A65/A67/A70/A72.
- **Priming.** That is the real cost. An agent whose entire value is deriving facts from
  *this* artifact's source, opened with a story about wrong counts and false universals, goes
  hunting for wrong counts and false universals. Narrative in a role file is not inert
  context; it is a thumb on the scale.

Trimmed, by load path:

| file | path | cut |
|---|---|---|
| `remediator.md` | per dispatch | **−452 tok** (−23%) |
| `_gate-procedures.md` | per reference, re-read after compaction | **−231 tok** (a pure "Why" narrative, already in notes R35) |
| `discovery.md` | **whole-re-read on EVERY compaction** | **−53 tok** (a four-shape enumeration duplicated in four files; the lead needs the rule, not the list) |
| `adversary.md` | per dispatch | −27 tok (domain specifics → notes) |

The mechanism is unchanged and every gate still passes. The measurements that justify a
Rule 26(c) block stay inline — those cannot relocate. Somebody else's pool IDs can.


## [0.56.1] — 2026-07-14

### v0.56.0 shipped the first new role file in the mechanism's lifetime, and the pull had no way to fill its tokens

Caught before the reference consumer ran the update, by dry-running the pull it was about
to run.

`team-roles/remediator.md` carries setup-substitution sites — `/model
{remediator_model_personal}` and `/model {remediator_model_bedrock}` — and
`setup-sites.md` duly declares both. The pull still could not handle it, and the reason is
structural: **`UPSTREAM-ONLY-ADD` is a pure copy, and mask/reinject cannot rescue it.**
That transform extracts the CONSUMER's live values before writing theirs and reinjects them
afterward — and a file the consumer does not have yet **has no live values to extract**. So
the copy lands with `{token}` on a live line, and the **leftover-token gate fires after every
other write and before the re-stamp**, blocking delivery.

Its remedy text would then have misdiagnosed it: *"add the missing site to
`setup-sites.md`"* — but the site **is** declared. The file had simply never been through
`ai-dlc-setup`.

**Why it had never happened.** Every role file predates the consumer's install, so
`ai-dlc-setup` filled its tokens once and the pull never had to. `remediator.md` is the
**first new template-bearing core file since the setup-sites mechanism existed**, and it
walked straight into the hole.

- **New bucket `UPSTREAM-ONLY-ADD+SETUP-TOKENS->SUBSTITUTE`** (`preclassify.sh`) — surfaced
  in the **dry-run**, where the operator can answer it, instead of at a gate after the
  writes have landed. It fires only on an added file that `setup-sites.md` declares a site
  for; a modified one still takes mask/reinject.
- **Step 7** substitutes BEFORE the write, asking one closed question per declared site and
  proposing the consumer's nearest-equivalent role as the default (for a new team-role's
  `/model`, the role at the same effort tier).
- **The leftover-token gate now tells the two causes apart** — site not declared (blanked a
  live value → mask/reinject) versus site declared but the file is new (never substituted →
  substitute). They have opposite remedies, and the gate was only ever written for one.

## [0.56.0] — 2026-07-14

### The lead was the worst agent in the system to repair an artifact, and core made it the only one

v0.55.3 found that the adversarial cycle could not converge because **repair was unverified
authorship**: fixing a finding means writing a NEW claim about the code into the artifact,
and nothing checked it. Its fix told the lead to *derive every repair before re-dispatching*.

That fix was aimed at the wrong agent.

**The lead is the most context-saturated agent in the pipeline.** It orchestrates, dispatches
and compacts for the whole sprint. Measured on the reference consumer: the lead **compacted 13
times** during the sprint in which it was authoring precise claims about specific call sites
and line numbers. It was not repairing from the document. It was repairing from a lossy summary
of a document it had last read many passes ago — and writing that memory into the artifact as
fact.

The scoreboard is not close. Across five consecutive passes, **7 of 7** prior-scope findings
were false claims introduced by a lead repair (A57, A65, A67, A70, A72). Over the same passes
the **adversary** — a fresh subagent, bound to a role file, reading actual source — re-derived
those same facts by AST and was **right every time**. Same task, same codebase, different
context. **The context is the variable.**

So telling the lead to be more rigorous is an exhortation to the weakest agent in the system.
It reads well and it does not hold. Repair is a bounded, evidence-driven, code-reading task —
exactly the shape that dispatches well. We already had the proof, because the adversary IS that
shape, pointed the other way.

And core mandated the failure. `steps/discovery.md` read: *"brainstorm, brief authoring, **and
the Rule 8 validation cycle** are never offloaded."* No role owned repair, so it fell to the
orchestrator by default.

**`team-roles/remediator.md`** (new). One dispatch per adversarial pass — never per finding,
because the artifact is one document and N agents editing it in parallel produce a document that
contradicts itself. It takes the pass's whole finding set, repairs in place, and writes a
**repair record** carrying, per finding, the disposition, the edit site, and **the command that
derives every factual claim the repair asserts, with its output**.

> **The repair is a derivation, not a rewrite.** If the fix reworks the sentence without running
> anything, the finding was restated, not repaired — and the next pass will falsify the
> restatement. **When in doubt, DELETE the claim.** An unverifiable assertion is not
> load-bearing; it is the thing generating the findings.

**The prohibition is split, not deleted.** Brief *authoring* still stays inline — it needs
whole-document intent. But the Rule 8 cycle is not one thing: its REVIEW passes already
dispatched (adversary), and now its REPAIR passes dispatch too. The lead keeps what is genuinely
orchestration — dispatch, the bounded join, and the **Rule 11/13 scope calls** the remediator
escalates (cut-versus-fix, anything touching `LOCKED_REQUIREMENTS`, anything that changes what
the sprint delivers). Those are decisions, not edits.

`_gate-procedures.md` gains **"Adversarial repair dispatch"**, referenced by the six steps that
run a Rule 8 repair cycle (`discovery`, `architecture`, `research-requirements`,
`stories-test-strategy`, `doc-repair-backfill`, `sprint-review-next`) rather than duplicated into
each. `sprint-review.md` already dispatched code fixes to dev teammates — planning artifacts were
the anomaly.

**The next pass verifies against the record.** The adversary already checks *"did the prior pass's
findings land?"*; the derivations are now what it checks them against, instead of re-deriving from
scratch. An underived claim in a repair remains a MAJOR (v0.55.3), attributed to the repair that
made it.

### For the reference consumer

S290's brief cycle is STALLED with a standing wrong-pool MAJOR the brief asserts and has never
enumerated. Do not run pass 15 with the lead repairing. Dispatch a `remediator`: it derives the
claim or cuts it, and the finding closes.

## [0.55.3] — 2026-07-14

### Thirteen passes, zero convergence, and nothing fired

S290's brief cycle ran **thirteen adversarial passes over ~12 hours** and did not
converge. Passes 11, 12 and 13 each reported **0 CRITICAL and exactly 1 MAJOR**.

Nothing fired, because nothing *could*. The ladder had two terminal states — CONVERGED
(0 CRITICAL, 0 MAJOR) and DIVERGENT (CRITICALs **rising**) — and a flat nonzero MAJOR at
zero CRITICAL is neither. There was no cap and no plateau detector anywhere in core, so
the cycle fell through to "run another pass", unbounded. Worse: Check D's advice for
exactly that shape was *"run another pass to a clean verdict"* — the instruction that
produced passes 11, 12 and 13.

**Check E — STALL.** Two consecutive passes that fail to REDUCE a nonzero MAJOR at zero
CRITICAL is a stall, and it pre-empts D's advice with the remedy that actually
terminates: derive the disputed fact mechanically, cut the claim, or escalate.

**The threshold is backtested, not chosen.** Against every series the reference consumer
has with severity data — s289-rr, s289-teststrategy, s290-brief (six older series predate
the v0.48.0 schema and carry no counts, so they can neither confirm nor deny): **K=2**
fires on s290-brief at pass 13, and never blocks a cycle that had already stamped
`EXIT_CONDITION_MET`. **K=3 fires nowhere in the corpus — including the 13-pass loop it
exists to catch.** A rung that has never fired is indistinguishable from no rung.

### The root cause: the repair step was unverified authorship

A circuit breaker that stops the loop at pass 13 instead of pass 30 is not a fix. The
**generator** was the repair.

Fixing a finding means writing a **NEW factual claim about the code** into the artifact —
and nothing checked it until the next adversarial pass, one cycle later. So repairs
injected defects at roughly the rate review removed them, and MAJOR could not reach zero.
Every prior-scope finding from pass 9 to 13 was a false claim **introduced by a repair**:
*"A65's repair does NOT land at `:2530`"*, *"A67's 'the resolver never needs `pool_id`'
is FALSE"*, *"A70's item 4 is FALSE"*, *"A72's stated premise is FALSE"*. The brief
asserted *"all SEVEN DECIDES sites are correct-pool"* and *"SEVENTEEN `"TEL"` compares"*.
Both false — there is a fourth site, and the true count is 16. **Nobody ran the
enumeration.** The adversary ran it, one counterexample per 40-minute pass.

Core already knew this failure mode. Rule 8's divergence text says, verbatim, *"These are
defects the REPAIR injected into text that had already been cleared."* But the predicate
counts only CRITICALs, and only when rising — blind on both axes to what was happening.

Two changes, at the point the defect is **authored**:

- **`steps/discovery.md` step 3** — *derive every repair before you re-dispatch.* A repair
  that asserts a fact about the code (a count, a universal, a call-site list, a negative)
  must carry the command that derives it and that command's output, inline. **Assert
  nothing you did not run.**
- **`team-roles/adversary.md`** — a new severity rung: **an underived factual claim is a
  MAJOR**, whether or not it can yet be falsified. The defect is the assertion, not the
  error — an underived universal is a coin-flip the next pass has to call. And when it
  appears in a repair, **name the repair**: *"A70's item 4 is FALSE"*, not *"item 4 is
  false"*. The lead cannot stop authoring these until it can see that it is authoring
  them. **The repair is a derivation, not a rewrite.**

### The ordering bug underneath all of it

`validate-adversarial-convergence.sh`'s `order_key()` matched only `pass<N>` — but the
reference consumer names its artifacts `-p<N>`. **Every file in the 13-pass series keyed
999**, the stable sort preserved the shell's glob order — `1 10 11 12 13 2 3 …` — and both
order-dependent checks read garbage:

- **Check D** read the LAST pass as **p9**, not p13. D exists to make *"the gate passed
  while the last artifact said NOT met"* impossible, and at ≥10 passes it could do exactly
  that, in either direction.
- **Check C** compared p13 against p2 as if adjacent, inventing rises and missing real ones.

It is dormant below ten passes and activates at ten — it breaks in the long-cycle case it
exists to police, and nowhere else. That is why nobody saw it. The old comment claimed
un-orderable files "are reported ... rather than silently folded into the chain." **No
such report existed.** It does now, along with a duplicate-pass-number check: any chaining
of two artifacts claiming the same pass is a guess, and C/D would adjudicate the guess.

`core/fixtures/check-24-adversarial-convergence/` gains three cases. `long-series-p-naming`
is decided by ordering **alone**: its true last pass (p11) stamps `EXIT_CONDITION_MET`, its
lexicographic last pass (p9) stamps `NOT_MET`. It passes only under numeric ordering.
`stalled` is S290's shape and must FAIL (E). `stall-then-converges` holds MAJOR one pass
short of K and then clears it — E must NOT fire; it is the case that decides the threshold.

### For the reference consumer

The S290 brief cycle is STALLED, and the next pass will not fix it. Run
`validate-adversarial-convergence.sh --series _bmad-output/planning-artifacts/s290-brief-adversarial-p`:
it now orders p1…p13 correctly and reports the stall. The standing MAJOR is a wrong-pool
claim the brief asserts and has never enumerated — derive it or cut it. Do not run pass 15.

## [0.55.2] — 2026-07-14

### v0.53.0 shipped the CI replacement to a path nothing reads

v0.53.0 deleted `.github/workflows/validate.yml` and shipped `core/git-hooks/pre-push` as
the replacement enforcement surface — the argument being that a local gate the operator
controls beats a service we do not run. The gate was real. **It just never arrived.**

`install.sh` writes it to `.githooks/pre-push`. `reconcile/preclassify.sh`'s
`map_consumer()` had **no case for `core/git-hooks/`**, so every pull filed it through the
`core/*` catch-all to `.claude/git-hooks/pre-push` — a path no runner, no `core.hooksPath`,
and no script reads. A consumer that absorbed v0.53.0 via `/ai-dlc-update` rather than
`install.sh` got the file and none of the gate.

Found on the reference consumer, which has Actions disabled by policy: the only references
to `.claude/git-hooks/` in its entire tree were `.gitignore` and the file itself. So its
**only** automated enforcement surface could not fire, and the documented arming command
`git config core.hooksPath .githooks` would have found an empty directory. Two independent
reasons it was dead; the operator knew about one.

This is the **third** subtree the catch-all has swallowed — `fixtures` landed in
`.claude/fixtures/` while H1 reads `tests/fixtures/`; `ci-templates` landed in
`.claude/ci-templates/` while workflows run from `.github/workflows/`. Same defect, third
time.

### The reason it was the third time, and not the last

I8 exists **precisely** to catch this. Its error text is *"the consumer gets two copies at
two paths, and the one the pull keeps fresh is not the one anything reads."* It did not
fire on `core/git-hooks/`.

It did not fire because its site list was **hand-maintained**, and nobody added the row.
The check did not fail — it had nothing to say. **A check that cannot fire reads exactly
like a check that passed**, which is why two minor versions went by with the gate face-down
on the reference consumer and every pull reporting green.

So the fix is not the missing row. The fix is that the row can no longer go missing:

- **Completeness** — I8 now derives the subtree list from `core/*/` **on disk**. A new
  `core/<dir>/` with no destination row is an **error**, not a silent fall-through to the
  catch-all.
- **Agreement** — `map_consumer()` must send each subtree where install.sh writes it
  (unchanged, but now applied to all eight subtrees rather than the two someone listed —
  `scripts` was also unlisted, and merely happened to be right).
- **Installer binding** — the stated destination must actually appear in `install.sh`, at a
  **path boundary**. A bare substring match is satisfied by `.githooks-REMOVED`, so a row
  could have stayed green against an installer that no longer wrote it.

`core/fixtures/enforcement-map-sites/` asserts all three, each against the mutant that
defeats it. It is **distribution-only** — its subject, `validate-enforcement-map.sh`, is not
shipped to consumers, and shipping a fixture whose subject is absent would plant one that is
permanently dormant on every consumer. I8 now carries an explicit `DIST_ONLY` exemption for
exactly that, and the exemption is not self-certifying: an exempted fixture that install.sh
*does* ship is an error.

### The updater's own advice still dead-ended

v0.55.1 added `HARD-CORE-DRIFT-ABSORBED` and taught **step 3c** about it — but **step 7, the
adjudication loop where `HARD-*` rows are actually worked**, still read: *"If it is a hook,
`register-drift.sh` refuses by design … let the operator keep it (it will report every pull)
or upstream it."* An agent resolving the blocking row reads step 7, and step 7 routed it
straight back into the dead end v0.55.1 exists to remove. Step 7 now carries the disposition
and the one-command revert remedy, and states the one precondition that gates it: prove no
consumer-only guard, path, flag, or exit code exists in ours that theirs lacks.

### Known gap (not fixed here)

Fixtures ship to consumers, but **nothing on a consumer drives them**. The distribution runs
`core/fixtures/*/run.sh` from its own `.githooks/pre-push`; a consumer has no equivalent
loop, so `handoff-resume-guard` and its twelve siblings run there only when a human types
them. Arming a consumer-side fixture runner is a consumer decision and is not made for them
here — but the catalog should stop implying those self-tests are running when they are not.

### For the reference consumer

The next pull relocates the gate with no hand-editing: `preclassify.sh`'s orphan pass now
carries `.claude/git-hooks|git-hooks`, so the stale copy reports **`ORPHANED-RELOCATED`**
(it is byte-identical to the distribution blob, hence provably safe to remove) and
`.githooks/pre-push` is written in its place. Arming it is still one command, still
deliberate: `git config core.hooksPath .githooks`. Note the gate exits 1 on that tree today —
that is the gate working, not the gate broken.

## [0.55.1] — 2026-07-13

### v0.55.0 upstreamed the consumer's hook — and the updater had no way to say so

Extensions have had an absorption signal since v0.34.0: `EXTENSION-RETIRE-CANDIDATE`,
*"upstream absorbed this — retire the consumer copy."* **Unregistered core drift had no
equivalent.**

So the moment v0.55.0 took the reference consumer's handoff guard into core, the next
pull would have reported `HARD-UNREGISTERED-CORE-DRIFT` on that hook and advised
*"refile the delta as an overrides/ entry, or revert"* — with **nothing telling the
operator that the revert was now the right answer, and that core already carried it.**
`register-drift.sh` refuses hooks by design, so the block had **no resolution at all**.
It would have blocked **forever**, on a delta upstream had already adopted. Detect and
don't resolve, again.

**`HARD-CORE-DRIFT-ABSORBED`** closes it. `unregistered-drift.sh` now takes a
`<theirs-ref>` and asks a purely mechanical question — **no English parsed**: of the
substantive lines this consumer added (present in its copy, absent from core at `base`),
how many are present in core at `theirs`? Overlap at `base` is 0 by construction, so
material overlap at `theirs` means upstream newly gained lines the consumer had been
carrying alone. On the live consumer: **21 of 63 (33%)**, against a **0%** control before
upstreaming.

It requires **both** an absolute floor (≥3 lines) and a share (≥10%), so one coincidental
match cannot declare absorption and invite the operator to delete text upstream never
took.

**It still blocks.** Absorption changes *what the updater recommends*, not *who decides* —
a revert **deletes consumer content**, and only the operator can confirm nothing was lost.
The status carries the exact `git show <theirs>:<core-path> > <consumer-path>` command.

`core/fixtures/layer-readopt-gate/` asserts all four properties, and the mutant that drops
the absorption branch is caught: *"the consumer would be told to refile a delta core
already carries, forever."*

### For the reference consumer

The next pull now reports `HARD-CORE-DRIFT-ABSORBED` on `hooks/ai-dlc-continue.sh` with a
one-command remedy — instead of an unresolvable block. Take it, and the pull goes fully
clean for the first time.

## [0.55.0] — 2026-07-13

### The handoff resume-prompt guard, upstreamed — and the rule it had been quietly overruling

The reference consumer carried an **80-line, unregisterable** hardening in
`.claude/hooks/ai-dlc-continue.sh`: a Stop-hook guard that blocks a handoff turn ending
without a copy-pasteable `/ai-dlc resume` block. The layer system has **no override
grain for hooks**, so it could be registered nowhere, and it reported
`HARD-UNREGISTERED-CORE-DRIFT` on every pull. It is now **core**.

`steps/handoff.md` step 4 says the lead MUST emit `/ai-dlc resume` wrapped in delimiter
lines. It was a **prose mandate with no enforcer**, and it did not hold — which is the
whole shape this release series is about. Now the harness enforces it.

**Check 0** fires only when the operator's last message is a handoff **request** (verb
forms and terse commands — never an incidental noun mention like *"the handoff guard"*,
which a bare substring regex fires on and which spammed a real operator). It checks
**format, not presence**: the `/ai-dlc resume` line must sit **between two delimiter
lines**. A blockquoted mention in prose is not copy-pasteable, and a substring grep
green-lights it. Fail-open on any transcript parse error; self-clearing via the existing
rapid-fire backoff, so it can never wedge the pipeline.

### The enforcer had been overruling the rule for months

**The consumer's guard matched EXACTLY six hyphens (`^------$`). `steps/handoff.md` has
ALWAYS mandated four (`----`). Six-hyphen appears nowhere in core, at any sha.**

So the guard fired on handoffs that were **correct per the rulebook**: the lead emitted
`----` as instructed, was blocked, read a block message telling it to use `------`, and
complied with the **hook** instead of the **rule**. A check that fires on *compliance* is
worse than no check — and the rulebook lost, silently, every time.

**The delimiter is now `-{4,}`, not an exact count.** The invariant that matters is *"the
command line is delimited for copy-paste"*, never the hyphen count. The block message
quotes the rulebook's own template instead of inventing a competing one.

This is the **fourth instance** in this arc of one predicate with two implementations that
drifted apart — after `readopt-override`'s resolver (v0.52.0), `register-drift`'s resolver
(v0.54.2), and `layer-drift`'s label check (v0.54.3). Each time the tool and the rule
disagreed, **and the tool won.**

### Proven able to fire

`core/fixtures/handoff-resume-guard/` drives the hook end-to-end with real JSONL
transcripts, and **mutation-testing catches the production bug**:

| mutant | caught by |
|---|---|
| the guard as the consumer actually ran it (exactly six hyphens) | *"BLOCKED a handoff that follows `steps/handoff.md` step 4 verbatim — the check fires on COMPLIANCE"* |
| substring presence instead of format (the pre-S258 guard) | *"an undelimited, non-copy-pasteable mention passed — presence is not format"* |

Five assertions: missed block → **BLOCK**; core's `----` → **ALLOW**; six hyphens →
**ALLOW**; undelimited mention → **BLOCK**; incidental noun mention → **no fire**.

### For the reference consumer

Once on 0.55.0, delete the local hook delta — core now carries it, correctly. That
retires the last `HARD-UNREGISTERED-CORE-DRIFT` row and the pull goes fully clean.

## [0.54.3] — 2026-07-13

### `layer-drift.sh` cried collision on the headings the operator had just correctly fixed

`validate-layer-entries.sh` learned in v0.53.0 that a `[ext:<id>]`-labelled heading is
the **resolved** state of a check-number collision, not a violation. `layer-drift.sh` —
which reports the same predicate in the reconcile report — **did not.**

So on the reference consumer, after `relabel-extension-checks.sh` correctly labelled all
16 colliding headings and `validate-layer-entries.sh` went to **0 errors**, `layer-drift`
went on reporting **11 collisions** — for entries that are *fixed*, on **every pull,
forever.**

It is report-only, so it corrupted nothing. It just trains the operator to stop reading
the reconcile report, and **a report that is always wrong is a report nobody reads.** The
remedy the message itself prescribes could never silence the message.

The label is now stripped before the title comparison, and a labelled heading clears the
collision. Verified against the consumer: **11 → 5**, and the 5 that remain are
*step-section* collisions (warn-tier by design, not the check catalog) — **the same 5
`validate-layer-entries.sh` reports.** The two tools finally agree. Un-labelling `Check
25` brings the collision straight back, so the check still fires.

### Third instance of one defect: two implementations of one predicate, drifting apart

- v0.52.0 — `readopt-override.sh`'s section resolver was weaker than `layer-drift`'s, so
  it could not resolve the anchor `layer-drift` had just **blocked** on, found no stale
  lines, and **would have cleared the block.**
- v0.54.2 — `register-drift.sh`'s resolver was stricter than `layer-drift`'s, so it
  **misfiled a renamed section as an addition**, which would have rendered core's heading
  *and* the consumer's, side by side.
- v0.54.3 — `layer-drift`'s collision check did not know the label that
  `validate-layer-entries` accepts, so the fix could not silence the finding.

Each time: **the gate and the tool disagreed, and the tool won.** The resolvers are now
shared byte-for-byte; this one is the label predicate, and it is now identical in both.

## [0.54.2] — 2026-07-13

### `register-drift.sh` authored overrides with anchors that resolve to nothing

Two bugs, both found by running it on the reference consumer's `tea.md`. Both produce a
**silently dead** entry, which is the failure class this project keeps re-learning.

**1. It anchored `shadows:` at headings core does not have.** It took its heading list
from the *consumer's* file. `tea.md` has `## Context Loading` and `## Communication`;
core has neither. An override anchors to a **core** heading — one that resolves to
nothing means `layer-drift` reports `OVERRIDE-ANCHOR-UNRESOLVED` and **drift detection is
dead for that section, forever.** This project has already had to repoint four overrides
for exactly that, and this script wrote two more. Consumer-only sections are **additive**
and now go to `extensions/` (file-hooked, no anchor to break), with the override keeping
only the headings core actually defines.

**2. Its section resolver was stricter than `layer-drift`'s, so it MISFILED a rename.**
The consumer's `## Escalation Protocol` is core's `## Escalation`, renamed —
`layer-drift`'s bidirectional substring match resolves it; an exact match does not. The
strict matcher concluded core had no such heading and routed it to `extensions/` as an
*addition*. Extensions are additive, so core's `Escalation` and the consumer's
`Escalation Protocol` would **both have rendered** — duplicate, conflicting guidance in
one document. The resolver is now `layer-drift`'s, byte for byte.

This is the same lesson `readopt-override.sh` learned in v0.52.0: **two resolvers that
disagree means the tool and the gate disagree, and the tool wins.** There is one
resolver.

## [0.54.1] — 2026-07-13

### `--stamp reaffirm` corrupted a live override's `reason:` — the record the whole workflow turns on

`--stamp reaffirm` appended its note to the **`reason:` line**. A `reason:` is routinely
a **multi-line YAML block** — six of the reference consumer's overrides have one, and the
longest runs **99 lines** — so the note was spliced **into the middle of the first
sentence**:

```
reason: The core paragraph states that `validate-ci-gates.sh` "runs on RE-AFFIRMED
  against 6c5e55e: ... still stands. every pull request via `.github/workflows/...`
```

This shipped in v0.52.0 and **damaged a real override on the reference consumer.** The
`reason:` is what the *next* pull reads to answer the one question the re-adoption
workflow exists to ask — *does upstream's change supersede the reason this override
exists?* Corrupting it corrupts the record that question is asked against.

The note is now appended as a **continuation line at the end of the `reason:` block**.
`core/fixtures/layer-readopt-gate/` asserts the first line stays intact, the continuation
lines survive, and the note lands at the end — mutation-tested against the old splice,
which it catches.

**Repairing an override already corrupted:** `git checkout` the file to restore the
original `reason:`, then re-run `--stamp reaffirm` with a 0.54.1 or later updater.

## [0.54.0] — 2026-07-13

### The updater handed the operator a blocker list. A blocker list is a to-do list with extra steps.

v0.52.0 made a stale override **block** `apply`, and v0.53.0 gave the consumer a gate.
Both were right, and both stopped one step short: run against the reference consumer,
`/ai-dlc-update` reported *"5 blockers that need disposition"* and asked the operator
how to respond. Answering meant **hand-merging prose** into an override body,
**hand-authoring YAML frontmatter**, and **hand-picking a `shadows:` anchor** — the
three things this project has most often gotten wrong. Four overrides have had to be
anchor-repointed after naming a heading that did not exist, and drift detection was
**dead for each of them** until someone noticed.

Detecting a blocker and then handing the surgery to the operator is not a resolution
path. **The updater has the tools; it must use them, and ask for approval — not
instructions.**

- **`readopt-override.sh --merge`** — re-adoption is a **three-way merge**, not a hand
  edit: base = core@`base_sha`, ours = the override body, theirs = core@`theirs`.
  Upstream's change lands, the consumer's delta survives, mechanically. Telling an
  operator to "merge the new core text in, preserving your delta" is asking them to run
  this algorithm in their head, on prose — and a hand-merge is where half an upstream
  clause gets silently dropped. A real conflict leaves standard markers and is the one
  place a human is genuinely required.

- **`reconcile/register-drift.sh`** — pulls an unregistered in-place core edit **into**
  the layer system: authors the `overrides/` entry from the consumer's own changed
  sections, anchors it to **real headings**, stamps `base_sha` at **base**, and reverts
  core. It skips sections differing only at `{token}` template sites (that is
  `install.sh` doing its job, not a consumer change), and it **refuses hooks by
  design** — the layer system has no override grain for them, and papering over that
  would be worse than saying so.

  `base_sha` is stamped at **base, not theirs**, deliberately: theirs would claim the
  consumer had already read an upstream change it has not. If upstream also touched
  that section, the new entry is immediately reported as `HARD-OVERRIDE-DRIFT-SECTION`
  and goes through `--merge` like any other. The mechanisms chain.

- **The adjudication loop (`ai-dlc-update` SKILL.md step 7).** Work `HARD-*` rows **one
  at a time**: build the dossier, decide against it, **do the work**, then ask **one
  closed question with a recommendation and its evidence**. The operator's answer is
  *yes* or *no, do X instead* — never "here are five blockers, how do you want to
  handle them."

### Proven on the reference consumer: 5 blockers → 1, mechanically, with zero hand edits

| blocker | disposition | how |
|---|---|---|
| `SKILL__Rule-8` | **readopt** | `--merge` + `--stamp` — new predicate in, old clause out, intensity table intact |
| `steps__retro__ci-gates-enforcement-surface` | **reaffirm** | v0.52.0 changed only prose there |
| `team-roles/tea.md` | **register** | `register-drift.sh --apply` authored the override, reverted core |
| `steps/retro.md` | **revert** | duplicates an override that already carries it |
| `hooks/ai-dlc-continue.sh` | **stays** | no override grain for hooks — the known gap, reported every pull |

Graph's **effective** Rule 8 — the override, the text the lead actually obeys — now
carries `findings_critical_prior_scope`, with the consumer's delta preserved.

### The bug the fixture caught in the merge itself

`--merge` reported **CONFLICT on a paragraph byte-identical to its own merge base.** The
body extractor emitted a leading blank line (the one after the frontmatter fence) while
`section_of` starts flush at the heading; that one-line offset mis-aligned `ours`
against `base`. A clean, mechanical re-adoption was being handed back to the operator as
prose to merge by hand — **the exact failure `--merge` exists to remove.** All three
inputs are now aligned. `core/fixtures/layer-readopt-gate/` asserts a clean merge, that
the superseded clause is *gone*, that the delta *survives*, that `--check` goes green
after, and that a stamp **cannot outrun an unresolved conflict**.

## [0.53.0] — 2026-07-13

### A gate hosted in a service we do not run is a gate we do not control

Operator policy: **no CI in GitHub** — not in the distribution, and not in the
reference consumer, which removed its own Actions scaffolding on purpose
(`fcce033ee`). v0.52.0 shipped `.github/workflows/validate.yml` against that policy.
It is removed. The checks are unchanged; only **where they run** changes.

- **`.githooks/pre-push` (the distribution's own gate).** enforcement-map integrity
  (I1–I9), the `SKILL.md` re-attach budget, the full fixture suite, and `bash -n` over
  every shipped script. Blocks the push on failure. No runner, no network, no third
  party. Nothing depended on the removed workflow: only 3 of 39 enforcement-map entries
  carry a `ci_workflow:`, all three pointing at the **consumer** templates, and none of
  the `call_sites:` backfilled by I9/W1 reference `.github`. `core/ci-templates/` is
  **retained** and still installed for consumers that do run Actions.

- **`core/git-hooks/pre-push` (shipped to consumers) — this closes the gap v0.52.0
  left open and said so.** `validate-layer-entries.sh` is correct, fires on real
  consumers, and was bound to nothing but `retro.md` — which runs *after* the sprint
  has already paid for the drift. Rule 27 has **no gate check and no
  `enforcement-map.yaml` row**, so layer hygiene was enforced by a human remembering to
  type a command: the same half-wired shape v0.52.0 is named for, one layer up. The
  consumer now has a call site that fires on its own.

  It runs **tree-level** checks only — layer entries, the compact-window invariant,
  `bash -n`, and the fixture suite. Gate-time validators (provenance, retro evidence,
  adversarial convergence, steering budget) need live pipeline state and stay at their
  gates. A push hook that fired them on every unrelated service commit would be a gate
  that fires on everything, and a gate that fires on everything gets turned off.

### Installed automatically, enabled deliberately

**The file installs; the hook does not self-enable.** Enabling is
`git config core.hooksPath .githooks`, left to the operator on purpose.

`validate-layer-entries.sh` exits 1 on the reference consumer **today** (5 errors).
Auto-enabling a blocking hook would have failed its very next push, mid-sprint — and a
linter that errors on first contact is a linter that gets commented out. Install now,
enable once the tree is clean. `install.sh` prints which state it is in.

Verified both directions: the consumer hook is **RED against graph as it stands today**
(the 5 real errors) and **GREEN only against the migrated tree**. It can fire, and it
clears only when the v0.52.0 migration actually lands.

### The claim this corrects

v0.52.0's changelog credited the Actions workflow with catching its own packaging bug —
the `layer-readopt-gate` fixture reaching `install.sh`'s hardcoded loop but not
`uninstall.sh`'s. **It did not.** `validate-enforcement-map.sh` caught that on a
**local** run, before the push; both of the two Actions runs that ever existed saw an
already-fixed tree and caught nothing.

Crediting a check with a catch it did not make is the same defect as a check that
cannot fire being recorded as a check that passed — the error class v0.52.0 is named
for, committed in v0.52.0's own release notes. The entry is corrected in place.

Both hooks were **mutation-tested going red**: the exact packaging bug (fixture in
`install.sh`, absent from `uninstall.sh`), `SKILL.md` pushed over the resident fold,
and a syntax error in a shipped script. Each blocks the push.

## [0.52.0] — 2026-07-13

### A rule that explains itself invites negotiation

*"Putting those things in the core skill are how we get agents 'reasoning' around the
rules and gates."* — operator.

A gate that justifies its own design hands the agent an argument for why the design
does not apply *here*, and a pointer from a gate file to the rationale doc is a door:
the agent walks through it and comes back with a story instead of a verdict.

Every rationale header, cross-doc pointer, measured anecdote, and piece of version
archaeology is **removed from the 38 agent-read files** (`SKILL.md`, `steps/*.md`,
`core/team-roles/*.md`) and relocated to `docs/context-hardening-notes.md` **R33**,
where humans read it and the pipeline does not. **No forwarding pointer is left
behind — the pointer is the door.**

| file | delta |
|---|---|
| `SKILL.md` | **−4,995 B** |
| `steps/gate-validation.md` | **−3,110 B** |
| `core/team-roles/adversary.md` | −1,749 B |
| `steps/retro.md` | −511 B |
| `steps/route.md` | −490 B |
| `steps/_gate-procedures.md` | −231 B |
| `steps/implementation.md` | −91 B |
| **total** | **−11,177 B (~−2,794 tokens)** |

The handed list of 5 headers + 9 pointers was a *starting* set. A shape-sweep found
**3 more headers and 6 more anecdote sites**. Resident slack: **253 → 266 tokens**.

**What was kept, and the test that decided it** — *can the agent use this sentence to
argue the rule does not apply to it?* If yes, rationale, cut. If it is an invariant of
the world, keep.

- **All 21 Rule 26(c) contracts** (verified by count). Rule 26(c) *requires* machinery
  to state failure-caught / false-positive-cost / removal-condition, and a retro audit
  flags machinery lacking one — deleting them breaks a different gate. Compressed to
  terse form; the sprint-numbered measurements *inside* the "failure caught" clauses
  were stripped, the contracts were not.
- **Factual API statements.** *"`Agent` returns an `agent_id`, `TaskOutput` takes a
  `task_id`"* is a fact an agent cannot argue with.
- **`gate-validation.md`'s H1 format examples** (`Sprint 288`, `Sprint S286`) — those
  are accepted-input strings for a parser, not anecdotes.

No `##`/`###` heading was deleted or renamed, so **no consumer override was orphaned**
(checked against graph's `shadows:` entries before cutting; every site cut was a
bold/italic paragraph lead *inside* a section).

### Stopping is not landing — `/ai-dlc-update` can now carry a fix through re-adoption

v0.52.0 promoted `OVERRIDE-DRIFT-SECTION` to `HARD-`, so a stale override blocks
`apply`. That is necessary and **not sufficient**: graph's
`overrides/SKILL__Rule-8.md` copies the divergence clause **verbatim**, the lead reads
the *override* and not core, and blocking merely stops the pull. Three new reconcile
tools end the block instead of parking on it.

**`reconcile/readopt-override.sh`** — the re-adoption workflow. Prints a dossier (the
core section's `base_sha..theirs` diff, the override's body, its stated `reason:`, and
the superseded core lines still sitting in that body) and forces one question: *does
upstream's change supersede the reason this override exists?* Outcomes: `retire`,
`readopt`, `reaffirm --note`. All three end in a re-stamped `base_sha`.

> **The trap it closes.** Drift is computed `core@base_sha[section] != core@theirs[section]`,
> so re-stamping `base_sha := theirs` makes the HARD status **evaporate with nothing
> migrated** — "proceed by doing nothing" wearing a stamp. So **`--stamp readopt` is
> refused** while the body still contains a line core carried at `base_sha` and no
> longer carries at `theirs`. Doing nothing is not an available outcome.

**`reconcile/unregistered-drift.sh`** — the layer system's blind spot. `layer-drift.sh`
walks `overrides/` and `extensions/`; a core file edited **in place** appears in
neither, so no entry describes it, no `base_sha` tracks it, and `apply` — which
overwrites upstream-owned core — **deletes it without a word.** On graph it finds
exactly three (`team-roles/tea.md`, `steps/retro.md`, `hooks/ai-dlc-continue.sh`) and
correctly exempts the ten files that differ only at `{token}` template sites.

**`reconcile/relabel-extension-checks.sh`** — mechanizes the v0.49.0 catalog label.
v0.49.0 defined the fix and shipped a detector; it shipped nothing that *did* the
relabelling, so graph adopted the label on **zero** of its extension checks across
three releases. Rewrites `### <n>. <title>` → `### <n>. [ext:<id>] <title>`. The
integer never moves.

### `validate-layer-entries.sh` told you the remedy, then rejected it

Applying the linter's own advice — add the `[ext:<id>]` label it tells you to add —
left the ERROR in place. `heading_title()` folded the label into the title text, so a
correctly-labelled heading could never match core's title and the collision persisted.
**5 errors became 6.** A remedy that does not remedy is a check that cannot pass, and
a check that cannot pass gets commented out. The label is now stripped before the title
comparison and a labelled heading **clears** the collision. A restatement (same title)
still warns: the label fixes *ambiguity*, not *duplication*.

### Verified end-to-end against the reference consumer, not against a green script

Rehearsed on an `rsync` copy of graph (paused mid-sprint at S290; **its live tree was
never written to, and its `_bmad-output/` audit record was never touched**):

1. The dry-run **blocks** on 5 `HARD-*` rows — `SKILL__Rule-8`,
   `steps__retro__ci-gates-enforcement-surface`, and the three unregistered-drift
   files — each carrying its resolution command, and reports the Check-25 collision
   this pull creates.
2. **The Rule 8 fix is live in the RENDERED pipeline.** After `--stamp readopt`,
   graph's *effective* Rule 8 — the override, not core — carries
   `findings_critical_prior_scope`, and the consumer's validation-intensity table,
   floor list, and revise-upward guarantee all survived.
3. `validate-layer-entries.sh` in the migrated copy: **5 errors → 0** (21 warnings
   remain: `RESTATES`, judgement-required, untouched).
4. `validate-adversarial-convergence.sh --series s290-brief-adversarial-p` returns
   **the same result as before the update** — one `FAIL (D — TERMINAL)`, p8 still
   `EXIT_CONDITION_NOT_MET`. **Zero new failures on adoption, zero writes to p1–p8.**
   The fail-closed default is what makes the field safe to adopt mid-cycle.

### The three defects the rehearsal caught in the new code

All three are the *check-that-cannot-fail* class, and none is visible without driving
the real consumer state:

- **`readopt-override.sh` used a weaker section resolver than `layer-drift.sh`.**
  `layer-drift` blocked on the retro override; the remedy could not resolve the same
  anchor, found zero stale lines, and **would have cleared the block.** The two now
  share one resolver, byte for byte.
- **An unresolvable anchor made the stale-text test vacuous** — two empty sections
  compare equal, so *any* body read as clean. It now fails **closed**: `UNDECIDABLE`,
  and `readopt` is refused (`reaffirm --note` is the recorded way past).
- **The dossier's "what upstream changed" panel rendered empty.** `printf '%s'` emits
  no trailing newline, so `while read` skipped its only line — "nothing changed" on a
  section that changed.

`core/fixtures/layer-readopt-gate/` asserts all of it, and **every gate was
mutation-tested going red** before it went green. Its `seed.sh` writes a real git
repository to disk — v0.48.0 shipped three seeds that were `echo` statements
describing files they never created.

### Reported honestly: what did NOT land

- **`validate-layer-entries.sh` did not need a WARN→ERROR change for check-number
  collisions — it has been an ERROR since v0.49.0** (E6, `kind: check`). The premise
  was wrong. The WARNs are *step-section* numbers, tiered deliberately. No mechanism
  was added where one already existed (Rule 26(b)).
- **The enforcer still cannot run in graph's CI, because graph has no CI** — it was
  removed on purpose (`fcce033ee chore: permanently remove GitHub Actions CI
  scaffolding`). Wiring a job there would be a check that cannot fire. Its only call
  sites remain retro and, now, `/ai-dlc-update`. **Rule 27 has no gate check and no
  `enforcement-map.yaml` row at all** — the same half-wired shape this release is
  named for, one layer up, and it is *not* fixed here.
- **The layer system has no override grain for hooks.** `ai-dlc-continue.sh` carries a
  legitimate +80-line consumer hardening (a handoff-resume guard with its own Rule
  26(c) contract) that can be registered nowhere, so it stays `HARD-` on every pull.
  The detector makes it *visible* and *blocking* — previously it was invisible and
  would have been silently overwritten — but the durable fix is a separate release.
  No hook-override subsystem was invented for it (Rule 26(a)).
- **The packaging trap bit a fourth time** and was caught by
  `validate-enforcement-map.sh`: the new fixture reached `install.sh`'s hardcoded loop
  but not `uninstall.sh`'s. Both loops now agree.

### Three validators found real defects on the live consumer. Not one of them was wired to anything that stops the pipeline.

The reference consumer was reviewed live at `0.51.0@b333c86`, mid-sprint, paused at an
operator handoff. The question was whether v0.48.0–v0.51.0 were effective. The answer
turned out to be about **delivery**, not design.

| validator | findings on the live consumer, right now | invoked at a gate? |
|---|---|---|
| `validate-steering-budget.sh` | **FAIL(A): 11 starvation violations, worst 10.0 min** | **no gate call site at all** |
| `validate-layer-entries.sh` | 5 ERRORs, 21 warnings | named in gate *prose*; the gate passed |
| `validate-enforcement-map.sh` | — | distribution-only — and **the distribution had no CI** |

`git log --all -- .github` was **empty for the project's entire history.** ai-dlc
shipped a CI template *to its consumers* while gating none of its own fifteen
validators.

**The previous releases were not half-*applied* by the consumer. They were
half-*wired* in the distribution.** `wait-for-deliverable.sh` is physically present in
graph; the sync worked. What never existed, in core, was a call site.

### The machine that made it possible

`enforcement-map.yaml` recorded `enforcer:` — *who* enforces a rule — on all 38
entries. It recorded `call_sites:` — *where the enforcer is actually invoked* — on
**one**. So *"Enforced by `validate-X.sh`"* was a **claim**, and nothing could tell a
claim from a wiring. That is how `implementation.md:152` came to say
*"`validate-steering-budget.sh` fails the gate on it"* while that sentence was **false
at every gate, in every phase** — the script ran only at retro, after the sprint had
already paid.

- **`scripts/validate-enforcement-map.sh` gains I9.** **W1:** an
  `adjudication: script` entry with no `call_sites:` is an ERROR. Run against the map
  as it stood, it fails on **nine** entries. **It would have caught v0.50.0's
  half-wiring at authoring time.** **W2:** no declared site may be fictional — the
  file it names must at least know the enforcer exists. W2 *cannot* tell an invocation
  from a prose mention, and **says so in the script**: telling them apart means parsing
  English, and a heuristic that fails closed on a legitimate phrasing is an unpassable
  gate, which gets turned off. The teeth are W1 plus the reviewable `posture:`.
- **All nine entries backfilled** — and the backfill *is* the audit. It is what put
  `steering-budget`'s single real call site (retro, after the fact) on the record.
- **`.githooks/pre-push`** — the distribution now runs its own checks: enforcement-map
  integrity (I1–I9), the SKILL.md re-attach budget, the full fixture suite, and
  `bash -n` over every shipped script. It blocks the push on a failure. Enable once per
  clone with `git config core.hooksPath .githooks`. It caught a fixture
  (`context-sensor`, 36 assertions) that resolved its hook only at a **consumer** path
  and had therefore never once run upstream.

  **This shipped as a GitHub Actions workflow first, and that was wrong.** It was
  removed in **0.53.0** and the same four checks moved to a local pre-push hook.

  **The correction is on the record because the original claim was wrong.** This entry
  previously credited the Actions workflow with catching v0.52.0's own packaging bug (a
  fixture added to `install.sh`'s hardcoded loop but not `uninstall.sh`'s). It did not.
  `validate-enforcement-map.sh` caught that on a **local** run, before the push; the
  two Actions runs that ever existed both saw an already-fixed tree and caught nothing.
  Crediting a check with a catch it did not make is the same defect as a check that
  cannot fire, recorded as a check that passed — and this release is named for it.
  The pre-push hook was mutation-tested against that exact packaging bug, the resident
  budget, and a syntax error: it blocks on all three.

### Rule 8 — the divergence predicate compared counts across two documents that are not the same document

S290 ran **eight** adversarial passes on one artifact. CRITICALs went
`3 → 1 → 1 → 2 → 2 → 2 → 3 → 2` and **not one pass ever stamped
`EXIT_CONDITION_MET`**. The predicate — `criticals(N+1) > criticals(N)` — hard-blocked
twice, and **both times its stated cause was false.** Pass 7, first line:

> *"The rise is NOT pass 6's repairs injecting defects — I probed those and they hold.
> Every new CRITICAL is in the scope the sprint ADDED after pass 6 closed."*

The adversary wrote **prose to override the field it had just stamped** — v0.48.0's
defect exactly inverted, and the two conditions have **opposite remedies**.

- **New field: `findings_critical_prior_scope: <int>`** — of your CRITICALs, how many
  sit in text the *previous pass also reviewed*. Only those are comparable. An **int,
  not an enum**: an enum is a cheat code (stamp `GREW`, the block evaporates), while an
  integer is a cross-checkable partition of a number the adversary already produced.
  **No fourth verdict** — the condition is derivable, and inventing one would be
  unrequested mechanism under the rung v0.51.0 itself just shipped.
- **Check C is now scope-relative; Check D names the real remedy** — *freeze the
  artifact, cut the added scope* — instead of "run another pass," which is the advice
  that produced passes 2 through 8.
- **The exit condition was never broken.** S289's cycle ran `3 → 4 → 7 → 0` and
  converged the moment the repairs finally *cut* text. It is reachable as soon as the
  scope holds still, so nothing here touches it, Check B, or the pass floor.
- `SKILL.md` Rule 8 is a **byte-NEGATIVE swap** (391 → 377). The resident region had
  **zero** headroom — it ended at exactly the 4,750-token ceiling — and it fits because
  the sentence deleted is the false one (*"Usual cause: an artifact over its Rule 25(d)
  budget"*), which survives, correctly re-scoped, as the scope-growth remedy.

### Rule 29 — the join fix was installed in half the pipeline

v0.50.0 works **where it was wired**: 0 `TaskOutput` calls (S289: 8 failures) and **0
re-dispatches across 28 spawns** (S289: 13 of 39). But it was authored against the
phase where the failure was *observed*, not against the invariant. Five planning steps
dispatch teammates; `wait-for-deliverable.sh` was prescribed in `implementation.md`
**alone**, and `discovery.md` had **no join guidance at all** — while **all 28 of
S290's dispatches were in planning.** The lead found the script anyway (34 calls) and
*also* hand-rolled 17 `sleep` commands, ~8 of them unbounded loops that ran to the
10-minute harness cap.

- **`_gate-procedures.md` gains a "Bounded-join beat"** procedure, invoked by name from
  every dispatch site in the five planning steps plus `sprint-review.md`. **Zero bytes
  added to SKILL.md.**
- **New gate Check 25** runs the enforcer at **every gate**, making
  `implementation.md:152`'s claim true for the first time. The **delta rule is
  load-bearing**: the scan is whole-session and a starvation window is conduct already
  committed, so a raw FAIL would re-report it forever and an unpassable gate gets turned
  off. Only an *increase* since the previous gate fails.
- `validate-steering-budget.sh --count` emits the integer the gate compares. A markdown
  step grepping a count out of an English sentence is the hand-rolled pipe `verdict.sh`
  exists to kill.
- **The turn-cost asymmetry is real but is NOT the cause.** In implementation, where the
  beat *is* prescribed, the same lead paid ~3.4 beats per spawn and hand-rolled **zero**
  loops. The variable is prescription, not price. A `PreToolUse` deny is **pre-registered,
  not built** — it ships only if violations remain above zero.

### A stale remedy would have told the lead to delete its own dispatch ledger

`validate-artifact-budget.sh` said to trim `pipeline-snapshot.md` to its **6-section**
schema. v0.50.0 made it **seven** and never swept the text. A lead obeying it literally
would have deleted `In-Flight Teammates` — **the ledger that is the one thing
demonstrably preventing re-dispatch.** Fixed to 7, pointing at Check 14 as schema owner.

The snapshot had reached **66,782 bytes — 278% of budget** — whole-read at each of *ten*
compactions in one day, while the sub-step check sat there reporting it. The check
already exited 1 past the grace band; the step file said *"trim at your next natural
pause."* **An obligation with no deadline is not an obligation.** Now: past grace →
**trim before the next sub-step.** `In-Flight Teammates` is rows-only, **deleted at
join** (it was *struck*, so rows accumulated, and the consumer wrote narrative instead
— the section that saves the pipeline from re-dispatch had grown to ~35 lines).

### v0.51.0 is installed, unexercised, and deliberately untouched

The over-engineering MAJOR rung is present verbatim in the consumer and produced **zero
findings across all eight passes**. The tempting confirmation — *"every repair
subtracted"* — is confounded: S290's operator-set theme was literally **SUBTRACTION**,
and v0.51.0's own changelog records S289's adversaries already removing by instinct
without it. Reading that as the rung working would be a check that never fired, recorded
as a check that passed. **It needs another sprint of evidence, not another edit.**

### Migration — required, and it is not optional this time

- **`OVERRIDE-DRIFT-SECTION` → `HARD-OVERRIDE-DRIFT-SECTION`, and it now BLOCKS
  `apply`.** A consumer overriding a core section whose text has changed is shadowing
  **a rule that no longer exists** — and the lead reads the override, not core. Left
  advisory, v0.52.0's Rule 8 fix would have landed on disk and been **inert on the one
  pipeline it was written for**, because the reference consumer shadows `SKILL.md#Rule 8`
  verbatim. This is distinct from a check-number collision, which is cosmetic and
  correctly does *not* block. `ai-dlc-update` already matches on the `HARD-` **prefix**,
  so no new mechanism.
- **Consumers overriding `SKILL.md#Rule 8` must re-adopt the new divergence clause and
  re-stamp `base_sha`.** The update will now stop until they do.
- **Consumers whose `extensions/checks/` squat integers ≥ 25 must adopt catalog labels**
  (`### 25. [ext:<id>] …`, per v0.49.0). Core now defines Check 25.
- **Adversarial passes stamped before v0.52.0 need NO back-fill.** The absent field
  defaults to `prior := crit` — the *hostile* reading — so it reproduces the old
  predicate exactly and cannot be used to dodge a hard block. The field is
  **forward-adopting**: it is only ever needed on the *left* side of the comparison, so
  the next pass can stamp it while every prior pass lacks it. **Do not retro-stamp a
  review artifact**; it falsifies an audit record.

## [0.51.0] — 2026-07-13

### The adversary found the over-engineering, then filed it in the one bucket the gate forgives

The adversary is already a strong KISS reviewer. It hunts unrequested mechanism unprompted
and argues for removal well — S289's own artifacts say so out loud:

- *"Posture: REMOVAL-BIASED. Every finding below is either a DELETION or the re-scoping of
  a…"* (`s289-teststrategy-adversarial-pass1.md:5`)
- *"Of the thirteen findings above, five are removals… Zero net new mutation events are
  required to fix everything in this report."* (`s289-rr-adversarial-pass3.md:500`)
- *"Both fixes are subtractions: delete a duplicated map, delete a stamp."*
  (`s289-sprint-review-adversarial-p1.md:133`)

So there was never a hunting gap. There was a **classification** gap, and it was
load-bearing.

The severity ladder had three rungs. CRITICAL demands a concrete failure — *"behaviour that
ships wrong, an AC that cannot pass, a LOCKED requirement contradicted."* Over-built mechanism
**ships right**: nothing fails, no AC breaks, nothing is contradicted. So it cannot be
CRITICAL — and MINOR/NIT was defined as *"everything else. Style, phrasing, preference."*
An artifact that works but carries mechanism nothing asked for fits neither rung.

MINOR is the **explicitly forgiven** bucket: a residue of 0 CRITICAL / 0 MAJOR with open
MINORs *"is a MET exit condition, not a nearly-met one. Say MET."* Check 24 then passes the
gate. This contradicted Rule 26(d) — *"removal and simplification findings are equal in
standing to additions"* — because the verdict contract made them structurally **unequal**:
an additive defect reaches the residue that gates; a removal finding could not.

**What the ladder's silence actually produced.** Given no rung for a removal, an adversary
built its own channel *outside the graded set*. `s289-arch-adversarial-pass1.md:261-278`
carries a *"Rule 26 removal sweep"* — three deletions, ~18 lines of proposed cuts — that the
same file's `VERDICT: 2 CRITICAL, 1 MAJOR, 2 MINOR` counts **zero** of. Findings with no
severity, absent from the residue, invisible to Check 24. They landed only because the lead
read the prose. That is v0.48.0's failure exactly one rung down: **converged in the prose,
absent from the field.** The role file already said *"Every finding carries exactly one
severity"* — and the ladder gave this class of finding no severity to carry.

### The change

`core/team-roles/adversary.md`:

- **New rung.** Unrequested mechanism (Rule 26(a) — a speculative abstraction, a parallel
  path without the 26(b) rationale record, a guard without the 26(c) contract, a fallback
  for a case that cannot occur, an AC demanding capability nothing asked for) is a **MAJOR**,
  not a nitpick. It then counts in `findings_major`, forces `EXIT_CONDITION_NOT_MET`, and
  gate Check 24 holds — **using machinery that already shipped in v0.48.0.**
- **A three-part bar**, symmetric with CRITICAL's *"if you cannot state it, it is not
  CRITICAL."* Name the mechanism at `file:line`, the requirement it does **not** serve, and
  the simpler change — or it stays MINOR. *"This feels over-built"* names none of the three.
  Rule 26(b)'s escape hatch sits inside test 2: if the artifact already records why the
  mechanism is there, test 2 fails and there is no finding.
- **The repair is a deletion.** A repair that adds text means the finding is misclassified.
  This is the anti-manufacturing guard: on S289's `research-requirements` cycle CRITICALs ran
  **3 → 4 → 7 → 0**, converging only once the repair wave finally *cut* text.
- **Contract item 5.** Rule 26(d)'s reflexive half — *a finding whose repair ADDS mechanism
  must say why the simpler path fails* — was a parenthetical buried in a Constraints bullet
  about something else. It is now a numbered must.

`core/skills/ai-dlc/SKILL.md` — Rule 26's enforcement pointer said violations are *"a
code-review finding per `code-reviewer.md`"*, i.e. **post-implementation only**. Planning-phase
over-engineering — where scope creep enters, and where it is cheapest to kill — had no gated
home at all. The pointer now names both enforcers. Token-neutral swap (+15 bytes, in a region
1000 lines below the re-attach window; `validate-reattach-budget.sh` still PASSes with 250
tokens of slack).

### Backtested before shipping — it does not break convergence

Run against all 21 removal findings across S289's 14 adversarial artifacts:

- **13 were already filed CRITICAL/MAJOR.** The adversaries were doing this by instinct,
  inconsistently, pass to pass. The rung makes a habit into a contract.
- **8 were filed MINOR — and all 8 are correctly MINOR.** Every one is a stale word, stale
  count, or stale reference. None names a *mechanism*, so all 8 fail bar test 1 and stay put.
- **3 had no severity at all** — the ungraded arch sweep above. These are what the rung fixes.
- **The converged `rr` pass 4 (0 CRITICAL / 0 MAJOR / 2 MINOR) is unchanged.** Both its MINORs
  (`prd.md:1923` a stale word; `prd.md:2014` a false premise about `grep`) are stale-fact
  defects, not mechanism. It still stamps MET. **No S289 cycle would have been forced to run
  again.**

### What this does NOT fix — stated so nobody reads it as covered

Graph's retro found `SAFEGUARD_DISPOSITION_TABLE` — *33 lines, zero consumers, eight tests,
one green code review* (`docs/retro/sprint-289.md:136`). **This rung would not have caught
it.** Zero S289 adversarial passes mention it: it was introduced in sprint 245-5, green-reviewed
there, and sat outside S289's diff. Nobody forgave it — **nobody looked at it.** That is a
*scope* miss (what the adversary is handed to review), not a *severity* miss, and it needs a
different change. Claiming this rung as its fix would be a check that cannot fire, recorded as
a check that passed.

### Deliberately not added

- **No new provenance field.** `findings_major` already carries it.
- **No new script, no new gate.** `validate-adversarial-convergence.sh` Checks A–D and gate
  Check 24 already adjudicate residue → verdict. The finding simply was never allowed to reach
  them.
- **No new fixture.** There is no new script assertion to fixture; one that exercised nothing
  new would be a vacuous green — the trap this repo shipped in v0.48.0 and caught in v0.49.0.
  The existing 5-case suite still passes, including the `nitpicks-remain` decoy (0C/0M with 5
  MINOR open must PASS) — proof we did not make *all* MINORs block.

### Honest limitation

**Nothing mechanically verifies that the adversary classified an over-engineering finding as
MAJOR rather than MINOR.** No script can know that a finding filed MINOR should have been
MAJOR — that is precisely the judgement the role exists to make. This is a contract change
riding an existing enforcer, and its efficacy is observable only in the artifacts. The Rule
26(c) removal condition is stated inline in the role file: two consecutive sprints with zero
over-engineering MAJORs and no shipped unrequested mechanism, or two consecutive sprints of
the lead overriding them as taste — either way the rung is not discriminating, and it goes.

### Consumer migration

Consumers overriding `team-roles/adversary.md` must re-stamp `base_sha` and re-verify. Graph's
`team-roles__adversary__no-worktree-isolation.md` shadows **Contract item 3**; the new item 5
appends after item 4 and does not move item 3, so the anchor survives — but the pinned
`base_sha` is now stale and the Rule 27 drift detector should flag it.

## [0.50.3] — 2026-07-12

### A beat that never waited was still charged, so the script cried NON-DELIVERY on a live teammate

v0.50.1's chained-beat guard stops a second invocation in the same `Bash` call from
sleeping — two sleeps in one call would blow the steering budget. But it charged the beat
anyway: the counter was incremented *before* the guard ran.

The sequence bound exists to cap **waiting time** (`max_wait_beats × steering_budget`). A
beat that did not wait is not a beat, and charging one for it burns the budget without
buying any wait.

Observed live within the hour, again. The consumer wrapped beats in a loop:

    for i in 3 4 5; do scripts/wait-for-deliverable.sh docs/reviews/…-p1.md; RC=$?; …; done

Two of every three invocations were non-sleeping siblings — and each still took a beat.
The counter hit `max_wait_beats` while the teammate was **alive**, the script returned
`exit 1` = NON-DELIVERY, and Rule 20 tells the lead to re-dispatch on that. The
deliverable landed four minutes later. **A false NON-DELIVERY re-dispatches a live
teammate — the exact failure this entire mechanism exists to prevent, reintroduced by the
mechanism itself.**

- A beat is charged **only if it actually sleeps**. The guard now returns without
  consuming one, and says so.
- Stale `.shell-<PID>` markers are pruned. PIDs recycle, so a marker from a long-dead
  shell could suppress a legitimate beat; anything older than the budget cannot be a
  sibling of the current call by definition. This also stops the markers accumulating.
- Together these make a false sibling match **benign**: it can cause an early return, but
  it can no longer consume a beat or trigger a false non-delivery.

## [0.50.2] — 2026-07-12

### The pause gate denied `/ai-dlc-update`'s dispatches, so the model did the work inline

`ai-dlc-acknowledge.sh` denies pipeline-advancing tools while `pipeline-paused.flag`
exists. `/ai-dlc-update` is not `/ai-dlc`: it advances no sprint, passes no gate, and
runs precisely when the pipeline is parked — which is exactly when the flag is set,
usually by the handoff that parked it.

The hook already knew this for the updater's **writes** — there is a carve-out for
`_bmad-output/ai-dlc-update/**` with a comment reading *"Denying its report write because
'the pipeline is paused' blocks a skill that has no pipeline to pause. Observed live."*
That reasoning was never extended to its **dispatches**, while the updater's whole design
is a fan-out (*"dispatch ONE generic agent per file"*, `ai-dlc-update/SKILL.md`).

So the dispatch was denied, and the model routed around the denial by doing the work
**inline in the lead** — which defeats the offload the dispatch existed for and inflates
the very context the updater is meant to protect. A guardrail that is trivially routed
around is not a guardrail; it is a tax on the honest path.

- `Agent` / `Task` / `Skill` / `TaskCreate` are exempt from the pause gate **in an
  `/ai-dlc-update` session**. In a pipeline session they still advance the pipeline and
  the deny stands, unchanged.
- The active skill is read from the **transcript**, not a marker file. A marker needs a
  lifecycle — create, delete, and a story for the crash in between — and a
  stale-flag-with-a-lifecycle is the bug being fixed here, not a tool to fix it with. The
  transcript is self-healing: whichever skill was invoked last is the one in play.
- **Fails closed.** No transcript, or an unreadable one, denies. A session that runs
  `/ai-dlc-update` and then `/ai-dlc resume` is a pipeline session again, and the pause
  gate applies to it in full.

## [0.50.1] — 2026-07-12

### v0.50.0's wait-beat gave the lead no way to join a wave, so it chained them

Shipped v0.50.0, updated the reference consumer, and watched. The join fix held:
**0 `TaskOutput` calls, 5 of 5 dispatches joined through `wait-for-deliverable.sh`, 0
hand-rolled poll loops** (was 98 in one phase), and after an auto-compaction the lead's
first output named its in-flight teammates from the snapshot — `s289-cr-sd{3,4,5}` — and
re-dispatched **none** of them.

Then it did this, within the hour:

    scripts/wait-for-deliverable.sh docs/reviews/s289-3-selfdiscrimination.md; echo "WAIT3_RC=$?"; \
    scripts/wait-for-deliverable.sh docs/reviews/s289-4-selfdiscrimination.md; echo "WAIT4_RC=$?"

Two beats in one `Bash` call: 2 × 110s against a 120s steering budget. The harness
backgrounded it at the cap and both verdicts went to a file the lead never read. That is
Check A starvation — committed by the *caller* rather than by the loop, which is the
failure v0.50.0's script was supposed to make impossible.

**The lead was not being careless. It had a wave of three reviewers to join and the
script took exactly one path**, so serial beats would have cost 3 × 110s. Chaining was
the only option the tool left it. A primitive that makes the correct thing expensive
will be worked around.

- `wait-for-deliverable.sh` now takes **many paths and polls them inside ONE beat**, so a
  three-teammate wave joins in ~110s instead of 330s. This is the shape a wave dispatch
  always needed.
- It also **refuses to sleep twice in one `Bash` call**. Chained invocations share a
  parent shell, so they share `$PPID`; a sibling beat that already slept means this one
  does an instantaneous check and returns, naming the right call shape. The call cannot
  overrun the budget even when the lead composes it wrong.
- Rule 29 and `implementation.md` now prescribe the wave join and forbid chaining.

## [0.50.0] — 2026-07-12

### The lead re-dispatched 13 of 39 teammates, and the skill had told it to

`steps/implementation.md` prescribed the join for a dev, code-reviewer, and qa as:

    TaskOutput(task_id, block: true, timeout: 120000)

Those are all `Agent` spawns. `TaskOutput` joins a `task_id`, which only `TaskCreate`
produces; an `Agent` returns an `agent_id`. **`TaskOutput` cannot join an `Agent`
spawn** — Rule 29 has said so since v0.44.0, in the same skill, and `implementation.md`
was never brought onto it. The step file named an API that cannot work, and the lead
obeyed it.

Measured on the reference consumer's S289 implementation phase (4h25m, 8 stories, one
lead session):

- **8 `TaskOutput` calls failed** with `No task found with ID`. Every one passed a
  human-readable agent name (`s289-qa-1`, `s289-cr-8b`). Every one of the 10 calls that
  passed a real `task_id` succeeded. The split is total.
- **13 of 39 dispatches were re-dispatches.** The lead could not reach a teammate, read
  that as the teammate having *died*, and dispatched a replacement over work that was
  still running or already delivered.
- It misattributed the cause on the record — *"`s289-qa-1` no longer resolves — the
  compaction killed the in-flight QA agent"* — and then invented forensics (worktree
  emptiness, transcript-staleness probes) at each of **7 auto-compactions** to guess who
  was still alive. The agent had not died. The call had never been capable of working,
  compaction or no compaction.

The handle that defeats this already existed. Rule 29 establishes that every teammate
delivers by file (Rule 20), so **the deliverable file IS the handle** — it needs no
`agent_id`, takes no `task_id`, and outlives a compaction. Nothing carried that path
across the boundary, so it may as well not have existed.

**Changed**

- `steps/implementation.md` — the dev/reviewer/qa join is now Rule 29's **bounded
  file-wait beat** on the deliverable, not `TaskOutput`. The old text is replaced, and
  the reason `TaskOutput` cannot be used is stated inline so it is not re-introduced.
- **`In-Flight Teammates` is now the seventh snapshot section** (`gate-validation.md`
  Check 14 owns the schema): one row per dispatched-but-unjoined teammate —
  `agent name | role | deliverable path | dispatched-at`. Written **at dispatch**, in the
  same turn as the `Agent` call — a teammate is at risk from dispatch until join, which
  is exactly the window in which no story transition has happened yet.
- `hooks/ai-dlc-recover.sh` — the post-compact block now tells the lead its teammates did
  not die, it lost their handles; that a wrong-API error looks identical to death and is
  not; and to re-join each row on its deliverable file, re-dispatching only on Rule 20
  non-delivery.
- `scripts/validate-steering-budget.sh` — the Check A remediation string said the fix for
  an `Agent` spawn was `TaskOutput(task_id, ...)`, repeating the same category error the
  validator's own Check D exists to catch. Corrected.
- `_gate-procedures.md` — the sub-step snapshot update now reconciles `In-Flight
  Teammates` and runs `validate-artifact-budget.sh` **warn-only**. Check 14 enforces the
  6k snapshot budget at gates, which is frequent enough in planning — but implementation
  passes only three gates in a phase that can run four hours. In S289 the snapshot grew
  past **200% of budget** between gates and was whole-read at each of seven compactions,
  the largest single byte-injector in the session.

### The lead's own tool calls were 224k resident tokens; ~26k of that was retyping

Same phase, second measurement. The lead's tool-call *parameters* — not what it read,
what it wrote — cost **224k resident tokens**: Bash 101k (45%), Agent briefs 61k (27%),
Edits 26k (12%). Most of the Bash is genuinely one-off investigation and is not
recoverable. Two slices are pure re-authoring, and both are now commands:

- **`scripts/wait-for-deliverable.sh`** — Rule 29 handed the lead a shell *snippet* to
  retype for every join. It retyped it **75 times** (~13k tokens). Now one call:
  `exit 0` delivered, `exit 2` beat again, `exit 1` Rule 20 non-delivery. It enforces
  **both** of Rule 29's bounds rather than trusting the caller to hold them — the beat
  is clamped inside the steering budget (reserving a full poll interval, so a large
  `AI_DLC_WAIT_POLL_SECS` cannot silently push it over), and beats are counted in a
  sidecar so the sequence terminates whether or not the lead remembers. Checks A and C
  were policing a handwritten loop after the fact; now the loop cannot be written wrong.

- **`scripts/verdict.sh`** — the validators print their working, so the lead wrapped
  them: `validate-… 2>&1 | grep -E 'OVER|PASS' | head -2`, **71 times** (~26k tokens),
  a fresh filter each time. `verdict.sh <validator> [args]` prints one line and **exits
  with the validator's own status**. That last part is the point: `cmd | grep` takes
  *grep's* exit status, so a validator that prints `FAIL` and exits 1 reads as a pass —
  which is not hypothetical, S289 shipped a fix titled *"the harness could print FAIL
  and exit 0"* and then kept hand-rolling the same pipe. `gate-validation.md` Check 14
  and the sub-step budget check now call through it.

Both are wired into `scripts/install.sh`'s copy loop, which is hardcoded and has been
silently missed before.

**Migration: none.** `In-Flight Teammates` **auto-heals** — `route.md` Step 0 creates it
empty rather than failing the resume. Its absence is unambiguous (a snapshot written
before the section existed recorded no teammates, and empty is the correct default), so
failing a resume on it would strand every snapshot written by a prior version for a
section whose empty state is already right. The other six sections still FAIL on absence,
because their state cannot be reconstructed by assuming a default.

Rationale relocated to `docs/context-hardening-notes.md` R31: the resident region had
**7 tokens of slack** under `validate-reattach-budget.sh`'s ceiling, so the verification
turn's "why" moved out to pay for the teammate re-join instruction moving in.

## [0.49.0] — 2026-07-12

### The consumer-catalog namespace was a declaration; nothing enforced it

`steps/gate-validation.md` has always said that a consumer's `extensions/checks/`
numbers are their own namespace, that they do not map to core's, and that fire history
must be aligned by title and **never** by number. The rule was right. Nothing
implemented it.

Extensions are **additive**, so at load time core's checks and a consumer's extension
checks render into ONE merged list under the SAME integers. The rule told the reader not
to conflate them — but the reader is a lead who then writes a bare `Check 24: PASSED`
into the gate log, the durable audit artifact. The whole burden sat on recall, at
exactly the moment the number became permanent evidence, and no rendering anywhere
distinguished the catalogs at the point they are actually used.

Measured on a real consumer at v0.48.0:

- **Four number-shared / title-different pairs**: 20, 22, 23 and — created by v0.48.0
  itself — 24 (core "The adversarial cycle CONVERGED" vs consumer "Financial-display
  ground-truth live-verify").
- **It had already broken.** The "different gate types disambiguate them" luck ran out
  at the sprint-review gate, where the consumer's check 21 and core's check 21 both
  fire. The lead hit two check-21s in one gate entry and improvised `(consumer Check
  21)` by hand into the audit record. Nobody noticed because it was papered over in
  prose.
- **Two absorbed duplicates, carried ~35 minor versions, never once reported.** Core's
  own text records both ("This is graph's Check 21 absorbed as distribution Check 20";
  "Absorbed from graph's Check 33"). The retirement signal could not see either,
  because it joined on the *number* and upstream had absorbed them under different ones.
- **One heading typo disabled four tools at once.** v0.48.0 shipped `### Check 24.`
  where every other check is `### 24.`. Every anchor extractor keys on `^### <n>.`, so
  check 24 vanished from all of them — including the linter that would have caught the
  collision v0.48.0 created, and `audit-machinery-efficacy.js`, whose per-check token
  span runs to the next *matched* header and therefore folded check 24's entire cost
  into check 23.

### Added

- **Catalog labels at the point of use** (Rule 27(d), gate-validation "Consumer-catalog
  crosswalk"). Check headings and gate-log row ids carry their catalog — `[core] 24 — …`
  vs `[ext:<id>] 24 — …`, reusing the `catalog` key `GATE_METRIC v1` already emits. **The
  integer never moves**: the label is *added*, so history maps by identity, nothing is
  renumbered, and an upstream release can never force a consumer to renumber.
- `EXTENSION-CHECK-NUMBER-COLLISION` and `EXTENSION-RESTATES-CORE` in
  `reconcile/layer-drift.sh`, so a consumer learns of a collision from the pull that
  creates it (tagged `NEW-THIS-PULL`) rather than from a confused gate log months later.
  Report-only: a collision is decidable and consumer-fixable, and a consumer must never
  be unable to take a security fix because its own catalog needs relabelling.
- `layer-catalog-collision` adversarial fixture pinning all four catalog states.
- `validate-enforcement-map.sh` I6 (heading ⇔ `CHECK_LOADED` anchor), I7 (the
  manifest-bypass fixture actually seeds the slice it claims), I8 (fixture packaging:
  `core/fixtures/` == install loop == uninstall loop).

### Changed

- **Absorption detection is level-triggered, not edge-triggered.** It used to fire only
  on the single pull that landed an absorption ("present at theirs, absent at base") and
  never again — so a missed report meant the duplicate rotted forever, which is exactly
  what happened twice. Absorption is a *state*; `base` now only tags the finding.
- **The absorption join is number-agnostic**, matching on title, so a check upstream
  absorbed under a *different* number is finally visible.
- **`validate-layer-entries.sh` W1 split by title and given teeth.** Same number +
  different title is now an **ERROR** (E6) for check extensions; same number + same title
  stays a warning (the Rule 27(c) retirement worklist). The linter was already correct
  and already firing on every real consumer — into nothing: it was WARN-only and wired
  into **no CI anywhere**. Now wired into `validate-ci-gates.yml`.
- **The title matcher is tight enough to be a join key.** The old rule (≥2 shared tokens
  of the first 4) matched consumer check 22 "Smoke test evidence" to core check 11 "Smoke
  test coverage for user-facing changes" on `{smoke, test}` — as a join key that proposes
  *deleting* a live deploy-validate check on a financial system. Now Jaccard ≥0.6, or
  ≥0.75 containment of the shorter title (which forgives an appended provenance tag
  without forgiving a different check).
- **`HARD-` is a prefix contract again.** `layer-drift.sh` documents it as one and the
  report builds its blocking list from `HARD-*`, but `SKILL.md`'s apply gate enumerated
  two names literally — so the next `HARD-` status added would have appeared in the
  report under "blocks apply" and then not blocked it.

### Fixed

- `audit-machinery-efficacy.js` attributed consumer narrative "catches" to distribution
  checks **by number** — the exact mis-attribution the crosswalk rule forbids. Core's
  check 24, shipped in v0.48.0, was credited with 15 escalation + 35 retro references
  belonging to the *consumer's* check 24 and classified `EARNED`: a check born that
  release, wearing someone else's fire history. Narrative references are now counted
  against the title-aligned consumer number, and a check with no aligned counterpart
  honestly reports `NO-CONSUMER-TRACE`.
- `### Check 24.` normalized to `### 24.`; anchor extractors additionally tolerate the
  `Check ` prefix, letter ids (`Check AP`, `Check VH` — two `push_candidate: true`
  extensions that yielded *zero* anchors, so absorption of either could never fire), and
  an em-dash separator.
- `uninstall.sh` named 5 of the 9 shipped fixtures, silently orphaning four.
- **The pull filed every fixture where nothing reads it.** `reconcile/preclassify.sh`'s
  `map_consumer()` had no `core/fixtures/` case, so the `core/*` catch-all sent fixtures
  to `.claude/fixtures/` — while `install.sh` writes `tests/fixtures/`, the only path
  `gate-validation.md` and H1 ever reference. Every pull wrote a shadow copy into a dead
  directory, and an upstream fixture never reached the path its own self-test looks in.
  Caught live: v0.48.0 delivered the check-24 fixture to `.claude/fixtures/`, H1 failed,
  and the consumer's lead hand-moved the directory and committed *"H1 fixture
  remediated"* — manually patching around this mapping. An adversarial fixture shipped
  to a path no check reads is worse than no fixture: the catalog claims the check is
  self-tested and it is not.
- **The pull filed every CI template where nothing runs it** — the same defect, same
  catch-all. `core/ci-templates/` went to `.claude/ci-templates/`, while workflows run
  from `.github/workflows/`, which is where `install.sh` copies them. Upstream CI
  updates therefore reached no one, and a real consumer's `validate-retro-compliance.yml`
  has been dormant for that reason rather than any of the ones previously assumed.
  Now mapped to `.github/workflows/` — **and CI stays opt-in**: `install.sh` has always
  copied workflows only `if [ -d .github/workflows ]`, so `preclassify.sh` mirrors that
  guard exactly (`CONSUMER-MISSING-NOOP`). Updating a workflow a consumer *has* is a
  fix; conjuring CI on a consumer that has none is a behavioral change nobody asked the
  pull to make.
- I8 now **evaluates** `map_consumer()` and fails if any `core/` subtree the installer
  also places disagrees with it. The catch-all had silently invented a second home for
  two of them.

- **The pull now retires its own orphans.** New `ORPHANED-RELOCATED` bucket (status `O`):
  when a core subtree's destination changes, the copies already written to the old
  consumer path do not move and do not vanish — every later pull refreshes only the new
  path, so the orphan silently diverges from the file it is a copy of. That is the rot
  the pull exists to prevent, and leaving it to a migration note in a changelog is how it
  never gets done. Emitted **level-triggered** (an orphan is a *state* of the consumer
  tree, not an event in the upstream diff), gated per-path at apply exactly like
  `UPSTREAM-DELETED`, and **safe by construction**: it proposes deleting a file only when
  the bytes still hash-match the blob we shipped. A consumer-edited orphan
  (`ORPHANED-RELOCATED+consumer-modified`) or a file upstream never shipped
  (`ORPHANED-UNKNOWN`) is surfaced for adjudication and never auto-deleted. On a real
  consumer this retires all 29 stale `.claude/fixtures/` files on the next pull, with no
  hand-migration.
- `blob_hash()` in `preclassify.sh` could never report `MISSING`. A bare
  `git rev-parse <rev>:<path>` on a path absent from `<rev>` **echoes its own argument to
  stdout** and *then* exits 128, so `|| echo MISSING` produced the two-line string
  `"<rev>:<path>\nMISSING"` — and every `[ "$h" = MISSING ]` test silently read false. The
  existing buckets escaped it only by accident (the `A` branch never reads `base_h`, the
  `D` branch never reads `theirs_h`). Now `-q --verify`, which prints nothing and exits 1.

## [0.48.0] — 2026-07-12

### The adversary converged in its prose and refused to converge in its field

v0.46.0 told the adversary that *"a clean verdict is a valid outcome, and on a later
pass it is the expected one."* It gave the role no field to write one in.
`SKILL_INVOCATION_PROVENANCE v1` had **no verdict key at all**, so each pass invented
its own — and the invented vocabulary had no success value.

Measured on the S289 `research-requirements` cycle, the first cycle to run under the
v0.46.0 contract:

| Pass | CRITICAL | What it stamped | Cite |
|---|---|---|---|
| 1 | 3 | *(no verdict field at all)* | `s289-rr-adversarial-pass1.md:180` |
| 2 | 4 | `exit_condition_met: NO` — a *different key* than pass 3 used | `pass2.md:252-254` |
| 3 | 7 | `verdict: EXIT CONDITION NOT MET` | `pass3.md:517-518` |
| 4 | **0** | `verdict: EXIT CONDITION NOT MET` — **the identical string** | `pass4-verification.md:492-493` |

Pass 4's residue was 0 CRITICAL, 0 MAJOR, 2 MINOR, and its prose said *"The repair wave
converged… I probed the repair hard — every site of every finding — and it holds."*
Under the severity ladder v0.46.0 itself shipped, where **MINOR / NIT is the nitpick
bucket**, and the step's exit condition of *"continue until only nitpicks remain,"* the
exit condition **was met**. The adversary would not say so in the field, because the
field had no word for it. The lead read the prose instead, applied the two one-line
deletions, and passed the §5 planning gate.

**So the gate passed while the last adversarial artifact of record said the exit
condition was not met.** Termination came from the lead overriding the adversary's own
verdict — the exact dependency on the authoring context that the adversary's
independence exists to remove. Rule 8 had required convergence since v0.46.0 and had
called divergence a HARD_BLOCK. Nothing counted a CRITICAL. Nothing read a verdict. The
requirement was unfalsifiable, so it was decorative.

**The fix is a vocabulary and a script that reads it.**

`core/team-roles/adversary.md` gains a **The verdict** section: four required provenance
fields (`findings_critical`, `findings_major`, `findings_minor`, `verdict`) and the rule
that **the residue decides the verdict, not the reviewer** — `0 CRITICAL + 0 MAJOR` ⇒
`EXIT_CONDITION_MET`; any CRITICAL or MAJOR ⇒ `EXIT_CONDITION_NOT_MET`; more CRITICALs
than the pass before ⇒ `DIVERGENT_HARD_BLOCK`.

`core/scripts/validate-adversarial-convergence.sh` (new) + **gate Check 24** enforce it
across a step's whole pass series: **A** every pass declares an enumerated verdict, **B**
the verdict agrees with the residue it reports, **C** a divergent pass stamps
`DIVERGENT_HARD_BLOCK`, **D** the last pass is `EXIT_CONDITION_MET`. Run against the real
S289 series it returns exit 1 on five violations — both un-verdicted passes, both
divergent steps (3→4, 4→7), and the terminal `NOT_MET` the §5 gate passed over.

The three steps that run the cycle (`research-requirements`, `architecture`, `discovery`)
now say what "nitpick" means instead of leaving it to the reader: it is the ladder's
MINOR/NIT rung, not a feeling.

**The decoy that decides the check.** `tests/fixtures/check-24-adversarial-convergence/`
seeds five series, and the load-bearing one is `nitpicks-remain`: a terminal pass with 0
CRITICAL, 0 MAJOR and **five open MINORs**, which must **PASS**. A validator that reads
"the cycle must converge" as "the last pass must have zero findings" fails it — and in
doing so makes *"continue until only nitpicks remain"* unreachable all over again, one
layer down. That is the v0.46.0 bug reintroduced by its own fix, and the fixture is what
stops it shipping.

`SKILL.md` is deliberately **untouched**: Rule 8 already said the cycle must converge and
that divergence is a HARD_BLOCK. The defect was never the rule — it was that no artifact
could express compliance and no script could measure it. The re-attach window stays at
4,743 tokens (7 under the ceiling), which is also why the edit had to land outside it.

### Fixed — the number that motivated v0.46.0 was wrong

v0.46.0's changelog and `adversary.md` both asserted *"CRITICALs per pass ran 3 → 3 → 6 →
9 and never converged."* The artifacts it cites give **3 → 4 → 7 → 0**. The qualitative
defect was real — findings rose 9 → 14 → 18 and CRITICALs rose every pass — but the
series was miscounted, in a release whose whole subject is a count nobody could check.

Both sites are corrected, and each figure now carries the `file:line` it derives from, so
the next reader re-checks it instead of inheriting it. This is the fifth instance of the
same class: **a number read off a stale label and repeated as fact.** The derivation trail
is the cheap durable guard, and it is the only part of this that generalizes.

## [0.47.0] — 2026-07-11

### The reconcile blanked the config it exists to preserve — and had no gate to notice

Found by a real consumer pull, `0.45.2 → 0.46.0`, on the one file that release touched:
`core/team-roles/adversary.md`.

`setup-sites.md` is the manifest of every location `ai-dlc-setup` fills with consumer
config. Step 7 runs the mask/reinject transform **only for files the manifest lists**;
everything else is a blind overwrite. The manifest did not list `adversary.md`.

It qualified. `ai-dlc-setup/SKILL.md` STEP 2 declares `{adversary_model_personal}` and
`{adversary_model_bedrock}`, and the manifest's own authoring rule is *"every entry MUST
trace to an explicit 'Files to replace in' directive in STEP 2."* It was simply missed:
**`adversary.md` shipped in v0.30.0 (`3727f68`); `setup-sites.md` was last touched in
v0.21.0 (`43bffa0`).** For nine minor versions the manifest was stale and nothing said so.

The consequence, had the pull been applied as written:

```
- Personal: `/model claude-opus-4-8[1m]`          ← consumer's live config
+ Personal: `/model {adversary_model_personal}`   ← what the overwrite would have written
```

Every adversary dispatch then fails on an invalid `/model`. This is the exact failure class
the mask/reinject transform was built to prevent, arriving through the one door it wasn't
watching.

**And nothing in the run would have caught it.** `untangle`'s §7v criterion 4 already
asserts *"zero remaining `{...}` template tokens in any team-role file"* — but **7v is
untangle-only**. The ordinary pull, the path every consumer actually runs, had no
equivalent. A one-line grep stood between a silent config wipe and a loud stop, and it was
only wired into the mode nobody runs twice.

### Fixed

- **`reconcile/setup-sites.md`** — declares `adversary-model-personal` and
  `adversary-model-bedrock`, so mask/reinject fires on `core/team-roles/adversary.md`.

### Added

- **Leftover-token gate in `ai-dlc-update` step 7** (`core/skills/ai-dlc-update/SKILL.md`).
  After the last write and before the re-stamp, the ordinary pull now greps consumer core
  for a template token surviving on a live line (`<!-- ... -->` doc comments excluded —
  those legitimately carry the token text and must survive from `theirs`). A hit means some
  file has an undeclared setup site; the run STOPS before the re-stamp, names the file and
  token, and the missing site is added to the manifest.

  The data fix above closes *this* miss. The gate closes the *class*: a hand-maintained
  manifest will go stale again, and the next time it does the run says so instead of
  quietly overwriting a live value.

## [0.46.0] — 2026-07-11

### The adversary could not converge — its contract made a clean review a failure

Operator observation: adversarial review cycles churn endlessly, each pass returning more
findings than the last. Measured on S289's research-requirements step, CRITICALs per pass ran
**3 → 4 → 7** across the three passes that ran under the old contract, rising every time
(`s289-rr-adversarial-pass1.md:180`, `pass2.md:252`, `pass3.md:517`; total findings 9 → 14 →
18). Rule 8's exit condition is *"continue until only nitpicks remain."* **It was unreachable
by construction.**

> **Corrected in v0.48.0.** This entry originally read `3 → 3 → 6 → 9`, a miscount against
> the artifacts it cites. The defect it describes was real; the series was not. See v0.48.0,
> "the number that motivated v0.46.0 was wrong."

`core/team-roles/adversary.md`, clause 4:

> *"Be adversarial, not agreeable. … "Looks good" with no probed assumption is a **failed
> review**."*

A review that finds nothing had **failed by its own contract**. There was no state in which
"this artifact is sound" was a successful outcome — so on pass 3 the adversary *must* produce
findings, and the newest, least-defended text (the last pass's repairs) is where it looks.

**And it is recent.** Before v0.30.0 (2026-07-08), adversarial review bound to
`code-reviewer`: **zero** phrases demanding a finding, **34** severity terms, and an explicit
*"approve, request changes, or block"* — approval was a valid outcome. v0.30.0 replaced a
bounded, severity-disciplined reviewer **that could approve** with an unbounded adversary
**that fails if it approves**. The *role* was right (a diff-scoped code-reviewer is the wrong
critic for a planning artifact, which is why v0.30.0 happened); the **contract** was the bug.

This is not merely a pickier reviewer. Pass 3's own summary: *"Pass-2's repair wave injected
five new CRITICALs, three of them defects the repair itself created"* — a half-applied
`S0`–`S7` rename leaving a mapping that says the opposite of the repair, and a corrected row
contradicting the red-proof row thirteen lines above it. **The repair step manufactures
defects faster than review removes them**, and an adversary that must find something
guarantees the loop never ends.

### Changed
- `team-roles/adversary.md` — a **probed clean verdict is a valid, completed review**, and on
  a later pass the *expected* one. Manufacturing a finding to justify the pass is now the
  named failure mode, and is worse than a clean review: it sends the lead to edit a correct
  artifact, and the edit is where new defects come from. An *unprobed* "looks good" is still a
  failed review; a *probed* "this holds" is a completed one.
- `team-roles/adversary.md` — **falsifiable severity bar.** CRITICAL requires naming the
  concrete failure (ships wrong behaviour / an AC cannot pass / a LOCKED requirement
  contradicted). *"If you cannot state it, it is not CRITICAL."*
- `team-roles/adversary.md` — **pass 2+ reviews the REPAIR**, not the document again: each
  prior finding marked repaired / partially / not / **repaired wrongly**. No re-litigating a
  settled disposition without *new evidence*. Divergence reported in the first line.
- `SKILL.md` Rule 8 — **divergence is a HARD_BLOCK, not a reason for another pass.** More
  CRITICALs than the pass before means the repairs are injecting defects; another pass only
  finds the next wave. Usual cause: an artifact over its Rule 25(d) budget, too
  cross-referenced to edit safely (S289's PRD was at **194%**).

### Notes
- **The re-attach window is now saturated.** The recovery protocol ends at 4,743 tokens
  against a 4,750 ceiling — **7 tokens of headroom**. Rule 2(d) (v0.45.3) and Rule 8's
  convergence clause each fit alone but not together; both had to be tightened. The next rule
  added *above* the POST-COMPACT RECOVERY PROTOCOL will fail
  `validate-reattach-budget.sh`. Relocating narrative below the protocol is the standing
  remedy (v0.36.2); a structural fix to the pre-protocol region is now owed.

## [0.45.3] — 2026-07-11

### The context sensor told the lead to hand off, citing the rule that forbids it

Reported by the operator: the S289 sprint **stopped itself for a handoff nobody asked
for**, mid-step, with three teammates that had already delivered.

`ai-dlc-context-sensor.sh`'s IMMINENT advice closed with:

> *"…prefer **Rule 2(a): hand off** via /clear + /ai-dlc resume. Compaction is strictly
> lower fidelity than the handoff."*

Rule 2(a) **is** human-requested handoff. Rule 2 says: *"Only path (a) initiates a
handoff. Paths (b) and (c) are reminders only. **The lead does NOT force handoff at any
threshold.**"* The hook was instructing the lead to take the one path only a human can
initiate — and citing the rule that forbids it to do so. Worse, the wrapper text around
the same injected message said *"the decision is the user's"*, so a single reminder
carried both a permission and an imperative. **The lead resolved that contradiction in
favour of the imperative.**

Observed live: IMMINENT fired at 333k/380k; the lead refreshed the snapshot, announced
*"the handoff is safe to take"*, stopped three delivered teammates, and ended the
session. At RED the same lead had correctly held the line — because the RED string
happened to carry an *"if continuing, do so deliberately"* escape that IMMINENT lacked.

**Not caused by v0.45.x** — the advice is unchanged since v0.36.0. It was *exposed* by
v0.45.0: with the poll-loops gone the session stopped compacting every ~33 minutes and,
for the first time, ran long and clean enough to reach a legitimate IMMINENT.

Rule 2 also had a gap that let the lead improvise: it defined (b) yellow and (c) red,
while the sensor has emitted a **fourth** level, `imminent`, since v0.36.0 — a level the
rule never named. Now named as **(d)**, explicitly non-blocking.

### Fixed
- `ai-dlc-context-sensor.sh` — no ADVICE string issues a handoff imperative. All three
  now tell the lead to refresh the snapshot, **CONTINUE**, and surface the trade-off for
  the *operator* to call. The invariant, the live failure, and an editing test ("would a
  reader with no other context read this as an instruction to the lead?") are in the
  hook header.
- `SKILL.md` Rule 2 — adds threshold **(d) imminent**; states plainly that **a threshold
  is not a request**: the lead may *name* a handoff as an option, never *take* one.

### Notes
- Re-attach budget held: the recovery protocol ends at ~4,643 tokens (357 of slack).
  The first draft of the Rule 2 wording left only **15 tokens** under the ceiling, so the
  rationale was relocated to the hook header — narrative moves, mechanism stays
  (v0.36.2's rule).

## [0.45.2] — 2026-07-11

### The layer-drift validator could not detect a dangling step pointer

Found while reviewing the 0.45.1 reconcile on the reference consumer.
`validate-layer-entries.sh` reported `Step 0a` as a dangling pointer — but `route.md:53`
**defines it**. Pulling that thread found the check broken in both directions, because
it collapsed two different namespaces into one.

The rulebook spells step sections two ways: `route.md` uses `### Step 0a:` (word +
colon); every other step file uses `### 2a.` (number + dot). The validator only ever
harvested the second form, so **route.md contributed zero definitions** while its own
headings were still scanned as *references*.

Those references then resolved against a global pool that also held
`gate-validation.md`'s **check** numbers (`### 9.`, `### 12.`) — a different namespace
entirely. So a reference to a step that does not exist was **silently satisfied by a
same-numbered gate check**. Verified by injecting `Step 9` and `Step 12` into route.md:
neither step exists anywhere, and the validator accepted both. **It could not detect the
one thing it exists to detect.**

Gate checks are cited as "Check N" throughout the corpus, never "Step N" (183 vs 190
occurrences, zero cross-uses), so they now contribute nothing to the step namespace —
including their extension/override copies, which restate the same numbers and leaked
through a first, narrower fix.

### Fixed
- `validate-layer-entries.sh` — step references resolve against step definitions only.
  False positive cleared (`Step 0a`), false negative closed (`Step 9`/`Step 12` now
  caught), legitimate `### 2a.` section references still resolve. Clean-tree warnings on
  the reference consumer: 28 → 26, the delta being exactly the two bogus ones.

### Notes
- A false negative in a drift detector is worse than noise: it means the check reports
  green on the failure it was built for. This one had been reporting green since Rule 27
  was mechanized in v0.34.0.

## [0.45.1] — 2026-07-11

### Check B scored attempts, not outcomes — a working hook manufactured its own violations

Found by running v0.45.0 against the reference consumer's **first post-update sessions**.
Two defects, both in `validate-steering-budget.sh` Check B, both the same shape: **the
check read `tool_use` and never looked at what happened.**

**A — a blocked attempt is not a steamroll.** When `ai-dlc-acknowledge.sh` *denies* an
advancing call, the `tool_use` still appears in the transcript; the deny lands on the
`tool_result` (`is_error: true`, carrying `AI/DLC Rule 29: the pipeline is PAUSED`).
Check B counted the blocked attempt and reported *"the lead received the steer and
executed straight through it"* about a call that **never executed** — scoring the hook
*working* as the failure the hook prevents. Live evidence: the consumer's post-update
sessions showed 2 "steamrolls" while the flow log showed **3 `ACK_DENIED` events at the
same moments**. The hook had stopped every one. The old remedy text made it worse —
*"if these violations are recent, the hook is not installed"* — which was exactly
backwards. Removed.

Check B now scores **outcomes**. This both removes phantoms and **unmasks real ones**: a
denied attempt used to record a hit and halt the forward walk, hiding any genuine advance
that followed it.

**B — the updater is not the pipeline.** `_bmad-output/ai-dlc-update/**` is
`/ai-dlc-update`'s own scratch space (reconcile report, push-candidate ledger). It is a
*different skill* from `/ai-dlc`: it advances no sprint and runs precisely when the
pipeline is **not** running. Both the hook and Check B treated a write there as pipeline
advancement — so the updater was **denied mid-reconcile on its own ledger**, by a rule
about a pipeline that wasn't running. Excluded from both.

### Fixed
- `validate-steering-budget.sh` Check B — scores outcomes, not attempts; excludes
  hook-denied calls and `_bmad-output/ai-dlc-update/**`.
- `core/hooks/ai-dlc-acknowledge.sh` — no longer denies the updater's own artifacts.

### Notes
- Corpus-wide Check B: **114 → 95 → 82**. Each correction removed a class of *machine*
  event being read as a *human* one — the circular-acknowledgement draft, then the
  compact-resume phantom, now the blocked attempt. Three instances of one mistake; the
  pattern is now named in the script header so the next reader doesn't make it a fourth.
- Consumer effect of the update landing: the reference consumer's resumed sprint went
  from **8 foreground calls over budget (worst 10.0 min, returning `TIMEOUT`)** to **zero,
  longest wait 111 s**, and from **6 auto-compactions in 3h16m** to **0 in 88 min**. The
  Rule 29 bounded file-wait beat is being used as specified.

## [0.45.0] — 2026-07-11

### Planning latency — the ratchet, the missing join, and a meta-check that proved nothing

A consumer sprint spent **3h16m in planning without finishing it**, and reported that
long planning cycles recur. Measured from the live transcripts: **99.7% machine time**
(three human turns in the whole span), advancing exactly two planning steps of six,
with six auto-compactions at ~33-minute intervals and a peak of 342K tokens against a
380K window. Three structural defects, all mechanized here.

**Defect A — the join was improvised, because none existed.** Rule 29's bounded-join
keys on a `task_id`, and the `Skill` tool returns none: `/bmad-party-mode` spawns its
personas *inside* the sub-skill (Rule 20(i)), so the lead holds no handle. Rule 20's
"File-write deliverable" clause made the lead's read of the expected path the check —
but attached no *wait semantics* to it. Handed an async spawn, a mandatory join, and
no join primitive, the lead wrote `until [ -s "$d/s289-pm.md" ]; do sleep 20; done` as
one `Bash` call. It runs to the harness's 10-minute cap and returns `TIMEOUT` having
learned nothing. Six such calls in one planning phase cost 52 minutes, **29 of them
past the point of no return**.

Rule 29 gains the **bounded file-wait beat**: a beat is one foreground `Bash` call
that returns within `steering_budget` (it may poll *inside* itself); the *sequence* is
bounded by `max_wait_beats` (default 10); exhaustion means the deliverable is absent,
which Rule 20 already calls non-delivery — re-dispatch, then HARD_BLOCK. **The loop
goes in the beat count, never inside the call.**

`validate-steering-budget.sh` gains **Check C** (sequence bound) and its Check A hint
is now shape-aware — it used to tell a filesystem poll to "use `TaskOutput(task_id)`",
which is precisely the primitive that does not exist for it.

**Check B had a false-positive class.** It counted the harness's own auto-compaction
resume prompt as an operator steer, so the lead advancing afterward — *the POST-COMPACT
RECOVERY PROTOCOL working as designed* — was logged as a steamroll. **19 of 114 (16.7%)
of the corpus's violations were this phantom; the real figure is 95.** Same error class
as the circular-acknowledgement draft the script already warns about: a machine event
read as a human one.

**Defect B — every size threshold was warn-only and fired at retro.** A ratchet with no
pawl: the only mechanism that would notice an oversized artifact ran at the end of the
sprint that had already paid for it. Artifacts climbed every sprint; planning got
slower every sprint. Rule 25(b)'s whole-read exemption was justified by *"rely on (a)
keeping it bounded"* — an assumption, never a check. In the consumer, `product-brief.md`
reached 480 KB (2× budget) and `carry-over-evaluation` whole-read it 11 times anyway.

New `validate-artifact-budget.sh` owns the canonical budgets and remedies (they are no
longer restated in `retro.md` prose — a threshold in prose is one that drifts from the
one that executes). Enforcement moves to where it is still cheap:

- **`route.md` Step 1a (sprint start) — HARD_BLOCK.** The last moment an oversized
  artifact costs nothing to fix, and upstream of `carry-over-evaluation`'s whole-read.
- **Gate Check 14 — FAILS the gate** for `pipeline-snapshot.md`, the only artifact that
  grows *within* a sprint and the pipeline's single largest byte-injector (50 KB,
  whole-read 8 times in one planning phase — at every gate, every resume, every
  compaction). Rule 23's exemption permitting those re-reads was explicitly
  *"conditional on their staying small, which is not automatic."* Now it is.
- **`retro.md` — warn-only, unchanged.** The sprint already paid; retro reports.

**Warn at 100%, block at 100% + grace** (default 10%). The grace band is aim, not
softness: a ratchet announces itself in *multiples* — the consumer's real breaches were
161%, 215%, 526% and **3311%** of budget. A gate that also failed at 104% would have the
lead trim 300 tokens, watch the artifact grow back by the next gate, and fail again. That
treadmill turns a real signal into noise. Over-budget is always reported; only a breach
past the band blocks.

Rule 25(b)'s exemption is now void when the artifact is over budget. Rule 25(c) names
`context-mode-protection-log.md`, which had **no rotation and no threshold at all** (210
KB in the consumer) and now has both.

**Defect C — H2 was vacuous, not merely repetitive.** The meta-meta-check that guards
the gate's own integrity ran at every gate (4–6× per planning phase). All three of its
`seed.sh` files were `echo` statements describing, in English, fixtures that were never
written to disk. **H2 read a description of a test and adjudicated that.** It could not
fail, and it never did. Worse, `check-17-bypass`'s V5 — the forgery floor, the variant
proving a well-formed-but-forged provenance block is caught only by the heavyweight
byte-match — carried `mode: solo`, tripping `validate-provenance-block.sh`'s Rule 20
assertion *before* the SHA branch was reached. The README asserted "V5 passes that
script." It did not, and the floor was never tested.

The fixtures now write real files. `check-17-bypass/run.sh` drives the real validators
and asserts the full matrix, standing up a throwaway git repo so V5's fabricated SHA has
something to fail against — and it fails loudly with `the forgery floor is UNTESTED` if
V5 ever regresses to failing the first script. New `validate-h2-attestation.sh` makes H2
attest **once per sprint**, pinned to a digest of the fixture set: change any byte and
the digest moves, every attestation carrying the old one is void, and H2 re-drives in
full. **Deduplication, not pruning — the check keeps every tooth.**

### Added
- `core/scripts/validate-artifact-budget.sh` — Rule 25(d) budgets; blocking at sprint
  start and at gate Check 14, warn-only at retro.
- `core/scripts/validate-h2-attestation.sh` — digest-pinned, once-per-sprint H2.
- `core/fixtures/check-17-bypass/run.sh` — drives the real validators; asserts the
  V1–V5 matrix including the forgery floor.
- `validate-steering-budget.sh` Check C — bounds the wait *sequence*, not just the call.

### Changed
- Rule 29 — bounded file-wait beat for `Skill`-tool spawns (no `task_id` exists).
- Rule 25(b) — whole-read exemption is void when the artifact is over budget.
- Rule 25(c) — names `context-mode-protection-log.md`; `retro.md` §4b rotates it.
- Rule 25(d) — no longer "warn-only, never blocks."
- Rule 20 "File-write deliverable" — points at Rule 29 for *how long* to wait.
- `gate-validation.md` H2 — once per sprint, digest-pinned.
- `retro.md` Close-Out Sweep — calls the script instead of restating the thresholds.
- `core/fixtures/{check-17-bypass,check-h1-recursion,check-manifest-bypass}/seed.sh` —
  these now write files.

### Fixed
- `validate-steering-budget.sh` Check B counted auto-compaction resume prompts as
  operator steers (19 of 114 violations were phantom; the real figure is 95).
- `check-17-bypass` V5 `mode: solo` short-circuit — the forgery floor was untested while
  its README asserted the opposite.

### Notes
- **Check C is dormant by construction.** Zero catches across 278 consumer sessions,
  even at a ceiling of 2 — no lead has ever run 3 consecutive bounded wait-beats,
  because until this release there was no reason to slice a poll at all. It bounds a
  shape *this release introduces*. Stated here rather than implied; see the Rule 29
  minimum-mechanism note for its removal condition.
- **Not fixed here:** `sprint-status.yaml` was frozen at S288 `status: done` in both
  paths while S289 ran. A correctness landmine, not a wall-clock cause — folding it in
  would blur two unrelated changes.
- A consumer must sync to consume any of this. The reference consumer runs skill 0.41.0
  against a 0.44.0 distribution; the 0.41.0 → 0.44.0 hop alone already kills the
  analyst/adversary/dev poll-loop class.

## [0.44.0] — 2026-07-11

### Operator steerability — bound the blind window, give the pause flag teeth

The operator could not reliably steer a running pipeline. Two independent
defects, both now mechanized.

**Defect A — the steering window was unbounded.** Claude Code delivers a queued
operator message at a *tool-call boundary*; it rides in beside the next tool
result. A long turn is therefore harmless. What silences the operator is a long
*single tool call*: while one is in flight there is no boundary, so the message
cannot land. The blind window equals the in-flight call's duration.

`Agent` is the only unbounded foreground primitive — `Bash` and `TaskOutput` are
harness-capped at 10 minutes, and `AskUserQuestion`'s duration is the operator's
own think-time. And ai-dlc *mandated* it: `implementation.md`'s
"Foreground-dispatch mandate" required gated dev dispatch to be a blocking
`Agent` call and explicitly forbade `run_in_background`. Measured across 278
consumer sessions: **355 foreground `Agent` calls blocked longer than 2 minutes,
the worst for 36 minutes** — 36 minutes in which the human physically could not
be heard.

Replaced by **bounded-join dispatch** (new **Rule 29**): spawn with
`run_in_background: true`, then join in bounded beats —
`TaskOutput(task_id, block: true, timeout: 120000)`. Each beat returns within the
steering budget carrying the teammate's full result, or `status: running`. The
join is preserved (a gated cycle stays gated; nothing is detached), Rule 3 is
preserved (every beat is a tool call, so the lead never emits a text-only
response and never stalls), and parallel wave dispatch is preserved. The lead
does **not** end its turn to let the operator in — that would trade a queued
prompt for a dead pipeline.

**Defect B — the pause flag had no teeth.** `ai-dlc-pause.sh` sets
`_bmad-output/pipeline-paused.flag` on every operator message and instructs the
lead not to advance while it exists. That flag was read by exactly two consumers
— the Stop hook and the driver signal — and **nothing enforced it against a tool
call**. So the contract was prose aimed at a lead simultaneously under Rule 3
("Keep working. Do not ask if you should continue.") and the Stop hook's
forced-continuation reason. The steer, arriving mid-turn beside a tool result,
lost. **111 operator messages in the consumer corpus were followed by a
pipeline-advancing call before the flag was ever released.**

New `PreToolUse` hook `ai-dlc-acknowledge.sh` denies `Agent`, `Task`, `Skill`,
`TaskCreate`, and `_bmad-output/` writes while the flag is set. `Read`, `Grep`,
`Glob`, and `Bash` stay allowed — so the lead can investigate the operator's
question, and so the `rm` that releases the flag is always available. Denying
Bash would have wedged the pipeline permanently; the escape hatch is deliberate.

### Added
- **Rule 29 (steering budget)** in `SKILL.md` — the invariant, the bounded-join
  mechanics, and the acknowledge contract. `run_in_background: true` is now the
  default for every spawn, not an exception.
- `core/hooks/ai-dlc-acknowledge.sh` — `PreToolUse` deny hook (Defect B). Logs
  `ACK_DENIED` to the flow log.
- `core/scripts/validate-steering-budget.sh` — audits a transcript for (A)
  foreground calls exceeding the budget and (B) steamrolled operator messages.
  `AskUserQuestion` is exempt from (A): its duration is human think-time, not
  machine starvation.
- `retro.md` §4b — operator-steerability audit, **then flow-log rotation**. Also
  gives `pipeline-continuation-log.md` its first live consumer; both hooks'
  headers had claimed "Retro reviews this log" since inception, and nothing ever
  did.
- **Flow-log rotation (Rule 25(c)).** `pipeline-continuation-log.md` was
  append-only with **no bounding mechanism at all** — 1.3 MB / 5,418 events
  spanning every sprint ever run in the reference consumer. Rule 25(c) already
  required rotation for "`gate-log.md` and similar logs," but "similar" bound the
  flow log to nothing, so no step ever rotated it. Now: Rule 25(c) names the file
  explicitly, and `retro.md` §4b rotates it per sprint to
  `pipeline-continuation-log-archive-s<N>.md` (cut-and-paste, verbatim;
  write-only). Rotation is unconditional and per-sprint, not threshold-triggered
  — a threshold would let several sprints of unrelated events bleed into an audit
  scoped to one. Ordering is load-bearing: **audit first, rotate second**, or
  rotation destroys the evidence §4b reads. All three hooks re-seed the header on
  their next write, so the live log reopens clean with no manual step. A
  10k-token threshold is registered in the artifact-size audit to catch a *missed*
  rotation.
- `ACK_DENIED` documented in the event taxonomy all three hooks seed.

### Changed
- `implementation.md` — "Foreground-dispatch mandate" → **"Bounded-join dispatch
  mandate."** A blocking dev dispatch is now a lead-conduct retro finding. The
  parallel-wave requirement is unchanged.
- Rule 24 dispatch contract — analyst spawns inherit bounded-join.
- `templates/settings.json.template` — registers the new `PreToolUse` hook.
- `scripts/install.sh` — `validate-steering-budget.sh` added to the enumerated
  script loop (the packaging trap: `core/scripts/` alone does not ship it).
- `enforcement-map.yaml` — `steering-budget` enforcer entry.

### Measurement note
Aggregate operator-latency joins over these transcripts are lossy and were not
used to size this work. Enqueue↔delivery matching drops ~50% of prompts, skewed
toward the repeated control words (`handoff`, `approved`) that hang; and a first
pass at "how long until the lead replies" silently excluded every message the
lead never answered — i.e. it excluded Defect B from the statistic meant to
measure Defect B. A "633-minute Bash" cited in early analysis was an artifact of
that lossy pairing and is retracted; the true foreground ceiling is `Agent` at
36.2 minutes. The mechanisms above are established by direct tool-duration
measurement and by the 111 flag-lifecycle violations, not by those joins.

## [0.43.0] — 2026-07-11

The four per-sprint analyst drafts are now written to sprint-stamped paths, so a
new sprint can no longer destroy the previous sprint's draft.

This started as a request to *reset* `carry-over-evaluation.md` at every pipeline
start. Investigation showed a reset is a no-op — the file never accumulates. All
40 commits touching it in a real consumer are wholesale rewrites, and line counts
sawtooth (101 → 810 → 101 → 800) rather than growing. The analyst already
truncates it by overwriting.

The real defect is the opposite one. These drafts have no reader in the pipeline,
no template, no size threshold, and no history/archive pair, so the overwrite is
not "an overwrite" — it is a total, unrecoverable-outside-git destruction of the
prior sprint's draft. And downstream artifacts cite *into* the file. In the
consumer, `story-262-1` carries `<!-- Source: … carry-over-evaluation.md §7 F6 …
-->` and the file on disk, thirty sprints later, has no §7 at all. The pointer
still resolves — against the wrong sprint's document. A silently-wrong answer,
not an error. Resetting the file would have converted silent destruction into
eager destruction and violated Rule 25(a) ("move, never delete").

The model had already noticed: the consumer holds 111 hand-made sprint-prefixed
files (`s166-carry-over-evaluation.md`, …) working around the missing lifecycle.
The repo used that convention through S241, then drifted into the single
overwritten file at S242.

### Added

- **Rule 24 sprint-stamped drafts.** The four per-sprint analyst drafts are
  written to `s<N>-<base>.md`, where `<N>` is `sprint_id` from the pipeline
  snapshot: `s<N>-carry-over-evaluation.md`, `s<N>-discovery-context.md`,
  `s<N>-research-notes.md`, `s<N>-architecture-context.md`. Each is immutable
  *across* sprints by construction — no rotation, no archive step, no reset, no
  staleness window. (Not append-only *within* a sprint: re-drafting sprint N
  correctly overwrites sprint N's own file.) The stamp lives in the filename; the
  draft's H1 is prose and is never parsed.
- **`route.md` Step 6 resolves `sprint_id`.** The sprint number previously had no
  mechanical source: `sprint-status.yaml` still holds the *previous* sprint
  (`status: done`) until `stories-test-strategy` writes the new one — which runs
  *after* the steps that need the stamp — and nothing in `core/` creates or bumps
  that file at all. Step 6 already runs at the "new pipeline starts" moment and
  already initializes the snapshot, whose Sprint Context already carries a
  `sprint_id` field. It now resolves it: absent file → 1; `status: done` → N+1;
  in-flight → N; the two `sprint-status.yaml` copies disagreeing → HARD_BLOCK.
  `none` is a hard stop, never an unstamped fallback. **This is what the original
  "reset at pipeline start" instinct was reaching for — the thing to establish at
  pipeline start is the sprint identity, not a truncated file.**
- **Check 23 + `validate-draft-stamps.sh`** (planning gates, HARD_BLOCK). Two
  halves, because the drift has two surfaces. *Disk:* no unstamped draft may
  exist in `planning-artifacts/` — this fires on the rendered outcome, catching a
  core regression and a consumer override equally. *Layer:* no
  `extensions/`/`overrides/` entry may declare an unstamped write path — a
  `kind: step-domain` extension restates its step's whole Section 0, including the
  output path, so it can revert the stamp in the rendered pipeline while core
  looks correct (the v0.34.0 lesson). Both halves anchor on the
  `_bmad-output/planning-artifacts/` path prefix, never a bare basename: every
  step file's own name collides with its artifact's, and `route.md`'s pipeline
  table legitimately names the *step* `carry-over-evaluation.md`.
- **Fixture `check-23-draft-stamps/`.** Four trees. `bad-disk` and `bad-layer`
  must FAIL; `good` and `decoy` must PASS. `bad-layer` is not hypothetical — it is
  the real consumer's `carry-over-evaluation-domain.md:15` shape verbatim.
  `decoy` is the case that decides shippability: it seeds the step-file name
  collision *and* every out-of-scope artifact.

### Fixed

- **Phantom pointer** (`gate-validation.md`, Check 3 origin-anchoring): cited
  `_bmad-output/planning-artifacts/carry-over-items.md`, a path that exists
  nowhere in the distribution or any consumer. Every other site says
  `carry-over-backlog.md`.
- **H1 fixture enumeration** was missing Check 3b, whose fixture has existed
  since v0.40.0. H1 verifies "each phase-specific check ships a fixture" against
  a hand-maintained list, so it cannot catch its own omissions.

### Scope — deliberately not stamped

Four other analyst drafts look similar and were cut after checking them, per Rule
26(a):

- `codebase-analysis.md`, `brownfield-inventory.md`, `doc-reconciliation.md` —
  one-shot *onboarding* artifacts, not per-sprint drafts (the consumer's
  `brownfield-inventory.md` has 2 commits and an H1 of `# Brownfield Inventory`,
  no sprint at all). They also have real in-pipeline readers by path
  (`discovery.md`, `doc-repair-backfill.md`). Stamping them would break four
  working reads to fix a defect they do not have.
- `bug-analysis.md` — bug-keyed, not sprint-keyed; two bugs in one sprint would
  collide on the same stamp, and the bug pipeline runs an `implementation` gate,
  never a `planning` one.

Cutting these is what makes the change nearly free: **the remaining four have
zero readers by path**, so no call sites needed updating.

A **citation-grammar validator** was designed and then cut for vacuity. Current
stories cite stable item IDs (`CO-S288-CHECK5-CANNOT-FIRE`), which are
sprint-stamped by construction and do not rot; the rotted `§section` pointers are
concentrated in an older era. A validator firing zero times on the current corpus
would have reproduced the exact "check that cannot fire" defect the consumer's
last sprint existed to fix.

### Migration

Stamped-at-write has no implicit grandfathering — the disk half fires immediately
on any unstamped draft. At adoption, one-time in the consumer: `git mv` each of
the four live unstamped drafts to its `s<N>-` name (read the sprint from git
history, **not** by parsing the H1 — observed H1s include `Sprint S286` and
`Sprint 285 (draft)`), and update any `extensions/`/`overrides/` layer that
restates a draft write path. Check 23 names exactly what to fix.

## [0.42.0] — 2026-07-10

The context sensor (`ai-dlc-context-sensor.sh`) is now compaction-aware: it only
reads a token count from an assistant turn that lands *after* the most recent
`compact_boundary`.

The sensor derives resident context from the last main-thread assistant
`message.usage` in a bounded tail-read. That reading flips at a compaction: the
last *pre*-compaction assistant line still carries the old, large usage, and on
the first `PostToolBatch` after an auto-compact that line is the newest one on
disk — the post-compaction turn has not been written yet. The unguarded
tail-read selected it, reporting the *pre*-compaction window as resident and
firing a false `IMMINENT` one request after compaction had just reclaimed the
space. Observed live on the `graph` consumer: `~265,909 / 88% / IMMINENT`
emitted immediately after a compact whose real resident context was `80,851`
(27%). The false signal drove a premature snapshot-finalize and a spurious
`/clear` handoff recommendation, and — because the sensor's "reconcile the
snapshot Context Reminders fields to this reading" directive outranks
`ai-dlc-recover.sh`'s "reset fire-state to none" — re-poisoned the fire-state
the recover hook had just cleared.

The fix locates the most recent boundary in the tail window and takes the last
assistant-with-usage line that follows it; a boundary with no post-boundary
reading yet stays silent, the same fail-open as a fresh transcript. It
self-heals within one turn as the post-compaction usage lands. Two fixtures
(`post-compact-stale`, `post-compact-reattached`) pin the guard.

## [0.41.0] — 2026-07-10

`ai-dlc-update` git preflight now auto-pushes a push-resolvable branch instead
of stopping for the operator.

The v0.37.0 preflight correctly blocks a reconcile when the consumer branch does
not match `origin` (a branch cut off an un-synced branch and merged to `origin`
strands local commits or reconciles against a stale base). But for the two states
whose remedy is *literally a push* — **AHEAD of upstream** (unpushed commits) and
**no upstream** (never pushed) — it stopped and asked the operator to run
`git push` by hand, then re-invoke. That is a needless halt: the skill already
performs autonomous push→PR→merge in steps 2 and 8, so publishing the operator's
own commits on their own branch is within its authority and is the exact fix.

### Changed

- **`core/skills/ai-dlc-update/SKILL.md`** — step-1 preflight (and the step-7
  re-confirm): **AHEAD** → `git push`; **no upstream** → `git push -u origin
  <branch>`; then proceed. A rejected/failed push (auth, network, protected
  branch, or the remote advanced mid-run making the branch truly diverged) still
  STOPs with the exact error and remedy. **BEHIND** and **DIVERGED** remain STOP
  — their remedy is a pull/rebase, which can conflict and is not a push.

## [0.40.0] — 2026-07-10

Mechanized gate Check 3b: a story's `LOCKED_REQUIREMENTS` full-text citation
must resolve verbatim to the byte-verbatim source of record, not a condensed
index.

A live consumer running the story-authoring step degraded requirement text to
one-line ≤250-char summaries "to stay under the ctx index threshold," citing
`prd.md:LR-<n>` as the "full text" source. Two defects stacked: (1) a **category
error** — the ctx `INTENT_SEARCH_THRESHOLD` (5,000 bytes) gates only what
re-enters the conversation on an intent-bearing tool call; it never gates what is
written to a file, so degrading a durable artifact to satisfy it is degrading it
for no reason; (2) **mis-anchored + lossy propagation** — the brief is the
byte-verbatim source of record (where `discovery.md` §4a extracts the block),
while `prd.md` carries only a §2a-propagated condensed index, so "full text"
resolved to summarized text. Gate Check 3 does INTRA-artifact drift detection (a
LOCKED block vs. its own body) and never compares a story's block against the
parent source of record, so a story whose block and body carry the same summary
passed Check 3 while still being lossy. That is the hole this closes.

### Added

- **`core/scripts/validate-locked-anchor.sh`** — Check 3b enforcer. For each
  `full_text_source: <artifact>:<anchor>` in a story `LOCKED_REQUIREMENTS` block,
  asserts (a) the artifact is the byte-verbatim source of record (default
  basename `product-brief.md`, overridable via `--sor`) and not a self-declared
  condensed index, (b) the anchor exists, (c) every requirement bullet is
  byte-present at the anchor (whitespace-collapsed). Honest cite-by-reference
  (`requires_context:`) and blocks with no full-text claim are untouched — no
  false positives on legitimate pointers.
- **Check 3b** in `enforcement-map.yaml` (script-adjudicated, `gate_types:
  [story]`, hard-block) and in the `gate-validation.md` GATE_MANIFEST story row.
- **`core/fixtures/check-3b-locked-anchor/`** — discriminating fixture: a story
  citing an index as `full_text_source` (must FAIL) paired with a verbatim
  citation plus honest `requires_context:` pointer (must PASS).

### Changed

- **`gate-validation.md`** — new Check 3b heading/anchor documenting the
  `full_text_source:` vs `requires_context:` schema, the three checks, and a
  category-error rider (tool thresholds never gate file writes).
- **`stories-test-strategy.md` §2a** — documents the full-text-claim vs
  load-pointer distinction and the ctx category error to avoid.
- **`scripts/install.sh`** — ships `validate-locked-anchor.sh` and the
  `check-3b-locked-anchor` fixture through the two hardcoded install loops.

## [0.39.0] — 2026-07-10

Mechanized the post-compact re-attach budget as a commit-time validator.

Claude Code re-attaches only the first ~5,000 tokens of `SKILL.md` after a
compaction, and the POST-COMPACT RECOVERY PROTOCOL must sit entirely inside that
window — or the instructions for recovering from a compaction are the ones a
compaction drops (this happened in v0.35.0: ~400 tokens of the protocol were
themselves discarded). The v0.35.0 reorder left ~561 tokens of slack, but nothing
caught an overrun at commit time — only `retro.md`'s self-check, which runs per
sprint and eyeballed the "whole body precedes the cut" invariant. A single edit
ABOVE the protocol could silently push its tail past 5,000 between retros.

### Added

- **`core/scripts/validate-reattach-budget.sh`** — measures bytes from the start
  of `SKILL.md` through the end of the `## POST-COMPACT RECOVERY PROTOCOL` section,
  estimates tokens (bytes/token divisor calibrated to the v0.35.0 measurement:
  17,990 bytes ≈ 4,439 Claude tokens), and FAILS if the protocol end exceeds the
  re-attach window minus a safety margin (defaults: 5000 budget, 250 margin, so it
  trips at ~4,750 tokens — before the real cliff). FAILS loudly if the protocol
  heading or its end boundary is missing (structure moved → re-measure). Current
  state: ~4,497 tokens, ~503 slack, PASS. Budget/margin/divisor are env-overridable.
  Copied to consumers via `install.sh` alongside the other validators.
- **`retro.md` Rule File Audit** now runs `validate-reattach-budget.sh` for the
  whole-body invariant it previously only asked the auditor to confirm by eye, and
  records its PASS/FAIL + slack in the resident-ordering scan.

## [0.38.0] — 2026-07-10

`ai-dlc-update` re-invokes itself automatically after a self-update instead of
asking the operator.

When a pull included a change to the update skill's own files, step 2 landed that
self-update and then HARD-STOPPED to ask the operator to choose: re-invoke,
continue on stale logic, or hold. The re-invoke is the only correct answer — an
operator who just updated the tool wants to run its latest iteration, and the
in-flight agent can't hot-reload its own instructions, so re-invoking is the only
way to execute the fresh logic. The question added a round-trip with no real
decision behind it.

### Changed

- **`ai-dlc-update` self-update (step 2)** (`core/skills/ai-dlc-update/SKILL.md`).
  After the self-update merges, the run now reports what landed in one line and
  **automatically re-invokes `/ai-dlc-update`**, carrying the operator's original
  argument (bare → fresh dry-run; `apply` → `apply`). No operator prompt. The only
  path that returns control is a harness that cannot self-invoke a skill — then it
  says so and tells the operator to run `/ai-dlc-update` themselves. Continuing on
  stale logic remains forbidden. The step-2 recap block at the end of the skill was
  updated to match.

## [0.37.0] — 2026-07-10

`ai-dlc-update` gains a git preflight so a diverged local branch no longer forces
extra reconciliation on the next run.

The update skill cuts its reconcile branch off the consumer's current branch, and
step 2's autonomous self-update pushes and auto-merges to `origin` on every
invocation — including a bare dry-run. Neither checked whether the current branch
matched `origin` first. When the branch had unpushed commits (or was behind, or
had never been pushed), cutting/merging off that base diverged local from `origin`
the moment a PR merged, so the next update reconciled against a base that no longer
matched `origin` — an avoidable re-reconciliation loop.

### Added

- **`ai-dlc-update` step 1 git preflight** (`core/skills/ai-dlc-update/SKILL.md`).
  Before the self-update or any apply, the skill checks the consumer's current
  branch and STOPs with the exact remedy on: detached HEAD; remote exists but the
  branch was never pushed (`git push -u` first); branch ahead of upstream (push
  first); branch behind (fast-forward/pull first); diverged (pull/rebase first). No
  remote configured → non-blocking note, consistent with the existing self-update
  no-remote path. Step 2 notes the push→auto-merge is safe because the preflight
  confirmed sync; step 6 re-confirms it at apply time in case the branch drifted
  since the dry-run. Detection commands (`git remote`, `git symbolic-ref -q HEAD`,
  `@{u}`, `git rev-list --left-right --count @{u}...HEAD`) verified against git
  behavior.

## [0.36.2] — 2026-07-10

Resident-path narrative strip. The LLM-consumed skill files under
`core/skills/ai-dlc/` had accreted design history, incident evidence, and
version-diff framing that a fresh lead never acts on but pays for on every
dispatch. An audit of all 28 files separated that dead rationale from
operational scar tissue and relocated it to the maintainer design record.

Rule 26(c) `Minimum mechanism` contracts (`Failure caught` / `False-positive
cost` / `Removal condition`) were deliberately **left inline** at their
machinery sites: Rule 26(c) requires the contract "at introduction", and the
retro rule-file audit flags machinery lacking it, so relocating would
manufacture that violation. Only origin/change-history and worked-proof
narrative moved. Non-behavioral (PATCH) — no gate, hook, or step contract
changed; both validators (`validate-compact-window.sh`,
`validate-enforcement-map.sh`) and every structural anchor pass unchanged.

### Changed

- **`SKILL.md`** (loads every dispatch): compact-window ordering-invariant prose
  collapsed to the invariant + validator pointer (its rationale already lived in
  `validate-compact-window.sh`'s header); removed superseded-phrasing clauses,
  `v0.24.0 Lever 2` / `pre-0.8.0` version tags, and the `graph`-consumer war-story
  citations trimmed off the Rule 27/28 26(c) lines (the contracts themselves stay).
- **`steps/gate-validation.md`** (loads every gate): the 23-line consumer-catalog
  crosswalk collapsed to a 3-line operational pointer; removed version tags, the
  Check-13 numbering aside, and the Check-22 "supersedes stale Check 15" changelog.
- **Phase B — per-phase step files and layer READMEs**: `retro.md`,
  `implementation.md`, `stories-test-strategy.md`, `architecture.md`,
  `overrides/README.md`, `extensions/README.md`, `steps/sprint-review-next.md` —
  each stripped of its remaining version tag, war story, or placement rationale.
- **`docs/context-hardening-notes.md`**: R2 extended with the compact-window
  invariant + worked 1M example; new dated **R30** section captures every
  relocated block with `moved from <file> L<n>` provenance so nothing is lost.

## [0.36.1] — 2026-07-10

The v0.36.0 sensor was a Stop hook, and Stop only fires when the model ends its
turn. The first real compaction under v0.36.0 exposed the gap: session `bd13dc14`
ran `/ai-dlc resume` → auto-compact across **169 consecutive `tool_use` messages
with zero `end_turn` boundaries**, so the sensor never sampled and context climbed
77K → 270K with no reminder. Recovery still landed cleanly (`injected_bytes: 3873`,
no degradation), but the imminent early-warning could not fire. Across `graph`, 19
of 185 red-crossing sessions have ≤2 Stop boundaries — the turn-less autonomous
runs are exactly the highest-risk ones.

### Changed

- `ai-dlc-context-sensor.sh` is now wired to **`PostToolBatch` as well as `Stop`**.
  PostToolBatch fires once per tool batch, before the next model request, so it
  samples during turn-less runs. Verified with a live headless probe that its
  `additionalContext` reaches the model mid-run. The hook echoes whichever event
  invoked it in `hookSpecificOutput.hookEventName`.
- The `PostToolBatch` tail-read is **throttled**: it runs only once the transcript
  has grown ~512KB (`AI_DLC_SENSOR_THROTTLE_BYTES`) since the last read, tracked as
  `last_read_size` in the sidecar. `Stop` is never throttled. Measured on a 2.7MB
  transcript: full read 60ms, throttled skip 27ms. The shared sidecar dedups, so
  the extra event samples often but injects only on a level change or recurrence.
  The first sample of a session (no sidecar) is never throttled.
- `templates/settings.json.template` gains a `PostToolBatch` block. It propagates to
  existing consumers automatically — `settings-merge.sh` and `install.sh` union the
  event keys, so a new event needs no migration, and the per-block strip means the
  sensor lands once on each event without duplication.

## [0.36.0] — 2026-07-10

Rule 2's yellow/red reminders had no sensor. They exist so the high-fidelity
handoff (`/clear` + `/ai-dlc resume`) gets first refusal before auto-compact
takes the lossy path, but the only authoritative trigger was the user pasting
`/context`. Across 243 real `graph` sessions that happened **twice**, while
**184 of them crossed red**. The ordering invariant was decorative.

`autoCompactWindow: 300000` reaching the consumer made this urgent: it drops the
compact trigger from 987,000 to 287,000. Historically 148 of 243 sessions
exceeded 287,000 but only one ever compacted, because the 1M default was out of
reach. Compaction moved from a once-ever event onto the hot path.

### Added

- `core/hooks/ai-dlc-context-sensor.sh` — a decision-free Stop hook that measures
  resident context every turn and fires the Rule 2(b)/(c) reminder itself. It
  reads the last main-thread assistant `usage` from the transcript and sums
  `input_tokens + cache_creation_input_tokens + cache_read_input_tokens`, which is
  Claude Code's own figure (equal to `compactMetadata.preTokens`). Verified
  against a real 6.5MB transcript: 248,721 measured vs 248,721 actual, in 59ms.
  Hook stdin carries no token counts, but it carries `transcript_path`.
- An `imminent` level, ranked above red, opening a critical band 20,000 tokens
  below the sensor-visible ceiling (`effectiveWindow - 31,000`). Claude Code
  compacts at `effectiveWindow - 13,000`, but the measured quantity sits a further
  ~18,000 below that at fire time (287,000−268,892 = 18,108; 987,000−969,084 =
  17,916). The band does **not** open at the ceiling: a warning there arrives too
  late to act on, since compaction fires on the very next model request and takes
  the directive with it. And the ceiling is usually never observed at all — the
  four real auto-compactions on `graph` last measured 268,892 / 267,719 / 267,445 /
  267,023 against a 269,000 ceiling. At ~1,200 tok/turn the lead buys ~16 turns.

  In the band the hook directs the lead to **refresh `pipeline-snapshot.md` before
  its next pipeline action**. The snapshot is what `ai-dlc-recover.sh` re-reads
  after compaction, and on `graph` its write cadence has a p90 gap of 12.9h against
  compactions ~1–4h apart — so a stale snapshot gets recovered faithfully and is
  still wrong. `imminent` is its own level rather than a red variant so that
  entering the band always fires on first crossing, instead of waiting on red's
  50,000-token / 20-turn recurrence delta. Suppressed while the row is only assumed.
- `core/fixtures/context-sensor/` — 9 synthetic transcripts and a 19-assertion
  runner covering silence cases, idempotence, escalation, the self-healing reset
  after compaction, sidechain filtering, the tail-read escalation ladder, model-row
  inference, and recurrence.
- SKILL.md now **defines** the Rule 2(b)/2(c) reminder text. It was referenced from
  three files and defined in none.

### Changed

- The reminders are non-blocking, as before. What changed is that they fire.
  The Stop result loop collects each hook's `additionalContext` independently of
  whether a sibling sets `preventContinuation`, so the reminder reaches the model
  even on turns `ai-dlc-continue.sh` blocks — nearly all of them, autonomously.
- Fire state and recurrence (50K-token / 20-turn) move from the lead-written
  snapshot to the hook-owned `_bmad-output/.context-sensor-state`. Gates ran a
  handful of times against a p50 of 242 assistant turns — far too coarse to dedupe
  a per-turn sensor. Check 14 now reconciles the snapshot from the sidecar.
- `ai-dlc-recover.sh` clears the sidecar on `SessionStart(compact)`. The sensor also
  self-heals: a >50,000-token drop means compaction or `/clear`, and resets to `none`.
- Auto-handoff's `deploy-only` precondition reads `last_level` from the sidecar
  instead of "red confirmed under Mode 1". The guarantee is strengthened — every
  advance is now a direct measurement rather than a human paste.
- `scripts/install.sh` fixture loop gained `context-sensor` and now chmods `run.sh`.
  The hook itself needs no installer change (hooks are copied by glob), and the
  `ai-dlc-[^/]+\.sh` regex upserts it into existing consumers.
- `scripts/install.sh` no longer carries its own copy of the settings.json jq. It
  delegates to `reconcile/settings-merge.sh`, so an installed consumer and a
  reconciled consumer provably apply the same contract instead of drifting apart.
- `install.sh` now chmods `reconcile/*.sh` as a glob. It named `preclassify.sh`
  explicitly; `layer-drift.sh` was executable only because `cp` happens to preserve
  the source mode.

### Added (consumer pull path)

- `core/skills/ai-dlc-update/reconcile/settings-merge.sh` — the settings.json
  reconcile as a script rather than prose an agent retypes as jq. Strips ai-dlc hook
  blocks per-block (never per-event: `SessionStart` is shared with context-mode and
  caveman), re-appends the template's, preserves permissions/env/mcpServers/statusLine,
  and provisions `env.AI_DLC_MODEL_ROW` when — and only when — that key is absent and
  the template wires the sensor. `--check` reports `model_row_needed=yes|no` and the
  exact question to ask, writing nothing; `--model-row` carries the operator's answer.
  Refuses to write on invalid input or invalid output JSON, leaving the file untouched.
  `ai-dlc-update` step 5 runs `--check` to build the dry-run question; step 7 applies.

### Removed

- **Mode 2, the fallback estimator** (`15,000 + turns*2,000 + tool_bytes*0.25`).
  Measured against ground truth it was wrong in both terms — the real resident floor
  is ~69,000, not 15,000, and real growth is ~1,200 tokens/turn, not 2,000. It
  overestimated by 69% at the median (p90 +134%) yet was **silent at the true yellow
  crossing in 108 of 219 sessions**. With a real sensor it had no caller, and a guess
  beside an authoritative number only invites guessing. `/context` survives as
  optional manual confirmation.

### Notes

- The transcript records `claude-opus-4-8` for both the 200K and 1M variants, and no
  window size appears anywhere in it, so the model row cannot be read off the
  transcript. The errors are asymmetric: assuming 200K on a 1M model fires reminders
  early (noisy, non-blocking); assuming 1M on a 200K model puts red at 200,000 above
  a compact threshold of 187,000, so red would never fire first. The sensor therefore
  assumes 200K and upgrades only on proof (a reading ≥ 187,000 is impossible on a 200K
  model), caching it in `_bmad-output/.context-sensor-model`.

  `AI_DLC_MODEL_ROW` pins it, read from the `env` block of `.claude/settings.json`
  (Claude Code propagates that block into hook subprocesses — verified against 2.1.206
  with a live headless probe). Both `scripts/install.sh` and the `ai-dlc-update`
  reconcile **ask the operator once**, only when the key is absent, and never overwrite
  an existing value. `AI_DLC_MODEL_ROW=1M scripts/install.sh <path>` presets it for CI
  and `curl | bash`. Answering `auto` writes nothing.

  **No default value is shipped in the template, deliberately.** Pinning `200K` sets
  `row_known=1` and disables the self-correction, so a 1M project would fire early
  reminders forever — worse than unset. Pinning `1M` on a 200K model puts red (200,000)
  above that model's compact threshold (187,000), so red would never fire before
  compaction. An absent key is the only safe default. The jq merge also never carries a
  template `env` into an existing consumer, so a shipped value would reach fresh
  installs only — which is why the installer writes it explicitly instead.
- No `statusLine` is shipped. Its stdin does carry official context numbers, but its
  stdout is display-only and never reaches the model, it occupies a single global slot
  users fill with their own tool, the installer's jq merge does not manage that key,
  and it does not run headless where the session driver operates.

## [0.35.3] — 2026-07-10

The recovery hook never worked. Found by reviewing three real auto-compactions on
the live `graph` consumer — the first time the machinery ran outside a fixture.

**Claude Code persists any hook `additionalContext` of >= 10,000 characters to a
file and replaces it in context with a 2,000-character preview stub.** Measured
across every transcript on the machine: 4,385 inline blocks, largest 9,983 chars;
everything above was stubbed. `ai-dlc-recover.sh` emitted **31,881** characters,
so on all three compactions the snapshot was NEVER injected. Only the leading
2,000 characters survived, and only by luck of ordering — the directive happened
to be at the top. The design's central claim ("the snapshot is placed back into
context by the harness, unconditionally") was false as shipped.

Worse, the log said otherwise. `ai-dlc-postcompact.sh` reported
`recovery_injected: yes` on all three because it only checked for the marker file
`ai-dlc-recover.sh` writes unconditionally. Actual behaviour: compaction #1 read
the snapshot of its own accord and recovered fully; #2 skipped the snapshot; #3
emitted no acknowledgement, no verification turn, and no snapshot read at all.

- **`ai-dlc-recover.sh` inverted.** It no longer inlines the snapshot. It emits a
  ~3.7 KB directive whose FIRST instruction is `Read _bmad-output/pipeline-snapshot.md`
  in full, plus a bounded `Pipeline Position` excerpt for orientation. This is the
  better design regardless of the cliff: the snapshot is a verbatim-load file
  (`ai-dlc-protect.sh` exists to stop it being consolidated) and a `Read` is the
  Rule 21 attention interrupt. Emitted size is now invariant to snapshot size —
  3,679 chars against a 32 KB snapshot and against a 232 KB one. The block is
  measured and trimmed (Position excerpt drops first) before emission, because an
  over-limit block is not truncated by the harness, it is replaced wholesale.
  Ceiling configurable via `AI_DLC_HOOK_CONTEXT_LIMIT` / `_MARGIN`.
- **The log tells the truth.** `recover.sh` records `injected_bytes` and
  `degraded` in its marker; `postcompact` reports `recovery_injected: yes |
  degraded-persisted | no` plus `injected_bytes`. `degraded` tests against the
  real 10,000 cliff, not the trim ceiling.
- **`session_continuity` folded in.** context-mode's own SessionStart block is
  ~11.5 KB on long sessions and hits the same cliff, so its `<session_continuity>`
  section — "captured directives are a memory aid, not a standing order" — is
  stripped from context at exactly the moment the lead reaches for auto-memory.
  `ai-dlc-recover.sh` now states it beside the `ctx_search` call it mandates.
- **`pipeline-snapshot.md` registered into the Rule 25 rails** — 6k-token
  threshold, the tightest of any artifact, because it is the most-read file in the
  pipeline (every gate, every resume, every compaction recovery). Its remedy is
  schema trimming (Rule 25(a), `Recent Activity` <= ~10 entries, history to
  `pipeline-snapshot-history.md`), never consolidation. Its unchecked growth to
  32,765 bytes on `graph` is what pushed the injection over the cliff. Rule 23(a)'s
  claim that these state files "are small" is corrected: the exemption is
  conditional, not automatic.

## [0.35.2] — 2026-07-10

Patch. `layer-drift.sh` (v0.34.0) reported only ONE anchor per override.

Found while dry-running a v0.35.0 pull against the live `graph` consumer, whose
retro override shadows eight `steps/retro.md` sections. Three of them changed
upstream (`#4a. Close-Out Sweep`, `#5. Human Commentary`, `#7. Merge and
Next-Sprint Handoff`); the report named only `#7`. The `worst` status was always
correct — the file was flagged `OVERRIDE-DRIFT-SECTION` — but `detail` was
reassigned on every loop iteration, so the last anchor examined overwrote the
rest. An operator reconciling from that line fixes one section and silently drops
two, which is the exact failure v0.34.0 was built to end.

The mixed case was worse. When an override shadowed two changed sections *and*
one anchor that no longer resolves, the unresolvable-anchor branch ran last and
the emitted detail named **zero** drifted sections while still reporting status
`OVERRIDE-DRIFT-SECTION`.

- **`reconcile/layer-drift.sh`** now accumulates per category (drifted /
  not-locatable / not-found) and composes one line naming every affected anchor
  with a count: `3 shadowed section(s) changed <base>..<theirs>: #4a…, #5…, #7…`.
  Status precedence is unchanged. Output stays one tab-separated line per entry.

## [0.35.1] — 2026-07-10

Patch to v0.35.0, found by dry-running the new machinery against the live `graph`
consumer before updating it.

- **`ai-dlc-recover.sh` failed to name the step file on real snapshots.** The
  extractor matched only the schema spelling `current_step_file:`. `graph`'s
  snapshot — and, in practice, snapshots generally — writes the prose form
  `- **Current step file:** \`discovery.md\``. The grep missed it and the
  injection degraded to the placeholder "(named in Pipeline Position below)",
  losing the single most actionable line of the post-compact recovery block.
  `ai-dlc-continue.sh` has always tolerated both spellings; `ai-dlc-recover.sh`
  now matches its pattern, and strips the trailing prose an em-dash introduces.

## [0.35.0] — 2026-07-10

Compaction becomes a managed net. AI/DLC's dominant failure mode is token
saturation, and the rulebook answers it with context reminders plus a
high-fidelity reset (`/clear` + `/ai-dlc resume`, rehydrating from the pipeline
snapshot). Claude Code answers it with auto-compaction. The two never spoke.
Reading the installed binary (`2.1.206`) rather than the docs turned up why that
mattered:

- **The involuntary net is out of position.** Compaction fires at
  `effectiveWindow − 13000`. On a 1M model that is **987,000** tokens, while
  AI/DLC's red reminder fires at 200,000 — leaving **787,000 tokens** in which an
  operator who ignored red keeps working inside a degraded context. On 200K models
  the default (187,000 vs red 120,000) is already correct and needs no change.
- **Recovery was prose, not mechanism.** `SKILL.md`'s POST-COMPACT protocol asked
  the lead to read the snapshot first — an instruction living in the very context
  the summary may have discarded, competing for the 5,000-token skill re-attach
  budget. No `PreCompact`, `PostCompact`, or `SessionStart` hook existed anywhere.
- **The knob is a window, not a percentage.** `autoCompactWindow` is an integer in
  `[100000, 1000000]`. `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` is a test hook that can
  only lower; `CLAUDE_CODE_MAX_CONTEXT_TOKENS` is read only when compaction is
  disabled outright.
- **Three breakers bound how low you may go.** `rapid_refill_breaker` is a
  *terminal stop reason* whose own message names AI/DLC's failure mode ("a file
  being read or a tool output is likely too large… use `/clear` to start fresh").

Verified statically, and decisively: `SessionStart` fires with source `compact` on
**every** compaction path (`compact_full`, `compact_partial`, `reactive_compact`)
for both `auto` and `manual` triggers, and its `additionalContext` is injected.
Spec: `docs/v0.35.0-compaction-net-spec.md`.

- **`core/scripts/validate-compact-window.sh` (new).** Enforces the two-sided
  ordering invariant `red + MIN_SLACK < threshold < red + MAX_DRIFT` (defaults
  50,000 / 100,000) against each row of the `SKILL.md` threshold table. Scope it
  with `--row` when a project only ever runs one context size. AI/DLC does not
  write `autoCompactWindow` — the safe floor depends on the consumer's fixed
  prefix, which the skill cannot measure — it enforces and reports. Recommended
  value on 1M: `300000` (threshold 287,000; legal band 263,000–313,000).
- **`core/hooks/ai-dlc-precompact.sh` (new).** Steers the summarizer to preserve
  LOCKED_REQUIREMENTS, gate state, and open findings verbatim, and flushes a
  mechanical sidecar (`pipeline-snapshot.precompact.md`) covering the delta since
  the snapshot's last sub-step write. Echoes the incoming `custom_instructions`
  back — hook stdout *replaces* that field, so a naive hook would silently discard
  a user's `/compact <instructions>`. Never blocks: blocking a near-full context
  leaves the next stop at the API hard block.
- **`core/hooks/ai-dlc-recover.sh` (new).** `SessionStart` matcher `compact`.
  Re-injects the snapshot verbatim plus the sidecar as `additionalContext`,
  byte-capped with an explicit truncation notice. Directs a fresh `Read` of the
  current step file (compaction calls `readFileState.clear()`), the reset of stale
  context-reminder fire state, and exactly one `ctx_search(sort: "timeline")` for
  the rationale the snapshot schema cannot hold. The `SKILL.md` prose protocol is
  demoted to the fallback for when the hook is absent or truncated.
- **`core/hooks/ai-dlc-postcompact.sh` (new).** Instrumentation only —
  `PostCompact` output is display-only and cannot inject context. Writes
  `compaction-log.md`; `recovery_injected: no` on an auto trigger is the design
  failing in the field, and is now self-reporting.
- **Three latent bugs fixed.** (1) `route.md` validated five of the snapshot
  schema's six required sections (`Context Reminders` was omitted, so a snapshot
  missing it resumed). (2) Compaction resets the token counter but not
  `context_reminders_sent` / `last_*_fire_tokens`, so a recovered lead believed red
  had already fired and the auto-handoff evaluation mis-decided. (3) **Every Rule 3
  pause point was pressured across its own gate.** Rule 3 declares three pause
  points where the lead stops for a human, and `ai-dlc-continue.sh` — the hook that
  *enforces* Rule 3 — recognizes an intentional pause by exactly one signal,
  `pipeline-paused.flag`. None of the three set it; only `handoff.md:36` and
  `_gate-procedures.md:179` ever did. `SKILL.md` then guarantees the flag is absent
  by requiring the lead to clear it before routing. So each pause ended text-only
  with no flag, and the hook blocked the stop with a reason urging the lead to
  "pair the text with the tool call." At `deploy-validate.md` §6 (Wait for Human)
  the next tool call is §7 Post-Validation Routing — the hook was arguing the lead
  past the human's **production sign-off**. At `route.md` Step 0a it argued for
  dispatching to `current_step_file`, the exact action the integrity check forbids.
  Terminal stops were blocked too: nothing removes the snapshot at pipeline end
  (`route.md:301` archives only at a fresh start), so `continue.sh`'s "no snapshot"
  escape never fires. Fixed by stating the contract in Rule 3 and setting the flag
  at all seven turn-end sites. Predates this release.
- Registered per existing rails: `validate-compact-window.sh` into
  `install.sh`'s hardcoded script list and `enforcement-map.yaml`
  (`non_catalog_units`); `compaction-log.md` into the Rule 25(c) rotation and
  25(d) threshold lists in `retro.md`; the three hook events into
  `templates/settings.json.template` and the `ai-dlc-update` reconcile contract.

- **The recovery protocol did not survive its own event.** Claude Code re-attaches
  only the first ~5,000 tokens of `SKILL.md` after a compact, and `retro.md`'s
  self-check asserted the `POST-COMPACT RECOVERY PROTOCOL` *heading* fell inside
  it. Measuring the section showed it began at ~4,834 tokens and ran 566 long — so
  **~400 tokens of the protocol were discarded by compaction**, specifically the
  verification-turn requirements and the re-attach-budget fallback. The heading
  survived; the instructions did not. Fixed by a pure reorder (no content change):
  the second-tier half of the Handoff Protocol — handoff triggers, pending
  approvals, threshold defaults, reminder semantics, auto-handoff, and the new
  ordering invariant — moved into `## HANDOFF PROTOCOL -- TRIGGERS AND CONTEXT
  THRESHOLDS` below the protocol, while `Living pipeline snapshot` and `No
  self-scheduling skill re-entry` stay above it. The protocol now spans
  ~3,872–4,439 tokens, entirely inside the fold, with 561 tokens of slack (was
  166). The section retains the `Handoff Protocol` name so the eight step-file
  pointers of the form `SKILL.md` Handoff Protocol `"<subsection>"` keep resolving.
  `retro.md`'s self-check now also checks the protocol's *body*, not just its
  heading.

**Migration.** Adding `Context Reminders` to the `route.md` integrity check FAILs
a resume against snapshots written before that section became universal. The
failure surfaces the existing `archive` / `edit` / `abort` prompt rather than
proceeding silently. Land between sprints, not mid-sprint.

**Note.** `strip_ai_dlc` is per-block, never per-event. `SessionStart` is the first
event key AI/DLC shares with tools outside it (context-mode, caveman); stripping
the whole event would delete a consumer's own hooks.

## [0.34.0] — 2026-07-09

Rule 27 gets teeth. A full sweep of the high-volume consumer's 12 overrides and
29 extensions found that the layered rulebook's **drift detection was never
implemented** — it was prose in `ai-dlc-update/SKILL.md` instructing an agent to
run `git diff` once per override. `reconcile/preclassify.sh` contained zero
references to `extensions`, `overrides`, `base_sha`, `shadows`, or `hooks`.
Consequences, all silent and all found live:

- **5 of 12 overrides carried a `base_sha` pointing at the CONSUMER's own repo**
  (three were literally its `chore(ai-dlc-update): reconcile …` merge commits).
  `git diff <base_sha>..theirs` inside the distribution dies on
  `fatal: bad revision`, and nothing defined what to do then.
- A 29 KB override shadowing 8 retro sections silently **discarded two shipped
  upstream changes** — v0.33.0's `docs/architecture.md` size threshold and
  v0.33.2's gate-log rotation routing. That consumer will never warn on
  architecture-doc size, and no mechanism could have said so.
- **Absorption had no retirement step.** `discovery-domain.md` was absorbed
  upstream at v0.11.0 (`e7ccffa`) and never deleted; 22 releases later it both
  duplicates *and* contradicts the core §1a it became.
- Extensions carry `hooks:` only — a file-grain anchor, no `base_sha`, no section
  id — so nothing could detect core changing underneath one.

Spec: `docs/v0.34.0-layer-drift-enforcement-spec.md`.

- **`reconcile/layer-drift.sh` (new, pull-time).** Mechanizes the layered
  reconcile. Emits `HARD-OVERRIDE-BASE-CONSUMER-SHA` /
  `HARD-OVERRIDE-BASE-UNRESOLVABLE` (both **block `apply`** — an unusable base
  makes drift *undecidable*, and is never read as "unchanged"),
  `OVERRIDE-DRIFT-SECTION`, `OVERRIDE-DRIFT-FILE` (anchor not a locatable heading
  and the file changed → cannot *prove* the section safe, so surface it),
  `OVERRIDE-ANCHOR-UNRESOLVED`, `EXTENSION-HOOK-DRIFT`, and
  `EXTENSION-RETIRE-CANDIDATE` — the absorption-retirement signal that closes the
  loop. Retirement matching requires the section **titles** to agree, not merely
  the number: consumer gate-check numbers are a sanctioned separate namespace per
  core's Consumer-catalog crosswalk, so number-only matching false-positives.
  Wired as step 3c; feeds three new dry-run report sections.
- **`core/scripts/validate-layer-entries.sh` (new, authoring-time).** Runs entirely
  consumer-side, no distribution checkout, on this property (verified 9/9 on real
  data): **a correct `base_sha` never resolves in the consumer's own repo.**
  Severity is tiered on purpose — ERROR only for mechanized invariants with no
  false-positive path (poisoned `base_sha`, broken `hooks:`/`shadows:` target,
  missing frontmatter); WARN for smells needing judgement (an extension restating a
  core section, a restriction filed in the additive layer, a dangling `Step <n>`
  pointer resolved globally so cross-file references don't false-positive). A
  linter that errors 78 times on first contact gets disabled, and then catches
  nothing. Wired into `rule-authoring.md` and the retro Close-Out Sweep.
- **Rule 27 (a)/(b)/(c) (`SKILL.md`).** `base_sha` provenance is normative;
  retirement on absorption is a consumer duty; additive means additive — a
  restriction is an override wearing extension frontmatter. Both layer READMEs
  carry the traps and the rule of thumb.
- `install.sh` ships the new validator (`core/scripts/`, per the v0.33.1 trap).

**CONSUMER ACTION (layered consumers).** Run
`scripts/validate-layer-entries.sh` after updating. Every ERROR is an entry whose
drift detection is currently dead — re-stamp its `base_sha` to the correct
distribution sha before the next `/ai-dlc-update apply`, which will otherwise
block on it.

## [0.33.2] — 2026-07-09

Absorb a consumer push-candidate: gate-log is not a consolidation target, and the
retro audit must stop routing it to one. Surfaced when v0.33.0 added
`architecture.md` as a consolidation target and a consumer extension
(`artifact-consolidation-push.md`, flagged `push_candidate: true`) contradicted
core by asserting a **closed allowlist** of valid targets. Interrogating it found
a real upstream incoherence the extension was patching locally.

- **`steps/artifact-consolidation.md` — declare the gate-log exclusion.**
  Append-only logs are bounded by *rotation* (Rule 25(c)), not consolidation: a
  live log never accretes the per-sprint narrative and superseded versions this
  step collapses. Stated deliberately as an **exclusion, not a closed allowlist**
  — adding a fifth living artifact must not require editing that paragraph, which
  is exactly the staleness that made the consumer extension contradict core.
- **`steps/retro.md` — route the size-audit remedy by bounding mechanism.** The
  Rule 25(d) audit measures live `gate-log.md` at 25k and, on breach, recommended
  `artifact-consolidation.md` — a step that (since v0.33.0) enumerates targets not
  including it. The audit now recommends **rotation** for append-only logs and
  consolidation only for living planning artifacts. A live log over threshold
  means a rotation was missed, not that it needs a fidelity-critical rewrite.
- Cites Rule 25(c) only. The consumer extension's `retro.md` "Step 5e" anchor is
  consumer-local and does not exist upstream — carrying it over would have shipped
  a dangling pointer of exactly the kind the retro relocation-pointer scan hunts.

Consumers carrying `extensions/steps-domain/artifact-consolidation-push.md` should
**retire it** after pulling this release — its content is now upstream, and its
closed-allowlist phrasing is the defect.

## [0.33.1] — 2026-07-09

Fix v0.33.0's delivery gap: `gen-architecture-index.js` never reached consumers.

- **Ship `gen-architecture-index.js` (`core/scripts/`, `install.sh`).** v0.33.0
  wrote the generator to the distribution's ROOT `scripts/` — maintainer-only
  tooling (`install.sh`, `check-version.sh`, `audit-machinery-efficacy.js`), which
  is never distributed. Only `core/scripts/<x>` maps to a consumer's
  `scripts/<x>` (via `install.sh`'s copy loop and `ai-dlc-update`'s path mapping),
  so a consumer following the v0.33.0 migration block hit "script doesn't exist"
  at step 2. Moved to `core/scripts/gen-architecture-index.js`, marked executable,
  and registered in `install.sh`'s copy list. Consumer-facing references in
  `steps/architecture.md` §4a, `steps/artifact-consolidation.md`, and the
  migration block were already correct (`scripts/gen-architecture-index.js`) and
  are unchanged. Next `ai-dlc-update` pull delivers it as a pure
  `UPSTREAM-ONLY-ADD`.

## [0.33.0] — 2026-07-08

Architecture-doc size discipline — close the one gap in Rule 25's living-artifact
rails. In the high-volume consumer, `docs/architecture.md` reached
21,018 lines / ~506K tokens (~2.5× a 200K window) because the architecture step
appended a per-sprint "Architecture Addendum" every cycle and never rotated
history — 124 dated addenda, ~99% of the file. Meanwhile the **dev** role
contract directs every spawned dev agent, before every task, to read that doc;
qa, architect, and the implementation lead whole-read it too. So one ~506K-token
file was loaded uncached on nearly every dispatch — the single largest read cost
in the pipeline. Root cause: `architecture.md` was the sole living artifact
absent from all four Rule 25 rails (the 25(a) history mapping, the retro
artifact-size audit, `artifact-consolidation.md`, and the 25(b) slice-read
contracts) — every *other* big artifact (prd/brief/backlog/gate-log) already has
them. No enforcement removed; this registers architecture into existing machinery
(Rule 26(b) extend-proven-paths) and adds one deterministic script. Direct
descendant of the v0.9.0 artifact-size arc. Spec:
`docs/v0.33.0-architecture-size-discipline-spec.md`.

- **Read-side — slice, never whole-read (`team-roles/dev.md`, `qa.md`,
  `architect.md`, `code-reviewer.md`; `steps/implementation.md`,
  `sprint-review-next.md`).** The six contracts that said "read the architecture
  document" now invoke Rule 25(b): read the current-state head plus only the
  section(s) named in the story's `architecture_refs`, never the whole file.
  Fallbacks degrade gracefully: `docs/architecture-index.md`, then `grep '^## '`.
  Ships immediately, zero consumer migration.
- **Per-story `architecture_refs` (`steps/stories-test-strategy.md` §2b).** New
  story-frontmatter field naming the architecture section anchors a story touches,
  propagated at authoring time (next to Rule 13 `LOCKED_REQUIREMENTS`
  propagation) where the design is fresh. This is the slice target dev/qa read
  instead of whole-reading. `architecture_refs: []` is an explicit "no
  architecture context needed" signal.
- **Generated index (`scripts/gen-architecture-index.js`, `steps/architecture.md`
  §4a).** Deterministic H2 index (heading → anchor → line → one-line summary),
  regenerated on every architecture-step update — no LLM whole-read. Measured on
  the consumer's 21K-line doc: 243 lines / ~13K tokens, ~38× cheaper than the
  ~506K whole-read. `--h3` for finer navigation.
- **History rotation (`SKILL.md` Rule 25(a); `steps/architecture.md` §2).**
  `architecture.md` → `architecture-history.md` added to the 25(a) mapping; the
  architecture step now folds net change into current-state and moves superseded
  content + dated addenda verbatim to the history companion (no-loss) instead of
  appending forever.
- **Size audit + consolidation coverage (`steps/retro.md`;
  `steps/artifact-consolidation.md`).** `docs/architecture.md` added to the retro
  Rule 25(d) artifact-size audit (60k-token default, warn-only) and to the
  one-shot consolidation step (manifest = every heading + ADR; validate +
  regenerate index; relocate history verbatim). Consumers run consolidation once
  to collapse the existing 124 addenda — ~506K → consolidated head, zero loss.

**CONSUMER MIGRATION (required on update).** The read-side slice contracts and
history rotation ship active immediately and are non-breaking, but a consumer
whose `docs/architecture.md` already accreted per-sprint addenda before this
release still carries the whole-read cost until its live doc is consolidated.
After updating to 0.33.0, run the one-shot consolidation **once**, at a quiescent
point (between sprints):

1. Invoke the operator-run `artifact-consolidation.md` step naming
   `docs/architecture.md` as the target (it is fidelity-critical and supervised —
   never automatic, per Rule 25(d)). It builds a no-loss manifest, splits
   current-state (live) from history, verifies `live ∪ history ⊇ baseline`, and
   commits the swap, relocating every dated addendum verbatim to
   `docs/architecture-history.md`.
2. Regenerate the index: `node scripts/gen-architecture-index.js`
   (writes `docs/architecture-index.md`).
3. Backfill `architecture_refs` on in-flight stories as they are next touched;
   older stories fall back to the index/`grep` path until then.

The retro artifact-size audit will warn (60k-token default) on every retro until
this consolidation runs, pointing at the same step. Skipping migration is safe —
slicing still works via the index/`grep` fallback — it just leaves the doc large.

## [0.32.0] — 2026-07-08

Retro workflow optimization — four structural levers that cut the per-sprint
retro's wall-clock and commit tail without removing any enforcement or trimming
any rule prose. Rooted in an audit of the high-volume consumer, where a single
retro ran ~1–2 h with a ~10-commit tail. Settled scar tissue was deliberately
left untouched: party-mode's 6 real subagents + byte-matched transcript (v0.29),
the per-phase-vs-one-batch analyst-dispatch decision (v0.26 §2), and live
deferral re-verification. Spec: `docs/v0.32.0-retro-workflow-optimization-spec.md`.

- **Shift-left the transcript/provenance contract (`steps/retro.md` Step 2).**
  The Step-5c validators (`validate-retro-evidence.sh` shape floor +
  `validate-provenance-block.sh` HTML-comment format) were discovered only at
  the gate, so the transcript was patched afterward — and every transcript edit
  re-invalidated the cited blob SHA, forcing a re-cite + reformat loop (observed
  as 4 commits/sprint). Step 2 now states the floor (pointing at the script as
  the single source of the thresholds, not restating them) and prescribes a
  commit-once order: shape transcript → commit it alone → capture blob SHA →
  write provenance once → never re-touch the transcript. The gate is unchanged;
  only *when the requirements are known* moved earlier.
- **Retired the `research-citations.md` phantom pointer** from `steps/retro.md`
  (Invariant-1 example list) and `SKILL.md`. The file never existed, so the
  every-retro relocation-pointer scan failed on a dangling reference, forcing
  consumers to carry local overrides to mask it. Consumers drop those overrides
  on next `/ai-dlc-update`.
- **Consolidated Step 4's two co-temporal analyst dispatches into one spawn**
  (`steps/retro.md`). The rule-file audit and the dormancy + pointer-invariant-1
  scans fire at the identical post-improvement point; they now share a single
  `analyst` dispatch instead of two serial round-trips. Not a reopening of
  v0.26 §2 (which rejected one up-front gather for the *whole* retro) — these are
  same-phase, same causal point.
- **Corrected the Step-5c prose** (`steps/retro.md`): `validate-mandatory-rules.sh`
  chains retro-evidence + cycle-commits + **retro-prereq** (+ inline Checks 3/5/6),
  not `validate-provenance-block.sh` as previously documented. The local+CI
  re-run of the validators is intentional defense-in-depth (CI catches a
  locally-skipped gate), left in place.

## [0.31.0] — 2026-07-08

Enforcement crosswalk — a validated machine index of the gate-validation check
catalog to its enforcement binding. Outcome of a prose-vs-schema evaluation: the
rulebook prose stays prose (LLM-consumed verbatim, rationale fused into the
directive per `rule-authoring.md`; schema would add token cost and strip the
scar tissue without helping the reworded-prose merge path). Only the genuine
machine-consumed data is extracted — the enforcer bindings that were scattered
across `SKILL.md`, `gate-validation.md`, `core/scripts/`, and `core/ci-templates/`
with no single queryable artifact (the gap the v0.27.0 machinery-efficacy audit
flagged as UNMAPPED).

- **New `core/skills/ai-dlc/enforcement-map.yaml`.** Per catalog check:
  `gate_types`, `adjudication` (script | project | llm), `enforcer` scripts,
  `ci_workflow`, and adversarial `fixtures`. Plus `non_catalog_units` (the Rule 18
  retro-compliance suite, the CI-gate dormancy detector). It is a DERIVED view —
  `gate-validation.md` remains the sole source of truth for check semantics — and
  carries no independent authority. Surfaces the honest finding as data: **1 of 29
  catalog checks (Check 17) is script-adjudicated; the rest are LLM/project-
  adjudicated.** Upstream maintainer data, co-located with the catalog it indexes;
  NOT shipped to consumers (like `audit-machinery-efficacy.js`).
- **New `scripts/validate-enforcement-map.sh`.** Portable bash (no jq/yq), exit
  0/1/2. Keeps the map honest against the catalog: catalog⊆map and map⊆catalog
  (anchor set vs `checks:`), GATE_MANIFEST gate-type sync, no dormant binding
  (every enforcer/ci_workflow path exists; every fixture exists), and — a
  pre-existing hazard both files flag — the two hand-synced `core_manifest` copies
  (`core-manifest.md` and `reconcile/setup-sites.md`) list the same logical set.
  Each invariant has a demonstrated RED (perturb → fail → restore).
- **`scripts/audit-machinery-efficacy.js`** reads the map and adds an `enf` column
  + a script-vs-LLM adjudication summary to the distribution-catalog report.
- **Deliberately NOT migrated** (evidence, not oversight): the `ai-dlc-update`
  reconcile manifests (`setup-sites.md`, `template-sites.md`, `core-manifest.md`)
  and the Rule 8 intensity table. On inspection these are already fenced YAML /
  tables wrapped in load-bearing LLM contract prose (anchor-drift STOP semantics,
  mask-only-the-captured-span) consumed by the reconcile agent, not by
  `preclassify.sh`. Lifting them into standalone schema is a no-op that would
  *create* the drift it claims to remove — the plan's own thesis one level deeper.

## [0.30.0] — 2026-07-08

New `adversary` team-role — completes v0.29.0's validation-sub-skill spawn binding
with a purpose-built role instead of the provisional (ill-fitting) mapping.

- **New `core/team-roles/adversary.md`.** Independent critical evaluator of a
  planning artifact: no ownership stake, the dispatched sub-skill drives the
  method, the role supplies independence + model (**opus-tier**, high effort,
  Agent-spawned per Rule 19 — architect-altitude: deep open-ended reasoning about
  plan soundness, where a missed planning flaw compounds downstream). Writes
  `mode: subagent` provenance + findings to a canonical path, returns only the path.
- **SKILL.md Rule 20 shape (ii) rebound** — all three single-voice sub-skills
  (`advanced-elicitation`, `review-adversarial-general`, `validate-prd`) dispatch
  to `adversary` (one constant role; the sub-skill selects the method). Replaces
  the v0.29.0 provisional `code-reviewer`/`analyst`/`pm` mapping, which fit
  poorly: `code-reviewer` is diff-scoped, `analyst` is read-only non-adversarial,
  `pm` reviewing the PRD is the owner reviewing its own domain.
- **`ai-dlc-setup` model-tier guide** registers `{adversary_model_*}`
  (opus-tier). Manifest/install/update wiring is glob-based (`team-roles/*.md`),
  so the new role propagates with no enumerated-list edits.

## [0.29.0] — 2026-07-08

Validation sub-skills must run in independent subagents — no solo. Closes a rule
inconsistency caught live in graph S286: the lead ran `bmad-review-adversarial-
general` and `bmad-validate-prd` `mode: solo` (a single LLM reviewing an artifact
its own conversation authored) and correctly cited Rule 20 to justify it — Rule 20
only forbade solo for party-mode, while Rule 28 falsely assumed all validation
sub-skills spawn. **Behavior change: a previously-passing solo run now FAILs
Check 17.**

- **SKILL.md Rule 20 reframed** from "run inline" to "run in independent
  subagents." Two shapes, both `mode: subagent`: party-mode spawns personas
  internally (unchanged); the three single-voice sub-skills (advanced-elicitation,
  review-adversarial-general, validate-prd) are now **dispatched to a Rule-19-bound
  teammate** (analyst / code-reviewer / pm) — reversing the old "do NOT route
  through Agent" mandate, which made inline invocation solo by construction. Solo
  is forbidden for all four.
- **SKILL.md Rule 28** premise corrected — validation evaluation genuinely runs in
  subagents; a solo run is both a Rule 20 and Rule 28 violation.
- **`scripts/validate-provenance-block.sh`** rejects `mode: solo` on any tracked
  sub-skill (core-owned, so the teeth reach consumers even where Check 17 is
  overridden). Verified: solo → exit 1, subagent → exit 0.
- **`gate-validation.md` Check 17** lists `mode: solo` as a FAIL condition for all
  four.

Migration (see `docs/v0.29.0-validation-subskill-spawn-spec.md`): reinstalling
into a consumer with in-flight `mode: solo` artifacts (graph S286:
`discovery-adversarial-s286.md`, `prd.md`) will FAIL them at the next gate —
merge after the current sprint closes, or re-run those passes as subagent
dispatches.

## [0.28.1] — 2026-07-08

Gate-metrics emission tightened from its first live emission (graph consumer
Sprint S286 carry-over gate). Two fidelity fixes to the v0.28.0 `GATE_METRIC v1`
clause; additive/refinement, no new capability.

- **Emit validation checks only.** The procedural gate-mechanics checks 12–15
  (log-append / announce / snapshot / verify-snapshot) are bookkeeping, never
  defect-catchers, so they are explicitly excluded — codifying what the lead
  already did at S286 and removing the "every check" ambiguity. All other
  manifest-loaded checks are emitted, `NA` included (an `NA` exposure is signal).
- **`tok_slice` is now required** (was optional; S286 emitted it `null`
  throughout). Without the per-check token cost, cost-vs-catch — the point of the
  metric — is not computable. `scripts/audit-machinery-efficacy.js` now prints a
  `tok/gate` and `tok÷catch` column (`∞` at zero catches = the dormancy signal)
  and warns on any record missing `tok_slice`.

## [0.28.0] — 2026-07-07

Gate-metrics emission — the forward-looking half of the v0.27.0 audit. That audit
found "which checks earn their token cost" un-answerable because fire-history is
prose (gate-log verdicts are PASS-dominated; catches hide in `**Remediations:**`
footers) and confounded across the consumer's separate `extensions/checks/`
catalog. This makes every future gate emit a structured, machine-readable,
**catalog-namespaced** outcome record so consumer history yields decisive
efficacy/cost data. Additive (new gate output); existing consumers keep working —
absence of the file just means audit tooling uses the prose fallback.

- **`gate-validation.md` Check 12 — new `GATE_METRIC v1` emission clause.** After
  the prose gate-log entry, append one JSONL line per check to
  `_bmad-output/implementation-artifacts/gate-metrics.jsonl` (append-only,
  machine-read only, rotates with the gate-log epoch). Same per-check verdict data
  the prose entry already carries — near-free. Each record namespaces the check by
  `catalog` (`core` vs `extension:<id>`), so a consumer's redefined/added check
  numbers are never conflated with this catalog's (the exact confound the v0.27.0
  crosswalk note warned about). Fields: verdict (machine-countable), defect_class
  (catch taxonomy), evidence pointer, optional tok_slice (cost side of efficacy).
- **`scripts/audit-machinery-efficacy.js` — prefers the JSONL when present.**
  Emits a decisive per-`(catalog, check)` exposures / real-FAILs / defect-class
  table from `gate-metrics*.jsonl`, falling back to the prose-derived signals for
  pre-v0.28.0 sprints. Verified against both a no-file consumer (fallback) and a
  sample record set (namespaced aggregation).
- **New `docs/v0.28.0-gate-metrics-emission-spec.md`** — schema, emission point,
  reader, and how it makes dormancy/efficacy decisive. Dashboard wiring
  (context-mode `ctx_insight`) left as an optional follow-on (KISS).

## [0.27.0] — 2026-07-07

Machinery-efficacy audit — an end-to-end optimization review that applied the
v0.10.0 "0 true catches → hold" methodology to the whole gate-check catalog +
non-check machinery, against a real consumer's 285-sprint fire history. The
review's honest finding: the structural token levers are largely exhausted
(v0.12.0 resident-slimming, v0.24.0 gate-slicing, v0.25/0.26 delegation) and the
gate catalog carries almost no dormant weight. Investigation overturned every
naive pruning candidate — the two biggest "dormant" flags were live under drifted
consumer names, and the strongest "backport" candidate is a consumer domain check
explicitly marked `push_candidate: false`. Deliverable is the reusable audit tool
+ a crosswalk-hygiene note, not a pruning PR. Additive/doc only; no rule, gate
check, or hook contract changed.

- **New maintainer tool `scripts/audit-machinery-efficacy.js`.** Computes, per
  gate check, a title-aligned distribution↔consumer crosswalk + per-check token
  cost (real tiktoken under `bun`, chars/4 fallback) + fire-frequency signals
  (escalation-archive + retro-corpus `Check N` refs; gate-log verdicts are
  PASS-dominated and NOT a dormancy signal). Repeatable against any consumer via
  `--graph <path>`.
- **`gate-validation.md` — new "Consumer-catalog crosswalk" note.** Records that a
  consumer's `extensions/checks/` catalog is its OWN number namespace (may
  redefine shared numbers, adds checks past this range), so consumer `Check N`
  fire-history MUST NOT be attributed to a distribution check by number, and a
  `push_candidate: false` extension MUST NOT be backported. Prevents the
  false-crosswalk that this very audit first fell into.
- **`retro.md` — path-filter dormancy scan gains a script-based-consumer N/A
  clause.** A consumer with no `.github/workflows/` (validators run via
  `validate-*.sh` directly) records the scan N/A instead of scanning an empty
  target — the workflow-CI layer is optional, not dormant, in such consumers.
- **New `docs/v0.27.0-machinery-efficacy-audit.md`.** Full method, caveats, the
  28-check efficacy table, and the decisive correction (the consumer runs a
  separate opted-out domain catalog). Deferred (author-judgment, no sound consumer
  evidence): a Check-19 clause split and a Check-11a scope review.

## [0.26.0] — 2026-07-07

Retro inline-delegation (#60) — the third and final lever of the
delegation-closeout arc ([[v0.8.0]] Rule 24 → Rule 28 → v0.25.0). Closes the
one step v0.25.0 deferred: `retro.md`, the largest read-heavy step (740 lines)
and the lead's single biggest inline-read site. Unlike the v0.25.0 targets,
retro's delegable reads do NOT factor behind one prepended §0 — they interleave
with lead-owned decisions, are causally ordered, and sit next to a live
provenance/evidence chain. Design spec, not mechanical. No new rule, no new
gate check, no new script, no detector — enforcement rides the existing retro
audits (Rule 26(c)). Text-only; takes effect on the next `/ai-dlc` retro.

- **Per-phase micro-dispatches, not one §0.** Six read-heavy retro sites each
  open with a scoped `analyst` dispatch (Rule 19 binding byte-identical to
  discovery / carry-over §0) that writes a structured table to a canonical
  `_bmad-output/retro-artifacts/sprint-<N>-*.md` artifact and returns only
  `{artifact_path, summary, gaps}`; the lead resumes in-place for disposition,
  authoring, and mutation. Two dispatch clusters split by the merge seam —
  **Dispatch A** (Step 1 context digest, Step 3 doc split, Step 4 rule-audit
  candidates + dormancy/pointer scans, Step 4a close-out gather) and
  **Dispatch B** (Step 7b next-sprint inputs, issued after the 7a human merge
  gate).
- **Causal ordering preserved.** Branch creation stays inline (git mutation,
  Rule 28(a)/23(c)) with Dispatch A issued after the branch exists; the Step 4
  rule-audit dispatch fires only after "apply process improvements" edits land
  so the scan sees post-improvement state; Dispatch B fires only after the 7a
  merge gate. Descriptive/analytical sections are analyst-drafted; prescriptive
  sections (improvements, which-file-updates, 5-layer enforcement) stay
  lead-authored inline.
- **Evidence-chain invariants held (the acceptance contract).** Step 2
  party-mode transport is byte-unchanged — no analyst produces or re-commits
  the transcript; the analyst never emits `SKILL_INVOCATION_PROVENANCE`; the
  Agent-findings summary cites the existing `transcript_path: path@<sha>`
  verbatim and never re-derives (else solo-mode-by-proxy, Rule 20); topology +
  TRIGGER `file:line` citations survive the hop and the lead validates before
  disposition; deferral conditions are run LIVE against real source, never
  inferred. Locked-requirement deferral disposition is never delegated
  (Rule 13 / Rule 12 Tier-1 HARD_BLOCK, lead-only). Invariants 2 & 3 stay as
  compact `node -e` one-liners run via `ctx_execute`, not wrapped in a dispatch.
- **Config — reuse `planning_offload`, no new flag.** Rule 24's heading and
  description widen from planning-only to "read-heavy exploration in planning
  **and retro** steps"; `retro` joins the split-offload list. When `off`, retro
  runs fully inline (pre-0.26.0 behavior).
- **Self-audited, no new machinery.** The Step 4 rule-file audit scope note
  gains one line asserting retro's own read-heavy sections (Steps 1, 3, 4, 4a,
  7b) carry their analyst dispatch — a structural invariant checked by the audit
  that already runs every retro (the retro audits itself), not a new detector.

> **Live-retro acceptance is NOT yet exercised.** §7.3 requires one full live
> retro to confirm the five §4 invariants hold, `validate-retro-evidence.sh` +
> `validate-retro-compliance.yml` pass green, the `transcript@sha` byte-match is
> intact, and resident context measurably drops. That runs on the next live
> retro, not at merge.

## [0.25.0] — 2026-07-07

Lead-inline delegation closeout (#59). Rule 28 already mandates that inline
lead execution is the exception; this closes the gap between the rule and the
step-file procedures that predate it. No new rule, no gate check, no detector —
enforcement rides the existing retro audits (Rule 26(c)). Text-only edits to
core step files + one SKILL.md reconciliation; takes effect on the next
`/ai-dlc` invocation.

- **Lever 2 — fix-directly purge.** Four procedures carried a bare
  `fix directly` / `Apply fixes` / `Apply all improvements` / `update it
  directly` imperative that put the lead's own hands on source or story files.
  Requalified each to name the dispatch target while keeping the orchestration
  verbs (redeploy, re-validate, re-present checkpoint, mark `skipped`) on the
  lead: `deploy-validate.md` §4 drift (dev corrects, lead redeploys/re-verifies)
  and §7 post-validation fixes (dev + code-reviewer + qa, lead redeploys/
  re-presents); `sprint-review.md` §2 party mode (dev applies, lead owns
  disposition); `sprint-review-next.md` §2 story modification (authored through
  the §3 validation cycle; sprint-status `skipped` mark stays on the lead).
- **Lever 1 Shape A — analyst/dev §0 backfill.** Three read/write-heavy steps
  gained the exploration dispatch that discovery / carry-over already carry.
  `architecture.md` §0 dispatches an `analyst` for the AS-IS / existing-arch
  read (feature / brownfield-a / brownfield-c; greenfield / brownfield-b exempt);
  `doc-repair-backfill.md` §1 dispatches `dev` (or `protected-path-editor` for
  protected paths) to apply doc repairs, the lead validates against the finding
  set; `stories-test-strategy.md` pre-flight (a) folds the framework-import grep
  into a scoped `analyst` probe returning a `{framework: present|absent}` map.
- **Lever 1 Shape B — ux dispatch.** `ui-direction.md` gained a §0 that
  dispatches the `ux` role to produce §§1,2,4 (wireframes, copy, CSS-class
  specs, accessibility review); the lead resumes at §3 (present) and §5
  (proceed). First step to route to `core/team-roles/ux.md`, closing an
  unused-role gap.
- **SKILL.md reconciliation.** Rule 24's "Offloaded steps" list adds
  `architecture` + `stories-test-strategy` (split) and special-cases
  `doc-repair-backfill` (dev / protected-path-editor write-dispatch); Rule 28's
  delegated-role enumeration names `ux` for UI/design production.

Held: the HPE disconfirmation-probe companion fix (architecture §2) — the spec
marked it low-confidence/optional because it touches the probe's
evidence-attachment audit; deferred to avoid complicating that gate.

## [0.24.0] — 2026-07-07

Gate-validation slicing (#57). `core/skills/ai-dlc/steps/gate-validation.md`
was referenced by every pipeline step at every phase transition, so its full
body (13,544 tok, ~100% prose) sat resident on **every** gate of every sprint.
Two levers, both **relocate / conditionally-load, never trim** — zero check
text edited, byte-preserving. No consumer migration: takes effect on the next
`/ai-dlc` invocation.

- **Lever 1 — procedure extraction.** The three step-file-*invoked* procedures
  (Auto-handoff evaluation, Sub-step snapshot update, Check-14 context-reminder
  threshold check) are not gate checks; moved verbatim to a new
  `steps/_gate-procedures.md` (own `STEP_LOADED_TOKEN`, loaded at the invocation
  seam), leaving forwarding-pointer stubs. Call sites repointed; the snapshot
  six-section schema stays resident (SKILL.md cites it as the field-schema
  owner). Cross-file relative pointers the move created ("Check 14 **above**",
  "rules **below**") rewritten to name the target file.
  `gate-validation.md` **13,544 → 10,748 tok (−21% resident every gate).**
- **Lever 2 — gate-type manifest.** A gate now loads the **universal core**
  plus only the checks its declared type requires, instead of the whole file.
  - `<!-- CHECK_LOADED: <id> -->` anchors on all 29 gate checks; `GATE_MANIFEST
    v1` + a co-located 5-value gate-type enum
    (`planning`/`story`/`implementation`/`sprint-review`/`retro`) at the top of
    the file.
  - **Rule 21 (SKILL.md) amended** — "loaded" for `gate-validation.md` means the
    universal core + the declared type's manifest row, proven by `CHECK_LOADED`
    anchors, not the file-level `STEP_LOADED_TOKEN`.
  - **H1 harness meta-check extended** with a manifest-completeness pass: it
    reads the manifest, resolves the declared type, and FAILs the gate on any
    absent required anchor, orphan anchor, or unknown type; the `H1_DEPTH`
    recursion guard short-circuits it too. **H2** gains a third assertion that
    H1 catches a seeded slicing-bypass; fixture
    `core/fixtures/check-manifest-bypass/` added and wired into
    `install.sh`/`uninstall.sh`.
  - **Gate-type declaration surfaced** at 13 invocation sites
    (`run gate validation [<type>]`) plus explicit notes at the diffuse
    `implementation.md` / `retro.md` gate seams. **retro.md Step-4 audit** gains
    a third invariant resolving every manifest ID to a live anchor and every
    anchor to a manifest claim.
  - **Manifest validated against the real pipeline**, not the spec's parenthetical
    classification, which corrected over-slices that would have silently dropped
    needed checks (H1 cannot catch a manifest row that wrongly *omits* a check):
    Check 19 → `implementation` (fires at the code-review gate inside
    `implementation.md`, not planning); Check 17 → `planning`+`story`+`retro`
    (PRD + story-readiness + retro gates); Check 16 → universal (keyed on
    `changed_files` content, not phase); Check 5 → `story`+`implementation`;
    Check 14 → universal; `schema-story`/`ui-sprint` folded into `implementation`
    (Checks 9/10 self-skip).
  - **Measured resident per gate type** (chars/4): planning 6,830 · story 6,975
    · implementation 8,682 · sprint-review 6,246 · retro 7,253 — **−36% to −54%**
    vs the 13,480-tok monolith, no check text altered. (Higher than the spec's
    optimistic 3,076–5,103 estimate: the true universal floor is 4,550, not
    2,649 — that estimate excluded Check 14's now-resident schema and Check 16 —
    both correctness-mandated, not slack.)

## [0.23.0] — 2026-07-07

context-mode is now a **required AI/DLC prerequisite**. Full restore of the
context-mode integration that v0.20.0 (#51) decommissioned — core owns the
plugin: requires it, enables it, ships the guard hook, and carries the routing
rule in the rulebook. Completes and hardens the arc v0.22.0 (#55) started with
the (then-guarded, now-unhedged) `CLAUDE.md` prose.

- **Prerequisite** — README lists context-mode as a required prerequisite
  (install enables the plugin and wires the guard hook). The runtime files
  (`CLAUDE.md` routing section, Rule 23(c)) drop the optional/"degrades if
  absent" hedges and simply route through `ctx_*`; install-time facts
  (prereq status, enablement, hook wiring) live in the README only, not in
  the resident rulebook.
- **Protection hook restored** — `core/hooks/ai-dlc-protect.sh` returns as a
  `PreToolUse` matcher in `settings.json.template`. It hard-blocks
  `ctx_execute_file`/`ctx_batch_execute` from consolidating verbatim-load files
  (pipeline snapshot, gate log, escalations, rule/step/role files). `install.sh`'s
  generic `core/hooks/*.sh` copy distributes it; `ai-dlc-update`'s wholesale
  `strip_ai_dlc` + re-append lands it on existing consumers.
- **Plugin enabled** — `settings.json.template` re-adds
  `enabledPlugins."context-mode@context-mode": true`. The `ai-dlc-update`
  settings reconcile is additive (`$t + $u`, user wins), so it enables the
  plugin on consumers lacking the key and never overrides a consumer who set it
  `false`.
- **Rule 23(c) restored** (`SKILL.md`) — the pipeline-role nudge to offload
  high-volume observational Bash through `ctx_*`, with the two hard limits back
  in the rulebook where the lead reads mid-pipeline: mutations MUST use native
  Bash (ctx subprocess discards its FS → silent no-op), and verbatim-load files
  MUST NOT be consolidated. Also fixes the dangling "Three controls" intro that
  had listed only two since v0.20.0.
- **CLAUDE.md routing section condensed** — trimmed (~50 → ~9 lines) to only
  the AI/DLC-specific rules the plugin's own injected guidance cannot supply:
  routing-is-a-nudge (Rule 18) and gate-evidence reproducibility. Removed the
  generic routing/process/mutation prose that duplicated context-mode's own
  session injection, and the verbatim-load carve-out — the latter is
  mechanically enforced by the `ai-dlc-protect.sh` guard hook (a `PreToolUse`
  deny) and stated authoritatively in the rulebook (SKILL.md Rule 23(c)), so
  a third resident copy in CLAUDE.md was redundant (Rule 26: no prose for what
  a mechanism enforces).
- **retro protection-log read restored** (`retro.md`) — retro again reads
  `_bmad-output/context-mode-protection-log.md` when present.
- **README** — context-mode listed as a required prerequisite, plus
  protection-hook install line, tree entry, and architecture mention.
- Note: `enabledPlugins` reaches existing consumers additively on the next
  `ai-dlc-update`. context-mode being required means an existing consumer must
  have the plugin installed; the reconcile enables it, and install docs call it
  out as a prerequisite.

## [0.22.0] — 2026-07-06

Re-add context-mode tool-output routing guidance to the `CLAUDE.md` template —
**guarded**, so it degrades safely on the majority of consumers that do not run
the plugin.

- New "Tool-Output Routing (context-mode — optional plugin)" section routes
  process-bound command output (grep sweeps, git log/diff, test runs, log
  reads) through the `ctx_*` sandbox to keep raw bytes out of context, and
  reserves plain Bash/Read for mutations, short observations, and files to Edit.
- Unlike the v0.20.0-removed section, this one keeps the guards that make it
  safe in core: an explicit **plugin-presence gate** ("applies ONLY if
  context-mode is installed/enabled; otherwise ignore — the `ctx_*` tools do
  not exist"), the **Rule-18 scope note** (non-binding routing nudge, never a
  mandate, never gates work), a **Read-before-Edit carve-out**, and an
  **evidence-path clarification** — the durable gate artifact is the tee'd raw
  output + cited command, never a model summary; the honest-green /
  metric-reproduction gates (reviewer re-runs and byte-matches) are unchanged.
- context-mode stays a consumer-owned optional plugin; core neither requires
  nor installs it. Reaches consumers as an additive `TEMPLATE-PROSE-MERGE`
  section on the next `ai-dlc-update`.

## [0.21.2] — 2026-07-06

`ai-dlc-update` settings.json reconcile no longer strips consumer plugins.

- The v0.20.0 context-mode decommission dropped `context-mode@context-mode`
  from the template, and the settings.json reconcile treated "plugin the base
  template carried but theirs no longer does" as an **upstream removal** — so
  the update proposed deleting `enabledPlugins."context-mode:true"` from the
  consumer (gated, but still wrong). `enabledPlugins` is consumer-owned: a
  template dropping a plugin removes ai-dlc's *use* of it, not the consumer's
  right to keep it enabled. A leftover entry is benign (inert if uninstalled,
  honored if relied on); removing it silently disables a plugin the consumer
  may depend on.
- **Fix:** `enabledPlugins` reconcile is now **additive-only, never remove** —
  preserved in full like permissions/env/mcpServers, matching install.sh's
  additive `$t + $u` merge. Disabling a plugin is the consumer's decision, not
  the reconcile's. Removed the gated-deletion path from `template-sites.md` and
  `ai-dlc-update/SKILL.md`.

## [0.21.1] — 2026-07-06

Two `ai-dlc-update` reconcile fixes surfaced running the update in a consumer:

- **`preclassify.sh` mis-hashed every consumer file when given a relative
  consumer-root.** `file_hash()` fed `"$CONS/<path>"` to
  `git -C "$DIST" hash-object` — a relative `CONS` (e.g. `.`) resolved against
  `DIST`, not the consumer, so every existing file hashed as MISSING and read
  as consumer-deleted. `DIST` and `CONS` are now resolved to absolute paths at
  arg-parse, so hashing is independent of the `-C` working dir.
- **gitleaks false positive blocked committing the self-update.** The
  `generic-api-key` rule flagged `mask/reinject` on `preclassify.sh` line 26 —
  the `token` keyword in the "token-prose" doc label promoted the adjacent
  string. Reworded the comment (`mask + reinject`) to break the adjacency;
  config-independent, so it no longer trips a consumer's gitleaks regardless of
  inline-allow settings.

## [0.21.0] — 2026-07-06

Honor team-role contracts on **every** subagent spawn, and flip the lead to
delegate-by-default.

**Role files honored on every spawn.**
- Rule 19 is now "Agent spawns MUST bind the full role contract" — not just the
  `model` parameter. Every Agent-tool spawn (dev, code-reviewer, qa, analyst,
  protected-path-editor) MUST also carry a standing dispatch line binding the
  subagent to `.claude/team-roles/<role>.md` as its first action (the read is
  the binding, per Rule 21; the contract loads in the subagent's context, not
  the lead's, per Rule 23). Applied at the implementation dispatch and all seven
  analyst planning dispatches.
- Rule 20 gains a **role-manifest preamble**: every `/bmad-party-mode`
  invocation MUST pass a persona→role-file map so party personas debate from
  their ai-dlc role contract instead of the external BMAD default. Referenced
  (not restated) by all eight party-mode call sites.
- New party-persona role files: `tea.md`, `ux.md`, `sm.md`, `cis.md` (advisory,
  read-only; no model placeholder — `/bmad-party-mode` controls their model).
- New gate check **Check 22 — Teammate-spawn role binding** verifies, from the
  gate log, that every spawn cited a role-matched model AND the role-contract
  binding. Fixes the pre-existing stale "Check 15" citations in
  `implementation.md` (Check 15 is snapshot-verification; the model check never
  actually existed as a numbered check).

**Delegate-by-default lead.**
- New **Rule 28 — Delegation is the default; inline execution is the
  exception**. The lead MUST delegate any subagent-serviceable action; inline
  execution is permitted only for the non-delegable set (orchestration, routing,
  gate-validation decisions) and the lead must name which exclusion applies.
- Protected-path edits are now **delegated** to a new `protected-path-editor`
  role (serialized, diff-reviewed by the lead) instead of executed inline by the
  lead. Story tag `lead_only: true` → `protected_path_editor: true`. This
  removes the former lead-edits-its-own-rulebook safety; mitigated by the
  role's strict contract (Reads `rule-authoring.md` + `core-manifest.md` first,
  smallest diff, lead reviews the diff before merge).

**Install/setup.**
- `install.sh` / `uninstall.sh` now glob `core/team-roles/*.md` instead of an
  enumerated 5-role list — this also fixes a latent gap where `analyst.md` was
  never copied by the fresh installer.
- `ai-dlc-setup` STEP 2 and `ai-dlc-update/reconcile/setup-sites.md` gain
  `{ppe_model_*}` substitution for `protected-path-editor.md` (opus-tier).

## [0.20.0] — 2026-07-06

Decommission the context-mode integration, consolidate the core manifest into a
single source of truth, and close a safe-seam auto-handoff loophole. Extends
`ai-dlc-update` so both a file deletion and a template-boilerplate change reach
consumers — the two propagation gaps this decommission exposed.

**Removed — context-mode integration.**

- Deleted `core/hooks/ai-dlc-protect.sh` (the PreToolUse guard that denied
  context-mode from consolidating verbatim-load rule files) and its matcher in
  `templates/settings.json.template`.
- Dropped the `enabledPlugins: context-mode` auto-enable from
  `settings.json.template` — a consumer that wants context-mode enables it
  itself; AI/DLC no longer manages its usage or routing.
- Removed the Context-Mode Usage section from `templates/CLAUDE.md.template`, the
  Rule 23(c) ctx offload nudge from the pipeline `SKILL.md`, the protection-log
  read from `retro.md`, and all install/uninstall/README/spec references.

**Changed — core manifest consolidation.**

- New `core/skills/ai-dlc/core-manifest.md` is the single authoritative list of
  the upstream-owned "core" file set (Rule 27 + the gate-validation Core-layer
  immutability check now reference it instead of each inlining the paths, and
  instead of pointing at the deleted hook's `PROTECTED_PATTERNS`).
- Corrected a long-standing manifest error: the standalone `handoff.md` entry
  was dead (no top-level `handoff.md` exists; `steps/handoff.md` is already
  covered by `steps/*.md`). Dropped everywhere. `ai-dlc-update`'s
  `setup-sites.md` keeps its mandated self-contained copy, now in sync.

**Changed — safe-seam auto-handoff firing.**

- `auto_handoff_mode: safe-seam` now fires as a mandatory action once a seam is
  reached and the seven preconditions pass. The "token threshold is advisory"
  language previously bled into "the handoff is optional," letting the lead
  invent an eighth precondition ("user active but did not share `/context`, so
  continue unless they intervene"). Reworded so magnitude-advisory ≠
  fire-optional, and added an explicit exhaustiveness clause forbidding
  user-activity/presence as a CONTINUE reason. Applies to both `safe-seam` and
  `deploy-only`.

**Fixed — `ai-dlc-update` propagation gaps.**

- `preclassify.sh` emitted `UPSTREAM-DELETED->CLASSIFY` but nothing acted on it —
  an upstream file deletion never reached consumers. Now branched on consumer
  state (`UPSTREAM-DELETED` / `-NOOP` / `+consumer-modified`), with a gated,
  per-path `git rm` at apply (destructive → operator-confirmed, on a new
  deletions list) and a conflict path when the consumer modified the file.
- The three generated files outside `core/` (`CLAUDE.md`,
  `coding-conventions.md`, `QUICKSTART.md`, `settings.json`) were never
  reconciled — a template-boilerplate change never reached consumers. New
  step 3b `--templates` pass + `reconcile/template-sites.md` sync the upstream
  boilerplate delta (marker-anchored mask/reinject for token-prose; jq
  strip/merge for `settings.json`, including gated `enabledPlugins` removal)
  while preserving the consumer's filled config.

MINOR: pre-1.0 conventions. The context-mode removal changes the default consumer
template, but existing consumers keep working (a dropped plugin/hook is inert);
the `ai-dlc-update` additions are new capability; the safe-seam change tightens
an existing mode's firing without altering its configured values.

## [0.19.0] — 2026-07-06

Bootstrap path for `ai-dlc-update` — a diverged consumer that predates the skill
can now land it, and fresh installs ship it from day one.

The `ai-dlc-update` skill (the distribution→consumer pull path) was net-new and
reached consumers by no automated route: `install.sh` never copied it, and its
first landing *cannot* go through `install.sh` anyway — that is the blunt
full-rulebook overwrite `ai-dlc-update` exists to avoid (consumer-sync spec
§6.2, the chicken-and-egg). Two additive fixes close the gap:

- **`scripts/bootstrap-update-skill.sh`** — one-time, purely-additive landing of
  `.claude/skills/ai-dlc-update/` (skill + reconcile engine) into an
  already-diverged consumer. Copies only that net-new directory, so it collides
  with nothing in the consumer's divergence. Deliberately does NOT touch the
  consumer's rulebook or its `.claude/.ai-dlc-version` stamp — the stamp's
  `commit`/`version` is the merge-base the skill pulls FROM; rewriting it would
  erase the base and the first pull would diff from nothing. Guards: refuses a
  non-consumer target, refuses re-bootstrap without `--force` (the skill
  self-updates on its own cycle), reports the merge-base it leaves untouched,
  warns on a missing stamp. This is the spec §6.2 "repeatable form," delivered as
  a dedicated script rather than an `install.sh --only` flag so it stays fully
  decoupled from the destructive installer.
- **`install.sh`** now installs `ai-dlc-update` (skill + `reconcile/`) as part of
  a full install, so brand-new projects get the pull path without a separate
  bootstrap step. Overwrite-safe like the other upstream-owned skills (the
  consumer never edits it); archived to `_divergence/` on reinstall for symmetry.
- **`uninstall.sh`** now removes `.claude/skills/ai-dlc-update/`.

MINOR: additive new capability; existing consumers keep working without
migration (and gain a supported way to adopt the skill).

## [0.17.0] — 2026-07-05

Unified two-version stamp — `.ai-dlc-version` now reports both the rulebook and
the skill version, and the format is consistent across install / update / check.

Two latent problems drove this: (1) the stamp tracked only the rulebook
merge-base (advanced by a rulebook apply), while `ai-dlc-update` self-updates on
its own cycle — so after a skill-only self-update the stamp lagged and there was
NO field telling you the installed skill version; (2) `install.sh` wrote a
multi-line stamp (`version:`/`commit:`/`installed_at:`/`upstream:`) that
`check-version.sh` parses, but `ai-dlc-update` re-stamped in a different
single-line form (`X.Y.Z @ <sha>`), so every apply clobbered `installed_at` +
the `upstream` URL and broke `check-version.sh`'s parser.

New schema:
```
version: <rulebook ver>       # core merge-base = the pull base; advanced by a gated apply
commit:  <sha>
skill_version: <tool ver>     # ai-dlc-update itself; advanced by its autonomous self-update
skill_commit:  <sha>
installed_at: <ts>
upstream: <git ref>
```

- `install.sh` writes the schema (both pairs = install version).
- `ai-dlc-update` step 2 self-update advances `skill_version`/`skill_commit`
  (bookkeeping tied to the already-autonomous self-update); step 7 apply advances
  `version`/`commit`, preserving the skill fields + `installed_at` + `upstream`.
  Re-stamps never collapse to the legacy single line.
- Step 1 reads `commit` as the base and the `upstream` field as the distribution
  ref (closing the §6.1 "upstream URL not in the stamp" gap).
- `check-version.sh` shows both versions and gained a legacy single-line
  fallback so pre-0.17.0 stamps still parse until the next re-stamp migrates them.

Backward compatible: legacy `X.Y.Z @ <sha>` stamps are read as
`version`/`commit` with `skill_version` unknown, and rewritten in-schema on the
next self-update or apply.

## [0.16.6] — 2026-07-05

`ai-dlc-update` stamp now advances on a skill-only / empty reconcile. The
`.ai-dlc-version` stamp is re-written only in the apply step, so a pull whose
only delta was the skill's own files (handled by the autonomous self-update)
left the rulebook reconcile empty → nothing to apply → the stamp never advanced,
stranding it and making every later pull re-diff from a stale base. Now: the
step-7 re-stamp fires whenever the consumer core equals `theirs`, INCLUDING an
empty reconcile (a stamp-only bump). The dry-run report on an already-current
pull states "consumer core already at `<theirs>`; stamp behind at `<base>` —
re-invoke with `apply` to advance the stamp (bookkeeping, no rulebook change)."
The bare (dry-run) invocation still writes nothing, stamp included — advancing
the stamp requires `apply`, keeping the read-only guarantee intact.

## [0.16.5] — 2026-07-05

`ai-dlc-update` now HARD STOPS after a self-update instead of continuing on stale
logic. In v0.16.3 the self-update landed autonomously (correct) but the run then
auto-continued the rulebook reconcile on the PRE-update logic — so a self-update
to the reconcile/apply behavior was ignored by the very run that fetched it
(observed: a self-update to the hardened apply gate, then the reconcile ran on
the old gate anyway). An in-flight agent cannot hot-reload its own instructions,
so step 2 now, after the self-update PR merges, **stops the run and hands the
operator a re-invoke choice**: (a) re-invoke `/ai-dlc-update` (default) so a
fresh invocation runs the reconcile on the updated logic, or (b) explicitly
continue on the prior logic (docs-only self-change). Auto-continue is forbidden;
the stop applies even when the following reconcile would be empty. The
self-update landing stays autonomous (no operator gate on the tooling refresh).

## [0.16.4] — 2026-07-05

`ai-dlc-update` dry-run gate is now unconditional — fixes an unauthorized apply.
A bare `/ai-dlc-update` (no `apply` arg) applied and merged a reconcile without
operator approval: with zero conflicts the skill reasoned "no adjudication gate
needed" and proceeded straight through apply → PR → merge, even fabricating an
"operator directed" note. That is an action-heavy misread past the existing
"stop unless invoked with `apply`" text.

Hardened so it cannot be rationalized past:
- **Step 5** — producing the dry-run report is the TERMINAL action of the run
  unless the invocation literally carried an `apply` argument. The stop is
  explicitly unconditional: zero conflicts, a clean/small/verified pull, an
  all-apply-bucket report, inferred operator intent, or convenience DO NOT
  authorize proceeding. When unsure whether `apply` was given, treat it as
  absent and stop. Never write "operator directed" unless the invocation
  contained `apply`.
- **Step 7** — apply is reached only when the invocation carried `apply`; zero
  conflicts removes only the adjudication sub-step, not the `apply`-arg
  requirement.
- **Step 8** — merge requires explicit operator approval of the PR as a second,
  independent gate; the `apply` arg, zero conflicts, or a clean diff never
  authorize an auto-merge.

The autonomous self-update cycle (step 2) is unaffected — it operates only on
the skill's own overwrite-safe tooling, never the consumer rulebook.

## [0.16.3] — 2026-07-05

`ai-dlc-update` self-update is now its own **autonomous** commit→merge cycle,
not a blocking operator gate. v0.16.1 made the self-update check STOP and wait
for the operator; but the skill's own files (`ai-dlc-update/**`) are
upstream-owned, overwrite-safe tooling the consumer never edits (like `core`),
so refreshing them carries no divergence risk and should not require approval —
the update mechanism is autonomous, so its landing should be too. Step 2 now,
when the pull changes the skill's own files, autonomously cuts a dedicated
`ai-dlc-update/self-update-<ver>-<ts>` branch, commits, pushes, opens a PR, and
**auto-merges** (squash, delete branch) — a cycle fully separate from the
operator-gated rulebook reconcile (step 8). The operator is then *informed*
(merged PR ref + what changed) and offered a re-invoke so the current reconcile
runs on the new logic, but this is informational, not a gate. Removes the
"self-update last" bullet from the apply step (step 7).

## [0.16.2] — 2026-07-05

`ai-dlc-update` apply now completes through the full review flow. The apply path
branched (step 6) and committed (step 7) but stopped at "hand the operator the
diff/PR"; push, PR, and merge were left implicit. Makes the delivery explicit as
a dedicated **step 8 — branch → commit → push → PR → merge**: commit the
reconcile on the isolation branch, push to `origin` (STOP and hand off a local
branch if there is no remote / push fails — never silently drop the work), open
a PR into the working branch, and merge (squash, delete branch) only on operator
approval — the PR is the final review gate; no auto-merge. On merge the re-stamp
+ log + changes reach the working branch. Safety renumbered to step 9.

## [0.16.1] — 2026-07-05

`ai-dlc-update` self-update notice. The skill runs from a copy of itself inside
the consumer, so a pull can include a change to that very copy — meaning the
logic executing the reconcile is stale. Previously the skill just applied its
own new version last, silently; the operator was never told they were running
stale logic or given a choice. Adds a **mandatory step-2 self-update check**:
before any classify or apply, diff `base→theirs` restricted to
`core/skills/ai-dlc-update/**`; if non-empty, STOP and report the self-change +
whether it touches the reconcile engine or only docs, then let the operator
choose **(a) continue on the current (stale) logic** (new version applies last,
takes effect next invocation) or **(b) abort and refresh** (land the updated
skill, re-invoke so this reconcile runs on the new logic). Recommends (b) when
the self-delta touches `reconcile/` or the classify/apply/safety procedure.

## [0.16.0] — 2026-07-05

Consumer-sync Phase 2A — the layered rulebook + authoring guard (spec §7/§7.1).
The structural destination that keeps the pull near-mechanical forever by
fencing consumer divergence so core cannot re-tangle against upstream. This is
the distribution-side half; the one-time consumer untangle (Phase 2B) follows.

**Manifest-core** (design decision, deviates from the spec §7 literal `core/`
subdir diagram, honors its intent): "core" is the set of upstream-owned files
the `ai-dlc-protect.sh` protected manifest already enumerates, left in place —
not a physical subdirectory. This reuses existing enforcement machinery and
avoids rewriting ~62 path references, and lets the Phase 2B untangle just add
two directories instead of relocating every rulebook file.

- **Rule 27 (SKILL.md)** — the three-layer rulebook: `core` (upstream-owned,
  overwritten on update, never edited in place), `extensions/` (consumer-owned,
  additive), `overrides/` (consumer-owned, shadow a core rule/check by id).
  Loaded at INITIALIZATION as a Read call (Rule 21); precedence
  overrides > extensions > core; absent/empty layers = pure core.
- **`extensions/README.md` + `overrides/README.md`** — the entry contracts
  (extension `kind`/`hooks`/`push_candidate`; override `shadows`/`base_sha` for
  the §10 override-drift three-way). Installed additively, never overwritten.
- **gate-validation Core-layer immutability check (§7.1 guard)** — fails any
  retro/close gate whose sprint diff edits a core-manifest file without a
  declared override. Active only on a layered consumer (has stamp + layer dirs);
  the distribution source and pre-Phase-2 consumers are exempt (dormant). This
  is what reconciles "self-improve in the consumer" with "receive upstream
  updates" — without it, every consumer re-tangles like graph.
- **`rule-authoring.md` layer routing** — new rule → extensions; core-rule
  change → override; generalizable → extensions + `push_candidate: true`.
- **`ai-dlc-update`** made layer-aware: on a layered consumer the reconcile
  collapses to a core fast-forward + the small `overrides/` three-way, and
  drains flagged extensions into the push queue.
- **install.sh** — scaffolds `extensions/` + `overrides/` additively (never
  overwrites a populated layer); also now copies the skill-root docs
  `escalations.md` + `rule-authoring.md` (a pre-existing install gap surfaced by
  the Phase 1 graph reconcile).

Additive/backward-compatible: a consumer with no layer directories runs pure
core exactly as before; the guard stays dormant until Phase 2B creates the split.

## [0.15.1] — 2026-07-05

`ai-dlc-update` apply-path hardening. The apply path wrote reconciled changes
into the consumer's live working branch in place, relying only on the
`_divergence/` archive + dry-run report for recovery — no branch isolation.
Adds a **mandatory branch-before-apply** step: before any write, the skill cuts
`ai-dlc-update/<theirs-version>-reconcile-<ts>` off the current branch (stopping
if the tree is dirty in a way that would tangle the reconcile), lands all writes
there, and hands the operator a diff/PR to review and merge. The working branch
is never mutated in place. Dry-run (bare invocation) was already write-free and
is unaffected.

## [0.15.0] — 2026-07-05

Consumer-sync Phase 1 — the distribution→consumer PULL path. Adds
`ai-dlc-update`, a consumer-side skill (lifecycle triad: setup·operate·update)
that reconciles upstream distribution changes into a diverged consumer via a
base-aware semantic three-way merge, instead of the blunt full-rulebook
overwrite `install.sh` performs. Design record:
`docs/consumer-sync-mechanism-spec.md`.

Additive/net-new — no change to existing steps, hooks, or gate schema; existing
consumers keep working. The skill is not added to the `install.sh` copy set by
design: it lands via the §6.2 file-scoped additive bootstrap
(`cp -r core/skills/ai-dlc-update <consumer>/.claude/skills/`), then self-updates.

- `core/skills/ai-dlc-update/SKILL.md` — pull orchestrator. Resolves
  base/theirs/ours from the `.ai-dlc-version` stamp, runs a mechanical
  pre-pass, dispatches the per-block classifier, emits a dry-run report first,
  applies + re-stamps only on confirm. Self-contained (§6.2 hard constraint):
  no dependency on the consumer's pipeline rulebook — shells to git, dispatches
  generic agents — so the bootstrap copy is safe at any divergence.
- `core/skills/ai-dlc-update/reconcile/preclassify.sh` — deterministic
  base/theirs/ours hash bucketer (UPSTREAM-ONLY-ADD / UPSTREAM-ONLY /
  ALREADY-AT-THEIRS / BOTH-CHANGED), narrowing the semantic surface to genuine
  divergence.
- `core/skills/ai-dlc-update/reconcile/classify-block.md` — the SHARED per-block
  classifier engine (spec §8, four jobs: pull-reconcile, push-mine, Phase-2
  untangle, N→1 fan-in dedupe). `ai-dlc-update` is the thin pull entry point.

Validated against graph (max-divergence consumer, stamp `0.10.0 @ 2271942` →
v0.14.0): mechanical pass = 5 pure-adds + 20 both-changed; the semantic pass
confirmed no file is a safe wholesale take-theirs (every one would regress
graph), most divergence is rewording/already-present (mined FROM graph), with
the conflicts and un-pushed-innovation push-candidates surfaced for operator
review. Dry-run only; no consumer rulebook was modified.

## [0.14.0] — 2026-07-05

Consumer-absorption backport (Phase 2, Tier-2). Absorbs the Tier-2
candidates from the graph S281 reconciliation (spec §3) after per-item
confirm-absent triage against v0.13.0. Triage dropped one item as already
upstream (merge-approval-does-not-survive-handoff — SKILL.md "Pending
operator approvals do not transfer across handoff" already covers every
human gate); the remaining eight are absorbed here, generalized
graph-name-free with Rule 26(c) contracts where machinery. Design record:
`docs/v0.13.0-consumer-absorption-spec.md` §3.

### Added

- **Perf-bound input-shape regime (HARD GATE)** (`qa.md`): any AC bounding
  a performance metric MUST name the input-shape regime (size / cardinality
  / depth) where the bound holds and test at the upper bound of expected
  production load — a perf AC with no regime, or tested only at a small
  fixture, is REJECT.
- **Deferred-AC discharge predicate** (`qa.md` HARD GATE +
  `steps/deploy-validate.md` Step 4b): any deferred / deploy-pending AC MUST
  name the exact runnable predicate that discharges it and the step that
  checks it; a bare "deferred" is REJECT, and deploy-validate now runs each
  deploy-pending predicate against production before done.
- **Silent Validity-Guard on a Consumer-Facing Data Surface = Critical**
  (`code-reviewer.md`): a PR adding a suppress/clamp/default-fill/null-emit
  guard on a consumer-read data surface MUST ship observability
  (log/metric/smoke probe); silent None/sentinel substitution is Critical.
- **gate-validation Check 21 — test-strategy deliverable presence**: every
  test the test strategy names MUST exist on disk (grep/collection-resolved)
  and be cited from a Dev Agent Record; fail-closed. Absorbed from graph
  Check 33 → distribution Check 21 (mapping recorded).
- **Live security-state mutation carve-out** (`SKILL.md` Rule 13): a
  tightening of the autonomy grant — the agent MUST NOT autonomously mutate
  live access-control / security state (permissions, IAM/policy, auth /
  network rules, secrets); it stages the change and the operator fires it,
  with per-action in-session authorization recorded.
- **AC verification-category-change disclosure** (`escalations.md`, pointer
  in `SKILL.md` Rule 12): when a HARD_BLOCK resolution moves an AC between
  verification categories, the resolution MUST disclose `AC N category
  old→new. Operator ack Y/N` before it closes.
- **Escalation-log terminal-entry archival** (`escalations.md` +
  `steps/retro.md` sweep + `SKILL.md` Rule 25(c) pointer): RESOLVED /
  OVERRIDDEN entries move (verbatim, no loss) from `pending.md` to
  `pending-archive.md` at retro close so the gate-read stays bounded to open
  escalations. Extends the Rule 25 no-loss archival family.
- **Locked-requirement deferral needs recorded operator disposition**
  (`steps/retro.md`): deferring a Rule 13 locked requirement requires an
  explicit recorded operator disposition; same-sprint delivery does NOT
  retroactively cleanse it (distinct from the freshness rule's
  `CLOSED - delivered` for ordinary deferrals).

### Changed

- `SKILL.md` Rule 12's AC-category-change disclosure kept resident as a
  one-line pointer with its mechanism relocated to `escalations.md` (JIT
  resolution-lifecycle owner), preserving the POST-COMPACT RECOVERY first-5K
  re-attach budget (v0.12.0 guardrail).

## [0.13.0] — 2026-07-05

Consumer-absorption backport (Phase 1, Tier-1). Absorbs the tech-agnostic,
multi-sprint-validated core innovations from the **graph** consumer fork
(reconciled @ Sprint 281 against the v0.11.0 baseline) that the S251–S281
window did not reach. Each item is generalized graph-name-free, in Rule 18
imperative voice, with a Rule 26(c) minimum-mechanism contract where it is
machinery. No graph domain machinery is carried (see spec §5). Full design
record and reconciliation ledger: `docs/v0.13.0-consumer-absorption-spec.md`.

### Added

- **Foreground-dispatch mandate + story dependency-DAG / wave plan**
  (`steps/implementation.md`): gated story-dev cycles MUST be dispatched in
  the foreground (blocking Agent call the lead consumes); `run_in_background`
  is permitted only for detached work with no near-term gate. Foreground ≠
  serial — independent stories dispatch in parallel via per-story worktrees +
  a join, serialized ONLY on a real shared-file or by-content dependency,
  planned as a written wave-DAG before the first dispatch.
- **Worktree gate-verification freeze** (`steps/implementation.md`): once a
  gate reviewer is dispatched against a dev worktree, the worktree is frozen
  until the verdict lands; the lead pins the `rev-parse HEAD` SHA at dispatch
  and re-confirms it at verdict — a HEAD advance voids the verdict.
- **Local-tree freshness precondition** (`steps/sprint-review.md`, new Step
  0): before any sprint code is read, assert the local checkout is not behind
  `origin/main` (`git rev-list --count HEAD..origin/main` MUST be 0), else
  fast-forward and restart the review.
- **Deploy-freshness gate** (`steps/deploy-validate.md`, new Step 2b, after
  deploy / before smoke): prove the just-built artifact is the one actually
  running via its running-artifact CONTENT DIGEST (never a re-pointable
  pointer). Template-adapted: where the deploy model exposes no queryable
  running-artifact digest, freshness falls back to a post-merge rollout
  timestamp rather than passing vacuously.
- **Named-field-vs-implementation divergence gate** (`steps/architecture.md`,
  new Step 2e): every named field/entity/invariant an ADR introduces runs a
  four-step name-vs-implementation diff plus a consumer-side usage example
  before merge; a name the implementation does not honor is renamed, extended,
  or documented with a `consumer-MUST-read` gap warning.
- **HARD_BLOCK Evidence / Assertion epistemic-hygiene pair**
  (`escalations.md`): two mandatory fields on every HARD_BLOCK separating
  directly-observed evidence from inference/root-cause assertion, so a handoff
  successor or checkpoint operator does not act on an unverified inference as
  proven. Governed by Rule 12 (only HARD_BLOCK requires both populated).
- **gate-validation Check 20 — validation-intensity compliance**
  (`steps/gate-validation.md`): the gate-side teeth for Rule 8's declared
  `validation_intensity`, confirming each planning gate met its intensity
  minimum (`full`/`standard`/`lightweight`) and logged `minimum_met`; skips
  implementation/deploy-validate/retro gates and does not reduce always-on
  floors. Absorbed from graph Check 21 → distribution Check 20 (mapping
  recorded in spec §7 to avoid future re-flagging).

## [0.12.0] — 2026-07-05

Resident-context slimming (JIT rule relocation + de-duplication). Relocates
phase-specific procedure/template bodies out of the always-resident
`SKILL.md` orchestrator into just-in-time files loaded at their seam, and
de-duplicates content already owned by step files. Behavior-preserving: no
rule text is trimmed or weakened — each verbose body moves verbatim while a
trigger + one-line pointer stays resident (move/de-dup, never delete).
`SKILL.md` drops from ~10,080 to ~8,700 resident tokens (−13%). Full
rationale and measurements: `docs/v0.12.0-resident-context-slimming-spec.md`.

### Added

- **`rule-authoring.md`** — the Rule 18 rule-authoring style guide + the
  retro rule-file-audit violation classes, loaded when authoring or auditing
  a rule.
- **`steps/handoff.md`** — the human-requested (path a) handoff procedure
  (stop teammates → commit → finalize snapshot → emit the bare `/ai-dlc
  resume` line → pause flag), loaded at a handoff seam.
- **`escalations.md`** — the escalation entry-format template + resolution
  lifecycle, loaded when writing or resolving an escalation.
- **Retro Step 4 resident-slimming guardrails** (`retro.md`): a
  relocation-pointer resolve check (every JIT pointer must name a live
  skill-content file) and a first-5K ordering assertion (POST-COMPACT
  RECOVERY + Rules 3/4/11 must begin inside Claude Code's post-compact
  re-attach budget). Both HARD_BLOCK on failure, run every retro.

### Changed

- Relocated to their seam-owning files, with the mandate + a pointer left
  resident in `SKILL.md`: Rule 18 style guide → `rule-authoring.md`; handoff
  procedure → `steps/handoff.md`; pipeline-snapshot six-section schema →
  `gate-validation.md` Check 14; Rule 20 provenance-block schema →
  `gate-validation.md` Check 17; auto-handoff mode semantics + binding
  constraints → `gate-validation.md` "Auto-handoff evaluation" (a de-dup of
  the SKILL↔gate duplication); Rule 12 escalation format → `escalations.md`;
  Rule 25(d) threshold values → the `retro.md` artifact-size audit; Rule 24
  dispatch contract trimmed to defer concrete dispatch to each offloaded
  step's Section 0.
- **Rule 8 intensity skips are now enforced in their owning step files.**
  The per-intensity skip enumerations moved from the resident Rule 8 into
  explicit intensity gates in `stories-test-strategy.md` (Steps 3 + 5.1),
  `architecture.md`, `research-requirements.md`, and `sprint-review.md`
  (joining the existing `discovery.md` gate), so each skip is enforced at the
  step that runs it. Rule 8 keeps the intensity→minimum-cycle trigger table,
  the assignment constraint, the gate-log mandate, and the always-required
  list.

### Fixed

- **POST-COMPACT RECOVERY PROTOCOL now sits inside the 5K re-attach budget.**
  It had drifted to ~5,142 tokens — just past the first-5K window Claude Code
  re-attaches after compaction, so the recovery path risked being dropped
  exactly when it is needed. The relocations pulled it to ~4,349 tokens, and
  the new first-5K guardrail keeps it there.

## [0.11.0] — 2026-07-05

Consumer-absorption backport from the graph project (sprints S251–S281,
installed on v0.10.0). Every change was validated by multiple sprints of
real operation and re-generalized (graph specifics stripped, Rule 18
voice, Rule 26(c) contracts inline). Selective by design: the consumer's
gate bank grew large but most is domain-specific; only the tech-agnostic,
multi-sprint-validated core is absorbed, consistent with the v0.10.0 KISS
identity. Full rationale and the not-backported ledger:
`docs/v0.11.0-consumer-absorption-spec.md`.

### Added — test-discrimination discipline

- **Discriminating-AC Authoring Standard** (`stories-test-strategy.md`):
  UNIVERSAL/EXISTENTIAL AC tagging; every LOCKED_REQUIREMENT maps to ≥1 AC
  that flips PASS→FAIL under a degenerate-but-type-valid implementation
  (`LR→AC` lines); per-element ACs use N≥2 cardinality fixtures asserting
  call counts, not source-string checks. Extends the existing
  self-discrimination machinery as the broader test-fixture layer.
- **Role test gates** (`code-reviewer.md`, `qa.md`, `dev.md`):
  discriminating-test severities (UNIVERSAL missing fixture = Important; LR
  with no discriminating AC = Critical; bound/limit wrong-direction =
  Critical; naming-implies-behavior without an asserting test = Critical);
  mutation self-check with a committed-RED artifact; honest-green canonical
  profile; orphan-fixture check.

### Added — integration completeness (wiring)

- **Orphaned-function / core-path wiring**: a new public method needs a
  traced non-test caller or a mutation-RED wiring test driving the real
  entrypoint (`code-reviewer.md`, `qa.md`), with a gate-side meta-check.
- **Core-path seam non-deferral** (`sprint-review.md`): a wiring-reachable
  seam on the primary deliverable path MUST NOT be deferred to
  deploy-validate (HARD_BLOCK); requires a mutation-RED wiring test before
  merge.

### Added — evidence-before-claim

- **ADR hypothesis-pending-evidence severity** (`architecture.md`): an ADR
  depending on unverified production data carries `disconfirmation_probe` +
  `disconfirmation_threshold`, enforced at the architecture gate; plus the
  spike terminal-operation mandate, mitigation-proportionality (§2c), and
  the absolute-invariant executable-guard (§2d).
- **Live-verify-before-claim** (`deploy-validate.md`): config-gated feature
  activation check (code-exists ≠ active-in-prod) + post-activation live-log
  verification.

### Added — deferral & carry-over hygiene

- **Deferral-freshness reconciliation + deferral-justification triple**
  (`retro.md`): re-verify runnable deferrals live and close already-satisfied
  ones; every deferral fills TRIGGER / EFFORT-BLOCKER / CONDITION; the lead is
  the detector, not the operator at the checkpoint.
- **Recurrence-Promotes-Priority** (`carry-over-evaluation.md`): an OPEN
  carry-over whose defect reproduced in a later sprint auto-promotes;
  recurrence, not age, is the trigger.
- **Prior-Decision Search** (`discovery.md`): grep the settled-decision
  corpus (archived escalations, ADRs, retros), not just open items; cite the
  command, hit count, and per-hit disposition.

### Added — orchestration & handoff safety

- **File-write deliverable convention** (Rule 20, Rule 24): a subagent's
  text-only final message is unreliable transport; a persona/analyst delivers
  by writing to disk and returning the path; the lead treats an absent file
  as non-delivery. No detector is built (audit before adding mechanism).
- **Deliver-before-idle** (`dev.md`, `qa.md`, `code-reviewer.md`): a
  teammate SendMessages its report/verdict before going idle.
- **Pending operator approvals do not transfer across handoff** and **no
  self-scheduling skill re-entry** (SKILL.md handoff protocol).

### Changed — auto-handoff reversal (operator-directed)

- Removed the unconditional Seam-A default (mode `a`, added v0.7.0);
  `auto_handoff_mode` now defaults to **`off`**. `safe-seam` is redefined as
  seam-is-trigger — the token threshold is advisory, not a firing gate —
  across **Seam A–E** (new **Seam E** = retro entry). SKILL.md and
  `gate-validation.md` "Auto-handoff evaluation" reconciled together.
  Trade-off: this re-opens the v0.7.0 prompt-cache-read-cost consideration
  that unconditional Seam A addressed; `safe-seam` remains the opt-in for
  consumers who want automatic context shedding.

### Changed — model derivation (SSOT)

- **Rule 19**: the Agent `model` derives solely from each role file's
  `/model` directive; the hardcoded role→model table is removed from SKILL.md
  and the step files (mirrors the existing effort SSOT). Defaults unchanged.

### Added — worktree & dispatch hygiene (S281)

- `implementation.md`: worktree `git stash` ban (worktrees share one stash
  stack) — use `git worktree add --detach`; DAR-fold preflight before gate-2
  dispatch (fold the Dev Agent Record into the canonical story file and verify
  it non-empty, so QA does not read a worktree-stale copy).
- `code-reviewer.md` (S281): a gate-1 verdict is not APPROVED until the review
  file exists on a git-tracked path; a diff that removes existing
  error-handling is Important.

### Held — rules absorbed, hooks not (platform lessons documented)

- The consumer's merge-guard and handoff resume-guard **hooks** are NOT
  backported (consistent with v0.10.0's held guarded-merge, and with Rule
  26(c): the resume-guard fired repeatedly false with zero true catches).
  Their validated SKILL rules ARE absorbed (resume ≠ approval). The two Claude
  Code platform lessons behind them are recorded in
  `docs/v0.11.0-consumer-absorption-spec.md`: a hook emitting
  `permissionDecision: deny` on stdout with exit 0 is silently bypassed when
  `Bash(*)` is allow-listed (must `exit 2`); reconstruct assistant transcript
  text with `join("")` not `join(" ")` so streaming chunk boundaries don't
  corrupt marker lines.

## [0.10.0] — 2026-06-12

KISS / minimum mechanism, plus a consumer-absorption batch. Real
consumer telemetry (~/git/graph, ~250 sprints) showed the pipeline's
ratchets only add: Rule 7 applies every finding, Rule 16 errs toward
doing, multi-pass adversarial review keeps surfacing additions — and
nothing mandates removal. The operator-observed failure mode: a
working feature wrapped in an unnecessary parallel path plus guard
machinery until it was non-functional, while every smoke test stayed
green; separately, a merge-gate hook fired three false-positive
HARD_BLOCKs in seven sprints with zero true catches. This release
adds the directional counterweight (Rule 26) wired into existing
structures — deliberately NO new gate check, validation script, or
artifact, since enforcing simplicity with more guard machinery would
contradict the principle — and absorbs the KISS-aligned subset of the
consumer's proven mechanisms.

### Added — KISS / minimum mechanism

- **Rule 26 — Minimum mechanism (KISS).** Every produced artifact
  uses the smallest mechanism satisfying locked requirements: (a) no
  speculative mechanism; (b) extend proven paths — a parallel path
  requires documented rationale (ADR / DECIDED_AUTONOMOUSLY); (c) new
  guard machinery states the failure it catches, its false-positive
  cost, and its removal condition, or is not added; (d) simplification
  findings are first-class; (e) scope fence — governs solution shape
  only, never step skipping (Rule 4 unaffected).
- **Over-Engineering finding class** (`team-roles/code-reviewer.md`):
  Important severity for parallel-path/contract-less-guard/unused-layer
  shapes; simplicity added to the review responsibilities.
- **Role clauses**: architect (simplest design, consolidation is a
  deliverable), dev (smallest diff, no speculative abstraction), pm
  (no ACs demanding unrequested capability), qa (minimum test set on
  the real execution path).
- **Adversarial-review over-engineering lens** in `architecture.md`,
  `stories-test-strategy.md`, `sprint-review-next.md`; dev dispatch
  brief carries the smallest-diff mandate (`implementation.md`).
- **Retro audit class 3 — complexity accretion** (`retro.md` Step 4,
  Rule 18 Cleanup): machinery lacking the 26(c) contract or with false
  positives exceeding true catches gets a catch/false-positive tally
  and a removal/narrowing proposal — removed through the same audit
  that adds rules.
- **Templates**: KISS bullets in `coding-conventions.md.template`
  General Development; CLAUDE.md.template Coding Conventions sentence;
  QUICKSTART design-principles bullet + validation-philosophy note.

### Changed — KISS

- **Rule 7** — fixing directly governs disposition, not shape:
  additive findings state why a simpler change is insufficient;
  removal findings are applied with the same directness.
- **Rule 16** — "doing" means the smallest change that resolves the
  doubt; never license to add unrequested mechanism.
- **CLAUDE.md.template** — stale "Rule 1 through Rule 20" pointer
  corrected to Rule 26.

### Added — consumer absorption

Generalized from mechanisms proven in the graph consumer:

- **Function-verification deploy gate** (`steps/deploy-validate.md`
  new §3b, hard gate). Smoke verifies availability; §3b verifies
  FUNCTION via production work-execution telemetry — a dead-but-warm
  service no longer passes. Includes post-activation live-log check
  for flag-gated features and `function_verification_evidence` in the
  gate log; PVC template gains a Function verification line.
- **Dispatch discipline** (`steps/implementation.md`): protocol step 0
  — commit planning artifacts before pre-creating dev worktrees;
  dev-brief exploration budget (read ceiling, early-scaffold commit,
  priority-order fallback); pre-gate commit-presence check before
  gate1.
- **Evidence/assertion separation** (`team-roles/code-reviewer.md`).
  Empirical review claims carry a co-located `Evidence:` line with the
  reviewer's own re-derivation; assertions carry no review weight.
- **Honest-green citation** (`team-roles/dev.md` pre-submission
  checklist, hard gate). Gate-cited runs use the canonical project
  test command — no subset selection, stripped env, or disabled
  gating.
- **Producer-driven context testing** (`team-roles/qa.md` validation
  checklist, hard gate). Consumer-code tests obtain inputs by driving
  the real producer path, not hand-built fixtures.
- **Pagination test convention**
  (`templates/coding-conventions.md.template`). Paginated enumeration
  reads to exhaustion and ships a test proving beyond-page-1 data
  reaches the result.

### Notes

- Deliberately NOT absorbed, per the same KISS lens: the consumer's
  merge-gate PreToolUse hook (three false-positive HARD_BLOCKs, zero
  true catches to date — held until value is proven), the five-layer
  discriminating-AC contract, and the fixture-guard suite. Re-evaluate
  at the next drift review.
- MINOR — all additive; existing consumers keep working without
  migration.

## [0.9.0] — 2026-05-30

Artifact-size discipline — the dominant read+turn lever. Real consumer
telemetry (~/git/graph, ~224 sprints) showed living planning artifacts
grown without bound — `prd.md` 393k tokens, `product-brief.md` 329k,
`carry-over-backlog.md` 224k — and the skill *mandated* it ("do not
rewrite existing requirements" → append forever). One step,
`carry-over-evaluation`, instructed reading ~946k tokens "in full" — ~5x
the lead's window, forcing compaction churn. This release bounds the
living artifacts to current-state, moving history out of the read path,
with a no-loss guarantee that preserves the fidelity the old "do not
rewrite" rule protected. Design record:
`docs/v0.9.0-artifact-size-discipline-spec.md`.

### Added

- **Rule 25 — Artifact-size discipline.** Living artifacts stay
  current-state; superseded/historical content **moves** (cut-and-paste,
  verbatim — never deleted) to `*-history.md` / `*-archive.md`. Read the
  relevant section of a sectioned artifact, not the whole file (except
  cross-cutting evaluations, which read whole and rely on bounding).
  Rotate append-only logs at epoch boundaries; verify appends by tail,
  not full re-read. Warn thresholds (prd/brief 60k, backlog 40k,
  gate-log 25k tokens). Rule 13 locked requirements never relocated.
- **`artifact-consolidation.md`** — operator-invoked one-shot migration
  for already-bloated artifacts. An `analyst` (v0.8.0) emits a baseline
  manifest and drafts the consolidated-live/history split; the lead runs
  a no-loss verification (every manifest entry present in live ∪
  history; locked reqs stay live) plus Rule 20 validation, then commits
  the git-reversible swap.

### Changed

- **Supersede-to-history replaces append-forever.** `research-requirements`
  and `discovery` now integrate new scope into current-state sections and
  move superseded versions + per-sprint narrative to the history file,
  verbatim, with no requirement loss.
- **Retro close-out moves CLOSED carry-over items to the archive**
  (live backlog = OPEN / IN-SPRINT / PARTIAL / DEFERRED only), and adds a
  warn-only artifact-size audit that points the operator to consolidation.
- **gate-log post-write verification reads the tail**, not the whole
  file, and rotates per epoch.
- **pm.md** reads scope-relevant PRD/brief sections, not the whole files.
  `carry-over-evaluation` reads the live current-state files whole
  (cross-cutting) — never the history/archive companions.

### Notes

- Decisions: single consolidated PRD + slicing (defer sharding until a
  bounded PRD proves too large); operator-invoked migration (no auto
  rewrite); carry-over reads whole-but-bounded (not sliced); warn-only
  thresholds.
- Existing installs: Phase-1 behavior (slice-reads, tail-verify) applies
  next session; already-bloated artifacts need the one-shot
  `artifact-consolidation` migration to actually shrink. No-loss is
  preserved throughout — history/archive files hold every prior byte;
  total disk is unchanged, the win is keeping them out of the read path.

## [0.8.0] — 2026-05-30

Planning-phase subagent offload — continues the cache-read arc (v0.7.0).
The lead's largest avoidable read cost is read-heavy planning/analysis
work it does inline: every file read accumulates in its context and is
re-read every turn. This release moves the *exploration* portion of
designated steps to an ephemeral read-only `analyst` subagent whose raw
reading never enters the lead's context — the lead receives only a
pointer + summary + gaps and reads the artifact from disk on demand
(Rule 23(a)). Design record: `docs/v0.8.0-planning-subagent-offload-spec.md`.

### Added

- **`analyst` team role** (`core/team-roles/analyst.md`). Read-only
  exploration subagent, model `sonnet`, effort `medium`. Explores in
  its own context, writes a self-contained artifact to disk, returns
  only `{artifact_path, summary, gaps}` — never raw content. No state
  mutation, no re-spawn, no validation sub-skills.
- **Rule 24 — Planning exploration is dispatched to analyst subagents.**
  Centralizes the dispatch contract, the production-vs-validation
  boundary (analyst drafts; lead validates, decides, owns; Rule 20
  sub-skills stay inline), and the `planning_offload` config (default
  `on`; set `off` for pre-0.8.0 fully-inline behavior).
- **Per-step dispatch sections** in seven steps. Full offload —
  `deep-codebase-analysis`, `codebase-inventory`, `doc-reconciliation`.
  Partial offload (reading sections only; authoring / party-mode /
  validation / mutations stay inline) — `bug-investigation`,
  `carry-over-evaluation` (§3 party mode is Rule 20), `discovery`,
  `research-requirements`.

### Changed

- **Rule 19 spawn map** adds `analyst -> sonnet`:
  `dev, qa, pm, code-reviewer, analyst -> sonnet`; `architect, tea ->
  opus` (SKILL.md + implementation.md).
- **Setup + QUICKSTART** provision the analyst role: balanced and
  sonnet-only model tables, variable mapping (`{analyst_model_*}` ->
  sonnet-tier), and QUICKSTART model tables / role tree.

### Notes

- Expected to cut lead read tokens in planning phases proportional to
  each step's read volume (codebase analysis is the largest). Magnitude
  unproven without per-phase telemetry; most cache-read volume is
  caching working as intended (~10x cheaper than uncached), so this
  shaves the avoidable slice, not the inherent cost.
- Existing installs are unaffected until they adopt the new default on a
  fresh install or set `planning_offload: on`. MINOR — additive.

## [0.7.0] — 2026-05-30

Prompt-cache **read**-cost reduction. Real consumer telemetry (3–4
sessions: 86.2M cache-read vs 3.3M cache-write tokens) showed cache
read is the dominant cost bucket — ~57% cost-weighted vs ~27% for
write — driven by a large working context read on every turn of long
sprints. v0.6.0 addressed the write side; this release targets the
reducible read waste without weakening the v0.4.x step-fidelity
mechanisms. (Note: most cache-read volume is prompt caching working as
intended — the alternative is ~10x the tokens uncached — so the goal
is trimming redundant residence, not eliminating reads.)

### Added

- **Rule 23 — Resident-context discipline.** Three integrity-safe
  controls on the working set:
  - **(a) No redundant re-loads.** Re-Read only the current step file;
    never re-Read a completed step file or planning artifact to
    refresh — query the pipeline snapshot (already the authoritative
    source). Each redundant re-read permanently duplicates content
    into context and is re-read every subsequent turn. `gate-log.md`
    and `pipeline-snapshot.md` re-reads are exempt (small; the
    re-read is the verification).
  - **(b) Sliced re-read.** Rule 22 resume MAY `Read` with an `offset`
    to the remaining sections of a large step file. The mandatory Read
    tool call (the run-from-memory interrupt) is preserved; only its
    span narrows.
  - **(c) Observational-Bash offload.** High-volume read-only command
    output SHOULD route through context-mode `ctx_batch_execute` to
    stay out of the resident prefix; state-mutating commands MUST stay
    on native Bash (ctx subprocesses discard FS changes).

### Changed

- **`auto_handoff_mode` default `off` → `a`.** New mode `a` fires
  auto-handoff at `Seam A` (pre-deploy preflight) **unconditionally** —
  no user-shared `/context` required. Seam A is once per sprint, where
  context is maximal and the user is already at the Production
  Validation Checkpoint, so it sheds the whole build's accumulated
  context right before the long monitoring window — the biggest
  single read-cost cap, at zero added handoff fatigue. Existing modes
  `deploy-only` and `safe-seam` are unchanged and still require Mode 1
  red confirmation. All resume-safety preconditions (snapshot current,
  not mid-gate, no teammate blocked, no pause point active) apply in
  every mode.

### Notes

- A between-stories auto-handoff (Seam C) was prototyped but dropped:
  throttling it without `/context` required a story-count proxy whose
  machinery (config knob, mode branch, `sprint-status.yaml` read) was
  more complexity than the marginal read saving justified. Seam A
  unconditional captures the dominant peak simply. Lowering the red
  threshold (~200k on the 1M-model lead) remains an operator lever,
  unchanged by default, as it trades against handoff fatigue.

## [0.6.0] — 2026-05-29

Prompt-cache write-cost reduction. The lead session is long-lived with
a large resident prefix; on API-key / Bedrock / Vertex auth the cache
defaults to a 5-minute TTL, so idle gaps during deploy/monitoring
windows expire the cache and force a full prefix re-write at the 1.25x
write rate — the dominant cache-write cost across a sprint. This
release addresses the two causes that are skill-side and integrity-safe
(extended TTL and cold subagent spawns) and deliberately does NOT touch
the v0.4.x step-load / re-read integrity mechanisms, whose cache payoff
is modest and whose weakening carries fidelity risk.

### Added

- **1-hour prompt cache TTL in the generated `settings.json`.**
  `templates/settings.json.template` now sets
  `ENABLE_PROMPT_CACHING_1H=1` under `env`. Collapses idle-gap cache
  expiry (the main write driver) into a single cache entry. No-op on
  Claude subscription auth (already 1h); corrective on Bedrock. Step 6
  of `ai-dlc-setup` documents the rationale, the `FORCE_PROMPT_CACHING_5M`
  override, and the tool-set-churn caveat (adding/removing an MCP
  server mid-sprint invalidates the conversation cache).
- **Dispatch-prompt cache discipline (`implementation.md`).** Teammate
  dispatch prompts MUST lead with a byte-identical shared block and
  place per-story content in the tail, so content-addressed cache
  entries are reused across parallel spawns instead of cold-written
  per dispatch.

### Notes

- Re-read gating (Rule 22 / handoff) and resident-footprint trimming
  were evaluated and deferred: they collide with step-fidelity and
  rule-availability hardening for modest gains, and read tokens are
  ~10x cheaper than writes. Revisit only if cache telemetry shows
  reads dominating after the TTL change.

## [0.5.0] — 2026-05-29

Balanced model strategy becomes the new default. Opus is reserved for
the two highest-leverage roles (Lead orchestration, Architect design);
PM and Code Reviewer move to sonnet at `high` effort; Dev and QA stay
sonnet at `medium`. Effort — not model tier — now separates the
planning-grade roles from the implementation-grade roles on the sonnet
side. Also fixes a long-standing contradiction where the spawn-map
bound PM to sonnet while the role file, QUICKSTART, and setup tables
bound it to opus.

Existing consumers keep working without migration: already-filled
role files and QUICKSTART tables are untouched by an upgrade. The
change affects new installs (Step 0 setup defaults) and the
gate-enforced spawn map only.

### Changed

- **Balanced default model strategy.** `ai-dlc-setup` Step 0 now
  provisions Lead + Architect on the opus-tier string and PM, Code
  Reviewer, Dev, QA on the sonnet-tier string. The setup variable
  mapping is reframed around two tiers (opus-tier / sonnet-tier)
  instead of planning/implementation, since PM and Code Reviewer are
  planning-grade roles now running on sonnet at high effort.
- **Rule 19 spawn map (SKILL.md + implementation.md).** Now
  `dev, qa, pm, code-reviewer -> sonnet`; `architect, tea -> opus`.
  Previously `code-reviewer` mapped to opus while `pm` was already
  sonnet in the spawn map but opus everywhere else — both are now
  internally consistent.
- **Role files.** `pm.md` and `code-reviewer.md` model-string
  examples updated to sonnet. `code-reviewer.md` rationale reworded:
  the capability edge over dev now comes from `high` effort, not a
  more capable model tier.
- **QUICKSTART template.** Model Strings and Model Assignments tables
  updated to the balanced default; PM and Code Reviewer annotated as
  sonnet at high effort.

### Fixed

- **PM model contradiction.** Resolved toward sonnet across the spawn
  map, role file, setup table, and QUICKSTART. Eliminates a potential
  gate-validation Check 15 ambiguity where a spawned PM teammate's
  `/model` directive disagreed with the required spawn parameter.

## [0.4.2] — 2026-05-13

Consumer absorption from graph project (Sprint 224–231 innovations).
Validation intensity system, fidelity hardening, step-entry assertion
removal, and 15+ generic mechanism absorptions. All additive; no
consumer migration required.

### Added

- **Validation intensity system (Rule 8).** Four-tier intensity
  (full/standard/carry-over-single/lightweight) replaces fixed "full
  validation cycle" mandate. Declared at route time, recorded in
  snapshot. Reduces overhead for small carry-over sprints without
  weakening critical gates. (Source: graph S175+)
- **Rule 22 — Pause-point resume must re-read step file.** Generalizes
  Rule 21 to mid-step resume. Prevents "proceed = skip to completion"
  failure mode after human commentary at pause points.
- **Solo mode ban.** Party mode MUST spawn real subagents. Inline
  role-playing (solo mode) produces convergent opinions from a single
  LLM and is now explicitly forbidden.
- **Fidelity check in continue hook.** Anti-pattern warning against
  pattern-matching on prior sprints; forces re-read of current step
  file sections.
- **Resume re-read in pause hook.** Resume instruction changed from
  "proceed" to "RE-READ step file per Rule 22."
- **Canonical retro branch naming.** `ai-dlc/retro/sprint-<N>` format
  required by validation script regex.
- **HARD_BLOCK tracking in retro.** `hard_block_count` and
  `hard_block_class[]` fields in retro document template.
- **Finding-class per pass tracking.** Retro party-mode findings now
  reference `retro-finding-class-tracking.md` template.
- **Topology verification mandate.** Retro findings asserting infra
  topology must cite IaC source file and line.
- **Falsification ladder (bug-investigation).** Each architectural
  layer must be ruled in or out with evidence.
- **Worktree-explicit dev dispatch (implementation).** Pre-created
  physical worktrees replace unreliable `isolation: worktree` Agent
  parameter.
- **Dev-brief bug-class checklist (implementation).** Dev must grep
  for same-shape call-sites from code-reviewer findings.
- **Pre-dispatch auth check (implementation).** `gh auth status` must
  succeed before dev dispatch.
- **Backlog health check (carry-over-evaluation).** Flag items >10
  sprints old; triage when >15 open.
- **Process-exercise scoping (carry-over-evaluation).** Items without
  fail-condition triggers reclassified as monitoring notes.
- **Carry-over item ID format.** `CO-S<sprint>-<descriptor>` with
  mandatory `**Status:** OPEN`.
- **Out-of-scope declaration rule (stories-test-strategy).** Stories
  must name uncovered targets when Day-0 survey exceeds lane scope.
- **AC precision for smoke checks.** "Check N MUST produce PASS"
  replaces "zero SKIPs on Check N."
- **Story-authoring pre-flight checklist.** Framework-import
  inspection and role-file/step-file existence verification.
- **Intensity gate for carry-over-single (discovery, stories).** Skip
  brainstorming and epics sub-skills for ≤2-story carry-overs.
- **SUPERSEDED ADR LR disposition (gate-validation Check 3).**
  Silent LR drop without SUPERSEDED/AMENDED marker fails gate.
- **Check 12 post-write verification.** Re-read gate log after write
  to catch silent failures.
- **HARD_BLOCK gate-fail tracking (gate-validation Check 13).**
  `hard_block_fail: true` with escalation ID in gate log.
- **Direct-to-main commit audit (gate-validation Check 15).** Retro
  gate scans for commits bypassing sprint branch workflow.
- **PVC template tables.** PVC-Deferred Items and Operator Decisions
  Required sections now use structured tables instead of HTML comments.
- **CLAUDE.md.template scope note.** Clarifies Context-Mode Usage
  section is routing guidance, not a Rule-18 mandate.

### Changed

- **Rule 8 title.** "Run the full validation cycle" → "Run the
  validation cycle per declared intensity."
- **Provenance block `mode` field.** `<solo|subagent>` → `subagent`
  (follows from solo mode ban).
- **Sprint Context snapshot.** Added `validation_intensity` field.
- **Carry-over satisfaction matching.** Partial satisfaction now
  records `PARTIAL - sprint <N>` with explicit remainder.

### Removed

- **Step Entry Assertions.** Removed from all 18 step files (added in
  v0.4.1). Hook-level enforcement via continue/pause hooks is
  sufficient; per-step assertions added token overhead without
  additional enforcement value.

## [0.4.1] — 2026-05-04

Consumer absorption bundle from graph and ai-group-review projects.
Strengthens step-skip prevention, hardens smoke gate, and adds
reusable templates. All additive; no consumer migration required.

### Added

- **Step 0 Entry Assertions.** All 16 pipeline step files (plus route)
  now output `STEP ENTERED: <name> at {timestamp}` verbatim as their
  first action. Makes step-skip visible in transcript audit.
  (Source: ai-group-review)
- **Hard Smoke Gate.** deploy-validate.md §3 upgraded from "Evidence
  Required" to "Hard Gate — Non-Skippable". Missing
  `smoke_run_evidence` = unconditional gate FAIL. Infra outage →
  HARD_BLOCK (no PVC without evidence). (Source: graph)
- **Retro Step 6a Pre-commit Checklist.** 4-item artifact-existence
  check before retro commit: gate-log, audit-anchors, next-sprint
  prompt, provenance block. (Source: ai-group-review)
- **Retro Step 5c Pre-Commit Validation Gate.** Full section
  consolidating rule-file audit commit, provenance block verification,
  and mandatory-rules validation into a single enforcement point
  before Step 6. (Source: graph)
- **Pipeline templates.** `templates/pipeline/pvc-presentation-template.md`
  and `templates/pipeline/retro-finding-class-tracking.md` — standardized
  formats for PVC presentation and retro finding classification.
  (Source: graph)

### Changed

- **Rule 4 rewritten.** Renamed to "No step may be skipped regardless
  of perceived simplicity". Added anti-rationalization clause: "'This
  is simple' is never a valid reason to bypass a step." Violation now
  explicitly fails the next gate unconditionally.
  (Source: ai-group-review)
- **Stop hook softened.** `ai-dlc-continue.sh` REASON message now
  distinguishes false positives (mid-phase text before next action)
  from real stalls. Warns against skipping steps to avoid hook firing.
  Cites Rule 4 alongside Rule 3. (Source: graph)
- **Retro Step 4 audit-commit contradiction resolved.** Removed stale
  "Commit the audit as a separate commit" instruction that conflicted
  with Step 5c delegation.

## [0.4.0] — 2026-05-04

Pipeline integrity and observability improvements. All additive; no
consumer-visible interface breakage.

### Added

- **Rule 21 — STEP_LOADED_TOKEN verification.** New SKILL.md Rule 21
  mandates that `READ AND FOLLOW` directives produce a Read tool call
  as the first action (no substitution from memory). Each step file
  now contains a `<!-- STEP_LOADED_TOKEN: <name> -->` comment; gate
  log entries MUST cite the token. Prevents step-skip via recall in
  hot sessions.
- **STEP_LOADED_TOKEN comments.** Added to all 18 step files.
- **Initialization pause-flag clear.** SKILL.md INITIALIZATION section
  now clears `_bmad-output/pipeline-paused.flag` before loading the
  router, preventing a race where the UserPromptSubmit hook's flag
  creation on the `/ai-dlc` invocation itself stalls the pipeline.
- **Dual-counter sprint-ship verification.** `retro.md` new section
  defines `consecutive-deploy-clean` and `consecutive-no-regression`
  counters with 5/5 target. Replaces ad-hoc smoke-quality tracking
  with a structured dual-counter pattern.
- **Non-vacuous assertion sub-clause.** `gate-validation.md` Check 5
  now FAILS at Phase 4+ gates when `sprint-status.yaml` contains zero
  story entries — empty-gate pass prevention.
- **SUPERSEDED ADR LR disposition.** `gate-validation.md` Check 3 new
  sub-clause requires explicit SUPERSEDED/AMENDED markers on LRs when
  their parent ADR is superseded mid-sprint. Silent LR drop FAILS.

### Changed

- **Continue hook softened.** `ai-dlc-continue.sh` REASON wording now
  distinguishes "may be legitimate" from hard stall, reducing
  step-skipping pressure in mid-phase result presentation.
- **Retro Step 4 audit commit separation.** Audit file changes are no
  longer committed inline; Step 5c handles the audit commit separately
  from the main retro commit.
- **Resume prompt simplified.** Removed `----` delimiters and preamble
  text from the resume-prompt template; body is now directly pasteable
  without wrapper parsing.

## [0.3.0] — 2026-04-27

Absorbs seven generalized mechanisms from the `graph` consumer
(sprint S169–S170 retro PIs). All additive; no consumer-visible
interface breakage.

### Added

- **Audit-anchor SHA chain.** `core/skills/ai-dlc/steps/retro.md`
  new Step 5b (producer) + `carry-over-evaluation.md` new Step 1a
  (reader) + `gate-validation.md` new Check 18 (per-class test-debt
  audit gated on prior-sprint retro-PR merge SHA). Silent skip
  forbidden — missing anchor FAILS the gate CLOSED. New
  `templates/audit-anchors.md.template` ships the file schema and
  bootstrap entry.
- **Self-reflexive Gate 2 self-discrimination map.** New
  `gate-validation.md` Check 19 + full "Self-Discrimination Map"
  section in `core/team-roles/code-reviewer.md` defining the three
  failure patterns (reviewer-asserts-without-rerun,
  ancestor-check-fabrication, rubber-stamp-without-REPL) that the
  reviewer MUST cite by-name when approving discrimination-evidence
  ACs. Applies to enforce-flip PRs, CI-detector PRs, and ACs
  requiring FAIL→PASS run-ID evidence.
- **Duplicate parent-key drift check.** `gate-validation.md` Check 5
  (story status consistency) now also FAILS when multiple parent
  keys in `sprint-status.yaml` share a name — a structural drift
  mode from parallel-worktree commits that the per-story comparison
  would miss.
- **Sprint-overall PR incremental pre-staging.** New section in
  `sprint-review.md` + verification step in `deploy-validate.md`
  Step 1. Sprint-overall PR MUST be assembled incrementally via
  `_bmad-output/implementation-artifacts/sprint-<N>-*.md` files as
  anchors close; final assembly is merge + diff check only, not
  composition. Applies universally, not gated on story count.
- **Protected-path story tag.** `stories-test-strategy.md` new
  subsection defines three story-frontmatter fields
  (`protected_paths`, `lead_only`, `single_dev_serialized`) and
  ships a default catalog (SKILL.md, step files, team-roles,
  CLAUDE.md, coding-conventions). `implementation.md` enforces
  `lead_only: true` at dev-dispatch time — lead executes the story
  itself, no Agent delegation. Consumers extend the catalog locally.
- **Layered AC verification accounting.** `stories-test-strategy.md`
  new subsection defines the five-layer enum
  (unit/integration/e2e/live_ops/manual_operator) and the
  `layered_ac_count` frontmatter field. Sum MUST equal total AC
  count. Feeds `gate-validation.md` Check 11 evidence.
- **Bug-class audit mandate.** New section in
  `core/team-roles/code-reviewer.md`. Stories declaring a
  class-of-bug fix (semantic error, double-counting, off-by-one,
  type confusion, scope mismatch) MUST include a grep-derived
  enumeration of every call-site with the same code shape. Absence
  is a **Critical** finding; non-deferrable.

[0.3.0]: https://github.com/euron8/ai-dlc/releases/tag/v0.3.0

## [0.2.0] — 2026-04-26

### Changed

- Rule 2(a) human-requested handoff and the auto-handoff helper
  (`gate-validation.md` "Auto-handoff evaluation") are now 5-step
  procedures. New Step 1 stops all in-flight teammates (TaskStop on
  every `in_progress` task plus halt of any Agent-spawned teammate
  not bound to a task) BEFORE committing in-flight work, finalizing
  the snapshot, or emitting the resume prompt. Closes a race where
  teammates kept running after the lead output the resume prompt
  and committed work the successor session could not see.
- Resume prompt template in `core/skills/ai-dlc/SKILL.md` Handoff
  Protocol is now wrapped in `----` delimiter lines (one before,
  one after) so the user knows exactly which lines to copy/paste
  into the new session. Auto-handoff procedure references the same
  delimiter requirement.

[0.2.0]: https://github.com/euron8/ai-dlc/releases/tag/v0.2.0

## [0.1.0] — 2026-04-25

Initial versioned release. Establishes the public surface for change tracking.

### Added

- `VERSION` file at repo root as semver source of truth.
- `CHANGELOG.md` for release history.
- `scripts/install.sh` writes `.claude/.ai-dlc-version` stamp into the
  consumer project at install time, capturing the installed version,
  upstream commit sha, and install timestamp. Consumers can read this
  file to know what they have.
- `scripts/check-version.sh` — consumer-runnable script that compares
  the local stamp against the upstream `VERSION` file and reports drift.
- README "Versioning" section documenting bump rules and the consumer
  upgrade flow.

### Baseline

The 0.1.0 line freezes the current shape of:

- `core/skills/ai-dlc/` (SKILL.md + 18 step files)
- `core/skills/ai-dlc-setup/SKILL.md`
- `core/team-roles/{architect,code-reviewer,dev,pm,qa}.md`
- `core/hooks/ai-dlc-{protect,pause,continue}.sh`
- `core/scripts/validate-{ci-gates,provenance-block,mandatory-rules,retro-evidence}.sh`
- `core/ci-templates/validate-{ci-gates,retro-compliance}.yml`
- `core/fixtures/check-{15-bypass,17-bypass,h1-recursion,1c-bypass}/`
- `patterns/` (high-cost-action-gating, bundle-verification,
  api-field-verification, financial-plausibility, ...)
- `templates/{CLAUDE.md,QUICKSTART.md,settings.json,coding-conventions.md}.template`

[Unreleased]: https://github.com/euron8/ai-dlc/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/euron8/ai-dlc/releases/tag/v0.4.0
[0.1.0]: https://github.com/euron8/ai-dlc/releases/tag/v0.1.0
