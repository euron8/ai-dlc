#!/usr/bin/env bash
# ai-dlc-session-driver.sh — Architecture A auto session chaining (tmux).
#
# Runs an interactive `claude` session inside tmux that YOU steer normally,
# and auto-sheds context with /clear at each ai-dlc handoff — without ending
# your session and without scraping the TUI.
#
#   Detection : hooks push file signals
#               - _bmad-output/.driver/idle       (Stop hook: agent idle)
#               - _bmad-output/handoff-resume.txt  (skill: auto-continue here)
#               - _bmad-output/awaiting-human.txt  (skill: human pause, stand down)
#   Injection : tmux send-keys "/clear" + bracketed-paste of the resume prompt
#
# STATUS: reference implementation. Mechanics validated by spikes 5/6; the
# real-skill resume path (§9.3 of the spec) is an integration test still owed.
#
# Usage:
#   ./ai-dlc-session-driver.sh "<initial /ai-dlc task>"
#   # in another terminal:  tmux attach -t ai-dlc   (steer freely)
#
# Requires: tmux (brew install tmux), jq not needed. Prereq: the driver-signal
# Stop hook registered (core/hooks/ai-dlc-driver-signal.sh).

set -uo pipefail

SESSION="${AI_DLC_TMUX_SESSION:-ai-dlc}"
SD="${AI_DLC_STATE_DIR:-_bmad-output}"
DRV="$SD/.driver"
HANDOFF="$SD/handoff-resume.txt"
HUMAN="$SD/awaiting-human.txt"
IDLE="$DRV/idle"
POLL="${AI_DLC_POLL_SECS:-2}"
CLAUDE_FLAGS=(${AI_DLC_CLAUDE_FLAGS:---dangerously-skip-permissions})
export AI_DLC_DRIVER_DIR="$DRV"
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS="${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-1}"

command -v tmux >/dev/null 2>&1 || { echo "error: tmux not found (brew install tmux), or use the PTY fallback"; exit 1; }
[ $# -ge 1 ] || { echo "usage: $0 \"<initial /ai-dlc task>\""; exit 2; }
INITIAL="$1"

mkdir -p "$DRV"
rm -f "$IDLE" "$DRV/turns" "$HANDOFF" "$HUMAN"

log(){ printf '%s  %s\n' "$(date +%H:%M:%S)" "$*"; }
alive(){ tmux has-session -t "$SESSION" 2>/dev/null; }

# type a single line + Enter
type_line(){ tmux send-keys -t "$SESSION" -l -- "$1"; sleep 0.6; tmux send-keys -t "$SESSION" Enter; }
# paste a (possibly multi-line) block without early submit, then Enter
paste_block(){ printf '%s' "$1" | tmux load-buffer -; tmux paste-buffer -p -t "$SESSION"; sleep 0.4; tmux send-keys -t "$SESSION" Enter; }

wait_idle(){ # wait until Stop hook marks idle, bounded
  local to="${1:-600}" t=0
  while [ $t -lt "$to" ]; do [ -f "$IDLE" ] && return 0; alive || return 1; sleep 1; t=$((t+1)); done
  return 1
}

tmux kill-session -t "$SESSION" 2>/dev/null || true
tmux new-session -d -s "$SESSION" -x 220 -y 55
tmux send-keys -t "$SESSION" -l -- "claude ${CLAUDE_FLAGS[*]}"; tmux send-keys -t "$SESSION" Enter

log "session '$SESSION' started. Attach to steer:  tmux attach -t $SESSION"
# let the TUI come up; answer a first-run trust dialog defensively (Enter=Yes)
sleep 8; tmux send-keys -t "$SESSION" Enter; sleep 2
rm -f "$IDLE"

# initial task
type_line "$INITIAL"
log "dispatched initial task"

while alive; do
  if [ -f "$HUMAN" ]; then
    log "HUMAN PAUSE: $(cat "$HUMAN" 2>/dev/null) — standing down; attend the session (tmux attach -t $SESSION)"
    printf '\a'                     # terminal bell
    rm -f "$HUMAN"
    # stop auto-injecting until the next handoff sentinel appears
    while alive && [ ! -f "$HANDOFF" ]; do sleep "$POLL"; done
    continue
  fi

  if [ -f "$HANDOFF" ]; then
    log "handoff detected; waiting for agent idle…"
    if wait_idle 900; then
      RESUME="$(cat "$HANDOFF")"; rm -f "$HANDOFF"
      type_line "/clear"; sleep 3
      paste_block "$RESUME"
      rm -f "$IDLE"                 # require a fresh idle before the next inject
      log "injected /clear + resume (fresh context)"
    else
      log "idle wait timed out or session died"
    fi
    continue
  fi

  sleep "$POLL"
done

log "tmux session ended; driver exiting"
