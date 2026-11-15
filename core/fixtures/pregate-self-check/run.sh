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
WANT='A=0 B=1 C=2 noparse=2 nostep=2 noverdict=2 D=2 Dran=no Dnamed=yes U=2 Unamed=yes J=1 Jnamed=yes Hcwd=0 Hres=2 Hresn=yes Htree=2 Htreen=yes Habs=2 Habsn=yes Hbehind=2 Hbehindn=yes Arec=yes Brec=no Wd=0 Wdrec=no Wdn=yes Aseed=yes Wdseed=yes Mt=0 Mtn=yes Mtrec=no Mr=1 Mrn=yes Htreem=yes Eskip=yes Mte=yes Er=1 Ern=yes Ts=0 Tsn=yes Tn=0 Tnn=yes Ep=0 Epn=yes Epall=no Epnone=no'

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

GWANT='Gdeny=1 Gdenyn=yes Gempty=0 Gallow=0 Gtree=1 Gtreen=yes Gdirty=1 Gdirtyn=yes E2E=1 E2En=yes'
# --- the BL-1055 push gate: the PREGATE_GATE span of the distribution hook, cut and driven ---------------------
# The hook resolved here is .githooks/pre-push by name (core/git-hooks/pre-push carries no gate). gc is the control,
# with one whole-hook drive (E2E) proving the call site stops the hook before any step.
HOOK_FILE="$REPO/.githooks/pre-push"
printf '  hook  %s\n' "$HOOK_FILE"
bash core/fixtures/pregate-self-check/receipt-bl643.sh --gate "$HOOK_FILE" > "$WORK/gc.out" 2>&1; gc=$?
if [ "$gc" -eq 9 ]; then echo "FIXTURE BROKEN: the gate receipt could not build its world" >&2; sed 's/^/     /' "$WORK/gc.out" >&2; exit 2; fi
grep -q '^Gdeny=' "$WORK/gc.out" && echo "HERMETIC-CONSUMED .githooks/pre-push"
if [ "$gc" -eq 0 ]; then ok "gc control: gate receipt exit 0 on the distribution hook"; B_gc_exit=1; else bad "gc control: gate receipt exit $gc, expected 0"; fi
if grep -qxF "$GWANT" "$WORK/gc.out"; then ok "gc control: the line '$GWANT' is present"; B_gc_line=1; else bad "gc control: the line '$GWANT' is absent (got: $(tail -1 "$WORK/gc.out"))"; fi
# 4 = a1: 2 ok, gc: 2 ok.
report_end pregate-self-check 4
