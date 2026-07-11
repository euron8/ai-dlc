#!/usr/bin/env bash
# validate-draft-stamps.sh — Rule 24 analyst-draft sprint stamps
#
# Usage: ./scripts/validate-draft-stamps.sh [project-root]
# Example: ./scripts/validate-draft-stamps.sh .
#
# Gate-validation Check 23 enforcer (planning gates).
#
# WHAT IT GUARDS. The four per-sprint analyst drafts are written by an analyst
# subagent at a step's Section 0 (Rule 24) and are read by NOTHING in the
# pipeline. They have no template, no size threshold, and no history/archive
# pair. So an unstamped write is not "an overwrite" — it is a silent, total
# destruction of the prior sprint's draft, recoverable only from git. Worse, any
# citation INTO the file (by section number, by finding ID) then resolves
# against the WRONG SPRINT'S DOCUMENT: a silently-wrong answer, not an error.
# Observed in a real consumer: a story's provenance comment cites
# `carry-over-evaluation.md §7 F6`, and the file on disk — thirty sprints
# later — has no §7 at all.
#
# The fix is to stamp the write path (`s<N>-<base>.md`, N = `sprint_id` from the
# pipeline snapshot, resolved at route.md Step 6), which makes each sprint's
# draft immutable across sprints by construction. This script is the guard that
# the stamp is actually applied — in core AND in the consumer layers that
# restate it.
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
# SCOPE — the four per-sprint drafts, and only those:
#   carry-over-evaluation · discovery-context · research-notes · architecture-context
#
# Deliberately NOT in scope (they are not per-sprint drafts, and stamping them
# would be Rule 26(a) speculative mechanism):
#   - codebase-analysis / brownfield-inventory / doc-reconciliation — one-shot
#     ONBOARDING artifacts. Written once, not per sprint, and READ BY PATH
#     downstream (discovery.md, doc-repair-backfill.md). Stamping breaks 4
#     working reads to fix a defect they do not have.
#   - bug-analysis — bug-keyed, not sprint-keyed. Two bugs in one sprint would
#     collide on the same stamp, and the bug pipeline runs an `implementation`
#     gate, never a `planning` one, so this check could not fire for it anyway.
#
# MATCHING IS PATH-ANCHORED, NEVER BASENAME-ANCHORED. `route.md`'s pipeline
# table legitimately names the STEP FILE `carry-over-evaluation.md`, and every
# step file's own name collides with its artifact's name. A bare-basename grep
# flags all of them. Both halves therefore only ever match the full artifact
# path prefix `_bmad-output/planning-artifacts/`.
#
# Rule 26(c) contract:
#   Catches:  a Section 0 write path — in core, or in a consumer layer that
#             restates it — landing an analyst draft unstamped, destroying the
#             prior sprint's draft and rotting every citation into it.
#   FP cost:  one line per legitimately-unstamped file, named by the check. An
#             exemption is a visible line a reviewer sees, not a silent skip.
#   Remove when: the write path is GENERATED from `sprint_id` rather than
#             prose-specified in each Section 0, so it cannot drift.
#
# Exit codes:
#   0  -- every per-sprint analyst draft on disk is sprint-stamped, and no
#         consumer layer declares an unstamped draft write path
#   1  -- an unstamped draft exists on disk, or a layer declares an unstamped
#         draft write path
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

# The four per-sprint analyst drafts. See scope note above before adding to this
# list — a one-shot or non-sprint-keyed artifact does not belong here.
DRAFTS="carry-over-evaluation discovery-context research-notes architecture-context"

ARTIFACT_DIR="$PROJECT_ROOT/_bmad-output/planning-artifacts"
LAYER_DIRS="$PROJECT_ROOT/.claude/skills/ai-dlc/extensions $PROJECT_ROOT/.claude/skills/ai-dlc/overrides"

ERRORS=0

# ---------------------------------------------------------------------------
# Half 1 — DISK. An unstamped draft in planning-artifacts means a Section 0
# write path is unstamped somewhere in the RENDERED pipeline.
# ---------------------------------------------------------------------------
if [ -d "$ARTIFACT_DIR" ]; then
  for draft in $DRAFTS; do
    unstamped="$ARTIFACT_DIR/$draft.md"
    if [ -f "$unstamped" ]; then
      echo "ERROR: unstamped analyst draft on disk:"
      echo "         _bmad-output/planning-artifacts/$draft.md"
      echo "       Rule 24 requires the sprint-stamped path:"
      echo "         _bmad-output/planning-artifacts/s<N>-$draft.md"
      echo "       (<N> = sprint_id from the pipeline snapshot, route.md Step 6)"
      echo "       An unstamped write destroys the prior sprint's draft."
      ERRORS=$((ERRORS + 1))
    fi
  done
fi

# ---------------------------------------------------------------------------
# Half 2 — LAYER. A consumer extension/override that restates a Section 0 write
# path without the stamp silently reverts the stamp in the rendered pipeline.
#
# Match the full artifact path, never the bare basename (see header). A stamped
# reference is `.../s<N>-<draft>.md` or the literal `.../s<N>-<draft>.md`
# placeholder as written in the step files; an unstamped one is `.../<draft>.md`
# with nothing between the directory separator and the basename.
# ---------------------------------------------------------------------------
for layer_dir in $LAYER_DIRS; do
  [ -d "$layer_dir" ] || continue
  for draft in $DRAFTS; do
    # The directory prefix is the anchor: a stamped path has `s<N>-` between the
    # separator and the basename, so it cannot contain this literal substring.
    hits=$(grep -rn -- "_bmad-output/planning-artifacts/$draft\.md" "$layer_dir" 2>/dev/null || true)
    if [ -n "$hits" ]; then
      echo "ERROR: consumer layer declares an UNSTAMPED analyst-draft write path:"
      echo "$hits" | sed 's/^/         /'
      echo "       Rule 24 requires: _bmad-output/planning-artifacts/s<N>-$draft.md"
      echo "       A step-domain layer restates its step's Section 0 verbatim, so"
      echo "       an unstamped path here reverts the stamp in the rendered"
      echo "       pipeline even when core is correct."
      ERRORS=$((ERRORS + 1))
    fi
  done
done

if [ "$ERRORS" -gt 0 ]; then
  echo ""
  echo "FAIL: $ERRORS unstamped analyst-draft write path(s)."
  exit 1
fi

echo "PASS: all per-sprint analyst drafts are sprint-stamped."
exit 0
