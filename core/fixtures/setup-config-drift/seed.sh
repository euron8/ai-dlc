#!/usr/bin/env bash
# setup-config-drift/seed.sh — build a fake distribution git repo + a consumer tree, so run.sh
# can prove unregistered-drift.sh distinguishes a declared setup-config region (exempt) from an
# in-place edit to the rest of the setup wizard (HARD drift). Idempotent: fresh temp tree each call.
#
# The fake ai-dlc-setup/SKILL.md carries the REAL STEP 2 / STEP 3 headings, so the REAL
# setup-sites.md `setup-model-strategy` site applies to it — this tests the actual declaration,
# not a stand-in. Rename those headings and the fixture breaks loudly, exactly as the real site would.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# Resolve the REAL unregistered-drift.sh (its sibling setup-sites.md is the site manifest it reads).
D_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
C_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if [ -n "$D_ROOT" ] && [ -f "$D_ROOT/core/skills/ai-dlc-update/reconcile/unregistered-drift.sh" ]; then
  SCRIPT="$D_ROOT/core/skills/ai-dlc-update/reconcile/unregistered-drift.sh"
elif [ -n "$C_ROOT" ] && [ -f "$C_ROOT/.claude/skills/ai-dlc-update/reconcile/unregistered-drift.sh" ]; then
  SCRIPT="$C_ROOT/.claude/skills/ai-dlc-update/reconcile/unregistered-drift.sh"
else
  echo "FIXTURE ERROR: unregistered-drift.sh not found in either layout" >&2
  exit 2
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/setup-config-drift.XXXXXX")" || exit 2
DIST="$WORK/dist"
CONSUMER="$WORK/consumer"
REL="skills/ai-dlc-setup/SKILL.md"
mkdir -p "$DIST/core/skills/ai-dlc-setup" "$CONSUMER/.claude/skills/ai-dlc-setup" \
         "$DIST/core/schemas" "$CONSUMER/.claude/schemas"
SCHEMA_REL="schemas/fixture-schema.json"

cat > "$DIST/core/$REL" <<'SKILL'
# ai-dlc-setup (fixture)

## STEP 2: API Tier and Model Strings

Choose a model strategy for this project.

- Full: opus for planning roles, sonnet for implementation.

## STEP 3: Deployment Configuration

Deployment guidance the operator fills at setup.

## STEP 5: Operations Protocol

Fixed rulebook prose. A consumer MUST NOT edit this in place — it is
upstream-owned and `apply` overwrites it.
SKILL

# A schema — an LLM-loaded, overwrite-on-pull core file with NO {token} and no config region, so
# any consumer edit is silent drift the scan must flag HARD.
cat > "$DIST/core/$SCHEMA_REL" <<'SCHEMA'
{
  "schema_id": "FIXTURE v1",
  "rule": "the-strict-original"
}
SCHEMA

# A distribution is a git repo; unregistered-drift.sh reads core@base with `git show`.
git -C "$DIST" init -q
git -C "$DIST" -c user.email=f@f -c user.name=fixture add -A
git -C "$DIST" -c user.email=f@f -c user.name=fixture commit -q -m base
BASE="$(git -C "$DIST" rev-parse HEAD)"

cp "$DIST/core/$REL" "$CONSUMER/.claude/$REL"
cp "$DIST/core/$SCHEMA_REL" "$CONSUMER/.claude/$SCHEMA_REL"

cat > "$WORK/env.sh" <<ENV
SCRIPT="$SCRIPT"
DIST="$DIST"
BASE="$BASE"
CONSUMER="$CONSUMER"
REL="$REL"
SCHEMA_REL="$SCHEMA_REL"
ENV

printf '%s\n' "$WORK"
