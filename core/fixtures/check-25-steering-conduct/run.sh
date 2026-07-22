#!/usr/bin/env bash
#
# Exercise validate-steering-budget.sh against the check-25 fixture.
#
# Check 25 does not ask the validator's own question ("any violations?"). It asks
# "how many, versus last gate?" -- so this fixture asserts the INTEGER that
# `--count` returns, not merely the exit status. A check-25 that only asserted
# PASS/FAIL would pass with a broken count, and the count is the whole mechanism.
#
# The decoy that decides shippability is `backgrounded`: it must return 0. A naive
# "any long call is starvation" implementation fails it, and would flag the exact
# background-dispatch shape Rule 29 prescribes -- an unpassable check, and an
# unpassable check gets turned off.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

VALIDATOR=""
for cand in \
  "$DIR/../../scripts/validate-steering-budget.sh" \
  "$DIR/../../../scripts/ai-dlc/validate-steering-budget.sh" \
  "$DIR/../../core/scripts/validate-steering-budget.sh"; do
  [ -f "$cand" ] && VALIDATOR="$cand" && break
done
if [ -z "$VALIDATOR" ]; then
  echo "FAIL: cannot locate validate-steering-budget.sh from $DIR"
  exit 1
fi

command -v node >/dev/null 2>&1 || { echo "SKIP: node is required for check-25"; exit 0; }

ROOT="$(bash "$DIR/seed.sh" | tail -1)"
trap 'rm -rf "$ROOT"' EXIT

FAILURES=0

expect_count() { # $1 case-dir  $2 expected count  $3 why
  local got
  got="$(bash "$VALIDATOR" --transcript "$ROOT/$1/session.jsonl" --count 2>/dev/null)"
  if [ "$got" != "$2" ]; then
    echo "FAIL [$1]: --count returned '$got', expected '$2' -- $3"
    FAILURES=$((FAILURES + 1))
  else
    echo "ok   [$1]: count=$got  ($3)"
  fi
}

expect_status() { # $1 case-dir  $2 expected exit  $3 why
  bash "$VALIDATOR" --transcript "$ROOT/$1/session.jsonl" --quiet >/dev/null 2>&1
  local rc=$?
  if [ "$rc" != "$2" ]; then
    echo "FAIL [$1]: exit $rc, expected $2 -- $3"
    FAILURES=$((FAILURES + 1))
  else
    echo "ok   [$1]: exit=$rc  ($3)"
  fi
}

expect_count starves      1 "an unbounded foreground poll loop is one Check A starvation"
expect_count clean        0 "a bounded beat through wait-for-deliverable.sh starves nobody"
expect_count backgrounded 0 "DECOY: run_in_background yields a tool boundary at once -- not starvation"

expect_status starves      1 "the validator itself must still FAIL on the starving session"
expect_status clean        0 "and PASS on the clean one"
expect_status backgrounded 0 "and PASS on the backgrounded decoy"

# --count must be a pure integer on stdout and exit 0 even when violations exist --
# Check 25 reads it directly, and a `cmd | grep` would take grep's exit status.
raw="$(bash "$VALIDATOR" --transcript "$ROOT/starves/session.jsonl" --count 2>/dev/null; echo "rc=$?")"
case "$raw" in
  "1"*"rc=0") echo "ok   [contract]: --count prints a bare integer and exits 0 despite violations" ;;
  *) echo "FAIL [contract]: --count must print a bare integer and exit 0; got: $raw"
     FAILURES=$((FAILURES + 1)) ;;
esac

if [ "$FAILURES" -eq 0 ]; then
  echo "PASS: check-25 steering-conduct fixture holds (3 cases + count contract)."
  exit 0
fi
echo "FAIL: $FAILURES check-25 assertion(s) failed."
exit 1
