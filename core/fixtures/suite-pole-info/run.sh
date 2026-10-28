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
# THE MUTANT MATRIX. m1 is scored per push on its DECIDING arm (arm4) and its named TWIN (arm3), which
# reads the same awk with a prior record present and must stay GREEN under it. `run.sh --matrix` scores m1
# against all eight arms and prints one MATRIX line. The matrix is re-measured whenever an arm or a mutant
# is added or changed, by the REMEASURE command below, run from the repo root.
# MUTANT-MATRIX m1 decides=arm4 twins=arm3
# MUTANT-MATRIX-REMEASURE bash core/fixtures/suite-pole-info/run.sh --matrix
#
# Usage: run.sh [--matrix]
# Exit 0 = every arm and the mutant hold, 1 = an arm regressed, 2 = the fixture could not run.
set -u

# MODE is "matrix" only under the positional `--matrix`; anything else is a usage error.
MODE=plain
case "${1:-}" in
  "") ;;
  --matrix) MODE=matrix ;;
  *) echo "suite-pole-info: usage: run.sh [--matrix]" >&2; exit 2 ;;
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

rc=0
ok()  { printf 'ok    %s\n' "$*"; }
bad() { printf 'FAIL  %s\n' "$*"; rc=1; }
MUT_LIB="$HERE/../lib/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$MUT_LIB"
# run_case <fn-file> -> the line the function prints, in a subshell so its globals cannot leak.
run_case() { ( . "$1"; pole_info_step ); }

# ---- matrix plumbing. The header rows are the only source of a mutant's deciding arm and twins. ----
SELF_FILE="$HERE/run.sh"
MXL="$T/mx.ledger"; : > "$MXL"
MX_DEC_GREEN=""; MX_BROKEN=0
mx_row() { # <mutant> <decides|twins> -> that field of the mutant's single header row
  local n="$1" f="$2" l w c=0 v=""
  while IFS= read -r l; do
    case "$l" in
      "# MUTANT-MATRIX $n "*)
        c=$((c + 1))
        for w in ${l#"# MUTANT-MATRIX $n "}; do case "$w" in "$f="*) v="${w#"$f="}" ;; esac; done ;;
    esac
  done < "$SELF_FILE"
  [ "$c" -eq 1 ] && printf '%s' "$v"
}
mx_count() { # <kind> -> how many ledger lines of that kind
  local k="$1" l n=0
  while IFS= read -r l; do case "$l" in "$k "*) n=$((n + 1)) ;; esac; done < "$MXL"
  printf '%s' "$n"
}
mx_chk() { case "$1" in *"unbound variable"*|*"command not found"*|*"syntax error"*) MX_BROKEN=1 ;; esac; }
# mx_eval <mutant> <every arm...> -- the deciding arm(s) and twin(s) always; every other arm only under --matrix.
mx_eval() {
  local m="$1" a dec tw g=0 tot=0 decs="" tws="" uex=""
  shift
  dec="$(mx_row "$m" decides)"; tw="$(mx_row "$m" twins)"
  if [ -z "$dec" ] || [ -z "$tw" ]; then
    bad "FIXTURE BROKEN: no single MUTANT-MATRIX row names the deciding arm and twins of $m"; MX_DEC_GREEN=" row"; return
  fi
  MX_DEC_GREEN=""
  for a in ${dec//,/ }; do
    printf 'dec %s %s\n' "$m" "$a" >> "$MXL"
    if mx_cell_red "$m" "$a"; then decs="$decs,$a:RED"; else decs="$decs,$a:GREEN"; MX_DEC_GREEN="$MX_DEC_GREEN $a"; uex="$uex $a:GREEN"; fi
  done
  for a in ${tw//,/ }; do
    printf 'dec %s %s\n' "$m" "$a" >> "$MXL"
    if mx_cell_red "$m" "$a"; then
      tws="$tws,$a:RED"; uex="$uex $a:RED"
      bad "$m: its twin $a also tripped -- the mutant is not confined to its own arm"
    else tws="$tws,$a:GREEN"; fi
  done
  if [ "$MODE" = matrix ]; then # mx-all-arms
    rd=""
    for a in "$@"; do
      case ",$dec,$tw," in *",$a,"*) continue ;; esac
      printf 'mx %s %s\n' "$m" "$a" >> "$MXL"
      tot=$((tot + 1)); if mx_cell_red "$m" "$a"; then rd="$rd,$a"; else g=$((g + 1)); fi
    done
    if [ "$MX_BROKEN" -ne 0 ]; then printf 'MATRIX BROKEN %s\n' "$m"; exit 2; fi
    if [ -n "$uex" ]; then
      printf 'MATRIX %s decides=%s twins=%s others=%d/%d%s UNEXPECTED=%s\n' "$m" "${decs#,}" "${tws#,}" "$g" "$tot" "${rd:+ red=${rd#,}}" "${uex# }"
    else
      printf 'MATRIX %s decides=%s twins=%s others=%d/%d%s\n' "$m" "${decs#,}" "${tws#,}" "$g" "$tot" "${rd:+ red=${rd#,}}"
    fi
  elif [ "$MX_BROKEN" -ne 0 ]; then printf 'MATRIX BROKEN %s\n' "$m"; exit 2; fi
}

DURATIONS_RECORD="$T/dur"; LASTRUN_RECORD="$T/last"
export DURATIONS_RECORD LASTRUN_RECORD
SUITE_STOPPED_EARLY=0; SUITE_SKIPPED=0; export SUITE_STOPPED_EARLY SUITE_SKIPPED

# arm_setup <n> -- the whole state arm n reads (arms 1-7), set from scratch so any arm can run on any function file.
arm_setup() {
  SUITE_STOPPED_EARLY=0; SUITE_SKIPPED=0; rm -f "$DURATIONS_RECORD.prev"
  case "$1" in
    # 1. A prior figure for the pole unit: the delta is signed and reads off the SAME unit.
    1) printf 'small 10\nbig-unit 467\nmid 200\n' > "$LASTRUN_RECORD"
       printf 'small 9\nbig-unit 381\nmid 210\n'  > "$DURATIONS_RECORD.prev" ;;
    # 2. Shrinkage prints a negative delta, not a clamp.
    2) printf 'big-unit 300\n' > "$LASTRUN_RECORD"; printf 'big-unit 381\n' > "$DURATIONS_RECORD.prev" ;;
    # 3. The pole unit is new: the prior record exists but does not name it.
    3) printf 'newunit 50\n' > "$LASTRUN_RECORD"; printf 'other 999\n' > "$DURATIONS_RECORD.prev" ;;
    # 4. NO prior record at all -- the case the first build got wrong.
    4) printf 'newunit 50\n' > "$LASTRUN_RECORD" ;;
    # 5. This run published no durations.
    5) : > "$LASTRUN_RECORD" ;;
    # 6. Stop-early and 7. the content-key skip: a stale record on disk must not be read as this run's.
    6) printf 'big-unit 467\n' > "$LASTRUN_RECORD"; SUITE_STOPPED_EARLY=1 ;;
    7) printf 'big-unit 467\n' > "$LASTRUN_RECORD"; SUITE_SKIPPED=1 ;;
  esac
}
arm_want() { # the exact line, whole, never a substring: a substring of the no-pole text is inside every malformed variant of it.
  case "$1" in
    1) printf '%s' "   pole big-unit 467s loaded (was 381s before this run, +86s)" ;;
    2) printf '%s' "   pole big-unit 300s loaded (was 381s before this run, -81s)" ;;
    3|4) printf '%s' "   pole newunit 50s loaded (no prior figure for it)" ;;
    5|6|7) printf '%s' "   (no suite run, no pole)" ;;
  esac
}
expect() { # <label> <arm n> -- the line, whole, for arm n against the extracted function
  local got; arm_setup "$2"; got="$(run_case "$T/fn.sh")"
  if [ "$got" = "$(arm_want "$2")" ]; then ok "$1"; else bad "$1 -- wanted [$(arm_want "$2")], got [$got]"; fi
}
# 8. Information, never a verdict: the step returns 0 on every state. Prints the states on which it did not.
arm8_nz() { # <fn-file>
  local st nz=""
  SUITE_STOPPED_EARLY=0; SUITE_SKIPPED=0; rm -f "$DURATIONS_RECORD.prev"
  for st in grow none stop; do
    case "$st" in
      grow) printf 'u 9\n' > "$LASTRUN_RECORD"; printf 'u 1\n' > "$DURATIONS_RECORD.prev" ;;
      none) : > "$LASTRUN_RECORD" ;;
      stop) printf 'u 9\n' > "$LASTRUN_RECORD"; SUITE_STOPPED_EARLY=1 ;;
    esac
    ( . "$1"; pole_info_step >/dev/null ) || nz="$nz $st"
    SUITE_STOPPED_EARLY=0
  done
  printf '%s' "$nz"
}

expect "1 prior figure, growth" 1
expect "2 prior figure, shrinkage" 2
expect "3 unit absent from the prior record" 3
# Arm 4 is the deciding arm of m1, so it sets the same-run base-pass flag in its passing branch.
arm_setup 4
got4="$(run_case "$T/fn.sh")"
if [ "$got4" = "$(arm_want 4)" ]; then ok "4 no prior record file"; B_arm4=1
else bad "4 no prior record file -- wanted [$(arm_want 4)], got [$got4]"; fi
expect "5 empty durations" 5
expect "6 stop-early with a stale record on disk" 6
expect "7 content-key skip with a stale record on disk" 7
nz="$(arm8_nz "$T/fn.sh")"
if [ -z "$nz" ]; then ok "8 returns 0 on growth, on no run and on stop-early"; else bad "8 returned non-zero on:$nz"; fi

# mx_cell_red <mutant> <arm> -> 0 when the arm FAILS on the mutant's function file (RED), 1 when it holds (GREEN).
mx_cell_red() {
  local f="$T/$1.sh" got
  case "$2" in
    arm8) got="$(arm8_nz "$f" 2>&1)"; mx_chk "$got"; [ -n "$got" ] ;;
    arm[1-7]) arm_setup "${2#arm}"; got="$(run_case "$f" 2>&1)"; mx_chk "$got"; [ "$got" != "$(arm_want "${2#arm}")" ] ;;
    *) MX_BROKEN=1; return 0 ;;
  esac
}

# m1 -- THE FIRST BUILD'S CONDITION RESTORED. Arm 4 must flag it; arm 3 (prior file present) must not,
# which proves the mutant differs from the subject ONLY on the absent-file input.
sed 's/FILENAME == ARGV\[1\] {/NR == FNR {/' "$T/fn.sh" > "$T/m1.sh"
if cmp -s "$T/fn.sh" "$T/m1.sh"; then
  bad "m1 -- the mutation did not apply; the anchor 'FILENAME == ARGV[1]' moved"
else
  mx_eval m1 arm1 arm2 arm3 arm4 arm5 arm6 arm7 arm8
  if [ -n "$MX_DEC_GREEN" ]; then
    bad "m1 NR==FNR restored SURVIVED -- arm 4 does not discriminate it (green on:$MX_DEC_GREEN)"
  else
    mutant_killed "${B_arm4:-0}" m1 "m1 NR==FNR restored -- scored by arm 4 and not by its twin arm 3"
  fi
fi

# RULE 9: a plain run executes NO matrix-only cell. The deciding and twin cells write the same ledger, so
# an empty matrix count cannot come from a ledger nothing writes.
mx_only="$(mx_count mx)"; mx_ctl="$(mx_count dec)"
if [ "$MODE" = plain ]; then
  if [ "$mx_ctl" -eq 0 ]; then
    bad "rule-9 the matrix ledger control is EMPTY: no deciding or twin cell wrote to it, so a zero count of matrix-only cells means nothing"
  elif [ "$mx_only" -ne 0 ]; then
    bad "rule-9 a plain run executed $mx_only matrix-only cell(s) -- the --matrix measurement leaked into the per-push run"
  else
    ok "rule-9 a plain run executed no matrix-only cell, while $mx_ctl deciding or twin cell(s) wrote the same ledger"
  fi
else
  echo "MATRIX-SUMMARY $mx_only matrix-only cell(s) ran"
fi

[ "$rc" -eq 0 ] && echo "PASS  suite-pole-info -- 8 arms, 1 mutant scored"
exit "$rc"
