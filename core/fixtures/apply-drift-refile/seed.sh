#!/usr/bin/env bash
# apply-drift-refile/seed.sh — a consumer that added a skill to provenance-block.json's known_skills
# IN PLACE (the exact "migrate the drift" chore). run.sh proves apply.sh refiles it to the extension
# and reverts the core schema automatically — no manual step. Idempotent.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
D_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
C_ROOT="$(cd "$HERE/../.." 2>/dev/null && pwd || true)"
if [ -n "$D_ROOT" ] && [ -f "$D_ROOT/core/skills/ai-dlc-update/reconcile/apply.sh" ]; then
  APPLY="$D_ROOT/core/skills/ai-dlc-update/reconcile/apply.sh"
elif [ -n "$C_ROOT" ] && [ -f "$C_ROOT/.claude/skills/ai-dlc-update/reconcile/apply.sh" ]; then
  APPLY="$C_ROOT/.claude/skills/ai-dlc-update/reconcile/apply.sh"
else
  echo "FIXTURE ERROR: apply.sh not found in either layout" >&2; exit 2
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/apply-drift.XXXXXX")" || exit 2
DIST="$WORK/dist"; CONSUMER="$WORK/consumer"
mkdir -p "$DIST/core/schemas" "$CONSUMER/.claude/schemas"

cat > "$DIST/core/schemas/provenance-block.json" <<'JSON'
{
  "schema_id": "SKILL_INVOCATION_PROVENANCE v1",
  "known_skills": [
    "bmad-party-mode"
  ]
}
JSON
printf '9.9.9\n' > "$DIST/VERSION"
git -C "$DIST" init -q
git -C "$DIST" -c user.email=f@f -c user.name=fixture add -A
git -C "$DIST" -c user.email=f@f -c user.name=fixture commit -q -m base
BASE="$(git -C "$DIST" rev-parse HEAD)"

# Consumer added its own persona skill to the core list, in place — the drift.
cat > "$CONSUMER/.claude/schemas/provenance-block.json" <<'JSON'
{
  "schema_id": "SKILL_INVOCATION_PROVENANCE v1",
  "known_skills": [
    "bmad-party-mode",
    "my-persona-skill"
  ]
}
JSON
printf 'version: 0.0.1\ncommit: %s\n' "$BASE" > "$CONSUMER/.claude/.ai-dlc-version"

cat > "$WORK/env.sh" <<ENV
APPLY="$APPLY"
DIST="$DIST"
BASE="$BASE"
CONSUMER="$CONSUMER"
EXT="$CONSUMER/.claude/skills/ai-dlc/extensions/known-skills.json"
SCHEMA="$CONSUMER/.claude/schemas/provenance-block.json"
STAMP="$CONSUMER/.claude/.ai-dlc-version"
ENV

printf '%s\n' "$WORK"
