#!/usr/bin/env bash
# receipt-bl983.sh [<fixture-dir>] — BL-983's receipt, run by run.sh beside it on every push.
# An undeclared `cmp` left both DID-NOT-APPLY guards dead: the hermetic sandbox puts only the tools
# tools.decl names on PATH, and `if cmp -s` folded rc 127 into "the files differ". Holds both halves:
#   R1 tools.decl declares cmp;
#   R2 mutant_applied (applied.sh) fails CLOSED when cmp cannot run: PATH holding no cmp -> BROKEN cmp rc=127, rc 2;
#   R3 an identical pair still reads NOT-APPLIED, rc 1 (the near-miss: R2 is not a guard that always says BROKEN).
# <fixture-dir> defaults to this file's own directory; a copy of another revision's files is the must-fail probe.
# Exit: 0 every arm holds, 1 an arm failed.
set -u
D="${1:-$(cd "$(dirname "$0")" && pwd)}"
rfail=0
rok()  { printf '  ok    receipt-bl983 %s\n' "$1"; }
rbad() { printf '  FAIL  receipt-bl983 %s\n' "$1"; rfail=1; }

if grep -qx 'cmp' "$D/tools.decl" 2>/dev/null; then rok "R1 tools.decl declares cmp"
else rbad "R1 tools.decl does not declare cmp -- under hermetic-run the guard's cmp is command not found"; fi

if [ -f "$D/applied.sh" ]; then
  # shellcheck source=applied.sh
  . "$D/applied.sh"
fi
if [ "$(type -t mutant_applied 2>/dev/null)" != function ]; then
  rbad "R2 applied.sh is absent or defines no mutant_applied -- there is no fail-closed guard to drive"
else
  # Every pair is drawn from this fixture's own files, so the receipt writes nothing. PATH names a directory
  # that does not exist (an empty PATH entry would mean the cwd), which is the sandbox's tool farm without cmp.
  v="$(PATH="$D/.no-such-bin-bl983"; mutant_applied 0 "$D/tools.decl" "$D/applied.sh" 2>/dev/null)"; rc=$?
  if [ "$v" = "BROKEN cmp rc=127" ] && [ "$rc" = 2 ]; then rok "R2 no cmp on PATH reads BROKEN cmp rc=127, rc 2"
  else rbad "R2 no cmp on PATH read [$v] rc=$rc, expected [BROKEN cmp rc=127] rc 2"; fi
  v="$(mutant_applied 0 "$D/applied.sh" "$D/applied.sh" 2>/dev/null)"; rc=$?
  if [ "${v%% *}" = NOT-APPLIED ] && [ "$rc" = 1 ]; then rok "R3 identical pair reads NOT-APPLIED, rc 1"
  else rbad "R3 identical pair read [$v] rc=$rc, expected NOT-APPLIED rc 1"; fi
fi
exit "$rfail"
