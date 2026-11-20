#!/usr/bin/env bash
# sprint-review-seats.sh -- which expected sprint-review seats are not yet joined.
#
# USAGE   sprint-review-seats.sh <seat-dir> <seat-file>...
#   <seat-dir>    the directory the seats write their deliverables into
#   <seat-file>   each expected seat's deliverable, a name under <seat-dir> (or a path to one)
# A seat is joined when its file exists and its last non-blank line starts with `seat-complete:` (the line
# `wait-for-deliverable.sh --mark` appends). A seat whose spawn errored (rate limit, capacity) never wrote that
# line, so it prints as REDISPATCH and is never counted as joined.
# OUTPUT  `JOINED <seat>` or `REDISPATCH <seat>` per expected seat, then
#         `SEATS examined=<n> joined=<j> redispatch=<r>`
# EXIT    0 every expected seat joined; 1 at least one REDISPATCH; 2 refusal (seat dir missing, no seat listed).
set -uo pipefail

dir="${1:-}"
[ -n "$dir" ] && [ -d "$dir" ] || { echo "sprint-review-seats: seat dir '${dir}' is missing" >&2; exit 2; }
shift
[ "$#" -gt 0 ] || { echo "sprint-review-seats: no expected seat listed" >&2; exit 2; }

n=0; j=0; r=0
for s in "$@"; do
  n=$((n + 1))
  f="$s"; [ -f "$f" ] || f="$dir/$s"
  last=""
  [ -f "$f" ] && last="$(grep -v '^[[:space:]]*$' "$f" | tail -n 1)"
  case "$last" in
    seat-complete:*) echo "JOINED $s"; j=$((j + 1)) ;;
    *) echo "REDISPATCH $s"; r=$((r + 1)) ;;
  esac
done
echo "SEATS examined=$n joined=$j redispatch=$r"
[ "$r" -eq 0 ]
