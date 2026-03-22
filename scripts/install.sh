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

# Copy team roles (don't overwrite if they exist)
echo "Installing team roles..."
for role in architect code-reviewer dev pm qa; do
  if [ -f "$PROJECT_ROOT/.claude/team-roles/$role.md" ]; then
    echo "  $role.md already exists — skipping (see core/team-roles/$role.md for reference)"
  else
    cp "$SCRIPT_DIR/../core/team-roles/$role.md" "$PROJECT_ROOT/.claude/team-roles/"
    echo "  $role.md installed"
  fi
done

# Copy templates (don't overwrite if they exist)
echo "Installing templates..."
for tmpl in CLAUDE.md QUICKSTART.md; do
  if [ -f "$PROJECT_ROOT/$tmpl" ]; then
    echo "  $tmpl already exists — template saved to docs/ai-dlc-$tmpl.template"
    cp "$SCRIPT_DIR/../templates/$tmpl.template" "$PROJECT_ROOT/docs/ai-dlc-$tmpl.template"
  else
    # Remove .template extension for the installed copy
    cp "$SCRIPT_DIR/../templates/$tmpl.template" "$PROJECT_ROOT/$tmpl"
    echo "  $tmpl installed (customize template variables)"
  fi
done

if [ -f "$PROJECT_ROOT/docs/coding-conventions.md" ]; then
  echo "  coding-conventions.md already exists — template saved to docs/ai-dlc-coding-conventions.md.template"
  cp "$SCRIPT_DIR/../templates/coding-conventions.md.template" "$PROJECT_ROOT/docs/ai-dlc-coding-conventions.md.template"
else
  cp "$SCRIPT_DIR/../templates/coding-conventions.md.template" "$PROJECT_ROOT/docs/coding-conventions.md"
  echo "  coding-conventions.md installed (customize template variables)"
fi

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
echo "Next steps:"
echo "1. Open Claude Code in your project directory"
echo "2. Run /ai-dlc-setup for guided configuration (recommended)"
echo "   Or manually: search for {template_variable} placeholders"
echo "3. Review patterns in docs/ai-dlc-patterns/ for optional enforcement"
echo "4. Run /ai-dlc to start your first pipeline"
echo ""
echo "Template variables to configure:"
grep -rh '{[a-z_]*}' "$PROJECT_ROOT/.claude/skills/ai-dlc/" "$PROJECT_ROOT/.claude/team-roles/" 2>/dev/null | sort -u | head -20 || true
