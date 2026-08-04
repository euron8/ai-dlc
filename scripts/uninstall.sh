#!/bin/bash
# AI/DLC Uninstall Script
# Removes all AI/DLC components from a target project.
# Does NOT remove BMAD Method or _bmad-output/ (planning artifacts are yours).

set -e

PROJECT_ROOT="${1:-.}"
FORCE=false

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
  esac
done

# Normalize PROJECT_ROOT (strip trailing slash, resolve path)
PROJECT_ROOT="${PROJECT_ROOT%/}"

echo "AI/DLC Uninstaller"
echo "=================="
echo "Target project: $PROJECT_ROOT"
echo ""

# Verify target exists
if [ ! -d "$PROJECT_ROOT" ]; then
  echo "Error: Target directory $PROJECT_ROOT does not exist"
  exit 1
fi

# Verify AI/DLC is installed
if [ ! -f "$PROJECT_ROOT/.claude/skills/ai-dlc/SKILL.md" ]; then
  echo "AI/DLC does not appear to be installed in this project."
  echo "(Expected: .claude/skills/ai-dlc/SKILL.md)"
  exit 1
fi

# Build removal list
echo "The following will be removed:"
echo ""

DIRS_TO_REMOVE=()
FILES_TO_REMOVE=()

# -- Skills --
if [ -d "$PROJECT_ROOT/.claude/skills/ai-dlc" ]; then
  DIRS_TO_REMOVE+=(".claude/skills/ai-dlc/")
fi
if [ -d "$PROJECT_ROOT/.claude/skills/ai-dlc-setup" ]; then
  DIRS_TO_REMOVE+=(".claude/skills/ai-dlc-setup/")
fi
if [ -d "$PROJECT_ROOT/.claude/skills/ai-dlc-update" ]; then
  DIRS_TO_REMOVE+=(".claude/skills/ai-dlc-update/")
fi

# -- Team roles (all AI/DLC role files; team-roles/ is ai-dlc-owned) --
if [ -d "$PROJECT_ROOT/.claude/team-roles" ]; then
  for role_file in "$PROJECT_ROOT/.claude/team-roles/"*.md; do
    [ -f "$role_file" ] || continue
    FILES_TO_REMOVE+=(".claude/team-roles/$(basename "$role_file")")
  done
fi

# -- Templates installed to root --
for file in CLAUDE.md QUICKSTART.md; do
  if [ -f "$PROJECT_ROOT/$file" ]; then
    FILES_TO_REMOVE+=("$file")
  fi
done

# -- Docs installed by AI/DLC --
if [ -f "$PROJECT_ROOT/docs/coding-conventions.md" ]; then
  FILES_TO_REMOVE+=("docs/coding-conventions.md")
fi
if [ -f "$PROJECT_ROOT/docs/ai-dlc-feedback.md" ]; then
  FILES_TO_REMOVE+=("docs/ai-dlc-feedback.md")
fi
if [ -d "$PROJECT_ROOT/docs/ai-dlc-patterns" ]; then
  DIRS_TO_REMOVE+=("docs/ai-dlc-patterns/")
fi

# -- Template backup files (created when install.sh finds existing files) --
for file in docs/ai-dlc-CLAUDE.md.template docs/ai-dlc-QUICKSTART.md.template docs/ai-dlc-coding-conventions.md.template; do
  if [ -f "$PROJECT_ROOT/$file" ]; then
    FILES_TO_REMOVE+=("$file")
  fi
done

# -- Escalations file (only if it's the default empty one) --
if [ -f "$PROJECT_ROOT/docs/escalations/pending.md" ]; then
  FILES_TO_REMOVE+=("docs/escalations/pending.md")
fi

# -- Validation scripts installed by AI/DLC --
# The whole directory, because the whole directory is ours -- that is the point of
# scripts/ai-dlc/, and what core-manifest.md's `scripts/ai-dlc/*` entry claims.
#
# This used to be a hand-list of FOUR names against the full set install.sh ships, so
# an uninstall left almost every core validator behind and reported success. The list
# was the bug, exactly as it was for map_consumer() in v0.55.2, and exactly as the
# manifest's own enumeration of the same directory was until v0.160.0. A directory
# needs no list, and a de-numbered comment cannot go stale the way the last one did.
if [ -d "$PROJECT_ROOT/scripts/ai-dlc" ]; then
  DIRS_TO_REMOVE+=("scripts/ai-dlc")
fi

# -- CI workflows installed by AI/DLC --
for wf in validate-retro-compliance.yml validate-ci-gates.yml; do
  if [ -f "$PROJECT_ROOT/.github/workflows/$wf" ]; then
    FILES_TO_REMOVE+=(".github/workflows/$wf")
  fi
done

# -- Local pre-push gate installed by AI/DLC --
# Paired with install.sh's copy. Note we remove the FILE but never touch
# `core.hooksPath`: the operator set that, not us, and they may point it at hooks of
# their own.
if [ -f "$PROJECT_ROOT/.githooks/pre-push" ]; then
  FILES_TO_REMOVE+=(".githooks/pre-push")
fi

# -- Test fixture templates installed by AI/DLC --
# MUST stay identical to install.sh's fixture loop, or uninstall silently orphans the
# fixtures it does not name. It had already drifted: install shipped nine, this listed
# five. `scripts/validate-enforcement-map.sh` (I8) now asserts the two lists and
# core/fixtures/ agree, so the next fixture cannot be added to one loop only.
for fixture_dir in check-1c-bypass check-15-bypass check-17-bypass check-17-counts check-3b-locked-anchor check-23-draft-stamps check-24-adversarial-convergence adversarial-citation escalation-citation extension-check-adoption check-25-steering-conduct check-h1-recursion check-manifest-bypass context-sensor layer-anchor-declaration layer-catalog-collision layer-contract-conformance layer-readopt-gate handoff-resume-guard divergence-hard-block taught-schema gate-adjudication self-update-gate setup-config-drift relabel-theirs-collision known-skills-extension reconcile-blocking-list reconcile-emit-report apply-drift-refile apply-drift-after-write apply-restamp-theirs escalation-status-vocabulary askuserquestion-citation command-args-citation pause-hook-origin core-write-guard audit-anchors-schema dispatch-model-guard subagent-probe sprint-status-lifecycle route-defect-classification story-provenance implementation-join-yield wait-stale-deliverable validate-mandatory-rules-revive mandatory-rules-clean-tree check5-anchor-base check-22-spawn-ledger cycle-commits-enforce ledger-reverify ledger-status-vocabulary ledger-reverify-unfalsifiable ledger-rotate snapshot-section-schema resume-whole-read retired-contract-token retired-layer-contract retired-fixture-orphan consumer-machinery-inventory retro-audit-scans context-mode-protect verdict-pass-content provenance-not-accessible snapshot-evidence-cell inflight-row-shape whole-read-pool release-version-triple core-script-boundary apply-legacy-script-path validator-path-resolution relocation-preclassify ci-gates-resolution shadowed-local-validators h2-attest-scripts-dir gate-verdict-grep-shape blocker-adjudication-record bmad-invocation-resolve check-31-ac-falsifiability spec-adoption-floor spec-join-integrity consumer-machinery-home layer-qualifier-grain layer-extends-grain layer-retired-id-crosswalk layer-crosswalk-home layer-reference-resolution layer-conforms-to layer-adjudication-tier stray-party-mode-provenance core-paths-audit-diff mutation-red-replay trunk-push-bound trunk-audit-classes story-fields-derive fixture-drivability consumer-suite-pool; do
  if [ -d "$PROJECT_ROOT/tests/fixtures/$fixture_dir" ]; then
    DIRS_TO_REMOVE+=("tests/fixtures/$fixture_dir/")
  fi
done

# Print what we found
for dir in "${DIRS_TO_REMOVE[@]}"; do
  echo "  [dir]  $dir"
done
for file in "${FILES_TO_REMOVE[@]}"; do
  echo "  [file] $file"
done

echo ""
echo "The following will NOT be removed:"
echo "  _bmad/                    (BMAD Method — uninstall separately)"
echo "  _bmad-output/             (your planning/implementation artifacts)"
echo "  docs/reviews/             (your code review output)"
echo "  docs/retro/               (your retrospectives)"
echo "  docs/escalations/         (directory preserved, pending.md removed)"
echo ""

# Confirm
if [ "$FORCE" != true ]; then
  read -p "Proceed with uninstall? [y/N] " confirm
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Aborted."
    exit 0
  fi
fi

echo ""
echo "Removing AI/DLC components..."

# Remove directories
for dir in "${DIRS_TO_REMOVE[@]}"; do
  rm -rf "$PROJECT_ROOT/$dir"
  echo "  Removed $dir"
done

# Remove files
for file in "${FILES_TO_REMOVE[@]}"; do
  rm -f "$PROJECT_ROOT/$file"
  echo "  Removed $file"
done

# Restore archived originals from the most recent archive
RESTORED=false
ARCHIVE_BASE="$PROJECT_ROOT/docs/pre-ai-dlc"
if [ -d "$ARCHIVE_BASE" ]; then
  # Find the most recent timestamped subdirectory
  LATEST_ARCHIVE="$(ls -d "$ARCHIVE_BASE"/*/ 2>/dev/null | sort | tail -1)"

  # Fall back to the base dir if no subdirectories (legacy format)
  if [ -z "$LATEST_ARCHIVE" ]; then
    LATEST_ARCHIVE="$ARCHIVE_BASE"
  fi

  echo ""
  echo "Restoring archived originals from $(basename "$LATEST_ARCHIVE")..."
  for file in "$LATEST_ARCHIVE"/*; do
    [ -f "$file" ] || continue
    basename="$(basename "$file")"
    case "$basename" in
      CLAUDE.md|QUICKSTART.md)
        cp "$file" "$PROJECT_ROOT/$basename"
        echo "  Restored $basename"
        RESTORED=true
        ;;
      coding-conventions.md)
        mkdir -p "$PROJECT_ROOT/docs"
        cp "$file" "$PROJECT_ROOT/docs/$basename"
        echo "  Restored docs/$basename"
        RESTORED=true
        ;;
      architect.md|code-reviewer.md|dev.md|pm.md|qa.md)
        mkdir -p "$PROJECT_ROOT/.claude/team-roles"
        cp "$file" "$PROJECT_ROOT/.claude/team-roles/$basename"
        echo "  Restored .claude/team-roles/$basename"
        RESTORED=true
        ;;
    esac
  done
  rm -rf "$ARCHIVE_BASE"
  echo "  Removed docs/pre-ai-dlc/ archive directory"
fi

# Clean up empty directories (don't remove if they still have content)
for dir in .claude/skills .claude/team-roles .claude docs/escalations docs; do
  if [ -d "$PROJECT_ROOT/$dir" ] && [ -z "$(ls -A "$PROJECT_ROOT/$dir")" ]; then
    rmdir "$PROJECT_ROOT/$dir"
    echo "  Removed empty directory $dir/"
  fi
done

echo ""
echo "Uninstall complete."
echo ""
if [ "$RESTORED" = true ]; then
  echo "Restored original files from pre-ai-dlc archive."
fi
echo "Preserved:"
echo "  - _bmad-output/ (your planning artifacts)"
echo "  - docs/reviews/ (your code review output)"
echo "  - docs/retro/ (your retrospectives)"
echo "  - Any non-AI/DLC files in .claude/"
echo ""
echo "To also remove BMAD Method: rm -rf _bmad/"
echo "To remove planning artifacts: rm -rf _bmad-output/"
