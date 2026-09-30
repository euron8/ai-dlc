#!/usr/bin/env bash
# foreground-budget-deny/seed.sh — build the project trees run.sh drives the REAL
# ai-dlc-foreground-budget.sh hook against.
#
# Three projects, because the hook takes its default budget from the detector on disk:
#   REAL   — scripts/ai-dlc/validate-steering-budget.sh is a byte copy of the shipped
#            detector, so the default the hook reads is the one the detector counts with.
#   SHIFT  — the same copy with its default budget line changed to 60. A hook that carries
#            its own `120` instead of reading the detector answers differently here.
#   NONE   — no detector at all. The hook has no default to hold a call to.
#
# Both layouts are named: the distribution (core/hooks/, core/scripts/) and a consumer
# (.claude/hooks/, scripts/ai-dlc/), rooted at this fixture's own location.
#
# Prints the WORK dir on stdout. Idempotent: a fresh temp tree each call.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if [ -n "$ROOT" ] && [ -f "$ROOT/core/hooks/ai-dlc-foreground-budget.sh" ] \
   && [ -f "$ROOT/core/scripts/validate-steering-budget.sh" ]; then
  HOOK="$ROOT/core/hooks/ai-dlc-foreground-budget.sh"
  DETECTOR="$ROOT/core/scripts/validate-steering-budget.sh"
elif [ -n "$ROOT" ] && [ -f "$ROOT/.claude/hooks/ai-dlc-foreground-budget.sh" ] \
   && [ -f "$ROOT/scripts/ai-dlc/validate-steering-budget.sh" ]; then
  HOOK="$ROOT/.claude/hooks/ai-dlc-foreground-budget.sh"
  DETECTOR="$ROOT/scripts/ai-dlc/validate-steering-budget.sh"
else
  echo "FIXTURE ERROR: ai-dlc-foreground-budget.sh and validate-steering-budget.sh not found together in either layout" >&2
  exit 2
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/foreground-budget.XXXXXX")" || exit 2
WORK="$(cd "$WORK" && pwd)"

mkdir -p "$WORK/real/scripts/ai-dlc" "$WORK/shift/scripts/ai-dlc" "$WORK/none" "$WORK/mut" || exit 2
cp "$DETECTOR" "$WORK/real/scripts/ai-dlc/validate-steering-budget.sh" || exit 2
sed 's/^BUDGET="\${AI_DLC_STEERING_BUDGET:-120}"$/BUDGET="${AI_DLC_STEERING_BUDGET:-60}"/' \
  "$DETECTOR" > "$WORK/shift/scripts/ai-dlc/validate-steering-budget.sh" || exit 2
if cmp -s "$DETECTOR" "$WORK/shift/scripts/ai-dlc/validate-steering-budget.sh"; then
  echo "FIXTURE ERROR: the detector's default budget line is no longer 'BUDGET=\"\${AI_DLC_STEERING_BUDGET:-120}\"', so the SHIFT world could not be built. If the default moved, move this seed with it; if the line was respelled, the hook reads it too and must move as well." >&2
  exit 2
fi

cat > "$WORK/env.sh" <<ENV
HOOK="$HOOK"
DETECTOR="$DETECTOR"
REAL="$WORK/real"
SHIFT="$WORK/shift"
NONE="$WORK/none"
MUT="$WORK/mut"
ENV

printf '%s\n' "$WORK"
