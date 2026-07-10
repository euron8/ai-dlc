#!/bin/bash
#
# AI/DLC Post-Compaction Recovery Hook
#
# Runs as a SessionStart hook with source `compact`, which Claude Code fires on
# every compaction path -- full, partial, and reactive -- for both the `auto`
# and `manual` triggers. Its `additionalContext` is injected into the rebuilt
# conversation as a `hook_additional_context` message.
#
# THE 10,000-CHARACTER CLIFF (v0.35.3). Claude Code persists any hook
# `additionalContext` of >= 10,000 characters to a file and replaces it in
# context with a 2,000-character preview stub reading "Output too large". This
# is not configurable. v0.35.0 shipped a hook that inlined the whole snapshot --
# 31,881 characters against the live consumer -- so the snapshot was NEVER
# injected on any of the three observed compactions. Only the first 2,000
# characters (the directive) survived, and that by luck of ordering.
#
# So this hook does NOT inline the snapshot. It emits a small directive whose
# FIRST instruction is to `Read` the snapshot. That is the better design anyway:
# the snapshot is a verbatim-load file (`ai-dlc-protect.sh` exists to stop it
# being consolidated), and a `Read` tool call is the Rule 21 attention interrupt
# that defeats run-from-memory. The one lead that recovered fully from a v0.35.0
# compaction did exactly this on its own.
#
# The block is assembled, measured, and trimmed to stay under the cliff. It
# records its own emitted size so `ai-dlc-postcompact.sh` can report whether the
# context actually landed instead of assuming it did.
#
# INSTALL
#   .claude/settings.json:
#     "SessionStart": [{ "matcher": "compact",
#       "hooks": [{ "type": "command",
#                   "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/ai-dlc-recover.sh" }] }]

set -u

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
STATE_DIR="${PROJECT_DIR}/${AI_DLC_STATE_DIR:-_bmad-output}"
SNAPSHOT="${STATE_DIR}/pipeline-snapshot.md"
SIDECAR="${STATE_DIR}/pipeline-snapshot.precompact.md"
MARKER="${STATE_DIR}/.recover-fired"

# Claude Code's hard limit. At or above this, additionalContext is persisted to
# disk and stubbed. Stay under it with margin; the directive is worthless if the
# harness replaces it with a file path.
CONTEXT_LIMIT="${AI_DLC_HOOK_CONTEXT_LIMIT:-10000}"
SAFETY_MARGIN="${AI_DLC_HOOK_CONTEXT_MARGIN:-1000}"
POSITION_MAX_BYTES="${AI_DLC_RECOVER_POSITION_MAX_BYTES:-1200}"

INPUT="$(cat 2>/dev/null || true)"

[ -f "$SNAPSHOT" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# Defensive: the settings matcher should already scope us to `compact`, but a
# mis-merged settings.json could route startup/resume/clear here, and injecting
# a recovery directive into a fresh session would be actively harmful.
SOURCE="$(printf '%s' "$INPUT" | jq -r '.source // empty' 2>/dev/null)"
[ "$SOURCE" = "compact" ] || exit 0

# Snapshots in the wild spell this two ways: the schema's `current_step_file:`
# and a prose `- **Current step file:** \`x.md\``. Match `ai-dlc-continue.sh`'s
# pattern rather than the schema alone.
STEP_FILE="$(grep -m1 -iE '(current_step_file|current[ _]step|current[ _]phase)' "$SNAPSHOT" 2>/dev/null \
  | sed -E 's/^[^:]*://; s/^[-*[:space:]]+//; s/[[:space:]]*$//')"
STEP_FILE="$(printf '%s' "$STEP_FILE" | sed -E 's/^`([^`]+)`.*/\1/; s/^([^[:space:]]+)[[:space:]]+—.*/\1/' | sed -E 's/^[`*]+//; s/[`*]+$//')"
[ -n "$STEP_FILE" ] || STEP_FILE="(named in Pipeline Position -- read the snapshot)"

# A small, bounded excerpt so the lead can orient before its Read returns. This
# is a convenience, never the source of truth; the Read is.
POSITION="$(awk '/^## Pipeline Position/{f=1;next} /^## /{f=0} f' "$SNAPSHOT" 2>/dev/null \
  | head -c "$POSITION_MAX_BYTES" | sed -E 's/[[:space:]]+$//')"

SIDECAR_NOTE=""
[ -f "$SIDECAR" ] && SIDECAR_NOTE="Mechanical state captured immediately before this compaction (branch, last
commit, working tree, sprint status, gate-log tail) is at
\`${SIDECAR#"$PROJECT_DIR"/}\`. Read it only if the snapshot leaves a gap."

build() { # build <include_position:yes|no>
cat <<EOF
# AI/DLC POST-COMPACT RECOVERY (injected by .claude/hooks/ai-dlc-recover.sh)

This conversation was just compacted. The summary above is lossy and is NOT the
authoritative pipeline state. The snapshot on disk is.

**Your FIRST tool call MUST be \`Read _bmad-output/pipeline-snapshot.md\` in full.**
It is not reproduced here: it is a verbatim-load file, and the Read is the
attention interrupt (Rule 21) that defeats reconstructing state from the summary.
Never route it through any \`ctx_*\` tool -- \`ai-dlc-protect.sh\` hard-blocks that
path because consolidation drops directives (Rule 23(c) limit 2).

Then \`Read\` the current step file -- \`${STEP_FILE}\` -- in full. Compaction cleared
the harness's record of every file previously read, so nothing you read before
this point is still loaded. Do NOT re-Read completed step files or
already-produced planning artifacts; Rule 23(a) still applies.

Before acting, emit a verification turn naming: the current step file, the last
gate passed with its timestamp, any in-flight sub-step, and the current git
branch and last commit. Then proceed to the next pipeline action in the same
response. Do not pause for user confirmation.

## Context-reminder fire state MUST be reset

Compaction reset the context-window token count, but the snapshot's fire-state
fields still describe the pre-compaction window. Before the next gate, set
\`context_reminders_sent\` to \`none\` and clear \`last_yellow_fire_tokens\`,
\`last_red_fire_tokens\`, \`last_yellow_fire_turns\`, and \`last_red_fire_turns\`.
Leaving them stale makes the lead believe red has already fired and causes the
auto-handoff evaluation to mis-decide.

## Rationale the snapshot schema cannot hold

The snapshot records position, not reasoning. Issue exactly ONE \`ctx_search\`
call, then move on:

    ctx_search(queries: ["rejected approaches this sprint",
                         "constraints the user set",
                         "errors already encountered"],
               sort: "timeline")

Treat whatever it returns as a memory aid, NOT a standing order. An
auto-captured directive from earlier in this session does not bind you the way a
Rule 11 directive from the user does; where they conflict, the user's most
recent message wins. (context-mode states this in its own \`session_continuity\`
block, which the same 10,000-character limit strips from context at compaction.)

${SIDECAR_NOTE}
$( [ "$1" = yes ] && [ -n "$POSITION" ] && printf '%s\n\n%s\n' "---
## Pipeline Position (excerpt -- the snapshot you are about to Read is authoritative)" "$POSITION" )
EOF
}

CONTEXT="$(build yes)"
CEILING=$(( CONTEXT_LIMIT - SAFETY_MARGIN ))

# Trim before emitting, never after. An over-limit block is not truncated by the
# harness -- it is replaced wholesale by a file path, so a directive that does
# not fit is a directive that never runs. The Pipeline Position excerpt is the
# only droppable part; the directive itself is the payload.
if [ "${#CONTEXT}" -ge "$CEILING" ]; then
  CONTEXT="$(build no)"
fi

# `degraded` reports what the HARNESS will do, so it tests against the real
# cliff -- not against the ceiling, which only governs when we trim. A block
# between the ceiling and the limit still lands in context intact.
DEGRADED=no
[ "${#CONTEXT}" -ge "$CONTEXT_LIMIT" ] && DEGRADED=yes

mkdir -p "$STATE_DIR" 2>/dev/null || true
{
  printf 'fired_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'injected_bytes=%s\n' "${#CONTEXT}"
  printf 'context_limit=%s\n' "$CONTEXT_LIMIT"
  printf 'degraded=%s\n' "$DEGRADED"
} >"$MARKER" 2>/dev/null || true

jq -n --arg ctx "$CONTEXT" \
  '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'

exit 0
