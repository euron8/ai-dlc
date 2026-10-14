#!/usr/bin/env bash
# BL-514 receipt probe: does ai-dlc-foreground-budget.sh deny a SUBAGENT's foreground poll, while
# still allowing a subagent's readiness retry that declares no timeout?
#
# Builds one scratch project carrying the real detector at scripts/ai-dlc/ (the hook reads its
# default budget there), then drives the hook with PreToolUse Bash payloads:
#   CONTROL  a lead (no agent_id) `bash scripts/ai-dlc/ci-local.sh` at timeout 600000 must be
#            denied, or this probe cannot measure (exit 9)
#   SUBJECT  with agent_id, foreground, timeout 600000:
#              `S=/x; for i in $(seq 1 25); do grep -q EXIT $S/f && break; sleep 10; done`
#                (a loop poll AFTER a prefix, sleeping under the long-sleep threshold) -> deny
#              `cd /x && sleep 200` (a long sleep after a prefix)                      -> deny
#            with agent_id, NO timeout:
#              `for i in $(seq 1 20); do pg_isready && break; sleep 2; done`           -> allow
#   exit 0 when all three hold (fixed), 1 when any does not (live).
#
# Measured at 0.781.0: CONTROL denied, both polls allowed (agent_id exempts them) -> exit 1.
# Run from the repo root.
set -u
H=core/hooks/ai-dlc-foreground-budget.sh
D=core/scripts/validate-steering-budget.sh
[ -f "$H" ] && [ -f "$D" ] || exit 9
command -v jq >/dev/null 2>&1 || exit 9
d=$(mktemp -d)
mkdir -p "$d/scripts/ai-dlc"
cp "$D" "$d/scripts/ai-dlc/validate-steering-budget.sh" || exit 9
# decision <command> <agent_id-or-empty> <timeout-or-null> -> prints deny or allow
decision() {
  local p o
  p=$(jq -nc --arg c "$1" --arg a "$2" --argjson t "$3" \
    '{hook_event_name:"PreToolUse", tool_name:"Bash", tool_input:({command:$c} + (if $t == null then {} else {timeout:$t} end))} + (if $a == "" then {} else {agent_id:$a} end)')
  o=$(env -u AI_DLC_STEERING_BUDGET CLAUDE_PROJECT_DIR="$d" bash "$H" <<<"$p" 2>/dev/null)
  if grep -q '"deny"' <<<"$o"; then echo deny; else echo allow; fi
}
[ "$(decision 'bash scripts/ai-dlc/ci-local.sh' '' 600000)" = deny ] || exit 9
[ "$(decision 'S=/x; for i in $(seq 1 25); do grep -q EXIT $S/f && break; sleep 10; done' a1 600000)" = deny ] || exit 1
[ "$(decision 'cd /x && sleep 200' a1 600000)" = deny ] || exit 1
[ "$(decision 'for i in $(seq 1 20); do pg_isready && break; sleep 2; done' a1 null)" = allow ] || exit 1
exit 0
