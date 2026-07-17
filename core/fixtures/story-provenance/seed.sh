#!/usr/bin/env bash
# Seed for the story-provenance fixture. Builds a self-contained tree (no dependency on any real
# consumer) with three cases, and prints its ROOT on the last line.
#
#   converged/    terminal pass p2 = EXIT_CONDITION_MET with a REAL toolu_ id. Two stories: one
#                 with NO provenance block, one with a hand-written DRIFTED block (missing
#                 artifact_sha, a free-text comment) — the exact s291/s292 precedent bug.
#   placeholder/  terminal pass p2 = MET but its tool_use_id is a PLACEHOLDER (the self-introspection
#                 defect). The writer must refuse without --tool-use-id and backfill with it.
#   unconverged/  terminal pass p1 = EXIT_CONDITION_NOT_MET. The writer must refuse to stamp.
set -u

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/story-prov.XXXXXX")"

REAL_TID="toolu_FIXTUREaaaaaaaa"

mk_pass() { # $1 file  $2 verdict  $3 tool_use_id
  cat > "$1" <<EOF
# stories adversarial pass
<!-- SKILL_INVOCATION_PROVENANCE v1
skill: ai-dlc-adversary-review
invoked_at: 2026-01-02T03:04:05Z
tool_use_id: $3
mode: subagent
lead_role: stories-test-strategy.md
artifact: $(basename "$1")
findings_critical: 0
findings_critical_prior_scope: 0
findings_major: 0
findings_minor: 2
verdict: $2
SKILL_INVOCATION_PROVENANCE_END -->
EOF
}

mk_story_plain() { # $1 file
  cat > "$1" <<EOF
# Story $(basename "$1")

## Acceptance Criteria
- AC(a): does the thing.
EOF
}

# --- converged: real tool_use_id, drift on the story side ---
mkdir -p "$ROOT/converged/stories"
mk_pass "$ROOT/converged/s1-stories-adversarial-p1.md" EXIT_CONDITION_NOT_MET "$REAL_TID"
mk_pass "$ROOT/converged/s1-stories-adversarial-p2.md" EXIT_CONDITION_MET "$REAL_TID"
mk_story_plain "$ROOT/converged/stories/story-1.md"          # no provenance block at all
cat > "$ROOT/converged/stories/story-2.md" <<EOF
# Story story-2.md

## Acceptance Criteria
- AC(a): does another thing.

<!-- SKILL_INVOCATION_PROVENANCE v1
skill: ai-dlc-adversary-review
invoked_at: 2026-01-02T03:04:05Z
tool_use_id: $REAL_TID
mode: subagent
lead_role: stories-test-strategy.md
artifact: stories/story-2.md
findings_critical: 0
findings_major: 0
findings_minor: 2
verdict: EXIT_CONDITION_MET
# hand-written per precedent — note: NO artifact_sha, and this free-text line.
SKILL_INVOCATION_PROVENANCE_END -->
EOF

# --- placeholder: terminal pass could not self-report its tool_use_id ---
mkdir -p "$ROOT/placeholder/stories"
mk_pass "$ROOT/placeholder/s1-stories-adversarial-p2.md" EXIT_CONDITION_MET \
  "populated-by-lead-post-hoc (no toolu_ observable from within the subagent)"
mk_story_plain "$ROOT/placeholder/stories/story-1.md"

# --- unconverged: terminal verdict is not MET ---
mkdir -p "$ROOT/unconverged/stories"
mk_pass "$ROOT/unconverged/s1-stories-adversarial-p1.md" EXIT_CONDITION_NOT_MET "$REAL_TID"
mk_story_plain "$ROOT/unconverged/stories/story-1.md"

echo "$ROOT"
