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
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# -----------------------------------------------------------------------------
# Which skill is this session running?
#
# `/ai-dlc-update` is NOT `/ai-dlc`. It advances no sprint, passes no gate, and
# runs precisely when the pipeline is parked -- which is exactly when the pause
# flag is set. Denying its dispatches because "the pipeline is PAUSED" blocks a
# skill that has no pipeline to pause, and the flag it trips over is usually the
# one a HANDOFF left behind.
#
# This was already understood for the updater's file WRITES (see the
# _bmad-output/ai-dlc-update/ carve-out below) and never extended to its
# DISPATCHES -- while the updater's whole design is a fan-out ("dispatch ONE
# generic agent per file", ai-dlc-update/SKILL.md). So it was denied, and the
# model routed around the denial by doing the work INLINE in the lead, which
# defeats the offload the dispatch existed for and inflates the very context the
# updater is meant to protect. A guardrail that is trivially routed around is not
# a guardrail; it is a tax on the honest path.
#
# Detected from the transcript rather than a marker file. A marker would need a
# lifecycle -- create, delete, and a story for the crash in between -- and a
# stale-flag-with-a-lifecycle is the bug being fixed here, not a tool to fix it
# with. The transcript is self-healing: whichever skill was invoked LAST is the
# one in play. A session that runs /ai-dlc-update and then /ai-dlc resume is a
# pipeline session again, and the pause gate applies to it in full.
# -----------------------------------------------------------------------------
UPDATER_SESSION=0
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  LAST_UPDATE=$(grep -n '<command-name>/ai-dlc-update</command-name>' "$TRANSCRIPT" 2>/dev/null | tail -1 | cut -d: -f1)
  LAST_PIPELINE=$(grep -n '<command-name>/ai-dlc</command-name>' "$TRANSCRIPT" 2>/dev/null | tail -1 | cut -d: -f1)
  if [ -n "$LAST_UPDATE" ] && [ "$LAST_UPDATE" -gt "${LAST_PIPELINE:-0}" ] 2>/dev/null; then
    UPDATER_SESSION=1
  fi
fi

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
    # In an /ai-dlc-update session these advance nothing: the updater fans out
    # over its own reconcile, it does not run a sprint. Denying here is what
    # pushed the work inline. In a pipeline session they advance the pipeline
    # and the deny stands.
    [ "$UPDATER_SESSION" -eq 1 ] || ADVANCING=1
    ;;
  Write|Edit|MultiEdit|NotebookEdit)
    # Only artifact production under _bmad-output/ counts. Escalations
    # (docs/escalations/) and source edits are NOT denied -- the lead may
    # legitimately need to write an escalation while paused.
    FP=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
    case "$FP" in
      # _bmad-output/ai-dlc-update/** is the UPDATER's scratch space (reconcile
      # report, push-candidate ledger) -- NOT pipeline output. /ai-dlc-update is a
      # different skill from /ai-dlc: it advances no sprint, and it runs precisely
      # when the pipeline is not running. Denying its report write because "the
      # pipeline is paused" blocks a skill that has no pipeline to pause. Observed
      # live: the updater was denied mid-reconcile on its own ledger.
      # This case must precede the _bmad-output match below -- first match wins.
      */_bmad-output/ai-dlc-update/*|_bmad-output/ai-dlc-update/*) ;;
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

# Seed the log header if this is the first write of the sprint. Retro rotates
# the live log away at close (Rule 25(c)), so any of the three hooks may find
# the file absent and must be able to open a fresh one.
mkdir -p "$LOG_DIR"
if [ ! -s "$LOG_FILE" ]; then
  cat > "$LOG_FILE" <<'EOF'
# Pipeline Flow Log

Records pipeline-level events: user pauses, Rule 3 enforcement, operator
acknowledgement denials, and rapid-fire stall detection. Generated by AI/DLC
hook scripts. Rotated per sprint at retro close (Rule 25(c)).

Event types:

- `USER_PAUSE`: user sent a message; pipeline paused via flag file
- `BLOCKED`: Stop event blocked; Rule 3 enforcement forced continue
- `ALLOWED_BY_PAUSE`: Stop event allowed because pause flag exists
- `ACK_DENIED`: a pipeline-advancing tool call was DENIED because an operator
  message was outstanding and unacknowledged (Rule 29). A nonzero count means
  the lead tried to execute straight through a waiting human and the hook --
  not the lead's judgment -- is what stopped it. Investigate each one.
- `BACKOFF`: rapid-fire stop attempts detected; stall confirmed

---

EOF
fi

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
