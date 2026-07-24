#!/usr/bin/env bash
# apply-drift-after-write/run.sh — prove apply.sh measures consumer drift BEFORE it writes.
#
# THE DEFECT. apply.sh phase 1 overwrites every pure-apply core file from THEIRS. The
# unregistered-drift capture used to sit below that, in phase 2, and its comparison is
# `git show "${BASE}:${cp}" | cmp -s - "$cons"` — against BASE, on files phase 1 had just set
# to THEIRS. Any file that was both a pure-apply and changed upstream therefore reported as
# consumer drift NECESSARILY, on a pull containing no consumer drift at all.
#
# The output is destructive, not merely noisy: HARD-CORE-DRIFT-ABSORBED hands the operator a
# ready `git show ... > <consumer-path>` revert command and asserts "a revert DELETES text and
# only you can confirm nothing was lost", while HARD-UNREGISTERED-CORE-DRIFT reaches apply.sh
# itself as `DECISION drift ... refile-as-override or revert`. An operator who trusts either
# authors a bogus overrides/ entry shadowing a rule they never changed, or reverts a file to
# the version it already is. And on a pull that DID carry real drift, the true rows would be
# indistinguishable from these — a poisoned signal, not a spurious one.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "apply-drift-after-write:"

# --- Assertion 0: SANITY — the pull really is clean before the run ------------
# Everything below is meaningless if the seed shipped a consumer that HAD drift.
PRE="$(bash "$DRIFT" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
if printf '%s\n' "$PRE" | grep -q '^HARD-'; then
  bad "FIXTURE BROKEN — the consumer carries drift before apply.sh runs: $(printf '%s\n' "$PRE" | grep '^HARD-' | head -1)"
  echo; echo "apply-drift-after-write: FIXTURE BROKEN" >&2; exit 2
fi
if printf '%s\n' "$PRE" | grep -qc 'CORE-OK.*alpha.md' >/dev/null && printf '%s\n' "$PRE" | grep -q 'CORE-OK.*beta.md'; then
  ok "before: both core files byte-identical to BASE — zero consumer drift, nothing to decide"
else
  bad "FIXTURE BROKEN — the detector did not see the seeded files at all (scan set changed?)"
  echo; echo "apply-drift-after-write: FIXTURE BROKEN" >&2; exit 2
fi

# --- Assertion 0b: SANITY — there is a real upstream delta to apply -----------
if ! git -C "$DIST" diff --quiet "$BASE" "$THEIRS" -- core/skills/ai-dlc/steps/alpha.md core/skills/ai-dlc/steps/beta.md; then
  ok "before: upstream changed both files (a real UPSTREAM-ONLY apply, so phase 1 will write)"
else
  bad "FIXTURE BROKEN — no staged upstream delta, so phase 1 writes nothing and the defect cannot appear"
  echo; echo "apply-drift-after-write: FIXTURE BROKEN" >&2; exit 2
fi

# --- Run the resolution driver -----------------------------------------------
MANIFEST="$(bash "$APPLY" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"

# --- Assertion 1: both files applied ------------------------------------------
if [ "$(printf '%s\n' "$MANIFEST" | grep -c 'RESOLVED.*pure-apply')" -eq 2 ]; then
  ok "manifest: both files RESOLVED pure-apply"
else
  bad "expected 2 pure-apply rows, got: $(printf '%s\n' "$MANIFEST" | grep 'pure-apply' | tr '\n' ' ')"
fi

# --- Assertion 2: THE FIX — a clean pull produces no drift decision -----------
if printf '%s\n' "$MANIFEST" | grep -q 'DECISION[[:space:]]*drift'; then
  bad "apply.sh reported ITS OWN WRITE as consumer drift on a clean pull: $(printf '%s\n' "$MANIFEST" | grep 'DECISION.*drift' | head -1)"
else
  ok "no DECISION drift on a clean pull — the drift set was measured before phase 1 wrote"
fi

# --- Assertion 2b: EXTENSION-HOOK-DRIFT is handed back as WORK, not stated as prose ---
# The obligation ("re-read this entry against the new core text") was named only at the
# detector and in step 3c. Step 7 had no slot, no manifest row carried it, and no gate
# consulted it — a stated actor of nobody and a stated deadline of never. Measured on the
# reference consumer: four entries flagged, listed in the report's own "what apply would do",
# then not executed, two pulls running. A WORKLIST row is the weakest thing with an owner.
if printf '%s\n' "$MANIFEST" | grep -q 'WORKLIST[[:space:]]*extension-reread.*alpha-domain'; then
  ok "EXTENSION-HOOK-DRIFT reached the manifest as WORKLIST extension-reread"
else
  bad "the hooked-core-changed obligation produced no work item: $(printf '%s\n' "$MANIFEST" | tr '\n' '|')"
fi
# ...and it must NOT be a blocker: nothing can prove the entry is wrong, so gating on a
# suspicion would be a false HARD row. It is work with an owner, not a block. Written to
# require the row to EXIST first -- a plain "no HARD row" test passes loudest when the row
# is missing entirely, which is the failure above, not this one.
EXTROW="$(printf '%s\n' "$MANIFEST" | grep 'extension-reread' || true)"
if [ -n "$EXTROW" ] && ! printf '%s\n' "$EXTROW" | grep -q 'HARD-'; then
  ok "extension-reread is work, not a blocker"
elif [ -z "$EXTROW" ]; then
  bad "no extension-reread row at all — cannot assert it is non-blocking"
else
  bad "extension-reread was emitted as a HARD blocker — an unprovable suspicion must not gate apply"
fi

# --- Assertion 3: THE SECOND DEFENCE — the detector refuses the poisoned reading ---
# There are now TWO independent defences against this hazard, and this fixture must prove
# both or it silently proves neither.
#
#   1. ORDERING (v0.114.0) — apply.sh captures drift in phase 0, before it writes.
#   2. THE DETECTOR (v0.143.0) — a file byte-identical to THEIRS is CORE-AT-THEIRS, never
#      drift, whatever base was passed.
#
# Defence 2 subsumes defence 1 for this scenario: run post-write against BASE now and the
# hazard rows do not appear at all. That is why assertion 4's mutant must knock out BOTH.
POST="$(bash "$DRIFT" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
if printf '%s\n' "$POST" | grep -q 'CORE-AT-THEIRS.*alpha.md' \
   && printf '%s\n' "$POST" | grep -q 'CORE-AT-THEIRS.*beta.md'; then
  ok "post-write against a STALE base: both files read CORE-AT-THEIRS, not drift"
else
  bad "the stale-base guard did not fire post-write. Got: $(printf '%s\n' "$POST" | tr '\n' '|')"
fi

# --- Assertion 3b: ANTI-VACUITY — the hazard is real, the guard is what suppresses it ---
# Without this, assertion 3 could pass because the seed picked files the detector never looks
# at. Strip ONLY the guard and re-run: both hazard rows must return, with the destructive
# revert instruction intact. That proves the guard is load-bearing and the stakes are real.
NOGUARD="$WORK/drift-noguard.sh"
# The script resolves map_consumer() from its SIBLING preclassify.sh and refuses to scan at
# all without it. A mutant copied away from that sibling therefore reports nothing, which
# reads here as "the hazard did not reproduce" — a vacuous PASS of the wrong assertion.
cp "$(dirname "$DRIFT")/preclassify.sh" "$WORK/preclassify.sh"
awk '/^      if \[ -n "\$THEIRS" \] && git -C "\$DIST" cat-file -e "\$\{THEIRS\}:\$\{cp\}" 2>\/dev\/null \\$/ {skip=6}
     skip > 0 {skip--; next}
     {print}' "$DRIFT" > "$NOGUARD"
if [ "$(grep -c 'CORE-AT-THEIRS' "$NOGUARD")" -gt 1 ]; then
  bad "FIXTURE STALE: could not strip the CORE-AT-THEIRS guard — unregistered-drift.sh was reshaped"
else
  RAW="$(bash "$NOGUARD" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
  if printf '%s\n' "$RAW" | grep -q 'HARD-CORE-DRIFT-ABSORBED.*alpha.md' \
     && printf '%s\n' "$RAW" | grep -q 'HARD-UNREGISTERED-CORE-DRIFT.*beta.md' \
     && printf '%s\n' "$RAW" | grep 'alpha.md' | grep -q 'a revert DELETES text'; then
    ok "guard removed: BOTH hazard rows return, absorbed one still carrying the ready revert — the guard is what suppresses them"
  else
    bad "FIXTURE VACUOUS — with the guard stripped the hazard did not reproduce, so assertion 3 proves nothing. Got: $(printf '%s\n' "$RAW" | tr '\n' '|')"
  fi
fi

# --- Assertion 4: MUTANT — put the capture back below phase 1 and it must fire -
# A FRESH seed is load-bearing. The run above already applied both files, so a mutant pointed
# at that tree finds every bucket ALREADY-AT-THEIRS, writes nothing, and cannot reproduce the
# defect — it would score a false PASS for a reason unrelated to ordering.
MUTDIR="$WORK/reconcile-mutant"
mkdir -p "$MUTDIR"
cp "$RECONCILE"/*.sh "$MUTDIR/" 2>/dev/null
awk '
  /^UD="\$\(bash "\$SELF\/unregistered-drift\.sh"/ { ud=$0; next }
  /^# -+ 2\. drift refile/                         { print; if (ud != "") { print ud; ud="" } ; next }
  { print }
' "$APPLY" > "$MUTDIR/apply.sh"
# BOTH defences must go, or the mutant cannot reproduce the defect: with the detector guard
# in place the moved capture reads CORE-AT-THEIRS and reports nothing, and this assertion
# would score a false PASS for a reason unrelated to ordering.
cp "$NOGUARD" "$MUTDIR/unregistered-drift.sh"

mut_ud_line="$(grep -n '^UD="\$(bash "\$SELF/unregistered-drift.sh"' "$MUTDIR/apply.sh" | cut -d: -f1)"
mut_loop_line="$(grep -n '^# -* 1\. buckets' "$MUTDIR/apply.sh" | cut -d: -f1)"
W2="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: second seed failed" >&2; exit 2; }
eval "$(sed 's/^/M_/' "$W2/env.sh")"

if [ -z "$mut_ud_line" ] || [ -z "$mut_loop_line" ] || [ "$mut_ud_line" -lt "$mut_loop_line" ]; then
  bad "FIXTURE STALE: could not build the ordering mutant — apply.sh's UD capture or phase markers were renamed (ud=${mut_ud_line:-none}, phase1=${mut_loop_line:-none})"
else
  MUT_OUT="$(bash "$MUTDIR/apply.sh" "$M_DIST" "$M_BASE" "$M_CONSUMER" "$M_THEIRS" 2>/dev/null)"
  if [ "$(printf '%s\n' "$MUT_OUT" | grep -c 'RESOLVED.*pure-apply')" -ne 2 ]; then
    bad "FIXTURE BROKEN — the mutant did not apply both files, so any drift row below would have a different cause"
  elif printf '%s\n' "$MUT_OUT" | grep -q 'DECISION[[:space:]]*drift.*beta.md'; then
    ok "mutant: measuring after the write turns a clean pull into 'refile-as-override or revert' — the fixture can fail"
  else
    bad "MUTANT DID NOT FAIL — with the capture back below phase 1, apply.sh still reported no drift. This fixture cannot detect the defect it exists for."
  fi
fi
rm -rf "$W2"

echo
if [ "$fails" -eq 0 ]; then echo "apply-drift-after-write: PASS"; exit 0; fi
echo "apply-drift-after-write: $fails assertion(s) FAILED" >&2
exit 1
