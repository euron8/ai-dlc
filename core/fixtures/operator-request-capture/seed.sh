#!/usr/bin/env bash
# operator-request-capture/seed.sh — TWO projects, and the difference between them is the
# whole point.
#
#   fresh/  no pipeline snapshot. This is the state at the very first `/ai-dlc <ask>` of a
#           project, and the state the hook's own early-exit comment names as the one it
#           skips. The sprint kickoff lands HERE, so capture must survive it.
#   live/   an active pipeline. Capture and the pause flag must both happen.
#
# Idempotent.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
D_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
C_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if [ -n "$D_ROOT" ] && [ -f "$D_ROOT/core/hooks/ai-dlc-pause.sh" ]; then
  HOOK="$D_ROOT/core/hooks/ai-dlc-pause.sh"
elif [ -n "$C_ROOT" ] && [ -f "$C_ROOT/.claude/hooks/ai-dlc-pause.sh" ]; then
  HOOK="$C_ROOT/.claude/hooks/ai-dlc-pause.sh"
else
  echo "FIXTURE ERROR: ai-dlc-pause.sh not found in either layout" >&2; exit 2
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/opreq-capture.XXXXXX")" || exit 2
mkdir -p "$WORK/fresh" "$WORK/live/_bmad-output"

# NOTHING is created under fresh/ -- not even _bmad-output. The hook must build the path it
# writes to, because at a project's first /ai-dlc nothing has created it yet.

cat > "$WORK/live/_bmad-output/pipeline-snapshot.md" <<'MD'
# Pipeline Snapshot

## Pipeline Position
current_step: steps/implementation.md
MD

cat > "$WORK/env.sh" <<ENV
HOOK="$HOOK"
FRESH="$WORK/fresh"
LIVE="$WORK/live"
FRESH_REQ="$WORK/fresh/_bmad-output/operator-requests-history.md"
LIVE_REQ="$WORK/live/_bmad-output/operator-requests-history.md"
LIVE_FLAG="$WORK/live/_bmad-output/pipeline-paused.flag"
WORK="$WORK"
ENV

printf '%s\n' "$WORK"
