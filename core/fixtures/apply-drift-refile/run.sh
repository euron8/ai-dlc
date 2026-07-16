#!/usr/bin/env bash
# apply-drift-refile/run.sh — prove apply.sh AUTOMATES the known_skills drift migration: refile the
# in-place addition to extensions/known-skills.json and revert the core schema, with no manual step.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "apply-drift-refile:"

# --- Assertion 0: SANITY — the drift is present before ------------------------
if grep -q "my-persona-skill" "$SCHEMA" && [ ! -f "$EXT" ]; then
  ok "before: skill added to core schema in place, no extension file"
else
  bad "FIXTURE BROKEN — starting state wrong"; echo; echo "apply-drift-refile: FIXTURE BROKEN" >&2; exit 2
fi

# --- Run the resolution driver -----------------------------------------------
MANIFEST="$(bash "$APPLY" "$DIST" "$BASE" "$CONSUMER" "$BASE" 2>/dev/null)"

# --- Assertion 1: manifest reports the refile as RESOLVED --------------------
printf '%s\n' "$MANIFEST" | grep -q "drift-refile" && ok "manifest: RESOLVED drift-refile (not handed to the operator)" \
  || bad "manifest did not report a drift-refile"

# --- Assertion 2: the extension now registers the skill ----------------------
if [ -f "$EXT" ] && grep -q "my-persona-skill" "$EXT"; then
  ok "extensions/known-skills.json created with the consumer's skill"
else
  bad "extension file not created / missing the skill"
fi

# --- Assertion 3: the core schema is reverted (drift gone) --------------------
if ! grep -q "my-persona-skill" "$SCHEMA"; then
  ok "core schema reverted — the in-place drift is gone"
else
  bad "core schema still carries the in-place edit — drift not cleared"
fi

# --- Assertion 4: the stamp was re-stamped -----------------------------------
grep -q "version: 9.9.9" "$STAMP" && ok "stamp re-stamped to theirs (version 9.9.9)" \
  || bad "stamp not updated"

echo
if [ "$fails" -eq 0 ]; then echo "apply-drift-refile: PASS"; exit 0; fi
echo "apply-drift-refile: $fails assertion(s) FAILED" >&2
exit 1
