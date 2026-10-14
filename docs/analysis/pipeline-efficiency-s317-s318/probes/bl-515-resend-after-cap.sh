#!/usr/bin/env bash
# BL-515 receipt probe: does the shipped dispatch guard refuse a LEAD re-send of an `Agent` call the
# concurrency cap rejected, while still allowing it once an agent of the session has exited?
#
# Seeds one layered-consumer scratch tree and three lead transcripts, the record shapes taken from the
# reference consumer's lead transcripts (assistant tool_use; user tool_result carrying the cap text
# with is_error true; a <task-notification> user record for an agent):
#   (a) a rejected `Party seat 7`, then nothing          -> a re-send must be DENIED
#   (b) (a) plus a non-rejected Agent result after it     -> a re-send must be ALLOWED
#   (c) (a) plus an agent task-notification after it      -> a re-send must be ALLOWED
#   (e) (a), with a DIFFERENT description                 -> ALLOWED (the hold is per description)
# CONTROL: a call with no transcript at all must produce no decision, or the guard denies for some
# other reason and this probe cannot measure (exit 9).
#
# exit 0 fixed (a denied; b, c and e allowed; rule-28.md and the deny state one release condition),
# 1 live, 9 precondition missing.
# Measured at origin/main fe7d5ec2: (a) allowed -> exit 1. Run from the repo root.
set -u
G=core/hooks/ai-dlc-dispatch-guard.sh
[ -f "$G" ] && command -v jq >/dev/null 2>&1 || exit 9
d="$(mktemp -d)"
mkdir -p "$d/.claude/team-roles"
printf 'version: 0.0.0\n' > "$d/.claude/.ai-dlc-version"
printf '{}\n' > "$d/.claude/settings.json"
printf '# Role: dev\n' > "$d/.claude/team-roles/dev.md"
CAP='Concurrent subagent limit reached. You can run 20 subagents at once. Do not retry. If the user wants more concurrent subagents, ask them to increase CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS.'
use() { jq -nc --arg id "$1" --arg d "$2" '{type:"assistant",message:{role:"assistant",content:[{type:"tool_use",id:$id,name:"Agent",input:{description:$d}}]}}'; }
res() { jq -nc --arg id "$1" --arg t "$2" --argjson e "$3" '{type:"user",message:{role:"user",content:[{type:"tool_result",tool_use_id:$id,content:$t,is_error:$e}]}}'; }
note() { jq -nc --arg c "$(printf '<%s>\n<status>completed</status>\n<summary>Agent "Party seat 1" finished</summary>' task-notification)" \
  '{type:"user",origin:{kind:"task-notification"},message:{role:"user",content:$c}}'; }
{ use u1 "Party seat 7"; res u1 "$CAP" true; } > "$d/a.jsonl"
{ cat "$d/a.jsonl"; use u2 "Party seat 8"; res u2 "Async agent launched successfully." false; } > "$d/b.jsonl"
{ cat "$d/a.jsonl"; note; } > "$d/c.jsonl"
decide() { # decide <transcript> [description]; an allow is NO output -- default it to {} so jq says "none"
  local j o
  j="$(jq -nc --arg t "$1" --arg d "${2:-Party seat 7}" '{tool_name:"Agent",transcript_path:$t,
    tool_input:{description:$d,prompt:"Your operating contract is `.claude/team-roles/dev.md`."}}')"
  o="$(CLAUDE_PROJECT_DIR="$d" bash "$G" <<<"$j" 2>/dev/null)"
  [ -n "$o" ] || o='{}'
  jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"$o" 2>/dev/null
}
[ "$(decide /nonexistent-transcript)" = none ] || exit 9
# The rule and the deny must state ONE release condition: rule-28.md carries it, and the guard's
# remedy quotes it verbatim.
COND='an agent of this session has exited since the rejection'
grep -qF "$COND" core/skills/ai-dlc/rule-bodies/rule-28.md || exit 1
grep -qF "$COND" "$G" || exit 1
[ "$(decide "$d/a.jsonl")" = deny ] || exit 1
[ "$(decide "$d/a.jsonl" "Party seat 9")" = none ] || exit 1
[ "$(decide "$d/b.jsonl")" = none ] || exit 1
[ "$(decide "$d/c.jsonl")" = none ] || exit 1
exit 0
