#!/usr/bin/env bash
# Exercise validate-draft-stamps.sh against the check-23 fixture.
#
# Builds four throwaway project trees under a temp dir and asserts the validator
# distinguishes them. Exit 0 iff all four verdicts are correct.
#
#   bad-disk    an UNSTAMPED draft in planning-artifacts        -> must FAIL
#   bad-layer   a step-domain extension restating the unstamped
#               Section 0 write path (the real graph consumer's
#               carry-over-evaluation-domain.md shape)          -> must FAIL
#   good        stamped draft + stamped layer                   -> must PASS
#   decoy       a step file naming the STEP `carry-over-evaluation.md`
#               in a routing table, plus the one-shot onboarding
#               artifacts that are deliberately out of scope     -> must PASS
#
# The decoy case is the one that decides whether the script is shippable: a
# naive basename grep flags every step file (each step's own filename collides
# with its artifact's) and every out-of-scope onboarding artifact. The validator
# must anchor on the `_bmad-output/planning-artifacts/` path prefix.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

VALIDATOR=""
for cand in \
  "$DIR/../../scripts/validate-draft-stamps.sh" \
  "$DIR/../../../scripts/ai-dlc/validate-draft-stamps.sh" \
  "$DIR/../../core/scripts/validate-draft-stamps.sh"; do
  [ -f "$cand" ] && VALIDATOR="$cand" && break
done
if [ -z "$VALIDATOR" ]; then
  echo "run.sh: could not locate validate-draft-stamps.sh" >&2
  exit 2
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

"$DIR/seed.sh" "$TMP" || { echo "run.sh: seed failed" >&2; exit 2; }

rc=0

expect_fail() {
  if "$VALIDATOR" "$TMP/$1" >/dev/null 2>&1; then
    echo "FAIL: $1 should have been rejected but passed" >&2
    rc=1
  else
    echo "ok: $1 rejected"
  fi
}

expect_pass() {
  if "$VALIDATOR" "$TMP/$1" >/dev/null 2>&1; then
    echo "ok: $1 accepted"
  else
    echo "FAIL: $1 should have passed but was rejected" >&2
    "$VALIDATOR" "$TMP/$1" 2>&1 | sed 's/^/    /' >&2
    rc=1
  fi
}

expect_fail bad-disk
expect_fail bad-layer
expect_pass good
expect_pass decoy

[ "$rc" -eq 0 ] && echo "check-23 fixture: PASS"
exit "$rc"
