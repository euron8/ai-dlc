#!/usr/bin/env bash
# validate-draft-stamps.sh — per-sprint planning-artifact sprint stamps
#
# Usage: ./scripts/ai-dlc/validate-draft-stamps.sh [project-root]
# Example: ./scripts/ai-dlc/validate-draft-stamps.sh .
#
# Gate-validation Check 23 enforcer (planning gates).
#
# WHAT IT GUARDS. Four of the five names below are per-sprint ANALYST DRAFTS,
# written by an analyst subagent at a step's Section 0 (Rule 24) and read by
# NOTHING in the pipeline. They have no template, no size threshold, and no
# history/archive pair. So an unstamped write is not "an overwrite" — it is a
# silent, total destruction of the prior sprint's draft, recoverable only from
# git. Worse, any citation INTO the file (by section number, by finding ID) then
# resolves against the WRONG SPRINT'S DOCUMENT: a silently-wrong answer, not an
# error. Observed in a real consumer: a story's provenance comment cites
# `carry-over-evaluation.md §7 F6`, and the file on disk — thirty sprints
# later — has no §7 at all.
#
# THE FIFTH, `test-strategy`, IS NOT AN ANALYST DRAFT, AND ITS PRESENCE IS WHY
# THE SUBJECT OF THIS SCRIPT IS THE PATH SHAPE RATHER THAN THE PRODUCER. It is a
# TEA deliverable authored at `stories-test-strategy.md` §5, and it IS read
# downstream. It belongs here because the failure mode is identical and does not
# depend on who wrote it: one basename, one area root, one write per sprint, no
# consolidation pass draining it and no rotation archiving it — so sprint N+1's
# write destroys sprint N's. Scoping this check to "analyst drafts" is what let
# it sit outside for 72 sprints (v0.324.0, plan item 25).
#
# The fix is to stamp the write path (`s<N>/<base>.md`, N = `sprint_id` from the
# pipeline snapshot, resolved at route.md Step 6), which makes each sprint's copy
# immutable across sprints by construction. This script is the guard that the
# stamp is actually applied — in core AND in the consumer layers that restate it.
#
# THE CRITERION, so the next artifact is decided rather than discovered. An
# area-root path is legitimate iff the project holds exactly ONE instance of that
# basename for its whole life. Three ways that is true, each with a named
# mechanism, and one way it is false:
#
#   (a) DURABLE/CONSOLIDATED — every sprint appends to one file and
#       `artifact-consolidation.md` drains it. Declared twice and agreeing:
#       `artifact-consolidation.md` ("THE AREA ROOT IS FOR DURABLE ARTIFACTS
#       ONLY — the four this step targets") and `validate-artifact-budget.sh`'s
#       WHOLE_READ_SET. prd · product-brief · architecture · carry-over-backlog.
#   (b) LIVE + ROTATED — one live copy, epochs archived into `s<N>/` by a named
#       rotation (Rule 25(c)). sprint-status.yaml · gate-log.md ·
#       pipeline-snapshot.md · audit-anchors.md.
#   (c) ONE-SHOT — written once at onboarding and never again. See the scope
#       note below.
#   (x) NONE OF THESE — one write per sprint, nothing draining and nothing
#       archiving. That is this check's subject, and the four drafts plus
#       test-strategy are the whole of it on today's tree.
#
# Derived, not asserted: over the 10 basenames core prescribes at
# `_bmad-output/planning-artifacts/` root, (a) accounts for 4, (b) for 1
# (sprint-status.yaml, route.md Step 1), (c) for 3, and (x) for 1 —
# test-strategy. bug-analysis is (x) by shape and exempt for a stated reason
# below, which is the one place the criterion and the exemption disagree.
#
# TWO HALVES, because the drift has two surfaces:
#
#   (1) DISK (behavioural). No unstamped draft may exist in
#       `_bmad-output/planning-artifacts/`. This fires on the RENDERED OUTCOME
#       regardless of which layer caused it, so it catches a core regression and
#       a consumer override equally. Strictly stronger than reading source.
#
#   (2) LAYER (textual). No `extensions/`/`overrides/` entry may declare an
#       unstamped draft write path. A `kind: step-domain` extension hooking a
#       step re-states that step's whole Section 0 — including the output path —
#       so it can silently revert the stamp in the rendered pipeline while core
#       looks correct. (This is the v0.34.0 lesson: judge layer correctness
#       against the rendered pipeline, not core alone.) Catching it here reports
#       the drift BEFORE it produces a destroyed artifact.
#
# SCOPE — the five per-sprint planning artifacts, and only those:
#   carry-over-evaluation · discovery-context · research-notes ·
#   architecture-context · test-strategy
#
# Deliberately NOT in scope (they are not per-sprint, and stamping them would be
# Rule 26(a) speculative mechanism):
#   - codebase-analysis / brownfield-inventory / doc-reconciliation — one-shot
#     ONBOARDING artifacts. Written once, not per sprint, and READ BY PATH
#     downstream (discovery.md, doc-repair-backfill.md). Stamping breaks 4
#     working reads to fix a defect they do not have. Corroborated on the
#     reference consumer: brownfield-inventory 1 root / 0 slots, the other two
#     0 / 0 — prescribed and never written, so there is no evidence either way
#     and "leave it and say why" is the honest outcome.
#   - bug-analysis — bug-keyed, not sprint-keyed. Two bugs in one sprint would
#     collide on the same stamp, and the bug pipeline runs an `implementation`
#     gate, never a `planning` one, so this check could not fire for it anyway.
#     THIS IS THE ONE EXEMPTION THE CRITERION ABOVE DOES NOT ENDORSE, and it is
#     left standing on its own terms rather than quietly widened: bug-analysis
#     is shape (x), a second bug sprint DOES destroy the first's analysis (1 root
#     + 1 slot on the reference consumer), and the reason it stays out is that a
#     bug KEY does not exist to stamp with. Inventing one to satisfy this check
#     is the speculative mechanism Rule 26(a) forbids. Reopen it when the bug
#     route carries an id a path can be composed from — not before.
#
# MATCHING IS PATH-ANCHORED, NEVER BASENAME-ANCHORED. `route.md`'s pipeline
# table legitimately names the STEP FILE `carry-over-evaluation.md`, and every
# step file's own name collides with its artifact's name. A bare-basename grep
# flags all of them. Both halves therefore only ever match the full artifact
# path prefix `_bmad-output/planning-artifacts/`.
#
# Rule 26(c) contract:
#   Catches:  a write path — in core, or in a consumer layer that restates it —
#             landing a per-sprint planning artifact unstamped, destroying the
#             prior sprint's copy and rotting every citation into it.
#   FP cost:  one line per legitimately-unstamped file, named by the check. An
#             exemption is a visible line a reviewer sees, not a silent skip.
#   Remove when: the write path is GENERATED from `sprint_id` rather than
#             prose-specified in each Section 0, so it cannot drift.
#
# Exit codes:
#   0  -- every per-sprint planning artifact on disk is sprint-stamped, and no
#         consumer layer declares an unstamped write path for one
#   1  -- an unstamped per-sprint artifact exists on disk, or a layer declares an
#         unstamped write path for one
#   2  -- usage error
#
# Compatible with bash 3.2+ (standard on macOS).

set -u

PROJECT_ROOT="${1:-.}"

if [ ! -d "$PROJECT_ROOT" ]; then
  echo "usage: validate-draft-stamps.sh [project-root]" >&2
  echo "error: not a directory: $PROJECT_ROOT" >&2
  exit 2
fi

# The five per-sprint planning artifacts. See the scope note and the criterion
# above before adding to this list — a durable, rotated, one-shot or
# non-sprint-keyed artifact does not belong here.
DRAFTS="carry-over-evaluation discovery-context research-notes architecture-context test-strategy"

ARTIFACT_DIR="$PROJECT_ROOT/_bmad-output/planning-artifacts"
LAYER_DIRS="$PROJECT_ROOT/.claude/skills/ai-dlc/extensions $PROJECT_ROOT/.claude/skills/ai-dlc/overrides"

ERRORS=0
DISK_CHECKED=0
LAYER_FILES=0
SKIPS=""

# ---------------------------------------------------------------------------
# Half 1 — DISK. An unstamped draft in planning-artifacts means a Section 0
# write path is unstamped somewhere in the RENDERED pipeline.
#
# THE ABSENT-DIRECTORY CASE IS A SKIP, NOT A PASS. It used to fall out of the
# `if` with nothing checked and land on the same success line as a full run --
# success by two roads sharing one exit code AND one report line, which is the
# defect class this repo keeps shipping. Half 2 can still find a layer
# violation on such a tree, so the exit code is unchanged; what changes is that
# the verdict says which half ran.
# ---------------------------------------------------------------------------
if [ -d "$ARTIFACT_DIR" ]; then
  for draft in $DRAFTS; do
    DISK_CHECKED=$((DISK_CHECKED + 1))
    unstamped="$ARTIFACT_DIR/$draft.md"
    if [ -f "$unstamped" ]; then
      echo "ERROR: unstamped per-sprint planning artifact on disk:"
      echo "         _bmad-output/planning-artifacts/$draft.md"
      echo "       The sprint-stamped path is required:"
      echo "         _bmad-output/planning-artifacts/s<N>/$draft.md"
      echo "       (<N> = sprint_id from the pipeline snapshot, route.md Step 6)"
      echo "       THE STAMP IS THE DIRECTORY, not the basename — see"
      echo "       artifact-path-grammar.md. An unstamped write destroys the"
      echo "       prior sprint's copy."
      echo "       Remedy: git mv it into the slot of the sprint that WROTE it"
      echo "       (read the file's own H1 / Sprint field), never into the"
      echo "       current one — the file is that sprint's record, not this"
      echo "       sprint's."
      ERRORS=$((ERRORS + 1))
    fi
  done
else
  SKIPS="${SKIPS} disk(no $ARTIFACT_DIR)"
fi

# ---------------------------------------------------------------------------
# Half 2 — LAYER. A consumer extension/override that restates a Section 0 write
# path without the stamp silently reverts the stamp in the rendered pipeline.
#
# Match the full artifact path, never the bare basename (see header). A stamped
# reference is `.../s<N>/<draft>.md` — the DIRECTORY is the slot
# (artifact-path-grammar.md rule 2) — so it cannot contain the literal matched
# below; an unstamped one is `.../<draft>.md` with nothing between the directory
# separator and the basename. This comment described the superseded basename form
# `s<N>-<draft>.md` until v0.324.0, which is the spelling rule 2 forbids and the
# opposite of what the error text two lines down has always emitted.
# ---------------------------------------------------------------------------
LAYER_DIRS_SEEN=0
for layer_dir in $LAYER_DIRS; do
  [ -d "$layer_dir" ] || continue
  LAYER_DIRS_SEEN=$((LAYER_DIRS_SEEN + 1))
  LAYER_FILES=$((LAYER_FILES + $(find "$layer_dir" -type f 2>/dev/null | grep -c . || true)))
  for draft in $DRAFTS; do
    # The directory prefix is the anchor: a stamped path has `s<N>-` between the
    # separator and the basename, so it cannot contain this literal substring.
    hits=$(grep -rn -- "_bmad-output/planning-artifacts/$draft\.md" "$layer_dir" 2>/dev/null || true)
    if [ -n "$hits" ]; then
      echo "ERROR: consumer layer declares an UNSTAMPED per-sprint write path:"
      echo "$hits" | sed 's/^/         /'
      echo "       Required: _bmad-output/planning-artifacts/s<N>/$draft.md"
      echo "       A step-domain layer restates its step's Section 0 verbatim, so"
      echo "       an unstamped path here reverts the stamp in the rendered"
      echo "       pipeline even when core is correct."
      ERRORS=$((ERRORS + 1))
    fi
  done
done
[ "$LAYER_DIRS_SEEN" -eq 0 ] && SKIPS="${SKIPS} layer(no extensions/ or overrides/)"

if [ "$ERRORS" -gt 0 ]; then
  echo ""
  echo "FAIL: $ERRORS unstamped per-sprint planning-artifact write path(s)."
  exit 1
fi

# THE VERDICT NAMES ITS OWN WORK. "all drafts are stamped" is true of a tree with
# no drafts, no planning-artifacts directory and no consumer layer, and it was the
# same sentence either way.
if [ -n "$SKIPS" ]; then
  echo "PASS WITH SKIPS: $DISK_CHECKED artifact name(s) checked on disk, $LAYER_FILES layer file(s) scanned; SKIPPED:${SKIPS}"
  exit 0
fi
echo "PASS: all per-sprint planning artifacts are sprint-stamped ($DISK_CHECKED artifact name(s) checked on disk, $LAYER_FILES layer file(s) scanned)."
exit 0
