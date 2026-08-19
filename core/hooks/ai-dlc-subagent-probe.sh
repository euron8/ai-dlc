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
#   jq -s 'map(select(.duration_s>900))'    <- the long tail
#   jq -s 'map(select(.duration_s>900 and (.turns/(.duration_s/60))<1))'
#                                           <- long AND barely turning: stalled, not working
# `role` is null when the transcript's opening records do not carry it, and
# `duration_s` is null when no dispatch row matched; a null is "not observed",
# never "zero".
#
# NO SHARE-OF-RUNS FIGURE IS QUOTED HERE, AND THAT IS DELIBERATE. This comment
# used to say the >900s bucket was "10% of runs, ~47% of agent-hours". The
# reference consumer's file said 94.3% of runs and 99.9% of agent-seconds, and
# had said so for every day it holds -- the earliest day in the corpus already
# read 100%. The figure was not stale, it was unreproducible from any point in
# the record, and it read as confirmation for a month while the field beneath it
# emitted session age. A distribution quoted in a comment is a claim about data
# that moves; derive it when you need it and do not carry one here.
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
  # NO `|| echo 0` FALLBACK ON ANY OF THESE FIVE, AND THE OMISSION IS THE POINT.
  # `jq` exits non-zero on malformed input, so a fallback fires on exactly the case
  # it cannot distinguish: a genuine `0` and a read that FAILED become the identical
  # string, and every reader downstream sees a number where there was an absence.
  # This is the same conflation `BL-036` was closed for, and the fix it shipped is
  # the one copied here -- subtractive. An empty value is already handled: the
  # `TURNS` guard three lines down treats it as "window too small, keep looking",
  # and the `PEAK` guard before the emit exits without writing a row at all. A
  # missing record is a gap someone can see; a fabricated zero is a wrong number
  # that sums into every total taken over this file.
  PEAK="$(printf '%s' "$READ" | jq -r '.peak' 2>/dev/null)"
  TURNS="$(printf '%s' "$READ" | jq -r '.turns' 2>/dev/null)"
  COMPACTIONS="$(printf '%s' "$READ" | jq -r '.compactions' 2>/dev/null)"
  MODEL="$(printf '%s' "$READ" | jq -r '.model' 2>/dev/null)"
  END_TS="$(printf '%s' "$READ" | jq -r '.end_ts' 2>/dev/null)"
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
# failures with different remedies. A long run with few turns is stalled; a long
# run with many turns is working. Duration alone does not separate them; duration
# WITH turns does (turns-per-minute), which is why both
# fields are emitted and neither is emitted as a verdict. This records the
# fact. Nothing here bounds, kills, or warns — see the header: PURE
# INSTRUMENTATION. A bound argued from one incident is a guess; this is the
# measurement that would justify one.
START_TS=""; ROLE=""
HEAD_READ="$(head -c "${AI_DLC_PROBE_HEAD_BYTES:-262144}" "$TRANSCRIPT" 2>/dev/null)"
if [ -n "$HEAD_READ" ]; then
  # NO `START_TS` IS TAKEN FROM THIS WINDOW, AND THAT IS THE FIX -- see the
  # dispatch-instant block below for the measurement. The head read stays because
  # `ROLE`'s fallback still needs it; the START it used to yield was the SESSION's
  # first record, which is not this teammate's start and never was.
  # Role binding: `.claude/team-roles/<role>.md` as dispatched (Rule 19).
  #
  # SCOPED TO THE DISPATCH PROMPT — the first `type:"user"` record — and NOT to
  # the whole head window. Reading the window and taking `head -1` is what this
  # field used to do, and it did not measure the dispatched role: the window also
  # holds injected core prose naming `team-roles/adversary.md` (SKILL.md:164
  # among others), so the FIRST match was usually that mention rather than the
  # binding. Measured over the reference consumer's 997 rows: 478 `adversary`,
  # 412 null, 94 `remediator`, 8 `code-reviewer`, 5 `qa` — and ZERO
  # protected-path-editor, dev, analyst, pm, tea, ux, sm or gate-adjudicator,
  # despite documented spawns of every one. Row 991 is a `protected-path-editor`
  # spawn recorded as `adversary`; row 581 a `gate-adjudicator`, likewise. The
  # field was measuring our own documentation, and Check 22 had no other machine
  # record to compare a spawn table against.
  #
  # The binding is still read as PROSE (it is prose, inside the prompt), but only
  # from the record the lead authored, so injected context cannot win.
  ROLE="$(printf '%s' "$HEAD_READ" | jq -Rsc '
      [ (split("\n") | map(fromjson?))[]
        | select(.type == "user")
        | (.message.content // .content // empty)
        | if type == "array" then (map(.text? // "") | join(" ")) else tostring end
      ] | first // ""
    ' 2>/dev/null \
            | grep -oE 'team-roles/[a-z0-9-]+\.md' 2>/dev/null \
            | head -1 | sed 's|team-roles/||; s|\.md$||')"
fi

# AUTHORITATIVE OVERRIDE: the dispatch-time row, if the guard wrote one.
#
# Scoping the prose read to the first user record (above) removes the worst of the
# pollution but cannot remove all of it: injected `<system-reminder>` context can
# arrive INSIDE that same record, ahead of the lead's own text, and it carries the
# same core prose. Any transcript-derived answer is a guess about what was
# dispatched. `spawn-ledger.jsonl` is not a guess — `ai-dlc-dispatch-guard.sh`
# writes it at PreToolUse from the actual tool input, before the teammate runs,
# and it is the role the guard BOUND. Prefer it; keep the prose read as the
# fallback for teammates dispatched before the ledger existed.
#
# JOIN. The probe sees `agent_id` (`appe-hb-s298-1-disposition-db3a97…`), the
# ledger sees the dispatch `name` (`ppe-hb-s298-1-disposition`), and the id embeds
# the name. Match on containment and take the LONGEST matching name, so a short
# generic name (`dev`) cannot outrank a specific one that also matches.
SPAWN_LEDGER="${STATE_DIR}/spawn-ledger.jsonl"
if [ -n "${AGENT_ID:-}" ] && [ "${AGENT_ID}" != "unknown" ] && [ -r "$SPAWN_LEDGER" ]; then
  LEDGER_ROLE="$(jq -rs --arg id "$AGENT_ID" '
      [ .[]
        | select(type == "object")
        | select((.name // "") != "")
        | select(.role != null)
        | select(.name as $n | $id | contains($n))
      ]
      | sort_by(.name | length) | last | .role // empty
    ' "$SPAWN_LEDGER" 2>/dev/null || true)"
  [ -n "${LEDGER_ROLE:-}" ] && ROLE="$LEDGER_ROLE"

  # AND THE DISPATCH INSTANT, FROM THE SAME ROW, FOR THE SAME REASON.
  #
  # `START_TS` above is the first timestamp in the head of `$TRANSCRIPT`. At
  # SubagentStop `.transcript_path` is the LEAD's transcript, so that timestamp is
  # the SESSION's first record -- one constant shared by every teammate the session
  # ever dispatches. `duration_s` was therefore SESSION AGE, not teammate runtime.
  #
  # Measured on the reference consumer, one sprint, 145 rows carrying the field:
  # the implied starts (`ts - duration_s`) collapse onto THREE values, and those
  # three are the sprint's three harness sessions -- 59 rows on the first, 4 on the
  # second, 82 on the third, with 48 sharing a single minute. The control is that
  # the `ts` values themselves scatter across 118 distinct minutes over the same
  # 145 rows, so the collapse is in the derived start and not in the sampling.
  # Corpus-wide the field summed to 16,808 agent-hours across a 743-hour window --
  # 22.6 teammates running without pause for the whole month, against a measured
  # peak concurrency of five to eleven for minutes at a time.
  #
  # The ledger row is the fix because it is the one record written BEFORE the
  # teammate runs, from the actual tool input, by the guard -- the same reason the
  # block above prefers it for `role`. Its `ts` IS the dispatch instant.
  #
  # A teammate with no ledger row gets NO duration rather than the old value: a
  # session-age number is a wrong answer that reads as a real one, and this field
  # exists to be summed. `null` is already the field's declared absent form.
  LEDGER_TS="$(jq -rs --arg id "$AGENT_ID" '
      [ .[]
        | select(type == "object")
        | select((.name // "") != "")
        | select((.ts // "") != "")
        | select(.name as $n | $id | contains($n))
      ]
      | sort_by(.name | length) | last | .ts // empty
    ' "$SPAWN_LEDGER" 2>/dev/null || true)"
  START_TS="${LEDGER_TS:-}"
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
