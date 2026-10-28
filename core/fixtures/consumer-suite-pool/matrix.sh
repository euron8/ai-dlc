# matrix.sh -- sourced by run.sh AFTER ok() and bad() exist. It owns the mutant x arm matrix: the
# per-push subset (each mutant's deciding cells plus its twins) and the `--matrix` measurement
# (every cell of the mutant's own drive), and it is the only file that PRINTS matrix rows.
#
# A "cell" is one named observable of one drive. A mutant is judged on a vector of `cell=value`
# lines against a base vector of the same cells (the values the UNMUTATED subject gives):
#   tripped  the cell's value differs from its base value
#   decides  cells that must trip      -> the mutant is killed
#   twins    cells that must NOT trip  -> the kill is confined to the deciding cells
# Rows print as  MATRIX mutant=<m> arm=<cell> tripped=<yes|no> killed=<yes|no>  (killed is the cell's own trip; the mutant's verdict is the MATRIX-MUTANT line
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
mx_row() { printf 'MATRIX mutant=%s arm=%s tripped=%s killed=%s\n' "$1" "$2" "$3" "$3"; }  # killed is the CELL's own polarity: yes iff the cell tripped

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
    for pair in $rows; do mx_row "$name" "${pair%%:*}" "${pair##*:}"; done
    printf 'MATRIX-MUTANT %s dead=%s\n' "$name" "$killed"   # the per-mutant verdict, on its own line
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
