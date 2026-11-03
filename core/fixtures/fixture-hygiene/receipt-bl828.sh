#!/usr/bin/env bash
# core/fixtures/fixture-hygiene/receipt-bl828.sh -- lives under its fixture so it adds no subject start under scripts/.
# Receipt: BL-828 -- every fixture mutant kill goes through mutant_killed behind a same-run base flag.
# Usage: receipt-bl828.sh [<root>]   (<root> = a tree carrying scripts/ and VERSION; default: found by walking up from this script for scripts/validate-mutant-kills.sh)
# RUNS the shipping scripts/validate-mutant-kills.sh of <root> (it resolves its own root from its location, so the
# <root> copy is what is judged) and reads both allowlists of <root>:
#   - the validator exits 0 AND prints its "self-probe fired both ways" OK line
#   - scripts/mutant-kills-allowlist.txt and scripts/mutant-sites-allowlist.txt each exist and hold 0 non-comment rows
# WHAT IT CANNOT SEE: M1 reacts only to kill-SHAPED lines (a KILLED/killed token). A keyword-free kill verdict is BL-909.
# 0 = closed (validator green, both allowlists empty). 1 = a check failed. 9 = no verdict (no root, no validator).
set -uo pipefail
if [ -n "${1:-}" ]; then
  ROOT="$1"
else
  # walk up for the SUBJECT, never count hops
  ROOT="$(cd "$(dirname "$0")" && pwd)"
  while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/scripts/validate-mutant-kills.sh" ]; do ROOT="$(dirname "$ROOT")"; done
fi
V="$ROOT/scripts/validate-mutant-kills.sh"
[ -f "$V" ] || { echo "REFUSED: no $V" >&2; exit 9; }
rc=0
why=""
out="$(bash "$V" 2>&1)"; vrc=$?
if [ "$vrc" -ne 0 ]; then rc=1; why="$why validator-rc=$vrc"; fi
case "$out" in
  *"self-probe fired both ways"*) ;;
  *) rc=1; why="$why no-self-probe-line" ;;
esac
for f in scripts/mutant-kills-allowlist.txt scripts/mutant-sites-allowlist.txt; do
  if [ ! -f "$ROOT/$f" ]; then rc=1; why="$why missing:$f"; continue; fi
  n="$(grep -vc '^#' "$ROOT/$f")" || n=0
  [ "$n" -eq 0 ] || { rc=1; why="$why $f=$n-rows"; }
done
if [ "$rc" -eq 0 ]; then
  echo "BL-828 receipt: PASS -- validate-mutant-kills rc 0 with self-probe line, both allowlists at 0 non-comment rows"
else
  echo "BL-828 receipt: FAIL --$why"
  printf '%s\n' "$out" | tail -5
fi
exit "$rc"
