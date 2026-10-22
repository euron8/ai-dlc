#!/usr/bin/env bash
# BL-755 receipt (structural; no timing). Usage: bash receipt-bl755.sh [<review-shard-merge run.sh> [<lib.sh>]]
# The M battery's cut, read off the fixture's own program:
#   (a) no whole-directory copy: no `cp -R "$SRCDIR"` line in run.sh;
#   (b) the mut_run CALLS, executed with a stub `mut_run` that records its id, its CS_ONLY and its
#       predicate (argument 5), yield M1-M22 exactly once each, every one carrying a selector;
#   (c) every predicate a mutant drives gates its cells: its `p_<pred>` body in lib.sh calls `cell `
#       (or the selector-aware `cs_sel`);
#   (d) each selector names a cell that predicate declares (`cell <name>` in its body; M1's CS1 cells
#       are declared through the CS_CR list);
#   (e) mut_run asserts the one-cell count and prints the CS-UNSELECTED sentinel.
# Exit 0 when every clause holds, 1 otherwise, 2 when an input is absent or the calls cannot be read.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
R="${1:-$HERE/run.sh}"; L="${2:-$HERE/lib.sh}"
[ -f "$R" ] && [ -f "$L" ] || { echo "receipt-bl755: run.sh or lib.sh absent" >&2; exit 2; }
fail=0; say() { echo "receipt-bl755: $*"; fail=1; }
n="$(grep -c 'cp -R "\$SRCDIR"' "$R")" || n=0
[ "$n" = 0 ] || say "(a) $n whole-directory cp -R of SRCDIR remain"
# The call statements: every line that invokes mut_run with an M id, joined with its continuation lines.
calls="$(awk '/^[[:space:]]*(CS_ONLY=[^ ]+[[:space:]]+)?mut_run M[0-9]+/ { p = 1 }
  p { print; if ($0 !~ /\\$/) p = 0 }' "$R")"
[ -n "$calls" ] || { echo "receipt-bl755: no mut_run call read from $R" >&2; exit 2; }
rec="$( mut_run() { printf '%s\t%s\t%s\n' "$1" "${CS_ONLY:-}" "$5"; }; eval "$calls" )" \
  || { echo "receipt-bl755: the mut_run calls in $R did not execute under the stub" >&2; exit 2; }
body() { awk -v n="p_$1() {" 'index($0, n) == 1 { p = 1 } p { print } p && /^}$/ { exit }' "$L"; }
i=1
while [ "$i" -le 22 ]; do
  row="$(printf '%s\n' "$rec" | awk -F'\t' -v id="M$i" '$1 == id')"
  c="$(printf '%s\n' "$row" | grep -c .)" || c=0
  if [ "$c" != 1 ]; then say "(b) M$i has $c mut_run call(s), want 1"; i=$((i + 1)); continue; fi
  sel="$(printf '%s' "$row" | cut -f2)"; pred="$(printf '%s' "$row" | cut -f3)"
  [ -n "$sel" ] || say "(b) M$i carries no CS_ONLY selector"
  b="$(body "$pred")"
  if [ -z "$b" ]; then say "(c) M$i: p_$pred has no body in lib.sh"; i=$((i + 1)); continue; fi
  grep -qE '(^|[^A-Za-z_])(cell|cs_sel) ' <<<"$b" || say "(c) M$i: p_$pred calls no selector"
  if [ -n "$sel" ]; then
    cr="$(grep -E '^CS_CR="' "$L" | tr -d '"' | tr ' =' '\n\n')"
    if [ "$pred" = cs ]; then grep -qxF -- "$sel" <<<"$cr" || say "(d) M$i: '$sel' is not a CS_CR cell"
    else grep -qE "cell $sel( |;|\$)" <<<"$b" || say "(d) M$i: p_$pred declares no cell '$sel'"; fi
  fi
  i=$((i + 1))
done
grep -qF 'the mutant ran $CS_RAN cells of' "$R" && grep -qF 'echo "CS-UNSELECTED: ' "$R" || say "(e) mut_run does not assert one cell, or prints no CS-UNSELECTED sentinel"
[ "$fail" = 0 ] && echo "receipt-bl755: M1-M22 each selected, every driven predicate gated, no whole-directory copy"
exit "$fail"
