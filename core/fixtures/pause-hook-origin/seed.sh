#!/usr/bin/env bash
# pause-hook-origin/seed.sh — a project with an ACTIVE pipeline, so the hook is past its
# no-snapshot early exit and every assertion is about the prompt-origin predicate alone.
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

WORK="$(mktemp -d "${TMPDIR:-/tmp}/pause-origin.XXXXXX")" || exit 2
mkdir -p "$WORK/project/_bmad-output"

# The snapshot is what tells the hook a pipeline is active. Without it the hook exits 0
# before reaching the predicate, and every assertion below would pass vacuously.
cat > "$WORK/project/_bmad-output/pipeline-snapshot.md" <<'MD'
# Pipeline Snapshot

## Pipeline Position
current_step: steps/implementation.md
MD

cat > "$WORK/env.sh" <<ENV
HOOK="$HOOK"
PROJECT="$WORK/project"
FLAG="$WORK/project/_bmad-output/pipeline-paused.flag"
LOG="$WORK/project/_bmad-output/pipeline-continuation-log.md"
SNAPSHOT="$WORK/project/_bmad-output/pipeline-snapshot.md"
ENV

printf '%s\n' "$WORK"
