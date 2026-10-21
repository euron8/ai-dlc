#!/usr/bin/env bash
# BL-747 receipt (per-AC FAIL rows). Usage: bash receipt-bl747.sh <path to merge-review-shards.sh>
# The script's own directory is driven, so it must hold the merge's siblings. Worlds are built by this
# fixture's lib.sh (beside this file) in its own mktemp WORK; each case rewrites cross-1 (and part 2)
# of a clean qa world and runs the full merge.
#   PASS over an AC4 row reading FAIL                        -> REFUSED 'reads FAIL but the QA verdict is PASS'
#   PASS over FAIL under a Result column moved to position 3 -> REFUSED (the same)
#   PASS with FAIL only in the Expected column               -> merges (near-miss)
#   NEEDS_REWORK, a FAIL row no finding names                -> REFUSED as an orphan
#   NEEDS_REWORK, AC1 FAIL, a finding naming only AC10       -> REFUSED as an orphan (whole token)
#   NEEDS_REWORK, AC4 FAIL, part 2's finding naming AC4      -> merges
# 0 = every case answered as above. 1 = a case did not. 9 = the receipt could not run.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ "$#" -eq 1 ] && [ -f "$1" ] && [ "$(basename "$1")" = merge-review-shards.sh ] \
  || { echo "REFUSED: usage: bash receipt-bl747.sh <path to merge-review-shards.sh>" >&2; exit 9; }
HERE="$(cd "$(dirname "$0")" && pwd)"
SD="$(cd "$(dirname "$1")" && pwd)"
for _s in partition-review-diff.sh partition-document.sh artifact-path-config.sh content-seal.sh wait-for-deliverable.sh; do
  [ -f "$SD/$_s" ] || { echo "REFUSED: $_s is not beside $1; the merge resolves it there" >&2; exit 9; }
done
[ -f "$HERE/lib.sh" ] || { echo "REFUSED: no $HERE/lib.sh" >&2; exit 9; }
R="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl747.XXXXXX")" || exit 9
trap 'rm -rf "$R"' EXIT

(
  NAME=receipt-bl747
  . "$HERE/lib.sh" > /dev/null 2>&1 || exit 9
  one() { # <case> <want: merged|refused> <shard-dir> [token]
    local o got
    o="$(qout "$3")"
    run_mg "$SD" "$3" qa "$o"
    if [ "$RC" -eq 0 ] && has "$MO" "MERGED:"; then got=merged
    elif [ "$RC" -eq 2 ] && [ "$(nref "$MO")" = 1 ]; then
      got=refused; { [ -z "${4:-}" ] || has "$MO" "$4"; } || got=refused-other
    else got=broken; fi
    printf '%s %s %s\n' "$1" "$2" "$got"
    rm -f "$o"
  }
  d="$(qworld "$SD" PASS PASS PASS PASS)" || exit 9
  c="$(dirname "$d")/clean"; mkdir "$c" && cp "$d"/*.md "$c"/ || exit 9
  fr_x1 "$d" PASS "" "$FR_TBL" '| AC4 | FAIL | a RED | none |'; one fail-pass refused "$d" "$FR_VERD"; cs_reset "$d" "$c"
  fr_x1 "$d" PASS "" '| AC | Expected | Result | Got |' '| AC4 | green | FAIL | none |'; one fail-reorder refused "$d" "$FR_VERD"; cs_reset "$d" "$c"
  fr_x1 "$d" PASS "" "$FR_TBL" '| AC4 | PASS | FAIL on the old code | green |'; one fail-expected merged "$d"; cs_reset "$d" "$c"
  vb_q "$d" 2 NEEDS_REWORK "$(fr_find2 'a gap with no AC named' 'Body.')"
  fr_x1 "$d" PASS "" "$FR_TBL" '| AC4 | FAIL | a RED for AC4 | none |'; one orphan refused "$d" "$FR_ORPH AC4"; cs_reset "$d" "$c"
  vb_q "$d" 2 NEEDS_REWORK "$(fr_find2 'a gap' 'AC10 has no committed RED.')"
  fr_x1 "$d" PASS "" "$FR_TBL" '| AC1 | FAIL | a RED | none |'; one ac10 refused "$d" "$FR_ORPH AC1"; cs_reset "$d" "$c"
  vb_q "$d" 2 NEEDS_REWORK "$(fr_find2 'AC4 has no committed RED' 'Body.')"
  fr_x1 "$d" PASS "" "$FR_TBL" '| AC4 | FAIL | a RED | none |'; one backed merged "$d"
  exit 0
) > "$R/rows" 2> "$R/err"
rc=$?
[ "$rc" -eq 0 ] || { echo "REFUSED: the receipt's worlds did not build (rc=$rc): $(head -1 "$R/err")" >&2; exit 9; }
n="$(grep -c . "$R/rows")" || n=0
[ "$n" = 6 ] || { echo "REFUSED: $n of 6 cases answered" >&2; exit 9; }
fails=0
while read -r case want got; do
  [ "$got" != broken ] || { echo "REFUSED: $case: the merge exited other than 0 or 2 with one REFUSED line" >&2; exit 9; }
  [ "$got" = "$want" ] || { echo "FAIL $case: want $want, got $got"; fails=$((fails + 1)); }
done < "$R/rows"
[ "$fails" -eq 0 ] || exit 1
exit 0
