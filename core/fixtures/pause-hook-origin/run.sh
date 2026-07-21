#!/usr/bin/env bash
# pause-hook-origin/run.sh — prove ai-dlc-pause.sh pauses on operator prose and ONLY on
# operator prose.
#
# THE DEFECT. The hook touched the pause flag on every UserPromptSubmit with no inspection of
# the prompt at all; it read `.prompt` only for a 120-char log preview. The harness raises
# UserPromptSubmit identically when a backgrounded task completes as when a human types, so
# the hook created a pause flag for events carrying no operator prose, and the lead then
# blocked on a pause no human initiated. Five occurrences across two sprints on the reference
# consumer went undiagnosed, because a flag looks the same whoever created it.
#
# THE DIRECTION THAT MATTERS. A false NON-pause means the lead executes straight through a
# real operator steer — the failure Rule 29 exists to prevent. Assertion 3 is therefore the
# load-bearing one: it is the assertion that would catch a predicate scoped too widely.
set -uo pipefail

# The pre-push gate inherits every AI_DLC_* tunable a consumer set in settings.json. A
# fixture that drives a hook while inheriting them tests the CONFIG, not the code — and
# then blocks the consumer's every push against a hook behaving exactly as specified.
# Scrub first (validate-enforcement-map.sh I10 asserts this rather than trusting it).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# Drive the hook exactly as the harness does: JSON on stdin, CLAUDE_PROJECT_DIR set.
fire() { # <prompt-json-string>
  rm -f "$FLAG"
  printf '{"session_id":"fixture","prompt":%s}' "$1" \
    | CLAUDE_PROJECT_DIR="$PROJECT" bash "$HOOK" >/dev/null 2>&1
}

echo "pause-hook-origin:"

# --- Assertion 0: SANITY — the hook reaches the predicate at all --------------
# Without an active pipeline the hook exits before the predicate, and every assertion below
# would pass for the wrong reason.
if [ -f "$SNAPSHOT" ]; then
  ok "seed: a pipeline snapshot exists, so the hook runs past its no-snapshot early exit"
else
  bad "FIXTURE BROKEN — no snapshot; the hook exits before the predicate"
  echo; echo "pause-hook-origin: FIXTURE BROKEN" >&2; exit 2
fi

# --- Assertion 1: an EMPTY prompt does not pause ------------------------------
fire '""'
if [ ! -f "$FLAG" ]; then
  ok "empty prompt: no pause flag created"
else
  bad "an empty prompt still created the pause flag — the lead blocks on a pause no human initiated"
fi

# --- Assertion 2: whitespace + a system-reminder does not pause ---------------
# This is the shape a harness-synthetic event actually arrives in: no operator prose, but not
# a bare empty string either.
fire '"  \n<system-reminder>background task finished</system-reminder>\n  "'
if [ ! -f "$FLAG" ]; then
  ok "whitespace + system-reminder only: no pause flag created"
else
  bad "a prompt with no operator prose still created the pause flag"
fi

# --- Assertion 3: REAL OPERATOR PROSE STILL PAUSES ---------------------------
# The load-bearing assertion. Everything above narrows the hook; this is what stops the
# narrowing from swallowing a genuine steer.
fire '"Stop and re-check the gate before you continue."'
if [ -f "$FLAG" ]; then
  ok "operator prose: pause flag created (the narrowing cannot swallow a real steer)"
else
  bad "A REAL OPERATOR STEER DID NOT PAUSE THE PIPELINE. The predicate is scoped too widely; this is the failure direction Rule 29 exists to prevent."
fi

# --- Assertion 4: operator prose ALONGSIDE a system-reminder still pauses ------
# Every real operator turn in this harness carries system-reminder blocks. If stripping them
# ever consumed the prose too, assertion 3 would still pass while every real steer was lost.
fire '"<system-reminder>ctx</system-reminder>Actually, hold on — revert that."'
if [ -f "$FLAG" ]; then
  ok "prose + system-reminder: pause flag created (stripping does not consume the prose)"
else
  bad "a real steer arriving with a system-reminder was discarded — the strip is eating operator text"
fi

# --- Assertion 5: the skip is RECORDED, not silent ----------------------------
# A pause that never happened reads exactly like a pause the lead already cleared. If nothing
# records which, the retro cannot tell an over-firing hook from a well-behaved one.
fire '""'
if grep -q 'PAUSE_SKIPPED' "$LOG" 2>/dev/null; then
  ok "the skip is logged PAUSE_SKIPPED — not silent"
else
  bad "the hook skipped without recording it; a skip indistinguishable from a cleared pause is the same defect one layer down"
fi

# --- Assertion 6: the log legend explains the event it emits -------------------
# The skip path seeds the header too. A first-write that is a SKIP must not produce a log
# whose legend omits the only event type in it.
if grep -q '`PAUSE_SKIPPED`' "$LOG" 2>/dev/null; then
  ok "the log's event-type legend documents PAUSE_SKIPPED"
else
  bad "PAUSE_SKIPPED entries are written into a log whose legend never mentions them"
fi

# --- Assertion 7: MUTANT — remove the predicate and assertion 1 must fail ------
MUT="$WORK/pause-mutant.sh"
sed 's|^if \[ -z "\$PROMPT_STRIPPED" \]; then|if [ -n "$PROMPT_STRIPPED" ] \&\& false; then|' \
  "$HOOK" > "$MUT"
if ! grep -q 'PROMPT_STRIPPED" \] && false' "$MUT"; then
  bad "FIXTURE STALE: could not build the no-predicate mutant — the guard's condition was reworded"
else
  rm -f "$FLAG"
  printf '{"session_id":"fixture","prompt":""}' \
    | CLAUDE_PROJECT_DIR="$PROJECT" bash "$MUT" >/dev/null 2>&1
  if [ -f "$FLAG" ]; then
    ok "mutant: with the predicate disabled an empty prompt pauses again — the fixture can fail"
  else
    bad "MUTANT DID NOT FAIL — an empty prompt creates no flag even with the guard disabled, so assertion 1 proves nothing"
  fi
fi

echo
if [ "$fails" -eq 0 ]; then echo "pause-hook-origin: PASS"; exit 0; fi
echo "pause-hook-origin: $fails assertion(s) FAILED" >&2
exit 1
