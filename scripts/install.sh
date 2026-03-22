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
mkdir -p "$PROJECT_ROOT/.claude/team-roles"
mkdir -p "$PROJECT_ROOT/docs"
mkdir -p "$PROJECT_ROOT/_bmad-output/implementation-artifacts"
mkdir -p "$PROJECT_ROOT/_bmad-output/planning-artifacts/stories"
mkdir -p "$PROJECT_ROOT/docs/escalations"
mkdir -p "$PROJECT_ROOT/docs/reviews"
mkdir -p "$PROJECT_ROOT/docs/retro"

# Copy core skill files
echo "Installing AI/DLC skill..."
cp "$SCRIPT_DIR/../core/skills/ai-dlc/SKILL.md" "$PROJECT_ROOT/.claude/skills/ai-dlc/"
cp "$SCRIPT_DIR/../core/skills/ai-dlc/steps/"*.md "$PROJECT_ROOT/.claude/skills/ai-dlc/steps/"

# Copy setup skill
echo "Installing setup skill..."
mkdir -p "$PROJECT_ROOT/.claude/skills/ai-dlc-setup"
cp "$SCRIPT_DIR/../core/skills/ai-dlc-setup/SKILL.md" "$PROJECT_ROOT/.claude/skills/ai-dlc-setup/"

# Archive existing files that AI/DLC will replace
# The setup wizard reads these to absorb project-specific content
ARCHIVED=false
ARCHIVE_DIR="$PROJECT_ROOT/docs/pre-ai-dlc"

archive_if_exists() {
  local file="$1"
  local basename="$(basename "$file")"
  if [ -f "$file" ]; then
    if [ "$ARCHIVED" = false ]; then
      mkdir -p "$ARCHIVE_DIR"
      echo "Archiving existing files to docs/pre-ai-dlc/..."
      ARCHIVED=true
    fi
    cp "$file" "$ARCHIVE_DIR/$basename"
    echo "  Archived $basename"
  fi
}

archive_if_exists "$PROJECT_ROOT/CLAUDE.md"
archive_if_exists "$PROJECT_ROOT/QUICKSTART.md"
archive_if_exists "$PROJECT_ROOT/docs/coding-conventions.md"
for role in architect code-reviewer dev pm qa; do
  archive_if_exists "$PROJECT_ROOT/.claude/team-roles/$role.md"
done

if [ "$ARCHIVED" = true ]; then
  echo ""
  echo "  Originals saved to docs/pre-ai-dlc/"
  echo "  The /ai-dlc-setup wizard will absorb your project-specific"
  echo "  content from these files during configuration."
  echo ""
fi

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

# Copy pattern files for setup reference
echo "Installing patterns reference..."
mkdir -p "$PROJECT_ROOT/docs/ai-dlc-patterns"
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
