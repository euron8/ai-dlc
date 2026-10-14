#!/usr/bin/env bash
# BL-516 receipt probe: does any PreToolUse hook registered on Edit deny a LEAD edit to consumer
# product code while no gate is open?
#
# Builds one layered-consumer scratch tree (the activation preconditions core-guard checks), then
# drives every Edit-matched hook in templates/settings.json.template with a lead-shaped payload
# (no agent_id), twice:
#   CONTROL  an Edit to a core-manifest path -> core-guard must deny, or this probe cannot measure (exit 9)
#   SUBJECT  an Edit to product code         -> exit 0 if some hook denies it (fixed), 1 if none does (live)
#
# Measured at 0.781.0: CONTROL denied by ai-dlc-core-guard.sh, SUBJECT denied by none -> exit 1.
# Run from the repo root.
set -u
R=$PWD
T=templates/settings.json.template
[ -f "$T" ] && [ -f core/skills/ai-dlc/core-manifest.md ] && [ -f core/skills/ai-dlc-update/reconcile/setup-sites.md ] || exit 9
command -v python3 >/dev/null 2>&1 || exit 9
d=$(mktemp -d)
mkdir -p "$d/_bmad-output" "$d/src" "$d/.claude/skills/ai-dlc/overrides" "$d/.claude/skills/ai-dlc/extensions" \
  "$d/.claude/skills/ai-dlc/steps" "$d/.claude/skills/ai-dlc-update/reconcile"
echo "0.0.0" > "$d/.claude/.ai-dlc-version"
cp core/skills/ai-dlc/core-manifest.md "$d/.claude/skills/ai-dlc/core-manifest.md"
cp core/skills/ai-dlc-update/reconcile/setup-sites.md "$d/.claude/skills/ai-dlc-update/reconcile/setup-sites.md"
printf '# route\nline\n' > "$d/.claude/skills/ai-dlc/steps/route.md"
printf 'line\n' > "$d/src/app.py"
hooks=$(python3 -I -c 'import json,sys
d=json.load(open(sys.argv[1]))
print("\n".join(h["command"].split("/")[-1] for e in d["hooks"].get("PreToolUse",[]) if "Edit" in e.get("matcher","") for h in e["hooks"]))' "$T")
[ -n "$hooks" ] || exit 9
denies() {
  local p="{\"hook_event_name\":\"PreToolUse\",\"tool_name\":\"Edit\",\"session_id\":\"probe\",\"cwd\":\"$d\",\"tool_input\":{\"file_path\":\"$1\",\"old_string\":\"line\",\"new_string\":\"edited\"}}"
  local h o r
  for h in $hooks; do
    [ -f "$R/core/hooks/$h" ] || continue
    o=$(cd "$d" && CLAUDE_PROJECT_DIR="$d" AI_DLC_PROJECT_ROOT="$d" bash "$R/core/hooks/$h" <<<"$p" 2>/dev/null); r=$?
    if [ "$r" -eq 2 ] || grep -q '"deny"' <<<"$o"; then return 0; fi
  done
  return 1
}
denies "$d/.claude/skills/ai-dlc/steps/route.md" || exit 9
denies "$d/src/app.py" && exit 0
exit 1
