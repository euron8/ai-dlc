#!/usr/bin/env bash
# receipt-bl794.sh [hook] -- BL-794's backlog receipt. Drives the REAL protect hook with a
# ctx_batch_execute JSON on stdin, in a scratch project whose layer file protects
# docs/architecture.md, and asserts on the deny's output:
#   b  it does NOT say 'NOT protected' (core cannot know a consumer's layer)
#   c  it DOES say 'Use the native Read tool' (so a hook that emits nothing fails)
# Exit: 0 = BL-794 fixed, 1 = regressed, 9 = the receipt cannot measure its subject.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
H="${1:-}"
for c in "$H" "$here/../../hooks/ai-dlc-protect.sh" "$here/../../../.claude/hooks/ai-dlc-protect.sh"; do
  [ -n "$c" ] && [ -f "$c" ] && { H="$c"; break; }
done
[ -f "$H" ] || exit 9
command -v jq >/dev/null 2>&1 || exit 9
T="$(mktemp -d "${TMPDIR:-/tmp}/bl794.XXXXXX")" || exit 9
mkdir -p "$T/.claude/skills/ai-dlc/extensions" "$T/docs" "$T/_bmad-output" || exit 9
printf '%s\n' '{"protected_paths":["docs/architecture.md"],"excluded_paths":[]}' \
  > "$T/.claude/skills/ai-dlc/extensions/protected-paths.json" || exit 9
J="$(jq -nc --arg c 'cat docs/architecture.md' '{tool_name:"mcp__plugin_context-mode_context-mode__ctx_batch_execute",tool_input:{commands:[{label:"l",command:$c}]}}')" || exit 9
O="$(printf '%s' "$J" | CLAUDE_PROJECT_DIR="$T" bash "$H" 2>/dev/null)"
# Control: the layered path is denied, so the output is the deny under test and not an allow.
grep -q '"permissionDecision": *"deny"' <<<"$O" || exit 9
grep -qF 'NOT protected' <<<"$O" && exit 1
grep -qF 'Use the native Read tool' <<<"$O" || exit 1
exit 0
