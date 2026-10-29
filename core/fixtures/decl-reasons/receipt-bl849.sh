#!/usr/bin/env bash
# decl-reasons/receipt-bl849.sh -- a DID-NOT-APPLY mutant failure reaches the fixture's exit.
#
#   exit 0   the fix is present: a forced failure makes the fixture exit non-zero and print
#            DID NOT APPLY, and the same fixture unforced exits 0 with its PASS line
#   exit 1   the defect is live (the first missing property is printed)
#   exit 9   the receipt cannot measure: the fixture or its subject is absent, or no copy can be built
#
# THE FORCING. The fixture's M1 mutant rewrites the line `self_probe || exit 2` of the validator.
# The copy of the validator used here respaces that line to `self_probe  || exit 2`, so M1's sed
# matches nothing and mut() reports DID NOT APPLY. At base that report is recorded inside a `$( )`
# subshell, so neither the count nor the text survives and the fixture still exits 0.
#
# THE COPY. Two trees under one mktemp directory, each laid out as the repo lays them out
# (core/fixtures/decl-reasons/run.sh and scripts/validate-decl-reasons.sh), because run.sh locates
# its subject at HERE/../../../scripts. Both are run from the repo root, as the pool runs a fixture.
# This receipt never invokes pre-push or the fixture suite.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)" || exit 9
ROOT="$(cd "$HERE/../../.." && pwd)" || exit 9
RUN="$ROOT/core/fixtures/decl-reasons/run.sh"
VAL="$ROOT/scripts/validate-decl-reasons.sh"
[ -f "$RUN" ] && [ -f "$VAL" ] || { echo "receipt: decl-reasons run.sh or its subject is absent under $ROOT" >&2; exit 9; }

W="$(mktemp -d "${TMPDIR:-/tmp}/bl849-receipt.XXXXXX")" || exit 9
for t in forced unforced; do
  mkdir -p "$W/$t/core/fixtures/decl-reasons" "$W/$t/scripts" || exit 9
  cp "$RUN" "$W/$t/core/fixtures/decl-reasons/run.sh" || exit 9
  cp "$VAL" "$W/$t/scripts/validate-decl-reasons.sh" || exit 9
done
FV="$W/forced/scripts/validate-decl-reasons.sh"
sed 's/^self_probe || exit 2$/self_probe  || exit 2/' "$VAL" > "$FV" || exit 9
if cmp -s "$VAL" "$FV"; then echo "receipt: the forcing edit did not apply (no bytes changed)" >&2; exit 9; fi

cd "$ROOT" || exit 9
FOUT="$(AI_DLC_VERDICT_STORE="$W/store" bash "$W/forced/core/fixtures/decl-reasons/run.sh" 2>&1)"; FRC=$?
UOUT="$(AI_DLC_VERDICT_STORE="$W/store" bash "$W/unforced/core/fixtures/decl-reasons/run.sh" 2>&1)"; URC=$?

# The unforced control must be a real PASS, or the forced verdict means nothing.
if [ "$URC" -ne 0 ] || ! grep -qF 'decl-reasons: PASS' <<<"$UOUT"; then
  echo "receipt: the unforced copy did not PASS (rc=$URC), so the forced run proves nothing"; exit 1
fi
if [ "$FRC" -eq 0 ]; then
  echo "receipt: STILL LIVE -- the forced copy exited 0 although a mutant DID NOT APPLY"; exit 1
fi
# A FAIL line, not just the text: the helper prints DID NOT APPLY to stderr whatever its caller does, and the
# forced copy exits non-zero through unrelated arms, so only a counted FAIL line shows the caller reported it.
if ! grep -qiE '^  FAIL  .*did not apply' <<<"$FOUT"; then
  echo "receipt: the forced copy exited $FRC but printed no FAIL line for the mutant that did not apply -- STILL LIVE: the failure text of a mutant that did not apply is lost in a subshell"; exit 1
fi
echo "receipt: ok -- forced rc=$FRC with a FAIL line for the unapplied mutant; unforced rc=0 PASS"
exit 0
