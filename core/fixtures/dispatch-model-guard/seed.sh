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
# directive to the dispatch prompt; the rendered definition under .claude/agents/ is the
# channel that binds it (see the RENDERED AGENT DEFINITIONS block below).
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
    "badeffort":        { "model": "sonnet", "effort": "reallyhigh" },
    "defok":            { "model": "opus",   "effort": "high" },
    "defstalemodel":    { "model": "opus",   "effort": "high" },
    "defstaleeffort":   { "model": "opus",   "effort": "high" },
    "defunmarked":      { "model": "opus",   "effort": "high" },
    "defnodef":         { "model": "opus",   "effort": "high" },
    "defnoeffort":      { "model": "opus" }
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

# --- RENDERED AGENT DEFINITIONS ------------------------------------------------
# `.claude/agents/<role>.md`, the projection of `aiDlcRoles.<role>` that the HARNESS
# reads. The guard binds a role's `subagent_type` to one of these and strips `name` and
# `model`, because a definition's `effort:` is applied by the harness where the guard's
# prompt sentence is only advisory.
#
# EVERY DEFINITION BELONGS TO A ROLE NO OTHER ARM USES, AND THAT IS THE POINT. The
# absent-definition branch is "today's behaviour", so every pre-existing arm in run.sh IS
# its regression test — attaching a definition to `gate-adjudicator` or `dev` would flip
# those arms to the new path and delete the coverage of the old one in the same change,
# leaving the fail-open branch asserted by nothing. The `def*` roles below carry the new
# branch; the roles above carry the old one; neither can be dropped without an arm going
# red.
#
# THE FORMAT IS SEEDED HERE AND THE RENDERER IS NOT RUN, deliberately. This fixture drives
# the GUARD, and a seed produced by the renderer would only establish that the guard
# accepts whatever that renderer emits — the reader agreeing with its own writer, which is
# the seeding defect `fixture-mutants.md` names. The bytes below are the format the guard
# is contracted to read; if the renderer ever stops emitting them, the guard's own arms
# here stay honest and the renderer's own fixture is where that divergence shows.
mkdir -p "$CONSUMER/.claude/agents"
DEF_MARKER='<!-- AI/DLC GENERATED: rendered by scripts/ai-dlc/render-agent-definitions.sh from .claude/settings.json aiDlcRoles.<role>. Edit the settings entry, then re-render. -->'
render_def() {            # render_def <name> <model-key> [effort]
  {
    printf -- '---\n'
    printf 'name: %s\n' "$1"
    printf 'description: AI/DLC role %s — rendered from aiDlcRoles.%s; do not edit by hand\n' "$1" "$1"
    printf 'model: %s\n' "$2"
    [ -n "${3-}" ] && printf 'effort: %s\n' "$3"
    printf -- '---\n'
    printf '%s\n' "$DEF_MARKER"
    printf 'Your operating contract is `.claude/team-roles/%s.md`. Read it and follow it as your\n' "$1"
    printf 'FIRST action before any other work.\n'
  } > "$CONSUMER/.claude/agents/$1.md"
}

for r in defok defstalemodel defstaleeffort defunmarked defnodef defnoeffort; do
  render_role "$r"
done

# AGREES on both keys -> BOUND.
render_def defok opus high

# STALE on MODEL, effort agreeing.
render_def defstalemodel sonnet high

# STALE on EFFORT, model agreeing. BOTH stale shapes are seeded because the agreement test
# is a conjunction: a seed that only ever disagreed on model leaves the effort half
# unexercised, and dropping that half would go unnoticed.
render_def defstaleeffort opus low

# A role whose settings entry declares NO effort, rendered with no `effort:` line. The
# empty-to-empty comparison must AGREE — the renderer omits the key for exactly this case,
# so a comparison that treated absent-vs-absent as a disagreement would call every such
# render stale and bind none of them.
render_def defnoeffort opus

# UNMARKED: a consumer's own hand-written agent sharing a role name. The guard must leave
# it strictly alone rather than select a body this distribution did not write. Byte-identical
# to a rendered one EXCEPT for the marker, and it AGREES with settings — so the arm that
# skips it can only be keyed on the marker, never on disagreement.
{
  printf -- '---\nname: defunmarked\ndescription: a consumer wrote this by hand\nmodel: opus\neffort: high\n---\n'
  printf 'Hand-written. No generated marker.\n'
} > "$CONSUMER/.claude/agents/defunmarked.md"

# NO definition at all for `defnodef`, nor for tea/architect/badeffort/nocfg.

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
