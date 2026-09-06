#!/usr/bin/env bash
# reconcile-blocking-list/run.sh — prove hard-blockers.sh renders the blocking list and its --check
# catches a report that dropped a HARD blocker.
#
# THE DEFECT THIS EXISTS TO CATCH. The dry-run report is LLM-authored from the detectors' output;
# nothing forced every HARD-* line to appear in it. On a real pull, unregistered-drift.sh flagged an
# in-place core-schema edit HARD, twice, and both reports said "no unregistered core drift" — a
# blocker the operator would approve apply without seeing, then apply overwrites the edit silently.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "reconcile-blocking-list:"

# --- Assertion 0: SANITY — print mode renders the blocker ---------------------
out="$(bash "$HB" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
if grep -qF "$DRIFT_REL" <<<"$out" && grep -q "HARD-UNREGISTERED-CORE-DRIFT" <<<"$out"; then
  ok "print mode renders the HARD blocker ($DRIFT_REL) from the detectors"
else
  bad "FIXTURE BROKEN — print mode did not render the in-place drift; negatives below are meaningless"
  echo; echo "reconcile-blocking-list: FIXTURE BROKEN" >&2; exit 2
fi

# --- Assertion 1: --check FAILS a report that OMITS the blocker (the bug) ------
bash "$HB" --check "$REPORT_BAD" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 1 ] && ok "--check FAILS (exit 1) a report that omits the blocker — the drop is caught" \
  || bad "--check did NOT fail on a report omitting the blocker (rc=$rc) — the report could still silently drop it"

# --- Assertion 2: --check PASSES a report that NAMES the blocker ---------------
bash "$HB" --check "$REPORT_GOOD" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && ok "--check PASSES (exit 0) a report that names the blocker" \
  || bad "--check failed on a report that DOES name the blocker (rc=$rc) — false positive"

# --- Assertion 2b: the degenerate-range qualifier reaches the rendered list -----
# `layer-drift.sh` emits DRIFT-RANGE-DEGENERATE when base and theirs are the same commit, saying
# its range-keyed adjudication arms could not fire. This wrapper's only reader was a `^HARD-`
# filter, and that status carries a deliberately non-HARD prefix — so the one caller that most
# needed the warning discarded it and printed a clean sheet instead. Filed as
# PC-S302-HARD-BLOCKERS-HAS-NO-POST-APPLY-GUARD. BASE == THEIRS in this seed, so this run IS
# degenerate; the control below is the arm that proves the line is not printed unconditionally.
out="$(bash "$HB" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
grep -q 'DRIFT-RANGE-DEGENERATE' <<<"$out" \
  && ok "a degenerate range is qualified in the rendered list, not filtered out of it" \
  || bad "print mode rendered no DRIFT-RANGE-DEGENERATE row on a run where base == theirs — the clean sheet is unqualified"

# CONTROL: a NON-degenerate range must not carry the qualifier. Without this, the arm above
# passes against a wrapper that prints the line every time, which discriminates nothing.
out_adv="$(bash "$HB" "$DIST" "$BASE" "$CONSUMER" "$THEIRS_ADV" 2>/dev/null)"
grep -q 'DRIFT-RANGE-DEGENERATE' <<<"$out_adv" \
  && bad "CONTROL: the qualifier was printed on a range whose two refs DIFFER — it fires unconditionally and says nothing" \
  || ok "CONTROL: a real base..theirs range carries no degenerate qualifier"

# --- Assertion 2c: --post-apply moves ONLY the unregistered-drift base ----------
# Post-apply, core on disk is at THEIRS. Asking unregistered-drift.sh against the PULL's base
# then reports upstream's own freshly-written text as a consumer in-place edit, whose printed
# remedy is to revert or refile it. `--post-apply` asks against theirs instead.
#
# THE SAME INVOCATION CARRIES ITS OWN CONTROL: `$DRIFT_REL` is a genuine consumer edit and must
# stay blocking under the flag. An arm that only asserted the artefact disappears would pass
# against a flag that suppressed the whole detector.
pre="$(bash "$HB" "$DIST" "$BASE" "$CONSUMER" "$THEIRS_ADV" 2>/dev/null)"
post="$(bash "$HB" --post-apply "$DIST" "$BASE" "$CONSUMER" "$THEIRS_ADV" 2>/dev/null)"
if grep -qF "$MOVED_REL" <<<"$pre" && ! grep -qF "$MOVED_REL" <<<"$post"; then
  ok "--post-apply drops the wrong-base artefact on a file the pull itself wrote"
else
  bad "the wrong-base artefact ($MOVED_REL) did not appear pre-apply or did not clear under --post-apply — the flag changes nothing, or the seed cannot express the defect"
fi
grep -qF "$DRIFT_REL" <<<"$post" \
  && ok "CONTROL: a real consumer in-place edit still blocks under --post-apply" \
  || bad "CONTROL: --post-apply suppressed a genuine HARD blocker — the flag disarms the detector instead of rebasing it"

# --- Assertion 3: no drift → print says 0, --check passes any report ----------
git -C "$DIST" show "$BASE:core/$DRIFT_REL" > "$CONSUMER/.claude/$DRIFT_REL"   # revert consumer edit
git -C "$DIST" show "$BASE:core/$MOVED_REL" > "$CONSUMER/.claude/$MOVED_REL"   # and the range-drifted one
out="$(bash "$HB" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
if grep -q "0 HARD blockers" <<<"$out"; then
  bash "$HB" --check "$REPORT_BAD" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" >/dev/null 2>&1
  [ $? -eq 0 ] && ok "with no drift: print says '0 HARD blockers' and --check passes any report" \
    || bad "no-drift --check did not pass"
else
  bad "reverting the drift did not clear the blocker list"
fi

# --- MUTANT: the degenerate detection made unconditional -----------------------
# Assertion 2b's CONTROL is an ABSENCE — "a real base..theirs range carries no qualifier" —
# and an absence passes against a script that emits nothing at all. This is what makes that
# control mean "the detection discriminates" rather than "something did not happen".
#
# THE MUTANT IS A COPY OF THE WHOLE `reconcile/` DIRECTORY, not of the one script.
# `hard-blockers.sh` resolves its two detectors as siblings of its own path, so a lone copy
# in a temp dir finds neither, `[ -f "$UD" ]` is false, and it emits an empty list — which
# would score as a kill for every mutant in this file while proving nothing. The unmutated
# control below is what states that the copied harness still works.
MUTDIR="$(dirname "$HB")"
MW="$(mktemp -d "${TMPDIR:-/tmp}/rbl-mut.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
cp -R "$MUTDIR/." "$MW/" 2>/dev/null

ctl_out="$(bash "$MW/hard-blockers.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
grep -q 'DRIFT-RANGE-DEGENERATE' <<<"$ctl_out" \
  && ok "MUTANT CONTROL: the unmutated copy still resolves its detectors and qualifies the degenerate run" \
  || bad "MUTANT CONTROL is dead — a copy of the reconcile dir emits nothing, so any kill below is unearned"

sed 's|\$1=="DRIFT-RANGE-DEGENERATE"{print \$1; exit}|{print "X"; exit}|' \
  "$MW/hard-blockers.sh" > "$MW/hb-mut.sh"
if cmp -s "$MW/hard-blockers.sh" "$MW/hb-mut.sh"; then
  bad "MUTANT matched nothing (cmp -s guard) — assertion 2b's control proves nothing"
else
  mut_out="$(bash "$MW/hb-mut.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS_ADV" 2>/dev/null)"
  grep -q 'DRIFT-RANGE-DEGENERATE' <<<"$mut_out" \
    && ok "MUTANT: with the row test removed the qualifier appears on a NON-degenerate range — so the control is what proves it discriminates" \
    || bad "MUTANT: the qualifier stayed absent even with the row test removed — assertion 2b's control is vacuous"
fi

# --- Assertion 4: A REFUSING DETECTOR IS NOT A CLEAN SHEET --------------------------------
# THE DEFECT THIS CLOSES, MEASURED BEFORE THE FIX: stub either detector to `exit 2` and this
# wrapper printed `0 HARD blockers.` at exit 0. That is the one line the whole HARD- contract
# keys on — SKILL.md tells the operator a HARD- status blocks apply, so the affirmative empty
# line is what authorises the write, and a detector that never classified was producing it.
# `:84` above asserts the clean line on a genuinely clean tree; these arms are what stop that
# line meaning two different things.
#
# DRIVEN IN THE DIRECTORY COPY, one detector at a time, each against the SAME copy that just
# produced a correct control above — a lone script copy resolves no siblings and emits nothing,
# which would score every arm here as a kill it did not earn.
for a4_det in layer-drift unregistered-drift; do
  a4_w="$MW/refuse-$a4_det"
  rm -rf "$a4_w"; cp -R "$MUTDIR/." "$a4_w/" 2>/dev/null

  # POSITIVE CONTROL FIRST, in the same copy: unstubbed, this world renders the clean line.
  # Without it a copy that simply died would satisfy the absence half below.
  a4_ctl="$(bash "$a4_w/hard-blockers.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
  if ! grep -q '0 HARD blockers' <<<"$a4_ctl"; then
    bad "CONTROL for $a4_det: the unstubbed copy does not render '0 HARD blockers.', so the refusal arm below cannot tell a suppressed line from a copy that never ran"
    continue
  fi

  printf '#!/usr/bin/env bash\nexit 2\n' > "$a4_w/$a4_det.sh"
  a4_out="$(bash "$a4_w/hard-blockers.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
  # BOTH HALVES, because either alone is satisfied by the wrong program: a run that emits
  # nothing lacks the clean line, and a run that emits everything carries the refusal beside it.
  if grep -q "DETECTOR-REFUSED" <<<"$a4_out" \
     && grep -q "$a4_det.sh exited 2" <<<"$a4_out" \
     && ! grep -q '0 HARD blockers' <<<"$a4_out"; then
    ok "a refusing $a4_det.sh renders DETECTOR-REFUSED naming itself and SUPPRESSES '0 HARD blockers.' — a detector that never classified cannot authorise the write"
  else
    bad "a refusing $a4_det.sh did not produce a self-naming DETECTOR-REFUSED row with the clean line suppressed (got: $(printf '%s' "$a4_out" | tr '\n' ' ' | head -c 140)) — an empty blocking list from a dead detector reads as a clean sheet, and apply is authorised on it"
  fi

  # --check must FAIL on that same world. Its contract is "the report names every HARD item the
  # detectors emit", which against a detector that computed nothing is vacuously true — so a
  # pass there certifies a report against a set that was never built.
  bash "$a4_w/hard-blockers.sh" --check "$REPORT_BAD" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" >/dev/null 2>&1
  [ $? -ne 0 ] \
    && ok "--check REFUSES while $a4_det.sh is refusing — it cannot certify a report against a blocker set that was never computed" \
    || bad "--check passed while $a4_det.sh was refusing — the report is being certified complete against nothing, which is the vacuous pass this arm exists to stop"
done

# --- Assertion 5: THE ROWS FLAGS ARE OPTIONAL AND THEIR MISUSE IS REFUSED ------------------
# The flags exist so `emit-report.sh` can run each detector ONCE and hand the rows down. Every
# other caller — including all of this fixture's own invocations above — supplies none, so the
# default path must be untouched, and that is asserted by every arm above still passing.
#
# What is asserted here is the REFUSALS, because each one makes an ambiguous state
# unconstructible rather than merely detectable.
a5_w="$MW/flags"; rm -rf "$a5_w"; cp -R "$MUTDIR/." "$a5_w/" 2>/dev/null
: > "$a5_w/rows.empty"
a5_bad=0
bash "$a5_w/hard-blockers.sh" --ld-rows "$a5_w/rows.empty" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" >/dev/null 2>&1
[ $? -eq 2 ] || { bad "rows supplied without their rc was accepted — empty rows mean 'clean' or 'never ran' and only the status separates them"; a5_bad=1; }
bash "$a5_w/hard-blockers.sh" --ld-rc 0 "$DIST" "$BASE" "$CONSUMER" "$THEIRS" >/dev/null 2>&1
[ $? -eq 2 ] || { bad "an rc supplied without its rows was accepted — a status with no rows describes nothing"; a5_bad=1; }
bash "$a5_w/hard-blockers.sh" --ld-rows "$a5_w/nonexistent" --ld-rc 0 "$DIST" "$BASE" "$CONSUMER" "$THEIRS" >/dev/null 2>&1
[ $? -eq 2 ] || { bad "a rows flag naming no readable file was accepted"; a5_bad=1; }
# THE ONE THAT PROTECTS THE BASE SPLIT. `--post-apply` moves UD_BASE to theirs; rows a caller
# computed pre-apply are then wrong for that detector, in the direction that reports drift
# against text apply itself just wrote.
bash "$a5_w/hard-blockers.sh" --post-apply --ud-rows "$a5_w/rows.empty" --ud-rc 0 "$DIST" "$BASE" "$CONSUMER" "$THEIRS" >/dev/null 2>&1
[ $? -eq 2 ] || { bad "--post-apply with --ud-rows was accepted — the wrapper would filter rows computed at the WRONG base and report drift against text apply wrote"; a5_bad=1; }
# CONTROL: --post-apply alone still works, or the four refusals above would be satisfied by a
# script that refuses everything.
bash "$a5_w/hard-blockers.sh" --post-apply "$DIST" "$BASE" "$CONSUMER" "$THEIRS" >/dev/null 2>&1
[ $? -eq 0 ] || { bad "CONTROL: --post-apply alone no longer works, so the refusals above cannot be told from a wrapper that refuses unconditionally"; a5_bad=1; }
[ "$a5_bad" -eq 0 ] && ok "the rows flags are refused when unpaired, unreadable, or combined with --post-apply, and --post-apply alone still renders (control)"

# --- Assertion 6: A CALLER THAT SUPPLIED THE ROWS OWNS THE REFUSAL RENDERING ---------------
# `emit-report.sh` runs each detector itself and renders DETECTOR-REFUSED in that detector's own
# section from the same rc it passes here. A second copy in the blocking list is not a second
# finding — and it is not cosmetic: `--verify`'s `refused_new` COUNTS these rows to decide
# whether a mismatch can be BLOCKERS-RESOLVED, and two arms of reconcile-emit-report assert that
# count is exactly 1. So the row is emitted by whichever program RAN the detector.
a6_w="$MW/owns"; rm -rf "$a6_w"; cp -R "$MUTDIR/." "$a6_w/" 2>/dev/null
: > "$a6_w/rows.empty"
a6_supplied="$(bash "$a6_w/hard-blockers.sh" --ud-rows "$a6_w/rows.empty" --ud-rc 2 \
  "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null | grep -c '^DETECTOR-REFUSED')" || a6_supplied=0
printf '#!/usr/bin/env bash\nexit 2\n' > "$a6_w/unregistered-drift.sh"
a6_ran="$(bash "$a6_w/hard-blockers.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null \
  | grep -c '^DETECTOR-REFUSED')" || a6_ran=0
if [ "$a6_supplied" -eq 0 ] && [ "$a6_ran" -eq 1 ]; then
  ok "the refusal row is rendered by whichever program RAN the detector: 0 rows when the caller supplied them and renders its own, 1 when the wrapper ran it — the two differ, so the suppression is keyed on the flag and not switched off"
else
  bad "refusal ownership is wrong (rows-supplied: $a6_supplied, wrapper-ran: $a6_ran; want 0 and 1) — either the row is duplicated, which doubles the DETECTOR-REFUSED count --verify reads to decide BLOCKERS-RESOLVED, or it is suppressed even when this wrapper is the only program that saw the refusal"
fi
rm -rf "$MW"

echo
if [ "$fails" -eq 0 ]; then echo "reconcile-blocking-list: PASS"; exit 0; fi
echo "reconcile-blocking-list: $fails assertion(s) FAILED" >&2
exit 1
