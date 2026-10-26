#!/usr/bin/env bash
# BL-802 receipt. Usage: bash receipt-bl802.sh [<hook to drive> [abs|rel]]   Run from the repo root.
# Splits docs/design-notes.md with the REAL partition-document.sh (scratch copies of the core scripts), so a
# sections manifest under the state dir names it, then drives the REAL remediation-guard hook (or the copy
# named by $1) with a dispatched agent's Edit of that document, spelled absolutely (default) or relative
# to the project dir ($2 = rel). Two layouts: the default state dir, and AI_DLC_STATE_DIR=x/_bmad-output
# with the document at x/docs/. Each must record exactly ONE artifact-write row whose path is the
# project-relative spelling: docs/design-notes.md and x/docs/design-notes.md.
# 0 = both layouts record that one row.
# 1 = the default layout recorded no row, or more than one, or another spelling (the manifest arm is absent).
# 3 = the nested layout's row is wrong (spelled relative to the state dir's parent, not the project dir).
# 9 = the receipt could not run.
set -uo pipefail
[ -f core/hooks/ai-dlc-gate-remediation-guard.sh ] && [ -f core/scripts/partition-document.sh ] \
  || { echo "REFUSED: run from the distribution root" >&2; exit 9; }
command -v jq >/dev/null 2>&1 || exit 9
T="$(mktemp -d)" || exit 9
mkdir -p "$T/s" || exit 9
cp core/scripts/*.sh "$T/s/" || exit 9
cp core/hooks/ai-dlc-gate-remediation-guard.sh "$T/s/hook.sh" || exit 9
H="${1:-$T/s/hook.sh}"
SPELL="${2:-abs}"
[ -f "$H" ] || exit 9
case "$SPELL" in abs|rel) ;; *) exit 9 ;; esac
one() { # <state rel> <doc rel> -> prints the agent's rows' paths, one per line; rc 9 when the world fails
  local w="$T/w-${1%%/*}" s="$1" d="$2" fp pl
  mkdir -p "$w/$s/planning-artifacts/s5/shards" "$w/${d%/*}" || return 9
  printf '# Pipeline Snapshot\n' > "$w/$s/pipeline-snapshot.md" || return 9
  printf '# Design notes\n\n## Goals\nThe first goal, in one line.\nThe second goal, in one line.\n\n## Scope\nThe first scope item.\nThe second scope item.\n\n## Risks\nThe first risk.\nThe second risk.\n' > "$w/$d" || return 9
  bash "$T/s/partition-document.sh" --split "$w/$d" "$w/$s/planning-artifacts/s5/shards/design-notes-party-repair-p1" > /dev/null 2>&1 || return 9
  [ -f "$w/$s/planning-artifacts/s5/shards/design-notes-party-repair-p1/sections/.manifest" ] || return 9
  fp="$w/$d"; [ "$SPELL" = rel ] && fp="$d"
  pl="$(jq -nc --arg f "$fp" '{session_id:"r", tool_name:"Edit", agent_id:"a5e0c4b21d9f3a870", tool_input:{file_path:$f}}')" || return 9
  ( cd "$w" && CLAUDE_PROJECT_DIR="$w" AI_DLC_STATE_DIR="$s" bash "$H" <<< "$pl" > /dev/null 2>&1 )
  [ -f "$w/$s/planning-artifacts/.artifact-writes.jsonl" ] || return 0
  jq -r 'select(.kind == "artifact-write" and .agent_id == "a5e0c4b21d9f3a870") | .path' "$w/$s/planning-artifacts/.artifact-writes.jsonl"
}
a="$(one _bmad-output docs/design-notes.md)" || exit 9
b="$(one x/_bmad-output x/docs/design-notes.md)" || exit 9
[ "$a" = "docs/design-notes.md" ] || exit 1
[ "$b" = "x/docs/design-notes.md" ] || exit 3
exit 0
