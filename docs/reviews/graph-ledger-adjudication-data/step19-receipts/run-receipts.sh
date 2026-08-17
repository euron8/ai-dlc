#!/usr/bin/env bash
# Run every drafted replacement receipt under the environment the CONSUMER engine
# provides, and report its exit code.
#
# POLARITY, from ledger-reverify.sh's own dispatch (not its header):
#   rc = 0      -> STILL-LIVE      (the defect still reproduces)  <- REQUIRED today
#   rc != 0     -> CLOSE-CANDIDATE (upstream fixed it)            <- FALSE CLOSE today
#   rc 126/127  -> NEEDS-REVIEW    (subject unresolvable)
set -u
# Resolve beside this script, NOT a session scratchpad -- the scratchpad this was
# authored in is unreachable from any later session, and a harness that silently
# finds no receipts prints nothing and reads exactly like a clean run.
SP="$(cd "$(dirname "$0")" && pwd)"

export DIST=/Users/n8/git/ai-dlc
export CONSUMER=/Users/n8/git/graph
export BASE=adec9ae
export THEIRS=$(git -C "$DIST" rev-parse HEAD)

echo "DIST=$DIST  THEIRS=$THEIRS  BASE=$BASE"
echo

live=0; falseclose=0; needsreview=0
for i in 1 2 3 4; do
  f="$SP/batch-$i.md"
  [ -e "$f" ] || { echo "batch-$i: MISSING -- refusing to report a clean run over nothing" >&2; exit 2; }
  LC_ALL=C grep -n '^verify: sh ' "$f" | while IFS= read -r line; do
    ln=${line%%:*}
    body=${line#*:verify: sh }
    out=$(cd "$DIST" && eval "$body" 2>&1); rc=$?
    case "$rc" in
      0)        verdict="STILL-LIVE      ok" ;;
      126|127)  verdict="NEEDS-REVIEW    subject unresolvable" ;;
      *)        verdict="CLOSE-CANDIDATE **FALSE CLOSE**" ;;
    esac
    printf '  batch-%s:%-4s rc=%-3s %s\n' "$i" "$ln" "$rc" "$verdict"
  done
done

echo
echo "=== CONTROL: a receipt that MUST report a live defect (rc=0) ==="
eval 'git -C "$DIST" grep -qF "AI/DLC" "$THEIRS" -- VERSION' 2>/dev/null; echo "  impossible content in VERSION -> rc=$? (non-zero expected)"
eval 'git -C "$DIST" cat-file -e "${THEIRS}:CHANGELOG.md"'; echo "  CHANGELOG.md exists at theirs  -> rc=$? (0 expected)"
