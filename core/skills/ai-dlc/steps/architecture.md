---
name: architecture
description: System design + ADRs + solutioning gate + validation cycle
nextStepFile: ./stories-test-strategy.md
---
<!-- STEP_LOADED_TOKEN: architecture -->

# Architecture (Phase 2c)

**Purpose:** System design decisions, ADRs, and solutioning gate with
full validation cycle.

## EXECUTION SEQUENCE

### 0. Exploration dispatch (Rule 24)

If `planning_offload: on` (default) AND the variant reads existing code or
architecture (feature, brownfield-a, brownfield-c — NOT greenfield /
brownfield-b, which author from scratch via `/bmad-architecture`),
do NOT read the codebase or existing architecture inline. Spawn an `analyst`
subagent (Agent tool, bound to `.claude/team-roles/analyst.md` per SKILL.md
Rule 19 — both bindings: `model` and the standing role-contract Read line)
scoped to the AS-IS / existing-architecture read — it reads the code and the
current architecture doc and writes a context digest to
`_bmad-output/planning-artifacts/s<N>/architecture-context.md` (Rule 24
sprint stamp: `<N>` is `sprint_id` from the pipeline snapshot's Sprint
Context, resolved at `route.md` Step 6), returning only
`{artifact_path, summary, gaps}`. Then resume at section 1. **Sections 1
onward stay inline in the lead** — the PRD/brief read, all design decisions,
ADR authoring, and the Rule 8 validation cycle are never offloaded. If
`planning_offload: off`, run all sections inline. Per SKILL.md Rule 24.

### 1. Context Loading

Read the PRD and product brief from `_bmad-output/planning-artifacts/`.

### 2. Architecture Creation or Update

**Invoke `/bmad-architecture` for EVERY variant that reaches this step**, not
only greenfield/brownfield-b. It takes the spec package as its richest input,
produces `ARCHITECTURE-SPINE.md` as a lean spine of invariants, and carries
`AD-<n>` decision IDs each bearing `Binds` / `Prevents` / `Rule`. It also
loads a parent spine's `AD`s as binding and read-only, so a new `AD` that
contradicts or weakens an inherited one is surfaced as a conflict rather than
applied as a local override. Adopt the spine as a spec companion, keeping
`AD` IDs stable.

`bmad-architecture` ships `scripts/lint_spine.py`, which emits JSON findings
for unfilled placeholders, duplicate or non-monotonic `AD` IDs, an `AD`
missing Binds/Prevents/Rule, and an unpinned stack version — and **exits 0
unconditionally, by design, leaving the decision to its caller.** Pass its
JSON to gate-validation Check 30 via `--spine-lint`; that check is the
caller that decides. Do not re-implement the linter.

The per-variant guidance below governs the CONTENT of the design, not
whether the workflow runs:

- For **greenfield/brownfield-b**: full system design, tech decisions, ADRs
- For **feature**: Assess whether existing architecture supports this
  feature as-is. If yes, document the integration approach as an addendum.
  If no, update the architecture doc with changes needed. Use ADRs for
  every modification. Explicitly document: what stays the same, what
  changes, what is new.
- For **brownfield-a**: Document the AS-IS architecture from code, then
  target architecture for remaining work.
- For **brownfield-c**: Update architecture doc (or create if missing).
  Document TARGET state: what stays, what changes, what is new.

**History rotation — bounded live doc (Rule 25(a), MANDATORY).** The
architecture doc is a living artifact and MUST stay current-state, exactly like
`prd.md`/`product-brief.md`/`carry-over-backlog.md`. Do NOT append a per-sprint
"Architecture Addendum" that accretes forever — an unbounded doc is whole-read on
every dev/qa/architect dispatch and comes to dominate pipeline cost. Instead, for
every update:
- **Fold the net change into the live current-state sections in place.** The
  live `architecture.md` holds what is *currently true*, consolidated — current
  components, data flows, and active ADRs.
- **Move superseded content and the dated per-sprint narrative verbatim** (cut,
  not copy — no-loss, Rule 25(a)) to `docs/architecture-history.md`. That
  companion is write-only and never whole-read in the hot path, so its growth is
  free.
- Rule 13 current invariants and active ADRs stay live; only superseded/historical
  content relocates. Nothing is ever dropped — `architecture.md` ∪
  `architecture-history.md` preserves every prior decision.

**Design selection (Rule 26).** Select the simplest design that meets
the PRD's locked requirements and NFRs. Extend existing architecture
where it covers the requirement; a parallel path or new mechanism
class requires an ADR stating why extension is insufficient.
Consolidating redundant paths is a valid design outcome.

**ADR severity: hypothesis-pending-evidence (HPE).** When an ADR
asserts a behavior or shape that depends on production-runtime data the
architecture step has NOT verified directly (observed frequency of a
condition, a keying or cardinality assumption, a hit/miss ratio, live
system state), the ADR MUST carry `severity: hypothesis-pending-evidence`
in its frontmatter or section header AND MUST include two REQUIRED
fields:

- `disconfirmation_probe:` a concrete query, API call, log-grep, or
  equivalent observable that, if it returns a defined disconfirming
  shape, invalidates the ADR.
- `disconfirmation_threshold:` an objective numeric or boolean
  criterion (`>5% of sampled records exhibit the condition`, `non-empty
  result set for query X`). Subjective phrasing ("looks wrong", "feels
  off") is not a threshold.

The architecture-step gate FAILS for any HPE ADR missing either field.
Each HPE ADR MUST be re-checked before dev dispatch: the lead executes
the `disconfirmation_probe` against production, records the result
against `disconfirmation_threshold`, and attaches the evidence to the
story artifact. An HPE ADR that reaches dev dispatch WITHOUT attached
probe-result evidence FAILS gate validation. Catches: an ADR whose
design rests on an unverified runtime assumption that is false in
production, shipping a design built on a guess. False-positive cost:
one read-only probe per HPE ADR before dispatch. Remove when: no ADR
in scope asserts a behavior depending on unverified runtime data.

**Spike terminal-operation mandate.** A spike's GO/NO-GO decision MUST
be rendered against the terminal operation the spike exists to
de-risk — the last real action in the workflow under test — executed
against the real surface (the real integration point, service, or
system), not a prerequisite or primitive that precedes it. If the
terminal operation cannot be executed in the spike environment, the
spike result is NO-GO naming the structural blocker — never
"CONDITIONAL GO on prerequisite-only evidence." A GO whose evidence
stops at the primitive or prerequisite boundary is a process defect
attributable to the spike. Catches: a spike that green-lights an
approach on evidence from the steps that precede the risky operation,
leaving the actual risk unproven at dispatch. False-positive cost: a
spike blocked at the terminal op files NO-GO instead of a soft GO, so
the blocker surfaces at design time rather than mid-implementation.
Remove when: the workflow under test has no terminal operation distinct
from its prerequisites.

### 2a. Variant-Lock Evidence Requirement (when ADR offers multiple variants)

When an ADR offers two or more implementation variants distinguished
by a runtime hypothesis (latency cause, race window, ordering, retry
shape, transport behavior), the ADR MUST require Day-1 implementation
to commit a variant-lock artifact that includes BOTH:

- **(a) Reproduction of the failure mode under controlled conditions.**
  The hypothesis the variants address must be empirically observed,
  not assumed. If the failure cannot be reproduced before Day-1, the
  ADR must default to the variant with smallest blast radius and flag
  the lock as "hypothesis-pending-evidence."
- **(b) Measurement of each variant's behavior against the
  reproduction.** Run each variant against the reproduced failure
  mode and record observable result. The chosen variant is the one
  the measurement supports.

A variant-lock artifact that documents only the chosen path's
rationale without comparison evidence fails this requirement at
gate-validation Check 3 (architecture). Violation: revert variant
lock and re-author with comparison data before continuing.

### 2b. Framework Default Audit for Security-Relevant Properties

When an ADR accepts a framework or cloud-construct default value
(AWS CDK, Terraform module, library config) on any property that
affects authentication, TLS, authorization, network exposure, or
data retention, the ADR MUST record the default value explicitly
and state WHY the default is acceptable for this project's threat
model. "We used the default" is not sufficient — the default's
literal value and its security implications must be in the ADR
body, not left implicit. Gate FAILS at architecture gate if any
security-relevant property is accepted as "default" without the
literal value + acceptability rationale in the ADR.

### 2c. Mitigation Proportionality Surfacing

When a story's chosen mitigation introduces STANDING infrastructure — a
long-running service, a scheduled alarm or monitor, a daemon, a
persistent queue, an operational runbook with on-call obligations — to
guard a change, the architect MUST assess whether the mitigation's
blast radius exceeds the change it guards. Blast radius is the surface
the mitigation itself adds: new deployable units, new secrets or
parameters, new failure modes, new operator duties. The change guarded
is the actual operation at risk (a one-time flag flip on a bounded
table, a single idempotent migration). When the mitigation's blast
radius is larger than the guarded change, the architect MUST surface
the asymmetry in the ADR body under a `## Proportionality` heading —
quantifying both sides (what the mitigation adds vs. what the change
risks) and naming the smaller-footprint alternative — BEFORE the
Solutioning Gate and architecture gate validate the design. The
Solutioning Gate FAILS for any ADR introducing standing infrastructure
that lacks a `## Proportionality` assessment. Surfacing is not a veto:
the operator MAY still accept the heavier mitigation, but the asymmetry
MUST be visible before gates ratify it, not discovered at deploy.
Catches: a heavyweight standing mitigation ratified to guard a trivial
one-shot change, adding permanent operational cost the operator never
weighed. False-positive cost: one `## Proportionality` paragraph per
ADR that adds standing infrastructure. Remove when: no ADR in scope
introduces standing infrastructure as a mitigation.

### 2d. Absolute-Invariant Executable-Guard Mandate

An architectural invariant stated as ABSOLUTE — "never", "MUST NOT
ever", "cannot", "always" — on a safety or safeguard property MUST
ship, in the same sprint it is asserted, the executable test or gate
that fails when the invariant is violated. An absolute safety invariant
with no executable guard is advisory prose, not a constraint: write it
as "prefer" or "SHOULD" if it cannot be mechanized, never as an
unenforced "never". The architecture-step gate FAILS for any ADR
asserting a new absolute safety invariant without either the guard or
the advisory downgrade.

When an existing absolute invariant acquires a sanctioned exception,
the invariant TEXT MUST be reworded to its true bounded form in place,
with the prior absolute preserved — moved to the artifact's history
file as a SUPERSEDED entry per Rule 25(a), never dropped — NOT
annotated as an exception beside a now-false absolute. The sanctioned
exception MUST ship WITH both its compensating control (the mechanism
that bounds the exception) and its detective control (the mechanism
that records each use); an exception lacking either control is not
sanctioned and MUST NOT be merged. The architecture-step gate FAILS if
an ADR softens an absolute by adding an exception without naming both
controls. Catches: a "never" safety claim that any reader trusts as
enforced while nothing blocks its violation, and a silent exception
that erodes an absolute with no bounding or recording control.
False-positive cost: one test or gate per new absolute invariant, or a
one-word downgrade when mechanization is out of scope. Remove when: no
ADR asserts an absolute safety invariant.

### 2e. Named-field-vs-implementation divergence gate

For every named field, entity, or invariant an ADR introduces, the
architect MUST execute this four-step gate before the ADR merges:

1. Write the NAME as a plain-English sentence stating what it claims —
   what a downstream consumer would assume it means from the name alone.
2. Write the IMPLEMENTATION contract as a sentence stating what the code
   actually computes or guarantees, including its start conditions,
   boundaries, and accumulation/derivation rules.
3. Diff (1) against (2). Any token in the name not faithfully
   represented by the implementation is a divergence. Resolve by exactly
   ONE of: (a) rename the field to match the implementation; (b) extend
   the implementation to match the name; or (c) document the gap in the
   ADR with an explicit `consumer-MUST-read` warning AND expose a sibling
   field carrying the boundary/anchor the name omits.
4. Include a mandatory consumer-side usage example in the ADR body,
   written as the downstream consumer would write it. If the example
   needs a corrective caveat ("note: this is actually X, not what the
   name implies"), the field is mis-named — return to step 3.

The gate is non-skippable. The architecture step FAILS if any newly
named field/entity/invariant lacks BOTH (a) evidence of the four-step
check in the commit log or ADR body AND (b) the consumer-side usage
example.

**Minimum mechanism (Rule 26(c)).** Failure caught: a named field whose
name over-claims what the implementation guarantees, so a downstream
consumer trusts the name, assumes the fuller meaning, and computes
against a boundary the code never established. False-positive cost: one
or two authoring sentences plus one example for a genuinely faithful
name. Removal condition: retire once every ADR field name is
mechanically validated against its implementation contract (a naming
linter over the schema), or the pipeline no longer admits named-field
ADRs.

### 3. Solutioning Gate

Invoke `/bmad-check-implementation-readiness` — validate design coherence
against the PRD. Fix any misalignment found.

**Invoke it, do not approximate it.** Its step 03 IS an epic-coverage
validation whose stated purpose is requirements traceability: it checks each
PRD functional requirement against epic coverage and identifies the FRs no
epic covers. An inline "style check" re-derives that by judgement and reaches
a different answer every run. Its findings are advisory on their own —
gate-validation Check 30 is what makes an uncovered requirement fail.

### 4. Validation Cycle (Rule 8)

Run the validation cycle (`_gate-procedures.md`, "Validation cycle") on the
architecture doc — its passes use the **Adversarial review dispatch** and
**Adversarial repair dispatch** sub-routines. Parameters:
- **party-mode seats / subject:** Architect, Dev, TEA, PM — every design
  decision, every component boundary, every data flow.
- **adversarial focus:** security, scalability, coupling, single points of
  failure, backward compatibility, migration risk, integration seams, and
  over-engineering (Rule 26: mechanism beyond requirements, parallel paths,
  unjustified guards — propose removals as findings).
- **intensity:** on `validation_intensity == lightweight` AND the Step 2
  assessment is NO CHANGES NEEDED, skip this cycle entirely (Rule 5 fast-track)
  and proceed to Step 5; otherwise run the full cycle.
- **`Seam D` label:** `architecture adversarial pass <N>`.
- **on convergence:** append a changelog to the architecture doc, then proceed to
  index regeneration (§4a).

### 4a. Regenerate the architecture index (Rule 25(b) slice enabler)

After the architecture doc is updated and history rotated, regenerate
`docs/architecture-index.md` — a compact map of the live doc: one line per H2/H3
as `<heading title> — #<anchor> — <one-line summary>`. This is the discoverability
backstop dev/qa consult (per their Context Loading contracts) to locate the
section(s) to slice-read when a story's `architecture_refs` is absent or stale.

Run the deterministic generator `scripts/ai-dlc/gen-architecture-index.js` (headings +
anchors are extracted mechanically; keep it cheap and always-current — do NOT
author the index by hand or by LLM summary of the whole doc, which would
re-incur the whole-read cost this index exists to avoid). Commit the regenerated
index alongside the architecture-doc changes.

**Then immediately proceed to gate validation:**

### 5. Gate Validation and Proceed

Run auto-handoff evaluation at `Seam B` with the label
`architecture end-of-step pre-gate` (see `_gate-procedures.md`
\"Auto-handoff evaluation\"). If evaluation returns CONTINUE, run
gate validation [planning] (`gate-validation.md`), then:
**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/stories-test-strategy.md`
