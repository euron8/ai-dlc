#!/usr/bin/env bash
# consolidation-residue — assert artifact-consolidation.md homes its own working files
# in the sprint slot and says what becomes of them.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# WHAT THIS EXISTS FOR.
#
# The step is a one-shot rewrite of a durable planning artifact. It writes four working
# files along the way -- a baseline manifest, two drafts, a coverage report -- and until
# this fixture shipped it prescribed ONE of those paths, at the DURABLE AREA ROOT, and
# named no path at all for the other three.
#
# Measured in the reference consumer before the fix: 33 of 96 root-level files in
# planning-artifacts/ were this step's byproduct -- 1.80 MB, 13.7% of the directory --
# against 383 KB (2.9%) for the three live artifacts they exist to protect. Eleven
# basenames sat at BOTH the root and a sprint slot with nothing declaring which was
# current, including consolidation-manifest-prd.md. One draft was a 1383-line
# near-duplicate of the 1530-line live PRD, differing on 155 lines.
#
# WHY NO EXISTING CHECK CAUGHT IT, and this is the part worth carrying. I82 binds every
# artifact path core prescribes to the grammar, and validate-artifact-paths.sh enforces
# it on the consumer -- but the grammar's rule is "the directory is the only sprint
# slot", so what it detects is a sprint TOKEN outside the slot. An area-root path
# carrying NO sprint token is syntactically conforming, and so is the slotted one. Both
# paths pass. **A syntactic grammar cannot tell a durable artifact from a per-sprint one
# that omitted its sprint** -- only the step that writes the file knows which it is, so
# the assertion has to live against the step.
#
# THE JOIN IS THE POINT OF ASSERTION 4. Step 2 names the draft paths and Step 6 removes
# them. Two hand-lists that must agree is the shape this repo keeps finding broken, so
# the fixture derives Step 6's removal set from Step 2's write set rather than carrying
# its own copy of either.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

if [ -n "$ROOT" ] && [ -f "$ROOT/core/skills/ai-dlc/steps/artifact-consolidation.md" ]; then
  STEP="$ROOT/core/skills/ai-dlc/steps/artifact-consolidation.md"
elif [ -n "$ROOT" ] && [ -f "$ROOT/.claude/skills/ai-dlc/steps/artifact-consolidation.md" ]; then
  STEP="$ROOT/.claude/skills/ai-dlc/steps/artifact-consolidation.md"
else
  echo "FIXTURE ERROR: artifact-consolidation.md not found in either layout" >&2
  echo "  looked in: $ROOT/core/skills/ai-dlc/steps/ (distribution), $ROOT/.claude/skills/ai-dlc/steps/ (consumer)" >&2
  exit 2
fi

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }

# Every _bmad-output path a file prescribes, one per line.
paths_of() { grep -ohE '_bmad-output/[A-Za-z0-9_./<>-]+\.md' "$1" | sort -u; }

# The durable set: the four artifacts this step TARGETS, plus their write-only
# companions. These legitimately sit at the area root -- they are the whole reason the
# area root exists -- so they are exempt by NAME, derived from the step's own Purpose
# paragraph rather than hand-listed here.
durable_re='(prd|product-brief|carry-over-backlog|architecture)(-history|-archive|-proposed)?\.md$'

# Slotless prescribed paths that are NOT durable targets. This is the finding set.
offenders_of() { paths_of "$1" | grep -v '/s<N>/' | grep -vE "$durable_re" || true; }

echo "consolidation-residue"

# --- 1. NO WORKING FILE IS PRESCRIBED AT THE DURABLE AREA ROOT -----------------
n_off="$(offenders_of "$STEP" | grep -c . || true)"
if [ "$n_off" -eq 0 ]; then
  ok "every working-file path the step prescribes carries the s<N>/ sprint slot"
else
  bad "$n_off path(s) prescribed outside the sprint slot and outside the durable set"
  offenders_of "$STEP" | sed 's/^/        /'
fi

# --- 2. CONTROL: the step prescribes paths AT ALL ------------------------------
# Without this, assertion 1 passes for a step file that names no path -- and for a
# step file that was deleted. An absence is not a finding until something proves the
# search could have found one.
n_all="$(paths_of "$STEP" | grep -c . || true)"
n_slot="$(paths_of "$STEP" | grep -c '/s<N>/' || true)"
if [ "$n_all" -ge 4 ] && [ "$n_slot" -ge 4 ]; then
  ok "  control: the step prescribes $n_all path(s), $n_slot of them slotted -- assertion 1 is not vacuous"
else
  bad "  control failed: $n_all path(s) prescribed, $n_slot slotted -- assertion 1 proves nothing"
fi

# --- 3. STEP 6 SAYS WHAT BECOMES OF THE DRAFTS ---------------------------------
# The silence was the defect. Item 19's control on the original file:
# `delete|remove|rm|clean ?up|discard|retire|unlink` returned rc=1 over this step while
# matching three sibling steps, so the grep could fire and the zero was real.
if grep -qE '^ *rm -f ' "$STEP"; then
  ok "the step names a disposition for its drafts rather than falling silent"
else
  bad "no draft disposition in the step -- this is the silence that accumulated eleven drafts"
fi

# --- 4. THE REMOVAL SET IS THE WRITE SET — A JOIN, NOT TWO HAND-LISTS ----------
# Every draft path Step 2 prescribes must be a path the step later removes, and every
# path it removes must be one it prescribed. Divergence in EITHER direction is the
# defect: a draft written and not removed accumulates, and a removal of a path nothing
# writes is a line that will silently stop matching.
paths_of "$STEP" | grep 'consolidation-draft-' | sort -u > "$WORK/written"
grep -ohE '_bmad-output/[A-Za-z0-9_./<>-]+\.md' <(sed -n '/^ *rm -f /,/^$/p' "$STEP") \
  | sort -u > "$WORK/removed"
n_written="$(grep -c . < "$WORK/written" || true)"
if [ "$n_written" -eq 0 ]; then
  bad "  the step prescribes no draft paths at all -- assertion 4 has no subject"
elif diff -q "$WORK/written" "$WORK/removed" >/dev/null 2>&1; then
  ok "  the removal set and the draft write set are the same $n_written path(s), derived both ways"
else
  bad "  the drafts written and the drafts removed disagree"
  diff "$WORK/written" "$WORK/removed" | sed 's/^/        /'
fi

echo ""
report_end consolidation-residue
