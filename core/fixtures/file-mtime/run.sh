#!/usr/bin/env bash
# file-mtime -- core/scripts/file-mtime.sh states a file's mtime as an epoch and an ISO UTC stamp.
#
# Usage: run.sh [--matrix]        Exit: 0 = every assertion holds, 1 = a regression, 2 = fixture broken.
#
# THE ORACLE IS A LITERAL. Files are seeded with `TZ=UTC touch -t 202610160459.42`, so the
# expected answer is the constant 2026-10-16T04:59:42Z / 1792126782 and nothing in this
# fixture computes it with the tool under test. It is asserted under TZ=America/New_York as
# well as TZ=UTC, because a local-time format agrees with UTC in exactly one of the two.
#
# THE NUMERIC-BASENAME WORLD. BSD `date -r` reads an all-digit argument as an epoch, so a
# file NAMED 1792126782 with a 2020 mtime must report 2020, not the time its name spells.
# The script is invoked with the bare relative name from inside the directory, because an
# absolute path is never all-digit and would not discriminate.
#
# THE STAT-SHAPE WORLD. A `stat` shim answers `-f` the way GNU does (filesystem text, exit
# 0) and `-c %Y` with the seeded epoch. Only a shape check passes; an exit-code probe takes
# the filesystem text as the epoch.
#
# Each mutant is a literal replace that must match exactly once, is guarded by cmp -s, and
# must be killed by its arm. A mutant that no arm can kill on this platform is reported
# SKIP with the reason, never counted as killed.
#
# THE MUTANT MATRIX (mutant-battery rule). Every mutant could be scored on all six arms. PER PUSH a mutant scores
# only its DECIDING arm and its named TWIN (an arm it could plausibly co-trip and does not); with --matrix it
# scores every arm and prints one `MATRIX <mutant> <arm> KILLED|GREEN` row per pair. The block below is the one
# source: mx_cell reads it from this file, a plain run refuses a mutant with no row, and a cell whose result
# disagrees with its row is a failure. An arm token is the arm's base-pass flag name without the B_ prefix.
#
# The matrix is re-measured as .claude/rules/fixture-mutants.md clause 2 ("One run per distinct state")
# requires. hermetic-run.sh runs a fixture under `env -i` and
# forwards no argument, so the matrix is NOT reached through it; run.sh is invoked directly from the repo root.
# MUTANT-MATRIX-REMEASURE bash core/fixtures/file-mtime/run.sh --matrix
# MUTANT-MATRIX nolocal decides=ny,num twins=utc
# MUTANT-MATRIX exitcode decides=shape twins=utc
# MUTANT-MATRIX missok decides=miss twins=utc
# MUTANT-MATRIX datepath decides=num twins=utc
#
# A MATRIX row is a measurement and not a second kill emission: its kill goes through mutant_killed behind the
# same base-pass flag the arm sets. The mutant name reaches mutant_killed as a variable:
# MUTANT-MATRIX-DYNAMIC mx_cell why=passes each of the four mutant names below as a variable and every name keeps its own row
set -uo pipefail
MATRIX=0
for _a in "$@"; do
  case "$_a" in
    --matrix) MATRIX=1 ;;
    *) echo "FIXTURE ERROR: unknown argument '$_a' (only --matrix)" >&2; exit 2 ;;
  esac
done
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
SUBJ=""
for c in "$HERE/../../scripts/file-mtime.sh" "$HERE/../../../scripts/ai-dlc/file-mtime.sh"; do
  [ -f "$c" ] && { SUBJ="$c"; break; }
done
[ -n "$SUBJ" ] || { echo "FIXTURE ERROR: cannot locate file-mtime.sh in either layout" >&2; exit 2; }
SUBJ="$(cd "$(dirname "$SUBJ")" && pwd)/$(basename "$SUBJ")"
echo "HERMETIC-CONSUMED $SUBJ"

WORK="$(mktemp -d)" || exit 2
trap 'rm -rf "$WORK"' EXIT
fails=0
ok()  { printf '   ok    %s\n' "$1"; }
bad() { printf '   FAIL  %s\n' "$1" >&2; fails=$((fails + 1)); }
# A literal-tail path, never `. "$VAR"`: in a fixture opted in by an inproc: row, P1 reads an opaque source as a drive.
[ -f "$HERE/../lib/mutant.sh" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE ERROR: sourcing lib/mutant.sh failed" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

W="$WORK/w"; N="$WORK/n"; SHIM="$WORK/shim"; MUT="$WORK/mut"
mkdir -p "$W" "$N" "$SHIM" "$MUT"
TZ=UTC touch -t 202610160459.42 "$W/rec.md"
TZ=UTC touch -t 202001020304.05 "$N/1792126782"

LIT_E=1792126782; LIT_I=2026-10-16T04:59:42Z
NUM_E=1577934245; NUM_I=2020-01-02T03:04:05Z

# A GNU-shaped stat: `-f` is --file-system (text, exit 0); `-c %Y` is the mtime.
cat > "$SHIM/stat" <<EOF
#!/bin/bash
case "\$1" in
  -f) echo "  File: \"\$3\""; echo "    ID: 0 Namelen: 255 Type: ext2/ext3"; exit 0 ;;
  -c) echo 1792126782; exit 0 ;;
esac
exit 1
EOF
chmod +x "$SHIM/stat"

# IN PROCESS (BL-878). The subject is SOURCED once into this shell (its guard returns after defining fm_main), and
# every arm calls fm_main inside a `$( )` subshell, so the subject's own `exit` ends that subshell and its
# `set -uo pipefail`, TZ, PATH and cd stay there. A mutant copy is sourced once in its turn, which redefines fm_main,
# so the arms below always drive the copy sourced last. Each source is one fx_inproc pass (the inproc: row).
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. A consumer can receive this file one pull before the wrapped
# file-mtime.sh, and sourcing a pre-wrap subject would run its top-level `[ $# -ge 1 ] || exit 2` in this shell. So the
# shape is checked first, on its two halves: neither the `fm_main() {` line nor the column-0 source guard is a subject
# that predates the wrap, which prints SKIP and exits 0 -- never an ok. Exactly one half is a respelled subject this
# fixture can no longer drive, which FAILS. The distribution cannot reach the SKIP unnoticed: C5
# (validate-fixture-inprocess.sh) refuses a cli subject without the guard, and J3 refuses the start count moving.
fm_def=0; fm_guard=0
grep -q '^fm_main() {$' "$SUBJ"; _gx=$?
[ "$_gx" -le 1 ] || { echo "FIXTURE ERROR: cannot read $SUBJ (grep exit $_gx) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
[ "$_gx" -ne 0 ] || fm_def=1
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$SUBJ"; _gx=$?
[ "$_gx" -le 1 ] || { echo "FIXTURE ERROR: cannot read $SUBJ (grep exit $_gx) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
[ "$_gx" -ne 0 ] || fm_guard=1
if [ "$fm_def$fm_guard" = 00 ]; then echo "SKIP: subject predates the in-process wrap"; exit 0; fi
if [ "$fm_def" = 0 ]; then echo "   FAIL  $SUBJ carries the column-0 source guard but no \`fm_main() {\` line -- a respelled subject this fixture cannot drive" >&2; echo "file-mtime: FAIL (1)" >&2; exit 1; fi
if [ "$fm_guard" = 0 ]; then echo "   FAIL  $SUBJ defines \`fm_main() {\` but carries no column-0 source guard -- a respelled subject; sourcing it would run fm_main in this shell" >&2; echo "file-mtime: FAIL (1)" >&2; exit 1; fi
fx_inproc "$SUBJ"
. "$SUBJ" || { echo "FIXTURE BROKEN: sourcing $SUBJ failed" >&2; exit 2; }
declare -F fm_main > /dev/null || { echo "FIXTURE BROKEN: sourcing $SUBJ defined no fm_main" >&2; exit 2; }

# run <tz> <dir> <args...> -> OUT, RC: one in-process call of the fm_main sourced last
run() {
  local tz="$1" d="$2"; shift 2
  OUT="$(cd "$d" && export TZ="$tz" && fm_main "$@" 2>&1)"; RC=$?
}
run_shim() {
  OUT="$(cd "$W" && export TZ=UTC PATH="$SHIM:$PATH" && fm_main rec.md 2>&1)"; RC=$?
}
TAB="$(printf '\t')"

# --- arms, each a call of the fm_main sourced last, so a mutant reuses it --------------
arm_utc()   { run UTC "$W" rec.md;                    [ "$RC" -eq 0 ] && [ "$OUT" = "rec.md${TAB}${LIT_E}${TAB}${LIT_I}" ]; }
arm_ny()    { run America/New_York "$W" rec.md;       [ "$RC" -eq 0 ] && [ "$OUT" = "rec.md${TAB}${LIT_E}${TAB}${LIT_I}" ]; }
arm_num()   { run America/New_York "$N" 1792126782;   [ "$RC" -eq 0 ] && [ "$OUT" = "1792126782${TAB}${NUM_E}${TAB}${NUM_I}" ]; }
arm_shape() { run_shim;                               [ "$RC" -eq 0 ] && [ "$OUT" = "rec.md${TAB}${LIT_E}${TAB}${LIT_I}" ]; }
arm_miss()  {
  run UTC "$W" nope.md rec.md
  [ "$RC" -eq 1 ] && [ "$OUT" = "nope.md${TAB}MISSING
rec.md${TAB}${LIT_E}${TAB}${LIT_I}" ]
}
arm_noargs() { OUT="$(fm_main 2>&1)"; RC=$?; [ "$RC" -eq 2 ]; }

echo "== real script"
# Each arm sets its B_<arm> flag only in its passing branch; the mutant that arm kills is scored on it.
if arm_utc; then ok "UTC: literal epoch and ISO stamp"; B_utc=1
else bad "UTC arm: rc=$RC out=[$OUT]"; fi
if arm_ny; then ok "America/New_York: same literal stamp"; B_ny=1
else bad "NY arm: rc=$RC out=[$OUT]"; fi
if arm_num; then ok "all-digit basename reports its mtime, not its name"; B_num=1
else bad "numeric-basename arm: rc=$RC out=[$OUT]"; fi
if arm_shape; then ok "GNU-shaped stat -f (exit 0, text) is not taken as an epoch"; B_shape=1
else bad "stat-shape arm: rc=$RC out=[$OUT]"; fi
if arm_miss; then ok "MISSING path: reported, others still stated, exit 1"; B_miss=1
else bad "MISSING arm: rc=$RC out=[$OUT]"; fi
if arm_noargs; then ok "no arguments: exit 2"; B_noargs=1
else bad "no-args arm: rc=$RC out=[$OUT]"; fi

# --- the cli cells (cells.decl): the subject run as a PROGRAM once per distinct CLI outcome -----------------------
# The outcomes are exit x output class: 0 every path stated on stdout, 1 a MISSING row on stdout, 2 the usage line
# on stderr. One `FXCELL=<id> bash "$SUBJ"` start per outcome, each compared with the in-process call on the same
# input: stdout, stderr and exit separately, byte for byte. A cell also asserts its own outcome (a positive conjunct,
# so two runs that both printed nothing cannot read as equivalent), and the pass and refuse cells must differ.
EQ="$WORK/eq"; mkdir -p "$EQ"
eqv() { # <cell-id> <tz> <dir> <args...> -> $EQ/<id>.{ip,cl}.{out,err,rc}
  local id="$1" tz="$2" d="$3"; shift 3
  ( cd "$d" && export TZ="$tz" && fm_main "$@" ) > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  ( cd "$d" && TZ="$tz" FXCELL="$id" bash "$SUBJ" "$@" ) > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
}
eq_twin() { printf 'in-process rc=%s out=[%s] err=[%s] / program rc=%s out=[%s] err=[%s]' "$(cat "$EQ/$1.ip.rc")" \
  "$(cat "$EQ/$1.ip.out")" "$(cat "$EQ/$1.ip.err")" "$(cat "$EQ/$1.cl.rc")" "$(cat "$EQ/$1.cl.out")" "$(cat "$EQ/$1.cl.err")"; }
echo "== cli cells"
if eqv cli-pass UTC "$W" rec.md && [ "$(cat "$EQ/cli-pass.cl.rc")" = 0 ] \
   && [ "$(cat "$EQ/cli-pass.cl.out")" = "rec.md${TAB}${LIT_E}${TAB}${LIT_I}" ] && [ ! -s "$EQ/cli-pass.cl.err" ]; then
  ok "cli-pass: the program states rec.md exactly as the in-process call does (stdout, stderr, exit 0)"
else bad "cli-pass: the program and the in-process call differ, or the outcome is not exit 0 with the literal row ($(eq_twin cli-pass))"; fi
if eqv cli-missing UTC "$W" nope.md rec.md && [ "$(cat "$EQ/cli-missing.cl.rc")" = 1 ] \
   && [ "$(cat "$EQ/cli-missing.cl.out")" = "nope.md${TAB}MISSING
rec.md${TAB}${LIT_E}${TAB}${LIT_I}" ] && [ ! -s "$EQ/cli-missing.cl.err" ]; then
  ok "cli-missing: the program refuses nope.md exactly as the in-process call does (stdout, stderr, exit 1)"
else bad "cli-missing: the program and the in-process call differ, or the outcome is not exit 1 with a MISSING row ($(eq_twin cli-missing))"; fi
if eqv cli-usage UTC "$W" && [ "$(cat "$EQ/cli-usage.cl.rc")" = 2 ] && [ ! -s "$EQ/cli-usage.cl.out" ] \
   && [ "$(cat "$EQ/cli-usage.cl.err")" = "usage: file-mtime.sh <path> [<path> ...]" ]; then
  ok "cli-usage: the program refuses no arguments exactly as the in-process call does (stdout, stderr, exit 2)"
else bad "cli-usage: the program and the in-process call differ, or the outcome is not exit 2 with the usage line ($(eq_twin cli-usage))"; fi
if ! cmp -s "$EQ/cli-pass.cl.out" "$EQ/cli-missing.cl.out" && ! cmp -s "$EQ/cli-pass.cl.rc" "$EQ/cli-missing.cl.rc"; then
  ok "cli cells discriminate: the passing and the refusing input give different stdout and exit"
else bad "cli cells do not discriminate: cli-pass and cli-missing gave the same stdout or exit"; fi

# --- mutants: literal replace, exactly once, cmp -s guarded, killed by its arm -------
# mutate <name> <old> <new> [<old> <new>] -> writes $MUT/<name>/core/scripts/file-mtime.sh and SOURCES it once. The
# copy keeps the subject's declared suffix, so its fx_inproc row is counted under the same inproc: row.
mutate() {
  local name="$1"; shift
  local f="$MUT/$name/core/scripts/file-mtime.sh"; mkdir -p "${f%/*}"; cp "$SUBJ" "$f"
  while [ $# -ge 2 ]; do
    local o="$1" n="$2"; shift 2
    local cnt; cnt="$(grep -cF -- "$o" "$f")" || cnt=0
    if [ "$cnt" -ne 1 ]; then echo "FIXTURE ERROR: mutant $name: pattern matched $cnt times: $o" >&2; exit 2; fi
    local content out; content="$(cat "$f")"
    out=${content/"$o"/"$n"}   # assignment, not an expansion in double quotes: bash 3.2 keeps those quotes literal
    printf '%s\n' "$out" > "$f"
  done
  if cmp -s "$SUBJ" "$f"; then echo "FIXTURE ERROR: mutant $name is byte-identical to the subject" >&2; exit 2; fi
  unset -f fm_main
  fx_inproc "$f"
  . "$f" || { echo "FIXTURE BROKEN: sourcing mutant $name failed" >&2; exit 2; }
  declare -F fm_main > /dev/null || { echo "FIXTURE BROKEN: sourcing mutant $name defined no fm_main" >&2; exit 2; }
  MUT_SOURCED="$name"
}
MUT_SOURCED=""
MX_SRC="$HERE/run.sh"; MX_CELLS=0; MX_RUN=0; MX_SEEN=""
mx_row() { grep -m 1 -F -- "# MUTANT-MATRIX $1 decides=" "$MX_SRC"; } # no awk: the tool farm of this fixture does not declare it
mx_role() { # <mutant> <arm> -> D (decides), T (twin) or - (neither), read from the header block
  local line d tw; line="$(mx_row "$1")"
  [ -n "$line" ] || { echo -; return; }
  d="${line#*decides=}"; d="${d%% *}"; tw="${line#*twins=}"; tw="${tw%% *}"
  case ",$d," in *",$2,"*) echo D; return ;; esac
  case ",$tw," in *",$2,"*) echo T; return ;; esac
  echo -
}
mx_has_row() { [ -n "$(mx_row "$1")" ]; }
# mx_cell <mutant> <arm> <arm fn> <the arm's base-pass flag> -- score the mutant on one arm: the arm FAILING on the
# mutant is KILLED, holding is GREEN.
mx_cell() {
  local m="$1" t="$2" fn="$3" fl="$4" role
  case " $MX_SEEN " in
    *" $m "*) ;;
    *) MX_SEEN="$MX_SEEN $m"
       if [ "$MATRIX" != 1 ] && ! mx_has_row "$m"; then
         bad "mutant $m has no MUTANT-MATRIX row in $MX_SRC -- a per-push run cannot know its deciding arm or its twins"
       fi ;;
  esac
  role="$(mx_role "$m" "$t")"
  if [ "$MATRIX" != 1 ] && [ "$role" = - ]; then return 0; fi
  [ "$role" = - ] && MX_CELLS=$((MX_CELLS + 1))
  MX_RUN=$((MX_RUN + 1))
  [ "$MUT_SOURCED" = "$m" ] || { echo "FIXTURE BROKEN: scoring mutant $m while the fm_main sourced last is ${MUT_SOURCED:-the subject}" >&2; exit 2; }
  if "$fn"; then
    ok "MATRIX $m $t GREEN"
    if [ "$MATRIX" != 1 ] && [ "$role" = D ]; then bad "mutant $m SURVIVED arm $t, which the header names as its deciding arm"; fi
  else
    mutant_killed "$fl" "$m" "MATRIX $m $t KILLED"
    if [ "$MATRIX" != 1 ] && [ "$role" = T ]; then bad "mutant $m failed arm $t, which the header names as its twin"; fi
  fi
  return 0
}
mx_all() { # <mutant> -- every arm, in arm order
  mx_cell "$1" utc    arm_utc    "${B_utc:-0}"
  mx_cell "$1" ny     arm_ny     "${B_ny:-0}"
  mx_cell "$1" num    arm_num    "${B_num:-0}"
  mx_cell "$1" shape  arm_shape  "${B_shape:-0}"
  mx_cell "$1" miss   arm_miss   "${B_miss:-0}"
  mx_cell "$1" noargs arm_noargs "${B_noargs:-0}"
}

echo "== mutants"
mutate nolocal 'date -u -r "$1"' 'date -r "$1"' 'date -u -d "@$1"' 'date -d "@$1"'
mx_all nolocal

mutate exitcode '_e="$(stat -f %m "$1" 2>/dev/null)"' '_e="$(stat -f %m "$1" 2>/dev/null)" && { printf "%s" "$_e"; return 0; }'
mx_all exitcode

mutate missok 'exit "$rc"' 'exit 0'
mx_all missok

mutate datepath 'ep="$(mtime_epoch "$p")"' 'ep="$(date -r "$p" +%s)"'
if [ "$(cd "$N" && date -r 1792126782 +%s 2>/dev/null)" = "1792126782" ]; then
  mx_all datepath
else
  echo "   SKIP  mutant datepath: this date does not read an all-digit path as an epoch, so no arm can kill it here"
fi

# MX0: a plain run executes no matrix-only cell; --matrix scores every cell and says how many.
if [ "$MATRIX" = 1 ]; then
  echo "MATRIX MODE: $MX_RUN cells"
  if [ "$MX_RUN" -gt 0 ]; then ok "MX0 matrix mode: $MX_RUN cells scored"; else bad "MX0 matrix mode: --matrix scored no cell"; fi
elif [ "$MX_CELLS" -eq 0 ]; then ok "MX0 per-push run: matrix-only cells run = 0 (cells scored: $MX_RUN)"
else bad "MX0 per-push run: $MX_CELLS matrix-only cell(s) ran"; fi

if [ "$fails" -gt 0 ]; then echo "file-mtime: $fails FAILED" >&2; exit 1; fi
echo "file-mtime: all arms ok"
exit 0
