#!/usr/bin/env bash
# Behavioural tests for .claude/hooks/ai-dlc-context-sensor.sh
#
# The sensor's correctness depends on transcript state, so each case pipes a
# synthetic Stop-hook stdin at a fixture transcript and asserts on stdout plus
# the fire-state sidecar. Runs against a throwaway project dir; touches nothing
# in the real _bmad-output/.
#
#   tests/fixtures/context-sensor/run.sh [path/to/ai-dlc-context-sensor.sh]

set -u

HOOK="${1:-${CLAUDE_PROJECT_DIR:-.}/.claude/hooks/ai-dlc-context-sensor.sh}"
FIXTURES="$(cd "$(dirname "$0")" && pwd)"

if [ ! -x "$HOOK" ]; then
  echo "FAIL: hook not executable: $HOOK" >&2
  exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/_bmad-output" "$WORK/.claude/skills/ai-dlc"
touch "$WORK/_bmad-output/pipeline-snapshot.md"

cat > "$WORK/.claude/skills/ai-dlc/SKILL.md" <<'SKILL'
### Threshold defaults

| Model context window | Yellow (first reminder) | Red (urgent reminder) |
|---|---|---|
| 200K | 80K tokens | 120K tokens |
| 1M   | 120K tokens | 200K tokens |
SKILL

echo '{"autoCompactWindow":300000}' > "$WORK/.claude/settings.json"

STATE="$WORK/_bmad-output/.context-sensor-state"
MODEL="$WORK/_bmad-output/.context-sensor-model"

# Synthesized rather than committed: this fixture only needs to be larger than
# the sensor's 256KB default tail window, and a 400KB blob does not belong in git.
GIANT="$WORK/giant-tool-result.jsonl"
head -1 "$FIXTURES/at-yellow.jsonl" > "$GIANT"
{ printf '{"type":"user","toolUseResult":"'; head -c 400000 /dev/zero | tr '\0' 'x'; printf '"}\n'; } >> "$GIANT"

PASS=0
FAIL=0

reset()  { rm -f "$STATE" "$MODEL"; }
fire()   { printf '{"transcript_path":"%s","session_id":"t"%s}' "$FIXTURES/$1" "${2:-}" \
             | CLAUDE_PROJECT_DIR="$WORK" "$HOOK" 2>/dev/null; }
ctx()    { jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null; }
field()  { sed -n "s/^$1=//p" "$STATE" 2>/dev/null | head -1; }

ok()   { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL  %s -- %s\n' "$1" "$2"; }
check(){ [ "$2" = "$3" ] && ok "$1" || bad "$1" "expected '$3', got '$2'"; }

echo "context-sensor fixtures"

# --- silence cases -----------------------------------------------------------
reset
check "below yellow is silent" "$(fire below-yellow.jsonl | ctx)" ""
check "  and records the reading" "$(field last_measured)" "50000"

reset
check "no usage in transcript is silent" "$(fire no-usage.jsonl | ctx)" ""

reset
check "subagent (agent_id) is silent" "$(fire at-red.jsonl ',"agent_id":"a1"' | ctx)" ""

# --- firing and idempotence --------------------------------------------------
reset
OUT="$(fire at-yellow.jsonl | ctx)"
case "$OUT" in *"YELLOW threshold (80000)"*) ok "yellow fires at 90000" ;;
  *) bad "yellow fires at 90000" "got: ${OUT:-<silent>}" ;; esac

OUT="$(fire at-yellow.jsonl | ctx)"
check "yellow does not re-fire next turn" "$OUT" ""

OUT="$(fire at-red.jsonl | ctx)"
case "$OUT" in *"RED threshold (120000)"*) ok "red escalates from yellow" ;;
  *) bad "red escalates from yellow" "got: ${OUT:-<silent>}" ;; esac

# --- self-healing reset on a compaction-sized drop ---------------------------
OUT="$(fire post-compact-drop.jsonl | ctx)"
check "post-compact drop is silent" "$OUT" ""
check "  and resets fire state" "$(field last_level)" "none"

# --- transcript-shape robustness ---------------------------------------------
reset
fire sidechain-tail.jsonl >/dev/null
check "sidechain lines are skipped" "$(field last_measured)" "90000"

reset
printf '{"transcript_path":"%s","session_id":"t"}' "$GIANT" \
  | CLAUDE_PROJECT_DIR="$WORK" "$HOOK" >/dev/null 2>&1
check "tail ladder survives a 400KB tool_result" "$(field last_measured)" "90000"

# --- model row inference ------------------------------------------------------
reset
fire proves-1m.jsonl >/dev/null
check "a 250000 reading proves the 1M row" "$(field model_row)" "1M"
check "  and the proof is cached" "$(sed -n 's/^row=//p' "$MODEL" 2>/dev/null | head -1)" "1M"

reset
OUT="$(fire assumed-ceiling.jsonl | ctx)"
check "assumed row does not claim imminence" \
  "$(printf '%s' "$OUT" | grep -c 'imminent' | tr -d ' ')" "0"
check "  and stays row_known=0" "$(field row_known)" "0"

reset
OUT="$(printf '{"transcript_path":"%s","session_id":"t"}' "$FIXTURES/at-red.jsonl" \
        | AI_DLC_MODEL_ROW=1M CLAUDE_PROJECT_DIR="$WORK" "$HOOK" 2>/dev/null | ctx)"
check "AI_DLC_MODEL_ROW pins the row" "$(field model_row)" "1M"
check "  130000 is only yellow on the 1M row" \
  "$(printf '%s' "$OUT" | grep -c 'YELLOW' | tr -d ' ')" "1"

# --- compact_imminent backstop ------------------------------------------------
reset
printf 'row=1M\n' > "$MODEL"
printf '{"type":"assistant","isSidechain":false,"message":{"model":"claude-opus-4-8","usage":{"input_tokens":2,"cache_creation_input_tokens":0,"cache_read_input_tokens":269998}}}\n' \
  > "$WORK/imminent.jsonl"
OUT="$(printf '{"transcript_path":"%s","session_id":"t"}' "$WORK/imminent.jsonl" \
        | CLAUDE_PROJECT_DIR="$WORK" "$HOOK" 2>/dev/null | ctx)"
case "$OUT" in *"auto-compact is imminent"*) ok "imminent backstop fires at effectiveWindow-31000" ;;
  *) bad "imminent backstop fires at effectiveWindow-31000" "got: ${OUT:-<silent>}" ;; esac

# --- recurrence ---------------------------------------------------------------
reset
printf 'row=1M\n' > "$MODEL"
FIRES=0
i=0
while [ "$i" -lt 25 ]; do
  i=$((i+1))
  [ -n "$(fire at-red.jsonl | ctx)" ] && FIRES=$((FIRES+1))
done
check "flat context fires twice in 25 turns (initial + 20-turn recurrence)" "$FIRES" "2"

echo
echo "  $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
