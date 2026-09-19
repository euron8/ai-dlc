### Rule 24 -- Planning and retro exploration is dispatched to analyst subagents

This file is the full text of Rule 24 of `SKILL.md`; the stub in that file is the load pointer. It ships with the skill and is audited as rule prose under the same standard as the stub.

Read-heavy exploration in planning **and retro** steps is the lead's
largest avoidable cache-read cost: every file the lead reads inline accumulates in its
context and is re-read every subsequent turn. To keep the lead lean,
the *exploration* portion of designated steps is dispatched to an
`analyst` subagent (read-only, bound to the analyst role file per Rule 19 — model + role-contract line) whose raw
reading never enters the lead's context.

**Config.** `planning_offload` (default `on`). When `on`, the steps
listed below dispatch an analyst for their exploration. When `off`,
those steps run fully inline. Projects override
by setting `planning_offload` in this section directly.

**Offloaded steps.** Full offload — `deep-codebase-analysis`,
`codebase-inventory`, `bug-investigation`, `doc-reconciliation`,
`carry-over-evaluation`. Split offload (exploration only; authoring +
validation stay inline) — `discovery`, `research-requirements`,
`requirements`, `architecture`, `stories-test-strategy` (framework-import
probe only),
`retro` (per-phase micro-dispatches interleaved with lead decisions; the
evidence chain and all governance authoring stay inline — see
`steps/retro.md`).
Special-cased — `doc-repair-backfill`: its §1 repair is a **dev /
protected-path-editor** write-dispatch (not an analyst read-dispatch),
since the read was already done upstream by `doc-reconciliation`.

**Dispatch contract.** Each offloaded step's Section 0 defines its own
concrete dispatch — the analyst's exploration scope, the canonical output
artifact path, and the resume point — and spawns the `analyst` via the
Agent tool (bound to the analyst role file per Rule 19 — model + role-contract line). The
cross-cutting rules the lead applies to every such dispatch: dispatch with
`run_in_background: true` and bounded-join it (Rule 29 — a blocking analyst
spawn locks the operator out for its full duration); order the
dispatch prompt shared-block-first (dispatch-prompt cache discipline,
`implementation.md`); the analyst writes the artifact to disk and returns
ONLY `{artifact_path, summary, gaps}`, never raw content or its
exploration trace; the lead reads the artifact from disk only when a
decision needs it (Rule 23(a)); an absent artifact at the returned path is
non-delivery — the lead re-dispatches (a text-only summary is not a
delivered draft). Build no detector for this; the lead's read of the
expected path is the check (Rule 26: audit before adding mechanism).

**Sprint-stamped drafts.** A per-sprint analyst draft is written to a
sprint-stamped path — `<area>/s<N>/<base>.md`, where `<N>` is `sprint_id`
from the pipeline snapshot's Sprint Context (resolved at `route.md`
Step 6). **The stamp is the DIRECTORY, not the basename.**
`artifact-path-grammar.md` is the whole rule — the directory is the only
sprint slot, and a basename carrying a sprint token is what forces a
reader to search — and this is one application of it. This applies to the five
per-sprint drafts: `carry-over-evaluation.md`, `discovery-context.md`,
`research-notes.md`, `requirements-context.md`, `architecture-context.md`. It does NOT apply to the
one-shot onboarding artifacts (`codebase-analysis.md`,
`brownfield-inventory.md`, `doc-reconciliation.md`) — those are written
once at the area root, are read by path downstream, and have no sprint
key — nor to `bug-analysis.md`, which is bug-keyed rather than
sprint-keyed.

**AND IT APPLIES TO `test-strategy.md`, WHICH IS NOT A DRAFT — THE LIST ABOVE
ENUMERATED PRODUCERS AND THE RULE IS ABOUT PATHS.** It is a TEA deliverable
(`stories-test-strategy.md` §5), it is read downstream, and it was in none of
the three classes above for 72 sprints. Its write path is
`_bmad-output/planning-artifacts/s<N>/test-strategy.md`.

**THE CRITERION, so the next artifact is decided rather than discovered.** An
area-root path is legitimate iff the project holds exactly ONE instance of that
basename for its whole life, and there are exactly three ways that is true, each
naming the mechanism that keeps it true:

- **durable/consolidated** — every sprint appends to one file and
  `artifact-consolidation.md` drains it (`prd.md`, `product-brief.md`,
  `architecture.md`, `carry-over-backlog.md`);
- **live + rotated** — one live copy, epochs archived into `s<N>/` by a named
  rotation, Rule 25(c) (`sprint-status.yaml`, `gate-log.md`,
  `pipeline-snapshot.md`, `audit-anchors.md`);
- **one-shot** — written once at onboarding and never again (the three above).

Anything else is written once per sprint with nothing draining it and nothing
archiving it, so sprint N+1's write DESTROYS sprint N's — and it belongs in
`s<N>/`. **A syntactic path check cannot make this call and is not wrong not to**
(`artifact-path-grammar.md`): both the area-root and the slotted path conform.
Only the step that writes the file knows which class it is in, which is why the
criterion lives here and the enumeration lives with the enforcer.

An unstamped write silently destroys the prior sprint's draft: these
drafts have no reader in the pipeline and no archive pair, so an
overwrite is unrecoverable outside git, and any citation into the file
(by section, by finding ID) then resolves against the *wrong sprint's*
document — a silently-wrong answer, not an error. Stamping makes the
draft immutable **across** sprints. It is not append-only *within* one:
re-drafting sprint N (a re-dispatch after non-delivery, or a re-plan)
correctly overwrites sprint N's own file.

The stamp lives in the **filename**. The draft's H1 is prose and MUST NOT
be parsed for the sprint number. The returned `artifact_path` is
authoritative — never reconstruct the path from the basename.

Mechanized by `scripts/ai-dlc/validate-draft-stamps.sh` (gate-validation Check
23, planning gates), which fails on an unstamped draft on disk or a
consumer `extensions/`/`overrides/` layer that restates a §0 write path
without the stamp.

**Production vs validation boundary.** The analyst *drafts* the
artifact; the lead *validates, decides, and owns* it. Rule 20
validation sub-skills MUST still run inline in the lead on the draft —
they are never dispatched to the analyst, and the analyst never emits
a `SKILL_INVOCATION_PROVENANCE` block. The analyst produces inputs,
not validated outputs. Routing, gate, and requirement-tradeoff
decisions remain the lead's.

**Excluded.** Orchestration, routing, and gate-validation decisions are
never offloaded (the non-delegable set, Rule 28). Everything else is
delegated by default: the build phase to implementation teammates,
planning exploration to the analyst, protected-path edits to the
`protected-path-editor` (Rule 28 / `implementation.md`). "Requiring the
lead's live accumulated state" narrows to exactly the non-delegable set
-- it is not a general license to keep read-heavy or mechanical work
inline.
