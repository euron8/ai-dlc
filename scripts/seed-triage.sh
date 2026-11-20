#!/bin/bash
# seed-triage.sh -- read a counted seed (scripts/seed-verdict-store.sh --keep) by script, never by hand.
#
#   bash scripts/seed-triage.sh [--tree <dir>] [--apply <tree>] <seed-log> <keep-dir>
#
# <seed-log> is the whole output of `scripts/seed-verdict-store.sh --keep <keep-dir> ...`. For every unit whose
# `<fx> rc=<n>` line is non-zero it prints EVERY failing line of that unit's output: <keep-dir>/<fx>.out for a plain
# unit, the `--- <fx>@consumer` section of <keep-dir>/consumer.out for a consumer unit (the census keeps only that
# section's last lines, which the report says), and then each line the log attributes to the unit that the kept output
# does not carry. A failing line carries FAIL, BROKEN, REFUSED, undeclared, ERROR or `REQUIRED input` ANYWHERE in the
# line; the only lines excluded are the pass shapes: `ok`, `PASS:`, `HERMETIC-CONSUMED`, the judge's
# `J6: <fx>: <n> bash subject(s) rowed` summary, `[J0] coverage join`, and hermetic-run's `verdict recorded` trailer.
#
# One verdict per non-zero unit:
#   J3-ONLY       rc 1, at least one J3 or J6 line, and no other failing line.
#   UNDECLARABLE  rc 2, hermetic-run's `carries no inputs.decl` refusal, no failing line, and
#                 core/fixtures/<fx>/.undeclarable present in the tree. Neither red nor J3; pregate and the push run it.
#   RED           everything else. A red with no failing line matched is printed whole, marked NO FAILING LINE MATCHED.
#
# --apply <tree>: for J3-ONLY units only, rewrites each J3 row `<declared> <target>` to `<measured> <target>` and
# appends each J6 `row to add` line, in <tree>/core/fixtures/<fx>/invocations.decl. Every row is checked before any
# file is written; a J3 row matching 0 or 2+ lines, a corpus (`<c>+<k>x<glob>`) row, a J6 target already rowed, or a
# missing invocations.decl is a refusal and nothing is written. A RED unit's J3/J6 lines print `not applied (unit has
# other reds)`.
# --tree <dir>: where .undeclarable is looked up (default: the --apply tree, else this script's own root).
#
# REFUSALS (exit 2): bad arguments; a log with no rc line; the rc lines counted by two grammars disagree; a unit named
# twice; any line the seeder printed of its own other than its gate-wait notices (an abort such as `left no rc` or
# `gave no verdict`: the units after it have no rc line, so the triage above it is incomplete and is printed, then
# refused); a plain unit with no <keep-dir>/<fx>.out; a non-zero consumer unit with no consumer.out section; a row
# --apply cannot place. Otherwise exit 1 while a RED unit, or a J3-ONLY unit without --apply, remains, and 0 when none
# does.
st_die() { echo "seed-triage: REFUSED: $*" >&2; exit 2; }

# st_root: the repo root, walked up from this script's directory to the first one carrying .githooks/pre-push and
# core/fixtures.
st_root() {
  local d
  d="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)" || return 1
  while [ -n "$d" ] && [ "$d" != / ]; do
    if [ -f "$d/.githooks/pre-push" ] && [ -d "$d/core/fixtures" ]; then printf '%s\n' "$d"; return 0; fi
    d="$(dirname "$d")"
  done
  return 1
}

# The classifier. Input lines are `<tag>\t<text>`; output is `<kind>\t<tag>\t<text>` for each failing line, where
# kind is J3, J6, or the arm code / failure word of any other failing line, and CTX for every other non-blank line
# that is not a pass shape (a cause the token grammar cannot spell, such as `FIXTURE STALE:`); a RED unit prints its
# CTX lines too, and CTX never decides a verdict.
ST_CLASSIFY='
{ tab = index($0, "\t"); tag = substr($0, 1, tab - 1); t = substr($0, tab + 1); sub(/\r$/, "", t) }
t ~ /^[[:blank:]]*ok([[:blank:]:]|$)/ { next }
t ~ /^[[:blank:]]*PASS:/ { next }
t ~ /^HERMETIC-CONSUMED / { next }
t ~ /^J6: [^ ]+: [0-9]+ bash subject\(s\) rowed/ { next }
t ~ /^[[:blank:]]*\[J0\] coverage join/ { next }
t ~ /^hermetic-run: [^ ]+: verdict recorded in / { next }
t !~ /FAIL|BROKEN|REFUSED|[Uu]ndeclared|ERROR|REQUIRED input/ { if (t ~ /[^[:blank:]]/) print "CTX\t" tag "\t" t; next }
{
  k = "FAIL"
  if (t ~ /: FAIL \(J3\): row "/) k = "J3"
  else if (t ~ /: FAIL \(J6\): .* row to add, measured on this run: [0-9]+ [^ ]+$/) k = "J6"
  else if (match(t, /FAIL \([A-Z][0-9]+[a-z]?\)/)) k = substr(t, RSTART + 6, RLENGTH - 7)
  else if (t ~ /[Uu]ndeclared/) k = "UNDECLARED"
  else if (t ~ /BROKEN/) k = "BROKEN"
  else if (t ~ /FAIL/) k = "FAIL"
  else if (t ~ /REFUSED/) k = "REFUSED"
  else if (t ~ /REQUIRED input/) k = "REQUIRED"
  else if (t ~ /ERROR/ && t !~ /FAIL/) k = "ERROR"
  print k "\t" tag "\t" t
}'

st_main() {
set -u
local apply="" tree="" log keep n_awk n_grep fx rc src kinds nj no verdict line
while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply) apply="${2:-}"; [ -n "$apply" ] && [ -d "$apply/core/fixtures" ] || st_die "--apply needs a tree carrying core/fixtures"; shift 2 ;;
    --tree) tree="${2:-}"; [ -n "$tree" ] && [ -d "$tree/core/fixtures" ] || st_die "--tree needs a tree carrying core/fixtures"; shift 2 ;;
    -*) st_die "unknown option $1" ;;
    *) break ;;
  esac
done
[ "$#" -eq 2 ] || st_die "usage: bash scripts/seed-triage.sh [--tree <dir>] [--apply <tree>] <seed-log> <keep-dir>"
log="$1"; keep="$2"
[ -f "$log" ] && [ -s "$log" ] || st_die "seed log $log is missing or empty"
[ -d "$keep" ] || st_die "keep dir $keep is not a directory"
if [ -z "$tree" ]; then
  if [ -n "$apply" ]; then tree="$apply"; else tree="$(st_root)" || st_die "cannot resolve the repo root for .undeclarable (pass --tree)"; fi
fi
w="$(mktemp -d "${TMPDIR:-/tmp}/seedtriage.XXXXXX")" || st_die "mktemp failed"
trap 'rm -rf "$w"' EXIT

# THE LOG. Each `<fx> rc=<n>` line opens its unit; the lines the seeder prints under it, and a `--- <fx>@consumer`
# census section, are attributed to that unit until the next opener. Seeder lines other than its gate-wait notices are
# kept as seed-level lines.
awk -v U="$w/units" -v L="$w/loglines" -v S="$w/seedlines" '
  { sub(/\r$/, "") }
  /^[A-Za-z0-9._-]+(@consumer)? rc=[0-9]+$/ { i = index($0, " rc="); cur = substr($0, 1, i - 1); print cur "\t" substr($0, i + 4) > U; next }
  /^[A-Za-z0-9._-]+@consumer not-selected/ { cur = ""; next }
  /^--- [A-Za-z0-9._-]+@consumer / { cur = $2; next }
  /^census: / || /^   \.\. / || /^counted store: / { cur = ""; next }
  /^seed-verdict-store: / { if ($0 !~ /waiting, a push gate|no push gate is running now|wait skipped/) print NR "\t" $0 > S; cur = ""; next }
  cur != "" { print cur "\t" NR "\t" $0 > L }
' "$log" || st_die "could not parse $log"
touch "$w/units" "$w/loglines" "$w/seedlines"
n_awk="$(awk 'END { print NR }' "$w/units")"
n_grep="$(grep -cE '^[^ :]+ rc=[0-9]+$' "$log")" || n_grep=0
[ "$n_awk" -gt 0 ] || st_die "no \`<fx> rc=<n>\` line in $log (scanned 0 units)"
[ "$n_awk" = "$n_grep" ] || st_die "scanned $n_awk unit(s) but $log carries $n_grep rc line(s); the two grammars disagree"
line="$(cut -f1 "$w/units" | LC_ALL=C sort | uniq -d | head -n 1)"
[ -z "$line" ] || st_die "$line has two rc lines in $log"

# Every plain unit has its kept output, red or green, so the keep dir is the one this log wrote.
while IFS="$(printf '\t')" read -r fx rc; do
  case "$fx" in *@consumer) continue ;; esac
  [ -f "$keep/$fx.out" ] || st_die "$fx has an rc line but no $keep/$fx.out"
done < "$w/units"

: > "$w/rows"; : > "$w/report"
nred=0; nj3=0; nund=0; ngreen=0; redlist=""; j3list=""; undlist=""
while IFS="$(printf '\t')" read -r fx rc; do
  if [ "$rc" = 0 ]; then ngreen=$((ngreen + 1)); continue; fi
  src="$w/src"; note=""
  case "$fx" in
    *@consumer)
      [ -f "$keep/consumer.out" ] || st_die "$fx is red but $keep/consumer.out is missing"
      awk -v h="--- $fx " '
        index($0, h) == 1 { on = 1; next }
        on && (/^--- / || /^census: /) { on = 0 }
        on { print }' "$keep/consumer.out" > "$src"
      [ -s "$src" ] || st_die "$fx is red but $keep/consumer.out carries no \`--- $fx\` section"
      note=" (census keeps only this section's last lines; the unit's whole output is not on disk)" ;;
    *) cp "$keep/$fx.out" "$src" ;;
  esac
  # Kept lines first, then the log's lines for this unit that the kept output does not carry.
  awk '{ print "keep:" NR "\t" $0 }' "$src" > "$w/tagged"
  awk -F'\t' -v fx="$fx" 'NR == FNR { have[$0] = 1; next } $1 == fx { t = $0; sub(/^[^\t]*\t[^\t]*\t/, "", t); if (!(t in have)) print "log:" $2 "\t" t }' \
    "$src" "$w/loglines" >> "$w/tagged"
  awk "$ST_CLASSIFY" "$w/tagged" > "$w/classed"
  awk -F'\t' '$1 == "CTX"' "$w/classed" > "$w/ctx"
  awk -F'\t' '$1 != "CTX"' "$w/classed" > "$w/failing"
  nj="$(awk -F'\t' '$1 == "J3" || $1 == "J6"' "$w/failing" | awk 'END { print NR }')"
  no="$(awk -F'\t' '$1 != "J3" && $1 != "J6"' "$w/failing" | awk 'END { print NR }')"
  kinds="$(cut -f1 "$w/failing" | awk '{ n[$0]++; if (!($0 in o)) { o[$0] = ++k; ord[k] = $0 } } END { for (i = 1; i <= k; i++) printf "%s%s %d", (i > 1 ? ", " : ""), ord[i], n[ord[i]] }')"
  if [ "$rc" = 2 ] && [ "$nj" = 0 ] && [ "$no" = 0 ] && grep -q "carries no inputs.decl" "$src" && [ -f "$tree/core/fixtures/${fx%@consumer}/.undeclarable" ]; then
    verdict=UNDECLARABLE; nund=$((nund + 1)); undlist="$undlist $fx"
  elif [ "$rc" = 1 ] && [ "$nj" -gt 0 ] && [ "$no" = 0 ]; then
    verdict=J3-ONLY; nj3=$((nj3 + 1)); j3list="$j3list $fx"
  else
    verdict=RED; nred=$((nred + 1)); redlist="$redlist $fx"
  fi
  {
    case "$verdict" in
      UNDECLARABLE) printf '== UNDECLARABLE %s rc=%s: hermetic-run refuses it (no inputs.decl, .undeclarable present); pregate and the push run it plain\n' "$fx" "$rc" ;;
      *) printf '== %s %s rc=%s: %s failing line(s)%s%s\n' "$verdict" "$fx" "$rc" "$((nj + no))" "${kinds:+: $kinds}" "$note" ;;
    esac
    awk -F'\t' -v v="$verdict" '{ t = $0; sub(/^[^\t]*\t[^\t]*\t/, "", t)
      tail = ""; if (v == "RED" && ($1 == "J3" || $1 == "J6")) tail = "   <- not applied (unit has other reds)"
      print "  " $2 ": " t tail }' "$w/failing"
    if [ "$verdict" = RED ] && [ "$((nj + no))" = 0 ]; then
      printf '  NO FAILING LINE MATCHED; the whole output follows\n'
      awk -F'\t' '{ t = $0; sub(/^[^\t]*\t/, "", t); print "  | " $1 ": " t }' "$w/tagged"
    elif [ "$verdict" = RED ] && [ -s "$w/ctx" ]; then
      printf '  every other line that is not a pass shape (a cause can sit here):\n'
      awk -F'\t' '{ t = $0; sub(/^[^\t]*\t[^\t]*\t/, "", t); print "  | " $2 ": " t }' "$w/ctx"
    fi
    if [ "$rc" = 2 ] && [ "$verdict" = RED ] && grep -q "carries no inputs.decl" "$src"; then
      printf '  note: carries no inputs.decl but core/fixtures/%s/.undeclarable is absent in %s\n' "${fx%@consumer}" "$tree"
    fi
  } >> "$w/report"
  if [ "$verdict" = J3-ONLY ]; then
    awk -F'\t' -v fx="$fx" '
      $1 == "J3" { t = $3; p = fx ": FAIL (J3): row \""; if (index(t, p) != 1) { print "BAD\t" t; next }
        r = substr(t, length(p) + 1); i = index(r, "\": measured "); if (i == 0) { print "BAD\t" t; next }
        raw = substr(r, 1, i - 1); r = substr(r, i + 12); j = index(r, ", declared ")
        m = substr(r, 1, j - 1); r = substr(r, j + 11); d = r; sub(/ .*/, "", d)
        if (j == 0 || m !~ /^[0-9]+$/ || d !~ /^[0-9]+$/) { print "BAD\t" t; next }
        print fx "\tJ3\t" raw "\t" m "\t" d; next }
      $1 == "J6" { t = $3; p = fx ": FAIL (J6): "; if (index(t, p) != 1) { print "BAD\t" t; next }
        r = t; sub(/.* row to add, measured on this run: /, "", r); m = r; sub(/ .*/, "", m); tg = r; sub(/^[0-9]+ /, "", tg)
        print fx "\tJ6\t" tg "\t" m }' "$w/failing" >> "$w/rows"
  fi
done < "$w/units"

[ ! -s "$w/seedlines" ] || { printf '== SEED-LEVEL lines (the seeder itself)\n'; awk -F'\t' '{ t = $0; sub(/^[^\t]*\t/, "", t); print "  log:" $1 ": " t }' "$w/seedlines"; }
cat "$w/report"
printf 'seed-triage: scanned %s unit(s) (%s rc lines by both grammars): %s green, %s RED, %s J3-ONLY, %s UNDECLARABLE\n' \
  "$n_awk" "$n_grep" "$ngreen" "$nred" "$nj3" "$nund"
[ -z "$redlist" ] || printf '  RED:%s\n' "$redlist"
[ -z "$j3list" ] || printf '  J3-ONLY:%s\n' "$j3list"
[ -z "$undlist" ] || printf '  UNDECLARABLE:%s\n' "$undlist"
[ ! -s "$w/seedlines" ] || st_die "the seeder printed $(awk 'END { print NR }' "$w/seedlines") line(s) of its own (SEED-LEVEL above), so the seed did not finish and units may have no rc line; re-seed"
line="$(awk -F'\t' '$1 == "BAD" { sub(/^BAD\t/, ""); print; exit }' "$w/rows")"
[ -z "$line" ] || st_die "a J3/J6 line does not parse: $line"

if [ -n "$apply" ] && [ -s "$w/rows" ]; then
  # CHECK every row, then WRITE: a refusal leaves every invocations.decl as it was.
  : > "$w/plan"
  while IFS="$(printf '\t')" read -r fx kind a m d; do
    dfile="$apply/core/fixtures/$fx/invocations.decl"
    [ -f "$dfile" ] || st_die "$fx: no $dfile"
    if [ "$kind" = J3 ]; then
      case "${a%%[[:blank:]]*}" in *[!0-9]*|'') st_die "$fx: row \"$a\" is a corpus row; set it by hand" ;; esac
      [ "${a%%[[:blank:]]*}" = "$d" ] || st_die "$fx: row \"$a\" does not open with its declared count $d"
      n="$(awk -v r="$a" '{ sub(/\r$/, "") } $0 == r { n++ } END { print n + 0 }' "$dfile")"
      [ "$n" = 1 ] || st_die "$fx: row \"$a\" matches $n line(s) of $dfile; want exactly 1 (is the tree the one seeded?)"
    else
      n="$(awk -v tg="$a" '$0 !~ /^[[:blank:]]*#/ && NF == 2 && $2 == tg { n++ } END { print n + 0 }' "$dfile")"
      [ "$n" = 0 ] || st_die "$fx: J6 target $a already carries $n row(s) in $dfile"
    fi
    printf '%s\t%s\t%s\t%s\n' "$fx" "$kind" "$a" "$m" >> "$w/plan"
  done < "$w/rows"
  line="$(cut -f1,2,3 "$w/plan" | LC_ALL=C sort | uniq -d | head -n 1)"
  [ -z "$line" ] || st_die "the same row is listed twice: $line"
  napplied=0
  for fx in $(cut -f1 "$w/plan" | LC_ALL=C sort -u); do
    dfile="$apply/core/fixtures/$fx/invocations.decl"
    awk -F'\t' -v fx="$fx" -v D="$dfile" '
      NR == FNR { if ($1 == fx && $2 == "J3") j3[$3] = $4; if ($1 == fx && $2 == "J6") j6[++n6] = $4 " " $3; next }
      { l = $0; sub(/\r$/, "", l); if (l in j3) { c = l; sub(/^[0-9]+/, j3[l], c); print c } else print $0 }
      END { for (i = 1; i <= n6; i++) print j6[i] }' "$w/plan" "$dfile" > "$w/new" || st_die "$fx: rewrite failed"
    cat "$w/new" > "$dfile" || st_die "$fx: could not write $dfile"
    napplied=$((napplied + $(awk -F'\t' -v fx="$fx" '$1 == fx' "$w/plan" | awk 'END { print NR }')))
  done
  printf 'seed-triage: applied %s row(s) (%s J3, %s J6) in %s\n' "$napplied" \
    "$(awk -F'\t' '$2 == "J3"' "$w/plan" | awk 'END { print NR }')" "$(awk -F'\t' '$2 == "J6"' "$w/plan" | awk 'END { print NR }')" "$apply"
  [ "$nred" = 0 ] || return 1
  return 0
fi
[ "$nred" = 0 ] && [ "$nj3" = 0 ] || return 1
return 0
}
# Loadable: sourced, this file defines its functions and runs nothing; executed, it runs st_main.
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0
st_main "$@"
