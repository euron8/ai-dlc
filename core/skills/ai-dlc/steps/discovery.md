---
name: discovery
description: Brainstorm + product brief + validation cycle
nextStepFile: ./research-requirements.md
---
<!-- STEP_LOADED_TOKEN: discovery -->

# Discovery (Phase 1)

**Purpose:** CIS ideation and product brief creation with full validation
cycle. For feature/brownfield variants, this updates existing artifacts
rather than creating from scratch.

## EXECUTION SEQUENCE

### 0. Exploration dispatch (Rule 24)

If `planning_offload: on` (default), do NOT run section 1 inline. Spawn
an `analyst` subagent (Agent tool, bound to the analyst role file `.claude/team-roles/analyst.md` per SKILL.md Rule 19 — both bindings: `model` and the standing role-contract Read line) scoped to section 1
— it reads the input artifacts and any codebase context the brief
needs and writes a context digest to
`_bmad-output/planning-artifacts/s<N>-discovery-context.md` (Rule 24
sprint stamp: `<N>` is `sprint_id` from the pipeline snapshot's Sprint
Context, resolved at `route.md` Step 6), returning only
`{artifact_path, summary, gaps}`. Then resume at section 2.
**Join it with the bounded-join beat** (`_gate-procedures.md`, "Bounded-join beat"):
`scripts/ai-dlc/wait-for-deliverable.sh <artifact_path>`. A hand-rolled `until`/`sleep` wait
is a Rule 29 Check A violation and gate Check 25 counts it.
**Brainstorm and brief AUTHORING stay inline in the lead** — they need
whole-document intent. **The Rule 8 validation cycle is not one thing:**
its REVIEW passes dispatch (adversary, Rule 20) and its REPAIR passes
dispatch (remediator, `_gate-procedures.md` "Adversarial repair
dispatch"). The lead keeps orchestration — dispatch, the join, and the
Rule 11/13 scope calls. If `planning_offload: off`, run all sections
inline. Per SKILL.md Rule 24.

### 1. Context Loading

Read existing artifacts if they exist:
- `_bmad-output/planning-artifacts/product-brief.md`
- `_bmad-output/planning-artifacts/codebase-analysis.md` (brownfield)
- `_bmad-output/planning-artifacts/brownfield-inventory.md` (brownfield-a)
- `_bmad-output/planning-artifacts/doc-reconciliation.md` (brownfield-c)
- Project memory files in user's memory directory

### 1a. Prior-Decision Search (settled-decision corpus)

For any sprint whose scope touches a named subsystem or component, the
lead MUST grep the SETTLED-decision corpus — resolved and settled prior
decisions, not only currently-open items — and cite the result as
discovery evidence:
- `docs/escalations/pending.md`, **including** entries carrying a
  `RESOLVED` or `DECIDED_AUTONOMOUSLY` terminal marker — a search
  filtered to only OPEN entries misses settled answers
- `docs/adr/` (Architecture Decision Records) and
  `docs/retro/sprint-*.md` for prior decisions on the same subsystem

If the project keeps no such files, the corpus is the
archived-escalation / ADR / retro corpus wherever it lives; the search
is still required and a zero-hit pass still shows its command.

The discovery output MUST cite the literal grep command(s) run, the hit
count, and a one-line disposition per hit (`superseded` /
`still binding` / `not relevant`). A subsystem-keyword grep returning
zero hits is a valid pass ONLY if the grep command itself is shown. A
discovery that does not cite the prior-decision search → discovery gate
FAILS. Any prior decision dispositioned `still binding` — a premise
already refuted, a code path already specified — MUST be carried into
the requirements as an explicit constraint.

**Minimum mechanism (Rule 26(c)).** Failure caught: a sprint silently
re-derives or overturns a settled decision because discovery searched
only open items and never checked the resolved/settled corpus. False-
positive cost: a keyword hit that turns out `superseded` or
`not relevant` costs one disposition line — cheap. Removal condition:
drop this gate once binding prior decisions are surfaced to discovery
automatically (e.g. an index that injects them into the brief), making
the manual grep redundant.

### 2. Option Check (Rule 13)

Scan the user's feature description and any referenced carry-over items
for multiple implementation options or scope levels (e.g., "A: X, B: Y,
C: Z"). If any item presents options:
- Evaluate options using project context, user preference history, and
  technical feasibility
- Select the best option and document as `DECIDED_AUTONOMOUSLY` in
  `docs/escalations/pending.md`
- If options represent fundamentally different features (not just
  implementation approaches), seek clarity from the user per Rule 11

### 3. Brainstorm

**Intensity gate.** If `validation_intensity == carry-over-single`:
skip this step. Carry-over items are already scoped. Proceed to
Step 4.

Invoke `/bmad-brainstorming` — structured CIS ideation:
- For **greenfield**: open ideation for the user's idea
- For **feature**: scoped ideation constrained by existing architecture
- For **brownfield**: ideation grounded in codebase analysis
- Every idea must be feasible within the existing system or explicitly
  flag what would need to change

### 4. Product Brief

- For **greenfield/brownfield-b**: invoke `/bmad-create-product-brief`
- For **feature/brownfield-a/c**: UPDATE the existing brief per Rule
  25(a) — integrate the new scope into the current-state sections and
  **move** superseded content and prior per-sprint narrative to
  `product-brief-history.md` (cut-and-paste, verbatim). Never drop
  content: the union of live and history must preserve everything prior.

### 4a. Extract Locked Requirements (Rule 13)

After the brief is created/updated, extract all user-specified requirements
into a `LOCKED_REQUIREMENTS` block at the top of the artifact:

```markdown
<!-- LOCKED_REQUIREMENTS — DO NOT MODIFY DURING VALIDATION -->
<!-- Source: [user input | carry-over item #N | escalation spec path] -->
- [verbatim user-specified requirement 1]
- [verbatim user-specified requirement 2]
<!-- END LOCKED_REQUIREMENTS -->
```

Sources to extract from:
- The user's original input to `/ai-dlc`
- Any carry-over items referenced by the user
- Any escalation specs or feature docs referenced by the user
- Project memory entries about user preferences that constrain this feature

Be exhaustive. Every concrete detail the user specified (placement, scope,
behavior, approach) is a locked requirement. Do not paraphrase — quote
verbatim or as close to verbatim as the source allows.

### 5. Validation Cycle (Rule 8)

Run the validation cycle (`_gate-procedures.md`, "Validation cycle") on the
product brief — its passes use the **Adversarial review dispatch** and
**Adversarial repair dispatch** sub-routines. Parameters:
- **party-mode seats / subject:** PM, Architect, UX, CIS — walk every element of
  the brief.
- **source-fidelity check:** where features originate from carry-over items or
  user instructions with specific details, verify those details are preserved and
  flag any generalization.
- **adversarial focus:** none beyond the adversary's default contract.
- **`Seam D` label:** `discovery adversarial pass <N>`.
- **on convergence:** append a changelog to the brief summarizing improvements,
  then proceed to gate validation.

### 6. Gate Validation and Proceed

Run auto-handoff evaluation at `Seam B` with the label
`discovery end-of-step pre-gate` (see `_gate-procedures.md`
\"Auto-handoff evaluation\"). If evaluation returns CONTINUE, run
gate validation [planning] (`gate-validation.md`), then:
**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/research-requirements.md`
