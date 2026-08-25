#!/bin/bash
#
# AI/DLC Escalation Delivery Hook
#
# PURPOSE
# Records a `SendMessage` that did not arrive. When the lead escalates to a named
# session and that session is gone, the call REPORTS SUCCESS AT THE TOOL LEVEL and
# returns a payload saying it failed. Nothing observed that, so an escalation the
# lead believed it had sent simply never happened, and the only trace was a line in
# a transcript that a compaction then summarized away.
#
# THE MEASUREMENT. On the reference consumer's sprint 305 the operator's standing
# instruction was to send every decision to one named session. `SendMessage` to that
# session returned `No agent named 'graph-6b' is reachable.` three times -- once in
# each of the last three sessions -- and no artifact anywhere recorded it.
#
# WHY IT WAS SILENT, AND WHY THE SENSOR IS `.tool_response.success`. Measured across
# 1141 real SendMessage results: 1123 `success:true`, 18 `success:false`, and
# `is_error` was ABSENT ON ALL EIGHTEEN. The harness treats an undelivered message as
# a SUCCESSFUL tool call returning a failure payload, so `PostToolUseFailure` never
# fires for it and an error-flag sensor reads clean forever. The failure is only
# visible INSIDE the response body. That is the whole reason this hook exists rather
# than a matcher on an error event.
#
# THE FALSE-POSITIVE SET IS ENUMERATED, NOT EMPTY, and the entry carries what a
# reader needs to sort it. Of those 18: 9 were `No agent named 'parent' is reachable`
# (a subagent answering upward, routine, NOT an operator escalation), 1 was
# `notify_when_idle is only supported for...` (a capability refusal, not a delivery
# failure), and 8 were genuine undelivered messages to named sessions, 3 of them the
# s305 escalations this hook was built for. The event is therefore emitted for EVERY
# `success:false` -- no message-text grammar, which would be a fragile parser over
# harness prose -- and the TARGET and the harness's own message are recorded on the
# entry so a retro can separate the classes by reading rather than by trusting a
# count. A count of this event is a FLOOR on undelivered messages and an OVERCOUNT of
# undelivered escalations; the legend says so where the count is read.
#
# NEVER BLOCKS. This hook observes; it has no verdict, and every path exits 0. A
# recorder that can fail a tool call would make the pipeline's ability to send a
# message depend on its ability to write a file.
#
# OUTPUT
# - Appends to: _bmad-output/pipeline-continuation-log.md
# - stdout: nothing
#
# INSTALL
# 1. Place at .claude/hooks/ai-dlc-escalation-delivery.sh
# 2. chmod +x .claude/hooks/ai-dlc-escalation-delivery.sh
# 3. Add to .claude/settings.json hooks:
#      "PostToolUse": [
#        {
#          "matcher": "SendMessage",
#          "hooks": [{
#            "type": "command",
#            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/ai-dlc-escalation-delivery.sh"
#          }]
#        }
#      ]
# 4. Restart Claude Code
# 5. Verify with /hooks

set -u

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
LOG_DIR="${PROJECT_DIR}/_bmad-output"
LOG_FILE="${LOG_DIR}/pipeline-continuation-log.md"

INPUT=$(cat)

# jq is required to read the payload at all. Absent it, exit quietly rather than
# writing a partial record -- a missing entry is a gap a later check can count, a
# corrupt one is not. Same contract as ai-dlc-answer-capture.sh.
command -v jq >/dev/null 2>&1 || exit 0

TOOL_NAME=$(jq -r '.tool_name // empty' <<<"$INPUT" 2>/dev/null)
[ "$TOOL_NAME" = "SendMessage" ] || exit 0

# BOOLEAN `false` ONLY, COMPARED INSIDE jq. A missing, null or non-boolean field is NOT a
# failure: an absent `success` is a shape this hook has never seen, and inventing a verdict
# from it would manufacture escalation reports out of a harness change. The fail-safe
# direction here is silence, because the subject is a LOG rather than a gate.
#
# NOT `// empty`, AND THAT IS THE WHOLE POINT. jq's alternative operator treats `false`
# exactly as it treats null and absent, so `.tool_response.success // empty` yields NOTHING
# on the one input this hook exists for. Written that way first, the hook was silent on a
# verbatim sprint-305 failure payload and its every arm still exited 0 — a recorder that can
# never record, indistinguishable from a clean channel. The fixture's offender arm caught it.
#
# The comparison also has to be TYPE-STRICT: a string `"false"` is not a failed send, and
# `jq -r` would flatten the two into the same characters. `== false` inside jq is true only
# for the boolean.
IS_FALSE=$(jq -r '(.tool_response.success == false) | tostring' <<<"$INPUT" 2>/dev/null)
[ "$IS_FALSE" = "true" ] || exit 0

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SESSION_ID=$(jq -r '.session_id // empty' <<<"$INPUT" 2>/dev/null)
TARGET=$(jq -r '.tool_input.to // empty' <<<"$INPUT" 2>/dev/null)
# The harness's own words, flattened to one line: it names the target and often
# suggests a live one, and it is the sentence a retro reader needs.
DETAIL=$(jq -r '.tool_response.message // empty' <<<"$INPUT" 2>/dev/null | tr '\n' ' ' | sed 's/  */ /g')

mkdir -p "$LOG_DIR" 2>/dev/null || exit 0

# SEEDS THE SAME LEGEND AS THE OTHER THREE WRITERS, BYTE-IDENTICALLY. Whichever hook
# opens this file first decides the legend the whole sprint reads, and `retro.md` §4b
# counts events out of it. `core/fixtures/pause-hook-origin` assertion 8 compares all
# FOUR bodies and fails the push on any disagreement -- so this copy is bound, not
# trusted. Do not edit it here alone.
if [ ! -s "$LOG_FILE" ]; then
  cat > "$LOG_FILE" <<'EOF'
# Pipeline Flow Log

Records pipeline-level events: user pauses, Rule 3 enforcement, operator
acknowledgement denials, and rapid-fire stall detection. Generated by AI/DLC
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
  message was outstanding and unacknowledged (Rule 29). A nonzero count means
  the lead tried to execute straight through a waiting human and the hook --
  not the lead's judgment -- is what stopped it. Investigate each one.
- `BACKOFF`: rapid-fire stop attempts detected; stall confirmed
- `ESCALATION_UNDELIVERED`: a SendMessage returned `success:false`, so an
  operator-bound message was never delivered. The harness does NOT mark these
  as tool errors, which is why they fell through silently; a nonzero count
  means an escalation the lead believed it had sent did not arrive. Read the
  recorded target -- a failure to reach `parent` is subagent routing, not an
  operator escalation

Retro reviews this log to assess pipeline flow:

- High USER_PAUSE counts mean the user intervened often (normal for
  interactive sprints, concerning if unexpected)
- High PAUSE_SKIPPED counts are normal in a sprint with heavy background
  dispatch; a SUDDEN change in the USER_PAUSE:PAUSE_SKIPPED ratio is the
  signal worth reading
- High BLOCKED counts mean Rule 3 enforcement is doing work; without
  the hook the pipeline would have stalled
- BACKOFF entries indicate the pipeline actually got stuck and the
  hook exhausted its retry budget. Investigate the transcript around
  each BACKOFF to find the upstream cause.

Counting entries: one event is one `## <timestamp> -- <EVENT>` line. Count with
`grep -c '^## .*-- <EVENT>'`. A bare `grep -c <EVENT>` also matches this header,
which mentions every event name, so it over-reports — and the inflated number is
plausible enough that nothing about the result signals it counted documentation.

---

EOF
fi

{
  echo "## ${TIMESTAMP} -- ESCALATION_UNDELIVERED"
  echo "- Session: ${SESSION_ID}"
  echo "- Intended recipient: ${TARGET:-<none recorded>}"
  echo "- Harness reported: ${DETAIL:-<no message field>}"
  echo "- The tool call itself did NOT error; the failure was inside the response body."
  echo ""
} >> "$LOG_FILE"

exit 0
