#!/bin/bash
# BL-608 receipt. usage: receipt-bl608.sh [<validator-fork-budget run.sh>]; run from the repo root.
#   exit 0   judge() reports "RED headroom" one fork under the margin and PASS two forks under
#            the budget (arm A3b is present and neither too narrow nor too wide)
#   exit 1   it does not
#   exit 9   the receipt cannot measure: no run.sh, not exactly one HEADROOM_MARGIN= line, or
#            the HEADROOM_MARGIN..judge() extract could not be bounded
set -uo pipefail
F="${1:-core/fixtures/validator-fork-budget/run.sh}"
[ -f "$F" ] || exit 9
n="$(grep -c '^HEADROOM_MARGIN=' "$F")" || n=0
[ "$n" = 1 ] || exit 9
start="$(grep -n '^HEADROOM_MARGIN=' "$F" | cut -d: -f1)"
end="$(awk '/^judge\(\) \{/{j=1} j && /^}$/ {print NR; exit}' "$F")"
[ -n "$start" ] && [ -n "$end" ] || exit 9
X="$(mktemp -d "${TMPDIR:-/tmp}/bl608.XXXXXX")/j.sh" || exit 9
sed -n "${start},${end}p" "$F" > "$X"
[ -s "$X" ] || exit 9
( FLOOR=1; NFX=10; BUDGET_FILE=fork-budget.txt; . "$X"
  b=3446
  out="$(judge $((b-1)) 0 900 800 $b)"
  case "$out" in "RED headroom"*) ;; *) exit 1 ;; esac
  out="$(judge $((b-2)) 0 900 800 $b)"
  [ "$out" = PASS ] || exit 1
  exit 0 )
