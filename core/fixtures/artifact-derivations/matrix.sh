#!/usr/bin/env bash
# matrix.sh -- the MATRIX row printer for artifact-derivations/run.sh --matrix. Sourced by run.sh.
#
# It lives outside run.sh because scripts/validate-mutant-kills.sh (M1) reads every KILLED/killed
# token on a non-comment line of run.sh as a kill emission, and a row's per-cell polarity is
# spelled `<arm>:killed=yes|no` so the reader never infers what a bare 0/1 means.
#
# matrix_row <id> <tripped arms, space-separated>
#   One line: `MATRIX <id> <arm>:killed=yes|no ... tripped=[<list>]`, a cell for EVERY arm in
#   $P_ALL (set by run.sh to the arms of the battery the row belongs to). MATRIX_ROWS counts the
#   rows printed, so run.sh can assert a plain run printed none.
MATRIX_ROWS=0
matrix_row() {
  local mr_tr=" $2 " mr_p mr_line="MATRIX $1" mr_t
  for mr_p in $P_ALL; do
    case "$mr_tr" in
      *" $mr_p "*) mr_line="$mr_line $mr_p:killed=yes" ;;
      *) mr_line="$mr_line $mr_p:killed=no" ;;
    esac
  done
  mr_t="$(printf '%s' "$2" | tr -s ' ' | sed 's/^ //; s/ $//')"
  printf '%s tripped=[%s]\n' "$mr_line" "$mr_t"
  MATRIX_ROWS=$((MATRIX_ROWS + 1))
}
