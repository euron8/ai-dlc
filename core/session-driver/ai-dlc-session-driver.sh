#!/usr/bin/env bash
# ai-dlc-session-driver.sh — Architecture A auto session chaining (tmux).
#
# Runs an interactive `claude` session inside tmux that YOU steer normally,
# and auto-sheds context with /clear at each ai-dlc handoff — without ending
# your session and without scraping the TUI.
#
#   Detection (hook-pushed files, no TUI scraping):
#     - _bmad-output/handoff-resume.txt  (handoff procedure: the resume prompt)
#     - _bmad-output/.driver/idle        (driver-signal Stop hook: agent idle
#                                          at a pause/handoff => safe to inject)
#   Injection: tmux send-keys "/clear" + bracketed-paste of the resume prompt.
#
# The operator is attached and steers; the driver ONLY automates the handoff
# clear+reseed. Ordinary human pause points (PVC, ambiguity, retro) produce an
# idle with NO handoff sentinel — the driver leaves those to the attached
# operator and keeps watching. Stop the driver with Ctrl-C when the run is done.
#
# STATUS: wired against the skill's handoff sentinel + pause-flag-gated idle
# signal. A full real-skill chained-sprint run is the recommended acceptance
# test before trusting it unattended.
#
# Usage:
#   ./ai-dlc-session-driver.sh "<initial /ai-dlc task>"
#   # in another terminal:  tmux attach -t ai-dlc   (steer freely)
#
# Requires: tmux (brew install tmux). Prereq: the driver-signal Stop hook
# registered AFTER ai-dlc-continue.sh (core/hooks/ai-dlc-driver-signal.sh).

set -uo pipefail

SESSION="${AI_DLC_TMUX_SESSION:-ai-dlc}"
SD="${AI_DLC_STATE_DIR:-_bmad-output}"
DRV="$SD/.driver"
HANDOFF="$SD/handoff-resume.txt"
IDLE="$DRV/idle"
POLL="${AI_DLC_POLL_SECS:-2}"
CLAUDE_FLAGS=(${AI_DLC_CLAUDE_FLAGS:---dangerously-skip-permissions})
export AI_DLC_DRIVER_DIR="$DRV"
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS="${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-1}"

command -v tmux >/dev/null 2>&1 || { echo "error: tmux not found (brew install tmux)"; exit 1; }
[ $# -ge 1 ] || { echo "usage: $0 \"<initial /ai-dlc task>\""; exit 2; }
INITIAL="$1"

mkdir -p "$DRV"
rm -f "$IDLE" "$DRV/turns" "$HANDOFF"

log(){ printf '%s  %s\n' "$(date +%H:%M:%S)" "$*"; }
alive(){ tmux has-session -t "$SESSION" 2>/dev/null; }
# type a single line + Enter
type_line(){ tmux send-keys -t "$SESSION" -l -- "$1"; sleep 0.6; tmux send-keys -t "$SESSION" Enter; }
# paste a (possibly multi-line) block without early submit, then Enter
paste_block(){ printf '%s' "$1" | tmux load-buffer -; tmux paste-buffer -p -t "$SESSION"; sleep 0.4; tmux send-keys -t "$SESSION" Enter; }

tmux kill-session -t "$SESSION" 2>/dev/null || true
tmux new-session -d -s "$SESSION" -x 220 -y 55
tmux send-keys -t "$SESSION" -l -- "claude ${CLAUDE_FLAGS[*]}"; tmux send-keys -t "$SESSION" Enter

log "session '$SESSION' started. Attach to steer:  tmux attach -t $SESSION"
# let the TUI come up; answer a first-run trust dialog defensively (Enter=Yes)
sleep 8; tmux send-keys -t "$SESSION" Enter; sleep 2
rm -f "$IDLE"

type_line "$INITIAL"
log "dispatched initial task"

# Watch loop: inject /clear + resume when a handoff sentinel AND an idle signal
# are both present. handoff-resume.txt is written during the handoff turn; the
# idle signal fires after the lead stops (pause flag set), so requiring both
# guarantees the input box is ready before keystrokes land.
while alive; do
  if [ -f "$HANDOFF" ] && [ -f "$IDLE" ]; then
    RESUME="$(cat "$HANDOFF")"
    rm -f "$HANDOFF" "$IDLE"
    log "handoff detected — injecting /clear + resume (fresh context)"
    type_line "/clear"; sleep 3
    paste_block "$RESUME"
  fi
  sleep "$POLL"
done

log "tmux session ended; driver exiting"
