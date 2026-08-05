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
# Does this event carry operator prose?
# -----------------------------------------------------------------------------
# Computed BEFORE the snapshot gate below, because two things need it and they are
# gated differently: the pause flag (active pipeline only) and the operator-request
# capture (always, including the very first /ai-dlc of a project, when no snapshot
# exists yet by definition).
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
# prefix list. That list is a
# hand-maintained enumeration of harness spellings, and re-homing it here in bash makes it
# two lists in two languages that drift apart -- the exact duplication class this codebase
# keeps paying for. It also trades the safe failure direction for the unsafe one: a
# mis-scoped prefix silently discards a real steer. If a broader predicate is ever needed,
# single-source it, do not copy it.
#
# The evidence for the wider arms is not clean and is not being acted on here. The
# consumer's own RCA retracted one arm after a live negative control falsified it, and
# recorded two later background-completion events that did NOT create the flag, contradicting
# its own rate. The empty-prompt arm is the part that survived.
#
# v0.265.0 -- THE BROADER PREDICATE IS NOW NEEDED, AND IT IS SINGLE-SOURCED, AS THE
# PARAGRAPH ABOVE REQUIRED. The empty-prompt arm caught only the empty case, and a
# background-completion event is not empty. Measured on the reference consumer live:
# 4 of its 5 USER_PAUSE events carried a background-completion preview and ONE carried
# operator prose, so four fifths of the pauses that sprint were raised by a background
# command completing. That is the same failure this header says was root-caused, still
# firing through the arm the narrow predicate does not cover.
#
# The prefixes are NOT written here. They are resolved from core/schemas/harness-origin.json,
# which is also what validate-steering-budget.sh's genuineOperatorText is bound to by
# invariant -- so there is one declaration and three readers, not three lists in three
# languages. Matching is ANCHORED, after <system-reminder> stripping, for a reason that is
# the difference between this and a mis-scoped filter: a prompt that MENTIONS a notification
# is operator prose ABOUT a notification, and discarding it would be the false NON-pause this
# header calls the dangerous direction.
HARNESS_ORIGIN_SCHEMA=""
for _hos in "${PROJECT_DIR}/.claude/schemas/harness-origin.json" \
            "${PROJECT_DIR}/core/schemas/harness-origin.json"; do
  [ -f "$_hos" ] && { HARNESS_ORIGIN_SCHEMA="$_hos"; break; }
done

# is_harness_origin <text> -> 0 when the text starts with a declared harness prefix.
#
# THE UNRESOLVED CASE ANSWERS "NO", AND THAT DIRECTION IS DELIBERATE. If the declaration
# cannot be read, every prompt is treated as operator prose: the pause still fires and the
# request is still captured. The alternative fails silent in the direction this whole hook
# exists to prevent -- a real steer dropped because a JSON file was missing. The condition is
# not hidden either; the caller logs HARNESS_ORIGIN_UNRESOLVED so a run that lost the
# declaration does not read as a run with nothing to skip.
is_harness_origin() {
  [ -n "$HARNESS_ORIGIN_SCHEMA" ] || return 1
  printf '%s' "$1" | jq -Rs --slurpfile s "$HARNESS_ORIGIN_SCHEMA" -e '
    . as $t | ($s[0].prefixes // []) | any(. as $p | ($t | startswith($p)))
  ' >/dev/null 2>&1
}

PROMPT_NO_REMINDERS=$(printf '%s' "$PROMPT_RAW" \
  | sed -e 's/<system-reminder>.*<\/system-reminder>//g' \
  | sed -e 's/^[[:space:]]*//')
PROMPT_STRIPPED=$(printf '%s' "$PROMPT_NO_REMINDERS" | tr -d '[:space:]')
if [ -n "$PROMPT_STRIPPED" ] && is_harness_origin "$PROMPT_NO_REMINDERS"; then
  PROMPT_STRIPPED=""
  HARNESS_ORIGIN=1
else
  HARNESS_ORIGIN=0
fi

# -----------------------------------------------------------------------------
# Capture the operator's request -- a HARNESS artifact, not a lead artifact
# -----------------------------------------------------------------------------
# WHY THIS EXISTS. `user_request_verbatim` in the pipeline snapshot is prose the LEAD
# writes about what the operator asked for. Nothing produced it but the lead, and nothing
# could contradict it. On the reference consumer a lead recorded that field as a POINTER to
# the PREVIOUS sprint's locked block, planned three stories sharing not one identifier with
# the actual ask, and passed four consecutive gates green. The operator's words existed --
# 1359 bytes of them, timestamped -- and no artifact in the pipeline held them.
#
# This hook is the only place in the system that sees an operator's message before any agent
# interprets it. So it writes them down.
#
# WHY ABOVE THE SNAPSHOT GATE. The gate below exits when no snapshot exists, and its own
# comment names the case it is skipping: "the /ai-dlc invocation case: first message, no
# snapshot yet". That is precisely the message worth keeping -- the sprint kickoff. Capturing
# below the gate would miss the first request of every project, which is the one request no
# later artifact can reconstruct.
#
# WHY THE COMMAND TOKEN IS SPLIT OFF. The harness hands this hook the RAW typed text
# (`/ai-dlc Sprint 300: ...`), while the transcript stores the same message as an envelope
# whose <command-args> holds only the argument body. Recording the raw form verbatim would
# produce a record that cannot be cited against the transcript it came from -- the leading
# `/ai-dlc ` appears in one and not the other. The body is what the operator composed; the
# command token is how they addressed it. They are stored in different fields.
#
# APPEND-ONLY, and structurally so. The filename ends in `-history.md`, which is what
# validate-artifact-budget.sh's is_archive() reads: no budget row, no rotation, no trim. A
# provenance record that can be evicted to fit a budget is not a provenance record -- and
# eviction-with-no-durable-home is the failure this same sprint suffered five times.
REQUESTS_FILE="${LOG_DIR}/operator-requests-history.md"
if [ -n "$PROMPT_STRIPPED" ]; then
  case "$PROMPT_RAW" in
    /*) REQ_COMMAND=$(printf '%s' "$PROMPT_RAW" | sed -e 's/[[:space:]].*$//' -e 's/^\(.\{1,64\}\).*/\1/')
        REQ_BODY=$(printf '%s' "$PROMPT_RAW" | sed -e '1s/^[^[:space:]]*[[:space:]]*//') ;;
    *)  REQ_COMMAND="(typed)"
        REQ_BODY="$PROMPT_RAW" ;;
  esac
  # Strip system-reminder blocks from the stored body for the same reason the predicate
  # above strips them: they are harness injection, not operator prose. Everything else --
  # newlines, punctuation, casing -- is preserved byte-for-byte, because the whole value of
  # this record is that it was not paraphrased.
  REQ_BODY=$(printf '%s' "$REQ_BODY" | sed -e 's/<system-reminder>.*<\/system-reminder>//g')
  if [ -n "$(printf '%s' "$REQ_BODY" | tr -d '[:space:]')" ]; then
    mkdir -p "$LOG_DIR"
    if [ ! -s "$REQUESTS_FILE" ]; then
      cat > "$REQUESTS_FILE" <<'EOF'
# Operator Requests

Every message an operator sent, recorded by the UserPromptSubmit hook BEFORE any agent read
it. Append-only. Written by `ai-dlc-pause.sh`; no agent may edit or reorder it.

This file exists because `user_request_verbatim` in the pipeline snapshot is the LEAD's
account of what was asked, and a lead that misremembers the ask produces a snapshot nothing
can contradict. This is the record that can.

`body` is what the operator composed, with any leading slash-command token moved to
`command`. That split is what makes an entry CITABLE: the harness hands the hook the raw
typed text, while the session transcript stores the same message as an envelope holding only
the argument body. Verify any entry with:

    validate-steering-budget.sh --dir <transcript-dir> --cite "<a phrase from body>"

Rotation: none, ever. The filename ends `-history.md` so the artifact-budget validator
treats it as an archive (Rule 25(a)): growth is free, and nothing may trim it.

---

EOF
    fi
    REQ_SHA=$(printf '%s' "$REQ_BODY" | { shasum -a 256 2>/dev/null || sha256sum; } | cut -d' ' -f1)
    {
      echo "## ${TIMESTAMP} -- ${REQ_COMMAND}"
      echo "- Session: ${SESSION_ID}"
      echo "- Bytes: $(printf '%s' "$REQ_BODY" | wc -c | tr -d '[:space:]')"
      echo "- SHA256: ${REQ_SHA}"
      echo ""
      echo '```text'
      printf '%s\n' "$REQ_BODY"
      echo '```'
      echo ""
    } >> "$REQUESTS_FILE"
  fi
fi

# -----------------------------------------------------------------------------
# Skip if no active pipeline
# -----------------------------------------------------------------------------
if [ ! -f "$SNAPSHOT_FILE" ]; then
  # No snapshot means no active pipeline. Don't create flag.
  # This covers the /ai-dlc invocation case: first message, no snapshot
  # yet, skip. Claude starts the pipeline. By the time snapshot exists,
  # we're in autonomous mode. The capture above has already run -- it is
  # deliberately NOT gated on the pipeline being live.
  exit 0
fi
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
    # THE TWO SKIP REASONS ARE NAMED SEPARATELY, because they have different remedies and
    # a reader counting PAUSE_SKIPPED cannot otherwise tell "quiet sprint" from "the
    # harness-origin declaration went missing and every prompt is being treated as prose".
    if [ "${HARNESS_ORIGIN:-0}" = "1" ]; then
      echo "- Reason: prompt was raised by the harness, not the operator (matched a prefix in schemas/harness-origin.json)"
      echo "- Preview: ${PROMPT_PREVIEW}"
    else
      echo "- Reason: UserPromptSubmit carried no operator prose (empty after stripping system-reminders)"
    fi
    if [ -z "$HARNESS_ORIGIN_SCHEMA" ]; then
      echo "- HARNESS_ORIGIN_UNRESOLVED: schemas/harness-origin.json was not found, so no prompt could be"
      echo "  classified as harness-raised this run. Every prompt was treated as operator prose, which is the"
      echo "  safe direction and the wrong answer. Reinstall ai-dlc."
    fi
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
  # Emitted on THIS path too, not only on the skip path. A missing declaration produces
  # pauses, not skips -- so a note that appeared only where nothing was skipped would be
  # absent from every run where the condition actually cost something.
  if [ -z "$HARNESS_ORIGIN_SCHEMA" ]; then
    echo "- HARNESS_ORIGIN_UNRESOLVED: schemas/harness-origin.json was not found, so this pause may have been"
    echo "  raised by the harness rather than the operator and nothing could tell. Reinstall ai-dlc."
  fi
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