#!/usr/bin/env bash
# fu4.sh — per s320 adversarial p2/p3 MAJOR: the defect ("old") and fix tokens, counted with
# grep -c -F in r3 (the text p2 reviewed) and r4 (the shipped text), plus r4 line numbers.
# A fix token absent from r3 and present in r4 is a fix that shipped.
#
# Usage: fu4.sh <r3-file> <r4-file>
#   r3: graph blob a4010b9891ee2c14e113cb045133e53999adb972 (after the p1 serial repair)
#   r4: graph blob 1106438812b568edbd549e53f41f00506919f267 (shipped)
# Control: the CONTROL row is a token no revision carries and must read r3=0 r4=0.
set -u
[ $# -eq 2 ] || { echo "usage: fu4.sh <r3-file> <r4-file>" >&2; exit 2; }
R3="$1"; R4="$2"
[ -f "$R3" ] && [ -f "$R4" ] || { echo "fu4.sh: revision file missing" >&2; exit 2; }
cnt() { local n; n="$(grep -c -F -- "$1" "$2")" || n=0; printf '%s' "$n"; }
t() {
  local lines
  lines="$(grep -n -F -- "$3" "$R4" | cut -d: -f1 | head -4 | tr '\n' ',')"
  printf '%-10s %-6s %-58s r3=%s r4=%s r4L=%s\n' "$1" "$2" "$3" "$(cnt "$3" "$R3")" "$(cnt "$3" "$R4")" "$lines"
}
t p2-1F1 fix 'pipeline-snapshot.md` changed'
t p2-1F1 fix 'git diff --name-only 91a665334 b20bd5442 -- _bmad-output/pipeline-snapshot.md'
t p2-2F1 old 'not actually fee-inclusive'
t p2-2F1 fix 'already counts something it should not'
t p2-2F2 fix "action_type=\"FEE_COLLECT\""
t p2-4F1 fix 'owns pricing a re-target'
t p2-6F1 fix 'assert il_lt .= 15'
t p2-6F2 fix "sed -n '506,511p' _bmad-output/planning-artifacts/carry-over-backlog.md"
t p2-7F1 fix "grep -c 'claimable_raw' docs/escalations/pending.md"
t p2-c1F1 old 'Dependencies: none; reads precede'
t p2-c1F1 fix 'Dependencies: the Rebalancer half of the Day-0 read'
t p2-c2F1 old 'same pool and lifetime IL figure'
t p2-c2F1 fix 'pool_lifetime_il_usd_lifetime_scope'
t p3-1F1 old 'RewardsCard'
t p3-c2F1 old 'also covers closed positions'
t p3-c2F1 fix '_acc_il_usd_lifetime_scope +='
t CONTROL neg 'ZZ-NEVER-TOKEN-b810'
