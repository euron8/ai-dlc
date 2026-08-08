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
if grep -q '^HARD-' <<<"$PRE"; then
  bad "FIXTURE BROKEN — the consumer carries drift before apply.sh runs: $(printf '%s\n' "$PRE" | grep '^HARD-' | head -1)"
  echo; echo "apply-drift-after-write: FIXTURE BROKEN" >&2; exit 2
fi
if grep -qc 'CORE-OK.*alpha.md' >/dev/null <<<"$PRE" && grep -q 'CORE-OK.*beta.md' <<<"$PRE"; then
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
if grep -q 'DECISION[[:space:]]*drift' <<<"$MANIFEST"; then
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
if grep -q 'WORKLIST[[:space:]]*extension-reread.*alpha-domain' <<<"$MANIFEST"; then
  ok "EXTENSION-HOOK-DRIFT reached the manifest as WORKLIST extension-reread"
else
  bad "the hooked-core-changed obligation produced no work item: $(printf '%s\n' "$MANIFEST" | tr '\n' '|')"
fi
# ...and it must NOT be a blocker: nothing can prove the entry is wrong, so gating on a
# suspicion would be a false HARD row. It is work with an owner, not a block. Written to
# require the row to EXIST first -- a plain "no HARD row" test passes loudest when the row
# is missing entirely, which is the failure above, not this one.
EXTROW="$(printf '%s\n' "$MANIFEST" | grep 'extension-reread' || true)"
if [ -n "$EXTROW" ] && ! grep -q 'HARD-' <<<"$EXTROW"; then
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
if grep -q 'CORE-AT-THEIRS.*alpha.md' <<<"$POST" \
   && grep -q 'CORE-AT-THEIRS.*beta.md' <<<"$POST"; then
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
  if grep -q 'HARD-CORE-DRIFT-ABSORBED.*alpha.md' <<<"$RAW" \
     && grep -q 'HARD-UNREGISTERED-CORE-DRIFT.*beta.md' <<<"$RAW" \
     && grep -q 'a revert DELETES text' <<<"$(printf '%s\n' "$RAW" | grep 'alpha.md')"; then
    ok "guard removed: BOTH hazard rows return, absorbed one still carrying the ready revert — the guard is what suppresses them"
  else
    bad "FIXTURE VACUOUS — with the guard stripped the hazard did not reproduce, so assertion 3 proves nothing. Got: $(printf '%s\n' "$RAW" | tr '\n' '|')"
  fi
fi

# --- Assertion 3c: THE INTERMEDIATE SELF-UPDATE REF is not consumer drift -----
# Step 2's autonomous self-update rewrites the whole MACHINERY set on its own cycle and advances
# `skill_commit`, while `commit` — the base every predicate here measures against — stays put. On
# a multi-hop pull the machinery therefore sits at a ref that is NEITHER base nor theirs.
# Reproduced at ground truth on the distribution's own history before this arm existed: the file
# drew HARD-CORE-DRIFT-ABSORBED, whose printed remedy is to REVERT — deleting upstream's own text
# as though the consumer had written it. 28 files are in both the machinery set and this scan.
PRE="$(bash "$DRIFT" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
GROW="$(printf '%s\n' "$PRE" | grep 'gamma' || true)"
if grep -q '^CORE-AT-SELF-UPDATE' <<<"$GROW"; then
  ok "a machinery file at the intermediate \`skill_commit\` reads CORE-AT-SELF-UPDATE, not drift"
else
  bad "the self-update guard did not fire. Got: ${GROW:-<no gamma row at all>}"
fi
# ...and it must not BLOCK. A HARD- prefix here would turn false work into a stopped pull.
case "$GROW" in
  HARD-*) bad "the self-update row is HARD- — it blocks a pull over upstream's own content" ;;
  *)      ok "...and it is non-blocking: nothing consumer-authored is at stake" ;;
esac

# Assertion 3d: ANTI-VACUITY, same shape as 3b. Strip ONLY the new guard and the hazard must
# return, or 3c is passing because the seed picked a file the detector never reaches.
NOSU="$WORK/drift-nosu.sh"
awk '/^      if \[ -n "\$SELF_UPDATE_REF" \] && git -C "\$DIST" cat-file -e "\$\{SELF_UPDATE_REF\}:\$\{cp\}" 2>\/dev\/null \\$/ {skip=5}
     skip > 0 {skip--; next}
     {print}' "$DRIFT" > "$NOSU"
if grep -q 'emit CORE-AT-SELF-UPDATE' "$NOSU"; then
  bad "FIXTURE STALE: could not strip the CORE-AT-SELF-UPDATE guard — unregistered-drift.sh was reshaped"
elif cmp -s "$DRIFT" "$NOSU"; then
  bad "FIXTURE STALE: the strip changed nothing, so assertion 3c is tested against the original"
else
  RAWSU="$(bash "$NOSU" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null | grep 'gamma' || true)"
  case "$RAWSU" in
    HARD-*) ok "guard removed: the same file returns as ${RAWSU%%$'\t'*} — the guard is what suppresses it" ;;
    *)      bad "FIXTURE VACUOUS — with the guard stripped the file did not become a HARD row, so 3c proves nothing. Got: ${RAWSU:-<nothing>}" ;;
  esac
fi

# Assertion 3e: the guard is INERT without the stamp field, and it reads that field itself. A
# stamp carrying no `skill_commit` (a legacy single-line stamp, or a consumer that has never
# self-updated) must behave exactly as before — the guard must not invent a ref.
SAVED="$(cat "$STAMP")"
printf 'version: 0.0.1\ncommit: %s\n' "$BASE" > "$STAMP"
NOFIELD="$(bash "$DRIFT" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null | grep 'gamma' || true)"
printf '%s\n' "$SAVED" > "$STAMP"
case "$NOFIELD" in
  HARD-*) ok "with no \`skill_commit\` in the stamp the guard is inert — the ref is READ, never guessed" ;;
  *)      bad "a stamp with no \`skill_commit\` still suppressed the row, so the guard is matching something it did not read. Got: ${NOFIELD:-<nothing>}" ;;
esac

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
  elif grep -q 'DECISION[[:space:]]*drift.*beta.md' <<<"$MUT_OUT"; then
    ok "mutant: measuring after the write turns a clean pull into 'refile-as-override or revert' — the fixture can fail"
  else
    bad "MUTANT DID NOT FAIL — with the capture back below phase 1, apply.sh still reported no drift. This fixture cannot detect the defect it exists for."
  fi
fi
rm -rf "$W2"

# --- EXTENSION-FIXTURE-UNBOUND — a declared binding that resolves to nothing ---------
# `fixtures:` is how a CONSUMER check's adversarial fixture reaches core H1's derived coverage
# set; before it there was no binding path at all, so a consumer shipping fixtures with its
# checks had them silently uncovered. The binding IS the mechanism, which makes a dangling one
# strictly worse than none: H1 then reports coverage that does not exist — the same shape as
# the hand-typed enumeration H1's rewrite deleted, one layer out.
LD="$(bash "$LAYER" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null)"
if grep -q 'EXTENSION-FIXTURE-UNBOUND.*check-dangling' <<<"$LD"; then
  ok "a fixtures: binding naming no directory is reported EXTENSION-FIXTURE-UNBOUND"
else
  bad "a dangling fixtures: binding was not reported — H1 would count it as coverage: $(printf '%s\n' "$LD" | tr '\n' '|' | cut -c1-200)"
fi
# THE PRECISION SIDE, and it is the one that keeps the detector switched on. A check that
# fires on a binding that DOES resolve makes every correctly-bound consumer fixture a finding.
if grep -q 'EXTENSION-FIXTURE-UNBOUND.*check-bound' <<<"$LD"; then
  bad "the detector fired on a binding whose directory exists — a check with false positives is a check the operator turns off"
else
  ok "a fixtures: binding whose directory exists is silent (the bare name resolves under tests/fixtures/)"
fi

echo
if [ "$fails" -eq 0 ]; then echo "apply-drift-after-write: PASS"; exit 0; fi
echo "apply-drift-after-write: $fails assertion(s) FAILED" >&2
exit 1
