#!/usr/bin/env bash
# Sourced by run.sh. Row printers for --matrix; they read MATRIX_CELLS and HOOK_EXPECTED and call hook_cell, all defined by run.sh.
matrix_row() { # <mutant> <cells...>  each cell is <name>:<value>(killed=yes|no)
  MATRIX_CELLS=$((MATRIX_CELLS+1))
  printf 'MATRIX %s %s\n' "$1" "$2"
}
# arm_cells <"arm:rc" lines> -> "<arm>:<rc>(killed=yes|no) ..."; an arm is KILLED where it FAILS (rc 1)
arm_cells() { printf '%s\n' "$1" | awk -F: 'NF>=2 { printf "%s:%s(killed=%s) ", $1, $2, ($2=="1" ? "yes" : "no") }'; }
# hook_cells <battery vector> -> "hook-world-<W>:<outcome>(killed=yes|no) ..."; a world is KILLED where
# its outcome DIFFERS from the shipped hook's outcome in that world (HOOK_EXPECTED).
hook_cells() {
  local tok w v e out=""
  for tok in $1; do
    w="${tok%%:*}"; v="${tok#*:}"
    e="$(hook_cell "$HOOK_EXPECTED" "$w")"; e="${e#*:}"
    if [ "$v" = "$e" ]; then out="$out hook-world-$w:$v(killed=no)"; else out="$out hook-world-$w:$v(killed=yes)"; fi
  done
  printf '%s' "${out# }"
}
