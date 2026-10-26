#!/usr/bin/env bash
# fu7.sh — where each p2/p3 defect token first appears across the s320 revisions, so a finding can
# be placed as repair-introduced (absent before the repair that preceded its pass).
#
# Usage: fu7.sh <r1> <r2> <r2b> <r3> <r4>   (graph blobs, read with git -C <graph> cat-file -p)
#   r1  2a209ae17ea51182f5f092405eaf99f7b6f6ddf0  after the party repair
#   r2  c7318d0f12ef998c2b32aa63b928060016fc9465  after the elicitation repair
#   r2b 6824bc3702f040dbd1fcfa93b9fcbf35f2dbc6f6  after the p1 section repair
#   r3  a4010b9891ee2c14e113cb045133e53999adb972  after the p1 serial repair
#   r4  1106438812b568edbd549e53f41f00506919f267  shipped
# Control: the last token is carried by no revision and must read 0 everywhere.
set -u
[ $# -eq 5 ] || { echo "usage: fu7.sh <r1> <r2> <r2b> <r3> <r4>" >&2; exit 2; }
for f in "$@"; do [ -f "$f" ] || { echo "fu7.sh: missing $f" >&2; exit 2; }; done
cnt() { local n; n="$(grep -c -F -- "$1" "$2")" || n=0; printf '%s' "$n"; }
for t in 'not actually fee-inclusive' 'Dependencies: none; reads precede' 'same pool and lifetime IL figure' 'are unchanged between `91a665334` and `b20bd5442`' 'unchanged since filing' 'float(_acc_il_usd_lifetime_scope)' 'ZZ-NEVER-TOKEN-b810'; do
  printf '%-52s r1=%s r2=%s r2b=%s r3=%s r4=%s\n' "$t" \
    "$(cnt "$t" "$1")" "$(cnt "$t" "$2")" "$(cnt "$t" "$3")" "$(cnt "$t" "$4")" "$(cnt "$t" "$5")"
done
