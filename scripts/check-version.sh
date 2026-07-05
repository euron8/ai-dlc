#!/bin/bash
# AI/DLC version check
# Compares the installed .claude/.ai-dlc-version stamp in a consumer
# project against the upstream VERSION file on the AI/DLC main branch.
#
# Usage:
#   scripts/check-version.sh [project-root]
#
# Exit codes:
#   0  up to date
#   1  drift detected (upstream is newer or commits differ)
#   2  missing stamp / cannot determine
#   3  network or upstream fetch failure

set -e

PROJECT_ROOT="${1:-.}"
STAMP="$PROJECT_ROOT/.claude/.ai-dlc-version"
UPSTREAM_RAW="https://raw.githubusercontent.com/euron8/ai-dlc/main/VERSION"

if [ ! -f "$STAMP" ]; then
  echo "No version stamp at $STAMP"
  echo "This project was either not installed via scripts/install.sh"
  echo "or was installed before versioning landed (pre-0.1.0)."
  echo "Re-run install.sh from an up-to-date ai-dlc checkout to stamp it."
  exit 2
fi

LOCAL_VERSION="$(awk -F': ' '/^version:/ {print $2}' "$STAMP" | tr -d '[:space:]')"
LOCAL_COMMIT="$(awk -F': ' '/^commit:/ {print $2}' "$STAMP" | tr -d '[:space:]')"
LOCAL_SKILL_VERSION="$(awk -F': ' '/^skill_version:/ {print $2}' "$STAMP" | tr -d '[:space:]')"
LOCAL_INSTALLED="$(awk -F': ' '/^installed_at:/ {print $2}' "$STAMP" | tr -d '[:space:]')"

# Legacy single-line stamp fallback: "X.Y.Z @ <sha>" (pre-0.17.0 / early
# ai-dlc-update re-stamps). Parse it so drift-check still works pre-migration.
if [ -z "$LOCAL_VERSION" ] && grep -q ' @ ' "$STAMP" 2>/dev/null; then
  LOCAL_VERSION="$(awk -F' @ ' 'NR==1 {print $1}' "$STAMP" | tr -d '[:space:]')"
  LOCAL_COMMIT="$(awk -F' @ ' 'NR==1 {print $2}' "$STAMP" | tr -d '[:space:]')"
fi

if [ -z "$LOCAL_VERSION" ]; then
  echo "Stamp at $STAMP is malformed (no version field)."
  exit 2
fi
[ -z "$LOCAL_SKILL_VERSION" ] && LOCAL_SKILL_VERSION="(unknown — pre-0.17.0 stamp)"

if ! command -v curl >/dev/null 2>&1; then
  echo "curl required to fetch upstream VERSION."
  exit 3
fi

UPSTREAM_VERSION="$(curl -fsSL "$UPSTREAM_RAW" 2>/dev/null | tr -d '[:space:]')" || {
  echo "Failed to fetch upstream VERSION from $UPSTREAM_RAW"
  exit 3
}

echo "Local rulebook: $LOCAL_VERSION ($LOCAL_COMMIT, installed $LOCAL_INSTALLED)"
echo "Local skill:    $LOCAL_SKILL_VERSION (ai-dlc-update)"
echo "Upstream:       $UPSTREAM_VERSION (main)"
echo ""

if [ "$LOCAL_VERSION" = "$UPSTREAM_VERSION" ]; then
  echo "Up to date."
  exit 0
fi

echo "Drift detected: $LOCAL_VERSION → $UPSTREAM_VERSION"
echo ""
echo "See changes:"
echo "  https://github.com/euron8/ai-dlc/blob/main/CHANGELOG.md"
echo ""
echo "Upgrade:"
echo "  cd <ai-dlc checkout> && git pull && ./scripts/install.sh $PROJECT_ROOT"
exit 1
