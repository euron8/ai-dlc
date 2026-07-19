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
# term scales linearly with resident context (v0.70.0 Sonnet-lead A/B, §6).
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
#   {v, ts, sprint, agent_id, model, role, turns, peak_tokens, compactions, duration_s}
# One line per teammate completion. Append-only. Read it with:
#   jq -s 'max_by(.peak_tokens)'            <- the closest any teammate came
#   jq -s 'map(select(.compactions>0))'     <- teammates that actually compacted
#   jq -s 'map(select(.duration_s>900))'    <- the tail: 10% of runs, ~47% of agent-hours
#   jq -s 'map(select(.duration_s>900 and (.turns/(.duration_s/60))<1))'
#                                           <- long AND barely turning: stalled, not working
# `role` and `duration_s` are null when the transcript's opening records do not
# carry them; a null is "not observed", never "zero".
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
PEAK=0; TURNS=0; COMPACTIONS=0; MODEL=""; END_TS=""
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
          model: ([ $a[] | select(.type == "assistant") | .message.model // empty ] | last // ""),
          end_ts: ([ $a[] | .timestamp // empty ] | last // "")
        }
    ' 2>/dev/null)"
  [ -n "$READ" ] || continue
  PEAK="$(printf '%s' "$READ" | jq -r '.peak' 2>/dev/null || echo 0)"
  TURNS="$(printf '%s' "$READ" | jq -r '.turns' 2>/dev/null || echo 0)"
  COMPACTIONS="$(printf '%s' "$READ" | jq -r '.compactions' 2>/dev/null || echo 0)"
  MODEL="$(printf '%s' "$READ" | jq -r '.model' 2>/dev/null || echo "")"
  END_TS="$(printf '%s' "$READ" | jq -r '.end_ts' 2>/dev/null || echo "")"
  # A tail that captured no assistant turn means the window was too small for
  # even one record — escalate. Otherwise this reading stands.
  case "${TURNS:-0}" in ''|0) continue ;; esac
  break
done

# --- DURATION and ROLE: one bounded HEAD read ------------------------------
# Both answers live in the transcript's opening records — the first timestamp,
# and the Rule 19 role binding carried in the dispatch prompt — so one small
# head read settles both. It is a head and not a full scan for the same reason
# the block above is a bounded tail: this hook runs on EVERY teammate
# completion and must not become the thing it measures.
#
# WHY DURATION. peak_tokens answers "did a teammate approach the ceiling". It
# cannot answer "did a teammate STOP MAKING PROGRESS", and those are different
# failures with different remedies. Measured on the reference consumer's 1,979
# teammate runs: p50 4.1m, p90 15.0m, p99 61.6m, max 699m — and the 699m run
# had 127 turns while a healthy 151m run had 781. Duration alone does not
# separate them; duration WITH turns does (turns-per-minute), which is why both
# fields are emitted and neither is emitted as a verdict. This records the
# fact. Nothing here bounds, kills, or warns — see the header: PURE
# INSTRUMENTATION. A bound argued from one incident is a guess; this is the
# measurement that would justify one.
START_TS=""; ROLE=""
HEAD_READ="$(head -c "${AI_DLC_PROBE_HEAD_BYTES:-262144}" "$TRANSCRIPT" 2>/dev/null)"
if [ -n "$HEAD_READ" ]; then
  START_TS="$(printf '%s' "$HEAD_READ" | jq -Rsc '
      [ (split("\n") | map(fromjson?))[] | .timestamp // empty ] | first // ""
    ' 2>/dev/null | tr -d '"')"
  # Role binding: `.claude/team-roles/<role>.md` as dispatched (Rule 19). Read
  # from the raw text, not a JSON path — the binding is prose inside the prompt.
  ROLE="$(printf '%s' "$HEAD_READ" \
            | grep -oE 'team-roles/[a-z0-9-]+\.md' 2>/dev/null \
            | head -1 | sed 's|team-roles/||; s|\.md$||')"
fi

# Seconds, not milliseconds: the spread being measured runs minutes to hours,
# and sub-second precision on a SubagentStop timestamp would be false precision.
# Fractional seconds are stripped because fromdateiso8601 rejects them.
DURATION=""
if [ -n "$START_TS" ] && [ -n "$END_TS" ]; then
  DURATION="$(jq -nr --arg a "$START_TS" --arg b "$END_TS" '
      def t: sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601;
      (($b | t) - ($a | t)) as $d | if $d >= 0 then $d else empty end
    ' 2>/dev/null || echo "")"
fi
case "${DURATION:-}" in ''|*[!0-9]*) DURATION="" ;; esac

case "${PEAK:-}" in ''|*[!0-9]*) exit 0 ;; esac
[ "$PEAK" -gt 0 ] || exit 0

SPRINT="$(sed -n 's/^- \*\*sprint_id:\*\* *\([0-9][0-9]*\).*/\1/p' "$SNAPSHOT_FILE" 2>/dev/null | head -1)"

mkdir -p "$STATE_DIR" 2>/dev/null || true
jq -nc --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       --arg s "${SPRINT:-}" \
       --arg a "$AGENT_ID" \
       --arg m "${MODEL:-}" \
       --arg r "${ROLE:-}" \
       --arg d "${DURATION:-}" \
       --argjson turns "${TURNS:-0}" \
       --argjson peak "${PEAK:-0}" \
       --argjson comp "${COMPACTIONS:-0}" \
  '{v:1, ts:$ts, sprint:(if $s=="" then null else ($s|tonumber) end),
    agent_id:$a, model:(if $m=="" then null else $m end),
    role:(if $r=="" then null else $r end),
    turns:$turns, peak_tokens:$peak, compactions:$comp,
    duration_s:(if $d=="" then null else ($d|tonumber) end)}' \
  >> "$OUT" 2>/dev/null || true

exit 0
