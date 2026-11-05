#!/usr/bin/env bash
# receipt-bl924.sh [<run.sh>] -- the BL-924 receipt: prepush-pool-depth decides its cells on states its subjects
# write, never on a settled process-table sample, under the two schedules BL-924 names, FORCED rather than waited for.
#
# It builds ONE scratch copy of <run.sh> (default: the run.sh beside this file) with core/fixtures/lib/ and the first
# pre-push hook this tree carries, edits the copy, runs it once, and reads the values it prints:
#
#   (a) THE LATE FLIGHT FILE. Stub fx6, in a barrier drive, writes its flight file only once the barrier poller has
#       either COUNTED (barrier.n) or REJECTED a settle that came after fx6 arrived (a new barrier.rej line). It waits
#       in `read -t 1` on a private FIFO, a builtin wait in state S, so the drive's tree settles with six workers
#       forked and five flight files. The fixed poller rejects that settle and reads 6 of 6; a poller that counts the
#       settled flight dir reads 5.
#   (b) THE LATE WRITER. The first step of the fix_hlink, fix_fifo and fix_silent watcher drives (the unit's byte, or
#       its FIFO-step) waits the same way until the fixture has RECORDED that drive (pf.<tag>.at) or REJECTED a settle
#       of it (a new "<tag> " line in pn.rej). A fixture that records a drive at a settle and releases it reads
#       pn_hlink=ok, pn_silent=ok, pn_fifo=none; the fixed one reads REFUSED for all three.
#
# The copy keeps one pool mutant (not-exported) and no watcher mutant, and ends just after the watcher cells with its
# values printed. Every cell prints `CELL <name> PASS|FAIL <detail>`:
#
#   barrier        the depth-0 barrier's count, B0, is 6
#   not-exported   `MUTANT not-exported kill confirmed`: its depth-0 drive is forced (fx6 held), so a mutant scored
#                  on a cell it cannot move, obs_d0_max, fails here
#   pn_hlink, pn_fifo, pn_silent   the fix set's value is REFUSED
#
# cap-ignored and pool-capped-5 are left out. cap-ignored reads the same before and after the fix. pool-capped-5's
# drive is one the forcing does not reach: fx6 is forked only after the count, so the copy re-runs the fixture's arm.
#
# Exit 0 when every cell passes, 1 when one fails, 9 when it cannot measure: no root, no subject, an anchor not found
# exactly once, a copy that did not run to its value line, the copy's baseline missing, or a forcing that provably did
# not fire (fx6 never reached the injected wait in the baseline barrier drive, or a forced watcher step never waited).
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

refuse() { echo "receipt-bl924: $1" >&2; exit 9; }
HERE="$(cd "$(dirname "$0")" && pwd)"
root=""; d="$HERE"
while [ -n "$d" ] && [ "$d" != "/" ]; do
  if [ -f "$d/core/fixtures/lib/mutant.sh" ] && { [ -f "$d/.githooks/pre-push" ] || [ -f "$d/core/git-hooks/pre-push" ]; }; then root="$d"; break; fi
  d="$(dirname "$d")"
done
[ -n "$root" ] || refuse "cannot locate the repo root from $HERE"
SUBJ="${1:-$HERE/run.sh}"
[ -f "$SUBJ" ] || refuse "no subject $SUBJ"
HOOK=""
for h in .githooks/pre-push core/git-hooks/pre-push; do [ -f "$root/$h" ] && { HOOK="$h"; break; }; done

C="$(mktemp -d "${TMPDIR:-/tmp}/rcpt-bl924.XXXXXX")" || refuse "mktemp failed"
trap 'case "$C" in */rcpt-bl924.??????) rm -rf -- "$C" ;; esac' EXIT
F="$C/core/fixtures/prepush-pool-depth"
mkdir -p "$F" "$C/${HOOK%/*}" "$C/forced" || refuse "could not build the copy"
cp -R "$root/core/fixtures/lib" "$C/core/fixtures/lib" && cp "$root/$HOOK" "$C/$HOOK" || refuse "could not copy lib/ or $HOOK"
git -C "$C" init -q . >/dev/null 2>&1 || refuse "git init failed in the copy"

# every anchor exactly once in the subject, or the edit below would land nowhere or twice
once() { # once <label> <fixed string>
  local n; n="$(grep -cxF -- "$2" "$SUBJ")" || n=0
  [ "$n" = 1 ] || refuse "anchor '$1' found $n times in $SUBJ, want exactly 1"
}
A_FLIGHT=': > "$PD_FLIGHT/$$"'
A_STEP='  [ -z "$1" ] || printf x >> "$1"'
A_EVAL='for _m in $PN_MUTS; do pn_eval "$_m"; done'
once flight "$A_FLIGHT"; once step "$A_STEP"; once pn_eval "$A_EVAL"
[ "$(grep -c '^PN_MUTS="' "$SUBJ")" = 1 ] || refuse "anchor 'PN_MUTS=' not found exactly once in $SUBJ"
[ "$(grep -c '^\[ -n "\$_ti" \] ||' "$SUBJ")" = 1 ] || refuse "anchor 'SIGINT guard' not found exactly once in $SUBJ"
[ "$(grep -c '^  mutant not-exported ' "$SUBJ")" = 1 ] || refuse "anchor 'mutant not-exported' not found exactly once in $SUBJ"

# THE EDIT, one awk pass. The SIGINT guard protects only cells after the cut, so the copy drops it: a receipt run from
# a backgrounded caller must not refuse for a cell it never drives.
awk -v aflight="$A_FLIGHT" -v astep="$A_STEP" -v aeval="$A_EVAL" '
  /^\[ -n "\$_ti" \] \|\|/ { print ":"; next }
  /^  mutant [a-z]/ { if ($2 != "not-exported") next }
  /^PN_MUTS="/ { print "PN_MUTS=\"\""; next }
  $0 == aflight {
    print "case \"$0\" in */fx6/run.sh|*/fx6//run.sh) if [ -n \"${PD_GATE:-}\" ] && [ -n \"${BL924_FORCE:-}\" ]; then pw=\"${PD_FLIGHT%/flight}\"; [ -p \"$pw/force.fifo\" ] || mkfifo \"$pw/force.fifo\""
    print "  r0=0; if [ -f \"$pw/barrier.rej\" ]; then while read -r _; do r0=$((r0 + 1)); done < \"$pw/barrier.rej\"; fi; fw=0; fb=\"\""
    print "  while :; do [ -p \"$pw/force.fifo\" ] || break; [ -e \"$pw/barrier.n\" ] && { fb=n; break; }; r1=0; if [ -f \"$pw/barrier.rej\" ]; then while read -r _; do r1=$((r1 + 1)); done < \"$pw/barrier.rej\"; fi; [ \"$r1\" -gt \"$r0\" ] && { fb=rej; break; }; fw=$((fw + 1)); read -t 1 _ <> \"$pw/force.fifo\"; done"
    print "  printf \"raw=%s waits=%s by=%s\\n\" \"${raw:-_}\" \"$fw\" \"$fb\" >> \"$BL924_FORCE/barrier.log\"; fi ;; esac"
    print; next }
  $0 == astep {
    print
    print "  pf_t=\"${PN_DIR##*/pn.}\"; pf_w=\"${PN_DIR%/*}\""
    print "  case \"$pf_t\" in fix_hlink|fix_fifo|fix_silent) if [ -n \"${BL924_FORCE:-}\" ] && [ ! -e \"$PN_DIR/forced.done\" ]; then : > \"$PN_DIR/forced.done\"; [ -p \"$PN_DIR/force.fifo\" ] || mkfifo \"$PN_DIR/force.fifo\""
    print "    pf_c() { pf_n=0; if [ -f \"$pf_w/pn.rej\" ]; then while read -r pf_l pf_r; do [ \"$pf_l\" = \"$pf_t\" ] && pf_n=$((pf_n + 1)); done < \"$pf_w/pn.rej\"; fi; }"
    print "    pf_c; pf_r0=$pf_n; pf_fw=0; pf_b=\"\""
    print "    while :; do [ -p \"$PN_DIR/force.fifo\" ] || break; [ -e \"$pf_w/pf.$pf_t.at\" ] && { pf_b=at; break; }; pf_c; [ \"$pf_n\" -gt \"$pf_r0\" ] && { pf_b=rej; break; }; pf_fw=$((pf_fw + 1)); read -t 1 _ <> \"$PN_DIR/force.fifo\"; done"
    print "    printf \"%s waits=%s by=%s\\n\" \"$pf_t\" \"$pf_fw\" \"$pf_b\" >> \"$BL924_FORCE/step.log\"; fi ;; esac"
    next }
  $0 == aeval {
    print
    print "printf \"RCPT B0=%s\\n\" \"${B0:-_}\""
    print "for _c in pn_hlink pn_fifo pn_silent; do printf \"RCPT %s=%s\\n\" \"$_c\" \"$(pn_val fix \"$_c\")\"; done"
    print "printf \"RCPT END fails=%s asserts=%s\\n\" \"$fails\" \"$asserts\""
    print "exit 0"; cut = 1; exit }
  { print }
  END { if (!cut) exit 3 }
' "$SUBJ" > "$F/run.sh" || refuse "the edit did not reach the pn_eval anchor"
[ "$(grep -c '^  mutant [a-z]' "$F/run.sh")" = 1 ] || refuse "the copy keeps $(grep -c '^  mutant [a-z]' "$F/run.sh") pool mutants, want 1"
[ "$(grep -c 'BL924_FORCE' "$F/run.sh")" -ge 2 ] || refuse "the forcing edits did not land in the copy"
bash -n "$F/run.sh" || refuse "the edited copy does not parse"

# THE RUN, from the copy's root, as the hook runs a fixture
OUT="$C/out"
( cd "$C" && BL924_FORCE="$C/forced" bash "$F/run.sh" ) > "$OUT" 2>&1; rc=$?
grep -q '^RCPT END ' "$OUT" || refuse "the copy exited $rc before its value line: $(grep -m1 'FIXTURE\|BROKEN' "$OUT")"
grep -q '^  ok    \[[^]]*\] the probe emitted every arm' "$OUT" || refuse "the copy's baseline did not emit every arm, so no cell below means anything"

# THE FORCINGS FIRED. (a) The baseline barrier drive is the first drive whose workers receive depth 1 (raw=1): the
# depth-1 drives before it hand their workers 2. Its fx6 line must exist. (b) Each forced watcher step waited at least
# once, so it was held across a point where the fixture had neither recorded nor rejected that drive.
BL="$(grep -m1 '^raw=1 ' "$C/forced/barrier.log" 2>/dev/null)"
[ -n "$BL" ] || refuse "forcing (a) never fired: fx6 did not reach the injected wait in the baseline barrier drive"
for t in fix_hlink fix_fifo fix_silent; do
  SL="$(grep -m1 "^$t " "$C/forced/step.log" 2>/dev/null)"
  [ -n "$SL" ] || refuse "forcing (b) never fired for $t: its first step did not reach the injected wait"
  case "$SL" in *" waits=0 "*) refuse "forcing (b) did not hold $t: its first step waited 0 times ($SL)" ;; esac
done
echo "FORCED barrier: $BL"
sed 's/^/FORCED step: /' "$C/forced/step.log"

fails=0
cell() { # cell <name> <0 pass|1 fail> <detail>
  if [ "$2" = 0 ]; then echo "CELL $1 PASS $3"; else echo "CELL $1 FAIL $3"; fails=$((fails + 1)); fi
}
val() { awk -v k="RCPT $1=" 'index($0, k) == 1 { print substr($0, length(k) + 1); exit }' "$OUT"; }
B0="$(val B0)"
cell barrier "$([ "$B0" = 6 ] && echo 0 || echo 1)" "depth-0 barrier read $B0 of 6 (fx6: $BL)"
L="$(grep -m1 "MUTANT not-exported " "$OUT" | sed 's/^ *//')"
cell not-exported "$(grep -q "MUTANT not-exported kill confirmed" "$OUT" && echo 0 || echo 1)" "${L:-no line for MUTANT not-exported}"
for c in pn_hlink pn_fifo pn_silent; do
  v="$(val "$c")"
  cell "$c" "$([ "$v" = REFUSED ] && echo 0 || echo 1)" "read ${v:-_}, want REFUSED"
done
[ "$fails" = 0 ] || exit 1
exit 0
