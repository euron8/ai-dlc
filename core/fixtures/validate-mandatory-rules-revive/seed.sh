#!/usr/bin/env bash
# validate-mandatory-rules-revive/seed.sh — resolve the REAL validate-mandatory-rules.sh +
# sprint-status.sh + schema (both layouts), build a project tree. Prints WORK. Idempotent.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# core/fixtures/<name>/ upstream, tests/fixtures/<name>/ in a consumer — BOTH three dirs below root.
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if   [ -n "$ROOT" ] && [ -f "$ROOT/core/scripts/validate-mandatory-rules.sh" ]; then
  VMR="$ROOT/core/scripts/validate-mandatory-rules.sh"
  SS="$ROOT/core/scripts/sprint-status.sh"
  SCHEMA="$ROOT/core/schemas/sprint-status.json"
elif [ -n "$ROOT" ] && [ -f "$ROOT/scripts/ai-dlc/validate-mandatory-rules.sh" ]; then
  VMR="$ROOT/scripts/ai-dlc/validate-mandatory-rules.sh"
  SS="$ROOT/scripts/ai-dlc/sprint-status.sh"
  SCHEMA="$ROOT/.claude/schemas/sprint-status.json"
else
  echo "FIXTURE ERROR: validate-mandatory-rules.sh not found in either layout" >&2
  exit 2
fi
[ -f "$SS" ]     || { echo "FIXTURE ERROR: sprint-status.sh not found at $SS" >&2; exit 2; }
[ -f "$SCHEMA" ] || { echo "FIXTURE ERROR: sprint-status.json not found at $SCHEMA" >&2; exit 2; }

WORK="$(mktemp -d)"
cat > "$WORK/env.sh" <<EOF
VMR="$VMR"
SS="$SS"
SCHEMA="$SCHEMA"
EOF

# A project root shaped like a real consumer's — enough for the validator to read.
mkdir -p "$WORK/proj/_bmad-output/implementation-artifacts"
mkdir -p "$WORK/proj/_bmad-output/planning-artifacts/stories"

echo "$WORK"
