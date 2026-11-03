#!/usr/bin/env bash
# BL-905 receipt (a canonical-run claim is bound to an executed run). Usage: bash receipt-bl905.sh <path to merge-review-shards.sh>
# Drives the --gate qa merge twice over this fixture's lib.sh REPO_RR world (p_run_rec), with the merge's siblings beside
# it. The world's qa.md AT THE BASE prescribes --record-run, and the partition is recorded with --record-partition:
#   rr-fab  cross-1 types `Canonical run: `python3 -m pytest -q`` and `Canonical result: 812 passed, ...`, no run is
#           recorded                                                         -> REFUSED, "no canonical run is recorded"
#   rr-ok   the canonical run made through `--record-run <shard dir> -- <runner>`, its RECORDED-RESULT copied verbatim
#                                                                            -> MERGED
#   rr-s-head  serial `--record-run <review file> --frozen F` with the worktree checked out at X
#                                                                            -> REFUSED, nothing recorded
#   rr-s-ok    the same with the worktree at F, then --check-serial          -> SERIAL-OK
# Each cell asserts its own exit and token (lib.sh p_run_rec). Prints `<cell> ok` or `<cell> fail`.
# 0 = every cell answered as above. 1 = a cell did not. 9 = the receipt could not run.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ "$#" -eq 1 ] && [ -f "$1" ] && [ "$(basename "$1")" = merge-review-shards.sh ] \
  || { echo "REFUSED: usage: bash receipt-bl905.sh <path to merge-review-shards.sh>" >&2; exit 9; }
HERE="$(cd "$(dirname "$0")" && pwd)"
SD="$(cd "$(dirname "$1")" && pwd)"
for _s in partition-review-diff.sh partition-document.sh content-seal.sh record-only-diff.sh sprint-status.sh; do
  [ -f "$SD/$_s" ] || { echo "REFUSED: $_s is not beside the merge in $SD" >&2; exit 9; }
done
[ -f "$HERE/lib.sh" ] || { echo "REFUSED: no lib.sh beside the receipt" >&2; exit 9; }
R="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl905.XXXXXX")" || exit 9
trap 'rm -rf "$R"' EXIT
(
  NAME=receipt-bl905
  . "$HERE/lib.sh" > /dev/null 2>&1 || exit 9
  ip_load "$SD/merge-review-shards.sh" > /dev/null 2>&1 || exit 9
  for c in rr-fab rr-ok rr-s-head rr-s-ok; do
    WHY=""; CS_RAN=0
    CS_ONLY="$c" p_run_rec "$SD"
    case "$WHY" in *"was not built"*|*"FIXTURE "*) echo "BROKEN $c $WHY"; continue ;; esac
    [ "$CS_RAN" = 1 ] || { echo "BROKEN $c ran $CS_RAN cells"; continue; }
    case "$WHY" in *" $c{"*) echo "$c fail" ;; *) echo "$c ok" ;; esac
  done
  exit 0
) > "$R/rows" 2> "$R/err"
rc=$?
[ "$rc" -eq 0 ] || { echo "REFUSED: the receipt did not run (rc=$rc): $(head -1 "$R/err")" >&2; exit 9; }
if grep -q '^BROKEN' "$R/rows"; then echo "REFUSED: $(grep '^BROKEN' "$R/rows" | head -1)" >&2; exit 9; fi
n="$(grep -c . "$R/rows")" || n=0
[ "$n" = 4 ] || { echo "REFUSED: $n of 4 cases answered" >&2; exit 9; }
fails=0
while read -r case got; do
  echo "$case $got"
  [ "$got" = ok ] || fails=$((fails + 1))
done < "$R/rows"
[ "$fails" -eq 0 ] || exit 1
exit 0
