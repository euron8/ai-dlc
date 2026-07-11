#!/bin/bash
#
# AI/DLC Operator-Acknowledgement Hook (Rule 29)
#
# PURPOSE
# Gives the pause flag teeth. `ai-dlc-pause.sh` (UserPromptSubmit) creates
# _bmad-output/pipeline-paused.flag on every operator message and instructs
# the lead not to execute pipeline steps while it exists. Until now NOTHING
# enforced that: the flag was read only by the Stop hook (ai-dlc-continue.sh)
# and the driver signal. The lead -- simultaneously under Rule 3 ("Keep
# working. Do not ask if you should continue.") and the Stop hook's forced-
# continuation reason -- routinely steamrolled the operator's message, which
# arrives mid-turn alongside a tool result and is easy to ignore.
#
# This hook denies PIPELINE-ADVANCING tool calls while the flag exists. The
# lead must deal with the operator before it can advance.
#
# DECISION ORDER (first match wins)
# 1. no snapshot            -> allow (no active pipeline; same gating as pause.sh)
# 2. no pause flag          -> allow (autonomous mode; the common path)
# 3. tool is pipeline-      -> DENY with a reason telling the lead to answer
#    advancing                 the operator, then clear the flag to resume
# 4. default                -> allow (read-only work + the flag-clearing rm)
#
# THE ENFORCEMENT SURFACE (deliberately narrow -- Rule 26 minimum mechanism)
# Denied:  Agent, Skill, TaskCreate, and Write/Edit under _bmad-output/.
#          Per Rule 28 delegation is the default, so the lead cannot advance
#          the pipeline without one of these. This is the whole surface.
# Allowed: Read, Grep, Glob, Bash, and everything else -- so the lead can
#          investigate the operator's question, AND so it can always run
#          `rm -f _bmad-output/pipeline-paused.flag` to resume. Allowing Bash
#          is what makes deadlock impossible.
#
# WHY NOT DENY EVERYTHING
# A hook that denied Bash too would trap the lead: the sanctioned resume path
# (SKILL.md INITIALIZATION) is an `rm` via Bash. Denying it would wedge the
# pipeline permanently. The escape hatch must stay open.
#
# OUTPUT
# - Appends to: _bmad-output/pipeline-continuation-log.md (event: ACK_DENIED)
# - JSON to stdout on deny: permissionDecision + reason
# - Exit 0 in all cases (the deny is in the JSON body)
#
# INSTALL
# 1. Place at .claude/hooks/ai-dlc-acknowledge.sh
# 2. chmod +x .claude/hooks/ai-dlc-acknowledge.sh
# 3. Add to .claude/settings.json hooks under "PreToolUse" with
#    "matcher": "Agent|Skill|TaskCreate|Write|Edit"
# 4. Restart Claude Code; verify with /hooks

set -u

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
SNAPSHOT_FILE="${PROJECT_DIR}/_bmad-output/pipeline-snapshot.md"
LOG_DIR="${PROJECT_DIR}/_bmad-output"
LOG_FILE="${LOG_DIR}/pipeline-continuation-log.md"
PAUSE_FLAG="${LOG_DIR}/pipeline-paused.flag"

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# -----------------------------------------------------------------------------
# Check 1: no active pipeline -> allow
# -----------------------------------------------------------------------------
[ -f "$SNAPSHOT_FILE" ] || exit 0

# -----------------------------------------------------------------------------
# Check 2: not paused -> allow (the common path; keep it cheap)
# -----------------------------------------------------------------------------
[ -f "$PAUSE_FLAG" ] || exit 0

# -----------------------------------------------------------------------------
# Check 3: is this tool pipeline-advancing?
# -----------------------------------------------------------------------------
ADVANCING=0
case "$TOOL_NAME" in
  Agent|Task|Skill|TaskCreate)
    ADVANCING=1
    ;;
  Write|Edit|MultiEdit|NotebookEdit)
    # Only artifact production under _bmad-output/ counts. Escalations
    # (docs/escalations/) and source edits are NOT denied -- the lead may
    # legitimately need to write an escalation while paused.
    FP=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
    case "$FP" in
      */_bmad-output/*|_bmad-output/*) ADVANCING=1 ;;
    esac
    ;;
esac

[ "$ADVANCING" -eq 1 ] || exit 0

# -----------------------------------------------------------------------------
# DENY. The operator is waiting.
# -----------------------------------------------------------------------------
REASON="AI/DLC Rule 29: the pipeline is PAUSED -- an operator message is outstanding and has not been acknowledged. \`${TOOL_NAME}\` advances the pipeline, so it is denied until you deal with the operator.

Do this now, in order:
1. READ the operator's message. It arrived mid-turn, most likely alongside a tool result, and is easy to scroll past. Find it.
2. RESPOND to it in text. Answer the question, accept the correction, or state what you will do differently. Do not silently continue.
3. THEN classify intent, per the pause contract:
   (a) Resume intent (including /ai-dlc resume, handoff resume, or natural resume language) -> \`rm -f _bmad-output/pipeline-paused.flag\`, then RE-READ the current step file (Rule 22) and continue.
   (b) Question / correction / clarification -> answer it, leave the flag in place, and wait. The operator is steering.
   (c) Handoff request -> follow the Rule 2 handoff protocol; leave the flag in place.

Read-only tools (Read, Grep, Glob, Bash) are still ALLOWED -- use them to investigate the operator's question, and to clear the flag when you resume. Only pipeline-advancing calls are blocked.

This is not a stall and Rule 3 does not override it. Rule 3 forbids stalling when NO ONE is waiting on you. Here a human IS waiting on you. Answer them."

{
  echo "## ${TIMESTAMP} -- ACK_DENIED"
  echo "- Session: ${SESSION_ID}"
  echo "- Tool denied: ${TOOL_NAME}"
  echo "- Pause flag present; operator message not yet acknowledged"
  echo ""
} >> "$LOG_FILE"

jq -n \
  --arg reason "$REASON" \
  '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'

exit 0
