---
name: stories-test-strategy
description: Readiness check + epics/stories + sprint planning + test strategy + validation
nextStepFile_ui: ./ui-direction.md
nextStepFile_no_ui: ./implementation.md
---
<!-- STEP_LOADED_TOKEN: stories-test-strategy -->

# Stories and Test Strategy (Phase 2d-f)

**Purpose:** Implementation readiness, story creation, sprint planning,
and test strategy with full validation cycle.

## EXECUTION SEQUENCE

### 1. Implementation Readiness

Invoke `/bmad-check-implementation-readiness` — validate PRD + architecture
have everything needed for stories. Dispatch the `pm` (PRD gaps) and the
`architect` (architecture gaps), role-bound per Rule 19, to fix them directly
in the source artifacts. The lead owns the routing, not the edit.

### Story Routing Tags

A story's frontmatter MAY carry a **routing tag** that changes WHICH role
the lead binds when it dispatches the story, overriding the default `dev`.
This is the sanctioned way to give a story a different contract or a
different model tier: model is a property of the role file, not of the
dispatch call site (SKILL.md Rule 19; the dispatch guard binds the model
from the role file and rebinds any call-site override back to it), so
"this story needs a different role/model" is always expressed as "route
this story to a different role file."

**Routing map (canonical — `implementation.md` binds from it at dispatch,
gate-validation Check 22 re-derives from it at retro; add a row here, in
ONE place, to add a route):**

| Frontmatter flag           | Routed role file                        | Why |
|----------------------------|-----------------------------------------|-----|
| `protected_path_editor: true` | `.claude/team-roles/protected-path-editor.md` | Editing the rulebook/governance surface needs the strictest change discipline and lead-reviewed diffs. |
| `escalate_model: true`     | `.claude/team-roles/dev-escalated.md`   | The standard Dev contract on a stronger (opus-tier) model, for work that needs architectural judgment, cross-layer analysis, or an open-ended implementation approach. |

Absent any routing tag, a story is dispatched to `dev` as usual.

**Protected-path editing** additionally uses these frontmatter fields:

- `protected_paths: [<path-glob-list>]` — list of paths the story
  edits that are in the protected-path catalog.
- `protected_path_editor: true` — routes per the map above. The
  `protected-path-editor` returns a review-ready diff the lead reviews
  before merge. The lead does NOT execute the story inline (Rule 28:
  protected-path editing is delegable) and does NOT delegate it to a dev
  teammate. Lead may invoke validation sub-skills via Skill tool per
  Rule 20.
- `single_dev_serialized: true` — when set, lead orchestration
  MUST NOT spawn parallel teammates that touch the same
  protected file; protected-path stories are dispatched one at a time.

**Model escalation** uses one frontmatter field:

- `escalate_model: true` — routes per the map above to `dev-escalated`
  instead of `dev`. That role reads and follows `dev.md` in full — same
  ownership boundaries and constraints — and differs ONLY in the model key
  it names. Use it for a story whose difficulty warrants the escalated
  route; a well-scoped story with a precise checklist stays on `dev`. What
  the route resolves to is operator config; do not evaluate it. The tag is
  authored with the story (by PM/architect), not chosen at dispatch, so
  the routing is auditable from the persisted story file.

**Protected-path catalog** (default; consumers extend via
`CLAUDE.md` or a project-local override):

- `.claude/skills/ai-dlc/SKILL.md`
- `.claude/skills/ai-dlc/steps/*.md`
- `.claude/team-roles/*.md`
- `CLAUDE.md`
- `docs/coding-conventions.md`

When a story file's `protected_paths` field intersects this
catalog, both `protected_path_editor: true` and
`single_dev_serialized: true` are MANDATORY. `implementation.md`
enforces every routing tag at dispatch time; gate-validation Check 22
re-derives the expected route from each story's persisted frontmatter
and verifies the story was serviced by the routed role (a
`protected-path-editor` spawn for `protected_path_editor: true`, a
`dev-escalated` spawn for `escalate_model: true`).

### Discriminating-AC Authoring Standard

The `code-reviewer.md` "Self-Discrimination Map" and gate-validation
Check 19 enforce discrimination for PRs that flip a CI gate or add a
detector. This standard extends the same discipline to every story's
unit and integration fixtures at authoring time: an AC that stays
green under an implementation which does not actually meet the
requirement is non-discriminating and MUST NOT be accepted.

**UNIVERSAL / EXISTENTIAL tagging.** Every acceptance criterion MUST
be tagged UNIVERSAL or EXISTENTIAL in its parenthetical; an untagged
AC defaults to EXISTENTIAL.

- **UNIVERSAL** — the property MUST hold for ALL instances of a set
  (every endpoint, every element, every call site). Verification
  requires exhaustive enumeration or a for-each assertion, AND a
  discriminating-failure fixture: a test that FAILS if the property is
  violated for any single instance. The fixture proves the assertion
  is load-bearing, not tautological.
- **EXISTENTIAL** — verification requires at least ONE instance
  exhibiting the behavior; a single witness suffices.

**LR→AC discriminating coverage (MANDATORY).** Every
`LOCKED_REQUIREMENT` (Rule 13) propagated into a story MUST map to ≥1
acceptance criterion whose test transitions PASS→FAIL when the
requirement's production code is replaced by its
degenerate-but-type-valid implementation — the minimal lawful behavior
that violates the LR while satisfying every type contract and safety
invariant. Record the mapping inline as one `LR→AC` line per locked
requirement, naming the degenerate implementation each mapped AC reds
against. An LR whose only ACs assert invariants that the degenerate
implementation also passes is NOT covered; an unmapped LR, or an LR
covered only by degenerate-passing ACs, fails gate-validation Check 3a.
For any AC guarding a bound, limit, or ceiling, the AC MUST assert the
bound in the protective direction — the side that constrains the risk —
NOT merely the absence of the known failure mode; an AC satisfied by a
wrong-side bound is non-discriminating and fails Check 3a.

**Cardinality-fixture sub-mandate.** Any AC asserting per-element
behavior ("per element", "per item", "per call") MUST run on a fixture
where the element count N≥2 and the elements differ in an observed
value, and MUST assert `mock.call_count` / `call_args_list` /
per-element arguments. A source-string presence check
(e.g. `assertIn("method_name", body)`) MUST NOT satisfy a per-element
AC — it passes on a single call and on a hardcoded string, so it
discriminates neither element count nor per-element values.

**Minimum-mechanism contract (Rule 26c).** This standard catches
tautological ACs that assert type-shape or symbol presence instead of
required behavior and so stay green under an implementation that does
not meet the requirement. False-positive cost is bounded: a
genuinely-covered LR flagged for a missing `LR→AC` line costs one
authoring line; a genuinely-exhaustive assertion flagged as
non-discriminating costs one fixture. Remove this standard if a static
analyzer proves per-test discrimination automatically, or if Check 19
is extended to cover every story's unit/integration fixtures.

**AC header form.** `/bmad-create-epics-and-stories` emits acceptance criteria as
unnumbered Given/When/Then blocks under a bold `**Acceptance Criteria:**` label,
carrying no `AC` token at all. Those are INPUT. When a story file is created,
re-author each block as a numbered acceptance criterion in the form below, carrying
its UNIVERSAL/EXISTENTIAL tag and its layer. A story file that keeps the raw
Given/When/Then form fails Check 31 as DISARMED — an AC the checker cannot read is
not an AC that passed, and Check 31 will not silently score it clean.

Every acceptance criterion MUST open with a header of
the form `- **AC<n> (<tags>).**` or `- **AC<n> — <title>.**`, where `<n>` is
a decimal ordinal optionally suffixed with one lowercase letter (`AC1`,
`AC4a`). One AC per header. The header carries the AC; every following
line up to the next AC header or the next markdown heading belongs to it.

A single declared form is what lets Check 31 read acceptance criteria
without guessing. A story that declares acceptance criteria and presents
none in this form FAILS Check 31 as DISARMED — an AC the checker cannot
read is not an AC that passed.

**Falsifiable-predicate mandate.** An acceptance criterion MUST NOT state
its verification predicate with a qualifier that names no bounded set.
The terms below are FORBIDDEN in acceptance-criterion text — each names a
standard no verifier can fail, so an AC carrying one is green on sight:

<!-- AC_UNBOUNDED_TERMS v1 -->
exhaustive, exhaustively, comprehensive, comprehensively, definitively,
thoroughly, adequately, sufficiently, appropriately, robustly,
as needed, as appropriate, where appropriate, all relevant, if necessary
<!-- AC_UNBOUNDED_TERMS_END -->

Replace the term with the set it stands for: the enumerated members,
their count, and an assertion that the OBSERVED set EQUALS that
enumeration. Two constructions do NOT satisfy this mandate: a set the AC
describes but does not list, and a count the AC states but does not tie
to named members.

An AC whose set cannot be enumerated at authoring time carries
`falsifiability_waiver: <what is unbounded, and why it cannot be
enumerated>` on its own line inside that AC. Check 31 prints every
waiver it reads; a waiver suppresses the FAIL, never the report.

Run `scripts/ai-dlc/validate-ac-falsifiability.sh <story-file>` at
authoring time — it is the same enforcer Check 31 runs, and a term
rewritten here costs one word where the same term costs a story gate.

**Prior-evidence citation.** An AC that consumes a value, fixture,
baseline, or measurement produced BEFORE this story MUST cite it as
`prior_evidence: <repo-relative-path>[:<anchor>]`. Naming the producing
story, sprint, or measurement in prose is NOT a citation: prose names a
claim, a path names a retrievable artifact.

**Minimum-mechanism contract (Rule 26c).** This mandate catches an AC
whose predicate has no failing case, so the gate reading it records PASS
for a verification never performed, and an AC citing prior evidence that
is not retrievable at verification time. False-positive cost: an AC using
a forbidden term over a set it does enumerate costs one word rewritten; a
`prior_evidence:` typo costs one path correction. Remove this mandate when
Check 3a's adjudicator is required to construct and record a concrete
failing case per AC, which subsumes both halves.

### Layered AC Verification Accounting

Story acceptance criteria MUST be verifiable at exactly one
verification layer. Layer enum (story-frontmatter optional field
`layered_ac_count` records counts per layer):

- `unit` — function-scope test, no I/O, mocks for deps.
- `integration` — multi-component test, real local deps, no
  network beyond fixtures.
- `e2e` — full-stack against deployed dev environment.
- `live_ops` — verifies live production system state via
  read-only API/SSM/dashboard observation; mutations require
  operator approval per CLAUDE.md operations protocol.
- `manual_operator` — requires human action (operator-executed
  runbook step, deploy verification, visual inspection).

For every story, sum `layered_ac_count` values MUST equal
`acceptance_criteria` count. The `gate-validation.md` Check 11
"Smoke test coverage" reads layer tags to verify test type
matches change type — layered AC tags feed Check 11 evidence.

**Intensity gate for carry-over-single.** When
`validation_intensity == carry-over-single`, skip `/bmad-create-epics-and-stories`
and create stories directly from carry-over items. The carry-over-evaluation
step already scoped and validated items; the epics/stories sub-skill adds
overhead without value for ≤2 stories.

### Story-Authoring Pre-Flight Checklist

Before creating any story file, verify:

**(a) Framework-import inspection.** For every test framework prescribed in
story ACs, the framework's presence in the codebase MUST be verified before
the AC is written. Dispatch an `analyst` (role-bound per Rule 19) to grep for
each framework's import/config and return a `{framework: present|absent}`
map; the lead consumes the map when authoring/fixing ACs. Absent framework =
AC unimplementable as written → fix the AC or add a setup story.

**(b) Role-file/step-file existence verification.** For every
`.claude/team-roles/<role>.md` and `.claude/skills/ai-dlc/steps/<step>.md`
referenced in story dispatch plans, verify the file exists on disk.
Missing role/step file = dispatch will fail silently.

### Story-AC Out-of-Scope Declaration Rule

When a Day-0 survey enumerates more targets than the selected lane
covers, the story MUST include an explicit out-of-scope-declaration
AC naming uncovered targets verbatim. This prevents surprise gaps at
gate review where the reviewer discovers that "all targets handled"
was never an AC — it was an assumption. The out-of-scope AC is
verified at gate by confirming the named targets were not modified.

### AC Precision for Smoke Checks

Smoke-test ACs MUST use the phrasing "Check N MUST produce PASS"
rather than "zero SKIPs on Check N." SKIP is a legitimate status
for checks that do not apply to the current gate phase. Conflating
SKIP with FAIL produces false gate failures. The gate log records
PASS/FAIL/SKIP per check; the AC must target PASS specifically.

### 2. Epics and Stories

Invoke `/bmad-create-epics-and-stories` — break work into prioritized
stories with clear acceptance criteria. Four things MUST be supplied explicitly;
none of them can be left to the skill's own resolution:

- **The PRD path, named.** Its discovery globs are `{planning_artifacts}/*prd*.md`
  and `{planning_artifacts}/*prd*/index.md` — non-recursive, with no
  disambiguation rule when more than one matches. The per-sprint working files
  that used to collide with it now sit under `s<N>/`, out of a non-recursive
  glob's reach, but the durable area root still holds several PRD-named files
  (`prd.md`, `prd-history.md`, `review-consolidation-prd.md`, …) and the skill
  would still pick among them arbitrarily. Name the file.
- **A sprint-scoped output path.** Its default is a single fixed
  `{planning_artifacts}/epics.md`, and no step checks whether that file exists.
  Writing there overwrites the previous sprint's epics silently. Direct it to
  `{planning_artifacts}/s<N>/epics/epics.md`.
- **The spec package and the architecture spine, by path.** Its step 1 lists
  `architecture.md` as a required prerequisite and mines it for additional
  requirements; `SPEC.md` and the spine appear in none of its search patterns, so a
  project carrying a spec layer cannot satisfy that prerequisite as written.
- **A facilitator, not a fire-and-forget dispatch.** Every one of its step files
  opens with "NEVER generate content without user input" and "YOU ARE A
  FACILITATOR, not a content generator", and it halts at nine interactive menus. It
  has no headless mode and no flag that relaxes this. The lead drives it and answers
  its gates; do NOT dispatch it and walk away expecting a finished artifact. This is
  the opposite of `bmad-spec`, whose default invocation IS headless.

**Its `FR Coverage Map` is NOT a traceability surface.** The strings `CAP` and
`LR-` appear NOWHERE in that skill — not in `SKILL.md`, not in `customize.toml`,
not in either template, not in any step file. Its instructed output is literally
`FR1: Epic 1 - [Brief description]`, which drops both the capability and the
locked-requirement linkage. Whether a run preserves richer FR labels is the
author's discretion, not the skill's behaviour. Never build a check on that map:
gate-validation Check 30 reads the capability citation off `prd.md`'s own FR
entries, which ai-dlc authors and can therefore mandate.

- For **feature**: create stories for the new feature ONLY. Include
  migration/refactoring stories if architecture needs changes.
- For **brownfield-a**: create stories for REMAINING work only. Do not
  create stories for already-completed features unless flagged for rework.
- For **carry-over**: create stories from the carry-over items that
  passed evaluation. The carry-over-evaluation step scoped and validated
  the items; this step creates the actual story files with full ACs.
- Order dependencies explicitly. Reference existing stories by ID.

### 2a. Propagate Locked Requirements to Stories (Rule 13)

**Every story MUST carry a `capabilities:` frontmatter field** listing the
`CAP-<n>` identifiers it delivers, e.g. `capabilities: [CAP-3, CAP-7]`. A capability
inserted without renumbering carries a single lowercase suffix — `CAP-1a` — and is cited
in that exact form.
That field is the only mechanical link from a story to the spec; without it
the story's place in the chain
`LOCKED_REQUIREMENTS → CAP-<n> → FR-<n> → AC → test` is prose.
Gate-validation Check 30 FAILS a story missing the field, and FAILS one
citing a `CAP-<n>` that `SPEC.md` does not define — capability IDs are never
renumbered, so a dangling reference is a typo or a stale copy, never a
renumbering.

**A story that genuinely delivers no capability declares that, rather than
leaving the field blank.** `capabilities: []` on its own is an unexplained
claim about the chain, and Check 30 FAILS it as one — distinctly from a story
that carries no field at all, because those are different defects with
different remedies. Say why instead:

```
capabilities: []
capabilities_rationale: pipeline-infra only; implements no spec capability
```

That is a declared disposition, recorded in the gate log as a note. It is the
same shape as Check 33's `NOT-IN-SCOPE` line: an explicit, visible, per-item
disposition, which beats a blank nobody has to account for.

For each story created, propagate the relevant locked requirements from
the PRD's `LOCKED_REQUIREMENTS` block into the story file. Each story
gets its own `LOCKED_REQUIREMENTS` block containing only the requirements
that story is responsible for delivering. The story block must also
include:
- Source reference (carry-over item #, user input quote, escalation spec)
- Which PRD requirement(s) this story satisfies

Stories that do not trace back to a locked requirement (e.g., pure
technical stories, migration stories) do not need the block.

**Full-text claim vs. load pointer (Check 3b).** Inside the block,
distinguish two citation forms — they are NOT interchangeable:
- `full_text_source: <artifact>:<anchor>` — asserts the verbatim
  requirement text lives at this anchor. The artifact MUST be the
  byte-verbatim **source of record** —
  `_bmad-output/planning-artifacts/s<N>/locked-requirements.md`, where §4a
  writes the block — NOT a condensed index. `gate-validation.md`
  Check 3b (`scripts/ai-dlc/validate-locked-anchor.sh`) byte-verifies that
  every bullet in the block is present verbatim at the cited anchor and
  FAILS the gate on a mis-anchored or summarized claim.
- `requires_context: <artifact>#<anchor>` — a dev-time load pointer.
  Honest cite-by-reference; the bullets under it are never byte-matched.
  Use this (not `full_text_source:`) when the block text is an abridged
  restatement and the full text is loaded from the brief at
  implementation time. **The pointer is still resolved**: Check 3b fails
  the gate when the artifact or the anchor is not there. Write an anchor
  that is a LITERAL PRESENT IN THE TARGET (a heading's own text, an
  `LR-` id, or a `<start>-<end>` line range) — a GitHub slug such as
  `#probe-1` matches neither the heading it was derived from nor any
  literal in the file, and is the measured way this dangles.

Do NOT cite a condensed index (e.g. `prd.md`) as `full_text_source`
"for full text" — the PRD's LR entries are §2a-propagated, and
`s<N>/locked-requirements.md` is the byte-verbatim source of record.

**The spec layer does not add an anchor target.** `full_text_source` resolves to
the sprint's `locked-requirements.md` and nothing else. Locked-requirement text
originates there, written by `discovery.md` §4a; the spec is DERIVED from it, so
a spec artifact is a downstream restatement — the same category as `prd.md`,
which is already forbidden here. Cite the spec with `requires_context:` when a
dev needs it loaded.

**A CROSS-SPRINT ANCHOR IS LEGAL, AND THE ANCHOR IS WHAT PICKS THE SLOT.** Rule 13
makes locked requirements cumulative, so a story can honestly cite a requirement
locked in an earlier sprint. Write the anchor as that sprint's id —
`full_text_source: locked-requirements.md:LR-S299-4` from a story in `s302/` — and
Check 3b reads `s299/locked-requirements.md`, **before** the story's own slot, which
would otherwise shadow it by basename. Nothing else changes: the bullet is still
byte-matched against the window the anchor names, so a summarized cross-sprint
propagation fails exactly as a same-sprint one does.

**Prefer re-extracting to citing across sprints.** `discovery.md` §4a extracts from
carry-over items into THIS sprint's block, and `carry-over-evaluation.md` routes them
there, so a carried requirement normally appears verbatim in the current sprint's
file and the citation is local. The cross-sprint form exists because the corpus
already contains cross-sprint `LR-S<n>-` references — **260 of 4019 on the reference
consumer**, against **0 of 62** in anchored citations — so the first one anchored
would otherwise have been rejected for the wrong reason.

**`product-brief.md` is still ACCEPTED and is on its way out.** §4a used to append
each sprint's block to the durable brief, so stories written before that changed
cite it — 31 of 62 anchored citations on the reference consumer, all resolvable and
none defective. `validate-locked-anchor.sh` accepts both names and reports how many
claims are still at the legacy one, so the migration is something a run measures
rather than something an operator estimates. **Write new citations against
`locked-requirements.md`.**

`SPEC.md` is the worst possible anchor: `bmad-spec` is its sole writer and
re-renders it from `.memlog.md` on every run, so an anchor there holds until
the next derive and then either reports a drift that never happened or passes
against reworded text. `validate-locked-anchor.sh` already refuses any
`full_text_source` that is not the source of record, so this needs no new
rule — it is stated here only so nobody adds one.

**Category error to avoid.** Context/tool thresholds (e.g. the ctx
`INTENT_SEARCH_THRESHOLD`, which auto-indexes tool output above ~5KB)
gate what re-enters the **conversation** on an intent-bearing tool
call. They NEVER gate what is written to a file. Never truncate,
summarize, or otherwise shape a story's inlined requirement text to
"stay under" a tooling threshold — the threshold does not apply to
file writes, and the degraded artifact FAILS Check 3b.

### 2b. Propagate Architecture Refs to Stories (Rule 25(b))

For each story created, add an `architecture_refs:` frontmatter field — the
list of `docs/architecture.md` section anchors (or exact heading titles) that
story's implementation and NFR validation need. Populate it here, at authoring
time, where the architecture design is fresh and the touched sections are known
(the party-mode SM+Architect walk in step 4 refines it). This field is the
**slice target** the dev and qa role contracts read instead of whole-reading the
architecture doc (`dev.md`/`qa.md` Context Loading), per Rule 25.

- Each entry is a section anchor/title that exists in `architecture.md` (or its
  regenerated `docs/architecture-index.md`). Verify each referenced section
  exists — a dangling ref sends dev/qa to `architecture-index.md` to relocate,
  or (worst case) back to a whole-read.
- A story that genuinely needs no architecture context (e.g., a doc-only fix)
  sets `architecture_refs: []` explicitly — an empty list is a positive signal,
  not a missing field, and tells dev/qa to skip the architecture read entirely.
- Stories touching cross-cutting NFRs may list the current-state head anchor
  plus the specific NFR section(s).

### 3. Sprint Planning

**Intensity gate for carry-over-single.** When
`validation_intensity == carry-over-single`, skip `/bmad-sprint-planning`
and place all carry-over stories in a single sprint. Carry-over items are
already scoped and ≤2 stories are trivially plannable; the sprint-planning
sub-skill adds overhead without value. Proceed to Story Validation Cycle.

Invoke `/bmad-sprint-planning` — select stories for the sprint.

**Multi-sprint phasing check (Rule 14):** If the total story count exceeds
what can be delivered in a single sprint (typically 3-5 stories), or if
risk assessment suggests phasing:
- Split into multiple sprints autonomously
- Document phasing rationale
- Define phase boundaries ensuring each phase delivers standalone value
- The implementation step will execute sprint 1, deploy, signal human,
  then wait for validation before proceeding to sprint 2

### 4. Story Validation Cycle (Rule 8)

Run the validation cycle (`_gate-procedures.md`, "Validation cycle") on the
sprint's stories — its passes use the **Adversarial review dispatch** and
**Adversarial repair dispatch** sub-routines. Parameters:
- **party-mode seats / subject:** SM, Dev, Architect, TEA — every story: every
  acceptance criterion, every edge case, every dependency.
- **source-fidelity check:** for each story derived from a carry-over item or user
  instruction, verify every AC preserves the specific details from the source.
- **adversarial focus:** missing acceptance criteria, untestable criteria, scope
  creep, missing NFRs, and over-engineering (Rule 26: ACs demanding mechanism no
  locked requirement needs — propose removals).
- **`Seam D` label:** `stories-test-strategy adversarial pass <N>`.
- **on convergence:** append a changelog to each story file, then stamp story
  provenance (below).

   **Stamp the terminal-pass provenance block onto every story — MECHANICALLY,
   never by hand.** Check 17's story-readiness gate requires a
   `SKILL_INVOCATION_PROVENANCE` block on each story file. Do NOT transcribe it
   "per precedent" — that is how it drifted (one sprint carried `artifact_sha`,
   the next did not, each with a different free-text comment). Run:

   `scripts/ai-dlc/stamp-story-provenance.sh --series
   <this-sprint's-stories-adversarial-pass-prefix> <story-file>...`

   It reads the TERMINAL convergence pass (the single source of truth), copies
   every batch-invariant field verbatim, computes each story's `artifact_sha`,
   and writes a schema-conformant block — idempotently. If the terminal pass
   could not self-report its Agent-dispatch `tool_use_id` (the placeholder from
   the self-introspection defect), recover it from the session transcript and
   pass `--tool-use-id <toolu_...>`; the writer backfills the terminal pass too,
   so it is corrected once at the source. You author nothing; the gate's
   `--check` re-derives the same block and fails on any drift.
   **Then immediately proceed to Test Strategy:**

### 5. Test Strategy

**WRITE PATH — `_bmad-output/planning-artifacts/s<N>/test-strategy.md`**, where `<N>`
is `sprint_id` from the pipeline snapshot's Sprint Context (resolved at `route.md`
Step 6). **The stamp is the DIRECTORY, not the basename** (`artifact-path-grammar.md`
rule 2). The sub-skills below are told this path; whatever default they carry is
overridden by it.

**This step once prescribed NO path at all, and the consumer filled the gap for
72 sprints.** The reference consumer's own convention was
`test-strategy-sprint-<N>.md` at the area root — a per-sprint artifact spelling its
sprint in the basename, which rule 2 forbids and which the s<N>/ migration renamed to
`s<N>/test-strategy.md` for s134 through s297. One copy was left at the area root and
its own H1 reads `# S272 Sprint Test Strategy`: one sprint's document standing in as
the durable one, 29 sprints stale, and it is what
`codebase-inventory.md`'s artifact audit and `bug-investigation.md`'s context load
both read. **An unprescribed path is not a wrong path — it is the author choosing,
every sprint, with nothing to be consistent with**, which is the same finding item 23b
made about this pipeline's consolidation byproducts.

**Intensity gate for carry-over-single.** When
`validation_intensity == carry-over-single`, skip `/bmad-testarch-test-design`
(step 1 below) and derive the test strategy directly from the story
acceptance criteria. Test strategy for ≤2 already-scoped stories is
covered by the story validation cycle; the TEA sub-skill adds overhead
without value. Still run the step-2 adversarial review on the derived
strategy. Steps 1a–2 below otherwise proceed.

**Execute back-to-back without pausing:**

1. `/bmad-testarch-test-design` then select test strategy — risk-based test
   strategy for the sprint
1a. `/bmad-testarch-trace` — generate the requirements-to-tests traceability
   matrix and its quality gate decision (PASS / CONCERNS / FAIL / WAIVED).
   This closes the last leg of the chain, `AC → test`, against the same
   `CAP-<n>` IDs the spec and the PRD carry.

   **This run does NOT produce a gate decision, and no `--trace-verdict` is passed
   at this step.** The trace runs here at PLANNING phase, before any story is
   implemented, so collected coverage is 0 by construction — zero tests exist yet
   and every AC is `PLANNED`. The tool answers that by setting `allow_gate=false`
   for the run, recording `decision: NOT_EVALUATED`, and writing no
   `gate-decision.json`. Its own summary states the absence is correct. A zero
   here is not a coverage defect and MUST NOT be read as one.

   What the run DOES produce is the traceability matrix and
   `e2e-trace-summary.json`, which it writes unconditionally. Read the summary's
   `gate` object for the recorded rationale rather than inferring one from the
   missing file.

   **Check 30's `--trace-verdict` leg is therefore DISARMED by construction at
   this gate, not dormant.** It could only carry a real verdict from a trace run
   taken AFTER implementation, when tests exist; the pipeline takes no such run
   today. Do not synthesise `gate-decision.json` to arm it.
2. `/bmad-review-adversarial-general` — review test strategy.
   Repair its findings through the **Adversarial repair dispatch** sub-routine
   (`_gate-procedures.md`) — ONE `remediator` takes the whole finding set and
   applies the edits; the lead owns the disposition, not the edit.
   **ONE-SHOT — the bmad skill is correct here and stays.** Nothing loops, no
   verdict is stamped, no gate counts this residue, so the skill's "find ≥10,
   HALT on zero" contract costs nothing and buys a cynical sweep. Do NOT convert
   this to the native review; the native review exists for cycles that must reach
   zero. Write its findings under a path that does NOT share the stories series'
   `s<N>/stories-adversarial-p` prefix — Check 24 globs that prefix, and a
   verdict-less one-shot swept into the series fails rung A.
   **When done, immediately proceed to Commit Planning Artifacts:**

### 6. Commit Planning Artifacts

Before transitioning to implementation, commit all planning artifacts
so they are captured in version control. This ensures the planning
record is preserved regardless of what happens during implementation.

Stage and commit:
- `_bmad-output/planning-artifacts/` (brief, PRD, architecture, stories,
  sprint-backlog, test-strategy, and any other planning output)
- `docs/escalations/pending.md` (if modified during planning)

Use a conventional commit message:
`docs(planning): sprint N planning artifacts`

Do NOT commit implementation files, source code, or test files — those
are committed per-story by dev teammates during implementation.

### 7. UI Detection and Routing

Scan all sprint stories for new visual surfaces (new UI components, pages,
layout changes):

- If **new visual surfaces found**: set `is_ui_epic = true`
  Run auto-handoff evaluation at `Seam B` with the label
  `stories-test-strategy end-of-step pre-gate (UI)` (see
  `_gate-procedures.md` \"Auto-handoff evaluation\"). If evaluation
  returns CONTINUE, run gate validation [story] (`gate-validation.md`),
  then:
  **READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/ui-direction.md`

- If **no new visual surfaces**: set `is_ui_epic = false`
  Run auto-handoff evaluation at `Seam B` with the label
  `stories-test-strategy end-of-step pre-gate (no-UI)` (see
  `_gate-procedures.md` \"Auto-handoff evaluation\"). If evaluation
  returns CONTINUE, run gate validation [story] (`gate-validation.md`),
  then:
  **READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/implementation.md`
