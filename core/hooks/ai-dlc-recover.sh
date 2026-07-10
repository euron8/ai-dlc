#!/bin/bash
#
# AI/DLC Post-Compaction Recovery Hook
#
# Runs as a SessionStart hook with source `compact`, which Claude Code fires on
# every compaction path -- full, partial, and reactive -- for both the `auto`
# and `manual` triggers. Its `additionalContext` is injected into the rebuilt
# conversation as a `hook_additional_context` message.
#
# WHAT THIS REPLACES. Before this hook, post-compact recovery relied on the lead
# remembering an instruction ("read the snapshot first") that lived in the very
# context the summary had just discarded. Recovery was exactly as reliable as
# the model's memory of a rule it may no longer hold. Now the snapshot is placed
# back into context by the harness, unconditionally. The prose protocol in
# SKILL.md remains as the fallback for when this hook is absent or truncated.
#
# WHY RE-READING THE STEP FILE IS MANDATORY. Compaction clears Claude Code's
# readFileState and its loaded memory paths. Every file the lead read earlier --
# including the current step file -- is gone from context and from the harness's
# notion of what has been read. The snapshot restores position; only a fresh
# Read restores the step's instructions.
#
# WHY THE BYTE CAP. This text lands in the post-compact context, on top of the
# fixed prefix and the summary. An unbounded injection is itself a rapid-refill
# trigger: three post-compact turns that immediately refill will trip Claude
# Code's rapid-refill breaker, which is a terminal stop reason.
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

SNAPSHOT_MAX_BYTES="${AI_DLC_RECOVER_SNAPSHOT_MAX_BYTES:-24000}"
SIDECAR_MAX_BYTES="${AI_DLC_RECOVER_SIDECAR_MAX_BYTES:-6000}"

INPUT="$(cat 2>/dev/null || true)"

[ -f "$SNAPSHOT" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# Defensive: the settings matcher should already scope us to `compact`, but a
# mis-merged settings.json could route startup/resume/clear here, and injecting
# a recovery directive into a fresh session would be actively harmful.
SOURCE="$(printf '%s' "$INPUT" | jq -r '.source // empty' 2>/dev/null)"
[ "$SOURCE" = "compact" ] || exit 0

# Read at most N bytes, and say so when truncated rather than silently clipping.
read_capped() {
  local file="$1" cap="$2" size
  size="$(wc -c <"$file" 2>/dev/null | tr -d ' ')"
  if [ -z "$size" ]; then return 1; fi
  if [ "$size" -gt "$cap" ]; then
    head -c "$cap" "$file"
    printf '\n\n[TRUNCATED at %s of %s bytes by ai-dlc-recover.sh. Read the file directly for the remainder.]\n' "$cap" "$size"
  else
    cat "$file"
  fi
}

SNAPSHOT_TEXT="$(read_capped "$SNAPSHOT" "$SNAPSHOT_MAX_BYTES")"

SIDECAR_TEXT=""
if [ -f "$SIDECAR" ]; then
  SIDECAR_TEXT="$(read_capped "$SIDECAR" "$SIDECAR_MAX_BYTES")"
fi

STEP_FILE="$(grep -m1 -iE 'current_step_file' "$SNAPSHOT" 2>/dev/null | sed -E 's/.*current_step_file[^A-Za-z0-9_./-]*//I; s/[`*_ ]+$//')"
[ -n "$STEP_FILE" ] || STEP_FILE="(named in Pipeline Position below)"

CONTEXT="$(cat <<EOF
# AI/DLC POST-COMPACT RECOVERY (injected by .claude/hooks/ai-dlc-recover.sh)

This conversation was just compacted. The summary above is lossy and is NOT the
authoritative pipeline state. What follows is.

Compaction cleared the harness's record of every file previously read. Your
FIRST action MUST be to Read the current step file -- \`${STEP_FILE}\` -- in full.
Do NOT re-Read completed step files or already-produced planning artifacts;
Rule 23(a) still applies, and the snapshot below is the authoritative source for
prior-step state.

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

## Rationale not captured by the snapshot

The snapshot schema records position, not reasoning. Issue exactly ONE
\`ctx_search\` call, then move on:

    ctx_search(queries: ["rejected approaches this sprint",
                         "constraints the user set",
                         "errors already encountered"],
               sort: "timeline")

Never route \`pipeline-snapshot.md\` or \`gate-log.md\` through any \`ctx_*\` tool.
They are verbatim-load files; consolidation drops directives. The
\`ai-dlc-protect.sh\` hook hard-blocks that path (Rule 23(c) limit 2).

---

# pipeline-snapshot.md (verbatim)

${SNAPSHOT_TEXT}
EOF
)"

if [ -n "$SIDECAR_TEXT" ]; then
  CONTEXT="${CONTEXT}

---

# pipeline-snapshot.precompact.md (mechanical state at compaction time)

${SIDECAR_TEXT}"
fi

# Leave a marker so ai-dlc-postcompact.sh, which runs after us, can record that
# recovery context was actually injected for this compaction.
mkdir -p "$STATE_DIR" 2>/dev/null || true
date -u +%Y-%m-%dT%H:%M:%SZ >"$MARKER" 2>/dev/null || true

jq -n --arg ctx "$CONTEXT" \
  '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'

exit 0
