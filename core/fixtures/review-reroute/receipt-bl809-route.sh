#!/usr/bin/env bash
# BL-809 item 1 receipt (the record-only route). Usage: bash receipt-bl809-route.sh <path to partition-review-diff.sh>
# Drives --route over this fixture's world (world.sh), with validate-carried-findings.sh and
# artifact-path-config.sh beside the given script:
#   (a) EVIDENCE|BOOKKEEPING prior + a delta editing a test file   -> FULL, exit 1 (graph s317 2-6 p3)
#   (b) the same prior + a delta of records and captures only      -> ROUTE, exit 0
#   (c) a prior with no Class line + that records-only delta        -> FULL, exit 1
# 0 = every case answered as above. 1 = a case did not. 9 = the receipt could not run.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ "$#" -eq 1 ] && [ -f "$1" ] || { echo "REFUSED: usage: bash receipt-bl809-route.sh <path to partition-review-diff.sh>" >&2; exit 9; }
P="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
SD="$(dirname "$P")"; HERE="$(cd "$(dirname "$0")" && pwd)"
for f in validate-carried-findings.sh artifact-path-config.sh; do [ -f "$SD/$f" ] || { echo "REFUSED: $f is not beside $P" >&2; exit 9; }; done
GR=""; d="$HERE"
while [ -n "$d" ] && [ "$d" != "/" ]; do
  for c in "$d/core/skills/ai-dlc/artifact-path-grammar.md" "$d/.claude/skills/ai-dlc/artifact-path-grammar.md"; do [ -f "$c" ] && { GR="$c"; break 2; }; done
  d="$(dirname "$d")"
done
[ -n "$GR" ] || { echo "REFUSED: no artifact-path-grammar.md above the receipt" >&2; exit 9; }
W="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl809-route.XXXXXX")" || exit 9
trap 'rm -rf "$W"' EXIT
. "$HERE/world.sh" || exit 9
rr_world "$W" "$GR" || exit 9
fails=0
r() { bash "$P" --route "$W/repo" "$W/$1" "$(rr_ref "$W" "$2")" --exclude-captures "$W/captures" > "$W/o" 2>&1; echo $?; }
[ "$(r prior-evidence.md TEST_EDIT)" = 1 ] && grep -q '^FULL: ' "$W/o" || { echo "FAIL a: $(head -1 "$W/o")"; fails=$((fails + 1)); }
[ "$(r prior-evidence.md RECORDS)" = 0 ] && grep -q '^ROUTE: ' "$W/o" || { echo "FAIL b: $(head -1 "$W/o")"; fails=$((fails + 1)); }
[ "$(r prior-noclass.md RECORDS)" = 1 ] && grep -q '^FULL: ' "$W/o" || { echo "FAIL c: $(head -1 "$W/o")"; fails=$((fails + 1)); }
[ "$fails" -eq 0 ] || exit 1
exit 0
