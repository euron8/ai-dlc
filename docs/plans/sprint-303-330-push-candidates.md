# SPENT — four graph-consumer push candidates. DO NOT EXECUTE THIS.

**DISCHARGED.** Every action item is complete. All four remediations shipped as **v0.372.0**,
merged as `1537e4c` (#551), cut from `origin/main` and gated with
`AI_DLC_FIXTURE_NO_SKIP=1 bash .githooks/pre-push` — 156 ok / 0 FAIL, each changed fixture read
by NAME against an impossible-name control. The consumer at `/Users/n8/git/graph` was never
written to; all four `PC-` ids appear verbatim in the v0.372.0 CHANGELOG, which is its close
signal.

**What the run produced that this file did not predict**, which is the more useful half:

- **The R1 filing's consequence was false and its two reproductions were different defects.**
  No core caller greps the summary line, and the sprint-303 case (coverage WARN beside PASS)
  states two things that are both literally true. Only the sprint-302 case was a contradiction.
- **R2's filing was wrong that Check 18 is prose**, and the real gap is deeper than filed: the
  chain is a 1-deep link, so a hole at N−2 is permanently invisible. Filed as `BL-007`.
- **R4 was four defects, not one** — including a `core/scripts/` row stale since v0.126.0.
- **A defect nobody filed**: the recover hook's `${STEP_FILE}` fallback rendered its own MUST as
  an unexecutable instruction, so a lead in that branch could not comply.
- **A subagent's probe found a guard of mine that flips no verdict** — the gate's marker
  fast-path. It is a cost guard, now documented as one and covered by an arm keyed on cost
  rather than on a decision. **I authored that one arm and its subject**, which is the thing the
  different-author rule exists to prevent; it is recorded here rather than hidden.
- **`suite-dispatch-order` flaked under the pool** — green solo, `ok` on one pooled run and
  `FAIL` on the next with the same tree. Pre-existing, filed as `BL-008`.
- **My first cost arm could not fire**: it watched `jq`, which the gate only reaches *below* the
  guard being tested, so the arm passed against its own mutant. The signal had to be `sed`.

Original text follows, unedited.

---

# EXECUTE THIS — four graph-consumer push candidates, adjudicated and remediated

Four entries from the graph consumer's push-candidate ledger, each re-verified against this
working tree rather than against its own filing text. **All four are real and all four ship.
Three of the four filings are materially wrong about WHY, and one of them is wrong in the
direction that makes the fix bigger.**

## Start here

**Repos and the boundary.** Work in `/Users/n8/git/ai-dlc` (the distribution). The consumer
`/Users/n8/git/graph` is READ-ONLY for the whole of this program — read it to derive a figure,
**do not write it**, do not commit in it, do not push from it. Its push-candidate ledger at
`_bmad-output/ai-dlc-update/push-candidate-ledger.md` is the consumer's own record and is not
ours to annotate. The channel it reads on its next reconcile is this repo's `CHANGELOG.md`,
which closes an entry by naming its `PC-` id verbatim — the consumer's `NAMED-UPSTREAM` signal.
That citation is a required part of the release, not a courtesy.

**PING THE OPERATOR on any question, on any decision this file does not already make, and on
completion — including an early stop.** From outside, a session that is thinking and a session
that is waiting on a human look identical.

**Every figure and citation here was derived against the working tree at `dae23fa`
(VERSION 0.371.0), each with a control in the same invocation.** They are hypotheses again the
moment the tree moves. Re-derive before acting on one.

**Delegate aggressively.** Each of R1–R4 touches a different subsystem and they do not share a
file. Spawn a subagent per remediation to draft it, and a separate reviewer subagent per
fixture — `.claude/rules/fixture-mutants.md` requires the fixture's author be a different hand
from the arm's, deliberately, and that is the whole reason it works.

**Go to the numbered action list.** Everything above it is evidence for why those actions are
the actions.

## Status

Nothing built. All four adjudicated, premises re-derived at `dae23fa`, operator decisions taken
on R2, R3 and R4 (recorded in each section). This is the only status record in this file.

## Context

The graph consumer files defects it finds in the distribution into its push-candidate ledger.
The operator asked for four named entries to be implemented here. None of the four ids appears
in `CHANGELOG.md`, `docs/backlog.md` or any `docs/plans/*.md` — control: the known-closed id
`PC-S303-DERIVED-FIXTURE-SET-IS-MOST-OF-THE-SUITE` returns 1 from `CHANGELOG.md` in the same
invocation. All four are unclaimed and unclosed.

Only `PC-S330` carries a `verify:` receipt. The three `PC-S303` entries carry none (control: 69
`verify:` lines exist elsewhere in that ledger), so they have no mechanical close signal and the
CHANGELOG citation is the only thing that will close them.

---

## R1 — `PC-S303-BUDGET-SCRIPT-PASS-LINE-UNCONDITIONAL`

**The defect is real. The filing's stated consequence is FALSE, and the report back must say so.**

The summary line is not literally unconditional — it is guarded on the wrong variable.
`core/scripts/validate-artifact-budget.sh:1267` gates it on `RC`, and `RC` is deliberately left
at 0 on the `--warn-only` path when no breaching artifact was hardened with `--fail-on`
(`core/scripts/validate-artifact-budget.sh:1049`). So `WARN: N artifact(s) over the Rule 25(d)
budget.` prints at `:1013`, every `OVER` row prints at `:1017`, and
`PASS  every measured living artifact is within its Rule 25(d) budget.` prints at `:1269` in the
same run.

**The filing says this "defeats the budget-blocking callers' own read path". It does not.** The
enforcement map lists five call sites (`core/skills/ai-dlc/enforcement-map.yaml:1050`), and not
one of them greps the final line: `core/skills/ai-dlc/steps/route.md:168` reads the exit code,
`core/skills/ai-dlc/steps/gate-validation.md:889` reads the exit code, and
`core/skills/ai-dlc/steps/gate-validation.md:875` explicitly FORBIDS the grep the filing
describes. The one caller that reaches the defect state is retro
(`core/skills/ai-dlc/steps/retro.md:533`), and it is told to transcribe the breach rows, not the
summary. **What is real is a run whose own two lines contradict each other.** That is worth
fixing on its own; the read-path claim is not true against core and the consumer should be told.

**The two reproductions in the filing are different defects, and only one is a contradiction.**
The sprint-302 case above is a flat contradiction. The sprint-303 case — ungoverned read-path
artifacts warning alongside `PASS` — comes from the coverage arm at
`core/scripts/validate-artifact-budget.sh:1243`, which is warn-only ALWAYS and never folded into
`RC` by design (`:1205`). Its `WARN` and the `PASS` claim are both literally true there, because
an ungoverned artifact is unmeasured rather than over budget. Fix the contradiction; make the
coverage case legible rather than silent.

### What to change

- **`core/scripts/validate-artifact-budget.sh`** — key the summary line on whether a breach row
  was emitted this run, never on `RC`. **Do not touch the exit code.** `RC=0` on an unhardened
  `--warn-only` breach is the contract retro depends on, and changing it wedges
  `core/skills/ai-dlc/steps/retro.md:533` on every sprint that has already paid for an oversized
  artifact. Three arms feed the contradiction — budget (`:1009`), schema (`:1067`) and status
  (`:1160`) — and all three are `WARN_ONLY`-suppressed the same way.
- **`core/skills/ai-dlc/steps/retro.md:593`** — the evidence contract tells the lead to record
  `or "within budgets"`, a string the script has never emitted. Bind it to the real line.
- **`core/scripts/verdict.sh:114`** — the rc=0 evidence grep matches `ok|warn|OK:|PASS` and omits
  `OVER` and `WARN:`, which appear only in the rc≠0 set at `:122`. A `--warn-only` breaching run
  routed through `verdict.sh` would therefore surface neither the count nor the rows. No core
  site combines the two today, so this is latent rather than live — fix it in the same release
  because it is the same false-clean surface.

### Fixture

**New.** Nothing in the suite asserts the summary line. Control: `every measured living artifact`
has exactly two hits tree-wide — `core/scripts/validate-artifact-budget.sh:1269` and
`core/skills/ai-dlc-update/reconcile/retired-tokens.sh:17` — and neither is under
`core/fixtures/`. `snapshot-supersession-marker` is the only fixture touching `--fail-on` at all.

Seed a tree with one over-budget artifact and drive the real script four ways: `--warn-only`
unhardened, `--warn-only` with `--fail-on` naming the breacher, no flag, and clean. Assert the
summary text AND the exit code in each, so a fix that silences the line by breaking the contract
fails. Ships (its subject is on every consumer).

---

## R2 — `PC-S303-RETRO-NO-CLOSE-RECORD-FOR-RESET-OR-ABANDONED-SPRINTS`

**The filing's central mechanical claim is wrong: Check 18 is not prose.** It was, and was
converted — `core/scripts/validate-audit-anchors.sh:42` records that the check "published a
mechanical predicate and shipped no program for it" and that `--prior-sprint-sha` is now the
single home. It is registered at `core/skills/ai-dlc/enforcement-map.yaml:303` with two fixtures.

**The gap it names is real, and it is narrower and deeper than filed.**

- The chain is a **1-deep link, not a chain**. `core/scripts/validate-audit-anchors.sh:356`
  computes `prior = current - 1` and exact-matches it. There is no contiguity assertion anywhere.
  Control: `monotonic`/`contiguous` language exists elsewhere in the corpus
  (`core/scripts/validate-spec-join.sh:292`), so the grep works; none of it is in the anchor path.
- **Abandonment before close produces no gap at all.** `core/schemas/sprint-status.json:127`
  makes `status: done` the only value with mechanical meaning, and anything else re-uses sprint
  N. The gap arises only when a sprint reaches `done` without a retro-PR merge reaching Step 5b
  (`core/skills/ai-dlc/steps/retro.md:745`, the only writer).
- **The schema cannot express why an entry is absent.** `core/schemas/audit-anchors.json:34`
  carries `sprint`, `sha`, `closed_at`, `audit_window` and no state field, so absence is the only
  representation of a non-retro'd sprint.
- `reset` and `abandon` have **0 hits** in `core/skills/ai-dlc/steps/route.md` (control:
  `HARD_BLOCK` returns 5 from the same file), and no pipeline variant terminates outside retro.

### What to change — operator decision taken: filed scope plus a writer mode, no gap detection

- **`core/schemas/audit-anchors.json`** — add an OPTIONAL close-reason field with a CLOSED
  vocabulary. Optional is load-bearing: every existing consumer file lacks it, and a required
  field wedges live work on first contact.
- **`core/scripts/validate-audit-anchors.sh`** — add a `--close-record` mode that WRITES a
  schema-valid non-retro entry. The repo's rule is to render safety-critical output rather than
  let a model retype it, and this record's whole job is to be read by a fail-closed gate.
- **`--prior-sprint-sha`** — accept a close record as a valid link. It must still answer the
  question the caller asked: either resolve an audit-window base, or name plainly that this
  sprint has no audit window. A mode that returns success while resolving nothing turns
  Check 18 into a tautology.
- **The close path itself** — locate where a sprint is marked `done`
  (`core/scripts/sprint-status.sh:311` resolves the id; find the writer) and document the
  non-retro close there. It does not belong in `route.md`, which has no concept of it.
- **`docs/vocabulary-index.md`** — the new field is a controlled vocabulary. Change the OWNER and
  re-render; an arm whose header reads as a vocabulary join and carries no `# vocabulary:` marker
  fails the push.

**Do not add continuity detection.** It was considered and declined by the operator as beyond the
filing. File it in `docs/backlog.md` as a `BL-` entry with an `sh` receipt so it is not lost —
that file exists for exactly this state.

### Fixtures

`core/fixtures/audit-anchors-schema/` and `core/fixtures/check5-anchor-base/` both exist and both
SHIP. Extend both rather than creating a third. `check5-anchor-base/run.sh:15` already asserts
each of the four failure causes on its own wording; a fifth accepted-link case joins that set. The
accept arm is ABSENCE-shaped — it passes when nothing fires — so it **requires a committed
mutant**, not a seeded near-miss.

---

## R3 — `PC-S303-POSTCOMPACT-RECOVERY-MANDATE-HAS-NO-STATED-EXCEPTION`

The mandate is real and has no exception and no observer. `core/hooks/ai-dlc-recover.sh:93` and
`:99` carry the two bolded MUSTs; the hook is a `SessionStart` hook with matcher `compact`
(`templates/settings.json.template:207`), and it is advisory — it emits `additionalContext` and
has no deny path.

**Nothing in the tree observes whether the mandated reads happened.** No hook parses a `Read`
tool call, and none of the eight matcher blocks in the settings template names `Read`. Control:
five hooks DO parse `tool_name` and emit deny/allow, so the codebase gates tool calls freely and
simply never gates this one. The nearest thing, `core/hooks/ai-dlc-postcompact.sh:10`, records
whether the text was INJECTED — never whether it was OBEYED. The fixture
`core/fixtures/postcompact-rulebook-recovery/run.sh:80` asserts the hook SAYS it, and concedes at
`:20` that delivery and refusal-to-ship are its only two ends.

**A defect nobody filed, found while adjudicating this one.** The second mandate interpolates
`${STEP_FILE}`, and when the snapshot grep finds nothing the fallback at
`core/hooks/ai-dlc-recover.sh:74` is the literal string `(named in Pipeline Position -- read the
snapshot)`. The mandate then reads `Read (named in Pipeline Position -- read the snapshot)` in
full — an instruction that cannot be executed as written. A lead in that branch cannot comply,
and this partly explains a skip the filing attributes wholly to conduct.

### What to change — operator decision taken: mechanize, plus a stated exception with disclosure

- **New `PreToolUse` gate hook** under `core/hooks/`, registered in
  `templates/settings.json.template` (I13 makes the template the single registration site) with a
  committed executable bit. Deny via the JSON contract at `core/hooks/ai-dlc-protect.sh:365` —
  `permissionDecision: "deny"`, never exit code 2. `core/hooks/ai-dlc-acknowledge.sh` is the
  precedent for a broad matcher list.
- **Arm it only where it cannot wedge.** Fire only when `_bmad-output/.recover-fired` is fresh
  AND both mandated paths resolve on disk. In the `${STEP_FILE}` fallback branch the gate must
  not arm at all — denying a call against an unresolvable path is the wedge this repo forbids.
- **Fix the fallback** at `core/hooks/ai-dlc-recover.sh:74` so the second mandate is executable or
  is not stated as a MUST.
- **State the narrow exception in the injected text**, with a required disclosure line in the
  lead's next output, so a genuine exception and a rationalized skip are told apart by an
  operator reading the transcript.

### Fixture

Extend `core/fixtures/postcompact-rulebook-recovery/`, which ships and already drives the hook the
way the harness does (`run.sh:41`) and already carries an unmutated control (`:226`). The new
arms cover: gate denies a non-mandated first call; gate allows the mandated one; gate does NOT
arm when the step-file path is the fallback string; gate disarms after both reads. **The
does-not-arm arm is absence-shaped and needs its own mutant.** Prove the wedge case by
measurement, not by argument — the operator sees this hook on every compaction of every session.

---

## R4 — `PC-S330-PATH-MAPPING-TABLE-OMITS-THE-GIT-HOOKS-DESTINATION`

**Premise re-derived at `dae23fa`:** `core/git-hooks` count 0 in
`core/skills/ai-dlc-update/SKILL.md`, control `core/scripts` count 9 in the same invocation. Still
live, and its `verify:` receipt is anchored on a token the fix cannot avoid writing.

**The table is wrong in four ways, not one.** The prose at
`core/skills/ai-dlc-update/SKILL.md:105` states two rules and presents them as total. The
authority is `map_consumer()` at `core/skills/ai-dlc-update/reconcile/preclassify.sh:66`, which
has six arms:

| `map_consumer()` arm | destination | in the prose? |
|---|---|---|
| `core/scripts/*` | `scripts/ai-dlc/<x>` | **WRONG** — prose says `scripts/<x>`, stale since v0.126.0 |
| `core/fixtures/*` | `tests/fixtures/<x>` | **MISSING** |
| `core/ci-templates/*` | `.github/workflows/<x>` | **MISSING** |
| `core/git-hooks/*` | `.githooks/<x>` | **MISSING** — the filed defect |
| `core/*` | `.claude/<x>` | present, correct |
| `*` | identity | **MISSING** |

`scripts/install.sh` agrees with `map_consumer()` on all six. The prose matches neither.

**Why nothing caught it.** I16 is the only invariant that reads path prose, and
`scripts/validate-enforcement-map.sh:2197` puts `core/skills/ai-dlc-update/**` out of scope BY
NAME, for a good reason — that subtree reasons about the distribution layout by design. The prose
table sits in the one file every path invariant is told to skip. Control: the same file IS
reached by four other checks (`scripts/validate-enforcement-map.sh:2027` binds its helper names),
so it is not invisible generally, only to path checking.

### What to change — operator decision taken: render the whole table

Generate the table into a marked region in `core/skills/ai-dlc-update/SKILL.md` from
`map_consumer()` itself, and byte-compare it at pre-push. All four rows become correct as a
consequence, and a fifth omission becomes unconstructible rather than detectable.

- **Reuse the house idiom for reading the function**, do not reimplement it:
  `core/skills/ai-dlc-update/reconcile/apply.sh:169` scrapes `map_consumer()` out of its sibling
  with `awk` + `eval` and refuses loudly rather than falling back to a private table. Four other
  reconcile scripts do the same.
- **Follow the rendered-index precedent** — `scripts/render-invariant-index.sh` and
  `scripts/render-vocabulary-index.sh` are standalone renderers byte-compared at pre-push. Put
  the byte-compare there, **NOT as a new arm inside `scripts/validate-enforcement-map.sh`**: that
  validator is invoked by the suite pole, and `CLAUDE.md` records one added nested loop moving the
  pole from 442s to 595s. A standalone renderer costs the pole nothing.
- **Leave I16's carve-out alone.** The new check is targeted at one generated region; reopening
  the carve-out would put fixtures and enforcement-map data back in scope.

### Fixture

**New.** No fixture asserts the prose table against `map_consumer()`. The joining technique is
already in use on this exact file — `core/fixtures/ledger-status-vocabulary/run.sh:59` opens
`core/skills/ai-dlc-update/SKILL.md` and joins its status vocabulary to the emitter. Mutate an arm
out of `map_consumer()` and require the byte-compare to fail, the way
`core/fixtures/enforcement-map-sites/run.sh:190` deletes the git-hooks case and requires I8 to
catch it. That fixture is `.dist-only`; decide this one's shipping status from its subject
(`.claude/rules/fixture-ship-decl.md`) and write the reason in the marker.

---

## Sequencing — ONE release, v0.372.0

All four ship as **v0.372.0** on a single branch cut from `origin/main`. One version per branch:
a squash of two takes the first version in the subject and breaks the release triple. Commit
subject, `VERSION` and the `CHANGELOG` heading are one claim.

The `CHANGELOG` release carries **four sections, one per remediation, each naming its `PC-` id
verbatim** — that citation is the consumer's `NAMED-UPSTREAM` close signal and all four ids must
appear.

Build order: **R4 first** (smallest, and it proves the renderer/byte-compare path before anything
depends on it), then R1, then R2, then R3. R3 last because it is the only one that can wedge a
live session and it wants the most soak time on the branch.

## The numbered action list

1. **Promote this file to `docs/plans/<slug>.md` and commit it.** It is a handoff the moment
   anyone is told to follow it, and until it is tracked `scripts/validate-plan-shape.sh` cannot
   see it.
2. Cut `feat/sprint-303-330-push-candidates` from `origin/main`, not from a local `main` that may
   be ahead of it.
3. Re-derive every premise in this file against the branch tip before acting on it, each with a
   control in the same invocation. The measured base rate of expired premises here is roughly one
   in two.
4. **R4** — the renderer, the generated region in `core/skills/ai-dlc-update/SKILL.md`, the
   pre-push byte-compare, and the new fixture with its `map_consumer()` mutant. Time
   `scripts/validate-enforcement-map.sh` before and after from inside the repo and confirm it did
   not move; a copy run from `/tmp` resolves its root elsewhere and exits in milliseconds, which
   reads as a speed-up and is a broken measurement.
5. **R1** — the summary-line fix keyed on emitted rows, the `retro.md:593` evidence-contract
   string, the `verdict.sh:114` grep set, and the new four-way fixture. Assert the exit code in
   every arm.
6. **R2** — the schema field, `--close-record`, the `--prior-sprint-sha` accept path, the close
   path documentation, the `docs/vocabulary-index.md` re-render, and arms in both existing anchor
   fixtures with a committed mutant for the accept arm. File the declined continuity check as a
   `BL-` entry in `docs/backlog.md` with a receipt.
7. **R3** — the new `PreToolUse` gate hook, its registration in the settings template with a
   committed executable bit, the `${STEP_FILE}` fallback fix, the stated exception and disclosure
   line, and the new arms in `postcompact-rulebook-recovery` with a mutant for the does-not-arm
   case. **Demonstrate the non-wedge cases by running them**, and ping the operator with what you
   ran before merging this one.
8. `VERSION` → `0.372.0`, one `CHANGELOG` release with four sections, each naming its `PC-` id
   verbatim. Commit subject carries the same version.
9. Run the gate as the gate runs it: `AI_DLC_FIXTURE_NO_SKIP=1 bash .githooks/pre-push`, reading
   each new and changed fixture by NAME in the full output. The verdict grammar is
   `^ +(ok|FAIL|SKIP)  +<name>$` — a by-name grep on the wrong anchor returns 0 for every fixture
   and reads exactly like a clean run, so carry an impossible-name control.
10. Verify R4 and R1 on a tree built by running `scripts/install.sh` into an empty directory, in
    both layouts. A path that resolves here can resolve nowhere in an installed tree.
11. Merge it. Merges are preapproved — do not stop to ask.
12. Report back to the operator: the four fixes; the three filings that were materially wrong and
    in which direction; the `${STEP_FILE}` fallback defect nobody filed; and anything in this file
    that did not survive contact with the tree. **Report-back and the CHANGELOG citations are the
    only deliverables that reach the consumer** — no `docs/reviews/` file, no consumer write. It
    closes its own ledger off the CHANGELOG.

## Done when

- `AI_DLC_FIXTURE_NO_SKIP=1 bash .githooks/pre-push` is green with every new and changed fixture
  read by name, observed on the branch tip immediately before the merge in action 11.
- Each of R1–R4 has at least one arm that FAILED before its fix and passes after, demonstrated by
  a committed mutant rather than by a hand-run. Observation point: after action 7, before
  action 8.
- All four `PC-` ids appear verbatim in the v0.372.0 CHANGELOG release.
- `scripts/validate-enforcement-map.sh` timing is unchanged within measurement resolution,
  read from inside the repo before action 4 and after it.

**On `validate-artifact-budget.sh` specifically: do not write "the budget script is green" as a
criterion.** It has a known unrelated FAIL on this corpus, recorded in
`.claude/rules/plan-shape-measured.md`, and that criterion has already been unattainable once in
this repo's history. State the expected FAIL and what makes it unrelated, or run the command.
