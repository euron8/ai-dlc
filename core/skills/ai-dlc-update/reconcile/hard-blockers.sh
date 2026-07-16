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
# Exit:
#   print : 0 always. An empty list prints "0 HARD blockers." (affirmative, not silence).
#   check : 0 = the report contains every HARD blocker's path; 1 = one or more MISSING (report
#           unsound); 2 = usage / missing report.
#
# The two detectors take their args in DIFFERENT orders (a pre-existing quirk); this wraps both:
#   unregistered-drift.sh <dist> <base> <consumer> <theirs>   -> STATUS<TAB>FILE<TAB>DETAIL
#   layer-drift.sh        <dist> <base> <theirs> <consumer>   -> STATUS<TAB>ENTRY<TAB>TGT<TAB>DETAIL
# Field 2 is the path in both — the canonical id.
set -uo pipefail

MODE=print
REPORT=""
if [ "${1:-}" = "--check" ]; then
  MODE=check
  REPORT="${2:?usage: hard-blockers.sh --check <report.md> <dist> <base> <consumer> <theirs>}"
  shift 2
fi
DIST="${1:?usage: hard-blockers.sh [--check <report>] <dist> <base> <consumer> <theirs>}"
BASE="${2:?}"
CONSUMER="${3:?}"
THEIRS="${4:?}"

SELF="$(cd "$(dirname "$0")" && pwd)"
UD="$SELF/unregistered-drift.sh"
LD="$SELF/layer-drift.sh"

collect() {
  [ -f "$UD" ] && bash "$UD" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null \
    | awk -F'\t' '$1 ~ /^HARD-/ { print $1"\t"$2 }'
  [ -f "$LD" ] && bash "$LD" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null \
    | awk -F'\t' '$1 ~ /^HARD-/ { print $1"\t"$2 }'
}

BLOCKERS="$(collect | sort -u)"

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
  echo "<!-- END GENERATED: hard-blockers -->"
  exit 0
fi

# --- check mode -------------------------------------------------------------
[ -f "$REPORT" ] || { echo "hard-blockers: report not found: $REPORT" >&2; exit 2; }

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
