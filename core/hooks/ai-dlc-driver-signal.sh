#!/usr/bin/env bash
# ai-dlc-driver-signal.sh — Stop hook for Architecture A (auto session chaining).
#
# Pushes handoff/pause detection OUT to a file so the session driver
# (core/session-driver/ai-dlc-session-driver.sh) never scrapes the TUI.
# Additive: runs alongside ai-dlc-continue.sh (Stop hooks stack). Makes NO
# stop/continue decision; exits 0 always, so it can never block the pipeline.
#
# It writes the `.driver/idle` signal ONLY when the pause flag is present —
# i.e. when the lead has genuinely paused or handed off (the same condition
# under which ai-dlc-continue.sh ALLOWS the stop). On a blocked stall (no
# flag; ai-dlc-continue.sh forces continue) it writes nothing, so the driver
# never injects mid-pipeline. The driver then distinguishes a handoff (a
# `.driver/handoff` marker is also present -> inject /clear + /ai-dlc resume)
# from an ordinary human pause point (no marker -> the attached operator
# handles it; the driver keeps watching).
#
# Register in .claude/settings.json AFTER ai-dlc-continue.sh:
#   "Stop": [ { "hooks": [
#     { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/ai-dlc-continue.sh" },
#     { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/ai-dlc-driver-signal.sh" }
#   ] } ]

set -u
cat >/dev/null 2>&1 || true   # drain stdin (unused)

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
PAUSE_FLAG="${PROJECT_DIR}/_bmad-output/pipeline-paused.flag"
DRV="${AI_DLC_DRIVER_DIR:-${PROJECT_DIR}/_bmad-output/.driver}"

# Only signal on a genuine lead-intended pause/handoff (pause flag present).
# A blocked stall has no flag -> write nothing -> driver stays idle.
[ -f "$PAUSE_FLAG" ] || exit 0

mkdir -p "$DRV" 2>/dev/null || exit 0     # fail-open: never block the agent
n=$(cat "$DRV/turns" 2>/dev/null || echo 0)
case "$n" in ''|*[!0-9]*) n=0 ;; esac
echo $((n + 1)) > "$DRV/turns" 2>/dev/null || true
: > "$DRV/idle" 2>/dev/null || true       # "agent idle at a pause/handoff -> safe to inject"

exit 0
