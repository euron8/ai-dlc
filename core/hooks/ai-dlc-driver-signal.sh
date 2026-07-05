#!/usr/bin/env bash
# ai-dlc-driver-signal.sh — Stop hook for Architecture A (auto session chaining).
#
# Pushes turn-done detection OUT to files so the session driver
# (core/session-driver/ai-dlc-session-driver.sh) never has to scrape the TUI.
# Additive: runs alongside ai-dlc-continue.sh with no coupling (Stop hooks
# stack). This hook makes NO stop/continue decision — it only records that the
# agent went idle. exit 0 always, so it can never block or stall the pipeline.
#
# Register in .claude/settings.json:
#   "hooks": { "Stop": [ { "hooks": [
#     { "type": "command", "command": ".claude/hooks/ai-dlc-continue.sh" },
#     { "type": "command", "command": ".claude/hooks/ai-dlc-driver-signal.sh" }
#   ] } ] }

set -uo pipefail

# Consume stdin JSON (unused, but drain it so the hook contract is clean).
cat >/dev/null 2>&1 || true

DRV="${AI_DLC_DRIVER_DIR:-_bmad-output/.driver}"
mkdir -p "$DRV" 2>/dev/null || exit 0   # fail-open: never block the agent

n=$(cat "$DRV/turns" 2>/dev/null || echo 0)
case "$n" in ''|*[!0-9]*) n=0 ;; esac
echo $((n + 1)) > "$DRV/turns" 2>/dev/null || true
: > "$DRV/idle" 2>/dev/null || true       # touch: "agent is idle -> safe to inject"

exit 0
