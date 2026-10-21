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
`{artifact_path, summary, gaps}`, with every gap also
in the `## Gaps` section of the artifact. Then resume at section 1. **Section 1
stays inline in the lead; sections 2 and 3 are ONE dispatched `architect`
chain** (section 2's opening paragraph), and the lead orchestrates the Rule 8
validation cycle of section 4. Rule 24's "authoring + validation stay inline"
bounds this analyst dispatch, not that chain, which is Rule 28's. If
`planning_offload: off`, the lead reads the code and the existing architecture
itself, and still dispatches the section 2–3 chain. Per SKILL.md Rule 24.

### 1. Context Loading

Read the PRD and product brief from `_bmad-output/planning-artifacts/`.

### 2. Architecture Creation or Update

**Sections 2 and 3 run as ONE dispatched `architect` chain** (Rule 28 "Split
dispatch", serial exception 3, the ordered authoring chain). Dispatch one
`architect` subagent, bound per Rule 19 (model + role-contract line), with
`run_in_background: true`. Its brief carries `shard: none (authoring-chain)`,
names sections 2 through 3 of this file as its spec, run in order, starting at
the `/bmad-architecture` paragraph (this paragraph and the next address the
lead, and the architect dispatches and joins nothing), and names
its result file, its `## Architect handoff` section and its completion signal:
the chain record
`_bmad-output/planning-artifacts/s<N>/architecture-chain.md`. The architect
writes that record FIRST, with its header; appends one line naming each file
of the chain when it STARTS writing that file, and another when it finishes
it; and only after the LAST file of the chain is written makes one final
write, the ONE Bash call
`<lead engine>/wait-for-deliverable.sh --mark <record> architecture architect none findings=0`, after which it edits
no file of the chain. A chain dispatched worktree-isolated carries the absolute path of the LEAD checkout's `scripts/ai-dlc` (`<lead engine>`) in its brief; otherwise `scripts/ai-dlc` is the lead's engine. It appends the `## Architect handoff` section BEFORE that
call, so the `seat-complete:` line `--mark` writes stays the last non-blank line and the final
write. The record is appended to, never rewritten. Join it with
`scripts/ai-dlc/wait-for-deliverable.sh --complete --dispatch <agentId> _bmad-output/planning-artifacts/s<N>/architecture-chain.md`,
`run_in_background: true`, `<agentId>` being the one its Agent result
returned. Never join on `ARCHITECTURE-SPINE.md`, and never on
`docs/architecture*.md`. Under `--complete` a beat is granted again only
when the record has changed, so one file that takes longer than the beat
budget ends the join as NON-DELIVERY with the record UNFINISHED. While the
architect's completion notification has not arrived and the record is still
growing, that is a live architect, not a non-delivery: re-arm the same join
with `--reset` ONCE per beat, and never re-dispatch a second architect beside
it. The record is growing when it has a new start or finish line since the
previous beat; compare its line count with the one you noted at the previous
beat. A record that has not moved since the previous beat is a non-delivery,
and you take Rule 29 "The bounded file-wait beat" exhaustion path, not another
`--reset`.

**The chain drafts; the lead adopts.** The architect runs `lint_spine.py` as
below and lists its `<lint json>` in the record. Its `## Architect handoff`
section carries its section 2 assessment (NO CHANGES NEEDED, or the change
set), section 3's readiness findings, every operator-owned value it did not
pick, and every change a notarized file would need. Once the join reports the
record `DELIVERED`, the lead reads the record's `## Architect handoff` section
and the record's `<lint json>` list, routes each operator-owned value and
finding, and only then starts section 4. The lead
passes the record's `<lint json>` to Check 30.

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
unconditionally, by design, leaving the decision to its caller.** Run it as
`uv run .claude/skills/bmad-architecture/scripts/lint_spine.py --workspace <the run folder holding ARCHITECTURE-SPINE.md> -o <lint json>`,
the form `bmad-architecture`'s `references/reviewer-gate.md` gives for its
deterministic pass: `--workspace` takes the folder, never the spine file.
Pass `<lint json>` to gate-validation Check 30 via `--spine-lint`; that check is the
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
  decision, every component boundary, every data flow. The architecture doc is one document
  (Rule 28, "Split dispatch": seats x sections axis, or serial exception 4 when
  `partition-document.sh --map` reports it SERIAL).
- **adversarial focus:** security, scalability, coupling, single points of
  failure, backward compatibility, migration risk, integration seams, and
  over-engineering (Rule 26: mechanism beyond requirements, parallel paths,
  unjustified guards — propose removals as findings).
- **intensity:** when the Step 2 assessment is NO CHANGES NEEDED AND EITHER
  `validation_intensity == lightweight` OR the declared-no-impact predicate below
  holds, skip this cycle entirely (Rule 5 fast-track) and proceed to Step 5;
  otherwise run the full cycle. The declared-no-impact arm applies at EVERY
  intensity: it keys on this sprint's
  `_bmad-output/planning-artifacts/s<N>/architecture-impact.md` (written by
  `requirements.md` §4, one `architecture_impact:` line per FR). The predicate is
  line-exact — every `architecture_impact:` line reads exactly
  `architecture_impact: none`, and there is at least one such line. The file
  absent, an empty file, or any line reading anything else (`none-for-now`,
  `None`, a trailing word) keeps the full cycle. With `f` set to the file's path,
  the predicate holds when this exits 0 (a fixture extracts and runs this line, so
  it is the predicate, not a paraphrase of it):
  <!-- FAST_TRACK_PREDICATE -->
  ```
  awk '/architecture_impact:/{n++; if ($0 !~ /architecture_impact: none$/) b++} END{exit !(n>=1 && b==0)}' "$f"
  ```
  When the fast-track is taken on this arm, the Step 5 gate log entry records
  `fast_track: architecture-impact-none` and the impact file's path beside
  `validation_intensity:` and `minimum_met:` — that is the skip provenance
  gate-validation Check 20 reads.
- **`Seam D` label:** `architecture adversarial pass <N>`.
- **on convergence:** append a changelog to
  `_bmad-output/planning-artifacts/s<N>/changelog-architecture.md`
  (`_gate-procedures.md` — "Where a changelog is written"; NOT the architecture doc
  itself), then proceed to index regeneration (§4a).

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
