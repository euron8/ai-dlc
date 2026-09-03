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

# HERMETIC runtime-window layer, and this one is WORSE than the settings layers above.
# The window file defaults to $HOME/.ai-dlc/window.json, which is PRESENT on the machine
# running this suite and is rewritten every few seconds by whichever live session renders
# a statusline. Left unpinned, the arms below would resolve against the operator's own
# session -- passing or failing on what that session happened to be doing, and doing it
# differently on every run. Point it at a path inside the sandbox that does not exist, so
# the layer declines by default; the runtime cases create it deliberately.
#
# The AI_DLC_* scrub above unsets any ambient value, and per-command assignments still
# work, so this export is the only thing standing between the arms and the real file.
export AI_DLC_WINDOW_FILE="$WORK/window.json"

cat > "$WORK/.claude/skills/ai-dlc/SKILL.md" <<'SKILL'
### Threshold defaults

| Model context window | Yellow (first reminder) | Red (urgent reminder) |
|---|---|---|
| 200K | 80K tokens | 120K tokens |
| 1M   | 120K tokens | 200K tokens |
SKILL

echo '{"autoCompactWindow":300000}' > "$WORK/.claude/settings.json"

STATE="$WORK/_bmad-output/.context-sensor-state"

# Synthesized rather than committed: this fixture only needs to be larger than
# the sensor's 256KB default tail window, and a 400KB blob does not belong in git.
GIANT="$WORK/giant-tool-result.jsonl"
head -1 "$FIXTURES/at-yellow.jsonl" > "$GIANT"
{ printf '{"type":"user","toolUseResult":"'; head -c 400000 /dev/zero | tr '\0' 'x'; printf '"}\n'; } >> "$GIANT"

PASS=0
FAIL=0

# Every case starts from a clean sidecar AND an explicit ceiling. The committed transcripts
# and the at() helper record the model as claude-opus-4-8, so `reset1m` declares the OPUS
# family at 1M -- the role a cached `row=1M` seed played before the sensor stopped caching
# -- and `reset` leaves every family undeclared, which is the 200000 floor. The sensor
# never writes a model file any more; a case that needs a ceiling declares one.
reset()   { unset AI_DLC_MODEL_OPUS_WINDOW; rm -f "$STATE"; }
reset1m() { reset; export AI_DLC_MODEL_OPUS_WINDOW=1m; }
fire()   { printf '{"transcript_path":"%s","session_id":"t"%s}' "$FIXTURES/$1" "${2:-}" \
             | CLAUDE_PROJECT_DIR="$WORK" "$HOOK" 2>/dev/null; }
ctx()    { jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null; }
field()  { sed -n "s/^$1=//p" "$STATE" 2>/dev/null | head -1; }
at()     { # $1 = tokens  [$2 = model id] -> writes a one-line transcript, returns its path
  printf '{"type":"assistant","isSidechain":false,"message":{"model":"%s","usage":{"input_tokens":2,"cache_creation_input_tokens":0,"cache_read_input_tokens":%s}}}\n' \
    "${2:-claude-opus-4-8}" "$(( $1 - 2 ))" > "$WORK/at.jsonl"
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
# compact_boundary. OPUS declared at 1M so an unguarded 260000 would fire IMMINENT.
reset1m
check "pre-boundary-only transcript is silent" "$(fire post-compact-stale.jsonl | ctx)" ""
check "  and records no stale reading" "$(field last_measured)" ""

reset1m
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

# --- model ceiling: declared per family, never inferred -----------------------
# The transcript names the model but never its window, so the ceiling is the
# operator's declaration for that model's FAMILY (a substring of the id), and a
# family nobody declared is assumed at the 200000 floor with imminent gated off.
# Nothing is proven, learned or cached.
#
# ALL FIVE VARS ARE SET IN ONE RUN, EACH TO A DISTINCT VALUE, so a positive case
# proves the sensor picked ITS family's var and not merely that some lookup fired.
# Every value sits below the 300000 project window, so it is what effective_window
# echoes. The id list carries a mixed-case spelling and an id with no Claude family
# in it at all; the latter must land in OTHER, the conservative bucket.
fam() { # $1 tokens  $2 model id -> run with all five families declared
  printf '{"transcript_path":"%s","session_id":"t"}' "$(at "$1" "$2")" \
    | AI_DLC_MODEL_FABLE_WINDOW=290000 AI_DLC_MODEL_OPUS_WINDOW=280000 \
      AI_DLC_MODEL_SONNET_WINDOW=270000 AI_DLC_MODEL_HAIKU_WINDOW=260000 \
      AI_DLC_MODEL_OTHER_WINDOW=256000 \
      CLAUDE_PROJECT_DIR="$WORK" "$HOOK" 2>/dev/null
}
for spec in "claude-fable-5-1:FABLE:290000" "claude-mythos-5-1:FABLE:290000" \
            "claude-opus-4-8:OPUS:280000" "Claude-Opus-5:OPUS:280000" \
            "claude-sonnet-5:SONNET:270000" "claude-haiku-4-5-20251001:HAIKU:260000" \
            "local-qwen3-max:OTHER:256000"; do
  m="${spec%%:*}"; rest="${spec#*:}"; f="${rest%%:*}"; w="${rest#*:}"
  reset
  fam 100000 "$m" >/dev/null
  check "$m classifies as $f" "$(field model_family)" "$f"
  check "  and reads AI_DLC_MODEL_${f}_WINDOW ($w)" "$(field effective_window)" "$w"
  check "  and counts as declared" "$(field window_declared)" "1"
done

# THE ARM THAT PROVES SEPARATION, beside the positives. Only OPUS is declared; a Haiku
# lead must not inherit it. On the floor a 250000 reading is red, never imminent.
reset
OUT="$(printf '{"transcript_path":"%s","session_id":"t"}' "$(at 250000 claude-haiku-4-5)" \
        | AI_DLC_MODEL_OPUS_WINDOW=1m CLAUDE_PROJECT_DIR="$WORK" "$HOOK" 2>/dev/null | ctx)"
check "a Haiku lead with only OPUS declared does not inherit it" "$(field window_declared)" "0"
check "  and sits on the 200000 floor" "$(field effective_window)" "200000"
check "  classified HAIKU" "$(field model_family)" "HAIKU"
case "$OUT" in *"RED threshold"*) ok "  red still fires on the floor" ;;
  *) bad "  red still fires on the floor" "got: ${OUT:-<silent>}" ;; esac
case "$OUT" in *"Auto-compact will fire"*) bad "  imminent stays gated off undeclared" "fired imminent" ;;
  *) ok "  imminent stays gated off undeclared" ;; esac
case "$OUT" in *"AI_DLC_MODEL_HAIKU_WINDOW"*) ok "  and the reminder names the var to set" ;;
  *) bad "  and the reminder names the var to set" "got: ${OUT:-<silent>}" ;; esac
# The positive twin, one property apart: declare HAIKU and the same reading is imminent.
reset
OUT="$(printf '{"transcript_path":"%s","session_id":"t"}' "$(at 250000 claude-haiku-4-5)" \
        | AI_DLC_MODEL_HAIKU_WINDOW=1m CLAUDE_PROJECT_DIR="$WORK" "$HOOK" 2>/dev/null | ctx)"
case "$OUT" in *"Auto-compact will fire"*) ok "  CONTROL: with HAIKU declared the same reading is imminent" ;;
  *) bad "  CONTROL: with HAIKU declared the same reading is imminent" "got: ${OUT:-<silent>}" ;; esac

# An undeclared family: the floor, red, no imminence, and NO CACHE. The absence half
# (no model file) is paired with the state sidecar's presence in the same run, so a
# hook that exited before writing anything cannot pass it.
reset
OUT="$(fire at-250000.jsonl | ctx)"
check "an undeclared family sits on the 200000 floor" "$(field effective_window)" "200000"
check "  window_declared=0" "$(field window_declared)" "0"
check "  and stays red, not imminent" "$(field last_level)" "red"
check "  and writes no model cache" "$([ -e "$WORK/_bmad-output/.context-sensor-model" ] && echo present || echo absent)" "absent"
check "  CONTROL: the state sidecar WAS written" "$([ -e "$STATE" ] && echo present || echo absent)" "present"

# An unparseable declaration is the same as none, never a ceiling of zero.
reset
printf '{"transcript_path":"%s","session_id":"t"}' "$(at 100000)" \
  | AI_DLC_MODEL_OPUS_WINDOW=banana CLAUDE_PROJECT_DIR="$WORK" "$HOOK" >/dev/null 2>&1
check "an unparseable declaration falls to the floor" "$(field effective_window)" "200000"
check "  and is recorded as undeclared" "$(field window_declared)" "0"

# MUTANT CONTROL for the floor arm: seed the OLD 1M constant in place of 200000 and the
# floor arm must fail. Built as a COPY with its sibling library beside it, guarded by
# cmp -s so a sed that matched nothing cannot pass as a mutation.
HOOK_PATH="${HOOK#bash }"
MUTD="$WORK/mutant"; mkdir -p "$MUTD"
cp "$(dirname "$HOOK_PATH")/ai-dlc-window.sh" "$MUTD/" 2>/dev/null || true
sed 's/^UNDECLARED_MODEL_MAX=200000$/UNDECLARED_MODEL_MAX=1000000/' "$HOOK_PATH" > "$MUTD/ai-dlc-context-sensor.sh"
if cmp -s "$HOOK_PATH" "$MUTD/ai-dlc-context-sensor.sh"; then
  bad "floor mutant applied" "sed matched nothing; the copy is byte-identical"
else
  reset
  printf '{"transcript_path":"%s","session_id":"t"}' "$FIXTURES/at-250000.jsonl" \
    | CLAUDE_PROJECT_DIR="$WORK" bash "$MUTD/ai-dlc-context-sensor.sh" >/dev/null 2>&1
  check "MUTANT: with the old 1M constant the floor arm fails (effective 300000)" "$(field effective_window)" "300000"
fi

reset
OUT="$(printf '{"transcript_path":"%s","session_id":"t"}' "$(at 185000)" \
        | AI_DLC_MODEL_OPUS_WINDOW=1M CLAUDE_PROJECT_DIR="$WORK" "$HOOK" 2>/dev/null | ctx)"
check "a declaration takes the library's spellings (1M)" "$(field window_declared)" "1"
check "  185000 is yellow with OPUS at 1M (300000 window -> yellow 180000)" \
  "$(printf '%s' "$OUT" | grep -c 'YELLOW' | tr -d ' ')" "1"

# --- compact_imminent band ----------------------------------------------------
# window 300000 -> ceiling 269000 -> critical band opens at 249000 (imminent
# clamps to its 20000 min-lead here). A warning AT the ceiling is useless: all
# three real graph compactions last measured 268,892 / 267,719 / 267,445, i.e.
# BELOW 269000, because compaction preempts the next turn. The band must open
# with turns to spare. (at()/raw() are defined near the top helpers.)

reset1m
OUT="$(raw "$(at 249001)" | ctx)"
case "$OUT" in *"Auto-compact will fire"*) ok "imminent opens at ceiling-20000 (249001)" ;;
  *) bad "imminent opens at ceiling-20000 (249001)" "got: ${OUT:-<silent>}" ;; esac
case "$OUT" in *"refresh _bmad-output/pipeline-snapshot.md"*) ok "  and directs a snapshot refresh" ;;
  *) bad "  and directs a snapshot refresh" "no refresh directive" ;; esac
check "  level recorded as imminent" "$(field last_level)" "imminent"

reset1m
OUT="$(raw "$(at 248999)" | ctx)"
case "$OUT" in *"RED threshold"*) ok "just below the band is red, not imminent" ;;
  *) bad "just below the band is red, not imminent" "got: ${OUT:-<silent>}" ;; esac

# The real ordering hazard: red already fired, then the band opens well inside
# red's 50K/20-turn recurrence window. imminent must escalate immediately.
reset1m
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
reset1m
OUT="$(raw "$(at 267445)" | ctx)"                   # lowest real graph preTokens
case "$OUT" in *"Auto-compact will fire"*) ok "band covers the lowest real observed compaction (267445)" ;;
  *) bad "band covers the lowest real observed compaction (267445)" "got: ${OUT:-<silent>}" ;; esac

reset1m
OUT="$(raw "$(at 175000)" | ctx)"
case "$OUT" in *"Auto-compact will fire"*) bad "assumed-safe reading must not claim imminence" "fired at 175000" ;;
  *) ok "a mid-session reading does not claim imminence" ;; esac

# --- recurrence ---------------------------------------------------------------
reset1m
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
# autoCompactWindow, model max); with OPUS declared at 1M the max is 1000000, so it
# echoes the resolved window. Each case proves a layer the pre-change sensor could not see:
# it read only the project settings.json, so local/user cases would report 300000.
reset1m
echo '{"autoCompactWindow":250000}' > "$WORK/.claude/settings.local.json"    # project is 300000
raw "$(at 100000)" >/dev/null
check "settings.local.json overrides project settings.json" "$(field effective_window)" "250000"
rm -f "$WORK/.claude/settings.local.json"

reset1m
mv "$WORK/.claude/settings.json" "$WORK/.claude/settings.json.bak"           # drop project layer
echo '{"autoCompactWindow":420000}' > "$WORK/home/settings.json"             # user layer ($CLAUDE_CONFIG_DIR)
raw "$(at 100000)" >/dev/null
check "user settings used when no project/local layer sets the key" "$(field effective_window)" "420000"
mv "$WORK/.claude/settings.json.bak" "$WORK/.claude/settings.json"
rm -f "$WORK/home/settings.json"

reset1m
printf '{"transcript_path":"%s","session_id":"t"}' "$(at 100000)" \
  | CLAUDE_CODE_AUTO_COMPACT_WINDOW=200k CLAUDE_PROJECT_DIR="$WORK" "$HOOK" >/dev/null 2>&1
check "env CLAUDE_CODE_AUTO_COMPACT_WINDOW supersedes settings files" "$(field effective_window)" "200000"

# --- the runtime window file outranks the env var -----------------------------
# The env var is set once by a shell launcher and does NOT change when the model is
# switched mid-session with /model, so a launcher configured for a 1M model leaves the
# sensor ramping toward a number a 262144-context session never reaches. The statusline
# writes the live answer to a file; these arms pin that the file wins, and pin every
# condition under which it must NOT be trusted.
#
# SEEDED FROM WHAT THE PRODUCER EMITS, not from the subset this reader consults. An arm
# carrying only `target` would pass against a reader that ignored session_id and ts
# entirely, which is the reader this change exists to avoid writing.
WIN="$WORK/window.json"
NOW="$(date +%s)"
SID="ffffffff-1111-2222-3333-444444444444"
seedwin() { # $1 session  $2 ts  $3 target  $4 window  [$5 current_usage json]
  printf '{"model":"m","window":%s,"target":%s,"used_percentage":19,"total_input_tokens":52924,"current_usage":%s,"session_id":"%s","ts":%s}\n' \
    "$4" "$3" "${5:-null}" "$1" "$2" > "$WIN"
}
sidfire() { # $1 transcript  $2 session_id -> run the hook as that session
  printf '{"transcript_path":"%s","session_id":"%s"}' "$1" "$2" \
    | CLAUDE_PROJECT_DIR="$WORK" "$HOOK" 2>/dev/null
}

reset1m
seedwin "$SID" "$NOW" 420000 1000000
sidfire "$(at 100000)" "$SID" >/dev/null
check "a 1M-context model reports ramp target 420000" "$(field effective_window)" "420000"
check "  and records where the window came from" "$(field window_source)" "window.json (runtime)"

# THE DISCRIMINATING ARM. Nothing is declared here, so MODEL_MAX is the 200000 floor
# and the clamp is min(window, MODEL_MAX). A reader that took `target` but left that
# clamp alone reports 200000 -- correct-looking, and wrong by 62144 on every reading.
# The runtime file names the model, so it supplies MODEL_MAX too and the clamp is a
# no-op rather than a second branch beside it.
reset
seedwin "$SID" "$NOW" 262144 262144
sidfire "$(at 100000)" "$SID" >/dev/null
check "a 262144-context model reports 262144, not the assumed 200000" "$(field effective_window)" "262144"
check "  and the window counts as DECLARED (the file named the model)" "$(field window_declared)" "1"

# LAYER 1 OUTRANKS THE FAMILY LOOKUP, whichever family matched. A Haiku lead with HAIKU
# declared at 260000 still takes the runtime file's answer; the declaration is what
# answers when the file does not.
reset
seedwin "$SID" "$NOW" 420000 1000000
printf '{"transcript_path":"%s","session_id":"%s"}' "$(at 100000 claude-haiku-4-5)" "$SID" \
  | AI_DLC_MODEL_HAIKU_WINDOW=260000 CLAUDE_PROJECT_DIR="$WORK" "$HOOK" >/dev/null 2>&1
check "window.json outranks a declared family window" "$(field effective_window)" "420000"
check "  and the family is still recorded" "$(field model_family)" "HAIKU"
rm -f "$WIN"
printf '{"transcript_path":"%s","session_id":"%s"}' "$(at 100000 claude-haiku-4-5)" "$SID" \
  | AI_DLC_MODEL_HAIKU_WINDOW=260000 CLAUDE_PROJECT_DIR="$WORK" "$HOOK" >/dev/null 2>&1
check "  CONTROL: with the file gone the same declaration answers" "$(field effective_window)" "260000"

# Each fallback separately: one arm covering all four cannot say which one fired.
reset1m
rm -f "$WIN"
sidfire "$(at 100000)" "$SID" >/dev/null
check "a MISSING window file falls back to the settings layers" "$(field effective_window)" "300000"

reset1m
seedwin "$SID" "$((NOW - 61))" 420000 1000000
sidfire "$(at 100000)" "$SID" >/dev/null
check "a STALE window file (ts 61s old) falls back" "$(field effective_window)" "300000"

reset1m
seedwin "$SID" "$((NOW - 59))" 420000 1000000
sidfire "$(at 100000)" "$SID" >/dev/null
check "  CONTROL: 59s old is still fresh and IS taken" "$(field effective_window)" "420000"

reset1m
seedwin "00000000-9999-9999-9999-999999999999" "$NOW" 420000 1000000
sidfire "$(at 100000)" "$SID" >/dev/null
check "a FOREIGN session_id falls back (the path is shared between sessions)" "$(field effective_window)" "300000"

reset1m
printf '{"model":"m","window":1000000,"target":null,"used_percentage":null,"current_usage":null,"session_id":"%s","ts":%s}\n' "$SID" "$NOW" > "$WIN"
sidfire "$(at 100000)" "$SID" >/dev/null
check "a NULL target falls back rather than reading as a 0 window" "$(field effective_window)" "300000"

# current_usage is null before the first API call and again after a compaction. That
# says nothing about `target`, which the producer computes from the model, so the file
# stays usable -- absent is not empty, and neither field is derived from the other.
reset1m
seedwin "$SID" "$NOW" 420000 1000000 null
sidfire "$(at 100000)" "$SID" >/dev/null
check "a null current_usage does not disqualify a valid target" "$(field effective_window)" "420000"

reset1m
seedwin "$SID" "$NOW" 420000 1000000
printf '{"transcript_path":"%s","session_id":"%s"}' "$(at 100000)" "$SID" \
  | CLAUDE_CODE_AUTO_COMPACT_WINDOW=200k CLAUDE_PROJECT_DIR="$WORK" "$HOOK" >/dev/null 2>&1
check "the runtime file outranks the launcher's env var" "$(field effective_window)" "420000"

rm -f "$WIN"

# --- bands track the resolved window (Change B) -------------------------------
# The SAME reading changes level as the window changes, because the bands are a
# clamped percentage of the effective window: at a 300000 window red is 220000,
# but at 500000 the bands move up and 225000 no longer even reaches yellow
# (300000). The pre-change sensor read red off the 1M table (200000) regardless
# of the window, so 225000 fired red at BOTH -- this silent-at-500000 case is what
# it could not produce.
reset1m
OUT="$(printf '{"transcript_path":"%s","session_id":"t"}' "$(at 225000)" \
  | CLAUDE_CODE_AUTO_COMPACT_WINDOW=300000 CLAUDE_PROJECT_DIR="$WORK" "$HOOK" 2>/dev/null | ctx)"
check "225000 is RED at a 300000 window" "$(printf '%s' "$OUT" | grep -c 'RED threshold' | tr -d ' ')" "1"

reset1m
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
# THE SEED ABOVE IS THE DECORATED FORM, WHICH IS THE ONE THE READER ALREADY
# ACCEPTS, so the assertion on it cannot fail against the shape that actually
# broke. The snapshot's writer emits the plain bullet whenever nothing
# re-emphasises it; measured over 2066 real revisions the decoration-spelling
# reader resolved nothing on 195 of them. A sprint change appends a record, so
# the plain form gets a NEW sprint number and is asserted on its own record.
printf -- '- sprint_id: 293\n' > "$WORK/_bmad-output/pipeline-snapshot.md"
fire at-yellow.jsonl >/dev/null
check "  and resolves the PLAIN bullet too (the form the writer emits)" "$(armfield .sprint)" "293"
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
