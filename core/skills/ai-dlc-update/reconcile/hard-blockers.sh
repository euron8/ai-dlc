#!/usr/bin/env bash
# hard-blockers.sh — the reconcile's blocking list, RENDERED from the detectors, and a check that
# the report actually contains every one.
#
# WHY THIS EXISTS. The dry-run report is authored by the update skill's LLM from the detectors'
# output. Nothing forced every `HARD-*` line the detectors emit to appear in it — and on a real
# pull one did not: `unregistered-drift.sh` flagged an in-place edit to a core schema
# (`provenance-block.json`) as HARD, twice, and both reports said "no unregistered core drift". A
# blocker dropped from the report is a blocker the operator approves `apply` without ever seeing —
# and `apply` then overwrites the consumer's edit silently. The detector was fixed; the REPORT
# un-reported it. So: the blocking list is now a RENDERED artifact (print mode), and `--check`
# fails if the report is missing any HARD item the detectors report. Same posture as the gate's
# verdict.sh — the tool's output is ground truth; an LLM summary of it must not be able to drop a
# line.
#
# Usage:
#   hard-blockers.sh <dist> <base> <consumer> <theirs>                 # print the canonical HARD list
#   hard-blockers.sh --check <report.md> <dist> <base> <consumer> <theirs>
#   hard-blockers.sh --post-apply <dist> <base> <consumer> <theirs>    # re-run AFTER apply wrote core
#   …and, for a caller that has ALREADY run a detector in this same invocation:
#     --ld-rows <file> --ld-rc <n>    layer-drift.sh's rows and exit status, verbatim
#     --ud-rows <file> --ud-rc <n>    unregistered-drift.sh's rows and exit status, verbatim
# Exit:
#   print : 0 always. An empty list prints "0 HARD blockers." (affirmative, not silence) — unless a
#           detector REFUSED, which renders as a DETECTOR-REFUSED row instead. See below.
#   check : 0 = the report contains every HARD blocker's path; 1 = one or more MISSING (report
#           unsound); 2 = usage / missing report / a rows flag supplied without its rc.
#
# THE ROWS FLAGS EXIST BECAUSE THE SLOWEST DETECTOR IN THE SET WAS RUNNING TWICE PER RENDER.
# `emit-report.sh` needs all three OUTPUTS and was deriving them from three PROCESSES: it invoked
# this wrapper (which runs both detectors) and then invoked the same two detectors AGAIN to render
# their own sections. Measured on the reference consumer, both call sites byte-identical — 50 rows
# from layer-drift.sh, 85 from unregistered-drift.sh, with a degenerate-range control proving the
# comparison could report DIFFER: layer-drift.sh 19-20s, unregistered-drift.sh 2-3s, this wrapper
# 21-22s, the whole render 60-64s. So roughly a third of every render recomputed, against refs that
# cannot move within one invocation — and `--verify` re-renders, and `apply.sh` gates its writes on
# `--verify`, so a pull paid it three times over.
#
# THE SPLIT STAYS HERE. The caller supplies ROWS; it does not supply a base. `UD_BASE` below and the
# `--post-apply` rule that moves it are this wrapper's whole reason for existing, and pushing them
# into the caller would put the trap one program further along. `--post-apply` with `--ud-rows` is
# therefore REFUSED, not silently honoured: rows computed by a caller were computed at the pull's
# base, and post-apply that base is wrong for this detector by construction.
#
# ROWS REQUIRE THEIR rc, AND THAT PAIRING IS ENFORCED RATHER THAN DOCUMENTED. An empty row set means
# "clean" or "never ran" and those are the same bytes; the exit status is the only thing that
# separates them. A rows flag without its rc is a usage error (exit 2), which makes the ambiguous
# state unconstructible instead of detectable.
#
# The two detectors take their args in DIFFERENT orders (a pre-existing quirk); this wraps both:
#   unregistered-drift.sh <dist> <base> <consumer> <theirs>   -> STATUS<TAB>FILE<TAB>DETAIL
#   layer-drift.sh        <dist> <base> <theirs> <consumer>   -> STATUS<TAB>ENTRY<TAB>TGT<TAB>DETAIL
# Field 2 is the path in both — the canonical id.
#
# `--post-apply` EXISTS BECAUSE THE TWO DETECTORS WANT DIFFERENT BASES ONCE APPLY HAS WRITTEN
# CORE, AND THIS WRAPPER HAD ONE. SKILL.md step 7 splits them per script — `unregistered-drift.sh`
# takes `theirs`, because its statuses mean "consumer edits vs base" and core now sits at theirs;
# `layer-drift.sh` keeps the PULL's base, because its subject is what moved across the range and
# its `ADJUDICATED` clauses are computed over exactly that. A caller with one base has to pick a
# detector to be wrong about: the pull's base makes `unregistered-drift.sh` report
# `HARD-UNREGISTERED-CORE-DRIFT` against text `apply` itself just wrote, and `theirs` disarms
# `layer-drift.sh`'s LC-A1 arm so this wrapper prints a clean sheet on a tree where every
# adjudication is still owed. Both were measured on the reference consumer, two pulls running,
# and filed as PC-S302-HARD-BLOCKERS-HAS-NO-POST-APPLY-GUARD.
#
# THE FLAG CARRIES THE RULE RATHER THAN THE CALLER REMEMBERING IT. Taking a second base
# positionally would work and would put the same trap one argument further along; the phase is
# what the caller actually knows, so the phase is what it states. Pre-apply behaviour is
# byte-identical to before, which is why no existing call site changes.
set -uo pipefail

MODE=print
REPORT=""
POST_APPLY=no
LD_ROWS_FILE=""
UD_ROWS_FILE=""
LD_RC_IN=""
UD_RC_IN=""
# A LOOP, NOT TWO IFS, so the flags compose in either order. `--check --post-apply` and
# `--post-apply --check` are the same invocation; a hand-unrolled pair silently accepts one
# ordering and treats the other's flag as the <dist> argument.
while :; do
  case "${1:-}" in
    --check)
      MODE=check
      REPORT="${2:?usage: hard-blockers.sh --check <report.md> <dist> <base> <consumer> <theirs>}"
      shift 2 ;;
    --post-apply)
      POST_APPLY=yes
      shift ;;
    --ld-rows)
      LD_ROWS_FILE="${2:?usage: --ld-rows <file>}"
      shift 2 ;;
    --ud-rows)
      UD_ROWS_FILE="${2:?usage: --ud-rows <file>}"
      shift 2 ;;
    --ld-rc)
      LD_RC_IN="${2:?usage: --ld-rc <n>}"
      shift 2 ;;
    --ud-rc)
      UD_RC_IN="${2:?usage: --ud-rc <n>}"
      shift 2 ;;
    *) break ;;
  esac
done
DIST="${1:?usage: hard-blockers.sh [--check <report>] [--post-apply] <dist> <base> <consumer> <theirs>}"
BASE="${2:?}"
CONSUMER="${3:?}"
THEIRS="${4:?}"

SELF="$(cd "$(dirname "$0")" && pwd)"
UD="$SELF/unregistered-drift.sh"
LD="$SELF/layer-drift.sh"

# EACH ROWS FLAG REQUIRES ITS rc. Empty rows mean "clean" or "never ran", and only the status
# separates them; accepting one without the other would let a caller construct the ambiguity this
# wrapper is being changed to STOP swallowing.
#
# Written out twice rather than looped over variable NAMES: the indirection costs an `eval` per
# field, and `bash` here is 3.2 with no associative arrays to make it honest.
rows_rc_pair() { # rows_rc_pair <rows> <rc> <rows-flag> <rc-flag>
  if [ -n "$1" ] && [ -z "$2" ]; then
    echo "hard-blockers: $3 was supplied without $4. Empty rows mean 'clean' or 'never ran' and only the exit status tells them apart; a rows set with no status is the ambiguity this flag exists to remove." >&2
    exit 2
  fi
  if [ -z "$1" ] && [ -n "$2" ]; then
    echo "hard-blockers: $4 was supplied without $3. A status with no rows describes nothing." >&2
    exit 2
  fi
  if [ -n "$1" ] && [ ! -f "$1" ]; then
    echo "hard-blockers: $3 names no readable file: $1" >&2
    exit 2
  fi
}
rows_rc_pair "$LD_ROWS_FILE" "$LD_RC_IN" --ld-rows --ld-rc
rows_rc_pair "$UD_ROWS_FILE" "$UD_RC_IN" --ud-rows --ud-rc

# Only the unregistered-drift base moves. `layer-drift.sh` is passed the pull's base in BOTH
# phases, which is what keeps true the false-positive derivation in that script's own header —
# "every programmatic caller passes the pull's base".
UD_BASE="$BASE"
[ "$POST_APPLY" = yes ] && UD_BASE="$THEIRS"

# `--post-apply` MOVES THE BASE THIS WRAPPER PASSES, so rows a caller computed at the pull's base
# are the WRONG rows post-apply — silently, and in the direction that reports drift against text
# `apply` itself just wrote. Refuse the combination rather than honour it.
if [ "$POST_APPLY" = yes ] && [ -n "$UD_ROWS_FILE" ]; then
  echo "hard-blockers: --post-apply with --ud-rows is refused. Post-apply this wrapper passes 'theirs' to unregistered-drift.sh, and rows supplied by a caller were computed at the pull's base — the combination would report HARD-UNREGISTERED-CORE-DRIFT against text apply itself wrote. Drop --ud-rows and let the wrapper run it." >&2
  exit 2
fi

# RUN EACH DETECTOR ONCE AND KEEP ITS ROWS — or take rows a caller already computed in this same
# pull. The blocking list needs the `HARD-*` rows and the qualifier below needs a row that is
# deliberately NOT `HARD-*`, so the output is read twice either way; what must not happen twice is
# the RUN.
LD_ROWS=""
LD_RC=0
if [ -n "$LD_ROWS_FILE" ]; then
  LD_ROWS="$(cat "$LD_ROWS_FILE")"
  LD_RC="$LD_RC_IN"
elif [ -f "$LD" ]; then
  LD_ROWS="$(bash "$LD" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null)"
  LD_RC=$?
fi

UD_ROWS=""
UD_RC=0
if [ -n "$UD_ROWS_FILE" ]; then
  UD_ROWS="$(cat "$UD_ROWS_FILE")"
  UD_RC="$UD_RC_IN"
elif [ -f "$UD" ]; then
  UD_ROWS="$(bash "$UD" "$DIST" "$UD_BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
  UD_RC=$?
fi

# THE ROW THIS WRAPPER WAS STRUCTURALLY BLIND TO. `DRIFT-RANGE-DEGENERATE` is emitted by
# `layer-drift.sh` when its two refs resolve to the same commit, and it was given a prefix
# outside `HARD-`/`OVERRIDE-`/`EXTENSION-` on purpose — it describes the INVOCATION, not an
# entry, so no layer-contract clause could own it. The consequence nobody had joined up: the
# `^HARD-` filter below is the only reader this wrapper has, so the one caller that most needs
# that warning was the one caller that discarded it, and printed `0 HARD blockers.` instead.
# Read it out separately rather than widening the filter — widening would put a non-clause
# status into a list every downstream reader treats as clause-owned.
DEGENERATE="$(printf '%s\n' "$LD_ROWS" | awk -F'\t' '$1=="DRIFT-RANGE-DEGENERATE"{print $1; exit}')"

collect() {
  printf '%s\n' "$UD_ROWS" \
    | awk -F'\t' '$1 ~ /^HARD-/ { print $1"\t"$2 }'
  printf '%s\n' "$LD_ROWS" \
    | awk -F'\t' '$1 ~ /^HARD-/ { print $1"\t"$2 }'
}

BLOCKERS="$(collect | sort -u)"

# A REFUSING DETECTOR MUST NOT RENDER AS A CLEAN SHEET, AND UNTIL NOW IT DID.
#
# Measured before this arm existed, in a sandbox copy of reconcile/ with an unmutated control
# rendering correctly through the same sandbox: stub `layer-drift.sh` to `exit 2` and this wrapper
# printed `0 HARD blockers.` at exit 0. Stub `unregistered-drift.sh` the same way and it did too.
# `0 HARD blockers.` is the ONE line the whole HARD- contract keys on — SKILL.md tells the operator
# a HARD status blocks apply, so the affirmative empty line is what authorises the write. A detector
# that never classified was producing it.
#
# The duplication is what had been MASKING this: emit-report.sh ran the two detectors again itself
# and rendered `DETECTOR-REFUSED` from their exit codes, so the false clean line sat beside a true
# refusal in the same report. De-duplicating without this arm would have deleted the only signal.
# That is why the two changes ship together and neither is safe alone.
#
# NAMED PER DETECTOR, not as one flag, because the remedies differ and the operator is being told
# which program to run. Rendered INSIDE the generated region for the same reason the degenerate
# note is: the one programmatic reader invokes this with `2>/dev/null`, so stderr never reaches the
# artifact the operator approves from.
#
# `%-32s %s`, THE SAME PADDING AS EVERY OTHER ROW THIS SCRIPT RENDERS. The status sits at column 0
# either way, which is all `--verify`'s `unseen_rows()` and its `grep -c '^DETECTOR-REFUSED'` need;
# matching the blocking list's own convention is so the region reads as one table rather than two.
#
# A CALLER THAT SUPPLIED THE ROWS ALREADY RENDERED THE REFUSAL, AND A SECOND COPY IS NOT A SECOND
# FINDING. `emit-report.sh` runs each detector itself and renders `DETECTOR-REFUSED` in that
# detector's own section from the same rc it hands down here; emitting it again in the blocking list
# would put two rows in the region for one dead detector. `--verify` COUNTS these rows —
# `refused_new` decides whether a mismatch can be BLOCKERS-RESOLVED — so a duplicate is not
# cosmetic: it doubles a count the classifier reads. The rows-supplying caller owns the rendering;
# this wrapper owns it only when it ran the detector itself, which is every standalone invocation.
REFUSALS=""
#
# THE ROW MUST NOT QUOTE THE LINE IT SUPPRESSES. The first cut said "this list is NOT a finding of
# '0 HARD blockers.'" — which put that exact string INTO the region, so every reader testing whether
# the clean line is absent found it inside the refusal explaining its absence. Measured: the
# fixture arm asserting suppression failed against a wrapper that was suppressing correctly. Text
# about a program is not the program, and here the text was scored as the program.
if [ -z "$LD_ROWS_FILE" ] && [ "${LD_RC:-0}" -ne 0 ]; then
  REFUSALS="$(printf '%-32s %s\n' "DETECTOR-REFUSED" "layer-drift.sh exited ${LD_RC} without classifying, so this list is NOT a clean sheet — the layer's HARD rows, if any, were never computed. Run it directly: reconcile/layer-drift.sh <dist> <base> <theirs> <consumer>")"
fi
if [ -z "$UD_ROWS_FILE" ] && [ "${UD_RC:-0}" -ne 0 ]; then
  _ud_refusal="$(printf '%-32s %s\n' "DETECTOR-REFUSED" "unregistered-drift.sh exited ${UD_RC} without classifying, so this list is NOT a clean sheet — in-place core edits, if any, were never computed. Run it directly: reconcile/unregistered-drift.sh <dist> <base> <consumer> <theirs>")"
  if [ -n "$REFUSALS" ]; then REFUSALS="${REFUSALS}
${_ud_refusal}"; else REFUSALS="$_ud_refusal"; fi
fi

DEG_NOTE="this run could not fire layer-drift.sh's range-keyed adjudication arms — base and theirs resolve to the same commit — so the list above is silent about the layer rather than clean on it. Re-run with the PULL's base; post-apply, pass --post-apply."

if [ "$MODE" = "print" ]; then
  echo "<!-- BEGIN GENERATED: hard-blockers — rendered by reconcile/hard-blockers.sh; do not hand-edit -->"
  # THE REFUSAL ROWS COME FIRST AND THEY SUPPRESS THE AFFIRMATIVE LINE. An empty blocker list under
  # a refusing detector is not `0 HARD blockers.`; it is a list that was never computed, and the
  # one thing that must not happen is the operator reading the clean line off it.
  # `printf '%s\n'`, NOT `printf '%s'`. Without the newline the END marker is appended to the last
  # refusal row, so the row and the marker become one line — measured, and it defeats any reader
  # anchored on `^<!-- END`.
  [ -n "$REFUSALS" ] && printf '%s\n' "$REFUSALS"
  if [ -z "$BLOCKERS" ]; then
    [ -z "$REFUSALS" ] && echo "0 HARD blockers."
  else
    while IFS="$(printf '\t')" read -r st path; do
      [ -n "$st" ] || continue
      printf '%-32s %s\n' "$st" "$path"
    done <<EOF
$BLOCKERS
EOF
  fi
  # INSIDE THE GENERATED REGION, NOT ON STDERR, and that is the load-bearing choice. The one
  # programmatic reader of print mode is `emit-report.sh`, which invokes this script with
  # `2>/dev/null` — so a qualifier written to stderr would be dropped from the reconcile report,
  # which is the artifact the operator actually approves `apply` from. Nothing byte-compares this
  # region; the only transform applied to it strips the two marker lines.
  [ -n "$DEGENERATE" ] && printf '%-32s %s\n' "DRIFT-RANGE-DEGENERATE" "$DEG_NOTE"
  echo "<!-- END GENERATED: hard-blockers -->"
  exit 0
fi

# --- check mode -------------------------------------------------------------
[ -f "$REPORT" ] || { echo "hard-blockers: report not found: $REPORT" >&2; exit 2; }

# WARNED, NOT FAILED. check mode's contract is "the report names every HARD item the detectors
# emit", and on a degenerate range that set is smaller than it should be — so the check can pass
# while saying less than the operator thinks. Exiting nonzero here would red a report that is
# accurate about everything it could see, which is the wedge-live-work shape; the operator is told
# instead, and the exit code keeps meaning exactly what it meant.
[ -n "$DEGENERATE" ] && echo "hard-blockers: DRIFT-RANGE-DEGENERATE — $DEG_NOTE" >&2

# A REFUSAL IS DIFFERENT FROM A DEGENERATE RANGE AND IT FAILS. The paragraph above turns on the set
# being SMALLER THAN IT SHOULD BE but honestly computed; a refusing detector computed NOTHING, so
# "the report names every HARD item the detectors emit" is vacuously true and the pass is
# meaningless. This is the check-mode half of the swallow measured above: without it, `--check`
# certifies a report as complete against a detector that never ran.
if [ -n "$REFUSALS" ]; then
  printf '%s' "$REFUSALS" >&2
  echo "hard-blockers: a detector REFUSED, so this check cannot establish that the report names every HARD blocker — the set it would be compared against was never computed. Fix the detector and re-check; do not read this as a report defect." >&2
  exit 1
fi

missing=0
n=0
if [ -n "$BLOCKERS" ]; then
  while IFS="$(printf '\t')" read -r st path; do
    [ -n "$path" ] || continue
    n=$((n + 1))
    # The report references a blocker by its path (as the tool emits it, possibly with a
    # `.claude/` prefix the substring match tolerates). A path absent from the report is a
    # blocker the operator never saw.
    if ! grep -qF -- "$path" "$REPORT"; then
      echo "FAIL: reconcile report OMITS a HARD blocker the detectors emit: ${st}  ${path}" >&2
      missing=1
    fi
  done <<EOF
$BLOCKERS
EOF
fi

if [ "$missing" -ne 0 ]; then
  echo "" >&2
  echo "hard-blockers: the report does not list every HARD-* item the detectors report. A blocker" >&2
  echo "  dropped from the report is one the operator approves 'apply' without seeing, and apply then" >&2
  echo "  overwrites the consumer edit silently. Regenerate the blocking-layer list from" >&2
  echo "  'hard-blockers.sh <dist> <base> <consumer> <theirs>' and re-emit the report." >&2
  exit 1
fi
echo "hard-blockers: report contains every HARD blocker (${n} total)."
exit 0
