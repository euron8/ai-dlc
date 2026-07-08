---
name: artifact-consolidation
description: One-shot operator-invoked consolidation of a bloated living planning artifact to bounded current-state, with no-loss preservation to history
nextStepFile: STOP
---
<!-- STEP_LOADED_TOKEN: artifact-consolidation -->

# Artifact Consolidation (one-shot migration)

**Purpose:** A living planning artifact (`prd.md`, `product-brief.md`,
`carry-over-backlog.md`, or `docs/architecture.md`) has grown past its
Rule 25(d) threshold — typically a long-running project whose artifact
accreted per-sprint narrative and superseded versions inline (for
`architecture.md`: appended per-sprint "Architecture Addendum" sections).
This step rebuilds it as a bounded current-state file, moving everything
historical to its `*-history.md` / `*-archive.md` companion **without losing
anything**.

**Invocation.** Operator-invoked, not part of the automatic pipeline
(per Rule 25(d): consolidation is a fidelity-critical rewrite and must
be supervised). The retro artifact-size audit recommends it; the
operator runs it on demand, naming the target artifact. Run it at a
quiescent point (between sprints), not mid-pipeline.

## EXECUTION SEQUENCE

### 1. Baseline manifest

Before any change, enumerate what MUST be preserved. Dispatch an
`analyst` subagent (Rule 24, `model` from the analyst role file per Rule 19) to read the target
artifact and emit a **baseline manifest** to
`_bmad-output/planning-artifacts/consolidation-manifest-<artifact>.md`:
every requirement ID / numbered requirement / Rule 13 locked
requirement (for PRD), every section heading, or every backlog item ID
(for the backlog) present in the current file. For `architecture.md`: every
section heading AND every ADR (by title/ID) — both the current-state design and
every dated addendum. The manifest is the no-loss checklist. The analyst
returns `{artifact_path, summary, gaps}`.

### 2. Draft the consolidated split

Dispatch an `analyst` (Rule 24) to produce two drafts, written to disk
(NOT returned inline):
- **Consolidated live draft** — current-state only: deduplicated
  current requirements / open items, no per-sprint narrative, no
  superseded versions. Rule 13 locked requirements MUST remain.
- **History relocation draft** — the superseded versions and per-sprint
  scope narrative removed from live, verbatim, ready to append to the
  companion history/archive file.

Every manifest entry MUST appear in exactly one of the two drafts
(current → live, historical → history). The analyst returns the two
draft paths + a coverage report mapping each manifest entry to its
destination, plus any `gaps`.

### 3. No-loss verification (lead, inline — do NOT offload)

The lead verifies, against the Step 1 manifest:
- Every manifest entry is accounted for in `live_draft ∪ history_draft`.
- No Rule 13 locked requirement was relocated out of the live draft.
- No entry appears in neither draft (lost) — that is a HARD_BLOCK.

If any entry is unaccounted for, STOP. Do not commit. Return the gap to
the analyst (Step 2) for a corrected draft, or resolve manually. The
union must be a superset of the baseline. This check is the gate that
honors the no-loss guarantee (Rule 25(a)).

### 4. Rule 20 validation (lead, inline)

For `prd.md`, invoke `/bmad-validate-prd` on the consolidated live draft
(Rule 20 — inline, with a `SKILL_INVOCATION_PROVENANCE` block). For the
brief/backlog, run the appropriate validation sub-skill. For
`architecture.md`, run the architecture validation sub-skill on the
consolidated live draft and regenerate `docs/architecture-index.md` from it
(`scripts/gen-architecture-index.js`). The consolidation must not weaken the
artifact's validity, only its size.

### 5. Commit the swap

Only after Steps 3–4 pass:
- Append the history relocation draft to the companion file
  (`prd-history.md` / `product-brief-history.md` /
  `carry-over-backlog-archive.md` / `docs/architecture-history.md`) — verbatim.
- Replace the live artifact with the consolidated live draft.
- Commit both in one commit:
  `refactor(artifact): consolidate <artifact> to current-state, relocate history (no-loss)`.
- The commit is git-reversible; the manifest + coverage report are the
  audit trail. Record the before/after token sizes in the commit body.

### 6. Stop

Consolidation is a standalone migration. Do not continue into pipeline
steps. Report the before/after sizes and the manifest coverage to the
operator.
