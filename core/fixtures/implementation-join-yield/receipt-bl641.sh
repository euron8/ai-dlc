#!/bin/bash
# BL-641 receipt. usage: receipt-bl641.sh [<hook>] [<spelling 1|2>]; run from the repo root.
#   exit 0   on an unreadable transcript a same-session stall run counts up at 31 s spacing,
#            and a different session resets it (the fix is present)
#   exit 1   it does not
#   exit 9   the receipt cannot measure: no hook, or its world could not be built
set -uo pipefail
HOOK="${1:-core/hooks/ai-dlc-continue.sh}"; SP="${2:-1}"
[ -f "$HOOK" ] || HOOK=.claude/hooks/ai-dlc-continue.sh
[ -f "$HOOK" ] || exit 9
[ -f core/fixtures/implementation-join-yield/seed.sh ] || exit 9
drive() { # drive <session-in-state> <session-now> -> prints the state file's count line after one block, 31s after the stored stamp
  local w; w="$(bash core/fixtures/implementation-join-yield/seed.sh transcript)" || return 9
  [ -d "$w/_bmad-output" ] || return 9
  rm -f "$w/transcript.jsonl"
  printf '%s\n%s\n\n%s\n' "$(( $(date +%s) - 31 ))" 2 "$1" > "$w/_bmad-output/pipeline-block-state.txt"
  printf '{"session_id":"%s","transcript_path":"%s"}' "$2" "$w/transcript.jsonl" \
    | CLAUDE_PROJECT_DIR="$w" CLAUDE_CODE_STOP_HOOK_BLOCK_CAP= AI_DLC_PAUSE_ROUTING_SCHEMA="$(pwd)/core/schemas/pause-routing.json" bash "$HOOK" >/dev/null 2>&1
  if [ "$SP" = 1 ]; then sed -n '2p' "$w/_bmad-output/pipeline-block-state.txt"
  else grep -c 'rapid-fire 3/3' "$w/_bmad-output/pipeline-continuation-log.md" 2>/dev/null || true; fi
}
same="$(drive s1 s1)" || exit 9; other="$(drive s1 s2)" || exit 9
if [ "$SP" = 1 ]; then [ "$same" = 3 ] && [ "$other" = 1 ]; else [ "$same" = 1 ] && [ "$other" = 0 ]; fi
