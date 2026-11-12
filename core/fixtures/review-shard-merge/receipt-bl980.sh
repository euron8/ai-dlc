#!/usr/bin/env bash
# BL-980 receipt (no receipt in this fixture directory lets a commit spawn auto-maintenance). Usage:
#   bash receipt-bl980.sh <script dir> <project root> [<scan root>]
# <script dir> and <project root> are what lib.sh's receipt call sites name $sd and $PROJ (from the distribution's
# root: `core/scripts .`). The scan root defaults to this file's own directory; a probe tree is fed through it.
# Invoked by lib.sh's p_gmaint (arm GM1), which drives lib.sh's own G and the raw-git control itself.
#
# THE POPULATION IS PER FILE, judged by BEHAVIOUR, never by spelling: every <scan root>/receipt-*.sh but this one (the
# driver; it would run itself) is RUN the way lib.sh runs it, its arguments derived from its call site in
# <scan root>/lib.sh (a non-comment line `bash "$LIB_DIR/<receipt>" ...`, each argument "$sd/<file>" or "$PROJ"), with
# GIT_TRACE2_EVENT set and no system or global gitconfig, and the `git maintenance run` child_start events across its
# WHOLE run are counted: they must be 0. However a receipt spells or reaches git, a commit that spawns auto-maintenance
# is counted. A drive that made no commit (cmd_name "commit" absent from its trace) proves nothing, so it is BROKEN, as
# is a receipt with no lib.sh call site, or one whose call site names an argument other than those two.
# Why no environment default (GIT_CONFIG_COUNT) instead: hermetic-run starts the fixture under `env -i`, and
# scripts/validate-backlog-receipts.sh unsets GIT_CONFIG_COUNT before a verify line, so an export would have to be
# repeated in every receipt; and an export in lib.sh would reach every receipt THIS driver runs, reading 0 for a
# receipt that sets nothing and is unprotected when run alone. Each receipt carries its own flag on its own wrapper.
#
# Guards, each a FIXTURE BROKEN (exit 2): at least one receipt is driven, and receipt-bl904.sh (which cp -R's the
# repository its commits just wrote) is among them; the must-fire, receipt-bl904.sh copied with every
# ` -c maintenance.auto=false` stripped and driven the same way, must spawn at least 1, else this receipt cannot fail.
# The stripped copy must carry 0 flags; there is no cmp, and a strip that changed nothing is caught because the
# must-fire must spawn at least 1.
# Prints ONE verdict line and exits with it:
#   BL980 OK receipts=<n> files=<receipt,...> commits=<receipt:n,...> mustfire=<n>     exit 0
#   BL980 FAIL <receipt spawned 'c'; ...>                                              exit 1
#   BL980 FIXTURE BROKEN: <why>                                                         exit 2
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
r_broken() { echo "BL980 FIXTURE BROKEN: $1"; exit 2; }
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || r_broken "cannot resolve the receipt's own directory"
[ "$#" -eq 2 ] || [ "$#" -eq 3 ] || r_broken "usage: bash receipt-bl980.sh <script dir> <project root> [<scan root>]"
SDIR="$(cd "$1" 2>/dev/null && pwd)" || r_broken "the script dir '$1' is not a directory"
PRJ="$(cd "$2" 2>/dev/null && pwd)" || r_broken "the project root '$2' is not a directory"
ROOT="${3:-$HERE}"
ROOT="$(cd "$ROOT" 2>/dev/null && pwd)" || r_broken "the scan root '${3:-}' is not a directory"
SELF="${BASH_SOURCE[0]##*/}"
[ -f "$ROOT/lib.sh" ] || r_broken "found no lib.sh in $ROOT, so no receipt has a call site to derive its arguments from"
W="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl980.XXXXXX")" || r_broken "mktemp failed"
trap 'rm -rf "$W"' EXIT

# r_args <receipt basename>: its arguments, one per line, from its ONE non-comment call site in lib.sh.
r_args() {
  awk -v b="$1" -v sd="$SDIR" -v pj="$PRJ" '
    /^[[:space:]]*#/ { next }
    { i = index($0, "bash \"$LIB_DIR/" b "\""); if (!i) next
      n++; t = substr($0, i + length("bash \"$LIB_DIR/" b "\""))
      sub(/[[:space:]]*2>&1.*$/, "", t); sub(/\).*$/, "", t)
      m = split(t, a, /[[:space:]]+/); out = ""
      for (j = 1; j <= m; j++) {
        if (a[j] == "") continue
        if (a[j] == "\"$PROJ\"") { out = out pj "\n"; continue }
        if (a[j] ~ /^"\$sd\/[A-Za-z0-9._-]+"$/) { f = a[j]; gsub(/^"\$sd\/|"$/, "", f); out = out sd "/" f "\n"; continue }
        bad = "names the argument " a[j] ", neither \"$sd/<file>\" nor \"$PROJ\""
      } }
    END { if (n != 1) { print "has " n + 0 " call site(s) in lib.sh, want 1" > "/dev/stderr"; exit 1 }
          if (bad != "") { print bad > "/dev/stderr"; exit 1 }
          printf "%s", out }' "$ROOT/lib.sh"
}
# r_drive <receipt path> <basename> <tag>: run it as lib.sh does; print "<maintenance spawns> <commits>".
r_drive() {
  local t="$W/trace.$3.json" a n c
  a="$(r_args "$2" 2> "$W/args.$3.err")" || r_broken "$2 $(cat "$W/args.$3.err")"
  local IFS=$'\n'; set -f
  : > "$t" || return 1
  GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_TRACE2_EVENT="$t" bash "$1" $a > "$W/out.$3" 2>&1
  set +f; unset IFS
  n="$(grep -c '"event":"child_start".*"argv":\["git","maintenance","run"' "$t")" || n=0
  c="$(grep -c '"event":"cmd_name".*"name":"commit"' "$t")" || c=0
  printf '%s %s\n' "$n" "$c"
}

# ---- the population, by glob
set -- "$ROOT"/receipt-*.sh
[ -f "$1" ] || r_broken "found no receipt-*.sh in $ROOT"
FILES=""; NF=0; H904=0
for f in "$@"; do
  b="${f##*/}"
  [ "$b" = "$SELF" ] && continue
  FILES="$FILES $f"; NF=$((NF + 1)); [ "$b" = receipt-bl904.sh ] && H904=1
done
[ "$NF" -ge 1 ] || r_broken "the glob holds no receipt but this one"
[ "$H904" = 1 ] || r_broken "receipt-bl904.sh, the must-hit (it copies the repository its commits wrote), is absent from $ROOT"

# ---- the must-fire: receipt-bl904.sh less its flag, driven the same way
mkdir -p "$W/seed" || r_broken "could not make $W/seed"
sed 's/ -c maintenance\.auto=false//g' "$ROOT/receipt-bl904.sh" > "$W/seed/receipt-bl904.sh" || r_broken "could not build the must-fire"
n1="$(grep -c ' -c maintenance\.auto=false' "$W/seed/receipt-bl904.sh")" || n1=0
[ "$n1" = 0 ] || r_broken "the must-fire still carries the flag $n1 time(s)"

# ---- drives: every receipt, then the must-fire
fail=""; LIST=""; COMMITS=""; k=0
for f in $FILES; do
  k=$((k + 1)); b="${f##*/}"
  r="$(r_drive "$f" "$b" "r$k")" || r_broken "could not drive $b: $r"
  n="${r% *}"; c="${r#* }"
  [ "$c" -ge 1 ] || r_broken "$b made no commit when driven (its output: $(head -c 300 "$W/out.r$k" | tr '\n' ' ')), so its 0 spawns would prove nothing"
  [ "$n" = 0 ] || fail="$fail${fail:+; }$b spawned '$n'"
  LIST="$LIST${LIST:+,}$b"; COMMITS="$COMMITS${COMMITS:+,}$b:$c"
done
r="$(r_drive "$W/seed/receipt-bl904.sh" receipt-bl904.sh mf)" || r_broken "could not drive the must-fire: $r"
mf="${r% *}"; mfc="${r#* }"
[ "$mfc" -ge 1 ] && [ "$mf" -ge 1 ] || r_broken "the must-fire (receipt-bl904.sh less the flag) spawned '$mf' with $mfc commit(s), want at least 1 of each: this receipt cannot fail"
[ -z "$fail" ] || { echo "BL980 FAIL a receipt's commits spawned git maintenance run, want 0 each: $fail"; exit 1; }
echo "BL980 OK receipts=$NF files=$LIST commits=$COMMITS mustfire=$mf"
exit 0
