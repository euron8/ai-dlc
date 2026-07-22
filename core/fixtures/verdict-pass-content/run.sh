#!/usr/bin/env bash
# verdict-pass-content — assert verdict.sh's PASS line carries evidence of a run.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# verdict.sh used to print exactly `PASS  <validator>` on success -- content-free,
# and therefore derivable from the command alone. gate-validation.md Check 14 asks
# the lead to "paste the validator's verdict line verbatim" into the gate log, and
# Check 15 rejects a cell that is `-` or "a restatement like 'budget OK'". Both
# were satisfiable by a string transcribed straight out of the instruction.
#
# Measured in the reference consumer at gate `story-20260722T014002Z`, the Check 14
# evidence cell read:
#
#     Budget validator: `PASS  validate-artifact-budget.sh` (exit 0).
#
# The snapshot it names measured 126% of budget at the commit before that gate and
# 212% at the commit after. The validator exits 1 at both, and at every commit
# between them. Every check that passed honestly at that same gate cited
# run-specific content -- `36 manifest ids / 36 anchors`, `digest=e1254177c37c8e23`,
# `1 block(s)`. Check 14's was the only requirement satisfiable without the run.
#
# The fix: surface the validator's own measurement line on PASS, the way failing
# lines are already surfaced on FAIL. Assertion 4 is the control -- it strips the
# new branch from a copy and demands the PASS line go back to being content-free.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

# Two layouts, both derived from install.sh's mapping -- NOT guessed. install.sh
# maps `core/scripts/<x>` to `scripts/<x>` at the project root.
if [ -n "$ROOT" ] && [ -f "$ROOT/core/scripts/verdict.sh" ]; then
  SCRIPTS="$ROOT/core/scripts"
elif [ -n "$ROOT" ] && [ -f "$ROOT/scripts/ai-dlc/verdict.sh" ]; then
  SCRIPTS="$ROOT/scripts"
else
  echo "FIXTURE ERROR: verdict.sh not found in either layout" >&2
  echo "  looked in: $ROOT/core/scripts/ (distribution), $ROOT/scripts/ (consumer)" >&2
  exit 2
fi
VERDICT="$SCRIPTS/verdict.sh"
VALIDATOR="$SCRIPTS/validate-artifact-budget.sh"
[ -f "$VALIDATOR" ] || { echo "FIXTURE ERROR: validate-artifact-budget.sh missing" >&2; exit 2; }

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/_bmad-output" || exit 2

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# A snapshot small enough to pass the byte budget with room to spare. The PASS
# path is what this fixture measures, so every run below must actually pass.
{ printf '# Pipeline Snapshot\n\n'
  printf '## Pipeline Position\n- variant: carry-over\n\n'
  printf '## Sprint Context\n- sprint_id: 296\n\n'
  printf '## Recent Activity\n1. routed\n\n'
  printf '## Open Items\nnone\n\n'
  printf '## Locked Decisions\nnone\n\n'
  printf '## In-Flight Teammates\nnone\n\n'
  printf '## Context Reminders\n- context_reminders_sent: none\n\n'
} > "$WORK/_bmad-output/pipeline-snapshot.md"

run_verdict() { # run_verdict [verdict-script]
  local v="${1:-$VERDICT}"
  bash "$v" "$VALIDATOR" --root "$WORK" --only pipeline-snapshot.md \
    >"$WORK/out.txt" 2>&1
  echo "$?"
}

echo "verdict-pass-content"

# --- 1. A passing run still exits 0 and still says PASS ------------------------
# The floor. Whatever else changes, callers read this line as the verdict.
status="$(run_verdict)"
if [ "$status" = "0" ] && grep -q '^PASS  validate-artifact-budget.sh' "$WORK/out.txt"; then
  ok "a passing run exits 0 and prints the PASS verdict line"
else
  bad "exit $status / PASS line missing -- every caller reads this as the verdict"
fi

# --- 2. THE PASS OUTPUT CARRIES THE MEASUREMENT --------------------------------
# The assertion that matters. A token count cannot be transcribed out of the
# instruction; it exists only because the validator ran and measured a file.
if grep -qE '[0-9]+[[:space:]]+tok' "$WORK/out.txt"; then
  ok "  and it carries a token measurement (a number the instruction cannot supply)"
else
  bad "  PASS output carries no measurement -- the cell is forgeable again"
  sed 's/^/        /' "$WORK/out.txt"
fi

# --- 3. SILENCE IS STILL A PASS ------------------------------------------------
# A validator that prints nothing matchable -- or nothing at all -- still passed.
# Rendering that as an error, or as empty output, would break callers that have
# nothing to do with the budget. The measurement lines are additive, not required.
cat > "$WORK/silent.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
bash "$VERDICT" "$WORK/silent.sh" >"$WORK/silent-out.txt" 2>&1
silent_status=$?
if [ "$silent_status" = "0" ] && grep -q '^PASS  silent.sh' "$WORK/silent-out.txt"; then
  ok "a validator that prints nothing still renders as PASS, exit 0"
else
  bad "a silent validator rendered as exit $silent_status -- a quiet PASS became an error"
  sed 's/^/        /' "$WORK/silent-out.txt"
fi

# --- 4. THE MUTATION TEST — prove assertion 2 measures the new code ------------
# Strip the PASS-content branch from a COPY and demand assertion 2 go green (that
# is: the measurement disappears). If the number survives the mutation, something
# else was printing it and assertion 2 proves nothing.
MUTANT="$WORK/mutant.sh"
sed '/^    ok_hits=/d; /\[ -z "\$ok_hits" \]/d' "$VERDICT" > "$MUTANT" || exit 2
if cmp -s "$VERDICT" "$MUTANT"; then
  echo "FIXTURE ERROR: mutation matched nothing -- the PASS branch was renamed" >&2
  echo "  update the sed patterns in assertion 4 to match the real code" >&2
  exit 2
fi
mutant_status="$(run_verdict "$MUTANT")"
if [ "$mutant_status" != "0" ]; then
  bad "MUTATION: the mutant does not even pass (exit $mutant_status) -- fixture is confounded"
elif grep -qE '[0-9]+[[:space:]]+tok' "$WORK/out.txt"; then
  bad "MUTATION: the measurement survives without the PASS branch -- assertion 2 proves nothing"
else
  ok "MUTATION: removing the PASS-content branch removes the measurement"
fi

# --- 5. FAIL still surfaces the failing lines ----------------------------------
# The PASS branch sits directly above the FAIL branch. A regression that captured
# both would leave a failing gate with no reason attached, which is worse than the
# defect this change fixes.
head -c 40000 /dev/zero | tr '\0' 'x' >> "$WORK/_bmad-output/pipeline-snapshot.md"
fail_status="$(run_verdict)"
if [ "$fail_status" = "1" ] && grep -q '^FAIL  validate-artifact-budget.sh' "$WORK/out.txt" \
   && grep -q 'OVER ' "$WORK/out.txt"; then
  ok "a failing run still exits 1 and still surfaces its failing lines"
else
  bad "exit $fail_status / FAIL detail missing -- the FAIL branch regressed"
fi

echo ""
if [ "$fails" -eq 0 ]; then
  echo "verdict-pass-content: PASS"
  exit 0
fi
echo "verdict-pass-content: FAIL ($fails assertion(s))"
exit 1
