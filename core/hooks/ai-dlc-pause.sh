#!/bin/bash
#
# AI/DLC Pipeline Pause Hook
#
# PURPOSE
# Pauses the AI/DLC pipeline whenever the user sends a message.
# Creates a flag file that the Stop hook (ai-dlc-continue.sh) reads
# to honor the pause. The lead interprets the user's intent and
# deletes the flag when appropriate (e.g., user wants to resume).
#
# DESIGN CONTRACT
# - Pipeline runs autonomously when no pause flag exists
# - Any user message CARRYING PROSE creates the pause flag. The harness raises
#   UserPromptSubmit identically when a backgrounded task completes as when a
#   human types, so an event whose prompt is empty once <system-reminder> blocks
#   are stripped is not an operator turn and is logged PAUSE_SKIPPED instead.
#   See the predicate below for why it stops there and must not be broadened by
#   copying another script's list of harness prefixes.
# - The lead deletes the flag to resume autonomous execution
# - Flag deletion is the lead's responsibility, not this hook's
#
# GATING
# Only creates the flag when a pipeline snapshot exists. This prevents
# cluttering non-AI/DLC sessions with flag files. If the user invokes
# /ai-dlc for the first time (no snapshot yet), this hook skips and
# the pipeline starts normally. By the time Claude writes the first
# snapshot, the pipeline is in autonomous mode.
#
# OUTPUT
# - Creates: _bmad-output/pipeline-paused.flag (empty file, acts as
#   signal)
# - Appends to: _bmad-output/pipeline-continuation-log.md
# - stdout: JSON with additionalContext telling the lead what to do
#
# INSTALL
# 1. Place at .claude/hooks/ai-dlc-pause.sh
# 2. chmod +x .claude/hooks/ai-dlc-pause.sh
# 3. Add to .claude/settings.json hooks:
#      "UserPromptSubmit": [
#        {
#          "hooks": [{
#            "type": "command",
#            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/ai-dlc-pause.sh"
#          }]
#        }
#      ]
# 4. Restart Claude Code
# 5. Verify with /hooks

set -u

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
SNAPSHOT_FILE="${PROJECT_DIR}/_bmad-output/pipeline-snapshot.md"
LOG_DIR="${PROJECT_DIR}/_bmad-output"
LOG_FILE="${LOG_DIR}/pipeline-continuation-log.md"
PAUSE_FLAG="${LOG_DIR}/pipeline-paused.flag"

# -----------------------------------------------------------------------------
# Read hook input
# -----------------------------------------------------------------------------
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
PROMPT_RAW=$(echo "$INPUT" | jq -r '.prompt // empty')
PROMPT_PREVIEW=$(printf '%s' "$PROMPT_RAW" | head -c 120 | tr '\n' ' ')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# -----------------------------------------------------------------------------
# Skip if no active pipeline
# -----------------------------------------------------------------------------
if [ ! -f "$SNAPSHOT_FILE" ]; then
  # No snapshot means no active pipeline. Don't create flag.
  # This covers the /ai-dlc invocation case: first message, no snapshot
  # yet, skip. Claude starts the pipeline. By the time snapshot exists,
  # we're in autonomous mode.
  exit 0
fi

# -----------------------------------------------------------------------------
# Skip if the event carries no operator prose
# -----------------------------------------------------------------------------
# The harness raises UserPromptSubmit identically when a backgrounded task completes as
# when a human types. This hook inspected neither the prompt nor its origin, so it created
# a pause flag for events carrying no operator prose at all, and the lead then blocked on a
# pause no human initiated. Root-caused on the reference consumer after five occurrences
# across two sprints left it undiagnosed -- the flag looks the same whoever created it.
#
# THE PREDICATE IS DELIBERATELY NARROW: the prompt is empty, or whitespace once
# <system-reminder> blocks are stripped. A false NON-pause is the dangerous direction --
# it means the lead executes straight through a real operator steer, which is the failure
# Rule 29 and the whole steering-budget check exist to prevent. This arm cannot swallow a
# prompt carrying operator prose, because it fires only when there is none.
#
# DO NOT "COMPLETE" THIS by mirroring validate-steering-budget.sh's genuineOperatorText
# prefix list (<task-notification, <local-command, <agent-message, ...). That list is a
# hand-maintained enumeration of harness spellings, and re-homing it here in bash makes it
# two lists in two languages that drift apart -- the exact duplication class this codebase
# keeps paying for. It also trades the safe failure direction for the unsafe one: a
# mis-scoped prefix silently discards a real steer. If a broader predicate is ever needed,
# single-source it, do not copy it.
#
# The evidence for the wider arms is not clean and is not being acted on here. The
# consumer's own RCA retracted one arm after a live negative control falsified it, and
# recorded two later task-notification events that did NOT create the flag, contradicting
# its own rate. The empty-prompt arm is the part that survived.
PROMPT_STRIPPED=$(printf '%s' "$PROMPT_RAW" \
  | sed -e 's/<system-reminder>.*<\/system-reminder>//g' \
  | tr -d '[:space:]')
# Seed the log header if this is the first write. Both the skip path and the pause path
# call this: whichever event lands first, the legend that explains it must already be there.
seed_log_header() {
  mkdir -p "$LOG_DIR"
  [ -s "$LOG_FILE" ] && return 0
  cat > "$LOG_FILE" <<'EOF'
# Pipeline Flow Log

Records pipeline-level events: user pauses, Rule 3 enforcement, operator
acknowledgement denials, and loop-prevention backoffs. Generated by AI/DLC
hook scripts. Rotated per sprint at retro close (Rule 25(c)).

Event types:

- `USER_PAUSE`: user sent a message; pipeline paused via flag file
- `PAUSE_SKIPPED`: a UserPromptSubmit carried no operator prose, so no pause
  flag was created. The harness raises the event identically for a completed
  background task and for a human typing; this records the ones that were not
  a human, so a pause that never happened is distinguishable from one the lead
  already cleared
- `BLOCKED`: Stop event blocked; Rule 3 enforcement forced continue
- `ALLOWED_BY_PAUSE`: Stop event allowed because pause flag exists
- `ACK_DENIED`: a pipeline-advancing tool call was DENIED because an operator
  message was outstanding and unacknowledged (Rule 29)
- `BACKOFF`: stop_hook_active was true; loop prevention engaged

Retro reviews this log to assess pipeline flow:

- High USER_PAUSE counts mean the user intervened often (normal for
  interactive sprints, concerning if unexpected)
- High PAUSE_SKIPPED counts are normal in a sprint with heavy background
  dispatch; a SUDDEN change in the USER_PAUSE:PAUSE_SKIPPED ratio is the
  signal worth reading
- High BLOCKED counts mean Rule 3 enforcement is doing work; without
  the hook the pipeline would have stalled
- BACKOFF entries indicate the pipeline got stuck and the safety
  valve triggered

Counting entries: one event is one `## <timestamp> -- <EVENT>` line. Count with
`grep -c '^## .*-- <EVENT>'`. A bare `grep -c <EVENT>` also matches this header,
which mentions every event name, so it over-reports — and the inflated number is
plausible enough that nothing about the result signals it counted documentation.

---

EOF
}

if [ -z "$PROMPT_STRIPPED" ]; then
  # A SILENT skip is the same defect one layer down: a pause that never happened reads
  # exactly like a pause the lead already cleared, and nothing would record which.
  seed_log_header
  {
    echo "## ${TIMESTAMP} -- PAUSE_SKIPPED"
    echo "- Session: ${SESSION_ID}"
    echo "- Reason: UserPromptSubmit carried no operator prose (empty after stripping system-reminders)"
    echo ""
  } >> "$LOG_FILE"
  exit 0
fi

# -----------------------------------------------------------------------------
# Pipeline is active. Create pause flag.
# -----------------------------------------------------------------------------
mkdir -p "$LOG_DIR"
touch "$PAUSE_FLAG"

# -----------------------------------------------------------------------------
# Log the pause event
# -----------------------------------------------------------------------------
seed_log_header

{
  echo "## ${TIMESTAMP} -- USER_PAUSE"
  echo "- Session: ${SESSION_ID}"
  echo "- Prompt (first 120 chars): ${PROMPT_PREVIEW}"
  echo ""
} >> "$LOG_FILE"

# -----------------------------------------------------------------------------
# Inject context so the lead knows about the pause
# -----------------------------------------------------------------------------
# This fires on every user message during an active pipeline. Keep it
# concise -- the lead sees this as additionalContext before processing
# the user's message.

CONTEXT="[AI/DLC Pipeline Control] A user message was received while the pipeline is active. The pipeline has been paused via flag file at _bmad-output/pipeline-paused.flag. Before continuing pipeline work, interpret the user's intent: (a) Resume intent -- including /ai-dlc invocations, handoff resume prompts, or natural resume language -- delete the flag via Bash (rm _bmad-output/pipeline-paused.flag) then RE-READ the current step file (Rule 22: Read tool call for the step file named in pipeline-snapshot.md Pipeline Position, enumerate remaining numbered sections in output, THEN execute them). Do not act from memory of what remains. (b) Question, correction, clarification, or conversational message -- respond normally; leave the flag in place. (c) Handoff request -- follow Rule 2 handoff protocol; leave the flag in place. Do not execute pipeline steps while the flag exists."

jq -n \
  --arg context "$CONTEXT" \
  '{
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext: $context
    }
  }'

exit 0