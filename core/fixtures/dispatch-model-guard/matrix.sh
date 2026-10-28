# matrix.sh (dispatch-model-guard) -- sourced by run.sh AFTER ok() and bad() exist. It owns the mutant x arm matrix: the
# per-push subset (each mutant's deciding cells plus its twins) and the `--matrix` measurement
# (every cell of the mutant's own drive), and it is the only file that PRINTS matrix rows.
#
# A "cell" is one named observable of one drive. A mutant is judged on a vector of `cell=value`
# lines against a base vector of the same cells (the values the UNMUTATED subject gives):
#   tripped  the cell's value differs from its base value
#   decides  cells that must trip      -> the mutant is killed
#   twins    cells that must NOT trip  -> the kill is confined to the deciding cells
# Rows print as  MATRIX mutant=<m> arm=<cell> tripped=<yes|no> killed=<yes|no>  (killed is the
# mutant's verdict, repeated on each of its rows).  `mx_cells` is what keeps the other cells out of
# a plain run; MX_EXTRA counts the cells a run evaluated beyond decides+twins.
MX_EXTRA=0
MX_WHY=""

mx_get() { # mx_get <lines> <cell> -> the value after `cell=`
  printf '%s\n' "$1" | awk -v c="$2" 'BEGIN { FS = "=" } $1 == c { print substr($0, length(c) + 2); f = 1; exit } END { exit !f }'
}
mx_allyes() { # mx_allyes <csv of cells> -> cell=yes lines
  local c
  for c in ${1//,/ }; do printf '%s=yes\n' "$c"; done
}
mx_cells() { # mx_cells <all> <decides> <twins> -> the cells this run evaluates
  local t="$3"
  [ "$t" = - ] && t=""
  if [ "${MATRIX:-0}" = 1 ]; then printf '%s' "${1//,/ }"; else printf '%s %s' "${2//,/ }" "${t//,/ }"; fi
}
mx_vecof() { # mx_vecof <cellfn> <cells...> -> cell=value lines; the cell fn reads the caller's globals
  local fn="$1" c
  shift
  for c in "$@"; do printf '%s=%s\n' "$c" "$("$fn" "$c")"; done
}
mx_row() { printf 'MATRIX mutant=%s arm=%s tripped=%s killed=%s\n' "$1" "$2" "$3" "$4"; }

# mx_judge <mutant> <decides> <twins|-> <got-lines> <base-lines> [<expected-lines>]
# Returns 0 when every deciding cell tripped, every twin stayed at its base value, and (when given)
# every evaluated cell equals its expected value. Prints the rows in `--matrix` mode.
mx_judge() {
  local name="$1" dec="$2" tw="$3" got="$4" base="$5" exp="${6-}"
  local line c v b e trip in_dec in_tw dec_ok=1 conf_ok=1 rows="" killed pair
  [ "$tw" = - ] && tw=""
  MX_WHY=""
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    c="${line%%=*}"; v="${line#*=}"
    b="$(mx_get "$base" "$c")" || { MX_WHY="$MX_WHY [$c has no base value]"; continue; }
    if [ "$v" != "$b" ]; then trip=yes; else trip=no; fi
    if [ -n "$exp" ] && e="$(mx_get "$exp" "$c")"; then
      [ "$v" = "$e" ] || MX_WHY="$MX_WHY [$c got '$v' want '$e']"
    fi
    in_dec=0; in_tw=0
    case ",$dec," in *",$c,"*) in_dec=1 ;; esac
    case ",$tw," in *",$c,"*) in_tw=1 ;; esac
    [ "$in_dec" = 1 ] && [ "$trip" != yes ] && dec_ok=0
    [ "$in_tw" = 1 ] && [ "$trip" != no ] && conf_ok=0
    [ "$in_dec" = 0 ] && [ "$in_tw" = 0 ] && MX_EXTRA=$((MX_EXTRA + 1))
    rows="$rows$c:$trip "
  done <<<"$got"
  for c in ${dec//,/ }; do
    grep -q "^${c}=" <<<"$got" || { dec_ok=0; MX_WHY="$MX_WHY [deciding cell $c was not evaluated]"; }
  done
  [ "$dec_ok" = 1 ] && killed=yes || killed=no
  if [ "${MATRIX:-0}" = 1 ]; then
    for pair in $rows; do mx_row "$name" "${pair%%:*}" "${pair##*:}" "$killed"; done
  fi
  [ "$dec_ok" = 1 ] && [ "$conf_ok" = 1 ] && [ -z "$MX_WHY" ]
}

# mx_probe -- the matrix machinery's own both-directions probe, run on every invocation: a seeded
# kill is judged killed, a seeded survivor is judged not killed, and a twin that trips is refused.
mx_probe() {
  local was="${MATRIX:-0}" was_extra="$MX_EXTRA" r1=bad r2=bad r3=bad
  MATRIX=0
  mx_judge probe a b $'a=no\nb=yes\n' $'a=yes\nb=yes\n' >/dev/null && r1=ok
  mx_judge probe a b $'a=yes\nb=yes\n' $'a=yes\nb=yes\n' >/dev/null || r2=ok
  mx_judge probe a b $'a=no\nb=no\n' $'a=yes\nb=yes\n' >/dev/null || r3=ok
  MATRIX="$was"; MX_EXTRA="$was_extra"
  [ "$r1 $r2 $r3" = "ok ok ok" ]
}

# ---------------------------------------------------------------- family helpers ---
# A FAMILY is a vector battery: its cells are the named elements of one expected vector. For family
# <f> the caller defines SEP_<f> (the vector's separator, or `nl`), ALL_<f> (the comma list of cells),
# CELLFN_<f> (a function `fn <guard> <cell>` printing that cell's value) and BASE_<f> (the unmutated
# vector as cell=value lines, taken from the expected vector the base arms already assert in-run).
want_lines() { # want_lines <sep|nl> <string> -> one cell=value per line
  if [ "$1" = nl ]; then printf '%s\n' "$2" | awk '$0 != ""'
  else printf '%s' "$2" | awk -v RS="$1" '$0 != "" { print }'; fi
}
mx_kill() { # mx_kill <flag> <mutant> <decides> <twins|-> <got> <base> <message> [<expected>]
  if mx_judge "$2" "$3" "$4" "$5" "$6" "${8-}"; then mutant_killed "$1" "$2" "$7"
  else bad "MUTANT $2: deciding [$3] twins [$4] did not behave as recorded:$MX_WHY"; fi
}
fam_score() { # fam_score <fam> <mutant> <guard> <decides> <twins|-> <flag> <expected vector> <message>
  local fam="$1" name="$2" g="$3" dec="$4" tw="$5" flag="$6" expstr="$7" msg="$8"
  local sv="SEP_$1" av="ALL_$1" fv="CELLFN_$1" bv="BASE_$1" cells got c
  cells="$(mx_cells "${!av}" "$dec" "$tw")"
  got="$(for c in $cells; do printf '%s=%s\n' "$c" "$("${!fv}" "$g" "$c")"; done)"
  mx_kill "$flag" "$name" "$dec" "$tw" "$got" "${!bv}" "$msg" "$(want_lines "${!sv}" "$expstr")"
}
fam_control() { # fam_control <fam> <unmutated guard> <first cell> <message>: positive cell per push, every cell under --matrix
  local av="ALL_$1" fv="CELLFN_$1" bv="BASE_$1" c v b n=0 good=1
  for c in $(mx_cells "${!av}" "$3" -); do
    v="$("${!fv}" "$2" "$c")"; b="$(mx_get "${!bv}" "$c")" || b="<no base>"
    [ "$v" = "$b" ] || good=0
    n=$((n + 1))
  done
  [ "$n" -gt 1 ] && MX_EXTRA=$((MX_EXTRA + n - 1))
  if [ "$good" = 1 ] && [ "$n" -ge 1 ]; then ok "$4"
  else bad "$1 MUTANT CONTROL is dead: an unmutated hooks copy did not reproduce its base cells ($n evaluated) -- no kill in this family is believable"; fi
}
fam_mut() { # fam_mut <fam> <tag> <exact-anchor-line> <replacement-line> <decides> <twins|-> <flag> <expected> <message>
  local g n
  n="$(grep -cxF -- "$3" "$HOOK")" || n=0
  if [ "$n" != 1 ]; then bad "MUTANT $2 anchor matched $n lines in the guard, expected exactly 1"; return; fi
  g="$(mk_hooks_copy "$1-$2")"
  if [ -z "$g" ]; then bad "MUTANT $2: could not build the hooks copy"; return; fi
  A="$3" R="$4" awk '$0 == ENVIRON["A"] { print ENVIRON["R"]; next } { print }' "$HOOK" > "$g"
  if cmp -s "$HOOK" "$g"; then bad "MUTANT $2 DID NOT APPLY (cmp -s)"; return; fi
  if ! bash -n "$g" 2>/dev/null; then bad "MUTANT $2 DID NOT APPLY as valid shell"; return; fi
  fam_score "$1" "$2" "$g" "$5" "$6" "$7" "$8" "$9"
}
fam_sedmut() { # fam_sedmut <fam> <tag> <sed-expr> <decides> <twins|-> <flag> <expected> <message>
  local m="$WORK/guard-$1-$2.sh"
  sed "$3" "$HOOK" > "$m"
  if cmp -s "$HOOK" "$m"; then bad "MUTANT $2 matched nothing (cmp -s guard)"; return; fi
  bash -n "$m" 2>/dev/null || { bad "MUTANT $2 does not parse -- its silence would not be the mutation"; return; }
  fam_score "$1" "$2" "$m" "$4" "$5" "$6" "$7" "$8"
}
