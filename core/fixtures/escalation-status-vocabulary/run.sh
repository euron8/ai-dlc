#!/usr/bin/env bash
# escalation-status-vocabulary/run.sh — prove the vocabulary check fires, and that its
# vocabulary is DERIVED.
#
# THE DEFECT. gate-validation.md Check 2 branches on HARD_BLOCK / DECIDED_AUTONOMOUSLY /
# DEFERRAL_REQUEST and has no else. An entry on a fourth token satisfies no branch: Check 2
# does not block on it, does not surface it, and does not record it. It is silently skipped,
# and the gate reports Check 2 as passing. The failure is not a wrong verdict — it is an
# entry no verdict was ever computed for, which is a green indistinguishable from having
# examined nothing.
#
# Measured on the reference consumer: 8 entries on FILED and OPEN, accumulated across the
# sprints they were written in, every gate in that window reporting Check 2 as passing.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "escalation-status-vocabulary:"

# --- Assertion 1: POSITIVE CONTROL — the published set passes ----------------
# Without this, every assertion below is satisfied by a validator that reds on everything.
if bash "$VALIDATOR" "$CLEAN" "$SPEC_SRC" >/dev/null 2>&1; then
  ok "positive control: every token the spec publishes passes"
else
  bad "the check reds on entries using only the published set — it would fail every gate: $(bash "$VALIDATOR" "$CLEAN" "$SPEC_SRC" 2>&1 | grep FAIL | head -1)"
fi

# --- Assertion 2: THE DEFECT — out-of-vocabulary tokens FAIL -----------------
OUT="$(bash "$VALIDATOR" "$DRIFT" "$SPEC_SRC" 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && grep -q "FILED" <<<"$OUT" && grep -q "OPEN" <<<"$OUT"; then
  ok "drifted entries FAIL (rc=1) and both offending tokens are named"
else
  bad "out-of-vocabulary entries did not fail as expected (rc=$rc): $(printf '%s' "$OUT" | head -2 | tr '\n' ' ')"
fi

# --- Assertion 3: the count is exact, not approximate ------------------------
# 3 entries, 2 of them bad. A validator that reports "some" rather than which is not
# actionable, and one that over-counts is a validator nobody will keep enabled.
if grep -q "FAIL: 2 of 3 escalation entries" <<<"$OUT"; then
  ok "reports exactly 2 of 3 entries out of vocabulary"
else
  bad "wrong count: $(printf '%s\n' "$OUT" | grep 'of .* escalation entries' | head -1)"
fi

# --- Assertion 4: a Status field NOT at line start is still caught ------------
# The naive validator anyone writes first anchors `**Status:**` to line start. Check 2 has
# no such blind spot — it reads the entry — so a mid-entry token is just as silently
# skipped, and a checker that misses it reports a green it did not earn.
if ! bash "$VALIDATOR" "$MIDENTRY" "$SPEC_SRC" >/dev/null 2>&1; then
  ok "a mid-entry **Status:** token outside the set is caught (not only line-anchored ones)"
else
  bad "a mid-entry out-of-vocabulary token passed — the check has the line-anchored blind spot"
fi

# --- Assertion 5: THE DESIGN CLAIM — the set is DERIVED, not restated ---------
# This is the assertion that distinguishes this validator from the hand-listed copy it
# replaces. Add FILED to escalations.md's terminal-status line and the SAME drifted file
# must now pass. If it still fails, the script is carrying its own private set and the
# derivation is decoration.
SPEC_MUT="$WORK/escalations-mutant.md"
# APPEND to whatever the line publishes; do not restate its current contents. This
# anchor used to carry the literal `RESOLVED | OVERRIDDEN`, which made the fixture go
# STALE the moment a token was added to the published set — a hand-listed copy of the
# very set this fixture exists to prove is DERIVED. Insert before the closing backtick
# instead, so the mutant widens the vocabulary whatever it currently holds.
sed 's/^\(\*\*Terminal statuses\*\*.*\)`$/\1 | FILED | OPEN`/' \
  "$SPEC_SRC" > "$SPEC_MUT"
if ! grep -q 'FILED | OPEN' "$SPEC_MUT"; then
  bad "FIXTURE STALE: could not extend the terminal-status line — escalations.md's '**Terminal statuses**' line was reworded"
elif bash "$VALIDATOR" "$DRIFT" "$SPEC_MUT" >/dev/null 2>&1; then
  ok "widening escalations.md's published set makes the same entries pass — the vocabulary is read, not restated"
else
  bad "the drifted file STILL fails after escalations.md was widened — the script carries a private set and 'derived' is decoration"
fi

# --- Assertion 6: MUTANT — narrowing the source must break the clean file -----
# The other direction. If the derivation ignored the format block, the clean file would
# pass no matter what that line says.
SPEC_NARROW="$WORK/escalations-narrow.md"
sed 's/^\*\*Status:\*\* HARD_BLOCK.*/**Status:** HARD_BLOCK/' "$SPEC_SRC" > "$SPEC_NARROW"
if ! grep -qx '\*\*Status:\*\* HARD_BLOCK' "$SPEC_NARROW"; then
  bad "FIXTURE STALE: could not narrow the entry-format Status line — escalations.md's format block was reworded"
elif ! bash "$VALIDATOR" "$CLEAN" "$SPEC_NARROW" >/dev/null 2>&1; then
  ok "narrowing the format block's Status line reds the clean file — BOTH source lines are read"
else
  bad "the clean file still passes with DECIDED_AUTONOMOUSLY/DEFERRAL_REQUEST removed from the source — the format block is not being read"
fi

# --- Assertion 7: unreadable vocabulary source REFUSES, never passes ----------
# A validator that falls back to a built-in set when it cannot read escalations.md has
# reintroduced the hand-listed copy silently. Exit 2 (refusal), not 0 (clean).
LONE="$WORK/lone"; mkdir -p "$LONE"
cp "$VALIDATOR" "$LONE/validate-escalation-status-vocabulary.sh"
LONE_OUT="$(cd "$LONE" && CLAUDE_PROJECT_DIR="$LONE" bash ./validate-escalation-status-vocabulary.sh "$DRIFT" 2>&1)"
lone_rc=$?
if [ "$lone_rc" -eq 2 ] && grep -q "will not guess" <<<"$LONE_OUT"; then
  ok "with escalations.md unreachable the check REFUSES (rc=2) instead of passing"
else
  bad "severed from its vocabulary source the check returned rc=$lone_rc — it guessed a built-in set or reported clean"
fi

echo
if [ "$fails" -eq 0 ]; then echo "escalation-status-vocabulary: PASS"; exit 0; fi
echo "escalation-status-vocabulary: $fails assertion(s) FAILED" >&2
exit 1
