#!/usr/bin/env bash
# BL-811 receipt (W1). Usage: bash receipt-bl811.sh <path to merge-review-shards.sh> [lone|full]
# Drives the SHIPPED merge in its own directory (its siblings resolve there) on review-shard-merge's
# lib.sh REPO_C world at K=4 (cross groups 1..6, every pair of 4). Two seeds, both required:
#   (a) 4 part shards + the cross shape named by $2 -> exit 0, MERGED. lone (default): ONE cross.md,
#       titled 5 shards, '## Shard: cross' the last body header, no '## Shard: cross-'. full: the
#       second correct spelling, cross-1..6, titled 10 shards.
#   (b) 4 part shards + cross.md beside cross-1..6 -> exit 2, REFUSED as a mix, nothing written.
# 0 = both answered as above. 1 = either did not. 9 = the receipt could not run.
set -uo pipefail
[ "$#" -ge 1 ] && [ -f "$1" ] && [ "$(basename "$1")" = merge-review-shards.sh ] \
  || { echo "REFUSED: usage: bash receipt-bl811.sh <path to merge-review-shards.sh> [lone|full]" >&2; exit 9; }
SD="$(cd "$(dirname "$1")" && pwd)"; CASE="${2:-lone}"
HERE="$(cd "$(dirname "$0")" && pwd)"
[ -f "$HERE/lib.sh" ] || { echo "REFUSED: no $HERE/lib.sh" >&2; exit 9; }
(
  NAME=receipt-bl811
  . "$HERE/lib.sh" > /dev/null 2>&1 || exit 9
  SHARD_SHA="$C_SHA"
  # (a) the accepted shape
  d="$(kworld "$SD" "$REPO_C" "$C_BASE" "$C_SHA" 4 code-review APPROVED)" || exit 9
  [ "$(nparts "$d")" = 4 ] && [ -f "$d/cross-6.md" ] || exit 9
  o="$(out_of "$d")"
  case "$CASE" in
    lone) rm -f "$d"/cross-*.md; shard "$d" cross APPROVED "1, 4"; want=5 ;;
    full) want=10 ;;
    *) exit 9 ;;
  esac
  run_merge "$SD" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && grep -qF "(merged from $want shards)" <<<"$(sed -n 1p "$o")" || exit 1
  if [ "$CASE" = lone ]; then
    [ "$(grep '^## Shard: ' "$o" | tail -1)" = "## Shard: cross" ] && ! grep -q '^## Shard: cross-' "$o" || exit 1
  fi
  # (b) the mixed shape, a second seed
  d="$(kworld "$SD" "$REPO_C" "$C_BASE" "$C_SHA" 4 code-review APPROVED)" || exit 9
  [ -f "$d/cross-6.md" ] || exit 9
  shard "$d" cross APPROVED "1, 4"; run_merge "$SD" "$d"
  refused_clean "mixes cross.md with cross-<g>.md" "$d" || exit 1
  exit 0
); rc=$?
exit "$rc"
