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

# HERMETIC — scrub the operator's tuning before invoking any hook.
#
# A fixture that INHERITS ambient config tests the config, not the code. The hooks honour
# thirteen AI_DLC_* tunables; a consumer that sets any of them in settings.json exports it
# into every session, `git push` inherits it, and the pre-push gate then runs this fixture
# against a hook configured differently from what the assertions assume.
#
# Observed live: a consumer pinned AI_DLC_MODEL_ROW=1M (the documented, sanctioned way to
# declare the model row). Its effective window became 300000 instead of 200000, every
# threshold shifted, and SEVEN assertions failed against a sensor that was behaving exactly
# as specified. The gate blocked every push on the repo. The distribution never caught it
# because the distribution sets none of these -- the check could not fire where it was
# authored.
#
# Unset ALL of them, by pattern, so a NEW tunable cannot reintroduce this. Per-command
# assignments (`AI_DLC_MODEL_ROW=1M "$HOOK"`) still work: those are the deliberate tests.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

# Same class, different prefix. v0.77.0 makes CLAUDE_CODE_AUTO_COMPACT_WINDOW supersede EVERY
# settings layer, so an ambient export of it silently overrides the sandboxed local/user
# layers the settings-precedence cases below build -- and the AI_DLC_* pattern above does not
# match it. Observed live: a consumer's shell had CLAUDE_CODE_AUTO_COMPACT_WINDOW=300000
# exported; the "settings.local.json overrides project" (expects 250000) and "user settings
# used" (expects 420000) cases both read 300000 and false-failed. The env-supersedes cases
# set it per-command (`CLAUDE_CODE_AUTO_COMPACT_WINDOW=200k "$HOOK"`), so they are unaffected.
unset CLAUDE_CODE_AUTO_COMPACT_WINDOW


FIXTURES="$(cd "$(dirname "$0")" && pwd)"

# Resolve the hook from an explicit argument, then the CONSUMER layout, then the
# DISTRIBUTION layout. The third candidate is why this exists: the fixture only ever
# looked for `.claude/hooks/`, which does not exist upstream, so it could not run in
# the distribution at all -- and the distribution had no CI to notice. A self-test
# that cannot execute where it lives is the same defect this release is about.
HOOK="${1:-}"
if [ -z "$HOOK" ]; then
  for cand in \
    "${CLAUDE_PROJECT_DIR:-.}/.claude/hooks/ai-dlc-context-sensor.sh" \
    "$FIXTURES/../../hooks/ai-dlc-context-sensor.sh" \
    "$FIXTURES/../../core/hooks/ai-dlc-context-sensor.sh"; do
    [ -f "$cand" ] && HOOK="$cand" && break
  done
fi

if [ ! -f "$HOOK" ]; then
  echo "FAIL: cannot locate ai-dlc-context-sensor.sh (tried consumer and distribution layouts)" >&2
  exit 1
fi
[ -x "$HOOK" ] || HOOK="bash $HOOK"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/_bmad-output" "$WORK/.claude/skills/ai-dlc" "$WORK/home"
touch "$WORK/_bmad-output/pipeline-snapshot.md"

# HERMETIC user-settings layer. resolve_window() reads
# ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json as the lowest layer; point it
# at the sandbox so a case with no project/local window never reads the real
# ~/.claude/settings.json (which would make the assertions depend on the machine).
export CLAUDE_CONFIG_DIR="$WORK/home"

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
at()     { # $1 = tokens -> writes a one-line transcript, returns its path
  printf '{"type":"assistant","isSidechain":false,"message":{"model":"claude-opus-4-8","usage":{"input_tokens":2,"cache_creation_input_tokens":0,"cache_read_input_tokens":%s}}}\n' \
    "$(( $1 - 2 ))" > "$WORK/at.jsonl"
  printf '%s' "$WORK/at.jsonl"
}
raw()    { printf '{"transcript_path":"%s","session_id":"t"}' "$1" | CLAUDE_PROJECT_DIR="$WORK" "$HOOK" 2>/dev/null; }

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

# --- no band offers a handoff (v0.136.1) -------------------------------------
# The hook's header invariant is that no ADVICE string reads as an instruction to
# the lead. v0.45.3 removed the imperative and left an OFFER ("say so in one line
# and let the operator decide"); v0.136.1 removed the offer too, because SKILL.md
# Rule 2(b)/(c)/(d) already owns what the lead says to the operator and a second
# copy beside a threshold is the permission the S289 lead read as an imperative.
#
# PAIRED, not a bare absence check. On its own, "the output does not contain X"
# passes vacuously against a hook that emits nothing at all -- the same
# check-that-cannot-fire shape the suite exists to catch. The positive half
# asserts the prohibition the band MUST still carry, so a silenced or gutted
# ADVICE string fails here before the absence half can pass for the wrong reason.
case "$OUT" in *"not an instruction to hand off"*) ok "red keeps the prohibition" ;;
  *) bad "red keeps the prohibition" "got: ${OUT:-<silent>}" ;; esac
case "$OUT" in *"let the operator decide"*|*"say so in one line"*)
    bad "red does not ask the lead to offer a handoff" "advice re-offers the handoff" ;;
  *) ok "red does not ask the lead to offer a handoff" ;; esac

# --- self-healing reset on a compaction-sized drop ---------------------------
OUT="$(fire post-compact-drop.jsonl | ctx)"
check "post-compact drop is silent" "$OUT" ""
check "  and resets fire state" "$(field last_level)" "none"

# --- post-compaction boundary guard ------------------------------------------
# The last PRE-compaction assistant line still carries the old, large usage. On
# the first PostToolBatch after an auto-compact it is the newest line on disk --
# the post-compaction turn has not flushed -- so an unguarded tail-read reports
# the pre-compaction window (~preTokens) and fires a false IMMINENT one request
# after compaction reclaimed the space (graph consumer: 265,909 vs a real
# 80,851). The sensor must ignore any reading that precedes the most recent
# compact_boundary. Row pinned to 1M so an unguarded 260000 would fire IMMINENT.
reset; printf 'row=1M\n' > "$MODEL"
check "pre-boundary-only transcript is silent" "$(fire post-compact-stale.jsonl | ctx)" ""
check "  and records no stale reading" "$(field last_measured)" ""

reset; printf 'row=1M\n' > "$MODEL"
fire post-compact-reattached.jsonl >/dev/null
check "reads the post-boundary turn, not the pre-boundary one" "$(field last_measured)" "80000"

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
OUT="$(printf '{"transcript_path":"%s","session_id":"t"}' "$(at 185000)" \
        | AI_DLC_MODEL_ROW=1M CLAUDE_PROJECT_DIR="$WORK" "$HOOK" 2>/dev/null | ctx)"
check "AI_DLC_MODEL_ROW pins the row" "$(field model_row)" "1M"
check "  185000 is yellow on the 1M row (300000 window -> yellow 180000)" \
  "$(printf '%s' "$OUT" | grep -c 'YELLOW' | tr -d ' ')" "1"

# --- compact_imminent band ----------------------------------------------------
# window 300000 -> ceiling 269000 -> critical band opens at 249000 (imminent
# clamps to its 20000 min-lead here). A warning AT the ceiling is useless: all
# three real graph compactions last measured 268,892 / 267,719 / 267,445, i.e.
# BELOW 269000, because compaction preempts the next turn. The band must open
# with turns to spare. (at()/raw() are defined near the top helpers.)

reset; printf 'row=1M\n' > "$MODEL"
OUT="$(raw "$(at 249001)" | ctx)"
case "$OUT" in *"Auto-compact will fire"*) ok "imminent opens at ceiling-20000 (249001)" ;;
  *) bad "imminent opens at ceiling-20000 (249001)" "got: ${OUT:-<silent>}" ;; esac
case "$OUT" in *"refresh _bmad-output/pipeline-snapshot.md"*) ok "  and directs a snapshot refresh" ;;
  *) bad "  and directs a snapshot refresh" "no refresh directive" ;; esac
check "  level recorded as imminent" "$(field last_level)" "imminent"

reset; printf 'row=1M\n' > "$MODEL"
OUT="$(raw "$(at 248999)" | ctx)"
case "$OUT" in *"RED threshold"*) ok "just below the band is red, not imminent" ;;
  *) bad "just below the band is red, not imminent" "got: ${OUT:-<silent>}" ;; esac

# The real ordering hazard: red already fired, then the band opens well inside
# red's 50K/20-turn recurrence window. imminent must escalate immediately.
reset; printf 'row=1M\n' > "$MODEL"
raw "$(at 225000)" >/dev/null                       # red fires (300000 window -> red 220000)
check "  red fired first" "$(field last_level)" "red"
OUT="$(raw "$(at 250000)" | ctx)"                   # +25K, only 1 turn later
case "$OUT" in *"Auto-compact will fire"*) ok "imminent escalates from red inside the recurrence window" ;;
  *) bad "imminent escalates from red inside the recurrence window" "got: ${OUT:-<silent>}" ;; esac

# Imminent's half of the v0.136.1 invariant above. Same pairing, same reason: the
# positive assertion is what keeps the absence assertion falsifiable.
case "$OUT" in *"A threshold is not a request"*) ok "imminent keeps the prohibition" ;;
  *) bad "imminent keeps the prohibition" "got: ${OUT:-<silent>}" ;; esac
case "$OUT" in *"SURFACE that trade-off"*|*"let THEM call it"*)
    bad "imminent does not ask the lead to offer a handoff" "advice re-offers the handoff" ;;
  *) ok "imminent does not ask the lead to offer a handoff" ;; esac

# The band must still be reachable at the values real compactions were observed at.
reset; printf 'row=1M\n' > "$MODEL"
OUT="$(raw "$(at 267445)" | ctx)"                   # lowest real graph preTokens
case "$OUT" in *"Auto-compact will fire"*) ok "band covers the lowest real observed compaction (267445)" ;;
  *) bad "band covers the lowest real observed compaction (267445)" "got: ${OUT:-<silent>}" ;; esac

reset; printf 'row=1M\n' > "$MODEL"
OUT="$(raw "$(at 175000)" | ctx)"
case "$OUT" in *"Auto-compact will fire"*) bad "assumed-safe reading must not claim imminence" "fired at 175000" ;;
  *) ok "a mid-session reading does not claim imminence" ;; esac

# --- recurrence ---------------------------------------------------------------
reset
printf 'row=1M\n' > "$MODEL"
FIRES=0
i=0
FLAT="$(at 185000)"                                 # yellow at the 300000 window
while [ "$i" -lt 25 ]; do
  i=$((i+1))
  [ -n "$(raw "$FLAT" | ctx)" ] && FIRES=$((FIRES+1))
done
check "flat context fires twice in 25 turns (initial + 20-turn recurrence)" "$FIRES" "2"

# --- window resolution across settings layers (Change A) ----------------------
# effective_window (recorded in .context-sensor-state) = min(resolved
# autoCompactWindow, model max); on a 1M row the max is 1000000, so it echoes the
# resolved window. Each case proves a layer the pre-change sensor could not see:
# it read only the project settings.json, so local/user cases would report 300000.
reset; printf 'row=1M\n' > "$MODEL"
echo '{"autoCompactWindow":250000}' > "$WORK/.claude/settings.local.json"    # project is 300000
raw "$(at 100000)" >/dev/null
check "settings.local.json overrides project settings.json" "$(field effective_window)" "250000"
rm -f "$WORK/.claude/settings.local.json"

reset; printf 'row=1M\n' > "$MODEL"
mv "$WORK/.claude/settings.json" "$WORK/.claude/settings.json.bak"           # drop project layer
echo '{"autoCompactWindow":420000}' > "$WORK/home/settings.json"             # user layer ($CLAUDE_CONFIG_DIR)
raw "$(at 100000)" >/dev/null
check "user settings used when no project/local layer sets the key" "$(field effective_window)" "420000"
mv "$WORK/.claude/settings.json.bak" "$WORK/.claude/settings.json"
rm -f "$WORK/home/settings.json"

reset; printf 'row=1M\n' > "$MODEL"
printf '{"transcript_path":"%s","session_id":"t"}' "$(at 100000)" \
  | CLAUDE_CODE_AUTO_COMPACT_WINDOW=200k CLAUDE_PROJECT_DIR="$WORK" "$HOOK" >/dev/null 2>&1
check "env CLAUDE_CODE_AUTO_COMPACT_WINDOW supersedes settings files" "$(field effective_window)" "200000"

# --- bands track the resolved window (Change B) -------------------------------
# The SAME reading changes level as the window changes, because the bands are a
# clamped percentage of the effective window: at a 300000 window red is 220000,
# but at 500000 the bands move up and 225000 no longer even reaches yellow
# (300000). The pre-change sensor read red off the 1M table (200000) regardless
# of the window, so 225000 fired red at BOTH -- this silent-at-500000 case is what
# it could not produce.
reset; printf 'row=1M\n' > "$MODEL"
OUT="$(printf '{"transcript_path":"%s","session_id":"t"}' "$(at 225000)" \
  | CLAUDE_CODE_AUTO_COMPACT_WINDOW=300000 CLAUDE_PROJECT_DIR="$WORK" "$HOOK" 2>/dev/null | ctx)"
check "225000 is RED at a 300000 window" "$(printf '%s' "$OUT" | grep -c 'RED threshold' | tr -d ' ')" "1"

reset; printf 'row=1M\n' > "$MODEL"
OUT="$(printf '{"transcript_path":"%s","session_id":"t"}' "$(at 225000)" \
  | CLAUDE_CODE_AUTO_COMPACT_WINDOW=500000 CLAUDE_PROJECT_DIR="$WORK" "$HOOK" 2>/dev/null | ctx)"
check "the same 225000 is silent at a 500000 window (bands moved up)" "${OUT:-EMPTY}" "EMPTY"

# --- PostToolBatch event + throttle ------------------------------------------
# The sensor is wired to Stop AND PostToolBatch so it samples during turn-less
# autonomous runs (a real graph session climbed 77K->270K across 169 tool_use
# messages with zero Stop boundaries). These pin the event echo and the throttle.

evfire() { # $1 fixture, $2 hook_event_name -> run as that event
  printf '{"transcript_path":"%s","session_id":"t","hook_event_name":"%s"}' "$FIXTURES/$1" "$2" \
    | CLAUDE_PROJECT_DIR="$WORK" "$HOOK" 2>/dev/null
}
evfield() { sed -n "s/^$1=//p" "$STATE" 2>/dev/null | head -1; }

reset
OUT="$(evfire at-yellow.jsonl PostToolBatch)"
check "PostToolBatch echoes its own hookEventName" \
  "$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.hookEventName' 2>/dev/null)" "PostToolBatch"
case "$(printf '%s' "$OUT" | ctx)" in *"YELLOW threshold"*) ok "  and fires the reminder" ;;
  *) bad "  and fires the reminder" "silent" ;; esac

reset
OUT="$(evfire at-yellow.jsonl Stop)"
check "Stop still echoes Stop" \
  "$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.hookEventName' 2>/dev/null)" "Stop"

# Throttle: a small fixture (170 bytes) never advances 512KB, so a second
# PostToolBatch within the window is skipped -- but Stop always reads.
reset
evfire at-yellow.jsonl PostToolBatch >/dev/null            # first read: not throttled, records last_read_size
SIZE1="$(evfield last_read_size)"
[ -n "$SIZE1" ] && ok "PostToolBatch records last_read_size" || bad "PostToolBatch records last_read_size" "absent"
# second PostToolBatch on the SAME tiny fixture: below throttle delta -> skipped,
# so last_measured must NOT change even if we point at a bigger reading.
BEFORE="$(evfield last_measured)"
evfire at-red.jsonl PostToolBatch >/dev/null                # different file, but same tiny size class
AFTER="$(evfield last_measured)"
check "  second PostToolBatch within throttle window is skipped" "$AFTER" "$BEFORE"
# a Stop is never throttled: it reads even within the window.
evfire at-red.jsonl Stop >/dev/null
check "  Stop is never throttled (reads through the window)" "$(evfield last_measured)" "130000"

# First PostToolBatch of a session (no sidecar) is never throttled.
reset
evfire below-yellow.jsonl PostToolBatch >/dev/null
check "first PostToolBatch of a session always samples" "$(evfield last_measured)" "50000"

# --- arm record (v0.70.0 D4) -------------------------------------------------
# The lead's model must be recorded from the TRANSCRIPT, never self-reported.
ARM="$WORK/_bmad-output/arm-log.jsonl"
armreset() { reset; rm -f "$ARM"; }
armfield() { tail -1 "$ARM" 2>/dev/null | jq -r "$1 // empty" 2>/dev/null; }

armreset
fire below-yellow.jsonl >/dev/null
check "arm recorded from the transcript's model field" "$(armfield .lead_model)" "claude-opus-4-8"
check "  arm record is schema-stamped" "$(armfield .v)" "1"

# Deduped: a second identical reading must not append. An arm log that grows one
# record per tool batch is unreadable and would bury a real arm change.
fire below-yellow.jsonl >/dev/null
fire at-yellow.jsonl >/dev/null
check "  same arm + same sprint does not re-append" "$(wc -l < "$ARM" | tr -d ' ')" "1"

# A sprint change appends, so an arm is attributable per sprint.
printf -- '- **sprint_id:** 292\n' > "$WORK/_bmad-output/pipeline-snapshot.md"
fire at-yellow.jsonl >/dev/null
check "  a new sprint appends a fresh arm record" "$(wc -l < "$ARM" | tr -d ' ')" "2"
check "  and carries the sprint id" "$(armfield .sprint)" "292"
: > "$WORK/_bmad-output/pipeline-snapshot.md"

# The arm is the LEAD's. A subagent must never write one -- it would attribute a
# teammate's model to the lead and invert the arm.
armreset
fire at-red.jsonl ',"agent_id":"a1"' >/dev/null
check "  a subagent writes no arm record" "$([ -f "$ARM" ] && echo present || echo absent)" "absent"

# No pipeline -> no arm record (same gate as the rest of the sensor).
armreset
mv "$WORK/_bmad-output/pipeline-snapshot.md" "$WORK/snap.bak"
fire at-yellow.jsonl >/dev/null
check "  no active pipeline writes no arm record" "$([ -f "$ARM" ] && echo present || echo absent)" "absent"
mv "$WORK/snap.bak" "$WORK/_bmad-output/pipeline-snapshot.md"

echo
echo "  $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
