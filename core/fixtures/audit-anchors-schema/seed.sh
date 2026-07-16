#!/usr/bin/env bash
# audit-anchors-schema/seed.sh — resolve the REAL validate-audit-anchors.sh (which loads the REAL
# schemas/audit-anchors.json) so run.sh can prove the header is rendered from the schema, drift is
# caught, and entries are validated against it. Prints the WORK dir. Idempotent.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# core/fixtures/<name>/ upstream, tests/fixtures/<name>/ in a consumer — BOTH three dirs below root.
D_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
C_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if   [ -n "$D_ROOT" ] && [ -f "$D_ROOT/core/scripts/validate-audit-anchors.sh" ]; then
  VALIDATOR="$D_ROOT/core/scripts/validate-audit-anchors.sh"
elif [ -n "$C_ROOT" ] && [ -f "$C_ROOT/scripts/validate-audit-anchors.sh" ]; then
  VALIDATOR="$C_ROOT/scripts/validate-audit-anchors.sh"
else
  echo "FIXTURE ERROR: validate-audit-anchors.sh not found in either layout" >&2
  exit 2
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/audit-anchors-schema.XXXXXX")" || exit 2
WORK="$(cd "$WORK" && pwd)"

# A malformed schema JSON — used to prove the reader fails CLOSED, never degrades to no-schema.
printf '{ "fields": { "sprint": }, BROKEN\n' > "$WORK/bad-schema.json"

cat > "$WORK/env.sh" <<ENV
VALIDATOR="$VALIDATOR"
WORK="$WORK"
BAD_SCHEMA="$WORK/bad-schema.json"
ENV

printf '%s\n' "$WORK"
