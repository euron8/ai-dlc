#!/bin/bash
# BL-634 receipt. usage: receipt-bl634.sh; run from the repo root.
#   exit 0   the shipped enforcement-map.yaml passes the enforcement-map-yaml-plain fixture, the
#            unquoted base map and a map with only the Check 22 posture unquoted both fail it, and a
#            map with the seven values single-quoted passes it (the fix is present and the check bites)
#   exit 1   any of those four outcomes differs
#   exit 9   the receipt cannot measure: the fixture or map is absent, a seed could not be built,
#            a seed anchor does not match exactly once, or a seed equals the map it should differ from
set -uo pipefail
R=.
FX="$R/core/fixtures/enforcement-map-yaml-plain/run.sh"
MAP="$R/core/skills/ai-dlc/enforcement-map.yaml"
[ -f "$FX" ] || exit 9
[ -f "$MAP" ] || exit 9
T="$(mktemp -d)" || exit 9
# (a) the fix as committed
bash "$FX" "$MAP" >/dev/null 2>&1; a=$?
# (b1) regression: the base map, all seven values plain again
git show 'e91b4d86:core/skills/ai-dlc/enforcement-map.yaml' > "$T/base.yaml" \
  || { echo "b1 seed: e91b4d86 not readable here"; exit 9; }
# The seed must be a real map that differs from the fix, or b1's "kill" is the fixture refusing an empty file.
[ -s "$T/base.yaml" ] || { echo "b1 seed is empty"; exit 9; }
cmp -s "$MAP" "$T/base.yaml" && { echo "b1 seed equals the fix map"; exit 9; }
bash "$FX" "$T/base.yaml" >/dev/null 2>&1; b1=$?
# (b2) regression: ONLY the Check 22 posture unquoted -- its sole indicator is a line-final ':'
awk '/posture: "FAILS the gate on exit 1 and on exit 2/{sub(/posture: "/,"posture: "); o=1} o && /[^\\]"$/{sub(/"$/,""); o=0} {print}' "$MAP" > "$T/eol.yaml"
cmp -s "$MAP" "$T/eol.yaml" && { echo "b2 seed did not apply"; exit 9; }
bash "$FX" "$T/eol.yaml" >/dev/null 2>&1; b2=$?
# (c) second correct spelling: the seven values SINGLE-quoted (a doubled apostrophe, no \" escape).
# The seven values are keyed on CONTENT, never on a line number: a line number moves whenever main edits
# the map, and because (c) asserts PASS a seed applied to the wrong lines would still read 0.
# Three postures are identical text, so each is keyed on the unique "site:" line above it (S1-S3, whole
# line); the other four are keyed on a unique fixed string of their own key line (K1-K4).
S1='      - site: gate-validation.md Check 2'
S2='      - site: gate-validation.md Check 2 (suppression lifetime)'
S3='      - site: gate-validation.md Check 2a'
K1='compare status values programmatically'
K2='posture: "FAILS the gate on exit 1 and on exit 2'
K3='posture: "FAILS the gate (exit 0 required; exit 2 on absent evidence'
K4='asserts: "for every guard ledger row with `definition_bound: true`'
n=""
for s in "$S1" "$S2" "$S3"; do
  n="$(grep -cxF -- "$s" "$MAP")" || n=0
  [ "$n" = 1 ] || { echo "c anchor matches $n times: $s"; exit 9; }
done
for k in "$K1" "$K2" "$K3" "$K4"; do
  n="$(grep -cF -- "$k" "$MAP")" || n=0
  [ "$n" = 1 ] || { echo "c anchor matches $n times: $k"; exit 9; }
done
S1="$S1" S2="$S2" S3="$S3" K1="$K1" K2="$K2" K3="$K3" K4="$K4" awk -v q="'" '
  $0 == ENVIRON["S1"] || $0 == ENVIRON["S2"] || $0 == ENVIRON["S3"] { arm=1; print; next }
  arm && index($0, "posture: \"") { o=1; arm=0 }
  index($0, ENVIRON["K1"]) || index($0, ENVIRON["K2"]) || index($0, ENVIRON["K3"]) || index($0, ENVIRON["K4"]) { o=1 }
  o { cl = ($0 ~ /[^\\]"$/); if (cl) sub(/"$/, ""); gsub(/\\"/, "\""); gsub(q, q q); sub(/: "/, ": " q); if (cl) { $0 = $0 q; o=0 } }
  { print }' "$MAP" > "$T/single.yaml"
cmp -s "$MAP" "$T/single.yaml" && { echo "c seed did not apply"; exit 9; }
bash "$FX" "$T/single.yaml" >/dev/null 2>&1; c=$?
echo "a=$a b1=$b1 b2=$b2 c=$c"
[ "$a" -eq 0 ] && [ "$b1" -eq 1 ] && [ "$b2" -eq 1 ] && [ "$c" -eq 0 ]
