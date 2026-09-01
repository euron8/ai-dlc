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

**Not a consolidation target: `gate-log.md` (and any similar append-only log).**
Logs are bounded by *rotation*, not consolidation: they rotate at epoch/sprint
boundaries into `implementation-artifacts/s<N>/<basename>-archive.md`
(Rule 25(c)), so a live log never accretes the
per-sprint narrative and superseded versions this step exists to collapse — and
it never reaches a consolidation threshold in the first place. This step's
targets are the threshold-bearing living *planning* artifacts enumerated above.
Stated as an exclusion, not a closed allowlist: adding a fifth living artifact
to the list above must not require editing this paragraph.

**Invocation.** Operator-invoked, not part of the automatic pipeline
(per Rule 25(d): consolidation is a fidelity-critical rewrite and must
be supervised). The retro artifact-size audit recommends it; the
operator runs it on demand, naming the target artifact. Run it at a
quiescent point (between sprints), not mid-pipeline.

## WHERE THIS STEP'S WORKING FILES GO

**Every file this step writes is a PER-SPRINT work product and belongs in the sprint
slot**: `_bmad-output/planning-artifacts/s<N>/`. `<N>` is `sprint_id`; the directory
is the only sprint slot (`artifact-path-grammar.md`). This is stated once here and
the sequence below never repeats a bare area-root path.

**RESOLVING `<N>` IS DIFFERENT FOR THIS STEP THAN FOR EVERY OTHER ONE, AND THAT IS
WHY IT IS SPELT OUT.** Sibling steps run inside a sprint and take `sprint_id` from the
pipeline snapshot's Sprint Context, resolved at `route.md` Step 6. This step is
operator-invoked at a QUIESCENT point — between sprints — so the snapshot may hold a
sprint that has closed, or one that has not started. **Use the `sprint_id` the snapshot
holds when the pass runs.** A consolidation pass is bookkeeping for the sprint that
produced the growth, not for the one about to begin, and the closed sprint is the one
whose corpus the pass is draining. If the snapshot holds no `sprint_id` at all, STOP
and ask the operator which sprint to stamp — **do not fall back to the area root**,
which is the defect this section exists to prevent.

**THE AREA ROOT IS FOR DURABLE ARTIFACTS ONLY** — the four this step targets, and their
`*-history.md` / `*-archive.md` companions. Measured in the reference consumer before
this was written: **33 of 96 root-level files in `planning-artifacts/` were this step's
byproduct — 1.80 MB, 13.7% of the directory**, against 383 KB (2.9%) for the three live
artifacts they exist to protect. Eleven basenames sat at BOTH the root and a sprint
slot, `consolidation-manifest-prd.md` among them, with nothing declaring which was
current. `validate-artifact-paths.sh` cannot see it and is not wrong not to: both paths
conform. **A syntactic grammar cannot tell a durable artifact from a per-sprint one that
omitted its sprint** — only the step that writes the file can, which is why the
declaration is here.

## EXECUTION SEQUENCE

### 1. Baseline manifest

Before any change, enumerate what MUST be preserved. Dispatch an
`analyst` subagent (Rule 24, `model` from the analyst role file per Rule 19) to read the target
artifact and emit a **baseline manifest** to
`_bmad-output/planning-artifacts/s<N>/consolidation-manifest-<artifact>.md`:
every requirement ID / numbered requirement / Rule 13 locked
requirement (for PRD), every section heading, or every backlog item ID
(for the backlog) present in the current file. For `architecture.md`: every
section heading AND every ADR (by title/ID) — both the current-state design and
every dated addendum. The manifest is the no-loss checklist. The analyst
returns `{artifact_path, summary, gaps}`.

### 2. Draft the consolidated split

Dispatch an `analyst` (Rule 24) to produce two drafts, written to disk
(NOT returned inline) **at these paths** — the step used to name none, and an
unprescribed path is how eleven drafts landed in the durable area root:
- **Consolidated live draft** —
  `_bmad-output/planning-artifacts/s<N>/consolidation-draft-<artifact>-live.md`.
  Current-state only: deduplicated
  current requirements / open items, no per-sprint narrative, no
  superseded versions. Rule 13 locked requirements MUST remain.
- **History relocation draft** —
  `_bmad-output/planning-artifacts/s<N>/consolidation-draft-<artifact>-history.md`.
  The superseded versions and per-sprint
  scope narrative removed from live, verbatim, ready to append to the
  companion history/archive file.

Every manifest entry MUST appear in exactly one of the two drafts
(current → live, historical → history). The analyst returns the two
draft paths + a coverage report at
`_bmad-output/planning-artifacts/s<N>/consolidation-coverage-<artifact>.md`
mapping each manifest entry to its destination, plus any `gaps`.

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

For `prd.md`, invoke `/bmad-prd` on the consolidated live draft
(Rule 20 — inline, with a `SKILL_INVOCATION_PROVENANCE` block). For the
brief/backlog, run the appropriate validation sub-skill. For
`architecture.md`, run the architecture validation sub-skill on the
consolidated live draft and regenerate `docs/architecture-index.md` from it
(`scripts/ai-dlc/gen-architecture-index.js`). The consolidation must not weaken the
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
- **The coverage report cites THIS COMMIT's sha as the destination evidence, not the
  draft paths.** The drafts do not survive Step 6, so a coverage report that cites them
  is an audit trail with dangling citations the moment the step finishes.

### 6. Retire the drafts, keep the record

**DELETE both drafts. KEEP the manifest and the coverage report.** The step used to say
nothing here, and the silence is how eleven drafts accumulated in the reference consumer
— one of them a 1383-line near-duplicate of the 1530-line live PRD, differing on 155
lines, with nothing declaring which was authoritative. **Two files claiming to be the
same artifact is the failure mode this whole step exists to end, and the step was
manufacturing it.**

```sh
rm -f _bmad-output/planning-artifacts/s<N>/consolidation-draft-<artifact>-live.md \
      _bmad-output/planning-artifacts/s<N>/consolidation-draft-<artifact>-history.md
```

**WHY RETIRE RATHER THAN RETAIN, and the answer is in Step 5's own sentence.** After the
swap the live draft IS the live artifact and the history draft IS the tail of the
companion file — both byte-redundant with committed content, and Step 5 already names
the audit trail as *"the manifest + coverage report"*, which the drafts are not part of.
Retention would keep a second copy of every byte the artifact holds, in the same
directory, forever, and that second copy is indistinguishable from the first to every
reader that is not this step.

**THE MANIFEST AND THE COVERAGE REPORT STAY**, in the sprint slot. They are the no-loss
record — the manifest is what Step 3 verified against and the coverage report is the
per-entry mapping. They are small, they are not copies of the artifact, and deleting
them would destroy the only evidence that the pass lost nothing.

**THIS DOES NOT LICENSE DELETING BYPRODUCT A PREVIOUS PASS ALREADY LEFT BEHIND.** Older
coverage reports cite draft PATHS rather than a commit, so deleting those drafts breaks
a record that was already written. Existing byproduct is a HOMING problem, not a garbage
one: move it into the sprint slot of the pass that produced it. **Recover that sprint
from the commit that ADDED the file, never from the file's content** — a consolidation
byproduct's content is other sprints by construction, so the most-frequent sprint token
in it is the sprint being consolidated, not the sprint doing the consolidating. Measured
across the reference consumer's 33: content frequency disagreed with provenance on the
majority, while the adding commit resolved **24 of 33 directly from its own subject** and
the remaining 9 by walking back to the nearest sprint-naming commit in first-parent
order. **`git log --follow` is the wrong instrument here** — a draft is a near-copy of
its source artifact, so rename detection walks into the source's history and reports a
creation date months before the draft existed.

### 7. Stop

Consolidation is a standalone migration. Do not continue into pipeline
steps. Report the before/after sizes and the manifest coverage to the
operator.
