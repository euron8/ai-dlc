#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
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

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }

# Two stderr sinks for the check-mode arms, inside the seed's own WORK so the EXIT trap
# reaps them. Named rather than inlined because a `2>` target computed at the call site is
# one more thing that can silently land somewhere the reader never looks.
MW_ERR_A="$WORK/at-theirs-check.err"
MW_ERR_B="$WORK/at-theirs-check-control.err"

echo "reconcile-blocking-list:"
echo "HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/"

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

# --- Assertion 2d: the SAME shape on a MACHINERY path is CARRIED, not blocked ---------------
# THIS ARM EXISTS BECAUSE THE WORLD ABOVE USED TO BE THIS ONE. The wrong-base artefact was
# `schemas/moved.json` until `core/schemas/*.json` — a `machinery:` glob — met
# `unregistered-drift.sh`'s CORE-MACHINERY-CARRIED row: preclassify buckets it
# `BOTH-CHANGED->CLASSIFY` against the pull's base, `self-update-gate.sh`'s arm C would carry it
# out of step 2's slice, `apply.sh` emits a `WORKLIST semantic-merge` row for it, and the scan
# stopped calling it drift. That is CORRECT, and it took assertion 2c's subject with it: the
# blocking list renders only `HARD-` rows, so the pre side no longer named the file.
#
# Rather than delete the world, it is asserted in its own right. The precedence this documents:
# a token-substituted file on a MACHINERY path in the range is carried; the identical shape on a
# NON-machinery scanned path is still unregistered drift. Both are read from ONE run, so the
# contrast is between two paths and not between two invocations.
md_pre="$(bash "$HB" "$DIST" "$BASE" "$CONSUMER" "$THEIRS_ADV" 2>/dev/null)"
md_ud="$(bash "$(dirname "$HB")/unregistered-drift.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS_ADV" 2>/dev/null)"
md_st="$(awk -F'\t' -v p="$MACH_REL" '$2==p{print $1}' <<<"$md_ud")"
# CONTROL FIRST: the scan reached the file at all. Absent, every claim below is about an empty
# string and the non-HARD assertion passes for the wrong reason.
if [ -z "$md_st" ]; then
  bad "the scan emitted NO row for the machinery artefact ($MACH_REL), so 'it is not HARD' below would be a statement about nothing"
else
  case "$md_st" in
    CORE-MACHINERY-CARRIED)
      ok "a token-substituted MACHINERY template in the range reads CORE-MACHINERY-CARRIED — apply is already merging it" ;;
    HARD-*)
      bad "the machinery artefact read $md_st — arm C carries this path, so the blocking list and the worklist would give the operator opposite instructions for one file" ;;
    *)
      bad "the machinery artefact read $md_st, neither the carried row nor a HARD status — the precedence this arm documents has moved" ;;
  esac
fi
# ...and being non-HARD is exactly what keeps it OFF the blocking list, which is this wrapper's
# own subject. Asserted against the list, not re-read off the status string.
if grep -qF "$MACH_REL" <<<"$md_pre"; then
  bad "the carried machinery path is on the BLOCKING list — hard-blockers renders only HARD- rows, so either the row regained the prefix or the wrapper stopped filtering on it"
else
  ok "...so it is absent from the blocking list, while the non-machinery artefact in the SAME run is on it"
fi
# THE CONTRAST IS THE CONTROL. Without this the arm above passes against a wrapper that renders
# an empty list, or a scan that carries everything.
grep -qF "$MOVED_REL" <<<"$md_pre" \
  && ok "CONTROL: the NON-machinery artefact of the identical shape IS on that same list" \
  || bad "CONTROL: the non-machinery artefact is missing from the list too, so the absence above says nothing about machinery membership"
# ...and under --post-apply the machinery twin reads as the substitution it is: the range is
# empty at base==theirs, no bucket is emitted, and the carried row cannot claim it.
md_post="$(bash "$(dirname "$HB")/unregistered-drift.sh" "$DIST" "$THEIRS_ADV" "$CONSUMER" "$THEIRS_ADV" 2>/dev/null)"
md_pst="$(awk -F'\t' -v p="$MACH_REL" '$2==p{print $1}' <<<"$md_post")"
[ "$md_pst" = "CORE-TEMPLATE-SUBSTITUTED" ] \
  && ok "...and under --post-apply it reads CORE-TEMPLATE-SUBSTITUTED: the empty range emits no bucket, so nothing is carried" \
  || bad "post-apply the machinery artefact read '${md_pst:-<no row>}', not CORE-TEMPLATE-SUBSTITUTED — the post side of this precedence has moved"

# --- Assertion 3: no drift → print says 0, --check passes any report ----------
git -C "$DIST" show "$BASE:core/$DRIFT_REL" > "$CONSUMER/.claude/$DRIFT_REL"   # revert consumer edit
git -C "$DIST" show "$BASE:core/$MOVED_REL" > "$CONSUMER/.claude/$MOVED_REL"   # and the range-drifted one
git -C "$DIST" show "$BASE:core/$MACH_REL"  > "$CONSUMER/.claude/$MACH_REL"    # and its machinery twin
out="$(bash "$HB" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
if grep -q "0 HARD blockers" <<<"$out"; then
  bash "$HB" --check "$REPORT_BAD" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" >/dev/null 2>&1
  [ $? -eq 0 ] && ok "with no drift: print says '0 HARD blockers' and --check passes any report" \
    || bad "no-drift --check did not pass"
else
  bad "reverting the drift did not clear the blocker list"
fi

# --- Assertion 3b: a STALE BASE is read out BESIDE the clean line, not swallowed ----------
# THE SECOND ROW THE `^HARD-` FILTER DISCARDED, one detector over from assertion 2b's.
# `unregistered-drift.sh` emits `CORE-AT-THEIRS` for a consumer file already byte-identical to
# theirs, and SKILL.md step 7 names that row the tell that the base handed to the scan is STALE.
# Every status that detector emits means "consumer edits vs base", so against a base that is
# already theirs the whole set describes the wrong comparison — the list is SILENT about in-place
# core edits rather than clean on them. The row carries no `HARD-` prefix on purpose, so this
# wrapper's only reader dropped it and the run rendered as the affirmative empty line.
#
# THE WORLD IS BUILT, NOT FOUND, AND ASSERTION 3 ABOVE LEFT THE TREE WHERE IT IS NEEDED. Every
# seeded file now holds BASE's bytes, which is CORE-OK; writing ONE of them to THEIRS_ADV's bytes
# is the only shape that reaches the at-theirs arm, because the arm sits BELOW the byte-identical
# -to-base test and above `is_unregistered`. Measured while building it: the natural first choice
# — a path byte-identical at both refs — is claimed by CORE-OK and never reaches the branch.
#
# BESIDE, NOT INSTEAD. `:136` and `:192` both require `0 HARD blockers.` PRESENT on a clean tree
# and `:192` is the positive control guarding the refusal arm's absence half, so a suppressing
# read-out would turn a live control into a failure. Both halves are asserted in one run.
git -C "$DIST" show "$THEIRS_ADV:core/$MOVED_REL" > "$CONSUMER/.claude/$MOVED_REL"
# CONTROL FIRST, ON THE DETECTOR: the world reaches the at-theirs arm at all. Without this the
# two assertions below are statements about a run that never classified the file, and a wrapper
# that had stopped reading the row entirely would look identical to one on a clean tree.
a3b_ud="$(bash "$(dirname "$HB")/unregistered-drift.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS_ADV" 2>/dev/null)"
a3b_at="$(printf '%s\n' "$a3b_ud" | awk -F'\t' '$1=="CORE-AT-THEIRS"{c++} END{print c+0}')"
a3b_ok="$(printf '%s\n' "$a3b_ud" | awk -F'\t' '$1=="CORE-OK"{c++} END{print c+0}')"
if [ "$a3b_at" -ge 1 ] && [ "$a3b_ok" -ge 1 ]; then
  ok "CONTROL: the seeded world reaches the at-theirs arm — $a3b_at CORE-AT-THEIRS row(s) beside $a3b_ok CORE-OK row(s) in the same scan"
else
  bad "CONTROL: the scan emitted $a3b_at CORE-AT-THEIRS and $a3b_ok CORE-OK rows (both must be non-zero) — the world does not express a stale base, so every assertion below is about a run that never classified it"
fi
a3b_out="$(bash "$HB" "$DIST" "$BASE" "$CONSUMER" "$THEIRS_ADV" 2>/dev/null)"
if grep -q '^CORE-AT-THEIRS' <<<"$a3b_out"; then
  ok "a stale base is qualified in the rendered list: the CORE-AT-THEIRS row reaches the region the operator approves apply from"
else
  bad "print mode rendered no CORE-AT-THEIRS row on a run whose scan emitted $a3b_at of them — the one finding is 'the list you are reading was computed against the wrong base', and it was filtered out"
fi
# THE OTHER HALF, IN THE SAME RUN. A read-out that SUPPRESSED the affirmative line would satisfy
# the assertion above and break `:136` and `:192`, and the two failures would read as unrelated.
if grep -q '0 HARD blockers' <<<"$a3b_out"; then
  ok "  ...BESIDE the affirmative line, which is still rendered — the detector classified, so this is a qualifier and not a refusal"
else
  bad "  the CORE-AT-THEIRS read-out SUPPRESSED '0 HARD blockers.' — a classified row is not a refusal, and :136/:192 require that line present on a clean tree"
fi
# CONTROL: a world with NO at-theirs file must not carry the row. Without this the arm passes
# against a wrapper that prints the qualifier on every run, which discriminates nothing.
git -C "$DIST" show "$BASE:core/$MOVED_REL" > "$CONSUMER/.claude/$MOVED_REL"
a3b_ctl="$(bash "$HB" "$DIST" "$BASE" "$CONSUMER" "$THEIRS_ADV" 2>/dev/null)"
if grep -q '^CORE-AT-THEIRS' <<<"$a3b_ctl"; then
  bad "CONTROL: the qualifier was printed on a tree carrying NO file at theirs' bytes — it fires unconditionally and says nothing about the base"
else
  ok "CONTROL: a tree with no at-theirs file carries no stale-base qualifier"
fi

# --- Assertion 3c: CHECK MODE warns on the same world, and does NOT fail ------------------
# THE HALF THE DEGENERATE NOTE ALREADY HAD AND THIS ROW DID NOT. Check mode's contract is "the
# report names every HARD item the detectors emit"; against a stale base that set is smaller than
# it should be but honestly computed, so `--check` was certifying a report COMPLETE against the
# wrong comparison, silently. WARNED, NOT FAILED, for the reason the refusal arm states in the
# other direction: reddening an accurate report is the wedge-live-work shape.
#
# STDERR IS THE RIGHT CHANNEL HERE AND THE WRONG ONE IN PRINT MODE, and the two are asserted
# separately for that reason — check mode renders no region, while `emit-report.sh:814` invokes
# print mode with `2>/dev/null`, so a print-mode qualifier on stderr would never reach the
# artifact the operator approves from. Assertion 3b reads stdout; this one reads stderr.
git -C "$DIST" show "$THEIRS_ADV:core/$MOVED_REL" > "$CONSUMER/.claude/$MOVED_REL"
a3c_err="$MW_ERR_A"
bash "$HB" --check "$REPORT_BAD" "$DIST" "$BASE" "$CONSUMER" "$THEIRS_ADV" >/dev/null 2>"$a3c_err"; a3c_rc=$?
if grep -q 'CORE-AT-THEIRS' "$a3c_err"; then
  ok "--check WARNS on a stale base — it no longer certifies a report complete against a comparison the detector says was computed wrong"
else
  bad "--check said NOTHING about a stale base (rc=$a3c_rc) — it certifies the report complete against a HARD set the detector itself reports as computed against the wrong base"
fi
if [ "$a3c_rc" -eq 0 ]; then
  ok "  ...and does NOT fail: the set is smaller than it should be but honestly computed, so reddening it would wedge an accurate report"
else
  bad "  --check EXITED $a3c_rc on a stale base — that is the refusal tier, which reds a report accurate about everything it could see"
fi
# CONTROL, in the same shape: no at-theirs file, no warning, same exit. An arm reading only the
# presence of the message passes against a wrapper that prints it on every check.
git -C "$DIST" show "$BASE:core/$MOVED_REL" > "$CONSUMER/.claude/$MOVED_REL"
a3c_err2="$MW_ERR_B"
bash "$HB" --check "$REPORT_BAD" "$DIST" "$BASE" "$CONSUMER" "$THEIRS_ADV" >/dev/null 2>"$a3c_err2"; a3c_rc2=$?
if grep -q 'CORE-AT-THEIRS' "$a3c_err2"; then
  bad "CONTROL: --check warned about a stale base on a tree that has none — the warning fires unconditionally"
else
  ok "CONTROL: --check on a tree with no at-theirs file emits no stale-base warning, at the same exit ($a3c_rc2)"
fi

# The detector directory is copied per arm below: `hard-blockers.sh` resolves its two detectors
# as siblings of its own path, so a lone script copy finds neither and emits an empty list.
DETDIR="$(dirname "$HB")"
MW="$(mktemp -d "${TMPDIR:-/tmp}/rbl-copy.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
cp -R "$DETDIR/." "$MW/" 2>/dev/null

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
  rm -rf "$a4_w"; cp -R "$DETDIR/." "$a4_w/" 2>/dev/null

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
a5_w="$MW/flags"; rm -rf "$a5_w"; cp -R "$DETDIR/." "$a5_w/" 2>/dev/null
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
a6_w="$MW/owns"; rm -rf "$a6_w"; cp -R "$DETDIR/." "$a6_w/" 2>/dev/null
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
report_end reconcile-blocking-list
