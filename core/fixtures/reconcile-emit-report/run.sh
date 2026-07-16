#!/usr/bin/env bash
# reconcile-emit-report/run.sh — prove the reconcile report's mechanical sections are driver-owned:
# emit-report.sh renders them, and --verify fails a report whose region is missing OR hand-edited.
#
# THE DEFECT THIS EXISTS TO CATCH. The report was LLM-authored; a mechanical HARD finding was silently
# dropped from it, twice. Rendering the region is only half — the LLM could still omit it or edit it.
# --verify byte-compares the report's region against a fresh render, so neither omission nor a
# dropped-blocker edit survives.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

verify() { bash "$EMIT" --verify "$1" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" >/dev/null 2>&1; RC=$?; }

echo "reconcile-emit-report:"

# --- Assertion 0: SANITY — the rendered region carries the HARD blocker -------
if grep -q "reconcile-mechanical" "$REGION" && grep -q "HARD-UNREGISTERED-CORE-DRIFT" "$REGION" && grep -q "thing.json" "$REGION"; then
  ok "the driver renders a mechanical region carrying the HARD schema blocker"
else
  bad "FIXTURE BROKEN — the rendered region lacks the HARD blocker; negatives below are meaningless"
  echo; echo "reconcile-emit-report: FIXTURE BROKEN" >&2; exit 2
fi

# --- Assertion 1: --verify PASSES a report carrying the region verbatim -------
verify "$REPORT_GOOD"
[ "$RC" -eq 0 ] && ok "--verify PASSES a report whose region matches the driver (exit 0)" \
  || bad "--verify failed a correct report (rc=$RC) — false positive"

# --- Assertion 2: --verify FAILS a report with NO region (the narrated bug) ---
verify "$REPORT_MISSING"
[ "$RC" -eq 1 ] && ok "--verify FAILS a report with no rendered region (exit 1)" \
  || bad "--verify did NOT fail a report missing the region (rc=$RC) — a narrated report could drop everything"

# --- Assertion 3: --verify FAILS a region hand-edited to DROP the blocker ------
verify "$REPORT_STALE"
[ "$RC" -eq 1 ] && ok "--verify FAILS a region hand-edited to drop the HARD blocker (exit 1) — an edited render cannot hide a finding" \
  || bad "--verify did NOT catch a dropped-blocker edit (rc=$RC) — the region could still be doctored"

echo
if [ "$fails" -eq 0 ]; then echo "reconcile-emit-report: PASS"; exit 0; fi
echo "reconcile-emit-report: $fails assertion(s) FAILED" >&2
exit 1
