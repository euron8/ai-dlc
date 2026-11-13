#!/usr/bin/env bash
# receipt-bl988.sh [<fixture-dir> | <record-only-diff.sh>] -- BL-988's receipt, run by lib.sh's p_wrap (cell wr-receipt)
# beside it on every push, as `"$sd/record-only-diff.sh"` (the form receipt-bl980.sh drives every receipt in).
# A consumer's operator-mandated wrapper (`python3 -u scripts/<wrapper>.py --cwd <root> ... -- <pytest args>`) was
# recorded by --record-run and refused by the check half: RUN-SHAPE read it as no run and RUN-FILTER read every token
# after its bare `--` as a path handed to the runner. record-only-diff.sh now reads a wrapper the conventions DECLARE.
#   R0 the subject, sourced, defines ro_main (an empty `exit 0` stub fails here);
#   R1 the declared wrapper form, under a conventions file declaring it, reads RUN-SHAPE 0 and RUN-FILTER 0;
#   R2 the plain pytest control under the same file reads 0 and 0 (the receipt is not a reader that passes everything);
#   R3 the same payload under an undeclared wrapper is refused by both (the near-miss: R1 is not "any wrapper passes");
#   R4 a positional before the declared wrapper's bare `--` is refused by RUN-FILTER, naming it.
# The subject is record-only-diff.sh: the file named, or else found exactly as lib.sh finds its subjects (its find_up,
# walking up from <fixture-dir>, default this file's directory): core/scripts/record-only-diff.sh (the distribution and the hermetic
# sandbox) or scripts/ai-dlc/record-only-diff.sh (an installed tree), never by counting `..`; a scratch tree holding
# another revision's file there is the must-fail probe. Each ask SOURCES the subject in a subshell and calls its
# ro_main (no bash start), bounded by CPU time, `ulimit -t 5` (a loop that never ends burns CPU and dies of SIGXCPU,
# whatever the load), and `ulimit -f 2048`, its stdin /dev/null; no wall clock bounds it (BL-868).
# Exit: 0 every row holds, 1 a row failed, 2 no subject was found.
set -u
# fx_inproc (core/fixtures/lib/mutant.sh) logs this receipt's in-process passes under the fixture's counted run.
# mutant.sh refuses to load without ok() and bad(), so it is sourced behind stubs that are removed again, as
# lib/inproc.sh sources it.
case "${BASH_SOURCE[0]}" in */*) _rl="${BASH_SOURCE[0]%/*}/../lib" ;; *) _rl=../lib ;; esac
ok() { :; }; bad() { :; }
. "$_rl/mutant.sh" || { echo "FIXTURE BROKEN: cannot source $_rl/mutant.sh" >&2; exit 2; }
unset -f ok bad; unset _rl
D="${1:-$(cd "$(dirname "$0")" && pwd)}"
LIB_DIR=""; [ -f "$D" ] || LIB_DIR="$(cd "$D" 2> /dev/null && pwd)" || LIB_DIR=""
# lib.sh's find_up, byte for byte, walking up from <fixture-dir> as lib.sh walks up from its own directory.
find_up() { # <rel-dist> <rel-consumer> -> first existing path walking up from $LIB_DIR
  local d="$LIB_DIR" c
  while [ -n "$d" ] && [ "$d" != "/" ]; do
    for c in "$d/$1" "$d/$2"; do [ -f "$c" ] && { printf '%s' "$c"; return 0; }; done
    d="$(dirname "$d")"
  done
  return 1
}
if [ -f "$D" ]; then RO="$D"
else RO="$(find_up core/scripts/record-only-diff.sh scripts/ai-dlc/record-only-diff.sh)" || RO=""; fi
# A pass is logged only for a subject at its own path (a core/scripts directory); a mutant script directory's
# copy is no pass of the subject.
case "${RO%/*}" in */core/scripts) RO_PASS=1 ;; *) RO_PASS=0 ;; esac
[ -n "$RO" ] || { echo "  FAIL  receipt-bl988: no core/scripts/record-only-diff.sh or scripts/ai-dlc/record-only-diff.sh above $D"; exit 2; }
rfail=0
rok()  { printf '  ok    receipt-bl988 %s\n' "$1"; }
rbad() { printf '  FAIL  receipt-bl988 %s\n' "$1"; rfail=1; }
W="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl988.XXXXXX")" || { echo "  FAIL  receipt-bl988: mktemp failed"; exit 2; }
CV="$W/coding-conventions.md"
printf -- '%s\n' '- canonical: `pytest suite/tests`' \
  '- the mandated wrapper: `python3 -u scripts/w.py --cwd <repo-root> --python <venv>/bin/python -- <pytest args>`' > "$CV"
# ask <mode> <value> -> AR (exit), AO (stdout and stderr).
# NO WALL-CLOCK WATCHDOG (BL-868: no verdict may be decided by real time; a `sleep 600` backstop stood here and is
# removed). The CPU limit (`ulimit -t`) ends the only hang an ask can reach, the declaration reader's awk spinning.
# Nothing else in an ask can block: its stdin is /dev/null, it reads only regular files to EOF, and it reads no fifo,
# starts no background child and opens no network. So a hang that remains would be a new defect, and it now shows as
# a hang -- the push's own watchdog reports a stalled fixture -- rather than as a silent pass or fail real time decided.
ask() {
  ( ulimit -t 5; ulimit -f 2048; set +u; [ "$RO_PASS" = 0 ] || fx_inproc "$RO"; . "$RO" && ro_main "$1" "$2" "$CV" ) > "$W/out" 2>&1 < /dev/null &
  wait "$!"; AR=$?
  AO=""; IFS= read -r -d '' AO < "$W/out"; AO="${AO%$'\n'}"
}
row() { # <id> <value> <want run-shape exit> <want run-filter exit> <run-filter output must contain, or empty for none>
  local s f
  ask run-shape "$2"; s="$AR"
  ask run-filter "$2"; f="$AR"
  if [ "$s" = "$3" ] && [ "$f" = "$4" ] && { [ -z "$5" ] && [ -z "$AO" ] || { [ -n "$5" ] && case "$AO" in *"$5"*) true ;; *) false ;; esac; }; }; then
    rok "$1 run-shape $s, run-filter $f${5:+ ($5)}"
  else rbad "$1 read run-shape $s and run-filter $f [$AO], expected $3 and $4${5:+ naming [$5]}"; fi
}
# R0: sourced, the subject defines ro_main and returns to the caller (a subject that exits while sourced, or defines
# nothing, would answer every ask with its own exit and pass the 0/0 rows having read nothing).
r0="$( ( ulimit -t 5; ulimit -f 2048; set +u; [ "$RO_PASS" = 0 ] || fx_inproc "$RO"; . "$RO" > /dev/null 2>&1 < /dev/null; declare -F ro_main > /dev/null && echo RO-MAIN ) 2> /dev/null )"
if [ "$r0" = RO-MAIN ]; then rok "R0 $RO defines ro_main when sourced"
else rbad "R0 $RO, sourced, did not return defining ro_main; no row below reads it"; fi
row R1 '`python3 -u scripts/w.py --cwd /r --python /v/bin/python -- suite/tests -q -n 8`' 0 0 ""
row R2 '`.venv-ci/bin/python -m pytest suite/tests -q -n 8`' 0 0 ""
row R3 '`python3 -u scripts/other.py --cwd /r --python /v/bin/python -- suite/tests -q -n 8`' 1 1 "suite/tests"
row R4 '`python3 -u scripts/w.py --cwd /r tests/test_x.py -- -q`' 1 1 "(tests/test_x.py)"
rm -f "$CV" "$W/out"; rmdir "$W" 2> /dev/null
exit "$rfail"
