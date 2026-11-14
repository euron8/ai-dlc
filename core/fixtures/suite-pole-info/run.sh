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
# THE MUTANT MATRIX. m2 reads this run's figures from the shared `.last` file and m3 the prior figures
# from the shared `.prev` file, the two reads the concurrency fix removed. Each is scored per push on its
# DECIDING arm (arm9) and its named TWIN (arm1), which seeds the files with this run's own figures and
# must stay GREEN under it. `run.sh --matrix` scores each against all nine arms and prints one MATRIX
# line. The matrix is re-measured as .claude/rules/fixture-mutants.md clause 2 ("One run per distinct
# state") requires. Run the REMEASURE command below, from the repo root.
# MUTANT-MATRIX-DYNAMIC mut_pole why=mut_pole passes its first argument to mutant_killed; every mut_pole call names a literal mutant that carries its own row in this block
# MUTANT-MATRIX m2 decides=arm9 twins=arm1
# MUTANT-MATRIX m3 decides=arm9 twins=arm1
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
SUITE_SKIPPED=0; export SUITE_SKIPPED
LASTRUN_OWN=""; POLE_PREV=""

# own <last> <prev|-> -- this run's figures, and the shared files holding the SAME figures (no concurrent push).
own() {
  LASTRUN_OWN="$1"; printf '%s' "$1" > "$LASTRUN_RECORD"
  if [ "$2" = - ]; then POLE_PREV=""; rm -f "$DURATIONS_RECORD.prev"
  else POLE_PREV="$2"; printf '%s\n' "$2" > "$DURATIONS_RECORD.prev"; fi
}
# arm_setup <n> -- the whole state arm n reads (arms 1-5, 7 and 9), set from scratch so any arm can run on any function file.
arm_setup() {
  SUITE_SKIPPED=0
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
  esac
}
arm_want() { # the exact line, whole, never a substring: a substring of the no-pole text is inside every malformed variant of it.
  case "$1" in
    1|9) printf '%s' "   pole big-unit 467s loaded (was 381s before this run, +86s)" ;;
    2) printf '%s' "   pole big-unit 300s loaded (was 381s before this run, -81s)" ;;
    3|4) printf '%s' "   pole newunit 50s loaded (no prior figure for it)" ;;
    5|7) printf '%s' "   (no suite run, no pole)" ;;
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
  for st in grow none; do
    case "$st" in
      grow) own 'u 9' 'u 1' ;;
      none) own '' - ;;
    esac
    ( . "$1"; pole_info_step >/dev/null ) || nz="$nz $st"
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
expect "7 content-key skip with a stale record on disk" 7
nz="$(arm8_nz "$T/fn.sh")"
if [ -z "$nz" ]; then ok "8 returns 0 on growth and on no run"; else bad "8 returned non-zero on:$nz"; fi
# Arm 9 is the deciding arm of m2 and m3, so it sets the same-run base-pass flag in its passing branch.
arm_setup 9
got9="$(run_case "$T/fn.sh")"
if [ "$got9" = "$(arm_want 9)" ]; then ok "9 a concurrent push replaced both shared files: this run's own figures decide"; B_arm9=1
else bad "9 a concurrent push replaced both shared files -- wanted [$(arm_want 9)], got [$got9]"; fi

# mx_cell_red <mutant> <arm> -> 0 when the arm FAILS on the mutant's function file (RED), 1 when it holds (GREEN).
mx_cell_red() {
  local f="$T/$1.sh" got
  case "$2" in
    arm8) got="$(arm8_nz "$f" 2>&1)"; mx_chk "$got"; [ -n "$got" ] ;;
    arm[1-579]) arm_setup "${2#arm}"; got="$(run_case "$f" 2>&1)"; mx_chk "$got"; [ "$got" != "$(arm_want "${2#arm}")" ] ;;
    *) MX_BROKEN=1; return 0 ;;
  esac
}

# m2 -- THIS RUN'S FIGURES READ FROM THE SHARED `.last` FILE, and m3 -- THE PRIOR FIGURES READ FROM THE
# SHARED `.prev` FILE: each restores one of the two reads the concurrency fix removed. Arm 9 must flag each;
# arm 1, whose files hold this run's own figures, must not, which confines each mutant to the concurrent input.
mut_pole() { # <name> <old> <new> <message>
  awk -v o="$2" -v n="$3" '{ i = index($0, o); if (i) $0 = substr($0, 1, i - 1) n substr($0, i + length(o)); print }' "$T/fn.sh" > "$T/$1.sh"
  if cmp -s "$T/fn.sh" "$T/$1.sh"; then
    bad "$1 -- the mutation did not apply; the anchor '$2' moved"; return
  fi
  mx_eval "$1" arm1 arm2 arm3 arm4 arm5 arm7 arm8 arm9
  if [ -n "$MX_DEC_GREEN" ]; then
    bad "$1 SURVIVED -- arm 9 does not discriminate it (green on:$MX_DEC_GREEN)"
  else
    mutant_killed "${B_arm9:-0}" "$1" "$4"
  fi
}
mut_pole m2 'printf '"'"'%s\\n'"'"' "$LASTRUN_OWN" |' 'cat "$LASTRUN_RECORD" |' \
  "m2 this run's figures read from the shared .last file -- scored by arm 9 and not by its twin arm 1"
mut_pole m3 'PP="${POLE_PREV:-}"' 'PP="$(cat "$DURATIONS_RECORD.prev" 2>/dev/null)"' \
  "m3 the prior figures read from the shared .prev file -- scored by arm 9 and not by its twin arm 1"

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

[ "$rc" -eq 0 ] && echo "PASS  suite-pole-info -- 8 arms, 2 mutants scored"
exit "$rc"
