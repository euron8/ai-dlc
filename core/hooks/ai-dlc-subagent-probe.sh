#!/usr/bin/env bash
#
# AI/DLC Subagent Context Probe  (SubagentStop)
#
# PURE INSTRUMENTATION. Records nothing but facts, blocks nothing, and is the
# only thing in the pipeline that can see inside a teammate.
#
# WHY THIS EXISTS
# The lead is heavily netted around compaction: a snapshot, a precompact sidecar,
# a recovery protocol, a context sensor that warns at yellow/red before the
# threshold. A TEAMMATE has none of it. It runs in its own context window, and
# `ai-dlc-context-sensor.sh` deliberately exits on `agent_id` ("a subagent's usage
# describes its own window, not the lead's"), so nothing warns it and nothing
# recovers it. If a teammate compacts, it silently loses the middle of its own
# task -- the gate-adjudicator loses its worklist, the adversary loses half the
# artifacts it was comparing -- and returns a confident, quietly degraded verdict.
#
# That risk has been argued but never measured, and it is the open question under
# `autoCompactWindow`. Raising the ceiling (400000, say) buys teammates headroom
# before an unprotected compaction — but it costs ~19% on a bill whose cache-read
# term scales linearly with resident context (docs/v0.70.0-sonnet-lead-ab.md §6).
# Paying a certain 19% for an unquantified benefit is a guess. THIS HOOK TURNS IT
# INTO A MEASUREMENT: how close do teammates actually get to the threshold, and
# do any of them compact?
#
# It also settles a question no artifact could answer: teammates leave no
# transcript in ~/.claude/projects, so their context was unobservable from disk.
# SubagentStop hands us `transcript_path` at the one moment the teammate's own
# transcript is complete. That is the only window there is.
#
# EMITS  ${AI_DLC_STATE_DIR:-_bmad-output}/subagent-context.jsonl
#   {v, ts, sprint, agent_id, model, turns, peak_tokens, compactions}
# One line per teammate completion. Append-only. Read it with:
#   jq -s 'max_by(.peak_tokens)'            <- the closest any teammate came
#   jq -s 'map(select(.compactions>0))'     <- teammates that actually compacted
#
# READ peak_tokens AGAINST THE THRESHOLD, NOT THE WINDOW: compaction fires at
# `effectiveWindow - 13000` (287000 at the default 300000 setting). A teammate at
# 250K is already inside the blast radius; one at 100K is not, and no ceiling
# change would help it.
#
# NEVER BLOCKS. SubagentStop can block a subagent from stopping; this hook must
# never do that. Every path is `exit 0` with no stdout.
#
# INSTALL: wired by templates/settings.json.template (SubagentStop); upserted by
#   reconcile/settings-merge.sh on pull.

set -u

command -v jq >/dev/null 2>&1 || exit 0

INPUT="$(cat 2>/dev/null || true)"
[ -n "$INPUT" ] || exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
STATE_DIR="${PROJECT_DIR}/${AI_DLC_STATE_DIR:-_bmad-output}"
SNAPSHOT_FILE="${STATE_DIR}/pipeline-snapshot.md"
OUT="${STATE_DIR}/subagent-context.jsonl"

# Not an AI/DLC pipeline -> stay out of it entirely (same gate as every other hook).
[ -f "$SNAPSHOT_FILE" ] || exit 0

TRANSCRIPT="$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || true)"
[ -n "$TRANSCRIPT" ] && [ -r "$TRANSCRIPT" ] || exit 0

AGENT_ID="$(printf '%s' "$INPUT" | jq -r '.agent_id // empty' 2>/dev/null || true)"
[ -n "$AGENT_ID" ] || AGENT_ID="unknown"

# Bounded reverse tail-read, same discipline as ai-dlc-context-sensor.sh: a
# teammate transcript can be megabytes and a single tool_result line can be huge,
# so escalate the window rather than reading the whole file. Unlike the sensor we
# want the PEAK across the whole run, not the latest reading — a teammate that
# compacted and came back down still spent time at the ceiling, and that peak is
# the number the ceiling decision needs.
PEAK=0; TURNS=0; COMPACTIONS=0; MODEL=""
for N in ${AI_DLC_PROBE_TAIL_BYTES:-1048576} 4194304 16777216; do
  READ="$(tail -c "$N" "$TRANSCRIPT" 2>/dev/null | jq -Rsc '
      (split("\n") | map(fromjson?)) as $a
      | {
          peak: ([ $a[]
                   | select(.type == "assistant" and .message.usage != null)
                   | (.message.usage.input_tokens // 0)
                     + (.message.usage.cache_creation_input_tokens // 0)
                     + (.message.usage.cache_read_input_tokens // 0)
                 ] | max // 0),
          turns: ([ $a[] | select(.type == "assistant") ] | length),
          compactions: ([ $a[]
                          | select(.type == "system" and .subtype == "compact_boundary")
                        ] | length),
          model: ([ $a[] | select(.type == "assistant") | .message.model // empty ] | last // "")
        }
    ' 2>/dev/null)"
  [ -n "$READ" ] || continue
  PEAK="$(printf '%s' "$READ" | jq -r '.peak' 2>/dev/null || echo 0)"
  TURNS="$(printf '%s' "$READ" | jq -r '.turns' 2>/dev/null || echo 0)"
  COMPACTIONS="$(printf '%s' "$READ" | jq -r '.compactions' 2>/dev/null || echo 0)"
  MODEL="$(printf '%s' "$READ" | jq -r '.model' 2>/dev/null || echo "")"
  # A tail that captured no assistant turn means the window was too small for
  # even one record — escalate. Otherwise this reading stands.
  case "${TURNS:-0}" in ''|0) continue ;; esac
  break
done

case "${PEAK:-}" in ''|*[!0-9]*) exit 0 ;; esac
[ "$PEAK" -gt 0 ] || exit 0

SPRINT="$(sed -n 's/^- \*\*sprint_id:\*\* *\([0-9][0-9]*\).*/\1/p' "$SNAPSHOT_FILE" 2>/dev/null | head -1)"

mkdir -p "$STATE_DIR" 2>/dev/null || true
jq -nc --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       --arg s "${SPRINT:-}" \
       --arg a "$AGENT_ID" \
       --arg m "${MODEL:-}" \
       --argjson turns "${TURNS:-0}" \
       --argjson peak "${PEAK:-0}" \
       --argjson comp "${COMPACTIONS:-0}" \
  '{v:1, ts:$ts, sprint:(if $s=="" then null else ($s|tonumber) end),
    agent_id:$a, model:(if $m=="" then null else $m end),
    turns:$turns, peak_tokens:$peak, compactions:$comp}' \
  >> "$OUT" 2>/dev/null || true

exit 0
