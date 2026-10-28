#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# pregate-self-check -- assert scripts/pregate-self-check.sh derives its above-pool steps from the hook's
# own prefix, and that each of its guards fires.
#
# Usage: run.sh        (from the repo root, as the pre-push pool runs it)
# Exit:  0 = every assertion holds, 1 = the self-check regressed, 2 = fixture broken.
#
# THE WORLDS ARE SYNTHETIC, ALWAYS. receipt-bl643.sh seeds mini hooks of one to three trivial steps plus
# the cut marker (roots A, B, C, D and the refusals noparse, nostep, noverdict) and drives the self-check
# under AI_DLC_PREGATE_ROOT. This run.sh never drives the real .githooks/pre-push prefix: its 20 steps
# cost about a minute, and "today's real hook passes" is the self-check's own job, not this fixture's.
#
# a1  control: the unmutated self-check -> A=0 B=1 C=2 noparse=2 nostep=2 noverdict=2 D=2 Dran=no
#     Dnamed=yes, exit 0 (positive conjunct: that exact line must APPEAR, so a subject that prints nothing
#     fails it)
# m1  mutant: the verdict-count == declared-steps equality removed. noverdict then exits 1 (a dying step
#     reads as one red step), every other world is unchanged, and the receipt exits 1.
# m2  mutant: an unbound-variable reference inserted after the cut, before the prefix runs -- an early
#     death by a route other than NUL. Without the EXIT trap's done_ guard that death exits 1 (A reads as a
#     finding) or 0; with it every world exits 2, and A's output names the trap's message AND the unbound
#     variable, so the refusal is the guard's and for the inserted reason.
#
# THE MUTANT MATRIX. A cell is one property of a mutated receipt run, RED when the mutant changed it from
# the unmutated verdict (exit1: the receipt exit is 1; m1-moved: only noverdict moved, to 1; m2-refused:
# every world refused with exit 2; m2-names: world A names the early-death refusal and the unbound
# variable; differs: the output no longer equals the control's). A mutant's row lists the cells that kill
# it (decides) and the cells it could plausibly co-trip but must leave GREEN (twins). A plain run scores
# each mutant on its deciding cells and checks its twins on the SAME captured output, which costs no
# receipt run. Each mutant's twins are the other mutant's own cells: the two mutations sit on different
# lines of the self-check, so a kill that leaked across them would show there.
# The matrix is re-measured whenever an arm or a mutant is added or changed, by the REMEASURE command
# below, run from the repo root. It scores every mutant against every cell and prints one MATRIX line each.
# MUTANT-MATRIX m1 decides=exit1,m1-moved,differs twins=m2-refused,m2-names
# MUTANT-MATRIX m2 decides=exit1,m2-refused,m2-names,differs twins=m1-moved
# MUTANT-MATRIX-REMEASURE bash core/fixtures/pregate-self-check/run.sh --matrix
set -uo pipefail

# MODE is "matrix" only under the positional `--matrix`; an AI_DLC_* name would be scrubbed by the suite.
# Anything else as an argument is a usage error, never a silent plain run.
MODE=plain
case "${1:-}" in
  "") ;;
  --matrix) MODE=matrix ;;
  *) echo "pregate-self-check: usage: run.sh [--matrix]" >&2; exit 2 ;;
esac

HERE="$(cd "$(dirname "$0")" && pwd)"
SELF_FILE="$HERE/$(basename "$0")"
# BOTH LAYOUTS NAMED, never a single walk-up (I33c). This unit is .dist-only and only runs here.
REPO=""
for cand in "$HERE/../../.." "$HERE/../.."; do
  if [ -f "$cand/VERSION" ] && [ -f "$cand/scripts/pregate-self-check.sh" ]; then
    REPO="$(cd "$cand" && pwd)"; break
  fi
done
if [ -z "$REPO" ]; then
  echo "FIXTURE ERROR: could not locate the repo root (VERSION + scripts/pregate-self-check.sh) from $HERE" >&2
  exit 2
fi
SUBJECT="$REPO/scripts/pregate-self-check.sh"
RECEIPT="core/fixtures/pregate-self-check/receipt-bl643.sh"
[ -f "$REPO/$RECEIPT" ] || { echo "FIXTURE ERROR: missing $REPO/$RECEIPT" >&2; exit 2; }
[ -s "$REPO/core/fixtures/procsub-staged-refusal/procsub-spell.awk" ] || { echo "FIXTURE ERROR: missing procsub-spell.awk" >&2; exit 2; }
# Reached only when the -s test above read the grammar as present and non-empty.
echo "HERMETIC-CONSUMED core/fixtures/procsub-staged-refusal/procsub-spell.awk"
command -v git >/dev/null 2>&1 || { echo "FIXTURE ERROR: git not on PATH" >&2; exit 2; }
WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

fails=0
made=0
ok()  { printf '  ok    %s\n' "$1"; made=$((made+1)); }
bad() { printf '  FAIL  %s\n' "$1"; made=$((made+1)); fails=$((fails+1)); }
# 11 = a1: 2 notes, plus m1: 3 notes on either branch, plus m2: 1 anchor-uniqueness note and 4 notes on either
# branch (applied, or DID NOT APPLY; each mutant's branches are exclusive), plus the rule-9 arm: 1 note.
# The count is asserted on a plain run only; --matrix emits the same notes but no rule-9 `ok`.
EXPECTED_ASSERTIONS=11
# The shared mutant-kill helper: a kill is emitted only through mutant_killed, behind a same-run base-pass flag.
MUT_LIB="$(cd "$HERE/../lib" 2>/dev/null && pwd)/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$MUT_LIB"
WANT='A=0 B=1 C=2 noparse=2 nostep=2 noverdict=2 D=2 Dran=no Dnamed=yes'

cd "$REPO" || exit 2

# --- a1: the unmutated control ----------------------------------------------------------------
# The literal repo-relative path (not "$RECEIPT") is what lets validate-fixture-git-env.sh resolve the init site.
bash core/fixtures/pregate-self-check/receipt-bl643.sh "$SUBJECT" > "$WORK/a1.out" 2>&1; a1=$?
if [ "$a1" -eq 9 ]; then echo "FIXTURE BROKEN: the receipt could not build its worlds" >&2; sed 's/^/     /' "$WORK/a1.out" >&2; exit 2; fi
# THE THREE SENTINELS BELOW ARE KEYED ON THE RECEIPT'S OUTPUT, NOT ON ITS EXIT CODE. A sentinel attests a
# read that happened. The receipt prints its `A=...` summary line (its :86) only after it has tested (-s,
# its :17) and copied (cp, its :24-25) the probe and the self-check into its SELF tree and driven that copy
# of the self-check in every world (its :55-58, :68). An exit code alone cannot attest that: a1 may be one
# the receipt never wrote -- 126/127 when bash cannot run the file, 128+n when a signal kills it, 2 when a
# syntax error stops it before its first line runs -- and any of those passes an a1 != 9 test. `grep -q` on
# the file, never fed from a pipe. Its own `A| ` echo of world A (its :85) cannot match `^A=`.
if [ "$a1" -ne 9 ] && grep -q '^A=' "$WORK/a1.out"; then
  echo "HERMETIC-CONSUMED core/fixtures/procsub-staged-refusal/procsub-spell-probe.diff"
  echo "HERMETIC-CONSUMED scripts/pregate-self-check.sh"
  echo "HERMETIC-CONSUMED $RECEIPT"
fi
if [ "$a1" -eq 0 ]; then ok "a1 control: receipt exit 0 on the unmutated self-check"; B_a1_exit=1; else bad "a1 control: receipt exit $a1, expected 0"; fi
if grep -qxF "$WANT" "$WORK/a1.out"; then ok "a1 control: the line '$WANT' is present"; B_a1_line=1; else bad "a1 control: the line '$WANT' is absent (got: $(tail -1 "$WORK/a1.out"))"; fi

# --- the matrix cells, single-sourced ---------------------------------------------------------
# A cell is RED on a mutant's captured output when it reads as changed from the unmutated verdict. Both the
# kills below, the per-push twin check and the --matrix score read these predicates, so they cannot drift.
# Returns 0 RED, 1 GREEN, 2 UNKNOWN CELL (an unknown name must never read as GREEN).
M1_WANT='A=0 B=1 C=2 noparse=2 nostep=2 noverdict=1 D=2 Dran=no Dnamed=yes'
M2_WANT='A=2 B=2 C=2 noparse=2 nostep=2 noverdict=2 D=2 Dran=no Dnamed=yes'
MX_CELLS='exit1 m1-moved m2-refused m2-names differs'
cell_red() { # cell_red <cell> <mutant>: the mutant's output and receipt exit are in $WORK/<mutant>.out and .rc
  local c="$1" m="$2" rc
  rc="$(cat "$WORK/$m.rc")" || return 2
  case "$c" in
    exit1)      [ "$rc" -eq 1 ] ;;
    m1-moved)   grep -qxF "$M1_WANT" "$WORK/$m.out" ;;
    m2-refused) grep -qxF "$M2_WANT" "$WORK/$m.out" ;;
    m2-names)   grep -qF 'A| pregate-self-check: the run died before its verdict' "$WORK/$m.out" \
                  && grep -qF 'ai_dlc_m2_unbound: unbound variable' "$WORK/$m.out" ;;
    differs)    ! grep -qxF "$WANT" "$WORK/$m.out" ;;
    *)          return 2 ;;
  esac
}
# The header IS the decides/twins list: nothing else in this file restates it.
mx_row() { # mx_row <mutant> <decides|twins>
  awk -v n="$1" -v f="$2" '
    $1 == "#" && $2 == "MUTANT-MATRIX" && $3 == n {
      c++; for (i = 4; i <= NF; i++) if (index($i, f "=") == 1) v = substr($i, length(f) + 2)
    }
    END { if (c == 1) print v }' "$SELF_FILE"
}
MXL="$WORK/mx.ledger"; : > "$MXL"
BROKEN=0
MX_FAILS=0
# mx_twins <mutant>: per-push, every twin must be GREEN on the SAME captured output, which costs no receipt run.
mx_twins() {
  local m="$1" tw t r
  tw="$(mx_row "$m" twins)"
  if [ -z "$tw" ]; then BROKEN=$((BROKEN + 1)); printf '  FIXTURE BROKEN %s: no single MUTANT-MATRIX row names its twins\n' "$m"; return; fi
  printf 'plain-twins %s\n' "$m" >> "$MXL"
  for t in $(printf '%s' "$tw" | tr ',' ' '); do
    cell_red "$t" "$m"; r=$?
    if [ "$r" -eq 2 ]; then BROKEN=$((BROKEN + 1)); printf '  FIXTURE BROKEN %s: twin %s names no cell\n' "$m" "$t"
    elif [ "$r" -eq 0 ]; then bad "$m mutant: its twin $t also fired on this mutant's output, so the kill is not confined to its own cell"; fi
  done
}
# mx_score <mutant>: MATRIX-ONLY. Scores the mutant against every cell. It records itself in the ledger first (rule 9).
mx_score() {
  local m="$1" dec tw c r uex="" dl="" tl="" g=0 tot=0 rc crash unb
  printf 'mx-score %s\n' "$m" >> "$MXL"
  dec="$(mx_row "$m" decides)"; tw="$(mx_row "$m" twins)"
  rc="$(cat "$WORK/$m.rc")"
  # A crashed arm prints no FAIL and would read as green. The m2 mutant's own inserted unbound variable is expected.
  crash="$(grep -E 'command not found|syntax error' "$WORK/$m.out")" || crash=""
  unb="$(grep 'unbound variable' "$WORK/$m.out" | grep -vF 'ai_dlc_m2_unbound')" || unb=""
  if { [ "$rc" != 0 ] && [ "$rc" != 1 ]; } || [ -n "$crash" ] || [ -n "$unb" ]; then
    BROKEN=$((BROKEN + 1)); printf 'MATRIX BROKEN %s\n' "$m"; return
  fi
  for c in $(printf '%s' "$dec" | tr ',' ' '); do
    cell_red "$c" "$m"; r=$?
    if [ "$r" -eq 0 ]; then dl="$dl,$c:RED"; else dl="$dl,$c:GREEN"; uex="$uex $c:GREEN"; fi
  done
  for c in $(printf '%s' "$tw" | tr ',' ' '); do
    cell_red "$c" "$m"; r=$?
    if [ "$r" -eq 0 ]; then tl="$tl,$c:RED"; uex="$uex $c:RED"; else tl="$tl,$c:GREEN"; fi
  done
  for c in $MX_CELLS; do
    case ",$dec,$tw," in *",$c,"*) continue ;; esac
    tot=$((tot + 1)); cell_red "$c" "$m" || g=$((g + 1))
  done
  if [ -n "$uex" ]; then
    printf 'MATRIX %s decides=%s twins=%s others=%d/%d UNEXPECTED=%s\n' "$m" "${dl#,}" "${tl#,}" "$g" "$tot" "$(printf '%s' "${uex# }" | tr ' ' ',')"
    MX_FAILS=$((MX_FAILS + 1))
  else
    printf 'MATRIX %s decides=%s twins=%s others=%d/%d\n' "$m" "${dl#,}" "${tl#,}" "$g" "$tot"
  fi
}
# mx_matrix_only <mutant>: the single gate on the matrix-only cell.
mx_matrix_only() { if [ "$MODE" = matrix ]; then mx_score "$1"; fi; }

# --- m1: the verdict-count equality removed ---------------------------------------------------
MUT="$WORK/m1-pregate-self-check.sh"
sed 's/^if \[ "\$nv" -ne "\$ns" \]; then$/if false; then/' "$SUBJECT" > "$MUT" 2>/dev/null
if [ -s "$MUT" ] && ! cmp -s "$SUBJECT" "$MUT"; then
  bash "$RECEIPT" "$MUT" > "$WORK/m1.out" 2>&1; echo $? > "$WORK/m1.rc"; m1="$(cat "$WORK/m1.rc")"
  if cell_red exit1 m1; then mutant_killed "$(( ${B_a1_exit:-0} && ${B_a1_line:-0} ))" m1 "m1 mutant: receipt exit 1 (killed)"; else bad "m1 mutant SURVIVED: receipt exit $m1, expected 1"; fi
  if cell_red m1-moved m1; then mutant_killed "$(( ${B_a1_exit:-0} && ${B_a1_line:-0} ))" m1 "m1 mutant: only noverdict moved, to 1"; else bad "m1 mutant SURVIVED: expected the line '$M1_WANT' (got: $(tail -1 "$WORK/m1.out"))"; fi
  if cell_red differs m1; then mutant_killed "$(( ${B_a1_exit:-0} && ${B_a1_line:-0} ))" m1 "m1 mutant: output differs from the control"; else bad "m1 mutant SURVIVED: output equals the control"; fi
  mx_twins m1
  mx_matrix_only m1
else
  bad "m1 mutant: DID NOT APPLY (the equality line was not found, or sed died)"
  bad "m1 mutant: DID NOT APPLY (no kill line to check)"
  bad "m1 mutant: DID NOT APPLY (no differential)"
  BROKEN=$((BROKEN + 1))
fi

# --- m2: an early death after the cut, by a route other than NUL --------------------------------
M2_ANCHOR='bash "$W/prefix.sh" < /dev/null > "$W/a.out" 2>&1'
n_anchor="$(grep -cxF "$M2_ANCHOR" "$SUBJECT")" || n_anchor=0
if [ "$n_anchor" -eq 1 ]; then ok "m2 mutant: the anchor line occurs exactly once in the subject"; B_m2_anchor=1
else bad "m2 mutant: the anchor line occurs $n_anchor times in the subject, expected exactly 1"; fi
MUT2="$WORK/m2-pregate-self-check.sh"
sed 's/^bash "\$W\/prefix\.sh" < \/dev\/null > "\$W\/a\.out" 2>&1$/: "$ai_dlc_m2_unbound"; &/' "$SUBJECT" > "$MUT2" 2>/dev/null
if [ "$n_anchor" -eq 1 ] && [ -s "$MUT2" ] && ! cmp -s "$SUBJECT" "$MUT2"; then
  bash "$RECEIPT" "$MUT2" > "$WORK/m2.out" 2>&1; echo $? > "$WORK/m2.rc"; m2="$(cat "$WORK/m2.rc")"
  M2_FLAG="$(( ${B_a1_exit:-0} && ${B_a1_line:-0} && ${B_m2_anchor:-0} ))"
  if cell_red exit1 m2; then mutant_killed "$M2_FLAG" m2 "m2 mutant: receipt exit 1 (killed)"; else bad "m2 mutant SURVIVED: receipt exit $m2, expected 1"; fi
  if cell_red m2-refused m2; then mutant_killed "$M2_FLAG" m2 "m2 mutant: every world refused with exit 2"; else bad "m2 mutant SURVIVED: expected the line '$M2_WANT' (got: $(tail -1 "$WORK/m2.out"))"; fi
  if cell_red m2-names m2; then mutant_killed "$M2_FLAG" m2 "m2 mutant: world A names the early-death refusal and the unbound variable"; else bad "m2 mutant SURVIVED: world A's output lacks the early-death refusal or the unbound variable"; fi
  if cell_red differs m2; then mutant_killed "$M2_FLAG" m2 "m2 mutant: output differs from the control"; else bad "m2 mutant SURVIVED: output equals the control"; fi
  mx_twins m2
  mx_matrix_only m2
else
  bad "m2 mutant: DID NOT APPLY (the anchor was not unique, or sed died)"
  bad "m2 mutant: DID NOT APPLY (no kill line to check)"
  bad "m2 mutant: DID NOT APPLY (no refusal message to check)"
  bad "m2 mutant: DID NOT APPLY (no differential)"
  BROKEN=$((BROKEN + 1))
fi

# --- RULE 9: a plain run executes NO matrix-only cell ------------------------------------------
# Every matrix-only score appends `mx-score` to the ledger before anything else; the per-push twin check
# appends `plain-twins` to the SAME ledger. The CONTROL is that second line: it must be present, so a zero
# count of matrix-only cells cannot come from a ledger nothing writes.
mx_only="$(grep -c '^mx-score ' "$MXL")" || mx_only=0
mx_ctl="$(grep -c '^plain-twins ' "$MXL")" || mx_ctl=0
if [ "$MODE" = plain ]; then
  if [ "$mx_ctl" -eq 0 ]; then bad "rule-9: the matrix ledger control is EMPTY, so a zero count of matrix-only cells would mean nothing"
  elif [ "$mx_only" -ne 0 ]; then bad "rule-9: a plain run executed $mx_only matrix-only cell(s), so the --matrix measurement leaked into the per-push run"
  else ok "rule-9: a plain run executed no matrix-only cell, while its $mx_ctl per-push twin check(s) wrote to the same ledger"; fi
else
  # The header is bound to the measured set both ways: one MUTANT-MATRIX row per mutant, one mutant per row.
  mx_hdr="$(awk '$1 == "#" && $2 == "MUTANT-MATRIX" { print $3 }' "$SELF_FILE" | LC_ALL=C sort | tr '\n' ' ')"
  [ "$mx_hdr" = "m1 m2 " ] || { BROKEN=$((BROKEN + 1)); echo "MATRIX BROKEN: the header rows are [$mx_hdr], expected [m1 m2 ]"; }
  echo "MATRIX-SUMMARY $mx_only matrix-only cell(s) ran, $mx_ctl per-push twin check(s)"
  [ "$MX_FAILS" -eq 0 ] || fails=$((fails + MX_FAILS))
fi

# --- a closing tally derived from the notes actually emitted ----------------------------------
if [ "$BROKEN" -ne 0 ]; then
  echo "FIXTURE BROKEN: $BROKEN mutant arm(s) could not be built or scored, so those assertions tested nothing" >&2
  exit 2
fi
if [ "$MODE" = plain ] && [ "$made" -ne "$EXPECTED_ASSERTIONS" ]; then
  echo "FIXTURE BROKEN: $made assertion(s) ran, expected $EXPECTED_ASSERTIONS -- an arm never executed" >&2
  exit 1
fi
if [ "$fails" -ne 0 ]; then
  echo "pregate-self-check: $fails FAILED of $made"
  exit 1
fi
echo "pregate-self-check: PASS ($made assertions)"
exit 0
