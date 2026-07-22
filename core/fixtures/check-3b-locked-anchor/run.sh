#!/usr/bin/env bash
# Exercise validate-locked-anchor.sh against the check-3b fixture pair.
# Exit 0 iff bad-story.md FAILS and good-story.md PASSES.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
# Locate the validator: installed consumer path first, then upstream core path.
VALIDATOR=""
for cand in \
  "$DIR/../../scripts/validate-locked-anchor.sh" \
  "$DIR/../../../scripts/ai-dlc/validate-locked-anchor.sh" \
  "$DIR/../../core/scripts/validate-locked-anchor.sh"; do
  [ -f "$cand" ] && VALIDATOR="$cand" && break
done
if [ -z "$VALIDATOR" ]; then
  echo "run.sh: could not locate validate-locked-anchor.sh" >&2
  exit 2
fi

rc=0

if "$VALIDATOR" "$DIR/bad-story.md" >/dev/null 2>&1; then
  echo "FAIL: bad-story.md should have been rejected but passed" >&2
  rc=1
else
  echo "ok: bad-story.md rejected"
fi

if "$VALIDATOR" "$DIR/good-story.md" >/dev/null 2>&1; then
  echo "ok: good-story.md accepted"
else
  echo "FAIL: good-story.md should have passed but was rejected" >&2
  rc=1
fi

[ "$rc" -eq 0 ] && echo "check-3b fixture: PASS"
exit "$rc"
