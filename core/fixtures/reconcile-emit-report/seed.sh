#!/usr/bin/env bash
# reconcile-emit-report/seed.sh — a consumer with a real in-place core drift, and three candidate
# reports: one carrying emit-report's rendered mechanical region verbatim, one with NO region, and
# one whose region was hand-edited to drop the blocker. run.sh proves --verify passes the first and
# fails the other two. Idempotent.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

D_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
C_ROOT="$(cd "$HERE/../.." 2>/dev/null && pwd || true)"
if [ -n "$D_ROOT" ] && [ -f "$D_ROOT/core/skills/ai-dlc-update/reconcile/emit-report.sh" ]; then
  EMIT="$D_ROOT/core/skills/ai-dlc-update/reconcile/emit-report.sh"
elif [ -n "$C_ROOT" ] && [ -f "$C_ROOT/.claude/skills/ai-dlc-update/reconcile/emit-report.sh" ]; then
  EMIT="$C_ROOT/.claude/skills/ai-dlc-update/reconcile/emit-report.sh"
else
  echo "FIXTURE ERROR: emit-report.sh not found in either layout" >&2
  exit 2
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/reconcile-emit.XXXXXX")" || exit 2
DIST="$WORK/dist"
CONSUMER="$WORK/consumer"
mkdir -p "$DIST/core/schemas" "$CONSUMER/.claude/schemas"

printf '{\n  "rule": "original"\n}\n' > "$DIST/core/schemas/thing.json"
git -C "$DIST" init -q
git -C "$DIST" -c user.email=f@f -c user.name=fixture add -A
git -C "$DIST" -c user.email=f@f -c user.name=fixture commit -q -m base
BASE="$(git -C "$DIST" rev-parse HEAD)"
THEIRS="$BASE"

# Consumer edits the core schema IN PLACE → a HARD blocker the mechanical region must carry.
printf '{\n  "rule": "consumer-edited"\n}\n' > "$CONSUMER/.claude/schemas/thing.json"

# The driver's rendered region — ground truth.
REGION="$WORK/region.md"
bash "$EMIT" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" > "$REGION" 2>/dev/null

# GOOD: header + the region verbatim.
{ echo "# Reconcile report (fixture)"; echo; cat "$REGION"; } > "$WORK/report-good.md"
# MISSING: no region at all (the narrated-report bug).
{ echo "# Reconcile report (fixture)"; echo; echo "## Blocking-layer"; echo "None."; } > "$WORK/report-missing.md"
# STALE: the region, but with the HARD blocker line hand-deleted (LLM edited a rendered region).
{ echo "# Reconcile report (fixture)"; echo; grep -v 'HARD-UNREGISTERED-CORE-DRIFT' "$REGION"; } > "$WORK/report-stale.md"

cat > "$WORK/env.sh" <<ENV
EMIT="$EMIT"
DIST="$DIST"
BASE="$BASE"
THEIRS="$THEIRS"
CONSUMER="$CONSUMER"
REGION="$REGION"
REPORT_GOOD="$WORK/report-good.md"
REPORT_MISSING="$WORK/report-missing.md"
REPORT_STALE="$WORK/report-stale.md"
ENV

printf '%s\n' "$WORK"
