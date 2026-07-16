#!/usr/bin/env bash
# reconcile-blocking-list/run.sh — prove hard-blockers.sh renders the blocking list and its --check
# catches a report that dropped a HARD blocker.
#
# THE DEFECT THIS EXISTS TO CATCH. The dry-run report is LLM-authored from the detectors' output;
# nothing forced every HARD-* line to appear in it. On a real pull, unregistered-drift.sh flagged an
# in-place core-schema edit HARD, twice, and both reports said "no unregistered core drift" — a
# blocker the operator would approve apply without seeing, then apply overwrites the edit silently.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "reconcile-blocking-list:"

# --- Assertion 0: SANITY — print mode renders the blocker ---------------------
out="$(bash "$HB" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
if printf '%s' "$out" | grep -qF "$DRIFT_REL" && printf '%s' "$out" | grep -q "HARD-UNREGISTERED-CORE-DRIFT"; then
  ok "print mode renders the HARD blocker ($DRIFT_REL) from the detectors"
else
  bad "FIXTURE BROKEN — print mode did not render the in-place drift; negatives below are meaningless"
  echo; echo "reconcile-blocking-list: FIXTURE BROKEN" >&2; exit 2
fi

# --- Assertion 1: --check FAILS a report that OMITS the blocker (the bug) ------
bash "$HB" --check "$REPORT_BAD" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 1 ] && ok "--check FAILS (exit 1) a report that omits the blocker — the drop is caught" \
  || bad "--check did NOT fail on a report omitting the blocker (rc=$rc) — the report could still silently drop it"

# --- Assertion 2: --check PASSES a report that NAMES the blocker ---------------
bash "$HB" --check "$REPORT_GOOD" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && ok "--check PASSES (exit 0) a report that names the blocker" \
  || bad "--check failed on a report that DOES name the blocker (rc=$rc) — false positive"

# --- Assertion 3: no drift → print says 0, --check passes any report ----------
git -C "$DIST" show "$BASE:core/$DRIFT_REL" > "$CONSUMER/.claude/$DRIFT_REL"   # revert consumer edit
out="$(bash "$HB" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
if printf '%s' "$out" | grep -q "0 HARD blockers"; then
  bash "$HB" --check "$REPORT_BAD" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" >/dev/null 2>&1
  [ $? -eq 0 ] && ok "with no drift: print says '0 HARD blockers' and --check passes any report" \
    || bad "no-drift --check did not pass"
else
  bad "reverting the drift did not clear the blocker list"
fi

echo
if [ "$fails" -eq 0 ]; then echo "reconcile-blocking-list: PASS"; exit 0; fi
echo "reconcile-blocking-list: $fails assertion(s) FAILED" >&2
exit 1
