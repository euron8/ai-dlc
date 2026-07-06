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

# -- Team roles (only the 5 AI/DLC roles) --
for role in architect code-reviewer dev pm qa; do
  if [ -f "$PROJECT_ROOT/.claude/team-roles/$role.md" ]; then
    FILES_TO_REMOVE+=(".claude/team-roles/$role.md")
  fi
done

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
for script in validate-provenance-block.sh validate-retro-evidence.sh validate-mandatory-rules.sh validate-ci-gates.sh; do
  if [ -f "$PROJECT_ROOT/scripts/$script" ]; then
    FILES_TO_REMOVE+=("scripts/$script")
  fi
done

# -- CI workflows installed by AI/DLC --
for wf in validate-retro-compliance.yml validate-ci-gates.yml; do
  if [ -f "$PROJECT_ROOT/.github/workflows/$wf" ]; then
    FILES_TO_REMOVE+=(".github/workflows/$wf")
  fi
done

# -- Test fixture templates installed by AI/DLC --
for fixture_dir in check-1c-bypass check-15-bypass check-17-bypass check-h1-recursion; do
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
