#!/usr/bin/env bash
# BL-803 receipt. Usage: bash receipt-bl803.sh [<join to drive>]     Run from the repo root.
# Drives the REAL join (or the copy named by $1) through this fixture's own world builders (lib.sh):
# every ledger row is the REAL remediation-guard hook's, its clock pinned. The window is
# [2026-06-01T00:00Z, 01:00Z]; S22 is written in it by AG2 and cited by part 02, so the window is not
# empty. Part 01 cites story-2.1 (S21), which no agent wrote in the window, so every world REFUSES it
# as UNWRITTEN; the receipt reads the remedy clause after " -- ".
#   full   S21 written before --since by AG3; 01 cites the full path       -> the before-window text
#   base   the same; 01 cites the bare basename                            -> the before-window text
#   inapath  only a SAME-BASENAME file under ANOTHER dir inside the artifact path ($SLOT/epics/) is
#          written before --since; 01 cites the full S21 path, which has no row  -> the two-cause text
#   outapath only a same-basename file OUTSIDE the artifact path (s306/stories/) is written before
#          --since; 01 cites the bare basename                             -> the two-cause text
# 0 = every world reads as above.
# 1 = full did not name the before-window row (the lookup is absent or reads another row).
# 3 = base did not name it (the token is not resolved by the coverage join's suffix rule).
# 4 = inapath named a write (the lookup keys on the basename, not the cited path).
# 5 = outapath named a write (the lookup ignores the artifact-path filter).
# 9 = the receipt could not run: a missing file, a world that did not build, or no UNWRITTEN line.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
FJ=core/fixtures/remediator-shard-join
[ -f "$FJ/lib.sh" ] && [ -f core/scripts/join-remediator-shards.sh ] \
  || { echo "REFUSED: run from the distribution root" >&2; exit 9; }
command -v jq >/dev/null 2>&1 || { echo "REFUSED: jq absent; the hook records nothing" >&2; exit 9; }
NAME=receipt-bl803
. "$FJ/lib.sh" > /dev/null || exit 9
J="${1:-$JOIN}"
[ -f "$J" ] || { echo "REFUSED: no join at $J" >&2; exit 9; }
NONE="the file was written through Bash or another tool that reaches no Edit matcher, or it was never written; re-dispatch that shard writing through Edit, Write or MultiEdit"
BEFORE="the ledger's last write of $REL/$S21 was at 2026-05-20T00:00:00Z by $AG3, before --since $UW_S: the part cites an edit it did not make in this window"

world() { # <file written before the window, root-relative> <token part 01 cites> -> the remedy clause
  local w l
  w="$(new_world)" || return 9
  mkdir -p "$w/${1%/*}" || return 9
  drive "$w" Edit "$w/$1" "$AG3" "" "" 2026-05-20T00:00:00Z
  drive "$w" Edit "$w/$REL/$S22" "$AG2" "" "" 2026-06-01T00:10:00Z
  abspart "$w/$UW_PD" "$2"; part "$w" 02 2.2
  run_join_w "$J" "$w"
  [ "$RC" -eq 2 ] || return 9
  l="$(grep -F "01.md cites $2, which no dispatched agent wrote under $SLOT in the window -- " "$JO")" || return 9
  printf '%s' "${l#*in the window -- }"
}
r="$(world "$REL/$S21" "$REL/$S21")" || exit 9
case "$r" in "$BEFORE"*) ;; *) exit 1 ;; esac
r="$(world "$REL/$S21" "$S21")" || exit 9
case "$r" in "$BEFORE"*) ;; *) exit 3 ;; esac
r="$(world "$SLOT/epics/$S21" "$REL/$S21")" || exit 9
[ "$r" = "$NONE" ] || exit 4
r="$(world "_bmad-output/planning-artifacts/s306/stories/$S21" "$S21")" || exit 9
[ "$r" = "$NONE" ] || exit 5
exit 0
