# matrix.sh -- sourced by run.sh. Prints the MATRIX rows of `run.sh --matrix`. It lives beside run.sh,
# never inside it, because validate-mutant-kills.sh (M1) refuses a polarity word on a non-comment line
# of run.sh that is not a mutant_killed call.
#
# mx_row <mutant> <tripped-worlds> <all-worlds> <deciding-worlds> <twin-world>
# One row per mutant, polarity explicit: tripped=[worlds where the mutant differs from the shipped
# program], then whether every deciding world is among them and whether the twin is NOT.
MX_ROWS=0
mx_row() {
  local name="$1" tripped="$2" all="$3" dec="$4" twin="$5" w k=yes tg=yes
  for w in $dec; do case " $tripped " in *" $w "*) ;; *) k=no ;; esac; done
  case " $tripped " in *" $twin "*) tg=no ;; esac
  printf 'MATRIX %s decides=[%s] twins=[%s] tripped=[%s] of [%s] killed=%s twins_green=%s\n' \
    "$name" "$dec" "$twin" "$tripped" "$all" "$k" "$tg"
  MX_ROWS=$((MX_ROWS+1))
}
