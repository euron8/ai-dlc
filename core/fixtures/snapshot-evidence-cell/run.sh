#!/usr/bin/env bash
# snapshot-evidence-cell — assert Check 15 can refuse a Check 14 row that was
# written without running the budget check.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# Check 14 runs the budget check and writes its own result into the gate log.
# Check 15 exists to verify that Check 14's assertion took effect. For every other
# part of Check 14 that verification reads the snapshot; for the budget there was
# nothing to read but the same self-report, so the loop closed on itself.
#
# It failed exactly that way in the reference consumer. v0.118.0 found 12
# consecutive Check 14 rows whose evidence cell read `-`, and required the verdict
# line be pasted instead. At gate `story-20260722T014002Z` the cell then read:
#
#     Budget validator: `PASS  validate-artifact-budget.sh` (exit 0).
#
# -- not empty, and not a "budget OK" paraphrase of the kind Check 15 already
# rejected. It was the validator's real PASS format, which at the time carried no
# run-specific content. The snapshot it named measured 126% of budget at the commit
# before that gate and 212% at the commit after; the validator exits 1 at both.
#
# Assertion 3 uses that literal string. Assertion 6 is the control.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

if [ -n "$ROOT" ] && [ -f "$ROOT/core/scripts/validate-artifact-budget.sh" ]; then
  VALIDATOR="$ROOT/core/scripts/validate-artifact-budget.sh"
elif [ -n "$ROOT" ] && [ -f "$ROOT/scripts/ai-dlc/validate-artifact-budget.sh" ]; then
  VALIDATOR="$ROOT/scripts/ai-dlc/validate-artifact-budget.sh"
else
  echo "FIXTURE ERROR: validate-artifact-budget.sh not found in either layout" >&2
  echo "  looked in: $ROOT/core/scripts/ (distribution), $ROOT/scripts/ (consumer)" >&2
  exit 2
fi

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT
# The consumer keeps its gate log one directory down, under
# _bmad-output/implementation-artifacts/. Seed it there rather than at the top, so
# the arm's own discovery is exercised and not bypassed.
mkdir -p "$WORK/_bmad-output/implementation-artifacts" || exit 2
GATELOG="$WORK/_bmad-output/implementation-artifacts/gate-log.md"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# Seed a gate log whose LAST Check 14 row is the argument. The preceding rows are
# deliberately older-format `-` cells: gate logs are append-only and hold years of
# rows written under earlier rules, and indicting them retroactively would make
# this arm unpassable on any real consumer.
seed() { # seed <last-check-14-row>
  { printf '## Gate [planning] 2026-07-01\n\n'
    printf '| Check | Verdict | Evidence |\n|---|---|---|\n'
    printf '| [core] 14 — Update pipeline snapshot | done after this entry | — |\n'
    printf '| [core] 15 — Verify snapshot reflects gate | done after Check 14 | — |\n\n'
    printf '## Gate [story] 2026-07-22\n\n'
    printf '| Check | Verdict | Evidence |\n|---|---|---|\n'
    printf '%s\n' "$1"
  } > "$GATELOG"
}

run_arm() {
  bash "$VALIDATOR" --root "$WORK" --check-evidence >"$WORK/out.txt" 2>&1
  echo "$?"
}

expect() { # expect <want-status> <label>
  local got; got="$(run_arm)"
  [ "$got" = "$1" ] && ok "$2" || { bad "$2 -- expected exit $1, got $got"; sed 's/^/        /' "$WORK/out.txt"; }
}

echo "snapshot-evidence-cell"

# --- 1. A pasted verdict line with its measurement passes ----------------------
seed '| [core] 14 — Update pipeline snapshot | PASS (lead) | `PASS  validate-artifact-budget.sh` / `  ok  _bmad-output/pipeline-snapshot.md   5432 tok  (budget   6000)` |'
expect 0 "a cell carrying the measurement passes"

# --- 2. An empty cell fails ----------------------------------------------------
# The population v0.118.0 measured: 12 consecutive rows reading `-`. An empty cell
# is not a record that the check passed; it is a record that nothing was measured,
# and the two are indistinguishable afterwards.
seed '| [core] 14 — Update pipeline snapshot | done after this entry | — |'
expect 1 "an empty evidence cell fails"

# --- 3. THE CONTENT-FREE PASS STRING FAILS -------------------------------------
# The literal cell from `story-20260722T014002Z`. This is the assertion the whole
# change exists for: the string is the validator's real PASS format, it satisfies
# "paste the verdict line" and "not a restatement", and it was false.
seed '| [core] 14 — Update pipeline snapshot | PASS (lead) | `pipeline-snapshot.md` refreshed: Pipeline Position, Sprint Context unchanged. Budget validator: `PASS  validate-artifact-budget.sh` (exit 0). |'
expect 1 "the content-free PASS string fails (the S296 cell verbatim)"
if grep -q 'cites no budget measurement' "$WORK/out.txt"; then
  ok "  and the message says WHY -- no measurement, not 'over budget'"
else
  bad "  the message does not name the missing measurement"
fi

# --- 4. The short row shape is not passed vacuously ----------------------------
# Some gates append a compact per-check table (`| 14 | lead | ... |`) instead of
# the long form. Matching only the long form would let the short one through
# unmeasured -- a check that cannot fire reads exactly like one that passed.
seed '| 14 | lead | snapshot updated same gate |'
expect 1 "the compact row shape is matched, not skipped"

# --- 5. A breaching measurement cannot be laundered as PASS --------------------
# The second predicate. A row may not cite a number past the ceiling and call
# itself passing. Needs no tolerance and no file on disk -- it is a contradiction
# inside the row.
seed '| [core] 14 — Update pipeline snapshot | PASS (lead) | `OVER  _bmad-output/pipeline-snapshot.md   26,774 tok  (budget 6000)` |'
expect 1 "a PASS row citing 26,774 tok is refused"

# --- 6. THE MUTATION TEST — prove the reds come from the new arm ---------------
# Strip the arm's dispatch from a COPY. Without it the flag falls through to the
# ordinary measuring path, which has no artifacts to measure here and exits 0. If
# assertion 3's input still failed, something else was producing the red.
MUTANT="$WORK/mutant.sh"
sed 's/^if \[ "\$CHECK_EVIDENCE" -eq 1 \]; then$/if false; then/' "$VALIDATOR" > "$MUTANT" || exit 2
if cmp -s "$VALIDATOR" "$MUTANT"; then
  echo "FIXTURE ERROR: mutation matched nothing -- the arm's dispatch was renamed" >&2
  echo "  update the sed pattern in assertion 6 to match the real guard" >&2
  exit 2
fi
seed '| [core] 14 — Update pipeline snapshot | PASS (lead) | Budget validator: `PASS  validate-artifact-budget.sh` (exit 0). |'
bash "$MUTANT" --root "$WORK" --check-evidence >"$WORK/mut-out.txt" 2>&1
mutant_status=$?
if [ "$mutant_status" = "0" ]; then
  ok "MUTATION: removing the arm makes assertion 3's input go green"
else
  bad "MUTATION: assertion 3's input still fails (exit $mutant_status) without the arm -- it proves nothing"
  sed 's/^/        /' "$WORK/mut-out.txt"
fi

# --- 7. A missing gate log is an explicit failure, never a silent pass ---------
# The arm finds its own gate log. If discovery returns nothing it must say so:
# "no gate log" resolving to exit 0 is the check-that-cannot-fire, one layer down.
rm -f "$GATELOG"
missing_status="$(run_arm)"
if [ "$missing_status" = "1" ] && grep -q 'no gate-log.md found' "$WORK/out.txt"; then
  ok "a missing gate log fails loudly rather than passing silently"
else
  bad "a missing gate log exited $missing_status -- discovery failure must not read as a pass"
fi

echo ""
if [ "$fails" -eq 0 ]; then
  echo "snapshot-evidence-cell: PASS"
  exit 0
fi
echo "snapshot-evidence-cell: FAIL ($fails assertion(s))"
exit 1
