#!/usr/bin/env bash
# suppression-lifetime/run.sh — prove that an operator's permission to proceed past a
# failing check expires, and that a terminal entry cannot close a check that is still red.
#
# THE DEFECT. `RESOLVED` and `OVERRIDDEN` close a QUESTION and name no check. Measured on
# the reference consumer: a `hard_block: true` check failed at two consecutive planning
# gates and the pipeline proceeded past both on a SINGLE operator turn, each passage
# logged as "carried forward, none re-litigated".
#
# THE MECHANISM IS THE LICENCE, NOT THE RE-RUN, AND THAT WAS MEASURED. The first
# specification said the check "goes silent and nothing re-runs it". False: both affected
# checks were emitted at all three of that sprint's gates and read FAIL, FAIL, PASS. So
# assertion 3 is the one that carries the release — a suppression whose cause was fixed
# must cost NOTHING, because a check that nags after the failure is gone is the unmeasured
# lint the operator turns off.
#
# THE ASSERTIONS WHERE THE COMFORTABLE READING FAILS OPEN:
#   2. Past expiry with the check STILL failing must FAIL. If this passes, the lifetime is
#      decoration and the release delivers nothing.
#   4. A SUPPRESSED entry missing its target must be reported MALFORMED. This is the
#      delimiter regression: with an IFS-whitespace delimiter `read` collapses the empty
#      field, every later field shifts left, and malformed input scores as clean.
#   10. The metrics must be read in BOTH JSON spacings. The real corpus is 47% one form
#      and 53% the other; an extractor anchored to one reads half the file and reports
#      clean over the rest.
set -uo pipefail

# The pre-push gate inherits every AI_DLC_* tunable a consumer set in settings.json. A
# fixture that drives a validator while inheriting them tests the CONFIG, not the code.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

LAST_OUT=""
LAST_RC=""
# drive <validator> <case> <gate-metrics> [extra args...]
# Sets LAST_RC and LAST_OUT. Deliberately NOT used via `drive ...; rc="$LAST_RC"`: a command
# substitution runs in a SUBSHELL, so every global the function set is discarded and the
# message assertions grep an empty string — which passes or fails for reasons unrelated
# to the validator. That mistake is why this helper assigns instead of printing.
drive() {
  local v="$1" c="$2" gm="$3"; shift 3
  LAST_OUT="$(bash "$v" --escalations "$CASES/$c/pending.md" \
                        --gate-metrics "$gm" \
                        --enforcement-map "$MAP" "$@" 2>&1)"
  LAST_RC=$?
}

# --- Assertion 1: a suppression inside its lifetime is honoured ------------------
drive "$VALIDATOR" in-force "$GM_FAILING"; rc="$LAST_RC"
if [ "$rc" = "0" ]; then
  ok "a SUPPRESSED entry inside its lifetime does not fire (exit 0)"
else
  bad "in-force suppression FAILED (rc=$rc) — the arm has no green state and would wedge every gate"
  printf '%s\n' "$LAST_OUT" | sed 's/^/        /'
fi

# --- Assertion 2: past expiry, check still failing -> FAIL ----------------------
drive "$VALIDATOR" expired-still-failing "$GM_FAILING"; rc="$LAST_RC"
if [ "$rc" = "1" ]; then
  ok "past its lifetime with the check STILL failing, the suppression FAILS"
else
  bad "expired suppression did NOT fail (rc=$rc) — the lifetime is decoration"
fi
if grep -q 'past its lifetime' <<<"$LAST_OUT"; then
  ok "the expiry message names the lifetime as the reason"
else
  bad "the expiry FAIL did not explain itself"
fi

# --- Assertion 3: past expiry but the cause was FIXED -> silent -----------------
drive "$VALIDATOR" expired-but-fixed "$GM_FIXED"; rc="$LAST_RC"
if [ "$rc" = "0" ]; then
  ok "past its lifetime but the check now PASSes — reports nothing"
else
  bad "expired-but-fixed FAILED (rc=$rc) — the check nags after the failure is gone"
fi

# --- Assertion 4: malformed SUPPRESSED (no target) — the delimiter regression ---
drive "$VALIDATOR" malformed-no-target "$GM_FAILING"; rc="$LAST_RC"
if [ "$rc" = "1" ]; then
  ok "a SUPPRESSED entry with no **Suppresses:** is MALFORMED"
else
  bad "missing **Suppresses:** was accepted (rc=$rc) — an empty field collapsed and the later fields shifted left"
fi
if grep -q 'Suppresses' <<<"$LAST_OUT"; then
  ok "the malformed message names the missing field"
else
  bad "malformed FAIL did not name which field was missing"
fi

# --- Assertion 5: expiry outside 1..3 -------------------------------------------
drive "$VALIDATOR" expiry-out-of-range "$GM_FAILING"; rc="$LAST_RC"
if [ "$rc" = "1" ]; then
  ok "**Expires after:** outside 1..3 is rejected"
else
  bad "an out-of-range expiry was accepted (rc=$rc) — a suppression could be written to outlive anything"
fi

# --- Assertion 6: a target that is not in the catalog ---------------------------
drive "$VALIDATOR" unknown-check-id "$GM_FAILING"; rc="$LAST_RC"
if [ "$rc" = "1" ]; then
  ok "a **Suppresses:** id absent from the catalog is rejected"
else
  bad "an unknown check id was accepted (rc=$rc) — 'Check 924' is a real prose token in the corpus"
fi

# --- Assertion 7: RESOLVED closing a still-failing check ------------------------
drive "$VALIDATOR" terminal-names-failing "$GM_FAILING"; rc="$LAST_RC"
if [ "$rc" = "1" ]; then
  ok "a RESOLVED entry naming a still-failing check FAILS — the loophole is shut"
else
  bad "RESOLVED closed a still-failing check (rc=$rc) — this is the measured defect, unfixed"
fi

# --- Assertion 8: RESOLVED naming only a passing check must NOT fire ------------
drive "$VALIDATOR" terminal-names-passing "$GM_FAILING"; rc="$LAST_RC"
if [ "$rc" = "0" ]; then
  ok "a RESOLVED entry naming only a PASSING check does not fire"
else
  bad "a terminal entry naming a green check FAILED (rc=$rc) — every closed entry mentioning a check would trip"
fi

# --- Assertion 9: the zero-control ---------------------------------------------
drive "$VALIDATOR" empty "$GM_FAILING"; rc="$LAST_RC"
if [ "$rc" = "0" ] && grep -q 'entries_scanned=' <<<"$LAST_OUT"; then
  ok "a clean run reports the counts it was computed over"
else
  bad "the clean verdict carries no counts — a regex matching nothing reads like full coverage"
fi
if grep -q 'suppressed=0' <<<"$LAST_OUT"; then
  ok "the zero-control distinguishes 'no suppressions' from 'all suppressions valid'"
else
  bad "no suppressed= count in the verdict line"
fi

# --- Assertion 10: BOTH JSON spacings are read ---------------------------------
# Check 32's rows in the seed are written ONLY in the spaced form. If the extractor
# anchors to the unspaced form it cannot see check 32 at all, its verdict comes back
# empty, and assertion 2's expired-still-failing case silently passes.
drive "$VALIDATOR" expired-still-failing "$GM_FAILING"; rc="$LAST_RC"
if [ "$rc" = "1" ]; then
  ok "spaced-form metrics rows are read (check 32 is seeded spaced-only)"
else
  bad "the spaced JSON form was not read (rc=$rc) — 53% of the real corpus is invisible"
fi

# --- Assertion 11: a missing catalog is a REFUSAL, not a pass -------------------
out="$(bash "$VALIDATOR" --escalations "$CASES/expired-still-failing/pending.md" \
        --gate-metrics "$GM_FAILING" --enforcement-map "$WORK/nope.yaml" 2>&1)"; rc=$?
if [ "$rc" = "2" ]; then
  ok "an unreadable catalog exits 2 — a refusal, never a clean pass"
else
  bad "missing catalog did not refuse (rc=$rc) — it would act on prose tokens that are not checks"
fi

# --- Assertion 12: no metrics -> shape still checked, lifetime NOT-APPLICABLE ---
out="$(bash "$VALIDATOR" --escalations "$CASES/malformed-no-target/pending.md" \
        --enforcement-map "$MAP" --gate-metrics "$WORK/absent.jsonl" 2>&1)"; rc=$?
if [ "$rc" = "1" ]; then
  ok "with no metrics the SHAPE arm still fires on a malformed entry"
else
  bad "no-metrics run did not check shape (rc=$rc) — the whole script went quiet on a missing optional input"
fi

# --- Assertion 13: a baseline suppresses, and may not outlive its cause ---------
drive "$VALIDATOR" terminal-names-failing "$GM_FAILING" --baseline "$BASELINE_GOOD"; rc="$LAST_RC"
if [ "$rc" = "0" ]; then
  ok "a baselined violation is suppressed"
else
  bad "the baseline did not suppress its own entry (rc=$rc)"
fi
drive "$VALIDATOR" terminal-names-failing "$GM_FAILING" --baseline "$BASELINE_STALE"; rc="$LAST_RC"
if [ "$rc" = "1" ] && grep -q 'no longer reproduces' <<<"$LAST_OUT"; then
  ok "a baselined key that stops reproducing is itself a FAIL — the baseline cannot outlive its cause"
else
  bad "a stale baseline line was tolerated (rc=$rc) — a baseline would silently suppress a check that started passing"
fi

# ------------------------------------------------------------------------------
# MUTANTS. Copies, never in-place edits. `cmp -s` proves the mutation landed and
# `bash -n` proves the result is still a program — a copy that dies on a syntax error
# emits nothing, and "no output" otherwise scores as a kill.
# Anchors are chosen on backslash-free, grep-unique lines: `awk -v` processes escape
# sequences in the assigned value, so an anchor carrying a backslash arrives at index()
# stripped and the mutation is a silent no-op that comes out GREEN.
# ------------------------------------------------------------------------------

# The unmutated control. This validator resolves its own root by walking up for a marker;
# a lone copy in a temp dir that cannot resolve it would emit nothing, and that silence
# would score as a kill for every mutant below.
CTRL="$WORK/validator-control.sh"
cp "$VALIDATOR" "$CTRL"
drive "$CTRL" expired-still-failing "$GM_FAILING"; rc="$LAST_RC"
if [ "$rc" = "1" ]; then
  ok "UNMUTATED CONTROL reproduces the real verdict from a copy — mutant silence means mutation, not breakage"
  CONTROL_OK=1
else
  bad "UNMUTATED CONTROL did not reproduce (rc=$rc) — every mutant result below is uninterpretable"
  CONTROL_OK=0
fi

if [ "${CONTROL_OK:-0}" = "1" ]; then

  # --- MUTANT A: the metrics extractor stops tolerating whitespace --------------
  MUT_A="$WORK/mutant-a.sh"
  awk '
    index($0, "re = \"\\\"\" key \"\\\"[[:space:]]*:[[:space:]]*\\\"[^\\\"]*\\\"\"") {
      print "    re = \"\\\"\" key \"\\\":\\\"[^\\\"]*\\\"\""; next
    }
    { print }
  ' "$CTRL" > "$MUT_A"
  if cmp -s "$CTRL" "$MUT_A"; then
    bad "MUTANT A did not change the file — the anchor matched nothing and the mutant is a no-op"
  elif ! bash -n "$MUT_A" 2>/dev/null; then
    bad "MUTANT A is not a valid program — its absence would have scored as a kill"
  else
    drive "$MUT_A" expired-still-failing "$GM_FAILING"; rc="$LAST_RC"
    if [ "$rc" = "0" ]; then
      ok "MUTANT A killed — dropping whitespace tolerance blinds it to the spaced rows (assertion 10 has teeth)"
    else
      bad "MUTANT A DID NOT change the verdict (rc=$rc) — assertion 10 is not testing the spacing tolerance"
    fi
    # and it must not break the shape arm — the assertions are not entangled
    drive "$MUT_A" malformed-no-target "$GM_FAILING"; rc="$LAST_RC"
    if [ "$rc" = "1" ]; then
      ok "MUTANT A leaves the shape arm intact — assertions 4 and 10 are independent"
    else
      bad "MUTANT A ALSO broke the shape arm (rc=$rc) — the assertions are entangled and one is vacuous"
    fi
  fi

  # --- MUTANT B: the catalog join is dropped -----------------------------------
  MUT_B="$WORK/mutant-b.sh"
  awk '
    index($0, "if ! grep -qxF \"$supp\" <<<\"$CATALOG\"; then") {
      print "      if false; then"; next
    }
    { print }
  ' "$CTRL" > "$MUT_B"
  if cmp -s "$CTRL" "$MUT_B"; then
    bad "MUTANT B did not change the file — anchor matched nothing"
  elif ! bash -n "$MUT_B" 2>/dev/null; then
    bad "MUTANT B is not a valid program"
  else
    drive "$MUT_B" unknown-check-id "$GM_FAILING"; rc="$LAST_RC"
    if [ "$rc" = "0" ]; then
      ok "MUTANT B killed — without the catalog join a non-check id is accepted (assertion 6 has teeth)"
    else
      bad "MUTANT B DID NOT change the verdict (rc=$rc) — assertion 6 is not testing the catalog join"
    fi
    drive "$MUT_B" expired-still-failing "$GM_FAILING"; rc="$LAST_RC"
    if [ "$rc" = "1" ]; then
      ok "MUTANT B leaves the lifetime arm intact — assertions 2 and 6 are independent"
    else
      bad "MUTANT B ALSO broke the lifetime arm (rc=$rc) — the assertions are entangled"
    fi
  fi

  # --- MUTANT C: the record delimiter reverts to an IFS-whitespace character ----
  # This is the regression that shipped nothing but nearly did: with a tab delimiter
  # `read` collapses the run of empty fields, `named` and `supp` shift, and a malformed
  # entry parses as a well-formed one naming nothing.
  MUT_C="$WORK/mutant-c.sh"
  sed -e "s/037%s/011%s/g" -e "s/printf '\\\\037'/printf '\\\\011'/" "$CTRL" > "$MUT_C"
  if cmp -s "$CTRL" "$MUT_C"; then
    bad "MUTANT C did not change the file — anchor matched nothing"
  elif ! bash -n "$MUT_C" 2>/dev/null; then
    bad "MUTANT C is not a valid program"
  else
    drive "$MUT_C" malformed-no-target "$GM_FAILING"; rc="$LAST_RC"
    # The mutant still exits 1 here, but for the WRONG REASON: with the empty
    # **Suppresses:** field collapsed away, every later field shifts left, the expiry
    # value lands in `supp` and the timestamp in `expires`, and what the mutant reports
    # missing is **Operator authorization:** — a field the entry actually carries. An
    # rc-only assertion cannot tell those two apart, which is exactly how a collapsed
    # delimiter ships green.
    if grep -q 'Suppresses' <<<"$LAST_OUT"; then
      bad "MUTANT C DID NOT shift the fields — assertion 4 is not testing the delimiter"
    else
      ok "MUTANT C killed — an IFS-whitespace delimiter collapses the empty field and misreports which one is missing"
    fi
  fi
fi

echo
if [ "$fails" -ne 0 ]; then
  echo "suppression-lifetime: $fails assertion(s) FAILED" >&2
  exit 1
fi
echo "suppression-lifetime: all assertions passed"
