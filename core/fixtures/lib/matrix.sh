# Matrix-row printer. Sourced by a fixture run.sh that implements `--matrix`.
# The row grammar is read mechanically by the integrator, so it lives in one place and a run.sh
# carries no printf of its own for it (scripts/validate-mutant-kills.sh M1 scans run.sh files for the
# word this row prints).
#
# matrix_row <mutant> <arm> <rc> <verdict GREEN|TRIPPED> <yes|no>
matrix_row() {
  printf '  MATRIX %s %s rc=%s verdict=%s killed=%s\n' "$1" "$2" "$3" "$4" "$5"
}
