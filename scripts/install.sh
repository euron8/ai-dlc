#!/bin/bash
# AI/DLC Installation Script
# Copies core files into a target project and generates config scaffolding

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="${1:-.}"
AI_DLC_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Read upstream version (semver source of truth)
if [ -f "$AI_DLC_ROOT/VERSION" ]; then
  AI_DLC_VERSION="$(tr -d '[:space:]' < "$AI_DLC_ROOT/VERSION")"
else
  AI_DLC_VERSION="unknown"
fi

# Capture upstream commit sha if installer is running from a git checkout
if git -C "$AI_DLC_ROOT" rev-parse --short HEAD >/dev/null 2>&1; then
  AI_DLC_COMMIT="$(git -C "$AI_DLC_ROOT" rev-parse --short HEAD)"
  if ! git -C "$AI_DLC_ROOT" diff-index --quiet HEAD -- 2>/dev/null; then
    AI_DLC_COMMIT="${AI_DLC_COMMIT}-dirty"
  fi
else
  AI_DLC_COMMIT="unknown"
fi

INSTALL_TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "AI/DLC Installer"
echo "================"
echo "Version: $AI_DLC_VERSION ($AI_DLC_COMMIT)"
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

# Verify jq (required for settings.json merge and hook scripts)
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required but not found on PATH."
  echo "Install jq from your package manager (e.g. apt, dnf, pacman,"
  echo "apk, brew, choco) or https://jqlang.github.io/jq/download/"
  exit 1
fi

# Create directories
echo "Creating directories..."
mkdir -p "$PROJECT_ROOT/.claude/skills/ai-dlc/steps"
mkdir -p "$PROJECT_ROOT/.claude/skills/ai-dlc-setup"
mkdir -p "$PROJECT_ROOT/.claude/skills/ai-dlc-update/reconcile"
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

# Flat archive — consumer-owned files that /ai-dlc-setup Step 0 absorbs.
archive_if_exists "$PROJECT_ROOT/CLAUDE.md"
archive_if_exists "$PROJECT_ROOT/QUICKSTART.md"
archive_if_exists "$PROJECT_ROOT/docs/coding-conventions.md"

# Structured archive — ai-dlc-owned files (reference/diff only, NOT absorbed
# by setup). Upstream is authoritative on reinstall; team roles, skills,
# steps, patterns, and hooks are reset to the installed versions and any
# consumer drift lives only under _divergence/ for historical reference.
archive_tree_file "$PROJECT_ROOT/.claude/skills/ai-dlc/SKILL.md"
archive_tree_glob "$PROJECT_ROOT/.claude/skills/ai-dlc/steps" "*.md"
archive_tree_file "$PROJECT_ROOT/.claude/skills/ai-dlc-setup/SKILL.md"
archive_tree_file "$PROJECT_ROOT/.claude/skills/ai-dlc-update/SKILL.md"
archive_tree_glob "$PROJECT_ROOT/.claude/skills/ai-dlc-update/reconcile" "*"
archive_tree_glob "$PROJECT_ROOT/docs/ai-dlc-patterns" "*.md"
archive_tree_glob "$PROJECT_ROOT/.claude/team-roles" "*.md"
archive_tree_glob "$PROJECT_ROOT/.claude/hooks" "ai-dlc-*.sh"
archive_tree_file "$PROJECT_ROOT/.claude/settings.json"

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
# core skill docs that live at the skill root (not under steps/)
for doc in escalations.md rule-authoring.md; do
  [ -f "$SCRIPT_DIR/../core/skills/ai-dlc/$doc" ] && \
    cp "$SCRIPT_DIR/../core/skills/ai-dlc/$doc" "$PROJECT_ROOT/.claude/skills/ai-dlc/"
done

# Layered rulebook (Rule 27 / spec §7): consumer-owned extensions/ + overrides/.
# ADDITIVE — create if absent and seed the README contract; NEVER overwrite a
# consumer's populated layer (that is the whole point of the split).
echo "Installing rulebook layer scaffolds (extensions/, overrides/)..."
for layer in extensions overrides; do
  mkdir -p "$PROJECT_ROOT/.claude/skills/ai-dlc/$layer"
  if [ ! -f "$PROJECT_ROOT/.claude/skills/ai-dlc/$layer/README.md" ]; then
    cp "$SCRIPT_DIR/../core/skills/ai-dlc/$layer/README.md" \
       "$PROJECT_ROOT/.claude/skills/ai-dlc/$layer/"
    echo "  $layer/ scaffolded"
  else
    echo "  $layer/ preserved (consumer-owned)"
  fi
done

# Copy setup skill (always overwrite with AI/DLC versions)
echo "Installing setup skill..."
cp "$SCRIPT_DIR/../core/skills/ai-dlc-setup/SKILL.md" "$PROJECT_ROOT/.claude/skills/ai-dlc-setup/"

# Copy update skill + reconcile engine (always overwrite — upstream-owned
# tooling, overwrite-safe: the consumer never edits it. This is the SAME skill
# scripts/bootstrap-update-skill.sh lands additively into an already-diverged
# consumer that predates it; shipping it here means fresh installs get the
# distribution->consumer pull path (ai-dlc-update) from day one.)
echo "Installing update skill..."
cp "$SCRIPT_DIR/../core/skills/ai-dlc-update/SKILL.md" "$PROJECT_ROOT/.claude/skills/ai-dlc-update/"
cp "$SCRIPT_DIR/../core/skills/ai-dlc-update/reconcile/"* "$PROJECT_ROOT/.claude/skills/ai-dlc-update/reconcile/"
chmod +x "$PROJECT_ROOT/.claude/skills/ai-dlc-update/reconcile/preclassify.sh"
echo "  ai-dlc-update installed (skill + reconcile engine)"

# Install team roles (always overwrite with AI/DLC versions)
echo "Installing team roles..."
# Glob over every core role file so new roles (analyst, tea, ux, sm, cis,
# protected-path-editor, and any future additions) install automatically —
# no enumerated list to drift from core/team-roles/.
for role_file in "$SCRIPT_DIR/../core/team-roles/"*.md; do
  cp "$role_file" "$PROJECT_ROOT/.claude/team-roles/"
  echo "  $(basename "$role_file") installed"
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

# Install hooks (always overwrite with AI/DLC versions)
echo "Installing hooks..."
mkdir -p "$PROJECT_ROOT/.claude/hooks"
cp "$SCRIPT_DIR/../core/hooks/"*.sh "$PROJECT_ROOT/.claude/hooks/"
chmod +x "$PROJECT_ROOT/.claude/hooks/"*.sh
echo "  hooks installed"

# Install the auto session-chaining driver (operator-run tmux launcher)
mkdir -p "$PROJECT_ROOT/.claude/session-driver"
cp "$SCRIPT_DIR/../core/session-driver/"*.sh "$PROJECT_ROOT/.claude/session-driver/"
chmod +x "$PROJECT_ROOT/.claude/session-driver/"*.sh
echo "  session-driver installed (.claude/session-driver/)"

# Install settings.json
# Fresh project -> copy template. Existing settings.json -> merge in place:
#   * Preserve user-owned permissions, env, mcpServers, etc.
#   * Upsert ai-dlc hook blocks (stale ai-dlc entries from prior installs are
#     stripped before template entries are appended, so reinstalls propagate).
#   * Shallow-merge enabledPlugins; user values win on conflict.
# A block counts as ai-dlc-owned when any inner command references
# .claude/hooks/ai-dlc-*.sh OR the legacy "RULE 3 CONTINUATION MANDATE" echo
# (left over from pre-hook-script versions of this installer).
TEMPLATE_SETTINGS="$SCRIPT_DIR/../templates/settings.json.template"
USER_SETTINGS="$PROJECT_ROOT/.claude/settings.json"

if [ ! -f "$USER_SETTINGS" ]; then
  cp "$TEMPLATE_SETTINGS" "$USER_SETTINGS"
  echo "  settings.json installed"
else
  MERGE_TMP="$(mktemp)"
  if jq -n \
       --slurpfile user "$USER_SETTINGS" \
       --slurpfile tmpl "$TEMPLATE_SETTINGS" '
        ($user[0]) as $u |
        ($tmpl[0]) as $t |

        def is_ai_dlc_block:
          (.hooks // [])
          | any(
              (.command // "") as $c |
              ($c | test("/\\.claude/hooks/ai-dlc-[^/]+\\.sh")) or
              ($c | test("RULE 3 CONTINUATION MANDATE"))
            );

        def strip_ai_dlc:
          map(select(is_ai_dlc_block | not));

        ($u.hooks // {}) as $uh |
        ($t.hooks // {}) as $th |
        (($uh | keys) + ($th | keys) | unique) as $events |

        $u
        | .enabledPlugins = (($t.enabledPlugins // {}) + ($u.enabledPlugins // {}))
        | .hooks = (
            $events
            | map(. as $e | (($uh[$e] // []) | strip_ai_dlc) + ($th[$e] // []) | {($e): .})
            | add
          )
      ' "$USER_SETTINGS" > "$MERGE_TMP"; then
    mv "$MERGE_TMP" "$USER_SETTINGS"
    echo "  settings.json merged (ai-dlc hooks upserted; user config preserved)"
  else
    rm -f "$MERGE_TMP"
    echo "  Error: failed to merge settings.json. Existing file left untouched."
    echo "  Archived copy at docs/pre-ai-dlc/$ARCHIVE_TS/_divergence/.claude/settings.json"
    exit 1
  fi
fi

# Install validation scripts (always overwrite with AI/DLC versions)
echo "Installing validation scripts..."
mkdir -p "$PROJECT_ROOT/scripts"
for script in validate-provenance-block.sh validate-retro-evidence.sh validate-mandatory-rules.sh validate-ci-gates.sh; do
  if [ -f "$SCRIPT_DIR/../core/scripts/$script" ]; then
    cp "$SCRIPT_DIR/../core/scripts/$script" "$PROJECT_ROOT/scripts/"
    chmod +x "$PROJECT_ROOT/scripts/$script"
    echo "  $script installed"
  fi
done

# Install CI workflow templates (copy only if .github/workflows/ exists)
if [ -d "$PROJECT_ROOT/.github/workflows" ]; then
  echo "Installing CI workflow templates..."
  for wf in validate-retro-compliance.yml validate-ci-gates.yml; do
    if [ -f "$SCRIPT_DIR/../core/ci-templates/$wf" ]; then
      cp "$SCRIPT_DIR/../core/ci-templates/$wf" "$PROJECT_ROOT/.github/workflows/"
      echo "  $wf installed"
    fi
  done
else
  echo "Skipping CI workflows (.github/workflows/ not found)"
  echo "  Copy from ai-dlc/core/ci-templates/ when ready"
fi

# Install test fixture templates (always overwrite with AI/DLC versions)
echo "Installing test fixture templates..."
mkdir -p "$PROJECT_ROOT/tests/fixtures"
for fixture_dir in check-1c-bypass check-15-bypass check-17-bypass check-h1-recursion check-manifest-bypass; do
  if [ -d "$SCRIPT_DIR/../core/fixtures/$fixture_dir" ]; then
    mkdir -p "$PROJECT_ROOT/tests/fixtures/$fixture_dir"
    cp "$SCRIPT_DIR/../core/fixtures/$fixture_dir/"* "$PROJECT_ROOT/tests/fixtures/$fixture_dir/"
    chmod +x "$PROJECT_ROOT/tests/fixtures/$fixture_dir/seed.sh" 2>/dev/null || true
    echo "  $fixture_dir/ installed"
  fi
done

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

# Write version stamp so consumers can detect drift from upstream
VERSION_STAMP="$PROJECT_ROOT/.claude/.ai-dlc-version"
# Unified stamp schema (v0.17.0+): two independently-advancing versions.
#   version/commit       -> the rulebook (core) merge-base; advanced by an
#                           ai-dlc-update rulebook apply. This is the pull base.
#   skill_version/commit -> the ai-dlc-update tool itself; advanced by its own
#                           autonomous self-update cycle. Read this to know the
#                           installed skill version.
# At install time both pairs equal the installed distribution version.
cat > "$VERSION_STAMP" <<EOF
version: $AI_DLC_VERSION
commit: $AI_DLC_COMMIT
skill_version: $AI_DLC_VERSION
skill_commit: $AI_DLC_COMMIT
installed_at: $INSTALL_TIMESTAMP
upstream: https://github.com/euron8/ai-dlc
EOF
echo "  .claude/.ai-dlc-version stamped (rulebook $AI_DLC_VERSION @ $AI_DLC_COMMIT; skill $AI_DLC_VERSION)"

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