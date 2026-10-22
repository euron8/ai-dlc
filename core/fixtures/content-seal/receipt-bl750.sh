#!/usr/bin/env bash
# BL-750 receipt (the marker admission, content-seal.sh header "THE MARKER ADMISSION").
# Usage: bash receipt-bl750.sh [<content-seal.sh to drive>]   (default: the one found by walking up)
# Drives `content-seal.sh --admit-marker` over four scratch worlds, each a bare `seat-complete:` line
# on an adversary shard in the sealed set, no beats and no sleeps:
#   no role file                                    -> exit 1 (a missing role file never acquits)
#   a LEGACY adversary.md (the pre-0.904.0 fallback) -> exit 0
#   the SHIPPED adversary.md (CURRENT)               -> exit 1
#   an epics part OUTSIDE the sealed set, no role    -> exit 0
#   the CURRENT shard by a relative path from inside the state dir -> exit 1
# Exit 0 when every case holds, 1 when one does not, 2 when the receipt could not run.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SEAL="${1:-}"; ROLE=""; _d="$HERE"
while [ -n "$_d" ] && [ "$_d" != "/" ]; do
  for _r in core/team-roles/adversary.md .claude/team-roles/adversary.md; do
    if [ -z "$ROLE" ] && [ -f "$_d/$_r" ]; then ROLE="$_d/$_r"; fi
  done
  for _s in core/scripts/content-seal.sh scripts/ai-dlc/content-seal.sh; do
    if [ -z "$SEAL" ] && [ -f "$_d/$_s" ]; then SEAL="$_d/$_s"; fi
  done
  [ -n "$ROLE" ] && [ -n "$SEAL" ] && break
  _d="$(dirname "$_d")"
done
[ -f "$SEAL" ] && [ -f "$ROLE" ] || { echo "receipt-bl750: content-seal.sh or adversary.md not found above $HERE" >&2; exit 2; }
B="$(mktemp -d "${TMPDIR:-/tmp}/bl750.XXXXXX")" || exit 2
trap 'rm -rf "$B"' EXIT
mk() { # <name> <none|legacy|current> -> world root
  local w="$B/$1" d
  d="$w/_bmad-output/planning-artifacts/s1/shards/stories-p1"
  mkdir -p "$d" "$w/_bmad-output/planning-artifacts/s1/epics" || return 1
  printf '# shard\n\nseat-complete: stories adversary 1 findings=0\n' > "$d/1.md"
  printf '# part\n\nseat-complete: stories-epic-1 pm none findings=0\n' > "$w/_bmad-output/planning-artifacts/s1/epics/part-1.md"
  case "$2" in
    legacy) mkdir -p "$w/.claude/team-roles"
      printf 'run `wait-for-deliverable.sh --mark <f> <s> adversary <k> findings=<n>`.\nIf that call fails with `unknown arg: --mark`, append the bare line.\n' \
        > "$w/.claude/team-roles/adversary.md" ;;
    current) mkdir -p "$w/core/team-roles"; cp "$ROLE" "$w/core/team-roles/adversary.md" ;;
  esac
  printf '%s' "$w"
}
SH=_bmad-output/planning-artifacts/s1/shards/stories-p1/1.md
wm="$(mk missing none)" && wl="$(mk legacy legacy)" && wc="$(mk current current)" || exit 2
bash "$SEAL" --admit-marker "$wm/$SH" >/dev/null 2>&1; m=$?
bash "$SEAL" --admit-marker "$wl/$SH" >/dev/null 2>&1; l=$?
bash "$SEAL" --admit-marker "$wc/$SH" >/dev/null 2>&1; c=$?
bash "$SEAL" --admit-marker "$wm/_bmad-output/planning-artifacts/s1/epics/part-1.md" >/dev/null 2>&1; o=$?
r="$( cd "$wc/_bmad-output/planning-artifacts/s1" && bash "$SEAL" --admit-marker shards/stories-p1/1.md >/dev/null 2>&1; echo $? )"
# The repair kind: a joined record ending in a bare `repair-complete: serial 1`, whose role file is
# remediator.md (no file -> 1; the shipped remediator.md -> 1; a legacy one with the fallback -> 0).
RREM=""; _d="$HERE"
while [ -n "$_d" ] && [ "$_d" != "/" ]; do
  for _r in core/team-roles/remediator.md .claude/team-roles/remediator.md; do
    if [ -z "$RREM" ] && [ -f "$_d/$_r" ]; then RREM="$_d/$_r"; fi
  done
  [ -n "$RREM" ] && break
  _d="$(dirname "$_d")"
done
[ -f "$RREM" ] || { echo "receipt-bl750: remediator.md not found above $HERE" >&2; exit 2; }
RP=_bmad-output/planning-artifacts/s1/stories-repair-p1.md
for k in rnone rcur rleg; do
  mkdir -p "$B/$k/_bmad-output/planning-artifacts/s1" || exit 2
  printf '### e\n- edit: x\n\nrepair-complete: serial 1\n' > "$B/$k/$RP"
done
mkdir -p "$B/rcur/core/team-roles" "$B/rleg/.claude/team-roles" || exit 2
cp "$RREM" "$B/rcur/core/team-roles/remediator.md" || exit 2
printf 'close with `wait-for-deliverable.sh --mark-repair <record> <pass>`.\nIf that call fails with `unknown arg: --mark-repair`, append the bare line.\n' > "$B/rleg/.claude/team-roles/remediator.md"
bash "$SEAL" --admit-marker "$B/rnone/$RP" >/dev/null 2>&1; rn=$?
bash "$SEAL" --admit-marker "$B/rcur/$RP" >/dev/null 2>&1; rc_=$?
bash "$SEAL" --admit-marker "$B/rleg/$RP" >/dev/null 2>&1; rl=$?
echo "receipt-bl750: missing=$m legacy=$l current=$c outside=$o relative-current=$r repair-none=$rn repair-current=$rc_ repair-legacy=$rl (want 1 0 1 0 1 1 1 0)"
[ "$m" = 1 ] && [ "$l" = 0 ] && [ "$c" = 1 ] && [ "$o" = 0 ] && [ "$r" = 1 ] && [ "$rn" = 1 ] && [ "$rc_" = 1 ] && [ "$rl" = 0 ]
