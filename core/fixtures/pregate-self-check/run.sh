#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# pregate-self-check -- assert scripts/pregate-self-check.sh derives its above-pool steps from the hook's
# own prefix, and that each of its guards fires.
#
# Usage: run.sh        (from the repo root, as the pre-push pool runs it)
# Exit:  0 = every assertion holds, 1 = the self-check regressed, 2 = fixture broken.
#
# THE WORLDS ARE SYNTHETIC, ALWAYS. receipt-bl643.sh seeds mini hooks of one to three trivial steps plus
# the cut marker (roots A, B, C and the refusals noparse, nostep, noverdict) and drives the self-check
# under AI_DLC_PREGATE_ROOT. This run.sh never drives the real .githooks/pre-push prefix: its 20 steps
# cost about a minute, and "today's real hook passes" is the self-check's own job, not this fixture's.
#
# a1  control: the unmutated self-check -> A=0 B=1 C=2 noparse=2 nostep=2 noverdict=2, exit 0 (positive
#     conjunct: that exact line must APPEAR, so a subject that prints nothing fails it)
# m1  mutant: the verdict-count == declared-steps equality removed. noverdict then exits 1 (a dying step
#     reads as one red step), every other world is unchanged, and the receipt exits 1.
set -uo pipefail

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
echo "HERMETIC-CONSUMED scripts/pregate-self-check.sh"
echo "HERMETIC-CONSUMED $RECEIPT"
command -v git >/dev/null 2>&1 || { echo "FIXTURE ERROR: git not on PATH" >&2; exit 2; }
WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

fails=0
made=0
ok()  { printf '  ok    %s\n' "$1"; made=$((made+1)); }
bad() { printf '  FAIL  %s\n' "$1"; made=$((made+1)); fails=$((fails+1)); }
# 5 = a1: 2 notes, plus m1: 3 notes on either branch (applied, or DID NOT APPLY; the branches are exclusive).
EXPECTED_ASSERTIONS=5
WANT='A=0 B=1 C=2 noparse=2 nostep=2 noverdict=2'

cd "$REPO" || exit 2

# --- a1: the unmutated control ----------------------------------------------------------------
bash "$RECEIPT" "$SUBJECT" > "$WORK/a1.out" 2>&1; a1=$?
if [ "$a1" -eq 9 ]; then echo "FIXTURE BROKEN: the receipt could not build its worlds" >&2; sed 's/^/     /' "$WORK/a1.out" >&2; exit 2; fi
[ "$a1" -eq 0 ] && ok "a1 control: receipt exit 0 on the unmutated self-check" || bad "a1 control: receipt exit $a1, expected 0"
grep -qxF "$WANT" "$WORK/a1.out" && ok "a1 control: the line '$WANT' is present" || bad "a1 control: the line '$WANT' is absent (got: $(tail -1 "$WORK/a1.out"))"

# --- m1: the verdict-count equality removed ---------------------------------------------------
MUT="$WORK/m1-pregate-self-check.sh"
sed 's/^if \[ "\$nv" -ne "\$ns" \]; then$/if false; then/' "$SUBJECT" > "$MUT" 2>/dev/null
if [ -s "$MUT" ] && ! cmp -s "$SUBJECT" "$MUT"; then
  bash "$RECEIPT" "$MUT" > "$WORK/m1.out" 2>&1; m1=$?
  [ "$m1" -eq 1 ] && ok "m1 mutant: receipt exit 1 (killed)" || bad "m1 mutant: receipt exit $m1, expected 1"
  grep -qxF 'A=0 B=1 C=2 noparse=2 nostep=2 noverdict=1' "$WORK/m1.out" \
    && ok "m1 mutant: only noverdict moved, to 1" || bad "m1 mutant: expected the line 'A=0 B=1 C=2 noparse=2 nostep=2 noverdict=1' (got: $(tail -1 "$WORK/m1.out"))"
  grep -qxF "$WANT" "$WORK/m1.out" && bad "m1 mutant: output equals the control, nothing was killed" || ok "m1 mutant: output differs from the control"
else
  bad "m1 mutant: DID NOT APPLY (the equality line was not found, or sed died)"
  bad "m1 mutant: DID NOT APPLY (no kill line to check)"
  bad "m1 mutant: DID NOT APPLY (no differential)"
fi

# --- a closing tally derived from the notes actually emitted ----------------------------------
if [ "$made" -ne "$EXPECTED_ASSERTIONS" ]; then
  echo "FIXTURE BROKEN: $made assertion(s) ran, expected $EXPECTED_ASSERTIONS -- an arm never executed" >&2
  exit 1
fi
if [ "$fails" -ne 0 ]; then
  echo "pregate-self-check: $fails FAILED of $made"
  exit 1
fi
echo "pregate-self-check: PASS ($made assertions)"
exit 0
