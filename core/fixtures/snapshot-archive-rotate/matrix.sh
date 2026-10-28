# snapshot-archive-rotate/matrix.sh — the mutant x arm matrix printer, sourced by run.sh.
#
# It lives beside run.sh rather than inside it because each cell prints its polarity as a
# `killed=yes|no` token, and validate-mutant-kills.sh (M1) reads every non-comment line of run.sh
# carrying that word as a kill emission. The scan covers run.sh only, so the printer sits here.
#
# MATRIX_ROWS counts the rows printed. A plain (per-push) run must end with it at 0, which run.sh
# asserts, so the matrix-only path cannot run silently on a plain invocation.
MATRIX_ROWS=0

# matrix_row <mutant> <deciding column> <failed list> <column...>: one row, every column with its
# polarity. A column is "killed=yes" when it is in the failed list (the arm went red under the
# mutant), "killed=no" when it stayed green.
matrix_row() {
  local m="$1" dec="$2" failed=" $3 " row c
  shift 3
  row="  MATRIX ${m} decides=${dec} |"
  for c in "$@"; do
    case "$failed" in
      *" $c "*) row="${row} ${c}:killed=yes" ;;
      *)        row="${row} ${c}:killed=no" ;;
    esac
  done
  printf '%s\n' "$row"
  MATRIX_ROWS=$((MATRIX_ROWS + 1))
}
