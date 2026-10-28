#!/usr/bin/env bash
# Sourced by run.sh. Prints one MATRIX row per mutant; kept out of run.sh because validate-mutant-kills.sh
# M1 flags any kill-polarity token on a non-comment line of run.sh itself.
# mx_row <mutant> <deciding-arm> <yes|no> <tripped,arms> <green,arms>
mx_row() { printf 'MATRIX %s decides=%s killed=%s tripped=[%s] green=[%s]\n' "$1" "$2" "$3" "$4" "$5"; }
