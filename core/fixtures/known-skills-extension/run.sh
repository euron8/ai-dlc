#!/usr/bin/env bash
# known-skills-extension/run.sh — prove the consumer known_skills extension point.
#
# WHY THIS EXISTS. known_skills in provenance-block.json is a CORE list. A consumer with its own
# party-persona skill (whose real invocation emits a provenance block citing it) had no
# layer-correct way to register the name — editing the core schema in place was the only option,
# which /ai-dlc-update now flags as HARD-UNREGISTERED-CORE-DRIFT (schemas are scanned). This proves
# extensions/known-skills.json is the additive, drift-free alternative.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# run_with <ext-path> -> sets RC. Empty ext-path = no extension (explicitly).
run_with() { AI_DLC_KNOWN_SKILLS_EXT="$1" bash "$VALIDATOR" "$ARTIFACT" >/dev/null 2>&1; RC=$?; }

echo "known-skills-extension:"

# --- Assertion 0: SANITY — the skill is genuinely NOT core-known --------------
run_with ""
if [ "$RC" -eq 1 ]; then
  ok "without any extension, the block citing 'bmad-agent-tea-tea' FAILS (it is not a core skill — the negatives below mean something)"
else
  bad "FIXTURE BROKEN — the block passed (rc=$RC) with no extension; 'bmad-agent-tea-tea' must not be core-known"
  echo; echo "known-skills-extension: FIXTURE BROKEN" >&2; exit 2
fi

# --- Assertion 1: the extension (object form) registers the skill → PASS ------
run_with "$EXT"
[ "$RC" -eq 0 ] && ok "with extensions/known-skills.json ({known_skills:[…]}), the block PASSES (exit 0)" \
  || bad "the object-form extension did NOT register the skill (rc=$RC)"

# --- Assertion 2: bare-array form also works → PASS ---------------------------
run_with "$EXT_ARRAY"
[ "$RC" -eq 0 ] && ok "the bare-array extension form (['…']) also PASSES" \
  || bad "the array-form extension did NOT register the skill (rc=$RC)"

# --- Assertion 3: a malformed extension FAILS CLOSED --------------------------
run_with "$MALFORMED"
[ "$RC" -eq 1 ] && ok "a present-but-malformed extension FAILS closed (never silently degrades to the core-only list)" \
  || bad "a malformed extension did NOT fail closed (rc=$RC)"

# --- Assertion 4: a nonexistent path is 'no extension', not an error ----------
run_with "$WORK/does-not-exist.json"
[ "$RC" -eq 1 ] && ok "a nonexistent extension path is treated as absent (block still FAILS on the unknown skill, no crash)" \
  || bad "a nonexistent extension path did not behave as absent (rc=$RC)"

echo
if [ "$fails" -eq 0 ]; then echo "known-skills-extension: PASS"; exit 0; fi
echo "known-skills-extension: $fails assertion(s) FAILED" >&2
exit 1
