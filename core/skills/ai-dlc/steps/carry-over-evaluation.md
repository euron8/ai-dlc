---
name: carry-over-evaluation
description: Evaluate carry-over backlog, scope items, handle deferrals, then feed into full planning pipeline
nextStepFile: ./discovery.md
---
<!-- STEP_LOADED_TOKEN: carry-over-evaluation -->

# Carry-Over Evaluation

**Purpose:** Evaluate carry-over backlog items, close invalid ones,
handle deferrals, then feed valid items into the full planning pipeline
(discovery → research-requirements → architecture → stories). Carry-over
items get the same planning rigor as new features.

## EXECUTION SEQUENCE

### 0. Exploration dispatch (Rule 24)

If `planning_offload: on` (default), do NOT run sections 1–2 (and 1a)
inline. Spawn an `analyst` subagent (Agent tool, bound to the analyst role file `.claude/team-roles/analyst.md` per SKILL.md Rule 19 — both bindings: `model` and the standing role-contract Read line)
scoped to those reading sections — it loads the backlog/brief/PRD and
audit anchor, evaluates each item, and writes a draft evaluation to
`_bmad-output/planning-artifacts/s<N>-carry-over-evaluation.md` (Rule 24
sprint stamp: `<N>` is `sprint_id` from the pipeline snapshot's Sprint
Context, resolved at `route.md` Step 6 — never the unstamped path, which
would destroy the prior sprint's evaluation), returning
only `{artifact_path, summary, gaps}`. Then resume at section 3.
**Join it, and section 3's party seats, on their DELIVERABLES** — one
`scripts/ai-dlc/wait-for-deliverable.sh <path> [<path> ...]` call per wave
(`_gate-procedures.md`, "Bounded-join beat"). A hand-rolled `until`/`sleep` wait is
a Rule 29 Check A violation; gate Check 25 counts it.
**Sections 3 onward stay inline in the lead** — section 3 is party mode
(Rule 20, never offloaded) and sections 4–6 mutate escalations and the
backlog. If `planning_offload: off`, run all sections inline. Per
SKILL.md Rule 24.

### 1. Context Loading

Read in full (the live current-state files only — this evaluation is
cross-cutting, so per Rule 25(b) it reads whole and relies on those
files staying bounded; do NOT read the `*-history.md` / `*-archive.md`
files):
- `_bmad-output/planning-artifacts/carry-over-backlog.md`
- `docs/architecture.md`
- `_bmad-output/planning-artifacts/product-brief.md`
- `_bmad-output/planning-artifacts/prd.md`
- Project memory files for user preferences and prior decisions

### 1a. Read Audit Anchor

Read `_bmad-output/audit-anchors.md`. Locate the entry for the prior
sprint (current sprint number minus one). Resolve the `sha` field as
`<prior_sprint_sha>` for downstream per-class test-debt audit
(`gate-validation.md` Check 18). If no entry exists for prior sprint,
file HARD_BLOCK at carry-over-evaluation gate — silent skip is
forbidden.

**Backlog health check.** Before per-item evaluation, count OPEN
items and flag any older than 10 sprints. When OPEN count exceeds 15,
prioritize triage as a sprint deliverable.

### 2. Item Evaluation

For each OPEN item in the backlog, evaluate:
1. **Still valid?** Has it been superseded? Has affected code changed?
2. **Effort and complexity?** Single story or multiple?
3. **Dependencies?** On other backlog items?
4. **Option check (Rule 13):** Does this item list multiple implementation
   options or scope levels? If YES:
   - Evaluate options using project context and user preferences
   - Select the best option
   - Document as `DECIDED_AUTONOMOUSLY` with rationale
5. **Defect check (routing backstop).** Is this item a production defect —
   the system behaving contrary to intent (a failure, a misreport,
   wrong/stale values, a regression), whatever words the entry uses and
   however the operator dispositioned it? A defect folded into uniform
   feature-planning skips the repro-first triage the `bug` pipeline exists to
   give it. If YES:
   - Before a fix story is shaped, the evaluation MUST reproduce the defect
     and run the **Falsification ladder** (`bug-investigation.md` §2): for
     each layer the defect could originate from, document with live evidence
     why it IS or IS NOT the root cause. A "likely cause" that rules out no
     other layer is insufficient — a self-consistent plan on an unverified
     premise passes every downstream gate.
   - If the defect is the sprint's dominant work rather than one item among
     features, STOP and escalate to re-route (raise the pause flag): the
     pipeline MUST run the `bug` variant, not carry-over. Do not
     plan a fix on an unverified hypothesis.

**Process-exercise scoping.** For any item classified as a
process exercise, the evaluation MUST define a fail-condition trigger:
the specific observable event that constitutes exercise failure. Items
with no distinct fail condition MUST be reclassified as monitoring
notes embedded in the sprint retro rather than carried as standalone
exercise stories.

### 3. Party Mode Evaluation

`/bmad-party-mode --mode subagent --non-interactive` — PM, Architect, Dev, TEA (bound via the **Rule 20 role-manifest preamble** to their `.claude/team-roles/<role>.md`) evaluate every item:
- Valid or close? If valid, rough story shape?
- Surface any items that have become higher/lower priority
- Surface any that are clearly no longer worth doing

### 3a. Validation cycle (Rule 8)

**This step produces a planning artifact, so Rule 8 binds it like any other.** Run the
minimum cycle that SKILL.md Rule 8's intensity table names for the declared
`validation_intensity` — read the row there; a copy of it here is a copy that drifts.
Whatever the row names, the **Adversarial Review must CONVERGE**: its pass count is a
floor, not a target, and Party Mode dispatches per §3.

- **Review passes:** `_gate-procedures.md`, "Adversarial review dispatch" — ONE `adversary`
  per pass, ai-dlc-native, no Skill.
- **Repair passes:** `_gate-procedures.md`, "Adversarial repair dispatch" — ONE `remediator`
  per pass. **The lead does not repair the artifact itself.**
- The series is `_bmad-output/planning-artifacts/s<N>-coe-adversarial-p<M>.md`; the
  terminating pass stamps `verdict: EXIT_CONDITION_MET`. **Gate Check 24 reads it.**

*Catches:* Rule 8 has always bound this step — it says "per planning artifact," and the
carry-over evaluation is one — but this file never said so, no step here referenced the
repair dispatch, and Check 24's scope list omitted the step. So the cycle ran with the LEAD
repairing its own artifact (the most context-saturated agent, which is the exact failure the
remediator role was created to end), and no gate ever read the verdict. An unbounded
convergence loop adjudicated by nobody reads exactly like a loop that converged. The scope
list is DERIVED, never hand-maintained — see I11 in `validate-enforcement-map.sh`.
*Removed when:* Rule 8 stops binding this step.

### 4. Deferral Handling

If the agent determines any item should be DEFERRED (not implemented
this sprint, not closed):
- Write a `DEFERRAL_REQUEST` entry to `docs/escalations/pending.md`
- Include: which item, why deferral is recommended, impact of deferral
- **Proceed with all non-deferred items** — do not block the pipeline
- The human will review deferrals at the production validation checkpoint

### 4a. Recurrence-Promotes-Priority

Any OPEN carry-over item whose underlying defect has **reproduced in a
later sprint** MUST be auto-promoted: it MUST be scheduled into the NEXT
sprint's plan and MUST NOT be silently re-deferred. Re-deferral of a
recurring item is permitted only with an explicit operator override
recorded in that sprint's retro. The trigger is **recurrence, not age** —
each OPEN carry-over item MUST be cross-checked against the current
sprint's incident/defect log, and any match (a prior incident's signature
reproducing) promotes the item, flagged with the recurrence evidence
(both occurrence dates and the shared signature). Catches: a known defect
carried indefinitely because each sprint judged it in isolation and never
noticed it had already recurred. False-positive cost: one cross-check of
the OPEN items against the current sprint's incident/defect log, plus one
override line at retro when promotion is genuinely not warranted. Remove
when: the carry-over backlog and incident/defect log are unified so
recurrence auto-links without a manual cross-check.

### 5. Close Invalid Items

For items the team agrees to close:
- Document closure reason in `carry-over-backlog.md`
  (append status: CLOSED - [reason])

### 6. Update Backlog

Update `carry-over-backlog.md`:
- Mark items proceeding to planning as IN SPRINT
- Mark closed items as CLOSED with reason
- Mark deferred items as DEFERRAL_REQUESTED

### 7. Proceed to Full Planning Pipeline

Valid carry-over items now enter the same planning pipeline as new
features. Do NOT create stories here — that happens in
stories-test-strategy after the full planning cycle.

The discovery step will:
- Update the product brief with carry-over scope
- Extract LOCKED_REQUIREMENTS from carry-over items

The research-requirements step will:
- Update the PRD with carry-over requirements

The architecture step will:
- Assess architecture impact of carry-over items

The stories-test-strategy step will:
- Create stories from the updated planning artifacts
- Run the full validation cycle on stories

Every new item filed MUST include `**Status:** OPEN` at minimum.
Item IDs MUST use `CO-S<sprint>-<descriptor>` format.

Run gate validation [planning] (`gate-validation.md`), then:
**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/discovery.md`
