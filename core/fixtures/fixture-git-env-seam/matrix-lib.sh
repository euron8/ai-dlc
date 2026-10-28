# fixture-git-env-seam/matrix-lib.sh -- the printers of run.sh's `--matrix` mode, sourced by run.sh.
# They live here and not in run.sh because validate-mutant-kills.sh arm M1 refuses a kill-polarity word on a
# non-comment line of a run.sh that does not go through mutant_killed; a measured matrix cell has to PRINT that
# polarity, and this is the one place it is spelled.
#
# mx_diverge <shipped verdict> <mutant verdict> -> yes when the mutant's verdict differs from the shipped one
# on the SAME cell, else no. A cell's polarity is only ever read off that comparison.
mx_diverge() { if [ "$1" != "$2" ]; then printf 'yes'; else printf 'no'; fi; }
# mx_cell_row <mutant> <cell> <shipped verdict> <mutant verdict> <detail>
mx_cell_row() {
  printf 'MATRIX %s %s shipped=%s mutant=%s killed=%s detail=[%s]\n' "$1" "$2" "$3" "$4" "$(mx_diverge "$3" "$4")" "$5"
}
# mx_row <mutant> <tripped cells, space separated>
mx_row() { printf 'MATRIX-ROW %s tripped=[%s]\n' "$1" "$2"; }
