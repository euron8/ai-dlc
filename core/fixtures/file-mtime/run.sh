#!/usr/bin/env bash
# file-mtime -- core/scripts/file-mtime.sh states a file's mtime as an epoch and an ISO UTC stamp.
#
# Usage: run.sh        Exit: 0 = every assertion holds, 1 = a regression, 2 = fixture broken.
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
set -uo pipefail
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
# shellcheck source=/dev/null
. "$HERE/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }
# A literal-tail path, never `. "$VAR"`: in a fixture opted in by an inproc: row, P1 reads an opaque source as a drive.
[ -f "$HERE/../lib/mutant.sh" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE ERROR: sourcing lib/mutant.sh failed" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

W="$WORK/w"; N="$WORK/n"; SHIM="$WORK/shim"
mkdir -p "$W" "$N" "$SHIM"
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
# `set -uo pipefail`, TZ, PATH and cd stay there. The source is one fx_inproc pass (the inproc: row).
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

# run <tz> <dir> <args...> -> OUT, RC: one in-process call of fm_main
run() {
  local tz="$1" d="$2"; shift 2
  OUT="$(cd "$d" && export TZ="$tz" && fm_main "$@" 2>&1)"; RC=$?
}
run_shim() {
  OUT="$(cd "$W" && export TZ=UTC PATH="$SHIM:$PATH" && fm_main rec.md 2>&1)"; RC=$?
}
TAB="$(printf '\t')"

# --- arms, each a call of fm_main -----------------------------------------------------
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
if arm_utc; then ok "UTC: literal epoch and ISO stamp"
else bad "UTC arm: rc=$RC out=[$OUT]"; fi
if arm_ny; then ok "America/New_York: same literal stamp"
else bad "NY arm: rc=$RC out=[$OUT]"; fi
if arm_num; then ok "all-digit basename reports its mtime, not its name"
else bad "numeric-basename arm: rc=$RC out=[$OUT]"; fi
if arm_shape; then ok "GNU-shaped stat -f (exit 0, text) is not taken as an epoch"
else bad "stat-shape arm: rc=$RC out=[$OUT]"; fi
if arm_miss; then ok "MISSING path: reported, others still stated, exit 1"
else bad "MISSING arm: rc=$RC out=[$OUT]"; fi
if arm_noargs; then ok "no arguments: exit 2"
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

report_end file-mtime
