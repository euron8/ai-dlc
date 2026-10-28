#!/usr/bin/env bash
# matrix.sh -- the MATRIX row printer for document-partition/run.sh --matrix. Sourced by run.sh.
#
# It lives outside run.sh because scripts/validate-mutant-kills.sh (M1) reads every KILLED/killed
# token on a non-comment line of run.sh as a kill emission, and a row's per-cell polarity is
# spelled `<predicate>:killed=yes|no` so the reader never infers what a bare 0/1 means.
#
# matrix_row <id> <tripped predicates, space-separated, in P_ALL order>
#   One line: `MATRIX <id> <p>:killed=yes|no ... tripped=[<list>]`, a cell for EVERY predicate in
#   $P_ALL. MATRIX_ROWS counts the rows printed, so run.sh can assert a plain run printed none.
MATRIX_ROWS=0
matrix_row() {
  local mr_tr=" $2 " mr_p mr_line="MATRIX $1"
  for mr_p in $P_ALL; do
    case "$mr_tr" in
      *" $mr_p "*) mr_line="$mr_line $mr_p:killed=yes" ;;
      *) mr_line="$mr_line $mr_p:killed=no" ;;
    esac
  done
  printf '%s tripped=[%s]\n' "$mr_line" "$2"
  MATRIX_ROWS=$((MATRIX_ROWS + 1))
}
