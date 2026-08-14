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
# Exit:
#   print : 0 always. An empty list prints "0 HARD blockers." (affirmative, not silence).
#   check : 0 = the report contains every HARD blocker's path; 1 = one or more MISSING (report
#           unsound); 2 = usage / missing report.
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

# Only the unregistered-drift base moves. `layer-drift.sh` is passed the pull's base in BOTH
# phases, which is what keeps true the false-positive derivation in that script's own header —
# "every programmatic caller passes the pull's base".
UD_BASE="$BASE"
[ "$POST_APPLY" = yes ] && UD_BASE="$THEIRS"

# RUN layer-drift.sh ONCE AND KEEP ITS ROWS. The blocking list needs its `HARD-*` rows and the
# qualifier below needs a row that is deliberately NOT `HARD-*`; running it twice would double
# the cost of the slowest detector to read one line.
LD_ROWS=""
[ -f "$LD" ] && LD_ROWS="$(bash "$LD" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null || true)"

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
  [ -f "$UD" ] && bash "$UD" "$DIST" "$UD_BASE" "$CONSUMER" "$THEIRS" 2>/dev/null \
    | awk -F'\t' '$1 ~ /^HARD-/ { print $1"\t"$2 }'
  printf '%s\n' "$LD_ROWS" \
    | awk -F'\t' '$1 ~ /^HARD-/ { print $1"\t"$2 }'
}

BLOCKERS="$(collect | sort -u)"

DEG_NOTE="this run could not fire layer-drift.sh's range-keyed adjudication arms — base and theirs resolve to the same commit — so the list above is silent about the layer rather than clean on it. Re-run with the PULL's base; post-apply, pass --post-apply."

if [ "$MODE" = "print" ]; then
  echo "<!-- BEGIN GENERATED: hard-blockers — rendered by reconcile/hard-blockers.sh; do not hand-edit -->"
  if [ -z "$BLOCKERS" ]; then
    echo "0 HARD blockers."
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
