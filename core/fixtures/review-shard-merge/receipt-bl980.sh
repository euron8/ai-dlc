#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
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
# is a receipt with no lib.sh call site, or one whose call site names an argument other than those two. A drive whose
# trace holds no git command at all, from a receipt whose non-comment text names no `git` word, cannot spawn
# auto-maintenance and is listed `<receipt>:nogit`, outside the count.
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
SPONLY=0; [ "${1:-}" = --self-probe-only ] && { SPONLY=1; shift; }
[ "$#" -eq 2 ] || [ "$#" -eq 3 ] || r_broken "usage: bash receipt-bl980.sh [--self-probe-only] <script dir> <project root> [<scan root>]"
SDIR="$(cd "$1" 2>/dev/null && pwd)" || r_broken "the script dir '$1' is not a directory"
PRJ="$(cd "$2" 2>/dev/null && pwd)" || r_broken "the project root '$2' is not a directory"
SELF="${BASH_SOURCE[0]##*/}"
W="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl980.XXXXXX")" || r_broken "mktemp failed"
trap 'rm -rf "$W"' EXIT

# r_args <receipt basename>: its arguments, one per line, from its ONE non-comment call site in $ARGROOT/lib.sh.
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
          printf "%s", out }' "$ARGROOT/lib.sh"
}
# r_drive <receipt path> <basename> <tag>: run it as lib.sh does; print "<maintenance spawns> <commits> <git commands>".
r_drive() {
  local t="$W/trace.$3.json" a n c
  a="$(r_args "$2" 2> "$W/args.$3.err")" || r_broken "$2 $(cat "$W/args.$3.err")"
  local IFS=$'\n'; set -f
  : > "$t" || return 1
  GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_TRACE2_EVENT="$t" bash "$1" $a > "$W/out.$3" 2>&1
  set +f; unset IFS
  n="$(grep -c '"event":"child_start".*"argv":\["git","maintenance","run"' "$t")" || n=0
  c="$(grep -c '"event":"cmd_name".*"name":"commit"' "$t")" || c=0
  g="$(grep -c '"event":"cmd_name"' "$t")" || g=0
  printf '%s %s %s\n' "$n" "$c" "$g"
}
# r_gwords <receipt>: how many of its non-comment lines name a `git` word.
r_gwords() { local n; n="$(grep -v '^[[:space:]]*#' "$1" | grep -cE '(^|[^A-Za-z0-9_.-])git([^A-Za-z0-9_-]|$)')" || n=0; printf '%s' "$n"; }
# THE NOGIT RULE, both conjuncts on its one line: a receipt is outside the population (listed <receipt>:nogit) only
# when its drive made no commit, its trace holds NO git command at all (receipt-bl988.sh asks a sourced parser only),
# AND its non-comment text names no `git` word. The text conjunct is what stops a receipt that DOES run git from
# reading nogit because its git never reached the trace (under `env -i`, or with GIT_TRACE2_EVENT redirected); the
# trace conjunct is what stops a receipt with no `git` word that runs git through a helper. Each is held by the
# self-probe below and by a mutant of this line. RESIDUAL: git reached only through a helper that also hides its trace.
r_nogit() { [ "$1" = 0 ] && [ "$2" = 0 ] && [ "$3" = 0 ]; } # <commits> <git commands> <git words>
# r_class <receipt> <basename> <tag> -> NOGIT | COMMIT <spawns> <commits> | NOCOMMIT
r_class() {
  local r n c g
  r="$(r_drive "$1" "$2" "$3")" || { printf 'BROKEN %s\n' "$r"; return; }
  set -- $r "$(r_gwords "$1")"; n="$1"; c="$2"; g="$3"
  if r_nogit "$c" "$g" "$4"; then echo NOGIT; elif [ "$c" -ge 1 ]; then echo "COMMIT $n $c"; else echo NOCOMMIT; fi
}

# ---- THE SELF-PROBE, before the corpus: three mktemp scan roots, one receipt each, judged by r_class.
#   sp1 a literal `git` commit under `env -i` (no trace event; the text names git)        -> NOCOMMIT (BROKEN)
#   sp2 no `git` word, a helper that runs `git --version` (a trace event, no commit)       -> NOCOMMIT (BROKEN)
#   sp3 no git at all (its one `git` is in a comment)                                      -> NOGIT
sp_root() { # <n> <receipt body> [helper body] -> the root
  local d="$W/sp-$1"
  mkdir -p "$d" && printf '  o="$(bash "$LIB_DIR/receipt-p.sh" "$PROJ" 2>&1)"\n' > "$d/lib.sh" \
    && printf '#!/bin/bash\n%s\n' "$2" > "$d/receipt-p.sh" || r_broken "SELF-PROBE: could not build scan root $1"
  [ -z "${3:-}" ] || printf '#!/bin/bash\n%s\n' "$3" > "$d/helper.sh" || r_broken "SELF-PROBE: could not build scan root $1's helper"
  printf '%s' "$d"
}
SP_GOT=""
for _sp in 1 2 3; do
  case "$_sp" in
    1) d="$(sp_root 1 'd="$(dirname "$0")/repo"; env -i PATH="$PATH" HOME="$d" git init -q "$d" && env -i PATH="$PATH" HOME="$d" git -C "$d" -c user.name=p -c user.email=p@p -c maintenance.auto=false -c gc.auto=0 commit -q --allow-empty -m p')" ;;
    2) d="$(sp_root 2 'bash "$(dirname "$0")/helper.sh"' 'git --version > /dev/null')" ;;
    3) d="$(sp_root 3 '# a comment naming git is no invocation
: nothing runs here')" ;;
  esac
  [ -n "$d" ] || r_broken "SELF-PROBE: scan root $_sp was not built"
  ARGROOT="$d"; SP_GOT="$SP_GOT sp$_sp=$(r_class "$d/receipt-p.sh" receipt-p.sh "sp$_sp")"
done
[ "$SP_GOT" = " sp1=NOCOMMIT sp2=NOCOMMIT sp3=NOGIT" ] \
  || r_broken "SELF-PROBE: the nogit rule read [${SP_GOT# }], want [sp1=NOCOMMIT sp2=NOCOMMIT sp3=NOGIT]: a git-running receipt read as nogit, or a git-free one did not"
[ "$SPONLY" = 0 ] || { echo "BL980 SELF-PROBE OK${SP_GOT}"; exit 0; }
# ---- the two conjunct mutants, built from this file and run --self-probe-only: each must be REFUSED by the self-probe.
for _m in text trace; do
  if [ "$_m" = text ]; then _o=' && [ "$3" = 0 ]; }'; else _o=' && [ "$2" = 0 ]'; fi
  # The copy sits at $W/mut-<m>/, so its line-2 seam resolves $W/lib/preamble.sh: the seam is copied there first.
  mkdir -p "$W/mut-$_m" "$W/lib" && cp "$HERE/../lib/preamble.sh" "$W/lib/preamble.sh" || r_broken "could not make the $_m mutant's directory and its seam"
  _src="${BASH_SOURCE[0]}"
  OLD="$_o" awk 'BEGIN { o = ENVIRON["OLD"] } /^r_nogit\(\) / { i = index($0, o); if (i) { $0 = substr($0, 1, i - 1) (o ~ /; }$/ ? "; }" : "") substr($0, i + length(o)); n++ } } { print } END { exit n != 1 }' "$_src" > "$W/mut-$_m/$SELF" \
    || r_broken "the $_m conjunct mutant did not apply (its conjunct is not on the r_nogit line once)"
  ! cmp -s "$_src" "$W/mut-$_m/$SELF" || r_broken "the $_m conjunct mutant changed nothing"
  _mo="$(bash "$W/mut-$_m/$SELF" --self-probe-only "$SDIR" "$PRJ" 2>&1)"; _mrc=$?
  case "$_mrc:$_mo" in 2:*"FIXTURE BROKEN: SELF-PROBE: the nogit rule read"*) MUTS="${MUTS:-}${MUTS:+,}$_m" ;;
    *) r_broken "the $_m conjunct mutant passed the self-probe (rc $_mrc: ${_mo##*$'\n'}): that conjunct is not held" ;; esac
done

ROOT="${3:-$HERE}"
ROOT="$(cd "$ROOT" 2>/dev/null && pwd)" || r_broken "the scan root '${3:-}' is not a directory"
[ -f "$ROOT/lib.sh" ] || r_broken "found no lib.sh in $ROOT, so no receipt has a call site to derive its arguments from"
ARGROOT="$ROOT"

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
# The copy sits at $W/seed/, so the ../lib/mutant.sh it sources (for fx_inproc) resolves $W/lib/mutant.sh: copied first.
mkdir -p "$W/seed" "$W/lib" && cp "$HERE/../lib/mutant.sh" "$W/lib/mutant.sh" || r_broken "could not make $W/seed and the lib/mutant.sh its copy sources"
sed 's/ -c maintenance\.auto=false//g' "$ROOT/receipt-bl904.sh" > "$W/seed/receipt-bl904.sh" || r_broken "could not build the must-fire"
n1="$(grep -c ' -c maintenance\.auto=false' "$W/seed/receipt-bl904.sh")" || n1=0
[ "$n1" = 0 ] || r_broken "the must-fire still carries the flag $n1 time(s)"

# ---- drives: every receipt, then the must-fire
fail=""; LIST=""; COMMITS=""; k=0
for f in $FILES; do
  k=$((k + 1)); b="${f##*/}"
  r="$(r_class "$f" "$b" "r$k")"
  case "$r" in
    NOGIT) LIST="$LIST${LIST:+,}$b"; COMMITS="$COMMITS${COMMITS:+,}$b:nogit"; continue ;;
    BROKEN*) r_broken "could not drive $b: ${r#BROKEN }" ;;
    NOCOMMIT) r_broken "$b made no commit when driven (its output: $(head -c 300 "$W/out.r$k" | tr '\n' ' ')), so its 0 spawns would prove nothing" ;;
  esac
  set -- $r; n="$2"; c="$3"
  [ "$n" = 0 ] || fail="$fail${fail:+; }$b spawned '$n'"
  LIST="$LIST${LIST:+,}$b"; COMMITS="$COMMITS${COMMITS:+,}$b:$c"
done
r="$(r_drive "$W/seed/receipt-bl904.sh" receipt-bl904.sh mf)" || r_broken "could not drive the must-fire: $r"
set -- $r; mf="$1"; mfc="$2"
[ "$mfc" -ge 1 ] && [ "$mf" -ge 1 ] || r_broken "the must-fire (receipt-bl904.sh less the flag) spawned '$mf' with $mfc commit(s), want at least 1 of each: this receipt cannot fail"
[ -z "$fail" ] || { echo "BL980 FAIL a receipt's commits spawned git maintenance run, want 0 each: $fail"; exit 1; }
echo "BL980 OK receipts=$NF files=$LIST commits=$COMMITS mustfire=$mf selfprobe=${SP_GOT# } conjunct-mutants-refused=$MUTS"
exit 0
