---
name: requirements
description: Product brief update + spec kernel + PRD + validation cycle, merged (carry-over/feature only)
nextStepFile: ./architecture.md
---
<!-- STEP_LOADED_TOKEN: requirements -->

# Requirements (Phase 1-2)

**Purpose:** This step replaces `discovery.md` plus `research-requirements.md` for the
`carry-over` and `feature` pipeline variants. Those two variants restate an already-named
scope — the operator's request, or the carry-over item — and the decision the two-step form
existed to reach is reached early, so running a brainstorm, a separate brief-only validation
cycle, and a separate PRD-only validation cycle over the same restated scope is three passes
over one decision. Every other variant (`greenfield`, `brownfield-a`, `brownfield-b`,
`brownfield-c`) keeps the `discovery` → `research-requirements` two-step form unchanged; this
step is never loaded for them.

## EXECUTION SEQUENCE

### 0. Exploration Dispatch (Rule 24)

If `planning_offload: on` (default), do NOT run section 1 inline. Spawn an `analyst` subagent
(Agent tool, bound to the analyst role file `.claude/team-roles/analyst.md` per SKILL.md
Rule 19 — both bindings: `model` and the standing role-contract Read line) scoped to section 1
— it reads the input artifacts and any codebase context the brief needs and writes a context
digest to `_bmad-output/planning-artifacts/s<N>/requirements-context.md` (Rule 24 sprint
stamp: `<N>` is `sprint_id` from the pipeline snapshot's Sprint Context, resolved at
`route.md` Step 6), returning only `{artifact_path, summary, gaps}`. Then resume at
section 1.
**Join it with the bounded-join beat** (`_gate-procedures.md`, "Bounded-join beat"):
`scripts/ai-dlc/wait-for-deliverable.sh <artifact_path>`. A hand-rolled `until`/`sleep` wait
is a Rule 29 Check A violation and gate Check 25 counts it.
**Brief, spec, and PRD AUTHORING stay inline in the lead** — they need whole-document intent.
**The Rule 8 validation cycle is not one thing:** its REVIEW passes dispatch (adversary,
Rule 20) and its REPAIR passes dispatch (remediator, `_gate-procedures.md` "Adversarial
repair dispatch"). The lead keeps orchestration — dispatch, the join, and the Rule 11/13
scope calls. If `planning_offload: off`, run all sections inline. Per SKILL.md Rule 24.

### 1. Context Loading and Prior-Decision Search

Read existing artifacts if they exist:
- `_bmad-output/planning-artifacts/product-brief.md`
- `_bmad-output/planning-artifacts/prd.md`
- The prior sprint's `_bmad-output/planning-artifacts/s<N-1>/locked-requirements.md`, if that
  slot exists
- Project memory files in the user's memory directory

**Prior-decision search (settled-decision corpus).** For any sprint whose scope touches a
named subsystem or component, the lead MUST grep the SETTLED-decision corpus — resolved and
settled prior decisions, not only currently-open items — and cite the result as evidence:
- `docs/escalations/pending.md`, **including** entries carrying a `RESOLVED` or
  `DECIDED_AUTONOMOUSLY` terminal marker — a search filtered to only OPEN entries misses
  settled answers
- `docs/adr/` (Architecture Decision Records) and `docs/retro/s*/retro.md` for prior decisions
  on the same subsystem

If the project keeps no such files, the corpus is the archived-escalation / ADR / retro corpus
wherever it lives; the search is still required and a zero-hit pass still shows its command.

Cite the literal grep command(s) run, the hit count, and a one-line disposition per hit
(`superseded` / `still binding` / `not relevant`). A subsystem-keyword grep returning zero
hits is a valid pass ONLY if the grep command itself is shown. **A step that does not cite the
prior-decision search → gate FAILS.** Any prior decision dispositioned `still binding` MUST be
carried into the requirements as an explicit constraint. Rationale and the minimum-mechanism
accounting: `discovery.md` §1a.

### 2. Option Check (Rule 13)

Scan the user's feature description and any referenced carry-over items for multiple
implementation options or scope levels (e.g., "A: X, B: Y, C: Z"). If any item presents
options:
- Evaluate options using project context, user preference history, and technical feasibility
- Select the best option and document as `DECIDED_AUTONOMOUSLY` in `docs/escalations/pending.md`
- If options represent fundamentally different features (not just implementation approaches),
  seek clarity from the user per Rule 11

### 3. Locked Requirements (lead-inline, Rule 13)

Write this BEFORE section 4 — the authoring dispatch consumes it. Extract all
user-specified requirements into a `LOCKED_REQUIREMENTS` block and write it to this sprint's
slot, never into the brief:

```
_bmad-output/planning-artifacts/s<N>/locked-requirements.md
```

`<N>` is `sprint_id` (`scripts/ai-dlc/sprint-status.sh sprint-id`). The file holds this
sprint's block and nothing else:

```markdown
<!-- LOCKED_REQUIREMENTS — DO NOT MODIFY DURING VALIDATION -->
<!-- Source: [user input | carry-over item #N | escalation spec path] -->
- [verbatim user-specified requirement 1]
- [verbatim user-specified requirement 2]
<!-- END LOCKED_REQUIREMENTS -->
```

**Every block MUST be closed** — `validate-locked-anchor.sh` (Check 3b) parses blocks by
their sentinels and an unpaired opener extracts as nothing. Keep to the sentinel pair above.

**The brief keeps a POINTER, not a copy.** Where a per-sprint block used to sit, write:

```markdown
## Locked requirements

Each sprint's `LOCKED_REQUIREMENTS` block lives in that sprint's slot,
`_bmad-output/planning-artifacts/s<N>/locked-requirements.md`. The in-force set is
the union across slots; no block is copied here.
```

Sources to extract from: the user's original input to `/ai-dlc`, any carry-over items
referenced by the user, any escalation specs or feature docs referenced by the user, and
project memory entries about user preferences that constrain this feature. Be exhaustive.
Every concrete detail the user specified (placement, scope, behavior, approach) is a locked
requirement. Do not paraphrase — quote verbatim or as close to verbatim as the source allows.
Full rationale for this file's shape and the accumulation defect it fixes: `discovery.md` §4a.

### 4. Authoring Dispatch

Dispatch ONE `pm-escalated` subagent, bound per Rule 19 (model + role-contract line), that
runs the following in order:

**(a) Update the product brief.** Per Rule 25(a) — integrate the new scope into the
current-state sections and **move** superseded content and prior per-sprint narrative to
`product-brief-history.md` (cut-and-paste, verbatim). Never drop content: the union of live
and history must preserve everything prior.

**(b) Run `bmad-spec` headless** with the product brief and its `LOCKED_REQUIREMENTS` block
(section 3) as input, and slug `<sprint-slug>` — **no sprint token in the slug**, because
`bmad-spec` composes its output directory from it. File the package under
`_bmad-output/specs/s<N>/<slug>/` — relocate with `git mv` if the returned paths are not
already there, BEFORE section 4(c) or the validation cycle reads `SPEC.md`. Full contract for
this dispatch — the escalated-route reason, the dispatched-not-inline reason, the relocation
mechanics, the returns handling, and why the spec is never a full-text anchor target — is
`discovery.md` §4b; carry it unchanged. In particular:
- Every capability's `success` field MUST be in EARS form (one of `THE <system> SHALL …`;
  `WHILE <state>, THE <system> SHALL …`; `WHEN <trigger>, THE <system> SHALL …`;
  `WHERE <feature>, THE <system> SHALL …`; `IF <trigger>, THEN THE <system> SHALL …`).
- On `{"status": "complete", ...}` proceed. On `{"status": "blocked", "error_code":
  "insufficient_intent" | "missing_slug"}` escalate as a Rule 12 HARD_BLOCK with the `reason`
  quoted verbatim.
- Headless runs `express` mode: gaps land as `open_questions[]`. Any entry that bears on a
  `LOCKED_REQUIREMENTS` bullet is a Rule 11 ambiguity and MUST be escalated as a Rule 12
  HARD_BLOCK before the gate, not carried as a note — unless it is resolved by the research
  sub-skills below, in which case it is not escalated.

**(c) Update the PRD.** Per Rule 25(a) — integrate the new scope's requirements into the
current-state sections and **move** superseded requirement versions and prior per-sprint scope
narrative to `prd-history.md` (cut-and-paste, verbatim). Never drop a requirement. Rule 13
locked requirements stay in the live PRD. Reference existing components by name where the new
work touches them. For requirements from carry-over items or user instructions: quote the
source requirement verbatim; preserve specific details; do not generalize.
Every functional requirement MUST cite the capability it realizes, in its own entry, alongside
the existing locked-requirement arrow:

```
- **FR-S<N>-1 (CAP-1) (← LR-S<N>-1) — <title>.** <body>
```

`bmad-prd` cannot add this citation (its template numbers requirements globally and carries no
`CAP-`/`LR-`/`SPEC.md` token) — add it in a second pass, resolving `CAP-<m>` from the spec
kernel. Gate-validation Check 30 FAILS on a capability no FR cites. Full FR-grammar rationale:
`research-requirements.md` §2. Then propagate the `LOCKED_REQUIREMENTS` block from
`s<N>/locked-requirements.md` into the PRD (as `research-requirements.md` §2a): if the PRD
adds new requirements derived from research, add those to the block only if they originated
from the user's input, never from research findings or agent analysis.

**PRD validation.** Invoke `/bmad-prd` with the **validate** intent — structured completeness
check against its own rubric. Fix the gaps it reports as part of this same dispatch (rather
than a separate `pm` dispatch, since the authoring dispatch already holds the pen). It detects
create / update / validate from the conversation, so say which you want rather than relying on
inference: this call must not re-author the PRD. Under the headless contract the validate
intent always writes both `validation-report.html` and `validation-report.md` into the run
folder regardless of finding count, and returns `"offer_to_update": true` — read the report,
do not treat the returned offer as an instruction to hand it the update.

**Write `architecture-impact.md`** at `_bmad-output/planning-artifacts/s<N>/architecture-impact.md`
— one line per FR:
```
- FR-S<N>-<k>: architecture_impact: none
- FR-S<N>-<k>: architecture_impact: <one line naming the component and the change>
```
The Architect seat in section 5 challenges every line reading `none`.

**Research sub-skills.** `/bmad-domain-research`, `/bmad-market-research`,
`/bmad-technical-research` run inside this same dispatch, and ONLY when a SPEC
`open_questions[]` entry bears on a `LOCKED_REQUIREMENTS` bullet, scoped to that question. An
entry research does not resolve is a Rule 11 ambiguity escalated as a Rule 12 HARD_BLOCK
before the gate (as (b) above). Otherwise, write a skip record into the PRD's `Research
Findings` section naming the `open_questions[]` state that justified the skip, matching:
```
^(- )?\*{0,2}Research skipped\*{0,2}:[[:space:]]+\S
```
Gate-validation Check 1c arm (b) accepts that record.

Returns paths only. The lead reads paths, not content.

### 5. Validation Cycle (Rule 8)

Run the validation cycle (`_gate-procedures.md`, "Validation cycle") — its passes use the
**Adversarial review dispatch** and **Adversarial repair dispatch** sub-routines — over the
product brief, the spec kernel, and the PRD as ONE subject. Parameters:
- **party-mode seats / subject:** Architect, Dev — walk all three artifacts. The Architect
  seat challenges every `architecture_impact: none` line in `architecture-impact.md`.
- **source-fidelity check:** where features originate from carry-over items or user
  instructions with specific details, verify those details are preserved and flag any
  generalization (`discovery.md` §5's brief bullet); verify each requirement implements what
  was requested, not a generalized or lower-effort alternative (`research-requirements.md` §4's
  PRD bullet).
- **adversarial focus:** none beyond the adversary's default contract.
- **intensity:** on `validation_intensity == lightweight`, skip party-mode and
  advanced-elicitation. That skip is the whole of `lightweight`; it is NOT a cap on passes —
  the cycle still converges (Check 24's scope includes `requirements`), so each pass stamps a
  `verdict:` and the series ends when one stamps `EXIT_CONDITION_MET`. One validation cycle
  over the three artifacts as one subject satisfies the per-artifact minimum (Check 20).
- **`Seam D` label:** `requirements adversarial pass <N>`.
- **on convergence:** append a changelog to
  `_bmad-output/planning-artifacts/s<N>/changelog-requirements.md` (`_gate-procedures.md` —
  "Where a changelog is written"; NOT the artifacts themselves), then proceed to gate
  validation.

### 6. Gate Validation and Proceed

Run auto-handoff evaluation at `Seam B` with the label `requirements end-of-step pre-gate`
(see `_gate-procedures.md` "Auto-handoff evaluation"). If evaluation returns CONTINUE, run
gate validation [planning] (`gate-validation.md`), then:
**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/architecture.md`
