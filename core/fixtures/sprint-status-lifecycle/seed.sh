#!/usr/bin/env bash
# sprint-status-lifecycle/seed.sh — resolve the REAL sprint-status.sh (which loads the REAL
# schemas/sprint-status.json) so run.sh can prove sprint_id derivation and the atomic freeze+roll.
# Prints the WORK dir. Idempotent.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# core/fixtures/<name>/ upstream, tests/fixtures/<name>/ in a consumer — BOTH three dirs below root.
# (v0.68.1: eight fixtures shipped resolving this one dir too shallow and were green in the
# distribution while failing every consumer's pre-push.)
D_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
C_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if   [ -n "$D_ROOT" ] && [ -f "$D_ROOT/core/scripts/sprint-status.sh" ]; then
  TOOL="$D_ROOT/core/scripts/sprint-status.sh"
  SCHEMA="$D_ROOT/core/schemas/sprint-status.json"
elif [ -n "$C_ROOT" ] && [ -f "$C_ROOT/scripts/sprint-status.sh" ]; then
  TOOL="$C_ROOT/scripts/sprint-status.sh"
  SCHEMA="$C_ROOT/.claude/schemas/sprint-status.json"
else
  echo "FIXTURE ERROR: sprint-status.sh not found in either layout" >&2
  exit 2
fi
[ -f "$SCHEMA" ] || { echo "FIXTURE ERROR: sprint-status.json not found at $SCHEMA" >&2; exit 2; }

WORK="$(mktemp -d)"
cat > "$WORK/env.sh" <<EOF
TOOL="$TOOL"
SCHEMA="$SCHEMA"
EOF

# A project root shaped like a real consumer's.
mkdir -p "$WORK/proj/_bmad-output/implementation-artifacts/sprint-status"
mkdir -p "$WORK/proj/_bmad-output/planning-artifacts/sprint-status"

echo "$WORK"
