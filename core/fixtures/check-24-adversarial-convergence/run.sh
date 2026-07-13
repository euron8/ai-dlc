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

# --- backward compatibility (pre-v0.52.0 artifacts: no prior_scope field) -----
# These five seed NO findings_critical_prior_scope. Their verdicts are unchanged by
# v0.52.0, and that is the point: absent field => prior := crit => the old predicate,
# exactly. `divergent` is the one that proves the default is FAIL-CLOSED -- a missing
# field must not become a way to dodge a hard block.
expect converged           0 "clean terminal pass -- the cycle the machinery should produce"
expect nitpicks-remain     0 "THE DECOY: 0C/0M with 5 MINOR open is 'only nitpicks remain' -- MET"
expect refused-to-converge 1 "S289 pass-4 shape: clean residue, still stamps NOT_MET"
expect divergent           1 "no field, CRITICALs 3 -> 6, no DHB: the default is FAIL-CLOSED"
expect no-verdict          1 "a pass with no verdict: key is un-adjudicable"

echo
# --- v0.52.0: the scope-relative predicate ------------------------------------
# scope-grew-converges is THE RELEASE. Against the pre-v0.52.0 validator it FAILS (C)
# -- that is the false hard block, and it is S290's p6 -> p7 shape, which cost the
# operator a real adjudication. If this case ever goes red, the fix is gone.
expect scope-grew-converges   0 "RELEASE: CRIT rise 2->3 but only 1 in prior scope -- NOT divergence"
expect repair-injected        1 "3 of 3 CRIT in PRIOR scope: real divergence still caught (S289 3->4->7)"
expect scope-grew-unconverged 1 "S290's shape: never converges on a moving artifact -- FAIL (D)"

# Check D must fail for the RIGHT REASON. A FAIL with the old "run another pass"
# advice is the bug being fixed -- it is what produced S290's passes 2 through 8 --
# so assert the remedy string, not merely the exit code.
out="$(bash "$VALIDATOR" --series "$ROOT/scope-grew-unconverged/s1-adversarial-pass" 2>&1)"
if printf '%s' "$out" | grep -q "MOVING ARTIFACT" && printf '%s' "$out" | grep -q "CUT the added scope"; then
  printf '  ok    %-22s Check D names the real remedy (freeze + cut the added scope)\n' "remedy-text"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s Check D failed, but did NOT name the moving artifact or the cut.\n' "remedy-text"
  printf '        A FAIL for the wrong reason is the defect this release exists to fix.\n'
fi

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "FAIL: $FAILURES of 9 assertions wrong."
  exit 1
fi
echo "PASS: all 8 cases + the Check D remedy text correct."
exit 0
