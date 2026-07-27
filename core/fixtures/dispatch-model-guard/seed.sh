#!/usr/bin/env bash
#
# Seeds a throwaway layered-consumer tree for the dispatch-model-guard fixture.
# Prints the WORK dir on stdout; writes $WORK/env.sh for run.sh to source.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# Resolve the root. Fixtures live at core/fixtures/<name>/ upstream and at
# tests/fixtures/<name>/ in a consumer — BOTH are exactly three dirs below root.
# (v0.68.1: the consumer branch read ../.. and resolved one dir too shallow, so
# eight fixtures were green in the distribution and broken in every consumer.
# The distribution always takes the D_ROOT branch, so it never exercised it.)
D_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
C_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if [ -n "$D_ROOT" ] && [ -f "$D_ROOT/core/hooks/ai-dlc-dispatch-guard.sh" ]; then
  HOOK="$D_ROOT/core/hooks/ai-dlc-dispatch-guard.sh"
  SRC_ROLES="$D_ROOT/core/team-roles"
elif [ -n "$C_ROOT" ] && [ -f "$C_ROOT/.claude/hooks/ai-dlc-dispatch-guard.sh" ]; then
  HOOK="$C_ROOT/.claude/hooks/ai-dlc-dispatch-guard.sh"
  SRC_ROLES="$C_ROOT/.claude/team-roles"
else
  echo "FIXTURE ERROR: ai-dlc-dispatch-guard.sh not found in either layout" >&2
  exit 2
fi

# macOS /tmp is a symlink; resolve through cd+pwd so path compares hold.
WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"

CONSUMER="$WORK/consumer"
NOSTAMP="$WORK/nostamp"
mkdir -p "$CONSUMER/.claude/team-roles" "$NOSTAMP/.claude/team-roles"

# A layered consumer is stamped. The unstamped tree proves the activation gate.
printf 'version: 0.70.0\ncommit: fixture\n' > "$CONSUMER/.claude/.ai-dlc-version"

# Roles are seeded the way a real consumer carries them: the role file states NEITHER
# model nor effort, and `aiDlcRoles.<role>` in settings.json states both. The guard
# resolves the role name against that block.
#
# `model` is a KEY into `aiDlcModels`, and the guard injects the KEY as the Agent
# tool's `model` parameter — that parameter is an enum and rejects a full model
# string. `effort` has no tool parameter at all, so the guard appends a `/effort`
# directive to the dispatch prompt, the only channel that reaches the subagent.
cat > "$CONSUMER/.claude/settings.json" <<'SETTINGS'
{
  "aiDlcModels": {
    "opus": "claude-opus-5[1m]",
    "sonnet": "claude-sonnet-5[1m]"
  },
  "aiDlcRoles": {
    "gate-adjudicator": { "model": "opus",   "effort": "high" },
    "remediator":       { "model": "opus",   "effort": "high" },
    "analyst":          { "model": "sonnet", "effort": "medium" },
    "dev":              { "model": "sonnet", "effort": "medium" },
    "dev-escalated":    { "model": "opus",   "effort": "high" },
    "architect":        { "model": "ghostkey", "effort": "high" },
    "tea":              { "effort": "high" },
    "badeffort":        { "model": "sonnet", "effort": "reallyhigh" }
  },
  "env": { "ENABLE_PROMPT_CACHING_1H": "1" }
}
SETTINGS

# A role file states no model and no effort — the shipped shape.
render_role() {           # render_role <name>
  cat > "$CONSUMER/.claude/team-roles/$1.md" <<ROLE
# Role: $1

**Model and effort: set at the start of your session from
\`aiDlcRoles.$1\` in \`.claude/settings.json\`.** That entry is the only
source; do not infer either value from anywhere else.

## Contract
Do the thing the role does.
ROLE
}

for r in gate-adjudicator remediator analyst dev dev-escalated architect tea badeffort nocfg; do
  render_role "$r"
done

# A consumer whose settings.json carries NO aiDlcRoles block at all — a file that
# predates it, or was hand-trimmed. Nothing resolves for any role, so the guard must
# bind nothing rather than guess.
NOMODELS="$WORK/nomodels"
mkdir -p "$NOMODELS/.claude/team-roles"
cp "$CONSUMER/.claude/.ai-dlc-version" "$NOMODELS/.claude/"
cp "$CONSUMER/.claude/team-roles/gate-adjudicator.md" "$NOMODELS/.claude/team-roles/"
printf '{"env":{}}\n' > "$NOMODELS/.claude/settings.json"

# Unstamped tree: same roles, no version stamp -> hook must be a total no-op.
cp "$CONSUMER/.claude/team-roles/gate-adjudicator.md" "$NOSTAMP/.claude/team-roles/"

cat > "$WORK/env.sh" <<ENV
HOOK="$HOOK"
CONSUMER="$CONSUMER"
NOSTAMP="$NOSTAMP"
NOMODELS="$NOMODELS"
SRC_ROLES="$SRC_ROLES"
ENV

printf '%s\n' "$WORK"
