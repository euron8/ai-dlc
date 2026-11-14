#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
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
# m4  mutant (BL-1055): the pregate record's clean-and-unmoved condition replaced by `true`; the dirty world Wd then
#     records its tree (Wdrec=yes) and names nothing (Wdn=no). The control asserts A records (Arec=yes), B (a finding)
#     does not, and Wd does not and says why.
# m5  mutant (BL-1064): section d's clean-tree test made to match nothing; the clean world A then runs the fork-budget
#     fixture under the scratch store (Aseed=no) instead of through seed-verdict-store.sh into its hook's counted store.
# m6  mutant (BL-1082): the member mode's no-record exit disabled; the clean member world Mt then writes a pregate
#     record (Mtrec=yes) and does not say it wrote none (Mtn=no).
# m7  mutant (BL-1082): the member mode's switch to the tree's own hook deleted, so it runs the hook a push would run;
#     the member world Mr's red step after PRESUITE_DONE=1 then goes unseen (Mr=0, Mrn=no).
# m8  mutant (BL-1082): the --member clause dropped from the edited-hook refusal, the member mode's carrier; Htree's
#     refusal then no longer names it (Htreem=no).
# gc  control (BL-1055): the PREGATE_GATE span of .githooks/pre-push, cut and driven by the receipt's --gate mode
#     (deny, empty, allow, tree, dirty), plus one whole-hook drive (E2E) that must stop at the gate before any step.
# g1-g4 mutants of a copy of that hook, cut-only: g1 drops the record test, g2 the clean-tree test, g3 the
#     tree-equality test, g4 the empty-stdin exemption; each moves exactly its own cell.
#
# THE MUTANT MATRIX. A cell is one property of a mutated receipt run, RED when the mutant changed it from
# the unmutated verdict (exit1: the receipt exit is 1; m1-moved: only noverdict moved, to 1; m2-refused:
# every world refused with exit 2; m2-names: world A names the early-death refusal and the unbound
# variable; differs: the output no longer equals the control's). A mutant's row lists the cells that kill
# it (decides) and the cells it could plausibly co-trip but must leave GREEN (twins). A plain run scores
# each mutant on its deciding cells and checks its twins on the SAME captured output, which costs no
# receipt run. Each mutant's twins are the other mutant's own cells: the two mutations sit on different
# lines of the self-check, so a kill that leaked across them would show there.
# The matrix is re-measured as .claude/rules/fixture-mutants.md clause 2 ("One run per distinct state")
# requires. Run the REMEASURE command below, from the repo root. It scores every mutant against every cell
# and prints one MATRIX line each.
# MUTANT-MATRIX m1 decides=exit1,m1-moved,differs twins=m2-refused,m2-names,m3-moved,m4-moved,m5-moved,m6-moved,m7-moved,m8-moved
# MUTANT-MATRIX m2 decides=exit1,m2-refused,m2-names,differs twins=m1-moved,m3-moved,m4-moved,m5-moved,m6-moved,m7-moved,m8-moved
# MUTANT-MATRIX m3 decides=exit1,m3-moved,differs twins=m1-moved,m2-refused,m2-names,m4-moved,m5-moved,m6-moved,m7-moved,m8-moved
# MUTANT-MATRIX m4 decides=exit1,m4-moved,differs twins=m1-moved,m2-refused,m2-names,m3-moved,m5-moved,m6-moved,m7-moved,m8-moved
# MUTANT-MATRIX m5 decides=exit1,m5-moved,differs twins=m1-moved,m2-refused,m2-names,m3-moved,m4-moved,m6-moved,m7-moved,m8-moved
# MUTANT-MATRIX m6 decides=exit1,m6-moved,differs twins=m1-moved,m2-refused,m2-names,m3-moved,m4-moved,m5-moved,m7-moved,m8-moved
# MUTANT-MATRIX m7 decides=exit1,m7-moved,differs twins=m1-moved,m2-refused,m2-names,m3-moved,m4-moved,m5-moved,m6-moved,m8-moved
# MUTANT-MATRIX m8 decides=exit1,m8-moved,differs twins=m1-moved,m2-refused,m2-names,m3-moved,m4-moved,m5-moved,m6-moved,m7-moved
# MUTANT-MATRIX g1 decides=exit1,g1-moved,gdiffers twins=g2-moved,g3-moved,g4-moved
# MUTANT-MATRIX g2 decides=exit1,g2-moved,gdiffers twins=g1-moved,g3-moved,g4-moved
# MUTANT-MATRIX g3 decides=exit1,g3-moved,gdiffers twins=g1-moved,g2-moved,g4-moved
# MUTANT-MATRIX g4 decides=exit1,g4-moved,gdiffers twins=g1-moved,g2-moved,g3-moved
# Measured by the REMEASURE command below: m3 decides=exit1:RED,m3-moved:RED,differs:RED twins=m1-moved:GREEN,m2-refused:GREEN,m2-names:GREEN others=0/0.
# MUTANT-MATRIX-REMEASURE bash core/fixtures/pregate-self-check/run.sh --matrix
set -uo pipefail
# The env-derived scrub (H8): this fixture drives a hook, so no inherited AI_DLC_* tunable reaches it.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

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

# shellcheck source=/dev/null
. "$HERE/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }
# 53 = a1: 2 notes, m1: 3, m2: 1 anchor note and 4, m3: 1 anchor note and 3, m4-m8: 4 each on either branch, gc: 2,
# g1-g4: 4 each on either branch (applied, or DID NOT APPLY; each mutant's branches are exclusive), rule-9: 1 note.
# The count is asserted on a plain run only; --matrix emits the same notes but no rule-9 `ok`.
EXPECTED_ASSERTIONS=53
# The shared mutant-kill helper: a kill is emitted only through mutant_killed, behind a same-run base-pass flag.
MUT_LIB="$(cd "$HERE/../lib" 2>/dev/null && pwd)/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$MUT_LIB"
WANT='A=0 B=1 C=2 noparse=2 nostep=2 noverdict=2 D=2 Dran=no Dnamed=yes U=2 Unamed=yes J=1 Jnamed=yes Hcwd=0 Hres=2 Hresn=yes Htree=2 Htreen=yes Habs=2 Habsn=yes Hbehind=2 Hbehindn=yes Arec=yes Brec=no Wd=0 Wdrec=no Wdn=yes Aseed=yes Wdscr=yes Mt=0 Mtn=yes Mtrec=no Mr=1 Mrn=yes Htreem=yes'

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
  echo "HERMETIC-CONSUMED scripts/seed-verdict-store.sh"
  echo "HERMETIC-CONSUMED $RECEIPT"
fi
if [ "$a1" -eq 0 ]; then ok "a1 control: receipt exit 0 on the unmutated self-check"; B_a1_exit=1; else bad "a1 control: receipt exit $a1, expected 0"; fi
if grep -qxF "$WANT" "$WORK/a1.out"; then ok "a1 control: the line '$WANT' is present"; B_a1_line=1; else bad "a1 control: the line '$WANT' is absent (got: $(tail -1 "$WORK/a1.out"))"; fi

# --- the matrix cells, single-sourced ---------------------------------------------------------
# A cell is RED on a mutant's captured output when it reads as changed from the unmutated verdict. Both the
# kills below, the per-push twin check and the --matrix score read these predicates, so they cannot drift.
# Returns 0 RED, 1 GREEN, 2 UNKNOWN CELL (an unknown name must never read as GREEN).
M1_WANT='A=0 B=1 C=2 noparse=2 nostep=2 noverdict=1 D=2 Dran=no Dnamed=yes U=2 Unamed=yes J=1 Jnamed=yes Hcwd=0 Hres=2 Hresn=yes Htree=2 Htreen=yes Habs=2 Habsn=yes Hbehind=2 Hbehindn=yes Arec=yes Brec=no Wd=0 Wdrec=no Wdn=yes Aseed=yes Wdscr=yes Mt=0 Mtn=yes Mtrec=no Mr=1 Mrn=yes Htreem=yes'
M2_WANT='A=2 B=2 C=2 noparse=2 nostep=2 noverdict=2 D=2 Dran=no Dnamed=yes U=2 Unamed=no J=2 Jnamed=no Hcwd=2 Hres=2 Hresn=yes Htree=2 Htreen=yes Habs=2 Habsn=yes Hbehind=2 Hbehindn=yes Arec=no Brec=no Wd=2 Wdrec=no Wdn=no Aseed=no Wdscr=no Mt=2 Mtn=no Mtrec=no Mr=2 Mrn=no Htreem=yes'
M3_WANT='A=0 B=1 C=2 noparse=2 nostep=2 noverdict=2 D=2 Dran=no Dnamed=yes U=2 Unamed=yes J=1 Jnamed=yes Hcwd=0 Hres=0 Hresn=no Htree=0 Htreen=no Habs=0 Habsn=no Hbehind=0 Hbehindn=no Arec=yes Brec=no Wd=0 Wdrec=no Wdn=yes Aseed=yes Wdscr=yes Mt=0 Mtn=yes Mtrec=no Mr=1 Mrn=yes Htreem=no'
M4_WANT='A=0 B=1 C=2 noparse=2 nostep=2 noverdict=2 D=2 Dran=no Dnamed=yes U=2 Unamed=yes J=1 Jnamed=yes Hcwd=0 Hres=2 Hresn=yes Htree=2 Htreen=yes Habs=2 Habsn=yes Hbehind=2 Hbehindn=yes Arec=yes Brec=no Wd=0 Wdrec=yes Wdn=no Aseed=yes Wdscr=yes Mt=0 Mtn=yes Mtrec=no Mr=1 Mrn=yes Htreem=yes'
M5_WANT='A=0 B=1 C=2 noparse=2 nostep=2 noverdict=2 D=2 Dran=no Dnamed=yes U=2 Unamed=yes J=1 Jnamed=yes Hcwd=0 Hres=2 Hresn=yes Htree=2 Htreen=yes Habs=2 Habsn=yes Hbehind=2 Hbehindn=yes Arec=yes Brec=no Wd=0 Wdrec=no Wdn=yes Aseed=no Wdscr=yes Mt=0 Mtn=yes Mtrec=no Mr=1 Mrn=yes Htreem=yes'
M6_WANT='A=0 B=1 C=2 noparse=2 nostep=2 noverdict=2 D=2 Dran=no Dnamed=yes U=2 Unamed=yes J=1 Jnamed=yes Hcwd=0 Hres=2 Hresn=yes Htree=2 Htreen=yes Habs=2 Habsn=yes Hbehind=2 Hbehindn=yes Arec=yes Brec=no Wd=0 Wdrec=no Wdn=yes Aseed=yes Wdscr=yes Mt=0 Mtn=no Mtrec=yes Mr=1 Mrn=yes Htreem=yes'
M7_WANT='A=0 B=1 C=2 noparse=2 nostep=2 noverdict=2 D=2 Dran=no Dnamed=yes U=2 Unamed=yes J=1 Jnamed=yes Hcwd=0 Hres=2 Hresn=yes Htree=2 Htreen=yes Habs=2 Habsn=yes Hbehind=2 Hbehindn=yes Arec=yes Brec=no Wd=0 Wdrec=no Wdn=yes Aseed=yes Wdscr=yes Mt=0 Mtn=yes Mtrec=no Mr=0 Mrn=no Htreem=yes'
M8_WANT='A=0 B=1 C=2 noparse=2 nostep=2 noverdict=2 D=2 Dran=no Dnamed=yes U=2 Unamed=yes J=1 Jnamed=yes Hcwd=0 Hres=2 Hresn=yes Htree=2 Htreen=yes Habs=2 Habsn=yes Hbehind=2 Hbehindn=yes Arec=yes Brec=no Wd=0 Wdrec=no Wdn=yes Aseed=yes Wdscr=yes Mt=0 Mtn=yes Mtrec=no Mr=1 Mrn=yes Htreem=no'
GWANT='Gdeny=1 Gdenyn=yes Gempty=0 Gallow=0 Gtree=1 Gtreen=yes Gdirty=1 Gdirtyn=yes E2E=1 E2En=yes'
GCUT='Gdeny=1 Gdenyn=yes Gempty=0 Gallow=0 Gtree=1 Gtreen=yes Gdirty=1 Gdirtyn=yes E2E=skip E2En=skip'
G1_WANT='Gdeny=0 Gdenyn=no Gempty=0 Gallow=0 Gtree=1 Gtreen=yes Gdirty=1 Gdirtyn=yes E2E=skip E2En=skip'
G2_WANT='Gdeny=1 Gdenyn=yes Gempty=0 Gallow=0 Gtree=1 Gtreen=yes Gdirty=0 Gdirtyn=no E2E=skip E2En=skip'
G3_WANT='Gdeny=1 Gdenyn=yes Gempty=0 Gallow=0 Gtree=0 Gtreen=no Gdirty=1 Gdirtyn=yes E2E=skip E2En=skip'
G4_WANT='Gdeny=1 Gdenyn=yes Gempty=1 Gallow=0 Gtree=1 Gtreen=yes Gdirty=1 Gdirtyn=yes E2E=skip E2En=skip'
MX_CELLS='exit1 m1-moved m2-refused m2-names m3-moved m4-moved m5-moved m6-moved m7-moved m8-moved differs g1-moved g2-moved g3-moved g4-moved gdiffers'
cell_red() { # cell_red <cell> <mutant>: the mutant's output and receipt exit are in $WORK/<mutant>.out and .rc
  local c="$1" m="$2" rc
  rc="$(cat "$WORK/$m.rc")" || return 2
  case "$c" in
    exit1)      [ "$rc" -eq 1 ] ;;
    m1-moved)   grep -qxF "$M1_WANT" "$WORK/$m.out" ;;
    m2-refused) grep -qxF "$M2_WANT" "$WORK/$m.out" ;;
    m3-moved)   grep -qxF "$M3_WANT" "$WORK/$m.out" ;;
    m4-moved)   grep -qxF "$M4_WANT" "$WORK/$m.out" ;;
    m5-moved)   grep -qxF "$M5_WANT" "$WORK/$m.out" ;;
    m6-moved)   grep -qxF "$M6_WANT" "$WORK/$m.out" ;;
    m7-moved)   grep -qxF "$M7_WANT" "$WORK/$m.out" ;;
    m8-moved)   grep -qxF "$M8_WANT" "$WORK/$m.out" ;;
    g1-moved)   grep -qxF "$G1_WANT" "$WORK/$m.out" ;;
    g2-moved)   grep -qxF "$G2_WANT" "$WORK/$m.out" ;;
    g3-moved)   grep -qxF "$G3_WANT" "$WORK/$m.out" ;;
    g4-moved)   grep -qxF "$G4_WANT" "$WORK/$m.out" ;;
    gdiffers)   grep -q '^Gdeny=' "$WORK/$m.out" && ! grep -qxF "$GCUT" "$WORK/$m.out" ;;
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
M2_ANCHOR='AI_DLC_VERDICT_STORE="$W/vs" bash "$W/prefix.sh" < /dev/null > "$W/a.out" 2>&1'
n_anchor="$(grep -cxF "$M2_ANCHOR" "$SUBJECT")" || n_anchor=0
if [ "$n_anchor" -eq 1 ]; then ok "m2 mutant: the anchor line occurs exactly once in the subject"; B_m2_anchor=1
else bad "m2 mutant: the anchor line occurs $n_anchor times in the subject, expected exactly 1"; fi
MUT2="$WORK/m2-pregate-self-check.sh"
sed 's/^AI_DLC_VERDICT_STORE="\$W\/vs" bash "\$W\/prefix\.sh" < \/dev\/null > "\$W\/a\.out" 2>&1$/: "$ai_dlc_m2_unbound"; &/' "$SUBJECT" > "$MUT2" 2>/dev/null
if [ "$n_anchor" -eq 1 ] && [ -s "$MUT2" ] && ! cmp -s "$SUBJECT" "$MUT2"; then
  bash "$RECEIPT" "$MUT2" > "$WORK/m2.out" 2>&1; echo $? > "$WORK/m2.rc"; m2="$(cat "$WORK/m2.rc")"
  if cell_red exit1 m2; then mutant_killed "$(( ${B_a1_exit:-0} && ${B_a1_line:-0} && ${B_m2_anchor:-0} ))" m2 "m2 mutant: receipt exit 1 (killed)"; else bad "m2 mutant SURVIVED: receipt exit $m2, expected 1"; fi
  if cell_red m2-refused m2; then mutant_killed "$(( ${B_a1_exit:-0} && ${B_a1_line:-0} && ${B_m2_anchor:-0} ))" m2 "m2 mutant: every world refused with exit 2"; else bad "m2 mutant SURVIVED: expected the line '$M2_WANT' (got: $(tail -1 "$WORK/m2.out"))"; fi
  if cell_red m2-names m2; then mutant_killed "$(( ${B_a1_exit:-0} && ${B_a1_line:-0} && ${B_m2_anchor:-0} ))" m2 "m2 mutant: world A names the early-death refusal and the unbound variable"; else bad "m2 mutant SURVIVED: world A's output lacks the early-death refusal or the unbound variable"; fi
  if cell_red differs m2; then mutant_killed "$(( ${B_a1_exit:-0} && ${B_a1_line:-0} && ${B_m2_anchor:-0} ))" m2 "m2 mutant: output differs from the control"; else bad "m2 mutant SURVIVED: output equals the control"; fi
  mx_twins m2
  mx_matrix_only m2
else
  bad "m2 mutant: DID NOT APPLY (the anchor was not unique, or sed died)"
  bad "m2 mutant: DID NOT APPLY (no kill line to check)"
  bad "m2 mutant: DID NOT APPLY (no refusal message to check)"
  bad "m2 mutant: DID NOT APPLY (no differential)"
  BROKEN=$((BROKEN + 1))
fi

# --- m3: the old HOOK line (the hook a push would run is not resolved; the tree's own file is run) -----------
# The whole HOOK-RESOLVE block is replaced by the pre-BL-1020 assignment, so the Hres, Htree and Habs worlds, which
# all hold a valid tree hook, run it and exit 0 instead of refusing.
n_h3="$(grep -cxF '# HOOK-RESOLVE-BEGIN' "$SUBJECT")" || n_h3=0
if [ "$n_h3" -eq 1 ]; then ok "m3 mutant applied: the HOOK-RESOLVE block occurs exactly once in the subject"; B_m3_anchor=1
else bad "m3 mutant: the HOOK-RESOLVE block occurs $n_h3 times in the subject, expected exactly 1"; fi
MUT3="$WORK/m3-pregate-self-check.sh"
awk '$0 == "# HOOK-RESOLVE-BEGIN" { print "HOOK=\"$ROOT/.githooks/pre-push\""; skip = 1; next }
     $0 == "# HOOK-RESOLVE-END" { skip = 0; next }
     !skip { print }' "$SUBJECT" > "$MUT3" 2>/dev/null
if [ "$n_h3" -eq 1 ] && [ -s "$MUT3" ] && ! cmp -s "$SUBJECT" "$MUT3"; then
  bash "$RECEIPT" "$MUT3" > "$WORK/m3.out" 2>&1; echo $? > "$WORK/m3.rc"; m3="$(cat "$WORK/m3.rc")"
  if cell_red exit1 m3; then mutant_killed "$(( ${B_a1_exit:-0} && ${B_a1_line:-0} && ${B_m3_anchor:-0} ))" m3 "m3 mutant: receipt exit 1 (killed)"; else bad "m3 mutant SURVIVED: receipt exit $m3, expected 1"; fi
  if cell_red m3-moved m3; then mutant_killed "$(( ${B_a1_exit:-0} && ${B_a1_line:-0} && ${B_m3_anchor:-0} ))" m3 "m3 mutant: Hres, Htree and Habs each ran the hook (0) and named nothing"; else bad "m3 mutant SURVIVED: expected the line '$M3_WANT' (got: $(tail -1 "$WORK/m3.out"))"; fi
  if cell_red differs m3; then mutant_killed "$(( ${B_a1_exit:-0} && ${B_a1_line:-0} && ${B_m3_anchor:-0} ))" m3 "m3 mutant: output differs from the control"; else bad "m3 mutant SURVIVED: output equals the control"; fi
  mx_twins m3
  mx_matrix_only m3
else
  bad "m3 mutant: DID NOT APPLY (the block markers were not unique, or awk died)"
  bad "m3 mutant: DID NOT APPLY (no kill line to check)"
  bad "m3 mutant: DID NOT APPLY (no differential)"
  BROKEN=$((BROKEN + 1))
fi

# --- m4: the pregate record written whatever the tree's state (BL-1055) ---------------------------------------
# The clean-and-unmoved condition replaced by `true`: the dirty world Wd then records its tree and names nothing.
mut_line() { # mut_line <src> <dst> <exact line> <replacement|--delete> -> 0 when the line occurs once and was replaced
  local n
  n="$(grep -cxF -- "$3" "$1")" || n=0
  [ "$n" -eq 1 ] || return 1
  L="$3" R="$4" awk '$0 == ENVIRON["L"] { if (ENVIRON["R"] != "--delete") print ENVIRON["R"]; next } { print }' "$1" > "$2" 2>/dev/null \
    && [ -s "$2" ] && ! cmp -s "$1" "$2"
}
MUT4="$WORK/m4-pregate-self-check.sh"
if mut_line "$SUBJECT" "$MUT4" 'if [ -n "$PG_START" ] && [ "$PG_START" = "$pg_tree" ] && [ "$PG_END" = "$PG_START" ]; then' 'if true; then'; then
  ok "m4 mutant applied: the record condition occurs exactly once in the subject"; B_m4_anchor=1
  bash "$RECEIPT" "$MUT4" > "$WORK/m4.out" 2>&1; echo $? > "$WORK/m4.rc"; m4="$(cat "$WORK/m4.rc")"
  if cell_red exit1 m4; then mutant_killed "$(( ${B_a1_exit:-0} && ${B_a1_line:-0} && ${B_m4_anchor:-0} ))" m4 "m4 mutant: receipt exit 1 (killed)"; else bad "m4 mutant SURVIVED: receipt exit $m4, expected 1"; fi
  if cell_red m4-moved m4; then mutant_killed "$(( ${B_a1_exit:-0} && ${B_a1_line:-0} && ${B_m4_anchor:-0} ))" m4 "m4 mutant: the dirty world Wd recorded its tree and named nothing"; else bad "m4 mutant SURVIVED: expected the line '$M4_WANT' (got: $(tail -1 "$WORK/m4.out"))"; fi
  if cell_red differs m4; then mutant_killed "$(( ${B_a1_exit:-0} && ${B_a1_line:-0} && ${B_m4_anchor:-0} ))" m4 "m4 mutant: output differs from the control"; else bad "m4 mutant SURVIVED: output equals the control"; fi
  mx_twins m4
  mx_matrix_only m4
else
  bad "m4 mutant: DID NOT APPLY (the record condition is not exactly one line of the subject, or awk died)"
  bad "m4 mutant: DID NOT APPLY (no kill line to check)"
  bad "m4 mutant: DID NOT APPLY (no moved line to check)"
  bad "m4 mutant: DID NOT APPLY (no differential)"
  BROKEN=$((BROKEN + 1))
fi

# --- m5: section d never takes the clean-tree route (BL-1064) ------------------------------------------------
MUT5="$WORK/m5-pregate-self-check.sh"
if mut_line "$SUBJECT" "$MUT5" 'if [ -n "$PG_START" ] && [ "$PG_START" = "${PG_START%%' 'if false && [ "$PG_START" = "${PG_START%%'; then
  ok "m5 mutant applied: the clean-tree test of section d occurs exactly once in the subject"; B_m5_anchor=1
  bash "$RECEIPT" "$MUT5" > "$WORK/m5.out" 2>&1; echo $? > "$WORK/m5.rc"; m5="$(cat "$WORK/m5.rc")"
  if cell_red exit1 m5; then mutant_killed "$(( ${B_a1_exit:-0} && ${B_a1_line:-0} && ${B_m5_anchor:-0} ))" m5 "m5 mutant: receipt exit 1 (killed)"; else bad "m5 mutant SURVIVED: receipt exit $m5, expected 1"; fi
  if cell_red m5-moved m5; then mutant_killed "$(( ${B_a1_exit:-0} && ${B_a1_line:-0} && ${B_m5_anchor:-0} ))" m5 "m5 mutant: the clean world A ran section d under the scratch store"; else bad "m5 mutant SURVIVED: expected the line '$M5_WANT' (got: $(tail -1 "$WORK/m5.out"))"; fi
  if cell_red differs m5; then mutant_killed "$(( ${B_a1_exit:-0} && ${B_a1_line:-0} && ${B_m5_anchor:-0} ))" m5 "m5 mutant: output differs from the control"; else bad "m5 mutant SURVIVED: output equals the control"; fi
  mx_twins m5
  mx_matrix_only m5
else
  bad "m5 mutant: DID NOT APPLY (the clean-tree test is not exactly one line of the subject, or awk died)"
  bad "m5 mutant: DID NOT APPLY (no kill line to check)"
  bad "m5 mutant: DID NOT APPLY (no moved line to check)"
  bad "m5 mutant: DID NOT APPLY (no differential)"
  BROKEN=$((BROKEN + 1))
fi

# --- m6: the member mode writes the pregate record (BL-1082) --------------------------------------------------
MUT6="$WORK/m6-pregate-self-check.sh"
if mut_line "$SUBJECT" "$MUT6" 'if [ "$MEMBER" = 1 ]; then # member: no pregate record' 'if false; then'; then
  ok "m6 mutant applied: the member mode's no-record exit occurs exactly once in the subject"; B_m6_anchor=1
  bash "$RECEIPT" "$MUT6" > "$WORK/m6.out" 2>&1; echo $? > "$WORK/m6.rc"; m6="$(cat "$WORK/m6.rc")"
  if cell_red exit1 m6; then mutant_killed "$(( ${B_a1_exit:-0} && ${B_a1_line:-0} && ${B_m6_anchor:-0} ))" m6 "m6 mutant: receipt exit 1 (killed)"; else bad "m6 mutant SURVIVED: receipt exit $m6, expected 1"; fi
  if cell_red m6-moved m6; then mutant_killed "$(( ${B_a1_exit:-0} && ${B_a1_line:-0} && ${B_m6_anchor:-0} ))" m6 "m6 mutant: the member world Mt wrote a pregate record and did not say it wrote none"; else bad "m6 mutant SURVIVED: expected the line '$M6_WANT' (got: $(tail -1 "$WORK/m6.out"))"; fi
  if cell_red differs m6; then mutant_killed "$(( ${B_a1_exit:-0} && ${B_a1_line:-0} && ${B_m6_anchor:-0} ))" m6 "m6 mutant: output differs from the control"; else bad "m6 mutant SURVIVED: output equals the control"; fi
  mx_twins m6
  mx_matrix_only m6
else
  bad "m6 mutant: DID NOT APPLY (the member no-record test is not exactly one line of the subject, or awk died)"
  bad "m6 mutant: DID NOT APPLY (no kill line to check)"
  bad "m6 mutant: DID NOT APPLY (no moved line to check)"
  bad "m6 mutant: DID NOT APPLY (no differential)"
  BROKEN=$((BROKEN + 1))
fi

# --- m7: the member mode runs the hook a push would run, not the tree's own (BL-1082) -------------------------
MUT7="$WORK/m7-pregate-self-check.sh"
if mut_line "$SUBJECT" "$MUT7" '  HOOK="$ROOT/.githooks/pre-push"' --delete; then
  ok "m7 mutant applied: the member mode's tree-hook assignment occurs exactly once in the subject"; B_m7_anchor=1
  bash "$RECEIPT" "$MUT7" > "$WORK/m7.out" 2>&1; echo $? > "$WORK/m7.rc"; m7="$(cat "$WORK/m7.rc")"
  if cell_red exit1 m7; then mutant_killed "$(( ${B_a1_exit:-0} && ${B_a1_line:-0} && ${B_m7_anchor:-0} ))" m7 "m7 mutant: receipt exit 1 (killed)"; else bad "m7 mutant SURVIVED: receipt exit $m7, expected 1"; fi
  if cell_red m7-moved m7; then mutant_killed "$(( ${B_a1_exit:-0} && ${B_a1_line:-0} && ${B_m7_anchor:-0} ))" m7 "m7 mutant: the member world Mr's red step after PRESUITE_DONE=1 went unseen"; else bad "m7 mutant SURVIVED: expected the line '$M7_WANT' (got: $(tail -1 "$WORK/m7.out"))"; fi
  if cell_red differs m7; then mutant_killed "$(( ${B_a1_exit:-0} && ${B_a1_line:-0} && ${B_m7_anchor:-0} ))" m7 "m7 mutant: output differs from the control"; else bad "m7 mutant SURVIVED: output equals the control"; fi
  mx_twins m7
  mx_matrix_only m7
else
  bad "m7 mutant: DID NOT APPLY (the member tree-hook assignment is not exactly one line of the subject, or awk died)"
  bad "m7 mutant: DID NOT APPLY (no kill line to check)"
  bad "m7 mutant: DID NOT APPLY (no moved line to check)"
  bad "m7 mutant: DID NOT APPLY (no differential)"
  BROKEN=$((BROKEN + 1))
fi

# --- m8: the edited-hook refusal no longer names --member, the member mode's carrier (BL-1082) ---------------
MUT8="$WORK/m8-pregate-self-check.sh"
if mut_line "$SUBJECT" "$MUT8" '        else remedy="; the branch edited the hook, but the push will run ${HOOK}, not the edit: update the checkout holding it (the main checkout) or push from that checkout; before READY run this script with --member, which runs the tree'"'"'s own hook and records nothing"; fi' \
     '        else remedy="; the branch edited the hook, but the push will run ${HOOK}, not the edit: update the checkout holding it (the main checkout) or push from that checkout"; fi'; then
  ok "m8 mutant applied: the edited-hook remedy occurs exactly once in the subject"; B_m8_anchor=1
  bash "$RECEIPT" "$MUT8" > "$WORK/m8.out" 2>&1; echo $? > "$WORK/m8.rc"; m8="$(cat "$WORK/m8.rc")"
  if cell_red exit1 m8; then mutant_killed "$(( ${B_a1_exit:-0} && ${B_a1_line:-0} && ${B_m8_anchor:-0} ))" m8 "m8 mutant: receipt exit 1 (killed)"; else bad "m8 mutant SURVIVED: receipt exit $m8, expected 1"; fi
  if cell_red m8-moved m8; then mutant_killed "$(( ${B_a1_exit:-0} && ${B_a1_line:-0} && ${B_m8_anchor:-0} ))" m8 "m8 mutant: Htree's edited-hook refusal no longer names --member"; else bad "m8 mutant SURVIVED: expected the line '$M8_WANT' (got: $(tail -1 "$WORK/m8.out"))"; fi
  if cell_red differs m8; then mutant_killed "$(( ${B_a1_exit:-0} && ${B_a1_line:-0} && ${B_m8_anchor:-0} ))" m8 "m8 mutant: output differs from the control"; else bad "m8 mutant SURVIVED: output equals the control"; fi
  mx_twins m8
  mx_matrix_only m8
else
  bad "m8 mutant: DID NOT APPLY (the edited-hook remedy is not exactly one line of the subject, or awk died)"
  bad "m8 mutant: DID NOT APPLY (no kill line to check)"
  bad "m8 mutant: DID NOT APPLY (no moved line to check)"
  bad "m8 mutant: DID NOT APPLY (no differential)"
  BROKEN=$((BROKEN + 1))
fi

# --- the BL-1055 push gate: the PREGATE_GATE span of the distribution hook, cut and driven ---------------------
# The hook resolved here is .githooks/pre-push by name (core/git-hooks/pre-push carries no gate). gc is the control,
# with one whole-hook drive (E2E) proving the call site stops the hook before any step; g1-g4 each mutate one test
# of a copy of that hook and are driven on the cut span alone (--cut-only), so a mutant that opens the gate never
# runs the rest of the hook.
HOOK_FILE="$REPO/.githooks/pre-push"
printf '  hook  %s\n' "$HOOK_FILE"
bash core/fixtures/pregate-self-check/receipt-bl643.sh --gate "$HOOK_FILE" > "$WORK/gc.out" 2>&1; gc=$?
if [ "$gc" -eq 9 ]; then echo "FIXTURE BROKEN: the gate receipt could not build its world" >&2; sed 's/^/     /' "$WORK/gc.out" >&2; exit 2; fi
grep -q '^Gdeny=' "$WORK/gc.out" && echo "HERMETIC-CONSUMED .githooks/pre-push"
if [ "$gc" -eq 0 ]; then ok "gc control: gate receipt exit 0 on the distribution hook"; B_gc_exit=1; else bad "gc control: gate receipt exit $gc, expected 0"; fi
if grep -qxF "$GWANT" "$WORK/gc.out"; then ok "gc control: the line '$GWANT' is present"; B_gc_line=1; else bad "gc control: the line '$GWANT' is absent (got: $(tail -1 "$WORK/gc.out"))"; fi
# gate_mut <name> <base flag> <moved-cell message>: scores the hook copy $WORK/<name>-pre-push, which the caller's
# mut_line wrote only when its line occurs exactly once; the caller fills <base flag> from B_gc_exit, B_gc_line and
# its own B_<name>_anchor, set =1 only when its mut_line applied.
# MUTANT-MATRIX-DYNAMIC gate-mut-name why=gate_mut passes its first argument to mutant_killed; its four callers name g1, g2, g3 and g4, each a literal MUTANT-MATRIX row above
gate_mut() {
  local m="$1" mf="$WORK/$1-pre-push"
  if [ -s "$mf" ] && ! cmp -s "$HOOK_FILE" "$mf"; then
    bash core/fixtures/pregate-self-check/receipt-bl643.sh --gate "$mf" --cut-only > "$WORK/$m.out" 2>&1; echo $? > "$WORK/$m.rc"
    if cell_red exit1 "$m"; then mutant_killed "$2" "$m" "$m mutant: gate receipt exit 1 (killed)"; else bad "$m mutant SURVIVED: gate receipt exit $(cat "$WORK/$m.rc"), expected 1"; fi
    if cell_red "$m-moved" "$m"; then mutant_killed "$2" "$m" "$m mutant: $3"; else bad "$m mutant SURVIVED: its own cell did not move (got: $(tail -1 "$WORK/$m.out"))"; fi
    if cell_red gdiffers "$m"; then mutant_killed "$2" "$m" "$m mutant: output differs from the cut control"; else bad "$m mutant SURVIVED: output equals the cut control"; fi
    mx_twins "$m"
    mx_matrix_only "$m"
  else
    bad "$m mutant: DID NOT APPLY (no kill line to check)"
    bad "$m mutant: DID NOT APPLY (no moved line to check)"
    bad "$m mutant: DID NOT APPLY (no differential)"
    BROKEN=$((BROKEN + 1))
  fi
}
B_g1_anchor=0
if mut_line "$HOOK_FILE" "$WORK/g1-pre-push" '  if [ -z "$gcd" ] || [ ! -f "$rec" ] || [ "$(sed -n 1p "$rec" 2>/dev/null)" != '"'#format pg1'"' ]; then' '  if false; then'; then ok "g1 mutant applied: its line occurs exactly once in $HOOK_FILE"; B_g1_anchor=1; else bad "g1 mutant: DID NOT APPLY (its line is not exactly one line of $HOOK_FILE, or awk died)"; fi
gate_mut g1 "$(( ${B_gc_exit:-0} && ${B_gc_line:-0} && ${B_g1_anchor:-0} ))" "with the record test gone, a push with no record passes the gate"
B_g2_anchor=0
if mut_line "$HOOK_FILE" "$WORK/g2-pre-push" '  if [ -n "$st" ]; then' '  if false; then'; then ok "g2 mutant applied: its line occurs exactly once in $HOOK_FILE"; B_g2_anchor=1; else bad "g2 mutant: DID NOT APPLY (its line is not exactly one line of $HOOK_FILE, or awk died)"; fi
gate_mut g2 "$(( ${B_gc_exit:-0} && ${B_gc_line:-0} && ${B_g2_anchor:-0} ))" "with the clean-tree test gone, a dirty tree passes the gate"
B_g3_anchor=0
if mut_line "$HOOK_FILE" "$WORK/g3-pre-push" '    if [ "$(git rev-parse --verify --quiet "${ls}^{tree}")" != "$tree" ] || [ -z "$tree" ]; then' '    if false; then'; then ok "g3 mutant applied: its line occurs exactly once in $HOOK_FILE"; B_g3_anchor=1; else bad "g3 mutant: DID NOT APPLY (its line is not exactly one line of $HOOK_FILE, or awk died)"; fi
gate_mut g3 "$(( ${B_gc_exit:-0} && ${B_gc_line:-0} && ${B_g3_anchor:-0} ))" "with the tree-equality test gone, a pushed sha whose tree is not HEAD's passes the gate"
B_g4_anchor=0
if mut_line "$HOOK_FILE" "$WORK/g4-pre-push" '  [ "$n" -gt 0 ] || return 0 # an empty stdin delivers nothing: not gated' --delete; then ok "g4 mutant applied: its line occurs exactly once in $HOOK_FILE"; B_g4_anchor=1; else bad "g4 mutant: DID NOT APPLY (its line is not exactly one line of $HOOK_FILE, or awk died)"; fi
gate_mut g4 "$(( ${B_gc_exit:-0} && ${B_gc_line:-0} && ${B_g4_anchor:-0} ))" "with the empty-stdin exemption gone, a hand run with no record is refused"

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
  [ "$mx_hdr" = "g1 g2 g3 g4 m1 m2 m3 m4 m5 m6 m7 m8 " ] || { BROKEN=$((BROKEN + 1)); echo "MATRIX BROKEN: the header rows are [$mx_hdr], expected [g1 g2 g3 g4 m1 m2 m3 m4 m5 m6 m7 m8 ]"; }
  echo "MATRIX-SUMMARY $mx_only matrix-only cell(s) ran, $mx_ctl per-push twin check(s)"
  [ "$MX_FAILS" -eq 0 ] || fails=$((fails + MX_FAILS))
fi

# --- a closing tally derived from the notes actually emitted ----------------------------------
if [ "$BROKEN" -ne 0 ]; then
  echo "FIXTURE BROKEN: $BROKEN mutant arm(s) could not be built or scored, so those assertions tested nothing" >&2
  exit 2
fi
if [ "$MODE" = plain ]; then
  report_end pregate-self-check "$EXPECTED_ASSERTIONS"
fi
report_end pregate-self-check
