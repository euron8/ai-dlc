#!/usr/bin/env bash
# reconcile-blocking-list/seed.sh — a consumer with a real in-place core drift, plus two candidate
# reports: one that OMITS the blocker (the bug) and one that names it. run.sh drives the real
# hard-blockers.sh to prove it renders the blocker and its --check catches a report that dropped it.
# Idempotent.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

D_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
C_ROOT="$(cd "$HERE/../.." 2>/dev/null && pwd || true)"
if [ -n "$D_ROOT" ] && [ -f "$D_ROOT/core/skills/ai-dlc-update/reconcile/hard-blockers.sh" ]; then
  HB="$D_ROOT/core/skills/ai-dlc-update/reconcile/hard-blockers.sh"
elif [ -n "$C_ROOT" ] && [ -f "$C_ROOT/.claude/skills/ai-dlc-update/reconcile/hard-blockers.sh" ]; then
  HB="$C_ROOT/.claude/skills/ai-dlc-update/reconcile/hard-blockers.sh"
else
  echo "FIXTURE ERROR: hard-blockers.sh not found in either layout" >&2
  exit 2
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/reconcile-blocking.XXXXXX")" || exit 2
DIST="$WORK/dist"
CONSUMER="$WORK/consumer"
DRIFT_REL="schemas/thing.json"
mkdir -p "$DIST/core/schemas" "$CONSUMER/.claude/schemas"

printf '{\n  "rule": "original"\n}\n' > "$DIST/core/$DRIFT_REL"
git -C "$DIST" init -q
git -C "$DIST" -c user.email=f@f -c user.name=fixture add -A
git -C "$DIST" -c user.email=f@f -c user.name=fixture commit -q -m base
BASE="$(git -C "$DIST" rev-parse HEAD)"

# Consumer edits the core schema IN PLACE → unregistered-drift emits HARD-UNREGISTERED-CORE-DRIFT.
printf '{\n  "rule": "consumer-edited-in-place"\n}\n' > "$CONSUMER/.claude/$DRIFT_REL"

# The BAD report — the bug: it never names the drifted file.
cat > "$WORK/report-bad.md" <<'BAD'
# Reconcile report (fixture)
## Blocking-layer list
None — no unregistered core drift.
BAD

# The GOOD report — it names the blocker's path.
cat > "$WORK/report-good.md" <<GOOD
# Reconcile report (fixture)
## Blocking-layer list
- HARD-UNREGISTERED-CORE-DRIFT  $DRIFT_REL — resolve before apply.
GOOD

cat > "$WORK/env.sh" <<ENV
HB="$HB"
DIST="$DIST"
BASE="$BASE"
THEIRS="$BASE"
CONSUMER="$CONSUMER"
DRIFT_REL="$DRIFT_REL"
REPORT_BAD="$WORK/report-bad.md"
REPORT_GOOD="$WORK/report-good.md"
ENV

printf '%s\n' "$WORK"
