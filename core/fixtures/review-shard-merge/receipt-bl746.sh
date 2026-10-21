#!/usr/bin/env bash
# BL-746 receipt (QA severity containers). Usage: bash receipt-bl746.sh <path to merge-review-shards.sh>
# The script's own directory is driven, so it must hold the merge's siblings. Worlds are built by this
# fixture's lib.sh (beside this file) in its own mktemp WORK, never in the tree the script sits in; each
# case overwrites shard 2 of a clean qa world and runs the full merge.
#   qa.md as shipped (three containers: the severity rule)
#     NEEDS_REWORK with only a Suggestions finding -> REFUSED, naming the move-it remedy
#     NEEDS_REWORK with one Important finding      -> merges (control), no LEGACY line
#     PASS with one Critical finding               -> REFUSED 'a Critical finding is not approvable'
#     PASS with one finding under no container     -> REFUSED as unclassed
#   qa.md with its Findings Template removed (the consumer's installed qa.md: count-only)
#     NEEDS_REWORK with one uncontained finding    -> merges, with the LEGACY count-only line
#     PASS with one Critical finding               -> merges
#   today's qa.md, the set frozen over a tree whose INSTALLED qa.md declares no container
#     the graph post-F2 set (an uncontained NEEDS_REWORK finding) -> merges, with the boundary LEGACY line
#   the same set frozen over a tree installing the three-container qa.md -> REFUSED as unclassed
# The two legacy cases are what separate "drop the fallback" and "severity everywhere" from the fix;
# the first three are what separate "QA stays count-only".
# 0 = every case answered as above.
# 1 = a case did not (a refusal merged, a control was refused, or a refusal named another cause).
# 9 = the receipt could not run: no script, a sibling absent, lib.sh refused, a world did not build, or
#     the merge exited other than 0 (MERGED) or 2 with exactly one REFUSED line.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ "$#" -eq 1 ] && [ -f "$1" ] && [ "$(basename "$1")" = merge-review-shards.sh ] \
  || { echo "REFUSED: usage: bash receipt-bl746.sh <path to merge-review-shards.sh>" >&2; exit 9; }
HERE="$(cd "$(dirname "$0")" && pwd)"
SD="$(cd "$(dirname "$1")" && pwd)"
for _s in partition-review-diff.sh partition-document.sh artifact-path-config.sh content-seal.sh wait-for-deliverable.sh; do
  [ -f "$SD/$_s" ] || { echo "REFUSED: $_s is not beside $1; the merge resolves it there" >&2; exit 9; }
done
[ -f "$HERE/lib.sh" ] || { echo "REFUSED: no $HERE/lib.sh" >&2; exit 9; }
R="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl746.XXXXXX")" || exit 9
trap 'rm -rf "$R"' EXIT

# One row per case: "<case> <want> <got>", got one of merged | refused | refused-other | broken.
(
  NAME=receipt-bl746
  . "$HERE/lib.sh" > /dev/null 2>&1 || exit 9
  one() { # <case> <want: merged|refused> <shard-dir> [token] [token]
    local o got
    o="$(qout "$3")"
    run_mg "$SD" "$3" qa "$o"
    if [ "$RC" -eq 0 ] && has "$MO" "MERGED:"; then
      got=merged
      { [ -z "${4:-}" ] || has "$MO" "$4"; } && { [ -n "${4:-}" ] || ! has "$MO" "$VB_LEG"; } || got=merged-other
    elif [ "$RC" -eq 2 ] && [ "$(nref "$MO")" = 1 ]; then
      got=refused
      { [ -z "${4:-}" ] || has "$MO" "$4"; } && { [ -z "${5:-}" ] || has "$MO" "$5"; } || got=refused-other
    else got=broken; fi
    printf '%s %s %s\n' "$1" "$2" "$got"
    rm -f "$o"
  }
  d="$(qworld "$SD" PASS PASS PASS PASS)" || exit 9
  c="$(dirname "$d")/clean"; mkdir "$c" && cp "$d"/*.md "$c"/ || exit 9
  VB_PROJ=""
  vb_q "$d" 2 NEEDS_REWORK "$(qf Suggestions)"; one q-nr-sug refused "$d" "$VB_Q_SEV_NR" "$VB_MOVE"; cs_reset "$d" "$c"
  vb_q "$d" 2 NEEDS_REWORK "$(qf Important)"; one q-nr-imp merged "$d"; cs_reset "$d" "$c"
  vb_q "$d" 2 PASS "$(qf Critical)"; one q-pass-crit refused "$d" "$VB_Q_PASS_CRIT"; cs_reset "$d" "$c"
  vb_q "$d" 2 PASS "$(qf none)"; one q-unclassed refused "$d" "$VB_UNC"; cs_reset "$d" "$c"
  VB_PROJ="$PROJ_QLEG"
  vb_q "$d" 2 NEEDS_REWORK "$(qf none)"; one q-leg-nr-one merged "$d" "$VB_LEG"; cs_reset "$d" "$c"
  vb_q "$d" 2 PASS "$(qf Critical)"; one q-leg-pass-crit merged "$d" "$VB_LEG"
  # THE SEVERITY BOUNDARY: today's qa.md, the set frozen over a tree whose installed qa.md declares no
  # container -> count-only with its LEGACY line; frozen over the three-container one -> REFUSED unclassed.
  VB_PROJ=""
  d="$(fr_g_world "$SD" "$REPO_QL" "$QL_BASE" "$QL_SHA" 1)" || exit 9
  one q-bound-legacy merged "$d" "$FR_BLEG"
  d="$(fr_g_world "$SD" "$REPO_QS" "$QS_BASE" "$QS_SHA" 1)" || exit 9
  one q-bound-severity refused "$d" "$VB_UNC"
  exit 0
) > "$R/rows" 2> "$R/err"
rc=$?
[ "$rc" -eq 0 ] || { echo "REFUSED: the receipt's worlds did not build (rc=$rc): $(head -1 "$R/err")" >&2; exit 9; }
n="$(grep -c . "$R/rows")" || n=0
[ "$n" = 8 ] || { echo "REFUSED: $n of 8 cases answered" >&2; exit 9; }
fails=0
while read -r case want got; do
  [ "$got" != broken ] || { echo "REFUSED: $case: the merge exited other than 0 or 2 with one REFUSED line" >&2; exit 9; }
  [ "$got" = "$want" ] || { echo "FAIL $case: want $want, got $got"; fails=$((fails + 1)); }
done < "$R/rows"
[ "$fails" -eq 0 ] || exit 1
exit 0
