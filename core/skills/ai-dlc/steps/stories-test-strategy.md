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
have everything needed for stories. Fix all gaps directly in the source
artifacts.

### Protected-Path Story Tag

Stories that modify files in the protected-path catalog MUST be
tagged for lead-only execution. Three story-frontmatter fields
gate this behavior:

- `protected_paths: [<path-glob-list>]` — list of paths the story
  edits that are in the protected-path catalog.
- `lead_only: true` — when set, lead MUST execute the story itself
  (no Agent/Task delegation to dev teammate). Lead may invoke
  validation sub-skills via Skill tool per Rule 20.
- `single_dev_serialized: true` — when set, lead orchestration
  MUST NOT spawn parallel dev teammates that touch the same
  protected file.

**Protected-path catalog** (default; consumers extend via
`CLAUDE.md` or a project-local override):

- `.claude/skills/ai-dlc/SKILL.md`
- `.claude/skills/ai-dlc/steps/*.md`
- `.claude/team-roles/*.md`
- `CLAUDE.md`
- `docs/coding-conventions.md`

When a story file's `protected_paths` field intersects this
catalog, both `lead_only: true` and `single_dev_serialized: true`
are MANDATORY. `implementation.md` enforces these tags at
parallel-dispatch time.

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

**(a) Framework-import inspection.** For every test framework
prescribed in story ACs (pytest, vitest, playwright, etc.), verify
the framework is actually imported/configured in the codebase. Run
a grep for the import statement. Missing framework = story AC is
unimplementable as written → fix the AC or add a setup story.

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
stories with clear acceptance criteria.

- For **feature**: create stories for the new feature ONLY. Include
  migration/refactoring stories if architecture needs changes.
- For **brownfield-a**: create stories for REMAINING work only. Do not
  create stories for already-completed features unless flagged for rework.
- For **carry-over**: create stories from the carry-over items that
  passed evaluation. The carry-over-evaluation step scoped and validated
  the items; this step creates the actual story files with full ACs.
- Order dependencies explicitly. Reference existing stories by ID.

### 2a. Propagate Locked Requirements to Stories (Rule 13)

For each story created, propagate the relevant locked requirements from
the PRD's `LOCKED_REQUIREMENTS` block into the story file. Each story
gets its own `LOCKED_REQUIREMENTS` block containing only the requirements
that story is responsible for delivering. The story block must also
include:
- Source reference (carry-over item #, user input quote, escalation spec)
- Which PRD requirement(s) this story satisfies

Stories that do not trace back to a locked requirement (e.g., pure
technical stories, migration stories) do not need the block.

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

**Execute all sub-skills back-to-back without pausing for human input
between them:**

1. `/bmad-party-mode` — SM, Dev, Architect, TEA walk through EVERY story.
   Every acceptance criterion, every edge case, every dependency.
   Apply all improvements.
   **Requirement fidelity check:** For each story derived from a carry-over
   item or user instruction, verify: does every AC preserve the specific
   details from the source requirement?
   **Run sub-step snapshot update** (see `gate-validation.md` "Sub-step
   snapshot update"). **Then immediately proceed to step 2:**
2. `/bmad-advanced-elicitation` — probe every story's requirements,
   acceptance criteria, and edge cases until zero ambiguity remains.
   Update story files with all findings.
   **Run sub-step snapshot update. Then immediately proceed to step 3:**
3. `/bmad-review-adversarial-general` — 2+ passes on stories. Focus on
   missing acceptance criteria, untestable criteria, scope creep, missing
   NFRs, and over-engineering (Rule 26: ACs demanding mechanism no
   locked requirement needs — propose removals). Apply all fixes.
   **Source fidelity pass:** Verify stories implement what was requested,
   not a different or lower-effort alternative.
   **Run sub-step snapshot update after each adversarial pass.**
   **Then run auto-handoff evaluation** (see `gate-validation.md`
   "Auto-handoff evaluation") at `Seam D` with the label
   `stories-test-strategy adversarial pass <N>`. If evaluation
   returns FIRE, the session ends; otherwise continue.
   **When the final pass produces only nitpicks, immediately proceed to step 4:**
4. Append a changelog to each story file.
   **Then immediately proceed to Test Strategy:**

### 5. Test Strategy

**Intensity gate for carry-over-single.** When
`validation_intensity == carry-over-single`, skip `/bmad-agent-tea-tea`
(step 1 below) and derive the test strategy directly from the story
acceptance criteria. Test strategy for ≤2 already-scoped stories is
covered by the story validation cycle; the TEA sub-skill adds overhead
without value. Still run the step-3 adversarial review on the derived
strategy. Steps 2–3 below otherwise proceed.

**Execute back-to-back without pausing:**

1. `/bmad-agent-tea-tea` then select test strategy — risk-based test
   strategy for the sprint
2. Tea quality gates — define quality gates and release criteria
3. `/bmad-review-adversarial-general` — review test strategy. Apply fixes.
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
  `gate-validation.md` "Auto-handoff evaluation"). If evaluation
  returns CONTINUE, run gate validation (`gate-validation.md`),
  then:
  **READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/ui-direction.md`

- If **no new visual surfaces**: set `is_ui_epic = false`
  Run auto-handoff evaluation at `Seam B` with the label
  `stories-test-strategy end-of-step pre-gate (no-UI)` (see
  `gate-validation.md` "Auto-handoff evaluation"). If evaluation
  returns CONTINUE, run gate validation (`gate-validation.md`),
  then:
  **READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/implementation.md`
