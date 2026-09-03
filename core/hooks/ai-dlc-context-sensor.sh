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
# THIS HOOK MUST NEVER TELL THE LEAD TO HAND OFF.
# Rule 2 is explicit: "Only path (a) initiates a handoff. Paths (b) and (c) are
# reminders only. The lead does NOT force handoff at any threshold." Path (a) is
# the OPERATOR asking. A threshold is not a request.
#
# The ADVICE strings below used to close with "prefer Rule 2(a): hand off via
# /clear + /ai-dlc resume" -- instructing the lead to take the one path only a
# human can initiate, and citing the very rule that forbids it. The wrapper text
# said "the decision is the user's" in the same breath, so a single injected
# message carried both a permission and an imperative. The lead resolved that
# contradiction in favour of the imperative and handed off mid-sprint, unasked.
#
# Observed live (S289): IMMINENT fired at 333k/380k, the lead refreshed the
# snapshot, announced "the handoff is safe to take," stopped three delivered
# teammates and ended the session. The operator had requested nothing. At RED the
# same lead had correctly held the line -- because the RED string happened to
# carry an "if continuing, do so deliberately" escape that IMMINENT lacked.
#
# So: keep the snapshot fresh and CONTINUE. No band asks the lead to voice the
# handoff trade-off either -- SKILL.md Rule 2(b)/(c)/(d) already owns what the
# lead says to the operator at each threshold, and a second copy of that
# instruction inside the injected reminder is the same permission-beside-a-
# threshold the S289 lead resolved into an imperative. What the bands DO carry is
# the prohibition: red says the reminder is not an instruction to hand off,
# imminent says only path (a) initiates one and a threshold is not a request.
# If you are editing these strings, the test is whether a reader with no other
# context would read them as an instruction to the lead. If yes, rewrite.
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
# - stdout: JSON with additionalContext, only on a firing turn. Silent otherwise.
#
# Nothing else is written. The model ceiling is DECLARED per family in the settings
# `env` block (AI_DLC_MODEL_<FAMILY>_WINDOW, see "Model ceiling" below) and never
# learned, proven or cached, so the answer is the same on every fire.
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
# autoCompactWindow resolution reads these settings layers in Claude Code's
# precedence order (highest first). Managed/enterprise settings and CLI-flag
# overrides are not reachable from a hook, so they cannot be modelled here.
SETTINGS_LOCAL="${PROJECT_DIR}/.claude/settings.local.json"
SETTINGS_PROJECT="${PROJECT_DIR}/.claude/settings.json"
SETTINGS_USER="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"

# Claude Code compacts at `effectiveWindow - 13,000` (COMPACT_RESERVE in
# validate-compact-window.sh), but the quantity THIS hook measures sits a further
# ~18,000 below that at fire time: the check adds an output allowance before
# comparing. Measured on two independent windows (287,000-268,892=18,108 and
# 987,000-969,084=17,916). So the ceiling visible to a transcript-derived reading
# is `effectiveWindow - SENSOR_RESERVE`.
SENSOR_RESERVE="${AI_DLC_SENSOR_RESERVE:-31000}"

# The three context bands are a PERCENTAGE of the resolved effective window,
# CLAMPED so the distance below the ceiling (EFFECTIVE - SENSOR_RESERVE) stays
# within absolute bounds. The percentage lets the bands scale with the window; the
# clamp keeps the runway before compaction sane -- a straight percentage would
# fire red ~200 turns early on a 1M window (noise) and too late on a small one.
#
# Each band's threshold is clamp(EFFECTIVE * PCT / 100, ceiling - MAX_LEAD,
# ceiling - MIN_LEAD). MIN_LEAD is the closest the band may sit to the ceiling
# (latest fire); MAX_LEAD the furthest (earliest). The MIN_LEADs are the
# historical 200K offsets, so at small/mid windows every band clamps to exactly
# the old thresholds (200K -> yellow 80000, red 120000, imminent 149000; a 300000
# window -> 180000 / 220000 / 249000) and only goes proportional on large windows,
# where MAX_LEAD caps the runway.
#
# Ordering holds BY CONSTRUCTION: the clamp ranges do not overlap, because
# YELLOW_MIN_LEAD > RED_MAX_LEAD and RED_MIN_LEAD > IMMINENT_MAX_LEAD. So
# T_yellow <= ceiling-YELLOW_MIN_LEAD < ceiling-RED_MAX_LEAD <= T_red, and likewise
# T_red < T_imminent, for ANY window and ANY percentages.
# validate-compact-window.sh guards these constants.
#
# A warning delivered AT the ceiling is worthless (compaction fires on the very
# next request and destroys the injected directive), and the ceiling is usually
# never observed at all -- three real `graph` compactions last measured 268,892 /
# 267,719 / 267,445 against a 269,000 ceiling. So imminent's MIN_LEAD (20,000)
# opens its band ~16 turns early at the measured ~1,200 tokens/turn.
YELLOW_PCT="${AI_DLC_SENSOR_YELLOW_PCT:-60}"
RED_PCT="${AI_DLC_SENSOR_RED_PCT:-75}"
IMMINENT_PCT="${AI_DLC_SENSOR_IMMINENT_PCT:-90}"
YELLOW_MIN_LEAD="${AI_DLC_SENSOR_YELLOW_MIN_LEAD:-89000}"
YELLOW_MAX_LEAD="${AI_DLC_SENSOR_YELLOW_MAX_LEAD:-200000}"
RED_MIN_LEAD="${AI_DLC_SENSOR_RED_MIN_LEAD:-49000}"
RED_MAX_LEAD="${AI_DLC_SENSOR_RED_MAX_LEAD:-88000}"
IMMINENT_MIN_LEAD="${AI_DLC_SENSOR_IMMINENT_MIN_LEAD:-20000}"
IMMINENT_MAX_LEAD="${AI_DLC_SENSOR_IMMINENT_MAX_LEAD:-24000}"

# Recurrence, matching _gate-procedures.md: re-fire the current level after a
# 50,000-token or 20-turn delta.
RECUR_TOKENS="${AI_DLC_SENSOR_RECUR_TOKENS:-50000}"
RECUR_TURNS="${AI_DLC_SENSOR_RECUR_TURNS:-20}"

# A drop this large means the context was compacted or /clear'ed.
RESET_DROP="${AI_DLC_SENSOR_RESET_DROP:-50000}"

# The ceiling assumed for a model family whose window nobody declared. The smallest
# current tier (Haiku's own true maximum) and Claude Code's own fallback for an
# unrecognized model id. Assuming small fires early, which is noisy and non-blocking;
# assuming large puts red past the real compaction point, which is silent.
UNDECLARED_MODEL_MAX=200000

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

# The window file the statusline writes is at a FIXED path, so concurrent sessions
# overwrite each other's. This id is what lets the resolver tell "the live window for
# THIS session" from "some other session's window", and an empty one makes it decline
# the file rather than guess.
SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)"

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

# -----------------------------------------------------------------------------
# Arm record (v0.70.0 D4) -- which model the LEAD actually ran on
#
# No sprint artifact recorded this. The only on-disk evidence was the `model`
# field on each assistant turn of a transcript, which lives outside the repo and
# outside every check -- so "which arm ran" was unfalsifiable from a sprint's own
# artifacts, and the v0.70.0 Sonnet-lead A/B had to be answered by an external
# script reading ~/.claude/projects. An A/B whose independent variable is
# unrecorded is not reproducible.
#
# The lead must NOT self-report this. Asking a model to name its own weights is
# unreliable, and a self-reported arm is exactly the unfalsifiable testimony the
# finding complains about. So the HOOK writes it, from the transcript, as ground
# truth. This sensor is the right home for three reasons it already satisfies:
# it exits above on `agent_id` (so it only ever runs in the MAIN session -- the
# model it reads IS the lead's), it already holds the correct post-compaction
# assistant record in $LINE, and it already gates on an active pipeline.
#
# Append-only, deduped on (sprint, model): one record per arm change, so a
# mid-sprint model switch is captured rather than overwritten. Costs one tail
# read per firing.
#
# Caveat inherited from the model-ceiling note below: `message.model` is
# `claude-opus-4-8` for BOTH the 200K and 1M variant. That is fine for arm
# identity (sonnet vs opus, which is all an A/B needs) and for FAMILY
# classification, and useless for window size -- the ceiling is declared per
# family, never read off this field.
# -----------------------------------------------------------------------------
LEAD_MODEL="$(printf '%s' "$LINE" | jq -r '.message.model // empty' 2>/dev/null || true)"
if [ -n "$LEAD_MODEL" ]; then
  ARM_LOG="${STATE_DIR}/arm-log.jsonl"
  # Decoration is not part of the field -- see the measurement in
  # ai-dlc-dispatch-guard.sh's copy of this read. I104 binds the three.
  ARM_SPRINT="$(sed -n 's/^- *[*]*sprint_id:[*]* *\([0-9][0-9]*\).*/\1/p' "$SNAPSHOT_FILE" 2>/dev/null | head -1)"
  ARM_LAST="$(tail -1 "$ARM_LOG" 2>/dev/null || true)"
  LAST_MODEL="$(printf '%s' "$ARM_LAST" | jq -r '.lead_model // empty' 2>/dev/null || true)"
  LAST_SPRINT="$(printf '%s' "$ARM_LAST" | jq -r '(.sprint // empty) | tostring' 2>/dev/null || true)"
  [ "$LAST_SPRINT" = "null" ] && LAST_SPRINT=""
  if [ "$LEAD_MODEL" != "$LAST_MODEL" ] || [ "${ARM_SPRINT:-}" != "$LAST_SPRINT" ]; then
    mkdir -p "$STATE_DIR" 2>/dev/null || true
    jq -nc --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
           --arg m "$LEAD_MODEL" \
           --arg s "${ARM_SPRINT:-}" \
      '{v:1, ts:$ts, sprint:(if $s=="" then null else ($s|tonumber) end), lead_model:$m}' \
      >> "$ARM_LOG" 2>/dev/null || true
  fi
fi

TOKENS="$(printf '%s' "$LINE" | jq '
  .message.usage
  | (.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0)
' 2>/dev/null || true)"
case "${TOKENS:-}" in ''|*[!0-9]*) exit 0 ;; esac
[ "$TOKENS" -gt 0 ] || exit 0

# -----------------------------------------------------------------------------
# The window library. THE CHAIN IS NOT SPELLED HERE: scripts/ai-dlc/validate-compact-window.sh
# reports the same window this hook ramps against, and the two answers must not
# drift, so both source ai-dlc-window.sh and neither carries a second copy of the
# precedence order. The library is a SIBLING -- it installs to .claude/hooks/ beside
# this file, the way ai-dlc-handoff-pending.sh does for the Stop and recover hooks.
#
# Unreadable library -> WINDOW stays empty, a declared family window cannot be
# parsed, and the undeclared ceiling applies. That is the safe direction: it
# tightens the bands rather than opening them, and the library ships in the same
# copy step as this hook, so its absence means a broken install rather than a
# configuration a consumer chose.
# -----------------------------------------------------------------------------
_AI_DLC_WIN_LIB="$(dirname "${BASH_SOURCE[0]}")/ai-dlc-window.sh"
[ -r "$_AI_DLC_WIN_LIB" ] && . "$_AI_DLC_WIN_LIB"

# -----------------------------------------------------------------------------
# Model ceiling -- DECLARED per family by the operator, never inferred
#
# The transcript records `claude-opus-4-8` for BOTH the 200K and the 1M variant
# -- the `[1m]` suffix is stripped and no context_window_size is recorded
# anywhere. So the ceiling cannot be read off the transcript.
#
# It used to be GUESSED: a single closed 200K|1M row, pinned by one env var or
# proven upward by watching resident tokens cross a 200K model's compact point,
# and cached sticky across sessions. Two measured failures. A single pinned row
# is wrong the moment a session runs a family with a different native window --
# Haiku is 200K where every other current family is 1M. And the proof only ran
# UPWARD: a model with a window BELOW the proof line was never proven, so it
# ramped against whatever ceiling the fallback carried and the sensor was silent
# through the compaction it exists to warn about.
#
# So: classify the lead model by family SUBSTRING of the id the arm record
# already extracted (a version bump never needs a code change; a family with no
# arm lands in OTHER), take that family's declared window from the settings
# `env` block, and where none is declared assume UNDECLARED_MODEL_MAX. Nothing
# is proven, learned or cached. `imminent` stays gated on WINDOW_DECLARED below,
# because an assumed ceiling can be wrong in the silent direction; yellow and
# red fire on the assumption, so an undeclared project is never left un-warned.
# -----------------------------------------------------------------------------
case "$(printf '%s' "$LEAD_MODEL" | tr '[:upper:]' '[:lower:]')" in
  *fable*|*mythos*) MODEL_FAMILY=FABLE  ;;
  *opus*)           MODEL_FAMILY=OPUS   ;;
  *sonnet*)         MODEL_FAMILY=SONNET ;;
  *haiku*)          MODEL_FAMILY=HAIKU  ;;
  *)                MODEL_FAMILY=OTHER  ;;
esac

case "$MODEL_FAMILY" in
  FABLE)  DECLARED_WINDOW="${AI_DLC_MODEL_FABLE_WINDOW:-}"  ;;
  OPUS)   DECLARED_WINDOW="${AI_DLC_MODEL_OPUS_WINDOW:-}"   ;;
  SONNET) DECLARED_WINDOW="${AI_DLC_MODEL_SONNET_WINDOW:-}" ;;
  HAIKU)  DECLARED_WINDOW="${AI_DLC_MODEL_HAIKU_WINDOW:-}"  ;;
  *)      DECLARED_WINDOW="${AI_DLC_MODEL_OTHER_WINDOW:-}"  ;;
esac

# The declared value takes the library's own spellings (`1m`, `400k`, a bare
# integer) so a consumer writes it the way they write autoCompactWindow. An
# unparseable declaration is the same as none: the floor applies and the state
# file says so, rather than a typo silently pinning a ceiling of zero.
MODEL_MAX="$UNDECLARED_MODEL_MAX"
WINDOW_DECLARED=0
if [ -n "$DECLARED_WINDOW" ] && command -v ai_dlc_parse_window >/dev/null 2>&1; then
  if _PARSED_MAX="$(ai_dlc_parse_window "$DECLARED_WINDOW")" && [ "${_PARSED_MAX:-0}" -gt 0 ]; then
    MODEL_MAX="$_PARSED_MAX"
    WINDOW_DECLARED=1
  fi
fi

WINDOW=""
WINDOW_SOURCE="unset (model default)"
_RT_MODEL_MAX=""
if command -v ai_dlc_resolve_window >/dev/null 2>&1; then
  _WR="$(ai_dlc_resolve_window "${SESSION_ID:-}" "$SETTINGS_LOCAL" "$SETTINGS_PROJECT" "$SETTINGS_USER" 2>/dev/null || true)"
  WINDOW="${_WR%%|*}"
  _WR_REST="${_WR#*|}"
  WINDOW_SOURCE="${_WR_REST%%|*}"
  _RT_MODEL_MAX="${_WR_REST#*|}"
fi
case "${WINDOW:-}" in ''|*[!0-9]*) WINDOW="" ;; esac
case "${WINDOW_SOURCE:-}" in '') WINDOW_SOURCE="unset (model default)" ;; esac
case "${_RT_MODEL_MAX:-}" in ''|*[!0-9]*) _RT_MODEL_MAX="" ;; esac

# THE RUNTIME FILE NAMES THE MODEL, so where it answered the ceiling is a fact and not
# a declaration -- it outranks the family lookup exactly as it outranks every lower
# window layer, and it counts as DECLARED for the imminent gate. Overriding MODEL_MAX
# here is what keeps the clamp below correct rather than making it a second branch: on
# a 262144-token model whose family window nobody declared, MODEL_MAX is the assumed
# floor and an unchanged clamp would drag a correct 262144 down to it.
#
# MODEL_FAMILY itself is deliberately NOT rewritten: it names the family this hook
# classified, and `window_source` below is what tells a reader why effective_window
# need not match the family's declaration.
if [ -n "$_RT_MODEL_MAX" ]; then
  MODEL_MAX="$_RT_MODEL_MAX"
  WINDOW_DECLARED=1
fi

EFFECTIVE="$MODEL_MAX"
if [ -n "$WINDOW" ] && [ "$WINDOW" -lt "$MODEL_MAX" ]; then
  EFFECTIVE="$WINDOW"
fi

# -----------------------------------------------------------------------------
# Context bands: a clamped percentage of the resolved effective window (see the
# constant block above). imminent stays gated on WINDOW_DECLARED below -- an
# undeclared EFFECTIVE is an assumption, and an assumption in the large direction
# would push imminent past the real compaction point. yellow/red still fire on the
# assumed floor, so an undeclared project is never left un-warned.
# A band whose threshold is <= 0 (a window near the 100000 floor, where MAX_LEAD
# exceeds the ceiling) is disabled for that reading rather than firing at every
# token count.
# -----------------------------------------------------------------------------
CEILING=$(( EFFECTIVE - SENSOR_RESERVE ))

band() {  # $1 pct  $2 min_lead  $3 max_lead  -> echoes the clamped threshold
  local raw hi lo
  raw=$(( EFFECTIVE * $1 / 100 ))
  hi=$(( CEILING - $2 ))          # closest allowed to the ceiling (latest fire)
  lo=$(( CEILING - $3 ))          # furthest allowed from it   (earliest fire)
  [ "$raw" -gt "$hi" ] && raw="$hi"
  [ "$raw" -lt "$lo" ] && raw="$lo"
  printf '%s' "$raw"
}

T_YELLOW="$(band "$YELLOW_PCT" "$YELLOW_MIN_LEAD" "$YELLOW_MAX_LEAD")"
T_RED="$(band "$RED_PCT" "$RED_MIN_LEAD" "$RED_MAX_LEAD")"
T_IMMINENT="$(band "$IMMINENT_PCT" "$IMMINENT_MIN_LEAD" "$IMMINENT_MAX_LEAD")"

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
if   [ "$WINDOW_DECLARED" -eq 1 ] && [ "$T_IMMINENT" -gt 0 ] && [ "$TOKENS" -ge "$T_IMMINENT" ]; then
  LEVEL=imminent
elif [ "$T_RED" -gt 0 ] && [ "$TOKENS" -ge "$T_RED" ]; then
  LEVEL=red
elif [ "$T_YELLOW" -gt 0 ] && [ "$TOKENS" -ge "$T_YELLOW" ]; then
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
  printf 'model_family=%s\n'     "$MODEL_FAMILY"
  printf 'window_declared=%s\n'  "$WINDOW_DECLARED"
  printf 'effective_window=%s\n' "$EFFECTIVE"
  printf 'window_source=%s\n'    "$WINDOW_SOURCE"
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
  THR="$T_IMMINENT"
  # Turns of headroom at the measured p50 growth rate. Deliberately rounded down.
  TURNS_LEFT="$(awk -v c="$CEILING" -v t="$TOKENS" 'BEGIN{ n=int((c-t)/1200); print (n<1?1:n) }')"
  ADVICE="Auto-compact will fire at ~${CEILING} tokens -- roughly ${TURNS_LEFT} more turns at the observed growth rate. BEFORE your next pipeline action, refresh _bmad-output/pipeline-snapshot.md so it reflects the CURRENT state: Pipeline Position (current step file, in-flight sub-step), Recent Activity, Open Items, and any Locked Decisions taken since the last gate. A snapshot last written at a gate may be hundreds of turns stale, and it is what ai-dlc-recover.sh re-reads after compaction -- a stale snapshot is recovered faithfully and is still wrong. Having refreshed it, CONTINUE. Rule 2: only path (a) initiates a handoff, and path (a) is the operator asking. A threshold is not a request."
elif [ "$LEVEL" = red ]; then
  THR="$T_RED"
  ADVICE="Rule 2(c) is a REMINDER, not an instruction to hand off. Finalize the pipeline snapshot so it is not stale, then CONTINUE."
else
  THR="$T_YELLOW"
  ADVICE="Rule 2(b): finish the current sub-step, then continue."
fi

WINDOW_NOTE=""
[ "$WINDOW_DECLARED" -eq 0 ] && WINDOW_NOTE=" No context window is declared for the ${MODEL_FAMILY} model family, so a ${UNDECLARED_MODEL_MAX}-token ceiling is assumed; set env AI_DLC_MODEL_${MODEL_FAMILY}_WINDOW in .claude/settings.json to declare it."

CONTEXT="[AI/DLC context sensor] Resident context is ~${TOKENS} tokens (~${PCT}% of the ${EFFECTIVE}-token effective window), crossing the $(printf '%s' "$LEVEL" | tr '[:lower:]' '[:upper:]') threshold (${THR}). ${ADVICE} This reminder is non-blocking: the pipeline continues and the decision is the user's. Reconcile the snapshot Context Reminders fields to this reading at the next gate.${WINDOW_NOTE}"

# PROVENANCE MARKER -- PC-S306-UNSOLICITED-CONTEXT-HAS-NO-PROVENANCE-SIGNAL. The
# library is a SIBLING in both layouts (core/hooks/, .claude/hooks/), so this is a
# same-directory read and never a walk up from a resolved path. Fail-open: a hook
# that cannot mark its output still emits it.
_AI_DLC_PROV="$(dirname "${BASH_SOURCE[0]}")/ai-dlc-context-provenance.sh"
if [ -r "$_AI_DLC_PROV" ]; then . "$_AI_DLC_PROV"
else ai_dlc_provenance_wrap() { printf %s "${3:-}"; }; fi
CONTEXT="$(ai_dlc_provenance_wrap ai-dlc-context-sensor "$EVENT" "$CONTEXT")"

jq -n --arg context "$CONTEXT" --arg event "$EVENT" '{
  hookSpecificOutput: {
    hookEventName: $event,
    additionalContext: $context
  }
}'

exit 0
