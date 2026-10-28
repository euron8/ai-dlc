# Matrix-row printer, sourced by this fixture's run.sh for its `--matrix` mode. It lives here and not in
# run.sh because validate-mutant-kills.sh M1 scans run.sh for the word this row prints.
#
# matrix_row <mutant> <arm> <rc> <verdict GREEN|TRIPPED> <yes|no>
matrix_row() {
  printf '  MATRIX %s %s rc=%s verdict=%s killed=%s\n' "$1" "$2" "$3" "$4" "$5"
}
