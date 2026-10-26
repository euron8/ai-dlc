#!/usr/bin/env bash
# receipt-bl805.sh -- BL-805's receipt: drive the SHIPPED foreground-budget hook with the real
# graph waiter shape and require (1) a deny whose reason names `run_in_background: true`, and
# (2) an allow, on the same command joined with `;` instead of a lone `&`. Exit 0 = fixed,
# 1 = still reproduces, 9 = the hook is absent (the receipt cannot measure its subject).
#
# TWO SEEDS ON PURPOSE. The deny seed alone is satisfied by a hook that denies every waiter
# call; the allow seed alone by a hook that denies nothing. A lone-`&` test widened to match
# `2>&1` fails the allow seed, and a hook that never denies fails the deny seed, so each
# regression is caught by a different half. Scored against the fix (0), base bd0be5e51 (1), a
# widened lone-`&` test (1) and a deny gated behind a declared timeout (1).
#
# The hook resolves nothing from the working directory, so the repo root is found by walking up
# for the hook itself, never by counting `..` hops.
set -uo pipefail
d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v jq >/dev/null 2>&1 || exit 9
h=""
while [ "$d" != "/" ]; do
  for c in "$d/core/hooks/ai-dlc-foreground-budget.sh" "$d/.claude/hooks/ai-dlc-foreground-budget.sh"; do
    [ -f "$c" ] && { h="$c"; break 2; }
  done
  d="$(dirname "$d")"
done
[ -n "$h" ] || exit 9
w='bash scripts/ai-dlc/wait-for-deliverable.sh x >/dev/null 2>&1'
deny="$(printf '{"tool_name":"Bash","tool_input":{"command":"%s & echo armed"}}' "$w" | bash "$h" 2>/dev/null)"
allow="$(printf '{"tool_name":"Bash","tool_input":{"command":"%s; echo armed"}}' "$w" | bash "$h" 2>/dev/null)"
# Decide with jq, never on the output's spacing: compact and pretty JSON carry one decision.
printf '%s' "$deny" | jq -e '.hookSpecificOutput.permissionDecision == "deny" and (.hookSpecificOutput.permissionDecisionReason | contains("run_in_background: true"))' >/dev/null 2>&1 || exit 1
# The allow seed must be "not a deny": empty output, or output carrying no deny decision.
if [ -n "$allow" ]; then
  printf '%s' "$allow" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1 && exit 1
fi
exit 0
