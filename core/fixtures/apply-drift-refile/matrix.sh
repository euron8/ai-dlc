# Sourced by apply-drift-refile/run.sh. Holds the one function that PRINTS a mutant-matrix row, so the
# row text lives outside run.sh (validate-mutant-kills.sh M1 reads run.sh lines for a kill token).
# mx_row <mutant> <arm> <PASS|FAIL> [<cell>] -- called only under `run.sh --matrix`; MX_ROWS counts the calls.
MX_ROWS=0
mx_row() { MX_ROWS=$((MX_ROWS+1)); printf '  MATRIX %s | %s | %s tripped=%s | %s\n' "$1" "$2" "$3" "$([ "$3" = FAIL ] && echo yes || echo no)" "${4:-}"; }
