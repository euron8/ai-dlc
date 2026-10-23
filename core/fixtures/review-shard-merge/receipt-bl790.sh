#!/usr/bin/env bash
# BL-790 receipt (a review shard states whether the advisor ran). Usage: bash receipt-bl790.sh <path to merge-review-shards.sh>
# Drives the merge under --gate qa and --gate code-review, and --check-serial under both, over this
# fixture's lib.sh worlds (AD1-AD3), with the merge's siblings beside it:
#   the gate's role file carries the sentinel at the frozen sha:
#     no advisor: line                                  -> REFUSED [owner: 1]
#     advisor: called / unavailable / unavailable + CR  -> MERGED, no LEGACY line
#     advisor: maybe, two lines, '- advisor: called', '**advisor:** called' -> REFUSED
#   no sentinel at the frozen sha, no line              -> MERGED with the LEGACY line by value
#   the role file unreadable at the frozen sha, no line -> REFUSED
#   world (a): no sentinel at the frozen sha, the new role file on disk -> LEGACY, MERGED
#   world (b): the sentinel at the frozen sha, the old one on disk      -> REFUSED
#   untracked at the sha, new copy on disk -> REFUSED naming the fallback; old copy -> LEGACY
#   --check-serial, both gates: the same line rules over the installed role file, and LEGACY without it
# 0 = every case answered as above. 1 = a case did not. 9 = the receipt could not run.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ "$#" -eq 1 ] && [ -f "$1" ] && [ "$(basename "$1")" = merge-review-shards.sh ] \
  || { echo "REFUSED: usage: bash receipt-bl790.sh <path to merge-review-shards.sh>" >&2; exit 9; }
HERE="$(cd "$(dirname "$0")" && pwd)"
SD="$(cd "$(dirname "$1")" && pwd)"
for _s in partition-review-diff.sh partition-document.sh content-seal.sh; do
  [ -f "$SD/$_s" ] || { echo "REFUSED: $_s is not beside the merge in $SD" >&2; exit 9; }
done
[ -f "$HERE/lib.sh" ] || { echo "REFUSED: no lib.sh beside the receipt" >&2; exit 9; }
R="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl790.XXXXXX")" || exit 9
trap 'rm -rf "$R"' EXIT
(
  NAME=receipt-bl790
  . "$HERE/lib.sh" > /dev/null 2>&1 || exit 9
  # One predicate run per surface; each cell's name appears in WHY exactly when that cell failed. The
  # cells run are counted, so a predicate that stopped early cannot read as every cell passing.
  for p in adv_qa:14 adv_cr:14 adv_serial:16; do
    WHY=""; CS_RAN=0
    "p_${p%%:*}" "$SD"
    case "$WHY" in *"was not built"*) echo "BROKEN ${p%%:*} $WHY"; continue ;; esac
    [ "$CS_RAN" = "${p#*:}" ] || { echo "BROKEN ${p%%:*} ran $CS_RAN of ${p#*:} cells"; continue; }
    for c in present-absent called unavailable cr maybe two bullet deco legacy-absent unreadable-absent world-a world-b untracked-new untracked-old; do
      case "${p%%:*}" in adv_qa) n="ad-q-$c" ;; adv_cr) n="ad-c-$c" ;; *) continue ;; esac
      case "$WHY" in *" $n{"*) echo "$n fail" ;; *) echo "$n ok" ;; esac
    done
    if [ "${p%%:*}" = adv_serial ]; then
      for x in q c; do for c in absent called unavailable cr maybe two bullet legacy-absent; do
        n="ad-s$x-$c"; case "$WHY" in *" $n{"*) echo "$n fail" ;; *) echo "$n ok" ;; esac
      done; done
    fi
  done
  exit 0
) > "$R/rows" 2> "$R/err"
rc=$?
[ "$rc" -eq 0 ] || { echo "REFUSED: the receipt did not run (rc=$rc): $(head -1 "$R/err")" >&2; exit 9; }
if grep -q '^BROKEN' "$R/rows"; then echo "REFUSED: $(grep '^BROKEN' "$R/rows" | head -1)" >&2; exit 9; fi
n="$(grep -c . "$R/rows")" || n=0
[ "$n" = 44 ] || { echo "REFUSED: $n of 44 cases answered" >&2; exit 9; }
fails=0
while read -r case got; do
  [ "$got" = ok ] || { echo "FAIL $case"; fails=$((fails + 1)); }
done < "$R/rows"
[ "$fails" -eq 0 ] || exit 1
exit 0
