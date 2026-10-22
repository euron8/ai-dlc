#!/usr/bin/env bash
# receipt-bl752.sh [hook] -- BL-752's backlog receipt. Drives the REAL advisor gate over a seeded
# transcript (a grant, no advisor call, so every gated call is owed) and asserts, in one run:
#   C  control: knob 0, no tool_use_id -> DENY (the world owes; knob 0 still judges the last scan)
#   N  no tool_use_id, default knob, net shortened to 20s -> SILENT inside 5s, the reason on stderr
#   K  ADVISOR_GATE_NET=1, an id that never lands -> SILENT, stderr renders the 1s figure
#   D  the default net is 300s and an out-of-range knob does not lengthen it
#   T  a teammate Write of the role template to a PASS-1 code-review shard dir -> SILENT
#   F  the same Write plus one `#### ` finding -> DENY
# Exit: 0 = every assertion holds, 1 = BL-752 regressed, 9 = the receipt cannot measure its subject.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
H="${1:-}"
for c in "$H" "$here/../../hooks/ai-dlc-advisor-gate.sh" "$here/../../../.claude/hooks/ai-dlc-advisor-gate.sh"; do
  [ -n "$c" ] && [ -f "$c" ] && { H="$c"; break; }
done
[ -f "$H" ] || exit 9
command -v jq >/dev/null 2>&1 || exit 9
T="$(mktemp -d "${TMPDIR:-/tmp}/bl752.XXXXXX")" || exit 9
P="$T/projects/p"; mkdir -p "$P/s/subagents" || exit 9
G='{"type":"attachment","attachment":{"type":"advisor_tool","available":true,"toolChange":"add","model":"m"}}'
printf '%s\n' "$G" > "$P/s.jsonl" && printf '%s\n' "$G" > "$P/s/subagents/agent-a1.jsonl" || exit 9
push() { jq -cn --arg t "$P/s.jsonl" --arg d "$T" --arg u "$1" \
  '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:"git push -u origin HEAD"},transcript_path:$t,cwd:$d} + (if $u == "" then {} else {tool_use_id:$u} end)'; }
wr() { jq -cn --arg t "$P/s.jsonl" --arg d "$T" --arg f "$T/docs/reviews/s3/shards/3-code-review-abcdef123456/2.md" --arg c "$1" \
  '{hook_event_name:"PreToolUse",tool_name:"Write",tool_input:{file_path:$f,content:$c},transcript_path:$t,cwd:$d,tool_use_id:"tW",agent_id:"a1"}'; }
run() { # <stdin-json> <env...> -> sets O (stdout) E (stderr) S (seconds)
  local j="$1"; shift
  local t0=$SECONDS
  env -u ADVISOR_GATE_REREADS -u ADVISOR_GATE_NET -u ADVISOR_GATE_WINDOW "$@" HOME="$T" CLAUDE_PROJECT_DIR="$T" \
    bash "$H" <<<"$j" > "$T/o" 2> "$T/e"
  O="$(cat "$T/o")"; E="$(cat "$T/e")"; S=$((SECONDS - t0))
}
isdeny() { [ "$(jq -r '.hookSpecificOutput.permissionDecision // ""' <<<"$1" 2>/dev/null)" = deny ]; }
run "$(push '')" ADVISOR_GATE_REREADS=0
isdeny "$O" || exit 9
run "$(push '')" ADVISOR_GATE_NET=20
[ -z "$O" ] && [ "$S" -le 5 ] && grep -qF 'no tool_use_id' <<<"$E" || exit 1
run "$(push tNEVER)" ADVISOR_GATE_NET=1
[ -z "$O" ] && grep -qF 'within the 1s safety net' <<<"$E" || exit 1
# D, behaviourally: the knob block (first `_netcap=` line through its closing `esac`) is run in a
# scratch shell and the cap it leaves is read. Text is never counted: a second `_netcap=` line or a
# block that ignores the knob changes the value this prints.
awk '/^_netcap=/ { on = 1 } on { print } on && /^esac/ { exit }' "$H" > "$T/knob.sh" || exit 9
[ -s "$T/knob.sh" ] || exit 9
cap() { # <knob, or - for unset> -> the cap the block leaves
  if [ "$1" = - ]; then env -u ADVISOR_GATE_NET bash -c '. "$1"; printf "%s" "$_netcap"' _ "$T/knob.sh"
  else ADVISOR_GATE_NET="$1" bash -c '. "$1"; printf "%s" "$_netcap"' _ "$T/knob.sh"; fi
}
[ "$(cap -)" = 300 ] || exit 1
[ "$(cap 7)" = 7 ] || exit 1
[ "$(cap 300)" = 300 ] || exit 1
[ "$(cap 301)" = 300 ] || exit 1
[ "$(cap 0)" = 300 ] || exit 1
TM='# Code review part 2

## Findings

### Critical (must fix before merge)

None.

### Important (should fix, can be follow-up)

None.

### Suggestions (optional improvements)

None.
'
run "$(wr "$TM")" ADVISOR_GATE_REREADS=0
[ -z "$O" ] || exit 1
run "$(wr "$TM
#### null deref in foo
")" ADVISOR_GATE_REREADS=0
isdeny "$O" || exit 1
exit 0
