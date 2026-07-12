#!/usr/bin/env bash
# Exercise validate-adversarial-convergence.sh against the check-24 fixture.
#
# Exit 0 iff the validator returns the correct verdict on all five seeded series.
# The one that decides shippability is `nitpicks-remain`: it must PASS. A naive
# "the last pass must have zero findings" implementation fails it, and in doing so
# makes the exit condition "continue until only nitpicks remain" unreachable --
# which is the v0.46.0 defect this check exists to close, reintroduced one layer
# down.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

VALIDATOR=""
for cand in \
  "$DIR/../../scripts/validate-adversarial-convergence.sh" \
  "$DIR/../../../scripts/validate-adversarial-convergence.sh" \
  "$DIR/../../core/scripts/validate-adversarial-convergence.sh"; do
  [ -f "$cand" ] && VALIDATOR="$cand" && break
done
if [ -z "$VALIDATOR" ]; then
  echo "FAIL: cannot locate validate-adversarial-convergence.sh from $DIR"
  exit 1
fi

ROOT="$(bash "$DIR/seed.sh" | tail -1)"
trap 'rm -rf "$ROOT"' EXIT

FAILURES=0

# $1 case-dir  $2 expected exit (0|1)  $3 why
expect() {
  local case_dir="$1" want="$2" why="$3" got out
  out="$(bash "$VALIDATOR" --series "$ROOT/$case_dir/s1-adversarial-pass" 2>&1)"
  got=$?
  if [ "$got" -eq "$want" ]; then
    printf '  ok    %-22s exit=%s  (%s)\n' "$case_dir" "$got" "$why"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s exit=%s want=%s  (%s)\n' "$case_dir" "$got" "$want" "$why"
    printf '%s\n' "$out" | sed 's/^/          | /'
  fi
}

echo "check-24 adversarial-convergence fixture"
echo

expect converged           0 "clean terminal pass -- the cycle the machinery should produce"
expect nitpicks-remain     0 "THE DECOY: 0C/0M with 5 MINOR open is 'only nitpicks remain' -- MET"
expect refused-to-converge 1 "S289 pass-4 shape: clean residue, still stamps NOT_MET"
expect divergent           1 "CRITICALs 3 -> 6 with no DIVERGENT_HARD_BLOCK"
expect no-verdict          1 "a pass with no verdict: key is un-adjudicable"

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "FAIL: $FAILURES of 5 cases wrong."
  exit 1
fi
echo "PASS: all 5 cases correct."
exit 0
