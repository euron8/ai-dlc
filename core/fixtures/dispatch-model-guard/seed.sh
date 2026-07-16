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

# Roles are RENDERED here the way ai-dlc-setup renders them in a real consumer:
# the core files carry {placeholder} templates, the consumer carries real model
# strings. The guard reads the consumer's rendered files, so the fixture must
# seed rendered ones. The mangled-comment line is REAL — graph's remediator.md
# has the placeholder substituted into the comment key itself — and it is here
# on purpose: it is the line a naive `grep -m1 model` would read instead of the
# pin.
render_role() {           # render_role <name> <personal> <bedrock>
  cat > "$CONSUMER/.claude/team-roles/$1.md" <<ROLE
# Role: $1

**Model and effort: Set at the start of your session.**
- \`/effort high\`
<!-- $2: Personal/direct API model string (e.g., $2) -->
<!-- $3: Bedrock model string (e.g., $3) -->
- Personal: \`/model $2\`
- Bedrock: \`/model $3\`

## Contract
Do the thing the role does.
ROLE
}

render_role gate-adjudicator 'claude-opus-4-8[1m]'   'global.anthropic.claude-opus-4-6-v1'
render_role remediator       'claude-opus-4-8[1m]'   'global.anthropic.claude-opus-4-6-v1'
render_role analyst          'claude-sonnet-5[1m]'   'global.anthropic.claude-sonnet-4-6'

# An UNPINNED role — the real tea.md/sm.md/ux.md/cis.md shape. The guard must
# fail open here: a role file that declares nothing cannot bind anything.
cat > "$CONSUMER/.claude/team-roles/tea.md" <<'ROLE'
# Role: tea

**Model and effort: Set at the start of your session.**
- `/effort high`

## Contract
Test strategy.
ROLE

# A role whose two pins DISAGREE on tier — ambiguous intent, must fail open
# rather than pick a side.
render_role architect 'claude-opus-4-8[1m]' 'global.anthropic.claude-sonnet-4-6'

# A prose `/model` mention with no model string (dev.md:16 in the real tree).
# Must not be read as a pin.
cat > "$CONSUMER/.claude/team-roles/dev.md" <<'ROLE'
# Role: dev

**Model and effort: Set at the start of your session.**
- Personal: `/model claude-sonnet-5[1m]`
- Bedrock: `/model global.anthropic.claude-sonnet-4-6`
- When dispatched as a teammate the launcher sets it
  (no `/model` switch needed; the model is set at launch)

## Contract
Write the code.
ROLE

# Unstamped tree: same roles, no version stamp -> hook must be a total no-op.
cp "$CONSUMER/.claude/team-roles/gate-adjudicator.md" "$NOSTAMP/.claude/team-roles/"

cat > "$WORK/env.sh" <<ENV
HOOK="$HOOK"
CONSUMER="$CONSUMER"
NOSTAMP="$NOSTAMP"
SRC_ROLES="$SRC_ROLES"
ENV

printf '%s\n' "$WORK"
