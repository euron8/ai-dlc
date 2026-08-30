#!/bin/bash
#
# AI/DLC handoff entry marker
#
# PostToolUse on `Read`. When the lead reads steps/handoff.md it is inside the handoff
# procedure, and this records that fact on disk so a compaction landing on any turn of the
# five steps can be routed back to the same file. `ai-dlc-recover.sh` reads the marker
# through ai-dlc-handoff-pending.sh; steps/handoff.md removes it at step 5.
#
# WHY A HOOK AND NOT THE STEP FILE. The step file was the first cut: an instruction to
# `touch` the marker before step 1. It was wrong twice over. schemas/pipeline-state-paths.json
# classifies "every top-level entry the shipped MACHINERY constructs", and its `producer`
# field is explicitly "a shipped file that CONSTRUCTS this path on a non-comment line" -- a
# file that only tells a lead to construct it does not satisfy I95, which failed the push and
# was right to. And the defect this whole change exists for is a lead that did not execute the
# handoff procedure at all, so a marker whose only writer is that same procedure is absent in
# precisely the case that motivated it. The consumer's own filing said so in its One limit:
# the fix needs "a mechanical marker a hook can check, not just prose".
#
# NEVER BLOCKS, AND IS NOT A GATE. PostToolUse runs after the call has returned; the Read has
# already happened. Every path exits 0, including every failure path -- a marker hook that
# could fail a tool call would make the pipeline's ability to read a step file depend on its
# ability to write a file.
#
# THE MATCH IS ON THE BASENAME UNDER A steps/ PARENT, not on a whole path. The same file lives
# at .claude/skills/ai-dlc/steps/handoff.md on a consumer and core/skills/ai-dlc/steps/handoff.md
# in the distribution, and a lead may read it through either spelling or through a relative
# path. Anchoring on the two path segments matches every layout without matching a consumer's
# own unrelated `handoff.md` somewhere else in the tree.
#
# WHY NOT ALSO REMOVE IT HERE. The marker means "inside the procedure", and this hook cannot
# see the procedure END -- step 5 is a Bash call, not a Read. steps/handoff.md removes it,
# beside the pause flag, where the procedure knows it has finished. A stale marker with the
# pause flag already gone is inert: ai_dlc_handoff_pending requires the flag first.
#
# INSTALL
#   .claude/settings.json:
#     "PostToolUse": [{ "matcher": "Read",
#       "hooks": [{ "type": "command",
#                   "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/ai-dlc-handoff-entry.sh" }] }]

set -u

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
STATE_DIR="${PROJECT_DIR}/${AI_DLC_STATE_DIR:-_bmad-output}"

INPUT="$(cat 2>/dev/null || true)"
[ -n "$INPUT" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

TOOL="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
[ "$TOOL" = "Read" ] || exit 0

FPATH="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
[ -n "$FPATH" ] || exit 0

case "$FPATH" in
  */steps/handoff.md) : ;;
  *) exit 0 ;;
esac

# The output directory may legitimately not exist yet on a tree that has never run the
# pipeline; creating it here would manufacture pipeline state from a plain file read.
[ -d "$STATE_DIR" ] || exit 0
: > "${STATE_DIR}/.handoff-in-progress" 2>/dev/null || true
exit 0
