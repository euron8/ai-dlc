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

# --- Assertion 0b: SANITY — the driver starts at v1 and upstream has v2 -------
# Without this, "the driver was not updated" below could pass against a seed that never
# staged an update in the first place.
if grep -q 'driver v1' "$DRIVER" && git -C "$DIST" show "$THEIRS:core/session-driver/ai-dlc-session-driver.sh" | grep -q 'driver v2'; then
  ok "before: consumer driver at v1, upstream at v2 (a real UPSTREAM-ONLY delta to apply)"
else
  bad "FIXTURE BROKEN — no staged session-driver update"; echo; echo "apply-drift-refile: FIXTURE BROKEN" >&2; exit 2
fi

# --- Run the resolution driver -----------------------------------------------
MANIFEST="$(bash "$APPLY" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"

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

# --- Assertion 5: a core/ subtree apply.sh never hand-listed still APPLIES ----
# THE DEFECT. consumer_path() enumerated destinations by hand and omitted session-driver,
# ci-templates and git-hooks, so core/session-driver/** hit `*) return 1` and never applied
# — while the same run re-stamped, leaving a tree whose stamp claims a version it does not
# have. It escaped notice because the only upstream delta the driver had ever carried was a
# mode bit (100644 -> 100755) that install.sh had already set, so nothing observable broke.
if grep -q 'driver v2 UPSTREAM' "$DRIVER"; then
  ok "core/session-driver/ applied — apply.sh maps every core/ subtree, not a hand-listed set"
else
  bad "core/session-driver/ did NOT apply (still: $(head -2 "$DRIVER" | tail -1)) — apply.sh's mapper omits a subtree the pull classified and the installer ships"
fi

# --- Assertion 6: the manifest must not report a mapping failure --------------
if printf '%s\n' "$MANIFEST" | grep -q "unmapped-path"; then
  bad "apply.sh emitted DECISION unmapped-path — it cannot resolve a path preclassify mapped and install.sh writes: $(printf '%s\n' "$MANIFEST" | grep unmapped-path | head -1)"
else
  ok "no DECISION unmapped-path — the mapper is total, so nothing silently falls through"
fi

# --- Assertion 7: MUTANT — a mechanical failure must WITHHOLD the stamp -------
# The stamp asserts "this tree is at THEIRS". If a file that should have applied did not,
# that assertion is false, and a stamp that lies is exactly how the v0.70.1 exec-bit defect
# stayed invisible. Break the mapper on purpose and the stamp must NOT advance.
#
# The mutant needs its SIBLINGS: apply.sh resolves preclassify.sh via $SELF, so a lone copy
# in a temp dir exercises the load guard (assertion 8) rather than the mapper. Copy the
# whole reconcile/ dir and mutate that.
# A FRESH seed is load-bearing. The run above already applied the driver and refiled the
# drift, so a mutant pointed at that tree finds every bucket ALREADY-AT-THEIRS, fails at
# nothing, and re-stamps — scoring a false FAIL here for a reason that has nothing to do
# with the guard. The mutant needs work left to fail at.
MUTDIR="$WORK/reconcile-mutant"
mkdir -p "$MUTDIR"
cp "$(dirname "$APPLY")"/*.sh "$MUTDIR/" 2>/dev/null
sed 's|^\( *\)local m; m=.*|\1local m; m=""|' "$APPLY" > "$MUTDIR/apply.sh"
W2="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: second seed failed" >&2; exit 2; }
eval "$(sed 's/^/M_/' "$W2/env.sh")"
if ! grep -q 'local m; m=""' "$MUTDIR/apply.sh" || [ ! -f "$MUTDIR/preclassify.sh" ]; then
  bad "FIXTURE STALE: could not build the mapper mutant — consumer_path() no longer resolves via 'local m; m=...', or reconcile/ has no preclassify.sh sibling"
else
  MUT_OUT="$(bash "$MUTDIR/apply.sh" "$M_DIST" "$M_BASE" "$M_CONSUMER" "$M_THEIRS" 2>/dev/null)"
  if grep -q "version: 9.9.9" "$M_STAMP"; then
    bad "with the mapper broken, the stamp STILL advanced to 9.9.9 — the tree now claims a version it does not have"
  elif ! printf '%s\n' "$MUT_OUT" | grep -q "restamp-withheld"; then
    bad "mutant: stamp correctly withheld but apply.sh said nothing — a silent withhold is its own trap"
  elif grep -q 'driver v2' "$M_DRIVER"; then
    bad "FIXTURE BROKEN — the mutant applied the driver anyway, so the withhold above was not caused by a mapping failure"
  else
    ok "mutant: a mapping failure withholds the stamp and says so (the record cannot claim an apply that did not happen)"
  fi
fi
rm -rf "$W2"

# --- Assertion 8: severed from its mapper, apply.sh must REFUSE, not guess ----
# The delegation is only safe if a failure to load map_consumer() is loud. A silent fallback
# to a private table is the defect this whole change removes: it would place some subtrees,
# skip others, and stamp as though everything landed.
printf 'version: 0.0.1\ncommit: %s\n' "$BASE" > "$STAMP"
LONE="$WORK/lone/apply.sh"; mkdir -p "$WORK/lone"; cp "$APPLY" "$LONE"
LONE_OUT="$(bash "$LONE" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>&1)"; lone_rc=$?
if [ "$lone_rc" -ne 0 ] && printf '%s' "$LONE_OUT" | grep -q "could not load map_consumer" && ! grep -q "9.9.9" "$STAMP"; then
  ok "apply.sh with no map_consumer to load refuses loudly and leaves the stamp alone (it never guesses a path)"
else
  bad "apply.sh with no map_consumer did NOT fail closed (rc=$lone_rc) — it either guessed consumer paths or stamped anyway"
fi

# --- Assertion 9: the SECOND consumer of that mapper must also refuse ---------
# unregistered-drift.sh delegates to the same map_consumer(). It cannot fail closed the way
# apply.sh does — it never writes — so silence IS its failure mode: an unrunnable scan and a
# clean tree print the same empty output, and hard-blockers.sh reads both as 0 blockers.
UD="$(dirname "$APPLY")/unregistered-drift.sh"
LONE_UD="$WORK/lone/unregistered-drift.sh"; cp "$UD" "$LONE_UD"
UD_OUT="$(bash "$LONE_UD" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>&1)"
if printf '%s\n' "$UD_OUT" | grep -q '^HARD-DRIFT-SCAN-UNAVAILABLE'; then
  ok "unregistered-drift.sh with no map_consumer to load emits a HARD row (an unrunnable scan never reads as clean)"
else
  bad "unregistered-drift.sh with no map_consumer printed no HARD row: $(printf '%s' "$UD_OUT" | tr '\n' '|' | cut -c1-200)"
fi

# --- Assertion 9b: ANTI-VACUITY — the scan is alive when the sibling is there -
# Without this, 9 passes on a script that is broken for every input.
UD_OK="$(bash "$UD" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>&1)"
if [ -n "$UD_OK" ] && ! printf '%s\n' "$UD_OK" | grep -q '^HARD-DRIFT-SCAN-UNAVAILABLE'; then
  ok "with preclassify.sh beside it the same script scans and reports — the HARD row is the mapper, not a dead script"
else
  bad "the scan produced no usable rows with preclassify.sh present, so assertion 9 proves nothing: $(printf '%s' "$UD_OK" | tr '\n' '|' | cut -c1-200)"
fi

echo
if [ "$fails" -eq 0 ]; then echo "apply-drift-refile: PASS"; exit 0; fi
echo "apply-drift-refile: $fails assertion(s) FAILED" >&2
exit 1
