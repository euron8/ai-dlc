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
# a1  control: the self-check -> A=0 B=1 C=2 noparse=2 nostep=2 noverdict=2 D=2 Dran=no
#     Dnamed=yes, exit 0 (positive conjunct: that exact line must APPEAR, so a subject that prints nothing
#     fails it)
# gc  control (BL-1055): the PREGATE_GATE span of .githooks/pre-push, cut and driven by the receipt's --gate mode
#     (deny, empty, allow, tree, dirty), plus one whole-hook drive (E2E) that must stop at the gate before any step.
set -uo pipefail
# The env-derived scrub (H8): this fixture drives a hook, so no inherited AI_DLC_* tunable reaches it.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
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
WANT='A=0 B=1 C=2 noparse=2 nostep=2 noverdict=2 D=2 Dran=no Dnamed=yes U=2 Unamed=yes J=1 Jnamed=yes Hres=2 Hresn=yes Htree=2 Htreen=yes Habs=2 Habsn=yes Hbehind=2 Hbehindn=yes Arec=yes Brec=no Wd=0 Wdrec=no Wdn=yes Aseed=yes Wdseed=yes Mt=0 Mtn=yes Mtrec=no Mr=1 Mrn=yes Htreem=yes Eskip=yes Mte=yes Er=1 Ern=yes Ts=0 Tsn=yes Tn=0 Tnn=yes Ep=0 Epn=yes Epall=no Epnone=no Fskip=yes Tnf=yes Fs=1 Fsn=yes Fsnear=no'

cd "$REPO" || exit 2

# --- every drive is IN PROCESS (BL-878). The self-check is loaded once (inproc_load) and each world asks psc_main through
# the receipt's psc_drive; the receipt itself is sourced here and asked blr_main in a subshell; the seeder runs inside the
# self-check as svs_main. Command-line starts, one per distinct CLI outcome, are the FXCELL-tagged twins in cells.decl:
# the receipt's eqv() runs them for the self-check and the seeder.
. "$HERE/../lib/inproc.sh" || { echo "FIXTURE ERROR: lib/inproc.sh not found" >&2; exit 2; }
psc_drive() { inproc_run "$REPO/scripts/pregate-self-check.sh" psc_main "$@"; } # <self-check args> -> its answer, in process
export FX_SVS="$REPO/scripts/seed-verdict-store.sh" # exported: inproc_run keeps exported variables and drops the rest
bash() { # the self-check's own `bash "$SEED" ...` starts run the seeder's svs_main in a fresh-options subshell; any other bash start is real
  if [ "${1:-}" = "$FX_SVS" ]; then
    shift
    ! declare -F fx_inproc >/dev/null 2>&1 || fx_inproc "$FX_SVS"; ( set +eufx +o pipefail; . "$FX_SVS" && svs_main "$@" )
  else command bash "$@"; fi
}
inproc_load "$REPO/scripts/pregate-self-check.sh" || { echo "FIXTURE ERROR: $SUBJECT defines no psc_main (not loadable)" >&2; exit 2; }
# inproc_run strips every function the subject did not define; the bash shim above is kept through that strip by naming it with
# the loaded set (inproc_run then checks the set's definitions are unchanged, and bash is part of it).
INPROC_FNS="${INPROC_FNS}bash "; INPROC_DEFS="$(declare -f $INPROC_FNS)"
# shellcheck source=/dev/null
fx_inproc "$RECEIPT"; . "$REPO/core/fixtures/pregate-self-check/receipt-bl643.sh" || { echo "FIXTURE ERROR: cannot source $RECEIPT" >&2; exit 2; }
declare -F blr_main >/dev/null 2>&1 || { echo "FIXTURE ERROR: $RECEIPT defines no blr_main (not loadable)" >&2; exit 2; }

# --- a1: the unmutated control ----------------------------------------------------------------
( fx_inproc "$RECEIPT"; blr_main "$SUBJECT" ) > "$WORK/a1.out" 2>&1; a1=$?
if [ "$a1" -eq 9 ]; then echo "FIXTURE BROKEN: the receipt could not build its worlds" >&2; sed 's/^/     /' "$WORK/a1.out" >&2; exit 2; fi
# THE SENTINELS BELOW ARE KEYED ON THE RECEIPT'S OUTPUT, NOT ON ITS EXIT CODE: the receipt prints its `A=...` summary line
# only after it has tested and driven the self-check in every world, which an exit code alone cannot attest.
# `grep -q` on the file, never fed from a pipe. Its own `A| ` echo of world A cannot match `^A=`.
if [ "$a1" -ne 9 ] && grep -q '^A=' "$WORK/a1.out"; then
  echo "HERMETIC-CONSUMED core/fixtures/procsub-staged-refusal/procsub-spell-probe.diff"
  echo "HERMETIC-CONSUMED scripts/pregate-self-check.sh"
  echo "HERMETIC-CONSUMED scripts/seed-verdict-store.sh"
  echo "HERMETIC-CONSUMED $RECEIPT"
fi
if [ "$a1" -eq 0 ]; then ok "a1 control: receipt exit 0 on the unmutated self-check"; B_a1_exit=1; else bad "a1 control: receipt exit $a1, expected 0"; fi
if grep -qxF "$WANT" "$WORK/a1.out"; then ok "a1 control: the line '$WANT' is present"; B_a1_line=1; else bad "a1 control: the line '$WANT' is absent (got: $(tail -1 "$WORK/a1.out"))"; fi
# The command-line twins of the self-check and the seeder (cells cli-psc-*, cli-svs-*), run by the receipt: each outcome's
# exit is the in-process one and stdout, stderr and exit agree between the two (refusal 2, pass 0, for each subject).
EWANT='EQV psc-refuse=2/yes psc-pass=0/yes svs-refuse=2/yes svs-pass=0/yes'
if grep -qxF "$EWANT" "$WORK/a1.out"; then ok "a1 twins: '$EWANT' is present"; else bad "a1 twins: the line '$EWANT' is absent (got: $(grep '^EQV ' "$WORK/a1.out"))"; fi

GWANT='Gdeny=1 Gdenyn=yes Gempty=0 Gallow=0 Gtree=1 Gtreen=yes Gdirty=1 Gdirtyn=yes E2E=1 E2En=yes'
# --- the BL-1055 push gate: the PREGATE_GATE span of the distribution hook, cut and driven ---------------------
# The hook resolved here is .githooks/pre-push by name (core/git-hooks/pre-push carries no gate). gc is the control,
# with one whole-hook drive (E2E) proving the call site stops the hook before any step. That hook start is no start of a
# subject of this fixture.
HOOK_FILE="$REPO/.githooks/pre-push"
printf '  hook  %s\n' "$HOOK_FILE"
( fx_inproc "$RECEIPT"; blr_main --gate "$HOOK_FILE" ) > "$WORK/gc.out" 2>&1; gc=$?
if [ "$gc" -eq 9 ]; then echo "FIXTURE BROKEN: the gate receipt could not build its world" >&2; sed 's/^/     /' "$WORK/gc.out" >&2; exit 2; fi
grep -q '^Gdeny=' "$WORK/gc.out" && echo "HERMETIC-CONSUMED .githooks/pre-push"
if [ "$gc" -eq 0 ]; then ok "gc control: gate receipt exit 0 on the distribution hook"; B_gc_exit=1; else bad "gc control: gate receipt exit $gc, expected 0"; fi
if grep -qxF "$GWANT" "$WORK/gc.out"; then ok "gc control: the line '$GWANT' is present"; B_gc_line=1; else bad "gc control: the line '$GWANT' is absent (got: $(tail -1 "$WORK/gc.out"))"; fi

# 5 = a1: 3 ok, gc: 2 ok.
report_end pregate-self-check 5
