#!/usr/bin/env bash
# receipt-bl989.sh [<hook> [<validator>]] — BL-989's receipt, run by run.sh beside it on every push.
# Lift arm 8 read `remediator_agent_id` / `repaired_checks` at column 0 only, so a bullet record, the form
# remediator.md teaches every other repair record, left a genuine repair locked out. Holds both halves:
#   R1 a nonce-bound, corroborated BULLET record lifts the deny: the hook allows the lead's edit AND logs
#      GATE_REMEDIATION_LIFTED (an allow with no lift logged is a hook that emitted nothing, never a pass);
#   R2 the hook's repair_value is byte-identical to validate-adversarial-convergence.sh's, exactly one
#      definition in each (arm RR-B's predicate).
# <hook> and <validator> default to the copies this fixture resolves in either install layout; a copy of
# another revision's hook is the must-fail probe. Exit: 0 both arms hold, 1 an arm failed, 2 cannot run.
set -u
D="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
H="${1:-$(pick "$D/../../hooks/ai-dlc-gate-remediation-guard.sh" "$D/../../../.claude/hooks/ai-dlc-gate-remediation-guard.sh")}"
V="${2:-$(pick "$D/../../scripts/validate-adversarial-convergence.sh" "$D/../../../scripts/ai-dlc/validate-adversarial-convergence.sh")}"
[ -n "$H" ] && [ -f "$H" ] || { echo "receipt-bl989: cannot locate the hook" >&2; exit 2; }
[ -n "$V" ] && [ -f "$V" ] || { echo "receipt-bl989: cannot locate validate-adversarial-convergence.sh" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "receipt-bl989: jq absent" >&2; exit 2; }
rfail=0
rok()  { printf '  ok    receipt-bl989 %s\n' "$1"; }
rbad() { printf '  FAIL  receipt-bl989 %s\n' "$1"; rfail=1; }

W="$(bash "$D/seed.sh" open-fail)" && [ -n "$W" ] && [ -s "$W/_bmad-output/pipeline-snapshot.md" ] \
  || { echo "receipt-bl989: seed.sh open-fail produced no workspace" >&2; exit 2; }
printf '%s\n' '{"type":"assistant","content":"dispatching"}' '{"agent_id":"remediator@session-abc123"}' > "$W/transcript.jsonl"
printf '# Gate repair record\n- gate_nonce: story-20260811T193044Z\n- remediator_agent_id: remediator@session-abc123\n- repaired_checks: 7, 3a\n' \
  > "$W/_bmad-output/gate-adjudication/story-20260811T193044Z.repair.md"
out="$(jq -nc --arg f "$W/_bmad-output/planning-artifacts/s302/test-strategy.md" --arg tr "$W/transcript.jsonl" \
  '{session_id:"t", tool_name:"Edit", transcript_path:$tr, tool_input:{file_path:$f}}' \
  | CLAUDE_PROJECT_DIR="$W" AI_DLC_GATE_METRICS="" bash "$H" 2>/dev/null)"
case "$out" in *'"permissionDecision": "deny"'*|*'"permissionDecision":"deny"'*) dn=1 ;; *) dn=0 ;; esac
if [ "$dn" = 0 ] && grep -q 'GATE_REMEDIATION_LIFTED' "$W/_bmad-output/pipeline-continuation-log.md" 2>/dev/null; then
  rok "R1 a bound, corroborated bullet record lifts the deny and logs GATE_REMEDIATION_LIFTED"
else rbad "R1 a bound, corroborated bullet record did not lift (denied=$dn, or no GATE_REMEDIATION_LIFTED logged)"; fi
rm -rf "$W"

nh="$(grep -c '^repair_value() {' "$H")" || nh=0
nv="$(grep -c '^repair_value() {' "$V")" || nv=0
a="$(awk '/^repair_value\(\) \{/,/^\}/' "$H")"; b="$(awk '/^repair_value\(\) \{/,/^\}/' "$V")"
if [ "$nh" = 1 ] && [ "$nv" = 1 ] && [ -n "$a" ] && [ "$a" = "$b" ]; then
  rok "R2 the hook's repair_value is byte-identical to the validator's (one definition each)"
else rbad "R2 repair_value: hook $nh definition(s), validator $nv, bodies $([ -n "$a" ] && [ "$a" = "$b" ] && echo equal || echo differ)"; fi
exit "$rfail"
