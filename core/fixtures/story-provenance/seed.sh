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
#
#   --mixed-into <dir>   build ONLY the mixed-sprint world into <dir> (see mk_mixed) and print
#                        nothing. Each mutant of the mixed arms gets its own fresh world, because
#                        the arms stamp and a world a previous run stamped is not the seeded one.
set -u

REAL_TID="toolu_FIXTUREaaaaaaaa"

mk_pass() { # $1 file  $2 verdict  $3 tool_use_id  [$4 artifact, default the pass's own basename]
  cat > "$1" <<EOF
# stories adversarial pass
<!-- SKILL_INVOCATION_PROVENANCE v1
skill: ai-dlc-adversary-review
invoked_at: 2026-01-02T03:04:05Z
tool_use_id: $3
mode: subagent
lead_role: stories-test-strategy.md
artifact: ${4:-$(basename "$1")}
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

# A one-shot's `artifact:` NAMES THE FIX STORY. That is what the producer writes — measured on
# every bug-fix one-shot the reference consumer holds, each a project-root-relative path to the
# story it reviewed — and it is what Check 17 routes a folded story by. An earlier seed wrote
# the one-shot's OWN basename there, which the writer then accepted because it read nothing.
mk_oneshot() { # $1 file  $2 extra-lines  $3 artifact (the story reviewed)
  cat > "$1" <<EOF
# bug-fix one-shot cynical sweep
<!-- SKILL_INVOCATION_PROVENANCE v1
skill: bmad-review-adversarial-general
invoked_at: 2026-01-02T05:06:07Z
tool_use_id: $REAL_TID
mode: subagent
lead_role: bug-investigation.md
artifact: $3
findings_critical: 0
findings_major: 2
findings_minor: 3
${2}SKILL_INVOCATION_PROVENANCE_END -->
EOF
}

# --- mixed: ONE sprint slot holding a convergence-validated story AND a folded bug-fix story.
#     Paths inside every provenance block are RELATIVE to <dir>, as the producer writes them
#     relative to the project root, so the arms run with <dir> as the working directory.
#
#   s1/stories-adversarial-p{1,2}.md          the convergence series; p2 is MET. Its artifact
#                                             names the stories DIRECTORY, as the consumer's do.
#   s1/stories/story-1-feature.md             the convergence story
#   s1/stories/story-2-fix-thing.md           the folded bug-fix story
#   s1/stories/story-3-unfolded.md            a story NO one-shot names — the one that must not
#                                             reach the lighter arm
#   s1/bug-fix-oneshot-story-2-fix-thing.md   the per-bug one-shot; artifact names story-2
#   s1/bug-fix-oneshot.md                     LEGACY name; artifact names the CONVERGENCE story.
#                                             Check 17 reads no declaration from this name at
#                                             the stories gate, so story-1 stays on its arm.
#   s1/bug-fix-oneshot-story-9-moved.md       a per-bug one-shot whose artifact names a story
#                                             path that no longer exists (the consumer's s299
#                                             shape: the story moved after the review)
mk_mixed() { # $1 dir
  local d="$1"
  mkdir -p "$d/s1/stories"
  mk_pass "$d/s1/stories-adversarial-p1.md" EXIT_CONDITION_NOT_MET "$REAL_TID" "s1/stories/"
  mk_pass "$d/s1/stories-adversarial-p2.md" EXIT_CONDITION_MET "$REAL_TID" "s1/stories/"
  mk_story_plain "$d/s1/stories/story-1-feature.md"
  mk_story_plain "$d/s1/stories/story-2-fix-thing.md"
  mk_story_plain "$d/s1/stories/story-3-unfolded.md"
  mk_oneshot "$d/s1/bug-fix-oneshot-story-2-fix-thing.md" "" "s1/stories/story-2-fix-thing.md"
  mk_oneshot "$d/s1/bug-fix-oneshot.md" "" "s1/stories/story-1-feature.md"
  mk_oneshot "$d/s1/bug-fix-oneshot-story-9-moved.md" "" "s1/stories/story-9-old-name.md"
}

if [ "${1:-}" = "--mixed-into" ]; then
  [ -n "${2:-}" ] || { echo "seed.sh: --mixed-into needs a directory" >&2; exit 2; }
  mk_mixed "$2"
  exit 0
fi

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/story-prov.XXXXXX")"

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

# --- oneshot: the BUG variant. A one-shot review stamps no verdict and cites the bmad skill,
#     so it needs `--profile bug-story-provenance`. Three passes here, and the two decoys are
#     the point: `with-verdict` is a convergence pass wearing the one-shot skill name, and the
#     converged/ pass above is the reverse. Each must be refused by the door it is not for.
mkdir -p "$ROOT/oneshot/stories"
mk_oneshot "$ROOT/oneshot/s1-bug-fix-oneshot.md" "" "$ROOT/oneshot/stories/story-bug-1.md"
mk_oneshot "$ROOT/oneshot/s1-bug-fix-oneshot-with-verdict.md" "verdict: EXIT_CONDITION_MET
" "$ROOT/oneshot/stories/story-bug-1.md"
mk_story_plain "$ROOT/oneshot/stories/story-bug-1.md"

echo "$ROOT"
