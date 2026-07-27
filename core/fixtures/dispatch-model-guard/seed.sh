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

# Roles are seeded the way a real consumer carries them: the role file names a
# KEY on its `- Model:` line and the consumer's settings.json maps that key to a
# model string. Both halves must be present for the guard to bind, so the fixture
# seeds both — a settings.json with an `aiDlcModels` block, and role files that
# name keys in it.
#
# The guard resolves key -> string, and injects the KEY as the Agent tool's
# `model` parameter (that parameter is an enum and rejects a full model string).
cat > "$CONSUMER/.claude/settings.json" <<'SETTINGS'
{
  "aiDlcModels": {
    "opus": "claude-opus-5[1m]",
    "sonnet": "claude-sonnet-5[1m]"
  },
  "env": { "ENABLE_PROMPT_CACHING_1H": "1" }
}
SETTINGS

render_role() {           # render_role <name> <key>
  cat > "$CONSUMER/.claude/team-roles/$1.md" <<ROLE
# Role: $1

**Model and effort: Set at the start of your session.**
- \`/effort high\`
- Model: \`$2\` — a key in \`aiDlcModels\` (\`.claude/settings.json\`).
  Run \`/model\` with the model string that key maps to there.

## Contract
Do the thing the role does.
ROLE
}

render_role gate-adjudicator opus
render_role remediator       opus
render_role analyst          sonnet
# dev-escalated: the standard Dev contract on the stronger key a consumer points
# it at. The guard must bind THIS key, so running the escalated role on the cheap
# model — the exact slip escalation invites — is corrected.
render_role dev-escalated     opus

# An UNPINNED role — the real tea.md/sm.md/ux.md/cis.md shape. The guard must
# fail open here: a role file that declares nothing cannot bind anything.
cat > "$CONSUMER/.claude/team-roles/tea.md" <<'ROLE'
# Role: tea

**Model and effort: Set at the start of your session.**
- `/effort high`

## Contract
Test strategy.
ROLE

# A role naming a key that `aiDlcModels` does NOT define. The guard must fail
# open rather than bind a guess — this is the branch that replaced the old
# "two pins disagree on tier" ambiguity.
render_role architect ghostkey

# A prose `/model` mention with no key (dev.md's Ollama line in the real tree).
# Must not be read as a pin; the `- Model:` line is.
cat > "$CONSUMER/.claude/team-roles/dev.md" <<'ROLE'
# Role: dev

**Model and effort: Set at the start of your session.**
- `/effort medium`
- Model: `sonnet` — a key in `aiDlcModels` (`.claude/settings.json`).
  Run `/model` with the model string that key maps to there.
- Local (Ollama): Lead launches you with the local model at the command line
  (no `/model` switch needed; the model is set at launch)

## Contract
Write the code.
ROLE

# A consumer whose settings.json carries NO aiDlcModels block at all — the
# pre-v0.174.0 shape, or a hand-trimmed file. Every key is unresolvable, so the
# guard must bind nothing rather than bind wrongly.
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
