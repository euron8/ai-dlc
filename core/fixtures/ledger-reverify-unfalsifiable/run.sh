#!/usr/bin/env bash
# ledger-reverify-unfalsifiable/run.sh — prove ledger-reverify.sh separates a live
# `theirs_lacks` entry from an UNFALSIFIABLE one when both are absent at base and theirs.
#
# The verdict must be driven by consumer reachability and by nothing else, so this asserts
# all four directions: it FIRES on invented prose, it PASSES on a real anchor, the verdict
# FOLLOWS the anchor under mutation, and it REFUSES to decide when the scan set is missing.
# A check proven only to fire is indistinguishable from one that fires on everything.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
verdict() { bash "$RV" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null |
              awk -F'\t' -v l="$1" '$2 ~ l {print $1; exit}'; }

echo "ledger-reverify-unfalsifiable:"

# --- Assertion 0: SANITY — neither substring is at base OR theirs --------------------
# Without this the two entries are not the same case and nothing below is attributable.
s_absent=1
for s in -- "--strict-provenance" "strict provenance enforced by default"; do
  [ "$s" = "--" ] && continue
  for ref in "$BASE" "$THEIRS"; do
    git -C "$DIST" show "$ref:core/scripts/validate-thing.sh" | grep -qF -- "$s" && s_absent=0
  done
done
if [ "$s_absent" -eq 1 ]; then
  ok "before: BOTH substrings absent at base AND theirs (the undecidable-by-two-refs case)"
else
  bad "FIXTURE BROKEN — a substring is present at a ref"; echo
  echo "ledger-reverify-unfalsifiable: FIXTURE BROKEN" >&2; exit 2
fi

# --- Assertion 1: the check PASSES on a real anchor ----------------------------------
[ "$(verdict PC-GOOD)" = "STILL-LIVE" ] \
  && ok "PC-GOOD (flag the consumer implements) → STILL-LIVE" \
  || bad "PC-GOOD → $(verdict PC-GOOD), expected STILL-LIVE — the check fires on everything"

# --- Assertion 2: the check FIRES on invented prose ----------------------------------
[ "$(verdict PC-BAD)" = "NEEDS-REVIEW" ] \
  && ok "PC-BAD (prose describing the fix) → NEEDS-REVIEW" \
  || bad "PC-BAD → $(verdict PC-BAD), expected NEEDS-REVIEW — unfalsifiable predicate not caught"

# --- Assertion 3: MUTATION — the verdict follows the anchor, not the entry -----------
# Remove ONLY the anchor. keep.sh survives, so the scan set stays non-empty and the
# undecidable path cannot supply a false pass.
sed -i.bak 's/--strict-provenance/--other-flag/' "$CONSUMER/scripts/thing.sh" && rm -f "$CONSUMER/scripts/thing.sh.bak"
git -C "$CONSUMER" -c user.email=f@f -c user.name=f add -A >/dev/null 2>&1
git -C "$CONSUMER" -c user.email=f@f -c user.name=f commit -qm mutate >/dev/null 2>&1
[ "$(verdict PC-GOOD)" = "NEEDS-REVIEW" ] \
  && ok "mutation: anchor removed from the consumer → PC-GOOD flips to NEEDS-REVIEW" \
  || bad "mutation: PC-GOOD → $(verdict PC-GOOD), expected NEEDS-REVIEW — verdict is not driven by the anchor"

# --- Assertion 4: UNDECIDABLE — no scan set must not manufacture an accusation -------
# A missing input is not evidence of a bad predicate. It must say so, not accuse.
rm -rf "$CONSUMER/.git"
out="$(bash "$RV" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
if printf '%s' "$out" | grep -q "STILL-LIVE.*PC-BAD" && printf '%s' "$out" | grep -q "NOT checked"; then
  ok "no tracked file list → STILL-LIVE + 'reachability NOT checked' (undecidable says so)"
else
  bad "undecidable path did not degrade safely: $(printf '%s' "$out" | awk -F'\t' '{print $1}' | tr '\n' ' ')"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "ledger-reverify-unfalsifiable: PASS"
else
  echo "ledger-reverify-unfalsifiable: FAIL ($fails)" >&2; exit 1
fi
