#!/bin/bash
# AI/DLC Installation Script
# Copies core files into a target project and generates config scaffolding

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="${1:-.}"

echo "AI/DLC Installer"
echo "================"
echo "Target project: $PROJECT_ROOT"
echo ""

# Verify target exists
if [ ! -d "$PROJECT_ROOT" ]; then
  echo "Error: Target directory $PROJECT_ROOT does not exist"
  exit 1
fi

# Verify BMAD is installed
if [ ! -d "$PROJECT_ROOT/_bmad" ]; then
  echo "Warning: BMAD Method not detected in target project."
  echo "AI/DLC requires BMAD Method v6 (npx bmad-method install)."
  echo "Install BMAD first, then re-run this script."
  exit 1
fi

# Create directories
echo "Creating directories..."
mkdir -p "$PROJECT_ROOT/.claude/skills/ai-dlc/steps"
mkdir -p "$PROJECT_ROOT/.claude/skills/ai-dlc-setup"
mkdir -p "$PROJECT_ROOT/.claude/team-roles"
mkdir -p "$PROJECT_ROOT/docs"
mkdir -p "$PROJECT_ROOT/docs/ai-dlc-patterns"
mkdir -p "$PROJECT_ROOT/docs/escalations"
mkdir -p "$PROJECT_ROOT/docs/reviews"
mkdir -p "$PROJECT_ROOT/docs/retro"
mkdir -p "$PROJECT_ROOT/_bmad-output/implementation-artifacts"
mkdir -p "$PROJECT_ROOT/_bmad-output/planning-artifacts/stories"

# Archive existing files that AI/DLC will replace, BEFORE any overwrite.
# Each install gets a timestamped archive so previous backups aren't clobbered.
#
# Two archive layouts within docs/pre-ai-dlc/$ARCHIVE_TS/:
#   - Flat (archive root): files that /ai-dlc-setup Step 0 reads for
#     project-specific config absorption — CLAUDE.md, QUICKSTART.md,
#     coding-conventions.md, team role files.
#   - _divergence/ (mirrors project-relative paths): files that Step 0 does
#     NOT read but that the export tool needs to diff against installed
#     upstream — skill files, step files, setup skill, pattern files.
#     Preserving directory structure lets the export tool walk the tree
#     with `diff -r`.
ARCHIVED=false
ARCHIVE_TS="$(date +%Y%m%d-%H%M%S)"
ARCHIVE_DIR="$PROJECT_ROOT/docs/pre-ai-dlc/$ARCHIVE_TS"

_ensure_archive_root() {
  if [ "$ARCHIVED" = false ]; then
    mkdir -p "$ARCHIVE_DIR"
    echo "Archiving existing files to docs/pre-ai-dlc/$ARCHIVE_TS/..."
    ARCHIVED=true
  fi
}

# Flat archive — Step 0 absorption targets.
archive_if_exists() {
  local file="$1"
  local basename="$(basename "$file")"
  if [ -f "$file" ]; then
    _ensure_archive_root
    cp "$file" "$ARCHIVE_DIR/$basename"
    echo "  Archived $basename"
  fi
}

# Structured archive — preserves the project-relative path under _divergence/.
archive_tree_file() {
  local file="$1"
  local rel_path="${file#$PROJECT_ROOT/}"
  if [ -f "$file" ]; then
    _ensure_archive_root
    local dest_dir="$ARCHIVE_DIR/_divergence/$(dirname "$rel_path")"
    mkdir -p "$dest_dir"
    cp "$file" "$dest_dir/"
    echo "  Archived $rel_path"
  fi
}

# Archive every file in a directory matching a glob, preserving relative path.
archive_tree_glob() {
  local dir="$1"
  local glob="$2"
  if [ -d "$dir" ]; then
    shopt -s nullglob
    for file in "$dir"/$glob; do
      archive_tree_file "$file"
    done
    shopt -u nullglob
  fi
}

# Flat archive (Step 0 absorption targets)
archive_if_exists "$PROJECT_ROOT/CLAUDE.md"
archive_if_exists "$PROJECT_ROOT/QUICKSTART.md"
archive_if_exists "$PROJECT_ROOT/docs/coding-conventions.md"
for role in architect code-reviewer dev pm qa; do
  archive_if_exists "$PROJECT_ROOT/.claude/team-roles/$role.md"
done

# Structured archive (export-tool diff targets)
archive_tree_file "$PROJECT_ROOT/.claude/skills/ai-dlc/SKILL.md"
archive_tree_glob "$PROJECT_ROOT/.claude/skills/ai-dlc/steps" "*.md"
archive_tree_file "$PROJECT_ROOT/.claude/skills/ai-dlc-setup/SKILL.md"
archive_tree_glob "$PROJECT_ROOT/docs/ai-dlc-patterns" "*.md"

if [ "$ARCHIVED" = true ]; then
  echo ""
  echo "  Originals saved to docs/pre-ai-dlc/$ARCHIVE_TS/"
  echo "  The /ai-dlc-setup wizard will absorb your project-specific"
  echo "  content from the most recent archive during configuration."
  echo ""
fi

# Copy core skill files (always overwrite with AI/DLC versions)
echo "Installing AI/DLC skill..."
cp "$SCRIPT_DIR/../core/skills/ai-dlc/SKILL.md" "$PROJECT_ROOT/.claude/skills/ai-dlc/"
cp "$SCRIPT_DIR/../core/skills/ai-dlc/steps/"*.md "$PROJECT_ROOT/.claude/skills/ai-dlc/steps/"

# Copy setup skill (always overwrite with AI/DLC versions)
echo "Installing setup skill..."
cp "$SCRIPT_DIR/../core/skills/ai-dlc-setup/SKILL.md" "$PROJECT_ROOT/.claude/skills/ai-dlc-setup/"

# Install team roles (always overwrite with AI/DLC versions)
echo "Installing team roles..."
for role in architect code-reviewer dev pm qa; do
  cp "$SCRIPT_DIR/../core/team-roles/$role.md" "$PROJECT_ROOT/.claude/team-roles/"
  echo "  $role.md installed"
done

# Install templates (always overwrite with AI/DLC versions)
echo "Installing templates..."
for tmpl in CLAUDE.md QUICKSTART.md; do
  cp "$SCRIPT_DIR/../templates/$tmpl.template" "$PROJECT_ROOT/$tmpl"
  echo "  $tmpl installed"
done

cp "$SCRIPT_DIR/../templates/coding-conventions.md.template" "$PROJECT_ROOT/docs/coding-conventions.md"
echo "  coding-conventions.md installed"

# Copy pattern files for setup reference (always overwrite with AI/DLC versions)
echo "Installing patterns reference..."
cp "$SCRIPT_DIR/../patterns/"*.md "$PROJECT_ROOT/docs/ai-dlc-patterns/"
echo "  Patterns copied to docs/ai-dlc-patterns/ (reference for /ai-dlc-setup)"

# Create feedback log
if [ ! -f "$PROJECT_ROOT/docs/ai-dlc-feedback.md" ]; then
  cat > "$PROJECT_ROOT/docs/ai-dlc-feedback.md" << 'FEEDBACK'
# AI/DLC Feedback Log

Lessons learned from this project that may be generalizable to the
AI/DLC core framework. Reviewed during retros and periodically
contributed back to the upstream AI/DLC project.

## Format

```
## [Date] [Sprint/Context]
**Pattern:** [Name of the generalizable pattern]
**What happened:** [The incident or discovery]
**Current mitigation:** [What this project added]
**Generalizable?:** YES / NO / MAYBE
**If YES:** [How to generalize — what config would other projects need?]
```
FEEDBACK
  echo "  ai-dlc-feedback.md created (feedback loop log)"
fi

echo ""
echo "Installation complete!"
echo ""
echo "IMPORTANT: AI/DLC requires these for autonomous execution:"
echo "  export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1"
echo "  claude --dangerously-skip-permissions"
echo ""
echo "Without these, the pipeline will stall at every action waiting"
echo "for manual approval. See QUICKSTART.md for launch function examples."
echo ""
echo "Next steps:"
echo "1. Open Claude Code in your project directory (with the flags above)"
echo "2. Run /ai-dlc-setup for guided configuration (recommended)"
if [ "$ARCHIVED" = true ]; then
echo "   The wizard will absorb content from your archived files"
fi
echo "   Or manually: search for {template_variable} placeholders"
echo "3. Review patterns in docs/ai-dlc-patterns/ for optional enforcement"
echo "4. Run /ai-dlc to start your first pipeline"
