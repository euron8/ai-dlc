#!/bin/bash
# AI/DLC Update-Skill Bootstrap
# One-time, purely-additive landing of the `ai-dlc-update` skill into a
# diverged consumer project — WITHOUT the blunt full-rulebook overwrite that
# install.sh performs.
#
# Why this exists (consumer-sync spec §6.2, the chicken-and-egg):
#   The tool that lands upstream changes SAFELY (ai-dlc-update) must itself
#   first be landed by some OTHER means, because it is not present yet — and
#   the only other landing mechanism, install.sh, is exactly the destructive
#   overwrite ai-dlc-update exists to avoid. So the first install of
#   ai-dlc-update cannot go through install.sh.
#
#   ai-dlc-update is a NET-NEW directory in the consumer
#   (.claude/skills/ai-dlc-update/) — a diverged consumer does not have it.
#   Copying ONLY that directory collides with nothing in the consumer's
#   divergence: safe BECAUSE purely additive. The skill is self-contained
#   (reads only its own files + git + the .ai-dlc-version stamp), so the copy
#   is safe regardless of how far the consumer has diverged.
#
# What this deliberately does NOT do:
#   - Does NOT touch the consumer's rulebook (SKILL.md, steps/, team-roles/).
#   - Does NOT touch the consumer's .claude/.ai-dlc-version stamp. That stamp's
#     `commit`/`version` is the merge-base ai-dlc-update pulls FROM; rewriting
#     it would erase the base and the first pull would diff from nothing.
#   - Does NOT archive or overwrite anything else in the consumer.
#
# After bootstrap, run `/ai-dlc-update` from the consumer. The skill
# self-updates thereafter (spec §6.1) — this bootstrap is needed exactly once
# per consumer.
#
# Usage:
#   scripts/bootstrap-update-skill.sh [project-root] [--force]
#
# Exit codes:
#   0  skill landed (fresh copy, or --force refresh)
#   1  usage / target / source error
#   2  already bootstrapped (dest exists, no --force)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AI_DLC_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PROJECT_ROOT="."
FORCE=false
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
    -*)      echo "Error: unknown flag $arg" >&2; exit 1 ;;
    *)       PROJECT_ROOT="$arg" ;;
  esac
done

# Normalize (strip trailing slash; keep root as "/")
PROJECT_ROOT="${PROJECT_ROOT%/}"
[ -z "$PROJECT_ROOT" ] && PROJECT_ROOT="/"

if [ -f "$AI_DLC_ROOT/VERSION" ]; then
  AI_DLC_VERSION="$(tr -d '[:space:]' < "$AI_DLC_ROOT/VERSION")"
else
  AI_DLC_VERSION="unknown"
fi

SRC="$AI_DLC_ROOT/core/skills/ai-dlc-update"
DEST_PARENT="$PROJECT_ROOT/.claude/skills"
DEST="$DEST_PARENT/ai-dlc-update"

echo "AI/DLC Update-Skill Bootstrap"
echo "============================="
echo "Version: $AI_DLC_VERSION"
echo "Target project: $PROJECT_ROOT"
echo ""

# Source present? (are we in a distribution checkout?)
if [ ! -d "$SRC" ]; then
  echo "Error: source skill not found at $SRC" >&2
  echo "Run this from an ai-dlc distribution checkout." >&2
  exit 1
fi

# Target project present, and actually an ai-dlc consumer?
if [ ! -d "$PROJECT_ROOT" ]; then
  echo "Error: target directory $PROJECT_ROOT does not exist" >&2
  exit 1
fi
if [ ! -d "$PROJECT_ROOT/.claude" ]; then
  echo "Error: $PROJECT_ROOT/.claude not found — is this an ai-dlc consumer?" >&2
  echo "Bootstrap lands ai-dlc-update ALONGSIDE an existing install; it is not" >&2
  echo "a first-time installer. Run install.sh for a fresh project." >&2
  exit 1
fi

# Additive guard — never silently overwrite an existing skill dir.
if [ -d "$DEST" ] && [ "$FORCE" = false ]; then
  echo "Already bootstrapped: $DEST exists."
  echo ""
  echo "The skill self-updates on its own cycle — run /ai-dlc-update and let"
  echo "step 2 (autonomous self-update) refresh it. Re-copy from this"
  echo "distribution only if that path is unavailable:"
  echo "  scripts/bootstrap-update-skill.sh $PROJECT_ROOT --force"
  exit 2
fi

# Land the skill (purely additive: one net-new directory).
mkdir -p "$DEST_PARENT"
if [ "$FORCE" = true ] && [ -d "$DEST" ]; then
  echo "Refreshing existing ai-dlc-update skill (--force)..."
  rm -rf "$DEST"
fi
cp -R "$SRC" "$DEST_PARENT/"
# preclassify.sh is shelled out by the skill's mechanical pre-classify pass.
[ -f "$DEST/reconcile/preclassify.sh" ] && chmod +x "$DEST/reconcile/preclassify.sh"
echo "  Landed .claude/skills/ai-dlc-update/ (skill + reconcile engine)"

# Report the merge-base the skill will pull FROM — but NEVER write it.
STAMP="$PROJECT_ROOT/.claude/.ai-dlc-version"
echo ""
if [ -f "$STAMP" ]; then
  BASE_LINE="$(grep -E '^(commit|version):' "$STAMP" 2>/dev/null | tr '\n' ' ' || true)"
  [ -z "$BASE_LINE" ] && BASE_LINE="$(head -1 "$STAMP")"   # legacy "X.Y.Z @ <sha>"
  echo "Merge-base stamp present (left untouched): $BASE_LINE"
  echo "  ai-dlc-update pulls FROM this base — bootstrap must not rewrite it."
else
  echo "WARNING: no .claude/.ai-dlc-version stamp found."
  echo "  ai-dlc-update needs a merge-base commit to three-way against. With no"
  echo "  stamp the first run cannot tell what upstream content the consumer"
  echo "  already has, and will ask you for it. If you know the install point,"
  echo "  add a stamp before running (see install.sh for the schema)."
fi

echo ""
echo "Bootstrap complete. Next:"
echo "  1. Open Claude Code in $PROJECT_ROOT"
echo "  2. Run /ai-dlc-update    (bare = dry-run report; add 'apply' to land)"
echo ""
echo "Runtime deps the skill shells out to: git, jq. Ensure both are on PATH."
