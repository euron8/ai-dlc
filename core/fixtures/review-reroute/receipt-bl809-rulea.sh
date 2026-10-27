#!/usr/bin/env bash
# BL-809 item 3 receipt (Rule A). Usage: bash receipt-bl809-rulea.sh <path to partition-review-diff.sh>
# Drives --gate1-rerun over this fixture's world (world.sh):
#   (a) a docstring-only edit                        -> GATE1-SKIP
#   (b) an added test file (docstring and comment)   -> GATE1-RERUN
#   (c) an 18-line live smoke test added             -> GATE1-RERUN (graph s319 1-1-b)
#   (d) a records- and captures-only rework          -> GATE1-SKIP
# 0 = every case answered as above. 1 = a case did not. 9 = the receipt could not run.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ "$#" -eq 1 ] && [ -f "$1" ] || { echo "REFUSED: usage: bash receipt-bl809-rulea.sh <path to partition-review-diff.sh>" >&2; exit 9; }
P="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
SD="$(dirname "$P")"; HERE="$(cd "$(dirname "$0")" && pwd)"
[ -f "$SD/artifact-path-config.sh" ] || { echo "REFUSED: artifact-path-config.sh is not beside $P" >&2; exit 9; }
GR=""; d="$HERE"
while [ -n "$d" ] && [ "$d" != "/" ]; do
  for c in "$d/core/skills/ai-dlc/artifact-path-grammar.md" "$d/.claude/skills/ai-dlc/artifact-path-grammar.md"; do [ -f "$c" ] && { GR="$c"; break 2; }; done
  d="$(dirname "$d")"
done
[ -n "$GR" ] || { echo "REFUSED: no artifact-path-grammar.md above the receipt" >&2; exit 9; }
W="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl809-rulea.XXXXXX")" || exit 9
trap 'rm -rf "$W"' EXIT
. "$HERE/world.sh" || exit 9
rr_world "$W" "$GR" || exit 9
fails=0
g() { bash "$P" --gate1-rerun "$W/repo" "$(rr_ref "$W" B0)" "$(rr_ref "$W" "$1")" --exclude-captures "$W/captures" > "$W/o" 2>&1; echo $?; }
[ "$(g DOCSTRING)" = 0 ] && grep -q '^GATE1-SKIP: ' "$W/o" || { echo "FAIL a: $(head -1 "$W/o")"; fails=$((fails + 1)); }
[ "$(g NEWTEST)" = 0 ] && grep -q '^GATE1-RERUN: ' "$W/o" || { echo "FAIL b: $(head -1 "$W/o")"; fails=$((fails + 1)); }
[ "$(g SMOKE)" = 0 ] && grep -q '^GATE1-RERUN: ' "$W/o" || { echo "FAIL c: $(head -1 "$W/o")"; fails=$((fails + 1)); }
[ "$(g RECORDS_QA)" = 0 ] && grep -q '^GATE1-SKIP: ' "$W/o" || { echo "FAIL d: $(head -1 "$W/o")"; fails=$((fails + 1)); }
[ "$fails" -eq 0 ] || exit 1
exit 0
