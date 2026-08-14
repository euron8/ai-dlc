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
if grep -qF "$DRIFT_REL" <<<"$out" && grep -q "HARD-UNREGISTERED-CORE-DRIFT" <<<"$out"; then
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

# --- Assertion 2b: the degenerate-range qualifier reaches the rendered list -----
# `layer-drift.sh` emits DRIFT-RANGE-DEGENERATE when base and theirs are the same commit, saying
# its range-keyed adjudication arms could not fire. This wrapper's only reader was a `^HARD-`
# filter, and that status carries a deliberately non-HARD prefix — so the one caller that most
# needed the warning discarded it and printed a clean sheet instead. Filed as
# PC-S302-HARD-BLOCKERS-HAS-NO-POST-APPLY-GUARD. BASE == THEIRS in this seed, so this run IS
# degenerate; the control below is the arm that proves the line is not printed unconditionally.
out="$(bash "$HB" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
grep -q 'DRIFT-RANGE-DEGENERATE' <<<"$out" \
  && ok "a degenerate range is qualified in the rendered list, not filtered out of it" \
  || bad "print mode rendered no DRIFT-RANGE-DEGENERATE row on a run where base == theirs — the clean sheet is unqualified"

# CONTROL: a NON-degenerate range must not carry the qualifier. Without this, the arm above
# passes against a wrapper that prints the line every time, which discriminates nothing.
out_adv="$(bash "$HB" "$DIST" "$BASE" "$CONSUMER" "$THEIRS_ADV" 2>/dev/null)"
grep -q 'DRIFT-RANGE-DEGENERATE' <<<"$out_adv" \
  && bad "CONTROL: the qualifier was printed on a range whose two refs DIFFER — it fires unconditionally and says nothing" \
  || ok "CONTROL: a real base..theirs range carries no degenerate qualifier"

# --- Assertion 2c: --post-apply moves ONLY the unregistered-drift base ----------
# Post-apply, core on disk is at THEIRS. Asking unregistered-drift.sh against the PULL's base
# then reports upstream's own freshly-written text as a consumer in-place edit, whose printed
# remedy is to revert or refile it. `--post-apply` asks against theirs instead.
#
# THE SAME INVOCATION CARRIES ITS OWN CONTROL: `$DRIFT_REL` is a genuine consumer edit and must
# stay blocking under the flag. An arm that only asserted the artefact disappears would pass
# against a flag that suppressed the whole detector.
pre="$(bash "$HB" "$DIST" "$BASE" "$CONSUMER" "$THEIRS_ADV" 2>/dev/null)"
post="$(bash "$HB" --post-apply "$DIST" "$BASE" "$CONSUMER" "$THEIRS_ADV" 2>/dev/null)"
if grep -qF "$MOVED_REL" <<<"$pre" && ! grep -qF "$MOVED_REL" <<<"$post"; then
  ok "--post-apply drops the wrong-base artefact on a file the pull itself wrote"
else
  bad "the wrong-base artefact ($MOVED_REL) did not appear pre-apply or did not clear under --post-apply — the flag changes nothing, or the seed cannot express the defect"
fi
grep -qF "$DRIFT_REL" <<<"$post" \
  && ok "CONTROL: a real consumer in-place edit still blocks under --post-apply" \
  || bad "CONTROL: --post-apply suppressed a genuine HARD blocker — the flag disarms the detector instead of rebasing it"

# --- Assertion 3: no drift → print says 0, --check passes any report ----------
git -C "$DIST" show "$BASE:core/$DRIFT_REL" > "$CONSUMER/.claude/$DRIFT_REL"   # revert consumer edit
git -C "$DIST" show "$BASE:core/$MOVED_REL" > "$CONSUMER/.claude/$MOVED_REL"   # and the range-drifted one
out="$(bash "$HB" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
if grep -q "0 HARD blockers" <<<"$out"; then
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
