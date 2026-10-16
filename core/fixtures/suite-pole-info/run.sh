#!/usr/bin/env bash
# suite-pole-info -- drive the distribution hook's pole_info_step, extracted verbatim from
# .githooks/pre-push, and assert the line it prints for every state a push can leave.
#
# WHY THIS EXISTS. The pole is printed as information and never judged, so no gate reads the
# line: a wrong one prints on every push and nothing goes red. Its first build read the prior
# record with `NR == FNR`, and with no prior record the first file is an empty /dev/null, so that
# condition held through THIS run's file too and every green push after a reset printed
# "(no suite run, no pole)". Caught only by driving the function offline. That case is arm 4 here,
# and m1 restores the old condition to prove arm 4 can fire.
#
# WHY THE FUNCTION IS EXTRACTED, NOT RE-WRITTEN. A probe that re-implements the awk is a second
# opinion whose bugs nobody finds. The body below is cut from the hook between its definition line
# and the first column-0 `}`, and the extraction is asserted non-empty and to define the function.
#
# Exit 0 = every arm and the mutant hold, 1 = an arm regressed, 2 = the fixture could not run.
set -u

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

rc=0
ok()  { printf 'ok    %s\n' "$*"; }
bad() { printf 'FAIL  %s\n' "$*"; rc=1; }
# run_case <fn-file> -> the line the function prints, in a subshell so its globals cannot leak.
run_case() { ( . "$1"; pole_info_step ); }

DURATIONS_RECORD="$T/dur"; LASTRUN_RECORD="$T/last"
export DURATIONS_RECORD LASTRUN_RECORD
SUITE_STOPPED_EARLY=0; SUITE_SKIPPED=0; export SUITE_STOPPED_EARLY SUITE_SKIPPED

# expect <label> <exact line> -- the line, whole, never a substring: a substring of the
# no-pole text is inside every malformed variant of it.
expect() {
  local got; got="$(run_case "$T/fn.sh")"
  if [ "$got" = "$2" ]; then ok "$1"; else bad "$1 -- wanted [$2], got [$got]"; fi
}

# 1. A prior figure for the pole unit: the delta is signed and reads off the SAME unit.
printf 'small 10\nbig-unit 467\nmid 200\n' > "$LASTRUN_RECORD"
printf 'small 9\nbig-unit 381\nmid 210\n'  > "$DURATIONS_RECORD.prev"
expect "1 prior figure, growth" "   pole big-unit 467s loaded (was 381s before this run, +86s)"
# 2. Shrinkage prints a negative delta, not a clamp.
printf 'big-unit 300\n' > "$LASTRUN_RECORD"; printf 'big-unit 381\n' > "$DURATIONS_RECORD.prev"
expect "2 prior figure, shrinkage" "   pole big-unit 300s loaded (was 381s before this run, -81s)"
# 3. The pole unit is new: the prior record exists but does not name it.
printf 'newunit 50\n' > "$LASTRUN_RECORD"; printf 'other 999\n' > "$DURATIONS_RECORD.prev"
expect "3 unit absent from the prior record" "   pole newunit 50s loaded (no prior figure for it)"
# 4. NO prior record at all -- the case the first build got wrong.
rm -f "$DURATIONS_RECORD.prev"
expect "4 no prior record file" "   pole newunit 50s loaded (no prior figure for it)"
# 5. This run published no durations.
: > "$LASTRUN_RECORD"
expect "5 empty durations" "   (no suite run, no pole)"
# 6. Stop-early and 7. the content-key skip: a stale record on disk must not be read as this run's.
printf 'big-unit 467\n' > "$LASTRUN_RECORD"
SUITE_STOPPED_EARLY=1; expect "6 stop-early with a stale record on disk" "   (no suite run, no pole)"; SUITE_STOPPED_EARLY=0
SUITE_SKIPPED=1;       expect "7 content-key skip with a stale record on disk" "   (no suite run, no pole)"; SUITE_SKIPPED=0
# 8. Information, never a verdict: the step returns 0 on every state above.
nz=""
for st in grow none stop; do
  case "$st" in
    grow) printf 'u 9\n' > "$LASTRUN_RECORD"; printf 'u 1\n' > "$DURATIONS_RECORD.prev" ;;
    none) : > "$LASTRUN_RECORD" ;;
    stop) printf 'u 9\n' > "$LASTRUN_RECORD"; SUITE_STOPPED_EARLY=1 ;;
  esac
  ( . "$T/fn.sh"; pole_info_step >/dev/null ) || nz="$nz $st"
  SUITE_STOPPED_EARLY=0
done
[ -z "$nz" ] && ok "8 returns 0 on growth, on no run and on stop-early" || bad "8 returned non-zero on:$nz"

# m1 -- THE FIRST BUILD'S CONDITION RESTORED. Arm 4 must kill it; arm 3 (prior file present) must not,
# which proves the mutant differs from the subject ONLY on the absent-file input.
sed 's/FILENAME == ARGV\[1\] {/NR == FNR {/' "$T/fn.sh" > "$T/m1.sh"
if cmp -s "$T/fn.sh" "$T/m1.sh"; then
  bad "m1 -- the mutation did not apply; the anchor 'FILENAME == ARGV[1]' moved"
else
  printf 'newunit 50\n' > "$LASTRUN_RECORD"; rm -f "$DURATIONS_RECORD.prev"
  m1_abs="$(run_case "$T/m1.sh")"
  printf 'other 999\n' > "$DURATIONS_RECORD.prev"
  m1_pre="$(run_case "$T/m1.sh")"
  if [ "$m1_abs" != "   pole newunit 50s loaded (no prior figure for it)" ] \
     && [ "$m1_pre" = "   pole newunit 50s loaded (no prior figure for it)" ]; then
    ok "m1 NR==FNR restored -- killed by arm 4 only (absent file read as [$m1_abs])"
  else
    bad "m1 NR==FNR restored -- absent [$m1_abs], present [$m1_pre]; arm 4 does not discriminate it"
  fi
fi

[ "$rc" -eq 0 ] && echo "PASS  suite-pole-info -- 8 arms, 1 mutant killed"
exit "$rc"
