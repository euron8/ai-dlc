#!/usr/bin/env bash
# BL-740 receipt (verdict backing). Usage: bash receipt-bl740.sh <path to merge-review-shards.sh>
# The script's own directory is driven, so it must hold the merge's siblings. Worlds are built by this
# fixture's lib.sh (beside this file) in its own mktemp WORK, never in the tree the script sits in; each
# case overwrites shard 2 of a clean world and runs the full merge.
#   qa           NEEDS_REWORK with 0 findings      -> REFUSED with the stem
#                NEEDS_REWORK with one finding     -> merges (control)
#   code-review  APPROVED with one Critical        -> REFUSED 'a Critical finding is not approvable'
#                APPROVED with one Important       -> merges (control)
#                BLOCKED with only a Suggestion    -> REFUSED with the stem
#                BLOCKED with one Important        -> merges (control)
# The third pair is what separates "Suggestions counted as Important" from the rule; neither of the first
# two carries a Suggestions finding.
# 0 = every case answered as above.
# 1 = a case did not (a refusal merged, a control was refused, or a refusal named another cause).
# 9 = the receipt could not run: no script, a sibling absent, lib.sh refused, a world did not build, or
#     the merge exited other than 0 (MERGED) or 2 with exactly one REFUSED line.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ "$#" -eq 1 ] && [ -f "$1" ] && [ "$(basename "$1")" = merge-review-shards.sh ] \
  || { echo "REFUSED: usage: bash receipt-bl740.sh <path to merge-review-shards.sh>" >&2; exit 9; }
HERE="$(cd "$(dirname "$0")" && pwd)"
SD="$(cd "$(dirname "$1")" && pwd)"
for _s in partition-review-diff.sh partition-document.sh artifact-path-config.sh content-seal.sh wait-for-deliverable.sh; do
  [ -f "$SD/$_s" ] || { echo "REFUSED: $_s is not beside $1; the merge resolves it there" >&2; exit 9; }
done
[ -f "$HERE/lib.sh" ] || { echo "REFUSED: no $HERE/lib.sh" >&2; exit 9; }
R="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl740.XXXXXX")" || exit 9
trap 'rm -rf "$R"' EXIT

# One row per case: "<case> <want> <got>", got one of merged | refused | refused-other | broken.
(
  NAME=receipt-bl740
  . "$HERE/lib.sh" > /dev/null 2>&1 || exit 9
  one() { # <case> <want: merged|refused> <gate> <shard-dir> [token] [token]
    local o got
    if [ "$3" = qa ]; then o="$(qout "$4")"; else o="$(out_of "$4")"; fi
    run_mg "$SD" "$4" "$3" "$o"
    if [ "$RC" -eq 0 ] && has "$MO" "MERGED:"; then got=merged
    elif [ "$RC" -eq 2 ] && [ "$(nref "$MO")" = 1 ]; then
      got=refused
      { [ -z "${5:-}" ] || has "$MO" "$5"; } && { [ -z "${6:-}" ] || has "$MO" "$6"; } || got=refused-other
    else got=broken; fi
    printf '%s %s %s\n' "$1" "$2" "$got"
    rm -f "$o"
  }
  d="$(qworld "$SD" PASS PASS PASS PASS)" || exit 9
  c="$(dirname "$d")/clean"; mkdir "$c" && cp "$d"/*.md "$c"/ || exit 9
  vb_q "$d" 2 NEEDS_REWORK ""; one q-nr-empty refused qa "$d" "$VB_Q_NR" "$VB_STEM"; cs_reset "$d" "$c"
  vb_q "$d" 2 NEEDS_REWORK "$(printf '#### Q-2-9 a gap\nparts: 2\n\nBody.')"; one q-nr-one merged qa "$d"
  d="$(world4 "$SD" APPROVED APPROVED APPROVED APPROVED)" || exit 9
  c="$(dirname "$d")/clean"; mkdir "$c" && cp "$d"/*.md "$c"/ || exit 9
  vb_c "$d" 2 APPROVED 2 crit; one cr-approved-crit refused code-review "$d" "$VB_CR_AP"; cs_reset "$d" "$c"
  vb_c "$d" 2 APPROVED 2 imp; one cr-approved-imp merged code-review "$d"; cs_reset "$d" "$c"
  vb_c "$d" 2 BLOCKED 2 sug; one cr-blocked-sug refused code-review "$d" "$VB_CR_BL" "$VB_STEM"; cs_reset "$d" "$c"
  vb_c "$d" 2 BLOCKED 2 imp; one cr-blocked-imp merged code-review "$d"
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
