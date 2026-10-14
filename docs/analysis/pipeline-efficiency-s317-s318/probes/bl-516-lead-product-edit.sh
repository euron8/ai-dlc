#!/usr/bin/env bash
# BL-516 receipt probe: does a PreToolUse hook registered on Edit deny a LEAD edit to consumer
# product code, in an /ai-dlc pipeline session, while NO gate directory exists -- and only then?
#
# Builds one layered-consumer scratch tree (the activation preconditions core-guard checks, a
# pipeline snapshot, no gate-adjudication directory) and two transcripts in the harness's own
# record shapes: one carrying a typed `/ai-dlc` invocation followed by the router Read (so
# `ai-dlc-acknowledge.sh`'s router-not-read check stands down), and one carrying no invocation.
# Then drives every Edit-matched hook in templates/settings.json.template with a lead-shaped
# payload (no agent_id):
#   CONTROL   an Edit to a core-manifest path -> core-guard must deny, or this probe cannot measure (exit 9)
#   SUBJECT   an Edit to product code in the /ai-dlc session -> some hook must deny it WITH the
#             product-code reason ("THE LEAD DOES NOT EDIT PRODUCT CODE"); a deny for any other
#             reason does not count (exit 1 if none)
#   NEAR-MISS the same Edit in the non-pipeline session -> no hook may deny it (exit 3 if one does)
#   NEAR-MISS in the /ai-dlc session, the lead's own in-tree and out-of-tree targets --
#             `_bmad-output/x.md`, `docs/x.md`, repo-root `CLAUDE.md` (retro Step 4 tells the lead
#             to edit it) and a scratchpad path outside the tree -> no hook may deny any of them
#             (exit 3). Without these a hook denying EVERY lead edit in an /ai-dlc session passed.
# Exit 0 fixed, 1 live, 3 over-broad, 9 precondition missing.
#
# Measured at 0.781.0: CONTROL denied by ai-dlc-core-guard.sh, SUBJECT denied by none -> exit 1.
# Run from the repo root.
set -u
R=$PWD
T=templates/settings.json.template
[ -f "$T" ] && [ -f core/skills/ai-dlc/core-manifest.md ] && [ -f core/skills/ai-dlc-update/reconcile/setup-sites.md ] || exit 9
command -v python3 >/dev/null 2>&1 || exit 9
command -v jq >/dev/null 2>&1 || exit 9
d=$(mktemp -d)
mkdir -p "$d/_bmad-output" "$d/src" "$d/.claude/skills/ai-dlc/overrides" "$d/.claude/skills/ai-dlc/extensions" \
  "$d/.claude/skills/ai-dlc/steps" "$d/.claude/skills/ai-dlc-update/reconcile" "$d/tr"
echo "0.0.0" > "$d/.claude/.ai-dlc-version"
cp core/skills/ai-dlc/core-manifest.md "$d/.claude/skills/ai-dlc/core-manifest.md"
cp core/skills/ai-dlc-update/reconcile/setup-sites.md "$d/.claude/skills/ai-dlc-update/reconcile/setup-sites.md"
printf '# route\nline\n' > "$d/.claude/skills/ai-dlc/steps/route.md"
printf '# Pipeline Snapshot\nsprint: 1\n' > "$d/_bmad-output/pipeline-snapshot.md"
printf 'line\n' > "$d/src/app.py"
printf '{"type":"user","message":{"role":"user","content":"<command-message>ai-dlc</command-message>\\n<command-name>/ai-dlc</command-name>\\n<command-args></command-args>"}}\n' > "$d/tr/aidlc.jsonl"
printf '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_01","name":"Read","input":{"file_path":"%s/.claude/skills/ai-dlc/steps/route.md"}}]}}\n' "$d" >> "$d/tr/aidlc.jsonl"
printf '{"type":"user","message":{"role":"user","content":"fix the typo in src/app.py"}}\n' > "$d/tr/plain.jsonl"
[ ! -d "$d/_bmad-output/gate-adjudication" ] || exit 9
hooks=$(python3 -I -c 'import json,sys
d=json.load(open(sys.argv[1]))
print("\n".join(h["command"].split("/")[-1] for e in d["hooks"].get("PreToolUse",[]) if "Edit" in e.get("matcher","") for h in e["hooks"]))' "$T")
[ -n "$hooks" ] || exit 9
# denies <file> <transcript> [reason-token] -> 0 if some hook denies (with the token, when given)
denies() {
  local p h o r
  p=$(jq -nc --arg d "$d" --arg f "$1" --arg t "$2" \
    '{hook_event_name:"PreToolUse",tool_name:"Edit",session_id:"probe",cwd:$d,transcript_path:$t,
      tool_input:{file_path:$f,old_string:"line",new_string:"edited"}}')
  for h in $hooks; do
    [ -f "$R/core/hooks/$h" ] || continue
    o=$(cd "$d" && CLAUDE_PROJECT_DIR="$d" AI_DLC_PROJECT_ROOT="$d" bash "$R/core/hooks/$h" <<<"$p" 2>/dev/null); r=$?
    if [ "$r" -eq 2 ] || grep -q '"deny"' <<<"$o"; then
      [ -z "${3:-}" ] && return 0
      grep -qF "$3" <<<"$o" && return 0
    fi
  done
  return 1
}
denies "$d/.claude/skills/ai-dlc/steps/route.md" "$d/tr/plain.jsonl" || exit 9
denies "$d/src/app.py" "$d/tr/aidlc.jsonl" "THE LEAD DOES NOT EDIT PRODUCT CODE" || exit 1
denies "$d/src/app.py" "$d/tr/plain.jsonl" && exit 3
s=$(mktemp -d)
printf 'line\n' > "$d/_bmad-output/x.md"; mkdir -p "$d/docs"; printf 'line\n' > "$d/docs/x.md"
printf 'line\n' > "$d/CLAUDE.md"; printf 'line\n' > "$s/notes.md"
for nm in "$d/_bmad-output/x.md" "$d/docs/x.md" "$d/CLAUDE.md" "$s/notes.md"; do
  denies "$nm" "$d/tr/aidlc.jsonl" && exit 3
done
exit 0
