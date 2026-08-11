#!/usr/bin/env bash
# gate-adjudication/run.sh — the 3-step proof of validate-gate-adjudication.sh's fail-closed
# contract, plus the DERIVATION assertion.
#
# THE DEFECT THIS EXISTS TO CATCH. The gate-adjudication verdict is the ONE deliverable through
# which a cheaper-model lead adopts the read-and-compare judgment checks. If the validator that
# reads it can be fooled — a missing check that reads as covered, a stale verdict that reads as
# fresh, a bad map value that silently empties the escalated set, an absent file that reads as a
# pass — then a judgment check is adjudicated by no one, which reads EXACTLY like a check that
# passed. This proves each of those blocks.
#
# Structure mirrors the fixture discipline used across this suite:
#   (a) a COMPLETE, all-PASS verdict passes (exit 0) — the sanity baseline;
#   (b) each corruption fails with the RIGHT code (1 = defect, 2 = derivation/absent);
#   (c) restoring passes again (exit 0);
#   and --expected prints EXACTLY the derived set (no hand-list can drift from the map).
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

run() { # run <verdict_path> -> sets RC to the validator's exit code
  AI_DLC_ENFORCEMENT_MAP="$MAP" AI_DLC_VERDICT_SCHEMA="$SCHEMA" \
    bash "$VALIDATOR" "$GATE_TYPE" "$1" >/dev/null 2>&1
  RC=$?
}

# Rebuild the pristine verdict from the seed's canonical copy before each mutation, so the
# assertions are independent.
PRISTINE="$WORK/pristine.verdict.json"
cp "$VERDICT" "$PRISTINE"
restore() { cp "$PRISTINE" "$VERDICT"; }

py_edit() { # py_edit <code> — mutate $VERDICT in place with a python snippet over `doc`
  python3 - "$VERDICT" "$1" <<'PY'
import json, sys
path, code = sys.argv[1], sys.argv[2]
doc = json.load(open(path))
exec(code)
open(path, "w").write(json.dumps(doc, indent=2) + "\n")
PY
}

echo "gate-adjudication:"

# --- Assertion 0: SANITY (step a) --------------------------------------------
# A complete, all-PASS verdict must PASS. If it does not, every negative below is a false pass.
run "$VERDICT"
if [ "$RC" -eq 0 ]; then
  ok "complete all-PASS verdict → exit 0 (the negatives below mean something)"
else
  bad "FIXTURE BROKEN — pristine all-PASS verdict did not pass (rc=$RC). Every assertion below would be a false pass."
  echo; echo "gate-adjudication: FIXTURE BROKEN" >&2; exit 2
fi

# --- Assertion 1: DERIVATION --------------------------------------------------
# --expected must print EXACTLY the verdict's covered set. A hand-maintained escalation list is
# the exact bug this design removes; assert the two derivations agree.
EXP="$(AI_DLC_ENFORCEMENT_MAP="$MAP" AI_DLC_VERDICT_SCHEMA="$SCHEMA" bash "$VALIDATOR" --expected "$GATE_TYPE" | sort)"
COV="$(python3 -c 'import json,sys; print("\n".join(sorted(v["check_id"] for v in json.load(open(sys.argv[1]))["verdicts"])))' "$VERDICT")"
if [ "$EXP" = "$COV" ]; then
  ok "--expected $GATE_TYPE prints exactly the covered set ($(printf '%s' "$EXP" | tr '\n' ' '))"
else
  bad "--expected does NOT match the verdict's covered set — derivation drift"
fi

# --- Assertion 2: MISSING ESCALATED ID (step b) → exit 1 ---------------------
restore
py_edit 'doc["verdicts"] = doc["verdicts"][:-1]'   # drop one escalated check
run "$VERDICT"
[ "$RC" -eq 1 ] && ok "deleting an escalated entry → exit 1" || bad "a missing escalated check did NOT fail with exit 1 (rc=$RC) — an unadjudicated check reads as clean"

# --- Assertion 3: EMPTY EVIDENCE (step b) → exit 1 ---------------------------
restore
py_edit 'doc["verdicts"][0]["evidence"] = ""'
run "$VERDICT"
[ "$RC" -eq 1 ] && ok "blanking an evidence → exit 1" || bad "empty evidence did NOT fail with exit 1 (rc=$RC) — an unjustified PASS survived"

# --- Assertion 4: BAD VERDICT ENUM (step b) → exit 1 -------------------------
restore
py_edit 'doc["verdicts"][0]["verdict"] = "MAYBE"'
run "$VERDICT"
[ "$RC" -eq 1 ] && ok "verdict:MAYBE → exit 1" || bad "a third verdict value did NOT fail with exit 1 (rc=$RC)"

# --- Assertion 5: MAP ADJUDICATION TYPO (step b) → exit 2 --------------------
# A typo like 'lmm' is a hole in the derivation, not a fourth class. The honest failure is at the
# derivation layer (exit 2), BEFORE any verdict is trusted — else the escalated set silently
# shrinks and a real judgment check is escalated to no one.
restore
BADMAP="$WORK/enforcement-map.bad.yaml"
awk 'BEGIN{d=0} /^    adjudication: llm$/ && !d {sub(/llm/,"lmm"); d=1} {print}' "$MAP" > "$BADMAP"
if ! grep -q 'adjudication: lmm' "$BADMAP"; then
  bad "FIXTURE STALE: no 'adjudication: llm' line to corrupt in the map"
else
  AI_DLC_ENFORCEMENT_MAP="$BADMAP" AI_DLC_VERDICT_SCHEMA="$SCHEMA" bash "$VALIDATOR" "$GATE_TYPE" "$VERDICT" >/dev/null 2>&1
  RC=$?
  [ "$RC" -eq 2 ] && ok "an unknown map adjudication value ('lmm') → exit 2 (derivation layer)" || bad "a map typo did NOT fail with exit 2 (rc=$RC) — the escalated set could silently empty"
fi

# --- Assertion 6: ABSENT VERDICT → exit 2 ------------------------------------
restore
run "$WORK/gate-adjudication/does-not-exist.verdict.json"
[ "$RC" -eq 2 ] && ok "an absent verdict → exit 2 (non-delivery, not a clean gate)" || bad "an absent verdict did NOT fail with exit 2 (rc=$RC) — the stale/absent-reads-as-pass hole"

# --- Assertion 7: STALE VERDICT (nonce mismatch) → exit 1 --------------------
# A verdict whose gate_nonce does not match its path stem is a stale or foreign artifact.
restore
py_edit 'doc["gate_nonce"] = "implementation-20260101T000000Z"'
run "$VERDICT"
[ "$RC" -eq 1 ] && ok "a nonce that mismatches the path stem → exit 1 (freshness anchor)" || bad "a stale nonce did NOT fail with exit 1 (rc=$RC)"

# --- Assertion 8: ABSENT gate_series_id → exit 1 -----------------------------
# Without this arm the new required field is asserted by nothing here: it sits in the pristine
# dict, the restore arm passes, and a reader that never looked at it would score identically.
# The series id is what --series groups on; a verdict that omits it is invisible to the stall
# rung, and the rung's own legacy path would count it as a retained prior series rather than a
# missing pass. The per-pass gate is where that has to be caught.
restore
py_edit 'del doc["gate_series_id"]'
run "$VERDICT"
[ "$RC" -eq 1 ] && ok "deleting gate_series_id → exit 1 (the pass would be invisible to --series)" || bad "a verdict with no gate_series_id did NOT fail with exit 1 (rc=$RC) — it would drop out of the stall rung's count"

# --- Assertion 9: RESTORE (step c) → exit 0 ----------------------------------
restore
run "$VERDICT"
[ "$RC" -eq 0 ] && ok "restored verdict → exit 0" || bad "the restored pristine verdict did not pass again (rc=$RC)"

echo
if [ "$fails" -eq 0 ]; then echo "gate-adjudication: PASS"; exit 0; fi
echo "gate-adjudication: $fails assertion(s) FAILED" >&2
exit 1
