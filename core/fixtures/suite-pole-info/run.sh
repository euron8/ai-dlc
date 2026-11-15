#!/usr/bin/env bash
# suite-pole-info -- drive the distribution hook's pole_info_step, extracted verbatim from
# .githooks/pre-push, and assert the line it prints for every state a push can leave.
#
# WHY THIS EXISTS. The pole is printed as information and never judged, so no gate reads the
# line: a wrong one prints on every push and nothing goes red. Its first build read the prior
# record with `NR == FNR`, and with no prior record the first file is an empty /dev/null, so that
# condition held through THIS run's file too and every green push after a reset printed
# "(no suite run, no pole)". Caught only by driving the function offline. That case is arm 4 here.
#
# THIS RUN'S FIGURES ARE PROCESS STATE, NOT FILES. Pushes may run concurrently and the shared `.last`
# and durations records can belong to another push by the time the pole line runs, so the function
# reads LASTRUN_OWN (set by the pool) and POLE_PREV (snapshot before it). Arms 1-8 seed the shared
# files with the same figures as the variables; arm 9 seeds them with another push's, and must still
# print this run's pole.
#
# WHY THE FUNCTION IS EXTRACTED, NOT RE-WRITTEN. A probe that re-implements the awk is a second
# opinion whose bugs nobody finds. The body below is cut from the hook between its definition line
# and the first column-0 `}`, and the extraction is asserted non-empty and to define the function.
#
# Usage: run.sh
# Exit 0 = every arm holds, 1 = an arm regressed, 2 = the fixture could not run.
set -u

case "${1:-}" in
  "") ;;
  *) echo "suite-pole-info: usage: run.sh" >&2; exit 2 ;;
esac

# HERMETIC -- scrub the operator's tuning before reading anything (I10).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT=""
for cand in "$HERE/../../.." "$HERE/../.."; do
  if [ -f "$cand/.githooks/pre-push" ]; then ROOT="$(cd "$cand" && pwd)"; break; fi
done
[ -n "$ROOT" ] || { echo "FIXTURE ERROR: no .githooks/pre-push above $HERE"; exit 2; }
HOOK="$ROOT/.githooks/pre-push"
echo "HERMETIC-CONSUMED .githooks/pre-push"

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
extract() { awk '/^pole_info_step\(\) \{/{f=1} f{print} f&&/^\}/{exit}' "$1"; }
extract "$HOOK" > "$T/fn.sh"
if [ ! -s "$T/fn.sh" ] || ! grep -q '^pole_info_step() {' "$T/fn.sh"; then
  echo "FIXTURE BROKEN: pole_info_step could not be extracted from $HOOK"; exit 2
fi

# shellcheck source=/dev/null
. "$HERE/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }
# run_case <fn-file> -> the line the function prints, in a subshell so its globals cannot leak.
run_case() { ( . "$1"; pole_info_step ); }

DURATIONS_RECORD="$T/dur"; LASTRUN_RECORD="$T/last"
export DURATIONS_RECORD LASTRUN_RECORD
SUITE_SKIPPED=0; export SUITE_SKIPPED
LASTRUN_OWN=""; POLE_PREV=""

# own <last> <prev|-> -- this run's figures, and the shared files holding the SAME figures (no concurrent push).
own() {
  LASTRUN_OWN="$1"; printf '%s' "$1" > "$LASTRUN_RECORD"
  if [ "$2" = - ]; then POLE_PREV=""; rm -f "$DURATIONS_RECORD.prev"
  else POLE_PREV="$2"; printf '%s\n' "$2" > "$DURATIONS_RECORD.prev"; fi
}
# arm_setup <n> -- the whole state arm n reads (arms 1-5, 7 and 9-12), set from scratch so any arm can run on any function file.
# FIXTURE_JOBS is the pool width the hook sets; every arm sets it, so the caller's environment cannot reach it.
arm_setup() {
  SUITE_SKIPPED=0; FIXTURE_JOBS=12
  case "$1" in
    # 1. A prior figure for the pole unit: the delta is signed and reads off the SAME unit.
    1) own "$(printf 'small 10\nbig-unit 467\nmid 200')" "$(printf 'small 9\nbig-unit 381\nmid 210')" ;;
    # 2. Shrinkage prints a negative delta, not a clamp.
    2) own 'big-unit 300' 'big-unit 381' ;;
    # 3. The pole unit is new: the prior record exists but does not name it.
    3) own 'newunit 50' 'other 999' ;;
    # 4. NO prior record at all -- the case the first build got wrong.
    4) own 'newunit 50' - ;;
    # 5. This run published no durations.
    5) own '' - ;;
    # 7. The content-key skip: a stale figure must not be read as this run's. (Arm 6 was stop-early, which the hook no longer has.)
    7) own 'big-unit 467' - ; SUITE_SKIPPED=1 ;;
    # 9. A CONCURRENT PUSH has replaced both shared files: this run's own figures must still decide.
    9) own "$(printf 'small 10\nbig-unit 467\nmid 200')" "$(printf 'small 9\nbig-unit 381\nmid 210')"
       printf 'other-push 999\n' > "$LASTRUN_RECORD"; printf 'other-push 1\n' > "$DURATIONS_RECORD.prev" ;;
    # 10. The summed cost over the width exceeds the pole: the push is throughput-bound. The pole unit is not first.
    10) own "$(printf 'b 90\na 100\nc 80\nd 70')" - ; FIXTURE_JOBS=2 ;;
    # 11. Near-miss of 10: the summed cost over the width EQUALS the pole, which names the pole.
    11) own "$(printf 'b 100\na 100')" - ; FIXTURE_JOBS=2 ;;
    # 12. A width that is not a count names no bound, and the pole line still prints.
    12) own 'newunit 50' - ; FIXTURE_JOBS=abc ;;
  esac
}
arm_want() { # the exact output, whole, never a substring: a substring of the no-pole text is inside every malformed variant of it.
  # Arms 1 and 9 time 3 units at width 12: the width is cut to 3, so 677/3, not 677/12.
  case "$1" in
    1|9) printf '%s\n%s' "   pole big-unit 467s loaded (was 381s before this run, +86s)" \
           "   throughput 677s summed over 3 unit(s) / 3 worker(s) = 226s: POLE-BOUND (pole 467s >= 226s)" ;;
    2) printf '%s\n%s' "   pole big-unit 300s loaded (was 381s before this run, -81s)" \
         "   throughput 300s summed over 1 unit(s) / 1 worker(s) = 300s: POLE-BOUND (pole 300s >= 300s)" ;;
    3|4) printf '%s\n%s' "   pole newunit 50s loaded (no prior figure for it)" \
           "   throughput 50s summed over 1 unit(s) / 1 worker(s) = 50s: POLE-BOUND (pole 50s >= 50s)" ;;
    5|7) printf '%s' "   (no suite run, no pole)" ;;
    10) printf '%s\n%s' "   pole a 100s loaded (no prior figure for it)" \
          "   throughput 340s summed over 4 unit(s) / 2 worker(s) = 170s: THROUGHPUT-BOUND (170s > pole 100s)" ;;
    11) printf '%s\n%s' "   pole b 100s loaded (no prior figure for it)" \
          "   throughput 200s summed over 2 unit(s) / 2 worker(s) = 100s: POLE-BOUND (pole 100s >= 100s)" ;;
    12) printf '%s\n%s' "   pole newunit 50s loaded (no prior figure for it)" \
          "   throughput 50s summed over 1 unit(s); pool width \"abc\" is not a count, no bound named" ;;
  esac
}
expect() { # <label> <arm n> -- the line, whole, for arm n against the extracted function
  local got; arm_setup "$2"; got="$(run_case "$T/fn.sh")"
  if [ "$got" = "$(arm_want "$2")" ]; then ok "$1"; else bad "$1 -- wanted [$(arm_want "$2")], got [$got]"; fi
}
# 8. Information, never a verdict: the step returns 0 on every state. Prints the states on which it did not.
arm8_nz() { # <fn-file>
  local st nz=""
  SUITE_SKIPPED=0
  for st in grow none badwidth; do
    FIXTURE_JOBS=12
    case "$st" in
      grow) own 'u 9' 'u 1' ;;
      none) own '' - ;;
      badwidth) own 'u 9' - ; FIXTURE_JOBS=abc ;;
    esac
    ( . "$1"; pole_info_step >/dev/null ) || nz="$nz $st"
  done
  printf '%s' "$nz"
}

expect "1 prior figure, growth" 1
expect "2 prior figure, shrinkage" 2
expect "3 unit absent from the prior record" 3
# Arm 4: no prior record at all -- the case the first build got wrong.
arm_setup 4
got4="$(run_case "$T/fn.sh")"
if [ "$got4" = "$(arm_want 4)" ]; then ok "4 no prior record file"
else bad "4 no prior record file -- wanted [$(arm_want 4)], got [$got4]"; fi
expect "5 empty durations" 5
expect "7 content-key skip with a stale record on disk" 7
nz="$(arm8_nz "$T/fn.sh")"
if [ -z "$nz" ]; then ok "8 returns 0 on growth, on no run and on a width that is not a count"; else bad "8 returned non-zero on:$nz"; fi
# Arm 9: a concurrent push has replaced both shared files; this run's own figures must still decide.
arm_setup 9
got9="$(run_case "$T/fn.sh")"
if [ "$got9" = "$(arm_want 9)" ]; then ok "9 a concurrent push replaced both shared files: this run's own figures decide"
else bad "9 a concurrent push replaced both shared files -- wanted [$(arm_want 9)], got [$got9]"; fi
expect "10 summed cost / width exceeds the pole: THROUGHPUT-BOUND" 10
expect "11 summed cost / width equals the pole: POLE-BOUND" 11
expect "12 a width that is not a count names no bound" 12

report_end suite-pole-info 11
