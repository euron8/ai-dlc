#!/usr/bin/env bash
# ai-dlc-context-sensor.sh — Stop hook. Measures resident context, fires Rule 2.
#
# PURPOSE
# Rule 2(b)/(c) yellow and red reminders exist so the high-fidelity handoff
# (/clear + /ai-dlc resume) gets first refusal before Claude Code's auto-compact
# takes the lossy path. Until this hook existed, the only authoritative trigger
# was the user pasting `/context` output. Across 243 real consumer sessions that
# happened twice, while 184 of them crossed the red threshold. The reminders
# almost never fired, so the ordering invariant was decorative.
#
# HOW IT MEASURES
# Hook stdin carries no token counts (the shared schema is session_id,
# transcript_path, cwd, prompt_id, permission_mode, agent_id, agent_type,
# effort). But it carries `transcript_path`, and every assistant message in the
# transcript carries `message.usage`. Claude Code's own context figure is
#     input_tokens + cache_creation_input_tokens + cache_read_input_tokens
# taken from the last main-thread assistant message AFTER the most recent
# compaction boundary -- a pre-boundary line still carries the old, larger
# pre-compaction window. This hook computes exactly that, so its reading equals
# `compactMetadata.preTokens`.
#
# DESIGN CONTRACT
# - Decision-free. Never emits `decision`; always exits 0. Rule 2 reminders are
#   non-blocking and the user decides (SKILL.md Rule 2). This hook makes the
#   reminder fire; it does not change what the reminder means.
# - Runs alongside ai-dlc-continue.sh and ai-dlc-driver-signal.sh. The Stop
#   result loop collects each hook's additionalContext independently of whether
#   a sibling hook sets preventContinuation, so the reminder reaches the model
#   even on a turn that ai-dlc-continue.sh blocks.
# - Owns its own fire state. The snapshot's Context Reminders fields are written
#   by the lead at gates (a handful per session, against a p50 of 242 turns) --
#   far too coarse to dedupe a per-turn sensor.
#
# OUTPUT
# - Writes: _bmad-output/.context-sensor-state  (fire state, per pipeline)
# - Writes: _bmad-output/.context-sensor-model  (proven model row, sticky)
# - stdout: JSON with additionalContext, only on a firing turn. Silent otherwise.
#
# Register in .claude/settings.json AFTER ai-dlc-continue.sh and
# ai-dlc-driver-signal.sh:
#   "Stop": [ { "hooks": [
#     { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/ai-dlc-continue.sh" },
#     { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/ai-dlc-driver-signal.sh" },
#     { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/ai-dlc-context-sensor.sh" }
#   ] } ]

set -u

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
STATE_DIR="${PROJECT_DIR}/${AI_DLC_STATE_DIR:-_bmad-output}"
SNAPSHOT_FILE="${STATE_DIR}/pipeline-snapshot.md"
STATE_FILE="${STATE_DIR}/.context-sensor-state"
MODEL_FILE="${STATE_DIR}/.context-sensor-model"
SKILL_MD="${PROJECT_DIR}/.claude/skills/ai-dlc/SKILL.md"
SETTINGS_JSON="${PROJECT_DIR}/.claude/settings.json"

# Claude Code compacts at `effectiveWindow - COMPACT_RESERVE`, but the quantity
# THIS hook measures sits a further ~18,000 below that at fire time: the check
# adds an output allowance before comparing. Measured on two independent windows
# (287,000-268,892=18,108 and 987,000-969,084=17,916). So the ceiling visible to
# a transcript-derived reading is `effectiveWindow - SENSOR_RESERVE`.
COMPACT_RESERVE=13000
SENSOR_RESERVE="${AI_DLC_SENSOR_RESERVE:-31000}"

# A warning delivered AT the ceiling is worthless: compaction fires on the very
# next model request, so the injected directive is destroyed by the event it
# warns about. Worse, the ceiling is usually never observed at all -- the three
# real compactions on the `graph` consumer last measured 268,892 / 267,719 /
# 267,445 against a 269,000 ceiling, because compaction preempted the next turn.
#
# So the critical band opens IMMINENT_LEAD tokens below the ceiling. At the
# measured p50 growth of ~1,200 tokens/turn, 20,000 buys roughly 16 turns -- room
# to refresh the snapshot and hand off deliberately.
IMMINENT_LEAD="${AI_DLC_SENSOR_IMMINENT_LEAD:-20000}"

# Recurrence, matching _gate-procedures.md: re-fire the current level after a
# 50,000-token or 20-turn delta.
RECUR_TOKENS="${AI_DLC_SENSOR_RECUR_TOKENS:-50000}"
RECUR_TURNS="${AI_DLC_SENSOR_RECUR_TURNS:-20}"

# A drop this large means the context was compacted or /clear'ed.
RESET_DROP="${AI_DLC_SENSOR_RESET_DROP:-50000}"

# A 200K model auto-compacts at 187,000, so it can never be observed at or above
# that. Any reading this high PROVES the window is larger than 200K.
PROOF_1M=$(( 200000 - COMPACT_RESERVE ))

# Fail-open on every error path: a missing reading is never worse than a wrong
# one, and this hook must never be able to stall the pipeline.
command -v jq >/dev/null 2>&1 || exit 0

# -----------------------------------------------------------------------------
# Read hook input and gate
# -----------------------------------------------------------------------------
INPUT="$(cat 2>/dev/null || true)"
[ -n "$INPUT" ] || exit 0

# Subagents fire SubagentStop, not Stop, so agent_id should never be set here.
# Guard anyway: a subagent's usage describes its own window, not the lead's.
AGENT_ID="$(printf '%s' "$INPUT" | jq -r '.agent_id // empty' 2>/dev/null || true)"
[ -z "$AGENT_ID" ] || exit 0

# This hook is wired to two events. Stop fires when the model ends its turn; but
# an autonomous pipeline run can go hundreds of tool calls deep without ever
# ending a turn (a real `graph` session climbed 77K->270K across 169 tool_use
# messages with ZERO Stop boundaries, so the sensor never sampled and compaction
# fired unwarned). PostToolBatch fires once per tool batch, before the next model
# request, and catches exactly those turn-less runs. The emitted hookEventName
# must echo whichever event invoked us.
EVENT="$(printf '%s' "$INPUT" | jq -r '.hook_event_name // "Stop"' 2>/dev/null || echo Stop)"
case "$EVENT" in Stop|PostToolBatch) ;; *) EVENT=Stop ;; esac

# Not an AI/DLC session -> stay out of it entirely.
[ -f "$SNAPSHOT_FILE" ] || exit 0

TRANSCRIPT="$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || true)"
[ -n "$TRANSCRIPT" ] && [ -r "$TRANSCRIPT" ] || exit 0

# -----------------------------------------------------------------------------
# Throttle (PostToolBatch only)
#
# Stop is infrequent and carries the snapshot-reconcile semantics, so it always
# reads. PostToolBatch fires on every tool batch -- a full tail-read (up to a 4MB
# jq scan) that often is real hot-path latency. Skip it unless the transcript has
# grown by THROTTLE_BYTES since the last full read, tracked as `last_read_size`
# in the sidecar. The first read of a session (no sidecar) is never throttled, so
# sampling always starts. A crossing is at most THROTTLE_BYTES of transcript
# late, and transcript bytes vastly outpace token growth (tool outputs), so this
# is far tighter than the token thresholds it feeds.
# -----------------------------------------------------------------------------
THROTTLE_BYTES="${AI_DLC_SENSOR_THROTTLE_BYTES:-524288}"
if [ "$EVENT" = PostToolBatch ] && [ -r "$STATE_FILE" ]; then
  LAST_READ_SIZE="$(sed -n 's/^last_read_size=//p' "$STATE_FILE" 2>/dev/null | head -1)"
  case "${LAST_READ_SIZE:-}" in ''|*[!0-9]*) LAST_READ_SIZE="" ;; esac
  if [ -n "$LAST_READ_SIZE" ]; then
    CUR_SIZE="$(wc -c < "$TRANSCRIPT" 2>/dev/null | tr -d ' ')"
    case "${CUR_SIZE:-}" in ''|*[!0-9]*) CUR_SIZE=0 ;; esac
    [ "$(( CUR_SIZE - LAST_READ_SIZE ))" -ge "$THROTTLE_BYTES" ] || exit 0
  fi
fi

# -----------------------------------------------------------------------------
# Bounded reverse tail-read
#
# Transcripts reach 7.5MB on a real consumer; never read the whole file. Scan a
# tail window for the last main-thread assistant line carrying usage. A single
# preceding tool_result line can be megabytes, pushing the assistant line out of
# a small window, so escalate. `fromjson?` discards the partial first line that
# `tail -c` produces.
#
# Only a reading from AFTER the most recent compaction counts. The window the
# transcript records flips at a `compact_boundary`: the last PRE-compaction
# assistant line still carries the old (large) usage, and on the first
# PostToolBatch after an auto-compact that line is the newest one on disk --
# the post-compaction turn has not been written yet. Selecting it reports the
# pre-compaction window (~preTokens) as resident and fires a false IMMINENT one
# request after compaction just reclaimed the space (observed on the graph
# consumer: 265,909 reported against a real 80,851). So: locate the most recent
# boundary in the window and take the last assistant-with-usage line that
# FOLLOWS it. A boundary with no post-boundary reading yet stays silent -- the
# same fail-open as a fresh transcript.
# -----------------------------------------------------------------------------
LINE=""
for N in ${AI_DLC_SENSOR_TAIL_BYTES:-262144} 1048576 4194304; do
  # -Rs slurps the tail as one string so a single jq pass can both locate the
  # boundary and pick the post-boundary reading. `fromjson?` drops the partial
  # first line `tail -c` produces and any non-JSON line.
  LINE="$(tail -c "$N" "$TRANSCRIPT" 2>/dev/null \
    | jq -Rsc '
        (split("\n") | map(fromjson?)) as $a
        | (reduce range(0; ($a | length)) as $i (-1;
             if $a[$i].type == "system" and $a[$i].subtype == "compact_boundary"
             then $i else . end)) as $b
        | [ range(0; ($a | length)) as $i
            | select($i > $b
                     and $a[$i].type == "assistant"
                     and ($a[$i].isSidechain | not)
                     and ($a[$i].message.usage != null))
            | $a[$i] ]
        | if length > 0 then .[-1] else empty end
      ' 2>/dev/null)"
  [ -n "$LINE" ] && break
done

# Fresh session, resume onto a new transcript, or a tail with no assistant turn.
# Silence is correct: we have no reading, so we assert nothing.
[ -n "$LINE" ] || exit 0

# Record the size at which we actually read, for the PostToolBatch throttle.
CUR_SIZE="$(wc -c < "$TRANSCRIPT" 2>/dev/null | tr -d ' ')"
case "${CUR_SIZE:-}" in ''|*[!0-9]*) CUR_SIZE=0 ;; esac

TOKENS="$(printf '%s' "$LINE" | jq '
  .message.usage
  | (.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0)
' 2>/dev/null || true)"
case "${TOKENS:-}" in ''|*[!0-9]*) exit 0 ;; esac
[ "$TOKENS" -gt 0 ] || exit 0

# -----------------------------------------------------------------------------
# Window resolution
#
# The transcript records `claude-opus-4-8` for BOTH the 200K and the 1M variant
# -- the `[1m]` suffix is stripped and no context_window_size is recorded
# anywhere. So the model row cannot be read off the transcript.
#
# The two mistakes are not symmetric. Assuming 200K on a 1M model fires the
# reminders early: noisy, but they are non-blocking. Assuming 1M on a 200K model
# puts red at 200,000 while compaction fires at 187,000 -- red never fires
# before compact, which is the exact failure the ordering invariant exists to
# prevent. So: assume 200K, and upgrade only on proof.
#
# Proof is sticky across sessions, so a project pays the early-reminder noise at
# most once. Set env AI_DLC_MODEL_ROW=1M in .claude/settings.json to skip it.
# -----------------------------------------------------------------------------
ROW="${AI_DLC_MODEL_ROW:-}"
ROW_KNOWN=0

# `auto` is the explicit "let the sensor infer it" spelling, so an operator who
# answered the install prompt with "not sure" lands back on the inference path
# rather than being pinned to a guess.
[ "$ROW" = "auto" ] && ROW=""

if [ -z "$ROW" ] && [ -r "$MODEL_FILE" ]; then
  ROW="$(sed -n 's/^row=//p' "$MODEL_FILE" 2>/dev/null | head -1)"
fi

case "$ROW" in
  200K|1M) ROW_KNOWN=1 ;;
  *)       ROW="200K"; ROW_KNOWN=0 ;;
esac

# A reading at or above a 200K model's compact threshold proves a larger window.
if [ "$ROW_KNOWN" -eq 0 ] && [ "$TOKENS" -ge "$PROOF_1M" ]; then
  ROW="1M"
  ROW_KNOWN=1
  mkdir -p "$STATE_DIR" 2>/dev/null || true
  printf 'row=1M\nproven_at_tokens=%s\n' "$TOKENS" > "$MODEL_FILE" 2>/dev/null || true
fi

case "$ROW" in
  1M) MODEL_MAX=1000000 ;;
  *)  MODEL_MAX=200000 ;;
esac

# autoCompactWindow: env > settings.json > unset. Accepts Claude Code's own
# spellings ("auto", "400k", "1m", bare int where 100..1000 means thousands).
#
# NOTE: byte-identical to parse_window() in scripts/validate-compact-window.sh.
# Hooks install to .claude/hooks/ and cannot source from scripts/, so this is
# duplicated deliberately. Keep the two in step.
parse_window() {
  local raw
  raw="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  case "$raw" in
    ""|auto) return 1 ;;
    *m) awk -v v="${raw%m}" 'BEGIN{printf "%d", v*1000000}' ;;
    *k) awk -v v="${raw%k}" 'BEGIN{printf "%d", v*1000}' ;;
    *[!0-9]*) return 1 ;;
    *)
      if [ "$raw" -ge 100 ] && [ "$raw" -le 1000 ]; then
        awk -v v="$raw" 'BEGIN{printf "%d", v*1000}'
      else
        printf '%d' "$raw"
      fi
      ;;
  esac
}

WINDOW=""
if [ -n "${CLAUDE_CODE_AUTO_COMPACT_WINDOW:-}" ]; then
  WINDOW="$(parse_window "$CLAUDE_CODE_AUTO_COMPACT_WINDOW" 2>/dev/null || true)"
fi
if [ -z "$WINDOW" ] && [ -r "$SETTINGS_JSON" ]; then
  RAW_WINDOW="$(jq -r '.autoCompactWindow // empty' "$SETTINGS_JSON" 2>/dev/null || true)"
  [ -n "$RAW_WINDOW" ] && WINDOW="$(parse_window "$RAW_WINDOW" 2>/dev/null || true)"
fi
case "${WINDOW:-}" in ''|*[!0-9]*) WINDOW="" ;; esac

EFFECTIVE="$MODEL_MAX"
if [ -n "$WINDOW" ] && [ "$WINDOW" -lt "$MODEL_MAX" ]; then
  EFFECTIVE="$WINDOW"
fi

# -----------------------------------------------------------------------------
# Thresholds from the SKILL.md table -- the same rows validate-compact-window.sh
# reads, and the ones projects are told to edit directly.
#   | 200K | 80K tokens  | 120K tokens |
#   | 1M   | 120K tokens | 200K tokens |
# -----------------------------------------------------------------------------
[ -r "$SKILL_MD" ] || exit 0

read -r YELLOW RED <<EOF
$(awk -F'|' -v want="$ROW" '
  /^\|[[:space:]]*(200K|1M)[[:space:]]*\|/ {
    gsub(/[[:space:]]/, "", $2)
    gsub(/[[:space:]]|tokens/, "", $3)
    gsub(/[[:space:]]|tokens/, "", $4)
    if ($2 != want) next
    y = $3; r = $4
    ymult = (y ~ /K$/) ? 1000 : 1; sub(/K$/, "", y)
    rmult = (r ~ /K$/) ? 1000 : 1; sub(/K$/, "", r)
    printf "%d %d\n", y * ymult, r * rmult
    exit
  }
' "$SKILL_MD" 2>/dev/null)
EOF

case "${YELLOW:-}" in ''|*[!0-9]*) exit 0 ;; esac
case "${RED:-}" in ''|*[!0-9]*) exit 0 ;; esac
[ "$RED" -gt "$YELLOW" ] || exit 0

# Runtime backstop for the ordering invariant that validate-compact-window.sh
# only checks at config time: if the configured red sits above this project's
# actual ceiling, red would never fire before compaction. Only meaningful when
# the row is KNOWN -- on an assumed row, EFFECTIVE is a guess and this would
# raise a false alarm ~100 turns early.
CEILING=$(( EFFECTIVE - SENSOR_RESERVE ))
IMMINENT=0
if [ "$ROW_KNOWN" -eq 1 ] && [ "$TOKENS" -ge $(( CEILING - IMMINENT_LEAD )) ]; then
  IMMINENT=1
fi

# -----------------------------------------------------------------------------
# Fire state
# -----------------------------------------------------------------------------
LAST_LEVEL=none
LAST_FIRE_TOKENS=0
LAST_FIRE_TURN=0
TURN=0

if [ -r "$STATE_FILE" ]; then
  LAST_LEVEL="$(sed -n 's/^last_level=//p'        "$STATE_FILE" 2>/dev/null | head -1)"
  LAST_FIRE_TOKENS="$(sed -n 's/^last_fire_tokens=//p' "$STATE_FILE" 2>/dev/null | head -1)"
  LAST_FIRE_TURN="$(sed -n 's/^last_fire_turn=//p'  "$STATE_FILE" 2>/dev/null | head -1)"
  TURN="$(sed -n 's/^turn_counter=//p'            "$STATE_FILE" 2>/dev/null | head -1)"
fi
case "$LAST_LEVEL" in none|yellow|red|imminent) ;; *) LAST_LEVEL=none ;; esac
case "${LAST_FIRE_TOKENS:-}" in ''|*[!0-9]*) LAST_FIRE_TOKENS=0 ;; esac
case "${LAST_FIRE_TURN:-}" in ''|*[!0-9]*) LAST_FIRE_TURN=0 ;; esac
case "${TURN:-}" in ''|*[!0-9]*) TURN=0 ;; esac

TURN=$(( TURN + 1 ))

# Self-healing: a large drop means compaction or /clear reset the window. The
# old fire state describes a context that no longer exists.
if [ "$LAST_FIRE_TOKENS" -gt 0 ] && [ "$TOKENS" -lt $(( LAST_FIRE_TOKENS - RESET_DROP )) ]; then
  LAST_LEVEL=none
  LAST_FIRE_TOKENS=0
  LAST_FIRE_TURN=0
fi

# Desired level for this reading. `imminent` is a level of its own, ranked above
# red, so that entering the critical band ALWAYS fires on the first crossing. If
# it merely reused `red`, a lead that already saw red at 200,000 would be waiting
# on the 50,000-token / 20-turn recurrence delta and could sail into compaction
# without ever being told to refresh the snapshot.
LEVEL=none
if [ "$IMMINENT" -eq 1 ]; then
  LEVEL=imminent
elif [ "$TOKENS" -ge "$RED" ]; then
  LEVEL=red
elif [ "$TOKENS" -ge "$YELLOW" ]; then
  LEVEL=yellow
fi

rank() { case "$1" in imminent) echo 3 ;; red) echo 2 ;; yellow) echo 1 ;; *) echo 0 ;; esac; }

FIRE=0
if [ "$(rank "$LEVEL")" -gt "$(rank "$LAST_LEVEL")" ]; then
  FIRE=1                                    # first crossing / escalation
elif [ "$LEVEL" != none ] && [ "$LEVEL" = "$LAST_LEVEL" ]; then
  if [ $(( TOKENS - LAST_FIRE_TOKENS )) -ge "$RECUR_TOKENS" ] \
     || [ $(( TURN - LAST_FIRE_TURN )) -ge "$RECUR_TURNS" ]; then
    FIRE=1                                  # recurrence
  fi
fi

mkdir -p "$STATE_DIR" 2>/dev/null || exit 0

if [ "$FIRE" -eq 1 ]; then
  NEW_FIRE_TOKENS="$TOKENS"
  NEW_FIRE_TURN="$TURN"
else
  NEW_FIRE_TOKENS="$LAST_FIRE_TOKENS"
  NEW_FIRE_TURN="$LAST_FIRE_TURN"
fi

{
  printf 'last_level=%s\n'        "$LEVEL"
  printf 'last_fire_tokens=%s\n' "$NEW_FIRE_TOKENS"
  printf 'last_fire_turn=%s\n'   "$NEW_FIRE_TURN"
  printf 'turn_counter=%s\n'     "$TURN"
  printf 'last_measured=%s\n'    "$TOKENS"
  printf 'last_read_size=%s\n'   "$CUR_SIZE"
  printf 'model_row=%s\n'        "$ROW"
  printf 'row_known=%s\n'        "$ROW_KNOWN"
  printf 'effective_window=%s\n' "$EFFECTIVE"
} > "$STATE_FILE" 2>/dev/null || true

[ "$FIRE" -eq 1 ] || exit 0

# -----------------------------------------------------------------------------
# Emit the Rule 2 reminder.
#
# Non-blocking: additionalContext only, never `decision`. Payload is well under
# Claude Code's 10,000-character additionalContext cliff (past which the harness
# persists the block to a file and replaces it with a stub), so unlike
# ai-dlc-recover.sh this needs no two-tier trimming.
# -----------------------------------------------------------------------------
PCT="$(awk -v t="$TOKENS" -v e="$EFFECTIVE" 'BEGIN{ printf "%d", (e > 0 ? t * 100 / e : 0) }')"

if [ "$LEVEL" = imminent ]; then
  THR=$(( CEILING - IMMINENT_LEAD ))
  # Turns of headroom at the measured p50 growth rate. Deliberately rounded down.
  TURNS_LEFT="$(awk -v c="$CEILING" -v t="$TOKENS" 'BEGIN{ n=int((c-t)/1200); print (n<1?1:n) }')"
  ADVICE="Auto-compact will fire at ~${CEILING} tokens -- roughly ${TURNS_LEFT} more turns at the observed growth rate. BEFORE your next pipeline action, refresh _bmad-output/pipeline-snapshot.md so it reflects the CURRENT state: Pipeline Position (current step file, in-flight sub-step), Recent Activity, Open Items, and any Locked Decisions taken since the last gate. A snapshot last written at a gate may be hundreds of turns stale, and it is what ai-dlc-recover.sh re-reads after compaction -- a stale snapshot is recovered faithfully and is still wrong. Having refreshed it, prefer Rule 2(a): hand off via /clear + /ai-dlc resume. Compaction is strictly lower fidelity than the handoff."
elif [ "$LEVEL" = red ]; then
  THR="$RED"
  ADVICE="Rule 2(c): finalize the pipeline snapshot and hand off via /clear + /ai-dlc resume before auto-compact takes the lossy path. If continuing, do so deliberately."
else
  THR="$YELLOW"
  ADVICE="Rule 2(b): finish the current sub-step, then continue."
fi

ROW_NOTE=""
[ "$ROW_KNOWN" -eq 0 ] && ROW_NOTE=" Model row assumed ${ROW} (not yet proven); set env AI_DLC_MODEL_ROW in .claude/settings.json to pin it."

CONTEXT="[AI/DLC context sensor] Resident context is ~${TOKENS} tokens (~${PCT}% of the ${EFFECTIVE}-token effective window), crossing the $(printf '%s' "$LEVEL" | tr '[:lower:]' '[:upper:]') threshold (${THR}). ${ADVICE} This reminder is non-blocking: the pipeline continues and the decision is the user's. Reconcile the snapshot Context Reminders fields to this reading at the next gate.${ROW_NOTE}"

jq -n --arg context "$CONTEXT" --arg event "$EVENT" '{
  hookSpecificOutput: {
    hookEventName: $event,
    additionalContext: $context
  }
}'

exit 0
